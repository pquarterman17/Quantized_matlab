function handles = insetGraph(parentAx, region, options)
%INSETGRAPH  Create an inset axes showing a zoomed region of the parent.
%
%   Syntax
%     handles = bosonPlotter.insetGraph(parentAx, region)
%     handles = bosonPlotter.insetGraph(parentAx, region, Name=Value, ...)
%
%   Inputs
%     parentAx — parent axes handle (matlab.graphics.axis.Axes)
%     region   — [xMin xMax yMin yMax] region to zoom into (1x4 double)
%
%   Name-Value Options
%     Position        — normalized position of inset within parent axes
%                       [left bottom width height], default [0.55 0.55 0.35 0.35]
%     LineWidth       — border line width of the inset axes, default 0.8
%     BackgroundColor — RGB triplet for inset background, default [1 1 1]
%
%   Outputs
%     handles — struct with fields:
%       .insetAx    — axes handle for the inset
%       .rect       — rectangle handle drawn on parentAx marking the region
%       .connectors — 2-element array of line handles (corner connector lines)
%
%   Examples
%     h = bosonPlotter.insetGraph(gca, [0.1 0.5 -2 2])
%     h = bosonPlotter.insetGraph(gca, [0.1 0.5 -2 2], Position=[0.6 0.6 0.3 0.3])
%
%   Notes
%     The inset is draggable: click and drag the inset axes to reposition it.
%     The zoom rectangle on the parent axes has draggable corners that update
%     the inset region when moved.  Call bosonPlotter.insetGraph again after a
%     parent replot to refresh the inset content — the function detects an
%     existing inset (via Tag) and updates it in place.

% ════════════════════════════════════════════════════════════════════════════

arguments
    parentAx (1,1) matlab.graphics.axis.Axes
    region   (1,4) double  % [xMin xMax yMin yMax]
    options.Position        (1,4) double = [0.55 0.55 0.35 0.35]
    options.LineWidth       (1,1) double = 0.8
    options.BackgroundColor (1,3) double = [1 1 1]
end

% ── Validate region ──────────────────────────────────────────────────────
xMin = region(1); xMax = region(2);
yMin = region(3); yMax = region(4);
if xMin >= xMax || yMin >= yMax
    error('bosonPlotter:insetGraph:invalidRegion', ...
        'region must satisfy xMin < xMax and yMin < yMax.');
end

% ── Remove any existing inset on this parent (one inset per axes) ────────
cleanupExisting(parentAx);

% ── Create the inset axes ────────────────────────────────────────────────
parentFig = ancestor(parentAx, 'figure');
if isempty(parentFig)
    error('bosonPlotter:insetGraph:noFigure', ...
        'parentAx must belong to a figure.');
end

insetAx = axes(parentFig, ...
    'Units',           'normalized', ...
    'InnerPosition',   computeInsetPosition(parentAx, options.Position), ...
    'Color',           options.BackgroundColor, ...
    'Box',             'on', ...
    'FontSize',        8, ...
    'XLim',            [xMin xMax], ...
    'YLim',            [yMin yMax], ...
    'Tag',             'bosonInset', ...
    'UserData',        struct('parentAx', parentAx, 'region', region, ...
                              'normPos', options.Position));

% Inherit font from parent where possible
try
    insetAx.FontName = parentAx.FontName;
catch
end

% ── Copy line objects from parent into inset ─────────────────────────────
copyLinesToInset(parentAx, insetAx);

% ── Clean up inset decorations ────────────────────────────────────────────
legend(insetAx, 'off');
title(insetAx,  '');
xlabel(insetAx, '');
ylabel(insetAx, '');

% ── Draw zoom rectangle on parent ────────────────────────────────────────
rectH = drawZoomRect(parentAx, region, options.LineWidth);

% ── Draw connector lines from rect corners to inset corners ──────────────
connH = drawConnectors(parentAx, insetAx, region, options.LineWidth);

% ── Tag inset axes with sibling handles so cleanup is self-contained ─────
insetAx.UserData = struct( ...
    'parentAx',  parentAx, ...
    'region',    region, ...
    'normPos',   options.Position, ...
    'rectHandle', rectH, ...
    'connHandles', connH);

