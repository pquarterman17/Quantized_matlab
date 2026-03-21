%TEST_HYSTERESIS  Tests for hysteresis loop analysis: branch detection,
%   Hc, Mr, Ms, SFD, loop area, models.
%
%   Run:
%     run tests/fitting/test_hysteresis
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_hysteresis ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  HYSTERESIS ANALYSIS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.hysteresisAnalysis ---\n');

% Synthetic tanh loop with known parameters
Ms_true = 5e-4;
Hc_true = 200;
Hw_true = 100;
Hmax = 5000;

H_desc = linspace(Hmax, -Hmax, 500)';
M_desc = Ms_true * tanh((H_desc - Hc_true) / Hw_true);
H_asc = linspace(-Hmax, Hmax, 500)';
M_asc = Ms_true * tanh((H_asc + Hc_true) / Hw_true);
H = [H_desc; H_asc];
M = [M_desc; M_asc];

% Test 1: Basic analysis succeeds
r = utilities.hysteresisAnalysis(H, M);
if ~isempty(r) && isfield(r, 'Hc') && isfield(r, 'Mr')
    fprintf('  PASS: analysis returns complete result\n'); passed = passed + 1;
else
    fprintf('  FAIL: incomplete result\n'); failed = failed + 1;
end

% Test 2: Hc recovery
if abs(r.HcMean - Hc_true) < 20
    fprintf('  PASS: Hc = %.1f (exp %.1f, err %.1f%%)\n', r.HcMean, Hc_true, ...
        abs(r.HcMean - Hc_true)/Hc_true*100);
    passed = passed + 1;
else
    fprintf('  FAIL: Hc = %.1f (exp %.1f)\n', r.HcMean, Hc_true); failed = failed + 1;
end

% Test 3: Ms recovery
if abs(r.MsMean - Ms_true) / Ms_true < 0.05
    fprintf('  PASS: Ms = %.4e (exp %.4e)\n', r.MsMean, Ms_true); passed = passed + 1;
else
    fprintf('  FAIL: Ms = %.4e (exp %.4e)\n', r.MsMean, Ms_true); failed = failed + 1;
end

% Test 4: Mr recovery (tanh with Hc>0 has nonzero Mr)
if all(isfinite(r.Mr)) && r.MrMean > 0
    fprintf('  PASS: Mr = %.4e (finite, positive)\n', r.MrMean); passed = passed + 1;
else
    fprintf('  FAIL: Mr = %.4e\n', r.MrMean); failed = failed + 1;
end

% Test 5: Squareness in physical range
if r.squareness >= 0 && r.squareness <= 1
    fprintf('  PASS: squareness = %.4f (in [0,1])\n', r.squareness); passed = passed + 1;
else
    fprintf('  FAIL: squareness = %.4f\n', r.squareness); failed = failed + 1;
end

% Test 6: Branch detection
if numel(r.ascending.H) > 100 && numel(r.descending.H) > 100
    fprintf('  PASS: branches detected (%d asc, %d desc)\n', ...
        numel(r.ascending.H), numel(r.descending.H));
    passed = passed + 1;
else
    fprintf('  FAIL: branch sizes: %d asc, %d desc\n', ...
        numel(r.ascending.H), numel(r.descending.H));
    failed = failed + 1;
end

% Test 7: SFD
if isfinite(r.SFD.fwhm) && r.SFD.fwhm > 0
    fprintf('  PASS: SFD FWHM = %.1f (positive)\n', r.SFD.fwhm); passed = passed + 1;
else
    fprintf('  FAIL: SFD FWHM = %.1f\n', r.SFD.fwhm); failed = failed + 1;
end

% Test 8: Loop area (positive for a real loop)
if isfinite(r.loopArea) && r.loopArea > 0
    fprintf('  PASS: loop area = %.4e (positive)\n', r.loopArea); passed = passed + 1;
else
    fprintf('  FAIL: loop area = %.4e\n', r.loopArea); failed = failed + 1;
end

% Test 9: Noisy data
rng(42);
M_noisy = M + Ms_true * 0.05 * randn(size(M));
r2 = utilities.hysteresisAnalysis(H, M_noisy);
if abs(r2.HcMean - Hc_true) < 50 && abs(r2.MsMean - Ms_true)/Ms_true < 0.15
    fprintf('  PASS: noisy data: Hc=%.1f, Ms=%.4e (within 15%%)\n', r2.HcMean, r2.MsMean);
    passed = passed + 1;
