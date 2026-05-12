function ctrl = anchorSplineBackground(ax, xData, yData, onApply, options)
%ANCHORSPLINEBACKGROUND  Click-to-place anchor points; cubic spline = background.
%
%   Syntax:
%       ctrl = bosonPlotter.anchorSplineBackground(ax, xData, yData, onApply)
%       ctrl = bosonPlotter.anchorSplineBackground(ax, xData, yData, onApply, ...
%                   'StatusFcn', fcn)
%
%   Inputs:
%       ax          axes handle on which to operate
%       xData       column vector — x values of the dataset
%       yData       column vector — y values of the dataset
%       onApply     function_handle  called as onApply(correctedY, splineY)
%                   when the user clicks [Apply]; correctedY = yData - splineY
%
%   Options:
%       StatusFcn   function_handle  receives status text strings.
%                   Default: @(~) []
%
%   Outputs:
%       ctrl — struct with fields:
%         .activate   function handle — enter anchor-placement mode
%         .deactivate function handle — leave mode, remove all overlays
%         .apply      function handle — apply subtraction without mode exit
%         .clear      function handle — remove all anchors and spline preview
%         .getAnchors function handle — returns [anchorX, anchorY] as Nx2
%
%   Description:
%       In active mode, clicking on AX adds a diamond-shaped anchor marker.
%       Anchors can be dragged horizontally and vertically.  Right-clicking
%       an anchor removes it.  A cubic spline preview is redrawn after every
%       add, move, or delete.  [Apply] computes correctedY = yData - spline
%       and calls ONAPPLY.  [Clear] removes all anchors without applying.
%
%   Examples:
%       xv = linspace(0, 10, 200)';
%       yv = sin(xv) + 0.1*xv;
%       ctrl = bosonPlotter.anchorSplineBackground(ax, xv, yv, ...
%           @(ycorr, bg) plot(ax, xv, ycorr, 'b-'));
%       ctrl.activate();

arguments
    ax
    xData   double
    yData   double
    onApply function_handle
    options.StatusFcn function_handle = @(~) []
end

% ════════════════════════════════════════════════════════════════════════
% Internal state
% ════════════════════════════════════════════════════════════════════════

anchorX     = zeros(0, 1);   % anchor x-positions
anchorY     = zeros(0, 1);   % anchor y-positions
markerHandles = gobjects(0); % one diamond marker per anchor
splineLine  = gobjects(0);   % the spline preview line
active      = false;         % in placement mode?
dragState   = struct('src', [], 'idx', 0, 'savedM', '', 'savedU', '', 'savedD', '');

xData = xData(:);
yData = yData(:);

fig = ancestor(ax, 'figure');
savedClickFcn = fig.WindowButtonDownFcn;

% ════════════════════════════════════════════════════════════════════════
% Public interface
% ════════════════════════════════════════════════════════════════════════

ctrl.activate   = @activate;
ctrl.deactivate = @deactivate;
ctrl.apply      = @applySubtraction;
ctrl.clear      = @clearAnchors;
ctrl.getAnchors = @getAnchors;

% ════════════════════════════════════════════════════════════════════════
% Mode control
% ════════════════════════════════════════════════════════════════════════

    function activate()
    %ACTIVATE  Enter anchor-placement mode.
        if active, return; end
        active = true;
        savedClickFcn = fig.WindowButtonDownFcn;
        fig.WindowButtonDownFcn = @onFigureClick;
        options.StatusFcn( ...
            'Anchor BG: left-click to add, drag to move, right-click marker to remove.');
    end

    function deactivate()
    %DEACTIVATE  Exit mode, remove all overlays.
        active = false;
        fig.WindowButtonDownFcn = savedClickFcn;
        clearAnchors();
        options.StatusFcn('');
    end

