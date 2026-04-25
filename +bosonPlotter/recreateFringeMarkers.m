function recreateFringeMarkers(appData, ax, lbY, callbacks)
%RECREATEFRINGEMARKERS  Re-place fringe markers after a full plot redraw.
%
% Syntax
%   bosonPlotter.recreateFringeMarkers(appData, ax, lbY, callbacks)
%
% drawToAxes' cla() destroys the markers and annotation; this rebuilds
% them at the stored Q positions, snapping each marker's Y value to the
% nearest selected-trace data point. Wires the marker's ButtonDownFcn
% back to `bosonPlotter.onFringeMarkerDown` so the user can drag.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads activeIdx/datasets/
%               fringeQ; mutates fringeMarkers/fringeAnnotation)
%   ax        - main axes
%   lbY       - Y-trace listbox
%   callbacks - struct with:
%                 .setStatus(msg)
%                 .onMouseHover(~,~)  — restored after marker drag
%                 (passed through to onFringeMarkerDown)

    ds = appData.datasets{appData.activeIdx};
    primaryD = guiTernary_(~isempty(ds.corrData), ds.corrData, ds.data);
    xVec  = double(primaryD.time);
    ySel  = ensureCell_(lbY.Value);
    markerColors = {[0.10 0.65 0.85], [0.85 0.35 0.10]};
    appData.fringeMarkers = gobjects(1, 2);

    for mi = 1:2
        Qval = appData.fringeQ(mi);
        bestY  = 0;
        bestDx = Inf;
        for k = 1:numel(ySel)
            yIdx = find(strcmp(primaryD.labels, ySel{k}), 1);
            if isempty(yIdx), continue; end
            yVec = primaryD.values(:, yIdx);
            valid = ~isnan(xVec) & ~isnan(yVec);
            [mDx, mI] = min(abs(xVec(valid) - Qval));
            if mDx < bestDx
                bestDx = mDx;
                validIdx = find(valid);
                bestY = yVec(validIdx(mI));
            end
        end
        hold(ax, 'on');
        hm = plot(ax, Qval, bestY, 'v', ...
            'MarkerSize',       12, ...
            'MarkerFaceColor',  markerColors{mi}, ...
            'MarkerEdgeColor',  'w', ...
            'LineWidth',        1.2, ...
            'HitTest',          'on', ...
            'HandleVisibility', 'off', ...
            'Tag',              'GUIFringeMarker');
        % Bind marker click to the drag handler. ButtonDownFcn closure
        % captures fig from the caller via callbacks.fig (passed in).
        hm.ButtonDownFcn = @(~,~) bosonPlotter.onFringeMarkerDown( ...
            mi, appData, callbacks.fig, ax, lbY, callbacks);
        hold(ax, 'off');
        appData.fringeMarkers(mi) = hm;
    end

    appData.fringeAnnotation = [];   % force fresh creation
    bosonPlotter.updateFringeThickness(appData, ax, callbacks);
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers — duplicated to avoid cross-closure lookups.
% ════════════════════════════════════════════════════════════════════════
function v = guiTernary_(cond, a, b)
    if cond, v = a; else, v = b; end
end

function c = ensureCell_(v)
    if ischar(v) || isstring(v)
        c = cellstr(v);
    else
        c = v;
    end
end
