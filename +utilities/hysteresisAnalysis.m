function result = hysteresisAnalysis(H, M, options)
%HYSTERESISANALYSIS  Extract parameters from a magnetic hysteresis loop.
%
%   result = utilities.hysteresisAnalysis(H, M)
%   result = utilities.hysteresisAnalysis(H, M, SaturationFraction=0.8)
%
%   Automatically detects ascending/descending branches, then extracts:
%   coercive field (Hc), remanent moment (Mr), saturation moment (Ms),
%   squareness ratio, switching field distribution (SFD), and loop area.
%
%   Inputs:
%       H — [N×1] magnetic field vector (Oe or A/m)
%       M — [N×1] moment vector (emu or Am²)
%
%   Options:
%       SaturationFraction — fraction of max|H| for Ms averaging (default: 0.8)
%       PreSmooth          — smoothing half-window (0 = none, default: 0)
%       VirginDetect       — auto-detect virgin curve (default: true)
%
%   Output (struct):
%       .Hc         — [1×2] coercive fields [ascending, descending]
%       .HcMean     — average |Hc|
%       .Mr         — [1×2] remanent moments [ascending, descending]
%       .MrMean     — average |Mr|
%       .Ms         — [1×2] saturation moments [positive, negative]
%       .MsMean     — average |Ms|
%       .squareness — Mr/Ms ratio
%       .loopArea   — hysteresis loss (integral)
%       .SFD        — struct: .peakH, .peakdMdH, .fwhm
%       .ascending  — struct: .H, .M
%       .descending — struct: .H, .M
%       .virgin     — struct: .H, .M (empty if none)
%       .dMdH_asc   — dM/dH for ascending branch
%       .dMdH_desc  — dM/dH for descending branch
%       .warnings   — cell array of diagnostic strings
%
%   Example:
%       data = parser.importQDVSM('MvsH.dat', XAxis='field', YAxis='moment');
%       r = utilities.hysteresisAnalysis(data.time, data.values(:,1));
%       fprintf('Hc = %.1f Oe, Ms = %.3e emu\n', r.HcMean, r.MsMean);

arguments
    H       (:,1) double
    M       (:,1) double
    options.SaturationFraction (1,1) double = 0.8
    options.PreSmooth          (1,1) double = 0
    options.VirginDetect       (1,1) logical = true
end

N = numel(H);
warnings = {};

if N < 20
    error('utilities:hysteresisAnalysis:tooFew', 'Need at least 20 data points.');
end

% ════════════════════════════════════════════════════════════════════════
% 1. Optional pre-smoothing
% ════════════════════════════════════════════════════════════════════════

if options.PreSmooth > 0
    M = utilities.smoothData(H, M, options.PreSmooth, 'Method', 'savitzky-golay');
end

% ════════════════════════════════════════════════════════════════════════
% 2. Branch detection — find reversal points
% ════════════════════════════════════════════════════════════════════════

dH = diff(H);
% Ignore tiny fluctuations: require sign change to persist for >3 points
signDH = sign(dH);
signDH(signDH == 0) = 1;  % treat zero steps as continuation

% Find reversal indices (where sign of dH changes)
reversals = find(diff(signDH) ~= 0) + 1;

% Build segments between reversals
segStarts = [1; reversals(:)];
segEnds   = [reversals(:) - 1; N];

% Compute H-range of each segment
nSegs = numel(segStarts);
segRanges = zeros(nSegs, 1);
segDirs   = zeros(nSegs, 1);  % +1 = ascending, -1 = descending
for si = 1:nSegs
    s = segStarts(si); e = segEnds(si);
    if e > s
        segRanges(si) = H(e) - H(s);
        segDirs(si) = sign(segRanges(si));
    end
end

% Find the two longest monotonic segments as primary branches
ascSegs  = find(segDirs > 0);
descSegs = find(segDirs < 0);

% Virgin curve detection
virgin = struct('H', [], 'M', []);
if options.VirginDetect && ~isempty(ascSegs)
    firstSeg = ascSegs(1);
    s1 = segStarts(firstSeg); e1 = segEnds(firstSeg);
    if abs(H(s1)) < 0.1 * max(abs(H)) && firstSeg == 1
        virgin.H = H(s1:e1);
        virgin.M = M(s1:e1);
        ascSegs(1) = [];  % exclude from branch candidates
    end
end

% Select primary ascending branch (widest H-range)
if ~isempty(ascSegs)
    [~, bestAsc] = max(abs(segRanges(ascSegs)));
    ascIdx = ascSegs(bestAsc);
    ascS = segStarts(ascIdx); ascE = segEnds(ascIdx);
    ascending = struct('H', H(ascS:ascE), 'M', M(ascS:ascE));
else
    ascending = struct('H', [], 'M', []);
    warnings{end+1} = 'No ascending branch detected';
end

% Select primary descending branch (widest H-range)
if ~isempty(descSegs)
    [~, bestDesc] = max(abs(segRanges(descSegs)));
    descIdx = descSegs(bestDesc);
    descS = segStarts(descIdx); descE = segEnds(descIdx);
    descending = struct('H', H(descS:descE), 'M', M(descS:descE));
