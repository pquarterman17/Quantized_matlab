%TEST_GLOBALCURVEFIT  Tests for fitting.globalCurveFit (constraint-based global fitting).
%
%   Run:
%       run tests/fitting/test_globalCurveFit
%       runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_globalCurveFit ===\n');
passed = 0;
failed = 0;

catalog    = fitting.models();
gaussModel = catalog(strcmp({catalog.name}, 'Gaussian'));
linearModel = catalog(strcmp({catalog.name}, 'Linear'));

rng(7);

% ════════════════════════════════════════════════════════════════════════
% Test 1: Shared sigma, independent A and mu (3 Gaussian datasets)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Test 1: Shared sigma, independent A and mu (3 Gaussian datasets) ---\n');

x          = linspace(-5, 5, 120)';
sigma_true = 1.2;
A_vals     = [3.0, 5.0, 2.0];
mu_vals    = [-1.0, 0.5, 2.0];

ds1 = struct('x', x, 'y', A_vals(1)*exp(-(x-mu_vals(1)).^2/(2*sigma_true^2)) + 0.06*randn(size(x)));
ds2 = struct('x', x, 'y', A_vals(2)*exp(-(x-mu_vals(2)).^2/(2*sigma_true^2)) + 0.06*randn(size(x)));
ds3 = struct('x', x, 'y', A_vals(3)*exp(-(x-mu_vals(3)).^2/(2*sigma_true^2)) + 0.06*randn(size(x)));
gaussDatasets = {ds1, ds2, ds3};

c1(1).paramName = 'sigma';  c1(1).datasets = [1 2 3];
r1 = fitting.globalCurveFit(gaussDatasets, gaussModel, c1);

% 1a: converged
if r1.exitFlag == 1
    fprintf('  PASS: fit converged (exitFlag=1)\n'); passed = passed + 1;
else
    fprintf('  FAIL: exitFlag=%d\n', r1.exitFlag); failed = failed + 1;
end

% 1b: shared sigma recovered within 10%
if numel(r1.shared) == 1 && abs(r1.shared(1).value - sigma_true) / sigma_true < 0.1
    fprintf('  PASS: shared sigma=%.4f (expected %.4f)\n', r1.shared(1).value, sigma_true);
    passed = passed + 1;
else
    sigVal = 0;
    if numel(r1.shared) >= 1, sigVal = r1.shared(1).value; end
    fprintf('  FAIL: shared sigma=%.4f (expected %.4f)\n', sigVal, sigma_true);
    failed = failed + 1;
end

% 1c: sigma identical in all per-dataset param vectors
sigmaVals = cellfun(@(p) p(3), r1.params);
if max(sigmaVals) - min(sigmaVals) < 1e-8
    fprintf('  PASS: sigma identical across all per-dataset param vectors\n');
    passed = passed + 1;
else
    fprintf('  FAIL: sigma spread = %.2e across datasets\n', max(sigmaVals)-min(sigmaVals));
    failed = failed + 1;
end

% 1d: per-dataset A values close to true (within 15%)
A_fit = cellfun(@(p) p(1), r1.params);
A_err = abs(A_fit - A_vals) ./ A_vals;
if all(A_err < 0.15)
    fprintf('  PASS: per-dataset A within 15%% (max err=%.1f%%)\n', max(A_err)*100);
    passed = passed + 1;
else
    fprintf('  FAIL: A relative errors: [%s]%%\n', num2str(A_err*100, '%.1f '));
    failed = failed + 1;
end

% 1e: per-dataset R² > 0.95
if all(r1.R2 > 0.95)
    fprintf('  PASS: all R² > 0.95 (min=%.4f)\n', min(r1.R2));
    passed = passed + 1;
else
    fprintf('  FAIL: min R² = %.4f\n', min(r1.R2));
    failed = failed + 1;
end

% 1f: shared param error finite and positive
if numel(r1.shared) >= 1 && isfinite(r1.shared(1).error) && r1.shared(1).error > 0
    fprintf('  PASS: shared sigma error finite+positive (%.4g)\n', r1.shared(1).error);
    passed = passed + 1;
else
    fprintf('  FAIL: shared sigma error invalid\n');
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% Test 2: All parameters shared — 2 nearly identical datasets
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Test 2: All parameters shared (2 datasets) ---\n');

xLin = linspace(0, 10, 80)';
yA2 = 4.0*exp(-(xLin-2.0).^2/(2*1.5^2)) + 0.05*randn(size(xLin));
yB2 = 4.0*exp(-(xLin-2.0).^2/(2*1.5^2)) + 0.05*randn(size(xLin));
dsA2 = struct('x', xLin, 'y', yA2);
dsB2 = struct('x', xLin, 'y', yB2);

