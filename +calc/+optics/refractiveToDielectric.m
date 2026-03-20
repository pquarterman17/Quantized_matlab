function result = refractiveToDielectric(n, k)
%REFRACTIVEDIELECTRIC  Convert complex refractive index (n, k) to dielectric function.
%
%   Syntax
%   ------
%   result = calc.optics.refractiveToDielectric(n)
%   result = calc.optics.refractiveToDielectric(n, k)
%
%   Inputs
%   ------
%   n   — real part of refractive index (dimensionless, scalar or array)
%   k   — extinction coefficient (dimensionless); default = 0
%
%   Outputs
%   -------
%   result — struct with fields:
%     .eps1       — real part of dielectric function (n^2 - k^2)
%     .eps2       — imaginary part of dielectric function (2*n*k)
%     .epsComplex — complex dielectric function (eps1 + i*eps2)
%     .n          — input n
%     .k          — input k
%     .latex      — LaTeX-formatted result string
%
%   Examples
%   --------
%   r = calc.optics.refractiveToDielectric(3.5);          % silicon (IR), k=0
%   r = calc.optics.refractiveToDielectric(0.15, 3.6);    % gold at ~600 nm
%   r = calc.optics.refractiveToDielectric([1.5 1.8], 0); % array input

% ════════════════════════════════════════════════════════════════════

arguments
    n  double {mustBeReal, mustBeFinite}
    k  double {mustBeReal, mustBeNonnegative} = zeros(size(n))
end

% Broadcast k to match n if scalar
if isscalar(k) && ~isscalar(n)
    k = k * ones(size(n));
end

% Core conversion: eps = (n + i*k)^2
eps1 = n.^2 - k.^2;
eps2 = 2 .* n .* k;
epsComplex = complex(eps1, eps2);

result.eps1       = eps1;
result.eps2       = eps2;
result.epsComplex = epsComplex;
result.n          = n;
result.k          = k;

if isscalar(n)
    result.latex = sprintf( ...
        '$\\varepsilon = %.4g %+.4g i \\quad (n=%.4g,\\,k=%.4g)$', ...
        eps1, eps2, n, k);
else
    result.latex = sprintf( ...
        '$\\varepsilon_1 \\in [%.4g, %.4g],\\;\\varepsilon_2 \\in [%.4g, %.4g]$', ...
        min(eps1(:)), max(eps1(:)), min(eps2(:)), max(eps2(:)));
end
end
