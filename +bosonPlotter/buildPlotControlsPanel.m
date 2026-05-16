function s = buildPlotControlsPanel(ctrlGL, contentGL, tk, palette, callbacks)
%BUILDPLOTCONTROLSPANEL  Plot controls panel for BosonPlotter (ctrlGL rows 6–9).
%
%   s = bosonPlotter.buildPlotControlsPanel(ctrlGL, contentGL, tk, palette, callbacks)
%
%   Builds the axis-limits section (X/Y/Y2 min/max edit fields + tick-format
%   dropdowns + Auto/Reset buttons), the waterfall toggle and spacing field,
%   the Cts/s checkbox and Refresh button, and the Annotate/Style/Plot-options
%   row.  Also builds the right-side preview axes panel and toolbar grid.
%
%   Inputs
%     ctrlGL     uigridlayout inside ctrlPanel (9-row control column).
%                Sub-grids are placed in rows 6–9.
%     contentGL  uigridlayout for the top-level 3-column layout.
%                The preview axes panel (column 3) is placed here.
%     tk         UX tokens struct (tk.font.*, tk.pad.*, tk.color.*)
%     palette    struct of semantic colours — unused by this panel directly
%                but accepted for interface consistency with sibling builders
%     callbacks  struct of function handles:
%                  .onPlot               — full plot redraw
%                  .onAxisChanged        — scale / cts-per-sec changed
%                  .onWaterfallToggled   — waterfall checkbox toggled
%                  .onAutoLimits         — Reset button
%                  .onSmartScale         — Auto button
%                  .onAnnotationModeChanged — annotate checkbox toggled
%                  .onOpenPlotStyleDialog   — Style… button
%                  .onShowPlotOptionsMenu   — Plot ▾ menu button
%
%   Output
%     s          struct of widget handles.  Fields:
%                  Axis-limits grid:
%                    .limGL
%                    .efXMin, .efXMax, .ddXFmt
%                    .efYMin, .efYMax, .ddYFmt
%                    .efY2Min, .efY2Max, .ddY2Fmt
%                    .btnAutoLimits, .btnSmartScale
%                  Waterfall row:
%                    .cbWaterfall, .efWaterfallSpacing
%                  Misc row:
%                    .cbCountsPerSec, .btnPlot
%                  Annotation/style row:
%                    .cbAnnotationMode, .btnPlotStyle, .btnPlotOptions
%                  Preview pane:
%                    .axPanel, .axGL, .axToolbarGL
%
%   Usage
%     s = bosonPlotter.buildPlotControlsPanel(ctrlGL, contentGL, tk, palette, cbs);
%     % Wire any remaining late-bound callbacks on the returned handles, e.g.:
%     %   s.cbCountsPerSec.Enable = 'on';

    arguments
        ctrlGL
        contentGL
        tk         struct
        palette    struct
        callbacks  struct
    end

    % ── Tick-format menu data (mirrors the constants defined in BosonPlotter) ─
    TICKFMT_NAMES  = {'Auto', 'Scientific', 'Fixed 4dp', 'Fixed 2dp', 'Integer'};
    TICKFMT_DATA   = {'',     '%.2e',       '%.4f',      '%.2f',      '%d'};

    YTICKFMT_NAMES = {'Auto', 'Scientific', 'Fixed 4dp', 'Fixed 2dp', 'Integer', 'Exp = 0'};
    YTICKFMT_DATA  = {'',     '%.2e',       '%.4f',      '%.2f',      '%d',      '__exp0'};

    % Dark-on-dark colour scheme for axis-limit edit fields
    AXLIM_BG = [0.17 0.17 0.17];
    AXLIM_FG = [0.92 0.92 0.92];

    % ── Row 6: Axis limits (X/Y/Y2 min/max + fmt) + Auto/Reset ──────────────
    % Limits live next to the Linear/Log scale dropdowns they're paired with.
    s.limGL = uigridlayout(ctrlGL, [4 4], ...
        'Padding', tk.pad.flush, 'RowSpacing', 2, 'ColumnSpacing', 3, ...
        'RowHeight', {26, 26, 26, 28}, 'ColumnWidth', {20, '1x', '1x', 64});
    s.limGL.Layout.Row = 6;

    % Row 1: X limits + format
    lblXLim = uilabel(s.limGL, 'Text', 'X:', ...
        'HorizontalAlignment', 'right', 'FontSize', tk.font.label);
    lblXLim.Layout.Row = 1; lblXLim.Layout.Column = 1;

    s.efXMin = uieditfield(s.limGL, 'text', 'Value', '', ...
        'Placeholder', 'min', 'Tooltip', 'X axis minimum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'FontSize', tk.font.body, ...
        'ValueChangedFcn', @(~,~) callbacks.onPlot([], []));
    s.efXMin.Layout.Row = 1; s.efXMin.Layout.Column = 2;

    s.efXMax = uieditfield(s.limGL, 'text', 'Value', '', ...
        'Placeholder', 'max', 'Tooltip', 'X axis maximum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'FontSize', tk.font.body, ...
        'ValueChangedFcn', @(~,~) callbacks.onPlot([], []));
    s.efXMax.Layout.Row = 1; s.efXMax.Layout.Column = 3;

    s.ddXFmt = uidropdown(s.limGL, 'Items', TICKFMT_NAMES, 'ItemsData', TICKFMT_DATA, ...
        'Value', '', 'FontSize', tk.font.body, 'Tooltip', 'X-axis tick label notation', ...
        'ValueChangedFcn', @(~,~) callbacks.onPlot([], []));
    s.ddXFmt.Layout.Row = 1; s.ddXFmt.Layout.Column = 4;

    % Row 2: Y limits + format
    lblYLim = uilabel(s.limGL, 'Text', 'Y:', ...
        'HorizontalAlignment', 'right', 'FontSize', tk.font.label);
    lblYLim.Layout.Row = 2; lblYLim.Layout.Column = 1;

    s.efYMin = uieditfield(s.limGL, 'text', 'Value', '', ...
        'Placeholder', 'min', 'Tooltip', 'Y axis minimum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'FontSize', tk.font.body, ...
        'ValueChangedFcn', @(~,~) callbacks.onPlot([], []));
    s.efYMin.Layout.Row = 2; s.efYMin.Layout.Column = 2;

    s.efYMax = uieditfield(s.limGL, 'text', 'Value', '', ...
        'Placeholder', 'max', 'Tooltip', 'Y axis maximum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'FontSize', tk.font.body, ...
        'ValueChangedFcn', @(~,~) callbacks.onPlot([], []));
    s.efYMax.Layout.Row = 2; s.efYMax.Layout.Column = 3;

    s.ddYFmt = uidropdown(s.limGL, 'Items', YTICKFMT_NAMES, 'ItemsData', YTICKFMT_DATA, ...
        'Value', '__exp0', 'FontSize', tk.font.body, ...
        'Tooltip', 'Left Y-axis tick label notation', ...
        'ValueChangedFcn', @(~,~) callbacks.onPlot([], []));
    s.ddYFmt.Layout.Row = 2; s.ddYFmt.Layout.Column = 4;

    % Row 3: Y2 limits + format (RowHeight toggled to 0 when no Y2 active)
    lblY2Lim = uilabel(s.limGL, 'Text', 'Y2:', ...
        'HorizontalAlignment', 'right', 'FontSize', tk.font.label);
    lblY2Lim.Layout.Row = 3; lblY2Lim.Layout.Column = 1;

    s.efY2Min = uieditfield(s.limGL, 'text', 'Value', '', ...
        'Placeholder', 'min', 'Tooltip', 'Right Y-axis minimum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'FontSize', tk.font.body, ...
        'ValueChangedFcn', @(~,~) callbacks.onPlot([], []));
    s.efY2Min.Layout.Row = 3; s.efY2Min.Layout.Column = 2;

    s.efY2Max = uieditfield(s.limGL, 'text', 'Value', '', ...
        'Placeholder', 'max', 'Tooltip', 'Right Y-axis maximum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'FontSize', tk.font.body, ...
        'ValueChangedFcn', @(~,~) callbacks.onPlot([], []));
    s.efY2Max.Layout.Row = 3; s.efY2Max.Layout.Column = 3;

    s.ddY2Fmt = uidropdown(s.limGL, 'Items', YTICKFMT_NAMES, 'ItemsData', YTICKFMT_DATA, ...
        'Value', '', 'FontSize', tk.font.body, ...
        'Tooltip', 'Right Y-axis tick label notation', ...
        'ValueChangedFcn', @(~,~) callbacks.onPlot([], []));
    s.ddY2Fmt.Layout.Row = 3; s.ddY2Fmt.Layout.Column = 4;

    % Row 4: Auto-Scale + Reset
    s.btnSmartScale = uibutton(s.limGL, 'Text', 'Auto', ...
        'ButtonPushedFcn', callbacks.onSmartScale, 'FontSize', tk.font.body, ...
        'Tooltip', 'Auto-detect linear/log scale and set reasonable axis limits');
    s.btnSmartScale.Layout.Row = 4; s.btnSmartScale.Layout.Column = [1 2];

    s.btnAutoLimits = uibutton(s.limGL, 'Text', 'Reset', ...
        'ButtonPushedFcn', callbacks.onAutoLimits, 'FontSize', tk.font.body, ...
        'Tooltip', ['Reset View — clear manual axis limits and per-dataset' newline ...
                    'plot state (log/linear, grid, direction, 2D cmap/cLim)' newline ...
                    'so this dataset returns to auto defaults.']);
    s.btnAutoLimits.Layout.Row = 4; s.btnAutoLimits.Layout.Column = [3 4];

    % ── Row 7: Waterfall toggle + spacing ────────────────────────────────────
    wfGL = uigridlayout(ctrlGL, [1 2], ...
        'Padding', tk.pad.flush, 'ColumnSpacing', 4, 'ColumnWidth', {'1x', 50});
    wfGL.Layout.Row = 7;

    s.cbWaterfall = uicheckbox(wfGL, ...
        'Text',    'Waterfall', ...
        'Value',   false, ...
        'Tooltip', 'Waterfall: stack datasets vertically with a uniform Y offset', ...
        'ValueChangedFcn', @(~,~) callbacks.onWaterfallToggled());
    s.cbWaterfall.Layout.Column = 1;

    s.efWaterfallSpacing = uieditfield(wfGL, 'numeric', 'Value', 0, ...
        'Limits', [0 Inf], 'AllowEmpty', 'on', ...
        'Tooltip', ['Spacing between stacked traces in data units — ' ...
                    '0 or empty = auto (1.1× max data range)'], ...
        'ValueDisplayFormat', '%.4g', ...
        'ValueChangedFcn', @(~,~) callbacks.onPlot([], []));
    s.efWaterfallSpacing.Layout.Column = 2;

    % ── Row 8: Cts/s + Refresh ───────────────────────────────────────────────
    miscGL = uigridlayout(ctrlGL, [1 2], ...
        'Padding', tk.pad.flush, 'ColumnSpacing', 4, 'ColumnWidth', {'1x', 55});
    miscGL.Layout.Row = 8;

    s.cbCountsPerSec = uicheckbox(miscGL, 'Text', 'Cts/s', ...
        'Value', false, 'Enable', 'off', ...
        'Tooltip', 'Divide intensity by counting time (counts → counts/s). XRD files only.', ...
        'ValueChangedFcn', callbacks.onAxisChanged);
    s.cbCountsPerSec.Layout.Column = 1;

    s.btnPlot = uibutton(miscGL, 'Text', 'Refresh', ...
        'ButtonPushedFcn', callbacks.onPlot, ...
        'Tooltip', 'Force a full redraw of the current plot');
    s.btnPlot.Layout.Column = 2;

    % ── Row 9: Annotation mode + Style… + Plot Options button ────────────────
    annotPlotGL = uigridlayout(ctrlGL, [1 3], ...
        'Padding', tk.pad.flush, 'ColumnSpacing', 3, ...
        'ColumnWidth', {'1x', '1x', '1x'});
    annotPlotGL.Layout.Row = 9;

    s.cbAnnotationMode = uicheckbox(annotPlotGL, ...
        'Text',    'Annotate', ...
        'Value',   false, ...
        'Tooltip', 'Click on the plot to add text annotations. Right-click to delete.', ...
        'ValueChangedFcn', callbacks.onAnnotationModeChanged);
    s.cbAnnotationMode.Layout.Column = 1;

    s.btnPlotStyle = uibutton(annotPlotGL, 'Text', 'Style…', ...
        'ButtonPushedFcn', @(~,~) callbacks.onOpenPlotStyleDialog(), ...
        'BackgroundColor', [0.35 0.40 0.55], 'FontColor', [1 1 1], ...
        'FontSize', tk.font.label, ...
        'Tooltip', 'Fine-grained visual overrides: font, line width, marker, grid, legend (Phase B)');
    s.btnPlotStyle.Layout.Column = 2;

    s.btnPlotOptions = uibutton(annotPlotGL, 'Text', ['Plot ' char(9662)], ...
        'ButtonPushedFcn', callbacks.onShowPlotOptionsMenu, ...
        'BackgroundColor', [0.22 0.35 0.55], 'FontColor', [1 1 1], ...
        'FontSize', tk.font.label, ...
        'Tooltip', 'Plot types, visualization options, and unit conversion');
    s.btnPlotOptions.Layout.Column = 3;

    % ── Right: preview axes panel ─────────────────────────────────────────────
    s.axPanel = uipanel(contentGL, 'Title', '');
    s.axPanel.Layout.Column = 3;
    s.axGL = uigridlayout(s.axPanel, [3 1], 'Padding', tk.pad.tight, 'RowSpacing', 1, ...
        'RowHeight', {18, '1x', 20});

    % ── Dynamic axes toolbar (right-aligned buttons, rebuilt by buildToolbar) ─
    s.axToolbarGL = uigridlayout(s.axGL, [1 1], ...
        'Padding', tk.pad.flush, 'ColumnSpacing', 2);
    s.axToolbarGL.Layout.Row = 1;
end
