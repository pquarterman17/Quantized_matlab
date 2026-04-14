%TEST_PAWLEYREFINE  Scaffold tests for Pawley refinement (W3 #31).
%
%   TODO: scaffold test. Once the refinement moves from the placeholder
%   grid-search to Levenberg-Marquardt over (cell, profile, bg), extend
%   with:
%     - Recovery of perturbed cell on a synthetic pattern
%     - Profile-width (Cagliotti U/V/W) recovery
%     - Multi-phase refinement
%     - Visual regression on real Si XRDML pattern
%
%   Run:
%       run tests/fitting/test_pawleyRefine

clear; clc;
fprintf('\n=== Pawley refinement scaffold tests ===\n\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(ROOT);

passed = 0;
failed = 0;

% ────────────────────────────────────────────────────────────────────
%  1. Synthetic silicon pattern — refined cell should recover a ≈ 5.43 Å
% ────────────────────────────────────────────────────────────────────
fprintf('--- Synthetic cubic Si pattern ---\n');
try
    % Ground truth
    a_true = 5.4307;
    lambda = 1.5406;   % Cu Kα1

    phaseTrue = struct('a',a_true,'b',a_true,'c',a_true, ...
                       'alpha',90,'beta',90,'gamma',90, ...
                       'symmetry','F', 'hklMax',5);

    % Generate synthetic observed pattern with a known lattice
    ps = calc.crystal.planeSpacings(a_true, ...
        'Centering','F','MaxHKL',5,'Lambda',lambda);
    peaks2t = ps.twoTheta(~isnan(ps.twoTheta) & ps.twoTheta > 15 & ps.twoTheta < 120);
    mult    = ps.multiplicity(~isnan(ps.twoTheta) & ps.twoTheta > 15 & ps.twoTheta < 120);

    tt = linspace(15, 120, 4000)';
    I  = 10 * ones(size(tt));   % small flat background
    for k = 1:numel(peaks2t)
        pv = exp(-0.5 * ((tt - peaks2t(k)) / 0.06).^2) + ...
             0.3 ./ (1 + ((tt - peaks2t(k)) / 0.08).^2);
        I = I + 1000 * mult(k) * pv;
    end
    % Add a little counting noise so the weights don't blow up
    rng(0);
    I = I + sqrt(max(I,1)) .* randn(size(I));

    % Start from a slightly wrong cell (expected to converge back)
    phaseGuess = phaseTrue;
    phaseGuess.a = a_true + 0.05;
    phaseGuess.b = a_true + 0.05;
    phaseGuess.c = a_true + 0.05;

    result = fitting.pawleyRefine(tt, I, phaseGuess, ...
        'Wavelength', lambda, 'MaxTwoTheta', 120, 'MaxIter', 30);

    if abs(result.cell(1) - a_true) < 0.02
        fprintf('  PASS: refined a = %.5f Å (true %.5f, start %.5f)\n', ...
            result.cell(1), a_true, phaseGuess.a);
        passed = passed + 1;
    else
        fprintf('  FAIL: refined a = %.5f Å, true %.5f (tol 0.02)\n', ...
            result.cell(1), a_true);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: pawleyRefine threw: %s\n', ME.message);
    failed = failed + 1;
end

% ────────────────────────────────────────────────────────────────────
%  2. Output struct fields are present
% ────────────────────────────────────────────────────────────────────
fprintf('\n--- Output struct fields ---\n');
try
    phaseInfo = struct('a',5.4307,'b',5.4307,'c',5.4307, ...
                       'alpha',90,'beta',90,'gamma',90, ...
                       'symmetry','F', 'hklMax',4);
    tt = linspace(20, 100, 500)';
    I  = 10 * ones(size(tt));

    result = fitting.pawleyRefine(tt, I, phaseInfo, ...
        'Wavelength', 1.5406, 'MaxIter', 2, 'RefineCell', false);

    required = {'cell','cellInitial','peaks','background','model', ...
                'residual','rwp','nPeaks'};
    ok = true;
    for fi = 1:numel(required)
        if ~isfield(result, required{fi}), ok = false; end
    end
    if ok
        fprintf('  PASS: all required output fields present (nPeaks=%d)\n', result.nPeaks);
        passed = passed + 1;
    else
        fprintf('  FAIL: missing fields\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ────────────────────────────────────────────────────────────────────
%  3. Size-mismatch input is rejected
% ────────────────────────────────────────────────────────────────────
fprintf('\n--- Size mismatch ---\n');
try
    phaseInfo = struct('a',5,'b',5,'c',5,'alpha',90,'beta',90,'gamma',90, ...
                       'symmetry','P','hklMax',3);
    fitting.pawleyRefine((1:50)', (1:40)', phaseInfo);
    fprintf('  FAIL: size mismatch not caught\n'); failed = failed + 1;
catch ME
    if contains(ME.identifier, 'sizeMismatch')
        fprintf('  PASS: size mismatch rejected\n'); passed = passed + 1;
    else
        fprintf('  FAIL: wrong error id: %s\n', ME.identifier); failed = failed + 1;
    end
end

% ────────────────────────────────────────────────────────────────────
%  Summary
% ────────────────────────────────────────────────────────────────────
fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_pawleyRefine:failures', '%d test(s) failed', failed);
end
