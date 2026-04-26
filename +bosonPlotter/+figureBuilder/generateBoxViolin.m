function outFig = generateBoxViolin(datasets, cfg, globalOpts)
%GENERATEBOXVIOLIN  Box (or violin) plot, one box per dataset for a single channel.
%   Box mode uses MATLAB's boxchart; violin mode uses a kernel density
%   estimate + filled-patch outline, since boxchart doesn't include violin
%   shape and Statistics Toolbox is forbidden by the no-toolbox rule.
%
%   cfg fields:
%     .datasets    [1xN] dataset indices
%     .yChannel    Y channel name (single)
%     .mode        'box' (default) | 'violin'
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets') || isempty(cfg.datasets), cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel), cfg.yChannel = datasets{1}.data.labels{1}; end
    if ~isfield(cfg,'mode'), cfg.mode = 'box'; end

    n = numel(cfg.datasets);
    outFig = bosonPlotter.figureBuilder.createOutFig('Box / Violin', globalOpts);
    tAx = axes(outFig); hold(tAx,'on'); tAx.Box = 'on'; grid(tAx,'on');
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;

    cmap = lines(max(n, 1));
    if strcmp(cfg.mode, 'violin')
        for k = 1:n
            [~, yv] = bosonPlotter.figureBuilder.extractXY(datasets{cfg.datasets(k)}, cfg.yChannel);
            if isempty(yv), continue; end
            yMin = min(yv); yMax = max(yv);
            grid_ = linspace(yMin - 0.05*(yMax-yMin), yMax + 0.05*(yMax-yMin), 100);
            % Simple Gaussian KDE
            sd = std(yv); if sd <= 0, sd = (yMax-yMin)/10 + eps; end
            h  = 1.06 * sd * numel(yv)^(-1/5);
            kd = mean(exp(-((grid_(:) - yv').^2) / (2*h^2)) / (h*sqrt(2*pi)), 2);
            kd = kd / max(kd) * 0.4;        % half-width = 0.4
            col = cmap(mod(k-1, size(cmap,1))+1, :);
            fill(tAx, [k - kd; flipud(k + kd)], [grid_(:); flipud(grid_(:))], col, ...
                'FaceAlpha', 0.5, 'EdgeColor', col*0.7);
            % Median tick
            yline(tAx, median(yv), '-', 'Color', col*0.6, 'LineWidth', 0.8, ...
                'HandleVisibility','off');
        end
    else
        for k = 1:n
            [~, yv] = bosonPlotter.figureBuilder.extractXY(datasets{cfg.datasets(k)}, cfg.yChannel);
            if isempty(yv), continue; end
            % Manual box: median, IQR box, whiskers
            q   = quantile(yv, [0.25 0.5 0.75]);
            iqr = q(3) - q(1);
            lo  = max(min(yv), q(1) - 1.5*iqr);
            hi  = min(max(yv), q(3) + 1.5*iqr);
            col = cmap(mod(k-1, size(cmap,1))+1, :);
            % Box
            rectangle(tAx, 'Position', [k-0.3, q(1), 0.6, iqr], ...
                'EdgeColor', col, 'FaceColor', [col 0.2]);
            % Median
            plot(tAx, [k-0.3, k+0.3], [q(2) q(2)], '-', 'Color', col, 'LineWidth', 1.5);
            % Whiskers
            plot(tAx, [k k], [lo q(1)], '-', 'Color', col);
            plot(tAx, [k k], [q(3) hi], '-', 'Color', col);
        end
    end
    xticks(tAx, 1:n);
    xticklabels(tAx, arrayfun(@(d) sprintf('#%d', d), cfg.datasets, 'UniformOutput', false));
    ylabel(tAx, cfg.yChannel);
    xlim(tAx, [0.5, n + 0.5]);
end
