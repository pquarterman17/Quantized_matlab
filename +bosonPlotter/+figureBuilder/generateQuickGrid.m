function outFig = generateQuickGrid(datasets, cfg, globalOpts)
%GENERATEQUICKGRID  Auto-arranged grid of datasets, one panel each.
%
%   cfg fields:
%     .datasets    [1xN] dataset indices (default: all)
%     .yChannels   {} cell of channel names per panel (default: all from first ds)
%     .cols        target column count (default: ceil(sqrt(N)))
%     .shareX      logical (default: true)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets')  || isempty(cfg.datasets),  cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yChannels') || isempty(cfg.yChannels)
        if ~isempty(datasets), cfg.yChannels = datasets{1}.data.labels(1); else, cfg.yChannels = {}; end
    end
    if ~isfield(cfg,'cols') || isempty(cfg.cols), cfg.cols = ceil(sqrt(numel(cfg.datasets))); end
    if ~isfield(cfg,'shareX'), cfg.shareX = true; end

    n  = numel(cfg.datasets);
    nC = max(1, cfg.cols);
    nR = ceil(n / nC);

    outFig = bosonPlotter.figureBuilder.createOutFig('Quick Grid', globalOpts);
    tlo = tiledlayout(outFig, nR, nC, 'TileSpacing', 'compact', 'Padding', 'compact');

    axList = gobjects(0);
    for k = 1:n
        di = cfg.datasets(k);
        if di < 1 || di > numel(datasets), continue; end
        tAx = nexttile(tlo);
        hold(tAx, 'on'); tAx.Box = 'on'; tAx.FontSize = globalOpts.fontSize;
        tAx.FontName = globalOpts.fontName;
        ci = 0; xLbl = ''; yLbl = '';
        for yi = 1:numel(cfg.yChannels)
            [xv, yv, xLbl_, yLbl_] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannels{yi});
            if isempty(xv), continue; end
            ci = ci + 1;
            plot(tAx, xv, yv, '-', 'LineWidth', 1.0, ...
                'DisplayName', cfg.yChannels{yi});
            if isempty(xLbl), xLbl = xLbl_; end
            if isempty(yLbl), yLbl = yLbl_; end
        end
        [~, fn, fx] = fileparts(datasets{di}.filepath);
        title(tAx, [fn fx], 'FontSize', globalOpts.fontSize, 'Interpreter', 'none');
        xlabel(tAx, xLbl, 'FontSize', globalOpts.fontSize);
        ylabel(tAx, yLbl, 'FontSize', globalOpts.fontSize);
        axList(end+1) = tAx; %#ok<AGROW>
    end
    if cfg.shareX && numel(axList) >= 2, linkaxes(axList, 'x'); end
end
