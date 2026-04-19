function styleAxesForExport(expAx)
%STYLEAXESFOREXPORT  Re-style axes for readability on white backgrounds.
%
% Syntax
%   bosonPlotter.styleAxesForExport(expAx)
%
% Behaviour
%   Darkens axis lines, ticks, and labels; thickens the bounding box;
%   strips any inherited dark-mode background from the legend so the
%   exported image is fully transparent aside from the plot content.
%   Applied only to temporary export axes (clipboard / save).
%
% Input
%   expAx - Export axes handle (Axes object)

    darkColor = [0.15 0.15 0.15];
    expAx.XColor    = darkColor;
    expAx.YColor    = darkColor;
    expAx.LineWidth = 1.2;
    expAx.FontSize  = 13;
    % Darken axis labels
    if ~isempty(expAx.XLabel.String)
        expAx.XLabel.Color = darkColor;
    end
    if ~isempty(expAx.YLabel.String)
        expAx.YLabel.Color = darkColor;
    end
    if ~isempty(expAx.Title.String)
        expAx.Title.Color = darkColor;
    end
    % Style right Y-axis if it exists
    if isprop(expAx, 'YAxis') && numel(expAx.YAxis) > 1
        expAx.YAxis(2).Color = darkColor;
    end
    % Legend fill + text — the GUI's dark theme bakes a dark
    % background and white text into the legend handle; override
    % so the pasted image has a transparent legend with dark text.
    lgd = getLegendHandle(expAx);
    if ~isempty(lgd) && isvalid(lgd)
        try, lgd.Color     = 'none';   catch, end  % background fill
        try, lgd.EdgeColor = darkColor; catch, end % border stroke
        try, lgd.TextColor = darkColor; catch, end % entry labels
        try, lgd.Title.Color = darkColor; catch, end
    end
    % Thicken data lines for better visibility
    lines = findobj(expAx, 'Type', 'Line');
    for li = 1:numel(lines)
        if lines(li).LineWidth < 1.2
            lines(li).LineWidth = 1.2;
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helper
% ════════════════════════════════════════════════════════════════════════

function lgd = getLegendHandle(expAx)
%GETLEGENDHANDLE  Return the legend object attached to expAx, or [].
%   MATLAB exposes the legend via the axes' Legend property from
%   R2020a+; fall back to findobj on older releases or edge cases.
    lgd = [];
    if isprop(expAx, 'Legend') && ~isempty(expAx.Legend) && isvalid(expAx.Legend)
        lgd = expAx.Legend;
        return;
    end
    par = ancestor(expAx, 'figure');
    if ~isempty(par)
        hits = findobj(par, 'Type', 'Legend');
        if ~isempty(hits), lgd = hits(1); end
    end
end
