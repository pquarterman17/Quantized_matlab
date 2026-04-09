function ax = ternaryPlot(fractions, options)
%TERNARYPLOT  Plot three-component compositions on an equilateral triangle.
%
%   Maps each row of FRACTIONS = [a b c] to Cartesian coordinates inside an
%   equilateral triangle with vertices A = (0,0), B = (1,0), C = (0.5, √3/2)
%   via the standard barycentric map  [x,y] = a·A + b·B + c·C.  Rows that do
%   not sum to 1 are automatically normalized.
%
%   Appropriate for ternary phase diagrams, alloy compositions, EDS
%   quantification maps, sputter-deposition calibration, and any other
%   three-component mixture where two conventional axes would hide the
%   third degree of freedom.
%
% Syntax
%   plotting.ternaryPlot(fractions)
%   plotting.ternaryPlot(fractions, 'Values', v)
%   ax = plotting.ternaryPlot(fractions, 'Labels', {'Fe','Ni','Cr'}, ...)
%
% Inputs
%   fractions   Nx3 numeric matrix of component fractions. Each row is
%               auto-normalized so a+b+c = 1. Negative values error.
%
% Name-value options
%   Parent        Target axes handle (default: gca on a new figure)
%   Labels        1x3 cellstr/string of vertex labels (default {'A','B','C'})
%   Values        Nx1 scalar values → color-codes each point via current
%                 colormap (default: empty → uniform marker color)
%   MarkerSize    Scatter marker area (default 36)
%   MarkerColor   Uniform marker color when Values is empty (default [0 0.45 0.74])
%   Title         Axes title string (default '')
%   Grid          Draw internal gridlines at 10% intervals (default true)
%   ShowTriangle  Draw the bounding triangle (default true)
%   LineWidth     Triangle outline width (default 1.5)
%
% Output
%   ax   Handle to the axes containing the plot
%
% Example
%   % Three-point alloy map with composition-colored markers
%   comp = [0.7 0.2 0.1;   % Fe-rich
%           0.3 0.4 0.3;
%           0.1 0.1 0.8];  % Cr-rich
%   hardness = [180; 250; 320];
%   plotting.ternaryPlot(comp, 'Values', hardness, ...
%       'Labels', {'Fe','Ni','Cr'}, 'Title', 'Vickers hardness (HV)');
%   colorbar;
%
% See also: plotting.polarPlot, plotting.colorScatterZ

arguments
    fractions (:,3) double {mustBeReal}
    options.Parent = []
    options.Labels (1,3) string = ["A","B","C"]
    options.Values double = []
    options.MarkerSize (1,1) double {mustBePositive} = 36
    options.MarkerColor (1,3) double = [0 0.45 0.74]
    options.Title string = ""
    options.Grid (1,1) logical = true
    options.ShowTriangle (1,1) logical = true
    options.LineWidth (1,1) double {mustBePositive} = 1.5
end

if any(fractions(:) < 0, 'all')
    error('plotting:ternaryPlot:negativeFraction', ...
        'Fractions must be non-negative.');
end

% Normalize each row to sum = 1
rowSums = sum(fractions, 2);
if any(rowSums == 0)
    error('plotting:ternaryPlot:zeroRow', ...
        'All-zero rows are not valid compositions.');
end
F = fractions ./ rowSums;

% Barycentric → Cartesian
A = [0, 0];
B = [1, 0];
C = [0.5, sqrt(3)/2];
xy = F(:,1) * A + F(:,2) * B + F(:,3) * C;

% Target axes
if isempty(options.Parent)
    ax = gca;
else
    ax = options.Parent;
end
hold(ax, 'on');
axis(ax, 'equal');
axis(ax, 'off');
xlim(ax, [-0.08, 1.08]);
ylim(ax, [-0.08, sqrt(3)/2 + 0.12]);

% Internal gridlines at 10% intervals (before triangle so triangle overlays)
if options.Grid
    gridColor = [0.78 0.78 0.78];
    for t = 0.1:0.1:0.9
        % Line of constant a: from (t·B + (1-t)·C) to (t·A + (1-t)·C)? No —
        % constant a=t means fractions [t, s, 1-t-s] for s∈[0, 1-t]. The
        % locus is a line segment parallel to the side BC.
        %
        % For each corner's "constant fraction" line, interpolate between
        % the two edges that don't touch that corner.
        %   Constant a = t: endpoints on sides AB (b = 1-t, c = 0)
        %                                  and AC (b = 0, c = 1-t)
        pA1 = t*A + (1-t)*B;        % b = 1-t, c = 0
        pA2 = t*A + (1-t)*C;        % b = 0,   c = 1-t
        pB1 = t*B + (1-t)*A;
        pB2 = t*B + (1-t)*C;
        pC1 = t*C + (1-t)*A;
        pC2 = t*C + (1-t)*B;
        plot(ax, [pA1(1) pA2(1)], [pA1(2) pA2(2)], ...
            'Color', gridColor, 'LineWidth', 0.5, 'HandleVisibility', 'off');
        plot(ax, [pB1(1) pB2(1)], [pB1(2) pB2(2)], ...
            'Color', gridColor, 'LineWidth', 0.5, 'HandleVisibility', 'off');
        plot(ax, [pC1(1) pC2(1)], [pC1(2) pC2(2)], ...
            'Color', gridColor, 'LineWidth', 0.5, 'HandleVisibility', 'off');
    end
end

% Triangle outline
if options.ShowTriangle
    tri = [A; B; C; A];
    plot(ax, tri(:,1), tri(:,2), 'k-', 'LineWidth', options.LineWidth, ...
        'HandleVisibility', 'off');
end

% Vertex labels
text(ax, A(1) - 0.03, A(2) - 0.04, options.Labels(1), ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontWeight', 'bold', 'FontSize', 12);
text(ax, B(1) + 0.03, B(2) - 0.04, options.Labels(2), ...
    'HorizontalAlignment', 'left',  'VerticalAlignment', 'top', ...
    'FontWeight', 'bold', 'FontSize', 12);
text(ax, C(1),        C(2) + 0.04, options.Labels(3), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontWeight', 'bold', 'FontSize', 12);

% Scatter the data
if isempty(options.Values)
    scatter(ax, xy(:,1), xy(:,2), options.MarkerSize, ...
        options.MarkerColor, 'filled', 'MarkerEdgeColor', 'k');
else
    assert(numel(options.Values) == size(fractions, 1), ...
        'plotting:ternaryPlot:sizeMismatch', ...
        'Values length (%d) must match number of rows in fractions (%d).', ...
        numel(options.Values), size(fractions, 1));
    scatter(ax, xy(:,1), xy(:,2), options.MarkerSize, ...
        options.Values(:), 'filled', 'MarkerEdgeColor', 'k');
end

if strlength(options.Title) > 0
    title(ax, char(options.Title));
end

hold(ax, 'off');
end
