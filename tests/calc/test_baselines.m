%TEST_BASELINES  Tests for baseline estimation algorithms.
%   run tests/calc/test_baselines
%   runAllTests(Group="baseline")
clear; clc;
fprintf('\n=== Baseline Estimation Tests ===\n\n');
ROOT = fileparts(fileparts(fileparts(mfilename('fullpath')))); addpath(ROOT);
passed = 0; failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  Helper: synthetic test signals
% ════════════════════════════════════════════════════════════════════════
N = 500;
x = linspace(0, 10, N)';

% Linear slope baseline with Gaussian peaks
trueBaseline = 2 + 0.5 * x;
peak1 = 5 * exp(-((x - 3).^2) / (2 * 0.1^2));
peak2 = 8 * exp(-((x - 7).^2) / (2 * 0.15^2));
signalSlope = trueBaseline + peak1 + peak2;

% Flat baseline with sharp peaks
flatBaseline = 10 * ones(N, 1);
peak3 = 12 * exp(-((x - 2).^2) / (2 * 0.2^2));
peak4 = 6  * exp(-((x - 5).^2) / (2 * 0.05^2));
peak5 = 9  * exp(-((x - 8).^2) / (2 * 0.1^2));
signalFlat = flatBaseline + peak3 + peak4 + peak5;

% Broad fluorescence background (quadratic) + sharp Raman peaks
fluorBg = 50 - 3*(x - 5).^2;
ramanPeaks = 4*exp(-((x-3).^2)/(2*0.08^2)) + ...
             6*exp(-((x-6).^2)/(2*0.06^2)) + ...
             3*exp(-((x-8.5).^2)/(2*0.1^2));
signalRaman = fluorBg + ramanPeaks;


% ════════════════════════════════════════════════════════════════════════
%  ALS: recover linear slope baseline
% ════════════════════════════════════════════════════════════════════════
try
    [bl, par] = utilities.baselineALS(signalSlope, 'Lambda', 1e7, 'P', 0.001);
    residual = bl - trueBaseline;
    rmsErr = sqrt(mean(residual.^2));
    % Baseline should be close to the true linear slope (peaks excluded)
    % Allow tolerance: ALS won't perfectly match, but RMS error < 1
    assert(rmsErr < 1.0, 'ALS RMS error %.3f too large', rmsErr);
    assert(numel(bl) == N, 'Output size mismatch');
    fprintf('  PASS: ALS on linear slope (RMS=%.3f)\n', rmsErr); passed = passed + 1;
