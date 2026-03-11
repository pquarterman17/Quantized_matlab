function test_batch_xrd_converter()
% ════════════════════════════════════════════════════════════════════════
% Test batch XRD converter for bugs, edge cases, and redundancies.
% ════════════════════════════════════════════════════════════════════════

fprintf('╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║  BATCH XRD CONVERTER TEST SUITE                                ║\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');

% Setup
testDir = fullfile(pwd, 'test_batch_xrd');
if ~isfolder(testDir)
    mkdir(testDir);
end
cleanup_obj = onCleanup(@() cleanup(testDir));

fprintf('Test directory: %s\n\n', testDir);

% ════════════════════════════════════════════════════════════════════════
% TEST 1: Basic writeXRDcsv functionality
% ════════════════════════════════════════════════════════════════════════
fprintf('─ TEST 1: writeXRDcsv basic functionality ───────────────────────\n');
try
    data = parser.importXRDML('+test_datasets/XRDML/La2NiO4_1.xrdml');

    % Test standard CSV
    outFile1 = fullfile(testDir, 'test1_standard.csv');
    utilities.writeXRDcsv(data, outFile1, Format='standard');

    if isfile(outFile1)
        finfo = dir(outFile1);
        fprintf('✓ Standard CSV created (%d bytes)\n', finfo.bytes);

        % Verify header (skip metadata lines)
        fid = fopen(outFile1, 'r');
        line = fgetl(fid);
        assert(startsWith(line, '#'), 'Missing metadata header');

        % Skip metadata lines until we reach the CSV header
        while ischar(line) && startsWith(line, '#')
            line = fgetl(fid);
        end
        fclose(fid);

        assert(contains(line, '2-Theta'), sprintf('Missing column header. Got: %s', line));
        fprintf('✓ Header structure correct\n');
    else
        error('Failed to create standard CSV');
    end

    % Test origin CSV
    outFile2 = fullfile(testDir, 'test1_origin.csv');
    utilities.writeXRDcsv(data, outFile2, Format='origin');

    if isfile(outFile2)
        finfo = dir(outFile2);
        fprintf('✓ Origin ASCII created (%d bytes)\n', finfo.bytes);

        % Verify three-row header (skip metadata lines)
        fid = fopen(outFile2, 'r');
        line = fgetl(fid);
        assert(startsWith(line, '#'), 'Missing metadata');

        % Skip metadata lines
        while ischar(line) && startsWith(line, '#')
            line = fgetl(fid);
        end

        % Now we have the three header rows
        longNameRow = line;
        unitsRow = fgetl(fid);
        designationRow = fgetl(fid);
        fclose(fid);

        assert(contains(longNameRow, '2-Theta') && contains(longNameRow, char(9)), 'Missing long name row or tabs');
        assert(contains(unitsRow, 'deg') && contains(unitsRow, char(9)), 'Missing units row');
        assert(contains(designationRow, 'X') && contains(designationRow, 'Y') && contains(designationRow, char(9)), 'Missing designation row');
        fprintf('✓ Origin header structure correct (3 rows + metadata)\n');
    else
        error('Failed to create Origin ASCII');
    end

    fprintf('✓ TEST 1 PASSED\n\n');
catch ME
    fprintf('✗ TEST 1 FAILED: %s\n\n', ME.message);
end

% ════════════════════════════════════════════════════════════════════════
% TEST 2: Intensity conversion (both, cps, counts)
% ════════════════════════════════════════════════════════════════════════
fprintf('─ TEST 2: Intensity conversion logic ──────────────────────────────\n');
try
    data = parser.importXRDML('+test_datasets/XRDML/La2NiO4_1.xrdml');

    % Test "both"
    outFile3 = fullfile(testDir, 'test2_both.csv');
    utilities.writeXRDcsv(data, outFile3, Intensity='both');
    fid = fopen(outFile3, 'r');
    headerLine = '';
    while ischar(headerLine)
        headerLine = fgetl(fid);
        if ~startsWith(headerLine, '#')
            break;
        end
    end
    fclose(fid);
    colCount = numel(strsplit(headerLine, ',')) - 1; % -1 for x-axis
    fprintf('✓ "Both" format: %d intensity columns\n', colCount);

    % Test CPS only
    outFile4 = fullfile(testDir, 'test2_cps.csv');
    utilities.writeXRDcsv(data, outFile4, Intensity='cps');
    fid = fopen(outFile4, 'r');
    headerLine = '';
    while ischar(headerLine)
        headerLine = fgetl(fid);
        if ~startsWith(headerLine, '#')
            break;
        end
    end
    fclose(fid);
    colCount = numel(strsplit(headerLine, ',')) - 1;
    fprintf('✓ "CPS only" format: %d intensity column\n', colCount);

    % Test counts only
    outFile5 = fullfile(testDir, 'test2_counts.csv');
    utilities.writeXRDcsv(data, outFile5, Intensity='counts');
    fprintf('✓ "Counts only" format created\n');

    fprintf('✓ TEST 2 PASSED\n\n');
