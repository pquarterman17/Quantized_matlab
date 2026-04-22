function result = rsmAnalyze(map, options)
%RSMANALYZE  Decompose a 2D reciprocal-space map into substrate + film peaks.
%
%   Syntax
%     result = fitting.rsmAnalyze(map)
%     result = fitting.rsmAnalyze(map, NPeaks=2, FitModel='2D Pseudo-Voigt')
%
%   Inputs
%     map — struct as produced by parser.importXRDML (or passed through
%           parser.computeQSpace).  Required fields:
%             .intensity  [N×M] intensity matrix
%             .axis1      [N×1] ω values (deg)
%             .axis2      [M×1] 2θ values (deg)
%           Optional fields (used when present):
%             .Qx, .Qz    [N×M] reciprocal-space grids (Å⁻¹)
%             .intensityUnit  string (default 'cps')
%
%   Options (name-value)
%     NPeaks        — maximum number of peaks to report (default 2)
%     Threshold     — intensity floor as fraction of max; peaks below are
%                     rejected (default 0.01)
%     SmoothSigma   — Gaussian smoothing σ in pixels applied to the map
%                     before local-maximum detection (default 1.5)
%     MinSeparation — minimum pixel distance between detected peaks
%                     (default 4)
%     FitWindow     — half-window in pixels for the per-peak 2D fit
%                     (default 6, giving a 13×13 patch)
%     FitModel      — surface model name: '2D Gaussian' (default),
%                     '2D Lorentzian', or '2D Pseudo-Voigt'
%     Verbose       — print a short table of detected peaks (default false)
%
%   Output — struct with
%     .peaks  : struct array (one entry per detected peak) with fields
%         .rank           — 1 = strongest
%         .centre_angle   — [ω, 2θ] in degrees
%         .centre_Q       — [Qx, Qz] in Å⁻¹ (NaN if map lacks Q-space)
%         .fwhm_angle     — [ω-FWHM, 2θ-FWHM] in degrees
%         .fwhm_Q         — [Qx-FWHM, Qz-FWHM] in Å⁻¹ (NaN if no Q)
%         .amplitude      — fit amplitude (map intensity units)
%         .background     — fit baseline
%         .classification — 'substrate' for rank 1 when NPeaks >= 2,
%                           'film' for rank 2, otherwise 'unknown'
%         .fit_angle      — full surfaceFit result struct (angle-space)
%         .fit_Q          — full surfaceFit result struct (Q-space; empty
%                           if Qx/Qz absent)
%     .nPeaksFound : number of peaks that passed the threshold
%     .intensityUnit : pass-through from input
%     .usedQSpace   : true when Q-space fits were performed
%
%   Examples
%     data   = parser.importXRDML('rsm.xrdml', Intensity='cps');
%     map    = parser.computeQSpace(data.metadata.parserSpecific.map2D);
%     result = fitting.rsmAnalyze(map, NPeaks=2, Verbose=true);
%     strain = fitting.rsmStrain(result.peaks(1).centre_Q, ...
%                                result.peaks(2).centre_Q);
%
%   Method
%   ─────────────────────────────
%   1. Gaussian-smooth the intensity matrix (separable 1D convolution along
%      each axis) to suppress single-pixel noise before peak finding.
%   2. Find local maxima above `Threshold·max` using a 3×3 neighbourhood
%      comparison, then enforce `MinSeparation` by greedy suppression from
%      brightest down.
%   3. For each accepted peak, extract a `FitWindow`-sized patch centred on
%      the maximum and fit the chosen 2D model with fitting.surfaceFit.
%      The same patch (same indices) is refit against the Q-space grids
%      when available to produce centre and FWHM directly in Å⁻¹.
%   4. FWHM is computed from the fit: Gaussian σ → FWHM = 2√(2 ln 2)·σ;
%      Lorentzian w → FWHM = 2w; Pseudo-Voigt → η·2w + (1-η)·2√(2 ln 2)·σ.
%
%   See also parser.importXRDML, parser.computeQSpace,
%            fitting.surfaceFit, fitting.rsmStrain.

    arguments
        map (1,1) struct
        options.NPeaks        (1,1) double {mustBePositive, mustBeInteger} = 2
        options.Threshold     (1,1) double {mustBeNonnegative} = 0.01
        options.SmoothSigma   (1,1) double {mustBePositive} = 1.5
        options.MinSeparation (1,1) double {mustBePositive, mustBeInteger} = 4
        options.FitWindow     (1,1) double {mustBePositive, mustBeInteger} = 6
        options.FitModel      (1,:) char {mustBeMember(options.FitModel, ...
            {'2D Gaussian', '2D Lorentzian', '2D Pseudo-Voigt'})} = '2D Gaussian'
        options.Verbose       (1,1) logical = false
    end

    % ── Validate input map ───────────────────────────────────────────
    required = {'intensity', 'axis1', 'axis2'};
    for k = 1:numel(required)
        if ~isfield(map, required{k})
            error('fitting:rsmAnalyze:missingField', ...
                'Input map is missing required field "%s".', required{k});
        end
    end
    I      = double(map.intensity);
    ax1    = map.axis1(:);
    ax2    = map.axis2(:);
    [N, M] = size(I);
    assert(numel(ax1) == N && numel(ax2) == M, ...
        'fitting:rsmAnalyze:sizeMismatch', ...
        'axis1/axis2 lengths must match intensity dimensions [%d x %d].', N, M);

    hasQ = isfield(map, 'Qx') && isfield(map, 'Qz') ...
           && ~isempty(map.Qx) && ~isempty(map.Qz);
    intensityUnit = 'cps';
    if isfield(map, 'intensityUnit') && ~isempty(map.intensityUnit)
        intensityUnit = map.intensityUnit;
    end

    % ── Smooth to suppress single-pixel noise ───────────────────────
    Is = gaussianSmooth2D(I, options.SmoothSigma);

    % ── Detect local maxima above threshold, with min-separation ────
    thresh = options.Threshold * max(Is(:));
    [rowIdx, colIdx, peakI] = findLocalMaxima(Is, thresh, options.MinSeparation);
    nFound = numel(rowIdx);
    if nFound == 0
        result = emptyResult(intensityUnit, hasQ);
        if options.Verbose
            fprintf('[rsmAnalyze] no peaks above threshold\n');
        end
        return;
    end
    nKeep = min(nFound, options.NPeaks);
    rowIdx = rowIdx(1:nKeep);
    colIdx = colIdx(1:nKeep);
    peakI  = peakI(1:nKeep);

    % ── Fit each accepted peak ──────────────────────────────────────
    catalog    = fitting.surfaceModels();
    modelEntry = catalog(strcmp({catalog.name}, options.FitModel));

    peaks = repmat(emptyPeak(hasQ), 0, 1);
    for k = 1:nKeep
        patch = makePatch(I, rowIdx(k), colIdx(k), options.FitWindow);
        if isempty(patch.rows)
            continue;  % patch shrank to zero near a corner
        end

        % Angle-space fit — always available
        % meshgrid(x,y): 1st output tiles x along rows, 2nd output tiles y along cols.
        % ax2 = 2θ (column axis of I); ax1 = ω (row axis of I).
        [tthGrid, omegaGrid] = meshgrid(ax2(patch.cols), ax1(patch.rows));
        zPatch = I(patch.rows, patch.cols);
        fitA = tryFit(modelEntry, tthGrid, omegaGrid, zPatch);  % x=2θ, y=ω
        if isempty(fitA)
            continue;
        end
        [cx_ang, cy_ang, fwx_ang, fwy_ang, amp, bg] = unpackFit(fitA, options.FitModel);
        % cx_ang -> 2θ centre, cy_ang -> ω centre (we passed x=2θ, y=ω)
        centreAngle = [cy_ang, cx_ang];        % [ω, 2θ]
        fwhmAngle   = [fwy_ang, fwx_ang];      % [ω-FWHM, 2θ-FWHM]

        % Q-space fit (optional)
        if hasQ
            QxP = map.Qx(patch.rows, patch.cols);
            QzP = map.Qz(patch.rows, patch.cols);
            fitQ = tryFit(modelEntry, QxP, QzP, zPatch);
            if ~isempty(fitQ)
                [cQx, cQz, fwQx, fwQz, ~, ~] = unpackFit(fitQ, options.FitModel);
                centreQ = [cQx, cQz];
                fwhmQ   = [fwQx, fwQz];
            else
                centreQ = [NaN, NaN];
                fwhmQ   = [NaN, NaN];
                fitQ    = struct([]);
            end
        else
            centreQ = [NaN, NaN];
            fwhmQ   = [NaN, NaN];
            fitQ    = struct([]);
        end

        entry                = emptyPeak(hasQ);
        entry.rank           = numel(peaks) + 1;
        entry.centre_angle   = centreAngle;
        entry.centre_Q       = centreQ;
        entry.fwhm_angle     = fwhmAngle;
        entry.fwhm_Q         = fwhmQ;
        entry.amplitude      = amp;
        entry.background     = bg;
        entry.classification = classifyRank(entry.rank, options.NPeaks);
        entry.fit_angle      = fitA;
        entry.fit_Q          = fitQ;
        peaks(end+1, 1)      = entry; %#ok<AGROW>
    end

    result.peaks         = peaks;
    result.nPeaksFound   = numel(peaks);
    result.intensityUnit = intensityUnit;
    result.usedQSpace    = hasQ;

    if options.Verbose
        printPeakTable(result);
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function Is = gaussianSmooth2D(I, sigma)
%GAUSSIANSMOOTH2D  Separable 1D Gaussian smoothing (no toolbox).
    r = max(1, ceil(3*sigma));
    x = -r:r;
    k = exp(-x.^2 / (2*sigma^2));
    k = k ./ sum(k);
    % Two 1D convolutions (rows then cols) — 'same' keeps size.
    Is = conv2(k, k, I, 'same');
