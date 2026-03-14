function varargout = dataImportGUI()
%DATAIMPORTGUI  Browse, import and preview data files using the +parser toolkit.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   dataImportGUI()
%   api = dataImportGUI()
%
% ── Supported File Formats ────────────────────────────────────────────────
%
%   Extension(s)          Parser              Instrument / Format
%   ─────────────────     ──────────────────  ───────────────────────────────
%   .xrdml                importXRDML         PANalytical / Malvern Empyrean
%   .brml                 importBruker        Bruker D8/D2 (ZIP+XML)
%   .raw  (magic "FI")    importRigaku_raw    Rigaku SmartLab binary
%   .raw  (magic RAW1.01) importBruker        Bruker binary v3
%   .dat  ([Header])      importQDVSM         Quantum Design VSM / DynaCool
%   .dat  (plain CSV)     importPPMS          Quantum Design PPMS legacy
%   .dat  (MPMS SQUID)    importMPMS          Quantum Design MPMS
%   .dat  (Lake Shore)    importLakeShore     Lake Shore VSM / cryostat
%   .refl                 importNCNRRefl      NCNR neutron reflectometry
%   .pnr                  importNCNRPNR       NCNR polarized neutron refl.
%   .datA/.datB/.datC/.datD  importNCNRDat   refl1d fit output
%   .csv / .tsv / .txt    importCSV           Generic delimited text
%   .xlsx / .xls / .ods   importExcel         Spreadsheet
%
%   Auto-detection priority:
%     1. Magic bytes  (.raw: first 7 bytes → Rigaku or Bruker)
%     2. Extension    (all others above)
%     3. Content      (.dat: [Header]/[Data] markers → importQDVSM)
%
% ── GUI Overview ──────────────────────────────────────────────────────────
%
%   All loaded datasets are overlaid on the same axes.  Click a row in the
%   dataset list to make it active — channel selectors, corrections, and
%   peak tools then operate on that file only.
%
%   Toolbar (top):
%     Add Files / Drop files onto window  — loads one or more files at once
%     Dataset list (left panel)           — shows badge [XRD]/[MAG]/[NR]/…,
%                                           legend name, search/filter box
%     X / Y / Y2 channel dropdowns        — select columns to plot
%     Log X / Log Y                       — toggle log scale per axis
%     Plot style                          — Line | Scatter | Line+Markers
%     Waterfall offset                    — stacked view for series data
%     Colormap                            — auto-color datasets from a map
%
%   Corrections panel (left):
%     X Offset / Y Offset                 — rigid shift applied before plot
%     Background slope / intercept        — linear BG subtraction
%     Background file                     — subtract a separate reference file
%     Smoothing (moving average)
%     Normalization                       — None / Peak / Area / Z-score
%     Data trim (X min / X max)           — crop scan edges
%     Correction style dropdown           — selects parser-aware defaults
%     Apply / Reset / Undo
%     Apply to All                        — copy corrections to every dataset
%
%   Peak tools panel (right, XRD only):
%     Auto-detect peaks (prominence threshold)
%     Manual add / remove
%     Fit All (Lorentzian or Gaussian)
%     Fit All Together (simultaneous multi-peak fit)
%     Peak table: Center / FWHM / Height / Area / Status
%     Export peak summary CSV / XLSX
%
%   Axes & Appearance panel:
%     X / Y / Y2 limits (manual or auto)
%     Tick notation (auto / sci / engineering / exp=0)
%     Custom axis labels / title
%     Legend names per dataset
%     Color pickers (left and right axes)
%     Save figure (PNG/TIFF 300 dpi, PDF/SVG vector)
%
%   Save panel:
%     Save corrected CSV / batch export all datasets
%     Copy data to clipboard
%     Export to MATLAB figure
%     Batch Convert XRD (opens xrdConvertGUI)
%
% ── Programmatic API ──────────────────────────────────────────────────────
%
%   api = dataImportGUI() returns a struct of function handles for
%   automated testing and scripting.  All handles share the same closure
%   as the GUI, so they see live appData.
%
%   api.fig                    — figure handle
%   api.addFiles(fpaths)       — load a cell array of file paths
%   api.getDatasets()          — return cell array of dataset structs
%   api.getActiveIdx()         — active dataset index (0 when none loaded)
%   api.setActiveIdx(idx)      — switch active dataset (1-based)
%   api.setCorrections(xOff, yOff, bgSlope, bgInt)
%                              — write correction widget values
%   api.applyCorrections()     — run onApplyCorrections on active dataset
%   api.applyCorrectionsAll()  — apply same corrections to every dataset
%   api.undoCorrections()      — restore pre-correction state
%   api.autoPeaks()            — run auto peak detection
%   api.fitPeaks()             — fit detected peaks individually
%   api.getPeaks()             — return peaks struct from active dataset
%   api.setDatasetVisible(idx, vis) — toggle dataset visibility
%   api.saveSession(outPath)   — save session .mat (no dialog)
%   api.loadSession(matPath)   — restore session .mat (no dialog)
%   api.close()                — close figure
%   api.is2DActive()           — true when active dataset is a 2D area-detector map
%   api.setMap2DType(typeStr)  — set '2D plot type' and replot ('Heatmap'|'Contour'|...)
%   api.extractLineCut2D(x,y,isH) — extract 1D slice from 2D map (isH: H-cut vs V-cut)
%   api.setQSpace(tf)          — enable/disable Q-space axes on 2D map and replot
%   api.setContourLevels(n)    — set number of contour levels for Contour plot types
%   api.setColormap(name)      — set active colormap by name and replot
%
%   Headless usage (e.g. in test_gui_harness.m):
%     api = dataImportGUI();
%     api.fig.Visible = 'off';
%     api.addFiles({'/path/to/scan.xrdml'});
%     api.autoPeaks();
%     peaks = api.getPeaks();
%     api.close();
%
% ── Dataset Struct (appData.datasets{i}) ──────────────────────────────────
%
%   .data          — raw parsed data struct (from parser)
%   .corrData      — corrected data ([] until Apply Corrections is clicked)
%   .filepath      — full source file path
%   .parserName    — parser that produced .data
%   .displayName   — label shown in dataset list
%   .legendName    — user-editable legend name ('' = use displayName)
%   .xOff          — current X offset value
%   .yOff          — current Y offset value
%   .bgSlope       — background slope
%   .bgInt         — background intercept
%   .peaks         — struct array of detected/fitted peaks
%   .visible       — boolean; false = excluded from plot
%   .axLims        — per-dataset saved axis limits (restored on switch)
%   .annotations   — cell array of {x, y, text} annotation structs
%   .color         — [R G B] line color assigned from colormap
%
% ── Callback Flow (State Machine) ─────────────────────────────────────────
%
%   FILE LOADING
%   ────────────
%   onAddFiles / onDropFiles
%     └─► loadFilePaths(fpaths)
%           ├─ guiImport(fp)  [uses resolveParser → parser.*]
%           ├─ buildDs(fp, data, parserName)
%           ├─ appData.datasets{end+1} = ds
%           └─► rebuildDatasetList()
%                 └─► updateControlsForActiveDataset()
%                       └─► onPlot()
%                             └─► drawToAxes()
%
%   DATASET SELECTION
%   ─────────────────
%   lbDatasets.ValueChangedFcn → onSelectDataset()
%     ├─ saveAxisLimsToActiveDataset()   [persist zoom before leaving]
%     ├─ appData.activeIdx = new index
%     └─► updateControlsForActiveDataset()
%           ├─ populate efXOffset / efYOffset / …  from ds
%           ├─ set ddCorrStyle, ddNormalize, ddX, lbY, lbY2
%           ├─ applyParserAnalysisConfig(pName)
%           │     [shows/hides panels based on parser type]
%           └─► onPlot() → drawToAxes()
%
%   CORRECTIONS PIPELINE  (onApplyCorrections)
%   ──────────────────────────────────────────
%   Each step reads from ds.data (raw) or the previous step's output:
%
%     1. Trim (xTrimMin / xTrimMax)
%     2. X offset  (time = time − xOff)
%     3. Background subtraction  (file-based or slope+intercept)
%     4. Y offset  (values = values + yOff)
%     5. Normalization  (peak / area / z-score)
%     6. Smoothing  (moving average)
%     7. Spin asymmetry  (neutron NR only: (up−down)/(up+down))
%
%   Result stored in ds.corrData.  drawToAxes() plots corrData when
%   available, otherwise falls back to ds.data.
%
%   PEAK DETECTION / FITTING
%   ────────────────────────
%   onAutoPeak()
%     ├─ Uses utilities.findPeaksRobust (SNIP background + SNR filtering)
%     └─ Populates ds.peaks struct array
%
%   onFitPeaks()  — fits each peak independently
%   onFitAllPeaks() — fits all peaks simultaneously (sum-of-Lorentzians)
%     Both use fminsearch with Lorentzian or Gaussian model.
%     Results stored in ds.peaks(k).{center,fwhm,height,area,status}.
%
%   SESSION SAVE / LOAD
%   ────────────────────
%   onSaveSession() → saveSessionDirect(outPath)
%     saves: appData.datasets (full structs), GUI widget state
%
%   onLoadSession() → loadSessionDirect(matPath)
%     restores: datasets, corrections, peaks, axis limits, widget state
%
%   MOUSE / INTERACTION
%   ────────────────────
%   fig.WindowButtonDownFcn   = @onAxesButtonDown   (always active)
%   fig.WindowButtonMotionFcn = @onMouseHover        (always active)
%   Special modes (BG select, peak pick, annotation, pan-resize) override
%   these temporarily and restore them on completion.
%   Double-click detected via manual tic/toc (350 ms threshold).
%
%   RENDER CACHING
%   ───────────────
%   appData.lineCache stores line handles after each full drawToAxes() call.
%   Color/visibility changes call softUpdateLines() instead of full redraw,
%   updating handle properties directly for instant response with 50+ datasets.
%   Cache is invalidated when data, axis selection, or scale changes.
%
% ── Invariants ────────────────────────────────────────────────────────────
%
%   • appData.activeIdx == 0  iff  appData.datasets is empty.
%   • ds.corrData is []  until Apply Corrections is clicked; the plot
%     always prefers corrData over data when it is non-empty.
%   • The listbox lbDatasets.Items always mirrors appData.datasets (same
%     order, same count) — maintained by rebuildDatasetList().
%   • All widget writes to appData happen before any call to onPlot(),
%     so drawToAxes() always sees a consistent state.
%
% ── Requirements ──────────────────────────────────────────────────────────
%
%   MATLAB R2021b+ (arguments blocks, uifigure, uilistbox Multiselect)
%   No external toolboxes required.  Signal Processing Toolbox improves
%   peak detection (findpeaks) but falls back gracefully without it.
%
% ── See Also ──────────────────────────────────────────────────────────────
%
%   parser.importAuto, parser.resolveParser, +parser/README.md,
%   xrdConvertGUI, test_gui_harness

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
    appData.showSnipBg        = true;               % toggle SNIP background overlay on/off
    appData.fitCurveColor     = [0.85 0.20 0.00];   % default warm red-orange
    appData.kFactor           = 0.9;                % Scherrer shape factor K (0.9 spherical default)
    appData.instBroadening_deg = 0;                 % Instrument broadening FWHM (°); 0 = uncorrected
    appData.panelResizeDir    = '';   % '' | 'h_row12' | 'v_col12' | 'v_col23' | 'v_col34'
    appData.panelResizeStart  = [];   % [mousePixX, mousePixY] at resize drag start
    appData.panelResizeOrig   = [];   % panel dimension (px) at resize drag start
    appData.corrPanelWidth    = 350;  % user-resized corrections column width (px)
    appData.axLimPanelWidth   = 220;  % user-resized axes+appearance column width (px)
    appData.listDragSrcIdx    = 0;    % source row being dragged in lbDatasets (0 = none)
    appData.listDragActive    = false; % true once mouse has moved > threshold after listbox down
    appData.listDragStartPt   = [];   % [x y] fig-pixel position at listbox mouse-down
    appData.searchFilter      = '';   % dataset list search string (empty = show all)
    % ── Line caching for performance (soft-update path for color/visibility) ──
    appData.lineCache.valid   = false; % false = cache stale, use full redraw
    appData.lineCache.left    = {};    % {nDS × nY} line handles (left axis)
    appData.lineCache.right   = {};    % {nDS × nY2} line handles (right axis)

    % ── Figure ───────────────────────────────────────────────────────────
    fig = uifigure('Name','Data Import & Preview', ...
                   'Position',[80 60 1080 1000], ...
                   'AutoResizeChildren','off');
    MIN_FIG_H = 820;   % minimum height so the analysis panel is never clipped
    LAYOUT_DEFAULTS = struct('figW',1080,'figH',1000,'ctrlPanelW',215, ...
        'corrPanelW',350,'axLimPanelW',220,'fileListW',200);
    PREFS_FILE   = fullfile(fileparts(mfilename('fullpath')),'layoutPrefs.mat');
    BUG_LOG_FILE = fullfile(fileparts(mfilename('fullpath')),'gui_bug_log.txt');
    fig.SizeChangedFcn = @onFigSizeChanged;
    fig.CloseRequestFcn = @onFigureClose;
    try
        fig.DropFcn = @onDropFiles;   % drag-and-drop from Explorer (R2023a+)
    catch
        % DropFcn is not available on this MATLAB version — silently skip
    end

    % Delete key support for removing datasets
    fig.KeyPressFcn = @onFigureKeyPress;

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

    % Root grid  (2 rows × 1 col: content row 1, analysis row 2)
    % Row 1 holds file-list | controls | preview side-by-side (contentGL).
    % Row 2 (analysis) is resizable via the h_row12 drag border.
    rootGL = uigridlayout(fig,[2 1], ...
        'RowHeight',    {'1x','1x'}, ...
        'ColumnWidth',  {'1x'}, ...
        'Padding',      [8 8 8 8], ...
        'RowSpacing',   6, ...
        'ColumnSpacing', 0);

    % ── Content row: [Files | Controls | Preview] ─────────────────────────
    % File-list column is narrow; controls column fixed; preview fills remainder.
    contentGL = uigridlayout(rootGL,[1 3], ...
        'ColumnWidth',  {200, 215, '1x'}, ...
        'Padding',      [0 0 0 0], ...
        'ColumnSpacing', 8);
    contentGL.Layout.Row = 1; contentGL.Layout.Column = 1;

    % ── File list panel (contentGL col 1) ─────────────────────────────────
    % Stacked vertically: Add | Remove | Filter | Merge | Listbox
    tbGL = uigridlayout(contentGL,[8 2], ...
        'RowHeight',    {26,26,26,26,26,26,26,'1x'}, ...
        'ColumnWidth',  {'1x','1x'}, ...
        'Padding',      [0 0 0 0], ...
        'RowSpacing',   4, ...
        'ColumnSpacing', 4);
    tbGL.Layout.Row = 1; tbGL.Layout.Column = 1;

    btnBrowse = uibutton(tbGL,'Text','Add File(s)...', ...
        'ButtonPushedFcn',@onAddFiles, ...
        'BackgroundColor',[0.18 0.52 0.18], ...
        'FontColor',[1 1 1],'FontWeight','bold', ...
        'Tooltip','Browse for one or more data files — each is added as a new dataset');
    btnBrowse.Layout.Row = 1; btnBrowse.Layout.Column = [1 2];

    btnRemoveDS = uibutton(tbGL,'Text','Remove Selected', ...
        'ButtonPushedFcn',@onRemoveDataset, ...
        'BackgroundColor',[0.70 0.18 0.18], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Remove the highlighted dataset from the list (also: right-click or press Delete)');
    btnRemoveDS.Layout.Row = 2; btnRemoveDS.Layout.Column = [1 2];

    efDatasetSearch = uieditfield(tbGL,'text','Value','', ...
        'Placeholder','Filter datasets...', ...
        'Tooltip','Filter the dataset list by name (case-insensitive substring match)', ...
        'ValueChangedFcn',@onSearchChanged);
    efDatasetSearch.Layout.Row = 3; efDatasetSearch.Layout.Column = [1 2];

    btnMerge = uibutton(tbGL,'Text','Merge Selected', ...
        'ButtonPushedFcn',@onMergeDatasets, ...
        'BackgroundColor',[0.25 0.45 0.65], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Concatenate 2+ selected datasets into a new merged dataset (sorted by X)');
    btnMerge.Layout.Row = 4; btnMerge.Layout.Column = 1;

    btnDatasetMath = uibutton(tbGL,'Text','Dataset Math...', ...
        'ButtonPushedFcn',@onDatasetMath, ...
        'BackgroundColor',[0.45 0.30 0.60], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Create derived datasets via expressions: D1/D2, log10(D1), diff(D1), D1-D2, D1*D2');
    btnDatasetMath.Layout.Row = 4; btnDatasetMath.Layout.Column = 2;

    btnMoveUp = uibutton(tbGL,'Text',[char(9650) ' Up'], ...
        'ButtonPushedFcn',@onMoveDatasetUp, ...
        'Tooltip','Move the active dataset up in the list (Ctrl+Up)');
    btnMoveUp.Layout.Row = 5; btnMoveUp.Layout.Column = 1;

    btnMoveDown = uibutton(tbGL,'Text',[char(9660) ' Down'], ...
        'ButtonPushedFcn',@onMoveDatasetDown, ...
        'Tooltip','Move the active dataset down in the list (Ctrl+Down)');
    btnMoveDown.Layout.Row = 5; btnMoveDown.Layout.Column = 2;

    btnAnimate = uibutton(tbGL,'Text',[char(9654) ' Animate'], ...
        'ButtonPushedFcn',@onToggleAnimation, ...
        'BackgroundColor',[0.50 0.35 0.15], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Cycle through datasets as animation frames (2 fps). Click again to stop.');
    btnAnimate.Layout.Row = 6; btnAnimate.Layout.Column = [1 2];

    lbDatasets = uilistbox(tbGL, ...
        'Items',     {'(no files loaded — click  Add File(s)...  to begin)'}, ...
        'ItemsData', {0}, ...
        'Multiselect','on', ...
        'ValueChangedFcn',@onSelectDataset, ...
        'Tooltip','Loaded datasets — click to make active; Ctrl+click to select multiple; right-click to remove');
    lbDatasets.Layout.Row = 8; lbDatasets.Layout.Column = [1 2];

    % Context menu for dataset list (right-click)
    cmDatasets = uicontextmenu(fig);
    miRemove = uimenu(cmDatasets, 'Text', 'Remove Selected', ...
        'MenuSelectedFcn', @(~,~) onRemoveDataset([], [])); %#ok<NASGU>
    lbDatasets.ContextMenu = cmDatasets;

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
    %   8 -  30px  Refresh button
    %   9 -   1x   Metadata text area
    ctrlPanel = uipanel(contentGL,'Title','Controls','FontSize',13);
    ctrlPanel.Layout.Column = 2;

    ctrlGL = uigridlayout(ctrlPanel,[10 1], ...
        'RowHeight', {26,2,'1x',2,'1x',2,70,24,26,24}, ...
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

    % Row 5: Right Y-axis channel selector
    y2GL = uigridlayout(ctrlGL,[2 1], ...
        'Padding',[0 0 0 0],'RowSpacing',2,'ColumnSpacing',4, ...
        'RowHeight',{20,'1x'},'ColumnWidth',{'1x'});
    y2GL.Layout.Row = 5;

    lblY2 = uilabel(y2GL,'Text','Right Y-axis:', ...
        'FontSize',12,'FontColor',[0.75 0.75 0.75]);
    lblY2.Layout.Row = 1; lblY2.Layout.Column = 1;

    lbY2 = uilistbox(y2GL,'Items',{'(none)'},'Multiselect','on', ...
        'Value',{'(none)'}, ...
        'Tooltip','Right Y-axis channel(s) — plotted against the right-hand scale', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    lbY2.Layout.Row = 2; lbY2.Layout.Column = 1;

    % Plot-style buttons (row 7) — three uibutton objects in a nested grid.
    styleGL = uigridlayout(ctrlGL,[3 3], ...
        'Padding',[0 0 0 0],'ColumnSpacing',2,'RowSpacing',2, ...
        'ColumnWidth',{'1x','1x','1x'},'RowHeight',{20,20,'1x'});
    styleGL.Layout.Row = 7;

    % Row 1: Colormap label + selector
    lblColormap = uilabel(styleGL,'Text','Colormap:','FontSize',10);
    lblColormap.Layout.Row = 1; lblColormap.Layout.Column = 1;

    COLORMAPS = {'lines (MATLAB default)', 'jet', 'turbo', 'hot', 'cool', ...
                 'spring', 'summer', 'autumn', 'winter', 'gray', 'copper', ...
                 'pink', 'bone', 'hsv', 'parula', 'viridis', 'plasma', 'inferno'};
    ddColormap = uidropdown(styleGL, 'Items', COLORMAPS, 'Value', COLORMAPS{1}, ...
        'Tooltip', 'Color palette for multi-dataset plots', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddColormap.Layout.Row = 1; ddColormap.Layout.Column = [2 3];

    % Row 2: Theme selector
    lblTheme = uilabel(styleGL,'Text','Theme:','FontSize',10); %#ok<NASGU>
    lblTheme.Layout.Row = 2; lblTheme.Layout.Column = 1;

    ddTheme = uidropdown(styleGL, ...
        'Items',   {'Light', 'Dark'}, ...
        'Value',   'Light', ...
        'Tooltip', 'Switch between light and dark GUI themes', ...
        'ValueChangedFcn', @onThemeChanged);
    ddTheme.Layout.Row = 2; ddTheme.Layout.Column = [2 3];

    % Row 3: Style buttons
    btnStyleLine = uibutton(styleGL,'Text','Line', ...
        'ButtonPushedFcn',@(~,~) onStylePick('Line'), ...
        'BackgroundColor',[0.20 0.50 0.20],'FontColor',[1 1 1]);
    btnStyleLine.Layout.Row = 3; btnStyleLine.Layout.Column = 1;

    btnStyleScatter = uibutton(styleGL,'Text','Scatter', ...
        'ButtonPushedFcn',@(~,~) onStylePick('Scatter'));
    btnStyleScatter.Layout.Row = 3; btnStyleScatter.Layout.Column = 2;

    btnStyleLineMarkers = uibutton(styleGL,'Text','Line+Pts', ...
        'ButtonPushedFcn',@(~,~) onStylePick('Line+Pts'));
    btnStyleLineMarkers.Layout.Row = 3; btnStyleLineMarkers.Layout.Column = 3;

    % Row 8: All log-scale checkboxes + Cts/s in one row
    logChkGL = uigridlayout(ctrlGL,[1 4], ...
        'Padding',[0 0 0 0],'ColumnWidth',{'1x','1x','1x','1x'},'ColumnSpacing',2);
    logChkGL.Layout.Row = 8;
    cbLogX = uicheckbox(logChkGL,'Text','Log X','ValueChangedFcn',@onAxisChanged);
    cbLogX.Layout.Column = 1;
    cbLogY = uicheckbox(logChkGL,'Text','Log Y','ValueChangedFcn',@onAxisChanged);
    cbLogY.Layout.Column = 2;
    cbLogY2 = uicheckbox(logChkGL,'Text','Log R', ...
        'Value',false, ...
        'Tooltip','Use log scale for the right Y-axis', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    cbLogY2.Layout.Column = 3;
    cbCountsPerSec = uicheckbox(logChkGL,'Text','Cts/s', ...
        'Value', false, 'Enable', 'off', ...
        'Tooltip', 'Divide intensity by counting time (counts → counts/s). XRD files only.', ...
        'ValueChangedFcn', @onAxisChanged);
    cbCountsPerSec.Layout.Column = 4;

    % Row 9: Waterfall toggle + spacing + Replot button
    wfGL = uigridlayout(ctrlGL,[1 3], ...
        'Padding',[0 0 0 0],'ColumnSpacing',4,'ColumnWidth',{'1x',50,55});
    wfGL.Layout.Row = 9;

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

    btnPlot = uibutton(wfGL,'Text','Refresh','ButtonPushedFcn',@onPlot, ...
    'Tooltip','Force a full redraw of the current plot');
    btnPlot.Layout.Column = 3;

    % Row 10: Annotation mode toggle
    cbAnnotationMode = uicheckbox(ctrlGL, ...
        'Text',    'Annotation Mode', ...
        'Value',   false, ...
        'Tooltip', 'Click on the plot to add text annotations. Right-click to delete.', ...
        'ValueChangedFcn', @onAnnotationModeChanged);
    cbAnnotationMode.Layout.Row = 10;

    % ── Right: preview axes ───────────────────────────────────────────────
    axPanel = uipanel(contentGL,'Title','Preview','FontSize',13);
    axPanel.Layout.Column = 3;
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
    analysisPanel.Layout.Row = 2; analysisPanel.Layout.Column = 1;

    analysisGL = uigridlayout(analysisPanel,[1 4], ...
        'ColumnWidth', {350, 220, '7x', '3x'}, ...
        'RowHeight',   {'1x'}, ...
        'Padding',     [6 6 6 6], ...
        'ColumnSpacing', 10, ...
        'RowSpacing', 6);

    % ── Corrections sub-panel (analysisGL col 1) ─────────────────────────
    % 10-row × 4-col grid:
    %   row  1  : correction style selector
    %   rows 2-3: [X Offset | BG Slope] / [Y Offset | BG Intercept]
    %   row  4  : smoothing controls
    %   row  5  : Fit BG / Est. Y Offset (generic) | XRD interactive tools
    %   row  6  : Remove Peak button (XRD only)
    %   row  7  : background file selector (Load BG)
    %   row  8  : Subtract BG checkbox + Clear BG button
    %   row  9  : Apply Corrections | Reset | Show Raw checkbox
    %   row 10  : Undo button (one-level undo for corrections)
    corrPanel = uipanel(analysisGL,'Title','Corrections','FontSize',13);
    corrPanel.Layout.Row = 1; corrPanel.Layout.Column = 1;

    corrGL = uigridlayout(corrPanel,[16 4], ...
        'RowHeight',    {24,24,24,24,24,24,24,24,28,28,24,20,24,24,0,0}, ...
        'ColumnWidth',  {70,'1x',88,'1x'}, ...
        'Padding',      [6 6 6 6], ...
        'RowSpacing',   4, ...
        'ColumnSpacing', 4);

    % Row 1: Correction style selector
    lblCorrStyle = uibutton(corrGL,'Text','Style:','Enable','off','FontSize',10);
    lblCorrStyle.Layout.Row = 1; lblCorrStyle.Layout.Column = 1;

    ddCorrStyle = uidropdown(corrGL, ...
        'Items',           {'Auto (from file)', 'Generic', 'Magnetometry', 'PPMS', 'XRD — 2\theta + BG', 'Neutron NR'}, ...
        'Value',           'Auto (from file)', ...
        'Tooltip',         ['Controls which correction tools and analysis features are shown. '...
            '"Auto" detects from the file type. "XRD" enables peak detection. '...
            '"Neutron NR" enables spin asymmetry. "Generic" shows all controls.'], ...
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
    btnFitBG = uibutton(corrGL,'Text','Fit BG from Box', ...
        'ButtonPushedFcn',@onFitBGRegion, ...
        'BackgroundColor',[0.50 0.28 0.05], ...
        'FontColor',[1 1 1], ...
        'Tooltip', ['Draw a rectangle on the preview axes.  ' ...
                    'All selected-Y data points inside the box are fitted with ' ...
                    'a polynomial of the order chosen in "BG Order" (Linear = 1st-order).  ' ...
                    'For Linear: BG Slope and Intercept are auto-populated.  ' ...
                    'For higher orders: polynomial is stored per-dataset and applied on corrections.']);
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
        'Tooltip','Detect peaks automatically using SNIP background estimation and SNR-based filtering', ...
        'Visible','off');
    btnAutoPeak.Layout.Row = 5; btnAutoPeak.Layout.Column = 3;

    btnManualPeak = uibutton(corrGL,'Text','Add Peak', ...
        'ButtonPushedFcn',@onManualPeakAdd, ...
        'BackgroundColor',[0.45 0.20 0.55],'FontColor',[1 1 1], ...
        'Tooltip','Click once on a peak in the plot to add it to the peak list (click button again to finish)', ...
        'Visible','off');
    btnManualPeak.Layout.Row = 5; btnManualPeak.Layout.Column = 4;

    % Row 6: BG polynomial order selector (cols 1-3) + Remove Peak for XRD (col 4)
    lblBGOrder = uibutton(corrGL,'Text','BG Order:','Enable','off','FontSize',10);
    lblBGOrder.Layout.Row = 6; lblBGOrder.Layout.Column = 1;

    ddBGOrder = uidropdown(corrGL, ...
        'Items',   {'Linear', 'Poly 2', 'Poly 3', 'Poly 4', 'Poly 5', 'Poly 6'}, ...
        'Value',   'Linear', ...
        'Tooltip', 'Polynomial order used by "Fit BG from Box": Linear=1st-order, Poly N=Nth-order');
    ddBGOrder.Layout.Row = 6; ddBGOrder.Layout.Column = [2 3];

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
    efBGFile.Layout.Row = 7; efBGFile.Layout.Column = 2;

    btnLoadBG = uibutton(corrGL,'Text','Load BG...', ...
        'ButtonPushedFcn',@onLoadBackground, ...
        'Tooltip','Load a background file (any supported format) to subtract from corrected data');
    btnLoadBG.Layout.Row = 7; btnLoadBG.Layout.Column = 3;

    btnSetActiveBG = uibutton(corrGL,'Text','Use Active', ...
        'ButtonPushedFcn',@onSetActiveBG, ...
        'Tooltip','Use the active dataset as the background (no file dialog needed)', ...
        'FontSize',9);
    btnSetActiveBG.Layout.Row = 7; btnSetActiveBG.Layout.Column = 4;

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

    % Row 10: Apply to All | Undo
    btnApplyAll = uibutton(corrGL,'Text','Apply to All', ...
        'ButtonPushedFcn',@onApplyCorrectionsAll, ...
        'Tooltip','Copy current corrections to all loaded datasets', ...
        'FontColor',[0.4 0.4 0.4],'FontSize',9);
    btnApplyAll.Layout.Row = 10; btnApplyAll.Layout.Column = [1 2];

    btnUndo = uibutton(corrGL,'Text','Undo', ...
        'ButtonPushedFcn',@onUndoCorrections, ...
        'Tooltip','Restore previous correction state (one-level undo)', ...
        'FontColor',[0.6 0.6 0.6]);
    btnUndo.Layout.Row = 10; btnUndo.Layout.Column = 3;

    % Row 11: Visibility toggle
    btnToggleVis = uibutton(corrGL,'Text','Hide Dataset', ...
        'ButtonPushedFcn',@onToggleDatasetVisibility, ...
        'Tooltip','Hide/show the active dataset in the plot without removing it', ...
        'FontColor',[0.5 0.5 0.5]);
    btnToggleVis.Layout.Row = 11; btnToggleVis.Layout.Column = [1 2];

    % Row 12: Region statistics readout (populated when BG box is drawn)
    lblRegionStats = uibutton(corrGL,'Text','', 'Enable','off', 'FontSize',9, ...
        'FontColor',[0.3 0.3 0.6]);
    lblRegionStats.Layout.Row = 12; lblRegionStats.Layout.Column = [1 4];

    % Row 13: Normalization control
    lblNormalize = uibutton(corrGL,'Text','Normalize:','Enable','off');
    lblNormalize.Layout.Row = 13; lblNormalize.Layout.Column = 1;

    ddNormalize = uidropdown(corrGL, ...
        'Items',   {'None', 'Range [0,1]', 'Peak (max=1)', 'Z-score', 'Area (integral=1)'}, ...
        'Value',   'None', ...
        'Tooltip', 'Normalize corrected data: Range = [0,1], Peak = max height = 1, Z-score = (x-mean)/std, Area = integrate to 1');
    ddNormalize.Layout.Row = 13; ddNormalize.Layout.Column = [2 4];

    % Row 14: Data trim / crop
    lblXTrim = uibutton(corrGL,'Text','Trim X:','Enable','off');
    lblXTrim.Layout.Row = 14; lblXTrim.Layout.Column = 1;

    efXTrimMin = uieditfield(corrGL,'text','Value','', ...
        'Tooltip','Trim x-range: keep only data from this minimum x-value (blank = no limit)');
    efXTrimMin.Layout.Row = 14; efXTrimMin.Layout.Column = 2;

    efXTrimMax = uieditfield(corrGL,'text','Value','', ...
        'Tooltip','Trim x-range: keep only data up to this maximum x-value (blank = no limit)');
    efXTrimMax.Layout.Row = 14; efXTrimMax.Layout.Column = [3 4];

    % Row 15: Neutron spin asymmetry calculation (neutron data only)
    lblAsymmetry = uibutton(corrGL,'Text','Spin Asymmetry:','Enable','off');
    lblAsymmetry.Layout.Row = 15; lblAsymmetry.Layout.Column = 1;

    cbCalculateAsymmetry = uicheckbox(corrGL,'Text','Calculate & Plot', ...
        'Value',false, ...
        'Tooltip','Calculate spin asymmetry (R++ − R--) / (R++ + R--) and plot as new channel', ...
        'ValueChangedFcn',@onAsymmetryToggle);
    cbCalculateAsymmetry.Layout.Row = 15; cbCalculateAsymmetry.Layout.Column = [2 4];

    % Row 16: Asymmetry formula selector (hidden by default)
    lblAsymFormula = uibutton(corrGL,'Text','Formula:','Enable','off');
    lblAsymFormula.Layout.Row = 16; lblAsymFormula.Layout.Column = 1;

    ddAsymFormula = uidropdown(corrGL, ...
        'Items',   {'Linear: (R++ − R--) / (R++ + R--)', 'Log: log(R++ / R--)'}, ...
        'Value',   'Linear: (R++ − R--) / (R++ + R--)', ...
        'Tooltip', 'Asymmetry formula: Linear uses reflectivity ratio, Log uses reflectivity ratio logarithm');
    ddAsymFormula.Layout.Row = 16; ddAsymFormula.Layout.Column = [2 4];

    % ── Axes & Appearance sub-panel (middle column) ──────────────────────
    % Combined panel: rows 1-5 axis limits, rows 6-11 appearance controls.
    % All limit fields are text-type: blank = auto-scale, any number = manual.
    % str2double('') == NaN, so blank naturally means "do not apply".
    axLimPanel = uipanel(analysisGL,'Title','Axes & Appearance','FontSize',13);
    axLimPanel.Layout.Row = 1; axLimPanel.Layout.Column = 2;

    axLimGL = uigridlayout(axLimPanel,[11 4], ...
        'RowHeight',    {22,26,26,0,28, 22,22,22,22,22,22}, ...
        'ColumnWidth',  {40,'1x','1x','1x'}, ...
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
    AXLIM_PH = [0.70 0.70 0.70];   % placeholder "auto" text -- improved contrast on dark bg

    efXMin = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','X axis minimum — blank = auto-scale', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'PlaceholderFontColor', AXLIM_PH, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXMin.Layout.Row = 2; efXMin.Layout.Column = 2;

    efXMax = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','X axis maximum — blank = auto-scale', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'PlaceholderFontColor', AXLIM_PH, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXMax.Layout.Row = 2; efXMax.Layout.Column = 3;

    efXStep = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','X axis major tick spacing — blank = auto ticks', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'PlaceholderFontColor', AXLIM_PH, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXStep.Layout.Row = 2; efXStep.Layout.Column = 4;

    % Row 3: Y axis
    lblYLim = uibutton(axLimGL,'Text','Y:','Enable','off');
    lblYLim.Layout.Row = 3; lblYLim.Layout.Column = 1;

    efYMin = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Y axis minimum — blank = auto-scale', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'PlaceholderFontColor', AXLIM_PH, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYMin.Layout.Row = 3; efYMin.Layout.Column = 2;

    efYMax = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Y axis maximum — blank = auto-scale', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'PlaceholderFontColor', AXLIM_PH, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYMax.Layout.Row = 3; efYMax.Layout.Column = 3;

    efYStep = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Y axis major tick spacing — blank = auto ticks', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'PlaceholderFontColor', AXLIM_PH, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYStep.Layout.Row = 3; efYStep.Layout.Column = 4;

    % Row 4: right Y-axis limits — hidden (RowHeight=0) until Y2 channel is selected
    lblY2Lim = uibutton(axLimGL,'Text','Y2:','Enable','off');
    lblY2Lim.Layout.Row = 4; lblY2Lim.Layout.Column = 1;

    efY2Min = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Right Y-axis minimum — blank = auto-scale', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'PlaceholderFontColor', AXLIM_PH, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efY2Min.Layout.Row = 4; efY2Min.Layout.Column = 2;

    efY2Max = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Right Y-axis maximum — blank = auto-scale', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'PlaceholderFontColor', AXLIM_PH, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efY2Max.Layout.Row = 4; efY2Max.Layout.Column = 3;

    efY2Step = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','auto', ...
        'Tooltip','Right Y-axis major tick spacing — blank = auto ticks', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'PlaceholderFontColor', AXLIM_PH, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efY2Step.Layout.Row = 4; efY2Step.Layout.Column = 4;

    % Row 5: Auto Scale (smart) + Clear All (reset)
    btnSmartScale = uibutton(axLimGL,'Text','Auto Scale', ...
        'ButtonPushedFcn',@onSmartScale, ...
        'Tooltip','Auto-detect linear/log scale and set reasonable axis limits from the data');
    btnSmartScale.Layout.Row = 5; btnSmartScale.Layout.Column = [1 2];

    btnAutoLimits = uibutton(axLimGL,'Text','Clear All', ...
        'ButtonPushedFcn',@onAutoLimits, ...
        'Tooltip','Clear all manual axis limits and reset to auto-scale');
    btnAutoLimits.Layout.Row = 5; btnAutoLimits.Layout.Column = [3 4];

    % ── Appearance controls (rows 6-11) ────────────────────────────────
    % Row 6: Color (L spans 2-3 normally; R in col 4 when Y2 active)
    lblApColor = uibutton(axLimGL,'Text','Color:','Enable','off','FontSize',10);
    lblApColor.Layout.Row = 6; lblApColor.Layout.Column = 1;

    ddDatasetColor = uidropdown(axLimGL, ...
        'Items',     DS_COLOR_NAMES, ...
        'ItemsData', DS_COLOR_RGBS, ...
        'Value',     [], ...
        'Enable',    'off', ...
        'Tooltip',   'Override line colour for left-axis channels ("Auto" uses the palette)', ...
        'ValueChangedFcn', @onDatasetColorChanged);
    ddDatasetColor.Layout.Row = 6; ddDatasetColor.Layout.Column = [2 4];

    ddDatasetColorR = uidropdown(axLimGL, ...
        'Items',     DS_COLOR_NAMES, ...
        'ItemsData', DS_COLOR_RGBS, ...
        'Value',     [], ...
        'Enable',    'off', ...
        'Visible',   'off', ...
        'Tooltip',   'Override line colour for right-axis channels ("Auto" uses the palette)', ...
        'ValueChangedFcn', @onDatasetColorRChanged);
    ddDatasetColorR.Layout.Row = 6; ddDatasetColorR.Layout.Column = 4;

    % Row 7: Legend name
    lblApLegend = uibutton(axLimGL,'Text','Legend:','Enable','off','FontSize',10);
    lblApLegend.Layout.Row = 7; lblApLegend.Layout.Column = 1;

    efLegendName = uieditfield(axLimGL,'text','Value','', ...
        'Enable',          'off', ...
        'Placeholder',     'auto (channel name)', ...
        'Tooltip',         'Override the legend label for left-axis channels — blank = auto', ...
        'ValueChangedFcn', @onLegendNameChanged);
    efLegendName.Layout.Row = 7; efLegendName.Layout.Column = [2 4];

    efLegendNameR = uieditfield(axLimGL,'text','Value','', ...
        'Enable',          'off', ...
        'Visible',         'off', ...
        'Placeholder',     'auto', ...
        'Tooltip',         'Override the legend label for right-axis channels — blank = auto', ...
        'ValueChangedFcn', @onLegendNameRChanged);
    efLegendNameR.Layout.Row = 7; efLegendNameR.Layout.Column = 4;

    % Row 8: X label (spans all value columns — only one X axis)
    lblApXLabel = uibutton(axLimGL,'Text','X Label:','Enable','off','FontSize',10);
    lblApXLabel.Layout.Row = 8; lblApXLabel.Layout.Column = 1;

    efCustomXLabel = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder',     'auto (from data)', ...
        'Tooltip',         'Override the X-axis label — blank = auto', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomXLabel.Layout.Row = 8; efCustomXLabel.Layout.Column = [2 4];

    % Row 9: Y label (left and right independently)
    lblApYLabel = uibutton(axLimGL,'Text','Y Label:','Enable','off','FontSize',10);
    lblApYLabel.Layout.Row = 9; lblApYLabel.Layout.Column = 1;

    efCustomYLabel = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder',     'auto (from data)', ...
        'Tooltip',         'Override the left Y-axis label — blank = auto', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomYLabel.Layout.Row = 9; efCustomYLabel.Layout.Column = [2 4];

    efCustomY2Label = uieditfield(axLimGL,'text','Value','', ...
        'Visible',         'off', ...
        'Placeholder',     'auto', ...
        'Tooltip',         'Override the right Y-axis label — blank = auto', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomY2Label.Layout.Row = 9; efCustomY2Label.Layout.Column = 4;

    % Row 10: Title (spans all value columns)
    lblApTitle = uibutton(axLimGL,'Text','Title:','Enable','off','FontSize',10);
    lblApTitle.Layout.Row = 10; lblApTitle.Layout.Column = 1;

    efCustomTitle = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder',     'auto (from filename)', ...
        'Tooltip',         'Override the plot title — blank = auto', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomTitle.Layout.Row = 10; efCustomTitle.Layout.Column = [2 4];

    % Row 11: Tick-label notation — X and Y1 always visible; R (Y2) hidden until active.
    % A nested 1×6 grid packs [X: dd | Y: dd | R: dd] into the three value columns.
    % Cols 5-6 (the R label + dropdown) start at width 0 and are revealed with Y2.
    lblApFmt = uibutton(axLimGL,'Text','Format:','Enable','off','FontSize',10);
    lblApFmt.Layout.Row = 11; lblApFmt.Layout.Column = 1;

    fmtGL = uigridlayout(axLimGL, [1 6], ...
        'Padding', [0 0 0 0], 'RowSpacing', 0, 'ColumnSpacing', 2, ...
        'ColumnWidth', {16, '1x', 16, '1x', 0, 0});
    fmtGL.Layout.Row = 11; fmtGL.Layout.Column = [2 4];

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

    % ── Save / Export sub-panel (right column) ─────────────────────────────
    savePanel = uipanel(analysisGL,'Title','Save / Export','FontSize',13);
    savePanel.Layout.Row = 1; savePanel.Layout.Column = 4;

    saveGL = uigridlayout(savePanel,[14 2], ...
        'RowHeight',    {26,28,32,32,32,32,32,32,32,32,32,32,32,28}, ...
        'ColumnWidth',  {'1x','1x'}, ...
        'Padding',      [6 6 6 6], ...
        'RowSpacing',   4, ...
        'ColumnSpacing', 4);

    efSavePath = uieditfield(saveGL,'Value','', ...
        'Placeholder','(auto-set on dataset load or Apply)', ...
        'Tooltip','Output CSV file path — auto-filled on load/Apply, or browse to choose');
    efSavePath.Layout.Row = 1; efSavePath.Layout.Column = [1 2];

    % Row 2: CSV format selector
    ddExportFormat = uidropdown(saveGL, ...
        'Items',   {'Standard CSV', 'Origin ASCII'}, ...
        'Value',   'Standard CSV', ...
        'Tooltip', 'CSV format: Standard (single header) or Origin (Long Name / Units / Designation rows)');
    ddExportFormat.Layout.Row = 2; ddExportFormat.Layout.Column = [1 2];

    btnSaveBrowse = uibutton(saveGL,'Text','Browse...', ...
        'ButtonPushedFcn',@onSaveBrowse, ...
        'Tooltip','Choose output file location');
    btnSaveBrowse.Layout.Row = 3; btnSaveBrowse.Layout.Column = 1;

    btnSave = uibutton(saveGL,'Text','Save CSV', ...
        'ButtonPushedFcn',@onSaveCSV, ...
        'BackgroundColor',[0.15 0.37 0.63], ...
        'FontColor',[1 1 1],'FontWeight','bold', ...
        'Tooltip','Write data to CSV (raw or corrected; consolidated for neutron data)');
    btnSave.Layout.Row = 3; btnSave.Layout.Column = 2;

    btnExportHDF5 = uibutton(saveGL,'Text','Export HDF5...', ...
        'ButtonPushedFcn',@onExportHDF5, ...
        'BackgroundColor',[0.10 0.45 0.45], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Export data, corrections, and peaks to a self-describing HDF5 file (.h5)');
    btnExportHDF5.Layout.Row = 4; btnExportHDF5.Layout.Column = [1 2];

    btnExportFig = uibutton(saveGL,'Text','Export to Figure', ...
        'ButtonPushedFcn',@onExportFigure, ...
        'BackgroundColor',[0.30 0.30 0.60], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Open a new figure window with the current plot (full MATLAB toolbar — ideal for publication-quality editing)');
    btnExportFig.Layout.Row = 5; btnExportFig.Layout.Column = [1 2];

    btnCopyClip = uibutton(saveGL,'Text','Copy Plot to Clipboard', ...
        'ButtonPushedFcn',@onCopyToClipboard, ...
        'BackgroundColor',[0.22 0.22 0.22], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Copy the current plot as an image to the system clipboard (Windows only)');
    btnCopyClip.Layout.Row = 6; btnCopyClip.Layout.Column = [1 2];

    btnBatchExport = uibutton(saveGL,'Text','Batch Export All CSV', ...
        'ButtonPushedFcn',@onBatchExportCSV, ...
        'BackgroundColor',[0.50 0.40 0.10], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Export all loaded datasets to separate CSV files (one per dataset)');
    btnBatchExport.Layout.Row = 7; btnBatchExport.Layout.Column = [1 2];

    % Row 8: Publication figure save — format selector + save button
    ddFigFormat = uidropdown(saveGL, ...
        'Items',   {'PNG (300 dpi)', 'PDF (vector)', 'SVG (vector)', 'TIFF (300 dpi)'}, ...
        'Value',   'PNG (300 dpi)', ...
        'Tooltip', 'Output file format for publication-quality figure save');
    ddFigFormat.Layout.Row = 8; ddFigFormat.Layout.Column = 1;

    btnSaveFig = uibutton(saveGL,'Text','Save Figure', ...
        'ButtonPushedFcn',@onSaveFigure, ...
        'BackgroundColor',[0.55 0.20 0.55], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Save the current plot to an image or vector file via exportgraphics');
    btnSaveFig.Layout.Row = 8; btnSaveFig.Layout.Column = 2;

    % Row 9: Session save / load
    btnSaveSession = uibutton(saveGL,'Text','Save Session...', ...
        'ButtonPushedFcn',@onSaveSession, ...
        'BackgroundColor',[0.25 0.35 0.45], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Save all loaded datasets, corrections, and peaks to a .mat session file');
    btnSaveSession.Layout.Row = 9; btnSaveSession.Layout.Column = 1;

    btnLoadSession = uibutton(saveGL,'Text','Load Session...', ...
        'ButtonPushedFcn',@onLoadSession, ...
        'BackgroundColor',[0.25 0.35 0.45], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Restore a previously saved session from a .mat file');
    btnLoadSession.Layout.Row = 9; btnLoadSession.Layout.Column = 2;

    % Row 10: Copy data to clipboard (tab-delimited with Origin headers)
    btnCopyDataClip = uibutton(saveGL,'Text','Copy Data to Clipboard', ...
        'ButtonPushedFcn', @onCopyDataToClipboard, ...
        'BackgroundColor', [0.35 0.50 0.35], ...
        'FontColor', [1 1 1], ...
        'Tooltip', 'Copy selected datasets as tab-delimited text to clipboard (Origin-ready)');
    btnCopyDataClip.Layout.Row = 10; btnCopyDataClip.Layout.Column = [1 2];

    % Row 11: Send to Origin via COM (falls back to clipboard)
    btnSendOrigin = uibutton(saveGL,'Text','Send to Origin', ...
        'ButtonPushedFcn', @onSendToOrigin, ...
        'BackgroundColor', [0.60 0.30 0.15], ...
        'FontColor', [1 1 1], ...
        'Tooltip', 'Send data to OriginPro via COM automation (falls back to clipboard copy)');
    btnSendOrigin.Layout.Row = 11; btnSendOrigin.Layout.Column = [1 2];

    % Row 12: Batch Convert XRD
    btnBatchConvertXRD = uibutton(saveGL,'Text','Batch Convert XRD', ...
        'ButtonPushedFcn', @onBatchConvertXRD, ...
        'BackgroundColor', [0.45 0.45 0.20], ...
        'FontColor', [1 1 1], ...
        'Tooltip', 'Open batch XRD file converter (XRDML, Rigaku, Bruker)');
    btnBatchConvertXRD.Layout.Row = 12; btnBatchConvertXRD.Layout.Column = [1 2];

    % Row 13: Export Origin Script
    btnExportOriginScript = uibutton(saveGL,'Text','Export Origin Script', ...
        'ButtonPushedFcn', @onExportOriginScript, ...
        'BackgroundColor', [0.55 0.35 0.10], ...
        'FontColor', [1 1 1], ...
        'Tooltip', 'Write a LabTalk (.ogs) script + CSV that Origin can import directly');
    btnExportOriginScript.Layout.Row = 13; btnExportOriginScript.Layout.Column = [1 2];

    % Row 14: Layout Settings
    btnLayoutSettings = uibutton(saveGL,'Text','Layout Settings...', ...
        'ButtonPushedFcn', @onOpenLayoutSettings, ...
        'BackgroundColor', [0.30 0.30 0.50], ...
        'FontColor', [1 1 1], ...
        'Tooltip', 'Open the Layout Settings window to configure panel sizes and figure dimensions');
    btnLayoutSettings.Layout.Row = 14; btnLayoutSettings.Layout.Column = [1 2];

    % ── Peak Analysis sub-panel (row 2, full width) ───────────────────────
    % Always visible; XRD buttons in corrGL activate it contextually.
    peakPanel = uipanel(analysisGL,'Title','Peak Analysis','FontSize',13);
    peakPanel.Layout.Row = 1; peakPanel.Layout.Column = 3;

    peakGL = uigridlayout(peakPanel,[1 2], ...
        'ColumnWidth', {'1x',110}, ...
        'Padding',     [6 6 6 6], ...
        'ColumnSpacing', 8);

    peakTable = uitable(peakGL, ...
        'ColumnName',     {'#','Center (°)','d (Å)','Size (nm)','FWHM (°)','Height','Area',char(951),'Status'}, ...
        'ColumnWidth',    {22, 82, 70, 70, 68, 65, 65, 38, 55}, ...
        'Data',           {}, ...
        'RowName',        {}, ...
        'ColumnEditable', [false false false false false false false false false], ...
        'CellSelectionCallback', @onPeakTableSelect, ...
        'Tooltip','Detected peaks — select a row to highlight it on the plot');
    peakTable.Layout.Column = 1;

    peakBtnGL = uigridlayout(peakGL,[14 1], ...
        'RowHeight',    {20,24,24,24,24,24,20,24,24,24,24,24,24,'1x'}, ...
        'Padding',      [0 0 0 0], ...
        'RowSpacing',   4);
    peakBtnGL.Layout.Column = 2;

    ddFitModel = uidropdown(peakBtnGL, ...
        'Items',   {'Lorentzian', 'Gaussian', 'Pseudo-Voigt', 'Split Pearson VII'}, ...
        'Value',   'Lorentzian', ...
        'Tooltip', ['Peak shape model: Lorentzian, Gaussian, Pseudo-Voigt (' char(951) char(183) ...
                    'L + (1-' char(951) ')' char(183) 'G), or Split Pearson VII (asymmetric)']);
    ddFitModel.Layout.Row = 1;

    btnFitPeaks = uibutton(peakBtnGL,'Text','Fit Peaks', ...
        'ButtonPushedFcn',@onFitPeaks, ...
        'BackgroundColor',[0.15 0.37 0.63],'FontColor',[1 1 1], ...
        'Tooltip','Fit the selected model to each listed peak and extract precise center and FWHM');
    btnFitPeaks.Layout.Row = 2;

    btnFitAllPeaks = uibutton(peakBtnGL,'Text','Fit All (global)', ...
        'ButtonPushedFcn',@onFitAllPeaks, ...
        'BackgroundColor',[0.10 0.28 0.55],'FontColor',[1 1 1], ...
        'Tooltip','Fit all peaks simultaneously as a single multi-peak model (requires ≥2 peaks)');
    btnFitAllPeaks.Layout.Row = 3;

    btnClearPeaks = uibutton(peakBtnGL,'Text','Clear All Peaks', ...
        'ButtonPushedFcn',@onClearPeaks, ...
        'Tooltip','Remove all peaks for the active dataset');
    btnClearPeaks.Layout.Row = 4;

    btnRemovePeak = uibutton(peakBtnGL,'Text','Remove Selected', ...
        'ButtonPushedFcn',@onRemoveSelectedPeak, ...
        'Tooltip','Remove the currently highlighted peak from the list');
    btnRemovePeak.Layout.Row = 5;

    btnSavePeaks = uibutton(peakBtnGL,'Text','Export Summary CSV', ...
        'ButtonPushedFcn',@onSavePeakSummary, ...
        'BackgroundColor',[0.30 0.30 0.60],'FontColor',[1 1 1], ...
        'Tooltip','Save peak centers and FWHM values to a CSV file');
    btnSavePeaks.Layout.Row = 6;

    btnExportPeakXLSX = uibutton(peakBtnGL,'Text','Export Peaks XLSX', ...
        'ButtonPushedFcn',@onExportPeakXLSX, ...
        'BackgroundColor',[0.20 0.40 0.20],'FontColor',[1 1 1], ...
        'Tooltip','Export peak data from all datasets to an Excel file (.xlsx)');
    btnExportPeakXLSX.Layout.Row = 7;

    chkShowFit = uicheckbox(peakBtnGL, ...
        'Text',              'Show fit curves', ...
        'Value',             true, ...
        'Tooltip',           'Overlay fit curves on the plot', ...
        'ValueChangedFcn',   @onToggleFitCurves);
    chkShowFit.Layout.Row = 8;

    btnFitColor = uibutton(peakBtnGL, 'Text', 'Fit curve color...', ...
        'Tooltip',           'Pick the color used for fit curve overlays', ...
        'ButtonPushedFcn',   @onPickFitColor);
    btnFitColor.Layout.Row = 9;
    btnFitColor.BackgroundColor = appData.fitCurveColor;

    btnWHPlot = uibutton(peakBtnGL, 'Text', 'W-H Plot', ...
        'ButtonPushedFcn', @onWilliamsonHallPlot, ...
        'BackgroundColor', [0.40 0.20 0.55], 'FontColor', [1 1 1], ...
        'Tooltip', ['Williamson-Hall strain analysis: plot ' char(946) char(183) ...
                    'cos' char(952) ' vs 4' char(183) 'sin' char(952) ...
                    '.  Needs ' char(8805) '3 fitted peaks.']);
    btnWHPlot.Layout.Row = 10;

    btnFFTThickness = uibutton(peakBtnGL, 'Text', 'FFT Thickness', ...
        'ButtonPushedFcn', @onFFTThickness, ...
        'BackgroundColor', [0.55 0.30 0.15], 'FontColor', [1 1 1], ...
        'Tooltip', 'Compute film thickness from Laue / Kiessig fringe periodicity via FFT');
    btnFFTThickness.Layout.Row = 11;

    btnReflFFT = uibutton(peakBtnGL, 'Text', 'Reflectivity FFT', ...
        'ButtonPushedFcn', @onReflectivityFFT, ...
        'BackgroundColor', [0.20 0.45 0.55], 'FontColor', [1 1 1], ...
        'Tooltip', ['Compute film thickness from Kiessig fringes via FFT.' newline ...
                    'For neutron/XRR data (Q-space). Also works for XRD in 2' char(952) ...
                    '-space if wavelength is set.']);
    btnReflFFT.Layout.Row = 12;

    btnRefineLattice = uibutton(peakBtnGL, 'Text', 'Refine Lattice...', ...
        'ButtonPushedFcn', @onRefineLattice, ...
        'BackgroundColor', [0.15 0.50 0.30], 'FontColor', [1 1 1], ...
        'Tooltip', 'Refine lattice parameters from fitted peak positions + hkl Miller indices');
    btnRefineLattice.Layout.Row = 13;

    % Row 14: Min sep / wavelength / source / K factor / instrument broadening (shared sub-grid)
    % X-ray source lookup table: {display name, wavelength_A}
    XRAY_SOURCES = { ...
        ['Cu K' char(945) '1 (1.5406 ' char(197) ')'],   1.5406; ...
        ['Cu K' char(945) '2 (1.5444 ' char(197) ')'],   1.5444; ...
        ['Cu K' char(945) ' avg (1.5418 ' char(197) ')'],1.5418; ...
        ['Mo K' char(945) '1 (0.7093 ' char(197) ')'],   0.7093; ...
        ['Co K' char(945) '1 (1.7889 ' char(197) ')'],   1.7889; ...
        ['Cr K' char(945) '1 (2.2909 ' char(197) ')'],   2.2909; ...
        ['Fe K' char(945) '1 (1.9373 ' char(197) ')'],   1.9373; ...
        ['Ag K' char(945) '1 (0.5594 ' char(197) ')'],   0.5594; ...
        'Custom',                                          NaN};

    minSepGL = uigridlayout(peakBtnGL, [6 2], ...
        'RowHeight', {'1x','1x','1x','1x','1x','1x'}, 'ColumnWidth', {64, '1x'}, ...
        'Padding', [0 0 0 0], 'ColumnSpacing', 4, 'RowSpacing', 2);
    minSepGL.Layout.Row = 14;
    lblMinSep = uilabel(minSepGL, 'Text', 'Min sep:', 'FontSize', 9, ...
        'HorizontalAlignment', 'right', ...
        'Tooltip', 'Minimum peak separation in degrees');
    lblMinSep.Layout.Row = 1; lblMinSep.Layout.Column = 1;
    efMinSep = uispinner(minSepGL, ...
        'Value', 0, 'Limits', [0 20], 'Step', 0.05, ...
        'Tooltip', ['Minimum peak separation (°) for auto-detect.  ' ...
                    '0 = automatic (~1% of x-range).  ' ...
                    'Decrease to resolve closely-spaced peaks.'], ...
        'ValueDisplayFormat', '%.2f');
    efMinSep.Layout.Row = 1; efMinSep.Layout.Column = 2;
    lblWavelength = uilabel(minSepGL, 'Text', [char(955), ' (', char(197), '):'], 'FontSize', 9, ...
        'HorizontalAlignment', 'right', ...
        'Tooltip', 'X-ray wavelength in Ångströms for d-spacing / Scherrer calculations');
    lblWavelength.Layout.Row = 2; lblWavelength.Layout.Column = 1;
    efWavelength = uieditfield(minSepGL, 'numeric', ...
        'Value', 0, 'Limits', [0 Inf], ...
        'Tooltip', ['Wavelength in Å for d-spacing & Scherrer.  ' ...
                    'Auto-filled from file metadata when available.  ' ...
                    'Cu K' char(945) '1 = 1.5406 Å.  0 = not set.'], ...
        'ValueChangedFcn', @onWavelengthChanged);
    efWavelength.Layout.Row = 2; efWavelength.Layout.Column = 2;
    % Row 3: X-ray source dropdown (spans both columns)
    ddXraySource = uidropdown(minSepGL, ...
        'Items',   XRAY_SOURCES(:,1)', ...
        'Value',   XRAY_SOURCES{1,1}, ...
        'FontSize', 9, ...
        'Tooltip', 'Select X-ray source to auto-fill wavelength; pick Custom to type manually', ...
        'ValueChangedFcn', @onXraySourceChanged);
    ddXraySource.Layout.Row = 3; ddXraySource.Layout.Column = [1 2];
    lblKFactor = uilabel(minSepGL, 'Text', 'K factor:', 'FontSize', 9, ...
        'HorizontalAlignment', 'right', ...
        'Tooltip', 'Scherrer shape factor K (0.9 for spherical grains, 1.0 for cubic)');
    lblKFactor.Layout.Row = 4; lblKFactor.Layout.Column = 1;
    efKFactor = uieditfield(minSepGL, 'numeric', ...
        'Value', appData.kFactor, 'Limits', [0.1 2], ...
        'Tooltip', 'Scherrer shape factor K — 0.9 (spherical) or 1.0 (cubic). Affects Size (nm) column.', ...
        'ValueChangedFcn', @onKFactorChanged);
    efKFactor.Layout.Row = 4; efKFactor.Layout.Column = 2;
    lblInstB = uilabel(minSepGL, 'Text', ['Inst ', char(946), ' (', char(176), '):'], 'FontSize', 9, ...
        'HorizontalAlignment', 'right', ...
        'Tooltip', ['Instrument broadening FWHM in degrees (e.g. LaB6 standard).  ' ...
                    '0 = no correction.  Subtracted in quadrature: ' ...
                    char(946), char(8321), char(8325), char(8331), ...
                    ' = sqrt(', char(946), char(8322), char(8320), char(8322), char(8331), ...
                    ' - ', char(946), char(8321), char(8326), char(8331), char(8322), ')']);
    lblInstB.Layout.Row = 5; lblInstB.Layout.Column = 1;
    efInstBroadening = uieditfield(minSepGL, 'numeric', ...
        'Value', appData.instBroadening_deg, 'Limits', [0 5], ...
        'Tooltip', ['Instrument broadening FWHM (°). Enter the FWHM of a standard (e.g. LaB6) peak.  ' ...
                    '0 = no correction applied.'], ...
        'ValueChangedFcn', @onInstBroadeningChanged);
    efInstBroadening.Layout.Row = 5; efInstBroadening.Layout.Column = 2;
    chkShowBG = uicheckbox(minSepGL, ...
        'Text',            'Show BG', ...
        'Value',           true, ...
        'FontSize',        9, ...
        'Tooltip',         'Overlay the estimated SNIP background curve on the plot', ...
        'ValueChangedFcn', @onToggleShowBG);
    chkShowBG.Layout.Row = 6; chkShowBG.Layout.Column = [1 2];

    % ── 2D Map controls (col 3, overlaps peakPanel — toggled by is2DDataset) ──
    map2DPanel = uipanel(analysisGL,'Title','2D Map View','FontSize',13);
    map2DPanel.Layout.Row = 1; map2DPanel.Layout.Column = 3;
    map2DPanel.Visible = 'off';   % shown only when a 2D area-detector dataset is active

    map2DGL = uigridlayout(map2DPanel,[6 2], ...
        'RowHeight',    {24, 24, 24, 26, 22, '1x'}, ...
        'ColumnWidth',  {95, '1x'}, ...
        'Padding',      [8 8 8 8], ...
        'RowSpacing',   5, ...
        'ColumnSpacing', 5);

    lblMap2DType = uilabel(map2DGL,'Text','Plot type:','FontSize',10,'HorizontalAlignment','right');
    lblMap2DType.Layout.Row = 1; lblMap2DType.Layout.Column = 1;
    ddMap2DType = uidropdown(map2DGL, ...
        'Items',           {'Heatmap','Contour','Filled Contour'}, ...
        'Value',           'Heatmap', ...
        'Tooltip',         'Rendering style for the 2D intensity map', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddMap2DType.Layout.Row = 1; ddMap2DType.Layout.Column = 2;

    lblMap2DLevels = uilabel(map2DGL,'Text','Contour lvls:','FontSize',10,'HorizontalAlignment','right');
    lblMap2DLevels.Layout.Row = 2; lblMap2DLevels.Layout.Column = 1;
    efMap2DContourN = uieditfield(map2DGL,'numeric', ...
        'Value',   20, ...
        'Limits',  [2 200], ...
        'Tooltip', 'Number of contour levels (Contour and Filled Contour modes)', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efMap2DContourN.Layout.Row = 2; efMap2DContourN.Layout.Column = 2;

    cbMap2DQSpace = uicheckbox(map2DGL, ...
        'Text',    'Q-space (Qx / Qz)', ...
        'Value',   false, ...
        'Enable',  'off', ...
        'Tooltip', ['Show reciprocal-space map in Qx/Qz coordinates.' newline ...
                    'Enabled when the file contains wavelength metadata.' newline ...
                    'Shift+click / Ctrl+click line-cuts use Q-space coordinates.']);
    cbMap2DQSpace.Layout.Row = 3; cbMap2DQSpace.Layout.Column = [1 2];

    btnPoleFigure = uibutton(map2DGL,'Text','Pole Figure...', ...
        'ButtonPushedFcn',@onPoleFigure, ...
        'BackgroundColor',[0.30 0.45 0.55], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Open a polar plot of integrated intensity at a chosen 2θ position');
    btnPoleFigure.Layout.Row = 4; btnPoleFigure.Layout.Column = [1 2];

    lblMap2DInfo = uilabel(map2DGL,'Text','', ...
        'FontSize', 9, ...
        'FontColor', [0.4 0.4 0.4], ...
        'HorizontalAlignment', 'center', ...
        'WordWrap', 'on');
    lblMap2DInfo.Layout.Row = 5; lblMap2DInfo.Layout.Column = [1 2];

    lblMap2DHint = uilabel(map2DGL,'Text','Shift+click: H-cut  |  Ctrl+click: V-cut', ...
        'FontSize', 8, ...
        'FontColor', [0.55 0.55 0.55], ...
        'HorizontalAlignment', 'center');
    lblMap2DHint.Layout.Row = 6; lblMap2DHint.Layout.Column = [1 2];

    % ── Drag-and-drop: register every major surface as a drop target (R2023a+) ──
    % In uifigure the CEF renderer consumes drag events at whichever child
    % component is under the cursor; they do NOT bubble up to the figure.
    % Registering each panel/listbox/axes individually ensures that a file
    % dropped anywhere in the window is caught.
    dropSurfaces = {ctrlPanel, axPanel, ax, analysisPanel, ...
                    corrPanel, axLimPanel, savePanel, peakPanel, lbDatasets};
    for surf_i = 1:numel(dropSurfaces)
        try
            dropSurfaces{surf_i}.AllowDrop = true;   % R2024a+: must opt-in before DropFcn fires
            dropSurfaces{surf_i}.DropFcn   = @onDropFiles;
        catch
            % Component does not support AllowDrop/DropFcn on this MATLAB version — skip
        end
    end
    clear surf_i dropSurfaces;

    % ── Load persistent layout prefs (if saved) ──────────────────────────
    if isfile(PREFS_FILE)
        try
            pv = load(PREFS_FILE, 'layoutPrefs');
            applyLayoutSettings(pv.layoutPrefs);
        catch
            % Prefs file unreadable — silently proceed with defaults
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  PROGRAMMATIC API (for automated testing / scripting)
    % ════════════════════════════════════════════════════════════════════
    api.fig                 = fig;
    api.addFiles            = @addFilesDirect;
    api.saveSession         = @saveSessionDirect;
    api.loadSession         = @loadSessionDirect;
    api.getDatasets         = @getDatasetsDirect;
    api.getActiveIdx        = @getActiveIdxDirect;
    api.setActiveIdx        = @setActiveIdxDirect;
    api.setCorrections      = @setCorrections;
    api.applyCorrections    = @() onApplyCorrections([],[]);
    api.applyCorrectionsAll = @() onApplyCorrectionsAll([],[]);
    api.undoCorrections     = @() onUndoCorrections([],[]);
    api.autoPeaks           = @() onAutoPeak([],[]);
    api.fitPeaks            = @() onFitPeaks([],[]);
    api.getPeaks            = @getPeaksDirect;
    api.setDatasetVisible   = @setDatasetVisibleDirect;
    api.close               = @() close(fig);
    % 2D map API (used by test_gui_2d.m / test_gui_phase4.m)
    api.is2DActive          = @is2DActiveDirect;
    api.setMap2DType        = @setMap2DTypeDirect;
    api.extractLineCut2D    = @extractLineCut2DDirect;
    api.setQSpace           = @setQSpaceDirect;
    api.setContourLevels    = @setContourLevelsDirect;
    api.setColormap         = @setColormapDirect;

    % ════════════════════════════════════════════════════════════════════
    %  NESTED CALLBACKS  (share appData + all control handles via closure)
    % ════════════════════════════════════════════════════════════════════

    % ── Dataset management ───────────────────────────────────────────────

    function onAddFiles(~,~)
    %ONADDFILES  Open a multi-select file dialog; load every chosen file.
        startDir = guiTernary(isempty(appData.lastDir), pwd, appData.lastDir);
        [fnames, fpath] = uigetfile( ...
            {'*.dat;*.csv;*.tsv;*.txt;*.xlsx;*.xls;*.xlsm;*.xlsb;*.ods;*.raw;*.xrdml;*.refl;*.pnr;*.datA;*.datB;*.datC;*.datD;*.data;*.datb;*.datc;*.datd', ...
             'Supported data files (*.dat, *.csv, *.xlsx, *.raw, *.xrdml, *.refl, *.pnr, *.datA/B/C/D)'; ...
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
    %  e.Data may be a string array, a char vector (newline-separated), or a
    %  cell array of char vectors — normalise to a cell array before processing.
        try
            d = e.Data;
            if isstring(d)
                % String scalar: may be newline-separated list; string array: one path per element.
                if isscalar(d)
                    fpaths = cellstr(strsplit(strtrim(d), newline));
                else
                    fpaths = cellstr(d);   % multi-element string array → cell of chars
                end
            elseif ischar(d)
                % Char vector — may be newline-separated (legacy format)
                fpaths = cellstr(strsplit(strtrim(d), newline));
            elseif iscell(d)
                fpaths = d;
            else
                return;   % unrecognised format; nothing to do
            end
            fpaths = fpaths(~cellfun(@isempty, fpaths));
            if isempty(fpaths), return; end

            supported = {'.dat','.csv','.tsv','.txt', ...
                         '.xlsx','.xls','.xlsm','.xlsb','.ods', ...
                         '.raw','.xrdml','.brml', ...
                         '.refl','.pnr', ...
                         '.datA','.datB','.datC','.datD', ...
                         '.data','.datb','.datc','.datd'};
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
                        logGUIError('Import error', sprintf('%s [%s]  %s', fnBase, shName, ME.message), ME);
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
                logGUIError('Import error', sprintf('%s  %s', [fnBase fExt], ME.message), ME);
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

    % ════════════════════════════════════════════════════════════════════
    %  API HELPER FUNCTIONS
    % ════════════════════════════════════════════════════════════════════

    function addFilesDirect(fpaths)
    %ADDFILESDIRECT  Load files from a cell array of paths (or normalizing string input).
        if isstring(fpaths)
            fpaths = cellstr(fpaths);
        elseif ischar(fpaths)
            fpaths = {fpaths};
        end
        loadFilePaths(fpaths);
    end

    function saveSessionDirect(outPath)
    %SAVESESSIONDIRECT  Save session to .mat file (no dialog).
        if nargin < 1 || isempty(outPath)
            error('outPath required');
        end

        % Save datasets with all their state
        savedDatasets = appData.datasets;

        % Save GUI state
        savedState = struct( ...
            'colormap', ddColormap.Value, ...
            'xCol', ddX.Value, ...
            'yCol', lbY.Value, ...
            'y2Col', lbY2.Value, ...
            'logX', cbLogX.Value, ...
            'logY', cbLogY.Value, ...
            'logY2', cbLogY2.Value);

        save(outPath, 'savedDatasets', 'savedState');
    end

    function loadSessionDirect(matPath)
    %LOADSESSIONDIRECT  Load session from .mat file (no dialog).
        if nargin < 1 || isempty(matPath)
            error('matPath required');
        end

        if ~isfile(matPath)
            error('Session file not found: %s', matPath);
        end

        s = load(matPath);
        if ~isfield(s, 'savedDatasets')
            error('Invalid session file: missing savedDatasets field');
        end

        % Restore datasets
        appData.datasets  = s.savedDatasets;
        appData.activeIdx = 0;

        % parserVersion compatibility check (#18)
        nLegacy = sum(cellfun(@(ds) ...
            ~isfield(ds.data.metadata, 'parserVersion'), appData.datasets));
        if nLegacy > 0
            warning('dataImportGUI:legacySession', ...
                '%d dataset(s) lack parserVersion; re-import files to attach version metadata.', ...
                nLegacy);
        end

        % Restore GUI state if available
        if isfield(s, 'savedState')
            try
                ddColormap.Value = s.savedState.colormap;
                ddX.Value = s.savedState.xCol;
                lbY.Value = s.savedState.yCol;
                lbY2.Value = s.savedState.y2Col;
                cbLogX.Value = s.savedState.logX;
                cbLogY.Value = s.savedState.logY;
                cbLogY2.Value = s.savedState.logY2;
            catch
                % Ignore state restoration errors; dataset structure is sufficient
            end
        end

        cancelInteractions();
        rebuildDatasetList(true);
        if ~isempty(appData.datasets)
            appData.activeIdx = 1;
            updateControlsForActiveDataset();
        end
        onPlot([],[]);
    end

    function setActiveIdxDirect(idx)
    %SETACTIVEIDXDIRECT  Set the active dataset by index (1-based).
        assert(isnumeric(idx) && idx >= 1 && idx <= numel(appData.datasets), ...
            'idx must be integer in range [1, %d]', numel(appData.datasets));
        appData.activeIdx = idx;
        updateControlsForActiveDataset();
        onPlot([],[]);
    end

    function setCorrections(xOff, yOff, bgSlope, bgInt)
    %SETCORRECTIONS  Set correction widget values (xOffset, yOffset, bgSlope, bgIntercept).
        if nargin < 1, xOff = []; end
        if nargin < 2, yOff = []; end
        if nargin < 3, bgSlope = []; end
        if nargin < 4, bgInt = []; end

        if ~isempty(xOff),  efXOffset.Value = xOff; end
        if ~isempty(yOff),  efYOffset.Value = yOff; end
        if ~isempty(bgSlope), efBGSlope.Value = bgSlope; end
        if ~isempty(bgInt),  efBGIntercept.Value = bgInt; end
    end

    function peaks = getPeaksDirect()
    %GETPEAKSDIRECT  Return peaks from active dataset, or empty struct.
        if appData.activeIdx == 0
            peaks = struct.empty;
        else
            ds = appData.datasets{appData.activeIdx};
            if isfield(ds, 'peaks') && ~isempty(ds.peaks)
                peaks = ds.peaks;
            else
                peaks = struct.empty;
            end
        end
    end

    function ds = getDatasetsDirect()
    %GETDATASETSDIRECT  Return live cell array of dataset structs.
        ds = appData.datasets;
    end

    function idx = getActiveIdxDirect()
    %GETACTIVEIDXDIRECT  Return live active dataset index (0 when none loaded).
        idx = appData.activeIdx;
    end

    function setDatasetVisibleDirect(idx, vis)
    %SETDATASETVISIBLEDDIRECT  Set visibility of dataset at index.
        assert(isnumeric(idx) && idx >= 1 && idx <= numel(appData.datasets), ...
            'idx out of range');
        assert(islogical(vis) || isnumeric(vis), 'vis must be logical');
        appData.datasets{idx}.visible = logical(vis);
        onPlot([],[]);
    end

    function tf = is2DActiveDirect()
    %IS2DACTIVEDIRECT  True when the active dataset is a 2D area-detector map.
        tf = appData.activeIdx >= 1 && ~isempty(appData.datasets) && ...
             is2DDataset(appData.datasets{appData.activeIdx});
    end

    function setMap2DTypeDirect(typeStr)
    %SETMAP2DTYPEDIRECT  Set the 2D plot type and trigger a replot.
    %   typeStr: 'Heatmap' | 'Contour' | 'Filled Contour'
        validTypes = {'Heatmap', 'Contour', 'Filled Contour'};
        assert(ismember(typeStr, validTypes), ...
            'typeStr must be one of: %s', strjoin(validTypes, ', '));
        ddMap2DType.Value = typeStr;
        onPlot([],[]);
        drawnow;
    end

    function extractLineCut2DDirect(clickX, clickY, isHorizontal)
    %EXTRACTLINECUT2DDIRECT  Programmatically extract a 1D slice from the 2D map.
    %   Mirrors the Shift+click / Ctrl+click interaction.
        extract2DLineCut(clickX, clickY, isHorizontal);
        drawnow;
    end

    function setQSpaceDirect(tf)
    %SETQSPACEDIRECT  Enable or disable Q-space axes on the 2D map and replot.
    %   tf: true to enable Q-space (Qx/Qz), false for angular axes.
        cbMap2DQSpace.Value = logical(tf);
        onPlot([],[]);
        drawnow;
    end

    function setContourLevelsDirect(n)
    %SETCONTOURLEVELSDIRECT  Set the number of contour levels for Contour/Filled Contour plots.
    %   n: positive integer (e.g. 20)
        efMap2DContourN.Value = round(n);
    end

    function setColormapDirect(name)
    %SETCOLOURMAPDIRECT  Set the colormap by name and replot.
    %   name: one of the items in ddColormap (e.g. 'parula', 'viridis', 'jet')
        ddColormap.Value = name;
        onPlot([],[]);
        drawnow;
    end

    function onSelectDataset(~,~)
    %ONSELECTDATASET  Fires when the user clicks a row in lbDatasets.
    %  With Multiselect='on', lbDatasets.Value is a cell array of selected
    %  ItemsData values.  The active dataset is the first (most-recently
    %  clicked) element.
        rawVal = lbDatasets.Value;
        % Normalise to a numeric scalar (the "primary" selection)
        if iscell(rawVal)
            if isempty(rawVal), return; end
            val = rawVal{1};   % first element is the active dataset
        else
            val = rawVal;
        end
        if ~isnumeric(val) || numel(val) ~= 1, return; end
        if val < 1 || val > numel(appData.datasets), return; end
        if val == appData.activeIdx, return; end   % no change

        saveAxisLimsToActiveDataset();   % persist zoom before leaving current dataset
        % Don't cancel while a listbox drag has been initiated: cancelInteractions()
        % would clear the WindowButtonMotionFcn/UpFcn that onAxesButtonDown just set.
        if appData.listDragSrcIdx == 0
            cancelInteractions();
        end
        appData.activeIdx = val;
        updateControlsForActiveDataset();
        onPlot([],[]);
    end

    function onSearchChanged(~,~)
    %ONSEARCHCHANGED  Update dataset list filter when search box text changes.
        appData.searchFilter = efDatasetSearch.Value;
        rebuildDatasetList(true);
    end

    function onMergeDatasets(~,~)
    %ONMERGEDATASETS  Concatenate the selected datasets into one new dataset.
    %  Requires ≥ 2 datasets selected in lbDatasets (multi-select).
    %  Uses corrData if available, otherwise raw data.
    %  The merged x-vector is sorted ascending; y columns are concatenated
    %  to match the first dataset's label/unit layout.
        if isempty(appData.datasets)
            uialert(fig,'Load files first.','No data'); return;
        end

        % Collect selected indices from multi-select listbox
        rawVal = lbDatasets.Value;
        if ~iscell(rawVal), rawVal = {rawVal}; end
        selIdxList = cell2mat(rawVal);   % numeric vector of dataset indices
        selIdxList = selIdxList(selIdxList >= 1 & selIdxList <= numel(appData.datasets));

        if numel(selIdxList) < 2
            uialert(fig, ...
                sprintf(['Select at least 2 datasets in the list ' ...
                         '(Ctrl+click or Shift+click).\n' ...
                         'Currently selected: %d dataset(s).'], numel(selIdxList)), ...
                'Merge: need ≥2 datasets');
            return;
        end

        % Use corrData if available, else raw data
        d1 = appData.datasets{selIdxList(1)};
        baseData = guiTernary(~isempty(d1.corrData), d1.corrData, d1.data);

        mergedTime   = double(baseData.time);
        mergedValues = baseData.values;

        ok = true;
        for mi = 2:numel(selIdxList)
            dsi  = appData.datasets{selIdxList(mi)};
            di   = guiTernary(~isempty(dsi.corrData), dsi.corrData, dsi.data);

            % Check column count compatibility
            if size(di.values, 2) ~= size(baseData.values, 2)
                uialert(fig, ...
                    sprintf(['Dataset #%d has %d Y columns but dataset #%d has %d.\n' ...
                             'All selected datasets must have the same number of channels.'], ...
                             selIdxList(mi), size(di.values,2), ...
                             selIdxList(1),  size(baseData.values,2)), ...
                    'Merge: column mismatch');
                ok = false;  break;
            end

            mergedTime   = [mergedTime;   double(di.time)];   %#ok<AGROW>
            mergedValues = [mergedValues; di.values];           %#ok<AGROW>
        end
        if ~ok, return; end

        % Sort by x (ascending)
        [mergedTime, sortOrder] = sort(mergedTime, 'ascend');
        mergedValues = mergedValues(sortOrder, :);

        % Build merged data struct from the first dataset's metadata
        mergedData          = baseData;
        mergedData.time     = mergedTime;
        mergedData.values   = mergedValues;

        % Build display name from constituent filenames
        nameStrs = cell(1, numel(selIdxList));
        for mi = 1:numel(selIdxList)
            [~, fn, ~] = fileparts(appData.datasets{selIdxList(mi)}.filepath);
            nameStrs{mi} = fn;
        end
        mergedName = ['[merged] ', strjoin(nameStrs, ' + ')];

        ds = buildDs(appData.datasets{selIdxList(1)}.filepath, mergedData, ...
                     appData.datasets{selIdxList(1)}.parserName);
        ds.displayName = mergedName;

        appData.datasets{end+1} = ds;
        appData.activeIdx       = numel(appData.datasets);

        cancelInteractions();
        rebuildDatasetList(true);
        updateControlsForActiveDataset();
        onPlot([],[]);
    end

    function onDatasetMath(~,~)
    %ONDATASETMATH  Open expression dialog for derived dataset creation.
    %  Supports: D1/D2, D1-D2, D1*D2, D1+D2, log10(D1), diff(D1), abs(D1)
    %  Datasets are referenced by index: D1 = dataset #1, D2 = dataset #2, etc.
    %  When two datasets have different x-grids, interp1 aligns them.
        if isempty(appData.datasets)
            uialert(fig,'Load files first.','No data'); return;
        end
        nDS = numel(appData.datasets);

        % Build dataset list for the prompt
        dsNames = cell(1, nDS);
        for dmi = 1:nDS
            [~, fn, ext] = fileparts(appData.datasets{dmi}.filepath);
            dsNames{dmi} = sprintf('  D%d = %s%s', dmi, fn, ext);
        end
        prompt = sprintf(['Enter expression using D1, D2, ... (dataset indices):\n\n' ...
                          'Available datasets:\n%s\n\n' ...
                          'Examples:  D1 - D2,  D1 / D2,  log10(D1),  diff(D1)'], ...
                          strjoin(dsNames, '\n'));

        answer = inputdlg(prompt, 'Dataset Math', [1 60], {'D1 - D2'});
        if isempty(answer), return; end
        expr = strtrim(answer{1});
        if isempty(expr), return; end

        try
            % Parse referenced dataset indices (D1, D2, ...)
            refIdxs = unique(str2double(regexp(expr, 'D(\d+)', 'tokens', 'once')));
            allRefs = regexp(expr, 'D(\d+)', 'tokens');
            refIdxs = unique(cellfun(@(c) str2double(c{1}), allRefs));

            if any(refIdxs < 1 | refIdxs > nDS)
                error('Dataset index out of range (1 to %d).', nDS);
            end

            % Use corrected data if available; get first referenced dataset as base
            baseIdx = refIdxs(1);
            baseDs  = appData.datasets{baseIdx};
            baseD   = guiTernary(~isempty(baseDs.corrData), baseDs.corrData, baseDs.data);
            xBase   = double(baseD.time);

            % Build variable map: D1 → y-values (first channel), interp to base x-grid
            vars = struct();
            for ri = 1:numel(refIdxs)
                di = refIdxs(ri);
                dsi = appData.datasets{di};
                d   = guiTernary(~isempty(dsi.corrData), dsi.corrData, dsi.data);
                yVec = d.values(:, 1);  % use first y-channel
                if di ~= baseIdx
                    % Interpolate to base x-grid
                    yVec = interp1(double(d.time), yVec, xBase, 'linear', NaN);
                end
                vars.(sprintf('D%d', di)) = yVec;
            end

            % Replace D<N> references with struct field access for safe evaluation
            safeExpr = expr;
            for ri = sort(refIdxs, 'descend')  % descend to avoid D1 matching in D10
                safeExpr = strrep(safeExpr, sprintf('D%d', ri), sprintf('vars.D%d', ri));
            end

            % Evaluate expression (only allow safe math operations)
            yResult = eval(safeExpr); %#ok<EVLC>

            if ~isnumeric(yResult) || numel(yResult) ~= numel(xBase)
                error('Expression did not produce a vector of the correct length.');
            end

            % Build result data struct
            resultD        = baseD;
            resultD.time   = xBase;
            resultD.values = yResult(:);
            resultD.labels = {expr};
            resultD.units  = {''};

            ds = buildDs(baseDs.filepath, resultD, 'math');
            ds.displayName = ['[math] ' expr];
            ds.legendName  = expr;

            appData.datasets{end+1} = ds;
            appData.activeIdx       = numel(appData.datasets);

            rebuildDatasetList(true);
            updateControlsForActiveDataset();
            onPlot([],[]);
        catch ME
            logGUIError('Dataset Math Error', ME.message, ME);
            uialert(fig, sprintf('Expression error:\n\n%s', ME.message), 'Dataset Math Error');
        end
    end

    function onDatasetColorChanged(~,~)
    %ONDATASETCOLORCHANGED  Store colour override on the active dataset and replot.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds       = appData.datasets{appData.activeIdx};
        ds.color = ddDatasetColor.Value;   % [] = Auto; [r g b] = named colour
        appData.datasets{appData.activeIdx} = ds;
        softUpdateLines();  % Fast path: update only colors/visibility
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
    %ONREMOVEDATASET  Remove selected dataset(s) from the list.
    %  Supports removing multiple selected datasets when multi-select is enabled.
        if isempty(appData.datasets) || isempty(lbDatasets.Value), return; end

        cancelInteractions();

        % lbDatasets.ItemsData contains numeric indices, so Value returns
        % the selected indices directly (not display strings).
        sel = lbDatasets.Value;
        if iscell(sel)
            indicesToRemove = [sel{:}];
        else
            indicesToRemove = sel;
        end

        % Filter out invalid indices (e.g. the placeholder 0)
        indicesToRemove(indicesToRemove < 1 | indicesToRemove > numel(appData.datasets)) = [];

        % Sort indices in descending order so removal doesn't affect remaining indices
        indicesToRemove = sort(indicesToRemove, 'descend');

        % Remove selected datasets
        appData.datasets(indicesToRemove) = [];

        if isempty(appData.datasets)
            appData.activeIdx = 0;
            lbDatasets.Items     = {'(no files loaded — click  Add File(s)...  to begin)'};
            lbDatasets.ItemsData = {0};
            lbDatasets.Value     = {0};
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
            ax.XLim = [0 1];  ax.YLim = [0 1];
            ax.XLimMode = 'auto';  ax.YLimMode = 'auto';
            title(ax,'Load a file to preview data','Interpreter','none');
        else
            appData.activeIdx = min(appData.activeIdx, numel(appData.datasets));
            rebuildDatasetList(true);
            updateControlsForActiveDataset();
            onPlot([],[]);
        end
    end

    function onToggleAnimation(~,~)
    %ONTOGGLEANIMATION  Start/stop cycling through datasets as animation frames.
    %  Uses a MATLAB timer at ~2 fps to step through each dataset in sequence.
        if isfield(appData, 'animTimer') && ~isempty(appData.animTimer) && isvalid(appData.animTimer)
            % Stop animation
            stop(appData.animTimer);
            delete(appData.animTimer);
            appData.animTimer = [];
            btnAnimate.Text = [char(9654) ' Animate'];
            btnAnimate.BackgroundColor = [0.50 0.35 0.15];
            return;
        end

        if numel(appData.datasets) < 2
            uialert(fig,'Need at least 2 datasets to animate.','Animate'); return;
        end

        btnAnimate.Text = [char(9724) ' Stop'];
        btnAnimate.BackgroundColor = [0.70 0.18 0.18];

        appData.animTimer = timer('ExecutionMode', 'fixedRate', ...
            'Period', 0.5, ...
            'TimerFcn', @(~,~) animStep());
        start(appData.animTimer);
    end

    function animStep()
    %ANIMSTEP  Advance to the next dataset frame (called by animation timer).
        if isempty(appData.datasets), return; end
        nextIdx = appData.activeIdx + 1;
        if nextIdx > numel(appData.datasets)
            nextIdx = 1;
        end
        appData.activeIdx = nextIdx;
        rebuildDatasetList(true);
        updateControlsForActiveDataset();
        onPlot([],[]);
        drawnow limitrate;
    end

    function onMoveDatasetUp(~,~)
    %ONMOVEDATASETUP  Move the active dataset one position up in the list.
        if appData.activeIdx <= 1 || numel(appData.datasets) < 2, return; end
        idx = appData.activeIdx;
        appData.datasets([idx-1, idx]) = appData.datasets([idx, idx-1]);
        appData.activeIdx = idx - 1;
        rebuildDatasetList(true);
        onPlot([],[]);
    end

    function onMoveDatasetDown(~,~)
    %ONMOVEDATASETDOWN  Move the active dataset one position down in the list.
        if appData.activeIdx < 1 || appData.activeIdx >= numel(appData.datasets), return; end
        idx = appData.activeIdx;
        appData.datasets([idx, idx+1]) = appData.datasets([idx+1, idx]);
        appData.activeIdx = idx + 1;
        rebuildDatasetList(true);
        onPlot([],[]);
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
    %  Applies appData.searchFilter (case-insensitive substring) to the display
    %  strings, but always keeps the active dataset visible regardless of filter.
        N = numel(appData.datasets);
        if N == 0
            lbDatasets.Items     = {'(no files loaded — click  Add File(s)...  to begin)'};
            lbDatasets.ItemsData = {0};
            lbDatasets.Value     = {0};
            appData.activeIdx    = 0;
            % Disable dataset-dependent buttons when no data loaded
            btnRemoveDS.Enable  = 'off';
            btnMerge.Enable     = 'off';
            return;
        else
            % Re-enable dataset buttons when data is available
            btnRemoveDS.Enable  = 'on';
            btnMerge.Enable     = 'on';
        end

        % Build full display strings for all datasets
        allItems    = cell(1, N);
        allIdxData  = num2cell(1:N);
        for i = 1:N
            dsI = appData.datasets{i};
            badgeStr = getParserBadge(dsI.parserName);
            if isfield(dsI,'legendName') && ~isempty(dsI.legendName)
                displayStr = dsI.legendName;
            elseif isfield(dsI,'displayName') && ~isempty(dsI.displayName)
                displayStr = dsI.displayName;
            else
                [~, fn, fext] = fileparts(dsI.filepath);
                displayStr = [fn, fext];
            end
            allItems{i} = sprintf('[%d]  %s  %s', i, badgeStr, displayStr);
        end

        % Apply search filter (always keep active dataset visible)
        filt = strtrim(appData.searchFilter);
        if isempty(filt)
            visIdx = 1:N;
        else
            filtLC = lower(filt);
            visIdx = find(cellfun(@(s) contains(lower(s), filtLC), allItems));
            % Always include active dataset so it stays selectable
            if keepActiveIdx && appData.activeIdx >= 1 && appData.activeIdx <= N
                if ~ismember(appData.activeIdx, visIdx)
                    visIdx = sort([visIdx, appData.activeIdx]);
                end
            end
        end

        if isempty(visIdx)
            lbDatasets.Items     = {'(no matches)'};
            lbDatasets.ItemsData = {0};
            lbDatasets.Value     = {0};
            return;
        end

        lbDatasets.Items     = allItems(visIdx);
        lbDatasets.ItemsData = allIdxData(visIdx);

        if keepActiveIdx && appData.activeIdx >= 1 && appData.activeIdx <= N && ...
           ismember(appData.activeIdx, visIdx)
            lbDatasets.Value = {appData.activeIdx};
        else
            appData.activeIdx = visIdx(1);
            lbDatasets.Value  = {visIdx(1)};
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
        lblRegionStats.Text       = '';  % Clear region statistics display
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
        % Restore BG polynomial order dropdown
        if isfield(ds,'bgPoly') && numel(ds.bgPoly) > 2
            bgPolyOrd = numel(ds.bgPoly) - 1;   % poly order = nCoeffs - 1
            if bgPolyOrd >= 2 && bgPolyOrd <= 6
                ddBGOrder.Value = sprintf('Poly %d', bgPolyOrd);
            end
        else
            ddBGOrder.Value = 'Linear';
        end
        cbSmooth.Value       = guiTernary(isfield(ds,'smoothEnabled'), ds.smoothEnabled, false);
        efSmoothWin.Value    = guiTernary(isfield(ds,'smoothWindow'),  ds.smoothWindow,  5);
        ddSmoothMethod.Value = guiTernary(isfield(ds,'smoothMethod'),  ds.smoothMethod,  'Moving');
        efXTrimMin.Value     = nan2str(guiTernary(isfield(ds,'xTrimMin'),      ds.xTrimMin,      NaN));
        efXTrimMax.Value     = nan2str(guiTernary(isfield(ds,'xTrimMax'),      ds.xTrimMax,      NaN));
        ddNormalize.Value    = guiTernary(isfield(ds,'normMethod'),    ds.normMethod,    'None');

        % Restore wavelength override field; auto-fill from metadata if no override set
        wl_meta = extractWavelength_A(ds);
        if isfield(ds,'wavelengthOverride_A') && ~isnan(ds.wavelengthOverride_A) && ds.wavelengthOverride_A > 0
            efWavelength.Value = ds.wavelengthOverride_A;
        elseif ~isnan(wl_meta) && wl_meta > 0
            efWavelength.Value = wl_meta;
        else
            efWavelength.Value = 0;
        end

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
        fmtGL.ColumnWidth{5}  = guiTernary(y2Active, 20,   0);
        fmtGL.ColumnWidth{6}  = guiTernary(y2Active, '1x', 0);
        toggleY2Appearance(y2Active);

        [fp2, fn2, ~] = fileparts(ds.filepath);
        if ~isempty(ds.corrData)
            efSavePath.Value = fullfile(fp2, [fn2, '_corrected.csv']);
        elseif isfield(ds, 'parserName') && isNeutronParser(ds.parserName)
            efSavePath.Value = fullfile(fp2, [neutronBaseName(ds.filepath), '_neutron.csv']);
        else
            efSavePath.Value = fullfile(fp2, [fn2, '_export.csv']);
        end

        applyParserAnalysisConfig(resolvedCorrStyle());

        % Auto-configure for neutron data; reset log scale for non-neutron
        if isNeutronParser(ds.parserName)
            rIdx = find(strcmp(d.labels, 'R'), 1);
            if ~isempty(rIdx)
                lbY.Value = d.labels(rIdx);
            end
            cbLogY.Value = true;
        elseif is2DDataset(ds)
            cbLogY.Value = true;  % log intensity is standard for XRD reciprocal-space maps
            % Update map dimension info label
            map = ds.data.metadata.parserSpecific.map2D;
            lblMap2DInfo.Text = sprintf('%d %s positions  \xD7  %d 2\xB0 pixels', ...
                numel(map.axis1), map.axis1Name, numel(map.axis2));
            % Enable Q-space toggle only when wavelength was available for conversion
            if isfield(map, 'Qx')
                cbMap2DQSpace.Enable = 'on';
            else
                cbMap2DQSpace.Enable = 'off';
                cbMap2DQSpace.Value  = false;
            end
        else
            cbLogY.Value = false;
        end

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
            case {'importRigaku_raw', 'importXRDML', 'importBruker'}
                % Re-enable controls for non-neutron case
                for hh = {efXOffset, efYOffset, efBGSlope, efBGIntercept, ...
                          btnApply, btnReset, btnApplyAll, btnUndo, ...
                          cbSmooth, efSmoothWin, ddSmoothMethod, ...
                          efXTrimMin, efXTrimMax, ddNormalize}
                    hh{1}.Enable = 'on'; %#ok<FXSET>
                end
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
                % Peak analysis panel — visible for XRD (col 3 and col 4 split flexible width)
                peakPanel.Visible          = 'on';
                peakPanel.Title            = 'Peak Analysis';
                analysisGL.ColumnWidth     = {appData.corrPanelWidth, appData.axLimPanelWidth, '7x', '3x'};
                % Restore all XRD peak buttons
                for hh = {ddFitModel, btnFitPeaks, btnFitAllPeaks, btnClearPeaks, ...
                          btnRemovePeak, btnSavePeaks, btnExportPeakXLSX, chkShowFit, ...
                          btnFitColor, btnWHPlot, btnFFTThickness, btnRefineLattice, btnReflFFT}
                    hh{1}.Visible = 'on'; %#ok<FXSET>
                end
                % Hide asymmetry rows (save 48px); restore BG rows
                corrGL.RowHeight{7}  = 24; corrGL.RowHeight{8}  = 24;
                corrGL.RowHeight{15} = 0;  corrGL.RowHeight{16} = 0;

            case 'importQDVSM'
                % Re-enable controls for non-neutron case
                for hh = {efXOffset, efYOffset, efBGSlope, efBGIntercept, ...
                          btnApply, btnReset, btnApplyAll, btnUndo, ...
                          cbSmooth, efSmoothWin, ddSmoothMethod, ...
                          efXTrimMin, efXTrimMax, ddNormalize}
                    hh{1}.Enable = 'on'; %#ok<FXSET>
                end
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
                analysisGL.ColumnWidth     = {appData.corrPanelWidth, '7x', 0, '3x'};
                % Hide asymmetry rows (save 48px); restore BG rows
                corrGL.RowHeight{7}  = 24; corrGL.RowHeight{8}  = 24;
                corrGL.RowHeight{15} = 0;  corrGL.RowHeight{16} = 0;

            case 'importPPMS'
                % Re-enable controls for non-neutron case
                for hh = {efXOffset, efYOffset, efBGSlope, efBGIntercept, ...
                          btnApply, btnReset, btnApplyAll, btnUndo, ...
                          cbSmooth, efSmoothWin, ddSmoothMethod, ...
                          efXTrimMin, efXTrimMax, ddNormalize}
                    hh{1}.Enable = 'on'; %#ok<FXSET>
                end
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
                analysisGL.ColumnWidth     = {appData.corrPanelWidth, '7x', 0, '3x'};
                % Hide asymmetry rows (save 48px); restore BG rows
                corrGL.RowHeight{7}  = 24; corrGL.RowHeight{8}  = 24;
                corrGL.RowHeight{15} = 0;  corrGL.RowHeight{16} = 0;

            case {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'}
                analysisPanel.Title = 'Analysis & Corrections  —  Neutron Reflectometry';
                lblXOff.Text  = 'Q Offset:';
                efXOffset.Tooltip = 'Q-offset: Q_corrected = Q − this value  (0 = no shift)';
                lblYOff.Text  = 'R Scale:';
                efYOffset.Tooltip = 'R scale factor: R_corrected = R × this value  (1.0 = no change)';
                % Enable useful corrections (offsets, trim, normalize, apply/reset)
                for hh = {efXOffset, efYOffset, btnApply, btnReset, btnApplyAll, btnUndo, ...
                          efXTrimMin, efXTrimMax, ddNormalize}
                    hh{1}.Enable = 'on'; %#ok<FXSET>
                end
                % Keep BG slope/intercept and smoothing disabled (not meaningful for neutron)
                for hh = {efBGSlope, efBGIntercept, cbSmooth, efSmoothWin, ddSmoothMethod}
                    hh{1}.Enable = 'off'; %#ok<FXSET>
                end
                lblBGSlope.Text = 'BG Slope:';
                lblBGInt.Text   = 'BG Intercept:';
                btnFitBG.Visible           = 'off';
                btnPickY.Visible           = 'off';
                btnYTranslate.Visible      = 'off';
                btnAutoPeak.Visible        = 'off';
                btnManualPeak.Visible      = 'off';
                btnRemovePeakClick.Visible = 'off';
                btnApply.Tooltip = 'Apply Q offset / R scale, trim, and normalization to all polarizations from the same measurement';
                % Show peak panel (reduced: only Reflectivity FFT + wavelength controls)
                peakPanel.Visible          = 'on';
                peakPanel.Title            = 'Reflectivity Analysis';
                analysisGL.ColumnWidth     = {appData.corrPanelWidth, appData.axLimPanelWidth, '4x', '3x'};
                % Hide XRD-specific peak buttons; show only Reflectivity FFT
                for hh = {ddFitModel, btnFitPeaks, btnFitAllPeaks, btnClearPeaks, ...
                          btnRemovePeak, btnSavePeaks, btnExportPeakXLSX, chkShowFit, ...
                          btnFitColor, btnWHPlot, btnFFTThickness, btnRefineLattice}
                    hh{1}.Visible = 'off'; %#ok<FXSET>
                end
                btnReflFFT.Visible = 'on';
                % Hide BG file rows (not applicable); show asymmetry rows
                corrGL.RowHeight{7}  = 0;  corrGL.RowHeight{8}  = 0;
                corrGL.RowHeight{15} = 24; corrGL.RowHeight{16} = 24;
                % Show neutron-specific analysis controls
                lblAsymmetry.Enable        = 'on';
                cbCalculateAsymmetry.Enable = 'on';
                lblAsymFormula.Enable      = 'on';
                ddAsymFormula.Enable       = 'on';

            otherwise  % importCSV, importExcel, unknown — generic labels
                % Hide asymmetry rows (save 48px); restore BG rows
                corrGL.RowHeight{7}  = 24; corrGL.RowHeight{8}  = 24;
                corrGL.RowHeight{15} = 0;  corrGL.RowHeight{16} = 0;
                % Re-enable controls for non-neutron case
                for hh = {efXOffset, efYOffset, efBGSlope, efBGIntercept, ...
                          btnApply, btnReset, btnApplyAll, btnUndo, ...
                          cbSmooth, efSmoothWin, ddSmoothMethod, ...
                          efXTrimMin, efXTrimMax, ddNormalize}
                    hh{1}.Enable = 'on'; %#ok<FXSET>
                end
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
                analysisGL.ColumnWidth     = {appData.corrPanelWidth, '7x', 0, '3x'};
        end

        % ── 2D area-detector override (applied after the switch) ─────────
        % When the active dataset contains a 2D map, hide the peak panel and
        % corrections (not meaningful for raw intensity maps) and show the
        % map2D controls instead.
        is2D_active = appData.activeIdx >= 1 && ~isempty(appData.datasets) && ...
                      is2DDataset(appData.datasets{appData.activeIdx});
        if is2D_active
            peakPanel.Visible  = 'off';
            map2DPanel.Visible = 'on';
            analysisGL.ColumnWidth = {appData.corrPanelWidth, appData.axLimPanelWidth, '4x', '3x'};
            % Disable all corrections — not meaningful for raw 2D maps
            for hh = {efXOffset, efYOffset, efBGSlope, efBGIntercept, ...
                      btnApply, btnReset, btnApplyAll, btnUndo, ...
                      cbSmooth, efSmoothWin, ddSmoothMethod, ...
                      efXTrimMin, efXTrimMax, ddNormalize}
                hh{1}.Enable = 'off'; %#ok<FXSET>
            end
            btnFitBG.Visible           = 'off';
            btnPickY.Visible           = 'off';
            btnYTranslate.Visible      = 'off';
            btnAutoPeak.Visible        = 'off';
            btnManualPeak.Visible      = 'off';
            btnRemovePeakClick.Visible = 'off';
            analysisPanel.Title = 'Analysis  —  XRD 2D Map';
        else
            map2DPanel.Visible = 'off';
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
            case 'Neutron NR'
                pName = 'importNCNRDat';
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
    %ONAUTOPEAK  SNIP-based peak detection with manual seed preservation.
    %
    %  Uses utilities.findPeaksRobust for background-aware peak finding.
    %  Manual seeds from previous runs are preserved via Pass 2 re-detection.
    %  Output  — ds.peaks is REPLACED with deduplicated, centre-sorted result.
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
        xMinLim = str2double(efXMin.Value);
        xMaxLim = str2double(efXMax.Value);
        if ~isnan(xMinLim) && ~isnan(xMaxLim) && xMinLim < xMaxLim
            inView = xv >= xMinLim & xv <= xMaxLim;
            if sum(inView) >= 5
                xv = xv(inView);
                yv = yv(inView);
            end
        end

        xSpan = diff([min(xv), max(xv)]);

        PEAK_SEP_TOL_FRAC   = 0.005;  % seeds closer than this are merged
        PEAK_LOCAL_WIN_FRAC = 0.02;   % ±fraction of x-span for missed-seed search

        % ── User-configurable minimum separation ─────────────────────────
        userMinSep = efMinSep.Value;

        % ── Save existing manual seeds BEFORE rebuilding the list ─────────
        if ~isempty(ds.peaks) && isfield(ds.peaks, 'status')
            isManual     = strcmp({ds.peaks.status}, 'manual');
            manualSeeds  = ds.peaks(isManual);
        else
            manualSeeds  = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
                                  'xRange',{},'status',{});
        end

        % ── SNIP-based peak detection ───────────────────────────────────
        [merged, bgEst] = utilities.findPeaksRobust(xv(:), yv(:), ...
            'SNRThreshold',  5, ...
            'MinSeparation', guiTernary(userMinSep > 0, userMinSep, 0), ...
            'MaxPeaks',      50, ...
            'MaxWindowDeg',  2.0);

        % Store background estimate for overlay plotting
        ds.snipBackground = struct('x', xv(:), 'bg', bgEst(:));

        % ── Pass 2: force local search at missed manual seeds ────────────
        minSep  = xSpan * PEAK_SEP_TOL_FRAC;
        halfWin = xSpan * PEAK_LOCAL_WIN_FRAC;

        for si = 1:numel(manualSeeds)
            seedX = manualSeeds(si).center;
            if ~isempty(merged)
                if any(abs([merged.center] - seedX) <= minSep)
                    continue;
                end
            end

            inWin = xv >= (seedX - halfWin) & xv <= (seedX + halfWin);
            if ~any(inWin)
                merged(end+1) = manualSeeds(si);  %#ok<AGROW>
                continue;
            end
            xWin = xv(inWin);  yWin = yv(inWin);

            try
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
            newPk.area   = NaN;
            newPk.xRange = [];
            newPk.status = 'manual';
            newPk.bg     = NaN;
            newPk.model  = '';
            newPk.eta    = NaN;
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

        % Search within 3 % of x-axis range of click for the NEAREST local
        % maximum (not the global max — which misses the smaller of two close peaks).
        xWin  = diff(ax.XLim) * 0.03;
        inWin = xv >= (xClick - xWin) & xv <= (xClick + xWin) & ~isnan(yv);
        if any(inWin)
            xInWin = xv(inWin);
            yInWin = yv(inWin);
            % Find all local maxima in the window
            nW = numel(yInWin);
            if nW >= 3
                isLMax = false(nW,1);
                isLMax(2:end-1) = yInWin(2:end-1) > yInWin(1:end-2) & ...
                                  yInWin(2:end-1) > yInWin(3:end);
                if any(isLMax)
                    % Pick the local max nearest to the click x-position
                    lmX = xInWin(isLMax);
                    lmH = yInWin(isLMax);
                    [~, nearI] = min(abs(lmX - xClick));
                    pkX = lmX(nearI);
                    pkH = lmH(nearI);
                else
                    % No local max — fall back to nearest point
                    [~, nearI] = min(abs(xInWin - xClick));
                    pkX = xInWin(nearI);
                    pkH = yInWin(nearI);
                end
            else
                [~, nearI] = min(abs(xInWin - xClick));
                pkX = xInWin(nearI);
                pkH = yInWin(nearI);
            end
        else
            pkX = xClick;
            pkH = yClick;
        end

        newPk.center = pkX;
        newPk.fwhm   = NaN;
        newPk.height = pkH;
        newPk.area   = NaN;
        newPk.xRange = [];
        newPk.status = 'manual';
        newPk.bg     = NaN;
        newPk.model  = '';
        newPk.eta    = NaN;
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

        isPV   = strcmp(ddFitModel.Value, 'Pseudo-Voigt');
        isSPVII = strcmp(ddFitModel.Value, 'Split Pearson VII');
        switch ddFitModel.Value
            case 'Gaussian'
                modelFun = @(p,x) p(1) .* exp(-4.*log(2).*((x-p(2))./p(3)).^2) + p(4);
            case 'Pseudo-Voigt'
                % p = [H, x0, fwhm, bg, eta]  eta in [0,1] (Lorentzian fraction)
                modelFun = @(p,x) p(1) .* (p(5) ./ (1 + 4.*((x-p(2))./p(3)).^2) + ...
                                  (1-p(5)) .* exp(-4.*log(2).*((x-p(2))./p(3)).^2)) + p(4);
            case 'Split Pearson VII'
                % p = [H, center, wL, wR, mL, mR, bg]
                modelFun = @(p,x) utilities.splitPearsonVII(x, p);
            otherwise  % 'Lorentzian' (default)
                modelFun = @(p,x) p(1) ./ (1 + 4.*((x - p(2))./p(3)).^2) + p(4);
        end
        opts = optimset('Display','off','MaxIter',8000,'TolX',1e-10,'TolFun',1e-14);

        nFailed = 0;
        for pki = 1:numel(ds.peaks)
            pk = ds.peaks(pki);

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
            bg0   = min(yFit);
            % Use the DETECTED peak center, not max of window — max can snap
            % to a neighboring larger peak that partially overlaps the window.
            x0_0  = pk.center;
            % Interpolate y at the detected center for height estimate
            H0    = interp1(xFit, yFit, x0_0, 'linear', max(yFit)) - bg0;
            if H0 <= 0, H0 = max(yFit) - bg0; end   % fallback if interp fails
            % Use detected FWHM as initial guess when available; otherwise
            % fall back to 30% of window width (or 2× point spacing minimum)
            dx    = xFit(2) - xFit(1);
            if ~isnan(pk.fwhm) && pk.fwhm > 0
                fw0 = pk.fwhm;
            else
                fw0 = max(diff([min(xFit), max(xFit)]) * FIT_INIT_WIDTH_FRAC, dx*2);
            end

            if isSPVII
                % Split Pearson VII: p = [H, center, wL, wR, mL, mR, bg]
                hw0 = fw0 / 2;
                p0 = [H0, x0_0, hw0, hw0, 1.5, 1.5, bg0];
            else
                p0 = [H0, x0_0, fw0, bg0];
                if isPV, p0(end+1) = 0.5; end  %#ok<AGROW> % initial eta guess: 50% Lorentzian
            end
            objFun = @(p) sum((modelFun(p, xFit) - yFit).^2);
            try
                pFit = fminsearch(objFun, p0, opts);
                if isSPVII
                    fwhmFit = abs(pFit(3)) + abs(pFit(4));  % wL + wR
                    etaFit  = NaN;
                else
                    fwhmFit = abs(pFit(3));
                    etaFit  = guiTernary(isPV, max(0, min(1, pFit(5))), NaN);
                end
                % Accept only if center is inside fit window and fwhm is sane
                if pFit(2) >= xLo && pFit(2) <= xHi && ...
                   fwhmFit > 0     && fwhmFit < xSpan * FIT_MAX_FWHM_FRAC
                    ds.peaks(pki).center = pFit(2);
                    ds.peaks(pki).fwhm   = fwhmFit;
                    ds.peaks(pki).height = pFit(1);
                    ds.peaks(pki).bg     = guiTernary(isSPVII, pFit(7), pFit(4));
                    ds.peaks(pki).eta    = etaFit;
                    ds.peaks(pki).status = 'fitted';
                    ds.peaks(pki).model  = ddFitModel.Value;
                    if isSPVII
                        ds.peaks(pki).asymmetry = abs(pFit(3)) / abs(pFit(4));  % wL/wR ratio
                        ds.peaks(pki).fitParams = pFit;  % store full [H,c,wL,wR,mL,mR,bg]
                    end
                    % Compute area analytically (or numerically for Split Pearson VII)
                    switch ddFitModel.Value
                        case 'Gaussian'
                            fittedArea = pFit(1) * fwhmFit * sqrt(pi / log(2)) / 2;
                        case 'Pseudo-Voigt'
                            % Area = H*fwhm*(eta*pi/2 + (1-eta)*sqrt(pi)/(2*sqrt(ln2)))
                            A_L = pi / 2;
                            A_G = sqrt(pi) / (2 * sqrt(log(2)));
                            fittedArea = pFit(1) * fwhmFit * (etaFit * A_L + (1-etaFit) * A_G);
                        case 'Split Pearson VII'
                            % No closed-form integral — use numerical integration
                            xDense = linspace(xLo, xHi, 500)';
                            yDense = utilities.splitPearsonVII(xDense, pFit) - pFit(7);
                            fittedArea = trapz(xDense, yDense);
                        otherwise  % Lorentzian
                            fittedArea = pFit(1) * fwhmFit * pi / 2;
                    end
                    ds.peaks(pki).area = fittedArea;
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

    function onFitAllPeaks(~,~)
    %ONFITALLPEAKS  Fit all listed peaks simultaneously as a single multi-peak model.
    %  Builds a composite model (sum of N Lorentzian or Gaussian peaks + a
    %  shared linear background) and optimises all parameters together with
    %  fminsearch.  Requires ≥ 2 peaks.
    %
    %  Parameter vector layout (nP peaks):
    %    p = [H1, x0_1, fwhm1, H2, x0_2, fwhm2, …, HnP, x0_nP, fwhmnP, m, b]
    %  where m, b are the shared linear background slope and intercept.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};
        if numel(ds.peaks) < 2
            uialert(fig, ...
                'Need at least 2 peaks for a global fit.  Use "Fit Peaks" for a single peak.', ...
                'Global Fit: need ≥2 peaks');
            return;
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
        if isempty(yIdx)
            uialert(fig,'Could not find Y channel.','Global Fit'); return;
        end
        yv = d.values(:, yIdx);

        valid = ~isnan(xv) & ~isnan(yv);
        xv = xv(valid);  yv = yv(valid);
        nP = numel(ds.peaks);

        % Build composite model.
        % Lorentzian/Gaussian: [H1,x0_1,fwhm1, H2,..., HnP,x0_nP,fwhmNP, m, b]  (3 params/peak)
        % Pseudo-Voigt:        [H1,x0_1,fwhm1,eta1, ...,                  m, b]  (4 params/peak)
        isPVGlobal = strcmp(ddFitModel.Value,'Pseudo-Voigt');
        if isPVGlobal
            modelFun = @(p,x) evalMultiPeakPV(p, x, nP);
        else
            isGauss  = strcmp(ddFitModel.Value,'Gaussian');
            modelFun = @(p,x) evalMultiPeak(p, x, nP, isGauss);
        end

        % Build initial parameter vector from current peak seeds
        xSpan   = diff([min(xv), max(xv)]);
        bgEst   = min(yv);
        nPPeak  = guiTernary(isPVGlobal, 4, 3);
        p0      = zeros(1, nP*nPPeak + 2);
        for k = 1:nP
            pk    = ds.peaks(k);
            % pk.height is the absolute y-value; subtract background for model amplitude
            H0    = guiTernary(~isnan(pk.height) && pk.height > bgEst, pk.height - bgEst, max(yv) - bgEst);
            fwhm0 = guiTernary(~isnan(pk.fwhm)  && pk.fwhm  > 0, pk.fwhm,  xSpan * 0.02);
            p0((k-1)*nPPeak+1) = H0;
            p0((k-1)*nPPeak+2) = pk.center;
            p0((k-1)*nPPeak+3) = fwhm0;
            if isPVGlobal
                eta0 = guiTernary(isfield(pk,'eta') && ~isempty(pk.eta) && ~isnan(pk.eta), pk.eta, 0.5);
                p0((k-1)*nPPeak+4) = eta0;
            end
        end
        p0(end-1) = 0;       % shared linear BG slope
        p0(end)   = min(yv); % shared linear BG intercept

        % ── Build constrained objective function ─────────────────────────
        % Add a soft penalty when a peak center drifts more than 3 × its
        % initial FWHM from its seed position.  This prevents peaks from
        % swapping positions or collapsing onto each other during the
        % unconstrained fminsearch optimization.
        centerIdx = zeros(1, nP);
        centerBnd = zeros(1, nP);   % allowed half-window for each peak center
        for k = 1:nP
            centerIdx(k) = (k-1)*nPPeak + 2;
            fwInit       = abs(p0((k-1)*nPPeak + 3));
            centerBnd(k) = max(3 * fwInit, xSpan * 0.02);
        end
        seedCenters = p0(centerIdx);
        penaltyWt   = sum((yv - mean(yv)).^2) * 10;  % scale penalty to data magnitude

        objFun = @(p) sum((modelFun(p, xv) - yv).^2) + ...
            penaltyWt * sum(max(0, ((p(centerIdx) - seedCenters) ./ centerBnd).^2 - 1));

        opts   = optimset('Display','off','MaxIter',20000,'TolX',1e-10,'TolFun',1e-14);
        try
            pFit = fminsearch(objFun, p0, opts);
        catch
            uialert(fig,'Global fit optimisation failed.','Fit All Peaks');
            return;
        end

        % Extract fitted parameters and update ds.peaks
        mFit = pFit(end-1);  bFit = pFit(end);
        A_L  = pi / 2;
        A_G  = sqrt(pi) / (2 * sqrt(log(2)));
        for k = 1:nP
            Hk    = pFit((k-1)*nPPeak+1);
            x0k   = pFit((k-1)*nPPeak+2);
            fwhmk = abs(pFit((k-1)*nPPeak+3));
            etak  = guiTernary(isPVGlobal, max(0, min(1, pFit((k-1)*nPPeak+4))), NaN);
            if fwhmk > 0 && fwhmk < xSpan * 0.8
                ds.peaks(k).center = x0k;
                ds.peaks(k).fwhm   = fwhmk;
                ds.peaks(k).height = Hk;
                ds.peaks(k).bg     = mFit * x0k + bFit;
                ds.peaks(k).eta    = etak;
                ds.peaks(k).status = 'fitted(global)';
                ds.peaks(k).model  = ddFitModel.Value;
                switch ddFitModel.Value
                    case 'Gaussian'
                        ds.peaks(k).area = Hk * fwhmk * sqrt(pi / log(2)) / 2;
                    case 'Pseudo-Voigt'
                        ds.peaks(k).area = Hk * fwhmk * (etak * A_L + (1-etak) * A_G);
                    otherwise  % Lorentzian
                        ds.peaks(k).area = Hk * fwhmk * pi / 2;
                end
            end
        end

        appData.datasets{appData.activeIdx} = ds;
        refreshPeakTable();
        onPlot([],[]);
    end

    % ── Peak list management ─────────────────────────────────────────────

    function onClearPeaks(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        cancelInteractions();
        ds       = appData.datasets{appData.activeIdx};
        ds.peaks = struct('center',{},'fwhm',{},'height',{},'area',{},'xRange',{},'status',{},'bg',{},'model',{},'eta',{});
        appData.datasets{appData.activeIdx} = ds;
        appData.selectedPeakIdx = 0;
        refreshPeakTable();
        onPlot([],[]);
    end

    function onRemoveSelectedPeak(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        pki = appData.selectedPeakIdx;
        if pki < 1, return; end
        cancelInteractions();
        ds = appData.datasets{appData.activeIdx};
        if pki > numel(ds.peaks), return; end
        ds.peaks(pki) = [];
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
    %   Columns: #, Center(°), d(Å), Size(nm), FWHM(°), Height, Area, η, Status
        if isempty(appData.datasets) || appData.activeIdx < 1
            peakTable.Data = {}; return;
        end
        ds  = appData.datasets{appData.activeIdx};
        n   = numel(ds.peaks);
        if n == 0
            peakTable.Data = {}; return;
        end
        wl_A      = extractWavelength_A(ds);   % NaN if no wavelength available
        K         = appData.kFactor;
        inst_rad  = appData.instBroadening_deg * (pi / 180);
        DEG2RAD   = pi / 180;
        tbl       = cell(n, 9);
        for pIdx = 1:n
            pk          = ds.peaks(pIdx);
            tbl{pIdx,1} = pIdx;
            tbl{pIdx,2} = sprintf('%.4f', pk.center);
            % d-spacing via Bragg: d = λ / (2·sin(θ)), θ = 2θ/2 in radians
            canCalc = ~isnan(wl_A) && ~isnan(pk.center) && pk.center > 0;
            if canCalc
                theta_rad   = (pk.center / 2) * DEG2RAD;
                d_A         = wl_A / (2 * sin(theta_rad));
                tbl{pIdx,3} = sprintf('%.4f', d_A);
            else
                tbl{pIdx,3} = '—';
            end
            % Scherrer size: D = Kλ / (β·cosθ), β corrected for instrument broadening
            hasFWHM = ~isnan(pk.fwhm) && pk.fwhm > 0;
            if canCalc && hasFWHM
                beta_meas = pk.fwhm * DEG2RAD;
                beta_sq   = beta_meas^2 - inst_rad^2;
                if beta_sq > 0
                    beta_corr   = sqrt(beta_sq);
                    size_nm     = (K * wl_A * 0.1) / (beta_corr * cos(theta_rad));
                    tbl{pIdx,4} = sprintf('%.1f', size_nm);
                else
                    tbl{pIdx,4} = '—';   % inst broadening >= measured (unphysical)
                end
            else
                tbl{pIdx,4} = '—';
            end
            tbl{pIdx,5} = guiTernary(~hasFWHM, '—', sprintf('%.4f', pk.fwhm));
            tbl{pIdx,6} = sprintf('%.4g',  pk.height);
            tbl{pIdx,7} = guiTernary(isnan(pk.area) || pk.area <= 0, '—', sprintf('%.4g', pk.area));
            hasEta      = isfield(pk,'eta') && ~isempty(pk.eta) && ~isnan(pk.eta);
            tbl{pIdx,8} = guiTernary(hasEta, sprintf('%.2f', pk.eta), '—');
            tbl{pIdx,9} = pk.status;
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
            fprintf(fid, 'Peak,Center_deg,d_Angstrom,Size_nm,FWHM_deg,Height,Area,Status\n');
            wl_A      = extractWavelength_A(ds);
            K         = appData.kFactor;
            inst_rad  = appData.instBroadening_deg * (pi / 180);
            DEG2RAD   = pi / 180;
            for pki = 1:numel(ds.peaks)
                pk      = ds.peaks(pki);
                fwhmStr = guiTernary(isnan(pk.fwhm) || pk.fwhm <= 0, '', sprintf('%.6f', pk.fwhm));
                areaStr = guiTernary(isnan(pk.area) || pk.area <= 0, '', sprintf('%.6g', pk.area));
                canCalc = ~isnan(wl_A) && ~isnan(pk.center) && pk.center > 0;
                if canCalc
                    theta_rad = (pk.center / 2) * DEG2RAD;
                    dStr      = sprintf('%.6f', wl_A / (2 * sin(theta_rad)));
                else
                    dStr = '';
                end
                if canCalc && ~isnan(pk.fwhm) && pk.fwhm > 0
                    beta_sq = (pk.fwhm * DEG2RAD)^2 - inst_rad^2;
                    if beta_sq > 0
                        sizeStr = sprintf('%.2f', (K * wl_A * 0.1) / (sqrt(beta_sq) * cos(theta_rad)));
                    else
                        sizeStr = '';
                    end
                else
                    sizeStr = '';
                end
                fprintf(fid, '%d,%.6f,%s,%s,%s,%.6g,%s,%s\n', ...
                    pki, pk.center, dStr, sizeStr, fwhmStr, pk.height, areaStr, pk.status);
            end
            fclose(fid);
            uialert(fig, sprintf('Saved:\n%s', fp), 'Peak Summary Exported');
        catch ME
            if fid >= 0, fclose(fid); end
            logGUIError('Save error', ME.message, ME);
            uialert(fig, ME.message, 'Save error');
        end
    end

    function onExportPeakXLSX(~,~)
    %ONEXPORTPEAKXLSX  Export peak data from all datasets with peaks to Excel.
    %  One sheet per dataset; columns: Peak#, Center, FWHM, Height, Area, Status.
    %  Datasets with no peaks are silently skipped.
        if isempty(appData.datasets)
            uialert(fig,'Load files first.','No data'); return;
        end

        % Check that at least one dataset has peaks
        hasPeaks = false;
        for chk = 1:numel(appData.datasets)
            if ~isempty(appData.datasets{chk}.peaks)
                hasPeaks = true;  break;
            end
        end
        if ~hasPeaks
            uialert(fig, ...
                'No peaks found in any dataset.  Find or add peaks first.', ...
                'No peaks to export');
            return;
        end

        % Suggest save path based on first dataset
        ds1 = appData.datasets{1};
        [dPath, dName, ~] = fileparts(ds1.filepath);
        defPath = fullfile(dPath, [dName, '_peaks.xlsx']);

        [fname, fpath] = uiputfile({'*.xlsx','Excel Workbook (*.xlsx)'}, ...
            'Export peaks to Excel...', defPath);
        if isequal(fname, 0), return; end
        outPath = fullfile(fpath, fname);

        % Delete existing file so writecell starts fresh
        if isfile(outPath)
            try
                delete(outPath);
            catch
            end
        end

        nWritten = 0;
        errMsgs  = {};
        for di = 1:numel(appData.datasets)
            ds = appData.datasets{di};
            if isempty(ds.peaks), continue; end

            % Build sheet name from display name (Excel limits: 31 chars, no special chars)
            if isfield(ds,'legendName') && ~isempty(ds.legendName)
                rawName = ds.legendName;
            elseif isfield(ds,'displayName') && ~isempty(ds.displayName)
                rawName = ds.displayName;
            else
                [~, fn, ~] = fileparts(ds.filepath);
                rawName = fn;
            end
            % Sanitise: remove Excel-illegal characters, truncate to 31 chars
            sheetName = regexprep(rawName, '[:\\/?*\[\]]', '_');
            if numel(sheetName) > 28
                sheetName = [sheetName(1:25), sprintf('_%02d', di)];
            end
            if isempty(strtrim(sheetName))
                sheetName = sprintf('DS_%02d', di);
            end

            % Build cell array: header + data rows
            nPk      = numel(ds.peaks);
            wl_A     = extractWavelength_A(ds);
            K        = appData.kFactor;
            inst_rad = appData.instBroadening_deg * (pi / 180);
            DEG2RAD  = pi / 180;
            C   = cell(nPk + 1, 8);
            C(1,:) = {'Peak #', 'Center (deg)', 'd (A)', 'Size (nm)', 'FWHM (deg)', 'Height', 'Area', 'Status'};
            for pki = 1:nPk
                pk        = ds.peaks(pki);
                C{pki+1,1} = pki;
                C{pki+1,2} = pk.center;
                canCalc   = ~isnan(wl_A) && ~isnan(pk.center) && pk.center > 0;
                if canCalc
                    theta_rad  = (pk.center / 2) * DEG2RAD;
                    C{pki+1,3}  = wl_A / (2 * sin(theta_rad));
                else
                    C{pki+1,3} = '';
                end
                if canCalc && ~isnan(pk.fwhm) && pk.fwhm > 0
                    beta_sq = (pk.fwhm * DEG2RAD)^2 - inst_rad^2;
                    C{pki+1,4} = guiTernary(beta_sq > 0, ...
                        (K * wl_A * 0.1) / (sqrt(max(beta_sq,0)) * cos(theta_rad)), '');
                else
                    C{pki+1,4} = '';
                end
                C{pki+1,5} = guiTernary(isnan(pk.fwhm) || pk.fwhm <= 0, '', pk.fwhm);
                C{pki+1,6} = pk.height;
                C{pki+1,7} = guiTernary(isnan(pk.area) || pk.area <= 0, '', pk.area);
                C{pki+1,8} = pk.status;
            end

            try
                writecell(C, outPath, 'Sheet', sheetName);
                nWritten = nWritten + 1;
            catch ME
                errMsgs{end+1} = sprintf('%s: %s', sheetName, ME.message); %#ok<AGROW>
            end
        end

        if nWritten == 0
            uialert(fig, 'No peak data was written — check file permissions.', ...
                'Export Failed');
        elseif isempty(errMsgs)
            uialert(fig, sprintf('Exported %d dataset(s) to:\n%s', nWritten, outPath), ...
                'Peak Export Complete');
        else
            uialert(fig, sprintf('Exported %d dataset(s); %d error(s):\n%s', ...
                nWritten, numel(errMsgs), strjoin(errMsgs,'\n')), ...
                'Peak Export Partial');
        end
    end

    % ── Fit curve visibility / color ─────────────────────────────────────

    function onWavelengthChanged(src, ~)
    %ONWAVELENGTHCHANGED  User edited the wavelength override field.
    %   Saves the override to the active dataset and refreshes d-spacing column.
    %   Also syncs the source dropdown to 'Custom' when value doesn't match a preset.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds = appData.datasets{appData.activeIdx};
        v  = src.Value;
        ds.wavelengthOverride_A = guiTernary(isnan(v) || v <= 0, NaN, v);
        appData.datasets{appData.activeIdx} = ds;
        % Sync dropdown: if value matches a preset, select it; else set Custom
        matchIdx = find(abs([XRAY_SOURCES{:,2}] - v) < 1e-4, 1);
        if ~isempty(matchIdx)
            ddXraySource.Value = XRAY_SOURCES{matchIdx, 1};
        else
            ddXraySource.Value = 'Custom';
        end
        refreshPeakTable();
    end

    function onXraySourceChanged(src, ~)
    %ONXRAYSOURCECHANGED  User selected an X-ray source from the dropdown.
    %   Auto-fills the wavelength edit field and propagates to the dataset.
        selectedName = src.Value;
        matchIdx = strcmp(XRAY_SOURCES(:,1), selectedName);
        wl = XRAY_SOURCES{matchIdx, 2};
        if ~isnan(wl)
            efWavelength.Value = wl;
            % Propagate to dataset
            if ~isempty(appData.datasets) && appData.activeIdx >= 1
                ds = appData.datasets{appData.activeIdx};
                ds.wavelengthOverride_A = wl;
                appData.datasets{appData.activeIdx} = ds;
                refreshPeakTable();
            end
        end
        % 'Custom' selected: leave efWavelength unchanged for manual entry
    end

    function onKFactorChanged(src, ~)
    %ONKFACTORCHANGED  User edited the Scherrer K factor field.
    %   Saves value to appData and refreshes the Size (nm) column.
        v = src.Value;
        if ~isnan(v) && v > 0
            appData.kFactor = v;
        end
        refreshPeakTable();
    end

    function onInstBroadeningChanged(src, ~)
    %ONINSTBROADENINGCHANGED  User edited the instrument broadening field.
    %   Saves value to appData and refreshes the Size (nm) column.
        v = src.Value;
        appData.instBroadening_deg = guiTernary(isnan(v) || v < 0, 0, v);
        refreshPeakTable();
    end

    % ════════════════════════════════════════════════════════════════════
    %  2.3  LATTICE PARAMETER REFINEMENT
    % ════════════════════════════════════════════════════════════════════

    function onRefineLattice(~, ~)
    %ONREFINELATTICE  Open a dialog to assign hkl indices and refine lattice parameters.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        ds  = appData.datasets{appData.activeIdx};
        wl_A = extractWavelength_A(ds);
        if isnan(wl_A) || wl_A <= 0
            uialert(fig, ['Wavelength is required for lattice refinement.  ' ...
                          'Enter a value in the ' char(955) ' field or load an XRDML/Bruker file.'], ...
                'No wavelength'); return;
        end
        fitted = ~isempty(ds.peaks) && any(strcmp({ds.peaks.status}, 'fitted') | ...
                                           strcmp({ds.peaks.status}, 'fitted(global)'));
        if ~fitted
            uialert(fig, 'Fit peaks first (at least one fitted peak required).', ...
                'No fitted peaks'); return;
        end

        % ── Collect fitted peaks ────────────────────────────────────────
        DEG2RAD = pi / 180;
        fittedIdx = find(strcmp({ds.peaks.status}, 'fitted') | ...
                         strcmp({ds.peaks.status}, 'fitted(global)'));
        nPk = numel(fittedIdx);
        centers  = [ds.peaks(fittedIdx).center];
        theta    = centers / 2 * DEG2RAD;
        d_obs    = wl_A ./ (2 * sin(theta));

        % ── Create dialog figure ────────────────────────────────────────
        dlgFig = uifigure('Name', 'Lattice Parameter Refinement', ...
            'Position', [200 200 520 480], 'Resize', 'on');
        dlgGL = uigridlayout(dlgFig, [5 1], ...
            'RowHeight', {24, '1x', 28, 28, '0.6x'}, ...
            'Padding', [10 10 10 10], 'RowSpacing', 8);

        % Row 1: Crystal system selector
        sysGL = uigridlayout(dlgGL, [1 2], 'ColumnWidth', {120, '1x'}, ...
            'Padding', [0 0 0 0]);
        sysGL.Layout.Row = 1;
        uilabel(sysGL, 'Text', 'Crystal system:', 'FontWeight', 'bold');
        ddSystem = uidropdown(sysGL, ...
            'Items', {'Cubic', 'Tetragonal', 'Hexagonal', 'Orthorhombic'}, ...
            'Value', 'Cubic');

        % Row 2: hkl assignment table
        tblData = cell(nPk, 6);
        for i = 1:nPk
            tblData{i,1} = fittedIdx(i);
            tblData{i,2} = sprintf('%.4f', centers(i));
            tblData{i,3} = sprintf('%.4f', d_obs(i));
            tblData{i,4} = 0;   % h
            tblData{i,5} = 0;   % k
            tblData{i,6} = 0;   % l
        end
        hklTable = uitable(dlgGL, ...
            'ColumnName', {'Peak#', ['2' char(952) ' (' char(176) ')'], ...
                           'd (Å)', 'h', 'k', 'l'}, ...
            'ColumnWidth', {50, 75, 75, 55, 55, 55}, ...
            'ColumnEditable', [false false false true true true], ...
            'ColumnFormat', {'numeric','char','char','numeric','numeric','numeric'}, ...
            'Data', tblData, 'RowName', {});
        hklTable.Layout.Row = 2;

        % Row 3: Refine button
        btnRefine = uibutton(dlgGL, 'Text', 'Refine Lattice Parameters', ...
            'ButtonPushedFcn', @doRefine, ...
            'BackgroundColor', [0.15 0.50 0.30], 'FontColor', [1 1 1]);
        btnRefine.Layout.Row = 3;

        % Row 4: Nelson-Riley plot button
        btnNR = uibutton(dlgGL, 'Text', 'Nelson-Riley Plot (cubic only)', ...
            'ButtonPushedFcn', @doNelsonRiley, 'Enable', 'off');
        btnNR.Layout.Row = 4;

        % Row 5: Results text area
        taResults = uitextarea(dlgGL, 'Value', {'Assign hkl indices and click Refine.'}, ...
            'Editable', false, 'FontName', 'Consolas');
        taResults.Layout.Row = 5;

        % ── Stored refinement results (closure variable) ────────────────
        refinedResult = [];

        function doRefine(~, ~)
        %DOREFINE  Run least-squares lattice parameter refinement.
            tData  = hklTable.Data;
            h_arr  = cell2mat(tData(:,4));
            k_arr  = cell2mat(tData(:,5));
            l_arr  = cell2mat(tData(:,6));
            % Validate: at least one non-zero hkl
            hklSum = abs(h_arr) + abs(k_arr) + abs(l_arr);
            valid  = hklSum > 0;
            if sum(valid) < 1
                taResults.Value = {'Error: assign non-zero hkl to at least one peak.'};
                return;
            end
            hv = h_arr(valid);  kv = k_arr(valid);  lv = l_arr(valid);
            dv = d_obs(valid);
            inv_d2 = (1 ./ dv.^2)';

            sys = ddSystem.Value;
            lines_out = {};
            switch sys
                case 'Cubic'
                    % a = d * sqrt(h^2 + k^2 + l^2) for each peak
                    a_each = dv' .* sqrt(hv.^2 + kv.^2 + lv.^2);
                    a_mean = mean(a_each);
                    a_std  = std(a_each);
                    % Least-squares: 1/d^2 = (h^2+k^2+l^2) / a^2
                    A_mat  = hv.^2 + kv.^2 + lv.^2;
                    inv_a2 = A_mat \ inv_d2;
                    a_ls   = 1 / sqrt(inv_a2);
                    d_calc = a_ls ./ sqrt(hv.^2 + kv.^2 + lv.^2);
                    resid  = dv' - d_calc;
                    lines_out = {
                        sprintf('Crystal system: Cubic')
                        sprintf('Refined a = %.5f %s', a_ls, char(197))
                        sprintf('Mean a   = %.5f %s %s %.5f', a_mean, char(197), char(177), a_std)
                        ''
                        'Per-peak residuals (d_obs - d_calc):'
                    };
                    for ri = 1:numel(dv')
                        lines_out{end+1} = sprintf('  (%d%d%d)  d=%.4f  calc=%.4f  %s=%.4f', ...
                            hv(ri), kv(ri), lv(ri), dv(ri), d_calc(ri), char(916), resid(ri)); %#ok<AGROW>
                    end
                    refinedResult = struct('system','Cubic','a',a_ls,'residuals',resid, ...
                        'hkl',[hv kv lv],'d_obs',dv','d_calc',d_calc, ...
                        'theta_rad',theta(valid)');
                    btnNR.Enable = 'on';

                case 'Tetragonal'
                    % 1/d^2 = (h^2+k^2)/a^2 + l^2/c^2
                    A_mat = [hv.^2+kv.^2, lv.^2];
                    if size(A_mat,1) < 2
                        taResults.Value = {'Error: tetragonal needs >= 2 peaks with hkl.'};
                        return;
                    end
                    x = A_mat \ inv_d2;
                    a_ref = 1/sqrt(x(1));  c_ref = 1/sqrt(x(2));
                    d_calc = 1 ./ sqrt(A_mat * x);
                    resid  = dv' - d_calc;
                    lines_out = {
                        sprintf('Crystal system: Tetragonal')
                        sprintf('Refined a = %.5f %s', a_ref, char(197))
                        sprintf('Refined c = %.5f %s', c_ref, char(197))
                        sprintf('c/a = %.5f', c_ref/a_ref)
                        ''
                        'Per-peak residuals:'
                    };
                    for ri = 1:numel(dv')
                        lines_out{end+1} = sprintf('  (%d%d%d)  d=%.4f  calc=%.4f  %s=%.4f', ...
                            hv(ri), kv(ri), lv(ri), dv(ri), d_calc(ri), char(916), resid(ri)); %#ok<AGROW>
                    end
                    refinedResult = struct('system','Tetragonal','a',a_ref,'c',c_ref, ...
                        'residuals',resid,'hkl',[hv kv lv],'d_obs',dv','d_calc',d_calc);
                    btnNR.Enable = 'off';

                case 'Hexagonal'
                    % 1/d^2 = (4/3)(h^2+hk+k^2)/a^2 + l^2/c^2
                    A_mat = [(4/3)*(hv.^2 + hv.*kv + kv.^2), lv.^2];
                    if size(A_mat,1) < 2
                        taResults.Value = {'Error: hexagonal needs >= 2 peaks with hkl.'};
                        return;
                    end
                    x = A_mat \ inv_d2;
                    a_ref = 1/sqrt(x(1));  c_ref = 1/sqrt(x(2));
                    d_calc = 1 ./ sqrt(A_mat * x);
                    resid  = dv' - d_calc;
                    lines_out = {
                        sprintf('Crystal system: Hexagonal')
                        sprintf('Refined a = %.5f %s', a_ref, char(197))
                        sprintf('Refined c = %.5f %s', c_ref, char(197))
                        sprintf('c/a = %.5f', c_ref/a_ref)
                        ''
                        'Per-peak residuals:'
                    };
                    for ri = 1:numel(dv')
                        lines_out{end+1} = sprintf('  (%d%d%d)  d=%.4f  calc=%.4f  %s=%.4f', ...
                            hv(ri), kv(ri), lv(ri), dv(ri), d_calc(ri), char(916), resid(ri)); %#ok<AGROW>
                    end
                    refinedResult = struct('system','Hexagonal','a',a_ref,'c',c_ref, ...
                        'residuals',resid,'hkl',[hv kv lv],'d_obs',dv','d_calc',d_calc);
                    btnNR.Enable = 'off';

                case 'Orthorhombic'
                    % 1/d^2 = h^2/a^2 + k^2/b^2 + l^2/c^2
                    A_mat = [hv.^2, kv.^2, lv.^2];
                    if size(A_mat,1) < 3
                        taResults.Value = {'Error: orthorhombic needs >= 3 peaks with hkl.'};
                        return;
                    end
                    x = A_mat \ inv_d2;
                    a_ref = 1/sqrt(x(1));  b_ref = 1/sqrt(x(2));  c_ref = 1/sqrt(x(3));
                    d_calc = 1 ./ sqrt(A_mat * x);
                    resid  = dv' - d_calc;
                    lines_out = {
                        sprintf('Crystal system: Orthorhombic')
                        sprintf('Refined a = %.5f %s', a_ref, char(197))
                        sprintf('Refined b = %.5f %s', b_ref, char(197))
                        sprintf('Refined c = %.5f %s', c_ref, char(197))
                        ''
                        'Per-peak residuals:'
                    };
                    for ri = 1:numel(dv')
                        lines_out{end+1} = sprintf('  (%d%d%d)  d=%.4f  calc=%.4f  %s=%.4f', ...
                            hv(ri), kv(ri), lv(ri), dv(ri), d_calc(ri), char(916), resid(ri)); %#ok<AGROW>
                    end
                    refinedResult = struct('system','Orthorhombic','a',a_ref,'b',b_ref,'c',c_ref, ...
                        'residuals',resid,'hkl',[hv kv lv],'d_obs',dv','d_calc',d_calc);
                    btnNR.Enable = 'off';
            end

            rms = sqrt(mean(resid.^2));
            lines_out{end+1} = '';
            lines_out{end+1} = sprintf('RMS residual = %.6f %s', rms, char(197));
            taResults.Value = lines_out;

            % Persist to dataset
            ds2 = appData.datasets{appData.activeIdx};
            ds2.latticeParams = refinedResult;
            appData.datasets{appData.activeIdx} = ds2;
        end

        function doNelsonRiley(~, ~)
        %DONELSONRILEY  Nelson-Riley extrapolation plot for cubic systems.
        %   Plots a_individual vs NR(θ) = cos²θ/sinθ + cos²θ/θ; extrapolates to NR=0.
            if isempty(refinedResult) || ~strcmp(refinedResult.system, 'Cubic')
                return;
            end
            th  = refinedResult.theta_rad;
            hkl = refinedResult.hkl;
            dObs = refinedResult.d_obs;
            % a from each peak
            a_each = dObs .* sqrt(hkl(:,1).^2 + hkl(:,2).^2 + hkl(:,3).^2);
            % Nelson-Riley function
            NR = cos(th).^2 ./ sin(th) + cos(th).^2 ./ th;
            % Linear extrapolation
            p = polyfit(NR, a_each, 1);
            a_extrap = p(2);  % intercept at NR=0
            NR_fit = linspace(0, max(NR)*1.1, 100);
            a_fit  = polyval(p, NR_fit);

            nrFig = figure('Name', 'Nelson-Riley Extrapolation', ...
                'NumberTitle', 'off', 'Position', [300 250 500 380]);
            nrAx = axes(nrFig);
            plot(nrAx, NR, a_each, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.5 0.8]);
            hold(nrAx, 'on');
            plot(nrAx, NR_fit, a_fit, 'r-', 'LineWidth', 1.5);
            plot(nrAx, 0, a_extrap, 'r^', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
            hold(nrAx, 'off');
            xlabel(nrAx, ['cos' char(178) char(952) '/sin' char(952) ' + cos' char(178) char(952) '/' char(952)]);
            ylabel(nrAx, ['a (' char(197) ')']);
            title(nrAx, sprintf('Nelson-Riley:  a_0 = %.5f %s (extrapolated)', a_extrap, char(197)));
            grid(nrAx, 'on');
            box(nrAx, 'on');
            legend(nrAx, 'Per-peak a', 'Linear fit', ...
                sprintf('a_0 = %.5f', a_extrap), 'Location', 'best');

            % Add hkl labels
            for li = 1:numel(NR)
                text(nrAx, NR(li), a_each(li), ...
                    sprintf(' (%d%d%d)', hkl(li,1), hkl(li,2), hkl(li,3)), ...
                    'FontSize', 8);
            end
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  3.1  FILM THICKNESS FROM LAUE FRINGES (FFT)
    % ════════════════════════════════════════════════════════════════════

    function onFFTThickness(~, ~)
    %ONFFTTHICKNESS  Compute film thickness from fringe periodicity via FFT.
    %   Converts intensity data to Q-space, applies FFT, and finds dominant
    %   periodicity corresponding to film thickness.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        ds  = appData.datasets{appData.activeIdx};
        wl_A = extractWavelength_A(ds);
        if isnan(wl_A) || wl_A <= 0
            uialert(fig, ['Wavelength is required for FFT thickness.  ' ...
                          'Enter a value in the ' char(955) ' field.'], ...
                'No wavelength'); return;
        end

        % Get current data (corrected if available)
        d = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        xAll = d.time(:);
        % Use first y-channel (primary intensity)
        yAll = d.values(:,1);

        % Pre-fill range from current axis limits
        xLo = ax.XLim(1);
        xHi = ax.XLim(2);

        % ── Create dialog figure ────────────────────────────────────────
        fftFig = uifigure('Name', 'FFT Film Thickness', ...
            'Position', [250 200 600 500], 'Resize', 'on');
        fftGL = uigridlayout(fftFig, [3 1], ...
            'RowHeight', {60, 28, '1x'}, ...
            'Padding', [10 10 10 10], 'RowSpacing', 8);

        % Row 1: Range controls
        rangeGL = uigridlayout(fftGL, [2 4], ...
            'ColumnWidth', {80, '1x', 80, '1x'}, ...
            'RowHeight', {24, 24}, ...
            'Padding', [0 0 0 0], 'ColumnSpacing', 6, 'RowSpacing', 4);
        rangeGL.Layout.Row = 1;
        uilabel(rangeGL, 'Text', ['2' char(952) ' min (' char(176) '):'], 'FontWeight', 'bold');
        efFFTMin = uieditfield(rangeGL, 'numeric', 'Value', xLo, 'Limits', [-10 180]);
        efFFTMin.Layout.Row = 1; efFFTMin.Layout.Column = 2;
        uilabel(rangeGL, 'Text', ['2' char(952) ' max (' char(176) '):'], 'FontWeight', 'bold');
        efFFTMax = uieditfield(rangeGL, 'numeric', 'Value', xHi, 'Limits', [-10 180]);
        efFFTMax.Layout.Row = 1; efFFTMax.Layout.Column = 4;
        uilabel(rangeGL, 'Text', 'Max t (nm):', 'FontWeight', 'bold');
        efMaxThick = uieditfield(rangeGL, 'numeric', 'Value', 200, 'Limits', [1 10000], ...
            'Tooltip', 'Maximum thickness to display on x-axis (nm)');
        efMaxThick.Layout.Row = 2; efMaxThick.Layout.Column = 2;
        uilabel(rangeGL, 'Text', 'Window:');
        ddWindow = uidropdown(rangeGL, ...
            'Items', {'Hann', 'None', 'Blackman'}, 'Value', 'Hann', ...
            'Tooltip', 'Windowing function applied before FFT');
        ddWindow.Layout.Row = 2; ddWindow.Layout.Column = 4;

        % Row 2: Compute button
        btnCompute = uibutton(fftGL, 'Text', 'Compute FFT', ...
            'ButtonPushedFcn', @doFFT, ...
            'BackgroundColor', [0.55 0.30 0.15], 'FontColor', [1 1 1]);
        btnCompute.Layout.Row = 2;

        % Row 3: Axes for FFT plot
        fftAxPanel = uipanel(fftGL, 'BorderType', 'none');
        fftAxPanel.Layout.Row = 3;
        fftAx = axes(fftAxPanel);

        function doFFT(~, ~)
        %DOFFT  Run the FFT computation and plot results.
            twoThMin = efFFTMin.Value;
            twoThMax = efFFTMax.Value;
            if twoThMin >= twoThMax
                uialert(fftFig, 'Min must be less than Max.', 'Invalid range');
                return;
            end

            % Extract data in selected range
            mask = xAll >= twoThMin & xAll <= twoThMax;
            if sum(mask) < 10
                uialert(fftFig, 'Too few data points in selected range (need >= 10).', 'Insufficient data');
                return;
            end
            twoTh_sel = xAll(mask);
            I_sel     = yAll(mask);

            % Convert 2θ → Q (Å⁻¹)
            Q = (4 * pi / wl_A) * sin(twoTh_sel / 2 * pi / 180);

            % Interpolate to uniform Q grid
            nPts     = numel(Q);
            Q_uniform = linspace(min(Q), max(Q), nPts);
            I_uniform = interp1(Q, I_sel, Q_uniform, 'pchip');

            % Subtract mean (remove DC)
            I_uniform = I_uniform - mean(I_uniform);

            % Apply window function
            N = numel(I_uniform);
            switch ddWindow.Value
                case 'Hann'
                    w = 0.5 * (1 - cos(2*pi*(0:N-1)/(N-1)));
                case 'Blackman'
                    w = 0.42 - 0.5*cos(2*pi*(0:N-1)/(N-1)) + 0.08*cos(4*pi*(0:N-1)/(N-1));
                otherwise
                    w = ones(1, N);
            end
            I_windowed = I_uniform(:)' .* w;

            % FFT with zero-padding for better resolution
            N_fft = 2^nextpow2(4 * N);
            F     = abs(fft(I_windowed, N_fft));
            F     = F(1:N_fft/2);

            % Build thickness axis (Å → nm)
            dQ           = Q_uniform(2) - Q_uniform(1);
            thickness_A  = 2*pi*(0:N_fft/2-1) / (N_fft * dQ);
            thickness_nm = thickness_A / 10;

            % Find dominant peak (skip DC component, bins 1-3)
            searchMin = 4;
            maxT_nm   = efMaxThick.Value;
            searchMax = find(thickness_nm <= maxT_nm, 1, 'last');
            if isempty(searchMax) || searchMax < searchMin + 1
                searchMax = numel(F);
            end
            [peakVal, peakIdx] = max(F(searchMin:searchMax));
            peakIdx = peakIdx + searchMin - 1;
            t_nm    = thickness_nm(peakIdx);

            % Estimate uncertainty from FFT peak width (FWHM of FFT peak)
            halfMax = peakVal / 2;
            leftIdx  = find(F(1:peakIdx) < halfMax, 1, 'last');
            rightIdx = peakIdx + find(F(peakIdx:end) < halfMax, 1, 'first') - 1;
            if ~isempty(leftIdx) && ~isempty(rightIdx)
                fwhm_bins = rightIdx - leftIdx;
                dt_nm = thickness_nm(min(peakIdx + ceil(fwhm_bins/2), numel(thickness_nm))) - ...
                        thickness_nm(max(peakIdx - ceil(fwhm_bins/2), 1));
            else
                dt_nm = NaN;
            end

            % ── Plot ────────────────────────────────────────────────────
            cla(fftAx);
            plot(fftAx, thickness_nm(1:searchMax), F(1:searchMax), '-', ...
                'Color', [0.2 0.4 0.7], 'LineWidth', 1.2);
            hold(fftAx, 'on');
            plot(fftAx, t_nm, peakVal, 'rv', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
            hold(fftAx, 'off');
            xlabel(fftAx, 'Film thickness (nm)');
            ylabel(fftAx, 'FFT magnitude');
            if ~isnan(dt_nm)
                title(fftAx, sprintf('t = %.1f %s %.1f nm', t_nm, char(177), dt_nm/2));
            else
                title(fftAx, sprintf('t = %.1f nm', t_nm));
            end
            grid(fftAx, 'on');
            box(fftAx, 'on');
            xlim(fftAx, [0 maxT_nm]);

            % Persist to dataset
            ds2 = appData.datasets{appData.activeIdx};
            fftResult.thickness_nm = t_nm;
            fftResult.uncertainty_nm = guiTernary(isnan(dt_nm), NaN, dt_nm/2);
            fftResult.wavelength_A = wl_A;
            fftResult.twoTheta_range = [twoThMin twoThMax];
            fftResult.fft_magnitude = F(1:searchMax);
            fftResult.thickness_axis = thickness_nm(1:searchMax);
            ds2.filmThickness = fftResult;
            appData.datasets{appData.activeIdx} = ds2;
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  3.1b  REFLECTIVITY FFT (KIESSIG FRINGES)
    % ════════════════════════════════════════════════════════════════════

    function onReflectivityFFT(~, ~)
    %ONREFLECTIVITYFFT  Compute film thickness from Kiessig fringe periodicity.
    %   Works in Q-space directly (neutron NR data) or converts from 2θ (XRR).
    %   Supports multilayer / superlattice structures by detecting multiple
    %   FFT peaks (harmonics + independent layer thicknesses).
    %   Preprocessing: log(R), R×Q⁴, log(R×Q⁴), or raw R.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};

        % Determine if data is already in Q-space (neutron) or 2θ-space (XRR)
        isNeutronDS = isfield(ds, 'parserName') && isNeutronParser(ds.parserName);

        % For XRR (2θ-space), wavelength is required
        wl_A = NaN;
        if ~isNeutronDS
            wl_A = extractWavelength_A(ds);
            if isnan(wl_A) || wl_A <= 0
                uialert(fig, ['Wavelength is required for XRR FFT thickness.  ' ...
                    'Enter a value in the ' char(955) ' field or select an X-ray source.'], ...
                    'No wavelength'); return;
            end
        end

        % Get current corrected data
        d    = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        xAll = d.time(:);      % Q (Å⁻¹) for neutron; 2θ (°) for XRR
        yAll = d.values(:,1);  % R (reflectivity) or counts

        % Pre-fill range from current axis limits
        xLo = ax.XLim(1);
        xHi = ax.XLim(2);

        % ── Dialog figure ────────────────────────────────────────────────
        rfFig = uifigure('Name', 'Reflectivity FFT — Kiessig Thickness', ...
            'Position', [200 150 780 640], 'Resize', 'on');
        rfGL = uigridlayout(rfFig, [4 1], ...
            'RowHeight', {80, 28, '2x', '1x'}, ...
            'Padding', [10 10 10 10], 'RowSpacing', 6);

        % ── Row 1: Controls ──────────────────────────────────────────────
        ctrlGL = uigridlayout(rfGL, [3 6], ...
            'ColumnWidth', {80, '1x', 80, '1x', 90, '1x'}, ...
            'RowHeight', {24, 24, 24}, ...
            'Padding', [0 0 0 0], 'ColumnSpacing', 6, 'RowSpacing', 4);
        ctrlGL.Layout.Row = 1;

        if isNeutronDS
            xLabel = ['Q min (' char(197) char(8315) char(185) '):'];
            xMaxLabel = ['Q max (' char(197) char(8315) char(185) '):'];
        else
            xLabel = ['2' char(952) ' min (' char(176) '):'];
            xMaxLabel = ['2' char(952) ' max (' char(176) '):'];
        end
        lblRFXMin = uilabel(ctrlGL, 'Text', xLabel, 'FontWeight', 'bold');
        lblRFXMin.Layout.Row = 1; lblRFXMin.Layout.Column = 1;
        efRFMin = uieditfield(ctrlGL, 'numeric', 'Value', max(0, xLo), 'Limits', [-10 180]);
        efRFMin.Layout.Row = 1; efRFMin.Layout.Column = 2;
        lblRFXMax = uilabel(ctrlGL, 'Text', xMaxLabel, 'FontWeight', 'bold');
        lblRFXMax.Layout.Row = 1; lblRFXMax.Layout.Column = 3;
        efRFMax = uieditfield(ctrlGL, 'numeric', 'Value', xHi, 'Limits', [-10 180]);
        efRFMax.Layout.Row = 1; efRFMax.Layout.Column = 4;
        lblRFMaxT = uilabel(ctrlGL, 'Text', 'Max t (nm):', 'FontWeight', 'bold');
        lblRFMaxT.Layout.Row = 1; lblRFMaxT.Layout.Column = 5;
        efRFMaxThick = uieditfield(ctrlGL, 'numeric', 'Value', 500, 'Limits', [1 100000], ...
            'Tooltip', 'Maximum thickness to show on x-axis (nm)');
        efRFMaxThick.Layout.Row = 1; efRFMaxThick.Layout.Column = 6;

        lblRFWin = uilabel(ctrlGL, 'Text', 'Window:', 'FontWeight', 'bold');
        lblRFWin.Layout.Row = 2; lblRFWin.Layout.Column = 1;
        ddRFWindow = uidropdown(ctrlGL, ...
            'Items', {'Hann', 'None', 'Blackman'}, 'Value', 'Hann', ...
            'Tooltip', 'Windowing function applied before FFT (Hann reduces spectral leakage)');
        ddRFWindow.Layout.Row = 2; ddRFWindow.Layout.Column = 2;
        lblRFPrep = uilabel(ctrlGL, 'Text', 'Preprocess:', 'FontWeight', 'bold');
        lblRFPrep.Layout.Row = 2; lblRFPrep.Layout.Column = 3;
        ddRFPreprocess = uidropdown(ctrlGL, ...
            'Items', {'log(R)', ['log(R' char(183) 'Q' char(8308) ')'], ...
                      'R', ['R' char(183) 'Q' char(8308)]}, ...
            'Value', 'log(R)', ...
            'Tooltip', ['Preprocessing applied before FFT:' newline ...
                        '  log(R) — log-scale; equalises fringe visibility across Q (default)' newline ...
                        '  log(R' char(183) 'Q' char(8308) ') — Fresnel-corrected log' newline ...
                        '  R — raw linear reflectivity' newline ...
                        '  R' char(183) 'Q' char(8308) ' — Fresnel-corrected linear']);
        ddRFPreprocess.Layout.Row = 2; ddRFPreprocess.Layout.Column = 4;
        lblRFPeakThr = uilabel(ctrlGL, 'Text', 'Peak thr.:', 'FontWeight', 'bold', ...
            'Tooltip', ['Minimum peak prominence as a fraction of the strongest peak.' newline ...
                        'Lower = more peaks detected.  0.05 = 5% of max.']);
        lblRFPeakThr.Layout.Row = 2; lblRFPeakThr.Layout.Column = 5;
        efRFPeakThr = uieditfield(ctrlGL, 'numeric', ...
            'Value', 0.05, 'Limits', [0.001 1], ...
            'Tooltip', 'Minimum prominence threshold (fraction of max peak). Lower → more peaks.');
        efRFPeakThr.Layout.Row = 2; efRFPeakThr.Layout.Column = 6;

        % Row 3: wavelength controls (XRR) or compute button (neutron)
        if ~isNeutronDS
            row3GL = uigridlayout(ctrlGL, [1 6], ...
                'ColumnWidth', {55, 80, 55, '1x', 20, 100}, ...
                'Padding', [0 0 0 0], 'ColumnSpacing', 4, 'RowSpacing', 0);
            row3GL.Layout.Row = 3; row3GL.Layout.Column = [1 6];
            uilabel(row3GL, 'Text', [char(955) ' (' char(197) '):'], 'FontSize', 10);
            efRFWavelength = uieditfield(row3GL, 'numeric', 'Value', wl_A, 'Limits', [0 Inf], ...
                'Tooltip', 'X-ray wavelength in Å for 2θ → Q conversion');
            efRFWavelength.Layout.Row = 1; efRFWavelength.Layout.Column = 2;
            lblRFSrc2 = uilabel(row3GL, 'Text', 'Source:', 'FontSize', 10, ...
                'HorizontalAlignment', 'right');
            lblRFSrc2.Layout.Row = 1; lblRFSrc2.Layout.Column = 3;
            ddRFSource = uidropdown(row3GL, ...
                'Items', XRAY_SOURCES(:,1)', ...
                'Value', XRAY_SOURCES{1,1}, 'FontSize', 9, ...
                'Tooltip', 'Select X-ray source to auto-fill wavelength', ...
                'ValueChangedFcn', @(s,~) set(efRFWavelength, 'Value', ...
                    guiTernary(isnan(XRAY_SOURCES{strcmp(XRAY_SOURCES(:,1), s.Value), 2}), ...
                               efRFWavelength.Value, ...
                               XRAY_SOURCES{strcmp(XRAY_SOURCES(:,1), s.Value), 2})));
            ddRFSource.Layout.Row = 1; ddRFSource.Layout.Column = 4;
            % Sync dropdown to current wavelength
            rfSrcMatch = find(abs([XRAY_SOURCES{:,2}] - wl_A) < 1e-4, 1);
            if ~isempty(rfSrcMatch), ddRFSource.Value = XRAY_SOURCES{rfSrcMatch,1}; end
        else
            efRFWavelength = [];  % not needed for neutron
            % Fill row 3 with empty space (auto-layout handles it)
        end

        % ── Row 2: Compute button ────────────────────────────────────────
        btnRFCompute = uibutton(rfGL, 'Text', 'Compute FFT', ...
            'ButtonPushedFcn', @doReflFFT, ...
            'BackgroundColor', [0.20 0.45 0.55], 'FontColor', [1 1 1]);
        btnRFCompute.Layout.Row = 2;

        % ── Row 3: FFT plot ──────────────────────────────────────────────
        rfAxPanel = uipanel(rfGL, 'BorderType', 'none');
        rfAxPanel.Layout.Row = 3;
        rfAx = axes(rfAxPanel);

        % ── Row 4: Peak results table ────────────────────────────────────
        rfTblPanel = uipanel(rfGL, 'Title', 'Detected Thickness Peaks', 'FontSize', 11);
        rfTblPanel.Layout.Row = 4;
        rfTblGL = uigridlayout(rfTblPanel, [1 1], 'Padding', [4 4 4 4]);
        rfPeakTable = uitable(rfTblGL, ...
            'ColumnName',  {'#', 'Thickness (nm)', 'Amplitude', 'Rel (%)', 'Harmonic?'}, ...
            'ColumnWidth', {30, 110, 80, 60, 100}, ...
            'Data',        {}, ...
            'RowName',     {});

        % ── Auto-compute on open ─────────────────────────────────────────
        doReflFFT([], []);

        function doReflFFT(~, ~)
        %DOREFLEFFT  FFT with multi-peak detection for multilayer / superlattice.
            xMin = efRFMin.Value;
            xMax = efRFMax.Value;
            if xMin >= xMax
                rfPeakTable.Data = {};
                title(rfAx, 'Error: min must be less than max');
                return;
            end

            % Select data in range
            mask = xAll >= xMin & xAll <= xMax;
            if sum(mask) < 10
                rfPeakTable.Data = {};
                title(rfAx, 'Too few points in range (need >= 10)');
                return;
            end
            x_sel = xAll(mask);
            R_sel = yAll(mask);

            % Convert x to Q (Å⁻¹)
            if isNeutronDS
                Q = x_sel;
            else
                curWL = efRFWavelength.Value;
                if isnan(curWL) || curWL <= 0
                    rfPeakTable.Data = {};
                    title(rfAx, 'Wavelength required for XRR mode');
                    return;
                end
                Q = (4 * pi / curWL) .* sin(x_sel / 2 * pi / 180);
            end

            % ── Preprocessing ─────────────────────────────────────────
            prepMode = ddRFPreprocess.Value;
            useQ4 = contains(prepMode, 'Q');
            useLog = startsWith(prepMode, 'log');

            R_proc = R_sel;
            if useQ4
                Q_safe = max(Q, 1e-6);
                R_proc = R_proc .* Q_safe.^4;
            end
            if useLog
                R_proc = log10(max(R_proc, 1e-30));  % floor at 1e-30 to avoid -Inf
            end

            % ── Interpolate to uniform Q grid ─────────────────────────
            nPts      = numel(Q);
            Q_uniform = linspace(min(Q), max(Q), nPts);
            R_uniform = interp1(Q, R_proc, Q_uniform, 'pchip');

            % Subtract linear trend (remove low-frequency drift / DC)
            p_trend   = polyfit(Q_uniform(:), R_uniform(:), 1);
            R_uniform = R_uniform - polyval(p_trend, Q_uniform);

            % ── Apply window function ─────────────────────────────────
            N = numel(R_uniform);
            switch ddRFWindow.Value
                case 'Hann'
                    w = 0.5 * (1 - cos(2*pi*(0:N-1)/(N-1)));
                case 'Blackman'
                    w = 0.42 - 0.5*cos(2*pi*(0:N-1)/(N-1)) + ...
                        0.08*cos(4*pi*(0:N-1)/(N-1));
                otherwise
                    w = ones(1, N);
            end
            R_windowed = R_uniform(:)' .* w;

            % ── Zero-padded FFT ───────────────────────────────────────
            N_fft = 2^nextpow2(4 * N);
            F     = abs(fft(R_windowed, N_fft));
            F     = F(1:N_fft/2);

            % Thickness axis: t = 2π / ΔQ  (Å → nm via /10)
            dQ           = Q_uniform(2) - Q_uniform(1);
            thickness_A  = 2*pi*(0:N_fft/2-1) / (N_fft * dQ);
            thickness_nm = thickness_A / 10;

            % ── Restrict search range ─────────────────────────────────
            searchMin = 4;   % skip DC bins 1–3
            maxT_nm   = efRFMaxThick.Value;
            searchMax = find(thickness_nm <= maxT_nm, 1, 'last');
            if isempty(searchMax) || searchMax < searchMin + 1
                searchMax = numel(F);
            end
            F_search = F(searchMin:searchMax);
            t_search = thickness_nm(searchMin:searchMax);

            % ── Multi-peak detection (no toolbox needed) ──────────────
            % Find local maxima: F(i) > F(i-1) AND F(i) > F(i+1)
            nS      = numel(F_search);
            isLocalMax = false(1, nS);
            for ki = 2:nS-1
                isLocalMax(ki) = F_search(ki) > F_search(ki-1) && ...
                                 F_search(ki) > F_search(ki+1);
            end
            maxIdxRel = find(isLocalMax);

            if isempty(maxIdxRel)
                % Fallback: just take the global max
                [~, maxIdxRel] = max(F_search);
            end

            pkAmps = F_search(maxIdxRel);
            pkThick = t_search(maxIdxRel);
            pkAbsIdx = maxIdxRel + searchMin - 1;  % index into full F array

            % Filter by prominence: compute local prominence for each peak
            % Prominence = peak height minus the higher of the two nearest minima
            prominences = zeros(size(pkAmps));
            for pi2 = 1:numel(pkAmps)
                idx = maxIdxRel(pi2);
                % Find nearest minimum to the left
                leftMin = min(F_search(1:idx));
                % Find nearest minimum to the right
                rightMin = min(F_search(idx:end));
                prominences(pi2) = pkAmps(pi2) - max(leftMin, rightMin);
            end

            % Threshold: keep peaks whose prominence > threshold × max(prominence)
            promThresh = efRFPeakThr.Value * max(prominences);
            keep = prominences > promThresh;
            pkAmps   = pkAmps(keep);
            pkThick  = pkThick(keep);
            pkAbsIdx = pkAbsIdx(keep);
            prominences = prominences(keep);

            % Sort by amplitude (descending)
            [pkAmps, sortOrd] = sort(pkAmps, 'descend');
            pkThick     = pkThick(sortOrd);
            pkAbsIdx    = pkAbsIdx(sortOrd);
            prominences = prominences(sortOrd); %#ok<NASGU>

            % Cap at 20 peaks
            maxPeaks = 20;
            if numel(pkAmps) > maxPeaks
                pkAmps   = pkAmps(1:maxPeaks);
                pkThick  = pkThick(1:maxPeaks);
                pkAbsIdx = pkAbsIdx(1:maxPeaks); %#ok<NASGU>
            end

            % ── Identify harmonic relationships ───────────────────────
            % A peak at thickness T is a harmonic of a fundamental T0 if
            % T ≈ n × T0 for integer n (within 10% tolerance).
            nPk = numel(pkThick);
            harmonicLabels = cell(nPk, 1);
            for hi = 1:nPk
                harmonicLabels{hi} = '';
            end
            if nPk >= 2
                % Sort peaks by thickness for harmonic analysis
                [tSorted, tSortIdx] = sort(pkThick, 'ascend');
                for hi = 2:nPk
                    for hj = 1:hi-1
                        ratio = tSorted(hi) / tSorted(hj);
                        nHarm = round(ratio);
                        if nHarm >= 2 && abs(ratio - nHarm) < 0.10 * nHarm
                            % hi is the n-th harmonic of hj
                            origIdx = tSortIdx(hi);   % amplitude-sorted index of harmonic
                            refIdx  = tSortIdx(hj);   % amplitude-sorted index of fundamental
                            harmonicLabels{origIdx} = sprintf('%d%s #%d (%.1f nm)', ...
                                nHarm, char(215), refIdx, pkThick(refIdx));
                            break;  % only label as harmonic of the first match
                        end
                    end
                end
            end

            % ── Plot FFT spectrum with peak markers ───────────────────
            cla(rfAx);
            plot(rfAx, t_search, F_search, '-', ...
                'Color', [0.20 0.45 0.55], 'LineWidth', 1.2);
            hold(rfAx, 'on');

            % Colour-code peaks: harmonics grey, fundamentals red
            peakColors = repmat([0.85 0.15 0.15], nPk, 1);  % red default
            for ci = 1:nPk
                if ~isempty(harmonicLabels{ci})
                    peakColors(ci,:) = [0.55 0.55 0.55];  % grey for harmonics
                end
            end
            for mi = 1:nPk
                plot(rfAx, pkThick(mi), pkAmps(mi), 'v', ...
                    'MarkerSize', 10, 'MarkerFaceColor', peakColors(mi,:), ...
                    'MarkerEdgeColor', peakColors(mi,:));
                text(rfAx, pkThick(mi), pkAmps(mi) * 1.06, ...
                    sprintf('%.1f', pkThick(mi)), ...
                    'HorizontalAlignment', 'center', 'FontSize', 8, ...
                    'Color', peakColors(mi,:));
            end
            hold(rfAx, 'off');
            xlabel(rfAx, 'Film thickness (nm)');
            ylabel(rfAx, 'FFT magnitude');
            grid(rfAx, 'on');  box(rfAx, 'on');
            xlim(rfAx, [0 maxT_nm]);
            if nPk >= 1
                title(rfAx, sprintf('%d peaks detected  —  strongest: %.1f nm', nPk, pkThick(1)));
            else
                title(rfAx, 'No peaks detected');
            end

            % ── Fill peak results table ───────────────────────────────
            relPct = 100 * pkAmps / max(pkAmps);
            tblData = cell(nPk, 5);
            for ti = 1:nPk
                tblData{ti,1} = ti;
                tblData{ti,2} = round(pkThick(ti), 2);
                tblData{ti,3} = round(pkAmps(ti), 4);
                tblData{ti,4} = round(relPct(ti), 1);
                tblData{ti,5} = harmonicLabels{ti};
            end
            rfPeakTable.Data = tblData;

            % ── Persist all peaks to dataset ──────────────────────────
            ds2 = appData.datasets{appData.activeIdx};
            rfResult.thicknesses_nm = pkThick(:);
            rfResult.amplitudes     = pkAmps(:);
            rfResult.harmonicLabels = harmonicLabels;
            rfResult.Q_range        = [min(Q) max(Q)];
            rfResult.preprocess     = prepMode;
            rfResult.fft_magnitude  = F_search(:);
            rfResult.thickness_axis = t_search(:);
            rfResult.isNeutron      = isNeutronDS;
            if ~isNeutronDS && ~isempty(efRFWavelength)
                rfResult.wavelength_A = efRFWavelength.Value;
            end
            ds2.kiessigThickness = rfResult;
            appData.datasets{appData.activeIdx} = ds2;
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  3.2  WILLIAMSON-HALL STRAIN ANALYSIS
    % ════════════════════════════════════════════════════════════════════

    function onWilliamsonHallPlot(~, ~)
    %ONWILLIAMSONHALLPLOT  Williamson-Hall analysis: β·cosθ vs 4·sinθ.
    %   Linear fit: β·cosθ = Kλ/D + 4ε·sinθ
    %   intercept → crystallite size D,  slope → microstrain ε.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        ds  = appData.datasets{appData.activeIdx};
        wl_A = extractWavelength_A(ds);
        if isnan(wl_A) || wl_A <= 0
            uialert(fig, ['Wavelength is required for Williamson-Hall analysis.  ' ...
                          'Enter a value in the ' char(955) ' field.'], ...
                'No wavelength'); return;
        end

        % Collect fitted peaks with valid FWHM
        if isempty(ds.peaks)
            uialert(fig, 'No peaks available.  Find and fit peaks first.', 'No peaks');
            return;
        end
        DEG2RAD  = pi / 180;
        K        = appData.kFactor;
        inst_rad = appData.instBroadening_deg * DEG2RAD;

        validIdx = [];
        for pki = 1:numel(ds.peaks)
            pk = ds.peaks(pki);
            isFitted = strcmp(pk.status,'fitted') || strcmp(pk.status,'fitted(global)');
            hasFWHM  = ~isnan(pk.fwhm) && pk.fwhm > 0;
            if isFitted && hasFWHM
                beta_meas = pk.fwhm * DEG2RAD;
                beta_sq   = beta_meas^2 - inst_rad^2;
                if beta_sq > 0
                    validIdx(end+1) = pki; %#ok<AGROW>
                end
            end
        end
        if numel(validIdx) < 3
            uialert(fig, ...
                sprintf('Williamson-Hall needs %s 3 fitted peaks with valid FWHM.\nCurrently have %d.', ...
                    char(8805), numel(validIdx)), ...
                'Insufficient peaks');
            return;
        end

        % ── Compute W-H data ───────────────────────────────────────────
        nWH      = numel(validIdx);
        sinTh    = zeros(nWH, 1);
        betaCos  = zeros(nWH, 1);
        peakLabels = cell(nWH, 1);
        for wi = 1:nWH
            pk        = ds.peaks(validIdx(wi));
            theta_rad = (pk.center / 2) * DEG2RAD;
            beta_meas = pk.fwhm * DEG2RAD;
            beta_corr = sqrt(beta_meas^2 - inst_rad^2);
            sinTh(wi)   = sin(theta_rad);
            betaCos(wi)  = beta_corr * cos(theta_rad);
            peakLabels{wi} = sprintf('%.2f%s', pk.center, char(176));
        end
        xWH = 4 * sinTh;
        yWH = betaCos;

        % ── Linear fit: yWH = slope·xWH + intercept ───────────────────
        p  = polyfit(xWH, yWH, 1);
        slope     = p(1);   % = microstrain ε
        intercept = p(2);   % = Kλ/D

        if intercept > 0
            D_nm = (K * wl_A * 0.1) / intercept;   % Å→nm via ×0.1
        else
            D_nm = NaN;   % unphysical negative intercept
        end
        epsilon = slope;   % microstrain (dimensionless)

        % R²
        yFit = polyval(p, xWH);
        SS_res = sum((yWH - yFit).^2);
        SS_tot = sum((yWH - mean(yWH)).^2);
        R2 = 1 - SS_res / SS_tot;

        % ── Plot ────────────────────────────────────────────────────────
        whFig = figure('Name', 'Williamson-Hall Plot', ...
            'NumberTitle', 'off', 'Position', [300 220 540 400]);
        whAx = axes(whFig);
        plot(whAx, xWH, yWH, 'ko', 'MarkerSize', 8, 'MarkerFaceColor', [0.2 0.5 0.8]);
        hold(whAx, 'on');
        xFitLine = linspace(0, max(xWH)*1.15, 100);
        yFitLine = polyval(p, xFitLine);
        plot(whAx, xFitLine, yFitLine, 'r-', 'LineWidth', 1.5);
        hold(whAx, 'off');

        xlabel(whAx, ['4' char(183) 'sin(' char(952) ')']);
        ylabel(whAx, [char(946) char(183) 'cos(' char(952) ')  (rad)']);
        if ~isnan(D_nm)
            title(whAx, sprintf('D = %.1f nm,  %s = %.2e,  R%s = %.4f', ...
                D_nm, char(949), epsilon, char(178), R2));
        else
            title(whAx, sprintf('%s = %.2e,  R%s = %.4f  (negative intercept)', ...
                char(949), epsilon, char(178), R2));
        end
        grid(whAx, 'on');
        box(whAx, 'on');
        legend(whAx, 'Peak data', sprintf('%s%scos%s = %.2e%s4sin%s + %.4e', ...
            char(946), char(183), char(952), epsilon, char(183), char(952), intercept), ...
            'Location', 'best');

        % Add 2θ labels to points
        for li = 1:nWH
            text(whAx, xWH(li), yWH(li), ['  ' peakLabels{li}], 'FontSize', 8);
        end

        % Persist to dataset
        ds2 = appData.datasets{appData.activeIdx};
        ds2.williamsonHall = struct( ...
            'D_nm',      D_nm, ...
            'epsilon',   epsilon, ...
            'R2',        R2, ...
            'slope',     slope, ...
            'intercept', intercept, ...
            'xWH',       xWH, ...
            'yWH',       yWH, ...
            'K',         K, ...
            'wavelength_A', wl_A, ...
            'instBroadening_deg', appData.instBroadening_deg);
        appData.datasets{appData.activeIdx} = ds2;
    end

    function onToggleFitCurves(src, ~)
    %ONTOGGLEFITCURVES  Show or hide Lorentzian fit overlays on the plot.
        appData.showFitCurves = src.Value;
        onPlot([],[]);
    end

    function onToggleShowBG(src, ~)
    %ONTOGGLESHOWBG  Show or hide the SNIP background estimate on the plot.
        appData.showSnipBg = src.Value;
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

    function onThemeChanged(~,~)
    %ONTHEMECHANGED  Apply light or dark theme to the entire GUI.
        isDark = strcmp(ddTheme.Value, 'Dark');
        if isDark
            th = styles.dark();
        else
            th = styles.default();
        end

        if isDark
            bgC  = th.bgColor;
            fgC  = th.fgColor;
            panC = th.panelBgColor;
            btnC = th.buttonBgColor;
            btnF = th.buttonFgColor;
            lstC = th.listBgColor;
            lstF = th.listFgColor;
            edtC = th.editBgColor;
            edtF = th.editFgColor;
            axBg = th.axesBgColor;
            axFg = th.axesFgColor;
        else
            bgC  = [0.94 0.94 0.94];
            fgC  = [0 0 0];
            panC = [0.94 0.94 0.94];
            btnC = [0.94 0.94 0.94];
            btnF = [0 0 0];
            lstC = [1 1 1];
            lstF = [0 0 0];
            edtC = [1 1 1];
            edtF = [0 0 0];
            axBg = [1 1 1];
            axFg = [0.15 0.15 0.15];
        end

        % Apply to figure
        fig.Color = bgC;

        % Apply to axes
        ax.Color     = axBg;
        ax.XColor    = axFg;
        ax.YColor    = axFg;
        ax.GridColor = guiTernary(isDark, th.gridColor, [0.15 0.15 0.15]);

        % Apply to all panels and their children recursively
        applyThemeToChildren(fig, panC, fgC, btnC, btnF, lstC, lstF, edtC, edtF);

        if appData.activeIdx > 0 && ~isempty(appData.datasets)
            onPlot([],[]);
        end
    end

    function applyThemeToChildren(parent, panC, fgC, btnC, btnF, lstC, lstF, edtC, edtF)
    %APPLYTHEMETOCHILDREN  Recursively set theme colours on UI components.
        children = parent.Children;
        for ci = 1:numel(children)
            c = children(ci);
            cType = class(c);
            try
                switch cType
                    case {'matlab.ui.container.Panel', 'matlab.ui.container.GridLayout'}
                        if isprop(c, 'BackgroundColor')
                            c.BackgroundColor = panC;
                        end
                    case 'matlab.ui.control.Button'
                        % Don't override buttons with custom colors (colored buttons)
                        if all(abs(c.BackgroundColor - [0.94 0.94 0.94]) < 0.05) || ...
                           all(abs(c.BackgroundColor - [0.25 0.25 0.28]) < 0.05)
                            c.BackgroundColor = btnC;
                            c.FontColor = btnF;
                        end
                    case 'matlab.ui.control.ListBox'
                        c.BackgroundColor = lstC;
                        c.FontColor       = lstF;
                    case {'matlab.ui.control.EditField', 'matlab.ui.control.NumericEditField'}
                        c.BackgroundColor = edtC;
                        c.FontColor       = edtF;
                    case 'matlab.ui.control.Label'
                        c.FontColor = fgC;
                    case 'matlab.ui.control.DropDown'
                        c.BackgroundColor = edtC;
                        c.FontColor       = edtF;
                    case 'matlab.ui.control.CheckBox'
                        c.FontColor = fgC;
                end
            catch
                % Skip unsupported property assignments
            end
            % Recurse into containers
            if isprop(c, 'Children') && ~isempty(c.Children)
                applyThemeToChildren(c, panC, fgC, btnC, btnF, lstC, lstF, edtC, edtF);
            end
        end
    end

    % ── Corrections callbacks ─────────────────────────────────────────────

    function onApplyCorrectionsAll(~,~)
    %ONAPPLYCORRECTIONSALL  Apply current corrections to all datasets.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end

        % Get current correction parameters from UI
        xOff     = efXOffset.Value;
        yOff     = efYOffset.Value;
        bgSlope  = efBGSlope.Value;
        bgIntcpt = efBGIntercept.Value;
        smoothEnabled = cbSmooth.Value;
        smoothWin = efSmoothWin.Value;
        smoothMeth = ddSmoothMethod.Value;
        xTrimMin = str2num_trim(efXTrimMin.Value);
        xTrimMax = str2num_trim(efXTrimMax.Value);
        normVal  = ddNormalize.Value;

        % Apply to all datasets
        for di = 1:numel(appData.datasets)
            ds = appData.datasets{di};
            d = ds.data;

            % Save undo state (same logic as onApplyCorrections)
            undoState.corrData       = ds.corrData;
            undoState.xOff           = ds.xOff;
            undoState.yOff           = ds.yOff;
            undoState.bgSlope        = ds.bgSlope;
            undoState.bgInt          = ds.bgInt;
            undoState.bgPoly         = guiTernary(isfield(ds,'bgPoly'), ds.bgPoly, []);
            undoState.smoothEnabled  = ds.smoothEnabled;
            undoState.smoothWindow   = ds.smoothWindow;
            undoState.smoothMethod   = ds.smoothMethod;
            undoState.xTrimMin       = ds.xTrimMin;
            undoState.xTrimMax       = ds.xTrimMax;
            undoState.normMethod     = ds.normMethod;
            ds.undoState = undoState;

            % Build corrected data struct
            corrData = d;

            % Trim/crop (FIRST step)
            if ~isnan(xTrimMin) || ~isnan(xTrimMax)
                tVec = double(corrData.time);
                mask = true(size(tVec));
                if ~isnan(xTrimMin), mask = mask & tVec >= xTrimMin; end
                if ~isnan(xTrimMax), mask = mask & tVec <= xTrimMax; end
                corrData.time   = corrData.time(mask);
                corrData.values = corrData.values(mask, :);
            end

            % Correct x axis (use corrData after trim)
            if ~isdatetime(corrData.time)
                corrData.time = corrData.time - xOff;
            end

            % Correct y channels (use corrData after trim)
            isNeutronDS = isfield(ds, 'parserName') && isNeutronParser(ds.parserName);
            if isNeutronDS
                for k = 1:size(corrData.values, 2)
                    if ~strcmpi(corrData.labels{k}, 'dQ')
                        corrData.values(:, k) = corrData.values(:, k) * yOff;
                    end
                end
            else
                hasPolyAll = isfield(ds,'bgPoly') && numel(ds.bgPoly) > 2;
                for k = 1:size(corrData.values, 2)
                    yRaw = corrData.values(:, k);
                    if isdatetime(corrData.time)
                        xForBG = (1:numel(yRaw))';
                    else
                        xForBG = double(corrData.time);
                    end
                    if hasPolyAll
                        yBG = polyval(ds.bgPoly, xForBG);
                    else
                        yBG = bgSlope .* xForBG + bgIntcpt;
                    end
                    corrData.values(:, k) = yRaw - yBG - yOff;
                end
            end

            % Subtract background dataset (interpolated to corrected x-axis)
            if cbSubtractBG.Value && ~isempty(appData.bgDataset)
                bgDs = appData.bgDataset;
                if ~isdatetime(bgDs.time) && ~isdatetime(corrData.time)
                    bgX = double(bgDs.time);
                    bgY = bgDs.values(:, 1);
                    bgInterp = interp1(bgX, bgY, double(corrData.time), ...
                                       'linear', 0);
                    for k = 1:size(corrData.values, 2)
                        corrData.values(:, k) = corrData.values(:, k) - bgInterp;
                    end
                end
            end

            % Apply smoothing
            if smoothEnabled
                win = max(1, round(smoothWin));
                corrData.values = utilities.smoothData(corrData.values, ...
                    'Window', win, 'Method', lower(smoothMeth));
            end

            % Normalization (LAST step)
            switch normVal
                case 'Range [0,1]'
                    corrData.values = utilities.normalize(corrData.values,'Method','range');
                case 'Peak (max=1)'
                    corrData.values = utilities.normalize(corrData.values,'Method','peak');
                case 'Z-score'
                    corrData.values = utilities.normalize(corrData.values,'Method','zscore');
                case 'Area (integral=1)'
                    for k = 1:size(corrData.values,2)
                        A = trapz(double(corrData.time), corrData.values(:,k));
                        if A ~= 0, corrData.values(:,k) = corrData.values(:,k) / A; end
                    end
            end

            % Save corrected data
            ds.corrData      = corrData;
            ds.xOff          = xOff;
            ds.yOff          = yOff;
            ds.bgSlope       = bgSlope;
            ds.bgInt         = bgIntcpt;
            ds.smoothEnabled = smoothEnabled;
            ds.smoothWindow  = smoothWin;
            ds.smoothMethod  = smoothMeth;
            ds.xTrimMin      = xTrimMin;
            ds.xTrimMax      = xTrimMax;
            ds.normMethod    = normVal;

            appData.datasets{di} = ds;
        end

        % Refresh plot
        onPlot([],[]);
        uialert(fig, sprintf('Corrections applied to all %d datasets.', ...
            numel(appData.datasets)), 'Batch Apply Complete');
    end

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

        % ════════════════════════════════════════════════════════════════
        %  Save undo state before applying new corrections
        % ════════════════════════════════════════════════════════════════
        undoState.corrData       = ds.corrData;
        undoState.xOff           = ds.xOff;
        undoState.yOff           = ds.yOff;
        undoState.bgSlope        = ds.bgSlope;
        undoState.bgInt          = ds.bgInt;
        undoState.bgPoly         = guiTernary(isfield(ds,'bgPoly'), ds.bgPoly, []);
        undoState.smoothEnabled  = ds.smoothEnabled;
        undoState.smoothWindow   = ds.smoothWindow;
        undoState.smoothMethod   = ds.smoothMethod;
        undoState.xTrimMin       = ds.xTrimMin;
        undoState.xTrimMax       = ds.xTrimMax;
        undoState.normMethod     = ds.normMethod;
        ds.undoState = undoState;

        % Build corrected data struct (value-copy, then override time/values)
        corrData = d;

        % ════════════════════════════════════════════════════════════════
        %  Trim/crop data (FIRST step)
        % ════════════════════════════════════════════════════════════════
        xTrimMin = str2num_trim(efXTrimMin.Value);  xTrimMax = str2num_trim(efXTrimMax.Value);
        if ~isnan(xTrimMin) || ~isnan(xTrimMax)
            tVec = double(corrData.time);
            mask = true(size(tVec));
            if ~isnan(xTrimMin), mask = mask & tVec >= xTrimMin; end
            if ~isnan(xTrimMax), mask = mask & tVec <= xTrimMax; end
            corrData.time   = corrData.time(mask);
            corrData.values = corrData.values(mask, :);
        end

        % Correct x axis (datetime x-offset not supported — leave unchanged)
        if ~isdatetime(corrData.time)
            corrData.time = corrData.time - xOff;
        end

        % Correct all y channels (use corrData, not d, so trim is respected)
        isNeutron = isfield(ds, 'parserName') && isNeutronParser(ds.parserName);
        if isNeutron
            % Neutron reflectometry: yOff is a multiplicative R scale factor
            % applied to all R-related columns (R, dR, theory, fresnel).
            % dQ (Q uncertainty) is left unchanged.
            for k = 1:size(corrData.values, 2)
                if ~strcmpi(corrData.labels{k}, 'dQ')
                    corrData.values(:, k) = corrData.values(:, k) * yOff;
                end
            end
        else
            % Standard: y_corrected = y_raw - yBG(x) - yOff
            % yBG is polynomial (ds.bgPoly) when order > 1, else linear slope+intercept
            hasPoly = isfield(ds,'bgPoly') && numel(ds.bgPoly) > 2;
            for k = 1:size(corrData.values, 2)
                yRaw = corrData.values(:, k);
                if isdatetime(corrData.time)
                    xForBG = (1:numel(yRaw))';
                else
                    xForBG = double(corrData.time);
                end
                if hasPoly
                    yBG = polyval(ds.bgPoly, xForBG);
                else
                    yBG = bgSlope .* xForBG + bgIntcpt;
                end
                corrData.values(:, k) = yRaw - yBG - yOff;
            end
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

        % ════════════════════════════════════════════════════════════════
        %  Normalization (LAST step)
        % ════════════════════════════════════════════════════════════════
        switch ddNormalize.Value
            case 'Range [0,1]'
                corrData.values = utilities.normalize(corrData.values,'Method','range');
            case 'Peak (max=1)'
                corrData.values = utilities.normalize(corrData.values,'Method','peak');
            case 'Z-score'
                corrData.values = utilities.normalize(corrData.values,'Method','zscore');
            case 'Area (integral=1)'
                for k = 1:size(corrData.values,2)
                    A = trapz(double(corrData.time), corrData.values(:,k));
                    if A ~= 0, corrData.values(:,k) = corrData.values(:,k) / A; end
                end
        end

        ds.corrData      = corrData;
        ds.xOff          = xOff;
        ds.yOff          = yOff;
        ds.bgSlope       = bgSlope;
        ds.bgInt         = bgIntcpt;
        % bgPoly already set on ds by onBGMouseUp; preserve it here (don't overwrite)
        ds.smoothEnabled = cbSmooth.Value;
        ds.smoothWindow  = efSmoothWin.Value;
        ds.smoothMethod  = ddSmoothMethod.Value;
        ds.xTrimMin      = xTrimMin;
        ds.xTrimMax      = xTrimMax;
        ds.normMethod    = ddNormalize.Value;
        appData.datasets{appData.activeIdx} = ds;

        % ════════════════════════════════════════════════════════════════
        %  Cross-polarization propagation (neutron data only)
        %  Apply same corrections to all datasets sharing the same source
        %  file (matched by stripping polarization suffixes).
        % ════════════════════════════════════════════════════════════════
        if isfield(ds, 'parserName') && isNeutronParser(ds.parserName)
            activeBase = neutronBaseName(ds.filepath);
            normVal    = ddNormalize.Value;
            for pki = 1:numel(appData.datasets)
                if pki == appData.activeIdx, continue; end
                pds = appData.datasets{pki};
                if ~isfield(pds, 'parserName') || ~isNeutronParser(pds.parserName)
                    continue;
                end
                if ~strcmp(neutronBaseName(pds.filepath), activeBase)
                    continue;
                end
                % Save undo state for this sibling
                pUndo.corrData      = pds.corrData;
                pUndo.xOff          = pds.xOff;
                pUndo.yOff          = pds.yOff;
                pUndo.bgSlope       = pds.bgSlope;
                pUndo.bgInt         = pds.bgInt;
                pUndo.smoothEnabled = pds.smoothEnabled;
                pUndo.smoothWindow  = pds.smoothWindow;
                pUndo.smoothMethod  = pds.smoothMethod;
                pUndo.xTrimMin      = pds.xTrimMin;
                pUndo.xTrimMax      = pds.xTrimMax;
                pUndo.normMethod    = pds.normMethod;
                pds.undoState       = pUndo;
                % Apply same correction pipeline: trim → offset → normalize
                pCorr = pds.data;
                if ~isnan(xTrimMin) || ~isnan(xTrimMax)
                    tVec = double(pCorr.time);
                    mask = true(size(tVec));
                    if ~isnan(xTrimMin), mask = mask & tVec >= xTrimMin; end
                    if ~isnan(xTrimMax), mask = mask & tVec <= xTrimMax; end
                    pCorr.time   = pCorr.time(mask);
                    pCorr.values = pCorr.values(mask, :);
                end
                if ~isdatetime(pds.data.time)
                    pCorr.time = pCorr.time - xOff;
                end
                % Multiplicative R scale for neutron sibling datasets
                for k = 1:size(pCorr.values, 2)
                    if ~strcmpi(pCorr.labels{k}, 'dQ')
                        pCorr.values(:, k) = pCorr.values(:, k) * yOff;
                    end
                end
                switch normVal
                    case 'Range [0,1]'
                        pCorr.values = utilities.normalize(pCorr.values,'Method','range');
                    case 'Peak (max=1)'
                        pCorr.values = utilities.normalize(pCorr.values,'Method','peak');
                    case 'Z-score'
                        pCorr.values = utilities.normalize(pCorr.values,'Method','zscore');
                    case 'Area (integral=1)'
                        for k = 1:size(pCorr.values,2)
                            A = trapz(double(pCorr.time), pCorr.values(:,k));
                            if A ~= 0, pCorr.values(:,k) = pCorr.values(:,k) / A; end
                        end
                end
                pds.corrData   = pCorr;
                pds.xOff       = xOff;
                pds.yOff       = yOff;
                pds.bgSlope    = 0;
                pds.bgInt      = 0;
                pds.xTrimMin   = xTrimMin;
                pds.xTrimMax   = xTrimMax;
                pds.normMethod = normVal;
                appData.datasets{pki} = pds;
            end
        end

        % Auto-set the save path for the active dataset
        [fpath, fname, ~] = fileparts(ds.filepath);
        efSavePath.Value = fullfile(fpath, [fname, '_corrected.csv']);

        onPlot([],[]);
    end

    function onResetCorrections(~,~)
        % Determine neutral yOff: 1.0 for neutron (multiplicative), 0 for others (additive)
        isNeutronReset = false;
        if appData.activeIdx >= 1 && ~isempty(appData.datasets)
            dsCheck = appData.datasets{appData.activeIdx};
            isNeutronReset = isfield(dsCheck, 'parserName') && isNeutronParser(dsCheck.parserName);
        end
        yOffDefault = guiTernary(isNeutronReset, 1, 0);

        efXOffset.Value     = 0;
        efYOffset.Value     = yOffDefault;
        efBGSlope.Value     = 0;
        efBGIntercept.Value = 0;
        ddBGOrder.Value     = 'Linear';
        cbSmooth.Value      = false;
        efSmoothWin.Value   = 5;
        ddSmoothMethod.Value = 'Moving';
        efXTrimMin.Value    = '';
        efXTrimMax.Value    = '';
        ddNormalize.Value   = 'None';
        efSavePath.Value    = '';

        if appData.activeIdx >= 1 && ~isempty(appData.datasets)
            ds               = appData.datasets{appData.activeIdx};
            ds.corrData      = [];
            ds.xOff          = 0;
            ds.yOff          = yOffDefault;
            ds.bgSlope       = 0;
            ds.bgInt         = 0;
            ds.bgPoly        = [];
            ds.smoothEnabled = false;
            ds.smoothWindow  = 5;
            ds.smoothMethod  = 'Moving';
            ds.xTrimMin      = NaN;
            ds.xTrimMax      = NaN;
            ds.normMethod    = 'None';
            ds.peaks         = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
                                      'xRange',{},'status',{},'bg',{},'model',{},'eta',{});
            appData.datasets{appData.activeIdx} = ds;
            appData.selectedPeakIdx = 0;
        end

        cancelInteractions();
        refreshPeakTable();
        onPlot([],[]);
    end

    function onUndoCorrections(~,~)
    %ONUNDOCORRECTIONS  Restore the previous correction state (one-level undo).
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end

        ds = appData.datasets{appData.activeIdx};

        % Check if an undo state exists
        if ~isfield(ds, 'undoState') || isempty(ds.undoState)
            uialert(fig, 'No previous correction state to restore.', 'Undo unavailable');
            return;
        end

        undoState = ds.undoState;

        % Restore all correction state from the saved undo state
        ds.corrData      = undoState.corrData;
        ds.xOff          = undoState.xOff;
        ds.yOff          = undoState.yOff;
        ds.bgSlope       = undoState.bgSlope;
        ds.bgInt         = undoState.bgInt;
        ds.smoothEnabled = undoState.smoothEnabled;
        ds.smoothWindow  = undoState.smoothWindow;
        ds.smoothMethod  = undoState.smoothMethod;
        if isfield(undoState, 'xTrimMin')
            ds.xTrimMin = undoState.xTrimMin;
        end
        if isfield(undoState, 'xTrimMax')
            ds.xTrimMax = undoState.xTrimMax;
        end
        if isfield(undoState, 'normMethod')
            ds.normMethod = undoState.normMethod;
        end
        if isfield(undoState, 'bgPoly')
            ds.bgPoly = undoState.bgPoly;
        end

        % Clear the undo state after restoring (one-level undo)
        ds.undoState = struct();

        % Update appData
        appData.datasets{appData.activeIdx} = ds;

        % Sync UI fields to the restored state
        efXOffset.Value      = ds.xOff;
        efYOffset.Value      = ds.yOff;
        efBGSlope.Value      = ds.bgSlope;
        efBGIntercept.Value  = ds.bgInt;
        cbSmooth.Value       = ds.smoothEnabled;
        efSmoothWin.Value    = ds.smoothWindow;
        ddSmoothMethod.Value = ds.smoothMethod;
        efXTrimMin.Value     = nan2str(ds.xTrimMin);
        efXTrimMax.Value     = nan2str(ds.xTrimMax);
        ddNormalize.Value    = ds.normMethod;

        % Refresh the plot
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
            logGUIError('Background Load Error', ME.message, ME);
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

    function onSetActiveBG(~,~)
    %ONSETACTIVEBG  Use the active dataset as the background.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end

        ds = appData.datasets{appData.activeIdx};
        [~, fname, fext] = fileparts(ds.filepath);

        % Use corrected data if available, otherwise raw data
        if ~isempty(ds.corrData)
            bgData = ds.corrData;
        else
            bgData = ds.data;
        end

        appData.bgDataset = bgData;
        appData.bgFile = [fname, fext];
        efBGFile.Value = appData.bgFile;
        cbSubtractBG.Value = true;  % auto-enable subtraction

        uialert(fig, sprintf('Background set to:\n%s', appData.bgFile), ...
            'Background Updated');
    end

    function onToggleDatasetVisibility(~,~)
    %ONTOGLEDATASETVISIBILITY  Toggle visibility of the active dataset.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end

        ds = appData.datasets{appData.activeIdx};
        ds.visible = ~ds.visible;
        appData.datasets{appData.activeIdx} = ds;

        % Update button label
        if ds.visible
            btnToggleVis.Text = 'Hide Dataset';
        else
            btnToggleVis.Text = 'Show Dataset';
        end

        % Refresh plot — use soft-update for instant visibility toggle
        softUpdateLines();
    end

    function onSmoothingChanged(~,~)
    %ONSMOOTHINGCHANGED  Re-apply corrections whenever smoothing controls change.
        if ~isempty(appData.datasets) && appData.activeIdx >= 1
            onApplyCorrections([],[]);
        end
    end

    % ── Annotation tool ───────────────────────────────────────────────────

    function onAnnotationModeChanged(~,~)
    %ONANNOTATIONMODECHANGED  Toggle annotation mode on/off.
    %   When enabled, single-click on the plot adds annotations.
    %   Right-click on an annotation deletes it.
        if cbAnnotationMode.Value
            % Enable annotation mode
            appData.annotationMode = true;
            fig.WindowButtonDownFcn = @onAnnotationClick;
            fig.Pointer = 'crosshair';
        else
            % Disable annotation mode
            appData.annotationMode = false;
            fig.WindowButtonDownFcn = @onAxesButtonDown;
            fig.Pointer = 'arrow';
        end
    end

    function onAnnotationClick(~,~)
    %ONANNOTATIONCLICK  Handle clicks in annotation mode: add or delete annotations.
        if isempty(appData.datasets) || appData.activeIdx < 1
            return;
        end

        % Get click position in axes coordinates
        cp = ax.CurrentPoint;
        x = cp(1,1);
        y = cp(1,2);

        % Ignore clicks outside the axes plot area
        if x < ax.XLim(1) || x > ax.XLim(2) || ...
           y < ax.YLim(1) || y > ax.YLim(2)
            return;
        end

        % Right-click: delete annotation if near cursor
        if strcmp(fig.SelectionType, 'alt')
            deleteNearestAnnotation(x, y);
            onPlot([],[]);
            return;
        end

        % Left-click: add new annotation
        % Prompt user for annotation text
        answer = inputdlg('Enter annotation text:', 'Add Annotation', [1 40]);
        if isempty(answer) || isempty(strtrim(answer{1}))
            return;  % User cancelled
        end

        annotText = strtrim(answer{1});

        % Add annotation to current dataset
        ds = appData.datasets{appData.activeIdx};
        if ~isfield(ds, 'annotations') || isempty(ds.annotations)
            ds.annotations = {};
        end

        % Create annotation struct
        annot = struct('x', x, 'y', y, 'text', annotText);
        ds.annotations{end+1} = annot;

        appData.datasets{appData.activeIdx} = ds;

        % Refresh plot
        onPlot([],[]);
    end

    function deleteNearestAnnotation(x, y)
    %DELETENEARESTANNOTATION  Remove the annotation closest to (x, y).
        ds = appData.datasets{appData.activeIdx};
        if isempty(ds.annotations)
            return;
        end

        % Find the closest annotation (within 5% of axes range)
        xRange = ax.XLim(2) - ax.XLim(1);
        yRange = ax.YLim(2) - ax.YLim(1);
        thresh = 0.05;  % 5% of range

        minDist = inf;
        minIdx = -1;

        for ai = 1:numel(ds.annotations)
            annot = ds.annotations{ai};
            dx = abs(annot.x - x) / xRange;
            dy = abs(annot.y - y) / yRange;
            dist = sqrt(dx^2 + dy^2);

            if dist < thresh && dist < minDist
                minDist = dist;
                minIdx = ai;
            end
        end

        % Delete if found
        if minIdx > 0
            ds.annotations(minIdx) = [];
            appData.datasets{appData.activeIdx} = ds;
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

        % Display region statistics
        if numel(yPool) >= 1
            lblRegionStats.Text = sprintf( ...
                'Region: n=%d  mean=%.4g  std=%.4g  min=%.4g  max=%.4g', ...
                numel(yPool), mean(yPool), std(yPool), min(yPool), max(yPool));
        else
            lblRegionStats.Text = '';
        end

        if numel(xPool) < 2
            uialert(fig, ...
                sprintf('Only %d data point(s) inside the box — need at least 2 to fit.', ...
                        numel(xPool)), ...
                'Too few points');
            return;
        end

        % Determine polynomial order from ddBGOrder
        bgOrderStr = ddBGOrder.Value;
        if strcmp(bgOrderStr, 'Linear')
            bgOrder = 1;
        else
            bgOrder = str2double(bgOrderStr(6:end));  % 'Poly N' → N
        end

        p = polyfit(xPool, yPool, bgOrder);

        % Store per-dataset and update widgets
        ds = appData.datasets{appData.activeIdx};
        if bgOrder == 1
            % Linear: also populate slope/intercept widgets for manual editing
            efBGSlope.Value     = p(1);
            efBGIntercept.Value = p(2);
            ds.bgPoly = [];   % clear polynomial storage (use widget values)
        else
            % Higher order: store in ds.bgPoly; slope/intercept widgets stay as-is
            ds.bgPoly = p;
        end
        appData.datasets{appData.activeIdx} = ds;

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
            xVecPlot = posixtime(xVecPlot);
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
            % Re-enable only for non-neutron parsers (neutron hides btnPickY)
            if isempty(appData.datasets) || ~isfield(appData.datasets{appData.activeIdx}, 'parserName') ...
                    || ~isNeutronParser(appData.datasets{appData.activeIdx}.parserName)
                btnPickY.Enable = 'on';
            end
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
        fp = strtrim(efSavePath.Value);
        if isempty(fp)
            uialert(fig,'Set an output file path first.','No output path');
            return;
        end
        fmt = resolvedExportFormat();
        try
            if isfield(ds, 'parserName') && isNeutronParser(ds.parserName)
                saveConsolidatedNeutronCSV(ds, fp, fmt);
            else
                hasCorrected = ~isempty(ds.corrData);
                exportData   = guiTernary(hasCorrected, ds.corrData, ds.data);
                if hasCorrected
                    asymData = computeAsymmetryForExport(ds);
                    guiSaveCSV(exportData, fp, ds.data, asymData, fmt);
                else
                    guiSaveCSV(exportData, fp, [], [], fmt);
                end
            end
            uialert(fig, sprintf('Saved:\n%s', fp), 'Saved');
        catch ME
            fprintf(2, '\n[dataImportGUI] Save error: %s\n', ME.message);
            for si = 1:numel(ME.stack)
                fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
            end
            logGUIError('Save error', ME.message, ME);
            uialert(fig, ME.message, 'Save error');
        end
    end

    function fmt = resolvedExportFormat()
    %RESOLVEDEXPORTFORMAT  Map dropdown value to format string.
        if strcmp(ddExportFormat.Value, 'Origin ASCII')
            fmt = 'origin';
        else
            fmt = 'standard';
        end
    end

    function asymData = computeAsymmetryForExport(ds)
    %COMPUTEASYMMETRYFOREXPORT  Compute spin asymmetry for CSV export.
    %  Returns a struct with .headers and .values if the active dataset is
    %  neutron data with a paired ++ / -- partner. Returns empty struct otherwise.
        asymData = struct('headers', {{}}, 'values', []);

        if ~isfield(ds, 'parserName') || ~isNeutronParser(ds.parserName)
            return;
        end
        if ~isfield(ds.data.metadata, 'parserSpecific') || ...
           ~isfield(ds.data.metadata.parserSpecific, 'polarization')
            return;
        end
        pol = ds.data.metadata.parserSpecific.polarization;
        if ~strcmp(pol, '++') && ~strcmp(pol, '--')
            return;
        end

        % Find paired dataset
        pairMap = findPolarizationPairs(appData.datasets);
        myIdx = find(cellfun(@(c) ~isempty(c) && any(c == appData.activeIdx), pairMap), 1);
        if isempty(myIdx), return; end
        pair = pairMap{myIdx};
        idxPP = pair(1);  idxMM = pair(2);

        dsPP = appData.datasets{idxPP};
        dsMM = appData.datasets{idxMM};
        primaryPP = guiTernary(~isempty(dsPP.corrData), dsPP.corrData, dsPP.data);
        primaryMM = guiTernary(~isempty(dsMM.corrData), dsMM.corrData, dsMM.data);

        iRPP = find(strcmp(primaryPP.labels, 'R'), 1);
        iRMM = find(strcmp(primaryMM.labels, 'R'), 1);
        if isempty(iRPP) || isempty(iRMM), return; end

        RPP = primaryPP.values(:, iRPP);
        RMM = primaryMM.values(:, iRMM);

        idRPP = find(strcmp(primaryPP.labels, 'dR'), 1);
        idRMM = find(strcmp(primaryMM.labels, 'dR'), 1);
        dRPP = guiTernary(~isempty(idRPP), primaryPP.values(:, idRPP), zeros(size(RPP)));
        dRMM = guiTernary(~isempty(idRMM), primaryMM.values(:, idRMM), zeros(size(RMM)));

        % Linear asymmetry: (R++ - R--) / (R++ + R--)
        valid = RPP > 0 & RMM > 0 & ~isnan(RPP) & ~isnan(RMM);
        asymVal = NaN(size(RPP));
        asymErr = NaN(size(RPP));
        sumR = RPP + RMM;
        asymVal(valid) = (RPP(valid) - RMM(valid)) ./ sumR(valid);
        dA_dRPP = 2 * RMM(valid) ./ (sumR(valid).^2);
        dA_dRMM = -2 * RPP(valid) ./ (sumR(valid).^2);
        asymErr(valid) = sqrt((dA_dRPP .* dRPP(valid)).^2 + (dA_dRMM .* dRMM(valid)).^2);

        headers = {'Asymmetry', 'dAsymmetry'};
        vals = [asymVal, asymErr];

        % Theory asymmetry (if both datasets have theory columns)
        iThPP = find(strcmpi(primaryPP.labels, 'theory'), 1);
        if isempty(iThPP), iThPP = find(strcmpi(primaryPP.labels, 'model'), 1); end
        iThMM = find(strcmpi(primaryMM.labels, 'theory'), 1);
        if isempty(iThMM), iThMM = find(strcmpi(primaryMM.labels, 'model'), 1); end

        if ~isempty(iThPP) && ~isempty(iThMM)
            thPP = primaryPP.values(:, iThPP);
            thMM = primaryMM.values(:, iThMM);
            validTh = thPP > 0 & thMM > 0 & ~isnan(thPP) & ~isnan(thMM);
            asymTheory = NaN(size(thPP));
            sumTh = thPP + thMM;
            asymTheory(validTh) = (thPP(validTh) - thMM(validTh)) ./ sumTh(validTh);
            headers{end+1} = 'Asymmetry_theory';
            vals = [vals, asymTheory];
        end

        asymData.headers = headers;
        asymData.values  = vals;
    end

    function saveConsolidatedNeutronCSV(activeDs, fp, fmt)
    %SAVECONSOLIDATEDNEUTRONCSV  Write all polarization channels to one CSV.
    %   Gathers loaded neutron datasets from the same measurement and writes
    %   a single file with Q, R/dR/theory per polarization, plus spin asymmetry.
    %   fmt = 'standard' (default) or 'origin' (multi-row Origin headers).
        if nargin < 3 || isempty(fmt), fmt = 'standard'; end

        % ── Polarization suffix map ────────────────────────────────────
        polOrder   = {'++', '+-', '-+', '--', ''};
        polSuffix  = {'pp', 'pm', 'mp', 'mm', 'unpol'};

        % ── Gather datasets from the same measurement ─────────────────
        baseName = neutronBaseName(activeDs.filepath);
        nDS = numel(appData.datasets);
        collected = struct('ds', {}, 'pol', {}, 'sortKey', {});

        for di = 1:nDS
            dsi = appData.datasets{di};
            if ~isfield(dsi, 'parserName') || ~isNeutronParser(dsi.parserName)
                continue;
            end
            if ~strcmp(neutronBaseName(dsi.filepath), baseName)
                continue;
            end
            pol = '';
            if isfield(dsi.data.metadata, 'parserSpecific') && ...
               isfield(dsi.data.metadata.parserSpecific, 'polarization')
                pol = dsi.data.metadata.parserSpecific.polarization;
            end
            idx = find(strcmp(polOrder, pol), 1);
            if isempty(idx), idx = numel(polOrder); end
            entry.ds      = dsi;
            entry.pol     = pol;
            entry.sortKey = idx;
            collected(end+1) = entry; %#ok<AGROW>
        end

        if isempty(collected)
            error('saveConsolidatedNeutronCSV:noData', ...
                'No neutron datasets found for measurement "%s".', baseName);
        end

        % Sort by canonical polarization order
        [~, si] = sort([collected.sortKey]);
        collected = collected(si);

        % ── Build shared Q vector from first dataset ──────────────────
        src0 = guiTernary(~isempty(collected(1).ds.corrData), ...
                          collected(1).ds.corrData, collected(1).ds.data);
        Q = src0.time(:);
        nRows = numel(Q);

        % ── Determine Q unit ──────────────────────────────────────────
        qUnit = '';
        if isfield(src0, 'units') && ~isempty(src0.units)
            % X-axis unit is in metadata for neutron data
        end
        if isfield(src0.metadata, 'parserSpecific') && ...
           isfield(src0.metadata.parserSpecific, 'xUnit')
            qUnit = src0.metadata.parserSpecific.xUnit;
        end
        qHdr = guiTernary(~isempty(qUnit), sprintf('Q (%s)', qUnit), 'Q');

        % ── Collect columns per polarization ──────────────────────────
        allHdrs = {qHdr};
        allCols = {Q};
        hasPP = false; hasMM = false;
        RPP = []; RMM = []; dRPP = []; dRMM = []; thPP = []; thMM = [];

        for ci = 1:numel(collected)
            pol    = collected(ci).pol;
            dsi    = collected(ci).ds;
            src    = guiTernary(~isempty(dsi.corrData), dsi.corrData, dsi.data);
            pidx   = find(strcmp(polOrder, pol), 1);
            suffix = polSuffix{pidx};

            iR  = find(strcmp(src.labels, 'R'), 1);
            idR = find(strcmp(src.labels, 'dR'), 1);
            iTh = find(strcmp(src.labels, 'theory'), 1);

            % Interpolate onto shared Q grid if needed
            Qi = src.time(:);
            needInterp = numel(Qi) ~= nRows || any(abs(Qi - Q) > eps(Q)*10);

            if ~isempty(iR)
                Rcol = src.values(:, iR);
                if needInterp, Rcol = interp1(Qi, Rcol, Q, 'linear', NaN); end
                allHdrs{end+1} = sprintf('R_%s', suffix); %#ok<AGROW>
                allCols{end+1} = Rcol(:); %#ok<AGROW>
                if strcmp(pol, '++'), RPP = Rcol(:); hasPP = true; end
                if strcmp(pol, '--'), RMM = Rcol(:); hasMM = true; end
            end
            if ~isempty(idR)
                dRcol = src.values(:, idR);
                if needInterp, dRcol = interp1(Qi, dRcol, Q, 'linear', NaN); end
                allHdrs{end+1} = sprintf('dR_%s', suffix); %#ok<AGROW>
                allCols{end+1} = dRcol(:); %#ok<AGROW>
                if strcmp(pol, '++'), dRPP = dRcol(:); end
                if strcmp(pol, '--'), dRMM = dRcol(:); end
            end
            if ~isempty(iTh)
                thcol = src.values(:, iTh);
                if needInterp, thcol = interp1(Qi, thcol, Q, 'linear', NaN); end
                allHdrs{end+1} = sprintf('theory_%s', suffix); %#ok<AGROW>
                allCols{end+1} = thcol(:); %#ok<AGROW>
                if strcmp(pol, '++'), thPP = thcol(:); end
                if strcmp(pol, '--'), thMM = thcol(:); end
            end
        end

        % ── Spin asymmetry (++ and -- present) ────────────────────────
        if hasPP && hasMM
            valid = RPP > 0 & RMM > 0 & ~isnan(RPP) & ~isnan(RMM);
            asymVal = NaN(nRows, 1);
            sumR = RPP + RMM;
            asymVal(valid) = (RPP(valid) - RMM(valid)) ./ sumR(valid);
            allHdrs{end+1} = 'Asymmetry';
            allCols{end+1} = asymVal;

            % Propagated error: dA = 2/(R+++R--)^2 * sqrt((R--*dR++)^2 + (R++*dR--)^2)
            if ~isempty(dRPP) && ~isempty(dRMM)
                dAsym = NaN(nRows, 1);
                dAsym(valid) = 2 ./ sumR(valid).^2 .* ...
                    sqrt((RMM(valid) .* dRPP(valid)).^2 + (RPP(valid) .* dRMM(valid)).^2);
                allHdrs{end+1} = 'dAsymmetry';
                allCols{end+1} = dAsym;
            end

            % Theory asymmetry
            if ~isempty(thPP) && ~isempty(thMM)
                validTh = thPP > 0 & thMM > 0 & ~isnan(thPP) & ~isnan(thMM);
                asymTh = NaN(nRows, 1);
                sumTh = thPP + thMM;
                asymTh(validTh) = (thPP(validTh) - thMM(validTh)) ./ sumTh(validTh);
                allHdrs{end+1} = 'Asymmetry_theory';
                allCols{end+1} = asymTh;
            end
        end

        % ── Write CSV ─────────────────────────────────────────────────
        dirPart = fileparts(fp);
        if ~isempty(dirPart) && ~isfolder(dirPart)
            error('saveConsolidatedNeutronCSV:badDir', ...
                'Output directory does not exist:\n%s', dirPart);
        end
        fid = fopen(fp, 'w');
        if fid < 0
            error('saveConsolidatedNeutronCSV:cannotOpen', ...
                'Cannot open file for writing:\n%s', fp);
        end
        closeGuard = onCleanup(@() fclose(fid));

        if strcmp(fmt, 'origin')
            longNames = cellfun(@(h) strtrim(regexprep(h, '\s*\([^)]+\)', '')), ...
                                allHdrs, 'UniformOutput', false);
            units = cellfun(@extractUnitFromHeader, allHdrs, 'UniformOutput', false);
            desigs = buildColumnDesignations(allHdrs);
            fprintf(fid, '%s\n', strjoin(longNames, ','));
            fprintf(fid, '%s\n', strjoin(units, ','));
            fprintf(fid, '%s\n', strjoin(desigs, ','));
        else
            fprintf(fid, '%s\n', strjoin(allHdrs, ','));
        end
        nCols = numel(allCols);
        for r = 1:nRows
            fprintf(fid, '%.10g', allCols{1}(r));
            for c = 2:nCols
                fprintf(fid, ',%.10g', allCols{c}(r));
            end
            fprintf(fid, '\n');
        end
    end

    function onBatchExportCSV(~,~)
    %ONBATCHEXPORTCSV  Export all loaded datasets to separate CSV files.
    %   Non-neutron datasets: individual CSV (corrected+raw or raw-only).
    %   Neutron datasets: one consolidated CSV per measurement base name.
        if isempty(appData.datasets)
            uialert(fig,'Load a file first.','No data');
            return;
        end

        fmt = resolvedExportFormat();
        nDS = numel(appData.datasets);
        nExported = 0;
        failedFiles = {};
        neutronDone = {};  % base names already exported

        for di = 1:nDS
            ds = appData.datasets{di};

            % ── Neutron: consolidated export (once per measurement) ────
            if isfield(ds, 'parserName') && isNeutronParser(ds.parserName)
                bn = neutronBaseName(ds.filepath);
                if any(strcmp(neutronDone, bn)), continue; end
                [fpath, ~, ~] = fileparts(ds.filepath);
                outFile = fullfile(fpath, [bn, '_neutron.csv']);
                try
                    saveConsolidatedNeutronCSV(ds, outFile, fmt);
                    nExported = nExported + 1;
                    neutronDone{end+1} = bn; %#ok<AGROW>
                catch ME
                    failedFiles{end+1} = sprintf('%s: %s', bn, ME.message); %#ok<AGROW>
                end
                continue;
            end

            % ── Non-neutron: individual export ─────────────────────────
            hasCorrected = ~isempty(ds.corrData);
            exportData   = guiTernary(hasCorrected, ds.corrData, ds.data);
            suffix       = guiTernary(hasCorrected, '_corrected.csv', '_export.csv');

            [fpath, fname, ~] = fileparts(ds.filepath);
            outFile = fullfile(fpath, [fname, suffix]);

            try
                if hasCorrected
                    guiSaveCSV(exportData, outFile, ds.data, [], fmt);
                else
                    guiSaveCSV(exportData, outFile, [], [], fmt);
                end
                nExported = nExported + 1;
            catch ME
                failedFiles{end+1} = sprintf('%s: %s', fname, ME.message); %#ok<AGROW>
            end
        end

        % Show result
        if nExported == 0
            uialert(fig, 'No datasets to export.', 'Batch Export');
        elseif isempty(failedFiles)
            uialert(fig, sprintf('Successfully exported %d file(s) to CSV.', nExported), ...
                'Batch Export Complete');
        else
            msg = sprintf('Exported: %d\nFailed: %d\n\n', nExported, numel(failedFiles));
            msg = [msg, strjoin(failedFiles, '\n')];
            uialert(fig, msg, 'Batch Export Partial');
        end
    end

    function onCopyDataToClipboard(~,~)
    %ONCOPYDATATOCLIPBOARD  Copy selected datasets as tab-delimited text to clipboard.
    %   Opens a dataset picker dialog; copies data with Origin multi-row headers.
        if isempty(appData.datasets)
            uialert(fig, 'Load a file first.', 'No data');
            return;
        end

        % Build display names for each loaded dataset
        nDS = numel(appData.datasets);
        names = cell(1, nDS);
        for i = 1:nDS
            [~, fn, ex] = fileparts(appData.datasets{i}.filepath);
            badge = getParserBadge(appData.datasets{i}.parserName);
            names{i} = sprintf('%s %s%s', badge, fn, ex);
        end

        % Modal multi-select dialog
        sel = listdlg('ListString', names, ...
            'SelectionMode', 'multiple', ...
            'InitialValue', appData.activeIdx, ...
            'Name', 'Copy to Clipboard', ...
            'PromptString', 'Select datasets to copy:', ...
            'ListSize', [350 300]);
        if isempty(sel), return; end

        try
            clipStr = buildClipboardString(sel);
            clipboard('copy', clipStr);
            uialert(fig, sprintf('Copied %d dataset(s) to clipboard.\nPaste into Origin or Excel.', ...
                numel(sel)), 'Copied');
        catch ME
            logGUIError('Clipboard error', ME.message, ME);
            uialert(fig, ME.message, 'Clipboard error');
        end
    end

    function s = buildClipboardString(dsIndices)
    %BUILDCLIPBOARDSTRING  Build tab-delimited text with Origin-style headers.
    %   Returns a string ready for clipboard('copy', s) and Origin paste.
        allLongNames = {};
        allUnits     = {};
        allDesig     = {};
        allCols      = {};
        multiDS      = numel(dsIndices) > 1;

        for ii = 1:numel(dsIndices)
            di = dsIndices(ii);
            dsi = appData.datasets{di};
            src = guiTernary(~isempty(dsi.corrData), dsi.corrData, dsi.data);
            [~, fn, ~] = fileparts(dsi.filepath);
            prefix = guiTernary(multiDS, [fn, '_'], '');

            % X column
            allLongNames{end+1} = [prefix, 'X']; %#ok<AGROW>
            allUnits{end+1}     = extractXUnitFromStruct(src); %#ok<AGROW>
            allDesig{end+1}     = 'X'; %#ok<AGROW>
            allCols{end+1}      = src.time(:); %#ok<AGROW>

            % Y columns
            for k = 1:size(src.values, 2)
                allLongNames{end+1} = [prefix, src.labels{k}]; %#ok<AGROW>
                allUnits{end+1}     = src.units{k}; %#ok<AGROW>
                lbl = lower(src.labels{k});
                if contains(lbl, {'err', 'dr', 'std', 'sigma'})
                    allDesig{end+1} = 'yEr'; %#ok<AGROW>
                else
                    allDesig{end+1} = 'Y'; %#ok<AGROW>
                end
                allCols{end+1} = src.values(:, k); %#ok<AGROW>
            end
        end

        % Determine max rows across all datasets
        maxR = max(cellfun(@numel, allCols));
        nC   = numel(allCols);

        % Build string: Long Name / Units / Comments header rows, then data
        lines = cell(1, maxR + 3);
        lines{1} = strjoin(allLongNames, sprintf('\t'));
        lines{2} = strjoin(allUnits, sprintf('\t'));
        lines{3} = strjoin(allDesig, sprintf('\t'));

        for r = 1:maxR
            vals = cell(1, nC);
            for c = 1:nC
                if r <= numel(allCols{c})
                    vals{c} = sprintf('%.10g', allCols{c}(r));
                else
                    vals{c} = '';
                end
            end
            lines{r + 3} = strjoin(vals, sprintf('\t'));
        end

        s = strjoin(lines, newline);
    end

    function onSendToOrigin(~,~)
    %ONSENDTOORIGIN  Send active dataset to OriginPro via COM; fall back to clipboard.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data');
            return;
        end
        ds  = appData.datasets{appData.activeIdx};
        src = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        [~, fn, ~] = fileparts(ds.filepath);

        % Gather axis label hints from current GUI state
        axLabels = struct();
        if ~isempty(efCustomXLabel.Value)
            axLabels.x = efCustomXLabel.Value;
        end
        if ~isempty(efCustomYLabel.Value)
            axLabels.y = efCustomYLabel.Value;
        end

        % Attempt COM bridge
        ok = utilities.toOrigin(src, ...
            'SheetName',  fn, ...
            'BookName',   'ThinFilmToolkit', ...
            'AxisLabels', axLabels, ...
            'LogY',       cbLogY.Value, ...
            'LogX',       cbLogX.Value);

        if ok
            uialert(fig, sprintf('Data sent to OriginPro.\nWorksheet: %s', fn), ...
                'Origin Export');
        else
            % Fallback: copy to clipboard in Origin-ready format
            clipStr = buildClipboardString(appData.activeIdx);
            clipboard('copy', clipStr);
            uialert(fig, ...
                ['Origin not available — data copied to clipboard instead.' newline ...
                 'Paste into Origin with Edit > Paste.'], ...
                'Origin not found');
        end
    end

    function onExportOriginScript(~,~)
    %ONEXPORTORIGINSCRIPT  Export active dataset as LabTalk script + CSV.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        ds  = appData.datasets{appData.activeIdx};
        src = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        [fp, fn, ~] = fileparts(ds.filepath);

        defaultPath = fullfile(fp, [fn, '.ogs']);
        [outFile, outDir] = uiputfile({'*.ogs','LabTalk Script (*.ogs)'}, ...
            'Save Origin Script', defaultPath);
        if isequal(outFile, 0), return; end

        scriptPath = fullfile(outDir, outFile);
        try
            utilities.exportOriginScript(src, scriptPath, ...
                'LogY', cbLogY.Value, ...
                'LogX', cbLogX.Value);
            uialert(fig, sprintf('Origin script saved:\n%s\n\nRun in Origin: run.file("%s")', ...
                scriptPath, outFile), 'Export Complete');
        catch ME
            uialert(fig, sprintf('Export failed:\n%s', ME.message), 'Export Error');
        end
    end

    function onBatchConvertXRD(~,~)
    %ONBATCHCONVERTXRD  Launch the standalone XRD batch converter GUI.
        xrdConvertGUI();
    end

    function onOpenLayoutSettings(~,~)
    %ONOPENLAYOUTSETTINGS  Launch the Layout Settings GUI.
        current = struct( ...
            'figW',       fig.Position(3), ...
            'figH',       fig.Position(4), ...
            'ctrlPanelW', contentGL.ColumnWidth{2}, ...
            'corrPanelW', appData.corrPanelWidth, ...
            'axLimPanelW', appData.axLimPanelWidth, ...
            'fileListW',   contentGL.ColumnWidth{1} ...
        );
        layoutSettingsGUI(@applyLayoutSettings, current, LAYOUT_DEFAULTS, PREFS_FILE);
    end

    function applyLayoutSettings(s)
    %APPLYLAYOUTSETTINGS  Apply layout dimensions from a settings struct to the live GUI.
        % Figure size
        pos    = fig.Position;
        pos(3) = max(s.figW, 400);
        pos(4) = max(s.figH, MIN_FIG_H);
        fig.Position = pos;
        % File-list column width (narrow sidebar)
        contentGL.ColumnWidth{1} = s.fileListW;
        % Controls panel width
        contentGL.ColumnWidth{2} = s.ctrlPanelW;
        % Corrections and axes+appearance panel widths
        appData.corrPanelWidth  = s.corrPanelW;
        appData.axLimPanelWidth = s.axLimPanelW;
        % Propagate to live analysisGL column widths
        applyParserAnalysisConfig(resolvedCorrStyle());
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
            logGUIError('Export error', ME.message, ME);
            uialert(fig, ME.message, 'Export error');
        end
    end

    % ── Plot callbacks ────────────────────────────────────────────────────

    function softUpdateLines()
    % SOFTUPDATELINES  Update line colors and visibility without full redraw.
    %   Fast path for color/visibility changes that only need property updates
    %   on existing line handles. Falls back to full redraw if cache is invalid.
        if ~appData.lineCache.valid
            % Cache stale — fall back to full redraw
            onPlot([],[]);
            return;
        end

        nDS = numel(appData.datasets);

        % Update left-axis lines (color and visibility)
        for di = 1:nDS
            ds = appData.datasets{di};
            vis = 'on';
            if isfield(ds, 'visible') && ~ds.visible
                vis = 'off';
            end
            col = ds.color;  % per-dataset color override ([] = Auto)

            % Iterate over cached left-axis lines for this dataset
            for k = 1:size(appData.lineCache.left, 2)
                if di <= size(appData.lineCache.left, 1)
                    h = appData.lineCache.left{di, k};
                    if isvalid(h)
                        h.Visible = vis;
                        % Color: use override if present, otherwise keep current
                        if ~isempty(col)
                            h.Color = col;
                        end
                    else
                        % Line handle is invalid — cache is stale
                        appData.lineCache.valid = false;
                        onPlot([],[]);
                        return;
                    end
                end
            end
        end

        % Update right-axis lines (color and visibility)
        for di = 1:nDS
            ds = appData.datasets{di};
            vis = 'on';
            if isfield(ds, 'visible') && ~ds.visible
                vis = 'off';
            end
            colR = ds.colorR;  % per-dataset right-axis color override ([] = Auto)

            % Iterate over cached right-axis lines for this dataset
            for k = 1:size(appData.lineCache.right, 2)
                if di <= size(appData.lineCache.right, 1)
                    h = appData.lineCache.right{di, k};
                    if isvalid(h)
                        h.Visible = vis;
                        % Color: use override if present
                        if ~isempty(colR)
                            h.Color = colR;
                        end
                    else
                        % Line handle is invalid — cache is stale
                        appData.lineCache.valid = false;
                        onPlot([],[]);
                        return;
                    end
                end
            end
        end

        drawnow limitrate;  % lightweight update
    end

    function onPlot(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        % Invalidate line cache on full redraw — cache will be rebuilt by drawToAxes
        appData.lineCache.valid = false;
        drawToAxes(ax);
    end

    function onAsymmetryToggle(~,~)
    %ONASYMMETRYTOGGLE  Handle spin asymmetry checkbox state changes.
    %   When asymmetry is enabled:
    %     - Hide PNR datasets (importNCNRPNR) since asymmetry needs DAT files
    %     - Switch to linear Y scale
    %   When disabled:
    %     - Restore PNR dataset visibility
    %     - Restore previous log Y state

        if cbCalculateAsymmetry.Value
            % Asymmetry enabled: store previous log state and hide PNR data
            if ~isfield(appData, 'asymmetryPrevLogY')
                appData.asymmetryPrevLogY = cbLogY.Value;
            end
            cbLogY.Value = false;  % Switch to linear scale

            % Hide all PNR datasets
            for i = 1:numel(appData.datasets)
                if strcmp(appData.datasets{i}.parserName, 'importNCNRPNR')
                    if ~isfield(appData.datasets{i}, 'hiddenForAsymmetry')
                        appData.datasets{i}.hiddenForAsymmetry = false;
                    end
                    appData.datasets{i}.hiddenForAsymmetry = true;
                end
            end
        else
            % Asymmetry disabled: restore PNR visibility and previous log state
            for i = 1:numel(appData.datasets)
                if isfield(appData.datasets{i}, 'hiddenForAsymmetry') && appData.datasets{i}.hiddenForAsymmetry
                    appData.datasets{i}.hiddenForAsymmetry = false;
                end
            end

            % Restore previous log Y state if we stored it
            if isfield(appData, 'asymmetryPrevLogY')
                cbLogY.Value = appData.asymmetryPrevLogY;
            end
        end

        onPlot([], []);  % Redraw plot with updated visibility and scale
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
            % Generate colors from selected colormap or default lines() palette.
            % Left-axis indices:  (di-1)*nY  + k
            % Right-axis indices: nDS*nY     + (di-1)*nY2 + k
            colormapName = ddColormap.Value;
            nColors = max(nDS * (nY + nY2), 1);
            colors = getColorsFromMap(colormapName, nColors);

            % ── Draw ──────────────────────────────────────────────────────
            % Peak markers and zoom rect use HandleVisibility='off' so ax.Children may
            % omit them in some MATLAB releases. findall() bypasses this filter.
            delete(findall(targetAx, 'Tag', 'GUIPeakAnnotation'));
            delete(findall(targetAx, 'Tag', 'GUISNIPBackground'));
            delete(findall(targetAx, 'Tag', 'GUIZoomBox'));
            delete(targetAx.Children);
            cla(targetAx);
            % cla() removes plot children but DOES NOT reset XLim/YLim — MATLAB
            % retains the last auto-scaled range even after clearing.  When switching
            % data types (e.g. XRD → magnetometry), the stale XRD YLim [0,50000]
            % would persist, squishing new [-5,5] moment data into a flat line.
            % Fix: temporarily set [0 1] (forces XLimMode='manual') then release to
            % 'auto' so the next plot() auto-scales purely to the new data.
            targetAx.XLim = [0 1];  targetAx.YLim = [0 1];
            targetAx.XLimMode = 'auto';
            targetAx.YLimMode = 'auto';

            % Reset right y-axis state if it was created in a previous draw.
            % yyaxis cla only clears the active side, so switch explicitly.
            if numel(targetAx.YAxis) > 1
                yyaxis(targetAx, 'right');
                cla(targetAx);
                targetAx.YLim = [0 1];
                targetAx.YLimMode = 'auto';
                targetAx.YScale   = 'linear';
                ylabel(targetAx, '');
                yyaxis(targetAx, 'left');
            end

            % ── 2D area-detector map branch ──────────────────────────────
            if is2DDataset(activeDs)
                draw2DMap(targetAx, activeDs);
                return;
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
            % Log-mode waterfall uses multiplicative offsets instead of additive.
            wfLogMode = waterfallOn && cbLogY.Value;

            % For neutron data, group polarization cross-sections from the
            % same measurement so they share the same waterfall offset.
            % E.g., file-refl.datA and file-refl.datD get the same offset.
            wfGroupIdx = (1:nDS)';  % default: each dataset gets its own group
            if waterfallOn && nDS > 1
                anyNeutron = false;
                baseNames = cell(nDS, 1);
                for gi = 1:nDS
                    gds = appData.datasets{gi};
                    if isfield(gds, 'parserName') && isNeutronParser(gds.parserName)
                        anyNeutron = true;
                        baseNames{gi} = neutronBaseName(gds.filepath);
                    else
                        baseNames{gi} = sprintf('__unique_%d__', gi);
                    end
                end
                if anyNeutron
                    [~, ~, wfGroupIdx] = unique(baseNames, 'stable');
                end
            end

            for di = 1:nDS
                ds          = appData.datasets{di};

                % Skip invisible datasets
                if isfield(ds, 'visible') && ~ds.visible
                    continue;
                end

                % Skip datasets hidden for asymmetry calculation
                if isfield(ds, 'hiddenForAsymmetry') && ds.hiddenForAsymmetry
                    continue;
                end

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

                    % --- Neutron reflectometry: error bars + theory overlay ---
                    isNeutron = isfield(ds,'parserName') && isNeutronParser(ds.parserName);
                    isRChannel = strcmp(ySel{k}, 'R');

                    % When spin asymmetry is active, skip individual PNR traces
                    if isNeutron && isRChannel && cbCalculateAsymmetry.Value
                        continue;
                    end

                    if isNeutron && isRChannel
                        % Use polarization-based color
                        pol = '';
                        if isfield(d.metadata,'parserSpecific') && isfield(d.metadata.parserSpecific,'polarization')
                            pol = d.metadata.parserSpecific.polarization;
                        end
                        baseColor = neutronPolarizationColor(pol);

                        % Build legend display name: 'R++', 'R+-', etc. with optional filename group
                        if isempty(pol)
                            polLabel = 'R';
                        else
                            polLabel = ['R' pol];
                        end
                        if nDS > 1
                            [~, fn, ~] = fileparts(ds.filepath);
                            % Strip trailing polarization suffix (.datA/.datB etc.) from filename
                            fn = regexprep(fn, '-refl$', '');   % strip refl suffix
                            polLabel = [fn '  ' polLabel]; %#ok<AGROW>
                        end
                        dispName = polLabel;

                        % Measured R with error bars (manual construction for better HitTest control)
                        yR  = primaryD.values(:, idx);
                        % Find dR in primaryD (corrected or raw data)
                        idR = find(strcmp(primaryD.labels, 'dR'), 1);
                        if ~isempty(idR)
                            dyR = primaryD.values(:, idR);
                        else
                            dyR = zeros(size(yR));
                        end

                        % Apply waterfall offset for multi-dataset display
                        if effectiveSpacing ~= 0
                            if wfLogMode
                                yR = yR * effectiveSpacing^(wfGroupIdx(di) - 1);
                            else
                                yR = yR + (wfGroupIdx(di) - 1) * effectiveSpacing;
                            end
                        end

                        % Filter NaN
                        good = ~isnan(xVecPrimary) & ~isnan(yR);
                        xGood = xVecPrimary(good);
                        yGood = yR(good);
                        dyGood = dyR(good);

                        % Plot error bar whiskers (light color) - vectorized for performance
                        if any(good) && ~isempty(idR)
                            whiskerAlpha = 0.5;
                            whiskerColor = [baseColor(1)*whiskerAlpha+0.5, baseColor(2)*whiskerAlpha+0.5, baseColor(3)*whiskerAlpha+0.5];

                            % Build NaN-separated whisker segments: [x1 x1 NaN x2 x2 NaN ...]
                            nPts = length(xGood);
                            xWhiskers = zeros(1, nPts*3);
                            yWhiskers = zeros(1, nPts*3);
                            for ii = 1:nPts
                                wi = (ii-1)*3 + 1;
                                xWhiskers(wi:wi+1) = xGood(ii);
                                yWhiskers(wi) = yGood(ii) - dyGood(ii);
                                yWhiskers(wi+1) = yGood(ii) + dyGood(ii);
                                xWhiskers(wi+2) = NaN;
                                yWhiskers(wi+2) = NaN;
                            end

                            % Plot all whiskers as one line object (much more efficient)
                            plot(targetAx, xWhiskers, yWhiskers, '-', ...
                                'Color', whiskerColor, ...
                                'LineWidth', 1.2, 'HitTest', 'off', 'HandleVisibility', 'off');
                        end

                        % Plot measured R points (main trace, first plot gets the legend)
                        plot(targetAx, xGood, yGood, 'o', ...
                            'Color',       baseColor, ...
                            'MarkerSize',  4.5, ...
                            'LineWidth',   1.0, ...
                            'HitTest',     'off', ...
                            'DisplayName', dispName);

                        % Theory overlay (lighter/desaturated)
                        % Search in primaryD.labels (corrected or raw) for consistency
                        iTheory = find(strcmp(primaryD.labels, 'theory'), 1);
                        if isempty(iTheory)
                            % Try alternate naming conventions
                            iTheory = find(strcmpi(primaryD.labels, 'Theory'), 1);
                        end
                        if isempty(iTheory)
                            iTheory = find(strcmpi(primaryD.labels, 'model'), 1);
                        end

                        if ~isempty(iTheory)
                            yTheory = primaryD.values(:, iTheory);

                            % Apply waterfall offset to theory so it aligns with measured data
                            if effectiveSpacing ~= 0
                                if wfLogMode
                                    yTheory = yTheory * effectiveSpacing^(wfGroupIdx(di) - 1);
                                else
                                    yTheory = yTheory + (wfGroupIdx(di) - 1) * effectiveSpacing;
                                end
                            end

                            theoryColor = 0.55 * baseColor + 0.45 * [1 1 1];
                            goodT = ~isnan(xVecPrimary) & ~isnan(yTheory);
                            if any(goodT)
                                plot(targetAx, xVecPrimary(goodT), yTheory(goodT), '-', ...
                                    'Color',       theoryColor, ...
                                    'LineWidth',   1.2, ...
                                    'HitTest',     'off', ...
                                    'DisplayName', [polLabel ' theory']);
                            end
                        end

                    else
                        % --- Standard (non-neutron) path ---
                        baseLabel = [guiLabel(d.labels{idx}, d.units{idx}), fileSuffix];

                        % Raw overlay (dashed, desaturated 50% white-blend)
                        if showRawOver
                            anyRawShown = true;
                            yRaw     = d.values(:, idx);
                            if ctFactor > 0, yRaw = yRaw / ctFactor; end
                            if effectiveSpacing ~= 0
                                if wfLogMode
                                    yRaw = yRaw * effectiveSpacing^(wfGroupIdx(di) - 1);
                                else
                                    yRaw = yRaw + (wfGroupIdx(di) - 1) * effectiveSpacing;
                                end
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
                            if wfLogMode
                                yPrimary = yPrimary * effectiveSpacing^(wfGroupIdx(di) - 1);
                            else
                                yPrimary = yPrimary + (wfGroupIdx(di) - 1) * effectiveSpacing;
                            end
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

            % ── Spin asymmetry calculation (if enabled for neutron data) ────────
            if cbCalculateAsymmetry.Value && isNeutronParser(resolvedCorrStyle())
                hold(targetAx, 'on');
                pairMap = findPolarizationPairs(appData.datasets);
                drawnPairs = [];  % track drawn (pp,mm) index pairs to skip duplicates

                for i = 1:numel(pairMap)
                    if isempty(pairMap{i}), continue; end
                    [idxPP, idxMM] = deal(pairMap{i}(1), pairMap{i}(2));
                    pairKey = idxPP * 10000 + idxMM;
                    if ismember(pairKey, drawnPairs), continue; end
                    drawnPairs(end+1) = pairKey; %#ok<AGROW>

                    % Get both polarization datasets
                    dsPP = appData.datasets{idxPP};
                    dsMM = appData.datasets{idxMM};
                    dPP = dsPP.data;
                    dMM = dsMM.data;

                    % Use corrected data if available
                    primaryPP = guiTernary(~isempty(dsPP.corrData), dsPP.corrData, dPP);
                    primaryMM = guiTernary(~isempty(dsMM.corrData), dsMM.corrData, dMM);

                    % Get R channel from both
                    idxRPP = find(strcmp(primaryPP.labels, 'R'), 1);
                    idxRMM = find(strcmp(primaryMM.labels, 'R'), 1);
                    if isempty(idxRPP) || isempty(idxRMM), continue; end

                    % Find dR columns
                    idxdRPP = find(strcmp(primaryPP.labels, 'dR'), 1);
                    idxdRMM = find(strcmp(primaryMM.labels, 'dR'), 1);

                    % Calculate asymmetry
                    RPP = primaryPP.values(:, idxRPP);
                    RMM = primaryMM.values(:, idxRMM);
                    dRPP = guiTernary(~isempty(idxdRPP), primaryPP.values(:, idxdRPP), zeros(size(RPP)));
                    dRMM = guiTernary(~isempty(idxdRMM), primaryMM.values(:, idxdRMM), zeros(size(RMM)));

                    % Parse formula
                    formulaStr = ddAsymFormula.Value;
                    if contains(formulaStr, 'Log')
                        formula = 'Log';
                    else
                        formula = 'Linear';
                    end

                    % Calculate asymmetry values and errors
                    xAsym = primaryPP.time;
                    valid = ~isnan(RPP) & ~isnan(RMM) & RPP > 0 & RMM > 0;

                    asymVal = NaN(size(RPP));
                    asymErr = NaN(size(RPP));

                    if strcmp(formula, 'Linear')
                        sumR = RPP + RMM;
                        asymVal(valid) = (RPP(valid) - RMM(valid)) ./ sumR(valid);
                        dA_dRPP = 2 * RMM(valid) ./ (sumR(valid).^2);
                        dA_dRMM = -2 * RPP(valid) ./ (sumR(valid).^2);
                        asymErr(valid) = sqrt((dA_dRPP .* dRPP(valid)).^2 + (dA_dRMM .* dRMM(valid)).^2);
                    else  % Log
                        asymVal(valid) = log(RPP(valid) ./ RMM(valid));
                        dA_dRPP = 1 ./ RPP(valid);
                        dA_dRMM = -1 ./ RMM(valid);
                        asymErr(valid) = sqrt((dA_dRPP .* dRPP(valid)).^2 + (dA_dRMM .* dRMM(valid)).^2);
                    end

                    % Plot asymmetry with error bars
                    good = ~isnan(xAsym) & ~isnan(asymVal);
                    xGood = xAsym(good);
                    yGood = asymVal(good);
                    dyGood = asymErr(good);

                    % Get base filename for legend
                    [~, fnPP, ~] = fileparts(dsPP.filepath);
                    fnPP = regexprep(fnPP, '-refl$', '');
                    asymLegend = sprintf('%s  Asymmetry', fnPP);

                    % Plot asymmetry whiskers (light gray) - vectorized for performance
                    asymColor = [0.4 0.4 0.4];  % neutral dark gray
                    whiskerColor = 0.5 * asymColor + 0.5 * [1 1 1];

                    nPts = length(xGood);
                    xWhiskers = zeros(1, nPts*3);
                    yWhiskers = zeros(1, nPts*3);
                    for ii = 1:nPts
                        wi = (ii-1)*3 + 1;
                        xWhiskers(wi:wi+1) = xGood(ii);
                        yWhiskers(wi) = yGood(ii) - dyGood(ii);
                        yWhiskers(wi+1) = yGood(ii) + dyGood(ii);
                        xWhiskers(wi+2) = NaN;
                        yWhiskers(wi+2) = NaN;
                    end

                    plot(targetAx, xWhiskers, yWhiskers, '-', ...
                        'Color', whiskerColor, ...
                        'LineWidth', 1.0, 'HitTest', 'off', 'HandleVisibility', 'off');

                    % Plot asymmetry points
                    plot(targetAx, xGood, yGood, 'o', ...
                        'Color', asymColor, ...
                        'MarkerSize', 4.5, ...
                        'LineWidth', 1.0, ...
                        'HitTest', 'off', ...
                        'DisplayName', asymLegend);

                    % ── Theoretical asymmetry overlay ─────────────────────
                    % Look for 'theory' column in both ++ and -- datasets
                    iThPP = find(strcmpi(primaryPP.labels, 'theory'), 1);
                    if isempty(iThPP)
                        iThPP = find(strcmpi(primaryPP.labels, 'model'), 1);
                    end
                    iThMM = find(strcmpi(primaryMM.labels, 'theory'), 1);
                    if isempty(iThMM)
                        iThMM = find(strcmpi(primaryMM.labels, 'model'), 1);
                    end

                    if ~isempty(iThPP) && ~isempty(iThMM)
                        thPP = primaryPP.values(:, iThPP);
                        thMM = primaryMM.values(:, iThMM);
                        validTh = ~isnan(thPP) & ~isnan(thMM) & thPP > 0 & thMM > 0;

                        asymTheory = NaN(size(thPP));
                        if strcmp(formula, 'Linear')
                            sumTh = thPP + thMM;
                            asymTheory(validTh) = (thPP(validTh) - thMM(validTh)) ./ sumTh(validTh);
                        else  % Log
                            asymTheory(validTh) = log(thPP(validTh) ./ thMM(validTh));
                        end

                        goodTh = ~isnan(xAsym) & ~isnan(asymTheory);
                        if any(goodTh)
                            theoryColor = 0.55 * asymColor + 0.45 * [1 1 1];
                            plot(targetAx, xAsym(goodTh), asymTheory(goodTh), '-', ...
                                'Color',       theoryColor, ...
                                'LineWidth',   1.2, ...
                                'HitTest',     'off', ...
                                'DisplayName', [asymLegend ' theory']);
                        end
                    end
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
                legend(targetAx,'Location','best','Interpreter','none');
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

            % Suppress "Negative data ignored" warning that MATLAB emits
            % when log-scale axes contain zero or negative values (expected
            % for asymmetry data or zero-padded theory curves).
            warnState = warning('off', 'MATLAB:Axes:NegativeDataInLogAxis');
            cleanupWarn = onCleanup(@() warning(warnState));
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
                fmtGL.ColumnWidth{5} = guiTernary(hasY2, 20,   0);
                fmtGL.ColumnWidth{6} = guiTernary(hasY2, '1x', 0);
                toggleY2Appearance(hasY2);
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

            % Waterfall group of the active dataset (used for peak/bg/annotation offsets)
            if waterfallOn && appData.activeIdx >= 1 && appData.activeIdx <= numel(wfGroupIdx)
                activeGroupIdx = wfGroupIdx(appData.activeIdx);
            else
                activeGroupIdx = 1;
            end

            if appData.activeIdx >= 1 && ~isempty(appData.datasets)
                dsPk = appData.datasets{appData.activeIdx};
                if ~isempty(dsPk.peaks)
                    hold(targetAx,'on');
                    yLo   = targetAx.YLim(1);
                    yHi   = targetAx.YLim(2);
                    ySpan = yHi - yLo;
                    fitColor = appData.fitCurveColor;
                    % In waterfall mode the active dataset is shifted by this amount.
                    % Log mode uses a multiplier; linear mode uses an additive offset.
                    if wfLogMode
                        pkYMult = effectiveSpacing^(activeGroupIdx - 1);
                        pkYOff  = 0;
                    else
                        pkYMult = 1;
                        pkYOff  = (activeGroupIdx - 1) * effectiveSpacing;
                    end

                    % ── (1) Lorentzian fit overlays ───────────────────────
                    if appData.showFitCurves
                        for pki = 1:numel(dsPk.peaks)
                            pk       = dsPk.peaks(pki);
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
                            u = (xFitPlot - pk.center) ./ pk.fwhm;
                            if strcmp(pkModel, 'Gaussian')
                                yFitPlot = pk.height .* exp(-4.*log(2).*u.^2) + pk.bg;
                            elseif strcmp(pkModel, 'Pseudo-Voigt')
                                eta = guiTernary(isfield(pk,'eta') && ~isempty(pk.eta) && ~isnan(pk.eta), pk.eta, 0.5);
                                L   = 1 ./ (1 + 4.*u.^2);
                                G   = exp(-4.*log(2).*u.^2);
                                yFitPlot = pk.height .* (eta.*L + (1-eta).*G) + pk.bg;
                            elseif strcmp(pkModel, 'Split Pearson VII') && isfield(pk,'fitParams') && numel(pk.fitParams) == 7
                                yFitPlot = utilities.splitPearsonVII(xFitPlot(:), pk.fitParams)';
                            else   % Lorentzian (default)
                                yFitPlot = pk.height ./ (1 + 4.*u.^2) + pk.bg;
                            end
                            if wfLogMode
                                yFitPlot = yFitPlot * pkYMult;
                            else
                                yFitPlot = yFitPlot + pkYOff;
                            end

                            isSel = (pki == appData.selectedPeakIdx);
                            plot(targetAx, xFitPlot, yFitPlot, '-', ...
                                'Color',            fitColor, ...
                                'LineWidth',        guiTernary(isSel, 2.5, 1.5), ...
                                'HitTest',          'off', ...
                                'Tag',              'GUIPeakAnnotation', ...
                                'HandleVisibility', 'off');
                        end
                    end

                    % ── (2) Vertical markers, labels and FWHM bars ────────
                    for pki = 1:numel(dsPk.peaks)
                        pk        = dsPk.peaks(pki);
                        isSel     = (pki == appData.selectedPeakIdx);
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
                        if wfLogMode && yLo > 0 && yHi > 0
                            pkLabelY = exp(log(yLo) + (log(yHi)-log(yLo))*0.03) * pkYMult;
                        else
                            pkLabelY = yLo + ySpan*0.03 + pkYOff;
                        end
                        text(targetAx, pk.center, pkLabelY, ...
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
                            halfHBase = guiTernary(hasBg, pk.bg + pk.height*0.5, pk.height*0.5);
                            if wfLogMode
                                halfH = halfHBase * pkYMult;
                            else
                                halfH = halfHBase + pkYOff;
                            end
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

            % ── SNIP background overlay ──────────────────────────────────
            if appData.showSnipBg && appData.activeIdx >= 1 && ...
               ~isempty(appData.datasets)
                dsBg = appData.datasets{appData.activeIdx};
                if isfield(dsBg, 'snipBackground') && ...
                   ~isempty(dsBg.snipBackground) && ...
                   ~isempty(dsBg.snipBackground.x)
                    if wfLogMode
                        snipBgY = dsBg.snipBackground.bg * effectiveSpacing^(activeGroupIdx - 1);
                    else
                        snipBgY = dsBg.snipBackground.bg + (activeGroupIdx - 1) * effectiveSpacing;
                    end
                    hold(targetAx, 'on');
                    plot(targetAx, dsBg.snipBackground.x, snipBgY, '--', ...
                        'Color',            [0.2 0.8 0.2], ...
                        'LineWidth',        1.5, ...
                        'HitTest',          'off', ...
                        'Tag',              'GUISNIPBackground', ...
                        'HandleVisibility', 'off');
                    hold(targetAx, 'off');
                end
            end

            % ── User annotations ──────────────────────────────────────────
            % Render text labels placed by user in annotation mode.
            if appData.activeIdx >= 1 && ~isempty(appData.datasets)
                dsAnn = appData.datasets{appData.activeIdx};
                if isfield(dsAnn, 'annotations') && ~isempty(dsAnn.annotations)
                    hold(targetAx, 'on');
                    % In waterfall mode, offset annotations by dataset
                    for ai = 1:numel(dsAnn.annotations)
                        annot = dsAnn.annotations{ai};
                        if wfLogMode
                            yPos = annot.y * effectiveSpacing^(activeGroupIdx - 1);
                        else
                            yPos = annot.y + (activeGroupIdx - 1) * effectiveSpacing;
                        end

                        % Render text with light background for visibility
                        text(targetAx, annot.x, yPos, annot.text, ...
                            'FontSize',         10, ...
                            'FontWeight',       'normal', ...
                            'Color',            [0.2 0.2 0.2], ...
                            'BackgroundColor',  [1.0 0.95 0.85], ...
                            'EdgeColor',        [0.7 0.7 0.7], ...
                            'LineWidth',        0.5, ...
                            'HitTest',          'off', ...
                            'Tag',              'GUIUserAnnotation', ...
                            'HandleVisibility', 'off');
                    end
                    hold(targetAx, 'off');
                end
            end

            % ── Cache line handles for soft-update performance ────────────────
            % Collect all line handles from the axes and organize by dataset/axis
            % This enables fast color/visibility updates without full redraws.
            allLines = findobj(targetAx, 'Type', 'line');
            nDS      = numel(appData.datasets);

            % Initialize cache
            appData.lineCache.left  = cell(nDS, max(nY, 1));
            appData.lineCache.right = cell(nDS, max(nY2, 1));
            appData.lineCache.valid = false;  % conservative: mark as invalid until verified

            % Attempt to map lines to datasets by iterating through allLines and counting
            % Left-axis lines first, then right-axis lines (if any).
            % This is a heuristic based on order of creation in drawToAxes.
            lineIdx = 1;
            for di = 1:nDS
                ds = appData.datasets{di};
                if isfield(ds, 'visible') && ~ds.visible
                    continue;  % skip invisible datasets
                end
                if isfield(ds, 'hiddenForAsymmetry') && ds.hiddenForAsymmetry
                    continue;  % skip hidden datasets
                end

                % Count expected lines for this dataset (Y + Y2 channels)
                for k = 1:nY
                    if lineIdx <= numel(allLines)
                        appData.lineCache.left{di, k} = allLines(lineIdx);
                        lineIdx = lineIdx + 1;
                    end
                end
            end

            % Right-axis lines (if Y2 is active)
            if hasY2
                for di = 1:nDS
                    ds = appData.datasets{di};
                    if isfield(ds, 'visible') && ~ds.visible
                        continue;
                    end
                    if isfield(ds, 'hiddenForAsymmetry') && ds.hiddenForAsymmetry
                        continue;
                    end

                    for k = 1:nY2
                        if lineIdx <= numel(allLines)
                            appData.lineCache.right{di, k} = allLines(lineIdx);
                            lineIdx = lineIdx + 1;
                        end
                    end
                end
            end

            % Mark cache as valid (soft-update is now possible)
            appData.lineCache.valid = true;

        catch ME
            fprintf(2, '\n[dataImportGUI] Plot error: %s\n', ME.message);
            for si = 1:numel(ME.stack)
                fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
            end
            logGUIError('Plot error', ME.message, ME);
            uialert(fig, ME.message, 'Plot error');
        end
    end

    function onPoleFigure(~,~)
    %ONPOLEFIGURE  Generate a polar plot of intensity vs scan angle at a chosen 2θ.
    %  For 2D area-detector data: extracts a column (fixed 2θ) and plots
    %  intensity vs omega/chi/phi as a polar projection.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds = appData.datasets{appData.activeIdx};
        if ~is2DDataset(ds)
            uialert(fig,'Active dataset is not a 2D area-detector scan.','Pole Figure'); return;
        end

        map = ds.data.metadata.parserSpecific.map2D;
        I   = map.intensity;   % [N × M]
        x2  = map.axis2(:)';  % 2Theta [1×M]
        x1  = map.axis1(:);   % Omega/Chi [N×1]

        % Ask user for the 2θ position to extract
        [~, peakCol] = max(sum(I, 1));  % default: column with highest total intensity
        answer = inputdlg( ...
            sprintf('Enter 2%s position to extract (range: %.2f to %.2f):', ...
                    char(952), x2(1), x2(end)), ...
            'Pole Figure', [1 50], {sprintf('%.3f', x2(peakCol))});
        if isempty(answer), return; end
        target2th = str2double(answer{1});
        if isnan(target2th), return; end

        % Find nearest column
        [~, col] = min(abs(x2 - target2th));
        intensitySlice = I(:, col);

        % Create polar figure
        poleFig = figure('Name', sprintf('Pole Figure — 2%s = %.3f%s', ...
            char(952), x2(col), char(176)), ...
            'NumberTitle', 'off');
        pax = polaraxes(poleFig);

        % Convert omega/chi to radians for polar plot
        thetaRad = deg2rad(x1);
        polarplot(pax, thetaRad, intensitySlice, '-', 'LineWidth', 1.5);
        title(pax, sprintf('Intensity at 2%s = %.3f%s', char(952), x2(col), char(176)));
        pax.ThetaZeroLocation = 'top';
        pax.ThetaDir = 'clockwise';

        figure(poleFig);
    end

    function draw2DMap(targetAx, ds)
    %DRAW2DMAP  Render a 2D area-detector intensity map into targetAx.
    %   Uses imagesc (Heatmap) or contour/contourf (Contour / Filled Contour).
    %   cbLogY is reinterpreted as log-intensity toggle for 2D maps.
    %   Axis limits from ds.axLims are applied when present.
        ps  = ds.data.metadata.parserSpecific;
        map = ps.map2D;
        I   = map.intensity;

        x2 = map.axis2(:)';  % 2Theta [1×M]
        x1 = map.axis1(:);   % Omega / Chi / Phi [N×1]

        % Determine whether to render in Q-space (non-uniform Qx/Qz grid)
        useQSpace = cbMap2DQSpace.Value && isfield(map, 'Qx');
        if useQSpace
            Xmat = map.Qx;   % [N×M]  Qx grid
            Ymat = map.Qz;   % [N×M]  Qz grid
            xLbl = 'Q_x (Å^{-1})';
            yLbl = 'Q_z (Å^{-1})';
        else
            [Xmat, Ymat] = meshgrid(x2, x1);   % uniform angle-space grid
            xLbl = [map.axis2Name ' (' map.axis2Unit ')'];
            yLbl = [map.axis1Name ' (' map.axis1Unit ')'];
        end

        % Log intensity (cbLogY re-purposed as log-I for 2D)
        if cbLogY.Value
            I = log10(max(I, 1e-9));
        end

        % Per-axes colormap — handle custom palettes and the 'lines' special case
        cmapName = ddColormap.Value;
        try
            switch lower(cmapName)
                case {'lines (matlab default)', 'lines'}
                    colormap(targetAx, parula(256));   % lines is discrete, not suitable for maps
                case 'viridis'
                    colormap(targetAx, generateViridis(256));
                case 'plasma'
                    colormap(targetAx, generatePlasma(256));
                case 'inferno'
                    colormap(targetAx, generateInferno(256));
                otherwise
                    colormap(targetAx, feval(cmapName, 256));
            end
        catch
            colormap(targetAx, parula(256));
        end

        nLvl = round(efMap2DContourN.Value);
        switch ddMap2DType.Value
            case 'Heatmap'
                if useQSpace
                    % pcolor requires (N+1)×(M+1) for shading flat, but non-uniform
                    % grids can be passed directly with shading interp/flat on NxM data
                    pcolor(targetAx, Xmat, Ymat, I);
                    shading(targetAx, 'flat');
                else
                    imagesc(targetAx, x2, x1, I);
                    targetAx.YDir = 'normal';
                end
            case 'Contour'
                contour(targetAx, Xmat, Ymat, I, nLvl);
            otherwise  % 'Filled Contour'
                contourf(targetAx, Xmat, Ymat, I, nLvl);
        end

        % Colorbar with intensity unit label
        if cbLogY.Value
            cbStr = ['log_{10}(I / ' map.intensityUnit ')'];
        else
            cbStr = ['I (' map.intensityUnit ')'];
        end
        cbh = colorbar(targetAx);
        cbh.Label.String      = cbStr;
        cbh.Label.Interpreter = 'tex';

        xlabel(targetAx, xLbl, 'Interpreter', 'tex');
        ylabel(targetAx, yLbl, 'Interpreter', 'tex');

        % Title: sample name or filename
        sName = '';
        if isfield(ps, 'sampleName') && ~isempty(ps.sampleName)
            sName = ps.sampleName;
        end
        if isempty(sName)
            [~, fn, fext] = fileparts(ds.filepath);
            sName = [fn fext];
        end
        title(targetAx, sName, 'Interpreter', 'none');

        % Restore saved axis limits if present
        if isfield(ds, 'axLims')
            aL  = ds.axLims;
            xlo = str2num_trim(aL.xMin);  xhi = str2num_trim(aL.xMax);
            ylo = str2num_trim(aL.yMin);  yhi = str2num_trim(aL.yMax);
            if ~isnan(xlo) && ~isnan(xhi) && xhi > xlo
                targetAx.XLim = [xlo, xhi];
            end
            if ~isnan(ylo) && ~isnan(yhi) && yhi > ylo
                targetAx.YLim = [ylo, yhi];
            end
        end
    end

    function extract2DLineCut(clickX, clickY, isHorizontal)
    %EXTRACT2DLINECUT  Extract a 1D slice from the active 2D intensity map.
    %   isHorizontal == true  (Shift+click): row cut — fixed Omega → I vs 2Theta
    %   isHorizontal == false (Ctrl+click):  col cut — fixed 2Theta → I vs Omega
    %   The extracted profile is added as a new dataset in appData.datasets.
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        if ~is2DDataset(ds), return; end

        map = ds.data.metadata.parserSpecific.map2D;
        [~, fn, fext] = fileparts(ds.filepath);

        % Determine whether the axes are currently displaying Q-space coordinates
        useQSpace = cbMap2DQSpace.Value && isfield(map, 'Qx');

        if isHorizontal
            if useQSpace
                % Shift+click in Q-space: find row whose mean Qz is closest to clickY
                meanQz = mean(map.Qz, 2);   % [N×1]
                [~, rowIdx] = min(abs(meanQz - clickY));
                xVec = map.Qx(rowIdx, :)';
                xColName = 'Q_x (Ang^-1)';
                cutLabel = sprintf('H-cut  Qz\x2248%.4g \x212B\x207B\xB9', meanQz(rowIdx));
            else
                [~, rowIdx] = min(abs(map.axis1 - clickY));
                xVec = map.axis2(:);
                xColName = [map.axis2Name ' (' map.axis2Unit ')'];
                cutLabel = sprintf('H-cut  %s=%.4g %s', ...
                    map.axis1Name, map.axis1(rowIdx), map.axis1Unit);
            end
            yVec = map.intensity(rowIdx, :)';
        else
            if useQSpace
                % Ctrl+click in Q-space: find col whose mean Qx is closest to clickX
                meanQx = mean(map.Qx, 1);   % [1×M]
                [~, colIdx] = min(abs(meanQx - clickX));
                xVec = map.Qz(:, colIdx);
                xColName = 'Q_z (Ang^-1)';
                cutLabel = sprintf('V-cut  Qx\x2248%.4g \x212B\x207B\xB9', meanQx(colIdx));
            else
                [~, colIdx] = min(abs(map.axis2 - clickX));
                xVec = map.axis1(:);
                xColName = [map.axis1Name ' (' map.axis1Unit ')'];
                cutLabel = sprintf('V-cut  %s=%.4g %s', ...
                    map.axis2Name, map.axis2(colIdx), map.axis2Unit);
            end
            yVec = map.intensity(:, colIdx);
        end

        % Minimal metadata for the line-cut
        meta.source      = ds.filepath;
        meta.importDate  = datetime('now');
        meta.parserName  = 'lineCut';
        meta.xColumnName = xColName;
        meta.xColumnUnit = '';
        meta.parserSpecific = struct('is2D', false, ...
            'originFile', ds.filepath, 'cutLabel', cutLabel);
        cutData = parser.createDataStruct(xVec, yVec, ...
            'labels',   {['I (' map.intensityUnit ')']}, ...
            'units',    {map.intensityUnit}, ...
            'metadata', meta);

        newDs             = buildDs('[lineCut]', cutData, 'lineCut');
        newDs.displayName = cutLabel;
        newDs.legendName  = cutLabel;
        appData.datasets{end+1} = newDs;
        rebuildDatasetList(numel(appData.datasets));
        fprintf('[dataImportGUI] Line-cut added: %s — %s\n', [fn fext], cutLabel);
    end

    function onSmartScale(~,~)
    %ONSMARTSCALE  Auto-detect linear/log and set reasonable axis limits.
    %   Examines the plotted data to choose log scale when values span >2
    %   decades and are all positive, otherwise linear.  Sets axis limits
    %   to show all data with a small margin.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end

        % ── Collect visible X and Y data across all datasets ──────────
        allX = [];  allY = [];
        for si = 1:numel(appData.datasets)
            sds = appData.datasets{si};
            if isfield(sds,'visible') && ~sds.visible, continue; end
            sd = guiTernary(~isempty(sds.corrData), sds.corrData, sds.data);
            if isdatetime(sd.time), continue; end
            allX = [allX; double(sd.time(:))]; %#ok<AGROW>
            allY = [allY; sd.values(:)];       %#ok<AGROW>
        end
        if isempty(allX) || isempty(allY), return; end

        % Remove NaN/Inf for range analysis
        allX = allX(isfinite(allX));
        allY = allY(isfinite(allY));
        if isempty(allX) || isempty(allY), return; end

        % ── Decide log vs linear for each axis ───────────────────────
        % Log is appropriate when all values are positive and span >2
        % orders of magnitude (e.g. reflectivity 1e-6 to 1).
        xMin = min(allX);  xMax = max(allX);
        yMin = min(allY);  yMax = max(allY);

        useLogX = false;
        if xMin > 0 && xMax > 0 && xMax/xMin > 100
            useLogX = true;
        end
        useLogY = false;
        if yMin > 0 && yMax > 0 && yMax/yMin > 100
            useLogY = true;
        end

        cbLogX.Value = useLogX;
        cbLogY.Value = useLogY;

        % ── Set reasonable limits with margin ─────────────────────────
        if useLogX
            % Round to nearest decade with 0.5-decade margin
            efXMin.Value = sprintf('%.6g', 10^floor(log10(xMin)));
            efXMax.Value = sprintf('%.6g', 10^ceil(log10(xMax)));
        else
            xRange = xMax - xMin;
            if xRange == 0, xRange = max(abs(xMax), 1); end
            margin = xRange * 0.02;
            efXMin.Value = sprintf('%.6g', xMin - margin);
            efXMax.Value = sprintf('%.6g', xMax + margin);
        end

        if useLogY
            efYMin.Value = sprintf('%.6g', 10^floor(log10(yMin)));
            efYMax.Value = sprintf('%.6g', 10^ceil(log10(yMax)));
        else
            yRange = yMax - yMin;
            if yRange == 0, yRange = max(abs(yMax), 1); end
            margin = yRange * 0.05;
            efYMin.Value = sprintf('%.6g', yMin - margin);
            efYMax.Value = sprintf('%.6g', yMax + margin);
        end
        efXStep.Value = '';
        efYStep.Value = '';
        efY2Min.Value = '';  efY2Max.Value = '';  efY2Step.Value = '';

        saveAxisLimsToActiveDataset();
        onPlot([],[]);
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
        if     strcmp(dir, 'h_row12'), fig.Pointer = 'top';
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
        % Suppress "Negative data ignored" warning from ax.CurrentPoint
        % when log-scale axes contain negative data (fires every mouse move).
        wState = warning('off', 'MATLAB:Axes:NegativeDataInLogAxis');
        cp = ax.CurrentPoint;
        warning(wState);
        x  = cp(1,1);  y = cp(1,2);
        if x < ax.XLim(1) || x > ax.XLim(2) || ...
           y < ax.YLim(1) || y > ax.YLim(2)
            set(appData.cursorText, 'Visible', 'off');
            return;
        end
        cursorStr = sprintf('x = %.5g\ny = %.5g', x, y);

        % ── Peak identification on hover ────────────────────────────────
        % If the active dataset has fitted peaks, show info for the nearest
        % peak when the cursor is within 2× its FWHM.
        ds = appData.datasets{appData.activeIdx};
        if ~isempty(ds.peaks)
            bestDist = Inf;
            bestPk   = [];
            for pki = 1:numel(ds.peaks)
                pk = ds.peaks(pki);
                if isnan(pk.center), continue; end
                fwhmThr = guiTernary(~isnan(pk.fwhm) && pk.fwhm > 0, pk.fwhm * 2, Inf);
                dist = abs(x - pk.center);
                if dist < fwhmThr && dist < bestDist
                    bestDist = dist;
                    bestPk   = pk;
                end
            end
            if ~isempty(bestPk)
                pkInfo = sprintf('\n── Peak ──\ncenter = %.4f', bestPk.center);
                if ~isnan(bestPk.fwhm) && bestPk.fwhm > 0
                    pkInfo = [pkInfo, sprintf('\nFWHM = %.4f', bestPk.fwhm)];
                end
                % d-spacing if wavelength is available
                wl = extractWavelength_A(ds);
                if ~isnan(wl) && wl > 0 && bestPk.center > 0
                    dSpacing = wl / (2 * sind(bestPk.center / 2));
                    pkInfo = [pkInfo, sprintf('\nd = %.4f %s', dSpacing, char(197))];
                end
                cursorStr = [cursorStr, pkInfo];
            end
        end

        set(appData.cursorText, ...
            'String',  cursorStr, ...
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
        % 2D map line-cut (Shift+click = horizontal row, Ctrl+click = vertical col)
        if ~isempty(appData.datasets) && appData.activeIdx >= 1 && ...
                is2DDataset(appData.datasets{appData.activeIdx})
            mod = fig.CurrentModifier;
            if ismember('shift', mod)
                extract2DLineCut(x0, y0, true);
                return;
            elseif ismember('control', mod)
                extract2DLineCut(x0, y0, false);
                return;
            end
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
        % Only zoom if drag is at least 1% of the current axis span in both axes.
        % For log-scale axes, compare in log space so that zooming across
        % a few decades (visually large) isn't rejected as "too small."
        if strcmp(ax.XScale, 'log') && x0 > 0 && x1 > 0
            xDrag = abs(log10(x1) - log10(x0));
            xSpan = abs(log10(ax.XLim(2)) - log10(ax.XLim(1)));
        else
            xDrag = abs(x1 - x0);
            xSpan = diff(ax.XLim);
        end
        if strcmp(ax.YScale, 'log') && y0 > 0 && y1 > 0
            yDrag = abs(log10(y1) - log10(y0));
            ySpan = abs(log10(ax.YLim(2)) - log10(ax.YLim(1)));
        else
            yDrag = abs(y1 - y0);
            ySpan = diff(ax.YLim);
        end
        if xDrag < xSpan * 0.01 || yDrag < ySpan * 0.01
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

    function onFigureClose(~,~)
    %ONFIGURECLOSE  Clean up resources before closing the GUI figure.
        % Stop and delete animation timer if running
        if isfield(appData, 'animTimer') && ~isempty(appData.animTimer)
            if isvalid(appData.animTimer)
                stop(appData.animTimer);
                delete(appData.animTimer);
            end
            appData.animTimer = [];
        end
        delete(fig);
    end

    function onFigureKeyPress(~, e)
    %ONFIGUREKEYPRES  Handle keyboard shortcuts.
    %  Delete      — remove selected dataset(s)
    %  Ctrl+S      — save session
    %  Ctrl+Z      — undo corrections
    %  Ctrl+E      — export CSV
    %  Ctrl+C      — copy plot to clipboard
    %  Left/Right  — switch active dataset
    %  Space       — toggle dataset visibility
    %  Ctrl+Up     — move dataset up
    %  Ctrl+Down   — move dataset down
        hasMod  = ~isempty(e.Modifier);
        hasCtrl = hasMod && any(strcmp(e.Modifier, 'control'));

        switch e.Key
            case 'delete'
                if ~isempty(lbDatasets.Value) && ~isempty(appData.datasets)
                    onRemoveDataset([], []);
                end

            case 's'
                if hasCtrl, onSaveSession([], []); end

            case 'z'
                if hasCtrl, onUndoCorrections([], []); end

            case 'e'
                if hasCtrl, onSaveCSV([], []); end

            case 'c'
                if hasCtrl, onCopyToClipboard([], []); end

            case 'leftarrow'
                if ~hasCtrl && appData.activeIdx > 1
                    appData.activeIdx = appData.activeIdx - 1;
                    rebuildDatasetList(true);
                    updateControlsForActiveDataset();
                    onPlot([],[]);
                end

            case 'rightarrow'
                if ~hasCtrl && appData.activeIdx < numel(appData.datasets)
                    appData.activeIdx = appData.activeIdx + 1;
                    rebuildDatasetList(true);
                    updateControlsForActiveDataset();
                    onPlot([],[]);
                end

            case 'space'
                if ~isempty(appData.datasets) && appData.activeIdx > 0
                    onToggleDatasetVisibility([], []);
                end

            case 'uparrow'
                if hasCtrl, onMoveDatasetUp([], []); end

            case 'downarrow'
                if hasCtrl, onMoveDatasetDown([], []); end
        end
    end

    function onExportFigure(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end
        expFig = figure('Name','Exported Plot','NumberTitle','off');
        expAx  = axes(expFig);
        box(expAx,'on');
        grid(expAx,'on');
        drawToAxes(expAx);
        figure(expFig);   % bring to front
    end

    function onCopyToClipboard(~,~)
    %ONCOPYTOCLIPBOARD  Render the current plot into a temporary figure and copy
    %  it to the system clipboard as a vector EMF with transparent background.
    %  Falls back to bitmap if copygraphics is unavailable.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end
        % Spin up a lightweight off-screen figure so the GUI is not disturbed
        tmpFig = figure('Visible','off', ...
                        'Name','ClipboardCopy','NumberTitle','off', ...
                        'MenuBar','none','ToolBar','none', ...
                        'Color','none');
        tmpAx = axes(tmpFig);
        set(tmpAx, 'Color','none');
        box(tmpAx,'on');
        grid(tmpAx,'on');
        drawToAxes(tmpAx);
        styleAxesForExport(tmpAx);
        try
            % copygraphics (R2020a+): vector EMF with transparent background
            copygraphics(tmpAx, 'ContentType','vector', 'BackgroundColor','none');
        catch ME
            % Fallback: bitmap copy via print (Windows only)
            try
                print(tmpFig, '-clipboard', '-dmeta');
            catch ME2
                delete(tmpFig);
                uialert(fig, ...
                    sprintf(['Clipboard copy failed.\n\n' ...
                             '(%s)\n\nUse "Export to Figure" and copy from there.'], ...
                            ME2.message), ...
                    'Copy to clipboard failed');
                return;
            end
        end
        delete(tmpFig);
    end

    function onSaveFigure(~,~)
    %ONSAVEFIGURE  Export the current plot to a file using exportgraphics.
    %  The format and resolution are determined by the ddFigFormat dropdown.
    %  Renders into a temporary hidden figure (like onCopyToClipboard) so the
    %  GUI uiaxes is not disturbed.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end

        % Map dropdown choice to file extension and exportgraphics options
        fmtStr = ddFigFormat.Value;
        switch fmtStr
            case 'PNG (300 dpi)'
                ext      = '.png';
                fmtFilter = {'*.png','PNG image (*.png)'};
                egOpts   = {'ContentType','image','Resolution',300};
            case 'PDF (vector)'
                ext      = '.pdf';
                fmtFilter = {'*.pdf','PDF vector (*.pdf)'};
                egOpts   = {'ContentType','vector'};
            case 'SVG (vector)'
                ext      = '.svg';
                fmtFilter = {'*.svg','SVG vector (*.svg)'};
                egOpts   = {'ContentType','vector'};
            case 'TIFF (300 dpi)'
                ext      = '.tif';
                fmtFilter = {'*.tif','TIFF image (*.tif)'};
                egOpts   = {'ContentType','image','Resolution',300};
            otherwise
                ext      = '.png';
                fmtFilter = {'*.png','PNG image (*.png)'};
                egOpts   = {'ContentType','image','Resolution',300};
        end

        % Suggest a filename based on the active dataset
        ds = appData.datasets{appData.activeIdx};
        [dPath, dName, ~] = fileparts(ds.filepath);
        defPath = fullfile(dPath, [dName, ext]);

        [fname, fpath] = uiputfile(fmtFilter, 'Save figure as...', defPath);
        if isequal(fname, 0), return; end
        outPath = fullfile(fpath, fname);

        % Render into a hidden figure
        tmpFig = figure('Visible','off','Name','SaveFig','NumberTitle','off', ...
                        'MenuBar','none','ToolBar','none', ...
                        'Units','inches','Position',[0 0 7 5]);
        tmpAx = axes(tmpFig);
        box(tmpAx,'on');
        grid(tmpAx,'on');
        drawToAxes(tmpAx);
        styleAxesForExport(tmpAx);
        try
            exportgraphics(tmpFig, outPath, egOpts{:});
            delete(tmpFig);
            uialert(fig, sprintf('Saved:\n%s', outPath), 'Figure Saved');
        catch ME
            delete(tmpFig);
            logGUIError('Save error (exportgraphics)', ME.message, ME);
            uialert(fig, sprintf('exportgraphics failed:\n%s', ME.message), 'Save error');
        end
    end

    function styleAxesForExport(expAx)
    %STYLEAXESFOREXPORT  Make axes readable on white backgrounds.
    %  Darkens axis lines, ticks, and labels; thickens the bounding box.
    %  Applied only to temporary export figures (clipboard / save).
        darkColor = [0.15 0.15 0.15];
        expAx.XColor    = darkColor;
        expAx.YColor    = darkColor;
        expAx.LineWidth = 1.2;
        expAx.FontSize  = 13;
        % Darken axis labels
        if ~isempty(expAx.XLabel.String)
            expAx.XLabel.Color = darkColor;
        end
        if ~isempty(expAx.YLabel.String)
            expAx.YLabel.Color = darkColor;
        end
        if ~isempty(expAx.Title.String)
            expAx.Title.Color = darkColor;
        end
        % Style right Y-axis if it exists
        if isprop(expAx, 'YAxis') && numel(expAx.YAxis) > 1
            expAx.YAxis(2).Color = darkColor;
        end
        % Thicken data lines for better visibility
        lines = findobj(expAx, 'Type', 'Line');
        for li = 1:numel(lines)
            if lines(li).LineWidth < 1.2
                lines(li).LineWidth = 1.2;
            end
        end
    end

    % ── Session save / load ───────────────────────────────────────────────

    function onSaveSession(~,~)
    %ONSAVESESSION  Save all datasets, corrections, peaks, and key UI settings
    %  to a .mat file so the session can be restored later with onLoadSession.
        if isempty(appData.datasets)
            uialert(fig,'Nothing to save — load some files first.','No data'); return;
        end

        % Suggest path based on first dataset
        ds1 = appData.datasets{1};
        [dPath, dName, ~] = fileparts(ds1.filepath);
        defPath = fullfile(dPath, [dName, '_session.mat']);

        [fname, fpath] = uiputfile({'*.mat','MATLAB session (*.mat)'}, ...
            'Save session as...', defPath);
        if isequal(fname, 0), return; end
        outPath = fullfile(fpath, fname);

        % Collect datasets and current UI settings to persist
        savedDatasets  = appData.datasets;
        savedActiveIdx = appData.activeIdx;
        savedBgFile    = appData.bgFile;
        savedBgDataset = appData.bgDataset;
        savedStyle     = appData.style;
        savedLastDir   = appData.lastDir;
        savedColormap  = ddColormap.Value;
        savedXSel      = ddX.Value;
        savedYSel      = ensureCell(lbY.Value);
        savedY2Sel     = ensureCell(lbY2.Value);
        savedLogX      = cbLogX.Value;
        savedLogY      = cbLogY.Value;

        try
            save(outPath, 'savedDatasets', 'savedActiveIdx', ...
                          'savedBgFile', 'savedBgDataset', ...
                          'savedStyle', 'savedLastDir', ...
                          'savedColormap', 'savedXSel', ...
                          'savedYSel', 'savedY2Sel', ...
                          'savedLogX', 'savedLogY', ...
                          '-v7.3');
            uialert(fig, sprintf('Session saved:\n%s', outPath), 'Session Saved');
        catch ME
            logGUIError('Session Save Error', ME.message, ME);
            uialert(fig, sprintf('Save failed:\n%s', ME.message), 'Session Save Error');
        end
    end

    function onLoadSession(~,~)
    %ONLOADSESSION  Restore a previously saved session from a .mat file.
    %  Replaces all current datasets with those from the file, then refreshes
    %  all controls.
        startDir = guiTernary(isempty(appData.lastDir), pwd, appData.lastDir);
        [fname, fpath] = uigetfile({'*.mat','MATLAB session (*.mat)'}, ...
            'Load session file...', startDir);
        if isequal(fname, 0), return; end
        matPath = fullfile(fpath, fname);

        try
            S = load(matPath, '-mat');
        catch ME
            logGUIError('Load Error', ME.message, ME);
            uialert(fig, sprintf('Could not load file:\n%s', ME.message), 'Load Error');
            return;
        end

        % Validate required field
        if ~isfield(S, 'savedDatasets')
            uialert(fig, 'File does not appear to be a valid session file.', 'Load Error');
            return;
        end

        cancelInteractions();

        % Restore core data
        appData.datasets  = S.savedDatasets;
        appData.activeIdx = guiTernary(isfield(S,'savedActiveIdx') && ...
            S.savedActiveIdx >= 1 && S.savedActiveIdx <= numel(S.savedDatasets), ...
            S.savedActiveIdx, 1);
        appData.bgFile    = guiTernary(isfield(S,'savedBgFile'),    S.savedBgFile,    '');
        appData.bgDataset = guiTernary(isfield(S,'savedBgDataset'), S.savedBgDataset, []);
        appData.style     = guiTernary(isfield(S,'savedStyle'),     S.savedStyle,     'Line');
        appData.lastDir   = guiTernary(isfield(S,'savedLastDir'),   S.savedLastDir,   '');

        % parserVersion compatibility check (#18): warn if session was created before v1.0
        nLegacy = sum(cellfun(@(ds) ...
            ~isfield(ds.data.metadata, 'parserVersion'), appData.datasets));
        if nLegacy > 0
            warning('dataImportGUI:legacySession', ...
                ['%d dataset(s) in this session were imported before parser versioning was introduced.\n' ...
                 'Data should load correctly; re-import files to attach version metadata.'], nLegacy);
        end

        % Backward-compat: ensure snipBackground field exists for old sessions
        for di = 1:numel(appData.datasets)
            if ~isfield(appData.datasets{di}, 'snipBackground')
                appData.datasets{di}.snipBackground = struct('x', [], 'bg', []);
            end
        end

        if isempty(appData.datasets)
            rebuildDatasetList(false);
            return;
        end

        % Restore UI settings
        if isfield(S,'savedColormap') && ismember(S.savedColormap, ddColormap.Items)
            ddColormap.Value = S.savedColormap;
        end
        if isfield(S,'savedLogX'), cbLogX.Value = S.savedLogX; end
        if isfield(S,'savedLogY'), cbLogY.Value = S.savedLogY; end

        % Restore plot style button appearance
        onStylePick(appData.style);

        % Restore BG file display
        if ~isempty(appData.bgFile)
            efBGFile.Value = appData.bgFile;
        end

        % Clear search filter so all datasets are visible on load
        appData.searchFilter = '';
        efDatasetSearch.Value = '';

        rebuildDatasetList(true);
        updateControlsForActiveDataset();

        % Restore axis channel selections (best-effort — may not match new dataset)
        if isfield(S,'savedXSel') && ismember(S.savedXSel, ddX.Items)
            ddX.Value = S.savedXSel;
        end
        if isfield(S,'savedYSel')
            validY = S.savedYSel(ismember(S.savedYSel, lbY.Items));
            if ~isempty(validY), lbY.Value = validY; end
        end
        if isfield(S,'savedY2Sel')
            validY2 = S.savedY2Sel(ismember(S.savedY2Sel, lbY2.Items));
            if ~isempty(validY2), lbY2.Value = validY2; end
        end

        onPlot([],[]);
        uialert(fig, sprintf('Session loaded: %d dataset(s)', numel(appData.datasets)), ...
            'Session Loaded');
    end

    % ── Panel drag-resize ────────────────────────────────────────────────

    function dir = detectResizeBorder()
    %DETECTRESIZEBORDER  Check whether fig.CurrentPoint is within SNAP_PX of a
    %  resizable panel border.  Returns:
    %    'h_row12' — horizontal border between content row (1) and analysis row (2)
    %    'v_col12' — vertical border between corrections col (1) and axis-limits col (2)
    %    'v_col23' — vertical border between axis-limits col (2) and peak col (3)  [XRD only]
    %    'v_col34' — vertical border between peak col (3) and save col (4)         [XRD only]
    %    ''        — not near any known border
        SNAP_PX = 5;
        dir = '';
        try
            mp   = fig.CurrentPoint;                        % [x y] from figure bottom-left
            aPos = getpixelposition(analysisPanel, true);   % [l b w h] relative to figure

            % h_row12: top edge of the analysis panel
            borderY = aPos(2) + aPos(4);
            if abs(mp(2) - borderY) <= SNAP_PX && ...
               mp(1) >= aPos(1) && mp(1) <= aPos(1) + aPos(3)
                dir = 'h_row12'; return;
            end

            % Vertical borders — only test inside the analysis panel's y-band
            if mp(2) >= aPos(2) && mp(2) <= aPos(2) + aPos(4)

                % v_col12: right edge of corrections panel
                cPos    = getpixelposition(corrPanel, true);
                borderX = cPos(1) + cPos(3);
                if abs(mp(1) - borderX) <= SNAP_PX
                    dir = 'v_col12'; return;
                end

                if strcmp(peakPanel.Visible, 'on')
                    % v_col23: right edge of axis-limits panel (XRD mode)
                    alPos   = getpixelposition(axLimPanel, true);
                    borderX = alPos(1) + alPos(3);
                    if abs(mp(1) - borderX) <= SNAP_PX
                        dir = 'v_col23'; return;
                    end

                    % v_col34: right edge of peak-analysis panel (XRD mode)
                    pkPos   = getpixelposition(peakPanel, true);
                    borderX = pkPos(1) + pkPos(3);
                    if abs(mp(1) - borderX) <= SNAP_PX
                        dir = 'v_col34'; return;
                    end
                else
                    % v_col23: gap between axis-limits and save panels (non-XRD).
                    % Column 3 is hidden (width=0) but ColumnSpacing creates a
                    % ~20px gap.  Detect anywhere in that gap.
                    alPos = getpixelposition(axLimPanel, true);
                    spPos = getpixelposition(savePanel, true);
                    rightOfAL = alPos(1) + alPos(3);
                    leftOfSP  = spPos(1);
                    if mp(1) >= rightOfAL - SNAP_PX && mp(1) <= leftOfSP + SNAP_PX
                        dir = 'v_col23'; return;
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
            % Snapshot the current analysis panel height (px)
            try
                aPos = getpixelposition(analysisPanel, true);
                appData.panelResizeOrig = aPos(4);
            catch
                rh = rootGL.RowHeight;
                appData.panelResizeOrig = guiTernary(isnumeric(rh{2}), rh{2}, 400);
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
            if strcmp(peakPanel.Visible, 'on')
                % XRD mode: snapshot the current axis-limits panel width (px)
                try
                    alPos = getpixelposition(axLimPanel, true);
                    appData.panelResizeOrig = alPos(3);
                catch
                    appData.panelResizeOrig = appData.axLimPanelWidth;
                end
            else
                % Non-XRD mode: snapshot the save panel width (col 4)
                try
                    spPos = getpixelposition(savePanel, true);
                    appData.panelResizeOrig = spPos(3);
                catch
                    cw = analysisGL.ColumnWidth;
                    appData.panelResizeOrig = guiTernary(isnumeric(cw{4}), cw{4}, 120);
                end
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
            % Mouse moves up (mp(2) increases) → analysis panel gets taller
            delta_y = mp(2) - appData.panelResizeStart(2);
            figH    = fig.Position(4);
            % Available px after padding + 1 RowSpacing gap
            %   rootGL: Padding [8 8 8 8] → 16 px;  1 RowSpacing gap of 6 → 6 px
            availH  = figH - 16 - 6;
            newH    = round(appData.panelResizeOrig + delta_y);
            newH    = max(200, min(newH, availH - 100));  % leave ≥ 100 px for preview
            rootGL.RowHeight = {'1x', newH};

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
            delta_x = mp(1) - appData.panelResizeStart(1);
            if strcmp(peakPanel.Visible, 'on')
                % XRD mode: mouse moves right → axis-limits panel gets wider
                newW    = round(appData.panelResizeOrig + delta_x);
                newW    = max(150, min(newW, 500));
                appData.axLimPanelWidth = newW;
                cw    = analysisGL.ColumnWidth;
                cw{2} = newW;
                analysisGL.ColumnWidth = cw;
            else
                % Non-XRD mode: resize save panel (col 4); col 2 stays '1x'
                % Drag left → save panel wider; drag right → save panel narrower
                newW    = round(appData.panelResizeOrig - delta_x);
                newW    = max(100, min(newW, 400));
                cw    = analysisGL.ColumnWidth;
                cw{4} = newW;
                analysisGL.ColumnWidth = cw;
            end

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
    %COMPUTEAUTOWATERFALLSPACING  Return spacing for automatic waterfall.
    %  Linear mode: 1.1× the maximum data range (additive offset).
    %  Log mode:    10^(1.1 × max log-range) as a multiplicative factor.
        ySel = ensureCell(lbY.Value);
        if cbLogY.Value
            % Log mode — return a multiplier (ratio between adjacent traces)
            s = 10;   % safe fallback: one decade
            if isempty(ySel), return; end
            maxLogRange = 0;
            for ddi = 1:numel(appData.datasets)
                ds2      = appData.datasets{ddi};
                primaryD = guiTernary(~isempty(ds2.corrData), ds2.corrData, ds2.data);
                idx2     = find(strcmp(primaryD.labels, ySel{1}), 1);
                if isempty(idx2), continue; end
                yVals = primaryD.values(:, idx2);
                yVals = yVals(yVals > 0 & ~isnan(yVals));
                if numel(yVals) < 2, continue; end
                r = log10(max(yVals)) - log10(min(yVals));
                if r > maxLogRange, maxLogRange = r; end
            end
            if maxLogRange > 0, s = 10^(maxLogRange * 1.1); end
        else
            % Linear mode — return an additive offset
            s = 1;   % safe fallback if no data range can be determined
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
        lbDatasets.Value           = {tgt};
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

    function logGUIError(title, msg, ME)
    %LOGGUI ERROR  Append an error entry to gui_bug_log.txt next to this file.
    %   Called alongside every uialert that surfaces a caught exception so that
    %   errors can be reviewed and triaged in a future code session.
    %   ME may be [] if no MException is available.
        try
            fid = fopen(BUG_LOG_FILE, 'a');
            if fid == -1, return; end
            stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
            fprintf(fid, '
%s
', repmat('=', 1, 68));
            fprintf(fid, '[%s]  %s
', stamp, title);
            fprintf(fid, 'Message: %s
', msg);
            if ~isempty(ME)
                if ~isempty(ME.identifier)
                    fprintf(fid, 'Identifier: %s
', ME.identifier);
                end
                if ~isempty(ME.stack)
                    fprintf(fid, 'Stack:
');
                    for si = 1:numel(ME.stack)
                        fprintf(fid, '  %s  (line %d)
', ...
                            ME.stack(si).name, ME.stack(si).line);
                    end
                end
            end
            fclose(fid);
        catch
            % Never let logging crash the GUI
        end
    end

    function toggleY2Appearance(active)
    %TOGGLEY2APPEARANCE  Show/hide right-axis appearance controls in the combined panel.
    %  When active (true): L fields span cols 2-3, R fields visible in col 4.
    %  When inactive: L fields span cols 2-4, R fields hidden.
        if active
            ddDatasetColor.Layout.Column  = [2 3];
            ddDatasetColorR.Visible       = 'on';
            efLegendName.Layout.Column    = [2 3];
            efLegendNameR.Visible         = 'on';
            efCustomYLabel.Layout.Column  = [2 3];
            efCustomY2Label.Visible       = 'on';
        else
            ddDatasetColor.Layout.Column  = [2 4];
            ddDatasetColorR.Visible       = 'off';
            efLegendName.Layout.Column    = [2 4];
            efLegendNameR.Visible         = 'off';
            efCustomYLabel.Layout.Column  = [2 4];
            efCustomY2Label.Visible       = 'off';
        end
    end

    % Return api struct only when caller requests it (suppress command-window dump)
    if nargout > 0
        varargout{1} = api;
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

function ds = buildDs(fp, data, parserName)
%BUILDDS  Assemble the standard dataset struct from a parsed data struct.
    ds.data        = data;
    ds.filepath    = fp;
    ds.parserName  = parserName;
    ds.displayName = '';          % '' = use filepath-derived name in rebuildDatasetList
    ds.visible     = true;        % Visibility toggle for hiding datasets without removing them
    ds.corrData    = [];
    ds.xOff        = 0;
    ds.yOff        = guiTernary(isNeutronParser(parserName), 1, 0);
    ds.bgSlope     = 0;
    ds.bgInt       = 0;
    ds.bgPoly      = [];          % polynomial BG coefficients (polyfit output); [] = use linear
    ds.undoState   = struct();    % Stores previous correction state for one-level undo
    ds.annotations = {};          % Cell array of annotation structs {x, y, text}
    ds.color         = [];        % [] = Auto (lines() palette); [r g b] = override
    ds.colorR        = [];        % [] = Auto for right-axis channels
    ds.legendName    = '';        % '' = Auto (built from channel name)
    ds.legendNameR   = '';        % '' = Auto for right-axis channels
    ds.smoothEnabled = false;
    ds.smoothWindow  = 5;
    ds.smoothMethod  = 'Moving';
    ds.normMethod    = 'None';
    ds.xTrimMin      = NaN;
    ds.xTrimMax      = NaN;
    ds.wavelengthOverride_A = NaN; % NaN = use metadata; set by user efWavelength field
    ds.peaks       = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
                            'xRange',{},'status',{},'bg',{},'model',{},'eta',{});
    ds.axLims      = struct('xMin','','xMax','','xStep','', ...
                            'yMin','','yMax','','yStep','', ...
                            'y2Min','','y2Max','','y2Step','');
    ds.latticeParams  = [];   % struct with refined lattice parameters (set by Refine Lattice)
    ds.filmThickness  = [];   % struct with FFT-derived film thickness (set by FFT Thickness)
    ds.williamsonHall = [];   % struct with W-H analysis results (set by W-H Plot)
    ds.snipBackground = struct('x', [], 'bg', []);  % SNIP-estimated background (set by Auto Peak)
end


function [data, parserName] = guiImport(fp)
%GUIIMPORT  Dispatch to the correct parser and return both data and parser name.
%   Uses centralized resolveParser for extension→parser mapping.

    resolveResult = parser.resolveParser(fp);
    parserName = resolveResult.name;

    % GUI-specific parameters for each parser
    switch parserName
        case 'importRigaku_raw'
            data = parser.importRigaku_raw(fp);

        case 'importXRDML'
            % Load raw counts; the GUI's Cts/s toggle handles cps conversion.
            data = parser.importXRDML(fp, Intensity='counts');

        case 'importBruker'
            data = parser.importBruker(fp);

        case 'importExcel'
            data = parser.importExcel(fp);

        case 'importCSV'
            data = parser.importCSV(fp);

        case 'importNCNRRefl'
            data = parser.importNCNRRefl(fp);

        case 'importNCNRPNR'
            data = parser.importNCNRPNR(fp);

        case 'importNCNRDat'
            % NCNR refl1d output: polarization encoded in extension
            data = parser.importNCNRDat(fp);

        case 'importQDVSM'
            % Load every available channel so the user can explore them in the GUI.
            try
                data = parser.importQDVSM(fp, 'Verbose', false, 'YAxis', 'all');
            catch ME
                if contains(ME.message,'[Data]','IgnoreCase',true)
                    % Fall back to PPMS format
                    data = parser.importPPMS(fp, 'YAxis', 'all');
                    parserName = 'importPPMS';
                else
                    rethrow(ME);
                end
            end

        case 'importPPMS'
            data = parser.importPPMS(fp, 'YAxis', 'all');

        otherwise
            error('dataImportGUI:unknownExt', ...
                ['No parser for extension "%s" (resolved as "%s").\n' ...
                 'Supported: .raw, .xrdml, .brml, .xlsx/.xls/.xlsm/.xlsb/.ods, ' ...
                 '.csv/.tsv/.txt, .refl, .pnr, .datA/B/C/D, .dat'], ...
                extractFileExt(fp), parserName);
    end
end

% ────────────────────────────────────────────────────────────────────
function ext = extractFileExt(fp)
    [~, ~, ext] = fileparts(fp);
    ext = lower(ext);
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

% Helper: convert NaN ↔ empty string for text-based trim fields
function s = nan2str(x)
    if isnan(x), s = ''; else, s = num2str(x); end
end

function x = str2num_trim(s)
    x = str2double(s);
    if isnan(x), x = NaN; end
end


function c = ensureCell(v)
%ENSURECELL  Wrap a char/string scalar in a cell array; pass cell arrays through.
    if ischar(v) || isstring(v)
        c = cellstr(v);
    else
        c = v;
    end
end


function guiSaveCSV(d, fp, dRaw, asymData, fmt)
%GUISAVECSV  Write a data struct to a comma-delimited CSV file.
%   Columns: x-axis (d.time) then all y-channels (d.values).
%   A header row of column names (with units in parentheses) is written first.
%
%   guiSaveCSV(d, fp)                      — write data only (standard CSV)
%   guiSaveCSV(d, fp, dRaw)               — append raw data columns after corrected
%   guiSaveCSV(d, fp, dRaw, asymD)        — also append spin asymmetry columns
%   guiSaveCSV(d, fp, dRaw, asymD, fmt)   — fmt = 'standard' (default) or 'origin'
%
%   When dRaw is supplied the headers are suffixed:
%     corrected  →  'X [corr]', 'Label (unit) [corr]', ...
%     raw        →  'X [raw]',  'Label (unit) [raw]',  ...
%
%   When fmt = 'origin', three header rows are written:
%     Row 1: Long Name  (label without units)
%     Row 2: Units      (extracted from parentheses)
%     Row 3: Comments   (column designations: X, Y, yEr)

    if nargin < 5 || isempty(fmt), fmt = 'standard'; end
    if nargin < 4, asymData = []; end
    if nargin < 3, dRaw = []; end

    hasRaw  = ~isempty(dRaw) && isstruct(dRaw) && isfield(dRaw, 'time');
    hasAsym = ~isempty(asymData) && isstruct(asymData) && isfield(asymData, 'headers') && ~isempty(asymData.headers);
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

    if hasAsym
        allHdrs = [allHdrs, asymData.headers];
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
    closeGuard = onCleanup(@() fclose(fid));

    % ── Header ────────────────────────────────────────────────────────
    if strcmp(fmt, 'origin')
        longNames = cellfun(@(h) strtrim(regexprep(h, '\s*\([^)]+\)', '')), ...
                            allHdrs, 'UniformOutput', false);
        units = cellfun(@extractUnitFromHeader, allHdrs, 'UniformOutput', false);
        desigs = buildColumnDesignations(allHdrs);
        fprintf(fid, '%s\n', strjoin(longNames, ','));
        fprintf(fid, '%s\n', strjoin(units, ','));
        fprintf(fid, '%s\n', strjoin(desigs, ','));
    else
        fprintf(fid, '%s\n', strjoin(allHdrs, ','));
    end

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
        % Asymmetry columns (appended for paired neutron data)
        if hasAsym && r <= size(asymData.values, 1)
            for c = 1:size(asymData.values, 2)
                fprintf(fid, ',%.10g', asymData.values(r, c));
            end
        end
        fprintf(fid, '\n');
    end
end


function unit = extractUnitFromHeader(hdr)
%EXTRACTUNITFROMHEADER  Extract text inside parentheses from a header string.
%   'Moment (emu) [corr]' → 'emu';  'X [raw]' → ''
    tok = regexp(hdr, '\(([^)]+)\)', 'tokens', 'once');
    if ~isempty(tok)
        unit = tok{1};
    else
        unit = '';
    end
end


function desigs = buildColumnDesignations(hdrs)
%BUILDCOLUMNDESIGNATIONS  Map header names to Origin column designations.
%   First column → 'X'.  Headers containing error-like keywords → 'yEr'.
%   Any column named 'X [raw]' → 'X'.  All others → 'Y'.
    desigs = cell(size(hdrs));
    for k = 1:numel(hdrs)
        lbl = lower(hdrs{k});
        if k == 1 || startsWith(lbl, 'x ')
            desigs{k} = 'X';
        elseif contains(lbl, {'err', 'dr_', 'dr ', 'dasym', 'std', 'sigma'})
            desigs{k} = 'yEr';
        else
            desigs{k} = 'Y';
        end
    end
end


function unit = extractXUnitFromStruct(d)
%EXTRACTXUNITFROMSTRUCT  Get X-axis unit string from a data struct's metadata.
    unit = '';
    if ~isfield(d, 'metadata'), return; end
    m = d.metadata;
    if isfield(m, 'xColumnUnit') && ~isempty(m.xColumnUnit)
        unit = char(m.xColumnUnit);
    elseif isfield(m, 'parserSpecific') && isfield(m.parserSpecific, 'xUnit')
        unit = char(m.parserSpecific.xUnit);
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
                out{end+1} = sprintf('%-14s %g', [fname ':'], val); %#ok<AGROW>
            elseif (ischar(val) || (isstring(val) && isscalar(val))) && ~isempty(val)
                out{end+1} = sprintf('%-14s %s', [fname ':'], char(val)); %#ok<AGROW>
            elseif iscell(val) && ~isempty(val) && numel(val) <= 4
                out{end+1} = sprintf('%-14s %s', [fname ':'], strjoin(val, ', ')); %#ok<AGROW>
            elseif isstruct(val)
                % Sub-struct: show up to 4 scalar fields
                subFn = fieldnames(val);
                out{end+1} = sprintf('%s:', fname); %#ok<AGROW>
                shown = 0;
                for sfi = 1:numel(subFn)
                    sv = val.(subFn{sfi});
                    if (ischar(sv) || (isnumeric(sv) && isscalar(sv))) && shown < 4
                        out{end+1} = sprintf('  %-12s %s', [subFn{sfi} ':'], num2str(sv)); %#ok<AGROW>
                        shown = shown + 1;
                    end
                end
            elseif iscell(val) && ~isempty(val)
                % Cell array (allColumnNames etc.) — list items
                out{end+1} = sprintf('%s  (%d):', fname, numel(val)); %#ok<AGROW>
                for ci = 1:numel(val)
                    out{end+1} = sprintf('  %s', val{ci}); %#ok<AGROW>
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
            out{end+1} = sprintf('  Y%d: %s  (all NaN)', k, lbl); %#ok<AGROW>
        else
            out{end+1} = sprintf('  Y%d: %s', k, lbl); %#ok<AGROW>
            out{end+1} = sprintf('       [%.4g, %.4g]', min(col), max(col)); %#ok<AGROW>
        end
    end
end


function lbl = guiParserLabel(parserName)
%GUIPARSERLABEL Human-readable description for each parser function.
    switch parserName
        case 'importRigaku_raw', lbl = 'Rigaku SmartLab XRD';
        case 'importXRDML',   lbl = 'PANalytical XRDML';
        case 'importBruker',  lbl = 'Bruker XRD';
        case 'importExcel',   lbl = 'Excel Spreadsheet';
        case 'importCSV',     lbl = 'Delimited Text';
        case 'importQDVSM',   lbl = 'Quantum Design VSM';
        case 'importPPMS',    lbl = 'QD PPMS (legacy)';
        case 'importMPMS',    lbl = 'QD MPMS SQUID';
        case 'importLakeShore', lbl = 'Lake Shore Magnetometer';
        case {'importNCNRDat', 'importNCNRRefl'}, lbl = 'NCNR Neutron Reflectometry';
        case 'importNCNRPNR', lbl = 'NCNR Polarized Neutron Reflectometry';
        otherwise,            lbl = parserName;
    end
end


function badge = getParserBadge(parserName)
%GETPARSERBADGE  Return a short parser type tag (e.g. [XRD], [VSM], [CSV]).
    switch parserName
        case {'importRigaku_raw', 'importXRDML', 'importBruker'}
            badge = '[XRD]';
        case {'importQDVSM', 'importPPMS', 'importMPMS', 'importLakeShore'}
            badge = '[MAG]';  % Magnetometry
        case {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'}
            badge = '[NR]';   % Neutron Reflectometry
        case {'importExcel', 'importCSV'}
            badge = '[DAT]';  % Generic data
        case 'lineCut'
            badge = '[CUT]';  % 1D line-cut extracted from a 2D map
        otherwise
            badge = '';
    end
end


function tf = is2DDataset(ds)
%IS2DDATASET  True when ds holds a 2D area-detector XRDML map.
%   Checks for the is2D flag added by importXRDML Phase 1.1-1.3.
    tf = isfield(ds, 'data') && ...
         isfield(ds.data, 'metadata') && ...
         isfield(ds.data.metadata, 'parserSpecific') && ...
         isfield(ds.data.metadata.parserSpecific, 'is2D') && ...
         isequal(ds.data.metadata.parserSpecific.is2D, true);
end


function tf = isNeutronParser(pName)
%ISNEUTRONPARSER  True when pName is an NCNR neutron reflectometry parser.
    tf = ismember(pName, {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'});
end


function baseName = neutronBaseName(filepath)
%NEUTRONBASENAME  Strip polarization suffixes to get the measurement base name.
%   Removes [_-](refl|pnr), [_-](NSF|SF), and trailing [_-][a-z] so that
%   all cross-sections from one measurement share the same base name.
%   Handles both dash and underscore separators.
    [~, fn, ~] = fileparts(filepath);
    fn = regexprep(fn, '[_-](refl|pnr)$', '', 'ignorecase');
    fn = regexprep(fn, '[_-](NSF|SF)$',   '', 'ignorecase');
    fn = regexprep(fn, '[_-][a-z]$',       '', 'ignorecase');
    baseName = fn;
end


function col = neutronPolarizationColor(polarization)
%NEUTRONPOLARIZATIONCOLOR  Fixed base color for each polarization channel.
%   ++ = blue, +- = red, -+ = green, -- = purple, '' = mid-gray
    switch polarization
        case '++'
            col = [0.12 0.47 0.71];
        case '+-'
            col = [0.80 0.15 0.15];
        case '-+'
            col = [0.18 0.63 0.18];
        case '--'
            col = [0.58 0.40 0.74];
        otherwise
            col = [0.40 0.40 0.40];
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


function colors = getColorsFromMap(colormapName, nColors)
%GETCOLORSFROMMPA  Generate nColors colors from a named colormap.
%   If colormapName is 'lines (MATLAB default)', uses the lines() function.
%   Otherwise, generates evenly-spaced colors from the specified colormap.
%
%   Output: colors [nColors × 3] RGB matrix

    % Handle MATLAB default
    if strcmpi(colormapName, 'lines (MATLAB default)')
        colors = lines(nColors);
        return;
    end

    % Normalize colormap name (remove spaces, handle common variants)
    cmName = lower(strrep(colormapName, ' ', ''));

    % Map common names to MATLAB built-in colormaps
    % For newer MATLAB versions, use the listed names directly
    % For older versions, use alternative colormaps
    switch cmName
        case 'jet',      colors = getMapFromBuiltin('jet', nColors);
        case 'turbo',    colors = getMapFromBuiltin('turbo', nColors);
        case 'hot',      colors = getMapFromBuiltin('hot', nColors);
        case 'cool',     colors = getMapFromBuiltin('cool', nColors);
        case 'spring',   colors = getMapFromBuiltin('spring', nColors);
        case 'summer',   colors = getMapFromBuiltin('summer', nColors);
        case 'autumn',   colors = getMapFromBuiltin('autumn', nColors);
        case 'winter',   colors = getMapFromBuiltin('winter', nColors);
        case 'gray',     colors = getMapFromBuiltin('gray', nColors);
        case 'copper',   colors = getMapFromBuiltin('copper', nColors);
        case 'pink',     colors = getMapFromBuiltin('pink', nColors);
        case 'bone',     colors = getMapFromBuiltin('bone', nColors);
        case 'hsv',      colors = getMapFromBuiltin('hsv', nColors);
        case 'parula',   colors = getMapFromBuiltin('parula', nColors);
        case 'viridis',  colors = generateViridis(nColors);
        case 'plasma',   colors = generatePlasma(nColors);
        case 'inferno',  colors = generateInferno(nColors);
        otherwise
            % Default to lines if unrecognized
            colors = lines(nColors);
    end
end


function colors = getMapFromBuiltin(mapName, nColors)
%GETMAPFROMBUILTIN  Sample colors from a MATLAB built-in colormap.
    try
        % Try the modern colormap() function (R2014b+)
        cmap = colormap(gca, mapName);
        if size(cmap, 1) >= nColors
            % Sample evenly from the colormap
            indices = round(linspace(1, size(cmap, 1), nColors));
            colors = cmap(indices, :);
        else
            % Colormap smaller than requested, interpolate
            indices = linspace(1, size(cmap, 1), nColors);
            colors = interp1(1:size(cmap, 1), cmap, indices);
        end
    catch
        % Fallback: use feval for older MATLAB versions
        try
            cmap = feval(mapName, 256);
            indices = round(linspace(1, 256, nColors));
            colors = cmap(indices, :);
        catch
            % If all else fails, use lines
            colors = lines(nColors);
        end
    end
end


function colors = generateViridis(nColors)
%GENERATEVIRIDIS  Create a viridis-like colormap (perceptually uniform).
%   Approximation of the Python matplotlib 'viridis' colormap.
    if nColors == 1
        colors = [0.267 0.004 0.329];
        return;
    end
    t = linspace(0, 1, nColors)';
    % Viridis is a perceptually-uniform colormap; approximate with smooth spline
    % Purple (0,0) → Blue (0.5, 0) → Green (0.5, 0.5) → Yellow (1, 1)
    r = interp1([0 1], [0.267 0.993], t, 'pchip');
    g = interp1([0 0.5 1], [0.004 0.906 0.906], t, 'pchip');
    b = interp1([0 0.5 1], [0.329 0.145 0.023], t, 'pchip');
    colors = [r, g, b];
    colors = max(0, min(1, colors));  % Clamp to [0, 1]
end


function colors = generatePlasma(nColors)
%GENERATEPLASMA  Create a plasma-like colormap.
%   Approximation of the Python matplotlib 'plasma' colormap.
    if nColors == 1
        colors = [0.050 0.030 0.529];
        return;
    end
    t = linspace(0, 1, nColors)';
    % Plasma: Purple → Pink → Yellow
    r = interp1([0 0.5 1], [0.050 0.940 0.940], t, 'pchip');
    g = interp1([0 0.5 1], [0.030 0.098 0.906], t, 'pchip');
    b = interp1([0 0.5 1], [0.529 0.208 0.145], t, 'pchip');
    colors = [r, g, b];
    colors = max(0, min(1, colors));  % Clamp to [0, 1]
end


function colors = generateInferno(nColors)
%GENERATEINFERNO  Create an inferno-like colormap.
%   Approximation of the Python matplotlib 'inferno' colormap.
    if nColors == 1
        colors = [0.001 0.001 0.014];
        return;
    end
    t = linspace(0, 1, nColors)';
    % Inferno: Black → Purple → Yellow
    r = interp1([0 0.5 1], [0.001 0.283 0.988], t, 'pchip');
    g = interp1([0 0.5 1], [0.001 0.075 0.998], t, 'pchip');
    b = interp1([0 0.5 1], [0.014 0.612 0.120], t, 'pchip');
    colors = [r, g, b];
    colors = max(0, min(1, colors));  % Clamp to [0, 1]
end


function y = evalMultiPeak(p, x, nP, isGauss)
%EVALMULTIPEAK  Evaluate a composite multi-peak model at x.
%  p layout: [H1, x0_1, fwhm1,  H2, x0_2, fwhm2, …,  HnP, x0_nP, fwhmNP,  m, b]
%  where m and b are the shared linear background slope and intercept.
%  isGauss=true uses Gaussian peaks; false uses Lorentzian peaks.
    y = p(end-1) .* x + p(end);   % linear background
    for k = 1:nP
        H    = p((k-1)*3 + 1);
        x0   = p((k-1)*3 + 2);
        fwhm = p((k-1)*3 + 3);
        if isGauss
            y = y + H .* exp(-4.*log(2) .* ((x - x0) ./ fwhm).^2);
        else
            y = y + H ./ (1 + 4.*((x - x0) ./ fwhm).^2);
        end
    end
end

function y = evalMultiPeakPV(p, x, nP)
%EVALMULTIPEAKPV  Evaluate a composite pseudo-Voigt multi-peak model at x.
%  p layout: [H1, x0_1, fwhm1, eta1,  H2, x0_2, fwhm2, eta2, …,  m, b]
%  where eta_k in [0,1] is the Lorentzian fraction for peak k,
%  and m, b are the shared linear background slope and intercept.
    y = p(end-1) .* x + p(end);   % linear background
    for k = 1:nP
        H    = p((k-1)*4 + 1);
        x0   = p((k-1)*4 + 2);
        fwhm = p((k-1)*4 + 3);
        eta  = max(0, min(1, p((k-1)*4 + 4)));
        u    = (x - x0) ./ fwhm;
        L    = 1 ./ (1 + 4.*u.^2);
        G    = exp(-4.*log(2) .* u.^2);
        y    = y + H .* (eta .* L + (1 - eta) .* G);
    end
end


function wl_A = extractWavelength_A(ds)
%EXTRACTWAVELENGTH_A  Return X-ray wavelength in Ångströms for a dataset.
%
%   Priority:
%     1. ds.wavelengthOverride_A  — user-edited value (set via efWavelength)
%     2. XRDML   : ds.data.metadata.parserSpecific.wavelength.kAlpha1  (Å)
%     3. Bruker  : ds.data.metadata.parserSpecific.wavelength_A        (Å)
%     4. NaN     — wavelength unknown; d-spacing column shows '—'
%
%   Output unit is always Ångströms (Å).

    % 1. User override takes highest priority
    if isfield(ds, 'wavelengthOverride_A') && ~isnan(ds.wavelengthOverride_A) ...
            && ds.wavelengthOverride_A > 0
        wl_A = ds.wavelengthOverride_A;
        return
    end

    wl_A = NaN;
    if ~isfield(ds,'data') || ~isstruct(ds.data), return; end
    if ~isfield(ds.data,'metadata') || ~isstruct(ds.data.metadata), return; end
    meta = ds.data.metadata;
    if ~isfield(meta,'parserSpecific') || ~isstruct(meta.parserSpecific), return; end
    ps = meta.parserSpecific;

    % 2. XRDML: wavelength.kAlpha1 (Å)
    if isfield(ps,'wavelength') && isstruct(ps.wavelength) ...
            && isfield(ps.wavelength,'kAlpha1')
        v = ps.wavelength.kAlpha1;
        if isnumeric(v) && isscalar(v) && ~isnan(v) && v > 0
            wl_A = v;
            return
        end
    end

    % 3. Bruker: wavelength_A (Å)
    if isfield(ps,'wavelength_A')
        v = ps.wavelength_A;
        if isnumeric(v) && isscalar(v) && ~isnan(v) && v > 0
            wl_A = v;
            return
        end
    end
end


function pairMap = findPolarizationPairs(datasets)
%FINDPOLARIZATIONPAIRS  Identify paired neutron datasets by matching filenames.
%
%  INPUT:
%    datasets — cell array of dataset structs (each has .filepath, .data, .parserName)
%
%  OUTPUT:
%    pairMap — cell array where pairMap{i} = [idx_PP, idx_MM] for paired polarizations,
%              or [idx, 0] for unpaired. pairMap{i} is non-empty only if both ++ and --
%              channels exist for that measurement.
%
%  Looks for datasets from same measurement (matching filename prefix) with
%  complementary polarizations (++ with --).

    pairMap = {};
    nDS = numel(datasets);

    for i = 1:nDS
        ds_i = datasets{i};
        if ~isfield(ds_i, 'data') || ~isfield(ds_i.data, 'metadata')
            continue;
        end
        meta_i = ds_i.data.metadata;
        if ~isfield(meta_i, 'parserSpecific') || ~isfield(meta_i.parserSpecific, 'polarization')
            continue;
        end
        pol_i = meta_i.parserSpecific.polarization;

        % Skip if not ++ or --
        if ~strcmp(pol_i, '++') && ~strcmp(pol_i, '--')
            continue;
        end

        % Get filename without extension and polarization suffix
        [~, fn_i, ~] = fileparts(ds_i.filepath);
        fn_base_i = regexprep(fn_i, '-(refl|pnr)$', '');  % strip refl/pnr suffix
        fn_base_i = regexprep(fn_base_i, '-[a-z]$', '');  % strip polarization suffix

        % Look for matching dataset with opposite polarization
        targetPol = guiTernary(strcmp(pol_i, '++'), '--', '++');
        partnerIdx = 0;

        for j = i+1:nDS
            ds_j = datasets{j};
            if ~isfield(ds_j, 'data') || ~isfield(ds_j.data, 'metadata')
                continue;
            end
            meta_j = ds_j.data.metadata;
            if ~isfield(meta_j, 'parserSpecific') || ~isfield(meta_j.parserSpecific, 'polarization')
                continue;
            end
            pol_j = meta_j.parserSpecific.polarization;

            if strcmp(pol_j, targetPol)
                [~, fn_j, ~] = fileparts(ds_j.filepath);
                fn_base_j = regexprep(fn_j, '-(refl|pnr)$', '');
                fn_base_j = regexprep(fn_base_j, '-[a-z]$', '');

                if strcmp(fn_base_i, fn_base_j)
                    partnerIdx = j;
                    break;
                end
            end
        end

        % Store pair mapping
        if partnerIdx > 0
            if strcmp(pol_i, '++')
                pairMap{i} = [i, partnerIdx]; %#ok<AGROW>
            else
                pairMap{i} = [partnerIdx, i];  %#ok<AGROW> % always [++, --]
            end
        end
    end
end


