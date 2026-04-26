function outFig = generateContour(datasets, cfg, globalOpts)
%GENERATECONTOUR  Heatmap / contour of an [X × dataset-index] grid built
%   by stacking one Y channel from each dataset (rows = x, cols = dataset).
%
%   cfg fields:
%     .datasets    [1xN] dataset indices (the column axis)
%     .yChannel    Y channel name
%     .yValues     [1xN] numeric labels for the dataset axis (default: 1:N)
%     .yLabel      string label for the dataset axis (default: 'Index')
%     .colormap    e.g. 'parula', 'viridis' (default: 'parula')
%     .filled      logical (default: true → contourf, else contour)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets') || isempty(cfg.datasets), cfg.datasets = 1:numel(datasets); end
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel), cfg.yChannel = datasets{1}.data.labels{1}; end
    n = numel(cfg.datasets);
    if ~isfield(cfg,'yValues') || numel(cfg.yValues) ~= n, cfg.yValues = 1:n; end
    if ~isfield(cfg,'yLabel'), cfg.yLabel = 'Index'; end
    if ~isfield(cfg,'colormap'), cfg.colormap = 'parula'; end
    if ~isfield(cfg,'filled'), cfg.filled = true; end

    % Resample all onto the first dataset's x grid
    [xRef, ~, xLbl] = bosonPlotter.figureBuilder.extractXY( ...
        datasets{cfg.datasets(1)}, cfg.yChannel);
    Z = nan(numel(xRef), n);
    for k = 1:n
        [xv, yv] = bosonPlotter.figureBuilder.extractXY(datasets{cfg.datasets(k)}, cfg.yChannel);
        if isempty(xv), continue; end
        Z(:, k) = interp1(xv, yv, xRef, 'linear', NaN);
    end
    [Xg, Yg] = meshgrid(cfg.yValues, xRef);    % rows = x, cols = dataset

    outFig = bosonPlotter.figureBuilder.createOutFig('Contour / Heatmap', globalOpts);
    tAx = axes(outFig);
    if cfg.filled
        contourf(tAx, Xg, Yg, Z, 20, 'LineStyle', 'none');
    else
        contour(tAx, Xg, Yg, Z, 20);
    end
    try
        colormap(tAx, cfg.colormap);
    catch
        colormap(tAx, 'parula');
    end
    cb = colorbar(tAx);
    cb.Label.String = cfg.yChannel;
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
    xlabel(tAx, cfg.yLabel); ylabel(tAx, xLbl);
end
