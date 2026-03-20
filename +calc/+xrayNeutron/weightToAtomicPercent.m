function result = weightToAtomicPercent(elements, weightPct)
%WEIGHTTOATOMICPERCENT  Convert weight percent to atomic percent.
%
%   Syntax
%   ------
%   result = calc.xrayNeutron.weightToAtomicPercent(elements, weightPct)
%
%   Inputs
%   ------
%   elements  — cell array of element symbols, e.g. {'Fe', 'Ni', 'Cr'}
%   weightPct — numeric vector of weight percentages (need not sum to 100;
%               values are normalised internally)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .atomicPct — atomic percent for each element (sums to 100)
%     .elements  — element symbols (echoed)
%     .weightPct — normalised weight percentages (sums to 100)
%     .masses    — atomic mass of each element (g/mol)
%     .latex     — LaTeX summary string
%
%   Details
%   -------
%   at%ᵢ = (wt%ᵢ / Mᵢ) / Σ(wt%ⱼ / Mⱼ) × 100
%
%   Examples
%   --------
%   r = calc.xrayNeutron.weightToAtomicPercent({'Fe','O'}, [70 30]);
%   % r.atomicPct ≈ [46.58, 53.42]  (Fe₂O₃ ≈ 70% Fe, 30% O by weight)

% ════════════════════════════════════════════════════════════════════

arguments
    elements  (1,:) cell
    weightPct (1,:) double {mustBePositive}
end

if numel(elements) ~= numel(weightPct)
    error('calc:xrayNeutron:weightToAtomicPercent:sizeMismatch', ...
        'elements and weightPct must have the same number of entries.');
end

nEls = numel(elements);
masses = zeros(1, nEls);
for i = 1:nEls
    el = calc.elementData('bySymbol', elements{i});
    masses(i) = el.mass;
end

% Normalise weight fractions
wPctNorm = weightPct / sum(weightPct) * 100;

% Molar proportions
molarProp = wPctNorm ./ masses;

% Atomic percent
atPct = molarProp / sum(molarProp) * 100;

% Build latex summary: "Fe: 46.6 at%"
latexParts = cell(1, nEls);
for i = 1:nEls
    latexParts{i} = sprintf('\\text{%s}: %.3g\\%%', elements{i}, atPct(i));
end
latexStr = strjoin(latexParts, ',\\;');

result.atomicPct = atPct;
result.elements  = elements;
result.weightPct = wPctNorm;
result.masses    = masses;
result.latex     = ['$', latexStr, '$'];

end
