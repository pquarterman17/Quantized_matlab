function y = pseudoVoigt(x, x0, fwhm, H, eta, bg)
% PSEUDOVOIGT  Evaluate a pseudo-Voigt peak function at x.
%
% Syntax:
%   y = utilities.pseudoVoigt(x, x0, fwhm, H, eta, bg)
%
% Inputs:
%   x    - evaluation points (numeric vector)
%   x0   - peak centre
%   fwhm - full-width at half-maximum (same units as x)
%   H    - peak amplitude above background
%   eta  - Lorentzian fraction in [0, 1]  (0 = pure Gaussian, 1 = pure Lorentzian)
%   bg   - constant background level
%
% Output:
%   y = H * [eta * L(x) + (1-eta) * G(x)] + bg
%
%   where:
%     L(x) = 1 / (1 + 4*((x - x0)/fwhm)^2)          — normalised Lorentzian
%     G(x) = exp(-4*log(2)*((x - x0)/fwhm)^2)        — normalised Gaussian
%
% Notes:
%   Both L and G equal 1 at x = x0 and 0.5 at x = x0 ± fwhm/2, so H is the
%   true height above background regardless of eta.
%
% Examples:
%   x = linspace(-2, 2, 500);
%   y = utilities.pseudoVoigt(x, 0, 0.5, 100, 0.6, 5);   % 60% Lorentzian
%   plot(x, y)
%
% Analytical area:
%   area = H * fwhm * (eta * pi/2  +  (1-eta) * sqrt(pi) / (2*sqrt(log(2))))
%
% See also: +utilities/normalize.m, +utilities/smoothData.m

    arguments
        x    (1,:) double
        x0   (1,1) double
        fwhm (1,1) double {mustBePositive}
        H    (1,1) double
        eta  (1,1) double {mustBeInRange(eta, 0, 1)}
        bg   (1,1) double = 0
    end

    u = (x - x0) ./ fwhm;
    L = 1 ./ (1 + 4 .* u.^2);
    G = exp(-4 .* log(2) .* u.^2);
    y = H .* (eta .* L + (1 - eta) .* G) + bg;

end
