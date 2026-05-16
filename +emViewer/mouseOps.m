function appData = mouseOps(action, appData, ctx)
%MOUSEOPS  Mouse interaction handlers for FermiViewer -- extracted from main closure.
%
% Syntax:
%   appData = emViewer.mouseOps(action, appData, ctx)
%
% Actions:
%   'motion'            -- onMouseMotion: track cursor, show pixel info
%   'axesDown'          -- onAxesMouseDown: box-zoom, pan, double-click reset
%   'idleDown'          -- onIdleMouseDown: figure-level idle click
%   'buildContextMenus' -- build right-click menus for image/list
%   'buildContextMenu'  -- build simple axes context menu (Feature 20)
%
% ctx struct fields:
%   .fig               -- uifigure handle
%   .ax                -- main image axes handle
%   .lbImages          -- image listbox handle
%   .lblStatusMouse    -- status label for pixel coordinates
%   .cbPixelInspector  -- checkbox for pixel inspector enable
%   .cb.detectResizeBorder    -- @detectResizeBorder
%   .cb.startPanelResize      -- @startPanelResize
%   .cb.deselectMeasurement   -- @deselectMeasurement
%   .cb.highlightAnnotation   -- @highlightAnnotation
%   .cb.onZoomBox             -- @onZoomBox
%   .cb.onResetZoom           -- @onResetZoom
%   .cb.onZoomFit             -- @onZoomFit
%   .cb.onZoomActual          -- @onZoomActual
%   .cb.onZoomOut             -- @onZoomOut
%   .cb.togglePanMode         -- @() wrapper that reads current appData.panMode
%   .cb.onExportAction        -- @onExportAction
%   .cb.contextToggleScaleBar -- @contextToggleScaleBar
%   .cb.onClearOverlays       -- @onClearOverlays
%   .cb.onOpenFiles           -- @onOpenFiles
%   .cb.onRenameSelected      -- @onRenameSelected
%   .cb.onRemoveImage         -- @onRemoveImage
%   .cb.onBoxZoomDrag         -- @onBoxZoomDrag
%   .cb.onBoxZoomRelease      -- @onBoxZoomRelease
%   .cb.attachImageContextMenu -- @attachImageContextMenu
%   .cb.onAutoContrast        -- @onAutoContrast
%   .cb.onArmDistance         -- @onArmDistance
%   .cb.onArmLineProfile      -- @onArmLineProfile
%   .cb.onArmROIStats         -- @onArmROIStats
%   .cb.refreshState          -- @refreshState
%   .cb.cancelCapture         -- @cancelCapture
%   .cb.onContrastChanged     -- @onContrastChanged
%   .cb.updatePixelInspector  -- @updatePixelInspector
%
% Inputs:
%   action   -- char, one of the action strings above
%   appData  -- FermiViewer appData struct (modified in-place for some fields)
%   ctx      -- context struct with handles and callbacks (see above)
%
% Outputs:
%   appData  -- updated appData struct
%
% Examples:
%   appData = emViewer.mouseOps('motion', appData, buildMouseCtx());
%   appData = emViewer.mouseOps('axesDown', appData, buildMouseCtx());

