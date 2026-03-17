function result = fermiLevel(opts)
%FERMILEVEL  Compute Fermi level position relative to intrinsic level Ei.
%
%   Syntax
%   ------
%   result = calc.semiconductor.fermiLevel(Eg=Eg, Nd=Nd, Na=Na, meStar=me, mhStar=mh)
%   result = calc.semiconductor.fermiLevel(Material='Si', Nd=1e16)
%
%   Inputs
%   ------
%   Eg       — bandgap (eV); overridden by Material preset
%   Nd       — donor concentration (cm⁻³); default 0
%   Na       — acceptor concentration (cm⁻³); default 0
%   meStar   — electron DOS effective mass (in m_e); overridden by Material
%   mhStar   — hole DOS effective mass (in m_e); overridden by Material
%   T        — temperature (K); default 300
%   Material — material name string; auto-fills Eg, meStar, mhStar
%
%   Outputs
%   -------
%   result — struct with fields:
%     .EF    — Fermi level relative to Ei (eV); positive = above Ei
%     .type  — doping type: 'n', 'p', or 'intrinsic'
%     .latex — LaTeX-formatted result string
%
%   Example
%   -------
%   r = calc.semiconductor.fermiLevel(Material='Si', Nd=1e16);
%   fprintf('EF - Ei = %.4f eV\n', r.EF)

% ════════════════════════════════════════════════════════════════════

arguments
    opts.Eg       (1,1) double = NaN
    opts.meStar   (1,1) double = NaN
    opts.mhStar   (1,1) double = NaN
    opts.Nd       (1,1) double {mustBeNonnegative} = 0
    opts.Na       (1,1) double {mustBeNonnegative} = 0
    opts.T        (1,1) double {mustBePositive}    = 300
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
    error('calc:semiconductor:fermiLevel:missingInputs', ...
        'Provide Eg, meStar, mhStar or a valid Material name.');
end

% ════════════════════════════════════════════════════════════════════

C  = calc.constants();
T  = opts.T;
kT = C.kB * T / C.e;      % thermal voltage (eV)

niResult = calc.semiconductor.intrinsicCarrierConc( ...
    'Eg', opts.Eg, 'meStar', opts.meStar, 'mhStar', opts.mhStar, 'T', T);
ni = niResult.ni;

net = opts.Nd - opts.Na;

if abs(net) < ni
    type = 'intrinsic';
    EF   = 0;
elseif net > 0
    type = 'n';
    EF   =  kT * log(net / ni);
else
    type = 'p';
    EF   = -kT * log(-net / ni);
end

result.EF    = EF;
result.type  = type;
result.latex = sprintf('$E_F - E_i = %.4g\\,\\text{eV}$', EF);

end
