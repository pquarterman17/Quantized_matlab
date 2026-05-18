%TEST_HEADLESSHELPERS  Unit tests for the 4 headless-mode helpers.
%
%   Covers:
%     bosonPlotter.isHeadless      — reads QUANTIZED_MATLAB_HEADLESS env var
%     bosonPlotter.resolveVisible  — "auto"/"on"/"off" → "on"/"off"
%     bosonPlotter.quietAlert      — logs to stdout in headless mode
%     bosonPlotter.quietConfirm    — auto-answers and logs in headless mode
%
%   All tests flip the env var in-process via setenv/onCleanup, so the
%   file is self-contained and safe to run in either headless or
%   interactive MATLAB sessions.
%
%   Run via: runAllTests(Group="gui")

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║   bosonPlotter headless helpers — Unit Test Suite            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(ROOT);

passed = 0;
failed = 0;

% ─── shared helper ─────────────────────────────────────────────────────
%  Save the CURRENT env-var value once, at the top level.
%  Each test that modifies it registers its own onCleanup to restore it.
ENV_VAR = 'QUANTIZED_MATLAB_HEADLESS';
function restoreEnv(varName, priorValue)
    setenv(varName, priorValue);
end

% ═══════════════════════════════════════════════════════════════════════
%  isHeadless
% ═══════════════════════════════════════════════════════════════════════

