function TemplateManager(parentFig)
%TEMPLATEMANAGER  Browse, edit, and manage dataset templates.
%
%   Syntax:
%       templates.TemplateManager()
%       templates.TemplateManager(parentFig)
%
%   Opens a non-modal dialog listing all shipped and user-created templates.
%   The right panel shows details for the selected template.
%
%   Inputs:
%       parentFig — (optional) parent uifigure used for screen centering
%
%   Buttons:
%       [Edit...]   — open ColumnMapper (tabular) or MetadataEditor
%                     (image_metadata) pre-populated with the template
%       [Delete]    — delete user templates; shipped templates are protected
%       [Import...] — load a .json file from disk and register as user template
%       [Export...] — save selected template to a user-chosen .json path
%       [Close]     — close the dialog
%
%   See also templates.TemplateEngine, templates.ColumnMapper,
%            templates.MetadataEditor

    arguments
        parentFig = []
    end

    % ════════════════════════════════════════════════════════════════
    %  Create figure
    % ════════════════════════════════════════════════════════════════
    fig = uifigure('Name', 'Template Manager', ...
                   'Position', [100 100 520 420], ...
                   'Resize', 'on', ...
                   'WindowStyle', 'normal');

    % Centre on parent or screen
    if ~isempty(parentFig) && isvalid(parentFig)
        pPos = parentFig.Position;
        fig.Position(1) = pPos(1) + (pPos(3) - fig.Position(3)) / 2;
        fig.Position(2) = pPos(2) + (pPos(4) - fig.Position(4)) / 2;
    else
        movegui(fig, 'center');
    end

    % ════════════════════════════════════════════════════════════════
    %  Top-level grid: [list | details] over [buttons]
    % ════════════════════════════════════════════════════════════════
    mainGrid = uigridlayout(fig, [2 1]);
    mainGrid.RowHeight   = {'1x', 44};
    mainGrid.ColumnWidth = {'1x'};
    mainGrid.Padding     = [8 8 8 8];
    mainGrid.RowSpacing  = 6;

    % Inner split: list (left) | details (right)
    splitGrid = uigridlayout(mainGrid, [1 2]);
    splitGrid.Layout.Row    = 1;
    splitGrid.Layout.Column = 1;
    splitGrid.ColumnWidth   = {180, '1x'};
    splitGrid.RowHeight     = {'1x'};
    splitGrid.Padding       = [0 0 0 0];
    splitGrid.ColumnSpacing = 8;

    % ── Left: list box ──
    listPanel = uipanel(splitGrid, 'Title', 'Templates', 'FontWeight', 'bold');
    listPanel.Layout.Row    = 1;
    listPanel.Layout.Column = 1;

    listGrid = uigridlayout(listPanel, [1 1]);
    listGrid.Padding = [4 4 4 4];

    lb = uilistbox(listGrid, 'Items', {}, 'ValueChangedFcn', @onSelect);
    lb.Layout.Row    = 1;
    lb.Layout.Column = 1;

    % ── Right: details panel ──
    detailPanel = uipanel(splitGrid, 'Title', 'Details', 'FontWeight', 'bold');
    detailPanel.Layout.Row    = 1;
    detailPanel.Layout.Column = 2;

    detailGrid = uigridlayout(detailPanel, [1 1]);
    detailGrid.Padding = [6 6 6 6];

    detailArea = uitextarea(detailGrid, ...
        'Editable', 'off', ...
        'Value', {'Select a template to see details.'}, ...
        'FontName', 'Courier New', ...
        'FontSize', 11);
    detailArea.Layout.Row    = 1;
    detailArea.Layout.Column = 1;

    % ── Bottom: buttons ──
    btnGrid = uigridlayout(mainGrid, [1 6]);
    btnGrid.Layout.Row    = 2;
    btnGrid.Layout.Column = 1;
    btnGrid.ColumnWidth   = {'1x', 80, 80, 80, 80, 80};
    btnGrid.Padding       = [0 0 0 0];
    btnGrid.ColumnSpacing = 6;

    % Spacer in column 1 (flexible)
    lbl = uilabel(btnGrid, 'Text', '');
    lbl.Layout.Row = 1; lbl.Layout.Column = 1;

    btnEdit   = uibutton(btnGrid, 'push', 'Text', 'Edit...',    'ButtonPushedFcn', @onEdit);
    btnDelete = uibutton(btnGrid, 'push', 'Text', 'Delete',     'ButtonPushedFcn', @onDelete);
    btnImport = uibutton(btnGrid, 'push', 'Text', 'Import...', 'ButtonPushedFcn', @onImport);
    btnExport = uibutton(btnGrid, 'push', 'Text', 'Export...', 'ButtonPushedFcn', @onExport);
    btnClose  = uibutton(btnGrid, 'push', 'Text', 'Close',      'ButtonPushedFcn', @(~,~) close(fig));

    btnEdit.Layout.Row   = 1; btnEdit.Layout.Column   = 2;
    btnDelete.Layout.Row = 1; btnDelete.Layout.Column = 3;
    btnImport.Layout.Row = 1; btnImport.Layout.Column = 4;
    btnExport.Layout.Row = 1; btnExport.Layout.Column = 5;
    btnClose.Layout.Row  = 1; btnClose.Layout.Column  = 6;

    % ════════════════════════════════════════════════════════════════
    %  State
    % ════════════════════════════════════════════════════════════════
    allTemplates = {};   % cell array of template structs
    refreshList();

    % ════════════════════════════════════════════════════════════════
    %  Callbacks
    % ════════════════════════════════════════════════════════════════
    function refreshList()
        allTemplates = templates.TemplateEngine.loadAll(ForceReload=true);
        items = buildListItems(allTemplates);
        lb.Items = items;
        if ~isempty(items)
            lb.Value = items{1};
            updateDetails(1);
        else
            detailArea.Value = {'(No templates found.)'};
        end
    end

    function onSelect(src, ~)
        idx = find(strcmp(src.Items, src.Value), 1);
        if isempty(idx), return; end
        updateDetails(idx);
    end

    function updateDetails(idx)
        if idx < 1 || idx > numel(allTemplates)
            detailArea.Value = {'(No selection.)'};
            return;
        end
        t = allTemplates{idx};
        lines = buildDetailText(t);
        detailArea.Value = lines;
    end

    function onEdit(~, ~)
        idx = selectedIndex();
        if idx == 0, return; end
        t = allTemplates{idx};

        % We need a dummy data struct to open the editors
        % Build a minimal stub from the template's match criteria
        stubData = makeStubData(t);

        if strcmp(t.type, 'tabular')
            result = templates.ColumnMapper(stubData, Template=t, ParentFig=fig);
        else
            result = templates.MetadataEditor(stubData, Template=t, ParentFig=fig);
        end

        if ~isempty(result)
            % Extract the overrides back into the template and re-save
            updatedTmpl = t;
            updatedTmpl = extractOverrides(updatedTmpl, result, stubData);
            templates.TemplateEngine.save(updatedTmpl);
            refreshList();
            uialert(fig, sprintf('Template "%s" updated.', t.name), 'Saved', ...
                'Icon', 'success');
        end
    end

    function onDelete(~, ~)
        idx = selectedIndex();
        if idx == 0, return; end
        t = allTemplates{idx};

        % Guard: cannot delete shipped templates
        src = '';
        if isfield(t, 'source_'), src = t.source_; end
        if isfield(t, 'source'),  src = t.source;  end
        if strcmp(src, 'shipped')
            uialert(fig, ...
                sprintf('"%s" is a shipped template and cannot be deleted.', t.name), ...
                'Protected Template', 'Icon', 'warning');
            return;
        end

        answer = uiconfirm(fig, ...
            sprintf('Delete template "%s"?', t.name), ...
            'Confirm Delete', ...
            'Options', {'Delete', 'Cancel'}, ...
            'DefaultOption', 'Cancel', ...
            'CancelOption', 'Cancel', ...
            'Icon', 'warning');
        if strcmp(answer, 'Delete')
            templates.TemplateEngine.delete(t.name);
            refreshList();
        end
    end

    function onImport(~, ~)
        [fname, fpath] = uigetfile({'*.json', 'Template JSON (*.json)'}, ...
            'Import Template', templates.TemplateEngine.userDir());
        if isequal(fname, 0), return; end

        fullPath = fullfile(fpath, fname);
        try
            txt = fileread(fullPath);
            t   = jsondecode(txt);
        catch ME
            uialert(fig, sprintf('Could not parse JSON:\n%s', ME.message), ...
                'Import Error', 'Icon', 'error');
            return;
        end

        if ~isfield(t, 'name') || isempty(t.name)
            uialert(fig, 'JSON file is missing a "name" field.', ...
                'Import Error', 'Icon', 'error');
            return;
        end
        if ~isfield(t, 'type') || isempty(t.type)
            uialert(fig, 'JSON file is missing a "type" field.', ...
                'Import Error', 'Icon', 'error');
            return;
        end

        templates.TemplateEngine.save(t);
        refreshList();
        uialert(fig, sprintf('Imported "%s" as a user template.', t.name), ...
            'Imported', 'Icon', 'success');
    end

    function onExport(~, ~)
        idx = selectedIndex();
        if idx == 0, return; end
        t = allTemplates{idx};

        safeName = regexprep(t.name, '[^\w\-]', '_');
        [fname, fpath] = uiputfile({'*.json', 'Template JSON (*.json)'}, ...
            'Export Template', [safeName '.json']);
        if isequal(fname, 0), return; end

        outPath = fullfile(fpath, fname);
        try
            fid = fopen(outPath, 'w', 'n', 'UTF-8');
            if fid < 0
                error('Could not open file for writing: %s', outPath);
            end
            cleanupFid = onCleanup(@() fclose(fid));
            % Remove internal tracking fields before export
            exportT = rmfieldIfPresent(t, {'source_', 'filePath_'});
            txt = jsonencode(exportT, PrettyPrint=true);
            fwrite(fid, txt, 'char');
        catch ME
            uialert(fig, sprintf('Export failed:\n%s', ME.message), ...
                'Export Error', 'Icon', 'error');
            return;
        end
        uialert(fig, sprintf('Exported to:\n%s', outPath), 'Exported', ...
            'Icon', 'success');
    end

    % ════════════════════════════════════════════════════════════════
    %  Local helpers
    % ════════════════════════════════════════════════════════════════
    function idx = selectedIndex()
        idx = find(strcmp(lb.Items, lb.Value), 1);
        if isempty(idx), idx = 0; end
    end

