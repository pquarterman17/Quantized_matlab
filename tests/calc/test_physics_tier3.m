%TEST_PHYSICS_TIER3  Tests for Tier-3 physics analysis functions.
%
%   Items tested:
%     11 — calc.superconductor.bcsGap
%     12 — fitting.models Debye, Einstein, Debye+Einstein
%     13 — calc.magnetic.forcDiagram
%     14 — calc.magnetic.kissinger
%     15 — utilities.compareRelaxation
%
%   Run:
%       run tests/calc/test_physics_tier3
%       runAllTests(Group="physics3")

clear; clc;
fprintf('\n=== Physics Tier-3 Module Tests ===\n\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(ROOT);

passed = 0;
failed = 0;

kB_eV  = 8.617333e-5;   % eV/K
kB_meV = kB_eV * 1e3;   % meV/K
R_gas  = 8.314;          % J/(mol·K)

% ════════════════════════════════════════════════════════════════════════
% Item 11: BCS gap
% ════════════════════════════════════════════════════════════════════════
fprintf('--- bcsGap ---\n');

Tc_nb  = 9.25;   % K  (Niobium)
D0_nb  = 1.55;   % meV  => 2*D0/(kB*Tc) = 2*1.55/(kB_meV*9.25)
ratio_expected = 2 * D0_nb / (kB_meV * Tc_nb);

% Synthetic gap data from the BCS tanh approximation
T_data = linspace(0.5, Tc_nb * 0.98, 60)';
D_data = D0_nb * tanh(1.74 * sqrt(max(Tc_nb ./ T_data - 1, 0)));
D_data = D_data + 0.005 * randn(size(D_data)) * D0_nb;   % small noise

try
    r = calc.superconductor.bcsGap(T_data, D_data, Tc=Tc_nb);
    ratioOk = abs(r.ratio - ratio_expected) / ratio_expected < 0.05;   % 5%
    d0Ok    = abs(r.Delta0 - D0_nb) / D0_nb < 0.10;
    tcOk    = abs(r.Tc - Tc_nb) < 0.01;
    curveOk = isfield(r, 'fitCurve') && isfield(r.fitCurve, 'T') && ...
              isfield(r.fitCurve, 'Delta') && numel(r.fitCurve.T) > 10;

    if ratioOk && d0Ok && tcOk && curveOk
        fprintf('  PASS: bcsGap ratio=%.3f (expected %.3f, BCS=3.528), Delta0=%.3f meV\n', ...
            r.ratio, ratio_expected, r.Delta0);
        passed = passed + 1;
    else
        fprintf('  FAIL: bcsGap ratio=%.3f exp=%.3f, Delta0=%.3f exp=%.3f, Tc=%.3f\n', ...
            r.ratio, ratio_expected, r.Delta0, D0_nb, r.Tc);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: bcsGap — %s\n', ME.message);
    failed = failed + 1;
end

% Weak-coupling: ratio should be close to 3.528 for ideal tanh data (no noise)
try
    D0_ideal = 1.76 * kB_meV * Tc_nb;   % exact weak-coupling: 2*D0/(kB*Tc) = 3.528 => D0=1.76*kB*Tc
    T_ideal  = linspace(0.1, Tc_nb * 0.99, 100)';
    D_ideal  = D0_ideal * tanh(1.74 * sqrt(max(Tc_nb ./ T_ideal - 1, 0)));
    r2 = calc.superconductor.bcsGap(T_ideal, D_ideal, Tc=Tc_nb);
    if abs(r2.ratio - 3.528) < 0.05
        fprintf('  PASS: bcsGap weak-coupling ratio = %.4f (expected 3.528)\n', r2.ratio);
        passed = passed + 1;
    else
        fprintf('  FAIL: bcsGap weak-coupling ratio = %.4f (expected ~3.528)\n', r2.ratio);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: bcsGap weak-coupling — %s\n', ME.message);
    failed = failed + 1;
end

% Penetration depth mode
try
    lam0 = 39;  % nm (Nb)
    T_lam = linspace(0.1, Tc_nb * 0.95, 60)';
    lam_data = lam0 ./ sqrt(max(1 - (T_lam / Tc_nb).^4, eps));
    r3 = calc.superconductor.bcsGap(T_lam, lam_data, Tc=Tc_nb, InputType='penetration_depth');
    lam0_fit = r3.fitCurve.lambda(1);
    if abs(lam0_fit - lam0) / lam0 < 0.05 && isnan(r3.Delta0)
        fprintf('  PASS: bcsGap penetration_depth mode, lambda0 = %.1f nm\n', lam0_fit);
        passed = passed + 1;
    else
        fprintf('  FAIL: bcsGap penetration_depth: lam0=%.1f (expected %.1f)\n', lam0_fit, lam0);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: bcsGap penetration_depth — %s\n', ME.message);
    failed = failed + 1;
end

% Edge: too few points should error
try
    calc.superconductor.bcsGap([1;2;3], [1;2;3]);
    fprintf('  FAIL: bcsGap too-few-points — should have errored\n');
    failed = failed + 1;
catch
    fprintf('  PASS: bcsGap rejects < 4 points\n');
    passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% Item 12: Debye and Einstein models in fitting.models()
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- Debye / Einstein heat capacity models ---\n');

try
    cat = fitting.models();
    names = {cat.name};
    hasDebye    = any(strcmp(names, 'Debye'));
    hasEinstein = any(strcmp(names, 'Einstein'));
    hasCombined = any(strcmp(names, 'Debye+Einstein'));
    if hasDebye && hasEinstein && hasCombined
        fprintf('  PASS: Debye, Einstein, Debye+Einstein models registered in catalog\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: Missing models — Debye:%d Einstein:%d Combined:%d\n', ...
            hasDebye, hasEinstein, hasCombined);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: fitting.models() — %s\n', ME.message);
    failed = failed + 1;
end

% Debye high-T limit: C -> 3*n*R (Dulong-Petit) + gamma*T
try
    cat = fitting.models();
    idx = strcmp({cat.name}, 'Debye');
    m = cat(idx);
    % Parameters: [gamma=0, thetaD=300, n=1]
    % At T=3000 K >> thetaD, C -> 0 + 1 * 3*R * 1000 mJ/(mol*K) = 24942
    gamma = 0; thetaD = 300; n = 1;
    R = 8.314;
    C_highT = m.fcn(3000, [gamma, thetaD, n]);
    C_limit = 3 * n * R * 1000;   % mJ/(mol*K) Dulong-Petit
    if abs(C_highT - C_limit) / C_limit < 0.02
        fprintf('  PASS: Debye high-T limit = %.1f mJ/(mol*K) (Dulong-Petit = %.1f)\n', ...
            C_highT, C_limit);
        passed = passed + 1;
    else
        fprintf('  FAIL: Debye high-T: got %.1f, expected %.1f\n', C_highT, C_limit);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: Debye high-T limit — %s\n', ME.message);
    failed = failed + 1;
end

% Debye low-T limit: C -> gamma*T (electronic linear term dominates)
try
    cat = fitting.models();
    idx = strcmp({cat.name}, 'Debye');
    m = cat(idx);
    gamma = 5; thetaD = 300; n = 1;
    T_lo  = 0.5;   % K << thetaD
    C_lo  = m.fcn(T_lo, [gamma, thetaD, n]);
    % At T=0.5 K, lattice Debye C ~ 9*R*(T/thetaD)^3*integral << gamma*T
    C_elec = gamma * T_lo;   % mJ/(mol*K)
    % Should be close to electronic term (lattice negligible at T=0.5, thetaD=300)
    latticeFrac = (C_lo - C_elec) / max(C_elec, eps);
    if latticeFrac >= 0 && latticeFrac < 0.1
        fprintf('  PASS: Debye low-T dominated by gamma*T (lattice = %.2f%% correction)\n', ...
            latticeFrac * 100);
        passed = passed + 1;
    else
        fprintf('  FAIL: Debye low-T: C=%.4f, elec=%.4f, frac=%.3f\n', ...
            C_lo, C_elec, latticeFrac);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: Debye low-T limit — %s\n', ME.message);
    failed = failed + 1;
end

% Einstein high-T limit: C -> 3*n*R (Dulong-Petit)
try
    cat = fitting.models();
    idx = strcmp({cat.name}, 'Einstein');
    m = cat(idx);
    gamma = 0; thetaE = 200; n = 1;
    C_highT = m.fcn(5000, [gamma, thetaE, n]);
    C_limit = 3 * n * R_gas * 1000;
    if abs(C_highT - C_limit) / C_limit < 0.02
        fprintf('  PASS: Einstein high-T limit = %.1f mJ/(mol*K) (Dulong-Petit = %.1f)\n', ...
            C_highT, C_limit);
        passed = passed + 1;
    else
        fprintf('  FAIL: Einstein high-T: got %.1f, expected %.1f\n', C_highT, C_limit);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: Einstein high-T limit — %s\n', ME.message);
    failed = failed + 1;
end

% Combined model evaluates without error and is vectorised
try
    cat = fitting.models();
    idx = strcmp({cat.name}, 'Debye+Einstein');
    m = cat(idx);
    T_vec = (10:10:300)';
    p_comb = [5, 250, 0.8, 150, 0.2];
    C_comb = m.fcn(T_vec, p_comb);
    if numel(C_comb) == numel(T_vec) && all(C_comb >= 0)
        fprintf('  PASS: Debye+Einstein model evaluates on %d-point vector\n', numel(T_vec));
        passed = passed + 1;
    else
        fprintf('  FAIL: Debye+Einstein output size/sign wrong\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: Debye+Einstein model — %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% Item 13: FORC diagram
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- forcDiagram ---\n');

% Synthetic single-domain data: Stoner-Wohlfarth-like with Hc0 = 500 Oe
try
    Hc0 = 500;   % Oe  — expected peak location
    Hk  = 50;    % Oe  — switching width
    n_forc = 25;
    Ha = linspace(-900, -100, n_forc)';
    Q  = 150;
    Hb = repmat(linspace(-1000, 1000, Q), n_forc, 1);
    M  = zeros(n_forc, Q);
    for k = 1:n_forc
        % Simple tanh hysteresis loop offset by Ha(k)
        Heff = Hb(k,:) - sign(Hb(k,:)) * Hc0;
        M(k,:) = tanh(Heff / Hk);
    end

    r = calc.magnetic.forcDiagram(Ha, Hb, M, SmoothingFactor=2, GridPoints=80);

    % Output fields
    hasFields = isfield(r, 'Hc') && isfield(r, 'Hu') && ...
                isfield(r, 'rho') && isfield(r, 'contourLevels');
    sizeOk = numel(r.Hc) == 80 && numel(r.Hu) == 80;
    rhoOk  = isequal(size(r.rho), [80, 80]);
    lvlOk  = numel(r.contourLevels) == 10;

    if hasFields && sizeOk && rhoOk && lvlOk
        fprintf('  PASS: forcDiagram output struct and grid sizes correct\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: forcDiagram field/size check: fields=%d sz=%d rho=%d lvl=%d\n', ...
            hasFields, sizeOk, rhoOk, lvlOk);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: forcDiagram basic — %s\n', ME.message);
    failed = failed + 1;
end

% FORC distribution should have its peak near Hc=Hc0, Hu=0
try
    [~, iMax] = max(r.rho(:));
    [row, col] = ind2sub(size(r.rho), iMax);
    Hc_peak = r.Hc(col);
    Hu_peak = r.Hu(row);
    Hc_tol  = Hc0 * 0.50;  % within 50% (smoothing shifts peak)
    Hu_tol  = 300;           % interaction field near 0
    if abs(Hc_peak - Hc0) < Hc_tol && abs(Hu_peak) < Hu_tol
        fprintf('  PASS: FORC peak at Hc=%.0f Oe (expected ~%d), Hu=%.0f Oe\n', ...
            Hc_peak, Hc0, Hu_peak);
        passed = passed + 1;
    else
        fprintf('  FAIL: FORC peak at Hc=%.0f (expected ~%d), Hu=%.0f (expected ~0)\n', ...
            Hc_peak, Hc0, Hu_peak);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: FORC peak location — %s\n', ME.message);
    failed = failed + 1;
end

% Edge: too few points
try
    calc.magnetic.forcDiagram([1;2;3], [1 2 3;4 5 6;7 8 9], zeros(3,3));
    fprintf('  FAIL: forcDiagram too-few-points — should have errored\n');
    failed = failed + 1;
catch
    fprintf('  PASS: forcDiagram rejects < 4 curves or points\n');
    passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% Item 14: Kissinger analysis
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- kissinger ---\n');

% Construct synthetic data from known Ea
Ea_true_eV  = 1.5;    % eV
Ea_true_Jmol = Ea_true_eV * 1.60218e-19 * 6.02214076e23;  % J/mol
beta_vals = [5; 10; 20; 40];   % K/min

% Kissinger: ln(beta/Tp^2) = -Ea/R * (1/Tp) + const
% Choose Tp values that satisfy this for const = 30 (arbitrary)
const_val = 30;
% ln(beta/Tp^2) = -Ea/(R*Tp) + const  =>  Tp solved numerically
Tp_vals = zeros(4,1);
for ki = 1:4
    b = beta_vals(ki);
    obj = @(Tp) log(b/Tp^2) - (-Ea_true_Jmol/R_gas * 1/Tp + const_val);
    Tp_vals(ki) = fzero(obj, 550);
end

try
    r = calc.magnetic.kissinger(beta_vals, Tp_vals);
    Ea_err = abs(r.Ea_eV - Ea_true_eV) / Ea_true_eV;
    kJerr  = abs(r.Ea_kJmol - Ea_true_Jmol/1e3) / (Ea_true_Jmol/1e3);
    if Ea_err < 0.01 && kJerr < 0.01 && r.R2 > 0.999
        fprintf('  PASS: kissinger Ea=%.4f eV (true=%.4f), R2=%.6f\n', ...
            r.Ea_eV, Ea_true_eV, r.R2);
        passed = passed + 1;
    else
        fprintf('  FAIL: kissinger Ea=%.4f (true=%.4f, err=%.2f%%), R2=%.4f\n', ...
            r.Ea_eV, Ea_true_eV, Ea_err*100, r.R2);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: kissinger — %s\n', ME.message);
    failed = failed + 1;
end

% Check plot data structure
try
    if isfield(r, 'plotData') && isfield(r.plotData, 'x') && ...
       isfield(r.plotData, 'y') && isfield(r.plotData, 'fit') && ...
       numel(r.plotData.x) == 4
        fprintf('  PASS: kissinger plotData fields present and sized correctly\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: kissinger plotData structure incorrect\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: kissinger plotData check — %s\n', ME.message);
    failed = failed + 1;
end

% Edge: too few points
try
    calc.magnetic.kissinger([5;10], [500;520]);
    fprintf('  FAIL: kissinger too-few-points — should have errored\n');
    failed = failed + 1;
catch
    fprintf('  PASS: kissinger rejects < 3 points\n');
    passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% Item 15: Arrhenius / VFT comparison
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- compareRelaxation ---\n');

% Pure Arrhenius data -> Arrhenius preferred
try
    kB = 8.617e-5;
    T_arr = (200:20:500)';
    Ea_arr = 0.4;   % eV
    tau0_arr = 1e-12;
    tau_arr = tau0_arr * exp(Ea_arr ./ (kB * T_arr));
    % Small noise (0.5%)
    rng(0);
    tau_arr = tau_arr .* (1 + 0.005 * randn(size(tau_arr)));

    r = utilities.compareRelaxation(T_arr, tau_arr);
    arrOk   = abs(r.arrhenius.Ea_eV - Ea_arr) / Ea_arr < 0.05;
    prefOk  = strcmp(r.preferred, 'Arrhenius');
    fieldsOk = isfield(r, 'arrhenius') && isfield(r, 'vft') && ...
               isfield(r, 'preferred') && isfield(r, 'deltaAIC') && ...
               isfield(r, 'deltaBIC');

    if arrOk && prefOk && fieldsOk
        fprintf('  PASS: compareRelaxation Arrhenius data -> preferred=Arrhenius, Ea=%.3f eV\n', ...
            r.arrhenius.Ea_eV);
        passed = passed + 1;
    else
        fprintf('  FAIL: Arrhenius data: Ea=%.3f (true=%.3f), preferred=%s\n', ...
            r.arrhenius.Ea_eV, Ea_arr, r.preferred);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: compareRelaxation Arrhenius data — %s\n', ME.message);
    failed = failed + 1;
end

% Pure VFT data -> VFT preferred
try
    T0_vft  = 100;   % K
    Ea_vft  = 0.3;   % eV
    tau0_vft = 1e-13;
    T_vft  = (150:15:450)';
    tau_vft = tau0_vft * exp(Ea_vft ./ (kB * (T_vft - T0_vft)));
    tau_vft = tau_vft .* (1 + 0.005 * randn(size(tau_vft)));

    r2 = utilities.compareRelaxation(T_vft, tau_vft);
    vftPrefOk = strcmp(r2.preferred, 'VFT');
    t0Ok = abs(r2.vft.T0 - T0_vft) < 20;   % within 20 K
    EaOk = abs(r2.vft.Ea_eV - Ea_vft) / Ea_vft < 0.15;

    if vftPrefOk && t0Ok && EaOk
        fprintf('  PASS: compareRelaxation VFT data -> preferred=VFT, T0=%.1f K, Ea=%.3f eV\n', ...
            r2.vft.T0, r2.vft.Ea_eV);
        passed = passed + 1;
    else
        fprintf('  FAIL: VFT data: preferred=%s, T0=%.1f (true=%.1f), Ea=%.3f (true=%.3f)\n', ...
            r2.preferred, r2.vft.T0, T0_vft, r2.vft.Ea_eV, Ea_vft);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: compareRelaxation VFT data — %s\n', ME.message);
    failed = failed + 1;
end

% AIC/BIC signs are consistent with preference
try
    r_vft = utilities.compareRelaxation(T_vft, tau_vft);
    aicSign = (r_vft.deltaAIC > 0) == strcmp(r_vft.preferred, 'VFT');
    bicSign = (r_vft.deltaBIC > 0) == strcmp(r_vft.preferred, 'VFT');
    if aicSign && bicSign
        fprintf('  PASS: deltaAIC=%.2f, deltaBIC=%.2f consistent with preferred=%s\n', ...
            r_vft.deltaAIC, r_vft.deltaBIC, r_vft.preferred);
        passed = passed + 1;
    else
        fprintf('  FAIL: deltaAIC/BIC sign inconsistent with preferred model\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: compareRelaxation AIC/BIC signs — %s\n', ME.message);
    failed = failed + 1;
end

% Edge: too few points
try
    utilities.compareRelaxation([200;250;300;350], [1e-9;2e-9;4e-9;8e-9]);
    fprintf('  FAIL: compareRelaxation too-few-points — should have errored\n');
    failed = failed + 1;
catch
    fprintf('  PASS: compareRelaxation rejects < 5 points\n');
    passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_physics_tier3:failures', '%d test(s) FAILED', failed);
end
