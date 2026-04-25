%TEST_DENSITYPLOT  Verify plotting.densityPlot output and option handling.
%   Smoke + correctness tests for the 2D density plot helper (W3 #16).
%   Covers: auto bin sizing, explicit edges, log compression, Gaussian
%   smoothing, non-finite filtering, colormap delegation, and empty-cell
%   masking.
%
%   Run:  runAllTests(Group="plotting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir); addpath(rootDir); end

fprintf('\n=== test_densityPlot ===\n');
passed = 0; failed = 0;

fig = figure('Visible','off');
cleanup = onCleanup(@() close(fig, 'force'));

% ── Test 1: basic call with default options ─────────────────────────────
try
    ax = axes(fig); cla(ax);
    rng(7);
    x = randn(5000, 1);  y = 0.7*x + randn(5000, 1);
    h = plotting.densityPlot(ax, x, y);
    assert(isfield(h, 'image'),    'h.image missing');
    assert(isfield(h, 'counts'),   'h.counts missing');
    assert(isfield(h, 'xCenters'), 'h.xCenters missing');
    assert(isgraphics(h.image, 'image'), 'h.image is not an image');
    assert(strcmp(ax.YDir, 'normal'), 'YDir not set to normal');
    expectedNB = max(16, min(256, ceil(sqrt(5000)/2)));
    assert(size(h.counts, 1) == expectedNB, ...
        'Auto bin count wrong: got %d expected %d', size(h.counts,1), expectedNB);
    fprintf('  [PASS] basic call — auto bins = %d\n', expectedNB);
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] basic: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 2: explicit NBins (scalar and 2-vector) ────────────────────────
try
    ax = axes(fig); cla(ax);
    x = rand(2000,1); y = rand(2000,1);
    h = plotting.densityPlot(ax, x, y, NBins=50);
    assert(isequal(size(h.counts), [50 50]), ...
        'Scalar NBins wrong: got %s', mat2str(size(h.counts)));
    h2 = plotting.densityPlot(ax, x, y, NBins=[30 80]);
    assert(isequal(size(h2.counts), [30 80]), ...
        'Vector NBins wrong: got %s', mat2str(size(h2.counts)));
    fprintf('  [PASS] explicit NBins (scalar + vector)\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] explicit NBins: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 3: explicit XEdges/YEdges override NBins ───────────────────────
try
    ax = axes(fig); cla(ax);
    x = rand(1000,1)*10; y = rand(1000,1)*5;
    xE = 0:1:10; yE = 0:0.5:5;
    h = plotting.densityPlot(ax, x, y, XEdges=xE, YEdges=yE);
    assert(numel(h.xCenters) == numel(xE)-1, 'xCenters wrong count');
    assert(numel(h.yCenters) == numel(yE)-1, 'yCenters wrong count');
    assert(abs(h.xCenters(1) - 0.5) < 1e-9, 'First xCenter off');
    fprintf('  [PASS] explicit edges respected\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] explicit edges: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 4: LogCounts compresses dynamic range ──────────────────────────
try
    ax = axes(fig); cla(ax);
    % Heavy concentration at one spot — single bin gets ~1000 counts,
    % surrounding bins get ~0.
    x = [zeros(1000,1); randn(50,1)];
    y = [zeros(1000,1); randn(50,1)];
    hLin = plotting.densityPlot(ax, x, y, NBins=20, LogCounts=false);
    hLog = plotting.densityPlot(ax, x, y, NBins=20, LogCounts=true);
    assert(max(hLin.counts(:)) > 100, 'Linear hot-spot weak');
    assert(max(hLog.counts(:)) < 5,   'Log compression failed: max=%.2f', max(hLog.counts(:)));
    fprintf('  [PASS] LogCounts compresses 1000+ → <5\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] LogCounts: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 5: SmoothSigma blurs counts ────────────────────────────────────
try
    ax = axes(fig); cla(ax);
    x = [zeros(500,1); ones(500,1)*5];
    y = [zeros(500,1); ones(500,1)*5];
    h0 = plotting.densityPlot(ax, x, y, NBins=40, SmoothSigma=0);
    h1 = plotting.densityPlot(ax, x, y, NBins=40, SmoothSigma=2);
    % Smoothed map should have lower peak and more nonzero cells.
    assert(max(h1.counts(:)) < max(h0.counts(:)), 'Smoothed peak not lower');
    nz0 = nnz(h0.counts);  nz1 = nnz(h1.counts);
    assert(nz1 > nz0, 'Smoothed should spread mass: nnz0=%d nnz1=%d', nz0, nz1);
    fprintf('  [PASS] SmoothSigma — peak %.1f → %.1f, nnz %d → %d\n', ...
        max(h0.counts(:)), max(h1.counts(:)), nz0, nz1);
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] SmoothSigma: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 6: non-finite filtering ────────────────────────────────────────
try
    ax = axes(fig); cla(ax);
    x = [randn(100,1); NaN; Inf; -Inf];
    y = [randn(100,1); 0;   0;   0];
    h = plotting.densityPlot(ax, x, y, NBins=20);
    % Expected ~100 finite pairs (last 3 dropped because x is non-finite)
    assert(sum(h.counts(:)) == 100, ...
        'Expected 100 binned points, got %d', sum(h.counts(:)));
    fprintf('  [PASS] non-finite (x,y) skipped — %d binned\n', sum(h.counts(:)));
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] non-finite: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 7: colormap delegation (string + RGB matrix) ───────────────────
try
    ax = axes(fig); cla(ax);
    h1 = plotting.densityPlot(ax, randn(500,1), randn(500,1), Colormap='viridis');
    cm1 = colormap(ax);
    assert(size(cm1,1) >= 64 && size(cm1,2) == 3, 'viridis colormap not applied');
    custom = [linspace(0,1,32)' zeros(32,1) linspace(1,0,32)'];
    h2 = plotting.densityPlot(ax, randn(500,1), randn(500,1), Colormap=custom);
    cm2 = colormap(ax);
    assert(size(cm2,1) == 32 && abs(cm2(1,1)) < 1e-9 && abs(cm2(end,1)-1) < 1e-9, ...
        'Custom RGB colormap not applied');
    fprintf('  [PASS] colormap delegation — string + RGB matrix\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] colormap: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 8: ShowColorbar=false suppresses colorbar ──────────────────────
try
    ax = axes(fig); cla(ax);
    h = plotting.densityPlot(ax, randn(500,1), randn(500,1), ShowColorbar=false);
    assert(isempty(h.colorbar), 'Colorbar present when disabled');
    fprintf('  [PASS] ShowColorbar=false honoured\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] ShowColorbar: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 9: empty-data error ────────────────────────────────────────────
try
    ax = axes(fig); cla(ax);
    threw = false;
    try
        plotting.densityPlot(ax, [NaN; NaN], [NaN; NaN]);
    catch ME2
        if strcmp(ME2.identifier, 'plotting:densityPlot:noData')
            threw = true;
        else
            rethrow(ME2);
        end
    end
    assert(threw, 'No-data error not thrown');
    fprintf('  [PASS] all-non-finite errors as expected\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] empty error: %s\n', ME.message);
    failed = failed + 1;
end

fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_densityPlot: %d failure(s)', failed);
end
