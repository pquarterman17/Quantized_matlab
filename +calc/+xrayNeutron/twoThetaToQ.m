function result = twoThetaToQ(twoTheta, opts)
%TWOTHETATOQ  Convert diffraction angle 2θ (degrees) to Q (Å⁻¹).
%
%   Syntax
%   ------
%   result = calc.xrayNeutron.twoThetaToQ(twoTheta)
%   result = calc.xrayNeutron.twoThetaToQ(twoTheta, Lambda=lambda)
%
%   Inputs
%   ------
%   twoTheta — diffraction angle (degrees); scalar or vector
%   Lambda   — wavelength (Å); default = 1.5406 (Cu Kα₁)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Q        — momentum transfer (Å⁻¹); same size as twoTheta
%     .twoTheta — input angles (degrees, echoed)
%     .lambda   — wavelength used (Å, echoed)
%     .latex    — LaTeX formula used (string)
%
%   Details
%   -------
%   Q = 4π sin(θ) / λ  where θ = twoTheta / 2
%
%   Examples
%   --------
%   r = calc.xrayNeutron.twoThetaToQ(46.47);
%   % r.Q ≈ 3.218 Å⁻¹  (SrTiO3 (002) at Cu Kα)
%
%   r = calc.xrayNeutron.twoThetaToQ(10:5:80);
%   % vector input → vector .Q

% ════════════════════════════════════════════════════════════════════

arguments
    twoTheta double {mustBePositive}
    opts.Lambda (1,1) double {mustBePositive} = 1.5406
end

lambda = opts.Lambda;

Q = 4 * pi * sind(twoTheta / 2) / lambda;

result.Q        = Q;
result.twoTheta = twoTheta;
result.lambda   = lambda;
result.latex    = '$Q = \dfrac{4\pi\sin\theta}{\lambda}$';

end
