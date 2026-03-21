function result = linRegress(x, y, options)
%LINREGRESS  Linear regression with full diagnostics (no Statistics Toolbox).
%
%   result = utilities.linRegress(x, y)
%   result = utilities.linRegress(x, y, Alpha=0.01)
%   result = utilities.linRegress(x, y, Order=2)  % polynomial regression
%
%   Fits y = b₀ + b₁x (+ b₂x² + ...) using ordinary least squares.
%   Returns slope, intercept, standard errors, R², adjusted R², F-statistic,
%   p-values, and confidence/prediction band evaluation function.
%
%   Inputs:
%       x — [N×1] independent variable
%       y — [N×1] dependent variable
%
%   Options:
%       Order — polynomial order (default: 1 = linear)
%       Alpha — significance level for confidence intervals (default: 0.05)
%
%   Output (struct):
%       .coeffs    — [1×(Order+1)] fitted coefficients [b₀, b₁, ...] (constant first)
%       .se        — [1×(Order+1)] standard errors of coefficients
%       .tStats    — [1×(Order+1)] t-statistics for each coefficient
%       .pValues   — [1×(Order+1)] p-values for H₀: bᵢ = 0
%       .R2        — coefficient of determination
%       .R2adj     — adjusted R²
%       .fStat     — F-statistic for overall model significance
%       .fPvalue   — p-value for the F-test
%       .RMSE      — root mean squared error
%       .residuals — [N×1] residual vector
%       .yFit      — [N×1] fitted values
%       .confBand  — function handle: [lo,hi] = confBand(xNew) for 95% CI
%       .predBand  — function handle: [lo,hi] = predBand(xNew) for 95% PI
%       .N         — number of observations
%       .df        — residual degrees of freedom
%
%   Examples:
%       r = utilities.linRegress(xdata, ydata);
%       fprintf('y = %.4f + %.4f·x  (R²=%.4f, p=%.2e)\n', ...
%           r.coeffs(1), r.coeffs(2), r.R2, r.pValues(2));
%
%       % Plot with confidence band
%       [lo, hi] = r.confBand(xdata);
%       fill([xdata; flipud(xdata)], [lo; flipud(hi)], 'b', ...
%           'FaceAlpha', 0.15, 'EdgeColor', 'none');

arguments
    x (:,1) double
    y (:,1) double
    options.Order (1,1) double {mustBePositive, mustBeInteger} = 1
    options.Alpha (1,1) double = 0.05
end

N = numel(x);
p = options.Order;  % polynomial order
k = p + 1;          % number of coefficients (including intercept)

if N < k + 1
    error('utilities:linRegress:tooFew', ...
        'Need at least %d points for order-%d regression.', k+1, p);
end

% ════════════════════════════════════════════════════════════════════════
% Design matrix and OLS fit
% ════════════════════════════════════════════════════════════════════════

% Build Vandermonde-like matrix: [1, x, x², ..., x^p]
X = zeros(N, k);
for j = 0:p
    X(:, j+1) = x.^j;
end

% Normal equations: b = (X'X)^(-1) X'y
XtX = X' * X;
Xty = X' * y;
b = XtX \ Xty;

yFit = X * b;
residuals = y - yFit;

% ════════════════════════════════════════════════════════════════════════
% Statistics
% ════════════════════════════════════════════════════════════════════════

df = N - k;
ssRes = sum(residuals.^2);
ssTot = sum((y - mean(y)).^2);
ssReg = ssTot - ssRes;

R2 = 1 - ssRes / max(ssTot, eps);
R2adj = 1 - (ssRes/df) / (ssTot/(N-1));
MSE = ssRes / df;
RMSE = sqrt(MSE);

% F-statistic for overall model
MSreg = ssReg / p;
fStat = MSreg / max(MSE, eps);
fPvalue = 1 - fcdf_builtin(fStat, p, df);

% Coefficient standard errors
covB = MSE * inv(XtX); %#ok<MINV>
se = sqrt(max(diag(covB), 0))';

% t-statistics and p-values for each coefficient
tStats = b' ./ max(se, eps);
pValues = 2 * (1 - tcdf_local(abs(tStats), df));

% ════════════════════════════════════════════════════════════════════════
% Confidence and prediction bands
% ════════════════════════════════════════════════════════════════════════

alpha = options.Alpha;
tCrit = tinv_local(1 - alpha/2, df);
covBmat = covB;  % capture for closure

    function [lo, hi] = confBandFcn(xNew)
        xNew = xNew(:);
        Xnew = zeros(numel(xNew), k);
        for jj = 0:p
            Xnew(:, jj+1) = xNew.^jj;
        end
        yHat = Xnew * b;
        % Variance of predicted mean
        varMean = sum((Xnew * covBmat) .* Xnew, 2);
        margin = tCrit * sqrt(varMean);
        lo = yHat - margin;
        hi = yHat + margin;
    end

    function [lo, hi] = predBandFcn(xNew)
        xNew = xNew(:);
        Xnew = zeros(numel(xNew), k);
        for jj = 0:p
            Xnew(:, jj+1) = xNew.^jj;
        end
        yHat = Xnew * b;
        % Variance of individual prediction
        varPred = MSE + sum((Xnew * covBmat) .* Xnew, 2);
        margin = tCrit * sqrt(varPred);
        lo = yHat - margin;
        hi = yHat + margin;
    end

% ════════════════════════════════════════════════════════════════════════
% Output
% ════════════════════════════════════════════════════════════════════════

result.coeffs    = b';
result.se        = se;
result.tStats    = tStats;
result.pValues   = pValues;
result.R2        = R2;
result.R2adj     = R2adj;
result.fStat     = fStat;
result.fPvalue   = fPvalue;
result.RMSE      = RMSE;
result.residuals = residuals;
result.yFit      = yFit;
result.confBand  = @confBandFcn;
result.predBand  = @predBandFcn;
result.N         = N;
result.df        = df;

end

% ════════════════════════════════════════════════════════════════════════
% Distribution functions (no Statistics Toolbox)
% ════════════════════════════════════════════════════════════════════════

function p = tcdf_local(t, nu)
    x = nu ./ (nu + t.^2);
    p = 1 - 0.5 * betainc(x, nu/2, 0.5);
    neg = t < 0;
    p(neg) = 1 - p(neg);
end

function t = tinv_local(p, nu)
    % Normal approx + Newton refinement
    t0 = sqrt(-2*log(min(p,1-p)));
    c0=2.515517; c1=0.802853; c2=0.010328;
    d1=1.432788; d2=0.189269; d3=0.001308;
    t = t0 - (c0+c1*t0+c2*t0.^2)./(1+d1*t0+d2*t0.^2+d3*t0.^3);
    if p < 0.5, t = -t; end
    for iter = 1:10
        cp = tcdf_local(t, nu);
        pdf_t = (1+t.^2/nu).^(-(nu+1)/2) / (sqrt(nu)*beta(nu/2,0.5));
        t = t - (cp-p)./max(pdf_t, eps);
    end
end

function p = fcdf_builtin(f, d1, d2)
%FCDF_BUILTIN  F-distribution CDF via incomplete beta function.
    x = d1*f ./ (d1*f + d2);
    p = betainc(x, d1/2, d2/2);
end
