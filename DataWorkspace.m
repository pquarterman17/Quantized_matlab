function varargout = DataWorkspace(options)
%DATAWORKSPACE  Standalone spreadsheet-centric data workspace GUI.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   DataWorkspace
%   DataWorkspace(Visible='off')
%   api = DataWorkspace(Visible='off')
%
% ── Inputs ────────────────────────────────────────────────────────────────
%
%   Visible  'on' (default) | 'off'
%            Set to 'off' for headless / automated testing.
%   Model    [] (default) | dataWorkspace.WorkspaceModel
%            When provided, this model is shared with the caller (e.g.
%            BosonPlotter) so both GUIs observe the same dataset list.
%
% ── Outputs ───────────────────────────────────────────────────────────────
%
%   api      Struct with fields:
%              .fig          — uifigure handle
%              .addFiles(f)  — function handle: load file paths cell/char
%              .getModel()   — function handle: returns WorkspaceModel
%
% ── Examples ──────────────────────────────────────────────────────────────
%
%   DataWorkspace                              % interactive launch
%   api = DataWorkspace(Visible='off')         % headless for tests
%   api.addFiles({'data.dat'})
%   model = api.getModel();
%
%   % Shared-model launch from BosonPlotter:
%   m    = dataWorkspace.WorkspaceModel();
%   bpApi = BosonPlotter(Model=m);
%   dwApi = DataWorkspace(Model=m);
%
% ════════════════════════════════════════════════════════════════════════

arguments
    options.Visible (1,:) char {mustBeMember(options.Visible, {'on','off'})} = 'on'
    options.Model         = []   % existing WorkspaceModel (shared with BosonPlotter)
end

% ════════════════════════════════════════════════════════════════════════
%  Shared model
% ════════════════════════════════════════════════════════════════════════
if ~isempty(options.Model) && isa(options.Model, 'dataWorkspace.WorkspaceModel')
    model = options.Model;
else
    model = dataWorkspace.WorkspaceModel();
end

% ════════════════════════════════════════════════════════════════════════
%  Figure
% ════════════════════════════════════════════════════════════════════════
BG  = [0.15 0.15 0.15];   % figure / panel background
PAN = [0.18 0.18 0.18];   % left panel background
TBL = [0.13 0.13 0.13];   % table area background
FG  = [0.92 0.92 0.92];   % primary foreground text
BTN = [0.28 0.28 0.28];   % toolbar button background
ACC = [0.24 0.52 0.90];   % accent (selected / active)

fig = uifigure( ...
    'Name',            'Data Workspace', ...
    'Position',        [80 80 1200 660], ...
    'Color',           BG, ...
    'Visible',         options.Visible, ...
    'KeyPressFcn',     @onKeyPress, ...
    'CloseRequestFcn', @onClose);

% ── Help menu (Report a Bug) ─────────────────────────────────────────────
helpMenu = uimenu(fig, 'Text', '&Help');
uimenu(helpMenu, 'Text', 'Report a Bug...', ...
    'MenuSelectedFcn', @(~,~) onReportBug());

% ════════════════════════════════════════════════════════════════════════
%  Root grid: [toolbar ; content]
% ════════════════════════════════════════════════════════════════════════
rootGL = uigridlayout(fig, [3 1], ...
    'RowHeight',   {34, '1x', 26}, ...
    'ColumnWidth', {'1x'}, ...
    'Padding',     [4 4 4 4], ...
    'RowSpacing',  4, ...
    'BackgroundColor', BG);

% ════════════════════════════════════════════════════════════════════════
%  Toolbar row
% ════════════════════════════════════════════════════════════════════════
tbGL = uigridlayout(rootGL, [1 11], ...
    'ColumnWidth',   {90, 90, 90, 110, 110, 80, 110, 110, 110, '1x', 90}, ...
    'Padding',       [0 0 0 0], ...
    'ColumnSpacing', 4, ...
    'BackgroundColor', BG);
tbGL.Layout.Row = 1;

btnAddFiles = uibutton(tbGL, ...
    'Text',            [char(43) ' Add Files'], ...
    'Tooltip',         'Import files via parser.importAuto (Ctrl+V pastes clipboard)', ...
    'BackgroundColor', BTN, ...
    'FontColor',       FG, ...
    'FontSize',        10, ...
    'ButtonPushedFcn', @onAddFiles);
btnAddFiles.Layout.Column = 1;

btnRemove = uibutton(tbGL, ...
    'Text',            [char(8722) ' Remove'], ...
    'Tooltip',         'Remove selected dataset(s)', ...
    'BackgroundColor', BTN, ...
    'FontColor',       FG, ...
    'FontSize',        10, ...
    'ButtonPushedFcn', @onRemove);
btnRemove.Layout.Column = 2;

btnExport = uibutton(tbGL, ...
    'Text',            [char(8599) ' Export CSV'], ...
    'Tooltip',         'Export active dataset to CSV', ...
    'BackgroundColor', BTN, ...
    'FontColor',       FG, ...
    'FontSize',        10, ...
    'ButtonPushedFcn', @onExportCSV);
btnExport.Layout.Column = 3;

btnDsMath = uibutton(tbGL, ...
    'Text',            [char(8710) ' Dataset Math...'], ...
    'Tooltip',         'Apply arithmetic between two datasets', ...
    'BackgroundColor', BTN, ...
    'FontColor',       FG, ...
    'FontSize',        10, ...
    'ButtonPushedFcn', @onDatasetMath);
btnDsMath.Layout.Column = 4;

btnMerge = uibutton(tbGL, ...
    'Text',            [char(8614) ' Merge Columns...'], ...
    'Tooltip',         'Horizontally concatenate two datasets', ...
    'BackgroundColor', BTN, ...
    'FontColor',       FG, ...
    'FontSize',        10, ...
    'ButtonPushedFcn', @onMergeDatasets);
btnMerge.Layout.Column = 5;

btnPlot = uibutton(tbGL, ...
    'Text',            [char(9654) ' Plot...'], ...
    'Tooltip',         'Open in BosonPlotter (left-click: single instance; right-click: new window)', ...
    'BackgroundColor', BTN, ...
    'FontColor',       FG, ...
    'FontSize',        10, ...
    'ButtonPushedFcn', @onPlotSelected);
btnPlot.Layout.Column = 6;
% Right-click context menu for "Open New Plotter"
cmPlot = uicontextmenu(fig);
uimenu(cmPlot, 'Text', 'Open New Plotter', ...
    'MenuSelectedFcn', @(~,~) openNewBosonPlotter());
btnPlot.ContextMenu = cmPlot;

btnAddColumn = uibutton(tbGL, ...
    'Text',            [char(402) ' Add Column...'], ...
    'Tooltip',         'Add a computed column with a formula', ...
    'BackgroundColor', BTN, ...
    'FontColor',       FG, ...
    'FontSize',        10, ...
    'ButtonPushedFcn', @onAddColumn);
btnAddColumn.Layout.Column = 7;

btnSave = uibutton(tbGL, ...
    'Text',            [char(128190) ' Save Workspace...'], ...
    'Tooltip',         'Save all datasets to a .dwk file', ...
    'BackgroundColor', BTN, ...
    'FontColor',       FG, ...
    'FontSize',        10, ...
    'ButtonPushedFcn', @onSaveWorkspace);
btnSave.Layout.Column = 8;

btnLoad = uibutton(tbGL, ...
    'Text',            [char(128194) ' Load Workspace...'], ...
    'Tooltip',         'Load a previously saved .dwk workspace file', ...
    'BackgroundColor', BTN, ...
    'FontColor',       FG, ...
    'FontSize',        10, ...
    'ButtonPushedFcn', @onLoadWorkspace);
btnLoad.Layout.Column = 9;

% Spacer at column 10

lblStatus = uilabel(tbGL, ...
    'Text',                'No datasets loaded', ...
    'FontColor',           [0.6 0.6 0.6], ...
    'FontSize',            10, ...
    'HorizontalAlignment', 'right');
lblStatus.Layout.Column = 11;

% ════════════════════════════════════════════════════════════════════════
%  Content area: [left panel | table area]
% ════════════════════════════════════════════════════════════════════════
contentGL = uigridlayout(rootGL, [1 2], ...
    'ColumnWidth',   {180, '1x'}, ...
    'Padding',       [0 0 0 0], ...
    'ColumnSpacing', 4, ...
    'BackgroundColor', BG);
contentGL.Layout.Row = 2;

% ────────────────────────────────────────────────────────────────────────
%  Left panel: dataset list
% ────────────────────────────────────────────────────────────────────────
leftGL = uigridlayout(contentGL, [2 1], ...
    'RowHeight',     {20, '1x'}, ...
    'Padding',       [4 4 4 4], ...
    'RowSpacing',    4, ...
    'BackgroundColor', PAN);
leftGL.Layout.Column = 1;

lblDatasets = uilabel(leftGL, ...
    'Text',      'Datasets', ...
    'FontSize',  10, ...
    'FontColor', [0.6 0.6 0.6], ...
    'FontWeight','bold');
