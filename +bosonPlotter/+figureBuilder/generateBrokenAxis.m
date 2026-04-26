function outFig = generateBrokenAxis(datasets, cfg, globalOpts)
%GENERATEBROKENAXIS  Two side-by-side axes with a discontinuity in X, both
%   showing the same data; standard "broken axis" trick for spanning a gap.
%
%   cfg fields:
%     .datasets   [1xN] dataset indices to overlay
%     .yChannel   Y channel name
%     .leftRange  [xMin xBreakLow]
%     .rightRange [xBreakHigh xMax]
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets')   || isempty(cfg.datasets),   cfg.datasets = 1:min(1, numel(datasets)); end
    if ~isfield(cfg,'yChannel')   || isempty(cfg.yChannel),   cfg.yChannel = datasets{cfg.datasets(1)}.data.labels{1}; end

    if ~isfield(cfg,'leftRange') || ~isfield(cfg,'rightRange') || ...
       isempty(cfg.leftRange) || isempty(cfg.rightRange)
        % Auto-pick: split the x-range at the median
        [xv, ~] = bosonPlotter.figureBuilder.extractXY(datasets{cfg.datasets(1)}, cfg.yChannel);
        if isempty(xv)
            cfg.leftRange = [0 1]; cfg.rightRange = [2 3];
        else
            xMin = min(xv); xMax = max(xv); xMid = median(xv);
            cfg.leftRange  = [xMin, xMid - 0.05 * (xMax - xMin)];
            cfg.rightRange = [xMid + 0.05 * (xMax - xMin), xMax];
        end
    end

    outFig = bosonPlotter.figureBuilder.createOutFig('Broken Axis', globalOpts);
    tlo = tiledlayout(outFig, 1, 2, 'TileSpacing','tight','Padding','compact');
    axL = nexttile(tlo); hold(axL,'on'); axL.Box = 'on';
    axR = nexttile(tlo); hold(axR,'on'); axR.Box = 'on';
    for ax_ = [axL axR], ax_.FontSize = globalOpts.fontSize; ax_.FontName = globalOpts.fontName; end

    cmap = lines(max(numel(cfg.datasets), 1));
    xLbl = ''; yLbl = cfg.yChannel;
    for k = 1:numel(cfg.datasets)
        di = cfg.datasets(k);
        [xv, yv, xLbl_, ~] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannel);
        if isempty(xv), continue; end
        if isempty(xLbl), xLbl = xLbl_; end
        col = cmap(mod(k-1, size(cmap,1))+1, :);
        plot(axL, xv, yv, '-', 'Color', col);
        plot(axR, xv, yv, '-', 'Color', col);
    end
    axL.XLim = cfg.leftRange;  axR.XLim = cfg.rightRange;
    linkaxes([axL axR], 'y');
    axR.YTickLabel = [];   % hide right-panel y labels (shared)
    xlabel(axL, xLbl); ylabel(axL, yLbl);
end
