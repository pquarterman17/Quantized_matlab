function results = globalCurveFit(datasets, models, constraints, options)
%GLOBALCURVEFIT  Simultaneously fit models to multiple datasets with shared parameters.
%
%   Syntax:
%       results = fitting.globalCurveFit(datasets, models, constraints)
%       results = fitting.globalCurveFit(datasets, models, constraints, Name=Value, ...)
%
%   Inputs:
%       datasets    — {1×K} cell array, each cell is a struct with .x [N×1] and
%                     .y [N×1], OR a {x, y} two-element cell pair.
%       models      — {1×K} cell array of model structs from fitting.models(), OR
%                     a single model struct applied identically to all datasets.
%       constraints — struct array defining shared parameters:
%                       .paramName  — string matching a name in the model's .paramNames
%                       .datasets   — [1×M] integer indices of datasets that share
%                                     this parameter (e.g. [1 2 3]).
%                     Parameters not listed are treated as free per dataset.
%                     Pass empty ([]) to use no shared parameters.
%
%   Options (Name=Value):
%       InitGuess   — {1×K} cell, each [1×P] initial guess vector per dataset.
%                     When omitted, fitting.autoGuess is called per dataset.
%       LowerBound  — {1×K} cell, each [1×P] lower bound vector per dataset.
%                     Scalar cell {lb} broadcasts to all datasets.
%       UpperBound  — {1×K} cell, each [1×P] upper bound vector per dataset.
%                     Scalar cell {ub} broadcasts to all datasets.
%       MaxIter     — max fminsearch iterations (default: 20000)
%       Weights     — {1×K} cell, each [N×1] weight vector (default: uniform)
%       TolFun      — function tolerance (default: 1e-12)
%       TolX        — parameter tolerance (default: 1e-10)
%
%   Output (struct):
%       .params     — {1×K} cell, each [1×P] fitted parameter vector per dataset
%       .errors     — {1×K} cell, each [1×P] parameter standard errors per dataset
%       .shared     — struct array with .name, .value, .error for each shared group
%       .residuals  — {1×K} cell of residual vectors
%       .yFit       — {1×K} cell of fitted y vectors (same x as input)
%       .R2         — [1×K] per-dataset R²
%       .RMSE       — [1×K] per-dataset RMSE
%       .chiSqRed   — global reduced chi-squared
%       .covar      — [T×T] global covariance matrix (T = total super-params)
%       .nTotal     — total data points across all datasets
%       .nFree      — total free super-parameters
%       .exitFlag   — fminsearch exit flag
%
%   Examples:
%       % Three Gaussian datasets with shared sigma, independent centers/amplitudes
%       m = fitting.models();
%       gauss = m(strcmp({m.name}, 'Gaussian'));
%       c(1).paramName = 'sigma';  c(1).datasets = [1 2 3];
%       r = fitting.globalCurveFit(datasets, gauss, c);
%       fprintf('Shared sigma = %.3f\n', r.shared(1).value);
%
%       % No shared params — equivalent to batch independent fits
%       r = fitting.globalCurveFit(datasets, gauss, []);

arguments
    datasets   (1,:) cell
    models                          % model struct OR {1×K} cell of model structs
    constraints                     % struct array OR []
    options.InitGuess  cell = {}
    options.LowerBound cell = {}
    options.UpperBound cell = {}
    options.MaxIter    (1,1) double = 20000
    options.Weights    cell = {}
    options.TolFun     (1,1) double = 1e-12
    options.TolX       (1,1) double = 1e-10
end

K = numel(datasets);
assert(K >= 1, 'fitting:globalCurveFit:noData', 'Need at least one dataset.');

% ════════════════════════════════════════════════════════════════════════
% Normalise models argument to a {1×K} cell
% ════════════════════════════════════════════════════════════════════════

if isstruct(models)
    % Single model struct — broadcast to all datasets
    modelCell = repmat({models}, 1, K);
