function result = coherenceLength(opts)
%COHERENCELENGTH  Calculate BCS coherence length at temperature T.
%
%   Syntax
%   ------
%   result = calc.superconductor.coherenceLength(xi0=xi0, T=T, Tc=Tc)
%   result = calc.superconductor.coherenceLength(Material=name, T=T)
%
%   Inputs
%   ------
%   xi0      — BCS coherence length at T=0 (nm); required unless Material
%              is given
%   Tc       — critical temperature (K); required unless Material is given
%   T        — measurement temperature (K); must be < Tc
%   Material — (optional) string material name (e.g. 'Nb').  When given,
%              xi0 and Tc are loaded from materialPresets; explicit values
%              override the preset.
%
%   Outputs
%   -------
%   result — struct with fields:
%     .xi   — coherence length at T (nm)
%     .xi0  — coherence length at T=0 (nm)
%     .T    — temperature (K)
%     .Tc   — critical temperature (K)
%     .latex — LaTeX-formatted result string
%
%   Formula
%   -------
%   Approximate Gorkov temperature dependence (dirty limit):
%     xi(T) = xi0 / sqrt(1 - (T/Tc)^2)
%
%   Note: the clean-limit BCS result diverges at Tc as (1-T/Tc)^(-1/2),
%   identical in exponent. The factor above is the standard textbook
%   GL-regime expression and is appropriate near Tc.
%
%   Examples
%   --------
%   r = calc.superconductor.coherenceLength(Material='Nb', T=4.2);
%   r = calc.superconductor.coherenceLength(xi0=38, T=4.2, Tc=9.25);
%   fprintf('xi(4.2 K) = %.1f nm\n', r.xi);

% ════════════════════════════════════════════════════════════════════

arguments
    opts.xi0      (1,1) double {mustBePositive} = NaN
    opts.Tc       (1,1) double {mustBePositive} = NaN
    opts.T        (1,1) double {mustBeNonnegative}
    opts.Material (1,:) char = ''
end

[xi0, Tc] = resolveScParams(opts, 'xi0', 'Tc');

if opts.T >= Tc
    error('calc:superconductor:normalState', ...
          'T (%.4g K) must be below Tc (%.4g K).', opts.T, Tc);
end

t    = opts.T / Tc;
xi   = xi0 / sqrt(1 - t^2);

result.xi    = xi;
result.xi0   = xi0;
result.T     = opts.T;
result.Tc    = Tc;
result.latex = sprintf( ...
    '$\\xi(%.4g\\,\\mathrm{K}) = %.4g\\,\\mathrm{nm}$', opts.T, xi);
end

% ════════════════════════════════════════════════════════════════════

function [v1, v2] = resolveScParams(opts, name1, name2)
    if ~isempty(opts.Material)
        preset = calc.superconductor.materialPresets(Material=opts.Material);
    else
        preset = struct();
    end

    if isnan(opts.(name1))
        if isfield(preset, name1)
            v1 = preset.(name1);
        else
            error('calc:superconductor:missingParam', ...
                  'Provide ''%s'' or a Material name.', name1);
        end
    else
        v1 = opts.(name1);
    end

    if isnan(opts.(name2))
        if isfield(preset, name2)
            v2 = preset.(name2);
        else
            error('calc:superconductor:missingParam', ...
                  'Provide ''%s'' or a Material name.', name2);
        end
    else
        v2 = opts.(name2);
    end
end
