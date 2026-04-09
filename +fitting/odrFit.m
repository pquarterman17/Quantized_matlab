function result = odrFit(x, y, options)
%ODRFIT  Orthogonal distance regression (Deming regression).
%
%   Linear fit y = a*x + b that minimizes the sum of squared *perpendicular*
%   distances from each (x,y) point to the fitted line, rather than the
%   vertical distances used by ordinary least squares. Appropriate when
%   *both* X and Y are measured quantities with uncertainty — the common
%   case in instrument calibration, Arrhenius plots, and any fit where
%   both axes come from experiment rather than from a noiseless setpoint.
%
%   Generalizes to Deming regression via a weight ratio λ = σy² / σx²:
%     λ → ∞  recovers ordinary least squares (errors all in Y)
%     λ → 0  recovers inverse OLS            (errors all in X)
%     λ = 1  is symmetric orthogonal regression (equal-variance assumption)
%
%   Uses the closed-form Deming estimator (no iteration needed) and
%   jackknife resampling for standard errors on the slope and intercept.
%
% Syntax
%   result = fitting.odrFit(x, y)
%   result = fitting.odrFit(x, y, 'Lambda', 4)
%   result = fitting.odrFit(x, y, 'XError', xe, 'YError', ye)
%
% Inputs
%   x, y           Column vectors, same length, >= 3 points
%   Lambda         (optional) σy²/σx² ratio (default 1 → symmetric ODR)
%   XError, YError (optional) per-point standard errors; if both given,
%                  λ is computed from mean(YError)²/mean(XError)²
%
% Output struct fields
%   .slope         Fitted slope a
%   .intercept     Fitted intercept b
%   .slopeErr      Jackknife standard error on slope
%   .interceptErr  Jackknife standard error on intercept
%   .lambda        λ used in the fit
%   .rss           Sum of squared orthogonal residuals
%   .rmse          Root mean square of orthogonal residuals
%   .n             Number of points
%
% Example
%   x = linspace(0, 10, 20)' + 0.1*randn(20,1);
%   y = 2*x + 1          + 0.1*randn(20,1);
%   r = fitting.odrFit(x, y);
%   fprintf('slope = %.3f ± %.3f, intercept = %.3f ± %.3f\n', ...
%       r.slope, r.slopeErr, r.intercept, r.interceptErr);
%
% See also: fitting.curveFit, utilities.linRegress

arguments
    x (:,1) double {mustBeReal}
    y (:,1) double {mustBeReal}
    options.Lambda (1,1) double {mustBePositive} = 1
    options.XError double = []
    options.YError double = []
end

assert(numel(x) == numel(y), 'fitting:odrFit:sizeMismatch', ...
    'x and y must have the same length.');
n = numel(x);
assert(n >= 3, 'fitting:odrFit:tooFewPoints', ...
    'ODR requires at least 3 points (got %d).', n);

% Determine λ from supplied error estimates if both are present.
lambda = options.Lambda;
if ~isempty(options.XError) && ~isempty(options.YError)
    xeMean = mean(options.XError, 'omitnan');
    yeMean = mean(options.YError, 'omitnan');
    assert(xeMean > 0, 'fitting:odrFit:badErrors', ...
        'Mean XError must be positive.');
    lambda = (yeMean / xeMean)^2;
end

[slope, intercept] = demingFit(x, y, lambda);

% Orthogonal residuals: perpendicular distance from point to line
% a*x − y + b = 0 → d = (a*x − y + b) / sqrt(a² + 1)
res = (slope*x - y + intercept) / sqrt(slope^2 + 1);
rss  = sum(res.^2);
rmse = sqrt(rss / n);

% Jackknife standard errors — refit n times leaving one point out.
slopes     = zeros(n, 1);
intercepts = zeros(n, 1);
for k = 1:n
    idx = [1:k-1, k+1:n];
    [slopes(k), intercepts(k)] = demingFit(x(idx), y(idx), lambda);
end
slopeErr     = sqrt((n - 1) / n * sum((slopes     - mean(slopes)).^2));
interceptErr = sqrt((n - 1) / n * sum((intercepts - mean(intercepts)).^2));

result = struct( ...
    'slope',        slope, ...
    'intercept',    intercept, ...
    'slopeErr',     slopeErr, ...
    'interceptErr', interceptErr, ...
    'lambda',       lambda, ...
    'rss',          rss, ...
    'rmse',         rmse, ...
    'n',            n);
end

% ════════════════════════════════════════════════════════════════════════
function [slope, intercept] = demingFit(x, y, lambda)
%DEMINGFIT  Closed-form Deming regression on centered moments.
    xbar = mean(x); ybar = mean(y);
    xc = x - xbar;  yc = y - ybar;
    sxx = sum(xc.^2);
    syy = sum(yc.^2);
    sxy = sum(xc .* yc);

    if abs(sxy) < eps
        % Degenerate: no linear correlation. Return zero slope anchored at mean.
        slope = 0;
    else
        disc  = (syy - lambda*sxx)^2 + 4*lambda*sxy^2;
        slope = (syy - lambda*sxx + sign(sxy)*sqrt(disc)) / (2*sxy);
    end
    intercept = ybar - slope * xbar;
end
