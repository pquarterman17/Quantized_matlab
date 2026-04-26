function outFig = generateGroupedPlot(datasets, cfg, globalOpts)
%GENERATEGROUPEDPLOT  Overlay multiple datasets, coloured by group label.
%
%   cfg fields:
%     .datasets   [1xN] dataset indices
%     .yChannel   Y channel name
%     .groups     [1xN] group label per dataset (cellstr) — same group
%                 means same colour. Default: each dataset its own group.
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets') || isempty(cfg.datasets), cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel), cfg.yChannel = datasets{1}.data.labels{1}; end
    if ~isfield(cfg,'groups')   || numel(cfg.groups) ~= numel(cfg.datasets)
        cfg.groups = arrayfun(@(k) sprintf('Group %d', k), 1:numel(cfg.datasets), 'UniformOutput', false);
    end

    [uniqueGroups, ~, gIdx] = unique(cfg.groups, 'stable');
    nG = numel(uniqueGroups);
    cmap = lines(max(nG, 1));

    outFig = bosonPlotter.figureBuilder.createOutFig('Grouped Plot', globalOpts);
    tAx = axes(outFig); hold(tAx,'on'); tAx.Box = 'on'; grid(tAx,'on');
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;

    seen = false(1, nG);
    xLbl = ''; yLbl = cfg.yChannel;
    for k = 1:numel(cfg.datasets)
        di = cfg.datasets(k);
        [xv, yv, xLbl_, ~] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannel);
        if isempty(xv), continue; end
        if isempty(xLbl), xLbl = xLbl_; end
        gi = gIdx(k);
        col = cmap(mod(gi-1, size(cmap,1))+1, :);
        % Only show legend entry for the first member of each group
        if ~seen(gi)
            plot(tAx, xv, yv, '-', 'Color', col, 'LineWidth', 1.0, ...
                'DisplayName', uniqueGroups{gi});
            seen(gi) = true;
        else
            plot(tAx, xv, yv, '-', 'Color', col, 'LineWidth', 1.0, ...
                'HandleVisibility', 'off');
        end
    end
    xlabel(tAx, xLbl); ylabel(tAx, yLbl);
    if nG > 1, legend(tAx, 'Location','best','FontSize',max(globalOpts.fontSize-2,6)); end
end
