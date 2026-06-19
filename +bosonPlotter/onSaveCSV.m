function onSaveCSV(appData, fig, ui, callbacks)
%ONSAVECSV  Export CSV with Save As dialog and multi-dataset support.
%
% Syntax
%   bosonPlotter.onSaveCSV(appData, fig, ui, callbacks)
%
% Behaviour
%   Shows a Save As file dialog (suggested path from efSavePath).
%   When multiple datasets are selected, prompts the user to choose:
%     - Active dataset only
%     - Each dataset as its own file (separate CSVs)
%     - All combined into one CSV (columns side-by-side)
%
% Inputs
%   appData   - bosonPlotter.AppState handle
%   fig       - Main figure handle (uialert parent)
%   ui        - Struct with widget handles: efSavePath, lbDatasets
%   callbacks - Struct of function handles:
%                 .resolvedExportFormat() -> 'origin' | 'standard'
%                 .findPolarizationPairs(datasets) -> pairMap
%                 .recordAction(cmdLine)
%                 .logGUIError(title, msg, ME)
%                 .guiSaveCSV(d, fp, dRaw, asymData, fmt)
%                 .setStatus(msg)

    if isempty(appData.datasets) || appData.activeIdx < 1
        bosonPlotter.quietAlert(fig, 'Load a file first.', 'No data');
        return;
    end

    selIdx = resolveSelectedIndices(ui.lbDatasets, appData);
    multiSelected = numel(selIdx) > 1;

    wfOn = isfield(callbacks, 'waterfall') && isstruct(callbacks.waterfall) && callbacks.waterfall.on;
    if multiSelected
        [mode, applyWf] = askExportMode(fig, numel(selIdx), wfOn, appData.theme);
        if isempty(mode), return; end
    else
        mode = 'active'; applyWf = false;
    end

    fmt = callbacks.resolvedExportFormat();

    switch mode
        case 'active'
            fp = pickSaveFile(fig, appData, appData.activeIdx);
            if isempty(fp), return; end
            exportSingleDataset(appData, appData.activeIdx, fp, fmt, fig, callbacks);
            callbacks.recordAction(sprintf("%% Exported CSV: %s", fp));
            bosonPlotter.quietAlert(fig, sprintf('Saved:\n%s', fp), 'Saved');

        case 'separate'
            outDir = uigetdir(resolveStartDir(appData), ...
                'Choose output folder for individual CSVs');
            if isequal(outDir, 0), return; end
            fig.Pointer = 'watch'; drawnow;
            nOk = 0;
            for k = 1:numel(selIdx)
                di = selIdx(k);
                ds = appData.datasets{di};
                [~, fn, ~] = fileparts(ds.filepath);
                suffix = guiTernary(~isempty(ds.corrData), '_corrected', '_export');
                fp = fullfile(outDir, [fn, suffix, '.csv']);
                try
                    exportSingleDataset(appData, di, fp, fmt, fig, callbacks);
                    nOk = nOk + 1;
                catch ME
                    callbacks.logGUIError('Batch save', ME.message, ME);
                end
            end
            fig.Pointer = 'arrow';
            callbacks.recordAction(sprintf("%% Exported %d CSV files", nOk));
            bosonPlotter.quietAlert(fig, sprintf('Exported %d of %d datasets.', nOk, numel(selIdx)), ...
                'Export Complete');

        case 'combined'
            fp = pickSaveFile(fig, appData, selIdx(1), '_combined');
            if isempty(fp), return; end
            fig.Pointer = 'watch'; drawnow;
            try
                wf = resolveWaterfall(callbacks, appData, selIdx, applyWf);
                bosonPlotter.exportCombinedCSV(appData, selIdx, fp, fmt, wf);
                fig.Pointer = 'arrow';
                noteWf = guiTernary(wf.apply, ' (waterfall offset applied)', '');
                callbacks.recordAction(sprintf("%% Exported combined CSV: %s%s", fp, noteWf));
                bosonPlotter.quietAlert(fig, sprintf('Saved %d datasets to:\n%s%s', numel(selIdx), fp, noteWf), 'Saved');
            catch ME
                fig.Pointer = 'arrow';
                callbacks.logGUIError('Combined export', ME.message, ME);
                bosonPlotter.quietAlert(fig, ME.message, 'Export error');
            end
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers
% ════════════════════════════════════════════════════════════════════════

