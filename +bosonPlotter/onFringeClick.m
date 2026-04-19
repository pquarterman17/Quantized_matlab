function onFringeClick(appData, fig, ax, widgets, callbacks)
%ONFRINGECLICK  Handle a click during fringe-thickness pick mode.
%
% Syntax
%   bosonPlotter.onFringeClick(appData, fig, ax, widgets, callbacks)
%
% Behaviour
%   Two-click tool for estimating thin-film thickness from Kiessig
%   fringes:
%     Click 1 — places the first marker at the data point nearest the
%               click, stored in appData.fringeQ(1) and
%               appData.fringeMarkers(1).
%     Click 2 — places the second marker, restores the normal
%               WindowButton* handlers, resets btnFringeThick, and
%               calls updateFringeThickness to compute and display the
%               thickness from Δq.
%   Data-point snapping uses normalised-distance in the current axis
%   space with log-space Y if the axis is log-scaled.  Markers are
%   click-draggable along the data curve via the
%   @onFringeMarkerDown callback.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutates fringeClickCount,
%               fringeQ, fringeMarkers, fringeDragIdx)
%   fig       - Main figure handle (rewires button handlers on click 2)
%   ax        - Main axes (reads CurrentPoint, XLim, YLim, YScale)
%   widgets   - Struct with handles:
%                 .lbY            - Y-channel listbox
%                 .btnFringeThick - fringe-thickness tool button
%   callbacks - Struct of function handles + constants:
%                 .onFringeMarkerDown(markerIdx)
%                 .onAxesButtonDown   - figure WindowButtonDownFcn
%                 .onMouseHover       - figure WindowButtonMotionFcn
%                 .updateFringeThickness()
%                 .BTN_ACCENT (RGB triplet for the default button colour)

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
    ySel2  = ensureCell(widgets.lbY.Value);
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
    hm.ButtonDownFcn = @(src, evt) callbacks.onFringeMarkerDown(n);
    hold(ax, 'off');

    if n == 1
        appData.fringeMarkers = hm;
        widgets.btnFringeThick.Text = 'Click peak 2 of 2...';
    else
        appData.fringeMarkers(2) = hm;
        % Restore normal interaction and compute thickness
        fig.WindowButtonDownFcn   = callbacks.onAxesButtonDown;
        fig.WindowButtonMotionFcn = callbacks.onMouseHover;
        fig.Pointer               = 'arrow';
        widgets.btnFringeThick.Text            = ['Fringe ' char(916) 't (2-click)'];
        widgets.btnFringeThick.BackgroundColor = callbacks.BTN_ACCENT;
        widgets.btnFringeThick.Enable          = 'on';

        callbacks.updateFringeThickness();
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m module-level scope)
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function c = ensureCell(v)
    if ischar(v) || isstring(v)
        c = cellstr(v);
    else
        c = v;
    end
end
