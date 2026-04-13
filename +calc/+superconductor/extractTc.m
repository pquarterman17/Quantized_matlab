function result = extractTc(temperature, resistance, options)
%EXTRACTTC  Extract superconducting transition temperature from R(T) data.
%
%   Syntax
%   ------
%   result = calc.superconductor.extractTc(T, R)
%   result = calc.superconductor.extractTc(T, R, Method='midpoint')
%   result = calc.superconductor.extractTc(T, R, OnsetFraction=0.9, OffsetFraction=0.1)
%
%   Inputs
%   ------
%   temperature     — temperature vector (K), column or row
%   resistance      — resistance vector (Ohm), same length as temperature
%   Method          — which Tc definition to use: 'midpoint', 'onset',
%                     'derivative', or 'all' (default: 'all')
%   OnsetFraction   — fraction of R_normal that defines onset (default: 0.9)
%   OffsetFraction  — fraction of R_normal that defines offset (default: 0.1)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Tc_midpoint      — T where R = 0.5 * R_normal (K)
%     .Tc_onset         — T where R drops to OnsetFraction * R_normal (K)
%     .Tc_offset        — T where R drops to OffsetFraction * R_normal (K)
%     .Tc_derivative    — T at minimum dR/dT (steepest drop) (K)
%     .transitionWidth  — Tc_onset - Tc_offset (K)
%     .R_normal         — average resistance in the normal state above Tc (Ohm)
%     .RRR              — residual resistance ratio R(300K)/R(Tc_onset);
%                         NaN when 300 K data is not present in the input
%
%   Notes
%   -----
%   Data should span from below the transition (superconducting state) to
%   above it (normal state).  The function sorts by temperature before
%   processing.  Smoothing is applied to dR/dT to suppress noise artefacts.
%
%   Examples
%   --------
%   T = linspace(5, 15, 200)';
%   R = 1 ./ (1 + exp(-2*(T - 9.2)));          % synthetic sigmoid
%   result = calc.superconductor.extractTc(T, R);
%   fprintf('Tc (midpoint) = %.3f K\n', result.Tc_midpoint);
%
%   result = calc.superconductor.extractTc(T, R, Method='onset');

% ════════════════════════════════════════════════════════════════════

arguments
    temperature     (:,1) double
    resistance      (:,1) double
    options.Method          (1,:) char {mustBeMember(options.Method, ...
                                {'midpoint','onset','derivative','all'})} = 'all'
    options.OnsetFraction   (1,1) double = 0.9
    options.OffsetFraction  (1,1) double = 0.1
end

% ── Validate and sort ───────────────────────────────────────────────
if numel(temperature) ~= numel(resistance)
    error('calc:superconductor:extractTc:sizeMismatch', ...
          'temperature and resistance must have the same number of elements.');
end
if numel(temperature) < 5
    error('calc:superconductor:extractTc:tooFewPoints', ...
          'At least 5 data points are required.');
end

[T, idx] = sort(temperature(:));
R        = resistance(idx);

% ── Determine R_normal ──────────────────────────────────────────────
% R_normal is the mean resistance in the flat region at the top of the
% temperature range.  Find where |dR/dT| is small relative to the peak
% derivative magnitude, then average R in that region.
R_normal = estimateRNormal(T, R);

% ── Fraction thresholds ─────────────────────────────────────────────
R_mid    = 0.5                       * R_normal;
R_onset  = options.OnsetFraction     * R_normal;
R_offset = options.OffsetFraction    * R_normal;

% ── Extract each Tc via interpolation ──────────────────────────────
method = options.Method;
computeAll = strcmp(method, 'all');

Tc_mid  = NaN;
Tc_on   = NaN;
Tc_off  = NaN;
Tc_deriv = NaN;

if computeAll || strcmp(method, 'midpoint')
    Tc_mid = interpolateCrossing(T, R, R_mid);
end
if computeAll || strcmp(method, 'onset')
    Tc_on = interpolateCrossing(T, R, R_onset);
end
if computeAll || strcmp(method, 'offset')
    % re-use onset path via generic fraction
    Tc_off = interpolateCrossing(T, R, R_offset);
end
if computeAll || strcmp(method, 'derivative')
    Tc_deriv = derivativeTc(T, R);
end

% When 'onset' is needed for transitionWidth but method='midpoint', etc.
% always compute onset/offset for transitionWidth when method='all'
if strcmp(method, 'all')
    % already computed above
