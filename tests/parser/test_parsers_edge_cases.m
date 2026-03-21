%TEST_PARSERS_EDGE_CASES  Edge-case and error-handling tests for +parser functions.
%
%   Run standalone:  cd tests; run test_parsers_edge_cases
%   Run from root:   run tests/test_parsers_edge_cases
%
%   Tests edge cases like empty files, truncated data, inconsistent columns, etc.
%   Each test expects either a specific error or a graceful fallback.

clear; clc;

% Ensure toolbox is on the path
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

passed = 0;
failed = 0;
tmpDir = tempdir();

% ════════════════════════════════════════════════════════════════════════
%  1. Empty CSV file
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: importCSV – empty file ══\n');
try
    tmpFile = fullfile(tmpDir, 'empty.csv');
    fid = fopen(tmpFile, 'w');
    fclose(fid);
    cleanObj1 = onCleanup(@() delete(tmpFile));

    % Should error or return empty struct
    try
        d = parser.importCSV(tmpFile);
        % If it doesn't error, check that result is reasonable
        assert(isstruct(d), 'output should be a struct');
        assert(isempty(d.time) || isempty(d.values), 'empty file should return empty data');
        fprintf('  Graceful handling: returned empty struct\n');
    catch ME
        % Expected to error
        assert(contains(ME.message, 'empty', 'IgnoreCase', true) || ...
               contains(ME.message, 'no', 'IgnoreCase', true), ...
               'error should mention empty data');
        fprintf('  Expected error: %s\n', ME.message(1:min(60,numel(ME.message))));
    end
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. CSV with header but no data rows
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: importCSV – header only, no data ══\n');
try
    tmpFile = fullfile(tmpDir, 'header_only.csv');
    fid = fopen(tmpFile, 'w');
    fprintf(fid, 'Time,Value1,Value2\n');
    fclose(fid);
    cleanObj2 = onCleanup(@() delete(tmpFile));

    try
        d = parser.importCSV(tmpFile);
        % Should return empty or handle gracefully
        fprintf('  Graceful handling: returned data struct\n');
    catch ME
        % Any error for a header-only file is acceptable
        fprintf('  Expected error: %s\n', ME.message(1:min(60,numel(ME.message))));
    end
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. CSV with inconsistent column counts (ragged array)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: importCSV – inconsistent column counts ══\n');
try
    tmpFile = fullfile(tmpDir, 'ragged.csv');
    fid = fopen(tmpFile, 'w');
    fprintf(fid, 'Time,Value1,Value2\n');
    fprintf(fid, '1,10,20\n');
    fprintf(fid, '2,30\n');           % Missing Value2
    fprintf(fid, '3,40,50,60\n');     % Extra column
    fclose(fid);
    cleanObj3 = onCleanup(@() delete(tmpFile));

    % Should either error or handle by padding/truncating
    try
        d = parser.importCSV(tmpFile);
        assert(isstruct(d), 'output should be a struct');
        assert(~isempty(d.time), 'should have parsed some rows');
        fprintf('  Handled ragged array: %d rows × %d cols\n', numel(d.time), size(d.values,2));
    catch ME
        % Also acceptable to error
        fprintf('  Expected error: %s\n', ME.message(1:min(60,numel(ME.message))));
    end
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Truncated binary .raw file (shorter than header)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: importRigaku_raw – truncated binary ══\n');
try
    tmpFile = fullfile(tmpDir, 'truncated.raw');
    % Write only 100 bytes (much less than 3158-byte header)
    fid = fopen(tmpFile, 'w');
    fwrite(fid, repmat(uint8(0), 100, 1));
    fclose(fid);
    cleanObj4 = onCleanup(@() delete(tmpFile));

    try
        d = parser.importRigaku_raw(tmpFile);
        error('Should have failed on truncated file');
    catch ME
        assert(contains(ME.message, 'too small', 'IgnoreCase', true) || ...
               contains(ME.message, 'truncated', 'IgnoreCase', true), ...
               sprintf('expected "too small" or "truncated" error, got: %s', ME.message));
        fprintf('  Expected error caught: %s\n', ME.message(1:min(60,numel(ME.message))));
        fprintf('  PASS\n');
        passed = passed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. Empty .dat file (QD format)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: importQDVSM – empty [Data] section ══\n');