% ── Wire drag interaction on the inset axes ───────────────────────────────
wireDragBehavior(insetAx, parentAx, connH, rectH);

% ── Wire cleanup listener: delete inset when parent is cleared/deleted ────
addlistener(parentAx, 'ObjectBeingDestroyed', ...
    @(~,~) safeDelete({insetAx, rectH, connH(isvalid(connH))}));

% ── Output ───────────────────────────────────────────────────────────────
handles.insetAx    = insetAx;
handles.rect       = rectH;
handles.connectors = connH;

end

% ════════════════════════════════════════════════════════════════════════════
%  Module-level helpers
% ════════════════════════════════════════════════════════════════════════════

function cleanupExisting(parentAx)
%CLEANUPEXISTING  Remove any bosonInset and its decorations from parentAx.
    parentFig = ancestor(parentAx, 'figure');
    if isempty(parentFig), return; end
    existing = findobj(parentFig, 'Tag', 'bosonInset');
    for k = 1:numel(existing)
        ax = existing(k);
        if ~isgraphics(ax), continue; end
        ud = ax.UserData;
        if isstruct(ud)
            safeDelete({ud.rectHandle});
            if isfield(ud, 'connHandles')
                safeDelete(num2cell(ud.connHandles));
            end
        end
        delete(ax);
    end
    % Also clean up any orphaned rect/connector objects on the parent
    orphanRects = findobj(parentAx, 'Tag', 'bosonInsetRect');
    orphanLines = findobj(parentAx, 'Tag', 'bosonInsetConnector');
    delete(orphanRects);
    delete(orphanLines);
end

function safeDelete(handleCell)
%SAFEDELETE  Delete graphics handles that are still valid.
    for k = 1:numel(handleCell)
        h = handleCell{k};
        try
            if ~isempty(h) && isgraphics(h) && isvalid(h)
                delete(h);
            end
        catch
        end
    end
end

function insetPos = computeInsetPosition(parentAx, normPos)
%COMPUTEINSETPOSITION  Convert normalized-within-axes coords to figure coords.
%   normPos is [left bottom width height] relative to the parent axes inner
%   position.  Returns absolute normalized position suitable for axes InnerPosition.
    axPos = parentAx.InnerPosition;   % [left bottom width height] normalized in figure
    insetPos = [ ...
        axPos(1) + normPos(1) * axPos(3), ...
        axPos(2) + normPos(2) * axPos(4), ...
        normPos(3) * axPos(3), ...
        normPos(4) * axPos(4)];
end

function copyLinesToInset(parentAx, insetAx)
%COPYLINESTOINSET  Duplicate visible line objects from parentAx into insetAx.
%   Copies XData, YData, Color, LineStyle, LineWidth, Marker, MarkerSize.
%   Skips HandleVisibility='off' objects (cursors, overlays, etc.).
    lineObjs = findobj(parentAx, 'Type', 'line', ...
                       '-not', 'HandleVisibility', 'off');
    hold(insetAx, 'on');
    for k = numel(lineObjs):-1:1   % reverse to preserve draw order
        lh = lineObjs(k);
        if ~isgraphics(lh) || isempty(lh.XData), continue; end
        try
            newLine = line(insetAx, lh.XData, lh.YData, ...
                'Color',       lh.Color, ...
                'LineStyle',   lh.LineStyle, ...
                'LineWidth',   lh.LineWidth, ...
                'Marker',      lh.Marker, ...
                'MarkerSize',  lh.MarkerSize, ...
                'HandleVisibility', 'off');
            % Copy marker colors if they are explicit (not 'auto')
            try
                if ~strcmpi(char(lh.MarkerFaceColor), 'auto')
                    newLine.MarkerFaceColor = lh.MarkerFaceColor;
                end
                if ~strcmpi(char(lh.MarkerEdgeColor), 'auto')
                    newLine.MarkerEdgeColor = lh.MarkerEdgeColor;
                end
            catch
            end
        catch
        end
    end
    hold(insetAx, 'off');
end

