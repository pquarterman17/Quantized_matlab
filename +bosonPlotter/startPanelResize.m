function startPanelResize(appData, fig, widgets, callbacks)
%STARTPANELRESIZE  Arm a live drag-resize for one of the five panel borders.
%
% Syntax
%   bosonPlotter.startPanelResize(appData, fig, widgets, callbacks)
%
% Behaviour
%   Called by `onAxesButtonDown` when the user mouse-downs on a panel
%   border that `onMouseHover` has tagged in `appData.panelResizeDir`.
%   Snapshots the current pixel-size of the panel being resized so that
%   relative-motion-to-pixel-delta conversion works correctly, then
%   installs motion and up handlers so the border tracks the mouse
%   until release.  Five resize directions are supported:
%     'h_row12'       - analysis panel height (above/below preview)
%     'v_col12'       - corrections panel width
%     'v_col23'       - save/export panel width (col 4)
%     'v_content12'   - file list panel width (col 1)
%     'v_content23'   - controls panel width (col 2)
%
% Inputs
%   appData    - bosonPlotter.AppState handle (reads panelResizeDir, MIN_*;
%                   mutates panelResizeStart, panelResizeOrig, corrPanelWidth)
%   fig        - Main figure handle (reads CurrentPoint; window callback owner)
%   widgets    - Widget struct with fields:
%                   .rootGL, .analysisGL, .contentGL,
%                   .analysisPanel, .corrPanel, .savePanel,
%                   .fileListPanel, .ctrlPanel
%   callbacks  - Struct of function handles:
%                   .onMouseHover(src, evt)

    mp = fig.CurrentPoint;
    appData.panelResizeStart = mp;
    switch appData.panelResizeDir
        case 'h_row12'
            try
                aPos = getpixelposition(widgets.analysisPanel, true);
                appData.panelResizeOrig = aPos(4);
            catch
                rh = widgets.rootGL.RowHeight;
                appData.panelResizeOrig = guiTernary(isnumeric(rh{2}), rh{2}, 300);
            end
        case 'v_col12'
            try
                cPos = getpixelposition(widgets.corrPanel, true);
                appData.panelResizeOrig = cPos(3);
            catch
                appData.panelResizeOrig = appData.corrPanelWidth;
            end
        case 'v_col23'
            try
                sPos = getpixelposition(widgets.savePanel, true);
                appData.panelResizeOrig = sPos(3);
            catch
                cw = widgets.analysisGL.ColumnWidth;
                appData.panelResizeOrig = guiTernary(isnumeric(cw{4}), cw{4}, 210);
            end
        case 'v_content12'
            try
                flPos = getpixelposition(widgets.fileListPanel, true);
                appData.panelResizeOrig = flPos(3);
            catch
                cw = widgets.contentGL.ColumnWidth;
                appData.panelResizeOrig = guiTernary(isnumeric(cw{1}), cw{1}, 180);
            end
        case 'v_content23'
            try
                cpPos = getpixelposition(widgets.ctrlPanel, true);
                appData.panelResizeOrig = cpPos(3);
            catch
                cw = widgets.contentGL.ColumnWidth;
                appData.panelResizeOrig = guiTernary(isnumeric(cw{2}), cw{2}, 190);
            end
    end
    fig.WindowButtonMotionFcn = @(s,e) localMove(appData, fig, widgets);
    fig.WindowButtonUpFcn     = @(s,e) localUp(appData, fig, callbacks);
end

function localMove(appData, fig, widgets)
    if isempty(appData.panelResizeStart), return; end
    mp = fig.CurrentPoint;

    switch appData.panelResizeDir
        case 'h_row12'
            delta_y = mp(2) - appData.panelResizeStart(2);
            figH    = fig.Position(4);
            availH  = figH - 12 - 8 - 16;
            newH    = round(appData.panelResizeOrig + delta_y);
            newH    = max(appData.MIN_ANALYSIS_H, min(newH, availH - appData.MIN_PREVIEW_H));
            widgets.rootGL.RowHeight = {'1x', newH, 16};

        case 'v_col12'
            delta_x = mp(1) - appData.panelResizeStart(1);
            newW    = round(appData.panelResizeOrig + delta_x);
            newW    = max(appData.MIN_CORR_W, min(newW, 600));
            appData.corrPanelWidth = newW;
            cw    = widgets.analysisGL.ColumnWidth;
            cw{1} = newW;
            widgets.analysisGL.ColumnWidth = cw;

        case 'v_col23'
            delta_x = mp(1) - appData.panelResizeStart(1);
            newW    = round(appData.panelResizeOrig - delta_x);
            newW    = max(140, min(newW, 400));
            cw    = widgets.analysisGL.ColumnWidth;
            cw{4} = newW;
            widgets.analysisGL.ColumnWidth = cw;

        case 'v_content12'
            delta_x = mp(1) - appData.panelResizeStart(1);
            newW    = round(appData.panelResizeOrig + delta_x);
            newW    = max(120, min(newW, 350));
            cw    = widgets.contentGL.ColumnWidth;
            cw{1} = newW;
            widgets.contentGL.ColumnWidth = cw;

        case 'v_content23'
            delta_x = mp(1) - appData.panelResizeStart(1);
            newW    = round(appData.panelResizeOrig + delta_x);
            newW    = max(140, min(newW, 350));
            cw    = widgets.contentGL.ColumnWidth;
            cw{2} = newW;
            widgets.contentGL.ColumnWidth = cw;
    end
end

function localUp(appData, fig, callbacks)
    fig.WindowButtonMotionFcn = callbacks.onMouseHover;
    fig.WindowButtonUpFcn     = '';
    appData.panelResizeStart  = [];
    appData.panelResizeOrig   = [];
end

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end
