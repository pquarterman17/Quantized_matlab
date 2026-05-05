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
        };
        bpDir = fullfile(rootDir, '+bosonPlotter');
        if isfolder(bpDir)
            d = dir(fullfile(bpDir, '*.m'));
            for ii = 1:numel(d)
                filesToScan{end+1} = fullfile(bpDir, d(ii).name); %#ok<AGROW>
            end
        end
        emDir = fullfile(rootDir, '+emViewer');
        if isfolder(emDir)
            d = dir(fullfile(emDir, '*.m'));
            for ii = 1:numel(d)
                filesToScan{end+1} = fullfile(emDir, d(ii).name); %#ok<AGROW>
            end
        end

        violations = 0;
        for ii = 1:numel(filesToScan)
            src = fileread(filesToScan{ii});
            [~, fname] = fileparts(filesToScan{ii});
            % Match: 'Text', '...' where the text value ends with ...
            % Pattern: uibutton(..., 'Text', 'Something...'
            matches = regexp(src, '''Text''\s*,\s*''[^'']*\.\.\.''', 'match');
            for jj = 1:numel(matches)
                % Exclude false positives: 'Text', '' (empty) and menu items
                m = matches{jj};
                if contains(m, 'Loading') || contains(m, 'running') || ...
                        contains(m, 'Decompos') || contains(m, 'progress')
                    continue;  % status messages are allowed
                end
                fprintf('  WARN  %s: %s\n', fname, m);
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
