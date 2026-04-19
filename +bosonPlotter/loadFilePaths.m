function loadFilePaths(appData, fpaths, fig, headless, callbacks)
%LOADFILEPATHS  Import a cell array of full file paths into appData.datasets.
%
% Syntax
%   bosonPlotter.loadFilePaths(appData, fpaths, fig, headless, callbacks)
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutated: datasets, activeIdx, lastDir, model)
%   fpaths    - Cell array of full file paths
%   fig       - Main BosonPlotter figure handle (for uialert / uiconfirm parents)
%   headless  - Logical scalar; when true, skip autosave timer restart
%   callbacks - Struct of function handles:
%                 .buildDs(fp, data, parserName)         -> ds struct
%                 .guiImport(fp)                         -> [data, parserName]
%                 .setStatus(msg)
%                 .addToRecentFiles(fp)
%                 .logGUIError(title, msg, ME)
%                 .cancelInteractions()
%                 .rebuildDatasetList(keepActiveIdx)
%                 .updateControlsForActiveDataset()
%                 .estimateDatasetMemoryMB()             -> scalar MB
%                 .recordAction(cmd)
%                 .onPlot()
%
% Notes
%   Shared by onAddFiles (file dialog) and onDropFiles (drag-and-drop).
%   buildDs() and guiImport() are file-level helpers in BosonPlotter.m;
%   they are passed in as handles to keep the boundary clean.

    buildDsFn   = callbacks.buildDs;
    guiImportFn = callbacks.guiImport;

    if isempty(fpaths), return; end
    appData.lastDir = fileparts(fpaths{1});

    % File size warning for very large files (>50 MB)
    for wfi = 1:numel(fpaths)
        try
            fInfo = dir(fpaths{wfi});
            if ~isempty(fInfo) && fInfo(1).bytes > 50e6
                [~, wfn, wfx] = fileparts(fpaths{wfi});
                sizeMB = fInfo(1).bytes / 1e6;
                answer = uiconfirm(fig, ...
                    sprintf('%s%s is %.0f MB.\nLarge files may use significant memory. Continue?', ...
                        wfn, wfx, sizeMB), ...
                    'Large File Warning', ...
                    'Options', {'Continue', 'Skip'}, ...
                    'DefaultOption', 'Continue');
                if strcmp(answer, 'Skip')
                    fpaths{wfi} = '';  % mark for skip
                end
            end
        catch
        end
    end
    fpaths = fpaths(~cellfun(@isempty, fpaths));
    if isempty(fpaths), return; end

    % Progress indicator for file loading
    fig.Pointer = 'watch';
    nTotal = numel(fpaths);

    % ── Excel "Apply to all" state ──
    excelApplyAll    = false;
    excelSavedSheets = {};

    excelExts = {'.xlsx','.xls','.xlsm','.xlsb','.ods'};
    nLoaded = 0;
    for fi = 1:numel(fpaths)
        fp = fpaths{fi};
        [~, fnBase, fExt] = fileparts(fp);
        if nTotal > 1
            callbacks.setStatus(sprintf('Loading file %d of %d: %s%s...', fi, nTotal, fnBase, fExt));
        else
            callbacks.setStatus(sprintf('Loading %s%s...', fnBase, fExt));
        end
        drawnow limitrate;

        % ── Excel: offer sheet selection when file has multiple sheets ──
        if any(strcmpi(fExt, excelExts))
            try
                allSheetNames = sheetnames(fp);
            catch
                allSheetNames = {'Sheet1'};
            end
            if numel(allSheetNames) > 1
                if excelApplyAll && ~isempty(excelSavedSheets)
                    validIdx = excelSavedSheets(excelSavedSheets <= numel(allSheetNames));
                    if isempty(validIdx), validIdx = 1; end
                    selectedSheets = allSheetNames(validIdx);
                else
                    selIdx = listdlg( ...
                        'PromptString', {sprintf('Sheets in  %s:', [fnBase fExt]), ...
                                         'Select sheets to import:'}, ...
                        'ListString',   allSheetNames, ...
                        'SelectionMode','multiple', ...
                        'InitialValue', 1:numel(allSheetNames), ...
                        'Name',         'Import Excel Sheets', ...
                        'ListSize',     [220 160]);
                    if isempty(selIdx), continue; end
                    selectedSheets = allSheetNames(selIdx);

                    nExcelRemaining = 0;
                    for ri = (fi+1):numel(fpaths)
                        [~, ~, rExt] = fileparts(fpaths{ri});
                        if any(strcmpi(rExt, excelExts))
                            nExcelRemaining = nExcelRemaining + 1;
                        end
                    end
                    if nExcelRemaining > 0
                        selDesc = strjoin(cellstr(selectedSheets), ', ');
                        answer = uiconfirm(fig, ...
                            sprintf('Apply this sheet selection (%s) to the remaining %d Excel file(s)?', ...
                                selDesc, nExcelRemaining), ...
                            'Apply to All', ...
                            'Options', {'Apply to All', 'Choose Individually'}, ...
                            'DefaultOption', 1, 'CancelOption', 2);
                        if strcmp(answer, 'Apply to All')
                            excelApplyAll    = true;
                            excelSavedSheets = selIdx;
                        end
                    end
                end
            else
                selectedSheets = allSheetNames;
            end
            % Determine correct parser for this Excel file (SIMS vs generic)
            resolveResult = parser.resolveParser(fp);
            excelParserName = resolveResult.name;

            for si = 1:numel(selectedSheets)
                shName = selectedSheets{si};
                try
                    if strcmp(excelParserName, 'importSIMS')
                        data       = parser.importSIMS(fp, 'Sheet', shName);
                        parserName = 'importSIMS';
                    else
                        data       = parser.importExcel(fp, 'Sheet', shName);
                        parserName = 'importExcel';
                    end
                    ds = buildDsFn(fp, data, parserName);
                    ds.displayName = sprintf('%s%s [%s]', fnBase, fExt, shName);
                    appData.datasets{end+1} = ds;
                    appData.model.addDataset(data, fp, parserName);
                    nLoaded = nLoaded + 1;
                    callbacks.addToRecentFiles(fp);
                catch ME
                    fprintf(2, '\n[BosonPlotter] Import error (%s [%s]): %s\n', ...
                        fnBase, shName, ME.message);
                    callbacks.logGUIError('Import error', sprintf('%s [%s]  %s', fnBase, shName, ME.message), ME);
                    uialert(fig, sprintf('%s [%s]\n\n%s', fnBase, shName, ME.message), ...
                        'Import error');
                end
            end
            continue   % skip normal single-parser path
        end

        % ── Normal single-parser import ──────────────────────────────
        try
            [data, parserName] = guiImportFn(fp);

            % Template matching: auto-apply or suggest overrides
            try
                [tmpl, conf] = templates.TemplateEngine.match(data, Type='tabular');
                if conf >= 0.8 && ~isempty(tmpl)
                    data = templates.TemplateEngine.apply(data, tmpl);
                    callbacks.setStatus(sprintf('Applied template: %s', tmpl.name));
                elseif conf >= 0.4 && ~isempty(tmpl)
                    sel = uiconfirm(fig, ...
                        sprintf('Suggested template: "%s" (%.0f%% match)\nApply it?', tmpl.name, conf*100), ...
                        'Template Suggestion', ...
                        'Options', {'Apply', 'Edit...', 'Ignore'}, ...
                        'DefaultOption', 'Apply', 'CancelOption', 'Ignore');
                    if strcmp(sel, 'Apply')
                        data = templates.TemplateEngine.apply(data, tmpl);
                    elseif strcmp(sel, 'Edit...')
                        edited = templates.ColumnMapper(data, Template=tmpl, ParentFig=fig);
                        if ~isempty(edited), data = edited; end
                    end
                elseif conf < 0.4 && ismember(parserName, {'importCSV', 'importExcel'})
                    % Generic parsers: offer Column Mapper for unknown layouts
                    edited = templates.ColumnMapper(data, ParentFig=fig);
                    if ~isempty(edited), data = edited; end
                end
            catch ME_tmpl
                fprintf(2, '[BosonPlotter] Template match warning: %s\n', ME_tmpl.message);
            end

            ds = buildDsFn(fp, data, parserName);
            appData.datasets{end+1} = ds;
            appData.model.addDataset(data, fp, parserName);
            nLoaded = nLoaded + 1;
            callbacks.addToRecentFiles(fp);
        catch ME
            fprintf(2, '\n[BosonPlotter] Import error (%s): %s\n', fnBase, ME.message);
            for si = 1:numel(ME.stack)
                fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
            end
            callbacks.logGUIError('Import error', sprintf('%s  %s', [fnBase fExt], ME.message), ME);
            uialert(fig, sprintf('%s\n\n%s', [fnBase fExt], ME.message), 'Import error');
        end
    end

    fig.Pointer = 'arrow';
    callbacks.cancelInteractions();
    drawnow;
    if nLoaded == 0, return; end

    appData.activeIdx = numel(appData.datasets);

    callbacks.rebuildDatasetList(true);
    callbacks.updateControlsForActiveDataset();
    memMB = callbacks.estimateDatasetMemoryMB();
    callbacks.setStatus(sprintf('Loaded %d file(s) — %d dataset(s) total (~%.0f MB).', ...
        nLoaded, numel(appData.datasets), memMB));
    for fj = 1:numel(fpaths)
        callbacks.recordAction(sprintf("data = parser.importAuto('%s');", fpaths{fj}));
    end
    callbacks.onPlot();
    if ~headless
        bosonPlotter.autosave.start(appData);
    end
end
