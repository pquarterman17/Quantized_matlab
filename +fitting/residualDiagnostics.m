function diag = residualDiagnostics(residuals)
%RESIDUALDIAGNOSTICS  Compute diagnostic statistics for fit residuals.
%
%   Syntax:
%       diag = fitting.residualDiagnostics(residuals)
%
%   Inputs:
%       residuals — [N×1] or [1×N] residual vector (yData - yFit)
%
%   Outputs:
%       diag — struct with fields:
%           .qqX         — [N×1] theoretical normal quantiles
%           .qqY         — [N×1] sorted residuals (sample quantiles)
%           .durbinWatson — scalar DW statistic (≈2 = uncorrelated)
%           .runsTestZ   — Z-score from runs test
%           .runsTestP   — two-tailed p-value from runs test
%           .nRuns       — number of sign-change runs observed
%           .nPos        — number of positive residuals
%           .nNeg        — number of non-positive residuals
%           .skewness    — third standardised central moment
%           .kurtosis    — excess kurtosis (0 = normal)
%           .summary     — multi-line interpretive text (char)
%
%   Examples:
%       r = randn(100, 1);
%       d = fitting.residualDiagnostics(r);
%       fprintf('%s\n', d.summary);
%
%   Diagnostic formulas
%   ─────────────────────────────
%   Q-Q plot uses Blom plotting positions  p_i = (i - 3/8)/(n + 1/4),
%   then x_i = Phi^{-1}(p_i). A straight line on (qqX, qqY) implies
%   normally distributed residuals.
%
%   Durbin-Watson statistic:
%
%       DW = sum_{i=2..n} (r_i - r_{i-1})^2 / sum_i r_i^2
%
%   DW ~ 2 indicates no first-order autocorrelation; DW < 1.5 indicates
%   positive autocorrelation (typical when the model is missing a
%   trend); DW > 2.5 indicates negative autocorrelation. Critical values
%   depend on n and the number of regressors (Durbin & Watson 1951).
%
%   Wald-Wolfowitz runs test: under random sign sequencing, the number
%   of runs R has mean and variance
%
%       mu_R   = 2*nPos*nNeg/n + 1
%       var_R  = 2*nPos*nNeg*(2*nPos*nNeg - n) / (n^2 * (n - 1))
%
%   and Z = (R - mu_R)/sqrt(var_R) is approximately standard normal for
%   nPos, nNeg >= 10. Significant Z (|Z| > 1.96) indicates structure
%   missed by the model.
%
%   References
%   ─────────────────────────────
%   - Durbin, J. & Watson, G.S., "Testing for serial correlation in least
%     squares regression. II", Biometrika 38, 159-178 (1951).
%   - Wald, A. & Wolfowitz, J., "On a test whether two samples are from
%     the same population", Ann. Math. Stat. 11, 147-162 (1940).
%   - Bevington, P.R. & Robinson, D.K., "Data Reduction and Error
%     Analysis", 3rd ed., McGraw-Hill, 2003. Ch. 4 (residual analysis).

arguments
    residuals double
end

% ════════════════════════════════════════════════════════════════════════
% Ensure column vector; handle edge cases early
% ════════════════════════════════════════════════════════════════════════

r = residuals(:);
n = numel(r);

nanStruct = struct( ...
    'qqX',         NaN, ...
    'qqY',         NaN, ...
    'durbinWatson', NaN, ...
    'runsTestZ',   NaN, ...
    'runsTestP',   NaN, ...
    'nRuns',       NaN, ...
    'nPos',        NaN, ...
    'nNeg',        NaN, ...
    'skewness',    NaN, ...
    'kurtosis',    NaN, ...
    'summary',     'Insufficient data for diagnostics.');

if n < 3
    diag = nanStruct;
    if n == 1
        diag.summary = 'N=1: all diagnostics undefined.';
    elseif n == 2
        diag.summary = 'N=2: insufficient data for diagnostics.';
    end
    return
end

% ════════════════════════════════════════════════════════════════════════
% Q-Q plot data
% ════════════════════════════════════════════════════════════════════════

qqY = sort(r);

% Blom plotting positions: p = (i - 0.375) / (n + 0.25)
idx = (1:n)';
p   = (idx - 0.375) ./ (n + 0.25);

% Inverse normal CDF via rational approximation (Abramowitz & Stegun 26.2.17)
qqX = normalInv(p);

% ════════════════════════════════════════════════════════════════════════
% Durbin-Watson statistic
% ════════════════════════════════════════════════════════════════════════

durbinWatson = sum(diff(r).^2) / sum(r.^2);

% ════════════════════════════════════════════════════════════════════════
% Runs test (Wald-Wolfowitz)
% ════════════════════════════════════════════════════════════════════════

signs = r >= 0;   % true = non-negative, false = negative
nPos  = sum(signs);
nNeg  = n - nPos;

% Count runs
nRuns = 1 + sum(signs(1:end-1) ~= signs(2:end));

if nPos < 1 || nNeg < 1
    % All same sign — trivially non-random (only one run possible)
    runsTestZ = NaN;
    runsTestP = NaN;
