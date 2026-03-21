function result = tTest(x, y, options)
%TTEST  One-sample, two-sample, or paired t-test (no Statistics Toolbox).
%
%   result = utilities.tTest(x)                  % one-sample (H₀: μ=0)
%   result = utilities.tTest(x, [], Mu=5)        % one-sample (H₀: μ=5)
%   result = utilities.tTest(x, y)               % two-sample unpaired
%   result = utilities.tTest(x, y, Paired=true)  % paired t-test
%   result = utilities.tTest(x, y, Alpha=0.01)   % custom significance
%
%   Inputs:
%       x — [N×1] numeric vector (first sample)
%       y — [M×1] numeric vector (second sample), or [] for one-sample
%
%   Options:
%       Mu     — hypothesised mean for one-sample test (default: 0)
%       Paired — logical, if true use paired test (requires same length)
%       Alpha  — significance level (default: 0.05)
%       Tail   — 'both' | 'left' | 'right' (default: 'both')
%
%   Output (struct):
%       .testType — 'one-sample' | 'two-sample' | 'paired'
%       .tStat    — t-statistic
%       .df       — degrees of freedom
%       .pValue   — p-value
%       .ci       — [low high] confidence interval for the mean (difference)
%       .reject   — logical, true if p < alpha
%       .meanDiff — mean difference (or mean - mu for one-sample)
%       .se       — standard error of the mean (difference)
%
%   Examples:
%       % Does this sample differ from zero?
%       r = utilities.tTest(data);
%       fprintf('t(%d) = %.3f, p = %.4f\n', r.df, r.tStat, r.pValue);
%
%       % Are two groups different?
%       r = utilities.tTest(groupA, groupB);
%
%       % Paired before/after comparison
%       r = utilities.tTest(before, after, Paired=true);

arguments
    x (:,1) double
    y (:,1) double = []
    options.Mu     (1,1) double = 0
    options.Paired (1,1) logical = false
    options.Alpha  (1,1) double = 0.05
    options.Tail   (1,1) string {mustBeMember(options.Tail, ...
        ["both","left","right"])} = "both"
end

x = x(~isnan(x));
alpha = options.Alpha;
tail = char(options.Tail);

if isempty(y)
    % ── One-sample t-test ─────────────────────────────────────────
    result.testType = 'one-sample';
    n = numel(x);
    xbar = mean(x);
    s = std(x);
    se = s / sqrt(n);
    tStat = (xbar - options.Mu) / se;
    df = n - 1;
    result.meanDiff = xbar - options.Mu;

elseif options.Paired
    % ── Paired t-test ─────────────────────────────────────────────
    y = y(~isnan(y));
    if numel(x) ~= numel(y)
        error('utilities:tTest:pairedLength', ...
            'Paired test requires equal-length vectors.');
    end
    result.testType = 'paired';
    d = x - y;
    n = numel(d);
    dbar = mean(d);
    s = std(d);
    se = s / sqrt(n);
    tStat = dbar / se;
    df = n - 1;
    result.meanDiff = dbar;

else
    % ── Two-sample t-test (Welch's, unequal variance) ────────────
    y = y(~isnan(y));
    result.testType = 'two-sample';
    n1 = numel(x); n2 = numel(y);
    m1 = mean(x);  m2 = mean(y);
    s1 = std(x);   s2 = std(y);
    se = sqrt(s1^2/n1 + s2^2/n2);
    tStat = (m1 - m2) / se;
    % Welch-Satterthwaite degrees of freedom
    v1 = s1^2/n1; v2 = s2^2/n2;
    df = (v1 + v2)^2 / (v1^2/(n1-1) + v2^2/(n2-1));
    result.meanDiff = m1 - m2;
end

% ════════════════════════════════════════════════════════════════════════
% p-value from t-distribution
% ════════════════════════════════════════════════════════════════════════

% Handle degenerate case: se=0 means all differences are identical
if se == 0 || isnan(tStat)
    if abs(result.meanDiff) < eps
        pValue = 1;   % no difference detected
        tStat  = 0;
    else
        pValue = 0;   % perfect separation
    end
else
    switch tail
        case 'both'
            pValue = 2 * (1 - tcdf_builtin(abs(tStat), df));
        case 'right'
            pValue = 1 - tcdf_builtin(tStat, df);
        case 'left'
            pValue = tcdf_builtin(tStat, df);
    end
end

% Confidence interval
tCrit = tinv_builtin(1 - alpha/2, df);
if isempty(y)
    center = mean(x) - options.Mu;
elseif options.Paired
    center = mean(x - y);
else
    center = mean(x) - mean(y);
end
ci = [center - tCrit*se, center + tCrit*se];

result.tStat  = tStat;
result.df     = df;
result.pValue = pValue;
result.ci     = ci;
result.reject = pValue < alpha;
result.se     = se;

end

% ════════════════════════════════════════════════════════════════════════
% t-distribution CDF via incomplete beta function (no toolbox)
% ════════════════════════════════════════════════════════════════════════

function p = tcdf_builtin(t, nu)
%TCDF_BUILTIN  Student's t cumulative distribution function.
%   Uses the regularised incomplete beta function (MATLAB built-in).
    if ~isfinite(t) || ~isfinite(nu)
        if isnan(t), p = NaN; return; end
        if t == Inf, p = 1; return; end
        if t == -Inf, p = 0; return; end
    end
    x = nu ./ (nu + t.^2);
    x = max(min(x, 1), 0);  % clamp to [0,1] for betainc
    p = 1 - 0.5 * betainc(x, nu/2, 0.5);
    % Handle t < 0
    neg = t < 0;
    p(neg) = 1 - p(neg);
end

function t = tinv_builtin(p, nu)
%TINV_BUILTIN  Inverse t-distribution via bisection.
%   Finds t such that tcdf(t, nu) = p.
    % Start with normal approximation
    t = norminv_approx(p);
    % Newton-Raphson refinement (5 iterations)
    for iter = 1:10
        cp = tcdf_builtin(t, nu);
        % t-distribution PDF
        pdf_t = (1 + t.^2/nu).^(-(nu+1)/2) / (sqrt(nu) * beta(nu/2, 0.5));
        t = t - (cp - p) ./ max(pdf_t, eps);
    end
end

function z = norminv_approx(p)
%NORMINV_APPROX  Approximate inverse normal CDF (rational approximation).
    % Abramowitz & Stegun 26.2.23
    t = sqrt(-2*log(min(p, 1-p)));
    c0 = 2.515517; c1 = 0.802853; c2 = 0.010328;
    d1 = 1.432788; d2 = 0.189269; d3 = 0.001308;
    z = t - (c0 + c1*t + c2*t.^2) ./ (1 + d1*t + d2*t.^2 + d3*t.^3);
    z(p < 0.5) = -z(p < 0.5);
end
