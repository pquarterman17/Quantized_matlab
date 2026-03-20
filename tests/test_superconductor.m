%TEST_SUPERCONDUCTOR  Tests for the +calc/+superconductor/ package.
%
%   Run:
%       run tests/test_superconductor
%       runAllTests(Group="superconductor")

clear; clc;
fprintf('\n=== Superconductor Module Tests ===\n\n');

ROOT = fileparts(fileparts(mfilename('fullpath')));
addpath(ROOT);

passed = 0;
failed = 0;

% ── materialPresets ──────────────────────────────────────────────────
fprintf('--- materialPresets ---\n');

try
    p = calc.superconductor.materialPresets();
    mats = {'Nb','NbN','YBCO','MgB2','Al','Pb','In','Sn'};
    allOk = true;
    for mi = 1:numel(mats)
        if ~isfield(p, mats{mi})
            fprintf('  FAIL: missing preset: %s\n', mats{mi});
            allOk = false;
        end
    end
    if allOk
        % Spot-check Nb
        ok = abs(p.Nb.Tc - 9.25) < 0.1 && ...
             abs(p.Nb.lambda0 - 39) < 5 && ...
             abs(p.Nb.xi0 - 38) < 5;
        if ok
            fprintf('  PASS: 8 presets loaded, Nb spot-check OK\n');
            passed = passed + 1;
        else
            fprintf('  FAIL: Nb preset values wrong\n');
            failed = failed + 1;
        end
    else
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: materialPresets — %s\n', ME.message);
    failed = failed + 1;
end

% ── londonDepth ──────────────────────────────────────────────────────
fprintf('--- londonDepth ---\n');

try
    % Nb at 4.2 K: lambda should be close to lambda0 since T << Tc
    r = calc.superconductor.londonDepth(lambda0=39, T=4.2, Tc=9.25);
    if r.lambda > 39 && r.lambda < 50 && isfield(r, 'latex')
        fprintf('  PASS: londonDepth(Nb, 4.2K) = %.2f nm\n', r.lambda);
        passed = passed + 1;
    else
        fprintf('  FAIL: londonDepth(Nb, 4.2K) = %.2f nm, expected 39-50\n', r.lambda);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: londonDepth — %s\n', ME.message);
    failed = failed + 1;
end

try
    % At T=0, lambda should equal lambda0
    r = calc.superconductor.londonDepth(lambda0=39, T=0, Tc=9.25);
    if abs(r.lambda - 39) < 0.01
        fprintf('  PASS: londonDepth(T=0) = lambda0\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: londonDepth(T=0) = %.3f, expected 39\n', r.lambda);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: londonDepth(T=0) — %s\n', ME.message);
    failed = failed + 1;
end

try
    % At T→Tc, lambda should diverge
    r = calc.superconductor.londonDepth(lambda0=39, T=9.2, Tc=9.25);
    if r.lambda > 200
        fprintf('  PASS: londonDepth near Tc diverges (%.1f nm)\n', r.lambda);
        passed = passed + 1;
    else
        fprintf('  FAIL: londonDepth near Tc = %.1f, expected divergent\n', r.lambda);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: londonDepth near Tc — %s\n', ME.message);
    failed = failed + 1;
end

% ── coherenceLength ──────────────────────────────────────────────────
fprintf('--- coherenceLength ---\n');

try
    r = calc.superconductor.coherenceLength(xi0=38, T=4.2, Tc=9.25);
    if r.xi > 38 && r.xi < 60 && isfield(r, 'latex')
        fprintf('  PASS: coherenceLength(Nb, 4.2K) = %.2f nm\n', r.xi);
        passed = passed + 1;
    else
        fprintf('  FAIL: coherenceLength(Nb, 4.2K) = %.2f, expected 38-60\n', r.xi);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: coherenceLength — %s\n', ME.message);
    failed = failed + 1;
end

% ── glParameter ──────────────────────────────────────────────────────
fprintf('--- glParameter ---\n');

