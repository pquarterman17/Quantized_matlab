function onFringeMarkerMove(appData, ax, lbY, callbacks)
%ONFRINGEMARKERMOVE  Update fringe-marker position while user drags it.
%
% Syntax
%   bosonPlotter.onFringeMarkerMove(appData, ax, lbY, callbacks)
%
% Behaviour
%   Installed as the figure's `WindowButtonMotionFcn` while a fringe
%   marker drag is in progress.  Snaps the currently-dragged marker
%   (`appData.fringeDragIdx`) to the nearest x-data point on any of the
%   currently selected Y traces.  Updates `appData.fringeQ(idx)` and the
%   marker's XData/YData in place, then calls
%   `callbacks.updateFringeThickness` to refresh the displayed
%   t = 2*pi / |DeltaQ| readout.  Exits early when no marker is active
%   (`fringeDragIdx` out of 1..2 range).
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads fringeDragIdx,
%                 datasets, activeIdx; mutates fringeQ, fringeMarkers)
%   ax        - Main axes handle (reads CurrentPoint)
%   lbY       - Y-trace listbox widget (reads .Value for selection)
%   callbacks - Struct of function handles:
%                 .updateFringeThickness()

    idx = appData.fringeDragIdx;
    if idx < 1 || idx > 2, return; end

    cp = ax.CurrentPoint;
    xDrag = cp(1,1);

    ds = appData.datasets{appData.activeIdx};
    if ~isempty(ds.corrData)
        primaryD = ds.corrData;
    else
        primaryD = ds.data;
    end
    xVec = double(primaryD.time);
    ySel2 = ensureCell(lbY.Value);

    bestX = xDrag;
    bestY = cp(1,2);
    bestDx = Inf;
    for k = 1:numel(ySel2)
        yIdx = find(strcmp(primaryD.labels, ySel2{k}), 1);
        if isempty(yIdx), continue; end
        yVec = primaryD.values(:, yIdx);
        valid = ~isnan(xVec) & ~isnan(yVec);
        [mDx, mI] = min(abs(xVec(valid) - xDrag));
        if mDx < bestDx
            bestDx = mDx;
            validIdx = find(valid);
            bestX = xVec(validIdx(mI));
            bestY = yVec(validIdx(mI));
        end
    end

    appData.fringeQ(idx) = bestX;
    hm = appData.fringeMarkers(idx);
    if isvalid(hm)
        hm.XData = bestX;
        hm.YData = bestY;
    end

    callbacks.updateFringeThickness();
    drawnow limitrate;
end

function c = ensureCell(v)
    if iscell(v), c = v; elseif isempty(v), c = {}; else, c = {v}; end
end
