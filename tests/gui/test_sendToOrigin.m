%TEST_SENDTOORIGIN  Multi-dataset Send to Origin via MockOriginCom.
%   Verifies worksheet-per-dataset and combined layouts without OriginPro.
%   Must run headless (QUANTIZED_MATLAB_HEADLESS=1) so the success uialert
%   logs instead of blocking — runAllTests(Group="gui") sets this.
%
%   Run standalone:  run tests/gui/test_sendToOrigin

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir), addpath(rootDir); end
utilDir = fullfile(rootDir, 'tests', 'utilities');
if ~contains(path, utilDir), addpath(utilDir); end

passed = 0;
failed = 0;

fig = uifigure('Visible', 'off');
cleanupFig = onCleanup(@() delete(fig)); %#ok<NASGU>

% Two generic datasets, different lengths (so combined NaN-padding is exercised)
appData = bosonPlotter.AppState();
appData.datasets = { ...
    makeDs('alpha.csv', (1:4)', (10:10:40)'), ...
    makeDs('beta.csv',  (1:3)', (11:10:31)') };
appData.activeIdx = 1;

% ════════════════════════════════════════════════════════════════════════
%  1. One worksheet per dataset
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 1: one worksheet per dataset ==\n');
try
    mock = MockOriginCom();
    gs = struct('mode','sheets','selIdx',[1 2],'originObj',mock, ...
                'logX',false,'logY',false,'xLabel','','yLabel','');
    bosonPlotter.sendToOrigin(appData, fig, gs);

    nBook  = countCalls(mock, 'Execute', 'newbook');
    nSheet = countCalls(mock, 'Execute', 'newsheet');
    nPut   = countCalls(mock, 'PutWorksheet', '');
    assert(nBook == 1,  sprintf('expected 1 newbook, got %d', nBook));
    assert(nSheet == 1, sprintf('expected 1 newsheet (2nd dataset), got %d', nSheet));
    assert(nPut == 2,   sprintf('expected 2 PutWorksheet, got %d', nPut));
    fprintf('  PASS (newbook=%d newsheet=%d put=%d)\n', nBook, nSheet, nPut);
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. Combined into one worksheet
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 2: combined into one worksheet ==\n');
try
    mock = MockOriginCom();
    gs = struct('mode','combined','selIdx',[1 2],'originObj',mock, ...
                'logX',false,'logY',false,'xLabel','','yLabel','');
    bosonPlotter.sendToOrigin(appData, fig, gs);

    assert(countCalls(mock,'Execute','newbook') == 1, 'combined should create one book');
    assert(countCalls(mock,'Execute','newsheet') == 0, 'combined should not add sheets');
    putIdx = mock.findCall('PutWorksheet');
    assert(putIdx > 0, 'combined should PutWorksheet once');
    sz = mock.Calls{putIdx}{3};
    % each dataset = X + 1 Y = 2 cols; two datasets → 4 cols; rows = max len (4)
    assert(sz(2) == 4, sprintf('combined matrix should have 4 cols, got %d', sz(2)));
    assert(sz(1) == 4, sprintf('combined matrix rows should be 4 (max length), got %d', sz(1)));
    nX = countCalls(mock, 'Execute', 'type = 3');
    assert(nX == 2, sprintf('combined should mark 2 X columns, got %d', nX));
    fprintf('  PASS (cols=%d rows=%d Xcols=%d)\n', sz(2), sz(1), nX);
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Single selection → one worksheet, no popup
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 3: single selection ==\n');
try
    mock = MockOriginCom();
    gs = struct('selIdx',1,'originObj',mock,'logX',false,'logY',false,'xLabel','','yLabel','');
    bosonPlotter.sendToOrigin(appData, fig, gs);
    assert(countCalls(mock,'Execute','newbook') == 1,  'one newbook');
    assert(countCalls(mock,'Execute','newsheet') == 0, 'no newsheet');
    assert(countCalls(mock,'PutWorksheet','') == 1,    'one PutWorksheet');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Worksheets get distinct, sanitised names
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 4: distinct worksheet names ==\n');
try
    mock = MockOriginCom();
    gs = struct('mode','sheets','selIdx',[1 2],'originObj',mock, ...
                'logX',false,'logY',false,'xLabel','','yLabel','');
    bosonPlotter.sendToOrigin(appData, fig, gs);
    i1 = mock.findCall('Execute', 'wks\.name\$\s*=\s*"alpha"');
    i2 = mock.findCall('Execute', 'newsheet name:="beta"');
    assert(i1 > 0, 'first worksheet named "alpha"');
    assert(i2 > 0, 'second worksheet named "beta"');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. Separate workbook per dataset ('books') — 4 datasets → 4 workbooks
