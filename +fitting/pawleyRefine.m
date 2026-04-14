function result = pawleyRefine(twoTheta, intensity, phaseInfo, options)
%PAWLEYREFINE  Pawley whole-pattern refinement for powder XRD (scaffold).
%
%   TODO: scaffold implementation. Lattice parameters and scale factor
%   are currently refined by a simple grid search around the initial
%   guess; peak intensities are fit free. The production target is a
%   full Levenberg-Marquardt minimisation over (cell parameters, peak
%   profile, background) with the Cagliotti U/V/W profile width model.
%   See docs/theory/xrd.md "Pawley Refinement" section for the spec.
%
%   Syntax
%   ------
%       result = fitting.pawleyRefine(twoTheta, intensity, phaseInfo)
%       result = fitting.pawleyRefine(twoTheta, intensity, phaseInfo, ...
%                   Wavelength=1.5406, MaxTwoTheta=120, ...
%                   Background='linear', ProfileFWHM=0.05)
%
%   Inputs
%   ------
%   twoTheta    [N×1] scan angle 2θ in degrees.
%   intensity   [N×1] observed counts / intensity at each 2θ.
%   phaseInfo   struct with fields:
%                 .a, .b, .c        lattice parameters (Å)
%                 .alpha, .beta, .gamma  lattice angles (deg), default 90
%                 .symmetry         space group symbol or Bravais letter
%                                   (e.g. 'Fm-3m', 'P', 'F', ...)
%                 .hklMax           highest Miller index to consider (default 6)
%
%   Options
%   -------
%   Wavelength   Å, CuKα1 by default (1.5406)
%   MaxTwoTheta  (deg) cut-off (default 120)
%   Background   'linear' | 'polynomial' | 'cheby' (default 'linear')
%                TODO: currently only linear is implemented
%   ProfileFWHM  (deg) pseudo-Voigt FWHM for each peak (default 0.05)
%                TODO: Cagliotti U/V/W profile is the production goal
%   RefineCell   logical, refine lattice parameters (default true)
%   MaxIter      outer-loop iterations for cell refinement (default 20)
%
%   Outputs
%   -------
%   result — struct with fields:
%     .cell        — refined [a b c alpha beta gamma] (Å, deg)
%     .cellInitial — initial cell, for reference
%     .scale       — overall scale factor fitted
%     .peaks       — struct array with .hkl, .twoTheta, .d, .intensity
%     .background  — [N×1] fitted background
%     .model       — [N×1] total fitted intensity (peaks + background)
%     .residual    — [N×1] intensity - model
%     .rwp         — weighted profile R-factor (sqrt of sum(w·resid²)/sum(w·obs²))
%     .nPeaks      — number of allowed reflections within MaxTwoTheta
%
%   Notes
%   -----
%   * Pawley refinement fits INTEGRATED INTENSITIES freely — it does
%     NOT require a structural model. Use for quick cell refinement
%     before moving to full Rietveld (which constrains intensities
%     via atomic positions + thermal parameters).
%   * The allowed reflections are filtered by the symmetry field's
%     centering rules (P, F, I, C, A, B, R). Glide/screw systematic
%     absences are NOT applied yet — TODO: integrate with a space-
%     group extinction table.
%
%   Example
%   -------
%   % Cubic Si, a = 5.4307 Å, CuKα1
%   phaseInfo = struct('a',5.4307, 'b',5.4307, 'c',5.4307, ...
%                      'alpha',90,'beta',90,'gamma',90, ...
%                      'symmetry','F', 'hklMax',4);
%   [tt, I] = importXRDML('si.xrdml');  % hypothetical
%   result = fitting.pawleyRefine(tt, I, phaseInfo);
%   fprintf('Refined a = %.5f Å\n', result.cell(1));
%
%   References
%   ----------
%   Pawley, G.S., "Unit-cell refinement from powder diffraction scans",
%     J. Appl. Cryst. 14, 357 (1981). DOI: 10.1107/S0021889881009618
%   Rietveld, H.M., "A profile refinement method for nuclear and magnetic
%     structures", J. Appl. Cryst. 2, 65 (1969).
%   Cagliotti, G. et al., Nucl. Instrum. 3, 223 (1958) — U/V/W profile.
%   Larson, A.C. & Von Dreele, R.B., GSAS Technical Manual LANSCE (2004).
%
%   See also calc.crystal.planeSpacings, calc.crystal.matchPhases,
%            fitting.mcmcSample

