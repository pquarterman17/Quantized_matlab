function result = demagFactor(shape, opts)
%DEMAGFACTOR  Estimate demagnetization factors for common sample geometries.
%
%   The internal field inside a uniformly magnetized sample differs from
%   the applied field by the demagnetizing field:
%
%     H_int = H_ext - N * M       (SI)
%     H_int = H_ext - 4*pi*N * M  (CGS)
%
%   N is the dimensionless demagnetization factor (0 <= N <= 1).  For a
%   body with rotational symmetry about z the trace condition gives
%   Nz + 2*Nxy = 1 (SI), so only Nz need be computed.
%
%   Syntax:
%     result = calc.magnetic.demagFactor(shape)
%     result = calc.magnetic.demagFactor('cylinder', L=L, d=d)
%     result = calc.magnetic.demagFactor('prolate',  ratio=ratio)
%     result = calc.magnetic.demagFactor('oblate',   ratio=ratio)
%
%   Shape options — unified reference:
%
%     Shape        Required opts   Nz formula                Valid range  Source
%     ─────────────────────────────────────────────────────────────────────────────
%     'sphere'     —               1/3 (exact)               always       Osborn 1945
%     'thin_film'  —               1   (infinite slab, Nxy=0) always      Osborn 1945
%     'cylinder'   L, d (cm)       1/(1 + 1.6*(L/d))         L/d in      Sato &
%                                  L = length, d = diameter   [0.1, 10]   Ishii 1989
%     'prolate'    ratio = c/a>1   closed-form (see below)   all c/a>1   Osborn 1945
%     'oblate'     ratio = a/c>1   closed-form (see below)   all a/c>1   Osborn 1945
%
%   Prolate spheroid (elongated needle, c > a):
%     e^2 = 1 - (a/c)^2 = 1 - 1/ratio^2
%     Nz  = (1-e^2)/e^2 * (-1 + (1/(2e))*log((1+e)/(1-e)))
%     Limits:  ratio->1 => Nz->1/3;  ratio->inf => Nz->0  (long rod)
%
%   Oblate spheroid (flattened disk, a > c):
%     e^2 = 1 - (c/a)^2 = 1 - 1/ratio^2
%     Nz  = (1/e^2) * (1 - sqrt(1-e^2)/e * asin(e))
%     Limits:  ratio->1 => Nz->1/3;  ratio->inf => Nz->1  (thin film)
%
%   Cylinder validity note:
%     The Sato-Ishii formula is accurate to a few percent for 0.1 <= L/d <= 10.
%     Outside this range the cylinder geometry approaches the spheroid limits:
%       L/d < 0.1  (flat disk)  — use shape='oblate' with ratio = d/L
%       L/d > 10   (long rod)   — use shape='prolate' with ratio = L/d
%     A warning is issued automatically when L/d falls outside [0.1, 10].
%
%   Inputs:
%     shape — geometry string (see table above)
%     L     — cylinder length (any consistent length unit, e.g. cm)
%     d     — cylinder diameter (same unit as L)
%     ratio — aspect ratio for spheroids (c/a for prolate, a/c for oblate)
%
%   Outputs:
%     result — struct with fields:
%       .Nz    — demagnetization factor along symmetry axis (z / long axis)
%       .Nxy   — transverse demagnetization factor: Nxy = (1 - Nz) / 2
%       .shape — input shape string (echoed back)
%       .latex — LaTeX-formatted result string, e.g. '$N_z = 0.3333$'
%
%   Examples:
%     % Sphere — all axes equivalent
%     r = calc.magnetic.demagFactor('sphere');
%     % r.Nz = 0.3333
%
%     % 3 mm long cylinder, 1 mm diameter (L/d = 3, within valid range)
%     r = calc.magnetic.demagFactor('cylinder', L=0.3, d=0.1);
%     % r.Nz ≈ 0.172,  r.Nxy ≈ 0.414
%
%     % Prolate spheroid with axis ratio 5:1
%     r = calc.magnetic.demagFactor('prolate', ratio=5);
%     % r.Nz ≈ 0.040
%
%     % Oblate disk with diameter 10x the thickness
%     r = calc.magnetic.demagFactor('oblate', ratio=10);
%     % r.Nz ≈ 0.860
%
%   References:
%     Osborn, J.A., "Demagnetizing factors of the general ellipsoid,"
%       Phys. Rev. 67, 351 (1945). DOI:10.1103/PhysRev.67.351
%     Sato, M. & Ishii, Y., "Simple and approximate expressions of
%       demagnetizing factors of uniformly magnetized rectangular rods
%       and cylinders," J. Appl. Phys. 66, 983 (1989).
%       DOI:10.1063/1.343481
%     Chen, D.-X., Brug, J.A. & Goldfarb, R.B., "Demagnetizing factors
%       for cylinders," IEEE Trans. Magn. 27, 3601 (1991).
%     Cullity, B.D. & Graham, C.D., Introduction to Magnetic Materials,
%       2nd ed., Wiley, 2009, Ch. 2.

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
