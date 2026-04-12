function estimateBaseline(appData, fig, ddBaselineMethod, efBaselineLambda, efBaselineRadius, ...
        buildDsFn, rebuildDatasetListFn, onPlotFn, setStatusFn)
%ESTIMATEBASELINE  Open dialog for baseline estimation and apply to active dataset.
%
%   Syntax:
%     bosonPlotter.estimateBaseline(appData, fig, ddBaselineMethod, ...
%         efBaselineLambda, efBaselineRadius, buildDsFn, ...
%         rebuildDatasetListFn, onPlotFn, setStatusFn)
%
%   Inputs:
%     appData              - shared application state struct (handle)
%     fig                  - parent uifigure (for uialert)
%     ddBaselineMethod     - uidropdown widget handle (Value = method name)
%     efBaselineLambda     - uieditfield widget handle (Value = ALS lambda)
%     efBaselineRadius     - uieditfield widget handle (Value = rolling-ball radius)
%     buildDsFn            - function handle: @(fp, data, parserName) → ds
%     rebuildDatasetListFn - function handle: @(keepActiveIdx)
%     onPlotFn             - function handle: @() trigger re-plot
%     setStatusFn          - function handle: @(msg) update status bar
%
%   Description:
%     Dispatches to SNIP, ALS, Rolling Ball, or Mod. Polynomial baseline
%     estimation.  Subtracts the estimated baseline from all Y channels and
%     stores the result as corrected data.  Appends the raw baseline as a
%     separate dataset for visual comparison.

% ════════════════════════════════════════════════════════════════════════

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig, 'Load a file first.', 'No data'); return;
    end
    ds = appData.datasets{appData.activeIdx};
    d  = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
    if isdatetime(d.time)
        uialert(fig, 'Baseline estimation requires numeric x-axes.', 'Error'); return;
    end

    meth = ddBaselineMethod.Value;
    bgAll = zeros(size(d.values));
    statusMsg = '';

    switch meth
        case 'SNIP'
            % ── SNIP (peak-clipping) ──────────────────────────────────
            answer = inputdlg({'Max window (x-axis units):', 'Smooth passes:'}, ...
                'SNIP Baseline Estimation', [1 40], {'2.0', '3'});
            if isempty(answer), return; end
            maxWin  = str2double(answer{1});
            smoothP = round(str2double(answer{2}));
            if isnan(maxWin) || isnan(smoothP) || maxWin <= 0
                uialert(fig, 'Invalid parameters.', 'Error'); return;
            end
            xVec = double(d.time);
            for k = 1:size(d.values, 2)
                bgAll(:, k) = utilities.estimateBackground(xVec, d.values(:, k), ...
                    'MaxWindowDeg', maxWin, 'SmoothPasses', smoothP);
            end
            statusMsg = sprintf('Baseline subtracted (SNIP, window=%.1f).', maxWin);

        case 'ALS'
            % ── Asymmetric Least Squares ──────────────────────────────
            lambda = efBaselineLambda.Value;
            for k = 1:size(d.values, 2)
                bgAll(:, k) = utilities.baselineALS(d.values(:, k), 'Lambda', lambda);
            end
            statusMsg = sprintf('Baseline subtracted (ALS, lambda=%.3g).', lambda);

        case 'Rolling Ball'
            % ── Rolling Ball ──────────────────────────────────────────
            radius = round(efBaselineRadius.Value);
            for k = 1:size(d.values, 2)
                bgAll(:, k) = utilities.baselineRollingBall(d.values(:, k), 'Radius', radius);
            end
            statusMsg = sprintf('Baseline subtracted (Rolling Ball, radius=%d pts).', radius);

        case 'Mod. Polynomial'
            % ── Modified Polynomial (Lieber & Mahadevan-Jansen) ───────
            answer = inputdlg({'Polynomial order:', 'Max iterations:'}, ...
                'Mod. Polynomial Baseline', [1 40], {'5', '100'});
            if isempty(answer), return; end
            polyOrd  = round(str2double(answer{1}));
            maxIter  = round(str2double(answer{2}));
            if isnan(polyOrd) || isnan(maxIter) || polyOrd < 1
                uialert(fig, 'Invalid parameters.', 'Error'); return;
            end
            for k = 1:size(d.values, 2)
                bgAll(:, k) = utilities.baselineModPoly(d.values(:, k), ...
                    'Order', polyOrd, 'MaxIter', maxIter);
            end
            statusMsg = sprintf('Baseline subtracted (Mod. Poly, order=%d).', polyOrd);

        otherwise
            uialert(fig, sprintf('Unknown baseline method: %s', meth), 'Error');
            return;
    end

    % ── Subtract baseline and store as corrected data ─────────────────────
    if isempty(ds.corrData)
        ds.corrData = d;
    end
    ds.corrData.values = d.values - bgAll;
    appData.datasets{appData.activeIdx} = ds;

    % ── Add raw baseline as a separate dataset for visual comparison ──────
    bgData = d;
    bgData.values = bgAll;
    bgData.labels = cellfun(@(lbl) ['BG: ' lbl], d.labels, 'UniformOutput', false);
    dsNew = buildDsFn(ds.filepath, bgData, 'baseline');
    [~, fn, fext] = fileparts(ds.filepath);
    dsNew.displayName = [fn fext ' (baseline)'];
    dsNew.legendName  = [fn fext ' (baseline)'];
    appData.datasets{end+1} = dsNew;
    rebuildDatasetListFn(true);
    onPlotFn();
    setStatusFn(statusMsg);
end

% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end
