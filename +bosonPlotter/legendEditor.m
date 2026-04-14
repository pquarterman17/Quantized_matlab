function legendEditor(parentFig, ctx)
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
        uialert(parentFig, 'Load at least one dataset first.', 'No data');
        return;
    end

    % Resolve current effective style for legend field defaults
    tpl       = styles.template(ctx.getActiveTemplate());
    effective = bosonPlotter.resolveStyle(tpl, ctx.getStyleOverrides());

    % ── Build dialog ──────────────────────────────────────────────
    dlgW = 520;
    dlgH = 460;
    figPos = parentFig.Position;
    dlgX = figPos(1) + max(50, (figPos(3) - dlgW)/2);
    dlgY = figPos(2) + max(50, (figPos(4) - dlgH)/2);

    dlg = uifigure('Name', 'Edit Legend', 'Position', [dlgX dlgY dlgW dlgH], ...
        'Resize', 'on', 'WindowStyle', 'modal');

    root = uigridlayout(dlg, [4 1], ...
        'Padding',    [12 12 12 8], ...
        'RowSpacing', 8, ...
        'RowHeight',  {26, '1x', 'fit', 36});

    % Row 1: header
    uilabel(root, ...
        'Text',       'Legend — per-dataset names, visibility, and shared style', ...
        'FontWeight', 'bold', ...
        'FontSize',   12);

    % Row 2: per-dataset table
    N = numel(datasets);
    tblData = cell(N, 3);
    for i = 1:N
        dsi = datasets{i};
        % "Visible" — ds.visible (defaults to true if missing)
        vis = true;
        if isfield(dsi, 'visible'), vis = logical(dsi.visible); end
        % "Dataset" — legendName if set, else displayName, else filename
        baseName = '';
        if isfield(dsi, 'displayName') && ~isempty(dsi.displayName)
            baseName = dsi.displayName;
        elseif isfield(dsi, 'filepath')
            [~, fn, fext] = fileparts(dsi.filepath);
            baseName = [fn fext];
        end
        legName = '';
        if isfield(dsi, 'legendName'), legName = dsi.legendName; end
        tblData{i, 1} = vis;
        tblData{i, 2} = baseName;       % read-only source name
        tblData{i, 3} = legName;        % editable legend override
    end
    tbl = uitable(root, ...
        'Data',              tblData, ...
        'ColumnName',        {'Show', 'Source', 'Legend name'}, ...
        'ColumnEditable',    [true, false, true], ...
        'ColumnFormat',      {'logical', 'char', 'char'}, ...
        'ColumnWidth',       {'1x', '3x', '5x'}, ...
        'RowName',           'numbered', ...
        'SelectionType',     'row');

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
            dsK.visible     = logical(tblNow{k, 1});
            dsK.legendName  = char(tblNow{k, 3});
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
