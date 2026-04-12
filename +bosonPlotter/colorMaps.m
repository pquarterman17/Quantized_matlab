function colors = colorMaps(colormapName, nColors)
%COLORMAPS  Generate nColors from a named colormap (no GUI dependencies).
%
% Syntax
% ------
%   colors = bosonPlotter.colorMaps(colormapName, nColors)
%
% Inputs
% ------
%   colormapName  (char) Name of the colormap. Supported values:
%                   Built-in MATLAB colormaps: 'parula', 'hot', 'jet',
%                     'turbo', 'gray', 'bone', 'copper', 'cool', 'spring',
%                     'summer', 'autumn', 'winter', and any other name
%                     accepted by feval(name, 256).
%                   Custom perceptual colormaps: 'viridis', 'plasma', 'inferno'.
%                   Special alias: 'lines (MATLAB default)' returns lines(nColors).
%   nColors       (positive integer) Number of distinct colours to sample.
%
% Outputs
% -------
%   colors  [nColors×3] double — RGB values in [0, 1]. Sampled evenly
%           across the full colormap range.
%
% Examples
% --------
%   % Get 8 colours from viridis for a waterfall plot
%   c = bosonPlotter.colorMaps('viridis', 8);
%   for k = 1:8
%       plot(x, y(:,k), 'Color', c(k,:));
%   end
%
%   % Jet colormap, 12 colours
%   c = bosonPlotter.colorMaps('jet', 12);

    if strcmpi(colormapName, 'lines (MATLAB default)')
        colors = lines(nColors);
        return;
    end

    cmName = lower(strrep(colormapName, ' ', ''));

    switch cmName
        case {'viridis','plasma','inferno'}
            colors = generateCustom(cmName, nColors);
        otherwise
            colors = sampleBuiltin(cmName, nColors);
    end
end

function colors = sampleBuiltin(mapName, nColors)
    try
        cmap = feval(mapName, 256);
        indices = round(linspace(1, 256, nColors));
        colors = cmap(indices, :);
    catch
        colors = lines(nColors);
    end
end

function colors = generateCustom(name, nColors)
    if nColors == 1
        switch name
            case 'viridis', colors = [0.267 0.004 0.329];
            case 'plasma',  colors = [0.050 0.030 0.529];
            case 'inferno', colors = [0.001 0.001 0.014];
        end
        return;
    end
    t = linspace(0, 1, nColors)';
    switch name
        case 'viridis'
            r = interp1([0 1], [0.267 0.993], t, 'pchip');
            g = interp1([0 0.5 1], [0.004 0.906 0.906], t, 'pchip');
            b = interp1([0 0.5 1], [0.329 0.145 0.023], t, 'pchip');
        case 'plasma'
            r = interp1([0 0.5 1], [0.050 0.940 0.940], t, 'pchip');
            g = interp1([0 0.5 1], [0.030 0.098 0.906], t, 'pchip');
            b = interp1([0 0.5 1], [0.529 0.208 0.145], t, 'pchip');
        case 'inferno'
            r = interp1([0 0.5 1], [0.001 0.283 0.988], t, 'pchip');
            g = interp1([0 0.5 1], [0.001 0.075 0.998], t, 'pchip');
            b = interp1([0 0.5 1], [0.014 0.612 0.120], t, 'pchip');
    end
    colors = max(0, min(1, [r, g, b]));
end
