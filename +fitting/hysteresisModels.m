function catalog = hysteresisModels()
%HYSTERESISMODELS  Physics models for magnetic hysteresis loop fitting.
%
%   catalog = fitting.hysteresisModels()
%
%   Returns a struct array compatible with fitting.curveFit. Each model
%   has: .name, .category, .equation, .fcn, .paramNames, .p0, .lb, .ub, .nParams
%
%   Models:
%     'Tanh Hysteresis'       — M = Ms·tanh((H±Hc)/Hw)
%     'Two-Component (F+P)'   — M = Ms·tanh((H-Hc)/Hw) + χ·H
%     'Linear Background'     — M = χ·H + offset
%     'Approach to Saturation' — M = Ms(1 - a/H - b/H²) + χ·H
%     'Langevin + Background'  — M = Ms·L(μH/kT) + χ·H
%
%   Example:
%       cat = fitting.hysteresisModels();
%       m = cat(strcmp({cat.name}, 'Two-Component (F+P)'));
%       R = fitting.curveFit(H, M, m.fcn, m.p0, Lower=m.lb, Upper=m.ub);

INF = Inf;

    function m = mdl(name, equation, fcn, paramNames, p0, lb, ub)
        m.name       = name;
        m.category   = 'Hysteresis';
        m.equation   = equation;
        m.fcn        = fcn;
        m.paramNames = paramNames;
        m.p0         = p0;
        m.lb         = lb;
        m.ub         = ub;
        m.nParams    = numel(p0);
    end

catalog = [ ...
    mdl('Tanh Hysteresis', 'M = Ms·tanh((H-Hc)/Hw)', ...
        @(x,p) p(1) * tanh((x - p(2)) ./ max(abs(p(3)), eps)), ...
        {'Ms','Hc','Hw'}, [1e-3 100 200], [0 -INF 0], [INF INF INF])

    mdl('Two-Component (F+P)', 'M = Ms·tanh((H-Hc)/Hw) + χ·H', ...
        @(x,p) p(1) * tanh((x - p(2)) ./ max(abs(p(3)), eps)) + p(4)*x, ...
        {'Ms','Hc','Hw','χ'}, [1e-3 100 200 0], [0 -INF 0 -INF], [INF INF INF INF])

    mdl('Linear Background', 'M = χ·H + offset', ...
        @(x,p) p(1)*x + p(2), ...
        {'χ','offset'}, [1e-7 0], [-INF -INF], [INF INF])

    mdl('Approach to Saturation', 'M = Ms(1 - a/H - b/H²) + χ·H', ...
        @(x,p) p(1) * (1 - p(2)./(abs(x)+eps) - p(3)./(x.^2+eps)) + p(4)*x, ...
        {'Ms','a','b','χ'}, [1e-3 1 1 0], [0 0 0 -INF], [INF INF INF INF])

    mdl('Langevin + Background', 'M = Ms·L(μH/kT) + χ·H', ...
        @(x,p) langevinBG(x, p), ...
        {'Ms','μ/kT','χ'}, [1e-3 1e-3 0], [0 0 -INF], [INF INF INF])
];

end

function y = langevinBG(x, p)
%LANGEVINBG  Langevin function plus linear background.
    Ms = p(1); alpha = p(2); chi = p(3);
    u = alpha * x;
    y = zeros(size(x));
    small = abs(u) < 1e-4;
    y(small) = Ms * (u(small)/3 - u(small).^3/45);
    y(~small) = Ms * (coth(u(~small)) - 1./u(~small));
    y = y + chi * x;
end
