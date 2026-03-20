function result = gasFlow(P1, P2, d, L, opts)
%GASFLOW  Compute molecular and viscous gas flow conductance through a tube.
%
%   Calculates conductance in both the molecular and viscous regimes, the
%   Knudsen number to identify which regime applies, and the gas throughput
%   Q = C * (P1 - P2).
%
%   Molecular conductance (Knudsen):
%     C_mol = (pi*d^3 / (12*L)) * sqrt(8*kB*T / (pi*m))
%
%   Viscous conductance (Hagen-Poiseuille):
%     C_visc = (pi*d^4 / (128*eta*L)) * (P1+P2)/2
%
%   Syntax
%   ------
%   result = calc.vacuum.gasFlow(P1, P2, d, L)
%   result = calc.vacuum.gasFlow(P1, P2, d, L, T=T, m=m)
%
%   Inputs
%   ------
%   P1  — upstream pressure (Pa)
%   P2  — downstream pressure (Pa)
%   d   — tube inner diameter (m)
%   L   — tube length (m)
%   T   — temperature (K); default = 300
%   m   — molecular mass (kg); default = 4.65e-26 (N2, ~28 amu)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Cmol       — molecular flow conductance (L/s)
%     .Cvisc      — viscous flow conductance (L/s)
%     .throughput — gas throughput Q = C*(P1-P2) using regime conductance (Pa*L/s)
%     .Kn         — Knudsen number (based on mean free path at mean pressure)
%     .regime     — flow regime string: 'molecular', 'transition', or 'viscous'
%     .latex      — LaTeX-formatted result string
%
%   Examples
%   --------
%   r = calc.vacuum.gasFlow(1e-3, 1e-5, 0.025, 0.5);       % 25 mm dia, 0.5 m tube
%   r = calc.vacuum.gasFlow(100, 1, 0.01, 0.1, T=300);     % high-pressure viscous flow

% ════════════════════════════════════════════════════════════════════

arguments
    P1   (1,1) double {mustBePositive}
    P2   (1,1) double {mustBePositive}
    d    (1,1) double {mustBePositive}
    L    (1,1) double {mustBePositive}
    opts.T   (1,1) double {mustBePositive} = 300
    opts.m   (1,1) double {mustBePositive} = 4.65e-26
end

C   = calc.constants();
T   = opts.T;
m   = opts.m;

% Viscosity of N2 at 300 K (Pa*s) — constant approximation
eta = 1.8e-5;

% ── Molecular conductance (m^3/s → L/s) ─────────────────────────────
Cmol_m3s = (pi * d^3 / (12 * L)) * sqrt(8 * C.kB * T / (pi * m));
Cmol     = Cmol_m3s * 1e3;   % convert m^3/s to L/s

% ── Viscous conductance (m^3/s → L/s) ───────────────────────────────
Pmean    = (P1 + P2) / 2;
Cvisc_m3s = (pi * d^4 / (128 * eta * L)) * Pmean;
Cvisc    = Cvisc_m3s * 1e3;  % convert m^3/s to L/s

% ── Knudsen number at mean pressure, using tube diameter as length ───
mfpResult = calc.vacuum.meanFreePath(Pmean, T=T, d=3.64e-10);
knResult  = calc.vacuum.knudsenNumber(mfpResult.mfp, d);
Kn        = knResult.Kn;
regime    = knResult.regime;

% ── Throughput using regime-appropriate conductance ──────────────────
if strcmp(regime, 'molecular')
    C_eff = Cmol_m3s;
elseif strcmp(regime, 'viscous')
    C_eff = Cvisc_m3s;
else
    % Transition: use sum (approximate Knudsen additive model)
    C_eff = Cmol_m3s + Cvisc_m3s;
end
throughput = C_eff * (P1 - P2) * 1e3;  % Pa*(m^3/s) → Pa*L/s

result.Cmol       = Cmol;
result.Cvisc      = Cvisc;
result.throughput = throughput;
result.Kn         = Kn;
result.regime     = regime;
result.latex      = sprintf( ...
    '$C_{\\mathrm{mol}} = %.4g\\,\\mathrm{L/s},\\;C_{\\mathrm{visc}} = %.4g\\,\\mathrm{L/s}$ (%s)', ...
    Cmol, Cvisc, regime);
end
