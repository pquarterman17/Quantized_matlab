classdef PeakWorkshopModel < handle
%PEAKWORKSHOPMODEL  State container for the Peak Workshop.
%
%   Owns ALL peak-feature state: detection params (SNR, prominence,
%   min separation, K factor, instrument broadening), the active peak
%   list, the SNIP background estimate, and the fit-curve display
%   colour. Replaces appData fields that were previously the
%   coordination point between BosonPlotter and the peak window.
%
%   Constructed once per BosonPlotter instance; bound to the active
%   dataset via .bind(dsRef). Callbacks operate on this model rather
%   than reaching into BosonPlotter's closure.
%
%   This is the SKELETON landed in 1a. Real method bodies + state
%   migration arrive in step 1b. The class signature below is the
%   target interface so callers can begin to depend on it.

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
        peaks          struct = emptyPeakStruct()  % fitted/manual peak list
        snipBackground struct = struct()           % .x, .bg from auto-detect
    end

    methods
        function obj = PeakWorkshopModel()
            % Construct empty. Real init in 1b.
        end

        % ── Bind to active dataset (placeholder for 1b) ──────────────
        function bind(~, ~)
            % bind(obj, dsRef) — 1b will populate peaks + snipBg from dsRef.
        end

        % ── Detection / fit (placeholders for 1b) ────────────────────
        function detect(~)
            error('PeakWorkshopModel:notImplemented', ...
                'detect() arrives in step 1b — see plans/workshop-conversion-plan.md.');
        end
        function fitOne(~, ~)
            error('PeakWorkshopModel:notImplemented', 'fitOne() arrives in 1b.');
        end
        function fitAll(~)
            error('PeakWorkshopModel:notImplemented', 'fitAll() arrives in 1b.');
        end
        function clear(~)
            error('PeakWorkshopModel:notImplemented', 'clear() arrives in 1b.');
        end
    end
end

function s = emptyPeakStruct()
%EMPTYPEAKSTRUCT  Canonical empty peak struct (matches dataset .peaks shape).
    s = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
               'xRange',{},'status',{},'bg',{},'model',{},'eta',{}, ...
               'prominence',{},'localSNR',{});
end
