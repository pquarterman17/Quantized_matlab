function result = bohrMagnetonConvert(moment, unit)
%BOHRMAGNETONCONVERT  Convert a magnetic moment to number of Bohr magnetons.
%
%   Syntax:
%     result = calc.magnetic.bohrMagnetonConvert(moment, unit)
%
%   Inputs:
%     moment — magnetic moment value (scalar)
%     unit   — unit string: 'emu', 'Am2', or 'JT'
%                'emu'  — CGS electromagnetic unit (1 emu = 1e-3 A·m²)
%                'Am2'  — SI ampere-square-metre (= J/T)
%                'JT'   — joule per tesla (same as Am2)
%
%   Outputs:
%     result — struct with fields:
%       .muB    — equivalent number of Bohr magnetons
%       .moment — input moment value
%       .unit   — input unit string
%       .latex  — LaTeX-formatted result string
%
%   Constants used:
%     muB_SI = 9.2740100783e-24 J/T = A·m²
%     muB_cgs = 9.2740100783e-21 emu
%
%   Example:
%     r = calc.magnetic.bohrMagnetonConvert(9.2740100783e-21, 'emu');
%     disp(r.muB)   % 1.0
%
%     r = calc.magnetic.bohrMagnetonConvert(1e-20, 'Am2');
%     disp(r.muB)   % ~1.078

% ════════════════════════════════════════════════════════════════════

arguments
    moment (1,1) double
    unit   (1,1) string {mustBeMember(unit, {'emu','Am2','JT'})}
end

muB_SI  = 9.2740100783e-24;    % J/T = A·m²
muB_cgs = 9.2740100783e-21;    % emu

switch unit
    case 'emu'
        muBohr = moment / muB_cgs;
    case {'Am2', 'JT'}
        muBohr = moment / muB_SI;
end

result.muB    = muBohr;
result.moment = moment;
result.unit   = unit;
result.latex  = sprintf('$m = %s\\,\\mu_\\mathrm{B}$', formatSci(muBohr));

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
