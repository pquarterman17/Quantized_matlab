%TEST_WORKSPACEMODEL  Unit tests for dataWorkspace.WorkspaceModel.
%
%   Tests:
%     A. addDataset / count
%     B. removeDataset / count / activeIdx clamp
%     C. setActive / getData
%     D. Mask set / get
%     E. Undo push / pop
%     F. Event firing (DataChanged, SelectionChanged, MaskChanged)
%     G. Error conditions (bad index, mask size mismatch, pop empty)
%
%   Run via: runAllTests(Group="workspace")
%   Or:      addpath(pwd); setupToolbox; run('tests/workspace/test_workspaceModel')

clear; clc;

% ── Path setup ────────────────────────────────────────────────────────────
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  A. addDataset / count
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST A: addDataset / count ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    assert(model.count() == 0, 'initial count should be 0');

    d1 = makeData(10, 'ds1');
    model.addDataset(d1, 'ds1.dat', 'importCSV');
    assert(model.count() == 1, 'count should be 1 after first add');
    assert(model.activeIdx == 1, 'first dataset should auto-activate');

    d2 = makeData(5, 'ds2');
    model.addDataset(d2, 'ds2.dat', 'importCSV');
    assert(model.count() == 2, 'count should be 2 after second add');
    assert(model.activeIdx == 1, 'activeIdx should remain 1 after second add');

    % Metadata from the struct itself is preserved (addDataset does not
    % overwrite fields that are already populated).
    assert(strcmp(model.datasets{1}.metadata.source, 'ds1.dat'), ...
        'source should be preserved from original struct');
    % makeData already set parserName='test'; addDataset does not overwrite.
    assert(strcmp(model.datasets{1}.metadata.parserName, 'test'), ...
        'existing parserName should not be overwritten by addDataset');

    % Verify that addDataset DOES stamp an empty parserName field.
    d3 = makeData(3, 'ds3');
    d3.metadata.parserName = '';   % force empty so addDataset will stamp it
    model.addDataset(d3, 'ds3.dat', 'importCSV');
    assert(strcmp(model.datasets{3}.metadata.parserName, 'importCSV'), ...
        'addDataset should stamp parserName when field is empty');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  B. removeDataset / count / activeIdx clamp
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST B: removeDataset / activeIdx clamp ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(3, 'x1'), 'x1.dat', '');
    model.addDataset(makeData(3, 'x2'), 'x2.dat', '');
    model.addDataset(makeData(3, 'x3'), 'x3.dat', '');
    model.setActive(3);

    model.removeDataset(3);   % remove the active one
    assert(model.count() == 2, 'count should be 2 after remove');
    assert(model.activeIdx == 2, 'activeIdx should clamp to 2');

    model.removeDataset(1);   % remove first
    assert(model.count() == 1);
    assert(model.activeIdx == 1, 'activeIdx should re-clamp to 1');

    model.removeDataset(1);   % remove last
    assert(model.count() == 0, 'count should be 0');
    assert(model.activeIdx == 0, 'activeIdx should be 0 when empty');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  C. setActive / getData
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST C: setActive / getData ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(8, 'c1'), '', '');
    model.addDataset(makeData(12, 'c2'), '', '');

    model.setActive(2);
    assert(model.activeIdx == 2, 'activeIdx should be 2');

    ret = model.getData(2);
    assert(numel(ret.time) == 12, 'getData(2) should return 12-row dataset');

    model.setActive(1);
    ret = model.getData(1);
    assert(numel(ret.time) == 8, 'getData(1) should return 8-row dataset');

    % getData prefers corrData when present
    model2 = dataWorkspace.WorkspaceModel();
    d3 = makeData(5, 'c3');
    d3.corrData = makeData(4, 'c3corr');  % synthetic corrected version
    model2.addDataset(d3, '', '');
    ret3 = model2.getData(1);
    assert(numel(ret3.time) == 4, 'getData should prefer corrData when available');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  D. Mask set / get
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST D: mask set / get ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(10, 'm1'), '', '');

    % Default mask: all true
    m = model.mask{1};
    assert(all(m), 'default mask should be all true');
    assert(numel(m) == 10, 'mask length should equal row count');

    % Set a partial mask
    newMask = true(10, 1);
    newMask([2 5 8]) = false;
    model.setMask(1, newMask);

    m2 = model.mask{1};
    assert(sum(~m2) == 3, '3 rows should be masked');
    assert(~m2(2) && ~m2(5) && ~m2(8), 'rows 2,5,8 should be masked');

    % Size mismatch should error
    errFired = false;
    try
        model.setMask(1, true(5, 1));
    catch
        errFired = true;
    end
    assert(errFired, 'wrong-size mask should error');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  E. Undo push / pop
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST E: pushUndo / popUndo ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(6, 'u1'), 'u1.dat', '');
    model.addDataset(makeData(6, 'u2'), 'u2.dat', '');

    % Snapshot state before a change
    model.pushUndo('before mask change');
    assert(numel(model.undoStack) == 1, 'undoStack should have 1 entry');

    % Apply a change
    model.setMask(1, false(6, 1));
    assert(all(~model.mask{1}), 'all rows should be masked');

    % Pop restores
    snap = model.popUndo();
    assert(all(model.mask{1}), 'mask should be restored after popUndo');
    assert(strcmp(snap.label, 'before mask change'), 'label should be preserved');
    assert(isempty(model.undoStack), 'undoStack should be empty after pop');

    % Pop from empty should error
    errFired = false;
    try
        model.popUndo();
    catch
        errFired = true;
    end
    assert(errFired, 'popUndo on empty stack should error');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  F. Event firing
