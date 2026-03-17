function result = criticalThickness(aFilm, aSub, opts)
%CRITICALTHICKNESS  Estimate the Matthews-Blakeslee critical thickness for misfit dislocations.
%
%   Syntax
%   ------
%   result = calc.crystal.criticalThickness(aFilm, aSub)
%   result = calc.crystal.criticalThickness(aFilm, aSub, nu=nu)
%
%   Inputs
%   ------
%   aFilm — relaxed lattice parameter of the film (Angstroms)
%   aSub  — lattice parameter of the substrate (Angstroms)
%   nu    — Poisson ratio of the film; default = 0.3
%
%   Outputs
%   -------
%   result — struct with fields:
%     .hc            — critical thickness (Angstroms)
%     .hcNm          — critical thickness (nm)
%     .mismatch      — fractional mismatch f
%     .burgersVector — Burgers vector magnitude b (Angstroms)
%     .latex         — LaTeX-formatted result string
%
%   Method
%   ------
%   Matthews-Blakeslee model for FCC {110}<-110> slip system:
%     h_c = (b / (2*pi*f)) * (1 - nu*cos^2(alpha)) / ((1+nu)*cos(lambda))
%           * (ln(h_c/b) + 1)
%   where b = a/sqrt(2), alpha = 60 deg (angle between dislocation and
%   Burgers vector), lambda = 60 deg (angle between Burgers vector and
%   direction in the interface normal to the line of intersection).
%   Solved iteratively starting from h_c = 1000 Ang.
%
%   Examples
%   --------
%   % InGaAs on GaAs: aFilm=5.869 Ang (In0.2), aSub=5.653 Ang
%   r = calc.crystal.criticalThickness(5.869, 5.653);

% ════════════════════════════════════════════════════════════════════

arguments
    aFilm (1,1) double {mustBePositive}
    aSub  (1,1) double {mustBePositive}
    opts.nu (1,1) double {mustBeNonnegative} = 0.3
end

nu = opts.nu;
f  = abs((aFilm - aSub) / aSub);

if f < 1e-10
    % Perfectly matched — critical thickness is infinite
    result.hc            = Inf;
    result.hcNm          = Inf;
    result.mismatch      = 0;
    result.burgersVector = aFilm / sqrt(2);
    result.latex         = '$h_c = \infty$ (lattice-matched)';
    return
end

b      = aFilm / sqrt(2);        % {110}<-110> Burgers vector
alpha  = deg2rad(60);             % dislocation character angle
lambda = deg2rad(60);             % Schmid factor angle

prefactor = (b / (2*pi*f)) * (1 - nu*cos(alpha)^2) / ((1+nu)*cos(lambda));

% Iterative solution of hc = prefactor * (ln(hc/b) + 1)
hc = 1000;  % initial guess (Ang)
for i = 1:50
    hc = prefactor * (log(hc / b) + 1);
    if hc <= 0
        hc = b;
        break
    end
end

result.hc            = hc;
result.hcNm          = hc / 10;
result.mismatch      = (aFilm - aSub) / aSub;
result.burgersVector = b;
result.latex = sprintf('$h_c = %.4g\\,\\text{\\AA} = %.4g\\,\\text{nm}$', hc, hc/10);
end
