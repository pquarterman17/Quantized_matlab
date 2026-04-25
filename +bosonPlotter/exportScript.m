function exportScript(fig, filepath)
%EXPORTSCRIPT  Export a BosonPlotter session's macro log to a .m script.
%
%   bosonPlotter.exportScript(fig, 'analysis.m')
%
%   Free-function form of `actionLog.exportScript`. Looks up the macro
%   log attached to the BosonPlotter figure (via `getappdata(fig,
%   'macroLog')`) and writes it to `filepath` as a runnable MATLAB
%   script. Replay the script at any time with:
%
%       run('analysis.m')
%
%   This complements the toolbar "Save Script" button so headless tests
%   and external scripts can persist a recorded session without going
%   through the GUI.
%
%   Inputs:
%     fig      — BosonPlotter figure handle (return of `BosonPlotter()`
%                gives an api struct, not a fig — call `api.fig` or pass
%                the figure directly).
%     filepath — destination .m path (string or char).
%
%   Errors:
%     bosonPlotter:exportScript:noMacroLog — figure has no `macroLog` appdata
%     bosonPlotter:exportScript:emptyLog   — log is empty (nothing to export)
%
%   Example:
%     api = BosonPlotter();
%     api.startMacroRecord();
%     api.loadFiles({'sample.dat'});
%     api.stopMacroRecord();
%     bosonPlotter.exportScript(api.fig, 'session.m');
%
%   See also bosonPlotter.actionLog, bosonPlotter.serializeArg

    arguments
        fig      (1,1) {mustBeA(fig, ["matlab.ui.Figure", "matlab.graphics.Graphics"])}
        filepath (1,1) string
    end

    if ~isappdata(fig, 'macroLog')
        error('bosonPlotter:exportScript:noMacroLog', ...
            'Figure has no macroLog attached. Was this returned by BosonPlotter()?');
    end

    log = getappdata(fig, 'macroLog');
    if log.nEntries() == 0
        error('bosonPlotter:exportScript:emptyLog', ...
            'Macro log is empty — nothing to export.');
    end

    log.exportScript(filepath);
end
