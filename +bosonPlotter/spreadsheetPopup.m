function fig = spreadsheetPopup(dataStruct, Options)
%SPREADSHEETPOPUP  Open a standalone resizable spreadsheet window for a dataset.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   fig = bosonPlotter.spreadsheetPopup(dataStruct)
%   fig = bosonPlotter.spreadsheetPopup(dataStruct, Title=..., OnEdit=..., ReadOnly=...)
%
% ── Inputs ────────────────────────────────────────────────────────────────
%
%   dataStruct   unified data struct (.time, .values, .labels, .units, .metadata)
%
%   Title        window title string (default: source filename from metadata)
%   OnEdit       function handle called with (rowIdx, colIdx, newValue) on edit
%   ReadOnly     logical scalar; true prevents cell editing (default: false)
%
% ── Outputs ───────────────────────────────────────────────────────────────
%
%   fig          handle to the popup uifigure
%
% ── Examples ──────────────────────────────────────────────────────────────
%
%   d = parser.importAuto('data.dat');
%   bosonPlotter.spreadsheetPopup(d);
%   bosonPlotter.spreadsheetPopup(d, Title='My Dataset', ReadOnly=true);
%
% ════════════════════════════════════════════════════════════════════════

arguments
    dataStruct  (1,1) struct
    Options.Title    (1,:) char    = ''
    Options.OnEdit                 = []
    Options.ReadOnly (1,1) logical = false
end

% ════════════════════════════════════════════════════════════════════════
%  Derive window title
% ════════════════════════════════════════════════════════════════════════
if isempty(Options.Title)
    if isfield(dataStruct, 'metadata') && isfield(dataStruct.metadata, 'source') ...
            && ~isempty(dataStruct.metadata.source)
        [~, nm, ext] = fileparts(dataStruct.metadata.source);
        winTitle = [nm ext];
    else
        winTitle = 'Dataset Spreadsheet';
    end
else
    winTitle = Options.Title;
end

% ════════════════════════════════════════════════════════════════════════
%  Build MATLAB table from data struct
% ════════════════════════════════════════════════════════════════════════
T = buildTable(dataStruct);

% ════════════════════════════════════════════════════════════════════════
%  Popup figure
% ════════════════════════════════════════════════════════════════════════
fig = uifigure('Name',     winTitle, ...
               'Position', [150 100 900 600], ...
               'Resize',   'on');

% Root layout: toolbar row + content row
rootGL = uigridlayout(fig, [2 1], ...
    'RowHeight',   {32, '1x'}, ...
    'ColumnWidth', {'1x'}, ...
    'Padding',     [4 4 4 4], ...
    'RowSpacing',  4);

% ════════════════════════════════════════════════════════════════════════
%  Toolbar row
% ════════════════════════════════════════════════════════════════════════
tbGL = uigridlayout(rootGL, [1 9], ...
    'ColumnWidth', {70, 70, 80, 70, 80, 80, 70, '1x', 80}, ...
    'Padding',     [0 0 0 0], ...
    'ColumnSpacing', 4);
tbGL.Layout.Row = 1;

BTN = [0.28 0.28 0.28];
BTNTXT = [0.92 0.92 0.92];

btnSortAsc  = uibutton(tbGL, 'Text', [char(8679) ' Asc'],  ...
    'Tooltip', 'Sort selected column ascending', ...
    'BackgroundColor', BTN, 'FontColor', BTNTXT, 'FontSize', 10, ...
    'ButtonPushedFcn', @onSortAsc);
btnSortAsc.Layout.Column = 1;

btnSortDesc = uibutton(tbGL, 'Text', [char(8681) ' Desc'], ...
    'Tooltip', 'Sort selected column descending', ...
    'BackgroundColor', BTN, 'FontColor', BTNTXT, 'FontSize', 10, ...
    'ButtonPushedFcn', @onSortDesc);
btnSortDesc.Layout.Column = 2;

btnStats    = uibutton(tbGL, 'Text', [char(963) ' Stats'], ...
    'Tooltip', 'Show column statistics', ...
    'BackgroundColor', BTN, 'FontColor', BTNTXT, 'FontSize', 10, ...
    'ButtonPushedFcn', @onStats);
btnStats.Layout.Column = 3;

btnFilter   = uibutton(tbGL, 'Text', [char(9965) ' Filter'], ...
    'Tooltip', 'Apply row filter expression', ...
    'BackgroundColor', BTN, 'FontColor', BTNTXT, 'FontSize', 10, ...
    'ButtonPushedFcn', @onFilter);
btnFilter.Layout.Column = 4;

