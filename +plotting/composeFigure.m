function result = composeFigure(sources, options)
%COMPOSEFIGURE  Arrange multiple plots into a composite publication figure.
%
%   result = plotting.composeFigure(sources)
%   result = plotting.composeFigure(sources, Layout=[2 2], Template='aps')
%
%   Takes existing axes handles, figure handles, or {x,y} data and
%   arranges them into a single composite figure with panel labels,
%   annotations, and publication-ready formatting.
%
%   Inputs:
%       sources — cell array of any mix of:
%                 - axes handles (content is copied)
%                 - figure handles (first axes is copied)
%                 - data structs (plotted fresh)
%                 - {x, y} cell pairs (plotted fresh)
%
%   Options:
%       Layout      — [nRows nCols] (default: auto)
%       Template    — publication template name (default: 'screen')
%       Labels      — 'abc' | 'ABC' | '123' | 'none' (default: 'abc')
%       Title       — shared super-title string (default: '')
%       Annotations — cell array of annotation structs, each with:
%                     .panel (index), .text (string), .position ([x y] normalised),
%                     optional .arrow ([x1 y1 x2 y2] normalised)
%       PanelTitles — cell array of title strings per panel
%       FigureSize  — [width height] in cm
%       Spacing     — gap between panels in normalised units (default: 0.08)
%
%   Output (struct):
%       .fig     — composite figure handle
%       .axes    — array of axes handles in the composite
%       .nPanels — number of panels
%
%   Examples:
%       % Compose from 4 existing axes
%       r = plotting.composeFigure({ax1, ax2, ax3, ax4}, ...
%           Layout=[2 2], Template='aps');
%
%       % Compose from data with annotations
%       r = plotting.composeFigure({data1, data2}, ...
%           Layout=[1 2], Labels='abc', ...
%           Annotations={struct('panel',1,'text','T_C','position',[0.5 0.8])});
%
%       % Export
%       exportgraphics(r.fig, 'composite.pdf', 'Resolution', 600);

arguments
    sources    cell
    options.Layout     (1,:) double = []
    options.Template   (1,1) string = "screen"
    options.Labels     (1,1) string {mustBeMember(options.Labels, ...
        ["abc","ABC","123","none"])} = "abc"
    options.Title      (1,1) string = ""
    options.Annotations cell = {}
    options.PanelTitles cell = {}
    options.FigureSize (1,:) double = []
    options.Spacing    (1,1) double = 0.08
end

nSrc = numel(sources);

% Layout
if isempty(options.Layout)
    switch nSrc
        case 1, nR = 1; nC = 1;
        case 2, nR = 1; nC = 2;
        case 3, nR = 1; nC = 3;
        case 4, nR = 2; nC = 2;
        case 6, nR = 2; nC = 3;
        otherwise, nC = ceil(sqrt(nSrc)); nR = ceil(nSrc / nC);
    end
else
    nR = options.Layout(1);
    nC = options.Layout(2);
end
nPanels = nR * nC;

% Template
tmpl = styles.template(options.Template);

% Figure size
if ~isempty(options.FigureSize) && numel(options.FigureSize) == 2
    wCm = options.FigureSize(1);
    hCm = options.FigureSize(2);
else
    wCm = tmpl.figWidth_cm;
    hCm = tmpl.figHeight_cm;
end

pxPerCm = 96 / 2.54;
compFig = figure('Name', 'Composite Figure', 'NumberTitle', 'off', ...
    'Color', 'w', 'Units', 'pixels', ...
    'Position', [100 80 wCm*pxPerCm hCm*pxPerCm], ...
    'PaperUnits', 'centimeters', ...
    'PaperSize', [wCm hCm], ...
    'PaperPosition', [0 0 wCm hCm]);

if options.Title ~= ""
    sgtitle(compFig, char(options.Title), ...
        'FontSize', tmpl.titleFontSize, 'FontName', tmpl.fontName);
end

% Label set
switch char(options.Labels)
    case 'abc',  lbls = arrayfun(@(c) ['(' c ')'], 'a':'z', 'UniformOutput', false);
    case 'ABC',  lbls = arrayfun(@(c) ['(' c ')'], 'A':'Z', 'UniformOutput', false);
    case '123',  lbls = arrayfun(@(n) ['(' num2str(n) ')'], 1:26, 'UniformOutput', false);
    case 'none', lbls = {};