%     Regression: 'sheets' mode (shared book + AddSheet) could drop datasets;
%     'books' routes each through the single-dataset newbook path.
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 5: separate workbook per dataset (4 datasets) ==\n');
try
    app4 = bosonPlotter.AppState();
    app4.datasets = { ...
        makeDs('one.csv',   (1:4)', (10:10:40)'), ...
        makeDs('two.csv',   (1:5)', (11:10:51)'), ...
        makeDs('three.csv', (1:3)', (12:10:32)'), ...
        makeDs('four.csv',  (1:6)', (13:10:63)') };
    app4.activeIdx = 1;

    mock = MockOriginCom();
    gs = struct('mode','books','selIdx',[1 2 3 4],'originObj',mock, ...
                'logX',false,'logY',false,'xLabel','','yLabel','');
    bosonPlotter.sendToOrigin(app4, fig, gs);

    nBook  = countCalls(mock, 'Execute', 'newbook');
    nSheet = countCalls(mock, 'Execute', 'newsheet');
    nPut   = countCalls(mock, 'PutWorksheet', '');
    assert(nBook == 4,  sprintf('expected 4 newbook (one per dataset), got %d', nBook));
    assert(nSheet == 0, sprintf('books mode must not add sheets, got %d newsheet', nSheet));
    assert(nPut == 4,   sprintf('expected 4 PutWorksheet, got %d', nPut));

    % All four workbook names distinct
    books = {};
    for i = 1:numel(mock.Calls)
        c = mock.Calls{i};
        if strcmp(c{1},'Execute')
            tk = regexp(c{2}, 'newbook\s+name:="([^"]+)"', 'tokens', 'once');
            if ~isempty(tk), books{end+1} = tk{1}; end %#ok<SAGROW>
        end
    end
    assert(numel(unique(books)) == 4, ...
        sprintf('expected 4 distinct workbook names, got %s', strjoin(books, ',')));
    fprintf('  PASS (newbook=%d newsheet=%d put=%d, books={%s})\n', ...
        nBook, nSheet, nPut, strjoin(books, ', '));
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. 'sheets' mode with 4 datasets → 1 book, 3 added tabs, 4 writes
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 6: one workbook, a tab per dataset (4 datasets) ==\n');
try
    app4 = bosonPlotter.AppState();
    app4.datasets = { ...
        makeDs('one.csv',   (1:4)', (10:10:40)'), ...
        makeDs('two.csv',   (1:5)', (11:10:51)'), ...
        makeDs('three.csv', (1:3)', (12:10:32)'), ...
        makeDs('four.csv',  (1:6)', (13:10:63)') };
    app4.activeIdx = 1;

    mock = MockOriginCom();
    gs = struct('mode','sheets','selIdx',[1 2 3 4],'originObj',mock, ...
                'logX',false,'logY',false,'xLabel','','yLabel','');
    bosonPlotter.sendToOrigin(app4, fig, gs);

    assert(countCalls(mock,'Execute','newbook')  == 1, 'sheets mode → exactly 1 book');
    assert(countCalls(mock,'Execute','newsheet') == 3, 'sheets mode → 3 added tabs for 4 datasets');
    assert(countCalls(mock,'PutWorksheet','')    == 4, 'sheets mode → 4 writes (one per dataset)');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════════
fprintf('\n%s\n', repmat(char(9552), 1, 72));
fprintf('SUMMARY: %d passed, %d failed\n', passed, failed);
if failed > 0
    fprintf('Status: FAIL\n');
    error('test_sendToOrigin:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end

% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function ds = makeDs(fname, x, y)
    meta = struct('parserName','importCSV','xColumnName','X','xColumnUnit','s');
    data = struct('time', x, 'values', y, ...
        'labels', {{'Signal'}}, 'units', {{'arb'}}, 'metadata', meta);
    ds = struct('filepath', fullfile(tempdir, fname), ...
        'parserName', 'importCSV', 'data', data, 'corrData', []);
end

function n = countCalls(mock, method, pattern)
    n = 0;
    for i = 1:numel(mock.Calls)
        c = mock.Calls{i};
        if ~strcmp(c{1}, method), continue; end
        if nargin < 3 || isempty(pattern)
            n = n + 1;
        elseif numel(c) >= 2 && ischar(c{2}) && ~isempty(regexp(c{2}, pattern, 'once'))
            n = n + 1;
        end
    end
end
