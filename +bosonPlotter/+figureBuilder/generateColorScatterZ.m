function outFig = generateColorScatterZ(datasets, cfg, globalOpts)
%GENERATECOLORSCATTERZ  Scatter (x, y) coloured by z, all from one dataset.
%   Routes through plotting.colorScatterZ for rendering — supports custom
%   colormaps, alpha, edge colour, and a colorbar with label.
%
%   cfg fields:
%     .datasetIdx     single dataset index
%     .xChannel       'time' | column name (default 'time')
%     .yChannel       Y channel name
%     .zChannel       Z channel name (drives colour)
%     .colormap       'viridis' (default) | 'plasma' | 'parula' | etc.
%     .markerSize     numeric (default 25)
%     .alpha          0–1 (default 0.7)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasetIdx'), cfg.datasetIdx = 1; end
    ds = datasets{cfg.datasetIdx};
    labels = ds.data.labels;
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel), cfg.yChannel = labels{1}; end
    if ~isfield(cfg,'zChannel') || isempty(cfg.zChannel)
        if numel(labels) >= 2, cfg.zChannel = labels{2}; else, cfg.zChannel = labels{1}; end
    end
    if ~isfield(cfg,'xChannel') || isempty(cfg.xChannel), cfg.xChannel = 'time'; end
    if ~isfield(cfg,'colormap'),   cfg.colormap   = 'viridis'; end
    if ~isfield(cfg,'markerSize'), cfg.markerSize = 25; end
    if ~isfield(cfg,'alpha'),      cfg.alpha      = 0.7; end

    if strcmpi(cfg.xChannel, 'time')
        xv = double(ds.data.time);
    else
        xi = find(strcmp(labels, cfg.xChannel), 1);
        if isempty(xi), error('CSZ:badX','X channel "%s" not found', cfg.xChannel); end
        xv = ds.data.values(:, xi);
    end
    yi = find(strcmp(labels, cfg.yChannel), 1);
    zi = find(strcmp(labels, cfg.zChannel), 1);
    if isempty(yi) || isempty(zi)
        error('CSZ:badChannel','Y or Z channel not found in dataset.');
    end
    yv = ds.data.values(:, yi);
    zv = ds.data.values(:, zi);
    valid = ~isnan(xv) & ~isnan(yv) & ~isnan(zv);

    outFig = bosonPlotter.figureBuilder.createOutFig('Color Scatter (Z)', globalOpts);
    tAx = axes(outFig); hold(tAx,'on'); tAx.Box = 'on'; grid(tAx,'on');
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
    plotting.colorScatterZ(tAx, xv(valid), yv(valid), zv(valid), ...
        MarkerSize=cfg.markerSize, Colormap=cfg.colormap, Alpha=cfg.alpha, ...
        ColorbarLabel=cfg.zChannel);
    xlabel(tAx, cfg.xChannel); ylabel(tAx, cfg.yChannel);
end
