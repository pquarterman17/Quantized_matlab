function cb = peakCallbacks(ctx)
%PEAKCALLBACKS  Peak detection, fitting, and export callbacks.
%
%   Syntax
%     cb = bosonPlotter.peakCallbacks(ctx)
%
%   Inputs
%     ctx — struct bundling all closure state the callbacks need
%       .appData             shared application state (handle class or struct ref)
%       .fig                 uifigure handle
%       .ax                  main plot axes handle
%       .ddX                 X-axis dropdown
%       .lbY                 Y-channel listbox
%       .efXMin              X min edit field
%       .efXMax              X max edit field
%       .efMinSep            minimum separation edit field
%       .ddFitModel          fit model dropdown
%       .peakTable           peak table widget
%       .btnManualPeak       manual peak button
%       .btnRemovePeakClick  remove peak button
%       .onPlot              function handle — trigger replot
%       .showPeakWindow      function handle — show peak window
%       .cancelInteractions  function handle — cancel active interaction modes
%       .setStatus           function handle — status bar updates
%       .logGUIError         function handle — error logging
%       .getPlotData         function handle — retrieve plot data for a dataset index
%
%   Outputs
%     cb — struct of function handles:
%       .onAutoPeak, .onManualPeakAdd, .onManualPeakClick,
%       .onRemovePeakClickMode, .onRemovePeakClick,
%       .onFitPeaks, .onFitAllPeaks, .onShowDecomposition,
%       .onClearPeaks, .onRemoveSelectedPeak, .onPeakTableSelect,
%       .refreshPeakTable, .onSavePeakSummary, .onExportPeakXLSX
%
%   Examples
%     ctx.appData   = appData;
%     ctx.fig       = fig;
%     % ... fill remaining ctx fields ...
%     cb = bosonPlotter.peakCallbacks(ctx);
%     btnAutoPeak.ButtonPushedFcn = cb.onAutoPeak;

% ════════════════════════════════════════════════════════════════════════
% Return struct of callback function handles
% ════════════════════════════════════════════════════════════════════════

cb.onAutoPeak            = @onAutoPeak;
cb.onManualPeakAdd       = @onManualPeakAdd;
cb.onManualPeakClick     = @onManualPeakClick;
cb.onRemovePeakClickMode = @onRemovePeakClickMode;
cb.onRemovePeakClick     = @onRemovePeakClick;
cb.onFitPeaks            = @onFitPeaks;
cb.onFitAllPeaks         = @onFitAllPeaks;
cb.onShowDecomposition   = @onShowDecomposition;
cb.onClearPeaks          = @onClearPeaks;
cb.onRemoveSelectedPeak  = @onRemoveSelectedPeak;
cb.onPeakTableSelect     = @onPeakTableSelect;
cb.refreshPeakTable      = @refreshPeakTable;
cb.onSavePeakSummary     = @onSavePeakSummary;
cb.onExportPeakXLSX      = @onExportPeakXLSX;
cb.onKeyPress            = @onKeyPress;

% ════════════════════════════════════════════════════════════════════════
% Peak detection
% ════════════════════════════════════════════════════════════════════════

    function onAutoPeak(~,~)
    %ONAUTOPEAK  SNIP-based peak detection with manual seed preservation.
    %
    %  Uses utilities.findPeaksRobust for background-aware peak finding.
    %  Manual seeds from previous runs are preserved via Pass 2 re-detection.
    %  Output  — ds.peaks is REPLACED with deduplicated, centre-sorted result.
        if isempty(ctx.appData.datasets) || ctx.appData.activeIdx < 1
            uialert(ctx.fig,'Load a file first.','No data'); return;
        end
        ds = ctx.appData.datasets{ctx.appData.activeIdx};
        d  = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);

        % ── Resolve x / y vectors ─────────────────────────────────────────
        xSel  = ctx.ddX.Value;
        xName = guiXName(d.metadata);
        if strcmp(xSel, xName)
            xv = double(d.time);
        else
            idx2 = find(strcmp(d.labels, xSel), 1);
            xv   = guiTernary(isempty(idx2), double(d.time), d.values(:,idx2));
        end
        ySel = ensureCell(ctx.lbY.Value);
        yIdx = find(strcmp(d.labels, ySel{1}), 1);
        if isempty(yIdx)
            uialert(ctx.fig,'Could not find selected Y channel.','Auto Peaks'); return;
        end
        yv    = d.values(:, yIdx);
        dmask = buildDisplayMask(ds);
        valid = ~isnan(xv) & ~isnan(yv) & dmask;
        xv = xv(valid);  yv = yv(valid);
        if numel(xv) < 5
            uialert(ctx.fig,'Too few valid data points for peak detection.','Auto Peaks'); return;
        end

        % ── Restrict to visible x-range if limits are set ─────────────────
        xMinLim = str2double(ctx.efXMin.Value);
        xMaxLim = str2double(ctx.efXMax.Value);
        if ~isnan(xMinLim) && ~isnan(xMaxLim) && xMinLim < xMaxLim
            inView = xv >= xMinLim & xv <= xMaxLim;
            if sum(inView) >= 5
                xv = xv(inView);
                yv = yv(inView);
            end
        end

        xSpan = diff([min(xv), max(xv)]);

        PEAK_SEP_TOL_FRAC   = 0.005;  % seeds closer than this are merged
        PEAK_LOCAL_WIN_FRAC = 0.02;   % ±fraction of x-span for missed-seed search

        % ── User-configurable detection params (sidebar of Peak Workshop) ──
        userMinSep = ctx.efMinSep.Value;
        userSNR    = readSidebar(ctx, 'efNoise',      5);
        userProm   = readSidebar(ctx, 'efProminence', 0.02);

        % ── Save existing manual seeds BEFORE rebuilding the list ─────────
        if ~isempty(ds.peaks) && isfield(ds.peaks, 'status')
            isManual     = strcmp({ds.peaks.status}, 'manual');
            manualSeeds  = ds.peaks(isManual);
        else
            manualSeeds  = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
                                  'xRange',{},'status',{},'bg',{},'model',{},'eta',{}, ...
                                  'prominence',{},'localSNR',{});
        end

        % ── SNIP-based peak detection ───────────────────────────────────
        [merged, bgEst] = utilities.findPeaksRobust(xv(:), yv(:), ...
            'SNRThreshold',  userSNR, ...
            'MinProminence', userProm, ...
            'MinSeparation', guiTernary(userMinSep > 0, userMinSep, 0), ...
            'MaxPeaks',      50, ...
            'MaxWindowDeg',  2.0);

        % Store background estimate for overlay plotting
        ds.snipBackground = struct('x', xv(:), 'bg', bgEst(:));

        % ── Pass 2: force local search at missed manual seeds ────────────
        minSep  = xSpan * PEAK_SEP_TOL_FRAC;
        halfWin = xSpan * PEAK_LOCAL_WIN_FRAC;

        for si = 1:numel(manualSeeds)
            seedX = manualSeeds(si).center;
            if ~isempty(merged)
                if any(abs([merged.center] - seedX) <= minSep)
                    continue;
                end
            end

            inWin = xv >= (seedX - halfWin) & xv <= (seedX + halfWin);
            if ~any(inWin)
                merged(end+1) = manualSeeds(si);  %#ok<AGROW>
                continue;
            end
            xWin = xv(inWin);  yWin = yv(inWin);

            try
                [lH, lX, lW, ~] = findpeaks(yWin, xWin, 'SortStr', 'none');
                if isempty(lX)
                    [lH, mi] = max(yWin);  lX = xWin(mi);  lW = halfWin * 0.5;
                else
                    [~, ci] = min(abs(lX - seedX));
                    lH = lH(ci);  lX = lX(ci);  lW = lW(ci);
                end
            catch
                [lH, mi] = max(yWin);  lX = xWin(mi);  lW = halfWin * 0.5;
            end

            newPk.center     = lX;
            newPk.fwhm       = lW;
            newPk.height     = lH;
            newPk.area       = NaN;
            newPk.xRange     = [];
            newPk.status     = 'manual';
            newPk.bg         = NaN;
            newPk.model      = '';
            newPk.eta        = NaN;
            newPk.prominence = NaN;
            newPk.localSNR   = NaN;
            merged(end+1) = newPk;  %#ok<AGROW>
        end

        if isempty(merged)
            uialert(ctx.fig, ...
                ['No peaks found. ' ...
                 'Add manual seeds with the Add Peak button, or adjust ' ...
                 'axis limits to zoom in on the region of interest.'], ...
                'Auto Peaks');
            return;
        end

        % ── Deduplicate and sort by centre position ───────────────────────
        merged = deduplicatePeaks(merged, minSep);
        [~, ord] = sort([merged.center]);
        ds.peaks = merged(ord);

        ctx.appData.datasets{ctx.appData.activeIdx} = ds;
        refreshPeakTable();
        ctx.onPlot();
        ctx.showPeakWindow();
    end