end  % TemplateManager


% ════════════════════════════════════════════════════════════════════════
%  Module-level helpers (not nested — avoids nesting count issues)
% ════════════════════════════════════════════════════════════════════════

function items = buildListItems(allTemplates)
%BUILDLISTITEMS  Build display strings for the list box.
    items = {};
    for k = 1:numel(allTemplates)
        t = allTemplates{k};
        name = '(unnamed)';
        if isfield(t, 'name') && ~isempty(t.name)
            name = t.name;
        end
        src = '';
        if isfield(t, 'source_'), src = t.source_; end
        if isfield(t, 'source'),  src = t.source;  end

        badge = '';
        if strcmp(src, 'shipped'), badge = ' [shipped]';
        elseif strcmp(src, 'user'), badge = ' [user]';
        end
        items{end+1} = [name badge]; %#ok<AGROW>
    end
end


function lines = buildDetailText(t)
%BUILDDETAILTEXT  Build the detail text lines for a single template struct.
    lines = {};

    addLine = @(lbl, val) [lines, {sprintf('%-18s %s', [lbl ':'], val)}];

    name = '(unnamed)';
    if isfield(t, 'name') && ~isempty(t.name), name = t.name; end
    lines = addLine('Name', name);

    tp = '';
    if isfield(t, 'type') && ~isempty(t.type), tp = t.type; end
    lines = addLine('Type', tp);

    src = '';
    if isfield(t, 'source_'), src = t.source_; end
    if isfield(t, 'source'),  src = t.source;  end
    lines = addLine('Source', src);

    if isfield(t, 'created') && ~isempty(t.created)
        lines = addLine('Created', char(t.created));
    end

    lines{end+1} = '';
    lines{end+1} = '-- Match criteria --';
    if isfield(t, 'match')
        m = t.match;
        if isfield(m, 'parserName') && ~isempty(m.parserName)
            lines = addLine('  parserName', m.parserName);
        end
        if isfield(m, 'instrument') && ~isempty(m.instrument)
            lines = addLine('  instrument', m.instrument);
        end
        if isfield(m, 'filePattern') && ~isempty(m.filePattern)
            lines = addLine('  filePattern', m.filePattern);
        end
        if isfield(m, 'headerFingerprint') && ~isempty(m.headerFingerprint)
            lines = addLine('  fingerprint', m.headerFingerprint);
        end
        if isfield(m, 'columnNames') && ~isempty(m.columnNames)
            if iscell(m.columnNames)
                colStr = strjoin(m.columnNames, ', ');
            else
                colStr = strjoin(cellstr(m.columnNames), ', ');
            end
            % Wrap long lists
            if numel(colStr) > 40
                colStr = [colStr(1:37) '...'];
            end
            lines = addLine('  columnNames', colStr);
        end
    end

    lines{end+1} = '';
    lines{end+1} = '-- Overrides --';
    if isfield(t, 'overrides')
        ov = t.overrides;
        if isfield(ov, 'labels') && isstruct(ov.labels) && ~isempty(fieldnames(ov.labels))
            flds = fieldnames(ov.labels);
            for k = 1:min(4, numel(flds))
                lines = addLine(sprintf('  label[%s]', flds{k}), ov.labels.(flds{k}));
            end
            if numel(flds) > 4
                lines{end+1} = sprintf('  ... (%d more)', numel(flds)-4);
            end
        else
            lines{end+1} = '  (no label overrides)';
        end
        if isfield(ov, 'units') && isstruct(ov.units) && ~isempty(fieldnames(ov.units))
            flds = fieldnames(ov.units);
            for k = 1:min(4, numel(flds))
                lines = addLine(sprintf('  unit[%s]', flds{k}), ov.units.(flds{k}));
            end
        else
            lines{end+1} = '  (no unit overrides)';
        end
    end

    % Make sure every element is a char row vector (uitextarea requirement)
    for i = 1:numel(lines)
        lines{i} = char(lines{i});
    end
