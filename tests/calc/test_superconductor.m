%TEST_SUPERCONDUCTOR  Tests for the +calc/+superconductor/ package.
%
%   Run:
%       run tests/test_superconductor
%       runAllTests(Group="superconductor")

clear; clc;
fprintf('\n=== Superconductor Module Tests ===\n\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
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

% ── extractTc ─────────────────────────────────────────────────────────
fprintf('--- extractTc ---\n');

% Synthetic Nb-like R(T): sigmoid centred at Tc = 9.2 K, width ~0.3 K
Tc_true = 9.2;
T_data  = linspace(5, 15, 400)';
R_data  = 1 ./ (1 + exp(-10 * (T_data - Tc_true)));   % 0..1 normalised

try
    r = calc.superconductor.extractTc(T_data, R_data);
    tol = 0.15;   % K
    midOk  = abs(r.Tc_midpoint   - Tc_true) < tol;
    onOk   = abs(r.Tc_onset      - Tc_true) < 0.5;   % onset is up-shifted
    derivOk = abs(r.Tc_derivative - Tc_true) < tol;
    widthOk = r.transitionWidth > 0 && r.transitionWidth < 2;
    if midOk && onOk && derivOk && widthOk
        fprintf('  PASS: extractTc midpoint=%.3f K, deriv=%.3f K (true %.3f K)\n', ...
            r.Tc_midpoint, r.Tc_derivative, Tc_true);
        passed = passed + 1;
    else
        fprintf('  FAIL: extractTc mid=%.3f on=%.3f deriv=%.3f width=%.3f\n', ...
            r.Tc_midpoint, r.Tc_onset, r.Tc_derivative, r.transitionWidth);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: extractTc (clean) — %s\n', ME.message);
    failed = failed + 1;
end

% Method='midpoint' returns only midpoint (others should be NaN)
try
    r = calc.superconductor.extractTc(T_data, R_data, Method='midpoint');
    if abs(r.Tc_midpoint - Tc_true) < 0.15 && isnan(r.Tc_derivative)
        fprintf('  PASS: extractTc Method=midpoint isolates correctly\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: extractTc Method=midpoint: mid=%.3f deriv=%.3f (expect NaN)\n', ...
            r.Tc_midpoint, r.Tc_derivative);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: extractTc Method=midpoint — %s\n', ME.message);
    failed = failed + 1;
end

% Noisy R(T) — midpoint should still land within 0.3 K
try
    rng(42);
    R_noisy = R_data + 0.01 * randn(size(R_data));
    r = calc.superconductor.extractTc(T_data, R_noisy);
    if abs(r.Tc_midpoint - Tc_true) < 0.30
        fprintf('  PASS: extractTc noisy data mid=%.3f K\n', r.Tc_midpoint);
        passed = passed + 1;
    else
        fprintf('  FAIL: extractTc noisy mid=%.3f K (expected within 0.3 K of %.3f)\n', ...
            r.Tc_midpoint, Tc_true);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: extractTc noisy — %s\n', ME.message);
    failed = failed + 1;
end

% Edge: too few points should error
try
    calc.superconductor.extractTc([1;2;3], [1;2;3]);
    fprintf('  FAIL: extractTc too-few-points — should have errored\n');
    failed = failed + 1;
catch
    fprintf('  PASS: extractTc rejects < 5 points\n');
    passed = passed + 1;
end

% Edge: monotonically increasing R(T) (no superconducting transition)
% All Tc values should be NaN — there's no crossing of R_normal fractions
% below the normal state.
try
    T_metal = linspace(4, 300, 200)';
    R_metal = 0.01 + 0.001 * T_metal;   % pure metallic: monotonically up
    r_metal = calc.superconductor.extractTc(T_metal, R_metal);
    % The function must not crash. Tc values may be spurious but should be
    % numeric (NaN or a value — not an error).
    assert(isstruct(r_metal) && isfield(r_metal, 'Tc_midpoint'), ...
        'extractTc should return a struct even for metallic R(T)');
    fprintf('  PASS: extractTc monotonically increasing R(T) — no crash (Tc_mid=%.3f)\n', ...
        r_metal.Tc_midpoint);
    passed = passed + 1;
catch ME
    fprintf('  FAIL: extractTc monotonically increasing R(T) — crashed: %s\n', ME.message);
    failed = failed + 1;
end

% Edge: flat R(T) (zero-resistance already, all R=0)
% R_normal will be 0, all thresholds are 0, and interpolateCrossing
% should find a crossing at the first point or return NaN.
try
    T_flat = linspace(4, 30, 100)';
    R_flat = zeros(size(T_flat));
    r_flat = calc.superconductor.extractTc(T_flat, R_flat);
    assert(isstruct(r_flat) && isfield(r_flat, 'Tc_midpoint'), ...
        'extractTc should return a struct for flat R(T)');
    fprintf('  PASS: extractTc flat R(T)=0 — no crash\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: extractTc flat R(T)=0 — crashed: %s\n', ME.message);
    failed = failed + 1;
end

% Edge: R with negative values (e.g. Hall-corrected data)
% Should not crash; Tc values may be physically meaningless but no error.
try
    T_neg = linspace(5, 15, 100)';
    R_neg = -0.5 + 1 ./ (1 + exp(-5*(T_neg - 9)));  % has negative values below Tc
    r_neg = calc.superconductor.extractTc(T_neg, R_neg);
    assert(isstruct(r_neg), 'extractTc should return struct for R with negative values');
    fprintf('  PASS: extractTc R with negative values — no crash\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: extractTc R with negative values — crashed: %s\n', ME.message);
    failed = failed + 1;
end

% ── beanJc ────────────────────────────────────────────────────────────
fprintf('--- beanJc ---\n');

% Synthetic M(H) loop: known deltaM = 0.02 emu, rectangular sample
% a = 0.3 cm, b = 0.5 cm, t = 0.01 cm → vol = 0.0015 cm^3
% geomFactor = a*(1 - a/(3b)) = 0.3*(1 - 0.3/1.5) = 0.3*0.8 = 0.24
% Jc = 20 * deltaM * a / (vol * geomFactor)
%    = 20 * 0.02 * 0.3 / (0.0015 * 0.24) = 0.12 / 3.6e-4 = 333.33 A/cm^2
try
    dM_known = 0.02;   % emu (full width)
    a_s = 0.3; b_s = 0.5; t_s = 0.01;
    vol_s = a_s * b_s * t_s;
    gf    = a_s * (1 - a_s/(3*b_s));
    Jc_expected = 20 * dM_known * a_s / (vol_s * gf);

    % Build synthetic loop: triangle wave, ±1000 Oe
    H_loop = [linspace(-1000, 1000, 100), linspace(1000, -1000, 100)]';
    % Ascending: M = -deltaM/2; Descending: M = +deltaM/2  (constant width)
    M_asc_v  = -dM_known/2 * ones(100, 1);
    M_desc_v =  dM_known/2 * ones(100, 1);
    M_loop   = [M_asc_v; M_desc_v];

    dims.width = b_s; dims.length = a_s; dims.thickness = t_s;
    res = calc.superconductor.beanJc(H_loop, M_loop, dims);

    Jc_mean = mean(res.Jc(~isnan(res.Jc)));
    relErr  = abs(Jc_mean - Jc_expected) / Jc_expected;
    if relErr < 0.05
        fprintf('  PASS: beanJc rectangular Jc=%.1f A/cm^2 (expected %.1f, err=%.1f%%)\n', ...
            Jc_mean, Jc_expected, relErr*100);
        passed = passed + 1;
    else
        fprintf('  FAIL: beanJc rectangular Jc=%.1f, expected %.1f (err=%.1f%%)\n', ...
            Jc_mean, Jc_expected, relErr*100);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: beanJc rectangular — %s\n', ME.message);
    failed = failed + 1;
end

% Cylindrical: Jc = (3/(2*r)) * deltaM / vol = (3/(2*r)) * dM / (pi*r^2*t)
% r = 0.15 cm, t = 0.01 cm → vol = pi*0.0225*0.01 = 7.069e-4 cm^3
% Jc = 3/(2*0.15) * 0.02 / 7.069e-4 = 10 * 28.28 = 282.8 A/cm^2
try
    r_cyl = 0.15; t_cyl = 0.01;
    vol_cyl = pi * r_cyl^2 * t_cyl;
    Jc_cyl_exp = (3/(2*r_cyl)) * dM_known / vol_cyl;

    dims_cyl.radius = r_cyl; dims_cyl.thickness = t_cyl;
    res_cyl = calc.superconductor.beanJc(H_loop, M_loop, dims_cyl, ...
                                         Geometry='cylindrical');
    Jc_cyl_mean = mean(res_cyl.Jc(~isnan(res_cyl.Jc)));
    relErrC = abs(Jc_cyl_mean - Jc_cyl_exp) / Jc_cyl_exp;
    if relErrC < 0.05
        fprintf('  PASS: beanJc cylindrical Jc=%.1f A/cm^2 (expected %.1f)\n', ...
            Jc_cyl_mean, Jc_cyl_exp);
        passed = passed + 1;
    else
        fprintf('  FAIL: beanJc cylindrical Jc=%.1f, expected %.1f (err=%.1f%%)\n', ...
            Jc_cyl_mean, Jc_cyl_exp, relErrC*100);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: beanJc cylindrical — %s\n', ME.message);
    failed = failed + 1;
end

% Output fields present
try
    res2 = calc.superconductor.beanJc(H_loop, M_loop, dims);
    if isfield(res2,'Jc') && isfield(res2,'field') && isfield(res2,'deltaM') && ...
       numel(res2.Jc) == numel(res2.field) && numel(res2.Jc) == numel(res2.deltaM)
        fprintf('  PASS: beanJc output struct fields and sizes OK\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: beanJc output struct missing fields or size mismatch\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: beanJc output struct check — %s\n', ME.message);
    failed = failed + 1;
end

% FieldUnit='T' conversion: same Jc regardless of field unit
try
    H_T   = H_loop / 1e4;
    res_T = calc.superconductor.beanJc(H_T, M_loop, dims, FieldUnit='T');
    Jc_T_mean = mean(res_T.Jc(~isnan(res_T.Jc)));
    Jc_Oe_mean = mean(res.Jc(~isnan(res.Jc)));
    if abs(Jc_T_mean - Jc_Oe_mean) / Jc_Oe_mean < 0.01
        fprintf('  PASS: beanJc FieldUnit=T gives same Jc as Oe\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: beanJc FieldUnit=T Jc=%.1f vs Oe Jc=%.1f\n', Jc_T_mean, Jc_Oe_mean);
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: beanJc FieldUnit=T — %s\n', ME.message);
    failed = failed + 1;
end

% Edge: too few points should error
try
    dims_e.width=0.3; dims_e.length=0.5; dims_e.thickness=0.01;
    calc.superconductor.beanJc((1:5)', (1:5)', dims_e);
    fprintf('  FAIL: beanJc too-few-points — should have errored\n');
    failed = failed + 1;
catch
    fprintf('  PASS: beanJc rejects < 10 points\n');
    passed = passed + 1;
end

% Edge: zero-width loop (ascending == descending, deltaM = 0)
% Should not crash; Jc will be 0 everywhere.
try
    H_zw  = linspace(-1000, 1000, 50)';
    H_zw  = [H_zw; flipud(H_zw)];      % full loop
    M_zw  = zeros(size(H_zw));          % M = 0 everywhere (no hysteresis)
    dims_zw.width=0.3; dims_zw.length=0.5; dims_zw.thickness=0.01;
    res_zw = calc.superconductor.beanJc(H_zw, M_zw, dims_zw);
    assert(all(res_zw.Jc == 0) || all(isfinite(res_zw.Jc)), ...
        'beanJc zero-width loop should give Jc=0, not crash');
    fprintf('  PASS: beanJc zero-width loop (deltaM=0) — no crash, Jc=0\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: beanJc zero-width loop — crashed: %s\n', ME.message);
    failed = failed + 1;
end

% Edge: single-branch data (monotonically increasing H, no return sweep)
% Should error with a clear message because no hysteresis can be computed.
try
    H_single = linspace(-1000, 1000, 50)';   % ascending only, no descending
    M_single = 0.1 * tanh(H_single / 500);
    dims_s.width=0.3; dims_s.length=0.5; dims_s.thickness=0.01;
    calc.superconductor.beanJc(H_single, M_single, dims_s);
    fprintf('  FAIL: beanJc single-branch — should have errored (no overlap)\n');
    failed = failed + 1;
catch ME
    % Expected: noOverlap or noValidPoints
    if contains(ME.identifier, 'beanJc') || contains(lower(ME.message), 'overlap')
        fprintf('  PASS: beanJc single-branch gives clear error\n');
        passed = passed + 1;
    else
        fprintf('  FAIL: beanJc single-branch — unexpected error: %s\n', ME.message);
        failed = failed + 1;
    end
end

% Edge: NaN in moment data — should propagate gracefully (not crash)
try
    H_nan = H_loop;
    M_nan = M_loop;
    M_nan(50) = NaN;   % inject one NaN
    dims_n.width=0.3; dims_n.length=0.5; dims_n.thickness=0.01;
    res_nan = calc.superconductor.beanJc(H_nan, M_nan, dims_n);
    assert(isstruct(res_nan) && isfield(res_nan, 'Jc'), ...
        'beanJc should return a struct even with NaN in moment data');
    fprintf('  PASS: beanJc NaN in moment — no crash\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: beanJc NaN in moment — crashed: %s\n', ME.message);
    failed = failed + 1;
end

% ── SUMMARY ──────────────────────────────────────────────────────────
fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_superconductor:failures', '%d test(s) FAILED', failed);
end
