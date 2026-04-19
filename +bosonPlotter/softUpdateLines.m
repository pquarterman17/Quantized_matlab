function softUpdateLines(appData, callbacks)
%SOFTUPDATELINES  Update line colors and visibility without a full redraw.
%
% Syntax
%   bosonPlotter.softUpdateLines(appData, callbacks)
%
% Behaviour
%   Fast-path refresh for color / visibility changes: walks the cached
%   left-axis and right-axis line handles in `appData.lineCache` and
%   sets `.Visible` and `.Color` in place.  Falls back to a full redraw
%   via `callbacks.onPlot` in any of the following cases:
%     * Line cache is marked invalid (`appData.lineCache.valid` false).
%     * A cached line handle has been deleted from the axes since the
%       cache was populated (e.g. a corrections change that triggered
%       a full replot has not yet repopulated the cache).
%   Finishes with `drawnow limitrate` so the update is visible without
%   blocking the caller.
%
% Inputs
%   appData    - bosonPlotter.AppState handle (reads datasets;
%                   reads/mutates lineCache)
%   callbacks  - Struct of function handles:
%                   .onPlot(src, evt)  - full-redraw fallback

    if ~appData.lineCache.valid
        callbacks.onPlot([],[]);
        return;
    end

    nDS = numel(appData.datasets);

    for di = 1:nDS
        ds = appData.datasets{di};
        vis = 'on';
        if isfield(ds, 'visible') && ~ds.visible
            vis = 'off';
        end
        col = ds.color;

        for k = 1:size(appData.lineCache.left, 2)
            if di <= size(appData.lineCache.left, 1)
                h = appData.lineCache.left{di, k};
                if isvalid(h)
                    h.Visible = vis;
                    if ~isempty(col)
                        h.Color = col;
                    end
                else
                    appData.lineCache.valid = false;
                    callbacks.onPlot([],[]);
                    return;
                end
            end
        end
    end

    for di = 1:nDS
        ds = appData.datasets{di};
        vis = 'on';
        if isfield(ds, 'visible') && ~ds.visible
            vis = 'off';
        end
        colR = ds.colorR;

        for k = 1:size(appData.lineCache.right, 2)
            if di <= size(appData.lineCache.right, 1)
                h = appData.lineCache.right{di, k};
                if isvalid(h)
                    h.Visible = vis;
                    if ~isempty(colR)
                        h.Color = colR;
                    end
                else
                    appData.lineCache.valid = false;
                    callbacks.onPlot([],[]);
                    return;
                end
            end
        end
    end

    drawnow limitrate;
end
