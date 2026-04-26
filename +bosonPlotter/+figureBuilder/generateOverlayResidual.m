function outFig = generateOverlayResidual(datasets, cfg, globalOpts)
%GENERATEOVERLAYRESIDUAL  Two-panel data + (data - reference) overlay.
%
%   cfg fields:
%     .referenceIdx  index into cfg.datasets used as the reference trace
%     .datasets      [1xN] dataset indices to overlay
%     .yChannel      Y channel name
%     .residualMode  'difference' (default) | 'ratio' | 'percent'
%     .logOverlay    logical — log-Y on the overlay panel (default false)
%     .heightRatio   '1:1' (default) | '2:1' | '3:1' (overlay : residual)
%     .traceLabels   {1×N} cell of explicit DisplayName strings (optional)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets')     || isempty(cfg.datasets),     cfg.datasets = 1:min(2, numel(datasets)); end
    if ~isfield(cfg,'yChannel')     || isempty(cfg.yChannel),     cfg.yChannel = datasets{1}.data.labels{1}; end
    if ~isfield(cfg,'referenceIdx') || isempty(cfg.referenceIdx), cfg.referenceIdx = 1; end
    if ~isfield(cfg,'residualMode'), cfg.residualMode = 'difference'; end
    if ~isfield(cfg,'logOverlay'),   cfg.logOverlay   = false; end
    if ~isfield(cfg,'heightRatio'),  cfg.heightRatio  = '1:1'; end
    if ~isfield(cfg,'traceLabels') || numel(cfg.traceLabels) ~= numel(cfg.datasets)
        cfg.traceLabels = arrayfun(@(d) sprintf('#%d', d), cfg.datasets, 'UniformOutput', false);
    end

    % Parse height ratio for tiledlayout RowHeight
    switch cfg.heightRatio
        case '3:1', rh = {3, 1};
        case '2:1', rh = {2, 1};
        otherwise,  rh = {1, 1};
    end

    outFig = bosonPlotter.figureBuilder.createOutFig('Overlay + Residual', globalOpts);
    tlo = tiledlayout(outFig, 2, 1, 'TileSpacing','compact', 'Padding','compact');
    tlo.GridSize = [2 1];

    axTop = nexttile(tlo); hold(axTop,'on'); axTop.Box = 'on'; grid(axTop,'on');
    axBot = nexttile(tlo); hold(axBot,'on'); axBot.Box = 'on'; grid(axBot,'on');
    for ax_ = [axTop axBot]
        ax_.FontSize = globalOpts.fontSize; ax_.FontName = globalOpts.fontName;
    end

    % Reference trace (used for residual interpolation)
    refDi = cfg.datasets(cfg.referenceIdx);
    [xRef, yRef, xLbl, yLbl] = bosonPlotter.figureBuilder.extractXY(datasets{refDi}, cfg.yChannel);

    cmap = lines(numel(cfg.datasets));
    for k = 1:numel(cfg.datasets)
        di = cfg.datasets(k);
        [xv, yv] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannel);
        if isempty(xv), continue; end
        col = cmap(mod(k-1, size(cmap,1))+1, :);
        plot(axTop, xv, yv, '-', 'Color', col, 'LineWidth', 1.0, ...
            'DisplayName', cfg.traceLabels{k});
        if k ~= cfg.referenceIdx && ~isempty(xRef)
            yRefOnX = interp1(xRef, yRef, xv, 'linear', NaN);
            switch cfg.residualMode
                case 'ratio'
                    res = yv ./ yRefOnX;
                    refLine = 1; resLbl = 'Ratio';
                case 'percent'
                    res = (yv - yRefOnX) ./ yRefOnX * 100;
                    refLine = 0; resLbl = 'Residual (%)';
                otherwise
                    res = yv - yRefOnX;
                    refLine = 0; resLbl = 'Residual';
            end
            plot(axBot, xv, res, '-', 'Color', col, 'LineWidth', 0.9, ...
                'DisplayName', cfg.traceLabels{k});
        end
    end
    if ~exist('refLine','var'), refLine = 0; resLbl = 'Residual'; end
    yline(axBot, refLine, 'k:', 'HandleVisibility','off');
    if cfg.logOverlay, axTop.YScale = 'log'; end
    xlabel(axBot, xLbl, 'FontSize', globalOpts.fontSize);
    ylabel(axTop, yLbl, 'FontSize', globalOpts.fontSize);
    ylabel(axBot, resLbl, 'FontSize', globalOpts.fontSize);
    linkaxes([axTop axBot], 'x');
    if numel(cfg.datasets) > 1
        legend(axTop, 'Location','best', 'FontSize', max(globalOpts.fontSize-2, 6));
    end

    % Apply height ratio: tiledlayout supports RowHeight as cell weights
    try
        tlo.RowHeight = rh;
    catch
        % Older MATLAB — RowHeight not settable; fall back silently
    end
end
