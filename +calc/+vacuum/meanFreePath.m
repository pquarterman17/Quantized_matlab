function result = meanFreePath(P, opts)
%MEANFREEPATH  Compute the mean free path of a gas molecule.
%
%   Syntax
%   ------
%   result = calc.vacuum.meanFreePath(P)
%   result = calc.vacuum.meanFreePath(P, T=T, d=d)
%
%   Inputs
%   ------
%   P   — pressure (Pa)
%   T   — temperature (K); default = 300
%   d   — molecular diameter (m); default = 3.64e-10 (N2)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .mfp    — mean free path (m)
%     .mfpMm  — mean free path (mm)
%     .mfpUm  — mean free path (um)
%     .P      — input pressure (Pa)
%     .T      — input temperature (K)
%     .d      — input molecular diameter (m)
%     .latex  — LaTeX-formatted result string
%
%   Examples
%   --------
%   r = calc.vacuum.meanFreePath(1e-3);          % N2 at 1 mTorr-equivalent
%   r = calc.vacuum.meanFreePath(101325);        % atmospheric pressure
%   r = calc.vacuum.meanFreePath(1e-4, T=300, d=3.64e-10);

% ════════════════════════════════════════════════════════════════════

arguments
    P    (1,1) double {mustBePositive}
    opts.T   (1,1) double {mustBePositive} = 300
    opts.d   (1,1) double {mustBePositive} = 3.64e-10
end

C   = calc.constants();
T   = opts.T;
d   = opts.d;

mfp    = (C.kB * T) / (sqrt(2) * pi * d^2 * P);
mfpMm  = mfp * 1e3;
mfpUm  = mfp * 1e6;

result.mfp   = mfp;
result.mfpMm = mfpMm;
result.mfpUm = mfpUm;
result.P     = P;
result.T     = T;
result.d     = d;
result.latex = sprintf('$\\lambda = %.4g\\,\\text{m}$', mfp);
end
