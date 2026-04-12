function [result, info] = unitConvert(value, fromStr, toStr)
%UNITCONVERT  Convert a value between arbitrary unit expressions.
%
%   Syntax:
%     result = calc.unitConvert(value, fromUnit, toUnit)
%     [result, info] = calc.unitConvert(value, fromUnit, toUnit)
%
%   Inputs:
%     value   — numeric scalar or array to convert
%     fromStr — unit expression string (e.g., 'mA/cm^2', 'eV', 'K')
%     toStr   — target unit expression string
%
%   Outputs:
%     result — converted value(s)
%     info   — struct with fields:
%       .factor      — multiplication factor (result = value * factor),
%                      NaN for non-linear conversions (temperature, bridges)
%       .fromParsed  — parsed unit struct for fromStr
%       .toParsed    — parsed unit struct for toStr
%       .description — human-readable conversion string
%       .latex       — LaTeX-formatted result string
%
%   The parser handles:
%     - SI prefixes: m (milli), u/mu (micro), n (nano), k (kilo), M (mega), etc.
%     - Compound units: mA/cm^2, uOhm*cm, kg*m/s^2
%     - Exponents: cm^2, m^-1, Ang^-2
%     - Equivalence bridges: eV <-> nm, eV <-> THz, Oe <-> T
%     - Temperature: K <-> C <-> F (offset conversions)
%
%   Note: 'A' is always Ampere. Use 'Ang' for Angstrom.
%
%   Examples:
%     calc.unitConvert(1, 'mA/cm^2', 'A/m^2')    % returns 10
%     calc.unitConvert(300, 'K', 'C')              % returns 26.85
%     calc.unitConvert(1.5406, 'Ang', 'nm')        % returns 0.15406
%     calc.unitConvert(1, 'eV', 'nm')              % returns 1239.84...
%     calc.unitConvert(1, 'Oe', 'T')               % returns 1e-4

% ════════════════════════════════════════════════════════════════════

arguments
    value   double
    fromStr (1,:) char
    toStr   (1,:) char
end

C = calc.constants();

% Parse both unit expressions
fromParsed = parseUnits(fromStr);
toParsed   = parseUnits(toStr);

% Try temperature offset conversions first (K/C/F share the same dimension
% vector but require offset formulas, not simple scaling)
[ok, result, factor, desc] = tryTemperature(value, fromParsed, toParsed, fromStr, toStr);
if ~ok
    % Attempt dimensional conversion
    if isequal(fromParsed.dims, toParsed.dims)
        factor = fromParsed.scale / toParsed.scale;
        result = value * factor;
        desc = sprintf('1 %s = %g %s', fromStr, factor, toStr);
    else
        % Try equivalence bridges
        [ok, result, factor, desc] = tryBridge(value, fromParsed, toParsed, fromStr, toStr, C);
        if ~ok
            error('calc:unitConvert:incompatible', ...
                'Cannot convert from ''%s'' to ''%s'': incompatible dimensions.', ...
                fromStr, toStr);
        end
    end
end

% Build info struct
if nargout > 1
    info.factor      = factor;
    info.fromParsed  = fromParsed;
    info.toParsed    = toParsed;
    info.description = desc;
    info.latex       = buildLatex(value, result, fromStr, toStr);
end

end

% ════════════════════════════════════════════════════════════════════
%  UNIT PARSER
% ════════════════════════════════════════════════════════════════════

function parsed = parseUnits(unitStr)
%PARSEUNITS  Parse a unit expression into dimension vector + scale factor.

    tokens = tokenize(unitStr);
    dims  = [0 0 0 0 0 0 0];  % [M L T I Theta N J]
    scale = 1.0;

    for k = 1:numel(tokens)
        tok = tokens(k);
        [baseDims, baseScale] = decomposeToken(tok.str);
        totalScale = baseScale ^ tok.exp;
        if tok.inDenom
            dims  = dims - baseDims * tok.exp;
            scale = scale / totalScale;
        else
            dims  = dims + baseDims * tok.exp;
            scale = scale * totalScale;
        end
    end

    parsed.tokens  = tokens;
    parsed.dims    = dims;
    parsed.scale   = scale;
    parsed.display = unitStr;
end

% ════════════════════════════════════════════════════════════════════
%  STAGE 1: TOKENIZE
% ════════════════════════════════════════════════════════════════════

