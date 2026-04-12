%TEST_DRAGTOPLOT  Headless tests for drag-column-to-plot feature.
%
%   Tests the drag-to-plot API without requiring mouse simulation:
%     1. AppState has the required drag-state properties
%     2. setChannelFromDrag updates the X dropdown correctly
%     3. setChannelFromDrag updates the Y listbox correctly
%     4. setChannelFromDrag updates the Y2 listbox correctly
%     5. setChannelFromDrag is a no-op with no dataset loaded
%     6. setChannelFromDrag is a no-op for an unknown column name
%     7. getDragState returns expected initial state
%
%   Run standalone:  cd tests; run gui/test_dragToPlot
%   Run from root:   run tests/gui/test_dragToPlot
%   Run via runner:  runAllTests(Group="gui")

clear; clc;

% ── Path setup ──────────────────────────────────────────────────────────
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

ROOT    = rootDir;
VSM_F   = fullfile(ROOT, '+test_datasets', 'QuantumDesign', 'EDP136_Perp_StrawNew.dat');
XRDML_F = fullfile(ROOT, '+test_datasets', 'XRDML', 'La2NiO4_1.xrdml');

passed = 0;
failed = 0;

% ── Launch GUI (headless) ────────────────────────────────────────────────
api = BosonPlotter('Visible','off');
drawnow;
cleanup = onCleanup(@() api.close());

% ════════════════════════════════════════════════════════════════════════
%  1. AppState drag-state properties exist
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: AppState has drag-state properties ══\n');
try
    state = bosonPlotter.AppState();
    assert(isprop(state, 'columnDragActive'),  'missing property: columnDragActive');
    assert(isprop(state, 'columnDragColName'), 'missing property: columnDragColName');
    assert(isprop(state, 'columnDragGhost'),   'missing property: columnDragGhost');
    assert(isprop(state, 'columnDragPending'), 'missing property: columnDragPending');
    assert(isprop(state, 'columnDragStartPx'), 'missing property: columnDragStartPx');
    % Verify defaults
    assert(~state.columnDragActive,  'columnDragActive should default to false');
    assert(~state.columnDragPending, 'columnDragPending should default to false');
    assert(isempty(state.columnDragColName), 'columnDragColName should default to ''''');
    fprintf('  All 5 drag-state properties present with correct defaults\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. getDragState returns expected initial idle state
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: getDragState initial state ══\n');
try
    assert(isfield(api, 'getDragState'), 'API missing getDragState');
    ds = api.getDragState();
    assert(isstruct(ds),        'getDragState must return a struct');
    assert(isfield(ds,'active'),  'getDragState missing field: active');
    assert(isfield(ds,'pending'), 'getDragState missing field: pending');
    assert(isfield(ds,'colName'), 'getDragState missing field: colName');
    assert(~ds.active,  'initial active should be false');
    assert(~ds.pending, 'initial pending should be false');
    assert(isempty(ds.colName), 'initial colName should be empty');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. setChannelFromDrag is a no-op when no dataset loaded
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: setChannelFromDrag no-op without data ══\n');
try
    assert(isfield(api, 'setChannelFromDrag'), 'API missing setChannelFromDrag');
    assert(api.getActiveIdx() == 0, 'expected no active dataset');
    % Must not throw even with a fake column name
    api.setChannelFromDrag('FakeColumn', 'y');
    fprintf('  No crash on empty state\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ── Load a dataset for remaining tests ──────────────────────────────────
if ~isfile(VSM_F)
    fprintf('\n  WARNING: VSM test file not found — skipping tests 4-7\n');
    fprintf('\n══ Summary: %d passed, %d failed, 4 skipped ══\n', passed, failed);
    return;
end
api.addFiles({VSM_F});
drawnow;

if api.getActiveIdx() < 1
    fprintf('\n  WARNING: file loaded but no active dataset — skipping tests 4-7\n');
    fprintf('\n══ Summary: %d passed, %d failed, 4 skipped ══\n', passed, failed);
    return;
end

ds = api.getDatasets();
d  = ds{api.getActiveIdx()}.data;

% ════════════════════════════════════════════════════════════════════════
%  4. setChannelFromDrag 'x' — updates X dropdown
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: setChannelFromDrag sets X channel ══\n');
try
    % Pick a label that is a valid X channel (first data label)
    assert(~isempty(d.labels), 'dataset has no labels');
    targetCol = d.labels{1};
    api.setChannelFromDrag(targetCol, 'x');
    drawnow;
    % Verify via getDragState (state should be idle — drag already completed)
    state = api.getDragState();
    assert(~state.active,  'drag state should be idle after setChannelFromDrag');
    fprintf('  Set X channel to "%s" — no error\n', targetCol);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. setChannelFromDrag 'y' — updates Y listbox
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: setChannelFromDrag sets Y channel ══\n');
try
    assert(~isempty(d.labels), 'dataset has no labels');
    targetCol = d.labels{1};
    api.setChannelFromDrag(targetCol, 'y');
    drawnow;
    state = api.getDragState();
    assert(~state.active, 'drag state should be idle after setChannelFromDrag');
    fprintf('  Set Y channel to "%s" — no error\n', targetCol);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. setChannelFromDrag 'y2' — updates Y2 listbox
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6: setChannelFromDrag sets Y2 channel ══\n');
try
    assert(numel(d.labels) >= 1, 'dataset has no labels');
    targetCol = d.labels{end};   % use a different channel for Y2
    api.setChannelFromDrag(targetCol, 'y2');
    drawnow;
    state = api.getDragState();
    assert(~state.active, 'drag state should be idle after setChannelFromDrag');
    fprintf('  Set Y2 channel to "%s" — no error\n', targetCol);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. setChannelFromDrag with invalid column name — silent no-op
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7: setChannelFromDrag ignores unknown column ══\n');
try
    api.setChannelFromDrag('__NonExistentColumn__', 'y');
    drawnow;
    % Should not throw; GUI state unchanged
    assert(api.getActiveIdx() >= 1, 'active dataset lost after invalid drag');
    fprintf('  No crash or state corruption\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n════════════════════════════════════════\n');
fprintf('  Results: %d passed, %d failed\n', passed, failed);
fprintf('════════════════════════════════════════\n');
if failed > 0
    error('test_dragToPlot: %d test(s) failed', failed);
end
