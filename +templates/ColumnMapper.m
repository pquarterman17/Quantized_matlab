function result = ColumnMapper(data, opts)
%COLUMNMAPPER  Modal dialog for overriding column roles, labels, and units.
%
%   correctedData = templates.ColumnMapper(data)
%   correctedData = templates.ColumnMapper(data, Template=tmpl)
%   correctedData = templates.ColumnMapper(data, ParentFig=fig)
%
%   Opens a modal uifigure that shows a preview of the raw data and lets
%   the user reassign which columns are X-axis, Y-channels, or skipped,
%   and edit labels and units.  A live mini-plot updates as roles change.
%
%   Returns the corrected data struct on Apply, or empty [] on Cancel.
%   Optionally pre-populates from a template struct.
%
%   INPUTS:
%       data     — data struct from parser (must have .time, .values, .labels, .units)
%       Template — (optional) template struct to pre-populate overrides
%       ParentFig — (optional) parent uifigure for dialog positioning
%
%   OUTPUT:
%       result   — corrected data struct, or [] if cancelled
%
%   See also templates.TemplateEngine, templates.MetadataEditor

    arguments
        data      (1,1) struct
        opts.Template  = []
        opts.ParentFig = []
    end

    result = [];

    % ════════════════════════════════════════════════════════════════
    %  Reconstruct all columns (X + Y) into a single matrix for display
    % ════════════════════════════════════════════════════════════════
    allData   = [data.time(:), data.values];
    nRows     = size(allData, 1);
    nCols     = size(allData, 2);

    % Build initial column info
    xLabel = 'X';
    if isfield(data, 'metadata') && isfield(data.metadata, 'xColumnName')
        xLabel = data.metadata.xColumnName;
    end
    xUnit = '';
    if isfield(data, 'metadata') && isfield(data.metadata, 'xColumnUnit')
        xUnit = data.metadata.xColumnUnit;
    end

    colLabels = [{xLabel}, data.labels(:)'];
    colUnits  = [{xUnit},  data.units(:)'];
    colRoles  = [{'X-axis'}, repmat({'Y-channel'}, 1, nCols-1)];

    % Apply template pre-population if provided
    if ~isempty(opts.Template) && isfield(opts.Template, 'overrides')
        ov = opts.Template.overrides;
        if isfield(ov, 'labels') && isstruct(ov.labels)
            flds = fieldnames(ov.labels);
            for k = 1:numel(flds)
                idx = str2double(flds{k}) + 1;
                if idx >= 1 && idx <= nCols
                    colLabels{idx} = ov.labels.(flds{k});
                end
            end
        end
        if isfield(ov, 'units') && isstruct(ov.units)
            flds = fieldnames(ov.units);
            for k = 1:numel(flds)
                idx = str2double(flds{k}) + 1;
                if idx >= 1 && idx <= nCols
                    colUnits{idx} = ov.units.(flds{k});
                end
            end
        end
        if isfield(ov, 'skipColumns')
            for idx0 = ov.skipColumns(:)'
                idx = idx0 + 1;
                if idx >= 1 && idx <= nCols
                    colRoles{idx} = 'Skip';
                end
            end
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  Build dialog
    % ════════════════════════════════════════════════════════════════
    screenSize = get(0, 'ScreenSize');
    dlgW = min(1000, screenSize(3) - 100);
    dlgH = min(650, screenSize(4) - 120);

    dlgFig = uifigure('Name', 'Column Mapper', ...
        'WindowStyle', 'modal', ...
        'Resize', 'on', ...
        'Position', [round((screenSize(3)-dlgW)/2), ...
                     round((screenSize(4)-dlgH)/2), dlgW, dlgH]);

    % Dark theme detection
    isDark = false;
    if ~isempty(opts.ParentFig) && isvalid(opts.ParentFig)
        try
            bgc = opts.ParentFig.Color;
            isDark = mean(bgc) < 0.5;
        catch
        end
    end
    if isDark
        dlgFig.Color = [0.18 0.18 0.20];
    end

    rootGL = uigridlayout(dlgFig, [2 1], ...
        'RowHeight', {'1x', 40}, 'Padding', [8 8 8 8]);

    % Top: split left (table) / right (column config + preview plot)
    topGL = uigridlayout(rootGL, [1 2], ...
        'ColumnWidth', {'1x', '1x'}, 'Padding', 0);

    % ── Left panel: data preview table ──────────────────────────────
    leftGL = uigridlayout(topGL, [2 1], ...
        'RowHeight', {22, '1x'}, 'Padding', 0);
    uilabel(leftGL, 'Text', sprintf('Data Preview (%d rows × %d columns)', nRows, nCols), ...
        'FontWeight', 'bold');

    previewRows = min(nRows, 50);
    tblPreview = uitable(leftGL, ...
        'Data', allData(1:previewRows, :), ...
        'ColumnName', colLabels, ...
        'RowName', 'numbered');
    if isDark
        tblPreview.BackgroundColor = [0.22 0.22 0.24; 0.26 0.26 0.28];
        % uitable does not expose a direct FontColor property — apply the
        % text color via a uistyle (R2021a+) which is the supported path.
        addStyle(tblPreview, uistyle('FontColor', [0.9 0.9 0.9]));
    end

    % ── Right panel: column config + mini preview plot ──────────────
    rightGL = uigridlayout(topGL, [2 1], ...
        'RowHeight', {'1x', '1x'}, 'Padding', 0);

    % Column configuration table
    configGL = uigridlayout(rightGL, [2 1], ...
        'RowHeight', {22, '1x'}, 'Padding', 0);
    uilabel(configGL, 'Text', 'Column Configuration', 'FontWeight', 'bold');

    roleChoices = {'X-axis', 'Y-channel', 'Skip'};
    configData = cell(nCols, 3);
    for c = 1:nCols
        configData{c, 1} = colRoles{c};
        configData{c, 2} = colLabels{c};
        configData{c, 3} = colUnits{c};
    end

    tblConfig = uitable(configGL, ...
        'Data', configData, ...
        'ColumnName', {'Role', 'Label', 'Unit'}, ...
        'RowName', arrayfun(@(k) sprintf('Col %d', k), 1:nCols, 'UniformOutput', false), ...
        'ColumnEditable', [true true true], ...
        'ColumnFormat', {roleChoices, 'char', 'char'}, ...
        'ColumnWidth', {90, 'auto', 60});
    if isDark
        tblConfig.BackgroundColor = [0.22 0.22 0.24; 0.26 0.26 0.28];
        addStyle(tblConfig, uistyle('FontColor', [0.9 0.9 0.9]));
    end

    % Mini preview plot
    previewAx = uiaxes(rightGL);
    title(previewAx, 'Preview');
    hold(previewAx, 'on');
    grid(previewAx, 'on');

    % Initial plot
    updatePreview();

    % Wire config table edits to live preview
    tblConfig.CellEditCallback = @(~,~) updatePreview();

    % ── Bottom: buttons ─────────────────────────────────────────────
    btnGL = uigridlayout(rootGL, [1 4], ...
        'ColumnWidth', {'1x', 140, 140, 100}, 'Padding', 0);
    uilabel(btnGL);  % spacer

    btnSaveTemplate = uibutton(btnGL, 'Text', 'Save as Template', ...
        'ButtonPushedFcn', @onSaveTemplate);
    btnApply = uibutton(btnGL, 'Text', 'Apply', ...
        'ButtonPushedFcn', @onApply);
    btnCancel = uibutton(btnGL, 'Text', 'Cancel', ...
        'ButtonPushedFcn', @(~,~) close(dlgFig));

    if isDark
        btnApply.BackgroundColor = [0.25 0.50 0.25];
        btnApply.FontColor = [1 1 1];
    end

    % ════════════════════════════════════════════════════════════════
    %  Wait for modal to close
    % ════════════════════════════════════════════════════════════════
    uiwait(dlgFig);

    % ════════════════════════════════════════════════════════════════
    %  Nested callbacks
    % ════════════════════════════════════════════════════════════════
    function updatePreview()
        cla(previewAx);
        cfg = tblConfig.Data;
        xIdx = [];
        yIdx = [];
        yLabels = {};
        for ci = 1:size(cfg, 1)
            if strcmp(cfg{ci, 1}, 'X-axis')
                xIdx = ci;
            elseif strcmp(cfg{ci, 1}, 'Y-channel')
                yIdx(end+1) = ci; %#ok<AGROW>
                yLabels{end+1} = cfg{ci, 2}; %#ok<AGROW>
            end
        end
        if isempty(xIdx) || isempty(yIdx), return; end

        xVec = allData(:, xIdx);
        colors = lines(numel(yIdx));
        for yi = 1:numel(yIdx)
            plot(previewAx, xVec, allData(:, yIdx(yi)), '-', ...
                'Color', colors(yi,:), 'DisplayName', yLabels{yi});
        end
        xLbl = cfg{xIdx, 2};
        if ~isempty(cfg{xIdx, 3})
            xLbl = [xLbl ' (' cfg{xIdx, 3} ')'];
        end
        xlabel(previewAx, xLbl);
        if numel(yIdx) <= 5
            legend(previewAx, 'Location', 'best');
        end
    end

    function onApply(~, ~)
        cfg = tblConfig.Data;
        xIdx = [];
        yIdx = [];
        newLabels = {};
        newUnits  = {};
        for ci = 1:size(cfg, 1)
            if strcmp(cfg{ci, 1}, 'X-axis')
                xIdx = ci;
            elseif strcmp(cfg{ci, 1}, 'Y-channel')
                yIdx(end+1) = ci; %#ok<AGROW>
                newLabels{end+1} = cfg{ci, 2}; %#ok<AGROW>
                newUnits{end+1}  = cfg{ci, 3}; %#ok<AGROW>
            end
        end
        if isempty(xIdx)
            uialert(dlgFig, 'Please assign one column as X-axis.', 'No X-axis');
            return;
        end
        if isempty(yIdx)
            uialert(dlgFig, 'Please assign at least one Y-channel.', 'No Y data');
            return;
        end

        % Build corrected struct
        result = data;
        result.time   = allData(:, xIdx);
        result.values = allData(:, yIdx);
        result.labels = newLabels;
        result.units  = newUnits;
        result.metadata.xColumnName = cfg{xIdx, 2};
        result.metadata.xColumnUnit = cfg{xIdx, 3};

        % Store all-columns matrix for future template re-application
        result.metadata.parserSpecific.allColumns = allData;

        % Tag that this was user-mapped
        result.metadata.templateApplied = true;

        close(dlgFig);
    end

    function onSaveTemplate(~, ~)
        answer = inputdlg('Template name:', 'Save as Template', 1, {''});
        if isempty(answer) || isempty(strtrim(answer{1})), return; end

        cfg = tblConfig.Data;
        tmpl = struct();
        tmpl.name    = strtrim(answer{1});
        tmpl.type    = 'tabular';
        tmpl.version = 1;

        % Build match criteria
        tmpl.match.headerFingerprint = templates.TemplateEngine.fingerprint(data);
        tmpl.match.columnNames = data.labels;
        if isfield(data.metadata, 'parserName')
            tmpl.match.parserName = data.metadata.parserName;
        end

        % Build overrides from current config
        xIdx = [];
        yIdx = [];
        skipIdx = [];
        labelOv = struct();
        unitOv  = struct();
        for ci = 1:size(cfg, 1)
            if strcmp(cfg{ci, 1}, 'X-axis')
                xIdx = ci;
            elseif strcmp(cfg{ci, 1}, 'Y-channel')
                yIdx(end+1) = ci; %#ok<AGROW>
            else
                skipIdx(end+1) = ci; %#ok<AGROW>
            end
            % Record label/unit overrides where they differ from parser
            if ci <= numel(colLabels) && ~strcmp(cfg{ci, 2}, colLabels{ci})
                labelOv.(sprintf('x%d', ci-1)) = cfg{ci, 2};
            end
            if ci <= numel(colUnits) && ~strcmp(cfg{ci, 3}, colUnits{ci})
                unitOv.(sprintf('x%d', ci-1)) = cfg{ci, 3};
            end
        end

        ov = struct();
        if ~isempty(xIdx),    ov.xColumn = xIdx - 1; end  % 0-based for JSON
        if ~isempty(yIdx),    ov.yColumns = yIdx - 1; end
        if ~isempty(skipIdx), ov.skipColumns = skipIdx - 1; end
        if ~isempty(fieldnames(labelOv)), ov.labels = labelOv; end
        if ~isempty(fieldnames(unitOv)),  ov.units = unitOv; end
        tmpl.overrides = ov;

        templates.TemplateEngine.save(tmpl);

        uialert(dlgFig, sprintf('Template "%s" saved.', tmpl.name), ...
            'Saved', 'Icon', 'success');
    end
end
