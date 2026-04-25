function [z, sld] = splineSLD(zKnots, sldKnots, options)
%SPLINESLD  Free-form SLD depth profile from spline-interpolated knots.
%
%   [z, sld] = fitting.splineSLD(zKnots, sldKnots)
%   [z, sld] = fitting.splineSLD(zKnots, sldKnots, ...
%       SldAmbient=0, SldSubstrate=2.07e-6, ZRange=[-50 250], ...
%       NPoints=500, Method='pchip')
%
%   Generates a continuous SLD(z) profile by interpolating between user-
%   supplied knot points. Outside the knot range the profile is held at
%   the user-specified ambient (z < zKnots(1)) and substrate (z > zKnots(end))
%   SLDs — these plateaus are required by parrattRefl's semi-infinite
%   endpoint convention.
%
%   Inputs:
%       zKnots   — [K×1] knot depths in Å, monotonically increasing
%                  (z increases into the sample; z=0 is conventionally
%                  the top of the film stack)
%       sldKnots — [K×1] SLD values at each knot (Å⁻²)
%
%   Options:
%       SldAmbient   — semi-infinite SLD for z < zKnots(1) (default: sldKnots(1))
%       SldSubstrate — semi-infinite SLD for z > zKnots(end) (default: sldKnots(end))
%       ZRange       — [zMin, zMax] sample depth range (default: knot
%                      range padded by 50 Å on each side)
%       NPoints      — number of depth points (default: 500)
%       Method       — interpolation method: 'pchip' | 'spline' | 'makima' | 'linear'
%                      (default: 'pchip' — shape-preserving, no overshoot;
%                      cubic 'spline' can over/undershoot between knots
%                      with sharp SLD contrast)
%
%   Output:
%       z   — [N×1] depth vector (Å)
%       sld — [N×1] real SLD profile (Å⁻²)
%
%   Method
%   ─────────────────────────────
%   Inside the knot range, sld(z) is interpolated using the requested
%   method (default PCHIP). Outside, the profile is clamped to constant
%   ambient and substrate values rather than letting the interpolant
%   extrapolate freely (which would diverge for cubic methods).
%
%   PCHIP is the default because reflectometry SLD profiles are typically
%   step-like (sharp transitions between layer SLDs) and cubic spline can
%   produce ringing between knots of widely-different SLD. PCHIP is
%   shape-preserving: monotone runs stay monotone, no over/undershoot.
%   Use 'spline' only when the underlying profile is genuinely smooth
%   (e.g. graded-index, polymer brush).
%
%   Pair with fitting.profileToLayers to feed into fitting.parrattRefl:
%
%       [z, sld]   = fitting.splineSLD(zKnots, sldKnots, ...
%                        SldAmbient=0, SldSubstrate=2.07e-6);
%       layers     = fitting.profileToLayers(z, sld, ...
%                        SldAmbient=0, SldSubstrate=2.07e-6);
%       R          = fitting.parrattRefl(Q, layers, Roughness=false);
%
%   Roughness=false because microslicing already captures the smooth
%   interfacial structure; adding Névot-Croce on top would double-count.
%
%   Example
%   ─────────────────────────────
%       % Polymer brush on Si: SLD smoothly graded from ambient (D2O,
%       % 6.36e-6) through a brush layer to bulk substrate (Si, 2.07e-6)
%       zKnots   = [0 50 150 200 250]';
%       sldKnots = [6.36e-6 5.5e-6 3.0e-6 2.2e-6 2.07e-6]';
%       [z, sld] = fitting.splineSLD(zKnots, sldKnots, ...
%                      SldAmbient=6.36e-6, SldSubstrate=2.07e-6, ...
%                      ZRange=[-30 300]);
%       plot(z, sld * 1e6); xlabel('z (Å)'); ylabel('SLD (10^{-6} Å^{-2})');
%
%   References
%   ─────────────────────────────
%   - Pedersen, J. S. & Hamley, I. W., "Analysis of neutron and X-ray
%     reflectivity data: Constrained least-squares with prior knowledge",
%     J. Appl. Cryst. 27, 36-49 (1994). Section on free-form SLD profiles.
%   - Sivia, D. S. et al., "Bayesian analysis of neutron reflectometry
%     data", Physica B 248, 327-337 (1998).
%   - Fritsch, F. N. & Carlson, R. E., "Monotone piecewise cubic
%     interpolation", SIAM J. Numer. Anal. 17, 238-246 (1980). PCHIP.
%
%   See also fitting.profileToLayers, fitting.sldProfile, fitting.parrattRefl

arguments
    zKnots   (:,1) double
    sldKnots (:,1) double
    options.SldAmbient   (1,1) double = NaN
    options.SldSubstrate (1,1) double = NaN
    options.ZRange       (1,2) double = [NaN NaN]
    options.NPoints      (1,1) double = 500
    options.Method       (1,1) string = "pchip"
end

% ─── Validate inputs ────────────────────────────────────────────────
nKnots = numel(zKnots);
if nKnots < 2
    error('fitting:splineSLD:tooFewKnots', ...
        'Need at least 2 knots; got %d.', nKnots);
end
if numel(sldKnots) ~= nKnots
    error('fitting:splineSLD:knotMismatch', ...
        'zKnots and sldKnots must be same length (got %d vs %d).', ...
        nKnots, numel(sldKnots));
end
if any(diff(zKnots) <= 0)
    error('fitting:splineSLD:zNotMonotone', ...
        'zKnots must be strictly increasing.');
end
validMethods = ["pchip", "spline", "makima", "linear"];
if ~ismember(lower(options.Method), validMethods)
    error('fitting:splineSLD:badMethod', ...
        'Method must be one of: %s', strjoin(validMethods, ', '));
end

% ─── Resolve defaults ───────────────────────────────────────────────
sldAmbient   = options.SldAmbient;
sldSubstrate = options.SldSubstrate;
if isnan(sldAmbient),   sldAmbient   = sldKnots(1);   end
if isnan(sldSubstrate), sldSubstrate = sldKnots(end); end

zRange = options.ZRange;
if any(isnan(zRange))
    pad    = 50;
    zRange = [zKnots(1) - pad, zKnots(end) + pad];
end
if zRange(2) <= zRange(1)
    error('fitting:splineSLD:badZRange', ...
        'ZRange(2) must exceed ZRange(1).');
end

% ─── Build z grid ───────────────────────────────────────────────────
z = linspace(zRange(1), zRange(2), options.NPoints)';

% ─── Interpolate inside knot range, clamp outside ───────────────────
sld = zeros(size(z));

inside  = z >= zKnots(1) & z <= zKnots(end);
preMask  = z <  zKnots(1);
postMask = z >  zKnots(end);

if any(inside)
    sld(inside) = interp1(zKnots, sldKnots, z(inside), char(lower(options.Method)));
end
sld(preMask)  = sldAmbient;
sld(postMask) = sldSubstrate;

end
