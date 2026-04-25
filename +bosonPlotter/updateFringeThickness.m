function updateFringeThickness(appData, ax, callbacks)
%UPDATEFRINGETHICKNESS  Compute and display Kiessig-fringe film thickness.
%
% Syntax
%   bosonPlotter.updateFringeThickness(appData, ax, callbacks)
%
% Computes t = 2*pi / |Q2 - Q1| from the two fringe markers and renders
% the thickness as both a status-bar message and a top-left annotation
% on the plot. Also draws a horizontal dashed connector between the two
% markers.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads fringeQ + fringeMarkers;
%               mutates fringeAnnotation)
%   ax        - main axes
%   callbacks - struct with:
%                 .setStatus(msg)  — write to the GUI status bar

    Q1 = appData.fringeQ(1);
    Q2 = appData.fringeQ(2);
    if isnan(Q1) || isnan(Q2), return; end

    dQ = abs(Q2 - Q1);
    if dQ < eps
        tStr = 't = Inf (points overlap)';
    else
        % t = 2*pi / dQ in Å, convert to nm
        t_A  = 2 * pi / dQ;
        t_nm = t_A / 10;
        tStr = sprintf('t %s %.1f nm  (%.1f %s)    %sQ = %.5f %s%s%s', ...
            char(8776), t_nm, t_A, char(197), ...  % ≈, Å
            char(916), dQ, char(197), char(8315), char(185));  % Δ, Å⁻¹
    end

    % Show thickness annotation on plot (top-left, below title)
    if ~isempty(appData.fringeAnnotation) && isvalid(appData.fringeAnnotation)
        appData.fringeAnnotation.String = tStr;
    else
        hold(ax, 'on');
        appData.fringeAnnotation = text(ax, 0.02, 0.96, tStr, ...
            'Units',              'normalized', ...
            'FontSize',           12, ...
            'FontWeight',         'bold', ...
            'Color',              [0.95 0.85 0.20], ...
            'BackgroundColor',    [0.10 0.10 0.10 0.75], ...
            'Margin',             4, ...
            'VerticalAlignment',  'top', ...
            'HitTest',            'off', ...
            'HandleVisibility',   'off', ...
            'Tag',                'GUIFringeAnnotation');
        hold(ax, 'off');
    end

    callbacks.setStatus(tStr);
    drawFringeSpan_(appData, ax);
end

% ════════════════════════════════════════════════════════════════════════
% Local helper — only called from updateFringeThickness, so kept here
% rather than as a separate +bosonPlotter/ entry.
% ════════════════════════════════════════════════════════════════════════
function drawFringeSpan_(appData, ax)
%DRAWFRINGESPAN_  Dashed horizontal connector between the two fringe markers.
    delete(findall(ax, 'Tag', 'GUIFringeSpan'));
    if any(isnan(appData.fringeQ)), return; end
    Q1 = appData.fringeQ(1);
    Q2 = appData.fringeQ(2);
    if numel(appData.fringeMarkers) < 2, return; end
    y1 = appData.fringeMarkers(1).YData;
    y2 = appData.fringeMarkers(2).YData;
    yMid = (y1 + y2) / 2;
    hold(ax, 'on');
    plot(ax, [Q1, Q2], [yMid, yMid], '--', ...
        'Color', [0.95 0.85 0.20 0.6], ...
        'LineWidth', 1.5, ...
        'HitTest', 'off', ...
        'HandleVisibility', 'off', ...
        'Tag', 'GUIFringeSpan');
    hold(ax, 'off');
end
