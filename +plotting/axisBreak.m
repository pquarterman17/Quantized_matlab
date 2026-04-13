function handles = axisBreak(ax, breakValue, options)
%AXISBREAK  Split an axis at a specified value with break marks.
%
%   Syntax:
%       handles = plotting.axisBreak(ax, breakValue)
%       handles = plotting.axisBreak(ax, breakValue, 'Axis', 'y', ...
%                     'GapRatio', 0.05, 'BreakStyle', 'zigzag')
%
%   Inputs:
%       ax         — axes handle containing the data to split
%       breakValue — value along the chosen axis at which to break
%
%   Options:
%       Axis        — 'x' | 'y'  (default: 'y')
%                     Which axis to break.
%       GapRatio    — scalar in (0,1) (default: 0.05)
%                     Fraction of the full axis range to devote to the gap.
%       BreakStyle  — 'zigzag' | 'slash' | 'gap'  (default: 'zigzag')
%                     Visual style of the break marks.
%
%   Output (struct):
%       .ax1        — axes handle for the lower/left sub-axis
%       .ax2        — axes handle for the upper/right sub-axis
%       .breakMarks — array of graphics objects that form the break marks
%       .remove     — function handle; call handles.remove() to restore
%                     the original axes and delete the split axes + marks
%
%   Notes:
%       MATLAB does not natively support broken axes.  This function
%       replaces the input axes with two stacked (Y break) or side-by-side
%       (X break) axes that share the non-broken axis limits.  The original
%       axes is hidden but kept in memory so that remove() can restore it.
%
%       Break marks are drawn as annotation line objects placed at the
%       shared boundary in figure-normalised coordinates, so they survive
%       figure resizing.
%
%   Examples:
%       % Typical VSM hysteresis with a large background offset
%       fig = figure; ax = axes(fig);
%       plot(ax, x, y);
%       h = plotting.axisBreak(ax, 0.5, 'Axis', 'y', 'BreakStyle', 'zigzag');
%
%       % Remove the break and restore original view
%       h.remove();
%
%   See also plotting.formatAxes, annotation

arguments
    ax         (1,1) matlab.graphics.axis.Axes
    breakValue (1,1) double
    options.Axis       (1,:) char {mustBeMember(options.Axis, {'x','y'})} = 'y'
    options.GapRatio   (1,1) double = 0.05
    options.BreakStyle (1,:) char {mustBeMember(options.BreakStyle, ...
        {'zigzag','slash','gap'})} = 'zigzag'
end

% ════════════════════════════════════════════════════════════════════════
%  Validate break position relative to current axis limits
% ════════════════════════════════════════════════════════════════════════
breakAxis  = options.Axis;
gapRatio   = max(0.001, min(0.5, options.GapRatio));
breakStyle = options.BreakStyle;

if strcmp(breakAxis, 'y')
    axLim = ax.YLim;
else
    axLim = ax.XLim;
end

if breakValue <= axLim(1) || breakValue >= axLim(2)
    error('plotting:axisBreak:breakOutOfRange', ...
        'breakValue (%.4g) must be strictly inside the axis limits [%.4g, %.4g].', ...
        breakValue, axLim(1), axLim(2));
end

% ════════════════════════════════════════════════════════════════════════
%  Compute sub-axis limits (gap centred on breakValue)
% ════════════════════════════════════════════════════════════════════════
totalRange = axLim(2) - axLim(1);
halfGap    = gapRatio * totalRange / 2;
lowerLim   = [axLim(1), breakValue - halfGap];
upperLim   = [breakValue + halfGap, axLim(2)];

% ════════════════════════════════════════════════════════════════════════
%  Remember parent container and original axes position / properties
% ════════════════════════════════════════════════════════════════════════
fig       = ancestor(ax, 'figure');
origPos   = ax.Position;   % [left bottom width height] in normalised units
origVis   = ax.Visible;

% ════════════════════════════════════════════════════════════════════════
%  Compute positions of the two sub-axes
% ════════════════════════════════════════════════════════════════════════
%  A thin (~5 %) gap separates the two panels in figure coordinates.
panelGap = 0.01;   % normalised figure units between the two sub-axes

if strcmp(breakAxis, 'y')
    % Vertical split: lower fraction occupies the bottom fraction of origPos
    lowerFrac = (lowerLim(2) - lowerLim(1)) / (totalRange * (1 - gapRatio));
    upperFrac = 1 - lowerFrac;

    lowerH = (origPos(4) - panelGap) * lowerFrac;
    upperH = (origPos(4) - panelGap) * upperFrac;

    pos1 = [origPos(1), origPos(2),               origPos(3), lowerH];
    pos2 = [origPos(1), origPos(2) + lowerH + panelGap, origPos(3), upperH];
