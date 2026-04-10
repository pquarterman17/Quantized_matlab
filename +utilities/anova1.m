function result = anova1(groups, options)
%ANOVA1  One-way analysis of variance (no Statistics Toolbox).
%
%   result = utilities.anova1(groups)
%   result = utilities.anova1(groups, Alpha=0.01)
%   result = utilities.anova1(values, Group=groupLabels)
%
%   Two calling conventions:
%
%     (1) Cell array of vectors — one cell per group:
%             r = utilities.anova1({groupA, groupB, groupC});
%
%     (2) Flat value vector + group label vector:
%             r = utilities.anova1(values, Group=labels);
%         where labels is numeric/string/categorical of the same length.
%
%   Tests the null hypothesis that all groups have the same mean.
%
%   Options:
%       Alpha — significance level (default: 0.05)
%       Group — group labels (required for flat-vector calling form)
%
%   Output (struct):
%       .fStat       — F-statistic
%       .df1         — between-group degrees of freedom (k-1)
%       .df2         — within-group degrees of freedom  (N-k)
%       .pValue      — p-value from F-distribution
%       .ssBetween   — between-group sum of squares
%       .ssWithin    — within-group sum of squares
%       .ssTotal     — total sum of squares
%       .msBetween   — ssBetween / df1
%       .msWithin    — ssWithin  / df2  (pooled variance estimate)
%       .groupMeans  — [k×1] per-group means
%       .groupN      — [k×1] per-group sample sizes
%       .grandMean   — overall mean
%       .reject      — true if p < alpha
%
%   Example:
%       a = randn(20,1);
%       b = randn(25,1) + 0.5;
%       c = randn(15,1) + 1.0;
%       r = utilities.anova1({a,b,c});
%       fprintf('F(%d,%d) = %.3f, p = %.4g\n', r.df1, r.df2, r.fStat, r.pValue);
%
%   See also: utilities.tTest, utilities.linRegress, utilities.descriptiveStats

arguments
    groups
    options.Alpha (1,1) double = 0.05
    options.Group = []
end

% ════════════════════════════════════════════════════════════════════════
% Normalise input to a cell array of column vectors
% ════════════════════════════════════════════════════════════════════════
if iscell(groups)
    cellGroups = groups(:);
elseif isnumeric(groups) && ~isempty(options.Group)
    vals = groups(:);
    labels = options.Group(:);
    if numel(vals) ~= numel(labels)
        error('utilities:anova1:lengthMismatch', ...
            'Values and Group labels must have the same length.');
    end
    uLabels = unique(labels, 'stable');
    cellGroups = cell(numel(uLabels), 1);
    for i = 1:numel(uLabels)
        if iscategorical(labels) || isstring(labels) || ischar(labels)
            mask = labels == uLabels(i);
        else
            mask = labels == uLabels(i);
        end
        cellGroups{i} = vals(mask);
    end
else
    error('utilities:anova1:badInput', ...
        'Pass a cell array of vectors, or a numeric vector with Group= labels.');
end

% Drop NaNs and enforce column vectors
for i = 1:numel(cellGroups)
    g = cellGroups{i}(:);
    cellGroups{i} = g(~isnan(g));
end

% Drop empty groups
cellGroups = cellGroups(cellfun(@(g) numel(g) >= 1, cellGroups));

k = numel(cellGroups);
if k < 2
    error('utilities:anova1:tooFewGroups', ...
        'ANOVA requires at least 2 non-empty groups (got %d).', k);
end

groupN = cellfun(@numel, cellGroups);
if any(groupN < 1)
    error('utilities:anova1:emptyGroup', 'All groups must be non-empty.');
end

% ════════════════════════════════════════════════════════════════════════
% Sums of squares
% ════════════════════════════════════════════════════════════════════════
groupMeans = cellfun(@mean, cellGroups);
N = sum(groupN);
grandMean = sum(groupMeans .* groupN) / N;

ssBetween = sum(groupN .* (groupMeans - grandMean).^2);
ssWithin  = 0;
for i = 1:k
    ssWithin = ssWithin + sum((cellGroups{i} - groupMeans(i)).^2);
end
ssTotal = ssBetween + ssWithin;

df1 = k - 1;
df2 = N - k;
if df2 < 1
    error('utilities:anova1:insufficientData', ...
        'Need more observations than groups (N=%d, k=%d).', N, k);
end

msBetween = ssBetween / df1;
msWithin  = ssWithin  / df2;

if msWithin == 0
    % All observations within each group are identical
    if msBetween == 0
        fStat = 0;
        pValue = 1;
    else
        fStat = Inf;
        pValue = 0;
    end
else
    fStat = msBetween / msWithin;
    pValue = 1 - fcdf_builtin(fStat, df1, df2);
end

% ════════════════════════════════════════════════════════════════════════
% Result struct
% ════════════════════════════════════════════════════════════════════════
result.fStat      = fStat;
result.df1        = df1;
result.df2        = df2;
result.pValue     = pValue;
result.ssBetween  = ssBetween;
result.ssWithin   = ssWithin;
result.ssTotal    = ssTotal;
result.msBetween  = msBetween;
result.msWithin   = msWithin;
result.groupMeans = groupMeans(:);
result.groupN     = groupN(:);
result.grandMean  = grandMean;
result.reject     = pValue < options.Alpha;

end

% ════════════════════════════════════════════════════════════════════════
% F-distribution CDF via regularised incomplete beta (MATLAB built-in)
%
%   F_CDF(x; d1, d2) = I_{d1 x / (d1 x + d2)}(d1/2, d2/2)
%
% betainc(x, a, b) is the *regularised* incomplete beta — no toolbox needed.
% ════════════════════════════════════════════════════════════════════════
function p = fcdf_builtin(x, d1, d2)
    if ~isfinite(x)
        if x >= Inf, p = 1; return; end
        if x <= 0,   p = 0; return; end
        p = NaN; return;
    end
    if x <= 0
        p = 0; return;
    end
    z = (d1 * x) / (d1 * x + d2);
    z = max(min(z, 1), 0);
    p = betainc(z, d1/2, d2/2);
end
