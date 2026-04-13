function test_insetGraph
%TEST_INSETGRAPH  Headless tests for bosonPlotter.insetGraph.
%
%   Run standalone:  cd tests/gui; run test_insetGraph
%   Run via suite:   runAllTests(Group='gui')
%
%   Tests:
%     1. insetGraph creates a new axes overlaid on the parent
%     2. Inset axes has XLim and YLim matching the specified region
%     3. Inset axes is tagged 'bosonInset'
%     4. A zoom rectangle is drawn on the parent axes
%     5. Two connector lines are drawn on the parent axes
%     6. handles struct has .insetAx, .rect, .connectors fields
%     7. handles.insetAx is a valid axes handle
%     8. handles.rect is a valid rectangle handle
%     9. handles.connectors is a 1x2 array of valid line handles
%    10. insetGraph_remove cleans up inset, rect, and connectors
%    11. Repeated calls replace the previous inset (one inset per axes)
%    12. insetGraph with Position option places inset at expected location
%    13. Invalid region (xMin >= xMax) raises an error
%    14. Invalid region (yMin >= yMax) raises an error

% ── Path setup ───────────────────────────────────────────────────────────
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
    setupToolbox;
end

passed   = 0;
failed   = 0;
failures = {};

% ── Create a standalone figure + axes for testing ────────────────────────
fig = figure('Visible', 'off', 'Units', 'normalized', 'Position', [0 0 0.8 0.8]);
cleanupFig = onCleanup(@() close(fig));
ax  = axes(fig, 'Position', [0.1 0.1 0.8 0.8]);

% Populate parent axes with sample data
x = linspace(0, 2*pi, 100);
line(ax, x, sin(x), 'Color', 'b', 'LineWidth', 1.5);
ax.XLim = [0 2*pi]; ax.YLim = [-1.5 1.5];
drawnow;

REGION = [1.0 2.5 -0.5 0.5];

% ════════════════════════════════════════════════════════════════════════
%  TEST 1: creates a new axes overlaid on the parent figure
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 1: inset axes created ==\n');
try
    h = bosonPlotter.insetGraph(ax, REGION);
    drawnow;
    check('inset axes exists', isgraphics(h.insetAx) && isvalid(h.insetAx));
catch ME
    recordCrash('TEST 1', ME);
    h = struct('insetAx', gobjects(0), 'rect', gobjects(0), 'connectors', gobjects(0,2));
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 2: XLim and YLim match specified region
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 2: region limits correct ==\n');
try
    iAx = h.insetAx;
    check('inset XLim(1) == REGION(1)', abs(iAx.XLim(1) - REGION(1)) < 1e-10);
    check('inset XLim(2) == REGION(2)', abs(iAx.XLim(2) - REGION(2)) < 1e-10);
    check('inset YLim(1) == REGION(3)', abs(iAx.YLim(1) - REGION(3)) < 1e-10);
    check('inset YLim(2) == REGION(4)', abs(iAx.YLim(2) - REGION(4)) < 1e-10);
