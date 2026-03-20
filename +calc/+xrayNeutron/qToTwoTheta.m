function result = qToTwoTheta(Q, opts)
%QTOTTWOTHETA  Convert momentum transfer Q (Å⁻¹) to 2θ (degrees).
%
%   Syntax
%   ------
%   result = calc.xrayNeutron.qToTwoTheta(Q)
%   result = calc.xrayNeutron.qToTwoTheta(Q, Lambda=lambda)
%
%   Inputs
%   ------
%   Q      — momentum transfer (Å⁻¹); scalar or vector
%   Lambda — wavelength (Å); default = 1.5406 (Cu Kα₁)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .twoTheta — diffraction angle 2θ (degrees); same size as Q
%     .Q        — input Q values (Å⁻¹, echoed)
%     .lambda   — wavelength used (Å, echoed)
%     .latex    — LaTeX formula used (string)
%
%   Details
%   -------
%   From Q = 4π sin(θ) / λ:
%       sin(θ) = Q λ / (4π)
%       2θ = 2 arcsin( Q λ / (4π) )
%
%   Q values where Qλ/(4π) > 1 are physically inaccessible and will produce
%   NaN in the output (with a warning).
%
%   Examples
%   --------
%   r = calc.xrayNeutron.qToTwoTheta(3.218);
%   % r.twoTheta ≈ 46.47°  (SrTiO3 (002) at Cu Kα)
%
%   r = calc.xrayNeutron.qToTwoTheta([1 2 3 4]);
%   % vector input → vector .twoTheta

% ════════════════════════════════════════════════════════════════════

arguments
    Q      double {mustBePositive}
    opts.Lambda (1,1) double {mustBePositive} = 1.5406
end

lambda = opts.Lambda;

sinHalfAngle = Q * lambda / (4 * pi);

inaccessible = sinHalfAngle > 1;
if any(inaccessible)
    warning('calc:xrayNeutron:qToTwoTheta:inaccessible', ...
        '%d Q value(s) are inaccessible for λ = %.4g Å (Qλ/4π > 1); set to NaN.', ...
        sum(inaccessible), lambda);
    sinHalfAngle(inaccessible) = NaN;
end

twoTheta = 2 * asind(sinHalfAngle);

result.twoTheta = twoTheta;
result.Q        = Q;
result.lambda   = lambda;
result.latex    = '$2\theta = 2\arcsin\!\left(\dfrac{Q\lambda}{4\pi}\right)$';

end
