function result = builtInPotential(Na, Nd, ni, opts)
%BUILTINPOTENTIAL  Compute the built-in potential of a p-n junction.
%
%   Syntax
%   ------
%   result = calc.semiconductor.builtInPotential(Na, Nd, ni)
%   result = calc.semiconductor.builtInPotential(Na, Nd, ni, T=400)
%
%   Inputs
%   ------
%   Na  — acceptor concentration (cm⁻³)
%   Nd  — donor concentration (cm⁻³)
%   ni  — intrinsic carrier concentration (cm⁻³)
%   T   — temperature (K); default 300
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Vbi   — built-in potential (V)
%     .latex — LaTeX-formatted result string
%
%   Example
%   -------
%   ni = calc.semiconductor.intrinsicCarrierConc(Material='Si').ni;
%   r  = calc.semiconductor.builtInPotential(1e16, 1e17, ni);
%   fprintf('Vbi = %.4f V\n', r.Vbi)

% ════════════════════════════════════════════════════════════════════

arguments
    Na  (1,1) double {mustBePositive}
    Nd  (1,1) double {mustBePositive}
    ni  (1,1) double {mustBePositive}
    opts.T (1,1) double {mustBePositive} = 300
end

C   = calc.constants();
kT  = C.kB * opts.T / C.e;   % thermal voltage (eV = V)
Vbi = kT * log(Na * Nd / ni^2);

result.Vbi   = Vbi;
result.latex = sprintf('$V_{bi} = %.4g\\,\\text{V}$', Vbi);

end
