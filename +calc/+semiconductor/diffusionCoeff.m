function result = diffusionCoeff(mu, opts)
%DIFFUSIONCOEFF  Compute diffusion coefficient via the Einstein relation.
%
%   Syntax
%   ------
%   result = calc.semiconductor.diffusionCoeff(mu)
%   result = calc.semiconductor.diffusionCoeff(mu, T=400)
%
%   Inputs
%   ------
%   mu — carrier mobility (cm²/V·s)
%   T  — temperature (K); default 300
%
%   Outputs
%   -------
%   result — struct with fields:
%     .D     — diffusion coefficient (cm²/s)
%     .mu    — input mobility (cm²/V·s)
%     .T     — temperature used (K)
%     .latex — LaTeX-formatted result string
%
%   Formula
%   -------
%   D = μ · kB · T / q
%
%   Example
%   -------
%   r = calc.semiconductor.diffusionCoeff(1400);
%   fprintf('D = %.4f cm^2/s\n', r.D)

% ════════════════════════════════════════════════════════════════════

arguments
    mu      (1,1) double {mustBePositive}
    opts.T  (1,1) double {mustBePositive} = 300
end

C = calc.constants();
D = mu * C.kB * opts.T / C.e;

result.D     = D;
result.mu    = mu;
result.T     = opts.T;
result.latex = sprintf('$D = %.4g\\,\\text{cm}^2/\\text{s}$', D);

end
