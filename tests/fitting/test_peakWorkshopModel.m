%TEST_PEAKWORKSHOPMODEL  Tests for the PeakWorkshopModel handle class.
%
%   Exercises the model in isolation against synthetic Lorentzian and
%   Gaussian peaks, with no GUI and no main BosonPlotter state. This is
%   the proof-of-concept that the workshop pattern actually decouples
%   peak logic from the orchestrator: every test below constructs a
%   `PeakWorkshopModel`, hands it numeric vectors, and inspects the
%   resulting peak struct.
%
%   Run:
%     run tests/fitting/test_peakWorkshopModel
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_peakWorkshopModel ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  Synthetic data builders
% ════════════════════════════════════════════════════════════════════
makeLorentzian = @(x, x0, fwhm, h) h ./ (1 + 4*((x - x0) / fwhm).^2);
makeGaussian   = @(x, x0, fwhm, h) h .* exp(-4*log(2)*((x - x0) / fwhm).^2);

% ════════════════════════════════════════════════════════════════════
%  CONSTRUCTION + DEFAULTS
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- Construction + defaults ---\n');
try
    m = bosonPlotter.peak.PeakWorkshopModel();
    assert(m.peakSNR == 5, 'default SNR');
    assert(abs(m.peakProminence - 0.02) < 1e-12, 'default prominence');
    assert(abs(m.kFactor - 0.9) < 1e-12, 'default K');
    assert(strcmp(m.fitModel, 'Lorentzian'), 'default model');
    assert(isempty(m.peaks), 'starts with empty peaks');
    assert(m.selectedPeakIdx == 0, 'no selection');
    fprintf('  PASS: defaults OK\n'); passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  DETECT — single Lorentzian
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- detect() on single Lorentzian ---\n');
try
    x = linspace(20, 80, 1500)';
    y = 100 + makeLorentzian(x, 45.0, 0.4, 800) + 0.5*randn(size(x));
    m = bosonPlotter.peak.PeakWorkshopModel();
    m.detect(x, y);
    assert(numel(m.peaks) >= 1, 'should find at least one peak');
    centers = [m.peaks.center];
    [~, k] = min(abs(centers - 45));
    assert(abs(m.peaks(k).center - 45.0) < 0.5, ...
        sprintf('detected centre %.3f not near 45.0', m.peaks(k).center));
    assert(~isempty(m.snipBackground.bg), 'snipBackground populated');
    fprintf('  PASS: single Lorentzian detected at %.3f (target 45.000)\n', m.peaks(k).center);
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  DETECT — two well-separated Lorentzians
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- detect() on two Lorentzians ---\n');
try
    x = linspace(20, 80, 1500)';
    y = 100 + makeLorentzian(x, 30.0, 0.3, 600) + ...
              makeLorentzian(x, 60.0, 0.5, 400) + 0.3*randn(size(x));
    m = bosonPlotter.peak.PeakWorkshopModel();
    m.detect(x, y);
    centers = sort([m.peaks.center]);
    near30 = any(abs(centers - 30) < 1);
    near60 = any(abs(centers - 60) < 1);
    assert(near30 && near60, ...
        sprintf('expected peaks near 30 and 60; got [%s]', num2str(centers)));
    fprintf('  PASS: two peaks detected (centres: %s)\n', num2str(centers, '%.2f '));
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  FIT — single peak refines centre + FWHM
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- fitOne() refines a peak ---\n');
try
    x = linspace(20, 80, 1500)';
    trueCentre = 45.123;  trueFWHM = 0.42;
    y = 50 + makeLorentzian(x, trueCentre, trueFWHM, 1000) + 0.2*randn(size(x));
    m = bosonPlotter.peak.PeakWorkshopModel();
    m.detect(x, y);
    [~, k] = min(abs([m.peaks.center] - trueCentre));
    r = m.fitOne(k, x, y);
    assert(r.success, sprintf('fit should succeed: %s', r.reason));
    fitCentre = m.peaks(k).center;
    fitFWHM   = m.peaks(k).fwhm;
    assert(abs(fitCentre - trueCentre) < 0.05, ...
        sprintf('fit centre %.4f off from true %.4f', fitCentre, trueCentre));
    assert(abs(fitFWHM - trueFWHM) < 0.10, ...
        sprintf('fit FWHM %.4f off from true %.4f', fitFWHM, trueFWHM));
    assert(strcmp(m.peaks(k).status, 'fitted'), 'status should be fitted');
    fprintf('  PASS: centre %.4f (target %.4f), FWHM %.4f (target %.4f)\n', ...
        fitCentre, trueCentre, fitFWHM, trueFWHM);
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  FIT — Gaussian model
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- fitOne() with Gaussian model ---\n');
try
    x = linspace(20, 80, 1500)';
    trueCentre = 50.0;  trueFWHM = 0.6;
    y = 50 + makeGaussian(x, trueCentre, trueFWHM, 1000) + 0.2*randn(size(x));
    m = bosonPlotter.peak.PeakWorkshopModel();
    m.fitModel = 'Gaussian';
    m.detect(x, y);
    [~, k] = min(abs([m.peaks.center] - trueCentre));
    r = m.fitOne(k, x, y);
    assert(r.success, sprintf('Gaussian fit should succeed: %s', r.reason));
    assert(abs(m.peaks(k).center - trueCentre) < 0.05, 'Gaussian centre off');
    assert(abs(m.peaks(k).fwhm - trueFWHM) < 0.10, 'Gaussian FWHM off');
    fprintf('  PASS: Gaussian fit centre=%.4f, FWHM=%.4f\n', ...
        m.peaks(k).center, m.peaks(k).fwhm);
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  FITALL — collects failures
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- fitAll() returns failures list ---\n');
try
    x = linspace(20, 80, 1500)';
    y = 50 + makeLorentzian(x, 30.0, 0.4, 800) + ...
             makeLorentzian(x, 60.0, 0.5, 600) + 0.2*randn(size(x));
    m = bosonPlotter.peak.PeakWorkshopModel();
    m.detect(x, y);
    failures = m.fitAll(x, y);
    fittedCount = sum(strcmp({m.peaks.status}, 'fitted'));
    assert(fittedCount >= 2, ...
        sprintf('expected ≥2 fitted; got %d (failures: %d)', fittedCount, numel(failures)));
    if ~isempty(failures)
        % Failure entries must have all fields filled
        f = failures(1);
        assert(isfield(f, 'idx') && isfield(f, 'reason') && ...
               isfield(f, 'suggestion') && isfield(f, 'window'), 'failure shape');
    end
    fprintf('  PASS: fitAll fitted %d/%d peaks (failures: %d)\n', ...
        fittedCount, numel(m.peaks), numel(failures));
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  ADDMANUAL — auto-fit on click
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- addManual() snaps to local max + auto-fits ---\n');
try
    x = linspace(20, 80, 1500)';
    trueCentre = 50.0;  trueFWHM = 0.4;
    y = 50 + makeLorentzian(x, trueCentre, trueFWHM, 800) + 0.2*randn(size(x));
    m = bosonPlotter.peak.PeakWorkshopModel();

    % Click at 49.7 (slightly off the true centre)
    r = m.addManual(49.7, x, y);
    assert(numel(m.peaks) == 1, 'should add one peak');
    pk = m.peaks(1);
    assert(abs(pk.center - trueCentre) < 0.1, ...
        sprintf('addManual centre %.4f off from true %.4f', pk.center, trueCentre));
    assert(strcmp(pk.status, 'fitted') || strcmp(pk.status, 'manual'), ...
        'status must be fitted or manual');
    if r.success
        assert(strcmp(pk.status, 'fitted'), 'fit success → status fitted');
    end
    fprintf('  PASS: addManual centre=%.4f, status=%s, fit success=%d\n', ...
        pk.center, pk.status, r.success);
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  REMOVE + CLEAR + SELECT
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- removePeak / clearPeaks / selectPeak ---\n');
try
    x = linspace(20, 80, 1500)';
    y = 50 + makeLorentzian(x, 30, 0.4, 800) + ...
             makeLorentzian(x, 50, 0.5, 600) + ...
             makeLorentzian(x, 70, 0.4, 400) + 0.3*randn(size(x));
    m = bosonPlotter.peak.PeakWorkshopModel();
    m.detect(x, y);
    n0 = numel(m.peaks);
    assert(n0 >= 3, sprintf('expected ≥3 peaks; got %d', n0));

    m.selectPeak(2);
    assert(m.selectedPeakIdx == 2, 'select(2)');
    m.removePeak(1);
    assert(numel(m.peaks) == n0 - 1, 'remove drops one peak');
    assert(m.selectedPeakIdx == 1, 'selection shifts down');

    m.clearPeaks();
    assert(isempty(m.peaks), 'clear empties peak list');
    assert(m.selectedPeakIdx == 0, 'clear resets selection');
    fprintf('  PASS: remove/clear/select work as expected\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  BIND / APPLY round-trip
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- bindFromDataset / applyToDataset round-trip ---\n');
try
    x = linspace(20, 80, 1500)';
    y = 50 + makeLorentzian(x, 45.0, 0.4, 800) + 0.2*randn(size(x));
    m1 = bosonPlotter.peak.PeakWorkshopModel();
    m1.detect(x, y);
    nPeaks = numel(m1.peaks);

    % Synthesize a minimal dataset struct
    ds = struct('peaks', m1.peaks, 'snipBackground', m1.snipBackground);

    m2 = bosonPlotter.peak.PeakWorkshopModel();
    m2.bindFromDataset(ds);
    assert(numel(m2.peaks) == nPeaks, 'bind preserves count');
    assert(abs(m2.peaks(1).center - m1.peaks(1).center) < 1e-12, 'bind preserves centre');

    ds2 = m2.applyToDataset(struct());
    assert(isfield(ds2, 'peaks') && numel(ds2.peaks) == nPeaks, 'apply writes peaks');
    fprintf('  PASS: bind/apply round-trip preserves peaks (count=%d)\n', nPeaks);
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  REGRESSION — fitAll on legacy 11-field peaks must not throw
%  ("Subscripted assignment between dissimilar structures")
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- fitAll() against legacy 11-field peaks (regression) ---\n');
try
    x = linspace(20, 80, 1500)';
    y = 50 + makeLorentzian(x, 30.0, 0.4, 800) + ...
             makeLorentzian(x, 60.0, 0.5, 600) + 0.2*randn(size(x));

    % Synthesize a legacy dataset whose ds.peaks is missing
    % asymmetry / fitParams (the shape saved before the canonical
    % schema was extended in MASTERPLAN W5 #59 fix commit).
    legacyPeaks = struct('center',{30.0, 60.0}, 'fwhm',{0.4, 0.5}, ...
        'height',{800, 600}, 'area',{NaN, NaN}, 'xRange',{[],[]}, ...
        'status',{'manual','manual'}, 'bg',{NaN, NaN}, 'model',{'',''}, ...
        'eta',{NaN, NaN}, 'prominence',{NaN, NaN}, 'localSNR',{NaN, NaN});
    ds = struct('peaks', legacyPeaks, 'snipBackground', struct());

    m = bosonPlotter.peak.PeakWorkshopModel();
    m.bindFromDataset(ds);
    % bindFromDataset normalises: every peak now has 13 fields.
    assert(isfield(m.peaks, 'asymmetry') && isfield(m.peaks, 'fitParams'), ...
        'normalize must add asymmetry + fitParams');

    % This would have thrown "dissimilar structures" before the fix.
    failures = m.fitAll(x, y);
    fittedCount = sum(strcmp({m.peaks.status}, 'fitted'));
    assert(fittedCount >= 1, ...
        sprintf('expected ≥1 fitted on legacy peaks; got %d (failures: %d)', ...
            fittedCount, numel(failures)));
    fprintf('  PASS: legacy peaks fit without struct-shape error (%d fitted, %d failed)\n', ...
        fittedCount, numel(failures));
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════
fprintf('\n=== test_peakWorkshopModel: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_peakWorkshopModel:failed', '%d test(s) failed', failed);
end
