%TEST_CURVE_FITTING  Tests for the +fitting package: models, curveFit,
%   autoGuess, parseEquation.
%
%   Run:
%     run tests/fitting/test_curve_fitting
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_curve_fitting ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  MODEL LIBRARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.models ---\n');

catalog = fitting.models();

% All models have required fields
requiredFields = {'name','category','equation','fcn','paramNames','p0','lb','ub','nParams'};
allFieldsOk = true;
for i = 1:numel(catalog)
    for j = 1:numel(requiredFields)
        if ~isfield(catalog(i), requiredFields{j})
            allFieldsOk = false;
        end
    end
end
if allFieldsOk
    fprintf('  PASS: all models have required fields\n'); passed = passed + 1;
else
    fprintf('  FAIL: some models missing required fields\n'); failed = failed + 1;
end

% nParams matches p0 length for every model
nParamsOk = true;
for i = 1:numel(catalog)
    if catalog(i).nParams ~= numel(catalog(i).p0) || ...
       catalog(i).nParams ~= numel(catalog(i).lb) || ...
       catalog(i).nParams ~= numel(catalog(i).ub) || ...
       catalog(i).nParams ~= numel(catalog(i).paramNames)
        nParamsOk = false;
        fprintf('    mismatch in model: %s\n', catalog(i).name);
    end
end
if nParamsOk
    fprintf('  PASS: nParams consistent across all models\n'); passed = passed + 1;
else
    fprintf('  FAIL: nParams inconsistencies found\n'); failed = failed + 1;
end

% Each model fcn evaluates without error
x = linspace(0.1, 10, 50)';
allEvalOk = true;
for i = 1:numel(catalog)
    try
        y = catalog(i).fcn(x, catalog(i).p0);
        if ~isequal(size(y), size(x)) && ~isscalar(y)
            allEvalOk = false;
            fprintf('    size mismatch: %s\n', catalog(i).name);
        end
    catch ME
        allEvalOk = false;
        fprintf('    error in %s: %s\n', catalog(i).name, ME.message);
    end
end
if allEvalOk
    fprintf('  PASS: all model fcns evaluate on test data\n'); passed = passed + 1;
else
    fprintf('  FAIL: some model fcns failed\n'); failed = failed + 1;
end

% Check minimum model count (should have at least 20 models)
if numel(catalog) >= 20
    fprintf('  PASS: catalog has %d models (>= 20)\n', numel(catalog)); passed = passed + 1;
else
    fprintf('  FAIL: catalog has only %d models\n', numel(catalog)); failed = failed + 1;
end

% Check categories exist
cats = unique({catalog.category});
expectedCats = {'Linear','Decay','Growth','Peak','Power','Sigmoid','Magnetic','Thermal','Other'};
missingCats = setdiff(expectedCats, cats);
if isempty(missingCats)
    fprintf('  PASS: all expected categories present\n'); passed = passed + 1;
else
    fprintf('  FAIL: missing categories: %s\n', strjoin(missingCats, ', ')); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  CURVE FIT ENGINE — Linear fit (exact recovery)
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.curveFit ---\n');

% Linear: y = 2x + 3 (no noise, should recover exactly)
xLin = linspace(0, 10, 100)';
yLin = 2*xLin + 3;
linFcn = @(x,p) p(1)*x + p(2);
res = fitting.curveFit(xLin, yLin, linFcn, [1 1]);
if abs(res.params(1) - 2) < 1e-4 && abs(res.params(2) - 3) < 1e-4
    fprintf('  PASS: linear fit recovers m=2, b=3\n'); passed = passed + 1;
else
    fprintf('  FAIL: linear fit: m=%.4f (exp 2), b=%.4f (exp 3)\n', res.params(1), res.params(2));
    failed = failed + 1;
end

if res.R2 > 0.9999
    fprintf('  PASS: linear R² = %.8f (>0.9999)\n', res.R2); passed = passed + 1;
else
    fprintf('  FAIL: linear R² = %.8f\n', res.R2); failed = failed + 1;
end

% ── Exponential decay with noise ──────────────────────────────────