end


function stubData = makeStubData(tmpl)
%MAKESTUBDATA  Build a minimal data struct from a template's match criteria.
%   Used so ColumnMapper / MetadataEditor can be opened for an Edit action
%   even when no live data is available.
    stubData = struct();
    stubData.time   = zeros(5, 1);
    stubData.labels = {};
    stubData.units  = {};
    stubData.metadata = struct('parserName', '', 'source', '', ...
                               'xColumnName', 'X', 'xColumnUnit', '', ...
                               'parserSpecific', struct());

    if isfield(tmpl, 'match')
        m = tmpl.match;
        if isfield(m, 'columnNames') && ~isempty(m.columnNames)
            cols = m.columnNames;
            if ischar(cols), cols = {cols}; end
            if isstring(cols), cols = cellstr(cols); end
            nY = max(0, numel(cols) - 1);
            stubData.labels = cols(1:min(numel(cols), max(1, nY)));
            if isfield(m, 'parserName')
                stubData.metadata.parserName = m.parserName;
            end
        end
        if isfield(m, 'parserName')
            stubData.metadata.parserName = m.parserName;
        end
    end

    nY = numel(stubData.labels);
    if nY == 0
        stubData.values = zeros(5, 1);
        stubData.labels = {'Channel 1'};
        stubData.units  = {''};
    else
        stubData.values = zeros(5, nY);
        stubData.units  = repmat({''}, 1, nY);
    end
