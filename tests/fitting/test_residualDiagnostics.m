%TEST_RESIDUALDIAGNOSTICS  Tests for fitting.residualDiagnostics.
%
%   Run:
%     run tests/fitting/test_residualDiagnostics
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_residualDiagnostics ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  OUTPUT STRUCT — field presence and types
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- output struct fields ---\n');

rng(42);
rNorm = randn(100, 1);
d = fitting.residualDiagnostics(rNorm);

requiredFields = {'qqX','qqY','durbinWatson','runsTestZ','runsTestP', ...
    'nRuns','nPos','nNeg','skewness','kurtosis','summary'};
allPresent = true;
for fi = 1:numel(requiredFields)
    if ~isfield(d, requiredFields{fi})
        fprintf('  FAIL: missing field .%s\n', requiredFields{fi});
        allPresent = false;
    end
end
if allPresent
    fprintf('  PASS: all required fields present\n'); passed = passed + 1;
else
    failed = failed + 1;
end

% qqX and qqY same length as input
if numel(d.qqX) == 100 && numel(d.qqY) == 100
    fprintf('  PASS: qqX/qqY length = 100\n'); passed = passed + 1;
else
    fprintf('  FAIL: qqX=%d, qqY=%d (expected 100)\n', numel(d.qqX), numel(d.qqY));
    failed = failed + 1;
end

% qqY is sorted
if issorted(d.qqY)
    fprintf('  PASS: qqY is sorted\n'); passed = passed + 1;
else
    fprintf('  FAIL: qqY is not sorted\n'); failed = failed + 1;
end

% summary is non-empty char
if ischar(d.summary) && ~isempty(d.summary)
    fprintf('  PASS: summary is non-empty char\n'); passed = passed + 1;
