function result = bcsGap(temperature, gapOrPenetrationDepth, options)
%BCSGAP  Fit superconducting gap or penetration depth to BCS theory.
%
%   Syntax
%   ------
%   result = calc.superconductor.bcsGap(T, Delta)
%   result = calc.superconductor.bcsGap(T, Delta, Tc=9.25)
%   result = calc.superconductor.bcsGap(T, lambda, InputType='penetration_depth')
%
%   Inputs
%   ------
%   temperature            — column vector of temperatures (K), must include
%                            points both below and at/near Tc
%   gapOrPenetrationDepth  — measured quantity at each temperature:
%                            Delta(T) in meV (InputType='gap', default) or
%                            lambda(T) in nm (InputType='penetration_depth')
%
%   Options
%   -------
%   Tc         — critical temperature (K); NaN = auto-detect from where the
%                gap first reaches zero (or lambda diverges)
%   Delta0     — zero-temperature gap (meV); NaN = fitted from data
%   InputType  — 'gap' (default) or 'penetration_depth'
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Tc          — critical temperature used (K)
%     .Delta0      — zero-temperature gap (meV)
%     .ratio       — 2*Delta0 / (kB * Tc) in eV/eV; BCS weak-coupling = 3.528
%     .fitCurve    — struct with .T and .Delta (or .lambda) on a fine grid
%
%   Physics
%   -------
%   Gap equation (Mühlschlegel / approximate BCS):
%     Delta(T) / Delta(0) ≈ tanh( 1.74 * sqrt(Tc/T - 1) )  for T < Tc
%                         = 0                               for T >= Tc
%
%   Penetration depth (two-fluid approximation):
%     1/lambda(T)^2 ∝ 1 - (T/Tc)^4   (widely used empirical form)
%     lambda(T) = lambda(0) / sqrt(1 - (T/Tc)^4)
%
%   BCS ratio: 2*Delta0 / (kB*Tc)
%     Weak-coupling BCS value: 3.528
%     Strongly-coupled (e.g., Pb): ~4.5
%
%   Examples
%   --------
%   % Synthetic Nb-like gap data
%   Tc = 9.25;  Delta0 = 1.55;   % meV (2Delta0/(kBTc) ≈ 3.53)
%   T = linspace(1, Tc, 80)';
%   kB = 8.617e-5 * 1e3;  % meV/K
%   D = Delta0 * tanh(1.74 * sqrt(max(Tc./T - 1, 0)));
%   result = calc.superconductor.bcsGap(T, D, Tc=Tc);
%   fprintf('2Delta0/(kB*Tc) = %.3f\n', result.ratio);

% ════════════════════════════════════════════════════════════════════════
arguments
    temperature           (:,1) double
    gapOrPenetrationDepth (:,1) double
    options.Tc    (1,1) double = NaN
    options.Delta0 (1,1) double = NaN
    options.InputType (1,:) char {mustBeMember(options.InputType, ...
        {'gap','penetration_depth'})} = 'gap'
end

% ════════════════════════════════════════════════════════════════════════
% Physical constants
% ════════════════════════════════════════════════════════════════════════
kB_eV  = 8.617333e-5;   % eV/K
kB_meV = kB_eV * 1e3;   % meV/K

% ════════════════════════════════════════════════════════════════════════
% Validate inputs
% ════════════════════════════════════════════════════════════════════════
if numel(temperature) ~= numel(gapOrPenetrationDepth)
    error('calc:superconductor:bcsGap:sizeMismatch', ...
        'temperature and gapOrPenetrationDepth must have the same length.');
end
if numel(temperature) < 4
    error('calc:superconductor:bcsGap:tooFewPoints', ...
        'At least 4 data points are required.');
end

[T, sortIdx] = sort(temperature(:));
y = gapOrPenetrationDepth(sortIdx);

% ════════════════════════════════════════════════════════════════════════
% Determine Tc
% ════════════════════════════════════════════════════════════════════════
if isnan(options.Tc)
    Tc = estimateTc(T, y, options.InputType);
else
    Tc = options.Tc;
end

if isnan(Tc) || Tc <= 0
    error('calc:superconductor:bcsGap:badTc', ...
        'Could not determine Tc. Provide Tc explicitly.');
end

% ════════════════════════════════════════════════════════════════════════
% Determine Delta0
% ════════════════════════════════════════════════════════════════════════
if strcmp(options.InputType, 'gap')
    % Delta0: user-supplied or estimated from low-T data or fit
    if ~isnan(options.Delta0)
        Delta0 = options.Delta0;
    else
        Delta0 = estimateDelta0Gap(T, y, Tc);
    end

    % Build fine-grid fit curve (gap vs T)
    Tfine  = linspace(max(min(T), 0.01), Tc * 1.05, 400)';
    Dfine  = bcsGapModel(Tfine, Delta0, Tc);

    fitCurve.T     = Tfine;
    fitCurve.Delta = Dfine;