% ════════════════════════════════════════════════════════════════════════
%  Arguments
% ════════════════════════════════════════════════════════════════════════
arguments
    twoTheta   (:,1) double {mustBeNonempty}
    intensity  (:,1) double {mustBeNonempty}
    phaseInfo  (1,1) struct
    options.Wavelength   (1,1) double = 1.5406
    options.MaxTwoTheta  (1,1) double = 120
    options.Background   (1,:) char {mustBeMember(options.Background, ...
                                     {'linear','polynomial','cheby'})} = 'linear'
    options.ProfileFWHM  (1,1) double = 0.05
    options.RefineCell   (1,1) logical = true
    options.MaxIter      (1,1) double {mustBeInteger, mustBePositive} = 20
end

if numel(twoTheta) ~= numel(intensity)
    error('fitting:pawleyRefine:sizeMismatch', ...
        'twoTheta (%d) and intensity (%d) must have the same length.', ...
        numel(twoTheta), numel(intensity));
end

% ── Validate phaseInfo ──────────────────────────────────────────────
required = {'a','b','c','symmetry'};
for k = 1:numel(required)
    if ~isfield(phaseInfo, required{k})
        error('fitting:pawleyRefine:missingField', ...
            'phaseInfo is missing required field "%s".', required{k});
    end
end
if ~isfield(phaseInfo, 'alpha'), phaseInfo.alpha = 90; end
if ~isfield(phaseInfo, 'beta'),  phaseInfo.beta  = 90; end
if ~isfield(phaseInfo, 'gamma'), phaseInfo.gamma = 90; end
if ~isfield(phaseInfo, 'hklMax'), phaseInfo.hklMax = 6; end

cell0 = [phaseInfo.a, phaseInfo.b, phaseInfo.c, ...
         phaseInfo.alpha, phaseInfo.beta, phaseInfo.gamma];

% ── Helper: compute peak positions for a given cell ────────────────
function peaks = computePeaks(cellParams, centering)
    % Delegate to calc.crystal.planeSpacings. We filter by MaxTwoTheta
    % here because planeSpacings uses MinD instead of a twoTheta cut.
    ps = calc.crystal.planeSpacings(cellParams(1), ...
        'b', cellParams(2), ...
        'c', cellParams(3), ...
        'alpha', cellParams(4), ...
        'beta',  cellParams(5), ...
        'gamma', cellParams(6), ...
        'Centering', centering, ...
        'MaxHKL',    phaseInfo.hklMax, ...
        'Lambda',    options.Wavelength);

    mask = ~isnan(ps.twoTheta) & ps.twoTheta <= options.MaxTwoTheta & ...
           ps.twoTheta > 0;
    nPk = sum(mask);
    peaks = repmat(struct('hkl', [0 0 0], 'twoTheta', 0, 'd', 0, ...
        'multiplicity', 1, 'intensity', 0), nPk, 1);
    idx = find(mask);
    for i = 1:nPk
        k = idx(i);
        peaks(i).hkl          = ps.hkl(k, :);
        peaks(i).twoTheta     = ps.twoTheta(k);
        peaks(i).d            = ps.d(k);
        peaks(i).multiplicity = ps.multiplicity(k);
    end
end

% ── Objective: χ² for a trial cell (intensities fit free) ──────────
function chi2 = trialChi2(cellParams)
    peaks = computePeaks(cellParams, phaseInfo.symmetry);
    if isempty(peaks)
        chi2 = Inf; return;
    end
    modelY = buildModel(peaks, twoTheta, intensity, options);
    resid  = modelY - intensity;
    chi2   = sum(resid.^2);
end

