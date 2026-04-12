function map2DHandle = draw2DMap(targetAx, ds, map2DHandleIn, wgts)
%DRAW2DMAP  Render a 2D area-detector intensity map into targetAx.
%   Uses imagesc (Heatmap) or contour/contourf (Contour / Filled Contour).
%   ddMap2DScale is used for log-intensity toggle for 2D maps.
%   Axis limits from ds.axLims are applied when present.
%   Large maps are stride-decimated for faster rendering.
%
%   Syntax:
%     map2DHandle = bosonPlotter.draw2DMap(targetAx, ds, map2DHandleIn, wgts)
%
%   Inputs:
%     targetAx       - axes handle to render into
%     ds             - dataset struct (must be a 2D dataset)
%     map2DHandleIn  - current appData.map2DHandle ([] if none)
%     wgts           - widget struct with fields:
%                        .cbMap2DQSpace   - checkbox: show in Q-space
%                        .ddMap2DScale    - dropdown: 'Linear' or 'Log₁₀'
%                        .ddMap2DCmap     - dropdown: colormap name
%                        .ddMap2DType     - dropdown: 'Heatmap', 'Contour', 'Filled Contour'
%                        .efMap2DContourN - numeric editfield: number of contour levels
%                        .efMap2DCMin     - text editfield: colorbar min (text)
%                        .efMap2DCMax     - text editfield: colorbar max (text)
%                        .appearance      - struct from resolveActiveAppearance()
%
%   Outputs:
%     map2DHandle  - updated graphics handle for the rendered image/surface
%                   ([] for contour modes; caller stores in appData.map2DHandle)
%
%   Examples:
%     wgts.cbMap2DQSpace = cbMap2DQSpace;
%     wgts.ddMap2DScale  = ddMap2DScale;
%     % ... fill remaining fields ...
%     appData.map2DHandle = bosonPlotter.draw2DMap(ax, ds, appData.map2DHandle, wgts);

    ps  = ds.data.metadata.parserSpecific;
    map = ps.map2D;
    I   = double(map.intensity);   % ensure double for rendering (supports single storage)

    x2 = map.axis2(:)';  % 2Theta [1×M]
    x1 = map.axis1(:);   % Omega / Chi / Phi [N×1]

    % ── Stride-based decimation for very large maps ──
    % Skip every Nth pixel when the display resolution exceeds the screen.
    % This avoids rendering millions of pixels that would be subsampled anyway.
    MAX_DISPLAY_PIX = 2000;  % max pixels per axis before decimation
    [nRows, nCols] = size(I);
    strideR = max(1, ceil(nRows / MAX_DISPLAY_PIX));
    strideC = max(1, ceil(nCols / MAX_DISPLAY_PIX));
    if strideR > 1 || strideC > 1
        rIdx = 1:strideR:nRows;
        cIdx = 1:strideC:nCols;
        I  = I(rIdx, cIdx);
        x1 = x1(rIdx);
        x2 = x2(cIdx);
    end

    % Determine whether to render in Q-space (non-uniform Qx/Qz grid)
    useQSpace = wgts.cbMap2DQSpace.Value && isfield(map, 'Qx');
    if useQSpace
        Xmat = map.Qx;   % [N×M]  Qx grid
        Ymat = map.Qz;   % [N×M]  Qz grid
        if strideR > 1 || strideC > 1
            Xmat = Xmat(rIdx, cIdx);
            Ymat = Ymat(rIdx, cIdx);
        end
        xLbl = 'Q_x (Å^{-1})';
        yLbl = 'Q_z (Å^{-1})';
    else
        xLbl = [map.axis2Name ' (' map.axis2Unit ')'];
        yLbl = [map.axis1Name ' (' map.axis1Unit ')'];
        % Defer meshgrid — only needed for Contour modes, not Heatmap.
        % imagesc uses the axis vectors directly, avoiding two [N×M]
        % temporary matrices on every replot.
        Xmat = [];  Ymat = [];
    end

    % Log intensity — use dedicated 2D scale dropdown (ddMap2DScale)
    useLogI = strcmp(wgts.ddMap2DScale.Value, 'Log₁₀');
    if useLogI
        I = log10(max(I, 1e-9));
    end

    % Per-axes colormap — use the dedicated 2D color scale dropdown
    cmapName = wgts.ddMap2DCmap.Value;
    try
        switch lower(cmapName)
            case 'viridis'
                colormap(targetAx, bosonPlotter.colorMaps('viridis', 256));
            case 'plasma'
                colormap(targetAx, bosonPlotter.colorMaps('plasma', 256));
            case 'inferno'
                colormap(targetAx, bosonPlotter.colorMaps('inferno', 256));
            otherwise
                colormap(targetAx, feval(cmapName, 256));
        end
    catch
        colormap(targetAx, parula(256));
    end

    nLvl = round(wgts.efMap2DContourN.Value);
    % Try to reuse a cached graphics handle for Heatmap replots (faster)
    h2D = map2DHandleIn;
    map2DHandle = [];
    canReuse = ~isempty(h2D) && isvalid(h2D) && strcmp(wgts.ddMap2DType.Value, 'Heatmap');
    switch wgts.ddMap2DType.Value
        case 'Heatmap'
            if useQSpace
                if canReuse && isa(h2D, 'matlab.graphics.chart.primitive.Surface')
                    h2D.XData = Xmat;  h2D.YData = Ymat;  h2D.CData = I;
                    map2DHandle = h2D;
                else
                    pcolor(targetAx, Xmat, Ymat, I);
                    shading(targetAx, 'flat');
                    map2DHandle = targetAx.Children(1);
                end
            else
                if canReuse && isa(h2D, 'matlab.graphics.primitive.Image')
                    h2D.XData = [x2(1) x2(end)];
                    h2D.YData = [x1(1) x1(end)];
                    h2D.CData = I;
                    map2DHandle = h2D;
                else
                    imagesc(targetAx, x2, x1, I);
                    targetAx.YDir = 'normal';
                    map2DHandle = targetAx.Children(1);
                end
            end
        case 'Contour'
            if isempty(Xmat), [Xmat, Ymat] = meshgrid(x2, x1); end
            contour(targetAx, Xmat, Ymat, I, nLvl);
            map2DHandle = [];
        otherwise  % 'Filled Contour'
            if isempty(Xmat), [Xmat, Ymat] = meshgrid(x2, x1); end
            contourf(targetAx, Xmat, Ymat, I, nLvl);
            map2DHandle = [];
    end

    % Apply colorbar range limits from the editor controls
    cMin = str2double(wgts.efMap2DCMin.Value);
    cMax = str2double(wgts.efMap2DCMax.Value);
    if ~isnan(cMin) && ~isnan(cMax) && cMax > cMin
        clim(targetAx, [cMin cMax]);
    elseif ~isnan(cMin)
        cl = clim(targetAx);  clim(targetAx, [cMin cl(2)]);
    elseif ~isnan(cMax)
        cl = clim(targetAx);  clim(targetAx, [cl(1) cMax]);
    end

    % Colorbar with intensity unit label
    if useLogI
        cbStr = ['log_{10}(I / ' map.intensityUnit ')'];
    else
        cbStr = ['I (' map.intensityUnit ')'];
    end
    cbh = colorbar(targetAx);
    cbh.Label.String      = cbStr;
    cbh.Label.Interpreter = 'tex';

    xlabel(targetAx, xLbl, 'Interpreter', 'tex');
    ylabel(targetAx, yLbl, 'Interpreter', 'tex');

    % Title: sample name or filename
    sName = '';
    if isfield(ps, 'sampleName') && ~isempty(ps.sampleName)
        sName = ps.sampleName;
    end
    if isempty(sName)
        [~, fn, fext] = fileparts(ds.filepath);
        sName = [fn fext];
    end
    title(targetAx, sName, 'Interpreter', 'none');

    % ── Apply active template's axes-level properties ────────────────
    % 2D maps are rendered with imagesc / contourf which don't have
    % the "line width / marker size" concept — but they do have axes
    % typography, tick direction, box, and grid that should match
    % the main preview so switching the Template dropdown propagates
    % to the 2D heatmap as well.  The colorbar is a second axes with
    % its own FontName, TickDirection, TickLength, and Label font.
    try
        appr2D = wgts.appearance;
        bosonPlotter.applyAppearanceToAxes(targetAx, appr2D);
        if exist('cbh', 'var') && ~isempty(cbh) && isvalid(cbh)
            bosonPlotter.applyAppearanceToColorbar(cbh, appr2D);
        end
    catch
        % Never let a styling failure break the map render
    end

    % Restore saved axis limits if present
    if isfield(ds, 'axLims')
        aL  = ds.axLims;
        xlo = str2num_trim(aL.xMin);  xhi = str2num_trim(aL.xMax);
        ylo = str2num_trim(aL.yMin);  yhi = str2num_trim(aL.yMax);
        if ~isnan(xlo) && ~isnan(xhi) && xhi > xlo
            targetAx.XLim = [xlo, xhi];
        end
        if ~isnan(ylo) && ~isnan(yhi) && yhi > ylo
            targetAx.YLim = [ylo, yhi];
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m — not accessible cross-file)
% ════════════════════════════════════════════════════════════════════════

function x = str2num_trim(s)
%STR2NUM_TRIM  Convert string to number, returning NaN for blank/invalid.
    x = str2double(s);
    if isnan(x), x = NaN; end
end
