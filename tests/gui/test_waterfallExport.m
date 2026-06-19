%TEST_WATERFALLEXPORT  Waterfall offset baked into combined CSV export.
%   Covers waterfallOffsets (sequential + neutron grouping) and
%   exportCombinedCSV applying the offset to signal/theory columns only
%   (X and error columns left raw), additive and multiplicative.
%
%   Run standalone:  run tests/gui/test_waterfallExport

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir), addpath(rootDir); end

tmpDir = fullfile(tempdir, 'wfexport_' + string(datetime('now','Format','yyyyMMdd_HHmmss')));
if ~isfolder(tmpDir), mkdir(tmpDir); end
cleanupTmp = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  1. waterfallOffsets — sequential for independent datasets
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 1: waterfallOffsets sequential ==\n');
try
    dss = {csvDs('a.csv'), csvDs('b.csv'), csvDs('c.csv')};
    lv  = bosonPlotter.waterfallOffsets(dss, [1 2 3]);
    assert(isequal(lv(:)', [0 1 2]), 'got %s', mat2str(lv(:)'));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. waterfallOffsets — neutron cross-sections share a level
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 2: waterfallOffsets neutron grouping ==\n');
try
    dss = {neutronDs('meas_a.refl'), neutronDs('meas_b.refl'), neutronDs('other_a.refl')};
    lv  = bosonPlotter.waterfallOffsets(dss, [1 2 3]);
    % meas_a / meas_b share base "meas" → level 0; other → level 1
    assert(isequal(lv(:)', [0 0 1]), 'got %s', mat2str(lv(:)'));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. exportCombinedCSV — additive offset on signal, not error/X
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 3: combined export, additive waterfall offset ==\n');
try
    appData = bosonPlotter.AppState();
    appData.datasets = { reflDs('s1.csv', [10;20;30], [1;1;1]), ...
                         reflDs('s2.csv', [40;50;60], [2;2;2]) };
    appData.activeIdx = 1;
    wf = struct('apply', true, 'levels', [0;1], 'spacing', 100, 'logMode', false);

    fp = fullfile(tmpDir, 'comb_add.csv');
    bosonPlotter.exportCombinedCSV(appData, [1 2], fp, 'standard', wf);
    [~, rows] = readCSV(fp);

    % Columns: X1 R1 dR1 | X2 R2 dR2  (level 0 / level 1, spacing 100)
    assert(isequal(rows(:,2), [10;20;30]), 'ds1 R should be unshifted (level 0)');
    assert(isequal(rows(:,5), [140;150;160]), 'ds2 R should be +100');
    assert(isequal(rows(:,6), [2;2;2]),  'ds2 dR (error) must NOT be offset');
    assert(isequal(rows(:,4), [1;2;3]),  'ds2 X must NOT be offset');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. exportCombinedCSV — no offset when apply=false
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 4: combined export, offset disabled ==\n');
try
    appData = bosonPlotter.AppState();
    appData.datasets = { reflDs('s1.csv', [10;20;30], [1;1;1]), ...
                         reflDs('s2.csv', [40;50;60], [2;2;2]) };
    appData.activeIdx = 1;
    fp = fullfile(tmpDir, 'comb_raw.csv');
    bosonPlotter.exportCombinedCSV(appData, [1 2], fp, 'standard');   % no wf arg
    [~, rows] = readCSV(fp);
    assert(isequal(rows(:,5), [40;50;60]), 'ds2 R should be raw when no offset');
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. exportCombinedCSV — multiplicative offset (log Y)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 5: combined export, multiplicative (log) offset ==\n');
try
    appData = bosonPlotter.AppState();
    appData.datasets = { reflDs('s1.csv', [10;20;30], [1;1;1]), ...
                         reflDs('s2.csv', [40;50;60], [2;2;2]) };
    appData.activeIdx = 1;
    wf = struct('apply', true, 'levels', [0;1], 'spacing', 10, 'logMode', true);
    fp = fullfile(tmpDir, 'comb_log.csv');
    bosonPlotter.exportCombinedCSV(appData, [1 2], fp, 'standard', wf);
    [~, rows] = readCSV(fp);
    % ds2 R * 10^1 = [400 500 600]; dR unchanged
    assert(isequal(rows(:,5), [400;500;600]), 'ds2 R should be x10 (log)');
    assert(isequal(rows(:,6), [2;2;2]),       'ds2 dR must NOT be scaled');
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
    error('test_waterfallExport:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end

% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function ds = csvDs(fname)
    ds = struct('filepath', fullfile(tempdir, fname), 'parserName', 'importCSV', ...
        'corrData', [], 'data', struct('time', (1:3)', 'values', (1:3)', ...
        'labels', {{'Y'}}, 'units', {{''}}, 'metadata', struct('parserName','importCSV')));
end

function ds = neutronDs(fname)
    ds = struct('filepath', fullfile(tempdir, fname), 'parserName', 'importNCNRRefl', ...
        'corrData', [], 'data', struct('time', (1:3)', 'values', (1:3)', ...
        'labels', {{'R'}}, 'units', {{''}}, 'metadata', struct('parserName','importNCNRRefl')));
end

function ds = reflDs(fname, R, dR)
    data = struct('time', (1:3)', 'values', [R(:), dR(:)], ...
        'labels', {{'R','dR'}}, 'units', {{'',''}}, ...
        'metadata', struct('parserName','importCSV'));
    ds = struct('filepath', fullfile(tempdir, fname), 'parserName', 'importCSV', ...
        'corrData', [], 'data', data);
end

function [hdr, rows] = readCSV(fp)
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
            rows(r, c) = str2double(parts{c});
        end
    end
end
