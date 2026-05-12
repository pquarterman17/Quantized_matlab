function onYTranslateDrag(appData, fig, ax, widgets, callbacks)
%ONYTRANSLATEDRAG  Arm a click-and-drag to shift XRD data vertically in real time.
%
% Syntax
%   bosonPlotter.onYTranslateDrag(appData, fig, ax, widgets, callbacks)
%
% Behaviour
%   Invoked by the "Y Translate (drag)" button in the XRD Corrections
%   panel.  Cancels any in-flight interaction via
%   `callbacks.cancelInteractions`, repaints the translate button into
%   its active "armed" state (blue, disabled while armed), and installs
%   `WindowButtonDownFcn` on the figure so the next mouse click in the
%   axes initiates the drag.  When the user clicks, presses, and
%   releases, the internal Down/Move/Up helpers below take over:
%     * Down   - records the initial mouse y-value and current yOffset
%                so relative motion can be converted back to yOffset
%                units, then installs motion + up handlers.
%     * Move   - converts the current mouse delta to a yOffset update
%                (moving data UP reduces yOffset because the correction
%                pipeline computes `y_corrected = yRaw - BG - yOff`)
%                and re-runs `onApplyCorrections` so the plot tracks
%                the drag live.
%     * Up     - restores the default button/motion/up handlers, clears
%                the stored start point, and repaints the translate
%                button back to its idle style.
%
% Inputs
%   appData    - bosonPlotter.AppState handle (reads datasets / activeIdx;
%                   mutates yTranslateY0 / yTranslateOff0)
%   fig        - Main figure handle (window callback owner; uialert parent)
%   ax         - Main axes handle (reads CurrentPoint, XLim, YLim)
%   widgets    - Widget struct with fields:
%                   .btnYTranslate, .btnAutoPeak, .btnManualPeak, .efYOffset,
%                   .BTN_ACCENT (idle color for the translate button)
%   callbacks  - Struct of function handles:
%                   .cancelInteractions()
%                   .onApplyCorrections(src, evt)
%                   .onAxesButtonDown(src, evt)
%                   .onMouseHover(src, evt)

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig,'Load a file first.','No data'); return;
    end
    callbacks.cancelInteractions();
    widgets.btnYTranslate.Text            = 'Drag on plot to translate...';
    widgets.btnYTranslate.BackgroundColor = [0.00 0.55 0.80];
    widgets.btnYTranslate.Enable          = 'off';
    widgets.btnAutoPeak.Enable            = 'off';
    widgets.btnManualPeak.Enable          = 'off';
    fig.WindowButtonDownFcn = @(s,e) localDown(appData, fig, ax, widgets, callbacks);
end

function localDown(appData, fig, ax, widgets, callbacks)
    cp = ax.CurrentPoint;
    x0 = cp(1,1);  y0 = cp(1,2);
    if x0 < ax.XLim(1) || x0 > ax.XLim(2) || ...
       y0 < ax.YLim(1) || y0 > ax.YLim(2)
        return;
    end
    appData.yTranslateY0   = y0;
    appData.yTranslateOff0 = widgets.efYOffset.Value;
    fig.Pointer = 'fleur';
    fig.WindowButtonMotionFcn = @(s,e) localMove(appData, ax, widgets, callbacks);
    fig.WindowButtonUpFcn     = @(s,e) localUp(appData, fig, widgets, callbacks);
end

function localMove(appData, ax, widgets, callbacks)
    if isempty(appData.yTranslateY0), return; end
    cp = ax.CurrentPoint;
    dy = cp(1,2) - appData.yTranslateY0;
    widgets.efYOffset.Value = appData.yTranslateOff0 - dy;
    try
        callbacks.onApplyCorrections([],[]);
    catch
    end
end

function localUp(appData, fig, widgets, callbacks)
    fig.WindowButtonDownFcn   = callbacks.onAxesButtonDown;
    fig.WindowButtonMotionFcn = callbacks.onMouseHover;
    fig.WindowButtonUpFcn     = '';
    fig.Pointer = 'arrow';
    appData.yTranslateY0 = [];
    widgets.btnYTranslate.Text            = 'Y Translate (drag)';
    widgets.btnYTranslate.BackgroundColor = widgets.BTN_ACCENT;
    widgets.btnYTranslate.Enable          = 'on';
    widgets.btnAutoPeak.Enable            = 'on';
    widgets.btnManualPeak.Enable          = 'on';
end
