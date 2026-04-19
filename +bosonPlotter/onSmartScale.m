function onSmartScale(appData, ui, callbacks)
%ONSMARTSCALE  Auto-detect linear/log and set reasonable axis limits.
%
% Syntax
%   bosonPlotter.onSmartScale(appData, ui, callbacks)
%
% Behaviour
%   Examines visible data across all loaded datasets and chooses log
%   scale when values are strictly positive and span more than two
%   orders of magnitude (e.g. reflectivity 1e-6 to 1); otherwise uses
%   linear scale.  Axis limits get a 2% margin on linear axes and are
%   rounded to the enclosing decades on log axes.  Per-step edits and
%   Y2 limit edits are cleared so the next plot reflects the fresh
%   auto-range.  Datetime x-axes are skipped (treated as non-scalable).
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads datasets / activeIdx)
%   ui        - Struct with widget handles: ddScaleX, ddScaleY, efXMin,
%               efXMax, efYMin, efYMax, efXStep, efYStep, efY2Min,
%               efY2Max, efY2Step
%   callbacks - Struct of function handles:
%                 .saveAxisLimsToActiveDataset()
%                 .onPlot(src, evt)

    if isempty(appData.datasets) || appData.activeIdx < 1, return; end

    % ── Collect visible X and Y data across all datasets ──────────
    allX = [];  allY = [];
    for si = 1:numel(appData.datasets)
        sds = appData.datasets{si};
        if isfield(sds,'visible') && ~sds.visible, continue; end
        sd = guiTernary(~isempty(sds.corrData), sds.corrData, sds.data);
        if isdatetime(sd.time), continue; end
        allX = [allX; double(sd.time(:))]; %#ok<AGROW>
        allY = [allY; sd.values(:)];       %#ok<AGROW>
    end
    if isempty(allX) || isempty(allY), return; end

    % Remove NaN/Inf for range analysis
    allX = allX(isfinite(allX));
    allY = allY(isfinite(allY));
    if isempty(allX) || isempty(allY), return; end

    % ── Decide log vs linear for each axis ───────────────────────
    % Log is appropriate when all values are positive and span >2
    % orders of magnitude (e.g. reflectivity 1e-6 to 1).
    xMin = min(allX);  xMax = max(allX);
    yMin = min(allY);  yMax = max(allY);

    useLogX = false;
    if xMin > 0 && xMax > 0 && xMax/xMin > 100
        useLogX = true;
    end
    useLogY = false;
    if yMin > 0 && yMax > 0 && yMax/yMin > 100
        useLogY = true;
    end

    if useLogX, ui.ddScaleX.Value = 'Log'; else, ui.ddScaleX.Value = 'Linear'; end
    if useLogY, ui.ddScaleY.Value = 'Log'; else, ui.ddScaleY.Value = 'Linear'; end

    % ── Set reasonable limits with margin ─────────────────────────
    if useLogX
        % Round to nearest decade with 0.5-decade margin
        ui.efXMin.Value = sprintf('%.6g', 10^floor(log10(xMin)));
        ui.efXMax.Value = sprintf('%.6g', 10^ceil(log10(xMax)));
    else
        xRange = xMax - xMin;
        if xRange == 0, xRange = max(abs(xMax), 1); end
        margin = xRange * 0.02;
        ui.efXMin.Value = sprintf('%.6g', xMin - margin);
        ui.efXMax.Value = sprintf('%.6g', xMax + margin);
    end

    if useLogY
        ui.efYMin.Value = sprintf('%.6g', 10^floor(log10(yMin)));
        ui.efYMax.Value = sprintf('%.6g', 10^ceil(log10(yMax)));
    else
        yRange = yMax - yMin;
        if yRange == 0, yRange = max(abs(yMax), 1); end
        margin = yRange * 0.05;
        ui.efYMin.Value = sprintf('%.6g', yMin - margin);
        ui.efYMax.Value = sprintf('%.6g', yMax + margin);
    end
    ui.efXStep.Value = '';
    ui.efYStep.Value = '';
    ui.efY2Min.Value = '';  ui.efY2Max.Value = '';  ui.efY2Step.Value = '';

    callbacks.saveAxisLimsToActiveDataset();
    callbacks.onPlot([],[]);
end

% ════════════════════════════════════════════════════════════════════════
% Local helper
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end
