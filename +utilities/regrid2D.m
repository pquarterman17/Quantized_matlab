function [Xq, Yq, Zq] = regrid2D(x, y, z, Options)
%REGRID2D  Resample scattered or gridded 2-D data onto a regular Cartesian grid.
%
%   Syntax:
%       [Xq, Yq, Zq] = utilities.regrid2D(x, y, z)
%       [Xq, Yq, Zq] = utilities.regrid2D(x, y, z, Nx=200, Ny=200)
%       [Xq, Yq, Zq] = utilities.regrid2D(x, y, z, Method="thinplate", Nx=50)
%       [Xq, Yq, Zq] = utilities.regrid2D(x, y, z, XLim=[0 1], YLim=[0 1])
%
%   Inputs:
%       x, y  — coordinate arrays ([N×1] scattered or [Ny×Nx] gridded).
%       z     — data values, same size as x and y.
%
%   Options:
%       Nx     — number of grid columns (default 100)
%       Ny     — number of grid rows    (default 100)
%       Method — interpolation method passed to utilities.interpolate2D
%                (default "natural")
%       XLim   — [xmin xmax] bounds for output grid (default: data range)
%       YLim   — [ymin ymax] bounds for output grid (default: data range)
%       Extrapolation — passed through to interpolate2D (default "none")
%       Smoothing     — TPS smoothing parameter (default 0)
%       IDWPower      — IDW power (default 2)
%
%   Outputs:
%       Xq — [Ny×Nx] meshgrid of x-coordinates
%       Yq — [Ny×Nx] meshgrid of y-coordinates
%       Zq — [Ny×Nx] interpolated values (NaN outside convex hull if
%            Extrapolation="none")
%
%   Examples:
%       % Quick surface from scattered measurements
%       [Xg, Yg, Zg] = utilities.regrid2D(xData, yData, zData);
%       surf(Xg, Yg, Zg);
%
%       % High-resolution regrid with explicit bounds
%       [Xg, Yg, Zg] = utilities.regrid2D(x, y, z, Nx=300, Ny=300, ...
%                           XLim=[0 10], YLim=[0 10]);
%
%   See also utilities.interpolate2D, meshgrid

arguments
    x   (:,:) double
    y   (:,:) double
    z   (:,:) double
    Options.Nx     (1,1) double {mustBePositive, mustBeInteger} = 100
    Options.Ny     (1,1) double {mustBePositive, mustBeInteger} = 100
    Options.Method (1,1) string {mustBeMember(Options.Method, ...
        ["linear","natural","nearest","cubic","thinplate","idw"])} = "natural"
    Options.XLim   (1,2) double = [NaN NaN]
    Options.YLim   (1,2) double = [NaN NaN]
    Options.Extrapolation (1,1) string {mustBeMember(Options.Extrapolation, ...
        ["none","nearest","linear"])} = "none"
    Options.Smoothing (1,1) double {mustBeNonnegative} = 0
    Options.IDWPower  (1,1) double {mustBePositive}    = 2
end

% ════════════════════════════════════════════════════════════════════════
% Determine grid bounds
% ════════════════════════════════════════════════════════════════════════
xv = x(:);
yv = y(:);

if isnan(Options.XLim(1))
    xLim = [min(xv), max(xv)];
else
    xLim = Options.XLim;
end

if isnan(Options.YLim(1))
    yLim = [min(yv), max(yv)];
else
    yLim = Options.YLim;
end

if xLim(1) >= xLim(2)
    error('utilities:regrid2D:badXLim', 'XLim(1) must be less than XLim(2).');
end
if yLim(1) >= yLim(2)
    error('utilities:regrid2D:badYLim', 'YLim(1) must be less than YLim(2).');
end

% ════════════════════════════════════════════════════════════════════════
% Build regular query grid
% ════════════════════════════════════════════════════════════════════════
xGrid = linspace(xLim(1), xLim(2), Options.Nx);
yGrid = linspace(yLim(1), yLim(2), Options.Ny);
[Xq, Yq] = meshgrid(xGrid, yGrid);

% ════════════════════════════════════════════════════════════════════════
% Interpolate
% ════════════════════════════════════════════════════════════════════════
r = utilities.interpolate2D(x, y, z, Xq, Yq, ...
    Method        = Options.Method, ...
    Extrapolation = Options.Extrapolation, ...
    Smoothing     = Options.Smoothing, ...
    IDWPower      = Options.IDWPower);

Zq = r.zq;

end % regrid2D
