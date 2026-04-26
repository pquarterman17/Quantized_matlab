function clearOverlays(appData, ax)
%CLEAROVERLAYS  Remove all interactive overlays from the plot axes and
%               reset the associated appData state fields.
%
% Syntax
%   bosonPlotter.clearOverlays(appData, ax)
%
% Behaviour
%   User-triggered global clear for overlays that linger past their
%   originating interaction.  The canonical case: reflectivity fringe-
%   thickness markers and labels stay on the plot after the dataset is
%   removed because cla() does not touch HandleVisibility='off' objects.
%
%   Deletes (by Tag) every overlay class known to the GUI:
%     - Fringe markers / annotation / span
%     - Peak annotations, phase ticks/labels, peak decomposition curves
%     - SNIP background preview
%     - Zoom / background-fit / mask / box-integration rubber bands
%     - Masked-point overlays and reference lines
%     - User annotations (text tool)
%     - Smoothing live preview
%
%   Then resets the appData state fields that drive overlay redraw, so
%   the next onPlot() does not re-materialize stale markers.
%
%   Cursor readouts (GUICursorReadout) are preserved — they are the
%   live readout panel, not a user-placed overlay.
%
% Inputs
%   appData - bosonPlotter.AppState handle
%   ax      - Main plot axes handle

    % ── Delete overlay graphics by tag ────────────────────────────────
    overlayTags = { ...
        'GUIFringeMarker', 'GUIFringeAnnotation', 'GUIFringeSpan', ...
        'GUIPeakAnnotation', 'GUIPeakDecomp', ...
        'GUIPhaseTickMark', 'GUIPhaseLabel', ...
        'GUISNIPBackground', ...
        'GUIZoomBox', ...
        'GUIBoxIntBox', 'GUIBoxIntPreview', 'GUIBoxIntCompleted', ...
        'GUIMaskBox', 'GUIMaskedPoints', ...
        'GUIUserAnnotation', ...
        'GUIRefLine', ...
        'GUISmoothPreview', ...
        'GUIFitOverlay', ...
        'peakFitWindow'};
    for ti = 1:numel(overlayTags)
        delete(findall(ax, 'Tag', overlayTags{ti}));
    end

    % ── Reset fringe-thickness state ──────────────────────────────────
    appData.fringeMarkers    = [];
    appData.fringeAnnotation = [];
    appData.fringeQ          = [];
    appData.fringeClickCount = 0;
    appData.fringeDragIdx    = 0;

    % ── Reset zoom-rubber-band state ──────────────────────────────────
    appData.zoomRectPatch = [];
    appData.zoomStartPt   = [];

    % ── Reset background-fit rubber-band state ────────────────────────
    appData.bgRectPatch = [];
    appData.bgStartPt   = [];

    % ── Reset mask rubber-band state ──────────────────────────────────
    appData.maskRectPatch = [];
    appData.maskStartPt   = [];

    % ── Reset box-integration state ───────────────────────────────────
    appData.boxIntStartPt         = [];
    appData.boxIntPatch           = [];
    appData.boxPreviewPatch       = [];
    appData.boxIntCompletedPatch  = [];
    appData.boxIntCompletedRegion = [];

    % ── Reset Y-origin pick state ─────────────────────────────────────
    appData.yOriginMarker     = [];
    appData.yOriginClickCount = 0;
    appData.yOriginPt1        = [];

    % ── Reset cursor marker state (panel readout stays live) ──────────
    appData.cursorMarker      = [];
    appData.cursorMarker2     = [];
    appData.cursorLabel       = [];
    appData.cursorDeltaLabel  = [];
    appData.cursorLine        = [];
    appData.cursorText        = [];
    appData.cursorPt1         = [];
    appData.cursorPinned      = {};
    appData.cursorClickCount  = 0;

    % ── Reset smoothing preview ───────────────────────────────────────
    appData.smoothPreviewLine = [];
end
