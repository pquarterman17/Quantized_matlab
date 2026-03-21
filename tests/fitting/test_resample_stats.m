%TEST_RESAMPLE_STATS  Tests for resampling (+utilities/resampleData) and
%   statistics (+utilities/descriptiveStats, tTest, linRegress).
%
%   Run:
%     run tests/fitting/test_resample_stats
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_resample_stats ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  RESAMPLE DATA
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.resampleData ---\n');

% Create a test data struct (sine wave)
d.time = linspace(0, 2*pi, 100)';
d.values = [sin(d.time), cos(d.time)];
d.labels = {'sin', 'cos'};
d.units  = {'', ''};
d.metadata = struct();

% NPoints mode
d2 = utilities.resampleData(d, NPoints=50);
if numel(d2.time) == 50
    fprintf('  PASS: NPoints=50 gives 50 points\n'); passed = passed + 1;
else
    fprintf('  FAIL: NPoints=50 gives %d points\n', numel(d2.time)); failed = failed + 1;
end

% Values are correct (sine at resampled points)
yExpected = sin(d2.time);
maxErr = max(abs(d2.values(:,1) - yExpected));
if maxErr < 0.01
    fprintf('  PASS: resampled sine accurate (maxErr=%.4g)\n', maxErr); passed = passed + 1;
else
    fprintf('  FAIL: resampled sine error too large (%.4g)\n', maxErr); failed = failed + 1;
end

% Step mode
d3 = utilities.resampleData(d, Step=0.1);
actualStep = mean(diff(d3.time));
if abs(actualStep - 0.1) < 1e-10
    fprintf('  PASS: Step=0.1 produces uniform step\n'); passed = passed + 1;
else
    fprintf('  FAIL: step = %.6f (exp 0.1)\n', actualStep); failed = failed + 1;
end

% Grid mode
xCustom = [0; 1; 2; 3; 4; 5; 6]';
d4 = utilities.resampleData(d, Grid=xCustom(:));
if numel(d4.time) == 7 && d4.time(1) == 0 && d4.time(end) == 6
    fprintf('  PASS: custom grid mode works\n'); passed = passed + 1;
else
    fprintf('  FAIL: custom grid mode\n'); failed = failed + 1;
end

% MatchDataset mode
ref.time = linspace(0.5, 5.5, 30)';
d5 = utilities.resampleData(d, MatchDataset=ref);
if numel(d5.time) == 30 && abs(d5.time(1) - 0.5) < 1e-10
    fprintf('  PASS: MatchDataset mode works\n'); passed = passed + 1;
else
    fprintf('  FAIL: MatchDataset mode\n'); failed = failed + 1;
end

% Labels and metadata preserved
if isequal(d2.labels, d.labels)
    fprintf('  PASS: labels preserved\n'); passed = passed + 1;
else
    fprintf('  FAIL: labels not preserved\n'); failed = failed + 1;
end

% Multiple modes error
try
    utilities.resampleData(d, NPoints=50, Step=0.1);
    fprintf('  FAIL: multiple modes should error\n'); failed = failed + 1;
catch
    fprintf('  PASS: multiple modes throws error\n'); passed = passed + 1;
end

% All interpolation methods work
methodsOk = true;
for m = ["linear", "pchip", "spline", "makima"]
    try
        dm = utilities.resampleData(d, NPoints=50, Method=m);
        if numel(dm.time) ~= 50, methodsOk = false; end
    catch
        methodsOk = false;
    end
end
if methodsOk
    fprintf('  PASS: all interpolation methods work\n'); passed = passed + 1;
else
    fprintf('  FAIL: some methods failed\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  DESCRIPTIVE STATS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.descriptiveStats ---\n');

% Known distribution: uniform [0, 1] with 10000 points
rng(42);
xUnif = rand(10000, 1);
s = utilities.descriptiveStats(xUnif);

if abs(s.mean - 0.5) < 0.02
    fprintf('  PASS: uniform mean ≈ 0.5 (%.4f)\n', s.mean); passed = passed + 1;
else
    fprintf('  FAIL: uniform mean = %.4f\n', s.mean); failed = failed + 1;
end

if abs(s.std - sqrt(1/12)) < 0.02
    fprintf('  PASS: uniform std ≈ %.4f (%.4f)\n', sqrt(1/12), s.std); passed = passed + 1;
