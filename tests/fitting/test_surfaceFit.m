%TEST_SURFACEFIT  Tests for fitting.surfaceFit, fitting.surfaceModels,
%   fitting.surfaceAutoGuess.
%
%   Run:
%     run tests/fitting/test_surfaceFit
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_surfaceFit ===\n');
passed = 0;
failed = 0;

rng(42);   % reproducible noise

% ════════════════════════════════════════════════════════════════════════
%  MODEL CATALOG
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.surfaceModels catalog ---\n');

catalog = fitting.surfaceModels();

requiredFields = {'name','func','paramNames','nParams','description'};
allFieldsOk = true;
for i = 1:numel(catalog)
    for j = 1:numel(requiredFields)
        if ~isfield(catalog(i), requiredFields{j})
            allFieldsOk = false;
            fprintf('  FAIL: model %d missing field "%s"\n', i, requiredFields{j});
        end
    end
end
if allFieldsOk
    fprintf('  PASS: all models have required fields\n'); passed = passed + 1;
else
    failed = failed + 1;
end

% nParams matches paramNames length
nParamsOk = true;
for i = 1:numel(catalog)
    if catalog(i).nParams ~= numel(catalog(i).paramNames)
        nParamsOk = false;
        fprintf('  FAIL: model "%s" nParams=%d but %d paramNames\n', ...
            catalog(i).name, catalog(i).nParams, numel(catalog(i).paramNames));
    end
end
if nParamsOk
    fprintf('  PASS: nParams matches paramNames for all models\n'); passed = passed + 1;
else
    failed = failed + 1;
end

% func callable for each model
allCallable = true;
xT = (0:0.5:2)'; yT = (0:0.5:2)';
[XT,YT] = meshgrid(xT, yT);
xF = XT(:); yF = YT(:);
for i = 1:numel(catalog)
    p0 = ones(1, catalog(i).nParams);
    try
        zOut = catalog(i).func(p0, xF, yF);
        if numel(zOut) ~= numel(xF)
            allCallable = false;
            fprintf('  FAIL: model "%s" wrong output size\n', catalog(i).name);
        end
    catch ME
        allCallable = false;
        fprintf('  FAIL: model "%s" error: %s\n', catalog(i).name, ME.message);
    end
end
if allCallable
    fprintf('  PASS: all model functions are callable with unit params\n'); passed = passed + 1;
else
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  PLANE FIT
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Plane fit ---\n');

[XP, YP] = meshgrid(-3:0.5:3, -3:0.5:3);
ZP_true = 2*XP + 3*YP + 1;
noise   = 0.01 * randn(size(ZP_true));
ZP      = ZP_true + noise;

result = fitting.surfaceFit(XP, YP, ZP, 'Plane');

tol = 0.05;
paramOk = abs(result.params(1) - 2) < tol && ...
          abs(result.params(2) - 3) < tol && ...
          abs(result.params(3) - 1) < tol;
if paramOk
    fprintf('  PASS: Plane params recovered (a=%.3f, b=%.3f, c=%.3f)\n', ...
        result.params(1), result.params(2), result.params(3));
    passed = passed + 1;
else
    fprintf('  FAIL: Plane params off — got (%.3f, %.3f, %.3f), expected (2, 3, 1)\n', ...
        result.params(1), result.params(2), result.params(3));
    failed = failed + 1;
end

if result.R2 > 0.99
    fprintf('  PASS: R² = %.6f\n', result.R2); passed = passed + 1;
else
    fprintf('  FAIL: R² = %.6f (expected > 0.99)\n', result.R2); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2D GAUSSIAN FIT
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- 2D Gaussian fit ---\n');

[XG, YG] = meshgrid(-4:0.4:4, -4:0.4:4);
A_true  = 5.0;
x0_true = 0.5;
sx_true = 1.2;
y0_true = -0.3;
sy_true = 0.9;
z0_true = 0.1;
ZG_true = A_true * exp(-((XG-x0_true).^2/(2*sx_true^2) + (YG-y0_true).^2/(2*sy_true^2))) + z0_true;
ZG      = ZG_true + 0.02 * randn(size(ZG_true));

