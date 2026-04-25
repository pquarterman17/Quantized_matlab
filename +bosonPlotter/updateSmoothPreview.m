function updateSmoothPreview(appData, ui, ax)
%UPDATESMOOTHPREVIEW  Recompute and redraw the live smoothing preview line.
%
% Syntax
%   bosonPlotter.updateSmoothPreview(appData, ui, ax)
%
% Renders a dashed cyan overlay showing what the smoothed data would
% look like, without mutating any dataset. Always clears the previous
% overlay first. No-ops when the smooth checkbox is off, no datasets
% are loaded, or `utilities.smoothData` errors (e.g. insufficient
% points).
%
% Inputs
%   appData - bosonPlotter.AppState handle (mutates smoothPreviewLine)
%   ui      - widget struct with:
%               .cbSmooth        (logical — gate)
%               .efSmoothWin     (numeric window)
%               .ddSmoothMethod  ('Moving' | 'Gaussian' | 'Savitzky-Golay')
%   ax      - main axes handle

    clearSmoothPreview_(appData);
    if isempty(appData.datasets) || appData.activeIdx < 1, return; end
    if ~ui.cbSmooth.Value, return; end

    ds = appData.datasets{appData.activeIdx};
    d  = guiTernary_(~isempty(ds.corrData), ds.corrData, ds.data);
    if isempty(d) || isempty(d.values), return; end

    xVec = double(d.time);
    yVec = d.values(:, 1);   % preview on first Y column only

    win  = max(1, round(ui.efSmoothWin.Value));
    methVal = methodKey_(ui.ddSmoothMethod.Value);

    try
        ySmooth = utilities.smoothData(yVec, 'Method', methVal, 'Window', win);
    catch
        return;   % silently skip if smoothData fails
    end

    hold(ax, 'on');
    appData.smoothPreviewLine = plot(ax, xVec, ySmooth, ...
        '--', 'Color', [0.2 0.7 1.0], 'LineWidth', 1.5, ...
        'Tag', 'GUISmoothPreview', 'HandleVisibility', 'off');
    hold(ax, 'off');
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers — duplicated so this file has no cross-closure dependency.
% ════════════════════════════════════════════════════════════════════════
function clearSmoothPreview_(appData)
    if isgraphics(appData.smoothPreviewLine)
        delete(appData.smoothPreviewLine);
    end
    appData.smoothPreviewLine = [];
end

function v = guiTernary_(cond, a, b)
    if cond, v = a; else, v = b; end
end

function key = methodKey_(label)
%METHODKEY_  Map GUI dropdown label to utilities.smoothData 'Method' value.
    switch label
        case 'Moving',          key = 'moving';
        case 'Gaussian',        key = 'gaussian';
        case 'Savitzky-Golay',  key = 'savitzky-golay';
        otherwise,              key = 'moving';
    end
end
