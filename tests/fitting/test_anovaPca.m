%TEST_ANOVAPCA  Tests for utilities.anova1 and utilities.pcaAnalysis.
%
%   Run:
%     run tests/fitting/test_anovaPca
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_anovaPca ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  ANOVA1 — One-way analysis of variance
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.anova1 ---\n');

% Test 1: Classic Fisher/Iris-style textbook example (known F, p)
%   Three groups with known SS. Reference values computed by hand:
%     g1 = [6 8 4 5 3 4],   mean = 5.0, n=6
%     g2 = [8 12 9 11 6 8], mean = 9.0, n=6
%     g3 = [13 9 11 8 7 12], mean=10.0, n=6
%   Grand mean = 8.0
%   SS_between = 6*(5-8)^2 + 6*(9-8)^2 + 6*(10-8)^2 = 54 + 6 + 24 = 84
%   SS_within  = 16 + 22 + 26 = 64   (computed below from data)
%   df1=2, df2=15, F = (84/2)/(64/15) = 42/4.2667 ≈ 9.844
g1 = [6 8 4 5 3 4]';
g2 = [8 12 9 11 6 8]';
g3 = [13 9 11 8 7 12]';
r = utilities.anova1({g1, g2, g3});
if abs(r.ssBetween - 84) < 1e-9
    fprintf('  PASS: ssBetween = 84\n'); passed = passed + 1;
else
    fprintf('  FAIL: ssBetween = %.4f (expected 84)\n', r.ssBetween); failed = failed + 1;
end
if r.df1 == 2 && r.df2 == 15
    fprintf('  PASS: df1=2, df2=15\n'); passed = passed + 1;
else
    fprintf('  FAIL: df1=%d df2=%d\n', r.df1, r.df2); failed = failed + 1;
end
if abs(r.fStat - 9.2647) < 0.01
    fprintf('  PASS: F ≈ 9.2647 (got %.4f)\n', r.fStat); passed = passed + 1;
else
    fprintf('  FAIL: F = %.4f (expected ~9.2647)\n', r.fStat); failed = failed + 1;
end
if r.pValue < 0.01 && r.reject
    fprintf('  PASS: p < 0.01, reject H0 (p=%.4g)\n', r.pValue); passed = passed + 1;
else
    fprintf('  FAIL: p=%.4g reject=%d\n', r.pValue, r.reject); failed = failed + 1;
end

% Test 2: Null case — groups drawn from the same distribution
rng(42);
n1 = randn(30,1);
n2 = randn(30,1);
n3 = randn(30,1);
r = utilities.anova1({n1, n2, n3});
if r.pValue > 0.05 && ~r.reject
    fprintf('  PASS: null case not rejected (p=%.3f)\n', r.pValue); passed = passed + 1;
else
    fprintf('  FAIL: null case rejected (p=%.3f)\n', r.pValue); failed = failed + 1;
end

% Test 3: Strong effect — should be rejected with huge F
rng(7);
a = randn(40,1);
b = randn(40,1) + 3;
c = randn(40,1) + 6;
r = utilities.anova1({a, b, c});
if r.pValue < 1e-20 && r.fStat > 100
    fprintf('  PASS: strong effect detected (F=%.1f)\n', r.fStat); passed = passed + 1;
else
    fprintf('  FAIL: strong effect F=%.2f p=%.3g\n', r.fStat, r.pValue); failed = failed + 1;
end

% Test 4: Flat-vector + Group labels calling form
values = [g1; g2; g3];
labels = [ones(6,1); 2*ones(6,1); 3*ones(6,1)];
r2 = utilities.anova1(values, Group=labels);
if abs(r2.fStat - 9.2647) < 0.01
    fprintf('  PASS: flat-vector form matches cell-array form\n'); passed = passed + 1;
else
    fprintf('  FAIL: flat-vector F=%.4f\n', r2.fStat); failed = failed + 1;
end

% Test 5: Degenerate — all values identical
r = utilities.anova1({[1;1;1], [1;1;1], [1;1;1]});
if r.fStat == 0 && r.pValue == 1
    fprintf('  PASS: identical data → F=0, p=1\n'); passed = passed + 1;
else
    fprintf('  FAIL: identical data F=%.3f p=%.3f\n', r.fStat, r.pValue); failed = failed + 1;
end

% Test 6: Unequal group sizes
rng(1);
r = utilities.anova1({randn(10,1), randn(25,1)+2, randn(5,1)+4});
if r.df1 == 2 && r.df2 == (10+25+5 - 3) && r.pValue < 0.01
    fprintf('  PASS: unequal sizes (df2=%d, p=%.3g)\n', r.df2, r.pValue); passed = passed + 1;
else
    fprintf('  FAIL: unequal sizes df1=%d df2=%d p=%.3g\n', r.df1, r.df2, r.pValue); failed = failed + 1;
end

% Test 7: NaN handling — NaNs should be dropped
g = {[1;2;3;NaN], [5;6;7;NaN;NaN]};
r = utilities.anova1(g);
if all(r.groupN == [3;3])
    fprintf('  PASS: NaNs dropped (n=[3,3])\n'); passed = passed + 1;
else
    fprintf('  FAIL: NaN handling groupN=[%d,%d]\n', r.groupN(1), r.groupN(2)); failed = failed + 1;
end

% Test 8: Error on single group
try
    utilities.anova1({[1;2;3]});
    fprintf('  FAIL: single-group did not error\n'); failed = failed + 1;
