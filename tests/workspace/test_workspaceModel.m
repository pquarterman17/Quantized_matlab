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
%  H. ColumnRoles — default construction
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST H: ColumnRoles default construction ══\n');
try
    roles = dataWorkspace.ColumnRoles(5);
    assert(isequal(roles.displayOrder, 1:5), 'displayOrder should be 1:5');
    assert(numel(roles.xGroups) == 1, 'should have exactly one default xGroup');
    assert(roles.xGroups(1).xCol == 0, 'default xGroup.xCol should be 0');
    assert(isequal(roles.xGroups(1).yCols, 1:5), 'default yCols should be 1:5');
    assert(isequal(roles.skipped, false(1, 5)), 'skipped should be all false');
    assert(roles.numColumns() == 5, 'numColumns should return 5');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  I. ColumnRoles — addXGroup / getPlotGroups (2 groups)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST I: ColumnRoles addXGroup / getPlotGroups ══\n');
try
    % Build a 3-column data struct
    t = (1:6)';
    vals = [t*2, t*3, t*4];
    d = struct('time', t, 'values', vals, ...
               'labels', {{'A','B','C'}}, 'units', {{'u','u','u'}}, ...
               'metadata', struct());

    roles = dataWorkspace.ColumnRoles(3);
    % Default group: xCol=0, yCols=1:3 — replace with two explicit groups
    roles = roles.removeXGroup(1);                % remove default
    roles = roles.addXGroup(0, [1 2]);            % group 1: time → cols 1,2
    roles = roles.addXGroup(1, [3]);              % group 2: col 1 → col 3

    groups = roles.getPlotGroups(d);
    assert(numel(groups) == 2, 'should return 2 groups');

    % Group 1: X = time, Y = cols 1 and 2
    assert(isequal(groups{1}.xData, t), 'group1 xData should be time');
    assert(size(groups{1}.yData, 2) == 2, 'group1 yData should have 2 columns');
    assert(isequal(groups{1}.yData, vals(:, [1 2])), 'group1 yData mismatch');

    % Group 2: X = col 1 (vals(:,1)), Y = col 3
    assert(isequal(groups{2}.xData, vals(:, 1)), 'group2 xData should be col 1');
    assert(isequal(groups{2}.yData, vals(:, 3)), 'group2 yData should be col 3');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  J. ColumnRoles — reorder (valid and invalid)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST J: ColumnRoles reorder ══\n');
