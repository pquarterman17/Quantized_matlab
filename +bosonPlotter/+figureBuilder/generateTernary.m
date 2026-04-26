function outFig = generateTernary(datasets, cfg, globalOpts)
%GENERATETERNARY  Ternary composition plot from three channels of one dataset.
%   Delegates rendering to plotting.ternaryPlot, which produces a fully
%   labelled triangle with optional per-point value coloring + colorbar.
%
%   cfg fields:
%     .datasetIdx   single dataset index
%     .channels     {1×3} cell of channel names {a, b, c}
%     .valueChannel ''   (no coloring) | name of a 4th channel that drives
%                        per-point colour through the current colormap
%     .markerSize   numeric (default 36)
%     .grid         logical (default true) — internal gridlines
%     .labels       {1×3} explicit vertex labels (default = channels)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasetIdx'), cfg.datasetIdx = 1; end
    ds = datasets{cfg.datasetIdx};
    if ~isfield(cfg,'channels') || numel(cfg.channels) ~= 3
        labels = ds.data.labels;
        if numel(labels) < 3
            error('Ternary:needThree','Need at least 3 channels');
        end
        cfg.channels = labels(1:3);
    end
    if ~isfield(cfg,'markerSize'),   cfg.markerSize = 36;  end
    if ~isfield(cfg,'grid'),         cfg.grid = true;       end
    if ~isfield(cfg,'valueChannel'), cfg.valueChannel = ''; end
    if ~isfield(cfg,'labels') || numel(cfg.labels) ~= 3
        cfg.labels = cfg.channels;
    end

    cols = zeros(numel(ds.data.time), 3);
    for k = 1:3
        ci = find(strcmp(ds.data.labels, cfg.channels{k}), 1);
        if isempty(ci), error('Ternary:badChannel','%s not found', cfg.channels{k}); end
        cols(:, k) = ds.data.values(:, ci);
    end
    valid = all(~isnan(cols), 2) & all(cols >= 0, 2) & sum(cols, 2) > 0;
    F = cols(valid, :);

    outFig = bosonPlotter.figureBuilder.createOutFig('Ternary', globalOpts);
    tAx = axes(outFig);
    args = {F, 'Parent', tAx, 'Labels', cfg.labels(:)', ...
            'MarkerSize', cfg.markerSize, 'Grid', cfg.grid};
    if ~isempty(cfg.valueChannel)
        vi = find(strcmp(ds.data.labels, cfg.valueChannel), 1);
        if ~isempty(vi)
            vals = ds.data.values(:, vi);
            args = [args, {'Values', vals(valid)}];
        end
    end
    plotting.ternaryPlot(args{:});
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
end
