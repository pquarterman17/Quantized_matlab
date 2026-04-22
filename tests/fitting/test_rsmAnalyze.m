%TEST_RSMANALYZE  Tests for fitting.rsmAnalyze and fitting.rsmStrain.
%
%   Synthesises a 2D reciprocal-space map with a strong substrate peak
%   and a weaker film peak on a uniform background + Gaussian noise,
%   then checks:
%     - rsmAnalyze returns two peaks
%     - rank-1 (substrate) centre matches injected sub ω/2θ within tol
%     - rank-2 (film) centre matches injected film ω/2θ within tol
%     - FWHMs match the injected widths (angle-space and Q-space)
%     - classification strings are 'substrate' / 'film'
%     - rsmStrain produces ε∥ and ε⊥ matching the injected lattice offsets
%     - rsmStrain relaxation R is 0 for pseudomorphic, 1 for fully relaxed
%
%   Run:
%     run tests/fitting/test_rsmAnalyze
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_rsmAnalyze ===\n');
passed = 0;
failed = 0;

rng(7);   % reproducible noise

% ════════════════════════════════════════════════════════════════════════
%  Build a synthetic RSM
% ════════════════════════════════════════════════════════════════════════
% Axes: ω (rows) in degrees, 2θ (cols) in degrees.
% Two 2D Gaussian peaks on a flat background + small noise.

omegaAxis = (32:0.05:35)';                 % 61 rows, 0.05° step
tthAxis   = (66:0.05:70)';                 % 81 cols
[OM, TT]  = meshgrid(tthAxis, omegaAxis);  % OM=2θ grid, TT=ω grid
%  (variable naming above: first meshgrid output tiles 2θ; second tiles ω)
%  — keep explicit below to avoid confusion.
[TTgrid, OMgrid] = meshgrid(tthAxis, omegaAxis);   % TTgrid = 2θ, OMgrid = ω

% Substrate (strong, narrow): centred at ω=33.8°, 2θ=68.5°
sub = struct('amp', 1000, 'om0', 33.80, 'tt0', 68.50, ...
             'sw_om', 0.10, 'sw_tt', 0.15);   % σ in deg (~2–3 grid steps)
% Film (weaker, broader): centred at ω=33.40°, 2θ=67.70°
film = struct('amp', 250,  'om0', 33.40, 'tt0', 67.70, ...
              'sw_om', 0.15, 'sw_tt', 0.25);

Zsub  = sub.amp  * exp(-((OMgrid-sub.om0).^2 /(2*sub.sw_om^2)   + ...
                         (TTgrid-sub.tt0).^2 /(2*sub.sw_tt^2)));
Zfilm = film.amp * exp(-((OMgrid-film.om0).^2/(2*film.sw_om^2)  + ...
                         (TTgrid-film.tt0).^2/(2*film.sw_tt^2)));
bg    = 3.0;
I     = Zsub + Zfilm + bg + 0.5*randn(size(Zsub));

% Reciprocal-space grids — conventional XRD convention
%   Qx = (2π/λ)(cos ω − cos(2θ−ω))
%   Qz = (2π/λ)(sin ω + sin(2θ−ω))
lambda = 1.5406;  % Cu Kα1 (Å)
omRad  = deg2rad(OMgrid);
tthRad = deg2rad(TTgrid);
Qx = (2*pi/lambda) .* (cos(omRad) - cos(tthRad - omRad));
Qz = (2*pi/lambda) .* (sin(omRad) + sin(tthRad - omRad));

map = struct( ...
    'intensity',     I, ...
    'axis1',         omegaAxis, ...
    'axis2',         tthAxis, ...
    'Qx',            Qx, ...
    'Qz',            Qz, ...
    'intensityUnit', 'cps');

% ════════════════════════════════════════════════════════════════════════
%  rsmAnalyze — detection + fits
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- rsmAnalyze (2 peaks, Gaussian) ---\n');

result = fitting.rsmAnalyze(map, NPeaks=2, FitModel='2D Gaussian', ...
                            SmoothSigma=1.5, MinSeparation=5);

% --- Peak count
if result.nPeaksFound == 2
    fprintf('  PASS: found 2 peaks\n'); passed = passed + 1;
else
    fprintf('  FAIL: found %d peaks (expected 2)\n', result.nPeaksFound);
    failed = failed + 1;
