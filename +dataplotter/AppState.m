classdef AppState < handle
%APPSTATE  Shared GUI state for DataPlotter (handle class).
%
%   state = dataplotter.AppState()
%
%   Replaces the appData struct with a handle class.  Because handle
%   objects are passed by reference, extracted +dataplotter/ functions
%   can mutate state without return-value gymnastics:
%
%       function applyCorrections(state, params)
%           state.datasets{state.activeIdx}.corrData = ...;
%       end
%
%   All property defaults match the original struct initialization in
%   DataPlotter.m.  The DataPlotter main function assigns to appData =
%   dataplotter.AppState(), and all existing appData.X references work
%   unchanged.

    properties
        % ── Core data ──────────────────────────────────────────────
        datasets        cell   = {}
        activeIdx       double = 0
        lastDir         char   = ''
        searchFilter    char   = ''

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
        boxIntStartPt   double  = []
        boxIntPatch               = []
        boxIntMode      logical = false
        boxPreviewPatch           = []

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
        tableEdited     logical = false
        tableRowCap     double  = 500
        tableSelection  double  = []   % [Nx2] selected cells from CellSelectionCallback

        % ── Collapsible sections ───────────────────────────────────
        sectionCollapsed struct = struct( ...
            'offsets', false, 'processing', false, ...
            'bgFile', true, 'magSample', true, ...
            'saveTools', true, 'originExcel', true, ...
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
        datasetGroups             = []   % containers.Map (initialized in DataPlotter)
    end

    methods
        function obj = AppState()
            %APPSTATE  Construct with defaults (all set via property defaults above).
            %   The macroLog is created lazily by DataPlotter after construction
            %   to avoid dependency ordering issues.
        end
    end
end
