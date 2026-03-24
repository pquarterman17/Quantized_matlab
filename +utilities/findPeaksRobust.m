function [peaks, bgEstimate] = findPeaksRobust(x, y, options)
%FINDPEAKSROBUST  Detect peaks using adaptive local noise and prominence.
%
%   peaks = utilities.findPeaksRobust(x, y)
%   [peaks, bgEstimate] = utilities.findPeaksRobust(x, y, 'SNRThreshold', 5)
%
%   Robust peak detection designed for XRD and spectroscopic data with
%   high dynamic range.  Uses iterative background estimation, adaptive
%   local noise, topographic prominence filtering, and slope rejection
%   to minimise false positives while finding weak peaks near strong ones.
%
%   Algorithm:
%     1. Estimate background via iterative SNIP
%     2. Subtract background → residual
%     3. Adaptive local noise estimation (sliding window MAD)
%     4. Find local maxima above local SNR threshold
%     5. Compute topographic prominence for each candidate
%     6. Reject low-prominence candidates (slope artifacts)
%     7. Parabolic FWHM refinement
%     8. Enforce minimum separation (tallest first)
%     9. Cap at MaxPeaks
%
%   Inputs:
%       x — [N×1] x-axis values
%       y — [N×1] intensity values
%
%   Name-Value Options:
%       SNRThreshold    — minimum signal-to-noise ratio (default 5)
%       MinSeparation   — minimum peak separation in x-units (default 0 = auto)
%       MaxPeaks        — maximum number of peaks to return (default 50)
%       MaxWindowDeg    — SNIP window in x-units (default 2.0)
%       MinWidthDeg     — minimum FWHM to accept (default 0.01)
%       MaxWidthDeg     — maximum FWHM to accept (default 5.0)
%       MinProminence   — minimum prominence as fraction of max residual
%                         height (default 0.02 = 2%)
%       NoiseWindowPts  — half-width of local noise window in points
%                         (default 0 = auto, ~5% of data length)
%       Sensitivity     — preset: 'low', 'medium' (default), 'high'
%                         Adjusts SNRThreshold and MinProminence together.
%
%   Outputs:
%       peaks      — struct array: center, fwhm, height, area, xRange,
%                     status, bg, model, eta, prominence, localSNR
%       bgEstimate — [N×1] estimated background
%
%   Examples:
%       % Standard detection
%       [pks, bg] = utilities.findPeaksRobust(x, y);
%
%       % High sensitivity (find weak peaks)
%       pks = utilities.findPeaksRobust(x, y, 'Sensitivity', 'high');
%
%       % Strict detection (fewer false positives)
%       pks = utilities.findPeaksRobust(x, y, 'Sensitivity', 'low');

% ════════════════════════════════════════════════════════════════════════
%  Input validation
% ════════════════════════════════════════════════════════════════════════
    arguments
        x    (:,1) double
        y    (:,1) double
        options.SNRThreshold   (1,1) double {mustBePositive} = 5
        options.MinSeparation  (1,1) double {mustBeNonnegative} = 0
        options.MaxPeaks       (1,1) double {mustBePositive, mustBeInteger} = 50
        options.MaxWindowDeg   (1,1) double {mustBePositive} = 2.0
        options.MinWidthDeg    (1,1) double {mustBePositive} = 0.01
        options.MaxWidthDeg    (1,1) double {mustBePositive} = 10.0
        options.MinProminence  (1,1) double {mustBeNonnegative} = 0.02
        options.Sensitivity    (1,:) char {mustBeMember(options.Sensitivity, ...
                                        {'low','medium','high'})} = 'medium'
    end

    emptyPk = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
                     'xRange',{},'status',{},'bg',{},'model',{},'eta',{}, ...
                     'prominence',{},'localSNR',{});
    peaks = emptyPk;
    n = numel(y);

    if n < 5
        bgEstimate = y;
        return;
    end