end

function [rowIdx, colIdx, peakI] = findLocalMaxima(Is, thresh, minSep)
%FINDLOCALMAXIMA  3×3 non-max suppression + greedy min-separation filter.
    [N, M] = size(Is);
    rowIdx = zeros(0, 1);
    colIdx = zeros(0, 1);
    peakI  = zeros(0, 1);

    % Interior cells only (skip 1-pixel border — matches typical RSM framing)
    for r = 2:N-1
        for c = 2:M-1
            v = Is(r, c);
            if v < thresh, continue; end
            nb = Is(r-1:r+1, c-1:c+1);
            if v >= max(nb(:))  % >= so plateaus still give one peak
                rowIdx(end+1,1) = r; %#ok<AGROW>
                colIdx(end+1,1) = c; %#ok<AGROW>
                peakI(end+1,1)  = v; %#ok<AGROW>
            end
        end
    end

    % Sort brightest first
    [peakI, ord] = sort(peakI, 'descend');
    rowIdx = rowIdx(ord);
    colIdx = colIdx(ord);

    % Greedy min-separation: keep brightest, suppress anything within minSep
    keep = true(numel(peakI), 1);
    for i = 1:numel(peakI)
        if ~keep(i), continue; end
        for j = i+1:numel(peakI)
            if ~keep(j), continue; end
            dr = rowIdx(i) - rowIdx(j);
            dc = colIdx(i) - colIdx(j);
            if (dr*dr + dc*dc) < minSep*minSep
                keep(j) = false;
            end
        end
    end
    rowIdx = rowIdx(keep);
    colIdx = colIdx(keep);
    peakI  = peakI(keep);
