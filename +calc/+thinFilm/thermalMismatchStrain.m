function result = thermalMismatchStrain(alphaFilm, alphaSub, deltaT, opts)
%THERMALMISMATCHSTRAIN  Compute thermal mismatch strain (and optionally stress) in a thin film.
%
%   Syntax
%   ------
%   result = calc.thinFilm.thermalMismatchStrain(alphaFilm, alphaSub, deltaT)
%   result = calc.thinFilm.thermalMismatchStrain(alphaFilm, alphaSub, deltaT, E=E)
%   result = calc.thinFilm.thermalMismatchStrain(alphaFilm, alphaSub, deltaT, E=E, nu=nu)
%
%   Inputs
%   ------
%   alphaFilm — film linear coefficient of thermal expansion (1/K)
%   alphaSub  — substrate linear CTE (1/K)
%   deltaT    — temperature change T_final - T_initial (K)
%   E         — film biaxial modulus (Pa); optional, enables stress calculation
%   nu        — film Poisson ratio; default = 0.3 (used only when E is supplied)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .strain      — dimensionless thermal mismatch strain
%     .stressMPa   — biaxial stress (MPa); NaN if E not provided
%     .alphaFilm   — input film CTE (1/K)
%     .alphaSub    — input substrate CTE (1/K)
%     .deltaT      — input temperature change (K)
%     .description — 'tensile', 'compressive', or 'none'
%     .latex        — LaTeX-formatted result string
%
%   Notes
%   -----
%   strain = (alphaFilm - alphaSub) * deltaT
%   stress = E * strain / (1 - nu)   [biaxial, if E supplied]
%   Positive strain/stress = tensile; negative = compressive.
%
%   Examples
%   --------
%   % Strain only
%   r = calc.thinFilm.thermalMismatchStrain(17e-6, 3e-6, -500);
%   % Strain + stress (biaxial modulus given)
%   r = calc.thinFilm.thermalMismatchStrain(17e-6, 3e-6, -500, E=200e9, nu=0.28);

% ════════════════════════════════════════════════════════════════════

arguments
    alphaFilm (1,1) double
    alphaSub  (1,1) double
    deltaT    (1,1) double
    opts.E    (1,1) double = NaN
    opts.nu   (1,1) double {mustBeNonnegative} = 0.3
end

strain = (alphaFilm - alphaSub) * deltaT;

if ~isnan(opts.E)
    stressPa  = opts.E * strain / (1 - opts.nu);
    stressMPa = stressPa * 1e-6;
else
    stressMPa = NaN;
end

if strain > 0
    desc = 'tensile';
elseif strain < 0
    desc = 'compressive';
else
    desc = 'none';
end

result.strain      = strain;
result.stressMPa   = stressMPa;
result.alphaFilm   = alphaFilm;
result.alphaSub    = alphaSub;
result.deltaT      = deltaT;
result.description = desc;

if ~isnan(stressMPa)
    result.latex = sprintf( ...
        '$\\varepsilon = %.4g,\\;\\sigma = %.4g\\,\\text{MPa}\\;(%s)$', ...
        strain, stressMPa, desc);
else
    result.latex = sprintf( ...
        '$\\varepsilon = %.4g\\;(%s)$', strain, desc);
end
end
