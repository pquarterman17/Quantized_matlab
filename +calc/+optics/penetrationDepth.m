function result = penetrationDepth(n, k, lambda)
%PENETRATIONDEPTH  Compute the optical penetration depth for an absorbing medium.
%
%   Syntax
%   ------
%   result = calc.optics.penetrationDepth(n, k, lambda)
%
%   Inputs
%   ------
%   n       — real part of refractive index (dimensionless, positive)
%   k       — extinction coefficient (dimensionless, non-negative)
%   lambda  — wavelength of light (any length unit; output uses same unit)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .depth     — 1/e intensity penetration depth = lambda / (4*pi*k)  [same unit as lambda]
%     .absCoeff  — absorption coefficient alpha = 4*pi*k / lambda       [1 / unit of lambda]
%     .absLength — absorption length = 1 / (2 * absCoeff) = depth / 2  [same unit as lambda]
%     .lambda    — input wavelength
%     .n         — input n
%     .k         — input k
%     .latex     — LaTeX-formatted result string
%
%   Notes
%   -----
%   When k = 0 the medium is lossless; .depth and .absLength are Inf and
%   .absCoeff is 0.  No error is raised.
%
%   The intensity penetration depth is defined as the distance at which the
%   intensity falls to 1/e of its surface value:  I(z) = I_0 * exp(-z/depth).
%   This equals lambda/(4*pi*k) = 1/alpha for a plane wave.
%
%   Examples
%   --------
%   % Silicon at 400 nm (k ≈ 0.05)
%   r = calc.optics.penetrationDepth(5.6, 0.39, 400e-9);   % lambda in m
%   r = calc.optics.penetrationDepth(5.6, 0.39, 400);       % lambda in nm
%
%   % Gold at 532 nm (k ≈ 2.9)
%   r = calc.optics.penetrationDepth(0.5, 2.9, 532e-9);

% ════════════════════════════════════════════════════════════════════

arguments
    n       (1,1) double {mustBePositive, mustBeReal}
    k       (1,1) double {mustBeNonnegative, mustBeReal}
    lambda  (1,1) double {mustBePositive, mustBeReal}
end

if k == 0
    absCoeff  = 0;
    depth     = Inf;
    absLength = Inf;
else
    absCoeff  = 4 * pi * k / lambda;
    depth     = 1 / absCoeff;          % = lambda / (4*pi*k)
    absLength = 1 / (2 * absCoeff);
end

result.depth     = depth;
result.absCoeff  = absCoeff;
result.absLength = absLength;
result.lambda    = lambda;
result.n         = n;
result.k         = k;

if isinf(depth)
    result.latex = sprintf( ...
        '$\\delta = \\infty \\;(k=0,\\;\\lambda=%.4g)$', lambda);
else
    result.latex = sprintf( ...
        '$\\delta = \\frac{\\lambda}{4\\pi k} = %.4g \\quad (k=%.4g,\\;\\lambda=%.4g)$', ...
        depth, k, lambda);
end
end
