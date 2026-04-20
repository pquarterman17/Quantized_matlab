function metrics = fitCompare(yData, residuals, nParams, options)
%FITCOMPARE  Compute model comparison and goodness-of-fit metrics.
%
%   Syntax:
%       metrics = fitting.fitCompare(yData, residuals, nParams)
%       metrics = fitting.fitCompare(yData, residuals, nParams, ...
%           ResidRef=rRef, NParamsRef=pRef)
%
%   Inputs:
%       yData     — [N×1] observed data values
%       residuals — [N×1] residual vector (yData - yFit)
%       nParams   — number of free parameters in the fitted model
%
%   Options:
%       ResidRef   — [N×1] residuals from a reference/simpler model
%                    (required for F-test; ignored if absent)
%       NParamsRef — number of free parameters in the reference model
%                    (required for F-test; must be < nParams)
%
%   Output (struct):
%       .R2       — coefficient of determination
%       .adjR2    — adjusted R² = 1 - (1-R²)*(n-1)/(n-p-1)
%       .aic      — Akaike Information Criterion  (normal-error form)
%       .aicc     — corrected AIC for small samples
%       .bic      — Bayesian Information Criterion
%       .rmse     — root mean squared error
%       .fStat    — F-statistic for nested model comparison (NaN if not applicable)
%       .fPvalue  — two-tailed p-value from F-test (NaN if not applicable)
%       .n        — number of observations
%       .p        — number of free parameters (= nParams)
%       .summary  — human-readable ranking string
%
%   Examples:
%       % Basic metrics after a fit
%       res = fitting.curveFit(x, y, @myModel, p0);
%       m = fitting.fitCompare(y, res.residuals, res.nFree);
%       fprintf('AIC = %.2f  adj-R² = %.4f\n', m.aic, m.adjR2);
%
%       % F-test comparing linear (p=2) vs quadratic (p=3) fits
%       m2 = fitting.fitCompare(y, res2.residuals, 2);
%       m3 = fitting.fitCompare(y, res3.residuals, 3, ...
%           ResidRef=res2.residuals, NParamsRef=2);
%       fprintf('F(1,%d) = %.3f  p = %.4f\n', numel(y)-3, m3.fStat, m3.fPvalue);
%
%   Formulas
%   ─────────────────────────────
%   For RSS = sum(residuals.^2), TSS = sum((y - mean(y)).^2), n samples,
%   p free parameters:
%
%       R^2     = 1 - RSS/TSS
%       adj-R^2 = 1 - (1 - R^2) * (n - 1)/(n - p - 1)
%       AIC     = n*log(RSS/n) + 2*p              (Gaussian-error form, +const)
%       AICc    = AIC + 2*p*(p+1)/(n - p - 1)     (small-sample correction)
%       BIC     = n*log(RSS/n) + p*log(n)         (Schwarz criterion)
%
%   For nested models with RSS_full < RSS_ref (p_full > p_ref):
%
%       F = [(RSS_ref - RSS_full)/(p_full - p_ref)] / [RSS_full/(n - p_full)]
%
%   distributed as F(p_full - p_ref, n - p_full) under the null hypothesis
%   that the extra parameters are zero.
%
%   Interpretation guidelines (informal): differences in AIC of 2 are
%   "weak", 4-7 "considerable", > 10 "decisive" (Burnham & Anderson 2002).
%   BIC penalises complexity more aggressively than AIC for n >= 8.
%
%   References
%   ─────────────────────────────
%   - Akaike, H., "A new look at the statistical model identification",
%     IEEE Trans. Automat. Contr. 19, 716-723 (1974).
%   - Schwarz, G., "Estimating the dimension of a model", Ann. Statist. 6,
%     461-464 (1978).
%   - Burnham, K.P. & Anderson, D.R., "Model Selection and Multimodel
%     Inference", 2nd ed., Springer, 2002. (AIC/AICc decision rules.)
%   - Hurvich, C.M. & Tsai, C.L., "Regression and time series model
%     selection in small samples", Biometrika 76, 297-307 (1989). (AICc.)
%   - Bevington, P.R. & Robinson, D.K., "Data Reduction and Error Analysis",
%     3rd ed., McGraw-Hill, 2003. Ch. 11 (F-test for nested models).

