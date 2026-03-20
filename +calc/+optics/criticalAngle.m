function result = criticalAngle(n1, n2)
%CRITICALANGLE  Compute the critical angle for total internal reflection.
%
%   Syntax
%   ------
%   result = calc.optics.criticalAngle(n1, n2)
%
%   Inputs
%   ------
%   n1  — refractive index of the denser (incident) medium (real, positive)
%   n2  — refractive index of the rarer (transmitted) medium (real, positive)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .thetaC — critical angle (degrees); NaN if n2 >= n1 (no TIR possible)
%     .n1     — input n1
%     .n2     — input n2
%     .latex  — LaTeX-formatted result string
%
%   Notes
%   -----
%   Total internal reflection requires n1 > n2.  When n2 >= n1 the function
%   returns NaN and records a note in .latex rather than erroring, so callers
%   can use the result in vectorised workflows without branching.
%
%   Examples
%   --------
%   r = calc.optics.criticalAngle(1.5, 1.0);  % glass/air → ~41.8°
%   r = calc.optics.criticalAngle(1.0, 1.5);  % air/glass → NaN (no TIR)
%   r = calc.optics.criticalAngle(2.4, 1.0);  % diamond/air → ~24.6°

% ════════════════════════════════════════════════════════════════════

arguments
    n1  (1,1) double {mustBePositive, mustBeReal}
    n2  (1,1) double {mustBePositive, mustBeReal}
end

if n2 >= n1
    thetaC = NaN;
    latexStr = sprintf( ...
        '$\\theta_c = \\text{NaN} \\;(n_2=%.4g \\geq n_1=%.4g,\\;\\text{no TIR})$', ...
        n2, n1);
else
    thetaC   = rad2deg(asin(n2 / n1));
    latexStr = sprintf( ...
        '$\\theta_c = \\arcsin\\!\\left(\\tfrac{%.4g}{%.4g}\\right) = %.4g^\\circ$', ...
        n2, n1, thetaC);
end

result.thetaC = thetaC;
result.n1     = n1;
result.n2     = n2;
result.latex  = latexStr;
end
