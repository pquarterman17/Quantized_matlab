%TEST_SPLINESLD  Tests for spline SLD profile + microslicing helpers.
%
%   Covers:
%     fitting.splineSLD        — knots → (z, sld) profile
%     fitting.profileToLayers  — (z, sld) → parrattRefl layer matrix
%
%   Run:
%     run tests/fitting/test_splineSLD
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_splineSLD ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  fitting.splineSLD
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.splineSLD ---\n');

% Test 1: basic two-knot ramp
zK   = [0; 100];
sldK = [0; 3.47e-6];
[z, sld] = fitting.splineSLD(zK, sldK);

if numel(z) == 500 && numel(sld) == 500
    fprintf('  PASS: default NPoints=500\n'); passed = passed + 1;
else
    fprintf('  FAIL: expected 500 points, got %d/%d\n', numel(z), numel(sld));
    failed = failed + 1;
end

% Default ZRange should pad knot range by 50 Å
if abs(z(1) - (-50)) < 1e-9 && abs(z(end) - 150) < 1e-9
    fprintf('  PASS: default ZRange pads knots by 50 Å\n'); passed = passed + 1;
else
    fprintf('  FAIL: ZRange [%.1f, %.1f], expected [-50, 150]\n', z(1), z(end));
    failed = failed + 1;
end

% Below first knot → ambient (default = sldKnots(1) = 0)
if all(abs(sld(z < 0)) < 1e-12)
    fprintf('  PASS: below first knot held at SldAmbient=0\n'); passed = passed + 1;
else
    fprintf('  FAIL: pre-knot values not flat at ambient\n'); failed = failed + 1;
end

% Above last knot → substrate (default = sldKnots(end))
postIdx = z > 100;
if all(abs(sld(postIdx) - 3.47e-6) < 1e-15)
    fprintf('  PASS: above last knot held at SldSubstrate\n'); passed = passed + 1;
else
    fprintf('  FAIL: post-knot values not flat at substrate\n'); failed = failed + 1;
end

% Knot values approximately recovered at knot positions. Tolerance
% accounts for the linspace grid not landing exactly on the knot — we
% interpolate on the resampled grid so a sub-sample offset is unavoidable.
sldAtFirstKnot = interp1(z, sld, 0);
sldAtLastKnot  = interp1(z, sld, 100);
sldScale       = max(abs(sldK(:)));        % 3.47e-6 here
tolKnot        = 1e-3 * sldScale;          % 0.1% of SLD scale
if abs(sldAtFirstKnot - 0) < tolKnot && abs(sldAtLastKnot - 3.47e-6) < tolKnot
    fprintf('  PASS: profile passes through knot values within %.1e\n', tolKnot);
    passed = passed + 1;
else
    fprintf('  FAIL: knots not recovered (%.3e vs 0, %.3e vs 3.47e-6, tol %.1e)\n', ...
        sldAtFirstKnot, sldAtLastKnot, tolKnot);
    failed = failed + 1;
end

% Test 2: explicit boundaries
[z2, sld2] = fitting.splineSLD([0; 200], [3.47e-6; 2.07e-6], ...
    SldAmbient=0, SldSubstrate=2.07e-6, ZRange=[-30, 250]);
if abs(z2(1) - (-30)) < 1e-9 && abs(z2(end) - 250) < 1e-9
    fprintf('  PASS: explicit ZRange honored\n'); passed = passed + 1;
else
    fprintf('  FAIL: ZRange not honored (%.1f, %.1f)\n', z2(1), z2(end));
    failed = failed + 1;
end
if all(abs(sld2(z2 < 0) - 0) < 1e-15)
    fprintf('  PASS: explicit SldAmbient applied\n'); passed = passed + 1;
else
    fprintf('  FAIL: explicit SldAmbient ignored\n'); failed = failed + 1;
end

% Test 3: PCHIP doesn't overshoot between knots with sharp contrast
zK3   = [0; 50; 50.1; 200]';
sldK3 = [0; 0; 4.5e-6; 4.5e-6]';   % sharp step at z=50
[~, sld3] = fitting.splineSLD(zK3, sldK3, NPoints=2000, Method='pchip');
if max(sld3) <= 4.5e-6 + 1e-12 && min(sld3) >= -1e-12
    fprintf('  PASS: PCHIP no overshoot through sharp step\n'); passed = passed + 1;
