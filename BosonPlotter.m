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

    % Stacked vertically: Add | Batch | Remove | Filter | Merge | Up/Down | Groups | Animate/Shortcuts | Settings | Listbox
    tbGL = uigridlayout(fileListPanel,[10 2], ...
        'RowHeight',    {22,22,22,22,22,22,22,22,22,'1x'}, ...
        'ColumnWidth',  {'1x','1x'}, ...
        'Padding',      [0 0 0 0], ...
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
        'FontSize', 10, ...
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

    efDatasetSearch = uieditfield(tbGL,'text','Value','', ...
        'Placeholder','Filter datasets...', ...
        'Tooltip','Filter the dataset list by name (case-insensitive substring match)', ...
        'ValueChangedFcn',@onSearchChanged);
    efDatasetSearch.Layout.Row = 4; efDatasetSearch.Layout.Column = [1 2];

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
        'Padding',[0 0 0 0],'ColumnSpacing',2, ...
        'ColumnWidth',{'1x',36,20});
    grpGL.Layout.Row = 7; grpGL.Layout.Column = [1 2];

    ddGroup = uidropdown(grpGL, ...
        'Items',{'All Datasets'}, ...
        'Value','All Datasets', ...
        'Editable','on', ...
        'FontSize',10, ...
        'Tooltip',['Filter by group. Type a new name and press Enter to create. ' ...
                   'Select a group to filter the list.'], ...
        'ValueChangedFcn',@onGroupChanged);
    ddGroup.Layout.Column = 1;

    btnAddToGroup = uibutton(grpGL,'Text','+Grp', ...
        'ButtonPushedFcn',@onAddToGroup, ...
        'FontSize',9, ...
        'Tooltip','Add selected dataset(s) to the current group');
    btnAddToGroup.Layout.Column = 2;

    btnRemoveFromGroup = uibutton(grpGL,'Text',char(10005), ...
        'ButtonPushedFcn',@onRemoveFromGroup, ...
        'FontSize',9, ...
        'Tooltip','Remove selected dataset(s) from the current group');
    btnRemoveFromGroup.Layout.Column = 3;

    btnAnimate = uibutton(tbGL,'Text',[char(9654) ' Animate'], ...
        'ButtonPushedFcn',@onToggleAnimation, ...
        'BackgroundColor',BTN_ANIMATE, ...
        'FontColor',[1 1 1], ...
        'Tooltip','Cycle through datasets as animation frames (2 fps). Click again to stop.');
    btnAnimate.Layout.Row = 8; btnAnimate.Layout.Column = 1;

    btnShortcuts = uibutton(tbGL,'Text','?  Shortcuts', ...
        'ButtonPushedFcn',@onShowShortcuts, ...
        'BackgroundColor',BTN_TOOL, ...
        'FontColor',[0.75 0.75 0.75], ...
        'FontSize',10, ...
        'Tooltip','Show keyboard shortcuts');
    btnShortcuts.Layout.Row = 8; btnShortcuts.Layout.Column = 2;

    btnSettings = uibutton(tbGL,'Text',[char(9881) '  Settings...'], ...
        'ButtonPushedFcn',@(~,~) onOpenSettings(), ...
        'BackgroundColor',BTN_TOOL, ...
        'FontColor',[0.85 0.85 0.85], ...
        'FontSize',10, ...
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
        'RowHeight', {24,'2x','1x',44,66,22,22,20}, ...
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

    % Colormap + Template selectors (row 4) — two stacked sub-rows
    styleGL = uigridlayout(ctrlGL,[2 4], ...
        'Padding',[0 0 0 0],'ColumnSpacing',2,'RowSpacing',2, ...
        'ColumnWidth',{'1x','1x','1x','1x'},'RowHeight',{18,18});
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

    % ── Template selector (Phase A) ─────────────────────────────────
    % Selects a built-in visual template (screen / aps / nature / thesis /
    % presentation / poster) or a user-saved template.  Changes font,
    % line width, marker size, tick direction, grid, etc. on the live
    % preview so the GUI is WYSIWYG with exported figures.
    lblTemplate = uilabel(styleGL,'Text','Template:','FontSize',10);
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

    % Row 8: Annotation mode + Style… + Plot Options button
    annotPlotGL = uigridlayout(ctrlGL,[1 3], ...
        'Padding',[0 0 0 0],'ColumnSpacing',3, ...
        'ColumnWidth',{'1x','1x','1x'});
    annotPlotGL.Layout.Row = 8;

    cbAnnotationMode = uicheckbox(annotPlotGL, ...
        'Text',    'Annotate', ...
        'Value',   false, ...
        'Tooltip', 'Click on the plot to add text annotations. Right-click to delete.', ...
        'ValueChangedFcn', @onAnnotationModeChanged);
    cbAnnotationMode.Layout.Column = 1;

    btnPlotStyle = uibutton(annotPlotGL,'Text','Style…', ...
        'ButtonPushedFcn',@(~,~) onOpenPlotStyleDialog(), ...
        'BackgroundColor',[0.35 0.40 0.55],'FontColor',[1 1 1], ...
        'FontSize',10, ...
        'Tooltip','Fine-grained visual overrides: font, line width, marker, grid, legend (Phase B)');
    btnPlotStyle.Layout.Column = 2;

    btnPlotOptions = uibutton(annotPlotGL,'Text',['Plot ' char(9662)], ...
        'ButtonPushedFcn',@onShowPlotOptionsMenu, ...
        'BackgroundColor',[0.22 0.35 0.55],'FontColor',[1 1 1], ...
        'FontSize',10, ...
        'Tooltip','Plot types, visualization options, and unit conversion');
    btnPlotOptions.Layout.Column = 3;

    % ── Right: preview axes ───────────────────────────────────────────────
    axPanel = uipanel(contentGL,'Title','Preview','FontSize',11);
    axPanel.Layout.Column = 3;
    axGL = uigridlayout(axPanel,[3 1],'Padding',[2 2 2 2],'RowSpacing',1, ...
        'RowHeight',{18,'1x',20});

    % ── Dynamic axes toolbar (right-aligned buttons, order from user prefs) ──
    % The toolbar is built/rebuilt by buildToolbar().  A single-row grid with
    % N+1 columns is created here; column widths are set dynamically.
    axToolbarGL = uigridlayout(axGL,[1 1],'Padding',[0 0 0 0],'ColumnSpacing',2);
    axToolbarGL.Layout.Row = 1;

    % ── Action registry — ALL available toolbar actions ────────────────────
    tbActions = struct('id', {}, 'label', {}, 'tooltip', {}, 'callback', {});
    tbActions(end+1) = struct('id','cursor',     'label',[char(8982) ' Cursor'],  ...
        'tooltip','Toggle data cursor — click to read (x,y), click again for delta', ...
        'callback',@(~,~) onToggleDataCursor([],[]));
    tbActions(end+1) = struct('id','autoscale',  'label','Auto',   ...
        'tooltip','Reset all axis limits to auto-scale', ...
        'callback',@(~,~) onAutoLimits([],[]));
    tbActions(end+1) = struct('id','grid',       'label','Grid',   ...
        'tooltip','Toggle grid lines on/off', ...
        'callback',@(~,~) onContextToggle('grid'));
    tbActions(end+1) = struct('id','legend',     'label','Legend', ...
        'tooltip','Toggle legend visibility', ...
        'callback',@(~,~) onToolbarLegendToggle([],[]));
    tbActions(end+1) = struct('id','copy',       'label','Copy',   ...
        'tooltip','Copy plot to clipboard', ...
        'callback',@(~,~) onCopyPlotToClipboard());
    tbActions(end+1) = struct('id','save',       'label','Save',   ...
        'tooltip','Export figure as PNG / PDF / SVG / EPS', ...
        'callback',@(~,~) onExportFigure([],[]));
    tbActions(end+1) = struct('id','zoomIn',     'label',[char(43) ' Zoom'],  ...
        'tooltip','Zoom in (set axis limits to visible range)', ...
        'callback',@(~,~) onZoomInToolbar());
    tbActions(end+1) = struct('id','zoomOut',    'label','Zoom Out', ...
        'tooltip','Zoom out one step', ...
        'callback',@(~,~) onZoomOutToolbar());
    tbActions(end+1) = struct('id','pan',        'label','Pan',    ...
        'tooltip','Enable pan mode on plot axes', ...
        'callback',@(~,~) onPanToolbar());
    tbActions(end+1) = struct('id','figBuilder', 'label','Figure Builder', ...
        'tooltip','Open the Figure Builder for publication-quality figures', ...
        'callback',@(~,~) onAdvancedFigureBuilder([],[]));
    tbActions(end+1) = struct('id','export',     'label','Export Data', ...
        'tooltip','Export active dataset data to CSV', ...
        'callback',@(~,~) onSaveCSV([],[]));
    tbActions(end+1) = struct('id','animate',    'label',[char(9654) ' Animate'], ...
        'tooltip','Animate dataset sequence', ...
        'callback',@(~,~) onToggleAnimation([],[]));
    tbActions(end+1) = struct('id','workspace', 'label',[char(9783) ' Data Table'], ...
        'tooltip','Open shared DataWorkspace (single instance; right-click for new window)', ...
        'callback',@(~,~) openLinkedDataWorkspace());
    tbActions(end+1) = struct('id','undo',        'label',[char(8617) ' Undo'], ...
        'tooltip','Undo last operation  [Ctrl+Z]', ...
        'callback',@(~,~) onUndo([],[]));
    tbActions(end+1) = struct('id','redo',        'label',[char(8618) ' Redo'], ...
        'tooltip','Redo last undone operation  [Ctrl+Y]', ...
        'callback',@(~,~) onRedo([],[]));
    tbActions(end+1) = struct('id','watchFile',   'label',[char(9711) ' Watch'], ...
        'tooltip','Toggle live file watch: auto-reload and replot when the source file changes on disk', ...
        'callback',@(~,~) onToggleWatchFile());

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

        % Actions
        uimenu(cmAxes, 'Text', 'Auto-Scale', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) onAutoLimits([], []));
        uimenu(cmAxes, 'Text', 'Set Axis Limits...', ...
            'MenuSelectedFcn', @(~,~) onSetAxisLimitsMenu());
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
        'FontSize', 10, 'FontColor', [0.85 0.85 0.85], ...
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
        'ColumnWidth', {320, '1x', 0, 210}, ...
        'RowHeight',   {110, '1x'}, ...
        'Padding',     [4 4 4 4], ...
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
    corrPanel = uipanel(analysisGL,'Title','Corrections','FontSize',11, ...
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
        'ColumnWidth',  {62,'1x',62,'1x'}, ...
        'Padding',      [4 4 4 4], ...
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
        'FontSize', 9);
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
        'Items',   {'Oe', 'T', 'mT', 'A/m'}, ...
        'Value',   'Oe', ...
        'Tooltip', 'Convert magnetic field x-axis units (Oe → T, mT, or A/m)', ...
        'ValueChangedFcn', @onMagUnitChanged);
    ddFieldUnit.Layout.Row = CROW.MAG_UNITS; ddFieldUnit.Layout.Column = 2;

    lblMomentUnit = uilabel(corrGL,'Text','Moment:','FontSize',10,'HorizontalAlignment','right');
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
        'FontColor',[0.75 0.75 0.75],'FontSize',9);
    btnApplyAll.Layout.Row = CROW.ACTIONS; btnApplyAll.Layout.Column = [1 2];

    btnUndo = uibutton(corrGL,'Text',[char(8617) ' Undo'], ...
        'ButtonPushedFcn',@(~,~) onUndo([],[]), ...
        'Tooltip','Nothing to undo  [Ctrl+Z]', ...
        'FontColor',[0.75 0.75 0.75],'FontSize',9);
    btnUndo.Layout.Row = CROW.ACTIONS; btnUndo.Layout.Column = 3;

    btnRedo = uibutton(corrGL,'Text',[char(8618) ' Redo'], ...
        'ButtonPushedFcn',@(~,~) onRedo([],[]), ...
        'Tooltip','Nothing to redo  [Ctrl+Y]', ...
        'FontColor',[0.75 0.75 0.75],'FontSize',9, ...
        'Enable','off');
    btnRedo.Layout.Row = CROW.ACTIONS; btnRedo.Layout.Column = 4;

    % Row REDO (29): Correction presets — dropdown + Save + Delete
    ddPreset = uidropdown(corrGL, ...
        'Items', [{'(presets)'}, bosonPlotter.correctionPresets.list()], ...
        'Value', '(presets)', 'FontSize', 9, ...
        'Tooltip', 'Load a saved set of correction parameters', ...
        'ValueChangedFcn', @(~,~) onDatasetMetaEdit('load-preset'));
    ddPreset.Layout.Row = CROW.REDO; ddPreset.Layout.Column = [1 2];

    btnSavePreset = uibutton(corrGL, 'Text', 'Save', 'FontSize', 9, ...
        'Tooltip', 'Save current correction settings as a named preset', ...
        'ButtonPushedFcn', @(~,~) onDatasetMetaEdit('save-preset'));
    btnSavePreset.Layout.Row = CROW.REDO; btnSavePreset.Layout.Column = 3;

    btnDeletePreset = uibutton(corrGL, 'Text', char(10005), 'FontSize', 9, ...
        'Tooltip', 'Delete the selected preset', ...
        'ButtonPushedFcn', @(~,~) onDatasetMetaEdit('delete-preset'));
    btnDeletePreset.Layout.Row = CROW.REDO; btnDeletePreset.Layout.Column = 4;

    % Row MASK: Mask Selection | Hide | Unmask All
    btnMaskSelect = uibutton(corrGL,'Text','Mask Selection', ...
        'ButtonPushedFcn',@onArmMaskSelection, ...
        'BackgroundColor',[0.60 0.15 0.15], ...
        'FontColor',BTN_FG,'FontSize',9, ...
        'Tooltip','Click & drag a rectangle on the plot to mask (exclude) data points inside the box');
    btnMaskSelect.Layout.Row = CROW.MASK; btnMaskSelect.Layout.Column = [1 2];

    btnToggleVis = uibutton(corrGL,'Text','Hide', ...
        'ButtonPushedFcn',@onToggleDatasetVisibility, ...
        'Tooltip','Hide/show the active dataset in the plot without removing it  [Space]', ...
        'FontColor',[0.75 0.75 0.75],'FontSize',9);
    btnToggleVis.Layout.Row = CROW.MASK; btnToggleVis.Layout.Column = 3;

    btnUnmaskAll = uibutton(corrGL,'Text','Unmask All', ...
        'ButtonPushedFcn',@onUnmaskAll, ...
        'BackgroundColor',BTN_TOOL, ...
        'FontColor',[0.75 0.75 0.75],'FontSize',9, ...
        'Tooltip','Restore all masked data points for the active dataset  [Ctrl+M]');
    btnUnmaskAll.Layout.Row = CROW.MASK; btnUnmaskAll.Layout.Column = 4;

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

    % ── Data Table contents (toolbar + filter bar + units + editable table) ──
    dataTableInnerGL = uigridlayout(dataTablePanel, [5 1], ...
        'RowHeight', {22, 22, 14, 26, '1x'}, 'Padding', [2 2 2 2], 'RowSpacing', 1);

    % Toolbar row
    tableBarGL = uigridlayout(dataTableInnerGL, [1 8], ...
        'ColumnWidth', {70, 70, 55, 50, 50, 50, '1x', 100}, ...
        'RowHeight', {'1x'}, ...
        'Padding', [2 0 2 0], 'ColumnSpacing', 3);
    tableBarGL.Layout.Row = 1;

    btnTableSaveAs = uibutton(tableBarGL, 'Text', 'Save As...', ...
        'ButtonPushedFcn', @onTableSaveAs, ...
        'BackgroundColor', BTN_EXPORT, 'FontColor', BTN_FG, ...
        'FontSize', 8, ...
        'Tooltip', 'Save edited table to a new CSV or Excel file');
    btnTableSaveAs.Layout.Column = 1;

    btnTableMask = uibutton(tableBarGL, 'Text', 'Mask Sel.', ...
        'ButtonPushedFcn', @onTableMaskSelected, ...
        'BackgroundColor', BTN_DANGER, 'FontColor', BTN_FG, ...
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

    btnOpenDW = uibutton(tableBarGL, 'Text', [char(9783) ' Data Table'], ...
        'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
        'FontSize', 8, ...
        'Tooltip', 'Open shared DataWorkspace (single instance)', ...
        'ButtonPushedFcn', @(~,~) openLinkedDataWorkspace());
    btnOpenDW.Layout.Column = 8;

    % ── Filter bar row ────────────────────────────────────────────────────
    % Layout: [label | edit field (stretch) | Filter btn | Clear btn]
    filterBarGL = uigridlayout(dataTableInnerGL, [1 4], ...
        'ColumnWidth', {30, '1x', 44, 40}, ...
        'RowHeight',   {'1x'}, ...
        'Padding', [2 0 2 0], 'ColumnSpacing', 3);
    filterBarGL.Layout.Row = 2;

    lblFilter = uilabel(filterBarGL, 'Text', 'Filter:', ...
        'FontSize', 8, 'FontColor', [0.75 0.75 0.75], ...
        'HorizontalAlignment', 'right');
    lblFilter.Layout.Column = 1; %#ok<NASGU>

    efFilter = uieditfield(filterBarGL, 'text', 'Value', '', ...
        'Placeholder', 'e.g. Temp > 300  or  between(x, 0, 1)', ...
        'FontSize', 8, ...
        'BackgroundColor', [0.17 0.17 0.17], 'FontColor', [0.92 0.92 0.92], ...
        'Tooltip', ['Filter rows by expression. Column names from labels, ' ...
                    '''x'' = X axis. Operators: > < >= <= == ~= & | ~. ' ...
                    'Functions: abs(), between(col,lo,hi). Press Enter to apply.'], ...
        'ValueChangedFcn', @(~,~) onFilterApply());
    efFilter.Layout.Column = 2;

    btnFilterApply = uibutton(filterBarGL, 'Text', 'Filter', ...
        'ButtonPushedFcn', @(~,~) onFilterApply(), ...
        'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
        'FontSize', 8, ...
        'Tooltip', 'Apply filter expression');
    btnFilterApply.Layout.Column = 3; %#ok<NASGU>

    btnFilterClear = uibutton(filterBarGL, 'Text', 'Clear', ...
        'ButtonPushedFcn', @(~,~) onFilterClear(), ...
        'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [0.8 0.8 0.8], ...
        'FontSize', 8, ...
        'Tooltip', 'Clear filter — show all rows');
    btnFilterClear.Layout.Column = 4; %#ok<NASGU>

    % Units row
    lblTableUnits = uilabel(dataTableInnerGL, 'Text', '', ...
        'FontSize', 8, 'FontColor', [0.5 0.7 0.5], ...
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
        'CellEditCallback', @onUnitsCellEdit, ...
        'CellSelectionCallback', @onUnitsCellSelection, ...
        'FontSize', 9, ...
        'BackgroundColor', [0.96 0.98 0.93], ...
        'ForegroundColor', [0.0 0.35 0.0]);
    tblUnits.Layout.Row = 4;

    % Editable data table (pure numeric data — big scroll-perf win)
    tblData = uitable(dataTableInnerGL, ...
        'Tag', 'BosonDataTable', ...
        'ColumnName', {'(no data)'}, ...
        'Data', [], ...
        'ColumnEditable', true, ...
        'CellEditCallback', @onTableCellEdit, ...
        'CellSelectionCallback', @onTableSelectionChanged, ...
        'FontSize', 9);

    % Right-click context menu for row-level masking (replaces the old
    % "Masked" column).  Selected rows are taken from appData.tableSelection
    % which onTableSelectionChanged maintains from the CellSelectionCallback.
    tblCtxMenu = uicontextmenu(fig);
    uimenu(tblCtxMenu, 'Text', 'Mask selected rows', ...
        'MenuSelectedFcn', @onTableMaskSelected);
    uimenu(tblCtxMenu, 'Text', 'Unmask selected rows', ...
        'MenuSelectedFcn', @onTableUnmaskSelected);
    uimenu(tblCtxMenu, 'Separator', 'on', 'Text', 'Unmask all', ...
        'MenuSelectedFcn', @onTableUnmaskAll);
    tblData.ContextMenu = tblCtxMenu;
    tblData.Layout.Row = 5;
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
        'Tooltip',['Reset View — clear manual axis limits and per-dataset' newline ...
                   'plot state (log/linear, grid, direction, 2D cmap/cLim)' newline ...
                   'so this dataset returns to auto defaults.']);
    btnAutoLimits.Layout.Row = 4; btnAutoLimits.Layout.Column = 2;

    ddLegendLoc = uidropdown(axLimGL, ...
        'Items', {'best','NE','NW','SE','SW','EastOutside','off'}, ...
        'Value', 'best', 'FontSize', 9, ...
        'Tooltip', 'Legend location ("off" hides it)', ...
        'ValueChangedFcn', @onToolbarLegendToggle);
    ddLegendLoc.Layout.Row = 4; ddLegendLoc.Layout.Column = 3;

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
        'Tooltip', 'Toggle advanced appearance options (title, labels, legend name, reference lines)', ...
        'ButtonPushedFcn', @(~,~) onToggleAxAppearance());
    btnAxMore.Layout.Row = 4; btnAxMore.Layout.Column = [5 6];

    % ── Save / Export panel (analysisGL col 3 — vertical, collapsible) ─────
    savePanel = uipanel(analysisGL,'Title','Save / Export','FontSize',10, ...
        'Scrollable','on');
    savePanel.Layout.Row = [1 2]; savePanel.Layout.Column = 4;

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

    saveToolsGL = uigridlayout(saveGL, [3 2], ...
        'RowHeight', {24, 24, 24}, 'ColumnWidth', {'1x','1x'}, ...
        'Padding', [0 0 0 0], 'RowSpacing', 2, 'ColumnSpacing', 3);
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
    btnClear2DMatrix.ButtonPushedFcn = @(~,~) onClear2DMatrix();

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

    % ── Static render context (allocated once, merged into rCtx_ each replot) ──
    rCtxStatic_.fig                         = fig;
    rCtxStatic_.efXMin                      = efXMin;
    rCtxStatic_.efXMax                      = efXMax;
    rCtxStatic_.efYMin                      = efYMin;
    rCtxStatic_.efYMax                      = efYMax;
    rCtxStatic_.efY2Min                     = efY2Min;
    rCtxStatic_.efY2Max                     = efY2Max;
    rCtxStatic_.axLimGL                     = axLimGL;
    rCtxStatic_.draw2DMap                   = @draw2DMap;
    rCtxStatic_.toggleY2Appearance          = @toggleY2Appearance;
    rCtxStatic_.applyAxisPrefix             = @applyAxisPrefix;
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
    % Scale / display
    ui.ddScaleX         = ddScaleX;
    ui.ddScaleY         = ddScaleY;
    ui.cbCountsPerSec   = cbCountsPerSec;
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
    ui.axLimGL          = axLimGL;
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
    ui.axLimPanel       = axLimPanel;
    % 2D map controls
    ui.cbMap2DQSpace    = cbMap2DQSpace;
    ui.btnArcIntegrate  = btnArcIntegrate;
    ui.lblMap2DInfo     = lblMap2DInfo;
    % Save path (hidden field)
    ui.efSavePath       = efSavePath;
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
    apacCb_.updateUndoButtons          = @updateUndoButtons;

    % ── Callback struct for onApplyCorrections ────────────────────────────
    corrCb_ = struct();
    corrCb_.onPlot                  = @(varargin) onPlot([],[]);
    corrCb_.setStatus               = @setStatus;
    corrCb_.logGUIError             = @logGUIError;
    corrCb_.markCorrectionsDirty    = @markCorrectionsDirty;
    corrCb_.updateApplyButtonStyle  = @updateApplyButtonStyle;
    corrCb_.recordAction            = @recordAction;
    corrCb_.pushUndoCorrectionEntry = @pushUndoCorrectionEntry;
    corrCb_.updateUndoButtons       = @updateUndoButtons;
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
    api.undo                = @() onUndo([],[]);
    api.redo                = @() onRedo([],[]);
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
    api.toggleAxAppearance  = @() onToggleAxAppearance();
    api.getAxAppearanceState = @() struct( ...
        'collapsed',        appData.sectionCollapsed.axAppearance, ...
        'advRowHeight',     axLimGL.RowHeight{AXLIM_ADV_ROW}, ...
        'analysisRow1Height', analysisGL.RowHeight{1});
    api.showDecomposition   = @() peakCb.onShowDecomposition([],[]);
    api.getTableData        = @() struct( ...
        'data',     {tblData.Data}, ...
        'colNames', {tblData.ColumnName}, ...
        'working',  appData.tableWorkingCopy, ...
        'units',    {appData.tableUnits});
    api.descriptiveStats    = @() onDescriptiveStats([],[]);

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
        startDir = guiTernary(isempty(appData.lastDir), pwd, appData.lastDir);
        [fnames, fpath] = uigetfile( ...
            {'*.dat;*.csv;*.tsv;*.txt;*.xlsx;*.xls;*.xlsm;*.xlsb;*.ods;*.raw;*.brml;*.xrdml;*.refl;*.pnr;*.datA;*.datB;*.datC;*.datD;*.data;*.datb;*.datc;*.datd;*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff;*.bcf;*.dm3;*.dm4;*.mrc;*.mrcs;*.ser;*.spm;*.000;*.001', ...
                'All supported formats'; ...
             '*.xrdml;*.raw;*.brml', 'XRD files (*.xrdml, *.raw, *.brml)'; ...
             '*.dat;*.datA;*.datB;*.datC;*.datD', 'VSM / PPMS / Neutron (*.dat, *.datA-D)'; ...
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
                         '.raw','.brml','.xrdml', ...
                         '.refl','.pnr', ...
                         '.datA','.datB','.datC','.datD', ...
                         '.data','.datb','.datc','.datd', ...
                         '.jpg','.jpeg','.png','.bmp','.gif', ...
                         '.tif','.tiff','.bcf','.dm3','.dm4', ...
                         '.mrc','.mrcs','.ser','.spm', ...
                         '.000','.001'};
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
            fprintf(2, '[BosonPlotter] DropFcn error: %s\n', ME.message);
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

        excelExts = {'.xlsx','.xls','.xlsm','.xlsb','.ods'};
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
                        appData.model.addDataset(data, fp, parserName);
                        nLoaded = nLoaded + 1;
                        addToRecentFiles(fp);
                    catch ME
                        fprintf(2, '\n[BosonPlotter] Import error (%s [%s]): %s\n', ...
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

                % Template matching: auto-apply or suggest overrides
                try
                    [tmpl, conf] = templates.TemplateEngine.match(data, Type='tabular');
                    if conf >= 0.8 && ~isempty(tmpl)
                        data = templates.TemplateEngine.apply(data, tmpl);
                        setStatus(sprintf('Applied template: %s', tmpl.name));
                    elseif conf >= 0.4 && ~isempty(tmpl)
                        sel = uiconfirm(fig, ...
                            sprintf('Suggested template: "%s" (%.0f%% match)\nApply it?', tmpl.name, conf*100), ...
                            'Template Suggestion', ...
                            'Options', {'Apply', 'Edit...', 'Ignore'}, ...
                            'DefaultOption', 'Apply', 'CancelOption', 'Ignore');
                        if strcmp(sel, 'Apply')
                            data = templates.TemplateEngine.apply(data, tmpl);
                        elseif strcmp(sel, 'Edit...')
                            edited = templates.ColumnMapper(data, Template=tmpl, ParentFig=fig);
                            if ~isempty(edited), data = edited; end
                        end
                    elseif conf < 0.4 && ismember(parserName, {'importCSV', 'importExcel'})
                        % Generic parsers: offer Column Mapper for unknown layouts
                        edited = templates.ColumnMapper(data, ParentFig=fig);
                        if ~isempty(edited), data = edited; end
                    end
                catch ME_tmpl
                    % Template matching is non-critical — log and continue
                    fprintf(2, '[BosonPlotter] Template match warning: %s\n', ME_tmpl.message);
                end

                ds = buildDs(fp, data, parserName);
                appData.datasets{end+1} = ds;
                appData.model.addDataset(data, fp, parserName);
                nLoaded = nLoaded + 1;
                addToRecentFiles(fp);
            catch ME
                fprintf(2, '\n[BosonPlotter] Import error (%s): %s\n', fnBase, ME.message);
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
        % (Re)start autosave timer now that datasets exist
        if ~headless
            bosonPlotter.autosave.start(appData);
        end
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
        appData.model.addDataset(ds.data, ds.filepath, ds.parserName);
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
            yResult = bosonPlotter.safeEvalMathExpr(expr, vars);
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
            appData.model.addDataset(ds.data, ds.filepath, ds.parserName);
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
        if isempty(indicesToRemove), return; end

        % Confirm when removing multiple datasets
        if numel(indicesToRemove) > 1 && ~headless
            answer = uiconfirm(fig, ...
                sprintf('Remove %d selected datasets?', numel(indicesToRemove)), ...
                'Confirm Remove', 'Options', {'Remove', 'Cancel'}, ...
                'DefaultOption', 'Remove', 'CancelOption', 'Cancel');
            if strcmp(answer, 'Cancel'), return; end
        end

        % Sort indices in descending order so removal doesn't affect remaining indices
        indicesToRemove = sort(indicesToRemove, 'descend');

        % Remove selected datasets (also from shared model)
        for ri = 1:numel(indicesToRemove)
            if indicesToRemove(ri) <= appData.model.count()
                appData.model.removeDataset(indicesToRemove(ri));
            end
        end
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
            btnAnimate.BackgroundColor = BTN_ANIMATE;
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
    %SAVEAXISLIMSTOACTIVEDATASET  Persist axis limits + plot-view state.
    %  Called before switching datasets so each dataset remembers its own
    %  zoom, axis scale (linear/log), grid/direction, and 2D map state.
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

        % Capture plot-view state so log/linear, grid, and axis direction
        % survive a dataset toggle. Reading from live axes catches user
        % changes made via context menu (grid/invert) that don't update
        % a dropdown.
        ps = struct();
        ps.xScale  = ddScaleX.Value;
        ps.yScale  = ddScaleY.Value;
        ps.y2Scale = ddScaleY2.Value;
        if ~isempty(ax) && isvalid(ax)
            ps.gridX = ax.XGrid;
            ps.gridY = ax.YGrid;
            ps.xDir  = ax.XDir;
            ps.yDir  = ax.YDir;
        end
        % 2D map state — widgets always exist; values are still read for
        % non-2D parsers so user overrides persist if they later load a
        % 2D dataset into the same session.
        if ~isempty(ddMap2DCmap) && isvalid(ddMap2DCmap)
            ps.map2DCmap  = ddMap2DCmap.Value;
            ps.map2DScale = ddMap2DScale.Value;
            ps.map2DCMin  = efMap2DCMin.Value;
            ps.map2DCMax  = efMap2DCMax.Value;
        end
        appData.datasets{appData.activeIdx}.plotState = ps;
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
        dsColors    = zeros(N, 3);  % resolved plot colors for swatch styling
        defaultCols = plotting.lineColors(N);
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
            noteTag = '';
            if isfield(dsI, 'notes') && ~isempty(dsI.notes)
                noteTag = [' ' char(9998)];  % ✎ pencil
            end
            if isfield(dsI,'color') && ~isempty(dsI.color)
                dsColors(i,:) = dsI.color;
            else
                dsColors(i,:) = defaultCols(i,:);
            end
            allItems{i} = sprintf('%s [%d]  %s  %s%s', char(9679), i, badgeStr, displayStr, noteTag);
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

        % Apply color swatches via uistyle per visible item
        removeStyle(lbDatasets);
        for si = 1:numel(visIdx)
            s = uistyle('FontColor', dsColors(visIdx(si),:));
            addStyle(lbDatasets, s, 'item', si);
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
        % Abort any in-progress box integration selection
        if ~isempty(appData.boxIntPatch) && isvalid(appData.boxIntPatch)
            delete(appData.boxIntPatch);
        end
        appData.boxIntPatch       = [];
        appData.boxIntStartPt     = [];
        appData.boxIntMode        = false;
        clearBoxPreview();
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
        btnFitBG.BackgroundColor = BTN_INTERACT;
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

        % ── Customise Toolbar button ──
        btnCustomTb = uibutton(sGL,'Text',[char(9881) '  Customise Toolbar...'], ...
            'FontSize',12, ...
            'Tooltip','Choose which buttons appear in the axes toolbar', ...
            'ButtonPushedFcn',@(~,~) onCustomiseToolbar());
        btnCustomTb.Layout.Row = 4; btnCustomTb.Layout.Column = [1 2];

        % ── Close button ──
        btnClose = uibutton(sGL,'Text','Close', ...
            'FontSize',12, ...
            'ButtonPushedFcn',@(~,~) delete(settingsFig));
        btnClose.Layout.Row = 5; btnClose.Layout.Column = [1 2];

        bosonPlotter.applyDialogTheme(settingsFig, appData.theme);
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
    %BUILDTOOLBAR  Clear and repopulate parentGL with buttons for each action in config.
    %
    %   parentGL  — uigridlayout (1 row) that hosts the toolbar buttons
    %   config    — {1×N} cell of action IDs; empty → use factory default
    %   registry  — struct array with .id / .label / .tooltip / .callback
    %   btnColor  — [1×3] background colour for buttons

        if isempty(config)
            config = bosonPlotter.toolbarDefaultConfig();
        end

        % Keep only IDs present in the registry
        allRegIds = {registry.id};
        config    = config(ismember(config, allRegIds));
        if isempty(config)
            config = bosonPlotter.toolbarDefaultConfig();
            config = config(ismember(config, allRegIds));
        end

        nBtns = numel(config);

        % Remove all existing children (buttons + spacer)
        existingChildren = parentGL.Children;
        for ci = 1:numel(existingChildren)
            if isvalid(existingChildren(ci))
                delete(existingChildren(ci));
            end
        end

        % Set column widths: spacer | btn1 | btn2 | …
        % Assigning ColumnWidth resizes the grid automatically.
        BTN_W = 55;
        colWidths = [{'1x'}, repmat({BTN_W}, 1, nBtns)];
        parentGL.ColumnWidth = colWidths;

        % Spacer label
        spacer = uilabel(parentGL, 'Text', '');
        spacer.Layout.Column = 1;

        % Create a button for each action
        for bi = 1:nBtns
            actId = config{bi};
            idx   = find(strcmp(allRegIds, actId), 1);
            if isempty(idx), continue; end
            act = registry(idx);
            btn = uibutton(parentGL, 'Text', act.label, ...
                'BackgroundColor', btnColor, ...
                'FontColor',       [0.85 0.85 0.85], ...
                'FontSize',        9, ...
                'Tooltip',         act.tooltip, ...
                'ButtonPushedFcn', act.callback);
            btn.Layout.Column = bi + 1;
        end
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
        if isDark && isfield(th, 'gridColor')
            ax.GridColor = th.gridColor;
        else
            ax.GridColor = [0.15 0.15 0.15];
        end

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
                'fieldUnit', 'Oe', 'momentUnit', 'emu');
            corrParams = bosonPlotter.correctionParams(ds, uiVals);
            bgArgs = {};
            if cbSubtractBG.Value && ~isempty(appData.bgDataset)
                bgArgs = {'BgDataset', appData.bgDataset, ...
                          'BgInterp', ddBGInterp.Value};
            end
            corrData = bosonPlotter.applyCorrections(d, corrParams, bgArgs{:});

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
            try
                appData.model.updateDataset(di, ds);
            catch
            end
        end

        % Refresh plot
        fig.Pointer = 'arrow';
        setStatus(sprintf('Corrections applied to all %d datasets.', numel(appData.datasets)));
        onPlot([],[]);
        uialert(fig, sprintf('Corrections applied to all %d datasets.', ...
            numel(appData.datasets)), 'Batch Apply Complete');
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
        ddMomentUnit.Value   = 'emu';
        ddFieldUnit.Value    = 'Oe';
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
            ds.momentUnit    = 'emu';
            ds.fieldUnit     = 'Oe';
            ds.unitSystem    = 'CGS';
            ds.peaks         = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
                                      'xRange',{},'status',{},'bg',{},'model',{},'eta',{});
            appData.datasets{appData.activeIdx} = ds;
            appData.selectedPeakIdx = 0;
        end

        cancelInteractions();
        peakCb.refreshPeakTable();
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
        ddMomentUnit.Value   = guiTernary(isfield(ds,'momentUnit'),   ds.momentUnit,   'emu');
        ddFieldUnit.Value    = guiTernary(isfield(ds,'fieldUnit'),    ds.fieldUnit,    'Oe');
        ddUnitSystem.Value   = guiTernary(isfield(ds,'unitSystem'),   ds.unitSystem,   'CGS');

        % Refresh the plot
        onPlot([],[]);
    end

    % ════════════════════════════════════════════════════════════════════
    %  UNDO / REDO (UndoManager-based)
    % ════════════════════════════════════════════════════════════════════

    function onUndo(~,~)
    %ONUNDO  Execute the topmost undo entry from the UndoManager.
        entry = appData.undoMgr.undo();
        if isempty(entry)
            setStatus('Nothing to undo.');
            return;
        end
        setStatus(['Undid: ' entry.label]);
        updateUndoButtons();
        onPlot([],[]);
    end

    function onRedo(~,~)
    %ONREDO  Re-apply the next redo entry from the UndoManager.
        entry = appData.undoMgr.redo();
        if isempty(entry)
            setStatus('Nothing to redo.');
            return;
        end
        setStatus(['Redid: ' entry.label]);
        updateUndoButtons();
        onPlot([],[]);
    end

    function updateUndoButtons()
    %UPDATEUNDOBUTTONS  Sync undo/redo button enabled state and tooltips.
        if appData.undoMgr.canUndo()
            btnUndo.Enable  = 'on';
        else
            btnUndo.Enable  = 'off';
        end
        if appData.undoMgr.canRedo()
            btnRedo.Enable  = 'on';
        else
            btnRedo.Enable  = 'off';
        end
        btnUndo.Tooltip = [appData.undoMgr.undoLabel() '  [Ctrl+Z]'];
        btnRedo.Tooltip = [appData.undoMgr.redoLabel() '  [Ctrl+Y]'];
    end

    function pushUndoCorrectionEntry(dsIdx, prevState, newState, labelStr)
    %PUSHUNDOCORRECTIONENTRY  Push a correction undo entry for dataset dsIdx.
    %
    %   prevState / newState are structs capturing the full correction state
    %   of the dataset before and after the operation.
        appData.undoMgr.push(struct( ...
            'type',  'correction', ...
            'label', labelStr, ...
            'undo',  @() restoreCorrectionState(dsIdx, prevState), ...
            'redo',  @() restoreCorrectionState(dsIdx, newState)));
        updateUndoButtons();
    end

    function restoreCorrectionState(dsIdx, s)
    %RESTORECORRECTIONSTATE  Apply a saved correction state struct back to a dataset.
        if dsIdx < 1 || dsIdx > numel(appData.datasets)
            return;
        end
        ds = appData.datasets{dsIdx};
        ds.corrData      = s.corrData;
        if isfield(s,'mask'),          ds.mask          = s.mask;          end
        ds.xOff          = s.xOff;
        ds.yOff          = s.yOff;
        ds.bgSlope       = s.bgSlope;
        ds.bgInt         = s.bgInt;
        if isfield(s,'bgPoly'),        ds.bgPoly        = s.bgPoly;        end
        ds.smoothEnabled = s.smoothEnabled;
        ds.smoothWindow  = s.smoothWindow;
        ds.smoothMethod  = s.smoothMethod;
        if isfield(s,'xTrimMin'),      ds.xTrimMin      = s.xTrimMin;      end
        if isfield(s,'xTrimMax'),      ds.xTrimMax      = s.xTrimMax;      end
        if isfield(s,'normMethod'),    ds.normMethod    = s.normMethod;    end
        if isfield(s,'derivativeMode'),ds.derivativeMode= s.derivativeMode;end
        if isfield(s,'sampleMass'),    ds.sampleMass    = s.sampleMass;    end
        if isfield(s,'sampleWidth'),   ds.sampleWidth   = s.sampleWidth;   end
        if isfield(s,'sampleHeight'),  ds.sampleHeight  = s.sampleHeight;  end
        if isfield(s,'dimUnit'),       ds.dimUnit       = s.dimUnit;       end
        if isfield(s,'sampleThick'),   ds.sampleThick   = s.sampleThick;   end
        if isfield(s,'thickUnit'),     ds.thickUnit     = s.thickUnit;     end
        if isfield(s,'momentUnit'),    ds.momentUnit    = s.momentUnit;    end
        if isfield(s,'fieldUnit'),     ds.fieldUnit     = s.fieldUnit;     end
        if isfield(s,'unitSystem'),    ds.unitSystem    = s.unitSystem;    end
        % Migration: old sessions used 'Oe (raw)' / 'emu (raw)' as the
        % un-converted state; the "(raw)" suffix was dropped in 2026-04.
        if isfield(ds,'fieldUnit')  && strcmp(ds.fieldUnit,  'Oe (raw)'),  ds.fieldUnit  = 'Oe';  end
        if isfield(ds,'momentUnit') && strcmp(ds.momentUnit, 'emu (raw)'), ds.momentUnit = 'emu'; end
        appData.datasets{dsIdx} = ds;
        try
            appData.model.updateDataset(dsIdx, ds);
        catch
        end

        % Sync UI widgets only when this is the active dataset
        if dsIdx == appData.activeIdx
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
            if isfield(ds,'derivativeMode')
                ddDerivative.Value = ds.derivativeMode;
            end
            efSampleMass.Value   = guiTernary(isfield(ds,'sampleMass'),   ds.sampleMass,   0);
            efSampleWidth.Value  = guiTernary(isfield(ds,'sampleWidth'),  ds.sampleWidth,  0);
            efSampleHeight.Value = guiTernary(isfield(ds,'sampleHeight'), ds.sampleHeight, 0);
            ddDimUnit.Value      = guiTernary(isfield(ds,'dimUnit'),      ds.dimUnit,      'mm');
            efSampleThick.Value  = guiTernary(isfield(ds,'sampleThick'),  ds.sampleThick,  0);
            ddThickUnit.Value    = guiTernary(isfield(ds,'thickUnit'),    ds.thickUnit,    'nm');
            ddMomentUnit.Value   = guiTernary(isfield(ds,'momentUnit'),   ds.momentUnit,   'emu');
            ddFieldUnit.Value    = guiTernary(isfield(ds,'fieldUnit'),    ds.fieldUnit,    'Oe');
            ddUnitSystem.Value   = guiTernary(isfield(ds,'unitSystem'),   ds.unitSystem,   'CGS');
        end
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
    %UPDATESMOOTHPREVIEW  Recompute and redraw the dashed smooth preview line.
        clearSmoothPreview();
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        if ~cbSmooth.Value, return; end

        ds = appData.datasets{appData.activeIdx};
        d  = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        if isempty(d) || isempty(d.values), return; end

        xVec = double(d.time);
        yVec = d.values(:, 1);  % preview on first Y column only

        win  = max(1, round(efSmoothWin.Value));
        % Map GUI dropdown labels to smoothData 'Method' values (lowercase)
        persistent methMap
        if isempty(methMap)
            methMap = containers.Map( ...
                {'Moving','Gaussian','Savitzky-Golay'}, ...
                {'moving','gaussian','savitzky-golay'});
        end
        methKey = ddSmoothMethod.Value;
        if isKey(methMap, methKey)
            methVal = methMap(methKey);
        else
            methVal = 'moving';
        end
        try
            ySmooth = utilities.smoothData(yVec, 'Method', methVal, 'Window', win);
        catch
            return;  % silently skip if smoothData fails (e.g. insufficient data)
        end

        hold(ax, 'on');
        appData.smoothPreviewLine = plot(ax, xVec, ySmooth, ...
            '--', 'Color', [0.2 0.7 1.0], 'LineWidth', 1.5, ...
            'Tag', 'GUISmoothPreview', 'HandleVisibility', 'off');
        hold(ax, 'off');
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
            fprintf(2, '\n[BosonPlotter] Save error: %s\n', ME.message);
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
    %   1. Magnetometry unit conversion: multiplies .time / .values by the
    %      appropriate factor to convert Oe/emu into the user's requested
    %      field/moment unit, AND updates the corresponding labels.
    %   2. SI axis prefix scaling: multiplies .time and .values by the
    %      prefix factors currently active on the preview axes (e.g. kilo = 1e-3).
    %
    %   NEVER mutates the input dataset (ds.data / ds.corrData).  The
    %   argument `d` is a COPY created by the caller before calling this
    %   function — we scale that copy and hand it back to the exporter.

        % ── 1. Magnetometry unit conversion (values + labels) ─────────
        % Same helper as renderPlot so the exported file matches the
        % preview byte-for-byte.  Removed the old ~isempty(corrData)
        % gate so raw data exports correctly too.
        isMag = ismember(guiTernary(isfield(ds,'parserName'), ds.parserName, ''), ...
                    {'importQDVSM','importPPMS','importMPMS','importLakeShore'});
        if isMag
            fu = guiTernary(isfield(ds,'fieldUnit'),  ds.fieldUnit,  'Oe');
            mu = guiTernary(isfield(ds,'momentUnit'), ds.momentUnit, 'emu');
            if ~strcmp(fu, 'Oe') || ~strcmp(mu, 'emu')
                sampleMass = guiTernary(isfield(ds,'sampleMass'), ds.sampleMass, 0);
                sampleVol  = computeSampleVolumeForExport(ds);

                % ── Field / x-axis ──
                xU = '';
                if isfield(d,'metadata') && isfield(d.metadata,'xColumnUnit')
                    xU = char(d.metadata.xColumnUnit);
                end
                if strcmpi(xU, 'Oe') && ~strcmp(fu, 'Oe') && isnumeric(d.time)
                    [xNew, ~, xuNew, ~, wX] = utilities.convertMagUnits( ...
                        d.time(:), zeros(numel(d.time),1), ...
                        'FromField', 'Oe', 'ToField', fu);
                    if isempty(wX)
                        d.time = reshape(xNew, size(d.time));
                        d.metadata.xColumnUnit = xuNew;
                    end
                end

                % ── Moment / y-columns (per column) ──
                if ~strcmp(mu, 'emu') && isfield(d,'units') && iscell(d.units)
                    for k = 1:numel(d.units)
                        if k > size(d.values, 2), break; end
                        if strcmpi(char(d.units{k}), 'emu')
                            [~, yNew, ~, yuNew, wY] = utilities.convertMagUnits( ...
                                zeros(size(d.values,1),1), d.values(:,k), ...
                                'FromMoment', 'emu', 'ToMoment', mu, ...
                                'SampleMass', sampleMass, 'SampleVolume', sampleVol);
                            if isempty(wY)
                                d.values(:,k) = yNew;
                                d.units{k} = yuNew;
                            else
                                % Stop trying the rest — same warning
                                break;
                            end
                        end
                    end
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

    function v = computeSampleVolumeForExport(ds)
    %COMPUTESAMPLEVOLUMEFOREXPORT  Sample volume in cm³ from stored dimensions.
    %   Mirror of the helper inside +bosonPlotter/renderPlot.m so the
    %   export path and the live preview path agree on volume calculation.
    %   Returns 0 when any dimension is missing — caller treats this as
    %   "volume unavailable" and skips the conversion with a warning.
        v = 0;
        w = guiTernary(isfield(ds,'sampleWidth')  && isnumeric(ds.sampleWidth),  double(ds.sampleWidth),  0);
        h = guiTernary(isfield(ds,'sampleHeight') && isnumeric(ds.sampleHeight), double(ds.sampleHeight), 0);
        t = guiTernary(isfield(ds,'sampleThick')  && isnumeric(ds.sampleThick),  double(ds.sampleThick),  0);
        if w <= 0 || h <= 0 || t <= 0, return; end

        dimU = '';
        if isfield(ds,'dimUnit'), dimU = char(ds.dimUnit); end
        switch lower(dimU)
            case 'mm', dimToCm = 0.1;
            case 'cm', dimToCm = 1.0;
            otherwise, dimToCm = 0.1;
        end

        thkU = '';
        if isfield(ds,'thickUnit'), thkU = char(ds.thickUnit); end
        switch lower(thkU)
            case 'nm',                   thkToCm = 1e-7;
            case {char(197), 'a', 'ang'}, thkToCm = 1e-8;   % Å
            otherwise,                   thkToCm = 1e-7;
        end

        v = (w * dimToCm) * (h * dimToCm) * (t * thkToCm);
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
    %SAVECONSOLIDATEDNEUTRONCSV  Delegates to bosonPlotter.saveConsolidatedNeutronCSV.
        bosonPlotter.saveConsolidatedNeutronCSV(activeDs, fp, fmt, appData.datasets);
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
            fprintf(2, '\n[BosonPlotter] HDF5 export error: %s\n', ME.message);
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
    %APPLYAXESPLOTSTATE  Post-plot pass: restore per-dataset grid/XDir/YDir.
    %  The scale dropdowns and 2D widgets drive renderPlot via their
    %  ValueChangedFcn; grid and axis-direction live on the axes object
    %  directly and need to be re-applied after each draw.
        if isempty(ax) || ~isvalid(ax), return; end
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        ds = appData.datasets{appData.activeIdx};
        if ~isfield(ds, 'plotState') || ~isstruct(ds.plotState), return; end
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
        try
            appData.model.addDataset(newDs.data, newDs.filepath, newDs.parserName);
        catch
        end
        rebuildDatasetList(numel(appData.datasets));
        updateControlsForActiveDataset();
        fprintf('[BosonPlotter] Line-cut added: %s — %s\n', [fn fext], cutLabel);
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
    %ONARCINTBUTTON  Open arc-integration dialog and extract I(|Q|) profile.
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds = appData.datasets{appData.activeIdx};
        if ~is2DDataset(ds), return; end
        map = ds.data.metadata.parserSpecific.map2D;
        if ~isfield(map, 'Qx')
            uialert(fig, 'Arc integration requires Q-space coordinates (wavelength must be in the file metadata).', ...
                'No Q-space Data');
            return;
        end

        % Compute Q-radius range for defaults
        Qrad = hypot(map.Qx, map.Qz);
        qMin = min(Qrad(:));  qMax = max(Qrad(:));
        nDefault = min(100, max(20, round(max(size(map.intensity)) / 2)));

        % Build dialog
        dlgFig = uifigure('Name', 'Arc Integration', ...
            'Position', [100 100 320 280], 'Resize', 'off');
        dlgFig.CloseRequestFcn = @(~,~) delete(dlgFig);
        scr = get(0, 'ScreenSize');
        dlgFig.Position(1) = round((scr(3) - dlgFig.Position(3)) / 2);
        dlgFig.Position(2) = round((scr(4) - dlgFig.Position(4)) / 2);
        dlgGL = uigridlayout(dlgFig, [7 2], ...
            'RowHeight',    {22, 22, 22, 22, 22, 22, 30}, ...
            'ColumnWidth',  {120, '1x'}, ...
            'Padding', [10 10 10 10], 'RowSpacing', 6);

        uilabel(dlgGL, 'Text', 'Q min:', 'HorizontalAlignment', 'right');
        efQMin = uieditfield(dlgGL, 'numeric', 'Value', qMin, ...
            'Limits', [0 Inf], 'ValueDisplayFormat', '%.4f', ...
            'Tooltip', sprintf('Minimum |Q| (%s^{-1})', char(197)));

        uilabel(dlgGL, 'Text', 'Q max:', 'HorizontalAlignment', 'right');
        efQMax = uieditfield(dlgGL, 'numeric', 'Value', qMax, ...
            'Limits', [0 Inf], 'ValueDisplayFormat', '%.4f', ...
            'Tooltip', sprintf('Maximum |Q| (%s^{-1})', char(197)));

        uilabel(dlgGL, 'Text', 'Num bins:', 'HorizontalAlignment', 'right');
        efNBins = uieditfield(dlgGL, 'numeric', 'Value', nDefault, ...
            'Limits', [5 2000], 'Tooltip', 'Number of radial Q bins');

        uilabel(dlgGL, 'Text', 'Sector min (deg):', 'HorizontalAlignment', 'right');
        efSectorMin = uieditfield(dlgGL, 'numeric', 'Value', 0, ...
            'Limits', [-180 360], 'Tooltip', 'Azimuthal start angle (0 = +Qx axis, CCW)');

        uilabel(dlgGL, 'Text', 'Sector max (deg):', 'HorizontalAlignment', 'right');
        efSectorMax = uieditfield(dlgGL, 'numeric', 'Value', 360, ...
            'Limits', [-180 360], 'Tooltip', 'Azimuthal end angle (360 = full circle)');

        uilabel(dlgGL, 'Text', 'Integration:', 'HorizontalAlignment', 'right');
        ddMode = uidropdown(dlgGL, 'Items', {'Sum', 'Mean'}, 'Value', 'Sum', ...
            'Tooltip', 'Sum: total counts per bin. Mean: average per contributing pixel.');

        btnGo = uibutton(dlgGL, 'Text', 'Integrate', ...
            'BackgroundColor', [0.40 0.25 0.55], 'FontColor', [1 1 1], ...
            'ButtonPushedFcn', @(~,~) doArcInt());
        btnGo.Layout.Row = 7; btnGo.Layout.Column = [1 2];

        function doArcInt()
            params.qMin = efQMin.Value;
            params.qMax = efQMax.Value;
            params.nBins = round(efNBins.Value);
            params.sectorMin = efSectorMin.Value;
            params.sectorMax = efSectorMax.Value;
            params.mode = ddMode.Value;
            delete(dlgFig);
            extract2DArcIntegral(params);
        end
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
        delete(findall(ax, '-regexp', 'Tag', ...
            '^(curveFitOverlay|curveFitLabel|GUIPeakDecomp|integrationShade|integrationEdge)$'));
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
        drawToAxes(tmpAx);
        copygraphics(tmpFig, 'Resolution', 200);
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
    %ONAUTOLIMITS  Reset View — clear axis limits and per-dataset plot
    %  state so the active dataset returns to parser-aware auto defaults
    %  (log/linear, grid, axis direction, 2D map settings).
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
        saveAxisLimsToActiveDataset();
        updateControlsForActiveDataset();   % re-pull parser defaults
        onPlot([],[]);
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

    function onMouseHover(~,~)
    %ONMOUSEHOVER  Update x,y readout and set resize cursor near panel borders.
    %  Fires continuously while the mouse moves over the figure in idle (non-drag) mode.

        % -- Panel resize border detection: update cursor and store hover direction --
        dir = detectResizeBorder();
        appData.panelResizeDir = dir;
        if     any(strcmp(dir, {'h_row12', 'h_axdata'})), fig.Pointer = 'top';
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
                    executeFixedBoxIntegration(x0, y0);
                else
                    % Free-draw mode: drag to define box corners
                    appData.boxIntStartPt = [x0, y0];
                    fig.WindowButtonMotionFcn = @onBoxIntMove;
                    fig.WindowButtonUpFcn     = @onBoxIntUp;
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

    function onBoxIntMove(~,~)
    %ONBOXINTMOVE  Update the box-integration rubber-band rectangle while dragging.
        if isempty(appData.boxIntStartPt), return; end
        cp = ax.CurrentPoint;
        x1 = cp(1,1);  y1 = cp(1,2);
        x0 = appData.boxIntStartPt(1);
        y0 = appData.boxIntStartPt(2);
        xLo = min(x0,x1);  xHi = max(x0,x1);
        yLo = min(y0,y1);  yHi = max(y0,y1);
        if ~isempty(appData.boxIntPatch) && isvalid(appData.boxIntPatch)
            set(appData.boxIntPatch, ...
                'XData', [xLo xHi xHi xLo xLo], ...
                'YData', [yLo yLo yHi yHi yLo]);
        else
            hold(ax,'on');
            appData.boxIntPatch = patch(ax, ...
                [xLo xHi xHi xLo xLo], [yLo yLo yHi yHi yLo], ...
                'k', ...
                'FaceAlpha',       0, ...
                'EdgeColor',       [0.65 0.20 0.85], ...
                'LineStyle',       '--', ...
                'LineWidth',       2.5, ...
                'Tag',             'GUIBoxIntBox', ...
                'HandleVisibility','off');
            hold(ax,'off');
        end
    end

    function onBoxIntUp(~,~)
    %ONBOXINTUP  Finalise box-integration selection and extract integrated profile.
        fig.WindowButtonMotionFcn = @onMouseHover;
        fig.WindowButtonUpFcn     = '';
        if isempty(appData.boxIntStartPt)
            return;
        end
        cp = ax.CurrentPoint;
        x1 = cp(1,1);  y1 = cp(1,2);
        x0 = appData.boxIntStartPt(1);
        y0 = appData.boxIntStartPt(2);
        % Remove rubber-band rectangle
        if ~isempty(appData.boxIntPatch) && isvalid(appData.boxIntPatch)
            delete(appData.boxIntPatch);
        end
        appData.boxIntPatch   = [];
        appData.boxIntStartPt = [];
        appData.boxIntMode    = false;
        % Minimum drag threshold (1% of axis span in both directions)
        xDrag = abs(x1 - x0);  xSpan = diff(ax.XLim);
        yDrag = abs(y1 - y0);  ySpan = diff(ax.YLim);
        if xDrag < xSpan * 0.01 || yDrag < ySpan * 0.01
            return;
        end
        extract2DBoxIntegral(x0, y0, x1, y1);
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
    %HASFIXEDBOXSIZE  Return true if both Width and Height fields are valid positive numbers.
        boxW = str2double(efBoxIntW.Value);
        boxH = str2double(efBoxIntH.Value);
        tf = ~isnan(boxW) && ~isnan(boxH) && boxW > 0 && boxH > 0;
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
    %EXECUTEFIXEDBOXINTEGRATION  Place a fixed-size box centred at (cx,cy) and integrate.
        clearBoxPreview();
        [~, boxW, boxH] = hasFixedBoxSize();
        hw = boxW / 2;  hh = boxH / 2;
        xLo = cx - hw;  xHi = cx + hw;
        yLo = cy - hh;  yHi = cy + hh;

        % Draw overlay showing the fixed-size box
        hold(ax, 'on');
        hBoxOverlay = patch(ax, ...
            [xLo xHi xHi xLo xLo], [yLo yLo yHi yHi yLo], ...
            'k', ...
            'FaceAlpha',       0, ...
            'EdgeColor',       [0.65 0.20 0.85], ...
            'LineStyle',       '--', ...
            'LineWidth',       2.5, ...
            'Tag',             'GUIBoxIntFixed', ...
            'HandleVisibility','off');
        hold(ax, 'off');
        drawnow;

        extract2DBoxIntegral(xLo, yLo, xHi, yHi);

        % Clean up overlay
        if ~isempty(hBoxOverlay) && isvalid(hBoxOverlay)
            delete(hBoxOverlay);
        end
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
        % Col 3 = 2D map panel (visible only for 2D data), col 4 = save/export (always).
        is2D_now = appData.activeIdx >= 1 && ~isempty(appData.datasets) && ...
                   is2DDataset(appData.datasets{appData.activeIdx});
        col3W = guiTernary(is2D_now, '2x', 0);
        defCorrW = LAYOUT_DEFAULTS.corrPanelW;
        if figW < 900
            col4W = guiTernary(is2D_now, 140, 0);
            analysisGL.ColumnWidth = {min(260, defCorrW), '1x', col3W, col4W};
        elseif figW < 1100
            analysisGL.ColumnWidth = {min(280, defCorrW), '1x', col3W, 180};
        end

        % ── Keep data table hidden in 2D mode during resize ──
        if is2D_now
            dataTablePanel.Visible = 'off';
            axLimPanel.Layout.Row  = [1 2];
        else
            dataTablePanel.Visible = 'on';
            axLimPanel.Layout.Row  = 1;
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
    %ONFIGUREKEYPRES  Handle keyboard shortcuts.
    %  Delete          — remove selected dataset(s)
    %  Ctrl+S          — save session
    %  Ctrl+Z          — undo last operation
    %  Ctrl+Y / Ctrl+Shift+Z — redo last undone operation
    %  Ctrl+E          — export CSV
    %  Ctrl+C          — copy plot to clipboard
    %  Left/Right      — switch active dataset
    %  Space           — toggle dataset visibility
    %  Ctrl+Up         — move dataset up
    %  Ctrl+Down       — move dataset down
    %  Alt+Up/Down     — cycle SI prefix on Y (Alt+Shift = X)
    %  F5              — refresh state (flush caches, re-sync widgets, redraw)
        hasMod   = ~isempty(e.Modifier);
        hasCtrl  = hasMod && any(strcmp(e.Modifier, 'control'));
        hasShift = hasMod && any(strcmp(e.Modifier, 'shift'));
        hasAlt   = hasMod && any(strcmp(e.Modifier, 'alt'));

        switch e.Key
            case 'f5'
                refreshState();
                return;
            case 'delete'
                if ~isempty(lbDatasets.Value) && ~isempty(appData.datasets)
                    onRemoveDataset([], []);
                end

            case 's'
                if hasCtrl, onSaveSession([], []); end

            case 'z'
                if hasCtrl && hasShift
                    onRedo([], []);      % Ctrl+Shift+Z = redo
                elseif hasCtrl
                    onUndo([], []);      % Ctrl+Z = undo
                end

            case 'y'
                if hasCtrl && hasShift
                    focus(lbY);              % Ctrl+Shift+Y → Y channel selector
                elseif hasCtrl
                    onRedo([], []);          % Ctrl+Y = redo
                end

            case 'm'
                if hasCtrl, onUnmaskAll([], []); end

            case 'e'
                if hasCtrl, onSaveCSV([], []); end

            case 'c'
                if hasCtrl, onCopyToClipboard([], []); end

            case 'l'
                if hasCtrl, focus(lbDatasets); end  % Ctrl+L → dataset list

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
                if hasAlt
                    % Alt+Up = cycle Y prefix toward larger units; +Shift = X
                    isX = hasShift;
                    if isX, curSym = appData.axisPrefixX.symbol;
                    else,   curSym = appData.axisPrefixY.symbol;
                    end
                    ci = find(strcmp(appData.prefixSymbols, curSym), 1);
                    if isempty(ci), ci = 1; end
                    ni = max(1, ci - 1);
                    pf = struct('symbol', appData.prefixSymbols{ni}, 'factor', appData.prefixFactors(ni));
                    if isX, appData.axisPrefixX = pf; else, appData.axisPrefixY = pf; end
                    onPlot([],[]); setStatus(sprintf('%s prefix: %s', guiTernary(isX,'X','Y'), appData.prefixNames{ni}));
                elseif hasCtrl
                    onMoveDatasetUp([], []);
                end

            case 'downarrow'
                if hasAlt
                    % Alt+Down = cycle Y prefix toward smaller units; +Shift = X
                    isX = hasShift;
                    if isX, curSym = appData.axisPrefixX.symbol;
                    else,   curSym = appData.axisPrefixY.symbol;
                    end
                    ci = find(strcmp(appData.prefixSymbols, curSym), 1);
                    if isempty(ci), ci = 1; end
                    ni = min(numel(appData.prefixSymbols), ci + 1);
                    pf = struct('symbol', appData.prefixSymbols{ni}, 'factor', appData.prefixFactors(ni));
                    if isX, appData.axisPrefixX = pf; else, appData.axisPrefixY = pf; end
                    onPlot([],[]); setStatus(sprintf('%s prefix: %s', guiTernary(isX,'X','Y'), appData.prefixNames{ni}));
                elseif hasCtrl
                    onMoveDatasetDown([], []);
                end
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
        copygraphics(tmpAx, 'ContentType','vector', 'BackgroundColor','none');
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
    %ONLOADSESSION  Restore a previously saved session from a .mat file.
    %  Delegates deserialisation to bosonPlotter.sessionManager.load().
        startDir = guiTernary(isempty(appData.lastDir), pwd, appData.lastDir);
        [fname, fpath] = uigetfile({'*.mat','MATLAB session (*.mat)'}, ...
            'Load session file...', startDir);
        if isequal(fname, 0), return; end
        matPath = fullfile(fpath, fname);

        setStatus('Loading session...');
        fig.Pointer = 'watch';
        drawnow;

        try
            [datasets, restored] = bosonPlotter.sessionManager.load(matPath);
        catch ME
            fig.Pointer = 'arrow';
            setStatus('Session load failed.');
            logGUIError('Load Error', ME.message, ME);
            uialert(fig, sprintf('Could not load session:\n%s', ME.message), 'Load Error');
            return;
        end

        cancelInteractions();

        % Restore core data into appData
        appData.datasets  = datasets;
        appData.activeIdx = restored.activeIdx;
        appData.bgFile    = restored.bgFile;
        appData.bgDataset = restored.bgDataset;
        appData.style     = restored.style;
        appData.lastDir   = restored.lastDir;
        % Phase A/B visual state
        if isfield(restored, 'activeTemplate') && ~isempty(restored.activeTemplate)
            appData.activeTemplate = restored.activeTemplate;
        end
        if isfield(restored, 'styleOverrides') && isstruct(restored.styleOverrides)
            appData.styleOverrides = restored.styleOverrides;
        end
        % Sync the Template dropdown so the UI reflects the restored state
        refreshTemplateDropdown();
        if ~isempty(ddTemplate) && isvalid(ddTemplate)
            if any(strcmp(ddTemplate.Items, appData.activeTemplate))
                ddTemplate.Value = appData.activeTemplate;
            end
        end

        if isempty(appData.datasets)
            rebuildDatasetList(false);
            fig.Pointer = 'arrow';
            return;
        end

        % Restore dropdown/scale widget values (colormap, scale, BG interp)
        widgets = buildSessionWidgets_();
        bosonPlotter.sessionManager.applyGuiState(restored.guiState, widgets);

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

        % Restore axis channel selections after listbox items are populated
        bosonPlotter.sessionManager.applyAxisSelections(restored.guiState, widgets);

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
    %    'h_row12'      — horizontal border between content row (1) and analysis row (2)
    %    'h_axdata'     — horizontal border between axLimPanel and dataTablePanel
    %    'v_col12'      — vertical border between corrections col (1) and axes col (2)
    %    'v_col23'      — vertical border between axes col (2) and save/export col (3)
    %    'v_content12'  — vertical border between file list and controls (top row)
    %    'v_content23'  — vertical border between controls and preview (top row)
    %    ''             — not near any known border
        SNAP_PX = 5;
        dir = '';
        try
            mp   = fig.CurrentPoint;                        % [x y] from figure bottom-left
            aPos = getpixelposition(analysisPanel, true);   % [l b w h] relative to figure

            % h_row12: top edge of the analysis panel (border between rows 1 & 2)
            borderY = aPos(2) + aPos(4);
            if abs(mp(2) - borderY) <= SNAP_PX && ...
               mp(1) >= aPos(1) && mp(1) <= aPos(1) + aPos(3)
                dir = 'h_row12'; return;
            end

            % Borders inside the analysis panel's y-band
            if mp(2) >= aPos(2) && mp(2) <= aPos(2) + aPos(4)

                % v_col12: right edge of corrections panel
                cPos    = getpixelposition(corrPanel, true);
                borderX = cPos(1) + cPos(3);
                if abs(mp(1) - borderX) <= SNAP_PX
                    dir = 'v_col12'; return;
                end

                % v_col23: left edge of savePanel (col 4 — always rightmost)
                spPos    = getpixelposition(savePanel, true);
                borderX2 = spPos(1);
                if abs(mp(1) - borderX2) <= SNAP_PX
                    dir = 'v_col23'; return;
                end

                % h_axdata: bottom edge of axLimPanel (border between axes and data table)
                % Skip when data table is hidden (2D map mode — axes span both rows).
                if strcmp(dataTablePanel.Visible, 'on')
                    borderY2 = alPos(2);
                    if abs(mp(2) - borderY2) <= SNAP_PX && ...
                       mp(1) >= alPos(1) && mp(1) <= alPos(1) + alPos(3)
                        dir = 'h_axdata'; return;
                    end
                end
            end

            % Borders inside the content row (top half of figure)
            flPos = getpixelposition(fileListPanel, true);
            cpPos = getpixelposition(ctrlPanel, true);
            if mp(2) >= flPos(2) && mp(2) <= flPos(2) + flPos(4)

                % v_content12: right edge of file list panel
                borderX3 = flPos(1) + flPos(3);
                if abs(mp(1) - borderX3) <= SNAP_PX
                    dir = 'v_content12'; return;
                end

                % v_content23: right edge of controls panel
                borderX4 = cpPos(1) + cpPos(3);
                if abs(mp(1) - borderX4) <= SNAP_PX
                    dir = 'v_content23'; return;
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
        switch appData.panelResizeDir
            case 'h_row12'
                % Snapshot the current analysis panel height (px)
                try
                    aPos = getpixelposition(analysisPanel, true);
                    appData.panelResizeOrig = aPos(4);
                catch
                    rh = rootGL.RowHeight;
                    appData.panelResizeOrig = guiTernary(isnumeric(rh{2}), rh{2}, 300);
                end
            case 'v_col12'
                % Snapshot the current corrections panel width (px)
                try
                    cPos = getpixelposition(corrPanel, true);
                    appData.panelResizeOrig = cPos(3);
                catch
                    appData.panelResizeOrig = appData.corrPanelWidth;
                end
            case 'h_axdata'
                % Snapshot the axLimPanel row height (row 1 of analysisGL)
                rh = analysisGL.RowHeight;
                try
                    alPos = getpixelposition(axLimPanel, true);
                    appData.panelResizeOrig = alPos(4);
                catch
                    appData.panelResizeOrig = guiTernary(isnumeric(rh{1}), rh{1}, 110);
                end
            case 'v_col23'
                % Snapshot the save/export panel width (col 4 of analysisGL)
                try
                    sPos = getpixelposition(savePanel, true);
                    appData.panelResizeOrig = sPos(3);
                catch
                    cw = analysisGL.ColumnWidth;
                    appData.panelResizeOrig = guiTernary(isnumeric(cw{4}), cw{4}, 210);
                end
            case 'v_content12'
                % Snapshot the file list panel width (col 1 of contentGL)
                try
                    flPos = getpixelposition(fileListPanel, true);
                    appData.panelResizeOrig = flPos(3);
                catch
                    cw = contentGL.ColumnWidth;
                    appData.panelResizeOrig = guiTernary(isnumeric(cw{1}), cw{1}, 180);
                end
            case 'v_content23'
                % Snapshot the controls panel width (col 2 of contentGL)
                try
                    cpPos = getpixelposition(ctrlPanel, true);
                    appData.panelResizeOrig = cpPos(3);
                catch
                    cw = contentGL.ColumnWidth;
                    appData.panelResizeOrig = guiTernary(isnumeric(cw{2}), cw{2}, 190);
                end
        end
        fig.WindowButtonMotionFcn = @onPanelResizeMove;
        fig.WindowButtonUpFcn     = @onPanelResizeUp;
    end

    function onPanelResizeMove(~,~)
    %ONPANELRESIZEMOVE  Live-update layout while dragging a panel border.
        if isempty(appData.panelResizeStart), return; end
        mp = fig.CurrentPoint;

        switch appData.panelResizeDir
            case 'h_row12'
                % Mouse moves up → analysis panel gets taller
                delta_y = mp(2) - appData.panelResizeStart(2);
                figH    = fig.Position(4);
                availH  = figH - 12 - 8 - 16;
                newH    = round(appData.panelResizeOrig + delta_y);
                newH    = max(appData.MIN_ANALYSIS_H, min(newH, availH - appData.MIN_PREVIEW_H));
                rootGL.RowHeight = {'1x', newH, 16};

            case 'v_col12'
                % Mouse moves right → corrections panel gets wider
                delta_x = mp(1) - appData.panelResizeStart(1);
                newW    = round(appData.panelResizeOrig + delta_x);
                newW    = max(appData.MIN_CORR_W, min(newW, 600));
                appData.corrPanelWidth = newW;
                cw    = analysisGL.ColumnWidth;
                cw{1} = newW;
                analysisGL.ColumnWidth = cw;

            case 'h_axdata'
                % Mouse moves up → axLimPanel (row 1) gets taller, dataTable shrinks
                delta_y = mp(2) - appData.panelResizeStart(2);
                newH    = round(appData.panelResizeOrig + delta_y);
                newH    = max(60, min(newH, 400));  % min 60px for axes, max 400px
                analysisGL.RowHeight = {newH, '1x'};

            case 'v_col23'
                % Mouse moves right → save panel (col 4) gets narrower
                delta_x = mp(1) - appData.panelResizeStart(1);
                newW    = round(appData.panelResizeOrig - delta_x);
                newW    = max(140, min(newW, 400));  % min 140px, max 400px
                cw    = analysisGL.ColumnWidth;
                cw{4} = newW;
                analysisGL.ColumnWidth = cw;

            case 'v_content12'
                % Mouse moves right → file list gets wider
                delta_x = mp(1) - appData.panelResizeStart(1);
                newW    = round(appData.panelResizeOrig + delta_x);
                newW    = max(120, min(newW, 350));  % min 120px, max 350px
                cw    = contentGL.ColumnWidth;
                cw{1} = newW;
                contentGL.ColumnWidth = cw;

            case 'v_content23'
                % Mouse moves right → controls panel gets wider
                delta_x = mp(1) - appData.panelResizeStart(1);
                newW    = round(appData.panelResizeOrig + delta_x);
                newW    = max(140, min(newW, 350));  % min 140px, max 350px
                cw    = contentGL.ColumnWidth;
                cw{2} = newW;
                contentGL.ColumnWidth = cw;
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
                'FontSize',        10, ...
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
        appData.model.addDataset(dsCopy.data, dsCopy.filepath, dsCopy.parserName);
        appData.activeIdx = numel(appData.datasets);
        rebuildDatasetList(true);
        updateControlsForActiveDataset();
        onPlot([],[]);
    end

    function onDatasetMetaEdit(mode)
    %ONDATASETMETAEDIT  Dataset operations and correction preset management.
    %   mode: 'notes', 'rename', 'reload', 'save-preset', 'load-preset', 'delete-preset'

        % Preset operations don't require a loaded dataset
        if startsWith(mode, 'save-preset') || startsWith(mode, 'load-preset') || startsWith(mode, 'delete-preset')
            switch mode
                case 'save-preset'
                    answer = inputdlg('Preset name:', 'Save Correction Preset', [1 40]);
                    if isempty(answer) || isempty(strtrim(answer{1})), return; end
                    pName = strtrim(answer{1});
                    p = struct('xOff', efXOffset.Value, 'yOff', efYOffset.Value, ...
                        'bgSlope', efBGSlope.Value, 'bgInt', efBGIntercept.Value, ...
                        'smoothEnabled', cbSmooth.Value, 'smoothWindow', efSmoothWin.Value, ...
                        'smoothMethod', ddSmoothMethod.Value, 'normMethod', ddNormalize.Value, ...
                        'derivativeMode', ddDerivative.Value, ...
                        'xTrimMin', efXTrimMin.Value, 'xTrimMax', efXTrimMax.Value);
                    bosonPlotter.correctionPresets.save(pName, p);
                    ddPreset.Items = [{'(presets)'}, bosonPlotter.correctionPresets.list()];
                    ddPreset.Value = '(presets)';
                    setStatus(sprintf('Preset "%s" saved.', pName));
                case 'load-preset'
                    selName = ddPreset.Value;
                    if strcmp(selName, '(presets)'), return; end
                    try
                        p = bosonPlotter.correctionPresets.load(selName);
                    catch
                        uialert(fig, sprintf('Preset "%s" not found.', selName), 'Load Error');
                        return;
                    end
                    if isfield(p,'xOff'),    efXOffset.Value = p.xOff; end
                    if isfield(p,'yOff'),    efYOffset.Value = p.yOff; end
                    if isfield(p,'bgSlope'), efBGSlope.Value = p.bgSlope; end
                    if isfield(p,'bgInt'),   efBGIntercept.Value = p.bgInt; end
                    if isfield(p,'smoothEnabled'), cbSmooth.Value = p.smoothEnabled; end
                    if isfield(p,'smoothWindow'),  efSmoothWin.Value = p.smoothWindow; end
                    if isfield(p,'smoothMethod'),   ddSmoothMethod.Value = p.smoothMethod; end
                    if isfield(p,'normMethod'),     ddNormalize.Value = p.normMethod; end
                    if isfield(p,'derivativeMode'), ddDerivative.Value = p.derivativeMode; end
                    if isfield(p,'xTrimMin'), efXTrimMin.Value = p.xTrimMin; end
                    if isfield(p,'xTrimMax'), efXTrimMax.Value = p.xTrimMax; end
                    setStatus(sprintf('Loaded preset "%s" — click Apply to use.', selName));
                case 'delete-preset'
                    selName = ddPreset.Value;
                    if strcmp(selName, '(presets)'), return; end
                    bosonPlotter.correctionPresets.delete(selName);
                    ddPreset.Items = [{'(presets)'}, bosonPlotter.correctionPresets.list()];
                    ddPreset.Value = '(presets)';
                    setStatus(sprintf('Preset "%s" deleted.', selName));
            end
            return;
        end

        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a file first.', 'No data'); return;
        end
        ds = appData.datasets{appData.activeIdx};
        switch mode
            case 'notes'
                currentNotes = '';
                if isfield(ds, 'notes'), currentNotes = ds.notes; end
                answer = inputdlg('Dataset notes:', 'Notes', [5 60], {currentNotes});
                if isempty(answer), return; end
                appData.datasets{appData.activeIdx}.notes = strtrim(answer{1});
                rebuildDatasetList(true);
                onSelectDataset([], []);
                setStatus(guiTernary(isempty(strtrim(answer{1})), 'Note cleared.', 'Note saved.'));
            case 'rename'
                current = ds.displayName;
                if isempty(current)
                    [~, fn, fext] = fileparts(ds.filepath);
                    current = [fn fext];
                end
                answer = inputdlg('Display name:', 'Rename Dataset', [1 60], {current});
                if isempty(answer), return; end
                newName = strtrim(answer{1});
                if isempty(newName), return; end
                appData.datasets{appData.activeIdx}.displayName = newName;
                appData.datasets{appData.activeIdx}.legendName  = newName;
                rebuildDatasetList(true);
                onPlot([], []);
                setStatus(sprintf('Renamed to: %s', newName));
            case 'reload'
                fp = ds.filepath;
                if ~isfile(fp)
                    uialert(fig, sprintf('File not found:\n%s', fp), 'Reload Failed');
                    return;
                end
                try
                    [newData, pName] = guiImport(fp);
                    appData.datasets{appData.activeIdx}.data = newData;
                    appData.datasets{appData.activeIdx}.corrData = [];
                    appData.datasets{appData.activeIdx}.parserName = pName;
                    appData.datasets{appData.activeIdx}.mask = true(size(newData.time));
                    updateControlsForActiveDataset();
                    onPlot([], []);
                    [~, fn, fext] = fileparts(fp);
                    setStatus(sprintf('Reloaded %s%s from disk.', fn, fext));
                catch ME
                    uialert(fig, sprintf('Reload failed:\n%s', ME.message), 'Reload Error');
                end
        end
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
            yResult = bosonPlotter.safeEvalMathExpr(expr, colVars);
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
            try
                appData.model.updateDataset(appData.activeIdx, ds);
            catch
            end
            updateControlsForActiveDataset();
            onPlot([],[]);
            setStatus(sprintf('Added column "%s".', colName));
            recordAction(sprintf('%% Column calculator: %s = %s', colName, expr));
        catch ME
            uialert(fig, sprintf('Expression error:\n%s', ME.message), 'Column Calculator Error');
        end
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
    %ONCURSORCLICK  Handle click in data cursor mode.
    %  Normal click: point 1 / point 2 (delta) cycle.
    %  Ctrl+click: pin a persistent marker at the snapped point.
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
        xRange = diff(xl); yRange = diff(yl);
        if xRange == 0, xRange = 1; end
        if yRange == 0, yRange = 1; end
        dist = ((xData - xClick) / xRange).^2 + ((yCol - yClick) / yRange).^2;
        [~, idx] = min(dist);
        xSnap = xData(idx);
        ySnap = yCol(idx);

        % Ctrl+click → pin a persistent marker
        ctrlHeld = ~isempty(fig.CurrentModifier) && ...
                   any(strcmp(fig.CurrentModifier, 'control'));
        if ctrlHeld
            hold(ax, 'on');
            pinColors = [0.00 0.60 0.30; 0.80 0.40 0.00; 0.50 0.00 0.50; ...
                         0.00 0.40 0.70; 0.70 0.00 0.00; 0.40 0.40 0.40];
            ci = mod(numel(appData.cursorPinned), size(pinColors,1)) + 1;
            pc = pinColors(ci,:);
            mk = plot(ax, xSnap, ySnap, 'd', 'MarkerSize', 9, 'LineWidth', 2, ...
                'Color', pc, 'MarkerFaceColor', pc, 'HandleVisibility', 'off');
            lbl = sprintf('  (%.6g, %.6g)', xSnap, ySnap);
            lb = text(ax, xSnap, ySnap, lbl, ...
                'FontSize', 8, 'Color', pc, 'FontWeight', 'bold', ...
                'BackgroundColor', [1 1 1 0.85], 'EdgeColor', pc, ...
                'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');
            appData.cursorPinned{end+1} = struct('marker', mk, 'label', lb);
            setStatus(sprintf('Pinned #%d: (%.6g, %.6g)', numel(appData.cursorPinned), xSnap, ySnap));
            return;
        end

        appData.cursorClickCount = appData.cursorClickCount + 1;

        if appData.cursorClickCount == 1
            % First click: show point — clean up previous graphics
            if isgraphics(appData.cursorMarker), delete(appData.cursorMarker); end
            if isgraphics(appData.cursorLabel), delete(appData.cursorLabel); end
            if isgraphics(appData.cursorMarker2), delete(appData.cursorMarker2); end
            if isgraphics(appData.cursorDeltaLabel), delete(appData.cursorDeltaLabel); end
            if isgraphics(appData.cursorLine), delete(appData.cursorLine); end

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
            if isempty(appData.cursorPt1)
                appData.cursorClickCount = 1;
                return;
            end
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
                   'applyMaskStylingFn',       @applyMaskStyling, ...
                   'syncUnitsColumnWidthsFn',  @syncUnitsColumnWidths));
    end

    function applyMaskStyling()
    %APPLYMASKSTYLING  Highlight masked rows in soft red using uistyle/addStyle.
    %   Clears any existing row styles (they can accumulate across refreshes)
    %   and reapplies a single BackgroundColor style to each currently masked
    %   row.  Data rows are offset by 1 in the display to account for the
    %   units row at table row 1.  Safe to call on an empty/invalid table.
        if isempty(tblData) || ~isvalid(tblData), return; end
        removeStyle(tblData);

        if isempty(appData.tableMask) || ~any(appData.tableMask), return; end

        cap = min(numel(appData.tableMask), appData.tableRowCap);
        maskedDataRows = find(appData.tableMask(1:cap));
        if isempty(maskedDataRows), return; end

        % Post-split: tblData rows map 1:1 to data rows — no units row
        % to offset around.
        softRed = [1.0 0.88 0.88];
        s = uistyle('BackgroundColor', softRed);
        addStyle(tblData, s, 'row', maskedDataRows);
    end

    function onTableCellEdit(~, evt)
    %ONTABLECELLEDIT  Handle cell edits in the main data table.
    %   Post-split: tblData holds only numeric data rows (no units
    %   row).  Units live in a separate tblUnits uitable handled by
    %   onUnitsCellEdit below.
        row = evt.Indices(1);
        col = evt.Indices(2);
        nDataCols = size(appData.tableWorkingCopy, 2);
        if col > nDataCols, return; end

        newVal = evt.NewData;
        if isnumeric(newVal)
            appData.tableWorkingCopy(row, col) = newVal;
            appData.tableEdited = true;
        end
    end

    function onUnitsCellEdit(~, evt)
    %ONUNITSCELLEDIT  Handle edits in the 1-row units uitable.
    %   Stores the new unit string in appData.tableUnits.  Cell edit
    %   event rows are always 1 for the units table.
        col = evt.Indices(2);
        if col < 1 || col > numel(appData.tableUnits), return; end
        newVal = evt.NewData;
        if ischar(newVal) || isstring(newVal)
            appData.tableUnits{col} = char(newVal);
            appData.tableEdited = true;
        end
    end

    function syncUnitsColumnWidths(nCols)
    %SYNCUNITSCOLUMNWIDTHS  Match tblUnits column widths to tblData.
    %   MATLAB uitable auto-sizes each column to its own content by
    %   default — on two separate tables that means the units table
    %   and data table would diverge.  Use an explicit ColumnWidth
    %   array on BOTH tables so the columns stay aligned no matter
    %   what values are in the cells.
        w = cell(1, nCols);
        for ci = 1:nCols, w{ci} = 90; end
        try tblData.ColumnWidth  = w; catch, end
        try tblUnits.ColumnWidth = w; catch, end
    end

    function onTableSelectionChanged(~, evt)
    %ONTABLESELECTIONCHANGED  Track selected cells for mask actions.
    %   Selected [row col] pairs are cached in appData.tableSelection
    %   for onTableMaskSelected / onTableUnmaskSelected to read.
    %   Column drag-to-plot is handled by onUnitsCellSelection below
    %   (fires when the user clicks a cell in tblUnits, which is
    %   visually adjacent to tblData's column header).
        appData.tableSelection = evt.Indices;
    end

    function onUnitsCellSelection(~, evt)
    %ONUNITSCELLSELECTION  Arm the column drag-to-plot gesture.
    %   Replaces the pre-split "click row 1 of the data table"
    %   pathway.  tblUnits sits directly below the column header and
    %   is the visual proxy for clicking a column; selecting any cell
    %   in it arms the drag for that column's channel.
        if isempty(evt.Indices), return; end
        col = evt.Indices(1,2);
        colNames = tblUnits.ColumnName;
        if col < 1 || col > numel(colNames), return; end
        rawName = colNames{col};
        if isempty(appData.datasets) || appData.activeIdx < 1, return; end
        ds = appData.datasets{appData.activeIdx};
        d  = ds.data;
        xName     = guiXName(d.metadata);
        allLabels = [{xName}, d.labels];
        matched = allLabels(strcmp(allLabels, rawName));
        if isempty(matched)
            cleanName = regexprep(rawName, '\s*\(.*\)\s*$', '');
            matched = allLabels(strcmp(allLabels, cleanName));
        end
        if isempty(matched), return; end
        onColumnDragStart(matched{1});
    end

    function onTableMaskSelected(~, ~)
    %ONTABLEMASKSELECTED  Mask the currently selected rows in the table.
    %   Post-split: tblData rows map 1:1 to data rows (no units row
    %   offset).  Applies soft-red row highlighting via applyMaskStyling.
        sel = appData.tableSelection;
        if isempty(sel), return; end
        dataRows = unique(sel(:, 1));
        dataRows(dataRows < 1) = [];
        if isempty(dataRows), return; end
        if max(dataRows) > size(appData.tableWorkingCopy, 1), return; end
        appData.tableMask(dataRows) = true;
        applyMaskStyling();
        nMasked = sum(appData.tableMask);
        nRows = size(appData.tableWorkingCopy, 1);
        nCols = size(appData.tableWorkingCopy, 2);
        lblTableStats.Text = sprintf('%d rows, %d cols, %d masked  ', ...
            nRows, nCols, nMasked);
        syncTableMaskToDataset();
        setStatus(sprintf('Masked %d rows (%d total masked)', numel(dataRows), nMasked));
    end

    function onTableUnmaskSelected(~, ~)
    %ONTABLEUNMASKSELECTED  Unmask the currently selected rows (opposite of onTableMaskSelected).
        sel = appData.tableSelection;
        if isempty(sel), return; end
        dataRows = unique(sel(:, 1));
        dataRows = dataRows(dataRows >= 1 & dataRows <= numel(appData.tableMask));
        if isempty(dataRows), return; end
        appData.tableMask(dataRows) = false;
        applyMaskStyling();
        nMasked = sum(appData.tableMask);
        nRows = size(appData.tableWorkingCopy, 1);
        nCols = size(appData.tableWorkingCopy, 2);
        lblTableStats.Text = sprintf('%d rows, %d cols, %d masked  ', ...
            nRows, nCols, nMasked);
        syncTableMaskToDataset();
        setStatus(sprintf('Unmasked %d rows (%d total masked)', numel(dataRows), nMasked));
    end

    function onTableUnmaskAll(~, ~)
    %ONTABLEUNMASKALL  Clear all row masks.
        if isempty(appData.tableMask), return; end
        appData.tableMask(:) = false;
        refreshDataTable();
        syncTableMaskToDataset();
        setStatus('All masks cleared');
    end

    function onFilterApply()
    %ONFILTERAPPY  Evaluate filter expression and mask non-passing rows.
    %   Calls bosonPlotter.filterRows() with the current data struct.
    %   Rows that fail the filter are added to the mask (excluded from plot).
    %   An empty expression clears the filter without touching manual masks.
        if appData.activeIdx < 1 || isempty(appData.datasets), return; end
        expr = strtrim(efFilter.Value);
        d    = getPlotData(appData.activeIdx);
        nRows = numel(d.time);

        if isempty(expr)
            % Empty expression — clear filter mask only
            appData.filterMask = [];
        else
            try
                passMask = bosonPlotter.filterRows(d, expr);
                appData.filterMask = ~passMask(:);  % true = excluded by filter
                nPass = sum(passMask);
                setStatus(sprintf('Filter applied: %d / %d rows pass', nPass, nRows));
            catch ME
                uialert(fig, ME.message, 'Filter Error');
                return;
            end
        end

        % Merge filter mask into table mask: row is masked if either source says so
        if isempty(appData.filterMask)
            appData.tableMask = false(nRows, 1);
        else
            if isempty(appData.tableMask) || numel(appData.tableMask) ~= nRows
                appData.tableMask = appData.filterMask;
            else
                appData.tableMask = appData.tableMask | appData.filterMask;
            end
        end
        refreshDataTable();
        syncTableMaskToDataset();
    end

    function onFilterClear()
    %ONFILTERCLEAR  Remove the row filter and restore unfiltered data.
        efFilter.Value     = '';
        appData.filterMask = [];
        nRows = size(appData.tableWorkingCopy, 1);
        if ~isempty(appData.tableMask) && numel(appData.tableMask) == nRows
            appData.tableMask(:) = false;
        end
        refreshDataTable();
        syncTableMaskToDataset();
        setStatus('Filter cleared');
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
            [~, ~, ext] = fileparts(outPath);

            if strcmpi(ext, '.xlsx')
                % Excel: write header, units, then data as separate rows
                headerCell = colNames(:)';
                unitsCell  = appData.tableUnits(:)';
                dataCell   = num2cell(wc);
                allCell    = [headerCell; unitsCell; dataCell];
                writecell(allCell, outPath);
            else
                % CSV: write header + units rows, then bulk-write data
                fidOut = fopen(outPath, 'w');
                if fidOut == -1
                    error('Cannot open file: %s', outPath);
                end
                % Header row
                fprintf(fidOut, '%s\n', strjoin(colNames, ','));
                % Units row
                fprintf(fidOut, '%s\n', strjoin(appData.tableUnits, ','));
                fclose(fidOut);
                % Data rows — single writematrix call replaces O(N) loop
                writematrix(wc, outPath, 'Delimiter', ',', ...
                    'WriteMode', 'append', 'Precision', 10);
            end
            setStatus(sprintf('Table saved: %s (%d rows + units)', fn, size(wc, 1)));
        catch ME
            uialert(fig, sprintf('Save failed:\n%s', ME.message), 'Error');
        end
    end

    % ── Plot Options Popup Menu ──────────────────────────────────────────

    plotOptFig = [];  % persistent handle to the plot options popup

    function closePlotOptMenu()
    %CLOSEPLOTOPTMENU  Close the plot options popup if open.
        if ~isempty(plotOptFig) && isvalid(plotOptFig)
            delete(plotOptFig);
        end
        plotOptFig = [];
    end

    function onShowPlotOptionsMenu(~, ~)
    %ONSHOWPLOTOPTIONSMENU  Show a popup menu of plot types and visualization tools.

        % Bring to front if already open
        if ~isempty(plotOptFig) && isvalid(plotOptFig)
            if ~headless, figure(plotOptFig); end
            return;
        end

        BTN_BG = [0.15 0.15 0.15];
        BTN_FC = [0.9 0.9 0.9];
        HDR_FC = [0.5 0.5 0.5];

        figPos = fig.Position;
        plotOptFig = uifigure('Name', 'Plot Options', ...
            'Position', [figPos(1) + 200, figPos(2) + figPos(4) - 300, 220, 260], ...
            'Resize', 'off', ...
            'CloseRequestFcn', @(~,~) closePlotOptMenu(), ...
            'KeyPressFcn', @(~,evt) onPlotOptKey(evt));

        poGL = uigridlayout(plotOptFig, [10 1], ...
            'RowHeight', {16, 26, 26, 26, 5, 16, 26, 26, 5, 26}, ...
            'ColumnWidth', {'1x'}, ...
            'Padding', [8 6 8 6], 'RowSpacing', 2);

        % Section: PLOT TYPES
        lblPT = uilabel(poGL, 'Text', 'PLOT TYPES', 'FontSize', 9, ...
            'FontWeight', 'bold', 'FontColor', HDR_FC);
        lblPT.Layout.Row = 1;

        poBtn(poGL, 2, 'Compose Figure...', @onComposeFigure, ...
            'Multi-panel composite figure with subplot labels and annotations');
        poBtn(poGL, 3, '3D Surface / Mesh...', @on3DSurface, ...
            'Surface, mesh, or contour plot from gridded 2D data (e.g. area detector XRDML)');
        poBtn(poGL, 4, 'Polar Plot...', @onPolarPlot, ...
            'Polar plot for phi scans, pole figures, and angular measurements');

        % Separator row 5

        % Section: CONVERT
        lblCv = uilabel(poGL, 'Text', 'CONVERT', 'FontSize', 9, ...
            'FontWeight', 'bold', 'FontColor', HDR_FC);
        lblCv.Layout.Row = 6;

        poBtn(poGL, 7, ['Convert Units (' char(8596) ')...'], @onConvertUnits, ...
            ['Convert axis units: Oe' char(8596) 'T, emu' char(8596) ...
             'A' char(183) 'm' char(178) ', K' char(8596) char(176) 'C, etc.']);
        poBtn(poGL, 8, 'XRD CSV Export...', @onWriteXRDcsv, ...
            'Export XRD data as CSV with metadata header (standard or Origin ASCII format)');

        % Separator row 9

        % Close
        btnCloseP = uibutton(poGL, 'Text', 'Close', ...
            'ButtonPushedFcn', @(~,~) closePlotOptMenu(), ...
            'BackgroundColor', [0.25 0.25 0.25], 'FontColor', [0.7 0.7 0.7]);
        btnCloseP.Layout.Row = 10;

        function poBtn(gl, row, txt, cb, tip)
            b = uibutton(gl, 'Text', txt, ...
                'ButtonPushedFcn', @(~,~) plotOptAction(cb), ...
                'BackgroundColor', BTN_BG, 'FontColor', BTN_FC, ...
                'HorizontalAlignment', 'left', ...
                'Tooltip', tip);
            b.Layout.Row = row;
        end

        function plotOptAction(callbackFcn)
            closePlotOptMenu();
            callbackFcn([], []);
        end

        function onPlotOptKey(evt)
            if strcmp(evt.Key, 'escape'), closePlotOptMenu(); end
        end
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
    %ONCONVERTUNITS  Convert axis units for the active dataset.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Convert Units');
            return;
        end
        answer = inputdlg({ ...
            'From unit (e.g. Oe, T, emu, K):', ...
            'To unit (e.g. T, Oe, A*m2, C):'}, ...
            'Convert Units', [1 40; 1 40], {'Oe', 'T'});
        if isempty(answer), return; end
        fromUnit = strtrim(answer{1});
        toUnit   = strtrim(answer{2});
        ds = appData.datasets{appData.activeIdx};
        d = ds.data;
        % Convert all matching columns
        converted = false;
        for ci = 1:numel(d.units)
            if strcmpi(d.units{ci}, fromUnit)
                try
                    [d.values(:, ci), newUnit] = utilities.convertUnits( ...
                        d.values(:, ci), fromUnit, toUnit);
                    d.units{ci} = newUnit;
                    converted = true;
                catch ME
                    uialert(fig, sprintf('Conversion failed for %s:\n%s', ...
                        d.labels{ci}, ME.message), 'Error');
                    return;
                end
            end
        end
        % Also convert time/x if its unit matches
        if isfield(d.metadata, 'xUnit') && strcmpi(d.metadata.xUnit, fromUnit)
            try
                [d.time, newUnit] = utilities.convertUnits(d.time, fromUnit, toUnit);
                d.metadata.xUnit = newUnit;
                converted = true;
            catch ME
                logGUIError('X-axis unit conversion', ME.message, ME);
            end
        end
        if converted
            ds.data = d;
            ds.corrData = [];  % reset corrections since base data changed
            appData.datasets{appData.activeIdx} = ds;
            onPlot([], []);
            setStatus(sprintf('Converted %s to %s', fromUnit, toUnit));
        else
            uialert(fig, sprintf('No columns with unit "%s" found.', fromUnit), 'Convert Units');
        end
        recordAction(sprintf('%% Convert units: %s -> %s', fromUnit, toUnit));
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
    %ONBATCHIMPORTDIR  Import all supported files from a directory.
        dirPath = uigetdir(pwd, 'Select directory to import');
        if isequal(dirPath, 0), return; end
        answer = uiconfirm(fig, 'Scan subdirectories recursively?', ...
            'Batch Import', 'Options', {'Yes', 'No', 'Cancel'}, ...
            'DefaultOption', 1, 'CancelOption', 3);
        if strcmp(answer, 'Cancel'), return; end
        recursive = strcmp(answer, 'Yes');
        setStatus('Batch importing...');
        drawnow;
        try
            results = scripts.batchImport(dirPath, 'Recursive', recursive);
            if isempty(results)
                uialert(fig, 'No supported files found in the selected directory.', 'Batch Import');
                setStatus('Batch import: no files found');
                return;
            end
            % Add each result as a dataset via standard buildDs path
            nAdded = 0;
            for bi = 1:numel(results)
                if isempty(results(bi).data), continue; end
                try
                    fp_i = results(bi).filepath;
                    ds_i = buildDs(fp_i, results(bi).data, 'importAuto');
                    appData.datasets{end+1} = ds_i;
                    appData.model.addDataset(results(bi).data, fp_i, 'importAuto');
                    nAdded = nAdded + 1;
                catch
                    % Skip files that fail to build dataset struct
                end
            end
            if nAdded > 0
                rebuildDatasetList(false);
                appData.activeIdx = numel(appData.datasets);
                onSelectDataset([], []);
            end
            setStatus(sprintf('Batch import: %d files loaded from %s', nAdded, dirPath));
        catch ME
            uialert(fig, sprintf('Batch import failed:\n%s', ME.message), 'Error');
            setStatus('Batch import failed');
        end
        recordAction(sprintf("%% Batch import: '%s' (recursive=%d)", dirPath, recursive));
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

    advMenuFig = [];  % persistent handle to the popup menu figure

    function closeAdvMenu()
    %CLOSEADVMENU  Close the advanced tools popup if open.
        if ~isempty(advMenuFig) && isvalid(advMenuFig)
            delete(advMenuFig);
        end
        advMenuFig = [];
    end

    function onShowAdvancedMenu(~, ~)
    %ONSHOWADVANCEDMENU  Show a popup menu of advanced analysis tools.
    %   Opens a 2-column floating figure with sectioned actions. Clicking an
    %   action closes the popup and launches the corresponding dialog.

        % Bring to front if already open (prevents "lost window" problem)
        if ~isempty(advMenuFig) && isvalid(advMenuFig)
            if ~headless, figure(advMenuFig); end
            return;
        end

        BTN_BG = [0.15 0.15 0.15];
        BTN_FC = [0.9 0.9 0.9];
        HDR_FC = [0.5 0.5 0.5];

        % Position near the Advanced button
        figPos = fig.Position;
        advMenuFig = uifigure('Name', 'Advanced Tools', ...
            'Position', [figPos(1) + figPos(3) - 400, figPos(2) + figPos(4) - 700, 380, 640], ...
            'Resize', 'on', ...
            'CloseRequestFcn', @(~,~) closeAdvMenu(), ...
            'KeyPressFcn', @(~,evt) onAdvMenuKey(evt));

        % ── Top-level grid: filter bar + scrollable button panel ────────
        advRootGL = uigridlayout(advMenuFig, [2 1], ...
            'RowHeight', {30, '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 0);
        efAdvFilter = uieditfield(advRootGL, 'text', ...
            'Value', '', ...
            'Placeholder', 'Filter tools...', ...
            'FontSize', 10, ...
            'ValueChangedFcn', @(~,~) onAdvFilterChanged());
        efAdvFilter.Layout.Row = 1;

        advScrollPanel = uipanel(advRootGL, 'BorderType', 'none', 'Scrollable', 'on');
        advScrollPanel.Layout.Row = 2;

        % 26 rows x 2 cols: 7 headers, 6 separators, 13 button rows
        advMenuGL = uigridlayout(advScrollPanel, [26 2], ...
            'RowHeight', {16, 26,26,26,  5,  16, 26,26,26,  5,  16, 26,  5,  16, 26,  5,  16, 26,  5,  16, 26,26,26,  5,  16, 26}, ...
            'ColumnWidth', {'1x', '1x'}, ...
            'Padding', [8 6 8 6], 'RowSpacing', 2, 'ColumnSpacing', 4);

        allAdvBtns = {};  % collect all button handles for filtering (Fix B2)

        % ── Section: ANALYSIS ────────────────────────────────────────
        hdr = uilabel(advMenuGL, 'Text', 'ANALYSIS', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
        hdr.Layout.Row = 1; hdr.Layout.Column = [1 2];

        advBtn(advMenuGL, 2, 1, [char(8747) ' Integrate...'], @onOpenIntegrationDialog, ...
            'Compute definite integral between two x-range edge points');
        advBtn(advMenuGL, 2, 2, [char(8776) ' Curve Fit...'], @onOpenCurveFitDialog, ...
            'Fit data to built-in models (exponential, power law, polynomial, Gaussian, ...)');
        advBtn(advMenuGL, 3, 1, [char(916) ' Dataset Math...'], @onDatasetAlgebra, ...
            'Combine datasets: A+B, A-B, A/B, A*B, asymmetry');
        advBtn(advMenuGL, 3, 2, [char(8635) ' Hysteresis...'], @onOpenHysteresisDialog, ...
            'Analyze M(H) loops: Hc, Mr, Ms, squareness, SFD, background subtraction');
        advBtn(advMenuGL, 4, 1, 'ROI Analysis...', @onROIAnalysis, ...
            'Select a region of interest and compute statistics within it');
        advBtn(advMenuGL, 4, 2, 'Confidence Band...', @onConfidenceBand, ...
            ['Mean' char(177) 'std or median' char(177) 'IQR shaded bands from repeat measurements']);

        % ── Section: STATISTICS & FITTING ────────────────────────────
        % Separator row 5
        hdr2 = uilabel(advMenuGL, 'Text', 'STATISTICS & FITTING', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
        hdr2.Layout.Row = 6; hdr2.Layout.Column = [1 2];

        advBtn(advMenuGL, 7, 1, 'Descriptive Stats...', @onDescriptiveStats, ...
            'Mean, median, std, quartiles, skewness, kurtosis for selected channel');
        advBtn(advMenuGL, 7, 2, 'Linear Regression...', @onLinearRegression, ...
            'Polynomial regression with confidence bands and p-values');
        advBtn(advMenuGL, 8, 1, 't-Test...', @onTTest, ...
            'One-sample, paired, or two-sample t-test');
        advBtn(advMenuGL, 8, 2, 'Batch Fit...', @onBatchFit, ...
            'Fit the same model across all loaded datasets and collect trend results');
        advBtn(advMenuGL, 9, 1, 'Global Fit...', @onGlobalFit, ...
            'Fit multiple datasets simultaneously with shared parameters');
        advBtn(advMenuGL, 9, 2, 'Track Peak...', @onTrackPeak, ...
            'Track peak position/width drift across a dataset series');

        % ── Section: SIGNAL PROCESSING ───────────────────────────────
        % Separator row 10
        hdr3 = uilabel(advMenuGL, 'Text', 'SIGNAL PROCESSING', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
        hdr3.Layout.Row = 11; hdr3.Layout.Column = [1 2];

        advBtn(advMenuGL, 12, 1, 'FFT Filter...', @onFFTFilter, ...
            'Frequency-domain lowpass / highpass / bandpass / notch filter');

        % ── Section: PEAK ANALYSIS ───────────────────────────────────
        % Separator row 13
        hdr4 = uilabel(advMenuGL, 'Text', 'PEAK ANALYSIS', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
        hdr4.Layout.Row = 14; hdr4.Layout.Column = [1 2];

        advBtn(advMenuGL, 15, 1, 'Advanced Peak Analysis...', @onOpenAdvancedPeakAnalysis, ...
            ['Robust peak detection with adaptive noise, prominence ' ...
             'filtering, simultaneous multi-peak + polynomial background fitting']);

        % ── Section: CORRECTION ──────────────────────────────────────
        % Separator row 16
        hdr5 = uilabel(advMenuGL, 'Text', 'CORRECTION', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
        hdr5.Layout.Row = 17; hdr5.Layout.Column = [1 2];

        advBtn(advMenuGL, 18, 1, [char(8596) ' Resample...'], @onResampleDataset, ...
            'Resample data to a uniform x-grid');
        advBtn(advMenuGL, 18, 2, 'Column Calculator...', @onColumnCalculator, ...
            'Create new columns from expressions');

        % ── Section: NEUTRON / REFLECTOMETRY ─────────────────────────
        % Separator row 19
        hdr6 = uilabel(advMenuGL, 'Text', 'NEUTRON / REFLECTOMETRY', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
        hdr6.Layout.Row = 20; hdr6.Layout.Column = [1 2];

        advBtn(advMenuGL, 21, 1, 'Spin Asymmetry...', @onAdvAsymmetry, ...
            ['Toggle spin asymmetry calculation (R++ ' char(8722) ' R--) / (R++ + R--) for polarized neutron data']);
        advBtn(advMenuGL, 21, 2, 'Reflectivity Fitting...', @onOpenReflFitDialog, ...
            'Fit specular reflectivity R(Q) via Parratt recursion with layer stack editor');
        advBtn(advMenuGL, 22, 1, 'FFT Thickness...', @onFFTThickness, ...
            'Compute film thickness from Laue / Kiessig fringe periodicity via FFT');
        advBtn(advMenuGL, 22, 2, 'Reflectivity FFT...', @onReflectivityFFT, ...
            ['Compute SLD profile from Kiessig fringes via FFT (Q-space). ' ...
             'Also estimates thickness from fringe spacing.']);
        advBtn(advMenuGL, 23, 1, ['Fringe ' char(916) 't (2-click)...'], @onArmFringeThickness, ...
            ['Pick two fringe peaks to estimate thickness via t = 2' char(960) ...
             '/' char(916) 'Q.  Draggable markers for refinement.']);

        % ── Section: VISUALIZATION & DATA ────────────────────────────
        % Separator row 24
        hdr7 = uilabel(advMenuGL, 'Text', 'VISUALIZATION & DATA', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
        hdr7.Layout.Row = 25; hdr7.Layout.Column = [1 2];

        advBtn(advMenuGL, 26, 1, 'Inset Plot...', @onCreateInset, ...
            'Create an inset zoom of a selected region');
        advBtn(advMenuGL, 26, 2, [char(9998) ' Graph Digitizer...'], @onOpenDigitizer, ...
            'Extract data points from a graph image (screenshot/PDF figure)');

        function advBtn(gl, row, col, txt, cb, tip)
        %ADVBTN  Create a styled button in the advanced menu grid.
            b = uibutton(gl, 'Text', txt, ...
                'ButtonPushedFcn', @(~,~) advMenuAction(cb), ...
                'BackgroundColor', BTN_BG, 'FontColor', BTN_FC, ...
                'HorizontalAlignment', 'left', ...
                'Tooltip', tip);
            b.Layout.Row = row; b.Layout.Column = col;
            allAdvBtns{end+1} = b;  % register for filter (Fix B2)
        end

        function advMenuAction(callbackFcn)
        %ADVMENUACTION  Close the popup then execute the callback.
            closeAdvMenu();
            callbackFcn([], []);
        end

        function onAdvMenuKey(evt)
            if strcmp(evt.Key, 'escape'), closeAdvMenu(); end
        end

        function onAdvFilterChanged()
        %ONADVFILTERCHANGED  Show/hide buttons based on filter text (Fix B2).
            term = lower(strtrim(efAdvFilter.Value));
            for bi = 1:numel(allAdvBtns)
                b = allAdvBtns{bi};
                if ~isvalid(b), continue; end
                if isempty(term)
                    b.Visible = 'on';
                else
                    matches = contains(lower(b.Text), term) || ...
                              contains(lower(b.Tooltip), term);
                    b.Visible = guiTernary(matches, 'on', 'off');
                end
            end
        end
    end

    % ── Advanced Peak Analysis (extracted dialog) ────────────────────────

    function onOpenAdvancedPeakAnalysis(~, ~)
    %ONOPENADVANCEDPEAKANALYSIS  Launch the advanced peak analysis dialog.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Peak Analysis');
            return;
        end
        bosonPlotter.peakAnalysis(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn', @setStatus, ...
            'PeakUpdateCallback', @peakAnalysisApply, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG), ...
            'Appearance',  resolveActiveAppearance());

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
            peakCb.refreshPeakTable();
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

        bosonPlotter.applyDialogTheme(intFig, appData.theme);

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
                if ~headless
                    intFig.Visible = 'on';
                    figure(intFig);
                end
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
        bosonPlotter.curveFitting(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn', @setStatus, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG), ...
            'Appearance',  resolveActiveAppearance());
    end

    function onOpenHysteresisDialog(~, ~)
    %ONOPENHYSTERESISDIALOG  Open hysteresis loop analysis dialog.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Hysteresis');
            return;
        end
        bosonPlotter.hysteresisDialog(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn', @setStatus, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG));
    end

    % ── New analysis callbacks (wiring disconnected +utilities/+fitting functions) ──
    % NOTE: onDescriptiveStats already exists above (data table stats popup).
    %       The Advanced Analysis button calls that existing function.

    function onLinearRegression(~, ~)
    %ONLINEARREGRESSION  Polynomial regression with confidence bands.
        [xV, yV, ~] = getActiveXY();
        if isempty(yV), return; end
        % Prompt for polynomial degree
        answer = inputdlg('Polynomial degree (1 = linear):', 'Regression', 1, {'1'});
        if isempty(answer), return; end
        deg = round(str2double(answer{1}));
        if isnan(deg) || deg < 1 || deg > 10
            uialert(fig, 'Degree must be 1-10.', 'Regression'); return;
        end
        result = utilities.linRegress(xV, yV, 'Degree', deg);
        % Plot regression line on axes
        hold(ax, 'on');
        xFit = linspace(min(xV), max(xV), 500)';
        yFit = polyval(result.coefficients, xFit);
        plot(ax, xFit, yFit, 'r-', 'LineWidth', 1.5, ...
            'DisplayName', sprintf('Poly(%d) R%s=%.4f', deg, char(178), result.R2), ...
            'Tag', 'GUIFitOverlay');
        if isfield(result, 'ciUpper') && ~isempty(result.ciUpper)
            ciUp = polyval(result.ciUpper, xFit);
            ciLo = polyval(result.ciLower, xFit);
            fill(ax, [xFit; flipud(xFit)], [ciUp; flipud(ciLo)], ...
                'r', 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off', 'Tag', 'GUIFitOverlay');
        end
        hold(ax, 'off');
        legend(ax, 'show');
        msg = sprintf('R%s = %.6f,  p = %.4g', char(178), result.R2, result.pValue);
        setStatus(sprintf('Regression: degree=%d  %s', deg, msg));
        uialert(fig, sprintf('Degree %d regression:\n%s\nCoeffs: %s', ...
            deg, msg, mat2str(result.coefficients, 4)), 'Regression', 'Icon', 'info');
        recordAction(sprintf('%% Regression: degree=%d R2=%.4f', deg, result.R2));
    end

    function onTTest(~, ~)
    %ONTTEST  Perform a t-test on the active channel.
        [~, yV, yLbl] = getActiveXY();
        if isempty(yV), return; end
        % Ask for test type
        choice = uiconfirm(fig, ...
            'Select t-test type:', 't-Test', ...
            'Options', {'One-sample (vs 0)', 'One-sample (vs value)', 'Cancel'}, ...
            'DefaultOption', 1, 'CancelOption', 3);
        if strcmp(choice, 'Cancel'), return; end
        if strcmp(choice, 'One-sample (vs value)')
            answer = inputdlg('Test value:', 't-Test', 1, {'0'});
            if isempty(answer), return; end
            mu0 = str2double(answer{1});
        else
            mu0 = 0;
        end
        result = utilities.tTest(yV, [], 'TestType', 'one', 'Mu', mu0);
        msg = sprintf(['t-Test: %s vs %.4g\n' ...
            't-statistic: %.4f\n' ...
            'p-value:     %.6g\n' ...
            'df:          %d\n' ...
            'CI (95%%):    [%.4g, %.4g]\n' ...
            'Significant: %s'], ...
            yLbl, mu0, result.tStat, result.pValue, result.df, ...
            result.ci(1), result.ci(2), ...
            mat2str(result.pValue < 0.05));
        uialert(fig, msg, 't-Test Result', 'Icon', 'info');
        setStatus(sprintf('t-Test: t=%.3f  p=%.4g', result.tStat, result.pValue));
        recordAction(sprintf('%% t-Test: %s vs %.4g, p=%.4g', yLbl, mu0, result.pValue));
    end

    function onConfidenceBand(~, ~)
    %ONCONFIDENCEBAND  Overlay mean+/-std band from multiple datasets.
        if numel(appData.datasets) < 2
            uialert(fig, 'Need at least 2 datasets for confidence bands.', 'Confidence Band');
            return;
        end
        choice = uiconfirm(fig, ...
            'Band type:', 'Confidence Band', ...
            'Options', {'Mean +/- Std', 'Median +/- IQR', 'Cancel'}, ...
            'DefaultOption', 1, 'CancelOption', 3);
        if strcmp(choice, 'Cancel'), return; end
        bandType = 'meanstd';
        if contains(choice, 'Median'), bandType = 'medianiqr'; end
        result = utilities.confidenceBand(appData.datasets, 'Type', bandType);
        hold(ax, 'on');
        fill(ax, [result.x; flipud(result.x)], ...
            [result.upper; flipud(result.lower)], ...
            'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
            'DisplayName', choice, 'Tag', 'GUIFitOverlay');
        plot(ax, result.x, result.center, 'b-', 'LineWidth', 1.5, ...
            'DisplayName', 'Center', 'Tag', 'GUIFitOverlay');
        hold(ax, 'off');
        legend(ax, 'show');
        setStatus(sprintf('Confidence band: %s (%d datasets)', bandType, numel(appData.datasets)));
        recordAction(sprintf('%% Confidence band: %s', bandType));
    end

    function onROIAnalysis(~, ~)
    %ONROIANALYSIS  Open ROI selection and statistics dialog.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'ROI Analysis');
            return;
        end
        bosonPlotter.roiAnalysis(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn', @setStatus);
    end

    function onFFTFilter(~, ~)
    %ONFFTFILTER  Apply FFT filter to active dataset.
        [xV, yV, yLbl] = getActiveXY();
        if isempty(yV), return; end
        % Prompt for filter type and cutoff
        answer = inputdlg({ ...
            'Filter type (lowpass / highpass / bandpass / notch):', ...
            'Cutoff frequency (Hz, or [low high] for bandpass/notch):'}, ...
            'FFT Filter', [1 50; 1 50], {'lowpass', '0.1'});
        if isempty(answer), return; end
        filterType = strtrim(answer{1});
        cutoffStr = strtrim(answer{2});
        % Parse cutoff safely (no eval): supports "0.1" or "0.01 0.5"
        cutoff = str2double(strsplit(strtrim(cutoffStr)));
        cutoff = cutoff(~isnan(cutoff));
        if isempty(cutoff)
            uialert(fig, 'Invalid cutoff value.', 'FFT Filter'); return;
        end
        result = utilities.fftFilter(xV, yV, 'Type', filterType, 'Cutoff', cutoff);
        % Replace active Y channel with filtered data
        ds = appData.datasets{appData.activeIdx};
        ySel = ensureCell(lbY.Value);
        idx = find(strcmp(ds.data.labels, ySel{1}), 1);
        if ~isempty(idx)
            ds.data.values(:, idx) = result.filtered;
            appData.datasets{appData.activeIdx} = ds;
            try
                appData.model.updateDataset(appData.activeIdx, ds);
            catch
            end
            onPlot([], []);
            setStatus(sprintf('FFT filter: %s (cutoff=%s) applied to %s', filterType, cutoffStr, yLbl));
        end
        recordAction(sprintf('%% FFT filter: %s cutoff=%s on %s', filterType, cutoffStr, yLbl));
    end

    function onBatchFit(~, ~)
    %ONBATCHFIT  Fit the same model across all loaded datasets.
        if numel(appData.datasets) < 2
            uialert(fig, 'Need at least 2 datasets for batch fitting.', 'Batch Fit');
            return;
        end
        % Open the curve fit dialog for the active dataset, then use its
        % result to batch-fit all datasets.
        setStatus('Batch Fit: first configure a fit on the active dataset using Curve Fit dialog...');
        onOpenCurveFitDialog([], []);
    end

    function onGlobalFit(~, ~)
    %ONGLOBALFIT  Fit multiple datasets simultaneously with shared parameters.
        if numel(appData.datasets) < 2
            uialert(fig, 'Need at least 2 datasets for global fitting.', 'Global Fit');
            return;
        end
        setStatus('Global Fit: first configure a model via Curve Fit, then apply globally...');
        onOpenCurveFitDialog([], []);
    end

    function onTrackPeak(~, ~)
    %ONTRACKPEAK  Track peak position across a dataset series.
        if numel(appData.datasets) < 2
            uialert(fig, 'Need at least 2 datasets for peak tracking.', 'Track Peak');
            return;
        end
        answer = inputdlg('Seed peak position (x value):', 'Track Peak', 1, {'0'});
        if isempty(answer), return; end
        seedPos = str2double(answer{1});
        if isnan(seedPos)
            uialert(fig, 'Invalid position.', 'Track Peak'); return;
        end
        try
            result = fitting.trackPeak(appData.datasets, seedPos);
            % Plot tracked positions
            hold(ax, 'on');
            plot(ax, 1:numel(result.positions), result.positions, 'ro-', ...
                'LineWidth', 1.5, 'DisplayName', 'Peak Track', ...
                'Tag', 'GUIFitOverlay');
            hold(ax, 'off');
            setStatus(sprintf('Peak tracked across %d datasets: %.4g to %.4g', ...
                numel(result.positions), result.positions(1), result.positions(end)));
        catch ME
            uialert(fig, sprintf('Track Peak failed:\n%s', ME.message), 'Error');
        end
        recordAction(sprintf('%% Track peak: seed=%.4g', seedPos));
    end

    function [xV, yV, yLbl] = getActiveXY()
    %GETACTIVEXY  Extract x,y vectors and label for the active dataset/channel.
        xV = []; yV = []; yLbl = '';
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'No Data');
            return;
        end
        ds = appData.datasets{appData.activeIdx};
        d = ds.data;
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
        xV = d.time;
        yV = d.values(:, yIdx);
        yLbl = d.labels{yIdx};
        % Remove NaN/NaT
        if isdatetime(xV)
            valid = ~isnat(xV) & ~isnan(yV);
            xV = datenum(xV(valid)); %#ok<DATNM>
        else
            valid = ~isnan(xV) & ~isnan(yV);
            xV = xV(valid);
        end
        yV = yV(valid);
    end

    function onOpenReflFitDialog(~, ~)
    %ONOPENREFLFITDIALOG  Open reflectivity fitting dialog (Parratt recursion).
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Reflectivity Fit');
            return;
        end
        bosonPlotter.reflFitting(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn', @setStatus, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG), ...
            'Appearance',  resolveActiveAppearance());
    end

    % ── Graph Digitizer ────────────────────────────────────────────────

    function onOpenDigitizer(~, ~)
    %ONOPENDIGITIZER  Delegates to bosonPlotter.graphDigitizer.
        bosonPlotter.graphDigitizer( ...
            'LoadCallback', @digLoadDataset, ...
            'StatusFcn', @setStatus, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG));
        function digLoadDataset(data)
            newDS = buildDs('[Digitized]', data, 'digitizer');
            appData.datasets{end+1} = newDS;
            appData.activeIdx = numel(appData.datasets);
            try
                appData.model.addDataset(newDS.data, newDS.filepath, newDS.parserName);
            catch
            end
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
    %ONPLOTTEMPLATES  Delegate to extracted +bosonPlotter module.
        bosonPlotter.plotTemplates(appData, fig, ui, ptCb_);
    end

    % ── Batch Figure Export ────────────────────────────────────────────

    function onBatchFigureExport(~,~)
    %ONBATCHFIGUREEXPORT  Delegates to bosonPlotter.batchFigureExport.
        bosonPlotter.batchFigureExport(appData.datasets, fig, ...
            @getPlotData, @setStatus, ...
            struct('primary', BTN_PRIMARY, 'fg', BTN_FG));
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
    %ONADVANCEDFIGUREBUILDER  Delegates to bosonPlotter.figureBuilder.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig,'Load at least one file first.','No data'); return;
        end
        bosonPlotter.figureBuilder(appData.datasets, appData.activeIdx, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG), ...
            'Appearance',   resolveActiveAppearance());
    end  % onAdvancedFigureBuilder

    if nargout > 0
        varargout{1} = api;
    end

end  % BosonPlotter


% ════════════════════════════════════════════════════════════════════════
%  Module-level helpers  (stateless — no access to GUI handles)
% ════════════════════════════════════════════════════════════════════════

function filterGridButtons(gl, query)
%FILTERGRIDBUTTONS  Show/hide buttons in a uigridlayout by text match.
%   Hides rows containing buttons whose Text doesn't match the query.
%   Empty query shows all. Used by the Advanced Tools filter bar.
    allBtns = findall(gl, 'Type', 'uibutton');
    q = lower(strtrim(query));
    for bi = 1:numel(allBtns)
        b = allBtns(bi);
        if isempty(q)
            b.Visible = 'on';
        elseif contains(lower(b.Text), q) || contains(lower(b.Tooltip), q)
            b.Visible = 'on';
        else
            b.Visible = 'off';
        end
    end
end

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


