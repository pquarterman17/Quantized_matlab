function result = thermalVelocity(mStar, opts)
%THERMALVELOCITY  Compute the thermal velocity of carriers.
%
%   Syntax
%   ------
%   result = calc.semiconductor.thermalVelocity(mStar)
%   result = calc.semiconductor.thermalVelocity(mStar, T=400)
%
%   Inputs
%   ------
%   mStar — effective mass in units of m_e (free electron mass)
%   T     — temperature (K); default 300
%
%   Outputs
%   -------
%   result — struct with fields:
%     .vth   — thermal velocity (cm/s)
%     .mStar — input effective mass (in m_e)
%     .T     — temperature used (K)
%     .latex — LaTeX-formatted result string
%
%   Formula
%   -------
%   vth = sqrt(3 · kB · T / (mStar · m_e))
%
%   Example
%   -------
%   r = calc.semiconductor.thermalVelocity(0.26);   % Si electron m*
%   fprintf('vth = %.3e cm/s\n', r.vth)

% ════════════════════════════════════════════════════════════════════

arguments
    mStar   (1,1) double {mustBePositive}
    opts.T  (1,1) double {mustBePositive} = 300
end

C    = calc.constants();
vth_m = sqrt(3 * C.kB * opts.T / (mStar * C.m_e));
vth  = vth_m * 100;        % m/s → cm/s

result.vth   = vth;
result.mStar = mStar;
result.T     = opts.T;
result.latex = sprintf('$v_{th} = %s\\,\\text{cm/s}$', formatSci(vth));

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
