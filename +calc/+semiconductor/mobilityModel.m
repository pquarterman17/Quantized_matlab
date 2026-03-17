function result = mobilityModel(opts)
%MOBILITYMODEL  Caughey-Thomas doping- and temperature-dependent mobility.
%
%   Syntax
%   ------
%   result = calc.semiconductor.mobilityModel(Material='Si', N=1e16)
%   result = calc.semiconductor.mobilityModel(Material='Si', N=1e16, T=400)
%
%   Inputs
%   ------
%   Material — material name; currently parameterised for 'Si' (default)
%   T        — temperature (K); default 300
%   N        — total impurity concentration Nd + Na (cm⁻³); default 0
%
%   Outputs
%   -------
%   result — struct with fields:
%     .muE      — electron mobility (cm²/V·s)
%     .muH      — hole mobility (cm²/V·s)
%     .material — material string used
%     .latex    — LaTeX-formatted result string
%
%   Notes
%   -----
%   For non-Si materials the Si coefficients are used as a fallback with a
%   warning. Temperature scaling uses (T/300)^β with β = -2.4 for electrons
%   and β = -2.2 for holes (Sze empirical values for Si).
%
%   Example
%   -------
%   r = calc.semiconductor.mobilityModel(Material='Si', N=1e16);
%   fprintf('muE = %.1f  muH = %.1f cm^2/V.s\n', r.muE, r.muH)

% ════════════════════════════════════════════════════════════════════

arguments
    opts.Material (1,:) char   = 'Si'
    opts.T        (1,1) double {mustBePositive}    = 300
    opts.N        (1,1) double {mustBeNonnegative} = 0
end

mat = opts.Material;
if ~strcmp(mat, 'Si')
    warning('calc:semiconductor:mobilityModel:notParameterised', ...
        'Caughey-Thomas coefficients only available for Si; using Si values.');
    mat = 'Si';
end

% ════════════════════════════════════════════════════════════════════
% Si Caughey-Thomas coefficients
muMin_e  = 88;       muMax_e  = 1252;   Nref_e = 1.26e17;  alpha_e = 0.88;
muMin_h  = 54;       muMax_h  = 407;    Nref_h = 2.35e17;  alpha_h = 0.88;
beta_e   = -2.4;     beta_h   = -2.2;

T    = opts.T;
N    = max(opts.N, 1);   % avoid divide-by-zero; at N→0 result → μ_max

Tscale_e = (T / 300)^beta_e;
Tscale_h = (T / 300)^beta_h;

muE = (muMin_e + (muMax_e - muMin_e) / (1 + (N / Nref_e)^alpha_e)) * Tscale_e;
muH = (muMin_h + (muMax_h - muMin_h) / (1 + (N / Nref_h)^alpha_h)) * Tscale_h;

result.muE      = muE;
result.muH      = muH;
result.material = opts.Material;
result.latex    = sprintf('$\\mu_e = %.4g,\\; \\mu_h = %.4g\\,\\text{cm}^2/\\text{V}{\\cdot}\\text{s}$', muE, muH);

end
