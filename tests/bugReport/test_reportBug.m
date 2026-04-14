%TEST_REPORTBUG  Tests for bugReport.buildReport and bugReport.formatReportMarkdown.
%
%   Run standalone:  run tests/bugReport/test_reportBug
%   Run via group:   runAllTests(Group="bugReport")

clear; clc;

% Ensure toolbox is on the path
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

passed = 0; failed = 0;

% ── 1. buildReport with no arguments returns a valid struct ─────────────
fprintf('=== 1. buildReport() with no args ===\n');
try
    r = bugReport.buildReport();
    assert(isstruct(r), 'report must be a struct');
    assert(isfield(r, 'env'),         'missing .env');
    assert(isfield(r, 'error'),       'missing .error');
    assert(isfield(r, 'dataset'),     'missing .dataset');
    assert(isfield(r, 'description'), 'missing .description');
    assert(isfield(r, 'email'),       'missing .email');
    assert(isfield(r, 'source'),      'missing .source');
    assert(isfield(r, 'generatedAt'), 'missing .generatedAt');
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ── 2. env block is populated with real values ──────────────────────────
fprintf('=== 2. env block populated ===\n');
try
    r = bugReport.buildReport();
    assert(r.env.matlabRelease ~= "",     'matlabRelease empty');
    assert(r.env.computer ~= "",          'computer empty');
    assert(r.env.toolboxRoot ~= "",       'toolboxRoot empty');
    % gitSha may be 'unknown' if git not on PATH — that's OK
    assert(strlength(r.env.gitSha) > 0,   'gitSha empty');
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ── 3. Git SHA falls back gracefully ────────────────────────────────────
fprintf('=== 3. git fallback (PATH manipulation) ===\n');
try
    % Temporarily break PATH so `git` resolves to nothing
    origPath = getenv('PATH');
    cleanup  = onCleanup(@() setenv('PATH', origPath));
    setenv('PATH', '');
    r = bugReport.buildReport();
    assert(~isempty(char(r.env.gitSha)), 'gitSha should never be empty string');
    % With broken PATH, gitSha should be "unknown"
    clear cleanup;  % restore
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ── 4. Explicit error passes through ────────────────────────────────────
fprintf('=== 4. explicit Error argument ===\n');
try
    ME_fake = MException('test:bug', 'Something broke at line %d', 42);
    r = bugReport.buildReport(Error=ME_fake);
    assert(isfield(r.error, 'identifier'),              'missing identifier');
    assert(strcmp(r.error.identifier, 'test:bug'),      'identifier mismatch');
    assert(contains(r.error.message, 'line 42'),        'message mismatch');
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ── 5. Dataset metadata is extracted ────────────────────────────────────
fprintf('=== 5. dataset metadata extraction ===\n');
try
    ds = parser.createDataStruct((1:10)', (1:10)'.*[1 2 3], ...
        'labels', {'A', 'B', 'C'}, ...
        'units',  {'K', 'emu', ''}, ...
        'metadata', struct('parser', 'importTest', 'filename', '/tmp/foo.dat'));
    r = bugReport.buildReport(Dataset=ds);
    assert(isfield(r.dataset, 'parser'),       'missing parser');
    assert(isfield(r.dataset, 'filename'),     'missing filename');
    assert(isfield(r.dataset, 'labels'),       'missing labels');
    assert(r.dataset.nRows == 10,              'nRows mismatch');
    assert(r.dataset.nCols == 3,               'nCols mismatch');
    assert(strcmp(r.dataset.filename, 'foo.dat'), 'filename not basename');
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ── 6. formatReportMarkdown produces non-empty markdown ─────────────────
fprintf('=== 6. formatReportMarkdown minimal ===\n');
try
    r = bugReport.buildReport(Source="UnitTest", Description="It crashed.");
    md = bugReport.formatReportMarkdown(r);
    assert(ischar(md),                          'markdown must be char');
    assert(~isempty(md),                        'markdown empty');
    assert(contains(md, 'Bug Report'),          'missing title');
    assert(contains(md, 'Environment'),         'missing env section');
    assert(contains(md, 'MATLAB release'),      'missing matlab line');
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ── 7. ContextOnly mode ─────────────────────────────────────────────────
fprintf('=== 7. formatReportMarkdown ContextOnly ===\n');
try
    r = bugReport.buildReport();
    full = bugReport.formatReportMarkdown(r);
    ctx  = bugReport.formatReportMarkdown(r, ContextOnly=true);
    assert(~contains(ctx, 'Bug Report'),        'ContextOnly should not have title');
    assert(contains(ctx, 'Environment'),        'ContextOnly missing env');
    assert(numel(ctx) < numel(full),            'ContextOnly should be shorter');
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ── 8. Markdown includes error section when present ─────────────────────
fprintf('=== 8. error section rendering ===\n');
try
    ME_fake = MException('alpha:beta', 'boom');
    r = bugReport.buildReport(Error=ME_fake);
    md = bugReport.formatReportMarkdown(r);
    assert(contains(md, 'Last Error'),          'missing error section');
    assert(contains(md, 'alpha:beta'),          'missing identifier');
    assert(contains(md, 'boom'),                'missing message');
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ── 9. Markdown includes dataset section when present ───────────────────
fprintf('=== 9. dataset section rendering ===\n');
try
    ds = parser.createDataStruct((1:5)', (1:5)', ...
        'labels', {'X'}, 'units', {'m'}, ...
        'metadata', struct('parser','importTest','filename','bar.csv'));
    r  = bugReport.buildReport(Dataset=ds);
    md = bugReport.formatReportMarkdown(r);
    assert(contains(md, 'Active Dataset'),      'missing dataset section');
    assert(contains(md, 'bar.csv'),             'missing filename');
    assert(contains(md, 'importTest'),          'missing parser');
    assert(contains(md, '5 rows'),              'missing row count');
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ── 10. URL encoding round-trips special chars ──────────────────────────
fprintf('=== 10. urlencode handles special chars ===\n');
try
    bad = sprintf('Title with & symbols and\nnewlines and "quotes"');
    encoded = urlencode(bad);
    assert(~contains(encoded, '&'),             'unencoded ampersand');
    assert(~contains(encoded, char(10)),        'unencoded newline'); %#ok<CHARTEN>
    assert(~contains(encoded, '"'),             'unencoded quote');
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ═══════════════════════════════════════════════════════════════════════
fprintf('\n=== Summary: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_reportBug:failures', '%d test(s) failed.', failed);
end
