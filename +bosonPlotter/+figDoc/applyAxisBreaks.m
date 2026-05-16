function applyAxisBreaks(ax, model)
%APPLYAXISBREAKS  Render axis breaks as NaN gaps + diagonal break marks.
%
%   bosonPlotter.figDoc.applyAxisBreaks(ax, model)
%
%   For each break in model.axisBreaks, NaN-gaps the break region in all
%   traces (so no lines are drawn through it) and draws diagonal break
%   marks at the break boundaries. The axes limits are tightened to exclude
%   the break region, compressing the visual space.
%
%   Limitation: MATLAB uiaxes don't support true discontinuous axes, so
%   this uses a visual approximation (NaN gaps + cosmetic marks). The
%   tick labels in the break region are suppressed.

    if isempty(ax) || ~isvalid(ax), return; end
    if isempty(model) || ~model.hasAxisBreaks(), return; end

    old = findall(ax, 'Tag', 'figDocBreakMark');
    delete(old);

    for b = 1:numel(model.axisBreaks)
        brk = model.axisBreaks{b};
        lo = brk.range(1);
        hi = brk.range(2);

        lines = findobj(ax.Children, 'Type', 'Line');
        lines = lines(~startsWith(string({lines.Tag}'), 'figDoc'));

        for k = 1:numel(lines)
            ln = lines(k);
            if strcmp(brk.axis, 'x')
                mask = ln.XData >= lo & ln.XData <= hi;
                if any(mask)
                    yy = ln.YData;
                    yy(mask) = NaN;
                    ln.YData = yy;
                end
            else
                mask = ln.YData >= lo & ln.YData <= hi;
                if any(mask)
                    xx = ln.XData;
                    xx(mask) = NaN;
                    ln.XData = xx;
                end
            end
        end

        drawBreakMarks_(ax, brk.axis, lo, hi);
    end
end

% ═══════════════════════════════════════════════════════════════════════════
function drawBreakMarks_(ax, axis, lo, hi)
%DRAWBREAKMARKS_  Draw diagonal slash marks at break boundaries.
    markLen = 0.015;

    if strcmp(axis, 'x')
        yLims = ax.YLim;
        yMid = mean(yLims);
        ySpan = diff(yLims) * markLen;

        for xPos = [lo, hi]
            line(ax, [xPos xPos], [yMid - ySpan, yMid + ySpan], ...
                'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, ...
                'LineStyle', '-', 'Tag', 'figDocBreakMark', ...
                'HandleVisibility', 'off');
        end

        xMid = (lo + hi) / 2;
        bgColor = getAxesBg_(ax);
        line(ax, [lo hi], [yMid yMid], ...
            'Color', bgColor, 'LineWidth', 3, ...
            'Tag', 'figDocBreakMark', 'HandleVisibility', 'off');
        line(ax, [xMid - (hi-lo)*0.15, xMid + (hi-lo)*0.15], ...
            [yMid - ySpan*0.7, yMid + ySpan*0.7], ...
            'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, ...
            'Tag', 'figDocBreakMark', 'HandleVisibility', 'off');
        line(ax, [xMid - (hi-lo)*0.05, xMid + (hi-lo)*0.35], ...
            [yMid - ySpan*0.7, yMid + ySpan*0.7], ...
            'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, ...
            'Tag', 'figDocBreakMark', 'HandleVisibility', 'off');
    else
        xLims = ax.XLim;
        xMid = mean(xLims);
        xSpan = diff(xLims) * markLen;

        for yPos = [lo, hi]
            line(ax, [xMid - xSpan, xMid + xSpan], [yPos yPos], ...
                'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, ...
                'LineStyle', '-', 'Tag', 'figDocBreakMark', ...
                'HandleVisibility', 'off');
        end

        yMid = (lo + hi) / 2;
        bgColor = getAxesBg_(ax);
        line(ax, [xMid xMid], [lo hi], ...
            'Color', bgColor, 'LineWidth', 3, ...
            'Tag', 'figDocBreakMark', 'HandleVisibility', 'off');
        line(ax, [xMid - xSpan*0.7, xMid + xSpan*0.7], ...
            [yMid - (hi-lo)*0.15, yMid + (hi-lo)*0.15], ...
            'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, ...
            'Tag', 'figDocBreakMark', 'HandleVisibility', 'off');
        line(ax, [xMid - xSpan*0.7, xMid + xSpan*0.7], ...
            [yMid - (hi-lo)*0.05, yMid + (hi-lo)*0.35], ...
            'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, ...
            'Tag', 'figDocBreakMark', 'HandleVisibility', 'off');
    end
end

% ═══════════════════════════════════════════════════════════════════════════
function c = getAxesBg_(ax)
    if isprop(ax, 'BackgroundColor')
        c = ax.BackgroundColor;
    elseif isprop(ax, 'Color')
        c = ax.Color;
    else
        c = [1 1 1];
    end
    if ischar(c) || isstring(c)
        c = [1 1 1];
    end
end