function rectH = drawZoomRect(parentAx, region, lineWidth)
%DRAWZOOMRECT  Draw a dashed rectangle on parentAx marking the zoom region.
    xMin = region(1); xMax = region(2);
    yMin = region(3); yMax = region(4);

    hold(parentAx, 'on');
    rectH = rectangle(parentAx, ...
        'Position',   [xMin, yMin, xMax-xMin, yMax-yMin], ...
        'EdgeColor',  [0.2 0.4 0.8], ...
        'LineWidth',  lineWidth, ...
        'LineStyle',  '--', ...
        'FaceColor',  'none', ...
        'HandleVisibility', 'off', ...
        'Tag',        'bosonInsetRect', ...
        'PickableParts', 'all');
    hold(parentAx, 'off');
end

function connH = drawConnectors(parentAx, insetAx, region, lineWidth)
%DRAWCONNECTORS  Draw two connector lines from the zoom rect to the inset corners.
%   Uses the top-right and bottom-right corners of the rect connecting to the
%   corresponding corners of the inset axes in data coordinates.
    [rectCorners, insetCorners] = resolveConnectorEndpoints(parentAx, insetAx, region);

    hold(parentAx, 'on');
    connH = gobjects(1, 2);
    for k = 1:2
        connH(k) = line(parentAx, ...
            [rectCorners(k,1), insetCorners(k,1)], ...
            [rectCorners(k,2), insetCorners(k,2)], ...
            'Color',            [0.2 0.4 0.8], ...
            'LineWidth',        lineWidth, ...
            'LineStyle',        ':', ...
            'HandleVisibility', 'off', ...
            'Tag',              'bosonInsetConnector', ...
            'PickableParts',    'none');
    end
    hold(parentAx, 'off');
end

function [rectCorners, insetCorners] = resolveConnectorEndpoints(parentAx, insetAx, region)
%RESOLVECONNECTORENDPOINTS  Calculate current connector endpoints in parent data coords.
%   Uses two corners (top-right and bottom-right of the zoom rect) connecting to
%   the corresponding corners of the inset in data space.

    xMax = region(2);
    yMin = region(3); yMax = region(4);

    % Rectangle corners (top-right, bottom-right)
    rectCorners = [xMax, yMax;
                   xMax, yMin];

    % Inset corners mapped back to parent data coordinates
    insetCorners = insetCornersInParentData(parentAx, insetAx);
end

function corners = insetCornersInParentData(parentAx, insetAx)
%INSETCORNERSINPARENTDATA  Get inset top-right and bottom-right in parent data coords.
    try
        % Inset position in figure-normalized units
        iPos = insetAx.InnerPosition;      % [l b w h] normalized
        pPos = parentAx.InnerPosition;     % [l b w h] normalized

        % Inset corners (top-right, bottom-right) in figure-normalized coords
        figTR = [iPos(1)+iPos(3),  iPos(2)+iPos(4)];
        figBR = [iPos(1)+iPos(3),  iPos(2)];

        % Convert to axes-normalized coords within parentAx
        axTR = [(figTR(1) - pPos(1)) / pPos(3), (figTR(2) - pPos(2)) / pPos(4)];
        axBR = [(figBR(1) - pPos(1)) / pPos(3), (figBR(2) - pPos(2)) / pPos(4)];

        % Convert axes-normalized to data coordinates
        xl = parentAx.XLim; yl = parentAx.YLim;
        corners = [ ...
            xl(1) + axTR(1)*(xl(2)-xl(1)),  yl(1) + axTR(2)*(yl(2)-yl(1));
            xl(1) + axBR(1)*(xl(2)-xl(1)),  yl(1) + axBR(2)*(yl(2)-yl(1))];
    catch
        % Fallback: place connectors at current axis extents
        xl = parentAx.XLim; yl = parentAx.YLim;
        corners = [xl(2), yl(2); xl(2), yl(1)];
    end
end

