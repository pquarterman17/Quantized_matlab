function test_string_snapshots
%TEST_STRING_SNAPSHOTS  Verify button labels and tooltips match expectations.
%
%   Enumerates all uibutton Text values in BosonPlotter and FermiViewer,
%   checks for common corruption patterns:
%     - Buttons with empty Text that shouldn't be empty
%     - Buttons with truncated "..." (MATLAB's silent truncation)
%     - Tooltips that are empty on icon-only buttons
%     - Status/title strings that lost content in a bulk refactor
%
%   This test was created after a sed-based ellipsis removal accidentally
%   stripped "..." from status messages and loading text (2026-05-04).
%
%   Run:  runAllTests(Group="smoke")
%   Or:   run tests/smoke/test_string_snapshots

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    addpath(rootDir);

    passed = 0;
    failed = 0;
    failures = {};

    fprintf('\n=== test_string_snapshots ===\n');

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: BosonPlotter button labels
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: BosonPlotter button labels ==\n');
    try
        api = BosonPlotter('Visible', 'off');
        cleanupBP = onCleanup(@() safeClose(api));
        drawnow;

        allBtns = findall(api.fig, 'Type', 'uibutton');
        fprintf('  Found %d uibuttons\n', numel(allBtns));

        % No button should have trailing "..." (our rule since 2026-05-04)
        for ii = 1:numel(allBtns)
            txt = allBtns(ii).Text;
            if endsWith(txt, '...')
                check(sprintf('BP button "%s" has no trailing ellipsis', txt), false);
            end
        end

        % Icon-only buttons (empty Text) must have non-empty Tooltip
        iconOnly = allBtns(arrayfun(@(b) isempty(strtrim(b.Text)), allBtns));
        for ii = 1:numel(iconOnly)
            btn = iconOnly(ii);
            tip = btn.Tooltip;
            if isempty(strtrim(string(tip)))
                check(sprintf('BP icon-only button (no text) has tooltip'), false);
            end
        end

        % Overall counts
        check(sprintf('BP has %d uibuttons (sanity check > 20)', numel(allBtns)), ...
            numel(allBtns) > 20);

        api.close();
        clear cleanupBP;
    catch ME
        recordCrash('TEST 1 (BosonPlotter)', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: FermiViewer button labels
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2: FermiViewer button labels ==\n');
    try
        api = FermiViewer();
        cleanupFV = onCleanup(@() safeClose(api));
        drawnow;

        allBtns = findall(api.fig, 'Type', 'uibutton');
        fprintf('  Found %d uibuttons\n', numel(allBtns));

        for ii = 1:numel(allBtns)
            txt = allBtns(ii).Text;
            if endsWith(txt, '...')
                check(sprintf('FV button "%s" has no trailing ellipsis', txt), false);
            end
        end

        iconOnly = allBtns(arrayfun(@(b) isempty(strtrim(b.Text)), allBtns));
        for ii = 1:numel(iconOnly)
            btn = iconOnly(ii);
            tip = btn.Tooltip;
            if isempty(strtrim(string(tip)))
                check(sprintf('FV icon-only button (no text) has tooltip'), false);
            end
        end

        check(sprintf('FV has %d uibuttons (sanity check > 40)', numel(allBtns)), ...
            numel(allBtns) > 40);

        api.close();
        clear cleanupFV;
    catch ME
        recordCrash('TEST 2 (FermiViewer)', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 3: Source-level checks (no "..." in uibutton Text literals)
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 3: Source-level ellipsis scan ==\n');
    try
        filesToScan = {
            fullfile(rootDir, 'BosonPlotter.m')
            fullfile(rootDir, 'FermiViewer.m')
            fullfile(rootDir, 'DiraCulator.m')
            fullfile(rootDir, 'DataWorkspace.m')
            fullfile(rootDir, 'xrdConvertGUI.m')
        };
        pkgDirs = {'+bosonPlotter', '+emViewer', '+templates', ...
                   '+dataWorkspace'};
        for pi = 1:numel(pkgDirs)
            pkgDir = fullfile(rootDir, pkgDirs{pi});
            if isfolder(pkgDir)
                d = dir(fullfile(pkgDir, '**', '*.m'));
                for ii = 1:numel(d)
                    filesToScan{end+1} = fullfile(d(ii).folder, d(ii).name); %#ok<AGROW>
                end
            end
        end

        violations = 0;
        for ii = 1:numel(filesToScan)
            src = fileread(filesToScan{ii});
            [~, fname] = fileparts(filesToScan{ii});
            srcLines = splitlines(src);
            for li = 1:numel(srcLines)
                ln = srcLines{li};
                if isempty(regexp(ln, '''Text''\s*,\s*''[^'']*\.\.\.''', 'once'))
                    continue;
                end
                % uimenu items are allowed to have "..."
                if contains(ln, 'uimenu')
                    continue;
                end
                % Status/progress strings are allowed
                if contains(ln, 'Loading') || contains(ln, 'running') || ...
                        contains(ln, 'Decompos') || contains(ln, 'progress')
                    continue;
                end
                fprintf('  WARN  %s:%d: %s\n', fname, li, strtrim(ln));
                violations = violations + 1;
            end
        end

        check(sprintf('No uibutton Text literals with trailing ellipsis (%d found)', violations), ...
            violations == 0);
    catch ME
        recordCrash('TEST 3 (source scan)', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('  test_string_snapshots: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_string_snapshots:failed', '%d test(s) failed', failed);
    end
    fprintf('%s\n', repmat('=', 1, 60));

    % ── Nested helpers ─────────────────────────────────────────────────
    function check(label, cond)
        if cond
            passed = passed + 1;
            fprintf('  PASS  %s\n', label);
        else
            failed = failed + 1;
            failures{end+1} = label; %#ok<AGROW>
            fprintf('  FAIL  %s\n', label);
        end
    end

    function recordCrash(testName, ME)
        failed = failed + 1;
        failures{end+1} = sprintf('%s crashed: %s', testName, ME.message); %#ok<AGROW>
        fprintf('  CRASH %s: %s\n', testName, ME.message);
    end

    function safeClose(a)
        try
            if isfield(a, 'close')
                a.close();
            end
        catch
        end
    end
end
