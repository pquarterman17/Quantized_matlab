function onZoomMouseUp(appData, fig, ax, ui, callbacks)
%ONZOOMMOUSEUP  Apply zoom to the drawn rectangle, then clean up.
%
% Syntax
%   bosonPlotter.onZoomMouseUp(appData, fig, ax, ui, callbacks)
%
% Behaviour
%   Runs when the user releases the mouse after a drag-zoom.  Restores
%   the default motion handler (`callbacks.onMouseHover`), clears the
%   figure's up handler, removes the rubber-band patch, and only
%   applies the zoom if the drag covers at least 1% of the current
%   axis span in both X and Y.  For log-scale axes the comparison is
%   performed in log-space, so a few-decade drag is not rejected as
%   "too small".  On a valid zoom the `efXMin / efXMax / efYMin /
%   efYMax` fields in the supplied `ui` struct are updated, the limits
%   are persisted via `callbacks.saveAxisLimsToActiveDataset`, and the
%   plot is re-rendered via `callbacks.onPlot`.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutates zoomStartPt, zoomRectPatch)
%   fig       - Main figure handle (window callback owner)
%   ax        - Main axes handle
%   ui        - Widget struct with fields: efXMin, efXMax, efYMin, efYMax
%   callbacks - Struct of function handles:
%                 .onMouseHover(src, evt)
%                 .saveAxisLimsToActiveDataset()
%                 .onPlot()

    fig.WindowButtonMotionFcn = callbacks.onMouseHover;
    fig.WindowButtonUpFcn     = '';
    if isempty(appData.zoomStartPt)
        return;
    end
    cp = ax.CurrentPoint;
    x1 = cp(1,1);  y1 = cp(1,2);
    x0 = appData.zoomStartPt(1);
    y0 = appData.zoomStartPt(2);
    if ~isempty(appData.zoomRectPatch) && isvalid(appData.zoomRectPatch)
        delete(appData.zoomRectPatch);
    end
    appData.zoomRectPatch = [];
    appData.zoomStartPt   = [];

    % Minimum drag threshold — 1% of axis span (in log space for log axes,
    % so a several-decade drag isn't rejected as "too small").
    if strcmp(ax.XScale, 'log') && x0 > 0 && x1 > 0
        xDrag = abs(log10(x1) - log10(x0));
        xSpan = abs(log10(ax.XLim(2)) - log10(ax.XLim(1)));
    else
        xDrag = abs(x1 - x0);
        xSpan = diff(ax.XLim);
    end
    if strcmp(ax.YScale, 'log') && y0 > 0 && y1 > 0
        yDrag = abs(log10(y1) - log10(y0));
        ySpan = abs(log10(ax.YLim(2)) - log10(ax.YLim(1)));
    else
        yDrag = abs(y1 - y0);
        ySpan = diff(ax.YLim);
    end
    if xDrag < xSpan * 0.01 || yDrag < ySpan * 0.01
        return;
    end

    xLo = min(x0,x1);  xHi = max(x0,x1);
    yLo = min(y0,y1);  yHi = max(y0,y1);
    ui.efXMin.Value = sprintf('%.6g', xLo);
    ui.efXMax.Value = sprintf('%.6g', xHi);
    ui.efYMin.Value = sprintf('%.6g', yLo);
    ui.efYMax.Value = sprintf('%.6g', yHi);
    callbacks.saveAxisLimsToActiveDataset();
    callbacks.onPlot();
end
