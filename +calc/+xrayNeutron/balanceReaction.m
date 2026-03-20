function result = balanceReaction(reactants, products, reactCoeffs, prodCoeffs)
%BALANCEREACTION  Check if a chemical reaction is elementally balanced.
%
%   Syntax
%   ------
%   result = calc.xrayNeutron.balanceReaction(reactants, products, reactCoeffs, prodCoeffs)
%
%   Inputs
%   ------
%   reactants   — cell array of reactant formula strings, e.g. {'Fe2O3', 'CO'}
%   products    — cell array of product formula strings, e.g. {'Fe', 'CO2'}
%   reactCoeffs — numeric vector of stoichiometric coefficients for reactants
%   prodCoeffs  — numeric vector of stoichiometric coefficients for products
%
%   Outputs
%   -------
%   result — struct with fields:
%     .balanced   — logical; true if all elements balance (LHS = RHS)
%     .elements   — cell array of all element symbols appearing in the reaction
%     .lhsCounts  — total atom count per element on the left-hand side
%     .rhsCounts  — total atom count per element on the right-hand side
%     .difference — lhsCounts - rhsCounts (zero vector if balanced)
%     .latex      — LaTeX reaction string with verdict
%
%   Details
%   -------
%   This function does not solve for balancing coefficients — it only
%   verifies whether a proposed set of coefficients produces a balanced
%   equation.  Counts are compared with a tolerance of 1e-9 to allow for
%   fractional stoichiometries.
%
%   Examples
%   --------
%   % Check Fe2O3 + 3CO → 2Fe + 3CO2
%   r = calc.xrayNeutron.balanceReaction( ...
%       {'Fe2O3','CO'}, {'Fe','CO2'}, [1 3], [2 3]);
%   % r.balanced = true
%
%   % Unbalanced example
%   r = calc.xrayNeutron.balanceReaction( ...
%       {'H2','O2'}, {'H2O'}, [1 1], [1]);
%   % r.balanced = false  (need 2H2 + O2 → 2H2O)

% ════════════════════════════════════════════════════════════════════

arguments
    reactants   (1,:) cell
    products    (1,:) cell
    reactCoeffs (1,:) double {mustBePositive}
    prodCoeffs  (1,:) double {mustBePositive}
end

if numel(reactants) ~= numel(reactCoeffs)
    error('calc:xrayNeutron:balanceReaction:sizeMismatch', ...
        'reactants and reactCoeffs must have the same length.');
end
if numel(products) ~= numel(prodCoeffs)
    error('calc:xrayNeutron:balanceReaction:sizeMismatch', ...
        'products and prodCoeffs must have the same length.');
end

% Collect all unique element symbols from both sides
allElements = {};
for i = 1:numel(reactants)
    p = calc.xrayNeutron.parseFormula(reactants{i});
    allElements = [allElements, p.elements]; %#ok<AGROW>
end
for i = 1:numel(products)
    p = calc.xrayNeutron.parseFormula(products{i});
    allElements = [allElements, p.elements]; %#ok<AGROW>
end
allElements = unique(allElements);
nEls = numel(allElements);

% Tally LHS
lhsCounts = zeros(1, nEls);
for i = 1:numel(reactants)
    p = calc.xrayNeutron.parseFormula(reactants{i});
    for j = 1:numel(p.elements)
        idx = strcmp(allElements, p.elements{j});
        lhsCounts(idx) = lhsCounts(idx) + reactCoeffs(i) * p.counts(j);
    end
end

% Tally RHS
rhsCounts = zeros(1, nEls);
for i = 1:numel(products)
    p = calc.xrayNeutron.parseFormula(products{i});
    for j = 1:numel(p.elements)
        idx = strcmp(allElements, p.elements{j});
        rhsCounts(idx) = rhsCounts(idx) + prodCoeffs(i) * p.counts(j);
    end
end

difference = lhsCounts - rhsCounts;
balanced   = all(abs(difference) < 1e-9);

% Build a readable latex string for the reaction arrow
lhsParts = cell(1, numel(reactants));
for i = 1:numel(reactants)
    n = reactCoeffs(i);
    if n == 1
        lhsParts{i} = ['\text{', reactants{i}, '}'];
    else
        lhsParts{i} = [num2str(n, '%g'), '\,\text{', reactants{i}, '}'];
    end
end
rhsParts = cell(1, numel(products));
for i = 1:numel(products)
    n = prodCoeffs(i);
    if n == 1
        rhsParts{i} = ['\text{', products{i}, '}'];
    else
        rhsParts{i} = [num2str(n, '%g'), '\,\text{', products{i}, '}'];
    end
end
verdict = '\;\checkmark';
if ~balanced
    verdict = '\;\times\;(\text{not balanced})';
end
latexStr = ['$', strjoin(lhsParts,' + '), ' \rightarrow ', ...
            strjoin(rhsParts,' + '), verdict, '$'];

result.balanced   = balanced;
result.elements   = allElements;
result.lhsCounts  = lhsCounts;
result.rhsCounts  = rhsCounts;
result.difference = difference;
result.latex      = latexStr;

end
