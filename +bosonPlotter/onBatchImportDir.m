function onBatchImportDir(appData, fig, callbacks)
%ONBATCHIMPORTDIR  Import all supported files from a directory into the GUI.
%
% Syntax
%   bosonPlotter.onBatchImportDir(appData, fig, callbacks)
%
% Behaviour
%   Prompts for a directory via `uigetdir`, then asks (via `uiconfirm`)
%   whether to recurse into subdirectories.  Calls
%   `scripts.batchImport(dirPath, 'Recursive', recursive)` and, for each
%   returned result with non-empty `.data`, builds a dataset struct with
%   `callbacks.buildDs(filepath, data, 'importAuto')` and appends it
%   both to `appData.datasets` and to `appData.model`.  After loading,
%   the active dataset is set to the last one added and the GUI list is
%   rebuilt.  Any single failure is skipped silently (other files still
%   load); batch-level failures are reported via `uialert`.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutates datasets, activeIdx, model)
%   fig       - Main figure handle (uiconfirm / uialert parent)
%   callbacks - Struct of function handles:
%                 .buildDs(filepath, data, parserName) -> dataset struct
%                 .rebuildDatasetList(keepActiveIdx)
%                 .onSelectDataset()
%                 .setStatus(msg)
%                 .recordAction(comment)

    dirPath = uigetdir(pwd, 'Select directory to import');
    if isequal(dirPath, 0), return; end
    answer = uiconfirm(fig, 'Scan subdirectories recursively?', ...
        'Batch Import', 'Options', {'Yes', 'No', 'Cancel'}, ...
        'DefaultOption', 1, 'CancelOption', 3);
    if strcmp(answer, 'Cancel'), return; end
    recursive = strcmp(answer, 'Yes');
    callbacks.setStatus('Batch importing...');
    drawnow;
    try
        results = scripts.batchImport(dirPath, 'Recursive', recursive);
        if isempty(results)
            uialert(fig, 'No supported files found in the selected directory.', 'Batch Import');
            callbacks.setStatus('Batch import: no files found');
            return;
        end
        nAdded = 0;
        for bi = 1:numel(results)
            if isempty(results(bi).data), continue; end
            try
                fp_i = results(bi).filepath;
                ds_i = callbacks.buildDs(fp_i, results(bi).data, 'importAuto');
                appData.datasets{end+1} = ds_i;
                appData.model.addDataset(results(bi).data, fp_i, 'importAuto');
                nAdded = nAdded + 1;
            catch
                % Skip files that fail to build dataset struct
            end
        end
        if nAdded > 0
            callbacks.rebuildDatasetList(false);
            appData.activeIdx = numel(appData.datasets);
            callbacks.onSelectDataset();
        end
        callbacks.setStatus(sprintf('Batch import: %d files loaded from %s', nAdded, dirPath));
    catch ME
        uialert(fig, sprintf('Batch import failed:\n%s', ME.message), 'Error');
        callbacks.setStatus('Batch import failed');
    end
    callbacks.recordAction(sprintf("%% Batch import: '%s' (recursive=%d)", dirPath, recursive));
end
