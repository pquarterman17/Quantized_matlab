function outFig = generateGroupedPlot(datasets, cfg, globalOpts)
%GENERATEGROUPEDPLOT  Group-by-channel-value plot from one dataset.
%   Routes through plotting.groupedPlot, which handles the four plot types
%   (line / scatter / bar / box) and per-group colour cycling.
%
%   cfg fields:
%     .datasetIdx  single dataset index
%     .xChannel    X channel name
%     .yChannel    Y channel name
%     .groupChannel  channel name whose values define groups (continuous
%                    values are categorised by `unique`)
%     .plotType    'line' (default) | 'scatter' | 'bar' | 'box'
%     .legend      logical (default true)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasetIdx'), cfg.datasetIdx = 1; end
    ds = datasets{cfg.datasetIdx};
    labels = ds.data.labels;
    if ~isfield(cfg,'xChannel')     || isempty(cfg.xChannel),     cfg.xChannel     = labels{1}; end
    if ~isfield(cfg,'yChannel')     || isempty(cfg.yChannel)
        cfg.yChannel = labels{min(2, numel(labels))};
    end
    if ~isfield(cfg,'groupChannel') || isempty(cfg.groupChannel)
        cfg.groupChannel = labels{min(3, numel(labels))};
    end
    if ~isfield(cfg,'plotType'), cfg.plotType = 'line'; end
    if ~isfield(cfg,'legend'),   cfg.legend = true;     end

    xi = find(strcmp(labels, cfg.xChannel), 1);
    yi = find(strcmp(labels, cfg.yChannel), 1);
    gi = find(strcmp(labels, cfg.groupChannel), 1);
    if isempty(xi) || isempty(yi) || isempty(gi)
        error('GroupedPlot:badChannel','One of x/y/group channels not found');
    end
    xv = ds.data.values(:, xi);
    yv = ds.data.values(:, yi);
    gv = ds.data.values(:, gi);
    valid = ~isnan(xv) & ~isnan(yv) & ~isnan(gv);
    xv = xv(valid); yv = yv(valid); gv = gv(valid);

    outFig = bosonPlotter.figureBuilder.createOutFig('Grouped Plot', globalOpts);
    tAx = axes(outFig); hold(tAx,'on'); tAx.Box = 'on'; grid(tAx,'on');
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
    plotting.groupedPlot(tAx, xv, yv, gv, ...
        PlotType=cfg.plotType, Legend=cfg.legend);
    xlabel(tAx, cfg.xChannel); ylabel(tAx, cfg.yChannel);
end
