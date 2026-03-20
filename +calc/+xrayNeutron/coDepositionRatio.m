function result = coDepositionRatio(formula, sources)
%CODEPOSITONRATIO  Calculate source flux ratios for co-deposition of a target film.
%
%   Syntax
%   ------
%   result = calc.xrayNeutron.coDepositionRatio(formula, sources)
%
%   Inputs
%   ------
%   formula — target film formula string, e.g. 'SrTiO3'
%   sources — cell array of source material formula strings, e.g. {'Sr','TiO2'}
%             Each source provides cation(s) that appear in the target formula.
%             The function maps each unique cation in the target to exactly one
%             source by finding which source contains that cation.
%
%   Outputs
%   -------
%   result — struct with fields:
%     .ratios   — molar flux ratio for each source (normalised so the smallest = 1)
%     .sources  — source formula strings (echoed)
%     .formula  — target formula string (echoed)
%     .cations  — the cation matched from each source (cell array)
%     .needed   — molar count needed per formula unit from each source
%     .latex    — LaTeX string summarising the flux ratios
%
%   Details
%   -------
%   The algorithm:
%   1. Parse the target formula to get element stoichiometry.
%   2. Parse each source formula.
%   3. For each source, identify its cations (non-oxygen elements) that
%      are present in the target formula.
%   4. The molar flux of source i needed to supply nᵢ atoms of cation i
%      per formula unit is:  fluxᵢ = nᵢ / (cation count per formula unit in source i).
%   5. Normalise so the smallest flux = 1.
%
%   This is a simple linear cation-matching model.  It assumes each source
%   uniquely supplies one target cation.  If a source contains multiple
%   target cations (e.g. a complex oxide source), the first matching cation
%   is used and a warning is issued.
%
%   Examples
%   --------
%   r = calc.xrayNeutron.coDepositionRatio('SrTiO3', {'Sr','TiO2'});
%   % r.ratios = [1, 1]  (equal Sr and Ti flux needed)
%
%   r = calc.xrayNeutron.coDepositionRatio('La0.7Sr0.3MnO3', {'La2O3','SrO','MnO'});
%   % r.ratios = [0.35, 0.30, 1.0] (relative fluxes, normalised to Mn = 1)

% ════════════════════════════════════════════════════════════════════

arguments
    formula (1,:) char
    sources (1,:) cell
end

targetParsed = calc.xrayNeutron.parseFormula(formula);

% Build a lookup: element symbol → required count in target
targetMap = containers.Map(targetParsed.elements, num2cell(targetParsed.counts));

nSrc   = numel(sources);
needed  = zeros(1, nSrc);
cations = cell(1, nSrc);

for i = 1:nSrc
    srcParsed = calc.xrayNeutron.parseFormula(sources{i});

    % Find which elements in this source are also cations in the target
    % (treat oxygen as the anion; skip it)
    matchIdx = [];
    for j = 1:numel(srcParsed.elements)
        sym = srcParsed.elements{j};
        if strcmp(sym, 'O')
            continue
        end
        if isKey(targetMap, sym)
            matchIdx(end+1) = j; %#ok<AGROW>
        end
    end

    if isempty(matchIdx)
        error('calc:xrayNeutron:coDepositionRatio:noMatch', ...
            'Source ''%s'' contains no cation found in target formula ''%s''.', ...
            sources{i}, formula);
    end

    if numel(matchIdx) > 1
        warning('calc:xrayNeutron:coDepositionRatio:multipleMatch', ...
            'Source ''%s'' matches multiple target cations; using first match (%s).', ...
            sources{i}, srcParsed.elements{matchIdx(1)});
    end

    j = matchIdx(1);
    cationSym        = srcParsed.elements{j};
    cationInSrc      = srcParsed.counts(j);   % how many of this cation per source formula unit
    cationInTarget   = targetMap(cationSym);   % how many needed in target formula unit

    % Molar flux of source needed per target formula unit
    needed(i)  = cationInTarget / cationInSrc;
    cations{i} = cationSym;
end

% Normalise so smallest = 1
ratios = needed / min(needed);

% Build latex
latexParts = cell(1, nSrc);
for i = 1:nSrc
    latexParts{i} = sprintf('%.4g\\,\\text{%s}', ratios(i), sources{i});
end
latexStr = ['$\text{Flux ratios: }', strjoin(latexParts, ' : '), '$'];

result.ratios  = ratios;
result.sources = sources;
result.formula = formula;
result.cations = cations;
result.needed  = needed;
result.latex   = latexStr;

end
