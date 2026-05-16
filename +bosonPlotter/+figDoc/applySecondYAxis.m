function applySecondYAxis(ax, model)
%APPLYSECONDYAXIS  Move designated traces to right Y-axis and style it.
%
%   bosonPlotter.figDoc.applySecondYAxis(ax, model)
%
%   If any trace in model.traceYAxis is 'right', enables yyaxis on the axes,
%   moves those line objects to the right side, and applies y2Lim/y2Scale/y2Label.

    if isempty(ax) || ~isvalid(ax), return; end
    if isempty(model) || ~model.hasRightAxis(), return; end

    lines = findobj(ax.Children, 'Type', 'Line');
    lines = lines(~startsWith(string({lines.Tag}'), 'figDoc'));
    if isempty(lines), return; end

    nTraces = numel(lines);
    assignments = model.traceYAxis;

    rightIdxs = [];
    for k = 1:min(numel(assignments), nTraces)
        if strcmp(assignments{k}, 'right')
            rightIdxs(end+1) = k; %#ok<AGROW>
        end
    end
    if isempty(rightIdxs), return; end

    leftData = {};
    rightData = {};

    for k = 1:nTraces
        ln = lines(nTraces - k + 1); % reverse draw order
        entry.XData = ln.XData;
        entry.YData = ln.YData;
        entry.DisplayName = ln.DisplayName;
        entry.Color = ln.Color;
        entry.LineWidth = ln.LineWidth;
        entry.LineStyle = ln.LineStyle;
        entry.Marker = ln.Marker;
        entry.MarkerSize = ln.MarkerSize;
        if k <= numel(assignments) && strcmp(assignments{k}, 'right')
            rightData{end+1} = entry; %#ok<AGROW>
        else
            leftData{end+1} = entry; %#ok<AGROW>
        end
    end

    delete(lines);

    yyaxis(ax, 'left');
    hold(ax, 'on');
    for k = 1:numel(leftData)
        d = leftData{k};
        plot(ax, d.XData, d.YData, ...
            'DisplayName', d.DisplayName, 'Color', d.Color, ...
            'LineWidth', d.LineWidth, 'LineStyle', d.LineStyle, ...
            'Marker', d.Marker, 'MarkerSize', d.MarkerSize);
    end

    yyaxis(ax, 'right');
    for k = 1:numel(rightData)
        d = rightData{k};
        plot(ax, d.XData, d.YData, ...
            'DisplayName', d.DisplayName, 'Color', d.Color, ...
            'LineWidth', d.LineWidth, 'LineStyle', d.LineStyle, ...
            'Marker', d.Marker, 'MarkerSize', d.MarkerSize);
    end
    hold(ax, 'off');

    if isequal(model.y2Lim, 'auto')
        ax.YLimMode = 'auto';
    else
        ax.YLim = model.y2Lim;
    end
    ax.YScale = model.y2Scale;
    if strlength(model.y2Label) > 0
        ax.YLabel.String = model.y2Label;
        ax.YLabel.FontSize = model.fontSize;
        ax.YLabel.FontName = model.fontName;
    end

    yyaxis(ax, 'left');
end
