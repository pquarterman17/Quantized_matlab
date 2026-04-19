function mergeDatasets(appData, fig, ui, callbacks)
%MERGEDATASETS  Concatenate selected datasets into one new dataset.
%
% Syntax
%   bosonPlotter.mergeDatasets(appData, fig, ui, callbacks)
%
% Behaviour
%   Requires >= 2 datasets selected in ui.lbDatasets (multi-select).
%   Uses corrData if available, otherwise raw data.  Concatenates y columns
%   from all selected datasets (must have matching column counts) and sorts
%   the merged x-vector ascending.  Display name lists the constituents.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutated: datasets, activeIdx, model)
%   fig       - Main BosonPlotter figure handle (for uialert parent)
%   ui        - Struct with widget handles: lbDatasets
%   callbacks - Struct of function handles:
%                 .buildDs(fp, data, parserName)  -> ds struct
%                 .cancelInteractions()
%                 .rebuildDatasetList(keepActive)
%                 .updateControlsForActiveDataset()
%                 .onPlot()

    if isempty(appData.datasets)
        uialert(fig,'Load files first.','No data'); return;
    end

    % Collect selected indices from multi-select listbox
    rawVal = ui.lbDatasets.Value;
    if ~iscell(rawVal), rawVal = {rawVal}; end
    selIdxList = cell2mat(rawVal);   % numeric vector of dataset indices
    selIdxList = selIdxList(selIdxList >= 1 & selIdxList <= numel(appData.datasets));

    if numel(selIdxList) < 2
        uialert(fig, ...
            sprintf(['Select at least 2 datasets in the list ' ...
                     '(Ctrl+click or Shift+click).\n' ...
                     'Currently selected: %d dataset(s).'], numel(selIdxList)), ...
            'Merge: need ≥2 datasets');
        return;
    end

    % Use corrData if available, else raw data
    d1 = appData.datasets{selIdxList(1)};
    baseData = guiTernary(~isempty(d1.corrData), d1.corrData, d1.data);

    mergedTime   = double(baseData.time);
    mergedValues = baseData.values;

    ok = true;
    for mi = 2:numel(selIdxList)
        dsi  = appData.datasets{selIdxList(mi)};
        di   = guiTernary(~isempty(dsi.corrData), dsi.corrData, dsi.data);

        % Check column count compatibility
        if size(di.values, 2) ~= size(baseData.values, 2)
            uialert(fig, ...
                sprintf(['Dataset #%d has %d Y columns but dataset #%d has %d.\n' ...
                         'All selected datasets must have the same number of channels.'], ...
                         selIdxList(mi), size(di.values,2), ...
                         selIdxList(1),  size(baseData.values,2)), ...
                'Merge: column mismatch');
            ok = false;  break;
        end

        mergedTime   = [mergedTime;   double(di.time)];   %#ok<AGROW>
        mergedValues = [mergedValues; di.values];           %#ok<AGROW>
    end
    if ~ok, return; end

    % Sort by x (ascending)
    [mergedTime, sortOrder] = sort(mergedTime, 'ascend');
    mergedValues = mergedValues(sortOrder, :);

    % Build merged data struct from the first dataset's metadata
    mergedData          = baseData;
    mergedData.time     = mergedTime;
    mergedData.values   = mergedValues;

    % Build display name from constituent filenames
    nameStrs = cell(1, numel(selIdxList));
    for mi = 1:numel(selIdxList)
        [~, fn, ~] = fileparts(appData.datasets{selIdxList(mi)}.filepath);
        nameStrs{mi} = fn;
    end
    mergedName = ['[merged] ', strjoin(nameStrs, ' + ')];

    ds = callbacks.buildDs(appData.datasets{selIdxList(1)}.filepath, mergedData, ...
                           appData.datasets{selIdxList(1)}.parserName);
    ds.displayName = mergedName;

    appData.datasets{end+1} = ds;
    appData.model.addDataset(ds.data, ds.filepath, ds.parserName);
    appData.activeIdx       = numel(appData.datasets);

    callbacks.cancelInteractions();
    callbacks.rebuildDatasetList(true);
    callbacks.updateControlsForActiveDataset();
    callbacks.onPlot();
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m nested function scope)
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end
