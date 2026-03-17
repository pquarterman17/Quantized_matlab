function result = unitCellVolume(a, opts)
%UNITCELLVOLUME  Compute the unit cell volume from lattice parameters.
%
%   Syntax
%   ------
%   result = calc.crystal.unitCellVolume(a)
%   result = calc.crystal.unitCellVolume(a, b=b, c=c, alpha=alpha, beta=beta, gamma=gamma)
%
%   Inputs
%   ------
%   a      — lattice parameter a (Angstroms)
%   b      — lattice parameter b (Ang); default = a
%   c      — lattice parameter c (Ang); default = a
%   alpha  — angle between b and c (degrees); default = 90
%   beta   — angle between a and c (degrees); default = 90
%   gamma  — angle between a and b (degrees); default = 90
%
%   Outputs
%   -------
%   result — struct with fields:
%     .volume  — unit cell volume (Angstroms^3)
%     .system  — inferred crystal system string
%     .latex   — LaTeX-formatted result string
%
%   Examples
%   --------
%   r = calc.crystal.unitCellVolume(3.905);           % SrTiO3 cubic -> 59.5 Ang^3
%   r = calc.crystal.unitCellVolume(3.905, c=3.95);   % tetragonal

% ════════════════════════════════════════════════════════════════════

arguments
    a     (1,1) double {mustBePositive}
    opts.b     (1,1) double {mustBePositive} = a
    opts.c     (1,1) double {mustBePositive} = a
    opts.alpha (1,1) double = 90
    opts.beta  (1,1) double = 90
    opts.gamma (1,1) double = 90
end

b = opts.b;
c = opts.c;
al = deg2rad(opts.alpha);
be = deg2rad(opts.beta);
ga = deg2rad(opts.gamma);

system = inferSystem(a, b, c, opts.alpha, opts.beta, opts.gamma);

V = a * b * c * sqrt(1 - cos(al)^2 - cos(be)^2 - cos(ga)^2 ...
    + 2*cos(al)*cos(be)*cos(ga));

result.volume = V;
result.system = system;
result.latex  = sprintf('$V = %.4g\\,\\text{\\AA}^3$', V);
end

% ════════════════════════════════════════════════════════════════════

function sys = inferSystem(a, b, c, alpha, beta, gamma)
    isRightAngles = (alpha == 90) && (beta == 90) && (gamma == 90);
    bIsA = (b == a);
    cIsA = (c == a);
    if isRightAngles && bIsA && cIsA
        sys = 'cubic';
    elseif isRightAngles && bIsA && ~cIsA
        sys = 'tetragonal';
    elseif (alpha == 90) && (beta == 90) && (gamma == 120) && bIsA
        sys = 'hexagonal';
    elseif isRightAngles
        sys = 'orthorhombic';
    else
        sys = 'triclinic';
    end
end
