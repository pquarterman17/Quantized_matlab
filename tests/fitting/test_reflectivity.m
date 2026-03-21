%TEST_REFLECTIVITY  Tests for reflectivity fitting: parrattRefl, sldProfile,
%   reflSLDPresets.
%
%   Run:
%     run tests/fitting/test_reflectivity
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_reflectivity ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  PARRATT REFLECTIVITY
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.parrattRefl ---\n');

Q = linspace(0.005, 0.3, 500)';

% Test 1: Bare silicon (Fresnel reflectivity)
layers_si = [0 0 0 0; 0 2.07e-6 0 0];  % air/Si, no roughness
R_si = fitting.parrattRefl(Q, layers_si, Roughness=false);

% At low Q, R should approach 1 (total reflection)
if R_si(1) > 0.99
    fprintf('  PASS: bare Si — R→1 at low Q (R=%.4f)\n', R_si(1)); passed = passed + 1;
else
    fprintf('  FAIL: bare Si — R(Q_min)=%.4f\n', R_si(1)); failed = failed + 1;
end

% At high Q, R should be very small
if R_si(end) < 1e-4
    fprintf('  PASS: bare Si — R→0 at high Q (R=%.2e)\n', R_si(end)); passed = passed + 1;
else
    fprintf('  FAIL: bare Si — R(Q_max)=%.2e\n', R_si(end)); failed = failed + 1;
end

% R should be mostly decreasing for bare substrate (tiny numerical noise
% near the critical edge is acceptable)
dR = diff(R_si);
fracDecreasing = sum(dR <= 1e-10) / numel(dR);
if fracDecreasing > 0.98
    fprintf('  PASS: bare Si — %.0f%% monotonically decreasing\n', fracDecreasing*100);
    passed = passed + 1;
else
    fprintf('  FAIL: bare Si — only %.0f%% decreasing\n', fracDecreasing*100);
    failed = failed + 1;
end

% R should be real and non-negative
if all(isreal(R_si)) && all(R_si >= 0)
    fprintf('  PASS: R is real and non-negative\n'); passed = passed + 1;
else
    fprintf('  FAIL: R has complex or negative values\n'); failed = failed + 1;
end

% Test 2: Single thin film — should show Kiessig fringes
layers_film = [0 0 0 0; 200 3.47e-6 0 0; 0 2.07e-6 0 0];  % air/SiO2(200Å)/Si
R_film = fitting.parrattRefl(Q, layers_film, Roughness=false);

% Count local minima (fringes)
isMin = false(size(R_film));
for i = 2:numel(R_film)-1
    isMin(i) = R_film(i) < R_film(i-1) && R_film(i) < R_film(i+1);
end
nFringes = sum(isMin);
if nFringes >= 3
    fprintf('  PASS: 200Å SiO₂/Si — %d Kiessig fringes detected\n', nFringes);
    passed = passed + 1;
else
    fprintf('  FAIL: expected ≥3 fringes, got %d\n', nFringes); failed = failed + 1;
end

% Fringe spacing should be ≈ 2π/d = 2π/200 ≈ 0.0314 Å⁻¹
fringeQ = Q(isMin);
if numel(fringeQ) >= 2
    avgSpacing = mean(diff(fringeQ));
    expectedSpacing = 2*pi/200;
    if abs(avgSpacing - expectedSpacing) < 0.01
        fprintf('  PASS: fringe spacing ≈ 2π/d (%.4f vs %.4f)\n', ...
            avgSpacing, expectedSpacing);
        passed = passed + 1;
    else
        fprintf('  FAIL: fringe spacing %.4f (exp %.4f)\n', avgSpacing, expectedSpacing);
        failed = failed + 1;
    end
else
    fprintf('  SKIP: not enough fringes for spacing test\n');
end

% Test 3: Roughness reduces reflectivity at high Q
R_rough = fitting.parrattRefl(Q, [0 0 0 0; 200 3.47e-6 0 10; 0 2.07e-6 0 5], ...
    Roughness=true);
% At high Q, rough should be lower than smooth
if R_rough(end) < R_film(end)
    fprintf('  PASS: roughness reduces high-Q reflectivity\n'); passed = passed + 1;
else
    fprintf('  FAIL: roughness did not reduce reflectivity\n'); failed = failed + 1;
end

% Test 4: Scale and background
R_scaled = fitting.parrattRefl(Q, layers_si, Scale=0.5, Background=1e-7);
if abs(R_scaled(1) - (0.5*R_si(1) + 1e-7)) < 1e-10
    fprintf('  PASS: scale and background applied correctly\n'); passed = passed + 1;
else
    fprintf('  FAIL: scale/BG mismatch\n'); failed = failed + 1;
end

% Test 5: Multi-layer (Si/Fe/Si/substrate)
layers_multi = [0 0 0 0; 50 8.02e-6 0 3; 100 2.07e-6 0 3; 0 2.07e-6 0 3];
R_multi = fitting.parrattRefl(Q, layers_multi);
if all(isfinite(R_multi)) && all(R_multi >= 0)
    fprintf('  PASS: multi-layer evaluates without error\n'); passed = passed + 1;
