%TEST_NEUTRONCSVEXPORT  saveConsolidatedNeutronCSV layout: per-dataset blocks
%   for unpolarized/independent scans vs shared-Q consolidation for true PNR.
%
%   Run standalone:  run tests/gui/test_neutronCSVExport
%
%   Each test prints PASS / FAIL. Errors at the end if any failed so
%   runAllTests detects the failure.

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

tmpDir = fullfile(tempdir, 'neutroncsv_test_' + string(datetime('now','Format','yyyyMMdd_HHmmss')));
if ~isfolder(tmpDir), mkdir(tmpDir); end
cleanupTmp = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  1. Unpolarized scans → per-dataset blocks, each keeping its own Q
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 1: unpolarized .refl → per-dataset blocks (own Q, no interp) ==\n');
try
    % Two scans, same base name ("meas"), DIFFERENT Q grids and lengths.
    Q1 = (0.01:0.01:0.05)';            % 5 points
    Q2 = (0.012:0.02:0.072)';          % 4 points, different grid
    ds1 = makeNeutronDs(fullfile(tmpDir,'meas_a.refl'), '', Q1, 0.9*ones(5,1), 0.01*ones(5,1));
    ds2 = makeNeutronDs(fullfile(tmpDir,'meas_b.refl'), '', Q2, 0.8*ones(4,1), 0.02*ones(4,1));

    fp = fullfile(tmpDir, 'unpol_combined.csv');
    bosonPlotter.saveConsolidatedNeutronCSV(ds1, fp, 'standard', {ds1, ds2});

    [hdr, rows] = readCSV(fp);

    % Expect two Q columns (one per dataset) — the per-dataset layout.
    nQ = sum(cellfun(@(h) isQHeader(h), hdr));
    assert(nQ == 2, sprintf('expected 2 Q columns, got %d (header: %s)', nQ, strjoin(hdr, '|')));
    assert(numel(hdr) == 6, sprintf('expected 6 columns (Q R dR | Q R dR), got %d', numel(hdr)));

    % No interpolation: each block keeps its own Q grid.
    assert(abs(rows(1,1) - Q1(1)) < 1e-9, 'block 1 Q not preserved');
    assert(abs(rows(1,4) - Q2(1)) < 1e-9, 'block 2 Q not preserved');
    assert(abs(rows(2,4) - Q2(2)) < 1e-9, 'block 2 Q grid altered (interpolated?)');

    % Shorter block (ds2, 4 rows) is blank-padded on the 5th row, not NaN.
    assert(size(rows,1) == 5, sprintf('expected 5 data rows (max length), got %d', size(rows,1)));
    assert(isnan(rows(5,4)), 'short column should be blank/NaN-padded on extra row');
    assert(~isnan(rows(5,1)), 'long column (ds1) should have a value on row 5');

    fprintf('  Header: %s\n', strjoin(hdr, ', '));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. Polarized PNR (++ and --) → shared-Q consolidation + asymmetry
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 2: polarized PNR → shared Q + R_pp/R_mm + Asymmetry ==\n');
try
    Q = (0.01:0.01:0.06)';
    dsPP = makeNeutronDs(fullfile(tmpDir,'pnr_a.refl'), '++', Q, linspace(0.9,0.5,6)', 0.01*ones(6,1));
    dsMM = makeNeutronDs(fullfile(tmpDir,'pnr_b.refl'), '--', Q, linspace(0.8,0.4,6)', 0.02*ones(6,1));

    fp = fullfile(tmpDir, 'pnr_combined.csv');
    bosonPlotter.saveConsolidatedNeutronCSV(dsPP, fp, 'standard', {dsPP, dsMM});

    [hdr, ~] = readCSV(fp);

    nQ = sum(cellfun(@(h) isQHeader(h), hdr));
    assert(nQ == 1, sprintf('polarized export should share ONE Q column, got %d', nQ));
    assert(any(strcmp(hdr, 'R_pp')),  'missing R_pp column');
    assert(any(strcmp(hdr, 'R_mm')),  'missing R_mm column');
    assert(any(strcmp(hdr, 'Asymmetry')), 'missing Asymmetry column (consolidation lost)');

    fprintf('  Header: %s\n', strjoin(hdr, ', '));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Origin format: 4 header rows (Long Name / Units / File Name / Comments)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 3: origin format multi-row header for per-dataset blocks ==\n');
try
    Q1 = (0.01:0.01:0.04)';
    Q2 = (0.01:0.01:0.04)';
    ds1 = makeNeutronDs(fullfile(tmpDir,'org_a.refl'), '', Q1, 0.9*ones(4,1), 0.01*ones(4,1));
    ds2 = makeNeutronDs(fullfile(tmpDir,'org_b.refl'), '', Q2, 0.8*ones(4,1), 0.02*ones(4,1));

    fp = fullfile(tmpDir, 'unpol_origin.csv');
    bosonPlotter.saveConsolidatedNeutronCSV(ds1, fp, 'origin', {ds1, ds2});

    txt = fileread(fp);
    lines = regexp(txt, '\r?\n', 'split');
    lines = lines(~cellfun(@(l) isempty(strtrim(l)), lines));
    assert(numel(lines) >= 4, 'origin format needs 4 header rows');

    % Row 1 (Long Name): clean — no file tag brackets, no unit parentheses.
    assert(~any(ismember('[]()', lines{1})), ...
        sprintf('Long Name row not clean: %s', lines{1}));
    longNames = strsplit(lines{1}, ',', 'CollapseDelimiters', false);
    assert(isequal(longNames(:)', {'Q','R','dR','Q','R','dR'}), ...
        sprintf('Long Name row mismatch: got %s', strjoin(longNames, ',')));

    % Row 3 (File Name): source file per column.
    fileRow = strsplit(lines{3}, ',', 'CollapseDelimiters', false);
    expectFiles = {'org_a.refl','org_a.refl','org_a.refl','org_b.refl','org_b.refl','org_b.refl'};
    assert(isequal(fileRow(:)', expectFiles), ...
        sprintf('File Name row mismatch: got %s', strjoin(fileRow, ',')));

    % Row 4 (Comments): Q R dR | Q R dR  →  X Y yEr X Y yEr
    desig = strsplit(lines{4}, ',', 'CollapseDelimiters', false);
    expect = {'X','Y','yEr','X','Y','yEr'};
    assert(isequal(desig(:)', expect), ...
        sprintf('designation row mismatch: got %s', strjoin(desig, ',')));

    fprintf('  Long Name: %s\n', strjoin(longNames, ', '));
    fprintf('  File Name: %s\n', strjoin(fileRow, ', '));
    fprintf('  Comments : %s\n', strjoin(desig, ', '));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3b. Origin designations for real NCNR column names → X / Y / yEr / xEr
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 3b: origin designations for Intensity/uncertainty/resolution ==\n');
try
    Q = (0.01:0.01:0.05)';
    ds = makeReflDs(fullfile(tmpDir,'refl_real.refl'), Q, ...
        {'Intensity','uncertainty','resolution'}, {'counts','counts','1/Ang'}, ...
        [0.9*ones(5,1), 0.01*ones(5,1), 0.001*ones(5,1)]);

    fp = fullfile(tmpDir, 'refl_real_origin.csv');
    bosonPlotter.saveConsolidatedNeutronCSV(ds, fp, 'origin', {ds});

    txt = fileread(fp);
    lines = regexp(txt, '\r?\n', 'split');
    lines = lines(~cellfun(@(l) isempty(strtrim(l)), lines));

    longNames = strsplit(lines{1}, ',', 'CollapseDelimiters', false);
    units     = strsplit(lines{2}, ',', 'CollapseDelimiters', false);
    desig     = strsplit(lines{4}, ',', 'CollapseDelimiters', false);

    assert(isequal(longNames(:)', {'Q','Intensity','uncertainty','resolution'}), ...
        sprintf('Long Name mismatch: %s', strjoin(longNames, ',')));
    assert(isequal(units(:)', {'1/Ang','counts','counts','1/Ang'}), ...
        sprintf('Units mismatch: %s', strjoin(units, ',')));
    assert(isequal(desig(:)', {'X','Y','yEr','xEr'}), ...
        sprintf('Designation mismatch (want X,Y,yEr,xEr): %s', strjoin(desig, ',')));

    fprintf('  Long Name: %s\n', strjoin(longNames, ', '));
    fprintf('  Units    : %s\n', strjoin(units, ', '));
    fprintf('  Comments : %s\n', strjoin(desig, ', '));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Single unpolarized dataset → one block, no asymmetry, no interp
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 4: single unpolarized dataset → one Q/R/dR block ==\n');
try
    Q = (0.01:0.01:0.05)';
    ds = makeNeutronDs(fullfile(tmpDir,'solo.refl'), '', Q, 0.9*ones(5,1), 0.01*ones(5,1));

    fp = fullfile(tmpDir, 'solo.csv');
    bosonPlotter.saveConsolidatedNeutronCSV(ds, fp, 'standard', {ds});

    [hdr, rows] = readCSV(fp);
    nQ = sum(cellfun(@(h) isQHeader(h), hdr));
    assert(nQ == 1, sprintf('single dataset should have 1 Q column, got %d', nQ));
    assert(~any(contains(hdr, 'Asymmetry')), 'asymmetry should not appear for single dataset');
    assert(abs(rows(1,1) - Q(1)) < 1e-9, 'Q not preserved for single dataset');

    fprintf('  Header: %s\n', strjoin(hdr, ', '));
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
    error('test_neutronCSVExport:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end

% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function ds = makeNeutronDs(filepath, pol, Q, R, dR)
%MAKENEUTRONDS  Minimal neutron dataset struct for export testing.
    meta = struct();
    meta.parserName = 'importNCNRRefl';
    meta.parserSpecific = struct('xUnit', '1/A');
    if ~isempty(pol)
        meta.parserSpecific.polarization = pol;
    end
    data = struct( ...
        'time',   Q(:), ...
        'values', [R(:), dR(:)], ...
        'labels', {{'R', 'dR'}}, ...
        'units',  {{'', ''}}, ...
        'metadata', meta);
    ds = struct( ...
        'filepath',   filepath, ...
        'parserName', 'importNCNRRefl', ...
        'data',       data, ...
        'corrData',   []);
end

function ds = makeReflDs(filepath, Q, labels, units, values)
%MAKEREFLDS  Neutron dataset with explicit value labels/units (real .refl names).
    meta = struct();
    meta.parserName = 'importNCNRRefl';
    meta.xColumnUnit = '1/Ang';
    meta.parserSpecific = struct('dataSource', 'NCNR reductus');
    data = struct( ...
        'time',   Q(:), ...
        'values', values, ...
        'labels', {labels}, ...
        'units',  {units}, ...
        'metadata', meta);
    ds = struct( ...
        'filepath',   filepath, ...
        'parserName', 'importNCNRRefl', ...
        'data',       data, ...
        'corrData',   []);
end

function tf = isQHeader(h)
%ISQHEADER  True when a header names the Q column ('Q', 'Q (unit)', 'Q [tag]').
    s = strtrim(h);
    tf = strcmp(s, 'Q') || startsWith(s, 'Q ') || ...
         startsWith(s, 'Q[') || startsWith(s, 'Q(');
end

function [hdr, rows] = readCSV(fp)
%READCSV  Read a standard-format CSV into a header cellstr + numeric matrix.
%   Empty cells (blank-padded short columns) become NaN.  Preserves column
%   alignment by disabling delimiter collapsing.
    txt = fileread(fp);
    lines = regexp(txt, '\r?\n', 'split');
    lines = lines(~cellfun(@(l) isempty(strtrim(l)), lines));
    hdr = strsplit(lines{1}, ',', 'CollapseDelimiters', false);
    nCols = numel(hdr);
    nData = numel(lines) - 1;
    rows = NaN(nData, nCols);
    for r = 1:nData
        parts = strsplit(lines{r+1}, ',', 'CollapseDelimiters', false);
        for c = 1:min(nCols, numel(parts))
            v = str2double(parts{c});
            rows(r, c) = v;   % str2double('') → NaN
        end
    end
end