% ════════════════════════════════════════════════════════════════════════
% Click handler — add anchor
% ════════════════════════════════════════════════════════════════════════

    function onFigureClick(~, ~)
    %ONFIGURE CLICK  Add an anchor at the clicked position (axes coords).
        if ~active, return; end
        % Only respond to left-click inside AX
        if ~strcmp(fig.SelectionType, 'normal'), return; end
        cp = ax.CurrentPoint;
        xClick = cp(1, 1);
        yClick = cp(1, 2);
        if xClick < ax.XLim(1) || xClick > ax.XLim(2) || ...
           yClick < ax.YLim(1) || yClick > ax.YLim(2)
            return;
        end

        % Snap y to the nearest data point within 3 % of x-axis range
        snapX = snapToData(xClick, yClick);

        anchorX(end+1, 1) = xClick;
        anchorY(end+1, 1) = snapX;

        % Sort anchors by x so spline is monotone in x
        [anchorX, ord] = sort(anchorX);
        anchorY = anchorY(ord);

        drawAnchorMarker(numel(anchorX));
        % Rebuild marker array to match sorted order
        markerHandles = markerHandles(ord);

        redrawSpline();
        options.StatusFcn(sprintf('Anchor BG: %d anchors placed.', numel(anchorX)));
    end

    function snappedY = snapToData(xClick, yClick)
    %SNAPTODATA  Return y from data nearest to xClick; fall back to yClick.
        xWin = diff(ax.XLim) * 0.03;
        inWin = xData >= (xClick - xWin) & xData <= (xClick + xWin);
        if any(inWin)
            xSub = xData(inWin);
            ySub = yData(inWin);
            [~, ni] = min(abs(xSub - xClick));
            snappedY = ySub(ni);
        else
            snappedY = yClick;
        end
    end

% ════════════════════════════════════════════════════════════════════════
% Marker drawing
% ════════════════════════════════════════════════════════════════════════

    function drawAnchorMarker(idx)
    %DRAWANCHORMARKER  Plot a diamond marker for anchor IDX.
        h = plot(ax, anchorX(idx), anchorY(idx), 'd', ...
            'MarkerSize', 9, ...
            'MarkerFaceColor', [0.90 0.65 0.10], ...
            'MarkerEdgeColor', [0.50 0.35 0.00], ...
            'LineWidth', 1.2, ...
            'Tag',  'AnchorBGMarker', ...
            'HandleVisibility', 'off', ...
            'PickableParts', 'all', 'HitTest', 'on');
        h.ButtonDownFcn = @(src, evt) onMarkerClick(src, evt, idx);
        % Grow array; the sort in onFigureClick will re-order if needed
        markerHandles(end+1) = h;
    end

    function onMarkerClick(src, evt, idx)
    %ONMARKERCLICK  Right-click to delete; left-click to start drag.
        switch evt.EventName
            case 'Hit'
                selType = fig.SelectionType;
                if strcmp(selType, 'alt')
                    % Right-click: delete this anchor
                    removeAnchor(idx);
                else
                    % Left-click: drag
                    startMarkerDrag(src, idx);
                end
        end
    end

% ════════════════════════════════════════════════════════════════════════
% Drag an existing anchor
% ════════════════════════════════════════════════════════════════════════

    function startMarkerDrag(src, idx)
    %STARTMARKERDRAG  Enter per-marker drag mode.
        dragState.src    = src;
        dragState.idx    = idx;
        dragState.savedM = fig.WindowButtonMotionFcn;
        dragState.savedU = fig.WindowButtonUpFcn;
        dragState.savedD = fig.WindowButtonDownFcn;
        fig.Pointer = 'hand';
        fig.WindowButtonMotionFcn = @anchorDragMotion;
        fig.WindowButtonUpFcn     = @anchorDragRelease;
        fig.WindowButtonDownFcn   = @(~,~) [];
    end

    function anchorDragMotion(~, ~)
        cp = ax.CurrentPoint;
        xNow = cp(1, 1);
        yNow = cp(1, 2);
        xl = ax.XLim; yl = ax.YLim;
        xNow = max(xl(1), min(xl(2), xNow));
        yNow = max(yl(1), min(yl(2), yNow));
        anchorX(dragState.idx) = xNow;
        anchorY(dragState.idx) = yNow;
        if isvalid(dragState.src)
            dragState.src.XData = xNow;
            dragState.src.YData = yNow;
        end
        redrawSpline();
        drawnow limitrate
    end

    function anchorDragRelease(~, ~)
        [anchorX, ord] = sort(anchorX);
        anchorY = anchorY(ord);
        markerHandles = markerHandles(ord);
        for ki = 1:numel(markerHandles)
            ki2 = ki;
            if isvalid(markerHandles(ki))
                markerHandles(ki).ButtonDownFcn = ...
                    @(s,e) onMarkerClick(s, e, ki2);
            end
        end
        fig.WindowButtonMotionFcn = dragState.savedM;
        fig.WindowButtonUpFcn     = dragState.savedU;
        fig.WindowButtonDownFcn   = dragState.savedD;
        fig.Pointer = 'crosshair';
        redrawSpline();
        options.StatusFcn(sprintf('Anchor BG: %d anchors.', numel(anchorX)));
    end