try
    % Nb: kappa ≈ 39/38 ≈ 1.03 → Type II (barely)
    r = calc.superconductor.glParameter(lambda=39, xi=38);
    if abs(r.kappa - 39/38) < 0.01 && isfield(r, 'type') && isfield(r, 'latex')
        fprintf('  PASS: GL(Nb) kappa = %.3f, type %s\n', r.kappa, r.type);
        passed = passed + 1;
    else
        fprintf('  FAIL: GL(Nb) kappa = %.3f\n', r.kappa);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: glParameter — %s\n', ME.message);
    failed = failed + 1;
end

try
    % Al: kappa ≈ 16/1600 = 0.01 → Type I
    r = calc.superconductor.glParameter(lambda=16, xi=1600);
    if r.kappa < 1/sqrt(2) && strcmp(r.type, 'I')
        fprintf('  PASS: GL(Al) kappa = %.4f, type I\n', r.kappa);
        passed = passed + 1;
    else
        fprintf('  FAIL: GL(Al) type = %s, kappa = %.4f\n', r.type, r.kappa);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: glParameter(Al) — %s\n', ME.message);
    failed = failed + 1;
end

% ── criticalFields ───────────────────────────────────────────────────
fprintf('--- criticalFields ---\n');

try
    r = calc.superconductor.criticalFields(Hc0=1980, Tc=9.25, T=4.2);
    % Hc(4.2) = Hc0 * (1 - (4.2/9.25)^2) ≈ 1980 * 0.794 ≈ 1572
    if abs(r.Hc - 1572) < 50 && isfield(r, 'latex')
        fprintf('  PASS: Hc(Nb, 4.2K) = %.1f Oe\n', r.Hc);
        passed = passed + 1;
    else
        fprintf('  FAIL: Hc(Nb, 4.2K) = %.1f, expected ~1572\n', r.Hc);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: criticalFields — %s\n', ME.message);
    failed = failed + 1;
end

try
    % At T=0, Hc = Hc0
    r = calc.superconductor.criticalFields(Hc0=1980, Tc=9.25, T=0);
    if abs(r.Hc - 1980) < 1
        fprintf('  PASS: Hc(T=0) = Hc0 = %.1f Oe\n', r.Hc);
        passed = passed + 1;
    else
        fprintf('  FAIL: Hc(T=0) = %.1f, expected 1980\n', r.Hc);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: criticalFields(T=0) — %s\n', ME.message);
    failed = failed + 1;
end

% ── depairingCurrent ─────────────────────────────────────────────────
fprintf('--- depairingCurrent ---\n');

try
    r = calc.superconductor.depairingCurrent(Hc0=1980, lambda0=39, Tc=9.25, T=4.2);
    % Jd should be on the order of MA/cm² for Nb
    if r.Jd > 1e6 && isfield(r, 'latex')
        fprintf('  PASS: Jd(Nb, 4.2K) = %.2e A/cm² = %.2f MA/cm²\n', r.Jd, r.JdMA);
        passed = passed + 1;
    else
        fprintf('  FAIL: Jd(Nb, 4.2K) = %.2e, expected > 1e6\n', r.Jd);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: depairingCurrent — %s\n', ME.message);
    failed = failed + 1;
end

% ── LaTeX fields ─────────────────────────────────────────────────────
fprintf('--- LaTeX field check ---\n');

latexTests = {
    @() calc.superconductor.londonDepth(lambda0=39, T=4.2, Tc=9.25), 'londonDepth'
    @() calc.superconductor.coherenceLength(xi0=38, T=4.2, Tc=9.25), 'coherenceLength'
    @() calc.superconductor.glParameter(lambda=39, xi=38), 'glParameter'
    @() calc.superconductor.criticalFields(Hc0=1980, Tc=9.25, T=4.2), 'criticalFields'
};

for ti = 1:size(latexTests, 1)
    try
        r = latexTests{ti,1}();
        if isfield(r, 'latex') && ischar(r.latex) && ~isempty(r.latex)
            fprintf('  PASS: %s has .latex\n', latexTests{ti,2});
            passed = passed + 1;
        else
            fprintf('  FAIL: %s missing or empty .latex\n', latexTests{ti,2});
            failed = failed + 1;
        end
    catch ME
        fprintf('  FAIL: %s latex check — %s\n', latexTests{ti,2}, ME.message);
        failed = failed + 1;
    end
end

% ── SUMMARY ──────────────────────────────────────────────────────────
fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_superconductor:failures', '%d test(s) FAILED', failed);
end
