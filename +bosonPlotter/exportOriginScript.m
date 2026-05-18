function exportOriginScript(appData, fig, guiState)
%EXPORTORIGINSCRIPT  Export active dataset as LabTalk script + CSV.
%
%   bosonPlotter.exportOriginScript(appData, fig, guiState)
%
%   Inputs:
%     appData  - AppState handle
%     fig      - uifigure
%     guiState - struct with fields: logX, logY

    if isempty(appData.datasets) || appData.activeIdx < 1
        bosonPlotter.quietAlert(fig, 'Load a file first.', 'No data'); return;
    end
    ds  = appData.datasets{appData.activeIdx};
    src = guiTernary_(~isempty(ds.corrData), ds.corrData, ds.data);
    [fp, fn, ~] = fileparts(ds.filepath);

    defaultPath = fullfile(fp, [fn, '.ogs']);
    [outFile, outDir] = uiputfile({'*.ogs','LabTalk Script (*.ogs)'}, ...
        'Save Origin Script', defaultPath);
    if isequal(outFile, 0), return; end

    scriptPath = fullfile(outDir, outFile);
    try
        utilities.exportOriginScript(src, scriptPath, ...
            'LogY', guiState.logY, ...
            'LogX', guiState.logX);
        bosonPlotter.quietAlert(fig, sprintf('Origin script saved:\n%s\n\nRun in Origin: run.file("%s")', ...
            scriptPath, outFile), 'Export Complete');
    catch ME
        bosonPlotter.quietAlert(fig, sprintf('Export failed:\n%s', ME.message), 'Export Error');
    end
end

function out = guiTernary_(cond, ifTrue, ifFalse)
    if cond, out = ifTrue; else, out = ifFalse; end
end
