function result = MetadataEditor(data, opts)
%METADATAEDITOR  Modal dialog for overriding image metadata fields.
%
%   correctedData = templates.MetadataEditor(data)
%   correctedData = templates.MetadataEditor(data, ParentFig=fig)
%   correctedData = templates.MetadataEditor(data, Template=tmpl)
%
%   Opens a modal dialog showing current metadata from the image parser
%   and lets the user override fields like sample name, pixel size,
%   voltage, operator, etc.  Designed for the FermiViewer use case where
%   instrument-burned metadata is wrong (e.g. stale sample name on SEM).
%
%   Returns the corrected data struct on Apply, or [] on Cancel.
%
%   See also templates.TemplateEngine, templates.ColumnMapper

    arguments
        data      (1,1) struct
        opts.Template  = []
        opts.ParentFig = []
    end

    result = [];

    % ════════════════════════════════════════════════════════════════
    %  Extract current metadata
    % ════════════════════════════════════════════════════════════════
    ps = struct();
    if isfield(data, 'metadata') && isfield(data.metadata, 'parserSpecific')
        ps = data.metadata.parserSpecific;
    end

    % Define editable fields: {fieldName, displayLabel, currentValue, inputType}
    editableFields = {
        'sampleName',    'Sample Name',    getField(ps, 'sampleName', ''),    'text'
        'pixelSize',     'Pixel Size',     getField(ps, 'pixelSize', NaN),    'numeric'
        'pixelUnit',     'Pixel Unit',     getField(ps, 'pixelUnit', ''),     'text'
        'voltage',       'Voltage (kV)',   getField(ps, 'voltage', NaN),      'numeric'
        'operator',      'Operator',       getField(ps, 'operator', ''),      'text'
        'magnification', 'Magnification',  getField(ps, 'magnification', NaN),'numeric'
        'detector',      'Detector',       getField(ps, 'detector', ''),      'text'
        'workingDist',   'Working Dist.',  getField(ps, 'workingDist', NaN),  'numeric'
    };

    % Also extract imageData sub-struct fields if they differ
    if isfield(ps, 'imageData')
        img = ps.imageData;
        for k = 1:size(editableFields, 1)
            fn = editableFields{k, 1};
            if isfield(img, fn)
                currentPs = editableFields{k, 3};
                currentImg = img.(fn);
                % Prefer imageData value if parserSpecific is empty
                if (ischar(currentPs) && isempty(currentPs)) || ...
                   (isnumeric(currentPs) && isnan(currentPs))
                    editableFields{k, 3} = currentImg;
                end
            end
        end
    end

    % Pre-populate from template if provided
    if ~isempty(opts.Template) && isfield(opts.Template, 'overrides')
        ov = opts.Template.overrides;
        for k = 1:size(editableFields, 1)
            fn = editableFields{k, 1};
            if isfield(ov, fn)
                editableFields{k, 3} = ov.(fn);
            end
        end
    end

    nFields = size(editableFields, 1);

    % ════════════════════════════════════════════════════════════════
    %  Build dialog
    % ════════════════════════════════════════════════════════════════
    screenSize = get(0, 'ScreenSize');
    dlgW = 420;
    dlgH = min(50 + nFields * 40 + 60, screenSize(4) - 120);

    dlgFig = uifigure('Name', 'Edit Metadata', ...
        'WindowStyle', 'modal', ...
        'Resize', 'on', ...
        'Position', [round((screenSize(3)-dlgW)/2), ...
                     round((screenSize(4)-dlgH)/2), dlgW, dlgH]);

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

    rootGL = uigridlayout(dlgFig, [3 1], ...
        'RowHeight', {22, '1x', 40}, 'Padding', [10 10 10 10]);

    uilabel(rootGL, 'Text', 'Override image metadata fields:', ...
        'FontWeight', 'bold');

    % Scrollable fields panel
    fieldPanel = uipanel(rootGL, 'BorderType', 'none', 'Scrollable', 'on');
    if isDark
        fieldPanel.BackgroundColor = [0.18 0.18 0.20];
    end

    rowHeights = repmat({32}, 1, nFields);
    fieldGL = uigridlayout(fieldPanel, [nFields, 3], ...
        'RowHeight', rowHeights, ...
        'ColumnWidth', {120, '1x', 100}, ...
        'Padding', [4 4 4 4], 'RowSpacing', 4);

    editWidgets = cell(nFields, 1);
    for k = 1:nFields
        fn    = editableFields{k, 1};
        label = editableFields{k, 2};
        val   = editableFields{k, 3};
        kind  = editableFields{k, 4};

        lbl = uilabel(fieldGL, 'Text', label, 'HorizontalAlignment', 'right');
        if isDark, lbl.FontColor = [0.85 0.85 0.85]; end

        if strcmp(kind, 'numeric')
            if isnan(val)
                ef = uieditfield(fieldGL, 'text', 'Value', '');
            else
                ef = uieditfield(fieldGL, 'text', 'Value', num2str(val, '%.6g'));
            end
        else
            ef = uieditfield(fieldGL, 'text', 'Value', char(val));
        end
        editWidgets{k} = ef;

        % Show current parser value as reference
        origStr = '';
        if isnumeric(val) && ~isnan(val)
            origStr = sprintf('(was: %g)', val);
        elseif ischar(val) && ~isempty(val)
            origStr = sprintf('(was: %s)', val);
        end
        refLbl = uilabel(fieldGL, 'Text', origStr, ...
            'FontSize', 10, 'FontColor', [0.5 0.5 0.5]);
    end

    % ── Buttons ─────────────────────────────────────────────────────
    btnGL = uigridlayout(rootGL, [1 4], ...
        'ColumnWidth', {'1x', 140, 80, 80}, 'Padding', 0);
    uilabel(btnGL);  % spacer

    uibutton(btnGL, 'Text', 'Save as Template', ...
        'ButtonPushedFcn', @onSaveTemplate);
    btnApply = uibutton(btnGL, 'Text', 'Apply', ...
        'ButtonPushedFcn', @onApply);
    uibutton(btnGL, 'Text', 'Cancel', ...
        'ButtonPushedFcn', @(~,~) close(dlgFig));

    if isDark
        btnApply.BackgroundColor = [0.25 0.50 0.25];
        btnApply.FontColor = [1 1 1];
    end

    uiwait(dlgFig);

    % ════════════════════════════════════════════════════════════════
    %  Nested callbacks
    % ════════════════════════════════════════════════════════════════
    function onApply(~, ~)
        result = data;
        ov = collectOverrides();
        if ~isempty(fieldnames(ov))
            tmplStruct = struct('type', 'image_metadata', 'overrides', ov);
            result = templates.TemplateEngine.apply(result, tmplStruct);
            result.metadata.templateApplied = true;
        end
        close(dlgFig);
    end

    function onSaveTemplate(~, ~)
        answer = inputdlg('Template name:', 'Save as Template', 1, {''});
        if isempty(answer) || isempty(strtrim(answer{1})), return; end

        tmpl = struct();
        tmpl.name    = strtrim(answer{1});
        tmpl.type    = 'image_metadata';
        tmpl.version = 1;

        % Build match criteria
        tmpl.match = struct();
        if isfield(data.metadata, 'parserName')
            tmpl.match.parserName = data.metadata.parserName;
        end
        if isfield(ps, 'instrument')
            tmpl.match.instrument = ps.instrument;
        elseif isfield(ps, 'instrumentType')
            tmpl.match.instrument = ps.instrumentType;
        end

        tmpl.overrides = collectOverrides();
        templates.TemplateEngine.save(tmpl);
        uialert(dlgFig, sprintf('Template "%s" saved.', tmpl.name), ...
            'Saved', 'Icon', 'success');
    end

    function ov = collectOverrides()
    %COLLECTOVERRIDES  Read edit widgets and build an overrides struct.
        ov = struct();
        for ki = 1:nFields
            fn   = editableFields{ki, 1};
            kind = editableFields{ki, 4};
            raw  = strtrim(editWidgets{ki}.Value);
            if isempty(raw), continue; end

            if strcmp(kind, 'numeric')
                numVal = str2double(raw);
                if ~isnan(numVal)
                    ov.(fn) = numVal;
                end
            else
                ov.(fn) = raw;
            end
        end
    end
end


function val = getField(s, fn, default)
%GETFIELD  Safe field access with default.
    if isfield(s, fn) && ~isempty(s.(fn))
        val = s.(fn);
    else
        val = default;
    end
end
