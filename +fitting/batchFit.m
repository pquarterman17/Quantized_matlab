function summary = batchFit(datasets, modelFcn, p0, options)
%BATCHFIT  Run the same curve fit across multiple datasets.
%
%   summary = fitting.batchFit(datasets, modelFcn, p0)
%   summary = fitting.batchFit(datasets, modelFcn, p0, Lower=lb, Upper=ub)
%   summary = fitting.batchFit(datasets, modelFcn, p0, ModelName='Exp Decay')
%
%   Fits the same model to each dataset and collects results into a
%   parameter summary table for trend analysis.
%
%   Inputs:
%       datasets — cell array of data structs (each with .time, .values)
%                  OR cell array of {x, y} pairs: {{x1,y1}, {x2,y2}, ...}
%       modelFcn — function handle f(x, p) → y
%       p0       — [1×M] initial parameter vector (or 'auto' with ModelName)
%
%   Options:
%       Lower      — [1×M] lower bounds (default: -Inf)
%       Upper      — [1×M] upper bounds (default: +Inf)
%       Fixed      — [1×M] logical mask for fixed parameters
%       Channel    — column index for .values in data structs (default: 1)
%       ModelName  — string name from fitting.models() for auto-guess
%       MetaField  — metadata field name to extract for trend plotting
%                    (e.g. 'temperature', accesses ds.metadata.temperature)
%       XRange     — [xMin xMax] restrict fit to this x-range (default: all)
%       Weights    — 'none' | '1/y' | '1/y2' (default: 'none')
%       Verbose    — print progress (default: true)
%
%   Output (struct):
%       .params      — [N×M] fitted parameters (one row per dataset)
%       .errors      — [N×M] parameter standard errors
%       .R2          — [N×1] R² values
%       .chiSqRed    — [N×1] reduced chi-squared
%       .RMSE        — [N×1] root mean squared error
%       .AIC         — [N×1] Akaike information criterion
%       .exitFlags   — [N×1] fminsearch exit flags
%       .paramNames  — {1×M} parameter name cell array
%       .modelName   — model name string
%       .metaValues  — [N×1] extracted metadata (NaN if not available)
%       .nDatasets   — number of datasets
%       .converged   — [N×1] logical (exitFlag == 1)
%
%   Examples:
%       % Fit exponential decay to 10 temperature scans
%       cat = fitting.models();
%       m = cat(strcmp({cat.name}, 'Exponential Decay'));
%       s = fitting.batchFit(datasets, m.fcn, m.p0, ...
%           Lower=m.lb, Upper=m.ub, ModelName='Exponential Decay', ...
%           MetaField='temperature');
%       plot(s.metaValues, s.params(:,2), 'o-');  % τ vs T
%
%       % Fit custom function to {x,y} pairs
%       data = {{x1,y1}, {x2,y2}, {x3,y3}};
%       s = fitting.batchFit(data, @(x,p) p(1)*x.^p(2), [1 1]);

arguments
    datasets   cell
    modelFcn   function_handle
    p0         (1,:) double
    options.Lower     (1,:) double = []
    options.Upper     (1,:) double = []
    options.Fixed     (1,:) logical = []
    options.Channel   (1,1) double = 1
    options.ModelName (1,1) string = ""
    options.MetaField (1,1) string = ""
    options.XRange    (1,:) double = []
    options.Weights   (1,1) string {mustBeMember(options.Weights, ...
        ["none","1/y","1/y2"])} = "none"
    options.Verbose   (1,1) logical = true
end

N = numel(datasets);
M = numel(p0);

% Preallocate outputs
params    = NaN(N, M);
errors    = NaN(N, M);
R2        = NaN(N, 1);
chiSqRed  = NaN(N, 1);
RMSE_     = NaN(N, 1);
AIC_      = NaN(N, 1);
exitFlags = zeros(N, 1);
metaVals  = NaN(N, 1);

% ════════════════════════════════════════════════════════════════════════
% Fit each dataset
% ════════════════════════════════════════════════════════════════════════

