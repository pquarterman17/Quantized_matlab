function result = dFromTwoTheta(twoTheta, opts)
%DFROMTWOTHETA  Convert 2-theta to d-spacing using Bragg's law.
%
%   Syntax
%   ------
%   result = calc.crystal.dFromTwoTheta(twoTheta)
%   result = calc.crystal.dFromTwoTheta(twoTheta, lambda=lambda)
%
%   Inputs
%   ------
%   twoTheta — diffraction angle (degrees); scalar or array
%   lambda   — X-ray wavelength (Angstroms); default = 1.5406 (Cu Kalpha1)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .d        — interplanar spacing (Angstroms)
%     .twoTheta — input angle (degrees)
%     .lambda   — wavelength used (Angstroms)
%     .latex    — LaTeX-formatted result string (scalar input only)
%
%   Examples
%   --------
%   r = calc.crystal.dFromTwoTheta(44.507);            % Cu Ka -> ~2.032 Ang
%   r = calc.crystal.dFromTwoTheta([20, 40, 60]);      % array input

% ════════════════════════════════════════════════════════════════════

arguments
    twoTheta double {mustBePositive}
    opts.lambda (1,1) double {mustBePositive} = 1.5406
end

lambda = opts.lambda;
theta  = deg2rad(twoTheta ./ 2);
d      = lambda ./ (2 .* sin(theta));

result.d        = d;
result.twoTheta = twoTheta;
result.lambda   = lambda;

if isscalar(twoTheta)
    result.latex = sprintf('$d = %.4g\\,\\text{\\AA}$\\;$(2\\theta = %.4g^\\circ,\\;\\lambda = %.4g\\,\\text{\\AA})$', ...
        d, twoTheta, lambda);
else
    result.latex = '';
end
end
