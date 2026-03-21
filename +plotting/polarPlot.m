function result = polarPlot(theta, r, options)
%POLARPLOT  Polar coordinate plot for angular-dependent measurements.
%
%   result = plotting.polarPlot(theta, r)
%   result = plotting.polarPlot(theta, r, Style='filled', Template='aps')
%
%   Creates a publication-ready polar plot for phi scans, pole figures,
%   torque magnetometry, and angular-dependent transport measurements.
%
%   Inputs:
%       theta — [N×1] angle vector (degrees)
%       r     — [N×1] radial values, OR [N×M] for multiple datasets
%
%   Options:
%       Style      — 'line' | 'scatter' | 'filled' | 'stem' (default: 'line')
%       ThetaUnit  — 'degrees' | 'radians' (default: 'degrees')
%       Symmetric  — mirror data across origin for half-scans (default: false)
%       Normalize  — normalize r to [0,1] (default: false)
%       RLabel     — radial axis label (default: '')
%       Title      — plot title (default: '')
%       Template   — publication template name (default: '')
%       Labels     — cell array of legend labels for multi-dataset (default: {})
%       RLim       — [rMin rMax] radial limits (default: auto)
%       ThetaZero  — angle for the 0° direction: 'top' | 'right' (default: 'top')
%       ThetaDir   — 'counterclockwise' | 'clockwise' (default: 'counterclockwise')
%       GridLines  — number of radial grid circles (default: 4)
%       FigureSize — [width height] in cm (default: from template)
%       Parent     — axes handle to plot into (default: create new figure)
%
%   Output (struct):
%       .fig    — figure handle (empty if Parent provided)
%       .ax     — polaraxes handle
%       .lines  — array of line handles
%
%   Examples:
%       % XRD phi scan (4-fold symmetry)
%       plotting.polarPlot(phi_deg, intensity, Title='Si (220) Phi Scan');
%
%       % Torque magnetometry
%       plotting.polarPlot(angle, torque, Style='filled', Normalize=true);
%
%       % Compare two samples
%       plotting.polarPlot(phi, [I_sampleA, I_sampleB], ...
%           Labels={'Sample A', 'Sample B'}, Template='aps');
%
%       % Half-scan mirrored to full circle
%       plotting.polarPlot(phi_half, r_half, Symmetric=true);

arguments
    theta  (:,1) double
    r      (:,:) double
    options.Style      (1,1) string {mustBeMember(options.Style, ...
        ["line","scatter","filled","stem"])} = "line"
    options.ThetaUnit  (1,1) string {mustBeMember(options.ThetaUnit, ...
        ["degrees","radians"])} = "degrees"
    options.Symmetric  (1,1) logical = false
    options.Normalize  (1,1) logical = false
    options.RLabel     (1,1) string = ""
    options.Title      (1,1) string = ""
    options.Template   (1,1) string = ""
    options.Labels     cell = {}
    options.RLim       (1,:) double = []
    options.ThetaZero  (1,1) string {mustBeMember(options.ThetaZero, ...
        ["top","right"])} = "top"
    options.ThetaDir   (1,1) string {mustBeMember(options.ThetaDir, ...
        ["counterclockwise","clockwise"])} = "counterclockwise"
    options.GridLines  (1,1) double = 4
    options.FigureSize (1,:) double = []
    options.Parent              = []
end

% ════════════════════════════════════════════════════════════════════════
% Convert to radians if needed
% ════════════════════════════════════════════════════════════════════════

if strcmp(options.ThetaUnit, 'degrees')
    thetaRad = deg2rad(theta);
else
    thetaRad = theta;
end

% Symmetric: mirror half-scan data
if options.Symmetric
    thetaRad = [thetaRad; thetaRad + pi];
    r = [r; r];
end

% Normalize
if options.Normalize
    for ci = 1:size(r, 2)
        rCol = r(:, ci);
        rMin = min(rCol);
        rRange = max(rCol) - rMin;
        if rRange > 0
            r(:, ci) = (rCol - rMin) / rRange;
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
% Template
% ════════════════════════════════════════════════════════════════════════

if options.Template ~= ""
    tmpl = styles.template(options.Template);
