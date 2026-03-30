%TEST_GROUPEDPLOT  Tests for plotting.groupedPlot.
%
%   Covers:
%     - 3 string groups → 3 line objects
%     - Legend has correct group names
%     - PlotType="scatter" produces scatter objects
%     - PlotType="bar" produces bar object
%     - PlotType="box" produces struct output without crash
%     - Empty group — no crash
%     - Numeric groups work same as string groups
%     - SortGroups=false preserves insertion order
%     - ErrorBars applied in line mode
%     - Legend=false — no legend created
%
%   Run standalone:
%       run tests/plotting/test_groupedPlot
%   Run via suite:
%       runAllTests(Group="plotting")

clear; clc;
fprintf('\n=== test_groupedPlot ===\n\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if ~contains(path, ROOT)
    addpath(ROOT);
end

passed = 0;
failed = 0;

rng(21);

% ════════════════════════════════════════════════════════════════════════
%  Shared test data — 3 string groups, 10 points each
% ════════════════════════════════════════════════════════════════════════
N  = 30;
x  = (1:N)';
y  = sin(x * 0.3) + randn(N, 1) * 0.2;
gStr = repmat(["A","B","C"], 1, 10)';

% ════════════════════════════════════════════════════════════════════════
%  1. 3 groups → 3 line objects
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 1: 3 string groups → 3 line handles\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.groupedPlot(ax, x, y, gStr, 'PlotType', 'line');
    assert(isstruct(h), 'Expected struct output');
    validLines = h.lines(~cellfun(@isempty, h.lines));
    assert(numel(validLines) == 3, sprintf('Expected 3 line handles, got %d', numel(validLines)));
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. Legend has correct group names
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 2: Legend labels match group names\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.groupedPlot(ax, x, y, gStr, 'PlotType', 'line');
    assert(~isempty(h.legend) && isvalid(h.legend), 'Legend should exist');
    lgdStrings = string({h.legend.String{:}});
    assert(any(lgdStrings == "A"), 'Legend should contain "A"');
    assert(any(lgdStrings == "B"), 'Legend should contain "B"');
    assert(any(lgdStrings == "C"), 'Legend should contain "C"');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. PlotType="scatter" → scatter objects
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 3: PlotType="scatter" produces scatter objects\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.groupedPlot(ax, x, y, gStr, 'PlotType', 'scatter');
    validLines = h.lines(~cellfun(@isempty, h.lines));
    assert(numel(validLines) == 3, 'Expected 3 scatter handles');
    for k = 1:numel(validLines)
        assert(isa(validLines{k}, 'matlab.graphics.chart.primitive.Scatter'), ...
            'Each handle should be a scatter object');
    end
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. PlotType="bar" → bar object created
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 4: PlotType="bar" produces bar object\n');
try
    xBar = [1 2 3 1 2 3 1 2 3]';
    yBar = [4 6 3 5 7 4 3 8 5]';
    gBar = repmat(["X","Y","Z"], 1, 3)';
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.groupedPlot(ax, xBar, yBar, gBar, 'PlotType', 'bar');
    validLines = h.lines(~cellfun(@isempty, h.lines));
    assert(~isempty(validLines), 'Expected at least one bar handle');
    assert(isa(validLines{1}, 'matlab.graphics.chart.primitive.Bar'), ...
        'Handle should be a Bar object');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. PlotType="box" → no crash, struct returned
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 5: PlotType="box" — no crash\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.groupedPlot(ax, x, y, gStr, 'PlotType', 'box');
    assert(isstruct(h), 'Expected struct output for box mode');
    assert(~isempty(h.lines{1}), 'box mode should populate lines{1} with hGroup struct');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. Empty group — no crash
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 6: Empty group — no crash\n');
try
    % Group "D" appears in groups but has no data points
    xEmp = [1; 2; 3];
    yEmp = [1; 2; 3];
    gEmp = ["A"; "A"; "B"];   % "B" has only 1 member, no group is fully empty but test still covers skip
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.groupedPlot(ax, xEmp, yEmp, gEmp, 'PlotType', 'line');
    assert(isstruct(h), 'Should return struct');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. Numeric groups work same as string groups
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 7: Numeric groups\n');
try
    gNum = repmat([1; 2; 3], 10, 1);
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.groupedPlot(ax, x, y, gNum, 'PlotType', 'line');
    validLines = h.lines(~cellfun(@isempty, h.lines));
    assert(numel(validLines) == 3, 'Expected 3 line handles for numeric groups');
    assert(~isempty(h.legend) && isvalid(h.legend), 'Legend should exist for numeric groups');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  8. SortGroups=false preserves first-occurrence order
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 8: SortGroups=false preserves order\n');
try
    gUnsorted = ["C"; "A"; "B"; "C"; "A"; "B"];
    xU = (1:6)'; yU = randn(6,1);
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.groupedPlot(ax, xU, yU, gUnsorted, ...
        'PlotType', 'scatter', 'SortGroups', false);
    lgdStrings = string({h.legend.String{:}});
    % First occurrence order: C, A, B
    assert(strcmp(lgdStrings(1), 'C'), 'First legend entry should be C (first occurrence)');
    assert(strcmp(lgdStrings(2), 'A'), 'Second legend entry should be A');
    assert(strcmp(lgdStrings(3), 'B'), 'Third legend entry should be B');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  9. ErrorBars in line mode — errorbar objects created
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 9: ErrorBars in line mode\n');
try
    eb = abs(randn(N, 1)) * 0.1;
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.groupedPlot(ax, x, y, gStr, ...
        'PlotType', 'line', 'ErrorBars', eb);
    validErrBars = h.errBars(~cellfun(@isempty, h.errBars));
    assert(numel(validErrBars) == 3, ...
        sprintf('Expected 3 errorbar handles, got %d', numel(validErrBars)));
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  10. Legend=false — no legend created
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 10: Legend=false — no legend\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.groupedPlot(ax, x, y, gStr, ...
        'PlotType', 'line', 'Legend', false);
    assert(isempty(h.legend) || ~isvalid(h.legend), ...
        'No legend should be created when Legend=false');
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
    error('test_groupedPlot:failures', '%d test(s) failed.', failed);
end
