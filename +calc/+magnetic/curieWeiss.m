function result = curieWeiss(temperature, susceptibility, options)
%CURIEWEISS  Extract Curie-Weiss parameters from χ(T) data via 1/χ vs T fit.
%
%   Syntax:
%     result = calc.magnetic.curieWeiss(temperature, susceptibility)
%     result = calc.magnetic.curieWeiss(temperature, susceptibility, ...
%                 'FitRange', [150 350])
%
%   The Curie-Weiss law: χ = C / (T - θ_CW)
%   Equivalently: 1/χ = T/C - θ_CW/C  (linear in T)
%
%   A linear fit to 1/χ vs T gives:
%     slope     = 1/C
%     intercept = -θ_CW/C
%
%   The effective moment is derived from the Curie constant:
%     μ_eff = sqrt(3 * kB * C / (NA * μB²))   [in Bohr magnetons]
%
%   Sign convention for θ_CW:
%     θ_CW > 0  →  ferromagnetic exchange coupling
%     θ_CW < 0  →  antiferromagnetic exchange coupling
%     θ_CW = 0  →  ideal paramagnet (Curie law)
%
%   Inputs:
%     temperature    — [N×1] temperature vector (K)
%     susceptibility — [N×1] susceptibility χ vector (emu/Oe or SI; must
%                      be positive and in consistent units with Curie C)
%
%   Name-Value Options:
%     FitRange — [Tmin Tmax] temperature window for the linear fit.
%                Empty (default) auto-selects the region above the
%                peak of 1/χ (i.e., the paramagnetic regime).
%
%   Output (struct):
%     .theta_CW  — Weiss temperature (K)
%     .C         — Curie constant (same units as χ·T)
%     .mu_eff    — effective moment (Bohr magnetons) assuming CGS-emu
%                  molar susceptibility (χ in emu/Oe/mol)
%     .fitLine   — [slope, intercept] of the 1/χ vs T linear fit
%     .R2        — coefficient of determination of the linear fit
%     .invChi    — [N×1] computed 1/χ vector (for plotting)
%
%   Notes:
%     μ_eff is only physically meaningful if χ is molar susceptibility
%     (emu/Oe/mol).  For other normalizations, use θ_CW and C directly.
%
%   Examples:
%     % Synthetic paramagnet: C=4, theta=50
%     T   = (100:400)';
%     chi = 4 ./ (T - 50);
%     r   = calc.magnetic.curieWeiss(T, chi, 'FitRange', [150 400]);
%     fprintf('theta_CW = %.1f K, C = %.3f\n', r.theta_CW, r.C);

% ════════════════════════════════════════════════════════════════════════
%  Input validation (arguments block MUST precede executable code)
% ════════════════════════════════════════════════════════════════════════
arguments
    temperature    (:,1) double
    susceptibility (:,1) double
    options.FitRange (1,2) double = [NaN NaN]
end

% ════════════════════════════════════════════════════════════════════════
%  Physical constants (CGS-emu / SI for μ_eff calculation)
%   Standard textbook formula: μ_eff = sqrt(7.9735 * C_CGS)  [μB]
%   where C_CGS is the molar Curie constant in emu·K/(Oe·mol).
%   Derivation: μ_eff = sqrt(3*kB*C_SI/(NA*muB²)) with C_SI = C_CGS*1e-3
% ════════════════════════════════════════════════════════════════════════
kB  = 1.380649e-23;           % Boltzmann constant (J/K)
NA  = 6.02214076e23;          % Avogadro number
muB = 9.2740100783e-24;       % Bohr magneton (J/T)

% ════════════════════════════════════════════════════════════════════════
%  Basic size checks
% ════════════════════════════════════════════════════════════════════════
n = numel(temperature);
if n < 3
    error('calc:magnetic:curieWeiss:tooFewPoints', ...
        'Need at least 3 data points.');
end
if numel(susceptibility) ~= n
    error('calc:magnetic:curieWeiss:sizeMismatch', ...
        'temperature and susceptibility must be the same length.');
end
if any(susceptibility <= 0)
    warning('calc:magnetic:curieWeiss:nonPositiveChi', ...
        'susceptibility contains non-positive values; they will be excluded.');
end

% ════════════════════════════════════════════════════════════════════════
%  Compute 1/χ, excluding non-positive points
% ════════════════════════════════════════════════════════════════════════
valid    = susceptibility > 0;
T_v      = temperature(valid);
invChi   = nan(n, 1);
invChi(valid)  = 1 ./ susceptibility(valid);
invChi_v = invChi(valid);

% ════════════════════════════════════════════════════════════════════════
%  Select fitting range
% ════════════════════════════════════════════════════════════════════════
if all(isnan(options.FitRange))
    % Auto: fit above the temperature at which 1/χ is maximum.
    % In the paramagnetic regime 1/χ increases linearly with T;
    % the maximum of 1/χ in the dataset marks the boundary of the
    % linear regime (for well-behaved data, this is near T_max).
    [~, iMax] = max(invChi_v);
    Tthresh   = T_v(iMax);
    fitMask   = T_v >= Tthresh;
else
    fitMask = T_v >= options.FitRange(1) & T_v <= options.FitRange(2);
end

if sum(fitMask) < 2
    warning('calc:magnetic:curieWeiss:tooFewFitPoints', ...
        'Fit region has fewer than 2 valid points; using all valid data.');
    fitMask = true(numel(T_v), 1);
end

Tfit  = T_v(fitMask);
ICfit = invChi_v(fitMask);

% ════════════════════════════════════════════════════════════════════════
%  Linear fit: 1/χ = (1/C)*T + (-θ/C)
% ════════════════════════════════════════════════════════════════════════
X = [Tfit, ones(numel(Tfit), 1)];
b = X \ ICfit;                  % b(1) = slope = 1/C, b(2) = intercept = -θ/C

slope     = b(1);
intercept = b(2);

% Guard against degenerate fit
if abs(slope) < eps
    error('calc:magnetic:curieWeiss:singularFit', ...
        'Fitted slope is essentially zero — data may not follow Curie-Weiss law.');
end

C        = 1 / slope;
theta_CW = -intercept / slope;

% ════════════════════════════════════════════════════════════════════════
%  R² of the linear fit
% ════════════════════════════════════════════════════════════════════════
ICfit_pred = slope .* Tfit + intercept;
ssTot = sum((ICfit - mean(ICfit)).^2);
ssRes = sum((ICfit - ICfit_pred).^2);
R2    = 1 - ssRes / max(ssTot, eps);

% ════════════════════════════════════════════════════════════════════════
%  Effective moment μ_eff
%   For molar CGS susceptibility (emu/Oe/mol):
%     C_SI = C_CGS * 1e-3   (1 emu/Oe = 1e-3 m³ → SI molar susceptibility)
%     μ_eff = sqrt(3 * kB * C_SI / (NA * μB²))  in units of μB
% ════════════════════════════════════════════════════════════════════════
C_SI   = C * 1e-3;
mu_eff = sqrt(max(3 * kB * C_SI / (NA * muB^2), 0));

% ════════════════════════════════════════════════════════════════════════
%  Output
% ════════════════════════════════════════════════════════════════════════
result.theta_CW = theta_CW;
result.C        = C;
result.mu_eff   = mu_eff;
result.fitLine  = [slope, intercept];
result.R2       = R2;
result.invChi   = invChi;

end