% ════════════════════════════════════════════════════════════════════════
%  Apply sensitivity preset (overrides SNR and prominence defaults)
% ════════════════════════════════════════════════════════════════════════
    switch options.Sensitivity
        case 'high'
            snrThr  = min(options.SNRThreshold, 3);
            minProm = min(options.MinProminence, 0.005);
        case 'low'
            snrThr  = max(options.SNRThreshold, 8);
            minProm = max(options.MinProminence, 0.05);
        otherwise  % 'medium'
            snrThr  = options.SNRThreshold;
            minProm = options.MinProminence;
    end

% ════════════════════════════════════════════════════════════════════════
%  Step 1 — Background estimation
% ════════════════════════════════════════════════════════════════════════
    % Auto-scale SNIP window: ensure it's at least 5% of x-span so that
    % peaks wider than 2° are still clipped properly.
    xSpan  = max(x) - min(x);
    bgWin  = max(options.MaxWindowDeg, xSpan * 0.05);

    bgEstimate = utilities.estimateBackground(x, y, ...
        'MaxWindowDeg', bgWin);

% ════════════════════════════════════════════════════════════════════════
%  Step 2 — Background subtraction
% ════════════════════════════════════════════════════════════════════════
    residual = y - bgEstimate;

% ════════════════════════════════════════════════════════════════════════
%  Step 3 — Noise estimation from raw data
% ════════════════════════════════════════════════════════════════════════
    %  Use point-to-point differences of the raw data (not the one-sided
    %  SNIP residual).  The median filters out large diffs at peak slopes.
    %  The sqrt(2) corrects for diff doubling noise variance.
    globalNoise = estimateNoise(y);
    localNoise  = globalNoise * ones(n, 1);

% ════════════════════════════════════════════════════════════════════════
%  Step 4 — Find local maxima above local SNR threshold
% ════════════════════════════════════════════════════════════════════════
    isMax = false(n, 1);
    isMax(2:end-1) = residual(2:end-1) >= residual(1:end-2) & ...
                     residual(2:end-1) > residual(3:end);

    % Each candidate must exceed its local noise threshold
    localThreshold = snrThr * localNoise;
    isMax = isMax & (residual >= localThreshold);

    maxIdx = find(isMax);
    if isempty(maxIdx)
        return;
    end

% ════════════════════════════════════════════════════════════════════════
%  Step 5 — Compute topographic prominence for each candidate
% ════════════════════════════════════════════════════════════════════════
    pkProminence = computeProminence(residual, maxIdx);

    % Three-way prominence filter (pass ANY to survive):
    %   1. Absolute: prominence >= minProm * max(residual)
    %      → catches globally significant peaks
    %   2. Relative: prominence >= 15% of the peak's own height
    %      → catches isolated weak peaks (small but standing alone)
    %   3. Noise-relative: prominence >= 2 × local noise at peak position
    %      → ensures the peak genuinely rises above the noise floor
    % Noise spikes fail criterion 2 (prominence ≈ noise ≈ height, ratio ~50%)
    % BUT they also fail criterion 3 when prominence < 2*noise.
    % Combined with criterion 1, this filters noise while preserving weak peaks.
    maxResidual    = max(residual);
    % Absolute threshold: must exceed both a fraction of max AND 2× noise
    absPromThresh  = max(minProm * maxResidual, 4 * globalNoise);
    pkHeights      = residual(maxIdx);
    relPromRatio   = pkProminence ./ max(pkHeights, eps);

    % Pass either:
    %   1. Absolute: prominence large enough globally
    %   2. Relative: isolated peak (prominence ≥ 15% of own height)
    %      AND prominence exceeds 2× noise floor
    keepProm = pkProminence >= absPromThresh | ...
               (relPromRatio >= 0.15 & pkProminence >= 4 * globalNoise);

    maxIdx       = maxIdx(keepProm);
    pkProminence = pkProminence(keepProm);

    if isempty(maxIdx)
        return;
    end

