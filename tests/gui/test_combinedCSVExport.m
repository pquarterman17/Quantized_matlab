%TEST_COMBINEDCSVEXPORT  exportCombinedCSV layout for multiple datasets:
%   ragged lengths blank-pad (no literal "NaN"), the X header carries the real
%   x-axis name, and Origin designations are correct per block (X / Y / yEr /
%   xEr).  Regression for the 6-XRR-dataset "summarized CSV" bug.
%
%   Run standalone:  run tests/gui/test_combinedCSVExport
%
%   Each test prints PASS / FAIL. Errors at the end if any failed so
%   runAllTests detects the failure.

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir), addpath(rootDir); end

tmpDir = fullfile(tempdir, 'combcsv_' + string(datetime('now','Format','yyyyMMdd_HHmmss')));
if ~isfolder(tmpDir), mkdir(tmpDir); end
cleanupTmp = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  1. Ragged lengths → blank padding, NEVER literal "NaN" text
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 1: ragged datasets blank-pad (no "NaN" text) ==\n');
try
    appData = makeApp({ ...
        reflDs('s1.refl', (1:5)',  0.9*ones(5,1),  0.01*ones(5,1)), ...
        reflDs('s2.refl', (1:3)',  0.8*ones(3,1),  0.02*ones(3,1)) });

    fp = fullfile(tmpDir, 'ragged.csv');
    bosonPlotter.exportCombinedCSV(appData, [1 2], fp, 'standard');

    txt = fileread(fp);
    assert(~contains(txt, 'NaN'), 'export must not contain literal "NaN" (got ragged NaN fill)');

    [hdr, rows] = readCSV(fp);
    % Each block = Qz + Intensity + uncertainty + resolution = 4 cols → 8 total
    assert(numel(hdr) == 8, 'expected 8 columns (4 per block x2), got %d', numel(hdr));
    assert(size(rows,1) == 5, 'expected 5 data rows (max length), got %d', size(rows,1));
    % s2 (3 rows) blank-padded on rows 4-5; its Qz column is column 5
    assert(all(isnan(rows(4:5, 5))), 'short block Qz column should be blank past its length');
    assert(~isnan(rows(5, 1)), 'long block (s1) should keep a value on row 5');
    fprintf('  Header: %s\n', strjoin(hdr, ', '));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. Standard X header uses the real x-axis name (xColumnName), not 'X'
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 2: X header carries xColumnName ("Qz") ==\n');
try
    appData = makeApp({ reflDs('s1.refl', (1:4)', 0.9*ones(4,1), 0.01*ones(4,1)) });
    fp = fullfile(tmpDir, 'xname.csv');
    bosonPlotter.exportCombinedCSV(appData, 1, fp, 'standard');
    [hdr, ~] = readCSV(fp);
    assert(startsWith(strtrim(hdr{1}), 'Qz'), ...
        'X header should start with "Qz", got "%s"', hdr{1});
    fprintf('  X header: %s\n', hdr{1});
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Origin designations: each block's X is 'X'; uncertainty→yEr, resolution→xEr
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 3: origin designations correct per block ==\n');
try
    appData = makeApp({ reflDs('s1.refl', (1:4)', 0.9*ones(4,1), 0.01*ones(4,1)), ...
                        reflDs('s2.refl', (1:4)', 0.8*ones(4,1), 0.02*ones(4,1)) });
    fp = fullfile(tmpDir, 'origin.csv');
    bosonPlotter.exportCombinedCSV(appData, [1 2], fp, 'origin');

    txt = fileread(fp);
    lines = regexp(txt, '\r?\n', 'split');
    lines = lines(~cellfun(@(l) isempty(strtrim(l)), lines));
    assert(numel(lines) >= 3, 'origin format needs 3 header rows');

    longNames = strsplit(lines{1}, ',', 'CollapseDelimiters', false);
    units     = strsplit(lines{2}, ',', 'CollapseDelimiters', false);
    desig     = strsplit(lines{3}, ',', 'CollapseDelimiters', false);

    % Per dataset: Qz, Intensity, uncertainty, resolution → X Y yEr xEr
    expectDesig = {'X','Y','yEr','xEr','X','Y','yEr','xEr'};
    assert(isequal(desig(:)', expectDesig), ...
        'designation row wrong: got %s', strjoin(desig, ','));

    % Both X columns present (one per block), not just the first
    assert(sum(strcmp(desig, 'X')) == 2, 'each block must contribute its own X');

    % Long names clean of unit parens; units row carries them
    assert(strcmp(strtrim(longNames{2}), 'Intensity [s1.refl]'), ...
        'long name should carry [tag] without units: %s', longNames{2});
    assert(strcmp(strtrim(units{1}), '1/Ang'), 'X unit should be 1/Ang, got %s', units{1});

    fprintf('  Comments : %s\n', strjoin(desig, ', '));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Header tag containing a comma is CSV-quoted (no column shift)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 4: comma in legend tag is quoted ==\n');
try
    ds = reflDs('s1.refl', (1:3)', 0.9*ones(3,1), 0.01*ones(3,1));
    ds.legendName = 'Sample, 300K';   % comma would shift columns if unquoted
    appData = makeApp({ds});
    fp = fullfile(tmpDir, 'comma.csv');
    bosonPlotter.exportCombinedCSV(appData, 1, fp, 'standard');

    [hdr, ~] = readCSV(fp);
    assert(numel(hdr) == 4, 'comma in tag shifted columns: got %d headers', numel(hdr));
    assert(contains(hdr{1}, 'Sample, 300K'), 'quoted tag should survive intact: %s', hdr{1});
    fprintf('  Header[1]: %s\n', hdr{1});
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
    error('test_combinedCSVExport:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end

% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function ds = reflDs(fname, Q, R, dR)
%REFLDS  Minimal unpolarized .refl-shaped dataset (Qz + Intensity/uncertainty/
%   resolution) — mirrors importNCNRRefl output for XRR.
    res = 0.001 * ones(numel(Q), 1);
    meta = struct('parserName', 'importNCNRRefl', ...
                  'xColumnName', 'Qz', 'xColumnUnit', '1/Ang');
    data = struct('time', Q(:), ...
        'values', [R(:), dR(:), res], ...
        'labels', {{'Intensity', 'uncertainty', 'resolution'}}, ...
        'units',  {{'counts per second', 'counts per second', '1/Ang'}}, ...
        'metadata', meta);
    ds = struct('filepath', fullfile(tempdir, fname), 'parserName', 'importNCNRRefl', ...
        'corrData', [], 'data', data);
end

function appData = makeApp(datasets)
    appData = bosonPlotter.AppState();
    appData.datasets = datasets;
    appData.activeIdx = 1;
end

function [hdr, rows] = readCSV(fp)
%READCSV  Standard-format CSV → header cellstr + numeric matrix.  Empty cells
%   (blank-padded short columns) become NaN.  Delimiter collapsing disabled to
%   preserve column alignment.
    txt = fileread(fp);
    lines = regexp(txt, '\r?\n', 'split');
    lines = lines(~cellfun(@(l) isempty(strtrim(l)), lines));
    hdr = parseCSVLine(lines{1});
    nCols = numel(hdr);
    nData = numel(lines) - 1;
    rows = NaN(nData, nCols);
    for r = 1:nData
        parts = parseCSVLine(lines{r+1});
        for c = 1:min(nCols, numel(parts))
            rows(r, c) = str2double(parts{c});
        end
    end
end

function parts = parseCSVLine(line)
%PARSECSVLINE  Split a CSV line honoring "..." quoted fields (so a quoted
%   comma inside a tag does not split the column).
    parts = {};
    cur = '';
    inQ = false;
    i = 1;
    while i <= numel(line)
        ch = line(i);
        if ch == '"'
            if inQ && i < numel(line) && line(i+1) == '"'
                cur(end+1) = '"'; %#ok<AGROW>
                i = i + 1;
            else
                inQ = ~inQ;
            end
        elseif ch == ',' && ~inQ
            parts{end+1} = cur; %#ok<AGROW>
            cur = '';
        else
            cur(end+1) = ch; %#ok<AGROW>
        end
        i = i + 1;
    end
    parts{end+1} = cur; %#ok<AGROW>
end