btnCopy     = uibutton(tbGL, 'Text', [char(9112) ' Copy'], ...
    'Tooltip', 'Copy visible data to clipboard (tab-delimited)', ...
    'BackgroundColor', BTN, 'FontColor', BTNTXT, 'FontSize', 10, ...
    'ButtonPushedFcn', @onCopy);
btnCopy.Layout.Column = 5;

btnExport   = uibutton(tbGL, 'Text', [char(8599) ' Export'], ...
    'Tooltip', 'Export current view to CSV', ...
    'BackgroundColor', BTN, 'FontColor', BTNTXT, 'FontSize', 10, ...
    'ButtonPushedFcn', @onExportCSV);
btnExport.Layout.Column = 6;

btnReset    = uibutton(tbGL, 'Text', [char(8635) ' Reset'], ...
    'Tooltip', 'Restore original data (clear sort and filter)', ...
    'BackgroundColor', BTN, 'FontColor', BTNTXT, 'FontSize', 10, ...
    'ButtonPushedFcn', @onReset);
btnReset.Layout.Column = 7;

% Filter text field in the spacer slot
efFilter = uieditfield(tbGL, 'text', ...
    'Placeholder', 'Filter expression, e.g.  Field > 0', ...
    'FontSize',    10, ...
    'ValueChangedFcn', []);   % Enter key triggers onFilter via button
efFilter.Layout.Column = 8;

% ════════════════════════════════════════════════════════════════════════
%  Content area: units label + table/spreadsheet
% ════════════════════════════════════════════════════════════════════════
contentGL = uigridlayout(rootGL, [2 1], ...
    'RowHeight',  {18, '1x'}, ...
    'Padding',    [0 0 0 0], ...
    'RowSpacing', 2);
contentGL.Layout.Row = 2;

% Units bar
unitsStr = buildUnitsString(dataStruct);
lblUnits = uilabel(contentGL, ...
    'Text',      ['Units: ' unitsStr], ...
    'FontSize',  10, ...
    'FontColor', [0.55 0.55 0.55], ...
    'HorizontalAlignment', 'left');
lblUnits.Layout.Row = 1;

% ════════════════════════════════════════════════════════════════════════
%  Feature detection: uispreadsheet (R2025a+) vs uitable
% ════════════════════════════════════════════════════════════════════════
useSpreadsheet = exist('uispreadsheet', 'builtin') ~= 0 || ...
                 exist('uispreadsheet', 'file')    ~= 0;

% Working state
state.T         = T;           % current (possibly filtered/sorted) table
state.origT     = T;           % original untouched table
state.selCol    = 1;           % last-clicked column (1-based)
state.selRows   = [];          % selected row indices

if useSpreadsheet
    buildSpreadsheetWidget();
else
    buildUitableWidget();
end

% ════════════════════════════════════════════════════════════════════════
%  Nested: build uispreadsheet widget (R2025a+)
% ════════════════════════════════════════════════════════════════════════
    function buildSpreadsheetWidget()
        ss = uispreadsheet(contentGL, ...
            'Data',            state.T, ...
            'Editable',        ~Options.ReadOnly);
        ss.Layout.Row = 2;
        % uispreadsheet handles its own sorting/filtering via column headers.
        % Toolbar Sort buttons operate on the backing table and refresh Data.
        state.widget = ss;
    end

% ════════════════════════════════════════════════════════════════════════
%  Nested: build uitable fallback widget
% ════════════════════════════════════════════════════════════════════════
    function buildUitableWidget()
        nCols = width(state.T);
        colEditable = repmat(~Options.ReadOnly, 1, nCols);

        tb = uitable(contentGL, ...
            'Data',            state.T, ...
            'ColumnEditable',  colEditable, ...
            'FontSize',        11, ...
            'CellSelectionCallback',   @onCellSelected, ...
            'CellEditCallback',        @onCellEdit);
        try
            tb.ColumnSortable = true(1, nCols);
        catch
            % ColumnSortable not available (pre-R2023b), silently skip
        end
        tb.Layout.Row = 2;
        state.widget = tb;
    end