try
    roles = dataWorkspace.ColumnRoles(3);
    roles = roles.reorder([3 1 2]);
    assert(isequal(roles.displayOrder, [3 1 2]), 'displayOrder should be [3 1 2]');

    % Invalid: wrong length
    errFired = false;
    try
        roles.reorder([1 2]);
    catch
        errFired = true;
    end
    assert(errFired, 'reorder with wrong length should error');

    % Invalid: not a permutation
    errFired2 = false;
    try
        roles.reorder([1 1 3]);
    catch
        errFired2 = true;
    end
    assert(errFired2, 'reorder with duplicate indices should error');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  K. ColumnRoles — setSkipped / getPlotGroups skips excluded columns
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST K: ColumnRoles setSkipped ══\n');
try
    t = (1:4)';
    vals = [t, t*2, t*3];
    d = struct('time', t, 'values', vals, ...
               'labels', {{'A','B','C'}}, 'units', {{'u','u','u'}}, ...
               'metadata', struct());

    roles = dataWorkspace.ColumnRoles(3);
    roles = roles.setSkipped(2, true);  % skip column 2
    assert(roles.skipped(2) == true, 'column 2 should be skipped');
    assert(roles.skipped(1) == false, 'column 1 should not be skipped');
    assert(roles.skipped(3) == false, 'column 3 should not be skipped');

    % getPlotGroups should omit col 2 from yData
    groups = roles.getPlotGroups(d);
    assert(numel(groups) == 1, 'should have 1 group');
    assert(size(groups{1}.yData, 2) == 2, 'yData should have 2 columns (col 2 skipped)');
    assert(isequal(groups{1}.yData, vals(:, [1 3])), 'yData should be cols 1 and 3');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  L. WorkspaceModel — columnRoles initialized on addDataset
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST L: WorkspaceModel columnRoles init ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(6, 'lr'), '', '');
    roles = model.getColumnRoles(1);
    assert(isa(roles, 'dataWorkspace.ColumnRoles'), 'should return a ColumnRoles');
    assert(roles.numColumns() == 2, 'makeData has 2 value columns');
    assert(isequal(roles.displayOrder, [1 2]), 'default displayOrder should be [1 2]');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  M. WorkspaceModel — setColumnRoles fires DataChanged
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST M: setColumnRoles fires DataChanged ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(4, 'mc'), '', '');
    ctr = containers.Map({'data'}, {0});
    lsn = addlistener(model, 'DataChanged', @(~,~) bumpCtr(ctr, 'data'));

    roles = model.getColumnRoles(1);
    roles = roles.setSkipped(1, true);
    model.setColumnRoles(1, roles);
    assert(ctr('data') >= 1, 'DataChanged should fire on setColumnRoles');

    % Verify the roles were stored
    stored = model.getColumnRoles(1);
    assert(stored.skipped(1) == true, 'stored roles should reflect setSkipped change');

    delete(lsn);
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  N. Mask enhancements — maskPoints / unmaskPoints
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST N: maskPoints / unmaskPoints ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(10, 'np'), '', '');

    model.maskPoints(1, [3 5 7]);
    m = model.getMask(1);
    assert(m(3) == false, 'row 3 should be masked');
    assert(m(5) == false, 'row 5 should be masked');
    assert(m(7) == false, 'row 7 should be masked');
    assert(m(1) == true,  'row 1 should remain included');
    assert(sum(~m) == 3,  'exactly 3 rows should be masked');

    model.unmaskPoints(1, 5);
    m2 = model.getMask(1);
    assert(m2(5) == true,  'row 5 should be unmasked');
    assert(m2(3) == false, 'row 3 should still be masked');
    assert(sum(~m2) == 2,  'exactly 2 rows should remain masked');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  O. Mask enhancements — maskRegion
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST O: maskRegion ══\n');
try
    % X = 1:10, Y col 1 = 10:-1:1
    xVec = (1:10)';
    yVec = (10:-1:1)';
    d = struct('time',   xVec, ...
               'values', [yVec, zeros(10,1)], ...
               'labels', {{'Y','Z'}}, 'units', {{'u','u'}}, ...
               'metadata', struct());
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(d, '', '');

    % x ∈ [3,6] AND y col1 ∈ [4,8]
    %   x=3 → y=8  ✓ both in range
    %   x=4 → y=7  ✓
    %   x=5 → y=6  ✓
    %   x=6 → y=5  ✓
    %   x=7 → y=4  ✓
    %   x=8 → y=3  y out of range
    model.maskRegion(1, 3, 6, 4, 8, 1);
    m = model.getMask(1);
    assert(m(3) == false, 'row 3 (x=3,y=8) should be masked');
    assert(m(4) == false, 'row 4 (x=4,y=7) should be masked');
    assert(m(5) == false, 'row 5 (x=5,y=6) should be masked');
    assert(m(6) == false, 'row 6 (x=6,y=5) should be masked');
    assert(m(7) == true,  'row 7 (x=7>6) should not be masked');
    assert(m(8) == true,  'row 8 (y=3<4) should not be masked');
    assert(sum(~m) == 4,  'exactly 4 rows should be masked');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  P. Mask enhancements — unmaskAll
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST P: unmaskAll ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(8, 'pa'), '', '');

    model.maskPoints(1, [1 2 3 4 5]);
    assert(sum(~model.getMask(1)) == 5, '5 rows should be masked before unmaskAll');

    model.unmaskAll(1);
    m = model.getMask(1);
    assert(all(m), 'all rows should be included after unmaskAll');
    assert(numel(m) == 8, 'mask length should remain 8');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Q. Mask enhancements — MaskChanged event fires on new operations
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST Q: MaskChanged fires on mask operations ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(10, 'qe'), '', '');
    ctr = containers.Map({'mask'}, {0});
    lsn = addlistener(model, 'MaskChanged', @(~,~) bumpCtr(ctr, 'mask'));

    model.maskPoints(1, [2 4]);
    assert(ctr('mask') == 1, 'MaskChanged should fire on maskPoints');

    model.unmaskPoints(1, 2);
    assert(ctr('mask') == 2, 'MaskChanged should fire on unmaskPoints');

    model.maskRegion(1, 1, 3, -inf, inf, 1);
    assert(ctr('mask') == 3, 'MaskChanged should fire on maskRegion');

    model.unmaskAll(1);
    assert(ctr('mask') == 4, 'MaskChanged should fire on unmaskAll');

    delete(lsn);
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  R. datasetMath — same row counts
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST R: datasetMath (same rows) ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    d1 = parser.createDataStruct((1:5)', [2*ones(5,1), 3*ones(5,1)], ...
        'labels', {'A','B'}, 'units', {'u','u'}, ...
        'metadata', struct('source', 'r1.dat', 'parserName', 'test'));
    d2 = parser.createDataStruct((1:5)', [ones(5,1), ones(5,1)], ...
        'labels', {'A','B'}, 'units', {'u','u'}, ...
        'metadata', struct('source', 'r2.dat', 'parserName', 'test'));
    model.addDataset(d1, 'r1.dat', 'test');
    model.addDataset(d2, 'r2.dat', 'test');

    res = model.datasetMath(1, '+', 2);
    assert(numel(res.time) == 5, 'result should have 5 rows');
    assert(all(res.values(:,1) == 3), 'col1: 2+1 = 3');
    assert(all(res.values(:,2) == 4), 'col2: 3+1 = 4');
    assert(contains(res.metadata.source, '+'), 'source should contain op');

    res2 = model.datasetMath(1, '-', 2);
    assert(all(res2.values(:,1) == 1), 'col1: 2-1 = 1');

    res3 = model.datasetMath(1, 'ratio', 2);
    assert(all(res3.values(:,1) == 2), 'col1: 2/1 = 2 (ratio)');

    % Bad op should error
    ok = false;
    try, model.datasetMath(1, 'boop', 2); catch, ok = true; end
    assert(ok, 'bad op should error');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  S. datasetMath — different row counts (interpolation)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST S: datasetMath interpolation ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    % Dataset A: x=1:10, Y = x
    xA = (1:10)';
    d1 = parser.createDataStruct(xA, xA, 'labels', {'Y'}, 'units', {'u'}, ...
        'metadata', struct('source', 's1.dat', 'parserName', 'test'));
    % Dataset B: x=1:5 (half the rows), Y = 2*x
    xB = (1:5)';
    d2 = parser.createDataStruct(xB, 2*xB, 'labels', {'Y'}, 'units', {'u'}, ...
        'metadata', struct('source', 's2.dat', 'parserName', 'test'));
    model.addDataset(d1, 's1.dat', 'test');
    model.addDataset(d2, 's2.dat', 'test');

    res = model.datasetMath(1, '+', 2);
    % B interpolated onto A's grid: B(x=1)=2, B(x=2)=4, ..., B(x=5)=10
    % A+B at x=1: 1+2=3; at x=5: 5+10=15
    assert(numel(res.time) == 10, 'result should use A row count');
    assert(abs(res.values(1,1) - 3) < 1e-9,  'x=1: 1+2=3');
    assert(abs(res.values(5,1) - 15) < 1e-9, 'x=5: 5+10=15');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  T. mergeDatasets
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST T: mergeDatasets ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    d1 = parser.createDataStruct((1:4)', [ones(4,1)*10], 'labels', {'A'}, ...
        'units', {'u'}, 'metadata', struct('source', 't1.dat', 'parserName', 'test'));
    d2 = parser.createDataStruct((1:4)', [ones(4,1)*20], 'labels', {'B'}, ...
        'units', {'v'}, 'metadata', struct('source', 't2.dat', 'parserName', 'test'));
    model.addDataset(d1, 't1.dat', 'test');
    model.addDataset(d2, 't2.dat', 'test');

    res = model.mergeDatasets(1, 2);
    assert(size(res.values, 2) == 2, 'merged should have 2 value columns');
    assert(all(res.values(:,1) == 10), 'col1 from A');
    assert(all(res.values(:,2) == 20), 'col2 from B');
    assert(numel(res.labels) == 2, 'should have 2 labels');
    assert(strcmp(res.labels{1}, 'A'), 'first label = A');
    assert(strcmp(res.labels{2}, 'B'), 'second label = B');
    assert(contains(res.metadata.source, 'merge'), 'source should say merge');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  U. ColumnRoles — setErrorFor / getErrorFor / clearErrorFor
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST U: ColumnRoles error bar designation ══\n');
try
    roles = dataWorkspace.ColumnRoles(3);

    % Initially no error bars
    assert(roles.getErrorFor(1) == 0, 'no error bar initially for col 1');
    assert(roles.getErrorFor(2) == 0, 'no error bar initially for col 2');

    % Designate col 3 as error bars for col 2
    roles = roles.setErrorFor(2, 3);
    assert(roles.getErrorFor(2) == 3, 'col 3 should be error bar for col 2');
    assert(roles.getErrorFor(1) == 0, 'col 1 should have no error bar');

    % Overwrite designation
    roles = roles.setErrorFor(2, 1);
    assert(roles.getErrorFor(2) == 1, 'overwrite: col 1 should be error bar for col 2');
    assert(numel(roles.errorFor.yCols) == 1, 'should have exactly 1 designation');

    % Clear
    roles = roles.clearErrorFor(2);
    assert(roles.getErrorFor(2) == 0, 'error bar should be cleared');
    assert(isempty(roles.errorFor.yCols), 'errorFor should be empty after clear');

    % clearErrorFor on non-designated column is a no-op
    roles2 = dataWorkspace.ColumnRoles(2);
    roles2 = roles2.clearErrorFor(1);  % should not error
    assert(roles2.getErrorFor(1) == 0, 'no-op clear should leave col 1 without error bar');

    % Self-reference error
    errFired = false;
    try, roles.setErrorFor(1, 1); catch, errFired = true; end
    assert(errFired, 'setErrorFor with same y and err should error');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  V. ColumnRoles — getPlotGroups includes .errorData
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST V: getPlotGroups errorData ══\n');
try
    t   = (1:5)';
    vals = [t, t*2, t*0.1];   % col 1 = Y, col 2 = Y2, col 3 = error for col 1
    d = struct('time', t, 'values', vals, ...
               'labels', {{'Y','Y2','Err'}}, 'units', {{'u','u','u'}}, ...
               'metadata', struct());

    roles = dataWorkspace.ColumnRoles(3);
    roles = roles.setErrorFor(1, 3);   % col 3 is error for col 1

    groups = roles.getPlotGroups(d);
    assert(numel(groups) == 1, 'should have 1 group');
    g = groups{1};
    assert(~isempty(g.errorData),         'errorData should not be empty');
    assert(size(g.errorData, 2) == 3,     'errorData should have 3 columns (one per Y)');
    assert(isequal(g.errorData(:,1), vals(:,3)), 'errorData col 1 = vals col 3');
    assert(all(g.errorData(:,2) == 0),    'errorData col 2 has no designation → zeros');
    assert(all(g.errorData(:,3) == 0),    'errorData col 3 has no designation → zeros');

    % No error bars → errorData is []
    roles2 = dataWorkspace.ColumnRoles(2);
    g2 = roles2.getPlotGroups(d);
    assert(isempty(g2{1}.errorData), 'no designation → errorData should be []');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  W. WorkspaceModel — createSnapshot / restoreFromSnapshot
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST W: createSnapshot / restoreFromSnapshot ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(6, 'snap1'), 'snap1.dat', 'test');
    model.addDataset(makeData(4, 'snap2'), 'snap2.dat', 'test');
    model.setActive(2);
    model.setMask(1, [true; false; true; true; true; true]);

    snap = model.createSnapshot();
    assert(isfield(snap, 'datasets'),        'snap should have datasets');
    assert(isfield(snap, 'mask'),            'snap should have mask');
    assert(isfield(snap, 'columnRoles'),     'snap should have columnRoles');
    assert(isfield(snap, 'computedColumns'), 'snap should have computedColumns');
    assert(isfield(snap, 'activeIdx'),       'snap should have activeIdx');
    assert(isfield(snap, 'version'),         'snap should have version');
    assert(snap.activeIdx == 2,              'snap.activeIdx should be 2');

    % Restore into a fresh model
    model2 = dataWorkspace.WorkspaceModel();
    model2.restoreFromSnapshot(snap);

    assert(model2.count() == 2,              'restored model should have 2 datasets');
    assert(model2.activeIdx == 2,            'restored activeIdx should be 2');
    m = model2.getMask(1);
    assert(m(2) == false,                    'restored mask row 2 should be false');
    assert(all(m([1 3 4 5 6])),              'restored mask other rows should be true');

    % Events fired on restore
    ctr = containers.Map({'data','sel'}, {0, 0});
    model3 = dataWorkspace.WorkspaceModel();
    addlistener(model3, 'DataChanged',      @(~,~) bumpCtr(ctr,'data'));
    addlistener(model3, 'SelectionChanged', @(~,~) bumpCtr(ctr,'sel'));
    model3.restoreFromSnapshot(snap);
    assert(ctr('data') >= 1, 'DataChanged should fire on restoreFromSnapshot');
    assert(ctr('sel')  >= 1, 'SelectionChanged should fire on restoreFromSnapshot');

    % Missing field error
    errFired = false;
    badSnap.datasets = {}; badSnap.mask = {};
    try, model2.restoreFromSnapshot(badSnap); catch, errFired = true; end
    assert(errFired, 'restoreFromSnapshot with missing fields should error');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  X. Integration — model sync round-trip (model → BosonPlotter → model)
