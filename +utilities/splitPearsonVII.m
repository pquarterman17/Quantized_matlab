function y = splitPearsonVII(x, params)
%SPLITPEARSONVII  Asymmetric split Pearson VII peak profile for XRD fitting.
%
%   y = utilities.splitPearsonVII(x, params)
%
%   Evaluates a split Pearson VII line profile at each point in x.
%   The model uses independent half-width and shape parameters for the
%   left and right sides of the peak, joined continuously at the center.
%   This captures asymmetric broadening common in XRD Bragg reflections
%   (e.g., from strain gradients, instrumental aberrations, or defects).
%
%   The Pearson VII formula for one side is:
%
%       H * (1 + (2^(1/m) - 1) * ((x - c)/w)^2 )^(-m) + baseline
%
%   where m = 1 gives a Lorentzian, and m -> Inf approaches a Gaussian.
%   The left side (x < center) uses wL, mL; the right side (x >= center)
%   uses wR, mR.
%
%   INPUTS:
%       x      — [Nx1] or [1xN] numeric vector of evaluation positions
%                (e.g., 2-theta values in degrees)
%       params — [1x7] parameter vector:
%                  params(1) = height   — peak amplitude above baseline
%                  params(2) = center   — peak center position
%                  params(3) = wL       — left half-width (FWHM contribution)
%                  params(4) = wR       — right half-width (FWHM contribution)
%                  params(5) = mL       — left shape exponent (1=Lorentzian)
%                  params(6) = mR       — right shape exponent (1=Lorentzian)
%                  params(7) = baseline — constant vertical offset
%
%   OUTPUT:
%       y — same size as x, evaluated profile values
%
%   FWHM:
%       The full width at half maximum of the split profile is simply
%       FWHM = wL + wR, because each w parameter is the half-width at
%       half-max for its respective Pearson VII side.
%
%   AREA ESTIMATION:
%       The split Pearson VII has no simple closed-form integral for
%       general m. Use numerical integration on the result:
%           area = trapz(x, y - params(7));
%
%   EXAMPLES:
%       % Symmetric Lorentzian (m=1, equal widths)
%       x = linspace(28, 32, 500);
%       p = [1000, 30, 0.3, 0.3, 1, 1, 10];
%       y = utilities.splitPearsonVII(x, p);
%       plot(x, y);
%
%       % Asymmetric peak with Gaussian-like left tail
%       p = [5000, 44.5, 0.15, 0.25, 8, 2, 20];
%       y = utilities.splitPearsonVII(x, p);
%
%       % Compute FWHM
%       fwhm = p(3) + p(4);   % wL + wR
%
%       % Estimate integrated area above baseline
%       area = trapz(x, y - p(7));
%
%   REFERENCES:
%       Hall, M.M. et al., "The approximation of symmetric X-ray peaks
%       by Pearson type-VII distributions", J. Appl. Cryst. 10 (1977)
%       66-68.
%
%       Brown, A. & Edmonds, J.W., "The fitting of powder diffraction
%       profiles to an analytical expression and the influence of line
%       broadening factors", Adv. X-Ray Anal. 23 (1980) 361-374.
%
%   See also utilities.normalize, utilities.smoothData

    arguments
        x      (:,1) double {mustBeReal, mustBeFinite}
        params (1,7) double {mustBeReal, mustBeFinite}
    end

    % ════════════════════════════════════════════════════════════════════
    %   Unpack parameters
    % ════════════════════════════════════════════════════════════════════
    H        = params(1);
    center   = params(2);
    wL       = params(3);
    wR       = params(4);
    mL       = params(5);
    mR       = params(6);
    baseline = params(7);

    % ════════════════════════════════════════════════════════════════════
    %   Validate width and shape parameters
    % ════════════════════════════════════════════════════════════════════
    if wL <= 0 || wR <= 0
        error('utilities:splitPearsonVII:badWidth', ...
              'Half-widths wL and wR must be positive.');
    end
    if mL < 0.5 || mR < 0.5
        error('utilities:splitPearsonVII:badShape', ...
              'Shape exponents mL and mR must be >= 0.5.');
    end

    % ════════════════════════════════════════════════════════════════════
    %   Evaluate split profile
    % ════════════════════════════════════════════════════════════════════
    y = zeros(size(x));

    maskL = x < center;
    maskR = ~maskL;

    % Left side (x < center): use wL, mL
    if any(maskL)
        dx = x(maskL) - center;
        kL = (2^(1/mL) - 1);
        y(maskL) = H .* (1 + kL .* (dx ./ wL).^2) .^ (-mL);
    end

    % Right side (x >= center): use wR, mR
    if any(maskR)
        dx = x(maskR) - center;
        kR = (2^(1/mR) - 1);
        y(maskR) = H .* (1 + kR .* (dx ./ wR).^2) .^ (-mR);
    end

    % Add baseline
    y = y + baseline;

end
