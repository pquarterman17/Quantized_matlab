function [layers, z, sldProfile] = reflBuildSplineLayers(knotTableData, options)
%REFLBUILDSPLINELAYERS  Convert a reflFitting knot-table into a layer matrix
%   for fitting.parrattRefl. Pure-logic helper extracted from the dialog so
%   the spline-mode code path is unit-testable without launching the UI.
%
%   layers = bosonPlotter.reflBuildSplineLayers(knotTableData)
%   layers = bosonPlotter.reflBuildSplineLayers(knotTableData, ...
%       NProfile=300, Method='pchip', Padding=50)
%   [layers, z, sldProfile] = bosonPlotter.reflBuildSplineLayers(...)
%
%   Inputs:
%       knotTableData — N×3 cell or numeric array, columns:
%                       {z (Å), SLD (×10⁻⁶ Å⁻²), Fixed (logical)}
%                       Only z and SLD are used here (Fixed is consumed by
%                       doFit's bounds construction). N >= 2 required.
%
%   Options:
%       NProfile — number of profile points for the discretized SLD(z)
%                  (default: 300; balances Parratt cost vs profile fidelity).
%       Method   — interpolation method passed to fitting.splineSLD
%                  (default: 'pchip' for shape-preservation at sharp steps).
%       Padding  — extra Å of ambient/substrate plateau on each side beyond
%                  the knot range (default: 50). Important: parrattRefl
%                  needs semi-infinite endpoints, the padding gives the
%                  microsliced profile room to settle to constant SLD.
%
%   Outputs:
%       layers     — [(NProfile)×4] matrix in fitting.parrattRefl format:
%                    [thickness, SLD_real, SLD_imag, roughness]. Roughness
%                    is 0 on every microslab; SLD_imag is 0 (no absorption
%                    support in the spline GUI, by design — for absorbing
%                    materials use the layer-mode dialog).
%       z          — [NProfile×1] depth grid the profile was evaluated on.
%       sldProfile — [NProfile×1] SLD profile values (Å⁻²).
%
%   Endpoint convention:
%       Ambient SLD   = first knot's SLD value (knotTableData{1, 2} × 1e-6)
%       Substrate SLD = last knot's SLD value
%       This matches the layer-mode dialog where row 1 is incident medium
%       and row M is substrate.
%
%   See also fitting.splineSLD, fitting.profileToLayers, fitting.parrattRefl

arguments
    knotTableData
    options.NProfile (1,1) double = 300
    options.Method   (1,1) string = "pchip"
    options.Padding  (1,1) double = 50
end

% ─── Extract numeric (z, SLD) columns from cell or numeric input ────
if iscell(knotTableData)
    nKnots   = size(knotTableData, 1);
    zKnots   = zeros(nKnots, 1);
    sldKnots = zeros(nKnots, 1);
    for ki = 1:nKnots
        zKnots(ki)   = toNumeric(knotTableData{ki, 1});
        sldKnots(ki) = toNumeric(knotTableData{ki, 2}) * 1e-6;   % table is ×10⁻⁶
    end
else
    nKnots   = size(knotTableData, 1);
    zKnots   = knotTableData(:, 1);
    sldKnots = knotTableData(:, 2) * 1e-6;
end

if nKnots < 2
    error('bosonPlotter:reflBuildSplineLayers:tooFewKnots', ...
        'Spline mode needs at least 2 knots; got %d.', nKnots);
end

% Sort by z so out-of-order user edits (or fitter shuffling) don't break
% the strict-monotonicity contract of fitting.splineSLD.
[zKnots, sortIdx] = sort(zKnots);
sldKnots          = sldKnots(sortIdx);

% Reject duplicate z (interp1 needs strictly-increasing) — nudge by ε
dz = diff(zKnots);
if any(dz <= 0)
    epsZ = 1e-6;
    for ki = 2:nKnots
        if zKnots(ki) <= zKnots(ki-1)
            zKnots(ki) = zKnots(ki-1) + epsZ;
        end
    end
end

% ─── Build profile and microslice ──────────────────────────────────
sldAmbient   = sldKnots(1);
sldSubstrate = sldKnots(end);
zRange       = [zKnots(1) - options.Padding, zKnots(end) + options.Padding];

[z, sldProfile] = fitting.splineSLD(zKnots, sldKnots, ...
    SldAmbient=sldAmbient, SldSubstrate=sldSubstrate, ...
    ZRange=zRange, NPoints=options.NProfile, Method=options.Method);

layers = fitting.profileToLayers(z, sldProfile, ...
    SldAmbient=sldAmbient, SldSubstrate=sldSubstrate);

end

function v = toNumeric(val)
    if isnumeric(val), v = val;
    elseif ischar(val) || isstring(val), v = str2double(val);
    else, v = 0;
    end
    if isnan(v), v = 0; end
end
