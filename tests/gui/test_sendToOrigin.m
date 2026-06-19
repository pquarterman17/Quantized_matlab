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
