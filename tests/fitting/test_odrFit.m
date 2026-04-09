%TEST_ODRFIT  Unit tests for fitting.odrFit — orthogonal distance regression.
%
%   Covers: exact linear recovery, noisy-data tolerance, λ dependence,
%   jackknife errors, OLS comparison when both axes have noise, input
%   validation, and degenerate cases.
%
%   Run:  runAllTests(Group="fitting")
%   Or:   run tests/fitting/test_odrFit

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir); addpath(rootDir); end

fprintf('\n=== test_odrFit ===\n');
passed = 0; failed = 0;

% Fixed RNG so the noisy tests are deterministic
rng(20260409);

% ════════════════════════════════════════════════════════════════════════
% TEST 1: Exact linear recovery (no noise)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 1. Exact linear recovery ──\n');
try
    trueSlope = 2.5; trueIntercept = -1.3;
    x = linspace(0, 10, 25)';
    y = trueSlope * x + trueIntercept;

    r = fitting.odrFit(x, y);
    assert(abs(r.slope     - trueSlope)     < 1e-10, ...
        sprintf('slope: %.12f', r.slope));
    assert(abs(r.intercept - trueIntercept) < 1e-10, ...
        sprintf('intercept: %.12f', r.intercept));
    assert(r.rss < 1e-20, sprintf('rss should be ~0, got %g', r.rss));
    assert(r.n == 25, 'n mismatch');

    fprintf('  [PASS] slope=%.4f intercept=%.4f rss=%.2e\n', ...
        r.slope, r.intercept, r.rss);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 2: Noisy data, λ=1 symmetric — recovers slope within tolerance
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 2. Symmetric noise, λ=1 ──\n');
try
    trueSlope = 1.5; trueIntercept = 0.5;
    n = 200;
    xTrue = linspace(0, 10, n)';
    yTrue = trueSlope * xTrue + trueIntercept;
    sigma = 0.3;
    x = xTrue + sigma * randn(n, 1);
    y = yTrue + sigma * randn(n, 1);

    r = fitting.odrFit(x, y);
    assert(abs(r.slope - trueSlope) < 0.05, ...
        sprintf('slope error > 0.05: %.4f', r.slope));
    assert(r.slopeErr > 0, 'slopeErr must be positive');
    assert(r.interceptErr > 0, 'interceptErr must be positive');
    assert(r.rss > 0, 'rss must be positive on noisy data');
    assert(r.rmse > 0, 'rmse must be positive');

    fprintf('  [PASS] slope=%.4f±%.4f (true %.4f)\n', ...
        r.slope, r.slopeErr, trueSlope);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 3: ODR beats OLS when both axes have equal noise
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 3. ODR vs OLS with symmetric noise ──\n');
try
    trueSlope = 2.0; trueIntercept = 0.0;
    n = 500;
    xTrue = linspace(0, 10, n)';
    yTrue = trueSlope * xTrue + trueIntercept;
    sigma = 0.5;
    x = xTrue + sigma * randn(n, 1);
    y = yTrue + sigma * randn(n, 1);

    rOdr = fitting.odrFit(x, y);

    % Ordinary least squares via utilities.linRegress — coeffs = [b0,b1]
    rOls = utilities.linRegress(x, y);
    olsSlope = rOls.coeffs(2);

    odrErr = abs(rOdr.slope - trueSlope);
    olsErr = abs(olsSlope   - trueSlope);
    assert(odrErr < olsErr, ...
        sprintf('ODR (%.4f) should beat OLS (%.4f) on symmetric noise', ...
        odrErr, olsErr));

    fprintf('  [PASS] ODR slope=%.4f (err %.4f) < OLS slope=%.4f (err %.4f)\n', ...
        rOdr.slope, odrErr, olsSlope, olsErr);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 4: λ → ∞ limit approaches OLS
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 4. λ → ∞ limit recovers OLS ──\n');
try
    n = 50;
    x = linspace(0, 10, n)';
    y = 2*x + 1 + 0.4*randn(n, 1);   % noise in Y only

    rOls   = utilities.linRegress(x, y);
    olsIntercept = rOls.coeffs(1);
    olsSlope     = rOls.coeffs(2);
    rLarge = fitting.odrFit(x, y, 'Lambda', 1e6);
    assert(abs(rLarge.slope     - olsSlope)     < 1e-3, ...
        sprintf('λ=1e6 slope mismatch: %.6f vs %.6f', rLarge.slope, olsSlope));
    assert(abs(rLarge.intercept - olsIntercept) < 1e-3, ...
        'λ=1e6 intercept mismatch');
    assert(rLarge.lambda == 1e6, 'stored lambda mismatch');

    fprintf('  [PASS] λ=1e6 ODR slope=%.6f ≈ OLS slope=%.6f\n', ...
        rLarge.slope, olsSlope);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 5: λ from XError/YError inputs
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 5. λ derived from XError/YError ──\n');
try
    n = 30;
    x = linspace(0, 10, n)';
    y = 3*x - 2 + 0.1*randn(n, 1);
    xe = 0.5 * ones(n, 1);
    ye = 1.0 * ones(n, 1);   % → λ = (1.0/0.5)² = 4

    r = fitting.odrFit(x, y, 'XError', xe, 'YError', ye);
    assert(abs(r.lambda - 4) < 1e-10, ...
        sprintf('lambda should be 4, got %.6f', r.lambda));

    fprintf('  [PASS] λ=%.3f from error ratio\n', r.lambda);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 6: Jackknife errors non-zero on noisy data, zero on exact data
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 6. Jackknife errors ──\n');
try
    % Exact data → both errors ~0
    x = linspace(0, 10, 15)';
    y = 1.2*x + 3.4;
    rExact = fitting.odrFit(x, y);
    assert(rExact.slopeErr     < 1e-10, ...
        sprintf('exact slopeErr must be ~0, got %g', rExact.slopeErr));
    assert(rExact.interceptErr < 1e-10, ...
        sprintf('exact interceptErr must be ~0, got %g', rExact.interceptErr));

    % Noisy data → both errors > 0
    y2 = y + 0.2*randn(15, 1);
    rNoisy = fitting.odrFit(x, y2);
    assert(rNoisy.slopeErr     > 0, 'noisy slopeErr must be positive');
    assert(rNoisy.interceptErr > 0, 'noisy interceptErr must be positive');

    fprintf('  [PASS] exact errs ~0, noisy slopeErr=%.4f interceptErr=%.4f\n', ...
        rNoisy.slopeErr, rNoisy.interceptErr);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 7: Input validation — length mismatch
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 7. Length mismatch rejected ──\n');
try
    try
        fitting.odrFit([1;2;3;4], [1;2;3]);
        fprintf('  [FAIL] should have thrown on length mismatch\n');
        failed = failed + 1;
    catch ME
        assert(contains(ME.identifier, 'sizeMismatch'), ...
            sprintf('wrong error id: %s', ME.identifier));
        fprintf('  [PASS] length mismatch → %s\n', ME.identifier);
        passed = passed + 1;
    end
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 8: Input validation — too few points
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 8. Too few points rejected ──\n');
try
    try
        fitting.odrFit([1;2], [1;2]);
        fprintf('  [FAIL] should have thrown on n<3\n');
        failed = failed + 1;
    catch ME
        assert(contains(ME.identifier, 'tooFewPoints'), ...
            sprintf('wrong error id: %s', ME.identifier));
        fprintf('  [PASS] n<3 → %s\n', ME.identifier);
        passed = passed + 1;
    end
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 9: Degenerate — all y identical (zero correlation)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 9. Degenerate data (no correlation) ──\n');
try
    x = (1:10)';
    y = 5 * ones(10, 1);
    r = fitting.odrFit(x, y);
    assert(r.slope == 0, sprintf('flat data slope should be 0, got %.6f', r.slope));
    assert(abs(r.intercept - 5) < 1e-10, ...
        sprintf('intercept should be 5, got %.6f', r.intercept));
    fprintf('  [PASS] flat data → slope=0 intercept=5\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 10: Struct return has all expected fields
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 10. Return struct contract ──\n');
try
    r = fitting.odrFit((1:10)', (1:10)' + 0.01*randn(10,1));
    expectedFields = {'slope','intercept','slopeErr','interceptErr', ...
        'lambda','rss','rmse','n'};
    actualFields = fieldnames(r);
    missing = setdiff(expectedFields, actualFields);
    extra   = setdiff(actualFields, expectedFields);
    assert(isempty(missing), sprintf('missing fields: %s', strjoin(missing, ',')));
    assert(isempty(extra),   sprintf('extra fields: %s',   strjoin(extra,   ',')));
    fprintf('  [PASS] all 8 expected fields present\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
fprintf('\n%s\n', repmat(char(9552), 1, 72));
fprintf('SUMMARY: %d/%d tests passed\n', passed, passed + failed);
if failed > 0
    error('test_odrFit:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end
