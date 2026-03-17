function result = depletionWidth(opts)
%DEPLETIONWIDTH  Compute depletion width of a p-n junction.
%
%   Syntax
%   ------
%   result = calc.semiconductor.depletionWidth(epsilon_r=11.7, Vbi=0.7, Na=1e16, Nd=1e17)
%   result = calc.semiconductor.depletionWidth(Material='Si', Vbi=0.7, Na=1e16, Nd=1e17)
%
%   Inputs
%   ------
%   epsilon_r — relative permittivity; overridden by Material preset
%   Vbi       — built-in potential (V)
%   Na        — acceptor concentration (cm⁻³)
%   Nd        — donor concentration (cm⁻³)
%   Material  — material name string; auto-fills epsilon_r
%
%   Outputs
%   -------
%   result — struct with fields:
%     .W     — total depletion width (nm)
%     .Wcm   — total depletion width (cm)
%     .xn    — depletion width on n-side (nm)
%     .xp    — depletion width on p-side (nm)
%     .latex — LaTeX-formatted result string
%
%   Example
%   -------
%   r = calc.semiconductor.depletionWidth(Material='Si', Vbi=0.7, Na=1e16, Nd=1e17);
%   fprintf('W = %.2f nm\n', r.W)

% ════════════════════════════════════════════════════════════════════

arguments
    opts.epsilon_r (1,1) double = NaN
    opts.Vbi       (1,1) double {mustBePositive}
    opts.Na        (1,1) double {mustBePositive}
    opts.Nd        (1,1) double {mustBePositive}
    opts.Material  (1,:) char   = ''
end

if ~isempty(opts.Material)
    m = calc.semiconductor.materialPresets();
    mat = m.(opts.Material);
    if isnan(opts.epsilon_r), opts.epsilon_r = mat.eps_r; end
end

if isnan(opts.epsilon_r)
    error('calc:semiconductor:depletionWidth:missingInputs', ...
        'Provide epsilon_r or a valid Material name.');
end

% ════════════════════════════════════════════════════════════════════

C    = calc.constants();
Na_m3 = opts.Na * 1e6;    % cm^-3 → m^-3
Nd_m3 = opts.Nd * 1e6;

W_m  = sqrt(2 * C.eps0 * opts.epsilon_r * (1/Na_m3 + 1/Nd_m3) * opts.Vbi / C.e);
Wcm  = W_m * 100;          % m → cm
W    = W_m * 1e9;          % m → nm

xn = W * opts.Na / (opts.Na + opts.Nd);
xp = W * opts.Nd / (opts.Na + opts.Nd);

result.W     = W;
result.Wcm   = Wcm;
result.xn    = xn;
result.xp    = xp;
result.latex = sprintf('$W = %.4g\\,\\text{nm}$', W);

end