else
    tmpl = styles.default();
    tmpl.fontName = 'Helvetica';
end

colors = tmpl.colors;
nColors = size(colors, 1);

% ════════════════════════════════════════════════════════════════════════
% Create figure / axes
% ════════════════════════════════════════════════════════════════════════

if ~isempty(options.Parent) && isvalid(options.Parent)
    pax = options.Parent;
    pfig = [];
else
    % Figure size
    if ~isempty(options.FigureSize) && numel(options.FigureSize) == 2
        wCm = options.FigureSize(1);
        hCm = options.FigureSize(2);
    else
        wCm = tmpl.figWidth;
        hCm = tmpl.figHeight;
    end
    pxPerCm = 96 / 2.54;
    pfig = figure('Name', 'Polar Plot', 'NumberTitle', 'off', ...
        'Color', 'w', 'Units', 'pixels', ...
        'Position', [150 100 wCm*pxPerCm hCm*pxPerCm]);
    pax = polaraxes(pfig);
end

% ════════════════════════════════════════════════════════════════════════
% Plot data
% ════════════════════════════════════════════════════════════════════════

nDS = size(r, 2);
lineHandles = gobjects(nDS, 1);

hold(pax, 'on');
for di = 1:nDS
    ci = mod(di - 1, nColors) + 1;
    col = colors(ci, :);
    rData = r(:, di);

    switch char(options.Style)
        case 'line'
            lineHandles(di) = polarplot(pax, thetaRad, rData, '-', ...
                'Color', col, 'LineWidth', tmpl.lineWidth);
        case 'scatter'
            lineHandles(di) = polarplot(pax, thetaRad, rData, '.', ...
                'Color', col, 'MarkerSize', tmpl.markerSize * 2);
        case 'filled'
            % Filled area under the curve
            lineHandles(di) = polarplot(pax, thetaRad, rData, '-', ...
                'Color', col, 'LineWidth', tmpl.lineWidth);
            % Add fill using patch in Cartesian coordinates
            [xFill, yFill] = pol2cart([thetaRad; thetaRad(1)], [rData; rData(1)]);
            patch(pax.Parent, xFill, yFill, col, ...
                'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
        case 'stem'
            for si = 1:numel(thetaRad)
                polarplot(pax, [thetaRad(si) thetaRad(si)], [0 rData(si)], ...
                    '-', 'Color', col, 'LineWidth', 0.5, 'HandleVisibility', 'off');
            end
            lineHandles(di) = polarplot(pax, thetaRad, rData, '.', ...
                'Color', col, 'MarkerSize', tmpl.markerSize);
    end
end
hold(pax, 'off');

% ════════════════════════════════════════════════════════════════════════
% Formatting
% ════════════════════════════════════════════════════════════════════════

% Theta zero location
switch char(options.ThetaZero)
    case 'top',   pax.ThetaZeroLocation = 'top';
    case 'right', pax.ThetaZeroLocation = 'right';
end

% Theta direction
pax.ThetaDir = char(options.ThetaDir);

% Grid
pax.RGrid = 'on';
pax.ThetaGrid = 'on';
if options.GridLines > 0
    pax.RMinorGrid = 'off';
end

% Radial limits
if ~isempty(options.RLim) && numel(options.RLim) == 2
    pax.RLim = options.RLim;
end

% Font
pax.FontName = tmpl.fontName;
pax.FontSize = tmpl.fontSize;

% Title
if options.Title ~= ""
    title(pax, char(options.Title), 'FontSize', tmpl.titleFontSize, ...
        'FontName', tmpl.fontName);
end

% R-axis label
if options.RLabel ~= ""
    pax.RAxis.Label.String = char(options.RLabel);
end

% Legend
if ~isempty(options.Labels) && numel(options.Labels) == nDS
    legend(pax, lineHandles, options.Labels, 'Location', 'best', ...
        'FontSize', tmpl.legendFontSize);
end

% ════════════════════════════════════════════════════════════════════════
% Output
% ════════════════════════════════════════════════════════════════════════

result.fig   = pfig;
result.ax    = pax;
result.lines = lineHandles;

end