% ════════════════════════════════════════════════════════════════════════
% Manual peak add (click mode)
% ════════════════════════════════════════════════════════════════════════

    function onManualPeakAdd(~,~)
    %ONMANUALPEAKADD  Toggle click-to-add-peak mode.
        if ctx.appData.peakPickMode
            % Already active — cancel
            ctx.cancelInteractions(); return;
        end
        if isempty(ctx.appData.datasets) || ctx.appData.activeIdx < 1
            uialert(ctx.fig,'Load a file first.','No data'); return;
        end
        ctx.cancelInteractions();
        ctx.appData.peakPickMode          = true;
        ctx.btnManualPeak.Text            = 'Done Adding (click again)';
        ctx.btnManualPeak.BackgroundColor = [0.65 0.10 0.65];
        ctx.fig.WindowButtonDownFcn       = @onManualPeakClick;
    end

    function onManualPeakClick(~,~)
    %ONMANUALPEAKCLICK  Record a click on the plot as a peak seed.
        cp     = ctx.ax.CurrentPoint;
        xClick = cp(1,1);  yClick = cp(1,2);
        if xClick < ctx.ax.XLim(1) || xClick > ctx.ax.XLim(2) || ...
           yClick < ctx.ax.YLim(1) || yClick > ctx.ax.YLim(2)
            return;
        end

        ds = ctx.appData.datasets{ctx.appData.activeIdx};
        d  = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);

        % Resolve x/y vectors (same logic as onAutoPeak)
        xSel  = ctx.ddX.Value;
        xName = guiXName(d.metadata);
        if strcmp(xSel, xName)
            xv = double(d.time);
        else
            idx2 = find(strcmp(d.labels, xSel), 1);
            xv   = guiTernary(isempty(idx2), double(d.time), d.values(:,idx2));
        end
        ySel = ensureCell(ctx.lbY.Value);
        yIdx = find(strcmp(d.labels, ySel{1}), 1);
        if isempty(yIdx), return; end
        yv = d.values(:, yIdx);
        dmask = buildDisplayMask(ds);

        % Search within 3 % of x-axis range of click for the NEAREST local
        % maximum (not the global max — which misses the smaller of two close peaks).
        xWin  = diff(ctx.ax.XLim) * 0.03;
        inWin = xv >= (xClick - xWin) & xv <= (xClick + xWin) & ~isnan(yv) & dmask;
        if any(inWin)
            xInWin = xv(inWin);
            yInWin = yv(inWin);
            % Find all local maxima in the window
            nW = numel(yInWin);
            if nW >= 3
                isLMax = false(nW,1);
                isLMax(2:end-1) = yInWin(2:end-1) > yInWin(1:end-2) & ...
                                  yInWin(2:end-1) > yInWin(3:end);
                if any(isLMax)
                    % Pick the local max nearest to the click x-position
                    lmX = xInWin(isLMax);
                    lmH = yInWin(isLMax);
                    [~, nearI] = min(abs(lmX - xClick));
                    pkX = lmX(nearI);
                    pkH = lmH(nearI);
                else
                    % No local max — fall back to nearest point
                    [~, nearI] = min(abs(xInWin - xClick));
                    pkX = xInWin(nearI);
                    pkH = yInWin(nearI);
                end
            else
                [~, nearI] = min(abs(xInWin - xClick));
                pkX = xInWin(nearI);
                pkH = yInWin(nearI);
            end
        else
            pkX = xClick;
            pkH = yClick;
        end

        newPk.center     = pkX;
        newPk.fwhm       = NaN;
        newPk.height     = pkH;
        newPk.area       = NaN;
        newPk.xRange     = [];
        newPk.status     = 'manual';
        newPk.bg         = NaN;
        newPk.model      = '';
        newPk.eta        = NaN;
        newPk.prominence = NaN;
        newPk.localSNR   = NaN;

        % ── Auto-fit on add: estimate local FWHM, then run a quick local
        %    fit so the user sees a result immediately. Failures are quiet
        %    here — peak stays as 'manual' and the user can press Fit Peaks
        %    later (which will surface a rich diagnostic dialog).
        xvAll = double(d.time);  yvAll = d.values(:, yIdx);
        validAll = ~isnan(xvAll) & ~isnan(yvAll) & dmask;
        xvSorted = xvAll(validAll);  yvSorted = yvAll(validAll);
        [xvSorted, sortIdx] = sort(xvSorted);
        yvSorted = yvSorted(sortIdx);
        if numel(xvSorted) >= 5
            xSpanAll = diff([min(xvSorted), max(xvSorted)]);
            fwhmEst  = estimateLocalFWHM(xvSorted, yvSorted, pkX, xSpanAll);
            seed = struct('center', pkX, 'fwhm', fwhmEst);
            if isfinite(fwhmEst)
                hw  = 3.0 * fwhmEst;
            else
                hw  = xSpanAll * 0.03;
            end
            xLo = pkX - hw;  xHi = pkX + hw;
            r = fitSinglePeak(xvSorted, yvSorted, xLo, xHi, seed, ctx.ddFitModel.Value, []);
            if r.success
                newPk.center = r.center;
                newPk.fwhm   = r.fwhm;
                newPk.height = r.height;
                newPk.bg     = r.bg;
                newPk.eta    = r.eta;
                newPk.area   = r.area;
                newPk.model  = r.model;
                newPk.status = 'fitted';
            elseif isfinite(fwhmEst)
                newPk.fwhm = fwhmEst;  % still useful as a seed for later Fit Peaks
            end
        end

        ds.peaks(end+1) = newPk;
        ctx.appData.datasets{ctx.appData.activeIdx} = ds;

        refreshPeakTable();
        ctx.onPlot();
        % Auto-open peak window on first peak
        if isscalar(ds.peaks), ctx.showPeakWindow(); end
        % Stay in pick mode — user presses button again to stop
    end

% ════════════════════════════════════════════════════════════════════════
% Remove peak (click mode)
% ════════════════════════════════════════════════════════════════════════

    function onRemovePeakClickMode(~,~)
    %ONREMOVEPEAKCLICKMODE  Toggle click-to-remove-peak mode.
        if ctx.appData.peakRemoveMode
            % Already active — cancel
            ctx.cancelInteractions(); return;
        end
        if isempty(ctx.appData.datasets) || ctx.appData.activeIdx < 1
            uialert(ctx.fig,'Load a file first.','No data'); return;
        end
        ds = ctx.appData.datasets{ctx.appData.activeIdx};
        if isempty(ds.peaks)
            uialert(ctx.fig,'No peaks to remove.','No peaks'); return;
        end
        ctx.cancelInteractions();
        ctx.appData.peakRemoveMode          = true;
        ctx.btnRemovePeakClick.Text            = 'Done Removing (click again)';
        ctx.btnRemovePeakClick.BackgroundColor = [0.80 0.10 0.10];
        ctx.fig.WindowButtonDownFcn            = @onRemovePeakClick;
    end

    function onRemovePeakClick(~,~)
    %ONREMOVEPEAKCLICK  Remove the peak whose centre is closest to the click.
        cp     = ctx.ax.CurrentPoint;
        xClick = cp(1,1);  yClick = cp(1,2);
        if xClick < ctx.ax.XLim(1) || xClick > ctx.ax.XLim(2) || ...
           yClick < ctx.ax.YLim(1) || yClick > ctx.ax.YLim(2)
            return;
        end

        ds = ctx.appData.datasets{ctx.appData.activeIdx};
        if isempty(ds.peaks), return; end

        % Find the peak whose centre is nearest to the click x-position.
        % Tolerance: 3 % of the visible x-axis width.
        centers = [ds.peaks.center];
        dists   = abs(centers - xClick);
        [minD, idx] = min(dists);
        tol = diff(ctx.ax.XLim) * 0.03;
        if minD > tol, return; end  % click is not near any peak — ignore

        ds.peaks(idx) = [];
        ctx.appData.datasets{ctx.appData.activeIdx} = ds;
        ctx.appData.selectedPeakIdx = 0;
        refreshPeakTable();
        ctx.onPlot();
        % Stay in remove mode — user presses button again to stop
    end

