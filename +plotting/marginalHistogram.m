function handles = marginalHistogram(ax, x, y, Options)
%MARGINALHISTOGRAM  Scatter plot with marginal histograms on X and Y axes.
%
%   Syntax:
%       handles = plotting.marginalHistogram(ax, x, y)
%       handles = plotting.marginalHistogram(ax, x, y, NBins=40, ShowKDE=true)
%
%   Inputs:
%       ax — axes handle (used only to locate the parent figure and set
%            position; the returned handles struct contains the actual axes)
%       x  — [N×1] x-data
%       y  — [N×1] y-data
%
%   Options (name-value):
%       NBins       — number of histogram bins                (default 30)
%       ScatterOpts — struct with optional fields:
%                       .MarkerSize (default 20)
%                       .Color      (default [0.2 0.4 0.7])
%                       .Alpha      (default 0.5)
%       HistColor   — [1×3] RGB for histogram bars            (default [0.3 0.5 0.8])
%       HistAlpha   — histogram bar transparency              (default 0.6)
%       ShowKDE     — overlay Gaussian KDE curve on histograms (default false)
%       Layout      — "tight" | "spaced"                      (default "tight")
%
%   Output:
%       handles — struct with fields:
%           .axMain    — central scatter axes
%           .axTop     — top marginal histogram axes (X distribution)
%           .axRight   — right marginal histogram axes (Y distribution)
%           .scatterH  — scatter graphics object
%           .histTopH  — histogram object in top axes
%           .histRightH — histogram object in right axes
%
%   Notes:
%       The three axes panels are positioned manually inside the parent
%       figure of the supplied ax.  ax itself is deleted and replaced —
%       pass any axes from the target figure.
%
%   Examples:
%       fig = figure; ax = axes(fig);
%       x = randn(300,1); y = 0.6*x + randn(300,1);
%       h = plotting.marginalHistogram(ax, x, y, ShowKDE=true);
%
%   See also scatter, histogram

arguments
    ax  (1,1) matlab.graphics.axis.Axes
    x   (:,1) double
    y   (:,1) double
    Options.NBins      (1,1) double {mustBePositive, mustBeInteger} = 30
    Options.ScatterOpts                                             = struct()
    Options.HistColor  (1,3) double                                 = [0.3 0.5 0.8]
    Options.HistAlpha  (1,1) double {mustBeNonnegative, mustBeLessThanOrEqual(Options.HistAlpha,1)} = 0.6
    Options.ShowKDE    (1,1) logical                                = false
    Options.Layout     (1,1) string ...
        {mustBeMember(Options.Layout, ["tight","spaced"])}          = "tight"
end

% ════════════════════════════════════════════════════════════════════════
%  Resolve scatter options
% ════════════════════════════════════════════════════════════════════════
sOpts = Options.ScatterOpts;
if ~isfield(sOpts, 'MarkerSize'), sOpts.MarkerSize = 20;              end
if ~isfield(sOpts, 'Color'),      sOpts.Color      = [0.2 0.4 0.7];  end
if ~isfield(sOpts, 'Alpha'),      sOpts.Alpha      = 0.5;            end

% ════════════════════════════════════════════════════════════════════════
%  Locate parent figure and delete placeholder axes
% ════════════════════════════════════════════════════════════════════════
fig = ancestor(ax, 'figure');
delete(ax);

% ════════════════════════════════════════════════════════════════════════
%  Define panel positions [left bottom width height] in normalised units
% ════════════════════════════════════════════════════════════════════════
if strcmp(Options.Layout, "tight")
    gap  = 0.02;
    marg = 0.12;   % outer margin
else
    gap  = 0.04;
    marg = 0.13;
end

histH = 0.20;   % height of top/right histogram panels
histW = 0.20;   % width of right histogram panel

mainL = marg;
mainB = marg;
mainW = 1 - marg - histW - gap - 0.02;
mainH = 1 - marg - histH - gap - 0.02;

topL = mainL;
topB = mainB + mainH + gap;
topW = mainW;
topH = histH;

rightL = mainL + mainW + gap;
rightB = mainB;
rightW = histW;
rightH = mainH;

