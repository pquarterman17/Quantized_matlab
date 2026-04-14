function result = beanJc(field, moment, sampleDims, options)
%BEANJC  Critical current density from M(H) hysteresis loop (Bean model).
%
%   Syntax
%   ------
%   result = calc.superconductor.beanJc(H, M, dims)
%   result = calc.superconductor.beanJc(H, M, dims, Geometry='cylindrical')
%   result = calc.superconductor.beanJc(H, M, dims, FieldUnit='T')
%
%   Inputs
%   ------
%   field      — applied magnetic field vector (Oe or T, see FieldUnit)
%   moment     — magnetic moment vector (emu or A*m^2, see MomentUnit)
%                Must be a full hysteresis loop (ascending + descending).
%   sampleDims — struct describing sample geometry (dimensions in cm):
%                  Rectangular: .width, .length, .thickness
%                    (a = min(w,l) is the short cross-section dimension)
%                  Cylindrical:  .radius
%   FieldUnit  — 'Oe' (default) or 'T'
%   MomentUnit — 'emu' (default) or 'Am2'
%   Geometry   — 'rectangular' (default) or 'cylindrical'
%
%   Outputs
%   -------
%   result — struct with fields:
%     .Jc     — critical current density at each field point (A/cm^2)
%     .field  — field values for .Jc, in the same units as input
%     .deltaM — hysteresis loop width |M_up - M_down| at each field (emu or A*m^2)
%
%   Bean Model Formulas
%   -------------------
%   Rectangular sample (a <= b, cross-section dimensions in cm):
%     Jc = 20 * deltaM / (a * (1 - a/(3*b)))        [A/cm^2 when M in emu, a,b in cm]
%
%   Cylindrical sample (radius R in cm):
%     Jc = 30 * deltaM / R                           [A/cm^2 when M in emu]
%
%   The pre-factors 20 and 30 arise from the CGS Gaussian unit conversion
%   (1 emu = 1e-3 A*m^2; V = a*b*t or pi*R^2*t in cm^3).
%
%   Notes
%   -----
%   * The loop is split into ascending and descending branches by finding
%     the field extremum.  Both branches are interpolated onto a common
%     field grid (the overlap region).
%   * DeltaM = |M_ascending - M_descending| / 2 (half-width convention)
%     consistent with the factor-of-2 in the standard Bean formula.
%     The formulas above use the full-width deltaM = M_up - M_down, so
%     the factor is absorbed in the pre-factor coefficients.
%   * Fields below 10% of max|H| are excluded to avoid the central peak
%     region which is unreliable in noisy data.
%
%   Examples
%   --------
%   dims.width = 0.3; dims.length = 0.5; dims.thickness = 0.01;
%   result = calc.superconductor.beanJc(H, M, dims);
%   plot(result.field, result.Jc);
%
%   dims.radius = 0.15;
%   result = calc.superconductor.beanJc(H, M, dims, Geometry='cylindrical');

% ════════════════════════════════════════════════════════════════════

arguments
    field      (:,1) double
    moment     (:,1) double
    sampleDims (1,1) struct
    options.FieldUnit  (1,:) char {mustBeMember(options.FieldUnit,  {'Oe','T'})}  = 'Oe'
    options.MomentUnit (1,:) char {mustBeMember(options.MomentUnit, {'emu','Am2'})} = 'emu'
    options.Geometry   (1,:) char {mustBeMember(options.Geometry,   {'rectangular','cylindrical'})} = 'rectangular'
end

% ── Validate inputs ──────────────────────────────────────────────────
if numel(field) ~= numel(moment)
    error('calc:superconductor:beanJc:sizeMismatch', ...
          'field and moment must have the same number of elements.');
end
if numel(field) < 10
    error('calc:superconductor:beanJc:tooFewPoints', ...
          'At least 10 data points are required for hysteresis branch separation.');
end

% ── Convert units to CGS (Oe, emu) ──────────────────────────────────
H_oe = field(:);
M_emu = moment(:);

if strcmp(options.FieldUnit, 'T')
    H_oe = H_oe * 1e4;    % 1 T = 1e4 Oe
end
if strcmp(options.MomentUnit, 'Am2')
    M_emu = M_emu * 1e3;   % 1 A*m^2 = 1e3 emu
end

% ── Parse sample geometry ────────────────────────────────────────────
geom = options.Geometry;
if strcmp(geom, 'rectangular')
    [a, b] = getRectDims(sampleDims);
    t      = getThickness(sampleDims);
    vol_cm3 = a * b * t;
else
    r       = getCylinderRadius(sampleDims);
    t       = getThickness(sampleDims);
    vol_cm3 = pi * r^2 * t;
end

% Moment is total emu; we need magnetization per unit volume for the
% Bean formula.  Convert: M_vol (emu/cm^3) = M_emu / vol_cm^3
% But the standard Bean formula is written in terms of total moment —
% keep M_emu and volume separate for explicit formula application.

% ── Split into ascending and descending branches ─────────────────────
[H_asc, M_asc, H_desc, M_desc] = splitBranches(H_oe, M_emu);

% ── Common field grid (overlap of both branches) ─────────────────────
H_lo = max(min(H_asc), min(H_desc));
H_hi = min(max(H_asc), max(H_desc));

if H_lo >= H_hi
    error('calc:superconductor:beanJc:noOverlap', ...
          'Ascending and descending branches do not share a common field range.');
end

nGrid    = 200;
H_grid   = linspace(H_lo, H_hi, nGrid)';

M_up   = interp1(H_asc,  M_asc,  H_grid, 'linear', NaN);
M_down = interp1(H_desc, M_desc, H_grid, 'linear', NaN);

