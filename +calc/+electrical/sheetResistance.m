function result = sheetResistance(rho, t)
%SHEETRESISTANCE  Compute sheet resistance from bulk resistivity and thickness.
%
%   Syntax:
%     result = calc.electrical.sheetResistance(rho, t)
%
%   Inputs:
%     rho — bulk resistivity (Ohm·cm)
%     t   — film thickness (cm)
%
%   Outputs:
%     result — struct with fields:
%       .Rs     — sheet resistance (Ohm/sq)
%       .rho    — input resistivity (Ohm·cm)
%       .t      — input thickness (cm)
%       .latex  — LaTeX-formatted result string
%
%   Formula:
%     Rs = rho / t
%
%   Example:
%     r = calc.electrical.sheetResistance(1e-3, 2e-5);
%     disp(r.Rs)   % 50 Ohm/sq

% ════════════════════════════════════════════════════════════════════

arguments
    rho (1,1) double {mustBePositive}
    t   (1,1) double {mustBePositive}
end

Rs = rho / t;

result.Rs    = Rs;
result.rho   = rho;
result.t     = t;
result.latex = sprintf('$R_s = %s\\,\\Omega/\\square$', formatSci(Rs));

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