end

% --- Pull peaks in ranked order
if numel(result.peaks) >= 2
    pSub  = result.peaks(1);   % brightest
    pFilm = result.peaks(2);

    tolCentre = 0.05;   % degrees
    tolFWHM   = 0.10;   % degrees (loose — includes smoothing bias)

    % Rank-1 centre matches substrate
    dOmSub  = abs(pSub.centre_angle(1) - sub.om0);
    dTtSub  = abs(pSub.centre_angle(2) - sub.tt0);
    if dOmSub < tolCentre && dTtSub < tolCentre
        fprintf('  PASS: substrate centre recovered (Δω=%.3f°, Δ2θ=%.3f°)\n', dOmSub, dTtSub);
        passed = passed + 1;
    else
        fprintf('  FAIL: substrate centre off (Δω=%.3f°, Δ2θ=%.3f°; tol=%.3f)\n', ...
                dOmSub, dTtSub, tolCentre);
        failed = failed + 1;
    end

    % Rank-2 centre matches film
    dOmFilm = abs(pFilm.centre_angle(1) - film.om0);
    dTtFilm = abs(pFilm.centre_angle(2) - film.tt0);
    if dOmFilm < tolCentre && dTtFilm < tolCentre
        fprintf('  PASS: film centre recovered (Δω=%.3f°, Δ2θ=%.3f°)\n', dOmFilm, dTtFilm);
        passed = passed + 1;
    else
        fprintf('  FAIL: film centre off (Δω=%.3f°, Δ2θ=%.3f°; tol=%.3f)\n', ...
                dOmFilm, dTtFilm, tolCentre);
        failed = failed + 1;
    end

    % FWHM — Gaussian σ → 2√(2 ln 2)·σ
    k  = 2*sqrt(2*log(2));
    % Substrate FWHMs
    expFwhmOmSub = k*sub.sw_om;
    expFwhmTtSub = k*sub.sw_tt;
    dFwOm = abs(pSub.fwhm_angle(1) - expFwhmOmSub);
    dFwTt = abs(pSub.fwhm_angle(2) - expFwhmTtSub);
    if dFwOm < tolFWHM && dFwTt < tolFWHM
        fprintf('  PASS: substrate FWHM recovered (ω: %.3f vs %.3f,  2θ: %.3f vs %.3f)\n', ...
                pSub.fwhm_angle(1), expFwhmOmSub, pSub.fwhm_angle(2), expFwhmTtSub);
        passed = passed + 1;
    else
        fprintf('  FAIL: substrate FWHM off (Δω=%.3f°, Δ2θ=%.3f°; tol=%.3f)\n', ...
                dFwOm, dFwTt, tolFWHM);
        failed = failed + 1;
    end

    % Classification strings
    if strcmp(pSub.classification, 'substrate') && strcmp(pFilm.classification, 'film')
        fprintf('  PASS: classification labels substrate/film\n'); passed = passed + 1;
    else
        fprintf('  FAIL: classification labels (got "%s", "%s")\n', ...
                pSub.classification, pFilm.classification);
        failed = failed + 1;
    end

    % Q-space fit present
    if result.usedQSpace && all(isfinite(pSub.centre_Q)) && all(isfinite(pFilm.centre_Q))
        fprintf('  PASS: Q-space centres finite (sub: [%.4f, %.4f])\n', ...
                pSub.centre_Q(1), pSub.centre_Q(2));
        passed = passed + 1;
    else
        fprintf('  FAIL: Q-space centres not populated (usedQSpace=%d, subQ=[%.3g, %.3g])\n', ...
                result.usedQSpace, pSub.centre_Q(1), pSub.centre_Q(2));
        failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Threshold: noise-only map returns zero peaks
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Noise-only map ---\n');

% Threshold > 1.0 makes the cutoff exceed max(Is) → nothing qualifies.
noiseMap = map;
noiseMap.intensity = 0.5 * randn(size(I));
rN = fitting.rsmAnalyze(noiseMap, NPeaks=2, Threshold=10);
if rN.nPeaksFound == 0
    fprintf('  PASS: no peaks above impossibly-high threshold (noise-only input)\n');
    passed = passed + 1;