elseif iscell(models)
    assert(numel(models) == K, ...
        'fitting:globalCurveFit:modelMismatch', ...
        'models cell must have %d elements (one per dataset).', K);
    modelCell = models;
else
    error('fitting:globalCurveFit:badModels', ...
        'models must be a model struct or {1×K} cell of model structs.');
end

% All models must have the same number of parameters (P)
P = modelCell{1}.nParams;
for ki = 2:K
    assert(modelCell{ki}.nParams == P, ...
        'fitting:globalCurveFit:paramCountMismatch', ...
        'All models must have the same number of parameters (%d vs %d).', ...
        P, modelCell{ki}.nParams);
end

% ════════════════════════════════════════════════════════════════════════
% Extract x/y/w per dataset
% ════════════════════════════════════════════════════════════════════════

xAll = cell(1, K);
yAll = cell(1, K);
wAll = cell(1, K);
nPts = zeros(1, K);

for ki = 1:K
    [xAll{ki}, yAll{ki}] = extractXY(datasets{ki});
    nPts(ki) = numel(xAll{ki});

    if numel(options.Weights) >= ki && ~isempty(options.Weights{ki})
        w = options.Weights{ki}(:);
        assert(numel(w) == nPts(ki), ...
            'fitting:globalCurveFit:weightLen', ...
            'Weights{%d} must have %d elements.', ki, nPts(ki));
        wAll{ki} = w;
    else
        wAll{ki} = ones(nPts(ki), 1);
    end
end

nTotal = sum(nPts);

% ════════════════════════════════════════════════════════════════════════
% Build initial guesses and bounds per dataset
% ════════════════════════════════════════════════════════════════════════

p0Cell = cell(1, K);
lbCell = cell(1, K);
ubCell = cell(1, K);

for ki = 1:K
    m = modelCell{ki};

    % Initial guess
    if numel(options.InitGuess) >= ki && ~isempty(options.InitGuess{ki})
        p0Cell{ki} = options.InitGuess{ki}(:)';
    else
        try
            p0Cell{ki} = fitting.autoGuess(m.name, xAll{ki}, yAll{ki});
        catch
            p0Cell{ki} = m.p0;
        end
    end

    % Lower bounds
    if numel(options.LowerBound) == 1
        lbCell{ki} = options.LowerBound{1}(:)';
    elseif numel(options.LowerBound) >= ki && ~isempty(options.LowerBound{ki})
        lbCell{ki} = options.LowerBound{ki}(:)';
    else
        lbCell{ki} = m.lb;
    end

    % Upper bounds
    if numel(options.UpperBound) == 1
        ubCell{ki} = options.UpperBound{1}(:)';
    elseif numel(options.UpperBound) >= ki && ~isempty(options.UpperBound{ki})
        ubCell{ki} = options.UpperBound{ki}(:)';
    else
        ubCell{ki} = m.ub;
    end

    % Clamp p0 to bounds
    p0Cell{ki} = max(p0Cell{ki}, lbCell{ki});
    p0Cell{ki} = min(p0Cell{ki}, ubCell{ki});
end

% ════════════════════════════════════════════════════════════════════════
% Build the "sharing map" from constraints
%
% sharing(g).paramIdx  — parameter index (1..P) in the model
% sharing(g).datasets  — sorted dataset indices that share this group
%
% A (dataset, param) pair maps to exactly one super-param slot.
% Layout of the super-vector:
%   [shared_group_1, shared_group_2, ..., ds1_param_1, ds1_param_2, ..., dsK_param_P]
% where only non-shared (dataset, param) slots appear in the per-dataset block.
% ════════════════════════════════════════════════════════════════════════

% Parse constraints into a normalized struct array
nGroups = 0;
sharing = struct('paramIdx', {}, 'paramName', {}, 'datasets', {});

