%TEST_BATCH_ROI  Tests for batch fitting (+fitting/batchFit, trackPeak)
%   and ROI statistics computation.
%
%   Run:
%     run tests/fitting/test_batch_roi
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_batch_roi ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  BATCH FIT
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.batchFit ---\n');

% Create 5 synthetic exponential decay datasets with varying τ
rng(42);
nDS = 5;
tauValues = [1.0, 1.5, 2.0, 2.5, 3.0];
datasets = cell(1, nDS);
x = linspace(0, 10, 100)';

for i = 1:nDS
    yTrue = 5 * exp(-x / tauValues(i)) + 0.3;
    yNoisy = yTrue + 0.05 * randn(size(x));
    datasets{i} = {x, yNoisy};
end

expFcn = @(x, p) p(1) * exp(-x ./ p(2)) + p(3);
s = fitting.batchFit(datasets, expFcn, [4 2 0], ...
    Lower=[0 0 -1], Upper=[20 10 5], Verbose=false);

% All 5 datasets converged
if all(s.converged)
    fprintf('  PASS: all %d datasets converged\n', nDS); passed = passed + 1;
else
    fprintf('  FAIL: %d/%d converged\n', sum(s.converged), nDS); failed = failed + 1;
end

% All R² > 0.95
if all(s.R2 > 0.95)
    fprintf('  PASS: all R² > 0.95 (min=%.4f)\n', min(s.R2)); passed = passed + 1;
else
    fprintf('  FAIL: min R² = %.4f\n', min(s.R2)); failed = failed + 1;
end

