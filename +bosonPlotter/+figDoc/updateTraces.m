function updateTraces(ax, datasets, activeIdx, overlayMode)
%UPDATETRACES  Non-destructive trace data update — never wipes style/layout.
%
%   bosonPlotter.figDoc.updateTraces(ax, datasets, activeIdx, overlayMode)
%
%   Updates XData/YData of existing line objects in-place. Creates new lines
%   only when the trace count changes. Removes lines for datasets no longer
%   visible. NEVER touches Color, LineWidth, Marker, or other style props.
%
%   Each line is tagged 'figDocTrace_<dsIndex>' for stable identification.
%
%   Inputs:
%     ax          - axes handle
%     datasets    - cell array of dataset structs (with .data or .corrData)
%     activeIdx   - scalar index of the active dataset
%     overlayMode - logical, if true show all visible datasets

    if isempty(ax) || ~isvalid(ax), return; end

    % Determine which datasets to display
    if overlayMode
        showIdx = [];
        for k = 1:numel(datasets)
            ds = datasets{k};
            if isfield(ds, 'visible') && ds.visible
                showIdx(end+1) = k; %#ok<AGROW>
            end
        end
    else
        showIdx = activeIdx;
    end

    % Get existing figDoc trace lines
    existingLines = findobj(ax.Children, '-regexp', 'Tag', '^figDocTrace_');

    % Build map of existing tag → handle
    existMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for k = 1:numel(existingLines)
        existMap(existingLines(k).Tag) = existingLines(k);
    end

    % Track which tags we want to keep
    keepTags = {};

    hold(ax, 'on');

    for k = 1:numel(showIdx)
        dsIdx = showIdx(k);
        ds = datasets{dsIdx};
        tag = sprintf('figDocTrace_%d', dsIdx);
        keepTags{end+1} = tag; %#ok<AGROW>

        % Get X/Y data from corrected or raw
        [xData, yData, dispName] = extractPlotData(ds);
        if isempty(xData) || isempty(yData), continue; end

        if existMap.isKey(tag)
            % Update in place — preserve all style properties
            ln = existMap(tag);
            ln.XData = xData;
            ln.YData = yData;
            if ~isempty(dispName)
                ln.DisplayName = dispName;
            end
        else
            % Create new line with default style
            ln = plot(ax, xData, yData, ...
                'Tag', tag, ...
                'DisplayName', dispName);
            applyDefaultColor(ln, k);
        end
    end

    hold(ax, 'off');

    % Remove lines for datasets no longer shown
    for k = 1:numel(existingLines)
        if ~ismember(existingLines(k).Tag, keepTags)
            delete(existingLines(k));
        end
    end
end

% ═════════════════════════════════════════════════════════════════════════
function [xData, yData, dispName] = extractPlotData(ds)
%EXTRACTPLOTDATA  Get X/Y vectors from a dataset struct.
    xData = [];
    yData = [];
    dispName = '';

    % Prefer corrected data if available
    src = [];
    if isfield(ds, 'corrData') && ~isempty(ds.corrData)
        src = ds.corrData;
    elseif isfield(ds, 'data') && ~isempty(ds.data)
        src = ds.data;
    end

    if isempty(src), return; end

    if isfield(src, 'time') && ~isempty(src.time)
        xData = src.time;
    end

    if isfield(src, 'values') && ~isempty(src.values)
        yData = src.values(:, 1);
    end

    if isfield(ds, 'legendName') && ~isempty(ds.legendName)
        dispName = ds.legendName;
    elseif isfield(src, 'labels') && ~isempty(src.labels)
        dispName = src.labels{1};
    end
end

% ═════════════════════════════════════════════════════════════════════════
function applyDefaultColor(ln, idx)
%APPLYDEFAULTCOLOR  Apply a color from the default color order.
    colors = [
        0.000 0.447 0.741
        0.850 0.325 0.098
        0.929 0.694 0.125
        0.494 0.184 0.556
        0.466 0.674 0.188
        0.301 0.745 0.933
        0.635 0.078 0.184
    ];
    ln.Color = colors(mod(idx-1, size(colors,1)) + 1, :);
end
