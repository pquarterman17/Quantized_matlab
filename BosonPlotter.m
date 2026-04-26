function varargout = BosonPlotter(options)
%BOSON  Browse, import and preview data files using the +parser toolkit.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   BosonPlotter()
%   api = BosonPlotter()
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
%   api = BosonPlotter() returns a struct of function handles for
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
%   api.undoCorrections()      — restore pre-correction state (legacy single-level)
%   api.undo()                 — undo last operation via UndoManager  [Ctrl+Z]
%   api.redo()                 — redo last undone operation  [Ctrl+Y]
%   api.undoMgr()              — return the live bosonPlotter.UndoManager instance
%   api.autoPeaks()            — run auto peak detection
%   api.fitPeaks()             — fit detected peaks individually
%   api.getPeaks()             — return peaks struct from active dataset
%   api.getModel()             — shared dataWorkspace.WorkspaceModel instance
%   api.setDatasetVisible(idx, vis) — toggle dataset visibility
%   api.saveSession(outPath)   — save session .mat (no dialog)
%   api.loadSession(matPath)   — restore session .mat (no dialog)
%   api.close()                — close figure
%   api.is2DActive()           — true when active dataset is a 2D area-detector map
%   api.setMap2DType(typeStr)  — set '2D plot type' and replot ('Heatmap'|'Contour'|...)
%   api.extractLineCut2D(x,y,isH) — extract 1D slice from 2D map (isH: H-cut vs V-cut)
%   api.boxIntegrate2D(xLo,xHi,yLo,yHi,profileAxis) — integrate box region of 2D map
%   api.setBoxIntSize(w,h)   — set fixed box-integration dimensions ('' to clear)
%   api.arcIntegrate2D(qMin,qMax,nBins,...) — arc integrate I(|Q|) from 2D RSM
%   api.setQSpace(tf)          — enable/disable Q-space axes on 2D map and replot
%   api.setContourLevels(n)    — set number of contour levels for Contour plot types
%   api.setColormap(name)      — set active colormap by name and replot
%   api.setMap2DColormap(name) — set 2D map color scale (e.g. 'parula','viridis','plasma')
%
%   Headless usage (e.g. in test_gui_harness.m):
%     api = BosonPlotter();
%     api.fig.Visible = 'off';
%     api.addFiles({'/path/to/scan.xrdml'});
%     api.autoPeaks();
%     peaks = api.getPeaks();
%     api.close();
%
%   Shared-model usage (linked to DataWorkspace):
%     dwApi = DataWorkspace();           % or DataWorkspace(Visible='off')
%     m = dwApi.getModel();
%     api  = BosonPlotter(Model=m);      % datasets pre-loaded from model
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
%   .plotState     — per-dataset plot-view state: xScale/yScale/y2Scale
%                    ('Linear'|'Log'), gridX/Y ('on'|'off'), xDir/yDir
%                    ('normal'|'reverse'), and 2D map state (colormap,
%                    intensity scale, colorbar limits).  Empty strings
%                    fall back to parser-aware auto defaults.
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

    arguments
        options.Visible (1,1) string {mustBeMember(options.Visible,["on","off"])} = "on"
        options.Model         = []   % existing WorkspaceModel (shared with DataWorkspace)
    end

    % ── Shared application state (handle class — pass-by-reference) ──────
    % Using a handle class enables extracted +bosonPlotter/ functions to
    % mutate state without return-value gymnastics.  All existing
    % appData.X references work unchanged (same dot-syntax as struct).
    appData = bosonPlotter.AppState();

    % Log-scale axes emit "Negative data ignored" from the axes layout
    % manager on every repaint (resize, pan, zoom, hover) when the data
    % contains zeros / negatives — typical for XRD counts. The transparent
    % background export from copy/save falls back to the figure color on
    % renderers that cannot honor alpha and also emits a per-render warning.
    % Both are pure noise for the expected workflow; suppress for the
    % session. Users who need them back can run:
    %   warning('on', 'MATLAB:Axes:NegativeDataInLogAxis')
    %   warning('on', 'MATLAB:print:ReplacingTransparentBackgroundWithDefaultColor')
    warning('off', 'MATLAB:Axes:NegativeDataInLogAxis');
    warning('off', 'MATLAB:print:ReplacingTransparentBackgroundWithDefaultColor');

    % ── Shared WorkspaceModel (observed by DataWorkspace if open) ────────
    % Accept an existing model from DataWorkspace (shared-model mode)
    if ~isempty(options.Model) && isa(options.Model, 'dataWorkspace.WorkspaceModel')
        appData.model = options.Model;
        % Populate datasets from model
        for modelIdx = 1:appData.model.count()
            rawDs = appData.model.datasets{modelIdx};
            ds = buildDs('', rawDs, '');
            if isfield(rawDs, 'metadata')
                md = rawDs.metadata;
                if isfield(md, 'source'),     ds.filepath   = md.source;     end
                if isfield(md, 'parserName'), ds.parserName = md.parserName; end
            end
            appData.datasets{end+1} = ds;
        end
        if ~isempty(appData.datasets)
            appData.activeIdx = 1;
        end
    else
        appData.model = dataWorkspace.WorkspaceModel();
    end

    % Handle to any linked DataWorkspace figure (single-instance enforcement)
    linkedDW = [];

    % Fields with non-default values (overriding AppState property defaults)
    appData.style      = 'Line';
    appData.fringeQ    = [NaN NaN];
    appData.macroLog   = bosonPlotter.actionLog();

    % ── Line caching for performance (nested struct as property) ──
    appData.lineCache  = struct('valid', false, 'left', {{}}, 'right', {{}});

    % ── Undo / redo manager ──────────────────────────────────────────────
    appData.undoMgr = bosonPlotter.UndoManager(MaxSize=50);

    % ── Toolbar configuration: load from prefdir or use factory default ────
    appData.toolbarConfig = loadToolbarConfig();

    % ── Recent files: load from prefdir ──────────────────────────────────
    recentFilePath = fullfile(prefdir, 'boson_recent.mat');
    try
        if isfile(recentFilePath)
            tmp = load(recentFilePath, 'recentFiles');
            if isfield(tmp, 'recentFiles')
                appData.recentFiles = tmp.recentFiles;
            end
        end
    catch
        % Ignore errors loading recent files
    end

    % ── Figure ───────────────────────────────────────────────────────────
    % Detect available screen size and fit the window to it
    screenSz = get(0, 'ScreenSize');  % [1 1 width height]
    availW = screenSz(3);
    availH = screenSz(4);
    initW = min(1080, availW - 40);
    initH = min(1000, availH - 80);  % leave room for menu bar / dock
    initX = max(20, round((availW - initW) / 2));
    initY = max(40, round((availH - initH) / 2));
    % Headless mode: figure starts hidden and popup dialogs stay hidden.
    % Triggered by Visible='off' (used by tests).  For full focus-steal
    % suppression on Windows, run via tests/run_gui_hidden.ps1.
    headless = options.Visible == "off";
    figArgs = {'Name','Data Import & Preview', ...
               'Position',[initX initY initW initH], ...
               'AutoResizeChildren','off'};
    if headless
        % Visible='off' + off-screen position + callback-hidden.
        % On Windows, drawnow can activate invisible uifigures and
        % steal focus.  Pushing the window off-screen and suppressing
        % HandleVisibility prevents taskbar presence and focus theft.
        figArgs = [figArgs, {'Visible','off','HandleVisibility','off', ...
                             'Position',[-9999 -9999 initW initH]}];
    end
    fig = uifigure(figArgs{:});
    % UX design tokens — see +bosonPlotter/uxTokens.m for the scale.
    tk = bosonPlotter.uxTokens();
    % Expose the macro log on the figure so `bosonPlotter.exportScript(fig, ...)`
    % and other free-function helpers can find it without an `api` reference.
    setappdata(fig, 'macroLog', appData.macroLog);
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

    % ── Top-level menu bar ───────────────────────────────────────────────
    % Pure builder in +bosonPlotter/buildMenuBar.m wired with the nested-
    % function handles below. Mirrors the right-click context menus.
    menuCb = struct( ...
        'onAddFiles',@onAddFiles, 'onBatchImportDir',@onBatchImportDir, 'onBatchConvertXRD',@onBatchConvertXRD, ...
        'onSaveSession',@onSaveSession, 'onLoadSession',@onLoadSession, ...
        'onOpenSettings',@onOpenSettings, 'onOpenLayoutSettings',@onOpenLayoutSettings, ...
        'onUndoCorrections',@onUndoCorrections, 'onResetCorrections',@onResetCorrections, 'onApplyCorrectionsAll',@onApplyCorrectionsAll, ...
        'onArmMaskSelection',@onArmMaskSelection, 'onUnmaskAll',@onUnmaskAll, ...
        'onEditAxisLabelsMenu',@onEditAxisLabelsMenu, 'onOpenLegendEditor',@onOpenLegendEditor, 'onEditColumnMapping',@onEditColumnMapping, ...
        'onSmartScale',@onSmartScale, 'onAutoLimits',@onAutoLimits, 'onToggleDataCursor',@onToggleDataCursor, 'onWaterfallToggled',@onWaterfallToggled, ...
        'onAddHRefLine',@onAddHRefLine, 'onAddVRefLine',@onAddVRefLine, 'onClearRefLines',@onClearRefLines, 'onClearFitOverlays',@onClearFitOverlays, ...
        'onCreateInsetFromMenu',@onCreateInsetFromMenu, 'onRemoveInset',@onRemoveInset, ...
        'onCustomiseToolbar',@onCustomiseToolbar, 'onPlot',@onPlot, ...
        'onSaveCSV',@onSaveCSV, 'onBatchExportCSV',@onBatchExportCSV, 'onExportHDF5',@onExportHDF5, 'onCopyDataToClipboard',@onCopyDataToClipboard, ...
        'onSendToOrigin',@onSendToOrigin, 'onExportOriginScript',@onExportOriginScript, ...
        'onConvertUnits',@onConvertUnits, 'onResampleDataset',@onResampleDataset, 'onColumnCalculator',@onColumnCalculator, ...
        'onDatasetMath',@onDatasetMath, 'onDatasetAlgebra',@onDatasetAlgebra, 'onMergeDatasets',@onMergeDatasets, ...
        'showPeakWindow',@showPeakWindow, 'onEstimateBaseline',@onEstimateBaseline, 'onFitBGRegion',@onFitBGRegion, 'onApplyCorrections',@onApplyCorrections, ...
        'onWilliamsonHallPlot',@onWilliamsonHallPlot, 'onReflectivityFFT',@onReflectivityFFT, 'onFFTThickness',@onFFTThickness, ...
        'onRefineLattice',@onRefineLattice, 'onMatchPhases',@onMatchPhases, ...
        'onPoleFigure',@onPoleFigure, 'onDecomposeRSM',@onDecomposeRSM, 'onAdvAsymmetry',@onAdvAsymmetry, 'onShowAdvancedMenu',@onShowAdvancedMenu, ...
        'onPlotTemplates',@onPlotTemplates, 'onOpenPlotStyleDialog',@onOpenPlotStyleDialog, 'onAdvancedFigureBuilder',@onAdvancedFigureBuilder, ...
        'onComposeFigure',@onComposeFigure, 'onBatchFigureExport',@onBatchFigureExport, 'onPolarPlot',@onPolarPlot, ...
        'onToggleMacroRecord',@onToggleMacroRecord, 'onExportMacro',@onExportMacro, ...
        'onToggleWatchFile',@onToggleWatchFile, 'onToggleSinglePrecision',@onToggleSinglePrecision, ...
        'onShowShortcuts',@onShowShortcuts, 'onReportBug',@(~,~) onReportBug());
    bosonPlotter.buildMenuBar(fig, menuCb);

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
    BTN_INTERACT  = [0.50 0.28 0.05];  % amber  — interactive plot-click tools (Fit BG, Est Y, Peak)
    BTN_ANIMATE   = [0.50 0.35 0.15];  % warm amber — animation / playback
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
        'Padding',      tk.pad.comfortable, ...
        'RowSpacing',   4, ...
        'ColumnSpacing', 0);

    % ── Content row: [Files | Controls | Preview] ─────────────────────────
    % File-list column is narrow; controls column fixed; preview fills remainder.
    contentGL = uigridlayout(rootGL,[1 3], ...
        'ColumnWidth',  {180, 190, '1x'}, ...
        'Padding',      tk.pad.flush, ...
        'ColumnSpacing', 6);
    contentGL.Layout.Row = 1; contentGL.Layout.Column = 1;

    % ── File list panel (contentGL col 1, scrollable) ──────────────────────
    % Wrapped in a scrollable panel so buttons + listbox are never clipped.
    fileListPanel = uipanel(contentGL, 'BorderType', 'none', 'Scrollable', 'on');
    fileListPanel.Layout.Row = 1; fileListPanel.Layout.Column = 1;

    % Stacked vertically: Add | Batch | Remove | Filter | Merge | Up/Down | Groups | Animate/Shortcuts | Settings | Listbox
    tbGL = uigridlayout(fileListPanel,[10 2], ...
        'RowHeight',    {22,22,22,22,22,22,22,22,22,'1x'}, ...
        'ColumnWidth',  {'1x','1x'}, ...
        'Padding',      tk.pad.flush, ...
        'RowSpacing',   2, ...
        'ColumnSpacing', 3);

    btnBrowse = uibutton(tbGL,'Text','Add File(s)...', ...
        'ButtonPushedFcn',@onAddFiles, ...
        'BackgroundColor',BTN_PRIMARY, ...
        'FontColor',BTN_FG,'FontWeight','bold', ...
        'Tooltip','Browse for one or more data files — each is added as a new dataset');
    btnBrowse.Layout.Row = 1; btnBrowse.Layout.Column = 1;

    ddRecent = uidropdown(tbGL, ...
        'Items', {'(recent)'}, ...
        'Value', '(recent)', ...
        'FontSize', tk.font.label, ...
        'ValueChangedFcn', @onRecentFileSelected, ...
        'Tooltip', 'Open a recently loaded file');
    ddRecent.Layout.Row = 1; ddRecent.Layout.Column = 2;

    % Row 2: Batch Import | Batch XRD Convert
    btnBatchImport = uibutton(tbGL,'Text','Batch Import...', ...
        'ButtonPushedFcn',@onBatchImportDir, ...
        'BackgroundColor',BTN_PRIMARY, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Import all supported files from a directory (recursive)');
    btnBatchImport.Layout.Row = 2; btnBatchImport.Layout.Column = 1;

    btnBatchConvertXRD2 = uibutton(tbGL,'Text','Batch XRD...', ...
        'ButtonPushedFcn',@onBatchConvertXRD, ...
        'BackgroundColor',BTN_PRIMARY, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Batch convert XRD files between formats');
    btnBatchConvertXRD2.Layout.Row = 2; btnBatchConvertXRD2.Layout.Column = 2;

    btnRemoveDS = uibutton(tbGL,'Text','Remove Selected', ...
        'ButtonPushedFcn',@onRemoveDataset, ...
        'BackgroundColor',BTN_DANGER, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Remove the highlighted dataset from the list (also: right-click or press Delete)');
    btnRemoveDS.Layout.Row = 3; btnRemoveDS.Layout.Column = [1 2];

    % Row 4: filter field + ✕ clear button (sub-grid so the button doesn't
    % squeeze the text field — matches the grpGL row-7 pattern).
    searchGL = uigridlayout(tbGL,[1 2], ...
        'Padding', tk.pad.flush,'ColumnSpacing',2, ...
        'ColumnWidth',{'1x', 20});
    searchGL.Layout.Row = 4; searchGL.Layout.Column = [1 2];

    efDatasetSearch = uieditfield(searchGL,'text','Value','', ...
        'Placeholder','Filter datasets...', ...
        'Tooltip','Filter the dataset list by name (case-insensitive substring match)', ...
        'ValueChangedFcn',@onSearchChanged);
    efDatasetSearch.Layout.Column = 1;

    btnClearSearch = uibutton(searchGL,'Text',char(10005), ...
        'ButtonPushedFcn',@(~,~) clearDatasetSearch(), ...
        'FontSize', tk.font.body, ...
        'Tooltip','Clear the dataset filter');
    btnClearSearch.Layout.Column = 2; %#ok<NASGU>

    btnMerge = uibutton(tbGL,'Text','Merge Selected', ...
        'ButtonPushedFcn',@onMergeDatasets, ...
        'BackgroundColor',BTN_ACCENT, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Concatenate 2+ selected datasets into a new merged dataset (sorted by X)');
    btnMerge.Layout.Row = 5; btnMerge.Layout.Column = 1;

    btnDatasetMath = uibutton(tbGL,'Text','Dataset Math...', ...
        'ButtonPushedFcn',@onDatasetMath, ...
        'BackgroundColor',BTN_ACCENT, ...
        'FontColor',BTN_FG, ...
        'Tooltip','Create derived datasets via expressions: D1/D2, log10(D1), diff(D1), D1-D2, D1*D2');
    btnDatasetMath.Layout.Row = 5; btnDatasetMath.Layout.Column = 2;

    btnMoveUp = uibutton(tbGL,'Text',[char(9650) ' Up'], ...
        'ButtonPushedFcn',@onMoveDatasetUp, ...
        'Tooltip','Move the active dataset up in the list (Ctrl+Up)');
    btnMoveUp.Layout.Row = 6; btnMoveUp.Layout.Column = 1;

    btnMoveDown = uibutton(tbGL,'Text',[char(9660) ' Down'], ...
        'ButtonPushedFcn',@onMoveDatasetDown, ...
        'Tooltip','Move the active dataset down in the list (Ctrl+Down)');
    btnMoveDown.Layout.Row = 6; btnMoveDown.Layout.Column = 2;

    % Row 7: Dataset Groups — dropdown + add/remove
    grpGL = uigridlayout(tbGL,[1 3], ...
        'Padding', tk.pad.flush,'ColumnSpacing',2, ...
        'ColumnWidth',{'1x',36,20});
    grpGL.Layout.Row = 7; grpGL.Layout.Column = [1 2];

    ddGroup = uidropdown(grpGL, ...
        'Items',{'All Datasets'}, ...
        'Value','All Datasets', ...
        'Editable','on', ...
        'FontSize', tk.font.label, ...
        'Tooltip',['Filter by group. Type a new name and press Enter to create. ' ...
                   'Select a group to filter the list.'], ...
        'ValueChangedFcn',@onGroupChanged);
    ddGroup.Layout.Column = 1;

    btnAddToGroup = uibutton(grpGL,'Text','+Grp', ...
        'ButtonPushedFcn',@onAddToGroup, ...
        'FontSize', tk.font.body, ...
        'Tooltip','Add selected dataset(s) to the current group');
    btnAddToGroup.Layout.Column = 2;

    btnRemoveFromGroup = uibutton(grpGL,'Text',char(10005), ...
        'ButtonPushedFcn',@onRemoveFromGroup, ...
        'FontSize', tk.font.body, ...
        'Tooltip','Remove selected dataset(s) from the current group');
    btnRemoveFromGroup.Layout.Column = 3;

    % Animate lives on the axes toolbar (tbActions 'animate'); the
    % file-list duplicate was removed (repo-audit W2 #23).
    btnShortcuts = uibutton(tbGL,'Text','?  Shortcuts', ...
        'ButtonPushedFcn',@onShowShortcuts, ...
        'BackgroundColor',BTN_TOOL, ...
        'FontColor', tk.color.textMuted, ...
        'FontSize', tk.font.label, ...
        'Tooltip','Show keyboard shortcuts');
    btnShortcuts.Layout.Row = 8; btnShortcuts.Layout.Column = [1 2];

    btnSettings = uibutton(tbGL,'Text',[char(9881) '  Settings...'], ...
        'ButtonPushedFcn',@(~,~) onOpenSettings(), ...
        'BackgroundColor',BTN_TOOL, ...
        'FontColor', tk.color.textHighlight, ...
        'FontSize', tk.font.label, ...
        'Tooltip','Theme, plot style, and other global preferences');
    btnSettings.Layout.Row = 9; btnSettings.Layout.Column = [1 2];

    lbDatasets = uilistbox(tbGL, ...
        'Items',     {'(no files loaded — click  Add File(s)...  to begin)'}, ...
        'ItemsData', {0}, ...
        'Multiselect','on', ...
        'ValueChangedFcn',@onSelectDataset, ...
        'Tooltip','Loaded datasets — click to make active; Ctrl+click to select multiple; right-click to remove');
    lbDatasets.Layout.Row = 10; lbDatasets.Layout.Column = [1 2];

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
        uimenu(cmDatasets, 'Text', 'Notes...', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) onDatasetMetaEdit('notes'));
        uimenu(cmDatasets, 'Text', 'Rename...', ...
            'MenuSelectedFcn', @(~,~) onDatasetMetaEdit('rename'));
        uimenu(cmDatasets, 'Text', 'Reload from Disk', ...
            'MenuSelectedFcn', @(~,~) onDatasetMetaEdit('reload'));
        uimenu(cmDatasets, 'Text', 'Edit Column Mapping...', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) onEditColumnMapping());
        uimenu(cmDatasets, 'Text', 'Save as Template...', ...
            'MenuSelectedFcn', @(~,~) onSaveAsTemplate());
        lbDatasets.ContextMenu = cmDatasets;
    catch
        % R2022a/R2022b: uicontextmenu not supported on uifigure — skip silently.
        % Users can still use toolbar buttons for these operations.
    end

    % Left controls panel
    % Title updates to show parser name after each load.
    % Row layout (9 rows):
    %   1 -  24px  X dropdown
    %   2 -  '2x'  Y listbox (multi-select)
    %   3 -  '1x'  Right Y-axis selector
    %   4 -  44px  Colormap + template selectors
    %   5 -  66px  Linear/Log scale dropdowns (X, Y, Y2)
    %   6 - 110px  Axis limits (X/Y/Y2 min/max + fmt) + Auto/Reset
    %   7 -  22px  Waterfall + spacing
    %   8 -  22px  Cts/s + Refresh
    %   9 -  20px  Annotate + Style + Plot Options
    ctrlPanel = uipanel(contentGL,'Title','Controls','FontSize', tk.font.title, ...
        'Scrollable','on');
    ctrlPanel.Layout.Column = 2;

    ctrlGL = uigridlayout(ctrlPanel,[9 1], ...
        'RowHeight', {24,'2x','1x',44,66,110,22,22,20}, ...
        'Padding',   tk.pad.normal, ...
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
        'Padding', tk.pad.flush,'RowSpacing',1,'ColumnSpacing',3, ...
        'RowHeight',{16,'1x'},'ColumnWidth',{'1x'});
    y2GL.Layout.Row = 3;

    lblY2 = uilabel(y2GL,'Text','Right Y-axis:', ...
        'FontSize',12,'FontColor', tk.color.textMuted);
    lblY2.Layout.Row = 1; lblY2.Layout.Column = 1;

    lbY2 = uilistbox(y2GL,'Items',{'(none)'},'Multiselect','on', ...
        'Value',{'(none)'}, ...
        'Tooltip','Right Y-axis channel(s) — plotted against the right-hand scale', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    lbY2.Layout.Row = 2; lbY2.Layout.Column = 1;

    % Colormap + Template selectors (row 4) — two stacked sub-rows
    styleGL = uigridlayout(ctrlGL,[2 4], ...
        'Padding', tk.pad.flush,'ColumnSpacing',2,'RowSpacing',2, ...
        'ColumnWidth',{'1x','1x','1x','1x'},'RowHeight',{18,18});
    styleGL.Layout.Row = 4;

    lblColormap = uilabel(styleGL,'Text','Colormap:','FontSize', tk.font.label);
    lblColormap.Layout.Row = 1; lblColormap.Layout.Column = 1;

    COLORMAPS = {'lines (MATLAB default)', 'jet', 'turbo', 'hot', 'cool', ...
                 'spring', 'summer', 'autumn', 'winter', 'gray', 'copper', ...
                 'pink', 'bone', 'hsv', 'parula', 'viridis', 'plasma', 'inferno'};
    ddColormap = uidropdown(styleGL, 'Items', COLORMAPS, 'Value', COLORMAPS{1}, ...
        'Tooltip', 'Color palette for multi-dataset plots', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddColormap.Layout.Row = 1; ddColormap.Layout.Column = [2 4];

    % ── Template selector (Phase A) ─────────────────────────────────
    % Selects a built-in visual template (screen / aps / nature / thesis /
    % presentation / poster) or a user-saved template.  Changes font,
    % line width, marker size, tick direction, grid, etc. on the live
    % preview so the GUI is WYSIWYG with exported figures.
    lblTemplate = uilabel(styleGL,'Text','Template:','FontSize', tk.font.label);
    lblTemplate.Layout.Row = 2; lblTemplate.Layout.Column = 1;

    BUILTIN_TEMPLATES = {'screen','aps','aps_double','nature','nature_double', ...
                         'thesis','presentation','poster'};
    tplItems = BUILTIN_TEMPLATES;
    try
        userList = bosonPlotter.userTemplates.list();
        for utIdx = 1:numel(userList)
            tplItems{end+1} = ['user:' userList{utIdx}]; %#ok<AGROW>
        end
    catch
    end
    ddTemplate = uidropdown(styleGL, 'Items', tplItems, ...
        'Value', 'screen', ...
        'Tooltip', ['Visual template (font / line width / marker size / ' ...
                    'tick direction / grid).  Built-ins: screen (default), ' ...
                    'aps, nature, thesis, presentation, poster.  User ' ...
                    'templates appear with a "user:" prefix.'], ...
        'ValueChangedFcn', @onTemplateChanged);
    ddTemplate.Layout.Row = 2; ddTemplate.Layout.Column = [2 4];

    % Theme value stored here but UI moved to Settings dialog
    appData.theme = 'Light';

    % Row 5: Axis scale dropdowns (3 rows: X, Left Y, Right Y)
    scaleGL = uigridlayout(ctrlGL,[3 2], ...
        'Padding', tk.pad.flush,'RowSpacing',2,'ColumnSpacing',4, ...
        'RowHeight',{20,20,20},'ColumnWidth',{55,'1x'});
    scaleGL.Layout.Row = 5;

    lblScaleX = uilabel(scaleGL,'Text','X axis:','FontSize', tk.font.title);
    lblScaleX.Layout.Row = 1; lblScaleX.Layout.Column = 1;
    ddScaleX = uidropdown(scaleGL,'Items',{'Linear','Log'}, ...
        'Value','Linear','FontSize', tk.font.title, ...
        'ValueChangedFcn',@onAxisChanged, ...
        'Tooltip','X-axis scale');
    ddScaleX.Layout.Row = 1; ddScaleX.Layout.Column = 2;

    lblScaleY = uilabel(scaleGL,'Text','Left Y:','FontSize', tk.font.title);
    lblScaleY.Layout.Row = 2; lblScaleY.Layout.Column = 1;
    ddScaleY = uidropdown(scaleGL,'Items',{'Linear','Log'}, ...
        'Value','Linear','FontSize', tk.font.title, ...
        'ValueChangedFcn',@onAxisChanged, ...
        'Tooltip','Left Y-axis scale');
    ddScaleY.Layout.Row = 2; ddScaleY.Layout.Column = 2;

    lblScaleY2 = uilabel(scaleGL,'Text','Right Y:','FontSize', tk.font.title);
    lblScaleY2.Layout.Row = 3; lblScaleY2.Layout.Column = 1;
    ddScaleY2 = uidropdown(scaleGL,'Items',{'Linear','Log'}, ...
        'Value','Linear','FontSize', tk.font.title, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]), ...
        'Tooltip','Right Y-axis scale');
    ddScaleY2.Layout.Row = 3; ddScaleY2.Layout.Column = 2;

    % Row 6: Axis limits (X/Y/Y2 min/max + fmt) + Auto/Reset
    % Replaces the old standalone Axes panel (analysisGL col 2 row 1) so
    % limits live next to the Linear/Log scale dropdowns they're paired
    % with. Step inputs, color override, legend location, and title /
    % labels / ref lines moved to right-click and Plot Options ▾ menus.
    AXLIM_BG = [0.17 0.17 0.17];
    AXLIM_FG = [0.92 0.92 0.92];
    limGL = uigridlayout(ctrlGL,[4 4], ...
        'Padding', tk.pad.flush,'RowSpacing',2,'ColumnSpacing',3, ...
        'RowHeight',{20,20,20,22},'ColumnWidth',{18,'1x','1x',60});
    limGL.Layout.Row = 6;

    % Row 1: X limits + format
    lblXLim = uilabel(limGL,'Text','X:','HorizontalAlignment','right','FontSize', tk.font.label);
    lblXLim.Layout.Row = 1; lblXLim.Layout.Column = 1;
    efXMin = uieditfield(limGL,'text','Value','', ...
        'Placeholder','min', 'Tooltip','X axis minimum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'FontSize', tk.font.body, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXMin.Layout.Row = 1; efXMin.Layout.Column = 2;
    efXMax = uieditfield(limGL,'text','Value','', ...
        'Placeholder','max', 'Tooltip','X axis maximum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'FontSize', tk.font.body, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efXMax.Layout.Row = 1; efXMax.Layout.Column = 3;
    ddXFmt = uidropdown(limGL, 'Items', TICKFMT_NAMES, 'ItemsData', TICKFMT_DATA, ...
        'Value', '', 'FontSize', tk.font.body, 'Tooltip', 'X-axis tick label notation', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddXFmt.Layout.Row = 1; ddXFmt.Layout.Column = 4;

    % Row 2: Y limits + format
    lblYLim = uilabel(limGL,'Text','Y:','HorizontalAlignment','right','FontSize', tk.font.label);
    lblYLim.Layout.Row = 2; lblYLim.Layout.Column = 1;
    efYMin = uieditfield(limGL,'text','Value','', ...
        'Placeholder','min', 'Tooltip','Y axis minimum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'FontSize', tk.font.body, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYMin.Layout.Row = 2; efYMin.Layout.Column = 2;
    efYMax = uieditfield(limGL,'text','Value','', ...
        'Placeholder','max', 'Tooltip','Y axis maximum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'FontSize', tk.font.body, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYMax.Layout.Row = 2; efYMax.Layout.Column = 3;
    ddYFmt = uidropdown(limGL, 'Items', YTICKFMT_NAMES, 'ItemsData', YTICKFMT_DATA, ...
        'Value', '__exp0', 'FontSize', tk.font.body, 'Tooltip', 'Left Y-axis tick label notation', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddYFmt.Layout.Row = 2; ddYFmt.Layout.Column = 4;

    % Row 3: Y2 limits + format (RowHeight toggled to 0 when no Y2 active)
    lblY2Lim = uilabel(limGL,'Text','Y2:','HorizontalAlignment','right','FontSize', tk.font.label);
    lblY2Lim.Layout.Row = 3; lblY2Lim.Layout.Column = 1;
    efY2Min = uieditfield(limGL,'text','Value','', ...
        'Placeholder','min', 'Tooltip','Right Y-axis minimum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'FontSize', tk.font.body, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efY2Min.Layout.Row = 3; efY2Min.Layout.Column = 2;
    efY2Max = uieditfield(limGL,'text','Value','', ...
        'Placeholder','max', 'Tooltip','Right Y-axis maximum — blank = auto', ...
        'BackgroundColor', AXLIM_BG, 'FontColor', AXLIM_FG, 'FontSize', tk.font.body, ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efY2Max.Layout.Row = 3; efY2Max.Layout.Column = 3;
    ddY2Fmt = uidropdown(limGL, 'Items', YTICKFMT_NAMES, 'ItemsData', YTICKFMT_DATA, ...
        'Value', '', 'FontSize', tk.font.body, 'Tooltip', 'Right Y-axis tick label notation', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    ddY2Fmt.Layout.Row = 3; ddY2Fmt.Layout.Column = 4;

    % Row 4: Auto-Scale + Reset
    btnSmartScale = uibutton(limGL,'Text','Auto', ...
        'ButtonPushedFcn',@onSmartScale, 'FontSize', tk.font.body, ...
        'Tooltip','Auto-detect linear/log scale and set reasonable axis limits');
    btnSmartScale.Layout.Row = 4; btnSmartScale.Layout.Column = [1 2];
    btnAutoLimits = uibutton(limGL,'Text','Reset', ...
        'ButtonPushedFcn',@onAutoLimits, 'FontSize', tk.font.body, ...
        'Tooltip',['Reset View — clear manual axis limits and per-dataset' newline ...
                   'plot state (log/linear, grid, direction, 2D cmap/cLim)' newline ...
                   'so this dataset returns to auto defaults.']);
    btnAutoLimits.Layout.Row = 4; btnAutoLimits.Layout.Column = [3 4];

    % Row 7: Waterfall toggle + spacing
    wfGL = uigridlayout(ctrlGL,[1 2], ...
        'Padding', tk.pad.flush,'ColumnSpacing',4,'ColumnWidth',{'1x',50});
    wfGL.Layout.Row = 7;

    cbWaterfall = uicheckbox(wfGL, ...
        'Text',    'Waterfall', ...
        'Value',   false, ...
        'Tooltip', 'Waterfall: stack datasets vertically with a uniform Y offset', ...
        'ValueChangedFcn', @(~,~) onWaterfallToggled());
    cbWaterfall.Layout.Column = 1;

    efWaterfallSpacing = uieditfield(wfGL, 'numeric', 'Value', 0, ...
        'Limits', [0 Inf], 'AllowEmpty', 'on', ...
        'Tooltip', 'Spacing between stacked traces in data units — 0 or empty = auto (1.1× max data range)', ...
        'ValueDisplayFormat', '%.4g', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efWaterfallSpacing.Layout.Column = 2;

    % Waterfall gradient coloring (stored in appData, no separate widget)
    appData.wfGradient = false;

    % Row 8: Cts/s + Refresh
    miscGL = uigridlayout(ctrlGL,[1 2], ...
        'Padding', tk.pad.flush,'ColumnSpacing',4,'ColumnWidth',{'1x',55});
    miscGL.Layout.Row = 8;

    cbCountsPerSec = uicheckbox(miscGL,'Text','Cts/s', ...
        'Value', false, 'Enable', 'off', ...
        'Tooltip', 'Divide intensity by counting time (counts → counts/s). XRD files only.', ...
        'ValueChangedFcn', @onAxisChanged);
    cbCountsPerSec.Layout.Column = 1;

    btnPlot = uibutton(miscGL,'Text','Refresh','ButtonPushedFcn',@onPlot, ...
    'Tooltip','Force a full redraw of the current plot');
    btnPlot.Layout.Column = 2;

    % Row 9: Annotation mode + Style… + Plot Options button
    annotPlotGL = uigridlayout(ctrlGL,[1 3], ...
        'Padding', tk.pad.flush,'ColumnSpacing',3, ...
        'ColumnWidth',{'1x','1x','1x'});
    annotPlotGL.Layout.Row = 9;

    cbAnnotationMode = uicheckbox(annotPlotGL, ...
        'Text',    'Annotate', ...
        'Value',   false, ...
        'Tooltip', 'Click on the plot to add text annotations. Right-click to delete.', ...
        'ValueChangedFcn', @onAnnotationModeChanged);
    cbAnnotationMode.Layout.Column = 1;

    btnPlotStyle = uibutton(annotPlotGL,'Text','Style…', ...
        'ButtonPushedFcn',@(~,~) onOpenPlotStyleDialog(), ...
        'BackgroundColor',[0.35 0.40 0.55],'FontColor',[1 1 1], ...
        'FontSize', tk.font.label, ...
        'Tooltip','Fine-grained visual overrides: font, line width, marker, grid, legend (Phase B)');
    btnPlotStyle.Layout.Column = 2;

    btnPlotOptions = uibutton(annotPlotGL,'Text',['Plot ' char(9662)], ...
        'ButtonPushedFcn',@onShowPlotOptionsMenu, ...
        'BackgroundColor',[0.22 0.35 0.55],'FontColor',[1 1 1], ...
        'FontSize', tk.font.label, ...
        'Tooltip','Plot types, visualization options, and unit conversion');
    btnPlotOptions.Layout.Column = 3;

    % ── Right: preview axes ───────────────────────────────────────────────
    axPanel = uipanel(contentGL,'Title','Preview','FontSize', tk.font.title);
    axPanel.Layout.Column = 3;
    axGL = uigridlayout(axPanel,[3 1],'Padding', tk.pad.tight,'RowSpacing',1, ...
        'RowHeight',{18,'1x',20});

    % ── Dynamic axes toolbar (right-aligned buttons, order from user prefs) ──
    % The toolbar is built/rebuilt by buildToolbar().  A single-row grid with
    % N+1 columns is created here; column widths are set dynamically.
    axToolbarGL = uigridlayout(axGL,[1 1],'Padding', tk.pad.flush,'ColumnSpacing',2);
    axToolbarGL.Layout.Row = 1;

    % ── Action registry — ALL available toolbar actions ────────────────────
    %
    % Each action carries the metadata needed to render the button:
    %   id        — stable identifier (also resolves icons/bosonplotter/<id>.png)
    %   label     — text shown next to the icon (icon+text buttons) or used
    %               as a fallback if the icon PNG is missing
    %   tooltip   — hover text; includes [Ctrl+...] hint where applicable
    %   callback  — the button's action
    %   iconOnly  — true: render as a 28px square icon-only button.
    %               false: icon + label, width auto-sized via 'fit'
    %   group     — visual grouping key. Adjacent buttons sharing a group
    %               sit flush; group transitions get a 6px spacer column.
    %
    % Lucide icon names are documented in icons/bosonplotter/build_icons.m.
    % Filenames mirror id.png (e.g. cursor → cursor.png).
    tbActions = struct('id', {}, 'label', {}, 'tooltip', {}, 'callback', {}, ...
                       'iconOnly', {}, 'group', {});
    tbActions(end+1) = struct('id','cursor',         'label','Cursor', ...
        'tooltip','Toggle data cursor — click to read (x,y), click again for delta', ...
        'callback',@(~,~) onToggleDataCursor([],[]), 'iconOnly',true,  'group','view');
    tbActions(end+1) = struct('id','autoscale',      'label','Auto', ...
        'tooltip','Reset all axis limits to auto-scale', ...
        'callback',@(~,~) onAutoLimits([],[]),       'iconOnly',true,  'group','view');
    tbActions(end+1) = struct('id','clearOverlays',  'label','Clear', ...
        'tooltip','Clear all overlays (fringe markers, peaks, masks, cursors, zoom boxes, annotations)', ...
        'callback',@(~,~) onClearOverlays([],[]),    'iconOnly',false, 'group','view');
    tbActions(end+1) = struct('id','grid',           'label','Grid', ...
        'tooltip','Toggle grid lines on/off', ...
        'callback',@(~,~) onContextToggle('grid'),   'iconOnly',true,  'group','view');
    tbActions(end+1) = struct('id','legend',         'label','Legend', ...
        'tooltip','Toggle legend visibility', ...
        'callback',@(~,~) onToolbarLegendToggle([],[]), 'iconOnly',false, 'group','view');
    tbActions(end+1) = struct('id','zoomIn',         'label','Zoom In', ...
        'tooltip','Zoom in (set axis limits to visible range)', ...
        'callback',@(~,~) onZoomInToolbar(),         'iconOnly',true,  'group','navigate');
    tbActions(end+1) = struct('id','zoomOut',        'label','Zoom Out', ...
        'tooltip','Zoom out one step', ...
        'callback',@(~,~) onZoomOutToolbar(),        'iconOnly',true,  'group','navigate');
    tbActions(end+1) = struct('id','pan',            'label','Pan', ...
        'tooltip','Enable pan mode on plot axes', ...
        'callback',@(~,~) onPanToolbar(),            'iconOnly',true,  'group','navigate');
    tbActions(end+1) = struct('id','copy',           'label','Copy', ...
        'tooltip','Copy plot to clipboard  [Ctrl+C]', ...
        'callback',@(~,~) onCopyPlotToClipboard(),   'iconOnly',false, 'group','output');
    tbActions(end+1) = struct('id','save',           'label','Save', ...
        'tooltip','Export figure as PNG / PDF / SVG / EPS', ...
        'callback',@(~,~) onExportFigure([],[]),     'iconOnly',false, 'group','output');
    tbActions(end+1) = struct('id','export',         'label','Export Data', ...
        'tooltip','Export active dataset data to CSV  [Ctrl+E]', ...
        'callback',@(~,~) onSaveCSV([],[]),          'iconOnly',false, 'group','output');
    tbActions(end+1) = struct('id','figBuilder',     'label','Figure Builder', ...
        'tooltip','Open the Figure Builder for publication-quality figures', ...
        'callback',@(~,~) onAdvancedFigureBuilder([],[]), 'iconOnly',false, 'group','output');
    tbActions(end+1) = struct('id','animate',        'label','Animate', ...
        'tooltip','Animate dataset sequence', ...
        'callback',@(~,~) onToggleAnimation([],[]),  'iconOnly',false, 'group','data');
    tbActions(end+1) = struct('id','workspace',      'label','Data Table', ...
        'tooltip','Open shared DataWorkspace (single instance; right-click for new window)', ...
        'callback',@(~,~) openLinkedDataWorkspace(), 'iconOnly',false, 'group','data');
    tbActions(end+1) = struct('id','watchFile',      'label','Watch', ...
        'tooltip','Toggle live file watch: auto-reload and replot when the source file changes on disk', ...
        'callback',@(~,~) onToggleWatchFile(),       'iconOnly',false, 'group','data');
    tbActions(end+1) = struct('id','undo',           'label','Undo', ...
        'tooltip','Undo last operation  [Ctrl+Z]', ...
        'callback',@(s,e) appData.undoCb.onUndo(s,e), 'iconOnly',true, 'group','history');
    tbActions(end+1) = struct('id','redo',           'label','Redo', ...
        'tooltip','Redo last undone operation  [Ctrl+Y]', ...
        'callback',@(s,e) appData.undoCb.onRedo(s,e), 'iconOnly',true, 'group','history');

    % Build toolbar for the first time
    buildToolbar(axToolbarGL, appData.toolbarConfig, tbActions, BTN_TOOL);

    ax = uiaxes(axGL);
    ax.Layout.Row = 2;
    ax.Box = 'on';
    grid(ax,'on');
    title(ax,'Load a file to preview data','Interpreter','none');
    xlabel(ax,'');
    ylabel(ax,'');

    % ── Persistent cursor readout panel (row 3 of axGL) ───────────────────
    cursorPanelObj = bosonPlotter.cursorPanel(axGL, 3, ax, @() appData);

    % Table state (UI built later in dataTablePanel after analysisGL is created)
    appData.tableVisible    = true;   % visible by default in analysis area
    appData.tableWorkingCopy = [];
    appData.tableUnits       = {};
    appData.tableMask       = [];
    appData.tableEdited     = false;
    appData.tableRowCap     = 500;    % max rows displayed in uitable (perf cap)
    appData.filterMask      = [];     % [N×1] logical from filter bar; [] = no filter
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

        % Tools
        uimenu(cmAxes, 'Text', 'Toggle Data Cursor', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) onToggleDataCursor([], []));

        % Label editing (via double-click on plot labels or this menu entry)
        uimenu(cmAxes, 'Text', 'Edit Axis Labels...', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) onEditAxisLabelsMenu());
        uimenu(cmAxes, 'Text', 'Edit Legend...', ...
            'MenuSelectedFcn', @(~,~) onOpenLegendEditor());

        % Actions
        uimenu(cmAxes, 'Text', 'Auto-Scale', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) onAutoLimits([], []));
        uimenu(cmAxes, 'Text', 'Set Axis Limits...', ...
            'MenuSelectedFcn', @(~,~) onSetAxisLimitsMenu());
        uimenu(cmAxes, 'Text', 'Set Tick Spacing...', ...
            'MenuSelectedFcn', @(~,~) onSetTickSpacingMenu());

        % Legend Location ▸ submenu — replaces the deleted in-panel dropdown.
        smLegLoc = uimenu(cmAxes, 'Text', 'Legend Location');
        LEG_LOCS = {'best','NE','NW','SE','SW','EastOutside','off'};
        for il_ = 1:numel(LEG_LOCS)
            uimenu(smLegLoc, 'Text', LEG_LOCS{il_}, ...
                'MenuSelectedFcn', @(s,~) onContextSetLegendLoc(s.Text));
        end

        % Dataset Color ▸ submenu — replaces the deleted in-panel dropdown.
        smDsColor = uimenu(cmAxes, 'Text', 'Dataset Color');
        for ic_ = 1:numel(DS_COLOR_NAMES)
            uimenu(smDsColor, 'Text', DS_COLOR_NAMES{ic_}, ...
                'MenuSelectedFcn', @(s,~) onContextSetDatasetColor(s.Text));
        end

        uimenu(cmAxes, 'Text', 'Copy Plot (Vector)', ...
            'MenuSelectedFcn', @(~,~) onCopyPlotToClipboard());
        uimenu(cmAxes, 'Text', 'Copy as PNG', ...
            'MenuSelectedFcn', @(~,~) onCopyToClipboardAsPNG([], []));
        uimenu(cmAxes, 'Text', 'Copy Data to Clipboard', ...
            'MenuSelectedFcn', @(~,~) onCopyDataToClipboard([], []));
        uimenu(cmAxes, 'Text', 'Export Visible Range...', ...
            'MenuSelectedFcn', @(~,~) bosonPlotter.onExportVisibleRange(appData, fig, ax));
        uimenu(cmAxes, 'Text', 'Toggle Waterfall Gradient', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) toggleWfGradient());
        uimenu(cmAxes, 'Text', 'Clear Fit Overlays', ...
            'MenuSelectedFcn', @(~,~) onClearFitOverlays());
        uimenu(cmAxes, 'Text', 'Refresh State (F5)', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) refreshState());

        % Inset graph
        uimenu(cmAxes, 'Text', 'Add Inset...', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) onCreateInsetFromMenu());
        uimenu(cmAxes, 'Text', 'Remove Inset', ...
            'MenuSelectedFcn', @(~,~) onRemoveInset());

        % Toolbar customisation
        uimenu(cmAxes, 'Text', 'Customise Toolbar...', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) onCustomiseToolbar());

        ax.ContextMenu = cmAxes;
    catch
        % R2022a/R2022b: uicontextmenu not supported on uifigure uiaxes.
    end

    % Detect whether ContextMenu on uifigure children is supported (R2023b+).
    % Used by plotInteractions to skip line context-menu wiring on older MATLAB.
    cmSupported_ = ~isMATLABReleaseOlderThan('R2023b');

    % Persistent x,y readout — normalized coords so it sticks to the top-right corner
    % regardless of axis scale.  HandleVisibility='off' keeps it alive through cla().
    appData.cursorText = text(ax, 0.98, 0.97, '', ...
        'Units',              'normalized', ...
        'HorizontalAlignment','right', ...
        'VerticalAlignment',  'top', ...
        'FontSize',           tk.font.title, ...
        'FontName',           'Courier New', ...
        'Color',              [0.80 0.80 0.80], ...
        'HandleVisibility',   'off', ...
        'Tag',                'GUICursorReadout', ...
        'Visible',            'off');

    % ── Status bar (row 3 of rootGL) ──────────────────────────────────────
    statusGL = uigridlayout(rootGL, [1 3], ...
        'ColumnWidth', {'1x', 80, 80}, ...
        'Padding', tk.pad.flush, 'ColumnSpacing', 4);
    statusGL.Layout.Row = 3; statusGL.Layout.Column = 1;

    lblStatusBar = uilabel(statusGL, 'Text', 'Ready', ...
        'FontSize', tk.font.label, 'FontColor', tk.color.textHighlight, ...
        'HorizontalAlignment', 'left');
    lblStatusBar.Layout.Column = 1;

    btnMacroRecord = uibutton(statusGL, 'Text', char(9210), ...  % ⏺ record symbol
        'FontSize', tk.font.body, 'FontColor', [0.6 0.6 0.6], ...
        'BackgroundColor', tk.color.bgPanel, ...
        'Tooltip', 'Start recording GUI actions as a MATLAB script', ...
        'ButtonPushedFcn', @onToggleMacroRecord);
    btnMacroRecord.Layout.Column = 2;

    btnMacroExport = uibutton(statusGL, 'Text', 'Save Script', ...
        'FontSize', tk.font.caption, 'FontColor', tk.color.textDim, ...
        'Tooltip', 'Export recorded macro as .m script', ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @onExportMacro);
    btnMacroExport.Layout.Column = 3;

    % ── Analysis & Corrections panel (row 2, full width, scrollable) ──────
    analysisPanel = uipanel(rootGL,'Title','Analysis & Corrections','FontSize', tk.font.title, ...
        'Scrollable','on');
    analysisPanel.Layout.Row = 2; analysisPanel.Layout.Column = 1;

    analysisGL = uigridlayout(analysisPanel,[2 4], ...
        'ColumnWidth', {320, '1x', 0, 210}, ...
        'RowHeight',   {110, '1x'}, ...
        'Padding',     tk.pad.normal, ...
        'ColumnSpacing', 6, ...
        'RowSpacing', 4);

    % ── Corrections sub-panel (analysisGL col 1) ─────────────────────────
    % Corrections panel — 18-row × 4-col grid with collapsible sections:
    %   row  1  : Style dropdown + Live Preview checkbox
    %   row  2  : Advanced Analysis button
    %   row  3  : [HEADER] "Offsets & Background" (collapsible, default open)
    %   row  4  : X Offset | BG Slope
    %   row  5  : Y Offset | BG Intercept
    %   row  6  : BG Order | BG Interp (merged)
    %   row  7  : Interactive tools (Fit BG / Est Y  OR  Y Translate / Peak btns)
    %   row  8  : [HEADER] "Processing" (collapsible, default open)
    %   row  9  : Smoothing controls (Smooth cb | window | method | Preview cb)
    %   row 10  : Normalize | Derivative (merged)
    %   row 11  : Trim X min | max
    %   row 12  : Baseline method selector + Apply button
    %   row 13  : Baseline method params (ALS lambda / Rolling Ball radius; hidden otherwise)
    %   row 14  : (reserved, height=0)
    %   row 15  : [HEADER] "BG File Subtraction" (collapsible, default collapsed)
    %   row 16  : BG File path + Load BG / Use Active
    %   row 17  : Subtract BG + Clear BG
    %   row 18  : Spin Asymmetry (neutron only, RowHeight=0 otherwise)
    %   row 19  : Asymmetry formula (neutron only, RowHeight=0 otherwise)
    %   row 26  : Apply Corrections | Reset | Show Raw
    %   row 27  : Apply to All | Undo | Hide Dataset
    %   row 28  : Mask Select | Unmask All
    %   row 29  : Redo
    corrPanel = uipanel(analysisGL,'Title','Corrections','FontSize', tk.font.title, ...
        'Scrollable','on');
    corrPanel.Layout.Row = [1 2]; corrPanel.Layout.Column = 1;

    % ── Row index constants for corrGL sections ──
    CROW = struct( ...
        'STYLE',      1,  'ADVANCED',  2,  'SEC_OFFSETS', 3,  'XOFF',       4,  'YOFF',       5, ...
        'BGORDER',    6,  'TOOLS',     7,  'SEC_PROC',   8,  'SMOOTH',     9, ...
        'NORM_DERIV',10,  'TRIM',     11,  'BASELINE',  12, ...
        'BASELINE_PARAMS', 13,  'BASELINE_APPLY', 14, ...
        'SEC_BGFILE', 15, ...
        'BGFILE',    16,  'BGSUBTR',  17,  'ASYM1',     18,  'ASYM2',     19, ...
        'SEC_MAG',   20,  'MAG_MASS', 21,  'MAG_DIM',   22,  'MAG_THICK', 23, ...
        'MAG_UNITS', 24,  'MAG_AUTO', 25, ...
        'APPLY',     26,  'ACTIONS',  27,  'MASK',   28,  'REDO',  29);

    corrGL = uigridlayout(corrPanel,[29 4], ...
        'RowHeight',    {24, 24, 20, 22,22,22,22, 20, 22,22,22,22, 0,0, 20, 0,0, 0,0, ...
                         0,0,0,0,0,0, 24,22, 22, 22}, ...
        'ColumnWidth',  {80,'1x',80,'1x'}, ...
        'Padding',      tk.pad.normal, ...
        'RowSpacing',   2, ...
        'ColumnSpacing', 3);

    % Collapsible section state
    appData.sectionCollapsed.offsets = false;  % open by default
    appData.sectionCollapsed.processing = false;  % open by default
    appData.sectionCollapsed.bgFile = true;  % collapsed by default (uncommon)
    appData.sectionCollapsed.magSample = true;  % collapsed by default
    appData.sectionCollapsed.saveTools = false;  % expanded by default — common items shouldn't be buried
    appData.sectionCollapsed.originExcel = true;  % collapsed by default
    appData.sectionCollapsed.advancedPeak = true;  % collapsed by default
    appData.sectionHeaders = struct();  % filled below with header button handles

    % Row 1: Correction style selector + Live preview
    lblCorrStyle = uilabel(corrGL,'Text','Style:','FontSize', tk.font.label,'HorizontalAlignment','right');
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
        'FontWeight', 'bold', 'FontSize', tk.font.label, ...
        'Tooltip', 'Advanced tools: Integrate, Curve Fit, Dataset Math, Digitizer, Resample...');
    btnAdvancedCorr.Layout.Row = CROW.ADVANCED; btnAdvancedCorr.Layout.Column = [1 4];

    % Row 3: Section header — Offsets & Background (uibutton for click support)
    lblSecOffsets = bosonPlotter.sectionHeader(corrGL, [char(9660) ' Offsets & BG'], ...
        @(~,~) onToggleCorrSection('offsets', offsetsSectionTitle(), ...
            [CROW.XOFF CROW.YOFF CROW.BGORDER CROW.TOOLS], [22 22 22 22]), ...
        'BackgroundColor', corrGL.BackgroundColor, 'FontColor', tk.color.textDim);
    appData.sectionHeaders.offsets = lblSecOffsets;
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
    lblBGOrder = uilabel(corrGL,'Text','BG Order:','FontSize', tk.font.label,'HorizontalAlignment','right');
    lblBGOrder.Layout.Row = CROW.BGORDER; lblBGOrder.Layout.Column = 1;

    ddBGOrder = uidropdown(corrGL, ...
        'Items',   {'Linear', 'Poly 2', 'Poly 3', 'Poly 4', 'Poly 5', 'Poly 6'}, ...
        'Value',   'Linear', ...
        'Tooltip', 'Polynomial order used by "Fit BG from Box": Linear=1st-order, Poly N=Nth-order');
    ddBGOrder.Layout.Row = CROW.BGORDER; ddBGOrder.Layout.Column = 2;

    lblBGInterp = uilabel(corrGL,'Text','Interp:','HorizontalAlignment','right','FontSize', tk.font.label);
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
        'BackgroundColor',BTN_INTERACT, ...
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
        'ButtonPushedFcn',@(~,~)[], ...
        'BackgroundColor',BTN_INTERACT,'FontColor',[1 1 1], ...
        'Tooltip','Detect peaks automatically using SNIP background estimation and SNR-based filtering', ...
        'Visible','off');
    btnAutoPeak.Layout.Row = CROW.TOOLS; btnAutoPeak.Layout.Column = 3;

    btnManualPeak = uibutton(corrGL,'Text','Add Peak', ...
        'ButtonPushedFcn',@(~,~)[], ...
        'BackgroundColor',[0.45 0.20 0.55],'FontColor',[1 1 1], ...
        'Tooltip','Click once on a peak in the plot to add it to the peak list (click button again to finish)', ...
        'Visible','off');
    btnManualPeak.Layout.Row = CROW.TOOLS; btnManualPeak.Layout.Column = 4;

    btnRemovePeakClick = uibutton(corrGL,'Text','Click-Rm', ...
        'ButtonPushedFcn',@(~,~)[], ...
        'BackgroundColor',BTN_DANGER,'FontColor',BTN_FG, ...
        'FontSize', tk.font.body, ...
        'Tooltip','Click on a peak marker in the plot to remove it (click button again to finish)', ...
        'Visible','off');
    btnRemovePeakClick.Layout.Row = CROW.BGORDER; btnRemovePeakClick.Layout.Column = 3;

    btnPeakWindow = uibutton(corrGL,'Text','Peaks...', ...
        'ButtonPushedFcn', @(~,~) showPeakWindow(), ...
        'BackgroundColor', BTN_ACCENT, 'FontColor', BTN_FG, ...
        'FontSize', tk.font.body, ...
        'Tooltip', 'Open the Peak Analysis window (table, fitting, export)', ...
        'Visible','off');
    btnPeakWindow.Layout.Row = CROW.BGORDER; btnPeakWindow.Layout.Column = 4;

    % Row 7: Section header — Processing (uibutton for click support)
    lblSecProc = bosonPlotter.sectionHeader(corrGL, [char(9660) ' Processing'], ...
        @(~,~) onToggleCorrSection('processing', 'Processing', ...
            [CROW.SMOOTH CROW.NORM_DERIV CROW.TRIM CROW.BASELINE], [22 22 22 22]), ...
        'BackgroundColor', corrGL.BackgroundColor, 'FontColor', tk.color.textDim);
    appData.sectionHeaders.processing = lblSecProc;
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
    ddSmoothMethod.Layout.Row = CROW.SMOOTH; ddSmoothMethod.Layout.Column = 3;

    cbSmoothPreview = uicheckbox(corrGL, 'Text', 'Preview', 'Value', false, ...
        'Tooltip', ['Show a live dashed overlay of smoothed data on the plot without modifying ' ...
                    'the dataset. Uncheck or click Apply to remove the overlay.'], ...
        'ValueChangedFcn', @onSmoothPreviewToggled);
    cbSmoothPreview.Layout.Row = CROW.SMOOTH; cbSmoothPreview.Layout.Column = 4;

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

    % Row 11: Baseline method selector
    lblBaselineMethod = uilabel(corrGL, 'Text', 'Baseline:', 'HorizontalAlignment', 'right');
    lblBaselineMethod.Layout.Row = CROW.BASELINE; lblBaselineMethod.Layout.Column = 1;

    ddBaselineMethod = uidropdown(corrGL, ...
        'Items',   {'SNIP', 'ALS', 'Rolling Ball', 'Mod. Polynomial'}, ...
        'Value',   'SNIP', ...
        'Tooltip', ['SNIP: peak-clipping (best for XRD)  |  ALS: asymmetric least squares ' ...
                    '(Raman, EELS)  |  Rolling Ball: morphological lower envelope  |  ' ...
                    'Mod. Polynomial: iterative polynomial fit (fluorescence removal)'], ...
        'ValueChangedFcn', @onBaselineMethodChanged);
    ddBaselineMethod.Layout.Row = CROW.BASELINE; ddBaselineMethod.Layout.Column = [2 3];

    btnEstimateBaseline = uibutton(corrGL, 'Text', 'Apply', ...
        'ButtonPushedFcn', @onEstimateBaseline, ...
        'Tooltip', 'Estimate and subtract baseline using the selected method', ...
        'FontSize', tk.font.body);
    btnEstimateBaseline.Layout.Row = CROW.BASELINE; btnEstimateBaseline.Layout.Column = 4;

    % Row 12: Baseline method-specific parameters (ALS lambda / Rolling Ball radius)
    lblBaselineLambda = uilabel(corrGL, 'Text', [char(955) ' (ALS):'], 'HorizontalAlignment', 'right', ...
        'Tooltip', 'ALS smoothness penalty (default 1e6 — larger = smoother baseline)');
    lblBaselineLambda.Layout.Row = CROW.BASELINE_PARAMS; lblBaselineLambda.Layout.Column = 1;

    efBaselineLambda = uieditfield(corrGL, 'numeric', 'Value', 1e6, ...
        'Limits', [1 Inf], 'LowerLimitInclusive', 'on', ...
        'Tooltip', 'ALS lambda: smoothness penalty (1e4–1e9 typical; default 1e6)', ...
        'ValueChangedFcn', @(~,~) []);
    efBaselineLambda.Layout.Row = CROW.BASELINE_PARAMS; efBaselineLambda.Layout.Column = 2;

    lblBaselineRadius = uilabel(corrGL, 'Text', 'Radius:', 'HorizontalAlignment', 'right', ...
        'Tooltip', 'Rolling Ball radius in data points (default 100)');
    lblBaselineRadius.Layout.Row = CROW.BASELINE_PARAMS; lblBaselineRadius.Layout.Column = 3;

    efBaselineRadius = uieditfield(corrGL, 'numeric', 'Value', 100, ...
        'Limits', [1 Inf], 'LowerLimitInclusive', 'on', ...
        'RoundFractionalValues', 'on', ...
        'Tooltip', 'Rolling Ball radius in data points (default 100; larger = smoother)', ...
        'ValueChangedFcn', @(~,~) []);
    efBaselineRadius.Layout.Row = CROW.BASELINE_PARAMS; efBaselineRadius.Layout.Column = 4;

    % BASELINE_PARAMS row is hidden by default (RowHeight=0 in corrGL initialiser).
    % onBaselineMethodChanged sets it to 22 for ALS and Rolling Ball, and back to 0
    % for SNIP and Mod. Polynomial which need no extra spinners.

    % Row 15: Section header — BG File Subtraction (collapsed by default, uibutton)
    lblSecBGFile = bosonPlotter.sectionHeader(corrGL, [char(9654) ' BG File Subtraction'], ...
        @(~,~) onToggleCorrSection('bgFile', 'BG File Subtraction', ...
            [CROW.BGFILE CROW.BGSUBTR], [22 22]), ...
        'BackgroundColor', corrGL.BackgroundColor, 'FontColor', tk.color.textDim);
    appData.sectionHeaders.bgFile = lblSecBGFile;
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
        'FontSize', tk.font.body);
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

    lblSecMag = bosonPlotter.sectionHeader(corrGL, [char(9654) ' Sample & Units'], ...
        @(~,~) onToggleCorrSection('magSample', 'Sample & Units', MAG_ROWS, MAG_HEIGHTS), ...
        'BackgroundColor', corrGL.BackgroundColor, 'FontColor', tk.color.textDim);
    appData.sectionHeaders.magSample = lblSecMag;
    lblSecMag.Layout.Row = CROW.SEC_MAG; lblSecMag.Layout.Column = [1 4];

    % Row MAG_MASS: Mass (g) | CGS/SI toggle
    lblMass = uilabel(corrGL,'Text','Mass (g):','FontSize', tk.font.label,'HorizontalAlignment','right');
    lblMass.Layout.Row = CROW.MAG_MASS; lblMass.Layout.Column = 1;

    efSampleMass = uieditfield(corrGL,'numeric','Value',0, ...
        'Limits',[0 Inf],'LowerLimitInclusive','on', ...
        'ValueDisplayFormat','%.6g', ...
        'Tooltip','Sample mass in grams (for emu/g normalization; 0 = not set)');
    efSampleMass.Layout.Row = CROW.MAG_MASS; efSampleMass.Layout.Column = 2;

    lblUnitSys = uilabel(corrGL,'Text','Units:','FontSize', tk.font.label,'HorizontalAlignment','right');
    lblUnitSys.Layout.Row = CROW.MAG_MASS; lblUnitSys.Layout.Column = 3;

    ddUnitSystem = uidropdown(corrGL, ...
        'Items',   {'CGS', 'SI'}, ...
        'Value',   'CGS', ...
        'Tooltip', 'Quick-set CGS (Oe + emu) or SI (T + A·m²) — updates Field & Moment dropdowns below', ...
        'ValueChangedFcn', @onUnitSystemChanged);
    ddUnitSystem.Layout.Row = CROW.MAG_MASS; ddUnitSystem.Layout.Column = 4;

    % Row MAG_DIM: W × H with unit dropdown (mm or cm)
    lblDim = uilabel(corrGL,'Text','W × H:','FontSize', tk.font.label,'HorizontalAlignment','right');
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
    lblThick = uilabel(corrGL,'Text','Thickness:','FontSize', tk.font.label,'HorizontalAlignment','right');
    lblThick.Layout.Row = CROW.MAG_THICK; lblThick.Layout.Column = 1;

    efSampleThick = uieditfield(corrGL,'numeric','Value',0, ...
        'Limits',[0 Inf],'LowerLimitInclusive','on', ...
        'ValueDisplayFormat','%.6g', ...
        'Tooltip','Sample thickness (for volume calculation; 0 = not set)');
    efSampleThick.Layout.Row = CROW.MAG_THICK; efSampleThick.Layout.Column = 2;

    lblThickUnit = uilabel(corrGL,'Text','Thick. Unit:','FontSize', tk.font.label,'HorizontalAlignment','right');
    lblThickUnit.Layout.Row = CROW.MAG_THICK; lblThickUnit.Layout.Column = 3;

    ddThickUnit = uidropdown(corrGL, ...
        'Items',   {'nm', [char(197)]}, ...
        'Value',   'nm', ...
        'Tooltip', ['Thickness unit: nm or ' char(197) ' (Angstrom)']);
    ddThickUnit.Layout.Row = CROW.MAG_THICK; ddThickUnit.Layout.Column = 4;

    % Row MAG_UNITS: Field unit (cols 1-2) | Moment unit (cols 3-4)
    lblFieldUnit = uilabel(corrGL,'Text','Field:','FontSize', tk.font.label,'HorizontalAlignment','right');
    lblFieldUnit.Layout.Row = CROW.MAG_UNITS; lblFieldUnit.Layout.Column = 1;

    ddFieldUnit = uidropdown(corrGL, ...
        'Items',   {'Oe', 'T', 'mT', 'A/m'}, ...
        'Value',   'Oe', ...
        'Tooltip', 'Convert magnetic field x-axis units (Oe → T, mT, or A/m)', ...
        'ValueChangedFcn', @onMagUnitChanged);
    ddFieldUnit.Layout.Row = CROW.MAG_UNITS; ddFieldUnit.Layout.Column = 2;

    lblMomentUnit = uilabel(corrGL,'Text','Moment:','FontSize', tk.font.label,'HorizontalAlignment','right');
    lblMomentUnit.Layout.Row = CROW.MAG_UNITS; lblMomentUnit.Layout.Column = 3;

    ddMomentUnit = uidropdown(corrGL, ...
        'Items',   {'emu', 'emu/g', 'emu/cm³', 'A·m²', 'kA/m'}, ...
        'Value',   'emu', ...
        'Tooltip', ['Normalize moment: emu/g (divide by mass), emu/cm' char(179) ...
                    ' (divide by volume), A' char(183) 'm' char(178) ' (SI moment), kA/m (SI magnetization)'], ...
        'ValueChangedFcn', @onMagUnitChanged);
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

    % Row APPLY: Apply | Auto | Reset | Show Raw (pinned to bottom)
    btnApply = uibutton(corrGL,'Text','Apply Corrections', ...
        'ButtonPushedFcn',@onApplyCorrections, ...
        'BackgroundColor',BTN_PRIMARY, ...
        'FontColor',BTN_FG,'FontWeight','bold', ...
        'Tooltip','Compute corrected data and update plot');
    btnApply.Layout.Row = CROW.APPLY; btnApply.Layout.Column = 1;

    cbAutoRecalc = uicheckbox(corrGL, ...
        'Text',    'Auto-Apply', ...
        'Value',   false, ...
        'Tooltip', 'Automatically re-apply corrections 0.3 s after any parameter change (debounced; off by default)', ...
        'ValueChangedFcn', @(~,~) updateApplyButtonStyle());
    cbAutoRecalc.Layout.Row = CROW.APPLY; cbAutoRecalc.Layout.Column = 2;

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
        'FontColor', tk.color.textMuted,'FontSize', tk.font.body);
    btnApplyAll.Layout.Row = CROW.ACTIONS; btnApplyAll.Layout.Column = [1 2];

    btnUndo = uibutton(corrGL,'Text',[char(8617) ' Undo'], ...
        'ButtonPushedFcn',@(s,e) appData.undoCb.onUndo(s,e), ...
        'Tooltip','Nothing to undo  [Ctrl+Z]', ...
        'FontColor', tk.color.textMuted,'FontSize', tk.font.body);
    btnUndo.Layout.Row = CROW.ACTIONS; btnUndo.Layout.Column = 3;

    btnRedo = uibutton(corrGL,'Text',[char(8618) ' Redo'], ...
        'ButtonPushedFcn',@(s,e) appData.undoCb.onRedo(s,e), ...
        'Tooltip','Nothing to redo  [Ctrl+Y]', ...
        'FontColor', tk.color.textMuted,'FontSize', tk.font.body, ...
        'Enable','off');
    btnRedo.Layout.Row = CROW.ACTIONS; btnRedo.Layout.Column = 4;

    % Undo/redo callbacks — handle struct stored on appData so anonymous
    % callbacks at the toolbar (line ~834) and keyboard handler (line ~9180)
    % resolve at call time via the AppState handle, decoupling construction
    % order from button creation.
    appData.undoCb = bosonPlotter.undoCallbacks(struct( ...
        'appData',   appData, ...
        'btnUndo',   btnUndo, ...
        'btnRedo',   btnRedo, ...
        'setStatus', @setStatus, ...
        'onPlot',    @(varargin) onPlot([],[])));

    % Row REDO (29): Correction presets — dropdown + Save + Delete
    ddPreset = uidropdown(corrGL, ...
        'Items', [{'(presets)'}, bosonPlotter.correctionPresets.list()], ...
        'Value', '(presets)', 'FontSize', tk.font.body, ...
        'Tooltip', 'Load a saved set of correction parameters', ...
        'ValueChangedFcn', @(~,~) onDatasetMetaEdit('load-preset'));
    ddPreset.Layout.Row = CROW.REDO; ddPreset.Layout.Column = [1 2];

    btnSavePreset = uibutton(corrGL, 'Text', 'Save', 'FontSize', tk.font.body, ...
        'Tooltip', 'Save current correction settings as a named preset', ...
        'ButtonPushedFcn', @(~,~) onDatasetMetaEdit('save-preset'));
    btnSavePreset.Layout.Row = CROW.REDO; btnSavePreset.Layout.Column = 3;

    btnDeletePreset = uibutton(corrGL, 'Text', char(10005), 'FontSize', tk.font.body, ...
        'Tooltip', 'Delete the selected preset', ...
        'ButtonPushedFcn', @(~,~) onDatasetMetaEdit('delete-preset'));
    btnDeletePreset.Layout.Row = CROW.REDO; btnDeletePreset.Layout.Column = 4;

    % Row MASK: Mask Selection | Hide | Unmask All
    btnMaskSelect = uibutton(corrGL,'Text','Mask Selection', ...
        'ButtonPushedFcn',@onArmMaskSelection, ...
        'BackgroundColor',[0.60 0.15 0.15], ...
        'FontColor',BTN_FG,'FontSize', tk.font.body, ...
        'Tooltip','Click & drag a rectangle on the plot to mask (exclude) data points inside the box');
    btnMaskSelect.Layout.Row = CROW.MASK; btnMaskSelect.Layout.Column = [1 2];

    btnToggleVis = uibutton(corrGL,'Text','Hide', ...
        'ButtonPushedFcn',@onToggleDatasetVisibility, ...
        'Tooltip','Hide/show the active dataset in the plot without removing it  [Space]', ...
        'FontColor', tk.color.textMuted,'FontSize', tk.font.body);
    btnToggleVis.Layout.Row = CROW.MASK; btnToggleVis.Layout.Column = 3;

    btnUnmaskAll = uibutton(corrGL,'Text','Unmask All', ...
        'ButtonPushedFcn',@onUnmaskAll, ...
        'BackgroundColor',BTN_TOOL, ...
        'FontColor', tk.color.textMuted,'FontSize', tk.font.body, ...
        'Tooltip','Restore all masked data points for the active dataset  [Ctrl+M]');
    btnUnmaskAll.Layout.Row = CROW.MASK; btnUnmaskAll.Layout.Column = 4;

    % Region statistics readout — moved to status bar area (no longer a corrGL row)
    lblRegionStats = uilabel(corrGL,'Text','', 'FontSize', tk.font.body, ...
        'FontColor', tk.color.textAccent);
    lblRegionStats.Layout.Row = CROW.SEC_BGFILE; lblRegionStats.Layout.Column = [2 4];

    % ── Axes & Appearance sub-panel (middle column) ──────────────────────
    % Ultra-compact 5-row layout:
    % Apply tk.font.body to any corrGL buttons that didn't get an explicit
    % FontSize during construction. Buttons styled by sectionHeader (which
    % already sets FontSize) are left alone — see +bosonPlotter/applyDefaultFont.m.
    bosonPlotter.applyDefaultFont(corrGL, tk.font.body);

    % ── Data Table panel (analysisGL col 2, both rows) ──────────────────
    % Axes/limits/scale moved into the Controls panel (left column, ctrlGL).
    % Title/labels/ref lines are accessible via right-click context menu and
    % the Plot Options ▾ button — no longer in a separate panel.
    dataTablePanel = uipanel(analysisGL, 'Title', 'Data Table', 'FontSize', tk.font.title);
    dataTablePanel.Layout.Row = [1 2]; dataTablePanel.Layout.Column = 2;

    % ── Data Table contents (toolbar + filter bar + units + editable table) ──
    dataTableInnerGL = uigridlayout(dataTablePanel, [5 1], ...
        'RowHeight', {22, 22, 14, 26, '1x'}, 'Padding', tk.pad.tight, 'RowSpacing', 1);

    % Toolbar row
    tableBarGL = uigridlayout(dataTableInnerGL, [1 8], ...
        'ColumnWidth', {70, 70, 55, 50, 50, 50, '1x', 100}, ...
        'RowHeight', {'1x'}, ...
        'Padding', tk.pad.barH, 'ColumnSpacing', 3);
    tableBarGL.Layout.Row = 1;

    btnTableSaveAs = uibutton(tableBarGL, 'Text', 'Save As...', ...
        'ButtonPushedFcn', @(~,~) [], ...
        'BackgroundColor', BTN_EXPORT, 'FontColor', BTN_FG, ...
        'FontSize', tk.font.caption, ...
        'Tooltip', 'Save edited table to a new CSV or Excel file');
    btnTableSaveAs.Layout.Column = 1;

    btnTableMask = uibutton(tableBarGL, 'Text', 'Mask Sel.', ...
        'ButtonPushedFcn', @(~,~) [], ...
        'BackgroundColor', BTN_DANGER, 'FontColor', BTN_FG, ...
        'FontSize', tk.font.caption, ...
        'Tooltip', 'Mask selected rows — excluded from plot and analysis');
    btnTableMask.Layout.Column = 2;

    btnTableUnmask = uibutton(tableBarGL, 'Text', 'Unmask', ...
        'ButtonPushedFcn', @(~,~) [], ...
        'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [0.8 0.8 0.8], ...
        'FontSize', tk.font.caption, ...
        'Tooltip', 'Remove all row masks');
    btnTableUnmask.Layout.Column = 3;

    btnTableDescStats = uibutton(tableBarGL, 'Text', 'Stats', ...
        'ButtonPushedFcn', @(~,~) [], ...
        'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [0.8 0.8 0.8], ...
        'FontSize', tk.font.caption, ...
        'Tooltip', 'Per-column descriptive statistics');
    btnTableDescStats.Layout.Column = 4;

    btnSortAsc = uibutton(tableBarGL, 'Text', [char(9650) 'Asc'], ...
        'ButtonPushedFcn', @(~,~) [], ...
        'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [0.8 0.8 0.8], ...
        'FontSize', tk.font.caption, ...
        'Tooltip', 'Sort by selected column (ascending)');
    btnSortAsc.Layout.Column = 5;

    btnSortDesc = uibutton(tableBarGL, 'Text', [char(9660) 'Desc'], ...
        'ButtonPushedFcn', @(~,~) [], ...
        'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [0.8 0.8 0.8], ...
        'FontSize', tk.font.caption, ...
        'Tooltip', 'Sort by selected column (descending)');
    btnSortDesc.Layout.Column = 6;

    lblTableStats = uilabel(tableBarGL, 'Text', '', ...
        'FontSize', tk.font.caption, 'FontColor', tk.color.textDim, ...
        'HorizontalAlignment', 'right');
    lblTableStats.Layout.Column = 7;

    btnOpenDW = uibutton(tableBarGL, 'Text', [char(9783) ' Data Table'], ...
        'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
        'FontSize', tk.font.caption, ...
        'Tooltip', 'Open shared DataWorkspace (single instance)', ...
        'ButtonPushedFcn', @(~,~) openLinkedDataWorkspace());
    btnOpenDW.Layout.Column = 8;

    % ── Filter bar row ────────────────────────────────────────────────────
    % Layout: [label | edit field (stretch) | Filter btn | Clear btn]
    filterBarGL = uigridlayout(dataTableInnerGL, [1 4], ...
        'ColumnWidth', {30, '1x', 44, 40}, ...
        'RowHeight',   {'1x'}, ...
        'Padding', tk.pad.barH, 'ColumnSpacing', 3);
    filterBarGL.Layout.Row = 2;

    lblFilter = uilabel(filterBarGL, 'Text', 'Filter:', ...
        'FontSize', tk.font.caption, 'FontColor', tk.color.textMuted, ...
        'HorizontalAlignment', 'right');
    lblFilter.Layout.Column = 1; %#ok<NASGU>

    efFilter = uieditfield(filterBarGL, 'text', 'Value', '', ...
        'Placeholder', 'e.g. Temp > 300  or  between(x, 0, 1)', ...
        'FontSize', tk.font.caption, ...
        'BackgroundColor', tk.color.bgDark, 'FontColor', tk.color.text, ...
        'Tooltip', ['Filter rows by expression. Column names from labels, ' ...
                    '''x'' = X axis. Operators: > < >= <= == ~= & | ~. ' ...
                    'Functions: abs(), between(col,lo,hi). Press Enter to apply.'], ...
        'ValueChangedFcn', @(~,~) []);
    efFilter.Layout.Column = 2;

    btnFilterApply = uibutton(filterBarGL, 'Text', 'Filter', ...
        'ButtonPushedFcn', @(~,~) [], ...
        'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
        'FontSize', tk.font.caption, ...
        'Tooltip', 'Apply filter expression');
    btnFilterApply.Layout.Column = 3;

    btnFilterClear = uibutton(filterBarGL, 'Text', 'Clear', ...
        'ButtonPushedFcn', @(~,~) [], ...
        'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [0.8 0.8 0.8], ...
        'FontSize', tk.font.caption, ...
        'Tooltip', 'Clear filter — show all rows');
    btnFilterClear.Layout.Column = 4;

    % Units row
    lblTableUnits = uilabel(dataTableInnerGL, 'Text', '', ...
        'FontSize', tk.font.caption, 'FontColor', [0.5 0.7 0.5], ...
        'BackgroundColor', [0.16 0.16 0.16]);
    lblTableUnits.Layout.Row = 3;

    % ── Units row (separate 1-row uitable for performance) ────────────
    % Before the split, the main data table stored row 1 as unit strings
    % which forced the whole Data property to be a cell array.  Cell-
    % array uitables render ~10× slower than numeric matrices on scroll,
    % so we split units into their own tiny table and keep the main data
    % table pure numeric.  Column widths are kept in sync via an explicit
    % ColumnWidth array set on both tables.
    tblUnits = uitable(dataTableInnerGL, ...
        'Tag', 'BosonUnitsTable', ...
        'ColumnName', {'(no data)'}, ...
        'Data', {}, ...
        'ColumnEditable', true, ...
        'RowName', {'units'}, ...
        'CellEditCallback', @(~,~) [], ...
        'CellSelectionCallback', @(~,~) [], ...
        'FontSize', tk.font.body, ...
        'BackgroundColor', [0.96 0.98 0.93], ...
        'ForegroundColor', [0.0 0.35 0.0]);
    tblUnits.Layout.Row = 4;

    % Editable data table (pure numeric data — big scroll-perf win)
    tblData = uitable(dataTableInnerGL, ...
        'Tag', 'BosonDataTable', ...
        'ColumnName', {'(no data)'}, ...
        'Data', [], ...
        'ColumnEditable', true, ...
        'CellEditCallback', @(~,~) [], ...
        'CellSelectionCallback', @(~,~) [], ...
        'FontSize', tk.font.body);

    % Right-click context menu for row-level masking (replaces the old
    % "Masked" column).  Selected rows are taken from appData.tableSelection
    % which onTableSelectionChanged maintains from the CellSelectionCallback.
    tblCtxMenu = uicontextmenu(fig);
    miMaskRows   = uimenu(tblCtxMenu, 'Text', 'Mask selected rows', ...
        'MenuSelectedFcn', @(~,~) []);
    miUnmaskRows = uimenu(tblCtxMenu, 'Text', 'Unmask selected rows', ...
        'MenuSelectedFcn', @(~,~) []);
    miUnmaskAll  = uimenu(tblCtxMenu, 'Separator', 'on', 'Text', 'Unmask all', ...
        'MenuSelectedFcn', @(~,~) []);
    tblData.ContextMenu = tblCtxMenu;
    tblData.Layout.Row = 5;
    appData.tableSelection = [];  % [Nx2] matrix of [row col] pairs

    % ── Hidden floaters: not visible, but read by callbacks ──────────────
    % These were formerly visible widgets in axLimPanel. After the Axes
    % panel was deleted (axes/limits moved to ctrlGL above; less-used
    % features moved to right-click + Plot Options ▾ menus), they remain
    % as the source of truth for the corresponding values:
    %   efXStep / efYStep / efY2Step  — set via right-click "Tick Spacing"
    %   ddDatasetColor / ddDatasetColorR — set via right-click "Dataset Color"
    %   ddLegendLoc                   — set via right-click "Legend Location"
    %   efCustomTitle / efCustom*Label / efLegendName(R) — set via
    %       right-click "Edit Axis Labels..." / "Edit Legend..." dialogs
    % Existing callbacks (onPlot, renderPlot, saveAxisLimsToActiveDataset)
    % still read from these handles unchanged.
    efXStep = uieditfield(fig,'text','Value','','Visible','off', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efYStep = uieditfield(fig,'text','Value','','Visible','off', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));
    efY2Step = uieditfield(fig,'text','Value','','Visible','off', ...
        'ValueChangedFcn',@(~,~) onPlot([],[]));

    ddLegendLoc = uidropdown(fig, ...
        'Items', {'best','NE','NW','SE','SW','EastOutside','off'}, ...
        'Value', 'best', 'Visible','off', ...
        'ValueChangedFcn', @onToolbarLegendToggle);

    ddDatasetColor = uidropdown(fig, ...
        'Items', DS_COLOR_NAMES, 'ItemsData', DS_COLOR_RGBS, ...
        'Value', [], 'Enable', 'off', 'Visible','off', ...
        'ValueChangedFcn', @onDatasetColorChanged);

    ddDatasetColorR = uidropdown(fig, ...
        'Items', DS_COLOR_NAMES, 'ItemsData', DS_COLOR_RGBS, ...
        'Value', [], 'Enable', 'off', 'Visible','off', ...
        'ValueChangedFcn', @onDatasetColorRChanged);

    efCustomTitle = uieditfield(fig,'text','Value','','Visible','off', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomXLabel = uieditfield(fig,'text','Value','','Visible','off', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomYLabel = uieditfield(fig,'text','Value','','Visible','off', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efCustomY2Label = uieditfield(fig,'text','Value','','Visible','off', ...
        'ValueChangedFcn', @(~,~) onPlot([],[]));
    efLegendName = uieditfield(fig,'text','Value','','Enable','off','Visible','off', ...
        'ValueChangedFcn', @onLegendNameChanged);
    efLegendNameR = uieditfield(fig,'text','Value','','Enable','off','Visible','off', ...
        'ValueChangedFcn', @onLegendNameRChanged);

    % ── Save / Export panel (analysisGL col 3 — vertical, collapsible) ─────
    savePanel = uipanel(analysisGL,'Title','Save / Export','FontSize', tk.font.title, ...
        'Scrollable','on');
    savePanel.Layout.Row = [1 2]; savePanel.Layout.Column = 4;

    % Vertical stacked layout with collapsible section headers
    % Rows: [hdrData, dataContent, hdrFig, figContent, hdrSession, sessionContent, hdrTools, toolsContent]
    SAVE_SEC_H = 20;    % header row height
    SAVE_ROW_H = 78;    % content block height (3 rows of 24 + spacing)
    % Default open state: Data Export (row 2) + Figure Export (row 4).
    % Save-figure-as is a daily task; hiding it behind an extra click was
    % a papercut called out in the repo audit (W2 #19). Session and Tools
    % remain collapsed (rows 6, 8) because they're used far less often.
    saveGL = uigridlayout(savePanel,[8 1], ...
        'RowHeight', {SAVE_SEC_H, SAVE_ROW_H, SAVE_SEC_H, SAVE_ROW_H, SAVE_SEC_H, 0, SAVE_SEC_H, 0}, ...
        'ColumnWidth', {'1x'}, ...
        'Padding',     tk.pad.tight, ...
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
    btnSaveHdrData = bosonPlotter.sectionHeader(saveGL, [char(9660) ' Data Export'], ...
        @(~,~) toggleSaveSection('dataExport','Data Export'), ...
        'FontColor', tk.color.textHighlight);
    btnSaveHdrData.Layout.Row = 1;

    saveDataGL = uigridlayout(saveGL, [3 2], ...
        'RowHeight', {24, 24, 24}, 'ColumnWidth', {'1x','1x'}, ...
        'Padding', tk.pad.flush, 'RowSpacing', 2, 'ColumnSpacing', 3);
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

    % ── Header: Figure Export (open by default — W2 #19) ─────────────
    btnSaveHdrFig = bosonPlotter.sectionHeader(saveGL, [char(9660) ' Figure Export'], ...
        @(~,~) toggleSaveSection('figExport','Figure Export'), ...
        'FontColor', tk.color.textHighlight);
    btnSaveHdrFig.Layout.Row = 3;

    saveFigGL = uigridlayout(saveGL, [3 2], ...
        'RowHeight', {24, 24, 24}, 'ColumnWidth', {'1x','1x'}, ...
        'Padding', tk.pad.flush, 'RowSpacing', 2, 'ColumnSpacing', 3);
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
        'Padding', tk.pad.flush, 'ColumnSpacing', 2, ...
        'ColumnWidth', {40, '1x', 12, '1x'});
    figDimGL.Layout.Row = 3; figDimGL.Layout.Column = [1 2];

    uilabel(figDimGL, 'Text', 'Size:', 'FontSize', tk.font.caption, ...
        'HorizontalAlignment', 'right');
    efFigWidth = uieditfield(figDimGL, 'numeric', 'Value', 7, ...
        'Limits', [1 30], 'Tooltip', 'Width (in)');
    efFigWidth.Layout.Column = 2;
    uilabel(figDimGL, 'Text', char(215), 'FontSize', tk.font.body, ...
        'HorizontalAlignment', 'center');
    efFigHeight = uieditfield(figDimGL, 'numeric', 'Value', 5, ...
        'Limits', [1 30], 'Tooltip', 'Height (in)');
    efFigHeight.Layout.Column = 4;

    % ── Header: Session (collapsed by default) ───────────────────────
    btnSaveHdrSession = bosonPlotter.sectionHeader(saveGL, [char(9654) ' Session'], ...
        @(~,~) toggleSaveSection('session','Session'), ...
        'FontColor', tk.color.textHighlight);
    btnSaveHdrSession.Layout.Row = 5;

    saveSessionGL = uigridlayout(saveGL, [3 2], ...
        'RowHeight', {24, 24, 24}, 'ColumnWidth', {'1x','1x'}, ...
        'Padding', tk.pad.flush, 'RowSpacing', 2, 'ColumnSpacing', 3);
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
    btnSaveHdrTools = bosonPlotter.sectionHeader(saveGL, [char(9654) ' Tools'], ...
        @(~,~) toggleSaveSection('tools','Tools'), ...
        'FontColor', tk.color.textHighlight);
    btnSaveHdrTools.Layout.Row = 7;

    saveToolsGL = uigridlayout(saveGL, [3 2], ...
        'RowHeight', {24, 24, 24}, 'ColumnWidth', {'1x','1x'}, ...
        'Padding', tk.pad.flush, 'RowSpacing', 2, 'ColumnSpacing', 3);
    saveToolsGL.Layout.Row = 8;

    % Row 1: Figures + Templates + Layout + Overlay + Batch Figs
    btnAdvFigure = uibutton(saveToolsGL,'Text','Figures...', ...
        'ButtonPushedFcn', @onAdvancedFigureBuilder, ...
        'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
        'Tooltip', 'Advanced Figure Builder');
    btnAdvFigure.Layout.Row = 1; btnAdvFigure.Layout.Column = 1;

    btnTemplates = uibutton(saveToolsGL,'Text','Templates...', ...
        'ButtonPushedFcn', @onPlotTemplates, ...
        'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
        'Tooltip', 'Save/load plot formatting presets (axis limits, corrections, labels)');
    btnTemplates.Layout.Row = 1; btnTemplates.Layout.Column = 2;

    % Row 2: Overlay + Batch Figs
    cbOverlayMode = uicheckbox(saveToolsGL, ...
        'Text', 'Overlay', ...
        'Value', false, ...
        'Tooltip', 'Overlay selected datasets on the same axes with unified legend', ...
        'ValueChangedFcn', @onOverlayModeChanged);
    cbOverlayMode.Layout.Row = 2; cbOverlayMode.Layout.Column = 1;

    btnBatchFigExport = uibutton(saveToolsGL,'Text','Batch Figs...', ...
        'ButtonPushedFcn', @onBatchFigureExport, ...
        'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
        'Tooltip', 'Export all datasets as individual figures with consistent formatting');
    btnBatchFigExport.Layout.Row = 2; btnBatchFigExport.Layout.Column = 2;

    % Row 3: Plot Options (full width)
    % NOTE: "Advanced Analysis" button removed from here — it already exists
    % prominently in the corrections panel (corrGL row CROW.ADVANCED).
    % Having it in two places confused users without adding value.
    btnPlotOpt2 = uibutton(saveToolsGL,'Text',['Plot Options ' char(9662)], ...
        'ButtonPushedFcn', @onShowPlotOptionsMenu, ...
        'BackgroundColor', [0.22 0.35 0.55], 'FontColor', [1 1 1], ...
        'FontWeight', 'bold', ...
        'Tooltip', 'Plot types, visualization options, and unit conversion');
    btnPlotOpt2.Layout.Row = 3; btnPlotOpt2.Layout.Column = [1 2];

    % Bring any unstyled buttons in the controls/save sub-grids
    % (limGL / saveGL / nested sub-grids) down to tk.font.body so
    % they match the surrounding panel typography. See
    % +bosonPlotter/applyDefaultFont.m — the walk only touches buttons
    % still at the MATLAB default 12 pt; explicitly-styled buttons
    % (e.g. section headers via bosonPlotter.sectionHeader) are skipped.
    bosonPlotter.applyDefaultFont(limGL,  tk.font.body);
    bosonPlotter.applyDefaultFont(saveGL, tk.font.body);

    % ── Peak Analysis window (separate uifigure) ──────────────────────────
    % Construction delegated to +bosonPlotter/buildPeakWindow.m.
    % Callbacks are wired below after the struct is returned.
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
    peakConsts = struct( ...
        'BTN_ACCENT',    BTN_ACCENT, ...
        'BTN_EXPORT',    BTN_EXPORT, ...
        'BTN_SECONDARY', BTN_SECONDARY, ...
        'BTN_FG',        BTN_FG, ...
        'XRAY_SOURCES',  {XRAY_SOURCES});
    pw = bosonPlotter.buildPeakWindow(appData, peakConsts);

    % Destructure peak window handles into the BosonPlotter closure
    peakFig           = pw.peakFig;
    peakBtnGL         = pw.peakBtnGL;
    peakTable         = pw.peakTable;
    ddFitModel        = pw.ddFitModel;
    btnFitPeaks       = pw.btnFitPeaks;
    btnFitAllPeaks    = pw.btnFitAllPeaks;
    btnClearPeaks     = pw.btnClearPeaks;
    btnRemovePeak     = pw.btnRemovePeak;
    btnSavePeaks      = pw.btnSavePeaks;
    btnExportPeakXLSX = pw.btnExportPeakXLSX;
    btnCopyPeaksClip  = pw.btnCopyPeaksClip;
    btnFitColor       = pw.btnFitColor;
    chkShowFit        = pw.chkShowFit;
    btnReflFFT        = pw.btnReflFFT;
    btnFringeThick    = pw.btnFringeThick;
    btnMorePeak       = pw.btnMorePeak;
    btnWHPlot         = pw.btnWHPlot;
    btnFFTThickness   = pw.btnFFTThickness;
    btnRefineLattice  = pw.btnRefineLattice;
    btnMatchPhases    = pw.btnMatchPhases;
    efMinSep          = pw.efMinSep;
    efWavelength      = pw.efWavelength;
    efKFactor         = pw.efKFactor;
    efInstBroadening  = pw.efInstBroadening;
    ddXraySource      = pw.ddXraySource;
    chkShowBG         = pw.chkShowBG;

    % Constants used by onToggleAdvancedPeakTools
    PEAK_ADV_ROWS    = 9;
    PEAK_ADV_HEIGHTS = 46;

    % ── Initialize extracted peak-callbacks module ──────────────────────
    peakCtx_.appData            = appData;
    peakCtx_.fig                = fig;
    peakCtx_.ax                 = ax;
    peakCtx_.ddX                = ddX;
    peakCtx_.lbY                = lbY;
    peakCtx_.efXMin             = efXMin;
    peakCtx_.efXMax             = efXMax;
    peakCtx_.efMinSep           = efMinSep;
    peakCtx_.ddFitModel         = ddFitModel;
    peakCtx_.peakTable          = peakTable;
    peakCtx_.btnManualPeak      = btnManualPeak;
    peakCtx_.btnRemovePeakClick = btnRemovePeakClick;
    peakCtx_.onPlot             = @(varargin) onPlot([],[]);
    peakCtx_.showPeakWindow     = @showPeakWindow;
    peakCtx_.cancelInteractions = @cancelInteractions;
    peakCtx_.setStatus          = @setStatus;
    peakCtx_.logGUIError        = @logGUIError;
    peakCtx_.getPlotData        = @getPlotData;
    peakCb = bosonPlotter.peakCallbacks(peakCtx_);

    % Rewire peak buttons created earlier (before peakCb existed)
    btnAutoPeak.ButtonPushedFcn              = peakCb.onAutoPeak;
    btnManualPeak.ButtonPushedFcn            = peakCb.onManualPeakAdd;
    btnRemovePeakClick.ButtonPushedFcn       = peakCb.onRemovePeakClickMode;

    % Wire peak window callbacks (deferred from builder)
    peakFig.CloseRequestFcn                  = @(~,~) set(peakFig, 'Visible', 'off');
    peakTable.CellSelectionCallback          = peakCb.onPeakTableSelect;
    btnFitPeaks.ButtonPushedFcn              = peakCb.onFitPeaks;
    btnFitAllPeaks.ButtonPushedFcn           = peakCb.onFitAllPeaks;
    btnClearPeaks.ButtonPushedFcn            = peakCb.onClearPeaks;
    btnRemovePeak.ButtonPushedFcn            = peakCb.onRemoveSelectedPeak;
    btnSavePeaks.ButtonPushedFcn             = peakCb.onSavePeakSummary;
    btnExportPeakXLSX.ButtonPushedFcn        = peakCb.onExportPeakXLSX;
    btnCopyPeaksClip.ButtonPushedFcn         = @onCopyPeaksToClipboard;
    btnFitColor.ButtonPushedFcn              = @onPickFitColor;
    chkShowFit.ValueChangedFcn               = @onToggleFitCurves;
    btnReflFFT.ButtonPushedFcn               = @onReflectivityFFT;
    btnFringeThick.ButtonPushedFcn           = @onArmFringeThickness;
    btnMorePeak.ButtonPushedFcn              = @(~,~) onToggleAdvancedPeakTools();
    btnWHPlot.ButtonPushedFcn                = @onWilliamsonHallPlot;
    btnFFTThickness.ButtonPushedFcn          = @onFFTThickness;
    btnRefineLattice.ButtonPushedFcn         = @onRefineLattice;
    btnMatchPhases.ButtonPushedFcn           = @onMatchPhases;
    efWavelength.ValueChangedFcn             = @onWavelengthChanged;

    % ── Peak window keyboard shortcuts ─────────────────────────────────
    peakFig.KeyPressFcn = peakCb.onKeyPress;
    efKFactor.ValueChangedFcn                = @onKFactorChanged;
    efInstBroadening.ValueChangedFcn         = @onInstBroadeningChanged;
    ddXraySource.ValueChangedFcn             = @onXraySourceChanged;
    chkShowBG.ValueChangedFcn                = @onToggleShowBG;

    % ── 2D Map controls (col 3 of analysisGL — visible only for 2D data) ──
    % Construction delegated to +bosonPlotter/buildMap2DPanel.m.
    % Callbacks are wired below after the struct is returned.
    mw = bosonPlotter.buildMap2DPanel(analysisGL, ismac);
    mw.map2DPanel.Layout.Row = [1 2]; mw.map2DPanel.Layout.Column = 3;

    % Destructure 2D map handles into the BosonPlotter closure
    map2DPanel      = mw.map2DPanel;
    ddMap2DType     = mw.ddMap2DType;
    efMap2DContourN = mw.efMap2DContourN;
    cbMap2DQSpace   = mw.cbMap2DQSpace;
    ddMap2DCmap     = mw.ddMap2DCmap;
    ddMap2DScale    = mw.ddMap2DScale;
    efMap2DCMin     = mw.efMap2DCMin;
    efMap2DCMax     = mw.efMap2DCMax;
    btnPoleFigure   = mw.btnPoleFigure;
    btnBoxIntegrate = mw.btnBoxIntegrate;
    efBoxIntW       = mw.efBoxIntW;
    efBoxIntH       = mw.efBoxIntH;
    btnArcIntegrate  = mw.btnArcIntegrate;
    lblMap2DInfo     = mw.lblMap2DInfo;
    cbMap2DSingle    = mw.cbMap2DSingle;
    btnFitSurface    = mw.btnFitSurface;
    btnDecomposeRSM  = mw.btnDecomposeRSM;
    btnClear2DMatrix = mw.btnClear2DMatrix;

    % Wire 2D map callbacks (deferred from builder)
    ddMap2DType.ValueChangedFcn      = @(~,~) onPlot([],[]);
    efMap2DContourN.ValueChangedFcn  = @(~,~) onPlot([],[]);
    cbMap2DQSpace.ValueChangedFcn    = @(~,~) onPlot([],[]);
    ddMap2DCmap.ValueChangedFcn      = @(~,~) onPlot([],[]);
    ddMap2DScale.ValueChangedFcn     = @(~,~) onPlot([],[]);
    efMap2DCMin.ValueChangedFcn      = @(~,~) onPlot([],[]);
    efMap2DCMax.ValueChangedFcn      = @(~,~) onPlot([],[]);
    btnPoleFigure.ButtonPushedFcn    = @onPoleFigure;
    btnBoxIntegrate.ButtonPushedFcn  = @onBoxIntButton;
    efBoxIntW.ValueChangedFcn        = @(~,~) updateBoxPreview();
    efBoxIntH.ValueChangedFcn        = @(~,~) updateBoxPreview();
    btnArcIntegrate.ButtonPushedFcn  = @onArcIntButton;
    cbMap2DSingle.ValueChangedFcn    = @(~,~) onToggleSinglePrecision();
    btnFitSurface.ButtonPushedFcn    = @onFitSurface;
    btnDecomposeRSM.ButtonPushedFcn  = @(~,~) onDecomposeRSM();
    btnClear2DMatrix.ButtonPushedFcn = @(~,~) onClear2DMatrix();

    % ── Drag-and-drop: register every major surface as a drop target (R2023a+) ──
    % In uifigure the CEF renderer consumes drag events at whichever child
    % component is under the cursor; they do NOT bubble up to the figure.
    % Registering each panel/listbox/axes individually ensures that a file
    % dropped anywhere in the window is caught.
    dropSurfaces = {ctrlPanel, axPanel, ax, analysisPanel, ...
                    corrPanel, dataTablePanel, savePanel, lbDatasets};
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

    % ── Static render context (allocated once, merged into rCtx_ each replot) ──
    rCtxStatic_.fig                         = fig;
    rCtxStatic_.efXMin                      = efXMin;
    rCtxStatic_.efXMax                      = efXMax;
    rCtxStatic_.efYMin                      = efYMin;
    rCtxStatic_.efYMax                      = efYMax;
    rCtxStatic_.efY2Min                     = efY2Min;
    rCtxStatic_.efY2Max                     = efY2Max;
    rCtxStatic_.limGL                       = limGL;
    rCtxStatic_.draw2DMap                   = @draw2DMap;
    rCtxStatic_.toggleY2Appearance          = @toggleY2Appearance;
    rCtxStatic_.applyAxisPrefix             = @bosonPlotter.applyAxisPrefix;
    rCtxStatic_.recreateFringeMarkers       = @recreateFringeMarkers;
    rCtxStatic_.resolvedCorrStyle           = @resolvedCorrStyle;
    rCtxStatic_.getColorsFromMap            = @getColorsFromMap;
    rCtxStatic_.findPolarizationPairs       = @findPolarizationPairs;
    rCtxStatic_.setStatus                   = @setStatus;
    rCtxStatic_.logGUIError                 = @logGUIError;

    % ── Widget handle struct for extracted functions ──────────────────────
    % All fields point to the same handle objects as the closure variables.
    % Built once during initialisation; passed to +bosonPlotter/ helpers so
    % they can be ordinary functions instead of nested functions.
    ui = struct();
    % X/Y channel selectors
    ui.ddX              = ddX;
    ui.lbY              = lbY;
    ui.lbY2             = lbY2;
    ui.lbDatasets       = lbDatasets;
    ui.btnRemoveDS      = btnRemoveDS;
    ui.btnMerge         = btnMerge;
    % Scale / display
    ui.ddScaleX         = ddScaleX;
    ui.ddScaleY         = ddScaleY;
    ui.ddScaleY2        = ddScaleY2;
    ui.cbCountsPerSec   = cbCountsPerSec;
    ui.cbCalculateAsymmetry = cbCalculateAsymmetry;
    % 2D map controls
    ui.ddMap2DCmap      = ddMap2DCmap;
    ui.ddMap2DScale     = ddMap2DScale;
    ui.efMap2DCMin      = efMap2DCMin;
    ui.efMap2DCMax      = efMap2DCMax;
    % Dataset appearance
    ui.ddDatasetColor   = ddDatasetColor;
    ui.ddDatasetColorR  = ddDatasetColorR;
    ui.efLegendName     = efLegendName;
    ui.efLegendNameR    = efLegendNameR;
    % Correction offsets / BG
    ui.efXOffset        = efXOffset;
    ui.efYOffset        = efYOffset;
    ui.efBGSlope        = efBGSlope;
    ui.efBGIntercept    = efBGIntercept;
    ui.ddBGOrder        = ddBGOrder;
    ui.ddBGInterp       = ddBGInterp;
    ui.cbSubtractBG     = cbSubtractBG;
    ui.ddPreset         = ddPreset;
    % Smoothing
    ui.cbSmooth         = cbSmooth;
    ui.efSmoothWin      = efSmoothWin;
    ui.ddSmoothMethod   = ddSmoothMethod;
    ui.cbSmoothPreview  = cbSmoothPreview;
    % Trim / normalize / derivative
    ui.efXTrimMin       = efXTrimMin;
    ui.efXTrimMax       = efXTrimMax;
    ui.ddNormalize      = ddNormalize;
    ui.ddDerivative     = ddDerivative;
    % Magnetometry parameters
    ui.efSampleMass     = efSampleMass;
    ui.efSampleWidth    = efSampleWidth;
    ui.efSampleHeight   = efSampleHeight;
    ui.ddDimUnit        = ddDimUnit;
    ui.efSampleThick    = efSampleThick;
    ui.ddThickUnit      = ddThickUnit;
    ui.ddMomentUnit     = ddMomentUnit;
    ui.ddFieldUnit      = ddFieldUnit;
    ui.ddUnitSystem     = ddUnitSystem;
    % Wavelength (from peak window)
    ui.efWavelength     = efWavelength;
    % Axis limits
    ui.efXMin           = efXMin;
    ui.efXMax           = efXMax;
    ui.efXStep          = efXStep;
    ui.efYMin           = efYMin;
    ui.efYMax           = efYMax;
    ui.efYStep          = efYStep;
    ui.efY2Min          = efY2Min;
    ui.efY2Max          = efY2Max;
    ui.efY2Step         = efY2Step;
    ui.limGL            = limGL;
    % Correction labels (relabelled by applyParserAnalysisConfig)
    ui.lblXOff          = lblXOff;
    ui.lblYOff          = lblYOff;
    ui.lblBGSlope       = lblBGSlope;
    ui.lblBGInt         = lblBGInt;
    % Correction action buttons
    ui.btnApply         = btnApply;
    ui.btnReset         = btnReset;
    ui.btnApplyAll      = btnApplyAll;
    ui.btnUndo          = btnUndo;
    % Tool buttons (visibility toggled by parser type)
    ui.btnFitBG             = btnFitBG;
    ui.btnPickY             = btnPickY;
    ui.btnYTranslate        = btnYTranslate;
    ui.btnAutoPeak          = btnAutoPeak;
    ui.btnManualPeak        = btnManualPeak;
    ui.btnRemovePeakClick   = btnRemovePeakClick;
    ui.btnPeakWindow        = btnPeakWindow;
    % Panels / layouts (for visibility / row-height changes)
    ui.ctrlPanel        = ctrlPanel;
    ui.analysisPanel    = analysisPanel;
    ui.analysisGL       = analysisGL;
    ui.corrGL           = corrGL;
    ui.map2DPanel       = map2DPanel;
    ui.dataTablePanel   = dataTablePanel;
    % 2D map controls
    ui.cbMap2DQSpace    = cbMap2DQSpace;
    ui.btnArcIntegrate  = btnArcIntegrate;
    ui.lblMap2DInfo     = lblMap2DInfo;
    % Save path (hidden field)
    ui.efSavePath       = efSavePath;
    % Figure export dimensions + format
    ui.ddFigFormat      = ddFigFormat;
    ui.efFigWidth       = efFigWidth;
    ui.efFigHeight      = efFigHeight;
    % Data table filter
    ui.efFilter         = efFilter;
    % Axis appearance / label overrides (used by onPlotTemplates)
    ui.efCustomTitle    = efCustomTitle;
    ui.efCustomXLabel   = efCustomXLabel;
    ui.efCustomYLabel   = efCustomYLabel;
    ui.ddXFmt           = ddXFmt;
    ui.ddYFmt           = ddYFmt;
    % CorrStyle / LivePreview selectors
    ui.ddCorrStyle      = ddCorrStyle;
    ui.cbLivePreview    = cbLivePreview;
    % Cursor readout panel
    ui.cursorPanel      = cursorPanelObj;

    % ── Callback struct for applyParserAnalysisConfig ─────────────────────
    apacCb_ = struct();
    apacCb_.configurePeakWindowForMode = @configurePeakWindowForMode;
    apacCb_.showMagSection             = @showMagSection;
    apacCb_.is2DDataset                = @is2DDataset;
    apacCb_.updateUndoButtons          = @() appData.undoCb.updateUndoButtons();

    % ── Callback struct for onApplyCorrections ────────────────────────────
    corrCb_ = struct();
    corrCb_.onPlot                  = @(varargin) onPlot([],[]);
    corrCb_.setStatus               = @setStatus;
    corrCb_.logGUIError             = @logGUIError;
    corrCb_.markCorrectionsDirty    = @markCorrectionsDirty;
    corrCb_.updateApplyButtonStyle  = @updateApplyButtonStyle;
    corrCb_.recordAction            = @recordAction;
    corrCb_.pushUndoCorrectionEntry = @pushUndoCorrectionEntry;
    corrCb_.updateUndoButtons       = @() appData.undoCb.updateUndoButtons();
    corrCb_.magSampleVolume_cm3     = @magSampleVolume_cm3;
    corrCb_.str2num_trim            = @str2num_trim;
    corrCb_.isNeutronParser         = @isNeutronParser;
    corrCb_.neutronBaseName         = @neutronBaseName;
    corrCb_.BTN_FG                  = BTN_FG;
    corrCb_.BTN_PRIMARY             = BTN_PRIMARY;
    corrCb_.fig                     = fig;

    % ── Callback struct for updateControlsForActiveDataset ───────────────
    ucdsCb_ = struct();
    ucdsCb_.applyParserAnalysisConfig = @applyParserAnalysisConfig;
    ucdsCb_.resolvedCorrStyle         = @resolvedCorrStyle;
    ucdsCb_.onPlot                    = @() onPlot([],[]);
    ucdsCb_.guiXName                  = @guiXName;
    ucdsCb_.guiCountingTime           = @guiCountingTime;
    ucdsCb_.guiParserLabel            = @guiParserLabel;
    ucdsCb_.guiTernary                = @guiTernary;
    ucdsCb_.ensureCell                = @ensureCell;
    ucdsCb_.nan2str                   = @nan2str;
    ucdsCb_.is2DDataset               = @is2DDataset;
    ucdsCb_.isNeutronParser           = @isNeutronParser;
    ucdsCb_.neutronBaseName           = @neutronBaseName;
    ucdsCb_.extractWavelength_A       = @extractWavelength_A;
    ucdsCb_.refreshPeakTable          = peakCb.refreshPeakTable;
    ucdsCb_.refreshDataTable          = @refreshDataTable;
    ucdsCb_.toggleY2Appearance        = @toggleY2Appearance;
    ucdsCb_.onAxisChanged             = @onAxisChanged;
    ucdsCb_.computeQSpace             = @(map) parser.computeQSpace(map);

    % ── Callback struct for plotTemplates ────────────────────────────────
    ptCb_ = struct();
    ptCb_.onApplyCorrections = @(varargin) onApplyCorrections([],[]);
    ptCb_.setStatus          = @setStatus;
    ptCb_.logGUIError        = @logGUIError;
    ptCb_.getLastDir         = @() appData.lastDir;
    ptCb_.BTN_PRIMARY        = BTN_PRIMARY;
    ptCb_.BTN_TOOL           = BTN_TOOL;
    ptCb_.BTN_FG             = BTN_FG;
    ptCb_.fig                = fig;

    % ── Analysis callbacks (extracted to +bosonPlotter/analysisCallbacks.m) ─
    anaCtx_ = struct( ...
        'appData',     appData, ...
        'fig',         fig, ...
        'ax',          ax, ...
        'lbY',         lbY, ...
        'lbDatasets',  lbDatasets, ...
        'cbOverlayMode', cbOverlayMode, ...
        'ui',          ui, ...
        'ptCb_',       ptCb_, ...
        'BTN_PRIMARY', BTN_PRIMARY, ...
        'BTN_TOOL',    BTN_TOOL, ...
        'BTN_FG',      BTN_FG, ...
        'headless',    headless, ...
        'setStatus',             @setStatus, ...
        'recordAction',          @recordAction, ...
        'ensureCell',            @ensureCell, ...
        'onPlot',                @(varargin) onPlot([],[]), ...
        'resolveActiveAppearance', @resolveActiveAppearance, ...
        'updateFileList',          @updateFileList, ...
        'updateControlsForActiveDataset', @updateControlsForActiveDataset, ...
        'buildDs',               @buildDs, ...
        'getActiveXY',           @getActiveXY, ...
        'getPlotData',           @getPlotData, ...
        'peakCb',                peakCb, ...
        'showPeakWindow',        @showPeakWindow);
    anaCb = bosonPlotter.analysisCallbacks(anaCtx_);

    % ── Table callbacks (extracted to +bosonPlotter/tableCallbacks.m) ────
    tblCtx_ = struct( ...
        'appData',           appData, ...
        'tblData',           tblData, ...
        'tblUnits',          tblUnits, ...
        'lblTableStats',     lblTableStats, ...
        'efFilter',          efFilter, ...
        'fig',               fig, ...
        'setStatus',         @setStatus, ...
        'getPlotData',       @getPlotData, ...
        'onPlot',            @(varargin) onPlot([], []), ...
        'refreshDataTable',  @refreshDataTable, ...
        'onColumnDragStart', @onColumnDragStart, ...
        'guiXName',          @guiXName);
    tblCb = bosonPlotter.tableCallbacks(tblCtx_);
    % Rewire early-wired placeholder callbacks to real implementations
    btnTableSaveAs.ButtonPushedFcn    = tblCb.onTableSaveAs;
    btnTableMask.ButtonPushedFcn      = tblCb.onTableMaskSelected;
    btnTableUnmask.ButtonPushedFcn    = tblCb.onTableUnmaskAll;
    btnTableDescStats.ButtonPushedFcn = tblCb.onDescriptiveStats;
    btnSortAsc.ButtonPushedFcn        = @(~,~) tblCb.onTableSort('ascend');
    btnSortDesc.ButtonPushedFcn       = @(~,~) tblCb.onTableSort('descend');
    efFilter.ValueChangedFcn          = tblCb.onFilterApply;
    btnFilterApply.ButtonPushedFcn    = tblCb.onFilterApply;
    btnFilterClear.ButtonPushedFcn    = tblCb.onFilterClear;
    tblUnits.CellEditCallback         = tblCb.onUnitsCellEdit;
    tblUnits.CellSelectionCallback    = tblCb.onUnitsCellSelection;
    tblData.CellEditCallback          = tblCb.onTableCellEdit;
    tblData.CellSelectionCallback     = tblCb.onTableSelectionChanged;
    miMaskRows.MenuSelectedFcn        = tblCb.onTableMaskSelected;
    miUnmaskRows.MenuSelectedFcn      = tblCb.onTableUnmaskSelected;
    miUnmaskAll.MenuSelectedFcn       = tblCb.onTableUnmaskAll;

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
    api.undo                = @() appData.undoCb.onUndo([],[]);
    api.redo                = @() appData.undoCb.onRedo([],[]);
    api.undoMgr             = @() appData.undoMgr;
    api.autoPeaks           = @() peakCb.onAutoPeak([],[]);
    api.fitPeaks            = @() peakCb.onFitPeaks([],[]);
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
    % Phase A style API
    api.setTemplate         = @setTemplateDirect;
    api.getTemplate         = @() appData.activeTemplate;
    api.getAppearance       = @resolveActiveAppearance;
    api.getAxes             = @() ax;
    % Mag unit conversion API (Stage A/C)
    api.setFieldUnit        = @setFieldUnitDirect;
    api.setMomentUnit       = @setMomentUnitDirect;
    % Phase B plot style overrides API
    api.openPlotStyle       = @onOpenPlotStyleDialog;
    api.getStyleOverrides   = @() appData.styleOverrides;
    api.setStyleOverrides   = @assignStyleOverrides;
    api.getModel            = @() appData.model;
    api.getActiveDataset    = @getActiveDatasetSafe;
    api.setMap2DColormap    = @setMap2DColormapDirect;
    api.maskRegion          = @maskRegionDirect;
    api.unmaskAll           = @() onUnmaskAll([],[]);
    api.fringeThickness     = @fringeThicknessDirect;
    api.clearFringe         = @clearFringeMarkers;
    api.boxIntegrate2D      = @boxIntegrate2DDirect;
    api.setBoxIntSize       = @setBoxIntSizeDirect;
    api.arcIntegrate2D      = @arcIntegrate2DDirect;
    api.refreshState        = @refreshState;
    api.reset               = @resetGUIDirect;

    % ── Testability API (headless test hooks) ──────────────────────────
    api.getPlotData         = @(idx) getPlotData(idx);
    api.refreshDataTable    = @() refreshDataTable();
    api.getMacroLog         = @() appData.macroLog;
    api.isMacroRecording    = @() appData.macroRecording;
    api.startMacroRecord    = @() onToggleMacroRecord([], []);
    api.stopMacroRecord     = @() onToggleMacroRecord([], []);
    api.getHistory          = @(idx)    historyAPI('get',    idx, '');
    api.exportHistory       = @(idx, p) historyAPI('export', idx, p);
    api.formatHistory       = @(idx)    historyAPI('format', idx, '');
    api.showDecomposition   = @() peakCb.onShowDecomposition([],[]);
    api.getTableData        = @() struct( ...
        'data',     {tblData.Data}, ...
        'colNames', {tblData.ColumnName}, ...
        'working',  appData.tableWorkingCopy, ...
        'units',    {appData.tableUnits});
    api.descriptiveStats    = @() tblCb.onDescriptiveStats([],[]);

    % ── Toolbar API (for testing) ──────────────────────────────────────
    api.getToolbarConfig    = @() appData.toolbarConfig;
    api.setToolbarConfig    = @(cfg) setToolbarConfigDirect(cfg);
    api.getToolbarGL        = @() axToolbarGL;
    api.getToolbarRegistry  = @() tbActions;

    % ── Plot interactions API (for testing) ───────────────────────────
    api.getCursorPanel      = @() cursorPanelObj;
    api.getAxGL             = @() axGL;

    % ── Drag-to-plot API (for testing) ────────────────────────────────
    api.setChannelFromDrag  = @(col, tgt) setChannelFromDrag(col, tgt);
    api.getDragState        = @() struct( ...
        'active',   appData.columnDragActive, ...
        'pending',  appData.columnDragPending, ...
        'colName',  appData.columnDragColName);

    % ── Phase G style API (for testing) ──────────────────────────────
    % These let headless tests exercise the per-dataset override
    % cascade and the plot-style switches without clicking through the
    % dialog.  They write appData state directly, then trigger a
    % replot so the changes land on the visible axes.
    api.setDatasetStyleOverride = @setDatasetStyleOverrideDirect;
    api.setStyle                = @(s) onStylePick(s);
    api.setShowLegend           = @setShowLegendDirect;
    api.setTheme                = @(name) setThemeDirect(name);

    % ── Recent files API (for testing) ───────────────────────────────
    api.getRecentFiles          = @() appData.recentFiles;

    % ── Notes / rename API (for testing) ──────────────────────────────
    api.setDatasetNotes = @(idx, txt) dsFieldOp('set', idx, 'notes', char(txt));
    api.getDatasetNotes = @(idx) dsFieldOp('get', idx, 'notes', '');
    api.renameDataset   = @(idx, name) dsFieldOp('rename', idx, '', char(name));

    % Populate recent dropdown from persisted state
    updateRecentDropdown();

    % ── If launched with a shared Model, refresh dataset list now ────────
    % (datasets were loaded into appData.datasets before the GUI was built,
    %  but rebuildDatasetList / updateControlsForActiveDataset need all GUI
    %  handles to exist — they are guaranteed to exist at this point)
    if ~isempty(options.Model) && isa(options.Model, 'dataWorkspace.WorkspaceModel') ...
            && ~isempty(appData.datasets)
        rebuildDatasetList(true);
        updateControlsForActiveDataset();
    end

    % ── Autosave: check for crash recovery ───────────────────────────
    % Deferred to here so all GUI callbacks exist before restoring data.
    if ~headless && bosonPlotter.autosave.check()
        try
            answer = uiconfirm(fig, ...
                'An unsaved session was found (possible crash recovery). Restore it?', ...
                'Recover Session', ...
                'Options', {'Restore', 'Discard'}, ...
                'DefaultOption', 'Restore', 'CancelOption', 'Discard');
            if strcmp(answer, 'Restore')
                [recoveredDS, recovered] = bosonPlotter.autosave.restore();
                appData.datasets  = recoveredDS;
                appData.activeIdx = recovered.activeIdx;
                appData.lastDir   = recovered.lastDir;
                rebuildDatasetList(true);
                updateControlsForActiveDataset();
                onPlot([], []);
                setStatus(sprintf('Restored %d dataset(s) from autosave (%s).', ...
                    numel(recoveredDS), char(recovered.timestamp, 'HH:mm')));
            else
                bosonPlotter.autosave.cleanup();
            end
        catch ME
            fprintf(2, '[BosonPlotter] Autosave recovery failed: %s\n', ME.message);
            bosonPlotter.autosave.cleanup();
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  NESTED CALLBACKS  (share appData + all control handles via closure)
    % ════════════════════════════════════════════════════════════════════

    % ── Dataset management ───────────────────────────────────────────────

    function onAddFiles(~,~)
    %ONADDFILES  Open a multi-select file dialog; load every chosen file.
        startDir = resolveStartDir(appData.lastDir);
        [fnames, fpath] = uigetfile( ...
            {'*.dat;*.csv;*.tsv;*.txt;*.xlsx;*.xls;*.xlsm;*.xlsb;*.ods;*.raw;*.brml;*.xrdml;*.refl;*.pnr;*.datA;*.datB;*.datC;*.datD;*.data;*.datb;*.datc;*.datd;*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff;*.bcf;*.dm3;*.dm4;*.mrc;*.mrcs;*.ser;*.spm;*.000;*.001', ...
                'All supported formats'; ...
             '*.xrdml;*.raw;*.brml', 'XRD files (*.xrdml, *.raw, *.brml)'; ...
             '*.dat;*.datA;*.datB;*.datC;*.datD', 'VSM / PPMS / MPMS / Lake Shore / Neutron (*.dat, *.datA-D)'; ...
             '*.csv;*.tsv;*.txt', 'Text / CSV (*.csv, *.tsv, *.txt)'; ...
             '*.xlsx;*.xls;*.xlsm;*.xlsb;*.ods', 'Excel / Spreadsheet'; ...
             '*.dm3;*.dm4;*.mrc;*.mrcs;*.ser;*.bcf;*.spm', 'Microscopy (*.dm3/4, *.mrc, *.ser, *.bcf, *.spm)'; ...
             '*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff', 'Images (*.jpg, *.png, *.tif, ...)'; ...
             '*.refl;*.pnr', 'Neutron reflectometry (*.refl, *.pnr)'; ...
             '*.*', 'All files (*.*)'}, ...
            'Select data file(s)', startDir, ...
            'MultiSelect', 'on');
        if isequal(fnames, 0), return; end

        appData.lastDir = fpath;
        if ischar(fnames), fnames = {fnames}; end
        fpaths = cellfun(@(f) fullfile(fpath, f), fnames, 'UniformOutput', false);
        loadFilePaths(fpaths);
    end

    function onDropFiles(~, e)
    %ONDROPFILES  Delegate to extracted +bosonPlotter module.
        odfCb_.loadFilePaths = @loadFilePaths;
        bosonPlotter.onDropFiles(fig, e, odfCb_);
    end

    function loadFilePaths(fpaths)
    %LOADFILEPATHS  Delegate — see +bosonPlotter/loadFilePaths.m.
        cb = struct( ...
            'buildDs',                       @buildDs, ...
            'guiImport',                     @guiImport, ...
            'setStatus',                     @setStatus, ...
            'addToRecentFiles',              @addToRecentFiles, ...
            'logGUIError',                   @logGUIError, ...
            'cancelInteractions',            @cancelInteractions, ...
            'rebuildDatasetList',            @(keep) rebuildDatasetList(keep), ...
            'updateControlsForActiveDataset',@updateControlsForActiveDataset, ...
            'estimateDatasetMemoryMB',       @estimateDatasetMemoryMB, ...
            'recordAction',                  @recordAction, ...
            'onPlot',                        @() onPlot([],[]));
        bosonPlotter.loadFilePaths(appData, fpaths, fig, headless, cb);
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
        widgets  = buildSessionWidgets_();
        guiState = bosonPlotter.sessionManager.collectGuiState(widgets);
        bosonPlotter.sessionManager.save(outPath, appData, guiState);
    end

    function loadSessionDirect(matPath)
    %LOADSESSIONDIRECT  Load session from .mat file (no dialog).
        if nargin < 1 || isempty(matPath)
            error('matPath required');
        end
        [datasets, restored] = bosonPlotter.sessionManager.load(matPath);

        cancelInteractions();

        appData.datasets  = datasets;
        appData.activeIdx = restored.activeIdx;
        appData.bgFile    = restored.bgFile;
        appData.bgDataset = restored.bgDataset;
        appData.style     = restored.style;
        appData.lastDir   = restored.lastDir;
        % Phase A/B visual state (shared with onLoadSession)
        if isfield(restored, 'activeTemplate') && ~isempty(restored.activeTemplate)
            appData.activeTemplate = restored.activeTemplate;
        end
        if isfield(restored, 'styleOverrides') && isstruct(restored.styleOverrides)
            appData.styleOverrides = restored.styleOverrides;
        end
        bosonPlotter.syncWorkspaceModelFromSession(appData, datasets, restored);
        % Sync the Template dropdown so the UI matches restored state
        try refreshTemplateDropdown(); catch, end
        if ~isempty(ddTemplate) && isvalid(ddTemplate) && ...
           any(strcmp(ddTemplate.Items, appData.activeTemplate))
            ddTemplate.Value = appData.activeTemplate;
        end

        widgets = buildSessionWidgets_();
        bosonPlotter.sessionManager.applyGuiState(restored.guiState, widgets);

        rebuildDatasetList(true);
        if ~isempty(appData.datasets)
            bosonPlotter.sessionManager.applyAxisSelections(restored.guiState, widgets);
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

    function boxIntegrate2DDirect(xLo, xHi, yLo, yHi, profileAxis)
    %BOXINTEGRATE2DDIRECT  Programmatically integrate a rectangular region of a 2D map.
    %   xLo, xHi — X bounds (axis2 / 2Theta / Qx)
    %   yLo, yHi — Y bounds (axis1 / Omega / Qz)
    %   profileAxis — 'axis1' (sum along axis2) or 'axis2' (sum along axis1)
        extract2DBoxIntegral(xLo, yLo, xHi, yHi, profileAxis);
        drawnow;
    end

    function setBoxIntSizeDirect(w, h)
    %SETBOXINTSIZEDIRECT  Set the fixed box-integration dimensions.
    %   w, h — width and height in axis units. Pass '' or 0 to clear.
        if isempty(w) || (isnumeric(w) && w <= 0)
            efBoxIntW.Value = '';
        else
            efBoxIntW.Value = sprintf('%.6g', w);
        end
        if isempty(h) || (isnumeric(h) && h <= 0)
            efBoxIntH.Value = '';
        else
            efBoxIntH.Value = sprintf('%.6g', h);
        end
    end

    function arcIntegrate2DDirect(qMin, qMax, nBins, varargin)
    %ARCINTEGRATE2DDIRECT  Programmatically perform arc integration on a 2D RSM.
    %   qMin, qMax  — Q-radius range (Ang^-1)
    %   nBins       — number of radial bins
    %   Name-Value:
    %     SectorMin  — azimuthal start angle in degrees (default 0)
    %     SectorMax  — azimuthal end angle in degrees (default 360)
    %     Mode       — 'Sum' (default) or 'Mean'
        p = inputParser;
        addRequired(p, 'qMin',  @isnumeric);
        addRequired(p, 'qMax',  @isnumeric);
        addRequired(p, 'nBins', @isnumeric);
        addParameter(p, 'SectorMin', 0,     @isnumeric);
        addParameter(p, 'SectorMax', 360,   @isnumeric);
        addParameter(p, 'Mode',      'Sum', @(x) ischar(x)||isstring(x));
        parse(p, qMin, qMax, nBins, varargin{:});
        params.qMin = p.Results.qMin;
        params.qMax = p.Results.qMax;
        params.nBins = round(p.Results.nBins);
        params.sectorMin = p.Results.SectorMin;
        params.sectorMax = p.Results.SectorMax;
        params.mode = char(p.Results.Mode);
        extract2DArcIntegral(params);
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

    function refreshState()
    %REFRESHSTATE  Flush internal caches and re-sync GUI without losing data.
    %  Bound to F5 and available in the axes right-click menu.  This is the
    %  lightweight alternative to `clear all` + `setupToolbox` — it clears
    %  stale cached state that can cause display glitches while preserving
    %  all loaded datasets, the figure, and the undo history.
    %
    %  What it does:
    %    1. Invalidate lineCache → forces full line-handle rebuild
    %    2. Clear persistent caches in parsers and calc modules
    %    3. Cancel any in-progress interactions (zoom rect, mask, cursor)
    %    4. Re-sync all widget states from appData
    %    5. Force a full redraw

        % 1. Invalidate line cache
        appData.lineCache.valid = false;
        appData.lineCache.left  = {};
        appData.lineCache.right = {};

        % 2. Clear persistent caches in parsers and calc modules
        clear parser.importPPMS;    % clears PPMS_SHORTHAND_MAP
        clear parser.importQDVSM;   % clears QD_SHORTHAND_MAP
        clear calc.constants;       % clears cachedC
        clear calc.elementData;     % clears cachedElements
        clear calc.unitConvert;     % clears cachedReg, cachedPre
        clear calc.crystalCache;    % clears cachedDB, cachedMtime

        % 3. Cancel in-progress interactions
        cancelInteractions();

        % 4. Re-sync widgets from appData
        if ~isempty(appData.datasets) && appData.activeIdx > 0
            updateControlsForActiveDataset();
            rebuildDatasetList(true);
        end

        % 5. Force full redraw
        if ~isempty(appData.datasets) && appData.activeIdx > 0
            drawToAxes(ax);
        end
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
        appData.boxIntStartPt     = [];
        appData.boxIntPatch       = [];
        appData.boxIntMode        = false;
        clearBoxPreview();

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
        cbMap2DQSpace.Value  = false;
        efBoxIntW.Value      = '';
        efBoxIntH.Value      = '';

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

    function setToolbarConfigDirect(cfg)
    %SETTOOLBARCONFIGDIRECT  Programmatically set toolbar config and rebuild.
    %  Used by automated tests. An empty cell array ({}) falls back to
    %  the factory default configuration.
        if ~iscell(cfg)
            error('BosonPlotter:setToolbarConfigDirect:invalidInput', ...
                'cfg must be a cell array of action ID strings.');
        end
        % Normalize: accept empty cell → factory defaults; accept row or
        % column vectors; reject multi-dimensional cell arrays.
        if isempty(cfg)
            cfg = bosonPlotter.toolbarDefaultConfig();
        elseif ~isvector(cfg)
            error('BosonPlotter:setToolbarConfigDirect:invalidInput', ...
                'cfg must be a 1×N cell array of action ID strings.');
        end
        appData.toolbarConfig = cfg;
        buildToolbar(axToolbarGL, cfg, tbActions, BTN_TOOL);
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
        tipStr = sprintf('%s\nParser: %s  |  %d points  |  %s', ...
            ds.filepath, pName, nPts, hasCorrStr);
        if isfield(ds, 'notes') && ~isempty(ds.notes)
            tipStr = sprintf('%s\nNote: %s', tipStr, ds.notes);
        end
        lbDatasets.Tooltip = tipStr;

        % Always replot — selection may have changed even if active didn't
        onPlot([],[]);
    end

    function onSearchChanged(~,~)
    %ONSEARCHCHANGED  Update dataset list filter when search box text changes.
        appData.searchFilter = efDatasetSearch.Value;
        rebuildDatasetList(true);
    end

    function clearDatasetSearch()
    %CLEARDATASETSEARCH  Empty the filter field and refresh the dataset list.
        efDatasetSearch.Value = '';
        onSearchChanged();
    end

    function onMergeDatasets(~,~)
    %ONMERGEDATASETS  Delegate — see +bosonPlotter/mergeDatasets.m.
        cb.buildDs                        = @buildDs;
        cb.cancelInteractions             = @cancelInteractions;
        cb.rebuildDatasetList              = @(keep) rebuildDatasetList(keep);
        cb.updateControlsForActiveDataset = @updateControlsForActiveDataset;
        cb.onPlot                         = @() onPlot([],[]);
        bosonPlotter.mergeDatasets(appData, fig, ui, cb);
    end

    function onDatasetMath(~,~)
    %ONDATASETMATH  Delegate — see +bosonPlotter/datasetMath.m.
        cb.buildDs                        = @buildDs;
        cb.setStatus                      = @setStatus;
        cb.rebuildDatasetList              = @(keep) rebuildDatasetList(keep);
        cb.updateControlsForActiveDataset = @updateControlsForActiveDataset;
        cb.onPlot                         = @() onPlot([],[]);
        cb.logGUIError                    = @logGUIError;
        bosonPlotter.datasetMath(appData, fig, cb);
    end

    function onDatasetColorChanged(~,~)
    %ONDATASETCOLORCHANGED  Store colour override on the active dataset and replot.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds       = appData.datasets{appData.activeIdx};
        ds.color = ddDatasetColor.Value;   % [] = Auto; [r g b] = named colour
        appData.datasets{appData.activeIdx} = ds;
        bosonPlotter.softUpdateLines(appData, struct('onPlot', @onPlot));  % Fast path: update only colors/visibility
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
    %ONREMOVEDATASET  Delegate — see +bosonPlotter/removeDataset.m.
        cb.cancelInteractions             = @cancelInteractions;
        cb.rebuildDatasetList              = @(keep) rebuildDatasetList(keep);
        cb.updateControlsForActiveDataset = @updateControlsForActiveDataset;
        cb.onPlot                         = @() onPlot([],[]);
        bosonPlotter.removeDataset(appData, fig, ax, ui, headless, cb);
    end

    function onToggleAnimation(~,~)
    %ONTOGGLEANIMATION  Start/stop cycling through datasets as animation frames.
    %  Uses a MATLAB timer at ~2 fps to step through each dataset in sequence.
    %  The animate button lives on the axes toolbar (tag = 'animate'); we
    %  look it up by tag so the button text/colour can be toggled even
    %  though the toolbar is rebuilt dynamically.
        animBtn = findTagInChildren(axToolbarGL, 'animate');
        iconDir = fullfile(fileparts(mfilename('fullpath')), 'icons', 'bosonplotter');
        if isprop(appData, 'animTimer') && ~isempty(appData.animTimer) && isvalid(appData.animTimer)
            % Stop animation
            stop(appData.animTimer);
            delete(appData.animTimer);
            appData.animTimer = [];
            if ~isempty(animBtn)
                animBtn.Text = 'Animate';
                playP = fullfile(iconDir, 'animate.png');
                if isfile(playP), animBtn.Icon = playP; end
                animBtn.BackgroundColor = BTN_TOOL;
            end
            return;
        end

        if numel(appData.datasets) < 2
            uialert(fig,'Need at least 2 datasets to animate.','Animate'); return;
        end

        if ~isempty(animBtn)
            animBtn.Text = 'Stop';
            stopP = fullfile(iconDir, 'stop.png');
            if isfile(stopP), animBtn.Icon = stopP; end
            animBtn.BackgroundColor = BTN_DANGER;
        end

        appData.animTimer = timer('ExecutionMode', 'fixedRate', ...
            'Period', 0.5, ...
            'TimerFcn', @(~,~) animStep());
        start(appData.animTimer);
    end

    function h = findTagInChildren(parent, tagStr)
    %FINDTAGINCHILDREN  Return the first child of parent whose .Tag matches
    %  tagStr, or [] if none. Used to locate toolbar buttons built
    %  dynamically from the tbActions registry.
        h = [];
        if isempty(parent) || ~isvalid(parent), return; end
        kids = parent.Children;
        for kk = 1:numel(kids)
            if isprop(kids(kk),'Tag') && strcmp(kids(kk).Tag, tagStr)
                h = kids(kk); return;
            end
        end
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
            'Ctrl+S              Save session\n' ...
            'Ctrl+Z              Undo last operation\n' ...
            'Ctrl+Y / Ctrl+Shift+Z  Redo\n' ...
            'Ctrl+C              Copy plot to clipboard\n' ...
            'Ctrl+E              Export CSV\n' ...
            'Delete              Remove selected dataset\n' ...
            'Left / Right        Switch dataset\n' ...
            'Space               Toggle dataset visibility\n' ...
            'Ctrl+Up             Move dataset up\n' ...
            'Ctrl+Down           Move dataset down']);
        uialert(fig, msg, 'Keyboard Shortcuts', 'Icon', 'info');
    end

    function saveAxisLimsToActiveDataset()
    %SAVEAXISLIMSTOACTIVEDATASET  Delegate to extracted +bosonPlotter module.
        bosonPlotter.saveAxisLimsToActiveDataset(appData, ui, ax);
    end

    function rebuildDatasetList(keepActiveIdx)
    %REBUILDDATASETLIST  Delegate — see +bosonPlotter/rebuildDatasetList.m.
        bosonPlotter.rebuildDatasetList(appData, ui, keepActiveIdx);
    end

    function cancelInteractions()
    %CANCELINTERACTIONS  Delegate to extracted +bosonPlotter module.
        ciWidgets_.btnMaskSelect      = btnMaskSelect;
        ciWidgets_.btnFringeThick     = btnFringeThick;
        ciWidgets_.btnFitBG           = btnFitBG;
        ciWidgets_.btnPickY           = btnPickY;
        ciWidgets_.btnYTranslate      = btnYTranslate;
        ciWidgets_.btnAutoPeak        = btnAutoPeak;
        ciWidgets_.btnManualPeak      = btnManualPeak;
        ciWidgets_.btnRemovePeakClick = btnRemovePeakClick;
        ciWidgets_.lblRegionStats     = lblRegionStats;
        ciCb_.onAxesButtonDown        = @onAxesButtonDown;
        ciCb_.onMouseHover            = @onMouseHover;
        ciCb_.clearBoxPreview         = @clearBoxPreview;
        ciCb_.clearCompletedBoxPatch  = @clearCompletedBoxPatch;
        ciCb_.clearFringeMarkers      = @clearFringeMarkers;
        ciCb_.BTN_ACCENT              = BTN_ACCENT;
        ciCb_.BTN_DANGER              = BTN_DANGER;
        ciCb_.BTN_INTERACT            = BTN_INTERACT;
        bosonPlotter.cancelInteractions(appData, fig, ciWidgets_, ciCb_);
    end

    function updateControlsForActiveDataset()
    %UPDATECONTROLSFORACTIVEDATASET  Delegate to extracted +bosonPlotter module.
        bosonPlotter.updateControlsForActiveDataset(appData, ui, ucdsCb_);
    end

    % ── Axis / style callbacks ────────────────────────────────────────────

    function onAxisChanged(~,~)
        if appData.activeIdx > 0 && ~isempty(appData.datasets)
            onPlot([],[]);
        end
    end

    function applyParserAnalysisConfig(pName)
    %APPLYPARSERANALYSISCONFIG  Delegate to extracted +bosonPlotter module.
        bosonPlotter.applyParserAnalysisConfig(pName, appData, ui, CROW, peakFig, apacCb_);
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
                    try
                        appData.model.updateDataset(appData.activeIdx, ds);
                    catch
                    end
                    rebuildDatasetList();
                    updateControlsForActiveDataset();
                    onPlot([],[]);
                    return;  % updateControls already calls applyParserAnalysisConfig
                catch ME
                    warning('BosonPlotter:simsReimport', ...
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
                ddFieldUnit.Value  = 'Oe';
                ddMomentUnit.Value = 'emu';
            case 'SI'
                ddFieldUnit.Value  = 'T';
                ddMomentUnit.Value = 'A·m²';
        end
        markCorrectionsDirty();
    end

    function onAutoMagCorrections(~,~)
    %ONATOMAGCORRECTIONS  Delegate — see +bosonPlotter/computeAutoMagCorrections.m.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        doAll   = strcmp(ddAutoMagScope.Value, 'All Datasets');
        indices = guiTernary(doAll, 1:numel(appData.datasets), appData.activeIdx);
        corrections = bosonPlotter.computeAutoMagCorrections( ...
            appData.datasets, indices, lbY.Value);
        if isempty(corrections)
            uialert(fig, 'No magnetometry datasets found to correct.', 'Auto BG');
            return;
        end
        origIdx = appData.activeIdx;
        for ci = 1:numel(corrections)
            c = corrections(ci);
            appData.activeIdx = c.di;
            updateControlsForActiveDataset();
            efBGSlope.Value     = c.slope;
            efBGIntercept.Value = c.intercept;
            efYOffset.Value     = c.yOff;
            ds = appData.datasets{c.di};
            ds.bgPoly = [];
            appData.datasets{c.di} = ds;
            onApplyCorrections([], []);
        end
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
        peakCb.refreshPeakTable();
        if ~headless
            peakFig.Visible = 'on';
            figure(peakFig);  % bring to front
        end
    end

    function configurePeakWindowForMode(mode)
    %CONFIGUREPEAKWINDOWFORMODE  Show/hide mode-specific buttons in the peak window.
    %  mode: 'xrd', 'reflectometry', or 'none'
        % Bail if the peak figure was externally deleted — the body reads
        % and writes .Name / .Visible / child-button .Visible, all of
        % which error on an invalid handle.
        if ~isvalid(peakFig), return; end
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
    %ONYTRANSLATEDRAG  Delegate to extracted +bosonPlotter module.
        oytdWidgets_.btnYTranslate = btnYTranslate;
        oytdWidgets_.btnAutoPeak   = btnAutoPeak;
        oytdWidgets_.btnManualPeak = btnManualPeak;
        oytdWidgets_.efYOffset     = efYOffset;
        oytdWidgets_.BTN_ACCENT    = BTN_ACCENT;
        oytdCb_.cancelInteractions = @cancelInteractions;
        oytdCb_.onApplyCorrections = @onApplyCorrections;
        oytdCb_.onAxesButtonDown   = @onAxesButtonDown;
        oytdCb_.onMouseHover       = @onMouseHover;
        bosonPlotter.onYTranslateDrag(appData, fig, ax, oytdWidgets_, oytdCb_);
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
        peakCb.refreshPeakTable();
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
                peakCb.refreshPeakTable();
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
        peakCb.refreshPeakTable();
    end

    function onInstBroadeningChanged(src, ~)
    %ONINSTBROADENINGCHANGED  User edited the instrument broadening field.
    %   Saves value to appData and refreshes the Size (nm) column.
        v = src.Value;
        appData.instBroadening_deg = guiTernary(isnan(v) || v < 0, 0, v);
        peakCb.refreshPeakTable();
    end

    % ════════════════════════════════════════════════════════════════════
    %  2.3  LATTICE PARAMETER REFINEMENT
    % ════════════════════════════════════════════════════════════════════

    function onRefineLattice(~, ~)
    %ONREFINELATTICE  Open a dialog to assign hkl indices and refine lattice parameters.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        ds   = appData.datasets{appData.activeIdx};
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
        result = bosonPlotter.peakTools.refineLattice(ds, wl_A, ...
            ParentFig=fig, StatusFcn=@setStatus, ...
            ButtonColors=struct('primary', BTN_PRIMARY, 'fg', BTN_FG));
        if ~isempty(result)
            ds2 = appData.datasets{appData.activeIdx};
            ds2.latticeParams = result;
            appData.datasets{appData.activeIdx} = ds2;
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  3.1a  PHASE IDENTIFICATION (PEAK DATABASE MATCHING)
    % ════════════════════════════════════════════════════════════════════

    function onMatchPhases(~, ~)
    %ONMATCHPHASES  Thin wrapper — delegates to bosonPlotter.peakTools.matchPhases.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        ds   = appData.datasets{appData.activeIdx};
        wl_A = extractWavelength_A(ds);
        if isnan(wl_A) || wl_A <= 0
            uialert(fig, ['Wavelength is required for phase matching.  ' ...
                          'Enter a value in the ' char(955) ' field or select an X-ray source.'], ...
                'Wavelength needed'); return;
        end
        try
            bosonPlotter.peakTools.matchPhases(ds, wl_A, ...
                ParentFig=fig, StatusFcn=@setStatus, MainAx=ax);
        catch ME
            logGUIError('Phase Match Error', ME.message, ME);
            uialert(fig, sprintf('Phase matching failed:\n\n%s', ME.message), 'Error');
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  3.1  FILM THICKNESS FROM LAUE FRINGES (FFT)
    % ════════════════════════════════════════════════════════════════════

    function onFFTThickness(~, ~)
    %ONFFTTHICKNESS  Thin wrapper — delegates to bosonPlotter.peakTools.fftThickness.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        ds   = appData.datasets{appData.activeIdx};
        wl_A = extractWavelength_A(ds);
        if isnan(wl_A) || wl_A <= 0
            uialert(fig, ['Wavelength is required for FFT thickness.  ' ...
                          'Enter a value in the ' char(955) ' field.'], ...
                'No wavelength'); return;
        end
        result = bosonPlotter.peakTools.fftThickness(ds, wl_A, ...
            ParentFig=fig, StatusFcn=@setStatus, ...
            ButtonColors=struct('accent', BTN_ACCENT, 'fg', BTN_FG), ...
            AxisLimits=ax.XLim);
        if ~isempty(result)
            ds2 = appData.datasets{appData.activeIdx};
            ds2.filmThickness = result;
            appData.datasets{appData.activeIdx} = ds2;
        end
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
    %ONFRINGECLICK  Delegate to extracted +bosonPlotter module.
        ofcWidgets_.lbY            = lbY;
        ofcWidgets_.btnFringeThick = btnFringeThick;
        ofcCb_.onFringeMarkerDown    = @onFringeMarkerDown;
        ofcCb_.onAxesButtonDown      = @onAxesButtonDown;
        ofcCb_.onMouseHover          = @onMouseHover;
        ofcCb_.updateFringeThickness = @updateFringeThickness;
        ofcCb_.BTN_ACCENT            = BTN_ACCENT;
        bosonPlotter.onFringeClick(appData, fig, ax, ofcWidgets_, ofcCb_);
    end

    function onFringeMarkerDown(markerIdx)
    %ONFRINGEMARKERDOWN  Delegate to extracted +bosonPlotter module.
        bosonPlotter.onFringeMarkerDown(markerIdx, appData, fig, ax, lbY, fringeCallbacks_());
    end

    function updateFringeThickness()
    %UPDATEFRINGETHICKNESS  Delegate to extracted +bosonPlotter module.
        bosonPlotter.updateFringeThickness(appData, ax, fringeCallbacks_());
    end

    function recreateFringeMarkers()
    %RECREATEFRINGEMARKERS  Delegate to extracted +bosonPlotter module.
        bosonPlotter.recreateFringeMarkers(appData, ax, lbY, fringeCallbacks_());
    end

    function clearFringeMarkers()
    %CLEARFRINGEMARKERS  Delegate to extracted +bosonPlotter module.
        bosonPlotter.clearFringeMarkers(appData, ax);
    end

    function cb = fringeCallbacks_()
    %FRINGECALLBACKS_  Build the callbacks struct shared by fringe extractions.
        cb = struct( ...
            'setStatus',    @setStatus, ...
            'onMouseHover', @onMouseHover, ...
            'fig',          fig);
    end

    % ════════════════════════════════════════════════════════════════════
    %  3.1b  REFLECTIVITY FFT (KIESSIG FRINGES)
    % ════════════════════════════════════════════════════════════════════

    function onReflectivityFFT(~, ~)
    %ONREFLECTIVITYFFT  Compute film thickness from Kiessig fringe periodicity.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};

        isNeutronDS = isfield(ds, 'parserName') && isNeutronParser(ds.parserName);
        wl_A = NaN;
        if ~isNeutronDS
            wl_A = extractWavelength_A(ds);
            if isnan(wl_A) || wl_A <= 0
                uialert(fig, ['Wavelength is required for XRR FFT thickness.  ' ...
                    'Enter a value in the ' char(955) ' field or select an X-ray source.'], ...
                    'No wavelength'); return;
            end
        end

        result = bosonPlotter.peakTools.reflectivityFFT(ds, ...
            WavelengthA=wl_A, ParentFig=fig, StatusFcn=@setStatus, ...
            ButtonColors=struct('accent', BTN_ACCENT, 'fg', BTN_FG), ...
            AxisLimits=ax.XLim, XraySources=XRAY_SOURCES);
        if ~isempty(result)
            ds2 = appData.datasets{appData.activeIdx};
            ds2.kiessigThickness = result;
            appData.datasets{appData.activeIdx} = ds2;
        end
    end

    % ════════════════════════════════════════════════════════════════════
    %  3.2  WILLIAMSON-HALL STRAIN ANALYSIS
    % ════════════════════════════════════════════════════════════════════

    function onWilliamsonHallPlot(~, ~)
    %ONWILLIAMSONHALLPLOT  Williamson-Hall analysis: β·cosθ vs 4·sinθ.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        ds   = appData.datasets{appData.activeIdx};
        wl_A = extractWavelength_A(ds);
        if isnan(wl_A) || wl_A <= 0
            uialert(fig, ['Wavelength is required for Williamson-Hall analysis.  ' ...
                          'Enter a value in the ' char(955) ' field.'], ...
                'No wavelength'); return;
        end
        if isempty(ds.peaks)
            uialert(fig, 'No peaks available.  Find and fit peaks first.', 'No peaks');
            return;
        end
        result = bosonPlotter.peakTools.williamsonHall(ds, wl_A, ...
            appData.kFactor, appData.instBroadening_deg, ...
            ParentFig=fig, StatusFcn=@setStatus);
        if ~isempty(result)
            ds2 = appData.datasets{appData.activeIdx};
            ds2.williamsonHall = result;
            appData.datasets{appData.activeIdx} = ds2;
        end
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

    function onTemplateChanged(src, ~)
    %ONTEMPLATECHANGED  Apply a new visual template and re-render.
    %   Writes the template name into appData.activeTemplate.  Per-dataset
    %   overrides (ds.styleOverride) survive template switches; only the
    %   base layer of the style precedence chain changes.
        try
            appData.activeTemplate = src.Value;
            if appData.activeIdx > 0 && ~isempty(appData.datasets)
                onPlot([],[]);
            end
        catch ME
            uialert(fig, sprintf('Failed to apply template:\n%s', ME.message), ...
                'Template error');
            logGUIError('onTemplateChanged', 'template apply failed', ME);
        end
    end

    function setFieldUnitDirect(u)
    %SETFIELDUNITDIRECT  Programmatic api.setFieldUnit — mirrors dropdown change.
        u = char(u);
        if any(strcmp(ddFieldUnit.Items, u))
            ddFieldUnit.Value = u;
            onMagUnitChanged([], []);
        end
    end

    function setMomentUnitDirect(u)
    %SETMOMENTUNITDIRECT  Programmatic api.setMomentUnit — mirrors dropdown change.
        u = char(u);
        if any(strcmp(ddMomentUnit.Items, u))
            ddMomentUnit.Value = u;
            onMagUnitChanged([], []);
        end
    end

    function onMagUnitChanged(~, ~)
    %ONMAGUNITCHANGED  Trigger a replot when the field or moment unit changes.
    %   Writes the new value into the active dataset so it persists across
    %   dataset switches and survives session save/load.  The actual
    %   numerical conversion happens inside renderPlot / applyDisplayUnits
    %   on-the-fly — ds.data is NEVER mutated (raw values preserved).
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        ds.fieldUnit  = ddFieldUnit.Value;
        ds.momentUnit = ddMomentUnit.Value;
        appData.datasets{appData.activeIdx} = ds;
        onPlot([],[]);
    end

    function setTemplateDirect(name)
    %SETTEMPLATEDIRECT  Programmatic template change (api.setTemplate).
    %   Mirrors the ddTemplate dropdown change — updates the widget value
    %   so the UI stays in sync, writes appData.activeTemplate, and
    %   triggers a replot.
        name = char(name);
        if ~isempty(ddTemplate) && isvalid(ddTemplate)
            if ~any(strcmp(ddTemplate.Items, name))
                % User template not yet in the dropdown list — refresh first
                refreshTemplateDropdown();
            end
            if any(strcmp(ddTemplate.Items, name))
                ddTemplate.Value = name;
            end
        end
        appData.activeTemplate = name;
        if appData.activeIdx > 0 && ~isempty(appData.datasets)
            onPlot([],[]);
        end
    end

    function result = dsFieldOp(op, idx, fld, val)
    %DSFIELDOP  Multipurpose dataset field accessor for test API.
    %   dsFieldOp('set',    idx, 'notes', txt)  — set field, refresh list
    %   dsFieldOp('get',    idx, 'notes', '')    — get field value
    %   dsFieldOp('rename', idx, '',      name)  — set displayName+legendName, replot
        result = '';
        if idx < 1 || idx > numel(appData.datasets), return; end
        switch op
            case 'set'
                appData.datasets{idx}.(fld) = val;
                rebuildDatasetList(true);
            case 'get'
                ds = appData.datasets{idx};
                if isfield(ds, fld), result = ds.(fld); end
            case 'rename'
                appData.datasets{idx}.displayName = val;
                appData.datasets{idx}.legendName  = val;
                rebuildDatasetList(true);
                if appData.activeIdx > 0, onPlot([],[]); end
        end
    end

    function refreshTemplateDropdown()
    %REFRESHTEMPLATEDROPDOWN  Rebuild ddTemplate.Items from built-ins + user templates.
        BUILTIN = {'screen','aps','aps_double','nature','nature_double', ...
                   'thesis','presentation','poster'};
        items = BUILTIN;
        try
            userList = bosonPlotter.userTemplates.list();
            for utIdx2 = 1:numel(userList)
                items{end+1} = ['user:' userList{utIdx2}]; %#ok<AGROW>
            end
        catch
        end
        if ~isempty(ddTemplate) && isvalid(ddTemplate)
            cur = ddTemplate.Value;
            ddTemplate.Items = items;
            if any(strcmp(items, cur))
                ddTemplate.Value = cur;
            end
        end
    end

    function onOpenPlotStyleDialog()
    %ONOPENPLOTSTYLEDIALOG  Launch the Phase B modal style editor.
        dlgCtx = struct();
        dlgCtx.fig                 = fig;
        dlgCtx.theme               = appData.theme;
        dlgCtx.getStyleOverrides   = @() appData.styleOverrides;
        dlgCtx.setStyleOverrides   = @(s) assignStyleOverrides(s);
        dlgCtx.getActiveTemplate   = @() appData.activeTemplate;
        dlgCtx.setActiveTemplate   = @setTemplateDirect;
        dlgCtx.getActiveDataset    = @getActiveDatasetSafe;
        dlgCtx.setActiveDataset    = @setActiveDatasetSafe;
        dlgCtx.getActiveChannelIdx = @getActiveChannelIdxSafe;
        dlgCtx.getActiveChannelName= @getActiveChannelNameSafe;
        dlgCtx.replot              = @() onPlot([],[]);
        dlgCtx.refreshTemplateList = @refreshTemplateDropdown;

        try
            bosonPlotter.plotStyleDialog(fig, dlgCtx);
        catch ME
            uialert(fig, sprintf('Plot Style dialog failed:\n%s', ME.message), ...
                'Style dialog error');
            logGUIError('onOpenPlotStyleDialog', 'dialog failed', ME);
        end
    end

    function onOpenLegendEditor()
    %ONOPENLEGENDEDITOR  Open the multi-dataset legend editor dialog.
    %   Lets the user edit every dataset's legend name / visibility at
    %   once, and adjust shared legend style (location, font, box,
    %   weight). Persists edits via plotState (for visibility) and
    %   styleOverrides (for shared style) so changes survive dataset
    %   toggles and session save/load.
        if isempty(appData.datasets)
            uialert(fig, 'Load at least one dataset first.', 'No data');
            return;
        end
        legCtx = struct();
        legCtx.fig               = fig;
        legCtx.theme             = appData.theme;
        legCtx.getDatasets       = @() appData.datasets;
        legCtx.setDataset        = @(idx, d) assignDataset(idx, d);
        legCtx.getStyleOverrides = @() appData.styleOverrides;
        legCtx.setStyleOverrides = @(s) assignStyleOverrides(s);
        legCtx.getActiveTemplate = @() appData.activeTemplate;
        legCtx.replot            = @() onPlot([],[]);
        try
            bosonPlotter.legendEditor(fig, legCtx);
        catch ME
            uialert(fig, sprintf('Legend editor failed:\n%s', ME.message), ...
                'Legend dialog error');
            logGUIError('onOpenLegendEditor', 'dialog failed', ME);
        end
    end

    function assignDataset(idx, ds)
    %ASSIGNDATASET  Safe write-back helper for dialog callbacks that
    %   mutate per-dataset state (legend name, visibility, etc.).
        if idx >= 1 && idx <= numel(appData.datasets)
            appData.datasets{idx} = ds;
        end
    end

    function assignStyleOverrides(s)
        appData.styleOverrides = s;
    end

    function setDatasetStyleOverrideDirect(s)
    %SETDATASETSTYLEOVERRIDEDIRECT  Test hook: write a sparse style
    %   override onto the active dataset and replot.  The production
    %   path (Plot Style dialog with "Apply to: Active dataset") does
    %   the same mutation via setActiveDataset.  Headless tests use
    %   this to verify the per-dataset override layer without clicking.
        if appData.activeIdx <= 0 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        ds.styleOverride = s;
        appData.datasets{appData.activeIdx} = ds;
        onPlot([], []);
    end

    function setShowLegendDirect(tf)
    %SETSHOWLEGENDDIRECT  Test hook: set legend visibility.
        if logical(tf)
            ddLegendLoc.Value = 'best';
            appData.styleOverrides.legendLocation = 'best';
        else
            ddLegendLoc.Value = 'off';
        end
        onPlot([], []);
    end

    function setThemeDirect(name)
    %SETTHEMEDIRECT  Test hook: flip appData.theme and retheme the
    %   main window.  Mirrors what applyThemeFromDialog does via the
    %   Settings dialog, minus the settings-dialog side-effects.
        name = char(name);
        if ~any(strcmp({'Light','Dark'}, name)), return; end
        appData.theme = name;
        onThemeChanged([], []);
    end

    function ds = getActiveDatasetSafe()
        if appData.activeIdx > 0 && appData.activeIdx <= numel(appData.datasets)
            ds = appData.datasets{appData.activeIdx};
        else
            ds = [];
        end
    end

    function onReportBug()
        % Open the Report-a-Bug dialog, passing the active dataset for context.
        ds = getActiveDatasetSafe();
        if ~isempty(ds) && isstruct(ds) && isfield(ds, 'data') && isstruct(ds.data)
            bugReport.reportBug(Source="BosonPlotter", Dataset=ds.data);
        else
            bugReport.reportBug(Source="BosonPlotter");
        end
    end

    function setActiveDatasetSafe(ds)
        if appData.activeIdx > 0 && appData.activeIdx <= numel(appData.datasets)
            appData.datasets{appData.activeIdx} = ds;
        end
    end

    function idx = getActiveChannelIdxSafe()
        % Return the index (within ds.data.labels) of the first selected
        % Y channel on the main listbox, or [] if none / no dataset.
        idx = [];
        ds = getActiveDatasetSafe();
        if isempty(ds) || ~isfield(ds, 'data'), return; end
        sel = lbY.Value;
        if isempty(sel), return; end
        if ~iscell(sel), sel = {sel}; end
        firstName = char(sel{1});
        iFound = find(strcmp(ds.data.labels, firstName), 1);
        if ~isempty(iFound), idx = iFound; end
    end

    function nm = getActiveChannelNameSafe()
        nm = '';
        sel = lbY.Value;
        if isempty(sel), return; end
        if iscell(sel), nm = char(sel{1}); else, nm = char(sel); end
    end

    function onOpenSettings()
    %ONOPENSETTINGS  Delegate — see +bosonPlotter/openSettings.m.
        cb.applyThemeFromDialog = @applyThemeFromDialog;
        cb.onStylePick          = @onStylePick;
        cb.onCustomiseToolbar   = @onCustomiseToolbar;
        bosonPlotter.openSettings(appData, fig, cb);
    end

    function applyThemeFromDialog(themeName, settingsFig)
    %APPLYTHEMEFROMDIALOG  Apply theme change from the settings dialog.
        appData.theme = themeName;
        onThemeChanged([], []);
        % Update dialog colours to match new theme
        bosonPlotter.applyDialogTheme(settingsFig, themeName);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TOOLBAR CUSTOMISATION
    % ════════════════════════════════════════════════════════════════════

    function buildToolbar(parentGL, config, registry, btnColor)
    %BUILDTOOLBAR  Delegate to extracted +bosonPlotter module.
        bosonPlotter.buildToolbar(parentGL, config, registry, btnColor);
    end

    function cfg = loadToolbarConfig()
    %LOADTOOLBARCONFIG  Load saved toolbar config from prefdir; fall back to default.
        cfg = bosonPlotter.toolbarDefaultConfig();
        try
            prefFile = fullfile(prefdir, 'boson_toolbar.mat');
            if isfile(prefFile)
                s = load(prefFile, 'toolbarConfig');
                if isfield(s, 'toolbarConfig') && iscell(s.toolbarConfig) ...
                        && ~isempty(s.toolbarConfig)
                    cfg = s.toolbarConfig;
                end
            end
        catch
            % Silently use default if load fails
        end
    end

    function saveToolbarConfig(cfg)
    %SAVETOOLBARCONFIG  Persist toolbar config to prefdir.
        try
            prefFile = fullfile(prefdir, 'boson_toolbar.mat');
            toolbarConfig = cfg; %#ok<NASGU>
            save(prefFile, 'toolbarConfig');
        catch
            % Non-fatal — silently skip if write fails
        end
    end

    function onCustomiseToolbar()
    %ONCUSTOMISETOOLBAR  Open the toolbar customisation dialog and rebuild on OK.
        % Build the availableActions struct array from the registry
        regForDlg = struct('id', {tbActions.id}, ...
                           'label', {tbActions.label}, ...
                           'tooltip', {tbActions.tooltip});

        newCfg = bosonPlotter.toolbarConfig(appData.toolbarConfig, regForDlg);

        if ~isempty(newCfg)
            appData.toolbarConfig = newCfg;
            saveToolbarConfig(newCfg);
            buildToolbar(axToolbarGL, newCfg, tbActions, BTN_TOOL);
        end
    end

    % ── Optional toolbar action stubs ─────────────────────────────────────

    function onZoomInToolbar()
    %ONZOOMINTOOLBAR  Zoom in by shrinking axis limits to the current view ±10%.
        try
            xl = xlim(ax);  yl = ylim(ax);
            xMid = mean(xl);  xHalf = diff(xl) * 0.4;
            yMid = mean(yl);  yHalf = diff(yl) * 0.4;
            xlim(ax, [xMid - xHalf, xMid + xHalf]);
            ylim(ax, [yMid - yHalf, yMid + yHalf]);
        catch
        end
    end

    function onZoomOutToolbar()
    %ONZOOMOUTTOOLBAR  Zoom out by expanding axis limits by 25%.
        try
            xl = xlim(ax);  yl = ylim(ax);
            xMid = mean(xl);  xHalf = diff(xl) * 0.625;
            yMid = mean(yl);  yHalf = diff(yl) * 0.625;
            xlim(ax, [xMid - xHalf, xMid + xHalf]);
            ylim(ax, [yMid - yHalf, yMid + yHalf]);
        catch
        end
    end

    function onPanToolbar()
    %ONPANTOOLBAR  Toggle pan mode on the axes.
        try
            panObj = pan(fig);
            if strcmp(panObj.Enable, 'on')
                panObj.Enable = 'off';
            else
                panObj.Enable = 'on';
            end
        catch
        end
    end

    function onThemeChanged(~,~)
    %ONTHEMECHANGED  Delegate to extracted +bosonPlotter module.
        otcCb_.onPlot = @() onPlot([],[]);
        bosonPlotter.onThemeChanged(appData, fig, ax, otcCb_);
    end

    % ── Corrections callbacks ─────────────────────────────────────────────

    function onApplyCorrectionsAll(~,~)
    %ONAPPLYCORRECTIONSALL  Delegate — see +bosonPlotter/applyCorrectionsAll.m.
        cb.setStatus = @setStatus;
        cb.onPlot    = @() onPlot([],[]);
        bosonPlotter.applyCorrectionsAll(appData, fig, ui, cb);
    end

    function onApplyCorrections(~,~)
    %ONAPPLYCORRECTIONS  Delegate to extracted +bosonPlotter module.
        bosonPlotter.onApplyCorrections(appData, ui, corrCb_);
    end

    function markCorrectionsDirty()
    %MARKCORRECTIONSDIRTY  Visually indicate that correction fields have
    %  changed and the plot may be stale.  If live-preview is enabled (#2),
    %  immediately apply corrections and redraw instead.  If auto-recalc is
    %  enabled, schedule a debounced recalculation instead.
        if cbLivePreview.Value
            onApplyCorrections([], []);
            return;
        end
        scheduleAutoRecalc();
        if isvalid(btnApply)
            btnApply.Text      = 'Apply  *';
            btnApply.FontColor = [1 0.85 0.2];
        end
    end

    function scheduleAutoRecalc()
    %SCHEDULEAUTORECALC  Debounced auto-recalculate trigger.
    %   If the Auto checkbox is off, returns immediately.  Otherwise stops
    %   any pending timer and starts a new 0.3 s single-shot timer whose
    %   callback fires onApplyCorrections.  Rapid successive changes restart
    %   the delay, so recalculation happens once the user pauses.
        if ~isvalid(cbAutoRecalc) || ~cbAutoRecalc.Value
            return;
        end
        % Stop and discard any pending timer
        if ~isempty(appData.autoRecalcTimer) && isvalid(appData.autoRecalcTimer)
            stop(appData.autoRecalcTimer);
            delete(appData.autoRecalcTimer);
        end
        appData.autoRecalcTimer = timer( ...
            'ExecutionMode', 'singleShot', ...
            'StartDelay',    0.3, ...
            'TimerFcn',      @(~,~) onAutoRecalcFire());
        start(appData.autoRecalcTimer);
    end

    function onAutoRecalcFire()
    %ONAUTORECALCFIRE  Timer callback for debounced auto-recalculate.
    %   Runs on the timer thread — schedules onApplyCorrections on the
    %   main MATLAB event queue via drawnow so UI writes are safe.
        if isvalid(fig) && ~isempty(appData.datasets) && appData.activeIdx >= 1
            onApplyCorrections([], []);
        end
    end

    function updateApplyButtonStyle()
    %UPDATEAPPLYBUTTONSTYLE  Style the Apply button based on Live Preview / Auto state.
    %   When Live Preview or Auto is ON, Apply is redundant — show it as muted.
    %   When both are OFF, highlight it as the primary action the user needs to click.
        if ~isvalid(btnApply), return; end
        autoActive = isvalid(cbAutoRecalc) && cbAutoRecalc.Value;
        if cbLivePreview.Value || autoActive
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

    function out = historyAPI(action, idx, path)
    %HISTORYAPI  Dispatcher for api.getHistory/exportHistory/formatHistory (W3 #15).
        ds_ = appData.datasets{idx};
        switch action
            case 'get',    out = ds_.history;
            case 'format', out = bosonPlotter.formatHistory(ds_);
            case 'export', bosonPlotter.exportHistoryScript(ds_, path); out = [];
        end
    end

    % ── Recent files helpers ─────────────────────────────────────────────

    function saveRecentFiles()
    %SAVERECENTFILES  Persist the recent file list to prefdir.
        try
            recentFiles = appData.recentFiles; %#ok<NASGU>
            save(recentFilePath, 'recentFiles');
        catch
            % Ignore save errors (read-only prefdir, etc.)
        end
    end

    function addToRecentFiles(fp)
    %ADDTORECENTFILES  Add a file path to recent files (deduplicated, capped at 10).
        fp = char(fp);
        appData.recentFiles(strcmp(appData.recentFiles, fp)) = [];
        appData.recentFiles = [{fp}, appData.recentFiles];
        if numel(appData.recentFiles) > 10
            appData.recentFiles = appData.recentFiles(1:10);
        end
        saveRecentFiles();
        updateRecentDropdown();
    end

    function updateRecentDropdown()
    %UPDATERECENTDROPDOWN  Refresh the Recent dropdown from appData.recentFiles.
        if isempty(appData.recentFiles)
            ddRecent.Items = {'(recent)'};
            ddRecent.Value = '(recent)';
        else
            shortNames = cell(size(appData.recentFiles));
            for ri = 1:numel(appData.recentFiles)
                [~, fn, fe] = fileparts(appData.recentFiles{ri});
                shortNames{ri} = [fn fe];
            end
            ddRecent.Items     = shortNames;
            ddRecent.ItemsData = appData.recentFiles;
            ddRecent.Value     = appData.recentFiles{1};
        end
    end

    function onRecentFileSelected(~, evt)
    %ONRECENTFILESELECTED  Load a file chosen from the Recent dropdown.
        fp = evt.Value;
        if ischar(fp) && strcmp(fp, '(recent)'), return; end
        if ~isfile(fp)
            uialert(fig, sprintf('File not found:\n%s', fp), ...
                'File Missing', 'Icon', 'warning');
            % Remove stale entry
            appData.recentFiles(strcmp(appData.recentFiles, fp)) = [];
            saveRecentFiles();
            updateRecentDropdown();
            return;
        end
        loadFilePaths({fp});
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
    %ONRESETCORRECTIONS  Delegate — see +bosonPlotter/resetCorrections.m.
        cb.cancelInteractions = @cancelInteractions;
        cb.refreshPeakTable   = peakCb.refreshPeakTable;
        cb.onPlot             = @() onPlot([],[]);
        bosonPlotter.resetCorrections(appData, fig, ui, cb);
    end

    function onUndoCorrections(~,~)
    %ONUNDOCORRECTIONS  Delegate — see +bosonPlotter/undoCorrections.m.
        cb.onPlot = @() onPlot([],[]);
        bosonPlotter.undoCorrections(appData, fig, ui, cb);
    end

    % ════════════════════════════════════════════════════════════════════
    %  UNDO / REDO (UndoManager-based)
    % ════════════════════════════════════════════════════════════════════

    function pushUndoCorrectionEntry(dsIdx, prevState, newState, labelStr)
    %PUSHUNDOCORRECTIONENTRY  Push a correction undo entry for dataset dsIdx.
    %
    %   prevState / newState are structs capturing the full correction state
    %   of the dataset before and after the operation.
        appData.undoMgr.push(struct( ...
            'type',  'correction', ...
            'label', labelStr, ...
            'undo',  @() bosonPlotter.restoreCorrectionState(appData, ui, dsIdx, prevState), ...
            'redo',  @() bosonPlotter.restoreCorrectionState(appData, ui, dsIdx, newState)));
        appData.undoCb.updateUndoButtons();
    end

function onLoadBackground(~,~)
    %ONLOADBACKGROUND  Open file dialog and load a background dataset via importAuto.
        startDir = resolveStartDir(appData.lastDir);
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
        bosonPlotter.softUpdateLines(appData, struct('onPlot', @onPlot));
    end

    function onSmoothingChanged(~,~)
    %ONSMOOTHINGCHANGED  Re-apply corrections whenever smoothing controls change.
    %   Also refreshes the smooth preview overlay when it is active.
        if ~isempty(appData.datasets) && appData.activeIdx >= 1
            if isvalid(cbSmoothPreview) && cbSmoothPreview.Value
                updateSmoothPreview();
            else
                onApplyCorrections([],[]);
            end
        end
    end

    function onSmoothPreviewToggled(~,~)
    %ONSMOOTHPREVIEWTOGGLED  Show or remove the smoothing live preview overlay.
    %   When checked: compute smoothed Y on the active dataset and draw a dashed
    %   line on the axes without modifying any dataset.  When unchecked: delete
    %   the overlay line.
        clearSmoothPreview();
        if cbSmoothPreview.Value
            updateSmoothPreview();
        end
    end

    function updateSmoothPreview()
    %UPDATESMOOTHPREVIEW  Delegate to extracted +bosonPlotter module.
        bosonPlotter.updateSmoothPreview(appData, ui, ax);
    end

    function clearSmoothPreview()
    %CLEARSMOOTHPREVIEW  Delete the smooth preview overlay line if it exists.
        if isgraphics(appData.smoothPreviewLine)
            delete(appData.smoothPreviewLine);
        end
        appData.smoothPreviewLine = [];
    end

    function onBaselineMethodChanged(~,~)
    %ONBASELINEMETHODCHANGED  Show/hide ALS lambda and Rolling Ball radius spinners.
        meth = ddBaselineMethod.Value;
        switch meth
            case 'ALS'
                corrGL.RowHeight{CROW.BASELINE_PARAMS} = 22;
                lblBaselineLambda.Visible = 'on';
                efBaselineLambda.Visible  = 'on';
                lblBaselineRadius.Visible = 'off';
                efBaselineRadius.Visible  = 'off';
            case 'Rolling Ball'
                corrGL.RowHeight{CROW.BASELINE_PARAMS} = 22;
                lblBaselineLambda.Visible = 'off';
                efBaselineLambda.Visible  = 'off';
                lblBaselineRadius.Visible = 'on';
                efBaselineRadius.Visible  = 'on';
            otherwise  % 'SNIP', 'Mod. Polynomial' — no extra params
                corrGL.RowHeight{CROW.BASELINE_PARAMS} = 0;
        end
    end

    function onToggleWatchFile()
    %ONTOGGLEWATCHFILE  Start or stop live file watching on the active dataset.
    %   Creates a scripts.dataConnector that polls the source file and calls
    %   onFileChanged when a modification is detected.  The connector is stored
    %   in appData.dataConnectors{activeIdx}.  A second toggle stops and clears
    %   the watcher for that slot.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'Watch File');
            return;
        end

        idx = appData.activeIdx;
        ds  = appData.datasets{idx};

        % Ensure connector cell is large enough
        while numel(appData.dataConnectors) < idx
            appData.dataConnectors{end+1} = [];
        end

        existing = appData.dataConnectors{idx};
        if ~isempty(existing) && isstruct(existing) && existing.isRunning()
            % Already watching — stop it
            existing.stop();
            appData.dataConnectors{idx} = [];
            setStatus(sprintf('File watch stopped for: %s', ds.filepath));
            return;
        end

        if ~isfile(ds.filepath)
            uialert(fig, sprintf('Cannot watch: file not found.\n%s', ds.filepath), 'Watch File');
            return;
        end

        connector = scripts.dataConnector(ds.filepath, ...
            Callback=@(newData) onFileChanged(idx, newData));
        appData.dataConnectors{idx} = connector;
        setStatus(sprintf('Watching: %s', ds.filepath));
    end

    function onFileChanged(dsIdx, newData)
    %ONFILECHANGED  Called by dataConnector when the watched file changes.
    %   Replaces the dataset's raw data, clears corrData, and replots.
        if dsIdx < 1 || dsIdx > numel(appData.datasets), return; end
        ds = appData.datasets{dsIdx};
        ds.data     = newData;
        ds.corrData = [];  % stale corrections discarded — user must re-apply
        appData.datasets{dsIdx} = ds;
        try
            appData.model.updateDataset(dsIdx, ds);
        catch
        end
        rebuildDatasetList(false);
        if appData.activeIdx == dsIdx
            onPlot([], []);
        end
        setStatus(sprintf('Reloaded: %s', ds.filepath));
    end

    % ── Annotation tool ───────────────────────────────────────────────────

    function onAnnotationModeChanged(~,~)
    %ONANNOTATIONMODECHANGED  Toggle annotation mode on/off.
    %   When enabled, single-click on the plot adds annotations.
    %   Right-click on an annotation deletes it.
        if cbAnnotationMode.Value
            % Enable annotation mode
            appData.annotationMode = 'crosshair';
            fig.WindowButtonDownFcn = @onAnnotationClick;
            fig.Pointer = 'crosshair';
        else
            % Disable annotation mode
            appData.annotationMode = 'none';
            fig.WindowButtonDownFcn = @onAxesButtonDown;
            fig.Pointer = 'arrow';
        end
    end

    function onAnnotationClick(~,~)
    %ONANNOTATIONCLICK  Delegate to extracted +bosonPlotter module.
        oacCb_.onPlot = @() onPlot([],[]);
        bosonPlotter.onAnnotationClick(appData, fig, ax, oacCb_);
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
    %ONBGMOUSEUP  Delegate — see +bosonPlotter/onBGMouseUp.m for implementation.
        fig.WindowButtonDownFcn   = @onAxesButtonDown;
        fig.WindowButtonMotionFcn = @onMouseHover;
        fig.WindowButtonUpFcn     = '';
        btnFitBG.Text            = 'Fit Linear BG from Box';
        btnFitBG.BackgroundColor = BTN_INTERACT;
        btnPickY.Enable          = 'on';
        btnFitBG.Enable          = 'on';
        bgWgts.lbY            = lbY;
        bgWgts.ddBGOrder      = ddBGOrder;
        bgWgts.lblRegionStats = lblRegionStats;
        [ds, bgOrder, p] = bosonPlotter.onBGMouseUp(ax, appData, fig, bgWgts);
        appData.bgRectPatch = [];
        appData.bgStartPt   = [];
        if isempty(ds), return; end
        if bgOrder == 1
            efBGSlope.Value     = p(1);
            efBGIntercept.Value = p(2);
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
    %APPLYMASKINBOX  Delegate to extracted +bosonPlotter module.
        bosonPlotter.applyMaskInBox(appData, ui, xMin, xMax, yMin, yMax, ...
            struct('setStatus', @setStatus, 'onPlot', @() onPlot([],[])));
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
    %ONYORIGINCLICK  Delegate — see +bosonPlotter/yOriginClick.m.
        cb.onAxesButtonDown   = @onAxesButtonDown;
        cb.onApplyCorrections = @onApplyCorrections;
        bosonPlotter.yOriginClick(appData, fig, ax, ui, cb);
    end

    % ── Save callbacks ────────────────────────────────────────────────────

    function onSaveBrowse(~,~)
        [fname, fpath] = uiputfile({'*.csv','CSV files (*.csv)'}, ...
            'Save corrected data as...');
        if isequal(fname,0), return; end
        efSavePath.Value = fullfile(fpath,fname);
    end

    function openLinkedDataWorkspace()
    %OPENLINKEDDATAWORKSPACE  Open the shared DataWorkspace (single instance).
    %   Left-click behaviour: bring existing window to front if open,
    %   otherwise create a new one and store its figure handle.
        if ~isempty(linkedDW) && isvalid(linkedDW)
            figure(linkedDW);   % bring to front
            return;
        end
        dwApi  = DataWorkspace(Model=appData.model, Visible='on');
        linkedDW = dwApi.fig;
    end

    function onSpreadsheetEdit(dsIdx, rowIdx, colIdx, newValue)
    %ONSPREADSHEEDEDIT  Update the dataset working copy when a cell is edited.
        if dsIdx < 1 || dsIdx > numel(appData.datasets), return; end
        ds = appData.datasets{dsIdx};
        % Edits target corrData if it exists, otherwise raw data
        % col 1 = X axis; col 2+ = values columns
        if colIdx == 1
            % X-axis edit: apply to time vector
            if ~isempty(ds.corrData)
                if rowIdx <= numel(ds.corrData.time)
                    ds.corrData.time(rowIdx) = newValue;
                end
            else
                if rowIdx <= numel(ds.data.time)
                    ds.data.time(rowIdx) = newValue;
                    ds.corrData = [];   % invalidate corrected cache
                end
            end
        else
            valCol = colIdx - 1;
            if ~isempty(ds.corrData)
                if rowIdx <= size(ds.corrData.values, 1) && valCol <= size(ds.corrData.values, 2)
                    ds.corrData.values(rowIdx, valCol) = newValue;
                end
            else
                if rowIdx <= size(ds.data.values, 1) && valCol <= size(ds.data.values, 2)
                    ds.data.values(rowIdx, valCol) = newValue;
                    ds.corrData = [];   % invalidate corrected cache
                end
            end
        end
        appData.datasets{dsIdx} = ds;
    end

    function onSaveCSV(~,~)
    %ONSAVECSV  Delegate — see +bosonPlotter/onSaveCSV.m.
        oscsvCb_.resolvedExportFormat    = @resolvedExportFormat;
        oscsvCb_.findPolarizationPairs   = @findPolarizationPairs;
        oscsvCb_.recordAction            = @recordAction;
        oscsvCb_.logGUIError             = @logGUIError;
        oscsvCb_.guiSaveCSV              = @guiSaveCSV;
        bosonPlotter.onSaveCSV(appData, fig, ui, oscsvCb_);
    end

    function fmt = resolvedExportFormat()
    %RESOLVEDEXPORTFORMAT  Map dropdown value to format string.
        if strcmp(ddExportFormat.Value, 'Origin ASCII')
            fmt = 'origin';
        else
            fmt = 'standard';
        end
    end

    function saveConsolidatedNeutronCSV(activeDs, fp, fmt)
    %SAVECONSOLIDATEDNEUTRONCSV  Delegates to bosonPlotter.saveConsolidatedNeutronCSV.
        bosonPlotter.saveConsolidatedNeutronCSV(activeDs, fp, fmt, appData.datasets);
    end

    function onBatchExportCSV(~,~)
    %ONBATCHEXPORTCSV  Delegate — see +bosonPlotter/onBatchExportCSV.m.
        obeCb_.setStatus              = @setStatus;
        obeCb_.resolvedExportFormat   = @resolvedExportFormat;
        obeCb_.guiSaveCSV             = @guiSaveCSV;
        bosonPlotter.onBatchExportCSV(appData, fig, obeCb_);
    end

    function onCopyDataToClipboard(~,~)
    %ONCOPYDATATOCLIPBOARD  Delegate to extracted +bosonPlotter module.
        ocdcCb_.logGUIError = @logGUIError;
        bosonPlotter.onCopyDataToClipboard(appData, fig, ocdcCb_);
    end

function onSendToOrigin(~,~)
    %ONSENDTOORIGIN  Send active dataset to OriginPro via COM; fall back to clipboard.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data');
            return;
        end
        ds  = appData.datasets{appData.activeIdx};
        src = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        src = bosonPlotter.applyDisplayUnits(src, ds, appData);
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
            clipStr = bosonPlotter.buildClipboardString(appData, appData.activeIdx);
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
            fprintf(2, '\n[BosonPlotter] HDF5 export error: %s\n', ME.message);
            for si = 1:numel(ME.stack)
                fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
            end
            logGUIError('Export error', ME.message, ME);
            uialert(fig, ME.message, 'Export error');
        end
    end

    % ── Plot callbacks ────────────────────────────────────────────────────


    function onPlot(~,~)
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        % Fix B1: collapse Y2 listbox row when no right-axis channel is selected
        y2IsActive = ~all(strcmp(ensureCell(lbY2.Value), '(none)'));
        ctrlGL.RowHeight{3} = guiTernary(y2IsActive, '1x', 0);
        drawToAxes(ax);
        % Re-apply grid and axis-direction from the active dataset's plot
        % state — these are axes properties (not dropdowns) and would
        % otherwise be overwritten by the render's style pass.
        applyAxesPlotState();
    end

    function applyAxesPlotState()
    %APPLYAXESPLOTSTATE  Post-plot pass: restore per-dataset grid/XDir/
    %  YDir, and the completed-box integration marker (renderPlot wipes
    %  all axes children, so overlays that should persist must be
    %  re-created here).
        if isempty(ax) || ~isvalid(ax), return; end
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        if isfield(ds, 'plotState') && isstruct(ds.plotState)
            ps = ds.plotState;
            if isfield(ps, 'gridX') && ~isempty(ps.gridX)
                ax.XGrid = ps.gridX;
            end
            if isfield(ps, 'gridY') && ~isempty(ps.gridY)
                ax.YGrid = ps.gridY;
            end
            if isfield(ps, 'xDir') && ~isempty(ps.xDir)
                ax.XDir = ps.xDir;
            end
            if isfield(ps, 'yDir') && ~isempty(ps.yDir)
                ax.YDir = ps.yDir;
            end
        end
        redrawCompletedBoxPatch();
    end

    function onAdvAsymmetry(~, ~)
    %ONADVASYMMETRY  Toggle spin asymmetry from the Advanced Analysis popup.
    %   Presents a dialog to configure asymmetry formula before toggling.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a neutron dataset first.', 'Spin Asymmetry');
            return;
        end
        ds = appData.datasets{appData.activeIdx};
        if ~isfield(ds, 'parserName') || ~isNeutronParser(ds.parserName)
            uialert(fig, 'Active dataset is not neutron data. Load NCNR .refl/.datA files.', 'Spin Asymmetry');
            return;
        end
        if cbCalculateAsymmetry.Value
            % Currently on — offer to turn off
            choice = uiconfirm(fig, 'Spin asymmetry is currently ON. Turn off?', ...
                'Spin Asymmetry', 'Options', {'Turn Off', 'Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 2);
            if strcmp(choice, 'Turn Off')
                cbCalculateAsymmetry.Value = false;
                onAsymmetryToggle([], []);
            end
        else
            % Currently off — let user pick formula then enable
            choice = uiconfirm(fig, 'Calculate spin asymmetry?', ...
                'Spin Asymmetry', ...
                'Options', {'Linear: (R++ - R--) / (R++ + R--)', 'Log: log(R++ / R--)', 'Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 3);
            if strcmp(choice, 'Cancel'), return; end
            if contains(choice, 'Log')
                ddAsymFormula.Value = ddAsymFormula.Items{2};
            else
                ddAsymFormula.Value = ddAsymFormula.Items{1};
            end
            cbCalculateAsymmetry.Value = true;
            onAsymmetryToggle([], []);
        end
        recordAction(sprintf('%% Spin asymmetry: %s', mat2str(cbCalculateAsymmetry.Value)));
    end

    function onAsymmetryToggle(~,~)
    %ONASYMMETRYTOGGLE  Delegate to extracted +bosonPlotter module.
        bosonPlotter.onAsymmetryToggle(appData, ui, ...
            struct('onPlot', @() onPlot([],[])));
    end

    function drawToAxes(targetAx)
    %DRAWTOAXES  Render SELECTED datasets into targetAx.
    %   Delegates to bosonPlotter.renderPlot after building a context struct
    %   from the current widget state.  Original ~1,021-line body extracted
    %   to +bosonPlotter/renderPlot.m for maintainability.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end

        % ── Resolve plot selection from listbox ──────────────────────────
        rawSel = lbDatasets.Value;
        if ~iscell(rawSel), rawSel = {rawSel}; end
        plotIdx = cell2mat(rawSel);
        plotIdx = plotIdx(plotIdx >= 1 & plotIdx <= numel(appData.datasets));
        if ~ismember(appData.activeIdx, plotIdx)
            plotIdx = sort([plotIdx, appData.activeIdx]);
        end
        % ── Resolve waterfall spacing (needs widget values + appData) ────
        activeDs = appData.datasets{appData.activeIdx};
        xSel   = ddX.Value;
        xName  = guiXName(activeDs.data.metadata);
        xUnit  = guiXUnit(activeDs.data.metadata);
        xLabel = guiLabel(xName, xUnit);

        % ── Resolve waterfall spacing ────────────────────────────────────
        waterfallOn = cbWaterfall.Value;
        if waterfallOn
            rawSp = efWaterfallSpacing.Value;  % numeric field: [] or double
            if isempty(rawSp) || rawSp <= 0
                effectiveSpacing = computeAutoWaterfallSpacing();
            else
                effectiveSpacing = rawSp;
            end
        else
            effectiveSpacing = 0;
        end

        % ── Build context struct for renderPlot ──────────────────────────
        rCtx_.appData           = appData;
        rCtx_.plotIdx            = plotIdx;
        rCtx_.xSel               = xSel;
        rCtx_.xName              = xName;
        rCtx_.xUnit              = xUnit;
        rCtx_.xLabel             = xLabel;
        rCtx_.ySel               = ensureCell(lbY.Value);
        rCtx_.y2Sel              = ensureCell(lbY2.Value);
        rCtx_.y2Sel              = rCtx_.y2Sel(~strcmp(rCtx_.y2Sel, '(none)'));
        rCtx_.colormapName       = ddColormap.Value;
        rCtx_.useWfGradient      = cbWaterfall.Value && appData.wfGradient && numel(plotIdx) > 1;
        rCtx_.waterfallOn        = waterfallOn;
        rCtx_.effectiveSpacing   = effectiveSpacing;
        rCtx_.scaleX             = ddScaleX.Value;
        rCtx_.scaleY             = ddScaleY.Value;
        rCtx_.scaleY2            = ddScaleY2.Value;
        rCtx_.showLegend         = ~strcmp(ddLegendLoc.Value, 'off');
        rCtx_.showRaw            = cbShowRaw.Value;
        rCtx_.countsPerSec       = cbCountsPerSec.Value;
        rCtx_.style              = appData.style;

        % ── Resolve visual appearance (Phase A) ──────────────────────────
        % Merge the active template + global dialog overrides via
        % bosonPlotter.resolveStyle; per-dataset / per-channel overrides
        % are applied inside renderPlot when it iterates the loop.
        rCtx_.appearance = resolveActiveAppearance();

        rCtx_.ddMap2DType        = ddMap2DType.Value;
        rCtx_.calculateAsymmetry = cbCalculateAsymmetry.Value;
        rCtx_.asymFormula        = ddAsymFormula.Value;
        rCtx_.xMin               = efXMin.Value;
        rCtx_.xMax               = efXMax.Value;
        rCtx_.xStep              = efXStep.Value;
        rCtx_.yMin               = efYMin.Value;
        rCtx_.yMax               = efYMax.Value;
        rCtx_.yStep              = efYStep.Value;
        rCtx_.y2Min              = efY2Min.Value;
        rCtx_.y2Max              = efY2Max.Value;
        rCtx_.y2Step             = efY2Step.Value;
        rCtx_.xFmt               = ddXFmt.Value;
        rCtx_.yFmt               = ddYFmt.Value;
        rCtx_.y2Fmt              = ddY2Fmt.Value;
        rCtx_.customXLabel       = efCustomXLabel.Value;
        rCtx_.customYLabel       = efCustomYLabel.Value;
        rCtx_.customY2Label      = efCustomY2Label.Value;
        rCtx_.customTitle        = efCustomTitle.Value;
        rCtx_.isMainAx           = (targetAx == ax);
        % Merge static fields (widget handles + function handles, allocated once)
        sf = fieldnames(rCtxStatic_);
        for sfi = 1:numel(sf)
            rCtx_.(sf{sfi}) = rCtxStatic_.(sf{sfi});
        end

        bosonPlotter.renderPlot(targetAx, rCtx_);

        % ── Wire double-click / context menus on plot objects ──────────────
        % Only for the main axes; export/thumbnail axes get no interactions.
        if rCtx_.isMainAx
            try
                piCb_.getDatasets    = @() appData.datasets;
                piCb_.getActiveIdx   = @() appData.activeIdx;
                piCb_.setActiveIdx   = @setActiveIdxDirect;
                piCb_.setCustomXLabel = @(s) setIfChanged(efCustomXLabel, s);
                piCb_.setCustomYLabel = @(s) setIfChanged(efCustomYLabel, s);
                piCb_.setCustomTitle  = @(s) setIfChanged(efCustomTitle,  s);
                piCb_.onAutoLimits    = @() onAutoLimits([],[]);
                piCb_.isContextMenuSupported = cmSupported_;
                bosonPlotter.plotInteractions(targetAx, fig, piCb_);
            catch piME
                logGUIError('plotInteractions', piME.message, piME);
            end
        end
    end

    function setIfChanged(ef, newVal)
    %SETIFCHANGED  Update a text edit field and trigger replot when changed.
    %   Programmatic .Value assignment does NOT fire ValueChangedFcn in
    %   uifigures, so onPlot must be invoked explicitly after the update.
        if ~isequal(ef.Value, newVal)
            ef.Value = newVal;
            onPlot([],[]);
        end
    end


    function appearance = resolveActiveAppearance()
    %RESOLVEACTIVEAPPEARANCE  Build the effective visual style struct.
    %   Layers: styles.template(name) → appData.styleOverrides.  Per-
    %   dataset / per-channel layers are applied inside renderPlot where
    %   each dataset is iterated.  User templates are recognised by the
    %   'user:' prefix and loaded via bosonPlotter.userTemplates.load.
        try
            tname = appData.activeTemplate;
            if isempty(tname), tname = 'screen'; end
            if startsWith(tname, 'user:')
                tpl = bosonPlotter.userTemplates.load(tname(6:end));
            else
                tpl = styles.template(tname);
            end
        catch
            tpl = styles.template('screen');
        end

        % Colormap dropdown overrides template palette when the user has
        % explicitly picked one (anything other than the 'lines' default
        % means they made a choice — template palette takes the back seat)
        try
            cmapName = ddColormap.Value;
            if ~strcmp(cmapName, 'lines (MATLAB default)')
                n = max(6, size(tpl.colors, 1));
                tpl.colors = getColorsFromMap(cmapName, n);
            end
        catch ME
            logGUIError('Colormap resolution', ME.message, ME);
        end

        appearance = bosonPlotter.resolveStyle(tpl, appData.styleOverrides);
    end


    function onToggleSinglePrecision()
    %ONTOGGLESINGLEPREC  Convert 2D intensity matrix between single/double.
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        if ~is2DDataset(ds), return; end
        map = ds.data.metadata.parserSpecific.map2D;
        if cbMap2DSingle.Value
            map.intensity = single(map.intensity);
            if isfield(map, 'Qx'), map.Qx = single(map.Qx); end
            if isfield(map, 'Qz'), map.Qz = single(map.Qz); end
        else
            map.intensity = double(map.intensity);
            if isfield(map, 'Qx'), map.Qx = double(map.Qx); end
            if isfield(map, 'Qz'), map.Qz = double(map.Qz); end
        end
        ds.data.metadata.parserSpecific.map2D = map;
        appData.datasets{appData.activeIdx} = ds;
        setStatus(sprintf('2D matrix now %s (%.1f MB)', ...
            class(map.intensity), numel(map.intensity) * bytesPerElem(map.intensity) / 1e6));
    end

    function onClear2DMatrix()
    %ONCLEAR2DMATRIX  Discard the 2D intensity matrix to reclaim memory.
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        if ~is2DDataset(ds), return; end
        map = ds.data.metadata.parserSpecific.map2D;
        savedMB = numel(map.intensity) * bytesPerElem(map.intensity) / 1e6;
        if isfield(map, 'Qx'), savedMB = savedMB + 2 * numel(map.Qx) * bytesPerElem(map.Qx) / 1e6; end
        map.intensity = [];
        if isfield(map, 'Qx'), map.Qx = []; map.Qz = []; end
        ds.data.metadata.parserSpecific.map2D = map;
        appData.datasets{appData.activeIdx} = ds;
        appData.map2DHandle = [];
        setStatus(sprintf('Cleared 2D matrix — freed ~%.1f MB', savedMB));
    end

    function onFitSurface(~,~)
    %ONFITSURFACE  Open the 2D surface fitting dialog for the active map dataset.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds = appData.datasets{appData.activeIdx};
        if ~is2DDataset(ds)
            uialert(fig, 'Active dataset is not a 2D area-detector map.', 'Fit Surface');
            return;
        end
        map = ds.data.metadata.parserSpecific.map2D;
        mapData.intensity = map.intensity;
        mapData.axis1     = map.axis1;
        mapData.axis2     = map.axis2;
        bosonPlotter.surfaceFitDialog(mapData, ...
            Title="Surface Fit — " + ds.name, ...
            Appearance=resolveActiveAppearance());
    end

    function onDecomposeRSM(~,~)
    %ONDECOMPOSERSM  Open the RSM peak-decomposition dialog for the active map.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds = appData.datasets{appData.activeIdx};
        if ~is2DDataset(ds)
            uialert(fig, 'Active dataset is not a 2D area-detector map.', 'Decompose RSM');
            return;
        end
        map = ds.data.metadata.parserSpecific.map2D;
        bosonPlotter.rsmDecomposeDialog(map, ...
            Title       = "Decompose RSM — " + ds.name, ...
            OverlayAxes = ax);
    end

    function onPoleFigure(~,~)
    %ONPOLEFIGURE  Delegate to extracted +bosonPlotter module.
        opfCb_.is2DDataset = @is2DDataset;
        bosonPlotter.onPoleFigure(appData, fig, opfCb_);
    end

    function draw2DMap(targetAx, ds)
    %DRAW2DMAP  Delegate — see +bosonPlotter/draw2DMap.m for implementation.
        wgts.cbMap2DQSpace   = cbMap2DQSpace;
        wgts.ddMap2DScale    = ddMap2DScale;
        wgts.ddMap2DCmap     = ddMap2DCmap;
        wgts.ddMap2DType     = ddMap2DType;
        wgts.efMap2DContourN = efMap2DContourN;
        wgts.efMap2DCMin     = efMap2DCMin;
        wgts.efMap2DCMax     = efMap2DCMax;
        wgts.appearance      = resolveActiveAppearance();
        appData.map2DHandle  = bosonPlotter.draw2DMap(targetAx, ds, appData.map2DHandle, wgts);
    end

    function extract2DLineCut(clickX, clickY, isHorizontal)
    %EXTRACT2DLINECUT  Delegate — see +bosonPlotter/extract2DLineCut.m.
        e2lcCb_.buildDs                        = @buildDs;
        e2lcCb_.rebuildDatasetList             = @rebuildDatasetList;
        e2lcCb_.updateControlsForActiveDataset = @updateControlsForActiveDataset;
        bosonPlotter.extract2DLineCut(appData, ui, e2lcCb_, clickX, clickY, isHorizontal);
    end

    function extract2DBoxIntegral(bx0, by0, bx1, by1, profileAxis)
    %EXTRACT2DBOXINTEGRAL  Delegate — see +bosonPlotter/extract2DBoxIntegral.m.
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        if ~is2DDataset(ds), return; end
        if nargin < 5, profileAxis = []; end
        wgts2.cbMap2DQSpace = cbMap2DQSpace;
        wgts2.efBoxIntW     = efBoxIntW;
        wgts2.efBoxIntH     = efBoxIntH;
        wgts2.buildDs       = @buildDs;
        [newDs, cutLabel] = bosonPlotter.extract2DBoxIntegral( ...
            ds, bx0, by0, bx1, by1, profileAxis, fig, wgts2);
        if isempty(newDs), return; end
        appData.datasets{end+1} = newDs;
        try
            appData.model.addDataset(newDs.data, newDs.filepath, newDs.parserName);
        catch
        end
        rebuildDatasetList(numel(appData.datasets));
        updateControlsForActiveDataset();
        if hasFixedBoxSize()
            btnBoxIntegrate.Text = [char(9654) ' Integrate Box'];
        else
            btnBoxIntegrate.Text = 'Box Integrate...';
        end
        btnBoxIntegrate.BackgroundColor = [0.20 0.50 0.35];
        setStatus(sprintf('Box integral: %s', cutLabel));
    end

    function onArcIntButton(~,~)
    %ONARCINTBUTTON  Delegate to extracted +bosonPlotter module.
        oaibCb_.is2DDataset          = @is2DDataset;
        oaibCb_.extract2DArcIntegral = @extract2DArcIntegral;
        bosonPlotter.onArcIntButton(appData, fig, oaibCb_);
    end

    function extract2DArcIntegral(params)
    %EXTRACT2DARCINTEGRAL  Delegate — see +bosonPlotter/extract2DArcIntegral.m.
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        if ~is2DDataset(ds), return; end
        [newDs, ~] = bosonPlotter.extract2DArcIntegral(ds, params, fig, @buildDs);
        if isempty(newDs), return; end
        appData.datasets{end+1} = newDs;
        rebuildDatasetList(numel(appData.datasets));
        updateControlsForActiveDataset();
    end

    function onSmartScale(~,~)
    %ONSMARTSCALE  Delegate — see +bosonPlotter/onSmartScale.m.
        ossCb_.saveAxisLimsToActiveDataset = @saveAxisLimsToActiveDataset;
        ossCb_.onPlot                      = @onPlot;
        bosonPlotter.onSmartScale(appData, ui, ossCb_);
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
                stashPlotStateField('xScale', ddScaleX.Value);
                onPlot([], []);
            case 'logY'
                if strcmp(ddScaleY.Value,'Log'), ddScaleY.Value = 'Linear'; else, ddScaleY.Value = 'Log'; end
                stashPlotStateField('yScale', ddScaleY.Value);
                onPlot([], []);
            case 'grid'
                if strcmp(ax.XGrid, 'on')
                    grid(ax, 'off');
                else
                    grid(ax, 'on');
                end
                stashPlotStateField('gridX', ax.XGrid);
                stashPlotStateField('gridY', ax.YGrid);
            case 'invertX'
                if strcmp(ax.XDir, 'normal')
                    ax.XDir = 'reverse';
                else
                    ax.XDir = 'normal';
                end
                stashPlotStateField('xDir', ax.XDir);
        end
    end

    function stashPlotStateField(fieldName, value)
    %STASHPLOTSTATEFIELD  Persist a single plot-state field on the active
    %  dataset so it survives a dataset toggle. Safe to call when no
    %  dataset is active (no-op).
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        if ~isfield(appData.datasets{appData.activeIdx}, 'plotState') ...
                || ~isstruct(appData.datasets{appData.activeIdx}.plotState)
            appData.datasets{appData.activeIdx}.plotState = struct();
        end
        appData.datasets{appData.activeIdx}.plotState.(fieldName) = value;
    end

    function onToolbarLegendToggle(~,~)
    %ONTOOLBARLEGENDTOGGLE  Toggle legend on/off and replot.
    %   Also called by ddLegendLoc ValueChangedFcn when user picks a location.
        if nargin == 0 || isempty(gcbo) || gcbo ~= ddLegendLoc
            % Called from keyboard shortcut or toolbar button — toggle
            if strcmp(ddLegendLoc.Value, 'off')
                ddLegendLoc.Value = 'best';
            else
                ddLegendLoc.Value = 'off';
            end
        end
        loc = ddLegendLoc.Value;
        if ~strcmp(loc, 'off')
            appData.styleOverrides.legendLocation = loc;
        end
        onPlot([], []);
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

    % (onExportVisibleRange extracted to +bosonPlotter/onExportVisibleRange.m;
    %  wired directly at the uimenu callback site, no nested delegate needed)

    function onClearFitOverlays(~, ~)
    %ONCLEARFITOVERLAYS  Remove curve fit and peak decomposition overlays.
        delete(findall(ax, '-regexp', 'Tag', ...
            '^(curveFitOverlay|curveFitLabel|GUIPeakDecomp|integrationShade|integrationEdge)$'));
        setStatus('Fit overlays cleared');
    end

    function onCopyPlotToClipboard()
    %ONCOPYPLOTTOCLIPBOARD  Legacy entry-point kept for toolbar / context-menu
    %  bindings. Delegates to onCopyToClipboard, which produces a transparent
    %  background so the pasted image adapts to the target document's colour.
        onCopyToClipboard([], []);
    end

    function onAutoLimits(~,~)
    %ONAUTOLIMITS  Reset View — clear axis limits and per-dataset plot
    %  state so the active dataset returns to parser-aware auto defaults
    %  (log/linear, grid, axis direction, 2D map settings). Also clears
    %  any persistent box-integration marker from the map.
        efXMin.Value = '';  efXMax.Value = '';  efXStep.Value = '';
        efYMin.Value = '';  efYMax.Value = '';  efYStep.Value = '';
        efY2Min.Value = '';  efY2Max.Value = '';  efY2Step.Value = '';
        % Clear the persisted plot-state struct so parser defaults win
        % again. updateControlsForActiveDataset will re-apply those.
        if appData.activeIdx >= 1 && ~isempty(appData.datasets)
            appData.datasets{appData.activeIdx}.plotState = struct();
        end
        if ~isempty(ax) && isvalid(ax)
            ax.XGrid = 'off';
            ax.YGrid = 'off';
            ax.XDir  = 'normal';
            ax.YDir  = 'normal';
        end
        clearCompletedBoxPatch();
        saveAxisLimsToActiveDataset();
        updateControlsForActiveDataset();   % re-pull parser defaults
        onPlot([],[]);
    end

    function onClearOverlays(~,~)
    %ONCLEAROVERLAYS  Toolbar action — strip all interactive overlays
    %  (fringe markers/labels, peak annotations, masks, zoom boxes,
    %  cursor markers, smoothing preview, user annotations) from the
    %  plot and reset their appData state.  Leaves datasets untouched.
        bosonPlotter.clearOverlays(appData, ax);
        setStatus('Overlays cleared.');
    end

    function onEditAxisLabelsMenu()
    %ONEDITAXISLABELSMENU  Context-menu entry: open a dialog to edit all axis labels.
    %   Provides the same edits as double-clicking each label individually.
        prompts = {'X-Axis Label:', 'Y-Axis Label:', 'Plot Title:'};
        defaults = {efCustomXLabel.Value, efCustomYLabel.Value, efCustomTitle.Value};
        answer = inputdlg(prompts, 'Edit Axis Labels', [1 52], defaults);
        if isempty(answer), return; end
        changed = false;
        if ~isequal(efCustomXLabel.Value, answer{1})
            efCustomXLabel.Value = answer{1};  changed = true;
        end
        if ~isequal(efCustomYLabel.Value, answer{2})
            efCustomYLabel.Value = answer{2};  changed = true;
        end
        if ~isequal(efCustomTitle.Value, answer{3})
            efCustomTitle.Value  = answer{3};  changed = true;
        end
        if changed, onPlot([],[]); end
    end

    function onSetAxisLimitsMenu()
    %ONSETAXISLIMITSMENU  Context-menu entry: edit axis limits via dialog.
        prompts  = {'X Min:', 'X Max:', 'Y Min:', 'Y Max:'};
        defaults = {efXMin.Value, efXMax.Value, efYMin.Value, efYMax.Value};
        answer   = inputdlg(prompts, 'Set Axis Limits', [1 38], defaults);
        if isempty(answer), return; end
        efXMin.Value = strtrim(answer{1});
        efXMax.Value = strtrim(answer{2});
        efYMin.Value = strtrim(answer{3});
        efYMax.Value = strtrim(answer{4});
        saveAxisLimsToActiveDataset();
        onPlot([],[]);
    end

    function onSetTickSpacingMenu()
    %ONSETTICKSPACINGMENU  Edit tick spacing for X / Y / Y2 axes.
    %  Replaces the in-panel step inputs that were removed when the Axes
    %  panel was consolidated into the Controls panel. Blank = auto.
        prompts  = {'X tick spacing (blank = auto):', ...
                    'Y tick spacing (blank = auto):', ...
                    'Y2 tick spacing (blank = auto):'};
        defaults = {efXStep.Value, efYStep.Value, efY2Step.Value};
        answer   = inputdlg(prompts, 'Set Tick Spacing', [1 38], defaults);
        if isempty(answer), return; end
        efXStep.Value  = strtrim(answer{1});
        efYStep.Value  = strtrim(answer{2});
        efY2Step.Value = strtrim(answer{3});
        onPlot([],[]);
    end

    function onContextSetLegendLoc(loc)
    %ONCONTEXTSETLEGENDLOC  Set legend location from right-click submenu.
    %  Programmatic .Value writes don't fire ValueChangedFcn, so we invoke
    %  the legend-toggle callback explicitly.
        ddLegendLoc.Value = loc;
        onToolbarLegendToggle([],[]);
    end

    function onContextSetDatasetColor(colorName)
    %ONCONTEXTSETDATASETCOLOR  Set per-dataset color override from submenu.
    %  Maps the display name back to the RGB triplet stored in ItemsData,
    %  enables the dropdown (auto-disabled when no override), and fires the
    %  change callback explicitly.
        idx = find(strcmp(DS_COLOR_NAMES, colorName), 1);
        if isempty(idx), return; end
        ddDatasetColor.Value  = DS_COLOR_RGBS{idx};
        ddDatasetColor.Enable = 'on';
        onDatasetColorChanged([],[]);
    end

    function onMouseHover(~,~)
    %ONMOUSEHOVER  Update x,y readout and set resize cursor near panel borders.
    %  Fires continuously while the mouse moves over the figure in idle (non-drag) mode.

        % -- Panel resize border detection: update cursor and store hover direction --
        dir = bosonPlotter.detectResizeBorder(fig, struct( ...
            'fileListPanel',  fileListPanel, ...
            'ctrlPanel',      ctrlPanel, ...
            'corrPanel',      corrPanel, ...
            'savePanel',      savePanel, ...
            'analysisPanel',  analysisPanel, ...
            'dataTablePanel', dataTablePanel));
        appData.panelResizeDir = dir;
        if     strcmp(dir, 'h_row12'), fig.Pointer = 'top';
        elseif any(strcmp(dir, {'v_col12', 'v_col23', 'v_content12', 'v_content23'}))
                                                          fig.Pointer = 'left';
        else,                                             fig.Pointer = 'arrow';
        end

        % -- x,y readout in top-right of axes --
        if isempty(appData.cursorText) || ~isvalid(appData.cursorText), return; end
        if isempty(appData.datasets) || appData.activeIdx < 1
            set(appData.cursorText, 'Visible', 'off');
            try; cursorPanelObj.update(NaN, NaN); catch; end
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
            try; cursorPanelObj.update(NaN, NaN); catch; end
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

        % Update the persistent cursor readout panel at the bottom of the axes area
        try; cursorPanelObj.update(x, y); catch; end
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
        % 2D map interactions (line-cut and box integration)
        if ~isempty(appData.datasets) && appData.activeIdx >= 1 && ...
                is2DDataset(appData.datasets{appData.activeIdx})
            mod = fig.CurrentModifier;
            if ismember('shift', mod)
                extract2DLineCut(x0, y0, true);
                return;
            elseif ismember('control', mod)
                extract2DLineCut(x0, y0, false);
                return;
            elseif ismember('alt', mod) || appData.boxIntMode
                % Alt+click/drag or button-activated mode: box integration
                if hasFixedBoxSize()
                    % Fixed-size mode: single click places centred box
                    appData.boxIntMode = false;
                    btnBoxIntegrate.Text = 'Box Integrate...';
                    btnBoxIntegrate.BackgroundColor = [0.20 0.50 0.35];
                    clearCompletedBoxPatch();   % replace previous marker
                    executeFixedBoxIntegration(x0, y0);
                else
                    % Free-draw mode: drag to define box corners.
                    % Defensive cleanup: ensure no stale rubber-band or
                    % completed marker is lingering from a previous
                    % attempt that might have exited abnormally.
                    if ~isempty(appData.boxIntPatch) && isvalid(appData.boxIntPatch)
                        delete(appData.boxIntPatch);
                    end
                    appData.boxIntPatch   = [];
                    clearCompletedBoxPatch();
                    appData.boxIntStartPt = [x0, y0];
                    fig.WindowButtonMotionFcn = @(~,~) bosonPlotter.onBoxIntMove(appData, ax);
                    obiuCb_.onMouseHover             = @onMouseHover;
                    obiuCb_.clearCompletedBoxPatch   = @clearCompletedBoxPatch;
                    obiuCb_.extract2DBoxIntegral     = @extract2DBoxIntegral;
                    fig.WindowButtonUpFcn     = @(~,~) bosonPlotter.onBoxIntUp(appData, fig, ax, obiuCb_);
                end
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
        fig.WindowButtonMotionFcn = @(~,~) bosonPlotter.onZoomMouseMove(appData, ax);
        fig.WindowButtonUpFcn     = @onZoomMouseUp;
    end

    function onZoomMouseUp(~,~)
    %ONZOOMMOUSEUP  Delegate to extracted +bosonPlotter module.
        ozmuCb_.onMouseHover                 = @onMouseHover;
        ozmuCb_.saveAxisLimsToActiveDataset  = @saveAxisLimsToActiveDataset;
        ozmuCb_.onPlot                       = @() onPlot([],[]);
        bosonPlotter.onZoomMouseUp(appData, fig, ax, ui, ozmuCb_);
    end

    function clearCompletedBoxPatch()
    %CLEARCOMPLETEDBOXPATCH  Remove the persistent "last integrated box"
    %  marker from the axes and forget the saved region coords.
        if ~isempty(appData.boxIntCompletedPatch) && ...
                isvalid(appData.boxIntCompletedPatch)
            delete(appData.boxIntCompletedPatch);
        end
        appData.boxIntCompletedPatch  = [];
        appData.boxIntCompletedRegion = [];
    end

    function redrawCompletedBoxPatch()
    %REDRAWCOMPLETEDBOXPATCH  Re-create the completed-box marker from
    %  the stored region after a plot refresh that wiped the patch.
    %  No-op when no region is recorded or the axes is invalid.
        if isempty(appData.boxIntCompletedRegion), return; end
        if isempty(ax) || ~isvalid(ax), return; end
        % Only meaningful on the 2D heatmap view
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        if ~is2DDataset(appData.datasets{appData.activeIdx}), return; end
        r = appData.boxIntCompletedRegion;
        xLo = r(1); xHi = r(2); yLo = r(3); yHi = r(4);
        hold(ax, 'on');
        appData.boxIntCompletedPatch = patch(ax, ...
            [xLo xHi xHi xLo xLo], [yLo yLo yHi yHi yLo], ...
            'k', ...
            'FaceAlpha',       0, ...
            'EdgeColor',       [0.15 0.65 0.30], ...
            'LineStyle',       '-', ...
            'LineWidth',       2.0, ...
            'Tag',             'GUIBoxIntCompleted', ...
            'HandleVisibility','off');
        hold(ax, 'off');
    end

    function onBoxIntButton(~,~)
    %ONBOXINTBUTTON  Box-integration trigger.
    %   Fixed-size mode (W/H filled): integrate the preview box immediately
    %     at the current axes centre.  Click the map first to reposition.
    %   Free-draw mode (W/H empty): enter drag mode — draw a box on the map.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        if ~is2DDataset(appData.datasets{appData.activeIdx}), return; end
        if hasFixedBoxSize()
            % Integrate at current axes centre (matches the preview box)
            cx = mean(ax.XLim);
            cy = mean(ax.YLim);
            executeFixedBoxIntegration(cx, cy);
        else
            % Free-draw mode: wait for drag on map
            appData.boxIntMode = true;
            btnBoxIntegrate.Text = 'Draw box on map...';
            btnBoxIntegrate.BackgroundColor = [0.80 0.50 0.15];
        end
    end

    function [tf, boxW, boxH] = hasFixedBoxSize()
    %HASFIXEDBOXSIZE  Return true if both Width and Height fields hold
    %  a valid positive number OR the full-range keyword ("all", ":",
    %  "*"). For keyword fields boxW/boxH is returned as Inf — callers
    %  must handle that (integration resolves Inf to the map's axis
    %  extent; preview clamps Inf to the current axes view).
        [boxW, okW] = parseBoxDim(efBoxIntW.Value);
        [boxH, okH] = parseBoxDim(efBoxIntH.Value);
        tf = okW && okH;
    end

    function [val, ok] = parseBoxDim(s)
    %PARSEBOXDIM  Interpret a box-dimension text field.
    %    ''  (empty)      → (0,   false)   — user is in free-draw mode
    %    'all' | ':' | '*'→ (Inf, true)    — request full axis extent
    %    positive number  → (num, true)
    %    anything else    → (0,   false)   — invalid input
        s = strtrim(char(s));
        if isempty(s)
            val = 0; ok = false; return;
        end
        if any(strcmpi(s, {'all', ':', '*'}))
            val = Inf; ok = true; return;
        end
        v = str2double(s);
        if isnan(v) || v <= 0
            val = 0; ok = false; return;
        end
        val = v; ok = true;
    end

    function updateBoxPreview()
    %UPDATEBOXPREVIEW  Draw or update a dashed preview rectangle on the 2D map
    %  centred on the current axes view whenever W/H fields change.
    %  Also updates the button label to reflect the current mode.
        clearBoxPreview();
        [ok, boxW, boxH] = hasFixedBoxSize();
        if ~ok
            btnBoxIntegrate.Text = 'Box Integrate...';
            return;
        end
        btnBoxIntegrate.Text = [char(9654) ' Integrate Box'];  % ▶
        % Only draw when a 2D dataset is active
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        if ~is2DDataset(appData.datasets{appData.activeIdx}), return; end
        % Centre on the current axes midpoint
        cx = mean(ax.XLim);
        cy = mean(ax.YLim);
        % "all" dimensions clamp to the current axes span for preview
        % rendering (true full-extent is applied at integration time).
        if isinf(boxW), boxW = diff(ax.XLim); end
        if isinf(boxH), boxH = diff(ax.YLim); end
        hw = boxW / 2;  hh = boxH / 2;
        xLo = cx - hw;  xHi = cx + hw;
        yLo = cy - hh;  yHi = cy + hh;
        hold(ax, 'on');
        appData.boxPreviewPatch = patch(ax, ...
            [xLo xHi xHi xLo xLo], [yLo yLo yHi yHi yLo], ...
            'k', ...
            'FaceAlpha',       0, ...
            'EdgeColor',       [0.65 0.20 0.85], ...
            'LineStyle',       '--', ...
            'LineWidth',       2.5, ...
            'Tag',             'GUIBoxIntPreview', ...
            'HandleVisibility','off');
        hold(ax, 'off');
    end

    function clearBoxPreview()
    %CLEARBOXPREVIEW  Remove the box-size preview rectangle if present.
        if ~isempty(appData.boxPreviewPatch) && isvalid(appData.boxPreviewPatch)
            delete(appData.boxPreviewPatch);
        end
        appData.boxPreviewPatch = [];
    end

    function executeFixedBoxIntegration(cx, cy)
    %EXECUTEFIXEDBOXINTEGRATION  Delegate — see +bosonPlotter/executeFixedBoxIntegration.m.
        efbiCb_.clearBoxPreview        = @clearBoxPreview;
        efbiCb_.hasFixedBoxSize        = @hasFixedBoxSize;
        efbiCb_.clearCompletedBoxPatch = @clearCompletedBoxPatch;
        efbiCb_.extract2DBoxIntegral   = @extract2DBoxIntegral;
        bosonPlotter.executeFixedBoxIntegration(appData, ax, cx, cy, efbiCb_);
    end

    function onFigSizeChanged(~,~)
    %ONFIGSIZECHANGED  Delegate to extracted +bosonPlotter module.
        fig.SizeChangedFcn = '';          % disable to avoid recursion
        ofscWidgets_.rootGL         = rootGL;
        ofscWidgets_.contentGL      = contentGL;
        ofscWidgets_.analysisGL     = analysisGL;
        ofscWidgets_.dataTablePanel = dataTablePanel;
        ofscConst_.MIN_FIG_H        = MIN_FIG_H;
        ofscConst_.LAYOUT_DEFAULTS  = LAYOUT_DEFAULTS;
        ofscCb_.is2DDataset         = @is2DDataset;
        bosonPlotter.onFigSizeChanged(appData, fig, ofscWidgets_, ofscConst_, ofscCb_);
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
        % Stop and delete auto-recalc debounce timer if pending
        if isprop(appData, 'autoRecalcTimer') && ~isempty(appData.autoRecalcTimer)
            if isvalid(appData.autoRecalcTimer)
                stop(appData.autoRecalcTimer);
                delete(appData.autoRecalcTimer);
            end
            appData.autoRecalcTimer = [];
        end
        % Stop all live file-watch connectors
        for ci = 1:numel(appData.dataConnectors)
            conn = appData.dataConnectors{ci};
            if ~isempty(conn) && isstruct(conn) && isfield(conn, 'stop')
                try; conn.stop(); catch; end
            end
        end
        appData.dataConnectors = {};
        % Stop autosave and delete recovery file (clean exit = no recovery needed)
        bosonPlotter.autosave.cleanup();
        % Close the peak analysis window if it exists
        if isvalid(peakFig), delete(peakFig); end
        delete(fig);
    end

    function onFigureKeyPress(~, e)
    %ONFIGUREKEYPRES  Delegate to extracted +bosonPlotter module.
        ofkpWidgets_.lbY         = lbY;
        ofkpWidgets_.lbDatasets  = lbDatasets;
        ofkpCb_.refreshState              = @refreshState;
        ofkpCb_.onRemoveDataset           = @onRemoveDataset;
        ofkpCb_.onSaveSession             = @onSaveSession;
        ofkpCb_.onUndo                    = appData.undoCb.onUndo;
        ofkpCb_.onRedo                    = appData.undoCb.onRedo;
        ofkpCb_.onUnmaskAll               = @onUnmaskAll;
        ofkpCb_.onSaveCSV                 = @onSaveCSV;
        ofkpCb_.onCopyToClipboard         = @onCopyToClipboard;
        ofkpCb_.onToggleDatasetVisibility = @onToggleDatasetVisibility;
        ofkpCb_.onMoveDatasetUp           = @onMoveDatasetUp;
        ofkpCb_.onMoveDatasetDown         = @onMoveDatasetDown;
        ofkpCb_.rebuildDatasetList        = @rebuildDatasetList;
        ofkpCb_.updateControlsForActiveDataset = @updateControlsForActiveDataset;
        ofkpCb_.onPlot                    = @() onPlot([],[]);
        ofkpCb_.setStatus                 = @setStatus;
        bosonPlotter.onFigureKeyPress(appData, ofkpWidgets_, ofkpCb_, e);
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
    %ONCOPYTOCLIPBOARD  Copy the current plot to the clipboard as a
    %  transparent-background vector image. Best for Word, Illustrator,
    %  Origin, most email clients — pastes crisp at any zoom.
        cpwfCb_.drawToAxes  = @drawToAxes;
        cpwfCb_.logGUIError = @logGUIError;
        bosonPlotter.copyPlotWithFormat(appData, fig, 'vector', cpwfCb_);
    end

    function onCopyToClipboardAsPNG(~,~)
    %ONCOPYTOCLIPBOARDASPNG  Copy the current plot to the clipboard as a
    %  300-dpi transparent PNG. Use this when the target app rejects or
    %  mangles the vector clipboard format (notably MS Teams, some Slack
    %  clients, and older OneNote).
        cpwfCb_.drawToAxes  = @drawToAxes;
        cpwfCb_.logGUIError = @logGUIError;
        bosonPlotter.copyPlotWithFormat(appData, fig, 'png', cpwfCb_);
    end

    function onSaveFigure(~,~)
    %ONSAVEFIGURE  Delegate — see +bosonPlotter/saveFigure.m.
        cb.drawToAxes  = @drawToAxes;
        cb.logGUIError = @logGUIError;
        bosonPlotter.saveFigure(appData, fig, ui, cb);
    end

    % ── Session save / load ───────────────────────────────────────────────

    function w = buildSessionWidgets_()
    %BUILDSESSIONWIDGETS_  Pack widget handles into the struct expected by
    %  bosonPlotter.sessionManager.collectGuiState / applyGuiState.
        w.ddColormap  = ddColormap;
        w.ddMap2DCmap = ddMap2DCmap;
        w.ddX         = ddX;
        w.lbY         = lbY;
        w.lbY2        = lbY2;
        w.ddScaleX    = ddScaleX;
        w.ddScaleY    = ddScaleY;
        w.ddBGInterp  = ddBGInterp;
    end

    function onSaveSession(~,~)
    %ONSAVESESSION  Save all datasets and key UI settings to a .mat file.
    %  Delegates serialisation to bosonPlotter.sessionManager.save().
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

        widgets = buildSessionWidgets_();
        guiState = bosonPlotter.sessionManager.collectGuiState(widgets);

        setStatus('Saving session...');
        fig.Pointer = 'watch';
        drawnow;
        try
            bosonPlotter.sessionManager.save(outPath, appData, guiState);
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
    %ONLOADSESSION  Delegate to extracted +bosonPlotter module.
        olsWidgets_.ddTemplate      = ddTemplate;
        olsWidgets_.efBGFile        = efBGFile;
        olsWidgets_.efDatasetSearch = efDatasetSearch;
        olsCb_.cancelInteractions          = @cancelInteractions;
        olsCb_.refreshTemplateDropdown     = @refreshTemplateDropdown;
        olsCb_.onStylePick                 = @onStylePick;
        olsCb_.rebuildDatasetList          = @rebuildDatasetList;
        olsCb_.updateControlsForActiveDataset = @updateControlsForActiveDataset;
        olsCb_.onPlot                      = @() onPlot([],[]);
        olsCb_.setStatus                   = @setStatus;
        olsCb_.logGUIError                 = @logGUIError;
        olsCb_.buildSessionWidgets         = @buildSessionWidgets_;
        bosonPlotter.onLoadSession(appData, fig, olsWidgets_, olsCb_);
    end

    % ── Panel drag-resize ────────────────────────────────────────────────

    function startPanelResize()
    %STARTPANELRESIZE  Delegate to extracted +bosonPlotter module.
        sprWidgets_.rootGL         = rootGL;
        sprWidgets_.analysisGL     = analysisGL;
        sprWidgets_.contentGL      = contentGL;
        sprWidgets_.analysisPanel  = analysisPanel;
        sprWidgets_.corrPanel      = corrPanel;
        sprWidgets_.savePanel      = savePanel;
        sprWidgets_.fileListPanel  = fileListPanel;
        sprWidgets_.ctrlPanel      = ctrlPanel;
        sprCb_.onMouseHover        = @onMouseHover;
        bosonPlotter.startPanelResize(appData, fig, sprWidgets_, sprCb_);
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
        if cbWaterfall.Value && (isempty(efWaterfallSpacing.Value) || efWaterfallSpacing.Value <= 0)
            autoSp = computeAutoWaterfallSpacing();
            efWaterfallSpacing.Value = autoSp;
        end
        onPlot([],[]);
    end

    function s = computeAutoWaterfallSpacing()
    %COMPUTEAUTOWATERFALLSPACING  Delegates to bosonPlotter.computeAutoWaterfallSpacing.
        s = bosonPlotter.computeAutoWaterfallSpacing(appData.datasets, appData.activeIdx, lbY.Value, ddScaleY.Value);
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

    % ════════════════════════════════════════════════════════════════════
    %  Column-header drag-to-plot
    % ════════════════════════════════════════════════════════════════════

    function onColumnDragStart(colName)
    %ONCOLUMNDRAGSTART  Record the column name and arm drag-detect callbacks.
    %  Called from onTableSelectionChanged when a column header row is clicked.
    %  Actual drag does not begin until the mouse has moved > 5 px (hysteresis
    %  in onColumnDragMove).
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        appData.columnDragPending  = true;
        appData.columnDragActive   = false;
        appData.columnDragColName  = colName;
        appData.columnDragStartPx  = fig.CurrentPoint;
        % Overwrite motion/up only — leave ButtonDown alone so normal clicks
        % (column selection) are not disrupted.
        fig.WindowButtonMotionFcn = @onColumnDragMove;
        fig.WindowButtonUpFcn     = @onColumnDragUp;
    end

    function onColumnDragMove(~,~)
    %ONCOLUMNDRAGMOVE  Move the ghost label; highlight drop zone on axes.
        if ~appData.columnDragPending && ~appData.columnDragActive, return; end
        mp = fig.CurrentPoint;   % [x y] in figure pixels

        % Hysteresis: promote pending → active after 5 px movement
        if ~appData.columnDragActive
            if norm(mp - appData.columnDragStartPx) < 5, return; end
            appData.columnDragActive  = true;
            appData.columnDragPending = false;
            % Create floating ghost label
            ghostW = 120;  ghostH = 24;
            appData.columnDragGhost = uilabel(fig, ...
                'Text',            appData.columnDragColName, ...
                'Position',        [mp(1)+8, mp(2)-ghostH/2, ghostW, ghostH], ...
                'FontSize',        tk.font.label, ...
                'FontWeight',      'bold', ...
                'BackgroundColor', [0.20 0.20 0.60], ...
                'FontColor',       [1 1 1], ...
                'HorizontalAlignment', 'center');
            fig.Pointer = 'hand';
        end

        % Move ghost
        if ~isempty(appData.columnDragGhost) && isvalid(appData.columnDragGhost)
            ghostPos = appData.columnDragGhost.Position;
            appData.columnDragGhost.Position = [mp(1)+8, mp(2)-ghostPos(4)/2, ghostPos(3), ghostPos(4)];
        end

        % Highlight drop zone inside axes
        zone = columnDragZoneAt(mp);   % 'x', 'y', 'y2', or ''
        updateColumnDragOverlay(zone);
    end

    function onColumnDragUp(~,~)
    %ONCOLUMNDRAGUP  If released over axes, assign channel and replot.
        fig.WindowButtonMotionFcn = @onMouseHover;
        fig.WindowButtonUpFcn     = '';
        fig.Pointer               = 'arrow';

        mp   = fig.CurrentPoint;
        zone = columnDragZoneAt(mp);
        colName = appData.columnDragColName;

        % Clean up overlay and ghost before any early return
        cleanUpColumnDragOverlay();
        if ~isempty(appData.columnDragGhost) && isvalid(appData.columnDragGhost)
            delete(appData.columnDragGhost);
        end
        appData.columnDragGhost   = [];
        appData.columnDragActive  = false;
        appData.columnDragPending = false;
        appData.columnDragColName = '';
        appData.columnDragStartPx = [];

        if isempty(zone) || isempty(colName), return; end
        setChannelFromDrag(colName, zone);
    end

    function zone = columnDragZoneAt(mp)
    %COLUMNDRAGZONEAT  Return 'x', 'y', 'y2', or '' based on cursor position.
    %  Left third of axes → X, centre third → Y (left), right third → Y2.
        zone = '';
        try
            axPos = getpixelposition(ax, true);   % [x y w h] in figure pixels
            px = mp(1);
            if px < axPos(1) || px > axPos(1)+axPos(3), return; end
            py = mp(2);
            if py < axPos(2) || py > axPos(2)+axPos(4), return; end
            frac = (px - axPos(1)) / axPos(3);
            if     frac < 1/3, zone = 'x';
            elseif frac < 2/3, zone = 'y';
            else,              zone = 'y2';
            end
        catch
            % getpixelposition unavailable or axes invalid — return ''
        end
    end

    function updateColumnDragOverlay(zone)
    %UPDATECOLUMNDRAGOVERLAY  Draw a coloured hint rectangle over the active drop zone.
    %  Colours: X = blue, Y = green, Y2 = orange.  Clears previous overlay first.
        cleanUpColumnDragOverlay();
        if isempty(zone), return; end
        try
            axPos = getpixelposition(ax, true);  % figure-pixel coords
            w3 = axPos(3) / 3;
            switch zone
                case 'x',  xOff = 0;     clr = [0.20 0.55 0.90];  lbl = 'X';
                case 'y',  xOff = w3;    clr = [0.15 0.70 0.30];  lbl = 'Y';
                case 'y2', xOff = 2*w3;  clr = [0.90 0.55 0.10];  lbl = 'Y2';
                otherwise, return;
            end
            % Overlay uilabel covering the drop-zone third of the axes
            figX = axPos(1) + xOff;
            figY = axPos(2);
            % FontColor must be 3-element RGB; BackgroundColor supports RGBA
            % on R2023a+ but falls back gracefully on older versions.
            fig.UserData = uilabel(fig, ...
                'Position',        [figX, figY, w3, axPos(4)], ...
                'Text',            lbl, ...
                'FontSize',        22, ...
                'FontWeight',      'bold', ...
                'FontColor',       clr, ...
                'BackgroundColor', clr * 0.35, ...
                'HorizontalAlignment', 'center', ...
                'Tag',             'ColumnDragZoneOverlay');
        catch
            % Layout not yet resolved — skip overlay gracefully
        end
    end

    function cleanUpColumnDragOverlay()
    %CLEANUPCOLUMNDRAGOVERLAY  Remove any lingering zone-highlight overlay.
        try
            overlay = findobj(fig, 'Tag', 'ColumnDragZoneOverlay');
            if ~isempty(overlay)
                delete(overlay);
            end
            % Also clear fig.UserData if it held an overlay handle
            if ~isempty(fig.UserData) && isgraphics(fig.UserData, 'uilabel') && ...
               isvalid(fig.UserData)
                delete(fig.UserData);
            end
            fig.UserData = [];
        catch
        end
    end

    function setChannelFromDrag(colName, target)
    %SETCHANNELFROMDRAG  Assign colName to X, Y, or Y2 selector and replot.
    %
    %   Syntax
    %     setChannelFromDrag(colName, target)
    %
    %   Inputs
    %     colName  — column label string (must exist in the active dataset)
    %     target   — 'x', 'y', or 'y2' (case-insensitive)
    %
    %   Called internally by onColumnDragUp and exposed through api for tests.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        if isempty(colName) || isempty(target), return; end

        ds = appData.datasets{appData.activeIdx};
        d  = ds.data;
        xName     = guiXName(d.metadata);
        allLabels = [{xName}, d.labels];

        target = lower(strtrim(target));
        switch target
            case 'x'
                % colName must be in the X dropdown items
                if ~ismember(colName, allLabels)
                    setStatus(sprintf('Drag-to-X: column "%s" not available as X axis', colName));
                    return;
                end
                ddX.ValueChangedFcn = [];
                ddX.Value = colName;
                ddX.ValueChangedFcn = @onAxisChanged;

            case 'y'
                % colName must be a data column (in d.labels)
                if ~ismember(colName, d.labels)
                    setStatus(sprintf('Drag-to-Y: column "%s" not a plottable channel', colName));
                    return;
                end
                lbY.ValueChangedFcn = [];
                lbY.Value = {colName};
                lbY.ValueChangedFcn = @onAxisChanged;

            case 'y2'
                if ~ismember(colName, d.labels)
                    setStatus(sprintf('Drag-to-Y2: column "%s" not a plottable channel', colName));
                    return;
                end
                lbY2.ValueChangedFcn = [];
                lbY2.Value = {colName};
                lbY2.ValueChangedFcn = @(~,~) onPlot([],[]);

            otherwise
                return;
        end

        setStatus(sprintf('Channel dragged: "%s" → %s axis', colName, upper(target)));
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
    %TOGGLEY2APPEARANCE  Toggle right-axis Enable state on the hidden floaters.
    %  After the Axes panel was deleted, ddDatasetColor / ddDatasetColorR /
    %  efLegendName / efLegendNameR / efCustomYLabel / efCustomY2Label are
    %  hidden uifigure children with no Layout (no parent grid). They stay
    %  invisible regardless; we just enable the right-axis variants when
    %  Y2 is active so menu writes (or future dialogs) can read meaningful
    %  state.
        if active
            ddDatasetColorR.Enable = 'on';
            efLegendNameR.Enable   = 'on';
        else
            ddDatasetColorR.Enable = 'off';
            efLegendNameR.Enable   = 'off';
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
        appData.model.addDataset(dsCopy.data, dsCopy.filepath, dsCopy.parserName);
        appData.activeIdx = numel(appData.datasets);
        rebuildDatasetList(true);
        updateControlsForActiveDataset();
        onPlot([],[]);
    end

    function onDatasetMetaEdit(mode)
    %ONDATASETMETAEDIT  Delegate — see +bosonPlotter/datasetMetaEdit.m.
        cb.setStatus                     = @setStatus;
        cb.guiImport                     = @guiImport;
        cb.rebuildDatasetList             = @(keep) rebuildDatasetList(keep);
        cb.onSelectDataset               = @onSelectDataset;
        cb.onPlot                        = @() onPlot([],[]);
        cb.updateControlsForActiveDataset = @updateControlsForActiveDataset;
        bosonPlotter.datasetMetaEdit(appData, fig, ui, mode, cb);
    end

    function onEditColumnMapping()
    %ONEDITCOLUMNMAPPING  Open the Column Mapper dialog for the active dataset.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds = appData.datasets{appData.activeIdx};
        corrected = templates.ColumnMapper(ds.data, ParentFig=fig);
        if ~isempty(corrected)
            appData.datasets{appData.activeIdx}.data = corrected;
            appData.datasets{appData.activeIdx}.corrData = [];
            updateControlsForActiveDataset();
            onPlot([], []);
            setStatus('Column mapping updated.');
        end
    end

    function onSaveAsTemplate()
    %ONSAVEASTEMPLATE  Save the active dataset's column layout as a template.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds = appData.datasets{appData.activeIdx};
        answer = inputdlg('Template name:', 'Save as Template', [1 60], {''});
        if isempty(answer) || isempty(strtrim(answer{1})), return; end

        tmpl = struct();
        tmpl.name = strtrim(answer{1});
        tmpl.type = 'tabular';
        tmpl.match.headerFingerprint = templates.TemplateEngine.fingerprint(ds.data);
        tmpl.match.columnNames = ds.data.labels;
        if isfield(ds.data.metadata, 'parserName')
            tmpl.match.parserName = ds.data.metadata.parserName;
        end
        tmpl.overrides = struct('labels', struct(), 'units', struct());
        templates.TemplateEngine.save(tmpl);
        setStatus(sprintf('Template "%s" saved.', tmpl.name));
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
    %ONESTIMATEBASELINE  Delegate to bosonPlotter.estimateBaseline.
        bosonPlotter.estimateBaseline(appData, fig, ddBaselineMethod, efBaselineLambda, efBaselineRadius, ...
            @buildDs, @(k) rebuildDatasetList(k), @() onPlot([],[]), @setStatus);
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
        appData.model.addDataset(dsNew.data, dsNew.filepath, dsNew.parserName);
        appData.activeIdx = numel(appData.datasets);
        rebuildDatasetList(true);
        updateControlsForActiveDataset();
        onPlot([],[]);
        recordAction(sprintf('%% Resample: %d pts [%.4g, %.4g]', newN, newXMin, newXMax));
    end

    function onColumnCalculator(~,~)
    %ONCOLUMNCALCULATOR  Delegate to extracted +bosonPlotter module.
        occCb_.updateControlsForActiveDataset = @updateControlsForActiveDataset;
        occCb_.onPlot        = @() onPlot([],[]);
        occCb_.setStatus     = @setStatus;
        occCb_.recordAction  = @recordAction;
        bosonPlotter.onColumnCalculator(appData, fig, occCb_);
    end

    function onCreateInset(~,~)
    %ONCREATEINSET  Toolbar button: delegate to onCreateInsetFromMenu.
        onCreateInsetFromMenu();
    end

    function onCreateInsetFromMenu()
    %ONCREATEINSETFROMMENU  Right-click menu: prompt for region, then create inset.
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
        if xLo >= xHi || yLo >= yHi
            uialert(fig,'Region bounds must satisfy min < max.','Invalid Region');
            return;
        end
        try
            bosonPlotter.insetGraph(ax, [xLo xHi yLo yHi]);
        catch ME
            uialert(fig, sprintf('Inset creation failed:\n%s', ME.message), 'Inset Error');
        end
    end

    function onRemoveInset()
    %ONREMOVEINSET  Right-click menu: remove the inset and its decorations.
        bosonPlotter.insetGraph_remove(ax);
    end

    % ── Interactive Data Cursor ────────────────────────────────────────

    function onToggleDataCursor(~,~)
    %ONTOGGLEDATACURSOR  Toggle interactive data cursor mode.
    %  Click on plot to snap to nearest data point and show (x,y).
    %  Click a second point to show delta.  Ctrl+click pins a marker.
    %  Click button again to exit and clear all markers.
        if appData.cursorActive
            % Deactivate cursor
            appData.cursorActive = false;
            btnDataCursor.BackgroundColor = BTN_TOOL;
            fig.WindowButtonDownFcn = @onAxesButtonDown;
            % Remove cursor graphics
            if isgraphics(appData.cursorMarker), delete(appData.cursorMarker); end
            if isgraphics(appData.cursorLabel), delete(appData.cursorLabel); end
            if isgraphics(appData.cursorMarker2), delete(appData.cursorMarker2); end
            if isgraphics(appData.cursorDeltaLabel), delete(appData.cursorDeltaLabel); end
            if isgraphics(appData.cursorLine), delete(appData.cursorLine); end
            % Remove pinned markers
            for pi = 1:numel(appData.cursorPinned)
                p = appData.cursorPinned{pi};
                if isgraphics(p.marker), delete(p.marker); end
                if isgraphics(p.label),  delete(p.label);  end
            end
            appData.cursorPinned = {};
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
            setStatus('Cursor ON — click to read, click again for delta. Ctrl+click to pin.');
        end
    end

    function onCursorClick(~,~)
    %ONCURSORCLICK  Delegate — see +bosonPlotter/cursorClick.m.
        cb.getPlotData = @getPlotData;
        cb.setStatus   = @setStatus;
        bosonPlotter.cursorClick(appData, fig, ax, cb);
    end

    % ── Dataset Algebra ────────────────────────────────────────────────

    function onDatasetAlgebra(~,~)
    %ONDATASETALGEBRA  Delegate to bosonPlotter.datasetAlgebra.
        bosonPlotter.datasetAlgebra(appData, fig, struct( ...
            'BTN_PRIMARY',               BTN_PRIMARY, ...
            'BTN_FG',                    BTN_FG, ...
            'getPlotDataFn',             @getPlotData, ...
            'buildDsFn',                 @buildDs, ...
            'rebuildDatasetListFn',      @(k) rebuildDatasetList(k), ...
            'updateControlsForActiveFn', @updateControlsForActiveDataset, ...
            'onPlotFn',                  @() onPlot([],[]), ...
            'setStatusFn',               @setStatus));
    end

    % ── Data Table Functions ─────────────────────────────────────────────

    % (Data table is hidden in 2D map mode — see the is2D_active block in
    %  updateControlsForActiveDataset.)

    function refreshDataTable()
    %REFRESHDATATABLE  Delegate to bosonPlotter.refreshDataTable.
        bosonPlotter.refreshDataTable(appData, tblData, tblUnits, lblTableUnits, lblTableStats, ...
            struct('getPlotDataFn',            @getPlotData, ...
                   'is2DDatasetFn',            @is2DDataset, ...
                   'applyMaskStylingFn',       tblCb.applyMaskStyling, ...
                   'syncUnitsColumnWidthsFn',  tblCb.syncUnitsColumnWidths));
    end

    % (Table callbacks extracted to +bosonPlotter/tableCallbacks.m — tblCb)

    % ── Plot Options Popup Menu ──────────────────────────────────────────

    function onShowPlotOptionsMenu(~, ~)
    %ONSHOWPLOTOPTIONSMENU  Delegate to extracted +bosonPlotter module.
        ospomCb_.onComposeFigure = @onComposeFigure;
        ospomCb_.on3DSurface     = @on3DSurface;
        ospomCb_.onPolarPlot     = @onPolarPlot;
        ospomCb_.onConvertUnits  = @onConvertUnits;
        ospomCb_.onWriteXRDcsv   = @onWriteXRDcsv;
        bosonPlotter.showPlotOptionsMenu(appData, fig, headless, ospomCb_);
    end

    % ── Plot Options callbacks ────────────────────────────────────────────

    function onComposeFigure(~, ~)
    %ONCOMPOSEFIGURE  Create a multi-panel composite figure.
        if isempty(appData.datasets)
            uialert(fig, 'Load at least one dataset.', 'Compose Figure');
            return;
        end
        % Build sources from loaded datasets
        sources = cell(1, numel(appData.datasets));
        for si = 1:numel(appData.datasets)
            sources{si} = appData.datasets{si}.data;
        end
        try
            plotting.composeFigure(sources);
            setStatus(sprintf('Composite figure: %d panels', numel(sources)));
        catch ME
            uialert(fig, sprintf('Compose Figure failed:\n%s', ME.message), 'Error');
        end
        recordAction('%% Composite figure created');
    end

    function on3DSurface(~, ~)
    %ON3DSURFACE  Create a 3D surface/mesh plot from gridded data.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', '3D Surface');
            return;
        end
        ds = appData.datasets{appData.activeIdx};
        % Check for 2D map data
        if isfield(ds.data.metadata, 'parserSpecific') && ...
                isfield(ds.data.metadata.parserSpecific, 'is2D') && ...
                ds.data.metadata.parserSpecific.is2D
            try
                plotting.surface3D(ds.data);
                setStatus('3D surface plot created');
            catch ME
                uialert(fig, sprintf('3D Surface failed:\n%s', ME.message), 'Error');
            end
        else
            uialert(fig, ['Active dataset does not contain 2D gridded data. ' ...
                'Load a 2D XRDML map or area-detector scan.'], '3D Surface');
        end
        recordAction('%% 3D surface plot');
    end

    function onPolarPlot(~, ~)
    %ONPOLARPLOT  Create a polar plot from the active dataset.
        [xV, yV, ~] = getActiveXY();
        if isempty(yV), return; end
        try
            plotting.polarPlot(xV, yV);
            setStatus('Polar plot created');
        catch ME
            uialert(fig, sprintf('Polar Plot failed:\n%s', ME.message), 'Error');
        end
        recordAction('%% Polar plot');
    end

    function onConvertUnits(~, ~)
    %ONCONVERTUNITS  Delegate to extracted +bosonPlotter module.
        ocuCb_.onPlot       = @() onPlot([], []);
        ocuCb_.setStatus    = @setStatus;
        ocuCb_.logGUIError  = @logGUIError;
        ocuCb_.recordAction = @recordAction;
        bosonPlotter.onConvertUnits(appData, fig, ocuCb_);
    end

    function onWriteXRDcsv(~, ~)
    %ONWRITEXRDCSV  Export XRD data as CSV with metadata header.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'XRD CSV Export');
            return;
        end
        ds = appData.datasets{appData.activeIdx};
        [fn, fp] = uiputfile({'*.csv', 'CSV File (*.csv)'}, ...
            'Export XRD CSV', [ds.name '.csv']);
        if isequal(fn, 0), return; end
        outPath = fullfile(fp, fn);
        try
            utilities.writeXRDcsv(ds.data, outPath);
            setStatus(sprintf('XRD CSV exported: %s', fn));
        catch ME
            uialert(fig, sprintf('Export failed:\n%s', ME.message), 'Error');
        end
        recordAction(sprintf('%% XRD CSV export: %s', fn));
    end

    % ── Batch Import callback ─────────────────────────────────────────────

    function onBatchImportDir(~, ~)
    %ONBATCHIMPORTDIR  Delegate to extracted +bosonPlotter module.
        obidCb_.buildDs             = @buildDs;
        obidCb_.rebuildDatasetList  = @rebuildDatasetList;
        obidCb_.onSelectDataset     = @() onSelectDataset([],[]);
        obidCb_.setStatus           = @setStatus;
        obidCb_.recordAction        = @recordAction;
        bosonPlotter.onBatchImportDir(appData, fig, obidCb_);
    end

    % ── Dataset Groups callbacks ──────────────────────────────────────────

    appData.datasetGroups = containers.Map('KeyType', 'char', 'ValueType', 'any');

    function onGroupChanged(~, ~)
    %ONGROUPCHANGED  Filter dataset list by group or create a new group.
        groupName = ddGroup.Value;
        if strcmp(groupName, 'All Datasets')
            % Show all datasets
            rebuildDatasetList(true);
            return;
        end
        if ~appData.datasetGroups.isKey(groupName)
            % New group — create it empty
            appData.datasetGroups(groupName) = [];
            ddGroup.Items = [{'All Datasets'}, appData.datasetGroups.keys()];
            ddGroup.Value = groupName;
            setStatus(sprintf('Group "%s" created — select datasets and click +Grp to add', groupName));
            return;
        end
        % Filter listbox to show only datasets in this group
        indices = appData.datasetGroups(groupName);
        if isempty(indices)
            setStatus(sprintf('Group "%s" is empty', groupName));
            return;
        end
        rebuildDatasetList(true);
        setStatus(sprintf('Showing group: %s (%d datasets)', groupName, numel(indices)));
    end

    function onAddToGroup(~, ~)
    %ONADDTOGROUP  Add selected datasets to the current group.
        groupName = ddGroup.Value;
        if strcmp(groupName, 'All Datasets')
            uialert(fig, 'Select or create a group first (type a name in the dropdown).', 'Add to Group');
            return;
        end
        sel = lbDatasets.Value;
        if iscell(sel), sel = [sel{:}]; end
        sel = sel(sel > 0);
        if isempty(sel)
            uialert(fig, 'Select datasets in the list first.', 'Add to Group');
            return;
        end
        if ~appData.datasetGroups.isKey(groupName)
            appData.datasetGroups(groupName) = [];
        end
        existing = appData.datasetGroups(groupName);
        appData.datasetGroups(groupName) = unique([existing, sel]);
        ddGroup.Items = [{'All Datasets'}, appData.datasetGroups.keys()];
        setStatus(sprintf('Added %d dataset(s) to group "%s"', numel(sel), groupName));
    end

    function onRemoveFromGroup(~, ~)
    %ONREMOVEFROMGROUP  Remove selected datasets from the current group.
        groupName = ddGroup.Value;
        if strcmp(groupName, 'All Datasets'), return; end
        if ~appData.datasetGroups.isKey(groupName), return; end
        sel = lbDatasets.Value;
        if iscell(sel), sel = [sel{:}]; end
        sel = sel(sel > 0);
        existing = appData.datasetGroups(groupName);
        existing = setdiff(existing, sel);
        if isempty(existing)
            appData.datasetGroups.remove(groupName);
            ddGroup.Items = [{'All Datasets'}, appData.datasetGroups.keys()];
            ddGroup.Value = 'All Datasets';
            rebuildDatasetList(true);
            setStatus(sprintf('Group "%s" deleted (empty)', groupName));
        else
            appData.datasetGroups(groupName) = existing;
            setStatus(sprintf('Removed %d dataset(s) from group "%s"', numel(sel), groupName));
        end
    end

    % ── Advanced Analysis & Correction Menu ─────────────────────────────

    function onShowAdvancedMenu(~, ~)
    %ONSHOWADVANCEDMENU  Delegate — see +bosonPlotter/showAdvancedMenu.m.
        cb.anaCb                = anaCb;
        cb.tblCb                = tblCb;
        cb.onDatasetAlgebra     = @onDatasetAlgebra;
        cb.onResampleDataset    = @onResampleDataset;
        cb.onColumnCalculator   = @onColumnCalculator;
        cb.onAdvAsymmetry       = @onAdvAsymmetry;
        cb.onFFTThickness       = @onFFTThickness;
        cb.onReflectivityFFT    = @onReflectivityFFT;
        cb.onArmFringeThickness = @onArmFringeThickness;
        cb.onCreateInset        = @onCreateInset;
        bosonPlotter.showAdvancedMenu(appData, fig, headless, cb);
    end

    % ── Shared Data Helper (used by table, peaks, and analysis callbacks) ────

    function d = getPlotData(dsIdx)
    %GETPLOTDATA  Return corrected data if available, else raw.
        ds = appData.datasets{dsIdx};
        if ~isempty(ds.corrData)
            d = ds.corrData;
        else
            d = ds.data;
        end
    end

    function [xV, yV, yLbl] = getActiveXY()
    %GETACTIVEXY  Extract x,y vectors and label for the active dataset/channel.
        xV = []; yV = []; yLbl = '';
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'No Data');
            return;
        end
        ds = appData.datasets{appData.activeIdx};
        d  = ds.data;
        if ~isempty(ds.corrData), d = ds.corrData; end
        ySel = ensureCell(lbY.Value);
        if isempty(ySel)
            uialert(fig, 'Select a Y channel.', 'No Channel');
            return;
        end
        yIdx = find(strcmp(d.labels, ySel{1}), 1);
        if isempty(yIdx)
            uialert(fig, 'Channel not found.', 'Error');
            return;
        end
        xV = d.time;  yV = d.values(:, yIdx);  yLbl = d.labels{yIdx};
        if isdatetime(xV)
            valid = ~isnat(xV) & ~isnan(yV);
            xV = datenum(xV(valid)); %#ok<DATNM>
        else
            valid = ~isnan(xV) & ~isnan(yV);
            xV   = xV(valid);
        end
        yV = yV(valid);
    end

    % ── Analysis callbacks — stubs delegate to anaCb (analysisCallbacks.m) ─
    % NOTE: onOverlayModeChanged / onPlotTemplates / onBatchFigureExport /
    %       onAdvancedFigureBuilder are wired to toolbar buttons created
    %       before anaCb exists, so named stubs are needed.  All other
    %       analysis callbacks are wired directly as anaCb.onFoo handles
    %       in onShowAdvancedMenu.

    function onOverlayModeChanged(~,~)
        anaCb.onOverlayModeChanged([],[]);
    end

    function onPlotTemplates(~,~)
        anaCb.onPlotTemplates([],[]);
    end

    function onBatchFigureExport(~,~)
        anaCb.onBatchFigureExport([],[]);
    end

    function onAdvancedFigureBuilder(~,~)
        anaCb.onAdvancedFigureBuilder([],[]);
    end

    if nargout > 0
        varargout{1} = api;
    end

end  % BosonPlotter


% ════════════════════════════════════════════════════════════════════════
%  Module-level helpers  (stateless — no access to GUI handles)
% ════════════════════════════════════════════════════════════════════════

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
    % Per-dataset provenance log (W3 #15) — initial import entry.
    [~, fn_, fe_] = fileparts(fp);
    impCmd = guiTernary(~isempty(parserName), ...
        sprintf("data = parser.%s('%s');", parserName, strrep(fp,'''','''''')), "");
    ds = bosonPlotter.appendHistory(ds, "import", ...
        sprintf("imported %s%s via %s", fn_, fe_, parserName), impCmd);
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
    % Per-dataset plot-view state — empty fields fall back to parser-aware
    % defaults in updateControlsForActiveDataset. Non-empty fields are
    % authoritative and override auto-detection, so that switching away
    % and back to a dataset restores the user's chosen view.
    ds.plotState   = struct( ...
        'xScale',      '', ...   '' | 'Linear' | 'Log'
        'yScale',      '', ...
        'y2Scale',     '', ...
        'gridX',       '', ...   '' | 'on' | 'off'
        'gridY',       '', ...
        'xDir',        '', ...   '' | 'normal' | 'reverse'
        'yDir',        '', ...
        'map2DCmap',   '', ...   2D heatmap colormap name
        'map2DScale',  '', ...   'Linear' | 'Log₁₀'
        'map2DCMin',   '', ...   numeric or ''
        'map2DCMax',   '');      % numeric or ''
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
    ds.momentUnit    = 'emu';  % target moment unit
    ds.fieldUnit     = 'Oe';   % target field unit
    ds.unitSystem    = 'CGS';        % 'CGS' or 'SI' — quick-set toggle
    ds.refLines       = {};       % Cell array of structs: {orientation, value, color, style}
    ds.mask            = true(size(data.time));  % logical; true = included, false = masked
    ds.notes           = '';       % Free-text annotation; persists in session save/load
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

        case 'importLakeShore'
            % Lake Shore magnetometer exports — routed here by
            % resolveParser's content-sniffer when the .dat header shows
            % vendor strings or 7400/8600 model numbers. Load all
            % channels so the GUI Y-axis picker sees every column.
            data = parser.importLakeShore(fp, 'YAxis', 'all');

        case 'importMPMS'
            % MPMS SQUID magnetometer — shares the QD [Header]/[Data]
            % layout, so it's normally reached via importQDVSM dispatch.
            % This branch exists for users who configure the parser
            % directly (e.g. from templates or scripts).
            data = parser.importMPMS(fp, 'YAxis', 'all');

        case 'importImage'
            data = parser.importImage(fp);

        case 'importBCF'
            data = parser.importBCF(fp);

        case 'importDM3'
            data = parser.importDM3(fp);

        case 'importDM4'
            data = parser.importDM4(fp);

        case 'importAFM'
            data = parser.importAFM(fp);

        otherwise
            error('BosonPlotter:unknownExt', ...
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
    s = bosonPlotter.smartLabel(name, unit);
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


function ls = guiLineSpec_right(style)
%GUILINESPEC_RIGHT  Dashed line spec for right-axis (Y2) channels.
    switch style
        case 'Scatter'
            ls = {'LineStyle','none','Marker','s','MarkerSize',5};
        case 'Line+Pts'
            ls = {'LineStyle','--','Marker','s','MarkerSize',4};
        otherwise   % 'Line'
            ls = {'LineStyle','--'};
    end
end


function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function d = resolveStartDir(lastDir)
%RESOLVESTARTDIR  Pick a file-dialog starting folder.
%   Uses lastDir when it is a valid existing directory; otherwise falls back
%   to pwd so newly-launched sessions open in the MATLAB working directory.
    if ~isempty(lastDir) && (ischar(lastDir) || (isstring(lastDir) && isscalar(lastDir))) ...
            && isfolder(lastDir)
        d = char(lastDir);
    else
        d = pwd;
    end
end

function b = bytesPerElem(x)
%BYTESPERELEM  Return bytes per element for the class of x.
    if isa(x, 'single'), b = 4;
    elseif isa(x, 'uint16'), b = 2;
    elseif isa(x, 'uint8'), b = 1;
    else, b = 8;  % double, int64, uint64
    end
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
        case 'boxIntegral'
            badge = '[BOX]';  % Box-integrated profile from a 2D map
        case 'arcIntegral'
            badge = '[ARC]';  % Arc-integrated I(|Q|) from a 2D RSM
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
        ct = 0;
    end
end


function colors = getColorsFromMap(colormapName, nColors)
%GETCOLORSFROMMPA  Generate nColors colors from a named colormap.
%   Delegates to bosonPlotter.colorMaps for the actual implementation.
    colors = bosonPlotter.colorMaps(colormapName, nColors);
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


