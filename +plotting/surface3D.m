function result = surface3D(data, options)
%SURFACE3D  Render 2D data as 3D surface/mesh/contour plot.
%
%   result = plotting.surface3D(data)
%   result = plotting.surface3D(data, Style='mesh', Colormap='parula')
%   result = plotting.surface3D(data, Template='aps')
%
%   Creates a 3D surface visualization from gridded 2D data.  Supports
%   data structs with .map2D fields (from importXRDML 2D mode), or
%   explicit X/Y/Z matrices.
%
%   Inputs:
%       data — one of:
%              (a) struct with .metadata.parserSpecific.map2D containing
%                  .intensity [NxM], .axis1 [Nx1], .axis2 [1xM]
%              (b) struct with fields .X [NxM], .Y [NxM], .Z [NxM]
%              (c) [NxM] numeric matrix (auto-generates X/Y grids)
%
%   Options:
%       Style       — 'surface' | 'mesh' | 'contour3' | 'waterfall3'
%                     (default: 'surface')
%       Colormap    — colormap name string (default: 'parula')
%       LogScale    — log10 the Z data before plotting (default: false)
%       Lighting    — add lighting effects (default: true for 'surface')
%       ViewAngle   — [azimuth elevation] in degrees (default: [-37.5 30])
%       Colorbar    — show colorbar (default: true)
%       XLabel      — X-axis label (default: '' or from data)
%       YLabel      — Y-axis label (default: '' or from data)
%       ZLabel      — Z-axis label (default: 'Intensity')
%       Title       — plot title (default: '')
%       Template    — publication template name (default: '')
%       Clim        — [cMin cMax] colour limits (default: auto)
%
%   Output (struct):
%       .fig  — figure handle
%       .ax   — axes handle
%       .surf — surface/mesh handle
%
%   Examples:
%       % From XRDML 2D data
%       data = parser.importXRDML('rsm.xrdml');
%       plotting.surface3D(data, Style='surface', LogScale=true);
%
%       % From explicit matrices
%       [X,Y] = meshgrid(linspace(-5,5,100));
%       Z = peaks(100);
%       plotting.surface3D(struct('X',X,'Y',Y,'Z',Z));
%
%       % Plain matrix
%       plotting.surface3D(rand(50,50), Style='mesh');

arguments
    data
    options.Style     (1,1) string {mustBeMember(options.Style, ...
        ["surface","mesh","contour3","waterfall3"])} = "surface"
    options.Colormap  (1,1) string = "parula"
    options.LogScale  (1,1) logical = false
    options.Lighting  (1,1) logical = true
    options.ViewAngle (1,2) double = [-37.5 30]
    options.Colorbar  (1,1) logical = true
    options.XLabel    (1,1) string = ""
    options.YLabel    (1,1) string = ""
    options.ZLabel    (1,1) string = "Intensity"
    options.Title     (1,1) string = ""
    options.Template  (1,1) string = ""
    options.Clim      (1,:) double = []
end

% ════════════════════════════════════════════════════════════════════════
% Extract X, Y, Z grids
% ════════════════════════════════════════════════════════════════════════

[X, Y, Z, xLbl, yLbl] = extractGrids(data);

if isempty(Z)
    error('plotting:surface3D:noData', 'Could not extract 2D grid data.');
end

% Log scale
if options.LogScale
    Z = log10(max(Z, eps));
    if options.ZLabel == "Intensity"
        options.ZLabel = "log_{10}(Intensity)";
    end
end

% ════════════════════════════════════════════════════════════════════════
% Create figure
% ════════════════════════════════════════════════════════════════════════

if options.Template ~= ""
    tmpl = styles.template(options.Template);
else
    tmpl = styles.default();
    tmpl.fontName = 'Helvetica';
end

surfFig = figure('Name', '3D Surface', 'NumberTitle', 'off', ...
    'Color', 'w');
surfAx = axes(surfFig);

% ════════════════════════════════════════════════════════════════════════
% Plot
% ════════════════════════════════════════════════════════════════════════

