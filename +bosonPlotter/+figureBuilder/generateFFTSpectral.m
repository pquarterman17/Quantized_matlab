function outFig = generateFFTSpectral(datasets, cfg, globalOpts)
%GENERATEFFTSPECTRAL  Power spectrum (FFT) of a single Y channel from one dataset.
%
%   cfg fields:
%     .datasetIdx  single dataset index
%     .yChannel    Y channel name
%     .fs          sampling rate in Hz; if 0/empty, derived from x spacing
%     .logY        logical (default: true)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasetIdx'), cfg.datasetIdx = 1; end
    ds = datasets{cfg.datasetIdx};
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel), cfg.yChannel = ds.data.labels{1}; end
    if ~isfield(cfg,'fs'),    cfg.fs = 0; end
    if ~isfield(cfg,'logY'),  cfg.logY = true; end

    [xv, yv] = bosonPlotter.figureBuilder.extractXY(ds, cfg.yChannel);
    if numel(yv) < 4
        outFig = bosonPlotter.figureBuilder.createOutFig('FFT / Spectral', globalOpts);
        return;
    end
    if cfg.fs <= 0
        dx = median(diff(xv));
        if dx <= 0, dx = 1; end
        cfg.fs = 1 / dx;
    end

    yv = yv - mean(yv);
    N  = numel(yv);
    Y  = fft(yv);
    P  = abs(Y(1:floor(N/2)+1)).^2 / (cfg.fs * N);
    P(2:end-1) = 2 * P(2:end-1);
    f  = (0:floor(N/2))' * cfg.fs / N;

    outFig = bosonPlotter.figureBuilder.createOutFig('FFT / Spectral', globalOpts);
    tAx = axes(outFig); hold(tAx,'on'); tAx.Box = 'on'; grid(tAx,'on');
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
    plot(tAx, f, P, '-', 'LineWidth', 1.0);
    if cfg.logY, tAx.YScale = 'log'; end
    xlabel(tAx, 'Frequency'); ylabel(tAx, 'PSD');
    title(tAx, sprintf('FFT: %s', cfg.yChannel), 'Interpreter','none');
end
