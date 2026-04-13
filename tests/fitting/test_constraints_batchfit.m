%TEST_CONSTRAINTS_BATCHFIT  Tests for parameter constraints and batch fit.
%
%   Run:
%     run tests/fitting/test_constraints_batchfit
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
    setupToolbox;
end

fprintf('\n=== test_constraints_batchfit ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  APPLY CONSTRAINTS
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.applyConstraints ---\n');

% Single constraint: b = 2*a  (a is p1)
constraints = {'', '2*p1'};
names = {'a', 'b'};
[pFull, fi] = fitting.applyConstraints([3.5], constraints, names);
if abs(pFull(1) - 3.5) < 1e-10 && abs(pFull(2) - 7.0) < 1e-10 && isequal(fi, 1)
    fprintf('  PASS: b=2*a: pFull=[%.2f %.2f], freeIdx=[%d]\n', pFull, fi);
    passed = passed + 1;
else
    fprintf('  FAIL: b=2*a: pFull=[%s], freeIdx=[%s]\n', ...
        num2str(pFull,'%.2f '), num2str(fi));
    failed = failed + 1;
end

% Two free, one constrained: c = a + b
constraints2 = {'', '', 'p1 + p2'};
names2 = {'a', 'b', 'c'};
[pFull2, fi2] = fitting.applyConstraints([1, 2], constraints2, names2);
if abs(pFull2(3) - 3.0) < 1e-10 && isequal(fi2, [1 2])
    fprintf('  PASS: c=a+b: pFull(3)=%.2f (exp 3), freeIdx=[%s]\n', pFull2(3), num2str(fi2));
    passed = passed + 1;
else
    fprintf('  FAIL: c=a+b: pFull=[%s]\n', num2str(pFull2,'%.3f '));
    failed = failed + 1;
end

% Arithmetic constraint: c = sqrt(p1)
constraints3 = {'', 'sqrt(p1)'};
names3 = {'A', 'B'};
[pFull3, ~] = fitting.applyConstraints([4.0], constraints3, names3);
if abs(pFull3(2) - 2.0) < 1e-10
    fprintf('  PASS: B=sqrt(A): pFull(2)=%.4f (exp 2.0)\n', pFull3(2));
    passed = passed + 1;
else
    fprintf('  FAIL: B=sqrt(A): pFull(2)=%.4f (exp 2.0)\n', pFull3(2));
    failed = failed + 1;
end

% Named-reference constraint: b = 2*a (using name 'a' not 'p1')
constraintsN = {'', '2*a'};
namesN = {'a', 'b'};
try
    [pFullN, ~] = fitting.applyConstraints([5.0], constraintsN, namesN);
    if abs(pFullN(2) - 10.0) < 1e-10
        fprintf('  PASS: named reference "2*a" works: b=%.2f (exp 10)\n', pFullN(2));
        passed = passed + 1;
    else
        fprintf('  FAIL: named reference "2*a": b=%.4f (exp 10)\n', pFullN(2));
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: named reference threw: %s\n', ME.message);
    failed = failed + 1;
end

% Error on wrong pFree size
try
    fitting.applyConstraints([1 2], {'', '2*p1'}, {'a','b'});
    fprintf('  FAIL: wrong pFree size should throw\n'); failed = failed + 1;
catch
    fprintf('  PASS: wrong pFree size throws correctly\n'); passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  CURVEFIT WITH CONSTRAINTS
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.curveFit with Constraints ---\n');

% Fit y = a*x + b with constraint b = 2*a
% True model: a=3, b=6 (satisfies b=2*a)
xLin = linspace(0, 5, 100)';
yLin = 3*xLin + 6 + 0.05*randn(100, 1);   % noise around true

linFcn = @(x,p) p(1)*x + p(2);
res = fitting.curveFit(xLin, yLin, linFcn, [1 2], ...
    Constraints={'', '2*p1'}, ParamNames={'a','b'});

% b should be approximately 2*a
aHat = res.params(1);
bHat = res.params(2);
if abs(bHat - 2*aHat) < 1e-6
    fprintf('  PASS: constraint b=2*a enforced: a=%.4f, b=%.4f (b/a=%.6f)\n', ...
        aHat, bHat, bHat/aHat);
    passed = passed + 1;
else
    fprintf('  FAIL: b != 2*a: a=%.4f, b=%.4f\n', aHat, bHat);
    failed = failed + 1;
end

if res.R2 > 0.95
    fprintf('  PASS: constrained fit converged (R2=%.5f)\n', res.R2);
    passed = passed + 1;
else
    fprintf('  FAIL: constrained fit R2=%.5f (expected > 0.95)\n', res.R2);
    failed = failed + 1;
end

% nFree should reflect only the free params (1 here: only a)
if res.nFree == 1
    fprintf('  PASS: nFree=1 with one constrained param\n');
    passed = passed + 1;
else
    fprintf('  FAIL: nFree=%d (expected 1)\n', res.nFree);
    failed = failed + 1;
end

% Full params vector should have M=2 elements
if numel(res.params) == 2
    fprintf('  PASS: result.params has full length M=2\n');
    passed = passed + 1;
else
    fprintf('  FAIL: result.params has %d elements (expected 2)\n', numel(res.params));
    failed = failed + 1;
end

% Constraints with no constraint expressions = same as no Constraints arg
rNoConst = fitting.curveFit(xLin, yLin, linFcn, [1 2]);
resEmptyConst = fitting.curveFit(xLin, yLin, linFcn, [1 2], ...
    Constraints={'', ''}, ParamNames={'a','b'});
% Both should have nFree=2
if resEmptyConst.nFree == 2
    fprintf('  PASS: empty constraints -> nFree=2 (all free)\n');
    passed = passed + 1;
else
    fprintf('  FAIL: empty constraints -> nFree=%d (expected 2)\n', resEmptyConst.nFree);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  BATCH FIT: parameter recovery
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.batchFit: 3 synthetic datasets ---\n');

rng(42);

% True parameters: exponential decay A*exp(-x/tau) + C
% Dataset 1: A=2, tau=1.0, C=0.1
% Dataset 2: A=3, tau=1.5, C=0.2
% Dataset 3: A=1, tau=0.8, C=0.05
xB = linspace(0, 6, 150)';
trueParams = [2 1.0 0.1; 3 1.5 0.2; 1 0.8 0.05];
expFcn = @(x,p) p(1)*exp(-x./p(2)) + p(3);

syntheticData = cell(1, 3);
for k = 1:3
    A   = trueParams(k,1);
    tau = trueParams(k,2);
    C   = trueParams(k,3);
    y = A*exp(-xB./tau) + C + 0.02*randn(size(xB));
    syntheticData{k} = {xB, y};
end

summary = fitting.batchFit(syntheticData, expFcn, [2 1 0.1], ...
    Lower=[0 0 -1], Upper=[10 10 2], ...
    ModelName='Exponential Decay', Verbose=false);

% Check shape
if isequal(size(summary.params), [3 3])
    fprintf('  PASS: summary.params is [3x3]\n'); passed = passed + 1;
else
    fprintf('  FAIL: summary.params size = [%s]\n', num2str(size(summary.params)));
    failed = failed + 1;
end

% Check convergence
if all(summary.converged)
    fprintf('  PASS: all 3 datasets converged\n'); passed = passed + 1;
else
    fprintf('  FAIL: convergence flags = [%s]\n', num2str(summary.converged'));
    failed = failed + 1;
end

% Check R2 is high for all datasets
if all(summary.R2 > 0.95)
    fprintf('  PASS: all R2 > 0.95 (min=%.4f)\n', min(summary.R2));
    passed = passed + 1;
else
    fprintf('  FAIL: some R2 < 0.95: [%s]\n', num2str(summary.R2','%.4f '));
    failed = failed + 1;
end

% Check parameter recovery (within 20% of true)
paramRecoveryOk = true;
for k = 1:3
    for pi = 1:3
        if abs(summary.params(k,pi) - trueParams(k,pi)) > 0.2 * abs(trueParams(k,pi)) + 0.05
            paramRecoveryOk = false;
            fprintf('  WARN: dataset %d param %d: got %.4f, true %.4f\n', ...
                k, pi, summary.params(k,pi), trueParams(k,pi));
        end
    end
end
if paramRecoveryOk
    fprintf('  PASS: all parameters recovered within tolerance\n'); passed = passed + 1;
else
    fprintf('  FAIL: some parameters outside tolerance\n'); failed = failed + 1;
end

% Check output struct fields
requiredFields = {'params','errors','R2','chiSqRed','RMSE','AIC', ...
    'exitFlags','paramNames','modelName','metaValues','nDatasets','converged'};
missingFields = requiredFields(~cellfun(@(f) isfield(summary, f), requiredFields));
if isempty(missingFields)
    fprintf('  PASS: all required output fields present\n'); passed = passed + 1;
else
    fprintf('  FAIL: missing fields: %s\n', strjoin(missingFields, ', ')); failed = failed + 1;
end

% Check paramNames set correctly from ModelName
if numel(summary.paramNames) == 3
    fprintf('  PASS: paramNames has 3 entries\n'); passed = passed + 1;
else
    fprintf('  FAIL: paramNames has %d entries (expected 3)\n', numel(summary.paramNames));
    failed = failed + 1;
end

% Batch fit with {x,y} pairs and no ModelName (generic param names)
summaryGeneric = fitting.batchFit(syntheticData, expFcn, [2 1 0.1], Verbose=false);
if all(cellfun(@(n) startsWith(n,'p'), summaryGeneric.paramNames))
    fprintf('  PASS: generic param names used when ModelName not given\n'); passed = passed + 1;
else
    fprintf('  FAIL: unexpected paramNames without ModelName: %s\n', ...
        strjoin(summaryGeneric.paramNames,', ')); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════════

fprintf('\n=== test_constraints_batchfit: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_constraints_batchfit:failures', '%d test(s) failed.', failed);
end