else
    % still need offset for width if onset was computed
    if strcmp(method, 'onset')
        Tc_off = interpolateCrossing(T, R, R_offset);
    end
end

transitionWidth = Tc_on - Tc_off;   % NaN when either is NaN

% ── RRR ────────────────────────────────────────────────────────────
% R(300 K) / R(Tc_onset).  Only defined when 300 K is in the data range.
RRR = NaN;
if ~isnan(Tc_on) && max(T) >= 295
    R_at_300 = interp1(T, R, 300, 'linear', 'extrap');
    R_at_on  = interp1(T, R, Tc_on, 'linear', NaN);
    if ~isnan(R_at_on) && R_at_on > 0
        RRR = R_at_300 / R_at_on;
    end
end

% ── Assemble output ─────────────────────────────────────────────────
result.Tc_midpoint     = Tc_mid;
result.Tc_onset        = Tc_on;
result.Tc_offset       = Tc_off;
result.Tc_derivative   = Tc_deriv;
result.transitionWidth = transitionWidth;
result.R_normal        = R_normal;
result.RRR             = RRR;
end

% ════════════════════════════════════════════════════════════════════

function Rn = estimateRNormal(T, R)
%ESTIMATERNMOST  Find mean R in the flat normal-state region above Tc.
%   Strategy: compute dR/dT, find where |dR/dT| is < 20% of the peak
%   |dR/dT|, restrict to the upper half of the temperature range, and
%   average those R values.  Falls back to the top 20% of points if
%   the heuristic finds fewer than 3 points.

dRdT   = gradient(R, T);
peakD  = max(abs(dRdT));

if peakD == 0
    % Flat curve — R_normal is just the mean
    Rn = mean(R);
    return;
end

% Upper half of temperature range
T_mid   = (T(1) + T(end)) / 2;
inUpper = T > T_mid;

flatMask = (abs(dRdT) < 0.20 * peakD) & inUpper;

if sum(flatMask) >= 3
    Rn = mean(R(flatMask));
else
    % Fallback: top 20% of points by temperature
    nTop = max(3, round(0.20 * numel(T)));
    Rn   = mean(R(end - nTop + 1 : end));
end
end

% ════════════════════════════════════════════════════════════════════

function Tc = interpolateCrossing(T, R, Rlevel)
%INTERPOLATECROSSING  Find the temperature at which R crosses Rlevel.
%   Scans from high T to low T (descending through the transition) and
%   returns the first crossing via linear interpolation.  Returns NaN
%   if the level is never crossed.

% Scan top-to-bottom for the crossing: R drops from R_normal toward zero
for k = numel(T)-1 : -1 : 1
    R_hi = R(k+1);
    R_lo = R(k);
    T_hi = T(k+1);
    T_lo = T(k);
    % Crossing: Rlevel is between R_lo and R_hi
    if (R_hi >= Rlevel && Rlevel >= R_lo) || ...
       (R_hi <= Rlevel && Rlevel <= R_lo)
        % Linear interpolation
        dR = R_hi - R_lo;
        if abs(dR) < eps
            Tc = T_lo;
        else
            Tc = T_lo + (Rlevel - R_lo) / dR * (T_hi - T_lo);
        end
        return;
    end
end
Tc = NaN;
end

% ════════════════════════════════════════════════════════════════════

function Tc = derivativeTc(T, R)
%DERIVATIVETC  Tc at the extremum of dR/dT (steepest slope in resistance).
%   Works for both warming (dR/dT > 0) and cooling (dR/dT < 0) measurements
%   by finding the maximum of |dR/dT| within the transitional region.
%   Applies a smoothing pass (moving average) before differentiating to
%   reduce noise sensitivity.

if numel(R) < 5
    Tc = NaN;
    return;
end

% Smooth with a simple moving average (window = min(5, ~5% of N))
winLen = max(3, min(5, round(0.05 * numel(R))));
if mod(winLen, 2) == 0
    winLen = winLen + 1;   % make odd
end
R_sm = movmean(R, winLen);

dRdT = gradient(R_sm, T);

% Restrict search to the transitional region: exclude the top and
% bottom 15% of temperatures to avoid edge noise.
n      = numel(T);
i_lo   = max(1, round(0.15 * n));
i_hi   = min(n, round(0.85 * n));

% Use |dR/dT| — works for both warming and cooling sweeps.
% The peak of |dR/dT| is the steepest part of the transition.
[~, k] = max(abs(dRdT(i_lo:i_hi)));
k      = k + i_lo - 1;
Tc     = T(k);
end
