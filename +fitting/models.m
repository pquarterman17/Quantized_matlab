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
    mdl('VFT', 'Decay', 'τ = τ₀·exp(Ea/(kB·(T-T₀)))', ...
        @(x,p) p(1) * exp(p(2) ./ (8.617e-5 * (x - p(3)))), ...
        {'τ₀','Ea_eV','T₀'}, [1e-10 0.05 0], [0 0 0], [1 10 INF])
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

    % ── Heat Capacity — Debye & Einstein phonon models ─────────────────
    % C(T) = gamma*T + n * C_Debye(T, thetaD)
    % p = [gamma (mJ/mol/K²), thetaD (K), n (atoms/f.u.)]
    mdl('Debye', 'Thermal', 'C = γT + n·C_D(T,θD)', ...
        @(x,p) debyeHeatCapacity(x, p), ...
        {'gamma','thetaD','n'}, [5 200 1], [0 1 0.1], [INF INF 20])

    % C(T) = gamma*T + n * C_Einstein(T, thetaE)
    % p = [gamma (mJ/mol/K²), thetaE (K), n]
    mdl('Einstein', 'Thermal', 'C = γT + n·C_E(T,θE)', ...
        @(x,p) einsteinHeatCapacity(x, p), ...
        {'gamma','thetaE','n'}, [5 150 1], [0 1 0.1], [INF INF 20])

    % Combined Debye + Einstein with two characteristic temperatures
    % p = [gamma, thetaD, nD, thetaE, nE]
    mdl('Debye+Einstein', 'Thermal', 'C = γT + n_D·C_D(T,θD) + n_E·C_E(T,θE)', ...
        @(x,p) debyeEinsteinHeatCapacity(x, p), ...
        {'gamma','thetaD','n_D','thetaE','n_E'}, [5 200 0.8 150 0.2], ...
        [0 1 0 1 0], [INF INF 20 INF 20])
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

% ════════════════════════════════════════════════════════════════════════
% Local helper — Debye heat capacity (electronic + lattice)
% ════════════════════════════════════════════════════════════════════════
function C = debyeHeatCapacity(T, p)
%DEBYEHEATCAPACITY  C(T) = gamma*T + n * 9*R*(T/thetaD)^3 * integral.
%
%   p = [gamma (mJ/mol/K^2), thetaD (K), n (atoms/formula unit)]
%
%   Debye integral: integral from 0 to thetaD/T of x^4*e^x/(e^x-1)^2 dx
%   evaluated numerically. Full heat capacity per mole:
%     C_Debye(T, thetaD) = 9*R*(T/thetaD)^3 * integral
%
%   Total: C(T) = gamma*T + n * C_Debye(T, thetaD)   [mJ/mol/K]
%   Note: gamma in mJ/mol/K^2 so gamma*T in mJ/mol/K; 9*R in J/mol/K
%   converted to mJ: multiply by 1000.
    gamma  = p(1);    % mJ/(mol·K²)
    thetaD = max(p(2), 1);
    n      = max(p(3), 0);
    R      = 8.314;   % J/(mol·K)

    T = T(:);
    C = zeros(size(T));
    for k = 1:numel(T)
        Tk = max(T(k), 0.01);
        u  = thetaD / Tk;
        % Debye integral: int_0^u x^4*e^x/(e^x-1)^2 dx
        dInt = debyeIntegral(u);
        C_lattice_J = 9 * R * (1/u)^3 * dInt;   % J/(mol·K)
        C(k) = gamma * Tk + n * C_lattice_J * 1000;  % mJ/(mol·K)
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helper — Einstein heat capacity
% ════════════════════════════════════════════════════════════════════════
function C = einsteinHeatCapacity(T, p)
%EINSTEINHEATHCAPACITY  C(T) = gamma*T + n * 3*R*(thetaE/T)^2*e^u/(e^u-1)^2.
%
%   p = [gamma (mJ/mol/K^2), thetaE (K), n]
    gamma  = p(1);
    thetaE = max(p(2), 1);
    n      = max(p(3), 0);
    R      = 8.314;

    T = T(:);
    C = zeros(size(T));
    for k = 1:numel(T)
        Tk = max(T(k), 0.01);
        u  = thetaE / Tk;
        eu = exp(min(u, 500));   % cap to avoid overflow
        C_ein_J = 3 * R * u^2 * eu / max((eu - 1)^2, eps);
        C(k) = gamma * Tk + n * C_ein_J * 1000;
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helper — Combined Debye + Einstein model
% ════════════════════════════════════════════════════════════════════════
function C = debyeEinsteinHeatCapacity(T, p)
%DEBYEEINSTEINHEATCAPACITY  C = gamma*T + nD*C_D + nE*C_E.
%
%   p = [gamma, thetaD, nD, thetaE, nE]
    % Combine: gamma*T once + nD * Debye_lattice + nE * Einstein_lattice
    % (gamma is not double-counted; electronic term appears only once)
    R = 8.314;
    gamma  = p(1);
    thetaD = max(p(2), 1);
    nD     = max(p(3), 0);
    thetaE = max(p(4), 1);
    nE     = max(p(5), 0);

    T = T(:);
    C = zeros(size(T));
    for k = 1:numel(T)
        Tk = max(T(k), 0.01);

        uD = thetaD / Tk;
        dInt = debyeIntegral(uD);
        C_D_J = 9 * R * (1/uD)^3 * dInt;

        uE = thetaE / Tk;
        euE = exp(min(uE, 500));
        C_E_J = 3 * R * uE^2 * euE / max((euE - 1)^2, eps);

        C(k) = gamma * Tk + (nD * C_D_J + nE * C_E_J) * 1000;
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helper — Debye integral (numerical)
% ════════════════════════════════════════════════════════════════════════
function I = debyeIntegral(u)
%DEBYEINTEGRAL  Numerically evaluate integral_0^u x^4*e^x/(e^x-1)^2 dx.
%
%   For large u (u > 30), the integrand decays exponentially and the
%   integral converges to the analytic Debye function limit (4*pi^4/15).
%   For small u, uses adaptive Gauss-Legendre quadrature via integral().
    if u > 30
        % Converged: Debye function approaches D(inf) * 3 = 4*pi^4/15
        I = 4 * pi^4 / 15;
        return;
    end
    if u < 1e-4
        % Leading-order: integrand ~ x^2, integral ~ u^3/3
        I = u^3 / 3;
        return;
    end
    % Numerical integration (MATLAB built-in, no toolbox needed)
    integrand = @(x) x.^4 .* exp(x) ./ max((exp(x) - 1).^2, eps);
    I = integral(integrand, 0, u, 'RelTol', 1e-6, 'AbsTol', 1e-10);
end
