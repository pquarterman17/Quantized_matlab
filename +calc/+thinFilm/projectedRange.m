function result = projectedRange(ion, target, energy)
%PROJECTEDRANGE  Estimate ion projected range and straggle via LSS theory.
%
%   Syntax
%   ------
%   result = calc.thinFilm.projectedRange(ion, target, energy)
%
%   Inputs
%   ------
%   ion    — element symbol of the incident ion (char, e.g. 'Ar')
%   target — element symbol of the target material (char, e.g. 'Si')
%   energy — ion energy (keV)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Rp      — projected range (nm)
%     .deltaRp — range straggle (nm, Lindhard approximation)
%     .ion     — ion element symbol
%     .target  — target element symbol
%     .energy  — input energy (keV)
%     .warning — accuracy caveat string
%     .latex   — LaTeX-formatted result string
%
%   Notes
%   -----
%   Uses the simplified LSS (Lindhard-Scharff-Schiott) approximation.
%   Nuclear and electronic stopping are combined to yield Rp; straggle
%   follows the Lindhard approximation deltaRp ~ 0.4*Rp*sqrt(M1*M2)/(M1+M2).
%   Accuracy is typically ±20-30%.  Use SRIM/TRIM for precise work.
%
%   The atomic density of the target is estimated from the element bulk
%   density and molar mass stored in calc.elementData.  Elements with
%   NaN density fall back to 5 g/cm^3.
%
%   Examples
%   --------
%   r = calc.thinFilm.projectedRange('Ar', 'Si', 100);  % 100 keV Ar in Si
%   r = calc.thinFilm.projectedRange('B',  'Si', 30);   % 30 keV B  in Si

% ════════════════════════════════════════════════════════════════════

arguments
    ion    (1,:) char
    target (1,:) char
    energy (1,1) double {mustBePositive}
end

% ── Retrieve element data ────────────────────────────────────────────
elIon    = calc.elementData('bySymbol', ion);
elTarget = calc.elementData('bySymbol', target);

Z1 = elIon.Z;
M1 = elIon.mass;
Z2 = elTarget.Z;
M2 = elTarget.mass;

% ── Target atomic density (atoms/cm^3) ──────────────────────────────
C = calc.constants();
rhoTarget = elTarget.density;
if isnan(rhoTarget) || rhoTarget <= 0
    rhoTarget = 5.0;  % fallback (g/cm^3)
end
n = rhoTarget * C.NA / M2;   % atoms/cm^3

% ── LSS reduced energy (dimensionless) ──────────────────────────────
% Thomas-Fermi screening length a (Angstrom)
a = 0.4685 / sqrt(Z1^(2/3) + Z2^(2/3));   % Angstrom

% Reduced energy epsilon
epsilon = 32.53 * M2 * energy / ...
    (Z1 * Z2 * (M1 + M2) * sqrt(Z1^(2/3) + Z2^(2/3)));

% ── Nuclear stopping cross-section Sn (eV*cm^2) ─────────────────────
% Ziegler-Biersack-Littmark (ZBL) form valid for epsilon < 30
Sn_reduced = 3.441 * sqrt(epsilon) * log(epsilon + 2.718) / ...
    (1 + 6.355*sqrt(epsilon) + epsilon*(6.882*sqrt(epsilon) - 1.708));

% Convert dimensionless Sn to physical units (eV*cm^2)
Sn = Sn_reduced * 4*pi * a * Z1 * Z2 * (M1/(M1+M2)) * 1e-8 * 14.4 / ...
    (Z1^(2/3) + Z2^(2/3));   % eV*cm^2 (a in Ang, factor 1e-8 cm/Ang)

% ── Electronic stopping cross-section Se (eV*cm^2) ──────────────────
% Simplified k-factor form (LSS velocity-proportional regime)
Se = 0.0793 * Z1^(2/3) * sqrt(Z2) * (M1 + M2)^(3/2) / ...
    (M1^(3/2) * sqrt(M2) * (Z1^(2/3) + Z2^(2/3))^(3/4)) * ...
    sqrt(energy / M1) * 1e-15;   % eV*cm^2; sqrt(energy/M1) in sqrt(keV/u)

% ── Projected range Rp (cm → nm) ────────────────────────────────────
% Rp = E / (n * (Sn + Se))  [energy / (density * stopping power)]
energyEv = energy * 1e3;                        % keV → eV
Rp_cm    = energyEv / (n * (Sn + Se));          % cm
Rp       = Rp_cm * 1e7;                         % cm → nm

% ── Range straggle deltaRp (nm) ─────────────────────────────────────
deltaRp = 0.4 * Rp * sqrt(M1 * M2) / (M1 + M2);

% ── Assemble result ─────────────────────────────────────────────────
result.Rp      = Rp;
result.deltaRp = deltaRp;
result.ion     = ion;
result.target  = target;
result.energy  = energy;
result.warning = 'Approximate (±20-30%). Use SRIM for precise work.';
result.latex   = sprintf( ...
    '$R_p = %.4g\\,\\text{nm}\\;(\\Delta R_p = %.4g\\,\\text{nm})$', ...
    Rp, deltaRp);
end
