function catalog = models()
%MODELS  Built-in curve model library for general-purpose fitting.
%
%   catalog = fitting.models()
%
%   Returns a struct array where each element defines a named model:
%       .name       — display name (e.g. 'Exponential Decay')
%       .category   — grouping label (e.g. 'Decay', 'Magnetic', 'Peak')
%       .equation   — human-readable equation string for UI display
%       .fcn        — function handle f(x, p) → y  (column vector)
%       .paramNames — cell array of parameter name strings
%       .p0         — [1×M] default initial guesses
%       .lb         — [1×M] lower bounds (-Inf if unbounded)
%       .ub         — [1×M] upper bounds (+Inf if unbounded)
%       .nParams    — number of parameters (convenience)
%
%   Example:
%       cat = fitting.models();
%       m = cat(strcmp({cat.name}, 'Exponential Decay'));
%       y = m.fcn(xdata, [1.5, 200, 0.1]);

% ════════════════════════════════════════════════════════════════════════
% Helper to build one model entry
% ════════════════════════════════════════════════════════════════════════
    function m = mdl(name, category, equation, fcn, paramNames, p0, lb, ub)
        m.name       = name;
        m.category   = category;
        m.equation   = equation;
        m.fcn        = fcn;
        m.paramNames = paramNames;
        m.p0         = p0;
        m.lb         = lb;
        m.ub         = ub;
        m.nParams    = numel(p0);
    end

INF = Inf;