result = fitting.surfaceFit(XG, YG, ZG, '2D Gaussian');

ampOk    = abs(result.params(1) - A_true)  < 0.2;
x0Ok     = abs(result.params(2) - x0_true) < 0.1;
y0Ok     = abs(result.params(4) - y0_true) < 0.1;
widthsOk = abs(abs(result.params(3)) - sx_true) < 0.15 && ...
           abs(abs(result.params(5)) - sy_true) < 0.15;

if ampOk
    fprintf('  PASS: amplitude recovered (%.4f vs %.4f)\n', result.params(1), A_true);
    passed = passed + 1;
else
    fprintf('  FAIL: amplitude off (%.4f vs %.4f)\n', result.params(1), A_true);
    failed = failed + 1;
end

if x0Ok && y0Ok
    fprintf('  PASS: center recovered (%.3f, %.3f) vs (%.3f, %.3f)\n', ...
        result.params(2), result.params(4), x0_true, y0_true);
    passed = passed + 1;
else
    fprintf('  FAIL: center off (%.3f, %.3f) vs (%.3f, %.3f)\n', ...
        result.params(2), result.params(4), x0_true, y0_true);
    failed = failed + 1;
end

if widthsOk
    fprintf('  PASS: widths recovered (sx=%.3f, sy=%.3f)\n', ...
        abs(result.params(3)), abs(result.params(5)));
    passed = passed + 1;
else
    fprintf('  FAIL: widths off (sx=%.3f, sy=%.3f) vs (%.3f, %.3f)\n', ...
        abs(result.params(3)), abs(result.params(5)), sx_true, sy_true);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  R² FOR PERFECT DATA
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- R² for noiseless data ---\n');

[XN, YN] = meshgrid(0:0.5:4, 0:0.5:4);
ZN = 1.5*XN + 2.0*YN + 0.5;
resultN = fitting.surfaceFit(XN, YN, ZN, 'Plane');

if resultN.R2 > 0.9999
    fprintf('  PASS: R² = %.8f for noiseless plane\n', resultN.R2); passed = passed + 1;
else
    fprintf('  FAIL: R² = %.8f (expected ~1.0)\n', resultN.R2); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  PARABOLOID FIT
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Paraboloid fit ---\n');

[XQ, YQ] = meshgrid(-3:0.5:3, -3:0.5:3);
% z = 1*x² + 0.5*y² + 0*xy + 0*x + 0*y + 2
ZQ = 1*XQ.^2 + 0.5*YQ.^2 + 2;
noise2 = 0.02 * randn(size(ZQ));
ZQ = ZQ + noise2;

resultQ = fitting.surfaceFit(XQ, YQ, ZQ, 'Paraboloid');

% Check diagonal quadratic terms
aOk = abs(resultQ.params(1) - 1.0) < 0.1;
bOk = abs(resultQ.params(2) - 0.5) < 0.1;
fOk = abs(resultQ.params(6) - 2.0) < 0.1;

if aOk && bOk && fOk
    fprintf('  PASS: Paraboloid params recovered (a=%.3f, b=%.3f, f=%.3f)\n', ...
        resultQ.params(1), resultQ.params(2), resultQ.params(6));
    passed = passed + 1;
else
    fprintf('  FAIL: Paraboloid params off (a=%.3f, b=%.3f, f=%.3f)\n', ...
        resultQ.params(1), resultQ.params(2), resultQ.params(6));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  AUTO-GUESS: REASONABLE ESTIMATES
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- surfaceAutoGuess ---\n');

x1d = XG(:); y1d = YG(:); z1d = ZG_true(:);

