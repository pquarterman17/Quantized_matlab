function outFig = generateOverlayResidual(datasets, cfg, globalOpts)
%GENERATEOVERLAYRESIDUAL  Two-panel data + (data - reference) overlay.
%
%   cfg fields:
%     .referenceIdx  index into cfg.datasets used as the reference trace
%     .datasets      [1xN] dataset indices to overlay
%     .yChannel      Y channel name
%     .residualMode  'difference' (default) | 'ratio'
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets')     || isempty(cfg.datasets),     cfg.datasets = 1:min(2, numel(datasets)); end
    if ~isfield(cfg,'yChannel')     || isempty(cfg.yChannel),     cfg.yChannel = datasets{1}.data.labels{1}; end
    if ~isfield(cfg,'referenceIdx') || isempty(cfg.referenceIdx), cfg.referenceIdx = 1; end
    if ~isfield(cfg,'residualMode'), cfg.residualMode = 'difference'; end

    outFig = bosonPlotter.figureBuilder.createOutFig('Overlay + Residual', globalOpts);
    tlo = tiledlayout(outFig, 2, 1, 'TileSpacing','compact', 'Padding','compact');

    axTop = nexttile(tlo); hold(axTop,'on'); axTop.Box = 'on';
    axBot = nexttile(tlo); hold(axBot,'on'); axBot.Box = 'on';
    for ax_ = [axTop axBot]
        ax_.FontSize = globalOpts.fontSize; ax_.FontName = globalOpts.fontName;
    end

    % Reference trace (resampled by interp1 onto each subsequent x)
    refDi = cfg.datasets(cfg.referenceIdx);
    [xRef, yRef, xLbl, yLbl] = bosonPlotter.figureBuilder.extractXY(datasets{refDi}, cfg.yChannel);

    cmap = lines(numel(cfg.datasets));
    for k = 1:numel(cfg.datasets)
        di = cfg.datasets(k);
        [xv, yv, ~, ~] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannel);
        if isempty(xv), continue; end
        col = cmap(mod(k-1, size(cmap,1))+1, :);
        plot(axTop, xv, yv, '-', 'Color', col, 'LineWidth', 1.0, ...
            'DisplayName', sprintf('#%d', di));
        % Residual
        if k ~= cfg.referenceIdx && ~isempty(xRef)
            yRefOnX = interp1(xRef, yRef, xv, 'linear', NaN);
            switch cfg.residualMode
                case 'ratio'
                    res = yv ./ yRefOnX;
                otherwise
                    res = yv - yRefOnX;
            end
            plot(axBot, xv, res, '-', 'Color', col, 'LineWidth', 0.9, ...
                'DisplayName', sprintf('#%d', di));
        end
    end
    if strcmp(cfg.residualMode, 'ratio'), refLine = 1; else, refLine = 0; end
    yline(axBot, refLine, 'k:', 'HandleVisibility','off');
    xlabel(axBot, xLbl); ylabel(axTop, yLbl);
    if strcmp(cfg.residualMode, 'ratio')
        ylabel(axBot, 'Ratio');
    else
        ylabel(axBot, 'Residual');
    end
    linkaxes([axTop axBot], 'x');
    if numel(cfg.datasets) > 1, legend(axTop, 'Location','best','FontSize',max(globalOpts.fontSize-2,6)); end
end