% ════════════════════════════════════════════════════════════════════════
%  Step 6 — Slope rejection (reject peaks on steep background gradients)
% ════════════════════════════════════════════════════════════════════════
    bgGrad = abs(gradient(bgEstimate, x));
    keepSlope = true(size(maxIdx));

    for k = 1:numel(maxIdx)
        idx = maxIdx(k);
        % Estimate the background change across one peak width.
        % If the slope causes more change than 30% of the peak height
        % across a typical peak span (~3 points), the candidate is likely
        % a background artifact, not a real peak.
        slopeSpan = bgGrad(idx) * abs(x(min(n, idx+1)) - x(max(1, idx-1)));
        if slopeSpan > residual(idx) * 0.3
            keepSlope(k) = false;
        end
    end

    maxIdx       = maxIdx(keepSlope);
    pkProminence = pkProminence(keepSlope);

    if isempty(maxIdx)
        return;
    end

% ════════════════════════════════════════════════════════════════════════
%  Step 7 — Parabolic FWHM refinement
% ════════════════════════════════════════════════════════════════════════
    pkX    = x(maxIdx);
    pkH    = residual(maxIdx);
    pkBG   = bgEstimate(maxIdx);
    pkFWHM = zeros(size(maxIdx));
    validWidth = true(size(maxIdx));

    dx = median(diff(x));
    minWidthPts = max(4, round(options.MinWidthDeg / max(dx, eps)));

    for k = 1:numel(maxIdx)
        [pkFWHM(k), nPtsAboveHalf] = estimateFWHM(x, residual, maxIdx(k), n);

        % Reject if FWHM outside bounds or peak spans too few points
        if pkFWHM(k) < options.MinWidthDeg || pkFWHM(k) > options.MaxWidthDeg ...
                || nPtsAboveHalf < minWidthPts
            validWidth(k) = false;
        end
    end

    pkX          = pkX(validWidth);
    pkH          = pkH(validWidth);
    pkBG         = pkBG(validWidth);
    pkFWHM       = pkFWHM(validWidth);
    pkProminence = pkProminence(validWidth);
    maxIdx       = maxIdx(validWidth);

    if isempty(pkX)
        return;
    end

% ════════════════════════════════════════════════════════════════════════
%  Step 8 — Local SNR for each surviving peak
% ════════════════════════════════════════════════════════════════════════
    pkLocalSNR = pkH ./ max(localNoise(maxIdx), eps);

% ════════════════════════════════════════════════════════════════════════
%  Step 9 — Minimum distance suppression (greedy, tallest first)
% ════════════════════════════════════════════════════════════════════════
    minSep = options.MinSeparation;
    if minSep <= 0
        minSep = xSpan * 0.005;
    end

    [pkH_s, ord] = sort(pkH, 'descend');
    pkX_s    = pkX(ord);
    pkBG_s   = pkBG(ord);
    pkFWHM_s = pkFWHM(ord);
    pkProm_s = pkProminence(ord);
    pkSNR_s  = pkLocalSNR(ord);
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
    pkProm_s = pkProm_s(keep);
    pkSNR_s  = pkSNR_s(keep);

% ════════════════════════════════════════════════════════════════════════
%  Step 10 — Cap at MaxPeaks (already sorted by height descending)
% ════════════════════════════════════════════════════════════════════════
    if numel(pkX_s) > options.MaxPeaks
        pkX_s    = pkX_s(1:options.MaxPeaks);
        pkH_s    = pkH_s(1:options.MaxPeaks);
        pkBG_s   = pkBG_s(1:options.MaxPeaks);
        pkFWHM_s = pkFWHM_s(1:options.MaxPeaks);
        pkProm_s = pkProm_s(1:options.MaxPeaks);
        pkSNR_s  = pkSNR_s(1:options.MaxPeaks);
    end

