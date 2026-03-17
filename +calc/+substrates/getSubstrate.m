function s = getSubstrate(name)
%GETSUBSTRATE  Return a property struct for a named substrate.
%
%   Syntax:
%     s = calc.substrates.getSubstrate(name)
%
%   Inputs:
%     name   — char or string; substrate identifier (case-insensitive).
%              Call calc.substrates.listSubstrates() for valid names.
%
%   Outputs:
%     s      — struct with fields:
%                .name              char   canonical identifier
%                .formula           char   chemical formula
%                .orientation       char   crystallographic orientation
%                .a                 double lattice parameter a (Angstrom)
%                .b                 double lattice parameter b (Angstrom)
%                .c                 double lattice parameter c (Angstrom)
%                .alpha             double lattice angle alpha (deg)
%                .beta              double lattice angle beta  (deg)
%                .gamma             double lattice angle gamma (deg)
%                .thermalExpansion  double CTE (1e-6 / K)
%                .dielectric        double relative permittivity eps_r
%                .density           double mass density (g/cm^3)
%                .latticeType       char   'cubic' | 'hexagonal' | 'amorphous'
%
%   Example:
%     s = calc.substrates.getSubstrate('SrTiO3(100)');
%     fprintf('a = %.3f Ang\n', s.a);

% ════════════════════════════════════════════════════════════════════
arguments
    name (1,:) char
end

% ════════════════════════════════════════════════════════════════════
% Build table once; cache for subsequent calls
persistent tbl
if isempty(tbl)
    tbl = BuildTable();
end

% ════════════════════════════════════════════════════════════════════
% Lookup — case-insensitive exact match
names = {tbl.name};
idx   = find(strcmpi(name, names), 1);

if isempty(idx)
    % Suggest the closest match by character overlap
    nameLow = lower(name);
    scores  = cellfun(@(n) sum(ismember(lower(n), nameLow)), names);
    [~, bestIdx] = max(scores);
    error('calc:substrates:getSubstrate:unknownSubstrate', ...
        'Unknown substrate "%s". Did you mean "%s"?\nCall calc.substrates.listSubstrates() for all valid names.', ...
        name, tbl(bestIdx).name);
end

s = tbl(idx);
end

% ════════════════════════════════════════════════════════════════════
% Local helper — construct the substrate table (struct array)
function tbl = BuildTable()

% Each row: name, formula, orientation, a, c, CTE, eps_r, density, type
% c = NaN for cubic (will be set to a); a/c = NaN for amorphous
raw = { ...
    'Si(100)',       'Si',       '(100)',      5.431,  NaN,    2.6,   11.7,  2.329, 'cubic';      ...
    'Si(111)',       'Si',       '(111)',      5.431,  NaN,    2.6,   11.7,  2.329, 'cubic';      ...
    'SiO2/Si',       'SiO2',     'amorphous',  NaN,   NaN,    0.5,    3.9,  2.20,  'amorphous';  ...
    'Al2O3(0001)',   'Al2O3',    '(0001)',     4.758,  12.991, 5.0,    9.0,  3.987, 'hexagonal';  ...
    'Al2O3(11-20)',  'Al2O3',    '(11-20)',    4.758,  12.991, 5.0,    9.0,  3.987, 'hexagonal';  ...
    'MgO(100)',      'MgO',      '(100)',      4.212,  NaN,   10.5,    9.8,  3.585, 'cubic';      ...
    'SrTiO3(100)',   'SrTiO3',   '(100)',      3.905,  NaN,   11.0,  300.0,  5.117, 'cubic';      ...
    'GaAs(100)',     'GaAs',     '(100)',      5.653,  NaN,    5.73,  12.9,  5.317, 'cubic';      ...
    'LaAlO3(100)',   'LaAlO3',   '(100)',      3.789,  NaN,   10.0,   24.0,  6.52,  'cubic';      ...
    'LSAT(100)',     'LSAT',     '(100)',      3.868,  NaN,   10.0,   22.0,  6.74,  'cubic';      ...
    'Ge(100)',       'Ge',       '(100)',      5.658,  NaN,    5.9,   16.0,  5.323, 'cubic';      ...
    'InP(100)',      'InP',      '(100)',      5.869,  NaN,    4.6,   12.5,  4.81,  'cubic';      ...
    'YSZ(100)',      'YSZ',      '(100)',      5.125,  NaN,   10.5,   27.0,  5.96,  'cubic';      ...
    'MgAl2O4(100)', 'MgAl2O4',  '(100)',      8.083,  NaN,    7.45,   8.1,  3.578, 'cubic';      ...
};

nSub = size(raw, 1);

% Build cell array of structs with consistent field order, then convert
for k = nSub:-1:1
    aVal  = raw{k,4};
    cVal  = raw{k,5};
    lType = raw{k,9};

    switch lType
        case 'cubic'
            aOut = aVal; bOut = aVal; cOut = aVal;
            al = 90; be = 90; ga = 90;
        case 'hexagonal'
            aOut = aVal; bOut = aVal; cOut = cVal;
            al = 90; be = 90; ga = 120;
        case 'amorphous'
            aOut = NaN; bOut = NaN; cOut = NaN;
            al = NaN; be = NaN; ga = NaN;
        otherwise
            error('calc:substrates:getSubstrate:unknownType', ...
                'Unrecognised lattice type "%s" in substrate table.', lType);
    end

    tbl(k).name             = raw{k,1};
    tbl(k).formula          = raw{k,2};
    tbl(k).orientation      = raw{k,3};
    tbl(k).a                = aOut;
    tbl(k).b                = bOut;
    tbl(k).c                = cOut;
    tbl(k).alpha            = al;
    tbl(k).beta             = be;
    tbl(k).gamma            = ga;
    tbl(k).thermalExpansion  = raw{k,6};
    tbl(k).dielectric        = raw{k,7};
    tbl(k).density           = raw{k,8};
    tbl(k).latticeType       = lType;
end
end
