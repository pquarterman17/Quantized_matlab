function tintedPath = loadTintedIcon(iconPath, rgb)
%LOADTINTEDICON  Return a path to an icon PNG with its strokes recoloured.
%
% Syntax
%   tintedPath = bosonPlotter.loadTintedIcon(iconPath, rgb)
%
% Inputs
%   iconPath  — full path to a source PNG (e.g. icons/bosonplotter/cursor.png)
%   rgb       — [1×3] target colour for the non-transparent pixels (0..1)
%
% Behaviour
%   The Lucide icons we use are baked at colour #333338 (dark grey) —
%   readable on light backgrounds, invisible on dark ones. Rather than
%   shipping two icon sets and switching at build time, we tint at
%   runtime: the source PNG's RGB channel is replaced with `rgb` while
%   the alpha channel (which carries the actual stroke shape) is
%   preserved. The result is written to a per-session cache directory
%   so subsequent calls with the same (iconPath, rgb) hit the cache.
%
%   If the source PNG can't be read (e.g. missing file) the function
%   returns the original iconPath so the toolbar still renders, just
%   with the un-tinted version.
%
% Cache layout
%   tempdir/bosonPlotterIcons/<sourceName>__<colorHex>.png
%   The cache is per-session (tempdir) so it doesn't pollute the repo.
%
% Inputs validation
%   rgb may be [0..1] floats (preferred) or [0..255] uint8 ints; if any
%   value > 1 the function rescales.

    tintedPath = iconPath;   % safe default
    if ~isfile(iconPath), return; end

    if any(rgb > 1)
        rgb = double(rgb) ./ 255;
    end

    % Cache directory + filename based on icon name + colour hex
    [~, baseName] = fileparts(iconPath);
    rgb255 = round(rgb * 255);
    colorHex = sprintf('%02x%02x%02x', rgb255(1), rgb255(2), rgb255(3));
    cacheDir = fullfile(tempdir, 'bosonPlotterIcons');
    if ~isfolder(cacheDir)
        try
            mkdir(cacheDir);
        catch
            return;   % can't write cache; fall back to source
        end
    end
    cachedFile = fullfile(cacheDir, [baseName '__' colorHex '.png']);
    if isfile(cachedFile)
        tintedPath = cachedFile;
        return;
    end

    % Load source PNG (RGB + alpha) and rebuild with new RGB
    try
        [img, ~, alpha] = imread(iconPath);
    catch
        return;   % can't read; fall back to source
    end
    if isempty(alpha)
        % No alpha — derive a soft mask from luminance: darker pixels
        % become opaque, light pixels become transparent. Lucide icons
        % rasterised at #333338 on transparent BG should have alpha;
        % this branch handles non-Lucide icons gracefully.
        gray = double(rgb2gray(img));
        alpha = uint8(255 - gray);   % darker source → more opaque tint
    end

    h = size(img, 1);
    w = size(img, 2);
    tinted = zeros(h, w, 3, 'uint8');
    tinted(:,:,1) = uint8(rgb(1) * 255);
    tinted(:,:,2) = uint8(rgb(2) * 255);
    tinted(:,:,3) = uint8(rgb(3) * 255);

    try
        imwrite(tinted, cachedFile, 'Alpha', alpha);
        tintedPath = cachedFile;
    catch
        % Write failed — fall back to source path
    end
end