% ════════════════════════════════════════════════════════════════════════
%  Toolbar callbacks
% ════════════════════════════════════════════════════════════════════════

    function onSortAsc(~, ~)
    %ONSORTASC  Sort current view by last-selected column, ascending.
        if ~istable(state.T) || width(state.T) < 1, return; end
        col = min(state.selCol, width(state.T));
        try
            state.T = sortrows(state.T, col);
            refreshWidget();
        catch ME
            uialert(fig, ME.message, 'Sort failed');
        end
    end

    function onSortDesc(~, ~)
    %ONSORTDESC  Sort current view by last-selected column, descending.
        if ~istable(state.T) || width(state.T) < 1, return; end
        col = min(state.selCol, width(state.T));
        try
            state.T = sortrows(state.T, col, 'descend');
            refreshWidget();
        catch ME
            uialert(fig, ME.message, 'Sort failed');
        end
    end

    function onFilter(~, ~)
    %ONFILTER  Apply the filter expression from the edit field.
        expr = strtrim(efFilter.Value);
        if isempty(expr)
            state.T = state.origT;
            refreshWidget();
            return;
        end
        try
            mask = bosonPlotter.filterRows(dataStruct, expr);
            % Apply mask to the original table to get filtered rows
            % (filterRows returns a row mask for the full dataStruct)
            if numel(mask) == height(state.origT)
                state.T = state.origT(mask, :);
            else
                uialert(fig, 'Filter mask size mismatch. Using original data.', 'Filter warning');
                state.T = state.origT;
            end
            refreshWidget();
        catch ME
            uialert(fig, ME.message, 'Filter error');
        end
    end

    function onStats(~, ~)
    %ONSTATS  Show per-column statistics in a popup table.
        showStatistics(state.T, fig);
    end

    function onCopy(~, ~)
    %ONCOPY  Copy visible table contents as tab-delimited text to clipboard.
        try
            clipStr = tableToTabDelimited(state.T);
            clipboard('copy', clipStr);
        catch ME
            uialert(fig, ME.message, 'Copy failed');
        end
    end

    function onExportCSV(~, ~)
    %ONEXPORTCSV  Save the current view as a CSV file.
        [fname, fdir] = uiputfile('*.csv', 'Export CSV');
        if isequal(fname, 0), return; end
        try
            writetable(state.T, fullfile(fdir, fname));
        catch ME
            uialert(fig, ME.message, 'Export failed');
        end
    end

    function onReset(~, ~)
    %ONRESET  Restore original sort and filter.
        efFilter.Value = '';
        state.T = state.origT;
        refreshWidget();
    end

% ════════════════════════════════════════════════════════════════════════
%  Widget interaction callbacks (uitable only)
% ════════════════════════════════════════════════════════════════════════

    function onCellSelected(~, evt)
    %ONCELLSELECTED  Track last-selected column for sort operations.
        if ~isempty(evt.Indices)
            state.selCol  = evt.Indices(1, 2);
            state.selRows = unique(evt.Indices(:, 1));
        end
    end

    function onCellEdit(~, evt)
    %ONCELLEDIT  Propagate cell edits through OnEdit callback.
        if Options.ReadOnly, return; end
        r = evt.Indices(1);
        c = evt.Indices(2);
        state.T{r, c} = evt.NewData;
        if ~isempty(Options.OnEdit) && isa(Options.OnEdit, 'function_handle')
            try
                Options.OnEdit(r, c, evt.NewData);
            catch ME
                warning('bosonPlotter:spreadsheetPopup:editCallbackError', ...
                    'OnEdit callback error: %s', ME.message);
            end
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  Helper: refresh the widget when state.T changes
% ════════════════════════════════════════════════════════════════════════
    function refreshWidget()
        if ~isfield(state, 'widget') || ~isvalid(state.widget), return; end
        state.widget.Data = state.T;
    end

end  % spreadsheetPopup

% ════════════════════════════════════════════════════════════════════════
%  Local: buildTable
%   Convert unified data struct to a MATLAB table.
% ════════════════════════════════════════════════════════════════════════
function T = buildTable(dataStruct)
%BUILDTABLE  Convert a unified data struct to a MATLAB table.

% X column
xVec = double(dataStruct.time(:));

% Value columns
valMat = dataStruct.values;
if isempty(valMat)
    valMat = zeros(numel(xVec), 0);
end

% Determine x-axis label
xLabel = 'X';
if isfield(dataStruct, 'metadata') && isfield(dataStruct.metadata, 'xLabel') ...
        && ~isempty(dataStruct.metadata.xLabel)
    xLabel = dataStruct.metadata.xLabel;
end

% Build column labels
labels = {};
if isfield(dataStruct, 'labels') && ~isempty(dataStruct.labels)
    labels = dataStruct.labels(:)';
end
% Pad or trim labels to match value columns
nVal = size(valMat, 2);
if numel(labels) < nVal
    for k = numel(labels)+1 : nVal
        labels{k} = sprintf('Col%d', k);
    end
end
labels = labels(1:nVal);

% Sanitise for MATLAB variable names
allRaw    = [{xLabel}, labels];
allValid  = matlab.lang.makeValidName(allRaw);
% Ensure uniqueness
allValid  = matlab.lang.makeUniqueStrings(allValid);

% Assemble table
T = array2table([xVec, valMat]);
T.Properties.VariableNames = allValid;

% Units
units = {};
if isfield(dataStruct, 'units') && ~isempty(dataStruct.units)
    units = dataStruct.units(:)';
