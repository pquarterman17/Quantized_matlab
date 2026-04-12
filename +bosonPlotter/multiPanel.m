function result = multiPanel(datasets, options)
%MULTIPANEL  Create a multi-panel figure with linked axes.
%
%   result = bosonPlotter.multiPanel(datasets)
%   result = bosonPlotter.multiPanel(datasets, Layout='2x1')
%   result = bosonPlotter.multiPanel(datasets, Layout='2x2', Template='aps')
%
%   Creates a publication-ready multi-panel figure.  Each panel gets its
%   own axes; adjacent panels can share X or Y axes for aligned comparison.
%   Supports panel labels (a, b, c, d) and publication templates.
%
%   Inputs:
%       datasets — cell array of data structs (each with .time, .values)
%                  OR cell array of {x, y} pairs
%                  Datasets are assigned to panels in order.  If fewer
%                  datasets than panels, extra panels remain empty.
%
%   Options:
%       Layout      — '1x1' | '2x1' | '1x2' | '2x2' | '3x1' | '1x3' | '2x1r'
%                     (default: auto-select based on dataset count)
%                     '2x1r' = 2x1 with bottom panel for residuals
%       Channel     — column index in .values for each dataset (default: 1)
%                     Scalar (same for all) or vector (one per dataset)
%       ShareX      — link X axes across rows (default: true for Nx1 layouts)
%       ShareY      — link Y axes across columns (default: true for 1xN layouts)
%       Labels      — panel labels: 'abc' | 'ABC' | '123' | 'none' (default: 'abc')
%       Template    — publication template name (default: '' = screen style)
%       Title       — figure title string (default: '')
%       PlotStyle   — 'line' | 'scatter' | 'both' (default: 'line')
%       XLabel      — X-axis label (applied to bottom row, default: '')
%       YLabels     — cell array of Y-axis labels (one per panel, default: from data)
%       FigureSize  — [width height] in cm (default: from template or auto)
%       Residuals   — struct with .yFit for the first dataset (used in '2x1r' mode)
%       Appearance  — pre-resolved style struct from bosonPlotter.resolveStyle
%                     (default: empty struct → resolved from Template or screen default).
%                     When non-empty, Template is ignored and this struct is used
%                     directly. Back-fills figWidth_cm / figHeight_cm if absent.
%
%   Output (struct):
%       .fig     — figure handle
%       .axes    — array of axes handles (one per panel)
%       .layout  — layout string used
%       .nPanels — number of panels
%
%   Examples:
%       % Two datasets stacked vertically with shared X
%       r = bosonPlotter.multiPanel({data1, data2}, Layout='2x1');
%
%       % 2x2 grid for APS journal
%       r = bosonPlotter.multiPanel({d1,d2,d3,d4}, Layout='2x2', Template='aps');
%
%       % Data + residuals below
%       r = bosonPlotter.multiPanel({data}, Layout='2x1r', ...
%           Residuals=struct('yFit', yFitVec));

arguments
    datasets   cell
    options.Layout    (1,1) string = ""
    options.Channel          = 1
    options.ShareX    (1,1) logical = true
    options.ShareY    (1,1) logical = false
    options.Labels    (1,1) string {mustBeMember(options.Labels, ...
        ["abc","ABC","123","none"])} = "abc"
    options.Template  (1,1) string = ""
    options.Title     (1,1) string = ""
    options.PlotStyle (1,1) string {mustBeMember(options.PlotStyle, ...
        ["line","scatter","both"])} = "line"
    options.XLabel    (1,1) string = ""
    options.YLabels   cell = {}
    options.FigureSize (1,:) double = []
    options.Residuals        = []
    options.Appearance struct = struct()   % pre-resolved style from bosonPlotter.resolveStyle
end

nDS = numel(datasets);

% ════════════════════════════════════════════════════════════════════════
% Determine layout
% ════════════════════════════════════════════════════════════════════════

if options.Layout == ""
    % Auto-select
    switch nDS
        case 1,    layoutStr = '1x1';
        case 2,    layoutStr = '2x1';
        case 3,    layoutStr = '3x1';
        otherwise, layoutStr = '2x2';
    end
else
    layoutStr = char(options.Layout);
end