else
    descending = struct('H', [], 'M', []);
    warnings{end+1} = 'No descending branch detected';
end

% ════════════════════════════════════════════════════════════════════════
% 3. Coercive field Hc (M crosses zero)
% ════════════════════════════════════════════════════════════════════════

Hc = [NaN NaN];
if ~isempty(ascending.H)
    Hc(1) = interpCrossing(ascending.H, ascending.M, 0, 'M');
    if isnan(Hc(1)), warnings{end+1} = 'No M=0 crossing on ascending branch'; end
end
if ~isempty(descending.H)
    Hc(2) = interpCrossing(descending.H, descending.M, 0, 'M');
    if isnan(Hc(2)), warnings{end+1} = 'No M=0 crossing on descending branch'; end
end
HcMean = mean(abs(Hc), 'omitnan');

% Check asymmetry
if all(isfinite(Hc)) && HcMean > 0
    asymm = abs(abs(Hc(1)) - abs(Hc(2))) / HcMean;
    if asymm > 0.1
        warnings{end+1} = sprintf('Asymmetric loop: |Hc| differ by %.0f%%', asymm*100);
    end
end

% ════════════════════════════════════════════════════════════════════════
% 4. Remanent moment Mr (H crosses zero)
% ════════════════════════════════════════════════════════════════════════

Mr = [NaN NaN];
if ~isempty(ascending.H)
    Mr(1) = interpCrossing(ascending.M, ascending.H, 0, 'H');
    if isnan(Mr(1)), warnings{end+1} = 'No H=0 crossing on ascending branch'; end
end
if ~isempty(descending.H)
    Mr(2) = interpCrossing(descending.M, descending.H, 0, 'H');
    if isnan(Mr(2)), warnings{end+1} = 'No H=0 crossing on descending branch'; end
end
MrMean = mean(abs(Mr), 'omitnan');

% ════════════════════════════════════════════════════════════════════════
% 5. Saturation moment Ms
% ════════════════════════════════════════════════════════════════════════

Hmax = max(abs(H));
satThresh = options.SaturationFraction * Hmax;
Ms = [NaN NaN];

% Positive saturation from descending branch high-field region
if ~isempty(descending.H)
    hiMask = descending.H > satThresh;
    if sum(hiMask) >= 3
        Ms(1) = mean(descending.M(hiMask));
    end
end

% Negative saturation from ascending branch low-field region
if ~isempty(ascending.H)
    loMask = ascending.H < -satThresh;
    if sum(loMask) >= 3
        Ms(2) = mean(ascending.M(loMask));
    end
end

MsMean = mean(abs(Ms), 'omitnan');

% Saturation check
if ~isempty(descending.H) && ~isempty(ascending.H)
    allHiField = abs(H) > satThresh;
    if sum(allHiField) >= 6
        MHi = M(allHiField);
        dMrel = std(MHi) / max(abs(mean(MHi)), eps);
        if dMrel > 0.1
            warnings{end+1} = 'Loop may not be saturated (high-field M still varying)';
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
% 6. Squareness ratio
% ════════════════════════════════════════════════════════════════════════

squareness = MrMean / max(MsMean, eps);
squareness = min(squareness, 1);

% ════════════════════════════════════════════════════════════════════════
% 7. Switching field distribution (dM/dH)
% ════════════════════════════════════════════════════════════════════════

SFD = struct('peakH', NaN, 'peakdMdH', NaN, 'fwhm', NaN);
dMdH_asc = []; dMdH_desc = [];

if ~isempty(ascending.H) && numel(ascending.H) >= 5
    % Ensure strictly monotonic H for gradient — duplicate H gives dx=0 → Inf
    [Hu, iu] = unique(ascending.H, 'stable');
    Mu = ascending.M(iu);
    [Hu, sortIdx] = sort(Hu);
    Mu = Mu(sortIdx);
    if numel(Hu) >= 5
        [dMdH_asc, ~] = utilities.derivative(Hu, Mu, PreSmooth=max(3, options.PreSmooth));
        [pkVal, pkIdx] = max(abs(dMdH_asc)); %#ok<ASGLU>
        SFD.peakH = Hu(pkIdx);
        SFD.peakdMdH = dMdH_asc(pkIdx);
        SFD.fwhm = computeFWHM(Hu, abs(dMdH_asc), pkIdx);
    end
end

if ~isempty(descending.H) && numel(descending.H) >= 5
    [Hud, iud] = unique(descending.H, 'stable');
    Mud = descending.M(iud);
    [Hud, sortIdxD] = sort(Hud);
    Mud = Mud(sortIdxD);
    if numel(Hud) >= 5
        [dMdH_desc, ~] = utilities.derivative(Hud, Mud, PreSmooth=max(3, options.PreSmooth));
    end
end

% ════════════════════════════════════════════════════════════════════════
% 8. Loop area (hysteresis loss)
% ════════════════════════════════════════════════════════════════════════

