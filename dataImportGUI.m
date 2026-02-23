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
    appData.selectedPeakIdx   = 0;    % row highlighted in peakTable (0 = none)
    appData.showFitCurves     = true;               % toggle Lorentzian fit overlay on/off
    appData.fitCurveColor     = [0.85 0.20 0.00];   % default warm red-orange

    % ── Figure ───────────────────────────────────────────────────────────
    fig = uifigure('Name','Data Import & Preview', ...
                   'Position',[80 80 1080 915]);

    % ── Dataset-colour palette (shared by widget and callbacks) ──────────
    DS_COLOR_NAMES = {'Auto','Blue','Orange','Red','Green', ...
                      'Purple','Teal','Brown','Black','Grey'};
    DS_COLOR_RGBS  = {[], [0.00 0.45 0.74], [0.85 0.33 0.10], ...
                      [0.80 0.07 0.07], [0.47 0.67 0.19], ...
                      [0.49 0.18 0.56], [0.30 0.75 0.93], ...
                      [0.64 0.35 0.10], [0.00 0.00 0.00], ...
                      [0.50 0.50 0.50]};

    % Root grid  (3 rows: dataset toolbar | content | analysis)
    rootGL = uigridlayout(fig,[3 1], ...
        'RowHeight',   {128,'1x',420}, ...
        'ColumnWidth', {'1x'}, ...
        'Padding',     [8 8 8 8], ...
        'RowSpacing',  6);

    % ── Toolbar row: Add / Remove buttons (top) + dataset listbox (middle) + colour (bottom) ─
    tbGL = uigridlayout(rootGL,[3 2], ...
        'RowHeight',    {26,60,26}, ...
        'ColumnWidth',  {'1x','1x'}, ...
        'Padding',      [0 0 0 0], ...
        'RowSpacing',   4, ...
        'ColumnSpacing', 6);
    tbGL.Layout.Row = 1;

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

    lblDSColor = uibutton(tbGL,'Text','Dataset Color:', ...
        'Enable','off','FontSize',10);
    lblDSColor.Layout.Row = 3; lblDSColor.Layout.Column = 1;

    ddDatasetColor = uidropdown(tbGL, ...
        'Items',     DS_COLOR_NAMES, ...
        'ItemsData', DS_COLOR_RGBS, ...
        'Value',     [], ...
        'Enable',    'off', ...
        'Tooltip',   'Override the colour used to plot this dataset. "Auto" uses the automatic palette.', ...
        'ValueChangedFcn', @onDatasetColorChanged);
    ddDatasetColor.Layout.Row = 3; ddDatasetColor.Layout.Column = 2;

    % ── Content: controls panel (left) | preview axes (right) ────────────
    contentGL = uigridlayout(rootGL,[1 2], ...
        'ColumnWidth',  {215,'1x'}, ...
        'Padding',      [0 0 0 0], ...
        'ColumnSpacing', 8);
    contentGL.Layout.Row = 2;

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
    ctrlPanel = uipanel(contentGL,'Title','Controls');
    ctrlPanel.Layout.Column = 1;

    ctrlGL = uigridlayout(ctrlPanel,[9 1], ...
        'RowHeight', {26,4,88,4,36,26,6,30,'1x'}, ...
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

    % Plot-style buttons (row 5) — three uibutton objects in a nested grid.
    styleGL = uigridlayout(ctrlGL,[1 3], ...
        'Padding',[0 0 0 0],'ColumnSpacing',2,'ColumnWidth',{'1x','1x','1x'});
    styleGL.Layout.Row = 5;

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
    chkGL.Layout.Row = 6;
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
    btnPlot.Layout.Row = 8;

    txtMeta = uitextarea(ctrlGL,'Value','','Editable','off', ...
        'FontSize',8,'FontName','Courier New');
    txtMeta.Layout.Row = 9;

    % ── Right: preview axes ───────────────────────────────────────────────
    axPanel = uipanel(contentGL,'Title','Preview');
    axPanel.Layout.Column = 2;
    axGL = uigridlayout(axPanel,[1 1],'Padding',[2 2 2 2]);
    ax = uiaxes(axGL);
    ax.Box = 'on';
    grid(ax,'on');
    title(ax,'Load a file to preview data','Interpreter','none');
    xlabel(ax,'');
    ylabel(ax,'');

    % ── Analysis & Corrections panel (row 3, full width) ─────────────────
    analysisPanel = uipanel(rootGL,'Title','Analysis & Corrections');
    analysisPanel.Layout.Row = 3;

    analysisGL = uigridlayout(analysisPanel,[2 3], ...
        'ColumnWidth', {420,204,'1x'}, ...
        'RowHeight',   {210,'1x'}, ...
        'Padding',     [6 6 6 6], ...
        'ColumnSpacing', 10, ...
        'RowSpacing', 6);

    % ── Corrections sub-panel (left column) ──────────────────────────────
    % 4-row × 4-col grid:
    %   rows 1-2: [label-btn | numeric-field | label-btn | numeric-field]
    %   row  3  : [Fit BG (span 1-2) | Est. Y Offset (span 3-4)]
    %   row  4  : [Apply (span 1-2) | Reset | Show Raw checkbox]
    corrPanel = uipanel(analysisGL,'Title','Corrections');
    corrPanel.Layout.Row = 1; corrPanel.Layout.Column = 1;

    corrGL = uigridlayout(corrPanel,[5 4], ...
        'RowHeight',    {26,26,26,26,32}, ...
        'ColumnWidth',  {70,'1x',88,'1x'}, ...
        'Padding',      [6 6 6 6], ...
        'RowSpacing',   4, ...
        'ColumnSpacing', 4);

    % Row 1: Correction style selector
    lblCorrStyle = uibutton(corrGL,'Text','Style:','Enable','off','FontSize',10);
    lblCorrStyle.Layout.Row = 1; lblCorrStyle.Layout.Column = 1;

    ddCorrStyle = uidropdown(corrGL, ...
        'Items',           {'Auto (from file)', 'Generic', 'VSM — Diamagnetic', 'PPMS', 'XRD — 2\theta + BG'}, ...
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

    % Row 4: Fit BG from Box | Est. Y Offset 2-click
    btnFitBG = uibutton(corrGL,'Text','Fit Linear BG from Box', ...
        'ButtonPushedFcn',@onFitBGRegion, ...
        'BackgroundColor',[0.50 0.28 0.05], ...
        'FontColor',[1 1 1], ...
        'Tooltip', ['Draw a rectangle on the preview axes.  ' ...
                    'All selected-Y data points inside the box are used to fit ' ...
                    'a linear background (polyfit deg-1).  ' ...
                    'BG Slope and Intercept are auto-populated then corrections are applied.']);
    btnFitBG.Layout.Row = 4; btnFitBG.Layout.Column = [1 2];

    btnPickY = uibutton(corrGL,'Text','Est. Y Offset  (2 pts)', ...
        'ButtonPushedFcn',@onPickYOrigin, ...
        'BackgroundColor',[0.45 0.20 0.55], ...
        'FontColor',[1 1 1], ...
        'Tooltip', ['Click two data points on the plot.  ' ...
                    'The Y Offset is updated so that y = 0 falls halfway ' ...
                    'between their y-values.  Works on whichever data is ' ...
                    'currently displayed (raw or corrected).']);
    btnPickY.Layout.Row = 4; btnPickY.Layout.Column = [3 4];

    % XRD-mode interactive tools — same row 4 cells, hidden by default.
    % applyParserAnalysisConfig() swaps visibility between these and the
    % generic (btnFitBG / btnPickY) buttons when the correction style changes.
    btnYTranslate = uibutton(corrGL,'Text','Y Translate (drag)', ...
        'ButtonPushedFcn',@onYTranslateDrag, ...
        'BackgroundColor',[0.10 0.35 0.65],'FontColor',[1 1 1], ...
        'Tooltip',['Click and drag up/down on the plot to shift the data ' ...
                   'vertically — updates Y Offset live on each mouse move.'], ...
        'Visible','off');
    btnYTranslate.Layout.Row = 4; btnYTranslate.Layout.Column = [1 2];

    btnAutoPeak = uibutton(corrGL,'Text','Auto Find Peaks', ...
        'ButtonPushedFcn',@onAutoPeak, ...
        'BackgroundColor',[0.55 0.20 0.05],'FontColor',[1 1 1], ...
        'Tooltip','Detect peaks automatically using findpeaks (Signal Processing Toolbox) or a built-in local-max fallback', ...
        'Visible','off');
    btnAutoPeak.Layout.Row = 4; btnAutoPeak.Layout.Column = 3;

    btnManualPeak = uibutton(corrGL,'Text','Add Peak', ...
        'ButtonPushedFcn',@onManualPeakAdd, ...
        'BackgroundColor',[0.45 0.20 0.55],'FontColor',[1 1 1], ...
        'Tooltip','Click once on a peak in the plot to add it to the peak list (click button again to finish)', ...
        'Visible','off');
    btnManualPeak.Layout.Row = 4; btnManualPeak.Layout.Column = 4;

    % Row 5: Apply | Reset | Show Raw
    btnApply = uibutton(corrGL,'Text','Apply Corrections', ...
        'ButtonPushedFcn',@onApplyCorrections, ...
        'BackgroundColor',[0.18 0.52 0.18], ...
        'FontColor',[1 1 1],'FontWeight','bold', ...
        'Tooltip','Compute corrected data and update plot');
    btnApply.Layout.Row = 5; btnApply.Layout.Column = [1 2];

    btnReset = uibutton(corrGL,'Text','Reset', ...
        'ButtonPushedFcn',@onResetCorrections, ...
        'Tooltip','Zero all correction fields and discard corrected data for the active dataset');
    btnReset.Layout.Row = 5; btnReset.Layout.Column = 3;

    cbShowRaw = uicheckbox(corrGL,'Text','Show Raw','Value',true, ...
        'Tooltip','When corrected data exists, also overlay raw data (dashed, desaturated)', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    cbShowRaw.Layout.Row = 5; cbShowRaw.Layout.Column = 4;

    % ── Axis Limits sub-panel (middle column) ────────────────────────────
    % All six fields are text-type: blank = auto-scale, any number = manual.
    % str2double('') == NaN, so blank naturally means "do not apply".
    axLimPanel = uipanel(analysisGL,'Title','Axis Limits');
    axLimPanel.Layout.Row = 1; axLimPanel.Layout.Column = 2;

    axLimGL = uigridlayout(axLimPanel,[4 4], ...
        'RowHeight',    {22,26,26,32}, ...
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

    efXMin = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','X axis minimum — blank = auto-scale', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXMin.Layout.Row = 2; efXMin.Layout.Column = 2;

    efXMax = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','X axis maximum — blank = auto-scale', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXMax.Layout.Row = 2; efXMax.Layout.Column = 3;

    efXStep = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','X axis major tick spacing — blank = auto ticks', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXStep.Layout.Row = 2; efXStep.Layout.Column = 4;

    % Row 3: Y axis
    lblYLim = uibutton(axLimGL,'Text','Y:','Enable','off');
    lblYLim.Layout.Row = 3; lblYLim.Layout.Column = 1;

    efYMin = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Y axis minimum — blank = auto-scale', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYMin.Layout.Row = 3; efYMin.Layout.Column = 2;

    efYMax = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Y axis maximum — blank = auto-scale', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYMax.Layout.Row = 3; efYMax.Layout.Column = 3;

    efYStep = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Y axis major tick spacing — blank = auto ticks', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYStep.Layout.Row = 3; efYStep.Layout.Column = 4;

    % Row 4: clear-all button
    btnAutoLimits = uibutton(axLimGL,'Text','Auto (Clear All)', ...
        'ButtonPushedFcn',@onAutoLimits, ...
        'Tooltip','Clear all manual axis limits — return to auto-scale');
    btnAutoLimits.Layout.Row = 4; btnAutoLimits.Layout.Column = [1 4];

    % ── Save Corrected Data sub-panel (right column) ──────────────────────
    savePanel = uipanel(analysisGL,'Title','Save Corrected Data');
    savePanel.Layout.Row = 1; savePanel.Layout.Column = 3;

    saveGL = uigridlayout(savePanel,[3 2], ...
        'RowHeight',    {26,32,32}, ...
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

    btnExportFig = uibutton(saveGL,'Text','Export to Figure', ...
        'ButtonPushedFcn',@onExportFigure, ...
        'BackgroundColor',[0.30 0.30 0.60], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Open a new figure window with the current plot (full MATLAB toolbar — ideal for publication-quality editing)');
    btnExportFig.Layout.Row = 3; btnExportFig.Layout.Column = [1 2];

    % ── Peak Analysis sub-panel (row 2, full width) ───────────────────────
    % Always visible; XRD buttons in corrGL activate it contextually.
    peakPanel = uipanel(analysisGL,'Title','Peak Analysis');
    peakPanel.Layout.Row = 2; peakPanel.Layout.Column = [1 3];

    peakGL = uigridlayout(peakPanel,[1 2], ...
        'ColumnWidth', {'1x',150}, ...
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
        'RowHeight',    {22,32,32,32,32,22,32,'1x'}, ...
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

        % uigetfile returns char for a single file, cell array for multiple
        if ischar(fnames)
            fnames = {fnames};
        end

        nLoaded = 0;
        for fi = 1:numel(fnames)
            fp = fullfile(fpath, fnames{fi});
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
                fprintf(2, '\n[dataImportGUI] Import error (%s): %s\n', fnames{fi}, ME.message);
                for si = 1:numel(ME.stack)
                    fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
                end
                uialert(fig, sprintf('%s\n\n%s', fnames{fi}, ME.message), 'Import error');
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
            txtMeta.Value = '';
            efXOffset.Value = 0;  efYOffset.Value = 0;
            efBGSlope.Value = 0;  efBGIntercept.Value = 0;
            efSavePath.Value = '';
            analysisPanel.Title = 'Analysis & Corrections';
            ddDatasetColor.Enable = 'off';
            ddDatasetColor.Value  = [];
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
        lims.yMin  = efYMin.Value;
        lims.yMax  = efYMax.Value;
        lims.yStep = efYStep.Value;
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
    %CANCELINTERACTIONS  Abort any in-progress BG-fit or y-origin pick.
        fig.WindowButtonDownFcn   = '';
        fig.WindowButtonMotionFcn = '';
        fig.WindowButtonUpFcn     = '';
        if ~isempty(appData.bgRectPatch) && isvalid(appData.bgRectPatch)
            delete(appData.bgRectPatch);
        end
        appData.bgRectPatch       = [];
        appData.bgStartPt         = [];
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
    end

    function updateControlsForActiveDataset()
    %UPDATECONTROLSFORACTIVEDATASET  Sync all controls to the active dataset.
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        d  = ds.data;

        % Suppress value-change callbacks during bulk update
        ddX.ValueChangedFcn = [];
        lbY.ValueChangedFcn = [];

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

        txtMeta.Value = guiMetaLines(d, ds.parserName, ds.filepath);

        % Enable Counts/s only for Rigaku files with a valid counting time
        ct = guiCountingTime(ds);
        cbCountsPerSec.Enable = guiTernary(ct > 0, 'on', 'off');
        if ct == 0
            cbCountsPerSec.Value = false;
        end

        % Restore this dataset's colour override ([] = Auto)
        ddDatasetColor.Enable = 'on';
        ddDatasetColor.Value  = ds.color;

        % Restore this dataset's correction parameter values
        efXOffset.Value     = ds.xOff;
        efYOffset.Value     = ds.yOff;
        efBGSlope.Value     = ds.bgSlope;
        efBGIntercept.Value = ds.bgInt;

        % Restore per-dataset axis limits (auto-scale if not yet saved)
        if isfield(ds, 'axLims')
            efXMin.Value  = ds.axLims.xMin;
            efXMax.Value  = ds.axLims.xMax;
            efXStep.Value = ds.axLims.xStep;
            efYMin.Value  = ds.axLims.yMin;
            efYMax.Value  = ds.axLims.yMax;
            efYStep.Value = ds.axLims.yStep;
        else
            efXMin.Value = '';  efXMax.Value = '';  efXStep.Value = '';
            efYMin.Value = '';  efYMax.Value = '';  efYStep.Value = '';
        end

        if ~isempty(ds.corrData)
            [fp2, fn2, ~] = fileparts(ds.filepath);
            efSavePath.Value = fullfile(fp2, [fn2, '_corrected.csv']);
        else
            efSavePath.Value = '';
        end

        applyParserAnalysisConfig(resolvedCorrStyle());

        ddX.ValueChangedFcn = @onAxisChanged;
        lbY.ValueChangedFcn = @onAxisChanged;

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
                btnFitBG.Visible      = 'off';
                btnPickY.Visible      = 'off';
                btnYTranslate.Visible = 'on';
                btnAutoPeak.Visible   = 'on';
                btnManualPeak.Visible = 'on';

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
                btnFitBG.Visible      = 'on';
                btnPickY.Visible      = 'on';
                btnYTranslate.Visible = 'off';
                btnAutoPeak.Visible   = 'off';
                btnManualPeak.Visible = 'off';

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
                btnFitBG.Visible      = 'on';
                btnPickY.Visible      = 'on';
                btnYTranslate.Visible = 'off';
                btnAutoPeak.Visible   = 'off';
                btnManualPeak.Visible = 'off';

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
                btnFitBG.Visible      = 'on';
                btnPickY.Visible      = 'on';
                btnYTranslate.Visible = 'off';
                btnAutoPeak.Visible   = 'off';
                btnManualPeak.Visible = 'off';
        end
    end

    function pName = resolvedCorrStyle()
    %RESOLVEDCORRSTYLE  Map ddCorrStyle dropdown value to a parser name string.
    %  'Auto (from file)' → use the active dataset's actual parserName.
    %  All other choices → return a fixed parser name that drives the labels.
        switch ddCorrStyle.Value
            case 'VSM — Diamagnetic'
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
        fig.WindowButtonDownFcn   = '';
        fig.WindowButtonMotionFcn = '';
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
        xSpan = diff([min(xv), max(xv)]);

        PEAK_MIN_PROM_FRAC  = 0.05;   % min prominence as fraction of y-range
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
        try
            [pkH, pkX, pkW, ~] = findpeaks(yv, xv, ...
                'MinPeakProminence', minProm, ...
                'WidthReference',    'halfprom');
        catch
            [pkX, pkH, pkW] = simplePeakFind(xv, yv, minProm);
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

        ds.corrData = corrData;
        ds.xOff     = xOff;
        ds.yOff     = yOff;
        ds.bgSlope  = bgSlope;
        ds.bgInt    = bgIntcpt;
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
        efSavePath.Value    = '';

        if appData.activeIdx >= 1 && ~isempty(appData.datasets)
            ds            = appData.datasets{appData.activeIdx};
            ds.corrData   = [];
            ds.xOff       = 0;
            ds.yOff       = 0;
            ds.bgSlope    = 0;
            ds.bgInt      = 0;
            ds.peaks      = struct('center',{},'fwhm',{},'height',{}, ...
                                   'xRange',{},'status',{},'bg',{},'model',{});
            appData.datasets{appData.activeIdx} = ds;
            appData.selectedPeakIdx = 0;
        end

        cancelInteractions();
        refreshPeakTable();
        onPlot([],[]);
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
        fig.WindowButtonDownFcn   = '';
        fig.WindowButtonMotionFcn = '';
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
            fig.WindowButtonDownFcn = '';

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
            guiSaveCSV(ds.corrData, fp);
            uialert(fig, sprintf('Saved:\n%s', fp), 'Saved');
        catch ME
            fprintf(2, '\n[dataImportGUI] Save error: %s\n', ME.message);
            for si = 1:numel(ME.stack)
                fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
            end
            uialert(fig, ME.message, 'Save error');
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
            nY = numel(ySel);

            % ── Colour allocation ─────────────────────────────────────────
            % lines(nDS * nY) gives one colour per (dataset, channel) pair.
            % Index = (datasetIndex-1)*nY + channelIndex — consistent
            % regardless of which datasets happen to have a given channel.
            colors = lines(max(nDS * nY, 1));

            % ── Draw ──────────────────────────────────────────────────────
            % delete() removes ALL children including HandleVisibility='off' objects
            % (peak markers); cla() alone misses those and leaves them on screen.
            delete(targetAx.Children);
            cla(targetAx);
            hold(targetAx,'on');
            lsPrimary    = guiLineSpec(appData.style);
            lsRaw        = guiLineSpec_raw(appData.style);
            anyRawShown  = false;

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

                % Per-dataset colour override ([] = Auto → fall back to lines() palette)
                dsColorOverride = [];
                if isfield(ds,'color') && ~isempty(ds.color)
                    dsColorOverride = ds.color;
                end

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
                        rawColor = 0.5 * baseColor + 0.5 * [1 1 1];
                        if isdatetime(xVecRaw)
                            good = ~isnat(xVecRaw) & ~isnan(yRaw);
                        else
                            good = ~isnan(xVecRaw) & ~isnan(yRaw);
                        end
                        plot(targetAx, xVecRaw(good), yRaw(good), lsRaw{:}, ...
                            'Color',       rawColor, ...
                            'DisplayName', [baseLabel, ' (raw)']);
                    end

                    % Primary trace
                    yPrimary = primaryD.values(:, idx);
                    if ctFactor > 0, yPrimary = yPrimary / ctFactor; end
                    if isdatetime(xVecPrimary)
                        good = ~isnat(xVecPrimary) & ~isnan(yPrimary);
                    else
                        good = ~isnan(xVecPrimary) & ~isnan(yPrimary);
                    end
                    dispName = guiTernary(hasCorrData, [baseLabel, ' (corr)'], baseLabel);
                    plot(targetAx, xVecPrimary(good), yPrimary(good), lsPrimary{:}, ...
                        'Color',       baseColor, ...
                        'DisplayName', dispName);
                end
            end
            hold(targetAx,'off');

            % Legend: on when multi-channel, multi-dataset, or raw overlay shown
            if nY > 1 || nDS > 1 || anyRawShown
                legend(targetAx,'Location','best');
            else
                legend(targetAx,'off');
            end

            xlabel(targetAx, xLabel);
            % Y-axis label only when single channel + single dataset
            if nY == 1 && nDS == 1
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
            title(targetAx, titleStr, 'Interpreter','none');

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
            warnColor  = [1.00 0.88 0.88];
            clearColor = [1.00 1.00 1.00];
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

                            isSel = (pi == appData.selectedPeakIdx);
                            plot(targetAx, xFitPlot, yFitPlot, '-', ...
                                'Color',            fitColor, ...
                                'LineWidth',        guiTernary(isSel, 2.5, 1.5), ...
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
                            'HandleVisibility', 'off');

                        % Peak index + centre label near the bottom
                        text(targetAx, pk.center, yLo + ySpan*0.03, ...
                            sprintf('#%d  %.3f\xb0', pi, pk.center), ...
                            'FontSize',           7, ...
                            'HorizontalAlignment','center', ...
                            'Color',              lineColor, ...
                            'HandleVisibility',   'off', ...
                            'Interpreter',        'none');

                        % FWHM horizontal bar at the true half-maximum height
                        % For a fitted Lorentzian: half-max is at bg + H/2.
                        % For un-fitted peaks: fall back to H/2 as an estimate.
                        if ~isnan(pk.fwhm) && pk.fwhm > 0
                            hasBg = isfield(pk,'bg') && ~isempty(pk.bg) && ~isnan(pk.bg);
                            halfH = guiTernary(hasBg, pk.bg + pk.height*0.5, pk.height*0.5);
                            plot(targetAx, ...
                                [pk.center - pk.fwhm/2, pk.center + pk.fwhm/2], ...
                                [halfH, halfH], '-', ...
                                'Color',            lineColor, ...
                                'LineWidth',        2.0, ...
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
        saveAxisLimsToActiveDataset();
        onPlot([],[]);
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

function [pkX, pkH, pkW] = simplePeakFind(xv, yv, minProm)
%SIMPLEPEAKFIND  Minimal local-maxima detector (no Signal Processing Toolbox).
%   Returns peak x-positions (pkX), heights (pkH) and estimated half-widths (pkW).
%   Used as fallback when findpeaks is unavailable.
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
    ds.color       = [];          % [] = Auto (lines() palette); [r g b] = override
    ds.peaks       = struct('center',{},'fwhm',{},'height',{}, ...
                            'xRange',{},'status',{},'bg',{},'model',{});
    ds.axLims      = struct('xMin','','xMax','','xStep','', ...
                            'yMin','','yMax','','yStep','');
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
    if isempty(unit)
        s = name;
    else
        s = [name, ' (', unit, ')'];
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


function guiSaveCSV(d, fp)
%GUISAVECSV  Write a data struct to a comma-delimited CSV file.
%   Columns: x-axis (d.time) then all y-channels (d.values).
%   A header row of column names (with units in parentheses) is written first.
    % Build header row
    xHdr = 'X';
    yHdrs = cell(1, size(d.values, 2));
    for k = 1:numel(yHdrs)
        if ~isempty(d.units{k})
            yHdrs{k} = sprintf('%s (%s)', d.labels{k}, d.units{k});
        else
            yHdrs{k} = d.labels{k};
        end
    end
    allHdrs = [{xHdr}, yHdrs];

    dirPart = fileparts(fp);
    if ~isempty(dirPart) && ~isfolder(dirPart)
        error('guiSaveCSV:badDir', 'Output directory does not exist:\n%s', dirPart);
    end

    fid = fopen(fp, 'w');
    if fid < 0
        error('guiSaveCSV:cannotOpen', 'Cannot open file for writing:\n%s', fp);
    end
    closeGuard = onCleanup(@() fclose(fid));

    % Header
    fprintf(fid, '%s\n', strjoin(allHdrs, ','));

    % Data rows
    nRows = numel(d.time);
    for r = 1:nRows
        if isdatetime(d.time)
            fprintf(fid, '%s', datestr(d.time(r), 'yyyy-mm-dd HH:MM:SS'));
        else
            fprintf(fid, '%.10g', d.time(r));
        end
        for c = 1:size(d.values, 2)
            fprintf(fid, ',%.10g', d.values(r, c));
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