cAll(1).paramName = 'A';     cAll(1).datasets = [1 2];
cAll(2).paramName = 'mu';    cAll(2).datasets = [1 2];
cAll(3).paramName = 'sigma'; cAll(3).datasets = [1 2];

rAll = fitting.globalCurveFit({dsA2, dsB2}, gaussModel, cAll);

if rAll.nFree == 3
    fprintf('  PASS: all-shared nFree=3\n'); passed = passed + 1;
else
    fprintf('  FAIL: nFree=%d (expected 3)\n', rAll.nFree); failed = failed + 1;
end

p1All = rAll.params{1};
p2All = rAll.params{2};
if max(abs(p1All - p2All)) < 1e-10
    fprintf('  PASS: all-shared params identical across datasets\n');
    passed = passed + 1;
else
    fprintf('  FAIL: param diff max=%.2e\n', max(abs(p1All-p2All)));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% Test 3: No constraints — independent fits
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Test 3: No constraints (independent fits) ---\n');

rNone = fitting.globalCurveFit(gaussDatasets, gaussModel, []);
K3 = numel(gaussDatasets);
P3 = gaussModel.nParams;

if rNone.nFree == K3 * P3
    fprintf('  PASS: no-constraint nFree=%d (=%d×%d)\n', rNone.nFree, K3, P3);
    passed = passed + 1;
else
    fprintf('  FAIL: nFree=%d (expected %d)\n', rNone.nFree, K3*P3);
    failed = failed + 1;
end

if isempty(rNone.shared)
    fprintf('  PASS: no shared params in output struct\n'); passed = passed + 1;
else
    fprintf('  FAIL: shared has %d entries (expected 0)\n', numel(rNone.shared));
    failed = failed + 1;
end

if all(rNone.R2 > 0.90)
    fprintf('  PASS: independent R² all > 0.90 (min=%.4f)\n', min(rNone.R2));
    passed = passed + 1;
else
    fprintf('  FAIL: min R² = %.4f\n', min(rNone.R2));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% Test 4: Linear model, shared intercept (b) across 2 datasets
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Test 4: Linear model, shared intercept b ---\n');

xLin4 = linspace(0, 10, 60)';
slope1_true = 2.0;  slope2_true = -1.5;
intercept_true = 3.0;

yLin1 = slope1_true*xLin4 + intercept_true + 0.1*randn(size(xLin4));
yLin2 = slope2_true*xLin4 + intercept_true + 0.1*randn(size(xLin4));
dsLin1 = struct('x', xLin4, 'y', yLin1);
dsLin2 = struct('x', xLin4, 'y', yLin2);

cLin(1).paramName = 'b';  cLin(1).datasets = [1 2];
rLin = fitting.globalCurveFit({dsLin1, dsLin2}, linearModel, cLin);

if abs(rLin.shared(1).value - intercept_true) < 0.3
    fprintf('  PASS: shared b=%.4f (expected %.4f)\n', rLin.shared(1).value, intercept_true);
    passed = passed + 1;
else
    fprintf('  FAIL: shared b=%.4f (expected %.4f)\n', rLin.shared(1).value, intercept_true);
    failed = failed + 1;
end

b1Lin = rLin.params{1}(2);
b2Lin = rLin.params{2}(2);
if abs(b1Lin - b2Lin) < 1e-10
    fprintf('  PASS: b identical in both per-dataset param vectors\n');
    passed = passed + 1;
else
    fprintf('  FAIL: b values differ: %.6g vs %.6g\n', b1Lin, b2Lin);
    failed = failed + 1;
end

m1Lin = rLin.params{1}(1);
m2Lin = rLin.params{2}(1);
if abs(m1Lin - slope1_true) < 0.3 && abs(m2Lin - slope2_true) < 0.3
    fprintf('  PASS: slopes m1=%.3f (exp %.1f), m2=%.3f (exp %.1f)\n', ...
        m1Lin, slope1_true, m2Lin, slope2_true);
    passed = passed + 1;
else
    fprintf('  FAIL: slopes m1=%.3f (exp %.1f), m2=%.3f (exp %.1f)\n', ...
        m1Lin, slope1_true, m2Lin, slope2_true);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% Test 5: Datasets with different numbers of points
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Test 5: Different N per dataset ---\n');

xShort = linspace(-3, 3, 40)';
xLong  = linspace(-3, 3, 200)';
yShort = 2.0*exp(-xShort.^2/(2*sigma_true^2)) + 0.05*randn(size(xShort));
yLong  = 4.0*exp(-xLong .^2/(2*sigma_true^2)) + 0.05*randn(size(xLong));
dsShort = struct('x', xShort, 'y', yShort);
dsLong  = struct('x', xLong,  'y', yLong);