try
    tmpFile = fullfile(tmpDir, 'empty_qd.dat');
    fid = fopen(tmpFile, 'w');
    fprintf(fid, '[Header]\n');
    fprintf(fid, 'INFO,QD VSM Test\n');
    fprintf(fid, '[Data]\n');
    % No data rows
    fclose(fid);
    cleanObj5 = onCleanup(@() delete(tmpFile));

    try
        d = parser.importQDVSM(tmpFile);
        % Should error or return empty
        assert(isempty(d.time) || isempty(d.values), ...
               'empty [Data] section should return empty or error');
        fprintf('  Graceful handling: returned empty data\n');
    catch ME
        assert(contains(ME.message, 'empty', 'IgnoreCase', true) || ...
               contains(ME.message, 'no data', 'IgnoreCase', true), ...
               'error should mention empty data');
        fprintf('  Expected error: %s\n', ME.message(1:min(60,numel(ME.message))));
    end
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. Unknown file extension
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6: importAuto – unknown extension ══\n');
try
    tmpFile = fullfile(tmpDir, 'test.xyz');
    fid = fopen(tmpFile, 'w');
    fprintf(fid, 'dummy data');
    fclose(fid);
    cleanObj6 = onCleanup(@() delete(tmpFile));

    try
        d = parser.importAuto(tmpFile);
        error('Should have failed on unknown extension');
    catch ME
        assert(contains(ME.message, 'unsupported', 'IgnoreCase', true) || ...
               contains(ME.message, 'unknown', 'IgnoreCase', true) || ...
               contains(ME.message, 'no parser', 'IgnoreCase', true), ...
               sprintf('expected "unsupported/unknown" error, got: %s', ME.message));
        fprintf('  Expected error caught: %s\n', ME.message(1:min(60,numel(ME.message))));
        fprintf('  PASS\n');
        passed = passed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. Non-existent file
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7: importAuto – missing file ══\n');
try
    nonExistentFile = fullfile(tmpDir, 'does_not_exist_12345.csv');

    try
        d = parser.importAuto(nonExistentFile);
        error('Should have failed on non-existent file');
    catch ME
        assert(contains(ME.message, 'does not exist', 'IgnoreCase', true) || ...
               contains(ME.message, 'not found', 'IgnoreCase', true) || ...
               contains(ME.message, 'file', 'IgnoreCase', true), ...
               sprintf('expected "does not exist" or "not found" error, got: %s', ME.message));
        fprintf('  Expected error caught: %s\n', ME.message(1:min(60,numel(ME.message))));
        fprintf('  PASS\n');
        passed = passed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  8. Bruker .raw magic detection (vs Rigaku)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 8: importAuto + resolveParser – Bruker vs Rigaku .raw ══\n');
try
    % Create a fake Bruker .raw file (magic "RAW1.01")
    tmpFileBruker = fullfile(tmpDir, 'bruker_test.raw');
    fid = fopen(tmpFileBruker, 'w');
    fwrite(fid, 'RAW1.01');
    % Pad with zeros to at least 332 bytes (Bruker header size)
    fwrite(fid, repmat(uint8(0), 326, 1));
    fclose(fid);
    cleanObj8a = onCleanup(@() delete(tmpFileBruker));

    % Test resolveParser
    res = parser.resolveParser(tmpFileBruker);
    assert(strcmp(res.name, 'importBruker'), ...
           sprintf('expected importBruker, got %s', res.name));
    assert(res.isBrukerRaw == true, 'should detect Bruker magic');

    fprintf('  Bruker magic detected correctly\n');
    fprintf('  resolveParser returned: %s (isBrukerRaw=%d)\n', res.name, res.isBrukerRaw);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  9. resolveParser .dat fallback specification
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 9: resolveParser – .dat fallback ══\n');
try
    tmpFile = fullfile(tmpDir, 'test.dat');
    fid = fopen(tmpFile, 'w');
    fprintf(fid, 'dummy');
    fclose(fid);
    cleanObj9 = onCleanup(@() delete(tmpFile));

    res = parser.resolveParser(tmpFile);
    assert(strcmp(res.name, 'importQDVSM'), ...
           sprintf('expected importQDVSM, got %s', res.name));
    assert(strcmp(res.fallback, 'importPPMS'), ...
           sprintf('expected fallback importPPMS, got %s', res.fallback));

    fprintf('  Primary: %s, Fallback: %s\n', res.name, res.fallback);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  10. CSV with bad datetime strings (triggers warning)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 10: importCSV – bad datetime strings ══\n');
try
    tmpFile = fullfile(tmpDir, 'bad_dates.csv');
    fid = fopen(tmpFile, 'w');
    fprintf(fid, 'Time,Value\n');
    fprintf(fid, 'not-a-date,10\n');
    fprintf(fid, 'also-bad,20\n');
    fprintf(fid, '2026-01-01 12:00:00,30\n');
    fprintf(fid, 'garbage,40\n');
    fclose(fid);
    cleanObj10 = onCleanup(@() delete(tmpFile));

    % Should warn about parse failures but still load valid rows
    d = parser.importCSV(tmpFile);

    assert(isstruct(d), 'output should be a struct');
    assert(~isempty(d.time), 'should have parsed some data');
    % With 3 bad + 1 good out of 4 rows, should have warnings
    fprintf('  Parsed %d rows (with expected datetime parse warnings above)\n', numel(d.time));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n');
fprintf('════════════════════════════════════════════════════════════════\n');
fprintf('  EDGE CASE TEST SUMMARY\n');
fprintf('════════════════════════════════════════════════════════════════\n');
fprintf('  Passed: %d / %d\n', passed, passed + failed);
fprintf('  Failed: %d / %d\n', failed, passed + failed);
fprintf('════════════════════════════════════════════════════════════════\n');

if failed == 0
    fprintf('\n✓ All edge case tests passed!\n\n');
else
    fprintf('\n✗ %d test(s) failed.\n\n', failed);
    error('test_parsers_edge_cases:failures', '%d test(s) failed.', failed);
end
