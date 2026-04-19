function y = tchPseudoVoigt(x, params)
%TCHPSEUDOVOIGT  Thompson-Cox-Hastings modified pseudo-Voigt profile.
%
%   y = utilities.tchPseudoVoigt(x, params)
%
%   Evaluates the TCH pseudo-Voigt — the standard profile used in
%   Rietveld refinement (GSAS-II, FullProf, TOPAS). Unlike the plain
%   pseudo-Voigt which exposes eta as a free parameter, TCH takes
%   independent Gaussian and Lorentzian FWHM components (fG, fL) and
%   derives the total FWHM f and the mixing parameter eta from them
%   via the empirical polynomial relations of Thompson-Cox-Hastings.
%
%   Parameters:
%       params(1) = H   — peak height above baseline
%       params(2) = x0  — peak center
%       params(3) = fG  — Gaussian FWHM component (sample broadening)
%       params(4) = fL  — Lorentzian FWHM component (size/strain)
%       params(5) = bg  — constant baseline
%
%   Total FWHM:
%       f^5 = fG^5 + 2.69269·fG^4·fL + 2.42843·fG^3·fL^2
%                  + 4.47163·fG^2·fL^3 + 0.07842·fG·fL^4 + fL^5
%
%   Mixing parameter (eta = fraction Lorentzian):
%       r   = fL / f
%       eta = 1.36603·r − 0.47719·r^2 + 0.11116·r^3,  clamped to [0,1]
%
%   Profile:
%       y = H·(eta·L(f) + (1−eta)·G(f)) + bg
%   where L and G use the combined FWHM f.
%
%   AREA (closed form, same as plain pseudo-Voigt with combined f):
%       area = H · f · (eta·pi/2 + (1-eta)·sqrt(pi)/(2·sqrt(ln2)))
%
%   EXAMPLE:
%       x = linspace(28, 32, 500);
%       y = utilities.tchPseudoVoigt(x, [1000, 30, 0.15, 0.05, 10]);
%       plot(x, y);
%
%   REFERENCE:
%       Thompson, P., Cox, D.E., Hastings, J.B.,
%       "Rietveld refinement of Debye-Scherrer synchrotron X-ray data
%        from Al2O3", J. Appl. Cryst. 20, 79–83 (1987).

arguments
    x      (:,:) double
    params (1,5) double
end

H  = params(1);
x0 = params(2);
fG = abs(params(3));
fL = abs(params(4));
bg = params(5);

% Guard against zero widths (would divide by zero in L/G)
if fG < eps && fL < eps
    error('utilities:tchPseudoVoigt:zeroWidth', ...
        'At least one of fG, fL must be > 0.');
end

% Total FWHM via TCH 5th-order polynomial combination
f5 = fG^5 ...
   + 2.69269 * fG^4 * fL ...
   + 2.42843 * fG^3 * fL^2 ...
   + 4.47163 * fG^2 * fL^3 ...
   + 0.07842 * fG   * fL^4 ...
   + fL^5;
f = f5^(1/5);

% Lorentzian fraction from ratio fL/f
r   = fL / f;
eta = 1.36603*r - 0.47719*r^2 + 0.11116*r^3;
eta = max(0, min(1, eta));

% Profile components share the combined FWHM f
dx   = (x - x0) ./ f;
Lpart = 1 ./ (1 + 4 .* dx.^2);
Gpart = exp(-4 * log(2) .* dx.^2);

y = H .* (eta .* Lpart + (1 - eta) .* Gpart) + bg;
end
