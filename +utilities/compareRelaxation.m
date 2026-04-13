function result = compareRelaxation(temperature, relaxationTime)
%COMPARERELAXATION  Fit Arrhenius and VFT to tau(T) data and compare models.
%
%   Syntax
%   ------
%   result = utilities.compareRelaxation(T, tau)
%
%   Inputs
%   ------
%   temperature    — [N×1] temperatures in K (must be decreasing or increasing)
%   relaxationTime — [N×1] relaxation times in s (or any consistent unit)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .arrhenius — struct: {tau0, Ea_eV, R2, AIC, BIC}
%     .vft       — struct: {tau0, Ea_eV, T0, R2, AIC, BIC}
%     .preferred  — 'Arrhenius' or 'VFT' based on BIC criterion
%     .deltaAIC  — AIC_Arrhenius - AIC_VFT (positive = VFT preferred)
%     .deltaBIC  — BIC_Arrhenius - BIC_VFT (positive = VFT preferred)
%
%   Physics
%   -------
%   Arrhenius model (2 free params: tau0, Ea):
%     tau = tau0 * exp(Ea / (kB * T))
%     linearised: ln(tau) = ln(tau0) + Ea/(kB) * (1/T)
%
%   Vogel-Fulcher-Tammann (VFT) model (3 free params: tau0, Ea, T0):
%     tau = tau0 * exp(Ea / (kB * (T - T0)))
%
%   VFT reduces to Arrhenius when T0 = 0.
%
%   Model comparison uses AIC and BIC (normal-error form):
%     AIC = n*ln(RSS/n) + 2p
%     BIC = n*ln(RSS/n) + p*ln(n)
%   where p = number of free parameters and RSS = sum of squared residuals
%   in ln(tau) space.
%
%   Notes
%   -----
%   - Fitting is performed in ln(tau) space to handle the exponential dynamic
%     range and give equal weight to all decades.
%   - Arrhenius is fit by ordinary least squares on ln(tau) vs 1/T.
%   - VFT is fit using nonlinear least squares via fminsearch with bounds.
%   - A positive deltaAIC or deltaBIC favours VFT.
%   - The preferred model is determined by BIC (penalises extra parameters
%     more strongly than AIC for typical dataset sizes).
%
%   Examples
%   --------
%   % VFT data: tau0=1e-12 s, Ea=0.3 eV, T0=100 K
%   kB = 8.617e-5;
%   T  = (150:20:400)';
%   T0 = 100; Ea = 0.3; tau0_vft = 1e-12;
%   tau = tau0_vft * exp(Ea ./ (kB * (T - T0)));
%   tau = tau .* (1 + 0.05*randn(size(tau)));
%   r = utilities.compareRelaxation(T, tau);
%   fprintf('Preferred: %s  (deltaBIC=%.2f)\n', r.preferred, r.deltaBIC);

% ════════════════════════════════════════════════════════════════════════
arguments
    temperature    (:,1) double
    relaxationTime (:,1) double
end

% ════════════════════════════════════════════════════════════════════════
% Physical constants
% ════════════════════════════════════════════════════════════════════════
kB = 8.617333e-5;   % eV/K

% ════════════════════════════════════════════════════════════════════════
% Validate
% ════════════════════════════════════════════════════════════════════════
N = numel(temperature);
if N ~= numel(relaxationTime)
    error('utilities:compareRelaxation:sizeMismatch', ...
        'temperature and relaxationTime must have the same length.');
end
if N < 5
    error('utilities:compareRelaxation:tooFewPoints', ...
        'At least 5 data points are required.');
end
if any(relaxationTime <= 0)
    error('utilities:compareRelaxation:badTau', ...
        'All relaxation times must be positive.');
end
if any(temperature <= 0)
    error('utilities:compareRelaxation:badTemperature', ...
        'All temperatures must be positive (K).');
end

% Work in ln(tau) space
lnTau = log(relaxationTime);
invT  = 1 ./ temperature;

% ════════════════════════════════════════════════════════════════════════
% 1. Arrhenius fit — OLS in linearised space
%    ln(tau) = ln(tau0) + (Ea/kB) * (1/T)
%    y = b0 + b1 * x   where x = 1/T
% ════════════════════════════════════════════════════════════════════════
Xarr = [ones(N, 1), invT];
b_arr = Xarr \ lnTau;
lnTau_arr_fit = Xarr * b_arr;

tau0_arr  = exp(b_arr(1));
Ea_arr_eV = b_arr(2) * kB;        % b1 = Ea/(kB·K), Ea_eV = b1 * kB_eV/K

res_arr = lnTau - lnTau_arr_fit;
[arr_metrics, arr_R2] = computeMetrics(lnTau, res_arr, 2);

