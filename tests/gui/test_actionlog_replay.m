%TEST_ACTIONLOG_REPLAY  Tests for actionLog replay infrastructure (W3 #14).
%   Covers `bosonPlotter.serializeArg`, `actionLog.recordCall`, and the
%   `bosonPlotter.exportScript(fig, path)` free function — together they
%   provide structured action recording and figure→script export for
%   reproducible BosonPlotter sessions.
%
%   Run:  runAllTests(Group="gui")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir); addpath(rootDir); end

fprintf('\n=== test_actionlog_replay ===\n');
passed = 0; failed = 0;

% ── Test 1: serializeArg basic types ────────────────────────────────────
try
    cases = {
        % {value, expected}
        5,                 '5'
        3.14,              '3.14'
        'hello',           '''hello'''
        "hello",           '"hello"'
        true,              'true'
        false,             'false'
        [1 2 3],           '[1 2 3]'
        [],                '[]'
        {1, 'two'},        '{1, ''two''}'
        };
    for k = 1:size(cases, 1)
        v   = cases{k, 1};
        exp = cases{k, 2};
        got = bosonPlotter.serializeArg(v);
        assert(strcmp(got, exp), ...
            'serializeArg(case %d) → "%s", expected "%s"', k, got, exp);
    end
    fprintf('  [PASS] serializeArg basic types (%d cases)\n', size(cases, 1));
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] serializeArg basics: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 2: serializeArg round-trip via eval ────────────────────────────
try
    cases = {5, 3.14, 'hello', "world", true, [1 2 3], [1.1 2.2; 3.3 4.4], ...
             {1, 'two', [3 4]}, false(1,3)};
    for k = 1:numel(cases)
        v = cases{k};
        s = bosonPlotter.serializeArg(v);
        roundtrip = eval(s);
        assert(isequal(roundtrip, v), ...
            'serializeArg round-trip (case %d) — original=%s got=%s', ...
            k, formattedDisplayText(v), formattedDisplayText(roundtrip));
    end
    fprintf('  [PASS] serializeArg round-trip via eval (%d cases)\n', numel(cases));
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] serializeArg roundtrip: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 3: serializeArg quote escaping ─────────────────────────────────
try
    s = bosonPlotter.serializeArg('it''s');                 % char with apostrophe
    assert(strcmp(s, '''it''''s'''), 'apostrophe escape: %s', s);
    s = bosonPlotter.serializeArg("a""b");                  % string with quote
    assert(strcmp(s, '"a""b"'), 'string quote escape: %s', s);
    fprintf('  [PASS] serializeArg quote escaping\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] quote escape: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 4: recordCall builds correct command (no Lhs) ─────────────────
try
    log = bosonPlotter.actionLog();
    log.recordCall("plot", {[1 2 3], [4 5 6]});
    cmds = log.getLog();
    assert(numel(cmds) == 1, 'Expected 1 entry');
    assert(strcmp(cmds{1}, 'plot([1 2 3], [4 5 6]);'), ...
        'recordCall: got "%s"', cmds{1});
    fprintf('  [PASS] recordCall (no Lhs)\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] recordCall basic: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 5: recordCall with Lhs and Raw expressions ─────────────────────
try
    log = bosonPlotter.actionLog();
    log.recordCall("parser.importAuto", {'sample.dat'}, Lhs="d");
    log.recordCall("utilities.smoothData", {"d.time", "d.values", 5}, ...
                   Lhs="d.values", Raw=[true true false]);
    cmds = log.getLog();
    assert(strcmp(cmds{1}, 'd = parser.importAuto(''sample.dat'');'), ...
        'Lhs1: got "%s"', cmds{1});
    assert(strcmp(cmds{2}, 'd.values = utilities.smoothData(d.time, d.values, 5);'), ...
        'Raw mask: got "%s"', cmds{2});
    fprintf('  [PASS] recordCall with Lhs + Raw mask\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] recordCall Lhs/Raw: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 6: recordCall errors on bad Raw mask size ──────────────────────
try
    log = bosonPlotter.actionLog();
    threw = false;
    try
        log.recordCall("foo", {1, 2, 3}, Raw=[true false]);   % 2 entries for 3 args
    catch ME2
        if strcmp(ME2.identifier, 'bosonPlotter:actionLog:rawMaskSize')
            threw = true;
        else
            rethrow(ME2);
        end
    end
    assert(threw, 'Bad Raw mask should error');
    fprintf('  [PASS] recordCall validates Raw size\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] Raw size validation: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 7: exportScript(fig, path) writes runnable .m ──────────────────
try
    api = BosonPlotter('Visible', 'off');
    cleanup = onCleanup(@() api.close());
    api.startMacroRecord();
    log = api.getMacroLog();
    log.recordCall("disp", {'replay-test'});
    log.recordCall("a", {2, 3}, Lhs="result");        % result = a(2, 3);
    api.stopMacroRecord();

    tmpFile = [tempname '.m'];
    cleanupTmp = onCleanup(@() tryDelete(tmpFile));

    bosonPlotter.exportScript(api.fig, tmpFile);
    assert(isfile(tmpFile), 'Script file not created');
    txt = fileread(tmpFile);
    assert(contains(txt, 'disp(''replay-test'');'), ...
        'Recorded disp call missing in exported script');
    assert(contains(txt, 'result = a(2, 3);'), ...
        'Recorded Lhs call missing in exported script');
    assert(contains(txt, 'setupToolbox'), ...
        'Setup directive missing in exported script');
    fprintf('  [PASS] exportScript(fig, path) round-trip\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] exportScript fig: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 8: exportScript on unhooked figure errors gracefully ───────────
try
    extraneousFig = uifigure('Visible','off');
    cleanupF = onCleanup(@() delete(extraneousFig));
    threw = false;
    try
        bosonPlotter.exportScript(extraneousFig, [tempname '.m']);
    catch ME2
        if strcmp(ME2.identifier, 'bosonPlotter:exportScript:noMacroLog')
            threw = true;
        else
            rethrow(ME2);
        end
    end
    assert(threw, 'Plain figure should error with noMacroLog');
    fprintf('  [PASS] exportScript guards against non-BosonPlotter figures\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] exportScript guard: %s\n', ME.message);
    failed = failed + 1;
end

% ── Test 9: exportScript on empty log errors with emptyLog id ───────────
try
    api = BosonPlotter('Visible', 'off');
    cleanup = onCleanup(@() api.close());
    threw = false;
    try
        bosonPlotter.exportScript(api.fig, [tempname '.m']);
    catch ME2
        if strcmp(ME2.identifier, 'bosonPlotter:exportScript:emptyLog')
            threw = true;
        else
            rethrow(ME2);
        end
    end
    assert(threw, 'Empty log should error');
    fprintf('  [PASS] exportScript on empty log → emptyLog error\n');
    passed = passed + 1;
catch ME
    fprintf(2, '  [FAIL] empty log: %s\n', ME.message);
    failed = failed + 1;
end

fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_actionlog_replay: %d failure(s)', failed);
end

% ── Local helper: tolerant cleanup ─────────────────────────────────────
function tryDelete(path)
    try
        if isfile(path); delete(path); end
    catch
        % swallow
    end
end
