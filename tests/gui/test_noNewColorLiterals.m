function test_noNewColorLiterals
%TEST_NONEWCOLORLITERALS  Static check: no NEW hardcoded RGB colour literals.
%
%   Scans BosonPlotter.m and +bosonPlotter/*.m for RGB-triplet literals
%   like [0.94 0.94 0.94] used in colour contexts (BackgroundColor,
%   FontColor, ForegroundColor, BorderColor, GridColor). Each match is
%   compared against a baseline count snapshot — the test FAILS if the
%   total grows above the snapshot.
%
%   Allowlist (skipped entirely):
%     +bosonPlotter/uxTokens.m   — palette source
%     +styles/*.m                 — plot palettes
%
%   Goal: catch new hardcoded colours at PR time before they ship,
%   complementing the runtime theme conformance test that checks the
%   live GUI's painted state. Together they form a layered defense:
%     - Runtime test (test_themeConformance) catches widgets with
%       off-palette painted colours, including those that bypass the
%       construction-time tokens.
%     - Static test (this file) catches new RGB literals at the source
%       level so reviewers see them before they reach the GUI tree.
%
%   Run standalone:  run tests/gui/test_noNewColorLiterals
%   Run via group :  runAllTests(Group="gui")
%
%   When intentionally adding a new colour literal: bump BASELINE_COUNT
%   (with a comment justifying why a token doesn't fit). When tokenising
%   an existing literal: ratchet BASELINE_COUNT downward.

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));

    % Baseline as of 2026-04-25 — set after the uxTokens/onThemeChanged
    % refactor with a small in-flight buffer (~10). Ratchet DOWN as
    % literals are tokenised. NEVER raise the cap without a documented
    % reason in the commit message — that's the whole point.
    BASELINE_COUNT = 206;

    files = collectMatlabFiles(rootDir);
    totalHits = 0;
    perFileHits = struct('file', {}, 'count', {}, 'samples', {});
    rgbPattern = '\[\s*\d*\.?\d+\s+\d*\.?\d+\s+\d*\.?\d+\s*\]';
    % Allow up to 12 chars (quotes, commas, whitespace) between the
    % property name and the literal — this covers ', '   and similar.
    contextPattern = ['(BackgroundColor|FontColor|ForegroundColor|' ...
                      'BorderColor|GridColor|StripeColor)' ...
                      '[^\n\[]{0,12}' rgbPattern];

    for fi = 1:numel(files)
        fp = files{fi};
        if isAllowlisted(fp), continue; end
        try
            txt = fileread(fp);
        catch
            continue;
        end
        matches = regexp(txt, contextPattern, 'match');
        if isempty(matches), continue; end
        % Rough sample for the report
        sample = matches{1};
        if numel(sample) > 80, sample = [sample(1:77) '...']; end
        relPath = strrep(fp, [rootDir filesep], '');
        perFileHits(end+1) = struct( ...
            'file', relPath, 'count', numel(matches), ...
            'samples', sample); %#ok<AGROW>
        totalHits = totalHits + numel(matches);
    end

    fprintf('\n== test_noNewColorLiterals: scan ==\n');
    fprintf('  Files scanned : %d\n', numel(files));
    fprintf('  Hits          : %d\n', totalHits);
    fprintf('  Baseline cap  : %d\n', BASELINE_COUNT);

    if totalHits > 0
        fprintf('\n  Per-file counts:\n');
        for k = 1:numel(perFileHits)
            fprintf('    %4d  %s\n', perFileHits(k).count, perFileHits(k).file);
        end
    end

    if totalHits > BASELINE_COUNT
        fprintf(['\n  !! Hardcoded colour count %d EXCEEDS baseline %d.\n' ...
                 '     Use bosonPlotter.uxTokens() colours instead of new\n' ...
                 '     literals. If a new accent is genuinely needed, add\n' ...
                 '     it to uxTokens or bump BASELINE_COUNT in this test\n' ...
                 '     with a justification in the diff.\n'], ...
                totalHits, BASELINE_COUNT);
        error('test_noNewColorLiterals:exceeded', ...
            'New hardcoded colour literals: count %d > baseline %d', ...
            totalHits, BASELINE_COUNT);
    end

    if BASELINE_COUNT - totalHits > 10
        fprintf(['\n  NOTE: %d hits below baseline; ratchet BASELINE_COUNT\n' ...
                 '        down to %d on next commit.\n'], ...
                BASELINE_COUNT - totalHits, totalHits + 5);
    end

    fprintf('\n  PASS  hardcoded literals at or below baseline.\n');
    fprintf('%s\n', repmat('=', 1, 68));
end

% ════════════════════════════════════════════════════════════════════════
function files = collectMatlabFiles(rootDir)
%COLLECTMATLABFILES  Walk the repo for .m sources we care about.
    files = {};
    files = appendDir(files, rootDir, 'BosonPlotter.m');
    files = appendDir(files, rootDir, fullfile('+bosonPlotter', '*.m'));
end

function out = appendDir(in, rootDir, pattern)
    list = dir(fullfile(rootDir, pattern));
    out = in;
    for k = 1:numel(list)
        if list(k).isdir, continue; end
        out{end+1} = fullfile(list(k).folder, list(k).name); %#ok<AGROW>
    end
end

function tf = isAllowlisted(fp)
%ISALLOWLISTED  Files that legitimately contain RGB literals.
    name = lower(fp);
    tf = contains(name, 'uxtokens.m') || ...
         contains(name, ['+styles' filesep]) || ...
         contains(name, fullfile('tests', 'gui', 'test_themeConformance.m')) || ...
         contains(name, fullfile('tests', 'gui', 'test_noNewColorLiterals.m'));
end