else
    muRuns  = (2 * nPos * nNeg) / n + 1;
    varRuns = (2 * nPos * nNeg * (2 * nPos * nNeg - n)) / ...
              (n^2 * (n - 1));
    if varRuns <= 0
        runsTestZ = NaN;
        runsTestP = NaN;
    else
        runsTestZ = (nRuns - muRuns) / sqrt(varRuns);
        runsTestP = 2 * normalCDF(-abs(runsTestZ));
    end
end

% ════════════════════════════════════════════════════════════════════════
% Moments: skewness and excess kurtosis
% ════════════════════════════════════════════════════════════════════════

mu   = mean(r);
s    = std(r, 1);     % population std (divides by n)

if s < eps
    skewnessVal = NaN;
    kurtosisVal = NaN;
else
    skewnessVal = mean(((r - mu) ./ s).^3);
    kurtosisVal = mean(((r - mu) ./ s).^4) - 3;   % excess kurtosis
end

% ════════════════════════════════════════════════════════════════════════
% Build interpretive summary
% ════════════════════════════════════════════════════════════════════════

lines = {};

% Durbin-Watson
if isnan(durbinWatson)
    lines{end+1} = 'DW: N/A';
elseif durbinWatson < 1.5
    lines{end+1} = sprintf('DW = %.3f  [positive autocorrelation — residuals correlated]', durbinWatson);
elseif durbinWatson > 2.5
    lines{end+1} = sprintf('DW = %.3f  [negative autocorrelation — over-differenced?]', durbinWatson);
else
    lines{end+1} = sprintf('DW = %.3f  [no significant autocorrelation]', durbinWatson);
end

% Runs test
if isnan(runsTestP)
    lines{end+1} = sprintf('Runs test: Z = N/A  (all residuals same sign, nPos=%d, nNeg=%d)', nPos, nNeg);
elseif runsTestP < 0.05
    lines{end+1} = sprintf('Runs test: Z = %.3f, p = %.4f  [non-random pattern detected]', runsTestZ, runsTestP);
else
    lines{end+1} = sprintf('Runs test: Z = %.3f, p = %.4f  [no significant pattern]', runsTestZ, runsTestP);
end

% Skewness
if isnan(skewnessVal)
    lines{end+1} = 'Skewness: N/A (zero variance)';
elseif abs(skewnessVal) > 1
    lines{end+1} = sprintf('Skewness = %.3f  [strong asymmetry — consider transformation]', skewnessVal);
elseif abs(skewnessVal) > 0.5
    lines{end+1} = sprintf('Skewness = %.3f  [moderate asymmetry]', skewnessVal);
else
    lines{end+1} = sprintf('Skewness = %.3f  [approximately symmetric]', skewnessVal);
end

% Kurtosis
if isnan(kurtosisVal)
    lines{end+1} = 'Kurtosis: N/A (zero variance)';
elseif abs(kurtosisVal) > 2
    lines{end+1} = sprintf('Excess kurtosis = %.3f  [heavy tails / outliers likely]', kurtosisVal);
else
    lines{end+1} = sprintf('Excess kurtosis = %.3f  [tail weight near normal]', kurtosisVal);
end

lines{end+1} = sprintf('N = %d  |  nPos = %d  |  nNeg = %d  |  nRuns = %d', ...
    n, nPos, nNeg, nRuns);

summary = strjoin(lines, newline);

% ════════════════════════════════════════════════════════════════════════
% Assemble output struct
% ════════════════════════════════════════════════════════════════════════

diag.qqX          = qqX;
diag.qqY          = qqY;
diag.durbinWatson = durbinWatson;
diag.runsTestZ    = runsTestZ;
diag.runsTestP    = runsTestP;
diag.nRuns        = nRuns;
diag.nPos         = nPos;
diag.nNeg         = nNeg;
diag.skewness     = skewnessVal;
diag.kurtosis     = kurtosisVal;
diag.summary      = summary;

end

% ════════════════════════════════════════════════════════════════════════
% Local functions — statistics helpers (no toolbox)
% ════════════════════════════════════════════════════════════════════════

function z = normalInv(p)
%NORMALINV  Rational approximation of the probit function (Abramowitz & Stegun 26.2.17).
%   Valid for 0 < p < 1.  Input is a column vector.
    z = zeros(size(p));
    for k = 1:numel(p)
        pk = p(k);
        if pk <= 0
            z(k) = -Inf;
        elseif pk >= 1
            z(k) = Inf;
        else
            % Reflect for upper tail
            flip = pk > 0.5;
            if flip, pk = 1 - pk; end
            t = sqrt(-2 * log(pk));
            % Coefficients (A&S 26.2.17)
            c0 = 2.515517;
            c1 = 0.802853;
            c2 = 0.010328;
            d1 = 1.432788;
            d2 = 0.189269;
            d3 = 0.001308;
            num = c0 + c1*t + c2*t^2;
            den = 1 + d1*t + d2*t^2 + d3*t^3;
            approx = t - num/den;
            if flip
                z(k) = approx;
            else
                z(k) = -approx;
            end
        end
    end
end

function p = normalCDF(z)
%NORMALCDF  Standard normal CDF via rational approximation (A&S 26.2.17 / erfc).
%   p = P(Z <= z).
    p = 0.5 * erfc(-z / sqrt(2));
end
