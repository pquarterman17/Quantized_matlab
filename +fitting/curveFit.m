function result = curveFit(xData, yData, modelFcn, p0, options)
%CURVEFIT  General-purpose curve fitting via fminsearch with bound support.
%
%   result = fitting.curveFit(x, y, @(x,p) model(x,p), p0)
%   result = fitting.curveFit(x, y, modelFcn, p0, Lower=lb, Upper=ub)
%   result = fitting.curveFit(x, y, modelFcn, p0, Weights=w, Fixed=mask)
%   result = fitting.curveFit(x, y, modelFcn, p0, Constraints=c, ParamNames=n)
%
%   Inputs:
%       xData    — [N×1] independent variable
%       yData    — [N×1] dependent variable
%       modelFcn — function handle f(x, p) → [N×1]
%       p0       — [1×M] initial parameter vector
%
%   Options (name-value):
%       Lower       — [1×M] lower bounds (default: -Inf)
%       Upper       — [1×M] upper bounds (default: +Inf)
%       Weights     — [N×1] weights for weighted least squares (default: ones)
%       Fixed       — [1×M] logical mask, true = hold parameter at p0 value
%       Constraints — {1×M} cell array of constraint expressions.
%                     Empty string '' = free (fitted). Non-empty = expression
%                     of free parameters, e.g. '2*p1', 'p1+p2', 'sqrt(p1)'.
%                     Constrained params are derived; optimizer only sees free ones.
%       ParamNames  — {1×M} parameter name strings (required for named
%                     references in Constraints, e.g. 'tau' instead of 'p2')
%       MaxIter    — max iterations (default: 5000*M)
%       TolFun     — function tolerance (default: 1e-12)
%       TolX       — parameter tolerance (default: 1e-10)
%       CalcErrors — compute parameter standard errors (default: true)
%
%   Output (struct):
%       .params    — [1×M] fitted parameters
%       .errors    — [1×M] parameter standard errors (NaN if CalcErrors=false)
%       .covar     — [M×M] covariance matrix ([] if CalcErrors=false)
%       .residuals — [N×1] yData - yModel
%       .yFit      — [N×1] model evaluated at fitted params
%       .R2        — coefficient of determination
%       .chiSqRed  — reduced chi-squared (assumes unit variance if no weights)
%       .RMSE      — root mean squared error
%       .AIC       — Akaike information criterion
%       .exitFlag  — fminsearch exit condition (1 = converged)
%       .nIter     — number of iterations used
%       .nFree     — number of free parameters
%       .nPoints   — number of data points
%
%   Method
%   ─────────────────────────────
%   Minimizes the (weighted) sum of squared residuals
%
%       chi2 = sum_i  w_i * (y_i - f(x_i; p))^2
%
%   using MATLAB's fminsearch (Nelder-Mead simplex). Bounded parameters
%   are mapped to an unbounded inner optimization variable via a
%   logit-style transform; errors are propagated back through the
%   transform's Jacobian. Parameter standard errors are read from the
%   diagonal of the covariance matrix
%
%       Cov(p_hat) = inv(H/2) * chiSqRed,
%
%   where H is the central-difference Hessian of chi2 at the optimum and
%   chiSqRed = sum(residuals.^2) / (N - nFree). R2 is computed against the
%   weighted total sum of squares; AIC uses the Gaussian-error log-likelihood
%   form  AIC = 2*nFree - 2*logL = N*log(chiSqRed) + 2*nFree (+ constant).
%
%   Example
%   ─────────────────────────────
%       % Exponential decay with bounds and a fixed offset
%       x  = linspace(0, 5, 60)';
%       y  = 2.0 * exp(-x/1.3) + 0.05 + 0.02*randn(60,1);
%       fcn = @(x,p) p(1)*exp(-x./p(2)) + p(3);
%       res = fitting.curveFit(x, y, fcn, [1 1 0], ...
%                Lower=[0 0 -1], Upper=[Inf Inf 1], ...
%                Fixed=[false false false]);
%       fprintf('A   = %.3f ± %.3f\n', res.params(1), res.errors(1));
%       fprintf('tau = %.3f ± %.3f\n', res.params(2), res.errors(2));
%       fprintf('R^2 = %.4f\n', res.R2);
%
%   References
%   ─────────────────────────────
%   - Bevington, P.R. & Robinson, D.K., "Data Reduction and Error Analysis
%     for the Physical Sciences", 3rd ed., McGraw-Hill, 2003. Ch. 8 (least
%     squares) and Ch. 11 (parameter errors via curvature matrix).
%   - Nelder, J.A. & Mead, R., "A Simplex Method for Function Minimization",
%     Computer Journal 7, 308-313 (1965). DOI: 10.1093/comjnl/7.4.308
%   - Lagarias, J.C. et al., "Convergence Properties of the Nelder-Mead
%     Simplex Method in Low Dimensions", SIAM J. Optim. 9, 112-147 (1998).
%     (MATLAB's fminsearch implementation reference.)

arguments
    xData    (:,1) double
    yData    (:,1) double
    modelFcn function_handle
    p0       (1,:) double
    options.Lower       (1,:) double = []
    options.Upper       (1,:) double = []
    options.Weights     (:,1) double = []
    options.Fixed       (1,:) logical = []
    options.Constraints (1,:) cell = {}
    options.ParamNames  (1,:) cell = {}
    options.MaxIter     double = []
    options.TolFun      double = 1e-12
    options.TolX        double = 1e-10
    options.CalcErrors  logical = true
end

M = numel(p0);
N = numel(xData);

% ════════════════════════════════════════════════════════════════════════
% Validate and set defaults
% ════════════════════════════════════════════════════════════════════════

lb = repmat(-Inf, 1, M);
ub = repmat(Inf, 1, M);
if ~isempty(options.Lower)
    assert(numel(options.Lower) == M, 'fitting:curveFit:bounds', ...
        'Lower bounds must have %d elements.', M);
    lb = options.Lower;
end
if ~isempty(options.Upper)
    assert(numel(options.Upper) == M, 'fitting:curveFit:bounds', ...
        'Upper bounds must have %d elements.', M);
    ub = options.Upper;
end

fixed = false(1, M);
if ~isempty(options.Fixed)
    assert(numel(options.Fixed) == M, 'fitting:curveFit:fixed', ...
        'Fixed mask must have %d elements.', M);
    fixed = options.Fixed;
end

% ── Constraints ──────────────────────────────────────────────────────────
% When Constraints are supplied, constrained parameters are derived from
% free ones during every model evaluation. The optimizer only sees free
% parameters; constrained ones are filled in by applyConstraints before
% passing the full vector to modelFcn.
useConstraints = ~isempty(options.Constraints);
constraintExprs = options.Constraints;
paramNamesForConstraints = options.ParamNames;

if useConstraints
    assert(numel(constraintExprs) == M, 'fitting:curveFit:constraints', ...
        'Constraints cell array must have %d elements (one per parameter).', M);

    if isempty(paramNamesForConstraints)
        % Default names: p1, p2, ...
        paramNamesForConstraints = arrayfun(@(k) sprintf('p%d', k), 1:M, ...
            'UniformOutput', false);
    else
        assert(numel(paramNamesForConstraints) == M, 'fitting:curveFit:paramNames', ...
            'ParamNames must have %d elements.', M);
    end

    % Mark constrained params as "fixed" so the bound-transform logic ignores them.
    % applyConstraints will handle their values during fromFree().
    for k = 1:M
        if ~isempty(strtrim(constraintExprs{k}))
            fixed(k) = true;
        end
    end
end

w = ones(N, 1);
if ~isempty(options.Weights)
    assert(numel(options.Weights) == N, 'fitting:curveFit:weights', ...
        'Weights must have %d elements.', N);
    w = options.Weights(:);
end

freeIdx = find(~fixed);
nFree = numel(freeIdx);

if isempty(options.MaxIter)
    maxIter = 5000 * max(nFree, 1);
else
    maxIter = options.MaxIter;
end

% Clamp p0 to be within bounds
p0 = max(p0, lb);
p0 = min(p0, ub);

% ════════════════════════════════════════════════════════════════════════
% Parameter transform (bounded → unbounded for optimizer)
% ════════════════════════════════════════════════════════════════════════

    function pFree = toFree(pBounded)
        % Transform bounded parameters to unbounded space
        pSub = pBounded(freeIdx);
        lbSub = lb(freeIdx);
        ubSub = ub(freeIdx);
        pFree = zeros(1, nFree);
        for k = 1:nFree
            pFree(k) = boundToFree(pSub(k), lbSub(k), ubSub(k));
        end
    end

    function pBounded = fromFree(pFree)
        % Transform unbounded optimizer space back to bounded params
        pBounded = p0;  % start from p0 (fixed/constrained params stay at p0)
        lbSub = lb(freeIdx);
        ubSub = ub(freeIdx);
        for k = 1:nFree
            pBounded(freeIdx(k)) = freeToBound(pFree(k), lbSub(k), ubSub(k));
        end
        % Evaluate constraint expressions to fill in constrained parameters
        if useConstraints
            pBounded = applyConstraintExprs(pBounded);
        end
    end

    function pFull = applyConstraintExprs(pCurrent)
        % Fill constrained parameters by evaluating their expressions.
        % pCurrent already has free params in place; constrained slots get computed.
        pFreeVals = pCurrent(freeIdx);
        try
            pFull = fitting.applyConstraints(pFreeVals, constraintExprs, paramNamesForConstraints);
        catch
            % On failure, return pCurrent unchanged (optimizer will see bad cost)
            pFull = pCurrent;
        end
    end

% ════════════════════════════════════════════════════════════════════════
% Cost function (weighted sum of squared residuals)
% ════════════════════════════════════════════════════════════════════════

    function cost = costFcn(pFree)
        pFull = fromFree(pFree);
        yModel = modelFcn(xData, pFull);
        r = (yData - yModel) .* sqrt(w);
        cost = sum(r.^2);
    end

% ════════════════════════════════════════════════════════════════════════
% Run optimizer
% ════════════════════════════════════════════════════════════════════════

pFree0 = toFree(p0);

opts = optimset('MaxFunEvals', maxIter * 2, 'MaxIter', maxIter, ...
    'TolFun', options.TolFun, 'TolX', options.TolX, 'Display', 'off');

[pFreeOpt, fval, exitFlag, output] = fminsearch(@costFcn, pFree0, opts);

pOpt = fromFree(pFreeOpt);
yFit = modelFcn(xData, pOpt);
residuals = yData - yFit;

% ════════════════════════════════════════════════════════════════════════
% Goodness-of-fit statistics
% ════════════════════════════════════════════════════════════════════════

ssRes = sum(w .* residuals.^2);
ssTot = sum(w .* (yData - sum(w.*yData)/sum(w)).^2);
R2 = 1 - ssRes / max(ssTot, eps);

dof = N - nFree;
chiSqRed = ssRes / max(dof, 1);
RMSE = sqrt(ssRes / N);

% AIC: assuming Gaussian errors
logLik = -N/2 * log(2*pi*ssRes/N) - N/2;
AIC = 2*nFree - 2*logLik;

% ════════════════════════════════════════════════════════════════════════
% Parameter errors via numerical Hessian
% ════════════════════════════════════════════════════════════════════════

paramErrors = NaN(1, M);
covarMatrix = [];

if options.CalcErrors && nFree > 0 && dof > 0
    H = numericalHessian(@costFcn, pFreeOpt);
    try
        % Covariance in free space: inv(H/2) scaled by chi²_red
        covFree = inv(H/2) * chiSqRed; %#ok<MINV>
        if all(diag(covFree) >= 0)
            % Transform errors back to bounded space via Jacobian
            seFree = sqrt(diag(covFree))';
            for k = 1:nFree
                % d(pBound)/d(pFree) at optimum — chain rule for the transform
                jac = boundJacobian(pFreeOpt(k), lb(freeIdx(k)), ub(freeIdx(k)));
                paramErrors(freeIdx(k)) = seFree(k) * abs(jac);
            end
            % Full covariance in bounded space
            J = diag(arrayfun(@(k) boundJacobian(pFreeOpt(k), ...
                lb(freeIdx(k)), ub(freeIdx(k))), 1:nFree));
            covBound = J * covFree * J';
            covarMatrix = zeros(M);
            covarMatrix(freeIdx, freeIdx) = covBound;
        end
    catch
        % If Hessian is singular, errors remain NaN
    end
end

% ════════════════════════════════════════════════════════════════════════
% Assemble output
% ════════════════════════════════════════════════════════════════════════

result.params    = pOpt;
result.errors    = paramErrors;
result.covar     = covarMatrix;
result.residuals = residuals;
result.yFit      = yFit;
result.R2        = R2;
result.chiSqRed  = chiSqRed;
result.RMSE      = RMSE;
result.AIC       = AIC;
result.exitFlag  = exitFlag;
result.nIter     = output.iterations;
result.nFree     = nFree;
result.nPoints   = N;

end

% ════════════════════════════════════════════════════════════════════════
% Local functions — parameter transforms
% ════════════════════════════════════════════════════════════════════════

function pf = boundToFree(pb, lo, hi)
%BOUNDTOFREE  Map a bounded parameter to unbounded space.
    if lo == -Inf && hi == Inf
        pf = pb;                              % no bounds
    elseif lo > -Inf && hi == Inf
        pf = log(pb - lo + eps);              % lower bound only
    elseif lo == -Inf && hi < Inf
        pf = -log(hi - pb + eps);             % upper bound only
    else
        % Both bounds: logit transform
        t = (pb - lo) / (hi - lo);
        t = max(min(t, 1-eps), eps);          % clamp away from edges
        pf = log(t / (1 - t));
    end
end

function pb = freeToBound(pf, lo, hi)
%FREETOBOUND  Map an unbounded parameter back to bounded space.
    if lo == -Inf && hi == Inf
        pb = pf;
    elseif lo > -Inf && hi == Inf
        pb = lo + exp(pf);
    elseif lo == -Inf && hi < Inf
        pb = hi - exp(-pf);
    else
        pb = lo + (hi - lo) / (1 + exp(-pf));
    end
end

function jac = boundJacobian(pf, lo, hi)
%BOUNDJACOBIAN  d(pBound)/d(pFree) for error propagation.
    if lo == -Inf && hi == Inf
        jac = 1;
    elseif lo > -Inf && hi == Inf
        jac = exp(pf);
    elseif lo == -Inf && hi < Inf
        jac = exp(-pf);
    else
        s = 1 / (1 + exp(-pf));
        jac = (hi - lo) * s * (1 - s);
    end
end

% ════════════════════════════════════════════════════════════════════════
% Numerical Hessian via central finite differences
% ════════════════════════════════════════════════════════════════════════

function H = numericalHessian(fun, x0)
%NUMERICALHESSIAN  Central-difference Hessian of fun at x0.
    n = numel(x0);
    H = zeros(n);
    f0 = fun(x0);
    h = max(abs(x0) * 1e-4, 1e-6);

    for i = 1:n
        % Diagonal: f(x+h) - 2*f(x) + f(x-h)
        xp = x0; xp(i) = xp(i) + h(i);
        xm = x0; xm(i) = xm(i) - h(i);
        H(i,i) = (fun(xp) - 2*f0 + fun(xm)) / h(i)^2;

        % Off-diagonal: (f(x+hi+hj) - f(x+hi-hj) - f(x-hi+hj) + f(x-hi-hj)) / (4*hi*hj)
        for j = i+1:n
            xpp = x0; xpp(i) = xpp(i) + h(i); xpp(j) = xpp(j) + h(j);
            xpm = x0; xpm(i) = xpm(i) + h(i); xpm(j) = xpm(j) - h(j);
            xmp = x0; xmp(i) = xmp(i) - h(i); xmp(j) = xmp(j) + h(j);
            xmm = x0; xmm(i) = xmm(i) - h(i); xmm(j) = xmm(j) - h(j);
            H(i,j) = (fun(xpp) - fun(xpm) - fun(xmp) + fun(xmm)) / (4*h(i)*h(j));
            H(j,i) = H(i,j);
        end
    end
end
