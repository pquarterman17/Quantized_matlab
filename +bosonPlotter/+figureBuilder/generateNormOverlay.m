function outFig = generateNormOverlay(datasets, cfg, globalOpts)
%GENERATENORMOVERLAY  Overlay multiple datasets after per-trace normalisation.
%
%   cfg fields:
%     .datasets    [1xN] dataset indices
%     .yChannel    Y channel name
%     .normMethod  'Peak (0-1)' (default) | 'Range (0-1)' | 'Z-score' | 'Area'
%     .alignMode   'None' (default) | 'Peak center' | 'X offset'
%     .logY        logical
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets')   || isempty(cfg.datasets),   cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yChannel')   || isempty(cfg.yChannel),   cfg.yChannel = datasets{1}.data.labels{1}; end
    if ~isfield(cfg,'normMethod'), cfg.normMethod = 'Peak (0-1)'; end
    if ~isfield(cfg,'alignMode'),  cfg.alignMode  = 'None'; end
    if ~isfield(cfg,'logY'),       cfg.logY       = false; end

    outFig = bosonPlotter.figureBuilder.createOutFig('Normalized Overlay', globalOpts);
    tAx = axes(outFig); hold(tAx, 'on'); tAx.Box = 'on'; grid(tAx, 'on');
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;

    cmap = lines(max(numel(cfg.datasets), 1));
    yLbl = 'Normalised';  xLbl = '';
    for k = 1:numel(cfg.datasets)
        di = cfg.datasets(k);
        if di < 1 || di > numel(datasets), continue; end
        [xv, yv, xLbl_, ~] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannel);
        if isempty(xv), continue; end
        if isempty(xLbl), xLbl = xLbl_; end

        switch cfg.normMethod
            case 'Peak (0-1)'
                if max(abs(yv)) > 0, yv = yv / max(abs(yv)); end
            case 'Range (0-1)'
                mn = min(yv); mx = max(yv);
                if mx > mn, yv = (yv - mn) / (mx - mn); end
            case 'Z-score'
                m = mean(yv); s = std(yv);
                if s > 0, yv = (yv - m) / s; end
                yLbl = 'Z-score';
            case 'Area'
                a = trapz(xv, yv); if a ~= 0, yv = yv / a; end
                yLbl = 'Area-normalised';
        end
        switch cfg.alignMode
            case 'Peak center'
                [~, pi] = max(yv); xv = xv - xv(pi);
            case 'X offset'
                xv = xv - xv(1);
        end
        plot(tAx, xv, yv, '-', 'Color', cmap(mod(k-1, size(cmap,1))+1, :), ...
            'LineWidth', 1.0, 'DisplayName', sprintf('#%d', di));
    end
    if cfg.logY, tAx.YScale = 'log'; end
    xlabel(tAx, xLbl); ylabel(tAx, yLbl);
    if numel(cfg.datasets) > 1, legend(tAx, 'Location','best','FontSize',max(globalOpts.fontSize-2,6)); end
end