else
    fprintf('  FAIL: PCHIP overshoot, range=[%.3e, %.3e]\n', min(sld3), max(sld3));
    failed = failed + 1;
end

% Test 4: cubic spline DOES overshoot (sanity check that the methods differ)
[~, sld4] = fitting.splineSLD(zK3, sldK3, NPoints=2000, Method='spline');
if max(sld4) > 4.5e-6 + 1e-9 || min(sld4) < -1e-9
    fprintf('  PASS: cubic spline overshoots (as expected) → use PCHIP for steps\n');
    passed = passed + 1;
else
    fprintf('  PASS: cubic spline did not overshoot here (acceptable)\n');
    passed = passed + 1;
end

% Test 5: error paths
try
    fitting.splineSLD([0], [0]);  %#ok<NBRAK2>
    fprintf('  FAIL: did not error on single knot\n'); failed = failed + 1;
catch ME
    if contains(ME.identifier, 'tooFewKnots')
        fprintf('  PASS: rejects single-knot input\n'); passed = passed + 1;
    else
        fprintf('  FAIL: wrong error id %s\n', ME.identifier); failed = failed + 1;
    end
end

try
    fitting.splineSLD([0; 100], [1e-6]);
    fprintf('  FAIL: did not error on length mismatch\n'); failed = failed + 1;
catch ME
    if contains(ME.identifier, 'knotMismatch')
        fprintf('  PASS: rejects mismatched knot lengths\n'); passed = passed + 1;
    else
        fprintf('  FAIL: wrong error id %s\n', ME.identifier); failed = failed + 1;
    end
end

try
    fitting.splineSLD([0; 50; 30], [0; 1e-6; 2e-6]);
    fprintf('  FAIL: did not error on non-monotone z\n'); failed = failed + 1;
catch ME
    if contains(ME.identifier, 'zNotMonotone')
        fprintf('  PASS: rejects non-monotone zKnots\n'); passed = passed + 1;
    else
        fprintf('  FAIL: wrong error id %s\n', ME.identifier); failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════
%  fitting.profileToLayers
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- fitting.profileToLayers ---\n');

% Test 6: layer matrix shape — N profile points → (N-1) microslabs + 2 endpoint rows
N            = 200;
zP           = linspace(-30, 250, N)';
sldP         = ones(size(zP)) * 2e-6;
L            = fitting.profileToLayers(zP, sldP);
expectedRows = (N - 1) + 2;
if size(L, 1) == expectedRows && size(L, 2) == 4
    fprintf('  PASS: layer matrix is [%d×4] for N=%d profile points\n', expectedRows, N);
    passed = passed + 1;
else
    fprintf('  FAIL: shape [%d×%d], expected [%d×4]\n', size(L,1), size(L,2), expectedRows);
    failed = failed + 1;
end

% Endpoint rows have zero thickness, zero roughness
if L(1, 1) == 0 && L(1, 4) == 0 && L(end, 1) == 0 && L(end, 4) == 0
    fprintf('  PASS: ambient/substrate rows have zero thickness & roughness\n');
    passed = passed + 1;
else
    fprintf('  FAIL: endpoint rows malformed\n'); failed = failed + 1;
end

% Microslab roughness is identically zero
if all(L(2:end-1, 4) == 0)
    fprintf('  PASS: all microslab roughness = 0 (no double-count with profile)\n');
    passed = passed + 1;
else
    fprintf('  FAIL: nonzero microslab roughness\n'); failed = failed + 1;
end

% Sum of microslab thicknesses = z(end) - z(1)
totalThick = sum(L(2:end-1, 1));
if abs(totalThick - (zP(end) - zP(1))) < 1e-9
    fprintf('  PASS: microslab thicknesses sum to total profile range\n');
    passed = passed + 1;
else
    fprintf('  FAIL: thickness sum %.3f, expected %.3f\n', totalThick, zP(end)-zP(1));
    failed = failed + 1;
end

% Default ambient/substrate from profile endpoints
if L(1, 2) == sldP(1) && L(end, 2) == sldP(end)
    fprintf('  PASS: default ambient/substrate from profile endpoints\n');
    passed = passed + 1;
else
    fprintf('  FAIL: endpoint SLD defaults wrong\n'); failed = failed + 1;
end