else
    % Horizontal split: left sub-axis for smaller x, right for larger x
    lowerFrac = (lowerLim(2) - lowerLim(1)) / (totalRange * (1 - gapRatio));
    upperFrac = 1 - lowerFrac;

    lowerW = (origPos(3) - panelGap) * lowerFrac;
    upperW = (origPos(3) - panelGap) * upperFrac;

    pos1 = [origPos(1),               origPos(2), lowerW, origPos(4)];
    pos2 = [origPos(1) + lowerW + panelGap, origPos(2), upperW, origPos(4)];
end

% ════════════════════════════════════════════════════════════════════════
%  Hide original axes and create the two sub-axes
% ════════════════════════════════════════════════════════════════════════
ax.Visible = 'off';

ax1 = axes(fig, 'Position', pos1); %#ok<LAXES>
ax2 = axes(fig, 'Position', pos2); %#ok<LAXES>

CopyAxesAppearance(ax, ax1);
CopyAxesAppearance(ax, ax2);

% ════════════════════════════════════════════════════════════════════════
%  Copy line/scatter children to both sub-axes
% ════════════════════════════════════════════════════════════════════════
lines = findobj(ax, 'Type', 'line', '-or', 'Type', 'scatter', ...
    '-or', 'Type', 'errorbar');

for k = numel(lines):-1:1
    src = lines(k);
    CopyGraphicsObject(src, ax1, ax2, breakAxis, lowerLim, upperLim);
end

% ════════════════════════════════════════════════════════════════════════
%  Set limits on sub-axes
% ════════════════════════════════════════════════════════════════════════
if strcmp(breakAxis, 'y')
    ax1.YLim = lowerLim;   ax1.YLimMode = 'manual';
    ax2.YLim = upperLim;   ax2.YLimMode = 'manual';
    % Sync x limits
    xLim = ax.XLim;
    ax1.XLim = xLim;  ax1.XLimMode = 'manual';
    ax2.XLim = xLim;  ax2.XLimMode = 'manual';
    % Remove x tick labels / label from upper axes, remove top box edge on lower
    ax2.XTickLabel = {};
    ax2.XLabel.String = '';
    ax1.XLabel.String = ax.XLabel.String;
    ax1.YLabel.String = '';
    % Place y label centred across both axes
    ax2.YLabel.String = ax.YLabel.String;
else
    ax1.XLim = lowerLim;   ax1.XLimMode = 'manual';
    ax2.XLim = upperLim;   ax2.XLimMode = 'manual';
    % Sync y limits
    yLim = ax.YLim;
    ax1.YLim = yLim;  ax1.YLimMode = 'manual';
    ax2.YLim = yLim;  ax2.YLimMode = 'manual';
    % Remove y tick labels / label from right axes
    ax2.YTickLabel = {};
    ax2.YLabel.String = '';
    ax1.YLabel.String = ax.YLabel.String;
    ax1.XLabel.String = '';
    ax2.XLabel.String = ax.XLabel.String;
end

% Propagate titles only to top/right sub-axis
ax2.Title.String = ax.Title.String;

% ════════════════════════════════════════════════════════════════════════
%  Draw break marks
% ════════════════════════════════════════════════════════════════════════
if ~strcmp(breakStyle, 'gap')
    breakMarks = DrawBreakMarks(fig, ax1, ax2, breakAxis, breakStyle);
else
    breakMarks = gobjects(0);
end

% ════════════════════════════════════════════════════════════════════════
%  Build output struct
% ════════════════════════════════════════════════════════════════════════
handles.ax1        = ax1;
handles.ax2        = ax2;
handles.breakMarks = breakMarks;
handles.remove     = @() RemoveBreak(ax, ax1, ax2, breakMarks, origVis);

end


% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function CopyAxesAppearance(src, dst)
%COPYAXESAPPEARANCE  Duplicate cosmetic properties from src to dst axes.
    dst.FontName  = src.FontName;
    dst.FontSize  = src.FontSize;
    dst.TickDir   = src.TickDir;
    dst.Box       = src.Box;
    dst.GridAlpha = src.GridAlpha;
    dst.XScale    = src.XScale;
    dst.YScale    = src.YScale;
    dst.Color     = src.Color;
    if strcmp(src.XGrid, 'on'),  grid(dst, 'on');  end
    hold(dst, 'on');
end

