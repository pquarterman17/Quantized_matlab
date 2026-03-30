%TEST_DATACONNECTOR  Tests for scripts.dataConnector
%
%   Creates a temp CSV, starts a connector, modifies the file, and verifies
%   the callback fires.  Also tests stop() and graceful handling of a
%   non-existent file.
%
%   Run standalone:  cd tests/batch; run test_dataConnector
%   Run from root:   run tests/batch/test_dataConnector

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

tmpDir = fullfile(tempdir, ...
    ['connector_test_', char(datetime('now','Format','yyyyMMddHHmmss'))]);
mkdir(tmpDir);
cleanupTmp = onCleanup(@() rmdir(tmpDir, 's'));

passed = 0;
failed = 0;

% ── Helper: write or overwrite a CSV ──────────────────────────────────────
function writeCsv(fp, nRows)
%WRITECSV  Write a minimal valid CSV to the given path.
    fid = fopen(fp, 'w');
    fprintf(fid, 'x,y\n');
    for r = 1:nRows
        fprintf(fid, '%.4f,%.4f\n', r, rand());
    end
    fclose(fid);
end

% ════════════════════════════════════════════════════════════════════════
%  1. Callback fires when the watched file is modified
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: callback fires on file modification ══\n');
try
    fp = fullfile(tmpDir, 'live_data.csv');
    writeCsv(fp, 10);

    callbackCount = 0;
    callbackData  = [];

    c = scripts.dataConnector(fp, ...
        Interval=0.2, ...
        Callback=@(d) captureCallback(d), ...
        AutoStart=true);

    % Allow timer to take a baseline
    pause(0.35);

    % Modify the file (new row count)
    writeCsv(fp, 20);

    % Wait for the timer to fire and detect the change
    pause(0.6);

    c.stop();

    assert(callbackCount >= 1, ...
        sprintf('expected at least 1 callback, got %d', callbackCount));
    assert(~isempty(callbackData), 'callbackData should be populated');
    assert(isfield(callbackData, 'values'), 'data struct missing .values');

    fprintf('  Callback fires: %d time(s)\n', callbackCount);
    fprintf('  Rows in reloaded data: %d\n', size(callbackData.values,1));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    if exist('c','var')
        try, c.stop(); catch, end
    end
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

    % Nested capture function (modifies outer callbackCount / callbackData)
    function captureCallback(d)
        callbackCount = callbackCount + 1;
        callbackData  = d;
    end

% ════════════════════════════════════════════════════════════════════════
%  2. stop() prevents further callbacks
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: stop() prevents further callbacks ══\n');
try
    fp2 = fullfile(tmpDir, 'live_data2.csv');
    writeCsv(fp2, 5);

    count2 = 0;

    c2 = scripts.dataConnector(fp2, ...
        Interval=0.2, ...
        Callback=@(~) incrementCount(), ...
        AutoStart=true);

    pause(0.35);

    % Modify once to trigger a callback (baseline)
    writeCsv(fp2, 10);
    pause(0.5);
    countAfterFirst = count2;

    % Stop the connector
    c2.stop();
    assert(~c2.isRunning(), 'isRunning should be false after stop()');

    % Modify file again — should NOT trigger callback
    writeCsv(fp2, 15);
    pause(0.5);

    assert(count2 == countAfterFirst, ...
        sprintf('callback fired after stop(): count went from %d to %d', ...
                countAfterFirst, count2));

    fprintf('  stop() works; no callback after stop  ✓\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    if exist('c2','var')
        try, c2.stop(); catch, end
    end
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

    function incrementCount()
        count2 = count2 + 1;
    end

% ════════════════════════════════════════════════════════════════════════
%  3. Non-existent file: graceful — warning issued, no crash
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: non-existent file — graceful construction, no crash ══\n');
try
    missingPath = fullfile(tmpDir, 'does_not_exist.csv');

    % Expect a warning but NOT an error
    warnState = warning('off', 'scripts:dataConnector:fileNotFound');
    cleanupWarn = onCleanup(@() warning(warnState));

    c3 = scripts.dataConnector(missingPath, ...
        Interval=0.5, AutoStart=true);
    pause(0.2);
    c3.stop();

    assert(~isempty(c3.filePath), 'filePath field should be set');
    assert(strcmp(c3.filePath, missingPath), 'filePath should match input');

    fprintf('  Constructed without crash for missing file\n');
    fprintf('  filePath: %s\n', c3.filePath);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    if exist('c3','var')
        try, c3.stop(); catch, end
    end
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. AutoStart=false does not start timer immediately
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: AutoStart=false — timer not running until start() ══\n');
try
    fp4 = fullfile(tmpDir, 'manual_start.csv');
    writeCsv(fp4, 10);

    c4 = scripts.dataConnector(fp4, Interval=0.5, AutoStart=false);

    assert(~c4.isRunning(), 'isRunning should be false before start()');

    c4.start();
    assert(c4.isRunning(), 'isRunning should be true after start()');

    c4.stop();
    assert(~c4.isRunning(), 'isRunning should be false after stop()');

    fprintf('  AutoStart=false: not running until start()  ✓\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    if exist('c4','var')
        try, c4.stop(); catch, end
    end
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. lastModified is updated after file change
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: lastModified updated on detected change ══\n');
try
    fp5 = fullfile(tmpDir, 'timestamp_test.csv');
    writeCsv(fp5, 8);

    c5 = scripts.dataConnector(fp5, Interval=0.2, AutoStart=true);

    pause(0.35);  % Let timer establish baseline

    assert(isempty(c5.lastModified()), ...
        'lastModified should be [] before any change');

    writeCsv(fp5, 14);
    pause(0.6);

    lm = c5.lastModified();
    c5.stop();

    assert(~isempty(lm), 'lastModified should be set after file change');
    assert(isdatetime(lm), 'lastModified should be a datetime');

    fprintf('  lastModified set to: %s\n', char(lm));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    if exist('c5','var')
        try, c5.stop(); catch, end
    end
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════════
fprintf('\n%s\n', repmat(char(9552), 1, 72));
fprintf('SUMMARY: %d passed, %d failed\n', passed, failed);
if failed > 0
    fprintf('Status: FAIL\n');
    error('test_dataConnector:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end