%
%  Use containers.Map as a mutable counter reachable from listener
%  callbacks.  containers.Map has handle semantics, so the bump is
%  visible to all references — including listeners that fire from inside
%  the event notification machinery, which do not share the script
%  workspace with the main code.
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST F: event firing ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    ctr   = containers.Map({'data','sel','mask'}, {0, 0, 0});

    lsnD = addlistener(model, 'DataChanged',      @(~,~) bumpCtr(ctr,'data'));
    lsnS = addlistener(model, 'SelectionChanged', @(~,~) bumpCtr(ctr,'sel'));
    lsnM = addlistener(model, 'MaskChanged',      @(~,~) bumpCtr(ctr,'mask'));

    model.addDataset(makeData(4, 'e1'), '', '');
    assert(ctr('data') == 1, 'DataChanged should fire on addDataset');
    assert(ctr('sel')  == 0, 'SelectionChanged should NOT fire on addDataset');

    model.setActive(1);
    assert(ctr('sel') == 1, 'SelectionChanged should fire on setActive');

    model.setMask(1, false(4, 1));
    assert(ctr('mask') == 1, 'MaskChanged should fire on setMask');

    model.addDataset(makeData(4, 'e2'), '', '');
    assert(ctr('data') == 2, 'DataChanged should fire on second addDataset');

    model.removeDataset(2);
    assert(ctr('data') == 3, 'DataChanged should fire on removeDataset');

    % popUndo fires DataChanged + SelectionChanged
    model.pushUndo('test');
    prevDC = ctr('data');
    prevSC = ctr('sel');
    model.popUndo();
    assert(ctr('data') == prevDC + 1, 'DataChanged should fire on popUndo');
    assert(ctr('sel')  == prevSC + 1, 'SelectionChanged should fire on popUndo');

    delete(lsnD); delete(lsnS); delete(lsnM);

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  G. Error conditions
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST G: error conditions ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(5, 'g1'), '', '');

    % Bad removeDataset index
    ok = false;
    try, model.removeDataset(99); catch, ok = true; end
    assert(ok, 'removeDataset(99) should error');

    % Bad setActive index
    ok = false;
    try, model.setActive(99); catch, ok = true; end
    assert(ok, 'setActive(99) should error');

    % Bad getData index
    ok = false;
    try, model.getData(0); catch, ok = true; end
    assert(ok, 'getData(0) should error');

    % Bad setMask index
    ok = false;
    try, model.setMask(99, true(5,1)); catch, ok = true; end
    assert(ok, 'setMask(99,...) should error');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════

fprintf('\n════════════════════════════════\n');
fprintf('  Results: %d passed, %d failed\n', passed, failed);
fprintf('════════════════════════════════\n\n');

if failed > 0
    error('test_workspaceModel:failures', '%d test(s) failed.', failed);
end

% ════════════════════════════════════════════════════════════════════════
%  Local functions  (must appear after all script executable code)
% ════════════════════════════════════════════════════════════════════════

function d = makeData(n, tag)
%MAKEDATA  Build a minimal valid unified data struct with n rows.
    d = parser.createDataStruct( ...
        (1:n)', rand(n, 2), ...
        'labels',   {['A_' tag], ['B_' tag]}, ...
        'units',    {'Oe', 'emu'}, ...
        'metadata', struct('source', [tag '.dat'], 'parserName', 'test'));
end

function bumpCtr(ctr, key)
%BUMPCTR  Increment a containers.Map counter.
%   containers.Map has handle semantics so the change propagates to all
%   references — safe to call from within addlistener callbacks.
    ctr(key) = ctr(key) + 1;
end
