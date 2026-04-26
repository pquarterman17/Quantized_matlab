function outFig = generateFFTSpectral(datasets, cfg, globalOpts)
%GENERATEFFTSPECTRAL  Power spectrum / FFT of a single Y channel.
%   Routes through utilities.fftSpectral for window functions (hanning,
%   hamming, blackman, flattop, kaiser, none), detrend modes, and
%   output choice (psd / magnitude / phase).
%
%   cfg fields:
%     .datasetIdx  single dataset index
%     .yChannel    Y channel name
%     .window      'hanning' (default) | 'hamming' | 'blackman' | 'flattop'
%                  | 'kaiser' | 'none'
%     .output      'psd' (default) | 'magnitude' | 'phase'
%     .detrend     'mean' (default) | 'linear' | 'none'
%     .logY        logical (default true)
%     .logX        logical (default false)
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasetIdx'), cfg.datasetIdx = 1; end
    ds = datasets{cfg.datasetIdx};
    if ~isfield(cfg,'yChannel') || isempty(cfg.yChannel), cfg.yChannel = ds.data.labels{1}; end
    if ~isfield(cfg,'window'),  cfg.window  = 'hanning'; end
    if ~isfield(cfg,'output'),  cfg.output  = 'psd';     end
    if ~isfield(cfg,'detrend'), cfg.detrend = 'mean';    end
    if ~isfield(cfg,'logY'),    cfg.logY    = true;      end
    if ~isfield(cfg,'logX'),    cfg.logX    = false;     end

    [xv, yv] = bosonPlotter.figureBuilder.extractXY(ds, cfg.yChannel);
    if numel(yv) < 8
        outFig = bosonPlotter.figureBuilder.createOutFig('FFT / Spectral', globalOpts);
        return;
    end

    result = utilities.fftSpectral(xv, yv, ...
        Window=cfg.window, OutputType=cfg.output, Detrend=cfg.detrend);
    switch cfg.output
        case 'magnitude', ySpec = result.magnitude;
        case 'phase',     ySpec = result.phase;
        otherwise,        ySpec = result.psd;
    end

    outFig = bosonPlotter.figureBuilder.createOutFig('FFT / Spectral', globalOpts);
    tAx = axes(outFig); hold(tAx,'on'); tAx.Box = 'on'; grid(tAx,'on');
    tAx.FontSize = globalOpts.fontSize; tAx.FontName = globalOpts.fontName;
    plot(tAx, result.freq, ySpec, '-', 'LineWidth', 1.0, 'Color', [0.12 0.47 0.71]);
    if cfg.logY, tAx.YScale = 'log'; end
    if cfg.logX, tAx.XScale = 'log'; end

    xlabel(tAx, 'Frequency', 'FontSize', globalOpts.fontSize);
    switch cfg.output
        case 'magnitude', yLbl = ['|FFT| of ' cfg.yChannel];
        case 'phase',     yLbl = 'Phase (deg)';
        otherwise,        yLbl = [cfg.yChannel '^2 / Hz'];
    end
    ylabel(tAx, yLbl, 'Interpreter','none');
    title(tAx, sprintf('Spectral: %s (%s window, %s)', ...
        cfg.yChannel, cfg.window, cfg.output), ...
        'FontSize', globalOpts.fontSize + 1, 'Interpreter', 'none');
end
