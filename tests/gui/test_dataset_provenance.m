%TEST_DATASET_PROVENANCE  Tests for per-dataset operation history (W3 #15).
%
%   Covers the four free helpers (`appendHistory`, `getHistoryScript`,
%   `exportHistoryScript`, `formatHistory`) plus the BosonPlotter
%   integration: `buildDs` seeds an initial 'import' entry, and
%   `onApplyCorrections` appends a 'correction' entry whose summary
%   matches the macro-log line.
%
%   Run:  runAllTests(Group="gui")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir); addpath(rootDir); end

fprintf('\n=== test_dataset_provenance ===\n');
passed = 0; failed = 0;

% ── Test 1: appendHistory creates .history field on a bare ds ──────────
try
    ds = struct('foo', 1);
    ds = bosonPlotter.appendHistory(ds, 'manual', 'first entry', "x = 1;");
    assert(isfield(ds, 'history'), 'history field not created');
    assert(isscalar(ds.history), 'expected scalar history');
    assert(strcmp(ds.history.category, 'manual'), 'category mismatch');
    assert(strcmp(ds.history.cmd, 'x = 1;'),     'cmd mismatch');
    assert(isa(ds.history.timestamp, 'datetime'), 'timestamp not datetime');
    fprintf('  [PASS] appendHistory creates field on bare ds\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] appendHistory create: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 2: appendHistory appends; default cmd is empty ────────────────
try
    ds = struct();
    ds = bosonPlotter.appendHistory(ds, 'import', 'one');
    ds = bosonPlotter.appendHistory(ds, 'fit',    'two', "y = sin(x);");
    ds = bosonPlotter.appendHistory(ds, 'mask',   'three');
    assert(numel(ds.history) == 3, 'expected 3 entries, got %d', numel(ds.history));
    assert(strcmp(ds.history(1).cmd, ''), 'entry 1 cmd should default empty');
    assert(strcmp(ds.history(2).cmd, 'y = sin(x);'), 'entry 2 cmd wrong');
    assert(strcmp(ds.history(3).cmd, ''), 'entry 3 cmd should default empty');
    cats = {ds.history.category};
    assert(isequal(cats, {'import','fit','mask'}), 'category order wrong');
    fprintf('  [PASS] appendHistory append + default empty cmd\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] appendHistory append: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 3: getHistoryScript with header + comments ────────────────────
try
    ds = struct('filepath', 'sample.dat');
    ds = bosonPlotter.appendHistory(ds, 'import', 'imported sample', ...
            "data = parser.importAuto('sample.dat');");
    ds = bosonPlotter.appendHistory(ds, 'correction', 'smooth=5');
    txt = bosonPlotter.getHistoryScript(ds);
    assert(contains(txt, 'setupToolbox'),    'header missing setupToolbox');
    assert(contains(txt, 'sample.dat'),      'source filepath missing');
    assert(contains(txt, 'parser.importAuto'), 'import cmd missing');
    assert(contains(txt, '% [') && contains(txt, '] import:'), 'comment line missing');
    assert(contains(txt, 'smooth=5'),        'correction summary missing');
    fprintf('  [PASS] getHistoryScript full output\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] getHistoryScript: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 4: getHistoryScript with Header=false, IncludeComments=false ──
try
    ds = struct();
    ds = bosonPlotter.appendHistory(ds, 'manual', 'foo', "y = 2;");
    ds = bosonPlotter.appendHistory(ds, 'manual', 'bar', "z = 3;");
    txt = bosonPlotter.getHistoryScript(ds, Header=false, IncludeComments=false);
    assert(~contains(txt, 'setupToolbox'), 'header should be omitted');
    assert(contains(txt, 'y = 2;') && contains(txt, 'z = 3;'), 'cmds missing');
    assert(~contains(txt, '[') || ~contains(txt, ':'), 'unexpected comment lines');
    fprintf('  [PASS] getHistoryScript with options off\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] getHistoryScript options: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 5: getHistoryScript on empty ds.history shows note ────────────
try
    ds = struct();
    txt = bosonPlotter.getHistoryScript(ds);
    assert(contains(txt, 'no history entries'), 'empty-history note missing');
    fprintf('  [PASS] getHistoryScript on empty history\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] empty getHistoryScript: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 6: exportHistoryScript writes file; round-trip via fileread ───
try
    ds = struct();
    ds = bosonPlotter.appendHistory(ds, 'manual', 'echo', "disp('hi');");
    tmpFile = [tempname '.m'];
    cleanupTmp = onCleanup(@() tryDelete(tmpFile));
    bosonPlotter.exportHistoryScript(ds, tmpFile);
    assert(isfile(tmpFile), 'file not written');
    txt = fileread(tmpFile);
    assert(contains(txt, "disp('hi');"), 'cmd missing in file');
    fprintf('  [PASS] exportHistoryScript round-trip\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] exportHistoryScript: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 7: exportHistoryScript on empty history → emptyHistory error ──
try
    ds = struct();
    threw = false;
    try
        bosonPlotter.exportHistoryScript(ds, [tempname '.m']);
    catch ME2
        if strcmp(ME2.identifier, 'bosonPlotter:exportHistoryScript:emptyHistory')
            threw = true;
        else
            rethrow(ME2);
        end
    end
    assert(threw, 'empty history should error');
    fprintf('  [PASS] exportHistoryScript guards empty history\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] empty export: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 8: formatHistory pretty-print ──────────────────────────────────
try
    ds = struct();
    ds = bosonPlotter.appendHistory(ds, 'import', 'imported sample.dat');
    ds = bosonPlotter.appendHistory(ds, 'correction', 'smooth=5');
    txt = bosonPlotter.formatHistory(ds);
    assert(contains(txt, '1.') && contains(txt, '2.'), 'numbering missing');
    assert(contains(txt, 'import:'), 'category missing');
    assert(contains(txt, 'imported sample.dat'), 'summary missing');
    fprintf('  [PASS] formatHistory pretty-print\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] formatHistory: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 9: formatHistory MaxRows truncation ───────────────────────────
try
    ds = struct();
    for k = 1:5
        ds = bosonPlotter.appendHistory(ds, 'manual', sprintf('entry %d', k));
    end
    txt = bosonPlotter.formatHistory(ds, MaxRows=3);
    assert(contains(txt, 'entry 1') && contains(txt, 'entry 3'), 'first 3 missing');
    assert(~contains(txt, 'entry 4'), 'entry 4 should be truncated');
    assert(contains(txt, '2 more'), 'truncation footer missing');
    fprintf('  [PASS] formatHistory MaxRows truncation\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] formatHistory truncation: %s\n', ME.message);
    failed = failed + 1;
end

% ── Integration tests use a real XRDML file (same as test_gui_harness) ──
ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
XRDML_F = fullfile(ROOT, '+test_datasets', 'XRDML', 'La2NiO4_1.xrdml');
HAVE_TESTDATA = isfile(XRDML_F);

% ── Test 10: BosonPlotter buildDs seeds an 'import' entry ──────────────
try
    if ~HAVE_TESTDATA
        fprintf('  [SKIP] buildDs integration: %s missing\n', XRDML_F);
    else
        api = BosonPlotter('Visible', 'off');
        cleanupApi = onCleanup(@() api.close());
        api.addFiles({XRDML_F});
        h = api.getHistory(1);
        assert(~isempty(h), 'history empty after load');
        assert(strcmp(h(1).category, 'import'), 'first entry not import: %s', h(1).category);
        assert(contains(h(1).summary, 'imported'), 'summary lacks imported keyword');
        assert(contains(h(1).cmd, 'parser.'), 'cmd missing parser. prefix');
        fprintf('  [PASS] buildDs seeds import entry (cat=%s)\n', h(1).category);
        passed = passed + 1;
        clear cleanupApi;
    end
catch ME
    fprintf(2, '  [FAIL] buildDs integration: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 11: onApplyCorrections appends a 'correction' entry ───────────
try
    if ~HAVE_TESTDATA
        fprintf('  [SKIP] correction integration\n');
    else
        api = BosonPlotter('Visible', 'off');
        cleanupApi = onCleanup(@() api.close());
        api.addFiles({XRDML_F});
        api.applyCorrections();
        h = api.getHistory(1);
        cats = {h.category};
        assert(any(strcmp(cats, 'correction')), ...
            'correction entry missing; got cats: %s', strjoin(cats, ','));
        % Sanity: correction summary should mention at least one parameter
        corrIdx = find(strcmp(cats, 'correction'), 1);
        assert(contains(h(corrIdx).summary, 'XOff') || ...
               contains(h(corrIdx).summary, 'Smooth'), ...
            'correction summary unexpectedly empty: "%s"', h(corrIdx).summary);
        fprintf('  [PASS] onApplyCorrections appends correction entry\n');
        passed = passed + 1;
        clear cleanupApi;
    end
catch ME
    fprintf(2, '  [FAIL] correction integration: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 12: api.exportHistory + api.formatHistory ─────────────────────
try
    if ~HAVE_TESTDATA
        fprintf('  [SKIP] api integration\n');
    else
        api = BosonPlotter('Visible', 'off');
        cleanupApi = onCleanup(@() api.close());
        api.addFiles({XRDML_F});

        tmpFile = [tempname '.m'];
        cleanupTmp = onCleanup(@() tryDelete(tmpFile));
        api.exportHistory(1, tmpFile);
        assert(isfile(tmpFile), 'export did not write file');
        txt = fileread(tmpFile);
        assert(contains(txt, 'parser.'), 'parser. import line missing in script');

        formatted = api.formatHistory(1);
        assert(contains(formatted, 'import:'), 'import: missing in formatted output');
        fprintf('  [PASS] api.exportHistory + api.formatHistory\n');
        passed = passed + 1;
        clear cleanupApi;
    end
catch ME
    fprintf(2, '  [FAIL] api integration: %s\n', ME.message);
    failed = failed + 1;
end

fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_dataset_provenance: %d failure(s)', failed);
end

% ── Local helper: tolerant cleanup ─────────────────────────────────────
function tryDelete(path)
    try
        if isfile(path); delete(path); end
    catch
    end
end
