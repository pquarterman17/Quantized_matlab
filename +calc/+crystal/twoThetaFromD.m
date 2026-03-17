function result = twoThetaFromD(d, opts)
%TWOTHETATFROMD  Convert d-spacing to 2-theta using Bragg's law.
%
%   Syntax
%   ------
%   result = calc.crystal.twoThetaFromD(d)
%   result = calc.crystal.twoThetaFromD(d, lambda=lambda)
%
%   Inputs
%   ------
%   d      — interplanar spacing (Angstroms); scalar or array
%   lambda — X-ray wavelength (Angstroms); default = 1.5406 (Cu Kalpha1)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .twoTheta — diffraction angle 2theta (degrees)
%     .lambda   — wavelength used (Angstroms)
%     .d        — input d-spacing (Angstroms)
%     .latex    — LaTeX-formatted result string (scalar d only)
%
%   Examples
%   --------
%   r = calc.crystal.twoThetaFromD(2.0232);           % Cu Ka, returns ~44.5 deg
%   r = calc.crystal.twoThetaFromD(1.9, lambda=1.7902); % Co Ka

% ════════════════════════════════════════════════════════════════════

arguments
    d      double {mustBePositive}
    opts.lambda (1,1) double {mustBePositive} = 1.5406
end

lambda = opts.lambda;
sinTheta = lambda ./ (2 .* d);

if any(sinTheta > 1, 'all')
    error('calc:crystal:twoThetaFromD:noSolution', ...
        'No Bragg solution: lambda/(2d) > 1 for some inputs (lambda=%.4f, min d=%.4f).', ...
        lambda, min(d(:)));
end

twoTheta = 2 .* rad2deg(asin(sinTheta));

result.twoTheta = twoTheta;
result.lambda   = lambda;
result.d        = d;

if isscalar(d)
    result.latex = sprintf('$2\\theta = %.4g^\\circ$\\;$(d = %.4g\\,\\text{\\AA},\\;\\lambda = %.4g\\,\\text{\\AA})$', ...
        twoTheta, d, lambda);
else
    result.latex = '';
end
end
