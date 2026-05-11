function copyPlotWithFormat(appData, fig, mode, callbacks)
%COPYPLOTWITHFORMAT  Shared render + copy pipeline for clipboard export.
%
% Syntax
%   bosonPlotter.copyPlotWithFormat(appData, fig, mode, callbacks)
%
% Behaviour
%   Spins up a transient off-screen `figure` so the live BosonPlotter
%   axes are not disturbed, re-renders the current plot via the
%   supplied `drawToAxes` callback, then stripes the dark-theme
%   background (Color='none' on figure and axes) and applies
%   `bosonPlotter.styleAxesForExport` for readability before handing
%   the offscreen axes to `copygraphics`.  Two modes are supported:
%     mode = 'vector' — `ContentType='vector'`, best for Word /
%                       Illustrator / Origin / most email clients.
%     mode = 'png'    — `ContentType='image'`, 300 dpi, for apps that
%                       mangle the vector clipboard format (MS Teams,
%                       some Slack clients, older OneNote).
%   On failure, the offscreen figure is disposed of and the error is
%   funnelled through the `logGUIError` callback and a `uialert`.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads datasets / activeIdx)
%   fig       - Main figure handle (uialert parent)
%   mode      - 'vector' or 'png' (case-insensitive)
%   callbacks - Struct of function handles:
%                 .drawToAxes(targetAx)  - render current state onto targetAx
%                 .logGUIError(title, msg, ME)

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig, 'Load a file first.', 'No data');
        return;
    end
    tmpFig = figure('Visible', 'off', ...
                    'Name', 'ClipboardCopy', 'NumberTitle', 'off', ...
                    'MenuBar', 'none', 'ToolBar', 'none', ...
                    'Color', 'none', ...
                    'Units', 'inches', 'Position', [0 0 8 6]);
    tmpAx = axes(tmpFig);
    set(tmpAx, 'Color', 'none');
    box(tmpAx, 'on');
    grid(tmpAx, 'on');
    callbacks.drawToAxes(tmpAx);
    bosonPlotter.styleAxesForExport(tmpAx);
    try
        switch lower(mode)
            case 'png'
                copygraphics(tmpFig, ...
                    'ContentType', 'image', ...
                    'Resolution', 300, ...
                    'BackgroundColor', 'none');
            otherwise  % 'vector'
                copygraphics(tmpFig, ...
                    'ContentType', 'vector', ...
                    'BackgroundColor', 'none');
        end
    catch ME
        delete(tmpFig);
        callbacks.logGUIError('Copy to clipboard', ME.message, ME);
        uialert(fig, sprintf('Copy failed:\n%s', ME.message), 'Copy error');
        return;
    end
    delete(tmpFig);
end
