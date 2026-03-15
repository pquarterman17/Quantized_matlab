%TEST_CSV_MIXED_FORMAT  Tests for importCSV handling of mixed/awkward formats.
%
%   Run standalone:  cd tests; run test_csv_mixed_format
%   Run from root:   run tests/test_csv_mixed_format
%
%   Covers:
%     - Empty separator columns between data columns
%     - Dedicated units row (e.g. a row of "(°C)","(Oe)","emu")
%     - Pre-header metadata rows (instrument, operator, date lines)
%     - Combined: metadata + header + units row + empty columns + data
%     - Blank header entry replaced with Col{N}
%     - Header column count mismatch (more/fewer than data)
%     - Tab-delimited with units row

clear; clc;

% Ensure toolbox is on the path
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
if ~contains(path, rootDir)
    addpath(rootDir);
end

ROOT = rootDir;

passed = 0;
failed = 0;
tmpDir = tempdir();

% ════════════════════════════════════════════════════════════════════════
%  1. Empty separator columns (Excel-style blank columns between data)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: empty separator columns ══\n');
try
    f = fullfile(tmpDir, 'sep_cols.csv');
    fid = fopen(f, 'w'); cleanObj1 = onCleanup(@() delete(f));
    fprintf(fid, 'Time,,Temperature,,Humidity\n');
    fprintf(fid, '1,,25.3,,64.1\n');
    fprintf(fid, '2,,26.1,,63.8\n');
    fprintf(fid, '3,,25.9,,64.5\n');
    fclose(fid);

    d = parser.importCSV(f, 'TimeColumn', 1);

    % Empty cols 2 and 4 should be dropped
    assert(size(d.values, 2) == 2, ...
        sprintf('expected 2 data channels, got %d', size(d.values,2)));
    assert(numel(d.time) == 3, 'expected 3 rows');
    assert(~any(cellfun(@isempty, d.labels)), 'labels must not be empty strings');
    % Values should match Temperature and Humidity columns
    assert(abs(d.values(1,1) - 25.3) < 1e-6, 'Temperature row 1 mismatch');
    assert(abs(d.values(1,2) - 64.1) < 1e-6, 'Humidity row 1 mismatch');

    fprintf('  Channels   : %s | %s\n', d.labels{1}, d.labels{2});
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. Dedicated units row with ( ) brackets
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: dedicated units row – bracket style ══\n');
try
    f = fullfile(tmpDir, 'units_row_brackets.csv');
    fid = fopen(f, 'w'); cleanObj2 = onCleanup(@() delete(f));
    fprintf(fid, 'Time,Temperature,Humidity\n');
    fprintf(fid, '(s),(°C),(%%)\n');
    fprintf(fid, '1,25.3,64.1\n');
    fprintf(fid, '2,26.1,63.8\n');
    fclose(fid);

    d = parser.importCSV(f, 'TimeColumn', 1);

    assert(numel(d.time) == 2, 'expected 2 data rows');
    assert(size(d.values, 2) == 2, 'expected 2 channels');
    % Units should come from the units row, not from inline header parsing
    assert(strcmp(d.units{1}, '°C'), ...
        sprintf('expected unit ''°C'', got ''%s''', d.units{1}));
    assert(strcmp(d.units{2}, '%'), ...
        sprintf('expected unit ''%%'', got ''%s''', d.units{2}));
    % X-axis unit
    assert(strcmp(d.metadata.xColumnUnit, 's'), ...
        sprintf('expected xColumnUnit ''s'', got ''%s''', d.metadata.xColumnUnit));
    % Labels should be clean (no brackets left)
    assert(strcmp(d.labels{1}, 'Temperature'), ...
        sprintf('expected label ''Temperature'', got ''%s''', d.labels{1}));

    fprintf('  Units      : %s | %s\n', d.units{1}, d.units{2});
    fprintf('  xUnit      : %s\n', d.metadata.xColumnUnit);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Dedicated units row – bare abbreviation style (no brackets)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: dedicated units row – bare abbreviation style ══\n');
