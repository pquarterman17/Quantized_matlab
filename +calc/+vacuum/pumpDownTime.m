function result = pumpDownTime(V, S, P0, Pf)
%PUMPDOWNTIME  Estimate the time to pump a chamber from P0 to Pf.
%
%   Assumes ideal exponential pump-down (constant pump speed, no outgassing).
%   Formula: t = (V/S) * ln(P0/Pf)
%
%   Syntax
%   ------
%   result = calc.vacuum.pumpDownTime(V, S, P0, Pf)
%
%   Inputs
%   ------
%   V   — chamber volume (L)
%   S   — pump speed (L/s)
%   P0  — initial pressure (Pa)
%   Pf  — final (target) pressure (Pa)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .time    — pump-down time (s)
%     .timeMin — pump-down time (minutes)
%     .tau     — time constant V/S (s)
%     .V       — input volume (L)
%     .S       — input pump speed (L/s)
%     .P0      — initial pressure (Pa)
%     .Pf      — final pressure (Pa)
%     .latex   — LaTeX-formatted result string
%
%   Examples
%   --------
%   r = calc.vacuum.pumpDownTime(100, 500, 1e5, 1e-4);  % 100 L chamber
%   r = calc.vacuum.pumpDownTime(10,  50,  1e5, 1e-6);  % small chamber to HV

% ════════════════════════════════════════════════════════════════════

arguments
    V   (1,1) double {mustBePositive}
    S   (1,1) double {mustBePositive}
    P0  (1,1) double {mustBePositive}
    Pf  (1,1) double {mustBePositive}
end

if Pf >= P0
    error('pumpDownTime:invalidPressure', ...
        'Final pressure Pf must be less than initial pressure P0.');
end

tau     = V / S;
t       = tau * log(P0 / Pf);
timeMin = t / 60;

result.time    = t;
result.timeMin = timeMin;
result.tau     = tau;
result.V       = V;
result.S       = S;
result.P0      = P0;
result.Pf      = Pf;
result.latex   = sprintf('$t = %.4g\\,\\text{s}$ ($\\tau = %.4g\\,\\text{s}$)', t, tau);
end
