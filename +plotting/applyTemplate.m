function applyTemplate(fig, ax, tmpl)
%APPLYTEMPLATE  Apply a publication template to a figure and its axes.
%
%   plotting.applyTemplate(fig, ax, tmpl)
%
%   Sets figure size, paper position, font family, font sizes, tick
%   direction, line widths, colours, and other cosmetic properties
%   defined in a template struct (from styles.template).
%
%   Inputs:
%       fig  — figure handle
%       ax   — axes handle (or array of axes handles for multi-panel)
%       tmpl — template struct from styles.template('aps') etc.
%
%   What it sets:
%     Figure level:
%       - Size in centimetres (Position, PaperUnits, PaperPosition, PaperSize)
%       - Renderer set to 'painters' for vector export
%     Axes level (each ax):
%       - FontName, FontSize, TitleFontSizeMultiplier
%       - TickDir, TickLength, Box
%       - GridAlpha, GridColor
%       - Line widths on existing line children
%       - Legend: FontSize, Box, Location
%     Lines:
%       - Recolours existing lines using the template colour cycle
%       - Sets LineWidth to template value
%
%   Example:
%       t = styles.template('aps');
%       fig = figure; ax = axes(fig);
%       plot(ax, x, y1, x, y2);
%       plotting.applyTemplate(fig, ax, t);
%       exportgraphics(fig, 'figure1.pdf', 'Resolution', t.dpi);
%
%   See also styles.template, plotting.formatAxes, plotting.saveFigure

arguments
    fig
    ax
    tmpl struct
end

% ════════════════════════════════════════════════════════════════════════
% Figure-level properties
% ════════════════════════════════════════════════════════════════════════

% Convert cm to pixels (at 96 dpi screen resolution)
pxPerCm = 96 / 2.54;
widthPx  = tmpl.figWidth_cm * pxPerCm;
heightPx = tmpl.figHeight_cm * pxPerCm;

% Preserve position (top-left corner) while resizing
pos = fig.Position;
fig.Position = [pos(1), pos(2), widthPx, heightPx];

% Paper settings for print/export
fig.PaperUnits = 'centimeters';
fig.PaperSize = [tmpl.figWidth_cm, tmpl.figHeight_cm];
fig.PaperPosition = [0 0 tmpl.figWidth_cm tmpl.figHeight_cm];
fig.Renderer = 'painters';

% ════════════════════════════════════════════════════════════════════════
% Axes-level properties (loop for multi-panel support)
% ════════════════════════════════════════════════════════════════════════

for i = 1:numel(ax)
    a = ax(i);

    % Typography
    a.FontName = tmpl.fontName;
    a.FontSize = tmpl.fontSize;
    a.TitleFontSizeMultiplier = tmpl.titleFontSize / max(tmpl.fontSize, 1);
    a.LabelFontSizeMultiplier = 1.0;

    % Tick appearance
    a.TickDir    = tmpl.tickDir;
    a.TickLength = tmpl.tickLength;
    if tmpl.boxOn
        a.Box = 'on';
    else
        a.Box = 'off';
    end

    % Grid
    a.GridAlpha = tmpl.gridAlpha;
    if tmpl.gridAlpha > 0
        grid(a, 'on');
    else
        grid(a, 'off');
    end

    % Axis labels — update font
    a.XLabel.FontSize = tmpl.fontSize;
    a.YLabel.FontSize = tmpl.fontSize;
    a.Title.FontSize  = tmpl.titleFontSize;
    a.XLabel.FontName = tmpl.fontName;
    a.YLabel.FontName = tmpl.fontName;
    a.Title.FontName  = tmpl.fontName;

    % Legend
    if ~isempty(a.Legend)
        a.Legend.FontSize = tmpl.legendFontSize;
        a.Legend.FontName = tmpl.fontName;
        a.Legend.Location = tmpl.legendLocation;
        if tmpl.legendBox
            a.Legend.Box = 'on';
        else
            a.Legend.Box = 'off';
        end
    end

    % Recolour and resize existing lines
    lines = findobj(a.Children, 'Type', 'Line');
    nColors = size(tmpl.colors, 1);
    for li = 1:numel(lines)
        ci = mod(li - 1, nColors) + 1;
        lines(li).Color     = tmpl.colors(ci, :);
        lines(li).LineWidth = tmpl.lineWidth;
        if lines(li).MarkerSize ~= 6  % only change if not default
            lines(li).MarkerSize = tmpl.markerSize;
        end
    end

    % Resize markers
    markers = findobj(a.Children, '-property', 'MarkerSize');
    for mi = 1:numel(markers)
        markers(mi).MarkerSize = tmpl.markerSize;
    end
end

end
