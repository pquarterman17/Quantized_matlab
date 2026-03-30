function config = toolbarConfig(currentConfig, availableActions)
%TOOLBARCONFIG  Open a toolbar customisation dialog.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   config = dataplotter.toolbarConfig(currentConfig, availableActions)
%
% ── Inputs ────────────────────────────────────────────────────────────────
%
%   currentConfig    {1×N} cell of action ID strings currently in toolbar
%   availableActions struct array with fields .id, .label, .tooltip
%
% ── Outputs ───────────────────────────────────────────────────────────────
%
%   config           {1×M} cell of action IDs after user edit, or {} if
%                    the user cancelled (caller should treat {} as "no change")
%
% ── Examples ──────────────────────────────────────────────────────────────
%
%   actions(1) = struct('id','grid','label','Grid','tooltip','Toggle grid');
%   actions(2) = struct('id','legend','label','Legend','tooltip','Toggle legend');
%   cfg = dataplotter.toolbarConfig({'grid'}, actions);
%
% ════════════════════════════════════════════════════════════════════════

arguments
    currentConfig    (1,:) cell
    availableActions (1,:) struct
end

% ── Default: cancelled ────────────────────────────────────────────────────
config = {};

% ── Build label / id maps ─────────────────────────────────────────────────
allIds     = {availableActions.id};
allLabels  = {availableActions.label};

% ── Working copy: IDs in toolbar (preserve order) ─────────────────────────
% Keep only IDs that exist in the registry; discard stale entries silently.
validCurrent = currentConfig(ismember(currentConfig, allIds));
currentIds   = validCurrent;

% Available = all known minus those already in toolbar
availableIds = allIds(~ismember(allIds, currentIds));

% ── Dialog geometry ───────────────────────────────────────────────────────
dlgW = 520;  dlgH = 380;

dlg = uifigure('Name', 'Customise Toolbar', ...
    'Position',            [200 200 dlgW dlgH], ...
    'Resize',              'off', ...
    'WindowStyle',         'modal', ...
    'Color',               [0.15 0.15 0.15], ...
    'CloseRequestFcn',     @onCancel);

% ── Root grid: title | columns | buttons ─────────────────────────────────
rootGL = uigridlayout(dlg, [3 1], ...
    'RowHeight',    {24, '1x', 36}, ...
    'Padding',      [10 8 10 8], ...
    'RowSpacing',   6, ...
    'ColumnWidth',  {'1x'});

% ── Title label ───────────────────────────────────────────────────────────
lblTitle = uilabel(rootGL, ...
    'Text',               'Drag actions between lists or use the buttons below.', ...
    'FontSize',           11, ...
    'FontColor',          [0.75 0.75 0.75], ...
    'HorizontalAlignment','left');
lblTitle.Layout.Row = 1; lblTitle.Layout.Column = 1;

% ── Columns: [Available | mid-buttons | Current Toolbar] ──────────────────
colsGL = uigridlayout(rootGL, [1 3], ...
    'ColumnWidth', {'1x', 70, '1x'}, ...
    'Padding',     [0 0 0 0], ...
    'ColumnSpacing', 6);
colsGL.Layout.Row = 2; colsGL.Layout.Column = 1;

% ─ Left column: Available ─────────────────────────────────────────────────
leftGL = uigridlayout(colsGL, [2 1], ...
    'RowHeight', {18, '1x'}, ...
    'Padding',   [0 0 0 0], ...
    'RowSpacing', 2);
leftGL.Layout.Column = 1;

uilabel(leftGL, 'Text', 'Available Actions', ...
    'FontSize', 10, 'FontColor', [0.65 0.65 0.65], ...
    'HorizontalAlignment', 'center').Layout.Row = 1;

lbAvail = uilistbox(leftGL, ...
    'Items',           labelsFor(availableIds), ...
    'Value',           {}, ...
    'Multiselect',     'on', ...
    'BackgroundColor', [0.20 0.20 0.20], ...
    'FontColor',       [0.90 0.90 0.90], ...
    'FontSize',        11);
lbAvail.Layout.Row = 2;

