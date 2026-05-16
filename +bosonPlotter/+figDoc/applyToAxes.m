function applyToAxes(ax, model)
%APPLYTOAXES  Apply FigDocModel state to axes — idempotent.
%
%   bosonPlotter.figDoc.applyToAxes(ax, model)
%
%   Reads the model's axes, legend, margins, trace style, and annotation
%   properties and applies them to the given axes handle. Safe to call
%   repeatedly (idempotent). Never touches trace XData/YData.
%
%   Inputs:
%     ax    - axes handle (uiaxes or standard axes)
%     model - FigDocModel handle

    if isempty(ax) || ~isvalid(ax), return; end
    if isempty(model), return; end

    % ── Axis limits ──────────────────────────────────────────────────────
    if isequal(model.xLim, 'auto')
        ax.XLimMode = 'auto';
    else
        ax.XLim = model.xLim;
    end

    if isequal(model.yLim, 'auto')
        ax.YLimMode = 'auto';
    else
        ax.YLim = model.yLim;
    end

    % ── Axis scale ───────────────────────────────────────────────────────
    ax.XScale = model.xScale;
    ax.YScale = model.yScale;

    % ── Labels ───────────────────────────────────────────────────────────
    if strlength(model.xLabel) > 0
        ax.XLabel.String = model.xLabel;
        ax.XLabel.FontSize = model.fontSize;
        ax.XLabel.FontName = model.fontName;
    end
    if strlength(model.yLabel) > 0
        ax.YLabel.String = model.yLabel;
        ax.YLabel.FontSize = model.fontSize;
        ax.YLabel.FontName = model.fontName;
    end

    % ── Font ─────────────────────────────────────────────────────────────
    ax.FontSize = model.fontSize;
    ax.FontName = model.fontName;

    % ── Grid & ticks ─────────────────────────────────────────────────────
    if model.gridOn
        ax.XGrid = 'on'; ax.YGrid = 'on';
    else
        ax.XGrid = 'off'; ax.YGrid = 'off';
    end

    if model.minorTicks
        ax.XMinorTick = 'on'; ax.YMinorTick = 'on';
    else
        ax.XMinorTick = 'off'; ax.YMinorTick = 'off';
    end

    ax.TickDir = model.tickDir;

    if model.boxOn
        ax.Box = 'on';
    else
        ax.Box = 'off';
    end

    % ── Margins (axes position) ──────────────────────────────────────────
    m = model.margins; % [left right top bottom]
    pos = [m(1), m(4), 1 - m(1) - m(2), 1 - m(3) - m(4)];
    if all(pos(3:4) > 0)
        ax.Position = pos;
    end

    % ── Per-trace style overrides ────────────────────────────────────────
    lines = findobj(ax.Children, 'Type', 'Line');
    for k = 1:min(numel(model.traceStyles), numel(lines))
        s = model.traceStyles{k};
        ln = lines(numel(lines) - k + 1); % lines are in reverse draw order
        if isfield(s, 'color') && ~isempty(s.color)
            ln.Color = s.color;
        end
        if isfield(s, 'lineWidth') && ~isempty(s.lineWidth)
            ln.LineWidth = s.lineWidth;
        end
        if isfield(s, 'lineStyle') && ~isempty(s.lineStyle)
            ln.LineStyle = s.lineStyle;
        end
        if isfield(s, 'marker') && ~isempty(s.marker)
            ln.Marker = s.marker;
        end
        if isfield(s, 'markerSize') && ~isempty(s.markerSize)
            ln.MarkerSize = s.markerSize;
        end
        if isfield(s, 'displayName') && ~isempty(s.displayName)
            ln.DisplayName = s.displayName;
        end
    end

    % ── Second Y-axis ────────────────────────────────────────────────────
    if model.hasRightAxis()
        bosonPlotter.figDoc.applySecondYAxis(ax, model);
    end

    % ── Legend ────────────────────────────────────────────────────────────
    applyLegend(ax, model);

    % ── Annotations ──────────────────────────────────────────────────────
    applyAnnotations(ax, model);

    model.markClean();
end

% ═════════════════════════════════════════════════════════════════════════
function applyLegend(ax, model)
    if ~model.legendVisible
        legend(ax, 'off');
        return;
    end

    lines = findobj(ax.Children, 'Type', 'Line');
    if isempty(lines), return; end

    hasNames = false;
    for k = 1:numel(lines)
        if strlength(string(lines(k).DisplayName)) > 0
            hasNames = true;
            break;
        end
    end
    if ~hasNames, return; end

    lgd = legend(ax);
    lgd.FontSize = model.legendFontSize;
    lgd.Orientation = model.legendOrientation;

    if isnumeric(model.legendLocation) && numel(model.legendLocation) == 4
        lgd.Position = model.legendLocation;
    else
        lgd.Location = model.legendLocation;
    end

    if model.legendColumns > 1 && isprop(lgd, 'NumColumns')
        lgd.NumColumns = model.legendColumns;
    end
end

% ═════════════════════════════════════════════════════════════════════════
function applyAnnotations(ax, model)
    % Remove existing figDoc-managed annotations
    old = findobj(ax, 'Tag', 'figDocAnnotation');
    delete(old);

    for k = 1:numel(model.annotations)
        a = model.annotations{k};
        switch a.type
            case 'text'
                fs = 10;
                col = [0 0 0];
                if isfield(a, 'style')
                    if isfield(a.style, 'fontSize'), fs = a.style.fontSize; end
                    if isfield(a.style, 'color'), col = a.style.color; end
                end
                text(ax, a.position(1), a.position(2), a.text, ...
                    'FontSize', fs, 'Color', col, ...
                    'Tag', 'figDocAnnotation');

            case 'arrow'
                lw = 1.5;
                col = [0 0 0];
                if isfield(a, 'style')
                    if isfield(a.style, 'lineWidth'), lw = a.style.lineWidth; end
                    if isfield(a.style, 'color'), col = a.style.color; end
                end
                line(ax, [a.position(1) a.position(3)], [a.position(2) a.position(4)], ...
                    'Color', col, 'LineWidth', lw, ...
                    'Marker', '>', 'MarkerIndices', 2, 'MarkerSize', 8, ...
                    'MarkerFaceColor', col, ...
                    'Tag', 'figDocAnnotation', 'HandleVisibility', 'off');

            case 'bracket'
                % future: bracket annotation
        end
    end
end
