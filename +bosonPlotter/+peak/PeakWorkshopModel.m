classdef PeakWorkshopModel < handle
%PEAKWORKSHOPMODEL  State container for the Peak Workshop.
%
%   Owns ALL peak-feature state: detection params (SNR, prominence,
%   min separation, K factor, instrument broadening, wavelength, fit
%   model), the peak list, the SNIP background estimate, fit display
%   settings, and interaction-mode flags.
%
%   Usage from a controller:
%       model = bosonPlotter.peak.PeakWorkshopModel();
%       model.bindFromDataset(ds);            % pull peaks + snipBg
%       model.detect(xv, yv);                 % SNIP detection
%       failures = model.fitAll(xv, yv);      % fit every peak
%       ds = model.applyToDataset(ds);        % write back
%
%   The model is intentionally GUI-free — it never touches axes,
%   widgets, or appData. That's the whole point of the workshop
%   pattern: the model can be tested in isolation against synthetic
%   data, and any GUI shell (the existing Peak Workshop window, a
%   future dialog, a headless batch run) drives it through the same
%   methods.

    % ── Detection parameters ────────────────────────────────────────
    properties
        peakSNR        double  = 5
        peakProminence double  = 0.02
        minSep         double  = 0           % 0 → automatic (~1% of x-span)
        kFactor        double  = 0.9         % Scherrer shape factor
        instBroadening double  = 0           % degrees, FWHM
        wavelength_A   double  = 0           % Å; 0 → not set
        fitModel       char    = 'Lorentzian'
    end

    % ── Display state ────────────────────────────────────────────────
    properties
        fitCurveColor  double  = [0.85 0.20 0.00]
        showFitCurves  logical = true
        showSnipBg     logical = true
    end

    % ── Interaction state ────────────────────────────────────────────
    properties
        peakPickMode    logical = false
        peakRemoveMode  logical = false
        selectedPeakIdx double  = 0
    end

    % ── Bound data + outputs ─────────────────────────────────────────
    properties (SetAccess = protected)
        peaks                 = bosonPlotter.peak.PeakWorkshopModel.emptyPeakStruct()
        snipBackground struct = struct()
    end

    % ════════════════════════════════════════════════════════════════
    %  Public API
    % ════════════════════════════════════════════════════════════════
    methods
        function obj = PeakWorkshopModel()
            % Empty constructor — properties take their defined defaults.
        end

        % ── Bind to / write back to a dataset struct ──────────────────
        function bindFromDataset(obj, ds)
        %BINDFROMDATASET  Copy peaks + snipBackground from a dataset onto the model.
        %   Normalises the peak struct shape so legacy peaks (saved before
        %   asymmetry/fitParams were canonical) get upgraded — otherwise
        %   the next fitOne would fail with "dissimilar structures".
            if isfield(ds, 'peaks') && ~isempty(ds.peaks)
                obj.peaks = bosonPlotter.peak.PeakWorkshopModel.normalizePeaks(ds.peaks);
            else
                obj.peaks = bosonPlotter.peak.PeakWorkshopModel.emptyPeakStruct();
            end
            if isfield(ds, 'snipBackground') && ~isempty(ds.snipBackground)
                obj.snipBackground = ds.snipBackground;
            else
                obj.snipBackground = struct();
            end
            obj.selectedPeakIdx = 0;
        end

        function ds = applyToDataset(obj, ds)
        %APPLYTODATASET  Write peaks + snipBackground back onto a dataset struct.
            ds.peaks = obj.peaks;
            ds.snipBackground = obj.snipBackground;
        end

        % ── Detection ────────────────────────────────────────────────
        function detect(obj, xv, yv)
        %DETECT  SNIP-based peak detection on (xv, yv). Updates obj.peaks.
        %   Preserves any existing manual seeds (status='manual') and
        %   re-detects them in pass 2. xv must be monotone-increasing.
            arguments
                obj
                xv (:,1) double
                yv (:,1) double
            end
            if numel(xv) < 5, return; end
            xSpan = diff([min(xv), max(xv)]);
            PEAK_SEP_TOL_FRAC   = 0.005;
            PEAK_LOCAL_WIN_FRAC = 0.02;

            % Save manual seeds before rebuilding the list
            if ~isempty(obj.peaks) && isfield(obj.peaks, 'status')
                isManual    = strcmp({obj.peaks.status}, 'manual');
                manualSeeds = obj.peaks(isManual);
            else
                manualSeeds = bosonPlotter.peak.PeakWorkshopModel.emptyPeakStruct();
            end

            % Pass 1: SNIP-based detection
            [merged, bgEst] = utilities.findPeaksRobust(xv, yv, ...
                'SNRThreshold',  obj.peakSNR, ...
                'MinProminence', obj.peakProminence, ...
                'MinSeparation', max(0, obj.minSep), ...
                'MaxPeaks',      50, ...
                'MaxWindowDeg',  2.0);
            obj.snipBackground = struct('x', xv, 'bg', bgEst);

            % findPeaksRobust returns 11-field peaks (no asymmetry/fitParams).
            % Normalise so the array shape matches manualSeeds (13 fields)
            % and any subsequent fitOne can assign without struct mismatch.
            merged = bosonPlotter.peak.PeakWorkshopModel.normalizePeaks(merged);

            % Pass 2: re-detect at any manual seed not covered by pass 1
            minSepLocal = xSpan * PEAK_SEP_TOL_FRAC;
            halfWin     = xSpan * PEAK_LOCAL_WIN_FRAC;
            for si = 1:numel(manualSeeds)
                seedX = manualSeeds(si).center;
                if ~isempty(merged) && any(abs([merged.center] - seedX) <= minSepLocal)
                    continue;
                end
                inWin = xv >= (seedX - halfWin) & xv <= (seedX + halfWin);
                if ~any(inWin)
                    merged(end+1) = manualSeeds(si); %#ok<AGROW>
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
                merged(end+1) = bosonPlotter.peak.PeakWorkshopModel.makePeak( ...
                    lX, lW, lH, NaN, [], 'manual'); %#ok<AGROW>
            end

            if isempty(merged)
                obj.peaks = bosonPlotter.peak.PeakWorkshopModel.emptyPeakStruct();
                return;
            end

            merged = bosonPlotter.peak.deduplicatePeaks(merged, minSepLocal);
            [~, ord] = sort([merged.center]);
            obj.peaks = merged(ord);
        end

        % ── Fitting ──────────────────────────────────────────────────
        function r = fitOne(obj, idx, xv, yv)
        %FITONE  Fit a single peak; update obj.peaks(idx) on success.
        %   Returns the fitSinglePeak result struct (success flag, reason
        %   on failure, params on success). Performs a retry pass with a
        %   1.5x widened window + SNIP background subtraction if the first
        %   attempt fails.
            arguments
                obj
                idx (1,1) double {mustBePositive, mustBeInteger}
                xv  (:,1) double
                yv  (:,1) double
            end
            if idx > numel(obj.peaks)
                error('PeakWorkshopModel:badIndex', ...
                    'Peak index %d exceeds peak count %d.', idx, numel(obj.peaks));
            end
            pk = obj.peaks(idx);
            [xLo, xHi] = obj.fitWindowFor(pk, xv);
            seed = struct('center', pk.center, 'fwhm', pk.fwhm);
            r = bosonPlotter.peak.fitSinglePeak(xv, yv, xLo, xHi, seed, obj.fitModel, []);
            if ~r.success
                snipBg = bosonPlotter.peak.alignSnipBackground( ...
                    struct('snipBackground', obj.snipBackground), xv);
                hw2 = 1.5 * (xHi - xLo) / 2;
                r = bosonPlotter.peak.fitSinglePeak(xv, yv, ...
                    pk.center - hw2, pk.center + hw2, seed, obj.fitModel, snipBg);
            end
            if r.success
                obj.peaks(idx) = bosonPlotter.peak.PeakWorkshopModel.applyFitToPk(pk, r);
            end
        end

        function failures = fitAll(obj, xv, yv)
        %FITALL  Fit every peak; return list of failures.
        %   Each failure entry: {idx, center, reason, suggestion, window}.
        %   Successful fits update obj.peaks(idx) in place.
            arguments
                obj
                xv (:,1) double
                yv (:,1) double
            end
            failures = struct('idx', {}, 'center', {}, 'reason', {}, ...
                              'suggestion', {}, 'window', {});
            for idx = 1:numel(obj.peaks)
                pk = obj.peaks(idx);
                r = obj.fitOne(idx, xv, yv);
                if ~r.success
                    failures(end+1) = struct(...
                        'idx',        idx, ...
                        'center',     pk.center, ...
                        'reason',     r.reason, ...
                        'suggestion', bosonPlotter.peak.suggestNextStep(r.reason, obj.fitModel), ...
                        'window',     r.window); %#ok<AGROW>
                end
            end
        end

        % ── Manual interaction ───────────────────────────────────────
        function r = addManual(obj, xClick, xv, yv)
        %ADDMANUAL  Add a manually-clicked peak at xClick, auto-fit if possible.
        %   Snaps to the nearest local maximum within ±3% of x-span,
        %   estimates a local FWHM, then runs a single-peak fit. On
        %   fit success the peak lands as 'fitted'; on failure it lands
        %   as 'manual' with the FWHM estimate (or NaN). Returns the
        %   fitSinglePeak result struct.
            arguments
                obj
                xClick (1,1) double
                xv     (:,1) double
                yv     (:,1) double
            end
            xSpan = diff([min(xv), max(xv)]);

            % Snap to nearest local max within ±3% of x-span
            xWin  = xSpan * 0.03;
            inWin = xv >= (xClick - xWin) & xv <= (xClick + xWin);
            if any(inWin)
                xInWin = xv(inWin);  yInWin = yv(inWin);
                nW = numel(yInWin);
                if nW >= 3
                    isLMax = false(nW, 1);
                    isLMax(2:end-1) = yInWin(2:end-1) > yInWin(1:end-2) & ...
                                      yInWin(2:end-1) > yInWin(3:end);
                    if any(isLMax)
                        lmX = xInWin(isLMax);  lmH = yInWin(isLMax);
                        [~, nearI] = min(abs(lmX - xClick));
                        pkX = lmX(nearI);  pkH = lmH(nearI);
                    else
                        [~, nearI] = min(abs(xInWin - xClick));
                        pkX = xInWin(nearI);  pkH = yInWin(nearI);
                    end
                else
                    [~, nearI] = min(abs(xInWin - xClick));
                    pkX = xInWin(nearI);  pkH = yInWin(nearI);
                end
            else
                pkX = xClick;  pkH = NaN;
            end

            fwhmEst = bosonPlotter.peak.estimateLocalFWHM(xv, yv, pkX, xSpan);
            newPk = bosonPlotter.peak.PeakWorkshopModel.makePeak( ...
                pkX, fwhmEst, pkH, NaN, [], 'manual');

            % Auto-fit attempt
            if isfinite(fwhmEst)
                hw = 3.0 * fwhmEst;
            else
                hw = xSpan * 0.03;
            end
            seed = struct('center', pkX, 'fwhm', fwhmEst);
            r = bosonPlotter.peak.fitSinglePeak(xv, yv, pkX - hw, pkX + hw, seed, obj.fitModel, []);
            if r.success
                newPk = bosonPlotter.peak.PeakWorkshopModel.applyFitToPk(newPk, r);
            end

            obj.peaks(end+1) = newPk;
        end

        function removePeak(obj, idx)
        %REMOVEPEAK  Drop the peak at index idx (silently no-ops on bad idx).
            if idx < 1 || idx > numel(obj.peaks), return; end
            obj.peaks(idx) = [];
            if obj.selectedPeakIdx == idx
                obj.selectedPeakIdx = 0;
            elseif obj.selectedPeakIdx > idx
                obj.selectedPeakIdx = obj.selectedPeakIdx - 1;
            end
        end

        function clearPeaks(obj)
        %CLEARPEAKS  Remove all peaks; clears selection.
            obj.peaks = bosonPlotter.peak.PeakWorkshopModel.emptyPeakStruct();
            obj.selectedPeakIdx = 0;
        end

        function selectPeak(obj, idx)
        %SELECTPEAK  Mark the peak at index idx as selected (0 = no selection).
            if idx >= 0 && idx <= numel(obj.peaks)
                obj.selectedPeakIdx = idx;
            end
        end

        % ════════════════════════════════════════════════════════════
        %  Post-fit XRD analysis (delegates to bosonPlotter.peakTools)
        % ════════════════════════════════════════════════════════════
        function result = williamsonHall(obj, ds, opts)
        %WILLIAMSONHALL  Run W-H strain analysis on fitted peaks.
        %   result = model.williamsonHall(ds)
        %   result = model.williamsonHall(ds, ParentFig=fig, StatusFcn=@setStatus)
        %
        %   ds must contain ds.peaks (the dialog reads them directly so
        %   the model writes its current peak list back via applyToDataset
        %   first). Wavelength is taken from obj.wavelength_A; K-factor
        %   and instrument broadening from obj.kFactor / obj.instBroadening.
            arguments
                obj
                ds                 struct
                opts.ParentFig                    = []
                opts.StatusFcn     function_handle = @(~) []
            end
            ds = obj.applyToDataset(ds);
            result = bosonPlotter.peakTools.williamsonHall( ...
                ds, obj.wavelength_A, obj.kFactor, obj.instBroadening, ...
                ParentFig=opts.ParentFig, StatusFcn=opts.StatusFcn);
        end

        function result = refineLattice(obj, ds, opts)
        %REFINELATTICE  Refine lattice parameters via peakTools dialog.
            arguments
                obj
                ds                 struct
                opts.ParentFig                    = []
                opts.StatusFcn     function_handle = @(~) []
                opts.ButtonColors  struct = struct('primary',[0.18 0.52 0.18],'fg',[1 1 1])
            end
            ds = obj.applyToDataset(ds);
            result = bosonPlotter.peakTools.refineLattice( ...
                ds, obj.wavelength_A, ...
                ParentFig=opts.ParentFig, StatusFcn=opts.StatusFcn, ...
                ButtonColors=opts.ButtonColors);
        end

        function result = matchPhases(obj, ds, opts)
        %MATCHPHASES  Match d-spacings against the built-in phase database.
            arguments
                obj
                ds                 struct
                opts.ParentFig                    = []
                opts.StatusFcn     function_handle = @(~) []
                opts.MainAx                       = []
            end
            ds = obj.applyToDataset(ds);
            result = bosonPlotter.peakTools.matchPhases( ...
                ds, obj.wavelength_A, ...
                ParentFig=opts.ParentFig, StatusFcn=opts.StatusFcn, ...
                MainAx=opts.MainAx);
        end

        function result = fftThickness(obj, ds, opts)
        %FFTTHICKNESS  Compute film thickness from Laue / Kiessig fringes.
            arguments
                obj
                ds                 struct
                opts.ParentFig                    = []
                opts.StatusFcn     function_handle = @(~) []
                opts.ButtonColors  struct = struct('accent',[0.15 0.37 0.63],'fg',[1 1 1])
                opts.AxisLimits                   = []
            end
            ds = obj.applyToDataset(ds);
            result = bosonPlotter.peakTools.fftThickness( ...
                ds, obj.wavelength_A, ...
                ParentFig=opts.ParentFig, StatusFcn=opts.StatusFcn, ...
                ButtonColors=opts.ButtonColors, AxisLimits=opts.AxisLimits);
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  Internal helpers
    % ════════════════════════════════════════════════════════════════
    methods (Access = protected)
        function [xLo, xHi] = fitWindowFor(~, pk, xv)
        %FITWINDOWFOR  Determine a fit window for one peak.
        %   Priority: explicit pk.xRange → ±3·FWHM → fallback ±3% of x-span.
            FIT_HALFWIDTH_MULT = 3.0;
            FIT_FALLBACK_FRAC  = 0.03;
            xSpan = diff([min(xv), max(xv)]);
            if ~isempty(pk.xRange) && numel(pk.xRange) == 2
                xLo = pk.xRange(1);  xHi = pk.xRange(2);
            elseif ~isnan(pk.fwhm) && pk.fwhm > 0
                hw  = FIT_HALFWIDTH_MULT * pk.fwhm;
                xLo = pk.center - hw;
                xHi = pk.center + hw;
            else
                hw  = xSpan * FIT_FALLBACK_FRAC;
                xLo = pk.center - hw;
                xHi = pk.center + hw;
            end
        end
    end

    methods (Static, Access = public)
        function s = emptyPeakStruct()
        %EMPTYPEAKSTRUCT  Canonical empty peak struct (matches dataset .peaks shape).
        %   ALL peaks share this 13-field shape regardless of fit model.
        %   asymmetry / fitParams are populated by Split Pearson VII and
        %   TCH-pV fits; for other models they remain NaN / [] but the
        %   fields exist so struct-array assignment never fails with
        %   "dissimilar structures".
            s = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
                       'xRange',{},'status',{},'bg',{},'model',{},'eta',{}, ...
                       'prominence',{},'localSNR',{}, ...
                       'asymmetry',{},'fitParams',{});
        end

        function pk = makePeak(center, fwhm, height, area, xRange, status)
        %MAKEPEAK  Build a single peak struct with the canonical field set.
            if nargin < 4, area = NaN; end
            if nargin < 5, xRange = []; end
            if nargin < 6, status = 'manual'; end
            pk.center     = center;
            pk.fwhm       = fwhm;
            pk.height     = height;
            pk.area       = area;
            pk.xRange     = xRange;
            pk.status     = status;
            pk.bg         = NaN;
            pk.model      = '';
            pk.eta        = NaN;
            pk.prominence = NaN;
            pk.localSNR   = NaN;
            pk.asymmetry  = NaN;
            pk.fitParams  = [];
        end

        function pk = applyFitToPk(pk, r)
        %APPLYFITTOPK  Merge a fitSinglePeak result struct into a peak struct.
        %   Every peak ends up with the same 13-field shape — extra fields
        %   like asymmetry / fitParams are ALWAYS set (NaN / []) so that
        %   `obj.peaks(idx) = applyFitToPk(...)` never errors with
        %   "dissimilar structures" across mixed-model peak arrays.
            pk.center     = r.center;
            pk.fwhm       = r.fwhm;
            pk.height     = r.height;
            pk.bg         = r.bg;
            pk.eta        = r.eta;
            pk.area       = r.area;
            pk.model      = r.model;
            pk.status     = 'fitted';
            pk.asymmetry  = NaN;
            pk.fitParams  = [];
            if strcmp(r.model, 'Split Pearson VII')
                pk.asymmetry = abs(r.params(3)) / abs(r.params(4));
                pk.fitParams = r.params;
            elseif strcmp(r.model, 'TCH-pV')
                pk.fitParams = r.params;
            end
        end

        function peaks = normalizePeaks(peaks)
        %NORMALIZEPEAKS  Ensure every element has the canonical 13 fields.
        %   Used by bindFromDataset to upgrade peaks loaded from sessions
        %   saved before the canonical shape included asymmetry/fitParams.
            if isempty(peaks), return; end
            canonical = {'center','fwhm','height','area','xRange','status', ...
                         'bg','model','eta','prominence','localSNR', ...
                         'asymmetry','fitParams'};
            defaults  = {NaN, NaN, NaN, NaN, [], 'manual', ...
                         NaN, '', NaN, NaN, NaN, ...
                         NaN, []};
            for fi = 1:numel(canonical)
                f = canonical{fi};
                if ~isfield(peaks, f)
                    [peaks.(f)] = deal(defaults{fi});
                end
            end
        end
    end
end