loopArea = NaN;
if ~isempty(ascending.H) && ~isempty(descending.H)
    % Interpolate both branches onto common H grid
    % Ensure unique, sorted H for interp1
    [Ha_u, ia] = unique(ascending.H, 'stable');
    Ma_u = ascending.M(ia);
    [Ha_u, sortA] = sort(Ha_u);
    Ma_u = Ma_u(sortA);

    [Hd_u, id] = unique(descending.H, 'stable');
    Md_u = descending.M(id);
    [Hd_u, sortD] = sort(Hd_u);
    Md_u = Md_u(sortD);

    Hmin_ov = max(Ha_u(1), Hd_u(1));
    Hmax_ov = min(Ha_u(end), Hd_u(end));
    if Hmax_ov > Hmin_ov && numel(Ha_u) >= 2 && numel(Hd_u) >= 2
        Hgrid = linspace(Hmin_ov, Hmax_ov, 500)';
        M_asc_interp = interp1(Ha_u, Ma_u, Hgrid, 'linear', NaN);
        M_desc_interp = interp1(Hd_u, Md_u, Hgrid, 'linear', NaN);
        valid = ~isnan(M_asc_interp) & ~isnan(M_desc_interp);
        if sum(valid) > 10
            loopArea = abs(trapz(Hgrid(valid), M_desc_interp(valid)) - ...
                          trapz(Hgrid(valid), M_asc_interp(valid)));
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
% 9. Assemble output
% ════════════════════════════════════════════════════════════════════════

result.Hc         = Hc;
result.HcMean     = HcMean;
result.Mr         = Mr;
result.MrMean     = MrMean;
result.Ms         = Ms;
result.MsMean     = MsMean;
result.squareness = squareness;
result.loopArea   = loopArea;
result.SFD        = SFD;
result.ascending  = ascending;
result.descending = descending;
result.virgin     = virgin;
result.dMdH_asc   = dMdH_asc;
result.dMdH_desc  = dMdH_desc;
result.warnings   = warnings;

end

% ════════════════════════════════════════════════════════════════════════
% Local helpers
% ════════════════════════════════════════════════════════════════════════

function val = interpCrossing(x, y, targetY, label)
%INTERPCROSSING  Find x-value where y crosses targetY via linear interpolation.
%   If multiple crossings, pick the one with steepest local slope.
    dy = y - targetY;
    crossings = find(dy(1:end-1) .* dy(2:end) < 0);
    if isempty(crossings)
        val = NaN;
        return;
    end
    % For each crossing, interpolate and compute slope
    xCross = zeros(numel(crossings), 1);
    slopes = zeros(numel(crossings), 1);
    for ci = 1:numel(crossings)
        i = crossings(ci);
        % Linear interpolation
        xCross(ci) = x(i) - dy(i) * (x(i+1) - x(i)) / (dy(i+1) - dy(i));
        slopes(ci) = abs(dy(i+1) - dy(i)) / max(abs(x(i+1) - x(i)), eps);
    end
    % Pick steepest crossing (most physical)
    [~, best] = max(slopes);
    val = xCross(best);
end

function fw = computeFWHM(x, y, peakIdx)
%COMPUTEFWHM  Compute full-width at half-maximum of a peak.
    % Strip non-finite samples so NaN/Inf can't poison comparisons or
    % linear-interp arithmetic.
    finiteMask = isfinite(x) & isfinite(y);
    if ~finiteMask(peakIdx) || nnz(finiteMask) < 3
        fw = NaN;
        return;
    end
    halfMax = y(peakIdx) / 2;
    if ~isfinite(halfMax) || halfMax <= 0
        fw = NaN;
        return;
    end

    % Walk left from peak to find half-max crossing
    xLeft = NaN;
    for i = peakIdx-1:-1:1
        if ~finiteMask(i), continue; end
        if y(i) < halfMax
            denom = y(i+1) - y(i);
            if abs(denom) < eps
                xLeft = x(i);
            else
                frac = (halfMax - y(i)) / denom;
                xLeft = x(i) + frac * (x(i+1) - x(i));
            end
            break;
        end
    end
    % Walk right from peak
    xRight = NaN;
    for i = peakIdx+1:numel(y)
        if ~finiteMask(i), continue; end
        if y(i) < halfMax
            denom = y(i-1) - y(i);
            if abs(denom) < eps
                xRight = x(i);
            else
                frac = (halfMax - y(i)) / denom;
                xRight = x(i) + frac * (x(i-1) - x(i));
            end
            break;
        end
    end

    % Fall back to data extents if a crossing wasn't found on one side —
    % half-width on the side that did resolve, doubled.
    if isnan(xLeft) && isnan(xRight)
        fw = NaN;
    elseif isnan(xLeft)
        fw = 2 * abs(xRight - x(peakIdx));
    elseif isnan(xRight)
        fw = 2 * abs(x(peakIdx) - xLeft);
    else
        fw = abs(xRight - xLeft);
    end
    if ~isfinite(fw)
        fw = NaN;
    end
end
