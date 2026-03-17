function result = currentDensity(I, area)
%CURRENTDENSITY  Compute current density from current and cross-sectional area.
%
%   Syntax:
%     result = calc.electrical.currentDensity(I, area)
%
%   Inputs:
%     I    — current (A)
%     area — cross-sectional area (cm²)
%
%   Outputs:
%     result — struct with fields:
%       .J      — current density (A/cm²)
%       .I      — input current (A)
%       .area   — input area (cm²)
%       .latex  — LaTeX-formatted result string
%
%   Formula:
%     J = I / area
%
%   Example:
%     r = calc.electrical.currentDensity(0.01, 0.04);
%     disp(r.J)   % 0.25 A/cm²

% ════════════════════════════════════════════════════════════════════

arguments
    I    (1,1) double
    area (1,1) double {mustBePositive}
end

J = I / area;

result.J      = J;
result.I      = I;
result.area   = area;
result.latex  = sprintf('$J = %s\\,\\text{A/cm}^2$', formatSci(J));

end

% ════════════════════════════════════════════════════════════════════
%  LOCAL HELPERS
% ════════════════════════════════════════════════════════════════════

function s = formatSci(val)
%FORMATSCI  Format a scalar as LaTeX scientific notation if |exponent| >= 3.
    if val == 0
        s = '0';
        return
    end
    exp10 = floor(log10(abs(val)));
    if abs(exp10) >= 3
        mant = val / 10^exp10;
        s = sprintf('%g \\times 10^{%d}', mant, exp10);
    else
        s = sprintf('%g', val);
    end
end
