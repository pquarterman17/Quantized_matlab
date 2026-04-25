function applyMaskInBox(appData, ui, xMin, xMax, yMin, yMax, callbacks)
%APPLYMASKINBOX  Mask data points inside the given box for the active dataset.
%
% Syntax
%   bosonPlotter.applyMaskInBox(appData, ui, xMin, xMax, yMin, yMax, callbacks)
%
% Inputs
%   appData    - bosonPlotter.AppState handle (mutated: datasets{activeIdx}.mask)
%   ui         - widget struct, must include:
%                  .ddX  — x-channel dropdown (Value used)
%                  .lbY  — y-channel listbox  (Value used)
%   xMin, xMax - x bounds of the mask box (data coordinates)
%   yMin, yMax - y bounds of the mask box
%   callbacks  - struct of function handles:
%                  .setStatus(msg)  — write status-line message
%                  .onPlot()        — re-render the active dataset
%
% Notes
%   Builds a mask in displayed-data space (corrData if present, else raw),
%   then maps it back to raw row indices accounting for any active x-trim
%   (matches the trim logic in onApplyCorrections so the mask aligns with
%   the dataset's true row layout).
%
%   Returns nothing — mutates `appData.datasets{appData.activeIdx}.mask`
%   directly, since AppState is a handle class.

    if isempty(appData.datasets) || appData.activeIdx < 1
        return;
    end

    ds       = appData.datasets{appData.activeIdx};
    primaryD = guiTernary_(~isempty(ds.corrData), ds.corrData, ds.data);

    % Build displayed x vector (mirrors drawToAxes selection logic)
    xSel  = ui.ddX.Value;
    xName = guiXName_(ds.data.metadata);
    if strcmp(xSel, xName)
        xVec = primaryD.time;
    else
        idx = find(strcmp(primaryD.labels, xSel), 1);
        if isempty(idx)
            xVec = primaryD.time;
        else
            xVec = primaryD.values(:, idx);
        end
    end
    xVec = double(xVec);

    % Collect every selected Y channel so a box-select hits any visible trace
    ySel  = ensureCell_(ui.lbY.Value);
    inBox = false(size(xVec));
    for k = 1:numel(ySel)
        yIdx = find(strcmp(primaryD.labels, ySel{k}), 1);
        if isempty(yIdx), continue; end
        yVec = primaryD.values(:, yIdx);
        inBox = inBox | (xVec >= xMin & xVec <= xMax & ...
                         yVec >= yMin & yVec <= yMax);
    end

    % Map displayed indices back to raw indices
    if ~isempty(ds.corrData)
        rawRows = bgDisplayToRawRows_(ds, inBox);
    else
        rawRows = find(inBox);
    end

    if isempty(rawRows), return; end

    if ~isfield(ds, 'mask') || isempty(ds.mask)
        ds.mask = true(size(ds.data.time));
    end
    ds.mask(rawRows) = false;
    appData.datasets{appData.activeIdx} = ds;

    nMasked = sum(~ds.mask);
    callbacks.setStatus(sprintf('Masked %d points (%d total masked)', ...
        numel(rawRows), nMasked));
    callbacks.onPlot();
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers — duplicated from BosonPlotter.m / onBGMouseUp.m so this
% file has no cross-closure dependency.
% ════════════════════════════════════════════════════════════════════════

function rawRows = bgDisplayToRawRows_(ds, dispMask)
%BGDISPLAYTORAWROWS_  Map a displayed-data logical mask to raw row indices.
    d = ds.data;
    nRaw = numel(d.time);
    trimMin = guiTernary_(isfield(ds,'xTrimMin'), ds.xTrimMin, NaN);
    trimMax = guiTernary_(isfield(ds,'xTrimMax'), ds.xTrimMax, NaN);
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

function v = guiTernary_(cond, a, b)
    if cond, v = a; else, v = b; end
end

function c = ensureCell_(v)
    if ischar(v) || isstring(v)
        c = cellstr(v);
    else
        c = v;
    end
end

function name = guiXName_(meta)
%GUIXNAME_  Return metadata's X-column display name, defaulting to 'X'.
    if isfield(meta, 'xColumnName') && ~isempty(meta.xColumnName)
        name = meta.xColumnName;
    else
        name = 'X';
    end
end
