function batchFitDialog(datasets, activeIdx, options)
%BATCHFITDIALOG  GUI for fitting a model across multiple datasets.
%
%   Syntax:
%       bosonPlotter.batchFitDialog(datasets, activeIdx)
%       bosonPlotter.batchFitDialog(datasets, activeIdx, StatusFcn=fcn)
%       bosonPlotter.batchFitDialog(datasets, activeIdx, ButtonColors=s)
%
%   Inputs:
%       datasets    cell array of dataset structs (each with .corrData / .data)
%       activeIdx   index into datasets of the currently active file
%
%   Options:
%       StatusFcn       function_handle  Called with a status string message.
%                       Default: @(~) [] (no-op)
%       ButtonColors    struct with fields:
%                         .primary  — RGB triple for primary action buttons
%                         .tool     — RGB triple for secondary tool buttons
%                         .fg       — RGB triple for button text (foreground)
%                       Default: standard BosonPlotter colours
%
%   Description:
%       Opens a ~600x520 dialog that lets the user:
%         1. Select which datasets to include (checkbox list on the left).
%         2. Pick a built-in model (same catalog as curveFitting dialog).
%         3. Set initial guesses and bounds in a parameter table.
%         4. Run fitting.batchFit on selected datasets.
%         5. View results table (params, R², chi², RMSE per dataset).
%         6. Plot parameter evolution vs dataset index.
%         7. Export results to CSV.

arguments
    datasets   cell
    activeIdx  (1,1) double = 1
    options.StatusFcn   function_handle = @(~) []
    options.ButtonColors struct = struct( ...
        'primary', [0.15 0.45 0.75], ...
        'tool',    [0.22 0.22 0.28], ...
        'fg',      [0.95 0.95 0.95])
    options.Appearance  struct = bosonPlotter.resolveStyle(styles.template('screen'))
end

if isempty(datasets)
    error('bosonPlotter:batchFitDialog:noDatasets', 'No datasets provided.');
end

BTN_PRIMARY = options.ButtonColors.primary;
BTN_TOOL    = options.ButtonColors.tool;
BTN_FG      = options.ButtonColors.fg;

% ════════════════════════════════════════════════════════════════════════
% Model library
% ════════════════════════════════════════════════════════════════════════

catalog = fitting.models();

% ════════════════════════════════════════════════════════════════════════
% Dataset labels
% ════════════════════════════════════════════════════════════════════════

N = numel(datasets);
dsLabels = cell(1, N);
for i = 1:N
    ds = datasets{i};
    if isstruct(ds) && isfield(ds, 'label') && ~isempty(ds.label)
        dsLabels{i} = char(ds.label);
    elseif isstruct(ds) && isfield(ds, 'name') && ~isempty(ds.name)
        dsLabels{i} = char(ds.name);
    else
        dsLabels{i} = sprintf('Dataset %d', i);
    end
end

% ════════════════════════════════════════════════════════════════════════
% State
% ════════════════════════════════════════════════════════════════════════

batchResult = [];   % struct from fitting.batchFit, filled after run

% ════════════════════════════════════════════════════════════════════════
% Build dialog figure
% ════════════════════════════════════════════════════════════════════════

dlg = uifigure('Name', 'Batch Fit', ...
    'Position', [150 80 700 540], 'Resize', 'on');

% Root layout: left panel | right panel
rootGL = uigridlayout(dlg, [1 2], ...
    'ColumnWidth', {160, '1x'}, ...
    'Padding', [8 8 8 8], 'ColumnSpacing', 8);

% ── Left panel: dataset checklist ───────────────────────────────────────
leftGL = uigridlayout(rootGL, [3 1], ...
    'RowHeight', {20, '1x', 22}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 4);
leftGL.Layout.Column = 1;

uilabel(leftGL, 'Text', 'Datasets', 'FontWeight', 'bold');

