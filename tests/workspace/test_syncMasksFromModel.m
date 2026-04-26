%TEST_SYNCMASKSFROMMODEL  Unit tests for bosonPlotter.syncMasksFromModel.
%
%   The helper pulls row masks from a shared dataWorkspace.WorkspaceModel
%   into per-dataset working copies in appData.datasets{:}.mask. It is
%   the data-side adapter that lets DataWorkspace mask edits flow into
%   BosonPlotter's plot path.
%
%   Tests:
%     1. Mask propagates from model into an empty appData.datasets entry
%     2. Idempotence — calling sync twice with same model state returns
%        empty changedIdx the second time
%     3. Length mismatch is silently skipped (no error, no overwrite)
%     4. Empty model (count=0) is a no-op
%     5. Multiple datasets — only the changed one is reported
%
%   Run via: runAllTests(Group="workspace")

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║   bosonPlotter.syncMasksFromModel — Unit Test Suite             ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(ROOT);

passed = 0;
failed = 0;

% ─── Local fakes ─────────────────────────────────────────────────────────
function ds = makeDs(n)
    ds.data = struct('time', (1:n)', 'values', rand(n, 1), ...
                     'labels', {{'y'}}, 'units', {{''}}, 'metadata', struct());
    ds.mask = true(n, 1);
end

function ad = makeAppData(model, datasets)
    % syncMasksFromModel mutates appData.datasets in-place, so the caller
    % must hold a handle (not a struct) — match the real BosonPlotter
    % usage by instantiating bosonPlotter.AppState.
    ad = bosonPlotter.AppState();
    ad.model    = model;
    ad.datasets = datasets;
end

% ═══════════════════════════════════════════════════════════════════════
%  TEST 1: model-side mask propagates into appData.datasets{i}.mask
% ═══════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: model mask propagates ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeDs(10).data, 'ds1.dat', 'test');
    appData = makeAppData(model, {makeDs(10)});

    % Initially both sides are all-true; sync should report no change.
    changed = bosonPlotter.syncMasksFromModel(appData);
    assert(isempty(changed), 'sync should be a no-op when masks already agree');

    % DataWorkspace masks rows 3 and 7
    m = true(10, 1); m([3 7]) = false;
    model.setMask(1, m);

    changed = bosonPlotter.syncMasksFromModel(appData);
    assert(isequal(changed, 1), 'changedIdx should be [1]');
    assert(isequal(appData.datasets{1}.mask, m), ...
        'appData.datasets{1}.mask should match model mask after sync');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ═══════════════════════════════════════════════════════════════════════
%  TEST 2: idempotence — second sync sees no change
% ═══════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: sync is idempotent ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeDs(10).data, 'ds1.dat', 'test');
    m = true(10, 1); m(5) = false;
    model.setMask(1, m);
    appData = makeAppData(model, {makeDs(10)});

    changed1 = bosonPlotter.syncMasksFromModel(appData);
    assert(~isempty(changed1), 'first sync should report a change');
    changed2 = bosonPlotter.syncMasksFromModel(appData);
    assert(isempty(changed2), 'second sync should report no change');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ═══════════════════════════════════════════════════════════════════════
%  TEST 3: length mismatch silently skipped
% ═══════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: mismatched mask length is skipped, not errored ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeDs(10).data, 'ds1.dat', 'test');
    m = true(10, 1); m(2) = false;
    model.setMask(1, m);

    % appData has a 5-row dataset; model has 10 rows. Sync should skip.
    appData = makeAppData(model, {makeDs(5)});
    origMask = appData.datasets{1}.mask;
    changed = bosonPlotter.syncMasksFromModel(appData);
    assert(isempty(changed), 'mismatched length should produce no changes');
    assert(isequal(appData.datasets{1}.mask, origMask), ...
        'mismatched-length sync must NOT overwrite local mask');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ═══════════════════════════════════════════════════════════════════════
%  TEST 4: empty model is a no-op
% ═══════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: empty model → no-op ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    appData = makeAppData(model, {makeDs(10)});
    changed = bosonPlotter.syncMasksFromModel(appData);
    assert(isempty(changed), 'empty model should sync nothing');

    % Missing model entirely
    appData2 = makeAppData([], {makeDs(10)});
    changed2 = bosonPlotter.syncMasksFromModel(appData2);
    assert(isempty(changed2), 'absent model should sync nothing without erroring');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ═══════════════════════════════════════════════════════════════════════
%  TEST 5: multi-dataset — only changed datasets reported
% ═══════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: only changed datasets reported ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeDs(10).data, 'a.dat', 'test');
    model.addDataset(makeDs(10).data, 'b.dat', 'test');
    model.addDataset(makeDs(10).data, 'c.dat', 'test');

    appData = makeAppData(model, {makeDs(10), makeDs(10), makeDs(10)});

    % Touch only datasets 1 and 3
    m1 = true(10, 1); m1(4) = false;
    m3 = true(10, 1); m3([1 9]) = false;
    model.setMask(1, m1);
    model.setMask(3, m3);

    changed = bosonPlotter.syncMasksFromModel(appData);
    assert(isequal(sort(changed), [1 3]), ...
        sprintf('expected changedIdx=[1 3], got [%s]', num2str(changed)));
    assert(isequal(appData.datasets{1}.mask, m1), 'ds 1 mask should match');
    assert(all(appData.datasets{2}.mask), 'ds 2 mask should be untouched');
    assert(isequal(appData.datasets{3}.mask, m3), 'ds 3 mask should match');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ── Summary ────────────────────────────────────────────────────────────
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║ Results: %2d passed, %2d failed                                ║\n', passed, failed);
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

if failed > 0
    error('test_syncMasksFromModel: %d test(s) failed', failed);
end
