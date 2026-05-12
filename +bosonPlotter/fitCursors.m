function cursors = fitCursors(ax, xMin, xMax, onRangeChanged)
%FITCURSORS  Create draggable vertical cursor lines that define a fit region.
%
%   Syntax:
%       cursors = bosonPlotter.fitCursors(ax, xMin, xMax, onRangeChanged)
%
%   Inputs:
%       ax              axes handle in which to draw the cursors
%       xMin            initial left cursor x-position
%       xMax            initial right cursor x-position
%       onRangeChanged  function_handle  called as onRangeChanged(xL, xR)
%                       whenever either cursor is released after dragging
%
%   Outputs:
%       cursors — struct with fields:
%         .lineL      left cursor line handle  (blue dashed)
%         .lineR      right cursor line handle (red dashed)
%         .remove     function handle — call to delete both cursors cleanly
%         .setRange   function handle(xL, xR) — move cursors programmatically
%         .getRange   function handle() — returns [xL, xR]
%
%   Description:
%       Draws two full-height vertical dashed lines on AX.  Either line
%       can be grabbed with a left-click and dragged horizontally.  On
%       release, ONRANGECHANGED is invoked with the updated endpoints.
%       The callback is also invoked when setRange is called externally
%       (e.g. from an edit-field listener), so callers do not need to
%       duplicate synchronisation logic.
%
%   Examples:
%       c = bosonPlotter.fitCursors(ax, 0.5, 2.5, @(l,r) disp([l r]));
%       c.setRange(1.0, 3.0);   % move programmatically
%       c.remove();             % clean up

% ════════════════════════════════════════════════════════════════════════
% Internal state
% ════════════════════════════════════════════════════════════════════════

xL = xMin;
xR = xMax;

% Track which cursor is being dragged
dragging = '';          % 'left' | 'right' | ''

fig = ancestor(ax, 'figure');
savedMotionFcn = '';
savedUpFcn     = '';

% ════════════════════════════════════════════════════════════════════════
% Draw cursor lines
% ════════════════════════════════════════════════════════════════════════

yl = ylim(ax);
lineL = plot(ax, [xL xL], yl, '--', ...
    'Color', [0.15 0.40 0.85], 'LineWidth', 1.5, ...
    'Tag', 'FitCursorL', 'HandleVisibility', 'off', ...
    'PickableParts', 'all', 'HitTest', 'on');
lineL.ButtonDownFcn = @(~,~) startDrag('left');

lineR = plot(ax, [xR xR], yl, '--', ...
    'Color', [0.80 0.15 0.15], 'LineWidth', 1.5, ...
    'Tag', 'FitCursorR', 'HandleVisibility', 'off', ...
    'PickableParts', 'all', 'HitTest', 'on');
lineR.ButtonDownFcn = @(~,~) startDrag('right');

% Keep cursors on top of data lines
uistack(lineL, 'top');
uistack(lineR, 'top');

% ════════════════════════════════════════════════════════════════════════
% Public interface struct
% ════════════════════════════════════════════════════════════════════════

cursors.lineL    = lineL;
cursors.lineR    = lineR;
cursors.remove   = @removeCursors;
cursors.setRange = @setRange;
cursors.getRange = @getRange;

% ════════════════════════════════════════════════════════════════════════
% Nested helpers
% ════════════════════════════════════════════════════════════════════════

    function startDrag(side)
    %STARTDRAG  Attach motion/up handlers and begin dragging.
        dragging = side;
        savedMotionFcn = fig.WindowButtonMotionFcn;
        savedUpFcn     = fig.WindowButtonUpFcn;
        fig.WindowButtonMotionFcn = @onDragMotion;
        fig.WindowButtonUpFcn     = @onDragRelease;
        fig.Pointer = 'left';
    end

    function onDragMotion(~, ~)
    %ONDRAGMOTION  Move the active cursor as the mouse moves.
        if isempty(dragging), return; end
        cp = ax.CurrentPoint;
        xNow = cp(1, 1);

        % Clamp to axis limits
        xl = ax.XLim;
        xNow = max(xl(1), min(xl(2), xNow));

        % Enforce left < right with a small buffer
        switch dragging
            case 'left'
                xNow = min(xNow, xR - (xl(2) - xl(1)) * 0.001);
                xL   = xNow;
                moveLine(lineL, xL);
            case 'right'
                xNow = max(xNow, xL + (xl(2) - xl(1)) * 0.001);
                xR   = xNow;
                moveLine(lineR, xR);
        end
        drawnow limitrate
    end

    function onDragRelease(~, ~)
    %ONDRAGRELEASE  Restore saved callbacks and fire onRangeChanged.
        dragging = '';
        fig.WindowButtonMotionFcn = savedMotionFcn;
        fig.WindowButtonUpFcn     = savedUpFcn;
        fig.Pointer = 'arrow';
        if isvalid(ax)
            onRangeChanged(xL, xR);
        end
    end

    function moveLine(h, x)
    %MOVELINE  Update an existing cursor line to a new x-position.
        if isvalid(h)
            yl = ax.YLim;
            h.XData = [x x];
            h.YData = yl;
        end
    end

    function setRange(newXL, newXR)
    %SETRANGE  Move cursors programmatically, then fire onRangeChanged.
        xL = newXL;
        xR = newXR;
        moveLine(lineL, xL);
        moveLine(lineR, xR);
        onRangeChanged(xL, xR);
    end

    function out = getRange()
    %GETRANGE  Return current [xL, xR].
        out = [xL, xR];
    end

    function removeCursors()
    %REMOVECURSORS  Delete cursor lines and restore saved figure callbacks.
        if isvalid(lineL), delete(lineL); end
        if isvalid(lineR), delete(lineR); end
        if isvalid(fig) && ~isempty(dragging)
            fig.WindowButtonMotionFcn = savedMotionFcn;
            fig.WindowButtonUpFcn     = savedUpFcn;
            fig.Pointer = 'arrow';
        end
        dragging = '';
    end

end