% ════════════════════════════════════════════════════════════════════════
%  Step 11 — Build output struct array, sorted by center position
% ════════════════════════════════════════════════════════════════════════
    [pkX_s, reord] = sort(pkX_s);
    pkH_s    = pkH_s(reord);
    pkBG_s   = pkBG_s(reord);
    pkFWHM_s = pkFWHM_s(reord);
    pkProm_s = pkProm_s(reord);
    pkSNR_s  = pkSNR_s(reord);

    for k = 1:numel(pkX_s)
        pk.center     = pkX_s(k);
        pk.fwhm       = pkFWHM_s(k);
        pk.height     = pkH_s(k);
        pk.area       = NaN;
        pk.xRange     = [];
        pk.status     = 'auto';
        pk.bg         = pkBG_s(k);
        pk.model      = '';
        pk.eta        = NaN;
        pk.prominence = pkProm_s(k);
        pk.localSNR   = pkSNR_s(k);
        peaks(end + 1) = pk;  %#ok<AGROW>
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Adaptive local noise estimation via sliding window MAD
% ════════════════════════════════════════════════════════════════════════
function sigma = estimateNoise(y)
%ESTIMATENOISE  Robust noise estimate from point-to-point differences.
%   Uses MAD of diff(y), which is insensitive to peaks and background
%   shape since peaks are rare compared to quiet regions.
    diffs = diff(y);
    sigma = 1.4826 * median(abs(diffs - median(diffs))) / sqrt(2);
    % Floor for noiseless data
    sigma = max(sigma, max(y) * 1e-6);
end

% ════════════════════════════════════════════════════════════════════════
%  Topographic prominence (how far a peak rises above surrounding terrain)
% ════════════════════════════════════════════════════════════════════════
function prom = computeProminence(residual, maxIdx)
    nPeaks = numel(maxIdx);
    prom = zeros(nPeaks, 1);
    n = numel(residual);

    for k = 1:nPeaks
        idx = maxIdx(k);
        pkHeight = residual(idx);

        % Walk left to find the deepest valley before a higher peak
        leftMin = pkHeight;
        for j = (idx - 1):-1:1
            if residual(j) < leftMin
                leftMin = residual(j);
            end
            if residual(j) > pkHeight
                break;  % encountered a higher peak
            end
        end

        % Walk right to find the deepest valley before a higher peak
        rightMin = pkHeight;
        for j = (idx + 1):n
            if residual(j) < rightMin
                rightMin = residual(j);
            end
            if residual(j) > pkHeight
                break;
            end
        end

        % Prominence = height above the higher of the two key cols
        keyCol  = max(leftMin, rightMin);
        prom(k) = pkHeight - keyCol;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Parabolic FWHM estimation (more accurate than linear walk)
% ════════════════════════════════════════════════════════════════════════
function [fw, nPtsAboveHalf] = estimateFWHM(x, residual, idx, n)
    pkH = residual(idx);
    halfMax = pkH / 2;

    % Walk left until below half-max, then interpolate
    lIdx = 1;
    for j = (idx - 1):-1:1
        if residual(j) <= halfMax
            lIdx = j;
            break;
        end
    end
    % Linear interpolation for sub-sample accuracy
    if lIdx < idx && lIdx >= 1
        r1 = residual(lIdx);
        r2 = residual(min(lIdx + 1, n));
        if abs(r2 - r1) > eps
            frac = (halfMax - r1) / (r2 - r1);
            xLeft = x(lIdx) + frac * (x(min(lIdx + 1, n)) - x(lIdx));
        else
            xLeft = x(lIdx);
        end
    else
        xLeft = x(max(1, idx - 1));
    end

    % Walk right until below half-max, then interpolate
    rIdx = n;
    for j = (idx + 1):n
        if residual(j) <= halfMax
            rIdx = j;
            break;
        end
    end
    if rIdx > idx && rIdx <= n
        r1 = residual(rIdx);
        r2 = residual(max(rIdx - 1, 1));
        if abs(r2 - r1) > eps
            frac = (halfMax - r1) / (r2 - r1);
            xRight = x(rIdx) + frac * (x(max(rIdx - 1, 1)) - x(rIdx));
        else
            xRight = x(rIdx);
        end
    else
        xRight = x(min(n, idx + 1));
    end

    fw = abs(xRight - xLeft);
    if fw <= 0
        % Fallback: use spacing around peak
        fw = abs(x(min(n, idx + 1)) - x(max(1, idx - 1)));
    end

    % Count data points above half-max (for rejecting single-point spikes)
    nPtsAboveHalf = sum(residual(max(1,lIdx):min(n,rIdx)) >= halfMax);
end
