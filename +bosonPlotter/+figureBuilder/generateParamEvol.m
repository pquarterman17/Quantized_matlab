function outFig = generateParamEvol(datasets, cfg, globalOpts)
%GENERATEPARAMEVOL  Plot a single summary value vs an X parameter, one
%   point per dataset. Useful for parameter-sweep summaries (peak position
%   vs temperature, FWHM vs field, integrated intensity vs index, …).
%
%   cfg fields:
%     .datasets    [1xN] dataset indices (in order)
%     .yMetric     'mean' | 'max' | 'min' | 'last' | 'integrated' |
%                  'Peak center' | 'Peak FWHM' | 'Peak area' | 'Peak height'
%                  Peak metrics use ds.peaks (sorted by centre).
%     .yChannel    Y channel name (used by mean/max/min/last/integrated)
%     .peakIdx     when yMetric is a peak metric, which peak (1-based, sorted by centre)
%     .xMode       'index' (default) | 'metadata:<field>' to look up a meta field
%                  by name (multiple aliases comma-separated, e.g.
%                  'metadata:temperature,temp,Temperature')
%     .xValues     [1xN] explicit numeric X values (overrides xMode if set)
%     .xLabel      string for x axis (default: derived from xMode)
%     .connect     logical (default true) — line+marker vs scatter only
%     .pointLabels {1×N} cell of text labels per point (optional)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets') || isempty(cfg.datasets), cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yMetric'),  cfg.yMetric  = 'mean'; end
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel), cfg.yChannel = datasets{1}.data.labels{1}; end
    if ~isfield(cfg,'peakIdx'),  cfg.peakIdx  = 1; end
    if ~isfield(cfg,'xMode'),    cfg.xMode    = 'index'; end
    if ~isfield(cfg,'connect'),  cfg.connect  = true; end
    n = numel(cfg.datasets);
    if ~isfield(cfg,'xValues') || numel(cfg.xValues) ~= n
        cfg.xValues = nan(1, n);
        if strcmp(cfg.xMode, 'index')
            cfg.xValues = 1:n;
        elseif startsWith(cfg.xMode, 'metadata:')
            aliases = strtrim(strsplit(cfg.xMode(10:end), ','));
            for k = 1:n
                di = cfg.datasets(k);
                if di < 1 || di > numel(datasets), continue; end
                d = datasets{di}.data;
                cfg.xValues(k) = lookupMetaField(d.metadata, aliases);
            end
        end
    end
    if ~isfield(cfg,'xLabel') || isempty(cfg.xLabel)
        if strcmp(cfg.xMode, 'index')
            cfg.xLabel = 'Index';
        elseif startsWith(cfg.xMode, 'metadata:')
            cfg.xLabel = strtrim(extractAfter(cfg.xMode, 'metadata:'));
        else
            cfg.xLabel = 'X';
        end
    end
    if ~isfield(cfg,'pointLabels') || numel(cfg.pointLabels) ~= n
        cfg.pointLabels = {};
        for k = 1:n
            di = cfg.datasets(k);
            if di >= 1 && di <= numel(datasets)
                [~, fn, fx] = fileparts(datasets{di}.filepath);
                cfg.pointLabels{k} = [fn fx]; %#ok<AGROW>
            else
                cfg.pointLabels{k} = sprintf('#%d', di); %#ok<AGROW>
            end
        end
    end

    ys = nan(1, n);
    for k = 1:n
        di = cfg.datasets(k);
        if di < 1 || di > numel(datasets), continue; end
        ds = datasets{di};
        switch cfg.yMetric
            case {'Peak center','Peak FWHM','Peak area','Peak height'}
                if isfield(ds, 'peaks') && ~isempty(ds.peaks) && numel(ds.peaks) >= cfg.peakIdx
                    centers = [ds.peaks.center];
                    [~, sortIdx] = sort(centers);
                    pk = ds.peaks(sortIdx(cfg.peakIdx));
                    switch cfg.yMetric
                        case 'Peak center', ys(k) = pk.center;
                        case 'Peak FWHM',   ys(k) = pk.fwhm;
                        case 'Peak area',   ys(k) = pk.area;
                        case 'Peak height', ys(k) = pk.height;
                    end
                end
            case 'integrated'
                [xv, yv] = bosonPlotter.figureBuilder.extractXY(ds, cfg.yChannel);
                if ~isempty(xv), ys(k) = trapz(xv, yv); end
            otherwise   % mean / max / min / last
                [~, yv] = bosonPlotter.figureBuilder.extractXY(ds, cfg.yChannel);
                if isempty(yv), continue; end
                switch cfg.yMetric
                    case 'max',  ys(k) = max(yv);
                    case 'min',  ys(k) = min(yv);
                    case 'last', ys(k) = yv(end);
                    otherwise,   ys(k) = mean(yv);
                end
        end
    end

    outFig = bosonPlotter.figureBuilder.createOutFig('Parameter Evolution', globalOpts);
    tAx = axes(outFig); hold(tAx,'on'); tAx.Box = 'on'; grid(tAx,'on');
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;

    valid = ~isnan(cfg.xValues) & ~isnan(ys);
    if cfg.connect
        plot(tAx, cfg.xValues(valid), ys(valid), '-o', ...
            'Color', [0.12 0.47 0.71], ...
            'MarkerFaceColor', [0.12 0.47 0.71], ...
            'MarkerSize', 6, 'LineWidth', 1.0);
    else
        scatter(tAx, cfg.xValues(valid), ys(valid), 50, ...
            [0.12 0.47 0.71], 'filled');
    end

    % Point labels (only when ≤15 points to avoid clutter)
    if sum(valid) <= 15 && ~isempty(cfg.pointLabels)
        validIdx = find(valid);
        for vi = 1:numel(validIdx)
            k = validIdx(vi);
            if k <= numel(cfg.pointLabels) && ~isempty(cfg.pointLabels{k})
                text(tAx, cfg.xValues(k), ys(k), ['  ' cfg.pointLabels{k}], ...
                    'FontSize', max(globalOpts.fontSize - 3, 6), ...
                    'Interpreter', 'none', 'Rotation', 20);
            end
        end
    end
    xlabel(tAx, cfg.xLabel, 'FontSize', globalOpts.fontSize);
    ylabel(tAx, cfg.yMetric, 'FontSize', globalOpts.fontSize);
end

function v = lookupMetaField(meta, aliases)
%LOOKUPMETAFIELD  Return the first numeric value found across alias names.
    v = NaN;
    if ~isstruct(meta), return; end
    for k = 1:numel(aliases)
        f = aliases{k};
        if isfield(meta, f)
            val = meta.(f);
            if isnumeric(val) && isscalar(val) && isfinite(val)
                v = double(val); return;
            end
            if (ischar(val) || isstring(val))
                tmp = str2double(val);
                if isfinite(tmp), v = tmp; return; end
            end
        end
    end
end
