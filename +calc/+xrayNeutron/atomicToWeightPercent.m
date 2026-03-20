function result = atomicToWeightPercent(elements, atomicPct)
%ATOMICTOWEIGHTPERCENT  Convert atomic percent to weight percent.
%
%   Syntax
%   ------
%   result = calc.xrayNeutron.atomicToWeightPercent(elements, atomicPct)
%
%   Inputs
%   ------
%   elements  — cell array of element symbols, e.g. {'Fe', 'Ni', 'Cr'}
%   atomicPct — numeric vector of atomic percentages (need not sum to 100;
%               values are normalised internally)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .weightPct — weight percent for each element (sums to 100)
%     .elements  — element symbols (echoed)
%     .atomicPct — normalised atomic percentages (sums to 100)
%     .masses    — atomic mass of each element (g/mol)
%     .latex     — LaTeX summary string
%
%   Details
%   -------
%   wt%ᵢ = (at%ᵢ × Mᵢ) / Σ(at%ⱼ × Mⱼ) × 100
%
%   Examples
%   --------
%   r = calc.xrayNeutron.atomicToWeightPercent({'Fe','O'}, [2 3]);
%   % r.weightPct ≈ [69.94, 30.06]  (Fe2O3 stoichiometry)

% ════════════════════════════════════════════════════════════════════

arguments
    elements  (1,:) cell
    atomicPct (1,:) double {mustBePositive}
end

if numel(elements) ~= numel(atomicPct)
    error('calc:xrayNeutron:atomicToWeightPercent:sizeMismatch', ...
        'elements and atomicPct must have the same number of entries.');
end

nEls = numel(elements);
masses = zeros(1, nEls);
for i = 1:nEls
    el = calc.elementData('bySymbol', elements{i});
    masses(i) = el.mass;
end

% Normalise atomic fractions
atPctNorm = atomicPct / sum(atomicPct) * 100;

% Mass proportions
massProp = atPctNorm .* masses;

% Weight percent
wtPct = massProp / sum(massProp) * 100;

% Build latex summary: "Fe: 69.9 wt%"
latexParts = cell(1, nEls);
for i = 1:nEls
    latexParts{i} = sprintf('\\text{%s}: %.3g\\%%', elements{i}, wtPct(i));
end
latexStr = strjoin(latexParts, ',\\;');

result.weightPct = wtPct;
result.elements  = elements;
result.atomicPct = atPctNorm;
result.masses    = masses;
result.latex     = ['$', latexStr, '$'];

end
