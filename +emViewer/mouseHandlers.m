function appData = mouseHandlers(action, appData, ctx)
%MOUSEHANDLERS  Mouse motion and axes-click handlers for FermiViewer.
%
% Syntax:
%   appData = emViewer.mouseHandlers(action, appData, ctx)
%
% Actions:
%   'motion'      — mouse motion: pixel info in status bar, resize cursor
%   'axesdown'    — axes ButtonDownFcn: double-click reset, pan, or box-zoom
%
% ctx struct fields:
%   'motion':
%     .fig                  — uifigure handle
%     .ax                   — main image axes handle (may be empty in compare mode)
%     .lblStatusMouse       — label handle for pixel info
%     .cbPixelInspector     — pixel inspector checkbox handle
%     .hPixelInspector      — pixel inspector figure handle (may be empty)
%     .detectResizeBorder   — @detectResizeBorder function handle
%     .updatePixelInspector — @updatePixelInspector function handle
%
%   'axesdown':
%     .fig                  — uifigure handle
%     .ax                   — main image axes handle
%     .onBoxZoomDrag        — @onBoxZoomDrag function handle
%     .onBoxZoomRelease     — @onBoxZoomRelease function handle
%
% Note: onMouseMotion is called on every mouse-move event. The ctx struct
%   is NOT rebuilt per call — the caller builds it once and passes the same
%   instance. This keeps the hot path allocation-free.
%
% Examples:
%   % In FermiViewer.m motion callback:
%   function onMouseMotion(~, ~)
%       appData = emViewer.mouseHandlers('motion', appData, motionCtx);
%   end
%
%   % In FermiViewer.m axes button-down:
%   function onAxesMouseDown(~, ~)
%       appData = emViewer.mouseHandlers('axesdown', appData, axesCtx);
%   end

% ════════════════════════════════════════════════════════════════════
switch lower(action)

    % ── Mouse Motion ─────────────────────────────────────────────
    case 'motion'
        % Panel resize border detection: skip during capture mode
        if isempty(appData.captureMode) || strcmp(appData.captureMode, '')
            dir = ctx.detectResizeBorder();
            appData.panelResizeDir = dir;
            if     ~isempty(dir) && startsWith(dir, 'v_'), ctx.fig.Pointer = 'left';
            elseif ~isempty(dir) && startsWith(dir, 'h_'), ctx.fig.Pointer = 'top';
            elseif appData.panMode,                        ctx.fig.Pointer = 'hand';
            else
                ctx.fig.Pointer = 'arrow';
            end
        end

        % In compare mode, ax may not exist
        if isempty(ctx.ax) || ~isvalid(ctx.ax)
            return;
        end
        % If no image is loaded, nothing to show
        if appData.activeIdx < 1 || isempty(appData.rawPixels)
            ctx.lblStatusMouse.Text = '';
            return;
        end

        [H, W] = size(appData.rawPixels);

        % Get mouse position in data coordinates
        cp    = ctx.ax.CurrentPoint;
        xData = cp(1, 1);
        yData = cp(1, 2);

        % Check if mouse is within axes limits
        if xData < ctx.ax.XLim(1) || xData > ctx.ax.XLim(2) || ...
           yData < ctx.ax.YLim(1) || yData > ctx.ax.YLim(2)
            ctx.lblStatusMouse.Text = '';
            return;
        end

        % Convert to nearest integer pixel coordinate
        col = round(xData);
        row = round(yData);

        % Check if within image bounds
        if col < 1 || col > W || row < 1 || row > H
            ctx.lblStatusMouse.Text = '';
            return;
        end

        % Read raw pixel intensity (before contrast adjustment)
        intensity = appData.rawPixels(row, col);

        % Format based on data type (integer vs float)
        if intensity == floor(intensity) && abs(intensity) < 1e7
            ctx.lblStatusMouse.Text = sprintf('(%d, %d) = %d', col, row, round(intensity));
        else
            ctx.lblStatusMouse.Text = sprintf('(%d, %d) = %.4g', col, row, intensity);
        end

        % Update pixel inspector if active
        if ctx.cbPixelInspector.Value && ...
                ~isempty(ctx.hPixelInspector) && isvalid(ctx.hPixelInspector)
            ctx.updatePixelInspector(col, row);
        end

    % ── Axes Mouse Down ──────────────────────────────────────────
    case 'axesdown'
        if ~isempty(appData.captureMode), return; end
        if appData.compareMode, return; end
        if isempty(appData.imgHandle) || ~isvalid(appData.imgHandle), return; end

        selType = ctx.fig.SelectionType;
        if strcmp(selType, 'alt'), return; end

        % Manual double-click detection — uifigure on macOS does not always
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
                ctx.ax.XLim = [0.5, W + 0.5];
                ctx.ax.YLim = [0.5, H + 0.5];
            end
            return;
        end

        % Determine drag action: middle-click always pans, panMode left-click
        % pans, otherwise zoom/marquee as before.
        wantPan = strcmp(selType, 'extend') || ...
                  (appData.panMode && strcmp(selType, 'normal'));

        cp = ctx.ax.CurrentPoint;
        appData.prevMotionFcn = ctx.fig.WindowButtonMotionFcn;
        appData.prevUpFcn     = ctx.fig.WindowButtonUpFcn;

        if wantPan
            appData.dragAction   = 'pan';
            appData.panStartXY   = cp(1, 1:2);
            appData.panStartLims = struct('XLim', ctx.ax.XLim, 'YLim', ctx.ax.YLim);
            ctx.fig.Pointer = 'hand';
        else
            appData.dragAction  = 'zoomMarquee';
            appData.zoomStartXY = cp(1, 1:2);
            appData.zoomRect    = [];
        end

        ctx.fig.WindowButtonMotionFcn = ctx.onBoxZoomDrag;
        ctx.fig.WindowButtonUpFcn     = ctx.onBoxZoomRelease;

    otherwise
        error('emViewer:mouseHandlers:unknownAction', ...
            'Unknown action: %s', action);
end
end
