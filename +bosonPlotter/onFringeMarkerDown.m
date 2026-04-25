function onFringeMarkerDown(markerIdx, appData, fig, ax, lbY, callbacks)
%ONFRINGEMARKERDOWN  Begin dragging a Kiessig-fringe marker along the curve.
%
% Syntax
%   bosonPlotter.onFringeMarkerDown(markerIdx, appData, fig, ax, lbY, callbacks)
%
% Sets the figure's WindowButtonMotion/Up handlers to the existing
% fringe-drag helpers (`bosonPlotter.onFringeMarkerMove`,
% `bosonPlotter.onFringeMarkerUp`) and switches the cursor to a hand
% pointer so the user can reposition the clicked marker.
%
% Inputs
%   markerIdx - 1 or 2; which marker is being grabbed
%   appData   - bosonPlotter.AppState handle (mutates fringeDragIdx)
%   fig       - figure handle (mutates Pointer + WindowButton callbacks)
%   ax        - main axes
%   lbY       - Y-trace listbox (passed through to onFringeMarkerMove)
%   callbacks - struct with:
%                 .updateFringeThickness(appData, ax, cbs2) — re-render
%                                                             on each drag
%                 .onMouseHover(~,~) — restored as Motion fn after release
%                 .setStatus(msg)    — used by updateFringeThickness

    appData.fringeDragIdx = markerIdx;

    % onFringeMarkerMove expects a 0-arg `updateFringeThickness` callback
    % (existing contract); wrap the package call so the signature matches.
    moveCb = struct('updateFringeThickness', ...
        @() bosonPlotter.updateFringeThickness(appData, ax, callbacks));
    upCb   = struct('onMouseHover', callbacks.onMouseHover);

    fig.WindowButtonMotionFcn = ...
        @(~,~) bosonPlotter.onFringeMarkerMove(appData, ax, lbY, moveCb);
    fig.WindowButtonUpFcn = ...
        @(~,~) bosonPlotter.onFringeMarkerUp(appData, fig, upCb);
    fig.Pointer = 'hand';
end
