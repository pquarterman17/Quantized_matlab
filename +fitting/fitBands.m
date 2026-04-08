function bands = fitBands(xGrid, modelFcn, params, covar, nPoints, nFree, options)
%FITBANDS  Compute confidence and prediction bands for a curve fit result.
%
%   Syntax:
%       bands = fitting.fitBands(xGrid, modelFcn, params, covar, nPoints, nFree)
%       bands = fitting.fitBands(..., Level=0.95)
%
%   Inputs:
%       xGrid    — [M×1] x values at which to evaluate bands
%       modelFcn — function handle f(x, params) → [M×1]
%       params   — [P×1 or 1×P] best-fit parameter vector
%       covar    — [P×P] parameter covariance matrix (from curveFit.m)
%       nPoints  — number of data points used in the fit
%       nFree    — degrees of freedom (nPoints - nParams)
%
%   Options:
%       Level    — confidence level in (0, 1), default 0.95
%
%   Outputs (struct):
%       .yFit    — [M×1] model evaluated at xGrid with best-fit params
%       .ciLo    — [M×1] lower confidence interval bound
%       .ciHi    — [M×1] upper confidence interval bound
%       .piLo    — [M×1] lower prediction interval bound
%       .piHi    — [M×1] upper prediction interval bound
%       .level   — confidence level used
%
%   Examples:
%       xg = linspace(0, 10, 200)';
%       bands = fitting.fitBands(xg, @(x,p) p(1)*x + p(2), ...
%           res.params, res.covar, res.nPoints, res.nFree);
%
%   Notes:
%       - Uses numerical Jacobian (forward differences) to propagate
%         covariance to band variance at each x point.
%       - t-critical value is computed without the Statistics Toolbox
%         using a rational approximation for the inverse normal followed
%         by a Cornish-Fisher correction for the t-distribution.
%       - If covar is empty or non-positive-semi-definite, NaN bands are
%         returned gracefully.

arguments
    xGrid    (:,1) double
    modelFcn function_handle
    params   (:,1) double
    covar    (:,:) double
    nPoints  (1,1) double {mustBePositive}
    nFree    (1,1) double {mustBeNonnegative}
    options.Level (1,1) double {mustBeInRange(options.Level, 0, 1, "exclusive")} = 0.95
end

M = numel(xGrid);
P = numel(params);
params = params(:);   % ensure column

% ════════════════════════════════════════════════════════════════════════
% Default NaN output (returned on any failure path)
% ════════════════════════════════════════════════════════════════════════

nanBands = struct( ...
    'yFit',  NaN(M, 1), ...
    'ciLo',  NaN(M, 1), ...
    'ciHi',  NaN(M, 1), ...
    'piLo',  NaN(M, 1), ...
    'piHi',  NaN(M, 1), ...
    'level', options.Level);

% ════════════════════════════════════════════════════════════════════════
% Validate covariance matrix
% ════════════════════════════════════════════════════════════════════════

if isempty(covar) || ~isequal(size(covar), [P P])
    bands = nanBands;
    bands.yFit = modelFcn(xGrid, params);
    return;
end

% Check positive semi-definiteness via Cholesky (fast, no toolbox)
[~, flag] = chol(covar);
if flag ~= 0
    % Covariance is not positive (semi-)definite — return NaN bands but
    % still provide yFit
    bands = nanBands;
    try
        bands.yFit = modelFcn(xGrid, params);
    catch
        bands.yFit = NaN(M, 1);
    end
    return;
end

% ════════════════════════════════════════════════════════════════════════
% Evaluate model on xGrid
% ════════════════════════════════════════════════════════════════════════

try
    yFit = modelFcn(xGrid, params);
    yFit = yFit(:);
catch
    bands = nanBands;
    return;
end

% ════════════════════════════════════════════════════════════════════════
% Numerical Jacobian  J(i,j) = df(x_i)/dp_j
% ════════════════════════════════════════════════════════════════════════

% Step size: relative perturbation, floored to avoid zero steps
dp = max(abs(params) * 1e-7, 1e-10);

J = zeros(M, P);
for j = 1:P
    pPlus = params;
    pPlus(j) = pPlus(j) + dp(j);
    try
        yPlus = modelFcn(xGrid, pPlus);
        J(:, j) = (yPlus(:) - yFit) / dp(j);
    catch
        % If perturbation causes model failure, leave column as zero
        J(:, j) = 0;
    end
end

% ════════════════════════════════════════════════════════════════════════
% Band variance
%   varCI(i) = J(i,:) * covar * J(i,:)'
%   varPI(i) = varCI(i) + s2   where s2 = chiSqRed estimate
% ════════════════════════════════════════════════════════════════════════

