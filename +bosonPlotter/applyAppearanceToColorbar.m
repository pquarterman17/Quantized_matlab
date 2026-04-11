function applyAppearanceToColorbar(cbh, appearance)
%APPLYAPPEARANCETOCOLORBAR  Apply a resolved style struct to a Colorbar.
%
%   bosonPlotter.applyAppearanceToColorbar(cbh, appearance)
%
%   Counterpart to bosonPlotter.applyAppearanceToAxes, specialised for
%   matlab.graphics.illustration.ColorBar.  Colorbars live outside the
%   template-to-axes pipeline that Phase F built, so 2D maps ship with
%   Helvetica axes but a default-font colorbar unless this helper runs.
%
%   Why a separate function?  Colorbar properties differ from Axes:
%       • TickDirection  (not TickDir)
%       • TickLength     — scalar, not [major minor]
%       • no Box property
%       • Label is a Text object with its own FontName / FontSize
%
%   INPUTS:
%       cbh         — colorbar handle
%       appearance  — struct with any subset of: fontName, fontSize,
%                     titleFontSize, tickDir, tickLength
%
%   EXAMPLE:
%       cbh = colorbar(ax);
%       a = bosonPlotter.resolveStyle(styles.template('aps'));
%       bosonPlotter.applyAppearanceToColorbar(cbh, a);

    arguments
        cbh          matlab.graphics.illustration.ColorBar
        appearance   struct
    end

    if ~isvalid(cbh), return; end

    % Font on ticks and the axis label
    if isfield(appearance, 'fontName') && ~isempty(appearance.fontName)
        try cbh.FontName = appearance.fontName; catch, end
        try cbh.Label.FontName = appearance.fontName; catch, end
    end
    if isfield(appearance, 'fontSize') && isnumeric(appearance.fontSize) && appearance.fontSize > 0
        try cbh.FontSize = appearance.fontSize; catch, end
    end
    if isfield(appearance, 'titleFontSize') && isnumeric(appearance.titleFontSize) && appearance.titleFontSize > 0
        try cbh.Label.FontSize = appearance.titleFontSize; catch, end
    end

    % Tick direction — different property name from axes.  Accept any of
    % 'in' / 'out' / 'both' and pass straight through.
    if isfield(appearance, 'tickDir') && ~isempty(appearance.tickDir)
        try cbh.TickDirection = appearance.tickDir; catch, end
    end

    % Tick length — colorbar uses a single scalar (fraction of the long
    % axis).  resolveStyle stores [major minor]; take the major value.
    if isfield(appearance, 'tickLength') && isnumeric(appearance.tickLength) && ~isempty(appearance.tickLength)
        try cbh.TickLength = appearance.tickLength(1); catch, end
    end
end
