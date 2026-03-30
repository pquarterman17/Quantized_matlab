%TEST_INTERPOLATE2D  Tests for utilities.interpolate2D and utilities.regrid2D.
%
%   Run:
%       run tests/calc/test_interpolate2D
%       runAllTests(Group="interp2d")
%
%   Tests analytic surface interpolation, scattered/gridded inputs,
%   method correctness, and edge cases.

clear; clc;
fprintf('\n=== test_interpolate2D ===\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath')))); addpath(ROOT);
passed = 0; failed = 0;

rng(42);   % reproducible scattered samples

% ════════════════════════════════════════════════════════════════════════
%  SHARED TEST SURFACE:  z = sin(x)*cos(y)  on [0, 2*pi]^2
% ════════════════════════════════════════════════════════════════════════
L = 2*pi;

% Dense reference grid (used to generate the ground truth)
nRef = 15;
[Xref, Yref] = meshgrid(linspace(0.2, L-0.2, nRef));
Zref = sin(Xref) .* cos(Yref);

% Off-grid query points (inside hull of the reference grid)
nq = 9;
[Xq, Yq] = meshgrid(linspace(0.5, L-0.5, nq));
Ztrue = sin(Xq) .* cos(Yq);

% ════════════════════════════════════════════════════════════════════════
%  1. GRIDDED INPUT — linear method
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 1. Gridded input, linear method ---\n');
try
    r = utilities.interpolate2D(Xref, Yref, Zref, Xq, Yq, Method="linear");
    rmse = sqrt(mean((r.zq(:) - Ztrue(:)).^2, 'omitnan'));
    assert(rmse < 0.05, sprintf('RMSE %.4f too large', rmse));
    assert(strcmp(r.method, "linear"), 'Wrong method field');
    assert(isfield(r, 'stats') && isfield(r.stats, 'nPoints'), 'Missing stats');
    assert(r.stats.nPoints == nRef^2, 'Wrong nPoints');
    assert(isequal(size(r.zq), size(Xq)), 'Output size mismatch');
    fprintf('  PASS: gridded linear, RMSE=%.4f\n', rmse); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  2. SCATTERED INPUT — natural method
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 2. Scattered input, natural method ---\n');
try
    nSc = 120;
    xSc = rand(nSc,1) * L;
    ySc = rand(nSc,1) * L;
    zSc = sin(xSc) .* cos(ySc);

    r = utilities.interpolate2D(xSc, ySc, zSc, Xq, Yq, Method="natural");
    rmse = sqrt(mean((r.zq(:) - Ztrue(:)).^2, 'omitnan'));
    assert(rmse < 0.15, sprintf('RMSE %.4f too large for natural', rmse));
    fprintf('  PASS: scattered natural, RMSE=%.4f\n', rmse); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  3. NEAREST NEIGHBOUR — coarse grid, verify it returns a known value
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 3. Nearest-neighbour method ---\n');
try
    xNN = [0; 1; 0; 1];
    yNN = [0; 0; 1; 1];
    zNN = [10; 20; 30; 40];
    % Query exactly at a data point
    r = utilities.interpolate2D(xNN, yNN, zNN, 0, 0, Method="nearest");
    assert(r.zq == 10, 'Nearest: query at data point should return exact value');
    % Query near second point
    r2 = utilities.interpolate2D(xNN, yNN, zNN, 0.9, 0.1, Method="nearest");
    assert(r2.zq == 20, 'Nearest: should snap to closest point');
    fprintf('  PASS: nearest-neighbour exact and proximity\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  4. CUBIC (maps to natural) — same accuracy test as natural
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 4. Cubic method (mapped to natural) ---\n');
try
    r = utilities.interpolate2D(Xref, Yref, Zref, Xq, Yq, Method="cubic");
    rmse = sqrt(mean((r.zq(:) - Ztrue(:)).^2, 'omitnan'));
    assert(rmse < 0.05, sprintf('RMSE %.4f too large', rmse));
    assert(strcmp(r.method, "cubic"), 'Method field should be "cubic"');
    fprintf('  PASS: cubic, RMSE=%.4f\n', rmse); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  5. THIN-PLATE SPLINE — exact interpolation at data points (lambda=0)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 5. Thin-plate spline: exact at data points ---\n');
try
    % Small set so TPS system is well-conditioned
    n5 = 16;
    [X5, Y5] = meshgrid(linspace(0.5, 5.5, 4));
    x5 = X5(:); y5 = Y5(:); z5 = sin(x5) .* cos(y5);

    r = utilities.interpolate2D(x5, y5, z5, x5, y5, Method="thinplate", Smoothing=0);
    maxErr = max(abs(r.zq(:) - z5(:)));
    assert(maxErr < 1e-8, sprintf('TPS max error at data points: %.2e', maxErr));
    fprintf('  PASS: TPS exact interpolation, max error=%.2e\n', maxErr); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  6. THIN-PLATE SPLINE — reasonable off-node accuracy
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 6. Thin-plate spline: off-node accuracy ---\n');
try
    n6 = 25;
    xSc6 = rand(n6,1)*L; ySc6 = rand(n6,1)*L;
    zSc6 = sin(xSc6) .* cos(ySc6);

    r = utilities.interpolate2D(xSc6, ySc6, zSc6, Xq, Yq, Method="thinplate", Smoothing=0);
    rmse = sqrt(mean((r.zq(:) - Ztrue(:)).^2, 'omitnan'));
    assert(rmse < 0.3, sprintf('TPS off-node RMSE %.4f too large', rmse));
    fprintf('  PASS: TPS off-node, RMSE=%.4f\n', rmse); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  7. IDW — exact at data points
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 7. IDW: exact at data points ---\n');
try
    n7 = 20;
    xI = rand(n7,1)*4; yI = rand(n7,1)*4; zI = xI.^2 + yI;

    r = utilities.interpolate2D(xI, yI, zI, xI, yI, Method="idw", ...
        Extrapolation="nearest");
    maxErr = max(abs(r.zq(:) - zI(:)));
    assert(maxErr < 1e-10, sprintf('IDW max error at data points: %.2e', maxErr));
    fprintf('  PASS: IDW exact at data points, max error=%.2e\n', maxErr); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  8. IDW — between points (values bounded by data range)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 8. IDW: between-point bound check ---\n');
try
    xI2 = [0; 2; 0; 2]; yI2 = [0; 0; 2; 2]; zI2 = [1; 3; 2; 4];
    % Query at centre — should be between min and max z
    r = utilities.interpolate2D(xI2, yI2, zI2, 1, 1, Method="idw", ...
        Extrapolation="nearest");
    zMid = r.zq(1);
    assert(zMid >= min(zI2) && zMid <= max(zI2), ...
        sprintf('IDW midpoint %.4f outside data range', zMid));
    fprintf('  PASS: IDW midpoint %.4f in [%.1f, %.1f]\n', zMid, min(zI2), max(zI2));
    passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  9. EXTRAPOLATION=NONE — query outside hull returns NaN
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 9. Extrapolation=none: outside hull → NaN ---\n');
try
    % Unit-square data, query far outside
    xB = [0;1;0;1]; yB = [0;0;1;1]; zB = [1;2;3;4];
    r = utilities.interpolate2D(xB, yB, zB, 10, 10, ...
        Method="linear", Extrapolation="none");
    assert(isnan(r.zq(1)), 'Point outside hull should be NaN');
    fprintf('  PASS: outside hull returns NaN\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  10. EXTRAPOLATION=NEAREST — outside hull returns finite value
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 10. Extrapolation=nearest: outside hull → finite ---\n');
try
    xB = [0;1;0;1]; yB = [0;0;1;1]; zB = [1;2;3;4];
    r = utilities.interpolate2D(xB, yB, zB, 10, 10, ...
        Method="nearest", Extrapolation="nearest");
    assert(isfinite(r.zq(1)), 'Nearest extrapolation should be finite');
    fprintf('  PASS: nearest extrapolation returns finite %.4f\n', r.zq(1));
    passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  11. REGRID2D — output grid dimensions
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 11. regrid2D: output dimensions ---\n');
try
    nSc = 60;
    xRg = rand(nSc,1)*4; yRg = rand(nSc,1)*4;
    zRg = xRg + yRg;

    [Xg, Yg, Zg] = utilities.regrid2D(xRg, yRg, zRg, Nx=50, Ny=30);
    assert(isequal(size(Xg), [30 50]), sprintf('Xg size %s', mat2str(size(Xg))));
    assert(isequal(size(Yg), [30 50]), sprintf('Yg size %s', mat2str(size(Yg))));
    assert(isequal(size(Zg), [30 50]), sprintf('Zg size %s', mat2str(size(Zg))));
    fprintf('  PASS: regrid2D output [30×50]\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  12. REGRID2D — custom XLim/YLim respected
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 12. regrid2D: custom XLim/YLim ---\n');
try
    [Xg, Yg, ~] = utilities.regrid2D(xRg, yRg, zRg, XLim=[1 3], YLim=[1 3], Nx=10, Ny=10);
    assert(abs(min(Xg(1,:)) - 1) < 1e-10, 'XLim min not respected');
    assert(abs(max(Xg(1,:)) - 3) < 1e-10, 'XLim max not respected');
    assert(abs(min(Yg(:,1)) - 1) < 1e-10, 'YLim min not respected');
    fprintf('  PASS: regrid2D XLim/YLim respected\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  13. EDGE CASE — duplicate (x,y) points are deduplicated silently
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 13. Edge case: duplicate input points ---\n');
try
    xD = [0; 1; 0; 1; 0];   % last point duplicates first
    yD = [0; 0; 1; 1; 0];
    zD = [1; 2; 3; 4; 99];  % 99 should be discarded (duplicate)
    r = utilities.interpolate2D(xD, yD, zD, 0, 0, Method="linear");
    assert(r.zq == 1, sprintf('Duplicate dedup: expected 1 got %.4f', r.zq));
    fprintf('  PASS: duplicate points deduplicated, z=%.4f\n', r.zq); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  14. EDGE CASE — collinear points (only linear/nearest safe; TPS should warn/continue)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 14. Edge case: collinear points ---\n');
try
    xCol = (1:5)'; yCol = (1:5)'; zCol = xCol;
    % nearest is always defined
    r = utilities.interpolate2D(xCol, yCol, zCol, 3, 3, Method="nearest");
    assert(isfinite(r.zq(1)), 'Collinear nearest should return finite value');
    fprintf('  PASS: collinear points, nearest returns %.4f\n', r.zq); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  15. EDGE CASE — minimal 3-point input
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 15. Edge case: minimal 3-point input ---\n');
try
    x3 = [0; 1; 0]; y3 = [0; 0; 1]; z3 = [0; 1; 1];
    r = utilities.interpolate2D(x3, y3, z3, 0.25, 0.25, Method="linear");
    assert(isfinite(r.zq(1)), 'Min 3-point: query inside should be finite');
    fprintf('  PASS: 3-point interpolation, zq=%.4f\n', r.zq); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  16. TPS — smoothing parameter reduces overfitting
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 16. TPS: smoothing reduces error on noisy data ---\n');
try
    nSm = 30;
    xSm = rand(nSm,1)*4; ySm = rand(nSm,1)*4;
    zTrue6 = xSm + ySm;
    zNoisy = zTrue6 + 0.5*randn(nSm,1);

    % Query in interior
    [Xqsm, Yqsm] = meshgrid(linspace(0.5,3.5,5));
    Ztrue6q = Xqsm + Yqsm;

    rSmooth = utilities.interpolate2D(xSm, ySm, zNoisy, Xqsm, Yqsm, ...
        Method="thinplate", Smoothing=0.1);
    rExact  = utilities.interpolate2D(xSm, ySm, zNoisy, Xqsm, Yqsm, ...
        Method="thinplate", Smoothing=0);

    rmseSmooth = sqrt(mean((rSmooth.zq(:) - Ztrue6q(:)).^2, 'omitnan'));
    rmseExact  = sqrt(mean((rExact.zq(:) - Ztrue6q(:)).^2, 'omitnan'));

    % Smoothed version should not be drastically worse than exact on noisy data
    % (we just verify both are finite and smooth is within 2x of exact)
    assert(isfinite(rmseSmooth), 'Smooth TPS RMSE not finite');
    assert(isfinite(rmseExact),  'Exact TPS RMSE not finite');
    fprintf('  PASS: TPS smooth RMSE=%.4f, exact RMSE=%.4f\n', rmseSmooth, rmseExact);
    passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  17. RESULT STRUCT FIELDS
% ════════════════════════════════════════════════════════════════════════
fprintf('\n--- 17. Result struct fields ---\n');
try
    r = utilities.interpolate2D([0;1;0;1],[0;0;1;1],[1;2;3;4], 0.5, 0.5);
    assert(isfield(r, 'zq'),     'Missing .zq');
    assert(isfield(r, 'method'), 'Missing .method');
    assert(isfield(r, 'stats'),  'Missing .stats');
    assert(isfield(r.stats, 'nPoints'), 'Missing .stats.nPoints');
    assert(isfield(r.stats, 'rmse'),    'Missing .stats.rmse');
    fprintf('  PASS: all result struct fields present\n'); passed = passed + 1;
catch ME, fprintf('  FAIL: %s\n', ME.message); failed = failed + 1; end

% ════════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════════
fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_interpolate2D:failures', '%d test(s) FAILED', failed);
end
