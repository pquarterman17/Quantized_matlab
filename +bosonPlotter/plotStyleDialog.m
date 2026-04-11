function plotStyleDialog(parentFig, ctx)
%PLOTSTYLEDIALOG  Modal Plot Style editor for BosonPlotter (Phase B).
%
%   bosonPlotter.plotStyleDialog(parentFig, ctx)
%
%   Opens a dialog that lets the user override individual visual
%   properties of the active plot template — font, line width, marker
%   size / shape, line style, tick direction, grid, legend, etc.
%   Changes are applied to one of three scopes:
%
%       • All datasets (writes to ctx.getStyleOverrides / ctx.setStyleOverrides)
%       • Active dataset only (writes to ds.styleOverride)
%       • Active channel only (writes to ds.channelStyles{channelIdx})
%
%   The dialog also exposes template Save As / Delete so the user can
%   build up a personal library that appears in the main Template
%   dropdown prefixed with "user:".
%
%   REQUIRED CTX FIELDS (passed in by BosonPlotter):
%       .fig                  — parent uifigure (for positioning / theme)
%       .getStyleOverrides    — @() appData.styleOverrides
%       .setStyleOverrides    — @(s) appData.styleOverrides = s
%       .getActiveTemplate    — @() appData.activeTemplate
%       .setActiveTemplate    — @(name) setTemplateDirect(name)
%       .getActiveDataset     — @() appData.datasets{activeIdx} or []
%       .setActiveDataset     — @(ds) write back to appData.datasets{activeIdx}
%       .getActiveChannelIdx  — @() 1-based index of first selected Y channel, or []
%       .getActiveChannelName — @() label string of the first selected Y channel
%       .replot               — @() onPlot([],[])
%       .refreshTemplateList  — @() repopulate ddTemplate.Items with user: entries
%       .theme                — 'Light' or 'Dark'
%
%   The dialog uses an explicit APPLY button (not auto-apply) so the
%   user can tweak several fields and commit together — avoids the
%   render-storm on every spinner nudge that auto-apply would cause.

    arguments
        parentFig  matlab.ui.Figure
        ctx        struct
    end

    figPos = parentFig.Position;
    dlgW = 380; dlgH = 660;
    dlgX = figPos(1) + round((figPos(3) - dlgW) / 2);
    dlgY = figPos(2) + round((figPos(4) - dlgH) / 2);

    % ── Pull current state to pre-populate the fields ─────────────────
    activeTemplateName = ctx.getActiveTemplate();
    overrides          = ctx.getStyleOverrides();

    % Resolve the effective "current" style the dialog should show.  We
    % start from the template and overlay global overrides so the user
    % sees the values currently in effect for "all datasets".
    try
        if startsWith(activeTemplateName, 'user:')
            tpl = bosonPlotter.userTemplates.load(activeTemplateName(6:end));
        else
            tpl = styles.template(activeTemplateName);
        end
    catch
        tpl = styles.template('screen');
    end
    effective = bosonPlotter.resolveStyle(tpl, overrides);

    % ── Build the dialog window ───────────────────────────────────────
    dlg = uifigure('Name', 'Plot Style', ...
        'Position', [dlgX dlgY dlgW dlgH], ...
        'Resize',   'off', ...
        'Tag',      'BosonPlotStyleDialog');

    isDark = strcmp(ctx.theme, 'Dark');
    if isDark
        th = styles.dark();
        dlg.Color = th.bgColor;
        lblFg     = th.fgColor;
    else
        dlg.Color = [0.94 0.94 0.94];
        lblFg     = [0 0 0];
    end

    % Single column of section panels + a button row at the bottom
    root = uigridlayout(dlg, [8 1], ...
        'RowHeight',  {28, 112, 96, 96, 96, 72, 60, 44}, ...
        'ColumnWidth', {'1x'}, ...
        'Padding',    [12 12 12 12], ...
        'RowSpacing', 6);

    % ── Row 1: Template row (dropdown + Save As + Delete) ─────────────
    tplRow = uigridlayout(root, [1 4], ...
        'RowHeight', {24}, ...
        'ColumnWidth', {60, '1x', 70, 60}, ...
        'Padding', [0 0 0 0], 'ColumnSpacing', 4);
    tplRow.Layout.Row = 1;

    uilabel(tplRow, 'Text', 'Template:', 'FontColor', lblFg);
    ddTpl = uidropdown(tplRow, 'Items', listAllTemplates(), ...
        'Value', activeTemplateName, ...
        'ValueChangedFcn', @onTemplateChanged);
    btnSaveAs = uibutton(tplRow, 'Text', 'Save as…', ...
        'Tooltip', 'Save current dialog values as a new user template', ...
        'ButtonPushedFcn', @onSaveAs); %#ok<NASGU>
    btnDelete = uibutton(tplRow, 'Text', 'Delete', ...
        'Tooltip', 'Delete the selected user template (built-ins cannot be deleted)', ...
        'ButtonPushedFcn', @onDelete); %#ok<NASGU>

    % ── Section 2: Typography ─────────────────────────────────────────
    pTypo = uipanel(root, 'Title', 'Typography', 'FontWeight', 'bold');
    pTypo.Layout.Row = 2;
    gTypo = uigridlayout(pTypo, [2 4], ...
        'RowHeight', {24, 24}, ...
        'ColumnWidth', {80, '1x', 80, '1x'}, ...
        'Padding', [8 8 8 8], 'RowSpacing', 4, 'ColumnSpacing', 6);

    uilabel(gTypo, 'Text', 'Font:', 'FontColor', lblFg);
    ddFontName = uidropdown(gTypo, ...
        'Items', {'Helvetica','Arial','Times New Roman','Courier New','Consolas'}, ...
        'Value', pickClosest({'Helvetica','Arial','Times New Roman','Courier New','Consolas'}, effective.fontName));

    uilabel(gTypo, 'Text', 'Axis pt:', 'FontColor', lblFg);
    spFontSize = uispinner(gTypo, 'Limits', [6 36], 'Step', 1, ...
        'Value', effective.fontSize);

    uilabel(gTypo, 'Text', 'Title pt:', 'FontColor', lblFg);
    spTitleSize = uispinner(gTypo, 'Limits', [6 40], 'Step', 1, ...
        'Value', effective.titleFontSize);

    uilabel(gTypo, 'Text', 'Legend pt:', 'FontColor', lblFg);
    spLegendSize = uispinner(gTypo, 'Limits', [6 32], 'Step', 1, ...
        'Value', effective.legendFontSize);

    % ── Section 3: Lines ──────────────────────────────────────────────
    pLines = uipanel(root, 'Title', 'Lines', 'FontWeight', 'bold');
    pLines.Layout.Row = 3;
    gLines = uigridlayout(pLines, [2 4], ...
        'RowHeight', {24, 24}, ...
        'ColumnWidth', {80, '1x', 80, '1x'}, ...
        'Padding', [8 8 8 8], 'RowSpacing', 4, 'ColumnSpacing', 6);

    uilabel(gLines, 'Text', 'Width:', 'FontColor', lblFg);
    spLineWidth = uispinner(gLines, 'Limits', [0.25 8], 'Step', 0.25, ...
        'Value', effective.lineWidth);

    uilabel(gLines, 'Text', 'Thin:', 'FontColor', lblFg, ...
        'Tooltip', 'Line width for secondary lines (theory overlays, whiskers)');
    spLineWidthThin = uispinner(gLines, 'Limits', [0.25 6], 'Step', 0.25, ...
        'Value', effective.lineWidthThin);

    uilabel(gLines, 'Text', 'Style:', 'FontColor', lblFg);
    ddLineStyle = uidropdown(gLines, ...
        'Items',     {'-','--',':','-.','auto'}, ...
        'ItemsData', {'-','--',':','-.','auto'}, ...
        'Value', effective.lineStyle);

    uilabel(gLines, 'Text', 'Alpha:', 'FontColor', lblFg, ...
        'Tooltip', 'Transparency 0..1 (1 = opaque)');
    spAlpha = uispinner(gLines, 'Limits', [0.05 1.0], 'Step', 0.05, ...
        'Value', effective.alpha);

    % ── Section 4: Markers ────────────────────────────────────────────
    pMark = uipanel(root, 'Title', 'Markers', 'FontWeight', 'bold');
    pMark.Layout.Row = 4;
    gMark = uigridlayout(pMark, [2 4], ...
        'RowHeight', {24, 24}, ...
        'ColumnWidth', {80, '1x', 80, '1x'}, ...
        'Padding', [8 8 8 8], 'RowSpacing', 4, 'ColumnSpacing', 6);

    uilabel(gMark, 'Text', 'Size:', 'FontColor', lblFg);
    spMarkerSize = uispinner(gMark, 'Limits', [1 20], 'Step', 0.5, ...
        'Value', effective.markerSize);

    uilabel(gMark, 'Text', 'Shape:', 'FontColor', lblFg);
    ddMarkerShape = uidropdown(gMark, ...
        'Items',     {'o (circle)','s (square)','^ (triangle)','d (diamond)', ...
                      'v (down tri)','x (cross)','+ (plus)','* (star)','auto (cycle)','none'}, ...
        'ItemsData', {'o','s','^','d','v','x','+','*','auto','none'}, ...
        'Value', matchOrDefault({'o','s','^','d','v','x','+','*','auto','none'}, effective.markerShape, 'o'));

    % Row-2 of markers section: leave blank for future (e.g. marker face color)
    uilabel(gMark, 'Text', '', 'FontColor', lblFg);
    uilabel(gMark, 'Text', '', 'FontColor', lblFg);
    uilabel(gMark, 'Text', '', 'FontColor', lblFg);
    uilabel(gMark, 'Text', '', 'FontColor', lblFg);

    % ── Section 5: Axes ───────────────────────────────────────────────
    pAx = uipanel(root, 'Title', 'Axes', 'FontWeight', 'bold');
    pAx.Layout.Row = 5;
    gAx = uigridlayout(pAx, [2 4], ...
        'RowHeight', {24, 24}, ...
        'ColumnWidth', {80, '1x', 80, '1x'}, ...
        'Padding', [8 8 8 8], 'RowSpacing', 4, 'ColumnSpacing', 6);

    uilabel(gAx, 'Text', 'Tick dir:', 'FontColor', lblFg);
    ddTickDir = uidropdown(gAx, ...
        'Items', {'in','out','both'}, ...
        'Value', effective.tickDir);

    uilabel(gAx, 'Text', 'Box:', 'FontColor', lblFg);
    cbBox = uicheckbox(gAx, 'Text', '', 'Value', logical(effective.boxOn));

    uilabel(gAx, 'Text', 'Grid α:', 'FontColor', lblFg, ...
        'Tooltip', 'Grid transparency 0..1 (0 = grid off)');
    spGridAlpha = uispinner(gAx, 'Limits', [0 1], 'Step', 0.05, ...
        'Value', effective.gridAlpha);

    uilabel(gAx, 'Text', 'Minor:', 'FontColor', lblFg, ...
        'Tooltip', 'Show minor ticks');
    cbMinorTicks = uicheckbox(gAx, 'Text', '', 'Value', logical(effective.minorTicks));

    % ── Section 6: Legend ─────────────────────────────────────────────
    pLeg = uipanel(root, 'Title', 'Legend', 'FontWeight', 'bold');
    pLeg.Layout.Row = 6;
    gLeg = uigridlayout(pLeg, [1 4], ...
        'RowHeight', {24}, ...
        'ColumnWidth', {80, '1x', 80, '1x'}, ...
        'Padding', [8 8 8 8], 'ColumnSpacing', 6);

    uilabel(gLeg, 'Text', 'Position:', 'FontColor', lblFg);
    ddLegLoc = uidropdown(gLeg, ...
        'Items', {'best','northeast','northwest','southeast','southwest', ...
                  'north','south','east','west', ...
                  'bestoutside','northeastoutside','eastoutside'}, ...
        'Value', matchOrDefault({'best','northeast','northwest','southeast','southwest', ...
            'north','south','east','west','bestoutside','northeastoutside','eastoutside'}, ...
            effective.legendLocation, 'best'));

    uilabel(gLeg, 'Text', 'Box:', 'FontColor', lblFg);
    cbLegBox = uicheckbox(gLeg, 'Text', '', 'Value', logical(effective.legendBox));

    % ── Section 7: Apply scope (uibuttongroup gives mutual exclusion) ─
    bgScope = uibuttongroup(root, 'Title', 'Apply to', 'FontWeight', 'bold');
    bgScope.Layout.Row = 7;
    gScope = uigridlayout(bgScope, [1 3], ...
        'RowHeight', {24}, ...
        'ColumnWidth', {'1x','1x','1x'}, ...
        'Padding', [8 12 8 8], 'ColumnSpacing', 4);
    rbAll = uiradiobutton(gScope, 'Text', 'Whole plot', 'Value', true, 'FontColor', lblFg); %#ok<NASGU>
    rbDs  = uiradiobutton(gScope, 'Text', 'Active dataset', 'FontColor', lblFg); %#ok<NASGU>
    rbCh  = uiradiobutton(gScope, 'Text', 'Active channel', 'FontColor', lblFg); %#ok<NASGU>

    % ── Row 8: Bottom buttons (Reset / Apply / Close) ─────────────────
    btnRow = uigridlayout(root, [1 4], ...
        'RowHeight', {30}, ...
        'ColumnWidth', {'1x', 80, 80, 80}, ...
        'Padding', [0 0 0 0], 'ColumnSpacing', 6);
    btnRow.Layout.Row = 8;

    uilabel(btnRow, 'Text', '');   % spacer to right-align buttons
    btnReset = uibutton(btnRow, 'Text', 'Reset', ...
        'Tooltip', 'Clear all overrides and revert to the template defaults', ...
        'ButtonPushedFcn', @onReset); %#ok<NASGU>
    btnApply = uibutton(btnRow, 'Text', 'Apply', ...
        'BackgroundColor', [0.20 0.50 0.35], ...
        'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @onApply); %#ok<NASGU>
    btnClose = uibutton(btnRow, 'Text', 'Close', ...
        'ButtonPushedFcn', @(~,~) delete(dlg)); %#ok<NASGU>


    % ════════════════════════════════════════════════════════════════
    %  Callbacks
    % ════════════════════════════════════════════════════════════════

    function items = listAllTemplates()
        items = {'screen','aps','aps_double','nature','nature_double', ...
                 'thesis','presentation','poster'};
        try
            userList = bosonPlotter.userTemplates.list();
            for k = 1:numel(userList)
                items{end+1} = ['user:' userList{k}]; %#ok<AGROW>
            end
        catch
        end
    end

    function onTemplateChanged(src, ~)
        % Apply the new base template and re-pull defaults into the dialog
        ctx.setActiveTemplate(src.Value);
        % Refresh dialog values to reflect the new template's defaults
        try
            if startsWith(src.Value, 'user:')
                newTpl = bosonPlotter.userTemplates.load(src.Value(6:end));
            else
                newTpl = styles.template(src.Value);
            end
            newEff = bosonPlotter.resolveStyle(newTpl, ctx.getStyleOverrides());
            ddFontName.Value    = pickClosest(ddFontName.Items, newEff.fontName);
            spFontSize.Value    = newEff.fontSize;
            spTitleSize.Value   = newEff.titleFontSize;
            spLegendSize.Value  = newEff.legendFontSize;
            spLineWidth.Value   = newEff.lineWidth;
            spLineWidthThin.Value = newEff.lineWidthThin;
            ddLineStyle.Value   = newEff.lineStyle;
            spAlpha.Value       = newEff.alpha;
            spMarkerSize.Value  = newEff.markerSize;
            ddMarkerShape.Value = matchOrDefault(ddMarkerShape.ItemsData, newEff.markerShape, 'o');
            ddTickDir.Value     = newEff.tickDir;
            cbBox.Value         = logical(newEff.boxOn);
            spGridAlpha.Value   = newEff.gridAlpha;
            cbMinorTicks.Value  = logical(newEff.minorTicks);
            ddLegLoc.Value      = matchOrDefault(ddLegLoc.Items, newEff.legendLocation, 'best');
            cbLegBox.Value      = logical(newEff.legendBox);
        catch
        end
    end

    function s = collectDialogStyle()
    %COLLECTDIALOGSTYLE  Gather the current dialog values into a sparse
    %   override struct.  "Sparse" here means: every field the dialog
    %   shows gets written (the user saw the value, so consider it
    %   explicitly set).  Reset is the only way to empty an override.
        s = struct();
        s.fontName       = ddFontName.Value;
        s.fontSize       = spFontSize.Value;
        s.titleFontSize  = spTitleSize.Value;
        s.legendFontSize = spLegendSize.Value;
        s.lineWidth      = spLineWidth.Value;
        s.lineWidthThin  = spLineWidthThin.Value;
        s.lineStyle      = ddLineStyle.Value;
        s.alpha          = spAlpha.Value;
        s.markerSize     = spMarkerSize.Value;
        s.markerShape    = ddMarkerShape.Value;
        s.tickDir        = ddTickDir.Value;
        s.boxOn          = cbBox.Value;
        s.gridAlpha      = spGridAlpha.Value;
        s.minorTicks     = cbMinorTicks.Value;
        s.legendLocation = ddLegLoc.Value;
        s.legendBox      = cbLegBox.Value;
    end

    function onApply(~, ~)
        newStyle = collectDialogStyle();

        scope = bgScope.SelectedObject.Text;
        switch scope
            case 'Whole plot'
                ctx.setStyleOverrides(newStyle);
            case 'Active dataset'
                ds = ctx.getActiveDataset();
                if isempty(ds)
                    uialert(dlg, 'No active dataset — load a file first.', 'Apply');
                    return;
                end
                ds.styleOverride = newStyle;
                ctx.setActiveDataset(ds);
            case 'Active channel'
                ds = ctx.getActiveDataset();
                chIdx = ctx.getActiveChannelIdx();
                if isempty(ds)
                    uialert(dlg, 'No active dataset — load a file first.', 'Apply');
                    return;
                end
                if isempty(chIdx) || chIdx < 1
                    uialert(dlg, 'No Y channel is selected — pick one in the main GUI first.', 'Apply');
                    return;
                end
                if ~isfield(ds, 'channelStyles') || isempty(ds.channelStyles)
                    ds.channelStyles = cell(1, max(1, size(ds.data.values, 2)));
                end
                if chIdx > numel(ds.channelStyles)
                    ds.channelStyles{chIdx} = struct();
                end
                ds.channelStyles{chIdx} = newStyle;
                ctx.setActiveDataset(ds);
        end

        ctx.replot();
    end

    function onReset(~, ~)
        % Clear all overrides at every scope, then re-populate the dialog
        % with the raw template values.
        ctx.setStyleOverrides(struct());
        ds = ctx.getActiveDataset();
        if ~isempty(ds)
            if isfield(ds, 'styleOverride'), ds.styleOverride = struct(); end
            if isfield(ds, 'channelStyles'), ds.channelStyles = {};       end
            ctx.setActiveDataset(ds);
        end

        try
            if startsWith(ddTpl.Value, 'user:')
                tpl0 = bosonPlotter.userTemplates.load(ddTpl.Value(6:end));
            else
                tpl0 = styles.template(ddTpl.Value);
            end
            eff0 = bosonPlotter.resolveStyle(tpl0);
            ddFontName.Value    = pickClosest(ddFontName.Items, eff0.fontName);
            spFontSize.Value    = eff0.fontSize;
            spTitleSize.Value   = eff0.titleFontSize;
            spLegendSize.Value  = eff0.legendFontSize;
            spLineWidth.Value   = eff0.lineWidth;
            spLineWidthThin.Value = eff0.lineWidthThin;
            ddLineStyle.Value   = eff0.lineStyle;
            spAlpha.Value       = eff0.alpha;
            spMarkerSize.Value  = eff0.markerSize;
            ddMarkerShape.Value = matchOrDefault(ddMarkerShape.ItemsData, eff0.markerShape, 'o');
            ddTickDir.Value     = eff0.tickDir;
            cbBox.Value         = logical(eff0.boxOn);
            spGridAlpha.Value   = eff0.gridAlpha;
            cbMinorTicks.Value  = logical(eff0.minorTicks);
            ddLegLoc.Value      = matchOrDefault(ddLegLoc.Items, eff0.legendLocation, 'best');
            cbLegBox.Value      = logical(eff0.legendBox);
        catch
        end

        ctx.replot();
    end

    function onSaveAs(~, ~)
        prompt = inputdlg('Template name:', 'Save user template', [1 40], {''});
        if isempty(prompt), return; end
        name = strtrim(prompt{1});
        if isempty(name)
            uialert(dlg, 'Template name cannot be empty.', 'Save as');
            return;
        end

        % Start from the currently selected template, then overlay the
        % dialog values.  This ensures user templates always carry every
        % required field even if the dialog only shows a subset.
        try
            if startsWith(ddTpl.Value, 'user:')
                base = bosonPlotter.userTemplates.load(ddTpl.Value(6:end));
            else
                base = styles.template(ddTpl.Value);
            end
        catch
            base = styles.template('screen');
        end

        merged = base;
        dialogStyle = collectDialogStyle();
        fn = fieldnames(dialogStyle);
        for k = 1:numel(fn)
            merged.(fn{k}) = dialogStyle.(fn{k});
        end

        try
            bosonPlotter.userTemplates.save(name, merged);
        catch ME
            uialert(dlg, sprintf('Could not save template:\n%s', ME.message), 'Save as');
            return;
        end

        % Refresh template dropdown and the main GUI dropdown
        ddTpl.Items = listAllTemplates();
        newKey = bosonPlotter.userTemplates.sanitise(name);
        userVal = ['user:' newKey];
        if any(strcmp(ddTpl.Items, userVal))
            ddTpl.Value = userVal;
        end
        try ctx.refreshTemplateList(); catch, end
        try ctx.setActiveTemplate(userVal); catch, end
        uialert(dlg, sprintf('Saved template "%s"', name), 'Saved');
    end

    function onDelete(~, ~)
        name = ddTpl.Value;
        if ~startsWith(name, 'user:')
            uialert(dlg, 'Built-in templates cannot be deleted.', 'Delete');
            return;
        end
        userName = name(6:end);
        confirmMsg = sprintf('Delete user template "%s"?  This cannot be undone.', userName);
        sel = uiconfirm(dlg, confirmMsg, 'Delete template', ...
            'Options', {'Delete','Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
        if ~strcmp(sel, 'Delete'), return; end

        try
            bosonPlotter.userTemplates.delete(userName);
        catch ME
            uialert(dlg, sprintf('Delete failed:\n%s', ME.message), 'Delete');
            return;
        end

        ddTpl.Items = listAllTemplates();
        ddTpl.Value = 'screen';
        try ctx.refreshTemplateList(); catch, end
        try ctx.setActiveTemplate('screen'); catch, end
    end
end


% ════════════════════════════════════════════════════════════════════════
%  File-scope helpers (no access to outer workspace)
% ════════════════════════════════════════════════════════════════════════

function v = pickClosest(candidates, target)
%PICKCLOSEST  Return the first candidate whose canonical form matches
%   target (case-insensitive), or the first candidate as fallback.
    for i = 1:numel(candidates)
        if strcmpi(candidates{i}, target)
            v = candidates{i};
            return;
        end
    end
    v = candidates{1};
end

function v = matchOrDefault(candidates, target, fallback)
%MATCHORDEFAULT  If target is in candidates, return it; else return fallback.
    if any(strcmp(candidates, target))
        v = target;
    else
        v = fallback;
    end
end