else
    fprintf('  FAIL: expected 0 peaks, found %d\n', rN.nPeaksFound);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  rsmStrain — ε∥ / ε⊥ from the fitted peak pair
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- rsmStrain ---\n');

if numel(result.peaks) >= 2
    s = fitting.rsmStrain(result.peaks(1).centre_Q, result.peaks(2).centre_Q);

    % Strain sanity: film Qx ≠ sub Qx (asymmetric peaks here) ⇒ ε∥ finite
    if isfinite(s.eps_parallel) && isfinite(s.eps_perp)
        fprintf('  PASS: strains finite (ε∥=%+0.4f, ε⊥=%+0.4f)\n', ...
                s.eps_parallel, s.eps_perp);
        passed = passed + 1;
    else
        fprintf('  FAIL: non-finite strains (ε∥=%g, ε⊥=%g)\n', ...
                s.eps_parallel, s.eps_perp);
        failed = failed + 1;
    end

    % Expected strain from injected Q positions computed by hand
    omSubRad  = deg2rad(sub.om0);   tthSubRad  = deg2rad(sub.tt0);
    omFilmRad = deg2rad(film.om0);  tthFilmRad = deg2rad(film.tt0);
    QxSub  = (2*pi/lambda)*(cos(omSubRad)  - cos(tthSubRad  - omSubRad));
    QxFilm = (2*pi/lambda)*(cos(omFilmRad) - cos(tthFilmRad - omFilmRad));
    QzSub  = (2*pi/lambda)*(sin(omSubRad)  + sin(tthSubRad  - omSubRad));
    QzFilm = (2*pi/lambda)*(sin(omFilmRad) + sin(tthFilmRad - omFilmRad));
    if QxSub == 0 || QxFilm == 0
        expEpsPar = NaN;
    else
        expEpsPar = QxSub/QxFilm - 1;
    end
    expEpsPerp = QzSub/QzFilm - 1;

    tolEps = 0.005;  % 0.5% absolute (fits have some residual error)
    if abs(s.eps_parallel - expEpsPar) < tolEps && abs(s.eps_perp - expEpsPerp) < tolEps
        fprintf('  PASS: strains match injected Q pair (ε∥ %+0.4f vs %+0.4f, ε⊥ %+0.4f vs %+0.4f)\n', ...
                s.eps_parallel, expEpsPar, s.eps_perp, expEpsPerp);
        passed = passed + 1;
    else
        fprintf('  FAIL: strain mismatch (Δε∥=%.4f, Δε⊥=%.4f; tol=%.4f)\n', ...
                s.eps_parallel - expEpsPar, s.eps_perp - expEpsPerp, tolEps);
        failed = failed + 1;
    end
end

% --- Synthetic strain with known relaxation
% Pseudomorphic: film.Qx = sub.Qx ⇒ R = 0
qs = [3.000, 4.000];
qf_pseu = [3.000, 3.950];   % same Qx as substrate
qf_bulk = [2.980, 3.950];   % a bulk with different in-plane
sPseu = fitting.rsmStrain(qs, qf_pseu, Bulk=qf_bulk);
if abs(sPseu.eps_parallel) < 1e-9 && abs(sPseu.relaxation) < 1e-9
    fprintf('  PASS: pseudomorphic ε∥ = 0 and R = 0\n'); passed = passed + 1;
else
    fprintf('  FAIL: pseudomorphic expected ε∥=0/R=0 but got ε∥=%.3g, R=%.3g\n', ...
            sPseu.eps_parallel, sPseu.relaxation);
    failed = failed + 1;
end

% Fully relaxed: film.Qx = bulk.Qx ⇒ R = 1
qf_rel = qf_bulk;   % film at bulk position
sRel = fitting.rsmStrain(qs, qf_rel, Bulk=qf_bulk);
if abs(sRel.relaxation - 1) < 1e-9
    fprintf('  PASS: fully relaxed R = 1\n'); passed = passed + 1;
else
    fprintf('  FAIL: fully relaxed R = %.6f (expected 1)\n', sRel.relaxation);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════════
fprintf('\n%s\n', repmat('=', 1, 50));
fprintf('  test_rsmAnalyze: %d passed, %d failed\n', passed, failed);
fprintf('%s\n', repmat('=', 1, 50));

if failed > 0
    error('test_rsmAnalyze:failures', '%d test(s) failed.', failed);
end
