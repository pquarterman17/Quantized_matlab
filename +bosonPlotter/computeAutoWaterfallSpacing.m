function s = computeAutoWaterfallSpacing(datasets, activeIdx, ySel, scaleY)
%COMPUTEAUTOWATERFALLSPACING  Return spacing for automatic waterfall plots.
%
% Syntax
%   s = bosonPlotter.computeAutoWaterfallSpacing(datasets, activeIdx, ySel, scaleY)
%
% Inputs
%   datasets  - cell array of loaded dataset structs (appData.datasets)
%   activeIdx - index of the active dataset (appData.activeIdx)
%   ySel      - cell array of selected Y-axis label strings (ensureCell(lbY.Value))
%   scaleY    - Y scale mode string, e.g. 'Log' or 'Linear' (ddScaleY.Value)
%
% Outputs
%   s  - spacing value:
%          Linear mode → additive offset (0.7× max data range)
%          Log mode    → multiplicative factor (10^(0.7 × max log-range))
%
% Notes
%   Linear mode: 0.7× the maximum data range (additive offset).
%   Log mode:    10^(0.7 × max log-range) as a multiplicative factor.
%   SIMS single-file: scan across all selected channels, not datasets.

    nDS2 = numel(datasets);

    % Detect SIMS single-file → scan all selected channels
    isSIMSSingle = (nDS2 == 1) && ...
        isfield(datasets{1},'parserName') && ...
        strcmp(datasets{1}.parserName,'importSIMS') && ...
        numel(ySel) > 1;

    if strcmp(scaleY, 'Log')
        % Log mode — return a multiplier (ratio between adjacent traces)
        s = 10;   % safe fallback: one decade
        if isempty(ySel), return; end
        maxLogRange = 0;
        if isSIMSSingle
            ds2      = datasets{1};
            primaryD = guiTernary(~isempty(ds2.corrData), ds2.corrData, ds2.data);
            dm2      = buildDisplayMask(ds2);
            for ci = 1:numel(ySel)
                idx2 = find(strcmp(primaryD.labels, ySel{ci}), 1);
                if isempty(idx2), continue; end
                yVals = primaryD.values(:, idx2);
                yVals = yVals(yVals > 0 & ~isnan(yVals) & dm2);
                if numel(yVals) < 2, continue; end
                r = log10(max(yVals)) - log10(min(yVals));
                if r > maxLogRange, maxLogRange = r; end
            end
        else
            for ddi = 1:nDS2
                ds2      = datasets{ddi};
                primaryD = guiTernary(~isempty(ds2.corrData), ds2.corrData, ds2.data);
                idx2     = find(strcmp(primaryD.labels, ySel{1}), 1);
                if isempty(idx2), continue; end
                yVals = primaryD.values(:, idx2);
                dm2 = buildDisplayMask(ds2);
                yVals = yVals(yVals > 0 & ~isnan(yVals) & dm2);
                if numel(yVals) < 2, continue; end
                r = log10(max(yVals)) - log10(min(yVals));
                if r > maxLogRange, maxLogRange = r; end
            end
        end
        if maxLogRange > 0, s = 10^(maxLogRange * 0.7); end
    else
        % Linear mode — return an additive offset
        s = 1;   % safe fallback if no data range can be determined
        if isempty(ySel), return; end
        maxRange = 0;
        if isSIMSSingle
            ds2      = datasets{1};
            primaryD = guiTernary(~isempty(ds2.corrData), ds2.corrData, ds2.data);
            dm2      = buildDisplayMask(ds2);
            for ci = 1:numel(ySel)
                idx2 = find(strcmp(primaryD.labels, ySel{ci}), 1);
                if isempty(idx2), continue; end
                yVals = primaryD.values(:, idx2);
                yVals = yVals(~isnan(yVals) & dm2);
                if numel(yVals) < 2, continue; end
                r = max(yVals) - min(yVals);
                if r > maxRange, maxRange = r; end
            end
        else
            for ddi = 1:nDS2
                ds2      = datasets{ddi};
                primaryD = guiTernary(~isempty(ds2.corrData), ds2.corrData, ds2.data);
                idx2     = find(strcmp(primaryD.labels, ySel{1}), 1);
                if isempty(idx2), continue; end
                yVals = primaryD.values(:, idx2);
                dm2 = buildDisplayMask(ds2);
                yVals = yVals(~isnan(yVals) & dm2);
                if numel(yVals) < 2, continue; end
                r = max(yVals) - min(yVals);
                if r > maxRange, maxRange = r; end
            end
        end
        if maxRange > 0, s = maxRange * 0.7; end
    end
end

% ════════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m local function scope)
% ════════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function dmask = buildDisplayMask(ds)
%BUILDDISPLAYMASK  Return logical mask mapped to corrected/displayed data.
%  Translates the raw ds.mask through X-trim so it aligns with corrData.
    if ~isfield(ds, 'mask') || isempty(ds.mask) || all(ds.mask)
        d = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        dmask = true(size(d.time));
        return;
    end
    if ~isempty(ds.corrData)
        nRaw  = numel(ds.data.time);
        keepM = true(nRaw, 1);
        if ~isdatetime(ds.data.time)
            tVM = double(ds.data.time);
            trimMin = guiTernary(isfield(ds,'xTrimMin'), ds.xTrimMin, NaN);
            trimMax = guiTernary(isfield(ds,'xTrimMax'), ds.xTrimMax, NaN);
            if ~isnan(trimMin), keepM = keepM & tVM >= trimMin; end
            if ~isnan(trimMax), keepM = keepM & tVM <= trimMax; end
        end
        dmask = ds.mask(keepM);
    else
        dmask = ds.mask;
    end
end