else
    fprintf('  FAIL: multi-layer has NaN/Inf/negative values\n'); failed = failed + 1;
end

% Test 6: Two layers required
try
    fitting.parrattRefl(Q, [0 0 0 0]);
    fprintf('  FAIL: should error with <2 layers\n'); failed = failed + 1;
catch
    fprintf('  PASS: errors with <2 layers\n'); passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SLD PROFILE
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.sldProfile ---\n');

[z, sld] = fitting.sldProfile(layers_film);

if numel(z) == 500 && numel(sld) == 500
    fprintf('  PASS: profile has 500 points\n'); passed = passed + 1;
else
    fprintf('  FAIL: profile size: %d, %d\n', numel(z), numel(sld)); failed = failed + 1;
end

% SLD should transition from ~0 (air) to ~3.47e-6 (SiO2) to ~2.07e-6 (Si)
sldAtNeg50 = interp1(z, sld, -30);  % well above film
sldAt100   = interp1(z, sld, 100);  % middle of SiO2
sldAt250   = interp1(z, sld, min(240, max(z)));  % into substrate (within profile range)

if abs(sldAtNeg50) < 0.5e-6
    fprintf('  PASS: SLD ≈ 0 above film (%.2e)\n', sldAtNeg50); passed = passed + 1;
else
    fprintf('  FAIL: SLD above film = %.2e\n', sldAtNeg50); failed = failed + 1;
end

if abs(sldAt100 - 3.47e-6) < 1e-6
    fprintf('  PASS: SLD ≈ 3.47e-6 in SiO₂ (%.2e)\n', sldAt100); passed = passed + 1;
else
    fprintf('  FAIL: SLD in SiO₂ = %.2e\n', sldAt100); failed = failed + 1;
end

if abs(sldAt250 - 2.07e-6) < 0.5e-6
    fprintf('  PASS: SLD ≈ 2.07e-6 in substrate (%.2e)\n', sldAt250); passed = passed + 1;
else
    fprintf('  FAIL: SLD in substrate = %.2e\n', sldAt250); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SLD PRESETS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.reflSLDPresets ---\n');

presets = fitting.reflSLDPresets();

if numel(presets) >= 25
    fprintf('  PASS: %d material presets\n', numel(presets)); passed = passed + 1;
else
    fprintf('  FAIL: only %d presets\n', numel(presets)); failed = failed + 1;
end

% Check required fields
allOk = true;
for i = 1:numel(presets)
    if ~isfield(presets(i), 'name') || ~isfield(presets(i), 'sldN') || ...
       ~isfield(presets(i), 'sldX')
        allOk = false;
    end
end
if allOk
    fprintf('  PASS: all presets have required fields\n'); passed = passed + 1;
else
    fprintf('  FAIL: some presets missing fields\n'); failed = failed + 1;
end

% Silicon SLD check
si = presets(strcmp({presets.name}, 'Silicon'));
if abs(si.sldN - 2.073e-6) < 1e-8
    fprintf('  PASS: Si neutron SLD = 2.073e-6\n'); passed = passed + 1;
else
    fprintf('  FAIL: Si neutron SLD = %.4e\n', si.sldN); failed = failed + 1;
end

% Air/vacuum should be 0
air = presets(strcmp({presets.name}, 'Air / Vacuum'));
if air.sldN == 0 && air.sldX == 0
    fprintf('  PASS: Air SLD = 0\n'); passed = passed + 1;
else
    fprintf('  FAIL: Air SLD not zero\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  PARRATT + CURVEFIT INTEGRATION
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- parrattRefl + curveFit integration ---\n');

% Generate synthetic data from known layer stack, add noise, fit back
% Simplified: fit only thickness (1 free param) to avoid singular Hessian
rng(42);
trueLayers = [0 0 0 0; 150 3.47e-6 0 5; 0 2.07e-6 0 3];
Qtrue = linspace(0.01, 0.25, 200)';
Rtrue = fitting.parrattRefl(Qtrue, trueLayers);
Rnoisy = Rtrue .* (1 + 0.03*randn(size(Rtrue)));  % 3% noise
Rnoisy = max(Rnoisy, 1e-10);

% Fit thickness only — wrap parrattRefl as a 1-param model
fitModel = @(Q, p) log10(max(fitting.parrattRefl(Q, ...
    [0 0 0 0; p(1) 3.47e-6 0 5; 0 2.07e-6 0 3]), 1e-15));
logData = log10(max(Rnoisy, 1e-15));

res = fitting.curveFit(Qtrue, logData, fitModel, 120, ...
    Lower=50, Upper=300, CalcErrors=false);

fitThick = res.params(1);
if abs(fitThick - 150) < 50
    fprintf('  PASS: recovered thickness ≈ 150 Å (%.1f)\n', fitThick); passed = passed + 1;
else
    fprintf('  FAIL: thickness = %.1f (exp 150)\n', fitThick); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_reflectivity: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_reflectivity:failures', '%d test(s) failed.', failed);
end
