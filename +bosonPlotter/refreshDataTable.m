function refreshDataTable(appData, tblData, tblUnits, lblTableUnits, lblTableStats, callbacks)
%REFRESHDATATABLE  Populate the data-table panel from the active dataset.
%
%   Syntax:
%     bosonPlotter.refreshDataTable(appData, tblData, tblUnits, ...
%         lblTableUnits, lblTableStats, callbacks)
%
%   Inputs:
%     appData        - shared application state struct (handle)
%     tblData        - uitable handle for data rows
%     tblUnits       - uitable handle for the 1-row units header
%     lblTableUnits  - uilabel handle for the units-row hint text
%     lblTableStats  - uilabel handle for the row/col/masked summary
%     callbacks      - struct with function handles:
%       .getPlotDataFn       - @(idx) → data struct
%       .is2DDatasetFn       - @(ds) → logical
%       .applyMaskStylingFn  - @()
%       .syncUnitsColumnWidthsFn - @(nCols)
%
%   Description:
%     Syncs the spreadsheet data panel (tblData + tblUnits) from the active
%     dataset.  Row 1 is an editable units row (green text).  Rows 2+ are
%     data.  SIMS datasets with per-element original depths get paired
%     Depth/Conc columns instead of a single shared X column.
%
%   Examples:
%     bosonPlotter.refreshDataTable(appData, tblData, tblUnits, ...
%         lblTableUnits, lblTableStats, ...
%         struct('getPlotDataFn', @getPlotData, ...
%                'is2DDatasetFn', @is2DDataset, ...
%                'applyMaskStylingFn', @applyMaskStyling, ...
%                'syncUnitsColumnWidthsFn', @syncUnitsColumnWidths));

