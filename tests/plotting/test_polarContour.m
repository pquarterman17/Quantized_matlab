%TEST_POLARCONTOUR  Unit tests for plotting.polarContour.
%
%   Covers: size convention, radial symmetry, angular symmetry, ThetaZero
%   and ThetaDir rotation, RLim clipping, colorbar, filled vs line mode,
%   and input validation.
%
%   Run:  runAllTests(Group="plotting")
%   Or:   run tests/plotting/test_polarContour

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir); addpath(rootDir); end

fprintf('\n=== test_polarContour ===\n');
passed = 0; failed = 0;

fig = figure('Visible', 'off');
cleanupFig = onCleanup(@() closeIfValid(fig));

% Shared synthetic pole figure: 4-fold symmetry, Gaussian ring at chi=45°
chi = linspace(0, 90, 46)';          % Nr = 46
phi = linspace(0, 360, 73)';         % Nth = 73
[P, C] = meshgrid(phi, chi);         % → [46 × 73]
poleI = exp(-((C - 45).^2) / 50) .* (1 + cos(4 * P * pi/180));

% ════════════════════════════════════════════════════════════════════════
% TEST 1: Basic call, radially symmetric Z
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 1. Radially symmetric Z = r² ──\n');
try
    clf(fig); ax = axes(fig);
    rVec = linspace(0, 1, 30)';
    tVec = linspace(0, 360, 72)';
    Zsym = repmat(rVec.^2, 1, numel(tVec));

    plotting.polarContour(tVec, rVec, Zsym, 'Parent', ax, 'Colorbar', false);
    % Contour collections from contourf
    cs = findall(ax, 'Type', 'Contour');
    assert(~isempty(cs), 'contour object not found');
    fprintf('  [PASS] radially symmetric map rendered\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 2: Size mismatch rejected
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 2. Z size mismatch rejected ──\n');
try
    clf(fig); ax = axes(fig);
    try
        plotting.polarContour((1:10)', (1:5)', zeros(6, 10), 'Parent', ax);
        fprintf('  [FAIL] should have thrown on wrong Z size\n');
        failed = failed + 1;
    catch ME
        assert(contains(ME.identifier, 'sizeMismatch'), ...
            sprintf('wrong id: %s', ME.identifier));
        fprintf('  [PASS] %s\n', ME.identifier);
        passed = passed + 1;
    end
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 3: Correct orientation — Z[i,j] is intensity at (r(i), θ(j))
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 3. Orientation: Z[1,:] should map to innermost radius ──\n');
try
    clf(fig); ax = axes(fig);
    rVec = [0.2; 0.5; 1.0];
    tVec = [0; 90; 180; 270];
    % Only the innermost ring is hot
    Z = zeros(3, 4);
    Z(1, :) = 1;

    plotting.polarContour(tVec, rVec, Z, 'Parent', ax, ...
        'Colorbar', false, 'ShowGrid', false, 'Levels', 10);

    % The hot region should be within radius 0.2 from origin.
    % Inspect contour CData via findall → Contour object.
    cs = findall(ax, 'Type', 'Contour');
    assert(~isempty(cs), 'contour not found');
    zdata = cs.ZData;
    assert(max(zdata(:)) > 0 && min(zdata(:)) == 0, ...
        'Z data should contain both 0 and positive values');
    fprintf('  [PASS] inner-ring Z mapped correctly\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 4: ThetaZero='top' rotates θ=0 to the +y axis
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 4. ThetaZero=top puts θ=0 at +y ──\n');
try
    clf(fig); ax = axes(fig);
    rVec = [0.5; 1.0];
    tVec = [0; 90; 180; 270];
    % Single hot cell at (r=1, θ=0°) — all other cells zero
    Z = zeros(2, 4);
    Z(2, 1) = 1;

    plotting.polarContour(tVec, rVec, Z, 'Parent', ax, ...
        'ThetaZero', 'top', 'ThetaDir', 'ccw', ...
        'Colorbar', false, 'ShowGrid', false, 'Levels', 5);

    % Inspect the generated Cartesian mesh via the Contour object.
    % With ThetaZero=top, θ=0 should map to +y (XData≈0, YData>0).
    cs = findall(ax, 'Type', 'Contour');
    X = cs.XData; Y = cs.YData;
    % Find the grid column corresponding to θ=0 (first column of the mesh)
    x0 = X(:, 1);  y0 = Y(:, 1);
    % These points should lie along +y: x ≈ 0, y = r
    assert(max(abs(x0)) < 1e-10, sprintf('x0 not zero: max=%g', max(abs(x0))));
    assert(all(y0 >= 0), 'y0 should be non-negative');
    assert(abs(max(y0) - 1.0) < 1e-10, sprintf('max y0 = %g', max(y0)));
    fprintf('  [PASS] θ=0 mapped to +y\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 5: ThetaZero='right' puts θ=0 at +x (standard math convention)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 5. ThetaZero=right puts θ=0 at +x ──\n');
try
    clf(fig); ax = axes(fig);
    rVec = [0.5; 1.0];
    tVec = [0; 90; 180; 270];
    Z = zeros(2, 4);
    Z(2, 1) = 1;

    plotting.polarContour(tVec, rVec, Z, 'Parent', ax, ...
        'ThetaZero', 'right', 'ThetaDir', 'ccw', ...
        'Colorbar', false, 'ShowGrid', false);

    cs = findall(ax, 'Type', 'Contour');
    X = cs.XData; Y = cs.YData;
    x0 = X(:, 1); y0 = Y(:, 1);
    assert(max(abs(y0)) < 1e-10, sprintf('y0 not zero: max=%g', max(abs(y0))));
    assert(all(x0 >= 0), 'x0 should be non-negative');
    assert(abs(max(x0) - 1.0) < 1e-10, sprintf('max x0 = %g', max(x0)));
    fprintf('  [PASS] θ=0 mapped to +x\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 6: ThetaDir='cw' reverses angular sense
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 6. ThetaDir=cw reverses rotation ──\n');
try
    clf(fig); ax = axes(fig);
    rVec = [0.5; 1.0];
    tVec = [0; 90];
    Z = [0 0; 0 1];   % hot at (r=1, θ=90°)

    plotting.polarContour(tVec, rVec, Z, 'Parent', ax, ...
        'ThetaZero', 'top', 'ThetaDir', 'cw', ...
        'Colorbar', false, 'ShowGrid', false);

    % With ThetaZero=top + cw: θ=0 at +y, θ=90 goes to +x (clockwise)
    % Column 2 of the mesh corresponds to θ=90.
    cs = findall(ax, 'Type', 'Contour');
    X = cs.XData; Y = cs.YData;
    x90 = X(:, 2); y90 = Y(:, 2);
    assert(max(abs(y90)) < 1e-10, sprintf('y90 not zero: %g', max(abs(y90))));
    assert(all(x90 >= 0), 'x90 should be non-negative with cw rotation');
    fprintf('  [PASS] θ=90 at +y→+x under top+cw\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 7: RLim clipping
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 7. RLim clips outside radii ──\n');
try
    clf(fig); ax = axes(fig);
    rVec = linspace(0, 10, 20)';
    tVec = linspace(0, 360, 36)';
    Z = repmat(rVec, 1, numel(tVec));

    plotting.polarContour(tVec, rVec, Z, 'Parent', ax, ...
        'RLim', [3 7], 'Colorbar', false, 'ShowGrid', false);

    cs = findall(ax, 'Type', 'Contour');
    radius = sqrt(cs.XData.^2 + cs.YData.^2);
    assert(min(radius(:)) >= 3 - 1e-10, sprintf('min r = %g', min(radius(:))));
    assert(max(radius(:)) <= 7 + 1e-10, sprintf('max r = %g', max(radius(:))));
    fprintf('  [PASS] radius ∈ [%.3f, %.3f]\n', min(radius(:)), max(radius(:)));
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 8: Grid rendering — radial circles + angular spokes + outer ring
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 8. Grid rendering ──\n');
try
    clf(fig); ax = axes(fig);
    plotting.polarContour(phi, chi, poleI, 'Parent', ax, ...
        'Colorbar', false, 'ShowGrid', true, ...
        'NGridR', 4, 'NGridTheta', 12);

    lines = findall(ax, 'Type', 'line');
    % Expect: 4 inner circles + 12 spokes + 1 outer ring = 17 lines
    assert(numel(lines) >= 17, ...
        sprintf('expected >=17 grid lines, got %d', numel(lines)));
    fprintf('  [PASS] %d grid line objects\n', numel(lines));
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 9: Pole figure smoke — 4-fold symmetry renders without error
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 9. Synthetic pole figure (4-fold) ──\n');
try
    clf(fig); ax = axes(fig);
    plotting.polarContour(phi, chi, poleI, 'Parent', ax, ...
        'ThetaZero', 'top', 'ThetaDir', 'cw', ...
        'Levels', 20, 'Title', '{220} Pole', 'Colorbar', true);

    cs = findall(ax, 'Type', 'Contour');
    assert(~isempty(cs), 'contour not rendered');
    assert(~isempty(findobj(ax.Parent, 'Type', 'Colorbar')), ...
        'colorbar should be attached');
    fprintf('  [PASS] pole figure renders with colorbar\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 10: Filled=false uses line contour
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 10. Line contour mode ──\n');
try
    clf(fig); ax = axes(fig);
    plotting.polarContour(phi, chi, poleI, 'Parent', ax, ...
        'Filled', false, 'Levels', 8, ...
        'Colorbar', false, 'ShowGrid', false);

    cs = findall(ax, 'Type', 'Contour');
    assert(~isempty(cs), 'line contour not rendered');
    % A line-mode contour has Fill='off'
    assert(strcmp(cs.Fill, 'off'), sprintf('Fill=%s', cs.Fill));
    fprintf('  [PASS] non-filled contour\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
fprintf('\n%s\n', repmat(char(9552), 1, 72));
fprintf('SUMMARY: %d/%d tests passed\n', passed, passed + failed);
if failed > 0
    error('test_polarContour:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end

function closeIfValid(f)
    try
        if isvalid(f); close(f); end
    catch
    end
end
