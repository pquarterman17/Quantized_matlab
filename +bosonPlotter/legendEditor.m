function api = legendEditor(parentFig, ctx)
%LEGENDEDITOR  Unified legend editor — all datasets at once.
%
%   bosonPlotter.legendEditor(parentFig, ctx)
%
%   Opens a modal dialog that lists every loaded dataset with its
%   visibility checkbox and editable legend-name field, plus legend-
%   level style controls (location, font size, box on/off, font weight).
%   This complements the per-dataset efLegendName fields in the main
%   GUI, which only edit the currently-active dataset.
%
%   Required ctx fields:
%       .fig                  — parent uifigure (positioning, theme)
%       .getDatasets          — @() appData.datasets
%       .setDataset           — @(idx, ds) write back to appData.datasets{idx}
%       .getStyleOverrides    — @() appData.styleOverrides
%       .setStyleOverrides    — @(s) appData.styleOverrides = s
%       .getActiveTemplate    — @() appData.activeTemplate
%       .replot               — @() trigger a replot
%       .theme                — 'Light' or 'Dark'
%
%   The dialog uses an APPLY button (not auto-apply) so the user can
%   tweak multiple rows and commit together, avoiding a render storm
%   during editing.

    arguments
        parentFig  matlab.ui.Figure
        ctx        struct
    end

    datasets = ctx.getDatasets();
    if isempty(datasets)
        bosonPlotter.quietAlert(parentFig, 'Load at least one dataset first.', 'No data');
        return;
    end

    % Resolve current effective style for legend field defaults
    tpl       = styles.template(ctx.getActiveTemplate());
    effective = bosonPlotter.resolveStyle(tpl, ctx.getStyleOverrides());

    % ── Build dialog ──────────────────────────────────────────────
    dlgW = 580;
    dlgH = 470;
    figPos = parentFig.Position;
    dlgX = figPos(1) + max(50, (figPos(3) - dlgW)/2);
    dlgY = figPos(2) + max(50, (figPos(4) - dlgH)/2);

    dlg = uifigure('Name', 'Edit Legend', 'Position', [dlgX dlgY dlgW dlgH], ...
        'Resize', 'on', 'WindowStyle', 'modal');

    root = uigridlayout(dlg, [5 1], ...
        'Padding',    [12 12 12 8], ...
        'RowSpacing', 8, ...
        'RowHeight',  {26, 30, '1x', 'fit', 36});

    % Row 1: header
    uilabel(root, ...
        'Text',       'Legend — per-dataset names, visibility, and shared style', ...
        'FontWeight', 'bold', ...
        'FontSize',   12);

    % Row 2: bulk-edit tools (operate on the "Legend name" column; the table
    % updates immediately, Apply commits to the plot).
    bulkGL = uigridlayout(root, [1 9], ...
        'Padding', [0 0 0 0], 'ColumnSpacing', 4, ...
        'ColumnWidth', {32, '1x', 52, '1x', 64, 104, '1x', 42, 116});
    uilabel(bulkGL, 'Text', 'Find:');
    efFind = uieditfield(bulkGL, 'text');
    uilabel(bulkGL, 'Text', 'Replace:');
    efRepl = uieditfield(bulkGL, 'text');
    uibutton(bulkGL, 'Text', 'Replace', 'ButtonPushedFcn', @(~,~) doReplace());
    uibutton(bulkGL, 'Text', 'Strip common', ...
        'Tooltip', 'Remove the shared prefix/suffix from every label', ...
        'ButtonPushedFcn', @(~,~) bulkApply('stripCommon'));
    metaKeys = unionMetaKeys(datasets);
    ddMeta  = uidropdown(bulkGL, 'Items', metaKeys, ...
        'Tooltip', 'Fill labels from a metadata field (temperature, field, ...)');
    btnFill = uibutton(bulkGL, 'Text', 'Fill', 'ButtonPushedFcn', @(~,~) fillFromMeta(ddMeta.Value));
    uibutton(bulkGL, 'Text', 'Reset to Auto', 'ButtonPushedFcn', @(~,~) resetAuto());
    if isscalar(metaKeys) && strcmp(metaKeys{1}, '(no metadata)')
        ddMeta.Enable = 'off'; btnFill.Enable = 'off';
    end

    % Row 3: per-dataset table (swatch + Show + Source + editable Legend name)
    N = numel(datasets);
    % Swatch colour per dataset — same resolution as the dataset list / plot
    % lines, so the colours here match what's on screen.
    swatchColors = plotting.lineColors(max(N, 1));
    for i = 1:N
        ci = datasets{i};
        if isfield(ci, 'color') && isnumeric(ci.color) && numel(ci.color) == 3
            swatchColors(i, :) = ci.color;
        end
    end
    tblData = cell(N, 4);
    for i = 1:N
        dsi = datasets{i};
        % "Visible" — ds.visible (defaults to true if missing)
        vis = true;
        if isfield(dsi, 'visible'), vis = logical(dsi.visible); end
        % "Source" — displayName if set, else filename
        baseName = '';
        if isfield(dsi, 'displayName') && ~isempty(dsi.displayName)
            baseName = dsi.displayName;
        elseif isfield(dsi, 'filepath')
            [~, fn, fext] = fileparts(dsi.filepath);
            baseName = [fn fext];
        end
        legName = '';
        if isfield(dsi, 'legendName'), legName = dsi.legendName; end
        tblData{i, 1} = char(9679);     % ● colour swatch (styled per row)
        tblData{i, 2} = vis;
        tblData{i, 3} = baseName;       % read-only source name
        tblData{i, 4} = legName;        % editable legend override
    end
    tbl = uitable(root, ...
        'Data',              tblData, ...
        'ColumnName',        {'', 'Show', 'Source', 'Legend name'}, ...
        'ColumnEditable',    [false, true, false, true], ...
        'ColumnFormat',      {'char', 'logical', 'char', 'char'}, ...
        'ColumnWidth',       {26, 46, '3x', '5x'}, ...
        'RowName',           'numbered');
    applySwatchStyles();

    % Row 3: shared legend-style controls
    styleP = uipanel(root, 'Title', 'Shared legend style', 'FontWeight', 'bold');
    styleG = uigridlayout(styleP, [2 4], ...
        'Padding',      [8 6 8 6], ...
        'ColumnSpacing', 6, ...
        'RowSpacing',    4, ...
        'ColumnWidth',   {60, '1x', 80, '1x'});

    uilabel(styleG, 'Text', 'Location:');
    locChoices = {'best','north','south','east','west', ...
        'northeast','northwest','southeast','southwest', ...
        'eastoutside','westoutside','northoutside','southoutside','off'};
    ddLoc = uidropdown(styleG, ...
        'Items', locChoices, ...
        'Value', matchOrDefault(locChoices, effective.legendLocation, 'best'));

    uilabel(styleG, 'Text', 'Font pt:');
    spFont = uispinner(styleG, ...
        'Limits', [6 32], 'Step', 1, ...
        'Value',  effective.legendFontSize);

    uilabel(styleG, 'Text', 'Box:');
    cbBox = uicheckbox(styleG, 'Text', '', 'Value', logical(effective.legendBox));

    uilabel(styleG, 'Text', 'Weight:');
    weightChoices = {'normal', 'bold'};
    ddWeight = uidropdown(styleG, ...
        'Items', weightChoices, ...
        'Value', matchOrDefault(weightChoices, effective.legendFontWeight, 'normal'));

    % Row 4: action buttons
    btnRow = uigridlayout(root, [1 3], ...
        'Padding',      [0 0 0 0], ...
        'ColumnSpacing', 8, ...
        'ColumnWidth',   {'1x', 100, 100});
    uilabel(btnRow);  % spacer
    uibutton(btnRow, 'Text', 'Cancel', ...
        'ButtonPushedFcn', @(~,~) delete(dlg));
    uibutton(btnRow, 'Text', 'Apply', ...
        'BackgroundColor', [0.20 0.50 0.85], ...
        'FontColor',       [1 1 1], ...
        'FontWeight',      'bold', ...
        'ButtonPushedFcn', @(~,~) onApply());

    % Dialog theming (matches the main GUI)
    try
        bosonPlotter.applyDialogTheme(dlg, ctx.theme);
    catch
    end
    applySwatchStyles();   % reapply after theming so swatch colours win

    % Optional handle struct for headless testing / scripting.
    if nargout > 0
        api = struct('fig', dlg, 'tbl', tbl, 'efFind', efFind, 'efRepl', efRepl, ...
            'ddMeta', ddMeta, 'doReplace', @doReplace, ...
            'doStripCommon', @() bulkApply('stripCommon'), ...
            'doFillMeta', @fillFromMeta, 'doResetAuto', @resetAuto, ...
            'legendColumn', @() tbl.Data(:, 4).');
    end

    function onApply()
        % Commit per-dataset edits. Re-fetch the dataset list now (do
        % NOT reuse the snapshot captured at dialog open) — corrections,
        % renames, or additions made in the main figure while this
        % dialog was open would otherwise be silently reverted. Only
        % two fields are patched here (.visible, .legendName), leaving
        % every other dataset field on the live struct untouched.
        tblNow       = tbl.Data;
        liveDatasets = ctx.getDatasets();
        nRows        = min(size(tblNow, 1), numel(liveDatasets));
        for k = 1:nRows
            dsK = liveDatasets{k};
            dsK.visible     = logical(tblNow{k, 2});
            dsK.legendName  = char(tblNow{k, 4});
            ctx.setDataset(k, dsK);
        end
        % Commit shared legend style
        s = ctx.getStyleOverrides();
        s.legendLocation   = ddLoc.Value;
        s.legendFontSize   = spFont.Value;
        s.legendBox        = logical(cbBox.Value);
        s.legendFontWeight = ddWeight.Value;
        ctx.setStyleOverrides(s);

        ctx.replot();
        delete(dlg);
    end

    % ── Bulk-tool helpers (nested) ─────────────────────────────────────
    function applySwatchStyles()
        if ~isvalid(tbl), return; end
        try, removeStyle(tbl); catch, end
        for ii = 1:min(N, size(tbl.Data, 1))
            addStyle(tbl, uistyle('FontColor', swatchColors(ii, :)), 'cell', [ii 1]);
        end
    end

    function eff = getEffective(d)
        % Per row: the override (col 4) if set, else the Source name (col 3).
        eff = cell(1, size(d, 1));
        for ii = 1:numel(eff)
            ov = char(d{ii, 4});
            if isempty(ov), eff{ii} = char(d{ii, 3}); else, eff{ii} = ov; end
        end
    end

    function writeBack(res)
        d = tbl.Data;
        for ii = 1:min(numel(res), size(d, 1)), d{ii, 4} = res{ii}; end
        tbl.Data = d;
        applySwatchStyles();
    end

    function doReplace()
        writeBack(bosonPlotter.legendBulkOps('findReplace', ...
            getEffective(tbl.Data), efFind.Value, efRepl.Value));
    end

    function bulkApply(opName)
        writeBack(bosonPlotter.legendBulkOps(opName, getEffective(tbl.Data)));
    end

    function fillFromMeta(key)
        key = char(key);
        d = tbl.Data;
        for ii = 1:size(d, 1)
            mf = bosonPlotter.datasetMetaFields(datasets{ii});
            if isstruct(mf) && isfield(mf, key) && ~isempty(mf.(key))
                d{ii, 4} = char(mf.(key));
            end
        end
        tbl.Data = d;
        applySwatchStyles();
    end

    function resetAuto()
        d = tbl.Data;
        for ii = 1:size(d, 1), d{ii, 4} = ''; end
        tbl.Data = d;
        applySwatchStyles();
    end

    function keys = unionMetaKeys(dss)
        seen = {};
        for ii = 1:numel(dss)
            mf = bosonPlotter.datasetMetaFields(dss{ii});
            if isstruct(mf), seen = [seen, fieldnames(mf).']; end %#ok<AGROW>
        end
        keys = unique(seen, 'stable');
        if isempty(keys), keys = {'(no metadata)'}; end
    end
end

function out = matchOrDefault(choices, value, defaultVal)
%MATCHORDEFAULT  Return value if it is in choices, otherwise defaultVal.
    if ischar(value) || isstring(value)
        hit = find(strcmpi(choices, char(value)), 1);
        if ~isempty(hit)
            out = choices{hit};
            return;
        end
    end
    out = defaultVal;
end
