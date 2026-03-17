function result = hallCoefficient(n, p, mu_e, mu_h)
%HALLCOEFFICIENT  Compute the Hall coefficient for mixed conduction.
%
%   Syntax
%   ------
%   result = calc.semiconductor.hallCoefficient(n, p, mu_e, mu_h)
%
%   Inputs
%   ------
%   n    — electron concentration (cm⁻³)
%   p    — hole concentration (cm⁻³)
%   mu_e — electron mobility (cm²/V·s)
%   mu_h — hole mobility (cm²/V·s)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .RH           — Hall coefficient (cm³/C)
%     .apparentType — apparent carrier type: 'n' or 'p'
%     .latex        — LaTeX-formatted result string
%
%   Formula
%   -------
%   RH = (1/q) · (p·μh² - n·μe²) / (p·μh + n·μe)²
%
%   Example
%   -------
%   r = calc.semiconductor.hallCoefficient(1e16, 1e4, 1400, 450);
%   fprintf('RH = %.4g cm^3/C\n', r.RH)

% ════════════════════════════════════════════════════════════════════

arguments
    n    (1,1) double {mustBeNonnegative}
    p    (1,1) double {mustBeNonnegative}
    mu_e (1,1) double {mustBePositive}
    mu_h (1,1) double {mustBePositive}
end

C  = calc.constants();
q  = C.e;

RH = (1/q) * (p * mu_h^2 - n * mu_e^2) / (p * mu_h + n * mu_e)^2;

if RH < 0
    apparentType = 'n';
else
    apparentType = 'p';
end

result.RH           = RH;
result.apparentType = apparentType;
result.latex        = sprintf('$R_H = %s\\,\\text{cm}^3/\\text{C}$', formatSci(RH));

end

% ════════════════════════════════════════════════════════════════════

function s = formatSci(val)
    exp10 = floor(log10(abs(val)));
    if abs(exp10) >= 3
        mant = val / 10^exp10;
        s = sprintf('%.3g \\times 10^{%d}', mant, exp10);
    else
        s = sprintf('%.4g', val);
    end
end
