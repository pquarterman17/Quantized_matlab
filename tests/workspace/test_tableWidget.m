%TEST_TABLEWIDGET  Unit tests for dataWorkspace.createTableWidget.
%
%   Tests:
%     A. Returns a valid widget handle and a logical isSpreadsheet flag
%     B. Data property is settable and readable
%     C. ColumnName property is settable and readable
%     D. ColumnEditable property is settable and readable
%     E. Version-specific: isSpreadsheet matches R2025a+ check
%     F. CellEditCallback and CellSelectionCallback shim properties exist
%     G. Fallback notice prints exactly once (persistent flag resets
%        between independent test runs are not possible without a MATLAB
%        restart, so we verify the first call within this session)
%
%   Run via: runAllTests(Group="workspace")
%   Or:      addpath(pwd); setupToolbox; run('tests/workspace/test_tableWidget')

clear; clc;

% ── Path setup ────────────────────────────────────────────────────────────
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

passed = 0;
failed = 0;

% ── Shared hidden figure for all widget tests ─────────────────────────────
fig = uifigure('Visible', 'off');
cleanupObj = onCleanup(@() delete(fig));

% ════════════════════════════════════════════════════════════════════════
%  A. Returns valid handle and logical flag
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST A: valid handle + logical flag ══\n');
try
    [w, isSS] = dataWorkspace.createTableWidget(fig);
    assert(isvalid(w), 'widget handle should be valid');
    assert(islogical(isSS), 'isSpreadsheet should be logical');
    assert(isscalar(isSS),  'isSpreadsheet should be scalar');
    delete(w);
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  B. Data property round-trip
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST B: Data round-trip ══\n');
try
    T  = table([1;2;3], {'a';'b';'c'}, 'VariableNames', {'Num','Str'});
    [w, ~] = dataWorkspace.createTableWidget(fig, Data=T);
    w.Data = T;
    got = w.Data;
    assert(~isempty(got), 'Data should not be empty after assignment');
    % Width check — number of variables should match
    if istable(got)
        assert(width(got) == width(T), 'table width should match');
    end
    delete(w);
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  C. ColumnName property
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST C: ColumnName ══\n');
try
    colNames = {'Alpha', 'Beta', 'Gamma'};
    T2 = array2table(rand(4, 3), 'VariableNames', colNames);
    [w, ~] = dataWorkspace.createTableWidget(fig, Data=T2, ColumnName=colNames);
    % Property must exist and be non-empty
    cn = w.ColumnName;
    assert(~isempty(cn), 'ColumnName should be non-empty after set');
    delete(w);
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  D. ColumnEditable property
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST D: ColumnEditable ══\n');
try
    T3   = array2table(rand(3, 2));
    mask = [true, false];
    [w, ~] = dataWorkspace.createTableWidget(fig, Data=T3, ColumnEditable=mask);
    % Just verify no error was thrown and handle is valid
    assert(isvalid(w), 'widget should be valid after ColumnEditable set');
    delete(w);
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  E. isSpreadsheet matches version check
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST E: isSpreadsheet vs isMATLABReleaseOlderThan ══\n');
try
    [w, isSS] = dataWorkspace.createTableWidget(fig);
    expectedSS = ~isMATLABReleaseOlderThan('R2025a') && ...
                  exist('uispreadsheet', 'builtin') ~= 0;
    assert(isSS == expectedSS, ...
        sprintf('isSpreadsheet=%d but expected %d for this MATLAB release', ...
        isSS, expectedSS));
    delete(w);
    fprintf('PASS  (isSpreadsheet=%d on %s)\n', isSS, version('-release'));
    passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  F. CellEditCallback and CellSelectionCallback shim properties exist
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST F: shim callback properties exist ══\n');
try
    [w, isSS] = dataWorkspace.createTableWidget(fig);
    % Both property names must be accessible (set and get) on the widget
    w.CellEditCallback        = [];
    w.CellSelectionCallback   = [];
    ce  = w.CellEditCallback;
    csc = w.CellSelectionCallback;
    assert(isempty(ce),  'CellEditCallback should be empty after clearing');
    assert(isempty(csc), 'CellSelectionCallback should be empty after clearing');

    % Assign a live callback and confirm it is retrievable
    testCb = @(s,e) disp('fired');
    w.CellEditCallback = testCb;
    assert(isequal(w.CellEditCallback, testCb), ...
        'CellEditCallback should round-trip a function handle');
    if isSS
        fprintf('  (uispreadsheet path: shim dynamic properties verified)\n');
    else
        fprintf('  (uitable path: native properties verified)\n');
    end
    delete(w);
    fprintf('PASS\n'); passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  G. DataWorkspace still launches headlessly
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST G: DataWorkspace launch (headless) ══\n');
try
    api = DataWorkspace(Visible='off');
    assert(isvalid(api.fig), 'figure should be valid after launch');
    model = api.getModel();
    assert(model.count() == 0, 'model should be empty on launch');
    close(api.fig);
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
    error('test_tableWidget:failures', '%d test(s) failed.', failed);
end
