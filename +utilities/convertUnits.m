function [out, outUnit] = convertUnits(value, fromUnit, toUnit)
%CONVERTUNITS  Convert a numeric value between common lab units.
%
%   [out, outUnit] = utilities.convertUnits(value, 'Oe', 'T')
%   [out, outUnit] = utilities.convertUnits(data.values, 'emu', 'A·m²')
%
%   Converts value from fromUnit to toUnit.  Both units must be in the
%   same physical quantity group.  Returns the converted value and the
%   canonical output unit string.
%
%   SUPPORTED QUANTITIES AND UNITS:
%     Magnetic field  : Oe, T, mT, A/m
%     Magnetic moment : emu, A·m², J/T, memu
%     Temperature     : K, C, F
%     Angle           : deg, rad
%     Length          : nm, um, mm, cm, m, Å
%
%   INPUTS:
%       value    — scalar or numeric array
%       fromUnit — source unit string (case-insensitive)
%       toUnit   — target unit string (case-insensitive)
%
%   OUTPUTS:
%       out     — converted value (same size as value)
%       outUnit — canonical string for toUnit
%
%   EXAMPLES:
%       [H_T, u] = utilities.convertUnits(data.time, 'Oe', 'T');
%       xlabel(sprintf('Magnetic Field (%s)', u));
%
%       [M_Am2, ~] = utilities.convertUnits(data.values, 'emu', 'A·m²');
%
%   See also utilities.normalize, utilities.smoothData

    arguments
        value    (:,:) double
        fromUnit (1,1) string
        toUnit   (1,1) string
    end

    fromUnit = lower(strtrim(fromUnit));
    toUnit   = lower(strtrim(toUnit));

    if strcmp(fromUnit, toUnit)
        out = value;
        outUnit = char(toUnit);
        return;
    end

    % ── Magnetic field (base: A/m) ─────────────────────────────────────────
    fieldUnits = struct( ...
        'oe',   1000/(4*pi), ...   % 1 Oe = 1000/(4π) A/m
        't',    1e4/(4*pi), ...    % 1 T  = 1e4/(4π) A/m  (mu0 * H in SI)
        'mt',   10/(4*pi), ...     % 1 mT = 1e1/(4π) A/m
        'a_m',  1 ...              % base unit
    );
    % canonical display strings
    fieldCanon = struct('oe','Oe','t','T','mt','mT','a_m','A/m');

    % ── Magnetic moment (base: A·m²) ─────────────────────────────────────
    momentUnits = struct( ...
        'emu',     1e-3, ...       % 1 emu = 1e-3 A·m² (= 1e-3 J/T)
        'a_m2',    1, ...
        'j_t',     1, ...          % A·m² = J/T
        'memu',    1e-6 ...        % 1 memu = 1e-6 A·m²
    );
    momentCanon = struct('emu','emu','a_m2','A·m²','j_t','J/T','memu','memu');

    % ── Temperature (converted via Kelvin) ────────────────────────────────
    tempFrom = fromUnit;  tempTo = toUnit;
    if any(strcmp(tempFrom, {'k','c','f'})) && any(strcmp(tempTo, {'k','c','f'}))
        out = toKelvin(value, tempFrom);
        out = fromKelvin(out, tempTo);
        outUnit = tempCanonStr(tempTo);
        return;
    end

    % ── Angle ─────────────────────────────────────────────────────────────
    angleUnits = struct('deg', pi/180, 'rad', 1);
    angleCanon = struct('deg','deg','rad','rad');

    % ── Length (base: m) ─────────────────────────────────────────────────
    lengthUnits = struct( ...
        'nm',  1e-9, 'um', 1e-6, 'mm', 1e-3, ...
        'cm',  1e-2, 'm',  1,    'ang', 1e-10 ...
    );
    lengthCanon = struct( ...
        'nm','nm','um','µm','mm','mm','cm','cm','m','m','ang','Å');

    % ── Try each quantity group ───────────────────────────────────────────
    [out, outUnit, ok] = tryConvert(value, fromUnit, toUnit, fieldUnits,  fieldCanon);
    if ok, return; end
    [out, outUnit, ok] = tryConvert(value, fromUnit, toUnit, momentUnits, momentCanon);
    if ok, return; end
    [out, outUnit, ok] = tryConvert(value, fromUnit, toUnit, angleUnits,  angleCanon);
    if ok, return; end
    [out, outUnit, ok] = tryConvert(value, fromUnit, toUnit, lengthUnits, lengthCanon);
    if ok, return; end

    error('utilities:convertUnits:unknownUnit', ...
        'Cannot convert "%s" → "%s". Check supported units in help utilities.convertUnits.', ...
        fromUnit, toUnit);
end


% ── Local helpers ──────────────────────────────────────────────────────────

function [out, outUnit, ok] = tryConvert(value, fromU, toU, table, canon)
    ok = false;  out = value;  outUnit = char(toU);
    fromKey = matlab.lang.makeValidName(fromU);
    toKey   = matlab.lang.makeValidName(toU);
    if ~isfield(table, fromKey) || ~isfield(table, toKey), return; end
    baseVal = value * table.(fromKey);         % convert to base unit
    out     = baseVal / table.(toKey);         % convert to target
    outUnit = canon.(toKey);
    ok      = true;
end

function K = toKelvin(v, unit)
    switch unit
        case 'k', K = v;
        case 'c', K = v + 273.15;
        case 'f', K = (v - 32) * 5/9 + 273.15;
    end
end

function v = fromKelvin(K, unit)
    switch unit
        case 'k', v = K;
        case 'c', v = K - 273.15;
        case 'f', v = (K - 273.15) * 9/5 + 32;
    end
end

function s = tempCanonStr(unit)
    switch unit
        case 'k', s = 'K';
        case 'c', s = '°C';
        case 'f', s = '°F';
    end
end
