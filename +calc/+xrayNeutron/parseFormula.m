function result = parseFormula(formula)
%PARSEFORMULA  Parse a chemical formula string into elements and stoichiometry.
%
%   Syntax
%   ------
%   result = calc.xrayNeutron.parseFormula(formula)
%
%   Inputs
%   ------
%   formula — chemical formula string, e.g. 'Fe2O3', 'SrTiO3', 'La0.7Sr0.3MnO3'
%             Implicit stoichiometry of 1 is assumed for elements with no
%             following number (e.g. 'FeO' → Fe×1, O×1).
%             Parentheses are not supported.
%
%   Outputs
%   -------
%   result — struct with fields:
%     .elements   — cell array of element symbol strings
%     .counts     — numeric vector of stoichiometric coefficients
%     .totalAtoms — sum of all counts
%     .formula    — input formula string (echoed)
%     .latex      — LaTeX-formatted formula string
%
%   Examples
%   --------
%   r = calc.xrayNeutron.parseFormula('Fe2O3');
%   % r.elements = {'Fe','O'}, r.counts = [2 3]
%
%   r = calc.xrayNeutron.parseFormula('SrTiO3');
%   % r.elements = {'Sr','Ti','O'}, r.counts = [1 1 3]
%
%   r = calc.xrayNeutron.parseFormula('La0.7Sr0.3MnO3');
%   % r.elements = {'La','Sr','Mn','O'}, r.counts = [0.7 0.3 1 3]

% ════════════════════════════════════════════════════════════════════

arguments
    formula (1,:) char
end

% Tokenise: each token is an element symbol (capital + optional lowercase)
% followed by an optional number (integer or decimal).
% Pattern: [A-Z][a-z]?  followed by  [0-9]*\.?[0-9]*
tokens = regexp(formula, '([A-Z][a-z]?)(\d*\.?\d*)', 'tokens');

if isempty(tokens)
    error('calc:xrayNeutron:parseFormula:invalid', ...
        'Could not parse formula ''%s''. No element tokens found.', formula);
end

elements = cell(1, numel(tokens));
counts   = zeros(1, numel(tokens));

for i = 1:numel(tokens)
    sym = tokens{i}{1};
    numStr = tokens{i}{2};
    elements{i} = sym;
    if isempty(numStr)
        counts(i) = 1;
    else
        counts(i) = str2double(numStr);
    end
end

% Merge duplicate element symbols (e.g. 'H2OH' would give H×3, O×1)
[uniqueEls, ~, idx] = unique(elements, 'stable');
mergedCounts = zeros(1, numel(uniqueEls));
for i = 1:numel(elements)
    mergedCounts(idx(i)) = mergedCounts(idx(i)) + counts(i);
end

% Build LaTeX subscript string
latexStr = '';
for i = 1:numel(uniqueEls)
    n = mergedCounts(i);
    if n == 1
        latexStr = [latexStr, uniqueEls{i}]; %#ok<AGROW>
    elseif mod(n, 1) == 0
        latexStr = [latexStr, uniqueEls{i}, '_{', num2str(n, '%g'), '}']; %#ok<AGROW>
    else
        latexStr = [latexStr, uniqueEls{i}, '_{', num2str(n, '%.4g'), '}']; %#ok<AGROW>
    end
end

result.elements   = uniqueEls;
result.counts     = mergedCounts;
result.totalAtoms = sum(mergedCounts);
result.formula    = formula;
result.latex      = ['$\text{', latexStr, '}$'];

end