switch action

    % ════════════════════════════════════════════════════════════════════
    %  motion -- onMouseMotion: track cursor, show pixel info
    % ════════════════════════════════════════════════════════════════════
    case 'motion'
        fig            = ctx.fig;
        ax             = ctx.ax;
        lblStatusMouse = ctx.lblStatusMouse;

        % Panel resize border detection: skip during capture mode
        if isempty(appData.captureMode) || strcmp(appData.captureMode, '')
            dir = ctx.cb.detectResizeBorder();
            appData.panelResizeDir = dir;
            if     ~isempty(dir) && startsWith(dir, 'v_'), fig.Pointer = 'left';
            elseif ~isempty(dir) && startsWith(dir, 'h_'), fig.Pointer = 'top';
            elseif appData.panMode,                        fig.Pointer = 'hand';
            else
                fig.Pointer = 'arrow';
            end
        end

        % In compare mode, ax may not exist
        if isempty(ax) || ~isvalid(ax)
            return;
        end
        % If no image is loaded, nothing to show
        if appData.activeIdx < 1 || isempty(appData.rawPixels)
            lblStatusMouse.Text = '';
            return;
        end

        [H, W] = size(appData.rawPixels);

        % Get mouse position in data coordinates
        cp    = ax.CurrentPoint;
        xData = cp(1, 1);
        yData = cp(1, 2);

        % Check if mouse is within axes limits
        if xData < ax.XLim(1) || xData > ax.XLim(2) || ...
           yData < ax.YLim(1) || yData > ax.YLim(2)
            lblStatusMouse.Text = '';
            return;
        end

        % Convert to nearest integer pixel coordinate
        col = round(xData);
        row = round(yData);

        % Check if within image bounds
        if col < 1 || col > W || row < 1 || row > H
            lblStatusMouse.Text = '';
            return;
        end

        % Read raw pixel intensity (before contrast adjustment)
        intensity = appData.rawPixels(row, col);

        % Format based on data type (integer vs float)
        if intensity == floor(intensity) && abs(intensity) < 1e7
            lblStatusMouse.Text = sprintf('(%d, %d) = %d', col, row, round(intensity));
        else
            lblStatusMouse.Text = sprintf('(%d, %d) = %.4g', col, row, intensity);
        end

        % Update pixel inspector if active
        if ctx.cbPixelInspector.Value
            ctx.cb.updatePixelInspector(col, row);
        end

    % ════════════════════════════════════════════════════════════════════
    %  axesDown -- onAxesMouseDown: box-zoom, pan, or double-click reset
    % ════════════════════════════════════════════════════════════════════
    case 'axesDown'
        fig = ctx.fig;
        ax  = ctx.ax;

        if ~isempty(appData.captureMode), return; end
        if appData.compareMode, return; end
        if isempty(appData.imgHandle) || ~isvalid(appData.imgHandle), return; end

        selType = fig.SelectionType;
        if strcmp(selType, 'alt'), return; end

        % Manual double-click detection -- uifigure on macOS does not always
        % upgrade SelectionType to 'open' for rapid successive clicks.
        nowTick = tic;
        isDouble = strcmp(selType, 'open');
        if ~isDouble && appData.lastClickTick > 0
            if toc(appData.lastClickTick) < 0.35
                isDouble = true;
            end
        end
        appData.lastClickTick = nowTick;

        if isDouble
            cdata = appData.imgHandle.CData;
            H = size(cdata, 1); W = size(cdata, 2);
            if H > 0 && W > 0
                ax.XLim = [0.5, W + 0.5];
                ax.YLim = [0.5, H + 0.5];
            end
            return;
        end

        % Determine drag action: middle-click always pans, panMode left-click
        % pans, otherwise zoom/marquee as before.
        wantPan = strcmp(selType, 'extend') || ...
                  (appData.panMode && strcmp(selType, 'normal'));

        cp = ax.CurrentPoint;
        appData.prevMotionFcn = fig.WindowButtonMotionFcn;
        appData.prevUpFcn     = fig.WindowButtonUpFcn;

        if wantPan
            appData.dragAction   = 'pan';
            appData.panStartXY   = cp(1, 1:2);
            appData.panStartLims = struct('XLim', ax.XLim, 'YLim', ax.YLim);
            fig.Pointer = 'hand';
        else
            appData.dragAction  = 'zoomMarquee';
            appData.zoomStartXY = cp(1, 1:2);
            appData.zoomRect    = [];
        end

        fig.WindowButtonMotionFcn = ctx.cb.onBoxZoomDrag;
        fig.WindowButtonUpFcn     = ctx.cb.onBoxZoomRelease;

    % ════════════════════════════════════════════════════════════════════
    %  idleDown -- onIdleMouseDown: figure-level idle click handler
    % ════════════════════════════════════════════════════════════════════
    case 'idleDown'
        fig = ctx.fig;

        if strcmp(fig.SelectionType, 'alt'), return; end   % right-click: skip
        if ~isempty(appData.panelResizeDir)
            ctx.cb.startPanelResize();
            return;
        end
        % Click on empty canvas deselects any highlighted measurement
        % and any marquee-selected annotations. A measurement's own
        % ButtonDownFcn fires AFTER this figure-level callback, so
        % clicks directly on a measurement re-select it via
        % selectMeasurement -- no flicker, no missed highlights.
        if appData.selectedMeasIdx > 0 || ~isempty(appData.selectedMeasIndices)
            ctx.cb.deselectMeasurement();
        end
        if appData.selectedAnnotIdx > 0 || ~isempty(appData.selectedAnnotIndices)
            for ai = appData.selectedAnnotIndices(:)'
                if ai >= 1 && ai <= numel(appData.overlays.textAnnotations)
                    ctx.cb.highlightAnnotation(appData.overlays.textAnnotations{ai}, false);
                end
            end
            if appData.selectedAnnotIdx > 0 && ...
                    appData.selectedAnnotIdx <= numel(appData.overlays.textAnnotations)
                ctx.cb.highlightAnnotation( ...
                    appData.overlays.textAnnotations{appData.selectedAnnotIdx}, false);
            end
            appData.selectedAnnotIndices = [];
            appData.selectedAnnotIdx = 0;
        end

    % ════════════════════════════════════════════════════════════════════
    %  buildContextMenus -- right-click menus for image axes + listbox
    % ════════════════════════════════════════════════════════════════════
    case 'buildContextMenus'
        fig      = ctx.fig;
        ax       = ctx.ax;
        lbImages = ctx.lbImages;

        % --- Image axes + image menu -----------------------------------------
        cmImage = uicontextmenu(fig);
        uimenu(cmImage, 'Text', 'Zoom', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onZoomBox([], []));
        uimenu(cmImage, 'Text', 'Reset Zoom', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onResetZoom([], []));
        uimenu(cmImage, 'Text', 'Fit to Window', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onZoomFit([], []));
        uimenu(cmImage, 'Text', 'Zoom 1:1 (Actual Size)', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onZoomActual([], []));
        uimenu(cmImage, 'Text', 'Zoom Out (2x)', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onZoomOut([], []));
        uimenu(cmImage, 'Text', 'Zoom to Dimensions...', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onZoomBox([], [], 'dims'));
        uimenu(cmImage, 'Text', 'Toggle Pan Mode', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.togglePanMode());
        uimenu(cmImage, 'Text', 'Copy to Clipboard', ...
            'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onExportAction('copyClipboard'));
        uimenu(cmImage, 'Text', 'Save Image As...', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onExportAction('saveImage'));
        uimenu(cmImage, 'Text', 'Toggle Scale Bar', ...
            'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.contextToggleScaleBar());
        uimenu(cmImage, 'Text', 'Clear Overlays', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onClearOverlays([], []));
        appData.cmImage = cmImage;
        if ~isempty(ax) && isvalid(ax)
            ax.ContextMenu = cmImage;
        end
        ctx.cb.attachImageContextMenu();   % also attach to the current image HG object

        % --- Thumbnail list menu ---------------------------------------------
        cmList = uicontextmenu(fig);
        uimenu(cmList, 'Text', 'Open...', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onOpenFiles([], []));
        uimenu(cmList, 'Text', 'Rename Selected...', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onRenameSelected([], []));
        uimenu(cmList, 'Text', 'Remove Selected', ...
            'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onRemoveImage([], []));
        appData.cmList = cmList;
        if ~isempty(lbImages) && isvalid(lbImages)
            lbImages.ContextMenu = cmList;
        end

    % ════════════════════════════════════════════════════════════════════
    %  buildContextMenu -- simple axes context menu (Feature 20)
    % ════════════════════════════════════════════════════════════════════
    case 'buildContextMenu'
        ax  = ctx.ax;
        fig = ctx.fig;

        if isempty(ax) || ~isvalid(ax), return; end
        cm = uicontextmenu(fig);
        uimenu(cm, 'Text', 'Auto Contrast', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onAutoContrast());
        uimenu(cm, 'Text', 'Copy to Clipboard', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onExportAction('copyClipboard'));
        uimenu(cm, 'Text', 'Save Image', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onExportAction('saveImage'));
        uimenu(cm, 'Text', 'Measure Distance', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onArmDistance([], []));
        uimenu(cm, 'Text', 'Line Profile', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onArmLineProfile([], []));
        uimenu(cm, 'Text', 'ROI Statistics', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onArmROIStats([], []));
        uimenu(cm, 'Text', 'Zoom to Fit', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.onResetZoom([], []));
        uimenu(cm, 'Text', 'Refresh State (F5)', 'Separator', 'on', ...
            'MenuSelectedFcn', @(~,~) ctx.cb.refreshState());
        ax.ContextMenu = cm;

    otherwise
        error('emViewer:mouseOps:unknownAction', ...
            'Unknown action ''%s''. Valid: motion, axesDown, idleDown, buildContextMenus, buildContextMenu.', ...
            action);
end
end