% Listbox with checkboxes — use uicheckboxgroup with items
% (MATLAB R2022b: use uibutton array; listbox does not support checkboxes)
% We use a scrollable panel containing checkboxes.
dsScrollPanel = uipanel(leftGL, 'BorderType', 'line', 'BackgroundColor', 'white');
dsScrollPanel.Layout.Row = 2;

% Place checkboxes inside the panel via a grid
checkboxes = gobjects(N, 1);
cbGrid = uigridlayout(dsScrollPanel, [N 1], ...
    'RowHeight', repmat({20}, 1, N), ...
    'Padding', [4 4 4 4], 'RowSpacing', 2);
for i = 1:N
    checkboxes(i) = uicheckbox(cbGrid, 'Text', dsLabels{i}, ...
        'Value', true, 'FontSize', 10, ...
        'Tooltip', dsLabels{i});
end

% Select all / none buttons
selBtnGL = uigridlayout(leftGL, [1 2], ...
    'ColumnWidth', {'1x','1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 4);
selBtnGL.Layout.Row = 3;
uibutton(selBtnGL, 'Text', 'All', 'FontSize', 9, ...
    'ButtonPushedFcn', @(~,~) setAllChecked(true));
uibutton(selBtnGL, 'Text', 'None', 'FontSize', 9, ...
    'ButtonPushedFcn', @(~,~) setAllChecked(false));

% ── Right panel: model + params + results ───────────────────────────────
rightGL = uigridlayout(rootGL, [6 1], ...
    'RowHeight', {50, 'fit', '1x', 22, 26, 26}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 6);
rightGL.Layout.Column = 2;

% ── Row 1: model picker ──────────────────────────────────────────────────
modelGL = uigridlayout(rightGL, [2 4], ...
    'RowHeight', {22, 22}, ...
    'ColumnWidth', {55, '1x', 65, '1x'}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 4, 'ColumnSpacing', 6);
modelGL.Layout.Row = 1;

uilabel(modelGL, 'Text', 'Model:', 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'right');
ddModel = uidropdown(modelGL, 'Items', {catalog.name}, ...
    'Value', catalog(1).name, ...
    'ValueChangedFcn', @(~,~) onModelChanged());
ddModel.Layout.Row = 1; ddModel.Layout.Column = 2;

uilabel(modelGL, 'Text', 'Channel:', 'HorizontalAlignment', 'right', 'FontSize', 10);
ddChannel = uidropdown(modelGL, 'Items', {'1'}, 'ItemsData', 1, 'Value', 1, ...
    'FontSize', 10);
ddChannel.Layout.Row = 1; ddChannel.Layout.Column = 4;

uilabel(modelGL, 'Text', 'Equation:', 'HorizontalAlignment', 'right', 'FontSize', 10);
lblEqn = uilabel(modelGL, 'Text', catalog(1).equation, ...
    'FontSize', 10, 'FontColor', [0.4 0.7 0.4], 'Interpreter', 'none');
lblEqn.Layout.Row = 2; lblEqn.Layout.Column = [2 4];

% Populate channel dropdown from active dataset
populateChannelDropdown();

% ── Row 2: parameter table (guesses + bounds) ────────────────────────────
tblParams = uitable(rightGL, ...
    'ColumnName', {'Parameter', 'Guess', 'Lower', 'Upper', 'Fixed'}, ...
    'ColumnEditable', [false, true, true, true, true], ...
    'ColumnFormat', {'char', 'numeric', 'numeric', 'numeric', 'logical'}, ...
    'ColumnWidth', {'auto', 70, 65, 65, 45}, ...
    'Data', {});
tblParams.Layout.Row = 2;

% ── Row 3: results panel (tabs: results table | param evolution plot) ────
tabGroup = uitabgroup(rightGL);
tabGroup.Layout.Row = 3;

tabResults = uitab(tabGroup, 'Title', 'Results Table');
tabPlot    = uitab(tabGroup, 'Title', 'Param Evolution');

% Results table inside tabResults
resTblGL = uigridlayout(tabResults, [1 1], 'Padding', [4 4 4 4]);
tblResults = uitable(resTblGL, ...
    'ColumnEditable', false, ...
    'Data', {});

% Plot axes inside tabPlot
plotGL = uigridlayout(tabPlot, [2 1], ...
    'RowHeight', {22, '1x'}, 'Padding', [4 4 4 4], 'RowSpacing', 4);
uilabel(plotGL, 'Text', 'Select a parameter from the results table to plot', ...
    'FontSize', 9, 'FontColor', [0.5 0.5 0.5], 'HorizontalAlignment', 'center');
evAxes = uiaxes(plotGL);
evAxes.Layout.Row = 2;
xlabel(evAxes, 'Dataset index');
ylabel(evAxes, 'Parameter value');
grid(evAxes, 'on');
bosonPlotter.applyAppearanceToAxes(evAxes, options.Appearance);

% ── Row 4: stats label ──────────────────────────────────────────────────
lblStats = uilabel(rightGL, 'Text', '', ...
    'FontSize', 9, 'FontColor', [0.5 0.5 0.5], 'Interpreter', 'html');
lblStats.Layout.Row = 4;

% ── Row 5: action buttons ────────────────────────────────────────────────
actionGL = uigridlayout(rightGL, [1 4], ...
    'ColumnWidth', {'1x', '1x', '1x', '1x'}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 6);
actionGL.Layout.Row = 5;

uibutton(actionGL, 'Text', 'Auto-Guess', ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'FontSize', 10, ...
    'Tooltip', 'Estimate initial parameters from first selected dataset', ...
    'ButtonPushedFcn', @(~,~) onAutoGuess());

btnRun = uibutton(actionGL, 'Text', 'Run Batch Fit', ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
    'FontWeight', 'bold', 'FontSize', 11, ...
    'ButtonPushedFcn', @(~,~) onRunBatch());

uibutton(actionGL, 'Text', 'Plot Params', ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'FontSize', 10, ...
    'Tooltip', 'Plot parameter evolution (run fit first)', ...
    'ButtonPushedFcn', @(~,~) onPlotEvolution());

uibutton(actionGL, 'Text', 'Export CSV', ...
    'FontSize', 10, ...
    'Tooltip', 'Export results table to CSV file', ...
    'ButtonPushedFcn', @(~,~) onExportCSV());

% ── Row 6: close ────────────────────────────────────────────────────────
closeGL = uigridlayout(rightGL, [1 2], ...
    'ColumnWidth', {'1x', 80}, 'Padding', [0 0 0 0], 'ColumnSpacing', 6);
closeGL.Layout.Row = 6;

uilabel(closeGL, 'Text', 'Tip: hover results table columns for tooltips', ...
    'FontSize', 8, 'FontColor', [0.6 0.6 0.6]);
uibutton(closeGL, 'Text', 'Close', 'FontSize', 10, ...
    'ButtonPushedFcn', @(~,~) delete(dlg));

% ════════════════════════════════════════════════════════════════════════
% Initialise
% ════════════════════════════════════════════════════════════════════════

onModelChanged();

% ════════════════════════════════════════════════════════════════════════
% Nested functions
% ════════════════════════════════════════════════════════════════════════

    function populateChannelDropdown()
    %POPULATECHANNELDROPDOWN  Build channel dropdown from active dataset.
        ds = datasets{min(activeIdx, N)};
        if isstruct(ds) && isfield(ds, 'corrData') && ...
                ~isempty(ds.corrData) && ~isempty(ds.corrData.time)
            plotD = ds.corrData;
        elseif isstruct(ds) && isfield(ds, 'data')
            plotD = ds.data;
        elseif isstruct(ds) && isfield(ds, 'time')
            plotD = ds;
        else
            return;
        end
        if isfield(plotD, 'labels') && ~isempty(plotD.labels)
            lbls = plotD.labels;
            ddChannel.Items     = lbls;
            ddChannel.ItemsData = 1:numel(lbls);
            ddChannel.Value     = 1;
        end
    end

    function onModelChanged()
    %ONMODELCHANGED  Refresh equation label and parameter table.
        mName = ddModel.Value;
        idx = find(strcmp({catalog.name}, mName), 1);
        if isempty(idx), return; end
        m = catalog(idx);
        lblEqn.Text = m.equation;
        populateParamTable(m.paramNames, m.p0, m.lb, m.ub);
    end

    function populateParamTable(pNames, p0, lb, ub)
    %POPULATEPARAMTABLE  Fill guess/bounds table.
        nP = numel(pNames);
        tData = cell(nP, 5);
        for pi = 1:nP
            tData{pi, 1} = pNames{pi};
            tData{pi, 2} = p0(pi);
            tData{pi, 3} = lb(pi);
            tData{pi, 4} = ub(pi);
            tData{pi, 5} = false;
        end
        tblParams.Data = tData;
    end

    function setAllChecked(val)
    %SETALLCHECKED  Toggle all dataset checkboxes on or off.
        for k = 1:N
            checkboxes(k).Value = val;
        end
    end

    function selIdx = getSelectedIndices()
    %GETSELECTEDINDICES  Return indices of checked datasets.
        selIdx = find(arrayfun(@(cb) cb.Value, checkboxes));
    end

    function [p0, lb, ub, fixedMask, pNames] = readParamTable()
    %READPARAMTABLE  Extract guess, bounds, fixed from parameter table.
        nP = size(tblParams.Data, 1);
        p0 = zeros(1, nP);
        lb = repmat(-Inf, 1, nP);
        ub = repmat(Inf, 1, nP);
        fixedMask = false(1, nP);
        pNames = cell(1, nP);
        for pi = 1:nP
            pNames{pi} = tblParams.Data{pi, 1};
            p0(pi)     = safeNum(tblParams.Data{pi, 2}, 0);
            lb(pi)     = safeNum(tblParams.Data{pi, 3}, -Inf);
            ub(pi)     = safeNum(tblParams.Data{pi, 4}, Inf);
            fixedMask(pi) = logical(tblParams.Data{pi, 5});
        end
    end

    function v = safeNum(val, default)
    %SAFENUM  Safely extract numeric value from a table cell.
        if isnumeric(val) && ~isempty(val)
            v = val;
        elseif ischar(val) || isstring(val)
            v = str2double(val);
            if isnan(v), v = default; end
        else
            v = default;
        end
    end

    function onAutoGuess()
    %ONAUTOGUESS  Fill guesses from the first selected dataset.
        selIdx = getSelectedIndices();
        if isempty(selIdx)
            uialert(dlg, 'No datasets selected.', 'Auto-Guess');
            return;
        end

        mName = ddModel.Value;
        ds = datasets{selIdx(1)};
        [xData, yData] = extractXY(ds, ddChannel.Value);
        if numel(xData) < 3
            uialert(dlg, 'Not enough data in first selected dataset.', 'Auto-Guess');
            return;
        end

        try
            p0g = fitting.autoGuess(mName, xData, yData);
            nP = size(tblParams.Data, 1);
            for pi = 1:min(numel(p0g), nP)
                tblParams.Data{pi, 2} = p0g(pi);
            end
            options.StatusFcn('Batch fit: auto-guess applied');
        catch ME
            options.StatusFcn(sprintf('Auto-guess failed: %s', ME.message));
        end
    end

    function onRunBatch()
    %ONRUNBATCH  Run fitting.batchFit on selected datasets.
        selIdx = getSelectedIndices();
        if isempty(selIdx)
            uialert(dlg, 'Select at least one dataset.', 'Batch Fit');
            return;
        end

        mName = ddModel.Value;
        mIdx = find(strcmp({catalog.name}, mName), 1);
        if isempty(mIdx)
            uialert(dlg, 'Unknown model.', 'Batch Fit');
            return;
        end
        m = catalog(mIdx);

        [p0, lb, ub, fixedMask, ~] = readParamTable();
        ch = ddChannel.Value;

        dlg.Pointer = 'watch'; drawnow;
        try
            selDs = datasets(selIdx);

            fitArgs = {'Lower', lb, 'Upper', ub, 'Channel', ch, ...
                'ModelName', mName, 'Verbose', false};
            if any(fixedMask)
                fitArgs = [fitArgs, {'Fixed', fixedMask}];
            end

            batchResult = fitting.batchFit(selDs, m.fcn, p0, fitArgs{:});
            batchResult.selectedIdx = selIdx;
            batchResult.dsLabels    = dsLabels(selIdx);

            updateResultsTable();
            options.StatusFcn(sprintf('Batch fit complete: %d datasets', numel(selIdx)));
            tabGroup.SelectedTab = tabResults;
        catch ME
            uialert(dlg, sprintf('Batch fit failed:\n%s', ME.message), 'Error');
            options.StatusFcn(sprintf('Batch fit error: %s', ME.message));
        end
        dlg.Pointer = 'arrow';
    end

    function updateResultsTable()
    %UPDATERESULTSTABLE  Populate the results uitable from batchResult.
        if isempty(batchResult), return; end

        M = numel(batchResult.paramNames);
        nSel = batchResult.nDatasets;

        % Column names: Dataset | p1 | p1_err | p2 | p2_err | ... | R2 | chi2 | RMSE | Conv
        colNames = {'Dataset'};
        for pi = 1:M
            colNames{end+1} = batchResult.paramNames{pi}; %#ok<AGROW>
            colNames{end+1} = [char(177) batchResult.paramNames{pi}]; %#ok<AGROW>
        end
        colNames = [colNames, {'R%s', 'chi%s', 'RMSE', 'Conv'}];
        % Replace format tokens
        colNames{end-3} = sprintf('R%s', char(178));
        colNames{end-2} = sprintf('%s%s', char(967), char(178));

        % Build data
        tData = cell(nSel, numel(colNames));
        for i = 1:nSel
            tData{i, 1} = batchResult.dsLabels{i};
            col = 2;
            for pi = 1:M
                tData{i, col}   = sprintf('%.5g', batchResult.params(i, pi));
                tData{i, col+1} = sprintf('%.3g', batchResult.errors(i, pi));
                col = col + 2;
            end
            tData{i, col}   = sprintf('%.5f', batchResult.R2(i));
            tData{i, col+1} = sprintf('%.4g', batchResult.chiSqRed(i));
            tData{i, col+2} = sprintf('%.4g', batchResult.RMSE(i));
            tData{i, col+3} = batchResult.converged(i);
        end

        tblResults.ColumnName    = colNames;
        tblResults.Data          = tData;
        tblResults.ColumnEditable = false(1, numel(colNames));

        % Stats summary
        convFrac = sum(batchResult.converged) / nSel;
        meanR2   = mean(batchResult.R2(~isnan(batchResult.R2)));
        lblStats.Text = sprintf( ...
            'Datasets: %d &nbsp; Converged: %d/%d (%.0f%%) &nbsp; Mean R%s = %.4f', ...
            nSel, sum(batchResult.converged), nSel, convFrac*100, ...
            char(178), meanR2);
    end

    function onPlotEvolution()
    %ONPLOTEVOLUTION  Plot each fitted parameter vs dataset index.
        if isempty(batchResult)
            uialert(dlg, 'Run batch fit first.', 'Plot Evolution');
            return;
        end

        M = numel(batchResult.paramNames);
        nSel = batchResult.nDatasets;
        xIdx = (1:nSel)';

        cla(evAxes);
        hold(evAxes, 'on');
        cmap = lines(M);
        legendEntries = cell(1, M);
        for pi = 1:M
            vals = batchResult.params(:, pi);
            errs = batchResult.errors(:, pi);
            clr  = cmap(pi, :);
            errorbar(evAxes, xIdx, vals, errs, 'o-', ...
                'Color', clr, 'MarkerFaceColor', clr, ...
                'MarkerSize', 5, 'LineWidth', 1.2, ...
                'DisplayName', batchResult.paramNames{pi});
            legendEntries{pi} = batchResult.paramNames{pi};
        end
        hold(evAxes, 'off');
        legend(evAxes, legendEntries, 'Location', 'best');
        xlabel(evAxes, 'Dataset index');
        ylabel(evAxes, 'Parameter value');
        title(evAxes, sprintf('%s — parameter evolution', batchResult.modelName));
        grid(evAxes, 'on');

        tabGroup.SelectedTab = tabPlot;
        options.StatusFcn('Parameter evolution plotted');
    end

    function onExportCSV()
    %ONEXPORTCSV  Write results table to a user-chosen CSV file.
        if isempty(batchResult)
            uialert(dlg, 'Run batch fit first.', 'Export CSV');
            return;
        end

        [fname, fpath] = uiputfile('*.csv', 'Save Batch Fit Results', ...
            'batch_fit_results.csv');
        if isequal(fname, 0), return; end

        filePath = fullfile(fpath, fname);
        M = numel(batchResult.paramNames);
        nSel = batchResult.nDatasets;

        % Build header
        header = {'Dataset'};
        for pi = 1:M
            header{end+1} = batchResult.paramNames{pi}; %#ok<AGROW>
            header{end+1} = [batchResult.paramNames{pi} '_err']; %#ok<AGROW>
        end
        header = [header, {'R2', 'chiSqRed', 'RMSE', 'Converged', 'ExitFlag'}];

        try
            fid = fopen(filePath, 'w');
            if fid < 0
                error('batchFitDialog:csvWrite', 'Cannot open file: %s', filePath);
            end
            fprintf(fid, '%s\n', strjoin(header, ','));
            for i = 1:nSel
                row = {batchResult.dsLabels{i}};
                for pi = 1:M
                    row{end+1} = sprintf('%.8g', batchResult.params(i,pi)); %#ok<AGROW>
                    row{end+1} = sprintf('%.6g', batchResult.errors(i,pi)); %#ok<AGROW>
                end
                row{end+1} = sprintf('%.8f', batchResult.R2(i));
                row{end+1} = sprintf('%.6g', batchResult.chiSqRed(i));
                row{end+1} = sprintf('%.6g', batchResult.RMSE(i));
                row{end+1} = num2str(batchResult.converged(i));
                row{end+1} = num2str(batchResult.exitFlags(i));
                fprintf(fid, '%s\n', strjoin(row, ','));
            end
            fclose(fid);
            options.StatusFcn(sprintf('Results exported to %s', filePath));
        catch ME
            try; fclose(fid); catch; end
            uialert(dlg, sprintf('Export failed:\n%s', ME.message), 'Export Error');
        end
    end

end  % batchFitDialog

% ════════════════════════════════════════════════════════════════════════
% Module-level helper — extract x,y from a dataset struct
% ════════════════════════════════════════════════════════════════════════

function [x, y] = extractXY(ds, channel)
%EXTRACTXY  Get x/y vectors from a dataset struct (mirrors batchFit.extractXY).
    if isstruct(ds)
        if isfield(ds, 'corrData') && ~isempty(ds.corrData) && ...
                isfield(ds.corrData, 'time') && ~isempty(ds.corrData.time)
            plotD = ds.corrData;
        elseif isfield(ds, 'data')
            plotD = ds.data;
        elseif isfield(ds, 'time')
            plotD = ds;
        else
            x = []; y = []; return;
        end
        x  = plotD.time(:);
        ch = min(channel, size(plotD.values, 2));
        y  = plotD.values(:, ch);
    elseif iscell(ds) && numel(ds) >= 2
        x = ds{1}(:);
        y = ds{2}(:);
    else
        x = []; y = [];
    end
end
