function onFringeMarkerUp(appData, fig, callbacks)
%ONFRINGEMARKERUP  Finish dragging a fringe marker and restore handlers.
%
% Syntax
%   bosonPlotter.onFringeMarkerUp(appData, fig, callbacks)
%
% Behaviour
%   Runs when the user releases the mouse after a fringe-marker drag.
%   Restores the default motion handler (`callbacks.onMouseHover`),
%   clears the figure's up handler, resets the cursor to an arrow, and
%   clears the active drag index so a later motion event is a no-op.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutates fringeDragIdx)
%   fig       - Main figure handle (window callback owner)
%   callbacks - Struct of function handles:
%                 .onMouseHover(src, evt)

    fig.WindowButtonMotionFcn = callbacks.onMouseHover;
    fig.WindowButtonUpFcn     = '';
    fig.Pointer               = 'arrow';
    appData.fringeDragIdx     = 0;
end
