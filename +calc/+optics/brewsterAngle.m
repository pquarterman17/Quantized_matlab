function result = brewsterAngle(n1, n2)
%BREWSTERANGLE  Compute the Brewster angle for p-polarised light at an interface.
%
%   Syntax
%   ------
%   result = calc.optics.brewsterAngle(n1, n2)
%
%   Inputs
%   ------
%   n1  — refractive index of the incident medium (real, positive)
%   n2  — refractive index of the transmitted medium (real, positive)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .thetaB — Brewster angle (degrees); at this angle Rp = 0
%     .n1     — input n1
%     .n2     — input n2
%     .latex  — LaTeX-formatted result string
%
%   Notes
%   -----
%   At the Brewster angle the reflected beam is purely s-polarised.
%   The formula theta_B = atan(n2/n1) is exact for real (lossless) media.
%   For absorbing media (complex n) use fresnelCoefficients and find the
%   minimum of |rp|^2 numerically.
%
%   Examples
%   --------
%   r = calc.optics.brewsterAngle(1.0, 1.5);   % air/glass → ~56.3°
%   r = calc.optics.brewsterAngle(1.5, 1.0);   % glass/air → ~33.7°
%   r = calc.optics.brewsterAngle(1.0, 2.4);   % air/diamond → ~67.4°

% ════════════════════════════════════════════════════════════════════

arguments
    n1  (1,1) double {mustBePositive, mustBeReal}
    n2  (1,1) double {mustBePositive, mustBeReal}
end

thetaB = rad2deg(atan(n2 / n1));

result.thetaB = thetaB;
result.n1     = n1;
result.n2     = n2;
result.latex  = sprintf( ...
    '$\\theta_B = \\arctan\\!\\left(\\tfrac{%.4g}{%.4g}\\right) = %.4g^\\circ$', ...
    n2, n1, thetaB);
end
