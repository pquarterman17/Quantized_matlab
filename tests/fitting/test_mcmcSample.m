%TEST_MCMCSAMPLE  Basic sanity checks for fitting.mcmcSample scaffold.
%
%   TODO: this is a scaffold test — once the sampler is upgraded from
%   random-walk Metropolis to affine-invariant, extend with:
%     - R-hat convergence test across multiple chains
%     - Autocorrelation / ESS assertions
%     - Corner-plot visual regression (hash of rendered figure)
%     - Reflectivity-fit integration test (parrattRefl + real R(Q) data)
%
%   Run:
%       run tests/fitting/test_mcmcSample
%       runAllTests(Group="fitting")

clear; clc;
fprintf('\n=== MCMC sampler scaffold tests ===\n\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(ROOT);

passed = 0;
failed = 0;

% ────────────────────────────────────────────────────────────────────
%  1. Tight Gaussian posterior — sampler should recover the mean.
% ────────────────────────────────────────────────────────────────────
fprintf('--- 1D Gaussian likelihood ---\n');
try
    mu_true  = 2.5;
    sig_true = 1.2;
    rng(42);
    x    = mu_true + sig_true * randn(500, 1);
    lp   = @(p) -0.5 * sum((x - p(1)).^2) / p(2)^2 ...
                - 500 * log(max(p(2), 1e-6)) ...   % normalization
                - 0.5 * p(1)^2 / 100^2 ...          % loose prior on mu
                - 2 * log(max(p(2), 1e-6));         % log-normal-ish prior on sigma
    r = fitting.mcmcSample(lp, [0, 1], NumSteps=8000, BurnIn=2000, ...
                           StepSize=0.1, Seed=1);

    mu_est  = mean(r.samples(:, 1));
    sig_est = mean(r.samples(:, 2));

    if abs(mu_est - mu_true) < 0.25 && abs(sig_est - sig_true) < 0.25
        fprintf('  PASS: recovered mu=%.3f (true %.3f), sigma=%.3f (true %.3f)\n', ...
            mu_est, mu_true, sig_est, sig_true);
        passed = passed + 1;
    else
        fprintf('  FAIL: mu_est=%.3f, sig_est=%.3f vs true (%.3f, %.3f)\n', ...
            mu_est, sig_est, mu_true, sig_true);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: mcmcSample threw: %s\n', ME.message);
    failed = failed + 1;
end

% ────────────────────────────────────────────────────────────────────
%  2. Acceptance rate in a reasonable range for the tuned step size.
% ────────────────────────────────────────────────────────────────────
fprintf('\n--- Acceptance rate ---\n');
try
    lp = @(p) -0.5 * sum(p.^2);   % standard normal
    r  = fitting.mcmcSample(lp, [0, 0], NumSteps=5000, BurnIn=500, ...
                            StepSize=1.0, Seed=2);
    if r.acceptRate > 0.15 && r.acceptRate < 0.75
        fprintf('  PASS: acceptance rate %.2f in [0.15, 0.75]\n', r.acceptRate);
        passed = passed + 1;
    else
        fprintf('  FAIL: acceptance rate %.2f outside [0.15, 0.75]\n', r.acceptRate);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ────────────────────────────────────────────────────────────────────
%  3. Output struct has the right fields
% ────────────────────────────────────────────────────────────────────
fprintf('\n--- Output struct fields ---\n');
try
    lp = @(p) -0.5 * p^2;
    r  = fitting.mcmcSample(lp, 0, NumSteps=500, BurnIn=50, Seed=3);
    required = {'samples', 'logPosterior', 'acceptRate', 'diagnostic'};
    ok = true;
    for fi = 1:numel(required)
        if ~isfield(r, required{fi}), ok = false; end
    end
    if ok && isfield(r.diagnostic, 'sampler')
        fprintf('  PASS: all required fields present, sampler = "%s"\n', ...
            r.diagnostic.sampler);
        passed = passed + 1;
    else
        fprintf('  FAIL: missing output fields\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ────────────────────────────────────────────────────────────────────
%  4. Corner plot runs without error (headless)
% ────────────────────────────────────────────────────────────────────
fprintf('\n--- cornerPlot smoke test ---\n');
try
    samples = randn(500, 3) + [1, -2, 0.5];
    f = figure('Visible', 'off');
    plotting.cornerPlot(samples, Labels={'a','b','c'}, Truth=[1, -2, 0.5], Parent=f);
    close(f);
    fprintf('  PASS: cornerPlot rendered without error\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: cornerPlot threw: %s\n', ME.message);
    failed = failed + 1;
end

% ────────────────────────────────────────────────────────────────────
%  Summary
% ────────────────────────────────────────────────────────────────────
fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_mcmcSample:failures', '%d test(s) failed', failed);
end