function tokens = tokenize(unitStr)
%TOKENIZE  Split unit string on / and * operators, extract exponents.

    tokens = struct('str', {}, 'exp', {}, 'inDenom', {});
    inDenom = false;

    % Split on * and / while tracking position
    remaining = strtrim(unitStr);
    while ~isempty(remaining)
        % Find next operator
        opIdx = regexp(remaining, '[/\*]', 'once');
        if isempty(opIdx)
            chunk = remaining;
            remaining = '';
        else
            chunk = remaining(1:opIdx-1);
            op = remaining(opIdx);
            remaining = remaining(opIdx+1:end);
        end

        chunk = strtrim(chunk);
        if isempty(chunk)
            if exist('op', 'var') && op == '/'
                inDenom = true;
            end
            continue
        end

        % Extract exponent: cm^2, m^-1, etc.
        expMatch = regexp(chunk, '^(.+?)\^([+-]?\d+\.?\d*)$', 'tokens', 'once');
        if ~isempty(expMatch)
            tokStr = expMatch{1};
            tokExp = str2double(expMatch{2});
        else
            tokStr = chunk;
            tokExp = 1;
        end

        idx = numel(tokens) + 1;
        tokens(idx).str     = tokStr;
        tokens(idx).exp     = tokExp;
        tokens(idx).inDenom = inDenom;

        % After processing chunk, check if operator sets denom for next token
        if exist('op', 'var')
            if op == '/'
                inDenom = true;
            end
            % * does not change denom state
            clear op
        end
    end
end

% ════════════════════════════════════════════════════════════════════
%  STAGE 2: DECOMPOSE TOKEN (prefix + base unit)
% ════════════════════════════════════════════════════════════════════

function [dims, scale] = decomposeToken(tokStr)
%DECOMPOSETOKEN  Decompose a token into dimension vector and scale.

    reg = getBaseUnitRegistry();
    pre = getSIPrefixTable();

    % Strategy 1: exact match against base unit registry
    if isfield(reg, tokStr)
        entry = reg.(tokStr);
        dims  = entry.dims;
        scale = entry.toSI;
        return
    end

    % Strategy 2: try splitting off SI prefixes (longest first)
    prefixKeys = cellstr(keys(pre));
    prefixKeys = prefixKeys(~cellfun(@isempty, prefixKeys));
    % Sort by length descending so we try longest prefix first
    [~, sortIdx] = sort(cellfun(@numel, prefixKeys), 'descend');
    prefixKeys = prefixKeys(sortIdx);

    for k = 1:numel(prefixKeys)
        pfx = prefixKeys{k};
        if numel(tokStr) > numel(pfx) && strncmp(tokStr, pfx, numel(pfx))
            remainder = tokStr(numel(pfx)+1:end);
            if isfield(reg, remainder)
                entry = reg.(remainder);
                dims  = entry.dims;
                scale = entry.toSI * pre(pfx);
                return
            end
        end
    end

    % Strategy 3: treat as dimensionless label (e.g., 'ions', 'counts')
    dims  = [0 0 0 0 0 0 0];
    scale = 1.0;
end

% ════════════════════════════════════════════════════════════════════
%  BASE UNIT REGISTRY
% ════════════════════════════════════════════════════════════════════