else
    % Penetration depth mode: lambda(T) = lambda0 / sqrt(1 - (T/Tc)^4)
    % Estimate lambda0 from the lowest-temperature point(s)
    subTc  = T < Tc;
    if ~any(subTc)
        error('calc:superconductor:bcsGap:noSubTcData', ...
            'No data below Tc — cannot fit penetration depth.');
    end
    % lambda0 estimated by projecting each point back via the two-fluid formula
    lam0Estimates = y(subTc) .* sqrt(1 - (T(subTc) ./ Tc).^4);
    lam0Estimates(~isfinite(lam0Estimates)) = [];
    if isempty(lam0Estimates)
        error('calc:superconductor:bcsGap:noFiniteEstimates', ...
            'All lambda0 estimates are non-finite. Check data quality.');
    end
    lambda0 = median(lam0Estimates);

    % Derive equivalent Delta0 from two-fluid model:
    %   lambda(0) relates to Delta via BCS, but here we report ratio
    %   using the gap implied by 2*Delta0/(kB*Tc) = 3.528 as reference.
    % We can only compute the ratio if Delta0 is known; for penetration depth,
    % we just report the ratio as the nominal BCS value (it is not fitted).
    Delta0 = NaN;  % not directly measurable from lambda(T) alone

    Tfine  = linspace(max(min(T), 0.01), Tc * 0.999, 400)';
    lfine  = lambda0 ./ sqrt(max(1 - (Tfine ./ Tc).^4, 0));

    fitCurve.T      = Tfine;
    fitCurve.lambda = lfine;
end

% ════════════════════════════════════════════════════════════════════════
% BCS ratio: 2*Delta0 / (kB * Tc)
% ════════════════════════════════════════════════════════════════════════
if ~isnan(Delta0)
    ratio = 2 * Delta0 / (kB_meV * Tc);   % Delta0 in meV, kB_meV in meV/K
else
    ratio = NaN;
end

% ════════════════════════════════════════════════════════════════════════
% Output
% ════════════════════════════════════════════════════════════════════════
result.Tc       = Tc;
result.Delta0   = Delta0;
result.ratio    = ratio;
result.fitCurve = fitCurve;

end

% ════════════════════════════════════════════════════════════════════════
% Local: BCS gap model (Mühlschlegel approximation)
% ════════════════════════════════════════════════════════════════════════
function D = bcsGapModel(T, Delta0, Tc)
%BCSGAPMODEL  Delta(T) = Delta0 * tanh(1.74*sqrt(Tc/T - 1)) for T < Tc.
%   Returns 0 for T >= Tc.
    T    = T(:);
    D    = zeros(size(T));
    sub  = T > 0 & T < Tc;
    tRed = T(sub) ./ Tc;
    D(sub) = Delta0 .* tanh(1.74 .* sqrt(max(1 ./ tRed - 1, 0)));
end

% ════════════════════════════════════════════════════════════════════════
% Local: auto-detect Tc from gap data (first zero-crossing from high T)
% ════════════════════════════════════════════════════════════════════════
function Tc = estimateTc(T, y, inputType)
%ESTIMATETC  Find Tc as the temperature where gap→0 or lambda diverges.
    if strcmp(inputType, 'gap')
        % Tc is where Delta(T) drops to near zero; scan from high T
        maxY = max(y);
        threshold = 0.05 * maxY;
        Tc = NaN;
        for k = numel(T):-1:2
            if y(k) <= threshold && y(k-1) > threshold
                % Linear interpolation
                dY = y(k) - y(k-1);
                if abs(dY) > eps
                    Tc = T(k-1) + (threshold - y(k-1)) / dY * (T(k) - T(k-1));
                else
                    Tc = T(k);
                end
                return;
            end
        end
        % Fallback: use max T where y is near zero
        nearZero = y < threshold;
        if any(nearZero)
            Tc = min(T(nearZero));
        end
    else
        % Penetration depth: Tc where lambda diverges — find steepest increase
        dydT = gradient(y, T);
        [~, imax] = max(dydT);
        Tc = T(imax);
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local: estimate Delta0 from gap data
% ════════════════════════════════════════════════════════════════════════
function Delta0 = estimateDelta0Gap(T, y, Tc)
%ESTIMATEDELTA0GAP  Estimate Delta0 from the BCS model fit to gap data.
%   Uses the low-temperature data (T < 0.3*Tc) where tanh→1 so Delta≈Delta0.
%   Falls back to the maximum y value if insufficient low-T data.
    lowT = T < 0.3 * Tc & y > 0;
    if sum(lowT) >= 2
        Delta0 = median(y(lowT));
    else
        % Use the BCS model: back-calculate Delta0 from each data point
        subTc = T > 0 & T < Tc & y > 0;
        if ~any(subTc)
            Delta0 = max(y);
            return;
        end
        tRed = T(subTc) ./ Tc;
        tanhArg = tanh(1.74 .* sqrt(max(1 ./ tRed - 1, 0)));
        tanhArg(tanhArg < 0.01) = NaN;
        d0est = y(subTc) ./ tanhArg;
        d0est(~isfinite(d0est)) = [];
        if isempty(d0est)
            Delta0 = max(y);
        else
            Delta0 = median(d0est);
        end
    end
end
