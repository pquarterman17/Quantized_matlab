function outFig = generateConfidenceBand(datasets, cfg, globalOpts)
%GENERATECONFIDENCEBAND  Mean ± std (or median ± IQR) shaded band over repeats.
%
%   cfg fields:
%     .datasets   [1xN] dataset indices treated as repeats of the same measurement
%     .yChannel   Y channel name
%     .summary    'mean+std' (default) | 'median+iqr'
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets') || isempty(cfg.datasets), cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel), cfg.yChannel = datasets{1}.data.labels{1}; end
    if ~isfield(cfg,'summary'), cfg.summary = 'mean+std'; end

    % Resample everyone onto the first dataset's x grid
    [xRef, ~, xLbl, yLbl] = bosonPlotter.figureBuilder.extractXY( ...
        datasets{cfg.datasets(1)}, cfg.yChannel);
    n = numel(cfg.datasets);
    Y = nan(numel(xRef), n);
    for k = 1:n
        di = cfg.datasets(k);
        [xv, yv] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannel);
        if isempty(xv), continue; end
        Y(:, k) = interp1(xv, yv, xRef, 'linear', NaN);
    end

    switch cfg.summary
        case 'median+iqr'
            mid  = median(Y, 2, 'omitnan');
            q25  = quantile(Y, 0.25, 2);
            q75  = quantile(Y, 0.75, 2);
            lo   = q25; hi = q75;
            lblM = 'Median'; lblB = 'IQR';
        otherwise
            mid  = mean(Y, 2, 'omitnan');
            sd   = std(Y, 0, 2, 'omitnan');
            lo   = mid - sd; hi = mid + sd;
            lblM = 'Mean';  lblB = '\pm 1\sigma';
    end

    outFig = bosonPlotter.figureBuilder.createOutFig('Confidence Band', globalOpts);
    tAx = axes(outFig); hold(tAx,'on'); tAx.Box = 'on'; grid(tAx,'on');
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
    keep = ~isnan(mid) & ~isnan(lo) & ~isnan(hi);
    fill(tAx, [xRef(keep); flipud(xRef(keep))], [lo(keep); flipud(hi(keep))], ...
        [0.4 0.6 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.3, ...
        'DisplayName', lblB);
    plot(tAx, xRef(keep), mid(keep), '-', 'Color', [0.15 0.37 0.63], ...
        'LineWidth', 1.2, 'DisplayName', lblM);
    xlabel(tAx, xLbl); ylabel(tAx, yLbl);
    legend(tAx, 'Location','best','FontSize',max(globalOpts.fontSize-2,6));
end