% ════════════════════════════════════════════════════════════════════════

    if appData.activeIdx < 1 || isempty(appData.datasets)
        tblData.ColumnName = {};
        tblData.Data = [];
        tblUnits.ColumnName = {'(no data)'};
        tblUnits.Data = {};
        lblTableUnits.Text = '';
        lblTableStats.Text = '';
        return;
    end

    % Skip table population for 2D datasets — the table is hidden and
    % the 1D projection data is not meaningful in 2D map mode.
    if callbacks.is2DDatasetFn(appData.datasets{appData.activeIdx})
        tblData.ColumnName = {};
        tblData.Data = [];
        tblUnits.ColumnName = {'(2D map — table hidden)'};
        tblUnits.Data = {};
        lblTableUnits.Text = '';
        lblTableStats.Text = '';
        return;
    end

    d = callbacks.getPlotDataFn(appData.activeIdx);
    ds2 = appData.datasets{appData.activeIdx};
    nRows = numel(d.time);

    % ── Detect SIMS per-element depth mode ────────────────────────────────
    isSIMSMultiDepth = false;
    if isfield(d.metadata, 'parserSpecific') ...
            && isfield(d.metadata.parserSpecific, 'originalDepths') ...
            && iscell(d.metadata.parserSpecific.originalDepths)
        origD = d.metadata.parserSpecific.originalDepths;
        origC = d.metadata.parserSpecific.originalConcentrations;
        if numel(origD) == size(d.values, 2) && numel(origD) > 1
            isSIMSMultiDepth = true;
        end
    end

    if isSIMSMultiDepth
        % ── SIMS paired columns: Depth_A | A | Depth_B | B | ... ──────────
        nElem = numel(origD);
        depthUnit = '';
        if isfield(d.metadata.parserSpecific, 'depthUnit')
            depthUnit = d.metadata.parserSpecific.depthUnit;
        end

        % Find max rows across all elements
        maxPts = max(cellfun(@numel, origD));

        % Build column names and units
        colNames = {};
        unitCells = {};
        for ei = 1:nElem
            colNames{end+1}  = ['Depth_' d.labels{ei}]; %#ok<AGROW>
            colNames{end+1}  = d.labels{ei}; %#ok<AGROW>
            unitCells{end+1} = depthUnit; %#ok<AGROW>
            if ei <= numel(d.units)
                unitCells{end+1} = d.units{ei}; %#ok<AGROW>
            else
                unitCells{end+1} = ''; %#ok<AGROW>
            end
        end

        % Build data matrix with NaN padding
        nDataCols = nElem * 2;
        dataMat = NaN(maxPts, nDataCols);
        for ei = 1:nElem
            dVec = origD{ei}(:);
            cVec = origC{ei}(:);
            nPts = numel(dVec);
            dataMat(1:nPts, 2*ei-1) = dVec;
            dataMat(1:nPts, 2*ei)   = cVec;
        end

        % Store working copy (no mask column)
        appData.tableWorkingCopy = dataMat;
        appData.tableEdited = false;
        nRows = maxPts;

        % Initialize mask
        if isfield(ds2, 'mask') && numel(ds2.mask) == nRows
            appData.tableMask = ~ds2.mask;
        elseif isempty(appData.tableMask) || numel(appData.tableMask) ~= nRows
            appData.tableMask = false(nRows, 1);
        end

        % Pure numeric data rows — ~10x faster scroll than num2cell.
        % Row cap keeps render cost bounded even on very long scans;
        % the full matrix lives in appData.tableWorkingCopy and is
        % still available for export / analysis.
        cap = min(nRows, appData.tableRowCap);
        tblData.ColumnName = {};
        tblData.Data = dataMat(1:cap, :);
        tblData.ColumnEditable = true(1, nDataCols);

        % Units row lives in its own 1-row uitable above tblData
        tblUnits.ColumnName = colNames;
        tblUnits.Data = unitCells;
        tblUnits.ColumnEditable = true(1, nDataCols);
        callbacks.syncUnitsColumnWidthsFn(nDataCols);

    else
        % ── Standard layout: single X + Y channels ────────────────────────
        xName = 'X';
        if isfield(d.metadata, 'parserSpecific') && isfield(d.metadata.parserSpecific, 'xLabel')
            xName = d.metadata.parserSpecific.xLabel;
        end

        colNames = [{xName}, d.labels];
        nCols = size(d.values, 2);

        xCol = d.time(:);
        yMat = d.values;

        if isfield(ds2, 'mask') && numel(ds2.mask) == nRows
            appData.tableMask = ~ds2.mask;
        elseif isempty(appData.tableMask) || numel(appData.tableMask) ~= nRows
            appData.tableMask = false(nRows, 1);
        end

        appData.tableWorkingCopy = [xCol, yMat];
        appData.tableEdited = false;

        % Units row: X unit + Y units.  Lives in its own 1-row
        % uitable above tblData so tblData.Data can be a pure
        % numeric matrix — the big scroll-performance win.
        xUnit = '';
        if isfield(d.metadata, 'xColumnUnit')
            xUnit = d.metadata.xColumnUnit;
        end
        unitCells = [{xUnit}, d.units];

        % Pure numeric data rows
        cap = min(nRows, appData.tableRowCap);
        tblData.ColumnName = {};
        tblData.Data = [xCol(1:cap), yMat(1:cap, :)];
        tblData.ColumnEditable = true(1, 1 + nCols);

        % Units table (1 row, editable)
        tblUnits.ColumnName = colNames;
        tblUnits.Data = unitCells;
        tblUnits.ColumnEditable = true(1, 1 + nCols);
        callbacks.syncUnitsColumnWidthsFn(1 + nCols);
    end

    % Store units for editing and export
    appData.tableUnits = unitCells;

    % Update units label (summary)
    if ~isempty(d.units)
        lblTableUnits.Text = '  Row 1 = editable units (green)  |  Right-click data rows to mask';
    else
        lblTableUnits.Text = '';
    end

    % Stats summary
    nMasked = sum(appData.tableMask);
    nDataCols2 = size(appData.tableWorkingCopy, 2);
    if nRows > appData.tableRowCap
        lblTableStats.Text = sprintf('Showing %d of %d rows, %d cols, %d masked  ', ...
            min(nRows, appData.tableRowCap), nRows, nDataCols2, nMasked);
    else
        lblTableStats.Text = sprintf('%d rows, %d cols, %d masked  ', ...
            nRows, nDataCols2, nMasked);
    end

    % Apply soft-red row highlighting for masked rows
    callbacks.applyMaskStylingFn();
end
