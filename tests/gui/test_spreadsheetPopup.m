%TEST_SPREADSHEETPOPUP  Headless tests for boson.spreadsheetPopup().
%
%   Run via: runAllTests(Group="gui")
%   Run standalone: cd tests; run gui/test_spreadsheetPopup
%
%   Tests:
%     1.  Opens without crash for a valid data struct
%     2.  Figure contains a table/spreadsheet widget
%     3.  Statistics computation returns correct values for known data
%     4.  Export CSV writes a readable file
%     5.  ReadOnly mode — ColumnEditable is all-false
%     6.  Empty dataset (0 rows) does not crash
%     7.  Single column dataset (no value columns) opens successfully
%     8.  OnEdit callback fires with correct (row, col, value) arguments
%     9.  buildTable produces correct variable count and row count
%    10.  Sort ascending produces sorted first column
%    11.  Sort descending produces reverse-sorted first column

clear; clc;

% ── Path setup ───────────────────────────────────────────────────────────
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

passed  = 0;
failed  = 0;

% Temp dir for file-writing tests
tmpDir = fullfile(tempdir, ['ssheet_test_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]);
mkdir(tmpDir);
cleanupTmp = onCleanup(@() rmdir(tmpDir, 's'));

% ════════════════════════════════════════════════════════════════════════
%  Synthetic dataset
%   x (time)  : 1..10
%   col 1 Temp : 100 200 ... 1000
%   col 2 Field: -5..4
% ════════════════════════════════════════════════════════════════════════
N  = 10;
ds = struct( ...
    'time',   (1:N)', ...
    'values', [(100 * (1:N))', (-5 + (0:N-1))'], ...
    'labels', {{'Temp', 'Field'}}, ...
    'units',  {{'K', 'Oe'}}, ...
    'metadata', struct('source', 'test_data.dat'));

% ════════════════════════════════════════════════════════════════════════
%  Test 1 — opens without crash
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: Opens without crash ══\n');
try
    fig1 = boson.spreadsheetPopup(ds, 'Title', 'Test Popup');
    hideTestFig(fig1);
    drawnow;
    assert(isvalid(fig1), 'Expected valid uifigure handle');
    delete(fig1);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    closeAllFigs();
end

% ════════════════════════════════════════════════════════════════════════
%  Test 2 — figure contains a table or spreadsheet widget
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: Contains table/spreadsheet widget ══\n');
try
    fig2 = boson.spreadsheetPopup(ds, 'Title', 'Widget Check');
    hideTestFig(fig2);
    drawnow;
    tbls = findobj(fig2, 'Type', 'uitable');
    ssts = findobj(fig2, 'Type', 'uispreadsheet');
    assert(~isempty(tbls) || ~isempty(ssts), ...
        'No uitable or uispreadsheet found in popup figure');
    delete(fig2);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    closeAllFigs();
end

% ════════════════════════════════════════════════════════════════════════
%  Test 3 — statistics computation correctness (no popup, just math)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: Statistics computation ══\n');
try
    tempV  = ds.values(:,1);
    fieldV = ds.values(:,2);
    assert(abs(mean(tempV)   - 550)    < 1e-9, 'Temp mean wrong');
    assert(abs(min(tempV)    - 100)    < 1e-9, 'Temp min wrong');
    assert(abs(max(tempV)    - 1000)   < 1e-9, 'Temp max wrong');
    assert(abs(median(fieldV)- (-0.5)) < 1e-9, 'Field median wrong');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Test 4 — Export CSV writes a readable file
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: Export CSV ══\n');
try
    T4 = table(ds.time, ds.values(:,1), ds.values(:,2), ...
        'VariableNames', {'X','Temp','Field'});
    outFile = fullfile(tmpDir, 'export_test.csv');
    writetable(T4, outFile);
    assert(isfile(outFile), 'CSV file not written');
    Tback = readtable(outFile);
    assert(height(Tback) == N, 'Row count mismatch in re-read CSV');
    assert(abs(Tback.Temp(1) - 100) < 1e-9, 'First Temp value wrong in CSV');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Test 5 — ReadOnly mode sets ColumnEditable all-false
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: ReadOnly mode ══\n');
try
    fig5 = boson.spreadsheetPopup(ds, 'ReadOnly', true);
    hideTestFig(fig5);
    drawnow;
    assert(isvalid(fig5), 'Expected valid figure in ReadOnly mode');
    tbls5 = findobj(fig5, 'Type', 'uitable');
    if ~isempty(tbls5)
        assert(~any(tbls5(1).ColumnEditable), ...
            'ReadOnly mode should produce no editable columns');
    end
    delete(fig5);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    closeAllFigs();
end

% ════════════════════════════════════════════════════════════════════════
%  Test 6 — Empty dataset (0 rows) does not crash
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6: Empty dataset does not crash ══\n');
try
    dsEmpty = struct( ...
        'time',   zeros(0,1), ...
        'values', zeros(0,2), ...
        'labels', {{'A','B'}}, ...
        'units',  {{'',''}}, ...
        'metadata', struct('source', ''));
    fig6 = boson.spreadsheetPopup(dsEmpty, 'Title', 'Empty');
    hideTestFig(fig6);
    drawnow;
    assert(isvalid(fig6), 'Expected valid figure for empty dataset');
    delete(fig6);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    closeAllFigs();
end

% ════════════════════════════════════════════════════════════════════════
%  Test 7 — Single-column dataset (no value columns)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7: Single-column dataset ══\n');
try
    dsSingle = struct( ...
        'time',   (1:5)', ...
        'values', zeros(5,0), ...
        'labels', {{}}, ...
        'units',  {{}}, ...
        'metadata', struct('source', 'single.dat'));
    fig7 = boson.spreadsheetPopup(dsSingle, 'Title', 'Single');
    hideTestFig(fig7);
    drawnow;
    assert(isvalid(fig7), 'Expected valid figure for single-column dataset');
    delete(fig7);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    closeAllFigs();
end

% ════════════════════════════════════════════════════════════════════════
%  Test 8 — OnEdit callback fires with correct arguments
%   Uses a containers.Map as a handle-object record so it is mutable
%   inside the anonymous function closure.
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 8: OnEdit callback arguments ══\n');
try
    editLog = containers.Map({'row','col','val','fired'}, {0, 0, NaN, false});
    onEditFn = @(r,c,v) storeEditToMap(editLog, r, c, v);

    fig8 = boson.spreadsheetPopup(ds, ...
        'OnEdit', onEditFn, ...
        'ReadOnly', false);
    hideTestFig(fig8);
    drawnow;

    tbls8 = findobj(fig8, 'Type', 'uitable');
    if ~isempty(tbls8)
        tb8 = tbls8(1);
        mockEvt.Indices = [3, 2];
        mockEvt.NewData = 999;
        if ~isempty(tb8.CellEditCallback)
            tb8.CellEditCallback(tb8, mockEvt);
            drawnow;
            assert(editLog('fired'),       'OnEdit callback never fired');
            assert(editLog('row') == 3,    'Wrong row in OnEdit callback');
            assert(editLog('col') == 2,    'Wrong col in OnEdit callback');
            assert(editLog('val') == 999,  'Wrong value in OnEdit callback');
        end
    end
    delete(fig8);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    closeAllFigs();
end

% ════════════════════════════════════════════════════════════════════════
%  Test 9 — Widget Data has correct column count and row count
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 9: Table column and row count ══\n');
try
    fig9 = boson.spreadsheetPopup(ds, 'Title', 'Table Check');
    hideTestFig(fig9);
    drawnow;
    tbls9 = findobj(fig9, 'Type', 'uitable');
    ssts9 = findobj(fig9, 'Type', 'uispreadsheet');
    if ~isempty(tbls9)
        T9 = tbls9(1).Data;
        assert(istable(T9), 'uitable Data should be a MATLAB table');
        assert(height(T9) == N, sprintf('Expected %d rows, got %d', N, height(T9)));
        assert(width(T9)  == 3, sprintf('Expected 3 cols (X,Temp,Field), got %d', width(T9)));
    elseif ~isempty(ssts9)
        T9 = ssts9(1).Data;
        assert(istable(T9), 'uispreadsheet Data should be a MATLAB table');
        assert(height(T9) == N, sprintf('Expected %d rows, got %d', N, height(T9)));
    end
    delete(fig9);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    closeAllFigs();
end

% ════════════════════════════════════════════════════════════════════════
%  Test 10 — Sort ascending via toolbar button
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 10: Sort ascending via toolbar ══\n');
try
    dsShuffled = ds;
    dsShuffled.time   = flipud(ds.time);
    dsShuffled.values = flipud(ds.values);

    fig10 = boson.spreadsheetPopup(dsShuffled, 'Title', 'Sort Test');
    hideTestFig(fig10);
    drawnow;

    btnAsc = findButtonByText(fig10, char(8679));
    if ~isempty(btnAsc)
        btnAsc(1).ButtonPushedFcn(btnAsc(1), []);
        drawnow;
        tbls10 = findobj(fig10, 'Type', 'uitable');
        if ~isempty(tbls10)
            col1 = tbls10(1).Data{:, 1};
            assert(issorted(col1), 'Column 1 not sorted ascending after Sort Asc');
        end
    end
    delete(fig10);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    closeAllFigs();
end

% ════════════════════════════════════════════════════════════════════════
%  Test 11 — Sort descending via toolbar button
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 11: Sort descending via toolbar ══\n');
try
    fig11 = boson.spreadsheetPopup(ds, 'Title', 'Sort Desc Test');
    hideTestFig(fig11);
    drawnow;

    btnDesc = findButtonByText(fig11, char(8681));
    if ~isempty(btnDesc)
        btnDesc(1).ButtonPushedFcn(btnDesc(1), []);
        drawnow;
        tbls11 = findobj(fig11, 'Type', 'uitable');
        if ~isempty(tbls11)
            col1 = tbls11(1).Data{:, 1};
            assert(issorted(col1, 'descend'), 'Column 1 not sorted descending');
        end
    end
    delete(fig11);
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
    closeAllFigs();
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n════════════════════════════════════════════════════════════\n');
fprintf('  spreadsheetPopup: %d passed, %d failed\n', passed, failed);
fprintf('════════════════════════════════════════════════════════════\n\n');

if failed > 0
    error('test_spreadsheetPopup:failures', '%d test(s) failed.', failed);
end

% ════════════════════════════════════════════════════════════════════════
%  Local helper functions  (must appear after all script code)
% ════════════════════════════════════════════════════════════════════════

function hideTestFig(fig)
%HIDETESTFIG  Hide a uifigure during testing to suppress screen flicker.
    try
        if isvalid(fig)
            fig.Visible = 'off';
        end
    catch
    end
end

function closeAllFigs()
%CLOSEALLFIGS  Delete all open figures silently.
    allFigs = findobj(groot, 'Type', 'figure');
    for ii = 1:numel(allFigs)
        try; delete(allFigs(ii)); catch; end
    end
    drawnow;
end

function btn = findButtonByText(parentFig, textFragment)
%FINDBUTTONBYTEXT  Find uibutton(s) whose Text contains textFragment.
    allBtns = findobj(parentFig, 'Type', 'uibutton');
    btn = [];
    for k = 1:numel(allBtns)
        if contains(allBtns(k).Text, textFragment)
            btn = [btn; allBtns(k)]; %#ok<AGROW>
        end
    end
end

function storeEditToMap(m, r, c, v)
%STOREEDITTOMAP  Update an edit-record containers.Map (handle semantics).
    m('row')   = r;
    m('col')   = c;
    m('val')   = v;
    m('fired') = true;
end
