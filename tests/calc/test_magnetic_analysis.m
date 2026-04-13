%TEST_MAGNETIC_ANALYSIS  Tests for Brillouin fitting model, M(T) background
%   subtraction, Curie-Weiss analysis, and Stoner-Wohlfarth model.
%
%   Run:
%     run tests/calc/test_magnetic_analysis

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
    setupToolbox;
end

fprintf('\n=== test_magnetic_analysis ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  Helpers
% ════════════════════════════════════════════════════════════════════════

% Extract the Brillouin model from the catalog
cat   = fitting.models();
brIdx = strcmp({cat.name}, 'Brillouin');
swIdx = strcmp({cat.name}, 'Stoner-Wohlfarth');

% ════════════════════════════════════════════════════════════════════════
%  1. Brillouin J=1/2 reduces to tanh(y)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Brillouin function ---\n');

% For J=1/2: a=(2*0.5+1)/(2*0.5)=2, b=1/(2*0.5)=1
%   B_{1/2}(y) = 2*coth(2y) - coth(y)
% Trigonometric identity: 2*coth(2y) - coth(y) = tanh(y)
y = (-5:0.5:5)';
% Using the catalog model: x=H, p=[Ms, J, g, T]
% For J=1/2: the reduced argument y = g*muB*J*H/(kB*T) is p(3)*5.7884e-5*p(2)*x / (8.617e-5*p(4))
% Set Ms=1, J=0.5, g=2, T=300; vary x to get known y values
% y_arg = g*muB*J*H/(kB*T) = 2*5.7884e-5*0.5*H/(8.617e-5*300)
% => y_arg = H * (2*5.7884e-5*0.5) / (8.617e-5*300) = H * 2.239 (approx)
% Direct test of the brillouin helper by calling the model fcn with known params
brModel = cat(brIdx);
% Choose params so y_arg = x: Ms=1, J=0.5, g=2, T such that scale=1
% scale = g*muB_eV*J / (kB_eV*T) => T = g*muB_eV*J/kB_eV = 2*5.7884e-5*0.5/(8.617e-5)
T_unit = 2 * 5.7884e-5 * 0.5 / 8.617e-5;   % ~0.6716 K
p_half = [1, 0.5, 2, T_unit];
M_brill = brModel.fcn(y, p_half);          % should equal tanh(y)
M_tanh  = tanh(y);
err_half = max(abs(M_brill - M_tanh));
if err_half < 1e-10
    fprintf('  PASS: Brillouin J=1/2 == tanh(y)  (max err %.2e)\n', err_half);
    passed = passed + 1;
else
    fprintf('  FAIL: Brillouin J=1/2 vs tanh(y) (max err %.2e)\n', err_half);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. Brillouin J→∞ approaches Langevin L(y) = coth(y) - 1/y
% ════════════════════════════════════════════════════════════════════════
yL = (0.1:0.2:5)';  % avoid y=0 for Langevin
% Use J=50 (large) as approximation for J→∞
% B_J(y) → coth(y) - 1/y as J→∞ (see Kittel, Introduction to Solid State Physics)
T_unit_large = 50 * 5.7884e-5 * 2 / 8.617e-5;   % scale for J=50
p_large = [1, 50, 2, T_unit_large];
M_large = brModel.fcn(yL, p_large);
% Langevin: L(y) = coth(y) - 1/y
M_lang  = coth(yL) - 1 ./ yL;
err_lang = max(abs(M_large - M_lang));
if err_lang < 0.02    % 2% tolerance; J=50 is close but not exact infinity
    fprintf('  PASS: Brillouin J=50 ~ Langevin (max err %.4f)\n', err_lang);
    passed = passed + 1;
else
    fprintf('  FAIL: Brillouin J=50 vs Langevin (max err %.4f)\n', err_lang);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Brillouin y=0 returns zero (no NaN/Inf)
% ════════════════════════════════════════════════════════════════════════
p_test = [1, 3.5, 2, 300];
M0 = brModel.fcn(0, p_test);
if isfinite(M0) && abs(M0) < 1e-8
    fprintf('  PASS: Brillouin(y=0) = 0  (got %.2e)\n', M0);
    passed = passed + 1;
else
    fprintf('  FAIL: Brillouin(y=0) = %.4g (expected 0)\n', M0);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Brillouin J=7/2 (Gd³⁺): saturation moment = Ms at large y
% ════════════════════════════════════════════════════════════════════════
% B_J(y) → 1 as y → ∞ (saturation), so M → Ms
% At large y_arg the model should give M ≈ Ms
T_gd  = 2 * 5.7884e-5 * 3.5 / 8.617e-5;  % scale to map x→y_arg
p_gd  = [7.94, 3.5, 2, T_gd];             % Ms=7.94 muB/Gd, J=7/2
H_large = 1e5 * ones(1, 1);              % large field -> large y
M_sat = brModel.fcn(H_large, p_gd);
if abs(M_sat - p_gd(1)) / p_gd(1) < 0.001
    fprintf('  PASS: Brillouin J=7/2 saturates to Ms=%.2f at large H\n', p_gd(1));
    passed = passed + 1;
else
    fprintf('  FAIL: Brillouin J=7/2 saturation (got %.4f, expected %.4f)\n', ...
        M_sat, p_gd(1));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. M(T) background subtraction: known linear slope removed exactly
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- subtractMagBackground ---\n');

T_bg  = (10:10:400)';
% Simulate: ferromagnetic signal + linear background.
% Use a fast-decaying signal so M_ferro is negligible (< 1e-6) for T >= 300 K,
% making the linear fit in [300 400] essentially exact.
M_ferro_true = exp(-T_bg / 30);          % e^(-10) ~ 4.5e-5 at T=300
slope_true   = -2e-4;
int_true     = 0.05;
M_meas = M_ferro_true + slope_true .* T_bg + int_true;

% Subtract background using the high-T region where M_ferro ≈ 0
[Mcorr, bgSlope, bgIntercept] = utilities.subtractMagBackground(T_bg, M_meas, ...
    'FitRange', [300 400]);

% At T in [300 400]: M_ferro_true ~ 1e-5 so slope/intercept errors should be tiny
err_slope = abs(bgSlope - slope_true);
err_int   = abs(bgIntercept - int_true);
if err_slope < abs(slope_true) * 0.01 && err_int < abs(int_true) * 0.01
    fprintf('  PASS: background slope/intercept recovered (slope err %.2e, int err %.2e)\n', ...
        err_slope, err_int);
    passed = passed + 1;
else
    fprintf('  FAIL: background recovery (slope err %.2e, int err %.2e)\n', ...
        err_slope, err_int);
    failed = failed + 1;
end

% Corrected signal in the fit region should equal M_ferro_true there
% (tolerance = residual M_ferro at T=300, ~4.5e-5)
residual_highT = max(abs(Mcorr(T_bg >= 300) - M_ferro_true(T_bg >= 300)));
if residual_highT < 1e-3
    fprintf('  PASS: corrected signal matches true signal in fit region (err %.2e)\n', ...
        residual_highT);
    passed = passed + 1;
else
    fprintf('  FAIL: corrected signal in fit region (err %.2e)\n', residual_highT);
    failed = failed + 1;
end

% Auto-fraction mode: uses top 15% of T range = [342 400] — M_ferro negligible there
[~, bgSlope_auto, ~] = utilities.subtractMagBackground(T_bg, M_meas, ...
    'AutoFraction', 0.15);
if abs(bgSlope_auto - slope_true) < abs(slope_true) * 0.05
    fprintf('  PASS: auto-fraction mode recovers slope within 5%%\n');
    passed = passed + 1;
else
    fprintf('  FAIL: auto-fraction mode slope (got %.4e, expected %.4e)\n', ...
        bgSlope_auto, slope_true);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. Curie-Weiss: known C and theta recovered from synthetic 1/chi data
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- curieWeiss ---\n');

C_true     = 3.5;         % Curie constant (emu·K/Oe)
theta_true = 80;          % Weiss temperature (K) — ferromagnetic

T_cw  = (100:5:400)';
chi   = C_true ./ (T_cw - theta_true);

r_cw = calc.magnetic.curieWeiss(T_cw, chi, 'FitRange', [150 400]);

err_theta = abs(r_cw.theta_CW - theta_true);
err_C     = abs(r_cw.C       - C_true);
if err_theta < 0.1 && err_C / C_true < 0.001
    fprintf('  PASS: theta_CW=%.2f K (expected %.1f), C=%.4f (expected %.2f)\n', ...
        r_cw.theta_CW, theta_true, r_cw.C, C_true);
    passed = passed + 1;
else
    fprintf('  FAIL: theta_CW=%.2f (expected %.1f), C=%.4f (expected %.2f)\n', ...
        r_cw.theta_CW, theta_true, r_cw.C, C_true);
    failed = failed + 1;
end

% R² should be essentially 1 for exact synthetic data
if r_cw.R2 > 0.9999
    fprintf('  PASS: Curie-Weiss R² = %.6f\n', r_cw.R2);
    passed = passed + 1;
else
    fprintf('  FAIL: Curie-Weiss R² = %.6f (expected ~1)\n', r_cw.R2);
    failed = failed + 1;
end

% Antiferromagnetic: theta < 0
theta_afm = -50;
chi_afm   = C_true ./ (T_cw - theta_afm);
r_afm     = calc.magnetic.curieWeiss(T_cw, chi_afm, 'FitRange', [100 400]);
if r_afm.theta_CW < 0 && abs(r_afm.theta_CW - theta_afm) < 0.1
    fprintf('  PASS: AFM theta_CW=%.2f K (expected %.1f)\n', ...
        r_afm.theta_CW, theta_afm);
    passed = passed + 1;
else
    fprintf('  FAIL: AFM theta_CW=%.2f (expected %.1f)\n', ...
        r_afm.theta_CW, theta_afm);
    failed = failed + 1;
end

% Auto fit-range test (no FitRange specified)
r_auto = calc.magnetic.curieWeiss(T_cw, chi);
if abs(r_auto.theta_CW - theta_true) < 2
    fprintf('  PASS: Curie-Weiss auto fit-range theta_CW=%.2f K\n', r_auto.theta_CW);
    passed = passed + 1;
else
    fprintf('  FAIL: Curie-Weiss auto fit-range theta_CW=%.2f K (expected ~%.1f)\n', ...
        r_auto.theta_CW, theta_true);
    failed = failed + 1;
end

% Edge: all-zero susceptibility → clear error, no crash
try
    T_bad = (100:5:400)';
    chi_bad = zeros(size(T_bad));
    calc.magnetic.curieWeiss(T_bad, chi_bad);
    fprintf('  FAIL: curieWeiss all-zero chi — should have errored\n');
    failed = failed + 1;
catch ME
    if contains(ME.identifier, 'curieWeiss') || contains(lower(ME.message), 'positive')
        fprintf('  PASS: curieWeiss all-zero chi gives clear error\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: curieWeiss all-zero chi — unexpected error: %s\n', ME.message);
        failed = failed + 1;
    end
end

% Edge: all-negative susceptibility → clear error, no crash
try
    chi_neg = -abs(4 ./ (T_cw - 80));
    calc.magnetic.curieWeiss(T_cw, chi_neg);
    fprintf('  FAIL: curieWeiss all-negative chi — should have errored\n');
    failed = failed + 1;
catch ME
    if contains(ME.identifier, 'curieWeiss') || contains(lower(ME.message), 'positive')
        fprintf('  PASS: curieWeiss all-negative chi gives clear error\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: curieWeiss all-negative chi — unexpected error: %s\n', ME.message);
        failed = failed + 1;
    end
end

% Edge: single data point → tooFewPoints error
try
    calc.magnetic.curieWeiss(200, 0.01);
    fprintf('  FAIL: curieWeiss single point — should have errored\n');
    failed = failed + 1;
catch
    fprintf('  PASS: curieWeiss single point gives error\n');
    passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. Stoner-Wohlfarth: correct Hc and saturation
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Stoner-Wohlfarth model ---\n');

swModel = cat(swIdx);
Ms_sw  = 100;    % emu/g
Hc_sw  = 500;    % Oe — coercive field
Hk_sw  = 2000;   % Oe — anisotropy field (switching sharpness)
p_sw   = [Ms_sw, Hc_sw, Hk_sw];

% At H >> Hc, model should saturate to Ms
H_pos_large = 1e6;
M_pos_sat   = swModel.fcn(H_pos_large, p_sw);
if abs(M_pos_sat - Ms_sw) / Ms_sw < 0.001
    fprintf('  PASS: Stoner-Wohlfarth saturates to +Ms at large +H\n');
    passed = passed + 1;
else
    fprintf('  FAIL: Stoner-Wohlfarth saturation at +H (got %.4f, expected %.4f)\n', ...
        M_pos_sat, Ms_sw);
    failed = failed + 1;
end

M_neg_sat = swModel.fcn(-H_pos_large, p_sw);
if abs(M_neg_sat + Ms_sw) / Ms_sw < 0.001
    fprintf('  PASS: Stoner-Wohlfarth saturates to -Ms at large -H\n');
    passed = passed + 1;
else
    fprintf('  FAIL: Stoner-Wohlfarth saturation at -H (got %.4f, expected %.4f)\n', ...
        M_neg_sat, -Ms_sw);
    failed = failed + 1;
end

% At H = Hc (switching field), tanh argument = 0, so M = 0
M_at_Hc = swModel.fcn(Hc_sw, p_sw);
if abs(M_at_Hc) < 1e-10
    fprintf('  PASS: Stoner-Wohlfarth M(H=Hc) = 0  (got %.2e)\n', M_at_Hc);
    passed = passed + 1;
else
    fprintf('  FAIL: Stoner-Wohlfarth M(H=Hc) = %.4g (expected 0)\n', M_at_Hc);
    failed = failed + 1;
end

% Odd symmetry: M(-H) = -M(H) for the aligned model
H_test = (-2000:100:2000)';
M_test = swModel.fcn(H_test, p_sw);
antisym_err = max(abs(M_test + flipud(M_test)));
if antisym_err < 1e-10
    fprintf('  PASS: Stoner-Wohlfarth antisymmetry M(-H)=-M(H) (err %.2e)\n', antisym_err);
    passed = passed + 1;
else
    fprintf('  FAIL: Stoner-Wohlfarth antisymmetry (err %.2e)\n', antisym_err);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══════════════════════════════════════════\n');
fprintf('  test_magnetic_analysis: %d passed, %d failed\n', passed, failed);
fprintf('══════════════════════════════════════════\n\n');

if failed > 0
    error('test_magnetic_analysis:failures', ...
        '%d test(s) failed in test_magnetic_analysis.', failed);
end
