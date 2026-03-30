function result = surfaceFit(xData, yData, zData, model, options)
%SURFACEFIT  Fit a 2D model z = f(x,y) to scattered or gridded data.
%
%   Syntax
%     result = fitting.surfaceFit(xData, yData, zData, model)
%     result = fitting.surfaceFit(xData, yData, zData, model, InitGuess=p0)
%     result = fitting.surfaceFit(xData, yData, zData, model, ...
%                                 LowerBound=lb, UpperBound=ub, MaxIter=N)
%
%   Inputs
%     xData  — [N×1] or matrix of x coordinates (meshgrid matrices are flattened)
%     yData  — [N×1] or matrix of y coordinates (meshgrid matrices are flattened)
%     zData  — [N×1] or matrix of z values
%     model  — string name from fitting.surfaceModels(), or struct with
%              fields .func (function handle f(p,x,y)→z) and .paramNames
%
%   Options (name-value)
%     InitGuess  — [1×P] initial parameter vector (auto-guessed if omitted)
%     LowerBound — [1×P] lower bounds (default: -Inf)
%     UpperBound — [1×P] upper bounds (default: +Inf)
%     MaxIter    — max optimizer iterations (default: 10000)
%
%   Output (struct)
%     .params     — [1×P] best-fit parameters
%     .paramNames — {P×1} parameter names
%     .errors     — [1×P] parameter standard errors (NaN if not computable)
%     .residuals  — [N×1] zData - zFit
%     .zFit       — [N×1] model evaluated at fitted params
%     .R2         — coefficient of determination
%     .RMSE       — root mean square error
%     .covar      — [P×P] covariance matrix ([] if not computable)
%     .chiSqRed   — reduced chi-squared
%     .modelName  — string
%     .modelFcn   — function handle f(p, x, y) → z
%     .exitFlag   — fminsearch exit condition (1 = converged)
%     .nPoints    — number of data points
%     .nFree      — number of free parameters
%
%   Examples
%     % Fit a 2D Gaussian to synthetic data
%     [X,Y] = meshgrid(-5:0.5:5, -5:0.5:5);
%     Z = 3*exp(-X.^2/2 - Y.^2/2);
%     result = fitting.surfaceFit(X, Y, Z, '2D Gaussian');
%     fprintf('Center: (%.3f, %.3f)\n', result.params(2), result.params(4));

arguments
    xData  double
    yData  double
    zData  double
    model  % string or struct — validated below
    options.InitGuess  (1,:) double = []
    options.LowerBound (1,:) double = []
    options.UpperBound (1,:) double = []
    options.MaxIter    double = 10000
end

% ════════════════════════════════════════════════════════════════════════
% Flatten meshgrid inputs to column vectors
% ════════════════════════════════════════════════════════════════════════
x = xData(:);
y = yData(:);
z = zData(:);
N = numel(z);

assert(numel(x) == N && numel(y) == N, 'fitting:surfaceFit:sizeMismatch', ...
    'xData, yData, and zData must have the same number of elements.');
assert(N >= 2, 'fitting:surfaceFit:tooFewPoints', ...
    'At least 2 data points required.');

% ════════════════════════════════════════════════════════════════════════
% Resolve model: string name or struct with .func / .paramNames
% ════════════════════════════════════════════════════════════════════════
if ischar(model) || isstring(model)
    modelName = char(model);
    catalog   = fitting.surfaceModels();
    idx = find(strcmp({catalog.name}, modelName), 1);
    if isempty(idx)
        error('fitting:surfaceFit:unknownModel', ...
            'Model "%s" not found. Use fitting.surfaceModels() to list available models.', modelName);
    end
    modelFcn    = catalog(idx).func;
    paramNames  = catalog(idx).paramNames;
    nP          = catalog(idx).nParams;
elseif isstruct(model) && isfield(model, 'func') && isfield(model, 'paramNames')
    modelName  = 'Custom';
    modelFcn   = model.func;
    paramNames = model.paramNames;
    nP         = numel(paramNames);
else
    error('fitting:surfaceFit:invalidModel', ...
        'model must be a string name or a struct with .func and .paramNames fields.');
end

assert(N >= nP, 'fitting:surfaceFit:tooFewPoints', ...
    'Model "%s" requires at least %d data points (got %d).', modelName, nP, N);

% ════════════════════════════════════════════════════════════════════════
% Initial guess and bounds
% ════════════════════════════════════════════════════════════════════════
if isempty(options.InitGuess)
    if strcmp(modelName, 'Custom')
        p0 = ones(1, nP);   % no catalog entry — caller should supply InitGuess
    else
        p0 = fitting.surfaceAutoGuess(string(modelName), x, y, z);
    end
else
    assert(numel(options.InitGuess) == nP, 'fitting:surfaceFit:initGuessDim', ...
        'InitGuess must have %d elements for model "%s".', nP, modelName);
    p0 = options.InitGuess(:)';
end

lb = repmat(-Inf, 1, nP);
ub = repmat(Inf, 1, nP);
if ~isempty(options.LowerBound)
    assert(numel(options.LowerBound) == nP, 'fitting:surfaceFit:boundsDim', ...
        'LowerBound must have %d elements.', nP);
    lb = options.LowerBound(:)';
