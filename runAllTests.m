function runAllTests(options)
%RUNALLTESTS  Run the complete test suite and print a summary report.
%
%   Syntax:
%       runAllTests
%       runAllTests(Group="parser")
%
%   Name-Value Options:
%       Group    "all" (default) | "parser" | "batch" | "gui" | "xrd2d"
%                Run only the specified group of test suites.
%
%   Groups:
%       parser   — core parser smoke tests and edge cases (no GUI, fast)
%       batch    — batch import and XRD converter integration tests
%       xrd2d    — 2D area-detector XRDML parser and edge-case tests
%       gui      — headless GUI API tests (opens/closes figures)
%       all      — all of the above, in order
%
%   Examples:
%       runAllTests                   % full suite
%       runAllTests(Group="parser")   % fast parser checks only
%       runAllTests(Group="gui")      % GUI tests only
%
%   Throws an error if any suite fails so CI/scripts can detect failures.

arguments
    options.Group string = "all"
end

options.Group = validatestring(options.Group, ...
    ["all", "parser", "batch", "xrd2d", "gui"]);

% Build absolute paths to test scripts so `run` works regardless of CWD.
ROOT  = fileparts(mfilename('fullpath'));
T     = @(name) fullfile(ROOT, 'tests', name);

SUITES = {
    % absolute path                      group     description
    T('test_parsers'),             'parser', 'Parser smoke tests (all formats)'
    T('test_importAuto'),          'parser', 'importAuto dispatch'
    T('test_parsers_edge_cases'),  'parser', 'Parser edge cases / error handling'
    T('test_data_roundtrip'),      'parser', 'CSV export round-trip'
    T('test_batch_processing'),    'batch',  'batchImport + batchConvertXRD'
    T('test_batch_xrd_converter'), 'batch',  'XRD converter GUI edge cases'
    T('test_xrdml_2d'),            'xrd2d',  '2D XRDML parser (parser + Q-space)'
    T('test_xrdml_2d_edge'),       'xrd2d',  '2D XRDML edge cases (shapes, cuts, session)'
    T('test_gui_harness'),         'gui',    'GUI API: load, correct, peaks, session'
    T('test_gui_2d'),              'gui',    'GUI API: 2D map load, plot types, cuts'
    T('test_gui_phase4'),          'gui',    'GUI API: Q-space, colormap, mixed datasets'
};

% Filter by group
if ~strcmp(options.Group, "all")
    mask   = strcmp(SUITES(:,2), char(options.Group));
    SUITES = SUITES(mask, :);
end

nSuites = size(SUITES, 1);
if nSuites == 0
    fprintf('No suites match group "%s".\n', options.Group);
    return;
end

% ── Run each suite ────────────────────────────────────────────────────
passed  = false(1, nSuites);
msgs    = cell(1,  nSuites);
elapsed = zeros(1, nSuites);

sep = repmat(char(9552), 1, 68);
fprintf('\n%s\n', sep);
fprintf('  runAllTests — %d suite(s)  [group: %s]\n', nSuites, options.Group);
fprintf('%s\n', sep);

for k = 1:nSuites
    abspath = SUITES{k,1};
    [~, shortname] = fileparts(abspath);
    desc = SUITES{k,3};
    fprintf('\n  ▶  tests/%s\n     %s\n', shortname, desc);
    t0 = tic;
    [passed(k), msgs{k}] = runSuite(abspath);
    elapsed(k) = toc(t0);
    if passed(k)
        fprintf('     ✔  PASS  (%.1f s)\n', elapsed(k));
    else
        fprintf('     ✘  FAIL  (%.1f s)\n', elapsed(k));
        fprintf('        %s\n', msgs{k});
    end
end

% ── Summary ───────────────────────────────────────────────────────────
nPass = sum(passed);
nFail = nSuites - nPass;

fprintf('\n%s\n', sep);
fprintf('  SUMMARY: %d / %d suites passed  (%.1f s total)\n', ...
    nPass, nSuites, sum(elapsed));
fprintf('%s\n', sep);

if nFail > 0
    fprintf('\n  Failed suites:\n');
    for k = find(~passed)
        [~, shortname] = fileparts(SUITES{k,1});
        fprintf('    ✘  tests/%s\n', shortname);
    end
    fprintf('\n');
    error('runAllTests:failures', '%d suite(s) failed.', nFail);
else
    fprintf('\n  All suites PASSED.\n\n');
end

end % runAllTests


% ── Local helper — runs one suite in its own isolated workspace ────────
function [ok, msg] = runSuite(suitePath)
%RUNSUITE  Execute a test script and return pass/fail.
%   The test script runs in this function's workspace, so its `clear`
%   only affects local variables here — the caller's state is untouched.
%   `ok` and `msg` are assigned after `run` returns, so they survive
%   any `clear` that the test script issues at startup.
    try
        run(suitePath);
        ok  = true;
        msg = '';
    catch ME
        ok  = false;
        msg = ME.message;
    end
end
