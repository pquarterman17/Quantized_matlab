%TEST_GLOBALFIT  Tests for global/shared-parameter fitting.
%
%   Run:
%     run tests/fitting/test_globalfit
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_globalfit ===\n');
passed = 0;
failed = 0;

fprintf('\n--- fitting.globalFit ---\n');

% ── Synthetic data: exponential decay with shared τ ──────────────
% y = A * exp(-x/τ) + C  where τ and C are shared, A varies per dataset
rng(42);
tau_true = 2.0;
C_true = 0.5;
A_values = [3.0, 5.0, 2.0, 4.0];
nDS = numel(A_values);
x = linspace(0, 10, 100)';

datasets = cell(1, nDS);
for i = 1:nDS
    yTrue = A_values(i) * exp(-x / tau_true) + C_true;
    yNoisy = yTrue + 0.05 * randn(size(x));
    datasets{i} = {x, yNoisy};
end

expFcn = @(x, p) p(1) * exp(-x ./ p(2)) + p(3);
shared = [false true true];  % A free per dataset, τ and C shared

% Test 1: Global fit converges
r = fitting.globalFit(datasets, expFcn, [3 1.5 0], shared, Verbose=false);
if r.exitFlag == 1
    fprintf('  PASS: global fit converged\n'); passed = passed + 1;
else
    fprintf('  FAIL: exit flag = %d\n', r.exitFlag); failed = failed + 1;
end

% Test 2: Shared τ recovered
if abs(r.sharedParams(1) - tau_true) < 0.3
    fprintf('  PASS: shared τ = %.3f (exp %.1f)\n', r.sharedParams(1), tau_true);
    passed = passed + 1;
else
    fprintf('  FAIL: shared τ = %.3f (exp %.1f)\n', r.sharedParams(1), tau_true);
    failed = failed + 1;
end

% Test 3: Shared C recovered
if abs(r.sharedParams(2) - C_true) < 0.2
    fprintf('  PASS: shared C = %.3f (exp %.1f)\n', r.sharedParams(2), C_true);
    passed = passed + 1;
else
    fprintf('  FAIL: shared C = %.3f (exp %.1f)\n', r.sharedParams(2), C_true);
    failed = failed + 1;
end

% Test 4: Per-dataset A values recovered
A_fit = r.perDataset(:, 1);
A_err = abs(A_fit - A_values(:)) ./ A_values(:);
if all(A_err < 0.15)
    fprintf('  PASS: per-dataset A values within 15%% (max err %.1f%%)\n', max(A_err)*100);
    passed = passed + 1;
else
    fprintf('  FAIL: A errors: [%s]%%\n', num2str(A_err'*100, '%.1f '));
    failed = failed + 1;
end

% Test 5: All per-dataset R² > 0.95
if all(r.R2 > 0.95)
    fprintf('  PASS: all R² > 0.95 (min=%.4f)\n', min(r.R2)); passed = passed + 1;
else
    fprintf('  FAIL: min R² = %.4f\n', min(r.R2)); failed = failed + 1;
end

% Test 6: Shared errors are finite
if all(isfinite(r.sharedErrors)) && all(r.sharedErrors > 0)
    fprintf('  PASS: shared param errors are finite and positive\n'); passed = passed + 1;
else
    fprintf('  FAIL: shared errors: [%s]\n', num2str(r.sharedErrors, '%.4g ')); failed = failed + 1;
end

% Test 7: nDatasets correct
if r.nDatasets == nDS
    fprintf('  PASS: nDatasets = %d\n', nDS); passed = passed + 1;
else
    fprintf('  FAIL: nDatasets = %d\n', r.nDatasets); failed = failed + 1;
end

% Test 8: All parameters shared (trivial case)
allShared = [true true true];
r2 = fitting.globalFit(datasets, expFcn, [3 1.5 0], allShared, Verbose=false);
if r2.nParams == 3  % just 3 params total, no per-dataset
    fprintf('  PASS: all-shared mode works (%d params)\n', r2.nParams); passed = passed + 1;
else
    fprintf('  FAIL: all-shared params = %d (exp 3)\n', r2.nParams); failed = failed + 1;
end

% Test 9: No shared parameters (equivalent to batch fit)
noneShared = [false false false];
r3 = fitting.globalFit(datasets, expFcn, [3 1.5 0], noneShared, Verbose=false);
if r3.nParams == nDS * 3
    fprintf('  PASS: no-shared mode works (%d params = %d×3)\n', r3.nParams, nDS);
    passed = passed + 1;
else
    fprintf('  FAIL: no-shared params = %d (exp %d)\n', r3.nParams, nDS*3);
    failed = failed + 1;
end

% Test 10: With bounds
r4 = fitting.globalFit(datasets, expFcn, [3 1.5 0], shared, ...
    Lower=[0 0 -1], Upper=[10 10 5], Verbose=false);
if all(r4.perDataset(:,1) >= 0) && r4.sharedParams(1) >= 0
    fprintf('  PASS: bounds enforced\n'); passed = passed + 1;
else
    fprintf('  FAIL: bounds violated\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_globalfit: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_globalfit:failures', '%d test(s) failed.', failed);
end
