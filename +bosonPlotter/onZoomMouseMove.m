function onZoomMouseMove(appData, ax)
%ONZOOMMOUSEMOVE  Update the rubber-band rectangle while dragging.
%
% Syntax
%   bosonPlotter.onZoomMouseMove(appData, ax)
%
% Behaviour
%   Installed as the figure's `WindowButtonMotionFcn` while a drag-zoom
%   is in progress.  Computes the current rubber-band rectangle from
%   the stored `appData.zoomStartPt` and the axes' `CurrentPoint`.  If
%   a rectangle patch already exists (`appData.zoomRectPatch`), its
%   XData/YData are updated in place; otherwise a new translucent blue
%   patch is created with `HandleVisibility='off'` and
%   `Tag='GUIZoomBox'`.  Exits early if no start point has been
%   recorded (should not happen in normal flow).
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads zoomStartPt;
%                 mutates zoomRectPatch)
%   ax        - Main axes handle (reads CurrentPoint)

    if isempty(appData.zoomStartPt), return; end
    cp = ax.CurrentPoint;
    x1 = cp(1,1);  y1 = cp(1,2);
    x0 = appData.zoomStartPt(1);
    y0 = appData.zoomStartPt(2);
    xLo = min(x0, x1);  xHi = max(x0, x1);
    yLo = min(y0, y1);  yHi = max(y0, y1);
    if ~isempty(appData.zoomRectPatch) && isvalid(appData.zoomRectPatch)
        set(appData.zoomRectPatch, ...
            'XData', [xLo xHi xHi xLo xLo], ...
            'YData', [yLo yLo yHi yHi yLo]);
    else
        hold(ax, 'on');
        appData.zoomRectPatch = patch(ax, ...
            [xLo xHi xHi xLo xLo], [yLo yLo yHi yHi yLo], ...
            [0.20 0.55 0.90], ...
            'FaceAlpha',       0.12, ...
            'EdgeColor',       [0.20 0.55 0.90], ...
            'LineWidth',       1.5, ...
            'Tag',             'GUIZoomBox', ...
            'HandleVisibility','off');
        hold(ax, 'off');
    end
end
