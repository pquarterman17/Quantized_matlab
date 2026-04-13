function insetGraph_remove(parentAx)
%INSETGRAPH_REMOVE  Remove the inset axes and its decorations from parentAx.
%
%   Syntax
%     bosonPlotter.insetGraph_remove(parentAx)
%
%   Inputs
%     parentAx — parent axes handle whose inset should be removed
%
%   Notes
%     This is a no-op if no inset exists on parentAx.  It cleans up
%     the inset axes, zoom rectangle, and connector lines.

% ════════════════════════════════════════════════════════════════════════════

arguments
    parentAx (1,1) matlab.graphics.axis.Axes
end

parentFig = ancestor(parentAx, 'figure');
if isempty(parentFig), return; end

existing = findobj(parentFig, 'Tag', 'bosonInset');
removed  = 0;

for k = 1:numel(existing)
    axH = existing(k);
    if ~isgraphics(axH), continue; end

    ud = axH.UserData;
    if isstruct(ud) && isfield(ud, 'parentAx') && isequal(ud.parentAx, parentAx)
        % Remove decorations on parent axes
        if isfield(ud, 'rectHandle') && isgraphics(ud.rectHandle)
            delete(ud.rectHandle);
        end
        if isfield(ud, 'connHandles')
            ch = ud.connHandles;
            ch = ch(isgraphics(ch));
            if ~isempty(ch), delete(ch); end
        end
        delete(axH);
        removed = removed + 1;
    end
end

% Also clear any orphaned decorator objects (belt-and-suspenders)
orphanRects = findobj(parentAx, 'Tag', 'bosonInsetRect');
orphanLines = findobj(parentAx, 'Tag', 'bosonInsetConnector');
if ~isempty(orphanRects), delete(orphanRects); end
if ~isempty(orphanLines), delete(orphanLines); end

end
