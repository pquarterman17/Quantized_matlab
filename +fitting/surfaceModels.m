function catalog = surfaceModels()
%SURFACEMODELS  Built-in 2D surface model library for surface fitting.
%
%   Syntax
%     catalog = fitting.surfaceModels()
%
%   Returns a struct array where each element defines a named 2D model:
%       .name        — display name (e.g. '2D Gaussian')
%       .func        — function handle f(p, x, y) → z  (column vector)
%       .paramNames  — cell array of parameter name strings
%       .nParams     — number of parameters
%       .description — human-readable equation string
%
%   Example
%       cat = fitting.surfaceModels();
%       m = cat(strcmp({cat.name}, '2D Gaussian'));
%       z = m.func(p, xVec, yVec);

% ════════════════════════════════════════════════════════════════════════
% Helper to build one model entry
% ════════════════════════════════════════════════════════════════════════
    function m = mdl(name, func, paramNames, description)
        m.name        = name;
        m.func        = func;
        m.paramNames  = paramNames;
        m.nParams     = numel(paramNames);
        m.description = description;
    end

catalog = [ ...
    % ── Plane ─────────────────────────────────────────────────────────
    mdl('Plane', ...
        @(p,x,y) p(1)*x + p(2)*y + p(3), ...
        {'a','b','c'}, ...
        'z = a·x + b·y + c')

    % ── Paraboloid ────────────────────────────────────────────────────
    mdl('Paraboloid', ...
        @(p,x,y) p(1)*x.^2 + p(2)*y.^2 + p(3)*x.*y + p(4)*x + p(5)*y + p(6), ...
        {'a','b','c','d','e','f'}, ...
        'z = a·x² + b·y² + c·xy + d·x + e·y + f')

    % ── 2D Gaussian ───────────────────────────────────────────────────
    mdl('2D Gaussian', ...
        @(p,x,y) p(1)*exp(-((x-p(2)).^2/(2*max(p(3),eps)^2) + ...
                             (y-p(4)).^2/(2*max(p(5),eps)^2))) + p(6), ...
        {'A','x0','sx','y0','sy','z0'}, ...
        'z = A·exp(-((x-x0)²/(2σx²) + (y-y0)²/(2σy²))) + z0')

    % ── 2D Lorentzian ─────────────────────────────────────────────────
    mdl('2D Lorentzian', ...
        @(p,x,y) p(1) ./ (1 + ((x-p(2))./max(p(3),eps)).^2 + ...
                              ((y-p(4))./max(p(5),eps)).^2) + p(6), ...
        {'A','x0','wx','y0','wy','z0'}, ...
        'z = A / (1 + ((x-x0)/wx)² + ((y-y0)/wy)²) + z0')

    % ── 2D Pseudo-Voigt ───────────────────────────────────────────────
    mdl('2D Pseudo-Voigt', ...
        @pseudoVoigt2D, ...
        {'A','x0','wx','y0','wy','z0','eta'}, ...
        'z = η·Lorentzian + (1-η)·Gaussian + z0  (0 ≤ η ≤ 1)')

    % ── Polynomial 2D (order 2) ───────────────────────────────────────
    mdl('Polynomial 2D', ...
        @(p,x,y) p(1) + p(2)*x + p(3)*y + p(4)*x.^2 + p(5)*x.*y + p(6)*y.^2, ...
        {'a00','a10','a01','a20','a11','a02'}, ...
        'z = a00 + a10·x + a01·y + a20·x² + a11·xy + a02·y²')

    % ── Exponential Decay 2D ──────────────────────────────────────────
    mdl('Exponential Decay 2D', ...
        @(p,x,y) p(1)*exp(-x./max(p(2),eps) - y./max(p(3),eps)) + p(4), ...
        {'A','tx','ty','z0'}, ...
        'z = A·exp(-x/τx - y/τy) + z0')
];

end

% ════════════════════════════════════════════════════════════════════════
% Local helper — 2D Pseudo-Voigt (eta-weighted Gaussian / Lorentzian mix)
% ════════════════════════════════════════════════════════════════════════
function z = pseudoVoigt2D(p, x, y)
%PSEUDOVOIGT2D  eta·Lorentzian + (1-eta)·Gaussian + z0
    A   = p(1);
    x0  = p(2);
    wx  = max(p(3), eps);
    y0  = p(4);
    wy  = max(p(5), eps);
    z0  = p(6);
    eta = max(min(p(7), 1), 0);   % clamp to [0,1]

    gauss = A * exp(-((x-x0).^2/(2*wx^2) + (y-y0).^2/(2*wy^2)));
    loren = A ./ (1 + ((x-x0)./wx).^2 + ((y-y0)./wy).^2);
    z = eta*loren + (1-eta)*gauss + z0;
end
