function yOriginClick(appData, fig, ax, ui, callbacks)
%YORIGINCLICK  Handle a click in the 2-click "Estimate Y Offset" picker.
%
% Syntax
%   bosonPlotter.yOriginClick(appData, fig, ax, ui, callbacks)
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutated: yOriginClickCount,
%               yOriginPt1, yOriginMarker)
%   fig       - Main BosonPlotter figure handle (for WindowButtonDownFcn reset)
%   ax        - Main plot axes
%   ui        - Struct of widget handles with fields:
%                 .ddX, .lbY, .btnPickY, .efYOffset, .btnFitBG
%   callbacks - Struct of function handles:
%                 .onAxesButtonDown(s,e)     — restored on second click
%                 .onApplyCorrections(s,e)   — fires after offset update
%
% Behaviour
%   First click:  snaps to nearest plotted data point, drops a marker,
%                 stores y-value as appData.yOriginPt1, updates button text.
%   Second click: computes new Y-offset so midpoint of the two y-values maps
%                 to zero, clears markers, restores the default button-down
%                 handler, re-enables controls, and invokes onApplyCorrections.

    cp     = ax.CurrentPoint;
    xClick = cp(1,1);
    yClick = cp(1,2);
    if xClick < ax.XLim(1) || xClick > ax.XLim(2) || ...
       yClick < ax.YLim(1) || yClick > ax.YLim(2)
        return;
    end

    ds       = appData.datasets{appData.activeIdx};
    d        = ds.data;
    primaryD = guiTernary(~isempty(ds.corrData), ds.corrData, d);

    % ── Resolve the PLOTTED x vector ──────────────────────────────────
    xSel  = ui.ddX.Value;
    xName = guiXName(d.metadata);
    if strcmp(xSel, xName)
        xVecPlot = primaryD.time;
    else
        idx2     = find(strcmp(d.labels, xSel), 1);
        xVecPlot = guiTernary(isempty(idx2), primaryD.time, primaryD.values(:, idx2));
    end
    if isdatetime(xVecPlot)
        xVecPlot = posixtime(xVecPlot);
    else
        xVecPlot = double(xVecPlot);
    end

    % ── Snap to nearest plotted point ─────────────────────────────────
    ySel = ensureCell(ui.lbY.Value);

    xRange = max(diff(ax.XLim), eps);
    yRange = max(diff(ax.YLim), eps);
    bestDist = Inf;
    xNearest = NaN;
    yNearest = NaN;
    for k = 1:numel(ySel)
        idx = find(strcmp(d.labels, ySel{k}), 1);
        if isempty(idx), continue; end
        yVec  = primaryD.values(:, idx);
        valid = ~isnan(xVecPlot) & ~isnan(yVec);
        if ~any(valid), continue; end
        xv = xVecPlot(valid);
        yv = yVec(valid);
        dx = (xv - xClick) / xRange;
        dy = (yv - yClick) / yRange;
        [minD, minI] = min(sqrt(dx.^2 + dy.^2));
        if minD < bestDist
            bestDist = minD;
            xNearest = xv(minI);
            yNearest = yv(minI);
        end
    end

    if isnan(yNearest), return; end

    appData.yOriginClickCount = appData.yOriginClickCount + 1;

    if appData.yOriginClickCount == 1
        % ── First click: mark point, wait for second ──────────────────
        appData.yOriginPt1 = yNearest;
        hold(ax, 'on');
        appData.yOriginMarker = plot(ax, xNearest, yNearest, ...
            'v', 'MarkerSize', 9, 'LineWidth', 2, ...
            'Color',            [0.85 0.33 0.10], ...
            'MarkerFaceColor',  [0.85 0.33 0.10], ...
            'HitTest',          'off', ...
            'HandleVisibility', 'off');
        hold(ax, 'off');
        ui.btnPickY.Text = sprintf('Click pt 2  (pt 1: y = %.4g)', yNearest);

    else
        % ── Second click: shift Y offset so midpoint → 0 ─────────────
        fig.WindowButtonDownFcn = callbacks.onAxesButtonDown;

        hold(ax, 'on');
        mkr2 = plot(ax, xNearest, yNearest, ...
            '^', 'MarkerSize', 9, 'LineWidth', 2, ...
            'Color',            [0.20 0.60 0.20], ...
            'MarkerFaceColor',  [0.20 0.60 0.20], ...
            'HitTest',          'off', ...
            'HandleVisibility', 'off');
        hold(ax, 'off');
        drawnow limitrate;

        if ~isempty(appData.yOriginMarker) && isvalid(appData.yOriginMarker)
            delete(appData.yOriginMarker);
        end
        if isvalid(mkr2)
            delete(mkr2);
        end

        % new_yOff = old_yOff + (y1 + y2) / 2
        ui.efYOffset.Value = ui.efYOffset.Value + (appData.yOriginPt1 + yNearest) / 2;

        appData.yOriginMarker     = [];
        appData.yOriginClickCount = 0;
        appData.yOriginPt1        = [];

        ui.btnPickY.Text   = 'Est. Y Offset  (2 pts)';
        % Re-enable only for non-neutron parsers (neutron hides btnPickY)
        if isempty(appData.datasets) || ~isfield(appData.datasets{appData.activeIdx}, 'parserName') ...
                || ~isNeutronParser(appData.datasets{appData.activeIdx}.parserName)
            ui.btnPickY.Enable = 'on';
        end
        ui.btnFitBG.Enable = 'on';

        callbacks.onApplyCorrections([], []);
    end
end
