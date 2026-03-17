function varargout = emViewerGUI()
%EMVIEWERGUI  Standalone electron microscopy image viewer and analysis tool.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   emViewerGUI()
%   api = emViewerGUI()
%
% ── Description ───────────────────────────────────────────────────────────
%
%   Interactive uifigure GUI for viewing and analysing electron microscopy
%   images.  Supports TIFF (.tif/.tiff) and headerless RAW binary files.
%   Images are displayed with calibrated pixel coordinates, mouse-hover
%   intensity readout, zoom controls, and a metadata inspector.
%
%   The GUI follows the same monolithic-function architecture as
%   dataImportGUI.m: all mutable state lives in the appData struct, all
%   callbacks are nested functions sharing closure over appData and widget
%   handles, and a programmatic API struct is returned when called with an
%   output argument.
%
% ── Supported File Formats ────────────────────────────────────────────────
%
%   Extension(s)      Parser              Description
%   ──────────────    ──────────────────  ─────────────────────────────────
%   .tif / .tiff      importTIFF          TIFF images (8/16/32-bit, FEI)
%   .raw              importRawImage      Headerless binary (user dims)
%   .dm3 / .dm4       importDM3           Gatan DigitalMicrograph v3/v4
%
% ── GUI Layout ────────────────────────────────────────────────────────────
%
%   +------------------------------------------------------------------+
%   | Toolbar: [Open Files...] [Remove] | [Fit] [1:1] | filename       |
%   +------------------------------------------------------------------+
%   |            |                                  |                   |
%   | Image List |     Main Image Display           | Tools Panel       |
%   | (listbox)  |     (uiaxes + imagesc)           |                   |
%   |            |                                  | -- Contrast --    |
%   |            |                                  | -- Histogram --   |
%   |            |                                  | -- Measurement -- |
%   |            |                                  | -- Processing --  |
%   |            |                                  | -- Metadata --    |
%   |            |                                  | [metadata text]   |
%   +------------------------------------------------------------------+
%   | Status: 2048x2048 px | 16-bit | 2.4 nm/px | (512, 384) = 1547   |
%   +------------------------------------------------------------------+
%
% ── Programmatic API ──────────────────────────────────────────────────────
%
%   api = emViewerGUI() returns a struct of function handles:
%
%   api.fig                          — figure handle
%   api.loadImages(paths)            — load a cell array of file paths
%   api.getImages()                  — return loaded image data structs
%   api.getActiveIdx()               — index of active image (0 = none)
%   api.setActiveIdx(idx)            — switch to image at index idx
%   api.setContrast(low, high)       — set Low/High contrast window
%   api.autoContrast()               — auto-stretch to [2nd, 98th] percentile
%   api.getLineProfile(x1,y1,x2,y2) — extract line profile
%   api.applyFilter(type, params)    — type='gaussian' (params.Sigma) or 'median' (params.WindowSize)
%   api.computeFFT()                 — compute FFT; returns struct with .magnitude/.phase
%   api.exportImage(path)            — save current displayImg to PNG or TIFF
%   api.close()                      — close figure
%
%   Headless usage (e.g. in test_em_gui_harness.m):
%     api = emViewerGUI();
%     api.fig.Visible = 'off';
%     api.loadImages({'sem_image.tif'});
%     imgs = api.getImages();
%     api.close();
%
% ── Requirements ──────────────────────────────────────────────────────────
%
%   MATLAB R2021b+ (arguments blocks, uifigure, uilistbox Multiselect).
%   No external toolboxes required.
%
% ── See Also ──────────────────────────────────────────────────────────────
%
%   parser.importTIFF, parser.importRawImage, parser.importAuto,
%   dataImportGUI, test_em_gui_harness

    % ════════════════════════════════════════════════════════════════════
    %  SHARED APPLICATION STATE
    % ════════════════════════════════════════════════════════════════════
    appData.images         = {};    % cell array of loaded data structs (from parsers)
    appData.activeIdx      = 0;    % index of currently displayed image (0 = none)
    appData.rawPixels      = [];   % original pixels from parser (reset on undo)
    appData.preCropPixels  = [];   % snapshot of rawPixels before crop (for undo)
    appData.filteredPixels = [];   % pixels after filters, before contrast
    appData.displayImg     = [];   % final [0,1] image shown via CData
    appData.imgHandle      = [];   % handle to the imagesc graphics object
    appData.overlays   = struct( ...
        'scalebar',     [], ...      % struct with .bar and .label handles from addScaleBar
        'lines',        {{}}, ...   % cell array of line graphics handles
        'clickMarkers', {{}}, ...   % cell array of click-marker graphics handles
        'distLabels',   {{}}, ...   % cell array of text graphics handles
        'measurements', {{}}, ...   % cell array of measurement structs (for draggable endpoints)
        'textAnnotations', {{}});  % cell array of text annotation structs
    appData.lastProfile   = struct('dist', [], 'intensity', [], 'unit', 'px');
    appData.captureMode   = '';     % '' | 'profile' | 'distance' | 'zoom' | 'crop' | 'savecrop' | 'annotation'
    appData.captureClicks = [];     % [Nx2] accumulated click coords (x y per row)
    appData.lastDir       = '';     % last browsed directory for file open dialog

    % Comparison mode state
    appData.compareMode        = false;   % true when side-by-side is active
    appData.compareIdxL        = 0;       % left panel image index
    appData.compareIdxR        = 0;       % right panel image index
    appData.compareActivePanel = 'L';     % 'L' or 'R' — which panel arrows control

    % Annotation defaults
    appData.annotationColor = [1 1 1];    % white

    % ════════════════════════════════════════════════════════════════════
    %  SEMANTIC BUTTON COLOUR PALETTE
    % ════════════════════════════════════════════════════════════════════
    BTN_PRIMARY   = [0.18 0.52 0.18];   % green  — primary actions
    BTN_DANGER    = [0.55 0.15 0.15];   % red    — destructive actions
    BTN_TOOL      = [0.28 0.28 0.28];   % gray   — secondary tools
    BTN_EXPORT    = [0.18 0.32 0.52];   % blue   — export actions
    BTN_FG        = [1 1 1];            % white text on dark buttons
    OVERLAY_COLOR = [0 1 1];            % cyan   — measurement overlays

    % ════════════════════════════════════════════════════════════════════
    %  FIGURE
    % ════════════════════════════════════════════════════════════════════
    fig = uifigure('Name', 'EM Image Viewer — Thin Film Toolkit', ...
                   'Position', [100 100 1200 720], ...
                   'AutoResizeChildren', 'off');
    fig.CloseRequestFcn = @onFigureClose;

    % ════════════════════════════════════════════════════════════════════
    %  ROOT GRID: 3 rows x 1 col
    %    Row 1 (30px):  Toolbar
    %    Row 2 (1x):    Main content area
    %    Row 3 (22px):  Status bar
    % ════════════════════════════════════════════════════════════════════
    rootGL = uigridlayout(fig, [3 1], ...
        'RowHeight',    {30, '1x', 22}, ...
        'ColumnWidth',  {'1x'}, ...
        'Padding',      [6 6 6 6], ...
        'RowSpacing',   4, ...
        'ColumnSpacing', 0);

    % ════════════════════════════════════════════════════════════════════
    %  ROW 1: TOOLBAR
    %  [Open Files...] [Remove] | gap | [Fit] [1:1] | filename label
    % ════════════════════════════════════════════════════════════════════
    toolbarGL = uigridlayout(rootGL, [1 9], ...
        'ColumnWidth', {90, 65, 14, 40, 40, 14, 65, 14, '1x'}, ...
        'RowHeight',   {'1x'}, ...
        'Padding',     [4 2 4 2], ...
        'ColumnSpacing', 4);
    toolbarGL.Layout.Row = 1;
    toolbarGL.Layout.Column = 1;

    btnOpen = uibutton(toolbarGL, 'Text', 'Open...', ...
        'ButtonPushedFcn', @onOpenFiles, ...
        'BackgroundColor', BTN_PRIMARY, ...
        'FontColor', BTN_FG, ...
        'FontWeight', 'bold', ...
        'Tooltip', 'Browse for TIFF or RAW image files to load');
    btnOpen.Layout.Row = 1; btnOpen.Layout.Column = 1;

    btnRemove = uibutton(toolbarGL, 'Text', 'Remove', ...
        'ButtonPushedFcn', @onRemoveImage, ...
        'BackgroundColor', BTN_DANGER, ...
        'FontColor', BTN_FG, ...
        'Tooltip', 'Remove the selected image(s) from the list');
    btnRemove.Layout.Row = 1; btnRemove.Layout.Column = 2;

    % Separator gap (column 3 is empty space)
    lblSep = uilabel(toolbarGL, 'Text', '|', ...
        'FontColor', [0.5 0.5 0.5], ...
        'HorizontalAlignment', 'center');
    lblSep.Layout.Row = 1; lblSep.Layout.Column = 3; %#ok<NASGU>

    btnZoomFit = uibutton(toolbarGL, 'Text', 'Fit', ...
        'ButtonPushedFcn', @onZoomFit, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor', BTN_FG, ...
        'Tooltip', 'Zoom to fit the entire image in the axes');
    btnZoomFit.Layout.Row = 1; btnZoomFit.Layout.Column = 4;

    btnZoomActual = uibutton(toolbarGL, 'Text', '1:1', ...
        'ButtonPushedFcn', @onZoomActual, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor', BTN_FG, ...
        'Tooltip', 'Zoom to actual pixels (100% — one image pixel = one screen pixel)');
    btnZoomActual.Layout.Row = 1; btnZoomActual.Layout.Column = 5;

    % Separator gap (column 6 is empty space)
    lblSep2 = uilabel(toolbarGL, 'Text', '|', ...
        'FontColor', [0.5 0.5 0.5], ...
        'HorizontalAlignment', 'center');
    lblSep2.Layout.Row = 1; lblSep2.Layout.Column = 6; %#ok<NASGU>

    btnCompare = uibutton(toolbarGL, 'state', 'Text', 'Compare', ...
        'ValueChangedFcn', @onCompareToggle, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor', BTN_FG, ...
        'Enable', 'off', ...
        'Tooltip', 'Side-by-side comparison (Tab to switch active panel, arrows to scroll)');
    btnCompare.Layout.Row = 1; btnCompare.Layout.Column = 7;

    lblSep3 = uilabel(toolbarGL, 'Text', '|', ...
        'FontColor', [0.5 0.5 0.5], ...
        'HorizontalAlignment', 'center');
    lblSep3.Layout.Row = 1; lblSep3.Layout.Column = 8; %#ok<NASGU>

    lblFilename = uilabel(toolbarGL, 'Text', '(no image loaded)', ...
        'FontSize', 11, ...
        'FontColor', [0.85 0.85 0.85], ...
        'HorizontalAlignment', 'left');
    lblFilename.Layout.Row = 1; lblFilename.Layout.Column = 9;

    % ════════════════════════════════════════════════════════════════════
    %  ROW 2: MAIN CONTENT — 3 columns
    %    Col 1 (180px):  Image list panel
    %    Col 2 (1x):     Image display (uiaxes)
    %    Col 3 (240px):  Tools panel (scrollable)
    % ════════════════════════════════════════════════════════════════════
    mainGL = uigridlayout(rootGL, [1 3], ...
        'ColumnWidth', {160, '1x', 240}, ...
        'RowHeight',   {'1x'}, ...
        'Padding',     [0 0 0 0], ...
        'ColumnSpacing', 6);
    mainGL.Layout.Row = 2;
    mainGL.Layout.Column = 1;

    % ── Col 1: Image list ────────────────────────────────────────────────
    listPanel = uipanel(mainGL, 'Title', 'Images', 'FontSize', 11);
    listPanel.Layout.Row = 1;
    listPanel.Layout.Column = 1;

    listGL = uigridlayout(listPanel, [1 1], ...
        'Padding', [4 4 4 4]);

    lbImages = uilistbox(listGL, ...
        'Items', {'(no images loaded)'}, ...
        'ItemsData', {0}, ...
        'Multiselect', 'on', ...
        'ValueChangedFcn', @onSelectImage, ...
        'Tooltip', 'Loaded images — click to display; Ctrl+click for multi-select');

    % ── Col 2: Image display axes ────────────────────────────────────────
    axPanel = uipanel(mainGL, 'Title', '', 'BorderType', 'none');
    axPanel.Layout.Row = 1;
    axPanel.Layout.Column = 2;

    axGL = uigridlayout(axPanel, [1 1], 'Padding', [2 2 2 2]);

    ax = uiaxes(axGL);
    ax.Box = 'on';
    ax.XTick = [];
    ax.YTick = [];
    title(ax, 'Open an image file to begin', 'Interpreter', 'none');
    xlabel(ax, '');
    ylabel(ax, '');
    colormap(ax, gray(256));
    ax.Toolbar.Visible = 'off';

    % Comparison mode axes (created/destroyed dynamically)
    compareGL = [];   % uigridlayout replacing axGL when in compare mode
    axL       = [];   % left uiaxes
    axR       = [];   % right uiaxes

    % Mouse hover tracking via figure-level motion callback
    fig.WindowButtonMotionFcn = @onMouseMotion;

    % Keyboard: Escape cancels any in-progress two-click capture
    fig.KeyPressFcn = @onKeyPress;

    % ── Col 3: Tools panel ───────────────────────────────────────────────
    toolsPanel = uipanel(mainGL, 'Title', 'Tools', 'FontSize', 11, ...
        'Scrollable', 'on');
    toolsPanel.Layout.Row = 1;
    toolsPanel.Layout.Column = 3;

    toolsGL = uigridlayout(toolsPanel, [12 1], ...
        'RowHeight', {14, 140, 14, 90, 14, 140, 14, 160, 14, 108, 14, '1x'}, ...
        'ColumnWidth', {'1x'}, ...
        'Padding', [4 4 4 4], ...
        'RowSpacing', 1);

    % ── Section 1: Contrast ───────────────────────────────────────────────
    lblContrastHeader = uilabel(toolsGL, 'Text', 'Contrast', ...
        'FontWeight', 'bold', 'FontSize', 11, ...
        'FontColor', [0.15 0.15 0.15]);
    lblContrastHeader.Layout.Row = 1; %#ok<NASGU>

    pnlContrast = uipanel(toolsGL, 'BorderType', 'line');
    pnlContrast.Layout.Row = 2;

    % Inner grid: Low label+slider, High label+slider, two buttons, colormap
    contrastInnerGL = uigridlayout(pnlContrast, [7 2], ...
        'RowHeight',   {12, 20, 12, 20, 2, 20, 20}, ...
        'ColumnWidth', {'1x', '1x'}, ...
        'Padding',     [3 2 3 2], ...
        'RowSpacing',  1, ...
        'ColumnSpacing', 3);

    lblLow = uilabel(contrastInnerGL, 'Text', 'Low', ...
        'FontSize', 8, 'HorizontalAlignment', 'left');
    lblLow.Layout.Row = 1; lblLow.Layout.Column = [1 2]; %#ok<NASGU>

    sldLow = uislider(contrastInnerGL, ...
        'Value', 0, 'Limits', [0 1], ...
        'ValueChangedFcn', @onContrastChanged, ...
        'Tooltip', 'Lower contrast bound (dark clipping point)');
    sldLow.Layout.Row = 2; sldLow.Layout.Column = [1 2];
    sldLow.MajorTicks = [];
    sldLow.MinorTicks = [];

    lblHigh = uilabel(contrastInnerGL, 'Text', 'High', ...
        'FontSize', 8, 'HorizontalAlignment', 'left');
    lblHigh.Layout.Row = 3; lblHigh.Layout.Column = [1 2]; %#ok<NASGU>

    sldHigh = uislider(contrastInnerGL, ...
        'Value', 1, 'Limits', [0 1], ...
        'ValueChangedFcn', @onContrastChanged, ...
        'Tooltip', 'Upper contrast bound (bright clipping point)');
    sldHigh.Layout.Row = 4; sldHigh.Layout.Column = [1 2];
    sldHigh.MajorTicks = [];
    sldHigh.MinorTicks = [];

    % Gap row 5 is just spacing

    btnAutoContrast = uibutton(contrastInnerGL, 'Text', 'Auto', ...
        'ButtonPushedFcn', @onAutoContrast, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor', BTN_FG, ...
        'Tooltip', 'Auto-stretch contrast to [2nd, 98th] percentile');
    btnAutoContrast.Layout.Row = 6; btnAutoContrast.Layout.Column = 1;

    btnResetContrast = uibutton(contrastInnerGL, 'Text', 'Reset', ...
        'ButtonPushedFcn', @onResetContrast, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor', BTN_FG, ...
        'Tooltip', 'Reset contrast to full pixel range');
    btnResetContrast.Layout.Row = 6; btnResetContrast.Layout.Column = 2;

    ddColormap = uidropdown(contrastInnerGL, ...
        'Items', {'gray', 'parula', 'hot', 'jet', 'bone'}, ...
        'Value', 'gray', ...
        'ValueChangedFcn', @onColormapChanged, ...
        'Tooltip', 'Select colormap for image display');
    ddColormap.Layout.Row = 7; ddColormap.Layout.Column = [1 2];

    % ── Section 2: Histogram ──────────────────────────────────────────────
    lblHistogramHeader = uilabel(toolsGL, 'Text', 'Histogram', ...
        'FontWeight', 'bold', 'FontSize', 11, ...
        'FontColor', [0.15 0.15 0.15]);
    lblHistogramHeader.Layout.Row = 3; %#ok<NASGU>

    pnlHistogram = uipanel(toolsGL, 'BorderType', 'line');
    pnlHistogram.Layout.Row = 4;

    histInnerGL = uigridlayout(pnlHistogram, [1 1], ...
        'Padding', [2 2 2 2]);

    histAx = uiaxes(histInnerGL);
    histAx.XTick = [];
    histAx.YTick = [];
    histAx.XColor = [0.5 0.5 0.5];
    histAx.YColor = [0.5 0.5 0.5];
    histAx.FontSize = 8;
    histAx.Box = 'on';
    histAx.XLim = [0 1];
    histAx.YLim = [0 1];
    histAx.Toolbar.Visible = 'off';
    title(histAx, '');
    xlabel(histAx, '');
    ylabel(histAx, '');

    % ── Section 3: Measurement ────────────────────────────────────────────
    lblMeasureHeader = uilabel(toolsGL, 'Text', 'Measurement', ...
        'FontWeight', 'bold', 'FontSize', 11, ...
        'FontColor', [0.15 0.15 0.15]);
    lblMeasureHeader.Layout.Row = 5; %#ok<NASGU>

    pnlMeasure = uipanel(toolsGL, 'BorderType', 'line');
    pnlMeasure.Layout.Row = 6;

    % 8-row grid inside the measurement panel:
    %   Row 1: Scale bar checkbox
    %   Row 2: Scale bar options — color toggle + font size spinner
    %   Row 3: (separator gap)
    %   Row 4: Line Profile button
    %   Row 5: Distance button
    %   Row 6: Export Profile button
    %   Row 7: Clear All button
    %   Row 8: (padding)
    measureInnerGL = uigridlayout(pnlMeasure, [7 2], ...
        'RowHeight',   {18, 20, 2, 20, 20, 20, 20}, ...
        'ColumnWidth', {'1x', '1x'}, ...
        'Padding',     [3 2 3 2], ...
        'RowSpacing',  2, ...
        'ColumnSpacing', 3);

    cbScaleBar = uicheckbox(measureInnerGL, ...
        'Text',    'Scale Bar', ...
        'Value',   false, ...
        'Enable',  'off', ...
        'ValueChangedFcn', @onScaleBarToggle, ...
        'Tooltip', 'Overlay a draggable scale bar (requires pixel size calibration)');
    cbScaleBar.Layout.Row = 1; cbScaleBar.Layout.Column = [1 2];

    % Scale bar options row: color toggle + font size
    btnScaleBarColor = uibutton(measureInnerGL, 'Text', 'White', ...
        'ButtonPushedFcn', @onScaleBarColorToggle, ...
        'BackgroundColor', [0.25 0.25 0.25], ...
        'FontColor',       [1 1 1], ...
        'Enable',          'off', ...
        'Tooltip',         'Toggle scale bar colour between white and black');
    btnScaleBarColor.Layout.Row = 2; btnScaleBarColor.Layout.Column = 1;

    spnScaleBarFont = uispinner(measureInnerGL, ...
        'Value', 30, 'Limits', [6 72], 'Step', 1, ...
        'ValueChangedFcn', @onScaleBarFontChange, ...
        'Enable', 'off', ...
        'Tooltip', 'Scale bar label font size (pt)');
    spnScaleBarFont.Layout.Row = 2; spnScaleBarFont.Layout.Column = 2;

    btnLineProfile = uibutton(measureInnerGL, 'Text', 'Line Profile', ...
        'ButtonPushedFcn', @onLineProfile, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor',       BTN_FG, ...
        'Enable',          'off', ...
        'Tooltip',         'Click two points to extract an intensity profile (Esc to cancel)');
    btnLineProfile.Layout.Row = 4; btnLineProfile.Layout.Column = [1 2];

    btnDistance = uibutton(measureInnerGL, 'Text', 'Distance', ...
        'ButtonPushedFcn', @onDistance, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor',       BTN_FG, ...
        'Enable',          'off', ...
        'Tooltip',         'Click two points to measure distance (Esc to cancel)');
    btnDistance.Layout.Row = 5; btnDistance.Layout.Column = [1 2];

    btnExportProfile = uibutton(measureInnerGL, 'Text', 'Export CSV', ...
        'ButtonPushedFcn', @onExportProfile, ...
        'BackgroundColor', BTN_EXPORT, ...
        'FontColor',       BTN_FG, ...
        'Enable',          'off', ...
        'Tooltip',         'Save the last line profile to a CSV file');
    btnExportProfile.Layout.Row = 6; btnExportProfile.Layout.Column = [1 2];

    btnClearOverlays = uibutton(measureInnerGL, 'Text', 'Clear All', ...
        'ButtonPushedFcn', @onClearOverlays, ...
        'BackgroundColor', BTN_DANGER, ...
        'FontColor',       BTN_FG, ...
        'Enable',          'off', ...
        'Tooltip',         'Remove all measurement overlays from the image');
    btnClearOverlays.Layout.Row = 7; btnClearOverlays.Layout.Column = [1 2];

    % ── Section 4: Processing ────────────────────────────────────────────
    lblProcessHeader = uilabel(toolsGL, 'Text', 'Processing', ...
        'FontWeight', 'bold', 'FontSize', 11, ...
        'FontColor', [0.15 0.15 0.15]);
    lblProcessHeader.Layout.Row = 7; %#ok<NASGU>

    pnlProcess = uipanel(toolsGL, 'BorderType', 'line');
    pnlProcess.Layout.Row = 8;

    processInnerGL = uigridlayout(pnlProcess, [7 2], ...
        'RowHeight',   {20, 20, 20, 2, 20, 20, 20}, ...
        'ColumnWidth', {'1x', '1x'}, ...
        'Padding',     [3 2 3 2], ...
        'RowSpacing',  2, ...
        'ColumnSpacing', 3);

    btnGaussian = uibutton(processInnerGL, 'Text', 'Gaussian...', ...
        'ButtonPushedFcn', @onGaussianFilter, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor', BTN_FG, ...
        'Enable', 'off', ...
        'Tooltip', 'Apply Gaussian blur — prompts for sigma value');
    btnGaussian.Layout.Row = 1; btnGaussian.Layout.Column = 1;

    btnMedian = uibutton(processInnerGL, 'Text', 'Median...', ...
        'ButtonPushedFcn', @onMedianFilter, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor', BTN_FG, ...
        'Enable', 'off', ...
        'Tooltip', 'Apply median filter — prompts for window size (3/5/7)');
    btnMedian.Layout.Row = 1; btnMedian.Layout.Column = 2;

    btnShowFFT = uibutton(processInnerGL, 'Text', 'Show FFT', ...
        'ButtonPushedFcn', @onShowFFT, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor', BTN_FG, ...
        'Enable', 'off', ...
        'Tooltip', 'Display 2D FFT magnitude in a new figure window');
    btnShowFFT.Layout.Row = 2; btnShowFFT.Layout.Column = [1 2];

    btnUndoFilters = uibutton(processInnerGL, 'Text', 'Undo Filters', ...
        'ButtonPushedFcn', @onUndoFilters, ...
        'BackgroundColor', BTN_DANGER, ...
        'FontColor', BTN_FG, ...
        'Enable', 'off', ...
        'Tooltip', 'Revert to the original unfiltered image');
    btnUndoFilters.Layout.Row = 3; btnUndoFilters.Layout.Column = [1 2];

    % Row 4 = separator gap

    btnZoomBox = uibutton(processInnerGL, 'Text', 'Zoom Box', ...
        'ButtonPushedFcn', @onZoomBox, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor', BTN_FG, ...
        'Enable', 'off', ...
        'Tooltip', 'Draw a rectangle to zoom into a region (Esc to cancel)');
    btnZoomBox.Layout.Row = 5; btnZoomBox.Layout.Column = 1;

    btnResetZoom = uibutton(processInnerGL, 'Text', 'Reset Zoom', ...
        'ButtonPushedFcn', @onResetZoom, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor', BTN_FG, ...
        'Enable', 'off', ...
        'Tooltip', 'Reset zoom to show the full image');
    btnResetZoom.Layout.Row = 5; btnResetZoom.Layout.Column = 2;

    btnCropImage = uibutton(processInnerGL, 'Text', 'Crop', ...
        'ButtonPushedFcn', @onCropImage, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor', BTN_FG, ...
        'Enable', 'off', ...
        'Tooltip', 'Draw a rectangle to crop the image (destructive — use Undo Filters to revert)');
    btnCropImage.Layout.Row = 6; btnCropImage.Layout.Column = 1;

    btnSaveCrop = uibutton(processInnerGL, 'Text', 'Save Crop...', ...
        'ButtonPushedFcn', @onSaveCrop, ...
        'BackgroundColor', BTN_EXPORT, ...
        'FontColor', BTN_FG, ...
        'Enable', 'off', ...
        'Tooltip', 'Save a cropped region to file (draw box, then save)');
    btnSaveCrop.Layout.Row = 6; btnSaveCrop.Layout.Column = 2;

    btnSaveImage = uibutton(processInnerGL, 'Text', 'Save Image...', ...
        'ButtonPushedFcn', @onSaveImage, ...
        'BackgroundColor', BTN_EXPORT, ...
        'FontColor', BTN_FG, ...
        'Enable', 'off', ...
        'Tooltip', 'Save current processed image to PNG or TIFF');
    btnSaveImage.Layout.Row = 7; btnSaveImage.Layout.Column = [1 2];

    % ── Section 5: Annotations ──────────────────────────────────────────
    lblAnnotHeader = uilabel(toolsGL, 'Text', 'Annotations', ...
        'FontWeight', 'bold', 'FontSize', 11, ...
        'FontColor', [0.15 0.15 0.15]);
    lblAnnotHeader.Layout.Row = 9; %#ok<NASGU>

    pnlAnnot = uipanel(toolsGL, 'BorderType', 'line');
    pnlAnnot.Layout.Row = 10;

    annotInnerGL = uigridlayout(pnlAnnot, [4 2], ...
        'RowHeight',   {20, 20, 20, 20}, ...
        'ColumnWidth', {'1x', '1x'}, ...
        'Padding',     [3 2 3 2], ...
        'RowSpacing',  2, ...
        'ColumnSpacing', 3);

    % Row 1: Text input field (spans both columns)
    efAnnotText = uieditfield(annotInnerGL, 'text', ...
        'Value', 'Label', ...
        'Tooltip', 'Text to place on the image');
    efAnnotText.Layout.Row = 1; efAnnotText.Layout.Column = [1 2];

    % Row 2: Font size spinner + Color cycle button
    spnAnnotFont = uispinner(annotInnerGL, ...
        'Value', 18, 'Limits', [6 72], 'Step', 1, ...
        'Tooltip', 'Font size for annotation text');
    spnAnnotFont.Layout.Row = 2; spnAnnotFont.Layout.Column = 1;

    btnAnnotColor = uibutton(annotInnerGL, 'Text', 'White', ...
        'ButtonPushedFcn', @onAnnotColorCycle, ...
        'BackgroundColor', [0.25 0.25 0.25], ...
        'FontColor', [1 1 1], ...
        'Enable', 'off', ...
        'Tooltip', 'Cycle text colour: White / Cyan / Yellow / Red / Black');
    btnAnnotColor.Layout.Row = 2; btnAnnotColor.Layout.Column = 2;

    % Row 3: Place Text button
    btnPlaceAnnot = uibutton(annotInnerGL, 'Text', 'Place Text', ...
        'ButtonPushedFcn', @onPlaceAnnotation, ...
        'BackgroundColor', BTN_TOOL, ...
        'FontColor', BTN_FG, ...
        'Enable', 'off', ...
        'Tooltip', 'Click on image to place text annotation (Esc to cancel)');
    btnPlaceAnnot.Layout.Row = 3; btnPlaceAnnot.Layout.Column = [1 2];

    % Row 4: Clear Annotations button
    btnClearAnnot = uibutton(annotInnerGL, 'Text', 'Clear Text', ...
        'ButtonPushedFcn', @onClearAnnotations, ...
        'BackgroundColor', BTN_DANGER, ...
        'FontColor', BTN_FG, ...
        'Enable', 'off', ...
        'Tooltip', 'Remove all text annotations from the image');
    btnClearAnnot.Layout.Row = 4; btnClearAnnot.Layout.Column = [1 2];

    % Row 5: (padding — unused for now)

    % ── Section 6: Metadata (populated) ──────────────────────────────────
    lblMetaHeader = uilabel(toolsGL, 'Text', 'Metadata', ...
        'FontWeight', 'bold', 'FontSize', 11, ...
        'FontColor', [0.15 0.15 0.15]);
    lblMetaHeader.Layout.Row = 11; %#ok<NASGU>

    taMetadata = uitextarea(toolsGL, ...
        'Value', {'(no image loaded)'}, ...
        'Editable', 'off', ...
        'FontName', 'Courier New', ...
        'FontSize', 10);
    taMetadata.Layout.Row = 12;

    % ════════════════════════════════════════════════════════════════════
    %  ROW 3: STATUS BAR
    %  [dimensions] | [bit depth] | [pixel size] | [mouse position]
    % ════════════════════════════════════════════════════════════════════
    statusGL = uigridlayout(rootGL, [1 4], ...
        'ColumnWidth', {110, 60, 100, '1x'}, ...
        'RowHeight',   {'1x'}, ...
        'Padding',     [6 0 6 0], ...
        'ColumnSpacing', 10);
    statusGL.Layout.Row = 3;
    statusGL.Layout.Column = 1;

    lblStatusDims = uilabel(statusGL, 'Text', '-- x -- px', ...
        'FontSize', 10, 'FontColor', [0.45 0.45 0.45]);
    lblStatusDims.Layout.Row = 1; lblStatusDims.Layout.Column = 1;

    lblStatusBits = uilabel(statusGL, 'Text', '--bit', ...
        'FontSize', 10, 'FontColor', [0.45 0.45 0.45]);
    lblStatusBits.Layout.Row = 1; lblStatusBits.Layout.Column = 2;

    lblStatusPixSize = uilabel(statusGL, 'Text', 'uncalibrated', ...
        'FontSize', 10, 'FontColor', [0.45 0.45 0.45]);
    lblStatusPixSize.Layout.Row = 1; lblStatusPixSize.Layout.Column = 3;

    lblStatusMouse = uilabel(statusGL, 'Text', '', ...
        'FontSize', 10, 'FontColor', [0.45 0.45 0.45]);
    lblStatusMouse.Layout.Row = 1; lblStatusMouse.Layout.Column = 4;

    % ════════════════════════════════════════════════════════════════════
    %  PROGRAMMATIC API (returned when nargout > 0)
    % ════════════════════════════════════════════════════════════════════
    if nargout > 0
        api.fig            = fig;
        api.loadImages     = @(paths) loadImagesAPI(paths);
        api.getImages      = @getImagesAPI;
        api.getActiveIdx   = @getActiveIdxAPI;
        api.setActiveIdx   = @(idx) setActiveIdxAPI(idx);

        % Phase 4 — contrast
        api.setContrast    = @(low, high) setContrastAPI(low, high);
        api.autoContrast   = @() onAutoContrast([], []);

        % Phase 5 — measurement
        api.getLineProfile = @(x1,y1,x2,y2) getLineProfileAPI(x1,y1,x2,y2);

        % Phase 6 — processing & export
        api.applyFilter    = @(type, params) applyFilterAPI(type, params);
        api.computeFFT     = @() computeFFTAPI();
        api.exportImage    = @(path) exportImageAPI(path);

        % Comparison mode
        api.enterCompare    = @() enterCompareMode();
        api.exitCompare     = @() exitCompareMode();
        api.isCompareMode   = @() appData.compareMode;

        % Annotations
        api.placeAnnotation = @(x, y, str, sz, col) placeAnnotationAPI(x, y, str, sz, col);
        api.clearAnnotations = @() onClearAnnotations([], []);

        api.close          = @() close(fig);
        varargout{1}       = api;
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onOpenFiles — Browse for image files via uigetfile
    % ════════════════════════════════════════════════════════════════════
    function onOpenFiles(~, ~)
        filterSpec = { ...
            '*.tif;*.tiff;*.raw;*.dm3;*.dm4', 'Image Files (*.tif, *.tiff, *.raw, *.dm3, *.dm4)'; ...
            '*.tif;*.tiff',                   'TIFF Files (*.tif, *.tiff)'; ...
            '*.dm3;*.dm4',                    'Gatan Files (*.dm3, *.dm4)'; ...
            '*.raw',                          'RAW Binary Files (*.raw)'; ...
            '*.*',                            'All Files (*.*)'};

        startDir = appData.lastDir;
        if isempty(startDir) || ~isfolder(startDir)
            startDir = pwd;
        end

        [files, folder] = uigetfile(filterSpec, 'Select Image File(s)', ...
            startDir, 'MultiSelect', 'on');

        if isequal(files, 0)
            return;   % user cancelled
        end

        appData.lastDir = folder;

        % Normalize to cell array
        if ischar(files)
            files = {files};
        end

        % Build full paths
        fpaths = cellfun(@(f) fullfile(folder, f), files, 'UniformOutput', false);

        loadImagesFromPaths(fpaths);
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onRemoveImage — Remove selected image(s) from the list
    % ════════════════════════════════════════════════════════════════════
    function onRemoveImage(~, ~)
        if isempty(appData.images)
            return;
        end

        % Get selected indices from listbox
        selVals = lbImages.Value;
        if iscell(selVals)
            selIdx = [selVals{:}];
        else
            selIdx = selVals;
        end

        % Filter out invalid indices (e.g., the placeholder 0)
        selIdx = selIdx(selIdx > 0 & selIdx <= numel(appData.images));
        if isempty(selIdx)
            return;
        end

        % Remove selected images
        appData.images(selIdx) = [];

        % Update active index
        if isempty(appData.images)
            appData.activeIdx = 0;
        elseif appData.activeIdx > numel(appData.images)
            appData.activeIdx = numel(appData.images);
        elseif any(selIdx == appData.activeIdx)
            appData.activeIdx = min(appData.activeIdx, numel(appData.images));
            if appData.activeIdx == 0 && ~isempty(appData.images)
                appData.activeIdx = 1;
            end
        end

        % Exit compare mode if fewer than 2 images remain
        if numel(appData.images) < 2 && appData.compareMode
            btnCompare.Value = false;
            exitCompareMode();
        end
        btnCompare.Enable = onOff(numel(appData.images) >= 2);

        rebuildImageList();

        if appData.activeIdx > 0
            displayImage();
        else
            clearDisplay();
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onSelectImage — Handle listbox selection change
    % ════════════════════════════════════════════════════════════════════
    function onSelectImage(~, ~)
        selVals = lbImages.Value;
        if iscell(selVals)
            idx = selVals{1};   % display the first selected item
        else
            idx = selVals;
        end

        if idx < 1 || idx > numel(appData.images)
            return;
        end

        appData.activeIdx = idx;

        % In compare mode, update the active panel instead
        if appData.compareMode
            if appData.compareActivePanel == 'L'
                appData.compareIdxL = idx;
                displayCompareImage('L');
            else
                appData.compareIdxR = idx;
                displayCompareImage('R');
            end
            return;
        end

        displayImage();
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onZoomFit — Reset axes limits to show the full image
    % ════════════════════════════════════════════════════════════════════
    function onZoomFit(~, ~)
        if appData.activeIdx < 1 || isempty(appData.rawPixels)
            return;
        end
        [H, W] = size(appData.rawPixels);
        ax.XLim = [0.5, W + 0.5];
        ax.YLim = [0.5, H + 0.5];
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onZoomActual — Zoom to 1:1 pixel ratio, centred on view
    % ════════════════════════════════════════════════════════════════════
    function onZoomActual(~, ~)
        if appData.activeIdx < 1 || isempty(appData.rawPixels)
            return;
        end

        [H, W] = size(appData.rawPixels);

        % Get the axes size in pixels to determine how many image pixels fit
        axPos = getpixelposition(ax, true);
        axW_px = axPos(3);
        axH_px = axPos(4);

        % Current view centre
        cx = mean(ax.XLim);
        cy = mean(ax.YLim);

        % At 1:1 ratio, the view should span axW_px image pixels wide
        halfW = axW_px / 2;
        halfH = axH_px / 2;

        newXLim = [cx - halfW, cx + halfW];
        newYLim = [cy - halfH, cy + halfH];

        % Clamp to image bounds
        if newXLim(1) < 0.5
            newXLim = [0.5, 0.5 + axW_px];
        end
        if newXLim(2) > W + 0.5
            newXLim = [W + 0.5 - axW_px, W + 0.5];
        end
        if newYLim(1) < 0.5
            newYLim = [0.5, 0.5 + axH_px];
        end
        if newYLim(2) > H + 0.5
            newYLim = [H + 0.5 - axH_px, H + 0.5];
        end

        ax.XLim = newXLim;
        ax.YLim = newYLim;
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onMouseMotion — Track mouse over axes, show pixel info
    % ════════════════════════════════════════════════════════════════════
    function onMouseMotion(~, ~)
        % In compare mode, ax may not exist
        if isempty(ax) || ~isvalid(ax)
            return;
        end
        % If no image is loaded, nothing to show
        if appData.activeIdx < 1 || isempty(appData.rawPixels)
            lblStatusMouse.Text = '';
            return;
        end

        [H, W] = size(appData.rawPixels);

        % Get mouse position in data coordinates
        cp = ax.CurrentPoint;
        xData = cp(1, 1);
        yData = cp(1, 2);

        % Check if mouse is within axes limits
        if xData < ax.XLim(1) || xData > ax.XLim(2) || ...
           yData < ax.YLim(1) || yData > ax.YLim(2)
            lblStatusMouse.Text = '';
            return;
        end

        % Convert to nearest integer pixel coordinate
        col = round(xData);
        row = round(yData);

        % Check if within image bounds
        if col < 1 || col > W || row < 1 || row > H
            lblStatusMouse.Text = '';
            return;
        end

        % Read raw pixel intensity (before contrast adjustment)
        intensity = appData.rawPixels(row, col);

        % Format based on data type (integer vs float)
        if intensity == floor(intensity) && abs(intensity) < 1e7
            lblStatusMouse.Text = sprintf('(%d, %d) = %d', col, row, round(intensity));
        else
            lblStatusMouse.Text = sprintf('(%d, %d) = %.4g', col, row, intensity);
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onFigureClose — Clean up and close the figure
    % ════════════════════════════════════════════════════════════════════
    function onFigureClose(~, ~)
        delete(fig);
    end

    % ════════════════════════════════════════════════════════════════════
    %  CORE RENDER: displayImage — Render the active image to axes
    % ════════════════════════════════════════════════════════════════════
    function displayImage()
        if appData.compareMode
            return;   % in compare mode, use displayCompareImage instead
        end
        if appData.activeIdx < 1 || appData.activeIdx > numel(appData.images)
            clearDisplay();
            return;
        end

        dataStruct = appData.images{appData.activeIdx};
        imgInfo    = dataStruct.metadata.parserSpecific.imageData;
        pixels     = imgInfo.pixels;

        % Convert to grayscale double (raw, unprocessed)
        if imgInfo.numChannels == 3
            % RGB: convert to luminance for grayscale display
            pixDouble = double(pixels);
            rawGray = 0.299 * pixDouble(:,:,1) + ...
                      0.587 * pixDouble(:,:,2) + ...
                      0.114 * pixDouble(:,:,3);
        else
            rawGray = double(pixels);
        end

        % Store the image pipeline state
        appData.rawPixels      = rawGray;
        appData.filteredPixels = rawGray;

        % Set slider ranges based on actual data range
        dMin = min(rawGray(:));
        dMax = max(rawGray(:));
        if dMax == dMin
            dMax = dMin + 1;   % avoid degenerate range
        end

        sldLow.Limits  = [dMin, dMax];
        sldHigh.Limits = [dMin, dMax];

        % Auto-contrast by default: 2nd/98th percentile (no Statistics Toolbox)
        pLow  = percentileNoToolbox(rawGray(:), 2);
        pHigh = percentileNoToolbox(rawGray(:), 98);
        if pLow >= pHigh
            pLow  = dMin;
            pHigh = dMax;
        end
        sldLow.Value  = pLow;
        sldHigh.Value = pHigh;

        [H, W] = size(rawGray);

        % Cancel any in-progress capture before clearing
        if ~isempty(appData.captureMode)
            cancelCapture();
        end

        % Clear all overlays (switches image context — old overlays no longer valid)
        clearAllOverlays();

        % Clear the axes and create fresh imagesc (resets zoom on image switch)
        if isempty(ax) || ~isvalid(ax), return; end
        delete(ax.Children);
        cla(ax);

        % Compute initial contrast-adjusted image
        dispImg = imaging.adjustContrast(rawGray, Low=pLow, High=pHigh);
        appData.displayImg = dispImg;

        hImg = imagesc(ax, 'XData', [1 W], 'YData', [1 H], 'CData', dispImg);
        appData.imgHandle = hImg;

        % Apply selected colormap
        cmapName = ddColormap.Value;
        colormap(ax, feval(cmapName, 256));
        ax.CLim = [0 1];

        ax.YDir = 'reverse';
        axis(ax, 'equal');
        ax.XLim = [0.5, W + 0.5];
        ax.YLim = [0.5, H + 0.5];
        ax.XTick = [];
        ax.YTick = [];
        title(ax, '');
        xlabel(ax, '');
        ylabel(ax, '');
        ax.Toolbar.Visible = 'off';

        % Update filename label in toolbar
        [~, fname, fext] = fileparts(dataStruct.metadata.source);
        lblFilename.Text = [fname, fext];

        % Update metadata panel, status bar, and histogram
        updateMetadataPanel();
        updateStatusBar();
        updateHistogram();

        % Enable measurement controls; scale bar only when calibrated
        imgInfo2 = dataStruct.metadata.parserSpecific.imageData;
        isCalib  = imgInfo2.calibrated && ~isnan(imgInfo2.pixelSize);
        cbScaleBar.Enable       = onOff(isCalib);
        cbScaleBar.Value        = isCalib;   % on by default when calibrated
        btnScaleBarColor.Enable = onOff(isCalib);
        spnScaleBarFont.Enable  = onOff(isCalib);
        if isCalib
            rebuildScaleBar();
        end
        btnLineProfile.Enable   = 'on';
        btnDistance.Enable      = 'on';
        btnClearOverlays.Enable = 'on';

        % Enable processing controls
        btnGaussian.Enable    = 'on';
        btnMedian.Enable      = 'on';
        btnShowFFT.Enable     = 'on';
        btnUndoFilters.Enable = 'on';
        btnZoomBox.Enable     = 'on';
        btnResetZoom.Enable   = 'on';
        btnCropImage.Enable   = 'on';
        btnSaveCrop.Enable    = 'on';
        btnSaveImage.Enable   = 'on';

        % Enable annotation controls
        btnPlaceAnnot.Enable  = 'on';
        btnClearAnnot.Enable  = 'on';
        btnAnnotColor.Enable  = 'on';
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: clearDisplay — Clear the axes and reset status when no image
    % ════════════════════════════════════════════════════════════════════
    function clearDisplay()
        appData.rawPixels      = [];
        appData.filteredPixels = [];
        appData.preCropPixels  = [];
        appData.displayImg     = [];
        appData.imgHandle      = [];
        if ~isempty(ax) && isvalid(ax)
            delete(ax.Children);
            cla(ax);
        end
        if ~isempty(ax) && isvalid(ax)
            ax.XTick = [];
            ax.YTick = [];
            title(ax, 'Open an image file to begin', 'Interpreter', 'none');
            colormap(ax, gray(256));
            ax.Toolbar.Visible = 'off';
        end

        lblFilename.Text      = '(no image loaded)';
        lblStatusDims.Text    = '-- x -- px';
        lblStatusBits.Text    = '--bit';
        lblStatusPixSize.Text = 'uncalibrated';
        lblStatusMouse.Text   = '';
        taMetadata.Value      = {'(no image loaded)'};

        % Disable processing controls
        btnGaussian.Enable    = 'off';
        btnMedian.Enable      = 'off';
        btnShowFFT.Enable     = 'off';
        btnUndoFilters.Enable = 'off';
        btnZoomBox.Enable     = 'off';
        btnResetZoom.Enable   = 'off';
        btnCropImage.Enable   = 'off';
        btnSaveCrop.Enable    = 'off';
        btnSaveImage.Enable   = 'off';

        % Disable annotation controls
        btnPlaceAnnot.Enable  = 'off';
        btnClearAnnot.Enable  = 'off';
        btnAnnotColor.Enable  = 'off';

        % Clear histogram
        cla(histAx);
        histAx.XLim = [0 1];
        histAx.YLim = [0 1];
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: updateStatusBar — Refresh status bar labels from active image
    % ════════════════════════════════════════════════════════════════════
    function updateStatusBar()
        if appData.activeIdx < 1 || appData.activeIdx > numel(appData.images)
            lblStatusDims.Text    = '-- x -- px';
            lblStatusBits.Text    = '--bit';
            lblStatusPixSize.Text = 'uncalibrated';
            lblStatusMouse.Text   = '';
            return;
        end

        imgInfo = appData.images{appData.activeIdx}.metadata.parserSpecific.imageData;

        % Dimensions
        lblStatusDims.Text = sprintf('%d x %d px', imgInfo.width, imgInfo.height);

        % Bit depth
        lblStatusBits.Text = sprintf('%d-bit', imgInfo.bitDepth);

        % Pixel size
        if imgInfo.calibrated && ~isnan(imgInfo.pixelSize)
            lblStatusPixSize.Text = sprintf('%.4g %s/px', imgInfo.pixelSize, imgInfo.pixelUnit);
        else
            lblStatusPixSize.Text = 'uncalibrated';
        end

        % Mouse position is updated dynamically in onMouseMotion
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: updateMetadataPanel — Populate metadata text area
    % ════════════════════════════════════════════════════════════════════
    function updateMetadataPanel()
        if appData.activeIdx < 1 || appData.activeIdx > numel(appData.images)
            taMetadata.Value = {'(no image loaded)'};
            return;
        end

        dataStruct = appData.images{appData.activeIdx};
        imgInfo    = dataStruct.metadata.parserSpecific.imageData;
        lines      = {};

        % Source file
        [~, fname, fext] = fileparts(dataStruct.metadata.source);
        lines{end+1} = sprintf('File:   %s%s', fname, fext);
        lines{end+1} = sprintf('Parser: %s', dataStruct.metadata.parserName);
        lines{end+1} = '';

        % Dimensions
        lines{end+1} = sprintf('Width:  %d px', imgInfo.width);
        lines{end+1} = sprintf('Height: %d px', imgInfo.height);
        lines{end+1} = sprintf('Depth:  %d-bit', imgInfo.bitDepth);
        lines{end+1} = sprintf('Chans:  %d', imgInfo.numChannels);
        lines{end+1} = sprintf('Frames: %d', imgInfo.numFrames);
        lines{end+1} = '';

        % Calibration
        if imgInfo.calibrated && ~isnan(imgInfo.pixelSize)
            lines{end+1} = sprintf('Pixel:  %.4g %s', imgInfo.pixelSize, imgInfo.pixelUnit);
        else
            lines{end+1} = 'Pixel:  uncalibrated';
        end
        lines{end+1} = '';

        % Acquisition parameters (instrument metadata)
        if isstruct(imgInfo.acquiParams) && ~isempty(fieldnames(imgInfo.acquiParams))
            lines{end+1} = '── Acquisition ──';

            % FEI metadata (nested structs for sections)
            if isfield(imgInfo.acquiParams, 'feiMetadata')
                fei = imgInfo.acquiParams.feiMetadata;
                sections = fieldnames(fei);
                for si = 1:numel(sections)
                    sec = sections{si};
                    secData = fei.(sec);
                    if ~isstruct(secData)
                        continue;
                    end
                    lines{end+1} = sprintf('[%s]', sec); %#ok<AGROW>
                    keys = fieldnames(secData);
                    for ki = 1:numel(keys)
                        k = keys{ki};
                        v = secData.(k);
                        if ischar(v) || isstring(v)
                            lines{end+1} = sprintf('  %s: %s', k, v); %#ok<AGROW>
                        elseif isnumeric(v)
                            lines{end+1} = sprintf('  %s: %g', k, v); %#ok<AGROW>
                        end
                    end
                end
            else
                % Flat acquisition params (non-FEI)
                keys = fieldnames(imgInfo.acquiParams);
                for ki = 1:numel(keys)
                    k = keys{ki};
                    v = imgInfo.acquiParams.(k);
                    if ischar(v) || isstring(v)
                        lines{end+1} = sprintf('  %s: %s', k, v); %#ok<AGROW>
                    elseif isnumeric(v) && isscalar(v)
                        lines{end+1} = sprintf('  %s: %g', k, v); %#ok<AGROW>
                    end
                end
            end
        end

        taMetadata.Value = lines;
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: rebuildImageList — Sync the listbox with appData.images
    % ════════════════════════════════════════════════════════════════════
    function rebuildImageList()
        if isempty(appData.images)
            lbImages.Items     = {'(no images loaded)'};
            lbImages.ItemsData = {0};
            return;
        end

        items = cell(1, numel(appData.images));
        idata = cell(1, numel(appData.images));
        for k = 1:numel(appData.images)
            [~, fname, fext] = fileparts(appData.images{k}.metadata.source);
            items{k} = [fname, fext];
            idata{k} = k;
        end

        lbImages.Items     = items;
        lbImages.ItemsData = idata;

        % Restore selection to active index
        if appData.activeIdx >= 1 && appData.activeIdx <= numel(appData.images)
            lbImages.Value = {appData.activeIdx};
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: loadImagesFromPaths — Load files and add to appData.images
    % ════════════════════════════════════════════════════════════════════
    function loadImagesFromPaths(fpaths)
        if ischar(fpaths)
            fpaths = {fpaths};
        end

        loadedAny = false;

        for k = 1:numel(fpaths)
            fp = fpaths{k};

            [~, ~, ext] = fileparts(fp);
            ext = lower(ext);

            try
                switch ext
                    case {'.tif', '.tiff'}
                        data = parser.importTIFF(fp);
                        appendImage(data);
                        loadedAny = true;

                    case '.raw'
                        % RAW files need dimensions from user
                        data = promptAndLoadRaw(fp);
                        if ~isempty(data)
                            appendImage(data);
                            loadedAny = true;
                        end

                    case {'.dm3', '.dm4'}
                        data = parser.importDM3(fp);
                        appendImage(data);
                        loadedAny = true;

                    otherwise
                        uialert(fig, ...
                            sprintf('Unsupported file format: "%s"\n\nSupported: .tif, .tiff, .raw, .dm3, .dm4', ext), ...
                            'Unsupported Format', 'Icon', 'warning');
                end
            catch ME
                uialert(fig, ...
                    sprintf('Failed to load "%s":\n\n%s', fp, ME.message), ...
                    'Load Error', 'Icon', 'error');
            end
        end

        if loadedAny
            rebuildImageList();
            displayImage();
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: promptAndLoadRaw — Show input dialog for RAW file params
    % ════════════════════════════════════════════════════════════════════
    function data = promptAndLoadRaw(fp)
        data = [];

        [~, fname, fext] = fileparts(fp);
        prompt  = {'Width (pixels):', 'Height (pixels):', 'Bit Depth (8, 16, or 32):'};
        dlgTitle = sprintf('RAW Image Parameters — %s%s', fname, fext);
        defaults = {'512', '512', '16'};

        answer = inputdlg(prompt, dlgTitle, [1 40], defaults);
        if isempty(answer)
            return;   % user cancelled
        end

        W = str2double(answer{1});
        H = str2double(answer{2});
        B = str2double(answer{3});

        if isnan(W) || isnan(H) || isnan(B) || W < 1 || H < 1
            uialert(fig, 'Invalid dimensions. Width and Height must be positive integers.', ...
                'Invalid Input', 'Icon', 'error');
            return;
        end

        if ~ismember(B, [8 16 32])
            uialert(fig, 'BitDepth must be 8, 16, or 32.', ...
                'Invalid Input', 'Icon', 'error');
            return;
        end

        data = parser.importRawImage(fp, Width=W, Height=H, BitDepth=B);
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: appendImage — Add a parsed data struct to appData.images
    % ════════════════════════════════════════════════════════════════════
    function appendImage(data)
        appData.images{end+1} = data;
        appData.activeIdx = numel(appData.images);
        btnCompare.Enable = onOff(numel(appData.images) >= 2);
    end

    % ════════════════════════════════════════════════════════════════════
    %  API: getImagesAPI / getActiveIdxAPI — nested-function accessors
    %  (Anonymous functions capture a snapshot; nested functions share
    %   the workspace by reference, so these always return current state.)
    % ════════════════════════════════════════════════════════════════════
    function imgs = getImagesAPI()
        imgs = appData.images;
    end

    function idx = getActiveIdxAPI()
        idx = appData.activeIdx;
    end

    % ════════════════════════════════════════════════════════════════════
    %  API: loadImagesAPI — Programmatic image loading (for testing)
    % ════════════════════════════════════════════════════════════════════
    function loadImagesAPI(paths)
    %LOADIMAGESAPI  Load images programmatically from a cell array of paths.
    %   For TIFF files, provide a string path.
    %   For RAW files, provide a struct with fields: path, Width, Height, BitDepth.
        if ischar(paths) || isstring(paths)
            paths = {paths};
        end

        loadedAny = false;
        for k = 1:numel(paths)
            entry = paths{k};

            try
                if isstruct(entry)
                    % RAW file with explicit dimensions
                    rawPath = entry.path;
                    data = parser.importRawImage(rawPath, ...
                        Width=entry.Width, Height=entry.Height, ...
                        BitDepth=entry.BitDepth);
                    appendImage(data);
                    loadedAny = true;
                elseif ischar(entry) || isstring(entry)
                    fp = char(entry);
                    [~, ~, ext] = fileparts(fp);
                    ext = lower(ext);

                    switch ext
                        case {'.tif', '.tiff'}
                            data = parser.importTIFF(fp);
                            appendImage(data);
                            loadedAny = true;
                        case {'.dm3', '.dm4'}
                            data = parser.importDM3(fp);
                            appendImage(data);
                            loadedAny = true;
                        case '.raw'
                            error('emViewerGUI:rawNeedsStruct', ...
                                ['RAW files in API mode require a struct with ' ...
                                 'fields: path, Width, Height, BitDepth.']);
                        otherwise
                            warning('emViewerGUI:unsupported', ...
                                'Unsupported format: %s', ext);
                    end
                end
            catch ME
                warning('emViewerGUI:loadFailed', ...
                    'Failed to load entry %d: %s', k, ME.message);
            end
        end

        if loadedAny
            rebuildImageList();
            displayImage();
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  API: setActiveIdxAPI — Switch to a specific image by index
    % ════════════════════════════════════════════════════════════════════
    function setActiveIdxAPI(idx)
        if idx < 1 || idx > numel(appData.images)
            warning('emViewerGUI:invalidIdx', ...
                'Index %d is out of range [1, %d].', idx, numel(appData.images));
            return;
        end
        appData.activeIdx = idx;

        % Update listbox selection
        if ~isempty(lbImages.ItemsData) && ...
                ~isequal(lbImages.ItemsData, {0})
            lbImages.Value = {idx};
        end

        displayImage();
    end

    % ════════════════════════════════════════════════════════════════════
    %  STUB: stubNotImplemented — Placeholder for future phase features
    % ════════════════════════════════════════════════════════════════════
    function varargout = stubNotImplemented(funcName)
        warning('emViewerGUI:notImplemented', ...
            '%s is not yet implemented (scheduled for a later phase).', funcName);
        if nargout > 0
            varargout{1} = [];
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onContrastChanged — Slider moved; update CData in-place
    % ════════════════════════════════════════════════════════════════════
    function onContrastChanged(src, ~)
        if isempty(appData.filteredPixels) || isempty(appData.imgHandle) || ...
                ~isvalid(appData.imgHandle)
            return;
        end

        lo = sldLow.Value;
        hi = sldHigh.Value;

        % Enforce lo < hi — determine which slider moved by checking the source
        if lo >= hi
            span = sldLow.Limits(2) - sldLow.Limits(1);
            eps  = span * 0.001;
            if ~isempty(src) && isequal(src, sldLow)
                % Low slider moved up past High — clamp just below High
                lo = max(sldLow.Limits(1), hi - eps);
                sldLow.Value = lo;
            else
                % High slider moved below Low — clamp just above Low
                hi = min(sldHigh.Limits(2), lo + eps);
                sldHigh.Value = hi;
            end
        end

        dispImg = imaging.adjustContrast(appData.filteredPixels, Low=lo, High=hi);
        appData.displayImg = dispImg;

        % Update CData without recreating imagesc (preserves zoom/pan state)
        appData.imgHandle.CData = dispImg;

        % Update histogram contrast lines
        updateHistogramLines(lo, hi);
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onAutoContrast — Stretch to 2nd/98th percentile
    % ════════════════════════════════════════════════════════════════════
    function onAutoContrast(~, ~)
        if isempty(appData.filteredPixels)
            return;
        end

        pLow  = percentileNoToolbox(appData.filteredPixels(:), 2);
        pHigh = percentileNoToolbox(appData.filteredPixels(:), 98);

        % Guard against degenerate case
        if pLow >= pHigh
            pLow  = sldLow.Limits(1);
            pHigh = sldHigh.Limits(2);
        end

        sldLow.Value  = pLow;
        sldHigh.Value = pHigh;

        onContrastChanged([], []);
        setStatus(sprintf('Auto contrast: [%.4g, %.4g]', pLow, pHigh));
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onResetContrast — Full range (min to max of raw pixels)
    % ════════════════════════════════════════════════════════════════════
    function onResetContrast(~, ~)
        if isempty(appData.filteredPixels)
            return;
        end

        dMin = sldLow.Limits(1);
        dMax = sldHigh.Limits(2);

        sldLow.Value  = dMin;
        sldHigh.Value = dMax;

        onContrastChanged([], []);
        setStatus('Contrast reset to full range.');
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onColormapChanged — Apply selected colormap to axes
    % ════════════════════════════════════════════════════════════════════
    function onColormapChanged(~, ~)
        if appData.activeIdx < 1
            return;
        end
        cmapName = ddColormap.Value;
        colormap(ax, feval(cmapName, 256));
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onGaussianFilter — Prompt for sigma and apply Gaussian blur
    % ════════════════════════════════════════════════════════════════════
    function onGaussianFilter(~, ~)
        if isempty(appData.filteredPixels)
            return;
        end

        answer = inputdlg({'Sigma (pixels):  [positive number, e.g. 1.5]'}, ...
            'Gaussian Filter', [1 44], {'1.5'});
        if isempty(answer)
            return;   % user cancelled
        end

        sigma = str2double(answer{1});
        if isnan(sigma) || sigma <= 0
            uialert(fig, 'Sigma must be a positive number.', ...
                'Invalid Input', 'Icon', 'error');
            return;
        end

        fig.Pointer = 'watch';
        drawnow;

        try
            appData.filteredPixels = imaging.applyGaussian( ...
                appData.filteredPixels, Sigma=sigma);
            refreshDisplay();
            setStatus(sprintf('Gaussian filter applied (sigma = %.2g px)', sigma));
        catch ME
            uialert(fig, sprintf('Gaussian filter failed:\n%s', ME.message), ...
                'Filter Error', 'Icon', 'error');
        end

        fig.Pointer = 'arrow';
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onMedianFilter — Prompt for window size and apply median
    % ════════════════════════════════════════════════════════════════════
    function onMedianFilter(~, ~)
        if isempty(appData.filteredPixels)
            return;
        end

        answer = inputdlg({'Window size (3, 5, or 7):'}, ...
            'Median Filter', [1 36], {'3'});
        if isempty(answer)
            return;   % user cancelled
        end

        wSize = round(str2double(answer{1}));
        if isnan(wSize) || ~ismember(wSize, [3 5 7])
            uialert(fig, 'Window size must be 3, 5, or 7.', ...
                'Invalid Input', 'Icon', 'error');
            return;
        end

        fig.Pointer = 'watch';
        drawnow;

        try
            appData.filteredPixels = imaging.applyMedian( ...
                appData.filteredPixels, WindowSize=wSize);
            refreshDisplay();
            setStatus(sprintf('Median filter applied (%dx%d window)', wSize, wSize));
        catch ME
            uialert(fig, sprintf('Median filter failed:\n%s', ME.message), ...
                'Filter Error', 'Icon', 'error');
        end

        fig.Pointer = 'arrow';
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onShowFFT — Compute and display FFT magnitude in new figure
    % ════════════════════════════════════════════════════════════════════
    function onShowFFT(~, ~)
        if isempty(appData.filteredPixels)
            return;
        end

        fig.Pointer = 'watch';
        drawnow;

        magImg = imaging.computeFFT(appData.filteredPixels);

        fig.Pointer = 'arrow';

        % Get filename for title
        if appData.activeIdx >= 1
            [~, fname, fext] = fileparts( ...
                appData.images{appData.activeIdx}.metadata.source);
            titleStr = sprintf('FFT — %s%s', fname, fext);
        else
            titleStr = 'FFT';
        end

        fftFig = figure('Name', titleStr, 'NumberTitle', 'off', ...
            'Units', 'pixels', 'Position', [220 180 600 520]);
        fftAx = axes(fftFig);
        imagesc(fftAx, magImg);
        colormap(fftFig, parula(256));
        colorbar(fftAx);
        axis(fftAx, 'image');
        fftAx.XTick = [];
        fftAx.YTick = [];
        title(fftAx, titleStr, 'Interpreter', 'none');

        setStatus('FFT displayed in new figure.');
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onUndoFilters — Revert filteredPixels back to rawPixels
    % ════════════════════════════════════════════════════════════════════
    function onUndoFilters(~, ~)
        if isempty(appData.rawPixels)
            return;
        end

        % If a crop was applied, restore the pre-crop original
        if ~isempty(appData.preCropPixels)
            appData.rawPixels     = appData.preCropPixels;
            appData.preCropPixels = [];
        end

        appData.filteredPixels = appData.rawPixels;
        refreshDisplay();
        setStatus('Filters undone — reverted to original image.');
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onSaveImage — Save current displayImg to PNG or TIFF
    % ════════════════════════════════════════════════════════════════════
    function onSaveImage(~, ~)
        if isempty(appData.displayImg)
            uialert(fig, 'No image to save.', 'No Image', 'Icon', 'warning');
            return;
        end

        % Suggest default filename from active image
        if appData.activeIdx >= 1
            [~, bname] = fileparts( ...
                appData.images{appData.activeIdx}.metadata.source);
            defName = [bname '_processed.tif'];
        else
            defName = 'em_image.tif';
        end

        startPath = appData.lastDir;
        if isempty(startPath) || ~isfolder(startPath)
            startPath = pwd;
        end

        [saveName, saveDir] = uiputfile( ...
            {'*.tif;*.tiff', 'TIFF (*.tif, *.tiff)'; ...
             '*.png',        'PNG (*.png)'}, ...
            'Save Processed Image As', ...
            fullfile(startPath, defName));

        if isequal(saveName, 0)
            return;   % user cancelled
        end

        outPath = fullfile(saveDir, saveName);
        [~, ~, ext] = fileparts(outPath);
        ext = lower(ext);

        fig.Pointer = 'watch';
        drawnow;

        try
            dispImg = appData.displayImg;   % [0,1] double
            if strcmp(ext, '.png')
                % Scale to uint8 for PNG
                imwrite(uint8(dispImg * 255), outPath);
            else
                % Scale to uint16 for TIFF (better precision)
                imwrite(uint16(dispImg * 65535), outPath);
            end
            setStatus(sprintf('Saved: %s', saveName));
        catch ME
            uialert(fig, sprintf('Save failed:\n%s', ME.message), ...
                'Save Error', 'Icon', 'error');
        end

        fig.Pointer = 'arrow';
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onZoomBox — Draw rectangle to zoom into a region
    % ════════════════════════════════════════════════════════════════════
    function onZoomBox(~, ~)
        if appData.activeIdx < 1 || isempty(appData.displayImg)
            return;
        end
        startRectCapture('zoom');
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onResetZoom — Reset axes limits to full image
    % ════════════════════════════════════════════════════════════════════
    function onResetZoom(~, ~)
        if isempty(appData.displayImg)
            return;
        end
        [H, W] = size(appData.displayImg);
        ax.XLim = [0.5 W+0.5];
        ax.YLim = [0.5 H+0.5];
        setStatus('Zoom reset.');
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onCropImage — Draw rectangle to crop image
    % ════════════════════════════════════════════════════════════════════
    function onCropImage(~, ~)
        if appData.activeIdx < 1 || isempty(appData.displayImg)
            return;
        end
        startRectCapture('crop');
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onSaveCrop — Draw rectangle and save cropped region
    % ════════════════════════════════════════════════════════════════════
    function onSaveCrop(~, ~)
        if appData.activeIdx < 1 || isempty(appData.displayImg)
            return;
        end
        startRectCapture('savecrop');
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: startRectCapture — Two-click rectangle selection
    % ════════════════════════════════════════════════════════════════════
    function startRectCapture(mode)
        if ~isempty(appData.captureMode)
            cancelCapture();
        end

        appData.captureMode   = mode;
        appData.captureClicks = [];

        fig.Pointer = 'crosshair';
        fig.WindowButtonDownFcn = @onRectClick;

        switch mode
            case 'zoom'
                setStatus('Click first corner for zoom region... (Esc to cancel)');
            case 'crop'
                setStatus('Click first corner of crop region... (Esc to cancel)');
            case 'savecrop'
                setStatus('Click first corner of region to save... (Esc to cancel)');
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onRectClick — Handle clicks during rectangle selection
    % ════════════════════════════════════════════════════════════════════
    function onRectClick(~, ~)
        if ~ismember(appData.captureMode, {'zoom', 'crop', 'savecrop'})
            return;
        end

        cp = ax.CurrentPoint;
        x  = cp(1, 1);
        y  = cp(1, 2);

        % Clamp to image bounds
        [H, W] = size(appData.displayImg);
        x = max(0.5, min(W + 0.5, x));
        y = max(0.5, min(H + 0.5, y));

        appData.captureClicks(end+1, :) = [x, y];

        if size(appData.captureClicks, 1) == 1
            % First click — draw live preview rectangle
            hRect = rectangle(ax, 'Position', [x y 1 1], ...
                'EdgeColor', OVERLAY_COLOR, ...
                'LineWidth', 1.5, ...
                'LineStyle', '--', ...
                'HandleVisibility', 'off');
            appData.overlays.clickMarkers{end+1} = hRect;

            % Attach motion callback for live rubber-band
            fig.WindowButtonMotionFcn = @(~,~) updateRectPreview(hRect, ...
                appData.captureClicks(1,1), appData.captureClicks(1,2));

            switch appData.captureMode
                case 'zoom'
                    setStatus('Click second corner to zoom... (Esc to cancel)');
                case 'crop'
                    setStatus('Click second corner to crop... (Esc to cancel)');
                case 'savecrop'
                    setStatus('Click second corner to save... (Esc to cancel)');
            end

        elseif size(appData.captureClicks, 1) >= 2
            % Both corners collected
            x1 = appData.captureClicks(1, 1);
            y1 = appData.captureClicks(1, 2);
            x2 = appData.captureClicks(2, 1);
            y2 = appData.captureClicks(2, 2);

            mode = appData.captureMode;

            % Clean up preview rectangle and restore callbacks
            fig.WindowButtonMotionFcn = @onMouseMotion;
            for ci = 1:numel(appData.overlays.clickMarkers)
                h = appData.overlays.clickMarkers{ci};
                if isvalid(h), delete(h); end
            end
            appData.overlays.clickMarkers = {};
            finishCapture();

            % Normalize to [xMin xMax yMin yMax]
            xMin = max(1, floor(min(x1, x2)));
            xMax = min(size(appData.displayImg, 2), ceil(max(x1, x2)));
            yMin = max(1, floor(min(y1, y2)));
            yMax = min(size(appData.displayImg, 1), ceil(max(y1, y2)));

            if xMax - xMin < 2 || yMax - yMin < 2
                setStatus('Selection too small — cancelled.');
                return;
            end

            switch mode
                case 'zoom'
                    ax.XLim = [xMin - 0.5, xMax + 0.5];
                    ax.YLim = [yMin - 0.5, yMax + 0.5];
                    setStatus(sprintf('Zoomed to [%d:%d, %d:%d]', ...
                        xMin, xMax, yMin, yMax));

                case 'crop'
                    % Save pre-crop state so Undo Filters can restore it
                    appData.preCropPixels  = appData.rawPixels;
                    appData.rawPixels      = appData.rawPixels(yMin:yMax, xMin:xMax);
                    appData.filteredPixels = appData.filteredPixels(yMin:yMax, xMin:xMax);
                    refreshDisplay();
                    setStatus(sprintf('Cropped to %dx%d px', ...
                        xMax - xMin + 1, yMax - yMin + 1));

                case 'savecrop'
                    saveCroppedRegion(xMin, xMax, yMin, yMax);
            end
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: updateRectPreview — Update rubber-band rectangle on motion
    % ════════════════════════════════════════════════════════════════════
    function updateRectPreview(hRect, x0, y0)
        if ~isvalid(hRect), return; end
        cp = ax.CurrentPoint;
        cx = cp(1,1);
        cy = cp(1,2);
        rx = min(x0, cx);
        ry = min(y0, cy);
        rw = abs(cx - x0);
        rh = abs(cy - y0);
        if rw < 0.5, rw = 0.5; end
        if rh < 0.5, rh = 0.5; end
        hRect.Position = [rx ry rw rh];
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: saveCroppedRegion — Save a rectangular crop, blocking
    %  overwrite of the original source file
    % ════════════════════════════════════════════════════════════════════
    function saveCroppedRegion(xMin, xMax, yMin, yMax)
        % Build default filename with _crop suffix
        if appData.activeIdx >= 1
            srcPath = appData.images{appData.activeIdx}.metadata.source;
            [srcDir, bname] = fileparts(srcPath);
            defName = [bname '_crop.tif'];
        else
            srcPath = '';
            srcDir  = '';
            defName = 'crop.tif';
        end

        startPath = appData.lastDir;
        if isempty(startPath) || ~isfolder(startPath)
            if ~isempty(srcDir) && isfolder(srcDir)
                startPath = srcDir;
            else
                startPath = pwd;
            end
        end

        [saveName, saveDir] = uiputfile( ...
            {'*.tif;*.tiff', 'TIFF (*.tif, *.tiff)'; ...
             '*.png',        'PNG (*.png)'}, ...
            'Save Cropped Region As', ...
            fullfile(startPath, defName));

        if isequal(saveName, 0)
            setStatus('Save cancelled.');
            return;
        end

        outPath = fullfile(saveDir, saveName);

        % Block overwrite of original source file (pure-MATLAB, no Java)
        if ~isempty(srcPath)
            srcResolved = lower(fullfile(srcPath));
            outResolved = lower(fullfile(outPath));
            if strcmp(srcResolved, outResolved)
                uialert(fig, ...
                    'Cannot overwrite the original source file. Choose a different name.', ...
                    'Overwrite Blocked', 'Icon', 'warning');
                return;
            end
        end

        [~, ~, ext] = fileparts(outPath);
        ext = lower(ext);

        fig.Pointer = 'watch';
        drawnow;

        try
            % Crop from filteredPixels (includes any applied filters)
            cropPx = appData.filteredPixels(yMin:yMax, xMin:xMax);

            % Scale to display range using current contrast
            lo = sldLow.Value;
            hi = sldHigh.Value;
            if hi <= lo, hi = lo + 1; end
            cropDisp = (cropPx - lo) / (hi - lo);
            cropDisp = max(0, min(1, cropDisp));

            if strcmp(ext, '.png')
                imwrite(uint8(cropDisp * 255), outPath);
            else
                imwrite(uint16(cropDisp * 65535), outPath);
            end
            setStatus(sprintf('Crop saved: %s (%dx%d)', saveName, ...
                xMax - xMin + 1, yMax - yMin + 1));
        catch ME
            uialert(fig, sprintf('Save crop failed:\n%s', ME.message), ...
                'Save Error', 'Icon', 'error');
        end

        fig.Pointer = 'arrow';
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: refreshDisplay — Re-apply contrast to filteredPixels; update
    %  histogram and CData without resetting zoom
    % ════════════════════════════════════════════════════════════════════
    function refreshDisplay()
        if isempty(appData.filteredPixels) || isempty(appData.imgHandle) || ...
                ~isvalid(appData.imgHandle)
            return;
        end

        lo = sldLow.Value;
        hi = sldHigh.Value;

        dispImg = imaging.adjustContrast(appData.filteredPixels, Low=lo, High=hi);
        appData.displayImg = dispImg;
        appData.imgHandle.CData = dispImg;

        updateHistogram();
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: updateHistogram — Draw histogram of raw pixels in histAx
    % ════════════════════════════════════════════════════════════════════
    function updateHistogram()
        if isempty(appData.rawPixels)
            cla(histAx);
            return;
        end

        % Compute histogram of raw (unfiltered) pixels for stable reference
        [counts, edges] = histcounts(double(appData.rawPixels(:)), 256);
        binCenters = (edges(1:end-1) + edges(2:end)) / 2;

        cla(histAx);
        bar(histAx, binCenters, counts, 1, ...
            'FaceColor', [0.5 0.5 0.5], ...
            'EdgeColor', 'none', ...
            'FaceAlpha', 0.8);

        histAx.XTick = [];
        histAx.YTick = [];
        histAx.FontSize = 8;
        histAx.Box = 'on';
        histAx.Toolbar.Visible = 'off';

        % Draw Low/High contrast lines
        if ~isempty(appData.filteredPixels)
            updateHistogramLines(sldLow.Value, sldHigh.Value);
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: updateHistogramLines — Draw/update contrast marker lines
    % ════════════════════════════════════════════════════════════════════
    function updateHistogramLines(lo, hi)
        % Remove old contrast lines (tagged with UserData='contrastLine')
        kids = histAx.Children;
        for ki = numel(kids):-1:1
            h = kids(ki);
            if isvalid(h) && isprop(h, 'UserData') && ...
                    isequal(h.UserData, 'contrastLine')
                delete(h);
            end
        end

        yLim = histAx.YLim;
        if yLim(2) == 0
            yLim(2) = 1;
        end

        % Low line
        hLo = line(histAx, [lo lo], yLim, ...
            'Color',            [1 0.2 0.2], ...
            'LineStyle',        '--', ...
            'LineWidth',        1.5, ...
            'HandleVisibility', 'off');
        hLo.UserData = 'contrastLine';

        % High line
        hHi = line(histAx, [hi hi], yLim, ...
            'Color',            [1 0.2 0.2], ...
            'LineStyle',        '--', ...
            'LineWidth',        1.5, ...
            'HandleVisibility', 'off');
        hHi.UserData = 'contrastLine';
    end

    % ════════════════════════════════════════════════════════════════════
    %  API: setContrastAPI — Programmatic contrast adjustment
    % ════════════════════════════════════════════════════════════════════
    function setContrastAPI(lo, hi)
    %SETCONTRASTAPI  Set Low/High contrast sliders and refresh display.
        if isempty(appData.filteredPixels)
            warning('emViewerGUI:noImage', 'No image loaded.');
            return;
        end

        dMin = sldLow.Limits(1);
        dMax = sldHigh.Limits(2);

        lo = max(dMin, min(dMax, lo));
        hi = max(dMin, min(dMax, hi));

        if lo >= hi
            warning('emViewerGUI:invalidContrast', ...
                'Low must be less than High. Values unchanged.');
            return;
        end

        sldLow.Value  = lo;
        sldHigh.Value = hi;
        onContrastChanged([], []);
    end

    % ════════════════════════════════════════════════════════════════════
    %  API: applyFilterAPI — Programmatic filter application
    % ════════════════════════════════════════════════════════════════════
    function applyFilterAPI(type, params)
    %APPLYFILTERAPI  Apply a named filter programmatically.
    %   api.applyFilter('gaussian', struct('Sigma', 1.5))
    %   api.applyFilter('median',   struct('WindowSize', 3))
        if isempty(appData.filteredPixels)
            warning('emViewerGUI:noImage', 'No image loaded.');
            return;
        end

        switch lower(type)
            case 'gaussian'
                sigma = 1.0;
                if isstruct(params) && isfield(params, 'Sigma')
                    sigma = params.Sigma;
                end
                appData.filteredPixels = imaging.applyGaussian( ...
                    appData.filteredPixels, Sigma=sigma);

            case 'median'
                wSize = 3;
                if isstruct(params) && isfield(params, 'WindowSize')
                    wSize = params.WindowSize;
                end
                appData.filteredPixels = imaging.applyMedian( ...
                    appData.filteredPixels, WindowSize=wSize);

            otherwise
                warning('emViewerGUI:unknownFilter', ...
                    'Unknown filter type "%s". Use ''gaussian'' or ''median''.', type);
                return;
        end

        refreshDisplay();
    end

    % ════════════════════════════════════════════════════════════════════
    %  API: computeFFTAPI — Programmatic FFT computation (no figure)
    % ════════════════════════════════════════════════════════════════════
    function result = computeFFTAPI()
    %COMPUTEFFTAPI  Compute FFT of filtered pixels without opening a figure.
    %   result = api.computeFFT()
    %   Returns struct with .magnitude ([HxW] double) and .phase ([HxW] double).
        result = struct('magnitude', [], 'phase', []);

        if isempty(appData.filteredPixels)
            warning('emViewerGUI:noImage', 'No image loaded.');
            return;
        end

        [mag, ph] = imaging.computeFFT(appData.filteredPixels);
        result.magnitude = mag;
        result.phase     = ph;
    end

    % ════════════════════════════════════════════════════════════════════
    %  API: exportImageAPI — Programmatic image save
    % ════════════════════════════════════════════════════════════════════
    function exportImageAPI(outPath)
    %EXPORTIMAGEAPI  Save the current displayImg to a file path.
    %   api.exportImage('output.tif')  or  api.exportImage('output.png')
        if isempty(appData.displayImg)
            warning('emViewerGUI:noImage', 'No image loaded.');
            return;
        end

        [~, ~, ext] = fileparts(outPath);
        ext = lower(ext);

        dispImg = appData.displayImg;   % [0,1] double
        if strcmp(ext, '.png')
            imwrite(uint8(dispImg * 255), outPath);
        else
            imwrite(uint16(dispImg * 65535), outPath);
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onScaleBarToggle — Add or remove scale bar overlay
    % ════════════════════════════════════════════════════════════════════
    function onScaleBarToggle(~, ~)
        if appData.activeIdx < 1
            return;
        end

        if cbScaleBar.Value
            rebuildScaleBar();
        else
            deleteScaleBar();
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onScaleBarColorToggle — Switch between white and black
    % ════════════════════════════════════════════════════════════════════
    function onScaleBarColorToggle(~, ~)
        % Toggle button state
        if isequal(btnScaleBarColor.FontColor, [1 1 1])
            % Was white → switch to black
            btnScaleBarColor.Text            = 'Black';
            btnScaleBarColor.FontColor       = [0 0 0];
            btnScaleBarColor.BackgroundColor = [0.85 0.85 0.85];
        else
            % Was black → switch to white
            btnScaleBarColor.Text            = 'White';
            btnScaleBarColor.FontColor       = [1 1 1];
            btnScaleBarColor.BackgroundColor = [0.25 0.25 0.25];
        end
        % Rebuild if scale bar is visible
        if cbScaleBar.Value
            rebuildScaleBar();
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onScaleBarFontChange — Update font size
    % ════════════════════════════════════════════════════════════════════
    function onScaleBarFontChange(~, ~)
        if cbScaleBar.Value
            rebuildScaleBar();
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: rebuildScaleBar — Delete and recreate with current settings
    % ════════════════════════════════════════════════════════════════════
    function rebuildScaleBar()
        deleteScaleBar();
        if appData.activeIdx < 1
            return;
        end

        imgInfo = appData.images{appData.activeIdx}.metadata.parserSpecific.imageData;

        % Read current settings from controls
        if isequal(btnScaleBarColor.FontColor, [1 1 1])
            barColor = [1 1 1];
        else
            barColor = [0 0 0];
        end
        fontSize = spnScaleBarFont.Value;

        hBar = imaging.addScaleBar(ax, imgInfo.pixelSize, imgInfo.pixelUnit, ...
            'Color', barColor, 'FontSize', fontSize);
        appData.overlays.scalebar = hBar;

        % Make scale bar draggable
        makeScaleBarDraggable(hBar);
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onLineProfile — Start two-click line profile capture
    % ════════════════════════════════════════════════════════════════════
    function onLineProfile(~, ~)
        if appData.activeIdx < 1 || isempty(appData.displayImg)
            return;
        end
        startTwoClickCapture('profile');
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onDistance — Start two-click distance capture
    % ════════════════════════════════════════════════════════════════════
    function onDistance(~, ~)
        if appData.activeIdx < 1 || isempty(appData.displayImg)
            return;
        end
        startTwoClickCapture('distance');
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onExportProfile — Save last line profile to CSV
    % ════════════════════════════════════════════════════════════════════
    function onExportProfile(~, ~)
        if isempty(appData.lastProfile.dist)
            uialert(fig, 'No line profile available. Use "Line Profile" first.', ...
                'No Profile', 'Icon', 'warning');
            return;
        end

        % Suggest filename from the active image
        if appData.activeIdx >= 1
            [~, bname] = fileparts(appData.images{appData.activeIdx}.metadata.source);
            defName = [bname '_profile.csv'];
        else
            defName = 'line_profile.csv';
        end

        startPath = appData.lastDir;
        if isempty(startPath) || ~isfolder(startPath)
            startPath = pwd;
        end

        [saveName, saveDir] = uiputfile('*.csv', 'Save Line Profile As', ...
            fullfile(startPath, defName));

        if isequal(saveName, 0)
            return;   % user cancelled
        end

        outPath = fullfile(saveDir, saveName);

        % Build matrix: [distance, intensity]
        distCol  = appData.lastProfile.dist(:);
        intCol   = appData.lastProfile.intensity(:);
        M = [distCol, intCol];

        % Write with a header comment row
        unitStr = appData.lastProfile.unit;
        header  = sprintf('Distance (%s),Intensity', unitStr);

        try
            fid = fopen(outPath, 'w');
            if fid == -1
                error('emViewerGUI:exportFailed', 'Cannot open file for writing: %s', outPath);
            end
            fprintf(fid, '%s\n', header);
            fclose(fid);
            writematrix(M, outPath, 'WriteMode', 'append');
            setStatus(sprintf('Profile saved: %s', saveName));
        catch ME
            uialert(fig, sprintf('Export failed:\n%s', ME.message), ...
                'Export Error', 'Icon', 'error');
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onClearOverlays — Remove all measurement overlays
    % ════════════════════════════════════════════════════════════════════
    function onClearOverlays(~, ~)
        % Cancel capture in progress
        if ~isempty(appData.captureMode)
            cancelCapture();
        end
        clearAllOverlays();
        cbScaleBar.Value = false;
        setStatus('All overlays cleared.');
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onCaptureClick — Handle clicks during two-click capture
    % ════════════════════════════════════════════════════════════════════
    function onCaptureClick(~, ~)
        if isempty(appData.captureMode)
            return;
        end

        % Get click position in data (image pixel) coordinates
        cp = ax.CurrentPoint;
        x  = cp(1, 1);
        y  = cp(1, 2);

        % Validate within image bounds
        if isempty(appData.displayImg)
            return;
        end
        [H, W] = size(appData.displayImg);
        x = max(0.5, min(W + 0.5, x));
        y = max(0.5, min(H + 0.5, y));

        % Draw click marker
        hMark = line(ax, x, y, ...
            'Marker',           'o', ...
            'MarkerSize',       6, ...
            'Color',            OVERLAY_COLOR, ...
            'MarkerFaceColor',  OVERLAY_COLOR, ...
            'LineStyle',        'none', ...
            'HandleVisibility', 'off');
        appData.overlays.clickMarkers{end+1} = hMark;

        % Accumulate clicks
        appData.captureClicks(end+1, :) = [x, y];

        if size(appData.captureClicks, 1) == 1
            % First click recorded — wait for second
            setStatus('Click second point on the image... (Escape to cancel)');

        elseif size(appData.captureClicks, 1) >= 2
            % Both clicks collected — execute the measurement
            x1 = appData.captureClicks(1, 1);
            y1 = appData.captureClicks(1, 2);
            x2 = appData.captureClicks(2, 1);
            y2 = appData.captureClicks(2, 2);

            mode = appData.captureMode;

            % Restore normal interaction
            finishCapture();

            switch mode
                case 'profile'
                    executeMeasureProfile(x1, y1, x2, y2);
                case 'distance'
                    executeMeasureDistance(x1, y1, x2, y2);
            end
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  CALLBACK: onKeyPress — Escape, arrow navigation, Tab (compare)
    % ════════════════════════════════════════════════════════════════════
    function onKeyPress(~, evt)
        % Escape cancels any in-progress capture
        if strcmp(evt.Key, 'escape') && ~isempty(appData.captureMode)
            cancelCapture();
            setStatus('Capture cancelled.');
            return;
        end

        % Don't navigate during capture
        if ~isempty(appData.captureMode)
            return;
        end

        nImages = numel(appData.images);

        % ── Compare mode: Tab switches panel, arrows scroll active panel ──
        if appData.compareMode
            if strcmp(evt.Key, 'tab')
                if appData.compareActivePanel == 'L'
                    appData.compareActivePanel = 'R';
                else
                    appData.compareActivePanel = 'L';
                end
                updateCompareHighlight();
                return;
            end

            if nImages < 2, return; end

            delta = 0;
            if strcmp(evt.Key, 'rightarrow'), delta =  1; end
            if strcmp(evt.Key, 'leftarrow'),  delta = -1; end
            if delta == 0, return; end

            if appData.compareActivePanel == 'L'
                newIdx = appData.compareIdxL + delta;
                if newIdx < 1, newIdx = nImages; end
                if newIdx > nImages, newIdx = 1; end
                appData.compareIdxL = newIdx;
                displayCompareImage('L');
            else
                newIdx = appData.compareIdxR + delta;
                if newIdx < 1, newIdx = nImages; end
                if newIdx > nImages, newIdx = 1; end
                appData.compareIdxR = newIdx;
                displayCompareImage('R');
            end
            return;
        end

        % ── Normal mode: left/right arrows cycle through images ──────────
        if nImages < 2, return; end

        if strcmp(evt.Key, 'rightarrow')
            newIdx = appData.activeIdx + 1;
            if newIdx > nImages, newIdx = 1; end
            setActiveIdxAPI(newIdx);
        elseif strcmp(evt.Key, 'leftarrow')
            newIdx = appData.activeIdx - 1;
            if newIdx < 1, newIdx = nImages; end
            setActiveIdxAPI(newIdx);
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  COMPARE MODE: enter / exit / display / highlight
    % ════════════════════════════════════════════════════════════════════
    function onCompareToggle(src, ~)
        if src.Value
            enterCompareMode();
        else
            exitCompareMode();
        end
    end

    function enterCompareMode()
        if numel(appData.images) < 2
            return;
        end

        appData.compareMode = true;

        % Pick indices for left and right panels
        appData.compareIdxL = appData.activeIdx;
        nextIdx = appData.activeIdx + 1;
        if nextIdx > numel(appData.images), nextIdx = 1; end
        appData.compareIdxR = nextIdx;
        appData.compareActivePanel = 'L';

        % Cancel any in-progress capture
        if ~isempty(appData.captureMode)
            cancelCapture();
        end

        % Clear overlays before destroying the axes
        clearAllOverlays();

        % Destroy single-view axes
        delete(axGL);
        axGL = []; %#ok<NASGU>
        ax   = []; %#ok<NASGU>

        % Create side-by-side layout inside axPanel
        compareGL = uigridlayout(axPanel, [1 2], ...
            'ColumnWidth', {'1x', '1x'}, ...
            'Padding', [2 2 2 2], ...
            'ColumnSpacing', 4);

        axL = uiaxes(compareGL);
        axL.Layout.Row = 1; axL.Layout.Column = 1;
        axL.Box = 'on';
        axL.XTick = []; axL.YTick = [];
        axL.Toolbar.Visible = 'off';
        colormap(axL, gray(256));

        axR = uiaxes(compareGL);
        axR.Layout.Row = 1; axR.Layout.Column = 2;
        axR.Box = 'on';
        axR.XTick = []; axR.YTick = [];
        axR.Toolbar.Visible = 'off';
        colormap(axR, gray(256));

        % Render both panels
        displayCompareImage('L');
        displayCompareImage('R');
        updateCompareHighlight();

        % Disable measurement/processing buttons (they operate on single ax)
        setToolsEnabled('off');
        setStatus('Compare mode — Tab to switch panel, arrows to scroll');
    end

    function exitCompareMode()
        appData.compareMode = false;

        % Destroy compare layout
        if ~isempty(compareGL) && isvalid(compareGL)
            delete(compareGL);
        end
        compareGL = [];
        axL = [];
        axR = [];

        % Recreate single-view axes
        axGL = uigridlayout(axPanel, [1 1], 'Padding', [2 2 2 2]);
        ax = uiaxes(axGL);
        ax.Box = 'on';
        ax.XTick = [];
        ax.YTick = [];
        title(ax, 'Open an image file to begin', 'Interpreter', 'none');
        xlabel(ax, '');
        ylabel(ax, '');
        colormap(ax, gray(256));
        ax.Toolbar.Visible = 'off';

        fig.WindowButtonMotionFcn = @onMouseMotion;

        % Restore single image view
        displayImage();

        setStatus('Compare mode off.');
    end

    function displayCompareImage(panel)
    %DISPLAYCOMPAREIMAGE  Render an image into the left or right compare axes.
        if panel == 'L'
            targetAx = axL;
            idx = appData.compareIdxL;
        else
            targetAx = axR;
            idx = appData.compareIdxR;
        end

        if isempty(targetAx) || ~isvalid(targetAx)
            return;
        end

        if idx < 1 || idx > numel(appData.images)
            return;
        end

        dataStruct = appData.images{idx};
        imgInfo = dataStruct.metadata.parserSpecific.imageData;
        pixels  = imgInfo.pixels;

        % Convert to grayscale double
        if imgInfo.numChannels == 3
            pixDouble = double(pixels);
            rawGray = 0.299*pixDouble(:,:,1) + 0.587*pixDouble(:,:,2) + 0.114*pixDouble(:,:,3);
        else
            rawGray = double(pixels);
        end

        % Auto-contrast (2nd/98th percentile)
        pLow  = percentileNoToolbox(rawGray(:), 2);
        pHigh = percentileNoToolbox(rawGray(:), 98);
        if pLow >= pHigh
            pLow  = min(rawGray(:));
            pHigh = max(rawGray(:));
        end
        if pHigh <= pLow, pHigh = pLow + 1; end

        dispImg = (rawGray - pLow) / (pHigh - pLow);
        dispImg = max(0, min(1, dispImg));

        [H, W] = size(rawGray);
        delete(targetAx.Children);
        cla(targetAx);
        imagesc(targetAx, 'XData', [1 W], 'YData', [1 H], 'CData', dispImg);
        targetAx.CLim = [0 1];
        targetAx.YDir = 'reverse';
        axis(targetAx, 'equal');
        targetAx.XLim = [0.5, W + 0.5];
        targetAx.YLim = [0.5, H + 0.5];
        targetAx.XTick = [];
        targetAx.YTick = [];

        [~, fname, fext] = fileparts(dataStruct.metadata.source);
        title(targetAx, sprintf('[%d] %s%s', idx, fname, fext), ...
            'Interpreter', 'none', 'FontSize', 10);
    end

    function updateCompareHighlight()
    %UPDATECOMPAREHIGHLIGHT  Show cyan border on the active compare panel.
        if isempty(axL) || ~isvalid(axL), return; end
        if isempty(axR) || ~isvalid(axR), return; end

        inactiveBorder = [0.4 0.4 0.4];
        if appData.compareActivePanel == 'L'
            axL.XColor = OVERLAY_COLOR; axL.YColor = OVERLAY_COLOR;
            axL.LineWidth = 2;
            axR.XColor = inactiveBorder; axR.YColor = inactiveBorder;
            axR.LineWidth = 0.5;
            setStatus(sprintf('Compare: LEFT [%d] active — Tab to switch, arrows to scroll', ...
                appData.compareIdxL));
        else
            axR.XColor = OVERLAY_COLOR; axR.YColor = OVERLAY_COLOR;
            axR.LineWidth = 2;
            axL.XColor = inactiveBorder; axL.YColor = inactiveBorder;
            axL.LineWidth = 0.5;
            setStatus(sprintf('Compare: RIGHT [%d] active — Tab to switch, arrows to scroll', ...
                appData.compareIdxR));
        end
    end

    function setToolsEnabled(state)
    %SETTOOLSENABLED  Enable or disable measurement/processing/annotation buttons.
        btnLineProfile.Enable   = state;
        btnDistance.Enable      = state;
        btnClearOverlays.Enable = state;
        btnGaussian.Enable     = state;
        btnMedian.Enable       = state;
        btnShowFFT.Enable      = state;
        btnUndoFilters.Enable  = state;
        btnZoomBox.Enable      = state;
        btnResetZoom.Enable    = state;
        btnCropImage.Enable    = state;
        btnSaveCrop.Enable     = state;
        btnSaveImage.Enable    = state;
        btnPlaceAnnot.Enable   = state;
        btnClearAnnot.Enable   = state;
        btnAnnotColor.Enable   = state;
        cbScaleBar.Enable      = state;
        btnScaleBarColor.Enable = state;
        spnScaleBarFont.Enable = state;
    end

    % ════════════════════════════════════════════════════════════════════
    %  ANNOTATIONS: color cycle, place, clear, API
    % ════════════════════════════════════════════════════════════════════
    function onAnnotColorCycle(~, ~)
        colors = {[1 1 1], OVERLAY_COLOR, [1 1 0], [1 0 0], [0 0 0]};
        names  = {'White', 'Cyan', 'Yellow', 'Red', 'Black'};
        bgs    = {[0.25 0.25 0.25], [0.15 0.15 0.15], [0.15 0.15 0.15], ...
                  [0.15 0.15 0.15], [0.85 0.85 0.85]};

        % Find current colour index
        curIdx = 1;
        for ci = 1:numel(colors)
            if isequal(appData.annotationColor, colors{ci})
                curIdx = ci;
                break;
            end
        end

        nextIdx = mod(curIdx, numel(colors)) + 1;
        appData.annotationColor = colors{nextIdx};
        btnAnnotColor.Text            = names{nextIdx};
        btnAnnotColor.FontColor       = colors{nextIdx};
        btnAnnotColor.BackgroundColor = bgs{nextIdx};
    end

    function onPlaceAnnotation(~, ~)
        if appData.activeIdx < 1 || isempty(appData.displayImg)
            return;
        end
        if appData.compareMode
            return;
        end
        if ~isempty(appData.captureMode)
            cancelCapture();
        end

        appData.captureMode = 'annotation';
        appData.captureClicks = [];
        fig.Pointer = 'crosshair';
        fig.WindowButtonDownFcn = @onAnnotationClick;
        setStatus('Click on image to place text annotation... (Esc to cancel)');
    end

    function onAnnotationClick(~, ~)
        if ~strcmp(appData.captureMode, 'annotation')
            return;
        end

        cp = ax.CurrentPoint;
        x  = cp(1, 1);
        y  = cp(1, 2);

        % Validate within image bounds
        if isempty(appData.displayImg), return; end
        [H, W] = size(appData.displayImg);
        if x < 0.5 || x > W + 0.5 || y < 0.5 || y > H + 0.5
            return;
        end

        annotStr   = efAnnotText.Value;
        annotSize  = spnAnnotFont.Value;
        annotColor = appData.annotationColor;

        if isempty(strtrim(annotStr))
            setStatus('Annotation text is empty — enter text first.');
            return;
        end

        placeAnnotationAt(x, y, annotStr, annotSize, annotColor);
        finishCapture();
        setStatus(sprintf('Annotation placed at (%.0f, %.0f).', x, y));
    end

    function placeAnnotationAt(x, y, str, fontSize, color)
    %PLACEANNOTATIONAT  Create a text object on ax and store it.
        hTxt = text(ax, x, y, str, ...
            'Color',               color, ...
            'FontSize',            fontSize, ...
            'FontWeight',          'bold', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment',   'bottom', ...
            'HandleVisibility',    'off', ...
            'Tag',                 'EMAnnotation');

        annot = struct('hText', hTxt, 'x', x, 'y', y, ...
                       'str', str, 'fontSize', fontSize, 'color', color);
        appData.overlays.textAnnotations{end+1} = annot;
    end

    function placeAnnotationAPI(x, y, str, fontSize, color)
    %PLACEANNOTATIONAPI  Non-interactive annotation placement for testing.
        if appData.activeIdx < 1 || isempty(appData.displayImg)
            return;
        end
        placeAnnotationAt(x, y, str, fontSize, color);
    end

    function onClearAnnotations(~, ~)
        for ci = 1:numel(appData.overlays.textAnnotations)
            a = appData.overlays.textAnnotations{ci};
            if isfield(a, 'hText') && isvalid(a.hText)
                delete(a.hText);
            end
        end
        appData.overlays.textAnnotations = {};
        setStatus('Text annotations cleared.');
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: startTwoClickCapture — Enter two-click capture mode
    % ════════════════════════════════════════════════════════════════════
    function startTwoClickCapture(mode)
        % Cancel any existing capture first
        if ~isempty(appData.captureMode)
            cancelCapture();
        end

        appData.captureMode   = mode;
        appData.captureClicks = [];

        fig.Pointer = 'crosshair';

        % Intercept button-down on the axes
        fig.WindowButtonDownFcn = @onCaptureClick;

        switch mode
            case 'profile'
                setStatus('Click first point for line profile... (Escape to cancel)');
            case 'distance'
                setStatus('Click first point for distance... (Escape to cancel)');
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: finishCapture — Restore cursor and ButtonDownFcn after capture
    % ════════════════════════════════════════════════════════════════════
    function finishCapture()
        appData.captureMode   = '';
        appData.captureClicks = [];
        fig.Pointer = 'arrow';
        fig.WindowButtonDownFcn = '';
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: cancelCapture — Abort capture and remove partial markers
    % ════════════════════════════════════════════════════════════════════
    function cancelCapture()
        % Delete any partial click markers placed during this capture
        for ci = 1:numel(appData.overlays.clickMarkers)
            h = appData.overlays.clickMarkers{ci};
            if isvalid(h)
                delete(h);
            end
        end
        appData.overlays.clickMarkers = {};

        % Restore motion callback in case rect-capture had replaced it
        fig.WindowButtonMotionFcn = @onMouseMotion;

        finishCapture();
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: executeMeasureProfile — Draw line and plot profile figure
    % ════════════════════════════════════════════════════════════════════
    function executeMeasureProfile(x1, y1, x2, y2)
        % Draw the measurement line
        hLine = line(ax, [x1 x2], [y1 y2], ...
            'Color',            OVERLAY_COLOR, ...
            'LineWidth',        1.5, ...
            'HandleVisibility', 'off');
        appData.overlays.lines{end+1} = hLine;

        % Delete temporary click markers — we'll create draggable ones
        for ci = 1:numel(appData.overlays.clickMarkers)
            h = appData.overlays.clickMarkers{ci};
            if isvalid(h), delete(h); end
        end
        appData.overlays.clickMarkers = {};

        % Create draggable endpoint markers
        hP1 = createEndpointMarker(x1, y1);
        hP2 = createEndpointMarker(x2, y2);

        % Build measurement record
        meas.type  = 'profile';
        meas.hLine = hLine;
        meas.hP1   = hP1;
        meas.hP2   = hP2;
        meas.hText = [];   % profiles don't have a midpoint label
        midx = numel(appData.overlays.measurements) + 1;
        appData.overlays.measurements{midx} = meas;

        % Attach drag callbacks
        hP1.ButtonDownFcn = @(~,~) startEndpointDrag(midx, 1);
        hP2.ButtonDownFcn = @(~,~) startEndpointDrag(midx, 2);

        % Run the profile computation
        runProfile(x1, y1, x2, y2);
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: executeMeasureDistance — Draw line and annotate distance
    % ════════════════════════════════════════════════════════════════════
    function executeMeasureDistance(x1, y1, x2, y2)
        % Draw the measurement line
        hLine = line(ax, [x1 x2], [y1 y2], ...
            'Color',            OVERLAY_COLOR, ...
            'LineWidth',        1.5, ...
            'HandleVisibility', 'off');
        appData.overlays.lines{end+1} = hLine;

        % Delete temporary click markers — we'll create draggable ones
        for ci = 1:numel(appData.overlays.clickMarkers)
            h = appData.overlays.clickMarkers{ci};
            if isvalid(h), delete(h); end
        end
        appData.overlays.clickMarkers = {};

        % Create draggable endpoint markers
        hP1 = createEndpointMarker(x1, y1);
        hP2 = createEndpointMarker(x2, y2);

        % Create midpoint distance label
        hTxt = createDistanceLabel(x1, y1, x2, y2);

        % Build measurement record
        meas.type  = 'distance';
        meas.hLine = hLine;
        meas.hP1   = hP1;
        meas.hP2   = hP2;
        meas.hText = hTxt;
        midx = numel(appData.overlays.measurements) + 1;
        appData.overlays.measurements{midx} = meas;

        % Attach drag callbacks
        hP1.ButtonDownFcn = @(~,~) startEndpointDrag(midx, 1);
        hP2.ButtonDownFcn = @(~,~) startEndpointDrag(midx, 2);

        appData.overlays.distLabels{end+1} = hTxt;
        setStatus(sprintf('Distance: %s', hTxt.String));
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: createEndpointMarker — Draggable circle marker for line ends
    % ════════════════════════════════════════════════════════════════════
    function hMark = createEndpointMarker(x, y)
        hMark = line(ax, x, y, ...
            'Marker',           'o', ...
            'MarkerSize',       8, ...
            'Color',            OVERLAY_COLOR, ...
            'MarkerFaceColor',  OVERLAY_COLOR, ...
            'LineStyle',        'none', ...
            'HandleVisibility', 'off');
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: createDistanceLabel — Midpoint annotation with distance text
    % ════════════════════════════════════════════════════════════════════
    function hTxt = createDistanceLabel(x1, y1, x2, y2)
        % Retrieve calibration
        imgInfo = appData.images{appData.activeIdx}.metadata.parserSpecific.imageData;
        ps = NaN;
        pu = 'px';
        if imgInfo.calibrated && ~isnan(imgInfo.pixelSize)
            ps = imgInfo.pixelSize;
            pu = imgInfo.pixelUnit;
        end

        if ~isnan(ps)
            [dVal, dUnit] = imaging.measureDistance(x1, y1, x2, y2, ...
                PixelSize=ps, PixelUnit=pu);
            distStr = sprintf('%.4g %s', dVal, dUnit);
        else
            [dVal, dUnit] = imaging.measureDistance(x1, y1, x2, y2);
            distStr = sprintf('%.1f %s', dVal, dUnit);
        end

        mx = (x1 + x2) / 2;
        my = (y1 + y2) / 2;

        hTxt = text(ax, mx, my, distStr, ...
            'Color',               [1 1 1], ...
            'FontSize',            10, ...
            'FontWeight',          'bold', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment',   'bottom', ...
            'BackgroundColor',     [0.1 0.1 0.1], ...
            'EdgeColor',           OVERLAY_COLOR, ...
            'Margin',              2, ...
            'HandleVisibility',    'off');
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: runProfile — Extract and display line profile
    % ════════════════════════════════════════════════════════════════════
    function runProfile(x1, y1, x2, y2)
        imgInfo = appData.images{appData.activeIdx}.metadata.parserSpecific.imageData;
        ps = NaN;
        pu = 'px';
        if imgInfo.calibrated && ~isnan(imgInfo.pixelSize)
            ps = imgInfo.pixelSize;
            pu = imgInfo.pixelUnit;
        end

        try
            if ~isnan(ps)
                [dist, intensity] = imaging.lineProfile(appData.filteredPixels, ...
                    x1, y1, x2, y2, PixelSize=ps, PixelUnit=pu);
            else
                [dist, intensity] = imaging.lineProfile(appData.filteredPixels, ...
                    x1, y1, x2, y2);
            end
        catch ME
            uialert(fig, sprintf('Line profile failed:\n%s', ME.message), ...
                'Error', 'Icon', 'error');
            return;
        end

        % Store for CSV export
        appData.lastProfile = struct('dist', dist, 'intensity', intensity, 'unit', pu);
        btnExportProfile.Enable = 'on';

        % Status bar
        [dVal, dUnit] = imaging.measureDistance(x1, y1, x2, y2, ...
            PixelSize=ps, PixelUnit=pu);
        if ~isnan(ps)
            setStatus(sprintf('Line profile: %.4g %s', dVal, dUnit));
        else
            setStatus(sprintf('Line profile: %.1f px', dVal));
        end

        % Open or update profile figure
        pfig = findobj(0, 'Type', 'figure', 'Name', 'Line Profile');
        if isempty(pfig)
            pfig = figure('Name', 'Line Profile', 'NumberTitle', 'off', ...
                'Units', 'pixels', 'Position', [200 200 560 300]);
        else
            figure(pfig(1));
            pfig = pfig(1);
        end
        pax = findobj(pfig, 'Type', 'axes');
        if isempty(pax)
            pax = axes(pfig);
        else
            cla(pax(1));
            pax = pax(1);
        end
        plot(pax, dist, intensity, 'Color', [0 0.4 0.8], 'LineWidth', 1.2);
        grid(pax, 'on');
        if ~isnan(ps)
            xlabel(pax, sprintf('Distance (%s)', pu));
        else
            xlabel(pax, 'Distance (px)');
        end
        ylabel(pax, 'Intensity');
        title(pax, 'Line Profile', 'Interpreter', 'none');
        box(pax, 'on');
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: startEndpointDrag — Drag a line endpoint to update measurement
    % ════════════════════════════════════════════════════════════════════
    function startEndpointDrag(measIdx, whichEnd)
        % whichEnd: 1 = start (P1), 2 = end (P2)
        if measIdx > numel(appData.overlays.measurements)
            return;
        end
        meas = appData.overlays.measurements{measIdx};
        if ~isvalid(meas.hLine)
            return;
        end

        % Store original callbacks
        origMotionFcn  = fig.WindowButtonMotionFcn;
        origReleaseFcn = fig.WindowButtonUpFcn;

        fig.Pointer = 'crosshair';
        fig.WindowButtonMotionFcn = @dragMotion;
        fig.WindowButtonUpFcn    = @dragRelease;

        function dragMotion(~, ~)
            cp = ax.CurrentPoint;
            nx = cp(1,1);
            ny = cp(1,2);

            % Clamp to image bounds
            if ~isempty(appData.displayImg)
                [H, W] = size(appData.displayImg);
                nx = max(0.5, min(W + 0.5, nx));
                ny = max(0.5, min(H + 0.5, ny));
            end

            % Update endpoint marker position
            if whichEnd == 1
                meas.hP1.XData = nx;
                meas.hP1.YData = ny;
                meas.hLine.XData(1) = nx;
                meas.hLine.YData(1) = ny;
            else
                meas.hP2.XData = nx;
                meas.hP2.YData = ny;
                meas.hLine.XData(2) = nx;
                meas.hLine.YData(2) = ny;
            end

            % Update distance label position (midpoint) during drag
            if ~isempty(meas.hText) && isvalid(meas.hText)
                mx = (meas.hLine.XData(1) + meas.hLine.XData(2)) / 2;
                my = (meas.hLine.YData(1) + meas.hLine.YData(2)) / 2;
                meas.hText.Position = [mx, my, 0];
            end
        end

        function dragRelease(~, ~)
            fig.WindowButtonMotionFcn = origMotionFcn;
            fig.WindowButtonUpFcn    = origReleaseFcn;
            fig.Pointer = 'arrow';

            % Read final positions
            x1 = meas.hLine.XData(1);
            y1 = meas.hLine.YData(1);
            x2 = meas.hLine.XData(2);
            y2 = meas.hLine.YData(2);

            % Update the stored record
            appData.overlays.measurements{measIdx} = meas;

            % Re-run the measurement
            switch meas.type
                case 'profile'
                    runProfile(x1, y1, x2, y2);
                case 'distance'
                    % Update the distance label text
                    if ~isempty(meas.hText) && isvalid(meas.hText)
                        delete(meas.hText);
                    end
                    newTxt = createDistanceLabel(x1, y1, x2, y2);
                    meas.hText = newTxt;
                    appData.overlays.measurements{measIdx} = meas;
                    setStatus(sprintf('Distance: %s', newTxt.String));
                    % Update distLabels reference
                    appData.overlays.distLabels{end+1} = newTxt;
            end
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: clearAllOverlays — Delete all measurement graphics objects
    % ════════════════════════════════════════════════════════════════════
    function clearAllOverlays()
        % Scale bar
        deleteScaleBar();

        % Measurement records (draggable endpoints)
        for ci = 1:numel(appData.overlays.measurements)
            m = appData.overlays.measurements{ci};
            if isfield(m, 'hP1') && isvalid(m.hP1), delete(m.hP1); end
            if isfield(m, 'hP2') && isvalid(m.hP2), delete(m.hP2); end
            if isfield(m, 'hText') && ~isempty(m.hText) && isvalid(m.hText)
                delete(m.hText);
            end
        end
        appData.overlays.measurements = {};

        % Measurement lines
        for ci = 1:numel(appData.overlays.lines)
            h = appData.overlays.lines{ci};
            if isvalid(h)
                delete(h);
            end
        end
        appData.overlays.lines = {};

        for ci = 1:numel(appData.overlays.clickMarkers)
            h = appData.overlays.clickMarkers{ci};
            if isvalid(h)
                delete(h);
            end
        end
        appData.overlays.clickMarkers = {};

        % Distance text annotations
        for ci = 1:numel(appData.overlays.distLabels)
            h = appData.overlays.distLabels{ci};
            if isvalid(h)
                delete(h);
            end
        end
        appData.overlays.distLabels = {};

        % Text annotations
        for ci = 1:numel(appData.overlays.textAnnotations)
            a = appData.overlays.textAnnotations{ci};
            if isfield(a, 'hText') && isvalid(a.hText)
                delete(a.hText);
            end
        end
        appData.overlays.textAnnotations = {};
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: deleteScaleBar — Remove scale bar graphics handles if present
    % ════════════════════════════════════════════════════════════════════
    function deleteScaleBar()
        sb = appData.overlays.scalebar;
        if ~isempty(sb) && isstruct(sb)
            if isfield(sb, 'bar') && isvalid(sb.bar)
                delete(sb.bar);
            end
            if isfield(sb, 'label') && isvalid(sb.label)
                delete(sb.label);
            end
        end
        appData.overlays.scalebar = [];
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: makeScaleBarDraggable — attach ButtonDownFcn for dragging
    % ════════════════════════════════════════════════════════════════════
    function makeScaleBarDraggable(hBar)
        % Both the rectangle and label trigger the same drag behaviour.
        % On mouse-down, record the initial position offset, then track
        % mouse motion and release via temporary figure callbacks.

        if ~isstruct(hBar), return; end

        if isfield(hBar, 'bar') && isvalid(hBar.bar)
            hBar.bar.ButtonDownFcn = @(~,~) startScaleBarDrag();
        end
        if isfield(hBar, 'label') && isvalid(hBar.label)
            hBar.label.ButtonDownFcn = @(~,~) startScaleBarDrag();
        end
    end

    function startScaleBarDrag()
        sb = appData.overlays.scalebar;
        if isempty(sb) || ~isstruct(sb), return; end

        % Current bar position: [x y w h]
        barPos  = sb.bar.Position;
        labelPt = [sb.label.Position(1), sb.label.Position(2)];

        % Get click location in data coords
        cp = ax.CurrentPoint;
        startX = cp(1,1);
        startY = cp(1,2);

        % Store original callbacks to restore on release
        origMotionFcn  = fig.WindowButtonMotionFcn;
        origReleaseFcn = fig.WindowButtonUpFcn;

        fig.WindowButtonMotionFcn = @dragMotion;
        fig.WindowButtonUpFcn    = @dragRelease;

        function dragMotion(~, ~)
            cp2 = ax.CurrentPoint;
            dx = cp2(1,1) - startX;
            dy = cp2(1,2) - startY;

            % Move rectangle
            sb.bar.Position(1) = barPos(1) + dx;
            sb.bar.Position(2) = barPos(2) + dy;

            % Move label
            sb.label.Position = [labelPt(1) + dx, labelPt(2) + dy, 0];
        end

        function dragRelease(~, ~)
            fig.WindowButtonMotionFcn = origMotionFcn;
            fig.WindowButtonUpFcn    = origReleaseFcn;
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: setStatus — Write a message to the mouse status label
    % ════════════════════════════════════════════════════════════════════
    function setStatus(msg)
        lblStatusMouse.Text = msg;
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: onOff — Convert logical to 'on'/'off' string
    % ════════════════════════════════════════════════════════════════════
    function s = onOff(tf)
        if tf
            s = 'on';
        else
            s = 'off';
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  API: getLineProfileAPI — Programmatic line profile extraction
    % ════════════════════════════════════════════════════════════════════
    function result = getLineProfileAPI(x1, y1, x2, y2)
    %GETLINEPROFILEAPI  Extract a line profile from the active image.
    %   result = api.getLineProfile(x1, y1, x2, y2)
    %   Returns a struct with fields:
    %       .dist      — [Nx1] distance vector
    %       .intensity — [Nx1] interpolated intensity values (raw pixel counts)
    %       .unit      — unit string ('px' when uncalibrated)
        result = struct('dist', [], 'intensity', [], 'unit', 'px');

        if appData.activeIdx < 1 || isempty(appData.filteredPixels)
            warning('emViewerGUI:noImage', 'No image loaded.');
            return;
        end

        imgInfo = appData.images{appData.activeIdx}.metadata.parserSpecific.imageData;
        ps = NaN;
        pu = 'px';
        if imgInfo.calibrated && ~isnan(imgInfo.pixelSize)
            ps = imgInfo.pixelSize;
            pu = imgInfo.pixelUnit;
        end

        if ~isnan(ps)
            [dist, intensity] = imaging.lineProfile(appData.filteredPixels, ...
                x1, y1, x2, y2, PixelSize=ps, PixelUnit=pu);
        else
            [dist, intensity] = imaging.lineProfile(appData.filteredPixels, ...
                x1, y1, x2, y2);
        end

        result.dist      = dist;
        result.intensity = intensity;
        result.unit      = pu;

        % Also cache it so Export CSV becomes available
        appData.lastProfile = result;
        btnExportProfile.Enable = 'on';
    end

    % ════════════════════════════════════════════════════════════════════
    %  HELPER: percentileNoToolbox — p-th percentile without Statistics Toolbox
    % ════════════════════════════════════════════════════════════════════
    function v = percentileNoToolbox(data, p)
    %PERCENTILENOTTOOLBOX  Compute the p-th percentile of a vector.
    %   Uses linear interpolation matching MATLAB's Statistics Toolbox
    %   prctile behaviour (method 5 / R-7).
        x = sort(double(data(:)));
        n = numel(x);
        if n == 0
            v = NaN;
            return;
        end
        if n == 1
            v = x(1);
            return;
        end
        % Map percentile p to a fractional index in [1, n]
        h = (p / 100) * (n - 1) + 1;   % 1-based fractional index
        lo = floor(h);
        hi = ceil(h);
        lo = max(1, min(n, lo));
        hi = max(1, min(n, hi));
        if lo == hi
            v = x(lo);
        else
            frac = h - lo;
            v = x(lo) * (1 - frac) + x(hi) * frac;
        end
    end

end