function reg = getBaseUnitRegistry()
    persistent cachedReg
    if ~isempty(cachedReg)
        reg = cachedReg;
        return
    end

    % Dimension vector order: [M L T I Theta N J]
    %                          kg m  s  A  K    mol cd

    % ── Length ──
    reg.m    = makeUnit([0 1 0 0 0 0 0], 1);
    reg.Ang  = makeUnit([0 1 0 0 0 0 0], 1e-10);
    reg.angstrom = makeUnit([0 1 0 0 0 0 0], 1e-10);

    % ── Mass ──
    reg.kg   = makeUnit([1 0 0 0 0 0 0], 1);
    reg.g    = makeUnit([1 0 0 0 0 0 0], 1e-3);
    reg.u    = makeUnit([1 0 0 0 0 0 0], 1.66053906660e-27);  % atomic mass unit
    reg.amu  = makeUnit([1 0 0 0 0 0 0], 1.66053906660e-27);

    % ── Time ──
    reg.s    = makeUnit([0 0 1 0 0 0 0], 1);
    reg.min  = makeUnit([0 0 1 0 0 0 0], 60);
    reg.hr   = makeUnit([0 0 1 0 0 0 0], 3600);

    % ── Current ──
    reg.A    = makeUnit([0 0 0 1 0 0 0], 1);

    % ── Temperature ──
    reg.K    = makeUnit([0 0 0 0 1 0 0], 1);
    reg.C    = makeUnit([0 0 0 0 1 0 0], 1);  % same dim, offset handled separately
    reg.F    = makeUnit([0 0 0 0 1 0 0], 1);  % same dim, offset handled separately

    % ── Amount ──
    reg.mol  = makeUnit([0 0 0 0 0 1 0], 1);

    % ── Frequency ──
    reg.Hz   = makeUnit([0 0 -1 0 0 0 0], 1);
    reg.THz  = makeUnit([0 0 -1 0 0 0 0], 1e12);

    % ── Force ──
    reg.N    = makeUnit([1 1 -2 0 0 0 0], 1);

    % ── Energy ──
    reg.J    = makeUnit([1 2 -2 0 0 0 0], 1);
    reg.eV   = makeUnit([1 2 -2 0 0 0 0], 1.602176634e-19);
    reg.erg  = makeUnit([1 2 -2 0 0 0 0], 1e-7);
    reg.cal  = makeUnit([1 2 -2 0 0 0 0], 4.184);

    % ── Power ──
    reg.W    = makeUnit([1 2 -3 0 0 0 0], 1);

    % ── Pressure ──
    reg.Pa   = makeUnit([1 -1 -2 0 0 0 0], 1);
    reg.bar  = makeUnit([1 -1 -2 0 0 0 0], 1e5);
    reg.atm  = makeUnit([1 -1 -2 0 0 0 0], 101325);
    reg.Torr = makeUnit([1 -1 -2 0 0 0 0], 133.322);
    reg.mbar = makeUnit([1 -1 -2 0 0 0 0], 100);
    reg.psi  = makeUnit([1 -1 -2 0 0 0 0], 6894.76);
    reg.GPa  = makeUnit([1 -1 -2 0 0 0 0], 1e9);
    reg.MPa  = makeUnit([1 -1 -2 0 0 0 0], 1e6);

    % ── Electric potential ──
    reg.V    = makeUnit([1 2 -3 -1 0 0 0], 1);

    % ── Resistance ──
    reg.Ohm  = makeUnit([1 2 -3 -2 0 0 0], 1);
    reg.ohm  = makeUnit([1 2 -3 -2 0 0 0], 1);

    % ── Conductance ──
    reg.S    = makeUnit([-1 -2 3 2 0 0 0], 1);

    % ── Capacitance ──
    reg.F_cap = makeUnit([-1 -2 4 2 0 0 0], 1);  % 'F' conflicts with Fahrenheit

    % ── Charge ──
    reg.Coul = makeUnit([0 0 1 1 0 0 0], 1);

    % ── Magnetic field (B-field) ──
    reg.T    = makeUnit([1 0 -2 -1 0 0 0], 1);
    reg.G    = makeUnit([1 0 -2 -1 0 0 0], 1e-4);  % Gauss

    % ── Magnetic field (H-field) ──
    reg.Oe   = makeUnit([0 -1 0 1 0 0 0], 1000/(4*pi));  % 1 Oe = 1000/(4*pi) A/m

    % ── Magnetic moment ──
    reg.emu  = makeUnit([0 2 0 1 0 0 0], 1e-3);  % 1 emu = 1e-3 A*m^2

    % ── Angle ──
    reg.rad  = makeUnit([0 0 0 0 0 0 0], 1);       % dimensionless
    reg.deg  = makeUnit([0 0 0 0 0 0 0], pi/180);
    reg.mrad = makeUnit([0 0 0 0 0 0 0], 1e-3);

    % ── Wavenumber ──
    % cm^-1 is handled by the parser as cm^-1 naturally

    % ── Dimensionless labels ──
    reg.ions   = makeUnit([0 0 0 0 0 0 0], 1);
    reg.counts = makeUnit([0 0 0 0 0 0 0], 1);
    reg.sq     = makeUnit([0 0 0 0 0 0 0], 1);  % Ohm/sq

    cachedReg = reg;
end

function entry = makeUnit(dims, toSI)
    entry.dims = dims;
    entry.toSI = toSI;
end

% ════════════════════════════════════════════════════════════════════
%  SI PREFIX TABLE
% ════════════════════════════════════════════════════════════════════

function pre = getSIPrefixTable()
    persistent cachedPre
    if ~isempty(cachedPre)
        pre = cachedPre;
        return
    end

    pre = dictionary( ...
        ["Y","Z","E","P","T","G","M","k","h","da", ...
         "d","c","m","u","mu","micro","n","p","f","a"], ...
        [1e24,1e21,1e18,1e15,1e12,1e9,1e6,1e3,1e2,1e1, ...
         1e-1,1e-2,1e-3,1e-6,1e-6,1e-6,1e-9,1e-12,1e-15,1e-18]);

    cachedPre = pre;
end

% ════════════════════════════════════════════════════════════════════
%  TEMPERATURE OFFSET CONVERSIONS
% ════════════════════════════════════════════════════════════════════

