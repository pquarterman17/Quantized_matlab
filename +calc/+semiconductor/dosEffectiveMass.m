function result = dosEffectiveMass(opts)
%DOSEFFECTIVEMASS  Look up DOS effective mass for a material and carrier type.
%
%   Syntax
%   ------
%   result = calc.semiconductor.dosEffectiveMass(Material='Si', Carrier='e')
%
%   Inputs
%   ------
%   Material — material name string (e.g. 'Si', 'GaAs'); required
%   Carrier  — 'e' for electrons, 'h' for holes; default 'e'
%
%   Outputs
%   -------
%   result — struct with fields:
%     .mStar   — DOS effective mass (in units of m_e)
%     .material — material name string
%     .carrier  — carrier type string ('e' or 'h')
%     .latex    — LaTeX-formatted result string
%
%   Example
%   -------
%   r = calc.semiconductor.dosEffectiveMass(Material='GaAs', Carrier='e');
%   fprintf('m* = %.3f m0\n', r.mStar)

% ════════════════════════════════════════════════════════════════════

arguments
    opts.Material (1,:) char = ''
    opts.Carrier  (1,:) char {mustBeMember(opts.Carrier, {'e','h'})} = 'e'
end

if isempty(opts.Material)
    error('calc:semiconductor:dosEffectiveMass:missingMaterial', ...
        'Material name-value argument is required.');
end

m   = calc.semiconductor.materialPresets();
mat = m.(opts.Material);

if strcmp(opts.Carrier, 'e')
    mStar = mat.me;
    sym   = 'm_e^*';
else
    mStar = mat.mh;
    sym   = 'm_h^*';
end

if isnan(mStar)
    error('calc:semiconductor:dosEffectiveMass:notAvailable', ...
        'Hole effective mass not available for %s.', opts.Material);
end

result.mStar    = mStar;
result.material = opts.Material;
result.carrier  = opts.Carrier;
result.latex    = sprintf('$%s = %.3g\\,m_0$', sym, mStar);

end
