function result = carrierConcentration(Nd, Na, ni)
%CARRIERCONCENTRATION  Compute majority/minority carrier concentrations.
%
%   Syntax
%   ------
%   result = calc.semiconductor.carrierConcentration(Nd, Na, ni)
%
%   Inputs
%   ------
%   Nd — donor concentration (cm⁻³)
%   Na — acceptor concentration (cm⁻³)
%   ni — intrinsic carrier concentration (cm⁻³)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .n     — electron concentration (cm⁻³)
%     .p     — hole concentration (cm⁻³)
%     .type  — doping type: 'n', 'p', or 'intrinsic'
%     .latex — LaTeX-formatted result string
%
%   Example
%   -------
%   r = calc.semiconductor.carrierConcentration(1e16, 0, 1.5e10);
%   fprintf('n = %.3e, p = %.3e\n', r.n, r.p)

% ════════════════════════════════════════════════════════════════════

arguments
    Nd (1,1) double {mustBeNonnegative}
    Na (1,1) double {mustBeNonnegative}
    ni (1,1) double {mustBePositive}
end

% Charge-neutrality + mass-action law, solved exactly:
%   n - p = Nd - Na      (charge neutrality)
%   n * p = ni^2          (mass action, non-degenerate limit)
% ==> n  = ((Nd-Na) + sqrt((Nd-Na)^2 + 4*ni^2)) / 2
%     p  = ni^2 / n
% This smoothly interpolates between intrinsic (|Nd-Na| << ni) and
% extrinsic (|Nd-Na| >> ni) regimes without a discrete branch that
% discontinuously flips near |net| ≈ ni.  Sze "Physics of Semiconductor
% Devices" 3rd ed. Ch. 1.5.
net = Nd - Na;
n = 0.5 * (net + sqrt(net^2 + 4 * ni^2));
p = ni^2 / n;

if abs(net) < 0.1 * ni
    type = 'intrinsic';
elseif net > 0
    type = 'n';
else
    type = 'p';
end

result.n     = n;
result.p     = p;
result.type  = type;
result.latex = sprintf('$n = %s,\\; p = %s\\,\\text{cm}^{-3}$', ...
    formatSci(n), formatSci(p));

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
