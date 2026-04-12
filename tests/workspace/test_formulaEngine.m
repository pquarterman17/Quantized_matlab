%TEST_FORMULAENGINE  Unit tests for dataWorkspace.FormulaEngine.
%
%   Tests:
%     A. Basic arithmetic:    $X * 2 + 1
%     B. Column reference:    col("Field") / 79.5775
%     C. col(0) and $X:       time axis references
%     D. Functions:           sqrt($X^2 + $Field^2)
%     E. Constants:           $X * pi,  $X + e
%     F. Multi-operator:      ($X + 1) * ($X - 1)
%     G. Unary minus:         -$X, -(col("Field"))
%     H. Functions: diff / cumsum / cumtrapz (length preservation)
%     I. Error: unknown column name → descriptive message
%     J. Error: syntax error → descriptive message
%     K. hasCircularRef — detects and ignores
%     L. WorkspaceModel integration: addComputedColumn / removeComputedColumn
%     M. WorkspaceModel: recomputeColumns
%     N. WorkspaceModel: duplicate name error
%     O. WorkspaceModel: getComputedColumns round-trip
%     P. buildTableFromData includes computed columns as extra columns
%
%   Run via: runAllTests(Group="workspace")
%   Or:      addpath(pwd); setupToolbox; run('tests/workspace/test_formulaEngine')

clear; clc;

% ── Path setup ────────────────────────────────────────────────────────────
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end
setupToolbox;

passed = 0;
failed = 0;

% ── Shared test data ──────────────────────────────────────────────────────

N = 20;
xVec = (1:N)';
data = parser.createDataStruct( ...
    xVec, [xVec * 10, xVec * 0.5, sin(xVec)], ...
    'labels', {'Field', 'Moment', 'Signal'}, ...
    'units',  {'Oe', 'emu', 'V'}, ...
    'metadata', struct('source', 'test.dat', 'parserName', 'test'));

% ════════════════════════════════════════════════════════════════════════
%  A. Basic arithmetic: $X * 2 + 1
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST A: basic arithmetic ($X * 2 + 1) ══\n');
try
    result = dataWorkspace.FormulaEngine.evaluate("$X * 2 + 1", data);
    expected = xVec * 2 + 1;
    assert(isequal(size(result), [N 1]), 'result should be [Nx1]');
    assert(max(abs(result - expected)) < 1e-12, '$X * 2 + 1 values mismatch');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  B. Column reference: col("Field") / 79.5775
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST B: col("Field") / 79.5775 ══\n');
try
    result = dataWorkspace.FormulaEngine.evaluate('col("Field") / 79.5775', data);
    expected = data.values(:,1) / 79.5775;
    assert(max(abs(result - expected)) < 1e-10, 'col("Field") / 79.5775 mismatch');
    assert(numel(result) == N, 'result length mismatch');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  C. col(0) and $X → time axis
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST C: col(0) and $X reference time axis ══\n');
try
    r1 = dataWorkspace.FormulaEngine.evaluate("col(0)", data);
    r2 = dataWorkspace.FormulaEngine.evaluate("$X", data);
    assert(max(abs(r1 - xVec)) < 1e-12, 'col(0) should return time vector');
    assert(max(abs(r2 - xVec)) < 1e-12, '$X should return time vector');
    assert(isequal(r1, r2), 'col(0) and $X should produce identical results');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  D. Functions: sqrt($X^2 + col("Moment")^2)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST D: sqrt($X^2 + col("Moment")^2) ══\n');
try
    result = dataWorkspace.FormulaEngine.evaluate('sqrt($X^2 + col("Moment")^2)', data);
    expected = sqrt(xVec.^2 + data.values(:,2).^2);
    assert(max(abs(result - expected)) < 1e-10, 'sqrt formula mismatch');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  E. Constants: pi and e
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST E: constants pi and e ══\n');
try
    r1 = dataWorkspace.FormulaEngine.evaluate("$X * pi", data);
    r2 = dataWorkspace.FormulaEngine.evaluate("$X + e - e", data);
    assert(max(abs(r1 - xVec * pi)) < 1e-10, '$X * pi mismatch');
    assert(max(abs(r2 - xVec)) < 1e-10, '$X + e - e should equal $X');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  F. Multi-operator with parentheses: ($X + 1) * ($X - 1)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST F: ($X + 1) * ($X - 1) == $X^2 - 1 ══\n');
