function [ds, bgOrder, p] = onBGMouseUp(ax, appData, fig, wgts)
%ONBGMOUSEUP  Process background-fit mouse-up: box selection → polyfit.
%   Reads the box region drawn on the axes, collects data points within it
%   (using displayed/corrected data but fitting against raw data), and
%   returns the fitted polynomial for the active dataset.
%
%   Syntax:
%     [ds, bgOrder, p] = bosonPlotter.onBGMouseUp(ax, appData, fig, wgts)
%
%   Inputs:
%     ax      - main axes handle (reads CurrentPoint and bgRectPatch)
%     appData - application state struct (reads bgStartPt, bgRectPatch,
%               bgXVecRaw, axisPrefixX/Y, datasets, activeIdx)
%     fig     - figure handle (for uialert dialogs)
%     wgts    - widget struct with fields:
%                 .lbY            - listbox: selected Y channels
%                 .ddBGOrder      - dropdown: 'Linear' or 'Poly N'
%                 .lblRegionStats - label: region statistics display
%
%   Outputs:
%     ds      - updated dataset struct (ds.bgPoly set; [] if aborted)
%     bgOrder - polynomial order used (1 for linear)
%     p       - polyfit coefficient vector ([] if aborted)
%
%   The caller is responsible for:
%     - Restoring fig.WindowButtonDownFcn / MotionFcn / UpFcn
%     - Resetting btnFitBG text/color and btnPickY.Enable
%     - Storing ds back into appData.datasets{activeIdx}
%     - Calling onApplyCorrections
%
%   Examples:
%     [ds, bgOrder, p] = bosonPlotter.onBGMouseUp(ax, appData, fig, wgts);
%     if isempty(ds), return; end
%     appData.datasets{appData.activeIdx} = ds;
%     if bgOrder == 1
%         efBGSlope.Value     = p(1);
%         efBGIntercept.Value = p(2);
%     end

    ds      = [];
    bgOrder = 0;
    p       = [];

    if isempty(appData.bgStartPt)
        return;
    end

    cp    = ax.CurrentPoint;
    endPt = [cp(1,1), cp(1,2)];

    if ~isempty(appData.bgRectPatch) && isvalid(appData.bgRectPatch)
        delete(appData.bgRectPatch);
    end

    xMin = min(appData.bgStartPt(1), endPt(1));
    xMax = max(appData.bgStartPt(1), endPt(1));
    yMin = min(appData.bgStartPt(2), endPt(2));
    yMax = max(appData.bgStartPt(2), endPt(2));

    if (xMax - xMin) < eps(xMax)
        uialert(fig,'Box too narrow — drag across a wider x range.','BG fit');
        return;
    end

    % Use displayed (corrected) data for hit-testing the box region,
    % then map selected indices back to raw data for the polynomial fit.
    % This ensures the box drawn on the preview matches the visible data,
    % while the BG polynomial operates in raw coordinates (as expected
    % by onApplyCorrections).
    dsActive = appData.datasets{appData.activeIdx};
    d        = dsActive.data;
    dDisp    = guiTernary_local(~isempty(dsActive.corrData), dsActive.corrData, dsActive.data);
    xVecRaw  = appData.bgXVecRaw;

    % Build the displayed x vector to match dDisp.values row count.
    % Also apply SI prefix scaling so coordinates match the axes.
    if ~isdatetime(dDisp.time)
        xDisp = double(dDisp.time);
    else
        xDisp = (1:numel(dDisp.time))';
    end
    pfX = appData.axisPrefixX;
    pfY = appData.axisPrefixY;
    if pfX.factor ~= 1, xDisp = xDisp * pfX.factor; end

    ySel = ensureCell_local(wgts.lbY.Value);

    xPool = [];
    yPool = [];
    for k = 1:numel(ySel)
        idx = find(strcmp(dDisp.labels, ySel{k}), 1);
        if isempty(idx), continue; end
        yDisp = dDisp.values(:, idx);
        if pfY.factor ~= 1, yDisp = yDisp * pfY.factor; end
        nDisp = min(numel(xDisp), numel(yDisp));
        inBox = xDisp(1:nDisp) >= xMin & xDisp(1:nDisp) <= xMax & ...
                yDisp(1:nDisp) >= yMin & yDisp(1:nDisp) <= yMax & ...
                ~isnan(xDisp(1:nDisp)) & ~isnan(yDisp(1:nDisp));
        % Map back to raw data for polyfit (use same row indices)
        idxRaw = find(strcmp(d.labels, ySel{k}), 1);
        if isempty(idxRaw), idxRaw = idx; end
        % When trimming is active, dDisp may have fewer rows than d;
        % find the corresponding raw rows via the trim mask.
        rawRows = bgDisplayToRawRows_local(dsActive, inBox);
        xPool = [xPool; xVecRaw(rawRows)];          %#ok<AGROW>
        yPool = [yPool; d.values(rawRows, idxRaw)];  %#ok<AGROW>
    end

    % Display region statistics
    if numel(yPool) >= 1
        wgts.lblRegionStats.Text = sprintf( ...
            'Region: n=%d  mean=%.4g  std=%.4g  min=%.4g  max=%.4g', ...
            numel(yPool), mean(yPool), std(yPool), min(yPool), max(yPool));
    else
        wgts.lblRegionStats.Text = '';
    end

    if numel(xPool) < 2
        uialert(fig, ...
            sprintf('Only %d data point(s) inside the box — need at least 2 to fit.', ...
                    numel(xPool)), ...
            'Too few points');
        return;
    end

    % Determine polynomial order from ddBGOrder
    bgOrderStr = wgts.ddBGOrder.Value;
    if strcmp(bgOrderStr, 'Linear')
        bgOrder = 1;
    else
        bgOrder = str2double(bgOrderStr(6:end));  % 'Poly N' → N
    end

    p = polyfit(xPool, yPool, bgOrder);

    % Return updated dataset
    ds = appData.datasets{appData.activeIdx};
    if bgOrder == 1
        ds.bgPoly = [];   % clear polynomial storage (use widget values)
    else
        ds.bgPoly = p;
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m — not accessible cross-file)
% ════════════════════════════════════════════════════════════════════════

function rawRows = bgDisplayToRawRows_local(ds, dispMask)
%BGDISPLAYTORAWROWS_LOCAL  Map displayed-data logical mask to raw row indices.
    d = ds.data;
    nRaw = numel(d.time);
    trimMin = guiTernary_local(isfield(ds,'xTrimMin'), ds.xTrimMin, NaN);
    trimMax = guiTernary_local(isfield(ds,'xTrimMax'), ds.xTrimMax, NaN);
    if isdatetime(d.time)
        keepMask = true(nRaw, 1);
    else
        tVec = double(d.time);
        keepMask = true(nRaw, 1);
        if ~isnan(trimMin), keepMask = keepMask & tVec >= trimMin; end
        if ~isnan(trimMax), keepMask = keepMask & tVec <= trimMax; end
    end
    keptIdx = find(keepMask);
    if numel(dispMask) < numel(keptIdx)
        dispMask(end+1:numel(keptIdx)) = false;
    end
    rawRows = keptIdx(dispMask(1:numel(keptIdx)));
end

function v = guiTernary_local(cond, a, b)
    if cond, v = a; else, v = b; end
end

function c = ensureCell_local(v)
    if ischar(v) || isstring(v)
        c = cellstr(v);
    else
        c = v;
    end
end
