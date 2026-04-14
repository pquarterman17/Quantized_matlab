function R = parrattRefl(Q, layers, options)
%PARRATTREFL  Specular reflectivity via Parratt recursion, with optional
%             instrument Q-resolution smearing.
%
%   R = fitting.parrattRefl(Q, layers)
%   R = fitting.parrattRefl(Q, layers, Roughness=true)
%   R = fitting.parrattRefl(Q, layers, Resolution=0.03)     % dQ/Q = 3 %%
%   R = fitting.parrattRefl(Q, layers, Resolution=dQ_vec)   % pointwise
%
%   Computes specular reflectivity R(Q) for a multilayer thin-film stack
%   using the recursive Parratt formalism with optional Névot-Croce
%   interfacial roughness. When a finite instrument Q-resolution is
%   supplied the ideal R(Q) is Gaussian-convolved with a kernel of width
%   dQ(Q) on an oversampled grid — the standard treatment for NCNR and
%   PANalytical data where dQ/Q ~ 3–6 %% and unsmeared fits bias layer
%   thickness and roughness.
%
%   Inputs:
%       Q      — [N×1] momentum transfer vector (Å⁻¹), Q = 4π sin(θ)/λ
%       layers — [M×4] matrix where each row defines a layer:
%                  [thickness(Å), SLD_real(Å⁻²), SLD_imag(Å⁻²), roughness(Å)]
%                Row 1 = incident medium (thickness ignored, usually air/vacuum)
%                Row M = substrate (thickness ignored, semi-infinite)
%                Rows 2..M-1 = thin film layers (top to bottom)
%
%   Options:
%       Roughness  — apply Névot-Croce roughness (default: true)
%       Scale      — overall scale factor (default: 1.0)
%       Background — constant background added to R (default: 0)
%       Resolution — instrument Q-resolution kernel width as Gaussian σ_Q:
%                      [] / 0         no smearing (default, backward-compatible)
%                      scalar         constant dQ/Q (σ_Q = fractional × Q)
%                      [N×1] vector   per-point σ_Q (Å⁻¹), one per input Q
%                    When non-empty the function oversamples each input Q
%                    point to ±3σ and returns the Gaussian-weighted R.
%
%   Output:
%       R — [N×1] reflectivity (|r|²), same size as Q
%
%   Layer convention:
%       Layer 1: incident medium (air: SLD ≈ 0, thickness = 0)
%       Layer 2: top film layer
%       ...
%       Layer M-1: bottom film layer
%       Layer M: substrate (Si: SLD ≈ 2.07e-6 Å⁻², thickness = 0)
%
%   Complex SLD sign convention:
%       The internal complex SLD is built as  sld = SLD_real + i * SLD_imag
%       with SLD_imag >= 0 for absorbing materials (e.g. Au, Pt, Cu at
%       X-ray energies). kz in each layer is then
%         kz_j = sqrt((Q/2)^2 - 4*pi*sld_j),
%       the standard Parratt form consistent with the optics convention
%       n^2 = 1 - (lambda^2/pi) * SLD_complex where SLD_complex carries
%       the same +i sign. Presets in fitting.reflSLDPresets store
%       sldImag as a POSITIVE number by this convention — expect
%       physical (monotonically decaying) R(Q) at high Q.
%
%   Examples:
%       % Bare silicon in air
%       Q = linspace(0.005, 0.3, 500)';
%       layers = [0 0 0 0; 0 2.07e-6 0 3];
%       R = fitting.parrattRefl(Q, layers);
%       semilogy(Q, R);
%
%       % 200 Å SiO₂ on Si
%       layers = [0 0 0 0; 200 3.47e-6 0 5; 0 2.07e-6 0 3];
%       R = fitting.parrattRefl(Q, layers);
%
%   See also fitting.sldProfile, fitting.reflSLDPresets, fitting.curveFit

arguments
    Q      (:,1) double
    layers (:,4) double
    options.Roughness  (1,1) logical = true
    options.Scale      (1,1) double = 1.0
    options.Background (1,1) double = 0
    options.Resolution      double  = []   % [] | scalar dQ/Q | N-vector dQ
