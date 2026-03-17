function result = stoneyStress(Es, nus, ts, tf, R)
%STONEYSTRESS  Compute biaxial film stress via the Stoney equation.
%
%   Syntax
%   ------
%   result = calc.thinFilm.stoneyStress(Es, nus, ts, tf, R)
%
%   Inputs
%   ------
%   Es  — substrate Young's modulus (Pa)
%   nus — substrate Poisson ratio (dimensionless)
%   ts  — substrate thickness (m)
%   tf  — film thickness (m)
%   R   — radius of curvature of the substrate (m); positive = concave up
%
%   Outputs
%   -------
%   result — struct with fields:
%     .stress    — biaxial film stress (Pa)
%     .stressMPa — stress (MPa)
%     .stressGPa — stress (GPa)
%     .Es, .ts, .tf, .R — echo of inputs
%     .latex      — LaTeX-formatted result string
%
%   Notes
%   -----
%   sigma = (Es * ts^2) / (6 * (1 - nus) * tf * R)
%   Positive sigma = tensile; negative sigma = compressive.
%
%   Examples
%   --------
%   % 100 nm film on 500 um Si substrate, R = 10 m curvature
%   r = calc.thinFilm.stoneyStress(130e9, 0.28, 500e-6, 100e-9, 10);

% ════════════════════════════════════════════════════════════════════

arguments
    Es  (1,1) double {mustBePositive}
    nus (1,1) double {mustBeNonnegative}
    ts  (1,1) double {mustBePositive}
    tf  (1,1) double {mustBePositive}
    R   (1,1) double
end

stress    = (Es * ts^2) / (6 * (1 - nus) * tf * R);
stressMPa = stress * 1e-6;
stressGPa = stress * 1e-9;

result.stress    = stress;
result.stressMPa = stressMPa;
result.stressGPa = stressGPa;
result.Es        = Es;
result.ts        = ts;
result.tf        = tf;
result.R         = R;
result.latex     = sprintf( ...
    '$\\sigma = %.4g\\,\\text{Pa}\\;(%.4g\\,\\text{MPa})$', ...
    stress, stressMPa);
end