if ~isempty(constraints)
    for ci = 1:numel(constraints)
        c = constraints(ci);
        pName = string(c.paramName);
        dsIdxList = sort(unique(c.datasets(:)'));

        % Resolve param name to index
        pNames = modelCell{1}.paramNames;
        pIdx = find(strcmp(pNames, char(pName)), 1);
        assert(~isempty(pIdx), ...
            'fitting:globalCurveFit:unknownParam', ...
            'Parameter "%s" not found in model "%s".', ...
            pName, modelCell{1}.name);

        assert(all(dsIdxList >= 1) && all(dsIdxList <= K), ...
            'fitting:globalCurveFit:badDsIdx', ...
            'Constraint dataset indices must be in [1, %d].', K);

        % Only meaningful if 2+ datasets share it
        if numel(dsIdxList) < 2
            continue;
        end

        nGroups = nGroups + 1;
        sharing(nGroups).paramIdx  = pIdx;
        sharing(nGroups).paramName = char(pName);
        sharing(nGroups).datasets  = dsIdxList;
    end
end

% Build a map: (dataset ki, param pi) → super-param index
% isShared(ki, pi) = true if this (ki, pi) pair is in a sharing group
isShared   = false(K, P);
groupOf    = zeros(K, P);   % which group index (0 = not shared)
groupStart = nGroups;       % super-params start with nGroups shared values

for g = 1:nGroups
    pIdx = sharing(g).paramIdx;
    for ki2 = sharing(g).datasets
        isShared(ki2, pIdx) = true;
        groupOf(ki2, pIdx)  = g;
    end
end

% Assign super-param indices
%   Positions 1..nGroups  → shared parameter values
%   Positions nGroups+1.. → free per-(dataset,param) slots
superIdx = zeros(K, P);  % superIdx(ki,pi) = index in super-vector
nextFree = nGroups + 1;

for g = 1:nGroups
    pIdx = sharing(g).paramIdx;
    for ki2 = sharing(g).datasets
        superIdx(ki2, pIdx) = g;
    end
end

for ki = 1:K
    for pi = 1:P
        if ~isShared(ki, pi)
            superIdx(ki, pi) = nextFree;
            nextFree = nextFree + 1;
        end
    end
end

nSuperParams = nextFree - 1;

% ════════════════════════════════════════════════════════════════════════
% Build super-parameter initial guess and bounds
% ════════════════════════════════════════════════════════════════════════

superP0 = zeros(1, nSuperParams);
superLb = repmat(-Inf, 1, nSuperParams);
superUb = repmat(Inf, 1, nSuperParams);

% Shared groups: average the initial guesses from participating datasets
for g = 1:nGroups
    pIdx = sharing(g).paramIdx;
    vals = arrayfun(@(ki2) p0Cell{ki2}(pIdx), sharing(g).datasets);
    lbs  = arrayfun(@(ki2) lbCell{ki2}(pIdx), sharing(g).datasets);
    ubs  = arrayfun(@(ki2) ubCell{ki2}(pIdx), sharing(g).datasets);
    superP0(g) = mean(vals);
    superLb(g) = max(lbs);  % tightest lower bound wins
    superUb(g) = min(ubs);  % tightest upper bound wins
    % Clamp averaged guess to combined bounds
    superP0(g) = max(superP0(g), superLb(g));
    superP0(g) = min(superP0(g), superUb(g));
end

% Independent (non-shared) slots
for ki = 1:K
    for pi = 1:P
        if ~isShared(ki, pi)
            si = superIdx(ki, pi);
            superP0(si) = p0Cell{ki}(pi);
            superLb(si) = lbCell{ki}(pi);
            superUb(si) = ubCell{ki}(pi);
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
% Parameter transform helpers (bounded ↔ unbounded)
% ════════════════════════════════════════════════════════════════════════

    function pf = toFreeAll(pb)
        pf = zeros(1, nSuperParams);
        for si = 1:nSuperParams
            pf(si) = boundToFree(pb(si), superLb(si), superUb(si));
        end
    end

    function pb = fromFreeAll(pf)
        pb = zeros(1, nSuperParams);
        for si = 1:nSuperParams
            pb(si) = freeToBound(pf(si), superLb(si), superUb(si));
        end
    end

% ════════════════════════════════════════════════════════════════════════
% Expand super-parameter vector into per-dataset parameter vectors
% ════════════════════════════════════════════════════════════════════════

    function pList = expandParams(sp)
        pList = cell(1, K);
        for ki3 = 1:K
            pList{ki3} = zeros(1, P);
            for pi = 1:P
                pList{ki3}(pi) = sp(superIdx(ki3, pi));
            end
        end
    end

% ════════════════════════════════════════════════════════════════════════
% Cost function: sum of weighted squared residuals across all datasets
% ════════════════════════════════════════════════════════════════════════

    function cost = costFcn(pFree)
        sp = fromFreeAll(pFree);
        pList = expandParams(sp);
        cost = 0;
        for ki4 = 1:K
            yModel = modelCell{ki4}.fcn(xAll{ki4}, pList{ki4});
            r = (yAll{ki4} - yModel) .* sqrt(wAll{ki4});
            cost = cost + sum(r .^ 2);
        end
    end

% ════════════════════════════════════════════════════════════════════════
% Run optimizer on the super-vector
% ════════════════════════════════════════════════════════════════════════

pFree0 = toFreeAll(superP0);

fmOpts = optimset( ...
    'MaxFunEvals', options.MaxIter * 4, ...
    'MaxIter',     options.MaxIter, ...
    'TolFun',      options.TolFun, ...
    'TolX',        options.TolX, ...
    'Display',     'off');

[pFreeOpt, ~, exitFlag] = fminsearch(@costFcn, pFree0, fmOpts);

spOpt = fromFreeAll(pFreeOpt);
pListOpt = expandParams(spOpt);

% ════════════════════════════════════════════════════════════════════════
% Parameter errors via numerical Hessian of the cost in free space
% ════════════════════════════════════════════════════════════════════════

% Total residuals for chi²_red
ssResTotal = 0;
for ki = 1:K
    yModel = modelCell{ki}.fcn(xAll{ki}, pListOpt{ki});
    r = (yAll{ki} - yModel) .* sqrt(wAll{ki});
    ssResTotal = ssResTotal + sum(r .^ 2);
end

dof = nTotal - nSuperParams;
chiSqRed = ssResTotal / max(dof, 1);

superErrors = NaN(1, nSuperParams);
covarMatrix = [];

if nSuperParams > 0 && dof > 0
    H = numericalHessian(@costFcn, pFreeOpt);
    try
        covFree = inv(H / 2) * chiSqRed; %#ok<MINV>
        if all(diag(covFree) >= 0)
            seFree = sqrt(diag(covFree))';
            for si = 1:nSuperParams
                jac = boundJacobian(pFreeOpt(si), superLb(si), superUb(si));
                superErrors(si) = seFree(si) * abs(jac);
            end
            J = diag(arrayfun(@(si) boundJacobian(pFreeOpt(si), ...
                superLb(si), superUb(si)), 1:nSuperParams));
            covarMatrix = J * covFree * J';
        end
    catch
        % Singular Hessian — errors remain NaN
    end
end

% ════════════════════════════════════════════════════════════════════════
% Expand errors into per-dataset error vectors
% ════════════════════════════════════════════════════════════════════════

errListOpt = cell(1, K);
for ki = 1:K
    errListOpt{ki} = zeros(1, P);
    for pi = 1:P
        errListOpt{ki}(pi) = superErrors(superIdx(ki, pi));
    end
end

% ════════════════════════════════════════════════════════════════════════
% Per-dataset goodness-of-fit statistics
% ════════════════════════════════════════════════════════════════════════

residCell = cell(1, K);
yFitCell  = cell(1, K);
R2vec     = zeros(1, K);
RMSEvec   = zeros(1, K);

for ki = 1:K
    yModel = modelCell{ki}.fcn(xAll{ki}, pListOpt{ki});
    yFitCell{ki}  = yModel;
    residCell{ki} = yAll{ki} - yModel;

    ssRes = sum(wAll{ki} .* residCell{ki}.^2);
    ssTot = sum(wAll{ki} .* (yAll{ki} - ...
        sum(wAll{ki} .* yAll{ki}) / sum(wAll{ki})).^2);
    R2vec(ki)   = 1 - ssRes / max(ssTot, eps);
    RMSEvec(ki) = sqrt(ssRes / nPts(ki));
end

% ════════════════════════════════════════════════════════════════════════
% Build .shared summary output
% ════════════════════════════════════════════════════════════════════════

sharedOut = struct('name', {}, 'paramIdx', {}, 'datasets', {}, ...
    'value', {}, 'error', {});
for g = 1:nGroups
    sharedOut(g).name     = sharing(g).paramName;
    sharedOut(g).paramIdx = sharing(g).paramIdx;
    sharedOut(g).datasets = sharing(g).datasets;
    sharedOut(g).value    = spOpt(g);
    sharedOut(g).error    = superErrors(g);
end

% ════════════════════════════════════════════════════════════════════════
% Assemble output
% ════════════════════════════════════════════════════════════════════════

results.params    = pListOpt;
results.errors    = errListOpt;
results.shared    = sharedOut;
results.residuals = residCell;
results.yFit      = yFitCell;
results.R2        = R2vec;
results.RMSE      = RMSEvec;
results.chiSqRed  = chiSqRed;
results.covar     = covarMatrix;
results.nTotal    = nTotal;
results.nFree     = nSuperParams;
results.exitFlag  = exitFlag;

end

% ════════════════════════════════════════════════════════════════════════
% Local: extract x/y from a dataset (struct with .x/.y, or {x,y} cell)
% ════════════════════════════════════════════════════════════════════════

function [x, y] = extractXY(ds)
    if isstruct(ds)
        if isfield(ds, 'x') && isfield(ds, 'y')
            x = ds.x(:);
            y = ds.y(:);
        elseif isfield(ds, 'time') && isfield(ds, 'values')
            x = ds.time(:);
            y = ds.values(:, 1);
        else
            error('fitting:globalCurveFit:badDataset', ...
                'Dataset struct must have fields .x/.y or .time/.values.');
        end
    elseif iscell(ds) && numel(ds) >= 2
        x = ds{1}(:);
        y = ds{2}(:);
    else
        error('fitting:globalCurveFit:badDataset', ...
            'Each dataset must be a struct with .x/.y or a {x,y} cell.');
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local: bounded ↔ unbounded parameter transforms (same as curveFit.m)
% ════════════════════════════════════════════════════════════════════════

function pf = boundToFree(pb, lo, hi)
    if lo == -Inf && hi == Inf
        pf = pb;
    elseif lo > -Inf && hi == Inf
        pf = log(pb - lo + eps);
    elseif lo == -Inf && hi < Inf
        pf = -log(hi - pb + eps);
    else
        t  = (pb - lo) / (hi - lo);
        t  = max(min(t, 1-eps), eps);
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
        s   = 1 / (1 + exp(-pf));
        jac = (hi - lo) * s * (1 - s);
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local: central-difference numerical Hessian
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
            xpp = x0; xpp(i) = xpp(i) + h(i); xpp(j) = xpp(j) + h(j);
            xpm = x0; xpm(i) = xpm(i) + h(i); xpm(j) = xpm(j) - h(j);
            xmp = x0; xmp(i) = xmp(i) - h(i); xmp(j) = xmp(j) + h(j);
            xmm = x0; xmm(i) = xmm(i) - h(i); xmm(j) = xmm(j) - h(j);
            H(i,j) = (fun(xpp) - fun(xpm) - fun(xmp) + fun(xmm)) / (4*h(i)*h(j));
            H(j,i) = H(i,j);
        end
    end
end
