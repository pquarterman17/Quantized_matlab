%TEST_AXISBREAK  Tests for plotting.axisBreak.
%
%   Covers:
%     - Y break: two axes created with correct YLim ranges
%     - X break: two axes with correct XLim ranges
%     - Removal: original axes restored, sub-axes deleted
%     - Break marks: annotation objects present for zigzag and slash styles
%     - 'gap' style: no annotation objects created
%     - breakValue out of range: error thrown
%     - Data copy: lines visible in both sub-axes
%
%   Run standalone:
%       run tests/plotting/test_axisBreak
%   Run via suite:
%       runAllTests(Group="plotting")

clear; clc;
fprintf('\n=== test_axisBreak ===\n\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if ~contains(path, ROOT)
    addpath(ROOT);
end

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  Shared test data
% ════════════════════════════════════════════════════════════════════════
x = linspace(0, 10, 50)';
y = [x * 0.5; x * 5 + 50];   % two clusters: 0-5 and 50-100  (not used as vectors)
xD = linspace(0, 10, 50);
yLow  = xD * 0.5;             % values 0-5
yHigh = xD * 5 + 50;          % values 50-100

% ════════════════════════════════════════════════════════════════════════
%  TEST 1: Y break — two axes created with correct YLim ranges
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 1: Y break — correct YLim on each sub-axis\n');
try
    fig = figure('Visible', 'off');
    ax  = axes(fig);
    hold(ax, 'on');
    plot(ax, xD, yLow,  'b-');
    plot(ax, xD, yHigh, 'r-');
    ax.YLim = [0 100];

    h = plotting.axisBreak(ax, 25, 'Axis', 'y', 'GapRatio', 0.04);

    assert(isstruct(h),          'Output must be a struct');
    assert(isfield(h, 'ax1'),    'Must have .ax1');
    assert(isfield(h, 'ax2'),    'Must have .ax2');
    assert(isvalid(h.ax1),       '.ax1 must be valid');
    assert(isvalid(h.ax2),       '.ax2 must be valid');

    % Lower axes must not include 25+halfGap and above
    assert(h.ax1.YLim(2) < 25, ...
        sprintf('ax1.YLim(2) should be < 25, got %.4g', h.ax1.YLim(2)));
    % Upper axes must not include 25-halfGap and below
    assert(h.ax2.YLim(1) > 25, ...
        sprintf('ax2.YLim(1) should be > 25, got %.4g', h.ax2.YLim(1)));
    % Lower axes starts at original min
    assert(h.ax1.YLim(1) == 0, ...
        sprintf('ax1.YLim(1) should be 0, got %.4g', h.ax1.YLim(1)));
    % Upper axes ends at original max
    assert(h.ax2.YLim(2) == 100, ...
        sprintf('ax2.YLim(2) should be 100, got %.4g', h.ax2.YLim(2)));

    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 2: X break — two axes with correct XLim ranges
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 2: X break — correct XLim on each sub-axis\n');
try
    fig = figure('Visible', 'off');
    ax  = axes(fig);
    plot(ax, xD, yLow, 'b-');
    ax.XLim = [0 10];

    h = plotting.axisBreak(ax, 4, 'Axis', 'x', 'GapRatio', 0.04);

    assert(isvalid(h.ax1) && isvalid(h.ax2), 'Both axes must be valid');

    % Left axes: XLim(2) < 4
    assert(h.ax1.XLim(2) < 4, ...
        sprintf('ax1.XLim(2) should be < 4, got %.4g', h.ax1.XLim(2)));
    % Right axes: XLim(1) > 4
    assert(h.ax2.XLim(1) > 4, ...
        sprintf('ax2.XLim(1) should be > 4, got %.4g', h.ax2.XLim(1)));
    assert(h.ax1.XLim(1) == 0, ...
        sprintf('ax1.XLim(1) should be 0, got %.4g', h.ax1.XLim(1)));
    assert(h.ax2.XLim(2) == 10, ...
        sprintf('ax2.XLim(2) should be 10, got %.4g', h.ax2.XLim(2)));

    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 3: remove() — original axes restored, sub-axes deleted
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 3: remove() restores original axes\n');
try
    fig = figure('Visible', 'off');
    ax  = axes(fig);
    plot(ax, xD, yLow, 'b-');
    ax.YLim = [0 5];

    h   = plotting.axisBreak(ax, 2, 'Axis', 'y');
    ax1 = h.ax1;
    ax2 = h.ax2;

    h.remove();

    assert(isvalid(ax),   'Original axes should still be valid after remove()');
    assert(strcmp(ax.Visible, 'on'), 'Original axes should be visible after remove()');
    assert(~isvalid(ax1), 'ax1 should be deleted after remove()');
    assert(~isvalid(ax2), 'ax2 should be deleted after remove()');

    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 4: zigzag style — annotation mark objects exist
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 4: zigzag style — break mark annotations created\n');
try
    fig = figure('Visible', 'off');
    ax  = axes(fig);
    plot(ax, xD, yLow, 'b-');
    ax.YLim = [0 5];

    h = plotting.axisBreak(ax, 2, 'Axis', 'y', 'BreakStyle', 'zigzag');

    assert(~isempty(h.breakMarks), 'breakMarks should not be empty for zigzag');
    validMarks = arrayfun(@isvalid, h.breakMarks);
    assert(all(validMarks), 'All breakMarks should be valid graphics objects');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 5: slash style — annotation mark objects exist
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 5: slash style — break mark annotations created\n');
try
    fig = figure('Visible', 'off');
    ax  = axes(fig);
    plot(ax, xD, yLow, 'b-');
    ax.YLim = [0 5];

    h = plotting.axisBreak(ax, 2, 'Axis', 'y', 'BreakStyle', 'slash');

    assert(~isempty(h.breakMarks), 'breakMarks should not be empty for slash');
    validMarks = arrayfun(@isvalid, h.breakMarks);
    assert(all(validMarks), 'All slash markMarks should be valid');
    % slash creates 2 lines per break location x 2 locations = 4
    assert(numel(h.breakMarks) >= 2, ...
        sprintf('Expected >= 2 mark handles for slash, got %d', numel(h.breakMarks)));
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 6: gap style — no annotation objects
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 6: gap style — no break marks created\n');
try
    fig = figure('Visible', 'off');
    ax  = axes(fig);
    plot(ax, xD, yLow, 'b-');
    ax.YLim = [0 5];

    h = plotting.axisBreak(ax, 2, 'Axis', 'y', 'BreakStyle', 'gap');

    assert(isempty(h.breakMarks), ...
        sprintf('breakMarks should be empty for gap style, got %d', numel(h.breakMarks)));
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 7: breakValue out of range — error thrown
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 7: breakValue outside axis limits — error\n');
try
    fig = figure('Visible', 'off');
    ax  = axes(fig);
    plot(ax, xD, yLow, 'b-');
    ax.YLim = [0 5];

    errThrown = false;
    try
        plotting.axisBreak(ax, 10, 'Axis', 'y');  % 10 > YLim(2)=5
    catch ME2
        if contains(ME2.identifier, 'axisBreak')
            errThrown = true;
        else
            rethrow(ME2);
        end
    end
    assert(errThrown, 'Should have thrown a plotting:axisBreak error');

    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 8: line data copied — children present in sub-axes
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 8: line data copied into both sub-axes\n');
try
    fig = figure('Visible', 'off');
    ax  = axes(fig);
    hold(ax, 'on');
    plot(ax, xD, yLow,  'b-', 'DisplayName', 'Low');
    plot(ax, xD, yHigh, 'r-', 'DisplayName', 'High');
    hold(ax, 'off');
    ax.YLim = [0 100];

    h = plotting.axisBreak(ax, 25, 'Axis', 'y');

    nLines1 = numel(findobj(h.ax1, 'Type', 'line'));
    nLines2 = numel(findobj(h.ax2, 'Type', 'line'));

    assert(nLines1 >= 2, ...
        sprintf('ax1 should contain >= 2 lines, got %d', nLines1));
    assert(nLines2 >= 2, ...
        sprintf('ax2 should contain >= 2 lines, got %d', nLines2));

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
fprintf('\n%s\n', repmat(char(9552), 1, 45));
fprintf('Results: %d passed, %d failed (of %d)\n', passed, failed, passed+failed);
if failed == 0
    fprintf('All tests PASSED.\n');
else
    fprintf('SOME TESTS FAILED.\n');
    error('test_axisBreak:failures', '%d test(s) failed.', failed);
end
