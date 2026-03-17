function result = magnetization(moment, volume)
%MAGNETIZATION  Compute magnetization from moment and volume in CGS and SI.
%
%   Syntax:
%     result = calc.magnetic.magnetization(moment, volume)
%
%   Inputs:
%     moment — magnetic moment (emu)
%     volume — sample volume (cm³)
%
%   Outputs:
%     result — struct with fields:
%       .Mcgs  — magnetization in CGS (emu/cm³)
%       .Msi   — magnetization in SI (A/m)
%       .MkAm  — magnetization in SI (kA/m)
%       .latex — LaTeX-formatted result string
%
%   Formulas:
%     M_cgs = moment / volume
%     M_SI  = M_cgs * 1000   (1 emu/cm³ = 1000 A/m)
%
%   Example:
%     r = calc.magnetic.magnetization(2.5e-3, 5e-5);
%     disp(r.Msi)   % A/m

% ════════════════════════════════════════════════════════════════════

arguments
    moment (1,1) double
    volume (1,1) double {mustBePositive}
end

Mcgs = moment / volume;          % emu/cm³
Msi  = Mcgs * 1000;              % A/m  (1 emu/cm³ = 1000 A/m)
MkAm = Msi  / 1000;             % kA/m

result.Mcgs  = Mcgs;
result.Msi   = Msi;
result.MkAm  = MkAm;
result.latex = sprintf('$M = %s\\,\\text{kA/m}$', formatSci(MkAm));

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
