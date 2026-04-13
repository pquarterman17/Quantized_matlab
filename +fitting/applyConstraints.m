function [pFull, freeIdx] = applyConstraints(pFree, constraints, allParamNames)
%APPLYCONSTRAINTS  Expand free parameters to full vector using constraint expressions.
%
%   Syntax:
%       [pFull, freeIdx] = fitting.applyConstraints(pFree, constraints, allParamNames)
%
%   Inputs:
%       pFree         — [1xK] free parameter values (only the unconstrained ones)
%       constraints   — {1xM} cell array of constraint strings, one per parameter.
%                       Empty string '' means the parameter is free (fitted).
%                       Non-empty string means the parameter is computed from
%                       free parameters using the expression.
%                       Supported syntax: p1, p2, ... refer to free parameters
%                       by their 1-based index in allParamNames.
%                       Also accepts paramName references (e.g. 'a', 'tau').
%                       Operators: + - * / ^ sqrt exp log abs sin cos tan
%                       Numeric constants are allowed. 'pi' and 'e' are recognised.
%       allParamNames — {1xM} parameter name strings matching p0 order
%
%   Outputs:
%       pFull   — [1xM] full parameter vector with constrained params filled in
%       freeIdx — [1xK] indices of free (unconstrained) parameters in pFull
%
%   Examples:
%       % Two params: a is free, b = 2*a
%       constraints = {'', '2*p1'};
%       [pFull, fi] = fitting.applyConstraints([3.5], constraints, {'a','b'});
%       % pFull = [3.5, 7.0],  fi = [1]
%
%       % Three params: a, b free; c = a + b
%       constraints = {'', '', 'p1 + p2'};
%       [pFull, fi] = fitting.applyConstraints([1, 2], constraints, {'a','b','c'});
%       % pFull = [1, 2, 3],  fi = [1 2]
%
%   Notes:
%       Uses fitting.parseEquation for safe tokenised evaluation (no eval).
%       Within constraint expressions the independent variable 'x' is NOT
%       meaningful; pass a scalar 0 to the generated function handle — only
%       the 'p' vector argument carries the free values.

arguments
    pFree         (1,:) double
    constraints   (1,:) cell
    allParamNames (1,:) cell
end

M = numel(constraints);
assert(numel(allParamNames) == M, ...
    'fitting:applyConstraints:sizeMismatch', ...
    'constraints and allParamNames must have the same length.');

% ════════════════════════════════════════════════════════════════════════
% Determine free and constrained indices
% ════════════════════════════════════════════════════════════════════════

isConstrained = false(1, M);
for k = 1:M
    expr = strtrim(constraints{k});
    if ~isempty(expr)
        isConstrained(k) = true;
    end
end

freeIdx = find(~isConstrained);
K = numel(freeIdx);

assert(numel(pFree) == K, ...
    'fitting:applyConstraints:freeCountMismatch', ...
    'pFree has %d elements but %d free parameters found.', numel(pFree), K);

% ════════════════════════════════════════════════════════════════════════
% Start with free params in their positions
% ════════════════════════════════════════════════════════════════════════

pFull = NaN(1, M);
pFull(freeIdx) = pFree;

% ════════════════════════════════════════════════════════════════════════
% Evaluate constrained parameters
% ════════════════════════════════════════════════════════════════════════

% Build a lookup: paramName -> its free-param index (p1, p2, ...) or NaN
% Constraint expressions may use:
%   p1, p2, ... (1-indexed positions among ALL params, matching allParamNames)
%   or the actual param name (e.g. 'a', 'tau')
%
% Strategy: rewrite the expression to use only 'p1..pK' referencing free params,
% then build a synthetic pVec for the evaluator where p(k) = pFull(freeIdx(k)).

for k = 1:M
    expr = strtrim(constraints{k});
    if isempty(expr)
        continue;
    end

    % Rewrite: replace named references with p<freeLocalIndex>
    % and replace p<globalIndex> with p<freeLocalIndex>
    rewrittenExpr = rewriteConstraintExpr(expr, allParamNames, freeIdx, M, K);

    % Parse the rewritten expression; 'x' is unused — pass scalar 0
    try
        fcn = fitting.parseEquation(rewrittenExpr);
    catch ME
        error('fitting:applyConstraints:parseFailed', ...
            'Failed to parse constraint for parameter "%s" ("%s"): %s', ...
            allParamNames{k}, expr, ME.message);
    end

    % Evaluate: pass free param values as the p vector
    try
        val = fcn(0, pFree);
        if isscalar(val)
            pFull(k) = val;
        else
            pFull(k) = val(1);
        end
    catch ME
        error('fitting:applyConstraints:evalFailed', ...
            'Failed to evaluate constraint for "%s" ("%s"): %s', ...
            allParamNames{k}, expr, ME.message);
    end
end

end

% ════════════════════════════════════════════════════════════════════════
% Helper: rewrite expression references to use local free-param indices
% ════════════════════════════════════════════════════════════════════════

function expr2 = rewriteConstraintExpr(expr, allParamNames, freeIdx, M, K)
%REWRITECONSTRAINTEXPR  Translate param references to free-local p1..pK indices.
%
%   Replaces:
%     - "pN" (1-indexed global position) -> "p<localIdx>"
%     - param names (e.g. "tau") -> "p<localIdx>"
%   where localIdx is the 1-based position in freeIdx.
%
%   Constrained parameters (not in freeIdx) cannot appear in expressions —
%   that would create circular dependencies. The check is left to the
%   calling code (a NaN in pFull would surface as a NaN result).

expr2 = expr;

% Build global-to-local map for free parameters only
globalToLocal = zeros(1, M);   % 0 = not free
for i = 1:K
    globalToLocal(freeIdx(i)) = i;
end

% Replace named param references (longest names first to avoid partial matches).
% Use regexptranslate('escape',...) to safely escape any regex metacharacters
% that might appear in parameter names.
[~, sortIdx] = sort(cellfun(@numel, allParamNames), 'descend');
for i = 1:M
    gi = sortIdx(i);
    if globalToLocal(gi) == 0, continue; end  % constrained — skip
    localIdx = globalToLocal(gi);
    name = allParamNames{gi};
    if isempty(name), continue; end
    % Only replace if surrounded by non-identifier characters (word boundary)
    safeName = regexptranslate('escape', name);
    expr2 = regexprep(expr2, ...
        ['(?<![a-zA-Z0-9_])' safeName '(?![a-zA-Z0-9_])'], ...
        sprintf('p%d', localIdx));
end

% Replace "pN" positional references (global index) -> local index.
% Do this AFTER name replacement to avoid double-replacing.
% Match 'p' followed by digits not preceded by a letter/digit/underscore.
for gi = 1:M
    if globalToLocal(gi) == 0, continue; end
    localIdx = globalToLocal(gi);
    expr2 = regexprep(expr2, ...
        ['(?<![a-zA-Z0-9_])p' num2str(gi) '(?![0-9])'], ...
        sprintf('p%d', localIdx));
end

end
