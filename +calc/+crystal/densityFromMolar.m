function result = densityFromMolar(molarMass, a, Z, opts)
%DENSITYFROMMOLAR  Compute mass density from molar mass and lattice parameters.
%
%   Syntax
%   ------
%   result = calc.crystal.densityFromMolar(molarMass, a, Z)
%   result = calc.crystal.densityFromMolar(molarMass, a, Z, b=b, c=c, ...)
%
%   Inputs
%   ------
%   molarMass — molar mass of the formula unit (g/mol)
%   a         — lattice parameter a (Angstroms)
%   Z         — formula units per unit cell
%   b,c       — lattice parameters (Ang); default = a
%   alpha,beta,gamma — lattice angles (degrees); default = 90
%
%   Outputs
%   -------
%   result — struct with fields:
%     .density   — mass density (g/cm^3)
%     .volume    — unit cell volume (Ang^3)
%     .Z         — formula units per unit cell
%     .molarMass — molar mass used (g/mol)
%     .latex     — LaTeX-formatted result string
%
%   Examples
%   --------
%   % SrTiO3: M=183.49, a=3.905 Ang, Z=1 -> ~5.12 g/cm^3
%   r = calc.crystal.densityFromMolar(183.49, 3.905, 1);
%
%   % Iron BCC: M=55.845, a=2.870 Ang, Z=2 -> ~7.87 g/cm^3
%   r = calc.crystal.densityFromMolar(55.845, 2.870, 2);

% ════════════════════════════════════════════════════════════════════

arguments
    molarMass (1,1) double {mustBePositive}
    a         (1,1) double {mustBePositive}
    Z         (1,1) double {mustBePositive}
    opts.b     (1,1) double {mustBePositive} = a
    opts.c     (1,1) double {mustBePositive} = a
    opts.alpha (1,1) double = 90
    opts.beta  (1,1) double = 90
    opts.gamma (1,1) double = 90
end

C = calc.constants();
NA = C.NA;

volResult = calc.crystal.unitCellVolume(a, ...
    b=opts.b, c=opts.c, alpha=opts.alpha, beta=opts.beta, gamma=opts.gamma);
V_cm3 = volResult.volume * 1e-24;  % Ang^3 -> cm^3

density = (Z * molarMass) / (NA * V_cm3);

result.density   = density;
result.volume    = volResult.volume;
result.Z         = Z;
result.molarMass = molarMass;
result.latex     = sprintf('$\\rho = %.4g\\,\\text{g/cm}^3$', density);
end