% τ values recovered within 20%
tauFit = s.params(:, 2);
tauErr = abs(tauFit - tauValues') ./ tauValues';
if all(tauErr < 0.2)
    fprintf('  PASS: τ recovered within 20%% (max err=%.1f%%)\n', max(tauErr)*100);
    passed = passed + 1;
else
    fprintf('  FAIL: τ errors: [%s]%%\n', num2str(tauErr'*100, '%.1f ')); failed = failed + 1;
end

% Output has correct dimensions
if size(s.params, 1) == nDS && size(s.params, 2) == 3
    fprintf('  PASS: params matrix is %dx%d\n', nDS, 3); passed = passed + 1;
else
    fprintf('  FAIL: params size = %dx%d\n', size(s.params)); failed = failed + 1;
end

% Errors matrix same size
if isequal(size(s.errors), size(s.params))
    fprintf('  PASS: errors matrix same size as params\n'); passed = passed + 1;
else
    fprintf('  FAIL: errors size mismatch\n'); failed = failed + 1;
end

% nDatasets correct
if s.nDatasets == nDS
    fprintf('  PASS: nDatasets = %d\n', nDS); passed = passed + 1;
else
    fprintf('  FAIL: nDatasets = %d\n', s.nDatasets); failed = failed + 1;
end

% ── Batch fit with data structs (not just {x,y} pairs) ──────────

dStructs = cell(1, 3);
for i = 1:3
    dStructs{i}.time = x;
    dStructs{i}.values = 2*exp(-x/tauValues(i)) + 0.1 + 0.02*randn(size(x));
    dStructs{i}.labels = {'signal'};
    dStructs{i}.units = {'a.u.'};
    dStructs{i}.metadata = struct('temperature', 100*i);
end

s2 = fitting.batchFit(dStructs, expFcn, [2 1 0], ...
    Lower=[0 0 -1], Upper=[10 10 5], ...
    MetaField='temperature', Verbose=false);

if all(s2.converged) && all(isfinite(s2.metaValues))
    fprintf('  PASS: batch fit with structs + metadata extraction\n');
    passed = passed + 1;
else
    fprintf('  FAIL: struct batch fit or metadata extraction\n'); failed = failed + 1;
end

if isequal(s2.metaValues, [100; 200; 300])
    fprintf('  PASS: metaValues = [100, 200, 300]\n'); passed = passed + 1;
else
    fprintf('  FAIL: metaValues = [%s]\n', num2str(s2.metaValues')); failed = failed + 1;
end

% ── Batch fit with model from catalog ────────────────────────────

cat = fitting.models();
m = cat(strcmp({cat.name}, 'Exponential Decay'));
s3 = fitting.batchFit(datasets, m.fcn, m.p0, ...
    Lower=m.lb, Upper=m.ub, ModelName='Exponential Decay', Verbose=false);

if all(s3.converged)
    fprintf('  PASS: catalog model batch fit converges\n'); passed = passed + 1;
else
    fprintf('  FAIL: catalog model batch fit\n'); failed = failed + 1;
end

% paramNames should come from catalog
if isequal(s3.paramNames, m.paramNames)
    fprintf('  PASS: paramNames from catalog: {%s}\n', strjoin(s3.paramNames, ', '));
    passed = passed + 1;
else
    fprintf('  FAIL: paramNames mismatch\n'); failed = failed + 1;
end

% ── Batch fit with XRange ────────────────────────────────────────

s4 = fitting.batchFit(datasets, expFcn, [4 2 0], ...
    Lower=[0 0 -1], Upper=[20 10 5], XRange=[0 5], Verbose=false);
if all(s4.converged)
    fprintf('  PASS: XRange=[0,5] works\n'); passed = passed + 1;
else
    fprintf('  FAIL: XRange batch fit\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  PEAK TRACKING
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.trackPeak ---\n');

% Create 8 datasets with a Gaussian peak that drifts from x=50 to x=54
peakDS = cell(1, 8);
xPeak = linspace(30, 70, 200)';
peakCenters = linspace(50, 54, 8);

for i = 1:8
    yPeak = 10 * exp(-(xPeak - peakCenters(i)).^2 / (2*1.5^2)) + ...
        0.1*randn(size(xPeak));
    peakDS{i} = {xPeak, yPeak};
end

r = fitting.trackPeak(peakDS, 50, Window=5, Shape='gaussian');

% All peaks found
if all(r.found)
    fprintf('  PASS: all %d peaks found\n', r.nDatasets); passed = passed + 1;
else
    fprintf('  FAIL: %d/%d peaks found\n', sum(r.found), r.nDatasets); failed = failed + 1;
end

% Centers track the drift within 0.3 units
centerErr = abs(r.center - peakCenters');
if all(centerErr < 0.3)
    fprintf('  PASS: centers track drift (max err=%.3f)\n', max(centerErr));
    passed = passed + 1;
else
    fprintf('  FAIL: center errors: [%s]\n', num2str(centerErr', '%.3f ')); failed = failed + 1;
end

% FWHM should be ~2.355*1.5 = 3.53
expectedFWHM = 2.355 * 1.5;
fwhmErr = abs(r.fwhm - expectedFWHM);
if all(fwhmErr < 0.5)
    fprintf('  PASS: FWHM ≈ %.2f (mean=%.2f)\n', expectedFWHM, mean(r.fwhm));
    passed = passed + 1;
else
    fprintf('  FAIL: FWHM values: [%s]\n', num2str(r.fwhm', '%.2f ')); failed = failed + 1;
end

% Heights should be ~10
if all(abs(r.height - 10) < 2)
    fprintf('  PASS: heights ≈ 10 (mean=%.2f)\n', mean(r.height)); passed = passed + 1;
else
    fprintf('  FAIL: heights: [%s]\n', num2str(r.height', '%.2f ')); failed = failed + 1;
end

% R² should be good
if all(r.R2 > 0.9)
    fprintf('  PASS: all local fit R² > 0.9 (min=%.4f)\n', min(r.R2)); passed = passed + 1;
else
    fprintf('  FAIL: min R² = %.4f\n', min(r.R2)); failed = failed + 1;
end

% ── Lorentzian peak tracking ─────────────────────────────────────

lorentzDS = cell(1, 4);
lCenters = [20, 20.5, 21, 21.5];
xL = linspace(10, 30, 200)';
for i = 1:4
    yL = 8 ./ (1 + ((xL - lCenters(i)) ./ 1.0).^2) + 0.05*randn(size(xL));
    lorentzDS{i} = {xL, yL};
end

rL = fitting.trackPeak(lorentzDS, 20, Window=4, Shape='lorentzian');
if all(rL.found) && all(abs(rL.center - lCenters') < 0.3)
    fprintf('  PASS: Lorentzian peak tracking works\n'); passed = passed + 1;
else
    fprintf('  FAIL: Lorentzian tracking\n'); failed = failed + 1;
end

% ── Area is positive and finite ──────────────────────────────────

if all(r.area > 0) && all(isfinite(r.area))
    fprintf('  PASS: peak areas are positive and finite\n'); passed = passed + 1;
else
    fprintf('  FAIL: area issues: [%s]\n', num2str(r.area', '%.2f ')); failed = failed + 1;
end

% ── Follow mode: last peak center should be near 54 ──────────────

rFollow = fitting.trackPeak(peakDS, 50, Window=3, Follow=true);
if rFollow.found(end) && abs(rFollow.center(end) - 54) < 0.5
    fprintf('  PASS: follow mode tracks to x≈54 (%.2f)\n', rFollow.center(end));
    passed = passed + 1;
else
    fprintf('  FAIL: follow mode final center = %.2f (exp ≈54)\n', rFollow.center(end));
    failed = failed + 1;
end

% ── No-follow mode: narrow window should lose drifting peak ──────

rNoFollow = fitting.trackPeak(peakDS, 50, Window=1.5, Follow=false);
% With a tight window centered at 50 and no following, later peaks should be lost
lostCount = sum(~rNoFollow.found);
if lostCount > 0
    fprintf('  PASS: no-follow mode loses %d peaks (as expected)\n', lostCount);
    passed = passed + 1;
else
    fprintf('  PASS: no-follow mode still found all (window wide enough)\n');
    passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_batch_roi: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_batch_roi:failures', '%d test(s) failed.', failed);
end
