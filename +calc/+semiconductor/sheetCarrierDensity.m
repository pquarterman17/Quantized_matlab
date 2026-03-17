function result = sheetCarrierDensity(n, t)
%SHEETCARRIERDENSITY  Compute sheet carrier density from bulk concentration and thickness.
%
%   Syntax
%   ------
%   result = calc.semiconductor.sheetCarrierDensity(n, t)
%
%   Inputs
%   ------
%   n — bulk carrier concentration (cm⁻³)
%   t — layer thickness (cm)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .ns    — sheet carrier density (cm⁻²)
%     .n     — input bulk concentration (cm⁻³)
%     .t     — input thickness (cm)
%     .latex — LaTeX-formatted result string
%
%   Example
%   -------
%   r = calc.semiconductor.sheetCarrierDensity(1e17, 100e-7);  % 100 nm layer
%   fprintf('ns = %.3e cm^-2\n', r.ns)

% ════════════════════════════════════════════════════════════════════

arguments
    n (1,1) double {mustBePositive}
    t (1,1) double {mustBePositive}
end

ns = n * t;

result.ns    = ns;
result.n     = n;
result.t     = t;
result.latex = sprintf('$n_s = %s\\,\\text{cm}^{-2}$', formatSci(ns));

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