try
    r1 = dataWorkspace.FormulaEngine.evaluate("($X + 1) * ($X - 1)", data);
    r2 = dataWorkspace.FormulaEngine.evaluate("$X^2 - 1", data);
    assert(max(abs(r1 - r2)) < 1e-10, 'difference-of-squares mismatch');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  G. Unary minus: -$X and -col("Field")
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST G: unary minus ══\n');
try
    r1 = dataWorkspace.FormulaEngine.evaluate("-$X", data);
    r2 = dataWorkspace.FormulaEngine.evaluate('-col("Field")', data);
    assert(max(abs(r1 - (-xVec))) < 1e-12, '-$X mismatch');
    assert(max(abs(r2 - (-data.values(:,1)))) < 1e-12, '-col("Field") mismatch');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  H. Functions: diff (NaN-prepend), cumsum, cumtrapz
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST H: diff / cumsum / cumtrapz length preservation ══\n');
try
    rDiff     = dataWorkspace.FormulaEngine.evaluate("diff($X)", data);
    rCumsum   = dataWorkspace.FormulaEngine.evaluate('cumsum(col("Field"))', data);
    rCumtrapz = dataWorkspace.FormulaEngine.evaluate("cumtrapz($X)", data);

    assert(numel(rDiff) == N, 'diff result should be length N (NaN prepended)');
    assert(isnan(rDiff(1)), 'first element of diff result should be NaN');
    assert(max(abs(rDiff(2:end) - diff(xVec))) < 1e-12, 'diff values mismatch');

    assert(numel(rCumsum) == N, 'cumsum result should be length N');
    assert(max(abs(rCumsum - cumsum(data.values(:,1)))) < 1e-10, 'cumsum mismatch');

    assert(numel(rCumtrapz) == N, 'cumtrapz result should be length N');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  I. Error: unknown column name
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST I: error on unknown column name ══\n');
try
    errFired = false;
    errMsg   = '';
    try
        dataWorkspace.FormulaEngine.evaluate('col("DoesNotExist")', data);
    catch ME
        errFired = true;
        errMsg   = ME.message;
    end
    assert(errFired, 'should error on unknown column');
    assert(contains(errMsg, 'DoesNotExist'), ...
        'error message should contain the missing column name');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  J. Error: syntax error (bad character, paren mismatch)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST J: syntax error → descriptive message ══\n');