end


function tmpl = extractOverrides(tmpl, resultData, originalStub)
%EXTRACTOVERRIDES  Diff resultData vs originalStub to update tmpl.overrides.
%   Only column label and unit changes are captured (X-axis assignment is
%   already in the template's match criteria).
    if ~isfield(tmpl, 'overrides'), tmpl.overrides = struct(); end
    if ~isfield(tmpl.overrides, 'labels'), tmpl.overrides.labels = struct(); end
    if ~isfield(tmpl.overrides, 'units'),  tmpl.overrides.units  = struct(); end

    % Y columns: indices 0..N-1 → JSON keys x0, x1, ...
    nY = numel(resultData.labels);
    for k = 1:nY
        key = sprintf('x%d', k-1);
        if k <= numel(originalStub.labels)
            origLabel = originalStub.labels{k};
        else
            origLabel = '';
        end
        newLabel = resultData.labels{k};
        if ~strcmp(newLabel, origLabel)
            tmpl.overrides.labels.(key) = newLabel;
        end

        if k <= numel(originalStub.units), origUnit = originalStub.units{k};
        else, origUnit = ''; end
        if k <= numel(resultData.units)
            newUnit = resultData.units{k};
            if ~strcmp(newUnit, origUnit)
                tmpl.overrides.units.(key) = newUnit;
            end
        end
    end
end


function s = rmfieldIfPresent(s, fields)
%RMFIELDIFPRESENT  Remove fields from struct if they exist (no error if absent).
    for k = 1:numel(fields)
        if isfield(s, fields{k})
            s = rmfield(s, fields{k});
        end
    end
end
