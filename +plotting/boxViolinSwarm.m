function hGroup = boxViolinSwarm(ax, dataCell, Options)
%BOXVIOLINSWARM  Draw box, violin, or bee-swarm plots on the given axes.
%
%   Syntax:
%       hGroup = plotting.boxViolinSwarm(ax, dataCell)
%       hGroup = plotting.boxViolinSwarm(ax, dataCell, Style="violin", Labels={"A","B"})
%
%   Inputs:
%       ax       - target axes handle
%       dataCell - {1×N} cell array; each cell is a numeric column vector
%
%   Options (name-value):
%       Style        - "box" | "violin" | "swarm" | "box+swarm"  (default "box")
%       Labels       - {1×N} string/char cell of category labels
%       Orientation  - "vertical" | "horizontal"                 (default "vertical")
%       ShowMean     - logical, overlay mean marker               (default true)
%       ShowOutliers - logical, show outlier points for box plot  (default true)
%       Colors       - [N×3] RGB matrix (default: plotting.lineColors)
%       Width        - scalar box/violin width fraction           (default 0.6)
%
%   Output:
%       hGroup - struct with graphics handles:
%                .boxes, .medians, .whiskers, .outliers,
%                .violins, .swarm, .means
%
%   Examples:
%       d = {randn(50,1), randn(50,1)+1, randn(30,1)*2};
%       fig = figure; ax = axes(fig);
%       plotting.boxViolinSwarm(ax, d, Style="violin", Labels={"A","B","C"});
%
%       plotting.boxViolinSwarm(ax, d, Style="box+swarm", Orientation="horizontal");
%
%   See also plotting.lineColors, patch, scatter

arguments
    ax       (1,1) matlab.graphics.axis.Axes
    dataCell (1,:) cell
    Options.Style        (1,1) string ...
        {mustBeMember(Options.Style, ["box","violin","swarm","box+swarm"])} = "box"
    Options.Labels       (1,:) cell   = {}
    Options.Orientation  (1,1) string ...
        {mustBeMember(Options.Orientation, ["vertical","horizontal"])} = "vertical"
    Options.ShowMean     (1,1) logical = true
    Options.ShowOutliers (1,1) logical = true
    Options.Colors       (:,3) double  = []
    Options.Width        (1,1) double  {mustBePositive} = 0.6
end

% ════════════════════════════════════════════════════════════════════════
%  Initialise output struct
% ════════════════════════════════════════════════════════════════════════
hGroup = struct( ...
    'boxes',    gobjects(0), ...
    'medians',  gobjects(0), ...
    'whiskers', gobjects(0), ...
    'outliers', gobjects(0), ...
    'violins',  gobjects(0), ...
    'swarm',    gobjects(0), ...
    'means',    gobjects(0));

n = numel(dataCell);
if n == 0
    return;
end

% ════════════════════════════════════════════════════════════════════════
%  Resolve colours
% ════════════════════════════════════════════════════════════════════════
if isempty(Options.Colors)
    colors = plotting.lineColors(n);