rng(42);
xExp = linspace(0, 5, 200)';
yTrue = 3.5*exp(-xExp/1.2) + 0.5;
yNoisy = yTrue + 0.05*randn(size(yTrue));
expFcn = @(x,p) p(1)*exp(-x./p(2)) + p(3);
res = fitting.curveFit(xExp, yNoisy, expFcn, [3 1 0]);
if abs(res.params(1) - 3.5) < 0.3 && abs(res.params(2) - 1.2) < 0.2 && abs(res.params(3) - 0.5) < 0.2
    fprintf('  PASS: exp decay recovery (A=%.2f, τ=%.2f, C=%.2f)\n', res.params);
    passed = passed + 1;
else
    fprintf('  FAIL: exp decay: A=%.2f (exp 3.5), τ=%.2f (exp 1.2), C=%.2f (exp 0.5)\n', res.params);
    failed = failed + 1;
end

% ── Parameter errors are finite and positive ──────────────────────

if all(isfinite(res.errors)) && all(res.errors > 0)
    fprintf('  PASS: param errors are finite and positive\n'); passed = passed + 1;
else
    fprintf('  FAIL: param errors: [%s]\n', num2str(res.errors, '%.4g ')); failed = failed + 1;
end

% ── Covariance matrix is symmetric positive semi-definite ─────────

