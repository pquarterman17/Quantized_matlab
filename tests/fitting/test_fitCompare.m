%TEST_FITCOMPARE  Tests for fitting.fitCompare model comparison metrics.
%
%   Run:
%     run tests/fitting/test_fitCompare
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_fitCompare ===\n');
passed = 0;
failed = 0;

% Helper `near()` lives at end of file — pre-R2024a MATLAB requires
% script-local functions to come after all top-level executable code.

% ════════════════════════════════════════════════════════════════════════
%  OUTPUT STRUCT FIELDS
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- output struct fields ---\n');

rng(1);
yD  = (1:20)' + randn(20,1)*0.1;
res = yD - (1:20)';   % near-zero residuals

m = fitting.fitCompare(yD, res, 2);

reqFields = {'R2','adjR2','aic','aicc','bic','rmse','fStat','fPvalue','n','p','summary'};
allOk = true;
for fi = 1:numel(reqFields)
    if ~isfield(m, reqFields{fi})
        fprintf('  FAIL: missing field .%s\n', reqFields{fi}); allOk = false;
    end
end
if allOk
    fprintf('  PASS: all required fields present\n'); passed = passed + 1;
else
    failed = failed + 1;
end

% n and p stored correctly
if m.n == 20 && m.p == 2
    fprintf('  PASS: n=%d p=%d stored correctly\n', m.n, m.p); passed = passed + 1;
else
    fprintf('  FAIL: n=%d (exp 20) p=%d (exp 2)\n', m.n, m.p); failed = failed + 1;
end

% summary is non-empty char
if ischar(m.summary) && ~isempty(m.summary)
    fprintf('  PASS: summary is non-empty char\n'); passed = passed + 1;
