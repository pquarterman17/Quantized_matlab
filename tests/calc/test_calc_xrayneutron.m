%TEST_CALC_XRAYNEUTRON  Tests for the +calc/+xrayNeutron/ package.
%
%   Run:
%       run tests/test_calc_xrayneutron
%       runAllTests(Group="xrayneutron")

clear; clc;
fprintf('\n=== X-ray/Neutron Module Tests ===\n\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(ROOT);

passed = 0;
failed = 0;

% ── parseFormula ─────────────────────────────────────────────────────
fprintf('--- parseFormula ---\n');

tests_pf = {
    'Fe2O3',   {'Fe','O'},   [2, 3]
    'SrTiO3',  {'Sr','Ti','O'}, [1, 1, 3]
    'NaCl',    {'Na','Cl'},  [1, 1]
    'H2O',     {'H','O'},    [2, 1]
    'La0.7Sr0.3MnO3', {'La','Sr','Mn','O'}, [0.7, 0.3, 1, 3]
};

for ti = 1:size(tests_pf, 1)
    try
        r = calc.xrayNeutron.parseFormula(tests_pf{ti,1});
        expElem = tests_pf{ti,2};
        expCount = tests_pf{ti,3};
        ok = numel(r.elements) == numel(expElem);
        for ei = 1:numel(expElem)
            ok = ok && strcmp(r.elements{ei}, expElem{ei});
            ok = ok && abs(r.counts(ei) - expCount(ei)) < 1e-6;
        end
        if ok
            fprintf('  PASS: parseFormula(%s)\n', tests_pf{ti,1});
            passed = passed + 1;
        else
            fprintf('  FAIL: parseFormula(%s) — wrong elements/counts\n', tests_pf{ti,1});
            failed = failed + 1;
        end
    catch ME
        fprintf('  FAIL: parseFormula(%s) — %s\n', tests_pf{ti,1}, ME.message);
        failed = failed + 1;
    end
end

% ── molecularWeight ──────────────────────────────────────────────────
fprintf('--- molecularWeight ---\n');

tests_mw = {
    'H2O',    18.015, 0.02
    'NaCl',   58.44,  0.02
    'Fe2O3',  159.69, 0.02
    'SrTiO3', 183.49, 0.1
};

for ti = 1:size(tests_mw, 1)
    try
        r = calc.xrayNeutron.molecularWeight(tests_mw{ti,1});
        if abs(r.M - tests_mw{ti,2}) < tests_mw{ti,3}
            fprintf('  PASS: M(%s) = %.2f\n', tests_mw{ti,1}, r.M);
            passed = passed + 1;
        else
            fprintf('  FAIL: M(%s) = %.4f, expected ~%.2f\n', tests_mw{ti,1}, r.M, tests_mw{ti,2});
            failed = failed + 1;
        end
    catch ME
        fprintf('  FAIL: M(%s) — %s\n', tests_mw{ti,1}, ME.message);
        failed = failed + 1;
    end
end

% ── neutronSLD ───────────────────────────────────────────────────────
fprintf('--- neutronSLD ---\n');

try
    % STO: known SLD ~3.54 × 10^-6 Å^-2
    r = calc.xrayNeutron.neutronSLD('SrTiO3', 5.12);
    if abs(r.SLDe6 - 3.54) < 0.5 && isfield(r, 'latex')
        fprintf('  PASS: neutronSLD(SrTiO3) = %.3f × 10^-6 Å^-2\n', r.SLDe6);
        passed = passed + 1;
    else
        fprintf('  FAIL: neutronSLD(SrTiO3) = %.3f, expected ~3.54\n', r.SLDe6);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: neutronSLD(SrTiO3) — %s\n', ME.message);
    failed = failed + 1;
end

try
    % Si: known SLD ~2.07 × 10^-6 Å^-2
    r = calc.xrayNeutron.neutronSLD('Si', 2.33);
    if abs(r.SLDe6 - 2.07) < 0.2
        fprintf('  PASS: neutronSLD(Si) = %.3f × 10^-6 Å^-2\n', r.SLDe6);
        passed = passed + 1;
    else
        fprintf('  FAIL: neutronSLD(Si) = %.3f, expected ~2.07\n', r.SLDe6);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: neutronSLD(Si) — %s\n', ME.message);
    failed = failed + 1;
end

% ── xraySLD ──────────────────────────────────────────────────────────
fprintf('--- xraySLD ---\n');

try
    r = calc.xrayNeutron.xraySLD('Si', 2.33);
    % Si X-ray SLD ~20 × 10^-6 Å^-2
    if r.SLDe6 > 10 && r.SLDe6 < 30 && isfield(r, 'electronDensity')
        fprintf('  PASS: xraySLD(Si) = %.3f × 10^-6 Å^-2\n', r.SLDe6);
        passed = passed + 1;
    else
        fprintf('  FAIL: xraySLD(Si) = %.3f, expected 10-30\n', r.SLDe6);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: xraySLD(Si) — %s\n', ME.message);
    failed = failed + 1;
end

% ── qToTwoTheta / twoThetaToQ ───────────────────────────────────────
fprintf('--- Q / 2theta conversion ---\n');

try
    r = calc.xrayNeutron.qToTwoTheta(2.0, Lambda=1.5406);
    if r.twoTheta > 0 && r.twoTheta < 180 && isfield(r, 'latex')
        fprintf('  PASS: qToTwoTheta(Q=2) = %.2f deg\n', r.twoTheta);
        passed = passed + 1;
    else
        fprintf('  FAIL: qToTwoTheta(Q=2) — invalid result\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: qToTwoTheta — %s\n', ME.message);
    failed = failed + 1;
end

try
    r = calc.xrayNeutron.twoThetaToQ(45.0, Lambda=1.5406);
    if r.Q > 0 && isfield(r, 'latex')
        fprintf('  PASS: twoThetaToQ(2th=45) = %.4f Å^-1\n', r.Q);
        passed = passed + 1;
    else
        fprintf('  FAIL: twoThetaToQ — invalid result\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: twoThetaToQ — %s\n', ME.message);
    failed = failed + 1;
end

% Round-trip: Q → 2θ → Q
try
    Q0 = 1.5;
    r1 = calc.xrayNeutron.qToTwoTheta(Q0, Lambda=1.5406);
    r2 = calc.xrayNeutron.twoThetaToQ(r1.twoTheta, Lambda=1.5406);
    if abs(r2.Q - Q0) < 1e-6
        fprintf('  PASS: Q round-trip (%.4f → %.2f° → %.4f)\n', Q0, r1.twoTheta, r2.Q);
        passed = passed + 1;
    else
        fprintf('  FAIL: Q round-trip: %.4f → %.4f\n', Q0, r2.Q);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: Q round-trip — %s\n', ME.message);
    failed = failed + 1;
end

% ── braggLaw ─────────────────────────────────────────────────────────
fprintf('--- braggLaw ---\n');

try
    r = calc.xrayNeutron.braggLaw(3.135, Lambda=1.5406);
    if r.twoTheta > 0 && isfield(r, 'Q') && isfield(r, 'latex')
        fprintf('  PASS: braggLaw(d=3.135) → 2θ=%.2f°, Q=%.3f\n', r.twoTheta, r.Q);
        passed = passed + 1;
    else
        fprintf('  FAIL: braggLaw — missing fields\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: braggLaw — %s\n', ME.message);
    failed = failed + 1;
end

% ── weightToAtomicPercent / atomicToWeightPercent ────────────────────
fprintf('--- percent conversions ---\n');

try
    r = calc.xrayNeutron.weightToAtomicPercent({'Fe','O'}, [69.94, 30.06]);
    % Fe2O3: Fe at% = 40%, O at% = 60%
    if abs(r.atomicPct(1) - 40) < 1 && abs(r.atomicPct(2) - 60) < 1
        fprintf('  PASS: wt%%→at%% for Fe2O3\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: wt%%→at%% got [%.1f, %.1f], expected [40, 60]\n', ...
            r.atomicPct(1), r.atomicPct(2));
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: weightToAtomicPercent — %s\n', ME.message);
    failed = failed + 1;
end

try
    r = calc.xrayNeutron.atomicToWeightPercent({'Fe','O'}, [40, 60]);
    if abs(r.weightPct(1) - 69.94) < 1 && abs(r.weightPct(2) - 30.06) < 1
        fprintf('  PASS: at%%→wt%% for Fe2O3\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: at%%→wt%% got [%.1f, %.1f], expected [69.9, 30.1]\n', ...
            r.weightPct(1), r.weightPct(2));
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: atomicToWeightPercent — %s\n', ME.message);
    failed = failed + 1;
end

% ── SUMMARY ──────────────────────────────────────────────────────────
fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_calc_xrayneutron:failures', '%d test(s) FAILED', failed);
end
