function result = doseFromCurrent(current, time, area)
%DOSEFROMCURRENT  Compute ion implantation dose from beam current, time, and area.
%
%   Syntax
%   ------
%   result = calc.thinFilm.doseFromCurrent(current, time, area)
%
%   Inputs
%   ------
%   current — beam current (A)
%   time    — implantation time (s)
%   area    — implanted area (cm^2)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .dose    — implanted ion dose (ions/cm^2)
%     .current — input current (A)
%     .time    — input time (s)
%     .area    — input area (cm^2)
%     .latex   — LaTeX-formatted result string
%
%   Notes
%   -----
%   dose = (current * time) / (q * area)
%   where q is the elementary charge (1.602e-19 C). Assumes singly charged ions.
%
%   Examples
%   --------
%   r = calc.thinFilm.doseFromCurrent(1e-6, 60, 1.0);   % 1 uA, 60 s, 1 cm^2
%   r = calc.thinFilm.doseFromCurrent(50e-6, 120, 0.5); % 50 uA, 2 min, 0.5 cm^2

% ════════════════════════════════════════════════════════════════════

arguments
    current (1,1) double {mustBePositive}
    time    (1,1) double {mustBePositive}
    area    (1,1) double {mustBePositive}
end

C    = calc.constants();
dose = (current * time) / (C.e * area);

result.dose    = dose;
result.current = current;
result.time    = time;
result.area    = area;
result.latex   = sprintf( ...
    '$\\Phi = %.4g\\,\\text{ions/cm}^2$', dose);
end
