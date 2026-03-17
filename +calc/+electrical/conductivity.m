function result = conductivity(rho)
%CONDUCTIVITY  Compute electrical conductivity from resistivity.
%
%   Syntax:
%     result = calc.electrical.conductivity(rho)
%
%   Inputs:
%     rho — bulk resistivity (Ohm·cm)
%
%   Outputs:
%     result — struct with fields:
%       .sigma  — electrical conductivity (S/cm)
%       .rho    — input resistivity (Ohm·cm)
%       .latex  — LaTeX-formatted result string
%
%   Formula:
%     sigma = 1 / rho
%
%   Example:
%     r = calc.electrical.conductivity(1e-3);
%     disp(r.sigma)   % 1000 S/cm

% ════════════════════════════════════════════════════════════════════

arguments
    rho (1,1) double {mustBePositive}
end

sigma = 1 / rho;

result.sigma = sigma;
result.rho   = rho;
result.latex = sprintf('$\\sigma = %s\\,\\text{S/cm}$', ...
    formatSci(sigma));

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
