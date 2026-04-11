function applyAppearanceToAxes(targetAx, appearance)
%APPLYAPPEARANCETOAXES  Apply a resolved style struct to an axes handle.
%
%   bosonPlotter.applyAppearanceToAxes(ax, appearance)
%
%   Sets the axes-level visual properties (FontName, FontSize, TickDir,
%   Box, TickLength, grid state, GridAlpha, minor ticks, Title font size)
%   from the struct produced by bosonPlotter.resolveStyle.  This lets the
%   analysis dialogs (peak window, curve fit, reflFitting, etc.) share
%   the same visual template as the main BosonPlotter preview, closing
%   the WYSIWYG asymmetry between the preview and the secondary windows.
%
%   Only axes-level properties are touched — individual line LineWidth /
%   MarkerSize / Color remain under the caller's control, since those are
%   often relative (e.g. a fit line is 1.5× the width of data points).
%
%   Safe to call with any struct that has the fields produced by
%   bosonPlotter.resolveStyle.  Missing fields are skipped — this makes
%   it robust to partial override structs from old sessions.
%
%   INPUTS:
%       targetAx    — axes handle
%       appearance  — struct with any subset of: fontName, fontSize,
%                     titleFontSize, tickDir, tickLength, boxOn,
%                     gridAlpha, minorTicks
%
%   EXAMPLE:
%       ax = axes(fig);
%       plot(ax, x, y);
%       a = bosonPlotter.resolveStyle(styles.template('aps'));
%       bosonPlotter.applyAppearanceToAxes(ax, a);

    arguments
        targetAx     matlab.graphics.axis.Axes
        appearance   struct
    end

    if ~isvalid(targetAx), return; end

    if isfield(appearance, 'fontName') && ~isempty(appearance.fontName)
        try targetAx.FontName = appearance.fontName; catch, end
        try targetAx.Title.FontName = appearance.fontName; catch, end
    end
    if isfield(appearance, 'fontSize') && isnumeric(appearance.fontSize) && appearance.fontSize > 0
        try targetAx.FontSize = appearance.fontSize; catch, end
    end
    if isfield(appearance, 'titleFontSize') && isnumeric(appearance.titleFontSize) && appearance.titleFontSize > 0
        try targetAx.Title.FontSize = appearance.titleFontSize; catch, end
    end
    if isfield(appearance, 'tickDir') && ~isempty(appearance.tickDir)
        try targetAx.TickDir = appearance.tickDir; catch, end
    end
    if isfield(appearance, 'tickLength') && isnumeric(appearance.tickLength) && numel(appearance.tickLength) == 2
        try targetAx.TickLength = appearance.tickLength; catch, end
    end
    if isfield(appearance, 'boxOn')
        try
            if appearance.boxOn, targetAx.Box = 'on';
            else,                 targetAx.Box = 'off'; end
        catch
        end
    end
    if isfield(appearance, 'gridAlpha') && isnumeric(appearance.gridAlpha)
        if appearance.gridAlpha > 0
            try grid(targetAx, 'on'); targetAx.GridAlpha = appearance.gridAlpha; catch, end
        else
            try grid(targetAx, 'off'); catch, end
        end
    end
    if isfield(appearance, 'minorTicks')
        state = 'off';
        if appearance.minorTicks, state = 'on'; end
        try targetAx.XAxis.MinorTick = state; catch, end
        try
            for yi = 1:numel(targetAx.YAxis)
                targetAx.YAxis(yi).MinorTick = state;
            end
        catch
        end
    end
end
