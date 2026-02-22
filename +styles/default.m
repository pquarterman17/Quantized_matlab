function s = default()
%DEFAULT  Return the default visual theme for thin-film toolkit plots.
%
%   s = styles.default()
%
%   Returns a struct with fields controlling colours, line widths, font
%   sizes and marker sizes.  Pass this struct to plotting helpers such as
%   plotting.formatAxes() to apply the theme consistently across figures.
%
%   FIELDS:
%       s.colors        — [Nx3] RGB colour palette (rows are colours)
%       s.lineWidth     — primary line width (points)
%       s.lineWidthThin — secondary / overlay line width
%       s.markerSize    — default marker size (points)
%       s.fontSize      — axis label and tick font size (points)
%       s.titleFontSize — title font size (points)
%       s.legendFontSize— legend font size (points)
%       s.figWidth      — default figure width  (cm)
%       s.figHeight     — default figure height (cm)
%       s.tickDir       — 'in' | 'out' | 'both'
%       s.boxOn         — logical — draw box around axes
%       s.gridAlpha     — grid line transparency [0,1]
%
%   EXAMPLE:
%       th = styles.default();
%       figure; plot(x, y, 'Color', th.colors(1,:), 'LineWidth', th.lineWidth);
%       plotting.formatAxes(gca, th);
%
%   See also plotting.formatAxes, plotting.lineColors, plotting.saveFigure

    % ── Colour palette (6 distinguishable colours, colourblind-friendly) ──
    s.colors = [
        0.122  0.471  0.706   % blue
        0.839  0.153  0.157   % red
        0.173  0.627  0.173   % green
        0.580  0.404  0.741   % purple
        1.000  0.498  0.055   % orange
        0.549  0.337  0.294   % brown
    ];

    % ── Line geometry ──────────────────────────────────────────────────────
    s.lineWidth     = 1.5;
    s.lineWidthThin = 0.75;
    s.markerSize    = 5;

    % ── Typography ─────────────────────────────────────────────────────────
    s.fontSize       = 11;
    s.titleFontSize  = 12;
    s.legendFontSize = 9;

    % ── Figure size (cm) ──────────────────────────────────────────────────
    s.figWidth  = 14;
    s.figHeight = 10;

    % ── Axes appearance ───────────────────────────────────────────────────
    s.tickDir  = 'in';
    s.boxOn    = true;
    s.gridAlpha = 0.25;
end
