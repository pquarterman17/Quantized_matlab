function result = glParameter(opts)
%GLPARAMETER  Calculate the Ginzburg-Landau parameter kappa = lambda/xi.
%
%   Syntax
%   ------
%   result = calc.superconductor.glParameter(lambda=lam, xi=xi)
%   result = calc.superconductor.glParameter(Material=name, T=T)
%   result = calc.superconductor.glParameter(Material=name, T=T, lambda=lam, xi=xi)
%
%   Inputs
%   ------
%   lambda   — London penetration depth (nm); required unless Material+T given
%   xi       — coherence length (nm); required unless Material+T given
%   Material — (optional) string material name (e.g. 'Nb').  When given,
%              lambda and xi are computed at temperature T from the
%              material presets using londonDepth and coherenceLength.
%   T        — temperature (K); used only when Material is given
%
%   Outputs
%   -------
%   result — struct with fields:
%     .kappa  — GL parameter (dimensionless)
%     .lambda — penetration depth used (nm)
%     .xi     — coherence length used (nm)
%     .type   — 'I' if kappa < 1/sqrt(2), 'II' if kappa >= 1/sqrt(2)
%     .latex  — LaTeX-formatted result string
%
%   Formula
%   -------
%   kappa = lambda / xi
%   Type-I boundary: kappa = 1/sqrt(2) ≈ 0.7071
%
%   Examples
%   --------
%   r = calc.superconductor.glParameter(lambda=39, xi=38);
%   r = calc.superconductor.glParameter(Material='Nb', T=4.2);
%   fprintf('kappa = %.3f (%s)\n', r.kappa, r.type);

% ════════════════════════════════════════════════════════════════════

arguments
    opts.lambda   (1,1) double {mustBePositive} = NaN
    opts.xi       (1,1) double {mustBePositive} = NaN
    opts.Material (1,:) char = ''
    opts.T        (1,1) double = NaN
end

lambda = opts.lambda;
xi     = opts.xi;

if ~isempty(opts.Material)
    if isnan(opts.T)
        error('calc:superconductor:missingParam', ...
              'Provide T when using Material for glParameter.');
    end
    if isnan(lambda)
        rL   = calc.superconductor.londonDepth(Material=opts.Material, T=opts.T);
        lambda = rL.lambda;
    end
    if isnan(xi)
        rX   = calc.superconductor.coherenceLength(Material=opts.Material, T=opts.T);
        xi   = rX.xi;
    end
else
    if isnan(lambda) || isnan(xi)
        error('calc:superconductor:missingParam', ...
              'Provide both lambda and xi, or a Material name with T.');
    end
end

kappa = lambda / xi;

% Type boundary: kappa = 1/sqrt(2)
if kappa < 1/sqrt(2)
    scType = 'I';
else
    scType = 'II';
end

result.kappa  = kappa;
result.lambda = lambda;
result.xi     = xi;
result.type   = scType;
result.latex  = sprintf( ...
    '$\\kappa = \\lambda/\\xi = %.4g\\,\\mathrm{nm}/%.4g\\,\\mathrm{nm} = %.4g$ (Type %s)', ...
    lambda, xi, kappa, scType);
end