% ─ Middle column: action buttons ──────────────────────────────────────────
midGL = uigridlayout(colsGL, [7 1], ...
    'RowHeight', {'1x', 28, 28, 8, 28, 28, '1x'}, ...
    'Padding',   [4 0 4 0], ...
    'RowSpacing', 4);
midGL.Layout.Column = 2;

btnAdd    = uibutton(midGL, 'Text', [char(8594) ' Add'],    ...
    'FontSize', 10, 'BackgroundColor', [0.28 0.28 0.28], ...
    'FontColor', [0.9 0.9 0.9], ...
    'Tooltip', 'Add selected action to toolbar', ...
    'ButtonPushedFcn', @onAdd);
btnAdd.Layout.Row = 2;

btnRemove = uibutton(midGL, 'Text', [char(8592) ' Remove'], ...
    'FontSize', 10, 'BackgroundColor', [0.28 0.28 0.28], ...
    'FontColor', [0.9 0.9 0.9], ...
    'Tooltip', 'Remove selected action from toolbar', ...
    'ButtonPushedFcn', @onRemove);
btnRemove.Layout.Row = 3;

btnUp   = uibutton(midGL, 'Text', [char(8679) ' Up'],   ...
    'FontSize', 10, 'BackgroundColor', [0.28 0.28 0.28], ...
    'FontColor', [0.9 0.9 0.9], ...
    'Tooltip', 'Move selected action up', ...
    'ButtonPushedFcn', @onMoveUp);
btnUp.Layout.Row = 5;

btnDown = uibutton(midGL, 'Text', [char(8681) ' Down'], ...
    'FontSize', 10, 'BackgroundColor', [0.28 0.28 0.28], ...
    'FontColor', [0.9 0.9 0.9], ...
    'Tooltip', 'Move selected action down', ...
    'ButtonPushedFcn', @onMoveDown);
btnDown.Layout.Row = 6;

% ─ Right column: Current Toolbar ──────────────────────────────────────────
rightGL = uigridlayout(colsGL, [2 1], ...
    'RowHeight', {18, '1x'}, ...
    'Padding',   [0 0 0 0], ...
    'RowSpacing', 2);
rightGL.Layout.Column = 3;

uilabel(rightGL, 'Text', 'Current Toolbar', ...
    'FontSize', 10, 'FontColor', [0.65 0.65 0.65], ...
    'HorizontalAlignment', 'center').Layout.Row = 1;

lbCurrent = uilistbox(rightGL, ...
    'Items',           labelsFor(currentIds), ...
    'Value',           {}, ...
    'Multiselect',     'on', ...
    'BackgroundColor', [0.20 0.20 0.20], ...
    'FontColor',       [0.90 0.90 0.90], ...
    'FontSize',        11);
lbCurrent.Layout.Row = 2;

% ── Bottom row: Reset | spacer | Cancel | OK ──────────────────────────────
botGL = uigridlayout(rootGL, [1 4], ...
    'ColumnWidth', {90, '1x', 80, 80}, ...
    'Padding',     [0 0 0 0], ...
    'ColumnSpacing', 6);
botGL.Layout.Row = 3; botGL.Layout.Column = 1;

btnReset = uibutton(botGL, 'Text', 'Reset to Default', ...
    'FontSize', 10, 'BackgroundColor', [0.28 0.28 0.28], ...
    'FontColor', [0.9 0.9 0.9], ...
    'Tooltip', 'Restore the original default toolbar', ...
    'ButtonPushedFcn', @onReset);
btnReset.Layout.Column = 1;

% Spacer via empty label
uilabel(botGL, 'Text', '').Layout.Column = 2;

