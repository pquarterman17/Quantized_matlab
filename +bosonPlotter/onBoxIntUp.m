function onBoxIntUp(appData, fig, ax, callbacks)
%ONBOXINTUP  Finalise a box-integration drag on the 2D map.
%
% Syntax
%   bosonPlotter.onBoxIntUp(appData, fig, ax, callbacks)
%
% Behaviour
%   Companion to `bosonPlotter.onBoxIntMove`.  Restores the default
%   motion/up handlers first — uifigure event routing otherwise leaves
%   callbacks in a half-registered state that breaks the next box-draw
%   attempt.  Then:
%     * Aborts cleanly if no drag was in progress (empty start point).
%     * Drops the rubber-band patch when the drag spans <1% of either
%       axis (classifies as a click, not a real box).
%     * On a valid drag, promotes the rubber-band to a solid green
%       "completed box" marker (tag 'GUIBoxIntCompleted') that survives
%       until the next integration, dataset switch, or Reset View.
%       Records the region in appData.boxIntCompletedRegion so the
%       marker can be re-drawn after cla() during renderPlot.
%     * Calls the supplied `extract2DBoxIntegral` callback with the
%       final corner coordinates to produce the integrated profile.
%
% Inputs
%   appData    - bosonPlotter.AppState handle (mutates boxInt* fields)
%   fig        - Main figure handle (resets WindowButton{Motion,Up}Fcn)
%   ax         - Main axes handle (reads CurrentPoint, XLim/YLim)
%   callbacks  - Struct of function handles:
%                   .onMouseHover(src,evt)        - restored as motion fcn
%                   .clearCompletedBoxPatch()     - erase prior marker
%                   .extract2DBoxIntegral(x0,y0,x1,y1)

    % Always restore default motion/up handlers FIRST so later
    % modal dialogs don't leave callbacks in a half-registered
    % state. This is a documented uifigure quirk that caused the
    % second box-draw to register motion incorrectly.
    fig.WindowButtonMotionFcn = callbacks.onMouseHover;
    fig.WindowButtonUpFcn     = '';
    if isempty(appData.boxIntStartPt)
        return;
    end
    cp = ax.CurrentPoint;
    x1 = max(ax.XLim(1), min(ax.XLim(2), cp(1,1)));
    y1 = max(ax.YLim(1), min(ax.YLim(2), cp(1,2)));
    x0 = appData.boxIntStartPt(1);
    y0 = appData.boxIntStartPt(2);

    % Detach the rubber-band handle before clearing state; we may
    % promote it to a completed-box marker below.
    dragPatch             = appData.boxIntPatch;
    appData.boxIntPatch   = [];
    appData.boxIntStartPt = [];
    appData.boxIntMode    = false;

    % Minimum drag threshold (1% of axis span in both directions)
    xDrag = abs(x1 - x0);  xSpan = diff(ax.XLim);
    yDrag = abs(y1 - y0);  ySpan = diff(ax.YLim);
    if xDrag < xSpan * 0.01 || yDrag < ySpan * 0.01
        % Drag was too small to be a real box — drop the rubber-band
        if ~isempty(dragPatch) && isvalid(dragPatch)
            delete(dragPatch);
        end
        return;
    end

    % Promote the rubber-band to the "completed box" style (solid
    % green edge) and keep it visible. A previous completed box, if
    % any, is replaced so only the most-recent integration is marked.
    callbacks.clearCompletedBoxPatch();
    if ~isempty(dragPatch) && isvalid(dragPatch)
        dragPatch.LineStyle = '-';
        dragPatch.EdgeColor = [0.15 0.65 0.30];
        dragPatch.LineWidth = 2.0;
        dragPatch.Tag       = 'GUIBoxIntCompleted';
        appData.boxIntCompletedPatch = dragPatch;
    end
    % Record the region coords so the marker can be re-drawn after
    % any plot refresh (renderPlot calls cla which wipes patches).
    appData.boxIntCompletedRegion = ...
        [min(x0,x1) max(x0,x1) min(y0,y1) max(y0,y1)];

    callbacks.extract2DBoxIntegral(x0, y0, x1, y1);
end
