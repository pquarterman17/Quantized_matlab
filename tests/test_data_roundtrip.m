%TEST_DATA_ROUNDTRIP  Verify round-trip data export: import → CSV → re-import = original
%
%   Tests that data exported to CSV via writeXRDcsv.m can be re-imported with importCSV.m
%   and recovers the original data (within tolerance).
%
%   Run standalone:  cd tests; run test_data_roundtrip
%   Run from root:   run tests/test_data_roundtrip
%
%   Each test prints PASS / FAIL and details. Cleanup is automatic via onCleanup.

clear; clc;

% Ensure toolbox is on the path
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
if ~contains(path, rootDir)
    addpath(rootDir);
end

ROOT = rootDir;
XRDML_FILE = fullfile(ROOT, '+test_datasets', 'XRDML', 'La2NiO4_1.xrdml');

% Setup temporary directory for test output files
tmpDir = fullfile(tempdir, 'roundtrip_test_' + string(datetime('now','Format','yyyyMMdd_HHmmss')));
if ~isfolder(tmpDir), mkdir(tmpDir); end
cleanupTmp = onCleanup(@() rmdir(tmpDir, 's'));

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  1. Standard CSV round-trip (cps)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: Standard CSV round-trip (cps) ══\n');
try
    % Import XRDML → write CSV → re-import
    data_orig = parser.importXRDML(XRDML_FILE, 'Intensity', 'cps');
    csvPath = fullfile(tmpDir, 'test1_roundtrip.csv');
    utilities.writeXRDcsv(data_orig, csvPath, 'Format', 'standard');

    % Re-import
    data_reimp = parser.importCSV(csvPath);

    % Verify structure
    assert(isstruct(data_reimp), 're-imported data must be a struct');
    assert(~isempty(data_reimp.time), 'time vector is empty');
    assert(~isempty(data_reimp.values), 'values matrix is empty');

    % Verify data count
    assert(numel(data_reimp.time) == numel(data_orig.time), ...
        sprintf('row count mismatch: %d vs %d', numel(data_reimp.time), numel(data_orig.time)));

    % Verify x-axis (2θ) within tolerance
    dTheta = abs(data_reimp.time - data_orig.time);
    assert(max(dTheta) < 1e-5, ...
        sprintf('max 2θ error %.2e exceeds 1e-5', max(dTheta)));

    % Verify y-axis (intensity) within relative tolerance
    relTol = 1e-4;
    intensity_max = max(abs(data_orig.values(:)));
    intensity_diff = abs(data_reimp.values(:,1) - data_orig.values(:,1));
    relErr = intensity_diff / intensity_max;
    assert(max(relErr) < relTol, ...
        sprintf('max relative intensity error %.2e exceeds %.2e', max(relErr), relTol));

    fprintf('  Data points: %d\n', numel(data_reimp.time));
    fprintf('  Max 2θ error: %.2e deg (tol: 1e-5)\n', max(dTheta));
    fprintf('  Max intensity rel. error: %.2e (tol: %.2e)\n', max(relErr), relTol);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. Standard CSV (both intensities: cps and counts)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: Standard CSV (cps + counts columns) ══\n');
try
    data_orig = parser.importXRDML(XRDML_FILE, 'Intensity', 'cps');
    csvPath = fullfile(tmpDir, 'test2_both_intensities.csv');
    utilities.writeXRDcsv(data_orig, csvPath, 'Format', 'standard');

    data_reimp = parser.importCSV(csvPath);

    % Should have 2 intensity columns (cps and counts)
    assert(size(data_reimp.values, 2) >= 2, ...
        sprintf('expected >= 2 data columns, got %d', size(data_reimp.values, 2)));

    fprintf('  Data columns: %d (%s)\n', size(data_reimp.values, 2), strjoin(data_reimp.labels, ', '));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Standard CSV (counts only)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: Standard CSV (counts only) ══\n');
