function openSettings(appData, fig, callbacks)
%OPENSETTINGS  Open the global settings dialog for theme + plot style.
%
% Syntax
%   bosonPlotter.openSettings(appData, fig, callbacks)
%
% Builds a small modal-like uifigure with theme selector, plot-style
% selector, a Customise Toolbar button, and a Close button.  Honours the
% caller's current theme (light / dark) so the dialog matches.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads .theme, .style)
%   fig       - Main BosonPlotter figure handle (used to centre the dialog)
%   callbacks - Struct of function handles:
%                 .applyThemeFromDialog(themeName, settingsFig)
%                 .onStylePick(styleKey)
%                 .onCustomiseToolbar()

    % Position dialog near the main figure
    figPos = fig.Position;
    dlgW = 280; dlgH = 220;
    dlgX = figPos(1) + round((figPos(3) - dlgW) / 2);
    dlgY = figPos(2) + round((figPos(4) - dlgH) / 2);

    settingsFig = uifigure('Name','Settings', ...
        'Position',[dlgX dlgY dlgW dlgH], ...
        'Resize','off');

    % Match current theme colours from the theme struct
    isDark = strcmp(appData.theme, 'Dark');
    if isDark
        th = styles.dark();
        settingsFig.Color = th.bgColor;
        lblFg = th.fgColor;
    else
        settingsFig.Color = [0.94 0.94 0.94];
        lblFg = [0 0 0];
    end

    sGL = uigridlayout(settingsFig,[6 2], ...
        'RowHeight', {24, 28, 14, 28, 28, '1x'}, ...
        'ColumnWidth', {90, '1x'}, ...
        'Padding', [16 16 16 16], ...
        'RowSpacing', 8);

    % ── Theme selector ──
    lblTh = uilabel(sGL,'Text','Theme:','FontSize',12,'FontColor',lblFg);
    lblTh.Layout.Row = 1; lblTh.Layout.Column = 1;

    ddThemeDlg = uidropdown(sGL, ...
        'Items', {'Light','Dark'}, ...
        'Value', appData.theme, ...
        'FontSize', 12, ...
        'ValueChangedFcn', @(src,~) callbacks.applyThemeFromDialog(src.Value, settingsFig));
    ddThemeDlg.Layout.Row = 1; ddThemeDlg.Layout.Column = 2;

    % ── Plot Style selector ──
    lblSt = uilabel(sGL,'Text','Plot Style:','FontSize',12,'FontColor',lblFg);
    lblSt.Layout.Row = 2; lblSt.Layout.Column = 1;

    STYLE_NAMES = {'Line', 'Scatter', 'Line + Markers', 'Error Band'};
    STYLE_KEYS  = {'Line', 'Scatter', 'Line+Pts',       'ErrorBand'};
    currentIdx = find(strcmp(STYLE_KEYS, appData.style), 1);
    if isempty(currentIdx), currentIdx = 1; end

    ddStyleDlg = uidropdown(sGL, ...
        'Items', STYLE_NAMES, ...
        'ItemsData', STYLE_KEYS, ...
        'Value', STYLE_KEYS{currentIdx}, ...
        'FontSize', 12, ...
        'ValueChangedFcn', @(src,~) callbacks.onStylePick(src.Value));
    ddStyleDlg.Layout.Row = 2; ddStyleDlg.Layout.Column = 2;

    % ── Separator label ──
    lblInfo = uilabel(sGL,'Text','Changes apply immediately.', ...
        'FontSize',10,'FontColor',[0.5 0.5 0.5],'FontAngle','italic');
    lblInfo.Layout.Row = 3; lblInfo.Layout.Column = [1 2];

    % ── Customise Toolbar button ──
    btnCustomTb = uibutton(sGL,'Text',[char(9881) '  Customise Toolbar...'], ...
        'FontSize',12, ...
        'Tooltip','Choose which buttons appear in the axes toolbar', ...
        'ButtonPushedFcn',@(~,~) callbacks.onCustomiseToolbar());
    btnCustomTb.Layout.Row = 4; btnCustomTb.Layout.Column = [1 2];

    % ── Close button ──
    btnClose = uibutton(sGL,'Text','Close', ...
        'FontSize',12, ...
        'ButtonPushedFcn',@(~,~) delete(settingsFig));
    btnClose.Layout.Row = 5; btnClose.Layout.Column = [1 2];

    bosonPlotter.applyDialogTheme(settingsFig, appData.theme);
end
