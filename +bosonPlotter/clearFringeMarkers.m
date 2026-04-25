function clearFringeMarkers(appData, ax)
%CLEARFRINGEMARKERS  Remove Kiessig-fringe thickness markers and annotation.
%
% Syntax
%   bosonPlotter.clearFringeMarkers(appData, ax)
%
% Inputs
%   appData - bosonPlotter.AppState handle (resets fringeMarkers,
%             fringeAnnotation, fringeQ, fringeClickCount, fringeDragIdx)
%   ax      - main axes handle (graphics objects with tag GUIFringe* are
%             deleted)
%
% Notes
%   Pure subsystem teardown — used both by the explicit "clear fringe"
%   action and by `recreateFringeMarkers` (via reset semantics) when the
%   plot is rebuilt.

    delete(findall(ax, 'Tag', 'GUIFringeMarker'));
    delete(findall(ax, 'Tag', 'GUIFringeAnnotation'));
    delete(findall(ax, 'Tag', 'GUIFringeSpan'));
    appData.fringeMarkers    = [];
    appData.fringeAnnotation = [];
    appData.fringeQ          = [NaN NaN];
    appData.fringeClickCount = 0;
    appData.fringeDragIdx    = 0;
end
