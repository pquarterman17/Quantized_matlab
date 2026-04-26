function outFig = generateContour(datasets, cfg, globalOpts)
%GENERATECONTOUR  Heatmap / contour from three columns of one dataset.
%   Interpolates scattered (X, Y, Z) onto a regular grid (scatteredInterpolant
%   when available, else griddata) then renders as filled contour, contour
%   lines, pcolor, or 3D surface.
%
%   cfg fields:
%     .datasetIdx  single dataset index
%     .xChannel    'time' (default) | column name (default = first)
%     .yChannel    column name
%     .zChannel    column name
%     .plotStyle   'filled' (default) | 'lines' | 'pcolor' | 'surface3d'
%     .colormap    'parula' | 'viridis' | 'plasma' | 'inferno' | etc.
%     .nGrid       interpolation grid size (default: min(200, 2*sqrt(N)))
%
%   Legacy (for back-compat with the old dataset-stack mode):
%     .datasets    [1xN] of indices to stack as columns of the grid (old
%                  behaviour). When this is set, falls back to the previous
%                  algorithm — interpolate first dataset's xChannel onto a
%                  reference grid and stack.
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end

    % If user supplied the old multi-dataset .datasets list, fall back to
    % stack-by-dataset mode for back-compat with earlier scripts.
    if isfield(cfg,'datasets') && ~isempty(cfg.datasets) && ~isfield(cfg,'datasetIdx')
        outFig = generateContour_legacy(datasets, cfg, globalOpts);
        return;
    end

    if ~isfield(cfg,'datasetIdx'), cfg.datasetIdx = 1; end
    ds = datasets{cfg.datasetIdx};
    labels = ds.data.labels;
    if ~isfield(cfg,'xChannel') || isempty(cfg.xChannel), cfg.xChannel = 'time'; end
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel)
        cfg.yChannel = labels{min(1, numel(labels))};
    end
    if ~isfield(cfg,'zChannel') || isempty(cfg.zChannel)
        cfg.zChannel = labels{min(2, numel(labels))};
    end
    if ~isfield(cfg,'plotStyle'), cfg.plotStyle = 'filled'; end
    if ~isfield(cfg,'colormap'),  cfg.colormap = 'parula';  end

    if strcmpi(cfg.xChannel, 'time')
        xV = double(ds.data.time(:));  xLbl = 'X';
    else
        xi = find(strcmp(labels, cfg.xChannel), 1);
        if isempty(xi), error('Contour:badX','%s not found', cfg.xChannel); end
        xV = ds.data.values(:, xi);  xLbl = cfg.xChannel;
    end
    yi = find(strcmp(labels, cfg.yChannel), 1);
    zi = find(strcmp(labels, cfg.zChannel), 1);
    if isempty(yi) || isempty(zi)
        error('Contour:badChannel','Y or Z channel not found in dataset.');
    end
    yV = ds.data.values(:, yi);  yLbl = cfg.yChannel;
    zV = ds.data.values(:, zi);  zLbl = cfg.zChannel;

    valid = ~isnan(xV) & ~isnan(yV) & ~isnan(zV);
    xV = xV(valid); yV = yV(valid); zV = zV(valid);
    if numel(xV) < 4
        outFig = bosonPlotter.figureBuilder.createOutFig('Contour', globalOpts);
        return;
    end

    if ~isfield(cfg,'nGrid') || isempty(cfg.nGrid)
        cfg.nGrid = min(200, round(sqrt(numel(xV)) * 2));
    end
    nG = cfg.nGrid;
    xLin = linspace(min(xV), max(xV), nG);
    yLin = linspace(min(yV), max(yV), nG);
    [Xg, Yg] = meshgrid(xLin, yLin);
    try
        F = scatteredInterpolant(xV, yV, zV, 'linear', 'none');
        Zg = F(Xg, Yg);
    catch
        Zg = griddata(xV, yV, zV, Xg, Yg, 'linear'); %#ok<GRIDD>
    end

    outFig = bosonPlotter.figureBuilder.createOutFig('Contour / Heatmap', globalOpts);
    tAx = axes(outFig);
    switch lower(cfg.plotStyle)
        case 'lines'
            [C, h] = contour(tAx, Xg, Yg, Zg, 15);
            clabel(C, h, 'FontSize', max(globalOpts.fontSize-2, 6));
        case 'pcolor'
            pcolor(tAx, Xg, Yg, Zg);  shading(tAx, 'flat');
        case 'surface3d'
            surf(tAx, Xg, Yg, Zg, 'EdgeColor', 'none');
            view(tAx, -37.5, 30);
            try, rotate3d(outFig, 'on'); catch, end
        otherwise   % 'filled'
            contourf(tAx, Xg, Yg, Zg, 20, 'LineStyle', 'none');
    end
    try
        colormap(tAx, bosonPlotter.colorMaps(cfg.colormap, 256));
    catch
        colormap(tAx, 'parula');
    end
    cb = colorbar(tAx);
    cb.Label.String = zLbl;
    cb.Label.Interpreter = 'none';
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
    xlabel(tAx, xLbl, 'Interpreter','none');
    ylabel(tAx, yLbl, 'Interpreter','none');
    title(tAx, zLbl, 'FontSize', globalOpts.fontSize + 1, 'Interpreter', 'none');
end

function outFig = generateContour_legacy(datasets, cfg, globalOpts)
%GENERATECONTOUR_LEGACY  Old behaviour: stack one Y channel across N datasets.
    if ~isfield(cfg,'datasets') || isempty(cfg.datasets), cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel), cfg.yChannel = datasets{1}.data.labels{1}; end
    n = numel(cfg.datasets);
    if ~isfield(cfg,'yValues') || numel(cfg.yValues) ~= n, cfg.yValues = 1:n; end
    if ~isfield(cfg,'yLabel'),    cfg.yLabel    = 'Index';   end
    if ~isfield(cfg,'colormap'),  cfg.colormap  = 'parula';  end
    if ~isfield(cfg,'plotStyle'), cfg.plotStyle = 'filled';   end

    [xRef, ~, xLbl] = bosonPlotter.figureBuilder.extractXY(datasets{cfg.datasets(1)}, cfg.yChannel);
    Z = nan(numel(xRef), n);
    for k = 1:n
        [xv, yv] = bosonPlotter.figureBuilder.extractXY(datasets{cfg.datasets(k)}, cfg.yChannel);
        if isempty(xv), continue; end
        Z(:, k) = interp1(xv, yv, xRef, 'linear', NaN);
    end
    [Xg, Yg] = meshgrid(cfg.yValues, xRef);

    outFig = bosonPlotter.figureBuilder.createOutFig('Contour / Heatmap', globalOpts);
    tAx = axes(outFig);
    if strcmpi(cfg.plotStyle, 'lines')
        contour(tAx, Xg, Yg, Z, 20);
    else
        contourf(tAx, Xg, Yg, Z, 20, 'LineStyle', 'none');
    end
    try, colormap(tAx, cfg.colormap); catch, colormap(tAx, 'parula'); end
    cb = colorbar(tAx);
    cb.Label.String = cfg.yChannel;
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
    xlabel(tAx, cfg.yLabel); ylabel(tAx, xLbl);
end