catch ME, fprintf('  FAIL: ALS linear slope — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  ALS: convergence and params struct
% ════════════════════════════════════════════════════════════════════════
try
    [~, par] = utilities.baselineALS(signalSlope, 'Lambda', 1e6, 'P', 0.01, 'MaxIter', 50);
    assert(par.converged, 'Should converge for well-behaved signal');
    assert(par.nIter <= 50, 'nIter should be <= MaxIter');
    assert(par.lambda == 1e6, 'Lambda not stored correctly');
    assert(par.p == 0.01, 'P not stored correctly');
    fprintf('  PASS: ALS convergence (iter=%d)\n', par.nIter); passed = passed + 1;
catch ME, fprintf('  FAIL: ALS convergence — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  ALS: lambda effect — larger lambda → smoother baseline
% ════════════════════════════════════════════════════════════════════════
try
    bl_low  = utilities.baselineALS(signalSlope, 'Lambda', 1e4);
    bl_high = utilities.baselineALS(signalSlope, 'Lambda', 1e9);
    % Measure roughness as sum of squared second differences
    rough_low  = sum(diff(bl_low, 2).^2);
    rough_high = sum(diff(bl_high, 2).^2);
    assert(rough_high < rough_low, ...
        'Higher lambda should give smoother baseline (%.2e vs %.2e)', rough_high, rough_low);
    fprintf('  PASS: ALS lambda effect (rough: %.2e > %.2e)\n', rough_low, rough_high); passed = passed + 1;
catch ME, fprintf('  FAIL: ALS lambda effect — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  ALS: baseline stays below peaks
% ════════════════════════════════════════════════════════════════════════
try
    bl = utilities.baselineALS(signalSlope, 'Lambda', 1e6, 'P', 0.001);
    % In peak regions, baseline should be well below the data
    peakIdx1 = abs(x - 3) < 0.3;
    peakIdx2 = abs(x - 7) < 0.3;
    assert(all(bl(peakIdx1) < signalSlope(peakIdx1)), 'Baseline above data in peak1 region');
    assert(all(bl(peakIdx2) < signalSlope(peakIdx2)), 'Baseline above data in peak2 region');
    fprintf('  PASS: ALS baseline below peaks\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: ALS below peaks — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Rolling Ball: flat baseline recovery
% ════════════════════════════════════════════════════════════════════════
try
    [bl, par] = utilities.baselineRollingBall(signalFlat, 'Radius', 50);
    % In non-peak regions, baseline should be close to 10
    nonPeak = (peak3 + peak4 + peak5) < 0.1;
    blNonPeak = bl(nonPeak);
    rmsErr = sqrt(mean((blNonPeak - 10).^2));
    assert(rmsErr < 2.0, 'Rolling ball flat baseline RMS=%.3f too large', rmsErr);
    assert(par.radius == 50, 'Radius not stored');
    fprintf('  PASS: Rolling ball flat baseline (RMS=%.3f)\n', rmsErr); passed = passed + 1;
catch ME, fprintf('  FAIL: Rolling ball flat — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Rolling Ball: radius effect — smaller radius follows curvature
% ════════════════════════════════════════════════════════════════════════
try
    bl_small = utilities.baselineRollingBall(signalSlope, 'Radius', 20);
    bl_large = utilities.baselineRollingBall(signalSlope, 'Radius', 200);
    % Smaller radius follows local curvature → higher variance relative to linear trend
    dev_small = std(bl_small - trueBaseline);
    dev_large = std(bl_large - trueBaseline);
    % Smaller radius baseline should have MORE variation (follows local features)
    % or at least comparable — key is larger radius is smoother
    rough_small = sum(diff(bl_small, 2).^2);
    rough_large = sum(diff(bl_large, 2).^2);
    assert(rough_large <= rough_small * 1.01, ...
        'Larger radius should be at least as smooth');
    fprintf('  PASS: Rolling ball radius effect\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: Rolling ball radius — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Rolling Ball: baseline stays at or below data
% ════════════════════════════════════════════════════════════════════════
try
    bl = utilities.baselineRollingBall(signalFlat, 'Radius', 80);
    assert(all(bl <= signalFlat + eps), 'Rolling ball baseline exceeds data');
    fprintf('  PASS: Rolling ball below data\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: Rolling ball below data — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  ModPoly: fluorescence background recovery
% ════════════════════════════════════════════════════════════════════════
try
    [bl, par] = utilities.baselineModPoly(signalRaman, 'Order', 4, 'MaxIter', 200);
    % In non-peak regions, baseline should approximate the parabolic fluorescence
    nonPeak = ramanPeaks < 0.1;
    rmsErr = sqrt(mean((bl(nonPeak) - fluorBg(nonPeak)).^2));
    assert(rmsErr < 3.0, 'ModPoly fluorescence RMS=%.3f too large', rmsErr);
    assert(par.order == 4, 'Order not stored');
    fprintf('  PASS: ModPoly fluorescence (RMS=%.3f)\n', rmsErr); passed = passed + 1;
catch ME, fprintf('  FAIL: ModPoly fluorescence — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  ModPoly: convergence
% ════════════════════════════════════════════════════════════════════════
try
    [~, par] = utilities.baselineModPoly(signalRaman, 'Order', 4);
    assert(par.converged, 'ModPoly should converge');
    assert(par.nIter > 1, 'Should take more than 1 iteration');
    fprintf('  PASS: ModPoly convergence (iter=%d)\n', par.nIter); passed = passed + 1;
catch ME, fprintf('  FAIL: ModPoly convergence — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  ModPoly: baseline at or below data
% ════════════════════════════════════════════════════════════════════════
try
    bl = utilities.baselineModPoly(signalRaman, 'Order', 5);
    assert(all(bl <= signalRaman + eps), 'ModPoly baseline exceeds data');
    fprintf('  PASS: ModPoly below data\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: ModPoly below data — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Edge case: constant signal
% ════════════════════════════════════════════════════════════════════════
try
    yConst = 5 * ones(100, 1);
    bl1 = utilities.baselineALS(yConst);
    bl2 = utilities.baselineRollingBall(yConst, 'Radius', 20);
    bl3 = utilities.baselineModPoly(yConst);
    assert(max(abs(bl1 - 5)) < 0.01, 'ALS on constant signal');
    assert(max(abs(bl2 - 5)) < 0.01, 'RollingBall on constant signal');
    assert(max(abs(bl3 - 5)) < 0.01, 'ModPoly on constant signal');
    fprintf('  PASS: Constant signal (all methods)\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: Constant signal — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Edge case: very short signal (N < 3)
% ════════════════════════════════════════════════════════════════════════
try
    yShort = [3; 7];
    bl1 = utilities.baselineALS(yShort);
    bl2 = utilities.baselineRollingBall(yShort, 'Radius', 5);
    bl3 = utilities.baselineModPoly(yShort);
    assert(isequal(bl1, yShort), 'ALS short passthrough');
    assert(isequal(bl2, yShort), 'RollingBall short passthrough');
    assert(isequal(bl3, yShort), 'ModPoly short passthrough');
    fprintf('  PASS: Short signal passthrough (N=2)\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: Short signal — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Edge case: single point
% ════════════════════════════════════════════════════════════════════════
try
    ySingle = 42;
    bl1 = utilities.baselineALS(ySingle);
    bl2 = utilities.baselineRollingBall(ySingle, 'Radius', 10);
    bl3 = utilities.baselineModPoly(ySingle);
    assert(bl1 == 42, 'ALS single point');
    assert(bl2 == 42, 'RollingBall single point');
    assert(bl3 == 42, 'ModPoly single point');
    fprintf('  PASS: Single point (all methods)\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: Single point — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Edge case: all-zero signal
% ════════════════════════════════════════════════════════════════════════
try
    yZero = zeros(100, 1);
    bl1 = utilities.baselineALS(yZero);
    bl2 = utilities.baselineRollingBall(yZero, 'Radius', 20);
    bl3 = utilities.baselineModPoly(yZero);
    assert(max(abs(bl1)) < 1e-10, 'ALS on zeros');
    assert(max(abs(bl2)) < 1e-10, 'RollingBall on zeros');
    assert(max(abs(bl3)) < 1e-10, 'ModPoly on zeros');
    fprintf('  PASS: All-zero signal (all methods)\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: All-zero — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Comparison: all 3 methods on same signal produce reasonable baselines
% ════════════════════════════════════════════════════════════════════════
try
    bl_als  = utilities.baselineALS(signalSlope, 'Lambda', 1e7, 'P', 0.001);
    bl_rb   = utilities.baselineRollingBall(signalSlope, 'Radius', 80);
    bl_mp   = utilities.baselineModPoly(signalSlope, 'Order', 3);

    % All baselines should be below the peaks (at peak centres)
    peakCentre1 = find(abs(x - 3) == min(abs(x - 3)), 1);
    peakCentre2 = find(abs(x - 7) == min(abs(x - 7)), 1);

    for method = {'ALS', 'RB', 'MP'}
        switch method{1}
            case 'ALS', bl = bl_als;
            case 'RB',  bl = bl_rb;
            case 'MP',  bl = bl_mp;
        end
        assert(bl(peakCentre1) < signalSlope(peakCentre1), ...
            '%s baseline not below peak1', method{1});
        assert(bl(peakCentre2) < signalSlope(peakCentre2), ...
            '%s baseline not below peak2', method{1});
    end

    % All baselines should be in a sensible range (between min(y) and max(y))
    yMin = min(signalSlope);
    yMax = max(signalSlope);
    assert(all(bl_als >= yMin - 1 & bl_als <= yMax), 'ALS out of range');
    assert(all(bl_rb  >= yMin - 1 & bl_rb  <= yMax), 'RB out of range');
    assert(all(bl_mp  >= yMin - 1 & bl_mp  <= yMax), 'MP out of range');

    fprintf('  PASS: All 3 methods produce reasonable baselines\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: Comparison — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  ALS: output size matches input for various lengths
% ════════════════════════════════════════════════════════════════════════
try
    for testN = [3, 10, 50, 1000]
        yTest = randn(testN, 1) + 10;
        bl = utilities.baselineALS(yTest, 'Lambda', 1e5);
        assert(numel(bl) == testN, 'ALS output size %d != %d', numel(bl), testN);
    end
    fprintf('  PASS: ALS output sizes (N=3,10,50,1000)\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: ALS output sizes — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Rolling Ball: smoothing disabled
% ════════════════════════════════════════════════════════════════════════
try
    bl = utilities.baselineRollingBall(signalFlat, 'Radius', 50, 'Smooth', 0);
    assert(numel(bl) == N, 'Output size mismatch with Smooth=0');
    assert(all(bl <= signalFlat + eps), 'Baseline exceeds data with Smooth=0');
    fprintf('  PASS: Rolling ball Smooth=0\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: Rolling ball Smooth=0 — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Baseline Tests: %d passed, %d failed ---\n', passed, failed);
if failed > 0
    error('test_baselines:fail', '%d test(s) failed.', failed);
end