lblDatasets.Layout.Row = 1;

listDatasets = uilistbox(leftGL, ...
    'Items',             {}, ...
    'Multiselect',       'on', ...
    'BackgroundColor',   TBL, ...
    'FontColor',         FG, ...
    'FontSize',          10, ...
    'ValueChangedFcn',   @onDatasetSelected);
listDatasets.Layout.Row = 2;

% ────────────────────────────────────────────────────────────────────────
%  Right area: units label | filter bar | table | stats bar | status bar
%  Row layout: {18, 28, '1x', 22, 20}
% ────────────────────────────────────────────────────────────────────────
rightGL = uigridlayout(contentGL, [5 1], ...
    'RowHeight',   {18, 28, '1x', 22, 20}, ...
    'Padding',     [0 0 0 0], ...
    'RowSpacing',  2, ...
    'BackgroundColor', BG);
rightGL.Layout.Column = 2;

lblUnits = uilabel(rightGL, ...
    'Text',      'Units: —', ...
    'FontSize',  10, ...
    'FontColor', [0.55 0.55 0.55], ...
    'HorizontalAlignment', 'left');
lblUnits.Layout.Row = 1;

% ── Filter bar (row 2) — only shown for uitable fallback ────────────────
filterGL = uigridlayout(rightGL, [1 2], ...
    'ColumnWidth',   {'1x', 60}, ...
    'Padding',       [0 2 0 2], ...
    'ColumnSpacing', 4, ...
    'BackgroundColor', BG);
filterGL.Layout.Row = 2;

txtFilter = uieditfield(filterGL, ...
    'Value',           '', ...
    'Placeholder',     'Filter: e.g. Temperature > 300', ...
    'BackgroundColor', TBL, ...
    'FontColor',       FG, ...
    'FontSize',        10, ...
    'ValueChangedFcn', @onFilterChanged);
txtFilter.Layout.Column = 1;

btnClearFilter = uibutton(filterGL, ...
    'Text',            'Clear', ...
    'BackgroundColor', BTN, ...
    'FontColor',       FG, ...
    'FontSize',        9, ...
    'ButtonPushedFcn', @onClearFilter);
btnClearFilter.Layout.Column = 2;

% Data table — uispreadsheet on R2025a+, uitable on older releases
[tblData, isSpreadsheet] = dataWorkspace.createTableWidget(rightGL);
tblData.Data = table();
try
    tblData.FontSize        = 11;
    tblData.BackgroundColor = [TBL; [0.16 0.16 0.16]];
    tblData.FontColor       = FG;
catch
    % uispreadsheet does not support all uitable appearance properties
end
tblData.CellSelectionCallback = @onCellSelected;
tblData.ContextMenu           = buildContextMenu();
tblData.Layout.Row            = 3;

% Hide filter bar when uispreadsheet is active (has built-in filter)
if isSpreadsheet
    filterGL.Visible = 'off';
    rightGL.RowHeight{2} = 0;
end

% ── Stats bar (row 4) ────────────────────────────────────────────────────
lblStats = uilabel(rightGL, ...
    'Text',                '', ...
    'FontSize',            9, ...
    'FontName',            'Courier New', ...
    'FontColor',           [0.65 0.65 0.65], ...
    'HorizontalAlignment', 'left');
lblStats.Layout.Row = 4;

lblStatusBar = uilabel(rightGL, ...
    'Text',                '', ...
    'FontSize',            9, ...
    'FontColor',           [0.5 0.5 0.5], ...
    'HorizontalAlignment', 'left');
lblStatusBar.Layout.Row = 5;

% ════════════════════════════════════════════════════════════════════════
%  Dataset tab bar (bottom of figure, row 3 of rootGL)
%  Empty tabs act as sheet selectors — clicking activates the dataset.
% ════════════════════════════════════════════════════════════════════════
tabGroup = uitabgroup(rootGL, ...
    'SelectionChangedFcn', @onTabSelectionChanged);
tabGroup.Layout.Row = 3;

% ════════════════════════════════════════════════════════════════════════
%  GUI state
% ════════════════════════════════════════════════════════════════════════
linkedBP            = [];        % handle to linked BosonPlotter figure (single-instance)
state.selRows       = [];        % selected row indices in the table
state.selCols       = [];        % selected column indices in the table

% Sort state (uitable fallback only — uispreadsheet has built-in sort)
state.sortCol       = 0;         % 0 = unsorted; column index when active
state.sortDir       = 'ascend';  % 'ascend' | 'descend'
state.sortOrder     = [];        % [N×1] permutation index: display → data row

% Filter state (uitable fallback only — uispreadsheet has built-in filter)
state.filterMask    = [];        % [N×1] logical, true = row passes filter

% ════════════════════════════════════════════════════════════════════════
%  Model event listeners
% ════════════════════════════════════════════════════════════════════════
lsnData = addlistener(model, 'DataChanged',      @onModelDataChanged);
lsnSel  = addlistener(model, 'SelectionChanged', @onModelSelectionChanged);
lsnMask = addlistener(model, 'MaskChanged',      @onModelMaskChanged);

% Keep listeners alive in the GUI scope (handle objects — MATLAB will
% auto-delete them when they go out of scope, so we anchor them here).
% The cell is mutable so callbacks registered later in the session can
% append via addGuiListener() without getting garbage-collected at the
% end of the enclosing scope.
guiListeners = {lsnData, lsnSel, lsnMask};  %#ok<NASGU>

