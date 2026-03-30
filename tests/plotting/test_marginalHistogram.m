%TEST_MARGINALHISTOGRAM  Tests for plotting.marginalHistogram.
%
%   Covers:
%     - Three axes created (main, top, right)
%     - Scatter in main axes
%     - Histogram bin counts consistent with data length
%     - Linked X axes: main and top share limits
%     - Linked Y axes: main and right share limits
%     - ShowKDE=true does not crash
%     - "spaced" layout does not crash
%     - Single point — no crash
%
%   Run standalone:
%       run tests/plotting/test_marginalHistogram
%   Run via suite:
%       runAllTests(Group="plotting")

clear; clc;
fprintf('\n=== test_marginalHistogram ===\n\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if ~contains(path, ROOT)
    addpath(ROOT);
end

passed = 0;
failed = 0;

rng(13);

% ════════════════════════════════════════════════════════════════════════
%  Shared test data
% ════════════════════════════════════════════════════════════════════════
N = 150;
x = randn(N, 1);
y = 0.7*x + randn(N, 1) * 0.5;

% ════════════════════════════════════════════════════════════════════════
%  1. Three axes returned
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 1: Three axes created\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.marginalHistogram(ax, x, y);
    assert(isstruct(h), 'Return value should be a struct');
    assert(isfield(h, 'axMain')  && isvalid(h.axMain),  'axMain missing or invalid');
    assert(isfield(h, 'axTop')   && isvalid(h.axTop),   'axTop missing or invalid');
    assert(isfield(h, 'axRight') && isvalid(h.axRight), 'axRight missing or invalid');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. Scatter object in main axes
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 2: Scatter in main axes\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.marginalHistogram(ax, x, y);
    assert(isfield(h, 'scatterH') && isvalid(h.scatterH), ...
        'scatterH should be a valid graphics handle');
    assert(isa(h.scatterH, 'matlab.graphics.chart.primitive.Scatter'), ...
        'scatterH should be a scatter object');
    assert(numel(h.scatterH.XData) == N, 'Scatter should contain all N points');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Histogram bin count totals consistent with data
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 3: Histogram counts match data size\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.marginalHistogram(ax, x, y, 'NBins', 20);
    topCount   = sum(h.histTopH.Values);
    rightCount = sum(h.histRightH.Values);
    assert(topCount   == N, sprintf('Top histogram total count = %d, expected %d', topCount,   N));
    assert(rightCount == N, sprintf('Right histogram total count = %d, expected %d', rightCount, N));
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Linked X axes: changing main XLim updates top XLim
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 4: X axes linked (main ↔ top)\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.marginalHistogram(ax, x, y);
    % Set main X limits and check top follows
    h.axMain.XLim = [-3 3];
    drawnow;
    assert(isequal(h.axTop.XLim, [-3 3]), ...
        'axTop XLim should match axMain XLim after linkaxes');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. Linked Y axes: changing main YLim updates right YLim
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 5: Y axes linked (main ↔ right)\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.marginalHistogram(ax, x, y);
    h.axMain.YLim = [-2 2];
    drawnow;
    assert(isequal(h.axRight.YLim, [-2 2]), ...
        'axRight YLim should match axMain YLim after linkaxes');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. ShowKDE=true — no crash, extra line objects appear
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 6: ShowKDE=true — no crash\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.marginalHistogram(ax, x, y, 'ShowKDE', true);
    assert(isvalid(h.axTop),   'axTop should be valid with ShowKDE=true');
    assert(isvalid(h.axRight), 'axRight should be valid with ShowKDE=true');
    % Expect at least one line object in top and right axes (the KDE curve)
    topLines   = findobj(h.axTop,   'Type', 'line');
    rightLines = findobj(h.axRight, 'Type', 'line');
    assert(~isempty(topLines),   'Expected KDE line in top axes');
    assert(~isempty(rightLines), 'Expected KDE line in right axes');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. Layout="spaced" — no crash
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 7: Layout="spaced" — no crash\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.marginalHistogram(ax, x, y, 'Layout', 'spaced');
    assert(isstruct(h) && isvalid(h.axMain), 'Should return valid struct for spaced layout');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  8. Single point — no crash
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 8: Single point — no crash\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.marginalHistogram(ax, 0, 0);
    assert(isstruct(h) && isvalid(h.axMain), ...
        'Should return valid struct for single point');
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
    error('test_marginalHistogram:failures', '%d test(s) failed.', failed);
end