% ════════════════════════════════════════════════════════════════════════
% Peak fitter
% ════════════════════════════════════════════════════════════════════════

    function onFitPeaks(~,~)
    %ONFITPEAKS  Fit each entry in ds.peaks via fitSinglePeak, with retry pass.
    %  First pass: window from pk.xRange | ±3·FWHM | fallback ±3% of x-span.
    %  Second pass (failed peaks only): widen window 1.5× and subtract the
    %  SNIP background if available. Failures are collected with a reason
    %  per peak and presented in a rich diagnostic dialog plus translucent
    %  fit-window overlays on the main plot.
        if isempty(ctx.appData.datasets) || ctx.appData.activeIdx < 1
            uialert(ctx.fig,'Load a file first.','No data'); return;
        end
        ds = ctx.appData.datasets{ctx.appData.activeIdx};
        if isempty(ds.peaks)
            uialert(ctx.fig,'No peaks to fit.  Use Auto Find Peaks or Add Peak first.','No peaks'); return;
        end

        d    = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        xSel = ctx.ddX.Value;
        xName = guiXName(d.metadata);
        if strcmp(xSel, xName)
            xv = double(d.time);
        else
            idx2 = find(strcmp(d.labels, xSel), 1);
            xv   = guiTernary(isempty(idx2), double(d.time), d.values(:,idx2));
        end
        ySel = ensureCell(ctx.lbY.Value);
        yIdx = find(strcmp(d.labels, ySel{1}), 1);
        if isempty(yIdx), uialert(ctx.fig,'Could not find Y channel.','Fit Peaks'); return; end
        yv = d.values(:, yIdx);

        dmask = buildDisplayMask(ds);
        valid = ~isnan(xv) & ~isnan(yv) & dmask;
        xv = xv(valid);  yv = yv(valid);
        % Ensure monotone-increasing xv for fitSinglePeak
        [xv, sortIdx] = sort(xv);
        yv = yv(sortIdx);
        xSpan = diff([min(xv), max(xv)]);

        % Cached SNIP background aligned to xv (used in retry pass)
        snipBg = alignSnipBackground(ds, xv);

        % Clear any prior fit-window overlays before this run.
        clearFitWindowOverlays(ctx.ax);

        modelName = ctx.ddFitModel.Value;
        failures = struct('idx', {}, 'center', {}, 'reason', {}, ...
                          'suggestion', {}, 'window', {});

        for pki = 1:numel(ds.peaks)
            pk = ds.peaks(pki);

            % ── First-pass window ─────────────────────────────────────
            if ~isempty(pk.xRange) && numel(pk.xRange) == 2
                xLo = pk.xRange(1);  xHi = pk.xRange(2);
            elseif ~isnan(pk.fwhm) && pk.fwhm > 0
                hw   = 3.0 * pk.fwhm;
                xLo  = pk.center - hw;
                xHi  = pk.center + hw;
            else
                hw   = xSpan * 0.03;
                xLo  = pk.center - hw;
                xHi  = pk.center + hw;
            end

            seed = struct('center', pk.center, 'fwhm', pk.fwhm);
            r = fitSinglePeak(xv, yv, xLo, xHi, seed, modelName, []);

            % ── Retry pass: widen window 1.5× and subtract SNIP bg ──
            if ~r.success
                hw2  = 1.5 * (xHi - xLo) / 2;
                xLo2 = pk.center - hw2;
                xHi2 = pk.center + hw2;
                r2 = fitSinglePeak(xv, yv, xLo2, xHi2, seed, modelName, snipBg);
                if r2.success
                    r = r2;
                else
                    % Use whichever window we last tried for the failure overlay
                    r = r2;  % keeps reason from second attempt
                end
            end

            if r.success
                ds.peaks(pki).center = r.center;
                ds.peaks(pki).fwhm   = r.fwhm;
                ds.peaks(pki).height = r.height;
                ds.peaks(pki).bg     = r.bg;
                ds.peaks(pki).eta    = r.eta;
                ds.peaks(pki).area   = r.area;
                ds.peaks(pki).status = 'fitted';
                ds.peaks(pki).model  = r.model;
                if strcmp(r.model, 'Split Pearson VII')
                    ds.peaks(pki).asymmetry = abs(r.params(3)) / abs(r.params(4));
                    ds.peaks(pki).fitParams = r.params;
                elseif strcmp(r.model, 'TCH-pV')
                    ds.peaks(pki).fitParams = r.params;
                end
            else
                drawFitWindowOverlay(ctx.ax, r.window(1), r.window(2), sprintf('#%d', pki));
                failures(end+1) = struct(...
                    'idx',        pki, ...
                    'center',     pk.center, ...
                    'reason',     r.reason, ...
                    'suggestion', suggestNextStep(r.reason, modelName), ...
                    'window',     r.window); %#ok<AGROW>
            end
        end

        ctx.appData.datasets{ctx.appData.activeIdx} = ds;
        refreshPeakTable();
        ctx.onPlot();

        if ~isempty(failures)
            ctx.setStatus(sprintf('%d of %d peak(s) failed to fit — see dialog and red windows on plot.', ...
                numel(failures), numel(ds.peaks)));
            showFitFailuresDialog(ctx.fig, failures);
        else
            ctx.setStatus(sprintf('Fitted %d peak(s).', numel(ds.peaks)));
        end
    end

    function onFitAllPeaks(~,~)
    %ONFITALLPEAKS  Fit all listed peaks simultaneously as a single multi-peak model.
    %  Builds a composite model (sum of N Lorentzian or Gaussian peaks + a
    %  shared linear background) and optimises all parameters together with
    %  fminsearch.  Requires ≥ 2 peaks.
    %
    %  Parameter vector layout (nP peaks):
    %    p = [H1, x0_1, fwhm1, H2, x0_2, fwhm2, …, HnP, x0_nP, fwhmnP, m, b]
    %  where m, b are the shared linear background slope and intercept.
        if isempty(ctx.appData.datasets) || ctx.appData.activeIdx < 1
            uialert(ctx.fig,'Load a file first.','No data'); return;
        end
        ctx.setStatus('Fitting all peaks simultaneously...');
        ctx.fig.Pointer = 'watch';
        drawnow;
        ds = ctx.appData.datasets{ctx.appData.activeIdx};
        if numel(ds.peaks) < 2
            ctx.fig.Pointer = 'arrow';
            ctx.setStatus('Ready');
            uialert(ctx.fig, ...
                'Need at least 2 peaks for a global fit.  Use "Fit Peaks" for a single peak.', ...
                'Global Fit: need ≥2 peaks');
            return;
        end

        d    = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
        xSel = ctx.ddX.Value;
        xName = guiXName(d.metadata);
        if strcmp(xSel, xName)
            xv = double(d.time);
        else
            idx2 = find(strcmp(d.labels, xSel), 1);
            xv   = guiTernary(isempty(idx2), double(d.time), d.values(:,idx2));
        end
        ySel = ensureCell(ctx.lbY.Value);
        yIdx = find(strcmp(d.labels, ySel{1}), 1);
        if isempty(yIdx)
            uialert(ctx.fig,'Could not find Y channel.','Global Fit'); return;
        end
        yv = d.values(:, yIdx);

        dmask = buildDisplayMask(ds);
        valid = ~isnan(xv) & ~isnan(yv) & dmask;
        xv = xv(valid);  yv = yv(valid);
        nP = numel(ds.peaks);

        % Build composite model.
        % Lorentzian/Gaussian: [H1,x0_1,fwhm1, H2,..., HnP,x0_nP,fwhmNP, m, b]  (3 params/peak)
        % Pseudo-Voigt:        [H1,x0_1,fwhm1,eta1, ...,                  m, b]  (4 params/peak)
        isPVGlobal = strcmp(ctx.ddFitModel.Value,'Pseudo-Voigt');
        if isPVGlobal
            modelFun = @(p,x) evalMultiPeakPV(p, x, nP);
        else
            isGauss  = strcmp(ctx.ddFitModel.Value,'Gaussian');
            modelFun = @(p,x) evalMultiPeak(p, x, nP, isGauss);
        end

        % Build initial parameter vector from current peak seeds
        xSpan   = diff([min(xv), max(xv)]);
        bgEst   = min(yv);
        nPPeak  = guiTernary(isPVGlobal, 4, 3);
        p0      = zeros(1, nP*nPPeak + 2);
        for k = 1:nP
            pk    = ds.peaks(k);
            % pk.height is the absolute y-value; subtract background for model amplitude
            H0    = guiTernary(~isnan(pk.height) && pk.height > bgEst, pk.height - bgEst, max(yv) - bgEst);
            fwhm0 = guiTernary(~isnan(pk.fwhm)  && pk.fwhm  > 0, pk.fwhm,  xSpan * 0.02);
            p0((k-1)*nPPeak+1) = H0;
            p0((k-1)*nPPeak+2) = pk.center;
            p0((k-1)*nPPeak+3) = fwhm0;
            if isPVGlobal
                eta0 = guiTernary(isfield(pk,'eta') && ~isempty(pk.eta) && ~isnan(pk.eta), pk.eta, 0.5);
                p0((k-1)*nPPeak+4) = eta0;
            end
        end
        p0(end-1) = 0;       % shared linear BG slope
        p0(end)   = min(yv); % shared linear BG intercept

        % ── Build constrained objective function ─────────────────────────
        % Add a soft penalty when a peak center drifts more than 3 × its
        % initial FWHM from its seed position.  This prevents peaks from
        % swapping positions or collapsing onto each other during the
        % unconstrained fminsearch optimization.
        centerIdx = zeros(1, nP);
        centerBnd = zeros(1, nP);   % allowed half-window for each peak center
        for k = 1:nP
            centerIdx(k) = (k-1)*nPPeak + 2;
            fwInit       = abs(p0((k-1)*nPPeak + 3));
            centerBnd(k) = max(3 * fwInit, xSpan * 0.02);
        end
        seedCenters = p0(centerIdx);
        penaltyWt   = sum((yv - mean(yv)).^2) * 10;  % scale penalty to data magnitude

        objFun = @(p) sum((modelFun(p, xv) - yv).^2) + ...
            penaltyWt * sum(max(0, ((p(centerIdx) - seedCenters) ./ centerBnd).^2 - 1));

        opts   = optimset('Display','off','MaxIter',20000,'TolX',1e-10,'TolFun',1e-14);
        try
            pFit = fminsearch(objFun, p0, opts);
        catch
            uialert(ctx.fig,'Global fit optimisation failed.','Fit All Peaks');
            return;
        end

        % Extract fitted parameters and update ds.peaks
        mFit = pFit(end-1);  bFit = pFit(end);
        A_L  = pi / 2;
        A_G  = sqrt(pi) / (2 * sqrt(log(2)));
        for k = 1:nP
            Hk    = pFit((k-1)*nPPeak+1);
            x0k   = pFit((k-1)*nPPeak+2);
            fwhmk = abs(pFit((k-1)*nPPeak+3));
            etak  = guiTernary(isPVGlobal, max(0, min(1, pFit((k-1)*nPPeak+4))), NaN);
            if fwhmk > 0 && fwhmk < xSpan * 0.8
                ds.peaks(k).center = x0k;
                ds.peaks(k).fwhm   = fwhmk;
                ds.peaks(k).height = Hk;
                ds.peaks(k).bg     = mFit * x0k + bFit;
                ds.peaks(k).eta    = etak;
                ds.peaks(k).status = 'fitted(global)';
                ds.peaks(k).model  = ctx.ddFitModel.Value;
                switch ctx.ddFitModel.Value
                    case 'Gaussian'
                        ds.peaks(k).area = Hk * fwhmk * sqrt(pi / log(2)) / 2;
                    case 'Pseudo-Voigt'
                        ds.peaks(k).area = Hk * fwhmk * (etak * A_L + (1-etak) * A_G);
                    otherwise  % Lorentzian
                        ds.peaks(k).area = Hk * fwhmk * pi / 2;
                end
            end
        end

        ctx.appData.datasets{ctx.appData.activeIdx} = ds;
        refreshPeakTable();
        ctx.fig.Pointer = 'arrow';
        ctx.setStatus('Global peak fit complete.');
        ctx.onPlot();

        % Auto-show decomposition after global fit
        onShowDecomposition();
    end

