function h = colorScatterZ(ax, x, y, z, Options)
%COLORSCATTERZ  Scatter plot with points coloured by a third variable Z.
%
%   Syntax:
%       h = plotting.colorScatterZ(ax, x, y, z)
%       h = plotting.colorScatterZ(ax, x, y, z, Colormap="plasma", ShowColorbar=true)
%
%   Inputs:
%       ax  — target axes handle
%       x   — [N×1] x-coordinates
%       y   — [N×1] y-coordinates
%       z   — [N×1] colour variable
%
%   Options (name-value):
%       MarkerSize     — scalar marker area in points^2  (default 20)
%       Colormap       — string name or [M×3] RGB matrix (default "viridis")
%                        Built-in names (no toolbox): "viridis", "plasma",
%                        "inferno", "magma", "cividis"
%       ColorLim       — [lo hi] colour axis limits       (default: auto)
%       ShowColorbar   — logical, add colorbar            (default true)
%       ColorbarLabel  — string label for the colorbar    (default "")
%       Marker         — marker symbol string             (default 'o')
%       Alpha          — marker face alpha 0–1            (default 0.7)
%       EdgeColor      — marker edge colour spec          (default 'none')
%
%   Output:
%       h — scatter graphics object
%
%   Examples:
%       fig = figure; ax = axes(fig);
%       x = randn(200,1); y = randn(200,1); z = x.^2 + y.^2;
%       plotting.colorScatterZ(ax, x, y, z, Colormap="viridis");
%
%   See also scatter, colormap, colorbar

arguments
    ax  (1,1) matlab.graphics.axis.Axes
    x   (:,1) double
    y   (:,1) double
    z   (:,1) double
    Options.MarkerSize    (1,1) double {mustBePositive}  = 20
    Options.Colormap                                     = "viridis"
    Options.ColorLim      (1,2) double                   = [NaN NaN]
    Options.ShowColorbar  (1,1) logical                  = true
    Options.ColorbarLabel (1,1) string                   = ""
    Options.Marker        (1,:) char                     = 'o'
    Options.Alpha         (1,1) double {mustBeNonnegative, mustBeLessThanOrEqual(Options.Alpha,1)} = 0.7
    Options.EdgeColor                                    = 'none'
end

% ════════════════════════════════════════════════════════════════════════
%  Validate inputs
% ════════════════════════════════════════════════════════════════════════
n = numel(x);
if numel(y) ~= n || numel(z) ~= n
    error('colorScatterZ:sizeMismatch', 'x, y, and z must have the same number of elements.');
end

% ════════════════════════════════════════════════════════════════════════
%  Apply colormap
% ════════════════════════════════════════════════════════════════════════
cmap = resolveColormap(Options.Colormap);
colormap(ax, cmap);

% ════════════════════════════════════════════════════════════════════════
%  Draw scatter
% ════════════════════════════════════════════════════════════════════════
hold(ax, 'on');

h = scatter(ax, x, y, Options.MarkerSize, z, 'filled', ...
    'Marker',          Options.Marker, ...
    'MarkerFaceAlpha', Options.Alpha, ...
    'MarkerEdgeColor', Options.EdgeColor);

% ════════════════════════════════════════════════════════════════════════
%  Colour axis limits
% ════════════════════════════════════════════════════════════════════════
zFinite = z(isfinite(z));
if ~isempty(zFinite)
    if isnan(Options.ColorLim(1))
        clo = min(zFinite);
    else
        clo = Options.ColorLim(1);
    end
    if isnan(Options.ColorLim(2))
        chi = max(zFinite);
    else
        chi = Options.ColorLim(2);
    end
    % Guard against flat colour range
    if clo == chi
        clo = clo - 1;
        chi = chi + 1;
    end
    clim(ax, [clo chi]);
end

% ════════════════════════════════════════════════════════════════════════
%  Colorbar
% ════════════════════════════════════════════════════════════════════════
if Options.ShowColorbar
    cb = colorbar(ax);
    if strlength(Options.ColorbarLabel) > 0
        cb.Label.String = Options.ColorbarLabel;
    end