switch char(options.Style)
    case 'surface'
        h = surf(surfAx, X, Y, Z, 'EdgeColor', 'none');
        if options.Lighting
            shading(surfAx, 'interp');
            light(surfAx, 'Position', [1 1 1]);
            lighting(surfAx, 'gouraud');
            material(surfAx, 'dull');
        end

    case 'mesh'
        h = mesh(surfAx, X, Y, Z);
        h.FaceColor = 'interp';
        h.FaceAlpha = 0.5;

    case 'contour3'
        [~, h] = contour3(surfAx, X, Y, Z, 20);

    case 'waterfall3'
        h = waterfall(surfAx, X, Y, Z);
end

% ════════════════════════════════════════════════════════════════════════
% Formatting
% ════════════════════════════════════════════════════════════════════════

colormap(surfAx, char(options.Colormap));

if options.Colorbar
    colorbar(surfAx);
end

if ~isempty(options.Clim) && numel(options.Clim) == 2
    caxis(surfAx, options.Clim); %#ok<CAXIS>
end

view(surfAx, options.ViewAngle);

% Labels
if options.XLabel ~= ""
    xlabel(surfAx, char(options.XLabel), 'FontSize', tmpl.fontSize);
elseif ~isempty(xLbl)
    xlabel(surfAx, xLbl, 'FontSize', tmpl.fontSize);
end

if options.YLabel ~= ""
    ylabel(surfAx, char(options.YLabel), 'FontSize', tmpl.fontSize);
elseif ~isempty(yLbl)
    ylabel(surfAx, yLbl, 'FontSize', tmpl.fontSize);
end

zlabel(surfAx, char(options.ZLabel), 'FontSize', tmpl.fontSize);

if options.Title ~= ""
    title(surfAx, char(options.Title), 'FontSize', tmpl.titleFontSize);
end

surfAx.FontName = tmpl.fontName;
surfAx.FontSize = tmpl.fontSize;
surfAx.Box = 'on';
grid(surfAx, 'on');

% ════════════════════════════════════════════════════════════════════════
% Output
% ════════════════════════════════════════════════════════════════════════

result.fig  = surfFig;
result.ax   = surfAx;
result.surf = h;

end

% ════════════════════════════════════════════════════════════════════════

function [X, Y, Z, xLbl, yLbl] = extractGrids(data)
%EXTRACTGRIDS  Get X, Y, Z matrices from various input formats.
    X = []; Y = []; Z = []; xLbl = ''; yLbl = '';

    if isnumeric(data) && ismatrix(data) && ~isvector(data)
        % Plain [NxM] matrix
        Z = data;
        [nr, nc] = size(Z);
        [X, Y] = meshgrid(1:nc, 1:nr);

    elseif isstruct(data)
        % Check for .X, .Y, .Z fields
        if isfield(data, 'X') && isfield(data, 'Y') && isfield(data, 'Z')
            X = data.X;
            Y = data.Y;
            Z = data.Z;

        % Check for map2D in metadata (from importXRDML)
        elseif isfield(data, 'metadata') && isfield(data.metadata, 'parserSpecific')
            ps = data.metadata.parserSpecific;
            if isfield(ps, 'map2D')
                m = ps.map2D;
                Z = m.intensity;

                % Try Qx/Qz grids first, then axis1/axis2
                if isfield(m, 'Qx') && isfield(m, 'Qz')
                    X = m.Qx;
                    Y = m.Qz;
                    xLbl = 'Q_x (\AA^{-1})';
                    yLbl = 'Q_z (\AA^{-1})';
                elseif isfield(m, 'axis1') && isfield(m, 'axis2')
                    [X, Y] = meshgrid(m.axis2, m.axis1);
                    xLbl = 'Axis 2';
                    yLbl = 'Axis 1';
                else
                    [nr, nc] = size(Z);
                    [X, Y] = meshgrid(1:nc, 1:nr);
                end
            end
        end
    end
end