else
    fprintf('  FAIL: uniform std = %.4f\n', s.std); failed = failed + 1;
end

if abs(s.skewness) < 0.1
    fprintf('  PASS: uniform skewness ≈ 0 (%.4f)\n', s.skewness); passed = passed + 1;
else
    fprintf('  FAIL: uniform skewness = %.4f\n', s.skewness); failed = failed + 1;
end

if s.N == 10000 && abs(s.min) < 0.01 && abs(s.max - 1) < 0.01
    fprintf('  PASS: N, min, max correct\n'); passed = passed + 1;
else
    fprintf('  FAIL: N=%d, min=%.4f, max=%.4f\n', s.N, s.min, s.max); failed = failed + 1;
end

% SEM
expectedSEM = s.std / sqrt(s.N);
if abs(s.sem - expectedSEM) < 1e-10
    fprintf('  PASS: SEM computed correctly\n'); passed = passed + 1;
else
    fprintf('  FAIL: SEM mismatch\n'); failed = failed + 1;
end

% IQR for uniform: should be ≈ 0.5
if abs(s.iqr - 0.5) < 0.05
    fprintf('  PASS: IQR ≈ 0.5 (%.4f)\n', s.iqr); passed = passed + 1;
else
    fprintf('  FAIL: IQR = %.4f\n', s.iqr); failed = failed + 1;
end

% NaN handling
xNaN = [1; 2; NaN; 4; 5; NaN];
sn = utilities.descriptiveStats(xNaN);
if sn.N == 4 && abs(sn.mean - 3) < 1e-10
    fprintf('  PASS: NaN values excluded correctly\n'); passed = passed + 1;
else
    fprintf('  FAIL: NaN handling: N=%d, mean=%.4f\n', sn.N, sn.mean); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  T-TEST
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.tTest ---\n');

% One-sample: N(5, 1) data — should strongly reject H₀: μ=0
rng(42);
xNorm = 5 + randn(100, 1);
r = utilities.tTest(xNorm);
if r.reject && r.pValue < 0.001
    fprintf('  PASS: one-sample rejects μ=0 for N(5,1) data (p=%.2e)\n', r.pValue);
    passed = passed + 1;
else
    fprintf('  FAIL: one-sample p=%.4f (exp <<0.05)\n', r.pValue); failed = failed + 1;
end

% One-sample: N(0, 1) — should NOT reject H₀: μ=0 most of the time
xNull = randn(100, 1);
r2 = utilities.tTest(xNull);
if abs(r2.tStat) < 5  % should be near 0
    fprintf('  PASS: one-sample t-stat reasonable for null data (t=%.2f)\n', r2.tStat);
    passed = passed + 1;
else
    fprintf('  FAIL: one-sample t-stat = %.2f\n', r2.tStat); failed = failed + 1;
end

% Two-sample: clearly different groups
groupA = 10 + randn(50, 1);
groupB = 15 + randn(50, 1);
r3 = utilities.tTest(groupA, groupB);
if r3.reject && r3.pValue < 0.001
    fprintf('  PASS: two-sample rejects (p=%.2e)\n', r3.pValue); passed = passed + 1;
else
    fprintf('  FAIL: two-sample p=%.4f\n', r3.pValue); failed = failed + 1;
end

if strcmp(r3.testType, 'two-sample')
    fprintf('  PASS: testType = two-sample\n'); passed = passed + 1;
else
    fprintf('  FAIL: testType = %s\n', r3.testType); failed = failed + 1;
end

% Paired test: same data → should NOT reject
r4 = utilities.tTest(groupA, groupA, Paired=true);
if ~r4.reject && r4.pValue > 0.9
    fprintf('  PASS: paired test on identical data does not reject (p=%.2f)\n', r4.pValue);
    passed = passed + 1;
else
    fprintf('  FAIL: paired test on identical data: p=%.4f\n', r4.pValue); failed = failed + 1;
end

% Confidence interval contains true mean difference
r5 = utilities.tTest(groupA, groupB);
trueDiff = 10 - 15;  % = -5
if r5.ci(1) < trueDiff && trueDiff < r5.ci(2)
    fprintf('  PASS: CI [%.2f, %.2f] contains true diff (%.1f)\n', r5.ci, trueDiff);
    passed = passed + 1;
