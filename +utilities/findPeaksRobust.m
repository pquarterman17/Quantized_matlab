function [peaks, bgEstimate] = findPeaksRobust(x, y, options)
%FINDPEAKSROBUST  Detect XRD peaks using SNIP background + SNR filtering.
%
%   peaks = utilities.findPeaksRobust(x, y)
%   [peaks, bgEstimate] = utilities.findPeaksRobust(x, y, 'SNRThreshold', 5)
%
%   Robust peak detection designed for XRD data with high dynamic range.
%   Uses SNIP background estimation to flatten the baseline before
%   detecting peaks, which eliminates false positives from noise on
%   varying backgrounds and false negatives from thin-film peaks
%   dwarfed by substrate peaks.
%
%   Algorithm:
%     1. Estimate background via SNIP (utilities.estimateBackground)
%     2. Subtract background: residual = y - bg
%     3. Estimate noise from residual (MAD in below-median regions)
%     4. Find local maxima in residual above SNR threshold
%     5. Estimate FWHM; reject peaks with unphysical widths
%     6. Enforce minimum separation (tallest peak wins)
%     7. Cap at MaxPeaks
%
%   Inputs:
%       x — [N×1] 2-theta values (degrees)
%       y — [N×1] intensity values
%
%   Name-Value Options:
%       SNRThreshold    — minimum signal-to-noise ratio (default 5)
%       MinSeparation   — minimum peak separation in x-units (default 0 = auto)
%       MaxPeaks        — maximum number of peaks to return (default 50)
%       MaxWindowDeg    — SNIP window in degrees (default 2.0)
%       MinWidthDeg     — minimum FWHM to accept in degrees (default 0.01)
%       MaxWidthDeg     — maximum FWHM to accept in degrees (default 5.0)
%
%   Outputs:
%       peaks      — struct array with fields: center, fwhm, height, area,
%                     xRange, status, bg, model, eta
%       bgEstimate — [N×1] estimated background (for overlay plotting)
%
%   Examples:
%       % Auto-detect peaks in XRD data
%       data = parser.importRigaku_raw('scan.raw');
%       [pks, bg] = utilities.findPeaksRobust(data.time, data.values(:,1));
%
%       % Overlay background and peak markers
%       plot(data.time, data.values(:,1)); hold on;
%       plot(data.time, bg, '--g');
%       for k = 1:numel(pks), xline(pks(k).center, ':r'); end
%
%       % Stricter detection with higher SNR
%       pks = utilities.findPeaksRobust(x, y, 'SNRThreshold', 10);

% ════════════════════════════════════════════════════════════════════════
%  Input validation
% ════════════════════════════════════════════════════════════════════════
    arguments
        x    (:,1) double
        y    (:,1) double
        options.SNRThreshold  (1,1) double {mustBePositive} = 5
        options.MinSeparation (1,1) double {mustBeNonnegative} = 0
        options.MaxPeaks      (1,1) double {mustBePositive, mustBeInteger} = 50
        options.MaxWindowDeg  (1,1) double {mustBePositive} = 2.0
        options.MinWidthDeg   (1,1) double {mustBePositive} = 0.01
        options.MaxWidthDeg   (1,1) double {mustBePositive} = 5.0
    end

    emptyPk = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
                     'xRange',{},'status',{},'bg',{},'model',{},'eta',{});
    peaks = emptyPk;
    n = numel(y);

    if n < 5
        bgEstimate = y;
        return;
    end

% ════════════════════════════════════════════════════════════════════════
%  Step 1 — Background estimation via SNIP
% ════════════════════════════════════════════════════════════════════════
    bgEstimate = utilities.estimateBackground(x, y, ...
        'MaxWindowDeg', options.MaxWindowDeg);

% ════════════════════════════════════════════════════════════════════════
%  Step 2 — Background subtraction
% ════════════════════════════════════════════════════════════════════════
    residual = y - bgEstimate;

% ════════════════════════════════════════════════════════════════════════
%  Step 3 — Noise estimation from background-subtracted signal
% ════════════════════════════════════════════════════════════════════════
    %  Use only below-median residual values (noise-dominated regions,
    %  not peak regions) for a clean noise estimate.
    medRes = median(residual);
    noiseRegion = residual(residual < medRes);
    if numel(noiseRegion) > 5
        noiseSigma = 1.4826 * median(abs(noiseRegion - median(noiseRegion)));
    else
        noiseSigma = 1.4826 * median(abs(residual - medRes));
    end
    if noiseSigma < eps
        noiseSigma = max(residual) * 0.001;   % fallback for constant data
    end