for i = 1:N
    % Extract x, y from dataset
    [xData, yData, meta] = extractXY(datasets{i}, options.Channel);

    if isempty(xData) || numel(xData) < M + 1
        if options.Verbose
            fprintf('  [%d/%d] Skipped (too few points)\n', i, N);
        end
        continue;
    end

    % Apply X-range
    if ~isempty(options.XRange) && numel(options.XRange) == 2
        mask = xData >= options.XRange(1) & xData <= options.XRange(2);
        xData = xData(mask);
        yData = yData(mask);
    end

    % Compute weights
    w = [];
    switch options.Weights
        case '1/y',  w = 1 ./ max(abs(yData), eps);
        case '1/y2', w = 1 ./ max(yData.^2, eps);
    end

    % Auto-guess if model name provided
    p0i = p0;
    if options.ModelName ~= ""
        try
            p0i = fitting.autoGuess(options.ModelName, xData, yData);
        catch
            % Fall back to provided p0
        end
    end

    % Extract metadata value
    if options.MetaField ~= "" && ~isempty(meta)
        fName = char(options.MetaField);
        if isstruct(meta) && isfield(meta, fName)
            val = meta.(fName);
            if isnumeric(val) && isscalar(val)
                metaVals(i) = val;
            end
        end
    end

    % Run fit
    try
        fitArgs = {'Lower', options.Lower, 'Upper', options.Upper};
        if ~isempty(options.Fixed)
            fitArgs = [fitArgs, {'Fixed', options.Fixed}]; %#ok<AGROW>
        end
        if ~isempty(w)
            fitArgs = [fitArgs, {'Weights', w}]; %#ok<AGROW>
        end

        r = fitting.curveFit(xData, yData, modelFcn, p0i, fitArgs{:});

        params(i, :)   = r.params;
        errors(i, :)   = r.errors;
        R2(i)          = r.R2;
        chiSqRed(i)    = r.chiSqRed;
        RMSE_(i)       = r.RMSE;
        AIC_(i)        = r.AIC;
        exitFlags(i)   = r.exitFlag;

        if options.Verbose
            fprintf('  [%d/%d] R²=%.4f  params=[%s]\n', i, N, r.R2, ...
                strjoin(arrayfun(@(v) sprintf('%.4g',v), r.params, 'UniformOutput', false), ', '));
        end
    catch ME
        if options.Verbose
            fprintf('  [%d/%d] FAILED: %s\n', i, N, ME.message);
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
% Build parameter names
% ════════════════════════════════════════════════════════════════════════

paramNames = arrayfun(@(j) sprintf('p%d', j), 1:M, 'UniformOutput', false);
if options.ModelName ~= ""
    cat = fitting.models();
    idx = find(strcmp({cat.name}, options.ModelName), 1);
    if ~isempty(idx)
        paramNames = cat(idx).paramNames;
    end
end

% ════════════════════════════════════════════════════════════════════════
% Output
% ════════════════════════════════════════════════════════════════════════

summary.params     = params;
summary.errors     = errors;
summary.R2         = R2;
summary.chiSqRed   = chiSqRed;
summary.RMSE       = RMSE_;
summary.AIC        = AIC_;
summary.exitFlags  = exitFlags;
summary.paramNames = paramNames;
summary.modelName  = char(options.ModelName);
summary.metaValues = metaVals;
summary.nDatasets  = N;
summary.converged  = exitFlags == 1;

end

% ════════════════════════════════════════════════════════════════════════

function [x, y, meta] = extractXY(ds, channel)
%EXTRACTXY  Get x, y vectors from a dataset (struct or {x,y} cell pair).
    meta = [];
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
        if isfield(plotD, 'metadata')
            meta = plotD.metadata;
        elseif isfield(ds, 'metadata')
            meta = ds.metadata;
        end
    elseif iscell(ds) && numel(ds) >= 2
        x = ds{1}(:);
        y = ds{2}(:);
    else
        x = []; y = [];
    end
end
