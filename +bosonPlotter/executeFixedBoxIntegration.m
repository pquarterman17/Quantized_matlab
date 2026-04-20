function executeFixedBoxIntegration(appData, ax, cx, cy, callbacks)
%EXECUTEFIXEDBOXINTEGRATION  Place a fixed-size box centred at (cx,cy) and integrate.
%
% Syntax
%   bosonPlotter.executeFixedBoxIntegration(appData, ax, cx, cy, callbacks)
%
% Behaviour
%   Draws a fixed-size integration box centred at (cx, cy) on the 2D map
%   and extracts the integrated profile.  The box dimensions come from
%   `callbacks.hasFixedBoxSize`; Inf in either dimension (from an
%   "all"/":"/"*" keyword on the size input) is resolved to the active
%   map's full axis1/axis2 extent so "full range" means the real data
%   span, not whatever slice the user has zoomed into.
%
%   The overlay is styled as the completed-box marker (solid green edge)
%   and the coordinates are recorded on appData so the marker can be
%   re-drawn after any plot refresh that calls `cla`.
%
% Inputs
%   appData    - bosonPlotter.AppState handle (mutates boxIntCompleted*)
%   ax         - Main axes handle (parent of the overlay patch)
%   cx, cy     - Centre coordinates in axes units
%   callbacks  - Struct of sibling function handles:
%                  .clearBoxPreview()              - erase any in-flight preview
%                  .hasFixedBoxSize()              - [tf, boxW, boxH]
%                  .clearCompletedBoxPatch()       - erase prior marker
%                  .extract2DBoxIntegral(x0,y0,x1,y1) - run the integration

    callbacks.clearBoxPreview();
    [~, boxW, boxH] = callbacks.hasFixedBoxSize();
    if isinf(boxW) || isinf(boxH)
        map = appData.datasets{appData.activeIdx}.data.metadata.parserSpecific.map2D;
    end
    if isinf(boxW)
        xLo = min(map.axis2(:));  xHi = max(map.axis2(:));
    else
        hw = boxW / 2;
        xLo = cx - hw;  xHi = cx + hw;
    end
    if isinf(boxH)
        yLo = min(map.axis1(:));  yHi = max(map.axis1(:));
    else
        hh = boxH / 2;
        yLo = cy - hh;  yHi = cy + hh;
    end

    % Draw overlay showing the fixed-size box and keep it visible as
    % the "completed box" marker for this integration.
    callbacks.clearCompletedBoxPatch();
    hold(ax, 'on');
    hBoxOverlay = patch(ax, ...
        [xLo xHi xHi xLo xLo], [yLo yLo yHi yHi yLo], ...
        'k', ...
        'FaceAlpha',       0, ...
        'EdgeColor',       [0.15 0.65 0.30], ...
        'LineStyle',       '-', ...
        'LineWidth',       2.0, ...
        'Tag',             'GUIBoxIntCompleted', ...
        'HandleVisibility','off');
    hold(ax, 'off');
    drawnow;
    appData.boxIntCompletedPatch  = hBoxOverlay;
    appData.boxIntCompletedRegion = [xLo xHi yLo yHi];

    callbacks.extract2DBoxIntegral(xLo, yLo, xHi, yHi);
end
