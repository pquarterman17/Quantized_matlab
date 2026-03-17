function result = atomicDensity(a, Z, opts)
%ATOMICDENSITY  Compute the atomic number density from lattice parameters.
%
%   Syntax
%   ------
%   result = calc.crystal.atomicDensity(a, Z)
%   result = calc.crystal.atomicDensity(a, Z, b=b, c=c, alpha=alpha, beta=beta, gamma=gamma)
%
%   Inputs
%   ------
%   a      — lattice parameter a (Angstroms)
%   Z      — number of atoms per unit cell (e.g. 2 for BCC, 4 for FCC)
%   b,c    — lattice parameters (Ang); default = a
%   alpha,beta,gamma — lattice angles (degrees); default = 90
%
%   Outputs
%   -------
%   result — struct with fields:
%     .density — atomic number density (atoms/cm^3)
%     .Z       — atoms per unit cell
%     .volume  — unit cell volume (Ang^3)
%     .latex   — LaTeX-formatted result string
%
%   Examples
%   --------
%   r = calc.crystal.atomicDensity(2.87, 2);   % BCC Fe: ~8.5e22 atoms/cm^3
%   r = calc.crystal.atomicDensity(3.52, 4);   % FCC Ni

% ════════════════════════════════════════════════════════════════════

arguments
    a     (1,1) double {mustBePositive}
    Z     (1,1) double {mustBePositive}
    opts.b     (1,1) double {mustBePositive} = a
    opts.c     (1,1) double {mustBePositive} = a
    opts.alpha (1,1) double = 90
    opts.beta  (1,1) double = 90
    opts.gamma (1,1) double = 90
end

volResult = calc.crystal.unitCellVolume(a, ...
    b=opts.b, c=opts.c, alpha=opts.alpha, beta=opts.beta, gamma=opts.gamma);
V_cm3 = volResult.volume * 1e-24;  % Ang^3 -> cm^3

density = Z / V_cm3;

result.density = density;
result.Z       = Z;
result.volume  = volResult.volume;
result.latex   = sprintf('$n = %.4g\\,\\text{atoms/cm}^3$', density);
end