arguments
    yData     (:,1) double
    residuals (:,1) double
    nParams   (1,1) double {mustBeInteger, mustBeNonnegative}
    options.ResidRef   (:,1) double = []
    options.NParamsRef (1,1) double = NaN
end

% ════════════════════════════════════════════════════════════════════════
% Basic quantities
% ════════════════════════════════════════════════════════════════════════

n = numel(yData);
p = nParams;

assert(numel(residuals) == n, 'fitting:fitCompare:lengthMismatch', ...
    'residuals must have the same length as yData (%d).', n);
assert(p >= 0, 'fitting:fitCompare:invalidParams', ...
    'nParams must be non-negative.');

RSS  = sum(residuals.^2);
TSS  = sum((yData - mean(yData)).^2);
RMSE = sqrt(RSS / max(n, 1));

% ════════════════════════════════════════════════════════════════════════
% R² and adjusted R²
% ════════════════════════════════════════════════════════════════════════

if TSS < eps
    % Constant y — R² is undefined; set to NaN rather than Inf/0
    R2    = NaN;
    adjR2 = NaN;
else
    R2 = 1 - RSS / TSS;
    dofDenom = n - p - 1;
    if dofDenom > 0
        adjR2 = 1 - (1 - R2) * (n - 1) / dofDenom;
    else
        adjR2 = NaN;   % not enough degrees of freedom
    end
end

% ════════════════════════════════════════════════════════════════════════
% Information criteria  (Gaussian log-likelihood form)
%   log L = -n/2 * log(2π σ²) - n/2,  σ² = RSS/n
%   AIC   = 2p - 2 log L  =  n*log(RSS/n) + 2p  (+const)
% ════════════════════════════════════════════════════════════════════════

if RSS < eps
    % Perfect fit: log-likelihood → +Inf, so AIC/BIC → -Inf
    aic  = -Inf;
    aicc = -Inf;
    bic  = -Inf;
elseif n < 2
    aic  = NaN;
    aicc = NaN;
    bic  = NaN;
else
    logRSSn = log(RSS / n);
    aic  = n * logRSSn + 2 * p;
    bic  = n * logRSSn + p * log(n);

    % AICc correction: defined when n - p - 1 > 0
    dofAICc = n - p - 1;
    if dofAICc > 0
        aicc = aic + 2 * p * (p + 1) / dofAICc;
    else
        aicc = Inf;   % correction undefined; flag as unreliable
    end
end

% ════════════════════════════════════════════════════════════════════════
% F-test for nested model comparison
%   H0: the additional (p - pRef) parameters are all zero
%   F = [(RSS_ref - RSS) / (p - pRef)] / [RSS / (n - p)]
% ════════════════════════════════════════════════════════════════════════

fStat   = NaN;
fPvalue = NaN;

if ~isempty(options.ResidRef) && ~isnan(options.NParamsRef)
    pRef   = options.NParamsRef;
    nRef   = numel(options.ResidRef);
    RSSref = sum(options.ResidRef.^2);

    % Basic sanity checks
    valid = (nRef == n) && (pRef < p) && (p < n);
    if valid
        df1 = p - pRef;           % numerator df
        df2 = n - p;              % denominator df
        if df2 > 0 && RSS > eps
            fStat   = ((RSSref - RSS) / df1) / (RSS / df2);
            fPvalue = fDistSurvival(fStat, df1, df2);
        elseif RSS < eps
            % Full model is perfect: F → Inf (p → 0)
            fStat   = Inf;
            fPvalue = 0;
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
% Summary string
% ════════════════════════════════════════════════════════════════════════

summaryParts = {};
if ~isnan(R2)
    summaryParts{end+1} = sprintf('R² = %.6f', R2);
end
if ~isnan(adjR2)
    summaryParts{end+1} = sprintf('adj-R² = %.6f', adjR2);
end
if isfinite(aic)
    summaryParts{end+1} = sprintf('AIC = %.2f', aic);
elseif aic == -Inf
    summaryParts{end+1} = 'AIC = -Inf (perfect fit)';
