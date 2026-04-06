%TEST_UNDOMANAGER  Unit tests for boson.UndoManager.
%
%   Tests the UndoManager class directly — no GUI required.
%
%   A. Push 3 entries, undo all 3: verify canUndo / canRedo
%   B. Undo then redo: verify redo restores state
%   C. Push after undo: verify redo branch is discarded
%   D. MaxSize cap: push 60 entries, verify depth capped at 50
%   E. Clear: verify empty after clear
%   F. Labels: verify undoLabel / redoLabel return expected strings
%   G. Edge cases: undo when empty, redo when at head
%   H. Custom MaxSize: verify configurable cap
%
%   Run via: runAllTests(Group="gui")

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
%  A. Push 3 entries, undo all 3
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST A1: push 3 entries then undo all 3 ══\n');
try
    mgr   = boson.UndoManager();
    calls = {};

    for k = 1:3
        n = k;  % capture loop variable
        mgr.push(struct( ...
            'type',  'test', ...
            'label', sprintf('Op %d', n), ...
            'undo',  @() appendCall(sprintf('undo%d', n)), ...
            'redo',  @() appendCall(sprintf('redo%d', n))));
    end

    assert(mgr.canUndo(),  'should be able to undo after 3 pushes');
    assert(~mgr.canRedo(), 'should not be able to redo at head');
    assert(mgr.depth() == 3, sprintf('expected depth 3, got %d', mgr.depth()));

    e3 = mgr.undo();
    assert(strcmp(e3.label, 'Op 3'), sprintf('expected Op 3, got %s', e3.label));
    assert(mgr.depth() == 2);
    e2 = mgr.undo();
    assert(strcmp(e2.label, 'Op 2'));
    e1 = mgr.undo();
    assert(strcmp(e1.label, 'Op 1'));

    assert(~mgr.canUndo(), 'nothing left to undo');
    assert(mgr.canRedo(),  'all 3 entries should be redoable');
    assert(mgr.depth() == 0);

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  B. Undo then redo
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST B1: undo then redo restores position ══\n');
try
    mgr = boson.UndoManager();
    counter = 0;

    mgr.push(struct('type','t','label','Inc', ...
        'undo', @() decrement(), ...
        'redo', @() increment()));
    counter = 1;  % simulate state after operation

    mgr.undo();
    assert(counter == 0, sprintf('undo should decrement; got %d', counter));
    assert(~mgr.canUndo(), 'stack should be empty after single undo');
    assert(mgr.canRedo(),  'redo should be available');

    mgr.redo();
    assert(counter == 1, sprintf('redo should increment; got %d', counter));
    assert(mgr.canUndo(),  'undo should be available after redo');
    assert(~mgr.canRedo(), 'redo exhausted');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  C. Push after undo discards redo branch
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST C1: push after undo discards redo entries ══\n');
try
    mgr = boson.UndoManager();

    for k = 1:3
        n = k;
        mgr.push(struct('type','t','label',sprintf('Op %d',n), ...
            'undo',@()[], 'redo',@()[]));
    end
    % Undo twice — stackPos is now 1
    mgr.undo();
    mgr.undo();
    assert(mgr.canRedo(), 'should have redo entries before new push');

    % Push a new entry — should discard the 2 redo entries
    mgr.push(struct('type','t','label','New Op', ...
        'undo',@()[], 'redo',@()[]));

    assert(~mgr.canRedo(), 'redo branch must be discarded after new push');
    assert(mgr.depth() == 2, sprintf('expected depth 2, got %d', mgr.depth()));
    assert(strcmp(mgr.stack{end}.label, 'New Op'), 'top of stack should be new op');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  D. MaxSize cap
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST D1: push 60 entries with MaxSize=50 — depth capped at 50 ══\n');
try
    mgr = boson.UndoManager(MaxSize=50);

    for k = 1:60
        n = k;
        mgr.push(struct('type','t','label',sprintf('Entry %d',n), ...
            'undo',@()[], 'redo',@()[]));
    end

    assert(mgr.depth() == 50, sprintf('expected 50, got %d', mgr.depth()));
    % Oldest entries (1-10) should have been dropped; top should be entry 60
    assert(strcmp(mgr.stack{end}.label, 'Entry 60'), 'top entry mismatch');
    % First remaining entry should be entry 11
    assert(strcmp(mgr.stack{1}.label, 'Entry 11'), ...
        sprintf('oldest entry should be Entry 11, got %s', mgr.stack{1}.label));

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  E. Clear empties the stack
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST E1: clear empties undo and redo ══\n');
try
    mgr = boson.UndoManager();
    for k = 1:5
        mgr.push(struct('type','t','label','x','undo',@()[],'redo',@()[]));
    end
    mgr.undo();  % put one entry into redo branch

    mgr.clear();

    assert(~mgr.canUndo(), 'canUndo must be false after clear');
    assert(~mgr.canRedo(), 'canRedo must be false after clear');
    assert(mgr.depth() == 0, sprintf('depth must be 0, got %d', mgr.depth()));

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  F. Labels
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST F1: undoLabel and redoLabel return correct strings ══\n');
try
    mgr = boson.UndoManager();

    % Empty manager
    assert(strcmp(mgr.undoLabel(), 'Nothing to undo'), ...
        sprintf('unexpected undoLabel: %s', mgr.undoLabel()));
    assert(strcmp(mgr.redoLabel(), 'Nothing to redo'), ...
        sprintf('unexpected redoLabel: %s', mgr.redoLabel()));

    mgr.push(struct('type','t','label','Apply Corrections', ...
        'undo',@()[], 'redo',@()[]));
    mgr.push(struct('type','t','label','Peak Edit', ...
        'undo',@()[], 'redo',@()[]));

    assert(strcmp(mgr.undoLabel(), 'Undo: Peak Edit'), ...
        sprintf('undoLabel: %s', mgr.undoLabel()));
    assert(strcmp(mgr.redoLabel(), 'Nothing to redo'), ...
        sprintf('redoLabel at head: %s', mgr.redoLabel()));

    mgr.undo();
    assert(strcmp(mgr.undoLabel(), 'Undo: Apply Corrections'), ...
        sprintf('undoLabel after 1 undo: %s', mgr.undoLabel()));
    assert(strcmp(mgr.redoLabel(), 'Redo: Peak Edit'), ...
        sprintf('redoLabel after 1 undo: %s', mgr.redoLabel()));

    mgr.undo();
    assert(strcmp(mgr.undoLabel(), 'Nothing to undo'), ...
        sprintf('undoLabel fully undone: %s', mgr.undoLabel()));
    assert(strcmp(mgr.redoLabel(), 'Redo: Apply Corrections'), ...
        sprintf('redoLabel bottom: %s', mgr.redoLabel()));

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  G. Edge cases: undo when empty, redo when at head
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST G1: undo on empty stack returns [] without error ══\n');
try
    mgr   = boson.UndoManager();
    entry = mgr.undo();
    assert(isempty(entry), 'expected [] from undo on empty stack');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

