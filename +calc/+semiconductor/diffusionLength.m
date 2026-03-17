function result = diffusionLength(D, tau)
%DIFFUSIONLENGTH  Compute minority-carrier diffusion length.
%
%   Syntax
%   ------
%   result = calc.semiconductor.diffusionLength(D, tau)
%
%   Inputs
%   ------
%   D   — diffusion coefficient (cm²/s)
%   tau — minority-carrier lifetime (s)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .L     — diffusion length (cm)
%     .Lum   — diffusion length (μm)
%     .D     — input diffusion coefficient (cm²/s)
%     .tau   — input lifetime (s)
%     .latex — LaTeX-formatted result string
%
%   Formula
%   -------
%   L = sqrt(D · τ)
%
%   Example
%   -------
%   r = calc.semiconductor.diffusionLength(25, 1e-6);
%   fprintf('L = %.2f um\n', r.Lum)

% ════════════════════════════════════════════════════════════════════

arguments
    D   (1,1) double {mustBePositive}
    tau (1,1) double {mustBePositive}
end

L    = sqrt(D * tau);
Lum  = L * 1e4;            % cm → μm

result.L     = L;
result.Lum   = Lum;
result.D     = D;
result.tau   = tau;
result.latex = sprintf('$L = %.4g\\,\\mu\\text{m}$', Lum);

end
