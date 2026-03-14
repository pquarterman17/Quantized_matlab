function s = dark()
%DARK  Return a dark visual theme for thin-film toolkit plots and GUI.
%
%   s = styles.dark()
%
%   Returns a struct with fields controlling colours, line widths, font
%   sizes, marker sizes, and GUI panel/text colours for a dark theme.
%   Extends the same field set as styles.default() with additional
%   fields for uifigure panel theming.
%
%   ADDITIONAL FIELDS (beyond styles.default):
%       s.bgColor       — [1x3] RGB background for panels / figure
%       s.fgColor       — [1x3] RGB foreground for text / labels
%       s.axesBgColor   — [1x3] RGB axes background
%       s.axesFgColor   — [1x3] RGB axes tick / label colour
%       s.gridColor     — [1x3] RGB grid line colour
%       s.panelBgColor  — [1x3] RGB for uipanel / uigridlayout
%       s.buttonBgColor — [1x3] RGB for button backgrounds
%       s.buttonFgColor — [1x3] RGB for button text
%       s.listBgColor   — [1x3] RGB for listbox background
%       s.listFgColor   — [1x3] RGB for listbox text
%       s.editBgColor   — [1x3] RGB for edit field background
%       s.editFgColor   — [1x3] RGB for edit field text
%
%   EXAMPLE:
%       th = styles.dark();
%       figure('Color', th.bgColor);
%       plot(x, y, 'Color', th.colors(1,:), 'LineWidth', th.lineWidth);
%       set(gca, 'Color', th.axesBgColor, 'XColor', th.axesFgColor, ...
%                'YColor', th.axesFgColor);
%
%   See also styles.default, plotting.formatAxes

    % ── Colour palette (bright on dark, colourblind-friendly) ────────────
    s.colors = [
        0.400  0.761  1.000   % light blue
        1.000  0.400  0.400   % coral red
        0.400  0.867  0.400   % light green
        0.749  0.561  0.902   % light purple
        1.000  0.702  0.247   % warm orange
        0.898  0.624  0.506   % salmon
    ];

    % ── Line geometry ────────────────────────────────────────────────────
    s.lineWidth     = 1.75;
    s.lineWidthThin = 1.0;
    s.markerSize    = 6;

    % ── Typography ───────────────────────────────────────────────────────
    s.fontSize       = 12;
    s.titleFontSize  = 14;
    s.legendFontSize = 10;

    % ── Figure size (cm) ─────────────────────────────────────────────────
    s.figWidth  = 14;
    s.figHeight = 10;

    % ── Axes appearance ──────────────────────────────────────────────────
    s.tickDir   = 'in';
    s.boxOn     = true;
    s.gridAlpha = 0.35;

    % ── Dark theme: surface colours ──────────────────────────────────────
    s.bgColor      = [0.15  0.15  0.17];   % figure / root background
    s.fgColor      = [0.90  0.90  0.92];   % primary text
    s.axesBgColor  = [0.18  0.18  0.20];   % axes plot area
    s.axesFgColor  = [0.85  0.85  0.87];   % axis ticks and labels
    s.gridColor    = [0.35  0.35  0.38];   % grid lines

    % ── Dark theme: widget colours ───────────────────────────────────────
    s.panelBgColor  = [0.18  0.18  0.20];  % uipanel / uigridlayout
    s.buttonBgColor = [0.25  0.25  0.28];  % uibutton
    s.buttonFgColor = [0.90  0.90  0.92];  % uibutton text
    s.listBgColor   = [0.20  0.20  0.22];  % uilistbox
    s.listFgColor   = [0.88  0.88  0.90];  % uilistbox text
    s.editBgColor   = [0.22  0.22  0.25];  % uieditfield
    s.editFgColor   = [0.90  0.90  0.92];  % uieditfield text
end