end
if ~isempty(options.UpperBound)
    assert(numel(options.UpperBound) == nP, 'fitting:surfaceFit:boundsDim', ...
        'UpperBound must have %d elements.', nP);
    ub = options.UpperBound(:)';
end

% Clamp p0 to bounds
p0 = max(p0, lb);
p0 = min(p0, ub);

% ════════════════════════════════════════════════════════════════════════
% Parameter transforms (bounded → unbounded for fminsearch)
% ════════════════════════════════════════════════════════════════════════
    function pf = toFree(pb)
        pf = zeros(1, nP);
        for k = 1:nP
            pf(k) = boundToFree(pb(k), lb(k), ub(k));
        end
    end

    function pb = fromFree(pf)
        pb = zeros(1, nP);
        for k = 1:nP
            pb(k) = freeToBound(pf(k), lb(k), ub(k));
        end
    end

% ════════════════════════════════════════════════════════════════════════
% Cost function
% ════════════════════════════════════════════════════════════════════════
    function cost = costFcn(pFree)
        pFull = fromFree(pFree);
        zModel = modelFcn(pFull, x, y);
        r = z - zModel(:);
        cost = sum(r.^2);
    end

% ════════════════════════════════════════════════════════════════════════
% Run optimizer
% ════════════════════════════════════════════════════════════════════════
pFree0 = toFree(p0);

opts = optimset('MaxFunEvals', options.MaxIter * 2, ...
                'MaxIter',     options.MaxIter, ...
                'TolFun',      1e-12, ...
                'TolX',        1e-10, ...
                'Display',     'off');

[pFreeOpt, ~, exitFlag] = fminsearch(@costFcn, pFree0, opts);

pOpt = fromFree(pFreeOpt);
zFit = modelFcn(pOpt, x, y);
zFit = zFit(:);
residuals = z - zFit;

% ════════════════════════════════════════════════════════════════════════
% Goodness-of-fit statistics
% ════════════════════════════════════════════════════════════════════════
ssRes  = sum(residuals.^2);
ssTot  = sum((z - mean(z)).^2);
R2     = 1 - ssRes / max(ssTot, eps);
dof    = N - nP;
chiSqRed = ssRes / max(dof, 1);
RMSE   = sqrt(ssRes / N);

% ════════════════════════════════════════════════════════════════════════
% Parameter errors via numerical Hessian
% ════════════════════════════════════════════════════════════════════════
paramErrors = NaN(1, nP);
covarMatrix = [];

if dof > 0
    H = numericalHessian(@costFcn, pFreeOpt);
    try
        covFree = inv(H/2) * chiSqRed; %#ok<MINV>
        if all(diag(covFree) >= 0)
            seFree = sqrt(diag(covFree))';
            for k = 1:nP
                jac = boundJacobian(pFreeOpt(k), lb(k), ub(k));
                paramErrors(k) = seFree(k) * abs(jac);
            end
            J = diag(arrayfun(@(k) boundJacobian(pFreeOpt(k), lb(k), ub(k)), 1:nP));
            covarMatrix = J * covFree * J';
        end
    catch
        % Hessian singular — errors remain NaN
    end
end

% ════════════════════════════════════════════════════════════════════════
% Assemble output
% ════════════════════════════════════════════════════════════════════════
result.params     = pOpt;
result.paramNames = paramNames;
result.errors     = paramErrors;
result.residuals  = residuals;
result.zFit       = zFit;
result.R2         = R2;
result.RMSE       = RMSE;
result.covar      = covarMatrix;
result.chiSqRed   = chiSqRed;
result.modelName  = modelName;
result.modelFcn   = modelFcn;
result.exitFlag   = exitFlag;
result.nPoints    = N;
result.nFree      = nP;

end

% ════════════════════════════════════════════════════════════════════════
% Local functions — parameter transforms (same logic as curveFit.m)
% ════════════════════════════════════════════════════════════════════════

function pf = boundToFree(pb, lo, hi)
    if lo == -Inf && hi == Inf
        pf = pb;
    elseif lo > -Inf && hi == Inf
        pf = log(pb - lo + eps);
    elseif lo == -Inf && hi < Inf
        pf = -log(hi - pb + eps);
    else
        t = (pb - lo) / (hi - lo);
        t = max(min(t, 1-eps), eps);
        pf = log(t / (1 - t));
    end
end

function pb = freeToBound(pf, lo, hi)
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
    n  = numel(x0);
    H  = zeros(n);
    f0 = fun(x0);
    h  = max(abs(x0) * 1e-4, 1e-6);

    for i = 1:n
        xp = x0; xp(i) = xp(i) + h(i);
        xm = x0; xm(i) = xm(i) - h(i);
        H(i,i) = (fun(xp) - 2*f0 + fun(xm)) / h(i)^2;
        for j = i+1:n
            xpp = x0; xpp(i) = xpp(i)+h(i); xpp(j) = xpp(j)+h(j);
            xpm = x0; xpm(i) = xpm(i)+h(i); xpm(j) = xpm(j)-h(j);
            xmp = x0; xmp(i) = xmp(i)-h(i); xmp(j) = xmp(j)+h(j);
            xmm = x0; xmm(i) = xmm(i)-h(i); xmm(j) = xmm(j)-h(j);
            H(i,j) = (fun(xpp) - fun(xpm) - fun(xmp) + fun(xmm)) / (4*h(i)*h(j));
            H(j,i) = H(i,j);
        end
    end
end