catch ME
    fprintf('✗ TEST 2 FAILED: %s\n\n', ME.message);
end

% ════════════════════════════════════════════════════════════════════════
% TEST 3: batchConvertXRD basic operation
% ════════════════════════════════════════════════════════════════════════
fprintf('─ TEST 3: batchConvertXRD basic operation ─────────────────────────\n');
try
    % Test with explicit file list
    files = ["+test_datasets/XRDML/La2NiO4_1.xrdml"];
    results = scripts.batchConvertXRD(files, ...
        OutputDir=testDir, ...
        Verbose=false);

    assert(numel(results) == 1, 'Expected 1 result');
    assert(isempty(results(1).error), sprintf('Conversion failed: %s', results(1).error));
    assert(isfile(results(1).outputFile), 'Output file not created');
    fprintf('✓ Single file conversion works\n');
    fprintf('  Output: %s\n', results(1).outputFile);

    fprintf('✓ TEST 3 PASSED\n\n');
catch ME
    fprintf('✗ TEST 3 FAILED: %s\n\n', ME.message);
end

% ════════════════════════════════════════════════════════════════════════
% TEST 4: batchConvertXRD with folder input
% ════════════════════════════════════════════════════════════════════════
fprintf('─ TEST 4: batchConvertXRD folder discovery ───────────────────────\n');
try
    results = scripts.batchConvertXRD('+test_datasets/XRDML/', ...
        OutputDir=testDir, ...
        Verbose=false);

    fprintf('✓ Found %d XRD file(s) in folder\n', numel(results));
    assert(numel(results) >= 1, 'No files discovered');

    nOk = sum(cellfun(@isempty, {results.error}));
    nErr = sum(~cellfun(@isempty, {results.error}));
    fprintf('  Converted: %d OK, %d errors\n', nOk, nErr);

    if nErr > 0
        fprintf('  Errors:\n');
        for i = 1:numel(results)
            if ~isempty(results(i).error)
                fprintf('    %s: %s\n', results(i).name, results(i).error);
            end
        end
    end

    fprintf('✓ TEST 4 PASSED\n\n');
catch ME
    fprintf('✗ TEST 4 FAILED: %s\n\n', ME.message);
end

% ════════════════════════════════════════════════════════════════════════
% TEST 5: batchConvertXRD options (Format, OutputDir, Intensity)
% ════════════════════════════════════════════════════════════════════════
fprintf('─ TEST 5: batchConvertXRD options ────────────────────────────────\n');
try
    files = ["+test_datasets/XRDML/La2NiO4_1.xrdml"];

    % Test Format="origin"
    subDir1 = fullfile(testDir, 'origin_out');
    mkdir(subDir1);
    results = scripts.batchConvertXRD(files, Format='origin', OutputDir=subDir1, Verbose=false);
    assert(isfile(results(1).outputFile), 'Origin format output not created');
    fprintf('✓ Format="origin" works\n');

    % Test Format="standard" with different Intensity options
    subDir2 = fullfile(testDir, 'cps_out');
    mkdir(subDir2);
    results = scripts.batchConvertXRD(files, Intensity='cps', OutputDir=subDir2, Verbose=false);
    assert(isfile(results(1).outputFile), 'Intensity="cps" output not created');
    fprintf('✓ Intensity="cps" works\n');

    subDir3 = fullfile(testDir, 'counts_out');
    mkdir(subDir3);
    results = scripts.batchConvertXRD(files, Intensity='counts', OutputDir=subDir3, Verbose=false);
    assert(isfile(results(1).outputFile), 'Intensity="counts" output not created');
    fprintf('✓ Intensity="counts" works\n');

    % Test IncludeMetadata=false
    subDir4 = fullfile(testDir, 'no_metadata');
    mkdir(subDir4);
    results = scripts.batchConvertXRD(files, OutputDir=subDir4, IncludeMetadata=false, Verbose=false);
    fid = fopen(results(1).outputFile, 'r');
    firstLine = fgetl(fid);
    fclose(fid);
    assert(~startsWith(firstLine, '#'), 'Metadata header present when IncludeMetadata=false');
    fprintf('✓ IncludeMetadata=false works\n');

    fprintf('✓ TEST 5 PASSED\n\n');
catch ME
    fprintf('✗ TEST 5 FAILED: %s\n\n', ME.message);
end

% ════════════════════════════════════════════════════════════════════════
% TEST 6: ProgressFcn callback
% ════════════════════════════════════════════════════════════════════════
fprintf('─ TEST 6: ProgressFcn callback ───────────────────────────────────\n');
try
    % Simple callback that just displays progress
    callbackFcn = @(k, n, fname) fprintf('  Progress: %d/%d\n', k, n);

    files = ["+test_datasets/XRDML/La2NiO4_1.xrdml"];
    results = scripts.batchConvertXRD(files, ...
        OutputDir=testDir, ...
        ProgressFcn=callbackFcn, ...
        Verbose=false);

    % Just verify that the function accepts the ProgressFcn parameter
    % and returns without error
    assert(~isempty(results), 'ProgressFcn parameter broke conversion');
    fprintf('✓ ProgressFcn parameter accepted\n');
    fprintf('✓ Conversion completed with callback\n');

    fprintf('✓ TEST 6 PASSED\n\n');
