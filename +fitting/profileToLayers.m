function layers = profileToLayers(z, sld, options)
%PROFILETOLAYERS  Discretize an SLD(z) profile into the layer-stack matrix
%   format expected by fitting.parrattRefl.
%
%   layers = fitting.profileToLayers(z, sld)
%   layers = fitting.profileToLayers(z, sld, ImagSld=zeros(N,1), ...
%       SldAmbient=0, SldSubstrate=2.07e-6)
%
%   Microslicing approximation: each adjacent pair of profile points
%   becomes one thin slab with thickness Δz_i = z(i+1) - z(i) and SLD
%   = midpoint of sld(i) and sld(i+1). Roughness is set to 0 on every
%   slab because the profile already carries the smooth interfacial
%   structure — adding Névot-Croce on top would double-count.
%
%   Inputs:
%       z   — [N×1] depth vector (Å), monotonically increasing
%       sld — [N×1] real SLD profile (Å⁻²)
%
%   Options:
%       ImagSld      — [N×1] imaginary SLD profile (default: zeros, no absorption)
%       SldAmbient   — semi-infinite ambient SLD prepended (default: sld(1))
%       SldSubstrate — semi-infinite substrate SLD appended (default: sld(end))
%
%   Output:
%       layers — [(N+1)×4] matrix in parrattRefl format:
%                  Row 1:        [0, SldAmbient, 0, 0]               — incident medium
%                  Rows 2..N:    [Δz_{i-1}, sld_mid, imag_mid, 0]   — N-1 microslabs
%                  Row N+1:      [0, SldSubstrate, 0, 0]            — substrate
%
%   Usage with parrattRefl:
%       [z, sld] = fitting.splineSLD(zKnots, sldKnots, ...);
%       layers   = fitting.profileToLayers(z, sld);
%       R        = fitting.parrattRefl(Q, layers, Roughness=false);
%
%   Pass Roughness=false: the profile is already the convolved SLD(z),
%   so each microslab needs zero interfacial roughness.
%
%   Performance note
%   ─────────────────────────────
%   Reflectivity cost in parrattRefl scales as O(N_layers · N_Q). 500
%   profile points → 499 microslabs → roughly 100× slower per Q than a
%   3-layer box model. For fitting use NPoints ≈ 200 (1 Å resolution
%   over a 200 Å film) as a sensible default; for forward simulation
%   500 is fine.
%
%   See also fitting.splineSLD, fitting.sldProfile, fitting.parrattRefl

arguments
    z   (:,1) double
    sld (:,1) double
    options.ImagSld      (:,1) double = []
    options.SldAmbient   (1,1) double = NaN
    options.SldSubstrate (1,1) double = NaN
end

N = numel(z);
if N < 2
    error('fitting:profileToLayers:tooFewPoints', ...
        'Need at least 2 profile points; got %d.', N);
end
if numel(sld) ~= N
    error('fitting:profileToLayers:lengthMismatch', ...
        'sld must match z length (got %d vs %d).', numel(sld), N);
end
if any(diff(z) <= 0)
    error('fitting:profileToLayers:zNotMonotone', ...
        'z must be strictly increasing.');
end

imagSld = options.ImagSld;
if isempty(imagSld)
    imagSld = zeros(N, 1);
elseif numel(imagSld) ~= N
    error('fitting:profileToLayers:imagLengthMismatch', ...
        'ImagSld must match z length (got %d vs %d).', numel(imagSld), N);
end

sldAmbient   = options.SldAmbient;
sldSubstrate = options.SldSubstrate;
if isnan(sldAmbient),   sldAmbient   = sld(1);   end
if isnan(sldSubstrate), sldSubstrate = sld(end); end

% ─── Microslab construction ────────────────────────────────────────
% N profile points → N-1 slabs between adjacent points
dz       = diff(z);                       % (N-1)×1 thicknesses
sldMid   = 0.5 * (sld(1:end-1)   + sld(2:end));
imagMid  = 0.5 * (imagSld(1:end-1) + imagSld(2:end));
rough    = zeros(N - 1, 1);

% Assemble layer matrix
layers = [
    0,            sldAmbient,   0,            0;
    dz,           sldMid,       imagMid,      rough;
    0,            sldSubstrate, 0,            0
];

end
