function outFig = generateBoxViolin(datasets, cfg, globalOpts)
%GENERATEBOXVIOLIN  Box / violin / swarm plot, one column per dataset.
%   Routes through plotting.boxViolinSwarm for the actual rendering, which
%   supports four styles, mean markers, outlier toggles, and orientation.
%
%   cfg fields:
%     .datasets     [1xN] dataset indices
%     .yChannel     Y channel name
%     .style        'box' (default) | 'violin' | 'swarm' | 'box+swarm'
%     .orientation  'vertical' (default) | 'horizontal'
%     .showMean     logical (default true)
%     .showOutliers logical (default true)
%     .width        scalar 0.1–1.5 (default 0.6)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets')     || isempty(cfg.datasets), cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yChannel')     || isempty(cfg.yChannel), cfg.yChannel = datasets{1}.data.labels{1}; end
    if ~isfield(cfg,'style'),       cfg.style       = 'box'; end
    if ~isfield(cfg,'orientation'), cfg.orientation = 'vertical'; end
    if ~isfield(cfg,'showMean'),    cfg.showMean    = true; end
    if ~isfield(cfg,'showOutliers'),cfg.showOutliers= true; end
    if ~isfield(cfg,'width'),       cfg.width       = 0.6; end

    n = numel(cfg.datasets);
    dataCell = cell(1, n);
    labels   = cell(1, n);
    for k = 1:n
        di = cfg.datasets(k);
        if di < 1 || di > numel(datasets), continue; end
        [~, yv] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannel);
        dataCell{k} = yv;
        labels{k}   = sprintf('#%d', di);
    end

    outFig = bosonPlotter.figureBuilder.createOutFig('Box / Violin', globalOpts);
    tAx = axes(outFig);
    plotting.boxViolinSwarm(tAx, dataCell, ...
        Style=cfg.style, Labels=labels, Orientation=cfg.orientation, ...
        ShowMean=cfg.showMean, ShowOutliers=cfg.showOutliers, Width=cfg.width);
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
    if strcmp(cfg.orientation, 'horizontal')
        xlabel(tAx, cfg.yChannel);
    else
        ylabel(tAx, cfg.yChannel);
    end
end
