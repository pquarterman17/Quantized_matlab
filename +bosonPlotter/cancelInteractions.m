function cancelInteractions(appData, fig, widgets, callbacks)
%CANCELINTERACTIONS  Abort any in-progress interaction (BG-fit, zoom, etc.).
%
% Syntax
%   bosonPlotter.cancelInteractions(appData, fig, widgets, callbacks)
%
% Behaviour
%   Restores the figure to "normal mode":
%     - Rewires WindowButtonDown/Motion/Up handlers to their default
%       state (@onAxesButtonDown / @onMouseHover / '').
%     - Cursor reset to 'arrow'.
%     - Clears all in-progress interaction patches (BG rect, zoom rect,
%       mask rect, box integration rect) and their start points.
%     - Resets panel-resize, listbox-drag, fringe-click, Y-translate,
%       Y-origin pick, and peak-pick state tracked on appData.
%     - Re-enables the tool buttons (Mask Select, Fringe Δt, Fit BG,
%       Est Y Offset, Y Translate, Auto Peak, Manual Peak, Click-Rm)
%       and restores their default text/background colours.
%     - Clears the region-statistics label.
%
%   Used at the start of every new interaction and whenever state
%   could otherwise leak between modes (session load, dataset switch,
%   correction apply, etc.).
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutates ~15 fields)
%   fig       - Main figure handle (rewires three callbacks + pointer)
%   widgets   - Struct with button/label handles:
%                 .btnMaskSelect, .btnFringeThick, .btnFitBG,
%                 .btnPickY, .btnYTranslate, .btnAutoPeak,
%                 .btnManualPeak, .btnRemovePeakClick,
%                 .lblRegionStats
%   callbacks - Struct of function handles + color constants:
%                 .onAxesButtonDown      - figure WindowButtonDownFcn
%                 .onMouseHover          - figure WindowButtonMotionFcn
%                 .clearBoxPreview()
%                 .clearCompletedBoxPatch()
%                 .clearFringeMarkers()
%                 .BTN_ACCENT  (RGB triplet, default accent colour)
%                 .BTN_DANGER  (RGB triplet, default danger colour)
%                 .BTN_INTERACT(RGB triplet, default interact colour)

    fig.WindowButtonDownFcn   = callbacks.onAxesButtonDown;
    fig.WindowButtonMotionFcn = callbacks.onMouseHover;
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
    widgets.lblRegionStats.Text = '';  % Clear region statistics display
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
    callbacks.clearBoxPreview();
    callbacks.clearCompletedBoxPatch();
    widgets.btnMaskSelect.Text            = 'Mask Selection';
    widgets.btnMaskSelect.BackgroundColor = [0.60 0.15 0.15];
    widgets.btnMaskSelect.Enable          = 'on';
    % Reset fringe thickness pick mode (but keep existing markers)
    if appData.fringeClickCount > 0 && appData.fringeClickCount < 2
        callbacks.clearFringeMarkers();
    end
    appData.fringeDragIdx     = 0;
    widgets.btnFringeThick.Text            = ['Fringe ' char(916) 't (2-click)'];
    widgets.btnFringeThick.BackgroundColor = callbacks.BTN_ACCENT;
    widgets.btnFringeThick.Enable          = 'on';
    appData.lastClickTic      = uint64(0);
    if ~isempty(appData.yOriginMarker) && isvalid(appData.yOriginMarker)
        delete(appData.yOriginMarker);
    end
    appData.yOriginMarker     = [];
    appData.yOriginClickCount = 0;
    appData.yOriginPt1        = [];
    widgets.btnFitBG.Text            = 'Fit Linear BG from Box';
    widgets.btnFitBG.BackgroundColor = callbacks.BTN_INTERACT;
    widgets.btnFitBG.Enable          = 'on';
    widgets.btnPickY.Text   = 'Est. Y Offset  (2 pts)';
    widgets.btnPickY.Enable = 'on';
    % Reset Y-translate state
    appData.yTranslateY0   = [];
    appData.yTranslateOff0 = 0;
    widgets.btnYTranslate.Text            = 'Y Translate (drag)';
    widgets.btnYTranslate.BackgroundColor = callbacks.BTN_ACCENT;
    widgets.btnYTranslate.Enable          = 'on';
    widgets.btnAutoPeak.Enable            = 'on';
    % Reset manual peak-pick mode
    if appData.peakPickMode
        appData.peakPickMode = false;
        widgets.btnManualPeak.Text            = 'Add Peak';
        widgets.btnManualPeak.BackgroundColor = [0.45 0.20 0.55];
    end
    widgets.btnManualPeak.Enable = 'on';
    % Reset peak-remove click mode
    if appData.peakRemoveMode
        appData.peakRemoveMode = false;
        widgets.btnRemovePeakClick.Text            = 'Click-Rm';
        widgets.btnRemovePeakClick.BackgroundColor = callbacks.BTN_DANGER;
    end
    widgets.btnRemovePeakClick.Enable = 'on';
end
