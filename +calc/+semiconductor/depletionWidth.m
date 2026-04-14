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
    opts.T         (1,1) double {mustBePositive} = 300   % K, for kT/q term
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

% Sze "Physics of Semiconductor Devices" Ch. 2.2: the exact depletion-
% approximation width includes a -2kT/q correction to Vbi that accounts
% for the tails of the majority carrier distributions at the edges of
% the depletion region. The correction is small at 300 K / Vbi ≈ 0.7 V
% but becomes important near flat-band (small Vbi) and at high T.
kT_over_q = C.kB * opts.T / C.e;             % volts
Vbi_eff   = max(opts.Vbi - 2 * kT_over_q, 0);

W_m  = sqrt(2 * C.eps0 * opts.epsilon_r * (1/Na_m3 + 1/Nd_m3) * Vbi_eff / C.e);
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
