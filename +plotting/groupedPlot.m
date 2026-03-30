function handles = groupedPlot(ax, x, y, groups, Options)
%GROUPEDPLOT  Plot data automatically grouped by a categorical variable.
%
%   Syntax:
%       handles = plotting.groupedPlot(ax, x, y, groups)
%       handles = plotting.groupedPlot(ax, x, y, groups, PlotType="scatter")
%
%   Inputs:
%       ax     — target axes handle
%       x      — [N×1] x-data (numeric, or ignored for "bar"/"box")
%       y      — [N×1] y-data
%       groups — [N×1] grouping variable (categorical, string, char, or numeric)
%
%   Options (name-value):
%       PlotType   — "line" | "scatter" | "bar" | "box"  (default "line")
%       Colors     — [G×3] RGB per group (default: auto from Colormap)
%       Legend     — logical, show legend                 (default true)
%       LegendLoc  — legend location string               (default "best")
%       SortGroups — logical, sort group labels           (default true)
%       ErrorBars  — [N×1] ±error values for line/scatter (default [])
%       Colormap   — colormap name for auto-colors        (default "lines")
%
%   Output:
%       handles — struct with fields:
%           .lines   — cell array {G×1} of plot/scatter/bar handles per group
%           .errBars — cell array {G×1} of errorbar handles (or empty)
%           .legend  — legend handle (or empty)
%
%   Notes:
%       - For "bar": x is treated as a numeric category label per group and
%         a grouped bar chart is produced via side-by-side bars.
%       - For "box": calls plotting.boxViolinSwarm with Style="box".
%       - Empty groups are silently skipped (no crash).
%       - Numeric groups are converted to strings for legend labels.
%
%   Examples:
%       fig = figure; ax = axes(fig);
%       x = (1:30)'; y = randn(30,1);
%       g = repmat(["A","B","C"], 1, 10)';
%       plotting.groupedPlot(ax, x, y, g, PlotType="scatter");
%
%       % Bar chart grouped by category
%       plotting.groupedPlot(ax, [1 2 3]', [4 6 3 5 7 4 3 8 5]', ...
%           repmat(["X","Y","Z"],1,3)', PlotType="bar");
%
%   See also plotting.boxViolinSwarm, plotting.lineColors

arguments
    ax     (1,1) matlab.graphics.axis.Axes
    x      (:,1) double
    y      (:,1) double
    groups (:,1)
    Options.PlotType   (1,1) string ...
        {mustBeMember(Options.PlotType, ["line","scatter","bar","box"])} = "line"
    Options.Colors     (:,3) double = []
    Options.Legend     (1,1) logical = true
    Options.LegendLoc  (1,1) string  = "best"
    Options.SortGroups (1,1) logical = true
    Options.ErrorBars  (:,1) double  = []
    Options.Colormap   (1,1) string  = "lines"
end

% ════════════════════════════════════════════════════════════════════════
%  Resolve unique groups
% ════════════════════════════════════════════════════════════════════════
groupLabels = coerceToStringCol(groups);
if Options.SortGroups
    uniqueLabels = unique(groupLabels);
else
    % preserve first-occurrence order
    [~, ia]      = unique(groupLabels, 'stable');
    uniqueLabels = groupLabels(sort(ia));
end
nGroups = numel(uniqueLabels);

% ════════════════════════════════════════════════════════════════════════
%  Resolve group colors
% ════════════════════════════════════════════════════════════════════════
if isempty(Options.Colors)
    colors = autoColors(nGroups, Options.Colormap);
else
    if size(Options.Colors, 1) < nGroups
        idx    = mod((0:nGroups-1)', size(Options.Colors,1)) + 1;
        colors = Options.Colors(idx, :);
    else
        colors = Options.Colors(1:nGroups, :);
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Initialise output
% ════════════════════════════════════════════════════════════════════════
handles = struct( ...
    'lines',   {cell(nGroups, 1)}, ...
    'errBars', {cell(nGroups, 1)}, ...
    'legend',  []);

hold(ax, 'on');

% ════════════════════════════════════════════════════════════════════════
%  Dispatch to plot type
% ════════════════════════════════════════════════════════════════════════
switch Options.PlotType

    % ── Line ─────────────────────────────────────────────────────────
    case "line"
        for g = 1:nGroups
            mask = strcmp(groupLabels, uniqueLabels(g));
            xg   = x(mask);
            yg   = y(mask);
            if isempty(xg), continue; end
            [xg, si] = sort(xg);
            yg = yg(si);
            col = colors(g, :);
            handles.lines{g} = plot(ax, xg, yg, '-o', ...
                'Color', col, ...
                'MarkerFaceColor', col, ...
                'MarkerEdgeColor', 'none', ...
                'MarkerSize', 5, ...
                'DisplayName', uniqueLabels(g));
            if ~isempty(Options.ErrorBars)
                eg = Options.ErrorBars(mask);
                eg = eg(si);
                handles.errBars{g} = errorbar(ax, xg, yg, eg, ...
                    'Color', col, 'LineStyle', 'none', ...
                    'HandleVisibility', 'off');
            end
        end

    % ── Scatter ───────────────────────────────────────────────────────
    case "scatter"
        for g = 1:nGroups
            mask = strcmp(groupLabels, uniqueLabels(g));
            xg   = x(mask);
            yg   = y(mask);
            if isempty(xg), continue; end
            col = colors(g, :);
            handles.lines{g} = scatter(ax, xg, yg, 25, col, 'filled', ...
                'MarkerFaceAlpha', 0.7, ...
                'MarkerEdgeColor', 'none', ...
                'DisplayName', uniqueLabels(g));
            if ~isempty(Options.ErrorBars)
                eg = Options.ErrorBars(mask);
                handles.errBars{g} = errorbar(ax, xg, yg, eg, ...
                    'Color', col, 'LineStyle', 'none', ...
                    'HandleVisibility', 'off');
            end
        end

    % ── Bar ───────────────────────────────────────────────────────────
    case "bar"
        % Build a matrix: rows = x positions (unique), cols = groups
        xUniq = unique(x);
        nX    = numel(xUniq);
        yMat  = NaN(nX, nGroups);
        for g = 1:nGroups
            mask = strcmp(groupLabels, uniqueLabels(g));
            xg   = x(mask);
            yg   = y(mask);
            for xi = 1:nX
                pos = xg == xUniq(xi);
                if any(pos)
                    yMat(xi, g) = mean(yg(pos));
                end
            end
        end
        bh = bar(ax, xUniq, yMat, 'grouped');
        for g = 1:nGroups
            bh(g).FaceColor  = colors(g, :);
            bh(g).DisplayName = uniqueLabels(g);
        end
        handles.lines = num2cell(bh(:));

    % ── Box ───────────────────────────────────────────────────────────
    case "box"
        dataCell = cell(1, nGroups);
        for g = 1:nGroups
            mask        = strcmp(groupLabels, uniqueLabels(g));
            dataCell{g} = y(mask);
        end
        labelCell = cellstr(uniqueLabels);
        hBox = plotting.boxViolinSwarm(ax, dataCell, ...
            'Style',  'box', ...
            'Labels', labelCell, ...
            'Colors', colors);
        handles.lines{1} = hBox;
        % For box mode return early — legend handled by tick labels
        handles.legend = [];
        return;
end

% ════════════════════════════════════════════════════════════════════════
%  Legend
% ════════════════════════════════════════════════════════════════════════
if Options.Legend
    % Only include line handles that are non-empty
    validLines = handles.lines(~cellfun(@isempty, handles.lines));
    if ~isempty(validLines)
        lgd = legend([validLines{:}], ...
            'Location', Options.LegendLoc);
        handles.legend = lgd;
    end
end

end  % groupedPlot

% ════════════════════════════════════════════════════════════════════════
%  LOCAL: Coerce groups to string column vector
% ════════════════════════════════════════════════════════════════════════
function s = coerceToStringCol(g)
if iscategorical(g)
    s = string(g(:));
elseif isnumeric(g)
    s = arrayfun(@(v) sprintf('%.6g', v), g(:), 'UniformOutput', false);
    s = string(s);
elseif ischar(g)
    % char matrix — each row is a group label
    s = string(cellstr(g));
    s = s(:);
elseif iscell(g)
    s = string(g(:));
elseif isstring(g)
    s = g(:);
else
    error('groupedPlot:unsupportedGroupType', ...
        'groups must be numeric, string, char, cell, or categorical.');
end
end

% ════════════════════════════════════════════════════════════════════════
%  LOCAL: Auto-generate N colours from a named colormap
% ════════════════════════════════════════════════════════════════════════
function colors = autoColors(n, cmapName)
% Try the named colormap first; fall back to plotting.lineColors
try
    if strcmpi(cmapName, 'lines')
        % MATLAB built-in lines(n) gives good distinguishable colors
        colors = lines(n);
    else
        fullMap = feval(char(cmapName), 256);
        if n == 1
            idx = 128;
        else
            idx = round(linspace(1, 256, n));
        end
        colors = fullMap(idx, :);
    end
catch
    colors = plotting.lineColors(n);
end
end
