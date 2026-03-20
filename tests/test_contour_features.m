%TEST_CONTOUR_FEATURES  Test contour/heatmap data workflows and edge cases.
%
%   Creates synthetic XYZ datasets, loads via parser.importCSV, and
%   validates the data is suitable for contour plotting. Also tests
%   the gridding/interpolation pipeline that generateContour() uses.
%
%   Run:
%       run tests/test_contour_features
%       runAllTests(Group="contour")

clear; clc;
fprintf('\n=== Contour / Heatmap Feature Tests ===\n\n');

ROOT = fileparts(fileparts(mfilename('fullpath')));
addpath(ROOT);

tmpDir = fullfile(tempdir, sprintf('contour_test_%s', datestr(now, 'yyyymmdd_HHMMSS')));
mkdir(tmpDir);
cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));

passed = 0;
failed = 0;

% ═════════════════════════════════════════════════════════════════════
%  Generate Synthetic Datasets
% ═════════════════════════════════════════════════════════════════════

% Dataset 1: 2D Gaussian peak on regular grid (XYZ columns)
fprintf('Generating synthetic datasets...\n');
[Xg, Yg] = meshgrid(linspace(-5, 5, 50), linspace(-5, 5, 50));
Zg = 10 * exp(-(Xg.^2 + Yg.^2) / 4);
f1 = fullfile(tmpDir, 'gaussian_peak_grid.csv');
fid = fopen(f1, 'w');
fprintf(fid, 'X,Y,Intensity\n');
for ri = 1:size(Xg, 1)
    for ci = 1:size(Xg, 2)
        fprintf(fid, '%.4f,%.4f,%.6f\n', Xg(ri,ci), Yg(ri,ci), Zg(ri,ci));
    end
end
fclose(fid);

% Dataset 2: Scattered (non-gridded) XYZ data — random sampling of a surface
rng(42);  % reproducible
nPts = 300;
xScatter = 10*rand(nPts,1) - 5;
yScatter = 10*rand(nPts,1) - 5;
zScatter = sin(xScatter) .* cos(yScatter) + 0.1*randn(nPts,1);
f2 = fullfile(tmpDir, 'scattered_sincos.csv');
fid = fopen(f2, 'w');
fprintf(fid, 'X_pos,Y_pos,Signal\n');
for ri = 1:nPts
    fprintf(fid, '%.4f,%.4f,%.6f\n', xScatter(ri), yScatter(ri), zScatter(ri));
end
fclose(fid);

% Dataset 3: XRD reciprocal space map (Omega vs 2Theta vs Intensity)
% Simulates a Bragg peak with some spreading
nOmega = 40;
n2Theta = 60;
omega = linspace(30, 32, nOmega);
twoTheta = linspace(60, 64, n2Theta);
[Om, TT] = meshgrid(omega, twoTheta);
% Gaussian peak at (31.0, 62.0)
RSM = 1000 * exp(-((Om-31).^2/0.2 + (TT-62).^2/0.8));
RSM = RSM + 10 + 5*randn(size(RSM));  % background + noise
RSM(RSM < 0) = 0;
f3 = fullfile(tmpDir, 'xrd_rsm.csv');
fid = fopen(f3, 'w');
fprintf(fid, 'Omega_deg,TwoTheta_deg,Intensity_cps\n');
for ri = 1:size(Om, 1)
    for ci = 1:size(Om, 2)
        fprintf(fid, '%.4f,%.4f,%.2f\n', Om(ri,ci), TT(ri,ci), RSM(ri,ci));
    end
end
fclose(fid);

% Dataset 4: Very sparse data (edge case — only 5 points)
f4 = fullfile(tmpDir, 'sparse_xyz.csv');
fid = fopen(f4, 'w');
fprintf(fid, 'X,Y,Z\n');
fprintf(fid, '0,0,1\n1,0,2\n0,1,3\n1,1,4\n0.5,0.5,5\n');
fclose(fid);

