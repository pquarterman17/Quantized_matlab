function result = fresnelCoefficients(n1, n2, theta)
%FRESNELCOEFFICIENTS  Compute Fresnel reflection and transmission coefficients at an interface.
%
%   Syntax
%   ------
%   result = calc.optics.fresnelCoefficients(n1, n2, theta)
%
%   Inputs
%   ------
%   n1     — complex refractive index of incident medium (scalar)
%   n2     — complex refractive index of transmitted medium (scalar)
%   theta  — angle of incidence (degrees, measured from surface normal; scalar or vector)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .rs    — s-polarisation amplitude reflection coefficient (complex)
%     .rp    — p-polarisation amplitude reflection coefficient (complex)
%     .ts    — s-polarisation amplitude transmission coefficient (complex)
%     .tp    — p-polarisation amplitude transmission coefficient (complex)
%     .Rs    — s-polarisation reflectance |rs|^2
%     .Rp    — p-polarisation reflectance |rp|^2
%     .Ts    — s-polarisation transmittance (real(n2*cos_t)/real(n1*cos_i))*|ts|^2
%     .Tp    — p-polarisation transmittance (real(n2*conj(cos_t))/real(n1*conj(cos_i)))*|tp|^2
%     .theta — input angle(s) in degrees
%     .latex — LaTeX-formatted result string (scalar theta only)
%
%   Notes
%   -----
%   All inputs may be complex (absorbing media). Snell's law is generalised
%   as cos(theta_t) = sqrt(1 - (n1/n2 * sin(theta_i))^2) using the principal
%   branch of sqrt, which gives evanescent waves above the critical angle.
%
%   Examples
%   --------
%   r = calc.optics.fresnelCoefficients(1.0, 1.5, 0);    % normal incidence, air/glass
%   r = calc.optics.fresnelCoefficients(1.5, 1.0, 45);   % glass/air near critical angle
%   r = calc.optics.fresnelCoefficients(1.0, 0.15+3.6i, 45); % air/gold (complex n2)
%   th = 0:0.5:90;
%   r  = calc.optics.fresnelCoefficients(1.0, 1.5, th);  % angular sweep

% ════════════════════════════════════════════════════════════════════

arguments
    n1     (1,1) double
    n2     (1,1) double
    theta  (1,:) double {mustBeNonnegative}
end

thetaRad = deg2rad(theta);
cosI     = cos(thetaRad);
sinI     = sin(thetaRad);

% Generalised Snell's law for complex media
sinT = (n1 ./ n2) .* sinI;
cosT = sqrt(1 - sinT.^2);   % principal sqrt; evanescent if TIR

% Amplitude coefficients
rs = (n1 .* cosI - n2 .* cosT) ./ (n1 .* cosI + n2 .* cosT);
rp = (n2 .* cosI - n1 .* cosT) ./ (n2 .* cosI + n1 .* cosT);
ts = (2 .* n1 .* cosI)         ./ (n1 .* cosI + n2 .* cosT);
tp = (2 .* n1 .* cosI)         ./ (n2 .* cosI + n1 .* cosT);

% Reflectances
Rs = abs(rs).^2;
Rp = abs(rp).^2;

% Transmittances (energy-conserving form; real() extracts propagating part)
Ts = real(n2 .* conj(cosT)) ./ real(n1 .* conj(cosI)) .* abs(ts).^2;
Tp = real(n2 .* conj(cosT)) ./ real(n1 .* conj(cosI)) .* abs(tp).^2;

result.rs    = rs;
result.rp    = rp;
result.ts    = ts;
result.tp    = tp;
result.Rs    = Rs;
result.Rp    = Rp;
result.Ts    = Ts;
result.Tp    = Tp;
result.theta = theta;

if isscalar(theta)
    result.latex = sprintf( ...
        '$\\theta=%.4g^\\circ:\\;R_s=%.4g,\\;R_p=%.4g$', ...
        theta, Rs, Rp);
else
    result.latex = sprintf( ...
        '$n_1=%.4g \\to n_2=%.4g,\\;\\theta \\in [%.4g^\\circ, %.4g^\\circ]$', ...
        real(n1), real(n2), min(theta), max(theta));
end
end
