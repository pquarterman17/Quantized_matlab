function cb = tableCallbacks(ctx)
%TABLECALLBACKS  Return callback struct for the data table panel.
%   ctx fields: appData, tblData, tblUnits, lblTableStats, efFilter, fig,
%               setStatus, getPlotData, onPlot, refreshDataTable,
%               onColumnDragStart, guiXName.

appData           = ctx.appData;
tblData           = ctx.tblData;
tblUnits          = ctx.tblUnits;
lblTableStats     = ctx.lblTableStats;
efFilter          = ctx.efFilter;
fig               = ctx.fig;
setStatus         = ctx.setStatus;
getPlotData       = ctx.getPlotData;
onPlot            = ctx.onPlot;
refreshDataTable  = ctx.refreshDataTable;
onColumnDragStart = ctx.onColumnDragStart;
guiXName          = ctx.guiXName;

cb.applyMaskStyling       = @applyMaskStyling;
cb.syncUnitsColumnWidths  = @syncUnitsColumnWidths;
cb.onTableCellEdit        = @onTableCellEdit;
cb.onUnitsCellEdit        = @onUnitsCellEdit;
cb.onTableSelectionChanged = @onTableSelectionChanged;
cb.onUnitsCellSelection   = @onUnitsCellSelection;
cb.onTableMaskSelected    = @onTableMaskSelected;
cb.onTableUnmaskSelected  = @onTableUnmaskSelected;
cb.onTableUnmaskAll       = @onTableUnmaskAll;
cb.onFilterApply          = @onFilterApply;
cb.onFilterClear          = @onFilterClear;
cb.onDescriptiveStats     = @onDescriptiveStats;
cb.onTableSort            = @onTableSort;
cb.onTableSaveAs          = @onTableSaveAs;

    function applyMaskStyling()
    %APPLYMASKSTYLING  Highlight masked rows in soft red using uistyle/addStyle.
        if isempty(tblData) || ~isvalid(tblData), return; end
        removeStyle(tblData);

        if isempty(appData.tableMask) || ~any(appData.tableMask), return; end

        cap = min(numel(appData.tableMask), appData.tableRowCap);
        maskedDataRows = find(appData.tableMask(1:cap));
        if isempty(maskedDataRows), return; end

        softRed = [1.0 0.88 0.88];
        s = uistyle('BackgroundColor', softRed);
        addStyle(tblData, s, 'row', maskedDataRows);
    end

    function syncUnitsColumnWidths(nCols)
    %SYNCUNITSCOLUMNWIDTHS  Match tblUnits column widths to tblData.
        w = cell(1, nCols);
        for ci = 1:nCols, w{ci} = 90; end
        try tblData.ColumnWidth  = w; catch, end
        try tblUnits.ColumnWidth = w; catch, end
    end

    function onTableCellEdit(~, evt)
    %ONTABLECELLEDIT  Handle cell edits in the main data table.
    %   Post-split: tblData holds only numeric data rows (no units row).
        row = evt.Indices(1);
        col = evt.Indices(2);
        nDataCols = size(appData.tableWorkingCopy, 2);
        if col > nDataCols, return; end

        newVal = evt.NewData;
        if isnumeric(newVal)
            appData.tableWorkingCopy(row, col) = newVal;
            appData.tableEdited = true;
        end
    end

    function onUnitsCellEdit(~, evt)
    %ONUNITSCELLEDIT  Handle edits in the 1-row units uitable.
        col = evt.Indices(2);
        if col < 1 || col > numel(appData.tableUnits), return; end
        newVal = evt.NewData;
        if ischar(newVal) || isstring(newVal)
            appData.tableUnits{col} = char(newVal);
            appData.tableEdited = true;
        end
    end

    function onTableSelectionChanged(~, evt)
    %ONTABLESELECTIONCHANGED  Track selected cells for mask actions.
        appData.tableSelection = evt.Indices;
    end

    function onUnitsCellSelection(~, evt)
    %ONUNITSCELLSELECTION  Arm the column drag-to-plot gesture.
        if isempty(evt.Indices), return; end
        col = evt.Indices(1,2);
        colNames = tblUnits.ColumnName;
        if col < 1 || col > numel(colNames), return; end
        rawName = colNames{col};
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds = appData.datasets{appData.activeIdx};
        d  = ds.data;
        xName     = guiXName(d.metadata);
        allLabels = [{xName}, d.labels];
        matched = allLabels(strcmp(allLabels, rawName));
        if isempty(matched)
            cleanName = regexprep(rawName, '\s*\(.*\)\s*$', '');
            matched = allLabels(strcmp(allLabels, cleanName));
        end
        if isempty(matched), return; end
        onColumnDragStart(matched{1});
    end

    function onTableMaskSelected(~, ~)
    %ONTABLEMASKSELECTED  Mask the currently selected rows in the table.
        sel = appData.tableSelection;
        if isempty(sel), return; end
        dataRows = unique(sel(:, 1));
        dataRows(dataRows < 1) = [];
        if isempty(dataRows), return; end
        if max(dataRows) > size(appData.tableWorkingCopy, 1), return; end
        appData.tableMask(dataRows) = true;
        applyMaskStyling();
        nMasked = sum(appData.tableMask);
        nRows = size(appData.tableWorkingCopy, 1);
        nCols = size(appData.tableWorkingCopy, 2);
        lblTableStats.Text = sprintf('%d rows, %d cols, %d masked  ', ...
            nRows, nCols, nMasked);
        syncTableMaskToDataset();
        setStatus(sprintf('Masked %d rows (%d total masked)', numel(dataRows), nMasked));
    end

    function onTableUnmaskSelected(~, ~)
    %ONTABLEUNMASKSELECTED  Unmask the currently selected rows.
        sel = appData.tableSelection;
        if isempty(sel), return; end
        dataRows = unique(sel(:, 1));
        dataRows = dataRows(dataRows >= 1 & dataRows <= numel(appData.tableMask));
        if isempty(dataRows), return; end
        appData.tableMask(dataRows) = false;
        applyMaskStyling();
        nMasked = sum(appData.tableMask);
        nRows = size(appData.tableWorkingCopy, 1);
        nCols = size(appData.tableWorkingCopy, 2);
        lblTableStats.Text = sprintf('%d rows, %d cols, %d masked  ', ...
            nRows, nCols, nMasked);
        syncTableMaskToDataset();
        setStatus(sprintf('Unmasked %d rows (%d total masked)', numel(dataRows), nMasked));
    end

    function onTableUnmaskAll(~, ~)
    %ONTABLEUNMASKALL  Clear all row masks.
        if isempty(appData.tableMask), return; end
        appData.tableMask(:) = false;
        refreshDataTable();
        syncTableMaskToDataset();
        setStatus('All masks cleared');
    end

    function onFilterApply(~, ~)
    %ONFILTERAPPY  Evaluate filter expression and mask non-passing rows.
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        expr = strtrim(efFilter.Value);
        d    = getPlotData(appData.activeIdx);
        nRows = numel(d.time);

        if isempty(expr)
            appData.filterMask = [];
        else
            try
                passMask = bosonPlotter.filterRows(d, expr);
                appData.filterMask = ~passMask(:);
                nPass = sum(passMask);
                setStatus(sprintf('Filter applied: %d / %d rows pass', nPass, nRows));
            catch ME
                uialert(fig, ME.message, 'Filter Error');
                return;
            end
        end

        if isempty(appData.filterMask)
            appData.tableMask = false(nRows, 1);
        else
            if isempty(appData.tableMask) || numel(appData.tableMask) ~= nRows
                appData.tableMask = appData.filterMask;
            else
                appData.tableMask = appData.tableMask | appData.filterMask;
            end
        end
        refreshDataTable();
        syncTableMaskToDataset();
    end

    function onFilterClear(~, ~)
    %ONFILTERCLEAR  Remove the row filter and restore unfiltered data.
        efFilter.Value     = '';
        appData.filterMask = [];
        nRows = size(appData.tableWorkingCopy, 1);
        if ~isempty(appData.tableMask) && numel(appData.tableMask) == nRows
            appData.tableMask(:) = false;
        end
        refreshDataTable();
        syncTableMaskToDataset();
        setStatus('Filter cleared');
    end

    function syncTableMaskToDataset()
    %SYNCTABLEMASKTODATASET  Push table mask into ds.mask and re-plot.
    %   appData.tableMask: true = masked (excluded). ds.mask: true = included.
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        nRaw = numel(ds.data.time);

        if isempty(appData.tableMask)
            ds.mask = true(nRaw, 1);
        else
            if numel(appData.tableMask) == nRaw
                ds.mask = ~appData.tableMask;
            else
                ds.mask = true(nRaw, 1);
                nM = min(numel(appData.tableMask), nRaw);
                ds.mask(1:nM) = ~appData.tableMask(1:nM);
            end
        end
        appData.datasets{appData.activeIdx} = ds;
        onPlot([], []);
    end

    function onDescriptiveStats(~, ~)
    %ONDESCRIPTIVESTATS  Show per-column descriptive statistics popup.
        if isempty(appData.tableWorkingCopy)
            uialert(fig, 'No data loaded.', 'Stats');
            return;
        end
        d = getPlotData(appData.activeIdx);
        wc = appData.tableWorkingCopy;
        mask = appData.tableMask;
        if ~isempty(mask) && any(mask)
            wc = wc(~mask, :);
        end
        colNames = [{'X'}, d.labels];
        nC = size(wc, 2);

        statNames = {'Mean', 'Std', 'Median', 'Min', 'Max', 'Skewness', 'Kurtosis', 'N'};
        statData = cell(numel(statNames), nC);
        for ci = 1:nC
            col = wc(:, ci);
            col = col(~isnan(col));
            if isempty(col)
                for si = 1:numel(statNames), statData{si, ci} = NaN; end
                continue;
            end
            statData{1, ci} = mean(col);
            statData{2, ci} = std(col);
            statData{3, ci} = median(col);
            statData{4, ci} = min(col);
            statData{5, ci} = max(col);
            mu = mean(col); sg = std(col);
            if sg > 0
                statData{6, ci} = mean(((col - mu) / sg).^3);
                statData{7, ci} = mean(((col - mu) / sg).^4);
            else
                statData{6, ci} = 0;
                statData{7, ci} = 0;
            end
            statData{8, ci} = numel(col);
        end

        sFig = figure('Name', 'Descriptive Statistics', 'NumberTitle', 'off', ...
            'Units', 'pixels', 'Position', [300 200 max(400, nC*100) 300], ...
            'Tag', 'dpDescStats');
        sAx = axes(sFig, 'Visible', 'off');
        sAx.Position = [0 0 1 1];

        lines = {};
        lines{end+1} = sprintf('%-12s', '');
        for ci = 1:nC
            lines{end} = [lines{end} sprintf('  %12s', colNames{ci})];
        end
        lines{end+1} = repmat('-', 1, 12 + nC*14);
        for si = 1:numel(statNames)
            line = sprintf('%-12s', statNames{si});
            for ci = 1:nC
                v = statData{si, ci};
                if si == 8
                    line = [line sprintf('  %12d', round(v))]; %#ok<AGROW>
                else
                    line = [line sprintf('  %12.4g', v)]; %#ok<AGROW>
                end
            end
            lines{end+1} = line; %#ok<AGROW>
        end

        text(sAx, 0.02, 0.95, strjoin(lines, '\n'), ...
            'FontName', 'Courier New', 'FontSize', 10, ...
            'VerticalAlignment', 'top', 'Units', 'normalized', ...
            'Interpreter', 'none');

        setStatus(sprintf('Stats: %d columns, %d rows (excl. %d masked)', ...
            nC, size(wc, 1), sum(appData.tableMask)));
    end

    function onTableSort(direction)
    %ONTABLESORT  Sort the data table by the selected column.
        if isempty(appData.tableWorkingCopy), return; end
        sel = appData.tableSelection;
        if isempty(sel)
            sortCol = 1;
        else
            sortCol = sel(1, 2);
        end
        nDataCols = size(appData.tableWorkingCopy, 2);
        if sortCol > nDataCols
            sortCol = 1;
        end
        [~, idx] = sort(appData.tableWorkingCopy(:, sortCol), direction);
        appData.tableWorkingCopy = appData.tableWorkingCopy(idx, :);
        appData.tableMask = appData.tableMask(idx);
        refreshDataTable();
        setStatus(sprintf('Sorted by column %d (%s)', sortCol, direction));
    end

    function onTableSaveAs(~, ~)
    %ONTABLESAVEAS  Save the working copy (with edits) to a new file.
        if isempty(appData.tableWorkingCopy)
            uialert(fig, 'No data to save.', 'Save As');
            return;
        end

        [fn, fp] = uiputfile( ...
            {'*.csv', 'CSV (*.csv)'; '*.xlsx', 'Excel (*.xlsx)'}, ...
            'Save Table As');
        if isequal(fn, 0), return; end
        outPath = fullfile(fp, fn);

        try
            colNames = tblData.ColumnName;
            if strcmp(colNames{end}, 'Masked')
                colNames = colNames(1:end-1);
            end

            wc = appData.tableWorkingCopy;
            mask = appData.tableMask;
            if any(mask)
                answer = questdlg('Exclude masked rows from export?', ...
                    'Masked Rows', 'Exclude', 'Include All', 'Exclude');
                if strcmp(answer, 'Exclude')
                    wc = wc(~mask, :);
                end
            end

            [~, ~, ext] = fileparts(outPath);

            if strcmpi(ext, '.xlsx')
                headerCell = colNames(:)';
                unitsCell  = appData.tableUnits(:)';
                dataCell   = num2cell(wc);
                allCell    = [headerCell; unitsCell; dataCell];
                writecell(allCell, outPath);
            else
                fidOut = fopen(outPath, 'w');
                if fidOut == -1
                    error('Cannot open file: %s', outPath);
                end
                fprintf(fidOut, '%s\n', strjoin(colNames, ','));
                fprintf(fidOut, '%s\n', strjoin(appData.tableUnits, ','));
                fclose(fidOut);
                writematrix(wc, outPath, 'Delimiter', ',', ...
                    'WriteMode', 'append', 'Precision', 10);
            end
            setStatus(sprintf('Table saved: %s (%d rows + units)', fn, size(wc, 1)));
        catch ME
            uialert(fig, sprintf('Save failed:\n%s', ME.message), 'Error');
        end
    end

end
