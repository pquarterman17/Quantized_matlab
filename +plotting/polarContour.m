function ax = polarContour(theta, r, Z, options)
%POLARCONTOUR  Filled contour plot on polar coordinates.
%
%   Renders a 2D intensity map Z(r, θ) as a filled contour on a circular
%   (polar) projection. Appropriate for XRD pole figures, angular-dependent
%   reciprocal-space maps, crystallographic texture plots, and any scalar
%   field sampled on a polar grid.
%
%   MATLAB's polaraxes does not support contourf, so this function builds
%   the (r, θ) mesh, converts it to Cartesian, calls contourf on a
%   standard 2D axis, and overlays radial grid circles and angular spokes
%   to recreate the polar look. Axis is set to equal aspect ratio and
%   ticks are hidden.
%
% Syntax
%   plotting.polarContour(theta, r, Z)
%   plotting.polarContour(theta, r, Z, 'Levels', 30)
%   ax = plotting.polarContour(theta, r, Z, 'ThetaZero', 'top', ...
%                              'ThetaDir', 'cw', 'Title', 'Pole figure');
%
% Inputs
%   theta   [Nθ×1] angle vector (degrees by default)
%   r       [Nr×1] radial vector, non-negative, monotone
%   Z       [Nr×Nθ] intensity matrix (rows index r, cols index θ) — note
%           the orientation matches [T,R] = meshgrid(theta, r).
%
% Name-value options
%   Parent        Target axes handle (default: gca)
%   Levels        Contour levels: scalar N → N auto-spaced levels,
%                 or a vector of explicit level values (default 20)
%   ThetaUnit     'degrees' (default) or 'radians'
%   ThetaZero     'top' (default — pole-figure convention) or 'right'
%   ThetaDir      'cw' or 'ccw' (default). Pole figures conventionally
%                 use ThetaZero='top' + ThetaDir='cw'.
%   RLim          [rMin rMax] radial limits (default: [min(r) max(r)])
%   Title         Axes title string
%   Colormap      Name string for the colormap (e.g. 'parula','jet')
%   ShowGrid      Draw radial circles + angular spokes (default true)
%   NGridR        Number of radial grid circles (default 4)
%   NGridTheta    Number of angular spokes (default 12 → every 30°)
%   Colorbar      Draw a colorbar (default true)
%   Filled        Filled contourf (default) vs line contour
%   LineColor     Contour line color for non-filled mode (default 'k')
%
% Output
%   ax   Handle to the axes containing the plot.
%
% Example
%   % Synthetic XRD pole figure with 4-fold symmetry
%   chi = linspace(0, 90, 46);        % tilt, degrees
%   phi = linspace(0, 360, 73);       % azimuth, degrees
%   [P, C] = meshgrid(phi, chi);
%   I = exp(-((C - 45).^2)/50) .* (1 + cos(4 * P * pi/180));
%   plotting.polarContour(phi, chi, I, 'ThetaDir', 'cw', ...
%       'Title', '{220} Pole Figure'); colorbar;
%
% See also: plotting.polarPlot, plotting.ternaryPlot

arguments
    theta (:,1) double {mustBeReal}
    r     (:,1) double {mustBeReal, mustBeNonnegative}
    Z     (:,:) double {mustBeReal}
    options.Parent = []
    options.Levels = 20
    options.ThetaUnit (1,1) string {mustBeMember(options.ThetaUnit, ["degrees","radians"])} = "degrees"
    options.ThetaZero (1,1) string {mustBeMember(options.ThetaZero, ["top","right"])} = "top"
    options.ThetaDir  (1,1) string {mustBeMember(options.ThetaDir,  ["cw","ccw"])}     = "ccw"
    options.RLim double = []
    options.Title string = ""
    options.Colormap string = ""
    options.ShowGrid (1,1) logical = true
    options.NGridR (1,1) double {mustBePositive, mustBeInteger} = 4
    options.NGridTheta (1,1) double {mustBePositive, mustBeInteger} = 12
    options.Colorbar (1,1) logical = true
    options.Filled (1,1) logical = true
    options.LineColor = 'k'
