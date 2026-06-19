%TEST_LEGENDEDITOR  Bulk legend editing: pure ops + headless editor drive.
%   Covers legendBulkOps (strip/replace), datasetMetaFields, and the editor's
%   swatch/bulk-tool wiring via its optional api handle.  Run headless
%   (runAllTests(Group="gui") sets QUANTIZED_MATLAB_HEADLESS).
%
%   Run standalone:  run tests/gui/test_legendEditor

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir), addpath(rootDir); end

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  1. legendBulkOps — strip common prefix/suffix
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 1: legendBulkOps stripCommon ==\n');
try
    out = bosonPlotter.legendBulkOps('stripCommon', {'AAA-x-ZZZ','AAA-y-ZZZ','AAA-z-ZZZ'});
    assert(isequal(out, {'x','y','z'}), 'got %s', strjoin(out, ','));
    fprintf('  PASS (%s)\n', strjoin(out, ', ')); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. legendBulkOps — find & replace
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 2: legendBulkOps findReplace ==\n');
try
    out = bosonPlotter.legendBulkOps('findReplace', {'R (corr)','R (corr)'}, ' (corr)', '');
    assert(isequal(out, {'R','R'}), 'got %s', strjoin(out, ','));
    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. datasetMetaFields — temperature extraction
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 3: datasetMetaFields ==\n');
try
    ds = makeDs('s.dat', '', 300);
    f  = bosonPlotter.datasetMetaFields(ds);
    assert(isfield(f, 'Temperature'), 'Temperature field missing');
    assert(strcmp(f.Temperature, '300 K'), 'got "%s"', f.Temperature);
    fprintf('  PASS (Temperature=%s)\n', f.Temperature); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Editor api — strip / reset / fill / replace operate on the table
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 4: editor bulk tools via api ==\n');
fig = uifigure('Visible', 'off');
cleanupFig = onCleanup(@() delete(fig)); %#ok<NASGU>
try
    datasets = { makeDs('AAA-x-ZZZ.dat', '', 300), makeDs('AAA-y-ZZZ.dat', '', 310) };
    ctx = struct( ...
        'fig', fig, 'theme', 'Dark', ...
        'getDatasets', @() datasets, ...
        'setDataset', @(idx, d) [], ...
        'getStyleOverrides', @() struct(), ...
        'setStyleOverrides', @(s) [], ...
        'getActiveTemplate', @() 'screen', ...
        'replot', @() []);

    api = bosonPlotter.legendEditor(fig, ctx);
    closeApi = onCleanup(@() delete(api.fig)); %#ok<NASGU>

    % Swatch column present (4 columns, first is the colour bullet)
    assert(size(api.tbl.Data, 2) == 4, 'table should have 4 columns');
    assert(strcmp(api.tbl.Data{1, 1}, char(9679)), 'first column should be the swatch bullet');

    % Strip common: effective labels = Source names → {'x','y'}
    api.doStripCommon();
    col = api.legendColumn();
    assert(isequal(col, {'x','y'}), 'strip → %s', strjoin(col, ','));

    % Reset to auto: overrides cleared
    api.doResetAuto();
    col = api.legendColumn();
    assert(all(cellfun(@isempty, col)), 'reset should clear overrides');

    % Fill from metadata (Temperature)
    assert(any(strcmp(api.ddMeta.Items, 'Temperature')), 'Temperature should be an available meta key');
    api.doFillMeta('Temperature');
    col = api.legendColumn();
    assert(isequal(col, {'300 K','310 K'}), 'fill → %s', strjoin(col, ','));

    % Find & replace on the filled overrides
    api.efFind.Value = 'K'; api.efRepl.Value = 'Kelvin';
    api.doReplace();
    col = api.legendColumn();
    assert(isequal(col, {'300 Kelvin','310 Kelvin'}), 'replace → %s', strjoin(col, ','));

    fprintf('  PASS\n'); passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. Apply round-trip writes ds.legendName (column-index correctness)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n== TEST 5: Apply writes legendName ==\n');
fig2 = uifigure('Visible', 'off');
cleanupFig2 = onCleanup(@() delete(fig2)); %#ok<NASGU>
try
    store = containers.Map('KeyType', 'double', 'ValueType', 'any');
    store(1) = makeDs('AAA-x-ZZZ.dat', '', 300);
    store(2) = makeDs('AAA-y-ZZZ.dat', '', 310);
    ctx = struct( ...
        'fig', fig2, 'theme', 'Dark', ...
        'getDatasets', @() {store(1), store(2)}, ...
        'setDataset', @(idx, d) putDs(store, idx, d), ...
        'getStyleOverrides', @() struct(), ...
        'setStyleOverrides', @(s) [], ...
        'getActiveTemplate', @() 'screen', ...
        'replot', @() []);

    api = bosonPlotter.legendEditor(fig2, ctx);
    api.doFillMeta('Temperature');                 % overrides = {'300 K','310 K'}
    btnApply = findobj(api.fig, 'Type', 'uibutton', 'Text', 'Apply');
    assert(~isempty(btnApply), 'Apply button not found');
    btnApply(1).ButtonPushedFcn(btnApply(1), []);  % commit

    assert(strcmp(store(1).legendName, '300 K'), 'ds1 legendName = "%s"', store(1).legendName);
    assert(strcmp(store(2).legendName, '310 K'), 'ds2 legendName = "%s"', store(2).legendName);
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
    error('test_legendEditor:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end

% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function ds = makeDs(fname, legendName, tempK)
    meta = struct('parserName', 'importCSV', 'temperature', tempK);
    data = struct('time', (1:3)', 'values', (1:3)', ...
        'labels', {{'Signal'}}, 'units', {{'arb'}}, 'metadata', meta);
    ds = struct('filepath', fullfile(tempdir, fname), 'parserName', 'importCSV', ...
        'data', data, 'corrData', [], 'legendName', legendName);
end

function putDs(store, idx, d)
    store(idx) = d;
end
