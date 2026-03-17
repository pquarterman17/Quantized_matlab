function result = intrinsicCarrierConc(opts)
%INTRINSICCARRIERCONC  Compute intrinsic carrier concentration ni.
%
%   Syntax
%   ------
%   result = calc.semiconductor.intrinsicCarrierConc(Eg=Eg, meStar=me, mhStar=mh)
%   result = calc.semiconductor.intrinsicCarrierConc(Material='Si')
%   result = calc.semiconductor.intrinsicCarrierConc(Material='GaAs', T=400)
%
%   Inputs
%   ------
%   Eg       — bandgap (eV); overridden by Material preset if given
%   meStar   — electron DOS effective mass (in m_e); overridden by Material
%   mhStar   — hole DOS effective mass (in m_e); overridden by Material
%   T        — temperature (K); default 300
%   Material — material name string (e.g. 'Si'); auto-fills Eg, meStar, mhStar
%
%   Outputs
%   -------
%   result — struct with fields:
%     .ni    — intrinsic carrier concentration (cm⁻³)
%     .Nc    — conduction band effective DOS (cm⁻³)
%     .Nv    — valence band effective DOS (cm⁻³)
%     .Eg    — bandgap used (eV)
%     .T     — temperature used (K)
%     .latex — LaTeX-formatted result string
%
%   Example
%   -------
%   r = calc.semiconductor.intrinsicCarrierConc(Material='Si');
%   fprintf('ni(Si,300K) = %.3e cm^-3\n', r.ni)

% ════════════════════════════════════════════════════════════════════

arguments
    opts.Eg       (1,1) double = NaN
    opts.meStar   (1,1) double = NaN
    opts.mhStar   (1,1) double = NaN
    opts.T        (1,1) double {mustBePositive} = 300
    opts.Material (1,:) char   = ''
end

if ~isempty(opts.Material)
    m = calc.semiconductor.materialPresets();
    mat = m.(opts.Material);
    if isnan(opts.Eg),     opts.Eg     = mat.Eg; end
    if isnan(opts.meStar), opts.meStar = mat.me; end
    if isnan(opts.mhStar), opts.mhStar = mat.mh; end
end

if any(isnan([opts.Eg, opts.meStar, opts.mhStar]))
    error('calc:semiconductor:intrinsicCarrierConc:missingInputs', ...
        'Provide Eg, meStar, mhStar or a valid Material name.');
end

% ════════════════════════════════════════════════════════════════════

C  = calc.constants();
T  = opts.T;
Eg = opts.Eg;

% Effective DOS masses in kg
me_kg = opts.meStar * C.m_e;
mh_kg = opts.mhStar * C.m_e;

% Effective density of states (m^-3 → convert to cm^-3)
Nc_m3 = 2 * (2*pi * me_kg * C.kB * T / C.h^2)^(3/2);
Nv_m3 = 2 * (2*pi * mh_kg * C.kB * T / C.h^2)^(3/2);
Nc = Nc_m3 * 1e-6;
Nv = Nv_m3 * 1e-6;

ni = sqrt(Nc * Nv) * exp(-Eg * C.e / (2 * C.kB * T));

result.ni    = ni;
result.Nc    = Nc;
result.Nv    = Nv;
result.Eg    = Eg;
result.T     = T;
result.latex = sprintf('$n_i = %s\\,\\text{cm}^{-3}$', formatSci(ni));

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