% ════════════════════════════════════════════════════════════════════════
% Decomposition overlay
% ════════════════════════════════════════════════════════════════════════

    function onShowDecomposition(~, ~)
    %ONSHOWDECOMPOSITION  Overlay individual peak components on the main axes.
    %   Draws each fitted peak as a separate dashed curve plus the
    %   composite model and a linear background. Requires peaks with
    %   status 'fitted' or 'fitted(global)'.
        if isempty(ctx.appData.datasets) || ctx.appData.activeIdx < 1, return; end
        ds = ctx.appData.datasets{ctx.appData.activeIdx};
        if isempty(ds.peaks), return; end

        % Remove any previous decomposition overlays
        delete(findall(ctx.ax, 'Tag', 'GUIPeakDecomp'));

        % Gather fitted peaks
        nP = numel(ds.peaks);
        fittedIdx = [];
        for k = 1:nP
            if contains(ds.peaks(k).status, 'fitted')
                fittedIdx(end+1) = k; %#ok<AGROW>
            end
        end
        if isempty(fittedIdx)
            ctx.setStatus('No fitted peaks to decompose.');
            return;
        end

        % Get the plotted data range
        d = ctx.getPlotData(ctx.appData.activeIdx);
        xAll = d.time;
        xDense = linspace(min(xAll), max(xAll), 1000)';

        % Determine model
        modelName = 'Lorentzian';
        if isfield(ds.peaks(fittedIdx(1)), 'model') && ~isempty(ds.peaks(fittedIdx(1)).model)
            modelName = ds.peaks(fittedIdx(1)).model;
        end

        % Compute linear background from first and last peak bg values
        bgSlope = 0; bgInt = 0;
        if numel(fittedIdx) >= 2
            p1 = ds.peaks(fittedIdx(1));
            pN = ds.peaks(fittedIdx(end));
            if isfield(p1, 'bg') && isfield(pN, 'bg') && ~isnan(p1.bg) && ~isnan(pN.bg)
                bgSlope = (pN.bg - p1.bg) / max(eps, pN.center - p1.center);
                bgInt = p1.bg - bgSlope * p1.center;
            end
        elseif isfield(ds.peaks(fittedIdx(1)), 'bg')
            bgInt = ds.peaks(fittedIdx(1)).bg;
        end

        bgLine = bgSlope * xDense + bgInt;
        composite = bgLine;

        % Color palette for individual peaks
        nFitted = numel(fittedIdx);
        peakColors = lines(max(nFitted, 1));

        hold(ctx.ax, 'on');

        for fi = 1:nFitted
            pk = ds.peaks(fittedIdx(fi));
            H = pk.height;
            x0 = pk.center;
            fw = pk.fwhm;

            switch modelName
                case 'Gaussian'
                    yPk = H * exp(-4*log(2) * ((xDense - x0)./fw).^2);
                case 'Pseudo-Voigt'
                    eta = 0.5;
                    if isfield(pk, 'eta') && ~isnan(pk.eta), eta = pk.eta; end
                    L = H ./ (1 + 4*((xDense - x0)./fw).^2);
                    G = H * exp(-4*log(2) * ((xDense - x0)./fw).^2);
                    yPk = eta * L + (1 - eta) * G;
                otherwise  % Lorentzian
                    yPk = H ./ (1 + 4*((xDense - x0)./fw).^2);
            end

            composite = composite + yPk;

            % Draw individual peak (dashed, colored)
            plot(ctx.ax, xDense, yPk + bgSlope * xDense + bgInt, '--', ...
                'Color', [peakColors(fi,:) 0.6], ...
                'LineWidth', 1.0, ...
                'HandleVisibility', 'off', ...
                'Tag', 'GUIPeakDecomp');
        end

        % Draw composite (solid red)
        plot(ctx.ax, xDense, composite, '-', ...
            'Color', [0.85 0.15 0.15], ...
            'LineWidth', 1.5, ...
            'HandleVisibility', 'off', ...
            'Tag', 'GUIPeakDecomp');

        % Draw background (thin dotted gray)
        plot(ctx.ax, xDense, bgLine, ':', ...
            'Color', [0.5 0.5 0.5], ...
            'LineWidth', 0.8, ...
            'HandleVisibility', 'off', ...
            'Tag', 'GUIPeakDecomp');

        hold(ctx.ax, 'off');
        ctx.setStatus(sprintf('Decomposition: %d peaks + background overlaid', nFitted));
    end

