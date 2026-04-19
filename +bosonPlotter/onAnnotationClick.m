function onAnnotationClick(appData, fig, ax, callbacks)
%ONANNOTATIONCLICK  Handle clicks in annotation mode: add or delete annotations.
%
% Syntax
%   bosonPlotter.onAnnotationClick(appData, fig, ax, callbacks)
%
% Behaviour
%   Installed as the figure's `WindowButtonDownFcn` while annotation
%   mode is active.  Reads the click position in axes coordinates and:
%     * Left-click (inside the plot area)  — prompts for text via
%       `inputdlg`, appends a `struct('x', .., 'y', .., 'text', ..)`
%       entry to `ds.annotations`, and re-renders.
%     * Right-click (`fig.SelectionType == 'alt'`) — deletes the
%       annotation closest to the click, provided it lies within 5% of
%       the axes range (normalised Euclidean distance).
%   Clicks outside the current `ax.XLim` / `ax.YLim` are silently
%   ignored.  The nearest-neighbour deletion lives as a local
%   subfunction in this package file.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutates datasets)
%   fig       - Main figure handle (reads SelectionType)
%   ax        - Main axes handle (reads CurrentPoint / XLim / YLim)
%   callbacks - Struct of function handles:
%                 .onPlot()  - re-render after mutation

    if isempty(appData.datasets) || appData.activeIdx < 1
        return;
    end

    cp = ax.CurrentPoint;
    x = cp(1,1);
    y = cp(1,2);

    if x < ax.XLim(1) || x > ax.XLim(2) || ...
       y < ax.YLim(1) || y > ax.YLim(2)
        return;
    end

    if strcmp(fig.SelectionType, 'alt')
        deleteNearestAnnotation(appData, ax, x, y);
        callbacks.onPlot();
        return;
    end

    answer = inputdlg('Enter annotation text:', 'Add Annotation', [1 40]);
    if isempty(answer) || isempty(strtrim(answer{1}))
        return;
    end

    annotText = strtrim(answer{1});

    ds = appData.datasets{appData.activeIdx};
    if ~isfield(ds, 'annotations') || isempty(ds.annotations)
        ds.annotations = {};
    end

    annot = struct('x', x, 'y', y, 'text', annotText);
    ds.annotations{end+1} = annot;
    appData.datasets{appData.activeIdx} = ds;

    callbacks.onPlot();
end

% ════════════════════════════════════════════════════════════════════════
% Local helper — nearest-neighbour deletion
% ════════════════════════════════════════════════════════════════════════

function deleteNearestAnnotation(appData, ax, x, y)
%DELETENEARESTANNOTATION  Remove the annotation closest to (x, y).
    ds = appData.datasets{appData.activeIdx};
    if isempty(ds.annotations)
        return;
    end

    xRange = ax.XLim(2) - ax.XLim(1);
    yRange = ax.YLim(2) - ax.YLim(1);
    thresh = 0.05;

    minDist = inf;
    minIdx = -1;

    for ai = 1:numel(ds.annotations)
        annot = ds.annotations{ai};
        dx = abs(annot.x - x) / xRange;
        dy = abs(annot.y - y) / yRange;
        dist = sqrt(dx^2 + dy^2);

        if dist < thresh && dist < minDist
            minDist = dist;
            minIdx = ai;
        end
    end

    if minIdx > 0
        ds.annotations(minIdx) = [];
        appData.datasets{appData.activeIdx} = ds;
    end
end