% Bootstrap the UI from any datasets already present in the shared
% model. Listeners only fire on NEW changes, so data added by another
% window (e.g. BosonPlotter's import path) before this workspace was
% opened must be rendered explicitly. addDataset already sets
% activeIdx=1 on the first add, so we just need to paint the widgets.
if model.count() > 0
    refreshDatasetList();
    refreshSelectionInList();
    refreshTable();
end

% ════════════════════════════════════════════════════════════════════════
%  API struct (for headless / automated testing)
% ════════════════════════════════════════════════════════════════════════
api.fig      = fig;
api.addFiles = @addFilesAPI;
api.getModel = @() model;

if nargout > 0
    varargout{1} = api;
end

% ════════════════════════════════════════════════════════════════════════
%  Autosave recovery check (runs after figure is visible)
% ════════════════════════════════════════════════════════════════════════
if strcmp(options.Visible, 'on') && dataWorkspace.WorkspaceAutosave.check()
    offerAutosaveRecovery();
end

% ════════════════════════════════════════════════════════════════════════
%  Toolbar callbacks
% ════════════════════════════════════════════════════════════════════════

    function onAddFiles(~, ~)
    %ONADDFILES  Open a file picker and import the chosen files.
        [fnames, fdir] = uigetfile( ...
            {'*.dat;*.csv;*.txt;*.xls;*.xlsx;*.xrdml;*.raw', ...
             'All supported files'; '*.*', 'All files'}, ...
            'Select data files', ...
            'MultiSelect', 'on');
        if isequal(fnames, 0), return; end
        if ischar(fnames)
            fnames = {fnames};
        end
        for k = 1:numel(fnames)
            fp = fullfile(fdir, fnames{k});
            loadSingleFile(fp);
        end
    end

    function onRemove(~, ~)
    %ONREMOVE  Remove the dataset(s) selected in the list box.
        if model.count() == 0, return; end
        idxToRemove = listDatasets.Value;   % integers from ItemsData
        if isempty(idxToRemove), return; end
        if ~isnumeric(idxToRemove)
            idxToRemove = cell2mat(idxToRemove);
        end
        % Remove in reverse order to keep remaining indices valid.
        idxToRemove = sort(idxToRemove(:).', 'descend');
        for k = 1:numel(idxToRemove)
            if idxToRemove(k) >= 1 && idxToRemove(k) <= model.count()
                model.removeDataset(idxToRemove(k));
            end
        end
    end

    function onExportCSV(~, ~)
    %ONEXPORTCSV  Export the active dataset to CSV.
        if model.activeIdx == 0, return; end
        data = model.getData(model.activeIdx);
        T    = buildTableFromData(data, model.getComputedColumns(model.activeIdx));
        [fname, fdir] = uiputfile('*.csv', 'Export CSV');
        if isequal(fname, 0), return; end
        try
            writetable(T, fullfile(fdir, fname));
            setStatusBar(sprintf('Exported: %s', fname));
        catch ME
            uialert(fig, ME.message, 'Export failed');
        end
    end

    function onAddColumn(~, ~)
    %ONADDCOLUMN  Open the Add Computed Column dialog.
        if model.activeIdx == 0
            uialert(fig, 'No active dataset. Load a file first.', 'Add Column');
            return;
        end
        showAddColumnDialog();
    end

    function onSaveWorkspace(~, ~)
    %ONSAVEWORKSPACE  Save all datasets to a .dwk workspace file.
        if model.count() == 0
            uialert(fig, 'No datasets to save.', 'Save Workspace');
            return;
        end
        % Suggest a filename derived from the first dataset
        ds1 = model.datasets{1};
        if isfield(ds1, 'metadata') && isfield(ds1.metadata, 'source') ...
                && ~isempty(ds1.metadata.source)
            [~, nm] = fileparts(ds1.metadata.source);
            defName = [nm '.dwk'];
        else
            defName = 'workspace.dwk';
        end
        [fname, fdir] = uiputfile('*.dwk', 'Save Workspace', defName);
        if isequal(fname, 0), return; end
        fp = fullfile(fdir, fname);
        try
            snap = model.createSnapshot();  %#ok<NASGU>
            save(fp, 'snap', '-v7.3');
            setStatusBar(sprintf('Workspace saved: %s', fname));
        catch ME
            uialert(fig, ME.message, 'Save Workspace failed');
        end
    end

    function onLoadWorkspace(~, ~)
    %ONLOADWORKSPACE  Load a .dwk workspace file and replace all model state.
        [fname, fdir] = uigetfile('*.dwk', 'Load Workspace');
        if isequal(fname, 0), return; end
        fp = fullfile(fdir, fname);
        try
            tmp = load(fp);
            if ~isfield(tmp, 'snap')
                error('Invalid workspace file: missing "snap" variable.');
            end
            model.pushUndo('before load workspace');
            model.restoreFromSnapshot(tmp.snap);
            % Restart autosave timer with the refreshed model
            dataWorkspace.WorkspaceAutosave.start(model);
            setStatusBar(sprintf('Workspace loaded: %s', fname));
        catch ME
            uialert(fig, ME.message, 'Load Workspace failed');
        end
    end

    function offerAutosaveRecovery()
    %OFFERAUTOSAVERECOVERY  Offer to restore the last autosave on startup.
        answer = uiconfirm(fig, ...
            ['A DataWorkspace autosave file was found. ' ...
             'This may indicate the previous session ended unexpectedly. ' ...
             'Restore the saved state?'], ...
            'Restore Autosave', ...
            'Options', {'Restore', 'Discard'}, ...
            'DefaultOption', 'Restore', ...
            'CancelOption',  'Discard');
        if strcmp(answer, 'Restore')
            try
                dataWorkspace.WorkspaceAutosave.restore(model);
                dataWorkspace.WorkspaceAutosave.start(model);
                setStatusBar('Autosave restored.');
            catch ME
                uialert(fig, ME.message, 'Autosave restore failed');
                dataWorkspace.WorkspaceAutosave.cleanup();
            end
        else
            dataWorkspace.WorkspaceAutosave.cleanup();
        end
    end

    function showAddColumnDialog(existingName, existingExpr, existingUnit)
    %SHOWADDCOLUMNDIALOG  Open a modal dialog for defining a computed column.
    %   existingName/Expr/Unit — if supplied, pre-fill the fields (Edit mode).
        if nargin < 1, existingName = ''; end
        if nargin < 2, existingExpr = ''; end
        if nargin < 3, existingUnit = ''; end

        isEditMode = ~isempty(existingName);

        dlgFig = uifigure( ...
            'Name',       'Add Computed Column', ...
            'Position',   [0 0 460 300], ...
            'Color',      BG, ...
            'Resize',     'off', ...
            'WindowStyle','modal');
        movegui(dlgFig, 'center');
        % Enter = commit, Escape = cancel (set after onCommit is defined below)

        dlgGL = uigridlayout(dlgFig, [6 2], ...
            'RowHeight',    {22, 22, 22, 60, 22, 34}, ...
            'ColumnWidth',  {100, '1x'}, ...
            'Padding',      [12 12 12 12], ...
            'RowSpacing',   6, ...
            'ColumnSpacing',8, ...
            'BackgroundColor', BG);

        % Column name
        uilabel(dlgGL, 'Text', 'Column name:', 'FontColor', FG, ...
            'FontSize', 10).Layout.Row = 1;
        txtName = uieditfield(dlgGL, 'Value', existingName, ...
            'BackgroundColor', TBL, 'FontColor', FG, 'FontSize', 10, ...
            'Placeholder', 'e.g. FieldSI');
        txtName.Layout.Row    = 1;
        txtName.Layout.Column = 2;

        % Unit
        uilabel(dlgGL, 'Text', 'Unit:', 'FontColor', FG, ...
            'FontSize', 10).Layout.Row = 2;
        txtUnit = uieditfield(dlgGL, 'Value', existingUnit, ...
            'BackgroundColor', TBL, 'FontColor', FG, 'FontSize', 10, ...
            'Placeholder', 'e.g. kA/m');
        txtUnit.Layout.Row    = 2;
        txtUnit.Layout.Column = 2;

        % Formula
        uilabel(dlgGL, 'Text', 'Formula:', 'FontColor', FG, ...
            'FontSize', 10).Layout.Row = 3;
        txtFormula = uieditfield(dlgGL, 'Value', existingExpr, ...
            'BackgroundColor', TBL, 'FontColor', FG, 'FontSize', 10, ...
            'Placeholder', 'e.g. col("Field") / 79.5775  or  $Field * pi');
        txtFormula.Layout.Row    = 3;
        txtFormula.Layout.Column = 2;
        txtFormula.ValueChangedFcn = @onFormulaEdited;

        % Preview area (row 4)
        lblPreviewHdr = uilabel(dlgGL, 'Text', 'Preview:', ...
            'FontColor', FG, 'FontSize', 10, 'VerticalAlignment', 'top');
        lblPreviewHdr.Layout.Row = 4;
        txtPreview = uitextarea(dlgGL, ...
            'Value',           {''}, ...
            'Editable',        'off', ...
            'BackgroundColor', TBL, ...
            'FontColor',       [0.6 0.85 0.6], ...
            'FontSize',        9, ...
            'FontName',        'Courier New');
        txtPreview.Layout.Row    = 4;
        txtPreview.Layout.Column = 2;

        % Error label (row 5)
        lblErr = uilabel(dlgGL, ...
            'Text',      '', ...
            'FontColor', [0.9 0.4 0.4], ...
            'FontSize',  9, ...
            'WordWrap',  'on');
        lblErr.Layout.Row        = 5;
        lblErr.Layout.Column     = [1 2];

        % Buttons (row 6)
        btnGL = uigridlayout(dlgGL, [1 3], ...
            'ColumnWidth',   {'1x', 80, 80}, ...
            'Padding',       [0 0 0 0], ...
            'ColumnSpacing', 6, ...
            'BackgroundColor', BG);
        btnGL.Layout.Row    = 6;
        btnGL.Layout.Column = [1 2];

        uibutton(btnGL, 'Text', '', 'BackgroundColor', BG, ...
            'Enable', 'off').Layout.Column = 1;  % spacer

        if isEditMode
            addLabel = 'Save';
        else
            addLabel = 'Add';
        end
        btnAdd = uibutton(btnGL, 'Text', addLabel, ...
            'BackgroundColor', ACC, 'FontColor', [1 1 1], 'FontSize', 10, ...
            'ButtonPushedFcn', @onCommit);
        btnAdd.Layout.Column = 2;

        uibutton(btnGL, 'Text', 'Cancel', ...
            'BackgroundColor', BTN, 'FontColor', FG, 'FontSize', 10, ...
            'ButtonPushedFcn', @(~,~) delete(dlgFig)).Layout.Column = 3;

        % Pre-fill preview if editing
        if isEditMode
            updatePreview(existingExpr);
        end

        % Enter commits, Escape cancels — matches standard modal-dialog
        % muscle memory. Wired here (after onCommit is defined as a
        % nested function) so the handler closures resolve correctly.
        dlgFig.KeyPressFcn = @(~, evt) dlgKey(evt);

        function dlgKey(evt)
            switch evt.Key
                case {'return', 'enter'}
                    onCommit([], []);
                case 'escape'
                    delete(dlgFig);
            end
        end

        function onFormulaEdited(~, ~)
            updatePreview(txtFormula.Value);
        end

        function updatePreview(expr)
            if isempty(strtrim(expr))
                txtPreview.Value = {''};
                lblErr.Text      = '';
                return;
            end
            try
                data   = model.getData(model.activeIdx);
                result = dataWorkspace.FormulaEngine.evaluate(string(expr), data);
                N      = numel(result);
                nShow  = min(10, N);
                lines  = cell(1, nShow + 1);
                lines{1} = sprintf('First %d of %d values:', nShow, N);
                for ki = 1:nShow
                    lines{ki+1} = sprintf('  [%d]  %g', ki, result(ki));
                end
                txtPreview.Value = lines;
                lblErr.Text      = '';
            catch ME
                txtPreview.Value = {''};
                lblErr.Text      = ME.message;
            end
        end

        function onCommit(~, ~)
            colName = strtrim(txtName.Value);
            expr    = strtrim(txtFormula.Value);
            unit    = strtrim(txtUnit.Value);

            if isempty(colName)
                lblErr.Text = 'Column name is required.';
                return;
            end
            if isempty(expr)
                lblErr.Text = 'Formula is required.';
                return;
            end

            dsIdx = model.activeIdx;
            try
                if isEditMode
                    % Remove the old column and re-add with (possibly new) name/expr
                    model.removeComputedColumn(dsIdx, existingName);
                end
                model.addComputedColumn(dsIdx, colName, expr, unit);
                delete(dlgFig);
                setStatusBar(sprintf('Computed column "%s" added.', colName));
            catch ME
                lblErr.Text = ME.message;
            end
        end
    end  % showAddColumnDialog

% ════════════════════════════════════════════════════════════════════════
%  Dataset list callbacks
% ════════════════════════════════════════════════════════════════════════

    function onDatasetSelected(~, evt)
    %ONDATASETSELECTED  Switch the active dataset when the list selection changes.
        if model.count() == 0, return; end
        idx = evt.Value;   % integer from ItemsData
        if isempty(idx), return; end
        if iscell(idx),   idx = idx{1}; end       % multi-select — use first
        if ~isnumeric(idx), return; end
        idx = idx(1);
        if idx >= 1 && idx <= model.count()
            model.setActive(idx);
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  Table callbacks
% ════════════════════════════════════════════════════════════════════════

    function onCellSelected(~, evt)
    %ONCELLSELECTED  Track selected rows/columns; update stats bar.
        if ~isempty(evt.Indices)
            state.selRows = unique(evt.Indices(:,1));
            state.selCols = unique(evt.Indices(:,2));
        end
        refreshStatsBar();
    end

% ════════════════════════════════════════════════════════════════════════
%  Context menu for row masking
% ════════════════════════════════════════════════════════════════════════

    function cm = buildContextMenu()
    %BUILDCONTEXTMENU  Build the right-click context menu for the data table.
        cm = uicontextmenu(fig);
        % Sort items — only wired when uitable fallback is active
        if ~isSpreadsheet
            uimenu(cm, 'Text', 'Sort Ascending',  'MenuSelectedFcn', @onSortAscending);
            uimenu(cm, 'Text', 'Sort Descending', 'MenuSelectedFcn', @onSortDescending);
            uimenu(cm, 'Text', 'Clear Sort',      'MenuSelectedFcn', @onClearSort, ...
                'Separator', 'on');
        end
        % Column reorder items
        uimenu(cm, 'Text', 'Move Column Left',    'MenuSelectedFcn', @onMoveColLeft,  'Separator', 'on');
        uimenu(cm, 'Text', 'Move Column Right',   'MenuSelectedFcn', @onMoveColRight);
        uimenu(cm, 'Text', 'Move Column to Start','MenuSelectedFcn', @onMoveColStart);
        uimenu(cm, 'Text', 'Mask selected rows', 'MenuSelectedFcn', @onMaskRows, 'Separator', 'on');
        uimenu(cm, 'Text', 'Unmask selected rows', 'MenuSelectedFcn', @onUnmaskRows);
        uimenu(cm, 'Text', 'Unmask all rows',      'MenuSelectedFcn', @onUnmaskAll, 'Separator', 'on');
        % Computed column operations (shown when a computed column is selected)
        uimenu(cm, 'Text', 'Edit Formula...',    'MenuSelectedFcn', @onEditFormula,   'Separator', 'on');
        uimenu(cm, 'Text', 'Remove Column',      'MenuSelectedFcn', @onRemoveColumn);
        % Error bar designation
        uimenu(cm, 'Text', 'Set as Error Bar for...', 'MenuSelectedFcn', @onSetErrorBar, 'Separator', 'on');
        uimenu(cm, 'Text', 'Clear Error Bar Role',    'MenuSelectedFcn', @onClearErrorBar);
    end

    function onMaskRows(~, ~)
    %ONMASKROWS  Set selected rows to masked (false) in the model.
        if model.activeIdx == 0 || isempty(state.selRows), return; end
        idx = model.activeIdx;
        m   = model.mask{idx};
        m(state.selRows) = false;
        model.setMask(idx, m);
    end

    function onUnmaskRows(~, ~)
    %ONUNMASKROWS  Clear mask on selected rows (set to true = included).
        if model.activeIdx == 0 || isempty(state.selRows), return; end
        idx = model.activeIdx;
        m   = model.mask{idx};
        m(state.selRows) = true;
        model.setMask(idx, m);
    end

    function onUnmaskAll(~, ~)
    %ONUNMASKALL  Reset the entire row mask to all-included.
        if model.activeIdx == 0, return; end
        idx = model.activeIdx;
        n   = numel(model.datasets{idx}.time);
        model.setMask(idx, true(n, 1));
    end

    function onEditFormula(~, ~)
    %ONEDITFORMULA  Open the Add Column dialog pre-filled for the selected column.
        if model.activeIdx == 0 || isempty(state.selCols), return; end
        dsIdx = model.activeIdx;
        data  = model.getData(dsIdx);
        cols  = model.getComputedColumns(dsIdx);
        if isempty(cols), return; end

        % Determine the column index within computed columns.
        % Table layout: 1 X col + M value cols + computed cols.
        nRegular = 1 + size(data.values, 2);  % X + value columns
        tblCol   = state.selCols(1);
        if tblCol <= nRegular, return; end  % not a computed column

        compIdx = tblCol - nRegular;
        if compIdx < 1 || compIdx > numel(cols), return; end
        entry = cols{compIdx};
        showAddColumnDialog(entry.name, entry.expression, entry.unit);
    end

    function onRemoveColumn(~, ~)
    %ONREMOVECOLUMN  Remove the computed column for the selected table column.
        if model.activeIdx == 0 || isempty(state.selCols), return; end
        dsIdx = model.activeIdx;
        data  = model.getData(dsIdx);
        cols  = model.getComputedColumns(dsIdx);
        if isempty(cols), return; end

        nRegular = 1 + size(data.values, 2);
        tblCol   = state.selCols(1);
        if tblCol <= nRegular, return; end

        compIdx = tblCol - nRegular;
        if compIdx < 1 || compIdx > numel(cols), return; end
        colName  = cols{compIdx}.name;

        answer = uiconfirm(fig, ...
            sprintf('Remove computed column "%s"?', colName), ...
            'Remove Column', ...
            'Options', {'Remove', 'Cancel'}, ...
            'DefaultOption', 'Cancel', ...
            'CancelOption',  'Cancel');
        if strcmp(answer, 'Remove')
            model.removeComputedColumn(dsIdx, colName);
            setStatusBar(sprintf('Computed column "%s" removed.', colName));
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  Error bar callbacks
% ════════════════════════════════════════════════════════════════════════

    function onSetErrorBar(~, ~)
    %ONSETERRORBAR  Designate the selected column as error bars for a Y column.
    %   The selected column is the error column (errColIdx).
    %   A dialog lists other value columns to attach to.
        if model.activeIdx == 0 || isempty(state.selCols), return; end
        dsIdx  = model.activeIdx;
        data   = model.getData(dsIdx);
        nVal   = size(data.values, 2);
        if nVal < 2, return; end

        % Selected column in the table (col 1 = X, cols 2.. = value columns)
        tblCol   = state.selCols(1);
        errValIdx = tblCol - 1;  % 1-based into .values
        if errValIdx < 1 || errValIdx > nVal, return; end

        % Build list of other Y columns
        labels = data.labels;
        while numel(labels) < nVal
            labels{end+1} = sprintf('Col%d', numel(labels)+1);  %#ok<AGROW>
        end
        otherIdx  = setdiff(1:nVal, errValIdx);
        otherLbls = labels(otherIdx);

        if isempty(otherLbls)
            uialert(fig, 'No other Y columns available.', 'Set Error Bar');
            return;
        end

        % Pick via listdlg-style modal
        [sel, ok] = showColumnPickerDialog( ...
            'Set as Error Bar for:', otherLbls, 'Set Error Bar');
        if ~ok || isempty(sel), return; end

        yColIdx = otherIdx(sel);
        roles = model.getColumnRoles(dsIdx);
        roles = roles.setErrorFor(yColIdx, errValIdx);
        model.pushUndo('set error bar');
        model.setColumnRoles(dsIdx, roles);
        setStatusBar(sprintf('Column "%s" set as error bars for "%s".', ...
            labels{errValIdx}, labels{yColIdx}));
    end

    function onClearErrorBar(~, ~)
    %ONCLEARERRORBAR  Clear the error bar designation from the selected column.
    %   The selected column is treated as the Y column whose error bar designation
    %   should be removed.
        if model.activeIdx == 0 || isempty(state.selCols), return; end
        dsIdx    = model.activeIdx;
        data     = model.getData(dsIdx);
        nVal     = size(data.values, 2);
        tblCol   = state.selCols(1);
        yValIdx  = tblCol - 1;
        if yValIdx < 1 || yValIdx > nVal, return; end

        roles = model.getColumnRoles(dsIdx);
        if roles.getErrorFor(yValIdx) == 0
            setStatusBar('No error bar designation to clear for this column.');
            return;
        end
        roles = roles.clearErrorFor(yValIdx);
        model.pushUndo('clear error bar');
        model.setColumnRoles(dsIdx, roles);
        setStatusBar('Error bar designation cleared.');
    end

    function [sel, ok] = showColumnPickerDialog(prompt, items, title)
    %SHOWCOLUMNPICKERDIALOG  Compact modal list picker; returns 1-based index.
        sel = [];
        ok  = false;

        dlg = uifigure('Name', title, ...
            'Position',    [0 0 300 200], ...
            'Color',       BG, ...
            'Resize',      'off', ...
            'WindowStyle', 'modal', ...
            'KeyPressFcn', @(~, evt) pickerKey(evt));
        movegui(dlg, 'center');

        dlgGL = uigridlayout(dlg, [3 2], ...
            'RowHeight',    {20, '1x', 34}, ...
            'ColumnWidth',  {'1x', 80}, ...
            'Padding',      [10 10 10 10], ...
            'RowSpacing',   6, ...
            'BackgroundColor', BG);

        lbl = uilabel(dlgGL, 'Text', prompt, 'FontColor', FG, 'FontSize', 10);
        lbl.Layout.Row    = 1;
        lbl.Layout.Column = [1 2];

        lst = uilistbox(dlgGL, 'Items', items, ...
            'BackgroundColor', TBL, 'FontColor', FG, 'FontSize', 10);
        lst.Layout.Row    = 2;
        lst.Layout.Column = [1 2];

        uibutton(dlgGL, 'Text', 'OK', ...
            'BackgroundColor', ACC, 'FontColor', [1 1 1], 'FontSize', 10, ...
            'ButtonPushedFcn', @doOK).Layout.Column = 1;
        uibutton(dlgGL, 'Text', 'Cancel', ...
            'BackgroundColor', BTN, 'FontColor', FG, 'FontSize', 10, ...
            'ButtonPushedFcn', @(~,~) delete(dlg)).Layout.Column = 2;

        uiwait(dlg);

        function doOK(~, ~)
            sel = find(strcmp(items, lst.Value), 1);
            ok  = true;
            delete(dlg);
        end

        function pickerKey(evt)
            switch evt.Key
                case {'return','enter'}, doOK([], []);
                case 'escape',           delete(dlg);
            end
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  Column reorder callbacks
% ════════════════════════════════════════════════════════════════════════

    function onMoveColLeft(~, ~)
    %ONMOVECOLLEFT  Move the right-clicked (selected) value column one step left.
        reorderColumn('left');
    end

    function onMoveColRight(~, ~)
    %ONMOVECOLRIGHT  Move the right-clicked value column one step right.
        reorderColumn('right');
    end

    function onMoveColStart(~, ~)
    %ONMOVECOLSTART  Move the right-clicked value column to the first position.
        reorderColumn('start');
    end

    function reorderColumn(direction)
    %REORDERCOLUMN  Compute new display order and call model.setColumnRoles.
    %
    %   direction — 'left' | 'right' | 'start'
    %
    %   Table col 1 = X axis (.time); value columns start at table col 2.
        if model.activeIdx == 0 || isempty(state.selCols), return; end

        dsIdx = model.activeIdx;
        roles = model.getColumnRoles(dsIdx);
        nCols = roles.numColumns();
        if nCols < 2, return; end

        % Map table column → value column index (col 1 is X, skipped)
        tblCol = state.selCols(1);
        valCol = tblCol - 1;
        if valCol < 1 || valCol > nCols, return; end

        % Find position of valCol in the current displayOrder
        order = roles.displayOrder;
        pos   = find(order == valCol, 1);
        if isempty(pos), return; end

        switch direction
            case 'left'
                if pos <= 1, return; end
                newPos = pos - 1;
            case 'right'
                if pos >= nCols, return; end
                newPos = pos + 1;
            case 'start'
                if pos == 1, return; end
                newPos = 1;
            otherwise
                return;
        end

        % Build new order: remove element at pos, insert at newPos
        newOrder      = order;
        newOrder(pos) = [];
        newOrder = [newOrder(1:newPos-1), order(pos), newOrder(newPos:end)];

        model.pushUndo(sprintf('reorder column %s', direction));
        model.setColumnRoles(dsIdx, roles.reorder(newOrder));
        setStatusBar(sprintf('Column moved %s', direction));
    end

% ════════════════════════════════════════════════════════════════════════
%  Dataset math callbacks
% ════════════════════════════════════════════════════════════════════════

    function onDatasetMath(~, ~)
    %ONDATASETMATH  Open the dataset arithmetic dialog.
        if model.count() < 2
            uialert(fig, 'At least two datasets are required.', 'Dataset Math');
            return;
        end
        showDatasetMathDialog('+');
    end

    function showDatasetMathDialog(defaultOp)
    %SHOWDATASETMATHDIALOG  Modal dialog: choose A, op, B then compute.
        n     = model.count();
        names = cell(1, n);
        for k = 1:n
            names{k} = getDatasetNameLocal(k);
        end

        dlg = uifigure('Name', 'Dataset Math', ...
            'Position', [200 300 360 200], ...
            'WindowStyle', 'modal', ...
            'KeyPressFcn', @(~, evt) mathKey(evt));
        dlgGL = uigridlayout(dlg, [4 3], ...
            'RowHeight',   {30, 30, 30, 36}, ...
            'ColumnWidth', {100, 80, 100}, ...
            'Padding',     [12 12 12 12], ...
            'RowSpacing',  8);

        uilabel(dlgGL, 'Text', 'Dataset A:', 'HorizontalAlignment', 'right');
        ddA = uidropdown(dlgGL, 'Items', names, 'Value', names{1});
        ddA.Layout.Column = [2 3];

        uilabel(dlgGL, 'Text', 'Operation:', 'HorizontalAlignment', 'right');
        ddOp = uidropdown(dlgGL, 'Items', {'+', '-', '*', '/', 'Ratio (A/B)'}, ...
            'Value', defaultOp);
        ddOp.Layout.Column = [2 3];

        uilabel(dlgGL, 'Text', 'Dataset B:', 'HorizontalAlignment', 'right');
        idxBDefault = min(2, n);
        ddB = uidropdown(dlgGL, 'Items', names, 'Value', names{idxBDefault});
        ddB.Layout.Column = [2 3];

        uibutton(dlgGL, 'Text', 'Cancel', ...
            'ButtonPushedFcn', @(~,~) delete(dlg));
        btnCompute = uibutton(dlgGL, 'Text', 'Compute', ...
            'ButtonPushedFcn', @doCompute);
        btnCompute.Layout.Column = [2 3];

        function doCompute(~, ~)
            idxA  = find(strcmp(names, ddA.Value), 1);
            idxB  = find(strcmp(names, ddB.Value), 1);
            opStr = ddOp.Value;
            if strcmp(opStr, 'Ratio (A/B)'), opStr = 'ratio'; end
            try
                result = model.datasetMath(idxA, opStr, idxB);
                model.addDataset(result, result.metadata.source, 'datasetMath');
                setStatusBar(sprintf('Created: %s', result.metadata.source));
                delete(dlg);
            catch ME
                uialert(dlg, sprintf('Dataset Math (%s %s %s) failed:\n\n%s', ...
                    ddA.Value, ddOp.Value, ddB.Value, ME.message), ...
                    'Dataset Math Error');
            end
        end

        function mathKey(evt)
            switch evt.Key
                case {'return','enter'}, doCompute([], []);
                case 'escape',           delete(dlg);
            end
        end
    end

    function onMergeDatasets(~, ~)
    %ONMERGEDATASETS  Open the merge-columns dialog.
        if model.count() < 2
            uialert(fig, 'At least two datasets are required.', 'Merge Columns');
            return;
        end
        showMergeDialog();
    end

    function showMergeDialog()
    %SHOWMERGEDIALOG  Modal dialog: choose A and B then merge columns.
        n     = model.count();
        names = cell(1, n);
        for k = 1:n
            names{k} = getDatasetNameLocal(k);
        end

        dlg = uifigure('Name', 'Merge Columns', ...
            'Position', [200 320 320 160], ...
            'WindowStyle', 'modal', ...
            'KeyPressFcn', @(~, evt) mergeKey(evt));
        dlgGL = uigridlayout(dlg, [3 3], ...
            'RowHeight',   {30, 30, 36}, ...
            'ColumnWidth', {100, 80, 80}, ...
            'Padding',     [12 12 12 12], ...
            'RowSpacing',  8);

        uilabel(dlgGL, 'Text', 'Base (A):', 'HorizontalAlignment', 'right');
        ddA = uidropdown(dlgGL, 'Items', names, 'Value', names{1});
        ddA.Layout.Column = [2 3];

        uilabel(dlgGL, 'Text', 'Append (B):', 'HorizontalAlignment', 'right');
        idxBDefault = min(2, n);
        ddB = uidropdown(dlgGL, 'Items', names, 'Value', names{idxBDefault});
        ddB.Layout.Column = [2 3];

        uibutton(dlgGL, 'Text', 'Cancel', ...
            'ButtonPushedFcn', @(~,~) delete(dlg));
        btnMerge = uibutton(dlgGL, 'Text', 'Merge', ...
            'ButtonPushedFcn', @doMerge);
        btnMerge.Layout.Column = [2 3];

        function doMerge(~, ~)
            idxA = find(strcmp(names, ddA.Value), 1);
            idxB = find(strcmp(names, ddB.Value), 1);
            try
                result = model.mergeDatasets(idxA, idxB);
                model.addDataset(result, result.metadata.source, 'mergeDatasets');
                setStatusBar(sprintf('Created: %s', result.metadata.source));
                delete(dlg);
            catch ME
                uialert(dlg, sprintf('Merge (%s + %s) failed:\n\n%s', ...
                    ddA.Value, ddB.Value, ME.message), 'Merge Error');
            end
        end

        function mergeKey(evt)
            switch evt.Key
                case {'return','enter'}, doMerge([], []);
                case 'escape',           delete(dlg);
            end
        end
    end

    function name = getDatasetNameLocal(idx)
    %GETDATASETNAMELOCAL  Return a short display name for dataset idx.
        ds = model.datasets{idx};
        if isfield(ds, 'metadata') && isfield(ds.metadata, 'source') ...
                && ~isempty(ds.metadata.source)
            [~, nm, ext] = fileparts(ds.metadata.source);
            name = [nm ext];
        else
            name = sprintf('Dataset%d', idx);
        end
    end

    function onReportBug()
    %ONREPORTBUG  Open the Report-a-Bug dialog with the active dataset.
        if model.activeIdx > 0 && model.activeIdx <= model.count()
            ds = model.datasets{model.activeIdx};
            bugReport.reportBug(Source="DataWorkspace", Dataset=ds);
        else
            bugReport.reportBug(Source="DataWorkspace");
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  Clipboard paste-to-import  (Ctrl+V)
% ════════════════════════════════════════════════════════════════════════

    function onKeyPress(~, evt)
    %ONKEYPRESS  Handle figure-level keyboard shortcuts.
    %   Ctrl+V — paste from clipboard
    %   Ctrl+S — save workspace session (if the callback exists in this
    %            build — the helper is only present in builds with the
    %            save-as-session toolbar action wired up)
    %   Delete — remove the currently selected dataset, matching the
    %            BosonPlotter dataset-list convention so the two GUIs
    %            feel consistent.
        if any(strcmp(evt.Modifier, 'control'))
            switch evt.Key
                case 'v'
                    onPasteFromClipboard();
                case 's'
                    try
                        onSaveWorkspace([], []);
                    catch
                        % No-op if the save callback isn't defined in
                        % this build — Ctrl+S then silently does nothing.
                    end
            end
            return;
        end
        if strcmp(evt.Key, 'delete')
            try
                onRemove([], []);
            catch
                % onRemove handles the "nothing selected" case itself.
            end
        end
    end

    function onPasteFromClipboard()
    %ONPASTEFROMCLIPBOARD  Read clipboard text and create a new dataset.
        txt = clipboard('paste');
        if isempty(strtrim(txt))
            setStatusBar('Clipboard is empty.');
            return;
        end
        try
            data = parseClipboardText(txt);
            model.addDataset(data, 'clipboard', 'paste');
            setStatusBar(sprintf('Pasted %d rows from clipboard.', numel(data.time)));
        catch ME
            uialert(fig, ME.message, 'Clipboard Import Failed');
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  Plot in BosonPlotter
% ════════════════════════════════════════════════════════════════════════

    function onPlotSelected(~, ~)
    %ONPLOTSELECTED  Open BosonPlotter with the shared model (single instance).
    %   Reuses an already-open BosonPlotter by bringing it to front.
    %   Right-click the button for "Open New Plotter".
        if ~isempty(linkedBP) && isvalid(linkedBP)
            figure(linkedBP);   % bring existing window to front
            return;
        end
        try
            bpApi    = BosonPlotter(Model=model, Visible='on');
            linkedBP = bpApi.fig;
            setStatusBar('Opened BosonPlotter with shared model.');
        catch ME
            uialert(fig, ME.message, 'BosonPlotter failed to open');
        end
    end

    function openNewBosonPlotter()
    %OPENNEWBOSONPLOTTER  Open a fresh BosonPlotter (ignores single-instance rule).
        try
            BosonPlotter(Model=model, Visible='on');
        catch ME
            uialert(fig, ME.message, 'BosonPlotter failed to open');
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  Sort callbacks (uitable fallback only)
% ════════════════════════════════════════════════════════════════════════

    function onSortAscending(~, ~)
    %ONSORTASCENDING  Sort by the right-clicked column, ascending.
        if isempty(state.selCols), return; end
        applySort(state.selCols(1), 'ascend');
    end

    function onSortDescending(~, ~)
    %ONSORTDESCENDING  Sort by the right-clicked column, descending.
        if isempty(state.selCols), return; end
        applySort(state.selCols(1), 'descend');
    end

    function onClearSort(~, ~)
    %ONCLEARSORT  Remove sort and restore original row order.
        state.sortCol   = 0;
        state.sortDir   = 'ascend';
        state.sortOrder = [];
        refreshTable();
    end

    function applySort(col, dir)
    %APPLYSORT  Sort visible rows by column col in direction dir.
        if model.activeIdx == 0, return; end
        data  = model.getData(model.activeIdx);
        T     = buildTableFromData(data, model.getComputedColumns(model.activeIdx));

        % Determine the base rows (visible after filter)
        baseRows = computeVisibleRows(data);   % [k×1] indices into data

        % Extract the sort column from the table (numeric columns only)
        nCols = width(T);
        if col < 1 || col > nCols, return; end
        colVec = table2array(T(baseRows, col));
        if ~isnumeric(colVec)
            % Cannot sort non-numeric; silently ignore
            return;
        end

        [~, ord]        = sort(colVec, dir);
        state.sortOrder = baseRows(ord);       % display-order index into data rows
        state.sortCol   = col;
        state.sortDir   = dir;
        renderSortedTable(data, T);
    end

% ════════════════════════════════════════════════════════════════════════
%  Filter callbacks (uitable fallback only)
% ════════════════════════════════════════════════════════════════════════

    function onFilterChanged(~, ~)
    %ONFILTERCHANGED  Re-evaluate the filter expression and re-render table.
        applyFilter();
    end

    function onClearFilter(~, ~)
    %ONCLEARFILTER  Clear the filter field and remove the filter.
        txtFilter.Value = '';
        applyFilter();
    end

    function applyFilter()
    %APPLYFILTER  Evaluate filter expression; update filterMask and re-render.
        if model.activeIdx == 0
            state.filterMask = [];
            return;
        end
        expr = strtrim(txtFilter.Value);
        data = model.getData(model.activeIdx);
        nRows = numel(data.time);
        if isempty(expr)
            state.filterMask = true(nRows, 1);
        else
            try
                state.filterMask = bosonPlotter.filterRows(data, expr);
            catch
                % On parse error keep the previous mask; show hint in stats
                state.filterMask = true(nRows, 1);
            end
        end
        % Reset sort order so it is recomputed against new visible rows
        state.sortOrder = [];
        state.sortCol   = 0;
        refreshTable();
    end

% ════════════════════════════════════════════════════════════════════════
%  Model event handlers (view updates)
% ════════════════════════════════════════════════════════════════════════

    function onModelDataChanged(~, ~)
    %ONMODELDATACHANGED  Rebuild the dataset list when the model changes.
        if ~isvalid(fig), return; end
        refreshDatasetList();
        resetSortFilterState();
        refreshTable();
        refreshStatusLabel();
    end

    function onModelSelectionChanged(~, ~)
    %ONMODELSELECTIONCHANGED  Refresh the table when the active dataset changes.
        if ~isvalid(fig), return; end
        resetSortFilterState();
        refreshTable();
        refreshSelectionInList();
        syncTabSelection();
    end

    function onModelMaskChanged(~, ~)
    %ONMODELMASKCHANGED  Re-render the table to reflect the new mask state.
        if ~isvalid(fig), return; end
        refreshTable();
        refreshStatusBar();
    end

% ════════════════════════════════════════════════════════════════════════
%  View refresh helpers
% ════════════════════════════════════════════════════════════════════════

    function refreshDatasetList()
    %REFRESHDATASETLIST  Rebuild the uilistbox items from model.datasets.
        n = model.count();
        items = cell(1, n);
        for k = 1:n
            ds = model.datasets{k};
            if isfield(ds, 'metadata') && isfield(ds.metadata, 'source') ...
                    && ~isempty(ds.metadata.source)
                [~, nm, ext] = fileparts(ds.metadata.source);
                items{k} = [nm ext];
            else
                items{k} = sprintf('Dataset %d', k);
            end
        end
        listDatasets.Items     = items;
        listDatasets.ItemsData = 1:n;   % integer indices — avoids display-name collisions
        % Update the status label
        if n == 0
            lblStatus.Text = 'No datasets loaded';
        elseif n == 1
            lblStatus.Text = '1 dataset';
        else
            lblStatus.Text = sprintf('%d datasets', n);
        end
        refreshTabBar();
    end

    function refreshTabBar()
    %REFRESHTABBAR  Rebuild the bottom tab bar to match model.datasets.
        if ~isvalid(tabGroup), return; end
        n = model.count();

        % Build the desired tab title list
        titles = cell(1, n);
        for k = 1:n
            ds = model.datasets{k};
            if isfield(ds, 'metadata') && isfield(ds.metadata, 'source') ...
                    && ~isempty(ds.metadata.source)
                [~, nm, ext] = fileparts(ds.metadata.source);
                titles{k} = [nm ext];
            else
                titles{k} = sprintf('Dataset %d', k);
            end
        end

        % Reconcile existing tabs with desired list (add/remove only as needed)
        existingTabs = tabGroup.Children;
        nExist = numel(existingTabs);

        % Remove excess tabs (from the end)
        for k = nExist : -1 : n + 1
            delete(existingTabs(k));
        end

        % Update or add tabs
        existingTabs = tabGroup.Children;  % refresh after deletions
        for k = 1:n
            if k <= numel(existingTabs)
                existingTabs(k).Title = titles{k};
            else
                uitab(tabGroup, 'Title', titles{k});
            end
        end

        % Sync selected tab to model.activeIdx
        syncTabSelection();
    end

    function syncTabSelection()
    %SYNCTABSELECTION  Select the tab that matches model.activeIdx.
        tabs = tabGroup.Children;
        if isempty(tabs) || model.activeIdx == 0, return; end
        idx = model.activeIdx;
        if idx >= 1 && idx <= numel(tabs)
            tabGroup.SelectedTab = tabs(idx);
        end
    end

    function onTabSelectionChanged(~, evt)
    %ONTABSELECTIONCHANGED  Switch active dataset when a tab is clicked.
        if ~isvalid(fig), return; end
        tabs = tabGroup.Children;
        idx  = find(tabs == evt.NewValue, 1);
        if ~isempty(idx) && idx ~= model.activeIdx
            model.setActive(idx);
        end
    end

    function refreshSelectionInList()
    %REFRESHSELECTIONINLIST  Sync list selection to model.activeIdx.
        if model.activeIdx == 0 || isempty(listDatasets.Items)
            return;
        end
        if model.activeIdx <= numel(listDatasets.Items)
            listDatasets.Value = model.activeIdx;   % integer from ItemsData
        end
    end

    function refreshTable()
    %REFRESHTABLE  Populate tblData from the active dataset (with sort/filter).
        if model.activeIdx == 0 || model.count() == 0
            tblData.Data  = table();
            lblUnits.Text = 'Units: —';
            lblStats.Text = '';
            return;
        end

        data = model.getData(model.activeIdx);
        compCols = model.getComputedColumns(model.activeIdx);
        T    = buildTableFromData(data, compCols);

        % Badge error columns with (E) in the header
        T = badgeErrorColumns(T, data, model.getColumnRoles(model.activeIdx));

        % Highlight masked rows with a distinct background color
        m = model.mask{model.activeIdx};
        if numel(m) == height(T) && any(~m)
            % We can't natively style individual rows in uitable without
            % a J-hack; we instead append a "Masked" column as a visual cue.
            maskedCol = repmat({''}, height(T), 1);
            maskedCol(~m) = {'*'};
            T.Masked = maskedCol;
        end

        % Units label
        lblUnits.Text = ['Units: ' buildUnitsString(data)];

        if isSpreadsheet
            % uispreadsheet: set data directly (sort/filter built-in)
            tblData.Data = T;
            try
                nC = width(T);
                tblData.ColumnSortable = true(1, nC);
            catch
            end
            refreshStatusBar();
            refreshStatsBar();
            return;
        end

        % ── uitable fallback: apply filter then sort ──────────────────────
        renderSortedTable(data, T);
    end

    function renderSortedTable(data, T)
    %RENDERSORTEDTABLE  Apply filterMask + sortOrder then display table.
        nRows = height(T);

        % Determine which rows pass the filter
        visibleRows = computeVisibleRows(data);   % indices into T

        % Apply sort if active
        if state.sortCol > 0 && ~isempty(state.sortOrder)
            % sortOrder was built from baseRows; intersect with current visibleRows
            % to handle mask/filter interaction (keep only rows still visible)
            [~, ia] = ismember(state.sortOrder, visibleRows);
            sortedRows = state.sortOrder(ia > 0);
            % Rows in visibleRows not yet in sortedRows (new rows after filter change)
            missing = visibleRows(~ismember(visibleRows, sortedRows));
            visibleRows = [sortedRows; missing(:)];
        end

        Tdisp = T(visibleRows, :);

        % Append sort indicator to column header
        colNames = T.Properties.VariableNames;
        if state.sortCol > 0 && state.sortCol <= numel(colNames)
            if strcmp(state.sortDir, 'ascend')
                colNames{state.sortCol} = [colNames{state.sortCol} ' ' char(9650)];
            else
                colNames{state.sortCol} = [colNames{state.sortCol} ' ' char(9660)];
            end
        end
        Tdisp.Properties.VariableNames = colNames;

        tblData.Data = Tdisp;
        try
            nC = width(Tdisp);
            tblData.ColumnSortable = true(1, nC);
        catch
        end

        refreshStatusBar(nRows, numel(visibleRows));
        refreshStatsBar();
    end

    function visRows = computeVisibleRows(data)
    %COMPUTEVISIBLEROWS  Return row indices (into data) visible after filter.
        nRows = numel(data.time);
        % Start with all rows
        fMask = true(nRows, 1);
        if ~isempty(state.filterMask) && numel(state.filterMask) == nRows
            fMask = state.filterMask;
        end
        visRows = find(fMask);
    end

    function resetSortFilterState()
    %RESETSORTFILTERSTATE  Clear sort + filter when switching datasets.
        state.sortCol    = 0;
        state.sortDir    = 'ascend';
        state.sortOrder  = [];
        state.filterMask = [];
        if ~isSpreadsheet
            txtFilter.Value = '';
        end
    end

    function refreshStatusLabel()
    %REFRESHSTATUSLABEL  Update top-right dataset count label.
        n = model.count();
        if n == 0
            lblStatus.Text = 'No datasets loaded';
        elseif n == 1
            lblStatus.Text = '1 dataset';
        else
            lblStatus.Text = sprintf('%d datasets', n);
        end
    end

    function refreshStatusBar(nTotal, nVisible)
    %REFRESHSTATUSBAR  Update the bottom status bar.
    %   Optional args nTotal and nVisible allow the caller to pass pre-computed
    %   counts (avoids redundant model access from renderSortedTable).
        if model.activeIdx == 0 || model.count() == 0
            lblStatusBar.Text = '';
            return;
        end
        if nargin < 1
            data   = model.getData(model.activeIdx);
            nTotal = numel(data.time);
        end
        if nargin < 2
            nVisible = nTotal;
        end
        m     = model.mask{model.activeIdx};
        nMask = sum(~m);

        parts = {};
        parts{end+1} = sprintf('%d rows', nTotal);
        if nMask > 0
            parts{end+1} = sprintf('%d masked', nMask);
        end
        % Show filter count only when filter is active and reduces rows
        if ~isSpreadsheet && nVisible < nTotal
            parts{end+1} = sprintf('Filtered: %d of %d shown', nVisible, nTotal);
        end
        lblStatusBar.Text = strjoin(parts, '  |  ');
    end

    function setStatusBar(msg)
    %SETSTATUSBAR  Display a transient message in the status bar.
        lblStatusBar.Text = msg;
    end

    function refreshStatsBar()
    %REFRESHSTATSBAR  Show Count/Mean/Std/Min/Max for the selected cells.
    %   Falls back to the entire active column when no numeric selection exists.
        if model.activeIdx == 0 || model.count() == 0
            lblStats.Text = '';
            return;
        end

        data = model.getData(model.activeIdx);
        T    = buildTableFromData(data, model.getComputedColumns(model.activeIdx));

        % Gather the numeric values to compute stats over
        vals = [];
        if ~isempty(state.selRows) && ~isempty(state.selCols)
            % Collect all selected numeric cells from the displayed table
            % (state.selRows are display-row indices)
            for ci = state.selCols(:)'
                if ci < 1 || ci > width(T), continue; end
                col = T{:, ci};
                if ~isnumeric(col), continue; end
                vals = [vals; col(state.selRows(state.selRows <= height(T)))]; %#ok<AGROW>
            end
        end

        % Fallback: use the first selected column across all visible rows
        if isempty(vals) && ~isempty(state.selCols)
            ci = state.selCols(1);
            if ci >= 1 && ci <= width(T)
                col = T{:, ci};
                if isnumeric(col)
                    vals = col;
                end
            end
        end

        % Final fallback: first numeric column
        if isempty(vals)
            for ci = 1:width(T)
                col = T{:, ci};
                if isnumeric(col)
                    vals = col;
                    break;
                end
            end
        end

        if isempty(vals)
            lblStats.Text = '';
            return;
        end

        % Exclude NaN before stats
        vals  = vals(~isnan(vals));
        n     = numel(vals);
        if n == 0
            lblStats.Text = 'Count: 0  (all NaN)';
            return;
        end
        mu    = mean(vals);
        sigma = std(vals);
        mn    = min(vals);
        mx    = max(vals);

        lblStats.Text = sprintf( ...
            'Count: %d  |  Mean: %g  |  Std: %g  |  Min: %g  |  Max: %g', ...
            n, mu, sigma, mn, mx);
    end

% ════════════════════════════════════════════════════════════════════════
%  File loading helpers
% ════════════════════════════════════════════════════════════════════════

    function loadSingleFile(fp)
    %LOADSINGLEFILE  Import one file via parser.importAuto and add to model.
        try
            data = parser.importAuto(fp);
            [~, ~, parserTag] = fileparts(fp);
            model.addDataset(data, fp, ['importAuto' parserTag]);
            % (Re)start autosave timer now that the model has data
            dataWorkspace.WorkspaceAutosave.start(model);
        catch ME
            uialert(fig, ME.message, sprintf('Import failed: %s', fp));
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  API helper (headless file loading)
% ════════════════════════════════════════════════════════════════════════

    function addFilesAPI(fpaths)
    %ADDFILESAPI  Load one or more file paths (char or cell) without a dialog.
        if ischar(fpaths)
            fpaths = {fpaths};
        end
        for k = 1:numel(fpaths)
            loadSingleFile(fpaths{k});
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  Close handler
% ════════════════════════════════════════════════════════════════════════

    function onClose(~, ~)
    %ONCLOSE  Clean up listeners, autosave timer, and delete the figure.
        % Stop autosave timer and remove the recovery file (clean exit)
        dataWorkspace.WorkspaceAutosave.cleanup();
        % Delete listeners to prevent callbacks on a dead figure
        for k = 1:numel(guiListeners)
            if isvalid(guiListeners{k})
                delete(guiListeners{k});
            end
        end
        guiListeners = {};  %#ok<NASGU>
        delete(fig);
    end

% ════════════════════════════════════════════════════════════════════════
%  Column header badge helper
% ════════════════════════════════════════════════════════════════════════

    function T = badgeErrorColumns(T, data, roles)
    %BADGEERRORCOLUMNS  Append (E) to variable names of error-designated columns.
    %
    %   T     — MATLAB table built by buildTableFromData
    %   data  — unified data struct (for column count)
    %   roles — dataWorkspace.ColumnRoles for the active dataset
        if isempty(roles.errorFor.errCols)
            return;  % nothing to badge
        end
        nVal   = size(data.values, 2);
        varNms = T.Properties.VariableNames;
        % errCols are 1-based value column indices; table col 2 = value col 1
        for ki = 1:numel(roles.errorFor.errCols)
            ec = roles.errorFor.errCols(ki);
            tblIdx = ec + 1;  % +1 because col 1 is X
            if tblIdx >= 1 && tblIdx <= numel(varNms) && ec <= nVal
                varNms{tblIdx} = [varNms{tblIdx} '_E'];
            end
        end
        T.Properties.VariableNames = varNms;
    end

end  % DataWorkspace


% ════════════════════════════════════════════════════════════════════════
%  Module-level helpers (outside the main function scope)
% ════════════════════════════════════════════════════════════════════════

function T = buildTableFromData(data, computedCols)
%BUILDTABLEFROMDATA  Convert a unified data struct to a MATLAB table.
%   Optional computedCols is a cell array of computed column structs
%   (each with .name, .values, .unit fields) appended as extra columns.

if nargin < 2
    computedCols = {};
end

xVec = double(data.time(:));

valMat = data.values;
if isempty(valMat)
    valMat = zeros(numel(xVec), 0);
end

% X-axis label
xLabel = 'X';
if isfield(data, 'metadata') && isfield(data.metadata, 'xLabel') ...
        && ~isempty(data.metadata.xLabel)
    xLabel = data.metadata.xLabel;
end

% Value column labels
labels = {};
if isfield(data, 'labels') && ~isempty(data.labels)
    labels = data.labels(:)';
end
nVal = size(valMat, 2);
while numel(labels) < nVal
    labels{end+1} = sprintf('Col%d', numel(labels)+1);  %#ok<AGROW>
end
labels = labels(1:nVal);

% Computed column data / labels / units
compMat   = zeros(numel(xVec), numel(computedCols));
compLabels = cell(1, numel(computedCols));
compUnits  = cell(1, numel(computedCols));
for kc = 1:numel(computedCols)
    v = computedCols{kc}.values;
    if numel(v) == numel(xVec)
        compMat(:, kc) = v(:);
    end
    compLabels{kc} = computedCols{kc}.name;
    compUnits{kc}  = computedCols{kc}.unit;
end

% Sanitise variable names for the table (mark computed with italic prefix f_)
allRaw   = [{xLabel}, labels, compLabels];
allValid = matlab.lang.makeValidName(allRaw);
allValid = matlab.lang.makeUniqueStrings(allValid);

allData = [xVec, valMat, compMat];
T = array2table(allData);
T.Properties.VariableNames = allValid;

% Units metadata
units = {};
if isfield(data, 'units') && ~isempty(data.units)
    units = data.units(:)';
end
while numel(units) < nVal
    units{end+1} = '';  %#ok<AGROW>
end
units = units(1:nVal);
T.Properties.VariableUnits = [{''},  units, compUnits];

end  % buildTableFromData


function s = buildUnitsString(data)
%BUILDUNITSSTRING  Return a compact "Label (unit), ..." display string.
parts = {};
if isfield(data, 'labels') && isfield(data, 'units')
    n = min(numel(data.labels), numel(data.units));
    for k = 1:n
        lbl = strtrim(data.labels{k});
        unt = strtrim(data.units{k});
        if ~isempty(lbl) && ~isempty(unt)
            parts{end+1} = [lbl ' (' unt ')'];  %#ok<AGROW>
        elseif ~isempty(lbl)
            parts{end+1} = lbl;                 %#ok<AGROW>
        end
    end
end
if isempty(parts)
    s = '(none)';
else
    s = strjoin(parts, ',  ');
end
end  % buildUnitsString


function data = parseClipboardText(txt)
%PARSECLIPBOARDTEXT  Parse raw clipboard text into a unified data struct.
%
%   data = parseClipboardText(txt)
%
%   Inputs:
%     txt — raw text string from clipboard('paste')
%
%   Outputs:
%     data — unified struct (.time, .values, .labels, .units, .metadata)
%
%   Auto-detects delimiter (tab > comma > space).  Treats the first row as
%   a header when it contains any non-numeric token.  First column becomes
%   .time; remaining columns become .values.

% Split into lines, remove trailing whitespace / empty lines
lines = strsplit(txt, {'\n', '\r\n', '\r'});
lines = strtrim(lines);
lines = lines(~cellfun('isempty', lines));

if isempty(lines)
    error('parseClipboardText:empty', 'No data found in clipboard text.');
end

% ── Detect delimiter ──────────────────────────────────────────────────
if contains(lines{1}, char(9))           % tab
    delim = char(9);
elseif contains(lines{1}, ',')           % comma
    delim = ',';
else                                     % space / whitespace
    delim = ' ';
end

% ── Split all rows ────────────────────────────────────────────────────
rows = cellfun(@(ln) strsplit(ln, delim), lines, 'UniformOutput', false);

% Normalise row lengths (pad short rows with NaN placeholder)
rowLens  = cellfun('length', rows);
maxCols  = max(rowLens);
for k = 1:numel(rows)
    while numel(rows{k}) < maxCols
        rows{k}{end+1} = '';
    end
end

% ── Detect header row (first row with any non-numeric token) ──────────
firstRow = rows{1};
isHeader = any(cellfun(@(t) isnan(str2double(strtrim(t))), firstRow));

if isHeader
    headerTokens = strtrim(firstRow);
    dataRows     = rows(2:end);
else
    headerTokens = arrayfun(@(k) sprintf('Col%d', k), 1:maxCols, ...
                            'UniformOutput', false);
    dataRows = rows;
end

if isempty(dataRows)
    error('parseClipboardText:noData', 'Clipboard contains a header but no data rows.');
end

% ── Convert to numeric matrix ─────────────────────────────────────────
nRows = numel(dataRows);
mat   = nan(nRows, maxCols);
for r = 1:nRows
    for c = 1:maxCols
        v = str2double(strtrim(dataRows{r}{c}));
        if ~isnan(v)
            mat(r, c) = v;
        end
    end
end

% ── Build unified struct ──────────────────────────────────────────────
xVec = mat(:, 1);
if maxCols > 1
    yMat = mat(:, 2:end);
else
    yMat = zeros(nRows, 0);
end

labels = headerTokens(2:end);
if isempty(labels)
    labels = {};
end
units = repmat({''}, 1, numel(labels));

data = parser.createDataStruct(xVec, yMat, ...
    'labels',   labels, ...
    'units',    units, ...
    'metadata', struct('source', 'clipboard', 'parserName', 'paste', ...
                       'xLabel', headerTokens{1}));

end  % parseClipboardText
