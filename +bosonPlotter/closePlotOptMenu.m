function closePlotOptMenu(appData)
%CLOSEPLOTOPTMENU  Dismiss the Plot Options popup if it is open.
%
% Syntax
%   bosonPlotter.closePlotOptMenu(appData)
%
% Behaviour
%   Idempotent.  Deletes `appData.plotOptFig` if it is a valid handle,
%   then clears the stored reference so the next call to
%   `bosonPlotter.showPlotOptionsMenu` opens a fresh popup.
%
% Inputs
%   appData - bosonPlotter.AppState handle (reads/mutates plotOptFig)

    if ~isempty(appData.plotOptFig) && isvalid(appData.plotOptFig)
        delete(appData.plotOptFig);
    end
    appData.plotOptFig = [];
end
