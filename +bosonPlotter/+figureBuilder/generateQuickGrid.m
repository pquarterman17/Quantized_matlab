function outFig = generateQuickGrid(datasets, cfg, globalOpts)
%GENERATEQUICKGRID  Auto-arranged grid of datasets, one panel each.
%
%   cfg fields:
%     .datasets    [1xN] dataset indices (default: all)
%     .yChannels   {} cell of channel names per panel (default: first label)
%     .rows        target row count (auto if missing)
%     .cols        target column count (default: ceil(sqrt(N)))
%     .shareX      logical (default: true)
%     .shareY      logical (default: false)
%     .logY        logical (default: false)
%     .titleMode   'Filename' (default) | 'None' | 'Channel name'
%     .emptyMode   'Leave blank' (default) | 'Hide axes'
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets')  || isempty(cfg.datasets),  cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yChannels') || isempty(cfg.yChannels)
        if ~isempty(datasets), cfg.yChannels = datasets{1}.data.labels(1); else, cfg.yChannels = {}; end
    end
    n = numel(cfg.datasets);
    if ~isfield(cfg,'cols') || isempty(cfg.cols), cfg.cols = ceil(sqrt(n)); end
    if ~isfield(cfg,'rows') || isempty(cfg.rows), cfg.rows = ceil(n / max(1, cfg.cols)); end
    if ~isfield(cfg,'shareX'),    cfg.shareX = true;     end
    if ~isfield(cfg,'shareY'),    cfg.shareY = false;    end
    if ~isfield(cfg,'logY'),      cfg.logY   = false;    end
    if ~isfield(cfg,'titleMode'), cfg.titleMode = 'Filename'; end
    if ~isfield(cfg,'emptyMode'), cfg.emptyMode = 'Leave blank'; end

    nC = max(1, cfg.cols);
    nR = max(1, cfg.rows);
    nPanels = nR * nC;

    outFig = bosonPlotter.figureBuilder.createOutFig('Quick Grid', globalOpts);
    if cfg.shareX, sp = 'compact'; else, sp = 'normal'; end
    tlo = tiledlayout(outFig, nR, nC, 'TileSpacing', sp, 'Padding', 'compact');

    cmap = lines(max(numel(cfg.yChannels), 1));
    axList = gobjects(0);

    for k = 1:nPanels
        tAx = nexttile(tlo);
        if k > n
            if strcmp(cfg.emptyMode, 'Hide axes'), tAx.Visible = 'off'; end
            continue;
        end
        di = cfg.datasets(k);
        if di < 1 || di > numel(datasets), continue; end

        hold(tAx, 'on'); tAx.Box = 'on'; grid(tAx, 'on');
        tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;

        ci = 0; xLbl = ''; yLbl = '';
        for yi = 1:numel(cfg.yChannels)
            [xv, yv, xLbl_, yLbl_] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannels{yi});
            if isempty(xv), continue; end
            ci = ci + 1;
            plot(tAx, xv, yv, '-', 'LineWidth', 1.0, ...
                'Color', cmap(mod(yi-1, size(cmap,1))+1, :), ...
                'DisplayName', cfg.yChannels{yi});
            if isempty(xLbl), xLbl = xLbl_; end
            if isempty(yLbl), yLbl = yLbl_; end
        end
        if cfg.logY, tAx.YScale = 'log'; end

        % Title mode
        switch cfg.titleMode
            case 'Filename'
                [~, fn, fx] = fileparts(datasets{di}.filepath);
                title(tAx, [fn fx], 'FontSize', globalOpts.fontSize, 'Interpreter', 'none');
            case 'Channel name'
                title(tAx, strjoin(cfg.yChannels, ', '), ...
                    'FontSize', globalOpts.fontSize, 'Interpreter', 'none');
            % 'None' — no title
        end

        % X label: suppress non-bottom rows when sharing
        [r, c] = ind2sub([nR, nC], k);
        if cfg.shareX && r < nR
            xlabel(tAx, '');
        else
            xlabel(tAx, xLbl, 'FontSize', globalOpts.fontSize);
        end
        % Y label: suppress non-left columns when sharing
        if cfg.shareY && c > 1
            ylabel(tAx, '');
        else
            ylabel(tAx, yLbl, 'FontSize', globalOpts.fontSize);
        end
        if numel(cfg.yChannels) > 1
            legend(tAx, 'Interpreter','none', ...
                'FontSize', max(globalOpts.fontSize-2, 6), 'Location', 'best');
        end
        axList(end+1) = tAx; %#ok<AGROW>
    end

    if numel(axList) >= 2
        if cfg.shareX && cfg.shareY
            linkaxes(axList, 'xy');
        elseif cfg.shareX
            linkaxes(axList, 'x');
        elseif cfg.shareY
            linkaxes(axList, 'y');
        end
    end
end
