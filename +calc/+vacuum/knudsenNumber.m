function result = knudsenNumber(mfp, L)
%KNUDSENNUMBER  Compute the Knudsen number and identify the flow regime.
%
%   Syntax
%   ------
%   result = calc.vacuum.knudsenNumber(mfp, L)
%
%   Inputs
%   ------
%   mfp — mean free path (m)
%   L   — characteristic length (m)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Kn     — Knudsen number (dimensionless)
%     .regime — flow regime string: 'molecular', 'transition', or 'viscous'
%     .mfp    — input mean free path (m)
%     .L      — input characteristic length (m)
%     .latex  — LaTeX-formatted result string
%
%   Examples
%   --------
%   r = calc.vacuum.knudsenNumber(0.05, 0.1);   % transition regime
%   r = calc.vacuum.knudsenNumber(1e-2, 1e-4);  % molecular flow (Kn > 1)

% ════════════════════════════════════════════════════════════════════

arguments
    mfp (1,1) double {mustBePositive}
    L   (1,1) double {mustBePositive}
end

Kn = mfp / L;

if Kn > 1
    regime = 'molecular';
elseif Kn >= 0.01
    regime = 'transition';
else
    regime = 'viscous';
end

result.Kn     = Kn;
result.regime = regime;
result.mfp    = mfp;
result.L      = L;
result.latex  = sprintf('$K_n = %.4g$ (%s)', Kn, regime);
end
