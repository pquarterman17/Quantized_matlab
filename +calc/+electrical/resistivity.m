function result = resistivity(Rs, t)
%RESISTIVITY  Compute bulk resistivity from sheet resistance and thickness.
%
%   Syntax:
%     result = calc.electrical.resistivity(Rs, t)
%
%   Inputs:
%     Rs — sheet resistance (Ohm/sq)
%     t  — film thickness (cm)
%
%   Outputs:
%     result — struct with fields:
%       .rho    — bulk resistivity (Ohm·cm)
%       .Rs     — input sheet resistance (Ohm/sq)
%       .t      — input thickness (cm)
%       .latex  — LaTeX-formatted result string
%
%   Formula:
%     rho = Rs * t
%
%   Example:
%     r = calc.electrical.resistivity(500, 2e-5);
%     disp(r.rho)   % 0.01 Ohm·cm

% ════════════════════════════════════════════════════════════════════

arguments
    Rs (1,1) double {mustBePositive}
    t  (1,1) double {mustBePositive}
end

rho = Rs * t;

result.rho   = rho;
result.Rs    = Rs;
result.t     = t;
result.latex = sprintf('$\\rho = %s\\,\\Omega{\\cdot}\\text{cm}$', ...
    formatSci(rho));

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
