function result = monolayerTime(P, opts)
%MONOLAYERTIME  Estimate the monolayer formation time at a given pressure.
%
%   Uses the Langmuir adsorption model: the impingement flux determines how
%   quickly a single monolayer accumulates on a surface.
%
%   Syntax
%   ------
%   result = calc.vacuum.monolayerTime(P)
%   result = calc.vacuum.monolayerTime(P, m=m, T=T, A_site=A_site)
%
%   Inputs
%   ------
%   P      — pressure (Pa)
%   m      — molecular mass (kg); default = 4.65e-26 (N2, ~28 amu)
%   T      — temperature (K); default = 300
%   A_site — adsorption site area (m^2); default = 1e-19
%
%   Outputs
%   -------
%   result — struct with fields:
%     .tMono  — monolayer formation time (s)
%     .flux   — molecular flux (molecules/m^2/s)
%     .P      — input pressure (Pa)
%     .T      — input temperature (K)
%     .latex  — LaTeX-formatted result string
%
%   Examples
%   --------
%   r = calc.vacuum.monolayerTime(1e-6);          % UHV base pressure
%   r = calc.vacuum.monolayerTime(1e-4, T=300);   % N2 at 1e-4 Pa

% ════════════════════════════════════════════════════════════════════

arguments
    P        (1,1) double {mustBePositive}
    opts.m      (1,1) double {mustBePositive} = 4.65e-26
    opts.T      (1,1) double {mustBePositive} = 300
    opts.A_site (1,1) double {mustBePositive} = 1e-19
end

C      = calc.constants();
m      = opts.m;
T      = opts.T;
A_site = opts.A_site;

flux   = P / sqrt(2 * pi * m * C.kB * T);
tMono  = 1 / (flux * A_site);

result.tMono = tMono;
result.flux  = flux;
result.P     = P;
result.T     = T;
result.latex = sprintf('$t_{\\mathrm{mono}} = %.4g\\,\\text{s}$', tMono);
end