end
% Pad to nVal
while numel(units) < nVal
    units{end+1} = '';
end
units = units(1:nVal);
T.Properties.VariableUnits = [{''},  units];

end  % buildTable

% ════════════════════════════════════════════════════════════════════════
%  Local: buildUnitsString
%   Return a compact "Label (unit), Label (unit), ..." display string.
% ════════════════════════════════════════════════════════════════════════
function s = buildUnitsString(dataStruct)
%BUILDUNITSSTRING  Produce a compact units summary string.
parts = {};
if isfield(dataStruct, 'labels') && isfield(dataStruct, 'units')
    n = min(numel(dataStruct.labels), numel(dataStruct.units));
    for k = 1:n
        lbl = strtrim(dataStruct.labels{k});
        unt = strtrim(dataStruct.units{k});
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

% ════════════════════════════════════════════════════════════════════════
%  Local: showStatistics
%   Open a small popup showing per-column descriptive stats.
% ════════════════════════════════════════════════════════════════════════
function showStatistics(T, parentFig)
%SHOWSTATISTICS  Display a per-column statistics popup.

numVars  = T.Properties.VariableNames;
numData  = zeros(height(T), numel(numVars));
for k = 1:numel(numVars)
    col = T{:, k};
    if isnumeric(col)
        numData(:, k) = double(col);
    else
        numData(:, k) = NaN;
    end
end

% Build stats table
statNames = {'Count'; 'Mean'; 'Std'; 'Min'; 'Q25'; 'Median'; 'Q75'; 'Max'};
nV = numel(numVars);
statMat = zeros(8, nV);
for k = 1:nV
    v = numData(:, k);
    v = v(~isnan(v));
    if isempty(v)
        statMat(:, k) = NaN;
    else
        statMat(1, k) = numel(v);
        statMat(2, k) = mean(v);
        statMat(3, k) = std(v);
        statMat(4, k) = min(v);
        statMat(5, k) = builtinPercentile(v, 25);
        statMat(6, k) = median(v);
        statMat(7, k) = builtinPercentile(v, 75);
        statMat(8, k) = max(v);
    end
end

Tstats = array2table(statMat, ...
    'VariableNames', numVars, ...
    'RowNames',      statNames);

% Popup figure
popW = min(120 * nV + 100, 900);
popH = 280;
sfig = uifigure('Name',     'Column Statistics', ...
                'Position', [200 200 popW popH], ...
                'Resize',   'on');
try
    sfig.WindowStyle = 'normal';
catch
end

sGL = uigridlayout(sfig, [1 1], 'Padding', [6 6 6 6]);
tb = uitable(sGL, ...
    'Data',          Tstats, ...
    'ColumnEditable', false(1, nV), ...
    'FontSize',       10);
tb.Layout.Row    = 1;
tb.Layout.Column = 1;

end  % showStatistics

% ════════════════════════════════════════════════════════════════════════
%  Local: tableToTabDelimited
%   Serialise a MATLAB table to a tab-delimited string with a header row.
% ════════════════════════════════════════════════════════════════════════
function s = tableToTabDelimited(T)
%TABLETOTABDELIMITED  Convert table to tab-delimited clipboard string.

nR = height(T);
nC = width(T);
varNames = T.Properties.VariableNames;

lines = cell(nR + 1, 1);

% Header
lines{1} = strjoin(varNames, '\t');

% Data rows
for r = 1:nR
    parts = cell(1, nC);
    for c = 1:nC
        v = T{r, c};
        if isnumeric(v)
            parts{c} = num2str(v, '%g');
        elseif ischar(v) || isstring(v)
            parts{c} = char(v);
        else
            parts{c} = '';
        end
    end
    lines{r+1} = strjoin(parts, '\t');
end

s = strjoin(lines, newline);
end  % tableToTabDelimited

% ════════════════════════════════════════════════════════════════════════
%  Local: builtinPercentile
%   Linear-interpolation percentile without Statistics Toolbox.
% ════════════════════════════════════════════════════════════════════════
function p = builtinPercentile(v, pct)
%BUILTINPERCENTILE  Compute the pct-th percentile of vector v (no toolbox).
%   Uses linear interpolation matching MATLAB's prctile convention.
v = sort(v(:));
n = numel(v);
if n == 0
    p = NaN;
    return;
end
if n == 1
    p = v(1);
    return;
end
% Map percentile to fractional index in [1, n]
rank = 1 + (pct / 100) * (n - 1);
lo   = floor(rank);
hi   = ceil(rank);
frac = rank - lo;
lo   = max(1, min(lo, n));
hi   = max(1, min(hi, n));
p    = v(lo) * (1 - frac) + v(hi) * frac;
end  % builtinPercentile