else
    fprintf('  FAIL: summary is empty or not char\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  KNOWN LINEAR FIT: y = 2x + 1, exact
%  x = 1..10, y = 2x+1, fit = y exactly → RSS=0 except for noise
%  Use y with small noise to keep R2 < 1 for well-defined AIC
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- known linear fit (hand-calculated values) ---\n');

rng(0);
n  = 50;
x  = (1:n)';
yTrue = 2*x + 1;
noise = randn(n,1) * 0.5;
yObs  = yTrue + noise;
yHat  = yTrue;          % assume perfect model (residuals = noise)
res50 = yObs - yHat;

RSS50 = sum(res50.^2);
TSS50 = sum((yObs - mean(yObs)).^2);
R2_exp    = 1 - RSS50 / TSS50;
adjR2_exp = 1 - (1 - R2_exp) * (n-1) / (n-2-1);   % p=2
aic_exp   = n * log(RSS50/n) + 2*2;
bic_exp   = n * log(RSS50/n) + 2*log(n);

m50 = fitting.fitCompare(yObs, res50, 2);

if near(m50.R2, R2_exp, 1e-10)
    fprintf('  PASS: R2 = %.6f matches hand calc\n', m50.R2); passed = passed + 1;
else
    fprintf('  FAIL: R2 = %.6f, expected %.6f\n', m50.R2, R2_exp); failed = failed + 1;
end

if near(m50.adjR2, adjR2_exp, 1e-10)
    fprintf('  PASS: adjR2 = %.6f matches hand calc\n', m50.adjR2); passed = passed + 1;
else
    fprintf('  FAIL: adjR2 = %.6f, expected %.6f\n', m50.adjR2, adjR2_exp); failed = failed + 1;
end

if near(m50.aic, aic_exp, 1e-8)
    fprintf('  PASS: AIC = %.4f matches hand calc\n', m50.aic); passed = passed + 1;
else
    fprintf('  FAIL: AIC = %.4f, expected %.4f\n', m50.aic, aic_exp); failed = failed + 1;
end

if near(m50.bic, bic_exp, 1e-8)
    fprintf('  PASS: BIC = %.4f matches hand calc\n', m50.bic); passed = passed + 1;
else
    fprintf('  FAIL: BIC = %.4f, expected %.4f\n', m50.bic, bic_exp); failed = failed + 1;
end

rmse_exp = sqrt(RSS50 / n);
if near(m50.rmse, rmse_exp, 1e-10)
    fprintf('  PASS: RMSE = %.6f matches hand calc\n', m50.rmse); passed = passed + 1;
else
    fprintf('  FAIL: RMSE = %.6f, expected %.6f\n', m50.rmse, rmse_exp); failed = failed + 1;
end

% AICc should approach AIC for large n (n=50, p=2)
if abs(m50.aicc - m50.aic) < 1.0
    fprintf('  PASS: AICc (%.4f) close to AIC (%.4f) for n=50\n', ...
        m50.aicc, m50.aic); passed = passed + 1;
else
    fprintf('  FAIL: AICc (%.4f) far from AIC (%.4f)\n', m50.aicc, m50.aic);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  AICC APPROACHES AIC AS N → LARGE
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- AICc → AIC for large n ---\n');

rng(5);
for nBig = [50, 200, 1000]
    yBig = randn(nBig, 1);
    rBig = randn(nBig, 1) * 0.1;
    mBig = fitting.fitCompare(yBig, rBig, 3);
    diff_ic = abs(mBig.aicc - mBig.aic);
    if nBig >= 200
        tol_ic = 0.2;
    else
        tol_ic = 2.0;
    end
    if diff_ic < tol_ic
        fprintf('  PASS: n=%d  |AICc-AIC| = %.4f < %.2f\n', nBig, diff_ic, tol_ic);
        passed = passed + 1;
    else
        fprintf('  FAIL: n=%d  |AICc-AIC| = %.4f (expected < %.2f)\n', ...
            nBig, diff_ic, tol_ic);
        failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  BETTER MODEL HAS LOWER AIC
%  Compare: linear fit (p=2) vs quadratic fit (p=3) on quadratic data
%  Quadratic model should have lower AIC when data is truly quadratic
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- better model (lower RSS, more params) has lower AIC ---\n');

rng(7);
n2   = 60;
x2   = linspace(-3, 3, n2)';
yQ   = 0.5*x2.^2 + x2 + randn(n2,1)*0.3;

% Linear fit residuals (larger RSS)
p1lin = polyfit(x2, yQ, 1);
resLin = yQ - polyval(p1lin, x2);

% Quadratic fit residuals (smaller RSS)
p2quad = polyfit(x2, yQ, 2);
resQuad = yQ - polyval(p2quad, x2);

mLin  = fitting.fitCompare(yQ, resLin,  2);
mQuad = fitting.fitCompare(yQ, resQuad, 3);

if mQuad.aic < mLin.aic
    fprintf('  PASS: quadratic AIC (%.2f) < linear AIC (%.2f)\n', ...
        mQuad.aic, mLin.aic); passed = passed + 1;
else
    fprintf('  FAIL: quadratic AIC (%.2f) >= linear AIC (%.2f)\n', ...
        mQuad.aic, mLin.aic); failed = failed + 1;
end

% adjR2 of quadratic should be higher
if mQuad.adjR2 > mLin.adjR2
    fprintf('  PASS: quadratic adjR2 (%.4f) > linear adjR2 (%.4f)\n', ...
        mQuad.adjR2, mLin.adjR2); passed = passed + 1;
else
    fprintf('  FAIL: quadratic adjR2 (%.4f) <= linear adjR2 (%.4f)\n', ...
        mQuad.adjR2, mLin.adjR2); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  F-TEST: LINEAR VS QUADRATIC (nested models)
%  With truly quadratic data the quadratic model should give F >> 1, p < 0.05
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- F-test: linear vs quadratic on quadratic data ---\n');

mFTest = fitting.fitCompare(yQ, resQuad, 3, ...
    ResidRef=resLin, NParamsRef=2);

if ~isnan(mFTest.fStat) && mFTest.fStat > 1
    fprintf('  PASS: F-stat = %.3f (> 1, quadratic explains more)\n', mFTest.fStat);
    passed = passed + 1;
else
    fprintf('  FAIL: F-stat = %.3f (expected > 1)\n', mFTest.fStat); failed = failed + 1;
end

if ~isnan(mFTest.fPvalue) && mFTest.fPvalue < 0.05
    fprintf('  PASS: F p-value = %.4f (< 0.05, significant improvement)\n', ...
        mFTest.fPvalue); passed = passed + 1;
else
    fprintf('  FAIL: F p-value = %.4f (expected < 0.05)\n', mFTest.fPvalue);
    failed = failed + 1;
end

% F-stat direction: identical models should give F ~ 0
mFIdentical = fitting.fitCompare(yQ, resQuad, 3, ...
    ResidRef=resQuad, NParamsRef=2);
% RSS_ref - RSS = 0, so F = 0
if isnan(mFIdentical.fStat) || mFIdentical.fStat <= 1e-6
    fprintf('  PASS: F = %.6f ~ 0 when reference and current residuals are equal\n', ...
        mFIdentical.fStat); passed = passed + 1;
else
    fprintf('  FAIL: F = %.6f expected ~ 0 for identical residuals\n', ...
        mFIdentical.fStat); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  F-TEST: F(1,df2) p-value against known value
%  F(1,100) = 3.84 → p ≈ 0.05 (standard tabulated value)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- F-test p-value against tabulated F(1,100)=3.84 ---\n');

% Construct synthetic residuals giving exactly that F statistic
%   F = (RSSref - RSS) / (1) / (RSS / df2)  where df2 = n - p
%   Set n=103, p=2, pRef=1.  Then df2=101.
%   Choose RSS and RSSref so F = 3.84.
nF  = 103;
df2 = nF - 2;    % = 101
RSS_f = 1;
RSSref_f = RSS_f + 3.84 * RSS_f / df2;

% Create synthetic yData (constant) and matching residuals
yF    = ones(nF, 1);
rFull = ones(nF, 1) * sqrt(RSS_f / nF);     % uniform residuals, RSS exact
rRef  = ones(nF, 1) * sqrt(RSSref_f / nF);

% Adjust to get exact RSS
rFull = rFull * sqrt(RSS_f / sum(rFull.^2));
rRef  = rRef  * sqrt(RSSref_f / sum(rRef.^2));

mFtab = fitting.fitCompare(yF, rFull, 2, ResidRef=rRef, NParamsRef=1);
if ~isnan(mFtab.fPvalue) && abs(mFtab.fPvalue - 0.05) < 0.02
    fprintf('  PASS: p-value = %.4f ≈ 0.05 for F(1,101)≈3.84\n', mFtab.fPvalue);
    passed = passed + 1;
else
    fprintf('  FAIL: p-value = %.4f (expected ≈ 0.05)\n', mFtab.fPvalue); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  EDGE CASE: n = p + 1 (minimum degrees of freedom)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- edge case: n = p+1 (minimum DOF) ---\n');

yMin = [1; 2; 3];   % n=3, p=2
rMin = [0; 0; 0];   % perfect fit

try
    mMin = fitting.fitCompare(yMin, rMin, 2);
    % adjR2 requires n-p-1 = 0 → should be NaN
    if isnan(mMin.adjR2)
        fprintf('  PASS: adjR2 = NaN when n-p-1 = 0\n'); passed = passed + 1;
    else
        fprintf('  FAIL: adjR2 = %.4f (expected NaN when n-p-1=0)\n', mMin.adjR2);
        failed = failed + 1;
    end
    % AICc denominator n-p-1 = 0 → should be Inf (flagged unreliable)
    if isinf(mMin.aicc)
        fprintf('  PASS: AICc = Inf when n-p-1 = 0\n'); passed = passed + 1;
    else
        fprintf('  FAIL: AICc = %.4f (expected Inf when n-p-1=0)\n', mMin.aicc);
        failed = failed + 1;
    end
    fprintf('  PASS: no crash for n=p+1\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: crashed for n=p+1: %s\n', ME.message); failed = failed + 3;
end

% ════════════════════════════════════════════════════════════════════════
%  EDGE CASE: perfect fit (RSS = 0)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- edge case: perfect fit (RSS=0) ---\n');

yPerf = (1:20)';
rPerf = zeros(20, 1);

try
    mPerf = fitting.fitCompare(yPerf, rPerf, 2);
    if mPerf.aic == -Inf
        fprintf('  PASS: AIC = -Inf for perfect fit\n'); passed = passed + 1;
    else
        fprintf('  FAIL: AIC = %.4f (expected -Inf)\n', mPerf.aic); failed = failed + 1;
    end
    if mPerf.bic == -Inf
        fprintf('  PASS: BIC = -Inf for perfect fit\n'); passed = passed + 1;
    else
        fprintf('  FAIL: BIC = %.4f (expected -Inf)\n', mPerf.bic); failed = failed + 1;
    end
    if mPerf.rmse == 0
        fprintf('  PASS: RMSE = 0 for perfect fit\n'); passed = passed + 1;
    else
        fprintf('  FAIL: RMSE = %.6g (expected 0)\n', mPerf.rmse); failed = failed + 1;
    end
    fprintf('  PASS: no crash for perfect fit\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: crashed for perfect fit: %s\n', ME.message); failed = failed + 4;
end

% ════════════════════════════════════════════════════════════════════════
%  EDGE CASE: constant yData (TSS = 0) → R2 undefined
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- edge case: constant yData (TSS=0) ---\n');

yConst = ones(20, 1) * 5;
rConst = randn(20, 1) * 0.1;

try
    mConst = fitting.fitCompare(yConst, rConst, 1);
    if isnan(mConst.R2)
        fprintf('  PASS: R2 = NaN when TSS=0\n'); passed = passed + 1;
    else
        fprintf('  FAIL: R2 = %.4f (expected NaN when TSS=0)\n', mConst.R2);
        failed = failed + 1;
    end
    fprintf('  PASS: no crash for constant y\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: crashed for constant y: %s\n', ME.message); failed = failed + 2;
end

% ════════════════════════════════════════════════════════════════════════
%  F-TEST NOT PERFORMED WHEN ResidRef NOT SUPPLIED
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- fStat/fPvalue NaN when ResidRef not supplied ---\n');

mNoF = fitting.fitCompare(yQ, resQuad, 3);
if isnan(mNoF.fStat) && isnan(mNoF.fPvalue)
    fprintf('  PASS: fStat=NaN, fPvalue=NaN when no ResidRef\n'); passed = passed + 1;
else
    fprintf('  FAIL: fStat=%.4f fPvalue=%.4f (expected NaN)\n', ...
        mNoF.fStat, mNoF.fPvalue); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════════

fprintf('\n=== test_fitCompare: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_fitCompare:failures', '%d test(s) failed.', failed);
end

% ════════════════════════════════════════════════════════════════════════
% Helpers (must be at end of script for R2022b–R2023b compatibility;
% R2024a relaxed this to allow function defs anywhere in scripts)
% ════════════════════════════════════════════════════════════════════════

function tf = near(a, b, tol)
    if nargin < 3, tol = 1e-6; end
    tf = abs(a - b) <= tol * (1 + abs(b));
end
