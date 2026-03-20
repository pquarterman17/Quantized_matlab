function result = sputterRate(Y, J, rho, M)
%SPUTTERRATE  Compute sputter erosion rate from yield, current density, and target properties.
%
%   Syntax
%   ------
%   result = calc.thinFilm.sputterRate(Y, J, rho, M)
%
%   Inputs
%   ------
%   Y   — sputter yield (atoms/ion)
%   J   — ion current density (mA/cm^2)
%   rho — target bulk density (g/cm^3)
%   M   — target molar mass (g/mol)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .rate        — sputter rate (nm/s)
%     .rateNmPerMin — sputter rate (nm/min)
%     .Y           — input sputter yield (atoms/ion)
%     .J           — input current density (mA/cm^2)
%     .rho         — input target density (g/cm^3)
%     .M           — input molar mass (g/mol)
%     .latex       — LaTeX-formatted result string
%
%   Notes
%   -----
%   Derivation:
%     Ion flux  phi  = J / e  (ions/cm^2/s)  where J is in A/cm^2
%     Atom flux       = Y * phi  (atoms/cm^2/s)
%     Volume flux     = Y * phi * M / (rho * NA)  (cm/s)
%     Rate (nm/s)    = volume flux * 1e7
%
%   J is supplied in mA/cm^2 and converted to A/cm^2 internally (*1e-3).
%   NA and e are taken from calc.constants().
%
%   Examples
%   --------
%   r = calc.thinFilm.sputterRate(2.5, 1.0, 19.3, 196.97);  % Au target, 1 mA/cm^2
%   r = calc.thinFilm.sputterRate(1.2, 0.5, 2.33, 28.09);   % Si target, 0.5 mA/cm^2

% ════════════════════════════════════════════════════════════════════

arguments
    Y   (1,1) double {mustBePositive}
    J   (1,1) double {mustBePositive}
    rho (1,1) double {mustBePositive}
    M   (1,1) double {mustBePositive}
end

C  = calc.constants();
NA = C.NA;
e  = C.e;

J_A       = J * 1e-3;                         % mA/cm^2 → A/cm^2
flux      = J_A / e;                           % ions/cm^2/s
rate_cmps = Y * flux * M / (rho * NA);         % cm/s
rate      = rate_cmps * 1e7;                   % cm/s → nm/s
rateNmPerMin = rate * 60;                      % nm/s → nm/min

result.rate         = rate;
result.rateNmPerMin = rateNmPerMin;
result.Y            = Y;
result.J            = J;
result.rho          = rho;
result.M            = M;
result.latex        = sprintf( ...
    '$\\dot{d} = %.4g\\,\\text{nm/s}\\;(%.4g\\,\\text{nm/min})$', ...
    rate, rateNmPerMin);
end