% ════════════════════════════════════════════════════════════════════════
%  Create three axes
% ════════════════════════════════════════════════════════════════════════
axMain  = axes('Parent', fig, 'Position', [mainL  mainB  mainW  mainH]);
axTop   = axes('Parent', fig, 'Position', [topL   topB   topW   topH]);
axRight = axes('Parent', fig, 'Position', [rightL rightB rightW rightH]);

% ════════════════════════════════════════════════════════════════════════
%  Draw scatter in main axes
% ════════════════════════════════════════════════════════════════════════
scatterH = scatter(axMain, x, y, sOpts.MarkerSize, 'filled', ...
    'MarkerFaceColor', sOpts.Color, ...
    'MarkerFaceAlpha', sOpts.Alpha, ...
    'MarkerEdgeColor', 'none');

% ════════════════════════════════════════════════════════════════════════
%  Top histogram (X distribution)
% ════════════════════════════════════════════════════════════════════════
histTopH = histogram(axTop, x, Options.NBins, ...
    'FaceColor', Options.HistColor, ...
    'FaceAlpha', Options.HistAlpha, ...
    'EdgeColor', 'none');
axTop.XTickLabel = {};
axTop.Box        = 'off';
axTop.XAxis.Visible = 'off';

% ════════════════════════════════════════════════════════════════════════
%  Right histogram (Y distribution, horizontal)
% ════════════════════════════════════════════════════════════════════════
histRightH = histogram(axRight, y, Options.NBins, ...
    'Orientation', 'horizontal', ...
    'FaceColor',   Options.HistColor, ...
    'FaceAlpha',   Options.HistAlpha, ...
    'EdgeColor',   'none');
axRight.YTickLabel  = {};
axRight.Box         = 'off';
axRight.YAxis.Visible = 'off';

% ════════════════════════════════════════════════════════════════════════
%  KDE overlays (optional)
% ════════════════════════════════════════════════════════════════════════
if Options.ShowKDE
    overlayKDE(axTop,   x, Options.HistColor, false);
    overlayKDE(axRight, y, Options.HistColor, true);
end

% ════════════════════════════════════════════════════════════════════════
%  Link axes limits
% ════════════════════════════════════════════════════════════════════════
linkaxes([axMain, axTop],   'x');
linkaxes([axMain, axRight], 'y');

% ════════════════════════════════════════════════════════════════════════
%  Pack output struct
% ════════════════════════════════════════════════════════════════════════
handles = struct( ...
    'axMain',     axMain, ...
    'axTop',      axTop, ...
    'axRight',    axRight, ...
    'scatterH',   scatterH, ...
    'histTopH',   histTopH, ...
    'histRightH', histRightH);

end  % marginalHistogram

% ════════════════════════════════════════════════════════════════════════
%  LOCAL: Overlay Gaussian KDE curve on a histogram axes
% ════════════════════════════════════════════════════════════════════════
function overlayKDE(ax, d, col, horizontal)
%OVERLAYKDE  Draw a scaled KDE density curve on histogram axes.

d = d(isfinite(d));
n = numel(d);
if n < 2
    return;
end

% Silverman bandwidth
sig   = std(d);
iqrBW = iqr(d) / 1.34;
if iqrBW == 0, iqrBW = sig; end
if sig == 0 && iqrBW == 0, return; end
bw = 0.9 * min(sig, iqrBW) * n^(-0.2);
if bw == 0, return; end

xGrid = linspace(min(d) - 3*bw, max(d) + 3*bw, 256)';
density = zeros(256, 1);
for i = 1:n
    density = density + exp(-0.5 * ((xGrid - d(i)) / bw).^2);
end
density = density / (n * bw * sqrt(2*pi));

% Scale density to match histogram counts (bin area → counts)
edgeVec = linspace(min(d), max(d), 31);
binW    = edgeVec(2) - edgeVec(1);
if binW > 0
    density = density * n * binW;
end

hold(ax, 'on');
if horizontal
    plot(ax, density, xGrid, '-', 'Color', col, 'LineWidth', 1.5);
else
    plot(ax, xGrid, density, '-', 'Color', col, 'LineWidth', 1.5);
end

end
