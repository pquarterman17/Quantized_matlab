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
        uialert(fig, 'Load a file first.', 'No data');
        return;
    end

    selIdx = resolveSelectedIndices(ui.lbDatasets, appData);
    multiSelected = numel(selIdx) > 1;

    if multiSelected
        mode = askExportMode(fig, numel(selIdx));
        if isempty(mode), return; end
    else
        mode = 'active';
    end

    fmt = callbacks.resolvedExportFormat();

    switch mode
        case 'active'
            fp = pickSaveFile(fig, appData, appData.activeIdx);
            if isempty(fp), return; end
            exportSingleDataset(appData, appData.activeIdx, fp, fmt, fig, callbacks);
            callbacks.recordAction(sprintf("%% Exported CSV: %s", fp));
            uialert(fig, sprintf('Saved:\n%s', fp), 'Saved');

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
            uialert(fig, sprintf('Exported %d of %d datasets.', nOk, numel(selIdx)), ...
                'Export Complete');

        case 'combined'
            fp = pickSaveFile(fig, appData, selIdx(1), '_combined');
            if isempty(fp), return; end
            fig.Pointer = 'watch'; drawnow;
            try
                exportCombined(appData, selIdx, fp, fmt, callbacks);
                fig.Pointer = 'arrow';
                callbacks.recordAction(sprintf("%% Exported combined CSV: %s", fp));
                uialert(fig, sprintf('Saved %d datasets to:\n%s', numel(selIdx), fp), 'Saved');
            catch ME
                fig.Pointer = 'arrow';
                callbacks.logGUIError('Combined export', ME.message, ME);
                uialert(fig, ME.message, 'Export error');
            end
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers
% ════════════════════════════════════════════════════════════════════════

function mode = askExportMode(fig, nSel)
%ASKEXPORTMODE  Prompt the user how to export multiple selected datasets.
    choices = { ...
        sprintf('Active dataset only'), ...
        sprintf('Each as separate file (%d files)', nSel), ...
        sprintf('Combined into one CSV (%d datasets side-by-side)', nSel), ...
        'Cancel'};
    answer = uiconfirm(fig, ...
        sprintf('%d datasets selected. How should they be exported?', nSel), ...
        'CSV Export Mode', ...
        'Options', choices, 'DefaultOption', 1, 'CancelOption', 4);
    switch answer
        case choices{1}, mode = 'active';
        case choices{2}, mode = 'separate';
        case choices{3}, mode = 'combined';
        otherwise,       mode = '';
    end
end

function fp = pickSaveFile(fig, appData, dsIdx, suffix)
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

function exportSingleDataset(appData, dsIdx, fp, fmt, fig, callbacks)
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

function exportCombined(appData, selIdx, fp, fmt, callbacks)
%EXPORTCOMBINED  Write multiple datasets side-by-side into one CSV.
    allHdrs = {};
    allCols = {};
    maxRows = 0;
    for k = 1:numel(selIdx)
        di = selIdx(k);
        ds = appData.datasets{di};
        hasCorrected = ~isempty(ds.corrData);
        d = guiTernary(hasCorrected, ds.corrData, ds.data);
        d = bosonPlotter.applyDisplayUnits(d, ds, appData);
        [~, fn, fext] = fileparts(ds.filepath);
        tag = guiTernary(isfield(ds,'legendName') && ~isempty(ds.legendName), ...
            ds.legendName, [fn fext]);

        xName = 'X';
        if isfield(d, 'metadata') && isfield(d.metadata, 'xName')
            xName = d.metadata.xName;
        end
        allHdrs{end+1} = sprintf('%s [%s]', xName, tag); %#ok<AGROW>
        if isdatetime(d.time)
            allCols{end+1} = d.time(:); %#ok<AGROW>
        else
            allCols{end+1} = d.time(:); %#ok<AGROW>
        end

        for ci = 1:numel(d.labels)
            lbl = d.labels{ci};
            if ~isempty(d.units{ci})
                lbl = sprintf('%s (%s)', lbl, d.units{ci});
            end
            allHdrs{end+1} = sprintf('%s [%s]', lbl, tag); %#ok<AGROW>
            allCols{end+1} = d.values(:, ci); %#ok<AGROW>
        end
        maxRows = max(maxRows, numel(d.time));
    end

    dirPart = fileparts(fp);
    if ~isempty(dirPart) && ~isfolder(dirPart)
        error('exportCombined:badDir', 'Output directory does not exist:\n%s', dirPart);
    end
    fid = fopen(fp, 'w');
    if fid < 0
        error('exportCombined:cannotOpen', 'Cannot open file for writing:\n%s', fp);
    end
    closeGuard = onCleanup(@() fclose(fid)); %#ok<NASGU>

    if strcmp(fmt, 'origin')
        longNames = cellfun(@(h) strtrim(regexprep(h, '\s*\([^)]+\)', '')), ...
                            allHdrs, 'UniformOutput', false);
        units = cellfun(@(h) extractUnit(h), allHdrs, 'UniformOutput', false);
        desigs = cell(size(allHdrs));
        isX = true;
        for ci = 1:numel(allHdrs)
            if isX, desigs{ci} = 'X'; isX = false;
            elseif contains(lower(allHdrs{ci}), {'err','std','sigma'}), desigs{ci} = 'yEr';
            else, desigs{ci} = 'Y';
            end
            if ci < numel(allHdrs) && ~isempty(regexp(allHdrs{ci+1}, '^\s*X\b', 'once'))
                isX = true;
            end
        end
        fprintf(fid, '%s\n', strjoin(longNames, ','));
        fprintf(fid, '%s\n', strjoin(units, ','));
        fprintf(fid, '%s\n', strjoin(desigs, ','));
    else
        fprintf(fid, '%s\n', strjoin(allHdrs, ','));
    end

    hasDatetime = any(cellfun(@isdatetime, allCols));
    if hasDatetime
        for r = 1:maxRows
            parts = cell(1, numel(allCols));
            for ci = 1:numel(allCols)
                col = allCols{ci};
                if r <= numel(col)
                    if isdatetime(col)
                        parts{ci} = datestr(col(r), 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST>
                    else
                        parts{ci} = sprintf('%.10g', col(r));
                    end
                else
                    parts{ci} = '';
                end
            end
            fprintf(fid, '%s\n', strjoin(parts, ','));
        end
    else
        mat = NaN(maxRows, numel(allCols));
        for ci = 1:numel(allCols)
            col = allCols{ci};
            mat(1:numel(col), ci) = col;
        end
        rowFmt = ['%.10g', repmat(',%.10g', 1, size(mat, 2) - 1), '\n'];
        fprintf(fid, rowFmt, mat.');
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

function u = extractUnit(hdr)
    tok = regexp(hdr, '\(([^)]+)\)', 'tokens', 'once');
    if ~isempty(tok), u = tok{1}; else, u = ''; end
end