function updateConnectors(connH, parentAx, insetAx, region)
%UPDATECONNECTORS  Recalculate and redraw the connector line endpoints.
    if any(~isgraphics(connH)), return; end
    [rectCorners, insetCorners] = resolveConnectorEndpoints(parentAx, insetAx, region);
    for k = 1:2
        connH(k).XData = [rectCorners(k,1), insetCorners(k,1)];
        connH(k).YData = [rectCorners(k,2), insetCorners(k,2)];
    end
end

% ════════════════════════════════════════════════════════════════════════════
%  Drag interaction
% ════════════════════════════════════════════════════════════════════════════

function wireDragBehavior(insetAx, parentAx, connH, ~)
%WIREDRAGBEHAVIOR  Attach mouse-drag callbacks to move the inset axes.
%   Uses WindowButtonDownFcn, WindowButtonMotionFcn, WindowButtonUpFcn on
%   the parent figure.  Guards against simultaneous drags.
    parentFig = ancestor(parentAx, 'figure');
    if isempty(parentFig), return; end

    % Store drag state in inset UserData (already a struct)
    ud = insetAx.UserData;
    ud.dragging    = false;
    ud.dragStart   = [];   % [x y] in figure-normalized at button down
    ud.posAtStart  = [];   % inset InnerPosition at button down
    insetAx.UserData = ud;

    % Attach ButtonDownFcn on the inset axes itself
    insetAx.ButtonDownFcn = @(~, evt) onInsetButtonDown(insetAx, parentAx, connH, parentFig, evt);
end

function onInsetButtonDown(insetAx, parentAx, connH, parentFig, ~)
%ONINSETBUTTONDOWN  Start drag on left-click of inset axes.
    if ~isgraphics(insetAx) || ~isgraphics(parentFig), return; end
    if ~strcmp(parentFig.SelectionType, 'normal'), return; end  % left-click only

    ud = insetAx.UserData;
    ud.dragging   = true;
    ud.posAtStart = insetAx.InnerPosition;
    ud.dragStart  = parentFig.CurrentPoint;   % [x y] normalized 0..1
    insetAx.UserData = ud;

    % Store previous callbacks to restore after drag
    ud.prevMotion = parentFig.WindowButtonMotionFcn;
    ud.prevUp     = parentFig.WindowButtonUpFcn;
    insetAx.UserData = ud;

    parentFig.WindowButtonMotionFcn = @(~,~) onInsetDragMotion(insetAx, parentAx, connH, parentFig);
    parentFig.WindowButtonUpFcn     = @(~,~) onInsetDragUp(insetAx, parentFig);
end

function onInsetDragMotion(insetAx, parentAx, connH, parentFig)
%ONINSETDRAGMOTION  Update inset position during drag.
    if ~isgraphics(insetAx), return; end
    ud = insetAx.UserData;
    if ~isfield(ud, 'dragging') || ~ud.dragging, return; end

    curPt  = parentFig.CurrentPoint;
    delta  = curPt - ud.dragStart;            % [dx dy] normalized

    newPos = ud.posAtStart;
    newPos(1) = newPos(1) + delta(1);
    newPos(2) = newPos(2) + delta(2);

    % Clamp to figure bounds [0..1] with a small margin
    margin = 0.005;
    newPos(1) = max(margin, min(1 - newPos(3) - margin, newPos(1)));
    newPos(2) = max(margin, min(1 - newPos(4) - margin, newPos(2)));

    insetAx.InnerPosition = newPos;

    % Update connector lines to follow the new inset position
    if isgraphics(parentAx) && all(isgraphics(connH))
        updateConnectors(connH, parentAx, insetAx, ud.region);
    end
end

function onInsetDragUp(insetAx, parentFig)
%ONINSETDRAGUP  End drag and restore previous figure callbacks.
    if ~isgraphics(insetAx) || ~isgraphics(parentFig), return; end
    ud = insetAx.UserData;
    ud.dragging = false;
    insetAx.UserData = ud;

    % Restore figure callbacks
    try
        parentFig.WindowButtonMotionFcn = ud.prevMotion;
        parentFig.WindowButtonUpFcn     = ud.prevUp;
    catch
        parentFig.WindowButtonMotionFcn = '';
        parentFig.WindowButtonUpFcn     = '';
    end
end