switch layoutStr
    case '1x1',  nRows = 1; nCols = 1; rowHeights = {'1x'};
    case '2x1',  nRows = 2; nCols = 1; rowHeights = {'1x','1x'};
    case '2x1r', nRows = 2; nCols = 1; rowHeights = {'3x','1x'};
    case '3x1',  nRows = 3; nCols = 1; rowHeights = {'1x','1x','1x'};
    case '1x2',  nRows = 1; nCols = 2; rowHeights = {'1x'};
    case '1x3',  nRows = 1; nCols = 3; rowHeights = {'1x'};
    case '2x2',  nRows = 2; nCols = 2; rowHeights = {'1x','1x'};
    otherwise
        error('bosonPlotter:multiPanel:badLayout', ...
            'Unknown layout "%s".', layoutStr);
end

nPanels = nRows * nCols;
colWidths = repmat({'1x'}, 1, nCols);

% ════════════════════════════════════════════════════════════════════════
% Create figure
% ════════════════════════════════════════════════════════════════════════

% Apply template in precedence order:
%   1. Appearance struct (full pre-resolved from bosonPlotter.resolveStyle)
%   2. Template string name  (legacy path)
%   3. styles.default() with a few Helvetica-screen overrides
if ~isempty(fieldnames(options.Appearance))
    tmpl = options.Appearance;
    % Back-fill any legacy fields multiPanel expects but resolveStyle
    % may not have populated (figWidth_cm / figHeight_cm).
    if ~isfield(tmpl,'figWidth_cm')  || isempty(tmpl.figWidth_cm),  tmpl.figWidth_cm  = 14; end
    if ~isfield(tmpl,'figHeight_cm') || isempty(tmpl.figHeight_cm), tmpl.figHeight_cm = 10; end
elseif options.Template ~= ""
    tmpl = styles.template(options.Template);
else
    tmpl = styles.default();
    tmpl.fontName = 'Helvetica';
    tmpl.tickDir = 'in';
    tmpl.figWidth_cm = 14;
    tmpl.figHeight_cm = 10;
end

% Figure size
if ~isempty(options.FigureSize) && numel(options.FigureSize) == 2
    figW_cm = options.FigureSize(1);
    figH_cm = options.FigureSize(2);
elseif isfield(tmpl, 'figWidth_cm')
    figW_cm = tmpl.figWidth_cm;
    figH_cm = tmpl.figHeight_cm;
else
    figW_cm = 14;
    figH_cm = 10;
end

pxPerCm = 96 / 2.54;
figW = figW_cm * pxPerCm;
figH = figH_cm * pxPerCm;

mpFig = figure('Name', 'Multi-Panel Figure', 'NumberTitle', 'off', ...
    'Units', 'pixels', 'Position', [150 100 figW figH], ...
    'PaperUnits', 'centimeters', ...
    'PaperSize', [figW_cm figH_cm], ...
    'PaperPosition', [0 0 figW_cm figH_cm], ...
    'Renderer', 'painters', 'Color', 'w');

if options.Title ~= ""
    sgtitle(mpFig, char(options.Title), 'FontSize', tmpl.titleFontSize, ...
        'FontName', tmpl.fontName);
end

% ════════════════════════════════════════════════════════════════════════
% Create axes grid
% ════════════════════════════════════════════════════════════════════════

axHandles = gobjects(nPanels, 1);
colors = tmpl.colors;
nColors = size(colors, 1);

% Panel labels
switch char(options.Labels)
    case 'abc',  labelSet = char('a' + (0:25));
    case 'ABC',  labelSet = char('A' + (0:25));
    case '123',  labelSet = arrayfun(@num2str, 1:26, 'UniformOutput', false);
    case 'none', labelSet = {};
end