cVarN(1).paramName = 'sigma'; cVarN(1).datasets = [1 2];
rVarN = fitting.globalCurveFit({dsShort, dsLong}, gaussModel, cVarN);

if rVarN.exitFlag == 1 && abs(rVarN.shared(1).value - sigma_true) / sigma_true < 0.15
    fprintf('  PASS: different-N fit converged, sigma=%.4f (exp %.4f)\n', ...
        rVarN.shared(1).value, sigma_true);
    passed = passed + 1;
else
    fprintf('  FAIL: sigma=%.4f (exp %.4f), exitFlag=%d\n', ...
        rVarN.shared(1).value, sigma_true, rVarN.exitFlag);
    failed = failed + 1;
end

expTotal = numel(xShort) + numel(xLong);
if rVarN.nTotal == expTotal
    fprintf('  PASS: nTotal=%d (%d+%d)\n', rVarN.nTotal, numel(xShort), numel(xLong));
    passed = passed + 1;
else
    fprintf('  FAIL: nTotal=%d (expected %d)\n', rVarN.nTotal, expTotal);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% Test 6: Single dataset (constraint with single member is silently dropped)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Test 6: Single dataset with constraint (degenerate case) ---\n');

dsSingle = struct('x', x, 'y', 3.5*exp(-(x-0.8).^2/(2*1.0^2)) + 0.04*randn(size(x)));
cSingle(1).paramName = 'sigma'; cSingle(1).datasets = [1];
rSingle = fitting.globalCurveFit({dsSingle}, gaussModel, cSingle);

if rSingle.nFree == 3
    fprintf('  PASS: single-dataset nFree=3 (single-member constraint dropped)\n');
    passed = passed + 1;
else
    fprintf('  FAIL: single-dataset nFree=%d (expected 3)\n', rSingle.nFree);
    failed = failed + 1;
end

if rSingle.R2(1) > 0.95
    fprintf('  PASS: single-dataset R²=%.4f > 0.95\n', rSingle.R2(1));
    passed = passed + 1;
else
    fprintf('  FAIL: single-dataset R²=%.4f\n', rSingle.R2(1));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% Test 7: Output struct fields complete
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Test 7: Output struct completeness ---\n');

requiredFields = {'params','errors','shared','residuals','yFit', ...
    'R2','RMSE','chiSqRed','covar','nTotal','nFree','exitFlag'};
missingFields = {};
for fi = 1:numel(requiredFields)
    if ~isfield(r1, requiredFields{fi})
        missingFields{end+1} = requiredFields{fi}; %#ok<AGROW>
    end
end

if isempty(missingFields)
    fprintf('  PASS: all required output fields present\n'); passed = passed + 1;
else
    fprintf('  FAIL: missing fields: %s\n', strjoin(missingFields, ', ')); failed = failed + 1;
end

if numel(r1.residuals{1}) == numel(ds1.y)
    fprintf('  PASS: residuals{1} length matches dataset 1\n'); passed = passed + 1;
else
    fprintf('  FAIL: residuals{1} length=%d (expected %d)\n', ...
        numel(r1.residuals{1}), numel(ds1.y));
    failed = failed + 1;
end

if numel(r1.yFit{2}) == numel(ds2.y)
    fprintf('  PASS: yFit{2} length matches dataset 2\n'); passed = passed + 1;
else
    fprintf('  FAIL: yFit{2} length=%d (expected %d)\n', numel(r1.yFit{2}), numel(ds2.y));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% Test 8: Cell-pair {x,y} dataset input format
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Test 8: Cell-pair {x,y} dataset input format ---\n');

cellDS1 = {x, ds1.y};
cellDS2 = {x, ds2.y};
cCell(1).paramName = 'sigma'; cCell(1).datasets = [1 2];
rCell = fitting.globalCurveFit({cellDS1, cellDS2}, gaussModel, cCell);

if rCell.exitFlag == 1 && numel(rCell.shared) == 1
    fprintf('  PASS: cell-pair {x,y} input format works\n'); passed = passed + 1;
else
    fprintf('  FAIL: cell-pair failed (exitFlag=%d, nShared=%d)\n', ...
        rCell.exitFlag, numel(rCell.shared));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% SUMMARY
% ════════════════════════════════════════════════════════════════════════
fprintf('\n=== test_globalCurveFit: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_globalCurveFit:failures', '%d test(s) failed.', failed);
end
