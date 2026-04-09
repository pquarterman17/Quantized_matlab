function layoutSettingsGUI(applyFn, currentSettings, defaultSettings, prefsFile)
% ════════════════════════════════════════════════════════════════════════
% GUI for configuring the layout and panel size defaults of BosonPlotter.
% ════════════════════════════════════════════════════════════════════════
%
% Syntax:
%   layoutSettingsGUI(applyFn, currentSettings, defaultSettings, prefsFile)
%
% Inputs:
%   applyFn         - function handle: @(settings) — called when Apply or
%                     Save is clicked; receives a settings struct and applies
%                     dimensions to the live BosonPlotter window.
%   currentSettings - struct with current dimension values (pre-fills spinners).
%   defaultSettings - struct with factory defaults (used by Reset button).
%   prefsFile       - char path to the .mat file for persistent defaults.
%
% Settings struct fields:
%   .figW       - Figure window width (px)
%   .figH       - Figure window height (px)
%   .ctrlPanelW - Dataset controls panel width (px, left sidebar)
%   .corrPanelW - Corrections panel width (px)
%   .axLimPanelW- Axes & Appearance panel width (px)
%   .fileListW  - File-list panel width (px, col 1 of contentGL; the file browser sidebar)
%
% ════════════════════════════════════════════════════════════════════════

% ── Guard: prevent duplicate windows ─────────────────────────────────
existing = findall(0, 'Type', 'figure', 'Name', 'Layout Settings');
if ~isempty(existing)
    figure(existing(1));
    return;
end

% ── Create figure ─────────────────────────────────────────────────────
fig = uifigure('Name', 'Layout Settings', ...
    'Position', [200 200 420 390], ...
    'Resize',   'off');

% ── Main grid: header + 3 sections + button bar ───────────────────────
mainGL = uigridlayout(fig, [5 1], ...
    'RowHeight',    {22, 150, 104, 24, 40}, ...
    'ColumnWidth',  {'1x'}, ...
    'Padding',      [10 10 10 10], ...
    'RowSpacing',   6);

% ── Row 1: top label ─────────────────────────────────────────────────
topLbl = uilabel(mainGL, ...
    'Text', 'Adjust default sizes and layout for the Data Import GUI window.', ...
    'FontSize', 10, 'FontColor', [0.4 0.4 0.4], ...
    'HorizontalAlignment', 'left');
topLbl.Layout.Row = 1; topLbl.Layout.Column = 1;

% ── Row 2: Window size + panel widths ────────────────────────────────
winPanel = uipanel(mainGL, 'Title', 'Window & Panel Sizes', 'FontSize', 11);
winPanel.Layout.Row = 2; winPanel.Layout.Column = 1;

winGL = uigridlayout(winPanel, [4 4], ...
    'RowHeight',    {26, 26, 26, 26}, ...
    'ColumnWidth',  {130, 70, 20, 70}, ...
    'Padding',      [8 6 8 6], ...
    'RowSpacing',   4, ...
    'ColumnSpacing', 6);

% Row 1: Figure dimensions
uilabel(winGL, 'Text', 'Figure width × height:', 'FontSize', 10);
uilabel(winGL, 'Text', 'Width', 'FontSize', 9, ...
    'HorizontalAlignment', 'center', 'FontColor', [0.5 0.5 0.5]);
uilabel(winGL, 'Text', '', 'FontSize', 9);  % spacer column
uilabel(winGL, 'Text', 'Height', 'FontSize', 9, ...
    'HorizontalAlignment', 'center', 'FontColor', [0.5 0.5 0.5]);

spFigW = uispinner(winGL, 'Value', currentSettings.figW, ...
    'Limits', [400 3840], 'Step', 50, ...
    'Tooltip', 'Main figure window width in pixels');
spFigW.Layout.Row = 2; spFigW.Layout.Column = [1 2];

uilabel(winGL, 'Text', '×', 'HorizontalAlignment', 'center', 'FontSize', 12);
spFigH = uispinner(winGL, 'Value', currentSettings.figH, ...
    'Limits', [500 2160], 'Step', 50, ...
    'Tooltip', 'Main figure window height in pixels (min 820 enforced)');
spFigH.Layout.Row = 2; spFigH.Layout.Column = 4;

% Row 3: Corrections panel width
uilabel(winGL, 'Text', 'Corrections panel width:', 'FontSize', 10);
spCorrW = uispinner(winGL, 'Value', currentSettings.corrPanelW, ...
    'Limits', [150 800], 'Step', 10, ...
    'Tooltip', 'Width of the Corrections sub-panel in the Analysis area');
spCorrW.Layout.Row = 3; spCorrW.Layout.Column = [2 4];

% Row 4: Axes & Appearance panel width
uilabel(winGL, 'Text', 'Axes & Appearance width:', 'FontSize', 10);
spAxLimW = uispinner(winGL, 'Value', currentSettings.axLimPanelW, ...
    'Limits', [100 500], 'Step', 10, ...
    'Tooltip', 'Width of the Axes & Appearance sub-panel in the Analysis area');
spAxLimW.Layout.Row = 4; spAxLimW.Layout.Column = [2 4];

% ── Row 3: Toolbar + controls panel ──────────────────────────────────
tbPanel = uipanel(mainGL, 'Title', 'Toolbar & Sidebar', 'FontSize', 11);
tbPanel.Layout.Row = 3; tbPanel.Layout.Column = 1;