end
if isfinite(bic)
    summaryParts{end+1} = sprintf('BIC = %.2f', bic);
end
if ~isnan(fStat)
    if isinf(fStat)
        summaryParts{end+1} = 'F-test: F = Inf (p ~ 0, full model perfect)';
    else
        summaryParts{end+1} = sprintf('F(%d,%d) = %.3f  p = %.4f', ...
            p - options.NParamsRef, n - p, fStat, fPvalue);
    end
end
summary = strjoin(summaryParts, '  |  ');
if isempty(summary)
    summary = sprintf('n=%d  p=%d  RMSE=%.4g', n, p, RMSE);
end

% ════════════════════════════════════════════════════════════════════════
% Assemble output struct
% ════════════════════════════════════════════════════════════════════════

metrics.R2      = R2;
metrics.adjR2   = adjR2;
metrics.aic     = aic;
metrics.aicc    = aicc;
metrics.bic     = bic;
metrics.rmse    = RMSE;
metrics.fStat   = fStat;
metrics.fPvalue = fPvalue;
metrics.n       = n;
metrics.p       = p;
metrics.summary = summary;

end

% ════════════════════════════════════════════════════════════════════════
% Local functions
% ════════════════════════════════════════════════════════════════════════

function p = fDistSurvival(f, df1, df2)
%FDISTSURVIVAL  P(F > f) for F(df1,df2) using the regularized incomplete beta.
%
%   Uses the relation: P(F > f) = I_x(df2/2, df1/2)  where x = df2/(df2+df1*f)
%
%   The regularized incomplete beta I_x(a,b) is computed via a continued-fraction
%   expansion (no Statistics Toolbox required).

if f <= 0
    p = 1;
    return;
end
if isinf(f)
    p = 0;
    return;
end

a = df2 / 2;
b = df1 / 2;
x = df2 / (df2 + df1 * f);

p = regIncBeta(x, a, b);
end

function Ix = regIncBeta(x, a, b)
%REGINCBETA  Regularized incomplete beta function I_x(a,b) via continued fraction.
%
%   Uses the Lentz continued-fraction method (Numerical Recipes §6.4).
%   Switches sides when x > (a+1)/(a+b+2) for faster convergence.

if x <= 0,  Ix = 0; return; end
if x >= 1,  Ix = 1; return; end

% Use symmetry for better convergence
if x > (a + 1) / (a + b + 2)
    Ix = 1 - regIncBeta(1 - x, b, a);
    return;
end

% Log of the prefactor:  x^a * (1-x)^b / (a * Beta(a,b))
logPre = a * log(x) + b * log(1 - x) - log(a) - logBetaFcn(a, b);
pre    = exp(logPre);

% Lentz continued-fraction for betacf(a,b,x)
MAXIT = 200;
EPS   = 3e-14;
FPMIN = 1e-300;

qab = a + b;
qap = a + 1;
qam = a - 1;
c   = 1;
d   = 1 - qab * x / qap;
if abs(d) < FPMIN, d = FPMIN; end
d   = 1 / d;
h   = d;

for m = 1:MAXIT
    m2 = 2 * m;
    % Even step
    aa =  m * (b - m) * x / ((qam + m2) * (a + m2));
    d  = 1 + aa * d;
    if abs(d) < FPMIN, d = FPMIN; end
    c  = 1 + aa / c;
    if abs(c) < FPMIN, c = FPMIN; end
    d  = 1 / d;
    h  = h * d * c;
    % Odd step
    aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
    d  = 1 + aa * d;
    if abs(d) < FPMIN, d = FPMIN; end
    c  = 1 + aa / c;
    if abs(c) < FPMIN, c = FPMIN; end
    d  = 1 / d;
    delta = d * c;
    h    = h * delta;
    if abs(delta - 1) < EPS
        break;
    end
end

Ix = pre * h;
% Clamp to [0, 1] for floating-point rounding
Ix = max(0, min(1, Ix));
end

function lb = logBetaFcn(a, b)
%LOGBETAFCN  log B(a,b) = log Γ(a) + log Γ(b) - log Γ(a+b).
    lb = gammaln(a) + gammaln(b) - gammaln(a + b);
end
