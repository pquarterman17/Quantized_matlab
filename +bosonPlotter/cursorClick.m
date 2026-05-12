function cursorClick(appData, fig, ax, callbacks)
%CURSORCLICK  Handle click in data cursor mode (point 1 / point 2 / pin).
%
% Syntax
%   bosonPlotter.cursorClick(appData, fig, ax, callbacks)
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutated: cursorClickCount,
%               cursorPt1, cursorPinned, cursorMarker, cursorLabel,
%               cursorMarker2, cursorDeltaLabel, cursorLine)
%   fig       - Main BosonPlotter figure handle (for CurrentModifier)
%   ax        - Main plot axes
%   callbacks - Struct of function handles:
%                 .getPlotData(dsIdx)  -> data struct
%                 .setStatus(msg)      -> updates status bar
%
% Behaviour
%   Normal click: point 1 / point 2 (delta) cycle with connecting line.
%   Ctrl+click:   pin a persistent marker at the snapped point (multi-pin).

    if ~appData.cursorActive, return; end
    if isempty(appData.datasets) || appData.activeIdx < 1, return; end

    % Get click position in axes coordinates
    cp = ax.CurrentPoint;
    xClick = cp(1,1);
    yClick = cp(1,2);

    % Check if click is within axes limits
    xl = ax.XLim; yl = ax.YLim;
    if xClick < xl(1) || xClick > xl(2) || yClick < yl(1) || yClick > yl(2)
        return;
    end

    % Get active dataset
    d = callbacks.getPlotData(appData.activeIdx);
    if isempty(d) || isempty(d.time), return; end

    xData = double(d.time);
    yData = d.values;
    if isempty(yData), return; end

    % Find nearest point (use first visible Y channel)
    yCol = yData(:, 1);
    xRange = diff(xl); yRange = diff(yl);
    if xRange == 0, xRange = 1; end
    if yRange == 0, yRange = 1; end
    dist = ((xData - xClick) / xRange).^2 + ((yCol - yClick) / yRange).^2;
    [~, idx] = min(dist);
    xSnap = xData(idx);
    ySnap = yCol(idx);

    % Ctrl+click → pin a persistent marker
    ctrlHeld = ~isempty(fig.CurrentModifier) && ...
               any(ismember(fig.CurrentModifier, {'control', 'command'}));
    if ctrlHeld
        hold(ax, 'on');
        pinColors = [0.00 0.60 0.30; 0.80 0.40 0.00; 0.50 0.00 0.50; ...
                     0.00 0.40 0.70; 0.70 0.00 0.00; 0.40 0.40 0.40];
        ci = mod(numel(appData.cursorPinned), size(pinColors,1)) + 1;
        pc = pinColors(ci,:);
        mk = plot(ax, xSnap, ySnap, 'd', 'MarkerSize', 9, 'LineWidth', 2, ...
            'Color', pc, 'MarkerFaceColor', pc, 'HandleVisibility', 'off');
        lbl = sprintf('  (%.6g, %.6g)', xSnap, ySnap);
        lb = text(ax, xSnap, ySnap, lbl, ...
            'FontSize', 8, 'Color', pc, 'FontWeight', 'bold', ...
            'BackgroundColor', [1 1 1 0.85], 'EdgeColor', pc, ...
            'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');
        appData.cursorPinned{end+1} = struct('marker', mk, 'label', lb);
        callbacks.setStatus(sprintf('Pinned #%d: (%.6g, %.6g)', numel(appData.cursorPinned), xSnap, ySnap));
        return;
    end

    appData.cursorClickCount = appData.cursorClickCount + 1;

    if appData.cursorClickCount == 1
        % First click: show point — clean up previous graphics
        if isgraphics(appData.cursorMarker), delete(appData.cursorMarker); end
        if isgraphics(appData.cursorLabel), delete(appData.cursorLabel); end
        if isgraphics(appData.cursorMarker2), delete(appData.cursorMarker2); end
        if isgraphics(appData.cursorDeltaLabel), delete(appData.cursorDeltaLabel); end
        if isgraphics(appData.cursorLine), delete(appData.cursorLine); end

        hold(ax, 'on');
        appData.cursorMarker = plot(ax, xSnap, ySnap, 'ro', ...
            'MarkerSize', 10, 'LineWidth', 2, 'HandleVisibility', 'off');
        lbl = sprintf('(%.6g, %.6g)', xSnap, ySnap);
        appData.cursorLabel = text(ax, xSnap, ySnap, ['  ' lbl], ...
            'FontSize', 9, 'Color', [0.8 0 0], 'FontWeight', 'bold', ...
            'BackgroundColor', [1 1 1 0.85], 'EdgeColor', [0.7 0.7 0.7], ...
            'VerticalAlignment', 'bottom', 'HandleVisibility', 'off');

        appData.cursorPt1 = [xSnap, ySnap];
        callbacks.setStatus(sprintf('Point 1: x = %.6g, y = %.6g  —  click again for delta', xSnap, ySnap));

    elseif appData.cursorClickCount == 2
        % Second click: show delta
        if isempty(appData.cursorPt1)
            appData.cursorClickCount = 1;
            return;
        end
        hold(ax, 'on');
        appData.cursorMarker2 = plot(ax, xSnap, ySnap, 'bs', ...
            'MarkerSize', 10, 'LineWidth', 2, 'HandleVisibility', 'off');

        dx = xSnap - appData.cursorPt1(1);
        dy = ySnap - appData.cursorPt1(2);
        lbl = sprintf('(%.6g, %.6g)\n\\Delta x=%.6g  \\Delta y=%.6g', xSnap, ySnap, dx, dy);
        appData.cursorDeltaLabel = text(ax, xSnap, ySnap, ['  ' lbl], ...
            'FontSize', 9, 'Color', [0 0 0.8], 'FontWeight', 'bold', ...
            'BackgroundColor', [1 1 1 0.85], 'EdgeColor', [0.5 0.5 0.8], ...
            'VerticalAlignment', 'top', 'HandleVisibility', 'off');

        % Draw connecting line
        appData.cursorLine = plot(ax, ...
            [appData.cursorPt1(1), xSnap], [appData.cursorPt1(2), ySnap], ...
            '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.75, ...
            'HandleVisibility', 'off');

        callbacks.setStatus(sprintf('Delta: dx = %.6g, dy = %.6g', dx, dy));
        appData.cursorClickCount = 0;  % reset for next pair
    end
end