% ════════════════════════════════════════════════════════════════════════
%  Step 4 — Find local maxima above SNR threshold
% ════════════════════════════════════════════════════════════════════════
    threshold = options.SNRThreshold * noiseSigma;

    isMax = false(n, 1);
    isMax(2:end-1) = residual(2:end-1) > residual(1:end-2) & ...
                     residual(2:end-1) > residual(3:end);
    isMax = isMax & (residual >= threshold);

    maxIdx = find(isMax);
    if isempty(maxIdx)
        return;
    end

% ════════════════════════════════════════════════════════════════════════
%  Step 5 — FWHM estimation and width validation
% ════════════════════════════════════════════════════════════════════════
    pkX    = x(maxIdx);
    pkH    = residual(maxIdx);     % height above background
    pkBG   = bgEstimate(maxIdx);   % local background level
    pkFWHM = zeros(size(maxIdx));
    validWidth = true(size(maxIdx));

    for k = 1:numel(maxIdx)
        idx = maxIdx(k);
        halfMax = pkH(k) / 2;

        % Walk left from peak until residual drops to half-max
        lIdx = idx;
        for j = (idx - 1):-1:1
            if residual(j) <= halfMax
                lIdx = j;
                break;
            end
        end
        if lIdx == idx, lIdx = max(1, idx - 1); end

        % Walk right from peak until residual drops to half-max
        rIdx = idx;
        for j = (idx + 1):n
            if residual(j) <= halfMax
                rIdx = j;
                break;
            end
        end
        if rIdx == idx, rIdx = min(n, idx + 1); end

        pkFWHM(k) = x(rIdx) - x(lIdx);

        % Reject if width is unphysical
        if pkFWHM(k) < options.MinWidthDeg || pkFWHM(k) > options.MaxWidthDeg
            validWidth(k) = false;
        end
    end

    % Apply width filter
    pkX    = pkX(validWidth);
    pkH    = pkH(validWidth);
    pkBG   = pkBG(validWidth);
    pkFWHM = pkFWHM(validWidth);

    if isempty(pkX)
        return;
    end

% ════════════════════════════════════════════════════════════════════════
%  Step 6 — Minimum distance suppression (greedy, tallest first)
% ════════════════════════════════════════════════════════════════════════
    xSpan = max(x) - min(x);
    minSep = options.MinSeparation;
    if minSep <= 0
        minSep = xSpan * 0.005;   % auto: 0.5% of x-span
    end

    [pkH_s, ord] = sort(pkH, 'descend');
    pkX_s    = pkX(ord);
    pkBG_s   = pkBG(ord);
    pkFWHM_s = pkFWHM(ord);
    keep = true(size(pkX_s));

    for ii = 1:numel(pkX_s)
        if ~keep(ii), continue; end
        for jj = (ii + 1):numel(pkX_s)
            if ~keep(jj), continue; end
            if abs(pkX_s(ii) - pkX_s(jj)) < minSep
                keep(jj) = false;
            end
        end
    end

    pkX_s    = pkX_s(keep);
    pkH_s    = pkH_s(keep);
    pkBG_s   = pkBG_s(keep);
    pkFWHM_s = pkFWHM_s(keep);

% ════════════════════════════════════════════════════════════════════════
%  Step 7 — Cap at MaxPeaks (already sorted by height descending)
% ════════════════════════════════════════════════════════════════════════
    if numel(pkX_s) > options.MaxPeaks
        pkX_s    = pkX_s(1:options.MaxPeaks);
        pkH_s    = pkH_s(1:options.MaxPeaks);
        pkBG_s   = pkBG_s(1:options.MaxPeaks);
        pkFWHM_s = pkFWHM_s(1:options.MaxPeaks);
    end

% ════════════════════════════════════════════════════════════════════════
%  Step 8 — Build output struct array, sorted by center position
% ════════════════════════════════════════════════════════════════════════
    [pkX_s, reord] = sort(pkX_s);
    pkH_s    = pkH_s(reord);
    pkBG_s   = pkBG_s(reord);
    pkFWHM_s = pkFWHM_s(reord);

    for k = 1:numel(pkX_s)
        pk.center = pkX_s(k);
        pk.fwhm   = pkFWHM_s(k);
        pk.height = pkH_s(k);      % amplitude above background
        pk.area   = NaN;
        pk.xRange = [];
        pk.status = 'auto';
        pk.bg     = pkBG_s(k);     % local background level
        pk.model  = '';
        pk.eta    = NaN;
        peaks(end + 1) = pk;  %#ok<AGROW>
    end
end