else
    fprintf('  FAIL: CI [%.2f, %.2f] does not contain %.1f\n', r5.ci, trueDiff);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  LINEAR REGRESSION
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.linRegress ---\n');

% Perfect linear data: y = 3x + 7
rng(42);
xLin = (1:50)';
yLin = 3*xLin + 7;
r6 = utilities.linRegress(xLin, yLin);
if abs(r6.coeffs(1) - 7) < 1e-6 && abs(r6.coeffs(2) - 3) < 1e-6
    fprintf('  PASS: recovers y = 3x + 7 exactly\n'); passed = passed + 1;
else
    fprintf('  FAIL: coeffs = [%.4f, %.4f]\n', r6.coeffs); failed = failed + 1;
end

if r6.R2 > 0.99999
    fprintf('  PASS: R² = %.8f for perfect data\n', r6.R2); passed = passed + 1;
else
    fprintf('  FAIL: R² = %.8f\n', r6.R2); failed = failed + 1;
end

% Noisy linear data
yNoisy = 3*xLin + 7 + 2*randn(50, 1);
r7 = utilities.linRegress(xLin, yNoisy);
if abs(r7.coeffs(2) - 3) < 1 && r7.R2 > 0.9
    fprintf('  PASS: noisy regression: slope=%.2f (exp 3), R²=%.4f\n', ...
        r7.coeffs(2), r7.R2);
    passed = passed + 1;
else
    fprintf('  FAIL: noisy regression: slope=%.2f, R²=%.4f\n', r7.coeffs(2), r7.R2);
    failed = failed + 1;
end

% Standard errors are positive and finite
if all(isfinite(r7.se)) && all(r7.se > 0)
    fprintf('  PASS: standard errors are finite and positive\n'); passed = passed + 1;
else
    fprintf('  FAIL: SE issues: [%s]\n', num2str(r7.se, '%.4g ')); failed = failed + 1;
end

% p-value for slope should be significant
if r7.pValues(2) < 0.001
    fprintf('  PASS: slope p-value < 0.001 (p=%.2e)\n', r7.pValues(2)); passed = passed + 1;
else
    fprintf('  FAIL: slope p-value = %.4f\n', r7.pValues(2)); failed = failed + 1;
end

% F-statistic is significant
if r7.fPvalue < 0.001
    fprintf('  PASS: F-test p-value < 0.001 (p=%.2e)\n', r7.fPvalue); passed = passed + 1;
else
    fprintf('  FAIL: F-test p = %.4f\n', r7.fPvalue); failed = failed + 1;
end

% Confidence band: should contain the true line at most x points
[lo, hi] = r7.confBand(xLin);
yTrue = 3*xLin + 7;
fracInside = mean(yTrue >= lo & yTrue <= hi);
if fracInside > 0.8
    fprintf('  PASS: confidence band contains true line %.0f%% of x range\n', fracInside*100);
    passed = passed + 1;
else
    fprintf('  FAIL: conf band contains true line only %.0f%%\n', fracInside*100);
    failed = failed + 1;
end

% Prediction band wider than confidence band
[plo, phi] = r7.predBand(xLin);
if all(plo <= lo) && all(phi >= hi)
    fprintf('  PASS: prediction band is wider than confidence band\n'); passed = passed + 1;
else
    fprintf('  FAIL: prediction band not wider than confidence band\n'); failed = failed + 1;
end

% Quadratic regression
xQ = (-5:0.2:5)';
yQ = 2*xQ.^2 - 3*xQ + 1 + 0.5*randn(size(xQ));
r8 = utilities.linRegress(xQ, yQ, Order=2);
if abs(r8.coeffs(3) - 2) < 0.5 && r8.R2 > 0.99
    fprintf('  PASS: quadratic regression (a=%.2f, R²=%.4f)\n', r8.coeffs(3), r8.R2);
    passed = passed + 1;
else
    fprintf('  FAIL: quadratic: a=%.2f (exp 2), R²=%.4f\n', r8.coeffs(3), r8.R2);
    failed = failed + 1;
end

% Residuals have correct length
if numel(r7.residuals) == 50 && numel(r7.yFit) == 50
    fprintf('  PASS: residuals and yFit have correct length\n'); passed = passed + 1;
else
    fprintf('  FAIL: output lengths wrong\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_resample_stats: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_resample_stats:failures', '%d test(s) failed.', failed);
end