% Gaussian: amplitude guess within 5x of true
p0g = fitting.surfaceAutoGuess('2D Gaussian', x1d, y1d, z1d);
ampGuessOk = p0g(1) > A_true/5 && p0g(1) < A_true*5;
if ampGuessOk
    fprintf('  PASS: 2D Gaussian amplitude guess reasonable (%.3f vs true %.3f)\n', p0g(1), A_true);
    passed = passed + 1;
else
    fprintf('  FAIL: 2D Gaussian amplitude guess unreasonable (%.3f vs true %.3f)\n', p0g(1), A_true);
    failed = failed + 1;
end

% Plane: guesses have correct length
p0p = fitting.surfaceAutoGuess('Plane', x1d, y1d, z1d);
if numel(p0p) == 3
    fprintf('  PASS: Plane auto-guess returns 3 params\n'); passed = passed + 1;
else
    fprintf('  FAIL: Plane auto-guess returned %d params (expected 3)\n', numel(p0p));
    failed = failed + 1;
end

% Unknown model raises error
try
    fitting.surfaceAutoGuess('NoSuchModel2D', x1d, y1d, z1d);
    fprintf('  FAIL: expected error for unknown model\n'); failed = failed + 1;
catch
    fprintf('  PASS: unknown model raises error\n'); passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  EDGE CASE: TOO FEW POINTS
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Edge case: too few points ---\n');

try
    fitting.surfaceFit([1;2], [1;2], [1;2], '2D Gaussian');
    fprintf('  FAIL: expected error for too few points vs 2D Gaussian (6 params)\n');
    failed = failed + 1;
catch
    fprintf('  PASS: too few points raises error gracefully\n');
    passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  OUTPUT STRUCT FIELDS
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Output struct fields ---\n');

requiredOut = {'params','paramNames','errors','residuals','zFit','R2','RMSE', ...
               'covar','chiSqRed','modelName','modelFcn','exitFlag','nPoints','nFree'};
allOut = true;
for k = 1:numel(requiredOut)
    if ~isfield(result, requiredOut{k})
        allOut = false;
        fprintf('  FAIL: missing output field "%s"\n', requiredOut{k});
    end
end
if allOut
    fprintf('  PASS: all required output fields present\n'); passed = passed + 1;
else
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  CUSTOM MODEL STRUCT
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Custom model struct ---\n');

customModel.func       = @(p,x,y) p(1)*x + p(2)*y + p(3);
customModel.paramNames = {'m1','m2','offset'};

[Xc,Yc] = meshgrid(0:1:4, 0:1:4);
Zc = 3*Xc - 2*Yc + 5;
resultC = fitting.surfaceFit(Xc, Yc, Zc, customModel);

custOk = abs(resultC.params(1) - 3) < 0.05 && ...
         abs(resultC.params(2) + 2) < 0.05 && ...
         abs(resultC.params(3) - 5) < 0.05;
if custOk
    fprintf('  PASS: custom model params recovered\n'); passed = passed + 1;
else
    fprintf('  FAIL: custom model params off (%.3f, %.3f, %.3f)\n', ...
        resultC.params(1), resultC.params(2), resultC.params(3));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  MESHGRID INPUT AUTO-FLATTEN
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Meshgrid input flattening ---\n');

[Xm, Ym] = meshgrid(0:0.5:2, 0:0.5:2);
Zm = 2*Xm + Ym + 1;
resultM = fitting.surfaceFit(Xm, Ym, Zm, 'Plane');
if resultM.nPoints == numel(Zm)
    fprintf('  PASS: meshgrid inputs correctly flattened (%d points)\n', resultM.nPoints);
    passed = passed + 1;
else
    fprintf('  FAIL: expected %d points, got %d\n', numel(Zm), resultM.nPoints);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════════

fprintf('\n%s\n', repmat('=', 1, 50));
fprintf('  test_surfaceFit: %d passed, %d failed\n', passed, failed);
fprintf('%s\n', repmat('=', 1, 50));

if failed > 0
    error('test_surfaceFit:failures', '%d test(s) failed.', failed);
end
