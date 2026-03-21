function result = globalFit(datasets, modelFcn, p0, sharedMask, options)
%GLOBALFIT  Fit multiple datasets simultaneously with shared parameters.
%
%   result = fitting.globalFit(datasets, modelFcn, p0, sharedMask)
%
%   Fits the same model to N datasets in a single optimization. Some
%   parameters are shared (same value across all datasets) while others
%   are free per-dataset (optimized independently for each).
%
%   Inputs:
%       datasets   — cell array of {x, y} pairs or data structs
%       modelFcn   — function handle f(x, p) → y
%       p0         — [1×M] initial parameter vector (for one dataset)
%       sharedMask — [1×M] logical: true = shared across all datasets,
%                    false = free per dataset
%
%   Options:
%       Lower      — [1×M] lower bounds (applied to all)
%       Upper      — [1×M] upper bounds (applied to all)
%       Channel    — column index for data structs (default: 1)
%       Weights    — 'none' | '1/y' | '1/y2' (default: 'none')
%       Verbose    — print progress (default: true)
%
%   Output (struct):
%       .sharedParams  — [1×nShared] fitted shared parameter values
%       .perDataset    — [N×M] full parameter matrix (shared + per-dataset)
%       .sharedErrors  — [1×nShared] standard errors for shared params
%       .R2            — [N×1] per-dataset R² values
%       .R2global      — overall R² across all datasets
%       .chiSqRed      — reduced chi-squared (global)
%       .residuals     — cell array of per-dataset residual vectors
%       .nDatasets     — number of datasets
%       .paramNames    — {1×M} parameter names (if from catalog)
%       .sharedMask    — [1×M] logical mask used
%
%   Example:
%       % Fit exponential decay to 5 datasets: A free per dataset, τ and C shared
%       expFcn = @(x,p) p(1)*exp(-x./p(2)) + p(3);
%       shared = [false true true];  % τ, C shared; A free
%       r = fitting.globalFit(datasets, expFcn, [1 2 0], shared);
%       fprintf('Shared τ = %.2f ± %.2f\n', r.sharedParams(1), r.sharedErrors(1));
%       disp(r.perDataset(:,1));  % per-dataset A values

arguments
    datasets   cell
    modelFcn   function_handle
    p0         (1,:) double
    sharedMask (1,:) logical
    options.Lower   (1,:) double = []
    options.Upper   (1,:) double = []
    options.Channel (1,1) double = 1
    options.Weights (1,1) string {mustBeMember(options.Weights, ...
        ["none","1/y","1/y2"])} = "none"
    options.Verbose (1,1) logical = true
end

M = numel(p0);
N = numel(datasets);
assert(numel(sharedMask) == M, 'sharedMask must have %d elements.', M);

nShared = sum(sharedMask);
nFreePerDS = sum(~sharedMask);
sharedIdx = find(sharedMask);
freeIdx = find(~sharedMask);

% ════════════════════════════════════════════════════════════════════════
% Extract all datasets
% ════════════════════════════════════════════════════════════════════════

xAll = cell(N, 1);
yAll = cell(N, 1);
wAll = cell(N, 1);
nPts = zeros(N, 1);

for i = 1:N
    [xAll{i}, yAll{i}] = extractXY(datasets{i}, options.Channel);
    nPts(i) = numel(xAll{i});

    switch options.Weights
        case '1/y',  wAll{i} = 1 ./ max(abs(yAll{i}), eps);
        case '1/y2', wAll{i} = 1 ./ max(yAll{i}.^2, eps);
        otherwise,    wAll{i} = ones(nPts(i), 1);
    end
end

totalPts = sum(nPts);

% ════════════════════════════════════════════════════════════════════════
% Build super-parameter vector
% Layout: [shared_p1, shared_p2, ..., ds1_free1, ds1_free2, ..., ds2_free1, ...]
% ════════════════════════════════════════════════════════════════════════

nSuperParams = nShared + N * nFreePerDS;
superP0 = zeros(1, nSuperParams);

% Shared params
superP0(1:nShared) = p0(sharedIdx);

% Per-dataset free params (all start at same p0)
for i = 1:N
    offset = nShared + (i-1) * nFreePerDS;
    superP0(offset + (1:nFreePerDS)) = p0(freeIdx);
end

% Bounds
superLb = repmat(-Inf, 1, nSuperParams);
superUb = repmat(Inf, 1, nSuperParams);
if ~isempty(options.Lower)
    superLb(1:nShared) = options.Lower(sharedIdx);
    for i = 1:N
        offset = nShared + (i-1) * nFreePerDS;
        superLb(offset + (1:nFreePerDS)) = options.Lower(freeIdx);
    end