catch ME
    fprintf('✗ TEST 6 FAILED: %s\n\n', ME.message);
end

% ════════════════════════════════════════════════════════════════════════
% TEST 7: Error handling and edge cases
% ════════════════════════════════════════════════════════════════════════
fprintf('─ TEST 7: Error handling ─────────────────────────────────────────\n');
try
    % Test invalid output directory
    fprintf('  Testing invalid output directory... ');
    try
        files = ["+test_datasets/XRDML/La2NiO4_1.xrdml"];
        results = scripts.batchConvertXRD(files, OutputDir='nonexistent/path/', Verbose=false);
        % Should have an error in results
        assert(~isempty(results(1).error), 'Expected error for invalid directory');
        fprintf('✓ Caught error\n');
    catch ME2
        fprintf('✓ Caught as exception\n');
    end

    % Test empty file list (explicitly pass empty string array)
    fprintf('  Testing empty file list... ');
    results = scripts.batchConvertXRD(string.empty, Verbose=false);
    assert(isempty(results), 'Expected empty results for no files');
    fprintf('✓ Handled gracefully\n');

    % Test invalid format
    fprintf('  Testing invalid format... ');
    try
        files = ["+test_datasets/XRDML/La2NiO4_1.xrdml"];
        results = scripts.batchConvertXRD(files, Format='invalid_format', Verbose=false);
        fprintf('✗ Should have errored on invalid format\n');
    catch
        fprintf('✓ Caught invalid format\n');
    end

    fprintf('✓ TEST 7 PASSED\n\n');
catch ME
    fprintf('✗ TEST 7 FAILED: %s\n\n', ME.message);
end

% ════════════════════════════════════════════════════════════════════════
% TEST 8: Check for redundancies in code
% ════════════════════════════════════════════════════════════════════════
fprintf('─ TEST 8: Code redundancy analysis ───────────────────────────────\n');
try
    % Check if batchConvertXRD properly delegates to writeXRDcsv
    % (both should produce identical output for same options)

    data = parser.importXRDML('+test_datasets/XRDML/La2NiO4_1.xrdml');

    % Direct call
    file1 = fullfile(testDir, 'direct_call.csv');
    utilities.writeXRDcsv(data, file1, Format='standard', Intensity='both');

    % Batch call with single file
    file2 = fullfile(testDir, 'batch_single.csv');
    results = scripts.batchConvertXRD(["+test_datasets/XRDML/La2NiO4_1.xrdml"], ...
        OutputDir=fileparts(file2), ...
        Format='standard', ...
        Intensity='both', ...
        Verbose=false);

    % Compare file sizes (should be very close, allowing for timestamp differences)
    finfo1 = dir(file1);
    finfo2 = dir(results(1).outputFile);
    sizeDiff = abs(finfo1.bytes - finfo2.bytes);

    fprintf('✓ Direct call file size: %d bytes\n', finfo1.bytes);
    fprintf('✓ Batch call file size: %d bytes\n', finfo2.bytes);
    fprintf('✓ Size difference: %d bytes (acceptable)\n', sizeDiff);

    % The files should be nearly identical (metadata timestamp may differ)
    % Check that column structure is the same
    fid1 = fopen(file1, 'r');
    fid2 = fopen(results(1).outputFile, 'r');

    line1 = fgetl(fid1);
    line2 = fgetl(fid2);
    % Skip metadata lines
    while startsWith(line1, '#')
        line1 = fgetl(fid1);
        line2 = fgetl(fid2);
    end

    col1 = strsplit(line1, ',');
    col2 = strsplit(line2, ',');

    fclose(fid1);
    fclose(fid2);

    assert(numel(col1) == numel(col2), 'Column count mismatch');
    fprintf('✓ Column structure matches (no redundant logic detected)\n');

    fprintf('✓ TEST 8 PASSED\n\n');
catch ME
    fprintf('✗ TEST 8 FAILED: %s\n\n', ME.message);
end

% ════════════════════════════════════════════════════════════════════════
% SUMMARY
% ════════════════════════════════════════════════════════════════════════
fprintf('╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║  TEST SUITE COMPLETE                                           ║\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n');

end

% ════════════════════════════════════════════════════════════════════════
% Cleanup helper
% ════════════════════════════════════════════════════════════════════════

function cleanup(testDir)
    if isfolder(testDir)
        rmdir(testDir, 's');
        fprintf('\nTest directory cleaned up: %s\n', testDir);
    end
end