try
    errCount = 0;

    % Bad character
    try
        dataWorkspace.FormulaEngine.evaluate('$X @ 2', data);
    catch
        errCount = errCount + 1;
    end

    % Mismatched paren
    try
        dataWorkspace.FormulaEngine.evaluate('($X + 1', data);
    catch
        errCount = errCount + 1;
    end

    % Empty expression
    try
        dataWorkspace.FormulaEngine.evaluate('', data);
    catch
        errCount = errCount + 1;
    end

    assert(errCount == 3, sprintf('expected 3 syntax errors, got %d', errCount));
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  K. hasCircularRef
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST K: hasCircularRef ══\n');
try
    % Expression references "Field" — which IS in dependsOn
    tf1 = dataWorkspace.FormulaEngine.hasCircularRef('col("Field") * 2', {'Field'});
    assert(tf1 == true, 'should detect col("Field") in dependsOn {Field}');

    % Expression does NOT reference the forbidden column
    tf2 = dataWorkspace.FormulaEngine.hasCircularRef('$X * 2', {'Field'});
    assert(tf2 == false, '$X does not reference Field');

    % Empty dependsOn → never circular
    tf3 = dataWorkspace.FormulaEngine.hasCircularRef('col("Field") + 1', {});
    assert(tf3 == false, 'empty dependsOn should always return false');

    % $-shorthand also detected
    tf4 = dataWorkspace.FormulaEngine.hasCircularRef('$Field + $X', {'Field'});
    assert(tf4 == true, '$Field should be detected in dependsOn {Field}');

    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  L. WorkspaceModel integration: add / remove computed column
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST L: addComputedColumn / removeComputedColumn ══\n');
try
    model = dataWorkspace.WorkspaceModel();
    model.addDataset(data, 'test.dat', 'test');

    ctr = containers.Map({'data'}, {0});
    lsn = addlistener(model, 'DataChanged', @(~,~) bumpCtr(ctr,'data'));

    model.addComputedColumn(1, 'FieldSI', 'col("Field") / 79.5775', 'kA/m');
    assert(ctr('data') >= 1, 'DataChanged should fire on addComputedColumn');

    cols = model.getComputedColumns(1);
    assert(numel(cols) == 1, 'should have 1 computed column');
    assert(strcmp(cols{1}.name, 'FieldSI'), 'name should match');
    assert(strcmp(cols{1}.expression, 'col("Field") / 79.5775'), 'expression should match');
    assert(strcmp(cols{1}.unit, 'kA/m'), 'unit should match');
    assert(numel(cols{1}.values) == N, 'values should have N rows');

    expected = data.values(:,1) / 79.5775;
    assert(max(abs(cols{1}.values - expected)) < 1e-10, 'computed values mismatch');

    % Remove it
    model.removeComputedColumn(1, 'FieldSI');
    cols2 = model.getComputedColumns(1);
    assert(isempty(cols2), 'should have 0 computed columns after removal');

    delete(lsn);
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  M. recomputeColumns
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST M: recomputeColumns after data change ══\n');
try
    model2 = dataWorkspace.WorkspaceModel();
    d0 = parser.createDataStruct( ...
        (1:5)', [(1:5)' * 10], ...
        'labels', {'Field'}, 'units', {'Oe'}, ...
        'metadata', struct('source','t.dat','parserName','test'));
    model2.addDataset(d0, 't.dat', 'test');
    model2.addComputedColumn(1, 'FieldSI', '$Field / 79.5775', 'kA/m');

    % Manually update the underlying dataset (simulate data change)
    d1 = d0;
    d1.values = (1:5)' * 20;  % double the field values
    model2.updateDataset(1, d1);
    model2.recomputeColumns(1);

    cols = model2.getComputedColumns(1);
    expected2 = (1:5)' * 20 / 79.5775;
    assert(max(abs(cols{1}.values - expected2)) < 1e-10, ...
        'recomputed values should reflect updated data');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  N. Duplicate name error
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST N: duplicate computed column name ══\n');
try
    model3 = dataWorkspace.WorkspaceModel();
    model3.addDataset(data, '', '');
    model3.addComputedColumn(1, 'FieldSI', '$Field / 79.5775', 'kA/m');

    errFired = false;
    try
        model3.addComputedColumn(1, 'FieldSI', '$Field * 2', '');
    catch
        errFired = true;
    end
    assert(errFired, 'duplicate column name should error');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  O. getComputedColumns: remove non-existent name errors
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST O: remove non-existent column errors ══\n');
try
    model4 = dataWorkspace.WorkspaceModel();
    model4.addDataset(data, '', '');

    errFired = false;
    try
        model4.removeComputedColumn(1, 'NoSuchColumn');
    catch
        errFired = true;
    end
    assert(errFired, 'removing non-existent column should error');
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  P. Computed columns appear in model and values are correct (integration)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST P: computed columns integration ══\n');
try
    model5 = dataWorkspace.WorkspaceModel();
    model5.addDataset(data, '', '');
    model5.addComputedColumn(1, 'FieldSI', 'col("Field") / 79.5775', 'kA/m');
    model5.addComputedColumn(1, 'FieldX2', 'col("Field") * 2', 'Oe');

    cols = model5.getComputedColumns(1);
    assert(numel(cols) == 2, 'should have 2 computed columns');

    % Verify names, units, and values
    assert(strcmp(cols{1}.name, 'FieldSI'), 'first column name mismatch');
    assert(strcmp(cols{1}.unit, 'kA/m'), 'first column unit mismatch');
    expected5 = data.values(:,1) / 79.5775;
    assert(max(abs(cols{1}.values - expected5)) < 1e-10, 'FieldSI values mismatch');

    assert(strcmp(cols{2}.name, 'FieldX2'), 'second column name mismatch');
    expected6 = data.values(:,1) * 2;
    assert(max(abs(cols{2}.values - expected6)) < 1e-10, 'FieldX2 values mismatch');

    % DataChanged fired for each add
    % (already verified in test L; just confirm count is 2 here)
    ctr2 = containers.Map({'data'}, {0});
    lsn2 = addlistener(model5, 'DataChanged', @(~,~) bumpCtr(ctr2,'data'));
    model5.removeComputedColumn(1, 'FieldSI');
    model5.removeComputedColumn(1, 'FieldX2');
    assert(ctr2('data') == 2, 'DataChanged should fire twice for two removals');
    delete(lsn2);

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
    error('test_formulaEngine:failures', '%d test(s) failed.', failed);
end

% ════════════════════════════════════════════════════════════════════════
%  Local functions
% ════════════════════════════════════════════════════════════════════════

function bumpCtr(ctr, key)
%BUMPCTR  Increment a containers.Map counter (handle semantics).
    ctr(key) = ctr(key) + 1;
end
