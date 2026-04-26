function outFig = generateTernary(datasets, cfg, globalOpts)
%GENERATETERNARY  Ternary plot (a + b + c = 1) from three channels of one dataset.
%   Renders as a Cartesian plot with a triangle outline + grid; data points
%   are projected onto the equilateral triangle.
%
%   cfg fields:
%     .datasetIdx     single dataset index
%     .channels       {1×3} cell of channel names {a, b, c}
%     .markerSize     numeric (default 25)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasetIdx'), cfg.datasetIdx = 1; end
    ds = datasets{cfg.datasetIdx};
    if ~isfield(cfg,'channels') || numel(cfg.channels) ~= 3
        labels = ds.data.labels;
        n = min(3, numel(labels));
        cfg.channels = labels(1:n);
        if n < 3, error('Ternary:needThree','Need at least 3 channels'); end
    end
    if ~isfield(cfg,'markerSize'), cfg.markerSize = 25; end

    cols = zeros(numel(ds.data.time), 3);
    for k = 1:3
        ci = find(strcmp(ds.data.labels, cfg.channels{k}), 1);
        if isempty(ci), error('Ternary:badChannel','%s not found', cfg.channels{k}); end
        cols(:, k) = ds.data.values(:, ci);
    end
    valid = all(~isnan(cols), 2);
    cols = cols(valid, :);
    rows = sum(cols, 2);
    rows(rows == 0) = 1;        % avoid div-by-zero
    cols = cols ./ rows;        % normalise so a+b+c = 1

    % Project onto equilateral triangle
    a = cols(:, 1); b = cols(:, 2); c = cols(:, 3);
    xCart = 0.5 * (2*b + c) ./ (a + b + c);
    yCart = (sqrt(3) / 2) * c ./ (a + b + c);

    outFig = bosonPlotter.figureBuilder.createOutFig('Ternary', globalOpts);
    tAx = axes(outFig); hold(tAx,'on'); tAx.Box = 'off';
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
    axis(tAx, 'equal'); axis(tAx, 'off');

    % Triangle outline
    triX = [0 1 0.5 0]; triY = [0 0 sqrt(3)/2 0];
    plot(tAx, triX, triY, 'k-', 'LineWidth', 1.0);

    % Vertex labels
    text(tAx, -0.03, -0.03, cfg.channels{1}, 'HorizontalAlignment','right', 'FontSize',globalOpts.fontSize);
    text(tAx,  1.03, -0.03, cfg.channels{2}, 'HorizontalAlignment','left',  'FontSize',globalOpts.fontSize);
    text(tAx,  0.50, sqrt(3)/2 + 0.04, cfg.channels{3}, 'HorizontalAlignment','center', 'FontSize',globalOpts.fontSize);

    scatter(tAx, xCart, yCart, cfg.markerSize, 'filled');
end