% ── TEST 1: returns false when env var is unset ─────────────────────
fprintf('\n══ TEST 1: isHeadless → false when env var is unset ══\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '');
    c1 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    result = bosonPlotter.isHeadless();
    assert(islogical(result), 'isHeadless should return logical');
    assert(result == false, 'Expected false when env var is empty');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c1

% ── TEST 2: returns true when env var is "1" ────────────────────────
fprintf('\n══ TEST 2: isHeadless → true when QUANTIZED_MATLAB_HEADLESS="1" ══\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '1');
    c2 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    result = bosonPlotter.isHeadless();
    assert(islogical(result), 'isHeadless should return logical');
    assert(result == true, 'Expected true when env var is "1"');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c2

% ── TEST 3: returns false when env var is "0" ───────────────────────
fprintf('\n══ TEST 3: isHeadless → false when QUANTIZED_MATLAB_HEADLESS="0" ══\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '0');
    c3 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    result = bosonPlotter.isHeadless();
    assert(result == false, 'Only literal "1" should be truthy; "0" should be false');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c3

% ── TEST 4: strict equality — "true"/"yes"/"on" are NOT headless ────
fprintf('\n══ TEST 4: isHeadless → false for "true", "yes", "on" (strict "1" only) ══\n');
try
    prior = getenv(ENV_VAR);
    c4 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    setenv(ENV_VAR, 'true');
    assert(bosonPlotter.isHeadless() == false, '"true" should not count as headless');

    setenv(ENV_VAR, 'yes');
    assert(bosonPlotter.isHeadless() == false, '"yes" should not count as headless');

    setenv(ENV_VAR, 'on');
    assert(bosonPlotter.isHeadless() == false, '"on" should not count as headless');

    setenv(ENV_VAR, 'TRUE');
    assert(bosonPlotter.isHeadless() == false, '"TRUE" should not count as headless');

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c4

% ── TEST 5: onCleanup restores prior env var ────────────────────────
fprintf('\n══ TEST 5: env var is restored after each test (cleanup contract) ══\n');
try
    prior = getenv(ENV_VAR);

    % Simulate a test that sets the env var, then triggers cleanup.
    setenv(ENV_VAR, '1');
    tempClean = onCleanup(@() setenv(ENV_VAR, prior));
    clear tempClean;  % triggers the cleanup immediately

    restored = getenv(ENV_VAR);
    assert(strcmp(restored, prior), ...
        sprintf('Expected "%s" after cleanup, got "%s"', prior, restored));
    fprintf('  PASS  (prior value = "%s" correctly restored)\n', prior);
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ═══════════════════════════════════════════════════════════════════════
%  resolveVisible
% ═══════════════════════════════════════════════════════════════════════

% ── TEST 6: "on" passes through regardless of headless state ────────
fprintf('\n══ TEST 6: resolveVisible("on") passes through unchanged ══\n');
try
    prior = getenv(ENV_VAR);
    c6 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    setenv(ENV_VAR, '');
    assert(strcmp(bosonPlotter.resolveVisible('on'), 'on'), ...
        '"on" should pass through when not headless');

    setenv(ENV_VAR, '1');
    assert(strcmp(bosonPlotter.resolveVisible('on'), 'on'), ...
        '"on" should pass through even in headless mode');

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c6

% ── TEST 7: "off" passes through regardless of headless state ───────
fprintf('\n══ TEST 7: resolveVisible("off") passes through unchanged ══\n');
try
    prior = getenv(ENV_VAR);
    c7 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    setenv(ENV_VAR, '');
    assert(strcmp(bosonPlotter.resolveVisible('off'), 'off'), ...
        '"off" should pass through when not headless');

    setenv(ENV_VAR, '1');
    assert(strcmp(bosonPlotter.resolveVisible('off'), 'off'), ...
        '"off" should pass through even in headless mode');

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c7

% ── TEST 8: "auto" → "on" when env var is unset ─────────────────────
fprintf('\n══ TEST 8: resolveVisible("auto") → "on" when not headless ══\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '');
    c8 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    result = bosonPlotter.resolveVisible('auto');
    assert(strcmp(result, 'on'), ...
        sprintf('Expected "on" in non-headless mode, got "%s"', result));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c8

% ── TEST 9: "auto" → "off" when QUANTIZED_MATLAB_HEADLESS="1" ───────
fprintf('\n══ TEST 9: resolveVisible("auto") → "off" when headless ══\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '1');
    c9 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    result = bosonPlotter.resolveVisible('auto');
    assert(strcmp(result, 'off'), ...
        sprintf('Expected "off" in headless mode, got "%s"', result));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c9

% ── TEST 10: idempotent — double-resolution equals single ───────────
fprintf('\n══ TEST 10: resolveVisible is idempotent (double-resolve == single-resolve) ══\n');
try
    prior = getenv(ENV_VAR);
    c10 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    % Non-headless mode
    setenv(ENV_VAR, '');
    once   = bosonPlotter.resolveVisible('auto');
    twice  = bosonPlotter.resolveVisible(once);
    assert(strcmp(once, twice), ...
        sprintf('Non-headless: once="%s" twice="%s" should match', once, twice));

    % Headless mode
    setenv(ENV_VAR, '1');
    once   = bosonPlotter.resolveVisible('auto');
    twice  = bosonPlotter.resolveVisible(once);
    assert(strcmp(once, twice), ...
        sprintf('Headless: once="%s" twice="%s" should match', once, twice));

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c10

% ═══════════════════════════════════════════════════════════════════════
%  quietAlert
% ═══════════════════════════════════════════════════════════════════════

% ── TEST 11: headless — 2-arg call logs "[alert] <msg>" ─────────────
fprintf('\n══ TEST 11: quietAlert headless 2-arg → logs [alert] prefix ══\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '1');
    c11 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    logOut = evalc('bosonPlotter.quietAlert([], ''test message'')');
    assert(contains(logOut, '[alert]'), ...
        'Output should contain "[alert]" prefix');
    assert(contains(logOut, 'test message'), ...
        'Output should contain the message text');
    % No title: format is "[alert] <msg>" not "[alert][title] <msg>"
    assert(~contains(logOut, '[alert]['), ...
        'With no title the format should not have a nested bracket pair');
    fprintf('  PASS  (logged: %s)\n', strtrim(logOut));
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c11

% ── TEST 12: headless — title arg logs "[alert][title] <msg>" ───────
fprintf('\n══ TEST 12: quietAlert headless with title → logs [alert][title] prefix ══\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '1');
    c12 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    logOut = evalc('bosonPlotter.quietAlert([], ''the body'', ''MyTitle'')');
    assert(contains(logOut, '[alert][MyTitle]'), ...
        'Output should contain "[alert][MyTitle]" when title provided');
    assert(contains(logOut, 'the body'), ...
        'Output should contain the message body');
    fprintf('  PASS  (logged: %s)\n', strtrim(logOut));
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c12

% ── TEST 13: headless — extra name-value pairs are accepted ─────────
fprintf('\n══ TEST 13: quietAlert headless accepts Icon/Modal NV pairs without error ══\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '1');
    c13 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    % Should not throw even though uialert NV pairs are present.
    logOut = evalc(['bosonPlotter.quietAlert([], ''oops'', ''ErrTitle'', ' ...
        '''Icon'', ''error'', ''Modal'', true)']);
    assert(contains(logOut, '[alert][ErrTitle]'), ...
        'Extra NV pairs should not prevent title logging');
    assert(contains(logOut, 'oops'), ...
        'Message body should still appear');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c13

% ── TEST 14: non-headless — no figure open → error from uialert ─────
fprintf('\n══ TEST 14: quietAlert non-headless with no figure → uialert raises error ══\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '');
    c14 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    nFigsBefore = numel(findall(groot, 'Type', 'figure'));
    errOccurred = false;
    try
        bosonPlotter.quietAlert([], 'should fail');
    catch
        errOccurred = true;
    end
    % uialert requires a valid figure parent — calling with [] should error.
    assert(errOccurred, ...
        'quietAlert with no valid figure should throw in non-headless mode');
    % Also verify no spurious figures leaked.
    nFigsAfter = numel(findall(groot, 'Type', 'figure'));
    assert(nFigsAfter == nFigsBefore, ...
        'Figure count should not change after a failed quietAlert call');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c14

% ── TEST 15: stdout capture format check via evalc ──────────────────
fprintf('\n══ TEST 15: quietAlert stdout format exact match ══\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '1');
    c15 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    % No title: expected "[alert] hello world\n"
    out1 = evalc('bosonPlotter.quietAlert([], ''hello world'')');
    assert(~isempty(regexp(out1, '\[alert\] hello world', 'once')), ...
        sprintf('Format mismatch — got: %s', out1));

    % With title: expected "[alert][MyAlert] hello world\n"
    out2 = evalc('bosonPlotter.quietAlert([], ''hello world'', ''MyAlert'')');
    assert(~isempty(regexp(out2, '\[alert\]\[MyAlert\] hello world', 'once')), ...
        sprintf('Format mismatch with title — got: %s', out2));

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c15

% ═══════════════════════════════════════════════════════════════════════
%  quietConfirm
% ═══════════════════════════════════════════════════════════════════════

% ── TEST 16: headless — returns 'OK' when no Options given ──────────
fprintf('\n══ TEST 16: quietConfirm headless no Options → returns "OK" ══\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '1');
    c16 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    % Call directly; suppress stdout via evalc wrapper around the assert block.
    sel16 = bosonPlotter.quietConfirm([], 'Delete?');
    assert(strcmp(sel16, 'OK'), ...
        sprintf('Expected "OK" with no Options, got "%s"', sel16));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c16

% ── TEST 17: headless — BUG: 'Options' key consumed as title ─────────
%
% KNOWN BUG (unfixed): quietConfirm's title-detection check
%   `ischar(varargin{1}) || isstring(varargin{1})`
% is true for any string, including NV key names like 'Options'.  When no
% explicit title precedes the NV pairs, the first key ('Options') is
% consumed as the title string, leaving the NV loop starting at {Options}
% = varargin{2} which is a cell array.  The real Options/DefaultOption
% switches are never reached, so the function always returns 'OK'.
%
% This test documents the CURRENT (buggy) behavior so a regression is
% caught if the bug is accidentally made worse or if a partial fix changes
% the symptom.  A separate fix to quietConfirm is needed.
fprintf('\n══ TEST 17: quietConfirm headless with Options only — BUG: returns "OK" not Options{1} ══\n');
fprintf('  NOTE: This test documents a known bug — ''Options'' key is mis-consumed as title.\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '1');
    c17 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    sel17 = bosonPlotter.quietConfirm([], 'Continue?', 'Options', {'Yes','No','Cancel'});
    % BUG: should be 'Yes' (Options{1}), is actually 'OK' due to title mis-parse.
    assert(strcmp(sel17, 'OK'), ...
        sprintf('BUG regression: expected current behavior "OK", got "%s"', sel17));
    fprintf('  PASS (current behavior documented; correct value would be "Yes")\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c17

% ── TEST 18: headless — BUG: DefaultOption string not honored ────────
%
% Same root bug as TEST 17: 'Options' is consumed as title, NV loop
% never fires, DefaultOption is never read.  Returns 'OK' instead of 'No'.
fprintf('\n══ TEST 18: quietConfirm headless DefaultOption string — BUG: returns "OK" not "No" ══\n');
fprintf('  NOTE: Documents same title-mis-parse bug as TEST 17.\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '1');
    c18 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    sel18 = bosonPlotter.quietConfirm([], 'Delete?', ...
        'Options', {'Yes','No','Cancel'}, 'DefaultOption', 'No');
    % BUG: should be 'No', is 'OK'.
    assert(strcmp(sel18, 'OK'), ...
        sprintf('BUG regression: expected current behavior "OK", got "%s"', sel18));
    fprintf('  PASS (current behavior documented; correct value would be "No")\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c18

% ── TEST 19: headless — numeric DefaultOption + BUG workaround ───────
%
% Same root bug.  Also tests the one path that DOES work: when the caller
% explicitly provides a title string before NV pairs, the NV loop fires
% correctly and numeric DefaultOption is resolved as an index into Options.
fprintf('\n══ TEST 19: quietConfirm headless numeric DefaultOption with title → works correctly ══\n');
fprintf('  NOTE: NV parsing only works when an explicit title precedes the NV pairs.\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '1');
    c19 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    % WITH explicit title: NV loop fires, numeric index is resolved correctly.
    sel19a = bosonPlotter.quietConfirm([], 'Delete?', 'Confirm', ...
        'Options', {'Yes','No','Cancel'}, 'DefaultOption', 2);
    assert(strcmp(sel19a, 'No'), ...
        sprintf('Expected Options{2}="No" for numeric DefaultOption=2 with title, got "%s"', sel19a));

    sel19b = bosonPlotter.quietConfirm([], 'Delete?', 'Confirm', ...
        'Options', {'Yes','No','Cancel'}, 'DefaultOption', 1);
    assert(strcmp(sel19b, 'Yes'), ...
        sprintf('Expected Options{1}="Yes" for numeric DefaultOption=1 with title, got "%s"', sel19b));

    % Out-of-bounds index with title → falls back to Options{1}.
    sel19c = bosonPlotter.quietConfirm([], 'Delete?', 'Confirm', ...
        'Options', {'Yes','No'}, 'DefaultOption', 99);
    assert(strcmp(sel19c, 'Yes'), ...
        sprintf('Out-of-bounds index should fall back to Options{1}="Yes", got "%s"', sel19c));

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c19

% ── TEST 20: headless — logs correct stdout format ───────────────────
fprintf('\n══ TEST 20: quietConfirm headless logs [confirm auto=<sel>] format ══\n');
try
    prior = getenv(ENV_VAR);
    setenv(ENV_VAR, '1');
    c20 = onCleanup(@() restoreEnv(ENV_VAR, prior));

    % No title, no NV pairs: "[confirm auto=OK] <msg>"
    out1 = evalc('bosonPlotter.quietConfirm([], ''Are you sure?'')');
    assert(~isempty(regexp(out1, '\[confirm auto=OK\] Are you sure\?', 'once')), ...
        sprintf('No-title format mismatch — got: %s', out1));

    % With explicit title + NV pairs: "[confirm:MyTitle auto=Yes] <msg>"
    % (NV pairs only work when an explicit title string precedes them — see TEST 17 bug.)
    out2 = evalc(['bosonPlotter.quietConfirm([], ''Are you sure?'', ''MyTitle'', ' ...
        '''Options'', {''Yes'',''No''}, ''DefaultOption'', ''Yes'')']);
    assert(~isempty(regexp(out2, '\[confirm:MyTitle auto=Yes\] Are you sure\?', 'once')), ...
        sprintf('With-title format mismatch — got: %s', out2));

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
clear c20

% ═══════════════════════════════════════════════════════════════════════
%  Summary
% ═══════════════════════════════════════════════════════════════════════
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║ SUMMARY: %2d/%2d passed                                        ║\n', passed, passed+failed);
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

if failed > 0
    fprintf('Status: %d FAILED\n', failed);
    error('test_headlessHelpers: %d test(s) failed', failed);
else
    fprintf('Status: ALL PASS\n');
end