catch ME
    if contains(ME.identifier, 'tooFewGroups')
        fprintf('  PASS: single-group errors correctly\n'); passed = passed + 1;
    else
        fprintf('  FAIL: wrong error %s\n', ME.identifier); failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════
%  PCA ANALYSIS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.pcaAnalysis ---\n');

% Test 9: Perfectly correlated data — PC1 should capture ~100%
rng(0);
t = linspace(0, 10, 200)';
X = [t, 2*t + 0.001*randn(200,1), -t + 0.001*randn(200,1)];
r = utilities.pcaAnalysis(X);
if r.explained(1) > 99.9
    fprintf('  PASS: collinear data → PC1 explains %.3f%%\n', r.explained(1)); passed = passed + 1;
else
    fprintf('  FAIL: PC1 explains %.3f%% (expected >99.9)\n', r.explained(1)); failed = failed + 1;
end

% Test 10: Explained percentages sum to 100
if abs(sum(r.explained) - 100) < 1e-9
    fprintf('  PASS: explained sums to 100\n'); passed = passed + 1;
else
    fprintf('  FAIL: explained sums to %.6f\n', sum(r.explained)); failed = failed + 1;
end

% Test 11: Latent = variance of scores (within numerical tolerance)
varScore = var(r.score, 0, 1)';
if max(abs(varScore - r.latent)) < 1e-9
    fprintf('  PASS: latent matches var(score)\n'); passed = passed + 1;
else
    fprintf('  FAIL: max diff = %.3e\n', max(abs(varScore - r.latent))); failed = failed + 1;
end

% Test 12: Loadings are orthonormal (V'V = I)
M = r.coeff' * r.coeff;
if max(max(abs(M - eye(size(M))))) < 1e-10
    fprintf('  PASS: coeff columns orthonormal\n'); passed = passed + 1;
else
    fprintf('  FAIL: max off-I = %.3e\n', max(max(abs(M - eye(size(M)))))); failed = failed + 1;
end

% Test 13: Known 2D case — rotated ellipse, PC1 direction ≈ 45°
rng(3);
n = 500;
u = 4*randn(n,1);          % long axis
v = 0.3*randn(n,1);        % short axis
theta = pi/4;
R = [cos(theta) -sin(theta); sin(theta) cos(theta)];
X2 = [u v] * R';
r2 = utilities.pcaAnalysis(X2);
% PC1 should align with (cos 45, sin 45)
angle = atan2(r2.coeff(2,1), r2.coeff(1,1));
if abs(abs(angle) - pi/4) < 0.05
    fprintf('  PASS: PC1 recovers 45° axis (got %.3f rad)\n', angle); passed = passed + 1;
else
    fprintf('  FAIL: PC1 angle %.3f rad\n', angle); failed = failed + 1;
end
if r2.explained(1) > 95
    fprintf('  PASS: PC1 captures dominant variance (%.1f%%)\n', r2.explained(1)); passed = passed + 1;
else
    fprintf('  FAIL: PC1 %.1f%%\n', r2.explained(1)); failed = failed + 1;
end

% Test 14: NumComponents truncation
r3 = utilities.pcaAnalysis(X, NumComponents=2);
if size(r3.coeff, 2) == 2 && size(r3.score, 2) == 2 && numel(r3.latent) == 2
    fprintf('  PASS: NumComponents=2 truncates output\n'); passed = passed + 1;
else
    fprintf('  FAIL: truncation shapes %s\n', mat2str(size(r3.coeff))); failed = failed + 1;
end

% Test 15: Scale=true produces correlation-based PCA (unit variance per var)
rng(5);
X4 = [randn(100,1), 100*randn(100,1), 0.01*randn(100,1)];
rCov = utilities.pcaAnalysis(X4);                     % covariance PCA
rCor = utilities.pcaAnalysis(X4, Scale=true);         % correlation PCA
% In covariance PCA the huge-variance column dominates; in correlation PCA
% all three variables contribute more evenly.
if rCov.explained(1) > 99 && rCor.explained(1) < 60
    fprintf('  PASS: Scale=true flattens variance dominance\n'); passed = passed + 1;
else
    fprintf('  FAIL: cov %.1f%% vs cor %.1f%%\n', ...
        rCov.explained(1), rCor.explained(1)); failed = failed + 1;
end

% Test 16: Score reconstruction — X_centered ≈ score * coeff'
Xc = X - r.mu;
Xhat = r.score * r.coeff';
if max(max(abs(Xc - Xhat))) < 1e-10
    fprintf('  PASS: X_centered = score * coeff''\n'); passed = passed + 1;
else
    fprintf('  FAIL: reconstruction error %.3e\n', max(max(abs(Xc - Xhat)))); failed = failed + 1;
end

% Test 17: Sign determinism — rerunning gives identical loadings
rA = utilities.pcaAnalysis(X);
rB = utilities.pcaAnalysis(X);
if isequal(rA.coeff, rB.coeff)
    fprintf('  PASS: sign convention is deterministic\n'); passed = passed + 1;
else
    fprintf('  FAIL: non-deterministic signs\n'); failed = failed + 1;
end

% Test 18: Error on single-row input
try
    utilities.pcaAnalysis([1 2 3]);
    fprintf('  FAIL: single-row did not error\n'); failed = failed + 1;
catch ME
    if contains(ME.identifier, 'tooFewRows')
        fprintf('  PASS: single-row errors correctly\n'); passed = passed + 1;
    else
        fprintf('  FAIL: wrong error %s\n', ME.identifier); failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════
fprintf('\n=== test_anovaPca: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_anovaPca: %d test(s) failed', failed);
end