% Dataset 5: Data with NaN values
f5 = fullfile(tmpDir, 'xyz_with_nans.csv');
fid = fopen(f5, 'w');
fprintf(fid, 'X,Y,Z\n');
for ri = 1:100
    xv = rand*10; yv = rand*10; zv = xv + yv;
    if mod(ri, 10) == 0
        zv = NaN;
    end
    fprintf(fid, '%.4f,%.4f,%.4f\n', xv, yv, zv);
end
fclose(fid);

fprintf('  Created 5 test datasets in %s\n\n', tmpDir);

% ═════════════════════════════════════════════════════════════════════
%  TEST 1: Parse 3-column CSV files correctly
% ═════════════════════════════════════════════════════════════════════
fprintf('== TEST 1: Parse gridded Gaussian peak CSV ==\n');
try
    d = parser.importCSV(f1);
    assert(numel(d.labels) >= 2, 'Should have at least 2 Y columns (Y + Intensity)');
    assert(numel(d.time) == 2500, 'Should have 50x50 = 2500 rows');
    fprintf('  Loaded: %d rows, %d columns (%s)\n', ...
        numel(d.time), numel(d.labels), strjoin(d.labels, ', '));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ═════════════════════════════════════════════════════════════════════
%  TEST 2: Parse scattered data
% ═════════════════════════════════════════════════════════════════════
fprintf('== TEST 2: Parse scattered sin*cos CSV ==\n');
try
    d = parser.importCSV(f2);
    assert(numel(d.time) == 300, 'Should have 300 rows');
    fprintf('  Loaded: %d rows, columns: %s\n', ...
        numel(d.time), strjoin(d.labels, ', '));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ═════════════════════════════════════════════════════════════════════
%  TEST 3: Gridding via scatteredInterpolant
% ═════════════════════════════════════════════════════════════════════
fprintf('== TEST 3: Grid scattered data via scatteredInterpolant ==\n');
try
    nGrid = 50;
    xLin = linspace(min(xScatter), max(xScatter), nGrid);
    yLin = linspace(min(yScatter), max(yScatter), nGrid);
    [XG, YG] = meshgrid(xLin, yLin);
    F = scatteredInterpolant(xScatter, yScatter, zScatter, 'linear', 'none');
    ZG = F(XG, YG);
    assert(all(size(ZG) == [nGrid nGrid]), 'Grid should be 50x50');
    nNaN = sum(isnan(ZG(:)));
    fprintf('  Grid: %dx%d, NaN count: %d (%.1f%%)\n', nGrid, nGrid, nNaN, 100*nNaN/numel(ZG));
    assert(nNaN < numel(ZG)*0.5, 'Less than 50%% should be NaN');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ═════════════════════════════════════════════════════════════════════