end

nLayers = size(layers, 1);
if nLayers < 2
    error('fitting:parrattRefl:tooFewLayers', ...
        'Need at least 2 layers (incident medium + substrate).');
end

N = numel(Q);

% ════════════════════════════════════════════════════════════════════════
%  Resolution smearing branch (oversample + Gaussian weight). Recurse
%  with Resolution=[] so we don't loop forever.
% ════════════════════════════════════════════════════════════════════════
if ~isempty(options.Resolution) && any(options.Resolution > 0)
    res = options.Resolution;
    if isscalar(res)
        dQ = Q(:) * res;                     % constant dQ/Q → σ_Q per point
    elseif numel(res) == N
        dQ = res(:);                         % per-point σ_Q
    else
        error('fitting:parrattRefl:badResolution', ...
            ['Resolution must be empty, a scalar dQ/Q, or an N-vector ' ...
             'of σ_Q (got %d elements, expected %d).'], numel(res), N);
    end

    nOver  = 21;     % samples per point
    nSigma = 3;      % truncation in σ
    R      = zeros(N, 1);
    for iPt = 1:N
        if dQ(iPt) <= 0
            % Zero resolution at this point — evaluate a single point
            R(iPt) = fitting.parrattRefl(Q(iPt), layers, ...
                Roughness=options.Roughness, ...
                Scale=options.Scale, ...
                Background=options.Background);
            continue;
        end
        qSamp = linspace(Q(iPt) - nSigma * dQ(iPt), ...
                         Q(iPt) + nSigma * dQ(iPt), nOver)';
        qSamp = max(qSamp, 1e-6);            % avoid non-physical negatives
        Rsamp = fitting.parrattRefl(qSamp, layers, ...
            Roughness=options.Roughness, ...
            Scale=options.Scale, ...
            Background=options.Background);
        w     = exp(-0.5 * ((qSamp - Q(iPt)) / dQ(iPt)).^2);
        R(iPt) = sum(w .* Rsamp) / sum(w);
    end
    return;
end

% Extract layer parameters
d     = layers(:, 1);   % thickness (Å)
sldR  = layers(:, 2);   % SLD real (Å⁻²)
sldI  = layers(:, 3);   % SLD imag (Å⁻²)
sigma = layers(:, 4);   % roughness (Å)

% Complex SLD
sld = sldR + 1i * sldI;

% ════════════════════════════════════════════════════════════════════════
% Compute k_z in each layer: k_z,j = sqrt((Q/2)² - 4π·SLD_j)
% ════════════════════════════════════════════════════════════════════════

% Q is [N×1], sld is [1×M] → kz is [N×M]
Q2 = Q(:);
Qsq_over4 = (Q2 / 2).^2;  % [N×1]
sldRow = sld(:)';           % [1×M]

kz = sqrt(Qsq_over4 - 4*pi*sldRow);  % [N×M] complex

% ════════════════════════════════════════════════════════════════════════
% Parratt recursion (bottom-up)
% ════════════════════════════════════════════════════════════════════════

% Start from the substrate (layer M) — no reflection below it
r = zeros(N, 1);  % reflectance ratio at substrate bottom = 0

for j = nLayers:-1:2
    % Fresnel coefficient at interface between layer j-1 and layer j
    kz_above = kz(:, j-1);
    kz_below = kz(:, j);

    fj = (kz_above - kz_below) ./ (kz_above + kz_below);

    % Névot-Croce roughness
    if options.Roughness && sigma(j) > 0
        fj = fj .* exp(-2 * kz_above .* kz_below * sigma(j)^2);
    end

    % Phase factor for layer j (skip for substrate, d=0)
    if j < nLayers && d(j) > 0
        phase = exp(2i * kz_below * d(j));
    else
        phase = ones(N, 1);
    end

    % Parratt recursion: combine reflectance from below with this interface
    r = (fj + r .* phase) ./ (1 + fj .* r .* phase);
end

% Reflectivity = |r|²
R = abs(r).^2;

% Apply scale and background
R = options.Scale * R + options.Background;

% Clamp to physical range
R = max(R, 0);

end
