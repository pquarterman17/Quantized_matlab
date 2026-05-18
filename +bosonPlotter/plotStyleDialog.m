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
    dlgW = 400;
    % ── Dynamic height: fit within the current screen so the Apply
    %    button stays reachable on laptops (1366×768 etc.).  Reserve
    %    ~120 px for title bar + taskbar + top/bottom margin.  If the
    %    screen is tall enough the dialog uses its natural 780 px; on
    %    short screens it shrinks and the root uigridlayout becomes
    %    scrollable (see Scrollable='on' below).
    try
        screenSize = get(0, 'ScreenSize');
        maxDlgH    = max(400, screenSize(4) - 120);
    catch
        maxDlgH = 780;
    end
    dlgH = min(780, maxDlgH);
    dlgX = figPos(1) + round((figPos(3) - dlgW) / 2);
    dlgY = figPos(2) + round((figPos(4) - dlgH) / 2);
    if dlgY < 20, dlgY = 20; end   % keep title bar on-screen

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
    % Resize='on' lets users grow the window on tall screens; the
    % root uigridlayout below is Scrollable='on' so small screens
    % get a scrollbar instead of an unreachable Apply button.
    dlg = uifigure('Name', 'Plot Style', ...
        'Position', [dlgX dlgY dlgW dlgH], ...
        'Resize',   'on', ...
        'Tag',      'BosonPlotStyleDialog');

    % ── Theme: assemble a full colour set so every widget can be
    %    coloured without ternary sprinkling.  Dark mode pulls from
    %    styles.dark(); light mode uses the system defaults that
    %    MATLAB's uifigure widgets ship with.  Every helper below
    %    references theme.* without caring which mode is active.
    isDark = strcmp(ctx.theme, 'Dark');
    if isDark
        darkTh = styles.dark();
        theme.bgColor       = darkTh.bgColor;
        theme.fgColor       = darkTh.fgColor;
        theme.panelBgColor  = darkTh.panelBgColor;
        theme.panelFgColor  = darkTh.fgColor;
        theme.editBgColor   = darkTh.editBgColor;
        theme.editFgColor   = darkTh.editFgColor;
        theme.buttonBgColor = darkTh.buttonBgColor;
        theme.buttonFgColor = darkTh.buttonFgColor;
    else
        theme.bgColor       = [0.94 0.94 0.94];
        theme.fgColor       = [0    0    0   ];
        theme.panelBgColor  = [0.94 0.94 0.94];
        theme.panelFgColor  = [0    0    0   ];
        theme.editBgColor   = [1    1    1   ];
        theme.editFgColor   = [0    0    0   ];
        theme.buttonBgColor = [0.94 0.94 0.94];
        theme.buttonFgColor = [0    0    0   ];
    end
    dlg.Color = theme.bgColor;
    lblFg     = theme.fgColor;   % kept for backward-compat with existing label refs

    % Single column of section panels + a button row at the bottom.
    % Rows:
    %   1  Template selector             28 px
    %   2  Typography                    112 px (2 rows × 4 cols)
    %   3  Lines                          96 px (2 rows × 4 cols)
    %   4  Markers                       120 px (3 rows × 4 cols — row 3 = face mode)
    %   5  Axes                          120 px (3 rows × 4 cols — row 3 = tick length)
    %   6  Palette                        56 px (1 row × 2 cols)
    %   7  Legend                         96 px (2 rows × 4 cols — row 2 = font weight)
    %   8  Apply-to radio group           60 px
    %   9  Button row                     44 px
    root = uigridlayout(dlg, [9 1], ...
        'RowHeight',  {28, 112, 96, 96, 120, 56, 96, 60, 44}, ...
        'ColumnWidth', {'1x'}, ...
        'Padding',    [12 12 12 12], ...
        'RowSpacing', 6, ...
        'Scrollable', 'on');

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

    % Row 2: marker face mode
    uilabel(gMark, 'Text', 'Face:', 'FontColor', lblFg, ...
        'Tooltip', 'none = outline only, filled = match line colour');
    ddMarkerFace = uidropdown(gMark, ...
        'Items',     {'outline','filled'}, ...
        'ItemsData', {'none','auto'}, ...
        'Value', matchOrDefault({'none','auto'}, effective.markerFaceMode, 'none'));

    % Keep the marker grid 2 rows × 4 cols — placeholder labels for the
    % empty cells on row 2 (future: explicit marker face colour picker).
    uilabel(gMark, 'Text', '', 'FontColor', lblFg);
    uilabel(gMark, 'Text', '', 'FontColor', lblFg);

    % ── Section 5: Axes ───────────────────────────────────────────────
    pAx = uipanel(root, 'Title', 'Axes', 'FontWeight', 'bold');
    pAx.Layout.Row = 5;
    gAx = uigridlayout(pAx, [3 4], ...
        'RowHeight', {24, 24, 24}, ...
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

    % Row 3: tick length.  MATLAB axes store [major minor] as a fraction
    % of the long axis; we expose just the major value and keep the
    % minor tick at half the major (the APS/Nature convention).
    uilabel(gAx, 'Text', 'Tick len:', 'FontColor', lblFg, ...
        'Tooltip', 'Major tick length (fraction of long axis, 0.005–0.05 typical)');
    majorInit = 0.01;
    if isnumeric(effective.tickLength) && ~isempty(effective.tickLength)
        majorInit = effective.tickLength(1);
    end
    spTickLenMajor = uispinner(gAx, 'Limits', [0 0.1], 'Step', 0.005, ...
        'ValueDisplayFormat', '%.3f', 'Value', majorInit);

    uilabel(gAx, 'Text', '', 'FontColor', lblFg);
    uilabel(gAx, 'Text', '', 'FontColor', lblFg);

    % ── Section 6: Palette ────────────────────────────────────────────
    % Lets the user swap the colour cycle without switching templates.
    % 'Template default' means "don't override" — leaves appearance.colors
    % empty so renderPlot falls through to the main GUI colormap dropdown.
    pPal = uipanel(root, 'Title', 'Palette', 'FontWeight', 'bold');
    pPal.Layout.Row = 6;
    gPal = uigridlayout(pPal, [1 2], ...
        'RowHeight', {24}, ...
        'ColumnWidth', {80, '1x'}, ...
        'Padding', [8 8 8 8], 'ColumnSpacing', 6);

    uilabel(gPal, 'Text', 'Colours:', 'FontColor', lblFg, ...
        'Tooltip', 'Override the dataset colour cycle (takes precedence over the main colormap dropdown)');
    paletteItems     = {'Template default','Tab10','Viridis','Plasma', ...
                        'Tol bright (CB)','Tol muted (CB)','Okabe-Ito (CB)', ...
                        'APS-like','Nature-like','Grayscale'};
    % NOTE: 'template_default' sentinel — the literal 'default' is a
    % reserved MATLAB set() keyword that resets a property to its
    % factory default, which makes uidropdown reject Value='default'
    % even when 'default' is in ItemsData.  Renamed to dodge the
    % collision; styles.palette accepts both as synonyms.
    paletteItemsData = {'template_default','tab10','viridis','plasma', ...
                        'tol_bright','tol_muted','okabe_ito', ...
                        'aps','nature','grayscale'};
    ddPalette = uidropdown(gPal, ...
        'Items',     paletteItems, ...
        'ItemsData', paletteItemsData, ...
        'Value', detectCurrentPalette(effective, paletteItemsData));

    % ── Section 7: Legend ─────────────────────────────────────────────
    pLeg = uipanel(root, 'Title', 'Legend', 'FontWeight', 'bold');
    pLeg.Layout.Row = 7;
    gLeg = uigridlayout(pLeg, [2 4], ...
        'RowHeight', {24, 24}, ...
        'ColumnWidth', {80, '1x', 80, '1x'}, ...
        'Padding', [8 8 8 8], 'RowSpacing', 4, 'ColumnSpacing', 6);

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

    % Row 2: legend font weight
    uilabel(gLeg, 'Text', 'Weight:', 'FontColor', lblFg, ...
        'Tooltip', 'Legend text weight');
    ddLegWeight = uidropdown(gLeg, ...
        'Items',     {'normal','bold'}, ...
        'Value', matchOrDefault({'normal','bold'}, effective.legendFontWeight, 'normal'));

    % Keep the legend grid symmetric (2×4) — spacers for the empty cells.
    uilabel(gLeg, 'Text', '', 'FontColor', lblFg);
    uilabel(gLeg, 'Text', '', 'FontColor', lblFg);

    % ── Section 8: Apply scope (uibuttongroup gives mutual exclusion) ─
    % IMPORTANT: uiradiobutton's parent validator REJECTS a nested
    % uigridlayout — it must be the uibuttongroup directly.  We used
    % to wrap gScope around the three buttons and it happened to work
    % in some R202x builds but crashes in R2025b with
    %   "'Parent' value must be specified as a ButtonGroup object."
    % So the buttons are now direct children with absolute Position.
    % The dialog is Resize='off' so fixed pixel layout is fine.
    bgScope = uibuttongroup(root, 'Title', 'Apply to', 'FontWeight', 'bold');
    bgScope.Layout.Row = 8;
    rbAll = uiradiobutton(bgScope, 'Text', 'Whole plot',     'Value', true, ...
                          'Position', [ 10 8 110 22]); %#ok<NASGU>
    rbDs  = uiradiobutton(bgScope, 'Text', 'Active dataset', ...
                          'Position', [130 8 130 22]); %#ok<NASGU>
    rbCh  = uiradiobutton(bgScope, 'Text', 'Active channel', ...
                          'Position', [270 8 130 22]); %#ok<NASGU>

    % ── Row 9: Bottom buttons (Reset / Apply / Close) ─────────────────
    btnRow = uigridlayout(root, [1 4], ...
        'RowHeight', {30}, ...
        'ColumnWidth', {'1x', 80, 80, 80}, ...
        'Padding', [0 0 0 0], 'ColumnSpacing', 6);
    btnRow.Layout.Row = 9;

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

    % ── Apply theme to every widget in one pass ─────────────────────
    % Walks the whole tree so we don't have to sprinkle colour args
    % through every creation call.  The Apply button keeps its custom
    % green background — the helper skips widgets tagged 'primary'.
    try
        btnApply.Tag = 'primary';   % exempt from theme walk
        applyThemeRecursive(dlg, theme);
    catch
    end


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
            pushEffectiveToDialog(newEff);
        catch
        end
    end

    function pushEffectiveToDialog(eff)
    %PUSHEFFECTIVETODIALOG  Apply a resolved appearance struct to every
    %   widget in the dialog.  Used by onTemplateChanged and onReset so
    %   the two code paths can't drift apart — every new control added
    %   to the dialog needs to be handled in exactly one place.
        ddFontName.Value      = pickClosest(ddFontName.Items, eff.fontName);
        spFontSize.Value      = eff.fontSize;
        spTitleSize.Value     = eff.titleFontSize;
        spLegendSize.Value    = eff.legendFontSize;
        spLineWidth.Value     = eff.lineWidth;
        spLineWidthThin.Value = eff.lineWidthThin;
        ddLineStyle.Value     = eff.lineStyle;
        spAlpha.Value         = eff.alpha;
        spMarkerSize.Value    = eff.markerSize;
        ddMarkerShape.Value   = matchOrDefault(ddMarkerShape.ItemsData, eff.markerShape, 'o');
        ddMarkerFace.Value    = matchOrDefault(ddMarkerFace.ItemsData, eff.markerFaceMode, 'none');
        ddTickDir.Value       = eff.tickDir;
        cbBox.Value           = logical(eff.boxOn);
        spGridAlpha.Value     = eff.gridAlpha;
        cbMinorTicks.Value    = logical(eff.minorTicks);
        if isnumeric(eff.tickLength) && ~isempty(eff.tickLength)
            spTickLenMajor.Value = eff.tickLength(1);
        end
        ddPalette.Value       = detectCurrentPalette(eff, ddPalette.ItemsData);
        ddLegLoc.Value        = matchOrDefault(ddLegLoc.Items, eff.legendLocation, 'best');
        cbLegBox.Value        = logical(eff.legendBox);
        ddLegWeight.Value     = matchOrDefault(ddLegWeight.Items, eff.legendFontWeight, 'normal');
    end

    function s = collectDialogStyle()
    %COLLECTDIALOGSTYLE  Gather the current dialog values into a sparse
    %   override struct.  "Sparse" here means: every field the dialog
    %   shows gets written (the user saw the value, so consider it
    %   explicitly set).  Reset is the only way to empty an override.
        s = struct();
        s.fontName         = ddFontName.Value;
        s.fontSize         = spFontSize.Value;
        s.titleFontSize    = spTitleSize.Value;
        s.legendFontSize   = spLegendSize.Value;
        s.lineWidth        = spLineWidth.Value;
        s.lineWidthThin    = spLineWidthThin.Value;
        s.lineStyle        = ddLineStyle.Value;
        s.alpha            = spAlpha.Value;
        s.markerSize       = spMarkerSize.Value;
        s.markerShape      = ddMarkerShape.Value;
        s.markerFaceMode   = ddMarkerFace.Value;
        s.tickDir          = ddTickDir.Value;
        s.boxOn            = cbBox.Value;
        s.gridAlpha        = spGridAlpha.Value;
        s.minorTicks       = cbMinorTicks.Value;
        % tickLength: expose the major value, keep minor at half the
        % major (MATLAB convention for publication plots).
        majorLen = spTickLenMajor.Value;
        s.tickLength       = [majorLen, majorLen/2];
        s.legendLocation   = ddLegLoc.Value;
        s.legendBox        = cbLegBox.Value;
        s.legendFontWeight = ddLegWeight.Value;

        % Palette: 'template_default' (or empty) means "no override".
        % We write to .paletteOverride (not .colors) so the template's
        % own colour cycle stays untouched — renderPlot checks
        % paletteOverride first and falls back to the main colormap
        % dropdown when empty, preserving pre-Phase-G behaviour.
        palKey = ddPalette.Value;
        if ~strcmpi(palKey, 'template_default') && ~strcmpi(palKey, 'default') && ~isempty(palKey)
            try
                s.paletteOverride = styles.palette(palKey);
            catch
                % Unknown palette name — leave override unset
            end
        end
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
                    bosonPlotter.quietAlert(dlg, 'No active dataset — load a file first.', 'Apply');
                    return;
                end
                ds.styleOverride = newStyle;
                ctx.setActiveDataset(ds);
            case 'Active channel'
                ds = ctx.getActiveDataset();
                chIdx = ctx.getActiveChannelIdx();
                if isempty(ds)
                    bosonPlotter.quietAlert(dlg, 'No active dataset — load a file first.', 'Apply');
                    return;
                end
                if isempty(chIdx) || chIdx < 1
                    bosonPlotter.quietAlert(dlg, 'No Y channel is selected — pick one in the main GUI first.', 'Apply');
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
            pushEffectiveToDialog(eff0);
        catch
        end

        ctx.replot();
    end

    function onSaveAs(~, ~)
        prompt = inputdlg('Template name:', 'Save user template', [1 40], {''});
        if isempty(prompt), return; end
        name = strtrim(prompt{1});
        if isempty(name)
            bosonPlotter.quietAlert(dlg, 'Template name cannot be empty.', 'Save as');
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
            bosonPlotter.quietAlert(dlg, sprintf('Could not save template:\n%s', ME.message), 'Save as');
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
        bosonPlotter.quietAlert(dlg, sprintf('Saved template "%s"', name), 'Saved');
    end

    function onDelete(~, ~)
        name = ddTpl.Value;
        if ~startsWith(name, 'user:')
            bosonPlotter.quietAlert(dlg, 'Built-in templates cannot be deleted.', 'Delete');
            return;
        end
        userName = name(6:end);
        confirmMsg = sprintf('Delete user template "%s"?  This cannot be undone.', userName);
        sel = bosonPlotter.quietConfirm(dlg, confirmMsg, 'Delete template', ...
            'Options', {'Delete','Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
        if ~strcmp(sel, 'Delete'), return; end

        try
            bosonPlotter.userTemplates.delete(userName);
        catch ME
            bosonPlotter.quietAlert(dlg, sprintf('Delete failed:\n%s', ME.message), 'Delete');
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

function applyThemeRecursive(node, theme)
%APPLYTHEMERECURSIVE  Walk a uifigure subtree and colour each widget.
%
%   Handles the widget classes used by plotStyleDialog:
%       uifigure, uigridlayout, uipanel, uibuttongroup,
%       uilabel, uidropdown, uispinner, uicheckbox, uiradiobutton,
%       uibutton
%
%   Widgets tagged 'primary' (the green Apply button) are exempt so
%   they keep their custom colours.  Unknown types are walked-through
%   for children but not recoloured.
    if ~isvalid(node), return; end

    % Skip exempt widgets (their Children are still walked below)
    tag = '';
    try tag = char(get(node, 'Tag')); catch, end
    exempt = strcmp(tag, 'primary');

    if ~exempt
        cls = class(node);
        switch cls
            case 'matlab.ui.Figure'
                try node.Color = theme.bgColor; catch, end

            case {'matlab.ui.container.GridLayout'}
                try node.BackgroundColor = theme.bgColor; catch, end

            case 'matlab.ui.container.Panel'
                try node.BackgroundColor     = theme.panelBgColor; catch, end
                try node.ForegroundColor     = theme.panelFgColor; catch, end

            case 'matlab.ui.container.ButtonGroup'
                try node.BackgroundColor = theme.panelBgColor; catch, end
                try node.ForegroundColor = theme.panelFgColor; catch, end

            case 'matlab.ui.control.Label'
                try node.FontColor = theme.fgColor; catch, end

            case 'matlab.ui.control.DropDown'
                try node.BackgroundColor = theme.editBgColor; catch, end
                try node.FontColor       = theme.editFgColor; catch, end

            case 'matlab.ui.control.Spinner'
                try node.BackgroundColor = theme.editBgColor; catch, end
                try node.FontColor       = theme.editFgColor; catch, end

            case 'matlab.ui.control.EditField'
                try node.BackgroundColor = theme.editBgColor; catch, end
                try node.FontColor       = theme.editFgColor; catch, end

            case 'matlab.ui.control.CheckBox'
                try node.FontColor = theme.fgColor; catch, end

            case 'matlab.ui.control.RadioButton'
                try node.FontColor = theme.fgColor; catch, end

            case 'matlab.ui.control.Button'
                try node.BackgroundColor = theme.buttonBgColor; catch, end
                try node.FontColor       = theme.buttonFgColor; catch, end
        end
    end

    % Recurse into children
    try
        kids = node.Children;
    catch
        return;
    end
    for k = 1:numel(kids)
        applyThemeRecursive(kids(k), theme);
    end
end

function v = matchOrDefault(candidates, target, fallback)
%MATCHORDEFAULT  If target is in candidates, return it; else return fallback.
    if any(strcmp(candidates, target))
        v = target;
    else
        v = fallback;
    end
end

function key = detectCurrentPalette(eff, candidates)
%DETECTCURRENTPALETTE  Guess which palette key matches eff.paletteOverride.
%   Returns the 'template_default' sentinel if the effective
%   appearance has no palette override, otherwise walks the known
%   palettes and returns the first whose RGB matrix matches within a
%   small tolerance.  This lets the dialog round-trip a saved
%   session's palette selection without storing the key explicitly.
    % Find the sentinel key dynamically so this helper stays in sync
    % with whatever the dialog's ItemsData uses.
    key = 'template_default';
    if ~any(strcmp(candidates, key)) && any(strcmp(candidates, 'default'))
        key = 'default';   % older callers may still use 'default'
    end
    if ~isfield(eff, 'paletteOverride') || isempty(eff.paletteOverride) || ...
       ~isnumeric(eff.paletteOverride)
        return;
    end
    tol = 1e-3;
    src = double(eff.paletteOverride);
    for i = 1:numel(candidates)
        c = candidates{i};
        if strcmpi(c, 'template_default') || strcmpi(c, 'default'), continue; end
        try
            ref = styles.palette(c);
        catch
            continue;
        end
        if isempty(ref), continue; end
        if size(ref, 1) == size(src, 1) && size(ref, 2) == size(src, 2) ...
           && all(abs(ref(:) - src(:)) < tol)
            key = c;
            return;
        end
    end
end
