function datasetMetaEdit(appData, fig, ui, mode, callbacks)
%DATASETMETAEDIT  Dataset operations and correction-preset management.
%
% Syntax
%   bosonPlotter.datasetMetaEdit(appData, fig, ui, mode, callbacks)
%
% Modes
%   'notes'         — edit dataset notes
%   'rename'        — change displayName / legendName
%   'reload'        — re-import active dataset from disk
%   'save-preset'   — save current correction settings under a name
%   'load-preset'   — apply a saved preset to the correction widgets
%   'delete-preset' — remove a saved preset
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutated)
%   fig       - Main BosonPlotter figure handle
%   ui        - Struct with widget handles: efXOffset, efYOffset, efBGSlope,
%               efBGIntercept, cbSmooth, efSmoothWin, ddSmoothMethod,
%               ddNormalize, ddDerivative, efXTrimMin, efXTrimMax, ddPreset
%   mode      - One of the mode strings above
%   callbacks - Struct of function handles:
%                 .setStatus(msg)
%                 .guiImport(fp)                 -> [data, parserName]
%                 .rebuildDatasetList(keepActive)
%                 .onSelectDataset(s, e)
%                 .onPlot()
%                 .updateControlsForActiveDataset()

    % Preset operations don't require a loaded dataset
    if startsWith(mode, 'save-preset') || startsWith(mode, 'load-preset') || startsWith(mode, 'delete-preset')
        switch mode
            case 'save-preset'
                answer = inputdlg('Preset name:', 'Save Correction Preset', [1 40]);
                if isempty(answer) || isempty(strtrim(answer{1})), return; end
                pName = strtrim(answer{1});
                p = struct('xOff', ui.efXOffset.Value, 'yOff', ui.efYOffset.Value, ...
                    'bgSlope', ui.efBGSlope.Value, 'bgInt', ui.efBGIntercept.Value, ...
                    'smoothEnabled', ui.cbSmooth.Value, 'smoothWindow', ui.efSmoothWin.Value, ...
                    'smoothMethod', ui.ddSmoothMethod.Value, 'normMethod', ui.ddNormalize.Value, ...
                    'derivativeMode', ui.ddDerivative.Value, ...
                    'xTrimMin', ui.efXTrimMin.Value, 'xTrimMax', ui.efXTrimMax.Value);
                bosonPlotter.correctionPresets.save(pName, p);
                ui.ddPreset.Items = [{'(presets)'}, bosonPlotter.correctionPresets.list()];
                ui.ddPreset.Value = '(presets)';
                callbacks.setStatus(sprintf('Preset "%s" saved.', pName));
            case 'load-preset'
                selName = ui.ddPreset.Value;
                if strcmp(selName, '(presets)'), return; end
                try
                    p = bosonPlotter.correctionPresets.load(selName);
                catch
                    uialert(fig, sprintf('Preset "%s" not found.', selName), 'Load Error');
                    return;
                end
                if isfield(p,'xOff'),    ui.efXOffset.Value = p.xOff; end
                if isfield(p,'yOff'),    ui.efYOffset.Value = p.yOff; end
                if isfield(p,'bgSlope'), ui.efBGSlope.Value = p.bgSlope; end
                if isfield(p,'bgInt'),   ui.efBGIntercept.Value = p.bgInt; end
                if isfield(p,'smoothEnabled'), ui.cbSmooth.Value = p.smoothEnabled; end
                if isfield(p,'smoothWindow'),  ui.efSmoothWin.Value = p.smoothWindow; end
                if isfield(p,'smoothMethod'),   ui.ddSmoothMethod.Value = p.smoothMethod; end
                if isfield(p,'normMethod'),     ui.ddNormalize.Value = p.normMethod; end
                if isfield(p,'derivativeMode'), ui.ddDerivative.Value = p.derivativeMode; end
                if isfield(p,'xTrimMin'), ui.efXTrimMin.Value = p.xTrimMin; end
                if isfield(p,'xTrimMax'), ui.efXTrimMax.Value = p.xTrimMax; end
                callbacks.setStatus(sprintf('Loaded preset "%s" — click Apply to use.', selName));
            case 'delete-preset'
                selName = ui.ddPreset.Value;
                if strcmp(selName, '(presets)'), return; end
                bosonPlotter.correctionPresets.delete(selName);
                ui.ddPreset.Items = [{'(presets)'}, bosonPlotter.correctionPresets.list()];
                ui.ddPreset.Value = '(presets)';
                callbacks.setStatus(sprintf('Preset "%s" deleted.', selName));
        end
        return;
    end

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig, 'Load a file first.', 'No data'); return;
    end
    ds = appData.datasets{appData.activeIdx};
    switch mode
        case 'notes'
            currentNotes = '';
            if isfield(ds, 'notes'), currentNotes = ds.notes; end
            answer = inputdlg('Dataset notes:', 'Notes', [5 60], {currentNotes});
            if isempty(answer), return; end
            appData.datasets{appData.activeIdx}.notes = strtrim(answer{1});
            callbacks.rebuildDatasetList(true);
            callbacks.onSelectDataset([], []);
            callbacks.setStatus(guiTernary(isempty(strtrim(answer{1})), 'Note cleared.', 'Note saved.'));
        case 'rename'
            current = ds.displayName;
            if isempty(current)
                [~, fn, fext] = fileparts(ds.filepath);
                current = [fn fext];
            end
            answer = inputdlg('Display name:', 'Rename Dataset', [1 60], {current});
            if isempty(answer), return; end
            newName = strtrim(answer{1});
            if isempty(newName), return; end
            appData.datasets{appData.activeIdx}.displayName = newName;
            appData.datasets{appData.activeIdx}.legendName  = newName;
            callbacks.rebuildDatasetList(true);
            callbacks.onPlot();
            callbacks.setStatus(sprintf('Renamed to: %s', newName));
        case 'reload'
            fp = ds.filepath;
            if ~isfile(fp)
                uialert(fig, sprintf('File not found:\n%s', fp), 'Reload Failed');
                return;
            end
            try
                [newData, pName] = callbacks.guiImport(fp);
                appData.datasets{appData.activeIdx}.data = newData;
                appData.datasets{appData.activeIdx}.corrData = [];
                appData.datasets{appData.activeIdx}.parserName = pName;
                appData.datasets{appData.activeIdx}.mask = true(size(newData.time));
                callbacks.updateControlsForActiveDataset();
                callbacks.onPlot();
                [~, fn, fext] = fileparts(fp);
                callbacks.setStatus(sprintf('Reloaded %s%s from disk.', fn, fext));
            catch ME
                uialert(fig, sprintf('Reload failed:\n%s', ME.message), 'Reload Error');
            end
    end
end
