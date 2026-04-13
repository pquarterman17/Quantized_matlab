%TEST_TRANSPORT_ANALYSIS  Tests for VFT model, Hall analysis, Wiedemann-Franz.
%
%   Run:
%     run tests/calc/test_transport_analysis
%     runAllTests(Group="transport")

clear; clc;
fprintf('\n=== test_transport_analysis ===\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if ~contains(path, ROOT)
    addpath(ROOT);
end

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  VFT MODEL
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- VFT model ---\n');

cat = fitting.models();
idx = strcmp({cat.name}, 'VFT');

% Model exists in catalog
try
    assert(any(idx), 'VFT not found in fitting.models()');
    vft = cat(idx);
    assert(strcmp(vft.category, 'Decay'), 'Category should be Decay');
    assert(numel(vft.p0) == 3, 'VFT should have 3 parameters');
    fprintf('  PASS: VFT model registered in catalog\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: VFT catalog entry — %s\n', ME.message); failed = failed + 1;
end

% VFT reduces to Arrhenius when T0=0
%   tau = tau0 * exp(Ea/(kB*T))  with kB=8.617e-5 eV/K
%   Arrhenius: tau = tau0 * exp(Ea_eV / (kB * T))
try
    vft = cat(idx);
    T   = (100:50:600)';
    tau0  = 1e-12;
    Ea    = 0.3;   % eV
    T0    = 0;
    kB    = 8.617e-5;  % eV/K

    yVFT  = vft.fcn(T, [tau0, Ea, T0]);
    yArr  = tau0 * exp(Ea ./ (kB * T));
    relErr = max(abs(yVFT - yArr) ./ yArr);
    assert(relErr < 1e-10, sprintf('VFT(T0=0) vs Arrhenius: relErr=%.2e', relErr));
    fprintf('  PASS: VFT reduces to Arrhenius when T0=0\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: VFT/Arrhenius equivalence — %s\n', ME.message); failed = failed + 1;
end

% VFT produces expected relaxation times for known parameters
try
    vft   = cat(idx);
    T     = 300;          % K
    tau0  = 1e-10;        % s
    Ea    = 0.05;         % eV
    T0    = 50;           % K
    kB    = 8.617e-5;
    expected = tau0 * exp(Ea / (kB * (T - T0)));
    got      = vft.fcn(T, [tau0, Ea, T0]);
    relErr   = abs(got - expected) / expected;
    assert(relErr < 1e-10, sprintf('VFT single-point relErr=%.2e', relErr));
    fprintf('  PASS: VFT single-point value (T=%g K)\n', T); passed = passed + 1;
catch ME
    fprintf('  FAIL: VFT single-point — %s\n', ME.message); failed = failed + 1;
end

% VFT diverges as T → T0 from above (cannot test exactly, but slope should be very steep)
try
    vft  = cat(idx);
    T0   = 100;
    Ts   = [T0+1, T0+2, T0+5, T0+10];
    vals = vft.fcn(Ts', [1e-10, 0.05, T0]);
    % Values should be monotonically decreasing as T increases above T0
    assert(all(diff(vals) < 0), 'VFT should decrease monotonically above T0');
    fprintf('  PASS: VFT monotonically decreasing above T0\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: VFT monotonicity — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  HALL ANALYSIS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Hall analysis ---\n');

% Synthetic linear R_xy: known slope → correct carrier density
try
    H    = (-5:0.5:5)';           % T
    t    = 0.01;                  % cm thickness (100 um film)
    RH_expected = -2e-4;          % cm³/C (electron-like)
    % slope [Ohm/T] = R_H [cm³/C] / (t [cm] × 1e4)
    slope_OhmPerT = RH_expected / (t * 1e4);
    Rxy  = slope_OhmPerT * H;     % perfect linear, no noise
    r    = calc.electrical.hallAnalysis(H, Rxy, Thickness=t);

    % R_H should match within 1e-6 relative
    assert(abs(r.R_H - RH_expected) / abs(RH_expected) < 1e-6, ...
        sprintf('R_H mismatch: got %.4e, expected %.4e', r.R_H, RH_expected));
    % Carrier density: n = 1/(|R_H|*e)
    C = calc.constants();
    nExpected = 1 / (abs(RH_expected) * C.e);
    assert(abs(r.carrierDensity - nExpected) / nExpected < 1e-6, ...
        sprintf('Carrier density mismatch: got %.4e, expected %.4e', r.carrierDensity, nExpected));
    fprintf('  PASS: Hall R_H and carrier density (synthetic linear data)\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: Hall carrier density — %s\n', ME.message); failed = failed + 1;
end

% Positive slope → holes
try
    H   = (-3:0.5:3)';
    RH_hole = +1e-3;                     % cm³/C (positive → holes)
    Rxy = (RH_hole / 100) * H;
    r   = calc.electrical.hallAnalysis(H, Rxy, Thickness=1e-3);
    assert(strcmp(r.carrierType, 'hole'), ...
        sprintf('Expected hole, got %s', r.carrierType));
    fprintf('  PASS: Positive R_H → holes\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: carrierType hole — %s\n', ME.message); failed = failed + 1;
end

% Negative slope → electrons
try
    H   = (-3:0.5:3)';
    RH_elec = -1e-3;                     % cm³/C (negative → electrons)
    Rxy = (RH_elec / (1e-3 * 1e4)) * H;
    r   = calc.electrical.hallAnalysis(H, Rxy, Thickness=1e-3);
    assert(strcmp(r.carrierType, 'electron'), ...
        sprintf('Expected electron, got %s', r.carrierType));
    fprintf('  PASS: Negative R_H → electrons\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: carrierType electron — %s\n', ME.message); failed = failed + 1;
end

% Hall mobility computed when Sigma is provided
try
    H      = (-5:0.5:5)';
    RH_val = -5e-4;           % cm³/C
    sigma  = 1000;            % S/cm
    Rxy    = (RH_val / (1e-3 * 1e4)) * H;
    r      = calc.electrical.hallAnalysis(H, Rxy, Thickness=1e-3, Sigma=sigma);
    muExpected = abs(RH_val) * sigma;
    assert(abs(r.mobility - muExpected) / muExpected < 1e-6, ...
        sprintf('Mobility mismatch: got %.4e, expected %.4e', r.mobility, muExpected));
    fprintf('  PASS: Hall mobility calculation\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: Hall mobility — %s\n', ME.message); failed = failed + 1;
end

% Oe unit conversion: same data in T vs Oe should give same R_H
try
    H_T  = (-5:0.5:5)';
    H_Oe = H_T * 1e4;                    % 1 T = 1e4 Oe
    RH_ref = -2e-4;
    Rxy  = (RH_ref / (1e-3 * 1e4)) * H_T;
    rT   = calc.electrical.hallAnalysis(H_T,  Rxy, Thickness=1e-3, FieldUnit='T');
    rOe  = calc.electrical.hallAnalysis(H_Oe, Rxy, Thickness=1e-3, FieldUnit='Oe');
    assert(abs(rT.R_H - rOe.R_H) / abs(rT.R_H) < 1e-8, ...
        'T and Oe results should agree');
    fprintf('  PASS: Oe/T unit conversion consistent\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: Oe unit conversion — %s\n', ME.message); failed = failed + 1;
end

% R² = 1 for perfect linear data, < 1 for noisy data
try
    rng(42);
    H     = (-5:0.5:5)';
    Rxy_p = -2e-5 * H;                                        % perfect
    Rxy_n = -2e-5 * H + 1e-5 * randn(size(H));               % noisy
    rP    = calc.electrical.hallAnalysis(H, Rxy_p);
    rN    = calc.electrical.hallAnalysis(H, Rxy_n);
    assert(abs(rP.fitR2 - 1) < 1e-10, 'R²=1 for perfect data');
    assert(rN.fitR2 < 1,              'R²<1 for noisy data');
    fprintf('  PASS: R² quality metric (perfect=1, noisy<1)\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: R² metric — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  WIEDEMANN-FRANZ
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Wiedemann-Franz ---\n');

% Cu at 300 K: ρ ≈ 1.72e-6 Ohm·cm → κ_e = L0*T/ρ ≈ 4.26 W/(cm·K)
try
    L0   = 2.44e-8;
    T    = 300;
    rho  = 1.72e-6;   % Ohm·cm (copper)
    kappa_expected = L0 * T / rho;
    kappa_got      = calc.electrical.wiedemannFranz(T, rho);
    relErr = abs(kappa_got - kappa_expected) / kappa_expected;
    assert(relErr < 1e-10, sprintf('Cu 300K relErr=%.2e', relErr));
    fprintf('  PASS: Cu at 300 K → κ_e = %.3f W/(cm·K)\n', kappa_got); passed = passed + 1;
catch ME
    fprintf('  FAIL: Cu 300 K — %s\n', ME.message); failed = failed + 1;
end

% Vector input: κ_e proportional to T for constant ρ
try
    T    = (100:50:500)';
    rho  = 1e-5;
    kappa = calc.electrical.wiedemannFranz(T, rho);
    assert(numel(kappa) == numel(T), 'Output size mismatch');
    % Check linearity: κ(T2)/κ(T1) = T2/T1
    ratio = kappa(end) / kappa(1);
    expected_ratio = T(end) / T(1);
    assert(abs(ratio - expected_ratio) / expected_ratio < 1e-10, ...
        'κ not proportional to T for constant ρ');
    fprintf('  PASS: κ_e proportional to T for constant ρ\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: Wiedemann-Franz vector — %s\n', ME.message); failed = failed + 1;
end

% Scalar broadcast: single ρ, vector T
try
    T     = (200:100:400)';
    rho   = 2e-6;
    kappa = calc.electrical.wiedemannFranz(T, rho);
    assert(numel(kappa) == numel(T), 'Scalar broadcast failed');
    fprintf('  PASS: Scalar ρ broadcast over vector T\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: Scalar broadcast — %s\n', ME.message); failed = failed + 1;
end

% Higher ρ → lower κ_e (inverse relationship)
try
    T     = 300;
    rho1  = 1e-6;
    rho2  = 1e-4;  % 100× higher
    k1    = calc.electrical.wiedemannFranz(T, rho1);
    k2    = calc.electrical.wiedemannFranz(T, rho2);
    assert(k1 > k2, 'Higher ρ should give lower κ_e');
    assert(abs(k1/k2 - rho2/rho1) < 1e-10, 'κ_e should scale as 1/ρ');
    fprintf('  PASS: κ_e inverse proportional to ρ\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: Wiedemann-Franz inverse-ρ — %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  HALL ANALYSIS — EDGE CASES
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Hall analysis — edge cases ---\n');

% Zero field range → clear error (not silent NaN)
try
    H_flat = ones(10, 1) * 2.5;    % all identical
    Rxy    = randn(10, 1) * 1e-5;
    calc.electrical.hallAnalysis(H_flat, Rxy);
    fprintf('  FAIL: zero-field-range — should have errored\n'); failed = failed + 1;
catch ME
    if contains(ME.identifier, 'zeroFieldRange') || contains(lower(ME.message), 'identical')
        fprintf('  PASS: zero-field-range gives clear error\n'); passed = passed + 1;
    else
        fprintf('  FAIL: zero-field-range — unexpected error: %s\n', ME.message);
        failed = failed + 1;
    end
end

% All-NaN resistance → NaN slope (not a crash)
try
    H_ok   = (-3:0.5:3)';
    Rxy_nan = nan(size(H_ok));
    r_nan = calc.electrical.hallAnalysis(H_ok, Rxy_nan);
    % Result should be NaN (no crash), R2 should be handled
    assert(isnan(r_nan.R_H) || isfinite(r_nan.R_H), ...
        'hallAnalysis should not crash on NaN Rxy');
    fprintf('  PASS: all-NaN Rxy — no crash\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: all-NaN Rxy — crashed: %s\n', ME.message); failed = failed + 1;
end

% Too few points (< 2) → error
try
    calc.electrical.hallAnalysis(1, 0.01);
    fprintf('  FAIL: single-point Hall — should have errored\n'); failed = failed + 1;
catch
    fprintf('  PASS: single-point Hall gives error\n'); passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_transport_analysis: %d test(s) failed.', failed);
end