if ~isempty(res.covar)
    symErr = max(abs(res.covar - res.covar'), [], 'all');
    eigVals = eig(res.covar);
    if symErr < 1e-10 && all(eigVals >= -1e-10)
        fprintf('  PASS: covariance matrix is symmetric PSD\n'); passed = passed + 1;
    else
        fprintf('  FAIL: covariance matrix issues (symErr=%.2g, minEig=%.2g)\n', ...
            symErr, min(eigVals)); failed = failed + 1;
    end
else
    fprintf('  FAIL: covariance matrix is empty\n'); failed = failed + 1;
end

% ── Fit statistics fields exist and are reasonable ────────────────

statsOk = isfield(res, 'R2') && isfield(res, 'chiSqRed') && ...
    isfield(res, 'RMSE') && isfield(res, 'AIC') && ...
    isfield(res, 'nFree') && isfield(res, 'nPoints');
if statsOk && res.R2 > 0.95 && res.RMSE < 0.2 && res.nFree == 3 && res.nPoints == 200
    fprintf('  PASS: fit statistics reasonable (R²=%.4f, RMSE=%.4g)\n', res.R2, res.RMSE);
    passed = passed + 1;
else
    fprintf('  FAIL: fit statistics issues\n'); failed = failed + 1;
end

% ── Bounds enforcement ────────────────────────────────────────────

% Fit with tight bounds — parameter should stay within
res2 = fitting.curveFit(xExp, yNoisy, expFcn, [3 1 0], ...
    Lower=[0 0.5 -1], Upper=[10 5 2]);
if all(res2.params >= [0 0.5 -1]) && all(res2.params <= [10 5 2])
    fprintf('  PASS: bounds enforced correctly\n'); passed = passed + 1;
else
    fprintf('  FAIL: params out of bounds: [%s]\n', num2str(res2.params, '%.3f ')); failed = failed + 1;
end

% ── Fixed parameters ──────────────────────────────────────────────

% Fix C=0.5, fit only A and τ
res3 = fitting.curveFit(xExp, yNoisy, expFcn, [3 1 0.5], ...
    Fixed=[false false true]);
if abs(res3.params(3) - 0.5) < 1e-10
    fprintf('  PASS: fixed parameter held at p0\n'); passed = passed + 1;
else
    fprintf('  FAIL: fixed param moved to %.6f (exp 0.5)\n', res3.params(3)); failed = failed + 1;
end

if res3.nFree == 2
    fprintf('  PASS: nFree = 2 with one fixed param\n'); passed = passed + 1;
else
    fprintf('  FAIL: nFree = %d (exp 2)\n', res3.nFree); failed = failed + 1;
end

% ── Weighted least squares ────────────────────────────────────────

% Higher weight on first half → fit should favor first half
w = ones(200,1);
w(1:100) = 10;
res4 = fitting.curveFit(xExp, yNoisy, expFcn, [3 1 0], Weights=w);
if isfinite(res4.R2) && res4.exitFlag == 1
    fprintf('  PASS: weighted fit converged (R²=%.4f)\n', res4.R2); passed = passed + 1;
else
    fprintf('  FAIL: weighted fit did not converge\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  AUTO-GUESS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.autoGuess ---\n');

% Exponential Decay guess should be in the right ballpark
p0g = fitting.autoGuess('Exponential Decay', xExp, yTrue);
if p0g(1) > 1 && p0g(1) < 10 && p0g(2) > 0.3 && p0g(2) < 5 && abs(p0g(3)) < 2
    fprintf('  PASS: exp decay guess reasonable (A=%.2f, τ=%.2f, C=%.2f)\n', p0g);
    passed = passed + 1;
else
    fprintf('  FAIL: exp decay guess: [%s]\n', num2str(p0g, '%.2f ')); failed = failed + 1;
end

% Linear guess
xL = (1:50)';
yL = 0.5*xL + 10;
p0l = fitting.autoGuess('Linear', xL, yL);
if abs(p0l(1) - 0.5) < 0.2 && abs(p0l(2) - 10) < 5
    fprintf('  PASS: linear guess reasonable (m=%.2f, b=%.2f)\n', p0l); passed = passed + 1;
else
    fprintf('  FAIL: linear guess: [%s]\n', num2str(p0l, '%.2f ')); failed = failed + 1;
end

% Gaussian guess
xG = linspace(-5, 5, 200)';
yG = 4.2 * exp(-(xG - 1.5).^2 / (2*0.8^2));
p0g = fitting.autoGuess('Gaussian', xG, yG);
if abs(p0g(1) - 4.2) < 1 && abs(p0g(2) - 1.5) < 0.5 && p0g(3) > 0
    fprintf('  PASS: Gaussian guess reasonable (A=%.2f, μ=%.2f, σ=%.2f)\n', p0g);
    passed = passed + 1;
else
    fprintf('  FAIL: Gaussian guess: [%s]\n', num2str(p0g, '%.2f ')); failed = failed + 1;
end

% Sigmoid guess
xS = linspace(-5, 5, 100)';
yS = 3 ./ (1 + exp(-2*(xS - 1))) + 0.5;
p0s = fitting.autoGuess('Logistic', xS, yS);
if p0s(1) > 1 && p0s(2) > 0 && abs(p0s(3)) < 5
    fprintf('  PASS: sigmoid guess reasonable (A=%.2f, k=%.2f, x0=%.2f)\n', p0s(1:3));
    passed = passed + 1;
else
    fprintf('  FAIL: sigmoid guess: [%s]\n', num2str(p0s, '%.2f ')); failed = failed + 1;
end

% Auto-guess + curveFit integration: guess → fit should converge for each model
fprintf('\n--- Auto-guess → curveFit integration ---\n');
rng(42);
testModels = {'Linear', 'Exponential Decay', 'Gaussian', 'Power Law', 'Logistic'};
xTest = linspace(0.1, 10, 100)';
integrationPassed = 0;
for i = 1:numel(testModels)
    mName = testModels{i};
    mIdx = find(strcmp({catalog.name}, mName), 1);
    m = catalog(mIdx);
    yTest = m.fcn(xTest, m.p0) + 0.01*randn(size(xTest));
    p0auto = fitting.autoGuess(mName, xTest, yTest);
    try
        r = fitting.curveFit(xTest, yTest, m.fcn, p0auto, Lower=m.lb, Upper=m.ub);
        if r.R2 > 0.9
            fprintf('  PASS: %s — autoGuess → fit converged (R²=%.4f)\n', mName, r.R2);
            integrationPassed = integrationPassed + 1;
        else
            fprintf('  FAIL: %s — low R² = %.4f\n', mName, r.R2);
        end
    catch ME
        fprintf('  FAIL: %s — error: %s\n', mName, ME.message);
    end
end
passed = passed + integrationPassed;
failed = failed + (numel(testModels) - integrationPassed);

% ════════════════════════════════════════════════════════════════════
%  PARSE EQUATION
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.parseEquation ---\n');

% Simple linear: A*x + B
[f, names] = fitting.parseEquation('A*x + B');
if isequal(names, {'A','B'})
    fprintf('  PASS: parsed "A*x + B" → params {A, B}\n'); passed = passed + 1;
else
    fprintf('  FAIL: expected {A,B}, got {%s}\n', strjoin(names,',')); failed = failed + 1;
end

xp = (1:5)';
yp = f(xp, [2, 3]);  % should be 2*x + 3
if max(abs(yp - (2*xp+3))) < 1e-10
    fprintf('  PASS: "A*x + B" evaluates correctly\n'); passed = passed + 1;
else
    fprintf('  FAIL: evaluation mismatch\n'); failed = failed + 1;
end

% Exponential: A*exp(-x/tau) + C
[f2, names2] = fitting.parseEquation('A*exp(-x/tau) + C');
if isequal(names2, {'A','tau','C'})
    fprintf('  PASS: parsed exp equation → {A, tau, C}\n'); passed = passed + 1;
else
    fprintf('  FAIL: expected {A,tau,C}, got {%s}\n', strjoin(names2,',')); failed = failed + 1;
end

yp2 = f2(xp, [2, 1, 0.5]);
yExp2 = 2*exp(-xp/1) + 0.5;
if max(abs(yp2 - yExp2)) < 1e-10
    fprintf('  PASS: exp equation evaluates correctly\n'); passed = passed + 1;
else
    fprintf('  FAIL: exp evaluation mismatch (max err=%.2g)\n', max(abs(yp2-yExp2)));
    failed = failed + 1;
end

% Power with parentheses: A*(x - x0)^n
[f3, names3] = fitting.parseEquation('A*(x - x0)^n');
if numel(names3) == 3  % A, x0, n
    fprintf('  PASS: parsed power equation → %d params\n', numel(names3)); passed = passed + 1;
else
    fprintf('  FAIL: expected 3 params, got %d\n', numel(names3)); failed = failed + 1;
end

% Constants: pi
[f4, ~] = fitting.parseEquation('A*sin(2*pi*x/T)');
yp4 = f4(0.25, [1, 1]);  % sin(2π*0.25/1) = sin(π/2) = 1
if abs(yp4 - 1) < 1e-10
    fprintf('  PASS: pi constant works in sin expression\n'); passed = passed + 1;
else
    fprintf('  FAIL: sin(pi/2) = %.6f (expected 1)\n', yp4); failed = failed + 1;
end

% Strip "y = " prefix
[f5, ~] = fitting.parseEquation('y = m*x + b');
yp5 = f5(2, [3, 1]);  % 3*2 + 1 = 7
if abs(yp5 - 7) < 1e-10
    fprintf('  PASS: "y = ..." prefix stripped correctly\n'); passed = passed + 1;
else
    fprintf('  FAIL: "y = m*x + b" → f(2,[3,1]) = %.4f (exp 7)\n', yp5); failed = failed + 1;
end

% Unary minus: -A*x
[f6, names6] = fitting.parseEquation('-A*x');
yp6 = f6(3, [2]);  % -2*3 = -6
if abs(yp6 - (-6)) < 1e-10
    fprintf('  PASS: unary minus handled correctly\n'); passed = passed + 1;
else
    fprintf('  FAIL: -A*x at x=3, A=2 → %.4f (exp -6)\n', yp6); failed = failed + 1;
end

% Error on empty string
try
    fitting.parseEquation('');
    fprintf('  FAIL: empty string should throw error\n'); failed = failed + 1;
catch
    fprintf('  PASS: empty string throws error\n'); passed = passed + 1;
end

% Error on mismatched parens
try
    fitting.parseEquation('A*(x + B');
    fprintf('  FAIL: mismatched parens should throw error\n'); failed = failed + 1;
catch
    fprintf('  PASS: mismatched parens throws error\n'); passed = passed + 1;
end

% Parse → curveFit integration: fit data generated from parsed equation
fprintf('\n--- parseEquation → curveFit integration ---\n');
[fParsed, pNames] = fitting.parseEquation('A*exp(-x/tau) + C');
xInt = linspace(0, 5, 150)';
yInt = fParsed(xInt, [3.5 1.2 0.5]) + 0.03*randn(size(xInt));
rInt = fitting.curveFit(xInt, yInt, fParsed, [2 1 0]);
if rInt.R2 > 0.95 && abs(rInt.params(1) - 3.5) < 0.5
    fprintf('  PASS: parsed equation fits data (R²=%.4f, A=%.2f)\n', rInt.R2, rInt.params(1));
    passed = passed + 1;
else
    fprintf('  FAIL: parsed equation fit: R²=%.4f, A=%.2f\n', rInt.R2, rInt.params(1));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_curve_fitting: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_curve_fitting:failures', '%d test(s) failed.', failed);
end
