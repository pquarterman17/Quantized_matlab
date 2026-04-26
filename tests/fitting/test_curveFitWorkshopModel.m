%TEST_CURVEFITWORKSHOPMODEL  Isolation tests for the Curve Fit Workshop model.
%
%   Exercises CurveFitWorkshopModel against synthetic data with no GUI,
%   no main BosonPlotter state. Proves the workshop pattern decouples
%   curve-fit logic from the orchestrator.
%
%   Run:
%     run tests/fitting/test_curveFitWorkshopModel
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_curveFitWorkshopModel ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  CONSTRUCTION
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- Construction loads catalog ---\n');
try
    m = bosonPlotter.curveFit.CurveFitWorkshopModel();
    assert(~isempty(m.catalog), 'catalog should load from fitting.models()');
    assert(m.weightsKind == "None" || strcmp(m.weightsKind, 'None'), 'default weights');
    assert(isempty(m.params), 'starts with no params');
    fprintf('  PASS: catalog has %d models\n', numel(m.catalog));
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SELECTMODEL — picks built-in by name, populates params
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- selectModel sets up param array ---\n');
try
    m = bosonPlotter.curveFit.CurveFitWorkshopModel();
    m.selectModel('Gaussian');
    assert(~isempty(m.params), 'params should populate');
    n = numel(m.params);
    assert(n >= 3, sprintf('Gaussian should have ≥3 params; got %d', n));
    assert(isfield(m.params, 'p0') && isfield(m.params, 'lb') && ...
           isfield(m.params, 'fittedErr'), ...
           'params must have canonical 8 fields');
    fprintf('  PASS: Gaussian → %d params (%s)\n', n, ...
        strjoin({m.params.name}, ', '));
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  FIT — recovers known params from synthetic Gaussian
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- fit() recovers Gaussian params from synthetic data ---\n');
try
    x = linspace(-5, 5, 200)';
    trueA = 3.5;  trueMu = 1.2;  trueSigma = 0.8;
    y = trueA .* exp(-((x - trueMu).^2) / (2 * trueSigma^2));
    y = y + 0.02 * randn(size(y));

    m = bosonPlotter.curveFit.CurveFitWorkshopModel();
    m.selectModel('Gaussian');
    m.autoGuess(x, y);
    res = m.fit(x, y);
    assert(m.hasResult(), 'fit must populate result');
    assert(res.R2 > 0.99, sprintf('R2 should be high for clean Gaussian; got %.4f', res.R2));

    % Find which param is which by name (catalog order may vary)
    pNames = {m.params.name};
    fits   = [m.params.fitted];
    iA     = find(contains(lower(pNames), 'a') | strcmp(pNames, 'A'), 1);
    if isempty(iA), iA = 1; end
    assert(any(abs(fits - trueA) < 0.5), ...
        sprintf('fitted A=%.3f far from true %.2f', fits(iA), trueA));
    fprintf('  PASS: R2=%.4f, fitted=[%s], true=[%.2f, %.2f, %.2f]\n', ...
        res.R2, sprintf('%.3f ', fits), trueA, trueMu, trueSigma);
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  CUSTOM EQUATION
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- setCustomEquation parses and fits user equation ---\n');
try
    x = linspace(0, 10, 100)';
    trueA = 2.5;  trueK = 0.8;
    y = trueA .* exp(-trueK .* x) + 0.05 * randn(size(x));

    m = bosonPlotter.curveFit.CurveFitWorkshopModel();
    m.setCustomEquation('A * exp(-k * x)');
    assert(strcmp(m.modelName, 'Custom Equation'), 'modelName updated');
    assert(numel(m.params) == 2, sprintf('expected 2 params; got %d', numel(m.params)));

    m.params(1).p0 = 1;  % A
    m.params(2).p0 = 0.5;  % k
    res = m.fit(x, y);
    assert(res.R2 > 0.95, sprintf('R2 should be high; got %.4f', res.R2));
    fprintf('  PASS: custom A*exp(-k*x), R2=%.4f, fitted=[%.3f, %.3f]\n', ...
        res.R2, m.params(1).fitted, m.params(2).fitted);
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  PARAMVECTORS — extracts vectors from struct array
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- paramVectors returns ordered numeric vectors ---\n');
try
    m = bosonPlotter.curveFit.CurveFitWorkshopModel();
    m.selectModel('Gaussian');
    m.params(1).p0 = 5;
    m.params(2).lb = -10;
    m.params(2).ub = 10;
    m.params(3).fixed = true;
    [p0, lb, ub, fixed, ~] = m.paramVectors();
    assert(numel(p0) == numel(m.params), 'p0 length matches params');
    assert(p0(1) == 5, 'p0(1) reads from struct');
    assert(lb(2) == -10 && ub(2) == 10, 'bounds extract');
    assert(fixed(3) == true, 'fixed extracts');
    fprintf('  PASS: paramVectors round-trips struct array → numeric vectors\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  REGRESSION — normalizeParamArray upgrades legacy 6-field input
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- normalizeParamArray on legacy 6-field input ---\n');
try
    % Simulate a session-saved param array missing fitted/fittedErr
    legacy = struct('name',{'A','mu'}, 'p0',{1,0}, 'lb',{-Inf,-Inf}, ...
        'ub',{Inf,Inf}, 'fixed',{false,false}, 'constraint',{'',''});
    upgraded = bosonPlotter.curveFit.CurveFitWorkshopModel.normalizeParamArray(legacy);
    assert(isfield(upgraded, 'fitted') && isfield(upgraded, 'fittedErr'), ...
        'must add fitted + fittedErr');
    assert(numel(upgraded) == 2, 'preserves length');
    assert(strcmp(upgraded(1).name, 'A'), 'preserves existing fields');
    fprintf('  PASS: legacy 6-field → canonical 8-field (n=%d)\n', numel(upgraded));
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════
fprintf('\n=== test_curveFitWorkshopModel: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_curveFitWorkshopModel:failed', '%d test(s) failed', failed);
end
