function outFig = generateParamEvol(datasets, cfg, globalOpts)
%GENERATEPARAMEVOL  Plot a single Y value (e.g. fitted peak position) vs an
%   X parameter, one point per dataset. Useful for parameter-sweep summaries.
%
%   cfg fields:
%     .datasets    [1xN] dataset indices in order
%     .yChannel    Y channel name; the SUMMARY (mean/peak max) is plotted
%     .summary     'mean' (default) | 'max' | 'min' | 'last'
%     .xValues     [1xN] x positions per dataset (default: 1:N)
%     .xLabel      string for x axis (default: 'Index')
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets') || isempty(cfg.datasets), cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel), cfg.yChannel = datasets{1}.data.labels{1}; end
    if ~isfield(cfg,'summary'), cfg.summary = 'mean'; end
    n = numel(cfg.datasets);
    if ~isfield(cfg,'xValues') || numel(cfg.xValues) ~= n, cfg.xValues = 1:n; end
    if ~isfield(cfg,'xLabel'),  cfg.xLabel = 'Index'; end

    ys = nan(1, n);
    for k = 1:n
        di = cfg.datasets(k);
        if di < 1 || di > numel(datasets), continue; end
        [~, yv] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannel);
        if isempty(yv), continue; end
        switch cfg.summary
            case 'max',  ys(k) = max(yv);
            case 'min',  ys(k) = min(yv);
            case 'last', ys(k) = yv(end);
            otherwise,   ys(k) = mean(yv);
        end
    end

    outFig = bosonPlotter.figureBuilder.createOutFig('Parameter Evolution', globalOpts);
    tAx = axes(outFig); hold(tAx,'on'); tAx.Box = 'on'; grid(tAx,'on');
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
    plot(tAx, cfg.xValues, ys, '-o', 'LineWidth', 1.0, 'MarkerSize', 5);
    xlabel(tAx, cfg.xLabel); ylabel(tAx, sprintf('%s (%s)', cfg.yChannel, cfg.summary));
end