end

function patch = makePatch(I, rowC, colC, halfWin)
%MAKEPATCH  Build row/col index vectors for a square window around (rowC, colC).
    [N, M] = size(I);
    patch.rows = max(1, rowC-halfWin) : min(N, rowC+halfWin);
    patch.cols = max(1, colC-halfWin) : min(M, colC+halfWin);
end

function fitR = tryFit(modelEntry, xGrid, yGrid, zGrid)
%TRYFIT  Call surfaceFit with a sensible initial guess and patch-scoped
%        bounds; return [] on failure.
    x = xGrid(:);
    y = yGrid(:);
    z = zGrid(:);

    % Initial guess from patch statistics
    [amp, idx] = max(z);
    bg         = min(z);
    A0         = max(amp - bg, eps);
    x0         = x(idx);
    y0         = y(idx);

    xMin = min(x); xMax = max(x); xRange = max(xMax - xMin, eps);
    yMin = min(y); yMax = max(y); yRange = max(yMax - yMin, eps);

    % Width guess: ~1/6 of patch span (narrow enough to lock the centre,
    % wide enough to let fminsearch broaden)
    sx0 = xRange / 6;
    sy0 = yRange / 6;

    % Bounds: keep the fit inside the patch so widths can't run to infinity
    sxMin = xRange / 100;  sxMax = 2 * xRange;
    syMin = yRange / 100;  syMax = 2 * yRange;
    zSpan = max(max(z) - min(z), eps);

    switch modelEntry.name
        case {'2D Gaussian', '2D Lorentzian'}
            % p = [A, x0, sx/wx, y0, sy/wy, z0]
            p0 = [A0, x0, sx0, y0, sy0, bg];
            lb = [0,        xMin, sxMin, yMin, syMin, bg - 10*zSpan];
            ub = [10*A0,    xMax, sxMax, yMax, syMax, bg + 10*zSpan];
        case '2D Pseudo-Voigt'
            % p = [A, x0, wx, y0, wy, z0, eta]
            p0 = [A0, x0, sx0, y0, sy0, bg, 0.5];
            lb = [0,        xMin, sxMin, yMin, syMin, bg - 10*zSpan, 0];
            ub = [10*A0,    xMax, sxMax, yMax, syMax, bg + 10*zSpan, 1];
        otherwise
            p0 = []; lb = []; ub = [];
    end

    try
        fitR = fitting.surfaceFit(x, y, z, modelEntry.name, ...
            InitGuess=p0, LowerBound=lb, UpperBound=ub);
    catch
        fitR = [];
    end