function CopyGraphicsObject(src, ax1, ax2, breakAxis, lowerLim, upperLim)
%COPYGRAPHICSOBJECT  Replicate a graphics object into each sub-axes.
%   Data points are not filtered — both axes share identical data, and
%   clipping is handled automatically by the axis limits set afterwards.
    typ = get(src, 'Type');

    props.Color     = src.Color;

    if strcmp(typ, 'line')
        props.LineStyle  = src.LineStyle;
        props.LineWidth  = src.LineWidth;
        props.Marker     = src.Marker;
        props.MarkerSize = src.MarkerSize;
        props.MarkerFaceColor = src.MarkerFaceColor;
        props.MarkerEdgeColor = src.MarkerEdgeColor;
        props.DisplayName = src.DisplayName;

        xd = src.XData;  yd = src.YData;

        line(ax1, xd, yd, 'Color', props.Color, ...
            'LineStyle', props.LineStyle, 'LineWidth', props.LineWidth, ...
            'Marker', props.Marker, 'MarkerSize', props.MarkerSize, ...
            'MarkerFaceColor', props.MarkerFaceColor, ...
            'MarkerEdgeColor', props.MarkerEdgeColor, ...
            'DisplayName', props.DisplayName, ...
            'HandleVisibility', src.HandleVisibility);

        line(ax2, xd, yd, 'Color', props.Color, ...
            'LineStyle', props.LineStyle, 'LineWidth', props.LineWidth, ...
            'Marker', props.Marker, 'MarkerSize', props.MarkerSize, ...
            'MarkerFaceColor', props.MarkerFaceColor, ...
            'MarkerEdgeColor', props.MarkerEdgeColor, ...
            'DisplayName', props.DisplayName, ...
            'HandleVisibility', src.HandleVisibility);

    elseif strcmp(typ, 'scatter')
        xd = src.XData;  yd = src.YData;
        scatter(ax1, xd, yd, src.SizeData, 'filled', ...
            'MarkerFaceColor', props.Color, 'MarkerEdgeColor', props.Color, ...
            'DisplayName', src.DisplayName, ...
            'HandleVisibility', src.HandleVisibility);
        scatter(ax2, xd, yd, src.SizeData, 'filled', ...
            'MarkerFaceColor', props.Color, 'MarkerEdgeColor', props.Color, ...
            'DisplayName', src.DisplayName, ...
            'HandleVisibility', src.HandleVisibility);

    elseif strcmp(typ, 'errorbar')
        xd = src.XData;  yd = src.YData;
        yneg = src.YNegativeDelta;  ypos = src.YPositiveDelta;
        errorbar(ax1, xd, yd, yneg, ypos, ...
            'Color', props.Color, 'LineStyle', src.LineStyle, ...
            'LineWidth', src.LineWidth, ...
            'DisplayName', src.DisplayName, ...
            'HandleVisibility', src.HandleVisibility);
        errorbar(ax2, xd, yd, yneg, ypos, ...
            'Color', props.Color, 'LineStyle', src.LineStyle, ...
            'LineWidth', src.LineWidth, ...
            'DisplayName', src.DisplayName, ...
            'HandleVisibility', src.HandleVisibility);
    end

    % suppress unused-variable lint on breakAxis / lowerLim / upperLim
    % (kept as parameters for future filtering extension)
    unused = {breakAxis, lowerLim, upperLim}; %#ok<NASGU>
end

function marks = DrawBreakMarks(fig, ax1, ax2, breakAxis, breakStyle)
%DRAWBREAKMARKS  Add // marks at the boundary between the two sub-axes.
%   Marks are placed using annotation('line') in figure-normalised units.
%   Each call to annotation returns one handle; we collect all of them.

    % Get figure-normalised positions of the two sub-axes boundary edges
    ax1Pos = GetNormPos(fig, ax1);
    ax2Pos = GetNormPos(fig, ax2);

    % For a Y break: ax1 is bottom, ax2 is top.
    % The boundary is between ax1.top and ax2.bottom.
    % For an X break: ax1 is left, ax2 is right.
    % The boundary is between ax1.right and ax2.left.

    markList = {};

    if strcmp(breakAxis, 'y')
        % Boundary y-coords in figure normalised space
        yTop    = ax1Pos(2) + ax1Pos(4);    % top of lower axes
        yBot    = ax2Pos(2);                % bottom of upper axes
        yCenter = (yTop + yBot) / 2;

        % Two marks side-by-side, at 1/3 and 2/3 of the axes width
        for xFrac = [0.3, 0.7]
            xMark = ax1Pos(1) + xFrac * ax1Pos(3);
            markList{end+1} = DrawSingleMark(fig, xMark, yCenter, ...
                breakStyle, 'y'); %#ok<AGROW>
        end

    else  % x break
        % Boundary x-coords
        xRight  = ax1Pos(1) + ax1Pos(3);   % right of left axes
        xLeft   = ax2Pos(1);               % left of right axes
        xCenter = (xRight + xLeft) / 2;

        % Two marks stacked at 1/3 and 2/3 of the axes height
        for yFrac = [0.3, 0.7]
            yMark = ax1Pos(2) + yFrac * ax1Pos(4);
            markList{end+1} = DrawSingleMark(fig, xCenter, yMark, ...
                breakStyle, 'x'); %#ok<AGROW>
        end
    end

    marks = [markList{:}];
