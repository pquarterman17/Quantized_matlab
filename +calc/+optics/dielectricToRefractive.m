function result = dielectricToRefractive(eps1, eps2)
%DIELECTRICTOREFRACTIVE  Convert dielectric function (eps1, eps2) to complex refractive index.
%
%   Syntax
%   ------
%   result = calc.optics.dielectricToRefractive(eps1)
%   result = calc.optics.dielectricToRefractive(eps1, eps2)
%
%   Inputs
%   ------
%   eps1  — real part of dielectric function (dimensionless, scalar or array)
%   eps2  — imaginary part of dielectric function; default = 0
%
%   Outputs
%   -------
%   result — struct with fields:
%     .n          — real part of refractive index
%     .k          — extinction coefficient (>= 0)
%     .eps1       — input eps1
%     .eps2       — input eps2
%     .latex      — LaTeX-formatted result string
%
%   Notes
%   -----
%   The physical square root is taken: n >= 0, k >= 0.
%   For metals with eps1 < 0 (and eps2 = 0), n = 0, k = sqrt(-eps1).
%
%   Examples
%   --------
%   r = calc.optics.dielectricToRefractive(12.25);        % eps1=12.25 → n=3.5
%   r = calc.optics.dielectricToRefractive(-10, 2);       % metallic regime
%   r = calc.optics.dielectricToRefractive([2 4 9], 0);   % array input

% ════════════════════════════════════════════════════════════════════

arguments
    eps1  double {mustBeReal, mustBeFinite}
    eps2  double {mustBeReal, mustBeFinite} = zeros(size(eps1))
end

% Broadcast eps2 to match eps1 if scalar
if isscalar(eps2) && ~isscalar(eps1)
    eps2 = eps2 * ones(size(eps1));
end

% Compute modulus of complex dielectric
modEps = sqrt(eps1.^2 + eps2.^2);

% Physical square root: n >= 0, k >= 0
n = sqrt((modEps + eps1) ./ 2);
k = sqrt((modEps - eps1) ./ 2);

result.n    = n;
result.k    = k;
result.eps1 = eps1;
result.eps2 = eps2;

if isscalar(eps1)
    result.latex = sprintf( ...
        '$\\tilde{n} = %.4g + %.4g i \\quad (\\varepsilon_1=%.4g,\\,\\varepsilon_2=%.4g)$', ...
        n, k, eps1, eps2);
else
    result.latex = sprintf( ...
        '$n \\in [%.4g, %.4g],\\;k \\in [%.4g, %.4g]$', ...
        min(n(:)), max(n(:)), min(k(:)), max(k(:)));
end
end