function [mode, applyWf] = askExportMode(fig, nSel, wfOn, theme)
%ASKEXPORTMODE  Modal dialog: pick export mode + optional waterfall offset.
%   Returns mode 'active'|'separate'|'combined' ('' = cancelled) and a
%   logical applyWf (the waterfall-offset checkbox; only enabled when
%   waterfall is on and Combined is selected).
    mode = ''; applyWf = false;
    if nargin < 3, wfOn = false; end
    if nargin < 4, theme = 'Dark'; end
    if bosonPlotter.isHeadless()
        mode = 'active';   % matches the previous default option
        return;
    end

    pos = [300 300 390 230];
    try
        fp = fig.Position;
        pos(1:2) = [fp(1) + (fp(3)-pos(3))/2, fp(2) + (fp(4)-pos(4))/2];
    catch
    end
    dlg = uifigure('Name', 'CSV Export', 'WindowStyle', 'modal', ...
        'Resize', 'off', 'Position', pos);
    gl = uigridlayout(dlg, [4 1], 'RowHeight', {34, 96, 26, 36}, ...
        'Padding', [14 12 14 12], 'RowSpacing', 8);

    uilabel(gl, 'Text', sprintf('%d datasets selected. How should they be exported?', nSel), ...
        'WordWrap', 'on');

    bg = uibuttongroup(gl, 'BorderType', 'none');
    rbActive = uiradiobutton(bg, 'Text', 'Active dataset only', 'Position', [6 70 350 20]);
    rbSep    = uiradiobutton(bg, 'Text', sprintf('Each as separate file (%d files)', nSel), 'Position', [6 42 350 20]); %#ok<NASGU>
    rbComb   = uiradiobutton(bg, 'Text', sprintf('Combined into one CSV (%d side-by-side)', nSel), 'Position', [6 14 350 20]);
    bg.SelectedObject = rbActive;

    cbWf = uicheckbox(gl, 'Text', 'Apply waterfall offset to Y values', 'Enable', 'off', ...
        'Tooltip', 'Bake the on-screen waterfall stacking into the written data (Combined mode)');
    bg.SelectionChangedFcn = @(~,~) syncWf();

    btnGL = uigridlayout(gl, [1 3], 'ColumnWidth', {'1x', 90, 90}, 'Padding', [0 0 0 0]);
    uilabel(btnGL);
    uibutton(btnGL, 'Text', 'Cancel', 'ButtonPushedFcn', @(~,~) finish(false));
    uibutton(btnGL, 'Text', 'Export', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) finish(true));

    try, bosonPlotter.applyDialogTheme(dlg, theme); catch, end
    syncWf();
    uiwait(dlg);

    function syncWf()
        if wfOn && bg.SelectedObject == rbComb
            cbWf.Enable = 'on';
        else
            cbWf.Enable = 'off';
        end
    end

    function finish(ok)
        if ok
            so = bg.SelectedObject;
            if     so == rbComb, mode = 'combined';
            elseif so == rbActive, mode = 'active';
            else,                  mode = 'separate';
            end
            applyWf = strcmp(cbWf.Enable, 'on') && cbWf.Value;
        else
            mode = '';
        end
        if isvalid(dlg), uiresume(dlg); delete(dlg); end
    end
end