end

function pos = GetNormPos(fig, ax)
%GETNORMPOS  Return axes Position in figure-normalised units.
    origUnits = ax.Units;
    ax.Units  = 'normalized';
    pos = ax.Position;
    ax.Units = origUnits;
    unused = fig; %#ok<NASGU> % fig kept as parameter for future TightInset handling
end

function handles = DrawSingleMark(fig, xCenter, yCenter, breakStyle, breakAxis)
%DRAWSINGLEMARK  Draw one pair of break mark lines at a given centre point.
%   Lines are drawn on a full-figure overlay axes (normalised units [0,1])
%   so they survive figure resizing.  Returns the line object handles.
%
%   annotation('line') only supports 2-point straight lines, so we use a
%   transparent overlay axes instead, which supports arbitrary polylines.

    if strcmp(breakAxis, 'y')
        tickW = 0.012;   % half-width in normalised x
        tickH = 0.008;   % amplitude in normalised y
    else
        tickW = 0.008;
        tickH = 0.012;
    end

    c = [0.3 0.3 0.3];   % dark grey

    % Reuse an existing overlay axes on this figure, or create one
    overlayTag = 'axisBreakOverlay';
    axOver = findobj(fig, 'Tag', overlayTag, 'Type', 'axes');
    if isempty(axOver)
        axOver = axes(fig, ...
            'Position', [0 0 1 1], ...
            'XLim', [0 1], 'YLim', [0 1], ...
            'HitTest', 'off', 'Color', 'none', ...
            'XColor', 'none', 'YColor', 'none', ...
            'Tag', overlayTag);
        axOver.XAxis.Visible = 'off';
        axOver.YAxis.Visible = 'off';
    end
    hold(axOver, 'on');

    switch breakStyle
        case 'zigzag'
            % Z-shaped polyline: /\/
            if strcmp(breakAxis, 'y')
                xd = [xCenter - tickW, xCenter - tickW/3, ...
                      xCenter + tickW/3, xCenter + tickW];
                yd = [yCenter, yCenter + tickH, yCenter - tickH, yCenter];
            else
                xd = [xCenter, xCenter + tickW, xCenter - tickW, xCenter];
                yd = [yCenter - tickH, yCenter - tickH/3, ...
                      yCenter + tickH/3, yCenter + tickH];
            end
            h1 = line(axOver, xd, yd, 'Color', c, 'LineWidth', 1.5, ...
                'Clipping', 'off');
            handles = h1;

        case 'slash'
            % Two short parallel diagonal lines (//)
            if strcmp(breakAxis, 'y')
                offset = tickW * 0.5;
                h1 = line(axOver, ...
                    [xCenter - tickW - offset, xCenter + tickW - offset], ...
                    [yCenter - tickH, yCenter + tickH], ...
                    'Color', c, 'LineWidth', 1.5, 'Clipping', 'off');
                h2 = line(axOver, ...
                    [xCenter - tickW + offset, xCenter + tickW + offset], ...
                    [yCenter - tickH, yCenter + tickH], ...
                    'Color', c, 'LineWidth', 1.5, 'Clipping', 'off');
            else
                offset = tickH * 0.5;
                h1 = line(axOver, ...
                    [xCenter - tickW, xCenter + tickW], ...
                    [yCenter - tickH - offset, yCenter + tickH - offset], ...
                    'Color', c, 'LineWidth', 1.5, 'Clipping', 'off');
                h2 = line(axOver, ...
                    [xCenter - tickW, xCenter + tickW], ...
                    [yCenter - tickH + offset, yCenter + tickH + offset], ...
                    'Color', c, 'LineWidth', 1.5, 'Clipping', 'off');
            end
            handles = [h1 h2];

        otherwise
            handles = gobjects(0);
    end
end

function RemoveBreak(origAx, ax1, ax2, breakMarks, origVis)
%REMOVEBREAK  Restore the original axes and clean up the split axes + marks.
    % Delete sub-axes (also removes their children)
    if isvalid(ax1), delete(ax1); end
    if isvalid(ax2), delete(ax2); end

    % Delete break mark line objects; clean up empty overlay if needed
    for k = 1:numel(breakMarks)
        if isvalid(breakMarks(k))
            overlayAx = breakMarks(k).Parent;
            delete(breakMarks(k));
            % Remove overlay axes when it has no remaining children
            if isvalid(overlayAx) && isempty(overlayAx.Children)
                delete(overlayAx);
            end
        end
    end

    % Restore original axes
    if isvalid(origAx)
        origAx.Visible = origVis;
    end
end
