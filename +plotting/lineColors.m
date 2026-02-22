function colors = lineColors(n, theme)
%LINECOLORS  Return N distinguishable RGB colours from the active theme.
%
%   colors = plotting.lineColors(n)
%   colors = plotting.lineColors(n, theme)
%
%   Returns an [Nx3] matrix of RGB row-vectors.  Colours are drawn from the
%   theme palette, cycling if N exceeds the palette length.  When no theme
%   is given, styles.default() is used.
%
%   INPUTS:
%       n     — number of colours required (positive integer)
%       theme — (optional) theme struct from styles.default().
%               Omit or pass [] to use styles.default().
%
%   OUTPUT:
%       colors — [Nx3] double, values in [0,1]
%
%   EXAMPLE:
%       cols = plotting.lineColors(3);
%       for k = 1:3
%           plot(x{k}, y{k}, 'Color', cols(k,:));
%           hold on;
%       end
%
%   See also styles.default, plotting.formatAxes

    arguments
        n     (1,1) double {mustBePositive, mustBeInteger}
        theme              = []
    end

    if isempty(theme)
        theme = styles.default();
    end

    palette  = theme.colors;
    nPalette = size(palette, 1);

    % Cycle through palette using modular indexing
    idx    = mod((0:n-1)', nPalette) + 1;
    colors = palette(idx, :);
end
