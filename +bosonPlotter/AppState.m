classdef AppState < handle
%APPSTATE  Shared GUI state for BosonPlotter (handle class).
%
%   state = bosonPlotter.AppState()
%
%   Replaces the appData struct with a handle class.  Because handle
%   objects are passed by reference, extracted +bosonPlotter/ functions
%   can mutate state without return-value gymnastics:
%
%       function applyCorrections(state, params)
%           state.datasets{state.activeIdx}.corrData = ...;
%       end
%
%   All property defaults match the original struct initialization in
%   BosonPlotter.m.  The BosonPlotter main function assigns to appData =
%   bosonPlotter.AppState(), and all existing appData.X references work
%   unchanged.

    properties
        % ── Core data ──────────────────────────────────────────────
        datasets        cell   = {}
        activeIdx       double = 0
        lastDir         char   = ''
        searchFilter    char   = ''
        model                  = []   % dataWorkspace.WorkspaceModel (shared with DataWorkspace)

        % ── Correction state ───────────────────────────────────────
        style           char   = 'auto'
        bgDataset                = []
        bgFile          char   = ''
        bgXVecRaw                = []

        % ── Peak state ─────────────────────────────────────────────
        peakMode        char   = 'none'
        peakPickMode    logical = false
        peakRemoveMode  logical = false
        selectedPeakIdx double  = 0

        % ── Fit display ────────────────────────────────────────────
        showFitCurves   logical = true
        showSnipBg      logical = true
        fitCurveColor   double  = [0.85 0.20 0.00]
        kFactor         double  = 0.9
        instBroadening_deg double = 0

        % ── Axis prefixes ──────────────────────────────────────────
        axisPrefixX     struct = struct('symbol','','factor',1)
        axisPrefixY     struct = struct('symbol','','factor',1)
        prefixNames     cell   = {}
        prefixSymbols   cell   = {}
        prefixFactors   double = []

        % ── Panel resize ───────────────────────────────────────────
        panelResizeDir    char   = ''
        panelResizeStart  double = []
        panelResizeOrig   double = []
        corrPanelWidth    double = 320
        axLimPanelWidth   double = 200

        % ── Min panel dimensions ───────────────────────────────────
        MIN_CORR_W      double = 280
        MIN_AXLIM_W     double = 180
        MIN_PREVIEW_H   double = 150
        MIN_ANALYSIS_H  double = 180

        % ── List drag-reorder ──────────────────────────────────────
        listDragSrcIdx  double  = 0
        listDragActive  logical = false
        listDragStartPt double  = []

        % ── Zoom ───────────────────────────────────────────────────
        zoomRectPatch             = []
        zoomStartPt     double  = []
        lastClickTic    uint64  = uint64(0)

        % ── Background fit ─────────────────────────────────────────
        bgRectPatch               = []
        bgStartPt       double  = []

        % ── Mask selection ─────────────────────────────────────────
        maskRectPatch             = []
        maskStartPt     double  = []

        % ── Box integration (2D map) ─────────────────────────────
        boxIntStartPt          double  = []
        boxIntPatch                      = []
        boxIntMode             logical = false
        boxPreviewPatch                  = []
        boxIntCompletedPatch             = []
        boxIntCompletedRegion  double  = []   % [xLo xHi yLo yHi] — survives redraw

        % ── Y-translate drag ───────────────────────────────────────
        yTranslateY0    double  = 0
        yTranslateOff0  double  = 0

        % ── Y-origin pick ──────────────────────────────────────────
        yOriginClickCount double = 0
        yOriginMarker             = []
        yOriginPt1      double  = []

        % ── Data cursor ────────────────────────────────────────────
        cursorActive    logical = false
        cursorClickCount double = 0
        cursorMarker              = []
        cursorMarker2             = []
        cursorLabel               = []
        cursorDeltaLabel          = []
        cursorLine                = []
        cursorText                = []
        cursorPt1       double  = []
        cursorPinned    cell    = {}   % pinned marker graphics (Ctrl+click)

        % ── Fringe thickness ───────────────────────────────────────
        fringeMarkers             = []
        fringeClickCount double  = 0
        fringeDragIdx   double  = 0
        fringeQ         double  = []
        fringeAnnotation          = []

        % ── Inset zoom ─────────────────────────────────────────────
        insetAx                   = []

        % ── Data table ─────────────────────────────────────────────
        tableVisible    logical = true
        tableWorkingCopy double = []
        tableUnits      cell   = {}
        tableMask       logical = logical([])
        filterMask      logical = logical([])  % [N×1] logical from filter bar; [] = no filter
        tableEdited     logical = false
        tableRowCap     double  = 500
        tableSelection  double  = []   % [Nx2] selected cells from CellSelectionCallback

        % ── Collapsible sections ───────────────────────────────────
        sectionCollapsed struct = struct( ...
            'offsets', false, 'processing', false, ...
            'bgFile', true, 'magSample', true, ...
            'saveTools', false, 'originExcel', true, ...
            'advancedPeak', true, 'axAppearance', true)
        sectionHeaders   struct = struct()

        % ── Save section ───────────────────────────────────────────
        saveSectionRows          = []   % struct (row indices per section)
        saveSectionHeights       = []   % struct (heights per section)

        % ── Annotation mode ────────────────────────────────────────
        annotationMode   char   = 'none'

        % ── Overlay mode ───────────────────────────────────────────
        overlayMode      char   = 'overlay'

        % ── Waterfall gradient ─────────────────────────────────────
        wfGradient       logical = false

        % ── Animation timer ────────────────────────────────────────
        animTimer                 = []

        % ── Auto-recalculate debounce timer ────────────────────────
        autoRecalcTimer           = []

        % ── Theme ──────────────────────────────────────────────────
        theme            char   = 'dark'

        % ── Neutron asymmetry ──────────────────────────────────────
        asymmetryPrevLogY logical = false

        % ── Line cache (optimization) ─────────────────────────────
        lineCache                 = []
        map2DHandle               = []   % cached graphics handle for 2D heatmap

        % ── Macro recording ────────────────────────────────────────
        macroLog                  = []
        macroRecording  logical = false

        % ── Dataset groups ────────────────────────────────────────
        datasetGroups             = []   % containers.Map (initialized in BosonPlotter)

        % ── Toolbar configuration ─────────────────────────────────
        toolbarConfig    cell   = {}    % {1×N} ordered action IDs; {} = use default

        % ── Column-to-plot drag state ─────────────────────────────
        columnDragActive   logical = false  % true while ghost is visible
        columnDragColName  char    = ''     % name of column being dragged
        columnDragGhost              = []   % floating uilabel ghost handle
        columnDragPending  logical = false  % mouse down in table header, not yet moved
        columnDragStartPx  double  = []     % [x y] fig-pixel coords of button-down

        % ── Undo/redo manager ─────────────────────────────────────
        undoMgr                      = []   % bosonPlotter.UndoManager instance

        % ── Data connectors (live file reload) ────────────────────
        dataConnectors  cell   = {}    % {1×N} scripts.dataConnector structs, indexed by dataset slot

        % ── Smoothing live preview ─────────────────────────────────
        smoothPreviewLine            = []   % line handle for dashed smooth overlay; [] when inactive

        % ── Recent files ───────────────────────────────────────────
        recentFiles     cell   = {}    % {1×N} full paths, most recent first; persisted to prefdir

        % ── Visual style (Phase A) ─────────────────────────────────
        % activeTemplate names a built-in template from styles.template()
        % or a user template (prefixed 'user:'); styleOverrides is a
        % sparse struct of fields that win over the template.  Resolved
        % into rCtx_.appearance by drawToAxes via bosonPlotter.resolveStyle.
        activeTemplate   char   = 'screen'
        styleOverrides   struct = struct()

        % ── Undo/redo callbacks (assigned post-widget-construction) ──
        % Populated by bosonPlotter.undoCallbacks() after btnUndo/btnRedo
        % exist.  Exposes .onUndo(s,e), .onRedo(s,e), .updateUndoButtons().
        undoCb                  = []

        % ── Advanced Tools popup figure ───────────────────────────────
        advMenuFig                = []

        % ── Plot Options popup figure ────────────────────────────────
        plotOptFig                = []
    end

    methods
        function obj = AppState()
            %APPSTATE  Construct with defaults (all set via property defaults above).
            %   The macroLog is created lazily by BosonPlotter after construction
            %   to avoid dependency ordering issues.
        end
    end
end
