function result = debyeLength(opts)
%DEBYELENGTH  Compute the Debye screening length in a semiconductor.
%
%   Syntax
%   ------
%   result = calc.semiconductor.debyeLength(epsilon_r=11.7, T=300, n=1e16)
%   result = calc.semiconductor.debyeLength(Material='Si', n=1e16)
%
%   Inputs
%   ------
%   epsilon_r — relative permittivity; overridden by Material preset
%   T         — temperature (K); default 300
%   n         — carrier concentration (cm⁻³)
%   Material  — material name string; auto-fills epsilon_r
%
%   Outputs
%   -------
%   result — struct with fields:
%     .LD    — Debye length (nm)
%     .LDcm  — Debye length (cm)
%     .latex — LaTeX-formatted result string
%
%   Example
%   -------
%   r = calc.semiconductor.debyeLength(Material='Si', n=1e16);
%   fprintf('LD = %.2f nm\n', r.LD)

% ════════════════════════════════════════════════════════════════════

arguments
    opts.epsilon_r (1,1) double = NaN
    opts.T         (1,1) double {mustBePositive}    = 300
    opts.n         (1,1) double {mustBePositive}
    opts.Material  (1,:) char   = ''
end

if ~isempty(opts.Material)
    m = calc.semiconductor.materialPresets();
    mat = m.(opts.Material);
    if isnan(opts.epsilon_r), opts.epsilon_r = mat.eps_r; end
end

if isnan(opts.epsilon_r)
    error('calc:semiconductor:debyeLength:missingInputs', ...
        'Provide epsilon_r or a valid Material name.');
end

% ════════════════════════════════════════════════════════════════════

C   = calc.constants();
n_m3 = opts.n * 1e6;       % cm^-3 → m^-3

LDm  = sqrt(C.eps0 * opts.epsilon_r * C.kB * opts.T / (C.e^2 * n_m3));
LDcm = LDm * 100;
LD   = LDm * 1e9;          % m → nm

result.LD    = LD;
result.LDcm  = LDcm;
result.latex = sprintf('$L_D = %.4g\\,\\text{nm}$', LD);

end
