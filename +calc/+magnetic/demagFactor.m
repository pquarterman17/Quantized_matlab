function result = demagFactor(shape, opts)
%DEMAGFACTOR  Estimate demagnetization factors for common sample geometries.
%
%   Syntax:
%     result = calc.magnetic.demagFactor(shape)
%     result = calc.magnetic.demagFactor('cylinder', L=L, d=d)
%     result = calc.magnetic.demagFactor('prolate',  ratio=ratio)
%     result = calc.magnetic.demagFactor('oblate',   ratio=ratio)
%
%   Inputs:
%     shape — geometry string:
%               'sphere'    — ideal sphere; N = 1/3 on all axes
%               'thin_film' — infinite slab; Nz = 1, Nxy = 0
%               'cylinder'  — finite cylinder; requires L (length, cm) and
%                             d (diameter, cm). Uses Nz = 1/(1 + 1.6*L/d).
%               'prolate'   — prolate spheroid (a > c); requires ratio = a/c
%               'oblate'    — oblate spheroid (a < c, flat disk); requires ratio = c/a
%
%   Outputs:
%     result — struct with fields:
%       .Nz    — demagnetization factor along symmetry axis (z / long axis)
%       .Nxy   — demagnetization factor along transverse axes (Nxy = (1-Nz)/2)
%       .shape — input shape string
%       .latex — LaTeX-formatted result string
%
%   Notes:
%     Nz + 2*Nxy = 1 for all ellipsoids and limiting shapes.
%     Cylinder formula is the Osborn (1945) approximation valid for L/d in [0.1, 10].
%     Prolate/oblate formulas are exact for spheroids (Osborn 1945).
%
%   Examples:
%     r = calc.magnetic.demagFactor('sphere');
%     r = calc.magnetic.demagFactor('cylinder', L=10e-1, d=3e-1);
%     r = calc.magnetic.demagFactor('prolate',  ratio=5);

% ════════════════════════════════════════════════════════════════════

arguments
    shape (1,1) string {mustBeMember(shape, ...
        {'sphere','thin_film','cylinder','prolate','oblate'})}
    opts.L     (1,1) double {mustBePositive} = 1
    opts.d     (1,1) double {mustBePositive} = 1
    opts.ratio (1,1) double {mustBePositive} = 2
end

switch shape

    case 'sphere'
        Nz  = 1/3;

    case 'thin_film'
        Nz  = 1;

    case 'cylinder'
        L = opts.L;
        d = opts.d;
        % Sato-Ishii-style finite-cylinder approximation:
        %   Nz = 1 / (1 + 1.6 * (L/d))
        % Valid roughly for 0.1 < L/d < 10; extreme aspect ratios
        % (thin disks, long rods) differ from the exact prolate /
        % oblate spheroid limit by several percent. Warn the caller.
        aspect = L / d;
        if aspect < 0.1 || aspect > 10
            warning('calc:magnetic:demagFactor:cylinderAspect', ...
                ['Cylinder L/d = %.3g is outside the Sato-Ishii ', ...
                 'approximation range (0.1 to 10). For better accuracy ', ...
                 'use shape=''prolate'' (rods) or shape=''oblate'' (disks).'], ...
                aspect);
        end
        Nz = 1 / (1 + 1.6 * aspect);

    case 'prolate'
        % Prolate spheroid: semi-axes a (equatorial) < c (polar); ratio = c/a > 1
        % e² = 1 - (a/c)²  =>  e² = 1 - 1/ratio²
        ratio = opts.ratio;
        if ratio <= 1
            error('calc:magnetic:demagFactor', ...
                'prolate requires ratio = c/a > 1 (elongated along z).');
        end
        e2 = 1 - (1/ratio)^2;
        e  = sqrt(e2);
        Nz = (1 - e2) / e2 * (-1 + 1/(2*e) * log((1+e)/(1-e)));

    case 'oblate'
        % Oblate spheroid: semi-axes a (equatorial) > c (polar); ratio = a/c > 1
        % e² = 1 - (c/a)²  =>  e² = 1 - 1/ratio²
        % Osborn (1945) exact formula for Nz (polar axis, short axis):
        %   Nz = (1/e²) * (1 - sqrt(1-e²)/e * asin(e))
        %   Limits: ratio->1 (sphere): Nz -> 1/3; ratio->inf (disk): Nz -> 1
        ratio = opts.ratio;
        if ratio <= 1
            error('calc:magnetic:demagFactor', ...
                'oblate requires ratio = a/c > 1 (flattened along z).');
        end
        e2 = 1 - (1/ratio)^2;
        e  = sqrt(e2);
        Nz = (1 / e2) * (1 - sqrt(1 - e2) / e * asin(e));

end

Nxy = (1 - Nz) / 2;

result.Nz    = Nz;
result.Nxy   = Nxy;
result.shape = shape;
result.latex = sprintf('$N_z = %.4g,\\; N_{xy} = %.4g$', Nz, Nxy);

end
