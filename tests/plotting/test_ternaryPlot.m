%TEST_TERNARYPLOT  Unit tests for plotting.ternaryPlot.
%
%   Covers: vertex placement, centroid placement, auto-normalization of
%   unnormalized input, value-colored scatter, label assignment, input
%   validation, and grid/triangle rendering.
%
%   Run:  runAllTests(Group="fitting")   % shares group with plot tests
%   Or:   run tests/plotting/test_ternaryPlot

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir); addpath(rootDir); end

fprintf('\n=== test_ternaryPlot ===\n');
passed = 0; failed = 0;

% All tests run in an off-screen figure to avoid flashing windows
fig = figure('Visible', 'off');
cleanupFig = onCleanup(@() closeIfValid(fig));

% ════════════════════════════════════════════════════════════════════════
% TEST 1: Pure vertices land at triangle corners
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 1. Pure-vertex placement ──\n');
try
    clf(fig); ax = axes(fig);
    plotting.ternaryPlot([1 0 0; 0 1 0; 0 0 1], 'Parent', ax, 'Grid', false);

    scats = findobj(ax, 'Type', 'scatter');
    assert(numel(scats) == 1, 'expected 1 scatter object');
    x = scats.XData; y = scats.YData;
    assert(numel(x) == 3, sprintf('expected 3 points, got %d', numel(x)));

    % Expected vertex positions
    expA = [0, 0];
    expB = [1, 0];
    expC = [0.5, sqrt(3)/2];
    tol = 1e-10;

    assert(abs(x(1) - expA(1)) < tol && abs(y(1) - expA(2)) < tol, ...
        sprintf('vertex A: (%.4f, %.4f)', x(1), y(1)));
    assert(abs(x(2) - expB(1)) < tol && abs(y(2) - expB(2)) < tol, ...
        sprintf('vertex B: (%.4f, %.4f)', x(2), y(2)));
    assert(abs(x(3) - expC(1)) < tol && abs(y(3) - expC(2)) < tol, ...
        sprintf('vertex C: (%.4f, %.4f)', x(3), y(3)));

    fprintf('  [PASS] A=(%.3f,%.3f) B=(%.3f,%.3f) C=(%.3f,%.3f)\n', ...
        x(1), y(1), x(2), y(2), x(3), y(3));
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 2: Centroid [1/3 1/3 1/3] lands at geometric centroid
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 2. Centroid placement ──\n');
try
    clf(fig); ax = axes(fig);
    plotting.ternaryPlot([1/3 1/3 1/3], 'Parent', ax, 'Grid', false);

    scats = findobj(ax, 'Type', 'scatter');
    x = scats.XData; y = scats.YData;
    expX = 0.5;                % centroid of equilateral triangle
    expY = sqrt(3) / 6;        % ≈ 0.2887
    tol = 1e-10;

    assert(abs(x - expX) < tol, sprintf('x = %.6f (expected %.6f)', x, expX));
    assert(abs(y - expY) < tol, sprintf('y = %.6f (expected %.6f)', y, expY));
    fprintf('  [PASS] centroid = (%.4f, %.4f)\n', x, y);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 3: Unnormalized input is auto-normalized
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 3. Auto-normalization ──\n');
try
    clf(fig); ax = axes(fig);
    % [10 20 30] → [1/6, 1/3, 1/2]
    plotting.ternaryPlot([10 20 30], 'Parent', ax, 'Grid', false);

    scats = findobj(ax, 'Type', 'scatter');
    x = scats.XData; y = scats.YData;
    % Expected: (1/6)*A + (1/3)*B + (1/2)*C
    expX = (1/3)*1 + (1/2)*0.5;          % = 1/3 + 1/4 = 7/12
    expY = (1/2) * sqrt(3)/2;             % = sqrt(3)/4
    tol = 1e-10;
    assert(abs(x - expX) < tol, sprintf('x = %.6f (expected %.6f)', x, expX));
    assert(abs(y - expY) < tol, sprintf('y = %.6f (expected %.6f)', y, expY));
    fprintf('  [PASS] [10,20,30] → (%.4f, %.4f)\n', x, y);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 4: Triangle outline drawn, vertex labels applied
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 4. Triangle outline + labels ──\n');
try
    clf(fig); ax = axes(fig);
    plotting.ternaryPlot([1/3 1/3 1/3], 'Parent', ax, ...
        'Labels', {'Fe','Ni','Cr'}, 'ShowTriangle', true, 'Grid', false);

    % The triangle is drawn with plot(, 'HandleVisibility','off') so we
    % need findall (which ignores HandleVisibility) instead of findobj.
    lines = findall(ax, 'Type', 'line');
    assert(~isempty(lines), 'triangle outline not found');

    % Labels should include all three strings
    txt = findobj(ax, 'Type', 'text');
    labels = arrayfun(@(t) string(t.String), txt);
    for want = ["Fe","Ni","Cr"]
        assert(any(labels == want), ...
            sprintf('label "%s" not found', want));
    end
    fprintf('  [PASS] triangle + 3 labels (Fe, Ni, Cr)\n');
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 5: Values scalar input → color-coded scatter
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 5. Value-colored scatter ──\n');
try
    clf(fig); ax = axes(fig);
    comp = [0.7 0.2 0.1; 0.3 0.4 0.3; 0.1 0.1 0.8];
    hardness = [180; 250; 320];
    plotting.ternaryPlot(comp, 'Parent', ax, 'Values', hardness, 'Grid', false);

    scats = findobj(ax, 'Type', 'scatter');
    cdata = scats.CData;
    assert(numel(cdata) == 3, sprintf('CData length %d (expected 3)', numel(cdata)));
    assert(isequal(cdata(:), hardness), 'CData should match values');
    fprintf('  [PASS] 3 points colored by [%s]\n', ...
        strjoin(string(hardness), ', '));
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 6: Grid draws without errors and produces multiple lines
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 6. Grid rendering ──\n');
try
    clf(fig); ax = axes(fig);
    plotting.ternaryPlot([1/3 1/3 1/3], 'Parent', ax, 'Grid', true);

    lines = findall(ax, 'Type', 'line');
    % Expect: 27 grid lines (9 intervals × 3 directions) + 1 triangle = 28
    assert(numel(lines) >= 27, ...
        sprintf('expected >=27 grid lines, got %d', numel(lines)));
    fprintf('  [PASS] %d grid/outline line objects\n', numel(lines));
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 7: Input validation — negative fractions
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 7. Negative fractions rejected ──\n');
try
    clf(fig); ax = axes(fig);
    try
        plotting.ternaryPlot([0.5 -0.1 0.6], 'Parent', ax);
        fprintf('  [FAIL] should have thrown on negative fraction\n');
        failed = failed + 1;
    catch ME
        assert(contains(ME.identifier, 'negativeFraction'), ...
            sprintf('wrong id: %s', ME.identifier));
        fprintf('  [PASS] %s\n', ME.identifier);
        passed = passed + 1;
    end
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 8: Input validation — wrong column count
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 8. Wrong column count rejected ──\n');
try
    clf(fig); ax = axes(fig);
    try
        plotting.ternaryPlot([0.5 0.5], 'Parent', ax);   % only 2 columns
        fprintf('  [FAIL] should have thrown on 2-column input\n');
        failed = failed + 1;
    catch
        fprintf('  [PASS] 2-column input rejected\n');
        passed = passed + 1;
    end
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
% TEST 9: Values length mismatch rejected
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 9. Values length mismatch rejected ──\n');
try
    clf(fig); ax = axes(fig);
    try
        plotting.ternaryPlot([0.5 0.3 0.2; 0.2 0.2 0.6], 'Parent', ax, ...
            'Values', [1 2 3]);   % 3 values for 2 rows
        fprintf('  [FAIL] should have thrown on length mismatch\n');
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
% TEST 10: Returns axes handle; interior point stays inside triangle
% ════════════════════════════════════════════════════════════════════════
fprintf('\n── 10. Return handle + interior bounds ──\n');
try
    clf(fig); ax = axes(fig);
    % Dense random ternary compositions
    rng(42);
    N = 50;
    raw = rand(N, 3);
    axReturned = plotting.ternaryPlot(raw, 'Parent', ax, 'Grid', false);
    assert(isequal(axReturned, ax), 'returned axes should match input');

    scats = findobj(ax, 'Type', 'scatter');
    x = scats.XData(:); y = scats.YData(:);
    % Verify every point is inside the equilateral triangle
    % Triangle inequalities:
    %   y >= 0
    %   y <= sqrt(3) * x         (left edge A→C)
    %   y <= sqrt(3) * (1 - x)   (right edge B→C)
    tol = 1e-10;
    assert(all(y >= -tol), 'point below base');
    assert(all(y <= sqrt(3)*x + tol), 'point outside left edge');
    assert(all(y <= sqrt(3)*(1 - x) + tol), 'point outside right edge');

    fprintf('  [PASS] %d random points all inside triangle\n', N);
    passed = passed + 1;
catch ME
    fprintf('  [FAIL] %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
fprintf('\n%s\n', repmat(char(9552), 1, 72));
fprintf('SUMMARY: %d/%d tests passed\n', passed, passed + failed);
if failed > 0
    error('test_ternaryPlot:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end

function closeIfValid(f)
    try
        if isvalid(f); close(f); end
    catch
    end
end