tbGL = uigridlayout(tbPanel, [2 4], ...
    'RowHeight',    {26, 26}, ...
    'ColumnWidth',  {130, 70, 20, 70}, ...
    'Padding',      [8 6 8 6], ...
    'RowSpacing',   4, ...
    'ColumnSpacing', 6);

uilabel(tbGL, 'Text', 'Dataset list panel width:', 'FontSize', 10);
spCtrlW = uispinner(tbGL, 'Value', currentSettings.ctrlPanelW, ...
    'Limits', [100 600], 'Step', 10, ...
    'Tooltip', 'Width of the left-side Controls panel containing the dataset list');
spCtrlW.Layout.Row = 1; spCtrlW.Layout.Column = [2 4];

uilabel(tbGL, 'Text', 'File-list panel width:', 'FontSize', 10);
uilabel(tbGL, 'Text', '', 'FontSize', 9);
uilabel(tbGL, 'Text', '', 'FontSize', 9);
spFileListW = uispinner(tbGL, 'Value', currentSettings.fileListW, ...
    'Limits', [80 300], 'Step', 5, ...
    'Tooltip', 'Width of the file-list sidebar (dataset browser, col 1 of the top row)');
spFileListW.Layout.Row = 2; spFileListW.Layout.Column = 4;

% ── Row 4: status label ───────────────────────────────────────────────
lblStatus = uilabel(mainGL, 'Text', '', 'FontSize', 9, ...
    'FontColor', [0.3 0.55 0.3], 'HorizontalAlignment', 'left');
lblStatus.Layout.Row = 4; lblStatus.Layout.Column = 1;

% ── Row 5: action buttons ─────────────────────────────────────────────
btnGL = uigridlayout(mainGL, [1 4], ...
    'RowHeight',    {'1x'}, ...
    'ColumnWidth',  {'1x','1x','1x','1x'}, ...
    'Padding',      [0 0 0 0], ...
    'ColumnSpacing', 6);
btnGL.Layout.Row = 5; btnGL.Layout.Column = 1;

btnApply = uibutton(btnGL, 'Text', 'Apply', ...
    'ButtonPushedFcn', @onApply, ...
    'BackgroundColor', [0.15 0.37 0.63], ...
    'FontColor', [1 1 1], 'FontWeight', 'bold', ...
    'Tooltip', 'Apply settings to the current Data Import GUI window');
btnApply.Layout.Row = 1; btnApply.Layout.Column = 1;

btnSave = uibutton(btnGL, 'Text', 'Save as Defaults', ...
    'ButtonPushedFcn', @onSaveDefaults, ...
    'BackgroundColor', [0.18 0.52 0.18], ...
    'FontColor', [1 1 1], ...
    'Tooltip', 'Apply settings and save as persistent defaults (loaded on next GUI launch)');
btnSave.Layout.Row = 1; btnSave.Layout.Column = 2;

btnReset = uibutton(btnGL, 'Text', 'Reset', ...
    'ButtonPushedFcn', @onReset, ...
    'BackgroundColor', [0.50 0.28 0.05], ...
    'FontColor', [1 1 1], ...
    'Tooltip', 'Restore factory defaults in the spinners (does not apply until you click Apply)');
btnReset.Layout.Row = 1; btnReset.Layout.Column = 3;

btnClose = uibutton(btnGL, 'Text', 'Close', ...
    'ButtonPushedFcn', @(~,~) close(fig), ...
    'Tooltip', 'Close this window without applying changes');
btnClose.Layout.Row = 1; btnClose.Layout.Column = 4;

% ── Callbacks ─────────────────────────────────────────────────────────

    function s = readSpinners()
        s.figW       = spFigW.Value;
        s.figH       = spFigH.Value;
        s.ctrlPanelW = spCtrlW.Value;
        s.corrPanelW = spCorrW.Value;
        s.axLimPanelW = spAxLimW.Value;
        s.fileListW   = spFileListW.Value;
    end

    function onApply(~,~)
        try
            applyFn(readSpinners());
            lblStatus.Text = 'Applied.';
            lblStatus.FontColor = [0.2 0.5 0.2];
        catch ME
            lblStatus.Text = ['Error: ' ME.message];
            lblStatus.FontColor = [0.7 0.1 0.1];
        end
    end

    function onSaveDefaults(~,~)
        try
            s = readSpinners();
            applyFn(s);
            layoutPrefs = s;
            save(prefsFile, 'layoutPrefs');
            lblStatus.Text = ['Saved to ' prefsFile];
            lblStatus.FontColor = [0.2 0.5 0.2];
        catch ME
            lblStatus.Text = ['Save failed: ' ME.message];
            lblStatus.FontColor = [0.7 0.1 0.1];
        end
    end

    function onReset(~,~)
        spFigW.Value      = defaultSettings.figW;
        spFigH.Value      = defaultSettings.figH;
        spCtrlW.Value     = defaultSettings.ctrlPanelW;
        spCorrW.Value     = defaultSettings.corrPanelW;
        spAxLimW.Value    = defaultSettings.axLimPanelW;
        spFileListW.Value  = defaultSettings.fileListW;
        lblStatus.Text    = 'Reset to factory defaults (click Apply to use).';
        lblStatus.FontColor = [0.45 0.35 0.0];
    end

end