fprintf('\n══ TEST G2: redo at head returns [] without error ══\n');
try
    mgr = boson.UndoManager();
    mgr.push(struct('type','t','label','x','undo',@()[],'redo',@()[]));
    entry = mgr.redo();  % already at head
    assert(isempty(entry), 'expected [] from redo at head');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

fprintf('\n══ TEST G3: redo after full undo sequence ══\n');
try
    mgr = boson.UndoManager();
    order = {};
    for k = 1:3
        n = k;
        mgr.push(struct('type','t','label',sprintf('Op %d',n), ...
            'undo', @() recordUndo(n), ...
            'redo', @() recordRedo(n)));
    end
    % Undo all
    mgr.undo(); mgr.undo(); mgr.undo();
    % Redo all
    e1 = mgr.redo();
    e2 = mgr.redo();
    e3 = mgr.redo();
    assert(strcmp(e1.label,'Op 1') && strcmp(e2.label,'Op 2') && strcmp(e3.label,'Op 3'), ...
        'redo sequence should restore ops in original order');
    assert(~mgr.canRedo(), 'should be at head after full redo');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  H. Custom MaxSize
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST H1: custom MaxSize=3 caps at 3 entries ══\n');
try
    mgr = boson.UndoManager(MaxSize=3);
    for k = 1:5
        n = k;
        mgr.push(struct('type','t','label',sprintf('E%d',n), ...
            'undo',@()[], 'redo',@()[]));
    end
    assert(mgr.depth() == 3, sprintf('expected depth 3, got %d', mgr.depth()));
    assert(strcmp(mgr.stack{1}.label, 'E3'), ...
        sprintf('oldest entry: %s', mgr.stack{1}.label));
    assert(strcmp(mgr.stack{end}.label, 'E5'), ...
        sprintf('newest entry: %s', mgr.stack{end}.label));
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════

fprintf('\n════ UndoManager tests: %d passed, %d failed ════\n', passed, failed);
if failed > 0
    error('test_undoManager: %d test(s) failed.', failed);
end

% ════════════════════════════════════════════════════════════════════════
%  Nested helpers  (closures rely on workspace variables)
% ════════════════════════════════════════════════════════════════════════

    function appendCall(s) %#ok<DEFNU>
        calls{end+1} = s; %#ok<AGROW>
    end

    function increment()
        counter = counter + 1;
    end

    function decrement()
        counter = counter - 1;
    end

    function recordUndo(n) %#ok<DEFNU>
        order{end+1} = sprintf('undo%d', n); %#ok<AGROW>
    end

    function recordRedo(n) %#ok<DEFNU>
        order{end+1} = sprintf('redo%d', n); %#ok<AGROW>
    end