end

end  % colorScatterZ

% ════════════════════════════════════════════════════════════════════════
%  LOCAL: Resolve colormap name to [M×3] RGB array (no toolbox required)
% ════════════════════════════════════════════════════════════════════════
function cmap = resolveColormap(spec)
%RESOLVECOLORMAP  Return a 256-row RGB colormap from a name or matrix.

if isnumeric(spec)
    % Caller supplied a custom [M×3] matrix — use directly
    cmap = spec;
    return;
end

name = lower(string(spec));

switch name
    case "viridis"
        % Viridis control points (perceptually uniform, colour-blind safe)
        ctrl = [ ...
            0.267  0.005  0.329; ...
            0.283  0.141  0.458; ...
            0.254  0.265  0.530; ...
            0.207  0.372  0.553; ...
            0.164  0.471  0.558; ...
            0.128  0.567  0.551; ...
            0.135  0.659  0.518; ...
            0.267  0.749  0.441; ...
            0.478  0.821  0.318; ...
            0.741  0.873  0.150; ...
            0.993  0.906  0.144];

    case "plasma"
        ctrl = [ ...
            0.050  0.030  0.528; ...
            0.238  0.017  0.580; ...
            0.399  0.003  0.600; ...
            0.542  0.019  0.580; ...
            0.668  0.086  0.524; ...
            0.772  0.179  0.437; ...
            0.863  0.271  0.339; ...
            0.934  0.374  0.234; ...
            0.977  0.490  0.122; ...
            0.990  0.619  0.017; ...
            0.940  0.975  0.131];

    case "inferno"
        ctrl = [ ...
            0.000  0.000  0.014; ...
            0.093  0.026  0.209; ...
            0.239  0.029  0.419; ...
            0.387  0.030  0.476; ...
            0.536  0.057  0.449; ...
            0.673  0.130  0.375; ...
            0.793  0.226  0.269; ...
            0.889  0.352  0.146; ...
            0.955  0.503  0.031; ...
            0.984  0.669  0.051; ...
            0.988  0.998  0.645];

    case "magma"
        ctrl = [ ...
            0.000  0.000  0.016; ...
            0.079  0.043  0.209; ...
            0.219  0.047  0.418; ...
            0.368  0.050  0.488; ...
            0.517  0.077  0.499; ...
            0.659  0.131  0.475; ...
            0.793  0.203  0.412; ...
            0.908  0.302  0.315; ...
            0.974  0.459  0.275; ...
            0.993  0.648  0.430; ...
            0.987  0.991  0.750];

    case "cividis"
        ctrl = [ ...
            0.000  0.135  0.304; ...
            0.119  0.172  0.359; ...
            0.223  0.210  0.397; ...
            0.321  0.251  0.417; ...
            0.415  0.295  0.424; ...
            0.506  0.341  0.423; ...
            0.596  0.393  0.407; ...
            0.688  0.454  0.370; ...
            0.782  0.524  0.308; ...
            0.876  0.604  0.221; ...
            0.963  0.694  0.122];

    otherwise
        % Fall back to MATLAB built-in if name is not one of ours
        try
            cmap = feval(char(name), 256);
        catch
            warning('colorScatterZ:unknownColormap', ...
                'Unknown colormap "%s". Falling back to viridis.', name);
            cmap = resolveColormap("viridis");
        end
        return;
end

% Interpolate control points to 256 levels
nCtrl = size(ctrl, 1);
t     = linspace(0, 1, nCtrl);
tOut  = linspace(0, 1, 256);
cmap  = [ ...
    interp1(t, ctrl(:,1), tOut, 'pchip'); ...
    interp1(t, ctrl(:,2), tOut, 'pchip'); ...
    interp1(t, ctrl(:,3), tOut, 'pchip')]';
cmap  = max(0, min(1, cmap));   % clamp to [0,1]

end