else
    if size(Options.Colors, 1) < n
        % cycle colours if too few provided
        idx    = mod((0:n-1)', size(Options.Colors,1)) + 1;
        colors = Options.Colors(idx, :);
    else
        colors = Options.Colors(1:n, :);
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Resolve category labels
% ════════════════════════════════════════════════════════════════════════
if numel(Options.Labels) >= n
    labels = Options.Labels(1:n);
else
    labels = arrayfun(@(k) sprintf('Group %d', k), 1:n, 'UniformOutput', false);
end

% ════════════════════════════════════════════════════════════════════════
%  Draw each group
% ════════════════════════════════════════════════════════════════════════
hold(ax, 'on');

style  = Options.Style;
horiz  = strcmp(Options.Orientation, "horizontal");
w      = Options.Width;

for k = 1:n
    d = dataCell{k}(:);          % ensure column
    d = d(isfinite(d));          % strip NaN/Inf
    col = colors(k,:);
    xc  = k;                     % category centre

    if isempty(d)
        continue;
    end

    switch style
        case "box"
            [h, hm, hw, ho] = drawBox(ax, d, xc, w, col, ...
                Options.ShowMean, Options.ShowOutliers, horiz);
            hGroup.boxes    = [hGroup.boxes,    h];
            hGroup.medians  = [hGroup.medians,  hm];
            hGroup.whiskers = [hGroup.whiskers, hw];
            hGroup.outliers = [hGroup.outliers, ho];
            if Options.ShowMean && ~isempty(h)
                hGroup.means = [hGroup.means, drawMean(ax, d, xc, w, col, horiz)];
            end

        case "violin"
            hv = drawViolin(ax, d, xc, w, col, horiz);
            hGroup.violins = [hGroup.violins, hv];
            if Options.ShowMean
                hGroup.means = [hGroup.means, drawMean(ax, d, xc, w, col, horiz)];
            end

        case "swarm"
            hs = drawSwarm(ax, d, xc, w, col, horiz);
            hGroup.swarm = [hGroup.swarm, hs];
            if Options.ShowMean
                hGroup.means = [hGroup.means, drawMean(ax, d, xc, w, col, horiz)];
            end

        case "box+swarm"
            [h, hm, hw, ho] = drawBox(ax, d, xc, w*0.5, col, ...
                false, Options.ShowOutliers, horiz);
            hGroup.boxes    = [hGroup.boxes,    h];
            hGroup.medians  = [hGroup.medians,  hm];
            hGroup.whiskers = [hGroup.whiskers, hw];
            hGroup.outliers = [hGroup.outliers, ho];
            hs = drawSwarm(ax, d, xc, w, col, horiz);
            hGroup.swarm = [hGroup.swarm, hs];
            if Options.ShowMean
                hGroup.means = [hGroup.means, drawMean(ax, d, xc, w*0.5, col, horiz)];
            end
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Axes decoration
% ════════════════════════════════════════════════════════════════════════
tickPos = 1:n;
tickLbls = labels;

if horiz
    ax.YTick      = tickPos;
    ax.YTickLabel = tickLbls;
    ax.YLim       = [0.5, n + 0.5];
else
    ax.XTick      = tickPos;
    ax.XTickLabel = tickLbls;
    ax.XLim       = [0.5, n + 0.5];
end

end  % boxViolinSwarm

% ════════════════════════════════════════════════════════════════════════
%  LOCAL: Draw box plot for one group
% ════════════════════════════════════════════════════════════════════════
function [hBox, hMedian, hWhiskers, hOutliers] = drawBox(ax, d, xc, w, col, showMean, showOutliers, horiz)

q1  = prctile(d, 25);
q3  = prctile(d, 75);
med = median(d);
iqrVal = q3 - q1;

wLow  = q1 - 1.5 * iqrVal;
wHigh = q3 + 1.5 * iqrVal;
wLow  = max(wLow,  min(d));
wHigh = min(wHigh, max(d));

isOut = d < (q1 - 1.5*iqrVal) | d > (q3 + 1.5*iqrVal);
outVals = d(isOut);

hw = w / 2;

if horiz
    % IQR box
    bX = [q1, q3, q3, q1, q1];
    bY = [xc-hw, xc-hw, xc+hw, xc+hw, xc-hw];
else
    bX = [xc-hw, xc+hw, xc+hw, xc-hw, xc-hw];
    bY = [q1, q1, q3, q3, q1];
end

hBox = patch(ax, bX, bY, col, ...
    'FaceAlpha', 0.35, 'EdgeColor', col, 'LineWidth', 1.2);

% Median line
if horiz
    hMedian = line(ax, [med med], [xc-hw xc+hw], ...
        'Color', col, 'LineWidth', 2.5);
else
    hMedian = line(ax, [xc-hw xc+hw], [med med], ...
        'Color', col, 'LineWidth', 2.5);
end

% Whiskers
capHw = hw * 0.4;
if horiz
    wLine1 = line(ax, [wLow  q1], [xc xc], 'Color', col, 'LineWidth', 1.2);
    wLine2 = line(ax, [q3  wHigh], [xc xc], 'Color', col, 'LineWidth', 1.2);
    wCap1  = line(ax, [wLow  wLow],  [xc-capHw xc+capHw], 'Color', col, 'LineWidth', 1.2);
    wCap2  = line(ax, [wHigh wHigh], [xc-capHw xc+capHw], 'Color', col, 'LineWidth', 1.2);
else
    wLine1 = line(ax, [xc xc], [wLow  q1], 'Color', col, 'LineWidth', 1.2);
    wLine2 = line(ax, [xc xc], [q3  wHigh], 'Color', col, 'LineWidth', 1.2);
    wCap1  = line(ax, [xc-capHw xc+capHw], [wLow  wLow],  'Color', col, 'LineWidth', 1.2);
    wCap2  = line(ax, [xc-capHw xc+capHw], [wHigh wHigh], 'Color', col, 'LineWidth', 1.2);
end
hWhiskers = [wLine1, wLine2, wCap1, wCap2];

% Outliers
if showOutliers && ~isempty(outVals)
    if horiz
        hOutliers = scatter(ax, outVals, repmat(xc, size(outVals)), ...
            24, col, 'o', 'filled', 'MarkerFaceAlpha', 0.6);
    else
        hOutliers = scatter(ax, repmat(xc, size(outVals)), outVals, ...
            24, col, 'o', 'filled', 'MarkerFaceAlpha', 0.6);
    end
else
    hOutliers = gobjects(0);
end

end

% ════════════════════════════════════════════════════════════════════════
%  LOCAL: Draw violin for one group (Gaussian KDE, Silverman bandwidth)
% ════════════════════════════════════════════════════════════════════════
function hViolin = drawViolin(ax, d, xc, w, col, horiz)

if numel(d) < 2
    % Single point — draw a thin box instead
    if horiz
        hViolin = line(ax, [d(1) d(1)], [xc-w/4 xc+w/4], ...
            'Color', col, 'LineWidth', 2);
    else
        hViolin = line(ax, [xc-w/4 xc+w/4], [d(1) d(1)], ...
            'Color', col, 'LineWidth', 2);
    end
    return;
end

% Silverman's rule-of-thumb bandwidth
n   = numel(d);
sig = std(d);
iqrBW = iqr(d) / 1.34;
if iqrBW == 0, iqrBW = sig; end
if sig == 0 && iqrBW == 0
    hViolin = gobjects(0);
    return;
end
h = 0.9 * min(sig, iqrBW) * n^(-0.2);
if h == 0, h = 1e-10; end

% Evaluation grid spanning data +/- 3*h
xMin = min(d) - 3*h;
xMax = max(d) + 3*h;
xGrid = linspace(xMin, xMax, 200)';

% KDE: sum of Gaussian kernels
density = zeros(200, 1);
for i = 1:n
    density = density + exp(-0.5 * ((xGrid - d(i)) / h).^2);
end
density = density / (n * h * sqrt(2*pi));

% Normalise to half-width w/2
maxDens = max(density);
if maxDens > 0
    halfW = (density / maxDens) * (w / 2);
else
    halfW = zeros(size(density));
end

% Build closed polygon: right side then mirrored left side
if horiz
    polyY = [xc + halfW; flipud(xc - halfW)];
    polyX = [xGrid; flipud(xGrid)];
else
    polyX = [xc + halfW; flipud(xc - halfW)];
    polyY = [xGrid; flipud(xGrid)];
end

hViolin = fill(ax, polyX, polyY, col, ...
    'FaceAlpha', 0.45, 'EdgeColor', col, 'LineWidth', 0.8);

% Median tick
med = median(d);
mHw = (interp1(xGrid, halfW, med, 'linear', 0)) * 0.9;
if horiz
    line(ax, [med med], [xc - mHw, xc + mHw], 'Color', col, 'LineWidth', 2.5);
else
    line(ax, [xc - mHw, xc + mHw], [med med], 'Color', col, 'LineWidth', 2.5);
end

end

% ════════════════════════════════════════════════════════════════════════
%  LOCAL: Draw bee-swarm for one group
% ════════════════════════════════════════════════════════════════════════
function hSwarm = drawSwarm(ax, d, xc, w, col, horiz)

if isempty(d)
    hSwarm = gobjects(0);
    return;
end

% Bin values along the value axis, assign offsets to avoid overlap
sorted = sort(d);
markerR = w * 0.06;          % radius per point in category units

xOffsets = assignSwarmOffsets(sorted, markerR, w/2);

if horiz
    hSwarm = scatter(ax, sorted, xc + xOffsets, 18, col, 'o', 'filled', ...
        'MarkerFaceAlpha', 0.7, 'MarkerEdgeColor', 'none');
else
    hSwarm = scatter(ax, xc + xOffsets, sorted, 18, col, 'o', 'filled', ...
        'MarkerFaceAlpha', 0.7, 'MarkerEdgeColor', 'none');
end

end

% ════════════════════════════════════════════════════════════════════════
%  LOCAL: Mean marker
% ════════════════════════════════════════════════════════════════════════
function hMean = drawMean(ax, d, xc, ~, col, horiz)
mu = mean(d);
if horiz
    hMean = scatter(ax, mu, xc, 50, 'w', 'd', 'filled', ...
        'MarkerEdgeColor', col, 'LineWidth', 1.5);
else
    hMean = scatter(ax, xc, mu, 50, 'w', 'd', 'filled', ...
        'MarkerEdgeColor', col, 'LineWidth', 1.5);
end
end

% ════════════════════════════════════════════════════════════════════════
%  LOCAL: Assign x-offsets for swarm plot (beeswarm algorithm)
% ════════════════════════════════════════════════════════════════════════
function offsets = assignSwarmOffsets(sortedVals, markerR, maxHw)
%ASSIGNSWARMOFFSETS  Compute lateral offsets so points in same bin do not overlap.
%   sortedVals - sorted numeric column vector
%   markerR    - half-width reserved per point (in category axis units)
%   maxHw      - maximum allowed half-width from centre

n = numel(sortedVals);
offsets = zeros(n, 1);

if n == 0, return; end

% Use markerR as the bin height in value space
binH = max(sortedVals) - min(sortedVals);
if binH == 0 || n == 1
    % All same value — spread evenly
    spread = min(maxHw, markerR * (n-1));
    offsets = linspace(-spread/2, spread/2, n)';
    return;
end

% Adaptive bin height: aim for ~sqrt(n) points per bin
nBins  = max(1, round(sqrt(n)));
binH   = binH / nBins;
if binH == 0, binH = 1e-10; end

% Walk through sorted values and group into bins
i = 1;
while i <= n
    % Find all points within this bin
    binStart = sortedVals(i);
    j = i;
    while j <= n && sortedVals(j) <= binStart + binH
        j = j + 1;
    end
    binIdx = i:j-1;
    k = numel(binIdx);

    if k == 1
        offsets(binIdx) = 0;
    else
        step = min(2*markerR, 2*maxHw/(k-1));
        xOff = (-(k-1)/2 : 1 : (k-1)/2) * step;
        % Clamp to maxHw
        xOff = max(-maxHw, min(maxHw, xOff));
        offsets(binIdx) = xOff(:);
    end

    i = j;
end

end