function wf = resolveWaterfall(callbacks, appData, selIdx, applyWf)
%RESOLVEWATERFALL  Build the waterfall-offset spec for exportCombinedCSV.
    wf = struct('apply', false, 'levels', [], 'spacing', 0, 'logMode', false);
    if ~applyWf || ~isfield(callbacks, 'waterfall') || ~callbacks.waterfall.on
        return;
    end
    w  = callbacks.waterfall;
    sp = w.rawSpacing;
    if isempty(sp) || ~isnumeric(sp) || sp <= 0
        if isfield(callbacks, 'computeAutoWaterfallSpacing')
            sp = callbacks.computeAutoWaterfallSpacing();
        else
            sp = 0;
        end
    end
    if isempty(sp) || sp <= 0, return; end
    wf.apply   = true;
    wf.spacing = sp;
    wf.logMode = isfield(w, 'logMode') && w.logMode;
    wf.levels  = bosonPlotter.waterfallOffsets(appData.datasets, selIdx);
end

function fp = pickSaveFile(~, appData, dsIdx, suffix)
%PICKSAVEFILE  Show a Save As dialog with a suggested filename.
    if nargin < 4, suffix = ''; end
    ds = appData.datasets{dsIdx};
    [dPath, dName, ~] = fileparts(ds.filepath);
    if isempty(suffix)
        if ~isempty(ds.corrData)
            suffix = '_corrected';
        else
            suffix = '_export';
        end
    end
    defFile = fullfile(dPath, [dName, suffix, '.csv']);
    [fname, fpath] = uiputfile({'*.csv','CSV files (*.csv)'}, ...
        'Save As...', defFile);
    if isequal(fname, 0)
        fp = '';
    else
        fp = fullfile(fpath, fname);
    end
    drawnow;  % flush dialog on some MATLAB versions
end

function exportSingleDataset(appData, dsIdx, fp, fmt, ~, callbacks)
%EXPORTSINGLEDATASET  Prepare and write one dataset to CSV.
    ds = appData.datasets{dsIdx};
    if isfield(ds, 'parserName') && isNeutronParser(ds.parserName)
        bosonPlotter.saveConsolidatedNeutronCSV(ds, fp, fmt, appData.datasets);
        return;
    end
    hasCorrected = ~isempty(ds.corrData);
    exportData   = guiTernary(hasCorrected, ds.corrData, ds.data);
    if isfield(ds, 'mask') && ~isempty(ds.mask) && any(~ds.mask)
        if hasCorrected
            nRawE = numel(ds.data.time);
            keepE = true(nRawE, 1);
            if ~isdatetime(ds.data.time)
                tVE = double(ds.data.time);
                if ~isnan(ds.xTrimMin), keepE = keepE & tVE >= ds.xTrimMin; end
                if ~isnan(ds.xTrimMax), keepE = keepE & tVE <= ds.xTrimMax; end
            end
            exportMask = ds.mask(keepE);
        else
            exportMask = ds.mask;
        end
        exportData.time   = exportData.time(exportMask);
        exportData.values = exportData.values(exportMask, :);
    end
    exportData = bosonPlotter.applyDisplayUnits(exportData, ds, appData);
    if hasCorrected
        cafeCb_ = struct('findPolarizationPairs', callbacks.findPolarizationPairs);
        asymData = bosonPlotter.computeAsymmetryForExport(ds, appData, cafeCb_);
        callbacks.guiSaveCSV(exportData, fp, ds.data, asymData, fmt);
    else
        callbacks.guiSaveCSV(exportData, fp, [], [], fmt);
    end
end

function selIdx = resolveSelectedIndices(lbDatasets, appData)
%RESOLVESELECTEDINDICES  Get selected dataset indices from the listbox.
    rawVal = lbDatasets.Value;
    if ~iscell(rawVal), rawVal = {rawVal}; end
    selIdx = cell2mat(rawVal);
    selIdx = selIdx(selIdx >= 1 & selIdx <= numel(appData.datasets));
    if isempty(selIdx)
        selIdx = appData.activeIdx;
    end
end

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function tf = isNeutronParser(pName)
    tf = ismember(pName, {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'});
end

function d = resolveStartDir(appData)
    if ~isempty(appData.lastDir) && isfolder(appData.lastDir)
        d = char(appData.lastDir);
    else
        d = pwd;
    end
end
