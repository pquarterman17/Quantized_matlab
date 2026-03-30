%TEST_BOXVIOLINSWARM  Tests for plotting.boxViolinSwarm.
%
%   Covers:
%     - Box plot object types
%     - Violin KDE symmetry and fill object
%     - Swarm scatter objects
%     - Box+Swarm combo
%     - Empty data cell (no crash)
%     - Single point per group (no crash)
%     - Horizontal orientation
%
%   Run standalone:
%       run tests/plotting/test_boxViolinSwarm
%   Run via suite:
%       runAllTests(Group="plotting")

clear; clc;
fprintf('\n=== test_boxViolinSwarm ===\n\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if ~contains(path, ROOT)
    addpath(ROOT);
end

passed = 0;
failed = 0;

rng(42);

% ════════════════════════════════════════════════════════════════════════
%  Shared test data
% ════════════════════════════════════════════════════════════════════════
d1 = randn(60, 1);
d2 = randn(60, 1) + 2;
d3 = randn(60, 1) * 1.5 - 1;
dataCell = {d1, d2, d3};

% ════════════════════════════════════════════════════════════════════════
%  1. Box plot — verify patch + line objects are created
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 1: Box plot object creation\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.boxViolinSwarm(ax, dataCell, ...
        'Style', 'box', 'Labels', {'A','B','C'});
    assert(numel(h.boxes)    >= 3, 'Expected 3 box patches');
    assert(numel(h.medians)  >= 3, 'Expected 3 median lines');
    assert(numel(h.whiskers) >= 12, 'Expected at least 12 whisker handles (4 per group)');
    assert(numel(h.means)    >= 3, 'Expected mean markers (ShowMean=true by default)');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. Violin plot — fill objects, rough KDE symmetry
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 2: Violin plot KDE symmetry\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.boxViolinSwarm(ax, dataCell, 'Style', 'violin');
    assert(numel(h.violins) >= 3, 'Expected 3 violin fill objects');

    % Verify each violin patch is an actual graphics object
    for k = 1:numel(h.violins)
        assert(isvalid(h.violins(k)), 'Violin patch invalid');
        vx = h.violins(k).XData;
        assert(numel(vx) >= 4, 'Violin must have polygon vertices');
    end

    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Violin KDE symmetry check — left and right halves mirror each other
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 3: Violin KDE left/right symmetry\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.boxViolinSwarm(ax, {d1}, 'Style', 'violin');
    vx = h.violins(1).XData;    % x = category +/- density width
    vy = h.violins(1).YData;    % y = value

    % Polygon is [right_side; flipped_left_side]. Find half.
    nPts  = numel(vx);
    half  = nPts / 2;
    % Right half x values should be >= category centre
    % Left half x values should be <= category centre
    rightX = vx(1:floor(half));
    leftX  = vx(floor(half)+1:end);
    assert(all(rightX >= 1 - 0.01), 'Right side should be >= centre');
    assert(all(leftX  <= 1 + 0.01), 'Left side should be <= centre');

    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Swarm plot — scatter objects
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 4: Swarm scatter objects\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.boxViolinSwarm(ax, dataCell, 'Style', 'swarm');
    assert(numel(h.swarm) >= 3, 'Expected 3 scatter objects');

    % Each scatter should have one x-value per point (approximately)
    for k = 1:3
        assert(isvalid(h.swarm(k)), 'Swarm scatter invalid');
        assert(numel(h.swarm(k).YData) == 60, 'Swarm should contain all 60 points');
    end

    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. Box+Swarm combo
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 5: Box+Swarm combo\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.boxViolinSwarm(ax, dataCell, 'Style', 'box+swarm');
    assert(numel(h.boxes)   >= 3, 'Expected 3 boxes');
    assert(numel(h.swarm)   >= 3, 'Expected 3 swarm scatter objects');
    assert(numel(h.medians) >= 3, 'Expected 3 median lines');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. Empty data cell — no crash
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 6: Empty data cell — no crash\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.boxViolinSwarm(ax, {});
    assert(isstruct(h), 'Should return struct even for empty input');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. Single point per group — no crash
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 7: Single point per group — no crash\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.boxViolinSwarm(ax, {1, 2, 3}, 'Style', 'box');
    assert(isstruct(h), 'Should return struct for single-point groups');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  8. Single point per group — violin no crash
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 8: Single point violin — no crash\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.boxViolinSwarm(ax, {5}, 'Style', 'violin');
    assert(isstruct(h), 'Should return struct');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  9. Horizontal orientation — axes tick direction swapped
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 9: Horizontal orientation\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    plotting.boxViolinSwarm(ax, dataCell, ...
        'Style', 'box', 'Orientation', 'horizontal', 'Labels', {'X','Y','Z'});

    % Y ticks should be set (1:3) for horizontal mode
    assert(isequal(ax.YTick, [1 2 3]), 'YTick should be 1:3 in horizontal mode');
    assert(strcmp(ax.YTickLabel{1}, 'X'), 'First YTickLabel should be X');

    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  10. Custom colors applied
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 10: Custom colors applied\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    cols = [1 0 0; 0 1 0; 0 0 1];
    h = plotting.boxViolinSwarm(ax, dataCell, 'Style', 'box', 'Colors', cols);
    % Verify the first box patch uses red (approximately)
    patchCol = h.boxes(1).FaceColor;
    assert(patchCol(1) > 0.8, 'First box should be red');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  11. ShowOutliers=false — no outlier scatter objects
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 11: ShowOutliers=false\n');
try
    % Use data with known outliers
    dWithOutliers = [randn(50,1); 100; -100];
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.boxViolinSwarm(ax, {dWithOutliers}, ...
        'Style', 'box', 'ShowOutliers', false);
    assert(isempty(h.outliers) || numel(h.outliers) == 0, ...
        'No outlier objects expected when ShowOutliers=false');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  12. ShowOutliers=true — outlier scatter objects present for extreme data
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 12: ShowOutliers=true with extreme values\n');
try
    dWithOutliers = [randn(50,1); 100; -100];
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.boxViolinSwarm(ax, {dWithOutliers}, ...
        'Style', 'box', 'ShowOutliers', true);
    assert(~isempty(h.outliers) && isvalid(h.outliers(1)), ...
        'Outlier scatter object expected for extreme data');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n═══════════════════════════════════════\n');
fprintf('Results: %d passed, %d failed (of %d)\n', passed, failed, passed+failed);
if failed == 0
    fprintf('All tests PASSED.\n');
else
    fprintf('SOME TESTS FAILED.\n');
    error('test_boxViolinSwarm:failures', '%d test(s) failed.', failed);
end