function [ok, result, factor, desc] = tryTemperature(value, fromP, toP, fromStr, toStr)
    ok = false;
    result = [];
    factor = NaN;
    desc = '';

    % Both must be pure temperature dimension [0 0 0 0 1 0 0]
    tempDim = [0 0 0 0 1 0 0];
    if ~isequal(fromP.dims, tempDim) || ~isequal(toP.dims, tempDim)
        return
    end

    fromU = identifyTempUnit(fromStr);
    toU   = identifyTempUnit(toStr);
    if isempty(fromU) || isempty(toU)
        return
    end

    % Convert to Kelvin first
    switch fromU
        case 'K', valK = value;
        case 'C', valK = value + 273.15;
        case 'F', valK = (value - 32) * 5/9 + 273.15;
    end

    % Convert from Kelvin to target
    switch toU
        case 'K', result = valK;
        case 'C', result = valK - 273.15;
        case 'F', result = (valK - 273.15) * 9/5 + 32;
    end

    ok = true;
    desc = sprintf('%g %s = %g %s', value, fromStr, result, toStr);
end

function u = identifyTempUnit(unitStr)
    unitStr = strtrim(unitStr);
    switch unitStr
        case 'K',          u = 'K';
        case 'C',          u = 'C';
        case 'degC',       u = 'C';
        case 'F',          u = 'F';
        case 'degF',       u = 'F';
        otherwise,         u = '';
    end
end

% ════════════════════════════════════════════════════════════════════
%  EQUIVALENCE BRIDGES (non-dimensional conversions)
% ════════════════════════════════════════════════════════════════════

function [ok, result, factor, desc] = tryBridge(value, fromP, toP, fromStr, toStr, C)
    ok = false;
    result = [];
    factor = NaN;
    desc = '';

    % Convert value to SI base first
    valueSI = value * fromP.scale;

    % Define bridge table: {fromDims, toDims, forwardFcn, description}
    % Energy dimension: [1 2 -2 0 0 0 0]
    % Length dimension:  [0 1 0 0 0 0 0]
    % Frequency:         [0 0 -1 0 0 0 0]
    % Inv-length:        [0 -1 0 0 0 0 0]
    % H-field:           [0 -1 0 1 0 0 0]
    % B-field:           [1 0 -2 -1 0 0 0]

    dimEnergy = [1 2 -2 0 0 0 0];
    dimLength = [0 1 0 0 0 0 0];
    dimFreq   = [0 0 -1 0 0 0 0];
    dimInvLen = [0 -1 0 0 0 0 0];
    dimH      = [0 -1 0 1 0 0 0];
    dimB      = [1 0 -2 -1 0 0 0];

    hc = C.h * C.c;  % J*m

    bridges = {
        dimEnergy, dimLength, @(E) hc ./ E,       @(L) hc ./ L,       'energy-wavelength'
        dimEnergy, dimFreq,   @(E) E / C.h,       @(f) f * C.h,       'energy-frequency'
        dimEnergy, dimInvLen, @(E) E / hc,         @(k) k * hc,        'energy-wavenumber'
        dimH,      dimB,      @(H) H * C.mu0,     @(B) B / C.mu0,     'H-field to B-field'
    };

    for k = 1:size(bridges, 1)
        bFromDims = bridges{k, 1};
        bToDims   = bridges{k, 2};
        fwdFcn    = bridges{k, 3};
        revFcn    = bridges{k, 4};
        bDesc     = bridges{k, 5};

        if isequal(fromP.dims, bFromDims) && isequal(toP.dims, bToDims)
            resultSI = fwdFcn(valueSI);
            result = resultSI / toP.scale;
            ok = true;
            desc = sprintf('%g %s = %g %s  [%s]', value, fromStr, result, toStr, bDesc);
            return
        elseif isequal(fromP.dims, bToDims) && isequal(toP.dims, bFromDims)
            resultSI = revFcn(valueSI);
            result = resultSI / toP.scale;
            ok = true;
            desc = sprintf('%g %s = %g %s  [%s]', value, fromStr, result, toStr, bDesc);
            return
        end
    end
end

% ════════════════════════════════════════════════════════════════════
%  LATEX FORMATTER
% ════════════════════════════════════════════════════════════════════

function tex = buildLatex(value, result, fromStr, toStr)
    if numel(result) == 1
        tex = sprintf('$%g\\,\\text{%s} = %g\\,\\text{%s}$', ...
            value, escapeTex(fromStr), result, escapeTex(toStr));
    else
        tex = '';
    end
end

function s = escapeTex(str)
    s = strrep(str, '*', '\cdot ');
    s = strrep(s, 'Ang', '\text{\AA}');
end
