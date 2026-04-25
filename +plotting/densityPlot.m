function h = densityPlot(ax, x, y, Options)
%DENSITYPLOT  2D density / heatmap of dense scatter data.
%
%   Syntax:
%       h = plotting.densityPlot(ax, x, y)
%       h = plotting.densityPlot(ax, x, y, NBins=128, LogCounts=true)
%
%   Bins (x,y) into a 2D grid and renders the count map as an image.
%   Useful for >10^4 points where individual markers heavily overplot.
%
%   Inputs:
%       ax — target axes handle
%       x  — [N×1] x-data (finite values used; non-finite skipped)
%       y  — [N×1] y-data
%
%   Options (name-value):
%       NBins        — scalar or [nx ny] bin counts. Default
%                      ceil(sqrt(N)/2), clamped to [16, 256].
%       XEdges       — explicit x bin edges (overrides NBins along x)
%       YEdges       — explicit y bin edges (overrides NBins along y)
%       LogCounts    — apply log10(1 + counts) to flatten dynamic range
%                      (default false)
%       Colormap     — colormap name string ('parula' | 'hot' | 'viridis' |
%                      'turbo' | 'magma' | 'inferno') or [M×3] RGB matrix.
%                      Default 'parula'.
%       SmoothSigma  — scalar or [σx σy] Gaussian smoothing (in bin units).
%                      0 disables smoothing (default 0).
%       ShowColorbar — append a colorbar (default true)
%       EmptyColor   — RGB for empty bins (alpha-masked); default white.
%
%   Output:
%       h — struct with fields:
%             .image     — image graphics object (imagesc)
%             .axes      — ax (returned for chaining)
%             .colorbar  — colorbar handle (or [] if disabled)
%             .counts    — [nx × ny] count matrix (post-smooth, post-log)
%             .xCenters  — bin centers along x
%             .yCenters  — bin centers along y
%
%   Examples:
%       % High-density M-H sweep with 50k samples
%       x = 1000*sin(linspace(0,8*pi,50000)) + 50*randn(1,50000);
%       y = tanh(x/500) + 0.05*randn(1,50000);
%       fig = figure; ax = axes(fig);
%       h = plotting.densityPlot(ax, x, y, NBins=200, LogCounts=true);
%       xlabel(ax, 'H (Oe)'); ylabel(ax, 'M (μ_B)');
%
%   See also histcounts2, imagesc, colormap

    arguments
        ax  (1,1) matlab.graphics.axis.Axes
        x   (:,1) double
        y   (:,1) double
        Options.NBins                       double  = []
        Options.XEdges                      double  = []
        Options.YEdges                      double  = []
        Options.LogCounts            (1,1)  logical = false
        Options.Colormap                            = 'parula'
        Options.SmoothSigma                 double  = 0
        Options.ShowColorbar         (1,1)  logical = true
        Options.EmptyColor           (1,3)  double  = [1 1 1]
    end

    % Drop non-finite pairs
    finiteMask = isfinite(x) & isfinite(y);
    x = x(finiteMask);
    y = y(finiteMask);
    if isempty(x)
        error('plotting:densityPlot:noData', ...
              'No finite (x,y) pairs to bin.');
    end
    n = numel(x);

    % ── Determine bin edges ─────────────────────────────────────────────
    if isempty(Options.NBins)
        nb = max(16, min(256, ceil(sqrt(n)/2)));
        nbX = nb;  nbY = nb;
    elseif isscalar(Options.NBins)
        nbX = round(Options.NBins);  nbY = nbX;
    else
        nbX = round(Options.NBins(1));  nbY = round(Options.NBins(2));
    end

    if ~isempty(Options.XEdges)
        xEdges = Options.XEdges(:).';
    else
        xMin = min(x);  xMax = max(x);
        if xMin == xMax, xMax = xMin + 1; end
        xEdges = linspace(xMin, xMax, nbX + 1);
    end
    if ~isempty(Options.YEdges)
        yEdges = Options.YEdges(:).';
    else
        yMin = min(y);  yMax = max(y);
        if yMin == yMax, yMax = yMin + 1; end
        yEdges = linspace(yMin, yMax, nbY + 1);
    end

    xCenters = (xEdges(1:end-1) + xEdges(2:end)) / 2;
    yCenters = (yEdges(1:end-1) + yEdges(2:end)) / 2;

    % ── Bin ─────────────────────────────────────────────────────────────
    counts = histcounts2(x, y, xEdges, yEdges);   % [nx × ny]

    % ── Optional Gaussian smoothing (separable, no toolbox) ─────────────
    sig = Options.SmoothSigma;
    if isscalar(sig), sigX = sig; sigY = sig; else, sigX = sig(1); sigY = sig(2); end
    if sigX > 0 || sigY > 0
        counts = gaussSmooth2(counts, sigX, sigY);
    end

    % ── Optional log compression ────────────────────────────────────────
    displayCounts = counts;
    if Options.LogCounts
        displayCounts = log10(1 + displayCounts);
    end

    % ── Render ──────────────────────────────────────────────────────────
    cla(ax);
    % imagesc lays out columns as x; counts is [nx × ny] so transpose.
    h.image = imagesc(ax, xCenters, yCenters, displayCounts.');
    % Mask zero-count cells with EmptyColor by setting AlphaData
    if any(displayCounts(:) == 0)
        alpha = ones(size(displayCounts.'));
        alpha(displayCounts.' == 0) = 0;
        h.image.AlphaData = alpha;
        ax.Color = Options.EmptyColor;
    end
    set(ax, 'YDir', 'normal');
    ax.XLim = [xEdges(1), xEdges(end)];
    ax.YLim = [yEdges(1), yEdges(end)];

    % Colormap
    cmap = resolveColormap(Options.Colormap);
    colormap(ax, cmap);

    % Colorbar
    if Options.ShowColorbar
        h.colorbar = colorbar(ax);
        if Options.LogCounts
            h.colorbar.Label.String = 'log_{10}(1+count)';
        else
            h.colorbar.Label.String = 'count';
        end
    else
        h.colorbar = [];
    end

    h.axes     = ax;
    h.counts   = displayCounts;
    h.xCenters = xCenters;
    h.yCenters = yCenters;
end

% ════════════════════════════════════════════════════════════════════════
%  HELPER: gaussSmooth2 — Separable 2D Gaussian (MATLAB built-ins only)
% ════════════════════════════════════════════════════════════════════════
function out = gaussSmooth2(M, sigX, sigY)
    out = M;
    if sigX > 0
        kx = gaussKernel(sigX);
        out = conv2(out, kx(:).', 'same');
    end
    if sigY > 0
        ky = gaussKernel(sigY);
        out = conv2(out, ky(:), 'same');
    end
end

function k = gaussKernel(sigma)
    r = ceil(3 * sigma);
    if r < 1, r = 1; end
    x = -r:r;
    k = exp(-x.^2 / (2*sigma^2));
    k = k / sum(k);
end

% ════════════════════════════════════════════════════════════════════════
%  HELPER: resolveColormap — Accept name strings or RGB matrices
% ════════════════════════════════════════════════════════════════════════
function cmap = resolveColormap(spec)
    if isnumeric(spec) && size(spec, 2) == 3
        cmap = spec;
        return;
    end
    % Delegate to bosonPlotter.colorMaps for both built-in (parula, jet,
    % hot, ...) and perceptual names (viridis, plasma, inferno).
    try
        cmap = bosonPlotter.colorMaps(char(spec), 256);
    catch
        warning('plotting:densityPlot:unknownColormap', ...
            'Unknown colormap "%s"; using parula.', char(spec));
        cmap = parula(256);
    end
end
