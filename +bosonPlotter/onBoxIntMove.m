function onBoxIntMove(appData, ax)
%ONBOXINTMOVE  Update the box-integration rubber-band rectangle while dragging.
%
% Syntax
%   bosonPlotter.onBoxIntMove(appData, ax)
%
% Behaviour
%   Installed as the figure's `WindowButtonMotionFcn` while box-integration
%   selection is in progress on a 2D map.  Updates the existing
%   `appData.boxIntPatch` in place, or creates a new dashed-purple patch
%   (`Tag='GUIBoxIntBox'`) if one does not exist yet.  The dashed style
%   is deliberately distinct from the solid-green "completed box"
%   marker drawn by onBoxIntUp, so users can tell in-progress vs
%   finalised selections apart.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads boxIntStartPt;
%                 mutates boxIntPatch)
%   ax        - Main axes handle (reads CurrentPoint)

    if isempty(appData.boxIntStartPt), return; end
    cp = ax.CurrentPoint;
    x1 = max(ax.XLim(1), min(ax.XLim(2), cp(1,1)));
    y1 = max(ax.YLim(1), min(ax.YLim(2), cp(1,2)));
    x0 = appData.boxIntStartPt(1);
    y0 = appData.boxIntStartPt(2);
    xLo = min(x0, x1);  xHi = max(x0, x1);
    yLo = min(y0, y1);  yHi = max(y0, y1);
    if ~isempty(appData.boxIntPatch) && isvalid(appData.boxIntPatch)
        set(appData.boxIntPatch, ...
            'XData', [xLo xHi xHi xLo xLo], ...
            'YData', [yLo yLo yHi yHi yLo]);
    else
        hold(ax, 'on');
        appData.boxIntPatch = patch(ax, ...
            [xLo xHi xHi xLo xLo], [yLo yLo yHi yHi yLo], ...
            'k', ...
            'FaceAlpha',       0, ...
            'EdgeColor',       [0.65 0.20 0.85], ...
            'LineStyle',       '--', ...
            'LineWidth',       2.5, ...
            'Tag',             'GUIBoxIntBox', ...
            'HandleVisibility','off');
        hold(ax, 'off');
    end
end