end

Nr  = numel(r);
Nth = numel(theta);
assert(isequal(size(Z), [Nr Nth]), ...
    'plotting:polarContour:sizeMismatch', ...
    ['Z must be [Nr x Nth] = [%d x %d] to match the (r, theta) grid, ' ...
     'got [%d x %d].'], Nr, Nth, size(Z,1), size(Z,2));
assert(Nr >= 2 && Nth >= 2, ...
    'plotting:polarContour:tooFewSamples', ...
    'Need at least 2 samples in each direction (got Nr=%d, Nth=%d).', Nr, Nth);

% Convert theta to radians with the requested zero direction and rotation sense
if options.ThetaUnit == "degrees"
    th = deg2rad(theta);
else
    th = theta;
end
if options.ThetaDir == "cw"
    th = -th;
end
if options.ThetaZero == "top"
    th = th + pi/2;
end

% Apply radial limits
rUse = r;
zUse = Z;
if ~isempty(options.RLim)
    assert(numel(options.RLim) == 2 && options.RLim(1) < options.RLim(2), ...
        'plotting:polarContour:badRLim', ...
        'RLim must be [rMin rMax] with rMin < rMax.');
    keep = r >= options.RLim(1) & r <= options.RLim(2);
    rUse = r(keep);
    zUse = Z(keep, :);
    assert(numel(rUse) >= 2, ...
        'plotting:polarContour:emptyRLim', ...
        'RLim excluded too many radial samples (got %d, need >=2).', numel(rUse));
end
rMax = max(rUse);

% Build the Cartesian mesh  — meshgrid(th, rUse) returns [length(rUse) × length(th)]
[T, R] = meshgrid(th, rUse);
X = R .* cos(T);
Y = R .* sin(T);

% Target axes
if isempty(options.Parent)
    ax = gca;
else
    ax = options.Parent;
end
hold(ax, 'on');
axis(ax, 'equal');
xlim(ax, [-rMax*1.1, rMax*1.1]);
ylim(ax, [-rMax*1.1, rMax*1.1]);

% Draw the contour
if options.Filled
    [~, hC] = contourf(ax, X, Y, zUse, options.Levels);
    set(hC, 'LineStyle', 'none');
else
    contour(ax, X, Y, zUse, options.Levels, ...
        'LineColor', options.LineColor);
end

% Overlay polar grid
if options.ShowGrid
    gridColor = [0.35 0.35 0.35];
    % Radial circles
    tCirc = linspace(0, 2*pi, 200);
    for k = 1:options.NGridR
        rr = rMax * k / options.NGridR;
        plot(ax, rr*cos(tCirc), rr*sin(tCirc), ...
            'Color', gridColor, 'LineWidth', 0.5, 'LineStyle', ':', ...
            'HandleVisibility', 'off');
    end
    % Angular spokes
    for k = 0:options.NGridTheta-1
        a = 2*pi * k / options.NGridTheta;
        plot(ax, [0, rMax*cos(a)], [0, rMax*sin(a)], ...
            'Color', gridColor, 'LineWidth', 0.5, 'LineStyle', ':', ...
            'HandleVisibility', 'off');
    end
    % Outer ring
    plot(ax, rMax*cos(tCirc), rMax*sin(tCirc), ...
        'Color', 'k', 'LineWidth', 1, 'HandleVisibility', 'off');
end

axis(ax, 'off');

% Colormap and colorbar
if strlength(options.Colormap) > 0
    colormap(ax, char(options.Colormap));
end
if options.Colorbar
    colorbar(ax);
end

if strlength(options.Title) > 0
    title(ax, char(options.Title));
end

hold(ax, 'off');
end
