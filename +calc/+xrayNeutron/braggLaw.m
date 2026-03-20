function result = braggLaw(d, opts)
%BRAGGLAW  Apply Bragg's law to compute diffraction angle and Q from d-spacing.
%
%   Syntax
%   ------
%   result = calc.xrayNeutron.braggLaw(d)
%   result = calc.xrayNeutron.braggLaw(d, Lambda=lambda)
%
%   Inputs
%   ------
%   d      — interplanar d-spacing (Å)
%   Lambda — X-ray or neutron wavelength (Å); default = 1.5406 (Cu Kα₁)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .twoTheta — Bragg angle 2θ (degrees)
%     .theta    — Bragg angle θ (degrees)
%     .Q        — momentum transfer Q = 4π sin(θ)/λ (Å⁻¹)
%     .d        — input d-spacing (Å, echoed)
%     .lambda   — wavelength used (Å, echoed)
%     .latex    — LaTeX-formatted result string
%
%   Details
%   -------
%   Bragg's law: λ = 2d sin(θ)  →  θ = arcsin(λ / (2d))
%   Q-space:     Q = 4π sin(θ) / λ  =  2π / d
%
%   The function errors if λ > 2d (physically inaccessible reflection).
%
%   Examples
%   --------
%   r = calc.xrayNeutron.braggLaw(1.9525);     % SrTiO3 (002) at Cu Kα
%   % r.twoTheta ≈ 46.47°, r.Q ≈ 3.218 Å⁻¹
%
%   r = calc.xrayNeutron.braggLaw(2.0, Lambda=1.0);
%   % neutron source, λ = 1.0 Å

% ════════════════════════════════════════════════════════════════════

arguments
    d    (1,1) double {mustBePositive}
    opts.Lambda (1,1) double {mustBePositive} = 1.5406
end

lambda = opts.Lambda;

if lambda > 2 * d
    error('calc:xrayNeutron:braggLaw:inaccessible', ...
        'Wavelength %.4g Å > 2d = %.4g Å: reflection is not accessible.', ...
        lambda, 2*d);
end

sinTheta = lambda / (2 * d);
theta    = asind(sinTheta);
twoTheta = 2 * theta;
Q        = 4 * pi * sinTheta / lambda;  % = 2π/d

result.twoTheta = twoTheta;
result.theta    = theta;
result.Q        = Q;
result.d        = d;
result.lambda   = lambda;
result.latex    = sprintf( ...
    '$2\\theta = %.4g^\\circ,\\; Q = %.4g\\,\\text{\\AA}^{-1}$ ($d = %.4g\\,\\text{\\AA}$)', ...
    twoTheta, Q, d);

end
