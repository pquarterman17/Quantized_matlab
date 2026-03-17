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

net = Nd - Na;

if abs(net) < ni
    type = 'intrinsic';
    n    = ni;
    p    = ni;
elseif net > 0
    type = 'n';
    n    = net;
    p    = ni^2 / n;
else
    type = 'p';
    p    = -net;
    n    = ni^2 / p;
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