else
    fprintf('  FAIL: summary is not a non-empty char\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  NORMAL RESIDUALS (rng(42), randn) — expected behaviour
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- normal residuals (rng=42, n=100) ---\n');

% DW near 2 (uncorrelated)
if d.durbinWatson > 1.5 && d.durbinWatson < 2.5
    fprintf('  PASS: DW = %.3f (in [1.5, 2.5])\n', d.durbinWatson); passed = passed + 1;
else
    fprintf('  FAIL: DW = %.3f (expected ~2)\n', d.durbinWatson); failed = failed + 1;
end

% Skewness near 0
if abs(d.skewness) < 0.5
    fprintf('  PASS: skewness = %.3f (~0)\n', d.skewness); passed = passed + 1;
else
    fprintf('  FAIL: skewness = %.3f (expected ~0)\n', d.skewness); failed = failed + 1;
end

% Excess kurtosis near 0
if abs(d.kurtosis) < 1.0
    fprintf('  PASS: excess kurtosis = %.3f (~0)\n', d.kurtosis); passed = passed + 1;
else
    fprintf('  FAIL: excess kurtosis = %.3f (expected ~0)\n', d.kurtosis); failed = failed + 1;
end

% Runs test p-value not tiny (random, so should not reject at 0.001)
if isnan(d.runsTestP) || d.runsTestP > 0.001
    fprintf('  PASS: runs test p = %.4f (not significant at 0.001)\n', ...
        d.runsTestP); passed = passed + 1;
else
    fprintf('  FAIL: runs test p = %.4f (unexpectedly significant)\n', d.runsTestP);
    failed = failed + 1;
end

% nPos + nNeg = 100
if d.nPos + d.nNeg == 100
    fprintf('  PASS: nPos(%d) + nNeg(%d) = 100\n', d.nPos, d.nNeg); passed = passed + 1;
else
    fprintf('  FAIL: nPos(%d) + nNeg(%d) != 100\n', d.nPos, d.nNeg); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  AUTOCORRELATED RESIDUALS (cumsum) — DW << 2
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- autocorrelated residuals (cumsum) ---\n');

rng(42);
rAuto = cumsum(randn(100, 1));
dAuto = fitting.residualDiagnostics(rAuto);

if dAuto.durbinWatson < 1.0
    fprintf('  PASS: DW = %.3f (positive autocorrelation detected, < 1.0)\n', ...
        dAuto.durbinWatson); passed = passed + 1;
else
    fprintf('  FAIL: DW = %.3f (expected < 1.0 for cumsum)\n', dAuto.durbinWatson);
    failed = failed + 1;
end

% Runs test should detect non-randomness
if ~isnan(dAuto.runsTestP) && dAuto.runsTestP < 0.05
    fprintf('  PASS: runs test p = %.4f (pattern detected)\n', dAuto.runsTestP);
    passed = passed + 1;
else
    fprintf('  FAIL: runs test p = %.4f (expected < 0.05 for cumsum)\n', ...
        dAuto.runsTestP); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  NON-NORMAL RESIDUALS (exponential) — skewness > 0, Q-Q curved
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- non-normal residuals (exponential) ---\n');

rng(42);
rExp = -log(rand(100, 1)) - 1;   % exponential(mean=1), shifted to zero mean
dExp = fitting.residualDiagnostics(rExp);

if dExp.skewness > 0.5
    fprintf('  PASS: skewness = %.3f (> 0.5 for exp distribution)\n', dExp.skewness);
    passed = passed + 1;
else
    fprintf('  FAIL: skewness = %.3f (expected > 0.5)\n', dExp.skewness); failed = failed + 1;
end

% Q-Q should deviate: qqY and qqX should not be equal
qqDev = max(abs(dExp.qqY - dExp.qqX));
if qqDev > 0.5
    fprintf('  PASS: Q-Q max deviation = %.3f (> 0.5, curved Q-Q)\n', qqDev);
    passed = passed + 1;
else
    fprintf('  FAIL: Q-Q max deviation = %.3f (expected > 0.5)\n', qqDev);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  ALL-POSITIVE RESIDUALS — few runs, NaN runs test Z
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- all-positive residuals ---\n');

rPos = abs(randn(50, 1)) + 0.1;   % guaranteed positive
dPos = fitting.residualDiagnostics(rPos);

if dPos.nNeg == 0
    fprintf('  PASS: nNeg = 0 (all positive)\n'); passed = passed + 1;
else
    fprintf('  FAIL: nNeg = %d (expected 0)\n', dPos.nNeg); failed = failed + 1;
end

if isnan(dPos.runsTestZ) && isnan(dPos.runsTestP)
    fprintf('  PASS: runsTestZ/P = NaN (only one sign)\n'); passed = passed + 1;
else
    fprintf('  FAIL: runsTestZ=%.3f, p=%.4f (expected NaN)\n', ...
        dPos.runsTestZ, dPos.runsTestP); failed = failed + 1;
end

% nRuns = 1 (only one run since all same sign)
if dPos.nRuns == 1
    fprintf('  PASS: nRuns = 1 (all same sign)\n'); passed = passed + 1;
else
    fprintf('  FAIL: nRuns = %d (expected 1)\n', dPos.nRuns); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  EDGE CASE: N = 3 — no crash, finite or NaN outputs
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- edge case: N=3 ---\n');

try
    d3 = fitting.residualDiagnostics([0.1; -0.2; 0.05]);
    if numel(d3.qqX) == 3 && numel(d3.qqY) == 3
        fprintf('  PASS: N=3 returns qqX/qqY of length 3\n'); passed = passed + 1;
    else
        fprintf('  FAIL: N=3 qqX=%d, qqY=%d (expected 3)\n', ...
            numel(d3.qqX), numel(d3.qqY)); failed = failed + 1;
    end
    if isfinite(d3.durbinWatson)
        fprintf('  PASS: N=3 DW = %.3f (finite)\n', d3.durbinWatson); passed = passed + 1;
    else
        fprintf('  FAIL: N=3 DW = NaN (expected finite)\n'); failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: N=3 crashed: %s\n', ME.message); failed = failed + 2;
end

% ════════════════════════════════════════════════════════════════════════
%  EDGE CASE: N = 1 — returns NaN struct, no crash
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- edge case: N=1 ---\n');

try
    d1 = fitting.residualDiagnostics(0.5);
    nanFields = {'durbinWatson','runsTestZ','runsTestP','skewness','kurtosis'};
    allNaN = true;
    for fi = 1:numel(nanFields)
        if ~isnan(d1.(nanFields{fi}))
            allNaN = false;
            fprintf('  FAIL: .%s = %.4g (expected NaN)\n', nanFields{fi}, d1.(nanFields{fi}));
        end
    end
    if allNaN
        fprintf('  PASS: N=1 returns NaN for all scalar stats\n'); passed = passed + 1;
    else
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: N=1 crashed: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  DW VALUE VALIDATION — known signal
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- DW formula validation ---\n');

% Construct residuals with known DW value
rKnown = [1; -1; 1; -1; 1; -1; 1; -1];   % alternating — DW should be ~4
dKnown = fitting.residualDiagnostics(rKnown);
dwExpected = sum(diff(rKnown).^2) / sum(rKnown.^2);
if abs(dKnown.durbinWatson - dwExpected) < 1e-10
    fprintf('  PASS: DW = %.4f matches manual formula\n', dKnown.durbinWatson);
    passed = passed + 1;
else
    fprintf('  FAIL: DW = %.4f, expected %.4f\n', dKnown.durbinWatson, dwExpected);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════════

fprintf('\n=== test_residualDiagnostics: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_residualDiagnostics:failures', '%d test(s) failed.', failed);
end