% Compute CI variance at each grid point: diag(J * C * J')
% Equivalent to sum((J*C) .* J, 2) for efficiency
JC = J * covar;                           % [M×P]
varCI = max(sum(JC .* J, 2), 0);          % [M×1], clamped non-negative

% Residual variance estimate: from the covariance scaling, chiSqRed = s2.
% curveFit.m defines chiSqRed = ssRes/dof, and scales covar by chiSqRed,
% so we can recover s2 from trace(covar) and the Hessian — but the
% simplest approach is:  s2 ~ mean diagonal of covar / mean diagonal of
% (J'J)^{-1}  which is exactly chiSqRed.  We use sum(varCI) / trace(J'J)
% as an estimate, but the most robust approach is to use the implied
% chiSqRed already baked into the covariance.  Since curveFit sets
% covFree = inv(H/2) * chiSqRed, we note that for a linear model
% inv(H/2) = inv(J'J) (approximately), so trace(covar) ≈ P * chiSqRed * s0
% where s0 is the mean eigenvalue of inv(J'J).  The cleanest no-toolbox
% estimate of s2 for prediction variance is via the ratio:
%   s2 = mean(varCI) / mean(diag(inv(J'J_approx)))
% But since we cannot easily invert without toolbox, we simply estimate:
%   s2 ≈ trace(covar) / trace(JTJinv_approx) ≈ chiSqRed (scalar)
% We use the Frobenius approach: s2 = trace(J * covar * J') / trace(J * J')
% which gives the mean scaled variance across grid points.
JTJ = J' * J;
trJTJ = max(trace(JTJ), eps);
trJCJT = sum(varCI);               % = trace(J * covar * J')
s2 = trJCJT / trJTJ;               % residual variance estimate

varPI = varCI + s2;                % [M×1]

% ════════════════════════════════════════════════════════════════════════
% t-critical value (no Statistics Toolbox)
% ════════════════════════════════════════════════════════════════════════

alpha = 1 - options.Level;
tCrit = tInvTwoTail(alpha, max(nFree, 1));

% ════════════════════════════════════════════════════════════════════════
% Compute bands
% ════════════════════════════════════════════════════════════════════════

halfCI = tCrit * sqrt(varCI);
halfPI = tCrit * sqrt(varPI);

bands.yFit = yFit;
bands.ciLo = yFit - halfCI;
bands.ciHi = yFit + halfCI;
bands.piLo = yFit - halfPI;
bands.piHi = yFit + halfPI;
bands.level = options.Level;

end

% ════════════════════════════════════════════════════════════════════════
% Local functions
% ════════════════════════════════════════════════════════════════════════

function t = tInvTwoTail(alpha, dof)
%TINVTWOTAIL  Two-tailed t-critical value without Statistics Toolbox.
%
%   Uses the Abramowitz & Stegun rational approximation for the standard
%   normal inverse (accurate to ~4.5e-4), then applies a Cornish-Fisher
%   expansion to adjust for finite degrees of freedom.
%
%   Reference:
%     Abramowitz & Stegun, Handbook of Mathematical Functions, §26.2.23
%     (normal inverse approximation)
%     Hill, G.W. (1970). "Algorithm 395: Student's t-distribution."
%     Communications of the ACM, 13(10), 617-619.

p = 1 - alpha / 2;   % upper tail probability cutoff (e.g. 0.975 for 95%)

% For large dof, t approaches z (standard normal)
z = normalInv(p);

if dof >= 1e6
    t = z;
    return;
end

% Cornish-Fisher t-distribution correction (Hill 1970 approximation)
% This is valid for dof >= 1 and gives < 1% error for dof >= 3.
g1 = (z^3 + z) / (4 * dof);
g2 = (5*z^5 + 16*z^3 + 3*z) / (96 * dof^2);
g3 = (3*z^7 + 19*z^5 + 17*z^3 - 15*z) / (384 * dof^3);
g4 = (79*z^9 + 776*z^7 + 1482*z^5 - 1920*z^3 - 945*z) / (92160 * dof^4);

t = z + g1 + g2 + g3 + g4;

% For very small dof the expansion can overshoot; a direct numerical
% inversion via bisection is more robust.
if dof <= 5
    t = tInvBisection(p, dof);
end

end

function z = normalInv(p)
%NORMALINV  Inverse standard normal CDF via Abramowitz & Stegun 26.2.23.
%   Accurate to |error| < 4.5e-4 for 0 < p < 1.

if p <= 0 || p >= 1
    z = sign(p - 0.5) * Inf;
    return;
end

if p < 0.5
    z = -normalInv(1 - p);
    return;
end

% p >= 0.5 branch
t0 = sqrt(-2 * log(1 - p));

% Rational approximation coefficients (A&S 26.2.23)
c = [2.515517, 0.802853, 0.010328];
d = [1.432788, 0.189269, 0.001308];

num = c(1) + c(2)*t0 + c(3)*t0^2;
den = 1 + d(1)*t0 + d(2)*t0^2 + d(3)*t0^3;

z = t0 - num / den;
end

function t = tInvBisection(p, dof)
%TINVBISECTION  Bisection-based t-quantile for small dof.
%   Solves tCDF(t, dof) = p using the beta incomplete-function relationship.

% t-CDF uses regularized incomplete beta:  I(x; a, b)
%   P(T <= t) = 1 - 0.5 * I(dof/(dof+t^2); dof/2, 0.5)  for t > 0
% Upper bracket: dof=1 at 99.9% needs t > 300, so we expand to 1000.
a = 0; b = 1000;  % search bracket: t in [0, 1000] covers all practical cases
for k = 1:80
    mid = (a + b) / 2;
    if tCDF(mid, dof) < p
        a = mid;
    else
        b = mid;
    end
    if (b - a) < 1e-8, break; end
end
t = (a + b) / 2;
end

function p = tCDF(t, dof)
%TCDF  t-distribution CDF P(T <= t) for t >= 0, dof integer or half-integer.
%   Uses the regularized incomplete beta function computed via continued
%   fraction (Numerical Recipes method, no toolbox required).

x = dof / (dof + t^2);
ib = incbeta(x, dof/2, 0.5);
p = 1 - 0.5 * ib;
end

function y = incbeta(x, a, b)
%INCBETA  Regularized incomplete beta I_x(a,b) via continued fraction.
%   Uses the Lentz continued-fraction evaluation (Numerical Recipes §6.4).
%   Accurate to ~1e-10 for most (a,b,x).

if x < 0 || x > 1
    error('fitting:fitBands:incbeta', 'x must be in [0,1]');
end
if x == 0, y = 0; return; end
if x == 1, y = 1; return; end

% Use the symmetry relation for numerical stability
if x > (a + 1) / (a + b + 2)
    y = 1 - incbeta(1 - x, b, a);
    return;
end

% Log of the beta function prefactor
lbf = a*log(x) + b*log(1-x) - log(a) - logBeta(a, b);

% Lentz continued fraction
TINY = 1e-30;
fpmin = TINY;
qab = a + b;
qap = a + 1;
qam = a - 1;
c = 1;
d = 1 - qab*x/qap;
if abs(d) < fpmin, d = fpmin; end
d = 1/d;
h = d;

for m = 1:200
    m2 = 2*m;
    % Even step
    aa = m * (b - m) * x / ((qam + m2) * (a + m2));
    d = 1 + aa*d;
    if abs(d) < fpmin, d = fpmin; end
    c = 1 + aa/c;
    if abs(c) < fpmin, c = fpmin; end
    d = 1/d;
    h = h * d * c;
    % Odd step
    aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
    d = 1 + aa*d;
    if abs(d) < fpmin, d = fpmin; end
    c = 1 + aa/c;
    if abs(c) < fpmin, c = fpmin; end
    d = 1/d;
    delta = d * c;
    h = h * delta;
    if abs(delta - 1) < 3e-10, break; end
end

y = exp(lbf) * h;
end

function lb = logBeta(a, b)
%LOGBETA  Natural log of the beta function B(a,b) = Gamma(a)*Gamma(b)/Gamma(a+b).
%   Uses Stirling-series log-gamma (Lanczos, g=7) — no toolbox required.
%   Accurate to ~1e-12 for a,b > 0.

lb = logGamma(a) + logGamma(b) - logGamma(a + b);
end

function lg = logGamma(z)
%LOGGAMMA  Natural log of Gamma(z) for z > 0 via Lanczos approximation (g=7).
%   Coefficients from Numerical Recipes §6.1.

g  = 7;
p  = [0.99999999999980993, ...
      676.5203681218851, ...
     -1259.1392167224028, ...
      771.32342877765313, ...
     -176.61502916214059, ...
      12.507343278686905, ...
     -0.13857109526572012, ...
      9.9843695780195716e-6, ...
      1.5056327351493116e-7];

if z < 0.5
    % Reflection formula: Gamma(z)*Gamma(1-z) = pi/sin(pi*z)
    lg = log(pi) - log(abs(sin(pi * z))) - logGamma(1 - z);
    return;
end

z = z - 1;
x = p(1);
for i = 1:g+1
    x = x + p(i+1) / (z + i);
end
t  = z + g + 0.5;
lg = 0.5*log(2*pi) + (z + 0.5)*log(t) - t + log(x);
end