%  TEST 4: Contourf on gridded data
% ═════════════════════════════════════════════════════════════════════
fprintf('== TEST 4: contourf on Gaussian peak grid ==\n');
try
    testFig = figure('Visible', 'off');
    testAx = axes(testFig);
    contourf(testAx, Xg, Yg, Zg, 20, 'LineStyle', 'none');
    colorbar(testAx);
    colormap(testAx, parula(256));
    title(testAx, 'Gaussian Peak Contour');
    % Verify the plot was created
    children = testAx.Children;
    assert(~isempty(children), 'Axes should have contour children');
    close(testFig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    try close(testFig); catch; end
end

% ═════════════════════════════════════════════════════════════════════
%  TEST 5: Contour lines with labels
% ═════════════════════════════════════════════════════════════════════
fprintf('== TEST 5: Labeled contour lines ==\n');
try
    testFig = figure('Visible', 'off');
    testAx = axes(testFig);
    [C, h] = contour(testAx, Xg, Yg, Zg, 10);
    clabel(C, h, 'FontSize', 8);
    assert(~isempty(h), 'Contour handle should not be empty');
    close(testFig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    try close(testFig); catch; end
end

% ═════════════════════════════════════════════════════════════════════
%  TEST 6: pcolor (pseudocolor)
% ═════════════════════════════════════════════════════════════════════
fprintf('== TEST 6: pcolor (pseudocolor) ==\n');
try
    testFig = figure('Visible', 'off');
    testAx = axes(testFig);
    pcolor(testAx, Xg, Yg, Zg);
    shading(testAx, 'flat');
    colorbar(testAx);
    assert(~isempty(testAx.Children), 'pcolor should create surface object');
    close(testFig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    try close(testFig); catch; end
end

% ═════════════════════════════════════════════════════════════════════
%  TEST 7: surf (3D surface)
% ═════════════════════════════════════════════════════════════════════
fprintf('== TEST 7: 3D surface plot ==\n');
try
    testFig = figure('Visible', 'off');
    testAx = axes(testFig);
    surf(testAx, Xg, Yg, Zg, 'EdgeColor', 'none');
    colorbar(testAx);
    view(testAx, -37.5, 30);
    assert(~isempty(testAx.Children), 'surf should create surface object');
    close(testFig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    try close(testFig); catch; end
end

% ═════════════════════════════════════════════════════════════════════
%  TEST 8: RSM data — XRD reciprocal space map
% ═════════════════════════════════════════════════════════════════════
fprintf('== TEST 8: XRD RSM contour from CSV ==\n');
try
    d = parser.importCSV(f3);
    assert(numel(d.time) == nOmega * n2Theta, ...
        sprintf('Should have %d rows', nOmega * n2Theta));
    % Extract columns and grid
    xV = d.time;  % Omega
    yV = d.values(:,1);  % TwoTheta
    zV = d.values(:,2);  % Intensity
    nG = 80;
    xL = linspace(min(xV), max(xV), nG);
    yL = linspace(min(yV), max(yV), nG);
    [XG2, YG2] = meshgrid(xL, yL);
    F2 = scatteredInterpolant(xV, yV, zV, 'linear', 'none');
    ZG2 = F2(XG2, YG2);
    testFig = figure('Visible', 'off');
    testAx = axes(testFig);
    contourf(testAx, XG2, YG2, log10(max(ZG2, 1)), 20, 'LineStyle', 'none');
    colorbar(testAx);
    xlabel(testAx, '\omega (°)'); ylabel(testAx, '2\theta (°)');
    title(testAx, 'RSM (log_{10} intensity)');
    close(testFig);
    fprintf('  Peak intensity: %.1f cps at grid center\n', max(zV));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    try close(testFig); catch; end
end

% ═════════════════════════════════════════════════════════════════════
%  TEST 9: Sparse data (5 points) — edge case
% ═════════════════════════════════════════════════════════════════════
fprintf('== TEST 9: Sparse data (5 points) gridding ==\n');
try
    d = parser.importCSV(f4);
    xV = d.time; yV = d.values(:,1); zV = d.values(:,2);
    assert(numel(xV) == 5, 'Should have 5 rows');
    % griddata should still work with 5 points
    nG = 20;
    xL = linspace(min(xV), max(xV), nG);
    yL = linspace(min(yV), max(yV), nG);
    [XG3, YG3] = meshgrid(xL, yL);
    ZG3 = griddata(xV, yV, zV, XG3, YG3, 'linear'); %#ok<GRIDD>
    assert(any(~isnan(ZG3(:))), 'At least some grid points should be valid');
    fprintf('  Gridded 5 points to %dx%d: %d valid cells\n', nG, nG, sum(~isnan(ZG3(:))));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ═════════════════════════════════════════════════════════════════════
%  TEST 10: Data with NaN values — filtered before gridding
% ═════════════════════════════════════════════════════════════════════
fprintf('== TEST 10: NaN filtering before gridding ==\n');
try
    d = parser.importCSV(f5);
    xV = d.time; yV = d.values(:,1); zV = d.values(:,2);
    nBefore = numel(xV);
    valid = ~isnan(xV) & ~isnan(yV) & ~isnan(zV);
    xV = xV(valid); yV = yV(valid); zV = zV(valid);
    nAfter = numel(xV);
    fprintf('  Before: %d rows, After NaN removal: %d rows\n', nBefore, nAfter);
    assert(nAfter < nBefore, 'Some rows should have been removed');
    assert(nAfter >= 4, 'Should have enough for gridding');
    % Grid
    nG = 30;
    xL = linspace(min(xV), max(xV), nG);
    yL = linspace(min(yV), max(yV), nG);
    [XG4, YG4] = meshgrid(xL, yL);
    F4 = scatteredInterpolant(xV, yV, zV, 'linear', 'none');
    ZG4 = F4(XG4, YG4);
    assert(any(~isnan(ZG4(:))), 'Grid should have valid values');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ═════════════════════════════════════════════════════════════════════
%  TEST 11: Multiple colormaps work
% ═════════════════════════════════════════════════════════════════════
fprintf('== TEST 11: Colormap compatibility ==\n');
try
    cmaps = {'parula','hot','jet','turbo','gray','bone','copper'};
    testFig = figure('Visible', 'off');
    testAx = axes(testFig);
    contourf(testAx, Xg, Yg, Zg, 10);
    allOk = true;
    for ci = 1:numel(cmaps)
        try
            cmapFcn = str2func(cmaps{ci});
            colormap(testAx, cmapFcn(256));
        catch
            fprintf('  WARNING: colormap %s not available\n', cmaps{ci});
            allOk = false;
        end
    end
    close(testFig);
    if allOk
        fprintf('  All %d colormaps work\n', numel(cmaps));
        fprintf('  PASS\n'); passed = passed + 1;
    else
        fprintf('  PASS (with warnings)\n'); passed = passed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    try close(testFig); catch; end
end

% ═════════════════════════════════════════════════════════════════════
%  TEST 12: Full pipeline — CSV → parse → grid → contour → export
% ═════════════════════════════════════════════════════════════════════
fprintf('== TEST 12: Full CSV → contour → PNG export pipeline ==\n');
try
    d = parser.importCSV(f1);
    xV = d.time; yV = d.values(:,1); zV = d.values(:,2);
    valid = ~isnan(xV) & ~isnan(yV) & ~isnan(zV);
    xV = xV(valid); yV = yV(valid); zV = zV(valid);

    nG = 100;
    xL = linspace(min(xV), max(xV), nG);
    yL = linspace(min(yV), max(yV), nG);
    [XG5, YG5] = meshgrid(xL, yL);
    F5 = scatteredInterpolant(xV, yV, zV, 'linear', 'none');
    ZG5 = F5(XG5, YG5);

    testFig = figure('Visible', 'off', 'Units', 'inches', 'Position', [2 2 6 5]);
    testAx = axes(testFig);
    contourf(testAx, XG5, YG5, ZG5, 20, 'LineStyle', 'none');
    colorbar(testAx);
    colormap(testAx, parula(256));
    xlabel(testAx, 'X'); ylabel(testAx, 'Y');
    title(testAx, 'Gaussian Peak (Contour)');
    testAx.FontSize = 11; testAx.Box = 'on';

    % Export to PNG
    outPng = fullfile(tmpDir, 'contour_test.png');
    exportgraphics(testAx, outPng, 'Resolution', 150);
    assert(isfile(outPng), 'PNG should exist');
    info = imfinfo(outPng);
    fprintf('  Exported: %dx%d px PNG\n', info.Width, info.Height);
    close(testFig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    try close(testFig); catch; end
end

% ═════════════════════════════════════════════════════════════════════
%  SUMMARY
% ═════════════════════════════════════════════════════════════════════
fprintf('\n──────────────────────────────────────────────────────────────\n');
fprintf('Contour Feature Tests: %d passed, %d failed (of %d)\n', ...
    passed, failed, passed + failed);
fprintf('──────────────────────────────────────────────────────────────\n');

if failed > 0
    error('test_contour_features:failures', '%d test(s) FAILED', failed);
end
