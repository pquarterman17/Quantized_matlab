function result = skinDepth(rho, f)
%SKINDEPTH  Compute the electromagnetic skin depth for a conducting material.
%
%   Syntax
%   ------
%   result = calc.optics.skinDepth(rho, f)
%
%   Inputs
%   ------
%   rho  — electrical resistivity (Ohm*m)
%   f    — frequency of the electromagnetic field (Hz)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .delta    — skin depth (m)
%     .deltaUm  — skin depth (micrometers)
%     .deltaNm  — skin depth (nanometers)
%     .rho      — input resistivity (Ohm*m)
%     .f        — input frequency (Hz)
%     .latex    — LaTeX-formatted result string
%
%   Notes
%   -----
%   The classical skin depth formula assumes a good conductor (sigma >> omega*eps):
%
%       delta = sqrt(2*rho / (omega * mu0))
%
%   where omega = 2*pi*f and mu0 is the vacuum permeability (H/m).
%   This approximation is valid when rho << 1 / (2*pi*f*eps0), i.e. the
%   conductivity dominates over displacement current.  The formula uses the
%   relative permeability mu_r = 1 (non-magnetic material); for magnetic
%   materials multiply rho by 1/mu_r or divide delta^2 by mu_r before sqrt.
%
%   Examples
%   --------
%   % Copper (rho ≈ 1.68e-8 Ohm*m) at 50 Hz mains frequency
%   r = calc.optics.skinDepth(1.68e-8, 50);      % → ~9.3 mm
%
%   % Copper at 1 GHz (microwave)
%   r = calc.optics.skinDepth(1.68e-8, 1e9);     % → ~2.1 µm
%
%   % Gold (rho ≈ 2.44e-8 Ohm*m) at 500 THz (visible light)
%   r = calc.optics.skinDepth(2.44e-8, 500e12);  % → ~25 nm

% ════════════════════════════════════════════════════════════════════

arguments
    rho  (1,1) double {mustBePositive, mustBeReal}
    f    (1,1) double {mustBePositive, mustBeReal}
end

C   = calc.constants();
mu0 = C.mu0;                          % vacuum permeability (H/m)

omega   = 2 * pi * f;
delta   = sqrt(2 * rho / (omega * mu0));
deltaUm = delta * 1e6;
deltaNm = delta * 1e9;

result.delta   = delta;
result.deltaUm = deltaUm;
result.deltaNm = deltaNm;
result.rho     = rho;
result.f       = f;
result.latex   = sprintf( ...
    '$\\delta = \\sqrt{\\frac{2\\rho}{\\omega\\mu_0}} = %.4g\\,\\text{m} = %.4g\\,\\mu\\text{m}$', ...
    delta, deltaUm);
end
