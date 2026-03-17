function result = diffusionLength_thermal(D, t)
%DIFFUSIONLENGTH_THERMAL  Compute thermal diffusion length from diffusivity and anneal time.
%
%   Syntax
%   ------
%   result = calc.thinFilm.diffusionLength_thermal(D, t)
%
%   Inputs
%   ------
%   D — diffusion coefficient (cm^2/s)
%   t — anneal time (s)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .L    — diffusion length (cm)
%     .Lnm  — diffusion length (nm)
%     .Lum  — diffusion length (um)
%     .D    — input diffusivity (cm^2/s)
%     .t    — input time (s)
%     .latex — LaTeX-formatted result string
%
%   Notes
%   -----
%   L = sqrt(D * t)
%   This gives the characteristic length over which a dopant or species
%   diffuses during an anneal step.
%
%   Examples
%   --------
%   r = calc.thinFilm.diffusionLength_thermal(1e-13, 3600);  % 1 hr anneal
%   r = calc.thinFilm.diffusionLength_thermal(1e-12, 600);   % 10 min anneal

% ════════════════════════════════════════════════════════════════════

arguments
    D (1,1) double {mustBePositive}
    t (1,1) double {mustBePositive}
end

L    = sqrt(D * t);               % cm
Lnm  = L * 1e7;                   % cm → nm  (1 cm = 1e7 nm)
Lum  = L * 1e4;                   % cm → um  (1 cm = 1e4 um)

result.L    = L;
result.Lnm  = Lnm;
result.Lum  = Lum;
result.D    = D;
result.t    = t;
result.latex = sprintf( ...
    '$L = \\sqrt{Dt} = %.4g\\,\\text{cm}\\;(%.4g\\,\\text{nm})$', L, Lnm);
end
