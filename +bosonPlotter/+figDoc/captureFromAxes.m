function captureFromAxes(ax, model)
%CAPTUREFROMAXES  Read current axes state back into FigDocModel.
%
%   bosonPlotter.figDoc.captureFromAxes(ax, model)
%
%   Called after user interactions (zoom, pan, legend drag, manual axis
%   edits) to persist the current visual state into the model so it
%   survives the next data re-render.
%
%   Inputs:
%     ax    - axes handle
%     model - FigDocModel handle (mutated in place)

    if isempty(ax) || ~isvalid(ax), return; end
    if isempty(model), return; end

    % ── Axis limits ───────────────────────────────���──────────────────────
    if strcmp(ax.XLimMode, 'manual')
        model.xLim = ax.XLim;
    else
        model.xLim = 'auto';
    end

    if strcmp(ax.YLimMode, 'manual')
        model.yLim = ax.YLim;
    else
        model.yLim = 'auto';
    end

    % ── Axis scale ───────────────────────────────────────────────────────
    model.xScale = ax.XScale;
    model.yScale = ax.YScale;

    % ── Labels ───────────────────────────────────────────────────────────
    if ~isempty(ax.XLabel.String)
        model.xLabel = string(ax.XLabel.String);
    end
    if ~isempty(ax.YLabel.String)
        model.yLabel = string(ax.YLabel.String);
    end

    % ── Font ─────────────────────────────────────────────────────────────
    model.fontSize = ax.FontSize;
    model.fontName = ax.FontName;

    % ── Legend position ──────────────────────────────────────────────────
    lgd = ax.Legend;
    if ~isempty(lgd) && isvalid(lgd)
        model.legendVisible = strcmp(lgd.Visible, 'on');
        model.legendOrientation = lgd.Orientation;
        model.legendFontSize = lgd.FontSize;
        model.legendLocation = lgd.Position; % capture exact [x y w h]
        if isprop(lgd, 'NumColumns')
            model.legendColumns = lgd.NumColumns;
        end
    end

    % ── Margins (axes position) ──────────────────────────────────────────
    pos = ax.Position; % [left bottom width height]
    model.margins = [pos(1), 1-pos(1)-pos(3), 1-pos(2)-pos(4), pos(2)];

    model.markDirty();
end