catch ME
    recordCrash('TEST 2', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 3: inset axes tagged 'bosonInset'
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 3: inset tag ==\n');
try
    check('Tag == bosonInset', strcmp(h.insetAx.Tag, 'bosonInset'));
catch ME
    recordCrash('TEST 3', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 4: zoom rectangle drawn on parent
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 4: zoom rectangle on parent ==\n');
try
    check('rect is valid graphics', isgraphics(h.rect) && isvalid(h.rect));
    check('rect tag is bosonInsetRect', strcmp(h.rect.Tag, 'bosonInsetRect'));
catch ME
    recordCrash('TEST 4', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 5: connector lines drawn on parent
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 5: connector lines ==\n');
try
    check('2 connector lines', numel(h.connectors) == 2);
    check('connector 1 valid', isgraphics(h.connectors(1)));
    check('connector 2 valid', isgraphics(h.connectors(2)));
catch ME
    recordCrash('TEST 5', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 6: handles struct has required fields
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 6: handles struct fields ==\n');
try
    check('handles.insetAx present',    isfield(h, 'insetAx'));
    check('handles.rect present',       isfield(h, 'rect'));
    check('handles.connectors present', isfield(h, 'connectors'));
catch ME
    recordCrash('TEST 6', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 7: insetAx is a valid axes handle
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 7: insetAx is axes ==\n');
try
    check('insetAx isa Axes', isa(h.insetAx, 'matlab.graphics.axis.Axes'));
catch ME
    recordCrash('TEST 7', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 8: rect is a valid rectangle
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 8: rect is rectangle ==\n');
try
    check('rect isa rectangle', isa(h.rect, 'matlab.graphics.primitive.Rectangle'));
catch ME
    recordCrash('TEST 8', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 9: connectors are line handles (1x2)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 9: connectors are lines ==\n');
try
    % Lines drawn on axes (not uiaxes) are matlab.graphics.primitive.Line;
    % lines on uiaxes are matlab.graphics.chart.primitive.Line — accept both.
    isLineObj = @(lh) isa(lh, 'matlab.graphics.primitive.Line') || ...
                      isa(lh, 'matlab.graphics.chart.primitive.Line');
    check('connector 1 isa line', isLineObj(h.connectors(1)));
    check('connector 2 isa line', isLineObj(h.connectors(2)));
catch ME
    recordCrash('TEST 9', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 10: insetGraph_remove cleans up all handles
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 10: remove cleans up ==\n');
try
    insetAxSaved  = h.insetAx;
    rectSaved     = h.rect;
    connSaved     = h.connectors;

    bosonPlotter.insetGraph_remove(ax);
    drawnow;

    check('insetAx deleted',     ~isgraphics(insetAxSaved));
    check('rect deleted',        ~isgraphics(rectSaved));
    check('connector 1 deleted', ~isgraphics(connSaved(1)));
    check('connector 2 deleted', ~isgraphics(connSaved(2)));
catch ME
    recordCrash('TEST 10', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 11: second call replaces first inset (one inset per axes)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 11: second call replaces first ==\n');
try
    h1 = bosonPlotter.insetGraph(ax, [1.0 2.0 -0.3 0.3]);
    h2 = bosonPlotter.insetGraph(ax, [2.0 3.0 -0.4 0.4]);
    drawnow;

    nInsets = numel(findobj(fig, 'Tag', 'bosonInset'));
    check('only 1 inset after 2 calls', nInsets == 1);
    check('first inset deleted',        ~isgraphics(h1.insetAx));
    check('second inset valid',          isgraphics(h2.insetAx));

    % Cleanup
    bosonPlotter.insetGraph_remove(ax);
catch ME
    recordCrash('TEST 11', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 12: Position option places inset at expected normalized location
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 12: Position option ==\n');
try
    customPos = [0.1 0.1 0.3 0.3];
    h12 = bosonPlotter.insetGraph(ax, REGION, Position=customPos);
    drawnow;

    % The inset InnerPosition should be inside the parent's InnerPosition
    axInner = ax.InnerPosition;
    iInner  = h12.insetAx.InnerPosition;
    expectedLeft   = axInner(1) + customPos(1) * axInner(3);
    expectedBottom = axInner(2) + customPos(2) * axInner(4);
    tol = 1e-6;
    check('inset left position correct',   abs(iInner(1) - expectedLeft)   < tol);
    check('inset bottom position correct', abs(iInner(2) - expectedBottom) < tol);

    bosonPlotter.insetGraph_remove(ax);
catch ME
    recordCrash('TEST 12', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 13: invalid region xMin >= xMax raises error
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 13: invalid region xMin >= xMax ==\n');
try
    threw = false;
    try
        bosonPlotter.insetGraph(ax, [2.0 1.0 -0.5 0.5]);
    catch
        threw = true;
    end
    check('error thrown for xMin >= xMax', threw);
catch ME
    recordCrash('TEST 13', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 14: invalid region yMin >= yMax raises error
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 14: invalid region yMin >= yMax ==\n');
try
    threw = false;
    try
        bosonPlotter.insetGraph(ax, [1.0 2.0 0.5 -0.5]);
    catch
        threw = true;
    end
    check('error thrown for yMin >= yMax', threw);
catch ME
    recordCrash('TEST 14', ME);
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n==== test_insetGraph: %d passed, %d failed ====\n', passed, failed);
if failed > 0
    for fi = 1:numel(failures)
        fprintf('  FAIL: %s\n', failures{fi});
    end
    error('test_insetGraph:failures', '%d test(s) failed.', failed);
end

% ── Local helpers ─────────────────────────────────────────────────────────
    function check(label, cond)
        if cond
            fprintf('  PASS: %s\n', label);
            passed = passed + 1;
        else
            fprintf('  FAIL: %s\n', label);
            failed  = failed + 1;
            failures{end+1} = label;
        end
    end

    function recordCrash(testName, ME)
        fprintf('  CRASH in %s: %s\n', testName, ME.message);
        failed  = failed + 1;
        failures{end+1} = [testName ': ' ME.message];
    end

end
