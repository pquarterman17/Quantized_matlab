%TEST_GENERATEREPORT  Tests for scripts.generateReport
%
%   Builds synthetic data structs and verifies that HTML and text reports
%   are produced with correct content.
%
%   Run standalone:  cd tests/batch; run test_generateReport
%   Run from root:   run tests/batch/test_generateReport

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

tmpDir = fullfile(tempdir, ...
    ['genReport_test_', char(datetime('now','Format','yyyyMMddHHmmss'))]);
mkdir(tmpDir);
cleanupTmp = onCleanup(@() rmdir(tmpDir, 's'));

passed = 0;
failed = 0;

% ── Helper: make a synthetic dataset ─────────────────────────────────────
function ds = makeSyntheticDataset(name, nPts, nChan)
%MAKESYNTHETICDATASET  Create a minimal valid data struct.
    x    = linspace(0, 10, nPts)';
    vals = rand(nPts, nChan);
    lbls = arrayfun(@(k) sprintf('ch%d', k), 1:nChan, 'UniformOutput', false);
    uts  = repmat({'a.u.'}, 1, nChan);
    meta = struct('parserName', 'test', 'sourceFile', name, ...
                  'importDate', char(datetime('now','Format','yyyy-MM-dd')));
    ds = parser.createDataStruct(x, vals, 'labels', lbls, 'units', uts, 'metadata', meta);
end

% ════════════════════════════════════════════════════════════════════════
%  1. HTML report is generated and file exists
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: HTML report created and file exists ══\n');
try
    ds1 = makeSyntheticDataset('scan_a.csv', 50, 2);
    ds2 = makeSyntheticDataset('scan_b.csv', 30, 1);

    outPath = fullfile(tmpDir, 'test1_report.html');
    reportPath = scripts.generateReport({ds1, ds2}, ...
        OutputPath=outPath, ...
        Title='Test Report 1', ...
        IncludePlots=false, ...
        Verbose=false);

    assert(isfile(reportPath), 'report file not found');
    assert(strcmp(reportPath, outPath), 'returned path mismatch');

    fprintf('  File exists: %s\n', reportPath);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. HTML report contains expected structural tags
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: HTML contains expected tags ══\n');
try
    ds1 = makeSyntheticDataset('alpha.csv', 20, 1);
    outPath = fullfile(tmpDir, 'test2_report.html');
    scripts.generateReport({ds1}, OutputPath=outPath, ...
        Title='TagCheck', IncludePlots=false, Verbose=false);

    content = fileread(outPath);

    assert(contains(content, '<!DOCTYPE html>'), 'missing DOCTYPE');
    assert(contains(content, '<html'), 'missing <html>');
    assert(contains(content, '<head>'), 'missing <head>');
    assert(contains(content, '<body>'), 'missing <body>');
    assert(contains(content, '<table'), 'missing <table>');
    assert(contains(content, '</html>'), 'missing </html>');

    fprintf('  DOCTYPE, html, head, body, table, /html: all present\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Dataset names appear in HTML report
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: dataset source filenames appear in report ══\n');
try
    ds1 = makeSyntheticDataset('xrd_scan_001.csv', 20, 1);
    ds2 = makeSyntheticDataset('vsm_hysteresis.dat', 15, 1);

    outPath = fullfile(tmpDir, 'test3_report.html');
    scripts.generateReport({ds1, ds2}, OutputPath=outPath, ...
        IncludePlots=false, Verbose=false);

    content = fileread(outPath);
    assert(contains(content, 'xrd_scan_001'), 'first dataset name not found in report');
    assert(contains(content, 'vsm_hysteresis'), 'second dataset name not found in report');

    fprintf('  Both dataset names found in report\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Title appears in HTML report
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: custom title appears in report ══\n');
try
    ds1 = makeSyntheticDataset('data.csv', 10, 1);
    outPath = fullfile(tmpDir, 'test4_report.html');
    scripts.generateReport({ds1}, OutputPath=outPath, ...
        Title='My Custom Title 2024', IncludePlots=false, Verbose=false);

    content = fileread(outPath);
    assert(contains(content, 'My Custom Title 2024'), 'title not found in report');

    fprintf('  Custom title found in HTML\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. Plain-text format produces .txt output
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: txt format output ══\n');
try
    ds1 = makeSyntheticDataset('result_a.csv', 15, 2);
    ds2 = makeSyntheticDataset('result_b.csv', 10, 1);

    outPath = fullfile(tmpDir, 'test5_report.txt');
    scripts.generateReport({ds1, ds2}, OutputPath=outPath, ...
        Format='txt', Title='Text Report', IncludePlots=false, Verbose=false);

    assert(isfile(outPath), 'txt report not created');

    content = fileread(outPath);
    assert(contains(content, 'Text Report'), 'title missing from txt');
    assert(contains(content, 'SUMMARY'), 'SUMMARY section missing');
    assert(contains(content, 'DATASET 1'), 'DATASET 1 section missing');
    assert(contains(content, 'DATASET 2'), 'DATASET 2 section missing');
    assert(contains(content, 'result_a'), 'first filename missing from txt');
    assert(contains(content, 'result_b'), 'second filename missing from txt');

    fprintf('  TXT file created with all expected sections\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. Empty datasets array: report generates (header-only)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6: empty datasets — header-only report generated ══\n');
try
    outPath = fullfile(tmpDir, 'test6_empty.html');
    scripts.generateReport({}, OutputPath=outPath, ...
        Title='Empty Report', IncludePlots=false, Verbose=false);

    assert(isfile(outPath), 'empty-dataset report file not created');

    content = fileread(outPath);
    assert(contains(content, 'Empty Report'), 'title missing');
    assert(contains(content, 'Datasets: <strong>0</strong>'), ...
        'dataset count = 0 not found');

    fprintf('  Empty report generated with correct dataset count\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. Statistics section present when IncludeStats=true
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7: statistics section included ══\n');
try
    ds1 = makeSyntheticDataset('stat_test.csv', 20, 2);
    outPath = fullfile(tmpDir, 'test7_stats.html');
    scripts.generateReport({ds1}, OutputPath=outPath, ...
        IncludeStats=true, IncludePlots=false, Verbose=false);

    content = fileread(outPath);
    assert(contains(content, 'Statistics'), 'Statistics heading not found');
    assert(contains(content, 'Min'), 'Min column header not found');
    assert(contains(content, 'Max'), 'Max column header not found');
    assert(contains(content, 'Mean'), 'Mean column header not found');

    fprintf('  Statistics section and column headers found\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  8. CustomSections content appears in report
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 8: custom section content appears in HTML ══\n');
try
    ds1 = makeSyntheticDataset('data.csv', 10, 1);
    outPath = fullfile(tmpDir, 'test8_custom.html');

    sec.title   = 'My Custom Section';
    sec.content = '<p>Custom paragraph content here.</p>';

    scripts.generateReport({ds1}, OutputPath=outPath, ...
        CustomSections={sec}, IncludePlots=false, Verbose=false);

    content = fileread(outPath);
    assert(contains(content, 'My Custom Section'), 'custom section title missing');
    assert(contains(content, 'Custom paragraph content here.'), ...
        'custom section body missing');

    fprintf('  Custom section title and body found in report\n');
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
    error('test_generateReport:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end