try
    data_orig = parser.importXRDML(XRDML_FILE, 'Intensity', 'counts');
    csvPath = fullfile(tmpDir, 'test3_counts_only.csv');
    utilities.writeXRDcsv(data_orig, csvPath, 'Format', 'standard', 'Intensity', 'counts');

    data_reimp = parser.importCSV(csvPath);

    % importCSV strips units into .units; check units not labels
    assert(any(contains(data_reimp.units, 'counts', 'IgnoreCase', true)), ...
        sprintf('expected "counts" in units: %s', strjoin(data_reimp.units, ', ')));

    fprintf('  Label: %s  Unit: %s\n', data_reimp.labels{1}, data_reimp.units{1});
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. No metadata header
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: No metadata header ══\n');
try
    data_orig = parser.importXRDML(XRDML_FILE);
    csvPath = fullfile(tmpDir, 'test4_no_metadata.csv');
    utilities.writeXRDcsv(data_orig, csvPath, 'Format', 'standard', 'IncludeMetadata', false);

    % Verify first line does NOT start with '#'
    fid = fopen(csvPath, 'r');
    firstLine = fgetl(fid);
    fclose(fid);

    assert(~startsWith(firstLine, '#'), ...
        sprintf('expected no metadata header, but first line starts with ''#'': %s', firstLine(1:min(20, end))));

    % Re-import should still succeed
    data_reimp = parser.importCSV(csvPath);
    assert(~isempty(data_reimp.time), 'time vector is empty after re-import');

    fprintf('  First line: %s...\n', firstLine(1:min(40, end)));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. Column header and unit extraction
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: Column header and unit extraction ══\n');
try
    data_orig = parser.importXRDML(XRDML_FILE);
    csvPath = fullfile(tmpDir, 'test5_units.csv');
    utilities.writeXRDcsv(data_orig, csvPath, 'Format', 'standard');

    data_reimp = parser.importCSV(csvPath);

    % Units should be extracted (cps or counts)
    assert(~isempty(data_reimp.units), 'units are empty');
    assert(any(strcmpi(data_reimp.units, 'cps')) || any(strcmpi(data_reimp.units, 'counts')), ...
        sprintf('expected cps or counts in units: %s', strjoin(data_reimp.units, ', ')));

    % Labels should be non-empty
    assert(~isempty(data_reimp.labels), 'labels are empty');

    fprintf('  Labels: %s\n', strjoin(data_reimp.labels, ', '));
    fprintf('  Units: %s\n', strjoin(data_reimp.units, ', '));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. X-axis range preserved
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6: X-axis range preserved ══\n');
try
    data_orig = parser.importXRDML(XRDML_FILE);
    csvPath = fullfile(tmpDir, 'test6_xrange.csv');
    utilities.writeXRDcsv(data_orig, csvPath, 'Format', 'standard');

    data_reimp = parser.importCSV(csvPath);

    xMin_orig = min(data_orig.time);
    xMax_orig = max(data_orig.time);
    xMin_reimp = min(data_reimp.time);
    xMax_reimp = max(data_reimp.time);

    assert(abs(xMin_reimp - xMin_orig) < 1e-5, ...
        sprintf('x min mismatch: %.6f vs %.6f', xMin_reimp, xMin_orig));
    assert(abs(xMax_reimp - xMax_orig) < 1e-5, ...
        sprintf('x max mismatch: %.6f vs %.6f', xMax_reimp, xMax_orig));

    fprintf('  Original 2θ range: %.4f to %.4f\n', xMin_orig, xMax_orig);
    fprintf('  Re-imported 2θ range: %.4f to %.4f\n', xMin_reimp, xMax_reimp);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. importAuto dispatch
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7: importAuto dispatch ══\n');
try
    data_orig = parser.importXRDML(XRDML_FILE);
    csvPath = fullfile(tmpDir, 'test7_autoimport.csv');
    utilities.writeXRDcsv(data_orig, csvPath, 'Format', 'standard');

    % Dispatch via importAuto
    [data_auto, parserName] = parser.importAuto(csvPath);

    assert(strcmp(parserName, 'importCSV'), ...
        sprintf('expected parser name ''importCSV'', got ''%s''', parserName));
    assert(numel(data_auto.time) == numel(data_orig.time), 'row count mismatch');

    fprintf('  Parser: %s\n', parserName);
    fprintf('  Data points: %d\n', numel(data_auto.time));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  8. Origin format round-trip
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 8: Origin ASCII format round-trip ══\n');
try
    data_orig = parser.importXRDML(XRDML_FILE);
    csvPath = fullfile(tmpDir, 'test8_origin_format.csv');
    % Write without metadata so structure is exactly 3 header rows + data
    utilities.writeXRDcsv(data_orig, csvPath, 'Format', 'Origin', 'IncludeMetadata', false);

    % Origin format: 3 header rows (Name/Units/Designation) then tab-delimited data.
    % Use fileread + regexp to avoid any delimiter auto-detection ambiguity.
    rawText8 = fileread(csvPath);
    allLines8 = regexp(rawText8, '\r?\n', 'split');
    allLines8 = allLines8(~cellfun(@(l) isempty(strtrim(l)), allLines8));

    nDataLines = numel(allLines8) - 3;   % 3 header rows
    assert(nDataLines == numel(data_orig.time), ...
        sprintf('row count mismatch: %d vs %d', nDataLines, numel(data_orig.time)));

    % Spot-check first and last data rows for value accuracy
    relTol = 1e-4;
    intensity_max = max(abs(data_orig.values(:)));
    for chkIdx = [1, numel(data_orig.time)]
        parts = strsplit(strtrim(allLines8{3 + chkIdx}), char(9));
        assert(numel(parts) >= 2, 'expected >= 2 tab-separated columns in data row');
        chkX = str2double(parts{1});
        chkI = str2double(parts{2});
        assert(abs(chkX - data_orig.time(chkIdx)) < 1e-5, ...
            sprintf('x mismatch at row %d: %.6f vs %.6f', chkIdx, chkX, data_orig.time(chkIdx)));
        assert(abs(chkI - data_orig.values(chkIdx,1)) / intensity_max < relTol, ...
            sprintf('intensity mismatch at row %d', chkIdx));
    end

    fprintf('  Points: %d\n', nDataLines);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  9. Metadata parserName update (should be importCSV after re-import)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 9: Metadata parserName after re-import ══\n');