end

function [cx, cy, fwx, fwy, amp, bg] = unpackFit(fitR, modelName)
%UNPACKFIT  Pull centre, FWHM, amplitude, baseline from a surfaceFit result.
    p = fitR.params;
    switch modelName
        case '2D Gaussian'
            % p = [A, x0, sx, y0, sy, z0]
            amp = p(1);  cx = p(2);  sx = abs(p(3));
            cy  = p(4);  sy = abs(p(5));  bg = p(6);
            k   = 2*sqrt(2*log(2));   % σ → FWHM
            fwx = k*sx;
            fwy = k*sy;
        case '2D Lorentzian'
            % p = [A, x0, wx, y0, wy, z0]
            amp = p(1);  cx = p(2);  wx = abs(p(3));
            cy  = p(4);  wy = abs(p(5));  bg = p(6);
            fwx = 2*wx;
            fwy = 2*wy;
        case '2D Pseudo-Voigt'
            % p = [A, x0, wx, y0, wy, z0, eta]
            amp = p(1);  cx = p(2);  wx = abs(p(3));
            cy  = p(4);  wy = abs(p(5));  bg = p(6);
            eta = min(max(p(7), 0), 1);
            k   = 2*sqrt(2*log(2));
            fwx = eta*(2*wx) + (1-eta)*(k*wx);
            fwy = eta*(2*wy) + (1-eta)*(k*wy);
        otherwise
            cx = NaN; cy = NaN; fwx = NaN; fwy = NaN; amp = NaN; bg = NaN;
    end
end

function tag = classifyRank(rank, nRequested)
%CLASSIFYRANK  Label the brightest peak as substrate, next as film.
    if nRequested >= 2 && rank == 1
        tag = 'substrate';
    elseif nRequested >= 2 && rank == 2
        tag = 'film';
    else
        tag = 'unknown';
    end
end

function r = emptyResult(unit, hasQ)
    r.peaks         = repmat(emptyPeak(hasQ), 0, 1);
    r.nPeaksFound   = 0;
    r.intensityUnit = unit;
    r.usedQSpace    = hasQ;
end

function p = emptyPeak(hasQ)
    p.rank           = 0;
    p.centre_angle   = [NaN NaN];
    p.centre_Q       = [NaN NaN];
    p.fwhm_angle     = [NaN NaN];
    p.fwhm_Q         = [NaN NaN];
    p.amplitude      = NaN;
    p.background     = NaN;
    p.classification = 'unknown';
    p.fit_angle      = struct([]);
    if hasQ
        p.fit_Q = struct([]);
    else
        p.fit_Q = struct([]);
    end
end

function printPeakTable(result)
    fprintf('\n[rsmAnalyze] %d peak(s) found\n', result.nPeaksFound);
    fprintf('  %-4s %-10s %9s %9s %9s %9s %10s\n', ...
        'rank', 'class', 'ω (°)', '2θ (°)', 'Δω (°)', 'Δ2θ (°)', 'amp');
    for k = 1:numel(result.peaks)
        pk = result.peaks(k);
        fprintf('  %-4d %-10s %9.4f %9.4f %9.4f %9.4f %10.2f\n', ...
            pk.rank, pk.classification, ...
            pk.centre_angle(1), pk.centre_angle(2), ...
            pk.fwhm_angle(1),   pk.fwhm_angle(2), ...
            pk.amplitude);
    end
    if result.usedQSpace
        fprintf('\n  %-4s %-10s %9s %9s %9s %9s\n', ...
            'rank', 'class', 'Qx (Å⁻¹)', 'Qz (Å⁻¹)', 'ΔQx', 'ΔQz');
        for k = 1:numel(result.peaks)
            pk = result.peaks(k);
            fprintf('  %-4d %-10s %9.5f %9.5f %9.5f %9.5f\n', ...
                pk.rank, pk.classification, ...
                pk.centre_Q(1), pk.centre_Q(2), ...
                pk.fwhm_Q(1),   pk.fwhm_Q(2));
        end
    end
end
