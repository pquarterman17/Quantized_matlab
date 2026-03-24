function varargout = DataPlotter()
%DATAPLOTTER  Browse, import and preview data files using the +parser toolkit.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   DataPlotter()
%   api = DataPlotter()
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
%   api = DataPlotter() returns a struct of function handles for
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
%   api.setMap2DColormap(name) — set 2D map color scale (e.g. 'parula','viridis','plasma')
%
%   Headless usage (e.g. in test_gui_harness.m):
%     api = DataPlotter();
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

    % ── Shared application state (handle class — pass-by-reference) ──────
    % Using a handle class enables extracted +dataplotter/ functions to
    % mutate state without return-value gymnastics.  All existing
    % appData.X references work unchanged (same dot-syntax as struct).
    appData = dataplotter.AppState();

    % Fields with non-default values (overriding AppState property defaults)
    appData.style      = 'Line';
    appData.fringeQ    = [NaN NaN];
    appData.macroLog   = dataplotter.actionLog();

    % ── Line caching for performance (nested struct as property) ──
    appData.lineCache  = struct('valid', false, 'left', {{}}, 'right', {{}});

    % ── Figure ───────────────────────────────────────────────────────────
    % Detect available screen size and fit the window to it
    screenSz = get(0, 'ScreenSize');  % [1 1 width height]
    availW = screenSz(3);
    availH = screenSz(4);
    initW = min(1080, availW - 40);
    initH = min(1000, availH - 80);  % leave room for menu bar / dock
    initX = max(20, round((availW - initW) / 2));
    initY = max(40, round((availH - initH) / 2));
    fig = uifigure('Name','Data Import & Preview', ...
                   'Position',[initX initY initW initH], ...
                   'AutoResizeChildren','off');
    MIN_FIG_H = 500;   % reduced minimum so GUI works on small screens
    LAYOUT_DEFAULTS = struct('figW',initW,'figH',initH,'ctrlPanelW',190, ...
        'corrPanelW',320,'axLimPanelW',200,'fileListW',180);
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

    % ── Semantic button colour palette ─────────────────────────────────────
    BTN_PRIMARY   = [0.18 0.52 0.18];  % green  — primary actions (Add Files, Apply)
    BTN_ACCENT    = [0.15 0.37 0.63];  % blue   — analysis/fit actions
    BTN_DANGER    = [0.55 0.15 0.15];  % red    — destructive (Remove, Clear)
    BTN_EXPORT    = [0.18 0.32 0.52];  % slate  — save/export operations
    BTN_EXTERNAL  = [0.12 0.38 0.38];  % teal   — external integrations (Origin, HDF5)
    BTN_SESSION   = [0.22 0.32 0.42];  % steel  — session save/load
    BTN_TOOL      = [0.28 0.28 0.28];  % gray   — secondary tools & utilities
    BTN_SECONDARY = [0.25 0.28 0.35];  % charcoal — figure export, copy
    BTN_FG        = [1 1 1];           % white text on dark buttons

    % ── Tick-label format options ─────────────────────────────────────────
    % X-axis: printf format strings only.
    TICKFMT_NAMES  = {'Auto', 'Scientific', 'Fixed 4dp', 'Fixed 2dp', 'Integer'};
    TICKFMT_DATA   = {'',     '%.2e',       '%.4f',      '%.2f',      '%d'};
    % Y-axis: same options plus "Exp = 0" which forces the axis exponent to zero
    % (suppresses the corner ×10ⁿ multiplier so ticks show their true magnitude).
    % The sentinel '__exp0' is detected in drawToAxes and handled via YAxis.Exponent.
    YTICKFMT_NAMES = {'Auto', 'Scientific', 'Fixed 4dp', 'Fixed 2dp', 'Integer', 'Exp = 0'};
    YTICKFMT_DATA  = {'',     '%.2e',       '%.4f',      '%.2f',      '%d',      '__exp0'};

    % Root grid  (3 rows × 1 col: content | analysis+save | status)
    % Row 1 holds file-list | controls | preview side-by-side (contentGL).
    % Row 2 holds corrections | axes | save/export side-by-side.
    % Both content rows split height ~50/50.
    rootGL = uigridlayout(fig,[3 1], ...
        'RowHeight',    {'1x', '1x', 16}, ...  % preview | analysis+save | status
        'ColumnWidth',  {'1x'}, ...
        'Padding',      [6 6 6 6], ...
        'RowSpacing',   4, ...
        'ColumnSpacing', 0);

    % ── Content row: [Files | Controls | Preview] ─────────────────────────
    % File-list column is narrow; controls column fixed; preview fills remainder.
    contentGL = uigridlayout(rootGL,[1 3], ...
        'ColumnWidth',  {180, 190, '1x'}, ...
        'Padding',      [0 0 0 0], ...
        'ColumnSpacing', 6);
    contentGL.Layout.Row = 1; contentGL.Layout.Column = 1;

    % ── File list panel (contentGL col 1, scrollable) ──────────────────────
    % Wrapped in a scrollable panel so buttons + listbox are never clipped.
    fileListPanel = uipanel(contentGL, 'BorderType', 'none', 'Scrollable', 'on');
    fileListPanel.Layout.Row = 1; fileListPanel.Layout.Column = 1;

    % Stacked vertically: Add | Remove | Filter | Merge | Up/Down | Animate/Shortcuts | Settings | Listbox
    tbGL = uigridlayout(fileListPanel,[8 2], ...
        'RowHeight',    {22,22,22,22,22,22,22,'1x'}, ...
        'ColumnWidth',  {'1x','1x'}, ...
        'Padding',      [0 0 0 0], ...
        'RowSpacing',   2, ...
        'ColumnSpacing', 3);

    btnBrowse = uibutton(tbGL,'Text','Add File(s)...', ...
        'ButtonPushedFcn',@onAddFiles, ...
        'BackgroundColor',BTN_PRIMARY, ...
        'FontColor',BTN_FG,'FontWeight','bold', ...
        'Tooltip','Browse for one or more data files — each is added as a new dataset');
    btnBrowse.Layout.Row = 1; btnBrowse.Layout.Column = [1 2];

    btnRemoveDS = uibutton(tbGL,'Text','Remove Selected', ...
        'ButtonPushedFcn',@onRemoveDataset, ...
        'BackgroundColor',BTN_DANGER, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Remove the highlighted dataset from the list (also: right-click or press Delete)');
    btnRemoveDS.Layout.Row = 2; btnRemoveDS.Layout.Column = [1 2];

    efDatasetSearch = uieditfield(tbGL,'text','Value','', ...
        'Placeholder','Filter datasets...', ...
        'Tooltip','Filter the dataset list by name (case-insensitive substring match)', ...
        'ValueChangedFcn',@onSearchChanged);
    efDatasetSearch.Layout.Row = 3; efDatasetSearch.Layout.Column = [1 2];

    btnMerge = uibutton(tbGL,'Text','Merge Selected', ...
        'ButtonPushedFcn',@onMergeDatasets, ...
        'BackgroundColor',BTN_ACCENT, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Concatenate 2+ selected datasets into a new merged dataset (sorted by X)');
    btnMerge.Layout.Row = 4; btnMerge.Layout.Column = 1;

    btnDatasetMath = uibutton(tbGL,'Text','Dataset Math...', ...
        'ButtonPushedFcn',@onDatasetMath, ...
        'BackgroundColor',BTN_ACCENT, ...
        'FontColor',BTN_FG, ...
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
    btnAnimate.Layout.Row = 6; btnAnimate.Layout.Column = 1;

    btnShortcuts = uibutton(tbGL,'Text','?  Shortcuts', ...
        'ButtonPushedFcn',@onShowShortcuts, ...
        'BackgroundColor',BTN_TOOL, ...
        'FontColor',[0.75 0.75 0.75], ...
        'FontSize',10, ...
        'Tooltip','Show keyboard shortcuts');
    btnShortcuts.Layout.Row = 6; btnShortcuts.Layout.Column = 2;

    btnSettings = uibutton(tbGL,'Text',[char(9881) '  Settings...'], ...
        'ButtonPushedFcn',@(~,~) onOpenSettings(), ...
        'BackgroundColor',BTN_TOOL, ...
        'FontColor',[0.85 0.85 0.85], ...
        'FontSize',10, ...
        'Tooltip','Theme, plot style, and other global preferences');
    btnSettings.Layout.Row = 7; btnSettings.Layout.Column = [1 2];

    lbDatasets = uilistbox(tbGL, ...
        'Items',     {'(no files loaded — click  Add File(s)...  to begin)'}, ...
        'ItemsData', {0}, ...
        'Multiselect','on', ...
        'ValueChangedFcn',@onSelectDataset, ...
        'Tooltip','Loaded datasets — click to make active; Ctrl+click to select multiple; right-click to remove');
    lbDatasets.Layout.Row = 8; lbDatasets.Layout.Column = [1 2];

    % Context menu for dataset list (right-click) — #12 expanded
    % uicontextmenu on uifigure components requires R2023b+; guard for older versions.
    try
        cmDatasets = uicontextmenu(fig);
        uimenu(cmDatasets, 'Text', 'Remove Selected', ...
            'MenuSelectedFcn', @(~,~) onRemoveDataset([], []));
        uimenu(cmDatasets, 'Text', 'Duplicate', ...
            'MenuSelectedFcn', @(~,~) onDuplicateDataset([], []));
        uimenu(cmDatasets, 'Text', 'Hide / Show', ...
            'MenuSelectedFcn', @(~,~) onToggleDatasetVisibility([], []));
        uimenu(cmDatasets, 'Text', 'Set as Background', ...
            'MenuSelectedFcn', @(~,~) onSetActiveBG([], []));
        uimenu(cmDatasets, 'Text', 'Move Up', ...
            'MenuSelectedFcn', @(~,~) onMoveDatasetUp([], []));
        uimenu(cmDatasets, 'Text', 'Move Down', ...
            'MenuSelectedFcn', @(~,~) onMoveDatasetDown([], []));
        lbDatasets.ContextMenu = cmDatasets;
    catch
        % R2022a/R2022b: uicontextmenu not supported on uifigure — skip silently.
        % Users can still use toolbar buttons for these operations.
    end

    % Left controls panel
    % Title updates to show parser name after each load.
    % Row layout (7 rows):
    %   1 -  26px  X dropdown
    %   2 -  '1x'  Y listbox (multi-select)
    %   3 -  '1x'  Right Y-axis selector
    %   4 -  70px  Plot-style / colormap / theme buttons
    %   5 -  24px  Log-scale checkboxes
    %   6 -  26px  Waterfall + Refresh
    %   7 -  24px  Annotation mode
    ctrlPanel = uipanel(contentGL,'Title','Controls','FontSize',11, ...
        'Scrollable','on');
    ctrlPanel.Layout.Column = 2;

    ctrlGL = uigridlayout(ctrlPanel,[8 1], ...
        'RowHeight', {24,'2x','1x',22,66,22,22,20}, ...
        'Padding',   [4 4 4 4], ...
        'RowSpacing', 2);

    ddX = uidropdown(ctrlGL,'Items',{'(load file first)'}, ...
        'ValueChangedFcn',@onAxisChanged, ...
        'Tooltip','X axis channel');
    ddX.Layout.Row = 1;

    lbY = uilistbox(ctrlGL,'Items',{'(load file first)'},'Multiselect','on', ...
        'ValueChangedFcn',@onAxisChanged, ...
        'Tooltip','Y axis channel(s) — Ctrl+click to select multiple');
    lbY.Layout.Row = 2;

    % Row 5: Right Y-axis channel selector
    y2GL = uigridlayout(ctrlGL,[2 1], ...
        'Padding',[0 0 0 0],'RowSpacing',1,'ColumnSpacing',3, ...
        'RowHeight',{16,'1x'},'ColumnWidth',{'1x'});
    y2GL.Layout.Row = 3;

    lblY2 = uilabel(y2GL,'Text','Right Y-axis:', ...
        'FontSize',12,'FontColor',[0.75 0.75 0.75]);
    lblY2.Layout.Row = 1; lblY2.Layout.Column = 1;

    lbY2 = uilistbox(y2GL,'Items',{'(none)'},'Multiselect','on', ...
        'Value',{'(none)'}, ...
        'Tooltip','Right Y-axis channel(s) — plotted against the right-hand scale', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    lbY2.Layout.Row = 2; lbY2.Layout.Column = 1;

    % Colormap selector (row 4) — theme + plot style moved to Settings dialog
    styleGL = uigridlayout(ctrlGL,[1 4], ...
        'Padding',[0 0 0 0],'ColumnSpacing',2,'RowSpacing',2, ...
        'ColumnWidth',{'1x','1x','1x','1x'},'RowHeight',{18});
    styleGL.Layout.Row = 4;

    lblColormap = uilabel(styleGL,'Text','Colormap:','FontSize',10);
    lblColormap.Layout.Row = 1; lblColormap.Layout.Column = 1;

    COLORMAPS = {'lines (MATLAB default)', 'jet', 'turbo', 'hot', 'cool', ...
                 'spring', 'summer', 'autumn', 'winter', 'gray', 'copper', ...
                 'pink', 'bone', 'hsv', 'parula', 'viridis', 'plasma', 'inferno'};
    ddColormap = uidropdown(styleGL, 'Items', COLORMAPS, 'Value', COLORMAPS{1}, ...
        'Tooltip', 'Color palette for multi-dataset plots', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddColormap.Layout.Row = 1; ddColormap.Layout.Column = [2 4];

    % Theme value stored here but UI moved to Settings dialog
    appData.theme = 'Light';

    % Row 5: Axis scale dropdowns (3 rows: X, Left Y, Right Y)
    scaleGL = uigridlayout(ctrlGL,[3 2], ...
        'Padding',[0 0 0 0],'RowSpacing',2,'ColumnSpacing',4, ...
        'RowHeight',{20,20,20},'ColumnWidth',{55,'1x'});
    scaleGL.Layout.Row = 5;

    lblScaleX = uilabel(scaleGL,'Text','X axis:','FontSize',11);
    lblScaleX.Layout.Row = 1; lblScaleX.Layout.Column = 1;
    ddScaleX = uidropdown(scaleGL,'Items',{'Linear','Log'}, ...
        'Value','Linear','FontSize',11, ...
        'ValueChangedFcn',@onAxisChanged, ...
        'Tooltip','X-axis scale');
    ddScaleX.Layout.Row = 1; ddScaleX.Layout.Column = 2;

    lblScaleY = uilabel(scaleGL,'Text','Left Y:','FontSize',11);
    lblScaleY.Layout.Row = 2; lblScaleY.Layout.Column = 1;
    ddScaleY = uidropdown(scaleGL,'Items',{'Linear','Log'}, ...
        'Value','Linear','FontSize',11, ...
        'ValueChangedFcn',@onAxisChanged, ...
        'Tooltip','Left Y-axis scale');
    ddScaleY.Layout.Row = 2; ddScaleY.Layout.Column = 2;

    lblScaleY2 = uilabel(scaleGL,'Text','Right Y:','FontSize',11);
    lblScaleY2.Layout.Row = 3; lblScaleY2.Layout.Column = 1;
    ddScaleY2 = uidropdown(scaleGL,'Items',{'Linear','Log'}, ...
        'Value','Linear','FontSize',11, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]), ...
        'Tooltip','Right Y-axis scale');
    ddScaleY2.Layout.Row = 3; ddScaleY2.Layout.Column = 2;

    % Row 6: Waterfall toggle + spacing
    wfGL = uigridlayout(ctrlGL,[1 2], ...
        'Padding',[0 0 0 0],'ColumnSpacing',4,'ColumnWidth',{'1x',50});
    wfGL.Layout.Row = 6;

    cbWaterfall = uicheckbox(wfGL, ...
        'Text',    'WF', ...
        'Value',   false, ...
        'Tooltip', 'Waterfall: stack datasets vertically with a uniform Y offset', ...
        'ValueChangedFcn', @(~,~) onWaterfallToggled());
    cbWaterfall.Layout.Column = 1;

    efWaterfallSpacing = uieditfield(wfGL, 'text', 'Value', '', ...
        'Placeholder',     'auto', ...
        'Tooltip',         'Spacing between stacked traces in data units — blank = auto (1.1× max data range)', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efWaterfallSpacing.Layout.Column = 2;

    % Waterfall gradient coloring (stored in appData, no separate widget)
    appData.wfGradient = false;

    % Row 7: Cts/s + Refresh
    miscGL = uigridlayout(ctrlGL,[1 2], ...
        'Padding',[0 0 0 0],'ColumnSpacing',4,'ColumnWidth',{'1x',55});
    miscGL.Layout.Row = 7;

    cbCountsPerSec = uicheckbox(miscGL,'Text','Cts/s', ...
        'Value', false, 'Enable', 'off', ...
        'Tooltip', 'Divide intensity by counting time (counts → counts/s). XRD files only.', ...
        'ValueChangedFcn', @onAxisChanged);
    cbCountsPerSec.Layout.Column = 1;

    btnPlot = uibutton(miscGL,'Text','Refresh','ButtonPushedFcn',@onPlot, ...
    'Tooltip','Force a full redraw of the current plot');
    btnPlot.Layout.Column = 2;

    % Row 10: Annotation mode toggle
    cbAnnotationMode = uicheckbox(ctrlGL, ...
        'Text',    'Annotation Mode', ...
        'Value',   false, ...
        'Tooltip', 'Click on the plot to add text annotations. Right-click to delete.', ...
        'ValueChangedFcn', @onAnnotationModeChanged);
    cbAnnotationMode.Layout.Row = 8;

    % ── Right: preview axes ───────────────────────────────────────────────
    axPanel = uipanel(contentGL,'Title','Preview','FontSize',11);
    axPanel.Layout.Column = 3;
    axGL = uigridlayout(axPanel,[1 1],'Padding',[2 2 2 2]);
    ax = uiaxes(axGL);
    ax.Box = 'on';
    grid(ax,'on');
    title(ax,'Load a file to preview data','Interpreter','none');
    xlabel(ax,'');
    ylabel(ax,'');

    % Table state (UI built later in dataTablePanel after analysisGL is created)
    appData.tableVisible    = true;   % visible by default in analysis area
    appData.tableWorkingCopy = [];
    appData.tableUnits       = {};
    appData.tableMask       = [];
    appData.tableEdited     = false;
    appData.tableRowCap     = 500;    % max rows displayed in uitable (perf cap)
    fig.WindowButtonDownFcn   = @onAxesButtonDown;  % normal mode; special modes overwrite this
    fig.WindowButtonMotionFcn = @onMouseHover;      % idle hover; drags overwrite and restore this

    % ── Axes context menu (right-click) ──────────────────────────────────
    % SI prefix lookup tables (stored in appData so nested functions can access)
    appData.prefixNames   = {'None','pico (p)','nano (n)',['micro (' char(956) ')'],'milli (m)', ...
                             'kilo (k)','Mega (M)','Giga (G)'};
    appData.prefixSymbols = {'',    'p',       'n',       char(956),     'm', ...
                             'k',   'M',       'G'};
    appData.prefixFactors = [1,     1e12,      1e9,       1e6,           1e3, ...
                             1e-3,  1e-6,      1e-9];
    try
        cmAxes = uicontextmenu(fig);

        smX = uimenu(cmAxes, 'Text', 'X-Axis Prefix');
        smY = uimenu(cmAxes, 'Text', 'Y-Axis Prefix');
        for ip = 1:numel(appData.prefixNames)
            uimenu(smX, 'Text', appData.prefixNames{ip}, ...
                'MenuSelectedFcn', @(src,~) onSetAxisPrefixFromMenu(src, 'x'));
            uimenu(smY, 'Text', appData.prefixNames{ip}, ...
                'MenuSelectedFcn', @(src,~) onSetAxisPrefixFromMenu(src, 'y'));
        end

        % Quick toggles
        uimenu(cmAxes, 'Text', 'Toggle Log X', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) onContextToggle('logX'));
        uimenu(cmAxes, 'Text', 'Toggle Log Y', ...
            'MenuSelectedFcn', @(~,~) onContextToggle('logY'));
        uimenu(cmAxes, 'Text', 'Toggle Grid', ...
            'MenuSelectedFcn', @(~,~) onContextToggle('grid'));
        uimenu(cmAxes, 'Text', 'Invert X-Axis', ...
            'MenuSelectedFcn', @(~,~) onContextToggle('invertX'));

        % Reference lines
        smRef = uimenu(cmAxes, 'Text', 'Reference Lines', 'Separator', 'on');
        uimenu(smRef, 'Text', 'Add Horizontal Line Here', ...
            'MenuSelectedFcn', @(~,~) onAddRefLineAtCursor('horizontal'));
        uimenu(smRef, 'Text', 'Add Vertical Line Here', ...
            'MenuSelectedFcn', @(~,~) onAddRefLineAtCursor('vertical'));
        uimenu(smRef, 'Text', 'Add Horizontal Line...', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) onAddHRefLine([], []));
        uimenu(smRef, 'Text', 'Add Vertical Line...', ...
            'MenuSelectedFcn', @(~,~) onAddVRefLine([], []));
        uimenu(smRef, 'Text', 'Clear All Reference Lines', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) onClearRefLines([], []));

        % Actions
        uimenu(cmAxes, 'Text', 'Auto-Scale', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) onAutoLimits([], []));
        uimenu(cmAxes, 'Text', 'Copy Plot to Clipboard', ...
            'MenuSelectedFcn', @(~,~) onCopyPlotToClipboard());
        uimenu(cmAxes, 'Text', 'Copy Data to Clipboard', ...
            'MenuSelectedFcn', @(~,~) onCopyDataToClipboard([], []));
        uimenu(cmAxes, 'Text', 'Export Visible Range...', ...
            'MenuSelectedFcn', @(~,~) onExportVisibleRange());
        uimenu(cmAxes, 'Text', 'Toggle Waterfall Gradient', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) toggleWfGradient());
        uimenu(cmAxes, 'Text', 'Clear Fit Overlays', ...
            'MenuSelectedFcn', @(~,~) onClearFitOverlays());

        ax.ContextMenu = cmAxes;
    catch
        % R2022a/R2022b: uicontextmenu not supported on uifigure uiaxes.
    end

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

    % ── Status bar (row 3 of rootGL) ──────────────────────────────────────
    statusGL = uigridlayout(rootGL, [1 3], ...
        'ColumnWidth', {'1x', 80, 80}, ...
        'Padding', [0 0 0 0], 'ColumnSpacing', 4);
    statusGL.Layout.Row = 3; statusGL.Layout.Column = 1;

    lblStatusBar = uilabel(statusGL, 'Text', 'Ready', ...
        'FontSize', 9, 'FontColor', [0.5 0.5 0.5], ...
        'HorizontalAlignment', 'left');
    lblStatusBar.Layout.Column = 1;

    btnMacroRecord = uibutton(statusGL, 'Text', char(9210), ...  % ⏺ record symbol
        'FontSize', 9, 'FontColor', [0.6 0.6 0.6], ...
        'BackgroundColor', [0.18 0.18 0.18], ...
        'Tooltip', 'Start recording GUI actions as a MATLAB script', ...
        'ButtonPushedFcn', @onToggleMacroRecord);
    btnMacroRecord.Layout.Column = 2;

    btnMacroExport = uibutton(statusGL, 'Text', 'Save Script', ...
        'FontSize', 8, 'FontColor', [0.5 0.5 0.5], ...
        'Tooltip', 'Export recorded macro as .m script', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @onExportMacro);
    btnMacroExport.Layout.Column = 3;

    % ── Analysis & Corrections panel (row 2, full width, scrollable) ──────
    analysisPanel = uipanel(rootGL,'Title','Analysis & Corrections','FontSize',11, ...
        'Scrollable','on');
    analysisPanel.Layout.Row = 2; analysisPanel.Layout.Column = 1;

    analysisGL = uigridlayout(analysisPanel,[2 4], ...
        'ColumnWidth', {320, '1x', 210, 0}, ...
        'RowHeight',   {110, '1x'}, ...
        'Padding',     [4 4 4 4], ...
        'ColumnSpacing', 6, ...
        'RowSpacing', 4);

    % ── Corrections sub-panel (analysisGL col 1) ─────────────────────────
    % Corrections panel — 18-row × 4-col grid with collapsible sections:
    %   row  1  : Style dropdown + Live Preview checkbox
    %   row  2  : [HEADER] "Offsets & Background" (collapsible, default open)
    %   row  3  : X Offset | BG Slope
    %   row  4  : Y Offset | BG Intercept
    %   row  5  : BG Order | BG Interp (merged)
    %   row  6  : Interactive tools (Fit BG / Est Y  OR  Y Translate / Peak btns)
    %   row  7  : [HEADER] "Processing" (collapsible, default open)
    %   row  8  : Smoothing controls
    %   row  9  : Normalize | Derivative (merged)
    %   row 10  : Trim X min | max
    %   row 11  : Estimate Baseline (SNIP)
    %   row 12  : [HEADER] "BG File Subtraction" (collapsible, default collapsed)
    %   row 13  : BG File path + Load BG / Use Active
    %   row 14  : Subtract BG + Clear BG
    %   row 15  : Spin Asymmetry (neutron only, RowHeight=0 otherwise)
    %   row 16  : Asymmetry formula (neutron only, RowHeight=0 otherwise)
    %   row 17  : Apply Corrections | Reset | Show Raw
    %   row 18  : Apply to All | Undo | Hide Dataset
    corrPanel = uipanel(analysisGL,'Title','Corrections','FontSize',11, ...
        'Scrollable','on');
    corrPanel.Layout.Row = [1 2]; corrPanel.Layout.Column = 1;

    % ── Row index constants for corrGL sections ──
    CROW = struct( ...
        'STYLE',      1,  'ADVANCED',  2,  'SEC_OFFSETS', 3,  'XOFF',       4,  'YOFF',       5, ...
        'BGORDER',    6,  'TOOLS',     7,  'SEC_PROC',   8,  'SMOOTH',     9, ...
        'NORM_DERIV',10,  'TRIM',     11,  'BASELINE',  12,  'SEC_BGFILE', 13, ...
        'BGFILE',    14,  'BGSUBTR',  15,  'ASYM1',     16,  'ASYM2',     17, ...
        'SEC_MAG',   18,  'MAG_MASS', 19,  'MAG_DIM',   20,  'MAG_THICK', 21, ...
        'MAG_UNITS', 22,  'MAG_AUTO', 23, ...
        'APPLY',     24,  'ACTIONS',  25,  'MASK',   26);

    corrGL = uigridlayout(corrPanel,[26 4], ...
        'RowHeight',    {24, 24, 20, 22,22,22,22, 20, 22,22,22,22, 20, 0,0, 0,0, ...
                         0,0,0,0,0,0, 24,22, 22}, ...
        'ColumnWidth',  {80,'1x',80,'1x'}, ...
        'Padding',      [4 4 4 4], ...
        'RowSpacing',   2, ...
        'ColumnSpacing', 3);

    % Collapsible section state
    appData.sectionCollapsed.offsets = false;  % open by default
    appData.sectionCollapsed.processing = false;  % open by default
    appData.sectionCollapsed.bgFile = true;  % collapsed by default (uncommon)
    appData.sectionCollapsed.magSample = true;  % collapsed by default
    appData.sectionCollapsed.saveTools = true;  % collapsed by default
    appData.sectionCollapsed.originExcel = true;  % collapsed by default
    appData.sectionCollapsed.advancedPeak = true;  % collapsed by default
    appData.sectionHeaders = struct();  % filled below with header button handles

    % Row 1: Correction style selector + Live preview
    lblCorrStyle = uilabel(corrGL,'Text','Style:','FontSize',10,'HorizontalAlignment','right');
    lblCorrStyle.Layout.Row = CROW.STYLE; lblCorrStyle.Layout.Column = 1;

    ddCorrStyle = uidropdown(corrGL, ...
        'Items',           {'Auto (from file)', 'Generic', 'Magnetometry', 'PPMS', 'XRD — 2\theta + BG', 'Neutron NR', 'SIMS Depth Profile'}, ...
        'Value',           'Auto (from file)', ...
        'Tooltip',         ['Controls which correction tools and analysis features are shown. '...
            '"Auto" detects from the file type. "XRD" enables peak detection. '...
            '"Neutron NR" enables spin asymmetry. "Generic" shows all controls.'], ...
        'ValueChangedFcn', @onCorrStyleChanged);
    ddCorrStyle.Layout.Row = CROW.STYLE; ddCorrStyle.Layout.Column = [2 3];

    cbLivePreview = uicheckbox(corrGL, ...
        'Text',    'Live', ...
        'Value',   true, ...
        'Tooltip', 'Automatically apply and redraw when correction parameters change (uncheck for large datasets)', ...
        'ValueChangedFcn', @(~,~) updateApplyButtonStyle());
    cbLivePreview.Layout.Row = CROW.STYLE; cbLivePreview.Layout.Column = 4;

    % Row 2: Advanced Analysis button (prominent, always visible)
    btnAdvancedCorr = uibutton(corrGL, 'Text', [char(9881) ' Advanced Analysis ' char(9662)], ...
        'ButtonPushedFcn', @onShowAdvancedMenu, ...
        'BackgroundColor', [0.22 0.44 0.22], 'FontColor', [1 1 1], ...
        'FontWeight', 'bold', 'FontSize', 10, ...
        'Tooltip', 'Advanced tools: Integrate, Curve Fit, Dataset Math, Digitizer, Resample...');
    btnAdvancedCorr.Layout.Row = CROW.ADVANCED; btnAdvancedCorr.Layout.Column = [1 4];

    % Row 3: Section header — Offsets & Background (uibutton for click support)
    lblSecOffsets = uibutton(corrGL, 'Text', [char(9660) ' Offsets & BG'], ...
        'FontSize', 9, 'FontWeight', 'bold', 'FontColor', [0.55 0.55 0.55], ...
        'BackgroundColor', corrGL.BackgroundColor, ...
        'HorizontalAlignment', 'left');
    appData.sectionHeaders.offsets = lblSecOffsets;
    lblSecOffsets.ButtonPushedFcn = @(~,~) onToggleCorrSection('offsets', ...
        offsetsSectionTitle(), ...
        [CROW.XOFF CROW.YOFF CROW.BGORDER CROW.TOOLS], [22 22 22 22]);
    lblSecOffsets.Layout.Row = CROW.SEC_OFFSETS; lblSecOffsets.Layout.Column = [1 4];

    % Row 3: X Offset | BG Slope
    lblXOff = uilabel(corrGL,'Text','X Offset:','HorizontalAlignment','right');
    lblXOff.Layout.Row = CROW.XOFF; lblXOff.Layout.Column = 1;

    efXOffset = uieditfield(corrGL,'numeric','Value',0, ...
        'Tooltip','X-offset: x_corrected = x − this value (0 = no shift)', ...
        'Limits',[-Inf Inf],'LowerLimitInclusive','off','UpperLimitInclusive','off', ...
        'ValueChangedFcn',@(~,~) markCorrectionsDirty());
    efXOffset.Layout.Row = CROW.XOFF; efXOffset.Layout.Column = 2;

    lblBGSlope = uilabel(corrGL,'Text','BG Slope:','HorizontalAlignment','right');
    lblBGSlope.Layout.Row = CROW.XOFF; lblBGSlope.Layout.Column = 3;

    efBGSlope = uieditfield(corrGL,'numeric','Value',0, ...
        'Tooltip','Linear BG slope m: y_BG = m·x + b  (0 = no BG subtraction)', ...
        'Limits',[-Inf Inf],'LowerLimitInclusive','off','UpperLimitInclusive','off', ...
        'ValueChangedFcn',@(~,~) markCorrectionsDirty());
    efBGSlope.Layout.Row = CROW.XOFF; efBGSlope.Layout.Column = 4;

    % Row 4: Y Offset | BG Intercept
    lblYOff = uilabel(corrGL,'Text','Y Offset:','HorizontalAlignment','right');
    lblYOff.Layout.Row = CROW.YOFF; lblYOff.Layout.Column = 1;

    efYOffset = uieditfield(corrGL,'numeric','Value',0, ...
        'Tooltip','Y-offset: applied after BG subtraction  (0 = no shift)', ...
        'Limits',[-Inf Inf],'LowerLimitInclusive','off','UpperLimitInclusive','off', ...
        'ValueChangedFcn',@(~,~) markCorrectionsDirty());
    efYOffset.Layout.Row = CROW.YOFF; efYOffset.Layout.Column = 2;

    lblBGInt = uilabel(corrGL,'Text','BG Intercept:','HorizontalAlignment','right');
    lblBGInt.Layout.Row = CROW.YOFF; lblBGInt.Layout.Column = 3;

    efBGIntercept = uieditfield(corrGL,'numeric','Value',0, ...
        'Tooltip','Linear BG intercept b: y_BG = m·x + b  (0 = no BG subtraction)', ...
        'Limits',[-Inf Inf],'LowerLimitInclusive','off','UpperLimitInclusive','off', ...
        'ValueChangedFcn',@(~,~) markCorrectionsDirty());
    efBGIntercept.Layout.Row = CROW.YOFF; efBGIntercept.Layout.Column = 4;

    % Row 5: BG Order (cols 1-2) | BG Interp (cols 3-4) — merged from old rows 6+17
    lblBGOrder = uilabel(corrGL,'Text','BG Order:','FontSize',10,'HorizontalAlignment','right');
    lblBGOrder.Layout.Row = CROW.BGORDER; lblBGOrder.Layout.Column = 1;

    ddBGOrder = uidropdown(corrGL, ...
        'Items',   {'Linear', 'Poly 2', 'Poly 3', 'Poly 4', 'Poly 5', 'Poly 6'}, ...
        'Value',   'Linear', ...
        'Tooltip', 'Polynomial order used by "Fit BG from Box": Linear=1st-order, Poly N=Nth-order');
    ddBGOrder.Layout.Row = CROW.BGORDER; ddBGOrder.Layout.Column = 2;

    lblBGInterp = uilabel(corrGL,'Text','Interp:','HorizontalAlignment','right','FontSize',10);
    lblBGInterp.Layout.Row = CROW.BGORDER; lblBGInterp.Layout.Column = 3;

    ddBGInterp = uidropdown(corrGL, ...
        'Items',   {'linear', 'pchip', 'spline', 'nearest'}, ...
        'Value',   'linear', ...
        'Tooltip', 'Interpolation method for background subtraction: linear (default), pchip (smooth), spline (smoother), nearest (step)', ...
        'ValueChangedFcn', @(~,~) markCorrectionsDirty());
    ddBGInterp.Layout.Row = CROW.BGORDER; ddBGInterp.Layout.Column = 4;

    % Row 6: Interactive tools — Fit BG / Est Y (generic) | XRD tools
    btnFitBG = uibutton(corrGL,'Text','Fit BG from Box', ...
        'ButtonPushedFcn',@onFitBGRegion, ...
        'BackgroundColor',[0.50 0.28 0.05], ...
        'FontColor',[1 1 1], ...
        'Tooltip', ['Draw a rectangle on the preview axes.  ' ...
                    'All selected-Y data points inside the box are fitted with ' ...
                    'a polynomial of the order chosen in "BG Order" (Linear = 1st-order).  ' ...
                    'For Linear: BG Slope and Intercept are auto-populated.  ' ...
                    'For higher orders: polynomial is stored per-dataset and applied on corrections.']);
    btnFitBG.Layout.Row = CROW.TOOLS; btnFitBG.Layout.Column = [1 2];

    btnPickY = uibutton(corrGL,'Text','Est. Y Offset  (2 pts)', ...
        'ButtonPushedFcn',@onPickYOrigin, ...
        'BackgroundColor',[0.45 0.20 0.55], ...
        'FontColor',[1 1 1], ...
        'Tooltip', ['Click two data points on the plot.  ' ...
                    'The Y Offset is updated so that y = 0 falls halfway ' ...
                    'between their y-values.  Works on whichever data is ' ...
                    'currently displayed (raw or corrected).']);
    btnPickY.Layout.Row = CROW.TOOLS; btnPickY.Layout.Column = [3 4];

    % XRD-mode interactive tools — same row, hidden by default.
    btnYTranslate = uibutton(corrGL,'Text','Y Translate (drag)', ...
        'ButtonPushedFcn',@onYTranslateDrag, ...
        'BackgroundColor',BTN_ACCENT,'FontColor',BTN_FG, ...
        'Tooltip',['Click and drag up/down on the plot to shift the data ' ...
                   'vertically — updates Y Offset live on each mouse move.'], ...
        'Visible','off');
    btnYTranslate.Layout.Row = CROW.TOOLS; btnYTranslate.Layout.Column = [1 2];

    btnAutoPeak = uibutton(corrGL,'Text','Auto Find Peaks', ...
        'ButtonPushedFcn',@onAutoPeak, ...
        'BackgroundColor',[0.55 0.20 0.05],'FontColor',[1 1 1], ...
        'Tooltip','Detect peaks automatically using SNIP background estimation and SNR-based filtering', ...
        'Visible','off');
    btnAutoPeak.Layout.Row = CROW.TOOLS; btnAutoPeak.Layout.Column = 3;

    btnManualPeak = uibutton(corrGL,'Text','Add Peak', ...
        'ButtonPushedFcn',@onManualPeakAdd, ...
        'BackgroundColor',[0.45 0.20 0.55],'FontColor',[1 1 1], ...
        'Tooltip','Click once on a peak in the plot to add it to the peak list (click button again to finish)', ...
        'Visible','off');
    btnManualPeak.Layout.Row = CROW.TOOLS; btnManualPeak.Layout.Column = 4;

    btnRemovePeakClick = uibutton(corrGL,'Text','Click-Rm', ...
        'ButtonPushedFcn',@onRemovePeakClickMode, ...
        'BackgroundColor',BTN_DANGER,'FontColor',BTN_FG, ...
        'FontSize', 9, ...
        'Tooltip','Click on a peak marker in the plot to remove it (click button again to finish)', ...
        'Visible','off');
    btnRemovePeakClick.Layout.Row = CROW.BGORDER; btnRemovePeakClick.Layout.Column = 3;

    btnPeakWindow = uibutton(corrGL,'Text','Peaks...', ...
        'ButtonPushedFcn', @(~,~) showPeakWindow(), ...
        'BackgroundColor', BTN_ACCENT, 'FontColor', BTN_FG, ...
        'FontSize', 9, ...
        'Tooltip', 'Open the Peak Analysis window (table, fitting, export)', ...
        'Visible','off');
    btnPeakWindow.Layout.Row = CROW.BGORDER; btnPeakWindow.Layout.Column = 4;

    % Row 7: Section header — Processing (uibutton for click support)
    lblSecProc = uibutton(corrGL, 'Text', [char(9660) ' Processing'], ...
        'FontSize', 9, 'FontWeight', 'bold', 'FontColor', [0.55 0.55 0.55], ...
        'BackgroundColor', corrGL.BackgroundColor, ...
        'HorizontalAlignment', 'left');
    appData.sectionHeaders.processing = lblSecProc;
    lblSecProc.ButtonPushedFcn = @(~,~) onToggleCorrSection('processing', ...
        'Processing', ...
        [CROW.SMOOTH CROW.NORM_DERIV CROW.TRIM CROW.BASELINE], [22 22 22 22]);
    lblSecProc.Layout.Row = CROW.SEC_PROC; lblSecProc.Layout.Column = [1 4];

    % Row 8: Smoothing controls
    cbSmooth = uicheckbox(corrGL, 'Text', 'Smooth', 'Value', false, ...
        'Tooltip', 'Apply smoothing to corrected data when Apply Corrections is pressed', ...
        'ValueChangedFcn', @onSmoothingChanged);
    cbSmooth.Layout.Row = CROW.SMOOTH; cbSmooth.Layout.Column = 1;

    efSmoothWin = uieditfield(corrGL, 'numeric', 'Value', 5, ...
        'Limits', [1 Inf], 'LowerLimitInclusive', 'on', ...
        'RoundFractionalValues', 'on', ...
        'Tooltip', 'Smoothing half-window in samples (total width = 2W+1 points)', ...
        'ValueChangedFcn', @onSmoothingChanged);
    efSmoothWin.Layout.Row = CROW.SMOOTH; efSmoothWin.Layout.Column = 2;

    ddSmoothMethod = uidropdown(corrGL, ...
        'Items',   {'Moving', 'Gaussian', 'Savitzky-Golay'}, ...
        'Value',   'Moving', ...
        'Tooltip', ['Moving: uniform average  |  Gaussian: bell-curve weighted  |  ' ...
                    'Savitzky-Golay: polynomial fit (preserves peak shapes)'], ...
        'ValueChangedFcn', @onSmoothingChanged);
    ddSmoothMethod.Layout.Row = CROW.SMOOTH; ddSmoothMethod.Layout.Column = [3 4];

    % Row 9: Normalize (cols 1-2) | Derivative (cols 3-4) — merged from old rows 13+19
    lblNormalize = uilabel(corrGL,'Text','Norm:','HorizontalAlignment','right');
    lblNormalize.Layout.Row = CROW.NORM_DERIV; lblNormalize.Layout.Column = 1;

    ddNormalize = uidropdown(corrGL, ...
        'Items',   {'None', 'Range [0,1]', 'Peak (max=1)', 'Z-score', 'Area (integral=1)'}, ...
        'Value',   'None', ...
        'Tooltip', 'Normalize corrected data: Range = [0,1], Peak = max height = 1, Z-score = (x-mean)/std, Area = integrate to 1', ...
        'ValueChangedFcn', @(~,~) markCorrectionsDirty());
    ddNormalize.Layout.Row = CROW.NORM_DERIV; ddNormalize.Layout.Column = 2;

    lblDerivative = uilabel(corrGL,'Text','Deriv:','HorizontalAlignment','right');
    lblDerivative.Layout.Row = CROW.NORM_DERIV; lblDerivative.Layout.Column = 3;

    ddDerivative = uidropdown(corrGL, ...
        'Items',   {'None', 'dY/dX', 'd²Y/dX²', '∫Y dx', 'dlog/dlog'}, ...
        'Value',   'None', ...
        'Tooltip', ['Transforms: dY/dX, d²Y/dX² (derivatives), ' ...
                    char(8747) 'Y dx (cumulative integral), ' ...
                    'dlog/dlog (log derivative — power-law exponent).'], ...
        'ValueChangedFcn', @(~,~) markCorrectionsDirty());
    ddDerivative.Layout.Row = CROW.NORM_DERIV; ddDerivative.Layout.Column = 4;

    % Row 10: Data trim / crop
    lblXTrim = uilabel(corrGL,'Text','Trim X:','HorizontalAlignment','right');
    lblXTrim.Layout.Row = CROW.TRIM; lblXTrim.Layout.Column = 1;

    efXTrimMin = uieditfield(corrGL,'text','Value','', ...
        'Tooltip','Trim x-range: keep only data from this minimum x-value (blank = no limit)', ...
        'ValueChangedFcn', @(~,~) markCorrectionsDirty());
    efXTrimMin.Layout.Row = CROW.TRIM; efXTrimMin.Layout.Column = 2;

    efXTrimMax = uieditfield(corrGL,'text','Value','', ...
        'Tooltip','Trim x-range: keep only data up to this maximum x-value (blank = no limit)', ...
        'ValueChangedFcn', @(~,~) markCorrectionsDirty());
    efXTrimMax.Layout.Row = CROW.TRIM; efXTrimMax.Layout.Column = [3 4];

    % Row 11: Baseline estimation button
    btnEstimateBaseline = uibutton(corrGL,'Text','Estimate Baseline (SNIP)', ...
        'ButtonPushedFcn', @onEstimateBaseline, ...
        'Tooltip', 'Estimate and subtract baseline using the SNIP peak-clipping algorithm (ideal for XRD data)', ...
        'FontSize', 9);
    btnEstimateBaseline.Layout.Row = CROW.BASELINE; btnEstimateBaseline.Layout.Column = [1 4];

    % Row 12: Section header — BG File Subtraction (collapsed by default, uibutton)
    lblSecBGFile = uibutton(corrGL, 'Text', [char(9654) ' BG File Subtraction'], ...
        'FontSize', 9, 'FontWeight', 'bold', 'FontColor', [0.55 0.55 0.55], ...
        'BackgroundColor', corrGL.BackgroundColor, ...
        'HorizontalAlignment', 'left');
    appData.sectionHeaders.bgFile = lblSecBGFile;
    lblSecBGFile.ButtonPushedFcn = @(~,~) onToggleCorrSection('bgFile', ...
        'BG File Subtraction', ...
        [CROW.BGFILE CROW.BGSUBTR], [22 22]);
    lblSecBGFile.Layout.Row = CROW.SEC_BGFILE; lblSecBGFile.Layout.Column = [1 4];

    % Row 13: Background dataset file picker (hidden by default)
    lblBGFile = uilabel(corrGL,'Text','BG File:','HorizontalAlignment','right');
    lblBGFile.Layout.Row = CROW.BGFILE; lblBGFile.Layout.Column = 1;

    efBGFile = uieditfield(corrGL,'text','Value','', ...
        'Placeholder','— none loaded —', ...
        'Editable','off', ...
        'Tooltip','Loaded background dataset — use "Load BG..." to populate');
    efBGFile.Layout.Row = CROW.BGFILE; efBGFile.Layout.Column = 2;

    btnLoadBG = uibutton(corrGL,'Text','Load BG...', ...
        'ButtonPushedFcn',@onLoadBackground, ...
        'Tooltip','Load a background file (any supported format) to subtract from corrected data');
    btnLoadBG.Layout.Row = CROW.BGFILE; btnLoadBG.Layout.Column = 3;

    btnSetActiveBG = uibutton(corrGL,'Text','Use Active', ...
        'ButtonPushedFcn',@onSetActiveBG, ...
        'Tooltip','Use the active dataset as the background (no file dialog needed)', ...
        'FontSize',9);
    btnSetActiveBG.Layout.Row = CROW.BGFILE; btnSetActiveBG.Layout.Column = 4;

    % Row 14: Subtract BG toggle + Clear (hidden by default)
    cbSubtractBG = uicheckbox(corrGL,'Text','Subtract BG','Value',false, ...
        'Tooltip','Subtract the loaded background from corrected data when Apply Corrections is pressed');
    cbSubtractBG.Layout.Row = CROW.BGSUBTR; cbSubtractBG.Layout.Column = [1 2];

    btnClearBG = uibutton(corrGL,'Text','Clear BG', ...
        'ButtonPushedFcn',@onClearBackground, ...
        'Tooltip','Remove the currently loaded background dataset');
    btnClearBG.Layout.Row = CROW.BGSUBTR; btnClearBG.Layout.Column = [3 4];

    % Row 15: Neutron spin asymmetry calculation (neutron data only, RowHeight=0)
    lblAsymmetry = uilabel(corrGL,'Text','Asymmetry:','HorizontalAlignment','right');
    lblAsymmetry.Layout.Row = CROW.ASYM1; lblAsymmetry.Layout.Column = 1;

    cbCalculateAsymmetry = uicheckbox(corrGL,'Text','Calculate & Plot', ...
        'Value',false, ...
        'Tooltip','Calculate spin asymmetry (R++ − R--) / (R++ + R--) and plot as new channel', ...
        'ValueChangedFcn',@onAsymmetryToggle);
    cbCalculateAsymmetry.Layout.Row = CROW.ASYM1; cbCalculateAsymmetry.Layout.Column = [2 4];

    % Row 16: Asymmetry formula selector (hidden by default)
    lblAsymFormula = uilabel(corrGL,'Text','Formula:','HorizontalAlignment','right');
    lblAsymFormula.Layout.Row = CROW.ASYM2; lblAsymFormula.Layout.Column = 1;

    ddAsymFormula = uidropdown(corrGL, ...
        'Items',   {'Linear: (R++ − R--) / (R++ + R--)', 'Log: log(R++ / R--)'}, ...
        'Value',   'Linear: (R++ − R--) / (R++ + R--)', ...
        'Tooltip', 'Asymmetry formula: Linear uses reflectivity ratio, Log uses reflectivity ratio logarithm');
    ddAsymFormula.Layout.Row = CROW.ASYM2; ddAsymFormula.Layout.Column = [2 4];

    % ── Magnetometry: Sample & Units (rows SEC_MAG..MAG_UNITS, collapsed by default)
    MAG_ROWS    = [CROW.MAG_MASS CROW.MAG_DIM CROW.MAG_THICK CROW.MAG_UNITS CROW.MAG_AUTO];
    MAG_HEIGHTS = [22 22 22 22 22];

    lblSecMag = uibutton(corrGL, 'Text', [char(9654) ' Sample & Units'], ...
        'FontSize', 9, 'FontWeight', 'bold', 'FontColor', [0.55 0.55 0.55], ...
        'BackgroundColor', corrGL.BackgroundColor, ...
        'HorizontalAlignment', 'left');
    appData.sectionHeaders.magSample = lblSecMag;
    lblSecMag.ButtonPushedFcn = @(~,~) onToggleCorrSection('magSample', ...
        'Sample & Units', MAG_ROWS, MAG_HEIGHTS);
    lblSecMag.Layout.Row = CROW.SEC_MAG; lblSecMag.Layout.Column = [1 4];

    % Row MAG_MASS: Mass (g) | CGS/SI toggle
    lblMass = uilabel(corrGL,'Text','Mass (g):','FontSize',10,'HorizontalAlignment','right');
    lblMass.Layout.Row = CROW.MAG_MASS; lblMass.Layout.Column = 1;

    efSampleMass = uieditfield(corrGL,'numeric','Value',0, ...
        'Limits',[0 Inf],'LowerLimitInclusive','on', ...
        'ValueDisplayFormat','%.6g', ...
        'Tooltip','Sample mass in grams (for emu/g normalization; 0 = not set)');
    efSampleMass.Layout.Row = CROW.MAG_MASS; efSampleMass.Layout.Column = 2;

    lblUnitSys = uilabel(corrGL,'Text','Units:','FontSize',10,'HorizontalAlignment','right');
    lblUnitSys.Layout.Row = CROW.MAG_MASS; lblUnitSys.Layout.Column = 3;

    ddUnitSystem = uidropdown(corrGL, ...
        'Items',   {'CGS', 'SI'}, ...
        'Value',   'CGS', ...
        'Tooltip', 'Quick-set CGS (Oe + emu) or SI (T + A·m²) — updates Field & Moment dropdowns below', ...
        'ValueChangedFcn', @onUnitSystemChanged);
    ddUnitSystem.Layout.Row = CROW.MAG_MASS; ddUnitSystem.Layout.Column = 4;

    % Row MAG_DIM: W × H with unit dropdown (mm or cm)
    lblDim = uilabel(corrGL,'Text','W × H:','FontSize',10,'HorizontalAlignment','right');
    lblDim.Layout.Row = CROW.MAG_DIM; lblDim.Layout.Column = 1;

    efSampleWidth = uieditfield(corrGL,'numeric','Value',0, ...
        'Limits',[0 Inf],'LowerLimitInclusive','on', ...
        'ValueDisplayFormat','%.6g', ...
        'Tooltip','Sample width (for volume calculation; 0 = not set)');
    efSampleWidth.Layout.Row = CROW.MAG_DIM; efSampleWidth.Layout.Column = 2;

    efSampleHeight = uieditfield(corrGL,'numeric','Value',0, ...
        'Limits',[0 Inf],'LowerLimitInclusive','on', ...
        'ValueDisplayFormat','%.6g', ...
        'Tooltip','Sample height (for volume calculation; 0 = not set)');
    efSampleHeight.Layout.Row = CROW.MAG_DIM; efSampleHeight.Layout.Column = 3;

    ddDimUnit = uidropdown(corrGL, ...
        'Items',   {'mm', 'cm'}, ...
        'Value',   'mm', ...
        'Tooltip', 'Unit for width and height dimensions (mm or cm)');
    ddDimUnit.Layout.Row = CROW.MAG_DIM; ddDimUnit.Layout.Column = 4;

    % Row MAG_THICK: Thickness + unit
    lblThick = uilabel(corrGL,'Text','Thickness:','FontSize',10,'HorizontalAlignment','right');
    lblThick.Layout.Row = CROW.MAG_THICK; lblThick.Layout.Column = 1;

    efSampleThick = uieditfield(corrGL,'numeric','Value',0, ...
        'Limits',[0 Inf],'LowerLimitInclusive','on', ...
        'ValueDisplayFormat','%.6g', ...
        'Tooltip','Sample thickness (for volume calculation; 0 = not set)');
    efSampleThick.Layout.Row = CROW.MAG_THICK; efSampleThick.Layout.Column = 2;

    lblThickUnit = uilabel(corrGL,'Text','Thick. Unit:','FontSize',10,'HorizontalAlignment','right');
    lblThickUnit.Layout.Row = CROW.MAG_THICK; lblThickUnit.Layout.Column = 3;

    ddThickUnit = uidropdown(corrGL, ...
        'Items',   {'nm', [char(197)]}, ...
        'Value',   'nm', ...
        'Tooltip', ['Thickness unit: nm or ' char(197) ' (Angstrom)']);
    ddThickUnit.Layout.Row = CROW.MAG_THICK; ddThickUnit.Layout.Column = 4;

    % Row MAG_UNITS: Field unit (cols 1-2) | Moment unit (cols 3-4)
    lblFieldUnit = uilabel(corrGL,'Text','Field:','FontSize',10,'HorizontalAlignment','right');
    lblFieldUnit.Layout.Row = CROW.MAG_UNITS; lblFieldUnit.Layout.Column = 1;

    ddFieldUnit = uidropdown(corrGL, ...
        'Items',   {'Oe (raw)', 'T', 'mT', 'A/m'}, ...
        'Value',   'Oe (raw)', ...
        'Tooltip', 'Convert magnetic field x-axis units (Oe → T, mT, or A/m)');
    ddFieldUnit.Layout.Row = CROW.MAG_UNITS; ddFieldUnit.Layout.Column = 2;

    lblMomentUnit = uilabel(corrGL,'Text','Moment:','FontSize',10,'HorizontalAlignment','right');
    lblMomentUnit.Layout.Row = CROW.MAG_UNITS; lblMomentUnit.Layout.Column = 3;

    ddMomentUnit = uidropdown(corrGL, ...
        'Items',   {'emu (raw)', 'emu/g', 'emu/cm³', 'A·m²', 'kA/m'}, ...
        'Value',   'emu (raw)', ...
        'Tooltip', ['Normalize moment: emu/g (divide by mass), emu/cm' char(179) ...
                    ' (divide by volume), A' char(183) 'm' char(178) ' (SI moment), kA/m (SI magnetization)']);
    ddMomentUnit.Layout.Row = CROW.MAG_UNITS; ddMomentUnit.Layout.Column = 4;

    % Row MAG_AUTO: Auto BG+Offset button + scope dropdown (magnetometry only)
    btnAutoMagCorr = uibutton(corrGL, 'Text', 'Auto BG + Y Off', ...
        'ButtonPushedFcn', @onAutoMagCorrections, ...
        'BackgroundColor', [0.20 0.50 0.35], ...
        'FontColor', BTN_FG, ...
        'Tooltip', ['Estimate linear background slope and Y offset from data near ' ...
                    char(177) '95% of the max field range (high-field saturation region).  ' ...
                    'Sets BG Slope, Intercept, and Y Offset, then applies corrections.']);
    btnAutoMagCorr.Layout.Row = CROW.MAG_AUTO; btnAutoMagCorr.Layout.Column = [1 2];

    ddAutoMagScope = uidropdown(corrGL, ...
        'Items',   {'Active', 'All Datasets'}, ...
        'Value',   'Active', ...
        'Tooltip', 'Apply auto-correction to just the active dataset or all loaded magnetometry datasets');
    ddAutoMagScope.Layout.Row = CROW.MAG_AUTO; ddAutoMagScope.Layout.Column = [3 4];

    % Row APPLY: Apply | Reset | Show Raw (pinned to bottom)
    btnApply = uibutton(corrGL,'Text','Apply Corrections', ...
        'ButtonPushedFcn',@onApplyCorrections, ...
        'BackgroundColor',BTN_PRIMARY, ...
        'FontColor',BTN_FG,'FontWeight','bold', ...
        'Tooltip','Compute corrected data and update plot');
    btnApply.Layout.Row = CROW.APPLY; btnApply.Layout.Column = [1 2];

    btnReset = uibutton(corrGL,'Text','Reset', ...
        'ButtonPushedFcn',@onResetCorrections, ...
        'Tooltip','Zero all correction fields and discard corrected data for the active dataset');
    btnReset.Layout.Row = CROW.APPLY; btnReset.Layout.Column = 3;

    cbShowRaw = uicheckbox(corrGL,'Text','Show Raw','Value',true, ...
        'Tooltip','When corrected data exists, also overlay raw data (dashed, desaturated)', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    cbShowRaw.Layout.Row = CROW.APPLY; cbShowRaw.Layout.Column = 4;

    % Row 18: Apply to All | Undo | Hide Dataset (merged from old rows 10+11)
    btnApplyAll = uibutton(corrGL,'Text','Apply to All', ...
        'ButtonPushedFcn',@onApplyCorrectionsAll, ...
        'Tooltip','Copy current corrections to all loaded datasets', ...
        'FontColor',[0.75 0.75 0.75],'FontSize',9);
    btnApplyAll.Layout.Row = CROW.ACTIONS; btnApplyAll.Layout.Column = [1 2];

    btnUndo = uibutton(corrGL,'Text','Undo', ...
        'ButtonPushedFcn',@onUndoCorrections, ...
        'Tooltip','Restore previous correction state (one-level undo)  [Ctrl+Z]', ...
        'FontColor',[0.75 0.75 0.75]);
    btnUndo.Layout.Row = CROW.ACTIONS; btnUndo.Layout.Column = 3;

    btnToggleVis = uibutton(corrGL,'Text','Hide', ...
        'ButtonPushedFcn',@onToggleDatasetVisibility, ...
        'Tooltip','Hide/show the active dataset in the plot without removing it  [Space]', ...
        'FontColor',[0.75 0.75 0.75],'FontSize',9);
    btnToggleVis.Layout.Row = CROW.ACTIONS; btnToggleVis.Layout.Column = 4;

    % Row 25: Mask Selection | Unmask All
    btnMaskSelect = uibutton(corrGL,'Text','Mask Selection', ...
        'ButtonPushedFcn',@onArmMaskSelection, ...
        'BackgroundColor',[0.60 0.15 0.15], ...
        'FontColor',BTN_FG,'FontSize',9, ...
        'Tooltip','Click & drag a rectangle on the plot to mask (exclude) data points inside the box');
    btnMaskSelect.Layout.Row = CROW.MASK; btnMaskSelect.Layout.Column = [1 2];

    btnUnmaskAll = uibutton(corrGL,'Text','Unmask All', ...
        'ButtonPushedFcn',@onUnmaskAll, ...
        'BackgroundColor',BTN_TOOL, ...
        'FontColor',[0.75 0.75 0.75],'FontSize',9, ...
        'Tooltip','Restore all masked data points for the active dataset  [Ctrl+M]');
    btnUnmaskAll.Layout.Row = CROW.MASK; btnUnmaskAll.Layout.Column = [3 4];

    % Region statistics readout — moved to status bar area (no longer a corrGL row)
    lblRegionStats = uilabel(corrGL,'Text','', 'FontSize',9, ...
        'FontColor',[0.3 0.3 0.6]);
    lblRegionStats.Layout.Row = CROW.SEC_BGFILE; lblRegionStats.Layout.Column = [2 4];

    % ── Axes & Appearance sub-panel (middle column) ──────────────────────
    % Ultra-compact 5-row layout:
    %   Row 1: X limits (label + min/max/step)
    %   Row 2: Y limits (label + min/max/step)  —  Y2 row hidden below
    %   Row 3: Y2 limits (hidden, RowHeight=0 until Y2 active)
    %   Row 4: Auto Scale + Reset + Legend checkbox + Color dropdown
    %   Row 5: Title + labels + format + ref lines (collapsible, default hidden)
    axLimPanel = uipanel(analysisGL,'Title','Axes','FontSize',11, ...
        'Scrollable','on');
    axLimPanel.Layout.Row = 1; axLimPanel.Layout.Column = 2;

    % ── Data Table panel (row 2, col 2 — shares space with Axes above) ──
    dataTablePanel = uipanel(analysisGL, 'Title', 'Data Table', 'FontSize', 10);
    dataTablePanel.Layout.Row = 2; dataTablePanel.Layout.Column = 2;

    % ── Data Table contents (toolbar + units + editable table) ───────
    dataTableInnerGL = uigridlayout(dataTablePanel, [3 1], ...
        'RowHeight', {22, 14, '1x'}, 'Padding', [2 2 2 2], 'RowSpacing', 1);

    % Toolbar row
    tableBarGL = uigridlayout(dataTableInnerGL, [1 7], ...
        'ColumnWidth', {70, 70, 55, 50, 50, 50, '1x'}, ...
        'RowHeight', {'1x'}, ...
        'Padding', [2 0 2 0], 'ColumnSpacing', 3);
    tableBarGL.Layout.Row = 1;

    btnTableSaveAs = uibutton(tableBarGL, 'Text', 'Save As...', ...
        'ButtonPushedFcn', @onTableSaveAs, ...
        'BackgroundColor', [0.15 0.45 0.75], 'FontColor', [1 1 1], ...
        'FontSize', 8, ...
        'Tooltip', 'Save edited table to a new CSV or Excel file');
    btnTableSaveAs.Layout.Column = 1;

    btnTableMask = uibutton(tableBarGL, 'Text', 'Mask Sel.', ...
        'ButtonPushedFcn', @onTableMaskSelected, ...
        'BackgroundColor', [0.55 0.15 0.15], 'FontColor', [1 1 1], ...
        'FontSize', 8, ...
        'Tooltip', 'Mask selected rows — excluded from plot and analysis');
    btnTableMask.Layout.Column = 2;

    btnTableUnmask = uibutton(tableBarGL, 'Text', 'Unmask', ...
        'ButtonPushedFcn', @onTableUnmaskAll, ...
        'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [0.8 0.8 0.8], ...
        'FontSize', 8, ...
        'Tooltip', 'Remove all row masks');
    btnTableUnmask.Layout.Column = 3;

    btnTableDescStats = uibutton(tableBarGL, 'Text', 'Stats', ...
        'ButtonPushedFcn', @onDescriptiveStats, ...
        'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [0.8 0.8 0.8], ...
        'FontSize', 8, ...
        'Tooltip', 'Per-column descriptive statistics');
    btnTableDescStats.Layout.Column = 4;

    btnSortAsc = uibutton(tableBarGL, 'Text', [char(9650) 'Asc'], ...
        'ButtonPushedFcn', @(~,~) onTableSort('ascend'), ...
        'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [0.8 0.8 0.8], ...
        'FontSize', 8, ...
        'Tooltip', 'Sort by selected column (ascending)');
    btnSortAsc.Layout.Column = 5;

    btnSortDesc = uibutton(tableBarGL, 'Text', [char(9660) 'Desc'], ...
        'ButtonPushedFcn', @(~,~) onTableSort('descend'), ...
        'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [0.8 0.8 0.8], ...
        'FontSize', 8, ...
        'Tooltip', 'Sort by selected column (descending)');
    btnSortDesc.Layout.Column = 6;

    lblTableStats = uilabel(tableBarGL, 'Text', '', ...
        'FontSize', 8, 'FontColor', [0.55 0.55 0.55], ...
        'HorizontalAlignment', 'right');
    lblTableStats.Layout.Column = 7;

    % Units row
    lblTableUnits = uilabel(dataTableInnerGL, 'Text', '', ...
        'FontSize', 8, 'FontColor', [0.5 0.7 0.5], ...
        'BackgroundColor', [0.16 0.16 0.16]);
    lblTableUnits.Layout.Row = 2;

    % Editable data table
    tblData = uitable(dataTableInnerGL, ...
        'ColumnName', {'(no data)'}, ...
        'Data', {}, ...
        'ColumnEditable', true, ...
        'CellEditCallback', @onTableCellEdit, ...
        'CellSelectionCallback', @onTableSelectionChanged, ...
        'FontSize', 9);
    tblData.Layout.Row = 3;
    appData.tableSelection = [];  % [Nx2] matrix of [row col] pairs

    axLimGL = uigridlayout(axLimPanel,[5 6], ...
        'RowHeight',    {22, 22, 0, 22, 0}, ...
        'ColumnWidth',  {24,'1x','1x','1x', 24, '1x'}, ...
        'Padding',      [4 2 4 2], ...
        'RowSpacing',   2, ...
        'ColumnSpacing', 3);

    % ── Row 1: X limits ──────────────────────────────────────────────
    AXLIM_BG = [0.17 0.17 0.17];
    AXLIM_FG = [0.92 0.92 0.92];

    lblXLim = uilabel(axLimGL,'Text','X:','HorizontalAlignment','right','FontSize',10);
    lblXLim.Layout.Row = 1; lblXLim.Layout.Column = 1;

    efXMin = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','min', 'Tooltip','X axis minimum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXMin.Layout.Row = 1; efXMin.Layout.Column = 2;

    efXMax = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','max', 'Tooltip','X axis maximum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXMax.Layout.Row = 1; efXMax.Layout.Column = 3;

    efXStep = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','step', 'Tooltip','X axis tick spacing — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXStep.Layout.Row = 1; efXStep.Layout.Column = 4;

    % X-row right side: X tick format dropdown
    lblFmtX = uilabel(axLimGL,'Text','fmt','FontSize',8,'HorizontalAlignment','right', ...
        'FontColor',[0.55 0.55 0.55]);
    lblFmtX.Layout.Row = 1; lblFmtX.Layout.Column = 5;
    ddXFmt = uidropdown(axLimGL, 'Items', TICKFMT_NAMES, 'ItemsData', TICKFMT_DATA, ...
        'Value', '', 'FontSize', 9, 'Tooltip', 'X-axis tick label notation', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddXFmt.Layout.Row = 1; ddXFmt.Layout.Column = 6;

    % ── Row 2: Y limits ──────────────────────────────────────────────
    lblYLim = uilabel(axLimGL,'Text','Y:','HorizontalAlignment','right','FontSize',10);
    lblYLim.Layout.Row = 2; lblYLim.Layout.Column = 1;

    efYMin = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','min', 'Tooltip','Y axis minimum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYMin.Layout.Row = 2; efYMin.Layout.Column = 2;

    efYMax = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','max', 'Tooltip','Y axis maximum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYMax.Layout.Row = 2; efYMax.Layout.Column = 3;

    efYStep = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','step', 'Tooltip','Y axis tick spacing — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYStep.Layout.Row = 2; efYStep.Layout.Column = 4;

    % Y-row right side: Y tick format dropdown
    lblFmtY = uilabel(axLimGL,'Text','fmt','FontSize',8,'HorizontalAlignment','right', ...
        'FontColor',[0.55 0.55 0.55]);
    lblFmtY.Layout.Row = 2; lblFmtY.Layout.Column = 5;
    ddYFmt = uidropdown(axLimGL, 'Items', YTICKFMT_NAMES, 'ItemsData', YTICKFMT_DATA, ...
        'Value', '__exp0', 'FontSize', 9, 'Tooltip', 'Left Y-axis tick label notation', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddYFmt.Layout.Row = 2; ddYFmt.Layout.Column = 6;

    % ── Row 3: Y2 limits (hidden until Y2 active) ────────────────────
    lblY2Lim = uilabel(axLimGL,'Text','Y2:','HorizontalAlignment','right','FontSize',10);
    lblY2Lim.Layout.Row = 3; lblY2Lim.Layout.Column = 1;

    efY2Min = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','min', 'Tooltip','Right Y-axis minimum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efY2Min.Layout.Row = 3; efY2Min.Layout.Column = 2;

    efY2Max = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','max', 'Tooltip','Right Y-axis maximum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efY2Max.Layout.Row = 3; efY2Max.Layout.Column = 3;

    efY2Step = uieditfield(axLimGL,'text','Value','', ...
        'Placeholder','step', 'Tooltip','Right Y-axis tick spacing — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efY2Step.Layout.Row = 3; efY2Step.Layout.Column = 4;

    lblFmtR = uilabel(axLimGL,'Text','fmt','FontSize',8,'HorizontalAlignment','right', ...
        'FontColor',[0.55 0.55 0.55]);
    lblFmtR.Layout.Row = 3; lblFmtR.Layout.Column = 5;
    ddY2Fmt = uidropdown(axLimGL, 'Items', YTICKFMT_NAMES, 'ItemsData', YTICKFMT_DATA, ...
        'Value', '', 'FontSize', 9, 'Tooltip', 'Right Y-axis tick label notation', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddY2Fmt.Layout.Row = 3; ddY2Fmt.Layout.Column = 6;

    % ── Row 4: Action buttons + legend + color ───────────────────────
    btnSmartScale = uibutton(axLimGL,'Text','Auto', ...
        'ButtonPushedFcn',@onSmartScale, 'FontSize', 9, ...
        'Tooltip','Auto-detect linear/log scale and set reasonable axis limits');
    btnSmartScale.Layout.Row = 4; btnSmartScale.Layout.Column = 1;

    btnAutoLimits = uibutton(axLimGL,'Text','Reset', ...
        'ButtonPushedFcn',@onAutoLimits, 'FontSize', 9, ...
        'Tooltip','Clear all manual axis limits and reset to auto-scale');
    btnAutoLimits.Layout.Row = 4; btnAutoLimits.Layout.Column = 2;

    cbShowLegend = uicheckbox(axLimGL, ...
        'Text', 'Legend', 'Value', true, 'FontSize', 9, ...
        'Tooltip', 'Show/hide the plot legend', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    cbShowLegend.Layout.Row = 4; cbShowLegend.Layout.Column = 3;

    ddDatasetColor = uidropdown(axLimGL, ...
        'Items', DS_COLOR_NAMES, 'ItemsData', DS_COLOR_RGBS, ...
        'Value', [], 'Enable', 'off', ...
        'Tooltip', 'Override line colour ("Auto" uses the palette)', ...
        'ValueChangedFcn', @onDatasetColorChanged);
    ddDatasetColor.Layout.Row = 4; ddDatasetColor.Layout.Column = [4 6];

    ddDatasetColorR = uidropdown(axLimGL, ...
        'Items', DS_COLOR_NAMES, 'ItemsData', DS_COLOR_RGBS, ...
        'Value', [], 'Enable', 'off', 'Visible', 'off', ...
        'Tooltip', 'Override right-axis line colour', ...
        'ValueChangedFcn', @onDatasetColorRChanged);
    ddDatasetColorR.Layout.Row = 4; ddDatasetColorR.Layout.Column = 6;

    % ── Row 5: Appearance extras (collapsible — default hidden) ──────
    % Contains: title, labels, legend name, ref lines — all in a nested grid
    AXLIM_ADV_ROW = 5;
    AXLIM_ADV_HEIGHT = 90;
    appData.sectionCollapsed.axAppearance = true;

    axAdvGL = uigridlayout(axLimGL, [4 6], ...
        'RowHeight', {20, 20, 20, 20}, ...
        'ColumnWidth', {32, '1x', 32, '1x', '1x', '1x'}, ...
        'Padding', [0 0 0 0], 'RowSpacing', 2, 'ColumnSpacing', 2);
    axAdvGL.Layout.Row = 5; axAdvGL.Layout.Column = [1 6];

    % Adv row 1: Title field + legend name
    lblApTitle = uilabel(axAdvGL,'Text','Title:','FontSize',9,'HorizontalAlignment','right');
    lblApTitle.Layout.Row = 1; lblApTitle.Layout.Column = 1;
    efCustomTitle = uieditfield(axAdvGL,'text','Value','', ...
        'Placeholder','auto', 'Tooltip','Override the plot title — blank = auto', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomTitle.Layout.Row = 1; efCustomTitle.Layout.Column = [2 4];
    lblApLegend = uilabel(axAdvGL,'Text','Leg:','FontSize',9,'HorizontalAlignment','right');
    lblApLegend.Layout.Row = 1; lblApLegend.Layout.Column = 5;
    efLegendName = uieditfield(axAdvGL,'text','Value','', ...
        'Enable','off', 'Placeholder','auto', ...
        'Tooltip','Override the legend label — blank = auto', ...
        'ValueChangedFcn', @onLegendNameChanged);
    efLegendName.Layout.Row = 1; efLegendName.Layout.Column = 6;
    efLegendNameR = uieditfield(axAdvGL,'text','Value','', ...
        'Enable','off', 'Visible','off', 'Placeholder','auto', ...
        'Tooltip','Override right-axis legend label', ...
        'ValueChangedFcn', @onLegendNameRChanged);
    efLegendNameR.Layout.Row = 1; efLegendNameR.Layout.Column = 6;

    % Adv row 2: X label + Y label
    lblApXLabel = uilabel(axAdvGL,'Text','X lbl:','FontSize',9,'HorizontalAlignment','right');
    lblApXLabel.Layout.Row = 2; lblApXLabel.Layout.Column = 1;
    efCustomXLabel = uieditfield(axAdvGL,'text','Value','', ...
        'Placeholder','auto', 'Tooltip','Override X-axis label — blank = auto', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomXLabel.Layout.Row = 2; efCustomXLabel.Layout.Column = [2 3];
    lblApYLabel = uilabel(axAdvGL,'Text','Y lbl:','FontSize',9,'HorizontalAlignment','right');
    lblApYLabel.Layout.Row = 2; lblApYLabel.Layout.Column = 4;
    efCustomYLabel = uieditfield(axAdvGL,'text','Value','', ...
        'Placeholder','auto', 'Tooltip','Override left Y-axis label — blank = auto', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomYLabel.Layout.Row = 2; efCustomYLabel.Layout.Column = [5 6];
    efCustomY2Label = uieditfield(axAdvGL,'text','Value','', ...
        'Visible','off', 'Placeholder','auto', ...
        'Tooltip','Override right Y-axis label — blank = auto', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomY2Label.Layout.Row = 2; efCustomY2Label.Layout.Column = 6;

    % Adv row 3: Reference lines
    btnAddHLine = uibutton(axAdvGL,'Text','+ H Line', ...
        'ButtonPushedFcn', @onAddHRefLine, 'FontSize', 9, ...
        'Tooltip', 'Add a horizontal reference line at a specified Y value');
    btnAddHLine.Layout.Row = 3; btnAddHLine.Layout.Column = [1 2];
    btnAddVLine = uibutton(axAdvGL,'Text','+ V Line', ...
        'ButtonPushedFcn', @onAddVRefLine, 'FontSize', 9, ...
        'Tooltip', 'Add a vertical reference line at a specified X value');
    btnAddVLine.Layout.Row = 3; btnAddVLine.Layout.Column = [3 4];
    btnClearRefLines = uibutton(axAdvGL,'Text','Clear Lines', ...
        'ButtonPushedFcn', @onClearRefLines, 'FontSize', 9, ...
        'Tooltip', 'Remove all reference lines');
    btnClearRefLines.Layout.Row = 3; btnClearRefLines.Layout.Column = [5 6];

    % Adv row 4: More... toggle to show/hide this section (placed last)


    % "More..." toggle in row 4 to expand/collapse appearance extras (row 5)
    btnAxMore = uibutton(axLimGL, 'Text', [char(9654) ' More'], ...
        'FontSize', 8, 'FontColor', [0.55 0.55 0.55], ...
        'BackgroundColor', axLimGL.BackgroundColor, ...
        'HorizontalAlignment', 'left', ...
        'ButtonPushedFcn', @(~,~) onToggleAxAppearance());
    btnAxMore.Layout.Row = 4; btnAxMore.Layout.Column = [5 6];

    % ── Save / Export panel (analysisGL col 3 — vertical, collapsible) ─────
    savePanel = uipanel(analysisGL,'Title','Save / Export','FontSize',10, ...
        'Scrollable','on');
    savePanel.Layout.Row = [1 2]; savePanel.Layout.Column = 3;

    % Vertical stacked layout with collapsible section headers
    % Rows: [hdrData, dataContent, hdrFig, figContent, hdrSession, sessionContent, hdrTools, toolsContent]
    SAVE_SEC_H = 20;    % header row height
    SAVE_ROW_H = 78;    % content block height (3 rows of 24 + spacing)
    saveGL = uigridlayout(savePanel,[8 1], ...
        'RowHeight', {SAVE_SEC_H, SAVE_ROW_H, SAVE_SEC_H, 0, SAVE_SEC_H, 0, SAVE_SEC_H, 0}, ...
        'ColumnWidth', {'1x'}, ...
        'Padding',     [2 2 2 2], ...
        'RowSpacing',  1);

    % Hidden path field — parented to fig (invisible), only read/written by callbacks
    efSavePath = uieditfield(fig,'Value','','Visible','off', ...
        'Placeholder','(auto-set on dataset load or Apply)', ...
        'Tooltip','Output CSV file path');

    % Section collapse state
    appData.saveSectionRows = struct( ...
        'dataExport', 2, 'figExport', 4, 'session', 6, 'tools', 8);
    appData.saveSectionHeights = struct( ...
        'dataExport', SAVE_ROW_H, 'figExport', SAVE_ROW_H, ...
        'session', SAVE_ROW_H, 'tools', SAVE_ROW_H);

    % ── Header: Data Export (open by default) ────────────────────────
    btnSaveHdrData = uibutton(saveGL,'Text',[char(9660) ' Data Export'], ...
        'FontSize',9,'FontWeight','bold','HorizontalAlignment','left', ...
        'BackgroundColor',[0.18 0.18 0.18],'FontColor',[0.85 0.85 0.85], ...
        'ButtonPushedFcn', @(~,~) toggleSaveSection('dataExport','Data Export'));
    btnSaveHdrData.Layout.Row = 1;

    saveDataGL = uigridlayout(saveGL, [3 2], ...
        'RowHeight', {24, 24, 24}, 'ColumnWidth', {'1x','1x'}, ...
        'Padding', [0 0 0 0], 'RowSpacing', 2, 'ColumnSpacing', 3);
    saveDataGL.Layout.Row = 2;

    ddExportFormat = uidropdown(saveDataGL, ...
        'Items',   {'Standard CSV', 'Origin ASCII'}, ...
        'Value',   'Standard CSV', ...
        'Tooltip', 'CSV format: Standard or Origin ASCII');
    ddExportFormat.Layout.Row = 1; ddExportFormat.Layout.Column = 1;

    btnSaveBrowse = uibutton(saveDataGL,'Text','Browse...', ...
        'ButtonPushedFcn',@onSaveBrowse, ...
        'Tooltip','Choose output file location');
    btnSaveBrowse.Layout.Row = 1; btnSaveBrowse.Layout.Column = 2;

    btnSave = uibutton(saveDataGL,'Text','Save CSV', ...
        'ButtonPushedFcn',@onSaveCSV, ...
        'BackgroundColor',BTN_EXPORT, ...
        'FontColor',BTN_FG,'FontWeight','bold', ...
        'Tooltip','Write data to CSV');
    btnSave.Layout.Row = 2; btnSave.Layout.Column = 1;

    btnBatchExport = uibutton(saveDataGL,'Text','Batch All', ...
        'ButtonPushedFcn',@onBatchExportCSV, ...
        'BackgroundColor',BTN_EXPORT, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Export all datasets to separate CSV files');
    btnBatchExport.Layout.Row = 2; btnBatchExport.Layout.Column = 2;

    btnCopyDataClip = uibutton(saveDataGL,'Text','Copy Data', ...
        'ButtonPushedFcn', @onCopyDataToClipboard, ...
        'BackgroundColor', BTN_EXPORT, ...
        'FontColor', BTN_FG, ...
        'Tooltip', 'Copy to clipboard (tab-delimited)');
    btnCopyDataClip.Layout.Row = 3; btnCopyDataClip.Layout.Column = 1;

    btnExportHDF5 = uibutton(saveDataGL,'Text','HDF5...', ...
        'ButtonPushedFcn',@onExportHDF5, ...
        'BackgroundColor',BTN_EXTERNAL, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Export to HDF5 (.h5)');
    btnExportHDF5.Layout.Row = 3; btnExportHDF5.Layout.Column = 2;

    % ── Header: Figure Export (collapsed by default) ─────────────────
    btnSaveHdrFig = uibutton(saveGL,'Text',[char(9654) ' Figure Export'], ...
        'FontSize',9,'FontWeight','bold','HorizontalAlignment','left', ...
        'BackgroundColor',[0.18 0.18 0.18],'FontColor',[0.85 0.85 0.85], ...
        'ButtonPushedFcn', @(~,~) toggleSaveSection('figExport','Figure Export'));
    btnSaveHdrFig.Layout.Row = 3;

    saveFigGL = uigridlayout(saveGL, [3 2], ...
        'RowHeight', {24, 24, 24}, 'ColumnWidth', {'1x','1x'}, ...
        'Padding', [0 0 0 0], 'RowSpacing', 2, 'ColumnSpacing', 3);
    saveFigGL.Layout.Row = 4;

    btnExportFig = uibutton(saveFigGL,'Text','To Figure', ...
        'ButtonPushedFcn',@onExportFigure, ...
        'BackgroundColor',BTN_SECONDARY, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Open in new figure window');
    btnExportFig.Layout.Row = 1; btnExportFig.Layout.Column = 1;

    btnCopyClip = uibutton(saveFigGL,'Text','Copy Plot', ...
        'ButtonPushedFcn',@onCopyToClipboard, ...
        'BackgroundColor',BTN_SECONDARY, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Copy plot to clipboard [Ctrl+C]');
    btnCopyClip.Layout.Row = 1; btnCopyClip.Layout.Column = 2;

    ddFigFormat = uidropdown(saveFigGL, ...
        'Items',   {'PNG (300 dpi)', 'PDF (vector)', 'SVG (vector)', 'TIFF (300 dpi)', 'MATLAB .fig'}, ...
        'Value',   'PNG (300 dpi)', ...
        'Tooltip', 'Output format');
    ddFigFormat.Layout.Row = 2; ddFigFormat.Layout.Column = 1;

    btnSaveFig = uibutton(saveFigGL,'Text','Save Figure', ...
        'ButtonPushedFcn',@onSaveFigure, ...
        'BackgroundColor',BTN_SECONDARY, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Save figure to file');
    btnSaveFig.Layout.Row = 2; btnSaveFig.Layout.Column = 2;

    figDimGL = uigridlayout(saveFigGL, [1 4], ...
        'Padding', [0 0 0 0], 'ColumnSpacing', 2, ...
        'ColumnWidth', {40, '1x', 12, '1x'});
    figDimGL.Layout.Row = 3; figDimGL.Layout.Column = [1 2];

    uilabel(figDimGL, 'Text', 'Size:', 'FontSize', 8, ...
        'HorizontalAlignment', 'right');
    efFigWidth = uieditfield(figDimGL, 'numeric', 'Value', 7, ...
        'Limits', [1 30], 'Tooltip', 'Width (in)');
    efFigWidth.Layout.Column = 2;
    uilabel(figDimGL, 'Text', char(215), 'FontSize', 9, ...
        'HorizontalAlignment', 'center');
    efFigHeight = uieditfield(figDimGL, 'numeric', 'Value', 5, ...
        'Limits', [1 30], 'Tooltip', 'Height (in)');
    efFigHeight.Layout.Column = 4;

    % ── Header: Session (collapsed by default) ───────────────────────
    btnSaveHdrSession = uibutton(saveGL,'Text',[char(9654) ' Session'], ...
        'FontSize',9,'FontWeight','bold','HorizontalAlignment','left', ...
        'BackgroundColor',[0.18 0.18 0.18],'FontColor',[0.85 0.85 0.85], ...
        'ButtonPushedFcn', @(~,~) toggleSaveSection('session','Session'));
    btnSaveHdrSession.Layout.Row = 5;

    saveSessionGL = uigridlayout(saveGL, [3 2], ...
        'RowHeight', {24, 24, 24}, 'ColumnWidth', {'1x','1x'}, ...
        'Padding', [0 0 0 0], 'RowSpacing', 2, 'ColumnSpacing', 3);
    saveSessionGL.Layout.Row = 6;

    btnSaveSession = uibutton(saveSessionGL,'Text','Save...', ...
        'ButtonPushedFcn',@onSaveSession, ...
        'BackgroundColor',BTN_SESSION, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Save session (.mat) [Ctrl+S]');
    btnSaveSession.Layout.Row = 1; btnSaveSession.Layout.Column = 1;

    btnLoadSession = uibutton(saveSessionGL,'Text','Load...', ...
        'ButtonPushedFcn',@onLoadSession, ...
        'BackgroundColor',BTN_SESSION, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Load session (.mat)');
    btnLoadSession.Layout.Row = 1; btnLoadSession.Layout.Column = 2;

    btnSendOrigin = uibutton(saveSessionGL,'Text','Send to Origin', ...
        'ButtonPushedFcn', @onSendToOrigin, ...
        'BackgroundColor', BTN_EXTERNAL, ...
        'FontColor', BTN_FG, ...
        'Tooltip', 'Send data to OriginPro via COM');
    btnSendOrigin.Layout.Row = 2; btnSendOrigin.Layout.Column = 1;

    btnExportOriginScript = uibutton(saveSessionGL,'Text','Origin Script', ...
        'ButtonPushedFcn', @onExportOriginScript, ...
        'BackgroundColor', BTN_EXTERNAL, ...
        'FontColor', BTN_FG, ...
        'Tooltip', 'Write LabTalk .ogs + CSV');
    btnExportOriginScript.Layout.Row = 2; btnExportOriginScript.Layout.Column = 2;

    % ── Header: Tools (collapsed by default) ─────────────────────────
    btnSaveHdrTools = uibutton(saveGL,'Text',[char(9654) ' Tools'], ...
        'FontSize',9,'FontWeight','bold','HorizontalAlignment','left', ...
        'BackgroundColor',[0.18 0.18 0.18],'FontColor',[0.85 0.85 0.85], ...
        'ButtonPushedFcn', @(~,~) toggleSaveSection('tools','Tools'));
    btnSaveHdrTools.Layout.Row = 7;

    saveToolsGL = uigridlayout(saveGL, [5 2], ...
        'RowHeight', {24, 24, 24, 24, 24}, 'ColumnWidth', {'1x','1x'}, ...
        'Padding', [0 0 0 0], 'RowSpacing', 2, 'ColumnSpacing', 3);
    saveToolsGL.Layout.Row = 8;

    % Row 1: Batch XRD + Layout
    btnBatchConvertXRD = uibutton(saveToolsGL,'Text','Batch XRD', ...
        'ButtonPushedFcn', @onBatchConvertXRD, ...
        'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
        'Tooltip', 'Batch XRD converter');
    btnBatchConvertXRD.Layout.Row = 1; btnBatchConvertXRD.Layout.Column = 1;

    btnLayoutSettings = uibutton(saveToolsGL,'Text','Layout...', ...
        'ButtonPushedFcn', @onOpenLayoutSettings, ...
        'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
        'Tooltip', 'Layout settings');
    btnLayoutSettings.Layout.Row = 1; btnLayoutSettings.Layout.Column = 2;

    % Row 2: Cursor + Figures
    btnDataCursor = uibutton(saveToolsGL,'Text','Cursor', ...
        'ButtonPushedFcn', @onToggleDataCursor, ...
        'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
        'Tooltip', 'Toggle interactive data cursor — click to read (x,y), click again for delta');
    btnDataCursor.Layout.Row = 2; btnDataCursor.Layout.Column = 1;

    btnAdvFigure = uibutton(saveToolsGL,'Text','Figures...', ...
        'ButtonPushedFcn', @onAdvancedFigureBuilder, ...
        'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
        'Tooltip', 'Advanced Figure Builder');
    btnAdvFigure.Layout.Row = 2; btnAdvFigure.Layout.Column = 2;

    % Row 3: Overlay + Templates
    cbOverlayMode = uicheckbox(saveToolsGL, ...
        'Text', 'Overlay', ...
        'Value', false, ...
        'Tooltip', 'Overlay selected datasets on the same axes with unified legend', ...
        'ValueChangedFcn', @onOverlayModeChanged);
    cbOverlayMode.Layout.Row = 3; cbOverlayMode.Layout.Column = 1;

    btnTemplates = uibutton(saveToolsGL,'Text','Templates...', ...
        'ButtonPushedFcn', @onPlotTemplates, ...
        'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
        'Tooltip', 'Save/load plot formatting presets (axis limits, corrections, labels)');
    btnTemplates.Layout.Row = 3; btnTemplates.Layout.Column = 2;

    % Row 4: Batch Fig Export
    btnBatchFigExport = uibutton(saveToolsGL,'Text','Batch Figs...', ...
        'ButtonPushedFcn', @onBatchFigureExport, ...
        'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
        'Tooltip', 'Export all datasets as individual figures with consistent formatting');
    btnBatchFigExport.Layout.Row = 4; btnBatchFigExport.Layout.Column = 1;

    uilabel(saveToolsGL,'Text','');  % spacer
    saveToolsGL.Children(end).Layout.Row = 4;
    saveToolsGL.Children(end).Layout.Column = 2;

    % Row 5: Advanced menu button (full width, prominent)
    btnAdvanced = uibutton(saveToolsGL,'Text',[char(9881) ' Advanced Analysis ' char(9662)], ...
        'ButtonPushedFcn', @onShowAdvancedMenu, ...
        'BackgroundColor', [0.22 0.44 0.22], 'FontColor', [1 1 1], ...
        'FontWeight', 'bold', ...
        'Tooltip', 'Advanced analysis & correction tools (integrate, math, resample, inset, ...)');
    btnAdvanced.Layout.Row = 5; btnAdvanced.Layout.Column = [1 2];

    % ── Peak Analysis window (separate uifigure) ──────────────────────────
    % The peak table + controls live in their own window, opened on demand.
    peakFig = uifigure('Name', 'Peak Analysis', 'Visible', 'off', ...
        'Position', [200 150 580 620], ...
        'CloseRequestFcn', @(~,~) set(peakFig, 'Visible', 'off'));

    peakRootGL = uigridlayout(peakFig, [3 1], ...
        'RowHeight', {'1x', 340, 24}, ...
        'Padding', [6 6 6 6], 'RowSpacing', 4);

    peakTable = uitable(peakRootGL, ...
        'ColumnName',     {'#','Center (°)','d (Å)','Size (nm)','FWHM (°)','Height','Area',char(951),'Status'}, ...
        'ColumnWidth',    {22, 82, 70, 70, 68, 65, 65, 38, 55}, ...
        'Data',           {}, ...
        'RowName',        {}, ...
        'ColumnEditable', [false false false false false false false false false], ...
        'CellSelectionCallback', @onPeakTableSelect, ...
        'Tooltip','Detected peaks — select a row to highlight it on the plot');
    peakTable.Layout.Row = 1;

    % Peak buttons — 2-column layout: fitting/actions on left, export/settings on right
    peakBtnGL = uigridlayout(peakRootGL, [10 2], ...
        'RowHeight',    {24,22,22,22,22,22,0, 18, 0, 96}, ...
        'ColumnWidth',  {'1x','1x'}, ...
        'Padding',      [0 0 0 0], ...
        'RowSpacing',   2, ...
        'ColumnSpacing', 4);
    peakBtnGL.Layout.Row = 2;

    % Row 1: Fit model dropdown (spans both columns)
    ddFitModel = uidropdown(peakBtnGL, ...
        'Items',   {'Lorentzian', 'Gaussian', 'Pseudo-Voigt', 'Split Pearson VII'}, ...
        'Value',   'Lorentzian', ...
        'Tooltip', ['Peak shape model: Lorentzian, Gaussian, Pseudo-Voigt (' char(951) char(183) ...
                    'L + (1-' char(951) ')' char(183) 'G), or Split Pearson VII (asymmetric)']);
    ddFitModel.Layout.Row = 1; ddFitModel.Layout.Column = [1 2];

    % Row 2: Fit Peaks | Fit All
    btnFitPeaks = uibutton(peakBtnGL,'Text','Fit Peaks', ...
        'ButtonPushedFcn',@onFitPeaks, ...
        'BackgroundColor',BTN_ACCENT,'FontColor',BTN_FG, ...
        'Tooltip','Fit the selected model to each listed peak and extract precise center and FWHM');
    btnFitPeaks.Layout.Row = 2; btnFitPeaks.Layout.Column = 1;

    btnFitAllPeaks = uibutton(peakBtnGL,'Text','Fit All (global)', ...
        'ButtonPushedFcn',@onFitAllPeaks, ...
        'BackgroundColor',BTN_ACCENT,'FontColor',BTN_FG, ...
        'Tooltip','Fit all peaks simultaneously as a single multi-peak model (requires ≥2 peaks)');
    btnFitAllPeaks.Layout.Row = 2; btnFitAllPeaks.Layout.Column = 2;

    % Row 3: Clear All | Remove Selected
    btnClearPeaks = uibutton(peakBtnGL,'Text','Clear All', ...
        'ButtonPushedFcn',@onClearPeaks, ...
        'Tooltip','Remove all peaks for the active dataset');
    btnClearPeaks.Layout.Row = 3; btnClearPeaks.Layout.Column = 1;

    btnRemovePeak = uibutton(peakBtnGL,'Text','Remove Sel.', ...
        'ButtonPushedFcn',@onRemoveSelectedPeak, ...
        'Tooltip','Remove the currently highlighted peak from the list');
    btnRemovePeak.Layout.Row = 3; btnRemovePeak.Layout.Column = 2;

    % Row 4: Export CSV | Export XLSX
    btnSavePeaks = uibutton(peakBtnGL,'Text','Export CSV', ...
        'ButtonPushedFcn',@onSavePeakSummary, ...
        'BackgroundColor',BTN_EXPORT,'FontColor',BTN_FG, ...
        'Tooltip','Save peak centers and FWHM values to a CSV file');
    btnSavePeaks.Layout.Row = 4; btnSavePeaks.Layout.Column = 1;

    btnExportPeakXLSX = uibutton(peakBtnGL,'Text','Export XLSX', ...
        'ButtonPushedFcn',@onExportPeakXLSX, ...
        'BackgroundColor',BTN_EXPORT,'FontColor',BTN_FG, ...
        'Tooltip','Export peak data from all datasets to an Excel file (.xlsx)');
    btnExportPeakXLSX.Layout.Row = 4; btnExportPeakXLSX.Layout.Column = 2;

    % Row 5: Copy Peaks | Fit Color
    btnCopyPeaksClip = uibutton(peakBtnGL,'Text','Copy Peaks', ...
        'ButtonPushedFcn', @onCopyPeaksToClipboard, ...
        'BackgroundColor', BTN_SECONDARY, 'FontColor', BTN_FG, ...
        'Tooltip', 'Copy peak table as tab-delimited text to clipboard');
    btnCopyPeaksClip.Layout.Row = 5; btnCopyPeaksClip.Layout.Column = 1;

    btnFitColor = uibutton(peakBtnGL, 'Text', 'Fit color...', ...
        'Tooltip',           'Pick the color used for fit curve overlays', ...
        'ButtonPushedFcn',   @onPickFitColor);
    btnFitColor.Layout.Row = 5; btnFitColor.Layout.Column = 2;
    btnFitColor.BackgroundColor = appData.fitCurveColor;

    % Row 6: Show fit curves | Reflectivity FFT
    chkShowFit = uicheckbox(peakBtnGL, ...
        'Text',              'Show fit curves', ...
        'Value',             true, ...
        'Tooltip',           'Overlay fit curves on the plot', ...
        'ValueChangedFcn',   @onToggleFitCurves);
    chkShowFit.Layout.Row = 6; chkShowFit.Layout.Column = 1;

    btnReflFFT = uibutton(peakBtnGL, 'Text', 'Refl. FFT', ...
        'ButtonPushedFcn', @onReflectivityFFT, ...
        'BackgroundColor', BTN_ACCENT, 'FontColor', BTN_FG, ...
        'Tooltip', ['Compute film thickness from Kiessig fringes via FFT.' newline ...
                    'For neutron/XRR data (Q-space). Also works for XRD in 2' char(952) ...
                    '-space if wavelength is set.']);
    btnReflFFT.Layout.Row = 6; btnReflFFT.Layout.Column = 2;

    % Row 7: Fringe thickness (2-click) — visible only in reflectometry mode
    btnFringeThick = uibutton(peakBtnGL, 'Text', ['Fringe ' char(916) 't (2-click)'], ...
        'ButtonPushedFcn', @onArmFringeThickness, ...
        'BackgroundColor', BTN_ACCENT, 'FontColor', BTN_FG, ...
        'FontSize', 9, ...
        'Tooltip', ['Pick two fringe peaks to estimate film thickness via t = 2' char(960) ...
                    '/' char(916) 'Q.  Points are draggable for refinement.']);
    btnFringeThick.Layout.Row = 7; btnFringeThick.Layout.Column = [1 2];
    btnFringeThick.Visible = 'off';  % shown only for reflectometry data

    % Row 8: "Advanced..." toggle (collapsed by default)
    PEAK_ADV_ROWS = 9;
    PEAK_ADV_HEIGHTS = 46;
    btnMorePeak = uibutton(peakBtnGL, 'Text', [char(9654) ' Advanced...'], ...
        'FontSize', 9, 'FontColor', [0.55 0.55 0.55], ...
        'BackgroundColor', peakBtnGL.BackgroundColor, ...
        'HorizontalAlignment', 'left', ...
        'ButtonPushedFcn', @(~,~) onToggleAdvancedPeakTools());
    btnMorePeak.Layout.Row = 8; btnMorePeak.Layout.Column = [1 2];

    % Row 8: Advanced peak tools (collapsed by default) — 2x3 sub-grid
    peakAdvGL = uigridlayout(peakBtnGL, [2 3], ...
        'Padding', [0 0 0 0], 'ColumnSpacing', 3, 'RowSpacing', 2, ...
        'ColumnWidth', {'1x','1x','1x'}, 'RowHeight', {22, 22});
    peakAdvGL.Layout.Row = 9; peakAdvGL.Layout.Column = [1 2];

    btnWHPlot = uibutton(peakAdvGL, 'Text', 'W-H Plot', ...
        'ButtonPushedFcn', @onWilliamsonHallPlot, ...
        'BackgroundColor', BTN_ACCENT, 'FontColor', BTN_FG, ...
        'Tooltip', ['Williamson-Hall strain analysis: plot ' char(946) char(183) ...
                    'cos' char(952) ' vs 4' char(183) 'sin' char(952) ...
                    '.  Needs ' char(8805) '3 fitted peaks.']);
    btnWHPlot.Layout.Row = 1; btnWHPlot.Layout.Column = 1;

    btnFFTThickness = uibutton(peakAdvGL, 'Text', 'FFT Thick.', ...
        'ButtonPushedFcn', @onFFTThickness, ...
        'BackgroundColor', BTN_ACCENT, 'FontColor', BTN_FG, ...
        'Tooltip', 'Compute film thickness from Laue / Kiessig fringe periodicity via FFT');
    btnFFTThickness.Layout.Row = 1; btnFFTThickness.Layout.Column = 2;

    btnRefineLattice = uibutton(peakAdvGL, 'Text', 'Lattice...', ...
        'ButtonPushedFcn', @onRefineLattice, ...
        'BackgroundColor', BTN_ACCENT, 'FontColor', BTN_FG, ...
        'Tooltip', 'Refine lattice parameters from fitted peak positions + hkl Miller indices');
    btnRefineLattice.Layout.Row = 1; btnRefineLattice.Layout.Column = 3;

    btnMatchPhases = uibutton(peakAdvGL, 'Text', 'Match Phases', ...
        'ButtonPushedFcn', @onMatchPhases, ...
        'BackgroundColor', [0.20 0.50 0.35], 'FontColor', BTN_FG, ...
        'Tooltip', ['Match detected peak d-spacings against a built-in database of ~50 phases ' ...
                    '(metals, oxides, substrates, perovskites). Tolerance slider adjustable.']);
    btnMatchPhases.Layout.Row = 2; btnMatchPhases.Layout.Column = [1 3];

    % Row 9: Min sep / wavelength / source / K factor / instrument broadening (shared sub-grid)
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

    minSepGL = uigridlayout(peakBtnGL, [4 4], ...
        'RowHeight', {22,22,24,20}, 'ColumnWidth', {50, '1x', 50, '1x'}, ...
        'Padding', [0 0 0 0], 'ColumnSpacing', 3, 'RowSpacing', 2);
    minSepGL.Layout.Row = 10; minSepGL.Layout.Column = [1 2];
    % Row 1: Min sep | Wavelength (side by side)
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
    lblWavelength.Layout.Row = 1; lblWavelength.Layout.Column = 3;
    efWavelength = uieditfield(minSepGL, 'numeric', ...
        'Value', 0, 'Limits', [0 Inf], ...
        'Tooltip', ['Wavelength in Å for d-spacing & Scherrer.  ' ...
                    'Auto-filled from file metadata when available.  ' ...
                    'Cu K' char(945) '1 = 1.5406 Å.  0 = not set.'], ...
        'ValueChangedFcn', @onWavelengthChanged);
    efWavelength.Layout.Row = 1; efWavelength.Layout.Column = 4;
    % Row 2: K factor | Inst broadening (side by side)
    lblKFactor = uilabel(minSepGL, 'Text', 'K:', 'FontSize', 9, ...
        'HorizontalAlignment', 'right', ...
        'Tooltip', 'Scherrer shape factor K (0.9 for spherical grains, 1.0 for cubic)');
    lblKFactor.Layout.Row = 2; lblKFactor.Layout.Column = 1;
    efKFactor = uieditfield(minSepGL, 'numeric', ...
        'Value', appData.kFactor, 'Limits', [0.1 2], ...
        'Tooltip', 'Scherrer shape factor K — 0.9 (spherical) or 1.0 (cubic). Affects Size (nm) column.', ...
        'ValueChangedFcn', @onKFactorChanged);
    efKFactor.Layout.Row = 2; efKFactor.Layout.Column = 2;
    lblInstB = uilabel(minSepGL, 'Text', ['Inst ', char(946), ':'], 'FontSize', 9, ...
        'HorizontalAlignment', 'right', ...
        'Tooltip', ['Instrument broadening FWHM in degrees (e.g. LaB6 standard).  ' ...
                    '0 = no correction.  Subtracted in quadrature: ' ...
                    char(946), char(8321), char(8325), char(8331), ...
                    ' = sqrt(', char(946), char(8322), char(8320), char(8322), char(8331), ...
                    ' - ', char(946), char(8321), char(8326), char(8331), char(8322), ')']);
    lblInstB.Layout.Row = 2; lblInstB.Layout.Column = 3;
    efInstBroadening = uieditfield(minSepGL, 'numeric', ...
        'Value', appData.instBroadening_deg, 'Limits', [0 5], ...
        'Tooltip', ['Instrument broadening FWHM (°). Enter the FWHM of a standard (e.g. LaB6) peak.  ' ...
                    '0 = no correction applied.'], ...
        'ValueChangedFcn', @onInstBroadeningChanged);
    efInstBroadening.Layout.Row = 2; efInstBroadening.Layout.Column = 4;
    % Row 3: X-ray source dropdown (spans all 4 columns)
    ddXraySource = uidropdown(minSepGL, ...
        'Items',   XRAY_SOURCES(:,1)', ...
        'Value',   XRAY_SOURCES{1,1}, ...
        'FontSize', 9, ...
        'Tooltip', 'Select X-ray source to auto-fill wavelength; pick Custom to type manually', ...
        'ValueChangedFcn', @onXraySourceChanged);
    ddXraySource.Layout.Row = 3; ddXraySource.Layout.Column = [1 4];
    % Row 4-6 are unused spacers (grid has 6 rows but only 3 used now)
    chkShowBG = uicheckbox(minSepGL, ...
        'Text',            'Show BG', ...
        'Value',           true, ...
        'FontSize',        9, ...
        'Tooltip',         'Overlay the estimated SNIP background curve on the plot', ...
        'ValueChangedFcn', @onToggleShowBG);
    chkShowBG.Layout.Row = 4; chkShowBG.Layout.Column = [1 2];

    % Row 3 of peakRootGL: help label
    lblPeakHelp = uilabel(peakRootGL, ...
        'Text', ['Select model ' char(8594) ' Fit Peaks.  Use Add Peak (main window) to click on the plot.  ' ...
                 'Close this window to hide; peaks stay on plot.'], ...
        'FontSize', 9, 'FontColor', [0.55 0.55 0.55], ...
        'HorizontalAlignment', 'center');
    lblPeakHelp.Layout.Row = 3;

    % ── 2D Map controls (col 3 of analysisGL — visible only for 2D data) ──
    map2DPanel = uipanel(analysisGL,'Title','2D Map View','FontSize',11, ...
        'Scrollable','on');
    map2DPanel.Layout.Row = [1 2]; map2DPanel.Layout.Column = 4;
    map2DPanel.Visible = 'off';   % shown only when a 2D area-detector dataset is active

    map2DGL = uigridlayout(map2DPanel,[11 2], ...
        'RowHeight',    {20, 20, 20, 20, 20, 20, 20, 22, 18, 18, '1x'}, ...
        'ColumnWidth',  {85, '1x'}, ...
        'Padding',      [4 4 4 4], ...
        'RowSpacing',   3, ...
        'ColumnSpacing', 4);

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

    lblMap2DCmap = uilabel(map2DGL,'Text','Color scale:','FontSize',10,'HorizontalAlignment','right');
    lblMap2DCmap.Layout.Row = 4; lblMap2DCmap.Layout.Column = 1;
    MAP2D_CMAPS = {'parula','viridis','plasma','inferno','hot','jet','turbo','gray','bone','copper'};
    ddMap2DCmap = uidropdown(map2DGL, ...
        'Items',           MAP2D_CMAPS, ...
        'Value',           'parula', ...
        'Tooltip',         'Colormap for 2D heatmap / contour display', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddMap2DCmap.Layout.Row = 4; ddMap2DCmap.Layout.Column = 2;

    % Row 5: Intensity scale (log/linear)
    lblMap2DScale = uilabel(map2DGL,'Text','Intensity:','FontSize',10,'HorizontalAlignment','right');
    lblMap2DScale.Layout.Row = 5; lblMap2DScale.Layout.Column = 1;
    ddMap2DScale = uidropdown(map2DGL, ...
        'Items',           {'Linear','Log₁₀'}, ...
        'Value',           'Log₁₀', ...
        'Tooltip',         'Linear or log₁₀ intensity scaling for the 2D map', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddMap2DScale.Layout.Row = 5; ddMap2DScale.Layout.Column = 2;

    % Row 6: Colorbar range min
    lblMap2DCMin = uilabel(map2DGL,'Text','CBar min:','FontSize',10,'HorizontalAlignment','right');
    lblMap2DCMin.Layout.Row = 6; lblMap2DCMin.Layout.Column = 1;
    efMap2DCMin = uieditfield(map2DGL,'Value','','Placeholder','auto', ...
        'FontSize',10, ...
        'Tooltip','Minimum colorbar value (blank = auto)', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efMap2DCMin.Layout.Row = 6; efMap2DCMin.Layout.Column = 2;

    % Row 7: Colorbar range max
    lblMap2DCMax = uilabel(map2DGL,'Text','CBar max:','FontSize',10,'HorizontalAlignment','right');
    lblMap2DCMax.Layout.Row = 7; lblMap2DCMax.Layout.Column = 1;
    efMap2DCMax = uieditfield(map2DGL,'Value','','Placeholder','auto', ...
        'FontSize',10, ...
        'Tooltip','Maximum colorbar value (blank = auto)', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efMap2DCMax.Layout.Row = 7; efMap2DCMax.Layout.Column = 2;

    btnPoleFigure = uibutton(map2DGL,'Text','Pole Figure...', ...
        'ButtonPushedFcn',@onPoleFigure, ...
        'BackgroundColor',[0.30 0.45 0.55], ...
        'FontColor',[1 1 1], ...
        'Tooltip','Open a polar plot of integrated intensity at a chosen 2θ position');
    btnPoleFigure.Layout.Row = 8; btnPoleFigure.Layout.Column = [1 2];

    lblMap2DInfo = uilabel(map2DGL,'Text','', ...
        'FontSize', 9, ...
        'FontColor', [0.4 0.4 0.4], ...
        'HorizontalAlignment', 'center', ...
        'WordWrap', 'on');
    lblMap2DInfo.Layout.Row = 9; lblMap2DInfo.Layout.Column = [1 2];

    lblMap2DHint = uilabel(map2DGL,'Text','Shift+click: H-cut  |  Ctrl+click: V-cut', ...
        'FontSize', 8, ...
        'FontColor', [0.55 0.55 0.55], ...
        'HorizontalAlignment', 'center');
    lblMap2DHint.Layout.Row = 10; lblMap2DHint.Layout.Column = [1 2];

    % ── Drag-and-drop: register every major surface as a drop target (R2023a+) ──
    % In uifigure the CEF renderer consumes drag events at whichever child
    % component is under the cursor; they do NOT bubble up to the figure.
    % Registering each panel/listbox/axes individually ensures that a file
    % dropped anywhere in the window is caught.
    dropSurfaces = {ctrlPanel, axPanel, ax, analysisPanel, ...
                    corrPanel, axLimPanel, savePanel, lbDatasets};
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

    % ── Apply initial button styles ─────────────────────────────────────
    updateApplyButtonStyle();

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
    api.showPeakWindow      = @showPeakWindow;
    api.peakFig             = peakFig;
    api.close               = @() close(fig);
    % 2D map API (used by test_gui_2d.m / test_gui_phase4.m)
    api.is2DActive          = @is2DActiveDirect;
    api.setMap2DType        = @setMap2DTypeDirect;
    api.extractLineCut2D    = @extractLineCut2DDirect;
    api.setQSpace           = @setQSpaceDirect;
    api.setContourLevels    = @setContourLevelsDirect;
    api.setColormap         = @setColormapDirect;
    api.setMap2DColormap    = @setMap2DColormapDirect;
    api.maskRegion          = @maskRegionDirect;
    api.unmaskAll           = @() onUnmaskAll([],[]);
    api.fringeThickness     = @fringeThicknessDirect;
    api.clearFringe         = @clearFringeMarkers;
    api.reset               = @resetGUIDirect;

    % ── Testability API (headless test hooks) ──────────────────────────
    api.getPlotData         = @(idx) getPlotData(idx);
    api.refreshDataTable    = @() refreshDataTable();
    api.getMacroLog         = @() appData.macroLog;
    api.isMacroRecording    = @() appData.macroRecording;
    api.startMacroRecord    = @() onToggleMacroRecord([], []);
    api.stopMacroRecord     = @() onToggleMacroRecord([], []);
    api.toggleAxAppearance  = @() onToggleAxAppearance();
    api.getAxAppearanceState = @() struct( ...
        'collapsed',        appData.sectionCollapsed.axAppearance, ...
        'advRowHeight',     axLimGL.RowHeight{AXLIM_ADV_ROW}, ...
        'analysisRow1Height', analysisGL.RowHeight{1});
    api.showDecomposition   = @() onShowDecomposition([],[]);
    api.getTableData        = @() struct( ...
        'data',     {tblData.Data}, ...
        'colNames', {tblData.ColumnName}, ...
        'working',  appData.tableWorkingCopy, ...
        'units',    {appData.tableUnits});
    api.descriptiveStats    = @() onDescriptiveStats([],[]);

    % ════════════════════════════════════════════════════════════════════
    %  NESTED CALLBACKS  (share appData + all control handles via closure)
    % ════════════════════════════════════════════════════════════════════

    % ── Dataset management ───────────────────────────────────────────────

    function onAddFiles(~,~)
    %ONADDFILES  Open a multi-select file dialog; load every chosen file.
        startDir = guiTernary(isempty(appData.lastDir), pwd, appData.lastDir);
        [fnames, fpath] = uigetfile( ...
            {'*.dat;*.csv;*.tsv;*.txt;*.xlsx;*.xls;*.xlsm;*.xlsb;*.ods;*.raw;*.xrdml;*.refl;*.pnr;*.datA;*.datB;*.datC;*.datD;*.data;*.datb;*.datc;*.datd;*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.bcf;*.dm3;*.dm4', ...
             'Supported data files (*.dat, *.csv, *.xlsx, *.raw, *.xrdml, *.refl, *.pnr, *.datA/B/C/D, *.jpg, *.png, *.bmp, *.gif, *.bcf, *.dm3, *.dm4)'; ...
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
            fprintf(2, '[DataPlotter] DropFcn error: %s\n', ME.message);
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

        % File size warning for very large files (>50 MB)
        for wfi = 1:numel(fpaths)
            try
                fInfo = dir(fpaths{wfi});
                if ~isempty(fInfo) && fInfo(1).bytes > 50e6
                    [~, wfn, wfx] = fileparts(fpaths{wfi});
                    sizeMB = fInfo(1).bytes / 1e6;
                    answer = uiconfirm(fig, ...
                        sprintf('%s%s is %.0f MB.\nLarge files may use significant memory. Continue?', ...
                            wfn, wfx, sizeMB), ...
                        'Large File Warning', ...
                        'Options', {'Continue', 'Skip'}, ...
                        'DefaultOption', 'Continue');
                    if strcmp(answer, 'Skip')
                        fpaths{wfi} = '';  % mark for skip
                    end
                end
            catch
            end
        end
        fpaths = fpaths(~cellfun(@isempty, fpaths));
        if isempty(fpaths), return; end

        % Progress indicator for file loading (#6)
        fig.Pointer = 'watch';
        nTotal = numel(fpaths);

        % ── Excel "Apply to all" state ──
        excelApplyAll    = false;   % true once user opts to reuse selection
        excelSavedSheets = {};      % remembered sheet indices (by name)

        nLoaded = 0;
        for fi = 1:numel(fpaths)
            fp = fpaths{fi};
            [~, fnBase, fExt] = fileparts(fp);
            if nTotal > 1
                setStatus(sprintf('Loading file %d of %d: %s%s...', fi, nTotal, fnBase, fExt));
            else
                setStatus(sprintf('Loading %s%s...', fnBase, fExt));
            end
            drawnow limitrate;

            % ── Excel: offer sheet selection when file has multiple sheets ──
            excelExts = {'.xlsx','.xls','.xlsm','.xlsb','.ods'};
            if any(strcmpi(fExt, excelExts))
                try
                    allSheetNames = sheetnames(fp);
                catch
                    allSheetNames = {'Sheet1'};
                end
                if numel(allSheetNames) > 1
                    if excelApplyAll && ~isempty(excelSavedSheets)
                        % Reuse saved selection — match by index, clamped to
                        % this file's actual sheet count
                        validIdx = excelSavedSheets(excelSavedSheets <= numel(allSheetNames));
                        if isempty(validIdx), validIdx = 1; end
                        selectedSheets = allSheetNames(validIdx);
                    else
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

                        % Count remaining Excel files
                        nExcelRemaining = 0;
                        for ri = (fi+1):numel(fpaths)
                            [~, ~, rExt] = fileparts(fpaths{ri});
                            if any(strcmpi(rExt, excelExts))
                                nExcelRemaining = nExcelRemaining + 1;
                            end
                        end
                        if nExcelRemaining > 0
                            selDesc = strjoin(cellstr(selectedSheets), ', ');
                            answer = uiconfirm(fig, ...
                                sprintf('Apply this sheet selection (%s) to the remaining %d Excel file(s)?', ...
                                    selDesc, nExcelRemaining), ...
                                'Apply to All', ...
                                'Options', {'Apply to All', 'Choose Individually'}, ...
                                'DefaultOption', 1, 'CancelOption', 2);
                            if strcmp(answer, 'Apply to All')
                                excelApplyAll    = true;
                                excelSavedSheets = selIdx;
                            end
                        end
                    end
                else
                    selectedSheets = allSheetNames;
                end
                % Determine correct parser for this Excel file (SIMS vs generic)
                resolveResult = parser.resolveParser(fp);
                excelParserName = resolveResult.name;

                for si = 1:numel(selectedSheets)
                    shName = selectedSheets{si};
                    try
                        if strcmp(excelParserName, 'importSIMS')
                            data       = parser.importSIMS(fp, 'Sheet', shName);
                            parserName = 'importSIMS';
                        else
                            data       = parser.importExcel(fp, 'Sheet', shName);
                            parserName = 'importExcel';
                        end
                        ds = buildDs(fp, data, parserName);
                        ds.displayName = sprintf('%s%s [%s]', fnBase, fExt, shName);
                        appData.datasets{end+1} = ds;
                        nLoaded = nLoaded + 1;
                    catch ME
                        fprintf(2, '\n[DataPlotter] Import error (%s [%s]): %s\n', ...
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
                fprintf(2, '\n[DataPlotter] Import error (%s): %s\n', fnBase, ME.message);
                for si = 1:numel(ME.stack)
                    fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
                end
                logGUIError('Import error', sprintf('%s  %s', [fnBase fExt], ME.message), ME);
                uialert(fig, sprintf('%s\n\n%s', [fnBase fExt], ME.message), 'Import error');
            end
        end

        fig.Pointer = 'arrow';
        cancelInteractions();   % always clean up — even if no files loaded
        drawnow;                % flush pending UI events (e.g. uialert) so
                                % subsequent tool popups get clean focus
        if nLoaded == 0, return; end

        % Make the last successfully loaded file the active dataset
        appData.activeIdx = numel(appData.datasets);

        rebuildDatasetList(true);
        updateControlsForActiveDataset();
        memMB = estimateDatasetMemoryMB();
        setStatus(sprintf('Loaded %d file(s) — %d dataset(s) total (~%.0f MB).', ...
            nLoaded, numel(appData.datasets), memMB));
        % Record loaded files in macro
        for fj = 1:numel(fpaths)
            recordAction(sprintf("data = parser.importAuto('%s');", fpaths{fj}));
        end
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
        guiState = struct( ...
            'colormap', ddColormap.Value, ...
            'xCol', ddX.Value, ...
            'yCol', lbY.Value, ...
            'y2Col', lbY2.Value, ...
            'logX', strcmp(ddScaleX.Value, 'Log'), ...
            'logY', strcmp(ddScaleY.Value, 'Log'), ...
            'logY2', strcmp(ddScaleY2.Value, 'Log'));
        dataplotter.sessionManager.save(outPath, appData, guiState);
    end

    function loadSessionDirect(matPath)
    %LOADSESSIONDIRECT  Load session from .mat file (no dialog).
        if nargin < 1 || isempty(matPath)
            error('matPath required');
        end
        guiState = dataplotter.sessionManager.load(matPath, appData);

        % Restore GUI widget state
        try
            ddColormap.Value = guiState.colormap;
            ddX.Value = guiState.xCol;
            lbY.Value = guiState.yCol;
            lbY2.Value = guiState.y2Col;
            if guiState.logX, ddScaleX.Value = 'Log'; else, ddScaleX.Value = 'Linear'; end
            if guiState.logY, ddScaleY.Value = 'Log'; else, ddScaleY.Value = 'Linear'; end
            if guiState.logY2, ddScaleY2.Value = 'Log'; else, ddScaleY2.Value = 'Linear'; end
        catch
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

    function setMap2DColormapDirect(name)
    %SETMAP2DCOLORMAPDIRECT  Set the 2D map color scale by name and replot.
    %   name: one of the items in ddMap2DCmap (e.g. 'parula', 'viridis', 'plasma')
        ddMap2DCmap.Value = name;
        onPlot([],[]);
        drawnow;
    end

    function maskRegionDirect(xMin, xMax, yMin, yMax)
    %MASKREGIONDIRECT  Programmatic masking for testing.
    %   api.maskRegion(xMin, xMax, yMin, yMax) masks data points in the box.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        applyMaskInBox(xMin, xMax, yMin, yMax);
    end

    function result = fringeThicknessDirect(Q1, Q2)
    %FRINGETHICKNESSDIRECT  Programmatic fringe thickness for testing.
    %   result = api.fringeThickness(Q1, Q2) returns struct with fields:
    %     .dQ, .thickness_A, .thickness_nm
        if isempty(appData.datasets) || appData.activeIdx < 1
            result = struct(); return;
        end
        clearFringeMarkers();
        appData.fringeQ = [Q1, Q2];
        appData.fringeClickCount = 2;
        dQ = abs(Q2 - Q1);
        result.dQ = dQ;
        result.thickness_A  = 2 * pi / dQ;
        result.thickness_nm = result.thickness_A / 10;
        % Place markers and annotation
        recreateFringeMarkers();
    end

    function resetGUIDirect()
    %RESETGUIDIRECT  Clear all datasets and reset GUI to initial state.
    %  Used by automated tests to reuse a single GUI instance.
        appData.datasets  = {};
        appData.activeIdx = 0;
        appData.style     = 'Line';
        appData.peakPickMode      = false;
        appData.fringeClickCount  = 0;
        appData.fringeQ           = [];
        appData.fringeMarkers     = {};
        appData.fringeAnnotation  = [];
        appData.fringeDragIdx     = 0;
        appData.maskStartPt       = [];
        appData.maskRectPatch     = [];

        % Reset correction widgets
        efXOffset.Value      = 0;
        efYOffset.Value      = 0;
        efBGSlope.Value      = 0;
        efBGIntercept.Value  = 0;
        ddBGOrder.Value      = 'Linear';
        cbSmooth.Value       = false;
        efXTrimMin.Value     = '';
        efXTrimMax.Value     = '';
        ddNormalize.Value    = 'None';
        ddMap2DCmap.Value    = 'parula';

        % Reset axis dropdowns and listboxes
        ddX.Items = {'(load file first)'};
        lbY.Items = {'(load file first)'};
        lbY2.Items = {'(none)'};
        lbY2.Value = {'(none)'};
        lbDatasets.Items     = {};
        lbDatasets.ItemsData = {};

        % Reset axis limit fields
        efXMin.Value = '';  efXMax.Value = '';
        efYMin.Value = '';  efYMax.Value = '';

        % Clear plot
        if ~isempty(ax) && isvalid(ax)
            delete(ax.Children);
            cla(ax);
            title(ax, '');
        end

        cancelInteractions();
        clearFringeMarkers();

        % Hide peak window and clear its table
        if isvalid(peakFig), peakFig.Visible = 'off'; end
        peakTable.Data = {};
    end

    function onSelectDataset(~,~)
    %ONSELECTDATASET  Fires when the user clicks a row in lbDatasets.
    %  With Multiselect='on', lbDatasets.Value is a cell array of selected
    %  ItemsData values.  The active dataset is the first (most-recently
    %  clicked) element.  Only selected datasets are plotted.
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

        activeChanged = (val ~= appData.activeIdx);
        if activeChanged
            saveAxisLimsToActiveDataset();   % persist zoom before leaving current dataset
            % Don't cancel while a listbox drag has been initiated: cancelInteractions()
            % would clear the WindowButtonMotionFcn/UpFcn that onAxesButtonDown just set.
            if appData.listDragSrcIdx == 0
                cancelInteractions();
            end
            appData.activeIdx = val;
            updateControlsForActiveDataset();
        end

        % Update listbox tooltip with dataset metadata (#19)
        ds = appData.datasets{val};
        nPts = numel(ds.data.time);
        pName = guiTernary(isfield(ds,'parserName'), ds.parserName, 'unknown');
        hasCorrStr = guiTernary(~isempty(ds.corrData), 'corrected', 'raw');
        lbDatasets.Tooltip = sprintf('%s\nParser: %s  |  %d points  |  %s', ...
            ds.filepath, pName, nPts, hasCorrStr);

        % Always replot — selection may have changed even if active didn't
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

            % Evaluate expression safely — no eval(); uses dispatch-based parser
            yResult = safeEvalMathExpr(expr, vars);
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
        if isprop(appData, 'animTimer') && ~isempty(appData.animTimer) && isvalid(appData.animTimer)
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
        btnAnimate.BackgroundColor = BTN_DANGER;

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

    function onShowShortcuts(~,~)
    %ONSHOWSHORTCUTS  Display a uialert listing all keyboard shortcuts.
        msg = sprintf(['Keyboard Shortcuts\n\n' ...
            'Ctrl+S        Save session\n' ...
            'Ctrl+Z        Undo corrections\n' ...
            'Ctrl+C        Copy plot to clipboard\n' ...
            'Ctrl+E        Export CSV\n' ...
            'Delete        Remove selected dataset\n' ...
            'Left / Right  Switch dataset\n' ...
            'Space         Toggle dataset visibility\n' ...
            'Ctrl+Up       Move dataset up\n' ...
            'Ctrl+Down     Move dataset down']);
        uialert(fig, msg, 'Keyboard Shortcuts', 'Icon', 'info');
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
        % Abort any in-progress mask selection
        if ~isempty(appData.maskRectPatch) && isvalid(appData.maskRectPatch)
            delete(appData.maskRectPatch);
        end
        appData.maskRectPatch     = [];
        appData.maskStartPt       = [];
        btnMaskSelect.Text            = 'Mask Selection';
        btnMaskSelect.BackgroundColor = [0.60 0.15 0.15];
        btnMaskSelect.Enable          = 'on';
        % Reset fringe thickness pick mode (but keep existing markers)
        if appData.fringeClickCount > 0 && appData.fringeClickCount < 2
            clearFringeMarkers();
        end
        appData.fringeDragIdx     = 0;
        btnFringeThick.Text            = ['Fringe ' char(916) 't (2-click)'];
        btnFringeThick.BackgroundColor = BTN_ACCENT;
        btnFringeThick.Enable          = 'on';
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
        btnYTranslate.BackgroundColor = BTN_ACCENT;
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
            btnRemovePeakClick.Text            = 'Click-Rm';
            btnRemovePeakClick.BackgroundColor = BTN_DANGER;
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
        ddDerivative.Value   = guiTernary(isfield(ds,'derivativeMode'), ds.derivativeMode, 'None');

        % Restore magnetometry sample parameters
        efSampleMass.Value   = guiTernary(isfield(ds,'sampleMass'),   ds.sampleMass,   0);
        efSampleWidth.Value  = guiTernary(isfield(ds,'sampleWidth'),  ds.sampleWidth,  0);
        efSampleHeight.Value = guiTernary(isfield(ds,'sampleHeight'), ds.sampleHeight, 0);
        ddDimUnit.Value      = guiTernary(isfield(ds,'dimUnit'),      ds.dimUnit,      'mm');
        efSampleThick.Value  = guiTernary(isfield(ds,'sampleThick'),  ds.sampleThick,  0);
        ddThickUnit.Value    = guiTernary(isfield(ds,'thickUnit'),    ds.thickUnit,    'nm');
        ddMomentUnit.Value   = guiTernary(isfield(ds,'momentUnit'),   ds.momentUnit,   'emu (raw)');
        ddFieldUnit.Value    = guiTernary(isfield(ds,'fieldUnit'),    ds.fieldUnit,    'Oe (raw)');
        ddUnitSystem.Value   = guiTernary(isfield(ds,'unitSystem'),   ds.unitSystem,   'CGS');

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
        axLimGL.RowHeight{3}  = 22 * y2Active;
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
            ddScaleY.Value = 'Log';
        elseif isfield(ds, 'parserName') && strcmp(ds.parserName, 'importSIMS')
            ddScaleY.Value = 'Log';  % SIMS concentrations span many decades
            % Auto-select all elements so each gets its own legend entry
            if numel(d.labels) > 1
                lbY.Value = d.labels;
            end
        elseif is2DDataset(ds)
            ddScaleY.Value = 'Log';  % log intensity is standard for XRD reciprocal-space maps
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
            ddScaleY.Value = 'Linear';
        end

        ddX.ValueChangedFcn  = @onAxisChanged;
        lbY.ValueChangedFcn  = @onAxisChanged;
        lbY2.ValueChangedFcn = @(~,~) onPlot([],[]);

        appData.selectedPeakIdx = 0;   % clear peak selection on dataset switch
        refreshPeakTable();

        % Refresh data table if visible
        appData.tableMask = [];  % reset mask on dataset switch
        refreshDataTable();
    end

    % ── Axis / style callbacks ────────────────────────────────────────────

    function onAxisChanged(~,~)
        if appData.activeIdx > 0 && ~isempty(appData.datasets)
            onPlot([],[]);
        end
    end

    function applyParserAnalysisConfig(pName)
    %APPLYPARSERANALYSISCONFIG  Relabel Analysis panel controls for data type.
    %  Uses CROW row-index constants defined at corrGL creation.

        % ── Common row-height setup for non-neutron modes ──
        % Show BG file rows only if section not collapsed; hide asymmetry
        showBGFileRows = ~appData.sectionCollapsed.bgFile;
        bgFileH = 22 * showBGFileRows;

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
                % Show XRD interactive tools, hide generic ones
                btnFitBG.Visible           = 'off';
                btnPickY.Visible           = 'off';
                btnYTranslate.Visible      = 'on';
                btnAutoPeak.Visible        = 'on';
                btnManualPeak.Visible      = 'on';
                btnRemovePeakClick.Visible = 'on';
                btnPeakWindow.Visible      = 'on';
                % Peak window mode — XRD
                appData.peakMode = 'xrd';
                configurePeakWindowForMode('xrd');
                analysisGL.ColumnWidth     = {appData.corrPanelWidth, '1x', 210, 0};
                % Hide asymmetry; respect BG file collapse state
                corrGL.RowHeight{CROW.BGFILE}  = bgFileH;
                corrGL.RowHeight{CROW.BGSUBTR} = bgFileH;
                corrGL.RowHeight{CROW.ASYM1}   = 0;
                corrGL.RowHeight{CROW.ASYM2}   = 0;
                % Hide magnetometry section (not applicable to XRD)
                showMagSection(false);

            case {'importQDVSM', 'importMPMS', 'importLakeShore', 'importPPMS'}
                % Re-enable controls for magnetometry data
                for hh = {efXOffset, efYOffset, efBGSlope, efBGIntercept, ...
                          btnApply, btnReset, btnApplyAll, btnUndo, ...
                          cbSmooth, efSmoothWin, ddSmoothMethod, ...
                          efXTrimMin, efXTrimMax, ddNormalize}
                    hh{1}.Enable = 'on'; %#ok<FXSET>
                end
                switch pName
                    case 'importPPMS',     magTitle = 'PPMS';
                    case 'importMPMS',     magTitle = 'MPMS';
                    case 'importLakeShore',magTitle = 'Lake Shore';
                    otherwise,             magTitle = 'VSM';
                end
                analysisPanel.Title   = ['Analysis & Corrections  —  ' magTitle];
                % Magnetometry-specific labels and tooltips
                lblXOff.Text          = 'Field Offset:';
                efXOffset.Tooltip     = 'Field offset: H_corrected = H − this value  (0 = no shift)';
                lblYOff.Text          = 'Moment Offset:';
                efYOffset.Tooltip     = ['Moment baseline shift applied after diamagnetic BG ' ...
                                         'subtraction  (0 = no shift)'];
                lblBGSlope.Text       = 'Diamag. Slope:';
                efBGSlope.Tooltip     = ['Diamagnetic susceptibility slope ' char(967) ': ' ...
                                         'M_BG = ' char(967) char(183) 'H + b  (0 = no subtraction).  ' ...
                                         'Use "Fit BG from Box" or "Auto BG" to estimate automatically.'];
                lblBGInt.Text         = 'Diamag. Intcpt:';
                efBGIntercept.Tooltip = ['Diamagnetic intercept b: M_BG = ' char(967) char(183) 'H + b  ' ...
                                         '(0 = no subtraction)'];
                % Magnetometry interactive tools: Fit BG + Est. Y Offset
                btnFitBG.Visible           = 'on';
                btnPickY.Visible           = 'on';
                btnYTranslate.Visible      = 'off';
                btnAutoPeak.Visible        = 'off';
                btnManualPeak.Visible      = 'off';
                btnRemovePeakClick.Visible = 'off';
                btnPeakWindow.Visible      = 'off';
                appData.peakMode = 'none';
                analysisGL.ColumnWidth     = {appData.corrPanelWidth, '1x', 210, 0};
                % Hide asymmetry; respect BG file collapse state; show mag section
                corrGL.RowHeight{CROW.BGFILE}  = bgFileH;
                corrGL.RowHeight{CROW.BGSUBTR} = bgFileH;
                corrGL.RowHeight{CROW.ASYM1}   = 0;
                corrGL.RowHeight{CROW.ASYM2}   = 0;
                showMagSection(true);

            case {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'}
                analysisPanel.Title = 'Analysis & Corrections  —  Neutron Reflectometry';
                lblXOff.Text  = 'Q Offset:';
                efXOffset.Tooltip = 'Q-offset: Q_corrected = Q − this value  (0 = no shift)';
                lblYOff.Text  = 'R Scale:';
                efYOffset.Tooltip = 'R scale factor: R_corrected = R × this value  (1.0 = no change)';
                for hh = {efXOffset, efYOffset, btnApply, btnReset, btnApplyAll, btnUndo, ...
                          efXTrimMin, efXTrimMax, ddNormalize}
                    hh{1}.Enable = 'on'; %#ok<FXSET>
                end
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
                btnPeakWindow.Visible      = 'off';
                btnApply.Tooltip = 'Apply Q offset / R scale, trim, and normalization to all polarizations from the same measurement';
                % Peak window mode — reflectometry
                appData.peakMode = 'reflectometry';
                configurePeakWindowForMode('reflectometry');
                analysisGL.ColumnWidth     = {appData.corrPanelWidth, '1x', 210, 0};
                % Hide BG file rows; show asymmetry rows
                corrGL.RowHeight{CROW.BGFILE}  = 0;
                corrGL.RowHeight{CROW.BGSUBTR} = 0;
                corrGL.RowHeight{CROW.ASYM1}   = 22;
                corrGL.RowHeight{CROW.ASYM2}   = 22;
                lblAsymmetry.Enable        = 'on';
                cbCalculateAsymmetry.Enable = 'on';
                lblAsymFormula.Enable      = 'on';
                ddAsymFormula.Enable       = 'on';
                % Hide magnetometry section (not applicable to neutron)
                showMagSection(false);

            case 'importSIMS'
                analysisPanel.Title   = 'Analysis & Corrections  —  SIMS Depth Profile';
                lblXOff.Text          = 'Depth Offset (nm):';
                efXOffset.Tooltip     = 'Depth offset: depth_corrected = depth − this value  (0 = no shift)';
                lblYOff.Text          = 'Conc. Floor:';
                efYOffset.Tooltip     = 'Concentration floor subtracted from all values  (0 = no shift)';
                lblBGSlope.Text       = 'BG Slope:';
                lblBGInt.Text         = 'BG Intercept:';
                for hh = {efXOffset, efYOffset, btnApply, btnReset, btnApplyAll, btnUndo, ...
                          cbSmooth, efSmoothWin, ddSmoothMethod, ...
                          efXTrimMin, efXTrimMax, ddNormalize}
                    hh{1}.Enable = 'on'; %#ok<FXSET>
                end
                for hh = {efBGSlope, efBGIntercept}
                    hh{1}.Enable = 'off'; %#ok<FXSET>
                end
                btnFitBG.Visible           = 'off';
                btnPickY.Visible           = 'off';
                btnYTranslate.Visible      = 'off';
                btnAutoPeak.Visible        = 'off';
                btnManualPeak.Visible      = 'off';
                btnRemovePeakClick.Visible = 'off';
                btnPeakWindow.Visible      = 'off';
                appData.peakMode = 'none';
                analysisGL.ColumnWidth     = {appData.corrPanelWidth, '1x', 210, 0};
                % Hide asymmetry; respect BG file collapse state
                corrGL.RowHeight{CROW.BGFILE}  = bgFileH;
                corrGL.RowHeight{CROW.BGSUBTR} = bgFileH;
                corrGL.RowHeight{CROW.ASYM1}   = 0;
                corrGL.RowHeight{CROW.ASYM2}   = 0;
                % Hide magnetometry section (not applicable to SIMS)
                showMagSection(false);

            otherwise  % importCSV, importExcel, unknown — generic labels
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
                btnPeakWindow.Visible      = 'off';
                appData.peakMode = 'none';
                analysisGL.ColumnWidth     = {appData.corrPanelWidth, '1x', 210, 0};
                % Hide asymmetry; respect BG file collapse state
                corrGL.RowHeight{CROW.BGFILE}  = bgFileH;
                corrGL.RowHeight{CROW.BGSUBTR} = bgFileH;
                corrGL.RowHeight{CROW.ASYM1}   = 0;
                corrGL.RowHeight{CROW.ASYM2}   = 0;
                % Hide magnetometry section for generic data
                showMagSection(false);
        end

        % ── Hide peak window when switching to a non-peak mode ───────────
        if strcmp(appData.peakMode, 'none') && isvalid(peakFig)
            peakFig.Visible = 'off';
        end

        % ── 2D area-detector override (applied after the switch) ─────────
        % When the active dataset contains a 2D map, hide the peak/map and
        % corrections (not meaningful for raw intensity maps) and show the
        % map2D controls instead.
        is2D_active = appData.activeIdx >= 1 && ~isempty(appData.datasets) && ...
                      is2DDataset(appData.datasets{appData.activeIdx});
        if is2D_active
            map2DPanel.Visible = 'on';
            analysisGL.ColumnWidth = {appData.corrPanelWidth, '1x', 0, '2x'};
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
            btnPeakWindow.Visible      = 'off';
            if isvalid(peakFig), peakFig.Visible = 'off'; end
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
            case 'SIMS Depth Profile'
                pName = 'importSIMS';
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
        % Reimport with SIMS parser when user switches to 'SIMS Depth Profile'
        % and the active dataset was originally parsed by importCSV
        if strcmp(ddCorrStyle.Value, 'SIMS Depth Profile') && ...
                appData.activeIdx >= 1 && ~isempty(appData.datasets)
            ds = appData.datasets{appData.activeIdx};
            if isfield(ds, 'parserName') && ...
                    (strcmp(ds.parserName, 'importCSV') || strcmp(ds.parserName, 'importExcel'))
                try
                    newData = parser.importSIMS(ds.filepath);
                    ds.data       = newData;
                    ds.corrData   = [];
                    ds.parserName = 'importSIMS';
                    appData.datasets{appData.activeIdx} = ds;
                    rebuildDatasetList();
                    updateControlsForActiveDataset();
                    onPlot([],[]);
                    return;  % updateControls already calls applyParserAnalysisConfig
                catch ME
                    warning('DataPlotter:simsReimport', ...
                        'SIMS reimport failed: %s', ME.message);
                end
            end
        end
        applyParserAnalysisConfig(resolvedCorrStyle());
    end

    % ── Collapsible section toggle ────────────────────────────────────────

    function onToggleCorrSection(sectionName, sectionTitle, childRows, defaultHeights)
    %ONTOGGLECORRSECTION  Toggle a collapsible section in the corrections panel.
    %   sectionName    — field name in appData.sectionCollapsed (e.g. 'offsets')
    %   sectionTitle   — display text (e.g. 'Offsets & BG')
    %   childRows      — vector of row indices to toggle
    %   defaultHeights — vector of default row heights when expanded
        headerLabel = appData.sectionHeaders.(sectionName);
        collapsed = ~appData.sectionCollapsed.(sectionName);
        appData.sectionCollapsed.(sectionName) = collapsed;
        if collapsed
            headerLabel.Text = [char(9654) ' ' sectionTitle];  % ▶
            for k = 1:numel(childRows)
                corrGL.RowHeight{childRows(k)} = 0;
            end
        else
            headerLabel.Text = [char(9660) ' ' sectionTitle];  % ▼
            for k = 1:numel(childRows)
                corrGL.RowHeight{childRows(k)} = defaultHeights(k);
            end
        end
    end

    function onToggleAxAppearance()
    %ONTOGGLEAXAPPEARANCE  Toggle the appearance extras row in axLimGL
    %  and resize the parent analysisGL row so the expanded content is
    %  not clipped by the Data Table panel below.
        collapsed = ~appData.sectionCollapsed.axAppearance;
        appData.sectionCollapsed.axAppearance = collapsed;
        AXLIM_BASE_H = 110;   % matches analysisGL RowHeight{1}
        if collapsed
            btnAxMore.Text = [char(9654) ' More'];  % ▶
            axLimGL.RowHeight{AXLIM_ADV_ROW} = 0;
            analysisGL.RowHeight{1} = AXLIM_BASE_H;
        else
            btnAxMore.Text = [char(9660) ' More'];  % ▼
            axLimGL.RowHeight{AXLIM_ADV_ROW} = AXLIM_ADV_HEIGHT;
            analysisGL.RowHeight{1} = AXLIM_BASE_H + AXLIM_ADV_HEIGHT;
        end
    end

    function toggleSaveSection(sectionName, sectionTitle)
    %TOGGLESAVESECTION  Toggle a collapsible section in the Save/Export panel.
        hdrMap = struct('dataExport', btnSaveHdrData, 'figExport', btnSaveHdrFig, ...
                        'session', btnSaveHdrSession, 'tools', btnSaveHdrTools);
        contentRow = appData.saveSectionRows.(sectionName);
        headerBtn  = hdrMap.(sectionName);
        rh = saveGL.RowHeight;
        if rh{contentRow} > 0
            % Collapse
            rh{contentRow} = 0;
            headerBtn.Text = [char(9654) ' ' sectionTitle];
        else
            % Expand
            rh{contentRow} = appData.saveSectionHeights.(sectionName);
            headerBtn.Text = [char(9660) ' ' sectionTitle];
        end
        saveGL.RowHeight = rh;
    end

    function showMagSection(visible)
    %SHOWMAGSECTION  Show or hide the magnetometry "Sample & Units" section.
    %   visible = true:  show header row (16px), data rows follow collapsed state
    %   visible = false: hide entire section (all rows = 0)
        if visible
            corrGL.RowHeight{CROW.SEC_MAG} = 20;
            showMag = ~appData.sectionCollapsed.magSample;
            for km = 1:numel(MAG_ROWS)
                corrGL.RowHeight{MAG_ROWS(km)} = MAG_HEIGHTS(km) * showMag;
            end
        else
            corrGL.RowHeight{CROW.SEC_MAG} = 0;
            for km = 1:numel(MAG_ROWS)
                corrGL.RowHeight{MAG_ROWS(km)} = 0;
            end
        end
    end

    function t = offsetsSectionTitle()
    %OFFSETSSECTIONTITLE  Section title for the offsets/BG collapsible group.
        t = 'Offsets & BG';
    end

    function vol = magSampleVolume_cm3()
    %MAGSAMPLEVOLUME_CM3  Compute sample volume in cm³ from width, height, thickness.
    %   Returns 0 if any dimension is missing (zero).
        w = efSampleWidth.Value;   % in units of ddDimUnit
        h = efSampleHeight.Value;  % in units of ddDimUnit
        t = efSampleThick.Value;   % in units of ddThickUnit
        if w <= 0 || h <= 0 || t <= 0
            vol = 0;
            return;
        end
        % Convert width and height to cm
        switch ddDimUnit.Value
            case 'mm'
                w_cm = w * 0.1;    % 1 mm = 0.1 cm
                h_cm = h * 0.1;
            otherwise  % cm
                w_cm = w;
                h_cm = h;
        end
        % Convert thickness to cm
        switch ddThickUnit.Value
            case 'nm'
                t_cm = t * 1e-7;       % 1 nm = 1e-7 cm
            otherwise  % Å
                t_cm = t * 1e-8;       % 1 Å = 1e-8 cm
        end
        vol = w_cm * h_cm * t_cm;
    end

    function onUnitSystemChanged(~, ~)
    %ONUNITSYSTEMCHANGED  Quick-set field and moment units from CGS/SI toggle.
        switch ddUnitSystem.Value
            case 'CGS'
                ddFieldUnit.Value  = 'Oe (raw)';
                ddMomentUnit.Value = 'emu (raw)';
            case 'SI'
                ddFieldUnit.Value  = 'T';
                ddMomentUnit.Value = 'A·m²';
        end
        markCorrectionsDirty();
    end

    function onAutoMagCorrections(~,~)
    %ONATOMAGCORRECTIONS  Estimate linear BG and Y offset from high-field data.
    %   Uses data points at |x| >= 95% of the maximum |x| (field) range to
    %   find the saturation region.  Fits a line through those points to get
    %   BG slope + intercept, and computes Y offset as the mean of the
    %   positive-field and negative-field saturation averages.
    %
    %   Works on the first selected Y channel.  Operates on the raw data
    %   (pre-correction) so the resulting polynomial is compatible with
    %   onApplyCorrections.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end

        doAll = strcmp(ddAutoMagScope.Value, 'All Datasets');
        if doAll
            indices = 1:numel(appData.datasets);
        else
            indices = appData.activeIdx;
        end

        magParsers = {'importQDVSM','importPPMS','importMPMS','importLakeShore'};

        % First pass: compute corrections per dataset
        corrections = struct('di', {}, 'slope', {}, 'intercept', {}, 'yOff', {});
        for di = indices
            ds = appData.datasets{di};
            if ~isfield(ds, 'parserName') || ...
               ~ismember(ds.parserName, magParsers)
                continue;
            end

            d = ds.data;
            if isdatetime(d.time), continue; end

            xVec = double(d.time);
            % Use first selected Y channel, or fall back to first column
            ySel = ensureCell(lbY.Value);
            yIdx = 1;
            if ~isempty(ySel)
                found = find(strcmp(d.labels, ySel{1}), 1);
                if ~isempty(found), yIdx = found; end
            end
            yVec = d.values(:, yIdx);

            % Remove NaNs
            valid = ~isnan(xVec) & ~isnan(yVec);
            xV = xVec(valid);
            yV = yVec(valid);
            if numel(xV) < 4, continue; end

            % Identify high-field region: |x| >= 95% of max |x|
            maxAbsX = max(abs(xV));
            if maxAbsX < eps, continue; end
            threshold = 0.95 * maxAbsX;
            hiPos = xV >=  threshold;
            hiNeg = xV <= -threshold;
            hiField = hiPos | hiNeg;

            if sum(hiField) < 2, continue; end

            % Fit linear BG through high-field points
            p = polyfit(xV(hiField), yV(hiField), 1);

            % Y offset: average of positive and negative saturation means
            % after removing the linear BG
            yDetrended = yV - polyval(p, xV);
            if any(hiPos) && any(hiNeg)
                meanPos = mean(yDetrended(hiPos));
                meanNeg = mean(yDetrended(hiNeg));
                yOff = (meanPos + meanNeg) / 2;
            else
                yOff = mean(yDetrended(hiField));
            end

            corrections(end+1) = struct('di', di, ...
                'slope', p(1), 'intercept', p(2), 'yOff', yOff); %#ok<AGROW>
        end

        if isempty(corrections)
            uialert(fig, 'No magnetometry datasets found to correct.', 'Auto BG');
            return;
        end

        % Second pass: apply corrections per dataset
        origIdx = appData.activeIdx;
        for ci = 1:numel(corrections)
            c = corrections(ci);
            % Switch to this dataset so onApplyCorrections reads the widgets
            appData.activeIdx = c.di;
            updateControlsForActiveDataset();

            efBGSlope.Value     = c.slope;
            efBGIntercept.Value = c.intercept;
            efYOffset.Value     = c.yOff;
            % Clear any stored higher-order polynomial
            ds = appData.datasets{c.di};
            ds.bgPoly = [];
            appData.datasets{c.di} = ds;

            onApplyCorrections([], []);
        end

        % Restore original active dataset
        appData.activeIdx = origIdx;
        updateControlsForActiveDataset();
        onPlot([], []);

        if numel(corrections) > 1
            setStatus(sprintf('Auto BG+Offset applied to %d dataset(s).', numel(corrections)));
        else
            setStatus('Auto BG+Offset applied.');
        end
    end

    function showPeakWindow()
    %SHOWPEAKWINDOW  Open (or bring to front) the Peak Analysis window.
        if ~isvalid(peakFig)
            return;  % figure was deleted — should not happen in normal use
        end
        refreshPeakTable();
        peakFig.Visible = 'on';
        figure(peakFig);  % bring to front
    end

    function configurePeakWindowForMode(mode)
    %CONFIGUREPEAKWINDOWFORMODE  Show/hide mode-specific buttons in the peak window.
    %  mode: 'xrd', 'reflectometry', or 'none'
        switch mode
            case 'xrd'
                peakFig.Name = 'Peak Analysis';
                % Restore all XRD peak buttons
                for hh = {ddFitModel, btnFitPeaks, btnFitAllPeaks, btnClearPeaks, ...
                          btnRemovePeak, btnSavePeaks, btnExportPeakXLSX, chkShowFit, ...
                          btnFitColor, btnWHPlot, btnFFTThickness, btnRefineLattice, btnReflFFT, ...
                          btnCopyPeaksClip, btnMorePeak, btnMatchPhases}
                    hh{1}.Visible = 'on'; %#ok<FXSET>
                end
                btnFringeThick.Visible = 'off';
                peakBtnGL.RowHeight{7} = 0;
            case 'reflectometry'
                peakFig.Name = 'Reflectivity Analysis';
                for hh = {ddFitModel, btnFitPeaks, btnFitAllPeaks, btnClearPeaks, ...
                          btnRemovePeak, btnSavePeaks, btnExportPeakXLSX, chkShowFit, ...
                          btnFitColor, btnWHPlot, btnFFTThickness, btnRefineLattice, ...
                          btnCopyPeaksClip, btnMorePeak, btnMatchPhases}
                    hh{1}.Visible = 'off'; %#ok<FXSET>
                end
                btnReflFFT.Visible = 'on';
                btnFringeThick.Visible = 'on';
                peakBtnGL.RowHeight{7} = 22;
            otherwise
                % 'none' — hide the window entirely
                if isvalid(peakFig), peakFig.Visible = 'off'; end
        end
    end

    function onToggleAdvancedPeakTools()
    %ONTOGGLEADVANCEDPEAKTOOLS  Toggle W-H Plot, FFT Thickness, Refine Lattice.
        collapsed = ~appData.sectionCollapsed.advancedPeak;
        appData.sectionCollapsed.advancedPeak = collapsed;
        if collapsed
            btnMorePeak.Text = [char(9654) ' Advanced...'];  % ▶
            for k = 1:numel(PEAK_ADV_ROWS)
                peakBtnGL.RowHeight{PEAK_ADV_ROWS(k)} = 0;
            end
        else
            btnMorePeak.Text = [char(9660) ' Advanced'];  % ▼
            for k = 1:numel(PEAK_ADV_ROWS)
                peakBtnGL.RowHeight{PEAK_ADV_ROWS(k)} = PEAK_ADV_HEIGHTS(k);
            end
        end
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
        btnYTranslate.BackgroundColor = BTN_ACCENT;
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
        dmask = buildDisplayMask(ds);
        valid = ~isnan(xv) & ~isnan(yv) & dmask;
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
                                  'xRange',{},'status',{},'bg',{},'model',{},'eta',{}, ...
                                  'prominence',{},'localSNR',{});
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

            newPk.center     = lX;
            newPk.fwhm       = lW;
            newPk.height     = lH;
            newPk.area       = NaN;
            newPk.xRange     = [];
            newPk.status     = 'manual';
            newPk.bg         = NaN;
            newPk.model      = '';
            newPk.eta        = NaN;
            newPk.prominence = NaN;
            newPk.localSNR   = NaN;
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
        showPeakWindow();
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
        dmask = buildDisplayMask(ds);

        % Search within 3 % of x-axis range of click for the NEAREST local
        % maximum (not the global max — which misses the smaller of two close peaks).
        xWin  = diff(ax.XLim) * 0.03;
        inWin = xv >= (xClick - xWin) & xv <= (xClick + xWin) & ~isnan(yv) & dmask;
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

        newPk.center     = pkX;
        newPk.fwhm       = NaN;
        newPk.height     = pkH;
        newPk.area       = NaN;
        newPk.xRange     = [];
        newPk.status     = 'manual';
        newPk.bg         = NaN;
        newPk.model      = '';
        newPk.eta        = NaN;
        newPk.prominence = NaN;
        newPk.localSNR   = NaN;
        ds.peaks(end+1) = newPk;
        appData.datasets{appData.activeIdx} = ds;

        refreshPeakTable();
        onPlot([],[]);
        % Auto-open peak window on first peak
        if numel(ds.peaks) == 1, showPeakWindow(); end
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

        dmask = buildDisplayMask(ds);
        valid = ~isnan(xv) & ~isnan(yv) & dmask;
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
        setStatus('Fitting all peaks simultaneously...');
        fig.Pointer = 'watch';
        drawnow;
        ds = appData.datasets{appData.activeIdx};
        if numel(ds.peaks) < 2
            fig.Pointer = 'arrow';
            setStatus('Ready');
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

        dmask = buildDisplayMask(ds);
        valid = ~isnan(xv) & ~isnan(yv) & dmask;
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
        fig.Pointer = 'arrow';
        setStatus('Global peak fit complete.');
        onPlot([],[]);

        % Auto-show decomposition after global fit
        onShowDecomposition();
    end

    function onShowDecomposition(~, ~)
    %ONSHOWDECOMPOSITION  Overlay individual peak components on the main axes.
    %   Draws each fitted peak as a separate dashed curve plus the
    %   composite model and a linear background. Requires peaks with
    %   status 'fitted' or 'fitted(global)'.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds = appData.datasets{appData.activeIdx};
        if isempty(ds.peaks), return; end

        % Remove any previous decomposition overlays
        delete(findall(ax, 'Tag', 'GUIPeakDecomp'));

        % Gather fitted peaks
        nP = numel(ds.peaks);
        fittedIdx = [];
        for k = 1:nP
            if contains(ds.peaks(k).status, 'fitted')
                fittedIdx(end+1) = k; %#ok<AGROW>
            end
        end
        if isempty(fittedIdx)
            setStatus('No fitted peaks to decompose.');
            return;
        end

        % Get the plotted data range
        d = getPlotData(appData.activeIdx);
        xAll = d.time;
        xDense = linspace(min(xAll), max(xAll), 1000)';

        % Determine model
        modelName = 'Lorentzian';
        if isfield(ds.peaks(fittedIdx(1)), 'model') && ~isempty(ds.peaks(fittedIdx(1)).model)
            modelName = ds.peaks(fittedIdx(1)).model;
        end

        % Compute linear background from first and last peak bg values
        bgSlope = 0; bgInt = 0;
        if numel(fittedIdx) >= 2
            p1 = ds.peaks(fittedIdx(1));
            pN = ds.peaks(fittedIdx(end));
            if isfield(p1, 'bg') && isfield(pN, 'bg') && ~isnan(p1.bg) && ~isnan(pN.bg)
                bgSlope = (pN.bg - p1.bg) / max(eps, pN.center - p1.center);
                bgInt = p1.bg - bgSlope * p1.center;
            end
        elseif isfield(ds.peaks(fittedIdx(1)), 'bg')
            bgInt = ds.peaks(fittedIdx(1)).bg;
        end

        bgLine = bgSlope * xDense + bgInt;
        composite = bgLine;

        % Color palette for individual peaks
        nFitted = numel(fittedIdx);
        peakColors = lines(max(nFitted, 1));

        hold(ax, 'on');

        for fi = 1:nFitted
            pk = ds.peaks(fittedIdx(fi));
            H = pk.height;
            x0 = pk.center;
            fw = pk.fwhm;

            switch modelName
                case 'Gaussian'
                    yPk = H * exp(-4*log(2) * ((xDense - x0)./fw).^2);
                case 'Pseudo-Voigt'
                    eta = 0.5;
                    if isfield(pk, 'eta') && ~isnan(pk.eta), eta = pk.eta; end
                    L = H ./ (1 + 4*((xDense - x0)./fw).^2);
                    G = H * exp(-4*log(2) * ((xDense - x0)./fw).^2);
                    yPk = eta * L + (1 - eta) * G;
                otherwise  % Lorentzian
                    yPk = H ./ (1 + 4*((xDense - x0)./fw).^2);
            end

            composite = composite + yPk;

            % Draw individual peak (dashed, colored)
            plot(ax, xDense, yPk + bgSlope * xDense + bgInt, '--', ...
                'Color', [peakColors(fi,:) 0.6], ...
                'LineWidth', 1.0, ...
                'HandleVisibility', 'off', ...
                'Tag', 'GUIPeakDecomp');
        end

        % Draw composite (solid red)
        plot(ax, xDense, composite, '-', ...
            'Color', [0.85 0.15 0.15], ...
            'LineWidth', 1.5, ...
            'HandleVisibility', 'off', ...
            'Tag', 'GUIPeakDecomp');

        % Draw background (thin dotted gray)
        plot(ax, xDense, bgLine, ':', ...
            'Color', [0.5 0.5 0.5], ...
            'LineWidth', 0.8, ...
            'HandleVisibility', 'off', ...
            'Tag', 'GUIPeakDecomp');

        hold(ax, 'off');
        setStatus(sprintf('Decomposition: %d peaks + background overlaid', nFitted));
    end

    % ── Peak list management ─────────────────────────────────────────────

    function onClearPeaks(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        cancelInteractions();
        ds       = appData.datasets{appData.activeIdx};
        if ~isempty(ds.peaks)
            nFitted = sum(strcmp({ds.peaks.status},'fitted') | strcmp({ds.peaks.status},'fitted(global)'));
            if nFitted > 0
                sel = uiconfirm(fig, ...
                    sprintf('Remove all %d peaks (%d fitted)?', numel(ds.peaks), nFitted), ...
                    'Clear Peaks', 'Options', {'Clear', 'Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2);
                if ~strcmp(sel, 'Clear'), return; end
            end
        end
        ds.peaks = struct('center',{},'fwhm',{},'height',{},'area',{},'xRange',{},'status',{},'bg',{},'model',{},'eta',{},'prominence',{},'localSNR',{});
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
            'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG);
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
    %  3.1a  PHASE IDENTIFICATION (PEAK DATABASE MATCHING)
    % ════════════════════════════════════════════════════════════════════

    function onMatchPhases(~, ~)
    %ONMATCHPHASES  Match detected peaks against built-in crystallographic database.
    %   Uses d-spacing comparison with adjustable tolerance.  Overlays
    %   vertical tick marks for matched reference positions.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        ds  = appData.datasets{appData.activeIdx};
        pks = ds.peaks;
        if isempty(pks) || ~isstruct(pks)
            uialert(fig, 'Detect peaks first (Auto Peak button).', 'No peaks'); return;
        end

        wl_A = extractWavelength_A(ds);
        if isnan(wl_A) || wl_A <= 0
            uialert(fig, ['Wavelength is required for phase matching.  ' ...
                          'Enter a value in the ' char(955) ' field or select an X-ray source.'], ...
                          'Wavelength needed'); return;
        end

        % Collect peak centers (2theta)
        centers = [pks.center];
        centers = centers(~isnan(centers));
        if isempty(centers)
            uialert(fig, 'No valid peak centers found.', 'No peaks'); return;
        end

        try
            % Ask for tolerance via a simple dialog
            answer = inputdlg( ...
                {['d-spacing tolerance (' char(197) '):'], ...
                 'Min. match fraction (0-1):'}, ...
                'Phase Match Settings', [1 40], {'0.03', '0.3'});
            if isempty(answer), return; end
            tol      = str2double(answer{1});
            minFrac  = str2double(answer{2});
            if isnan(tol) || isnan(minFrac)
                uialert(fig, 'Invalid numeric input.', 'Error'); return;
            end

            matches = calc.crystal.matchPhases(centers(:), ...
                Lambda=wl_A, Tolerance=tol, MinMatchFrac=minFrac);

            if isempty(matches)
                uialert(fig, ...
                    sprintf('No phases matched with tolerance %.3f %s and min fraction %.0f%%.', ...
                            tol, char(197), minFrac*100), ...
                    'No matches');
                return;
            end

            % Build results display
            nShow = min(numel(matches), 10);
            lines = cell(nShow, 1);
            for mi = 1:nShow
                m = matches(mi);
                hklStr = strjoin(m.matchedHKL, ', ');
                lines{mi} = sprintf('%d. %s  [%s]  —  %.0f%%  (%d/%d peaks)  hkl: %s', ...
                    mi, m.phaseName, m.formula, m.score*100, m.nMatched, m.nObserved, hklStr);
            end

            % Let user select which phases to overlay
            [sel, ok] = listdlg('ListString', lines, ...
                'SelectionMode', 'multiple', ...
                'ListSize', [550 300], ...
                'PromptString', 'Select phase(s) to overlay on plot:', ...
                'Name', 'Phase Match Results');
            if ~ok || isempty(sel), return; end

            % Remove existing phase tick marks
            delete(findall(ax, 'Tag', 'GUIPhaseTickMark'));
            delete(findall(ax, 'Tag', 'GUIPhaseLabel'));

            % Overlay vertical tick marks for selected phases
            phaseColors = [ ...
                0.85 0.20 0.20;  % red
                0.20 0.50 0.80;  % blue
                0.20 0.70 0.30;  % green
                0.80 0.50 0.10;  % orange
                0.60 0.20 0.70;  % purple
                0.10 0.70 0.70;  % teal
                0.90 0.40 0.60;  % pink
                0.50 0.50 0.20;  % olive
                0.35 0.35 0.80;  % indigo
                0.80 0.30 0.30]; % dark red

            yLims = ax.YLim;
            tickBase = yLims(1);
            tickTop  = tickBase + 0.08 * (yLims(2) - yLims(1));
            labelY   = tickBase - 0.03 * (yLims(2) - yLims(1));

            hold(ax, 'on');
            for si = 1:numel(sel)
                m = matches(sel(si));
                ci = mod(si-1, size(phaseColors, 1)) + 1;
                col = phaseColors(ci, :);

                % Draw tick marks at all reference 2theta positions in range
                refTT = m.allRefTwoTheta;
                xRange = ax.XLim;
                inView = refTT(refTT >= xRange(1) & refTT <= xRange(2) & ~isnan(refTT));

                for ti = 1:numel(inView)
                    line(ax, [inView(ti), inView(ti)], [tickBase, tickTop], ...
                        'Color', col, 'LineWidth', 1.5, ...
                        'HandleVisibility', 'off', 'Tag', 'GUIPhaseTickMark');
                end

                % Phase label at the left edge
                if ~isempty(inView)
                    text(ax, xRange(1) + 0.01*(xRange(2)-xRange(1)), ...
                         labelY - (si-1)*0.035*(yLims(2)-yLims(1)), ...
                         sprintf('%s', m.phaseName), ...
                         'Color', col, 'FontSize', 8, 'FontWeight', 'bold', ...
                         'HandleVisibility', 'off', 'Tag', 'GUIPhaseLabel');
                end
            end

            % Status bar update
            topMatch = matches(sel(1));
            lblStatus.Text = sprintf('Phase match: %s (%.0f%%) — %d phase(s) overlaid', ...
                topMatch.phaseName, topMatch.score*100, numel(sel));

        catch ME
            logGUIError('Phase Match Error', ME.message, ME);
            uialert(fig, sprintf('Phase matching failed:\n\n%s', ME.message), 'Error');
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

        % Get current data (corrected if available), exclude masked points
        d = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        dmask = buildDisplayMask(ds);
        xAll = d.time(dmask);
        % Use first y-channel (primary intensity)
        yAll = d.values(dmask,1);

        % Pre-fill range from current axis limits
        xLo = ax.XLim(1);
        xHi = ax.XLim(2);

        % ── Create dialog figure ────────────────────────────────────────
        fftFig = uifigure('Name', 'FFT Film Thickness — Laue Fringes', ...
            'Position', [250 150 680 580], 'Resize', 'on');
        fftGL = uigridlayout(fftFig, [4 1], ...
            'RowHeight', {78, 30, '1x', 72}, ...
            'Padding', [10 10 10 10], 'RowSpacing', 8);

        % ── Row 1: Parameter controls (titled panel) ───────────────────
        paramPanel = uipanel(fftGL, 'Title', 'Parameters', 'FontSize', 11);
        paramPanel.Layout.Row = 1;
        paramGL = uigridlayout(paramPanel, [2 6], ...
            'ColumnWidth', {80, '1x', 80, '1x', 80, '1x'}, ...
            'RowHeight', {24, 24}, ...
            'Padding', [6 4 6 4], 'ColumnSpacing', 6, 'RowSpacing', 4);

        % Row 1 of params: 2theta range + max thickness
        lbl1 = uilabel(paramGL, 'Text', ['2' char(952) ' min (' char(176) '):'], ...
            'FontWeight', 'bold');
        lbl1.Layout.Row = 1; lbl1.Layout.Column = 1;
        efFFTMin = uieditfield(paramGL, 'numeric', 'Value', xLo, 'Limits', [-10 180], ...
            'Tooltip', ['Lower bound of the 2' char(952) ' range for FFT analysis'], ...
            'ValueChangedFcn', @(~,~) doFFT([],[]));
        efFFTMin.Layout.Row = 1; efFFTMin.Layout.Column = 2;
        lbl2 = uilabel(paramGL, 'Text', ['2' char(952) ' max (' char(176) '):'], ...
            'FontWeight', 'bold');
        lbl2.Layout.Row = 1; lbl2.Layout.Column = 3;
        efFFTMax = uieditfield(paramGL, 'numeric', 'Value', xHi, 'Limits', [-10 180], ...
            'Tooltip', ['Upper bound of the 2' char(952) ' range for FFT analysis'], ...
            'ValueChangedFcn', @(~,~) doFFT([],[]));
        efFFTMax.Layout.Row = 1; efFFTMax.Layout.Column = 4;
        lbl3 = uilabel(paramGL, 'Text', 'Max t (nm):', 'FontWeight', 'bold');
        lbl3.Layout.Row = 1; lbl3.Layout.Column = 5;
        efMaxThick = uieditfield(paramGL, 'numeric', 'Value', 200, 'Limits', [1 10000], ...
            'Tooltip', 'Maximum thickness to display on the x-axis (nm)', ...
            'ValueChangedFcn', @(~,~) doFFT([],[]));
        efMaxThick.Layout.Row = 1; efMaxThick.Layout.Column = 6;

        % Row 2 of params: window + compute button
        lbl4 = uilabel(paramGL, 'Text', 'Window:', 'FontWeight', 'bold');
        lbl4.Layout.Row = 2; lbl4.Layout.Column = 1;
        ddWindow = uidropdown(paramGL, ...
            'Items', {'Hann', 'None', 'Blackman'}, 'Value', 'Hann', ...
            'Tooltip', ['Windowing function applied before FFT.' newline ...
                        'Hann reduces spectral leakage (recommended).'], ...
            'ValueChangedFcn', @(~,~) doFFT([],[]));
        ddWindow.Layout.Row = 2; ddWindow.Layout.Column = 2;
        btnCompute = uibutton(paramGL, 'Text', 'Compute FFT', ...
            'ButtonPushedFcn', @doFFT, ...
            'BackgroundColor', BTN_ACCENT, 'FontColor', BTN_FG, ...
            'FontWeight', 'bold');
        btnCompute.Layout.Row = 2; btnCompute.Layout.Column = [5 6];

        % ── Row 2: Wavelength info label ────────────────────────────────
        lblWavelength = uilabel(fftGL, 'Text', ...
            sprintf('%s = %.5f %s', char(955), wl_A, char(197)), ...
            'FontSize', 11, 'FontColor', [0.4 0.4 0.4]);
        lblWavelength.Layout.Row = 2;

        % ── Row 3: Axes for FFT plot ────────────────────────────────────
        fftAxPanel = uipanel(fftGL, 'BorderType', 'none');
        fftAxPanel.Layout.Row = 3;
        fftAx = axes(fftAxPanel);

        % ── Row 4: Results panel ────────────────────────────────────────
        resultPanel = uipanel(fftGL, 'Title', 'Result', ...
            'FontSize', 11, 'FontWeight', 'bold');
        resultPanel.Layout.Row = 4;
        resultGL = uigridlayout(resultPanel, [2 4], ...
            'ColumnWidth', {90, '1x', 100, '1x'}, ...
            'RowHeight', {20, 20}, ...
            'Padding', [8 4 8 4], 'ColumnSpacing', 6, 'RowSpacing', 2);
        uilabel(resultGL, 'Text', 'Thickness:', 'FontWeight', 'bold', ...
            'FontSize', 12);
        lblResThick = uilabel(resultGL, 'Text', '---', 'FontSize', 12);
        lblResThick.Layout.Row = 1; lblResThick.Layout.Column = 2;
        uilabel(resultGL, 'Text', 'Uncertainty:', 'FontWeight', 'bold', ...
            'FontSize', 12);
        lblResUncert = uilabel(resultGL, 'Text', '---', 'FontSize', 12);
        lblResUncert.Layout.Row = 1; lblResUncert.Layout.Column = 4;
        uilabel(resultGL, 'Text', 'Range:', 'FontWeight', 'bold', ...
            'FontSize', 11, 'FontColor', [0.4 0.4 0.4]);
        lblResRange = uilabel(resultGL, 'Text', '---', 'FontSize', 11, ...
            'FontColor', [0.4 0.4 0.4]);
        lblResRange.Layout.Row = 2; lblResRange.Layout.Column = 2;
        uilabel(resultGL, 'Text', 'Data points:', 'FontWeight', 'bold', ...
            'FontSize', 11, 'FontColor', [0.4 0.4 0.4]);
        lblResNpts = uilabel(resultGL, 'Text', '---', 'FontSize', 11, ...
            'FontColor', [0.4 0.4 0.4]);
        lblResNpts.Layout.Row = 2; lblResNpts.Layout.Column = 4;

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
            title(fftAx, 'FFT Magnitude Spectrum');
            grid(fftAx, 'on');
            box(fftAx, 'on');
            xlim(fftAx, [0 maxT_nm]);

            % ── Update results panel ──────────────────────────────────
            lblResThick.Text = sprintf('%.1f nm', t_nm);
            if ~isnan(dt_nm)
                lblResUncert.Text = sprintf('%s %.1f nm (FWHM/2)', char(177), dt_nm/2);
            else
                lblResUncert.Text = 'N/A (peak too broad)';
            end
            lblResRange.Text = sprintf(['%.2f' char(176) ' – %.2f' char(176) ...
                ' 2' char(952)], twoThMin, twoThMax);
            lblResNpts.Text = sprintf('%d', sum(mask));

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

        % Auto-compute on open
        doFFT([], []);
    end

    % ════════════════════════════════════════════════════════════════════
    %  3.1c  FRINGE THICKNESS (2-CLICK ΔQ ESTIMATION)
    % ════════════════════════════════════════════════════════════════════

    function onArmFringeThickness(~,~)
    %ONARMFRINGETHICKNESS  Arm 2-click fringe thickness pick mode.
    %   Click two fringe peaks; thickness = 2*pi / |Q1 - Q2|.
    %   Markers are draggable for refinement.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        cancelInteractions();
        clearFringeMarkers();

        appData.fringeClickCount = 0;
        appData.fringeQ          = [NaN NaN];
        btnFringeThick.Text            = 'Click peak 1 of 2...';
        btnFringeThick.BackgroundColor = [0.20 0.55 0.75];
        btnFringeThick.Enable          = 'off';
        fig.Pointer = 'crosshair';
        fig.WindowButtonDownFcn = @onFringeClick;
    end

    function onFringeClick(~,~)
    %ONFRINGECLICK  Handle a click during fringe thickness pick mode.
        cp = ax.CurrentPoint;
        xClick = cp(1,1);  yClick = cp(1,2);
        if xClick < ax.XLim(1) || xClick > ax.XLim(2) || ...
           yClick < ax.YLim(1) || yClick > ax.YLim(2)
            return;
        end

        % Get displayed data for the active dataset
        ds = appData.datasets{appData.activeIdx};
        primaryD = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        xVec = double(primaryD.time);

        % Snap to nearest data point (normalized distance)
        ySel2  = ensureCell(lbY.Value);
        bestD  = Inf;
        bestX  = xClick;
        bestY  = yClick;
        xRange = diff(ax.XLim);
        yRange = diff(ax.YLim);
        % In log scale, use log-space distances for Y
        isLogY = strcmp(ax.YScale, 'log');
        for k = 1:numel(ySel2)
            yIdx = find(strcmp(primaryD.labels, ySel2{k}), 1);
            if isempty(yIdx), continue; end
            yVec = primaryD.values(:, yIdx);
            valid = ~isnan(xVec) & ~isnan(yVec);
            if isLogY
                dy = (log10(max(yVec(valid), eps)) - log10(max(yClick, eps))) / log10(max(ax.YLim(2)/ax.YLim(1), 10));
            else
                dy = (yVec(valid) - yClick) / yRange;
            end
            dx = (xVec(valid) - xClick) / xRange;
            dists = sqrt(dx.^2 + dy.^2);
            [mD, mI] = min(dists);
            if mD < bestD
                bestD = mD;
                validIdx = find(valid);
                bestX = xVec(validIdx(mI));
                bestY = yVec(validIdx(mI));
            end
        end

        appData.fringeClickCount = appData.fringeClickCount + 1;
        n = appData.fringeClickCount;
        appData.fringeQ(n) = bestX;

        % Place a draggable marker
        markerColors = {[0.10 0.65 0.85], [0.85 0.35 0.10]};  % blue, orange
        hold(ax, 'on');
        hm = plot(ax, bestX, bestY, 'v', ...
            'MarkerSize',       12, ...
            'MarkerFaceColor',  markerColors{n}, ...
            'MarkerEdgeColor',  'w', ...
            'LineWidth',        1.2, ...
            'HitTest',          'on', ...
            'HandleVisibility', 'off', ...
            'Tag',              'GUIFringeMarker');
        % Enable dragging: mouse-down on marker starts a drag
        hm.ButtonDownFcn = @(src, evt) onFringeMarkerDown(n);
        hold(ax, 'off');

        if n == 1
            appData.fringeMarkers = hm;
            btnFringeThick.Text = 'Click peak 2 of 2...';
        else
            appData.fringeMarkers(2) = hm;
            % Restore normal interaction and compute thickness
            fig.WindowButtonDownFcn   = @onAxesButtonDown;
            fig.WindowButtonMotionFcn = @onMouseHover;
            fig.Pointer               = 'arrow';
            btnFringeThick.Text            = ['Fringe ' char(916) 't (2-click)'];
            btnFringeThick.BackgroundColor = BTN_ACCENT;
            btnFringeThick.Enable          = 'on';

            updateFringeThickness();
        end
    end

    function onFringeMarkerDown(markerIdx)
    %ONFRINGEMARKERDOWN  Begin dragging a fringe marker along the data curve.
        appData.fringeDragIdx = markerIdx;
        fig.WindowButtonMotionFcn = @onFringeMarkerMove;
        fig.WindowButtonUpFcn     = @onFringeMarkerUp;
        fig.Pointer               = 'hand';
    end

    function onFringeMarkerMove(~,~)
    %ONFRINGEMARKERMOVE  Update marker position as user drags.
        idx = appData.fringeDragIdx;
        if idx < 1 || idx > 2, return; end

        cp = ax.CurrentPoint;
        xDrag = cp(1,1);

        % Snap to nearest data point in x
        ds = appData.datasets{appData.activeIdx};
        primaryD = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        xVec = double(primaryD.time);
        ySel2 = ensureCell(lbY.Value);

        bestX = xDrag;
        bestY = cp(1,2);
        bestDx = Inf;
        for k = 1:numel(ySel2)
            yIdx = find(strcmp(primaryD.labels, ySel2{k}), 1);
            if isempty(yIdx), continue; end
            yVec = primaryD.values(:, yIdx);
            valid = ~isnan(xVec) & ~isnan(yVec);
            [mDx, mI] = min(abs(xVec(valid) - xDrag));
            if mDx < bestDx
                bestDx = mDx;
                validIdx = find(valid);
                bestX = xVec(validIdx(mI));
                bestY = yVec(validIdx(mI));
            end
        end

        appData.fringeQ(idx) = bestX;
        hm = appData.fringeMarkers(idx);
        if isvalid(hm)
            hm.XData = bestX;
            hm.YData = bestY;
        end

        updateFringeThickness();
        drawnow limitrate;
    end

    function onFringeMarkerUp(~,~)
    %ONFRINGEMARKERUP  Finish dragging a fringe marker.
        fig.WindowButtonMotionFcn = @onMouseHover;
        fig.WindowButtonUpFcn     = '';
        fig.Pointer               = 'arrow';
        appData.fringeDragIdx     = 0;
    end

    function updateFringeThickness()
    %UPDATEFRINGETHICKNESS  Compute and display t = 2*pi / |ΔQ|.
        Q1 = appData.fringeQ(1);
        Q2 = appData.fringeQ(2);
        if isnan(Q1) || isnan(Q2), return; end

        dQ = abs(Q2 - Q1);
        if dQ < eps
            tStr = 't = Inf (points overlap)';
        else
            % t = 2*pi / dQ in Å, convert to nm
            t_A  = 2 * pi / dQ;
            t_nm = t_A / 10;
            tStr = sprintf('t %s %.1f nm  (%.1f %s)    %sQ = %.5f %s%s%s', ...
                char(8776), t_nm, t_A, char(197), ...  % ≈, Å
                char(916), dQ, char(197), char(8315), char(185));  % Δ, Å⁻¹
        end

        % Show thickness annotation on plot (top-left, below title)
        if ~isempty(appData.fringeAnnotation) && isvalid(appData.fringeAnnotation)
            appData.fringeAnnotation.String = tStr;
        else
            hold(ax, 'on');
            appData.fringeAnnotation = text(ax, 0.02, 0.96, tStr, ...
                'Units',              'normalized', ...
                'FontSize',           12, ...
                'FontWeight',         'bold', ...
                'Color',              [0.95 0.85 0.20], ...
                'BackgroundColor',    [0.10 0.10 0.10 0.75], ...
                'Margin',             4, ...
                'VerticalAlignment',  'top', ...
                'HitTest',            'off', ...
                'HandleVisibility',   'off', ...
                'Tag',                'GUIFringeAnnotation');
            hold(ax, 'off');
        end

        % Also update status bar
        setStatus(tStr);

        % Draw a horizontal double-arrow between the two markers
        drawFringeSpan();
    end

    function drawFringeSpan()
    %DRAWFRINGESPAN  Draw a line connecting the two fringe markers.
        delete(findall(ax, 'Tag', 'GUIFringeSpan'));
        if any(isnan(appData.fringeQ)), return; end
        Q1 = appData.fringeQ(1);
        Q2 = appData.fringeQ(2);
        if numel(appData.fringeMarkers) < 2, return; end
        y1 = appData.fringeMarkers(1).YData;
        y2 = appData.fringeMarkers(2).YData;
        yMid = (y1 + y2) / 2;
        hold(ax, 'on');
        plot(ax, [Q1, Q2], [yMid, yMid], '--', ...
            'Color', [0.95 0.85 0.20 0.6], ...
            'LineWidth', 1.5, ...
            'HitTest', 'off', ...
            'HandleVisibility', 'off', ...
            'Tag', 'GUIFringeSpan');
        hold(ax, 'off');
    end

    function recreateFringeMarkers()
    %RECREATEFRINGEMARKERS  Re-place fringe markers after a full redraw.
    %   The markers and annotation are destroyed by drawToAxes' cla().
    %   This function rebuilds them at the stored Q positions.
        ds = appData.datasets{appData.activeIdx};
        primaryD = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        xVec = double(primaryD.time);
        ySel2 = ensureCell(lbY.Value);
        markerColors = {[0.10 0.65 0.85], [0.85 0.35 0.10]};
        appData.fringeMarkers = gobjects(1, 2);
        for mi = 1:2
            Qval = appData.fringeQ(mi);
            % Find nearest data point to get Y value
            bestY = 0;
            bestDx = Inf;
            for k = 1:numel(ySel2)
                yIdx = find(strcmp(primaryD.labels, ySel2{k}), 1);
                if isempty(yIdx), continue; end
                yVec = primaryD.values(:, yIdx);
                valid = ~isnan(xVec) & ~isnan(yVec);
                [mDx, mI] = min(abs(xVec(valid) - Qval));
                if mDx < bestDx
                    bestDx = mDx;
                    validIdx = find(valid);
                    bestY = yVec(validIdx(mI));
                end
            end
            hold(ax, 'on');
            hm = plot(ax, Qval, bestY, 'v', ...
                'MarkerSize',       12, ...
                'MarkerFaceColor',  markerColors{mi}, ...
                'MarkerEdgeColor',  'w', ...
                'LineWidth',        1.2, ...
                'HitTest',          'on', ...
                'HandleVisibility', 'off', ...
                'Tag',              'GUIFringeMarker');
            hm.ButtonDownFcn = @(~,~) onFringeMarkerDown(mi);
            hold(ax, 'off');
            appData.fringeMarkers(mi) = hm;
        end
        % Recreate the annotation and span line
        appData.fringeAnnotation = [];  % force fresh creation
        updateFringeThickness();
    end

    function clearFringeMarkers()
    %CLEARFRINGEMARKERS  Remove fringe thickness markers and annotation.
        delete(findall(ax, 'Tag', 'GUIFringeMarker'));
        delete(findall(ax, 'Tag', 'GUIFringeAnnotation'));
        delete(findall(ax, 'Tag', 'GUIFringeSpan'));
        appData.fringeMarkers    = [];
        appData.fringeAnnotation = [];
        appData.fringeQ          = [NaN NaN];
        appData.fringeClickCount = 0;
        appData.fringeDragIdx    = 0;
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

        % Get current corrected data, exclude masked points
        d    = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        dmask = buildDisplayMask(ds);
        xAll = d.time(dmask);       % Q (Å⁻¹) for neutron; 2θ (°) for XRR
        yAll = d.values(dmask,1);   % R (reflectivity) or counts

        % Pre-fill range from current axis limits
        xLo = ax.XLim(1);
        xHi = ax.XLim(2);

        % ── Dialog figure ────────────────────────────────────────────────
        rfFig = uifigure('Name', 'Reflectivity FFT — Kiessig Thickness', ...
            'Position', [200 150 780 720], 'Resize', 'on');
        rfGL = uigridlayout(rfFig, [5 1], ...
            'RowHeight', {80, 28, '2x', 80, '1x'}, ...
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
            'BackgroundColor', BTN_ACCENT, 'FontColor', BTN_FG);
        btnRFCompute.Layout.Row = 2;

        % ── Row 3: FFT plot ──────────────────────────────────────────────
        rfAxPanel = uipanel(rfGL, 'BorderType', 'none');
        rfAxPanel.Layout.Row = 3;
        rfAx = axes(rfAxPanel);

        % ── Row 4: Superlattice summary panel ────────────────────────────
        slPanel = uipanel(rfGL, 'Title', 'Superlattice Analysis', 'FontSize', 11);
        slPanel.Layout.Row = 4;
        slGL = uigridlayout(slPanel, [3 2], ...
            'ColumnWidth', {'1x', '1x'}, ...
            'RowHeight', {20, 18, 18}, ...
            'Padding', [6 2 6 2], 'ColumnSpacing', 12, 'RowSpacing', 2);
        lblSLStatus    = uilabel(slGL, 'Text', 'No superlattice pattern detected', ...
            'FontWeight', 'bold', 'FontColor', [0.4 0.4 0.4]);
        lblSLStatus.Layout.Row = 1; lblSLStatus.Layout.Column = [1 2];
        lblSLBilayer   = uilabel(slGL, 'Text', '', 'FontSize', 10);
        lblSLBilayer.Layout.Row = 2; lblSLBilayer.Layout.Column = 1;
        lblSLTotal     = uilabel(slGL, 'Text', '', 'FontSize', 10);
        lblSLTotal.Layout.Row = 2; lblSLTotal.Layout.Column = 2;
        lblSLSublayers = uilabel(slGL, 'Text', '', 'FontSize', 10);
        lblSLSublayers.Layout.Row = 3; lblSLSublayers.Layout.Column = [1 2];

        % ── Row 5: Peak results table ────────────────────────────────────
        rfTblPanel = uipanel(rfGL, 'Title', 'Detected Thickness Peaks', 'FontSize', 11);
        rfTblPanel.Layout.Row = 5;
        rfTblGL = uigridlayout(rfTblPanel, [1 1], 'Padding', [4 4 4 4]);
        rfPeakTable = uitable(rfTblGL, ...
            'ColumnName',  {'#', 'Thickness (nm)', 'Amplitude', 'Rel (%)', 'Interpretation'}, ...
            'ColumnWidth', {30, 110, 80, 60, 120}, ...
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

            % ── Superlattice detection ────────────────────────────────
            nPk = numel(pkThick);
            interpLabels = cell(nPk, 1);
            for hi = 1:nPk
                interpLabels{hi} = '';
            end

            slDetected     = false;
            slLambda_nm    = NaN;
            slTotal_nm     = NaN;
            slNRepeats     = NaN;
            slSubA_nm      = NaN;
            slSubB_nm      = NaN;
            slSuppressedOrders = [];

            if nPk >= 2
                % Sort peaks by thickness ascending for analysis
                [tAsc, ~] = sort(pkThick, 'ascend');

                % Try each of the 5 smallest peaks as candidate bilayer period
                nCandidates = min(5, nPk);
                bestScore   = 0;
                bestLambda  = NaN;
                harmTol     = 0.08;   % 8% ratio tolerance

                for ci = 1:nCandidates
                    Lambda_cand = tAsc(ci);
                    score = 0;
                    for pk = 1:nPk
                        ratio = pkThick(pk) / Lambda_cand;
                        nr    = round(ratio);
                        if nr >= 1 && abs(ratio - nr) / nr < harmTol
                            score = score + 1;
                        end
                    end
                    if score > bestScore
                        bestScore  = score;
                        bestLambda = Lambda_cand;
                    end
                end

                if bestScore >= 3
                    slDetected  = true;
                    slLambda_nm = bestLambda;

                    % Assign labels: find which peaks are SL harmonics or satellites
                    % First find highest matched harmonic order
                    nMax = 1;
                    for pk = 1:nPk
                        ratio = pkThick(pk) / slLambda_nm;
                        nr    = round(ratio);
                        if nr >= 1 && abs(ratio - nr) / nr < harmTol
                            if nr > nMax, nMax = nr; end
                        end
                    end

                    % Count subsidiary peaks between Λ and 2Λ
                    % Subsidiary peaks: in range [1.15×Λ, 1.85×Λ], not the 2Λ harmonic
                    nSub = 0;
                    for pk = 1:nPk
                        t = pkThick(pk);
                        if t > 1.15 * slLambda_nm && t < 1.85 * slLambda_nm
                            ratio = t / slLambda_nm;
                            nr    = round(ratio);
                            if ~(nr == 2 && abs(ratio - 2) / 2 < harmTol)
                                nSub = nSub + 1;
                            end
                        end
                    end

                    if nSub > 0
                        slNRepeats = nSub + 2;
                    else
                        slNRepeats = nMax;
                    end
                    slTotal_nm = slNRepeats * slLambda_nm;

                    % Find suppressed orders (2 through min(6, nMax))
                    for ord = 2:min(6, max(nMax, 3))
                        expectedT = ord * slLambda_nm;
                        found = false;
                        for pk = 1:nPk
                            if abs(pkThick(pk) - expectedT) / expectedT < harmTol
                                found = true;
                                break;
                            end
                        end
                        if ~found
                            slSuppressedOrders(end+1) = ord; %#ok<AGROW>
                        end
                    end

                    % Sublayer estimation from first missing order
                    if ~isempty(slSuppressedOrders)
                        firstMissing = slSuppressedOrders(1);
                        slSubA_nm    = slLambda_nm / firstMissing;
                        slSubB_nm    = slLambda_nm - slSubA_nm;
                    end

                    % Assign interpretation labels
                    bilayerPeakAssigned = false;
                    for pk = 1:nPk
                        t     = pkThick(pk);
                        ratio = t / slLambda_nm;
                        nr    = round(ratio);
                        isSLHarm = (nr >= 1) && (abs(ratio - nr) / nr < harmTol);

                        if isSLHarm && nr == 1 && ~bilayerPeakAssigned
                            interpLabels{pk}    = ['Bilayer ' char(923)];
                            bilayerPeakAssigned = true;
                        elseif isSLHarm && nr >= 2
                            interpLabels{pk} = sprintf('SL order %d', nr);
                        elseif t > 1.15 * slLambda_nm && t < 1.85 * slLambda_nm
                            ratio2 = t / slLambda_nm;
                            nr2    = round(ratio2);
                            if ~(nr2 == 2 && abs(ratio2 - 2) / 2 < harmTol)
                                interpLabels{pk} = 'Satellite';
                            end
                        else
                            interpLabels{pk} = 'Independent';
                        end
                    end
                end
            end

            % ── Update superlattice summary labels ────────────────────
            if slDetected
                lblSLStatus.Text      = sprintf(['Superlattice detected  ' char(8212) ...
                    '  [A/B]%s%d'], char(215), slNRepeats);
                lblSLStatus.FontColor = [0.10 0.45 0.10];
                lblSLBilayer.Text     = sprintf(['Bilayer period ' char(923) ' = %.2f nm'], ...
                    slLambda_nm);
                lblSLTotal.Text       = sprintf('Total thickness D = %.1f nm  (%d repeats)', ...
                    slTotal_nm, slNRepeats);
                if ~isnan(slSubA_nm)
                    lblSLSublayers.Text = sprintf( ...
                        ['Estimated sublayers: d_A ' char(8776) ' %.2f nm,  ' ...
                         'd_B ' char(8776) ' %.2f nm  ' ...
                         '(suppressed order %d)'], ...
                        slSubA_nm, slSubB_nm, slSuppressedOrders(1));
                else
                    lblSLSublayers.Text = 'd_A, d_B indeterminate (no suppressed orders)';
                end
            else
                lblSLStatus.Text      = 'No superlattice pattern detected';
                lblSLStatus.FontColor = [0.4 0.4 0.4];
                lblSLBilayer.Text     = '';
                lblSLTotal.Text       = '';
                lblSLSublayers.Text   = '';
            end

            % ── Plot FFT spectrum with peak markers ───────────────────
            cla(rfAx);
            plot(rfAx, t_search, F_search, '-', ...
                'Color', [0.20 0.45 0.55], 'LineWidth', 1.2);
            hold(rfAx, 'on');

            % Colour-code peaks by interpretation
            %   Bilayer Λ      → blue  [0.12 0.47 0.71]
            %   SL harmonic    → red   [0.85 0.15 0.15]
            %   Satellite      → cyan  [0.00 0.68 0.75]
            %   Independent    → orange [0.90 0.50 0.00]
            %   Unlabelled     → red (default, pre-superlattice-detection)
            COL_BILAYER  = [0.12 0.47 0.71];
            COL_SLHARM   = [0.85 0.15 0.15];
            COL_SAT      = [0.00 0.68 0.75];
            COL_INDEP    = [0.90 0.50 0.00];
            COL_DEFAULT  = [0.85 0.15 0.15];

            peakColors = repmat(COL_DEFAULT, nPk, 1);
            for ci = 1:nPk
                lbl = interpLabels{ci};
                if startsWith(lbl, 'Bilayer')
                    peakColors(ci,:) = COL_BILAYER;
                elseif startsWith(lbl, 'SL order')
                    peakColors(ci,:) = COL_SLHARM;
                elseif strcmp(lbl, 'Satellite')
                    peakColors(ci,:) = COL_SAT;
                elseif strcmp(lbl, 'Independent')
                    peakColors(ci,:) = COL_INDEP;
                end
            end

            for mi = 1:nPk
                plot(rfAx, pkThick(mi), pkAmps(mi), 'v', ...
                    'MarkerSize', 10, 'MarkerFaceColor', peakColors(mi,:), ...
                    'MarkerEdgeColor', peakColors(mi,:));
                % Label bilayer period with Λ annotation; others with thickness value
                if startsWith(interpLabels{mi}, 'Bilayer')
                    lblTxt = sprintf('%s\n%.1f nm', char(923), pkThick(mi));
                    text(rfAx, pkThick(mi), pkAmps(mi) * 1.06, lblTxt, ...
                        'HorizontalAlignment', 'center', 'FontSize', 8, ...
                        'FontWeight', 'bold', 'Color', peakColors(mi,:));
                else
                    text(rfAx, pkThick(mi), pkAmps(mi) * 1.06, ...
                        sprintf('%.1f', pkThick(mi)), ...
                        'HorizontalAlignment', 'center', 'FontSize', 8, ...
                        'Color', peakColors(mi,:));
                end
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
                tblData{ti,5} = interpLabels{ti};
            end
            rfPeakTable.Data = tblData;

            % ── Persist all peaks to dataset ──────────────────────────
            ds2 = appData.datasets{appData.activeIdx};
            rfResult.thicknesses_nm = pkThick(:);
            rfResult.amplitudes     = pkAmps(:);
            rfResult.harmonicLabels = interpLabels;
            rfResult.Q_range        = [min(Q) max(Q)];
            rfResult.preprocess     = prepMode;
            rfResult.fft_magnitude  = F_search(:);
            rfResult.thickness_axis = t_search(:);
            rfResult.isNeutron      = isNeutronDS;
            if ~isNeutronDS && ~isempty(efRFWavelength)
                rfResult.wavelength_A = efRFWavelength.Value;
            end
            % Superlattice analysis results
            rfResult.superlattice.detected           = slDetected;
            rfResult.superlattice.bilayerPeriod_nm   = slLambda_nm;
            rfResult.superlattice.totalThickness_nm  = slTotal_nm;
            rfResult.superlattice.nRepeats           = slNRepeats;
            rfResult.superlattice.sublayerA_nm       = slSubA_nm;
            rfResult.superlattice.sublayerB_nm       = slSubB_nm;
            rfResult.superlattice.suppressedOrders   = slSuppressedOrders;
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
        if appData.activeIdx > 0 && ~isempty(appData.datasets)
            onPlot([],[]);
        end
    end

    function onOpenSettings()
    %ONOPENSETTINGS  Open a global settings dialog for theme + plot style.
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

        sGL = uigridlayout(settingsFig,[5 2], ...
            'RowHeight', {24, 28, 14, 28, '1x'}, ...
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
            'ValueChangedFcn', @(src,~) applyThemeFromDialog(src.Value, settingsFig));
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
            'ValueChangedFcn', @(src,~) onStylePick(src.Value));
        ddStyleDlg.Layout.Row = 2; ddStyleDlg.Layout.Column = 2;

        % ── Separator label ──
        lblInfo = uilabel(sGL,'Text','Changes apply immediately.', ...
            'FontSize',10,'FontColor',[0.5 0.5 0.5],'FontAngle','italic');
        lblInfo.Layout.Row = 3; lblInfo.Layout.Column = [1 2];

        % ── Close button ──
        btnClose = uibutton(sGL,'Text','Close', ...
            'FontSize',12, ...
            'ButtonPushedFcn',@(~,~) delete(settingsFig));
        btnClose.Layout.Row = 4; btnClose.Layout.Column = [1 2];
    end

    function applyThemeFromDialog(themeName, settingsFig)
    %APPLYTHEMEFROMDIALOG  Apply theme change from the settings dialog.
        appData.theme = themeName;
        onThemeChanged([], []);
        % Update dialog colours to match new theme
        if strcmp(themeName, 'Dark')
            th = styles.dark();
            settingsFig.Color = th.bgColor;
        else
            settingsFig.Color = [0.94 0.94 0.94];
        end
    end

    function onThemeChanged(~,~)
    %ONTHEMECHANGED  Apply light or dark theme to the entire GUI.
        isDark = strcmp(appData.theme, 'Dark');
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

        setStatus('Applying corrections to all datasets...');
        fig.Pointer = 'watch';
        drawnow;

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
            undoState.mask           = guiTernary(isfield(ds,'mask'), ds.mask, true(size(ds.data.time)));
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

            % Apply corrections via extracted pipeline
            uiVals = struct('xOff', xOff, 'yOff', yOff, ...
                'bgSlope', bgSlope, 'bgInt', bgIntcpt, ...
                'xTrimMin', xTrimMin, 'xTrimMax', xTrimMax, ...
                'smoothEnabled', smoothEnabled, ...
                'smoothWindow', smoothWin, ...
                'smoothMethod', smoothMeth, ...
                'normMethod', normVal, ...
                'derivativeMode', 'None', ...
                'fieldUnit', 'Oe (raw)', 'momentUnit', 'emu (raw)');
            corrParams = dataplotter.correctionParams(ds, uiVals);
            bgArgs = {};
            if cbSubtractBG.Value && ~isempty(appData.bgDataset)
                bgArgs = {'BgDataset', appData.bgDataset, ...
                          'BgInterp', ddBGInterp.Value};
            end
            corrData = dataplotter.applyCorrections(d, corrParams, bgArgs{:});

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
        fig.Pointer = 'arrow';
        setStatus(sprintf('Corrections applied to all %d datasets.', numel(appData.datasets)));
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
        % 2D datasets have corrections disabled in the UI — skip the full
        % struct copy (corrData = d) that would otherwise double memory.
        if is2DDataset(ds), return; end
        d        = ds.data;
        xOff     = efXOffset.Value;
        yOff     = efYOffset.Value;
        bgSlope  = efBGSlope.Value;
        bgIntcpt = efBGIntercept.Value;

        % ════════════════════════════════════════════════════════════════
        %  Save undo state before applying new corrections
        % ════════════════════════════════════════════════════════════════
        undoState.corrData       = ds.corrData;
        undoState.mask           = guiTernary(isfield(ds,'mask'), ds.mask, true(size(ds.data.time)));
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
        if isfield(ds, 'derivativeMode')
            undoState.derivativeMode = ds.derivativeMode;
        else
            undoState.derivativeMode = 'None';
        end
        % Magnetometry undo fields
        undoState.sampleMass  = guiTernary(isfield(ds,'sampleMass'),  ds.sampleMass,  0);
        undoState.sampleWidth = guiTernary(isfield(ds,'sampleWidth'), ds.sampleWidth, 0);
        undoState.sampleHeight= guiTernary(isfield(ds,'sampleHeight'),ds.sampleHeight,0);
        undoState.dimUnit     = guiTernary(isfield(ds,'dimUnit'),     ds.dimUnit,     'mm');
        undoState.sampleThick = guiTernary(isfield(ds,'sampleThick'), ds.sampleThick, 0);
        undoState.thickUnit   = guiTernary(isfield(ds,'thickUnit'),   ds.thickUnit,   'nm');
        undoState.momentUnit  = guiTernary(isfield(ds,'momentUnit'),  ds.momentUnit,  'emu (raw)');
        undoState.fieldUnit   = guiTernary(isfield(ds,'fieldUnit'),   ds.fieldUnit,   'Oe (raw)');
        undoState.unitSystem  = guiTernary(isfield(ds,'unitSystem'),  ds.unitSystem,  'CGS');
        % Multi-level undo stack (#13): push onto stack, cap at 5
        if ~isfield(ds, 'undoStack') || ~iscell(ds.undoStack)
            ds.undoStack = {};
        end
        ds.undoStack{end+1} = undoState;
        if numel(ds.undoStack) > 5
            ds.undoStack = ds.undoStack(end-4:end);
        end
        ds.undoState = undoState;  % keep single-state for backward compat

        % ════════════════════════════════════════════════════════════════
        %  Apply corrections via extracted pipeline
        % ════════════════════════════════════════════════════════════════
        xTrimMin = str2num_trim(efXTrimMin.Value);
        xTrimMax = str2num_trim(efXTrimMax.Value);
        sampleVol = 0;
        isMag = ismember(guiTernary(isfield(ds,'parserName'), ds.parserName, ''), ...
                {'importQDVSM','importPPMS','importMPMS','importLakeShore'});
        if isMag
            sampleVol = magSampleVolume_cm3();
        end
        uiVals = struct('xOff', xOff, 'yOff', yOff, ...
            'bgSlope', bgSlope, 'bgInt', bgIntcpt, ...
            'xTrimMin', xTrimMin, 'xTrimMax', xTrimMax, ...
            'smoothEnabled', cbSmooth.Value, ...
            'smoothWindow', efSmoothWin.Value, ...
            'smoothMethod', ddSmoothMethod.Value, ...
            'normMethod', ddNormalize.Value, ...
            'derivativeMode', ddDerivative.Value, ...
            'fieldUnit', ddFieldUnit.Value, ...
            'momentUnit', ddMomentUnit.Value, ...
            'sampleMass', efSampleMass.Value, ...
            'sampleVolume', sampleVol);
        corrParams = dataplotter.correctionParams(ds, uiVals);
        bgArgs = {};
        if cbSubtractBG.Value && ~isempty(appData.bgDataset)
            bgArgs = {'BgDataset', appData.bgDataset, ...
                      'BgInterp', ddBGInterp.Value};
        end
        corrData = dataplotter.applyCorrections(d, corrParams, bgArgs{:});
        derivMode = ddDerivative.Value;

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
        ds.normMethod      = ddNormalize.Value;
        ds.derivativeMode  = ddDerivative.Value;
        % Magnetometry sample parameters
        ds.sampleMass    = efSampleMass.Value;
        ds.sampleWidth   = efSampleWidth.Value;
        ds.sampleHeight  = efSampleHeight.Value;
        ds.dimUnit       = ddDimUnit.Value;
        ds.sampleThick   = efSampleThick.Value;
        ds.thickUnit     = ddThickUnit.Value;
        ds.momentUnit    = ddMomentUnit.Value;
        ds.fieldUnit     = ddFieldUnit.Value;
        ds.unitSystem    = ddUnitSystem.Value;
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
                % Apply same correction pipeline via extracted function
                pUiVals = struct('xOff', xOff, 'yOff', yOff, ...
                    'bgSlope', 0, 'bgInt', 0, ...
                    'xTrimMin', xTrimMin, 'xTrimMax', xTrimMax, ...
                    'smoothEnabled', false, 'smoothWindow', 5, ...
                    'smoothMethod', 'Moving', ...
                    'normMethod', normVal, 'derivativeMode', 'None', ...
                    'fieldUnit', 'Oe (raw)', 'momentUnit', 'emu (raw)');
                pParams = dataplotter.correctionParams(pds, pUiVals);
                pCorr = dataplotter.applyCorrections(pds.data, pParams);
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

        % Reset dirty-state indicator on Apply button
        btnApply.Text      = 'Apply Corrections';
        btnApply.FontColor = BTN_FG;

        % Record correction parameters in macro
        recordAction(sprintf("%% Apply corrections: XOff=%.6g YOff=%.6g BGSlope=%.6g BGInt=%.6g Smooth=%s Norm=%s Deriv=%s", ...
            xOff, yOff, bgSlope, bgIntcpt, ...
            string(cbSmooth.Value), ddNormalize.Value, ddDerivative.Value));

        onPlot([],[]);
    end

    function markCorrectionsDirty()
    %MARKCORRECTIONSDIRTY  Visually indicate that correction fields have
    %  changed and the plot may be stale.  If live-preview is enabled (#2),
    %  immediately apply corrections and redraw instead.
        if cbLivePreview.Value
            onApplyCorrections([], []);
            return;
        end
        if isvalid(btnApply)
            btnApply.Text      = 'Apply  *';
            btnApply.FontColor = [1 0.85 0.2];
        end
    end

    function updateApplyButtonStyle()
    %UPDATEAPPLYBUTTONSTYLE  Style the Apply button based on Live Preview state.
    %   When Live Preview is ON, Apply is redundant — show it as muted.
    %   When OFF, highlight it as the primary action the user needs to click.
        if ~isvalid(btnApply), return; end
        if cbLivePreview.Value
            btnApply.BackgroundColor = BTN_TOOL;
            btnApply.FontColor       = [0.70 0.70 0.70];
            btnApply.FontWeight      = 'normal';
        else
            btnApply.BackgroundColor = BTN_PRIMARY;
            btnApply.FontColor       = BTN_FG;
            btnApply.FontWeight      = 'bold';
        end
    end

    function setStatus(msg)
    %SETSTATUS  Update the status bar text and flush to screen.
        if isvalid(lblStatusBar)
            lblStatusBar.Text = msg;
            drawnow limitrate;
        end
    end

    function mb = estimateDatasetMemoryMB()
    %ESTIMATEDATASETMEMORYMB  Rough estimate of total dataset memory in MB.
        mb = 0;
        for di = 1:numel(appData.datasets)
            dsi = appData.datasets{di};
            % Raw data
            if isfield(dsi, 'data') && ~isempty(dsi.data)
                mb = mb + numel(dsi.data.time) * 8 / 1e6;
                mb = mb + numel(dsi.data.values) * 8 / 1e6;
            end
            % Corrected data
            if isfield(dsi, 'corrData') && ~isempty(dsi.corrData)
                mb = mb + numel(dsi.corrData.time) * 8 / 1e6;
                mb = mb + numel(dsi.corrData.values) * 8 / 1e6;
            end
            % 2D map
            if isfield(dsi, 'data') && isfield(dsi.data, 'metadata') && ...
                    isfield(dsi.data.metadata, 'parserSpecific')
                ps = dsi.data.metadata.parserSpecific;
                if isfield(ps, 'map2D') && isfield(ps.map2D, 'intensity')
                    mb = mb + numel(ps.map2D.intensity) * 8 / 1e6;
                    if isfield(ps.map2D, 'Qx')
                        mb = mb + numel(ps.map2D.Qx) * 8 / 1e6;
                        mb = mb + numel(ps.map2D.Qz) * 8 / 1e6;
                    end
                end
            end
        end
    end

    function recordAction(cmd)
    %RECORDACTION  Append a MATLAB command to the macro log (if recording).
        if appData.macroRecording
            appData.macroLog.record(cmd);
            % Update record button text with entry count
            btnMacroRecord.Text = sprintf('%s %d', char(9632), appData.macroLog.nEntries());
        end
    end

    function onToggleMacroRecord(~, ~)
    %ONTOGGLEMACRORECORD  Start/stop macro recording.
        if appData.macroRecording
            % Stop recording
            appData.macroRecording = false;
            btnMacroRecord.Text = char(9210);  % ⏺
            btnMacroRecord.FontColor = [0.6 0.6 0.6];
            btnMacroExport.Enable = 'on';
            n = appData.macroLog.nEntries();
            setStatus(sprintf('Macro recording stopped (%d commands).', n));
        else
            % Start recording (clear previous log)
            appData.macroLog.clear();
            appData.macroRecording = true;
            btnMacroRecord.Text = [char(9632) ' 0'];  % ■ stop symbol + count
            btnMacroRecord.FontColor = [0.9 0.2 0.2];  % red = recording
            btnMacroExport.Enable = 'off';
            setStatus('Macro recording started — GUI actions will be captured.');
        end
    end

    function onExportMacro(~, ~)
    %ONEXPORTMACRO  Save the recorded macro to a .m file.
        if appData.macroLog.nEntries() == 0
            uialert(fig, 'No commands recorded.', 'Export Macro');
            return;
        end
        [fn, fp] = uiputfile({'*.m', 'MATLAB Script (*.m)'}, ...
            'Save Macro Script', 'analysis_macro.m');
        if isequal(fn, 0), return; end
        outPath = fullfile(fp, fn);
        try
            appData.macroLog.exportScript(outPath);
            setStatus(sprintf('Macro exported: %s (%d commands)', fn, appData.macroLog.nEntries()));
        catch ME
            uialert(fig, sprintf('Export failed:\n%s', ME.message), 'Export Error');
        end
    end

    function onResetCorrections(~,~)
        % Guard: confirm if corrections have been applied
        if appData.activeIdx >= 1 && ~isempty(appData.datasets)
            dsReset = appData.datasets{appData.activeIdx};
            if ~isempty(dsReset.corrData)
                sel = uiconfirm(fig, ...
                    'Discard all corrections for the active dataset?', ...
                    'Reset Corrections', 'Options', {'Reset', 'Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2);
                if ~strcmp(sel, 'Reset'), return; end
            end
        end
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
        % Reset magnetometry fields
        efSampleMass.Value   = 0;
        efSampleWidth.Value  = 0;
        efSampleHeight.Value = 0;
        ddDimUnit.Value      = 'mm';
        efSampleThick.Value  = 0;
        ddThickUnit.Value    = 'nm';
        ddMomentUnit.Value   = 'emu (raw)';
        ddFieldUnit.Value    = 'Oe (raw)';
        ddUnitSystem.Value   = 'CGS';

        if appData.activeIdx >= 1 && ~isempty(appData.datasets)
            ds               = appData.datasets{appData.activeIdx};
            ds.corrData      = [];
            ds.mask          = true(size(ds.data.time));
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
            ds.sampleMass    = 0;
            ds.sampleWidth   = 0;
            ds.sampleHeight  = 0;
            ds.dimUnit       = 'mm';
            ds.sampleThick   = 0;
            ds.thickUnit     = 'nm';
            ds.momentUnit    = 'emu (raw)';
            ds.fieldUnit     = 'Oe (raw)';
            ds.unitSystem    = 'CGS';
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
    %ONUNDOCORRECTIONS  Restore the previous correction state from the undo stack.
    %  Supports multi-level undo (up to 5 levels, #13).
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data');
            return;
        end

        ds = appData.datasets{appData.activeIdx};

        % Pop from multi-level stack if available, else fall back to single undoState
        hasStack = isfield(ds, 'undoStack') && iscell(ds.undoStack) && ~isempty(ds.undoStack);
        hasSingle = isfield(ds, 'undoState') && isstruct(ds.undoState) && ~isempty(fieldnames(ds.undoState));
        if ~hasStack && ~hasSingle
            uialert(fig, 'No previous correction state to restore.', 'Undo unavailable');
            return;
        end

        if hasStack
            undoState = ds.undoStack{end};
            ds.undoStack(end) = [];  % pop
        else
            undoState = ds.undoState;
            ds.undoState = struct();
        end

        % Restore all correction state from the saved undo state
        ds.corrData      = undoState.corrData;
        if isfield(undoState, 'mask'), ds.mask = undoState.mask; end
        ds.xOff          = undoState.xOff;
        ds.yOff          = undoState.yOff;
        ds.bgSlope       = undoState.bgSlope;
        ds.bgInt         = undoState.bgInt;
        ds.smoothEnabled = undoState.smoothEnabled;
        ds.smoothWindow  = undoState.smoothWindow;
        ds.smoothMethod  = undoState.smoothMethod;
        if isfield(undoState, 'xTrimMin'), ds.xTrimMin = undoState.xTrimMin; end
        if isfield(undoState, 'xTrimMax'), ds.xTrimMax = undoState.xTrimMax; end
        if isfield(undoState, 'normMethod'), ds.normMethod = undoState.normMethod; end
        if isfield(undoState, 'bgPoly'), ds.bgPoly = undoState.bgPoly; end
        if isfield(undoState, 'derivativeMode'), ds.derivativeMode = undoState.derivativeMode; end
        % Magnetometry undo restore
        if isfield(undoState, 'sampleMass'),  ds.sampleMass  = undoState.sampleMass;  end
        if isfield(undoState, 'sampleWidth'), ds.sampleWidth = undoState.sampleWidth; end
        if isfield(undoState, 'sampleHeight'),ds.sampleHeight= undoState.sampleHeight;end
        if isfield(undoState, 'dimUnit'),     ds.dimUnit     = undoState.dimUnit;     end
        if isfield(undoState, 'sampleThick'), ds.sampleThick = undoState.sampleThick; end
        if isfield(undoState, 'thickUnit'),   ds.thickUnit   = undoState.thickUnit;   end
        if isfield(undoState, 'momentUnit'),  ds.momentUnit  = undoState.momentUnit;  end
        if isfield(undoState, 'fieldUnit'),   ds.fieldUnit   = undoState.fieldUnit;   end
        if isfield(undoState, 'unitSystem'),  ds.unitSystem  = undoState.unitSystem;  end

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
        if isfield(ds, 'derivativeMode')
            ddDerivative.Value = ds.derivativeMode;
        end
        % Magnetometry UI sync
        efSampleMass.Value   = guiTernary(isfield(ds,'sampleMass'),   ds.sampleMass,   0);
        efSampleWidth.Value  = guiTernary(isfield(ds,'sampleWidth'),  ds.sampleWidth,  0);
        efSampleHeight.Value = guiTernary(isfield(ds,'sampleHeight'), ds.sampleHeight, 0);
        ddDimUnit.Value      = guiTernary(isfield(ds,'dimUnit'),      ds.dimUnit,      'mm');
        efSampleThick.Value  = guiTernary(isfield(ds,'sampleThick'),  ds.sampleThick,  0);
        ddThickUnit.Value    = guiTernary(isfield(ds,'thickUnit'),    ds.thickUnit,    'nm');
        ddMomentUnit.Value   = guiTernary(isfield(ds,'momentUnit'),   ds.momentUnit,   'emu (raw)');
        ddFieldUnit.Value    = guiTernary(isfield(ds,'fieldUnit'),    ds.fieldUnit,    'Oe (raw)');
        ddUnitSystem.Value   = guiTernary(isfield(ds,'unitSystem'),   ds.unitSystem,   'CGS');

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
            btnToggleVis.Text = 'Hide';
        else
            btnToggleVis.Text = 'Show';
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

        % Use displayed (corrected) data for hit-testing the box region,
        % then map selected indices back to raw data for the polynomial fit.
        % This ensures the box drawn on the preview matches the visible data,
        % while the BG polynomial operates in raw coordinates (as expected
        % by onApplyCorrections).
        ds      = appData.datasets{appData.activeIdx};
        d       = ds.data;
        dDisp   = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        xVecRaw = appData.bgXVecRaw;
        % Displayed x may be shorter (trimmed) or unit-converted;
        % build the displayed x vector to match dDisp.values row count.
        % Also apply SI prefix scaling so coordinates match the axes.
        if ~isdatetime(dDisp.time)
            xDisp = double(dDisp.time);
        else
            xDisp = (1:numel(dDisp.time))';
        end
        pfX = appData.axisPrefixX;
        pfY = appData.axisPrefixY;
        if pfX.factor ~= 1, xDisp = xDisp * pfX.factor; end

        ySel = ensureCell(lbY.Value);

        xPool = [];
        yPool = [];
        for k = 1:numel(ySel)
            idx = find(strcmp(dDisp.labels, ySel{k}), 1);
            if isempty(idx), continue; end
            yDisp = dDisp.values(:, idx);
            if pfY.factor ~= 1, yDisp = yDisp * pfY.factor; end
            nDisp = min(numel(xDisp), numel(yDisp));
            inBox = xDisp(1:nDisp) >= xMin & xDisp(1:nDisp) <= xMax & ...
                    yDisp(1:nDisp) >= yMin & yDisp(1:nDisp) <= yMax & ...
                    ~isnan(xDisp(1:nDisp)) & ~isnan(yDisp(1:nDisp));
            % Map back to raw data for polyfit (use same row indices)
            idxRaw = find(strcmp(d.labels, ySel{k}), 1);
            if isempty(idxRaw), idxRaw = idx; end
            % When trimming is active, dDisp may have fewer rows than d;
            % find the corresponding raw rows via the trim mask.
            rawRows = bgDisplayToRawRows(ds, inBox);
            xPool = [xPool; xVecRaw(rawRows)];        %#ok<AGROW>
            yPool = [yPool; d.values(rawRows, idxRaw)]; %#ok<AGROW>
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

    function rawRows = bgDisplayToRawRows(ds, dispMask)
    %BGDISPLAYTORAWROWS  Map a logical mask on displayed (corrected) data
    %  rows back to raw data row indices.  When trimming is active the
    %  displayed data has fewer rows than the raw data; this function
    %  reconstructs the trim mask to find the original row positions.
        d = ds.data;
        nRaw = numel(d.time);
        % Rebuild the trim mask applied during onApplyCorrections
        trimMin = guiTernary(isfield(ds,'xTrimMin'), ds.xTrimMin, NaN);
        trimMax = guiTernary(isfield(ds,'xTrimMax'), ds.xTrimMax, NaN);
        if isdatetime(d.time)
            keepMask = true(nRaw, 1);
        else
            tVec = double(d.time);
            keepMask = true(nRaw, 1);
            if ~isnan(trimMin), keepMask = keepMask & tVec >= trimMin; end
            if ~isnan(trimMax), keepMask = keepMask & tVec <= trimMax; end
        end
        % Indices of raw rows that survived trimming
        keptIdx = find(keepMask);
        % dispMask is logical over the trimmed (displayed) rows;
        % pad if shorter (shouldn't happen, but guard against edge cases)
        if numel(dispMask) < numel(keptIdx)
            dispMask(end+1:numel(keptIdx)) = false;
        end
        rawRows = keptIdx(dispMask(1:numel(keptIdx)));
    end

    function dmask = buildDisplayMask(ds)
    %BUILDDISPLAYMASK  Return logical mask mapped to corrected/displayed data.
    %  Translates the raw ds.mask through X-trim so it aligns with corrData.
        if ~isfield(ds, 'mask') || isempty(ds.mask) || all(ds.mask)
            d = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
            dmask = true(size(d.time));
            return;
        end
        if ~isempty(ds.corrData)
            nRaw  = numel(ds.data.time);
            keepM = true(nRaw, 1);
            if ~isdatetime(ds.data.time)
                tVM = double(ds.data.time);
                trimMin = guiTernary(isfield(ds,'xTrimMin'), ds.xTrimMin, NaN);
                trimMax = guiTernary(isfield(ds,'xTrimMax'), ds.xTrimMax, NaN);
                if ~isnan(trimMin), keepM = keepM & tVM >= trimMin; end
                if ~isnan(trimMax), keepM = keepM & tVM <= trimMax; end
            end
            dmask = ds.mask(keepM);
        else
            dmask = ds.mask;
        end
    end

    % ── Data masking (box-select exclusion) ────────────────────────────────

    function onArmMaskSelection(~,~)
    %ONARMMASKSELECTION  Arm click-and-drag mask mode.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        cancelInteractions();
        btnMaskSelect.Text            = 'Draw rectangle to mask...';
        btnMaskSelect.BackgroundColor = [0.80 0.20 0.20];
        btnMaskSelect.Enable          = 'off';
        fig.Pointer = 'crosshair';
        fig.WindowButtonDownFcn = @onMaskMouseDown;
    end

    function onMaskMouseDown(~,~)
        cp = ax.CurrentPoint;
        x0 = cp(1,1);  y0 = cp(1,2);
        if x0 < ax.XLim(1) || x0 > ax.XLim(2) || ...
           y0 < ax.YLim(1) || y0 > ax.YLim(2)
            return;
        end
        appData.maskStartPt = [x0, y0];
        hold(ax,'on');
        appData.maskRectPatch = patch(ax, ...
            [x0 x0 x0 x0], [y0 y0 y0 y0], [0.85 0.15 0.15], ...
            'FaceAlpha', 0.15, ...
            'EdgeColor', [0.85 0.15 0.15], ...
            'LineWidth', 1.5, ...
            'LineStyle', '--', ...
            'HitTest',   'off', ...
            'Tag',       'GUIMaskBox');
        hold(ax,'off');
        fig.WindowButtonMotionFcn = @onMaskMouseMove;
        fig.WindowButtonUpFcn     = @onMaskMouseUp;
    end

    function onMaskMouseMove(~,~)
        if isempty(appData.maskStartPt) || ...
           isempty(appData.maskRectPatch) || ~isvalid(appData.maskRectPatch)
            return;
        end
        cp = ax.CurrentPoint;
        x1 = cp(1,1);  y1 = cp(1,2);
        x0 = appData.maskStartPt(1);
        y0 = appData.maskStartPt(2);
        set(appData.maskRectPatch, ...
            'XData', [x0, x1, x1, x0], ...
            'YData', [y0, y0, y1, y1]);
    end

    function onMaskMouseUp(~,~)
        % Restore normal interaction state
        fig.WindowButtonDownFcn   = @onAxesButtonDown;
        fig.WindowButtonMotionFcn = @onMouseHover;
        fig.WindowButtonUpFcn     = '';
        fig.Pointer               = 'arrow';
        btnMaskSelect.Text            = 'Mask Selection';
        btnMaskSelect.BackgroundColor = [0.60 0.15 0.15];
        btnMaskSelect.Enable          = 'on';

        % Clean up rectangle
        if ~isempty(appData.maskRectPatch) && isvalid(appData.maskRectPatch)
            delete(appData.maskRectPatch);
        end
        appData.maskRectPatch = [];

        if isempty(appData.maskStartPt), return; end
        cp    = ax.CurrentPoint;
        endPt = [cp(1,1), cp(1,2)];

        xMin = min(appData.maskStartPt(1), endPt(1));
        xMax = max(appData.maskStartPt(1), endPt(1));
        yMin = min(appData.maskStartPt(2), endPt(2));
        yMax = max(appData.maskStartPt(2), endPt(2));
        appData.maskStartPt = [];

        if (xMax - xMin) < eps(xMax), return; end

        applyMaskInBox(xMin, xMax, yMin, yMax);
    end

    function applyMaskInBox(xMin, xMax, yMin, yMax)
    %APPLYMASKINBOX  Mask data points inside the given box for the active dataset.
        ds = appData.datasets{appData.activeIdx};
        primaryD = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);

        % Build displayed x vector (same logic as drawToAxes)
        xSel2  = ddX.Value;
        xName2 = guiXName(ds.data.metadata);
        if strcmp(xSel2, xName2)
            xVec = primaryD.time;
        else
            idx2 = find(strcmp(primaryD.labels, xSel2), 1);
            if isempty(idx2)
                xVec = primaryD.time;
            else
                xVec = primaryD.values(:, idx2);
            end
        end
        xVec = double(xVec);

        % Collect all selected Y channels so box-select hits any visible trace
        ySel2 = ensureCell(lbY.Value);
        inBox = false(size(xVec));
        for k = 1:numel(ySel2)
            yIdx = find(strcmp(primaryD.labels, ySel2{k}), 1);
            if isempty(yIdx), continue; end
            yVec = primaryD.values(:, yIdx);
            inBox = inBox | (xVec >= xMin & xVec <= xMax & ...
                             yVec >= yMin & yVec <= yMax);
        end

        % Map displayed indices back to raw indices
        if ~isempty(ds.corrData)
            rawRows = bgDisplayToRawRows(ds, inBox);
        else
            rawRows = find(inBox);
        end

        if isempty(rawRows), return; end

        % Ensure mask exists
        if ~isfield(ds, 'mask') || isempty(ds.mask)
            ds.mask = true(size(ds.data.time));
        end
        ds.mask(rawRows) = false;
        appData.datasets{appData.activeIdx} = ds;

        nMasked = sum(~ds.mask);
        setStatus(sprintf('Masked %d points (%d total masked)', numel(rawRows), nMasked));
        onPlot([], []);
    end

    function onUnmaskAll(~,~)
    %ONUNMASKALL  Restore all masked data points for the active dataset.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};
        ds.mask = true(size(ds.data.time));
        appData.datasets{appData.activeIdx} = ds;
        setStatus('All masked points restored.');
        onPlot([], []);
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
                % Apply mask (exclude masked points from export)
                if isfield(ds, 'mask') && ~isempty(ds.mask) && any(~ds.mask)
                    if hasCorrected
                        % Map raw mask through trim to match exportData rows
                        nRawE = numel(ds.data.time);
                        keepE = true(nRawE, 1);
                        if ~isdatetime(ds.data.time)
                            tVE = double(ds.data.time);
                            if ~isnan(ds.xTrimMin), keepE = keepE & tVE >= ds.xTrimMin; end
                            if ~isnan(ds.xTrimMax), keepE = keepE & tVE <= ds.xTrimMax; end
                        end
                        exportMask = ds.mask(keepE);
                    else
                        exportMask = ds.mask;
                    end
                    exportData.time   = exportData.time(exportMask);
                    exportData.values = exportData.values(exportMask, :);
                end
                % Apply display-unit scaling (SI prefix + mag unit labels)
                exportData = applyDisplayUnits(exportData, ds);
                if hasCorrected
                    asymData = computeAsymmetryForExport(ds);
                    % Include original raw data alongside display-scaled corrected
                    guiSaveCSV(exportData, fp, ds.data, asymData, fmt);
                else
                    % No corrections — export in display units, no duplication
                    guiSaveCSV(exportData, fp, [], [], fmt);
                end
            end
            recordAction(sprintf("%% Exported CSV: %s", fp));
            uialert(fig, sprintf('Saved:\n%s', fp), 'Saved');
        catch ME
            fprintf(2, '\n[DataPlotter] Save error: %s\n', ME.message);
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

    function d = applyDisplayUnits(d, ds)
    %APPLYDISPLAYUNITS  Scale exported data to match the units shown on the preview plot.
    %   Applies two transformations:
    %   1. Magnetometry unit labels: updates .labels and .units to reflect
    %      the field/moment unit chosen in the corrections panel.
    %   2. SI axis prefix scaling: multiplies .time and .values by the
    %      prefix factors currently active on the preview axes (e.g. kilo = 1e-3).

        % ── 1. Magnetometry unit labels ────────────────────────────────
        isMag = ismember(guiTernary(isfield(ds,'parserName'), ds.parserName, ''), ...
                    {'importQDVSM','importPPMS','importMPMS','importLakeShore'});
        if isMag && ~isempty(ds.corrData)
            fu = guiTernary(isfield(ds,'fieldUnit'),  ds.fieldUnit,  'Oe (raw)');
            mu = guiTernary(isfield(ds,'momentUnit'), ds.momentUnit, 'emu (raw)');
            % Update x-axis unit in metadata
            if ~strcmp(fu, 'Oe (raw)')
                fuClean = regexprep(fu, ' \(raw\)', '');
                if isfield(d, 'metadata') && isfield(d.metadata, 'xColumnUnit')
                    d.metadata.xColumnUnit = fuClean;
                end
            end
            % Update y-channel units
            if ~strcmp(mu, 'emu (raw)')
                for k = 1:numel(d.units)
                    d.units{k} = mu;
                end
            end
        end

        % ── 2. SI prefix scaling (matches preview axes) ────────────────
        pfX = appData.axisPrefixX;
        pfY = appData.axisPrefixY;
        if pfX.factor ~= 1 && ~isdatetime(d.time)
            d.time = d.time * pfX.factor;
            % Prepend prefix symbol to x-axis unit
            if isfield(d, 'metadata') && isfield(d.metadata, 'xColumnUnit')
                d.metadata.xColumnUnit = [pfX.symbol, d.metadata.xColumnUnit];
            end
        end
        if pfY.factor ~= 1
            d.values = d.values * pfY.factor;
            % Prepend prefix symbol to all y-channel units
            for k = 1:numel(d.units)
                d.units{k} = [pfY.symbol, d.units{k}];
            end
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

        % Output directory picker (#8): choose folder or use source-adjacent
        outDir = uigetdir(guiTernary(isempty(appData.lastDir), pwd, appData.lastDir), ...
            'Choose output folder (Cancel = save next to source files)');
        if isequal(outDir, 0), outDir = ''; end  % empty = source-adjacent

        setStatus('Exporting CSV files...');
        fig.Pointer = 'watch';
        drawnow;

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
                if ~isempty(outDir), fpath = outDir; end
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
            exportData   = applyDisplayUnits(exportData, ds);
            suffix       = guiTernary(hasCorrected, '_corrected.csv', '_export.csv');

            [fpath, fname, ~] = fileparts(ds.filepath);
            if ~isempty(outDir), fpath = outDir; end
            outFile = fullfile(fpath, [fname, suffix]);

            try
                % Include raw data alongside corrected; skip duplication if uncorrected
                rawRef = guiTernary(hasCorrected, ds.data, []);
                guiSaveCSV(exportData, outFile, rawRef, [], fmt);
                nExported = nExported + 1;
            catch ME
                failedFiles{end+1} = sprintf('%s: %s', fname, ME.message); %#ok<AGROW>
            end
        end

        % Show result
        fig.Pointer = 'arrow';
        if nExported == 0
            setStatus('Batch export: no datasets exported.');
            uialert(fig, 'No datasets to export.', 'Batch Export');
        elseif isempty(failedFiles)
            setStatus(sprintf('Batch export complete: %d file(s) saved.', nExported));
            uialert(fig, sprintf('Successfully exported %d file(s) to CSV.', nExported), ...
                'Batch Export Complete');
        else
            setStatus(sprintf('Batch export partial: %d exported, %d failed.', nExported, numel(failedFiles)));
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
            src = applyDisplayUnits(src, dsi);
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
        src = applyDisplayUnits(src, ds);
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
            'LogY',       strcmp(ddScaleY.Value, 'Log'), ...
            'LogX',       strcmp(ddScaleX.Value, 'Log'));

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
                'LogY', strcmp(ddScaleY.Value, 'Log'), ...
                'LogX', strcmp(ddScaleX.Value, 'Log'));
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
            fprintf(2, '\n[DataPlotter] HDF5 export error: %s\n', ME.message);
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
            if ~isprop(appData, 'asymmetryPrevLogY')
                appData.asymmetryPrevLogY = strcmp(ddScaleY.Value, 'Log');
            end
            ddScaleY.Value = 'Linear';  % Switch to linear scale

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
            if isprop(appData, 'asymmetryPrevLogY')
                if appData.asymmetryPrevLogY, ddScaleY.Value = 'Log'; else, ddScaleY.Value = 'Linear'; end
            end
        end

        onPlot([], []);  % Redraw plot with updated visibility and scale
    end

    function drawToAxes(targetAx)
    %DRAWTOAXES  Render SELECTED datasets into targetAx.
    %   Only datasets selected in lbDatasets are plotted.  Single-click
    %   plots one dataset; Ctrl+click / Shift+click plots multiple.
    %   Channel selection and x-axis label are driven by the active dataset.
    %   Each (dataset, y-channel) pair gets a unique colour from lines().
    %   Called by onPlot (GUI uiaxes) and onExportFigure (regular axes).
        try
            if isempty(appData.datasets) || appData.activeIdx < 1, return; end

            activeDs = appData.datasets{appData.activeIdx};

            % ── Determine which datasets to plot (listbox selection) ─────
            rawSel = lbDatasets.Value;
            if ~iscell(rawSel), rawSel = {rawSel}; end
            plotIdx = cell2mat(rawSel);
            plotIdx = plotIdx(plotIdx >= 1 & plotIdx <= numel(appData.datasets));
            % Always include active dataset so it is visible
            if ~ismember(appData.activeIdx, plotIdx)
                plotIdx = sort([plotIdx, appData.activeIdx]);
            end
            nDS = numel(plotIdx);

            % ── Channel selection from the active dataset ─────────────────
            xSel   = ddX.Value;
            xName  = guiXName(activeDs.data.metadata);
            xUnit  = guiXUnit(activeDs.data.metadata);
            xLabel = guiLabel(xName, xUnit);

            % Override axis labels when magnetometry unit conversion is active
            magYLabel = '';
            isMagActive = ~isempty(activeDs.corrData) && ...
                ismember(guiTernary(isfield(activeDs,'parserName'), activeDs.parserName, ''), ...
                    {'importQDVSM','importPPMS','importMPMS','importLakeShore'});
            if isMagActive
                fu = guiTernary(isfield(activeDs,'fieldUnit'),  activeDs.fieldUnit,  'Oe (raw)');
                mu = guiTernary(isfield(activeDs,'momentUnit'), activeDs.momentUnit, 'emu (raw)');
                if ~strcmp(fu, 'Oe (raw)')
                    fuClean = regexprep(fu, ' \(raw\)', '');
                    xLabel = sprintf('Magnetic Field (%s)', fuClean);
                end
                if ~strcmp(mu, 'emu (raw)')
                    magYLabel = sprintf('Magnetization (%s)', mu);
                end
            end

            ySel = ensureCell(lbY.Value);
            nY   = numel(ySel);

            y2SelRaw = ensureCell(lbY2.Value);
            y2Sel    = y2SelRaw(~strcmp(y2SelRaw, '(none)'));
            nY2      = numel(y2Sel);
            hasY2    = nY2 > 0;

            % ── Colour allocation ─────────────────────────────────────────
            % Generate colors from selected colormap or default lines() palette.
            % Left-axis indices:  (si-1)*nY  + k   (si = position in plotIdx)
            % Right-axis indices: nDS*nY     + (si-1)*nY2 + k
            colormapName = ddColormap.Value;
            nColors = max(nDS * (nY + nY2), 1);
            useWfGradient = cbWaterfall.Value && appData.wfGradient && nDS > 1;
            if useWfGradient
                % Gradient mode: one color per dataset from cool→warm colormap
                gradCmap = interp1([0 0.5 1], ...
                    [0.23 0.30 0.75; 0.87 0.87 0.87; 0.71 0.02 0.15], ...
                    linspace(0, 1, nDS)', 'pchip');  % coolwarm diverging
                % Expand: each dataset's nY channels get the same color
                colors = zeros(nColors, 3);
                for gi = 1:nDS
                    for gk = 1:nY
                        colors((gi-1)*nY + gk, :) = gradCmap(gi, :);
                    end
                    for gk = 1:nY2
                        colors(nDS*nY + (gi-1)*nY2 + gk, :) = gradCmap(gi, :);
                    end
                end
            else
                colors = getColorsFromMap(colormapName, nColors);
            end

            % ── Draw ──────────────────────────────────────────────────────
            % Peak markers and zoom rect use HandleVisibility='off' so ax.Children may
            % omit them in some MATLAB releases. findall() bypasses this filter.
            delete(findall(targetAx, 'Tag', 'GUIPeakAnnotation'));
            delete(findall(targetAx, 'Tag', 'GUISNIPBackground'));
            delete(findall(targetAx, 'Tag', 'GUIZoomBox'));
            delete(findall(targetAx, 'Tag', 'GUIRefLine'));
            delete(findall(targetAx, 'Tag', 'GUIMaskedPoints'));
            delete(findall(targetAx, 'Tag', 'GUIMaskBox'));
            delete(findall(targetAx, 'Tag', 'GUIFringeMarker'));
            delete(findall(targetAx, 'Tag', 'GUIFringeAnnotation'));
            delete(findall(targetAx, 'Tag', 'GUIFringeSpan'));
            delete(findall(targetAx, 'Tag', 'GUIPhaseTickMark'));
            delete(findall(targetAx, 'Tag', 'GUIPhaseLabel'));
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
            wfLogMode = waterfallOn && strcmp(ddScaleY.Value, 'Log');

            % For neutron data, group polarization cross-sections from the
            % same measurement so they share the same waterfall offset.
            % E.g., file-refl.datA and file-refl.datD get the same offset.
            wfGroupIdx = (1:nDS)';  % default: each dataset gets its own group
            if waterfallOn && nDS > 1
                anyNeutron = false;
                baseNames = cell(nDS, 1);
                for gi = 1:nDS
                    gds = appData.datasets{plotIdx(gi)};
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

            % SIMS waterfall: offset by element (channel), not by dataset.
            %   Single file:  each selected element gets its own offset tier.
            %   Multiple files: group by file — all elements in one file share
            %     the same tier, different files get successive tiers.
            wfSIMSByChannel = false;
            if waterfallOn
                anySIMS = false;
                for gi = 1:nDS
                    gds = appData.datasets{plotIdx(gi)};
                    if isfield(gds,'parserName') && strcmp(gds.parserName,'importSIMS')
                        anySIMS = true; break;
                    end
                end
                if anySIMS && nDS == 1
                    wfSIMSByChannel = true;  % offset driven by channel k
                elseif anySIMS && nDS > 1
                    % Group by file — all channels share the dataset's group
                    % (wfGroupIdx already defaults to per-dataset, which is correct)
                end
            end

            for si = 1:nDS
                di          = plotIdx(si);
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

                % ── Build display mask from ds.mask (raw row mask) ───────
                if isfield(ds, 'mask') && ~isempty(ds.mask) && any(~ds.mask)
                    if hasCorrData
                        % Map raw mask through trim to match primaryD row count
                        nRaw    = numel(d.time);
                        rawMask = ds.mask;
                        keepM   = true(nRaw, 1);
                        if ~isdatetime(d.time)
                            tVM = double(d.time);
                            if isfield(ds,'xTrimMin') && ~isnan(ds.xTrimMin)
                                keepM = keepM & tVM >= ds.xTrimMin;
                            end
                            if isfield(ds,'xTrimMax') && ~isnan(ds.xTrimMax)
                                keepM = keepM & tVM <= ds.xTrimMax;
                            end
                        end
                        displayMask = rawMask(keepM);
                    else
                        displayMask = ds.mask;
                    end
                else
                    displayMask = true(size(primaryD.time));
                end

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

                % SIMS flag: legend shows element name only, unit goes on y-axis
                isSIMSds = isfield(ds,'parserName') && strcmp(ds.parserName,'importSIMS');

                for k = 1:nY
                    colorIdx  = (si-1)*nY + k;
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
                                yR = yR * effectiveSpacing^(wfGroupIdx(si) - 1);
                            else
                                yR = yR + (wfGroupIdx(si) - 1) * effectiveSpacing;
                            end
                        end

                        % Filter NaN + masked points
                        good = ~isnan(xVecPrimary) & ~isnan(yR) & displayMask;
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
                                    yTheory = yTheory * effectiveSpacing^(wfGroupIdx(si) - 1);
                                else
                                    yTheory = yTheory + (wfGroupIdx(si) - 1) * effectiveSpacing;
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
                        % SIMS: legend shows element name only (unit goes on y-axis)
                        if isSIMSds
                            baseLabel = [d.labels{idx}, fileSuffix];
                        else
                            baseLabel = [guiLabel(d.labels{idx}, d.units{idx}), fileSuffix];
                        end

                        % Waterfall offset index for this trace.
                        % SIMS single-file: each element k gets its own tier.
                        % SIMS multi-file:  all elements share the file's tier.
                        if wfSIMSByChannel
                            wfOffset = k - 1;
                        else
                            wfOffset = wfGroupIdx(si) - 1;
                        end

                        % Raw overlay (dashed, desaturated 50% white-blend)
                        if showRawOver
                            anyRawShown = true;
                            yRaw     = d.values(:, idx);
                            if ctFactor > 0, yRaw = yRaw / ctFactor; end
                            if effectiveSpacing ~= 0
                                if wfLogMode
                                    yRaw = yRaw * effectiveSpacing^wfOffset;
                                else
                                    yRaw = yRaw + wfOffset * effectiveSpacing;
                                end
                            end
                            rawColor = 0.5 * baseColor + 0.5 * [1 1 1];
                            rawMaskVec = guiTernary(isfield(ds,'mask') && ~isempty(ds.mask), ds.mask, true(size(xVecRaw)));
                            if isdatetime(xVecRaw)
                                good = ~isnat(xVecRaw) & ~isnan(yRaw) & rawMaskVec;
                            else
                                good = ~isnan(xVecRaw) & ~isnan(yRaw) & rawMaskVec;
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
                                yPrimary = yPrimary * effectiveSpacing^wfOffset;
                            else
                                yPrimary = yPrimary + wfOffset * effectiveSpacing;
                            end
                        end
                        if isdatetime(xVecPrimary)
                            good = ~isnat(xVecPrimary) & ~isnan(yPrimary) & displayMask;
                        else
                            good = ~isnan(xVecPrimary) & ~isnan(yPrimary) & displayMask;
                        end
                        dispName = guiTernary(hasCorrData, [baseLabel, ' (corr)'], baseLabel);
                        if isfield(ds,'legendName') && ~isempty(ds.legendName)
                            dispName = ds.legendName;
                        end
                        % Auto-detect error column for this y-channel (#4, #17)
                        errIdx = findErrorColumn(primaryD.labels, ySel{k});
                        if ~isempty(errIdx)
                            yErr = primaryD.values(:, errIdx);
                            if ctFactor > 0, yErr = yErr / ctFactor; end
                            yErrGood = yErr(good);

                            if strcmp(appData.style, 'ErrorBand')
                                % Shaded error band (#17)
                                xFill = [xVecPrimary(good); flipud(xVecPrimary(good))];
                                yFill = [yPrimary(good) + yErrGood; flipud(yPrimary(good) - yErrGood)];
                                fill(targetAx, xFill, yFill, baseColor, ...
                                    'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
                                    'HitTest', 'off', 'HandleVisibility', 'off');
                                plot(targetAx, xVecPrimary(good), yPrimary(good), lsPrimary{:}, ...
                                    'Color', baseColor, 'HitTest', 'off', ...
                                    'DisplayName', dispName);
                            else
                                % Standard error bars via errorbar()
                                errorbar(targetAx, xVecPrimary(good), yPrimary(good), yErrGood, ...
                                    'Color', baseColor, 'LineWidth', 1.0, ...
                                    'CapSize', 3, 'HitTest', 'off', ...
                                    'DisplayName', dispName);
                            end
                        else
                            plot(targetAx, xVecPrimary(good), yPrimary(good), lsPrimary{:}, ...
                                'Color',       baseColor, ...
                                'HitTest',     'off', ...
                                'DisplayName', dispName);
                        end
                    end
                end

                % ── Show masked points as faded gray dots ────────────────
                if any(~displayMask)
                    for km = 1:nY
                        idxM = find(strcmp(primaryD.labels, ySel{km}), 1);
                        if isempty(idxM), continue; end
                        yM = primaryD.values(:, idxM);
                        if ctFactor > 0, yM = yM / ctFactor; end
                        masked = ~displayMask & ~isnan(double(xVecPrimary)) & ~isnan(yM);
                        if any(masked)
                            plot(targetAx, xVecPrimary(masked), yM(masked), '.', ...
                                'Color', [0.55 0.55 0.55], ...
                                'MarkerSize', 4, ...
                                'HitTest', 'off', ...
                                'HandleVisibility', 'off', ...
                                'Tag', 'GUIMaskedPoints');
                        end
                    end
                end

                % ── Right-axis (Y2) channels ──────────────────────────────
                if hasY2
                    yyaxis(targetAx, 'right');
                    for k2 = 1:nY2
                        colorIdx2  = nDS*nY + (si-1)*nY2 + k2;
                        baseColor2 = guiTernary(~isempty(dsColorROverride), dsColorROverride, colors(colorIdx2, :));

                        idx2 = find(strcmp(d.labels, y2Sel{k2}), 1);
                        if isempty(idx2), continue; end

                        if isSIMSds
                            baseLabel2 = [d.labels{idx2}, fileSuffix];
                        else
                            baseLabel2 = [guiLabel(d.labels{idx2}, d.units{idx2}), fileSuffix];
                        end
                        yY2 = primaryD.values(:, idx2);
                        if ctFactor > 0, yY2 = yY2 / ctFactor; end

                        if isdatetime(xVecPrimary)
                            good2 = ~isnat(xVecPrimary) & ~isnan(yY2) & displayMask;
                        else
                            good2 = ~isnan(xVecPrimary) & ~isnan(yY2) & displayMask;
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
                targetAx.YScale = guiTernary(strcmp(ddScaleY2.Value, 'Log'), 'log', 'linear');
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

            % Legend: controlled by cbShowLegend checkbox (#1)
            if cbShowLegend.Value && (nY > 1 || nDS > 1 || anyRawShown || hasY2)
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

            % Y label: custom override, mag unit, SIMS, waterfall, then auto (single dataset only)
            isSIMSActive = isfield(activeDs,'parserName') && strcmp(activeDs.parserName,'importSIMS');
            if ~isempty(efCustomYLabel.Value)
                ylabel(targetAx, efCustomYLabel.Value);
            elseif ~isempty(magYLabel)
                ylabel(targetAx, magYLabel);
            elseif isSIMSActive
                % SIMS: show concentration unit on y-axis (shared across elements)
                simsUnit = '';
                for su = 1:numel(activeDs.data.units)
                    if ~isempty(activeDs.data.units{su})
                        simsUnit = activeDs.data.units{su}; break;
                    end
                end
                if isempty(simsUnit)
                    ylabel(targetAx, 'Concentration');
                else
                    ylabel(targetAx, ['Concentration (' simsUnit ')']);
                end
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
                titleStr = sprintf('%d datasets selected  (active: [%d])', ...
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
            targetAx.XScale = guiTernary(strcmp(ddScaleX.Value, 'Log'),'log','linear');
            targetAx.YScale = guiTernary(strcmp(ddScaleY.Value, 'Log'),'log','linear');
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
                axLimGL.RowHeight{3} = 22 * hasY2;
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
                % YAxis.ExponentMode requires R2023a+; guard for older versions
                try
                    targetAx.YAxis(1).ExponentMode = 'manual';
                    targetAx.YAxis(1).Exponent     = 0;
                catch
                    % R2022 fallback: use ruler property if available
                    try targetAx.YRuler.Exponent = 0; catch, end
                end
            elseif isempty(yfmt)
                ytickformat(targetAx, 'auto');
                try targetAx.YAxis(1).ExponentMode = 'auto'; catch, end
            else
                ytickformat(targetAx, yfmt);
                try targetAx.YAxis(1).ExponentMode = 'auto'; catch, end
            end

            if hasY2
                yyaxis(targetAx, 'right');
                y2fmt = ddY2Fmt.Value;
                if strcmp(y2fmt, '__exp0')
                    ytickformat(targetAx, 'auto');
                    try
                        targetAx.YAxis(2).ExponentMode = 'manual';
                        targetAx.YAxis(2).Exponent     = 0;
                    catch
                    end
                elseif isempty(y2fmt)
                    ytickformat(targetAx, 'auto');
                    try targetAx.YAxis(2).ExponentMode = 'auto'; catch, end
                else
                    ytickformat(targetAx, y2fmt);
                    try targetAx.YAxis(2).ExponentMode = 'auto'; catch, end
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

            % ── Reference lines (#11) ────────────────────────────────────────
            if appData.activeIdx >= 1 && ~isempty(appData.datasets)
                dsRef = appData.datasets{appData.activeIdx};
                if isfield(dsRef, 'refLines') && ~isempty(dsRef.refLines)
                    hold(targetAx, 'on');
                    for ri = 1:numel(dsRef.refLines)
                        rl = dsRef.refLines{ri};
                        if strcmp(rl.orientation, 'horizontal')
                            yline(targetAx, rl.value, rl.style, ...
                                'Color', rl.color, 'LineWidth', 1.2, ...
                                'HitTest', 'off', 'HandleVisibility', 'off', ...
                                'Tag', 'GUIRefLine');
                        else
                            xline(targetAx, rl.value, rl.style, ...
                                'Color', rl.color, 'LineWidth', 1.2, ...
                                'HitTest', 'off', 'HandleVisibility', 'off', ...
                                'Tag', 'GUIRefLine');
                        end
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

            % ── SI prefix scaling (post-hoc) ─────────────────────────────
            % Rescale plotted data and axis labels by the prefix factor.
            % Applied after all plotting + limits so it simply transforms
            % the displayed numbers and label text in-place.
            applyAxisPrefix(targetAx, 'x', appData.axisPrefixX);
            applyAxisPrefix(targetAx, 'y', appData.axisPrefixY);

            % ── Restore fringe thickness markers after redraw ────────────
            if targetAx == ax && appData.fringeClickCount == 2 && ...
               all(~isnan(appData.fringeQ))
                recreateFringeMarkers();
            end

        catch ME
            fprintf(2, '\n[DataPlotter] Plot error: %s\n', ME.message);
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
    %   ddScaleY is reinterpreted as log-intensity toggle for 2D maps.
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
            xLbl = [map.axis2Name ' (' map.axis2Unit ')'];
            yLbl = [map.axis1Name ' (' map.axis1Unit ')'];
            % Defer meshgrid — only needed for Contour modes, not Heatmap.
            % imagesc uses the axis vectors directly, avoiding two [N×M]
            % temporary matrices on every replot.
            Xmat = [];  Ymat = [];
        end

        % Log intensity — use dedicated 2D scale dropdown (ddMap2DScale)
        useLogI = strcmp(ddMap2DScale.Value, 'Log₁₀');
        if useLogI
            I = log10(max(I, 1e-9));
        end

        % Per-axes colormap — use the dedicated 2D color scale dropdown
        cmapName = ddMap2DCmap.Value;
        try
            switch lower(cmapName)
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
                if isempty(Xmat), [Xmat, Ymat] = meshgrid(x2, x1); end
                contour(targetAx, Xmat, Ymat, I, nLvl);
            otherwise  % 'Filled Contour'
                if isempty(Xmat), [Xmat, Ymat] = meshgrid(x2, x1); end
                contourf(targetAx, Xmat, Ymat, I, nLvl);
        end

        % Apply colorbar range limits from the editor controls
        cMin = str2double(efMap2DCMin.Value);
        cMax = str2double(efMap2DCMax.Value);
        if ~isnan(cMin) && ~isnan(cMax) && cMax > cMin
            caxis(targetAx, [cMin cMax]);  %#ok<CAXIS>
        elseif ~isnan(cMin)
            cl = caxis(targetAx);  %#ok<CAXIS>
            caxis(targetAx, [cMin cl(2)]);  %#ok<CAXIS>
        elseif ~isnan(cMax)
            cl = caxis(targetAx);  %#ok<CAXIS>
            caxis(targetAx, [cl(1) cMax]);  %#ok<CAXIS>
        end

        % Colorbar with intensity unit label
        if useLogI
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
        fprintf('[DataPlotter] Line-cut added: %s — %s\n', [fn fext], cutLabel);
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

        if useLogX, ddScaleX.Value = 'Log'; else, ddScaleX.Value = 'Linear'; end
        if useLogY, ddScaleY.Value = 'Log'; else, ddScaleY.Value = 'Linear'; end

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

    % ════════════════════════════════════════════════════════════════════
    %  CONTEXT MENU CALLBACKS (right-click on preview axes)
    % ════════════════════════════════════════════════════════════════════

    function onSetAxisPrefixFromMenu(src, whichAxis)
    %ONSETAXISPREFIXFROMMENU  Set SI prefix from context menu item text.
        idx = find(strcmp(appData.prefixNames, src.Text), 1);
        if isempty(idx), return; end
        symbol = appData.prefixSymbols{idx};
        factor = appData.prefixFactors(idx);
        switch whichAxis
            case 'x'
                appData.axisPrefixX = struct('symbol', symbol, 'factor', factor);
            case 'y'
                appData.axisPrefixY = struct('symbol', symbol, 'factor', factor);
        end
        onPlot([], []);
    end

    function onContextToggle(what)
    %ONCONTEXTTOGGLE  Toggle log scale, grid, or axis direction from context menu.
        switch what
            case 'logX'
                if strcmp(ddScaleX.Value,'Log'), ddScaleX.Value = 'Linear'; else, ddScaleX.Value = 'Log'; end
                onPlot([], []);
            case 'logY'
                if strcmp(ddScaleY.Value,'Log'), ddScaleY.Value = 'Linear'; else, ddScaleY.Value = 'Log'; end
                onPlot([], []);
            case 'grid'
                if strcmp(ax.XGrid, 'on')
                    grid(ax, 'off');
                else
                    grid(ax, 'on');
                end
            case 'invertX'
                if strcmp(ax.XDir, 'normal')
                    ax.XDir = 'reverse';
                else
                    ax.XDir = 'normal';
                end
        end
    end

    function onAddRefLineAtCursor(orientation)
    %ONADDREFLINEATCURSOR  Add a reference line at the current cursor position.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        cp = ax.CurrentPoint;
        ds = appData.datasets{appData.activeIdx};
        if ~isfield(ds, 'refLines'), ds.refLines = {}; end
        switch orientation
            case 'horizontal'
                val = cp(1, 2);
                ds.refLines{end+1} = struct('orientation','horizontal','value',val, ...
                    'color',[0.5 0.5 0.5],'style','--');
            case 'vertical'
                val = cp(1, 1);
                ds.refLines{end+1} = struct('orientation','vertical','value',val, ...
                    'color',[0.5 0.5 0.5],'style','--');
        end
        appData.datasets{appData.activeIdx} = ds;
        onPlot([], []);
    end

    function onExportVisibleRange()
    %ONEXPORTVISIBLERANGE  Export only the data within the current axis limits to CSV.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        ds  = appData.datasets{appData.activeIdx};
        src = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        % Apply display-unit scaling so exported values match the preview
        src = applyDisplayUnits(src, ds);
        xLims = ax.XLim;

        % Filter data to visible x range (use scaled x values)
        xVec = double(src.time);
        mask = xVec >= xLims(1) & xVec <= xLims(2);
        if ~any(mask)
            uialert(fig, 'No data points in the visible range.', 'Empty'); return;
        end

        % Build output table
        xVisible = xVec(mask);
        yVisible = src.values(mask, :);

        % File dialog
        [~, fn, ~] = fileparts(ds.filepath);
        defaultName = [fn '_visible.csv'];
        [outFile, outDir] = uiputfile({'*.csv','CSV (*.csv)'}, ...
            'Export Visible Range', defaultName);
        if isequal(outFile, 0), return; end
        outPath = fullfile(outDir, outFile);

        % Write CSV with headers (labels already updated by applyDisplayUnits)
        fid = fopen(outPath, 'w');
        if fid == -1
            uialert(fig, 'Cannot open file for writing.', 'Error'); return;
        end
        xHdr = guiLabel(guiXName(src.metadata), guiXUnit(src.metadata));
        headers = [{xHdr}, cellfun(@(l,u) guiLabel(l,u), ...
            src.labels(:)', src.units(:)', 'UniformOutput', false)];
        fprintf(fid, '%s', headers{1});
        for hi = 2:numel(headers)
            fprintf(fid, ',%s', headers{hi});
        end
        fprintf(fid, '\n');
        % Data rows
        for ri = 1:numel(xVisible)
            fprintf(fid, '%.10g', xVisible(ri));
            for ci = 1:size(yVisible, 2)
                fprintf(fid, ',%.10g', yVisible(ri, ci));
            end
            fprintf(fid, '\n');
        end
        fclose(fid);
        uialert(fig, sprintf('Exported %d points to:\n%s', sum(mask), outPath), ...
            'Export Complete');
    end

    function onClearFitOverlays(~, ~)
    %ONCLEARFITOVERLAYS  Remove curve fit and peak decomposition overlays.
        delete(findall(ax, 'Tag', 'curveFitOverlay'));
        delete(findall(ax, 'Tag', 'curveFitLabel'));
        delete(findall(ax, 'Tag', 'GUIPeakDecomp'));
        delete(findall(ax, 'Tag', 'integrationShade'));
        delete(findall(ax, 'Tag', 'integrationEdge'));
        setStatus('Fit overlays cleared');
    end

    function onCopyPlotToClipboard()
    %ONCOPYPLOTTOCLIPBOARD  Render current plot into a temporary figure and copy to clipboard.
        if isempty(appData.datasets) || appData.activeIdx < 1
            return;
        end
        tmpFig = figure('Visible', 'off', 'Color', 'w', ...
            'Units', 'pixels', 'Position', [100 100 800 500]);
        tmpAx = axes(tmpFig);
        try
            drawToAxes(tmpAx);
            copygraphics(tmpFig, 'Resolution', 200);
        catch
            % copygraphics not available before R2020a — fall back to print
            print(tmpFig, '-dbitmap', '-clipboard');
        end
        delete(tmpFig);
    end

    function applyAxisPrefix(targetAx, whichAxis, prefixInfo)
    %APPLYAXISPREFIX  Rescale plotted data and axis label by an SI prefix.
    %   whichAxis  — 'x' or 'y'
    %   prefixInfo — struct with .symbol (e.g. 'k') and .factor (e.g. 1e-3)
        if prefixInfo.factor == 1
            return;  % no scaling needed
        end
        fac = prefixInfo.factor;
        sym = prefixInfo.symbol;

        % Rescale data on all line/errorbar children
        children = findall(targetAx, '-property', [upper(whichAxis) 'Data']);
        for ci = 1:numel(children)
            ch = children(ci);
            switch whichAxis
                case 'x'
                    ch.XData = ch.XData * fac;
                case 'y'
                    ch.YData = ch.YData * fac;
                    % Also scale error bar deltas if present
                    if isprop(ch, 'YNegativeDelta') && ~isempty(ch.YNegativeDelta)
                        ch.YNegativeDelta = ch.YNegativeDelta * abs(fac);
                        ch.YPositiveDelta = ch.YPositiveDelta * abs(fac);
                    end
            end
        end

        % Reset axis limits to auto so they fit the rescaled data
        switch whichAxis
            case 'x', targetAx.XLimMode = 'auto';
            case 'y', targetAx.YLimMode = 'auto';
        end

        % Update axis label: strip any existing SI prefix from the unit
        % and replace with the new one.
        % e.g. "Depth (um)" + nano → "Depth (nm)"  (not "Depth (num)")
        switch whichAxis
            case 'x', lbl = targetAx.XLabel.String;
            case 'y', lbl = targetAx.YLabel.String;
        end
        if ~isempty(lbl)
            tok = regexp(lbl, '^(.*)\(([^)]+)\)(.*)', 'tokens', 'once');
            if ~isempty(tok)
                unitStr  = tok{2};
                baseUnit = stripSIPrefix(unitStr);
                newUnit  = [sym baseUnit];
                newLbl   = [tok{1} '(' newUnit ')' tok{3}];
            else
                % No parenthesised unit found — append prefix notation
                newLbl = sprintf('%s  [%s%s]', lbl, sym, char(215));
            end
            switch whichAxis
                case 'x', xlabel(targetAx, newLbl);
                case 'y', ylabel(targetAx, newLbl);
            end
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
        if     strcmp(dir, 'h_row12'), fig.Pointer = 'top';
        elseif strcmp(dir, 'v_col12')
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

        % Right-click: let context menu handle it — do not start zoom/drag
        if strcmp(fig.SelectionType, 'alt')
            return;
        end

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
    %ONFIGSIZECHANGED  Enforce minimum size and adapt layout for small screens.
        fig.SizeChangedFcn = '';          % disable to avoid recursion
        pos = fig.Position;
        changed = false;
        if pos(4) < MIN_FIG_H
            pos(4) = MIN_FIG_H;
            changed = true;
        end
        if pos(3) < 600
            pos(3) = 600;
            changed = true;
        end
        if changed
            fig.Position = pos;
        end
        % On very short windows protect the preview; otherwise let analysis flex.
        if pos(4) < 700
            rootGL.RowHeight = {'3x', '2x', 16};
        else
            rootGL.RowHeight = {'1x', '1x', 16};
        end

        % ── Adapt content columns for narrow windows ──
        % On narrow screens, shrink file list and controls so preview is not crushed.
        % On wide screens, respect persisted or default widths.
        figW = pos(3);
        defFileW = LAYOUT_DEFAULTS.fileListW;
        defCtrlW = LAYOUT_DEFAULTS.ctrlPanelW;
        if figW < 800
            contentGL.ColumnWidth = {min(140, defFileW), min(160, defCtrlW), '1x'};
        elseif figW < 1000
            contentGL.ColumnWidth = {min(160, defFileW), min(175, defCtrlW), '1x'};
        end
        % (Wide windows keep whatever width the user or prefs last set.)

        % ── Adapt analysis columns for narrow windows ──
        defCorrW = LAYOUT_DEFAULTS.corrPanelW;
        if figW < 900
            analysisGL.ColumnWidth = {min(260, defCorrW), '1x', 0, 0};
        elseif figW < 1100
            analysisGL.ColumnWidth = {min(280, defCorrW), '1x', 180, 0};
        end

        fig.SizeChangedFcn = @onFigSizeChanged;
    end

    function onFigureClose(~,~)
    %ONFIGURECLOSE  Clean up resources before closing the GUI figure.
        % Stop and delete animation timer if running
        if isprop(appData, 'animTimer') && ~isempty(appData.animTimer)
            if isvalid(appData.animTimer)
                stop(appData.animTimer);
                delete(appData.animTimer);
            end
            appData.animTimer = [];
        end
        % Close the peak analysis window if it exists
        if isvalid(peakFig), delete(peakFig); end
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

            case 'm'
                if hasCtrl, onUnmaskAll([], []); end

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
        isFigFormat = strcmp(fmtStr, 'MATLAB .fig');
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
            case 'MATLAB .fig'
                ext      = '.fig';
                fmtFilter = {'*.fig','MATLAB figure (*.fig)'};
                egOpts   = {};
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

        % Use custom figure dimensions from efFigWidth/efFigHeight (#7)
        figW = efFigWidth.Value;
        figH = efFigHeight.Value;

        % Render into a hidden figure
        tmpFig = figure('Visible','off','Name','SaveFig','NumberTitle','off', ...
                        'MenuBar','none','ToolBar','none', ...
                        'Units','inches','Position',[0 0 figW figH]);
        tmpAx = axes(tmpFig);
        box(tmpAx,'on');
        grid(tmpAx,'on');
        drawToAxes(tmpAx);
        styleAxesForExport(tmpAx);
        try
            if isFigFormat
                savefig(tmpFig, outPath);  % #20: MATLAB .fig format
            else
                exportgraphics(tmpFig, outPath, egOpts{:});
            end
            delete(tmpFig);
            uialert(fig, sprintf('Saved:\n%s', outPath), 'Figure Saved');
        catch ME
            delete(tmpFig);
            logGUIError('Save error (exportgraphics)', ME.message, ME);
            uialert(fig, sprintf('Export failed:\n%s', ME.message), 'Save error');
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
        savedMap2DCmap = ddMap2DCmap.Value;
        savedXSel      = ddX.Value;
        savedYSel      = ensureCell(lbY.Value);
        savedY2Sel     = ensureCell(lbY2.Value);
        savedLogX      = strcmp(ddScaleX.Value, 'Log');
        savedLogY      = strcmp(ddScaleY.Value, 'Log');
        savedBGInterp  = ddBGInterp.Value;

        setStatus('Saving session...');
        fig.Pointer = 'watch';
        drawnow;
        try
            save(outPath, 'savedDatasets', 'savedActiveIdx', ...
                          'savedBgFile', 'savedBgDataset', ...
                          'savedStyle', 'savedLastDir', ...
                          'savedColormap', 'savedMap2DCmap', ...
                          'savedXSel', ...
                          'savedYSel', 'savedY2Sel', ...
                          'savedLogX', 'savedLogY', ...
                          'savedBGInterp', ...
                          '-v7.3');
            fig.Pointer = 'arrow';
            setStatus(sprintf('Session saved: %s', fname));
            uialert(fig, sprintf('Session saved:\n%s', outPath), 'Session Saved');
        catch ME
            fig.Pointer = 'arrow';
            setStatus('Session save failed.');
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

        setStatus('Loading session...');
        fig.Pointer = 'watch';
        drawnow;

        try
            S = load(matPath, '-mat');
        catch ME
            fig.Pointer = 'arrow';
            setStatus('Session load failed.');
            logGUIError('Load Error', ME.message, ME);
            uialert(fig, sprintf('Could not load file:\n%s', ME.message), 'Load Error');
            return;
        end

        % Validate required field
        if ~isfield(S, 'savedDatasets')
            fig.Pointer = 'arrow';
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
            warning('DataPlotter:legacySession', ...
                ['%d dataset(s) in this session were imported before parser versioning was introduced.\n' ...
                 'Data should load correctly; re-import files to attach version metadata.'], nLegacy);
        end

        % Backward-compat: ensure all expected fields exist for old sessions (#14)
        sessionDefaults = struct( ...
            'snipBackground', struct('x', [], 'bg', []), ...
            'derivativeMode', 'None', ...
            'refLines', {{}}, ...
            'undoStack', {{}}, ...
            'normMethod', 'None', ...
            'xTrimMin', NaN, ...
            'xTrimMax', NaN, ...
            'legendName', '', ...
            'legendNameR', '', ...
            'color', [], ...
            'colorR', [], ...
            'annotations', {{}}, ...
            'visible', true);
        fnames = fieldnames(sessionDefaults);
        for di = 1:numel(appData.datasets)
            for fi = 1:numel(fnames)
                if ~isfield(appData.datasets{di}, fnames{fi})
                    appData.datasets{di}.(fnames{fi}) = sessionDefaults.(fnames{fi});
                end
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
        if isfield(S,'savedMap2DCmap') && ismember(S.savedMap2DCmap, ddMap2DCmap.Items)
            ddMap2DCmap.Value = S.savedMap2DCmap;
        end
        if isfield(S,'savedLogX'), if S.savedLogX, ddScaleX.Value = 'Log'; else, ddScaleX.Value = 'Linear'; end, end
        if isfield(S,'savedLogY'), if S.savedLogY, ddScaleY.Value = 'Log'; else, ddScaleY.Value = 'Linear'; end, end
        if isfield(S,'savedBGInterp') && ismember(S.savedBGInterp, ddBGInterp.Items)
            ddBGInterp.Value = S.savedBGInterp;
        end

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
        fig.Pointer = 'arrow';
        setStatus(sprintf('Session loaded: %d dataset(s)', numel(appData.datasets)));
        uialert(fig, sprintf('Session loaded: %d dataset(s)', numel(appData.datasets)), ...
            'Session Loaded');
    end

    % ── Panel drag-resize ────────────────────────────────────────────────

    function dir = detectResizeBorder()
    %DETECTRESIZEBORDER  Check whether fig.CurrentPoint is within SNAP_PX of a
    %  resizable panel border.  Returns:
    %    'h_row12' — horizontal border between content row (1) and analysis row (2)
    %    'v_col12' — vertical border between corrections col (1) and axis-limits col (2)
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
                appData.panelResizeOrig = guiTernary(isnumeric(rh{2}), rh{2}, 300);
            end
        elseif strcmp(appData.panelResizeDir, 'v_col12')
            % Snapshot the current corrections panel width (px)
            try
                cPos = getpixelposition(corrPanel, true);
                appData.panelResizeOrig = cPos(3);
            catch
                appData.panelResizeOrig = appData.corrPanelWidth;
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
            % Available px after padding + RowSpacing gaps + status bar
            %   rootGL: Padding [6 6 6 6] → 12 px;  2 RowSpacing gaps of 4 → 8 px;
            %   status bar 16 px
            availH  = figH - 12 - 8 - 16;
            newH    = round(appData.panelResizeOrig + delta_y);
            newH    = max(appData.MIN_ANALYSIS_H, min(newH, availH - appData.MIN_PREVIEW_H));
            rootGL.RowHeight = {'1x', newH, 16};

        elseif strcmp(appData.panelResizeDir, 'v_col12')
            % Mouse moves right → corrections panel gets wider
            delta_x = mp(1) - appData.panelResizeStart(1);
            newW    = round(appData.panelResizeOrig + delta_x);
            newW    = max(appData.MIN_CORR_W, min(newW, 600));
            appData.corrPanelWidth = newW;
            cw    = analysisGL.ColumnWidth;
            cw{1} = newW;
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

    function toggleWfGradient()
    %TOGGLEWFGRADIENT  Toggle waterfall gradient coloring on/off.
        appData.wfGradient = ~appData.wfGradient;
        if appData.wfGradient
            setStatus('Waterfall gradient: ON (blue→red by dataset position)');
        else
            setStatus('Waterfall gradient: OFF');
        end
        onPlot([],[]);
    end

    function onWaterfallToggled()
    %ONWATERFALLTOGGLED  When waterfall is checked, seed the spacing field
    %  with the auto-computed value so users have a sensible starting point.
        if cbWaterfall.Value && isempty(strtrim(efWaterfallSpacing.Value))
            autoSp = computeAutoWaterfallSpacing();
            efWaterfallSpacing.Value = sprintf('%.4g', autoSp);
        end
        onPlot([],[]);
    end

    function s = computeAutoWaterfallSpacing()
    %COMPUTEAUTOWATERFALLSPACING  Return spacing for automatic waterfall.
    %  Linear mode: 1.1× the maximum data range (additive offset).
    %  Log mode:    10^(1.1 × max log-range) as a multiplicative factor.
    %  SIMS single-file: scan across all selected channels, not datasets.
        ySel = ensureCell(lbY.Value);
        nDS2 = numel(appData.datasets);

        % Detect SIMS single-file → scan all selected channels
        isSIMSSingle = (nDS2 == 1) && ...
            isfield(appData.datasets{1},'parserName') && ...
            strcmp(appData.datasets{1}.parserName,'importSIMS') && ...
            numel(ySel) > 1;

        if strcmp(ddScaleY.Value, 'Log')
            % Log mode — return a multiplier (ratio between adjacent traces)
            s = 10;   % safe fallback: one decade
            if isempty(ySel), return; end
            maxLogRange = 0;
            if isSIMSSingle
                ds2      = appData.datasets{1};
                primaryD = guiTernary(~isempty(ds2.corrData), ds2.corrData, ds2.data);
                dm2      = buildDisplayMask(ds2);
                for ci = 1:numel(ySel)
                    idx2 = find(strcmp(primaryD.labels, ySel{ci}), 1);
                    if isempty(idx2), continue; end
                    yVals = primaryD.values(:, idx2);
                    yVals = yVals(yVals > 0 & ~isnan(yVals) & dm2);
                    if numel(yVals) < 2, continue; end
                    r = log10(max(yVals)) - log10(min(yVals));
                    if r > maxLogRange, maxLogRange = r; end
                end
            else
                for ddi = 1:nDS2
                    ds2      = appData.datasets{ddi};
                    primaryD = guiTernary(~isempty(ds2.corrData), ds2.corrData, ds2.data);
                    idx2     = find(strcmp(primaryD.labels, ySel{1}), 1);
                    if isempty(idx2), continue; end
                    yVals = primaryD.values(:, idx2);
                    dm2 = buildDisplayMask(ds2);
                    yVals = yVals(yVals > 0 & ~isnan(yVals) & dm2);
                    if numel(yVals) < 2, continue; end
                    r = log10(max(yVals)) - log10(min(yVals));
                    if r > maxLogRange, maxLogRange = r; end
                end
            end
            if maxLogRange > 0, s = 10^(maxLogRange * 1.1); end
        else
            % Linear mode — return an additive offset
            s = 1;   % safe fallback if no data range can be determined
            if isempty(ySel), return; end
            maxRange = 0;
            if isSIMSSingle
                ds2      = appData.datasets{1};
                primaryD = guiTernary(~isempty(ds2.corrData), ds2.corrData, ds2.data);
                dm2      = buildDisplayMask(ds2);
                for ci = 1:numel(ySel)
                    idx2 = find(strcmp(primaryD.labels, ySel{ci}), 1);
                    if isempty(idx2), continue; end
                    yVals = primaryD.values(:, idx2);
                    yVals = yVals(~isnan(yVals) & dm2);
                    if numel(yVals) < 2, continue; end
                    r = max(yVals) - min(yVals);
                    if r > maxRange, maxRange = r; end
                end
            else
                for ddi = 1:nDS2
                    ds2      = appData.datasets{ddi};
                    primaryD = guiTernary(~isempty(ds2.corrData), ds2.corrData, ds2.data);
                    idx2     = find(strcmp(primaryD.labels, ySel{1}), 1);
                    if isempty(idx2), continue; end
                    yVals = primaryD.values(:, idx2);
                    dm2 = buildDisplayMask(ds2);
                    yVals = yVals(~isnan(yVals) & dm2);
                    if numel(yVals) < 2, continue; end
                    r = max(yVals) - min(yVals);
                    if r > maxRange, maxRange = r; end
                end
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
            fprintf(fid, '\n%s\n', repmat('=', 1, 68));
            fprintf(fid, '[%s]  %s\n', stamp, title);
            fprintf(fid, 'Message: %s\n', msg);
            if ~isempty(ME)
                if ~isempty(ME.identifier)
                    fprintf(fid, 'Identifier: %s\n', ME.identifier);
                end
                if ~isempty(ME.stack)
                    fprintf(fid, 'Stack:\n');
                    for si = 1:numel(ME.stack)
                        fprintf(fid, '  %s  (line %d)\n', ...
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
    % ════════════════════════════════════════════════════════════════════
    %  NEW FEATURE CALLBACKS (added 2026-03-14)
    % ════════════════════════════════════════════════════════════════════

    function onDuplicateDataset(~,~)
    %ONDUPLICATEDATASET  Deep-copy the active dataset for side-by-side comparison (#9).
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};
        dsCopy = ds;
        dsCopy.corrData = [];  % start fresh corrections on the copy
        dsCopy.undoState = struct();
        dsCopy.undoStack = {};
        [~, fn, fext] = fileparts(ds.filepath);
        dsCopy.displayName = [fn fext ' (copy)'];
        dsCopy.legendName  = [fn fext ' (copy)'];
        appData.datasets{end+1} = dsCopy;
        appData.activeIdx = numel(appData.datasets);
        rebuildDatasetList(true);
        updateControlsForActiveDataset();
        onPlot([],[]);
    end

    function onAddHRefLine(~,~)
    %ONADDHREFLINE  Add a horizontal reference line at a user-specified Y value (#11).
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        answer = inputdlg('Y value for horizontal line:', 'H Reference Line', [1 40], {'0'});
        if isempty(answer), return; end
        val = str2double(answer{1});
        if isnan(val), uialert(fig, 'Invalid number.', 'Error'); return; end
        ds = appData.datasets{appData.activeIdx};
        if ~isfield(ds, 'refLines'), ds.refLines = {}; end
        ds.refLines{end+1} = struct('orientation','horizontal','value',val, ...
            'color',[0.5 0.5 0.5],'style','--');
        appData.datasets{appData.activeIdx} = ds;
        onPlot([],[]);
    end

    function onAddVRefLine(~,~)
    %ONADDVREFLINE  Add a vertical reference line at a user-specified X value (#11).
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        answer = inputdlg('X value for vertical line:', 'V Reference Line', [1 40], {'0'});
        if isempty(answer), return; end
        val = str2double(answer{1});
        if isnan(val), uialert(fig, 'Invalid number.', 'Error'); return; end
        ds = appData.datasets{appData.activeIdx};
        if ~isfield(ds, 'refLines'), ds.refLines = {}; end
        ds.refLines{end+1} = struct('orientation','vertical','value',val, ...
            'color',[0.5 0.5 0.5],'style','--');
        appData.datasets{appData.activeIdx} = ds;
        onPlot([],[]);
    end

    function onClearRefLines(~,~)
    %ONCLEARREFLINES  Remove all reference lines from the active dataset (#11).
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds = appData.datasets{appData.activeIdx};
        ds.refLines = {};
        appData.datasets{appData.activeIdx} = ds;
        onPlot([],[]);
    end

    function onCopyPeaksToClipboard(~,~)
    %ONCOPYPEAKSTOCLIPBOARD  Copy peak table as tab-delimited text to clipboard (#10).
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};
        if isempty(ds.peaks)
            uialert(fig,'No peaks to copy.','No peaks'); return;
        end
        hdr = {'#','Center','d(A)','Size(nm)','FWHM','Height','Area','eta','Status'};
        lines = {strjoin(hdr, char(9))};
        for pi = 1:numel(ds.peaks)
            pk = ds.peaks(pi);
            dStr  = guiTernary(isfield(pk,'dSpacing') && ~isnan(pk.dSpacing), sprintf('%.4f',pk.dSpacing), '');
            szStr = guiTernary(isfield(pk,'crystSize') && ~isnan(pk.crystSize), sprintf('%.1f',pk.crystSize), '');
            areaStr = guiTernary(isfield(pk,'area') && ~isnan(pk.area), sprintf('%.4g',pk.area), '');
            etaStr  = guiTernary(isfield(pk,'eta') && ~isnan(pk.eta), sprintf('%.3f',pk.eta), '');
            row = sprintf('%d\t%.4f\t%s\t%s\t%.4f\t%.4g\t%s\t%s\t%s', ...
                pi, pk.center, dStr, szStr, pk.fwhm, pk.height, areaStr, etaStr, pk.status);
            lines{end+1} = row; %#ok<AGROW>
        end
        clipboard('copy', strjoin(lines, newline));
        setStatus(sprintf('Copied %d peak(s) to clipboard.', numel(ds.peaks)));
    end

    function onEstimateBaseline(~,~)
    %ONESTIMATEBASELINE  Estimate and subtract baseline via SNIP algorithm (#5).
    %  Uses utilities.estimateBackground (peak-clipping) to compute a baseline,
    %  then subtracts it from all Y channels. The baseline is stored as a new
    %  dataset for visual comparison. Works best on XRD data with sharp peaks.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};
        d = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        if isdatetime(d.time)
            uialert(fig,'Baseline estimation requires numeric x-axes.','Error'); return;
        end
        % Ask for max window parameter
        answer = inputdlg({'Max window (x-axis units):', 'Smooth passes:'}, ...
            'SNIP Baseline Estimation', [1 40], {'2.0', '3'});
        if isempty(answer), return; end
        maxWin = str2double(answer{1});
        smoothP = round(str2double(answer{2}));
        if isnan(maxWin) || isnan(smoothP) || maxWin <= 0
            uialert(fig,'Invalid parameters.','Error'); return;
        end
        xVec = double(d.time);
        bgAll = zeros(size(d.values));
        for k = 1:size(d.values, 2)
            bgAll(:, k) = utilities.estimateBackground(xVec, d.values(:, k), ...
                'MaxWindowDeg', maxWin, 'SmoothPasses', smoothP);
        end
        % Subtract baseline and store as corrected data
        if isempty(ds.corrData)
            ds.corrData = d;
        end
        ds.corrData.values = d.values - bgAll;
        appData.datasets{appData.activeIdx} = ds;
        % Also add the baseline as a separate dataset for visual comparison
        bgData = d;
        bgData.values = bgAll;
        bgData.labels = cellfun(@(lbl) ['BG: ' lbl], d.labels, 'UniformOutput', false);
        dsNew = buildDs(ds.filepath, bgData, 'baseline');
        [~, fn, fext] = fileparts(ds.filepath);
        dsNew.displayName = [fn fext ' (baseline)'];
        dsNew.legendName  = [fn fext ' (baseline)'];
        appData.datasets{end+1} = dsNew;
        rebuildDatasetList(true);
        onPlot([],[]);
        setStatus(sprintf('Baseline subtracted (SNIP, window=%.1f).', maxWin));
    end

    function onResampleDataset(~,~)
    %ONRESAMPLEDATASET  Resample active dataset to a uniform x-grid (#15).
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};
        d = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        if isdatetime(d.time)
            uialert(fig,'Cannot resample datetime x-axes.','Error'); return;
        end
        xVec = double(d.time);
        xLo = min(xVec); xHi = max(xVec);
        nPts = numel(xVec);
        answer = inputdlg({'X min:', 'X max:', 'Number of points:'}, ...
            'Resample Dataset', [1 40], {num2str(xLo), num2str(xHi), num2str(nPts)});
        if isempty(answer), return; end
        newXMin = str2double(answer{1}); newXMax = str2double(answer{2});
        newN    = round(str2double(answer{3}));
        if isnan(newXMin) || isnan(newXMax) || isnan(newN) || newN < 2
            uialert(fig,'Invalid parameters.','Error'); return;
        end
        newX = linspace(newXMin, newXMax, newN)';
        newVals = zeros(newN, size(d.values, 2));
        for k = 1:size(d.values, 2)
            newVals(:, k) = interp1(xVec, d.values(:, k), newX, 'pchip', NaN);
        end
        resD = d;
        resD.time   = newX;
        resD.values = newVals;
        dsNew = buildDs(ds.filepath, resD, 'resampled');
        [~, fn, fext] = fileparts(ds.filepath);
        dsNew.displayName = [fn fext ' (resampled)'];
        dsNew.legendName  = [fn fext ' (resampled)'];
        appData.datasets{end+1} = dsNew;
        appData.activeIdx = numel(appData.datasets);
        rebuildDatasetList(true);
        updateControlsForActiveDataset();
        onPlot([],[]);
    end

    function onColumnCalculator(~,~)
    %ONCOLUMNCALCULATOR  Per-dataset column math dialog (#16).
    %  Creates a new Y column from an expression using existing column names.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};
        d = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        colInfo = cell(1, numel(d.labels));
        for ci = 1:numel(d.labels)
            colInfo{ci} = sprintf('  C%d = %s', ci, d.labels{ci});
        end
        prompt = sprintf(['Create a new column from existing columns.\n\n' ...
                          'Available columns:\n%s\n\n' ...
                          'Use C1, C2, ... to reference columns.\n' ...
                          'Examples: C1./C2,  log10(C1),  C1*1e3'], ...
                          strjoin(colInfo, '\n'));
        answer = inputdlg({prompt, 'New column name:'}, ...
            'Column Calculator', [1 60; 1 40], {'C1 ./ C2', 'Derived'});
        if isempty(answer), return; end
        expr = strtrim(answer{1});
        colName = strtrim(answer{2});
        if isempty(expr) || isempty(colName), return; end
        try
            % Build column variables
            colVars = struct();
            for ci = 1:numel(d.labels)
                colVars.(sprintf('C%d', ci)) = d.values(:, ci);
            end
            % Evaluate via safe recursive-descent parser (no eval)
            yResult = safeEvalMathExpr(expr, colVars);
            if ~isnumeric(yResult) || numel(yResult) ~= size(d.values, 1)
                error('Result must be a vector with %d elements.', size(d.values, 1));
            end
            % Append new column
            d.values = [d.values, yResult(:)];
            d.labels{end+1} = colName;
            d.units{end+1}  = '';
            if ~isempty(ds.corrData)
                ds.corrData = d;
            else
                ds.data = d;
            end
            appData.datasets{appData.activeIdx} = ds;
            updateControlsForActiveDataset();
            onPlot([],[]);
            setStatus(sprintf('Added column "%s".', colName));
        catch ME
            uialert(fig, sprintf('Expression error:\n%s', ME.message), 'Column Calculator Error');
        end
    end

    function onCreateInset(~,~)
    %ONCREATEINSET  Create an inset axes showing a zoomed region (#18).
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load a file first.','No data'); return;
        end
        answer = inputdlg({'X min:', 'X max:', 'Y min:', 'Y max:'}, ...
            'Inset Region', [1 40], ...
            {num2str(ax.XLim(1)), num2str(ax.XLim(2)), ...
             num2str(ax.YLim(1)), num2str(ax.YLim(2))});
        if isempty(answer), return; end
        xLo = str2double(answer{1}); xHi = str2double(answer{2});
        yLo = str2double(answer{3}); yHi = str2double(answer{4});
        if any(isnan([xLo xHi yLo yHi])), return; end

        % Create inset axes in top-right corner of the main axes
        axPos = getpixelposition(ax, true);
        insetW = axPos(3) * 0.35;
        insetH = axPos(4) * 0.35;
        insetPos = [axPos(1)+axPos(3)-insetW-20, axPos(2)+axPos(4)-insetH-20, insetW, insetH];
        if isprop(appData, 'insetAx') && ~isempty(appData.insetAx) && isvalid(appData.insetAx)
            delete(appData.insetAx);
        end
        insetAx = axes(fig, 'Units', 'pixels', 'Position', insetPos);
        box(insetAx, 'on'); grid(insetAx, 'on');
        insetAx.FontSize = 8;
        drawToAxes(insetAx);
        insetAx.XLim = [xLo xHi];
        insetAx.YLim = [yLo yHi];
        legend(insetAx, 'off');
        title(insetAx, '');
        xlabel(insetAx, ''); ylabel(insetAx, '');
        appData.insetAx = insetAx;
    end

    % ── Interactive Data Cursor ────────────────────────────────────────

    function onToggleDataCursor(~,~)
    %ONTOGGLEDATACURSOR  Toggle interactive data cursor mode.
    %  Click on plot to snap to nearest data point and show (x,y).
    %  Click a second point to show delta.  Click button again to exit.
        if ~isprop(appData, 'cursorActive'), appData.cursorActive = false; end
        if appData.cursorActive
            % Deactivate cursor
            appData.cursorActive = false;
            btnDataCursor.BackgroundColor = BTN_TOOL;
            fig.WindowButtonDownFcn = @onAxesButtonDown;
            % Remove cursor graphics
            if isprop(appData, 'cursorMarker') && isvalid(appData.cursorMarker)
                delete(appData.cursorMarker);
            end
            if isprop(appData, 'cursorLabel') && isvalid(appData.cursorLabel)
                delete(appData.cursorLabel);
            end
            if isprop(appData, 'cursorMarker2') && isvalid(appData.cursorMarker2)
                delete(appData.cursorMarker2);
            end
            if isprop(appData, 'cursorDeltaLabel') && isvalid(appData.cursorDeltaLabel)
                delete(appData.cursorDeltaLabel);
            end
            if isprop(appData, 'cursorLine') && isvalid(appData.cursorLine)
                delete(appData.cursorLine);
            end
            appData.cursorClickCount = 0;
            setStatus('Cursor off.');
        else
            if isempty(appData.datasets) || appData.activeIdx < 1
                uialert(fig,'Load a file first.','No data'); return;
            end
            appData.cursorActive = true;
            appData.cursorClickCount = 0;
            btnDataCursor.BackgroundColor = BTN_PRIMARY;
            fig.WindowButtonDownFcn = @onCursorClick;
            setStatus('Cursor ON — click on plot to read values. Click again for delta.');
        end
    end

    function onCursorClick(~,~)
    %ONCURSORCLICK  Handle click in data cursor mode.
        if ~appData.cursorActive, return; end
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end

        % Get click position in axes coordinates
        cp = ax.CurrentPoint;
        xClick = cp(1,1);
        yClick = cp(1,2);

        % Check if click is within axes limits
        xl = ax.XLim; yl = ax.YLim;
        if xClick < xl(1) || xClick > xl(2) || yClick < yl(1) || yClick > yl(2)
            return;
        end

        % Get active dataset
        d = getPlotData(appData.activeIdx);
        if isempty(d) || isempty(d.time), return; end

        xData = double(d.time);
        yData = d.values;
        if isempty(yData), return; end

        % Find nearest point (use first visible Y channel)
        yCol = yData(:, 1);
        % Normalize distances to axes range for fair comparison
        xRange = diff(xl); yRange = diff(yl);
        if xRange == 0, xRange = 1; end
        if yRange == 0, yRange = 1; end
        dist = ((xData - xClick) / xRange).^2 + ((yCol - yClick) / yRange).^2;
        [~, idx] = min(dist);
        xSnap = xData(idx);
        ySnap = yCol(idx);

        appData.cursorClickCount = appData.cursorClickCount + 1;

        if appData.cursorClickCount == 1
            % First click: show point
            if isprop(appData, 'cursorMarker') && isvalid(appData.cursorMarker)
                delete(appData.cursorMarker);
            end
            if isprop(appData, 'cursorLabel') && isvalid(appData.cursorLabel)
                delete(appData.cursorLabel);
            end
            % Clean up any previous second-click graphics
            if isprop(appData, 'cursorMarker2') && isvalid(appData.cursorMarker2)
                delete(appData.cursorMarker2);
            end
            if isprop(appData, 'cursorDeltaLabel') && isvalid(appData.cursorDeltaLabel)
                delete(appData.cursorDeltaLabel);
            end
            if isprop(appData, 'cursorLine') && isvalid(appData.cursorLine)
                delete(appData.cursorLine);
            end

            hold(ax, 'on');
            appData.cursorMarker = plot(ax, xSnap, ySnap, 'ro', ...
                'MarkerSize', 10, 'LineWidth', 2, 'HandleVisibility', 'off');
            lbl = sprintf('(%.6g, %.6g)', xSnap, ySnap);
            appData.cursorLabel = text(ax, xSnap, ySnap, ['  ' lbl], ...
                'FontSize', 9, 'Color', [0.8 0 0], 'FontWeight', 'bold', ...
                'BackgroundColor', [1 1 1 0.85], 'EdgeColor', [0.7 0.7 0.7], ...
                'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');

            appData.cursorPt1 = [xSnap, ySnap];
            setStatus(sprintf('Point 1: x = %.6g, y = %.6g  —  click again for delta', xSnap, ySnap));

        elseif appData.cursorClickCount == 2
            % Second click: show delta
            hold(ax, 'on');
            appData.cursorMarker2 = plot(ax, xSnap, ySnap, 'bs', ...
                'MarkerSize', 10, 'LineWidth', 2, 'HandleVisibility', 'off');

            dx = xSnap - appData.cursorPt1(1);
            dy = ySnap - appData.cursorPt1(2);
            lbl = sprintf('(%.6g, %.6g)\n\\Delta x=%.6g  \\Delta y=%.6g', xSnap, ySnap, dx, dy);
            appData.cursorDeltaLabel = text(ax, xSnap, ySnap, ['  ' lbl], ...
                'FontSize', 9, 'Color', [0 0 0.8], 'FontWeight', 'bold', ...
                'BackgroundColor', [1 1 1 0.85], 'EdgeColor', [0.5 0.5 0.8], ...
                'VerticalAlignment', 'top', 'HandleVisibility', 'off');

            % Draw connecting line
            appData.cursorLine = plot(ax, ...
                [appData.cursorPt1(1), xSnap], [appData.cursorPt1(2), ySnap], ...
                '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.75, ...
                'HandleVisibility', 'off');

            setStatus(sprintf('Delta: dx = %.6g, dy = %.6g', dx, dy));
            appData.cursorClickCount = 0;  % reset for next pair
        end
    end

    % ── Dataset Algebra ────────────────────────────────────────────────

    function onDatasetAlgebra(~,~)
    %ONDATASETALGEBRA  Open dialog to combine two datasets arithmetically.
        if isempty(appData.datasets) || numel(appData.datasets) < 2
            uialert(fig, 'Load at least two files to use dataset math.', 'Need 2+ datasets');
            return;
        end
        nDS = numel(appData.datasets);
        dsNames = cell(1, nDS);
        for ii = 1:nDS
            [~, fn, fx] = fileparts(appData.datasets{ii}.filepath);
            dsNames{ii} = [fn, fx];
        end

        % Build dialog
        mathFig = uifigure('Name', 'Dataset Math', 'Position', [350 300 420 280], 'Resize', 'off');
        mGL = uigridlayout(mathFig, [7 2], ...
            'RowHeight', {22, 22, 22, 22, 22, 22, 30}, ...
            'ColumnWidth', {110, '1x'}, ...
            'Padding', [10 10 10 10], 'RowSpacing', 6);

        uilabel(mGL, 'Text', 'Dataset A:', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
        ddMathA = uidropdown(mGL, 'Items', dsNames, 'ItemsData', 1:nDS, ...
            'Value', min(1, nDS));

        uilabel(mGL, 'Text', 'Channel A:', 'HorizontalAlignment', 'right');
        ddMathChA = uidropdown(mGL, 'Items', appData.datasets{1}.data.labels, ...
            'ItemsData', 1:numel(appData.datasets{1}.data.labels), 'Value', 1);

        uilabel(mGL, 'Text', 'Dataset B:', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
        ddMathB = uidropdown(mGL, 'Items', dsNames, 'ItemsData', 1:nDS, ...
            'Value', min(2, nDS));

        uilabel(mGL, 'Text', 'Channel B:', 'HorizontalAlignment', 'right');
        ddMathChB = uidropdown(mGL, 'Items', appData.datasets{min(2,nDS)}.data.labels, ...
            'ItemsData', 1:numel(appData.datasets{min(2,nDS)}.data.labels), 'Value', 1);

        uilabel(mGL, 'Text', 'Operation:', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
        ddMathOp = uidropdown(mGL, 'Items', {'A-B', 'A+B', 'A/B', 'A*B', '(A-B)/(A+B)'}, ...
            'Value', 'A-B');

        uilabel(mGL, 'Text', 'Interpolation:', 'HorizontalAlignment', 'right');
        ddMathInterp = uidropdown(mGL, 'Items', {'pchip', 'linear', 'spline'}, 'Value', 'pchip');

        % Update channel lists when dataset selection changes
        ddMathA.ValueChangedFcn = @(~,~) set(ddMathChA, ...
            'Items', appData.datasets{ddMathA.Value}.data.labels, ...
            'ItemsData', 1:numel(appData.datasets{ddMathA.Value}.data.labels), 'Value', 1);
        ddMathB.ValueChangedFcn = @(~,~) set(ddMathChB, ...
            'Items', appData.datasets{ddMathB.Value}.data.labels, ...
            'ItemsData', 1:numel(appData.datasets{ddMathB.Value}.data.labels), 'Value', 1);

        btnGL = uigridlayout(mGL, [1 2], 'ColumnWidth', {'1x', '1x'}, ...
            'Padding', [0 0 0 0], 'ColumnSpacing', 8);
        btnGL.Layout.Row = 7; btnGL.Layout.Column = [1 2];

        uibutton(btnGL, 'Text', 'Compute', ...
            'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
            'FontWeight', 'bold', ...
            'ButtonPushedFcn', @(~,~) doMathCompute());
        uibutton(btnGL, 'Text', 'Cancel', ...
            'ButtonPushedFcn', @(~,~) delete(mathFig));

        function doMathCompute()
            try
                idxA = ddMathA.Value;  idxB = ddMathB.Value;
                dsA = getPlotData(idxA);
                dsB = getPlotData(idxB);
                result = utilities.datasetAlgebra(dsA, dsB, ddMathOp.Value, ...
                    'ChannelA', ddMathChA.Value, 'ChannelB', ddMathChB.Value, ...
                    'InterpMethod', ddMathInterp.Value);

                % Add result as a new virtual dataset
                newDS = struct();
                newDS.data     = result;
                newDS.corrData = [];
                newDS.filepath = sprintf('[Math: %s %s %s]', dsNames{idxA}, ddMathOp.Value, dsNames{idxB});
                newDS.xOff = 0; newDS.yOff = 0;
                newDS.bgSlope = 0; newDS.bgInt = 0;
                newDS.smoothEnabled = false; newDS.smoothWindow = 5; newDS.smoothMethod = 'Moving';
                newDS.xTrimMin = NaN; newDS.xTrimMax = NaN;
                newDS.normMethod = 'None'; newDS.derivativeMode = 'None';
                newDS.peaks = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
                                     'fitCurve',{},'status',{},'dSpacing',{});
                newDS.axLims = struct('xMin','','xMax','','xStep','', ...
                                      'yMin','','yMax','','yStep','', ...
                                      'y2Min','','y2Max','','y2Step','');
                newDS.parserName = 'datasetAlgebra';

                appData.datasets{end+1} = newDS;
                appData.activeIdx = numel(appData.datasets);
                updateFileList();
                updateControlsForActiveDataset();
                onPlot([],[]);
                delete(mathFig);
                setStatus(sprintf('Math result added: %s', ddMathOp.Value));
            catch ME
                uialert(mathFig, ME.message, 'Math Error');
            end
        end
    end

    % ── Data Table Functions ─────────────────────────────────────────────

    % (Data table is always visible in the analysis panel — no toggle needed)

    function refreshDataTable()
    %REFRESHDATATABLE  Populate the table from the active dataset.
    %   Row 1 is an editable units row (green text). Rows 2+ are data.
    %   SIMS datasets with per-element original depths get paired
    %   Depth/Conc columns instead of a single shared X column.
        if appData.activeIdx < 1 || isempty(appData.datasets)
            tblData.ColumnName = {'(no data)'};
            tblData.Data = {};
            lblTableUnits.Text = '';
            lblTableStats.Text = '';
            return;
        end

        d = getPlotData(appData.activeIdx);
        ds2 = appData.datasets{appData.activeIdx};
        nRows = numel(d.time);

        % ── Detect SIMS per-element depth mode ────────────────────────
        isSIMSMultiDepth = false;
        if isfield(d.metadata, 'parserSpecific') ...
                && isfield(d.metadata.parserSpecific, 'originalDepths') ...
                && iscell(d.metadata.parserSpecific.originalDepths)
            origD = d.metadata.parserSpecific.originalDepths;
            origC = d.metadata.parserSpecific.originalConcentrations;
            if numel(origD) == size(d.values, 2) && numel(origD) > 1
                isSIMSMultiDepth = true;
            end
        end

        if isSIMSMultiDepth
            % ── SIMS paired columns: Depth_A | A | Depth_B | B | ... ──
            nElem = numel(origD);
            depthUnit = '';
            if isfield(d.metadata.parserSpecific, 'depthUnit')
                depthUnit = d.metadata.parserSpecific.depthUnit;
            end

            % Find max rows across all elements
            maxPts = max(cellfun(@numel, origD));

            % Build column names and units
            colNames = {};
            unitCells = {};
            for ei = 1:nElem
                colNames{end+1}  = ['Depth_' d.labels{ei}]; %#ok<AGROW>
                colNames{end+1}  = d.labels{ei}; %#ok<AGROW>
                unitCells{end+1} = depthUnit; %#ok<AGROW>
                if ei <= numel(d.units)
                    unitCells{end+1} = d.units{ei}; %#ok<AGROW>
                else
                    unitCells{end+1} = ''; %#ok<AGROW>
                end
            end
            colNames{end+1} = 'Masked';
            unitCells{end+1} = '';

            % Build data matrix with NaN padding
            nDataCols = nElem * 2;
            dataMat = NaN(maxPts, nDataCols);
            for ei = 1:nElem
                dVec = origD{ei}(:);
                cVec = origC{ei}(:);
                nPts = numel(dVec);
                dataMat(1:nPts, 2*ei-1) = dVec;
                dataMat(1:nPts, 2*ei)   = cVec;
            end

            % Store working copy (without mask column)
            appData.tableWorkingCopy = dataMat;
            appData.tableEdited = false;
            nRows = maxPts;

            % Initialize mask
            if isfield(ds2, 'mask') && numel(ds2.mask) == nRows
                appData.tableMask = ~ds2.mask;
            elseif isempty(appData.tableMask) || numel(appData.tableMask) ~= nRows
                appData.tableMask = false(nRows, 1);
            end

            % Build cell data: units row + data rows + mask column
            % ── Performance: cap displayed rows (full data in tableWorkingCopy) ──
            cap = min(nRows, appData.tableRowCap);
            unitsRow = [unitCells(1:end-1), {false}];
            dataRows = [num2cell(dataMat(1:cap, :)), num2cell(appData.tableMask(1:cap))];
            tableData = [unitsRow; dataRows];

            tblData.ColumnName = colNames;
            tblData.Data = tableData;
            tblData.ColumnEditable = true(1, nDataCols + 1);

        else
            % ── Standard layout: single X + Y channels ────────────────
            xName = 'X';
            if isfield(d.metadata, 'parserSpecific') && isfield(d.metadata.parserSpecific, 'xLabel')
                xName = d.metadata.parserSpecific.xLabel;
            end

            colNames = [{xName}, d.labels, {'Masked'}];
            nCols = size(d.values, 2);

            xCol = d.time(:);
            yMat = d.values;

            if isfield(ds2, 'mask') && numel(ds2.mask) == nRows
                appData.tableMask = ~ds2.mask;
            elseif isempty(appData.tableMask) || numel(appData.tableMask) ~= nRows
                appData.tableMask = false(nRows, 1);
            end

            appData.tableWorkingCopy = [xCol, yMat];
            appData.tableEdited = false;

            % Units row: X unit + Y units + mask placeholder
            xUnit = '';
            if isfield(d.metadata, 'xColumnUnit')
                xUnit = d.metadata.xColumnUnit;
            end
            unitCells = [{xUnit}, d.units, {''}];

            % Build cell data: units row (row 1) + data rows
            % ── Performance: cap displayed rows (full data in tableWorkingCopy) ──
            cap = min(nRows, appData.tableRowCap);
            unitsRow = [num2cell([NaN, NaN(1, nCols)]), {false}];
            % Fill units as strings in row 1
            for ui = 1:numel(unitCells)
                unitsRow{ui} = unitCells{ui};
            end
            dataRows = [num2cell([xCol(1:cap), yMat(1:cap, :)]), num2cell(appData.tableMask(1:cap))];
            tableData = [unitsRow; dataRows];

            tblData.ColumnName = colNames;
            tblData.Data = tableData;
            tblData.ColumnEditable = [true(1, 1 + nCols), true];
        end

        % Store units for editing and export
        appData.tableUnits = unitCells(1:end-1);  % exclude mask column

        % Update units label (summary)
        if ~isempty(d.units)
            lblTableUnits.Text = '  Row 1 = editable units (green)';
        else
            lblTableUnits.Text = '';
        end

        % Stats summary
        nMasked = sum(appData.tableMask);
        nDataCols2 = size(appData.tableWorkingCopy, 2);
        if nRows > appData.tableRowCap
            lblTableStats.Text = sprintf('Showing %d of %d rows, %d cols, %d masked  ', ...
                min(nRows, appData.tableRowCap), nRows, nDataCols2, nMasked);
        else
            lblTableStats.Text = sprintf('%d rows, %d cols, %d masked  ', ...
                nRows, nDataCols2, nMasked);
        end
    end

    function onTableCellEdit(~, evt)
    %ONTABLECELLEDIT  Handle cell edits in the data table.
    %   Row 1 is the units row (string edits update appData.tableUnits).
    %   Rows 2+ are data (numeric edits update appData.tableWorkingCopy).
        row = evt.Indices(1);
        col = evt.Indices(2);
        nDataCols = size(appData.tableWorkingCopy, 2);

        if row == 1 && col <= nDataCols
            % Units row edit — store updated unit string
            newVal = evt.NewData;
            if ischar(newVal) || isstring(newVal)
                appData.tableUnits{col} = char(newVal);
                appData.tableEdited = true;
            end
        elseif row >= 2 && col <= nDataCols
            % Data row edit (offset by 1 for units row)
            dataRow = row - 1;
            newVal = evt.NewData;
            if isnumeric(newVal)
                appData.tableWorkingCopy(dataRow, col) = newVal;
                appData.tableEdited = true;
            end
        elseif col == nDataCols + 1 && row >= 2
            % Mask column toggle (data rows only)
            dataRow = row - 1;
            appData.tableMask(dataRow) = logical(evt.NewData);
            nMasked = sum(appData.tableMask);
            nRows = size(appData.tableWorkingCopy, 1);
            lblTableStats.Text = sprintf('%d rows, %d cols, %d masked  ', ...
                nRows, nDataCols, nMasked);
            syncTableMaskToDataset();
        end
    end

    function onTableSelectionChanged(~, evt)
    %ONTABLESELECTIONCHANGED  Track selected cells for mask/sort operations.
    %   Stores selection in appData (compatible with all MATLAB versions).
        appData.tableSelection = evt.Indices;
    end

    function onTableMaskSelected(~, ~)
    %ONTABLEMASKSELECTED  Mask the currently selected rows in the table.
    %   Skips row 1 (units row). Data rows start at table row 2.
        sel = appData.tableSelection;
        if isempty(sel), return; end
        tableRows = unique(sel(:, 1));
        tableRows(tableRows < 2) = [];  % skip units row
        if isempty(tableRows), return; end
        dataRows = tableRows - 1;  % offset for units row
        appData.tableMask(dataRows) = true;
        % Update mask column in table display
        for ri = 1:numel(tableRows)
            tblData.Data{tableRows(ri), end} = true;
        end
        nMasked = sum(appData.tableMask);
        nRows = size(appData.tableWorkingCopy, 1);
        nCols = size(appData.tableWorkingCopy, 2);
        lblTableStats.Text = sprintf('%d rows, %d cols, %d masked  ', ...
            nRows, nCols, nMasked);
        syncTableMaskToDataset();
        setStatus(sprintf('Masked %d rows (%d total masked)', numel(dataRows), nMasked));
    end

    function onTableUnmaskAll(~, ~)
    %ONTABLEUNMASKALL  Clear all row masks.
        if isempty(appData.tableMask), return; end
        appData.tableMask(:) = false;
        refreshDataTable();
        syncTableMaskToDataset();
        setStatus('All masks cleared');
    end

    function syncTableMaskToDataset()
    %SYNCTABLEMASKTODATASET  Push table mask into ds.mask and re-plot.
    %   ds.mask uses inverted convention: true = included, false = excluded.
    %   appData.tableMask: true = masked (excluded).
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        nRaw = numel(ds.data.time);

        if isempty(appData.tableMask)
            ds.mask = true(nRaw, 1);
        else
            % tableMask may be sized to corrData; need to map back to raw
            if numel(appData.tableMask) == nRaw
                ds.mask = ~appData.tableMask;  % invert: table true=excluded → mask false=excluded
            else
                % Size mismatch (corrections changed row count) — apply to raw
                ds.mask = true(nRaw, 1);
                nM = min(numel(appData.tableMask), nRaw);
                ds.mask(1:nM) = ~appData.tableMask(1:nM);
            end
        end
        appData.datasets{appData.activeIdx} = ds;
        onPlot([], []);  % redraw with faded masked points
    end

    function onDescriptiveStats(~, ~)
    %ONDESCRIPTIVESTATS  Show per-column descriptive statistics popup.
        if isempty(appData.tableWorkingCopy)
            uialert(fig, 'No data loaded.', 'Stats');
            return;
        end
        d = getPlotData(appData.activeIdx);
        wc = appData.tableWorkingCopy;
        mask = appData.tableMask;
        if ~isempty(mask) && any(mask)
            wc = wc(~mask, :);  % exclude masked rows
        end
        colNames = [{'X'}, d.labels];
        nC = size(wc, 2);

        % Compute stats
        statNames = {'Mean', 'Std', 'Median', 'Min', 'Max', 'Skewness', 'Kurtosis', 'N'};
        statData = cell(numel(statNames), nC);
        for ci = 1:nC
            col = wc(:, ci);
            col = col(~isnan(col));
            if isempty(col)
                for si = 1:numel(statNames), statData{si, ci} = NaN; end
                continue;
            end
            statData{1, ci} = mean(col);
            statData{2, ci} = std(col);
            statData{3, ci} = median(col);
            statData{4, ci} = min(col);
            statData{5, ci} = max(col);
            % Skewness: E[(x-mu)^3] / sigma^3
            mu = mean(col); sg = std(col);
            if sg > 0
                statData{6, ci} = mean(((col - mu) / sg).^3);
                statData{7, ci} = mean(((col - mu) / sg).^4);
            else
                statData{6, ci} = 0;
                statData{7, ci} = 0;
            end
            statData{8, ci} = numel(col);
        end

        % Show in popup figure
        sFig = figure('Name', 'Descriptive Statistics', 'NumberTitle', 'off', ...
            'Units', 'pixels', 'Position', [300 200 max(400, nC*100) 300], ...
            'Tag', 'dpDescStats');
        sAx = axes(sFig, 'Visible', 'off');
        sAx.Position = [0 0 1 1];

        % Build formatted text
        lines = {};
        lines{end+1} = sprintf('%-12s', '');
        for ci = 1:nC
            lines{end} = [lines{end} sprintf('  %12s', colNames{ci})];
        end
        lines{end+1} = repmat('-', 1, 12 + nC*14);
        for si = 1:numel(statNames)
            line = sprintf('%-12s', statNames{si});
            for ci = 1:nC
                v = statData{si, ci};
                if si == 8
                    line = [line sprintf('  %12d', round(v))]; %#ok<AGROW>
                else
                    line = [line sprintf('  %12.4g', v)]; %#ok<AGROW>
                end
            end
            lines{end+1} = line; %#ok<AGROW>
        end

        text(sAx, 0.02, 0.95, strjoin(lines, '\n'), ...
            'FontName', 'Courier New', 'FontSize', 10, ...
            'VerticalAlignment', 'top', 'Units', 'normalized', ...
            'Interpreter', 'none');

        setStatus(sprintf('Stats: %d columns, %d rows (excl. %d masked)', ...
            nC, size(wc, 1), sum(appData.tableMask)));
    end

    function onTableSort(direction)
    %ONTABLESORT  Sort the data table by the selected column.
        if isempty(appData.tableWorkingCopy), return; end
        sel = appData.tableSelection;
        if isempty(sel)
            % Default: sort by first column (X)
            sortCol = 1;
        else
            sortCol = sel(1, 2);
        end
        nDataCols = size(appData.tableWorkingCopy, 2);
        if sortCol > nDataCols
            % Mask column selected — sort by X instead
            sortCol = 1;
        end
        [~, idx] = sort(appData.tableWorkingCopy(:, sortCol), direction);
        appData.tableWorkingCopy = appData.tableWorkingCopy(idx, :);
        appData.tableMask = appData.tableMask(idx);
        refreshDataTable();
        setStatus(sprintf('Sorted by column %d (%s)', sortCol, direction));
    end

    function onTableSaveAs(~, ~)
    %ONTABLESAVEAS  Save the working copy (with edits) to a new file.
    %   Includes editable units row and column names. Exports with the
    %   units as row 1, matching what the user sees in the data table.
        if isempty(appData.tableWorkingCopy)
            uialert(fig, 'No data to save.', 'Save As');
            return;
        end

        [fn, fp] = uiputfile( ...
            {'*.csv', 'CSV (*.csv)'; '*.xlsx', 'Excel (*.xlsx)'}, ...
            'Save Table As');
        if isequal(fn, 0), return; end
        outPath = fullfile(fp, fn);

        try
            % Get column names from the table (excluding Masked column)
            colNames = tblData.ColumnName;
            if strcmp(colNames{end}, 'Masked')
                colNames = colNames(1:end-1);
            end

            % Get working copy, excluding masked rows if desired
            wc = appData.tableWorkingCopy;
            mask = appData.tableMask;
            if any(mask)
                answer = questdlg('Exclude masked rows from export?', ...
                    'Masked Rows', 'Exclude', 'Include All', 'Exclude');
                if strcmp(answer, 'Exclude')
                    wc = wc(~mask, :);
                end
            end

            % Build export: header row + units row + data
            validNames = matlab.lang.makeValidName(colNames);
            [~, ~, ext] = fileparts(outPath);

            if strcmpi(ext, '.xlsx')
                % Excel: write header, units, then data as separate rows
                headerCell = colNames(:)';
                unitsCell  = appData.tableUnits(:)';
                dataCell   = num2cell(wc);
                allCell    = [headerCell; unitsCell; dataCell];
                writecell(allCell, outPath);
            else
                % CSV: write header, units, then data
                fidOut = fopen(outPath, 'w');
                if fidOut == -1
                    error('Cannot open file: %s', outPath);
                end
                cleanF = onCleanup(@() fclose(fidOut));
                % Header row
                fprintf(fidOut, '%s\n', strjoin(colNames, ','));
                % Units row
                fprintf(fidOut, '%s\n', strjoin(appData.tableUnits, ','));
                % Data rows
                for ri = 1:size(wc, 1)
                    vals = arrayfun(@(v) sprintf('%.10g', v), wc(ri, :), ...
                        'UniformOutput', false);
                    fprintf(fidOut, '%s\n', strjoin(vals, ','));
                end
            end
            setStatus(sprintf('Table saved: %s (%d rows + units)', fn, size(wc, 1)));
        catch ME
            uialert(fig, sprintf('Save failed:\n%s', ME.message), 'Error');
        end
    end

    % ── Advanced Analysis & Correction Menu ─────────────────────────────

    advMenuFig = [];  % persistent handle to the popup menu figure

    function onShowAdvancedMenu(~, ~)
    %ONSHOWADVANCEDMENU  Show a popup menu of advanced analysis tools.
    %   Opens a small floating figure with a list of actions. Clicking an
    %   action closes the popup and launches the corresponding dialog.

        % Close existing popup if open
        if ~isempty(advMenuFig) && isvalid(advMenuFig)
            delete(advMenuFig);
            advMenuFig = [];
            return;  % toggle off
        end

        % Position near the Advanced button
        figPos = fig.Position;
        advMenuFig = uifigure('Name', 'Advanced Tools', ...
            'Position', [figPos(1) + figPos(3) - 210, figPos(2) + figPos(4) - 460, 200, 400], ...
            'Resize', 'off', ...
            'CloseRequestFcn', @(~,~) closeAdvMenu());

        advMenuGL = uigridlayout(advMenuFig, [24 1], ...
            'RowHeight', {18, 26, 26, 26, 26, 6, 18, 26, 6, 18, 26, 26, 6, 18, 26, 26, 26, 6, 18, 26, 6, 18, 26, 26}, ...
            'ColumnWidth', {'1x'}, ...
            'Padding', [8 6 8 6], 'RowSpacing', 2);

        % Section: Analysis
        lbl1 = uilabel(advMenuGL, 'Text', 'ANALYSIS', 'FontSize', 9, 'FontWeight', 'bold', ...
            'FontColor', [0.5 0.5 0.5]);
        lbl1.Layout.Row = 1;

        btn1 = uibutton(advMenuGL, 'Text', [char(8747) ' Integrate (bounded)...'], ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onOpenIntegrationDialog), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', 'Compute definite integral between two x-range edge points');
        btn1.Layout.Row = 2;

        btn2 = uibutton(advMenuGL, 'Text', [char(916) ' Dataset Math...'], ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onDatasetAlgebra), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', 'Combine datasets: A+B, A-B, A/B, A*B, asymmetry');
        btn2.Layout.Row = 3;

        btn3 = uibutton(advMenuGL, 'Text', [char(8776) ' Curve Fit...'], ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onOpenCurveFitDialog), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', 'Fit data to built-in models (exponential, power law, polynomial, Gaussian, ...)');
        btn3.Layout.Row = 4;

        btnHyst = uibutton(advMenuGL, 'Text', [char(8635) ' Hysteresis Analysis...'], ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onOpenHysteresisDialog), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', 'Analyze M(H) loops: Hc, Mr, Ms, squareness, SFD, background subtraction');
        btnHyst.Layout.Row = 5;

        % Separator (row 6)

        % Section: Peak Analysis
        lblPeak = uilabel(advMenuGL, 'Text', 'PEAK ANALYSIS', 'FontSize', 9, 'FontWeight', 'bold', ...
            'FontColor', [0.5 0.5 0.5]);
        lblPeak.Layout.Row = 7;

        btnAdvPeak = uibutton(advMenuGL, 'Text', 'Advanced Peak Analysis...', ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onOpenAdvancedPeakAnalysis), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', ['Robust peak detection with adaptive noise, prominence ' ...
                        'filtering, simultaneous multi-peak + polynomial background fitting']);
        btnAdvPeak.Layout.Row = 8;

        % Separator (row 9)

        % Section: Correction
        lbl2 = uilabel(advMenuGL, 'Text', 'CORRECTION', 'FontSize', 9, 'FontWeight', 'bold', ...
            'FontColor', [0.5 0.5 0.5]);
        lbl2.Layout.Row = 10;

        btn4 = uibutton(advMenuGL, 'Text', [char(8596) ' Resample...'], ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onResampleDataset), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', 'Resample data to a uniform x-grid');
        btn4.Layout.Row = 11;

        btn5 = uibutton(advMenuGL, 'Text', 'Column Calculator...', ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onColumnCalculator), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', 'Create new columns from expressions');
        btn5.Layout.Row = 12;

        % Separator (row 13)

        % Section: Thickness / Reflectivity
        lblThick = uilabel(advMenuGL, 'Text', 'THICKNESS / REFLECTIVITY', ...
            'FontSize', 9, 'FontWeight', 'bold', 'FontColor', [0.5 0.5 0.5]);
        lblThick.Layout.Row = 14;

        btnAdvFFTThick = uibutton(advMenuGL, 'Text', 'FFT Thickness...', ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onFFTThickness), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', 'Compute film thickness from Laue / Kiessig fringe periodicity via FFT');
        btnAdvFFTThick.Layout.Row = 15;

        btnAdvReflFFT = uibutton(advMenuGL, 'Text', 'Reflectivity FFT...', ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onReflectivityFFT), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', ['Compute SLD profile from Kiessig fringes via FFT (Q-space). ' ...
                        'Also estimates thickness from fringe spacing.']);
        btnAdvReflFFT.Layout.Row = 16;

        btnAdvFringe = uibutton(advMenuGL, 'Text', ['Fringe ' char(916) 't (2-click)...'], ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onArmFringeThickness), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', ['Pick two fringe peaks to estimate thickness via t = 2' char(960) ...
                        '/' char(916) 'Q.  Draggable markers for refinement.']);
        btnAdvFringe.Layout.Row = 17;

        % Separator (row 18)

        % Section: Visualization
        lbl3 = uilabel(advMenuGL, 'Text', 'VISUALIZATION', 'FontSize', 9, 'FontWeight', 'bold', ...
            'FontColor', [0.5 0.5 0.5]);
        lbl3.Layout.Row = 19;

        btn6 = uibutton(advMenuGL, 'Text', 'Inset Plot...', ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onCreateInset), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', 'Create an inset zoom of a selected region');
        btn6.Layout.Row = 20;

        % Separator (row 21)

        % Section: Data
        lbl4 = uilabel(advMenuGL, 'Text', 'DATA', 'FontSize', 9, 'FontWeight', 'bold', ...
            'FontColor', [0.5 0.5 0.5]);
        lbl4.Layout.Row = 22;

        btn7 = uibutton(advMenuGL, 'Text', [char(9998) ' Graph Digitizer...'], ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onOpenDigitizer), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', 'Extract data points from a graph image (screenshot/PDF figure)');
        btn7.Layout.Row = 23;

        btnAdvReflFit = uibutton(advMenuGL, 'Text', 'Reflectivity Fitting...', ...
            'ButtonPushedFcn', @(~,~) advMenuAction(@onOpenReflFitDialog), ...
            'BackgroundColor', [0.15 0.15 0.15], 'FontColor', [0.9 0.9 0.9], ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', 'Fit specular reflectivity R(Q) via Parratt recursion with layer stack editor');
        btnAdvReflFit.Layout.Row = 24;

        function advMenuAction(callbackFcn)
        %ADVMENUACTION  Close the popup then execute the callback.
            closeAdvMenu();
            callbackFcn([], []);
        end

        function closeAdvMenu()
            if ~isempty(advMenuFig) && isvalid(advMenuFig)
                delete(advMenuFig);
            end
            advMenuFig = [];
        end
    end

    % ── Advanced Peak Analysis (extracted dialog) ────────────────────────

    function onOpenAdvancedPeakAnalysis(~, ~)
    %ONOPENADVANCEDPEAKANALYSIS  Launch the advanced peak analysis dialog.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Peak Analysis');
            return;
        end
        dataplotter.peakAnalysis(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn', @setStatus, ...
            'PeakUpdateCallback', @peakAnalysisApply, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG));

        function peakAnalysisApply(peaksResult, bgEst)
        %PEAKANALYSISAPPLY  Receive peaks from advanced analysis dialog.
            ds = appData.datasets{appData.activeIdx};

            % Ensure output peaks have all required fields
            requiredFields = {'center','fwhm','height','area','xRange','status','bg','model','eta'};
            for fi = 1:numel(requiredFields)
                fn = requiredFields{fi};
                if ~isfield(peaksResult, fn)
                    for pi = 1:numel(peaksResult)
                        peaksResult(pi).(fn) = NaN;
                    end
                end
            end

            ds.peaks = peaksResult;
            if ~isempty(bgEst)
                d = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
                xv = double(d.time);
                valid = ~isnan(xv);
                ds.snipBackground = struct('x', xv(valid), 'bg', bgEst(1:sum(valid)));
            end
            appData.datasets{appData.activeIdx} = ds;
            refreshPeakTable();
            onPlot([], []);
            showPeakWindow();
        end
    end

    % ── Integration Dialog ──────────────────────────────────────────────

    function onOpenIntegrationDialog(~, ~)
    %ONOPENINTEGRATIONDIALOG  Open dialog for manual bounded integration.
    %   User sets two x-range edge points (type or click-to-set),
    %   selects a channel, and computes the definite integral.
    %   The integrated region is shaded on the main axes.

        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Integrate');
            return;
        end

        ds = appData.datasets{appData.activeIdx};
        plotD = getPlotData(appData.activeIdx);
        if isempty(plotD)
            uialert(fig, 'Apply corrections or plot data first.', 'Integrate');
            return;
        end

        xData = plotD.time;
        labels = plotD.labels;
        nCh = numel(labels);

        % Default range: full x-extent
        xMin = min(xData);
        xMax = max(xData);

        % Build dialog
        intFig = uifigure('Name', 'Integrate — Bounded Area', ...
            'Position', [350 280 440 340], 'Resize', 'off');
        iGL = uigridlayout(intFig, [9 3], ...
            'RowHeight', {22, 28, 28, 28, 12, 28, 50, 12, 34}, ...
            'ColumnWidth', {100, '1x', 80}, ...
            'Padding', [12 10 12 10], 'RowSpacing', 5);

        % Row 1: Instructions
        lblInstr = uilabel(iGL, 'Text', ...
            'Set two x-range edge points, then compute the area.', ...
            'FontSize', 10, 'FontColor', [0.5 0.5 0.5]);
        lblInstr.Layout.Row = 1; lblInstr.Layout.Column = [1 3];

        % Row 2: X1 (left edge)
        uilabel(iGL, 'Text', 'X₁ (left edge):', ...
            'HorizontalAlignment', 'right', 'FontWeight', 'bold');
        efIntX1 = uieditfield(iGL, 'numeric', 'Value', xMin);
        efIntX1.Layout.Row = 2; efIntX1.Layout.Column = 2;
        btnPickX1 = uibutton(iGL, 'Text', 'Pick...', ...
            'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [1 1 1], ...
            'Tooltip', 'Click on the plot to set X₁', ...
            'ButtonPushedFcn', @(~,~) pickEdgePoint('x1'));
        btnPickX1.Layout.Row = 2; btnPickX1.Layout.Column = 3;

        % Row 3: X2 (right edge)
        uilabel(iGL, 'Text', 'X₂ (right edge):', ...
            'HorizontalAlignment', 'right', 'FontWeight', 'bold');
        efIntX2 = uieditfield(iGL, 'numeric', 'Value', xMax);
        efIntX2.Layout.Row = 3; efIntX2.Layout.Column = 2;
        btnPickX2 = uibutton(iGL, 'Text', 'Pick...', ...
            'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [1 1 1], ...
            'Tooltip', 'Click on the plot to set X₂', ...
            'ButtonPushedFcn', @(~,~) pickEdgePoint('x2'));
        btnPickX2.Layout.Row = 3; btnPickX2.Layout.Column = 3;

        % Row 4: Channel selector
        uilabel(iGL, 'Text', 'Channel:', ...
            'HorizontalAlignment', 'right');
        ddIntCh = uidropdown(iGL, 'Items', labels, ...
            'ItemsData', 1:nCh, 'Value', 1);
        ddIntCh.Layout.Row = 4; ddIntCh.Layout.Column = [2 3];

        % Row 5: separator
        % Row 6: Compute button
        btnCompute = uibutton(iGL, 'Text', 'Compute Integral', ...
            'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
            'FontWeight', 'bold', ...
            'ButtonPushedFcn', @(~,~) doComputeIntegral());
        btnCompute.Layout.Row = 6; btnCompute.Layout.Column = [1 3];

        % Row 7: Result display
        lblIntResult = uilabel(iGL, 'Text', '', ...
            'FontSize', 13, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'Interpreter', 'html', 'WordWrap', 'on');
        lblIntResult.Layout.Row = 7; lblIntResult.Layout.Column = [1 3];

        % Row 8: separator
        % Row 9: Close + Copy
        btnRowGL = uigridlayout(iGL, [1 2], ...
            'ColumnWidth', {'1x', '1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 8);
        btnRowGL.Layout.Row = 9; btnRowGL.Layout.Column = [1 3];

        uibutton(btnRowGL, 'Text', 'Copy Result', ...
            'BackgroundColor', [0.15 0.45 0.75], 'FontColor', [1 1 1], ...
            'ButtonPushedFcn', @(~,~) copyIntResult());
        uibutton(btnRowGL, 'Text', 'Close', ...
            'ButtonPushedFcn', @(~,~) closeIntDialog());

        % State for the integration result
        intResult = struct('area', NaN, 'x1', NaN, 'x2', NaN, 'channel', '');
        hShadePatch = [];  % handle to shaded region on main axes

        function pickEdgePoint(which)
        %PICKEDGEPOINT  Click on the main axes to set an edge point.
            intFig.Visible = 'off';  % hide dialog so user can click plot
            setStatus(sprintf('Click on the plot to set %s...', upper(which)));
            fig.Pointer = 'crosshair';

            % Temporarily install a one-shot click handler
            oldBDF = ax.ButtonDownFcn;
            ax.ButtonDownFcn = @(~, ~) captureClick(which, oldBDF);

            function captureClick(wh, restoreFcn)
                cp = ax.CurrentPoint;
                xClick = cp(1, 1);
                switch wh
                    case 'x1'
                        efIntX1.Value = xClick;
                    case 'x2'
                        efIntX2.Value = xClick;
                end
                ax.ButtonDownFcn = restoreFcn;
                fig.Pointer = 'arrow';
                intFig.Visible = 'on';
                figure(intFig);
                setStatus(sprintf('%s set to %.4g', upper(wh), xClick));
            end
        end

        function doComputeIntegral()
        %DOCOMPUTEINTEGRAL  Compute the definite integral between X1 and X2.
            x1v = efIntX1.Value;
            x2v = efIntX2.Value;
            ch = ddIntCh.Value;

            if x1v >= x2v
                uialert(intFig, 'X₁ must be less than X₂.', 'Range Error');
                return;
            end

            % Get the data to integrate
            d = getPlotData(appData.activeIdx);
            xAll = d.time;
            yAll = d.values(:, ch);

            % Mask to the range [x1, x2]
            mask = xAll >= x1v & xAll <= x2v;
            xSeg = xAll(mask);
            ySeg = yAll(mask);

            if numel(xSeg) < 2
                uialert(intFig, 'Not enough data points in the selected range.', 'Error');
                return;
            end

            % Trapezoidal integration
            area = trapz(xSeg, ySeg);

            intResult.area = area;
            intResult.x1 = x1v;
            intResult.x2 = x2v;
            intResult.channel = labels{ch};

            % Display result
            lblIntResult.Text = sprintf( ...
                ['<b>%s</b> %s Y dx = <b>%.6g</b><br>' ...
                 'Range: [%.4g, %.4g] &nbsp; (%d points)'], ...
                char(8747), char(160), area, x1v, x2v, numel(xSeg));

            % Shade the region on the main axes
            clearIntShading();
            hold(ax, 'on');
            % Fill polygon: bottom at y=0 or yMin, top at data
            yBase = zeros(size(ySeg));
            xPoly = [xSeg; flipud(xSeg)];
            yPoly = [ySeg; yBase];
            hShadePatch = fill(ax, xPoly, yPoly, [0.3 0.6 1.0], ...
                'FaceAlpha', 0.3, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off', 'Tag', 'integrationShade');
            % Draw vertical edge lines
            yLimCurr = ax.YLim;
            line(ax, [x1v x1v], yLimCurr, 'Color', [0.8 0.2 0.2], ...
                'LineStyle', '--', 'LineWidth', 1.5, ...
                'HandleVisibility', 'off', 'Tag', 'integrationEdge');
            line(ax, [x2v x2v], yLimCurr, 'Color', [0.8 0.2 0.2], ...
                'LineStyle', '--', 'LineWidth', 1.5, ...
                'HandleVisibility', 'off', 'Tag', 'integrationEdge');
            hold(ax, 'off');

            setStatus(sprintf('Integral = %.6g over [%.4g, %.4g]', area, x1v, x2v));
        end

        function copyIntResult()
            if isnan(intResult.area)
                uialert(intFig, 'Compute an integral first.', 'Copy');
                return;
            end
            txt = sprintf('Integral of %s from %.6g to %.6g = %.6g', ...
                intResult.channel, intResult.x1, intResult.x2, intResult.area);
            clipboard('copy', txt);
            setStatus('Integration result copied to clipboard');
        end

        function closeIntDialog()
            clearIntShading();
            delete(intFig);
        end

        function clearIntShading()
        %CLEARINTSHADING  Remove shading and edge lines from main axes.
            if ~isempty(hShadePatch) && isvalid(hShadePatch)
                delete(hShadePatch);
                hShadePatch = [];
            end
            % Remove edge lines by tag
            if ~isempty(ax) && isvalid(ax)
                edgeLines = findobj(ax, 'Tag', 'integrationEdge');
                delete(edgeLines);
                shadePatches = findobj(ax, 'Tag', 'integrationShade');
                delete(shadePatches);
            end
        end
    end

    % ── Curve Fitting Dialog ────────────────────────────────────────────

    function onOpenCurveFitDialog(~, ~)
    %ONOPENCURVEFITDIALOG  Open general-purpose curve fitting dialog.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Curve Fit');
            return;
        end
        dataplotter.curveFitting(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn', @setStatus, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG));
    end

    function onOpenHysteresisDialog(~, ~)
    %ONOPENHYSTERESISDIALOG  Open hysteresis loop analysis dialog.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Hysteresis');
            return;
        end
        dataplotter.hysteresisDialog(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn', @setStatus, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG));
    end

    function onOpenReflFitDialog(~, ~)
    %ONOPENREFLFITDIALOG  Open reflectivity fitting dialog (Parratt recursion).
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Reflectivity Fit');
            return;
        end
        dataplotter.reflFitting(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn', @setStatus, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG));
    end

%{
        % Read initial guesses from table (user may have edited)
            p0 = zeros(1, numel(pNames));
            for pi = 1:numel(pNames)
                val = tblCFParams.Data{pi, 3};
                if isnumeric(val)
                    p0(pi) = val;
                else
                    p0(pi) = str2double(val);
                end
            end

            % Auto-guess improvements based on data
            p0 = autoGuess(idx, p0, xSeg, ySeg);

            % Cost function: sum of squared residuals
            costFcn = @(p) sum((ySeg - fitFcn(p, xSeg)).^2);

            % Run fminsearch
            cfFig.Pointer = 'watch'; drawnow;
            try
                opts2 = optimset('MaxFunEvals', 10000, 'MaxIter', 5000, ...
                    'TolFun', 1e-12, 'TolX', 1e-10);
                [pOpt, fval] = fminsearch(costFcn, p0, opts2);

                % Compute fit curve (dense x for smooth line)
                xFit = linspace(min(xSeg), max(xSeg), 500)';
                yFit = fitFcn(pOpt, xFit);
                yPred = fitFcn(pOpt, xSeg);
                residuals = ySeg - yPred;

                % R²
                ssTot = sum((ySeg - mean(ySeg)).^2);
                ssRes = fval;
                R2 = 1 - ssRes / max(ssTot, eps);
                RMSE = sqrt(ssRes / numel(ySeg));

                % Store result
                cfResult.params = pOpt;
                cfResult.model = ddCFModel.Value;
                cfResult.xFit = xFit;
                cfResult.yFit = yFit;
                cfResult.R2 = R2;
                cfResult.RMSE = RMSE;
                cfResult.paramNames = pNames;

                % Update parameter table
                for pi = 1:numel(pNames)
                    tblCFParams.Data{pi, 2} = sprintf('%.6g', pOpt(pi));
                end

                % Plot fit
                cla(cfAxFit);
                plot(cfAxFit, xSeg, ySeg, 'k.', 'MarkerSize', 4);
                hold(cfAxFit, 'on');
                plot(cfAxFit, xFit, yFit, 'r-', 'LineWidth', 1.5);
                hold(cfAxFit, 'off');
                legend(cfAxFit, {'Data', 'Fit'}, 'Location', 'best');
                title(cfAxFit, sprintf('%s  (R%s = %.6f)', ddCFModel.Value, char(178), R2));
                cfAxFit.Box = 'on'; grid(cfAxFit, 'on');

                % Plot residuals
                cla(cfAxRes);
                stem(cfAxRes, xSeg, residuals, 'b.', 'MarkerSize', 3);
                hold(cfAxRes, 'on');
                yline(cfAxRes, 0, 'k--');
                hold(cfAxRes, 'off');
                title(cfAxRes, sprintf('Residuals (RMSE = %.4g)', RMSE));
                cfAxRes.Box = 'on'; grid(cfAxRes, 'on');

                % Stats label
                lblCFStats.Text = sprintf('R%s = <b>%.6f</b> &nbsp; RMSE = %.4g &nbsp; N = %d', ...
                    char(178), R2, RMSE, numel(xSeg));

                cfFig.Pointer = 'arrow';
            catch ME
                cfFig.Pointer = 'arrow';
                uialert(cfFig, sprintf('Fit failed:\n%s', ME.message), 'Error');
            end
        end

        function p0 = autoGuess(modelIdx, p0, xS, yS)
        %AUTOGUESS  Improve initial parameter guesses from data.
            switch modelIdx
                case 1  % Linear
                    p0(1) = (yS(end)-yS(1)) / max(eps, xS(end)-xS(1));
                    p0(2) = yS(1);
                case {2,3}  % Polynomial
                    p0(end) = mean(yS);
                case 4  % Exp decay
                    p0(1) = max(yS) - min(yS);
                    p0(2) = (max(xS) - min(xS)) / 3;
                    p0(3) = min(yS);
                case 5  % Exp growth
                    p0(1) = min(yS);
                    p0(2) = (max(xS) - min(xS)) / 3;
                    p0(3) = min(yS);
                case 7  % Power law
                    p0(1) = yS(1) / max(eps, abs(xS(1)));
                    p0(2) = 1;
                case {8,9,10}  % Gaussian / Lorentzian / Voigt
                    [~, pkIdx] = max(yS);
                    p0(1) = yS(pkIdx);
                    p0(2) = xS(pkIdx);
                    hm = find(yS >= yS(pkIdx)/2);
                    if numel(hm) >= 2
                        p0(3) = (xS(hm(end)) - xS(hm(1))) / 2.355;
                    else
                        p0(3) = (max(xS)-min(xS)) / 10;
                    end
                case 11  % Sigmoid
                    p0(1) = max(yS) - min(yS);
                    p0(2) = mean(xS);
                    p0(3) = (max(xS) - min(xS)) / 10;
                case 13  % Langmuir
                    p0(1) = max(yS);
                    p0(2) = median(xS);
            end
        end

        function onCFPlotOnMain()
        %ONCFPLOTONMAIN  Overlay the fit curve on the main DataPlotter axes.
            if isempty(cfResult.xFit), return; end
            hold(ax, 'on');
            plot(ax, cfResult.xFit, cfResult.yFit, 'r-', 'LineWidth', 1.5, ...
                'DisplayName', sprintf('%s fit (R%s=%.4f)', ...
                    cfResult.model, char(178), cfResult.R2), ...
                'HandleVisibility', 'on', 'Tag', 'curveFitOverlay');
            hold(ax, 'off');
            % Add equation text annotation
            eqnStr = sprintf('%s  R%s = %.4f', cfResult.model, char(178), cfResult.R2);
            text(ax, 0.02, 0.95, eqnStr, ...
                'Units', 'normalized', 'FontSize', 9, ...
                'Color', [0.9 0.2 0.2], 'BackgroundColor', [1 1 1 0.7], ...
                'VerticalAlignment', 'top', ...
                'HandleVisibility', 'off', 'Tag', 'curveFitLabel');
            setStatus(sprintf('Fit overlaid: %s (R%s=%.6f)', cfResult.model, char(178), cfResult.R2));
        end

        function onCFCopyResults()
        %ONCFCOPYRESULTS  Copy fit parameters and stats to clipboard.
            if isnan(cfResult.R2), return; end
            lines2 = {};
            lines2{end+1} = sprintf('Model: %s', cfResult.model);
            lines2{end+1} = sprintf('R² = %.8f', cfResult.R2);
            lines2{end+1} = sprintf('RMSE = %.6g', cfResult.RMSE);
            lines2{end+1} = 'Parameters:';
            for pi = 1:numel(cfResult.paramNames)
                lines2{end+1} = sprintf('  %s = %.8g', cfResult.paramNames{pi}, cfResult.params(pi)); %#ok<AGROW>
            end
            clipboard('copy', strjoin(lines2, newline));
            setStatus('Fit results copied to clipboard');
        end

        function cfPickXRange(which)
        %CFPICKXRANGE  Click on DataPlotter axes to set X min or max.
            cfFig.Visible = 'off';
            fig.Pointer = 'crosshair';
            setStatus(sprintf('Click on the plot to set X %s...', which));
            oldBDF = ax.ButtonDownFcn;
            ax.ButtonDownFcn = @(~,~) cfCaptureX(which, oldBDF);
            function cfCaptureX(wh, restoreFcn)
                cp = ax.CurrentPoint;
                xClick = cp(1,1);
                switch wh
                    case 'min', efCFXmin.Value = xClick;
                    case 'max', efCFXmax.Value = xClick;
                end
                ax.ButtonDownFcn = restoreFcn;
                fig.Pointer = 'arrow';
                cfFig.Visible = 'on';
                figure(cfFig);
                setStatus(sprintf('X %s set to %.4g', wh, xClick));
            end
        end
    end
%}

    % ── Graph Digitizer ────────────────────────────────────────────────

    function onOpenDigitizer(~, ~)
    %ONOPENDIGITIZER  Delegates to dataplotter.graphDigitizer.
        dataplotter.graphDigitizer( ...
            'LoadCallback', @digLoadDataset, ...
            'StatusFcn', @setStatus, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG));
        function digLoadDataset(data)
            newDS = buildDs('[Digitized]', data, 'digitizer');
            appData.datasets{end+1} = newDS;
            appData.activeIdx = numel(appData.datasets);
            updateFileList();
            updateControlsForActiveDataset();
            onPlot([], []);
        end
    end

    % ── Multi-Dataset Overlay ──────────────────────────────────────────

    function onOverlayModeChanged(~,~)
    %ONOVERLAYCHANGED  Toggle multi-dataset overlay mode.
    %  When enabled, selects ALL loaded datasets in the listbox so they
    %  are all plotted simultaneously with a unified legend.
        if ~isprop(appData, 'overlayMode'), appData.overlayMode = false; end
        appData.overlayMode = cbOverlayMode.Value;
        if appData.overlayMode && numel(appData.datasets) > 1
            % Select all datasets in the listbox
            allIdx = num2cell(1:numel(appData.datasets));
            lbDatasets.Value = allIdx;
            setStatus(sprintf('Overlay ON — all %d datasets overlaid.', numel(appData.datasets)));
        else
            % Revert to just the active dataset
            lbDatasets.Value = {appData.activeIdx};
            setStatus('Overlay off.');
        end
        onPlot([],[]);
    end

    % ── Plot Templates ─────────────────────────────────────────────────

    function onPlotTemplates(~,~)
    %ONPLOTTEMPLATES  Save or load plot formatting presets.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end

        tplFig = uifigure('Name', 'Plot Templates', 'Position', [350 300 360 260], 'Resize', 'off');
        tplGL = uigridlayout(tplFig, [4 2], ...
            'RowHeight', {30, 30, 30, '1x'}, 'ColumnWidth', {'1x', '1x'}, ...
            'Padding', [15 15 15 15], 'RowSpacing', 10);

        uibutton(tplGL, 'Text', 'Save Template...', ...
            'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
            'FontWeight', 'bold', ...
            'ButtonPushedFcn', @(~,~) doSaveTemplate());
        uibutton(tplGL, 'Text', 'Load Template...', ...
            'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
            'FontWeight', 'bold', ...
            'ButtonPushedFcn', @(~,~) doLoadTemplate());

        uibutton(tplGL, 'Text', 'Delete Template...', ...
            'ButtonPushedFcn', @(~,~) doDeleteTemplate());
        uibutton(tplGL, 'Text', 'Cancel', ...
            'ButtonPushedFcn', @(~,~) delete(tplFig));

        btnBatchApply = uibutton(tplGL, 'Text', 'Batch Apply...', ...
            'BackgroundColor', [0.18 0.55 0.34], 'FontColor', BTN_FG, ...
            'FontWeight', 'bold', ...
            'Tooltip', 'Apply a saved template to a folder of files (import + correct + export CSV)', ...
            'ButtonPushedFcn', @(~,~) doBatchApplyTemplate());
        btnBatchApply.Layout.Row = 3; btnBatchApply.Layout.Column = [1 2];

        lblInfo = uilabel(tplGL, 'Text', ...
            ['Templates save corrections, normalization, labels, and scale settings. ' ...
             'Use "Batch Apply" to process a folder of files with the same pipeline.'], ...
            'WordWrap', 'on', 'FontSize', 9, 'FontColor', [0.4 0.4 0.4]);
        lblInfo.Layout.Row = 4; lblInfo.Layout.Column = [1 2];

        function doSaveTemplate()
            [fname, fpath] = uiputfile('*.mat', 'Save Plot Template');
            if isequal(fname, 0), return; end

            ds = appData.datasets{appData.activeIdx};
            tpl = struct();
            % Axis limits
            tpl.xMin = efXMin.Value; tpl.xMax = efXMax.Value; tpl.xStep = efXStep.Value;
            tpl.yMin = efYMin.Value; tpl.yMax = efYMax.Value; tpl.yStep = efYStep.Value;
            % Corrections
            tpl.xOff = ds.xOff; tpl.yOff = ds.yOff;
            tpl.bgSlope = ds.bgSlope; tpl.bgInt = ds.bgInt;
            tpl.smoothEnabled = ds.smoothEnabled;
            tpl.smoothWindow = ds.smoothWindow;
            tpl.smoothMethod = ds.smoothMethod;
            tpl.normMethod = ds.normMethod;
            tpl.derivativeMode = ds.derivativeMode;
            tpl.xTrimMin = ds.xTrimMin; tpl.xTrimMax = ds.xTrimMax;
            % Labels
            tpl.plotTitle = efPlotTitle.Value;
            tpl.xLabel = efXLabel.Value;
            tpl.yLabel = efYLabel.Value;
            % Scale
            tpl.xScale = ax.XScale;
            tpl.yScale = ax.YScale;
            % Tick format
            tpl.xTickFormat = ddXTickFmt.Value;
            tpl.yTickFormat = ddYTickFmt.Value;

            save(fullfile(fpath, fname), '-struct', 'tpl'); %#ok<SAVEVAR>
            setStatus(sprintf('Template saved: %s', fname));
        end

        function doLoadTemplate()
            [fname, fpath] = uigetfile('*.mat', 'Load Plot Template');
            if isequal(fname, 0), return; end

            tpl = load(fullfile(fpath, fname));
            ds = appData.datasets{appData.activeIdx};

            % Apply corrections
            if isfield(tpl, 'xOff'), efXOffset.Value = tpl.xOff; ds.xOff = tpl.xOff; end
            if isfield(tpl, 'yOff'), efYOffset.Value = tpl.yOff; ds.yOff = tpl.yOff; end
            if isfield(tpl, 'bgSlope'), efBGSlope.Value = tpl.bgSlope; ds.bgSlope = tpl.bgSlope; end
            if isfield(tpl, 'bgInt'), efBGIntercept.Value = tpl.bgInt; ds.bgInt = tpl.bgInt; end
            if isfield(tpl, 'smoothEnabled'), cbSmooth.Value = tpl.smoothEnabled; ds.smoothEnabled = tpl.smoothEnabled; end
            if isfield(tpl, 'smoothWindow'), efSmoothWin.Value = tpl.smoothWindow; ds.smoothWindow = tpl.smoothWindow; end
            if isfield(tpl, 'smoothMethod'), ddSmoothMethod.Value = tpl.smoothMethod; ds.smoothMethod = tpl.smoothMethod; end
            if isfield(tpl, 'normMethod'), ddNormalize.Value = tpl.normMethod; ds.normMethod = tpl.normMethod; end
            if isfield(tpl, 'derivativeMode'), ddDerivative.Value = tpl.derivativeMode; ds.derivativeMode = tpl.derivativeMode; end
            if isfield(tpl, 'xTrimMin') && ~isnan(tpl.xTrimMin), efXTrimMin.Value = num2str(tpl.xTrimMin); end
            if isfield(tpl, 'xTrimMax') && ~isnan(tpl.xTrimMax), efXTrimMax.Value = num2str(tpl.xTrimMax); end

            % Apply axis limits
            if isfield(tpl, 'xMin'), efXMin.Value = tpl.xMin; end
            if isfield(tpl, 'xMax'), efXMax.Value = tpl.xMax; end
            if isfield(tpl, 'xStep'), efXStep.Value = tpl.xStep; end
            if isfield(tpl, 'yMin'), efYMin.Value = tpl.yMin; end
            if isfield(tpl, 'yMax'), efYMax.Value = tpl.yMax; end
            if isfield(tpl, 'yStep'), efYStep.Value = tpl.yStep; end

            % Apply labels
            if isfield(tpl, 'plotTitle'), efPlotTitle.Value = tpl.plotTitle; end
            if isfield(tpl, 'xLabel'), efXLabel.Value = tpl.xLabel; end
            if isfield(tpl, 'yLabel'), efYLabel.Value = tpl.yLabel; end

            % Apply tick formats
            if isfield(tpl, 'xTickFormat'), ddXTickFmt.Value = tpl.xTickFormat; end
            if isfield(tpl, 'yTickFormat'), ddYTickFmt.Value = tpl.yTickFormat; end

            appData.datasets{appData.activeIdx} = ds;

            % Re-apply corrections and replot
            onApplyCorrections([],[]);
            setStatus(sprintf('Template loaded: %s', fname));
            delete(tplFig);
        end

        function doDeleteTemplate()
            [fname, fpath] = uigetfile('*.mat', 'Delete Plot Template');
            if isequal(fname, 0), return; end
            delete(fullfile(fpath, fname));
            setStatus(sprintf('Template deleted: %s', fname));
        end

        function doBatchApplyTemplate()
        %DOBATCHAPPLYTEMPLATE  Pick a template + folder, run analysis pipeline.
            % Select template
            [tplName, tplPath] = uigetfile('*.mat', 'Select Template to Apply');
            if isequal(tplName, 0), return; end
            tplFile = fullfile(tplPath, tplName);

            % Select input folder
            inputDir = uigetdir(startDir, 'Select folder of data files');
            if isequal(inputDir, 0), return; end

            % Select output folder
            outputDir = uigetdir(inputDir, 'Select output folder for corrected CSVs');
            if isequal(outputDir, 0), return; end

            setStatus('Batch applying template...');
            delete(tplFig);
            drawnow;

            try
                res = scripts.applyAnalysisTemplate(tplFile, inputDir, ...
                    'OutputDir', outputDir, 'Recursive', true, ...
                    'ExportCSV', true, 'ExportPeaks', false);
                nOk  = sum(cellfun(@isempty, {res.error}));
                nErr = numel(res) - nOk;
                msg = sprintf('Batch complete: %d processed, %d failed.\nOutput: %s', ...
                    nOk, nErr, outputDir);
                setStatus(sprintf('Batch template: %d ok, %d failed', nOk, nErr));
                uialert(fig, msg, 'Batch Apply Complete');
            catch ME
                setStatus('Batch apply failed.');
                logGUIError('Batch Apply Error', ME.message, ME);
                uialert(fig, sprintf('Batch apply failed:\n%s', ME.message), ...
                    'Batch Apply Error');
            end
        end
    end

    % ── Batch Figure Export ────────────────────────────────────────────

    function onBatchFigureExport(~,~)
    %ONBATCHFIGUREEXPORT  Export each loaded dataset as an individual figure.
        if isempty(appData.datasets)
            uialert(fig, 'Load files first.', 'No data'); return;
        end

        beFig = uifigure('Name', 'Batch Figure Export', 'Position', [350 300 400 250], 'Resize', 'off');
        beGL = uigridlayout(beFig, [6 2], ...
            'RowHeight', {22, 22, 22, 22, 22, 30}, ...
            'ColumnWidth', {110, '1x'}, ...
            'Padding', [10 10 10 10], 'RowSpacing', 6);

        uilabel(beGL, 'Text', 'Format:', 'HorizontalAlignment', 'right');
        ddBEFormat = uidropdown(beGL, 'Items', {'PNG','PDF','SVG','EPS'}, 'Value', 'PNG');

        uilabel(beGL, 'Text', 'DPI (raster):', 'HorizontalAlignment', 'right');
        spBEDpi = uispinner(beGL, 'Value', 300, 'Limits', [72 1200], 'Step', 50);

        uilabel(beGL, 'Text', 'Width (in):', 'HorizontalAlignment', 'right');
        spBEW = uispinner(beGL, 'Value', 7, 'Limits', [2 20], 'Step', 0.5);

        uilabel(beGL, 'Text', 'Height (in):', 'HorizontalAlignment', 'right');
        spBEH = uispinner(beGL, 'Value', 5, 'Limits', [2 20], 'Step', 0.5);

        uilabel(beGL, 'Text', 'Template:', 'HorizontalAlignment', 'right');
        ddBETpl = uidropdown(beGL, ...
            'Items', {'None','APS (Phys Rev)','Nature','ACS'}, ...
            'Value', 'None');

        btnBEGL = uigridlayout(beGL, [1 2], 'ColumnWidth', {'1x','1x'}, ...
            'Padding', [0 0 0 0], 'ColumnSpacing', 8);
        btnBEGL.Layout.Row = 6; btnBEGL.Layout.Column = [1 2];

        uibutton(btnBEGL, 'Text', 'Export All', ...
            'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
            'FontWeight', 'bold', ...
            'ButtonPushedFcn', @(~,~) doBatchExport());
        uibutton(btnBEGL, 'Text', 'Cancel', ...
            'ButtonPushedFcn', @(~,~) delete(beFig));

        function doBatchExport()
            outDir = uigetdir('', 'Select output folder');
            if isequal(outDir, 0), return; end

            fmt = lower(ddBEFormat.Value);
            nDS = numel(appData.datasets);
            pb = uiprogressdlg(beFig, 'Title', 'Exporting...', 'Indeterminate', 'off');

            for ii = 1:nDS
                pb.Value = (ii-1)/nDS;
                pb.Message = sprintf('Dataset %d of %d', ii, nDS);

                ds = appData.datasets{ii};
                d  = getPlotData(ii);
                [~, fn, ~] = fileparts(ds.filepath);

                % Create temporary figure
                tmpFig = figure('Visible', 'off', 'Units', 'inches', ...
                    'Position', [0 0 spBEW.Value spBEH.Value]);
                tmpAx = axes(tmpFig);
                hold(tmpAx, 'on'); box(tmpAx, 'on'); grid(tmpAx, 'on');

                % Plot all Y channels
                nCh = size(d.values, 2);
                cols = plotting.lineColors(nCh);
                for ch = 1:nCh
                    plot(tmpAx, d.time, d.values(:, ch), '-', ...
                        'Color', cols(ch,:), 'LineWidth', 1.5, ...
                        'DisplayName', d.labels{ch});
                end

                % Apply template formatting
                fontSize = 10;
                fontName = 'Helvetica';
                switch ddBETpl.Value
                    case 'APS (Phys Rev)', fontSize = 8; fontName = 'Times New Roman';
                    case 'Nature',         fontSize = 7; fontName = 'Helvetica';
                    case 'ACS',            fontSize = 8; fontName = 'Helvetica';
                end

                tmpAx.FontSize = fontSize;
                tmpAx.FontName = fontName;
                tmpAx.TickDir = 'in';

                xlabel(tmpAx, guiLabel(guiXName(d.metadata), guiXUnit(d.metadata)), 'FontSize', fontSize);
                if nCh == 1
                    ylabel(tmpAx, guiLabel(d.labels{1}, d.units{min(1,numel(d.units))}), 'FontSize', fontSize);
                else
                    ylabel(tmpAx, 'Intensity', 'FontSize', fontSize);
                    legend(tmpAx, 'Location', 'best', 'FontSize', max(6, fontSize-2));
                end
                title(tmpAx, fn, 'FontSize', fontSize+1, 'Interpreter', 'none');

                % Save
                outPath = fullfile(outDir, [fn '.' fmt]);
                switch fmt
                    case 'png'
                        exportgraphics(tmpFig, outPath, 'Resolution', spBEDpi.Value);
                    case {'pdf','eps','svg'}
                        exportgraphics(tmpFig, outPath, 'ContentType', 'vector');
                end
                close(tmpFig);
            end
            close(pb);
            setStatus(sprintf('Exported %d figures to %s', nDS, outDir));
            delete(beFig);
        end
    end

    % ── Shared Data Helper ─────────────────────────────────────────────

    function d = getPlotData(dsIdx)
    %GETPLOTDATA  Return corrected data if available, else raw.
        ds = appData.datasets{dsIdx};
        if ~isempty(ds.corrData)
            d = ds.corrData;
        else
            d = ds.data;
        end
    end

    % ── Advanced Figure Builder ────────────────────────────────────────

    function onAdvancedFigureBuilder(~,~)
    %ONADVANCEDFIGUREBUILDER  Delegates to dataplotter.figureBuilder.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load at least one file first.','No data'); return;
        end
        dataplotter.figureBuilder(appData.datasets, appData.activeIdx, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG));
    end  % onAdvancedFigureBuilder

    if nargout > 0
        varargout{1} = api;
    end

end  % DataPlotter


% ════════════════════════════════════════════════════════════════════════
%  Module-level helpers  (stateless — no access to GUI handles)
% ════════════════════════════════════════════════════════════════════════

function baseUnit = stripSIPrefix(unitStr)
%STRIPSIPREFIX  Remove a leading SI prefix from a unit string.
%   'um' → 'm', 'nm' → 'm', 'kOe' → 'Oe', 'mV' → 'V', 'MeV' → 'eV'
%   Handles µ (char 956), and common multi-char units (emu, eV, Ang).
%   Returns the base unit with prefix stripped. If no recognised prefix,
%   returns the input unchanged.
    mu = char(956);  % µ
    % Ordered longest-first to avoid partial matches (e.g. 'meV' vs 'm'+'eV')
    knownPrefixes = {'G','M','k','m',mu,'u','n','p','f','a'};
    unitStr = strtrim(unitStr);
    if isempty(unitStr)
        baseUnit = unitStr;
        return;
    end
    for kp = 1:numel(knownPrefixes)
        pfx = knownPrefixes{kp};
        if startsWith(unitStr, pfx) && numel(unitStr) > numel(pfx)
            candidate = unitStr(numel(pfx)+1 : end);
            % Reject if stripping creates a non-unit (e.g. stripping 'k' from 'kg')
            % Accept if the remainder starts with an uppercase letter or known unit
            if isKnownBaseUnit(candidate)
                baseUnit = candidate;
                return;
            end
        end
    end
    % No prefix found — return as-is
    baseUnit = unitStr;
end


function tf = isKnownBaseUnit(s)
%ISKNOWNBASEUNIT  Check if a string looks like a valid base unit.
%   Matches common lab units: m, V, A, Oe, T, eV, emu, Hz, s, K, Pa,
%   Ang, W, J, N, bar, counts, cps, mol, g, and multi-char compound units.
    known = {'m','V','A','Oe','T','eV','emu','Hz','s','K','Pa', ...
             'Ang','W','J','N','bar','counts','cps','mol','g','B', ...
             char(197), 'rad', 'deg', 'arb'};  % Å = char(197)
    % Direct match
    for ki = 1:numel(known)
        if strcmp(s, known{ki})
            tf = true;
            return;
        end
    end
    % Also accept if starts with uppercase (likely a unit like Ohm, Siemens)
    if ~isempty(s) && s(1) >= 'A' && s(1) <= 'Z'
        tf = true;
        return;
    end
    % Accept compound units with / or ^
    if contains(s, '/') || contains(s, '^') || contains(s, char(183))
        tf = true;
        return;
    end
    tf = false;
end


function idx = findErrorColumn(labels, yLabel)
%FINDERRORCOLUMN  Find an error/uncertainty column matching a given y-channel label.
%  Heuristic: look for labels containing 'err', 'std', 'sigma', or 'd<Label>'.
%  Returns the column index or [] if none found.
    idx = [];
    candidates = { ...
        ['d' yLabel], ...        % e.g., 'dMoment' for 'Moment'
        [yLabel ' err'], ...     % e.g., 'Moment err'
        [yLabel ' Err'], ...
        'M. Std. Err.', ...      % QD VSM standard error
        [yLabel ' std'], ...
        [yLabel ' sigma'] };
    for ci = 1:numel(candidates)
        ii = find(strcmpi(labels, candidates{ci}), 1);
        if ~isempty(ii), idx = ii; return; end
    end
    % Fallback: any label containing 'err' or 'std' (case-insensitive)
    for li = 1:numel(labels)
        lbl = lower(labels{li});
        if (contains(lbl, 'err') || contains(lbl, 'std')) && ~strcmpi(labels{li}, yLabel)
            idx = li; return;
        end
    end
end

function [idxLo, idxHi] = findAsymmetricErrorColumns(labels, yLabel)
%FINDASYMMETRICERRORCOLUMNS  Find separate lower/upper error columns.
%  Searches for patterns like 'dR+' / 'dR-', 'Rerr+' / 'Rerr-',
%  'R_err_lo' / 'R_err_hi', etc.  Returns [] if not found.
    idxLo = []; idxHi = [];
    % Pattern 1: d<Label>+ / d<Label>-   (e.g. dR+ / dR-)
    hiCands = {[yLabel '+'], ['d' yLabel '+'], [yLabel ' err+'], [yLabel '_err_hi'], [yLabel ' hi']};
    loCands = {[yLabel '-'], ['d' yLabel '-'], [yLabel ' err-'], [yLabel '_err_lo'], [yLabel ' lo']};
    for ci = 1:numel(hiCands)
        hi = find(strcmpi(labels, hiCands{ci}), 1);
        lo = find(strcmpi(labels, loCands{ci}), 1);
        if ~isempty(hi) && ~isempty(lo)
            idxHi = hi; idxLo = lo; return;
        end
    end
end

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
    ds.derivativeMode = 'None';   % 'None', 'dY/dX', 'd²Y/dX²' — applied in corrections pipeline
    % Magnetometry sample parameters (for moment normalization + unit conversion)
    ds.sampleMass    = 0;         % grams (0 = not set)
    ds.sampleWidth   = 0;         % in units of ds.dimUnit (0 = not set)
    ds.sampleHeight  = 0;         % in units of ds.dimUnit (0 = not set)
    ds.dimUnit       = 'mm';      % 'mm' or 'cm'
    ds.sampleThick   = 0;         % in units of ds.thickUnit (0 = not set)
    ds.thickUnit     = 'nm';      % 'nm' or 'Å'
    ds.momentUnit    = 'emu (raw)';  % target moment unit
    ds.fieldUnit     = 'Oe (raw)';   % target field unit
    ds.unitSystem    = 'CGS';        % 'CGS' or 'SI' — quick-set toggle
    ds.refLines       = {};       % Cell array of structs: {orientation, value, color, style}
    ds.mask            = true(size(data.time));  % logical; true = included, false = masked
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

        case 'importSIMS'
            data = parser.importSIMS(fp);

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

        case 'importImage'
            data = parser.importImage(fp);

        case 'importBCF'
            data = parser.importBCF(fp);

        case 'importDM3'
            data = parser.importDM3(fp);

        case 'importDM4'
            data = parser.importDM4(fp);

        otherwise
            error('DataPlotter:unknownExt', ...
                ['No parser for extension "%s" (resolved as "%s").\n' ...
                 'Supported: .raw, .xrdml, .brml, .xlsx/.xls/.xlsm/.xlsb/.ods, ' ...
                 '.csv/.tsv/.txt, .refl, .pnr, .datA/B/C/D, .dat, ' ...
                 '.jpg/.jpeg/.png/.bmp/.gif, .bcf, .dm3, .dm4'], ...
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


function ls = localLineSpec(style)
%LOCALLINESPEC  Return line-spec cell for multi-panel plot style.
    switch style
        case 'Scatter'
            ls = {'LineStyle','none','Marker','o','MarkerSize',5};
        case 'Line+Pts'
            ls = {'LineStyle','-','Marker','o','MarkerSize',4};
        otherwise
            ls = {'LineStyle','-'};
    end
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
        case 'importSIMS',    lbl = 'SIMS Depth Profile';
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
        case 'importSIMS'
            badge = '[SIMS]';
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
%   Delegates to dataplotter.colorMaps for the actual implementation.
    colors = dataplotter.colorMaps(colormapName, nColors);
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


function result = safeEvalMathExpr(expr, vars)
%SAFEEVALMATHEXPR  Evaluate a dataset-math expression without eval().
%   Delegates to dataplotter.safeEvalMathExpr for the actual implementation.
    result = dataplotter.safeEvalMathExpr(expr, vars);
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