btnCancel = uibutton(botGL, 'Text', 'Cancel', ...
    'FontSize', 11, 'BackgroundColor', [0.35 0.22 0.22], ...
    'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @onCancel);
btnCancel.Layout.Column = 3;

btnOK = uibutton(botGL, 'Text', 'OK', ...
    'FontSize', 11, 'BackgroundColor', [0.18 0.38 0.18], ...
    'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @onOK);
btnOK.Layout.Column = 4;

% ── Wait for user ─────────────────────────────────────────────────────────
uiwait(dlg);

% ── Collect result (set by onOK / onCancel) ───────────────────────────────
% config is already set in onOK, or remains {} if cancelled/closed.

% ════════════════════════════════════════════════════════════════════════
%  Nested helper functions
% ════════════════════════════════════════════════════════════════════════

    function labels = labelsFor(ids)
    %LABELSFOR  Convert a cell of IDs to display labels using the registry.
        if isempty(ids)
            labels = {};
            return;
        end
        labels = cell(1, numel(ids));
        for k = 1:numel(ids)
            idx = find(strcmp(allIds, ids{k}), 1);
            if ~isempty(idx)
                labels{k} = allLabels{idx};
            else
                labels{k} = ids{k};
            end
        end
    end

    function idsOut = idsForLabels(selectedLabels)
    %IDSFORLABELS  Reverse-map display labels back to IDs.
        if isempty(selectedLabels)
            idsOut = {};
            return;
        end
        if ischar(selectedLabels), selectedLabels = {selectedLabels}; end
        idsOut = cell(1, numel(selectedLabels));
        for k = 1:numel(selectedLabels)
            idx = find(strcmp(allLabels, selectedLabels{k}), 1);
            if ~isempty(idx)
                idsOut{k} = allIds{idx};
            else
                idsOut{k} = selectedLabels{k};
            end
        end
    end

    function refreshLists()
    %REFRESHLISTS  Sync listbox Items with working ID arrays.
        lbAvail.Items   = labelsFor(availableIds);
        lbAvail.Value   = {};
        lbCurrent.Items = labelsFor(currentIds);
        lbCurrent.Value = {};
    end

    % ── Button callbacks ───────────────────────────────────────────────────

    function onAdd(~, ~)
    %ONADD  Move selected available actions into the toolbar.
        sel = lbAvail.Value;
        if isempty(sel), return; end
        selIds = idsForLabels(sel);
        currentIds  = [currentIds  selIds];
        availableIds = availableIds(~ismember(availableIds, selIds));
        refreshLists();
    end

    function onRemove(~, ~)
    %ONREMOVE  Move selected toolbar actions back to available.
        sel = lbCurrent.Value;
        if isempty(sel), return; end
        selIds = idsForLabels(sel);
        availableIds = [availableIds selIds];
        currentIds   = currentIds(~ismember(currentIds, selIds));
        refreshLists();
    end

    function onMoveUp(~, ~)
    %ONMOVEUP  Shift selected current-toolbar item(s) one position earlier.
        sel = lbCurrent.Value;
        if isempty(sel), return; end
        selIds = idsForLabels(sel);
        for k = 1:numel(selIds)
            pos = find(strcmp(currentIds, selIds{k}), 1);
            if ~isempty(pos) && pos > 1
                currentIds([pos-1 pos]) = currentIds([pos pos-1]);
            end
        end
        lbCurrent.Items = labelsFor(currentIds);
        lbCurrent.Value = labelsFor(selIds);
    end

    function onMoveDown(~, ~)
    %ONMOVEDOWN  Shift selected current-toolbar item(s) one position later.
        sel = lbCurrent.Value;
        if isempty(sel), return; end
        selIds = idsForLabels(sel);
        % Iterate in reverse to preserve relative order when shifting multiple
        for k = numel(selIds):-1:1
            pos = find(strcmp(currentIds, selIds{k}), 1);
            if ~isempty(pos) && pos < numel(currentIds)
                currentIds([pos pos+1]) = currentIds([pos+1 pos]);
            end
        end
        lbCurrent.Items = labelsFor(currentIds);
        lbCurrent.Value = labelsFor(selIds);
    end

    function onReset(~, ~)
    %ONRESET  Restore the factory-default toolbar configuration.
        defaults     = dataplotter.toolbarDefaultConfig();
        currentIds   = defaults(ismember(defaults, allIds));
        availableIds = allIds(~ismember(allIds, currentIds));
        refreshLists();
    end

    function onOK(~, ~)
    %ONOK  Accept changes and close dialog.
        config = currentIds;
        if isvalid(dlg)
            uiresume(dlg);
            delete(dlg);
        end
    end

    function onCancel(~, ~)
    %ONCANCEL  Discard changes and close dialog.
        config = {};
        if isvalid(dlg)
            uiresume(dlg);
            delete(dlg);
        end
    end

end % toolbarConfig


