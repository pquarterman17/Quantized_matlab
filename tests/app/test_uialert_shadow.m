function test_uialert_shadow
%TEST_UIALERT_SHADOW  Verify that tests/shadows/uialert.m and uiconfirm.m
%   intercept calls in headless mode and pass through in normal mode.
%
%   Tests:
%     1. Shadow uialert returns cleanly (no error, no dialog) in headless mode.
%     2. Shadow uiconfirm auto-answers (first option) in headless mode.
%     3. Shadow uiconfirm honours string 'DefaultOption' in headless mode.
%     4. Shadow uiconfirm honours numeric 'DefaultOption' in headless mode.
%     5. Real MATLAB uialert / uiconfirm are still reachable (non-shadow entry
%        on the path) so the path-restore logic has somewhere to delegate to.
%     6. Shadow path-restore is idempotent: rmpath+addpath leaves path unchanged.
%     7. uiconfirm fallback: empty Options cell → returns 'OK'.
%
%   Invocation:
%       % Headless (recommended — exercises intercept path):
%       $env:QUANTIZED_MATLAB_HEADLESS = "1"
%       matlab -batch "set(groot,'DefaultFigureVisible','off'); ...
%                      cd('<root>'); addpath(pwd); setupToolbox; ...
%                      addpath(fullfile(pwd,'tests','shadows'),'-begin'); ...
%                      run('tests/app/test_uialert_shadow')"
%
%       % Normal mode (exercises path-restore checks):
%       run tests/app/test_uialert_shadow
%
%   Run via group:  runAllTests(Group="app")

    % ── Setup ──────────────────────────────────────────────────────────
    thisDir   = fileparts(mfilename('fullpath'));
    rootDir   = fileparts(fileparts(thisDir));
    shadowDir = fullfile(rootDir, 'tests', 'shadows');

    if ~contains(path, rootDir), addpath(rootDir); end
    setupToolbox();

    % Ensure shadow is on path for the duration of this test.
    shadowAlreadyOnPath = contains(path, shadowDir);
    if ~shadowAlreadyOnPath
        addpath(shadowDir, '-begin');
        shadowCleanup = onCleanup(@() rmpath(shadowDir));
    end

    passed   = 0;
    failed   = 0;
    failures = {};

    sep = repmat(char(9552), 1, 68);
    fprintf('\n%s\n  test_uialert_shadow\n%s\n', sep, sep);

    headless = bosonPlotter.isHeadless();
    fprintf('  Environment: QUANTIZED_MATLAB_HEADLESS=%d\n\n', headless);

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1 — uialert: no error in headless mode (dialog suppressed)
    % ════════════════════════════════════════════════════════════════════
    fprintf('TEST 1: uialert — headless suppression (no error)\n');
    try
        if headless
            % In headless mode the shadow must return cleanly without
            % trying to open a dialog (which would hang -batch mode).
            uialert([], 'Test message', 'Test Title');
            check('uialert headless: returns without error', true);
        else
            % Non-headless: just verify the path-restore cycle (TEST 6).
            check('uialert headless: skip in non-headless mode', true);
        end
    catch ME
        check('uialert headless: must not throw', false);
        fprintf('    error: %s\n', ME.message);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2 — uialert: no-title call also accepted
    % ════════════════════════════════════════════════════════════════════
    fprintf('\nTEST 2: uialert — no-title variant\n');
    try
        if headless
            uialert([], 'Plain message');
            check('uialert no-title headless: returns without error', true);
        else
            check('uialert no-title: skip in non-headless mode', true);
        end
    catch ME
        check('uialert no-title headless: must not throw', false);
        fprintf('    error: %s\n', ME.message);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 3 — uiconfirm: auto-answers with first option when headless
    % ════════════════════════════════════════════════════════════════════
    fprintf('\nTEST 3: uiconfirm — headless auto-answer (first option)\n');
    try
        if headless
            sel = uiconfirm([], 'Continue?', 'Confirm', ...
                'Options', {'Yes', 'No', 'Cancel'});
            check('uiconfirm headless: returns first option (Yes)', ...
                strcmp(sel, 'Yes'));
        else
            check('uiconfirm first-option: skip in non-headless mode', true);
        end
    catch ME
        check('uiconfirm first-option headless: must not throw', false);
        fprintf('    error: %s\n', ME.message);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 4 — uiconfirm: honours string DefaultOption
    % ════════════════════════════════════════════════════════════════════
    fprintf('\nTEST 4: uiconfirm — headless string DefaultOption\n');
    try
        if headless
            sel = uiconfirm([], 'Delete?', 'Confirm Delete', ...
                'Options',       {'Delete', 'Keep', 'Cancel'}, ...
                'DefaultOption', 'Keep', ...
                'CancelOption',  'Cancel');
            check('uiconfirm string DefaultOption: returns Keep', ...
                strcmp(sel, 'Keep'));
        else
            check('uiconfirm string DefaultOption: skip in non-headless mode', true);
        end
    catch ME
        check('uiconfirm string DefaultOption: must not throw', false);
        fprintf('    error: %s\n', ME.message);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 5 — uiconfirm: honours numeric DefaultOption
    % ════════════════════════════════════════════════════════════════════
    fprintf('\nTEST 5: uiconfirm — headless numeric DefaultOption\n');
    try
        if headless
            sel = uiconfirm([], 'Save?', 'Save', ...
                'Options',       {'Save', 'Discard', 'Cancel'}, ...
                'DefaultOption', 2);
            check('uiconfirm numeric DefaultOption: returns Discard (index 2)', ...
                strcmp(sel, 'Discard'));
        else
            check('uiconfirm numeric DefaultOption: skip in non-headless mode', true);
        end
    catch ME
        check('uiconfirm numeric DefaultOption: must not throw', false);
        fprintf('    error: %s\n', ME.message);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 6 — Path-restore cycle: shadow is still reachable after rmpath+addpath
    % ════════════════════════════════════════════════════════════════════
    fprintf('\nTEST 6: path-restore — shadow still reachable after rmpath+addpath\n');
    try
        % The shadow delegate path does: rmpath(shadowDir) → call real fn →
        % addpath(shadowDir, '-begin').  Verify that after this cycle the
        % shadow is still on the path (so subsequent calls still intercept).
        rmpath(shadowDir);
        addpath(shadowDir, '-begin');
        check('path-restore: shadowDir is still on path after rmpath+addpath', ...
            contains(path, shadowDir));
    catch ME
        check('path-restore: must not throw', false);
        fprintf('    error: %s\n', ME.message);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 7 — Real MATLAB uialert / uiconfirm are still reachable
    % ════════════════════════════════════════════════════════════════════
    fprintf('\nTEST 7: real uialert and uiconfirm are on path (non-shadow)\n');
    try
        % Temporarily remove the shadow, then check what which() resolves to.
        % The resolved path must NOT be inside our shadow directory — it
        % should point to a MATLAB toolbox file.
        rmpath(shadowDir);
        alertPath  = which('uialert');
        confirmPath = which('uiconfirm');
        addpath(shadowDir, '-begin');  % restore before checking

        check('Real uialert.m is reachable (non-shadow path found)', ...
            ~isempty(alertPath) && ~contains(alertPath, shadowDir));
        check('Real uiconfirm.m is reachable (non-shadow path found)', ...
            ~isempty(confirmPath) && ~contains(confirmPath, shadowDir));
    catch ME
        % Restore shadow path on error before crash-recording
        if ~contains(path, shadowDir), addpath(shadowDir, '-begin'); end
        recordCrash('TEST 7', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 8 — uiconfirm fallback: no Options → returns 'OK'
    % ════════════════════════════════════════════════════════════════════
    fprintf('\nTEST 8: uiconfirm — headless no-Options fallback\n');
    try
        if headless
            sel = uiconfirm([], 'Proceed?', 'Proceed');
            check('uiconfirm no-Options headless: returns OK', ...
                strcmp(sel, 'OK'));
        else
            check('uiconfirm no-Options: skip in non-headless mode', true);
        end
    catch ME
        check('uiconfirm no-Options: must not throw', false);
        fprintf('    error: %s\n', ME.message);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', sep);
    fprintf('  test_uialert_shadow: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_uialert_shadow:failed', '%d test(s) failed', failed);
    end
    fprintf('%s\n\n', sep);

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
end
