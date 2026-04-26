function outFig = generateWaterfall(datasets, cfg, globalOpts)
%GENERATEWATERFALL  Stacked waterfall of one Y channel across datasets.
%
%   cfg fields:
%     .datasets       [1xN] dataset indices
%     .yChannel       single Y channel name
%     .spacing        numeric vertical offset, NaN = auto (0.8 × median range)
%     .reverse        logical, top-to-bottom stacking (default false)
%     .logMode        logical, multiplicative offsets (default false)
%     .logY           logical, log Y axis (default false)
%     .edgeLabels     logical, right-edge trace labels (default true)
%     .colorByZ       logical, colour-map traces by a Z channel (default false)
%     .zChannel       channel name for Z mapping ('' if not used)
%     .colormap       'viridis' | 'parula' | 'plasma' | etc. (default 'viridis')
%     .traceLabels    {1×N} cell of explicit DisplayName strings (optional)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets')   || isempty(cfg.datasets),  cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yChannel')   || isempty(cfg.yChannel)
        cfg.yChannel = datasets{1}.data.labels{1};
    end
    if ~isfield(cfg,'spacing'),    cfg.spacing = NaN;        end
    if ~isfield(cfg,'reverse'),    cfg.reverse = false;       end
    if ~isfield(cfg,'logMode'),    cfg.logMode = false;       end
    if ~isfield(cfg,'logY'),       cfg.logY    = false;       end
    if ~isfield(cfg,'edgeLabels'), cfg.edgeLabels = true;     end
    if ~isfield(cfg,'colorByZ'),   cfg.colorByZ = false;      end
    if ~isfield(cfg,'zChannel'),   cfg.zChannel = '';         end
    if ~isfield(cfg,'colormap'),   cfg.colormap = 'viridis';  end
    if ~isfield(cfg,'traceLabels') || numel(cfg.traceLabels) ~= numel(cfg.datasets)
        cfg.traceLabels = arrayfun(@(d) sprintf('#%d', d), cfg.datasets, 'UniformOutput', false);
    end

    n = numel(cfg.datasets);

    % Cache traces + Y-ranges for auto-spacing
    cache    = cell(1, n);
    yRanges  = zeros(1, n);
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

    % Z-coloring: per-trace mean of zChannel mapped through colormap
    useColorZ = cfg.colorByZ && ~isempty(cfg.zChannel);
    if useColorZ
        zVals = NaN(1, n);
        for si = 1:n
            di = cfg.datasets(si);
            if di < 1 || di > numel(datasets), continue; end
            [~, zv] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.zChannel);
            if ~isempty(zv), zVals(si) = mean(zv); end
        end
        zFinite = zVals(~isnan(zVals));
        if isempty(zFinite) || min(zFinite) == max(zFinite)
            useColorZ = false;
        else
            zMin = min(zFinite); zMax = max(zFinite);
            try
                cmapRGB = bosonPlotter.colorMaps(cfg.colormap, 256);
            catch
                cmapRGB = parula(256);
            end
            zNorm = (zVals - zMin) / (zMax - zMin);
            colors = zeros(n, 3);
            for si = 1:n
                if isnan(zNorm(si))
                    colors(si, :) = [0.5 0.5 0.5];
                else
                    rowIdx = max(1, round(zNorm(si) * 255) + 1);
                    colors(si, :) = cmapRGB(rowIdx, :);
                end
            end
        end
    end
    if ~useColorZ
        baseCmap = lines(max(n, 1));
        colors   = baseCmap(mod((1:n)-1, size(baseCmap,1)) + 1, :);
    end

    outFig = bosonPlotter.figureBuilder.createOutFig('Waterfall', globalOpts);
    tAx = axes(outFig); hold(tAx, 'on'); tAx.Box = 'on'; grid(tAx, 'on');
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;

    traceOrder = 1:n;
    if cfg.reverse, traceOrder = flip(traceOrder); end

    xMax = -inf;
    for tk = 1:numel(traceOrder)
        si = traceOrder(tk);
        if isempty(cache{si}) || isempty(cache{si}.x), continue; end
        xv = cache{si}.x;  yv = cache{si}.y;
        offset = si - 1;
        if cfg.logMode
            yv = yv * (spacing ^ offset);
        else
            yv = yv + offset * spacing;
        end
        plot(tAx, xv, yv, '-', 'Color', colors(si,:), ...
            'LineWidth', 1.0, 'DisplayName', cfg.traceLabels{si});
        if cfg.edgeLabels && ~isempty(xv)
            xEnd = double(xv(end));  yEnd = double(yv(end));
            if xEnd > xMax, xMax = xEnd; end
            text(tAx, xEnd, yEnd, ['  ' cfg.traceLabels{si}], ...
                'FontSize', max(globalOpts.fontSize - 2, 6), ...
                'Color', colors(si,:), ...
                'Interpreter', 'none', ...
                'VerticalAlignment', 'middle', 'Clipping', 'on');
        end
    end

    if cfg.logY, tAx.YScale = 'log'; end
    xlabel(tAx, xLbl, 'FontSize', globalOpts.fontSize);
    ylabel(tAx, [cfg.yChannel ' (offset)'], 'FontSize', globalOpts.fontSize);
    if cfg.edgeLabels && xMax > -inf
        xl = tAx.XLim;
        tAx.XLim(2) = xl(2) + 0.15 * (xl(2) - xl(1));
    end
    if useColorZ
        try, colormap(tAx, bosonPlotter.colorMaps(cfg.colormap, 256));
        catch, colormap(tAx, 'parula'); end
        cb = colorbar(tAx);
        cb.Label.String = cfg.zChannel;
        cb.Label.FontSize = globalOpts.fontSize;
        tAx.CLim = [zMin, zMax];
    end
end