for pi = 1:nPanels
    [row, col] = ind2sub([nRows, nCols], pi);

    % Subplot position
    axHandles(pi) = subplot(nRows, nCols, pi, 'Parent', mpFig);
    ax = axHandles(pi);

    % Style
    ax.FontName = tmpl.fontName;
    ax.FontSize = tmpl.fontSize;
    ax.TickDir  = tmpl.tickDir;
    ax.Box      = 'on';

    if isfield(tmpl, 'tickLength')
        ax.TickLength = tmpl.tickLength;
    end

    hold(ax, 'on');
    grid(ax, 'on');

    % Plot dataset if available
    if pi <= nDS
        [xData, yData, dsLabels] = extractDS(datasets{pi}, options.Channel, pi);

        if ~isempty(xData) && ~isempty(yData)
            ci = mod(pi - 1, nColors) + 1;
            plotData(ax, xData, yData, colors(ci, :), tmpl, options.PlotStyle);

            % Y-axis label
            if pi <= numel(options.YLabels) && ~isempty(options.YLabels{pi})
                ylabel(ax, char(options.YLabels{pi}), 'FontSize', tmpl.fontSize);
            elseif ~isempty(dsLabels)
                ylabel(ax, dsLabels{1}, 'FontSize', tmpl.fontSize);
            end
        end

        % Residuals mode: bottom panel shows residuals
        if strcmp(layoutStr, '2x1r') && pi == 1 && ~isempty(options.Residuals) && ...
                isfield(options.Residuals, 'yFit')
            % Plot fit overlay on panel 1
            yFit = options.Residuals.yFit;
            plot(ax, xData, yFit, 'r-', 'LineWidth', tmpl.lineWidth);

            % Create residuals in panel 2 (next iteration)
            if nDS < 2
                residVec = yData - yFit(:);
                datasets{2} = {xData, residVec}; %#ok<AGROW>
                nDS = 2;
                if 2 <= numel(options.YLabels) && ~isempty(options.YLabels{2})
                    % keep user label
                else
                    options.YLabels{2} = 'Residual';
                end
            end
        end
    end

    hold(ax, 'off');

    % Panel label
    if ~isempty(labelSet) && pi <= numel(labelSet)
        if iscell(labelSet)
            lbl = labelSet{pi};
        else
            lbl = ['(' labelSet(pi) ')'];
        end
        text(ax, 0.02, 0.96, lbl, 'Units', 'normalized', ...
            'FontSize', tmpl.fontSize + 1, 'FontWeight', 'bold', ...
            'FontName', tmpl.fontName, 'VerticalAlignment', 'top');
    end

    % X-axis label only on bottom row
    if row == nRows && options.XLabel ~= ""
        xlabel(ax, char(options.XLabel), 'FontSize', tmpl.fontSize);
    end

    % Hide X tick labels on non-bottom rows if sharing X
    if options.ShareX && row < nRows && nCols == 1
        ax.XTickLabel = {};
    end

    % Hide Y tick labels on non-left columns if sharing Y
    if options.ShareY && col > 1 && nRows == 1
        ax.YTickLabel = {};
    end
end

% ════════════════════════════════════════════════════════════════════════
% Link axes
% ════════════════════════════════════════════════════════════════════════

if nPanels > 1
    if options.ShareX && nCols == 1
        linkaxes(axHandles, 'x');
    elseif options.ShareY && nRows == 1
        linkaxes(axHandles, 'y');
    end
end

% Tight layout
if exist('exportgraphics', 'file')
    % Available in R2020a+; just tighten spacing
    try
        for pi = 1:nPanels
            axHandles(pi).LooseInset = max(axHandles(pi).TightInset, 0.02);
        end
    catch
    end
end

% ════════════════════════════════════════════════════════════════════════
% Output
% ════════════════════════════════════════════════════════════════════════

result.fig     = mpFig;
result.axes    = axHandles;
result.layout  = layoutStr;
result.nPanels = nPanels;

end

% ════════════════════════════════════════════════════════════════════════
% Local helpers
% ════════════════════════════════════════════════════════════════════════

function [x, y, labels] = extractDS(ds, channelSpec, idx)
%EXTRACTDS  Get x, y from a dataset struct or {x,y} pair.
    labels = {};
    if isscalar(channelSpec)
        ch = channelSpec;
    else
        ch = channelSpec(min(idx, numel(channelSpec)));
    end

    if isstruct(ds)
        if isfield(ds, 'corrData') && ~isempty(ds.corrData) && ...
                isfield(ds.corrData, 'time') && ~isempty(ds.corrData.time)
            plotD = ds.corrData;
        elseif isfield(ds, 'data')
            plotD = ds.data;
        elseif isfield(ds, 'time')
            plotD = ds;
        else
            x = []; y = []; return;
        end
        x = plotD.time(:);
        ch = min(ch, size(plotD.values, 2));
        y = plotD.values(:, ch);
        if isfield(plotD, 'labels')
            labels = plotD.labels;
        end
    elseif iscell(ds) && numel(ds) >= 2
        x = ds{1}(:);
        y = ds{2}(:);
    else
        x = []; y = [];
    end
end

function plotData(ax, x, y, color, tmpl, style)
%PLOTDATA  Plot data on axes with specified style.
    switch char(style)
        case 'line'
            plot(ax, x, y, '-', 'Color', color, 'LineWidth', tmpl.lineWidth);
        case 'scatter'
            plot(ax, x, y, '.', 'Color', color, 'MarkerSize', tmpl.markerSize);
        case 'both'
            plot(ax, x, y, '-o', 'Color', color, ...
                'LineWidth', tmpl.lineWidth, 'MarkerSize', tmpl.markerSize * 0.6);
    end
end
