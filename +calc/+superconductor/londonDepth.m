function result = londonDepth(opts)
%LONDONDEPTH  Calculate London penetration depth at temperature T.
%
%   Syntax
%   ------
%   result = calc.superconductor.londonDepth(lambda0=lam, T=T, Tc=Tc)
%   result = calc.superconductor.londonDepth(Material=name, T=T)
%
%   Inputs
%   ------
%   lambda0  — London penetration depth at T=0 (nm); required unless
%              Material is given
%   Tc       — critical temperature (K); required unless Material is given
%   T        — measurement temperature (K); must be < Tc
%   Material — (optional) string material name (e.g. 'Nb').  When given,
%              lambda0 and Tc are loaded from materialPresets; explicit
%              values override the preset.
%
%   Outputs
%   -------
%   result — struct with fields:
%     .lambda  — London penetration depth at T (nm)
%     .lambda0 — penetration depth at T=0 (nm)
%     .T       — temperature (K)
%     .Tc      — critical temperature (K)
%     .latex   — LaTeX-formatted result string
%
%   Formula
%   -------
%   Two-fluid (Gorter-Casimir) approximation:
%     lambda(T) = lambda0 / sqrt(1 - (T/Tc)^4)
%
%   Examples
%   --------
%   r = calc.superconductor.londonDepth(Material='Nb', T=4.2);
%   r = calc.superconductor.londonDepth(lambda0=39, T=4.2, Tc=9.25);
%   fprintf('lambda(4.2 K) = %.1f nm\n', r.lambda);

% ════════════════════════════════════════════════════════════════════

arguments
    opts.lambda0  (1,1) double {mustBePositive} = NaN
    opts.Tc       (1,1) double {mustBePositive} = NaN
    opts.T        (1,1) double {mustBeNonnegative}
    opts.Material (1,:) char = ''
end

% Resolve material presets
[lambda0, Tc] = resolveScParams(opts, 'lambda0', 'Tc');

validateTempBelowTc(opts.T, Tc);

t      = opts.T / Tc;
lambda = lambda0 / sqrt(1 - t^4);

result.lambda  = lambda;
result.lambda0 = lambda0;
result.T       = opts.T;
result.Tc      = Tc;
result.latex   = sprintf( ...
    '$\\lambda(%.4g\\,\\mathrm{K}) = %.4g\\,\\mathrm{nm}$', opts.T, lambda);
end

% ════════════════════════════════════════════════════════════════════

function [v1, v2] = resolveScParams(opts, name1, name2)
%RESOLVESCPARAMS  Load preset fields and override with any explicit values.
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

% ════════════════════════════════════════════════════════════════════

function validateTempBelowTc(T, Tc)
    if T >= Tc
        error('calc:superconductor:normalState', ...
              'T (%.4g K) must be below Tc (%.4g K).', T, Tc);
    end
end
