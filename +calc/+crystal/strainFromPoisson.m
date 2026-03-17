function result = strainFromPoisson(epsInPlane, nu)
%STRAINFROMOTISSON  Compute out-of-plane strain from in-plane strain via Poisson coupling.
%
%   Syntax
%   ------
%   result = calc.crystal.strainFromPoisson(epsInPlane, nu)
%
%   Inputs
%   ------
%   epsInPlane — in-plane (parallel) strain epsilon_parallel (dimensionless)
%   nu         — Poisson ratio of the film (dimensionless)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .epsPerp    — out-of-plane strain epsilon_perp
%     .epsParallel — in-plane strain (echo of input)
%     .nu          — Poisson ratio used
%     .formula     — formula string description
%     .latex       — LaTeX-formatted result string
%
%   Notes
%   -----
%   For biaxial in-plane strain (epsilon_xx = epsilon_yy = epsilon_parallel)
%   with free out-of-plane surface, elastic theory gives:
%     epsilon_perp = -2*nu/(1-nu) * epsilon_parallel
%   Positive epsInPlane (tensile) → negative epsPerp (c-axis compression).
%
%   Examples
%   --------
%   % Film with 1% tensile in-plane strain, nu=0.3
%   r = calc.crystal.strainFromPoisson(0.01, 0.3);
%   % r.epsPerp = -0.0086 (0.86% c-axis compression)

% ════════════════════════════════════════════════════════════════════

arguments
    epsInPlane (1,1) double
    nu         (1,1) double {mustBeNonnegative}
end

epsPerp = -2*nu / (1 - nu) * epsInPlane;

result.epsPerp    = epsPerp;
result.epsParallel = epsInPlane;
result.nu          = nu;
result.formula     = 'eps_perp = -2*nu/(1-nu) * eps_parallel';
result.latex = sprintf( ...
    '$\\varepsilon_\\perp = %.4g,\\;\\varepsilon_\\parallel = %.4g,\\;\\nu = %.3g$', ...
    epsPerp, epsInPlane, nu);
end