arrhenius.tau0   = tau0_arr;
arrhenius.Ea_eV  = Ea_arr_eV;
arrhenius.R2     = arr_R2;
arrhenius.AIC    = arr_metrics.aic;
arrhenius.BIC    = arr_metrics.bic;

% ════════════════════════════════════════════════════════════════════════
% 2. VFT fit — nonlinear in 3 params: [lnTau0, Ea_eV, T0]
%    ln(tau) = lnTau0 + Ea / (kB * (T - T0))
% ════════════════════════════════════════════════════════════════════════
vftModel = @(p, T) p(1) + p(2) ./ (kB .* max(T - p(3), 1));
% (guard T0 < T with max(...,1) inside optimisation only)

% Initial guess from Arrhenius solution
T0_init = max(0, min(temperature) * 0.5);
p0_vft  = [b_arr(1), Ea_arr_eV, T0_init];

% Objective: sum of squared residuals in ln(tau) space
% Constraint: T0 must be < min(T) to keep the model physical
Tmin = min(temperature);
objFcn = @(p) vftResiduals(p, temperature, lnTau, kB, Tmin);

opts = optimset('fminsearch');
opts.MaxIter    = 20000;
opts.MaxFunEvals = 50000;
opts.TolFun     = 1e-12;
opts.TolX       = 1e-10;
opts.Display    = 'off';

[p_vft, ~] = fminsearch(objFcn, p0_vft, opts);

% Enforce T0 < Tmin after optimisation
p_vft(3) = min(p_vft(3), Tmin - 1);

tau0_vft  = exp(p_vft(1));
Ea_vft_eV = p_vft(2);
T0_vft    = p_vft(3);

lnTau_vft_fit = p_vft(1) + Ea_vft_eV ./ (kB .* max(temperature - T0_vft, eps));
res_vft = lnTau - lnTau_vft_fit;
[vft_metrics, vft_R2] = computeMetrics(lnTau, res_vft, 3);

vft.tau0   = tau0_vft;
vft.Ea_eV  = Ea_vft_eV;
vft.T0     = T0_vft;
vft.R2     = vft_R2;
vft.AIC    = vft_metrics.aic;
vft.BIC    = vft_metrics.bic;

% ════════════════════════════════════════════════════════════════════════
% 3. Model comparison
% ════════════════════════════════════════════════════════════════════════
deltaAIC = arrhenius.AIC - vft.AIC;   % positive = VFT preferred
deltaBIC = arrhenius.BIC - vft.BIC;   % positive = VFT preferred

if deltaBIC > 0
    preferred = 'VFT';
else
    preferred = 'Arrhenius';
end

% ════════════════════════════════════════════════════════════════════════
% Output
% ════════════════════════════════════════════════════════════════════════
result.arrhenius = arrhenius;
result.vft       = vft;
result.preferred = preferred;
result.deltaAIC  = deltaAIC;
result.deltaBIC  = deltaBIC;

end

% ════════════════════════════════════════════════════════════════════════
% Local: VFT objective function for fminsearch
% ════════════════════════════════════════════════════════════════════════
function RSS = vftResiduals(p, T, lnTau_obs, kB, Tmin)
%VFTRESIDUALS  Sum of squared ln(tau) residuals for fminsearch.
%   p = [lnTau0, Ea_eV, T0]
    lnTau0 = p(1);
    Ea     = p(2);
    T0     = p(3);

    % Penalise T0 >= Tmin (physically unphysical: T0 must be below all T)
    if T0 >= Tmin - 0.5
        RSS = 1e12 * (1 + abs(T0 - Tmin + 0.5));
        return;
    end

    denom = kB .* (T - T0);
    if any(denom <= 0)
        RSS = 1e12;
        return;
    end

    lnTau_pred = lnTau0 + Ea ./ denom;
    RSS = sum((lnTau_obs - lnTau_pred).^2);
end

% ════════════════════════════════════════════════════════════════════════
% Local: AIC / BIC / R² from residuals
% ════════════════════════════════════════════════════════════════════════
function [metrics, R2] = computeMetrics(yData, residuals, nParams)
%COMPUTEMETRICS  AIC, BIC, R² for a model with nParams free parameters.
    n   = numel(yData);
    RSS = sum(residuals.^2);
    TSS = sum((yData - mean(yData)).^2);
    R2  = 1 - RSS / max(TSS, eps);

    if RSS < eps
        aic = -Inf;
        bic = -Inf;
    else
        logL = n * log(RSS / n);
        aic  = logL + 2 * nParams;
        bic  = logL + nParams * log(n);
    end

    metrics.aic = aic;
    metrics.bic = bic;
end