% ════════════════════════════════════════════════════════════════════════
% Peak list management
% ════════════════════════════════════════════════════════════════════════

    function onClearPeaks(~,~)
        if isempty(ctx.appData.datasets) || ctx.appData.activeIdx < 1, return; end
        ctx.cancelInteractions();
        ds       = ctx.appData.datasets{ctx.appData.activeIdx};
        if ~isempty(ds.peaks)
            nFitted = sum(strcmp({ds.peaks.status},'fitted') | strcmp({ds.peaks.status},'fitted(global)'));
            if nFitted > 0
                sel = uiconfirm(ctx.fig, ...
                    sprintf('Remove all %d peaks (%d fitted)?', numel(ds.peaks), nFitted), ...
                    'Clear Peaks', 'Options', {'Clear', 'Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2);
                if ~strcmp(sel, 'Clear'), return; end
            end
        end
        ds.peaks = struct('center',{},'fwhm',{},'height',{},'area',{},'xRange',{},'status',{},'bg',{},'model',{},'eta',{},'prominence',{},'localSNR',{});
        ctx.appData.datasets{ctx.appData.activeIdx} = ds;
        ctx.appData.selectedPeakIdx = 0;
        refreshPeakTable();
        ctx.onPlot();
    end

    function onRemoveSelectedPeak(~,~)
        if isempty(ctx.appData.datasets) || ctx.appData.activeIdx < 1, return; end
        pki = ctx.appData.selectedPeakIdx;
        if pki < 1, return; end
        ctx.cancelInteractions();
        ds = ctx.appData.datasets{ctx.appData.activeIdx};
        if pki > numel(ds.peaks), return; end
        ds.peaks(pki) = [];
        ctx.appData.datasets{ctx.appData.activeIdx} = ds;
        ctx.appData.selectedPeakIdx = 0;
        refreshPeakTable();
        ctx.onPlot();
    end

    function onPeakTableSelect(~, evt)
    %ONPEAKTABLESELECT  Highlight the selected peak on the plot.
        if ~isempty(evt.Indices)
            ctx.appData.selectedPeakIdx = evt.Indices(1,1);
        else
            ctx.appData.selectedPeakIdx = 0;
        end
        ctx.onPlot();
    end

    function refreshPeakTable()
    %REFRESHPEAKTABLE  Sync peakTable.Data from the active dataset's ds.peaks.
    %   Columns: #, Center(°), d(Å), Size(nm), FWHM(°), Height, Area, η, Status
        if isempty(ctx.appData.datasets) || ctx.appData.activeIdx < 1
            ctx.peakTable.Data = {}; return;
        end
        ds  = ctx.appData.datasets{ctx.appData.activeIdx};
        n   = numel(ds.peaks);
        if n == 0
            ctx.peakTable.Data = {}; return;
        end
        wl_A      = extractWavelength_A(ds);   % NaN if no wavelength available
        K         = ctx.appData.kFactor;
        inst_rad  = ctx.appData.instBroadening_deg * (pi / 180);
        DEG2RAD   = pi / 180;
        tbl       = cell(n, 9);
        for pIdx = 1:n
            pk          = ds.peaks(pIdx);
            tbl{pIdx,1} = pIdx;
            tbl{pIdx,2} = sprintf('%.4f', pk.center);
            % d-spacing via Bragg: d = λ / (2·sin(θ)), θ = 2θ/2 in radians
            canCalc = ~isnan(wl_A) && ~isnan(pk.center) && pk.center > 0;
            if canCalc
                theta_rad   = (pk.center / 2) * DEG2RAD;
                d_A         = wl_A / (2 * sin(theta_rad));
                tbl{pIdx,3} = sprintf('%.4f', d_A);
            else
                tbl{pIdx,3} = '—';
            end
            % Scherrer size: D = Kλ / (β·cosθ), β corrected for instrument broadening
            hasFWHM = ~isnan(pk.fwhm) && pk.fwhm > 0;
            if canCalc && hasFWHM
                beta_meas = pk.fwhm * DEG2RAD;
                beta_sq   = beta_meas^2 - inst_rad^2;
                if beta_sq > 0
                    beta_corr   = sqrt(beta_sq);
                    size_nm     = (K * wl_A * 0.1) / (beta_corr * cos(theta_rad));
                    tbl{pIdx,4} = sprintf('%.1f', size_nm);
                else
                    tbl{pIdx,4} = '—';   % inst broadening >= measured (unphysical)
                end
            else
                tbl{pIdx,4} = '—';
            end
            tbl{pIdx,5} = guiTernary(~hasFWHM, '—', sprintf('%.4f', pk.fwhm));
            tbl{pIdx,6} = sprintf('%.4g',  pk.height);
            tbl{pIdx,7} = guiTernary(isnan(pk.area) || pk.area <= 0, '—', sprintf('%.4g', pk.area));
            hasEta      = isfield(pk,'eta') && ~isempty(pk.eta) && ~isnan(pk.eta);
            tbl{pIdx,8} = guiTernary(hasEta, sprintf('%.2f', pk.eta), '—');
            tbl{pIdx,9} = pk.status;
        end
        ctx.peakTable.Data = tbl;
    end

% ════════════════════════════════════════════════════════════════════════
% Peak summary export
% ════════════════════════════════════════════════════════════════════════

    function onSavePeakSummary(~,~)
    %ONSAVEPEAKSUMMARY  Write peak centers and FWHM values to a CSV file.
        if isempty(ctx.appData.datasets) || ctx.appData.activeIdx < 1
            uialert(ctx.fig,'Load a file first.','No data'); return;
        end
        ds = ctx.appData.datasets{ctx.appData.activeIdx};
        if isempty(ds.peaks)
            uialert(ctx.fig,'No peaks to export.  Find or add peaks first.','No peaks'); return;
        end

        [~, fn, ~] = fileparts(ds.filepath);
        defPath    = fullfile(fileparts(ds.filepath), [fn, '_peaks.csv']);
        [fname, fpath] = uiputfile({'*.csv','CSV files (*.csv)'}, ...
            'Save peak summary as...', defPath);
        if isequal(fname,0), return; end

        fp  = fullfile(fpath, fname);
        fid = -1;
        try
            fid = fopen(fp, 'w');
            if fid < 0, error('Cannot open file for writing: %s', fp); end
            fprintf(fid, 'Peak,Center_deg,d_Angstrom,Size_nm,FWHM_deg,Height,Area,Status\n');
            wl_A      = extractWavelength_A(ds);
            K         = ctx.appData.kFactor;
            inst_rad  = ctx.appData.instBroadening_deg * (pi / 180);
            DEG2RAD   = pi / 180;
            for pki = 1:numel(ds.peaks)
                pk      = ds.peaks(pki);
                fwhmStr = guiTernary(isnan(pk.fwhm) || pk.fwhm <= 0, '', sprintf('%.6f', pk.fwhm));
                areaStr = guiTernary(isnan(pk.area) || pk.area <= 0, '', sprintf('%.6g', pk.area));
                canCalc = ~isnan(wl_A) && ~isnan(pk.center) && pk.center > 0;
                if canCalc
                    theta_rad = (pk.center / 2) * DEG2RAD;
                    dStr      = sprintf('%.6f', wl_A / (2 * sin(theta_rad)));
                else
                    dStr = '';
                end
                if canCalc && ~isnan(pk.fwhm) && pk.fwhm > 0
                    beta_sq = (pk.fwhm * DEG2RAD)^2 - inst_rad^2;
                    if beta_sq > 0
                        sizeStr = sprintf('%.2f', (K * wl_A * 0.1) / (sqrt(beta_sq) * cos(theta_rad)));
                    else
                        sizeStr = '';
                    end
                else
                    sizeStr = '';
                end
                fprintf(fid, '%d,%.6f,%s,%s,%s,%.6g,%s,%s\n', ...
                    pki, pk.center, dStr, sizeStr, fwhmStr, pk.height, areaStr, pk.status);
            end
            fclose(fid);
            uialert(ctx.fig, sprintf('Saved:\n%s', fp), 'Peak Summary Exported');
        catch ME
            if fid >= 0, fclose(fid); end
            ctx.logGUIError('Save error', ME.message, ME);
            uialert(ctx.fig, ME.message, 'Save error');
        end
    end

    function onExportPeakXLSX(~,~)
    %ONEXPORTPEAKXLSX  Export peak data from all datasets with peaks to Excel.
    %  One sheet per dataset; columns: Peak#, Center, FWHM, Height, Area, Status.
    %  Datasets with no peaks are silently skipped.
        if isempty(ctx.appData.datasets)
            uialert(ctx.fig,'Load files first.','No data'); return;
        end

        % Check that at least one dataset has peaks
        hasPeaks = false;
        for chk = 1:numel(ctx.appData.datasets)
            if ~isempty(ctx.appData.datasets{chk}.peaks)
                hasPeaks = true;  break;
            end
        end
        if ~hasPeaks
            uialert(ctx.fig, ...
                'No peaks found in any dataset.  Find or add peaks first.', ...
                'No peaks to export');
            return;
        end

        % Suggest save path based on first dataset
        ds1 = ctx.appData.datasets{1};
        [dPath, dName, ~] = fileparts(ds1.filepath);
        defPath = fullfile(dPath, [dName, '_peaks.xlsx']);

        [fname, fpath] = uiputfile({'*.xlsx','Excel Workbook (*.xlsx)'}, ...
            'Export peaks to Excel...', defPath);
        if isequal(fname, 0), return; end
        outPath = fullfile(fpath, fname);

        % Delete existing file so writecell starts fresh
        if isfile(outPath)
            try
                delete(outPath);
            catch
            end
        end

        nWritten = 0;
        errMsgs  = {};
        for di = 1:numel(ctx.appData.datasets)
            ds = ctx.appData.datasets{di};
            if isempty(ds.peaks), continue; end

            % Build sheet name from display name (Excel limits: 31 chars, no special chars)
            if isfield(ds,'legendName') && ~isempty(ds.legendName)
                rawName = ds.legendName;
            elseif isfield(ds,'displayName') && ~isempty(ds.displayName)
                rawName = ds.displayName;
            else
                [~, fn, ~] = fileparts(ds.filepath);
                rawName = fn;
            end
            % Sanitise: remove Excel-illegal characters, truncate to 31 chars
            sheetName = regexprep(rawName, '[:\\/?*\[\]]', '_');
            if numel(sheetName) > 28
                sheetName = [sheetName(1:25), sprintf('_%02d', di)];
            end
            if isempty(strtrim(sheetName))
                sheetName = sprintf('DS_%02d', di);
            end

            % Build cell array: header + data rows
            nPk      = numel(ds.peaks);
            wl_A     = extractWavelength_A(ds);
            K        = ctx.appData.kFactor;
            inst_rad = ctx.appData.instBroadening_deg * (pi / 180);
            DEG2RAD  = pi / 180;
            C   = cell(nPk + 1, 8);
            C(1,:) = {'Peak #', 'Center (deg)', 'd (A)', 'Size (nm)', 'FWHM (deg)', 'Height', 'Area', 'Status'};
            for pki = 1:nPk
                pk        = ds.peaks(pki);
                C{pki+1,1} = pki;
                C{pki+1,2} = pk.center;
                canCalc   = ~isnan(wl_A) && ~isnan(pk.center) && pk.center > 0;
                if canCalc
                    theta_rad  = (pk.center / 2) * DEG2RAD;
                    C{pki+1,3}  = wl_A / (2 * sin(theta_rad));
                else
                    C{pki+1,3} = '';
                end
                if canCalc && ~isnan(pk.fwhm) && pk.fwhm > 0
                    beta_sq = (pk.fwhm * DEG2RAD)^2 - inst_rad^2;
                    C{pki+1,4} = guiTernary(beta_sq > 0, ...
                        (K * wl_A * 0.1) / (sqrt(max(beta_sq,0)) * cos(theta_rad)), '');
                else
                    C{pki+1,4} = '';
                end
                C{pki+1,5} = guiTernary(isnan(pk.fwhm) || pk.fwhm <= 0, '', pk.fwhm);
                C{pki+1,6} = pk.height;
                C{pki+1,7} = guiTernary(isnan(pk.area) || pk.area <= 0, '', pk.area);
                C{pki+1,8} = pk.status;
            end

            try
                writecell(C, outPath, 'Sheet', sheetName);
                nWritten = nWritten + 1;
            catch ME
                errMsgs{end+1} = sprintf('%s: %s', sheetName, ME.message); %#ok<AGROW>
            end
        end

        if nWritten == 0
            uialert(ctx.fig, 'No peak data was written — check file permissions.', ...
                'Export Failed');
        elseif isempty(errMsgs)
            uialert(ctx.fig, sprintf('Exported %d dataset(s) to:\n%s', nWritten, outPath), ...
                'Peak Export Complete');
        else
            uialert(ctx.fig, sprintf('Exported %d dataset(s); %d error(s):\n%s', ...
                nWritten, numel(errMsgs), strjoin(errMsgs,'\n')), ...
                'Peak Export Partial');
        end
    end

    function onKeyPress(~, evt)
    %ONKEYPRESS  Keyboard shortcuts in the Peak Analysis window.
    %  Up/Down   — navigate peak table rows
    %  Return    — fit selected peak
    %  Delete    — remove selected peak
        nRows = size(ctx.peakTable.Data, 1);
        if nRows == 0, return; end
        curRow = ctx.appData.selectedPeakIdx;

        switch evt.Key
            case 'uparrow'
                newRow = max(1, curRow - 1);
                ctx.appData.selectedPeakIdx = newRow;
                ctx.peakTable.Selection = newRow;
                ctx.onPlot();
            case 'downarrow'
                newRow = min(nRows, curRow + 1);
                if curRow == 0, newRow = 1; end
                ctx.appData.selectedPeakIdx = newRow;
                ctx.peakTable.Selection = newRow;
                ctx.onPlot();
            case 'return'
                if curRow > 0
                    onFitPeaks([], []);
                end
            case 'delete'
                if curRow > 0
                    onRemoveSelectedPeak([], []);
                end
        end
    end

end  % peakCallbacks

% ════════════════════════════════════════════════════════════════════════
% Local helper functions
% ════════════════════════════════════════════════════════════════════════

function s = guiTernary(cond, a, b)
    if cond, s = a; else, s = b; end
end

function c = ensureCell(v)
    if ~iscell(v), c = {v}; else, c = v; end
end

function name = guiXName(meta)
    if isfield(meta, 'x_column_name') && ~isempty(meta.x_column_name)
        name = meta.x_column_name;
    else
        name = 'Time';
    end
end

function wl_A = extractWavelength_A(ds)
    % Check dataset-level override first
    if isfield(ds, 'wavelengthOverride_A') && ~isnan(ds.wavelengthOverride_A)
        wl_A = ds.wavelengthOverride_A; return;
    end
    % Then check parser metadata
    wl_A = NaN;
    d = ds.data;
    if isfield(d.metadata, 'parserSpecific')
        ps = d.metadata.parserSpecific;
        if isfield(ps, 'wavelength_A') && ~isnan(ps.wavelength_A)
            wl_A = ps.wavelength_A;
        elseif isfield(ps, 'wavelength_nm') && ~isnan(ps.wavelength_nm)
            wl_A = ps.wavelength_nm * 10;
        end
    end
end

function merged = deduplicatePeaks(peaks, minSep)
    if numel(peaks) <= 1, merged = peaks; return; end
    centers = [peaks.center];
    heights = [peaks.height];
    keep    = true(1, numel(peaks));
    for i = 1:numel(peaks)
        if ~keep(i), continue; end
        for j = (i+1):numel(peaks)
            if ~keep(j), continue; end
            if abs(centers(i) - centers(j)) < minSep
                iWins = heights(i) > heights(j) || ...
                        (heights(i) == heights(j) && strcmp(peaks(i).status,'auto'));
                if iWins
                    keep(j) = false;
                else
                    keep(i) = false;
                    break;
                end
            end
        end
    end
    merged = peaks(keep);
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

function y = evalMultiPeak(p, x, nP, isGauss)
    m = p(end-1); b = p(end);
    y = m*x + b;
    for k = 1:nP
        H = p((k-1)*3+1); x0 = p((k-1)*3+2); fw = abs(p((k-1)*3+3));
        if isGauss
            y = y + H * exp(-4*log(2)*((x-x0)/fw).^2);
        else
            y = y + H ./ (1 + 4*((x-x0)/fw).^2);
        end
    end
end

function y = evalMultiPeakPV(p, x, nP)
    m = p(end-1); b = p(end);
    y = m*x + b;
    for k = 1:nP
        H   = p((k-1)*4+1);
        x0  = p((k-1)*4+2);
        fw  = abs(p((k-1)*4+3));
        eta = max(0, min(1, p((k-1)*4+4)));
        L   = H ./ (1 + 4*((x-x0)/fw).^2);
        G   = H .* exp(-4*log(2)*((x-x0)/fw).^2);
        y   = y + eta*L + (1-eta)*G;
    end
end

function v = readSidebar(ctx, fld, defaultVal)
%READSIDEBAR  Pull a numeric value from a Peak Workshop sidebar widget.
%   Returns defaultVal if the widget is missing, invalid, or non-finite.
%   Used for back-compat: older callers may have built peakCtx_ before
%   efNoise / efProminence existed.
    if ~isfield(ctx, fld) || isempty(ctx.(fld)) || ~isvalid(ctx.(fld))
        v = defaultVal; return;
    end
    v = ctx.(fld).Value;
    if isempty(v) || ~isfinite(v) || v < 0
        v = defaultVal;
    end
end

function bg = alignSnipBackground(ds, xv)
%ALIGNSNIPBACKGROUND  Interpolate ds.snipBackground onto xv. Returns [] if absent.
    bg = [];
    if ~isfield(ds, 'snipBackground') || isempty(ds.snipBackground), return; end
    sb = ds.snipBackground;
    if ~isfield(sb, 'x') || ~isfield(sb, 'bg') || isempty(sb.x) || isempty(sb.bg)
        return;
    end
    try
        bg = interp1(double(sb.x), double(sb.bg), xv, 'linear', NaN);
        if all(isnan(bg)), bg = []; end
    catch
        bg = [];
    end
end

function fwhm = estimateLocalFWHM(xv, yv, xCenter, xSpan)
%ESTIMATELOCALFWHM  Walk left+right from xCenter to find half-max points.
%   Returns NaN if either side cannot bracket half-max within ~5% of x-span.
%   xv must be monotone-increasing.
    fwhm = NaN;
    if numel(xv) < 5, return; end
    [~, ic] = min(abs(xv - xCenter));
    if ic <= 1 || ic >= numel(xv), return; end

    yPeak = yv(ic);
    % Local baseline: min y in ±5% of x-span around the click.
    bandHW = max(xSpan * 0.05, 5 * (xv(min(end,ic+1)) - xv(max(1,ic-1))) / 2);
    bandMask = xv >= (xCenter - bandHW) & xv <= (xCenter + bandHW);
    if ~any(bandMask), return; end
    yBase = min(yv(bandMask));
    halfMax = yBase + 0.5 * (yPeak - yBase);
    if ~isfinite(halfMax) || halfMax >= yPeak, return; end

    % Walk left until y dips below halfMax.
    iL = ic;
    while iL > 1 && yv(iL) >= halfMax
        iL = iL - 1;
    end
    if iL == 1 && yv(iL) >= halfMax, return; end
    xL = interpHalfMax(xv(iL), xv(iL+1), yv(iL), yv(iL+1), halfMax);

    % Walk right until y dips below halfMax.
    iR = ic;
    while iR < numel(xv) && yv(iR) >= halfMax
        iR = iR + 1;
    end
    if iR == numel(xv) && yv(iR) >= halfMax, return; end
    xR = interpHalfMax(xv(iR-1), xv(iR), yv(iR-1), yv(iR), halfMax);

    fwhm = xR - xL;
    % Sanity: reject implausibly wide estimates (> 20% of x-span).
    if fwhm <= 0 || fwhm > xSpan * 0.20
        fwhm = NaN;
    end
end

function x = interpHalfMax(x1, x2, y1, y2, yT)
    if y1 == y2
        x = (x1 + x2) / 2;
    else
        x = x1 + (yT - y1) * (x2 - x1) / (y2 - y1);
    end
end

function r = fitSinglePeak(xv, yv, xLo, xHi, pkSeed, modelName, snipBg)
%FITSINGLEPEAK  Fit one peak in [xLo, xHi] to modelName; return result struct.
%
%   Inputs
%     xv, yv     full active data (monotone xv)
%     xLo, xHi   fit window (x-range)
%     pkSeed     struct with .center .fwhm (NaN ok) used as initial guess
%     modelName  one of {'Lorentzian','Gaussian','Pseudo-Voigt',
%                        'Split Pearson VII','TCH-pV'}
%     snipBg     [] or vector aligned with xv — subtracted before fit if given
%
%   Output struct r:
%     r.success  logical
%     r.reason   char  '', or one of:
%                'too-few-points', 'window-too-narrow',
%                'center-drift', 'fwhm-too-wide',
%                'fminsearch-error'
%     r.center, r.fwhm, r.height, r.bg, r.eta, r.area, r.params, r.model
%     r.window   [xLo xHi] used for the fit (post-expansion if any)

    r = struct('success', false, 'reason', '', ...
               'center', NaN, 'fwhm', NaN, 'height', NaN, 'bg', NaN, ...
               'eta', NaN, 'area', NaN, 'params', [], 'model', modelName, ...
               'window', [xLo xHi]);

    if numel(xv) < 5
        r.reason = 'too-few-points'; return;
    end
    xSpan = diff([min(xv), max(xv)]);

    % Optional background subtraction (NaN-safe: skip at NaN positions)
    yWork = yv;
    if ~isempty(snipBg) && numel(snipBg) == numel(yv)
        ok = isfinite(snipBg);
        yWork(ok) = yv(ok) - snipBg(ok);
    end

    inWin = xv >= xLo & xv <= xHi;
    if sum(inWin) < 4
        r.reason = 'window-too-narrow'; return;
    end
    xFit = xv(inWin);  yFit = yWork(inWin);

    isPV    = strcmp(modelName, 'Pseudo-Voigt');
    isSPVII = strcmp(modelName, 'Split Pearson VII');
    isTCH   = strcmp(modelName, 'TCH-pV');
    switch modelName
        case 'Gaussian'
            modelFun = @(p,x) p(1) .* exp(-4.*log(2).*((x-p(2))./p(3)).^2) + p(4);
        case 'Pseudo-Voigt'
            modelFun = @(p,x) p(1) .* (p(5) ./ (1 + 4.*((x-p(2))./p(3)).^2) + ...
                              (1-p(5)) .* exp(-4.*log(2).*((x-p(2))./p(3)).^2)) + p(4);
        case 'Split Pearson VII'
            modelFun = @(p,x) utilities.splitPearsonVII(x, p);
        case 'TCH-pV'
            modelFun = @(p,x) utilities.tchPseudoVoigt(x(:), p(:)');
        otherwise
            modelFun = @(p,x) p(1) ./ (1 + 4.*((x - p(2))./p(3)).^2) + p(4);
    end
    opts = optimset('Display','off','MaxIter',8000,'TolX',1e-10,'TolFun',1e-14);

    % Initial guesses
    bg0  = min(yFit);
    x0_0 = pkSeed.center;
    H0   = interp1(xFit, yFit, x0_0, 'linear', max(yFit)) - bg0;
    if H0 <= 0, H0 = max(yFit) - bg0; end
    if ~isnan(pkSeed.fwhm) && pkSeed.fwhm > 0
        fw0 = pkSeed.fwhm;
    else
        dx  = (xFit(end) - xFit(1)) / max(1, numel(xFit) - 1);
        fw0 = max((xHi - xLo) * 0.3, dx * 2);
    end

    if isSPVII
        hw0 = fw0 / 2;
        p0 = [H0, x0_0, hw0, hw0, 1.5, 1.5, bg0];
    elseif isTCH
        fw_seed = fw0 / sqrt(2);
        p0 = [H0, x0_0, fw_seed, fw_seed, bg0];
    else
        p0 = [H0, x0_0, fw0, bg0];
        if isPV, p0(end+1) = 0.5; end %#ok<AGROW>
    end

    objFun = @(p) sum((modelFun(p, xFit) - yFit).^2);
    try
        pFit = fminsearch(objFun, p0, opts);
    catch
        r.reason = 'fminsearch-error'; return;
    end

    if isSPVII
        fwhmFit = abs(pFit(3)) + abs(pFit(4));
        etaFit  = NaN;
        bgFit   = pFit(7);
    elseif isTCH
        fG = abs(pFit(3));  fL = abs(pFit(4));
        f5 = fG^5 + 2.69269*fG^4*fL + 2.42843*fG^3*fL^2 ...
           + 4.47163*fG^2*fL^3 + 0.07842*fG*fL^4 + fL^5;
        fwhmFit = f5^(1/5);
        if fwhmFit > 0
            rR     = fL / fwhmFit;
            etaFit = max(0, min(1, 1.36603*rR - 0.47719*rR^2 + 0.11116*rR^3));
        else
            etaFit = NaN;
        end
        bgFit = pFit(5);
    else
        fwhmFit = abs(pFit(3));
        if isPV
            etaFit = max(0, min(1, pFit(5)));
        else
            etaFit = NaN;
        end
        bgFit = pFit(4);
    end

    if pFit(2) < xLo || pFit(2) > xHi
        r.reason = 'center-drift'; return;
    end
    if ~(fwhmFit > 0 && fwhmFit < xSpan * 0.5)
        r.reason = 'fwhm-too-wide'; return;
    end

    % Compute area
    switch modelName
        case 'Gaussian'
            fittedArea = pFit(1) * fwhmFit * sqrt(pi / log(2)) / 2;
        case 'Pseudo-Voigt'
            A_L = pi / 2;
            A_G = sqrt(pi) / (2 * sqrt(log(2)));
            fittedArea = pFit(1) * fwhmFit * (etaFit * A_L + (1-etaFit) * A_G);
        case 'Split Pearson VII'
            xDense = linspace(xLo, xHi, 500)';
            yDense = utilities.splitPearsonVII(xDense, pFit) - pFit(7);
            fittedArea = trapz(xDense, yDense);
        case 'TCH-pV'
            A_L = pi / 2;
            A_G = sqrt(pi) / (2 * sqrt(log(2)));
            fittedArea = pFit(1) * fwhmFit * (etaFit * A_L + (1-etaFit) * A_G);
        otherwise
            fittedArea = pFit(1) * fwhmFit * pi / 2;
    end

    r.success = true;
    r.center  = pFit(2);
    r.fwhm    = fwhmFit;
    r.height  = pFit(1);
    r.bg      = bgFit;
    r.eta     = etaFit;
    r.area    = fittedArea;
    r.params  = pFit;
end

function suggestion = suggestNextStep(reason, modelName)
%SUGGESTNEXTSTEP  One-line actionable hint based on a fit-failure reason.
    switch reason
        case 'window-too-narrow'
            suggestion = 'window covered too few points — widen via right-click on the peak row, or zoom out before clicking Add Peak';
        case 'center-drift'
            suggestion = 'fit centre wandered out of the window — peak overlap likely; try Fit All (global) or Add Peak closer to the maximum';
        case 'fwhm-too-wide'
            if strcmpi(modelName, 'Lorentzian')
                suggestion = 'shape diverged — try Gaussian or Pseudo-Voigt, or subtract background first (auto-detect once)';
            else
                suggestion = 'shape diverged — subtract background first (run auto-detect once) or pick a tighter manual seed';
            end
        case 'fminsearch-error'
            suggestion = 'optimiser threw — usually NaN/inf in the data window; check for masked rows';
        case 'too-few-points'
            suggestion = 'not enough data points in scan — check x-range filter';
        otherwise
            suggestion = 'try a different fit model';
    end
end

function clearFitWindowOverlays(ax)
%CLEARFITWINDOWOVERLAYS  Delete all rectangles tagged 'peakFitWindow'.
    if ~isvalid(ax), return; end
    overlays = findobj(ax, 'Tag', 'peakFitWindow');
    if ~isempty(overlays), delete(overlays); end
end

function drawFitWindowOverlay(ax, xLo, xHi, label)
%DRAWFITWINDOWOVERLAY  Paint a translucent rect spanning [xLo, xHi] on ax.
%   Tagged 'peakFitWindow' so onClearOverlays / next fit can sweep it.
    if ~isvalid(ax) || ~isfinite(xLo) || ~isfinite(xHi) || xHi <= xLo
        return;
    end
    yLim = ax.YLim;
    h = patch(ax, ...
        'XData', [xLo xHi xHi xLo], ...
        'YData', [yLim(1) yLim(1) yLim(2) yLim(2)], ...
        'FaceColor', [0.85 0.20 0.20], ...
        'FaceAlpha', 0.10, ...
        'EdgeColor', [0.85 0.20 0.20], ...
        'EdgeAlpha', 0.55, ...
        'LineStyle', '--', ...
        'LineWidth', 1.0, ...
        'HitTest',  'off', ...
        'PickableParts', 'none', ...
        'Tag', 'peakFitWindow');
    h.HandleVisibility = 'off';
    if nargin >= 4 && ~isempty(label)
        text(ax, (xLo + xHi) / 2, yLim(2), label, ...
            'VerticalAlignment','top', 'HorizontalAlignment','center', ...
            'Color',[0.85 0.20 0.20], 'FontSize', 9, 'FontWeight','bold', ...
            'Tag','peakFitWindow', 'HitTest','off', 'PickableParts','none', ...
            'HandleVisibility','off');
    end
end

function showFitFailuresDialog(parentFig, failures)
%SHOWFITFAILURESDIALOG  Rich dialog listing failed peaks + actionable hints.
%   failures: struct array with .idx .center .reason .suggestion .window
    if isempty(failures), return; end
    nF = numel(failures);

    dlg = uifigure('Name', sprintf('Fit Issues (%d peak%s)', nF, plural(nF)), ...
        'Position', [300 250 540 min(420, 110 + 64*nF)], ...
        'Resize', 'off');
    rootGL = uigridlayout(dlg, [3 1], ...
        'RowHeight', {26, '1x', 32}, ...
        'Padding', [12 10 12 10], 'RowSpacing', 6);

    uilabel(rootGL, ...
        'Text', sprintf('%d peak%s could not be fitted. Suggested fixes below:', nF, plural(nF)), ...
        'FontWeight', 'bold');

    % Scrollable list of per-peak details
    scrollPanel = uipanel(rootGL, 'BorderType', 'none', 'Scrollable', 'on');
    listGL = uigridlayout(scrollPanel, [nF 1], ...
        'RowHeight', repmat({'fit'}, 1, nF), ...
        'Padding', [0 0 4 0], 'RowSpacing', 4);

    for k = 1:nF
        f = failures(k);
        msg = sprintf(['<html><b>Peak #%d</b> (centre %.3f) — <i>%s</i><br>' ...
                       '&nbsp;&nbsp;%s</html>'], ...
            f.idx, f.center, prettyReason(f.reason), f.suggestion);
        uilabel(listGL, 'Text', msg, ...
            'Interpreter', 'html', ...
            'WordWrap', 'on', ...
            'FontSize', 11);
    end

    btnRow = uigridlayout(rootGL, [1 2], ...
        'ColumnWidth', {'1x', 110}, ...
        'Padding', [0 0 0 0]);
    uilabel(btnRow, 'Text', '');
    btnOK = uibutton(btnRow, 'Text', 'OK', ...
        'ButtonPushedFcn', @(~,~) delete(dlg));
    btnOK.Layout.Column = 2;

    if ~isempty(parentFig) && isvalid(parentFig) && ~strcmpi(parentFig.Visible, 'off')
        figure(dlg);
    end
end

function s = plural(n), if n == 1, s = ''; else, s = 's'; end, end

function s = prettyReason(reason)
    switch reason
        case 'window-too-narrow', s = 'fit window too narrow';
        case 'center-drift',       s = 'centre drifted out of window';
        case 'fwhm-too-wide',      s = 'FWHM grew past sanity limit';
        case 'fminsearch-error',   s = 'optimiser error';
        case 'too-few-points',     s = 'too few data points';
        otherwise,                 s = reason;
    end
end
