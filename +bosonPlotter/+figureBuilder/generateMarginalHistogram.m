function outFig = generateMarginalHistogram(datasets, cfg, globalOpts)
%GENERATEMARGINALHISTOGRAM  Scatter with marginal histograms on top + right.
%
%   cfg fields:
%     .datasetIdx  single dataset index
%     .xChannel    X channel name (default 'time')
%     .yChannel    Y channel name
%     .nBins       histogram bin count (default 30)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasetIdx'), cfg.datasetIdx = 1; end
    ds = datasets{cfg.datasetIdx};
    if ~isfield(cfg,'xChannel') || isempty(cfg.xChannel), cfg.xChannel = 'time'; end
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel), cfg.yChannel = ds.data.labels{1}; end
    if ~isfield(cfg,'nBins'),    cfg.nBins   = 30; end

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
    tlo = tiledlayout(outFig, 4, 4, 'TileSpacing','compact','Padding','compact');

    % Top histogram (x)
    axTop = nexttile(tlo, 1, [1 3]);
    histogram(axTop, xv, cfg.nBins, 'FaceColor', [0.55 0.65 0.85]);
    axTop.XTickLabel = []; axTop.Box = 'on';

    % (top-right corner blank)
    nexttile(tlo, 4, [1 1]); axis off;

    % Main scatter (rows 2-4, cols 1-3)
    axMain = nexttile(tlo, 5, [3 3]);
    scatter(axMain, xv, yv, 8, 'filled', 'MarkerFaceAlpha', 0.5);
    axMain.Box = 'on'; grid(axMain,'on');
    xlabel(axMain, cfg.xChannel); ylabel(axMain, cfg.yChannel);

    % Right histogram (y)
    axRight = nexttile(tlo, 8, [3 1]);
    histogram(axRight, yv, cfg.nBins, 'FaceColor', [0.55 0.65 0.85], 'Orientation','horizontal');
    axRight.YTickLabel = []; axRight.Box = 'on';

    for ax_ = [axTop axMain axRight]
        ax_.FontSize = globalOpts.fontSize; ax_.FontName = globalOpts.fontName;
    end
end