% ════════════════════════════════════════════════════════════════════════
% Anchor removal
% ════════════════════════════════════════════════════════════════════════

    function removeAnchor(idx)
    %REMOVEANCHOR  Delete the IDX-th anchor and its marker.
        if idx < 1 || idx > numel(anchorX), return; end
        if isvalid(markerHandles(idx))
            delete(markerHandles(idx));
        end
        anchorX(idx) = [];
        anchorY(idx) = [];
        markerHandles(idx) = [];
        % Re-index ButtonDownFcns
        for ki = 1:numel(markerHandles)
            ki2 = ki;
            if isvalid(markerHandles(ki))
                markerHandles(ki).ButtonDownFcn = ...
                    @(s,e) onMarkerClick(s, e, ki2);
            end
        end
        redrawSpline();
        options.StatusFcn(sprintf('Anchor BG: %d anchors.', numel(anchorX)));
    end

% ════════════════════════════════════════════════════════════════════════
% Spline preview
% ════════════════════════════════════════════════════════════════════════

    function redrawSpline()
    %REDRAWSPLINE  Recompute and replot the spline through all current anchors.
        % Remove stale preview
        if ~isempty(splineLine) && any(isvalid(splineLine))
            delete(splineLine(isvalid(splineLine)));
        end
        splineLine = gobjects(0);

        if numel(anchorX) < 2, return; end

        % Deduplicate x positions (interp1 requires unique x)
        [ux, ia] = unique(anchorX, 'stable');
        uy = anchorY(ia);
        if numel(ux) < 2, return; end

        try
            ySpline = interp1(ux, uy, xData, 'spline', 'extrap');
        catch
            return;
        end

        hold(ax, 'on');
        splineLine = plot(ax, xData, ySpline, '--', ...
            'Color', [0.15 0.70 0.30], 'LineWidth', 1.5, ...
            'Tag', 'AnchorBGSpline', 'HandleVisibility', 'off');
        hold(ax, 'off');
        uistack(splineLine, 'top');
    end

% ════════════════════════════════════════════════════════════════════════
% Apply / Clear
% ════════════════════════════════════════════════════════════════════════

    function applySubtraction()
    %APPLYSUBTRACTION  Subtract the spline from yData and call onApply.
        if numel(anchorX) < 2
            options.StatusFcn('Anchor BG: need at least 2 anchors to apply.');
            return;
        end

        [ux, ia] = unique(anchorX, 'stable');
        uy = anchorY(ia);
        if numel(ux) < 2
            options.StatusFcn('Anchor BG: anchors must have distinct x positions.');
            return;
        end

        try
            ySpline   = interp1(ux, uy, xData, 'spline', 'extrap');
            corrected = yData - ySpline;
        catch ME
            options.StatusFcn(sprintf('Anchor BG: spline error — %s', ME.message));
            return;
        end

        options.StatusFcn(sprintf( ...
            'Anchor BG: subtracted spline background (%d anchors).', numel(anchorX)));
        onApply(corrected, ySpline);
    end

    function clearAnchors()
    %CLEARANCHORS  Remove all anchors and the spline preview.
        for ki = 1:numel(markerHandles)
            if isvalid(markerHandles(ki))
                delete(markerHandles(ki));
            end
        end
        markerHandles = gobjects(0);
        anchorX = zeros(0, 1);
        anchorY = zeros(0, 1);

        if ~isempty(splineLine) && any(isvalid(splineLine))
            delete(splineLine(isvalid(splineLine)));
        end
        splineLine = gobjects(0);

        options.StatusFcn('Anchor BG: cleared.');
    end

    function out = getAnchors()
    %GETANCHORS  Return current anchors as [anchorX, anchorY] (Nx2).
        out = [anchorX, anchorY];
    end

end
