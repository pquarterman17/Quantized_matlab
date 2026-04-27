%TEST_RESOLVETHEME  Unit tests for bosonPlotter.resolveTheme.
%
%   Verifies that:
%     1. 'Dark' / 'Light' pass through unchanged.
%     2. Empty / unknown input falls back to 'Dark'.
%     3. 'Auto' resolves to a concrete 'Dark' or 'Light' string (the
%        actual value depends on the host OS appearance, but the result
%        must be one of those two).
%     4. No-arg form reads themePref then resolves.
%
%   Run via: runAllTests(Group="gui")

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║   bosonPlotter.resolveTheme — Unit Test Suite                   ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(ROOT);

passed = 0;
failed = 0;

% ═══════════════════════════════════════════════════════════════════════
%  TEST 1: Dark / Light passthrough
% ═══════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: Dark/Light pass through unchanged ══\n');
try
    assert(strcmp(bosonPlotter.resolveTheme('Dark'), 'Dark'), 'Dark should pass through');
    assert(strcmp(bosonPlotter.resolveTheme('Light'), 'Light'), 'Light should pass through');
    assert(strcmp(bosonPlotter.resolveTheme('dark'), 'Dark'), 'lowercase dark should normalise to Dark');
    assert(strcmp(bosonPlotter.resolveTheme('LIGHT'), 'Light'), 'uppercase LIGHT should normalise to Light');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ═══════════════════════════════════════════════════════════════════════
%  TEST 2: Unknown / empty falls back to Dark
% ═══════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: unknown / empty → Dark fallback ══\n');
try
    assert(strcmp(bosonPlotter.resolveTheme('Bogus'), 'Dark'), 'unknown value should default to Dark');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ═══════════════════════════════════════════════════════════════════════
%  TEST 3: Auto resolves to concrete Dark or Light
% ═══════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: Auto resolves to a concrete theme ══\n');
try
    out = bosonPlotter.resolveTheme('Auto');
    assert(ischar(out), 'Auto resolution should return a char vector');
    assert(any(strcmp(out, {'Dark','Light'})), ...
        sprintf('Auto must resolve to Dark or Light, got %s', out));
    fprintf('  PASS  (Auto → %s on this host)\n', out);
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ═══════════════════════════════════════════════════════════════════════
%  TEST 4: No-arg form reads themePref + resolves
% ═══════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: no-arg form reads themePref ══\n');
try
    out = bosonPlotter.resolveTheme();
    assert(ischar(out), 'no-arg call should return a char vector');
    assert(any(strcmp(out, {'Dark','Light'})), ...
        'no-arg call must always return Dark or Light (Auto is internal)');
    fprintf('  PASS  (themePref-resolved → %s)\n', out);
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ═══════════════════════════════════════════════════════════════════════
%  TEST 5: themePref accepts 'Auto'
% ═══════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: themePref read/write Auto ══\n');
try
    % Save current pref to restore after the test.
    original = bosonPlotter.themePref('read');
    cleanup = onCleanup(@() bosonPlotter.themePref('write', original));

    bosonPlotter.themePref('write', 'Auto');
    rt = bosonPlotter.themePref('read');
    assert(strcmp(rt, 'Auto'), sprintf('themePref should return Auto, got %s', rt));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ── Summary ────────────────────────────────────────────────────────────
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║ Results: %2d passed, %2d failed                                ║\n', passed, failed);
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

if failed > 0
    error('test_resolveTheme: %d test(s) failed', failed);
end
