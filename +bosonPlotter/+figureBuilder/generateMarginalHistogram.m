function outFig = generateMarginalHistogram(datasets, cfg, globalOpts)
%GENERATEMARGINALHISTOGRAM  Scatter + marginal X/Y histograms for one dataset.
%   Routes through plotting.marginalHistogram for the actual layout (which
%   includes optional KDE overlays).
%
%   cfg fields:
%     .datasetIdx  single dataset index
%     .xChannel    X channel name (default 'time')
%     .yChannel    Y channel name
%     .nBins       histogram bin count (default 30)
%     .showKDE     logical (default false) — overlay Gaussian KDE
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasetIdx'), cfg.datasetIdx = 1; end
    ds = datasets{cfg.datasetIdx};
    if ~isfield(cfg,'xChannel') || isempty(cfg.xChannel), cfg.xChannel = 'time'; end
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel), cfg.yChannel = ds.data.labels{1}; end
    if ~isfield(cfg,'nBins'),    cfg.nBins   = 30;     end
    if ~isfield(cfg,'showKDE'),  cfg.showKDE = false;  end

    if strcmpi(cfg.xChannel, 'time')
        xv = double(ds.data.time);
    else
        xi = find(strcmp(ds.data.labels, cfg.xChannel), 1);
        xv = ds.data.values(:, xi);
    end
    yi = find(strcmp(ds.data.labels, cfg.yChannel), 1);
    yv = ds.data.values(:, yi);
    valid = ~isnan(xv) & ~isnan(yv);
    xv = xv(valid); yv = yv(valid);

    outFig = bosonPlotter.figureBuilder.createOutFig('Marginal Histogram', globalOpts);
    tmpAx = axes(outFig);
    handles = plotting.marginalHistogram(tmpAx, xv, yv, ...
        NBins=cfg.nBins, ShowKDE=cfg.showKDE);
    xlabel(handles.axMain, cfg.xChannel, 'FontSize', globalOpts.fontSize);
    ylabel(handles.axMain, cfg.yChannel, 'FontSize', globalOpts.fontSize);
    handles.axMain.FontSize = globalOpts.fontSize;
    handles.axMain.FontName = globalOpts.fontName;
end