else
    fprintf('  FAIL: noisy: Hc=%.1f (exp %.1f), Ms=%.4e (exp %.4e)\n', ...
        r2.HcMean, Hc_true, r2.MsMean, Ms_true);
    failed = failed + 1;
end

% Test 10: Symmetric loop (Hc ≈ 0)
H_sym = [linspace(Hmax, -Hmax, 500), linspace(-Hmax, Hmax, 500)]';
M_sym = 1e-3 * tanh(H_sym / 300);
r3 = utilities.hysteresisAnalysis(H_sym, M_sym);
if abs(r3.HcMean) < 10
    fprintf('  PASS: symmetric loop Hc ≈ 0 (%.2f)\n', r3.HcMean); passed = passed + 1;
else
    fprintf('  FAIL: symmetric loop Hc = %.2f (exp ≈0)\n', r3.HcMean); failed = failed + 1;
end

% Test 11: Virgin curve detection
H_virgin = [linspace(0, Hmax, 200)'; linspace(Hmax, -Hmax, 500)'; linspace(-Hmax, Hmax, 500)'];
M_virgin = Ms_true * tanh(H_virgin / 300);
r4 = utilities.hysteresisAnalysis(H_virgin, M_virgin);
if ~isempty(r4.virgin.H) && numel(r4.virgin.H) > 10
    fprintf('  PASS: virgin curve detected (%d points)\n', numel(r4.virgin.H));
    passed = passed + 1;
else
    fprintf('  FAIL: virgin curve not detected\n'); failed = failed + 1;
end

% Test 12: Too few points error
try
    utilities.hysteresisAnalysis(H(1:10), M(1:10));
    fprintf('  FAIL: should error with <20 points\n'); failed = failed + 1;
catch
    fprintf('  PASS: errors with <20 points\n'); passed = passed + 1;
end

% Test 13: Background subtraction + re-analysis
chi_bg = 1e-7;
M_bg = M + chi_bg * H;
r5 = utilities.hysteresisAnalysis(H, M_bg);
% With background, Ms will be shifted — test that the analysis still works
if isfinite(r5.HcMean) && isfinite(r5.MsMean)
    fprintf('  PASS: analysis works with linear background\n'); passed = passed + 1;
else
    fprintf('  FAIL: background data analysis failed\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  HYSTERESIS MODELS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.hysteresisModels ---\n');

cat = fitting.hysteresisModels();

% Test 14: Models have required fields
allOk = true;
for i = 1:numel(cat)
    if ~isfield(cat(i), 'fcn') || ~isfield(cat(i), 'paramNames') || ...
       ~isfield(cat(i), 'p0') || ~isfield(cat(i), 'lb') || ~isfield(cat(i), 'ub')
        allOk = false;
    end
end
if allOk && numel(cat) >= 5
    fprintf('  PASS: %d models with required fields\n', numel(cat)); passed = passed + 1;
else
    fprintf('  FAIL: model issues\n'); failed = failed + 1;
end

% Test 15: All models evaluate without error
x = linspace(-5000, 5000, 200)';
evalOk = true;
for i = 1:numel(cat)
    try
        y = cat(i).fcn(x, cat(i).p0);
        if ~isequal(size(y), size(x)) && ~isscalar(y)
            evalOk = false;
        end
    catch
        evalOk = false;
    end
end
if evalOk
    fprintf('  PASS: all models evaluate on test data\n'); passed = passed + 1;
else
    fprintf('  FAIL: some models failed evaluation\n'); failed = failed + 1;
end

% Test 16: Two-component model fit
m = cat(strcmp({cat.name}, 'Two-Component (F+P)'));
Hfit = linspace(-3000, 3000, 200)';
Mtrue = 4e-4 * tanh((Hfit - 150)/100) + 5e-8*Hfit;
Mnoisy = Mtrue + 1e-5*randn(size(Mtrue));
res = fitting.curveFit(Hfit, Mnoisy, m.fcn, [3e-4 100 150 1e-8], ...
    Lower=m.lb, Upper=m.ub);
if res.R2 > 0.99
    fprintf('  PASS: two-component fit R²=%.4f\n', res.R2); passed = passed + 1;
else
    fprintf('  FAIL: two-component fit R²=%.4f\n', res.R2); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_hysteresis: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_hysteresis:failures', '%d test(s) failed.', failed);
end