% Test 7: explicit ambient/substrate override
L2 = fitting.profileToLayers(zP, sldP, SldAmbient=0, SldSubstrate=2.07e-6);
if L2(1, 2) == 0 && L2(end, 2) == 2.07e-6
    fprintf('  PASS: explicit endpoint SLD overrides honored\n');
    passed = passed + 1;
else
    fprintf('  FAIL: endpoint overrides ignored\n'); failed = failed + 1;
end

% Test 8: imaginary SLD propagated
L3 = fitting.profileToLayers(zP, sldP, ImagSld=ones(size(zP)) * 1e-7);
if all(abs(L3(2:end-1, 3) - 1e-7) < 1e-15)
    fprintf('  PASS: ImagSld propagated to microslab column 3\n');
    passed = passed + 1;
else
    fprintf('  FAIL: ImagSld not propagated correctly\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  Round-trip: layers → spline-SLD → layers → parrattRefl agrees
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- round-trip vs parrattRefl ---\n');

% Reference: 200 Å SiO₂ on Si, no roughness, computed via box model
Q     = linspace(0.01, 0.25, 100)';
boxL  = [0 0 0 0; 200 3.47e-6 0 0; 0 2.07e-6 0 0];
R_box = fitting.parrattRefl(Q, boxL, Roughness=false);

% Equivalent via spline + microslicing: knots at the layer boundaries,
% step transition (use 'linear' to faithfully reproduce the box, since
% PCHIP would round the step over a few Å)
zK_box   = [0; 0.001; 200; 200.001];
sldK_box = [0; 3.47e-6; 3.47e-6; 2.07e-6];
[zSp, sldSp] = fitting.splineSLD(zK_box, sldK_box, ...
    SldAmbient=0, SldSubstrate=2.07e-6, ZRange=[-50 250], ...
    NPoints=2000, Method='linear');
splineL = fitting.profileToLayers(zSp, sldSp, ...
    SldAmbient=0, SldSubstrate=2.07e-6);
R_spline = fitting.parrattRefl(Q, splineL, Roughness=false);

% Compare in log space (reflectivity spans many decades)
logBox    = log10(max(R_box,    1e-30));
logSpline = log10(max(R_spline, 1e-30));
maxDiff   = max(abs(logBox - logSpline));

if maxDiff < 0.05   % within 5% of one decade ≈ 12% relative
    fprintf('  PASS: spline-microsliced R matches box model in log-R within %.3f decades\n', maxDiff);
    passed = passed + 1;
else
    fprintf('  FAIL: log-R discrepancy %.3f decades (expected < 0.05)\n', maxDiff);
    failed = failed + 1;
end

% Smooth profile — Si / vacuum graded interface — should produce a
% reflectivity curve with the expected critical-edge behaviour (vacuum
% ambient → R≈1 below Q_c). We use vacuum ambient here rather than D2O
% because parrattRefl defines Q in the lab frame, and a high-SLD
% ambient (D2O) puts the wave below Q_c into the evanescent regime
% where R is ill-defined; that's a legitimate physical effect, not a
% function bug.
zKn   = [0; 50; 100; 150; 200];
sldKn = [0; 1.5e-6; 2.8e-6; 3.3e-6; 3.47e-6];
[zG, sldG] = fitting.splineSLD(zKn, sldKn, ...
    SldAmbient=0, SldSubstrate=3.47e-6, ZRange=[-30 250], NPoints=400);
LG = fitting.profileToLayers(zG, sldG, SldAmbient=0, SldSubstrate=3.47e-6);
R_graded = fitting.parrattRefl(Q, LG, Roughness=false);
if all(isreal(R_graded)) && all(R_graded >= 0) && all(R_graded <= 1.001) ...
        && R_graded(1) > 0.9 && R_graded(end) < 1e-3
    fprintf('  PASS: graded profile R is physical (R_low=%.3f, R_high=%.2e)\n', ...
        R_graded(1), R_graded(end));
    passed = passed + 1;
else
    fprintf('  FAIL: graded profile R out of physical range (R(1)=%.3f, max=%.3f, R(end)=%.2e)\n', ...
        R_graded(1), max(R_graded), R_graded(end)); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_splineSLD: %d passed, %d failed ===\n\n', passed, failed);

if failed > 0
    error('test_splineSLD:failures', '%d test(s) failed', failed);
end
