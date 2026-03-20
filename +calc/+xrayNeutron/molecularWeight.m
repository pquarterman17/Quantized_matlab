function result = molecularWeight(formula)
%MOLECULARWEIGHT  Calculate the molecular weight of a compound from its formula.
%
%   Syntax
%   ------
%   result = calc.xrayNeutron.molecularWeight(formula)
%
%   Inputs
%   ------
%   formula — chemical formula string, e.g. 'Fe2O3', 'SrTiO3'
%
%   Outputs
%   -------
%   result — struct with fields:
%     .M        — molecular weight (g/mol)
%     .formula  — input formula string (echoed)
%     .elements — cell array of element symbols
%     .counts   — stoichiometric coefficients (numeric vector)
%     .masses   — atomic mass of each element (g/mol)
%     .latex    — LaTeX-formatted string, e.g. '$M = 159.69\,\text{g/mol}$'
%
%   Examples
%   --------
%   r = calc.xrayNeutron.molecularWeight('Fe2O3');
%   % r.M ≈ 159.69 g/mol
%
%   r = calc.xrayNeutron.molecularWeight('SrTiO3');
%   % r.M ≈ 183.49 g/mol

% ════════════════════════════════════════════════════════════════════

arguments
    formula (1,:) char
end

parsed = calc.xrayNeutron.parseFormula(formula);

masses = zeros(1, numel(parsed.elements));
for i = 1:numel(parsed.elements)
    el = calc.elementData('bySymbol', parsed.elements{i});
    masses(i) = el.mass;
end

M = sum(parsed.counts .* masses);

result.M        = M;
result.formula  = formula;
result.elements = parsed.elements;
result.counts   = parsed.counts;
result.masses   = masses;
result.latex    = sprintf('$M_{\\text{%s}} = %.4g\\,\\text{g/mol}$', ...
                          strrep(formula, '_', '\\_'), M);

end
