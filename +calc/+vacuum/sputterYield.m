function result = sputterYield(material, energy, opts)
%SPUTTERYIELD  Look up the sputter yield for a material/ion combination.
%
%   Tabulated values are from Yamamura & Tawara (1996) / Matsunami (approximate)
%   for Ar ions at 200, 500, 1000, and 5000 eV. Values are interpolated linearly
%   between tabulated energies and return NaN outside the tabulated range.
%
%   Syntax
%   ------
%   result = calc.vacuum.sputterYield(material, energy)
%   result = calc.vacuum.sputterYield(material, energy, ion=ion)
%
%   Inputs
%   ------
%   material — target material string (case-insensitive):
%              'Si','Cu','Fe','Au','Ti','SiO2','Ni','Al','Pt','W',
%              'Ta','Cr','Mo','Ag','GaAs'
%   energy   — ion energy (eV)
%   ion      — ion species string; default = 'Ar'
%              (only 'Ar' is tabulated; other values return NaN with warning)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Y        — sputter yield (atoms/ion); NaN if unknown combination
%     .material — normalised material string
%     .ion      — ion species string
%     .energy   — input energy (eV)
%     .latex    — LaTeX-formatted result string
%
%   Examples
%   --------
%   r = calc.vacuum.sputterYield('Cu', 500);
%   r = calc.vacuum.sputterYield('Si', 1000, ion='Ar');
%   r = calc.vacuum.sputterYield('W',  200);

% ════════════════════════════════════════════════════════════════════

arguments
    material (1,:) char
    energy   (1,1) double {mustBePositive}
    opts.ion (1,:) char = 'Ar'
end

% Build lookup table once via persistent cache
persistent yieldTable
if isempty(yieldTable)
    yieldTable = buildYieldTable();
end

ion      = opts.ion;
matKey   = lower(strtrim(material));
ionKey   = lower(strtrim(ion));

% Only Ar is tabulated
if ~strcmp(ionKey, 'ar')
    warning('sputterYield:unknownIon', ...
        'Ion "%s" is not in the lookup table. Returning NaN.', ion);
    Y = NaN;
    result.Y        = Y;
    result.material = material;
    result.ion      = ion;
    result.energy   = energy;
    result.latex    = '$Y = \mathrm{NaN}$';
    return
end

% Resolve material key (handle case variations)
tableKeys = yieldTable.keys();
matchIdx  = find(strcmpi(tableKeys, matKey));

if isempty(matchIdx)
    warning('sputterYield:unknownMaterial', ...
        'Material "%s" is not in the lookup table. Returning NaN.', material);
    Y = NaN;
    result.Y        = Y;
    result.material = material;
    result.ion      = ion;
    result.energy   = energy;
    result.latex    = '$Y = \mathrm{NaN}$';
    return
end

resolvedKey = tableKeys{matchIdx(1)};
entry       = yieldTable(resolvedKey);
energyGrid  = entry.energies;
yieldGrid   = entry.yields;

% Interpolate; return NaN outside range (no extrapolation)
if energy < energyGrid(1) || energy > energyGrid(end)
    warning('sputterYield:outOfRange', ...
        'Energy %.4g eV is outside tabulated range [%g, %g] eV for %s/%s. Returning NaN.', ...
        energy, energyGrid(1), energyGrid(end), material, ion);
    Y = NaN;
else
    Y = interp1(energyGrid, yieldGrid, energy, 'linear');
end

result.Y        = Y;
result.material = material;
result.ion      = ion;
result.energy   = energy;
if isnan(Y)
    result.latex = '$Y = \mathrm{NaN}$';
else
    result.latex = sprintf('$Y(\\mathrm{%s/%s},\\,%g\\,\\mathrm{eV}) = %.3g\\,\\mathrm{atoms/ion}$', ...
        material, ion, energy, Y);
end
end

% ════════════════════════════════════════════════════════════════════

function tbl = buildYieldTable()
% Returns a containers.Map: lower(material) -> struct(.energies, .yields)
% Energies: [200, 500, 1000, 5000] eV  (Ar ions)
% Source: Yamamura & Tawara (1996) / Matsunami approximate values

energies = [200, 500, 1000, 5000];

data = { ...
    'si',   [0.4,  0.9,  1.2,  1.4]; ...
    'cu',   [1.5,  3.0,  4.0,  4.5]; ...
    'fe',   [0.8,  1.6,  2.2,  2.6]; ...
    'au',   [1.5,  3.2,  4.4,  5.0]; ...
    'ti',   [0.3,  0.7,  1.1,  1.4]; ...
    'sio2', [0.3,  0.7,  1.0,  1.2]; ...
    'ni',   [1.0,  2.2,  3.0,  3.5]; ...
    'al',   [0.5,  1.1,  1.6,  1.8]; ...
    'pt',   [0.8,  1.8,  2.5,  3.0]; ...
    'w',    [0.3,  0.7,  1.0,  1.3]; ...
    'ta',   [0.3,  0.6,  0.9,  1.2]; ...
    'cr',   [0.7,  1.5,  2.1,  2.5]; ...
    'mo',   [0.5,  1.1,  1.5,  1.8]; ...
    'ag',   [1.8,  3.5,  4.8,  5.5]; ...
    'gaas', [0.9,  1.8,  2.5,  2.9]; ...
};

tbl = containers.Map('KeyType','char','ValueType','any');
for i = 1:size(data,1)
    entry.energies = energies;
    entry.yields   = data{i,2};
    tbl(data{i,1}) = entry;
end
end
