function result = mobility(rho, n)
%MOBILITY  Compute carrier mobility from resistivity and carrier concentration.
%
%   Syntax:
%     result = calc.electrical.mobility(rho, n)
%
%   Inputs:
%     rho — bulk resistivity (Ohm·cm)
%     n   — carrier concentration (cm⁻³)
%
%   Outputs:
%     result — struct with fields:
%       .mu     — carrier mobility (cm²/V·s)
%       .rho    — input resistivity (Ohm·cm)
%       .n      — input carrier concentration (cm⁻³)
%       .latex  — LaTeX-formatted result string
%
%   Formula:
%     mu = 1 / (q * n * rho)
%   where q is the elementary charge (C).
%
%   Example:
%     r = calc.electrical.mobility(1e-2, 1e18);
%     disp(r.mu)   % ~62.4 cm²/V·s

% ════════════════════════════════════════════════════════════════════

arguments
    rho (1,1) double {mustBePositive}
    n   (1,1) double {mustBePositive}
end

C  = calc.constants();
mu = 1 / (C.e * n * rho);

result.mu    = mu;
result.rho   = rho;
result.n     = n;
result.latex = sprintf('$\\mu = %s\\,\\text{cm}^2/\\text{V}{\\cdot}\\text{s}$', ...
    formatSci(mu));

end

% ════════════════════════════════════════════════════════════════════
%  LOCAL HELPERS
% ════════════════════════════════════════════════════════════════════

function s = formatSci(val)
%FORMATSCI  Format a scalar as LaTeX scientific notation if |exponent| >= 3.
    exp10 = floor(log10(abs(val)));
    if abs(exp10) >= 3
        mant = val / 10^exp10;
        s = sprintf('%g \\times 10^{%d}', mant, exp10);
    else
        s = sprintf('%g', val);
    end
end