end

% Create panels
sp = options.Spacing;
axHandles = gobjects(nPanels, 1);

for pi = 1:nPanels
    [row, col] = ind2sub([nR, nC], pi);

    % Compute position [left bottom width height] with spacing
    pw = (1 - (nC+1)*sp) / nC;
    ph = (1 - (nR+1)*sp) / nR;
    left   = sp + (col-1)*(pw + sp);
    bottom = 1 - row*(ph + sp);

    axNew = axes(compFig, 'Position', [left bottom pw ph]); %#ok<LAXES>
    axNew.FontName = tmpl.fontName;
    axNew.FontSize = tmpl.fontSize;
    axNew.TickDir  = tmpl.tickDir;
    axNew.Box      = 'on';
    if isfield(tmpl, 'tickLength')
        axNew.TickLength = tmpl.tickLength;
    end

    % Populate panel
    if pi <= nSrc
        src = sources{pi};
        populatePanel(axNew, src, tmpl);
    end

    % Panel title
    if pi <= numel(options.PanelTitles) && ~isempty(options.PanelTitles{pi})
        title(axNew, char(options.PanelTitles{pi}), ...
            'FontSize', tmpl.titleFontSize, 'FontName', tmpl.fontName);
    end

    % Panel label
    if ~isempty(lbls) && pi <= numel(lbls)
        text(axNew, 0.02, 0.96, lbls{pi}, 'Units', 'normalized', ...
            'FontSize', tmpl.fontSize + 1, 'FontWeight', 'bold', ...
            'FontName', tmpl.fontName, 'VerticalAlignment', 'top');
    end

    axHandles(pi) = axNew;
end

% Annotations
for ai = 1:numel(options.Annotations)
    ann = options.Annotations{ai};
    if ~isfield(ann, 'panel') || ~isfield(ann, 'text'), continue; end
    pIdx = ann.panel;
    if pIdx < 1 || pIdx > nPanels, continue; end
    ax = axHandles(pIdx);

    pos = [0.5 0.5];
    if isfield(ann, 'position'), pos = ann.position; end

    text(ax, pos(1), pos(2), ann.text, 'Units', 'normalized', ...
        'FontSize', tmpl.fontSize, 'FontName', tmpl.fontName, ...
        'Color', [0.1 0.1 0.1], 'BackgroundColor', [1 1 1 0.7]);

    if isfield(ann, 'arrow') && numel(ann.arrow) == 4
        a = ann.arrow;
        annotation(compFig, 'arrow', [a(1) a(3)], [a(2) a(4)], ...
            'Color', [0.2 0.2 0.2]);
    end
end

result.fig     = compFig;
result.axes    = axHandles;
result.nPanels = nPanels;

end

% ════════════════════════════════════════════════════════════════════════

function populatePanel(axNew, src, tmpl)
%POPULATEPANEL  Fill an axes from a source (axes handle, figure, data, {x,y}).
    colors = tmpl.colors;

    if isa(src, 'matlab.graphics.axis.Axes') && isvalid(src)
        % Copy children from existing axes
        copyobj(src.Children, axNew);
        axNew.XLim = src.XLim;
        axNew.YLim = src.YLim;
        axNew.XLabel.String = src.XLabel.String;
        axNew.YLabel.String = src.YLabel.String;

    elseif isa(src, 'matlab.ui.Figure') && isvalid(src)
        % Copy from first axes of figure
        srcAx = findobj(src, 'Type', 'axes', '-depth', 1);
        if ~isempty(srcAx)
            populatePanel(axNew, srcAx(1), tmpl);
        end

    elseif isstruct(src) && isfield(src, 'time')
        % Data struct
        hold(axNew, 'on');
        for ci = 1:size(src.values, 2)
            cIdx = mod(ci-1, size(colors,1)) + 1;
            plot(axNew, src.time, src.values(:,ci), '-', ...
                'Color', colors(cIdx,:), 'LineWidth', tmpl.lineWidth);
        end
        hold(axNew, 'off');
        if isfield(src, 'labels') && ~isempty(src.labels)
            ylabel(axNew, src.labels{1});
        end

    elseif iscell(src) && numel(src) >= 2
        % {x, y} pair
        plot(axNew, src{1}, src{2}, '-', 'Color', colors(1,:), ...
            'LineWidth', tmpl.lineWidth);
    end
end
