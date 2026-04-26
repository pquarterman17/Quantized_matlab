function outFig = generateWaterfall(datasets, cfg, globalOpts)
%GENERATEWATERFALL  Stacked waterfall of one Y channel across datasets.
%
%   cfg fields:
%     .datasets   [1xN] dataset indices
%     .yChannel   single Y channel name
%     .spacing    numeric vertical offset, NaN = auto
%     .reverse    logical, top-to-bottom stacking
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets')  || isempty(cfg.datasets),  cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yChannel')  || isempty(cfg.yChannel)
        cfg.yChannel = datasets{1}.data.labels{1};
    end
    if ~isfield(cfg,'spacing'),  cfg.spacing = NaN; end
    if ~isfield(cfg,'reverse'),  cfg.reverse = false; end

    outFig = bosonPlotter.figureBuilder.createOutFig('Waterfall', globalOpts);
    tAx = axes(outFig);
    hold(tAx, 'on'); tAx.Box = 'on'; grid(tAx, 'on');
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;

    n = numel(cfg.datasets);
    yRanges = zeros(1, n);
    cache = cell(1, n);
    xLbl = '';
    for si = 1:n
        di = cfg.datasets(si);
        if di < 1 || di > numel(datasets), continue; end
        [xv, yv, xLbl_, ~] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannel);
        cache{si} = struct('x', xv, 'y', yv);
        if ~isempty(yv), yRanges(si) = max(yv) - min(yv); end
        if isempty(xLbl), xLbl = xLbl_; end
    end
    if isnan(cfg.spacing) || cfg.spacing == 0
        valid = yRanges(yRanges > 0);
        if isempty(valid), spacing = 1; else, spacing = 0.8 * median(valid); end
    else
        spacing = cfg.spacing;
    end
    cmap = lines(max(n, 1));
    for si = 1:n
        if isempty(cache{si}) || isempty(cache{si}.x), continue; end
        if cfg.reverse, off = (n - si) * spacing; else, off = (si - 1) * spacing; end
        plot(tAx, cache{si}.x, cache{si}.y + off, '-', ...
            'Color', cmap(mod(si-1, size(cmap,1))+1, :), ...
            'LineWidth', 1.0, ...
            'DisplayName', sprintf('#%d', cfg.datasets(si)));
    end
    xlabel(tAx, xLbl, 'FontSize', globalOpts.fontSize);
    ylabel(tAx, [cfg.yChannel ' (offset)'], 'FontSize', globalOpts.fontSize);
    if n > 1
        legend(tAx, 'Location','best', 'FontSize', max(globalOpts.fontSize-2, 6));
    end
end