catalog = [ ...
    % ── Linear / Polynomial ────────────────────────────────────────────
    mdl('Linear', 'Linear', 'y = m·x + b', ...
        @(x,p) p(1)*x + p(2), ...
        {'m','b'}, [1 0], [-INF -INF], [INF INF])
    mdl('Quadratic', 'Linear', 'y = a·x² + b·x + c', ...
        @(x,p) p(1)*x.^2 + p(2)*x + p(3), ...
        {'a','b','c'}, [0 1 0], [-INF -INF -INF], [INF INF INF])
    mdl('Cubic', 'Linear', 'y = a·x³ + b·x² + c·x + d', ...
        @(x,p) p(1)*x.^3 + p(2)*x.^2 + p(3)*x + p(4), ...
        {'a','b','c','d'}, [0 0 1 0], [-INF -INF -INF -INF], [INF INF INF INF])
    mdl('Poly 4', 'Linear', 'y = a·x⁴ + b·x³ + c·x² + d·x + e', ...
        @(x,p) p(1)*x.^4 + p(2)*x.^3 + p(3)*x.^2 + p(4)*x + p(5), ...
        {'a','b','c','d','e'}, [0 0 0 1 0], ...
        [-INF -INF -INF -INF -INF], [INF INF INF INF INF])

    % ── Decay ──────────────────────────────────────────────────────────
    mdl('Exponential Decay', 'Decay', 'y = A·exp(-x/τ) + C', ...
        @(x,p) p(1)*exp(-x./p(2)) + p(3), ...
        {'A','τ','C'}, [1 1 0], [-INF 0 -INF], [INF INF INF])
    mdl('Stretched Exponential', 'Decay', 'y = A·exp(-(x/τ)^β) + C', ...
        @(x,p) p(1)*exp(-(x./p(2)).^p(3)) + p(4), ...
        {'A','τ','β','C'}, [1 1 0.5 0], [-INF 0 0 -INF], [INF INF 2 INF])
    mdl('Bi-exponential Decay', 'Decay', 'y = A₁·exp(-x/τ₁) + A₂·exp(-x/τ₂) + C', ...
        @(x,p) p(1)*exp(-x./p(2)) + p(3)*exp(-x./p(4)) + p(5), ...
        {'A₁','τ₁','A₂','τ₂','C'}, [1 1 0.5 5 0], ...
        [-INF 0 -INF 0 -INF], [INF INF INF INF INF])

    % ── Growth ─────────────────────────────────────────────────────────
    mdl('Exponential Growth', 'Growth', 'y = A·exp(x/τ) + C', ...
        @(x,p) p(1)*exp(x./p(2)) + p(3), ...
        {'A','τ','C'}, [1 1 0], [-INF 0 -INF], [INF INF INF])
    mdl('Saturation Growth', 'Growth', 'y = A·(1 - exp(-x/τ)) + C', ...
        @(x,p) p(1)*(1 - exp(-x./p(2))) + p(3), ...
        {'A','τ','C'}, [1 1 0], [-INF 0 -INF], [INF INF INF])

    % ── Peak shapes ────────────────────────────────────────────────────
    mdl('Gaussian', 'Peak', 'y = A·exp(-(x-μ)²/(2σ²))', ...
        @(x,p) p(1)*exp(-(x-p(2)).^2 ./ (2*p(3)^2)), ...
        {'A','μ','σ'}, [1 0 1], [-INF -INF 0], [INF INF INF])
    mdl('Lorentzian', 'Peak', 'y = A / (1 + ((x-x₀)/γ)²)', ...
        @(x,p) p(1) ./ (1 + ((x-p(2))./p(3)).^2), ...
        {'A','x₀','γ'}, [1 0 1], [-INF -INF 0], [INF INF INF])
    mdl('Pseudo-Voigt', 'Peak', 'y = η·L(x) + (1-η)·G(x)', ...
        @(x,p) p(4)*(p(1)./(1+((x-p(2))./p(3)).^2)) + ...
                (1-p(4))*(p(1)*exp(-(x-p(2)).^2./(2*p(3)^2))), ...
        {'A','x₀','w','η'}, [1 0 1 0.5], [-INF -INF 0 0], [INF INF INF 1])

    % ── Power ──────────────────────────────────────────────────────────
    mdl('Power Law', 'Power', 'y = A·x^n + C', ...
        @(x,p) p(1)*abs(x).^p(2) + p(3), ...
        {'A','n','C'}, [1 1 0], [-INF -INF -INF], [INF INF INF])
    mdl('Allometric', 'Power', 'y = A·x^n', ...
        @(x,p) p(1)*abs(x).^p(2), ...
        {'A','n'}, [1 1], [-INF -INF], [INF INF])

    % ── Sigmoid ────────────────────────────────────────────────────────
    mdl('Logistic', 'Sigmoid', 'y = A / (1 + exp(-k·(x-x₀))) + C', ...
        @(x,p) p(1) ./ (1 + exp(-p(2)*(x-p(3)))) + p(4), ...
        {'A','k','x₀','C'}, [1 1 0 0], [-INF 0 -INF -INF], [INF INF INF INF])
    mdl('Tanh', 'Sigmoid', 'y = A·tanh(k·(x-x₀)) + C', ...
        @(x,p) p(1)*tanh(p(2)*(x-p(3))) + p(4), ...
        {'A','k','x₀','C'}, [1 1 0 0], [-INF 0 -INF -INF], [INF INF INF INF])

    % ── Magnetic ───────────────────────────────────────────────────────
    mdl('Langevin', 'Magnetic', 'y = A·(coth(x/B) - B/x)', ...
        @(x,p) langevinFcn(x, p), ...
        {'A','B'}, [1 1], [0 0], [INF INF])
    mdl('Brillouin', 'Magnetic', 'M = Ms·B_J(g·μB·J·H/(kB·T))', ...
        @(x,p) p(1) .* brillouinFcn(p(2), ...
            p(3) * 5.7884e-5 * p(2) .* x ./ (8.617e-5 * p(4))), ...
        {'Ms','J','g','T'}, [1 0.5 2 300], [0 0.5 0 0], [INF 7 10 1000])
    mdl('Curie-Weiss', 'Magnetic', 'y = C / (x - θ)', ...
        @(x,p) p(1) ./ (x - p(2)), ...
        {'C','θ'}, [1 0], [0 -INF], [INF INF])
    mdl('Bloch T^3/2', 'Magnetic', 'y = M₀·(1 - B·x^(3/2))', ...
        @(x,p) p(1)*(1 - p(2)*x.^1.5), ...
        {'M₀','B'}, [1 1e-5], [0 0], [INF INF])
    mdl('Stoner-Wohlfarth', 'Magnetic', 'M = Ms·tanh((H ± Hc)/Hk)', ...
        @(x,p) stonerWohlfarthFcn(x, p), ...
        {'Ms','Hc','Hk'}, [1 100 500], [0 0 0], [INF INF INF])

    % ── Thermal / Kinetic ──────────────────────────────────────────────
    mdl('Arrhenius', 'Thermal', 'y = A·exp(-Eₐ/(kB·x))', ...
        @(x,p) p(1)*exp(-p(2)./x), ...
        {'A','Eₐ/kB'}, [1 1000], [0 0], [INF INF])
    mdl('Langmuir', 'Thermal', 'y = A·x / (K + x)', ...
        @(x,p) p(1)*x ./ (p(2) + x), ...
        {'A','K'}, [1 1], [0 0], [INF INF])

    % ── Logarithmic / Sqrt ─────────────────────────────────────────────
    mdl('Logarithmic', 'Other', 'y = a·ln(x) + b', ...
        @(x,p) p(1)*log(abs(x)+eps) + p(2), ...
        {'a','b'}, [1 0], [-INF -INF], [INF INF])
    mdl('Square Root', 'Other', 'y = a·√x + b', ...
        @(x,p) p(1)*sqrt(abs(x)) + p(2), ...
        {'a','b'}, [1 0], [-INF -INF], [INF INF])
];