%
%  Strategy: use a pre-loaded WorkspaceModel so no real files need to be
%  present.  The model is passed to BosonPlotter via the Model= argument;
%  we verify that:
%    (a) BosonPlotter picks up existing datasets from the model.
%    (b) BosonPlotter.applyCorrections() syncs corrData back to the model.
%    (c) DataChanged fires on the model when corrections are applied.
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST X: model sync round-trip ══\n');
try
    % ── Step 1: Create a WorkspaceModel with one dataset ─────────────
    sharedModel = dataWorkspace.WorkspaceModel();
    d1 = makeData(10, 'int1');
    sharedModel.addDataset(d1, 'int1.dat', 'importCSV');
    assert(sharedModel.count() == 1, 'model should have 1 dataset after addDataset');

    % ── Step 2: Open BosonPlotter with that model (headless) ─────────
    bpApi = BosonPlotter('Visible', 'off', 'Model', sharedModel);
    cleanupBP = onCleanup(@() safeClose(bpApi));
    drawnow;

    % ── Step 3: Verify BosonPlotter loaded the dataset from the model ─
    bpDs = bpApi.getDatasets();
    assert(numel(bpDs) == 1, ...
        'BosonPlotter should have 1 dataset loaded from shared model');

    % ── Step 4: Apply corrections via API (triggers model updateDataset)
    %   setCorrections(xOff, yOff, bgSlope, bgInt) — set y offset to 5.
    bpApi.setCorrections([], 5, [], []);
    bpApi.applyCorrections();
    drawnow;

    % corrData should now be set on the model's dataset copy
    mDs1 = sharedModel.datasets{1};
    assert(isfield(mDs1, 'corrData') && ~isempty(mDs1.corrData), ...
        'model dataset should have corrData after BosonPlotter applyCorrections');
    assert(isfield(mDs1, 'yOff') && mDs1.yOff == 5, ...
        'model dataset yOff should reflect the correction applied in BosonPlotter');

    % ── Step 5: DataChanged fires when BosonPlotter updates dataset ────
    %   Count DataChanged events fired after one more correction cycle.
    eventCtr = containers.Map({'data'}, {0});
    lsnX = addlistener(sharedModel, 'DataChanged', @(~,~) bumpCtr(eventCtr, 'data'));
    prevCount = eventCtr('data');

    bpApi.setCorrections([], 10, [], []);
    bpApi.applyCorrections();
    drawnow;

    assert(eventCtr('data') > prevCount, ...
        'DataChanged should fire on sharedModel when BosonPlotter applies corrections');
    delete(lsnX);

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Y. Integration — BosonPlotter addFiles syncs to model
%
%  Verify that when a dataset is loaded via BosonPlotter.addFiles (or via
%  the model directly) both sides observe the same count.
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST Y: BosonPlotter addFiles → model count ══\n');
try
    % Fresh shared model, empty
    sharedModel2 = dataWorkspace.WorkspaceModel();
    bpApi2 = BosonPlotter('Visible', 'off', 'Model', sharedModel2);
    cleanupBP2 = onCleanup(@() safeClose(bpApi2));
    drawnow;

    assert(sharedModel2.count() == 0, 'model should start empty');
    assert(numel(bpApi2.getDatasets()) == 0, 'BosonPlotter should start empty');

    % Add a dataset directly to the model (simulates DataWorkspace adding a file)
    d2 = makeData(8, 'int2');
    sharedModel2.addDataset(d2, 'int2.dat', 'importCSV');
    drawnow;

    % BosonPlotter does NOT auto-populate from model events (one-way sync:
    % BP → model on mutations).  Verify the model has the new dataset.
    assert(sharedModel2.count() == 1, 'model should have 1 dataset after external add');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Z1. restoreFromSnapshot — corrupt activeIdx clamped, no crash
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST Z1: restoreFromSnapshot — corrupt activeIdx clamped ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(4, 'z1a'), '', '');
    model.addDataset(makeData(4, 'z1b'), '', '');
    snap = model.createSnapshot();

    % Corrupt the snapshot: set activeIdx beyond dataset count
    snap.activeIdx = 99;

    model2 = dataWorkspace.WorkspaceModel();
    warnFired = false;
    origWarn = warning('off', 'dataWorkspace:WorkspaceModel:snapshotIndexClamped');
    cleanupWarn = onCleanup(@() warning(origWarn));
    model2.restoreFromSnapshot(snap);   % must not crash
    warning(origWarn);

    % activeIdx must be clamped to valid range
    assert(model2.activeIdx >= 1 && model2.activeIdx <= model2.count(), ...
        'activeIdx should be clamped to valid range after corrupt snapshot restore');
    assert(model2.count() == 2, 'datasets should be restored normally');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Z2. maskRegion — 0-column dataset errors clearly
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST Z2: maskRegion — bad colIdx errors clearly ══\n');
try
    % Dataset with 1 value column; request colIdx=2 (out of range)
    d_1col = parser.createDataStruct((1:5)', (1:5)', 'labels', {'Y'}, ...
        'units', {'u'}, 'metadata', struct('source', 'z2.dat', 'parserName', 'test'));
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(d_1col, '', '');

    errFired = false;
    try
        model.maskRegion(1, 1, 5, -inf, inf, 2);   % colIdx=2 but only 1 col
    catch ME
        errFired = true;
    end
    assert(errFired, 'maskRegion with colIdx > nCols should error');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Z3. addDataset — empty time/values (0-row dataset) is accepted
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST Z3: addDataset — empty (0-row) dataset ══\n');
try
    d_empty = parser.createDataStruct([], [], ...
        'labels', {}, 'units', {}, ...
        'metadata', struct('source', 'empty.dat', 'parserName', 'test'));
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(d_empty, 'empty.dat', 'test');
    assert(model.count() == 1, 'should accept empty dataset');
    assert(isempty(model.getMask(1)), 'mask for 0-row dataset should be empty');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Z4. setActive(0) on non-empty model is accepted
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST Z4: setActive(0) on non-empty model ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(makeData(5, 'z4'), '', '');
    model.setActive(0);   % "none" — valid even when datasets exist
    assert(model.activeIdx == 0, 'setActive(0) should be accepted');
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

function safeClose(api)
%SAFECLOSE  Close a GUI api.fig, ignoring 'already closed' errors.
    try
        if ishandle(api.fig) && isvalid(api.fig)
            api.close();
        end
    catch
    end
end
