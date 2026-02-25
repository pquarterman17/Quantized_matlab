function dataImportGUI()
%DATAIMPORTGUI  Browse, import and preview data files using the +parser toolkit.
%
%   dataImportGUI()
%
%   Opens an interactive figure with:
%     - Multi-file import: add several files at once; each becomes a named dataset
%     - Auto-detection of the correct parser (same logic as parser.importAuto)
%     - X / Y channel selectors -- Y supports multi-select for overlay plots
%     - Line, Scatter, and Line+Markers plot styles
%     - Log-scale toggles for both axes
%     - Metadata summary panel (shows the active dataset)
%     - Analysis & Corrections: X/Y offset, linear background subtraction
%     - Raw + corrected overlay plotting (raw in desaturated pastel, corrected in full colour)
%     - Save corrected data to CSV
%     - Export to a standard MATLAB figure for publication-quality editing
%
%   All loaded datasets are overlaid on the same axes.  Click a dataset in
%   the list to make it active — channel selectors and corrections then apply
%   to that file only.  Remove a file with the "Remove Selected" button.
%
%   Run from the project root:
%       cd G:\Onedrive\Coding\git\thin_film_toolkit_matlab
%       dataImportGUI
%
%   See also parser.importAuto, parser.importRigaku_raw, parser.importPPMS,
%            parser.importCSV, parser.importExcel, parser.importQDVSM

    % ── Shared application state ─────────────────────────────────────────
    % Each element of appData.datasets is a struct with fields:
    %   .data       — parsed data struct (from guiImport)
    %   .filepath   — full path to the source file
    %   .parserName — name of the parser that was used
    %   .corrData   — corrected data struct ([] = not yet applied)
    %   .xOff / .yOff / .bgSlope / .bgInt — stored correction params
    appData.datasets   = {};   % cell array of dataset structs
    appData.activeIdx  = 0;    % 1-based index into datasets; 0 = none loaded
    appData.style      = 'Line';
    appData.bgXVecRaw   = [];
    appData.bgStartPt   = [];
    appData.bgRectPatch = [];
    appData.lastDir       = '';
    appData.yOriginClickCount = 0;
    appData.yOriginPt1        = [];
    appData.yOriginMarker     = [];
    appData.yTranslateY0      = [];   % y-coord of mouse-down during Y-translate drag
    appData.yTranslateOff0    = 0;    % efYOffset value at start of drag
    appData.peakPickMode      = false;
    appData.peakRemoveMode    = false;
    appData.selectedPeakIdx   = 0;    % row highlighted in peakTable (0 = none)
    appData.zoomStartPt       = [];        % [x y] data coords where drag-zoom began
    appData.zoomRectPatch     = [];        % patch handle for the rubber-band rectangle
    appData.lastClickTic      = uint64(0); % tic timestamp of last ax click (double-click detection)
    appData.cursorText        = [];        % text handle for x,y hover readout (top-right of axes)
    appData.bgDataset         = [];        % background data struct loaded via importAuto (or [])
    appData.bgFile            = '';        % short filename of background dataset for display
    appData.showFitCurves     = true;               % toggle Lorentzian fit overlay on/off
    appData.fitCurveColor     = [0.85 0.20 0.00];   % default warm red-orange
    appData.panelResizeDir    = '';   % '' | 'h_row12' | 'h_row23' | 'v_col12' | 'v_col23' | 'v_col34'
    appData.panelResizeStart  = [];   % [mousePixX, mousePixY] at resize drag start
    appData.panelResizeOrig   = [];   % panel dimension (px) at resize drag start
    appData.corrPanelWidth    = 350;  % user-resized corrections column width (px)
    appData.axLimPanelWidth   = 180;  % user-resized axis-limits column width (px)
    appData.listDragSrcIdx    = 0;    % source row being dragged in lbDatasets (0 = none)
    appData.listDragActive    = false; % true once mouse has moved > threshold after listbox down
    appData.listDragStartPt   = [];   % [x y] fig-pixel position at listbox mouse-down

    % ── Figure ───────────────────────────────────────────────────────────
    fig = uifigure('Name','Data Import & Preview', ...
                   'Position',[80 60 1080 1000], ...
                   'AutoResizeChildren','off');
    MIN_FIG_H = 820;   % minimum height so the analysis panel is never clipped
    fig.SizeChangedFcn = @onFigSizeChanged;
    try
        fig.DropFcn = @onDropFiles;   % drag-and-drop from Explorer (R2023a+)
    catch
        % DropFcn is not available on this MATLAB version — silently skip
    end

    % ── Dataset-colour palette (shared by widget and callbacks) ──────────
    DS_COLOR_NAMES = {'Auto','Blue','Orange','Red','Green', ...
                      'Purple','Teal','Brown','Black','Grey'};
    DS_COLOR_RGBS  = {[], [0.00 0.45 0.74], [0.85 0.33 0.10], ...
                      [0.80 0.07 0.07], [0.47 0.67 0.19], ...
                      [0.49 0.18 0.56], [0.30 0.75 0.93], ...
                      [0.64 0.35 0.10], [0.00 0.00 0.00], ...
                      [0.50 0.50 0.50]};

    % ── Tick-label format options ─────────────────────────────────────────
    % X-axis: printf format strings only.
    TICKFMT_NAMES  = {'Auto', 'Scientific', 'Fixed 4dp', 'Fixed 2dp', 'Integer'};
    TICKFMT_DATA   = {'',     '%.2e',       '%.4f',      '%.2f',      '%d'};
    % Y-axis: same options plus "Exp = 0" which forces the axis exponent to zero
    % (suppresses the corner ×10ⁿ multiplier so ticks show their true magnitude).
    % The sentinel '__exp0' is detected in drawToAxes and handled via YAxis.Exponent.
    YTICKFMT_NAMES = {'Auto', 'Scientific', 'Fixed 4dp', 'Fixed 2dp', 'Integer', 'Exp = 0'};
    YTICKFMT_DATA  = {'',     '%.2e',       '%.4f',      '%.2f',      '%d',      '__exp0'};

    % Root grid  (3 rows × 2 cols: toolbar occupies left half of row 1 only;
    %             content and analysis span both columns at full width)
    % Row 1 height: 222px (= 185 × 1.20) to prevent apGL clipping.
    % Row 2 (preview) gets 60% of flexible space, row 3 (analysis) gets 40%: ratio 3x:2x.
    rootGL = uigridlayout(fig,[3 2], ...
        'RowHeight',    {222,'3x','2x'}, ...
        'ColumnWidth',  {'1x','1x'}, ...
        'Padding',      [8 8 8 8], ...
        'RowSpacing',   6, ...
        'ColumnSpacing', 0);

    % ── Toolbar row: Add / Remove buttons (top) + dataset listbox (bottom) ─
    tbGL = uigridlayout(rootGL,[2 2], ...
        'RowHeight',    {26,'1x'}, ...
        'ColumnWidth',  {'1x','1x'}, ...
        'Padding',      [0 0 0 0], ...
        'RowSpacing',   4, ...
        'ColumnSpacing', 6);
    tbGL.Layout.Row = 1; tbGL.Layout.Column = 1;

    btnBrowse = uibutton(tbGL,'Text','Add File(s)...', ...
        'ButtonPushedFcn',@onAddFiles, ...
        'BackgroundColor',[0.18 0.52 0.18], ...
        'FontColor',[1 1 1],'FontWeight','bold', ...
        'Tooltip','Browse for one or more data files — each is added as a new dataset');
    btnBrowse.Layout.Row = 1; btnBrowse.Layout.Column = 1;

    btnRemoveDS = uibutton(tbGL,'Text','Remove Selected', ...
        'ButtonPushedFcn',@onRemoveDataset, ...
        'Tooltip','Remove the highlighted dataset from the list');
    btnRemoveDS.Layout.Row = 1; btnRemoveDS.Layout.Column = 2;

    lbDatasets = uilistbox(tbGL, ...
        'Items',     {'(no files loaded — click  Add File(s)...  to begin)'}, ...
        'ItemsData', {0}, ...
        'Multiselect','off', ...
        'ValueChangedFcn',@onSelectDataset, ...
        'Tooltip','Loaded datasets — click to make a dataset active for editing / corrections');
    lbDatasets.Layout.Row = 2; lbDatasets.Layout.Column = [1 2];

    % ── Appearance panel (top right): colour, legend, axis labels, title ────
    % Column 3 (right-axis options) starts hidden (ColumnWidth{3}=0) and row 1
    % (L/R column headers) starts hidden (RowHeight{1}=0).  Both are revealed
    % when Y2 channels are active.
    apGL = uigridlayout(rootGL,[7 3], ...
        'RowHeight',    {0,22,22,22,22,22,22}, ...
        'ColumnWidth',  {60,'1x',0}, ...
        'Padding',      [6 5 6 5], ...
        'RowSpacing',   2, ...
        'ColumnSpacing', 6);
    apGL.Layout.Row = 1; apGL.Layout.Column = 2;

    % Row 1: L / R column headers (hidden until Y2 is active)
    lblApHdrL = uilabel(apGL,'Text','Left Y','FontSize',12, ...
        'HorizontalAlignment','center','FontColor',[0.60 0.60 0.60],'FontWeight','bold');
    lblApHdrL.Layout.Row = 1; lblApHdrL.Layout.Column = 2;
    lblApHdrR = uilabel(apGL,'Text','Right Y','FontSize',12, ...
        'HorizontalAlignment','center','FontColor',[0.60 0.60 0.60],'FontWeight','bold');
    lblApHdrR.Layout.Row = 1; lblApHdrR.Layout.Column = 3;

    % Row 2: Color
    lblApColor = uibutton(apGL,'Text','Color:','Enable','off','FontSize',10);
    lblApColor.Layout.Row = 2; lblApColor.Layout.Column = 1;

    ddDatasetColor = uidropdown(apGL, ...
        'Items',     DS_COLOR_NAMES, ...
        'ItemsData', DS_COLOR_RGBS, ...
        'Value',     [], ...
        'Enable',    'off', ...
        'Tooltip',   'Override line colour for left-axis channels ("Auto" uses the palette)', ...
        'ValueChangedFcn', @onDatasetColorChanged);
    ddDatasetColor.Layout.Row = 2; ddDatasetColor.Layout.Column = 2;

    ddDatasetColorR = uidropdown(apGL, ...
        'Items',     DS_COLOR_NAMES, ...
        'ItemsData', DS_COLOR_RGBS, ...
        'Value',     [], ...
        'Enable',    'off', ...
        'Tooltip',   'Override line colour for right-axis channels ("Auto" uses the palette)', ...
        'ValueChangedFcn', @onDatasetColorRChanged);
    ddDatasetColorR.Layout.Row = 2; ddDatasetColorR.Layout.Column = 3;

    % Row 3: Legend name
    lblApLegend = uibutton(apGL,'Text','Legend:','Enable','off','FontSize',10);
    lblApLegend.Layout.Row = 3; lblApLegend.Layout.Column = 1;

    efLegendName = uieditfield(apGL,'text','Value','', ...
        'Enable',          'off', ...
        'Placeholder',     'auto (channel name)', ...
        'Tooltip',         'Override the legend label for left-axis channels — blank = auto', ...
        'ValueChangedFcn', @onLegendNameChanged);
    efLegendName.Layout.Row = 3; efLegendName.Layout.Column = 2;

    efLegendNameR = uieditfield(apGL,'text','Value','', ...
        'Enable',          'off', ...
        'Placeholder',     'auto', ...
        'Tooltip',         'Override the legend label for right-axis channels — blank = auto', ...
        'ValueChangedFcn', @onLegendNameRChanged);
    efLegendNameR.Layout.Row = 3; efLegendNameR.Layout.Column = 3;

    % Row 4: X label (spans both value columns — only one X axis)
    lblApXLabel = uibutton(apGL,'Text','X Label:','Enable','off','FontSize',10);
    lblApXLabel.Layout.Row = 4; lblApXLabel.Layout.Column = 1;

    efCustomXLabel = uieditfield(apGL,'text','Value','', ...
        'Placeholder',     'auto (from data)', ...
        'Tooltip',         'Override the X-axis label — blank = auto', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomXLabel.Layout.Row = 4; efCustomXLabel.Layout.Column = [2 3];

    % Row 5: Y label (left and right independently)
    lblApYLabel = uibutton(apGL,'Text','Y Label:','Enable','off','FontSize',10);
    lblApYLabel.Layout.Row = 5; lblApYLabel.Layout.Column = 1;

    efCustomYLabel = uieditfield(apGL,'text','Value','', ...
        'Placeholder',     'auto (from data)', ...
        'Tooltip',         'Override the left Y-axis label — blank = auto', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomYLabel.Layout.Row = 5; efCustomYLabel.Layout.Column = 2;

    efCustomY2Label = uieditfield(apGL,'text','Value','', ...
        'Placeholder',     'auto', ...
        'Tooltip',         'Override the right Y-axis label — blank = auto', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomY2Label.Layout.Row = 5; efCustomY2Label.Layout.Column = 3;

    % Row 6: Title (spans both value columns)
    lblApTitle = uibutton(apGL,'Text','Title:','Enable','off','FontSize',10);
    lblApTitle.Layout.Row = 6; lblApTitle.Layout.Column = 1;

    efCustomTitle = uieditfield(apGL,'text','Value','', ...
        'Placeholder',     'auto (from filename)', ...
        'Tooltip',         'Override the plot title — blank = auto', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomTitle.Layout.Row = 6; efCustomTitle.Layout.Column = [2 3];

    % Row 7: Tick-label notation — X and Y1 always visible; R (Y2) hidden until active.
    % A nested 1×6 grid packs [X: dd | Y: dd | R: dd] into the two value columns.
    % Cols 5-6 (the R label + dropdown) start at width 0 and are revealed with Y2.
    lblApFmt = uibutton(apGL,'Text','Format:','Enable','off','FontSize',10);
    lblApFmt.Layout.Row = 7; lblApFmt.Layout.Column = 1;

    fmtGL = uigridlayout(apGL, [1 6], ...
        'Padding', [0 0 0 0], 'RowSpacing', 0, 'ColumnSpacing', 2, ...
        'ColumnWidth', {16, '1x', 16, '1x', 0, 0});
    fmtGL.Layout.Row = 7; fmtGL.Layout.Column = [2 3];

    lblFmtX = uilabel(fmtGL,'Text','X','FontSize',9,'HorizontalAlignment','right');
    lblFmtX.Layout.Column = 1;
    ddXFmt = uidropdown(fmtGL, 'Items', TICKFMT_NAMES, 'ItemsData', TICKFMT_DATA, ...
        'Value', '', 'FontSize', 10, 'Tooltip', 'X-axis tick label notation', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddXFmt.Layout.Column = 2;

    lblFmtY = uilabel(fmtGL,'Text','Y','FontSize',9,'HorizontalAlignment','right');
    lblFmtY.Layout.Column = 3;
    ddYFmt = uidropdown(fmtGL, 'Items', YTICKFMT_NAMES, 'ItemsData', YTICKFMT_DATA, ...
        'Value', '__exp0', 'FontSize', 10, 'Tooltip', 'Left Y-axis tick label notation', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddYFmt.Layout.Column = 4;

    lblFmtR = uilabel(fmtGL,'Text','R','FontSize',9,'HorizontalAlignment','right');
    lblFmtR.Layout.Column = 5;
    ddY2Fmt = uidropdown(fmtGL, 'Items', YTICKFMT_NAMES, 'ItemsData', YTICKFMT_DATA, ...
        'Value', '', 'FontSize', 10, 'Tooltip', 'Right Y-axis tick label notation', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddY2Fmt.Layout.Column = 6;

    % ── Content: controls panel (left) | preview axes (right) ────────────
    contentGL = uigridlayout(rootGL,[1 2], ...
        'ColumnWidth',  {215,'1x'}, ...
        'Padding',      [0 0 0 0], ...
        'ColumnSpacing', 8);
    contentGL.Layout.Row = 2; contentGL.Layout.Column = [1 2];

    % Left controls panel
    % Title updates to show parser name after each load.
    % Row layout (9 rows):
    %   1 -  26px  X dropdown
    %   2 -   4px  spacer
    %   3 -  88px  Y listbox (multi-select)
    %   4 -   4px  spacer
    %   5 -  36px  Plot-style toggle buttons (Line | Scatter | Line+Pts)
    %   6 -  26px  Log-scale checkboxes
    %   7 -   6px  spacer
    %   8 -  30px  Replot button
    %   9 -   1x   Metadata text area
    ctrlPanel = uipanel(contentGL,'Title','Controls','FontSize',13);
    ctrlPanel.Layout.Column = 1;

    ctrlGL = uigridlayout(ctrlPanel,[12 1], ...
        'RowHeight', {26,4,'1x',4,'1x',4,36,26,4,30,4,26}, ...
        'Padding',   [6 6 6 6], ...
        'RowSpacing', 0);

    ddX = uidropdown(ctrlGL,'Items',{'(load file first)'}, ...
        'ValueChangedFcn',@onAxisChanged, ...
        'Tooltip','X axis channel');
    ddX.Layout.Row = 1;

    lbY = uilistbox(ctrlGL,'Items',{'(load file first)'},'Multiselect','on', ...
        'ValueChangedFcn',@onAxisChanged, ...
        'Tooltip','Y axis channel(s) — Ctrl+click to select multiple');
    lbY.Layout.Row = 3;

    % Row 5: Right Y-axis channel selector + log toggle
    y2GL = uigridlayout(ctrlGL,[2 2], ...
        'Padding',[0 0 0 0],'RowSpacing',2,'ColumnSpacing',4, ...
        'RowHeight',{20,'1x'},'ColumnWidth',{'1x',55});
    y2GL.Layout.Row = 5;

    lblY2 = uilabel(y2GL,'Text','Right Y-axis:', ...
        'FontSize',12,'FontColor',[0.75 0.75 0.75]);
    lblY2.Layout.Row = 1; lblY2.Layout.Column = 1;

    cbLogY2 = uicheckbox(y2GL,'Text','Log R', ...
        'Value',false, ...
        'Tooltip','Use log scale for the right Y-axis', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    cbLogY2.Layout.Row = 1; cbLogY2.Layout.Column = 2;

    lbY2 = uilistbox(y2GL,'Items',{'(none)'},'Multiselect','on', ...
        'Value',{'(none)'}, ...
        'Tooltip','Right Y-axis channel(s) — plotted against the right-hand scale', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    lbY2.Layout.Row = 2; lbY2.Layout.Column = [1 2];

    % Plot-style buttons (row 7) — three uibutton objects in a nested grid.
    styleGL = uigridlayout(ctrlGL,[1 3], ...
        'Padding',[0 0 0 0],'ColumnSpacing',2,'ColumnWidth',{'1x','1x','1x'});
    styleGL.Layout.Row = 7;

    btnStyleLine = uibutton(styleGL,'Text','Line', ...
        'ButtonPushedFcn',@(~,~) onStylePick('Line'), ...
        'BackgroundColor',[0.20 0.50 0.20],'FontColor',[1 1 1]);
    btnStyleLine.Layout.Column = 1;

    btnStyleScatter = uibutton(styleGL,'Text','Scatter', ...
        'ButtonPushedFcn',@(~,~) onStylePick('Scatter'));
    btnStyleScatter.Layout.Column = 2;

    btnStyleLineMarkers = uibutton(styleGL,'Text','Line+Pts', ...
        'ButtonPushedFcn',@(~,~) onStylePick('Line+Pts'));
    btnStyleLineMarkers.Layout.Column = 3;

    chkGL = uigridlayout(ctrlGL,[1 3], ...
        'Padding',[0 0 0 0],'ColumnWidth',{'1x','1x','1x'},'ColumnSpacing',4);
    chkGL.Layout.Row = 8;
    cbLogX = uicheckbox(chkGL,'Text','Log X','ValueChangedFcn',@onAxisChanged);
    cbLogX.Layout.Column = 1;
    cbLogY = uicheckbox(chkGL,'Text','Log Y','ValueChangedFcn',@onAxisChanged);
    cbLogY.Layout.Column = 2;
    cbCountsPerSec = uicheckbox(chkGL,'Text','Cts/s', ...
        'Value', false, 'Enable', 'off', ...
        'Tooltip', 'Divide intensity by counting time (counts → counts/s). XRD files only.', ...
        'ValueChangedFcn', @onAxisChanged);
    cbCountsPerSec.Layout.Column = 3;

    btnPlot = uibutton(ctrlGL,'Text','Replot','ButtonPushedFcn',@onPlot);
    btnPlot.Layout.Row = 10;

    % Row 12: Waterfall toggle + spacing field
    wfGL = uigridlayout(ctrlGL,[1 2], ...
        'Padding',[0 0 0 0],'ColumnSpacing',4,'ColumnWidth',{'1x',55});
    wfGL.Layout.Row = 12;

    cbWaterfall = uicheckbox(wfGL, ...
        'Text',    'Waterfall', ...
        'Value',   false, ...
        'Tooltip', 'Stack datasets vertically with a uniform Y offset between them', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    cbWaterfall.Layout.Column = 1;

    efWaterfallSpacing = uieditfield(wfGL, 'text', 'Value', '', ...
        'Placeholder',     'auto', ...
        'Tooltip',         'Spacing between stacked traces in data units — blank = auto (1.1× max data range)', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efWaterfallSpacing.Layout.Column = 2;

    % ── Right: preview axes ───────────────────────────────────────────────
    axPanel = uipanel(contentGL,'Title','Preview','FontSize',13);
    axPanel.Layout.Column = 2;
    axGL = uigridlayout(axPanel,[1 1],'Padding',[2 2 2 2]);
    ax = uiaxes(axGL);
    ax.Box = 'on';
    grid(ax,'on');
    title(ax,'Load a file to preview data','Interpreter','none');
    xlabel(ax,'');
    ylabel(ax,'');
    fig.WindowButtonDownFcn   = @onAxesButtonDown;  % normal mode; special modes overwrite this
    fig.WindowButtonMotionFcn = @onMouseHover;      % idle hover; drags overwrite and restore this

    % Persistent x,y readout — normalized coords so it sticks to the top-right corner
    % regardless of axis scale.  HandleVisibility='off' keeps it alive through cla().
    appData.cursorText = text(ax, 0.98, 0.97, '', ...
        'Units',              'normalized', ...
        'HorizontalAlignment','right', ...
        'VerticalAlignment',  'top', ...
        'FontSize',           11, ...
        'FontName',           'Courier New', ...
        'Color',              [0.80 0.80 0.80], ...
        'HandleVisibility',   'off', ...
        'Tag',                'GUICursorReadout', ...
        'Visible',            'off');

    % ── Analysis & Corrections panel (row 3, full width) ─────────────────
    analysisPanel = uipanel(rootGL,'Title','Analysis & Corrections','FontSize',13);
    analysisPanel.Layout.Row = 3; analysisPanel.Layout.Column = [1 2];

    analysisGL = uigridlayout(analysisPanel,[1 4], ...
        'ColumnWidth', {350, 180, '2x', 150}, ...
        'RowHeight',   {'1x'}, ...
        'Padding',     [6 6 6 6], ...
        'ColumnSpacing', 10, ...
        'RowSpacing', 6);

    % ── Corrections sub-panel (analysisGL col 1) ─────────────────────────
    % 9-row × 4-col grid:
    %   row  1  : correction style selector
    %   rows 2-3: [X Offset | BG Slope] / [Y Offset | BG Intercept]
    %   row  4  : smoothing controls
    %   row  5  : Fit BG / Est. Y Offset (generic) | XRD interactive tools
    %   row  6  : Remove Peak button (XRD only)
    %   row  7  : background file selector (Load BG)
    %   row  8  : Subtract BG checkbox + Clear BG button
    %   row  9  : Apply Corrections | Reset | Show Raw checkbox
    corrPanel = uipanel(analysisGL,'Title','Corrections','FontSize',13);
    corrPanel.Layout.Row = 1; corrPanel.Layout.Column = 1;

    corrGL = uigridlayout(corrPanel,[9 4], ...
        'RowHeight',    {24,24,24,24,24,24,24,24,28}, ...
        'ColumnWidth',  {70,'1x',88,'1x'}, ...
        'Padding',      [6 6 6 6], ...
        'RowSpacing',   4, ...
        'ColumnSpacing', 4);

    % Row 1: Correction style selector
    lblCorrStyle = uibutton(corrGL,'Text','Style:','Enable','off','FontSize',10);
    lblCorrStyle.Layout.Row = 1; lblCorrStyle.Layout.Column = 1;

    ddCorrStyle = uidropdown(corrGL, ...
        'Items',           {'Auto (from file)', 'Generic', 'Magnetometry', 'PPMS', 'XRD — 2\theta + BG'}, ...
        'Value',           'Auto (from file)', ...
        'Tooltip',         'Choose correction labels; Auto detects from the loaded file type', ...
        'ValueChangedFcn', @onCorrStyleChanged);
    ddCorrStyle.Layout.Row = 1; ddCorrStyle.Layout.Column = [2 4];

    % Row 2: X Offset | BG Slope
    lblXOff = uibutton(corrGL,'Text','X Offset:','Enable','off');
    lblXOff.Layout.Row = 2; lblXOff.Layout.Column = 1;

    efXOffset = uieditfield(corrGL,'numeric','Value',0, ...
        'Tooltip','X-offset: x_corrected = x − this value (0 = no shift)', ...
        'Limits',[-Inf Inf],'LowerLimitInclusive','off','UpperLimitInclusive','off');
    efXOffset.Layout.Row = 2; efXOffset.Layout.Column = 2;

    lblBGSlope = uibutton(corrGL,'Text','BG Slope:','Enable','off');
    lblBGSlope.Layout.Row = 2; lblBGSlope.Layout.Column = 3;

    efBGSlope = uieditfield(corrGL,'numeric','Value',0, ...
        'Tooltip','Linear BG slope m: y_BG = m·x + b  (0 = no BG subtraction)', ...
        'Limits',[-Inf Inf],'LowerLimitInclusive','off','UpperLimitInclusive','off');
    efBGSlope.Layout.Row = 2; efBGSlope.Layout.Column = 4;

    % Row 3: Y Offset | BG Intercept
    lblYOff = uibutton(corrGL,'Text','Y Offset:','Enable','off');
    lblYOff.Layout.Row = 3; lblYOff.Layout.Column = 1;

    efYOffset = uieditfield(corrGL,'numeric','Value',0, ...
        'Tooltip','Y-offset: applied after BG subtraction  (0 = no shift)', ...
        'Limits',[-Inf Inf],'LowerLimitInclusive','off','UpperLimitInclusive','off');
    efYOffset.Layout.Row = 3; efYOffset.Layout.Column = 2;

    lblBGInt = uibutton(corrGL,'Text','BG Intercept:','Enable','off');
    lblBGInt.Layout.Row = 3; lblBGInt.Layout.Column = 3;

    efBGIntercept = uieditfield(corrGL,'numeric','Value',0, ...
        'Tooltip','Linear BG intercept b: y_BG = m·x + b  (0 = no BG subtraction)', ...
        'Limits',[-Inf Inf],'LowerLimitInclusive','off','UpperLimitInclusive','off');
    efBGIntercept.Layout.Row = 3; efBGIntercept.Layout.Column = 4;

    % Row 4: Smoothing controls (all data types)
    cbSmooth = uicheckbox(corrGL, 'Text', 'Smooth', 'Value', false, ...
        'Tooltip', 'Apply smoothing to corrected data when Apply Corrections is pressed', ...
        'ValueChangedFcn', @onSmoothingChanged);
    cbSmooth.Layout.Row = 4; cbSmooth.Layout.Column = 1;

    efSmoothWin = uieditfield(corrGL, 'numeric', 'Value', 5, ...
        'Limits', [1 Inf], 'LowerLimitInclusive', 'on', ...
        'RoundFractionalValues', 'on', ...
        'Tooltip', 'Smoothing half-window in samples (total width = 2W+1 points)', ...
        'ValueChangedFcn', @onSmoothingChanged);
    efSmoothWin.Layout.Row = 4; efSmoothWin.Layout.Column = 2;

    ddSmoothMethod = uidropdown(corrGL, ...
        'Items',   {'Moving', 'Gaussian'}, ...
        'Value',   'Moving', ...
        'Tooltip', 'Moving: uniform average  |  Gaussian: bell-curve weighted average', ...
        'ValueChangedFcn', @onSmoothingChanged);
    ddSmoothMethod.Layout.Row = 4; ddSmoothMethod.Layout.Column = [3 4];

    % Row 5: Fit BG from Box | Est. Y Offset 2-click
    btnFitBG = uibutton(corrGL,'Text','Fit Linear BG from Box', ...
        'ButtonPushedFcn',@onFitBGRegion, ...
        'BackgroundColor',[0.50 0.28 0.05], ...
        'FontColor',[1 1 1], ...
        'Tooltip', ['Draw a rectangle on the preview axes.  ' ...
                    'All selected-Y data points inside the box are used to fit ' ...
                    'a linear background (polyfit deg-1).  ' ...
                    'BG Slope and Intercept are auto-populated then corrections are applied.']);
    btnFitBG.Layout.Row = 5; btnFitBG.Layout.Column = [1 2];

    btnPickY = uibutton(corrGL,'Text','Est. Y Offset  (2 pts)', ...
        'ButtonPushedFcn',@onPickYOrigin, ...
        'BackgroundColor',[0.45 0.20 0.55], ...
        'FontColor',[1 1 1], ...
        'Tooltip', ['Click two data points on the plot.  ' ...
                    'The Y Offset is updated so that y = 0 falls halfway ' ...
                    'between their y-values.  Works on whichever data is ' ...
                    'currently displayed (raw or corrected).']);
    btnPickY.Layout.Row = 5; btnPickY.Layout.Column = [3 4];

    % XRD-mode interactive tools — same row 5 cells, hidden by default.
    % applyParserAnalysisConfig() swaps visibility between these and the
    % generic (btnFitBG / btnPickY) buttons when the correction style changes.
    btnYTranslate = uibutton(corrGL,'Text','Y Translate (drag)', ...
        'ButtonPushedFcn',@onYTranslateDrag, ...
        'BackgroundColor',[0.10 0.35 0.65],'FontColor',[1 1 1], ...
        'Tooltip',['Click and drag up/down on the plot to shift the data ' ...
                   'vertically — updates Y Offset live on each mouse move.'], ...
        'Visible','off');
    btnYTranslate.Layout.Row = 5; btnYTranslate.Layout.Column = [1 2];

    btnAutoPeak = uibutton(corrGL,'Text','Auto Find Peaks', ...
        'ButtonPushedFcn',@onAutoPeak, ...
        'BackgroundColor',[0.55 0.20 0.05],'FontColor',[1 1 1], ...
        'Tooltip','Detect peaks automatically using findpeaks (Signal Processing Toolbox) or a built-in local-max fallback', ...
        'Visible','off');
    btnAutoPeak.Layout.Row = 5; btnAutoPeak.Layout.Column = 3;

    btnManualPeak = uibutton(corrGL,'Text','Add Peak', ...
        'ButtonPushedFcn',@onManualPeakAdd, ...
        'BackgroundColor',[0.45 0.20 0.55],'FontColor',[1 1 1], ...
        'Tooltip','Click once on a peak in the plot to add it to the peak list (click button again to finish)', ...
        'Visible','off');
    btnManualPeak.Layout.Row = 5; btnManualPeak.Layout.Column = 4;

    % Row 6: Remove Peak (click-to-remove mode; only visible for XRD data)
    btnRemovePeakClick = uibutton(corrGL,'Text','Remove Peak', ...
        'ButtonPushedFcn',@onRemovePeakClickMode, ...
        'BackgroundColor',[0.55 0.15 0.15],'FontColor',[1 1 1], ...
        'Tooltip','Click on a peak marker in the plot to remove it (click button again to finish)', ...
        'Visible','off');
    btnRemovePeakClick.Layout.Row = 6; btnRemovePeakClick.Layout.Column = 4;

    % Row 7: Background dataset file picker
    lblBGFile = uibutton(corrGL,'Text','BG File:','Enable','off');
    lblBGFile.Layout.Row = 7; lblBGFile.Layout.Column = 1;

    efBGFile = uieditfield(corrGL,'text','Value','', ...
        'Placeholder','— none loaded —', ...
        'Editable','off', ...
        'Tooltip','Loaded background dataset — use "Load BG..." to populate');
    efBGFile.Layout.Row = 7; efBGFile.Layout.Column = [2 3];

    btnLoadBG = uibutton(corrGL,'Text','Load BG...', ...
        'ButtonPushedFcn',@onLoadBackground, ...
        'Tooltip','Load a background file (any supported format) to subtract from corrected data');
    btnLoadBG.Layout.Row = 7; btnLoadBG.Layout.Column = 4;

    % Row 8: Subtract BG toggle + Clear
    cbSubtractBG = uicheckbox(corrGL,'Text','Subtract BG','Value',false, ...
        'Tooltip','Subtract the loaded background from corrected data when Apply Corrections is pressed');
    cbSubtractBG.Layout.Row = 8; cbSubtractBG.Layout.Column = [1 2];

    btnClearBG = uibutton(corrGL,'Text','Clear BG', ...
        'ButtonPushedFcn',@onClearBackground, ...
        'Tooltip','Remove the currently loaded background dataset');
    btnClearBG.Layout.Row = 8; btnClearBG.Layout.Column = [3 4];

    % Row 9: Apply | Reset | Show Raw
    btnApply = uibutton(corrGL,'Text','Apply Corrections', ...
        'ButtonPushedFcn',@onApplyCorrections, ...
        'BackgroundColor',[0.18 0.52 0.18], ...
        'FontColor',[1 1 1],'FontWeight','bold', ...
        'Tooltip','Compute corrected data and update plot');
    btnApply.Layout.Row = 9; btnApply.Layout.Column = [1 2];

    btnReset = uibutton(corrGL,'Text','Reset', ...
        'ButtonPushedFcn',@onResetCorrections, ...
        'Tooltip','Zero all correction fields and discard corrected data for the active dataset');
    btnReset.Layout.Row = 9; btnReset.Layout.Column = 3;

    cbShowRaw = uicheckbox(corrGL,'Text','Show Raw','Value',true, ...
        'Tooltip','When corrected data exists, also overlay raw data (dashed, desaturated)', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    cbShowRaw.Layout.Row = 9; cbShowRaw.Layout.Column = 4;

    % ── Axis Limits sub-panel (middle column) ────────────────────────────
    % All six fields are text-type: blank = auto-scale, any number = manual.
    % str2double('') == NaN, so blank naturally means "do not apply".
    axLimPanel = uipanel(analysisGL,'Title','Axis Limits','FontSize',13);
    axLimPanel.Layout.Row = 1; axLimPanel.Layout.Column = 2;

    axLimGL = uigridlayout(axLimPanel,[5 4], ...
        'RowHeight',    {22,26,26,0,32}, ...
        'ColumnWidth',  {38,'1x','1x','1x'}, ...
        'Padding',      [6 6 6 6], ...
        'RowSpacing',   4, ...
        'ColumnSpacing', 4);

    % Row 1: column header labels (Min | Max | Step)
    lblAxHdrMin  = uibutton(axLimGL,'Text','Min', 'Enable','off','FontSize',9);
    lblAxHdrMin.Layout.Row  = 1; lblAxHdrMin.Layout.Column  = 2;
    lblAxHdrMax  = uibutton(axLimGL,'Text','Max', 'Enable','off','FontSize',9);
    lblAxHdrMax.Layout.Row  = 1; lblAxHdrMax.Layout.Column  = 3;
    lblAxHdrStep = uibutton(axLimGL,'Text','Step','Enable','off','FontSize',9);
    lblAxHdrStep.Layout.Row = 1; lblAxHdrStep.Layout.Column = 4;

    % Row 2: X axis
    lblXLim = uibutton(axLimGL,'Text','X:','Enable','off');
    lblXLim.Layout.Row = 2; lblXLim.Layout.Column = 1;

    AXLIM_BG = [0.17 0.17 0.17];   % dark field background matching GUI theme
    AXLIM_FG = [0.92 0.92 0.92];   % light text for readability on dark background

    efXMin = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','X axis minimum — blank = auto-scale', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXMin.Layout.Row = 2; efXMin.Layout.Column = 2;

    efXMax = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','X axis maximum — blank = auto-scale', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXMax.Layout.Row = 2; efXMax.Layout.Column = 3;

    efXStep = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','X axis major tick spacing — blank = auto ticks', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXStep.Layout.Row = 2; efXStep.Layout.Column = 4;

    % Row 3: Y axis
    lblYLim = uibutton(axLimGL,'Text','Y:','Enable','off');
    lblYLim.Layout.Row = 3; lblYLim.Layout.Column = 1;

    efYMin = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Y axis minimum — blank = auto-scale', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYMin.Layout.Row = 3; efYMin.Layout.Column = 2;

    efYMax = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Y axis maximum — blank = auto-scale', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYMax.Layout.Row = 3; efYMax.Layout.Column = 3;

    efYStep = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Y axis major tick spacing — blank = auto ticks', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYStep.Layout.Row = 3; efYStep.Layout.Column = 4;

    % Row 4: right Y-axis limits — hidden (RowHeight=0) until Y2 channel is selected
    lblY2Lim = uibutton(axLimGL,'Text','Y2:','Enable','off');
    lblY2Lim.Layout.Row = 4; lblY2Lim.Layout.Column = 1;

    efY2Min = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Right Y-axis minimum — blank = auto-scale', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efY2Min.Layout.Row = 4; efY2Min.Layout.Column = 2;

    efY2Max = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Right Y-axis maximum — blank = auto-scale', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efY2Max.Layout.Row = 4; efY2Max.Layout.Column = 3;

    efY2Step = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Right Y-axis major tick spacing — blank = auto ticks', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efY2Step.Layout.Row = 4; efY2Step.Layout.Column = 4;

    % Row 5: clear-all button
    btnAutoLimits = uibutton(axLimGL,'Text','Auto (Clear All)', ...
        'ButtonPushedFcn',@onAutoLimits, ...
        'Tooltip','Clear all manual axis limits — return to auto-scale');
    btnAutoLimits.Layout.Row = 5; btnAutoLimits.Layout.Column = [1 4];

    % ── Save Corrected Data sub-panel (right column) ──────────────────────
    savePanel = uipanel(analysisGL,'Title','Save Corrected Data','FontSize',13);
    savePanel.Layout.Row = 1; savePanel.Layout.Column = 4;

    saveGL = uigridlayout(savePanel,[5 2], ...
        'RowHeight',    {26,32,32,32,32}, ...
        'ColumnWidth',  {'1x',100}, ...
        'Padding',      [6 6 6 6], ...
        'RowSpacing',   4, ...
        'ColumnSpacing', 4);

    efSavePath = uieditfield(saveGL,'Value','', ...
        'Placeholder','(auto-set when corrections are applied)', ...
        'Tooltip','Output CSV file path — auto-filled on Apply, or browse to choose');
    efSavePath.Layout.Row = 1; efSavePath.Layout.Column = [1 2];

    btnSaveBrowse = uibutton(saveGL,'Text','Browse...', ...
        'ButtonPushedFcn',@onSaveBrowse, ...
        'Tooltip','Choose output file location');
    btnSaveBrowse.Layout.Row = 2; btnSaveBrowse.Layout.Column = 1;

    btnSave = uibutton(saveGL,'Text','Save CSV', ...
        'ButtonPushedFcn',@onSaveCSV, ...
        'BackgroundColor',[0.15 0.37 0.63], ...
        'FontColor',[1 1 1],'FontWeight','bold', ...
        'Tooltip','Write corrected data to CSV file');
    btnSave.Layout.Row = 2; btnSave.Layout.Column = 2;

    btnExportHDF5 = uibutton(saveGL,'Text','Export HDF5...', ...
        'ButtonPushedFcn',@onExportHDF5, ...
        'BackgroundColor',[0.10 0.45 0.45], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Export data, corrections, and peaks to a self-describing HDF5 file (.h5)');
    btnExportHDF5.Layout.Row = 3; btnExportHDF5.Layout.Column = [1 2];

    btnExportFig = uibutton(saveGL,'Text','Export to Figure', ...
        'ButtonPushedFcn',@onExportFigure, ...
        'BackgroundColor',[0.30 0.30 0.60], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Open a new figure window with the current plot (full MATLAB toolbar — ideal for publication-quality editing)');
    btnExportFig.Layout.Row = 4; btnExportFig.Layout.Column = [1 2];

    btnCopyClip = uibutton(saveGL,'Text','Copy Plot to Clipboard', ...
        'ButtonPushedFcn',@onCopyToClipboard, ...
        'BackgroundColor',[0.22 0.22 0.22], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Copy the current plot as an image to the system clipboard (Windows only)');
    btnCopyClip.Layout.Row = 5; btnCopyClip.Layout.Column = [1 2];

    % ── Peak Analysis sub-panel (row 2, full width) ───────────────────────
    % Always visible; XRD buttons in corrGL activate it contextually.
    peakPanel = uipanel(analysisGL,'Title','Peak Analysis','FontSize',13);
    peakPanel.Layout.Row = 1; peakPanel.Layout.Column = 3;

    peakGL = uigridlayout(peakPanel,[1 2], ...
        'ColumnWidth', {'1x',110}, ...
        'Padding',     [6 6 6 6], ...
        'ColumnSpacing', 8);

    peakTable = uitable(peakGL, ...
        'ColumnName',     {'#','Center (°)','FWHM (°)','Height','Status'}, ...
        'ColumnWidth',    {28, 90, 78, 78, 62}, ...
        'Data',           {}, ...
        'RowName',        {}, ...
        'ColumnEditable', [false false false false false], ...
        'CellSelectionCallback', @onPeakTableSelect, ...
        'Tooltip','Detected peaks — select a row to highlight it on the plot');
    peakTable.Layout.Column = 1;

    peakBtnGL = uigridlayout(peakGL,[8 1], ...
        'RowHeight',    {20,24,24,24,24,20,24,'1x'}, ...
        'Padding',      [0 0 0 0], ...
        'RowSpacing',   4);
    peakBtnGL.Layout.Column = 2;

    ddFitModel = uidropdown(peakBtnGL, ...
        'Items',   {'Lorentzian', 'Gaussian'}, ...
        'Value',   'Lorentzian', ...
        'Tooltip', 'Peak shape model used by Fit Peaks');
    ddFitModel.Layout.Row = 1;

    btnFitPeaks = uibutton(peakBtnGL,'Text','Fit Peaks', ...
        'ButtonPushedFcn',@onFitPeaks, ...
        'BackgroundColor',[0.15 0.37 0.63],'FontColor',[1 1 1], ...
        'Tooltip','Fit the selected model to each listed peak and extract precise center and FWHM');
    btnFitPeaks.Layout.Row = 2;

    btnClearPeaks = uibutton(peakBtnGL,'Text','Clear All Peaks', ...
        'ButtonPushedFcn',@onClearPeaks, ...
        'Tooltip','Remove all peaks for the active dataset');
    btnClearPeaks.Layout.Row = 3;

    btnRemovePeak = uibutton(peakBtnGL,'Text','Remove Selected', ...
        'ButtonPushedFcn',@onRemoveSelectedPeak, ...
        'Tooltip','Remove the currently highlighted peak from the list');
    btnRemovePeak.Layout.Row = 4;

    btnSavePeaks = uibutton(peakBtnGL,'Text','Export Summary CSV', ...
        'ButtonPushedFcn',@onSavePeakSummary, ...
        'BackgroundColor',[0.30 0.30 0.60],'FontColor',[1 1 1], ...
        'Tooltip','Save peak centers and FWHM values to a CSV file');
    btnSavePeaks.Layout.Row = 5;

    chkShowFit = uicheckbox(peakBtnGL, ...
        'Text',              'Show fit curves', ...
        'Value',             true, ...
        'Tooltip',           'Overlay fit curves on the plot', ...
        'ValueChangedFcn',   @onToggleFitCurves);
    chkShowFit.Layout.Row = 6;

    btnFitColor = uibutton(peakBtnGL, 'Text', 'Fit curve color...', ...
        'Tooltip',           'Pick the color used for fit curve overlays', ...
        'ButtonPushedFcn',   @onPickFitColor);
    btnFitColor.Layout.Row = 7;
    btnFitColor.BackgroundColor = appData.fitCurveColor;

    % ── Drag-and-drop: register every major surface as a drop target (R2023a+) ──
    % In uifigure the CEF renderer consumes drag events at whichever child
    % component is under the cursor; they do NOT bubble up to the figure.
    % Registering each panel/listbox/axes individually ensures that a file
    % dropped anywhere in the window is caught.
    dropSurfaces = {ctrlPanel, axPanel, ax, analysisPanel, ...
                    corrPanel, axLimPanel, savePanel, peakPanel, lbDatasets};
    for dsi = 1:numel(dropSurfaces)
        try
            dropSurfaces{dsi}.DropFcn = @onDropFiles;
        catch
            % Component does not support DropFcn on this MATLAB version — skip
        end
    end
    clear dsi dropSurfaces;

    % ════════════════════════════════════════════════════════════════════
    %  NESTED CALLBACKS  (share appData + all control handles via closure)
    % ════════════════════════════════════════════════════════════════════

    % ── Dataset management ───────────────────────────────────────────────

    function onAddFiles(~,~)
    %ONADDFILES  Open a multi-select file dialog; load every chosen file.
        startDir = guiTernary(isempty(appData.lastDir), pwd, appData.lastDir);
        [fnames, fpath] = uigetfile( ...
            {'*.dat;*.csv;*.tsv;*.txt;*.xlsx;*.xls;*.xlsm;*.xlsb;*.ods;*.raw;*.xrdml', ...
             'Supported data files (*.dat, *.csv, *.xlsx, *.ods, *.raw, *.xrdml)'; ...
             '*.*','All files (*.*)'}, ...
            'Select data file(s)', startDir, ...
            'MultiSelect', 'on');
        if isequal(fnames, 0), return; end

        appData.lastDir = fpath;
        if ischar(fnames), fnames = {fnames}; end
        fpaths = cellfun(@(f) fullfile(fpath, f), fnames, 'UniformOutput', false);
        loadFilePaths(fpaths);
    end

    function onDropFiles(~, e)
    %ONDROPFILES  Handle files dragged from Explorer onto the figure (R2023a+).
    %  e.Data may be a char (single file), a string, or a cell array (multiple
    %  files) — normalise to a cell array before processing.
        try
            d = e.Data;
            if ischar(d) || isstring(d)
                % Single file or newline-separated list — wrap / split into cell
                fpaths = cellstr(strsplit(strtrim(char(d)), newline));
            elseif iscell(d)
                fpaths = d;
            else
                return;   % unrecognised format; nothing to do
            end
            fpaths = fpaths(~cellfun(@isempty, fpaths));
            if isempty(fpaths), return; end

            supported = {'.dat','.csv','.tsv','.txt', ...
                         '.xlsx','.xls','.xlsm','.xlsb','.ods', ...
                         '.raw','.xrdml'};
            valid = {};
            for k = 1:numel(fpaths)
                p = strtrim(char(fpaths{k}));
                [~, ~, ext] = fileparts(p);
                if isfile(p) && any(strcmpi(ext, supported))
                    valid{end+1} = p; %#ok<AGROW>
                end
            end

            if isempty(valid)
                uialert(fig, ...
                    'None of the dropped items are supported data files.', ...
                    'Unsupported file type');
                return;
            end
            loadFilePaths(valid);

        catch ME
            fprintf(2, '[dataImportGUI] DropFcn error: %s\n', ME.message);
            for si = 1:numel(ME.stack)
                fprintf(2, '  at %s (line %d)\n', ME.stack(si).name, ME.stack(si).line);
            end
        end
    end

    function loadFilePaths(fpaths)
    %LOADFILEPATHS  Import a cell array of full file paths into appData.datasets.
    %  Shared by onAddFiles (dialog) and onDropFiles (drag-and-drop).
        if isempty(fpaths), return; end
        appData.lastDir = fileparts(fpaths{1});

        nLoaded = 0;
        for fi = 1:numel(fpaths)
            fp = fpaths{fi};
            [~, fnBase, fExt] = fileparts(fp);

            % ── Excel: offer sheet selection when file has multiple sheets ──
            excelExts = {'.xlsx','.xls','.xlsm','.xlsb','.ods'};
            if any(strcmpi(fExt, excelExts))
                try
                    allSheetNames = sheetnames(fp);
                catch
                    allSheetNames = {'Sheet1'};
                end
                if numel(allSheetNames) > 1
                    selIdx = listdlg( ...
                        'PromptString', {sprintf('Sheets in  %s:', [fnBase fExt]), ...
                                         'Select sheets to import:'}, ...
                        'ListString',   allSheetNames, ...
                        'SelectionMode','multiple', ...
                        'InitialValue', 1:numel(allSheetNames), ...
                        'Name',         'Import Excel Sheets', ...
                        'ListSize',     [220 160]);
                    if isempty(selIdx), continue; end   % user cancelled this file
                    selectedSheets = allSheetNames(selIdx);
                else
                    selectedSheets = allSheetNames;
                end
                for si = 1:numel(selectedSheets)
                    shName = selectedSheets{si};
                    try
                        data       = parser.importExcel(fp, 'Sheet', shName);
                        parserName = 'importExcel';
                        ds = buildDs(fp, data, parserName);
                        ds.displayName = sprintf('%s%s [%s]', fnBase, fExt, shName);
                        appData.datasets{end+1} = ds;
                        nLoaded = nLoaded + 1;
                    catch ME
                        fprintf(2, '\n[dataImportGUI] Import error (%s [%s]): %s\n', ...
                            fnBase, shName, ME.message);
                        uialert(fig, sprintf('%s [%s]\n\n%s', fnBase, shName, ME.message), ...
                            'Import error');
                    end
                end
                continue   % skip normal single-parser path
            end

            % ── Normal single-parser import ──────────────────────────────
            try
                [data, parserName] = guiImport(fp);
                ds = buildDs(fp, data, parserName);
                appData.datasets{end+1} = ds;
                nLoaded = nLoaded + 1;
            catch ME
                fprintf(2, '\n[dataImportGUI] Import error (%s): %s\n', fnBase, ME.message);
                for si = 1:numel(ME.stack)
                    fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
                end
                uialert(fig, sprintf('%s\n\n%s', [fnBase fExt], ME.message), 'Import error');
            end
        end

        if nLoaded == 0, return; end

        % Make the last successfully loaded file the active dataset
        appData.activeIdx = numel(appData.datasets);

        cancelInteractions();
        rebuildDatasetList(true);
        updateControlsForActiveDataset();
        onPlot([],[]);
    end

    function onSelectDataset(~,~)
    %ONSELECTDATASET  Fires when the user clicks a row in lbDatasets.
        val = lbDatasets.Value;
        if isempty(val) || ~isnumeric(val) || val < 1 || ...
           val > numel(appData.datasets)
            return;
        end
        if val == appData.activeIdx, return; end   % no change

        saveAxisLimsToActiveDataset();   % persist zoom before leaving current dataset
        cancelInteractions();
        appData.activeIdx = val;
        updateControlsForActiveDataset();
        onPlot([],[]);
    end

    function onDatasetColorChanged(~,~)
    %ONDATASETCOLORCHANGED  Store colour override on the active dataset and replot.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds       = appData.datasets{appData.activeIdx};
        ds.color = ddDatasetColor.Value;   % [] = Auto; [r g b] = named colour
        appData.datasets{appData.activeIdx} = ds;
        onPlot([],[]);
    end

    function onLegendNameChanged(~,~)
    %ONLEGENDNAMECHANGED  Store custom legend label on the active dataset and replot.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds            = appData.datasets{appData.activeIdx};
        ds.legendName = efLegendName.Value;   % '' = auto (channel name)
        appData.datasets{appData.activeIdx} = ds;
        onPlot([],[]);
    end

    function onDatasetColorRChanged(~,~)
    %ONDATASETCOLORRCHANGED  Store right-axis colour override on the active dataset and replot.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds        = appData.datasets{appData.activeIdx};
        ds.colorR = ddDatasetColorR.Value;   % [] = Auto; [r g b] = named colour
        appData.datasets{appData.activeIdx} = ds;
        onPlot([],[]);
    end

    function onLegendNameRChanged(~,~)
    %ONLEGENDNAMERCHANGED  Store right-axis legend label on the active dataset and replot.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds             = appData.datasets{appData.activeIdx};
        ds.legendNameR = efLegendNameR.Value;   % '' = auto
        appData.datasets{appData.activeIdx} = ds;
        onPlot([],[]);
    end

    function onRemoveDataset(~,~)
    %ONREMOVEDATASET  Remove the active dataset from the list.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end

        cancelInteractions();
        appData.datasets(appData.activeIdx) = [];

        if isempty(appData.datasets)
            appData.activeIdx = 0;
            lbDatasets.Items     = {'(no files loaded — click  Add File(s)...  to begin)'};
            lbDatasets.ItemsData = {0};
            lbDatasets.Value     = 0;
            % Reset all controls to blank state
            ctrlPanel.Title = 'Controls';
            ddX.Items = {'(load file first)'};  ddX.Value = ddX.Items{1};
            lbY.Items = {'(load file first)'};  lbY.Value = lbY.Items(1);
            efXOffset.Value = 0;  efYOffset.Value = 0;
            efBGSlope.Value = 0;  efBGIntercept.Value = 0;
            efSavePath.Value = '';
            analysisPanel.Title = 'Analysis & Corrections';
            ddDatasetColor.Enable = 'off';
            ddDatasetColor.Value  = [];
            efLegendName.Enable   = 'off';
            efLegendName.Value    = '';
            cla(ax);
            title(ax,'Load a file to preview data','Interpreter','none');
        else
            appData.activeIdx = min(appData.activeIdx, numel(appData.datasets));
            rebuildDatasetList(true);
            updateControlsForActiveDataset();
            onPlot([],[]);
        end
    end

    function saveAxisLimsToActiveDataset()
    %SAVEAXISLIMSTOACTIVEDATASET  Copy current axis limit fields into the active dataset.
    %  Called before switching datasets so each dataset remembers its own zoom level.
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        lims.xMin  = efXMin.Value;
        lims.xMax  = efXMax.Value;
        lims.xStep = efXStep.Value;
        lims.yMin   = efYMin.Value;
        lims.yMax   = efYMax.Value;
        lims.yStep  = efYStep.Value;
        lims.y2Min  = efY2Min.Value;
        lims.y2Max  = efY2Max.Value;
        lims.y2Step = efY2Step.Value;
        appData.datasets{appData.activeIdx}.axLims = lims;
    end

    function rebuildDatasetList(keepActiveIdx)
    %REBUILDDATASETLIST  Sync lbDatasets Items/ItemsData to appData.datasets.
        N = numel(appData.datasets);
        if N == 0
            lbDatasets.Items     = {'(no files loaded — click  Add File(s)...  to begin)'};
            lbDatasets.ItemsData = {0};
            lbDatasets.Value     = 0;
            appData.activeIdx    = 0;
            return;
        end
        items = cell(1, N);
        for i = 1:N
            dsI = appData.datasets{i};
            if isfield(dsI,'displayName') && ~isempty(dsI.displayName)
                items{i} = sprintf('[%d]  %s', i, dsI.displayName);
            else
                [~, fn, fext] = fileparts(dsI.filepath);
                items{i} = sprintf('[%d]  %s%s', i, fn, fext);
            end
        end
        lbDatasets.Items     = items;
        lbDatasets.ItemsData = num2cell(1:N);
        if keepActiveIdx && appData.activeIdx >= 1 && appData.activeIdx <= N
            lbDatasets.Value = appData.activeIdx;
        else
            appData.activeIdx = 1;
            lbDatasets.Value  = 1;
        end
    end

    function cancelInteractions()
    %CANCELINTERACTIONS  Abort any in-progress interaction (BG-fit, zoom, etc.).
        fig.WindowButtonDownFcn   = @onAxesButtonDown;
        fig.WindowButtonMotionFcn = @onMouseHover;
        fig.WindowButtonUpFcn     = '';
        fig.Pointer               = 'arrow';
        appData.panelResizeDir    = '';
        appData.panelResizeStart  = [];
        appData.panelResizeOrig   = [];
        appData.listDragSrcIdx    = 0;
        appData.listDragActive    = false;
        appData.listDragStartPt   = [];
        if ~isempty(appData.bgRectPatch) && isvalid(appData.bgRectPatch)
            delete(appData.bgRectPatch);
        end
        appData.bgRectPatch       = [];
        appData.bgStartPt         = [];
        % Abort any in-progress drag-zoom
        if ~isempty(appData.zoomRectPatch) && isvalid(appData.zoomRectPatch)
            delete(appData.zoomRectPatch);
        end
        appData.zoomRectPatch     = [];
        appData.zoomStartPt       = [];
        appData.lastClickTic      = uint64(0);
        if ~isempty(appData.yOriginMarker) && isvalid(appData.yOriginMarker)
            delete(appData.yOriginMarker);
        end
        appData.yOriginMarker     = [];
        appData.yOriginClickCount = 0;
        appData.yOriginPt1        = [];
        btnFitBG.Text            = 'Fit Linear BG from Box';
        btnFitBG.BackgroundColor = [0.50 0.28 0.05];
        btnFitBG.Enable          = 'on';
        btnPickY.Text   = 'Est. Y Offset  (2 pts)';
        btnPickY.Enable = 'on';
        % Reset Y-translate state
        appData.yTranslateY0   = [];
        appData.yTranslateOff0 = 0;
        btnYTranslate.Text            = 'Y Translate (drag)';
        btnYTranslate.BackgroundColor = [0.10 0.35 0.65];
        btnYTranslate.Enable          = 'on';
        btnAutoPeak.Enable            = 'on';
        % Reset manual peak-pick mode
        if appData.peakPickMode
            appData.peakPickMode = false;
            btnManualPeak.Text            = 'Add Peak';
            btnManualPeak.BackgroundColor = [0.45 0.20 0.55];
        end
        btnManualPeak.Enable = 'on';
        % Reset peak-remove click mode
        if appData.peakRemoveMode
            appData.peakRemoveMode = false;
            btnRemovePeakClick.Text            = 'Remove Peak';
            btnRemovePeakClick.BackgroundColor = [0.55 0.15 0.15];
        end
        btnRemovePeakClick.Enable = 'on';
    end

    function updateControlsForActiveDataset()
    %UPDATECONTROLSFORACTIVEDATASET  Sync all controls to the active dataset.
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        d  = ds.data;

        % Suppress value-change callbacks during bulk update
        ddX.ValueChangedFcn  = [];
        lbY.ValueChangedFcn  = [];
        lbY2.ValueChangedFcn = [];

        ctrlPanel.Title = sprintf('Controls  —  %s', guiParserLabel(ds.parserName));

        % X dropdown: rebuild items; try to preserve the current selection
        xName     = guiXName(d.metadata);
        allLabels = [{xName}, d.labels];
        ddX.Items = allLabels;
        if ~ismember(ddX.Value, allLabels)
            ddX.Value = allLabels{1};
        end

        % Y listbox: rebuild; keep any channels that exist in this dataset
        lbY.Items = d.labels;
        if ~isempty(d.labels)
            curSel = ensureCell(lbY.Value);
            validSel = curSel(ismember(curSel, d.labels));
            if isempty(validSel)
                lbY.Value = d.labels(1);
            else
                lbY.Value = validSel;
            end
        end

        % Y2 listbox: rebuild; keep valid selections (or reset to "(none)")
        lbY2.Items = [{'(none)'}, d.labels];
        curSel2   = ensureCell(lbY2.Value);
        validSel2 = curSel2(ismember(curSel2, [{'(none)'}, d.labels]));
        if isempty(validSel2)
            lbY2.Value = {'(none)'};
        else
            lbY2.Value = validSel2;
        end

        % Enable Counts/s only for Rigaku files with a valid counting time
        ct = guiCountingTime(ds);
        cbCountsPerSec.Enable = guiTernary(ct > 0, 'on', 'off');
        if ct == 0
            cbCountsPerSec.Value = false;
        end

        % Restore this dataset's per-dataset appearance overrides
        ddDatasetColor.Enable  = 'on';
        ddDatasetColor.Value   = ds.color;
        ddDatasetColorR.Enable = 'on';
        ddDatasetColorR.Value  = guiTernary(isfield(ds,'colorR'),     ds.colorR,     []);
        efLegendName.Enable    = 'on';
        efLegendName.Value     = guiTernary(isfield(ds,'legendName'),  ds.legendName,  '');
        efLegendNameR.Enable   = 'on';
        efLegendNameR.Value    = guiTernary(isfield(ds,'legendNameR'), ds.legendNameR, '');

        % Restore this dataset's correction parameter values
        efXOffset.Value      = ds.xOff;
        efYOffset.Value      = ds.yOff;
        efBGSlope.Value      = ds.bgSlope;
        efBGIntercept.Value  = ds.bgInt;
        cbSmooth.Value       = guiTernary(isfield(ds,'smoothEnabled'), ds.smoothEnabled, false);
        efSmoothWin.Value    = guiTernary(isfield(ds,'smoothWindow'),  ds.smoothWindow,  5);
        ddSmoothMethod.Value = guiTernary(isfield(ds,'smoothMethod'),  ds.smoothMethod,  'Moving');

        % Restore per-dataset axis limits (auto-scale if not yet saved)
        if isfield(ds, 'axLims')
            efXMin.Value  = ds.axLims.xMin;
            efXMax.Value  = ds.axLims.xMax;
            efXStep.Value = ds.axLims.xStep;
            efYMin.Value  = ds.axLims.yMin;
            efYMax.Value  = ds.axLims.yMax;
            efYStep.Value = ds.axLims.yStep;
            efY2Min.Value  = guiTernary(isfield(ds.axLims,'y2Min'), ds.axLims.y2Min, '');
            efY2Max.Value  = guiTernary(isfield(ds.axLims,'y2Max'), ds.axLims.y2Max, '');
            efY2Step.Value = guiTernary(isfield(ds.axLims,'y2Step'), ds.axLims.y2Step, '');
        else
            efXMin.Value = '';  efXMax.Value = '';  efXStep.Value = '';
            efYMin.Value = '';  efYMax.Value = '';  efYStep.Value = '';
            efY2Min.Value = '';  efY2Max.Value = '';  efY2Step.Value = '';
        end

        % Show Y2 rows/columns only when a right-axis channel is active
        y2Active = ~all(strcmp(ensureCell(lbY2.Value), '(none)'));
        axLimGL.RowHeight{4}  = 26 * y2Active;
        apGL.ColumnWidth{3}   = guiTernary(y2Active, '1x', 0);
        apGL.RowHeight{1}     = guiTernary(y2Active, 20,   0);
        fmtGL.ColumnWidth{5}  = guiTernary(y2Active, 20,   0);
        fmtGL.ColumnWidth{6}  = guiTernary(y2Active, '1x', 0);

        if ~isempty(ds.corrData)
            [fp2, fn2, ~] = fileparts(ds.filepath);
            efSavePath.Value = fullfile(fp2, [fn2, '_corrected.csv']);
        else
            efSavePath.Value = '';
        end

        applyParserAnalysisConfig(resolvedCorrStyle());

        ddX.ValueChangedFcn  = @onAxisChanged;
        lbY.ValueChangedFcn  = @onAxisChanged;
        lbY2.ValueChangedFcn = @(~,~) onPlot([],[]);

        appData.selectedPeakIdx = 0;   % clear peak selection on dataset switch
        refreshPeakTable();
    end

    % ── Axis / style callbacks ────────────────────────────────────────────

    function onAxisChanged(~,~)
        if appData.activeIdx > 0 && ~isempty(appData.datasets)
            onPlot([],[]);
        end
    end

    function applyParserAnalysisConfig(pName)
    %APPLYPARSERANALYSISCONFIG  Relabel Analysis panel controls for data type.
        switch pName
            case {'importRigaku_raw', 'importXRDML'}
                analysisPanel.Title   = 'Analysis & Corrections  —  XRD';
                lblXOff.Text          = '2θ Offset (°):';
                efXOffset.Tooltip     = '2θ-offset: 2θ_corrected = 2θ − this value  (0 = no shift)';
                lblYOff.Text          = 'Intens. Floor:';
                efYOffset.Tooltip     = ['Intensity floor subtracted from all counts ' ...
                                         'after BG removal  (0 = no shift)'];
                lblBGSlope.Text       = 'BG Slope:';
                efBGSlope.Tooltip     = 'Linear BG slope m: I_BG = m·2θ + b  (0 = no BG subtraction)';
                lblBGInt.Text         = 'BG Intercept:';
                efBGIntercept.Tooltip = 'Linear BG intercept b: I_BG = m·2θ + b  (0 = no BG subtraction)';
                % Row 4: show XRD interactive tools, hide generic ones
                btnFitBG.Visible           = 'off';
                btnPickY.Visible           = 'off';
                btnYTranslate.Visible      = 'on';
                btnAutoPeak.Visible        = 'on';
                btnManualPeak.Visible      = 'on';
                btnRemovePeakClick.Visible = 'on';
                % Peak analysis panel — visible for XRD (col 3 gets flexible width)
                peakPanel.Visible          = 'on';
                analysisGL.ColumnWidth     = {appData.corrPanelWidth, appData.axLimPanelWidth, '2x', 150};

            case 'importQDVSM'
                analysisPanel.Title   = 'Analysis & Corrections  —  VSM';
                lblXOff.Text          = 'Field Offset:';
                efXOffset.Tooltip     = 'Field offset: H_corrected = H − this value  (0 = no shift)';
                lblYOff.Text          = 'Moment Offset:';
                efYOffset.Tooltip     = ['Moment baseline shift applied after BG subtraction ' ...
                                         '(0 = no shift)'];
                lblBGSlope.Text       = 'Diamag. Slope:';
                efBGSlope.Tooltip     = ['Diamagnetic susceptibility slope χ: M_BG = χ·H + b' ...
                                         '  (0 = no subtraction)'];
                lblBGInt.Text         = 'BG Intercept:';
                efBGIntercept.Tooltip = 'Diamagnetic intercept b: M_BG = χ·H + b  (0 = no subtraction)';
                btnFitBG.Visible           = 'on';
                btnPickY.Visible           = 'on';
                btnYTranslate.Visible      = 'off';
                btnAutoPeak.Visible        = 'off';
                btnManualPeak.Visible      = 'off';
                btnRemovePeakClick.Visible = 'off';
                % Peak analysis panel — hidden for VSM (col 3 collapses; axlim expands)
                peakPanel.Visible          = 'off';
                analysisGL.ColumnWidth     = {350, '1x', 0, 150};

            case 'importPPMS'
                analysisPanel.Title   = 'Analysis & Corrections  —  PPMS';
                lblXOff.Text          = 'X Offset:';
                efXOffset.Tooltip     = 'X-offset: x_corrected = x − this value  (0 = no shift)';
                lblYOff.Text          = 'Y Offset:';
                efYOffset.Tooltip     = 'Y baseline shift applied after BG subtraction  (0 = no shift)';
                lblBGSlope.Text       = 'BG Slope:';
                efBGSlope.Tooltip     = 'Linear BG slope m: y_BG = m·x + b  (0 = no BG subtraction)';
                lblBGInt.Text         = 'BG Intercept:';
                efBGIntercept.Tooltip = 'Linear BG intercept b: y_BG = m·x + b  (0 = no BG subtraction)';
                btnFitBG.Visible           = 'on';
                btnPickY.Visible           = 'on';
                btnYTranslate.Visible      = 'off';
                btnAutoPeak.Visible        = 'off';
                btnManualPeak.Visible      = 'off';
                btnRemovePeakClick.Visible = 'off';
                % Peak analysis panel — hidden for PPMS (col 3 collapses; axlim expands)
                peakPanel.Visible          = 'off';
                analysisGL.ColumnWidth     = {350, '1x', 0, 150};

            otherwise  % importCSV, importExcel, unknown — generic labels
                analysisPanel.Title   = 'Analysis & Corrections';
                lblXOff.Text          = 'X Offset:';
                efXOffset.Tooltip     = 'X-offset: x_corrected = x − this value  (0 = no shift)';
                lblYOff.Text          = 'Y Offset:';
                efYOffset.Tooltip     = 'Y-offset: applied after BG subtraction  (0 = no shift)';
                lblBGSlope.Text       = 'BG Slope:';
                efBGSlope.Tooltip     = 'Linear BG slope m: y_BG = m·x + b  (0 = no BG subtraction)';
                lblBGInt.Text         = 'BG Intercept:';
                efBGIntercept.Tooltip = 'Linear BG intercept b: y_BG = m·x + b  (0 = no BG subtraction)';
                btnFitBG.Visible           = 'on';
                btnPickY.Visible           = 'on';
                btnYTranslate.Visible      = 'off';
                btnAutoPeak.Visible        = 'off';
                btnManualPeak.Visible      = 'off';
                btnRemovePeakClick.Visible = 'off';
                % Peak analysis panel — hidden for generic data (col 3 collapses; axlim expands)
                peakPanel.Visible          = 'off';
                analysisGL.ColumnWidth     = {appData.corrPanelWidth, '1x', 0, 150};
        end
    end

    function pName = resolvedCorrStyle()
    %RESOLVEDCORRSTYLE  Map ddCorrStyle dropdown value to a parser name string.
    %  'Auto (from file)' → use the active dataset's actual parserName.
    %  All other choices → return a fixed parser name that drives the labels.
        switch ddCorrStyle.Value
            case 'Magnetometry'
                pName = 'importQDVSM';
            case 'PPMS'
                pName = 'importPPMS';
            case 'XRD — 2\theta + BG'
                pName = 'importRigaku_raw';
            case 'Generic'
                pName = 'importCSV';
            otherwise  % 'Auto (from file)'
                if appData.activeIdx >= 1 && ~isempty(appData.datasets)
                    pName = appData.datasets{appData.activeIdx}.parserName;
                else
                    pName = '';
                end
        end
    end

    function onCorrStyleChanged(~,~)
        applyParserAnalysisConfig(resolvedCorrStyle());
    end

    % ── Y-translate drag (XRD) ───────────────────────────────────────────

    function onYTranslateDrag(~,~)
    %ONYTRANSLATEDRAG  Arm click-drag to shift the data vertically in real time.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        cancelInteractions();
        btnYTranslate.Text            = 'Drag on plot to translate...';
        btnYTranslate.BackgroundColor = [0.00 0.55 0.80];
        btnYTranslate.Enable          = 'off';
        btnAutoPeak.Enable            = 'off';
        btnManualPeak.Enable          = 'off';
        fig.WindowButtonDownFcn = @onYTransDown;
    end

    function onYTransDown(~,~)
        cp = ax.CurrentPoint;
        x0 = cp(1,1);  y0 = cp(1,2);
        if x0 < ax.XLim(1) || x0 > ax.XLim(2) || ...
           y0 < ax.YLim(1) || y0 > ax.YLim(2)
            return;
        end
        appData.yTranslateY0   = y0;
        appData.yTranslateOff0 = efYOffset.Value;
        fig.WindowButtonMotionFcn = @onYTransMove;
        fig.WindowButtonUpFcn     = @onYTransUp;
    end

    function onYTransMove(~,~)
        if isempty(appData.yTranslateY0), return; end
        cp = ax.CurrentPoint;
        dy = cp(1,2) - appData.yTranslateY0;
        % Moving data UP (dy > 0 in axes units) → subtract more → yOff decreases
        % y_corrected = yRaw - BG - yOff   =>   increase y_corr by dy => reduce yOff by dy
        efYOffset.Value = appData.yTranslateOff0 - dy;
        onApplyCorrections([],[]);
    end

    function onYTransUp(~,~)
        fig.WindowButtonDownFcn   = @onAxesButtonDown;
        fig.WindowButtonMotionFcn = @onMouseHover;
        fig.WindowButtonUpFcn     = '';
        appData.yTranslateY0 = [];
        btnYTranslate.Text            = 'Y Translate (drag)';
        btnYTranslate.BackgroundColor = [0.10 0.35 0.65];
        btnYTranslate.Enable          = 'on';
        btnAutoPeak.Enable            = 'on';
        btnManualPeak.Enable          = 'on';
    end

    % ── Auto peak find (XRD) ─────────────────────────────────────────────

    function onAutoPeak(~,~)
    %ONAUTOPEAK  Two-pass peak detection: global auto-find + forced local search
    %            at any pre-existing manual seeds missed by the global pass.
    %
    %  Pass 1 — global findpeaks with a 5%-prominence threshold.
    %  Pass 2 — for each manual seed NOT within 0.5% of an auto-found peak,
    %            run a local unconstrained search in a ±2% x-window and force
    %            that location into the merged list regardless of prominence.
    %  Output  — ds.peaks is REPLACED (not appended) with the deduplicated,
    %            centre-sorted merged result so repeated presses stay clean.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};
        d  = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);

        % ── Resolve x / y vectors ─────────────────────────────────────────
        xSel  = ddX.Value;
        xName = guiXName(d.metadata);
        if strcmp(xSel, xName)
            xv = double(d.time);
        else
            idx2 = find(strcmp(d.labels, xSel), 1);
            xv   = guiTernary(isempty(idx2), double(d.time), d.values(:,idx2));
        end
        ySel = ensureCell(lbY.Value);
        yIdx = find(strcmp(d.labels, ySel{1}), 1);
        if isempty(yIdx)
            uialert(fig,'Could not find selected Y channel.','Auto Peaks'); return;
        end
        yv    = d.values(:, yIdx);
        valid = ~isnan(xv) & ~isnan(yv);
        xv = xv(valid);  yv = yv(valid);
        if numel(xv) < 5
            uialert(fig,'Too few valid data points for peak detection.','Auto Peaks'); return;
        end

        % ── Restrict to visible x-range if limits are set ─────────────────
        % This lets users exclude sloping background regions (e.g., low-angle
        % XRD background) simply by zooming into the region of interest first.
        xMinLim = str2double(efXMin.Value);
        xMaxLim = str2double(efXMax.Value);
        if ~isnan(xMinLim) && ~isnan(xMaxLim) && xMinLim < xMaxLim
            inView = xv >= xMinLim & xv <= xMaxLim;
            if sum(inView) >= 5   % only restrict if the window contains enough data
                xv = xv(inView);
                yv = yv(inView);
            end
        end

        xSpan = diff([min(xv), max(xv)]);

        PEAK_MIN_PROM_FRAC  = 0.05;   % min prominence as fraction of y-range
        PEAK_MIN_DIST_FRAC  = 0.01;   % min separation as fraction of x-span
        PEAK_SEP_TOL_FRAC   = 0.005;  % seeds closer than this fraction of x-span are merged
        PEAK_LOCAL_WIN_FRAC = 0.02;   % ±fraction of x-span for missed-seed local search

        % ── Save existing manual seeds BEFORE rebuilding the list ─────────
        if ~isempty(ds.peaks) && isfield(ds.peaks, 'status')
            isManual     = strcmp({ds.peaks.status}, 'manual');
            manualSeeds  = ds.peaks(isManual);
        else
            manualSeeds  = struct('center',{},'fwhm',{},'height',{}, ...
                                  'xRange',{},'status',{});
        end

        % ── Pass 1: global auto-detection ────────────────────────────────
        minProm = (max(yv) - min(yv)) * PEAK_MIN_PROM_FRAC;
        minDist = xSpan * PEAK_MIN_DIST_FRAC;
        try
            [pkH, pkX, pkW, ~] = findpeaks(yv, xv, ...
                'MinPeakProminence', minProm, ...
                'MinPeakDistance',   minDist, ...
                'WidthReference',    'halfprom');
        catch
            [pkX, pkH, pkW] = simplePeakFind(xv, yv, minProm, minDist);
        end

        % Build initial merged list from auto results
        merged = struct('center',{},'fwhm',{},'height',{},'xRange',{},'status',{},'bg',{},'model',{});
        for pi = 1:numel(pkX)
            newPk.center = pkX(pi);
            newPk.fwhm   = pkW(pi);
            newPk.height = pkH(pi);
            newPk.xRange = [];
            newPk.status = 'auto';
            newPk.bg     = NaN;
            newPk.model  = '';
            merged(end+1) = newPk;  %#ok<AGROW>
        end

        % ── Pass 2: force local search at missed manual seeds ─────────────
        % "Missed" = no auto peak within minSep of the seed's centre.
        minSep  = xSpan * PEAK_SEP_TOL_FRAC;
        halfWin = xSpan * PEAK_LOCAL_WIN_FRAC;

        for si = 1:numel(manualSeeds)
            seedX = manualSeeds(si).center;

            % Skip if an auto peak already covers this seed
            if ~isempty(merged)
                if any(abs([merged.center] - seedX) <= minSep)
                    continue;
                end
            end

            % Local unconstrained search within the window
            inWin = xv >= (seedX - halfWin) & xv <= (seedX + halfWin);
            if ~any(inWin)
                % Seed is outside data — preserve as-is
                merged(end+1) = manualSeeds(si);  %#ok<AGROW>
                continue;
            end
            xWin = xv(inWin);  yWin = yv(inWin);

            try
                % No prominence filter — pick closest local max to seed
                [lH, lX, lW, ~] = findpeaks(yWin, xWin, 'SortStr', 'none');
                if isempty(lX)
                    [lH, mi] = max(yWin);  lX = xWin(mi);  lW = halfWin * 0.5;
                else
                    [~, ci] = min(abs(lX - seedX));
                    lH = lH(ci);  lX = lX(ci);  lW = lW(ci);
                end
            catch
                [lH, mi] = max(yWin);  lX = xWin(mi);  lW = halfWin * 0.5;
            end

            newPk.center = lX;
            newPk.fwhm   = lW;
            newPk.height = lH;
            newPk.xRange = [];
            newPk.status = 'manual';   % retains 'manual' — forced by seed
            newPk.bg     = NaN;
            newPk.model  = '';
            merged(end+1) = newPk;  %#ok<AGROW>
        end

        if isempty(merged)
            uialert(fig, ...
                ['No peaks found. ' ...
                 'Add manual seeds with the Add Peak button, or adjust ' ...
                 'axis limits to zoom in on the region of interest.'], ...
                'Auto Peaks');
            return;
        end

        % ── Deduplicate and sort by centre position ───────────────────────
        merged = deduplicatePeaks(merged, minSep);
        [~, ord] = sort([merged.center]);
        ds.peaks = merged(ord);

        appData.datasets{appData.activeIdx} = ds;
        refreshPeakTable();
        onPlot([],[]);
    end

    % ── Manual peak add (click mode) ─────────────────────────────────────

    function onManualPeakAdd(~,~)
    %ONMANUALPEAKADD  Toggle click-to-add-peak mode.
        if appData.peakPickMode
            % Already active — cancel
            cancelInteractions(); return;
        end
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        cancelInteractions();
        appData.peakPickMode          = true;
        btnManualPeak.Text            = 'Done Adding (click again)';
        btnManualPeak.BackgroundColor = [0.65 0.10 0.65];
        fig.WindowButtonDownFcn       = @onManualPeakClick;
    end

    function onManualPeakClick(~,~)
    %ONMANUALPEAKCLICK  Record a click on the plot as a peak seed.
        cp     = ax.CurrentPoint;
        xClick = cp(1,1);  yClick = cp(1,2);
        if xClick < ax.XLim(1) || xClick > ax.XLim(2) || ...
           yClick < ax.YLim(1) || yClick > ax.YLim(2)
            return;
        end

        ds = appData.datasets{appData.activeIdx};
        d  = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);

        % Resolve x/y vectors (same logic as onAutoPeak)
        xSel  = ddX.Value;
        xName = guiXName(d.metadata);
        if strcmp(xSel, xName)
            xv = double(d.time);
        else
            idx2 = find(strcmp(d.labels, xSel), 1);
            xv   = guiTernary(isempty(idx2), double(d.time), d.values(:,idx2));
        end
        ySel = ensureCell(lbY.Value);
        yIdx = find(strcmp(d.labels, ySel{1}), 1);
        if isempty(yIdx), return; end
        yv = d.values(:, yIdx);

        % Search within 3 % of x-axis range of click for local maximum
        xWin  = diff(ax.XLim) * 0.03;
        inWin = xv >= (xClick - xWin) & xv <= (xClick + xWin) & ~isnan(yv);
        if any(inWin)
            [pkH, maxI] = max(yv(inWin));
            xInWin      = xv(inWin);
            pkX         = xInWin(maxI);
        else
            pkX = xClick;
            pkH = yClick;
        end

        newPk.center = pkX;
        newPk.fwhm   = NaN;
        newPk.height = pkH;
        newPk.xRange = [];
        newPk.status = 'manual';
        newPk.bg     = NaN;
        newPk.model  = '';
        ds.peaks(end+1) = newPk;
        appData.datasets{appData.activeIdx} = ds;

        refreshPeakTable();
        onPlot([],[]);
        % Stay in pick mode — user presses button again to stop
    end

    function onRemovePeakClickMode(~,~)
    %ONREMOVEPEAKCLICKMODE  Toggle click-to-remove-peak mode.
        if appData.peakRemoveMode
            % Already active — cancel
            cancelInteractions(); return;
        end
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};
        if isempty(ds.peaks)
            uialert(fig,'No peaks to remove.','No peaks'); return;
        end
        cancelInteractions();
        appData.peakRemoveMode          = true;
        btnRemovePeakClick.Text            = 'Done Removing (click again)';
        btnRemovePeakClick.BackgroundColor = [0.80 0.10 0.10];
        fig.WindowButtonDownFcn            = @onRemovePeakClick;
    end

    function onRemovePeakClick(~,~)
    %ONREMOVEPEAKCLICK  Remove the peak whose centre is closest to the click.
        cp     = ax.CurrentPoint;
        xClick = cp(1,1);  yClick = cp(1,2);
        if xClick < ax.XLim(1) || xClick > ax.XLim(2) || ...
           yClick < ax.YLim(1) || yClick > ax.YLim(2)
            return;
        end

        ds = appData.datasets{appData.activeIdx};
        if isempty(ds.peaks), return; end

        % Find the peak whose centre is nearest to the click x-position.
        % Tolerance: 3 % of the visible x-axis width.
        centers = [ds.peaks.center];
        dists   = abs(centers - xClick);
        [minD, idx] = min(dists);
        tol = diff(ax.XLim) * 0.03;
        if minD > tol, return; end  % click is not near any peak — ignore

        ds.peaks(idx) = [];
        appData.datasets{appData.activeIdx} = ds;
        appData.selectedPeakIdx = 0;
        refreshPeakTable();
        onPlot([],[]);
        % Stay in remove mode — user presses button again to stop
    end

    % ── Peak fitter ───────────────────────────────────────────────────────

    function onFitPeaks(~,~)
    %ONFITPEAKS  Fit a Lorentzian to each entry in ds.peaks to refine center/FWHM.
    %  Lorentzian model: H / (1 + 4*((x - x0)/fwhm)^2) + bg
    %  Fitted parameters: [H, x0, fwhm, bg].  Uses fminsearch (no toolbox needed).
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};
        if isempty(ds.peaks)
            uialert(fig,'No peaks to fit.  Use Auto Find Peaks or Add Peak first.','No peaks'); return;
        end

        d    = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        xSel = ddX.Value;
        xName = guiXName(d.metadata);
        if strcmp(xSel, xName)
            xv = double(d.time);
        else
            idx2 = find(strcmp(d.labels, xSel), 1);
            xv   = guiTernary(isempty(idx2), double(d.time), d.values(:,idx2));
        end
        ySel = ensureCell(lbY.Value);
        yIdx = find(strcmp(d.labels, ySel{1}), 1);
        if isempty(yIdx), uialert(fig,'Could not find Y channel.','Fit Peaks'); return; end
        yv = d.values(:, yIdx);

        valid = ~isnan(xv) & ~isnan(yv);
        xv = xv(valid);  yv = yv(valid);
        xSpan = diff([min(xv), max(xv)]);

        FIT_HALFWIDTH_MULT  = 3.0;    % fit window = ±(this × FWHM)
        FIT_FALLBACK_WIN    = 0.03;   % fallback half-window as fraction of x-span
        FIT_INIT_WIDTH_FRAC = 0.3;    % initial FWHM guess: this × window width
        FIT_MAX_FWHM_FRAC   = 0.5;    % reject fit if FWHM exceeds this × x-span
        FIT_EXPAND_WIN      = 0.025;  % expanded window fraction when < 5 pts in window

        switch ddFitModel.Value
            case 'Gaussian'
                modelFun = @(p,x) p(1) .* exp(-4.*log(2).*((x-p(2))./p(3)).^2) + p(4);
            otherwise  % 'Lorentzian' (default)
                modelFun = @(p,x) p(1) ./ (1 + 4.*((x - p(2))./p(3)).^2) + p(4);
        end
        opts = optimset('Display','off','MaxIter',8000,'TolX',1e-10,'TolFun',1e-14);

        nFailed = 0;
        for pi = 1:numel(ds.peaks)
            pk = ds.peaks(pi);

            % ── Determine fit window ──────────────────────────────────────
            if ~isempty(pk.xRange) && numel(pk.xRange) == 2
                xLo = pk.xRange(1);  xHi = pk.xRange(2);
            elseif ~isnan(pk.fwhm) && pk.fwhm > 0
                hw   = FIT_HALFWIDTH_MULT * pk.fwhm;
                xLo  = pk.center - hw;
                xHi  = pk.center + hw;
            else
                hw   = xSpan * FIT_FALLBACK_WIN;
                xLo  = pk.center - hw;
                xHi  = pk.center + hw;
            end

            inWin = xv >= xLo & xv <= xHi;
            if sum(inWin) < 5
                % Expand window
                inWin = xv >= (pk.center - xSpan*FIT_EXPAND_WIN) & ...
                        xv <= (pk.center + xSpan*FIT_EXPAND_WIN);
            end
            if sum(inWin) < 4, nFailed = nFailed + 1; continue; end

            xFit = xv(inWin);  yFit = yv(inWin);
            [H0, maxI] = max(yFit);
            x0_0  = xFit(maxI);
            fw0   = max(diff([min(xFit), max(xFit)]) * FIT_INIT_WIDTH_FRAC, (xFit(2)-xFit(1))*2);
            bg0   = min(yFit);

            objFun = @(p) sum((modelFun(p, xFit) - yFit).^2);
            try
                pFit = fminsearch(objFun, [H0, x0_0, fw0, bg0], opts);
                fwhmFit = abs(pFit(3));
                % Accept only if center is inside fit window and fwhm is sane
                if pFit(2) >= xLo && pFit(2) <= xHi && ...
                   fwhmFit > 0     && fwhmFit < xSpan * FIT_MAX_FWHM_FRAC
                    ds.peaks(pi).center = pFit(2);
                    ds.peaks(pi).fwhm   = fwhmFit;
                    ds.peaks(pi).height = pFit(1);   % amplitude H above background
                    ds.peaks(pi).bg     = pFit(4);   % background level at peak
                    ds.peaks(pi).status = 'fitted';
                    ds.peaks(pi).model  = ddFitModel.Value;
                else
                    nFailed = nFailed + 1;
                end
            catch
                nFailed = nFailed + 1;
            end
        end

        appData.datasets{appData.activeIdx} = ds;
        refreshPeakTable();
        onPlot([],[]);

        if nFailed > 0
            uialert(fig, sprintf('%d peak(s) could not be fitted — try Add Peak to refine seeds.', nFailed), 'Fit Warning');
        end
    end

    % ── Peak list management ─────────────────────────────────────────────

    function onClearPeaks(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        cancelInteractions();
        ds       = appData.datasets{appData.activeIdx};
        ds.peaks = struct('center',{},'fwhm',{},'height',{},'xRange',{},'status',{},'bg',{},'model',{});
        appData.datasets{appData.activeIdx} = ds;
        appData.selectedPeakIdx = 0;
        refreshPeakTable();
        onPlot([],[]);
    end

    function onRemoveSelectedPeak(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        pi = appData.selectedPeakIdx;
        if pi < 1, return; end
        cancelInteractions();
        ds = appData.datasets{appData.activeIdx};
        if pi > numel(ds.peaks), return; end
        ds.peaks(pi) = [];
        appData.datasets{appData.activeIdx} = ds;
        appData.selectedPeakIdx = 0;
        refreshPeakTable();
        onPlot([],[]);
    end

    function onPeakTableSelect(~, evt)
    %ONPEAKTABLESELECT  Highlight the selected peak on the plot.
        if ~isempty(evt.Indices)
            appData.selectedPeakIdx = evt.Indices(1,1);
        else
            appData.selectedPeakIdx = 0;
        end
        onPlot([],[]);
    end

    function refreshPeakTable()
    %REFRESHPEAKTABLE  Sync peakTable.Data from the active dataset's ds.peaks.
        if isempty(appData.datasets) || appData.activeIdx < 1
            peakTable.Data = {}; return;
        end
        ds = appData.datasets{appData.activeIdx};
        n  = numel(ds.peaks);
        if n == 0
            peakTable.Data = {}; return;
        end
        tbl = cell(n, 5);
        for pi = 1:n
            pk        = ds.peaks(pi);
            tbl{pi,1} = pi;
            tbl{pi,2} = sprintf('%.4f', pk.center);
            tbl{pi,3} = guiTernary(isnan(pk.fwhm) || pk.fwhm <= 0, '—', sprintf('%.4f', pk.fwhm));
            tbl{pi,4} = sprintf('%.4g',  pk.height);
            tbl{pi,5} = pk.status;
        end
        peakTable.Data = tbl;
    end

    % ── Peak summary export ───────────────────────────────────────────────

    function onSavePeakSummary(~,~)
    %ONSAVEPEAKSUMMARY  Write peak centers and FWHM values to a CSV file.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};
        if isempty(ds.peaks)
            uialert(fig,'No peaks to export.  Find or add peaks first.','No peaks'); return;
        end

        [~, fn, ~] = fileparts(ds.filepath);
        defPath    = fullfile(fileparts(ds.filepath), [fn, '_peaks.csv']);
        [fname, fpath] = uiputfile({'*.csv','CSV files (*.csv)'}, ...
            'Save peak summary as...', defPath);
        if isequal(fname,0), return; end

        fp  = fullfile(fpath, fname);
        fid = -1;
        try
            fid = fopen(fp, 'w');
            if fid < 0, error('Cannot open file for writing: %s', fp); end
            fprintf(fid, 'Peak,Center_deg,FWHM_deg,Height,Status\n');
            for pi = 1:numel(ds.peaks)
                pk     = ds.peaks(pi);
                fwhmStr = guiTernary(isnan(pk.fwhm), '', sprintf('%.6f', pk.fwhm));
                fprintf(fid, '%d,%.6f,%s,%.6g,%s\n', ...
                    pi, pk.center, fwhmStr, pk.height, pk.status);
            end
            fclose(fid);
            uialert(fig, sprintf('Saved:\n%s', fp), 'Peak Summary Exported');
        catch ME
            if fid >= 0, fclose(fid); end
            uialert(fig, ME.message, 'Save error');
        end
    end

    % ── Fit curve visibility / color ─────────────────────────────────────

    function onToggleFitCurves(src, ~)
    %ONTOGGLEFITCURVES  Show or hide Lorentzian fit overlays on the plot.
        appData.showFitCurves = src.Value;
        onPlot([],[]);
    end

    function onPickFitColor(~, ~)
    %ONPICKFITCOLOR  Open a colour picker and apply the chosen colour to fit overlays.
        c = uisetcolor(appData.fitCurveColor, 'Fit Curve Color');
        if numel(c) == 3          % user didn't cancel (cancel returns 0)
            appData.fitCurveColor       = c;
            btnFitColor.BackgroundColor = c;
            onPlot([],[]);
        end
    end

    function onStylePick(styleName)
        appData.style = styleName;
        allBtns   = {btnStyleLine, btnStyleScatter, btnStyleLineMarkers};
        allStyles = {'Line', 'Scatter', 'Line+Pts'};
        for i = 1:3
            if strcmp(allStyles{i}, styleName)
                allBtns{i}.BackgroundColor = [0.20 0.50 0.20];
                allBtns{i}.FontColor       = [1 1 1];
            else
                allBtns{i}.BackgroundColor = [0.94 0.94 0.94];
                allBtns{i}.FontColor       = [0 0 0];
            end
        end
        if appData.activeIdx > 0 && ~isempty(appData.datasets)
            onPlot([],[]);
        end
    end

    % ── Corrections callbacks ─────────────────────────────────────────────

    function onApplyCorrections(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end
        ds       = appData.datasets{appData.activeIdx};
        d        = ds.data;
        xOff     = efXOffset.Value;
        yOff     = efYOffset.Value;
        bgSlope  = efBGSlope.Value;
        bgIntcpt = efBGIntercept.Value;

        % Build corrected data struct (value-copy, then override time/values)
        corrData = d;

        % Correct x axis (datetime x-offset not supported — leave unchanged)
        if isdatetime(d.time)
            corrData.time = d.time;
        else
            corrData.time = d.time - xOff;
        end

        % Correct all y channels:
        %   y_corrected = y_raw - (bgSlope * x_raw + bgIntcpt) - yOff
        % BG is evaluated at RAW x so the fitted BG level is consistent.
        for k = 1:size(d.values, 2)
            yRaw = d.values(:, k);
            if isdatetime(d.time)
                xForBG = (1:numel(yRaw))';
            else
                xForBG = double(d.time);
            end
            yBG = bgSlope .* xForBG + bgIntcpt;
            corrData.values(:, k) = yRaw - yBG - yOff;
        end

        % Subtract background dataset (interpolated to corrected x-axis).
        % Uses the first channel of the background data; values outside the
        % background x-range are extrapolated as 0 (no subtraction).
        if cbSubtractBG.Value && ~isempty(appData.bgDataset)
            bgDs = appData.bgDataset;
            if ~isdatetime(bgDs.time) && ~isdatetime(corrData.time)
                bgX = double(bgDs.time);
                bgY = bgDs.values(:, 1);
                bgInterp = interp1(bgX, bgY, double(corrData.time), ...
                                   'linear', 0);   % 0 outside BG range
                for k = 1:size(corrData.values, 2)
                    corrData.values(:, k) = corrData.values(:, k) - bgInterp;
                end
            end
        end

        % Apply smoothing (after all other corrections, on all Y channels)
        if cbSmooth.Value
            win = max(1, round(efSmoothWin.Value));
            corrData.values = utilities.smoothData(corrData.values, ...
                'Window', win, 'Method', lower(ddSmoothMethod.Value));
        end

        ds.corrData      = corrData;
        ds.xOff          = xOff;
        ds.yOff          = yOff;
        ds.bgSlope       = bgSlope;
        ds.bgInt         = bgIntcpt;
        ds.smoothEnabled = cbSmooth.Value;
        ds.smoothWindow  = efSmoothWin.Value;
        ds.smoothMethod  = ddSmoothMethod.Value;
        appData.datasets{appData.activeIdx} = ds;

        % Auto-set the save path for the active dataset
        [fpath, fname, ~] = fileparts(ds.filepath);
        efSavePath.Value = fullfile(fpath, [fname, '_corrected.csv']);

        onPlot([],[]);
    end

    function onResetCorrections(~,~)
        efXOffset.Value     = 0;
        efYOffset.Value     = 0;
        efBGSlope.Value     = 0;
        efBGIntercept.Value = 0;
        cbSmooth.Value      = false;
        efSmoothWin.Value   = 5;
        ddSmoothMethod.Value = 'Moving';
        efSavePath.Value    = '';

        if appData.activeIdx >= 1 && ~isempty(appData.datasets)
            ds               = appData.datasets{appData.activeIdx};
            ds.corrData      = [];
            ds.xOff          = 0;
            ds.yOff          = 0;
            ds.bgSlope       = 0;
            ds.bgInt         = 0;
            ds.smoothEnabled = false;
            ds.smoothWindow  = 5;
            ds.smoothMethod  = 'Moving';
            ds.peaks         = struct('center',{},'fwhm',{},'height',{}, ...
                                      'xRange',{},'status',{},'bg',{},'model',{});
            appData.datasets{appData.activeIdx} = ds;
            appData.selectedPeakIdx = 0;
        end

        cancelInteractions();
        refreshPeakTable();
        onPlot([],[]);
    end

    function onLoadBackground(~,~)
    %ONLOADBACKGROUND  Open file dialog and load a background dataset via importAuto.
        startDir = guiTernary(isempty(appData.lastDir), pwd, appData.lastDir);
        [fname, fpath] = uigetfile( ...
            {'*.dat;*.csv;*.tsv;*.txt;*.xlsx;*.xls;*.xlsm;*.xlsb;*.ods;*.raw;*.xrdml', ...
             'Supported data files'; '*.*','All files (*.*)'}, ...
            'Select background file', startDir);
        if isequal(fname, 0), return; end
        fullPath = fullfile(fpath, fname);
        try
            bgData = parser.importAuto(fullPath);
        catch ME
            uialert(fig, ME.message, 'Background Load Error');
            return;
        end
        appData.bgDataset = bgData;
        appData.bgFile    = fname;
        efBGFile.Value    = fname;
        cbSubtractBG.Value = true;   % auto-enable subtraction on load
    end

    function onClearBackground(~,~)
    %ONCLEARBACKGROUND  Remove the loaded background dataset.
        appData.bgDataset  = [];
        appData.bgFile     = '';
        efBGFile.Value     = '';
        cbSubtractBG.Value = false;
    end

    function onSmoothingChanged(~,~)
    %ONSMOOTHINGCHANGED  Re-apply corrections whenever smoothing controls change.
        if ~isempty(appData.datasets) && appData.activeIdx >= 1
            onApplyCorrections([],[]);
        end
    end

    % ── BG rubber-band fit ────────────────────────────────────────────────

    function onFitBGRegion(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end

        % ── Resolve and cache raw x vector ───────────────────────────────
        d     = appData.datasets{appData.activeIdx}.data;
        xSel  = ddX.Value;
        xName = guiXName(d.metadata);
        if strcmp(xSel, xName)
            xv = d.time;
        else
            idx2 = find(strcmp(d.labels, xSel), 1);
            xv   = guiTernary(isempty(idx2), d.time, d.values(:,idx2));
        end

        if isdatetime(xv)
            uialert(fig, ...
                'Datetime x-axis: cannot fit a numeric linear BG.  Use a numeric X channel.', ...
                'Not supported');
            return;
        end

        appData.bgXVecRaw   = xv;
        appData.bgStartPt   = [];
        appData.bgRectPatch = [];

        % Cancel any in-progress y-origin pick before arming BG callbacks
        cancelInteractions();

        % Arm BG interaction (cancelInteractions re-enabled btnFitBG — disable again)
        btnPickY.Enable          = 'off';
        btnFitBG.Text            = 'Click & drag on the plot to select BG region...';
        btnFitBG.BackgroundColor = [0.80 0.45 0.00];
        btnFitBG.Enable          = 'off';

        fig.WindowButtonDownFcn = @onBGMouseDown;
    end

    function onBGMouseDown(~,~)
        cp = ax.CurrentPoint;
        x0 = cp(1,1);   y0 = cp(1,2);

        if x0 < ax.XLim(1) || x0 > ax.XLim(2) || ...
           y0 < ax.YLim(1) || y0 > ax.YLim(2)
            return;
        end

        appData.bgStartPt = [x0, y0];

        hold(ax,'on');
        appData.bgRectPatch = patch(ax, ...
            [x0 x0 x0 x0], [y0 y0 y0 y0], [0.90 0.55 0.00], ...
            'FaceAlpha', 0.15, ...
            'EdgeColor', [0.90 0.55 0.00], ...
            'LineWidth', 1.5, ...
            'LineStyle', '--', ...
            'HitTest',   'off');
        hold(ax,'off');

        fig.WindowButtonMotionFcn = @onBGMouseMove;
        fig.WindowButtonUpFcn     = @onBGMouseUp;
    end

    function onBGMouseMove(~,~)
        if isempty(appData.bgStartPt) || ...
           isempty(appData.bgRectPatch) || ~isvalid(appData.bgRectPatch)
            return;
        end
        cp = ax.CurrentPoint;
        x1 = cp(1,1);   y1 = cp(1,2);
        x0 = appData.bgStartPt(1);
        y0 = appData.bgStartPt(2);
        set(appData.bgRectPatch, ...
            'XData', [x0, x1, x1, x0], ...
            'YData', [y0, y0, y1, y1]);
    end

    function onBGMouseUp(~,~)
        fig.WindowButtonDownFcn   = @onAxesButtonDown;
        fig.WindowButtonMotionFcn = @onMouseHover;
        fig.WindowButtonUpFcn     = '';

        btnFitBG.Text            = 'Fit Linear BG from Box';
        btnFitBG.BackgroundColor = [0.50 0.28 0.05];
        btnPickY.Enable          = 'on';
        btnFitBG.Enable          = 'on';

        if isempty(appData.bgStartPt)
            return;
        end

        cp    = ax.CurrentPoint;
        endPt = [cp(1,1), cp(1,2)];

        if ~isempty(appData.bgRectPatch) && isvalid(appData.bgRectPatch)
            delete(appData.bgRectPatch);
            appData.bgRectPatch = [];
        end

        xMin = min(appData.bgStartPt(1), endPt(1));
        xMax = max(appData.bgStartPt(1), endPt(1));
        yMin = min(appData.bgStartPt(2), endPt(2));
        yMax = max(appData.bgStartPt(2), endPt(2));
        appData.bgStartPt = [];

        if (xMax - xMin) < eps(xMax)
            uialert(fig,'Box too narrow — drag across a wider x range.','BG fit');
            return;
        end

        % Use active dataset's raw data
        d       = appData.datasets{appData.activeIdx}.data;
        xVecRaw = appData.bgXVecRaw;

        ySel = ensureCell(lbY.Value);

        xPool = [];
        yPool = [];
        for k = 1:numel(ySel)
            idx = find(strcmp(d.labels, ySel{k}), 1);
            if isempty(idx), continue; end
            yVec  = d.values(:, idx);
            inBox = xVecRaw >= xMin & xVecRaw <= xMax & ...
                    yVec    >= yMin & yVec    <= yMax & ...
                    ~isnan(xVecRaw) & ~isnan(yVec);
            xPool = [xPool; xVecRaw(inBox)];  %#ok<AGROW>
            yPool = [yPool; yVec(inBox)];      %#ok<AGROW>
        end

        if numel(xPool) < 2
            uialert(fig, ...
                sprintf('Only %d data point(s) inside the box — need at least 2 to fit.', ...
                        numel(xPool)), ...
                'Too few points');
            return;
        end

        p = polyfit(xPool, yPool, 1);
        efBGSlope.Value     = p(1);
        efBGIntercept.Value = p(2);

        onApplyCorrections([],[]);
    end

    % ── Y-origin 2-click estimation ───────────────────────────────────────

    function onPickYOrigin(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end

        % Cancel any in-progress BG box-fit before arming this interaction
        cancelInteractions();

        % Arm y-origin interaction (cancelInteractions re-enabled btnPickY — disable)
        btnPickY.Text   = 'Click point 1 of 2 on plot...';
        btnPickY.Enable = 'off';
        btnFitBG.Enable = 'off';

        appData.yOriginClickCount = 0;
        appData.yOriginPt1        = [];

        fig.WindowButtonDownFcn = @onYOriginClick;
    end

    function onYOriginClick(~,~)
        cp     = ax.CurrentPoint;
        xClick = cp(1,1);
        yClick = cp(1,2);
        if xClick < ax.XLim(1) || xClick > ax.XLim(2) || ...
           yClick < ax.YLim(1) || yClick > ax.YLim(2)
            return;
        end

        ds       = appData.datasets{appData.activeIdx};
        d        = ds.data;
        primaryD = guiTernary(~isempty(ds.corrData), ds.corrData, d);

        % ── Resolve the PLOTTED x vector ──────────────────────────────────
        xSel  = ddX.Value;
        xName = guiXName(d.metadata);
        if strcmp(xSel, xName)
            xVecPlot = primaryD.time;
        else
            idx2     = find(strcmp(d.labels, xSel), 1);
            xVecPlot = guiTernary(isempty(idx2), primaryD.time, primaryD.values(:, idx2));
        end
        if isdatetime(xVecPlot)
            xVecPlot = datenum(xVecPlot);
        else
            xVecPlot = double(xVecPlot);
        end

        % ── Snap to nearest plotted point ─────────────────────────────────
        ySel = ensureCell(lbY.Value);

        xRange = max(diff(ax.XLim), eps);
        yRange = max(diff(ax.YLim), eps);
        bestDist = Inf;
        xNearest = NaN;
        yNearest = NaN;
        for k = 1:numel(ySel)
            idx = find(strcmp(d.labels, ySel{k}), 1);
            if isempty(idx), continue; end
            yVec  = primaryD.values(:, idx);
            valid = ~isnan(xVecPlot) & ~isnan(yVec);
            if ~any(valid), continue; end
            xv = xVecPlot(valid);
            yv = yVec(valid);
            dx = (xv - xClick) / xRange;
            dy = (yv - yClick) / yRange;
            [minD, minI] = min(sqrt(dx.^2 + dy.^2));
            if minD < bestDist
                bestDist = minD;
                xNearest = xv(minI);
                yNearest = yv(minI);
            end
        end

        if isnan(yNearest), return; end

        appData.yOriginClickCount = appData.yOriginClickCount + 1;

        if appData.yOriginClickCount == 1
            % ── First click: mark point, wait for second ──────────────────
            appData.yOriginPt1 = yNearest;
            hold(ax, 'on');
            appData.yOriginMarker = plot(ax, xNearest, yNearest, ...
                'v', 'MarkerSize', 9, 'LineWidth', 2, ...
                'Color',            [0.85 0.33 0.10], ...
                'MarkerFaceColor',  [0.85 0.33 0.10], ...
                'HitTest',          'off', ...
                'HandleVisibility', 'off');
            hold(ax, 'off');
            btnPickY.Text = sprintf('Click pt 2  (pt 1: y = %.4g)', yNearest);

        else
            % ── Second click: shift Y offset so midpoint → 0 ─────────────
            fig.WindowButtonDownFcn = @onAxesButtonDown;

            hold(ax, 'on');
            mkr2 = plot(ax, xNearest, yNearest, ...
                '^', 'MarkerSize', 9, 'LineWidth', 2, ...
                'Color',            [0.20 0.60 0.20], ...
                'MarkerFaceColor',  [0.20 0.60 0.20], ...
                'HitTest',          'off', ...
                'HandleVisibility', 'off');
            hold(ax, 'off');
            drawnow limitrate;

            if ~isempty(appData.yOriginMarker) && isvalid(appData.yOriginMarker)
                delete(appData.yOriginMarker);
            end
            if isvalid(mkr2)
                delete(mkr2);
            end

            % new_yOff = old_yOff + (y1 + y2) / 2
            efYOffset.Value = efYOffset.Value + (appData.yOriginPt1 + yNearest) / 2;

            appData.yOriginMarker     = [];
            appData.yOriginClickCount = 0;
            appData.yOriginPt1        = [];

            btnPickY.Text   = 'Est. Y Offset  (2 pts)';
            btnPickY.Enable = 'on';
            btnFitBG.Enable = 'on';

            onApplyCorrections([], []);
        end
    end

    % ── Save callbacks ────────────────────────────────────────────────────

    function onSaveBrowse(~,~)
        [fname, fpath] = uiputfile({'*.csv','CSV files (*.csv)'}, ...
            'Save corrected data as...');
        if isequal(fname,0), return; end
        efSavePath.Value = fullfile(fpath,fname);
    end

    function onSaveCSV(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end
        ds = appData.datasets{appData.activeIdx};
        if isempty(ds.corrData)
            uialert(fig,'Apply corrections first.','No corrected data');
            return;
        end
        fp = strtrim(efSavePath.Value);
        if isempty(fp)
            uialert(fig,'Set an output file path first.','No output path');
            return;
        end
        try
            guiSaveCSV(ds.corrData, fp, ds.data);
            uialert(fig, sprintf('Saved:\n%s', fp), 'Saved');
        catch ME
            fprintf(2, '\n[dataImportGUI] Save error: %s\n', ME.message);
            for si = 1:numel(ME.stack)
                fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
            end
            uialert(fig, ME.message, 'Save error');
        end
    end

    function onExportHDF5(~,~)
    %ONEXPORTHDF5  Export the active dataset to HDF5 via a browse-and-save dialog.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end
        ds = appData.datasets{appData.activeIdx};
        [~, fn, ~] = fileparts(ds.filepath);
        defName    = fullfile(fileparts(ds.filepath), [fn, '.h5']);
        [fname, fpath] = uiputfile( ...
            {'*.h5','HDF5 files (*.h5)'; '*.hdf5','HDF5 files (*.hdf5)'}, ...
            'Export to HDF5 as...', defName);
        if isequal(fname, 0), return; end
        outPath = fullfile(fpath, fname);
        try
            utilities.exportHDF5(ds.data, outPath, ...
                'CorrData',    ds.corrData, ...
                'Corrections', struct('xOff', ds.xOff, 'yOff', ds.yOff, ...
                                      'bgSlope', ds.bgSlope, 'bgInt', ds.bgInt), ...
                'IncludePeaks', ~isempty(ds.peaks), ...
                'Peaks',        ds.peaks);
            uialert(fig, sprintf('Saved:\n%s', outPath), 'HDF5 Exported');
        catch ME
            fprintf(2, '\n[dataImportGUI] HDF5 export error: %s\n', ME.message);
            for si = 1:numel(ME.stack)
                fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
            end
            uialert(fig, ME.message, 'Export error');
        end
    end

    % ── Plot callbacks ────────────────────────────────────────────────────

    function onPlot(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        drawToAxes(ax);
    end

    function drawToAxes(targetAx)
    %DRAWTOAXES  Render ALL loaded datasets into targetAx.
    %   Channel selection and x-axis label are driven by the active dataset.
    %   Each (dataset, y-channel) pair gets a unique colour from lines().
    %   Called by onPlot (GUI uiaxes) and onExportFigure (regular axes).
        try
            if isempty(appData.datasets) || appData.activeIdx < 1, return; end

            activeDs = appData.datasets{appData.activeIdx};
            nDS      = numel(appData.datasets);

            % ── Channel selection from the active dataset ─────────────────
            xSel   = ddX.Value;
            xName  = guiXName(activeDs.data.metadata);
            xUnit  = guiXUnit(activeDs.data.metadata);
            xLabel = guiLabel(xName, xUnit);

            ySel = ensureCell(lbY.Value);
            nY   = numel(ySel);

            y2SelRaw = ensureCell(lbY2.Value);
            y2Sel    = y2SelRaw(~strcmp(y2SelRaw, '(none)'));
            nY2      = numel(y2Sel);
            hasY2    = nY2 > 0;

            % ── Colour allocation ─────────────────────────────────────────
            % lines(nDS*(nY+nY2)) gives one colour per (dataset, channel) pair.
            % Left-axis indices:  (di-1)*nY  + k
            % Right-axis indices: nDS*nY     + (di-1)*nY2 + k
            colors = lines(max(nDS * (nY + nY2), 1));

            % ── Draw ──────────────────────────────────────────────────────
            % Peak markers and zoom rect use HandleVisibility='off' so ax.Children may
            % omit them in some MATLAB releases. findall() bypasses this filter.
            delete(findall(targetAx, 'Tag', 'GUIPeakAnnotation'));
            delete(findall(targetAx, 'Tag', 'GUIZoomBox'));
            delete(targetAx.Children);
            cla(targetAx);
            % cla() preserves XLimMode/YLimMode, so an explicit drag-zoom would keep
            % the axes locked at manual limits even after the fields are cleared.
            % Reset to auto here; explicit limits below will override when populated.
            targetAx.XLimMode = 'auto';
            targetAx.YLimMode = 'auto';

            % Reset right y-axis state if it was created in a previous draw.
            % yyaxis cla only clears the active side, so switch explicitly.
            if numel(targetAx.YAxis) > 1
                yyaxis(targetAx, 'right');
                cla(targetAx);
                targetAx.YLimMode = 'auto';
                targetAx.YScale   = 'linear';
                ylabel(targetAx, '');
                yyaxis(targetAx, 'left');
            end

            hold(targetAx,'on');
            if hasY2
                yyaxis(targetAx,'right'); hold(targetAx,'on');
                yyaxis(targetAx,'left');
            end
            lsPrimary    = guiLineSpec(appData.style);
            lsRaw        = guiLineSpec_raw(appData.style);
            anyRawShown  = false;

            % ── Waterfall offset ──────────────────────────────────────
            % effectiveSpacing > 0  →  each dataset i gets Y shifted by (i-1)*spacing
            waterfallOn = cbWaterfall.Value;
            if waterfallOn
                rawSp = str2double(efWaterfallSpacing.Value);
                if isnan(rawSp) || rawSp <= 0
                    effectiveSpacing = computeAutoWaterfallSpacing();
                else
                    effectiveSpacing = rawSp;
                end
            else
                effectiveSpacing = 0;
            end

            for di = 1:nDS
                ds          = appData.datasets{di};
                d           = ds.data;
                hasCorrData = ~isempty(ds.corrData);
                showRawOver = hasCorrData && cbShowRaw.Value;
                primaryD    = guiTernary(hasCorrData, ds.corrData, d);

                % ── X vector for this dataset ─────────────────────────────
                % Use xSel driven by the active dataset; for non-active
                % datasets, fall back to d.time if the label is not found.
                if strcmp(xSel, xName)
                    xVecRaw     = d.time;
                    xVecPrimary = primaryD.time;
                else
                    idx2 = find(strcmp(d.labels, xSel), 1);
                    if isempty(idx2)
                        xVecRaw     = d.time;
                        xVecPrimary = primaryD.time;
                    else
                        xVecRaw     = d.values(:, idx2);
                        xVecPrimary = primaryD.values(:, idx2);
                    end
                end

                % Filename suffix for legend (omitted when only 1 dataset)
                if nDS > 1
                    [~, fn, fext] = fileparts(ds.filepath);
                    fileSuffix = sprintf('  [%s%s]', fn, fext);
                else
                    fileSuffix = '';
                end

                % Counts/s normalisation factor (0 = disabled)
                ctFactor = 0;
                if cbCountsPerSec.Value
                    ctFactor = guiCountingTime(ds);
                end

                % Per-dataset colour overrides ([] = Auto → fall back to lines() palette)
                dsColorOverride  = [];
                if isfield(ds,'color')  && ~isempty(ds.color),  dsColorOverride  = ds.color;  end
                dsColorROverride = [];
                if isfield(ds,'colorR') && ~isempty(ds.colorR), dsColorROverride = ds.colorR; end

                for k = 1:nY
                    colorIdx  = (di-1)*nY + k;
                    baseColor = guiTernary(~isempty(dsColorOverride), dsColorOverride, colors(colorIdx,:));

                    idx = find(strcmp(d.labels, ySel{k}), 1);
                    if isempty(idx), continue; end

                    baseLabel = [guiLabel(d.labels{idx}, d.units{idx}), fileSuffix];

                    % Raw overlay (dashed, desaturated 50% white-blend)
                    if showRawOver
                        anyRawShown = true;
                        yRaw     = d.values(:, idx);
                        if ctFactor > 0, yRaw = yRaw / ctFactor; end
                        if effectiveSpacing ~= 0
                            yRaw = yRaw + (di - 1) * effectiveSpacing;
                        end
                        rawColor = 0.5 * baseColor + 0.5 * [1 1 1];
                        if isdatetime(xVecRaw)
                            good = ~isnat(xVecRaw) & ~isnan(yRaw);
                        else
                            good = ~isnan(xVecRaw) & ~isnan(yRaw);
                        end
                        plot(targetAx, xVecRaw(good), yRaw(good), lsRaw{:}, ...
                            'Color',       rawColor, ...
                            'HitTest',     'off', ...
                            'DisplayName', [baseLabel, ' (raw)']);
                    end

                    % Primary trace
                    yPrimary = primaryD.values(:, idx);
                    if ctFactor > 0, yPrimary = yPrimary / ctFactor; end
                    if effectiveSpacing ~= 0
                        yPrimary = yPrimary + (di - 1) * effectiveSpacing;
                    end
                    if isdatetime(xVecPrimary)
                        good = ~isnat(xVecPrimary) & ~isnan(yPrimary);
                    else
                        good = ~isnan(xVecPrimary) & ~isnan(yPrimary);
                    end
                    dispName = guiTernary(hasCorrData, [baseLabel, ' (corr)'], baseLabel);
                    if isfield(ds,'legendName') && ~isempty(ds.legendName)
                        dispName = ds.legendName;
                    end
                    plot(targetAx, xVecPrimary(good), yPrimary(good), lsPrimary{:}, ...
                        'Color',       baseColor, ...
                        'HitTest',     'off', ...
                        'DisplayName', dispName);
                end

                % ── Right-axis (Y2) channels ──────────────────────────────
                if hasY2
                    yyaxis(targetAx, 'right');
                    for k2 = 1:nY2
                        colorIdx2  = nDS*nY + (di-1)*nY2 + k2;
                        baseColor2 = guiTernary(~isempty(dsColorROverride), dsColorROverride, colors(colorIdx2, :));

                        idx2 = find(strcmp(d.labels, y2Sel{k2}), 1);
                        if isempty(idx2), continue; end

                        baseLabel2 = [guiLabel(d.labels{idx2}, d.units{idx2}), fileSuffix];
                        yY2 = primaryD.values(:, idx2);
                        if ctFactor > 0, yY2 = yY2 / ctFactor; end

                        if isdatetime(xVecPrimary)
                            good2 = ~isnat(xVecPrimary) & ~isnan(yY2);
                        else
                            good2 = ~isnan(xVecPrimary) & ~isnan(yY2);
                        end

                        dispName2 = [baseLabel2, '  [R]'];
                        if isfield(ds,'legendNameR') && ~isempty(ds.legendNameR)
                            dispName2 = ds.legendNameR;
                        end
                        plot(targetAx, xVecPrimary(good2), yY2(good2), lsPrimary{:}, ...
                            'Color',       baseColor2, ...
                            'HitTest',     'off', ...
                            'DisplayName', dispName2);
                    end
                    yyaxis(targetAx, 'left');
                end
            end
            hold(targetAx,'off');
            if hasY2
                yyaxis(targetAx, 'right');
                hold(targetAx, 'off');
                targetAx.YScale = guiTernary(cbLogY2.Value, 'log', 'linear');
                if ~isempty(efCustomY2Label.Value)
                    ylabel(targetAx, efCustomY2Label.Value);
                elseif nY2 == 1
                    idx2r = find(strcmp(activeDs.data.labels, y2Sel{1}), 1);
                    if ~isempty(idx2r)
                        ylabel(targetAx, guiLabel(activeDs.data.labels{idx2r}, ...
                            activeDs.data.units{idx2r}));
                    end
                end
                yyaxis(targetAx, 'left');
            end

            % Legend: on when multi-channel, multi-dataset, raw overlay, or Y2 shown
            if nY > 1 || nDS > 1 || anyRawShown || hasY2
                legend(targetAx,'Location','best');
            else
                legend(targetAx,'off');
            end

            % X label: custom override takes priority over auto-generated label
            if ~isempty(efCustomXLabel.Value)
                xlabel(targetAx, efCustomXLabel.Value);
            else
                xlabel(targetAx, xLabel);
            end

            % Y label: custom override, then waterfall note, then auto (single dataset only)
            if ~isempty(efCustomYLabel.Value)
                ylabel(targetAx, efCustomYLabel.Value);
            elseif waterfallOn
                ylabel(targetAx, 'Intensity (a.u.)');
            elseif nY == 1 && nDS == 1
                idx = find(strcmp(activeDs.data.labels, ySel{1}), 1);
                if ~isempty(idx)
                    unitStr = activeDs.data.units{idx};
                    if cbCountsPerSec.Value && guiCountingTime(activeDs) > 0
                        unitStr = 'counts/s';
                    end
                    ylabel(targetAx, guiLabel(activeDs.data.labels{idx}, unitStr));
                end
            else
                ylabel(targetAx,'');
            end

            if nDS == 1
                [~,fn,fext] = fileparts(activeDs.filepath);
                titleStr = [fn, fext];
                if ~isempty(activeDs.corrData)
                    titleStr = [titleStr, '  [corrected]'];
                end
            else
                titleStr = sprintf('%d datasets loaded  (active: [%d])', ...
                    nDS, appData.activeIdx);
            end
            % Title: custom override takes priority over auto-generated title
            if ~isempty(efCustomTitle.Value)
                title(targetAx, efCustomTitle.Value, 'Interpreter','none');
            else
                title(targetAx, titleStr, 'Interpreter','none');
            end

            targetAx.XScale = guiTernary(cbLogX.Value,'log','linear');
            targetAx.YScale = guiTernary(cbLogY.Value,'log','linear');
            grid(targetAx,'on');
            targetAx.FontSize       = 13;   % tick labels + axis labels
            targetAx.Title.FontSize = 14;   % title has its own independent property

            % ── Manual axis limits ────────────────────────────────────────
            % Applied after all plot() calls so auto-scale cannot override them.
            % str2double('') == NaN → blank field = auto (no action taken).
            xMinV  = str2double(efXMin.Value);
            xMaxV  = str2double(efXMax.Value);
            xStepV = str2double(efXStep.Value);
            yMinV  = str2double(efYMin.Value);
            yMaxV  = str2double(efYMax.Value);
            yStepV = str2double(efYStep.Value);

            % Highlight invalid limit pairs (both parsed but min >= max)
            xLimsInvalid = ~isnan(xMinV) && ~isnan(xMaxV) && xMinV >= xMaxV;
            yLimsInvalid = ~isnan(yMinV) && ~isnan(yMaxV) && yMinV >= yMaxV;
            warnColor  = [0.45 0.10 0.10];   % dark red — legible on dark background
            clearColor = [0.17 0.17 0.17];   % matches AXLIM_BG set at field creation
            efXMin.BackgroundColor = guiTernary(xLimsInvalid, warnColor, clearColor);
            efXMax.BackgroundColor = guiTernary(xLimsInvalid, warnColor, clearColor);
            efYMin.BackgroundColor = guiTernary(yLimsInvalid, warnColor, clearColor);
            efYMax.BackgroundColor = guiTernary(yLimsInvalid, warnColor, clearColor);

            if ~isnan(xMinV) && ~isnan(xMaxV) && xMinV < xMaxV
                targetAx.XLim = [xMinV, xMaxV];
            end
            if ~isnan(yMinV) && ~isnan(yMaxV) && yMinV < yMaxV
                targetAx.YLim = [yMinV, yMaxV];
            end

            % Tick spacing: computed from current XLim/YLim (set above or auto).
            % Guard against degenerate step that would generate >500 ticks.
            if ~isnan(xStepV) && xStepV > 0
                xTk = targetAx.XLim(1) : xStepV : targetAx.XLim(2);
                if numel(xTk) >= 2 && numel(xTk) <= 500
                    targetAx.XTick = xTk;
                end
            end
            if ~isnan(yStepV) && yStepV > 0
                yTk = targetAx.YLim(1) : yStepV : targetAx.YLim(2);
                if numel(yTk) >= 2 && numel(yTk) <= 500
                    targetAx.YTick = yTk;
                end
            end

            % ── Right Y-axis (Y2) limits ───────────────────────────────────
            % Toggle row visibility when drawing to the main GUI axes.
            if targetAx == ax
                axLimGL.RowHeight{4} = 26 * hasY2;
                apGL.ColumnWidth{3}  = guiTernary(hasY2, '1x', 0);
                apGL.RowHeight{1}    = guiTernary(hasY2, 20,   0);
                fmtGL.ColumnWidth{5} = guiTernary(hasY2, 20,   0);
                fmtGL.ColumnWidth{6} = guiTernary(hasY2, '1x', 0);
            end
            if hasY2
                y2MinV  = str2double(efY2Min.Value);
                y2MaxV  = str2double(efY2Max.Value);
                y2StepV = str2double(efY2Step.Value);

                y2LimsInvalid = ~isnan(y2MinV) && ~isnan(y2MaxV) && y2MinV >= y2MaxV;
                efY2Min.BackgroundColor = guiTernary(y2LimsInvalid, warnColor, clearColor);
                efY2Max.BackgroundColor = guiTernary(y2LimsInvalid, warnColor, clearColor);

                yyaxis(targetAx, 'right');
                if ~isnan(y2MinV) && ~isnan(y2MaxV) && y2MinV < y2MaxV
                    targetAx.YLim = [y2MinV, y2MaxV];
                end
                if ~isnan(y2StepV) && y2StepV > 0
                    yTk2 = targetAx.YLim(1) : y2StepV : targetAx.YLim(2);
                    if numel(yTk2) >= 2 && numel(yTk2) <= 500
                        targetAx.YTick = yTk2;
                    end
                end
                yyaxis(targetAx, 'left');
            end

            % ── Tick-label notation ───────────────────────────────────────
            % Applied after limits/steps so the format overrides any auto-
            % formatting triggered by manual XLim / YLim changes.
            % '__exp0' sentinel: force YAxis.Exponent = 0 (suppress ×10ⁿ corner
            % label) instead of applying a printf format string.
            xfmt = ddXFmt.Value;
            if isempty(xfmt), xtickformat(targetAx, 'auto');
            else,             xtickformat(targetAx, xfmt);  end

            yfmt = ddYFmt.Value;
            if strcmp(yfmt, '__exp0')
                ytickformat(targetAx, 'auto');
                targetAx.YAxis(1).ExponentMode = 'manual';
                targetAx.YAxis(1).Exponent     = 0;
            elseif isempty(yfmt)
                ytickformat(targetAx, 'auto');
                targetAx.YAxis(1).ExponentMode = 'auto';
            else
                ytickformat(targetAx, yfmt);
                targetAx.YAxis(1).ExponentMode = 'auto';
            end

            if hasY2
                yyaxis(targetAx, 'right');
                y2fmt = ddY2Fmt.Value;
                if strcmp(y2fmt, '__exp0')
                    ytickformat(targetAx, 'auto');
                    targetAx.YAxis(2).ExponentMode = 'manual';
                    targetAx.YAxis(2).Exponent     = 0;
                elseif isempty(y2fmt)
                    ytickformat(targetAx, 'auto');
                    targetAx.YAxis(2).ExponentMode = 'auto';
                else
                    ytickformat(targetAx, y2fmt);
                    targetAx.YAxis(2).ExponentMode = 'auto';
                end
                yyaxis(targetAx, 'left');
            end

            % ── Peak annotations ──────────────────────────────────────────
            % Drawn after axis limits so YLim is finalised.
            % Render order: (1) Lorentzian fit curves, (2) marker lines + labels,
            % so markers visually sit on top of the model overlay.
            if appData.activeIdx >= 1 && ~isempty(appData.datasets)
                dsPk = appData.datasets{appData.activeIdx};
                if ~isempty(dsPk.peaks)
                    hold(targetAx,'on');
                    yLo   = targetAx.YLim(1);
                    yHi   = targetAx.YLim(2);
                    ySpan = yHi - yLo;
                    fitColor = appData.fitCurveColor;
                    % In waterfall mode the active dataset is shifted by this amount
                    pkYOff = (appData.activeIdx - 1) * effectiveSpacing;

                    % ── (1) Lorentzian fit overlays ───────────────────────
                    if appData.showFitCurves
                        for pi = 1:numel(dsPk.peaks)
                            pk       = dsPk.peaks(pi);
                            hasBg    = isfield(pk,'bg') && ~isempty(pk.bg) && ~isnan(pk.bg);
                            isFitted = strcmp(pk.status,'fitted') && ~isnan(pk.fwhm) && pk.fwhm > 0;
                            if ~isFitted || ~hasBg, continue; end

                            % X range for the smooth curve: stored xRange or ±3·FWHM
                            if ~isempty(pk.xRange) && numel(pk.xRange) == 2
                                gxLo = pk.xRange(1);  gxHi = pk.xRange(2);
                            else
                                gxLo = pk.center - 3*pk.fwhm;
                                gxHi = pk.center + 3*pk.fwhm;
                            end
                            xFitPlot = linspace(gxLo, gxHi, 300);
                            pkModel = '';
                            if isfield(pk,'model'), pkModel = pk.model; end
                            if strcmp(pkModel, 'Gaussian')
                                yFitPlot = pk.height .* ...
                                    exp(-4.*log(2).*((xFitPlot-pk.center)./pk.fwhm).^2) + pk.bg;
                            else   % Lorentzian (default)
                                yFitPlot = pk.height ./ ...
                                    (1 + 4.*((xFitPlot - pk.center)./pk.fwhm).^2) + pk.bg;
                            end
                            yFitPlot = yFitPlot + pkYOff;

                            isSel = (pi == appData.selectedPeakIdx);
                            plot(targetAx, xFitPlot, yFitPlot, '-', ...
                                'Color',            fitColor, ...
                                'LineWidth',        guiTernary(isSel, 2.5, 1.5), ...
                                'HitTest',          'off', ...
                                'Tag',              'GUIPeakAnnotation', ...
                                'HandleVisibility', 'off');
                        end
                    end

                    % ── (2) Vertical markers, labels and FWHM bars ────────
                    for pi = 1:numel(dsPk.peaks)
                        pk        = dsPk.peaks(pi);
                        isSel     = (pi == appData.selectedPeakIdx);
                        lineColor = guiTernary(isSel, [1.0 0.50 0.00], [0.55 0.15 0.75]);
                        lineWidth = guiTernary(isSel, 2.5, 1.5);

                        % Vertical dashed line spanning the full y-axis
                        plot(targetAx, [pk.center, pk.center], [yLo, yHi], '--', ...
                            'Color',            lineColor, ...
                            'LineWidth',        lineWidth, ...
                            'HitTest',          'off', ...
                            'Tag',              'GUIPeakAnnotation', ...
                            'HandleVisibility', 'off');

                        % Peak index + centre label near the bottom (shifted in waterfall)
                        text(targetAx, pk.center, yLo + ySpan*0.03 + pkYOff, ...
                            sprintf('#%d  %.3f\xb0', pi, pk.center), ...
                            'FontSize',           7, ...
                            'HorizontalAlignment','center', ...
                            'Color',              lineColor, ...
                            'Tag',                'GUIPeakAnnotation', ...
                            'HandleVisibility',   'off', ...
                            'Interpreter',        'none');

                        % FWHM horizontal bar at the true half-maximum height
                        % For a fitted Lorentzian: half-max is at bg + H/2.
                        % For un-fitted peaks: fall back to H/2 as an estimate.
                        if ~isnan(pk.fwhm) && pk.fwhm > 0
                            hasBg = isfield(pk,'bg') && ~isempty(pk.bg) && ~isnan(pk.bg);
                            halfH = guiTernary(hasBg, pk.bg + pk.height*0.5, pk.height*0.5) + pkYOff;
                            plot(targetAx, ...
                                [pk.center - pk.fwhm/2, pk.center + pk.fwhm/2], ...
                                [halfH, halfH], '-', ...
                                'Color',            lineColor, ...
                                'LineWidth',        2.0, ...
                                'HitTest',          'off', ...
                                'Tag',              'GUIPeakAnnotation', ...
                                'HandleVisibility', 'off');
                        end
                    end
                    hold(targetAx,'off');
                end
            end

        catch ME
            fprintf(2, '\n[dataImportGUI] Plot error: %s\n', ME.message);
            for si = 1:numel(ME.stack)
                fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
            end
            uialert(fig, ME.message, 'Plot error');
        end
    end

    function onAutoLimits(~,~)
    %ONAUTOLIMITS  Clear all axis limit fields → return to auto-scale.
        efXMin.Value = '';  efXMax.Value = '';  efXStep.Value = '';
        efYMin.Value = '';  efYMax.Value = '';  efYStep.Value = '';
        efY2Min.Value = '';  efY2Max.Value = '';  efY2Step.Value = '';
        saveAxisLimsToActiveDataset();
        onPlot([],[]);
    end

    function onMouseHover(~,~)
    %ONMOUSEHOVER  Update x,y readout and set resize cursor near panel borders.
    %  Fires continuously while the mouse moves over the figure in idle (non-drag) mode.

        % -- Panel resize border detection: update cursor and store hover direction --
        dir = detectResizeBorder();
        appData.panelResizeDir = dir;
        if     strcmp(dir, 'h_row12') || strcmp(dir, 'h_row23'), fig.Pointer = 'top';
        elseif strcmp(dir, 'v_col12') || strcmp(dir, 'v_col23') || strcmp(dir, 'v_col34')
                                                                   fig.Pointer = 'left';
        else,                                                      fig.Pointer = 'arrow';
        end

        % -- x,y readout in top-right of axes --
        if isempty(appData.cursorText) || ~isvalid(appData.cursorText), return; end
        if isempty(appData.datasets) || appData.activeIdx < 1
            set(appData.cursorText, 'Visible', 'off');
            return;
        end
        cp = ax.CurrentPoint;
        x  = cp(1,1);  y = cp(1,2);
        if x < ax.XLim(1) || x > ax.XLim(2) || ...
           y < ax.YLim(1) || y > ax.YLim(2)
            set(appData.cursorText, 'Visible', 'off');
            return;
        end
        set(appData.cursorText, ...
            'String',  sprintf('x = %.5g\ny = %.5g', x, y), ...
            'Visible', 'on');
    end

    function onAxesButtonDown(~,~)
    %ONAXESBUTTONDOWN  Figure-level mouse-down in normal mode (no special mode active).
    %  Initiates a panel resize when the cursor is at a resizable border.
    %  Ignores clicks outside the axes plot area otherwise.
    %  Double-click (two clicks within 350 ms) resets zoom to auto-scale.
    %  Single-click drag draws a rubber-band zoom box.
    %  Note: fig.WindowButtonDownFcn is always set to this function in normal mode so
    %  that both clicks of a double-click reach the handler reliably (uiaxes
    %  ButtonDownFcn does not deliver the second click in uifigure event routing).

        % Initiate panel resize when hover has detected a border
        if ~isempty(appData.panelResizeDir)
            startPanelResize();
            return;
        end

        % Initiate dataset list drag if click is inside lbDatasets
        if numel(appData.datasets) > 1 && isInListbox()
            src = listboxRowAt(fig.CurrentPoint(2));
            if src >= 1 && src <= numel(appData.datasets)
                appData.listDragSrcIdx  = src;
                appData.listDragActive  = false;
                appData.listDragStartPt = fig.CurrentPoint;
                fig.WindowButtonMotionFcn = @onListDragMove;
                fig.WindowButtonUpFcn     = @onListDragUp;
            end
            return;   % let lbDatasets handle the selection click normally
        end

        % Ignore clicks outside the axes plot area
        cp = ax.CurrentPoint;
        x0 = cp(1,1);  y0 = cp(1,2);
        if x0 < ax.XLim(1) || x0 > ax.XLim(2) || ...
           y0 < ax.YLim(1) || y0 > ax.YLim(2)
            return;
        end
        % Manual double-click detection (two clicks within 350 ms)
        DBLCLICK_SEC = 0.35;
        isDoubleClick = appData.lastClickTic ~= uint64(0) && ...
                        toc(appData.lastClickTic) < DBLCLICK_SEC;
        appData.lastClickTic = tic;
        if isDoubleClick
            appData.lastClickTic = uint64(0);  % reset so a third click can't re-trigger
            onAutoLimits([],[]);
            return;
        end
        % Single click — begin drag-zoom if data is loaded
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        appData.zoomStartPt       = [x0, y0];
        fig.WindowButtonMotionFcn = @onZoomMouseMove;
        fig.WindowButtonUpFcn     = @onZoomMouseUp;
    end

    function onZoomMouseMove(~,~)
    %ONZOOMMOUSEMOVE  Update the rubber-band rectangle while dragging.
        if isempty(appData.zoomStartPt), return; end
        cp = ax.CurrentPoint;
        x1 = cp(1,1);  y1 = cp(1,2);
        x0 = appData.zoomStartPt(1);
        y0 = appData.zoomStartPt(2);
        xLo = min(x0,x1);  xHi = max(x0,x1);
        yLo = min(y0,y1);  yHi = max(y0,y1);
        if ~isempty(appData.zoomRectPatch) && isvalid(appData.zoomRectPatch)
            set(appData.zoomRectPatch, ...
                'XData', [xLo xHi xHi xLo xLo], ...
                'YData', [yLo yLo yHi yHi yLo]);
        else
            hold(ax,'on');
            appData.zoomRectPatch = patch(ax, ...
                [xLo xHi xHi xLo xLo], [yLo yLo yHi yHi yLo], ...
                [0.20 0.55 0.90], ...
                'FaceAlpha',       0.12, ...
                'EdgeColor',       [0.20 0.55 0.90], ...
                'LineWidth',       1.5, ...
                'Tag',             'GUIZoomBox', ...
                'HandleVisibility','off');
            hold(ax,'off');
        end
    end

    function onZoomMouseUp(~,~)
    %ONZOOMMOUSEUP  Apply zoom to the drawn rectangle, then clean up.
        fig.WindowButtonMotionFcn = @onMouseHover;
        fig.WindowButtonUpFcn     = '';
        if isempty(appData.zoomStartPt)
            return;
        end
        cp = ax.CurrentPoint;
        x1 = cp(1,1);  y1 = cp(1,2);
        x0 = appData.zoomStartPt(1);
        y0 = appData.zoomStartPt(2);
        % Remove rubber-band rectangle
        if ~isempty(appData.zoomRectPatch) && isvalid(appData.zoomRectPatch)
            delete(appData.zoomRectPatch);
        end
        appData.zoomRectPatch = [];
        appData.zoomStartPt   = [];
        % Only zoom if drag is at least 1% of the current axis span in both axes
        xDrag = abs(x1 - x0);
        yDrag = abs(y1 - y0);
        if xDrag < diff(ax.XLim) * 0.01 || yDrag < diff(ax.YLim) * 0.01
            return;
        end
        xLo = min(x0,x1);  xHi = max(x0,x1);
        yLo = min(y0,y1);  yHi = max(y0,y1);
        efXMin.Value = sprintf('%.6g', xLo);
        efXMax.Value = sprintf('%.6g', xHi);
        efYMin.Value = sprintf('%.6g', yLo);
        efYMax.Value = sprintf('%.6g', yHi);
        saveAxisLimsToActiveDataset();
        onPlot([],[]);
    end

    function onFigSizeChanged(~,~)
    %ONFIGSIZECHANGED  Prevent the window from being resized below MIN_FIG_H so
    %  the fixed-height analysis panel is never clipped by the window boundary.
        if fig.Position(4) < MIN_FIG_H
            fig.SizeChangedFcn = '';          % disable to avoid recursion
            fig.Position(4) = MIN_FIG_H;
            fig.SizeChangedFcn = @onFigSizeChanged;
        end
    end

    function onExportFigure(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end
        expFig = figure('Name','Exported Plot','NumberTitle','off');
        expAx  = axes(expFig);   %#ok<LAXES>
        box(expAx,'on');
        grid(expAx,'on');
        drawToAxes(expAx);
        figure(expFig);   % bring to front
    end

    function onCopyToClipboard(~,~)
    %ONCOPYTOCLIPBOARD  Render the current plot into a temporary figure and copy
    %  it to the system clipboard as a bitmap image.
    %  Note: '-clipboard' is only supported on Windows; an alert is shown otherwise.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end
        % Spin up a lightweight off-screen figure so the GUI is not disturbed
        tmpFig = figure('Visible','off', ...
                        'Name','ClipboardCopy','NumberTitle','off', ...
                        'MenuBar','none','ToolBar','none');
        tmpAx = axes(tmpFig);   %#ok<LAXES>
        box(tmpAx,'on');
        grid(tmpAx,'on');
        drawToAxes(tmpAx);
        try
            print(tmpFig, '-clipboard', '-dbitmap');
        catch ME
            delete(tmpFig);
            uialert(fig, ...
                sprintf(['Clipboard copy is not supported on this platform.\n\n' ...
                         '(%s)\n\nUse "Export to Figure" and copy from there.'], ...
                        ME.message), ...
                'Copy to clipboard failed');
            return;
        end
        delete(tmpFig);
    end

    % ── Panel drag-resize ────────────────────────────────────────────────

    function dir = detectResizeBorder()
    %DETECTRESIZEBORDER  Check whether fig.CurrentPoint is within SNAP_PX of a
    %  resizable panel border.  Returns:
    %    'h_row12' — horizontal border between toolbar row (1) and preview row (2)
    %    'h_row23' — horizontal border between preview row (2) and analysis row (3)
    %    'v_col12' — vertical border between corrections col (1) and axis-limits col (2)
    %    'v_col23' — vertical border between axis-limits col (2) and peak col (3)  [XRD only]
    %    'v_col34' — vertical border between peak col (3) and save col (4)         [XRD only]
    %    ''        — not near any known border
        SNAP_PX = 5;
        dir = '';
        try
            mp   = fig.CurrentPoint;                        % [x y] from figure bottom-left
            aPos = getpixelposition(analysisPanel, true);   % [l b w h] relative to figure

            % h_row12: bottom edge of toolbar row = top edge of contentGL
            cglPos  = getpixelposition(contentGL, true);
            borderY = cglPos(2) + cglPos(4);
            if abs(mp(2) - borderY) <= SNAP_PX && ...
               mp(1) >= cglPos(1) && mp(1) <= cglPos(1) + cglPos(3)
                dir = 'h_row12'; return;
            end

            % h_row23: top edge of the analysis panel
            borderY = aPos(2) + aPos(4);
            if abs(mp(2) - borderY) <= SNAP_PX && ...
               mp(1) >= aPos(1) && mp(1) <= aPos(1) + aPos(3)
                dir = 'h_row23'; return;
            end

            % Vertical borders — only test inside the analysis panel's y-band
            if mp(2) >= aPos(2) && mp(2) <= aPos(2) + aPos(4)

                % v_col12: right edge of corrections panel
                cPos    = getpixelposition(corrPanel, true);
                borderX = cPos(1) + cPos(3);
                if abs(mp(1) - borderX) <= SNAP_PX
                    dir = 'v_col12'; return;
                end

                % v_col23 and v_col34: only exist when peakPanel is visible (XRD mode)
                if strcmp(peakPanel.Visible, 'on')
                    % v_col23: right edge of axis-limits panel
                    alPos   = getpixelposition(axLimPanel, true);
                    borderX = alPos(1) + alPos(3);
                    if abs(mp(1) - borderX) <= SNAP_PX
                        dir = 'v_col23'; return;
                    end

                    % v_col34: right edge of peak-analysis panel
                    pkPos   = getpixelposition(peakPanel, true);
                    borderX = pkPos(1) + pkPos(3);
                    if abs(mp(1) - borderX) <= SNAP_PX
                        dir = 'v_col34'; return;
                    end
                end

            end
        catch
            % getpixelposition may throw on some MATLAB versions — silently skip
        end
    end

    function startPanelResize()
    %STARTPANELRESIZE  Arm motion/up handlers to begin dragging the detected border.
        mp = fig.CurrentPoint;
        appData.panelResizeStart = mp;
        if strcmp(appData.panelResizeDir, 'h_row12')
            % Snapshot the current toolbar row height (always a fixed-px number)
            rh = rootGL.RowHeight;
            appData.panelResizeOrig = guiTernary(isnumeric(rh{1}), rh{1}, 222);
        elseif strcmp(appData.panelResizeDir, 'h_row23')
            % Snapshot the current analysis panel height (px)
            try
                aPos = getpixelposition(analysisPanel, true);
                appData.panelResizeOrig = aPos(4);
            catch
                rh = rootGL.RowHeight;
                appData.panelResizeOrig = guiTernary(isnumeric(rh{3}), rh{3}, 400);
            end
        elseif strcmp(appData.panelResizeDir, 'v_col12')
            % Snapshot the current corrections panel width (px)
            try
                cPos = getpixelposition(corrPanel, true);
                appData.panelResizeOrig = cPos(3);
            catch
                appData.panelResizeOrig = appData.corrPanelWidth;
            end
        elseif strcmp(appData.panelResizeDir, 'v_col23')
            % Snapshot the current axis-limits panel width (px)
            try
                alPos = getpixelposition(axLimPanel, true);
                appData.panelResizeOrig = alPos(3);
            catch
                appData.panelResizeOrig = appData.axLimPanelWidth;
            end
        elseif strcmp(appData.panelResizeDir, 'v_col34')
            % Snapshot the current peak-analysis panel width (px)
            try
                pkPos = getpixelposition(peakPanel, true);
                appData.panelResizeOrig = pkPos(3);
            catch
                appData.panelResizeOrig = 300;
            end
        end
        fig.WindowButtonMotionFcn = @onPanelResizeMove;
        fig.WindowButtonUpFcn     = @onPanelResizeUp;
    end

    function onPanelResizeMove(~,~)
    %ONPANELRESIZEMOVE  Live-update layout while dragging a panel border.
        if isempty(appData.panelResizeStart), return; end
        mp = fig.CurrentPoint;

        if strcmp(appData.panelResizeDir, 'h_row12')
            % Mouse moves down (mp(2) decreases) → toolbar row gets taller.
            % Sign is inverted vs h_row23: dragging the top border down expands row 1.
            delta_y = mp(2) - appData.panelResizeStart(2);
            newH    = round(appData.panelResizeOrig - delta_y);
            newH    = max(140, min(newH, 400));
            rootGL.RowHeight = {newH, '3x', '2x'};

        elseif strcmp(appData.panelResizeDir, 'h_row23')
            % Mouse moves up (mp(2) increases) → analysis panel gets taller
            delta_y = mp(2) - appData.panelResizeStart(2);
            figH    = fig.Position(4);
            % Available px after toolbar row + padding + spacings
            %   rootGL: Padding [8 8 8 8] → 16 px;  2 RowSpacing gaps of 6 → 12 px
            availH  = figH - 16 - 12 - 222;
            newH    = round(appData.panelResizeOrig + delta_y);
            newH    = max(200, min(newH, availH - 100));  % leave ≥ 100 px for preview
            rootGL.RowHeight = {222, '1x', newH};

        elseif strcmp(appData.panelResizeDir, 'v_col12')
            % Mouse moves right → corrections panel gets wider
            delta_x = mp(1) - appData.panelResizeStart(1);
            newW    = round(appData.panelResizeOrig + delta_x);
            newW    = max(200, min(newW, 600));
            appData.corrPanelWidth = newW;
            cw    = analysisGL.ColumnWidth;
            cw{1} = newW;
            analysisGL.ColumnWidth = cw;

        elseif strcmp(appData.panelResizeDir, 'v_col23')
            % Mouse moves right → axis-limits panel gets wider
            delta_x = mp(1) - appData.panelResizeStart(1);
            newW    = round(appData.panelResizeOrig + delta_x);
            newW    = max(120, min(newW, 400));
            appData.axLimPanelWidth = newW;
            cw    = analysisGL.ColumnWidth;
            cw{2} = newW;
            analysisGL.ColumnWidth = cw;

        elseif strcmp(appData.panelResizeDir, 'v_col34')
            % Mouse moves right → peak-analysis panel gets wider
            delta_x = mp(1) - appData.panelResizeStart(1);
            newW    = round(appData.panelResizeOrig + delta_x);
            newW    = max(200, min(newW, 700));
            cw    = analysisGL.ColumnWidth;
            cw{3} = newW;
            analysisGL.ColumnWidth = cw;
        end
    end

    function onPanelResizeUp(~,~)
    %ONPANELRESIZEUP  Finish a panel border drag and restore normal idle handlers.
        fig.WindowButtonMotionFcn = @onMouseHover;
        fig.WindowButtonUpFcn     = '';
        appData.panelResizeStart  = [];
        appData.panelResizeOrig   = [];
        % panelResizeDir and Pointer are left for onMouseHover to update on next move
    end

    % ── Waterfall helpers ────────────────────────────────────────────────

    function s = computeAutoWaterfallSpacing()
    %COMPUTEAUTOWATERFALLSPACING  Return 1.1× the maximum data range across all
    %  loaded datasets for the first selected Y channel.  Used when the spacing
    %  field is blank so adjacent stacked traces just clear each other.
        s = 1;   % safe fallback if no data range can be determined
        ySel = ensureCell(lbY.Value);
        if isempty(ySel), return; end
        maxRange = 0;
        for ddi = 1:numel(appData.datasets)
            ds2      = appData.datasets{ddi};
            primaryD = guiTernary(~isempty(ds2.corrData), ds2.corrData, ds2.data);
            idx2     = find(strcmp(primaryD.labels, ySel{1}), 1);
            if isempty(idx2), continue; end
            yVals = primaryD.values(:, idx2);
            yVals = yVals(~isnan(yVals));
            if numel(yVals) < 2, continue; end
            r = max(yVals) - min(yVals);
            if r > maxRange, maxRange = r; end
        end
        if maxRange > 0, s = maxRange * 1.1; end
    end

    % ── Dataset list drag-to-reorder ─────────────────────────────────────

    function tf = isInListbox()
    %ISINLISTBOX  Return true if fig.CurrentPoint is over the dataset listbox.
        try
            mp    = fig.CurrentPoint;
            lbPos = getpixelposition(lbDatasets, true);
            tf = mp(1) >= lbPos(1) && mp(1) <= lbPos(1)+lbPos(3) && ...
                 mp(2) >= lbPos(2) && mp(2) <= lbPos(2)+lbPos(4);
        catch
            tf = false;
        end
    end

    function idx = listboxRowAt(py)
    %LISTBOXROWAT  Convert a figure-pixel Y-coordinate to a 1-based row index in lbDatasets.
    %  Uses a fixed 22 px row height (MATLAB uilistbox default at font size 12).
        ITEM_H = 22;
        try
            lbPos  = getpixelposition(lbDatasets, true);
            nItems = numel(lbDatasets.Items);
            if nItems == 0, idx = 0; return; end
            distFromTop = (lbPos(2) + lbPos(4)) - py;
            if distFromTop <= 0, idx = 0; return; end
            idx = min(nItems, max(1, ceil(distFromTop / ITEM_H)));
        catch
            idx = 0;
        end
    end

    function onListDragMove(~,~)
    %ONLISTDRAGMOVE  Provide drag feedback while reordering the dataset list.
    %  Activates after the mouse has moved > 8 px from the initial click.
        mp  = fig.CurrentPoint;
        if ~appData.listDragActive
            if norm(mp - appData.listDragStartPt) < 8, return; end
            appData.listDragActive = true;
        end
        fig.Pointer = 'fleur';
        nDS = numel(appData.datasets);
        tgt = listboxRowAt(mp(2));
        tgt = max(1, min(nDS, tgt));
        % Temporarily highlight target row without triggering onSelectDataset
        lbDatasets.ValueChangedFcn = [];
        lbDatasets.Value           = tgt;
        lbDatasets.ValueChangedFcn = @onSelectDataset;
    end

    function onListDragUp(~,~)
    %ONLISTDRAGUP  Commit the reorder and rebuild the dataset list.
        fig.WindowButtonMotionFcn = @onMouseHover;
        fig.WindowButtonUpFcn     = '';
        fig.Pointer               = 'arrow';

        src = appData.listDragSrcIdx;
        appData.listDragSrcIdx  = 0;
        appData.listDragStartPt = [];

        if ~appData.listDragActive
            % Was just a click, not a real drag — restore normal selection
            appData.listDragActive = false;
            rebuildDatasetList(true);
            return;
        end
        appData.listDragActive = false;

        nDS = numel(appData.datasets);
        tgt = listboxRowAt(fig.CurrentPoint(2));
        tgt = max(1, min(nDS, tgt));

        if src < 1 || src > nDS || tgt == src
            rebuildDatasetList(true);
            return;
        end

        % Build new order: remove src, insert at tgt
        order         = 1:nDS;
        order(src)    = [];                                  % [1..src-1, src+1..nDS]
        order         = [order(1:tgt-1), src, order(tgt:end)];

        appData.datasets  = appData.datasets(order);
        appData.activeIdx = find(order == appData.activeIdx, 1);  % follow active dataset

        rebuildDatasetList(true);
        onPlot([], []);
    end

end  % dataImportGUI


% ════════════════════════════════════════════════════════════════════════
%  Module-level helpers  (stateless — no access to GUI handles)
% ════════════════════════════════════════════════════════════════════════

function merged = deduplicatePeaks(peaks, minSep)
%DEDUPLICATEPEAKS  Remove peaks within minSep of each other.
%  When two peaks overlap, keep the one with greater height.
%  Priority: 'auto' status is preferred over 'manual' at equal height.
    if numel(peaks) <= 1, merged = peaks; return; end
    centers = [peaks.center];
    heights = [peaks.height];
    keep    = true(1, numel(peaks));
    for i = 1:numel(peaks)
        if ~keep(i), continue; end
        for j = (i+1):numel(peaks)
            if ~keep(j), continue; end
            if abs(centers(i) - centers(j)) < minSep
                % Prefer higher peak; break ties in favour of 'auto'
                iWins = heights(i) > heights(j) || ...
                        (heights(i) == heights(j) && strcmp(peaks(i).status,'auto'));
                if iWins
                    keep(j) = false;
                else
                    keep(i) = false;
                    break;   % i is gone — move to next i
                end
            end
        end
    end
    merged = peaks(keep);
end

function [pkX, pkH, pkW] = simplePeakFind(xv, yv, minProm, minDist)
%SIMPLEPEAKFIND  Minimal local-maxima detector (no Signal Processing Toolbox).
%   Returns peak x-positions (pkX), heights (pkH) and estimated half-widths (pkW).
%   Used as fallback when findpeaks is unavailable.
%
%   simplePeakFind(xv, yv, minProm)           – prominence filter only
%   simplePeakFind(xv, yv, minProm, minDist)  – also enforce minimum x-separation
    if nargin < 4, minDist = 0; end
    n   = numel(yv);
    if n < 3
        pkX = []; pkH = []; pkW = []; return;
    end
    % A point is a local max if it exceeds both neighbours
    isMax = false(n,1);
    isMax(2:end-1) = yv(2:end-1) > yv(1:end-2) & yv(2:end-1) > yv(3:end);
    % Apply minimum prominence filter
    yMin = min(yv);
    isMax = isMax & (yv > yMin + minProm);
    pkX = xv(isMax);
    pkH = yv(isMax);
    % Minimum-distance suppression: greedy, highest peak wins
    if minDist > 0 && numel(pkX) > 1
        [pkH_s, ord] = sort(pkH, 'descend');
        pkX_s = pkX(ord);
        keep  = true(size(pkX_s));
        for ii = 1:numel(pkX_s)
            if ~keep(ii), continue; end
            for jj = (ii+1):numel(pkX_s)
                if ~keep(jj), continue; end
                if abs(pkX_s(ii) - pkX_s(jj)) < minDist
                    keep(jj) = false;
                end
            end
        end
        pkX = pkX_s(keep);
        pkH = pkH_s(keep);
        % Restore original x-order so downstream code sees sorted positions
        [pkX, reord] = sort(pkX);
        pkH = pkH(reord);
    end
    % Rough width estimate: 2% of x-span per peak
    pkW = ones(size(pkX)) * diff([min(xv) max(xv)]) * 0.02;
end

function ds = buildDs(fp, data, parserName)
%BUILDDS  Assemble the standard dataset struct from a parsed data struct.
    ds.data        = data;
    ds.filepath    = fp;
    ds.parserName  = parserName;
    ds.displayName = '';          % '' = use filepath-derived name in rebuildDatasetList
    ds.corrData    = [];
    ds.xOff        = 0;
    ds.yOff        = 0;
    ds.bgSlope     = 0;
    ds.bgInt       = 0;
    ds.color         = [];        % [] = Auto (lines() palette); [r g b] = override
    ds.colorR        = [];        % [] = Auto for right-axis channels
    ds.legendName    = '';        % '' = Auto (built from channel name)
    ds.legendNameR   = '';        % '' = Auto for right-axis channels
    ds.smoothEnabled = false;
    ds.smoothWindow  = 5;
    ds.smoothMethod  = 'Moving';
    ds.peaks       = struct('center',{},'fwhm',{},'height',{}, ...
                            'xRange',{},'status',{},'bg',{},'model',{});
    ds.axLims      = struct('xMin','','xMax','','xStep','', ...
                            'yMin','','yMax','','yStep','', ...
                            'y2Min','','y2Max','','y2Step','');
end


function [data, parserName] = guiImport(fp)
%GUIIMPORT  Dispatch to the correct parser and return both data and parser name.
    [~,~,ext] = fileparts(fp);
    ext = lower(ext);
    switch ext
        case '.raw'
            data       = parser.importRigaku_raw(fp);
            parserName = 'importRigaku_raw';

        case '.xrdml'
            % Load raw counts; the GUI's Cts/s toggle handles cps conversion.
            data       = parser.importXRDML(fp, Intensity='counts');
            parserName = 'importXRDML';

        case {'.xlsx','.xls','.xlsm','.xlsb','.ods'}
            data       = parser.importExcel(fp);
            parserName = 'importExcel';

        case {'.csv','.tsv','.txt'}
            data       = parser.importCSV(fp);
            parserName = 'importCSV';

        case '.dat'
            % Load every available channel so the user can explore them in the GUI.
            try
                data       = parser.importQDVSM(fp, 'Verbose', false, 'YAxis', 'all');
                parserName = 'importQDVSM';
            catch ME
                if contains(ME.message,'[Data]','IgnoreCase',true)
                    data       = parser.importPPMS(fp, 'YAxis', 'all');
                    parserName = 'importPPMS';
                else
                    rethrow(ME);
                end
            end

        otherwise
            error('dataImportGUI:unknownExt', ...
                'No parser for extension "%s".\nSupported: .raw  .xlsx  .csv  .tsv  .txt  .dat', ...
                ext);
    end
end


function name = guiXName(meta)
    if isfield(meta,'xColumnName') && ~isempty(meta.xColumnName)
        name = meta.xColumnName;
    else
        name = 'X';
    end
end


function u = guiXUnit(meta)
    if isfield(meta,'xColumnUnit') && ~isempty(meta.xColumnUnit)
        u = meta.xColumnUnit;
    else
        u = '';
    end
end


function s = guiLabel(name, unit)
    name = greekify(name);
    if isempty(unit)
        s = name;
    else
        s = [name, ' (', greekify(unit), ')'];
    end
end


function s = greekify(s)
%GREEKIFY  Replace spelled-out Greek letter names and unit words with the
%  corresponding Unicode characters in axis label strings.
%
%  Rules:
%    - Case-insensitive: "theta", "Theta", "THETA" all → "θ"
%    - Boundary-guarded: only replaces when not immediately surrounded by
%      other letters, so "formula" is safe (mu not matched) but "2theta",
%      "mu0", and "phi_1" are converted correctly.
%    - Longest names first to prevent partial matches (e.g. "epsilon"
%      before "si", "beta"/"theta"/"zeta" before "eta";
%      "degrees" before "degree" before "deg").
    pairs = {
        'degrees', '°';   % 7 — before "degree" so plural is caught first
        'epsilon', 'ε';   % 7
        'degree',  '°';   % 6 — before "deg"
        'lambda',  'λ';   % 6
        'omega',   'ω';   % 5
        'theta',   'θ';   % 5
        'sigma',   'σ';   % 5
        'alpha',   'α';   % 5
        'gamma',   'γ';   % 5
        'delta',   'δ';   % 5
        'kappa',   'κ';   % 5
        'beta',    'β';   % 4
        'zeta',    'ζ';   % 4
        'phi',     'φ';   % 3
        'chi',     'χ';   % 3
        'psi',     'ψ';   % 3
        'tau',     'τ';   % 3
        'rho',     'ρ';   % 3
        'deg',     '°';   % 3 — after "degree"/"degrees"
        'eta',     'η';   % 3
        'mu',      'μ';   % 2
        'nu',      'ν';   % 2
        'xi',      'ξ';   % 2
        'pi',      'π';   % 2
    };
    for k = 1:size(pairs, 1)
        pat = ['(?i)(?<![a-zA-Z])', pairs{k,1}, '(?![a-zA-Z])'];
        s   = regexprep(s, pat, pairs{k,2});
    end
end


function ls = guiLineSpec(style)
    switch style
        case 'Scatter'
            ls = {'LineStyle','none','Marker','o','MarkerSize',5};
        case 'Line+Pts'
            ls = {'LineStyle','-','Marker','o','MarkerSize',4};
        otherwise   % 'Line'
            ls = {'LineStyle','-'};
    end
end


function ls = guiLineSpec_raw(style)
%GUILINESPEC_RAW  Dashed line spec for the raw-data overlay.
    switch style
        case 'Scatter'
            ls = {'LineStyle','none','Marker','o','MarkerSize',5,'LineWidth',0.75};
        case 'Line+Pts'
            ls = {'LineStyle','--','Marker','o','MarkerSize',4,'LineWidth',0.75};
        otherwise   % 'Line'
            ls = {'LineStyle','--','LineWidth',0.75};
    end
end


function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end


function c = ensureCell(v)
%ENSURECELL  Wrap a char/string scalar in a cell array; pass cell arrays through.
    if ischar(v) || isstring(v)
        c = cellstr(v);
    else
        c = v;
    end
end


function guiSaveCSV(d, fp, dRaw)
%GUISAVECSV  Write a data struct to a comma-delimited CSV file.
%   Columns: x-axis (d.time) then all y-channels (d.values).
%   A header row of column names (with units in parentheses) is written first.
%
%   guiSaveCSV(d, fp)        — write corrected data only
%   guiSaveCSV(d, fp, dRaw)  — append raw data columns after corrected columns
%
%   When dRaw is supplied the headers are suffixed:
%     corrected  →  'X [corr]', 'Label (unit) [corr]', ...
%     raw        →  'X [raw]',  'Label (unit) [raw]',  ...

    hasRaw = nargin >= 3 && ~isempty(dRaw) && isfield(dRaw, 'time');
    suffix = guiTernary(hasRaw, ' [corr]', '');

    % ── Header row ────────────────────────────────────────────────────
    xHdr  = ['X', suffix];
    nY    = size(d.values, 2);
    yHdrs = cell(1, nY);
    for k = 1:nY
        base     = guiTernary(~isempty(d.units{k}), ...
                       sprintf('%s (%s)', d.labels{k}, d.units{k}), d.labels{k});
        yHdrs{k} = [base, suffix];
    end
    allHdrs = [{xHdr}, yHdrs];

    if hasRaw
        nYr       = size(dRaw.values, 2);
        rawYHdrs  = cell(1, nYr);
        for k = 1:nYr
            base        = guiTernary(~isempty(dRaw.units{k}), ...
                              sprintf('%s (%s)', dRaw.labels{k}, dRaw.units{k}), dRaw.labels{k});
            rawYHdrs{k} = [base, ' [raw]'];
        end
        allHdrs = [allHdrs, {'X [raw]'}, rawYHdrs];
    end

    % ── Validate and open file ────────────────────────────────────────
    dirPart = fileparts(fp);
    if ~isempty(dirPart) && ~isfolder(dirPart)
        error('guiSaveCSV:badDir', 'Output directory does not exist:\n%s', dirPart);
    end

    fid = fopen(fp, 'w');
    if fid < 0
        error('guiSaveCSV:cannotOpen', 'Cannot open file for writing:\n%s', fp);
    end
    closeGuard = onCleanup(@() fclose(fid)); %#ok<NASGU>

    % ── Header ────────────────────────────────────────────────────────
    fprintf(fid, '%s\n', strjoin(allHdrs, ','));

    % ── Data rows ─────────────────────────────────────────────────────
    nRows = numel(d.time);
    for r = 1:nRows
        % Corrected x
        if isdatetime(d.time)
            fprintf(fid, '%s', datestr(d.time(r), 'yyyy-mm-dd HH:MM:SS')); %#ok<DATST>
        else
            fprintf(fid, '%.10g', d.time(r));
        end
        % Corrected y channels
        for c = 1:size(d.values, 2)
            fprintf(fid, ',%.10g', d.values(r, c));
        end
        % Raw columns (appended when available and row index is in range)
        if hasRaw && r <= numel(dRaw.time)
            if isdatetime(dRaw.time)
                fprintf(fid, ',%s', datestr(dRaw.time(r), 'yyyy-mm-dd HH:MM:SS')); %#ok<DATST>
            else
                fprintf(fid, ',%.10g', dRaw.time(r));
            end
            for c = 1:size(dRaw.values, 2)
                fprintf(fid, ',%.10g', dRaw.values(r, c));
            end
        end
        fprintf(fid, '\n');
    end
end


function out = guiMetaLines(d, parserName, fp)
%GUIMETALINES Build metadata summary lines using the unified metadata schema.
    [~,fn,ex] = fileparts(fp);
    m   = d.metadata;
    out = {};

    % ── Core fields ────────────────────────────────────────────────────
    out{end+1} = sprintf('File:    %s%s', fn, ex);
    out{end+1} = sprintf('Parser:  %s  [%s]', guiParserLabel(parserName), parserName);

    xName = guiXName(m);
    xUnit = guiXUnit(m);
    if ~isempty(xUnit)
        out{end+1} = sprintf('X axis:  %s (%s)', xName, xUnit);
    else
        out{end+1} = sprintf('X axis:  %s', xName);
    end

    % ── Parser-specific fields ─────────────────────────────────────────
    if isfield(m, 'parserSpecific')
        ps = m.parserSpecific;
        out{end+1} = '---';
        psFields = fieldnames(ps);
        for fi = 1:numel(psFields)
            fname = psFields{fi};
            val   = ps.(fname);
            % Scalar numeric or short char
            if isnumeric(val) && isscalar(val)
                out{end+1} = sprintf('%-14s %g', [fname ':'], val);
            elseif (ischar(val) || (isstring(val) && isscalar(val))) && ~isempty(val)
                out{end+1} = sprintf('%-14s %s', [fname ':'], char(val));
            elseif iscell(val) && ~isempty(val) && numel(val) <= 4
                out{end+1} = sprintf('%-14s %s', [fname ':'], strjoin(val, ', '));
            elseif isstruct(val)
                % Sub-struct: show up to 4 scalar fields
                subFn = fieldnames(val);
                out{end+1} = sprintf('%s:', fname);
                shown = 0;
                for sfi = 1:numel(subFn)
                    sv = val.(subFn{sfi});
                    if (ischar(sv) || (isnumeric(sv) && isscalar(sv))) && shown < 4
                        out{end+1} = sprintf('  %-12s %s', [subFn{sfi} ':'], num2str(sv));
                        shown = shown + 1;
                    end
                end
            elseif iscell(val) && ~isempty(val)
                % Cell array (allColumnNames etc.) — list items
                out{end+1} = sprintf('%s  (%d):', fname, numel(val));
                for ci = 1:numel(val)
                    out{end+1} = sprintf('  %s', val{ci});
                end
            end
        end
    end

    % ── Summary counts ────────────────────────────────────────────────
    out{end+1} = '---';
    out{end+1} = sprintf('Rows:    %d', numel(d.time));
    out{end+1} = sprintf('Chan:    %d', size(d.values,2));

    % ── X-axis range ─────────────────────────────────────────────────
    out{end+1} = '---';
    xLbl = guiLabel(xName, xUnit);
    if isdatetime(d.time)
        out{end+1} = sprintf('X: %s  (datetime)', xLbl);
    else
        t = d.time(~isnan(d.time));
        if ~isempty(t)
            out{end+1} = sprintf('X: %s', xLbl);
            out{end+1} = sprintf('   [%.4g, %.4g]', min(t), max(t));
        end
    end

    % ── Loaded Y channel ranges ───────────────────────────────────────
    out{end+1} = '';
    out{end+1} = 'Loaded channels:';
    for k = 1:size(d.values,2)
        col = d.values(~isnan(d.values(:,k)), k);
        lbl = guiLabel(d.labels{k}, d.units{k});
        if isempty(col)
            out{end+1} = sprintf('  Y%d: %s  (all NaN)', k, lbl);
        else
            out{end+1} = sprintf('  Y%d: %s', k, lbl);
            out{end+1} = sprintf('       [%.4g, %.4g]', min(col), max(col));
        end
    end
end


function lbl = guiParserLabel(parserName)
%GUIPARSERLABEL Human-readable description for each parser function.
    switch parserName
        case 'importRigaku_raw', lbl = 'Rigaku SmartLab XRD';
        case 'importXRDML',   lbl = 'PANalytical XRDML';
        case 'importExcel',   lbl = 'Excel Spreadsheet';
        case 'importCSV',     lbl = 'Delimited Text';
        case 'importQDVSM',   lbl = 'Quantum Design VSM';
        case 'importPPMS',    lbl = 'QD PPMS (legacy)';
        otherwise,            lbl = parserName;
    end
end


function s = delimLabel(d)
%DELIMLABEL Human-readable delimiter name.
    switch d
        case ',',          s = 'comma (,)';
        case sprintf('\t'),s = 'tab';
        case ';',          s = 'semicolon (;)';
        case ' ',          s = 'space';
        otherwise,         s = sprintf('"%s"', d);
    end
end


function ct = guiCountingTime(ds)
%GUICOUNTINGTIME  Return counting time (s) for a dataset, or 0 if unavailable.
%   Uses try/catch to safely traverse the nested struct path without
%   a chain of isfield checks on each level.
    ct = 0;
    try
        ct = ds.data.metadata.parserSpecific.countingTime;
        if ~isnumeric(ct) || ~isscalar(ct) || ct <= 0
            ct = 0;
        end
    catch
    end
end