end

% ════════════════════════════════════════════════════════════════════════
% Local helper — Langevin function with safe x≈0 handling
% ════════════════════════════════════════════════════════════════════════
function y = langevinFcn(x, p)
%LANGEVINFCN  A*(coth(x/B) - B/x) with Taylor expansion near x=0.
    A = p(1);
    B = p(2);
    u = x ./ max(B, eps);
    y = zeros(size(x));
    small = abs(u) < 1e-4;
    % Taylor: coth(u) - 1/u ≈ u/3 - u^3/45 for small u
    y(small) = A * (u(small)/3 - u(small).^3/45);
    % Full expression for large u
    y(~small) = A * (coth(u(~small)) - 1./u(~small));
end

% ════════════════════════════════════════════════════════════════════════
% Local helper — Brillouin function B_J(y) with safe y≈0 handling
% ════════════════════════════════════════════════════════════════════════
function BJ = brillouinFcn(J, y)
%BRILLOUINFCN  Brillouin function B_J(y) = a*coth(a*y) - b*coth(b*y).
%
%   J=1/2 reduces to tanh(y).  J→Inf approaches the Langevin L(y).
%
%   Uses Taylor expansion near y=0 to avoid 0/0:
%     B_J(y) ≈ (J+1)/3 * y  for small y
    if J == 0
        BJ = zeros(size(y));
        return
    end
    a = (2*J + 1) / (2*J);
    b = 1 / (2*J);
    BJ = zeros(size(y));

    small = abs(y) < 1e-6;
    % Taylor expansion: a*coth(a*y) - b*coth(b*y) ≈ (a²-b²)/y * (1/3)*y = (J+1)/(3J) * y
    % More precisely: each coth(u) ≈ 1/u + u/3 - u³/45, so
    %   a*coth(a*y) ≈ 1/y + a²*y/3;  b*coth(b*y) ≈ 1/y + b²*y/3
    %   difference  ≈ (a²-b²)*y/3 = ((2J+1)²-1)/(4J²) * y/3 = (J+1)/(3J) * y
    BJ(small) = (J + 1) / (3 * J) .* y(small);

    % Standard expression for |y| >= threshold
    large = ~small;
    ay = a .* y(large);
    by = b .* y(large);
    BJ(large) = a .* coth(ay) - b .* coth(by);
end

% ════════════════════════════════════════════════════════════════════════
% Local helper — Stoner-Wohlfarth aligned single-domain switching
% ════════════════════════════════════════════════════════════════════════
function M = stonerWohlfarthFcn(H, p)
%STONERWOHLFARTHFCN  Simplified aligned Stoner-Wohlfarth hysteresis model.
%
%   M(H) = Ms * tanh((H - sign(H)*Hc) / Hk)
%
%   For H > 0: switching field is +Hc; for H < 0: switching field is -Hc.
%   Hk is the anisotropy field controlling switching sharpness.
    Ms = p(1);
    Hc = p(2);
    Hk = max(p(3), eps);
    % Effective field relative to coercive field (sign follows H direction)
    Heff = H - sign(H) .* Hc;
    M = Ms .* tanh(Heff ./ Hk);
end