% Remove points where either branch gave NaN
valid  = ~isnan(M_up) & ~isnan(M_down);

% Exclude the low-field region (< 10% of max|H|) — central peak artefacts
Hmax    = max(abs(H_grid));
lowField = abs(H_grid) < 0.10 * Hmax;
valid   = valid & ~lowField;

H_grid  = H_grid(valid);
M_up    = M_up(valid);
M_down  = M_down(valid);

if isempty(H_grid)
    error('calc:superconductor:beanJc:noValidPoints', ...
          'No valid overlapping field points after filtering. Check input data.');
end

% ── Delta M (full loop width) ────────────────────────────────────────
% Standard convention: at positive fields, M_ascending < M_descending.
% deltaM = M_up - M_down (use absolute value to be sign-agnostic).
deltaM = abs(M_up - M_down);

% ── Bean Jc ──────────────────────────────────────────────────────────
% The Bean formula in CGS Gaussian units is:
%   Jc [A/cm^2] = (c / (4*pi)) * deltaM_vol / (a * f)
% where c = 3e10 cm/s, deltaM_vol = deltaM_emu / vol_cm3, and f is the
% geometry factor.  Simplified: Jc = 20 * deltaM_emu / (vol_cm3 * a * f)
% for rectangular, Jc = 30 * deltaM_emu / (vol_cm3 * R) for cylinder.
% Pre-factors: c/(4*pi) / 1e3 [A vs. abamp] ≈ 2.387e8 / (4*pi * 1000)
% ... which simplifies to 20 for rectangular when volume = a*b*t.
% Reference: Gyorgy et al., J. Appl. Phys. 61, 3802 (1987).

% Gyorgy et al., J. Appl. Phys. 61, 3802 (1987); Chen & Goldfarb,
% J. Appl. Phys. 66, 2489 (1989). Full-width convention — deltaM is the
% complete loop width M_up - M_down (not the half-width).
%   Rectangular: Jc [A/cm^2] = 20 * ΔM_vol [emu/cm^3] / [a * (1 - a/(3b))]
%   Cylindrical: Jc [A/cm^2] = 30 * ΔM_vol [emu/cm^3] / R
% with ΔM_vol = deltaM_total / vol_cm3.
if strcmp(geom, 'rectangular')
    geomFactor = a * (1 - a / (3*b));
    Jc = 20 .* deltaM ./ (vol_cm3 .* geomFactor);
else
    Jc = 30 .* (deltaM ./ vol_cm3) ./ r;
end

% Convert back to input field units for output
H_out = H_grid;
if strcmp(options.FieldUnit, 'T')
    H_out = H_out / 1e4;
end

% Convert deltaM back to input moment units
dM_out = deltaM;
if strcmp(options.MomentUnit, 'Am2')
    dM_out = dM_out / 1e3;
end

% ── Assemble output ──────────────────────────────────────────────────
result.Jc     = Jc;
result.field  = H_out;
result.deltaM = dM_out;
end

% ════════════════════════════════════════════════════════════════════

function [a, b] = getRectDims(dims)
%GETRECTDIMS  Return (short, long) cross-section dimensions in cm.
    required = {'width','length'};
    for ri = 1:numel(required)
        if ~isfield(dims, required{ri})
            error('calc:superconductor:beanJc:missingDim', ...
                  'sampleDims.%s is required for rectangular geometry.', required{ri});
        end
    end
    w = dims.width;
    l = dims.length;
    a = min(w, l);
    b = max(w, l);
end

% ════════════════════════════════════════════════════════════════════

function t = getThickness(dims)
%GETTHICKNESS  Return sample thickness in cm.
    if ~isfield(dims, 'thickness')
        error('calc:superconductor:beanJc:missingDim', ...
              'sampleDims.thickness is required.');
    end
    t = dims.thickness;
end

% ════════════════════════════════════════════════════════════════════

function r = getCylinderRadius(dims)
%GETCYLINDERRADIUS  Return cylinder radius in cm.
    if ~isfield(dims, 'radius')
        error('calc:superconductor:beanJc:missingDim', ...
              'sampleDims.radius is required for cylindrical geometry.');
    end
    r = dims.radius;
end

% ════════════════════════════════════════════════════════════════════

function [H_asc, M_asc, H_desc, M_desc] = splitBranches(H, M)
%SPLITBRANCHES  Split H,M into ascending and descending field branches.
%   Finds the field extremum (max |H|) as the split point.
%   The ascending branch goes from the negative extreme to the positive
%   extreme; the descending branch returns.

[~, iPeak] = max(H);
[~, iTrou] = min(H);

if iPeak > iTrou
    % Starts negative, sweeps to positive
    H_asc  = H(iTrou:iPeak);
    M_asc  = M(iTrou:iPeak);
    H_desc = H([iPeak:end, 1:iTrou]);
    M_desc = M([iPeak:end, 1:iTrou]);
else
    % Starts positive, sweeps to negative
    H_desc = H(iPeak:iTrou);
    M_desc = M(iPeak:iTrou);
    H_asc  = H([iTrou:end, 1:iPeak]);
    M_asc  = M([iTrou:end, 1:iPeak]);
end

% Ensure ascending branch is monotonically increasing for interp1
[H_asc, ia]  = sort(H_asc);
M_asc        = M_asc(ia);

% Ensure descending branch is monotonically increasing for interp1
[H_desc, id] = sort(H_desc);
M_desc       = M_desc(id);

% Remove duplicate H values (keep last occurrence per branch)
[H_asc, ua]  = unique(H_asc,  'last');
M_asc        = M_asc(ua);
[H_desc, ud] = unique(H_desc, 'last');
M_desc       = M_desc(ud);
end
