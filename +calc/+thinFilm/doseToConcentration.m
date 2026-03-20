function result = doseToConcentration(dose, Rp, deltaRp)
%DOSETOCONCENTRATION  Peak implant concentration from dose and range parameters.
%
%   Syntax
%   ------
%   result = calc.thinFilm.doseToConcentration(dose, Rp, deltaRp)
%
%   Inputs
%   ------
%   dose    — implanted ion dose (ions/cm^2)
%   Rp      — projected range (nm)
%   deltaRp — range straggle (nm)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Cpeak   — peak concentration at depth Rp (atoms/cm^3)
%     .dose    — input dose (ions/cm^2)
%     .Rp      — input projected range (nm)
%     .deltaRp — input straggle (nm)
%     .latex   — LaTeX-formatted result string
%
%   Notes
%   -----
%   Assumes a Gaussian depth profile centred at Rp with standard deviation
%   deltaRp.  The peak concentration is:
%
%       C_peak = dose / (sqrt(2*pi) * deltaRp)
%
%   with deltaRp converted from nm to cm before division so that C_peak
%   is in atoms/cm^3.
%
%   Examples
%   --------
%   r = calc.thinFilm.doseToConcentration(1e15, 80, 25);
%   r = calc.thinFilm.doseToConcentration(5e14, 120, 40);

% ════════════════════════════════════════════════════════════════════

arguments
    dose    (1,1) double {mustBePositive}
    Rp      (1,1) double {mustBePositive}
    deltaRp (1,1) double {mustBePositive}
end

deltaRp_cm = deltaRp * 1e-7;                          % nm → cm
Cpeak      = dose / (sqrt(2*pi) * deltaRp_cm);        % atoms/cm^3

result.Cpeak   = Cpeak;
result.dose    = dose;
result.Rp      = Rp;
result.deltaRp = deltaRp;
result.latex   = sprintf( ...
    '$C_{\\mathrm{peak}} = %.4g\\,\\text{atoms/cm}^3$', Cpeak);
end
