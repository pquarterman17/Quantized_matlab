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
%   DataWorkspace                      % interactive launch
%   api = DataWorkspace(Visible='off') % headless for tests
%   api.addFiles({'data.dat'})
%   model = api.getModel();
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
    'Position',        [80 80 1100 660], ...
    'Color',           BG, ...
    'Visible',         options.Visible, ...
    'CloseRequestFcn', @onClose);

% ════════════════════════════════════════════════════════════════════════
%  Root grid: [toolbar ; content]
% ════════════════════════════════════════════════════════════════════════
rootGL = uigridlayout(fig, [2 1], ...
    'RowHeight',   {34, '1x'}, ...
    'ColumnWidth', {'1x'}, ...
    'Padding',     [4 4 4 4], ...
    'RowSpacing',  4, ...
    'BackgroundColor', BG);

% ════════════════════════════════════════════════════════════════════════
%  Toolbar row
% ════════════════════════════════════════════════════════════════════════
tbGL = uigridlayout(rootGL, [1 5], ...
    'ColumnWidth',   {90, 90, 90, '1x', 90}, ...
    'Padding',       [0 0 0 0], ...
    'ColumnSpacing', 4, ...
    'BackgroundColor', BG);
tbGL.Layout.Row = 1;

btnAddFiles = uibutton(tbGL, ...
    'Text',            [char(43) ' Add Files'], ...
    'Tooltip',         'Import files via parser.importAuto', ...
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

% Spacer at column 4

lblStatus = uilabel(tbGL, ...
    'Text',                'No datasets loaded', ...
    'FontColor',           [0.6 0.6 0.6], ...
    'FontSize',            10, ...
    'HorizontalAlignment', 'right');
lblStatus.Layout.Column = 5;

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
%  Right area: units label + table + status bar
% ────────────────────────────────────────────────────────────────────────
rightGL = uigridlayout(contentGL, [3 1], ...
    'RowHeight',   {18, '1x', 20}, ...
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

% Data table — uispreadsheet on R2025a+, uitable on older releases
[tblData, ~] = dataWorkspace.createTableWidget(rightGL);
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
tblData.Layout.Row            = 2;

lblStatusBar = uilabel(rightGL, ...
    'Text',                '', ...
    'FontSize',            9, ...
    'FontColor',           [0.5 0.5 0.5], ...
    'HorizontalAlignment', 'left');
lblStatusBar.Layout.Row = 3;

% ════════════════════════════════════════════════════════════════════════
%  GUI state
% ════════════════════════════════════════════════════════════════════════
state.selRows    = [];   % selected row indices in the table
state.selCols    = [];   % selected column indices in the table

% ════════════════════════════════════════════════════════════════════════
%  Model event listeners
% ════════════════════════════════════════════════════════════════════════
lsnData = addlistener(model, 'DataChanged',      @onModelDataChanged);
lsnSel  = addlistener(model, 'SelectionChanged', @onModelSelectionChanged);
lsnMask = addlistener(model, 'MaskChanged',      @onModelMaskChanged);

% Keep listeners alive in the GUI scope (handle objects — MATLAB will
% auto-delete them when they go out of scope, so we anchor them here).
guiListeners = {lsnData, lsnSel, lsnMask};  %#ok<NASGU>

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
        selItems = listDatasets.Value;
        if isempty(selItems), return; end

        % Map display names → indices.  Remove in reverse order to keep
        % remaining indices valid.
        allItems = listDatasets.Items;
        idxToRemove = zeros(1, numel(selItems));
        for k = 1:numel(selItems)
            idxToRemove(k) = find(strcmp(allItems, selItems{k}), 1);
        end
        idxToRemove = sort(idxToRemove, 'descend');
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
        T    = buildTableFromData(data);
        [fname, fdir] = uiputfile('*.csv', 'Export CSV');
        if isequal(fname, 0), return; end
        try
            writetable(T, fullfile(fdir, fname));
            setStatusBar(sprintf('Exported: %s', fname));
        catch ME
            uialert(fig, ME.message, 'Export failed');
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  Dataset list callbacks
% ════════════════════════════════════════════════════════════════════════

    function onDatasetSelected(~, evt)
    %ONDATASETSELECTED  Switch the active dataset when the list selection changes.
        allItems = listDatasets.Items;
        if isempty(allItems) || model.count() == 0, return; end
        selVal = evt.Value;
        if isempty(selVal), return; end
        % Use the first selected item as the active dataset
        if iscell(selVal)
            selVal = selVal{1};
        end
        idx = find(strcmp(allItems, selVal), 1);
        if ~isempty(idx)
            model.setActive(idx);
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  Table callbacks
% ════════════════════════════════════════════════════════════════════════

    function onCellSelected(~, evt)
    %ONCELLSELECTED  Track selected rows/columns for context menu.
        if ~isempty(evt.Indices)
            state.selRows = unique(evt.Indices(:,1));
            state.selCols = unique(evt.Indices(:,2));
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  Context menu for row masking
% ════════════════════════════════════════════════════════════════════════

    function cm = buildContextMenu()
    %BUILDCONTEXTMENU  Build the right-click context menu for the data table.
        cm = uicontextmenu(fig);
        uimenu(cm, 'Text', 'Mask selected rows',   'MenuSelectedFcn', @onMaskRows);
        uimenu(cm, 'Text', 'Unmask selected rows', 'MenuSelectedFcn', @onUnmaskRows);
        uimenu(cm, 'Text', 'Unmask all rows',      'MenuSelectedFcn', @onUnmaskAll, 'Separator', 'on');
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

% ════════════════════════════════════════════════════════════════════════
%  Model event handlers (view updates)
% ════════════════════════════════════════════════════════════════════════

    function onModelDataChanged(~, ~)
    %ONMODELDATACHANGED  Rebuild the dataset list when the model changes.
        if ~isvalid(fig), return; end
        refreshDatasetList();
        refreshTable();
        refreshStatusLabel();
    end

    function onModelSelectionChanged(~, ~)
    %ONMODELSELECTIONCHANGED  Refresh the table when the active dataset changes.
        if ~isvalid(fig), return; end
        refreshTable();
        refreshSelectionInList();
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
        listDatasets.Items = items;
        % Update the status label
        if n == 0
            lblStatus.Text = 'No datasets loaded';
        elseif n == 1
            lblStatus.Text = '1 dataset';
        else
            lblStatus.Text = sprintf('%d datasets', n);
        end
    end

    function refreshSelectionInList()
    %REFRESHSELECTIONINLIST  Sync list selection to model.activeIdx.
        if model.activeIdx == 0 || isempty(listDatasets.Items)
            return;
        end
        if model.activeIdx <= numel(listDatasets.Items)
            listDatasets.Value = listDatasets.Items(model.activeIdx);
        end
    end

    function refreshTable()
    %REFRESHTABLE  Populate tblData from the active dataset.
        if model.activeIdx == 0 || model.count() == 0
            tblData.Data = table();
            lblUnits.Text = 'Units: —';
            return;
        end

        data = model.getData(model.activeIdx);
        T    = buildTableFromData(data);

        % Highlight masked rows with a distinct background color
        m = model.mask{model.activeIdx};
        if numel(m) == height(T) && any(~m)
            % We can't natively style individual rows in uitable without
            % a J-hack; we instead append a "Masked" column as a visual cue.
            maskedCol = repmat({''}, height(T), 1);
            maskedCol(~m) = {'*'};
            T.Masked = maskedCol;
        end

        tblData.Data = T;
        try
            nC = width(T);
            tblData.ColumnSortable = true(1, nC);
        catch
        end

        % Units label
        lblUnits.Text = ['Units: ' buildUnitsString(data)];

        refreshStatusBar();
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

    function refreshStatusBar()
    %REFRESHSTATUSBAR  Update the bottom status bar.
        if model.activeIdx == 0 || model.count() == 0
            lblStatusBar.Text = '';
            return;
        end
        data  = model.getData(model.activeIdx);
        nRows = numel(data.time);
        m     = model.mask{model.activeIdx};
        nMask = sum(~m);
        if nMask == 0
            lblStatusBar.Text = sprintf('%d rows', nRows);
        else
            lblStatusBar.Text = sprintf('%d rows  |  %d masked', nRows, nMask);
        end
    end

    function setStatusBar(msg)
    %SETSTATUSBAR  Display a transient message in the status bar.
        lblStatusBar.Text = msg;
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
    %ONCLOSE  Clean up listeners and delete the figure.
        % Delete listeners to prevent callbacks on a dead figure
        for k = 1:numel(guiListeners)
            if isvalid(guiListeners{k})
                delete(guiListeners{k});
            end
        end
        guiListeners = {};  %#ok<NASGU>
        delete(fig);
    end

end  % DataWorkspace


% ════════════════════════════════════════════════════════════════════════
%  Module-level helpers (outside the main function scope)
% ════════════════════════════════════════════════════════════════════════

function T = buildTableFromData(data)
%BUILDTABLEFROMDATA  Convert a unified data struct to a MATLAB table.

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

% Sanitise variable names for the table
allRaw   = [{xLabel}, labels];
allValid = matlab.lang.makeValidName(allRaw);
allValid = matlab.lang.makeUniqueStrings(allValid);

T = array2table([xVec, valMat]);
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
T.Properties.VariableUnits = [{''},  units];

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