% ── Refine cell via simple adaptive grid search around initial ──────
% TODO: replace with Levenberg-Marquardt over (cell, profile, bg).
% Placeholder: detect the crystal system from the input cell and tie
% the axes that should be constrained. For cubic (a=b=c) we step one
% axis and mirror; for tetragonal (a=b≠c) we step {a,c}; for lower
% symmetry we step all three independently.
cellRefined = cell0;
if options.RefineCell
    tolEq    = 1e-4;
    isCubic  = abs(cell0(1) - cell0(2)) < tolEq && abs(cell0(2) - cell0(3)) < tolEq;
    isTetrag = abs(cell0(1) - cell0(2)) < tolEq && abs(cell0(2) - cell0(3)) >= tolEq;

    if isCubic
        axesToStep = {1};                % a only; mirror to b, c
        mirrorFcn  = @(c, v) [v v v c(4:6)];
    elseif isTetrag
        axesToStep = {1, 3};             % a (mirror to b) and c
        mirrorFcn  = @(c, v) [v v c(3:6)]; %#ok<ISMAT> — overridden per axis below
    else
        axesToStep = {1, 2, 3};
        mirrorFcn  = [];
    end

    step = 0.02 * cell0(1:3);
    for iter = 1:options.MaxIter
        chiBase  = trialChi2(cellRefined);
        improved = false;
        for ii = 1:numel(axesToStep)
            ax = axesToStep{ii};
            for sign = [1, -1]
                trial = cellRefined;
                if isCubic
                    newVal   = cellRefined(1) + sign * step(1);
                    trial    = [newVal newVal newVal cellRefined(4:6)];
                elseif isTetrag && ax == 1
                    newVal   = cellRefined(1) + sign * step(1);
                    trial    = [newVal newVal cellRefined(3) cellRefined(4:6)];
                else
                    trial(ax) = cellRefined(ax) + sign * step(ax);
                end
                if trialChi2(trial) < chiBase
                    cellRefined = trial;
                    improved    = true;
                    break;
                end
            end
        end
        if ~improved
            step = step / 2;
            if max(abs(step)) < 1e-5, break; end
        end
    end
end

% ── Final model on refined cell ────────────────────────────────────
peaks                   = computePeaks(cellRefined, phaseInfo.symmetry);
[modelY, ~, bg, peakI]  = buildModel(peaks, twoTheta, intensity, options);
residual                = intensity - modelY;

% Rwp (weighted-profile R-factor, sqrt form)
w        = 1 ./ max(intensity, 1);    % Poisson-like weights
rwp_num  = sum(w .* residual.^2);
rwp_den  = sum(w .* intensity.^2);
if rwp_den > 0
    rwp = sqrt(rwp_num / rwp_den);
else
    rwp = NaN;
end

% Attach fit intensities to peaks for caller convenience
for k = 1:numel(peaks)
    peaks(k).intensity = peakI(k);
end

result.cell        = cellRefined;
result.cellInitial = cell0;
result.scale       = NaN;             % TODO: currently folded into per-peak intensity
result.peaks       = peaks;
result.background  = bg;
result.model       = modelY;
result.residual    = residual;
result.rwp         = rwp;
result.nPeaks      = numel(peaks);

end

% ════════════════════════════════════════════════════════════════════════
function [modelY, IobsUnused, bg, peakIntensity] = buildModel(peaks, twoTheta, intensity, options)
%BUILDMODEL  Build the fitted profile given a peak list.
%   Each peak is fit with a pseudo-Voigt of width ProfileFWHM; peak
%   integrated intensities are solved by linear least-squares against
%   the observed intensity after subtracting a linear background.

nPk = numel(peaks);
IobsUnused = []; %#ok<NASGU>

if nPk == 0
    modelY = zeros(size(twoTheta));
    bg = zeros(size(twoTheta));
    peakIntensity = [];
    return;
end

% Pseudo-Voigt basis (fixed FWHM, 50-50 mix) for each peak
fwhm = options.ProfileFWHM;
w    = fwhm / 2;
basis = zeros(numel(twoTheta), nPk);
for k = 1:nPk
    dx = twoTheta - peaks(k).twoTheta;
    lorentz = 1 ./ (1 + (dx / w).^2);
    gauss   = exp(-0.5 * (dx / (w / sqrt(2 * log(2)))).^2);
    basis(:, k) = 0.5 * lorentz + 0.5 * gauss;
end

% Linear background: 1, twoTheta
bgBasis = [ones(size(twoTheta)), twoTheta];

% Solve [basis | bgBasis] * x = intensity (non-negative on peak part)
A  = [basis, bgBasis];
x  = A \ intensity;
peakIntensity = max(x(1:nPk), 0);
bgCoeff       = x(nPk+1:end);

bg     = bgBasis * bgCoeff;
modelY = basis * peakIntensity + bg;
end
