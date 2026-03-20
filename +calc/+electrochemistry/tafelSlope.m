function result = tafelSlope(alpha, opts)
%TAFELSLOPE  Compute the Tafel slope for an electrode reaction.
%
%   Syntax
%   ------
%   result = calc.electrochemistry.tafelSlope(alpha)
%   result = calc.electrochemistry.tafelSlope(alpha, T=T)
%
%   Inputs
%   ------
%   alpha — transfer coefficient (dimensionless, 0 < alpha < 1)
%   T     — temperature (K); default = 298.15
%
%   Outputs
%   -------
%   result — struct with fields:
%     .b     — Tafel slope (V/decade)
%     .bMv   — Tafel slope (mV/decade)
%     .latex — LaTeX-formatted result string
%
%   Notes
%   -----
%   The Tafel slope is defined as b = 2.303 * R * T / (alpha * F).
%   At 25 °C with alpha = 0.5, b ≈ 118 mV/dec (anodic branch).
%   For the cathodic branch substitute (1 - alpha) for alpha.
%
%   Examples
%   --------
%   r = calc.electrochemistry.tafelSlope(0.5);        % 25 °C, anodic
%   r = calc.electrochemistry.tafelSlope(0.5, T=333); % 60 °C

% ════════════════════════════════════════════════════════════════════

arguments
    alpha (1,1) double {mustBeGreaterThan(alpha, 0), mustBeLessThan(alpha, 1)}
    opts.T (1,1) double {mustBePositive} = 298.15
end

C = calc.constants();

b    = 2.303 * C.R * opts.T / (alpha * C.F);
bMv  = b * 1000;

result.b     = b;
result.bMv   = bMv;
result.latex = sprintf('$b = %.4g\\,\\text{mV/dec}$', bMv);
end
