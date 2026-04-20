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
%   Model formulas (with units)
%   ─────────────────────────────
%   H is the applied field (Oe or A/m); M is magnetization (emu, or any
%   linear unit); chi is dimensionless volume susceptibility (or per-mass
%   if M is in emu/g). The tanh-based forms are empirical descriptors of
%   irreversible switching, NOT full Stoner-Wohlfarth astroid solutions.
%
%     Tanh Hysteresis     M(H) = Ms * tanh((H - Hc)/Hw)
%     Two-Component (F+P) M(H) = Ms * tanh((H - Hc)/Hw) + chi * H
%                         (ferromagnetic loop + paramagnetic background)
%     Linear Background   M(H) = chi * H + offset
%     Approach to Sat.    M(H) = Ms * (1 - a/H - b/H^2) + chi * H
%                         (high-field expansion, Akulov 1931)
%     Langevin + BG       M(H) = Ms * L(mu*H/kT) + chi * H,
%                         L(x) = coth(x) - 1/x
%                         (superparamagnetic clusters with linear BG)
%
%   When to use which:
%     - Tanh / F+P: soft ferromagnets, thin films with linear paramagnetic
%       contamination from substrate.
%     - Approach to Saturation: estimate Ms from data near saturation
%       without full loop fitting.
%     - Langevin + BG: superparamagnetic nanoparticle assemblies above
%       blocking temperature.
%
%   Example:
%       cat = fitting.hysteresisModels();
%       m = cat(strcmp({cat.name}, 'Two-Component (F+P)'));
%       R = fitting.curveFit(H, M, m.fcn, m.p0, Lower=m.lb, Upper=m.ub);
%
%   References
%   ─────────────────────────────
%   - Cullity, B.D. & Graham, C.D., "Introduction to Magnetic Materials",
%     2nd ed., Wiley/IEEE, 2009. Ch. 9 (hysteresis), Ch. 11 (super-
%     paramagnetism), Ch. 7 (approach-to-saturation analysis).
%   - Akulov, N.S., "Zur Theorie der Magnetisierungskurve von Einkristallen",
%     Z. Phys. 67, 794 (1931). (a/H + b/H^2 expansion.)
%   - Stoner, E.C. & Wohlfarth, E.P., "A mechanism of magnetic hysteresis
%     in heterogeneous alloys", Phil. Trans. R. Soc. A 240, 599 (1948).
%   - Bean, C.P. & Livingston, J.D., "Superparamagnetism", J. Appl. Phys.
%     30, 120S (1959). DOI: 10.1063/1.2185850

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