try
    data_orig = parser.importXRDML(XRDML_FILE);
    csvPath = fullfile(tmpDir, 'test9_metadata.csv');
    utilities.writeXRDcsv(data_orig, csvPath, 'Format', 'standard');

    data_reimp = parser.importCSV(csvPath);

    % After re-import via importCSV, parserName should be 'importCSV'
    assert(isfield(data_reimp, 'metadata'), 'missing metadata field');
    assert(isfield(data_reimp.metadata, 'parserName'), 'missing parserName');
    assert(strcmp(data_reimp.metadata.parserName, 'importCSV'), ...
        sprintf('expected parserName ''importCSV'', got ''%s''', data_reimp.metadata.parserName));

    fprintf('  Original parser: %s\n', data_orig.metadata.parserName);
    fprintf('  Re-import parser: %s\n', data_reimp.metadata.parserName);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  10. Large count precision (counts > 10000)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 10: Large count precision (counts > 10000) ══\n');
try
    data_orig = parser.importXRDML(XRDML_FILE, 'Intensity', 'counts');

    % Find columns with counts > 10000
    maxCounts = max(data_orig.values(:));

    if maxCounts > 10000
        csvPath = fullfile(tmpDir, 'test10_large_counts.csv');
        utilities.writeXRDcsv(data_orig, csvPath, 'Format', 'standard', 'Intensity', 'counts');

        data_reimp = parser.importCSV(csvPath);

        % For large values, relative tolerance should be tight
        relTol = 1e-5;
        highIdx = data_orig.values(:,1) > 10000;
        if any(highIdx)
            relErr = abs(data_reimp.values(highIdx, 1) - data_orig.values(highIdx, 1)) ./ data_orig.values(highIdx, 1);
            assert(max(relErr) < relTol, ...
                sprintf('precision loss for large counts: max rel. error %.2e > %.2e', max(relErr), relTol));
        end

        fprintf('  Max counts: %.0f\n', maxCounts);
        fprintf('  PASS\n');
        passed = passed + 1;
    else
        fprintf('  SKIP (max counts %.0f <= 10000)\n', maxCounts);
    end
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
    error('test_data_roundtrip:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end
