function test_figDoc()
%TEST_FIGDOC  Unit tests for the FigDocModel and its render functions.
%
%   Tests run headlessly (invisible figures). Validates model persistence,
%   applyToAxes idempotency, updateTraces non-destructive behavior, and
%   captureFromAxes round-trip.

    fprintf('\n=== test_figDoc ===\n');
    passed = 0; failed = 0;

    % ── TEST 1: Model construction and defaults ──────────────────────────
    fprintf('\n== TEST 1: Model construction and defaults ==\n');
    m = bosonPlotter.figDoc.FigDocModel();
    assert(isequal(m.xLim, 'auto'), 'xLim default');
    assert(isequal(m.yLim, 'auto'), 'yLim default');
    assert(strcmp(m.xScale, 'linear'), 'xScale default');
    assert(m.legendVisible == true, 'legend visible default');
    assert(strcmp(m.legendOrientation, 'vertical'), 'legend orientation');
    assert(m.fontSize == 11, 'fontSize default');
    assert(m.dirty == false, 'starts clean');
    fprintf('  PASS\n'); passed = passed + 1;

    % ── TEST 2: Snapshot and restore ─────────────────────────────────────
    fprintf('\n== TEST 2: Snapshot and restore ==\n');
    m.xLim = [10 200];
    m.yScale = 'log';
    m.legendLocation = 'northwest';
    m.addAnnotation(struct('type','text','position',[5 10],'text','peak','style',struct()));
    s = m.snapshot();
    assert(isstruct(s), 'snapshot returns struct');
    assert(isequal(s.xLim, [10 200]), 'snapshot preserves xLim');
    assert(numel(s.annotations) == 1, 'snapshot preserves annotations');

    m2 = bosonPlotter.figDoc.FigDocModel();
    m2.restore(s);
    assert(isequal(m2.xLim, [10 200]), 'restore xLim');
    assert(strcmp(m2.yScale, 'log'), 'restore yScale');
    assert(numel(m2.annotations) == 1, 'restore annotations');
    fprintf('  PASS\n'); passed = passed + 1;

    % ── TEST 3: Reset ────────────────────────────────────────────────────
    fprintf('\n== TEST 3: Reset ==\n');
    m2.reset();
    assert(isequal(m2.xLim, 'auto'), 'reset xLim');
    assert(strcmp(m2.yScale, 'linear'), 'reset yScale');
    assert(isempty(m2.annotations), 'reset annotations');
    fprintf('  PASS\n'); passed = passed + 1;

    % ── TEST 4: Trace style overrides ────────────────────────────────────
    fprintf('\n== TEST 4: Trace style overrides ==\n');
    m3 = bosonPlotter.figDoc.FigDocModel();
    m3.setTraceStyle(2, 'color', [1 0 0]);
    m3.setTraceStyle(2, 'lineWidth', 3);
    assert(numel(m3.traceStyles) == 2, 'traceStyles padded');
    assert(isequal(m3.traceStyles{2}.color, [1 0 0]), 'color set');
    assert(m3.traceStyles{2}.lineWidth == 3, 'lineWidth set');
    assert(m3.dirty == true, 'dirty after setTraceStyle');
    fprintf('  PASS\n'); passed = passed + 1;

    % ── TEST 5: applyToAxes idempotency ──────────────────────────────────
    fprintf('\n== TEST 5: applyToAxes idempotency ==\n');
    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() delete(fig));
    ax = axes(fig);
    plot(ax, 1:10, rand(1,10), 'Tag', 'figDocTrace_1');

    m4 = bosonPlotter.figDoc.FigDocModel();
    m4.xLim = [0 12];
    m4.yLim = [0 1.5];
    m4.xScale = 'linear';
    m4.gridOn = true;
    m4.fontSize = 14;

    bosonPlotter.figDoc.applyToAxes(ax, m4);
    assert(isequal(ax.XLim, [0 12]), 'XLim applied');
    assert(isequal(ax.YLim, [0 1.5]), 'YLim applied');
    assert(ax.FontSize == 14, 'fontSize applied');
    assert(strcmp(ax.XGrid, 'on'), 'grid applied');

    % Apply again — should be the same (idempotent)
    bosonPlotter.figDoc.applyToAxes(ax, m4);
    assert(isequal(ax.XLim, [0 12]), 'XLim idempotent');
    assert(m4.dirty == false, 'markClean after apply');
    fprintf('  PASS\n'); passed = passed + 1;

    % ── TEST 6: updateTraces non-destructive ─────────────────────────────
    fprintf('\n== TEST 6: updateTraces non-destructive ==\n');
    fig2 = figure('Visible', 'off');
    cleanup2 = onCleanup(@() delete(fig2));
    ax2 = axes(fig2);

    ds1 = makeFakeDataset(1:20, sin(1:20), 'Sine', true);
    ds2 = makeFakeDataset(1:20, cos(1:20), 'Cosine', true);

    bosonPlotter.figDoc.updateTraces(ax2, {ds1, ds2}, 1, true);
    lines = findobj(ax2.Children, 'Type', 'Line');
    assert(numel(lines) == 2, 'two traces created');

    % Manually set a color to simulate user override
    ln1 = findobj(ax2, 'Tag', 'figDocTrace_1');
    ln1.Color = [1 0 0]; % red override

    % Update data — should NOT wipe color
    ds1.data.values = sin((1:20) + 0.5)';
    bosonPlotter.figDoc.updateTraces(ax2, {ds1, ds2}, 1, true);
    ln1after = findobj(ax2, 'Tag', 'figDocTrace_1');
    assert(isequal(ln1after.Color, [1 0 0]), 'color preserved after data update');
    assert(numel(ln1after.YData) == 20, 'YData updated');
    fprintf('  PASS\n'); passed = passed + 1;

    % ── TEST 7: updateTraces removes hidden datasets ─────────────────────
    fprintf('\n== TEST 7: updateTraces removes hidden datasets ==\n');
    ds2.visible = false;
    bosonPlotter.figDoc.updateTraces(ax2, {ds1, ds2}, 1, true);
    lines = findobj(ax2.Children, '-regexp', 'Tag', '^figDocTrace_');
    assert(numel(lines) == 1, 'hidden dataset removed');
    assert(strcmp(lines.Tag, 'figDocTrace_1'), 'correct trace remains');
    fprintf('  PASS\n'); passed = passed + 1;

    % ── TEST 8: captureFromAxes round-trip ───────────────────────────────
    fprintf('\n== TEST 8: captureFromAxes round-trip ==\n');
    fig3 = figure('Visible', 'off');
    cleanup3 = onCleanup(@() delete(fig3));
    ax3 = axes(fig3);
    plot(ax3, 1:10, rand(1,10));
    ax3.XLim = [2 8];
    ax3.YLim = [0.1 0.9];
    ax3.XScale = 'log';
    ax3.FontSize = 12;

    m5 = bosonPlotter.figDoc.FigDocModel();
    bosonPlotter.figDoc.captureFromAxes(ax3, m5);
    assert(isequal(m5.xLim, [2 8]), 'captured xLim');
    assert(isequal(m5.yLim, [0.1 0.9]), 'captured yLim');
    assert(strcmp(m5.xScale, 'log'), 'captured xScale');
    assert(m5.fontSize == 12, 'captured fontSize');
    fprintf('  PASS\n'); passed = passed + 1;

    % ── TEST 9: export profiles ──────────────────────────────────────────
    fprintf('\n== TEST 9: export profiles ==\n');
    ppt = bosonPlotter.figDoc.exportProfiles('powerpoint');
    assert(ppt.width == 10, 'ppt width');
    assert(ppt.dpi == 150, 'ppt dpi');
    assert(ppt.lineWidth == 2.0, 'ppt lineWidth');

    aps = bosonPlotter.figDoc.exportProfiles('aps');
    assert(abs(aps.width - 3.375) < 0.01, 'aps width');
    assert(aps.dpi == 600, 'aps dpi');
    assert(strcmp(aps.format, 'pdf'), 'aps format');

    nat = bosonPlotter.figDoc.exportProfiles('nature');
    assert(nat.fontSize == 8, 'nature fontSize');
    fprintf('  PASS\n'); passed = passed + 1;

    % ── TEST 10: exportRender produces file ──────────────────────────────
    fprintf('\n== TEST 10: exportRender produces file ==\n');
    m6 = bosonPlotter.figDoc.FigDocModel();
    m6.xLabel = "X axis";
    m6.yLabel = "Y axis";
    tmpOut = fullfile(tempdir, 'figdoc_test_export.png');
    if exist(tmpOut, 'file'), delete(tmpOut); end

    ds = makeFakeDataset(1:50, randn(1,50), 'Test', true);
    outPath = bosonPlotter.figDoc.exportRender({ds}, 1, false, m6, 'powerpoint', tmpOut);
    assert(exist(outPath, 'file') == 2, 'export file created');
    info = imfinfo(outPath);
    assert(info.Width > 1000, 'export has reasonable width');
    delete(outPath);
    fprintf('  PASS\n'); passed = passed + 1;

    % ── Summary ──────────────────────────────────────────────────────────
    fprintf('\n====================================================================\n');
    fprintf('  test_figDoc: %d passed, %d failed\n', passed, failed);
    fprintf('====================================================================\n');
    if failed > 0
        error('test_figDoc:failures', '%d test(s) failed.', failed);
    end
end

% ═════════════════════════════════════════════════════════════════════════
function ds = makeFakeDataset(x, y, name, visible)
    ds.data.time = x(:);
    ds.data.values = y(:);
    ds.data.labels = {name};
    ds.corrData = [];
    ds.legendName = name;
    ds.visible = visible;
end
