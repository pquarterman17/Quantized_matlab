function data = getActiveData(appData, ddX, lbY, efXMin, efXMax)
%GETACTIVEDATA  Resolve x, y, mask, metadata for the peak workshop.
%
%   data = bosonPlotter.peak.getActiveData(appData, ddX, lbY, efXMin, efXMax)
%
%   Used by the Peak Workshop's hook to feed (x, y) into the model. Returns
%   a struct with .x .y .mask .meta .xLabel .yLabel — already sorted by x
%   ascending and restricted to the visible x-range filter (efXMin/efXMax).
%   When no dataset is loaded or no Y channel is selected, returns a struct
%   with empty .x/.y so the caller can short-circuit cleanly.
%
%   Inputs are passed as raw widget handles (not as a closure-bound `ctx`)
%   so this stays callable from anywhere — including tests that synthesise
%   minimal widget stubs.

    data = struct('x', [], 'y', [], 'mask', [], 'meta', struct(), ...
                  'xLabel', '', 'yLabel', '');

    if isempty(appData.datasets) || appData.activeIdx < 1, return; end
    ds = appData.datasets{appData.activeIdx};
    if ~isempty(ds.corrData)
        d = ds.corrData;
    else
        d = ds.data;
    end

    % Resolve X channel (Time vs a column name).
    xSel = ddX.Value;
    if isfield(d.metadata, 'x_column_name') && ~isempty(d.metadata.x_column_name)
        xName = d.metadata.x_column_name;
    else
        xName = 'Time';
    end
    if strcmp(xSel, xName)
        xv = double(d.time);
    else
        ix = find(strcmp(d.labels, xSel), 1);
        if isempty(ix), xv = double(d.time); else, xv = d.values(:, ix); end
    end

    % Resolve Y channel (first listbox selection).
    if iscell(lbY.Value), ySel = lbY.Value; else, ySel = {lbY.Value}; end
    if isempty(ySel), return; end
    yIdx = find(strcmp(d.labels, ySel{1}), 1);
    if isempty(yIdx), return; end
    yv = d.values(:, yIdx);

    dmask = bosonPlotter.peak.buildDisplayMask(ds);
    valid = ~isnan(xv) & ~isnan(yv) & dmask;
    xv = xv(valid);  yv = yv(valid);

    % Apply visible-range filter (used by Auto Peaks). Skip if not set.
    xMinLim = str2double(efXMin.Value);
    xMaxLim = str2double(efXMax.Value);
    if ~isnan(xMinLim) && ~isnan(xMaxLim) && xMinLim < xMaxLim
        inView = xv >= xMinLim & xv <= xMaxLim;
        if sum(inView) >= 5
            xv = xv(inView);  yv = yv(inView);
        end
    end

    % Sort ascending — model methods require monotone xv.
    [xv, sortIdx] = sort(xv);
    yv = yv(sortIdx);

    data.x      = xv;
    data.y      = yv;
    data.mask   = dmask(valid);
    data.meta   = d.metadata;
    data.xLabel = xSel;
    data.yLabel = ySel{1};
end
