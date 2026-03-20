function result = depairingCurrent(opts)
%DEPAIRINGCURRENT  Calculate the depairing (pair-breaking) current density.
%
%   Syntax
%   ------
%   result = calc.superconductor.depairingCurrent(Material=name, T=T)
%   result = calc.superconductor.depairingCurrent(Hc0=Hc0, lambda0=lam0, Tc=Tc, T=T)
%
%   Inputs
%   ------
%   Material — (optional) string material name (e.g. 'Nb').  Loads Hc0,
%              lambda0, and Tc from materialPresets.
%   Hc0      — thermodynamic critical field at T=0 (Oe); required unless
%              Material is given.
%   lambda0  — London penetration depth at T=0 (nm); required unless
%              Material is given.
%   Tc       — critical temperature (K); required unless Material is given.
%   T        — measurement temperature (K); must be < Tc.
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Jd    — depairing current density (A/cm^2)
%     .JdMA  — depairing current density (MA/cm^2)
%     .T     — temperature (K)
%     .Tc    — critical temperature (K)
%     .latex — LaTeX-formatted result string
%
%   Formula
%   -------
%   In Gaussian CGS the depairing current density is:
%
%     Jd(T) = Hc(T) / (3*sqrt(6) * pi * lambda(T))   [A/cm^2 in SI units]
%
%   The conversion from CGS Oe/cm to A/cm^2 uses:
%     1 Oe/cm = (1000 / (4*pi)) A/cm^2
%   equivalently:
%     Jd [A/cm^2] = Hc(T) [Oe] / (3*sqrt(6)*pi * lambda(T) [cm])
%                   * (1e3 / (4*pi))
%
%   Hc(T) is obtained from criticalFields; lambda(T) from londonDepth.
%
%   Examples
%   --------
%   r = calc.superconductor.depairingCurrent(Material='Nb', T=4.2);
%   fprintf('Jd = %.2f MA/cm^2\n', r.JdMA);
%
%   r = calc.superconductor.depairingCurrent(Hc0=1980, lambda0=39, Tc=9.25, T=4.2);

% ════════════════════════════════════════════════════════════════════

arguments
    opts.Material (1,:) char = ''
    opts.Hc0      (1,1) double = NaN   % Oe
    opts.lambda0  (1,1) double = NaN   % nm
    opts.Tc       (1,1) double = NaN   % K
    opts.T        (1,1) double {mustBeNonnegative}
end

% ── Resolve parameters from preset ──────────────────────────────────
if ~isempty(opts.Material)
    preset  = calc.superconductor.materialPresets(Material=opts.Material);
    Hc0     = nanFirst(opts.Hc0,     preset.Hc0);
    lambda0 = nanFirst(opts.lambda0, preset.lambda0);
    Tc      = nanFirst(opts.Tc,      preset.Tc);
else
    Hc0     = opts.Hc0;
    lambda0 = opts.lambda0;
    Tc      = opts.Tc;
    if any(isnan([Hc0, lambda0, Tc]))
        error('calc:superconductor:missingParam', ...
              'Provide Hc0, lambda0, and Tc, or a Material name.');
    end
end

T = opts.T;
if T >= Tc
    error('calc:superconductor:normalState', ...
          'T (%.4g K) must be below Tc (%.4g K).', T, Tc);
end

% ── Hc(T) and lambda(T) ─────────────────────────────────────────────
if ~isempty(opts.Material)
    rHc = calc.superconductor.criticalFields(Material=opts.Material, T=T);
    rL  = calc.superconductor.londonDepth(Material=opts.Material, T=T);
else
    rHc = calc.superconductor.criticalFields(Hc0=Hc0, Tc=Tc, T=T);
    rL  = calc.superconductor.londonDepth(lambda0=lambda0, T=T, Tc=Tc);
end

HcT     = rHc.Hc;        % Oe
lambdaT = rL.lambda;      % nm

% ── Convert to CGS and compute Jd ───────────────────────────────────
% lambda in cm: 1 nm = 1e-7 cm
lam_cm = lambdaT * 1e-7;

% Jd in CGS Oe/cm → convert to SI A/cm^2
% 1 Oe/cm = (1e3 / (4*pi)) A/cm^2  [from H = (1/(4*pi)) * J in CGS Gaussian]
Jd_cgs    = HcT / (3 * sqrt(6) * pi * lam_cm);   % Oe/cm (≡ A*s/cm^2 in mixed)
Jd_Acm2   = Jd_cgs * (1e3 / (4*pi));             % A/cm^2
JdMA_cm2  = Jd_Acm2 * 1e-6;                      % MA/cm^2

result.Jd    = Jd_Acm2;
result.JdMA  = JdMA_cm2;
result.T     = T;
result.Tc    = Tc;
result.latex = sprintf( ...
    '$J_d(%.4g\\,\\mathrm{K}) = %.4g\\,\\mathrm{MA/cm^2}$', T, JdMA_cm2);
end

% ════════════════════════════════════════════════════════════════════

function out = nanFirst(explicit, fallback)
%NANFIRST  Return explicit value if not NaN, otherwise fallback.
    if ~isnan(explicit)
        out = explicit;
    else
        out = fallback;
    end
end
