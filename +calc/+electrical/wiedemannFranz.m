function kappa = wiedemannFranz(temperature, resistivity)
%WIEDEMANNFRANZ  Electronic thermal conductivity from the Wiedemann-Franz law.
%
%   Syntax:
%     kappa = calc.electrical.wiedemannFranz(temperature, resistivity)
%
%   Inputs:
%     temperature — temperature vector or scalar (K)
%     resistivity — electrical resistivity vector or scalar (Ohm·cm); must be
%                   the same size as temperature, or scalar (broadcast)
%
%   Outputs:
%     kappa — electronic thermal conductivity κ_e (W/(cm·K)); same size as temperature
%
%   Formula:
%     κ_e = L₀ · T / ρ
%   where L₀ = 2.44×10⁻⁸ W·Ω/K² is the Lorenz number (Sommerfeld value).
%
%   Notes:
%     - ρ must be in Ohm·cm and T in K; κ_e is returned in W/(cm·K).
%     - For real metals, the Wiedemann-Franz law holds well near room temperature
%       and at very low T. At intermediate T, inelastic scattering reduces κ_e
%       below this estimate.
%     - Returns Inf where resistivity is zero; returns NaN where T or ρ is NaN.
%
%   Example:
%     % Copper at 300 K: ρ ≈ 1.72e-6 Ohm·cm → κ_e ≈ 4.25 W/(cm·K)
%     kappa = calc.electrical.wiedemannFranz(300, 1.72e-6);
%     fprintf('κ_e = %.3f W/(cm·K)\n', kappa)

% ════════════════════════════════════════════════════════════════════

arguments
    temperature (:,1) double
    resistivity (:,1) double
end

% Lorenz number (Sommerfeld value): L₀ = π²kB²/(3e²) = 2.44×10⁻⁸ W·Ω/K²
L0 = 2.44e-8;  % W·Ω/K²

% Broadcast scalar resistivity to match temperature length
if isscalar(resistivity) && ~isscalar(temperature)
    resistivity = resistivity * ones(size(temperature));
end
if isscalar(temperature) && ~isscalar(resistivity)
    temperature = temperature * ones(size(resistivity));
end

if numel(temperature) ~= numel(resistivity)
    error('wiedemannFranz:sizeMismatch', ...
        'temperature and resistivity must be the same size, or one must be scalar.');
end

% κ_e = L₀·T/ρ  (all in consistent CGS-electrical units)
kappa = L0 .* temperature ./ resistivity;

end
