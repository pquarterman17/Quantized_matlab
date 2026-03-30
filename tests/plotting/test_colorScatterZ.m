%TEST_COLORSCATTERZ  Tests for plotting.colorScatterZ.
%
%   Covers:
%     - Basic scatter object creation with correct CData
%     - Colorbar present when ShowColorbar=true
%     - Colorbar absent when ShowColorbar=false
%     - Custom built-in colormap ("plasma")
%     - Custom [M×3] colormap matrix
%     - ColorLim applied to axes
%     - Single point (no crash)
%     - All-NaN z (no crash)
%     - NaN elements in z handled without crash
%
%   Run standalone:
%       run tests/plotting/test_colorScatterZ
%   Run via suite:
%       runAllTests(Group="plotting")

clear; clc;
fprintf('\n=== test_colorScatterZ ===\n\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
if ~contains(path, ROOT)
    addpath(ROOT);
end

passed = 0;
failed = 0;

rng(7);

% ════════════════════════════════════════════════════════════════════════
%  Shared test data
% ════════════════════════════════════════════════════════════════════════
N  = 100;
x  = randn(N, 1);
y  = randn(N, 1);
z  = x.^2 + y.^2;

% ════════════════════════════════════════════════════════════════════════
%  1. Basic scatter object with correct CData
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 1: Basic scatter object and CData\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.colorScatterZ(ax, x, y, z);
    assert(isa(h, 'matlab.graphics.chart.primitive.Scatter'), ...
        'Expected a scatter object');
    assert(numel(h.CData) == N, 'CData should have N elements');
    assert(max(abs(h.CData - z)) < 1e-12, 'CData must equal z exactly');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. Colorbar present when ShowColorbar=true (default)
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 2: Colorbar present by default\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    plotting.colorScatterZ(ax, x, y, z);
    cbObjs = findobj(fig, 'Type', 'colorbar');
    assert(~isempty(cbObjs), 'Colorbar should be present when ShowColorbar=true');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Colorbar absent when ShowColorbar=false
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 3: No colorbar when ShowColorbar=false\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    plotting.colorScatterZ(ax, x, y, z, 'ShowColorbar', false);
    cbObjs = findobj(fig, 'Type', 'colorbar');
    assert(isempty(cbObjs), 'Colorbar should be absent when ShowColorbar=false');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Custom string colormap applied ("plasma")
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 4: Custom colormap "plasma" applied\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    plotting.colorScatterZ(ax, x, y, z, 'Colormap', 'plasma');
    % Verify colormap has 256 rows and values in [0,1]
    cmap = colormap(ax);
    assert(size(cmap,1) == 256, 'Colormap should have 256 rows');
    assert(size(cmap,2) == 3,   'Colormap should have 3 columns');
    assert(all(cmap(:) >= 0 & cmap(:) <= 1), 'All colormap values in [0,1]');
    % Plasma should have distinct endpoints (not uniform)
    assert(norm(cmap(1,:) - cmap(end,:)) > 0.1, 'Colormap endpoints should differ');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. Custom [M×3] colormap matrix applied
% ════════════════════════════════════════════════════════%%%%%%%%════════
fprintf('TEST 5: Custom [M×3] colormap matrix\n');
try
    customMap = [linspace(0,1,64)', zeros(64,1), linspace(1,0,64)'];
    fig = figure('Visible','off');
    ax  = axes(fig);
    plotting.colorScatterZ(ax, x, y, z, 'Colormap', customMap);
    cmap = colormap(ax);
    assert(isequal(cmap, customMap), 'Custom matrix colormap should be applied as-is');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. ColorLim applied
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 6: ColorLim applied to axes\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    plotting.colorScatterZ(ax, x, y, z, 'ColorLim', [0 5]);
    cl = clim(ax);
    assert(abs(cl(1) - 0) < 1e-10 && abs(cl(2) - 5) < 1e-10, ...
        'ColorLim should be [0 5]');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. Single point — no crash
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 7: Single point — no crash\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.colorScatterZ(ax, 0, 0, 1);
    assert(isa(h, 'matlab.graphics.chart.primitive.Scatter'), ...
        'Should return scatter for single point');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  8. NaN in z — no crash, finite points plotted
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 8: NaN values in z — no crash\n');
try
    zNaN = z;
    zNaN([3, 7, 15]) = NaN;
    fig = figure('Visible','off');
    ax  = axes(fig);
    h = plotting.colorScatterZ(ax, x, y, zNaN);
    assert(isa(h, 'matlab.graphics.chart.primitive.Scatter'), ...
        'Should return scatter even with NaN in z');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  9. All-NaN z — no crash
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 9: All-NaN z — no crash\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    zAllNaN = NaN(N, 1);
    h = plotting.colorScatterZ(ax, x, y, zAllNaN);
    assert(isa(h, 'matlab.graphics.chart.primitive.Scatter'), ...
        'Should return scatter for all-NaN z');
    close(fig);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    try, close(fig); catch; end
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  10. ColorbarLabel set on colorbar
% ════════════════════════════════════════════════════════════════════════
fprintf('TEST 10: ColorbarLabel applied\n');
try
    fig = figure('Visible','off');
    ax  = axes(fig);
    plotting.colorScatterZ(ax, x, y, z, 'ColorbarLabel', 'Intensity');
    cbObjs = findobj(fig, 'Type', 'colorbar');
    assert(~isempty(cbObjs), 'Colorbar expected');
    assert(strcmp(cbObjs(1).Label.String, 'Intensity'), ...
        'Colorbar label should be "Intensity"');
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
    error('test_colorScatterZ:failures', '%d test(s) failed.', failed);
end
