%TEST_BATCHPLOT  Tests for scripts.batchPlot
%
%   Creates synthetic CSV files, runs batchPlot, and verifies output figures
%   are produced.  All temp files are removed on exit.
%
%   Run standalone:  cd tests/batch; run test_batchPlot
%   Run from root:   run tests/batch/test_batchPlot

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

tmpDir = fullfile(tempdir, ...
    ['batchPlot_test_', char(datetime('now','Format','yyyyMMddHHmmss'))]);
mkdir(tmpDir);
cleanupTmp = onCleanup(@() rmdir(tmpDir, 's'));

passed = 0;
failed = 0;

% ── Helpers ──────────────────────────────────────────────────────────────
function fp = writeCsv(dir_, name, nRows)
%WRITECSV  Write a minimal valid CSV to dir_/name and return its path.
    fp  = fullfile(dir_, name);
    fid = fopen(fp, 'w');
    fprintf(fid, 'x,y\n');
    for r = 1:nRows
        fprintf(fid, '%.4f,%.4f\n', r, rand());
    end
    fclose(fid);
end

% ════════════════════════════════════════════════════════════════════════
%  1. Batch plot 3 CSV files — verify 3 PNGs are produced
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: batchPlot three CSV files → PNG ══\n');
try
    d1 = fullfile(tmpDir, 'test1');  mkdir(d1);
    fp1 = writeCsv(d1, 'sample_a.csv', 20);
    fp2 = writeCsv(d1, 'sample_b.csv', 15);
    fp3 = writeCsv(d1, 'sample_c.csv', 10);

    results = scripts.batchPlot({fp1, fp2, fp3}, ...
        OutputDir=d1, Format="png", Verbose=false);

    assert(numel(results) == 3, ...
        sprintf('expected 3 results, got %d', numel(results)));

    nOk = sum([results.success]);
    assert(nOk == 3, sprintf('expected 3 successes, got %d', nOk));

    % Verify PNG files exist on disk
    for k = 1:3
        assert(isfile(results(k).outputFile), ...
            sprintf('output PNG missing: %s', results(k).outputFile));
    end

    fprintf('  PNG files created: %d / 3\n', nOk);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. results struct has required fields
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: results struct fields ══\n');
try
    d2 = fullfile(tmpDir, 'test2');  mkdir(d2);
    fp = writeCsv(d2, 'sample.csv', 10);

    results = scripts.batchPlot({fp}, OutputDir=d2, Verbose=false);

    assert(isfield(results, 'inputFile'),  'missing field: inputFile');
    assert(isfield(results, 'outputFile'), 'missing field: outputFile');
    assert(isfield(results, 'success'),    'missing field: success');
    assert(isfield(results, 'error'),      'missing field: error');

    fprintf('  All required fields present\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Non-existent file: success=false, error populated
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: non-existent file → success=false, error set ══\n');
try
    d3 = fullfile(tmpDir, 'test3');  mkdir(d3);
    badPath = fullfile(d3, 'does_not_exist.csv');

    results = scripts.batchPlot({badPath}, OutputDir=d3, Verbose=false);

    assert(numel(results) == 1, 'expected exactly 1 result');
    assert(~results(1).success, 'success should be false for missing file');
    assert(~isempty(results(1).error), 'error field should be non-empty');

    fprintf('  success=false  ✓\n');
    fprintf('  error="%s"\n', results(1).error);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Directory input: all CSV files found and plotted
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: directory input → all CSV files collected ══\n');
try
    d4 = fullfile(tmpDir, 'test4');  mkdir(d4);
    writeCsv(d4, 'data1.csv', 12);
    writeCsv(d4, 'data2.csv', 12);
    writeCsv(d4, 'data3.csv', 12);

    % Also create a non-supported file that should be ignored
    fid = fopen(fullfile(d4, 'readme.pdf'), 'w');
    fwrite(fid, 'fake'); fclose(fid);

    outDir4 = fullfile(tmpDir, 'test4_out');  mkdir(outDir4);
    results = scripts.batchPlot(d4, OutputDir=outDir4, Verbose=false);

    assert(numel(results) == 3, ...
        sprintf('expected 3 results (3 CSVs), got %d', numel(results)));
    assert(all([results.success]), 'all 3 CSVs should succeed');

    fprintf('  Files found and plotted: %d / 3\n', sum([results.success]));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. Overwrite=false: existing file is skipped (not rewritten)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: Overwrite=false skips existing output file ══\n');
try
    d5 = fullfile(tmpDir, 'test5');  mkdir(d5);
    fp = writeCsv(d5, 'sample.csv', 10);
    outFile = fullfile(d5, 'sample.png');

    % First pass: create file
    scripts.batchPlot({fp}, OutputDir=d5, Overwrite=true, Verbose=false);
    assert(isfile(outFile), 'output file not created on first pass');
    t1 = dir(outFile).datenum;

    % Wait a moment to allow timestamp to differ if file is overwritten
    pause(0.05);

    % Second pass: should skip
    scripts.batchPlot({fp}, OutputDir=d5, Overwrite=false, Verbose=false);
    t2 = dir(outFile).datenum;

    assert(t1 == t2, 'file should not have been modified (Overwrite=false)');

    fprintf('  Timestamp unchanged (skipped correctly)\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. Prefix and Suffix applied to output filename
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6: Prefix and Suffix applied to output filename ══\n');
try
    d6 = fullfile(tmpDir, 'test6');  mkdir(d6);
    fp = writeCsv(d6, 'sample.csv', 10);

    results = scripts.batchPlot({fp}, OutputDir=d6, ...
        Prefix="fig_", Suffix="_v1", Verbose=false);

    [~, outName, ~] = fileparts(results(1).outputFile);
    assert(startsWith(outName, 'fig_'), 'prefix not applied');
    assert(endsWith(outName, '_v1'), 'suffix not applied');

    fprintf('  Output name: %s  ✓\n', outName);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. Journal preset template accepted without error
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7: journal preset template (aps) accepted ══\n');
try
    d7 = fullfile(tmpDir, 'test7');  mkdir(d7);
    fp = writeCsv(d7, 'sample.csv', 10);

    results = scripts.batchPlot({fp}, OutputDir=d7, ...
        Template="aps", Format="png", Verbose=false);

    assert(results(1).success, ...
        sprintf('expected success=true, error: %s', results(1).error));
    assert(isfile(results(1).outputFile), 'output PNG missing');

    fprintf('  Template "aps" applied successfully\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
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
    error('test_batchPlot:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end