end
if ~isempty(options.Upper)
    superUb(1:nShared) = options.Upper(sharedIdx);
    for i = 1:N
        offset = nShared + (i-1) * nFreePerDS;
        superUb(offset + (1:nFreePerDS)) = options.Upper(freeIdx);
    end
end

% ════════════════════════════════════════════════════════════════════════
% Super-model function: dispatch to per-dataset segments
% ════════════════════════════════════════════════════════════════════════

    function yPred = superModel(xDummy, sp) %#ok<INUSL>
        % xDummy is the concatenated x; sp is the super-parameter vector
        yPred = zeros(totalPts, 1);
        sharedP = sp(1:nShared);
        pos = 0;
        for di = 1:N
            % Reconstruct full parameter vector for dataset di
            pFull = zeros(1, M);
            pFull(sharedIdx) = sharedP;
            dsOffset = nShared + (di-1) * nFreePerDS;
            pFull(freeIdx) = sp(dsOffset + (1:nFreePerDS));

            yPred(pos + (1:nPts(di))) = modelFcn(xAll{di}, pFull);
            pos = pos + nPts(di);
        end
    end

% Concatenated data
xConcat = vertcat(xAll{:});
yConcat = vertcat(yAll{:});
wConcat = vertcat(wAll{:});

% ════════════════════════════════════════════════════════════════════════
% Run global optimization via curveFit
% ════════════════════════════════════════════════════════════════════════

if options.Verbose
    fprintf('Global fit: %d datasets, %d shared + %d×%d free = %d total params\n', ...
        N, nShared, N, nFreePerDS, nSuperParams);
end

fitResult = fitting.curveFit(xConcat, yConcat, @superModel, superP0, ...
    Lower=superLb, Upper=superUb, Weights=wConcat, CalcErrors=true);

% ════════════════════════════════════════════════════════════════════════
% Unpack results
% ════════════════════════════════════════════════════════════════════════

spOpt = fitResult.params;
spErr = fitResult.errors;

% Shared parameters
sharedParams = spOpt(1:nShared);
sharedErrors = spErr(1:nShared);

% Per-dataset full parameter matrices
perDataset = zeros(N, M);
perErrors  = zeros(N, M);
residuals  = cell(N, 1);
R2perDS    = zeros(N, 1);

pos = 0;
for i = 1:N
    pFull = zeros(1, M);
    eFull = zeros(1, M);
    pFull(sharedIdx) = sharedParams;
    eFull(sharedIdx) = sharedErrors;
    dsOffset = nShared + (i-1) * nFreePerDS;
    pFull(freeIdx) = spOpt(dsOffset + (1:nFreePerDS));
    eFull(freeIdx) = spErr(dsOffset + (1:nFreePerDS));

    perDataset(i, :) = pFull;
    perErrors(i, :) = eFull;

    % Per-dataset residuals and R²
    yPred_i = modelFcn(xAll{i}, pFull);
    residuals{i} = yAll{i} - yPred_i;
    ssTot = sum((yAll{i} - mean(yAll{i})).^2);
    ssRes = sum(residuals{i}.^2);
    R2perDS(i) = 1 - ssRes / max(ssTot, eps);

    if options.Verbose
        fprintf('  [%d/%d] R²=%.4f  params=[%s]\n', i, N, R2perDS(i), ...
            strjoin(arrayfun(@(v) sprintf('%.4g',v), pFull, 'UniformOutput', false), ', '));
    end
end

% ════════════════════════════════════════════════════════════════════════
% Output
% ════════════════════════════════════════════════════════════════════════

result.sharedParams = sharedParams;
result.sharedErrors = sharedErrors;
result.perDataset   = perDataset;
result.perErrors    = perErrors;
result.R2           = R2perDS;
result.R2global     = fitResult.R2;
result.chiSqRed     = fitResult.chiSqRed;
result.residuals    = residuals;
result.nDatasets    = N;
result.sharedMask   = sharedMask;
result.exitFlag     = fitResult.exitFlag;
result.nParams      = nSuperParams;

end

% ════════════════════════════════════════════════════════════════════════

function [x, y] = extractXY(ds, channel)
    if isstruct(ds)
        if isfield(ds, 'corrData') && ~isempty(ds.corrData) && ...
                isfield(ds.corrData, 'time') && ~isempty(ds.corrData.time)
            plotD = ds.corrData;
        elseif isfield(ds, 'data')
            plotD = ds.data;
        elseif isfield(ds, 'time')
            plotD = ds;
        else
            x = []; y = []; return;
        end
        x = plotD.time(:);
        ch = min(channel, size(plotD.values, 2));
        y = plotD.values(:, ch);
    elseif iscell(ds) && numel(ds) >= 2
        x = ds{1}(:);
        y = ds{2}(:);
    else
        x = []; y = [];
    end
end
