function t = template(name)
%TEMPLATE  Return a publication-ready graph template by name.
%
%   t = styles.template('aps')
%   t = styles.template('nature')
%   t = styles.template('thesis')
%
%   Returns a struct extending the styles.default() pattern with
%   journal- or context-specific formatting.  Use with
%   plotting.applyTemplate(fig, ax, t) to apply.
%
%   Available templates:
%       'aps'          — APS journals (PRB, PRL, PRApplied): Helvetica, 8.6 cm
%       'aps_double'   — APS double-column: 17.8 cm
%       'nature'       — Nature family: Arial 7pt, 8.9 cm
%       'nature_double'— Nature double-column: 18.3 cm
%       'thesis'       — Dissertation figures: Times, 15 cm
%       'presentation' — Conference slides: Arial 18pt, 25 cm
%       'poster'       — Research posters: Arial 24pt, 30 cm
%       'screen'       — Default screen display (= styles.default)
%
%   Template struct fields (superset of styles.default):
%       .name            — template name string
%       .fontName        — font family
%       .fontSize        — axis tick / label font size (pt)
%       .titleFontSize   — title font size (pt)
%       .legendFontSize  — legend font size (pt)
%       .lineWidth       — primary line width (pt)
%       .lineWidthThin   — secondary line width (pt)
%       .markerSize      — marker size (pt)
%       .figWidth_cm     — figure width in centimetres
%       .figHeight_cm    — figure height in centimetres
%       .dpi             — export resolution (dots per inch)
%       .tickDir         — 'in' | 'out' | 'both'
%       .tickLength      — normalised tick length [major minor]
%       .boxOn           — logical — draw box around axes
%       .gridAlpha       — grid transparency (0 = off)
%       .legendBox       — logical — draw box around legend
%       .legendLocation  — legend placement string
%       .colors          — [Nx3] colour cycle
%
%   Example:
%       t = styles.template('aps');
%       fig = figure; ax = axes(fig);
%       plot(ax, x, y);
%       plotting.applyTemplate(fig, ax, t);
%       plotting.saveFigure(fig, 'figure1.pdf');
%
%   See also styles.default, plotting.applyTemplate, plotting.formatAxes

arguments
    name (1,1) string
end

% Colourblind-friendly palette (default for all templates)
cbPalette = [
    0.000  0.447  0.741   % blue
    0.850  0.325  0.098   % vermillion
    0.000  0.620  0.451   % bluish green
    0.800  0.475  0.655   % reddish purple
    0.929  0.694  0.125   % yellow
    0.337  0.706  0.914   % sky blue
    0.494  0.184  0.556   % dark purple
    0.466  0.674  0.188   % yellow-green
];

switch lower(name)
    case 'aps'
        t = baseTemplate('aps', 'Helvetica', 9, 10, 8, ...
            1.25, 0.75, 4, 8.6, 6.5, 600, cbPalette);
        t.tickLength = [0.02 0.01];
        t.gridAlpha  = 0;
        t.legendBox  = false;

    case 'aps_double'
        t = baseTemplate('aps_double', 'Helvetica', 9, 10, 8, ...
            1.25, 0.75, 4, 17.8, 6.5, 600, cbPalette);
        t.tickLength = [0.015 0.008];
        t.gridAlpha  = 0;
        t.legendBox  = false;

    case 'nature'
        t = baseTemplate('nature', 'Arial', 7, 8, 6, ...
            1.0, 0.5, 3, 8.9, 6.0, 600, cbPalette);
        t.tickLength = [0.02 0.01];
        t.gridAlpha  = 0;
        t.legendBox  = false;

    case 'nature_double'
        t = baseTemplate('nature_double', 'Arial', 7, 8, 6, ...
            1.0, 0.5, 3, 18.3, 6.0, 600, cbPalette);
        t.tickLength = [0.015 0.008];
        t.gridAlpha  = 0;
        t.legendBox  = false;

    case 'thesis'
        t = baseTemplate('thesis', 'Times New Roman', 11, 12, 10, ...
            1.5, 0.75, 5, 15.0, 10.0, 300, cbPalette);
        t.tickLength = [0.015 0.008];
        t.gridAlpha  = 0.15;
        t.legendBox  = true;

    case 'presentation'
        t = baseTemplate('presentation', 'Arial', 18, 20, 14, ...
            2.5, 1.5, 8, 25.0, 18.0, 150, cbPalette);
        t.tickLength = [0.012 0.006];
        t.gridAlpha  = 0.2;
        t.legendBox  = false;

    case 'poster'
        t = baseTemplate('poster', 'Arial', 24, 28, 18, ...
            3.0, 2.0, 10, 30.0, 22.0, 150, cbPalette);
        t.tickLength = [0.012 0.006];
        t.gridAlpha  = 0.15;
        t.legendBox  = false;

    case 'screen'
        % Thin wrapper around styles.default()
        s = styles.default();
        t = s;
        t.name          = 'screen';
        t.fontName      = 'Helvetica';
        t.figWidth_cm   = s.figWidth;
        t.figHeight_cm  = s.figHeight;
        t.dpi           = 150;
        t.tickLength    = [0.01 0.005];
        t.legendBox     = true;
        t.legendLocation = 'best';

    otherwise
        error('styles:template:unknown', ...
            'Unknown template "%s". Available: aps, aps_double, nature, nature_double, thesis, presentation, poster, screen.', name);
end

end

% ════════════════════════════════════════════════════════════════════════

function t = baseTemplate(name, fontName, fontSize, titleFS, legendFS, ...
    lineWidth, lineWidthThin, markerSize, widthCm, heightCm, dpi, colors)
%BASETEMPLATE  Construct a template struct with common defaults.
    t.name           = name;
    t.fontName       = fontName;
    t.fontSize       = fontSize;
    t.titleFontSize  = titleFS;
    t.legendFontSize = legendFS;
    t.lineWidth      = lineWidth;
    t.lineWidthThin  = lineWidthThin;
    t.markerSize     = markerSize;
    t.figWidth_cm    = widthCm;
    t.figHeight_cm   = heightCm;
    t.figWidth       = widthCm;      % alias for compatibility with styles.default
    t.figHeight      = heightCm;
    t.dpi            = dpi;
    t.colors         = colors;
    t.tickDir        = 'in';
    t.boxOn          = true;
    t.legendLocation = 'best';

    % ── Phase A visual-style fields ──────────────────────────────────
    % Read by bosonPlotter.resolveStyle and consumed by renderPlot so the
    % live preview matches the exported figure.  Individual templates
    % below may override any of these.
    t.markerShape    = 'o';       % 'auto' = cycle per dataset (o,s,^,d,v,x,+,*)
    t.lineStyle      = '-';       % 'auto' = cycle per dataset (-,--,-.,:)
    t.alpha          = 1.0;       % 0..1 line/marker transparency
    t.minorTicks     = false;     % minor tick visibility
    % tickLength, gridAlpha, legendBox set by caller
end