try
    f = fullfile(tmpDir, 'units_row_bare.csv');
    fid = fopen(f, 'w'); cleanObj3 = onCleanup(@() delete(f));
    fprintf(fid, 'Field,Moment,StdErr\n');
    fprintf(fid, 'Oe,emu,emu\n');
    fprintf(fid, '-10000,0.00523,0.00001\n');
    fprintf(fid, '-9000,0.00498,0.00001\n');
    fprintf(fid, '0,0.00001,0.00000\n');
    fclose(fid);

    d = parser.importCSV(f, 'TimeColumn', 1);

    assert(numel(d.time) == 3, 'expected 3 rows');
    assert(size(d.values, 2) == 2, 'expected 2 channels (Moment, StdErr)');
    assert(strcmp(d.metadata.xColumnUnit, 'Oe'), ...
        sprintf('expected xColumnUnit ''Oe'', got ''%s''', d.metadata.xColumnUnit));
    assert(strcmp(d.units{1}, 'emu'), ...
        sprintf('expected unit ''emu'', got ''%s''', d.units{1}));

    fprintf('  xUnit      : %s\n', d.metadata.xColumnUnit);
    fprintf('  Units      : %s | %s\n', d.units{1}, d.units{2});
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Pre-header metadata rows (no comment marker)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: pre-header metadata rows ══\n');
try
    f = fullfile(tmpDir, 'metadata_rows.csv');
    fid = fopen(f, 'w'); cleanObj4 = onCleanup(@() delete(f));
    fprintf(fid, 'Instrument: VSM-3000\n');
    fprintf(fid, 'Operator: J. Smith\n');
    fprintf(fid, 'Date: 2025-01-15\n');
    fprintf(fid, 'Field,Moment\n');
    fprintf(fid, '-10000,0.00523\n');
    fprintf(fid, '0,0.00001\n');
    fprintf(fid, '10000,0.00521\n');
    fclose(fid);

    d = parser.importCSV(f, 'TimeColumn', 1);

    assert(numel(d.time) == 3, 'expected 3 data rows');
    assert(size(d.values, 2) == 1, 'expected 1 data channel');
    % Metadata lines should be captured
    assert(isfield(d.metadata.parserSpecific, 'headerMetadata'), ...
        'parserSpecific missing headerMetadata field');
    assert(numel(d.metadata.parserSpecific.headerMetadata) == 3, ...
        sprintf('expected 3 metadata lines, got %d', ...
        numel(d.metadata.parserSpecific.headerMetadata)));
    assert(contains(d.metadata.parserSpecific.headerMetadata{1}, 'VSM'), ...
        'first metadata line should contain instrument info');

    fprintf('  Metadata lines captured: %d\n', ...
        numel(d.metadata.parserSpecific.headerMetadata));
    fprintf('    [1] %s\n', d.metadata.parserSpecific.headerMetadata{1});
    fprintf('    [2] %s\n', d.metadata.parserSpecific.headerMetadata{2});
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. Combined: metadata + header + units row + empty columns
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: combined metadata + units row + empty columns ══\n');
try
    f = fullfile(tmpDir, 'combined.csv');
    fid = fopen(f, 'w'); cleanObj5 = onCleanup(@() delete(f));
    fprintf(fid, 'Lab: Building 1, Room 203\n');
    fprintf(fid, 'Sample: GdFeCo thin film\n');
    fprintf(fid, 'Time,,Temperature,,Pressure\n');
    fprintf(fid, '(s),,(°C),,(mbar)\n');
    fprintf(fid, '0,,20.1,,1013.0\n');
    fprintf(fid, '10,,20.3,,1013.1\n');
    fprintf(fid, '20,,20.5,,1013.0\n');
    fclose(fid);

    d = parser.importCSV(f, 'TimeColumn', 1);

    assert(numel(d.time) == 3, 'expected 3 rows');
    assert(size(d.values, 2) == 2, ...
        sprintf('expected 2 channels (empty cols removed), got %d', size(d.values,2)));
    % Metadata
    assert(numel(d.metadata.parserSpecific.headerMetadata) == 2, ...
        sprintf('expected 2 metadata lines, got %d', ...
        numel(d.metadata.parserSpecific.headerMetadata)));
    % Units from units row
    assert(strcmp(d.metadata.xColumnUnit, 's'), ...
        sprintf('expected xColumnUnit ''s'', got ''%s''', d.metadata.xColumnUnit));
    assert(strcmp(d.units{1}, '°C'), ...
        sprintf('expected unit ''°C'', got ''%s''', d.units{1}));
    assert(strcmp(d.units{2}, 'mbar'), ...
        sprintf('expected unit ''mbar'', got ''%s''', d.units{2}));

    fprintf('  Metadata   : %d lines\n', numel(d.metadata.parserSpecific.headerMetadata));
    fprintf('  Channels   : %s (%s) | %s (%s)\n', ...
        d.labels{1}, d.units{1}, d.labels{2}, d.units{2});
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. Blank column header replaced with Col{N}
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6: blank column header replaced with Col{N} ══\n');
try
    f = fullfile(tmpDir, 'blank_header.csv');
    fid = fopen(f, 'w'); cleanObj6 = onCleanup(@() delete(f));
    % Column 2 has no header name
    fprintf(fid, 'Time,,Value\n');
    fprintf(fid, '1,0.5,1.1\n');
    fprintf(fid, '2,0.7,1.3\n');
    fclose(fid);

    d = parser.importCSV(f, 'TimeColumn', 1);

    % Column 2 has data (0.5, 0.7) so it should not be removed
    % but its label must not be empty
    allLabels = [d.labels, {d.metadata.xColumnName}];
    hasEmpty = any(cellfun(@(s) isempty(strtrim(s)), allLabels));
    assert(~hasEmpty, 'no label should be an empty string');
    % Column 2 label should be Col2
    assert(strcmp(d.labels{1}, 'Col2'), ...
        sprintf('expected blank header → ''Col2'', got ''%s''', d.labels{1}));

    fprintf('  Labels     : %s | %s\n', d.labels{1}, d.labels{2});
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. Header has fewer columns than data rows (padding)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7: header has fewer columns than data ══\n');
try
    f = fullfile(tmpDir, 'short_header.csv');
    fid = fopen(f, 'w'); cleanObj7 = onCleanup(@() delete(f));
    fprintf(fid, 'Time,Temp\n');       % only 2 header cols
    fprintf(fid, '1,25.3,64.1\n');    % 3 data cols
    fprintf(fid, '2,26.1,63.8\n');
    fclose(fid);

    d = parser.importCSV(f, 'TimeColumn', 1);

    % Should not error; the 3rd column gets a Col3 label
    assert(numel(d.time) == 2, 'expected 2 rows');
    assert(size(d.values, 2) == 2, 'expected 2 data channels');
    assert(~any(cellfun(@isempty, d.labels)), 'labels must not be empty strings');

    fprintf('  Labels     : %s | %s\n', d.labels{1}, d.labels{2});
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  8. Units row not falsely triggered by single header like "Field (Oe)"
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 8: single header with inline unit – no false units row ══\n');
try
    f = fullfile(tmpDir, 'inline_units.csv');
    fid = fopen(f, 'w'); cleanObj8 = onCleanup(@() delete(f));
    fprintf(fid, 'Field (Oe),Moment (emu)\n');
    fprintf(fid, '-10000,0.00523\n');
    fprintf(fid, '0,0.00001\n');
    fclose(fid);

    d = parser.importCSV(f, 'TimeColumn', 1);

    % unitsRow should NOT have been detected (only 1 non-numeric row before data)
    assert(d.metadata.parserSpecific.unitsRow == 0, ...
        'unitsRow should be 0 when only 1 non-numeric row precedes data');
    % Units should still be extracted from inline header notation
    assert(strcmp(d.metadata.xColumnUnit, 'Oe'), ...
        sprintf('expected xColumnUnit ''Oe'' from inline header, got ''%s''', ...
        d.metadata.xColumnUnit));
    assert(strcmp(d.units{1}, 'emu'), ...
        sprintf('expected unit ''emu'', got ''%s''', d.units{1}));
    assert(strcmp(d.labels{1}, 'Moment'), ...
        sprintf('expected label ''Moment'', got ''%s''', d.labels{1}));

    fprintf('  unitsRow   : %d (correct – no dedicated units row)\n', ...
        d.metadata.parserSpecific.unitsRow);
    fprintf('  xUnit      : %s  label: %s (%s)\n', ...
        d.metadata.xColumnUnit, d.labels{1}, d.units{1});
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  9. Tab-delimited file with dedicated units row
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 9: tab-delimited with units row ══\n');
try
    f = fullfile(tmpDir, 'tab_units.tsv');
    fid = fopen(f, 'w'); cleanObj9 = onCleanup(@() delete(f));
    fprintf(fid, 'Q\tR\tdR\n');
    fprintf(fid, '(1/Å)\t(arb)\t(arb)\n');
    fprintf(fid, '0.01\t1.0000\t0.0010\n');
    fprintf(fid, '0.02\t0.5000\t0.0008\n');
    fprintf(fid, '0.03\t0.2500\t0.0006\n');
    fclose(fid);

    d = parser.importCSV(f, 'TimeColumn', 1);

    assert(numel(d.time) == 3, 'expected 3 rows');
    assert(size(d.values, 2) == 2, 'expected 2 channels (R, dR)');
    assert(d.metadata.parserSpecific.unitsRow > 0, ...
        'unitsRow should be detected');
    % Units stripped of brackets
    assert(strcmp(d.units{1}, 'arb'), ...
        sprintf('expected unit ''arb'', got ''%s''', d.units{1}));
    assert(strcmp(d.metadata.xColumnUnit, '1/Å'), ...
        sprintf('expected xColumnUnit ''1/Å'', got ''%s''', d.metadata.xColumnUnit));

    fprintf('  Delimiter  : tab (auto-detected)\n');
    fprintf('  unitsRow   : %d\n', d.metadata.parserSpecific.unitsRow);
    fprintf('  xUnit      : %s\n', d.metadata.xColumnUnit);
    fprintf('  Units      : %s | %s\n', d.units{1}, d.units{2});
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  10. Metadata rows do NOT get counted as header when the real header
%      immediately precedes the data (multiline instrument block)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 10: multi-line instrument block before header ══\n');
try
    f = fullfile(tmpDir, 'instrument_block.csv');
    fid = fopen(f, 'w'); cleanObj10 = onCleanup(@() delete(f));
    fprintf(fid, 'Quantum Design MPMS3\n');
    fprintf(fid, 'Serial Number: 12345\n');
    fprintf(fid, 'Sample name: test\n');
    fprintf(fid, 'Date: 2025-03-01\n');
    fprintf(fid, 'Temperature,Moment\n');
    fprintf(fid, '10,0.00521\n');
    fprintf(fid, '20,0.00498\n');
    fprintf(fid, '300,0.00003\n');
    fclose(fid);

    d = parser.importCSV(f, 'TimeColumn', 1);

    assert(numel(d.time) == 3, 'expected 3 data rows');
    assert(size(d.values, 2) == 1, 'expected 1 data channel (Moment)');
    % Header should have been correctly identified as "Temperature,Moment" row
    assert(strcmp(d.metadata.xColumnName, 'Temperature'), ...
        sprintf('expected xColumnName ''Temperature'', got ''%s''', d.metadata.xColumnName));
    assert(strcmp(d.labels{1}, 'Moment'), ...
        sprintf('expected label ''Moment'', got ''%s''', d.labels{1}));
    % 4 metadata lines should be captured
    assert(numel(d.metadata.parserSpecific.headerMetadata) == 4, ...
        sprintf('expected 4 metadata lines, got %d', ...
        numel(d.metadata.parserSpecific.headerMetadata)));

    fprintf('  Metadata   : %d lines captured\n', ...
        numel(d.metadata.parserSpecific.headerMetadata));
    fprintf('  Header     : %s | %s\n', d.metadata.xColumnName, d.labels{1});
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n════════════════════════════════════════════════════\n');
fprintf('  CSV mixed-format tests: %d passed, %d failed\n', passed, failed);
fprintf('════════════════════════════════════════════════════\n');

if failed > 0
    error('test:failure', '%d test(s) failed', failed);
end
