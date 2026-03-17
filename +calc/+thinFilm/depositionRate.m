function result = depositionRate(thickness, time)
%DEPOSITIONRATE  Compute thin-film deposition rate from thickness and time.
%
%   Syntax
%   ------
%   result = calc.thinFilm.depositionRate(thickness, time)
%
%   Inputs
%   ------
%   thickness — deposited film thickness (Angstroms)
%   time      — deposition time (seconds)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .rate         — deposition rate (Ang/s)
%     .rateNmPerMin — deposition rate (nm/min)
%     .thickness    — input thickness (Ang)
%     .time         — input time (s)
%     .latex        — LaTeX-formatted result string
%
%   Examples
%   --------
%   r = calc.thinFilm.depositionRate(100, 60);   % 100 Ang in 60 s
%   r = calc.thinFilm.depositionRate(500, 300);  % 500 Ang in 5 min

% ════════════════════════════════════════════════════════════════════

arguments
    thickness (1,1) double {mustBePositive}
    time      (1,1) double {mustBePositive}
end

rate         = thickness / time;                  % Ang/s
rateNmPerMin = rate * 0.1 * 60;                   % convert Ang/s → nm/min

result.rate         = rate;
result.rateNmPerMin = rateNmPerMin;
result.thickness    = thickness;
result.time         = time;
result.latex        = sprintf( ...
    '$r = %.4g\\,\\text{\\AA/s}\\;(%.4g\\,\\text{nm/min})$', ...
    rate, rateNmPerMin);
end
