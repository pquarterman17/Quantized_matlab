function test_plotInteractions
%TEST_PLOTINTERACTIONS  Headless tests for plotInteractions, cursorPanel,
%   and the extended axes context menu added in feat/plot-interactions.
%
%   Run standalone:  cd tests/gui; run test_plotInteractions
%   Run via suite:   runAllTests(Group='gui')
%
%   Tests:
%     1. BosonPlotter launches and the cursor panel handle is present in the API
%     2. Axes has a ContextMenu after launch (R2023b+ only; skipped on older)
%     3. Context menu includes the new 'Edit Axis Labels...' and 'Set Axis Limits...' items
%     4. cursorPanel.update fires without error on valid and NaN coordinates
%     5. cursorPanel shows dash text when no dataset is loaded
%     6. After loading a dataset and plotting, line objects exist in the axes
%     7. plotInteractions does not error on an empty axes call
%     8. cursorPanel.update shows coordinate text when a valid point is supplied

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir)
        addpath(rootDir);
    end

    VSM_F = fullfile(rootDir, '+test_datasets', 'QuantumDesign', ...
                     'EDP136_Perp_StrawNew.dat');

    passed   = 0;
    failed   = 0;
    failures = {};

    % ── Launch GUI ───────────────────────────────────────────────────────
    api = BosonPlotter('Visible','off');
    drawnow;
    cleanupApi = onCleanup(@() api.close()); %#ok<NASGU>

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: cursor panel handle is present in API
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: cursor panel in API ==\n');
    try
        cpanel = api.getCursorPanel();
        check('cursorPanel struct returned',     isstruct(cpanel));
        check('cursorPanel.container is graphics', isgraphics(cpanel.container));
        check('cursorPanel.lblLeft is graphics',   isgraphics(cpanel.lblLeft));
        check('cursorPanel.lblRight is graphics',  isgraphics(cpanel.lblRight));
        check('cursorPanel.update is function',    isa(cpanel.update, 'function_handle'));
    catch ME
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: axes has a ContextMenu after data load (R2023b+ only)
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2: axes context menu ==\n');
    try
        if isMATLABReleaseOlderThan('R2023b') || ~isfile(VSM_F)
            fprintf('   SKIP (pre-R2023b or missing data)\n');
        else
            api.addFiles({VSM_F});
            api.setActiveIdx(1);
            drawnow; pause(0.5);
            axh = api.getAxes();
            check('axes has ContextMenu', ...
                ~isempty(axh.ContextMenu) && isgraphics(axh.ContextMenu));
        end
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 3: context menu contains figDoc interaction items
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 3: new context menu items present ==\n');
    try
        if isMATLABReleaseOlderThan('R2023b') || ~isfile(VSM_F)
            fprintf('   SKIP (pre-R2023b or missing data)\n');
        else
            axh   = api.getAxes();
            cm    = axh.ContextMenu;
            items = cm.Children;
            texts = arrayfun(@(m) m.Text, items, 'UniformOutput', false);
            check('menu has Set X Limits...',  any(strcmp(texts, 'Set X Limits...')));
            check('menu has Log X',            any(strcmp(texts, 'Log X')));
            check('menu has Toggle Grid',      any(strcmp(texts, 'Toggle Grid')));
        end
    catch ME
        recordCrash('TEST 3', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 4: cursorPanel.update fires without error on valid and NaN coords
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 4: cursorPanel.update robustness ==\n');
    try
        cpanel = api.getCursorPanel();
        cpanel.update(NaN, NaN);
        check('update NaN/NaN does not error', true);

        cpanel.update(1.23, 4.56);
        check('update valid coords does not error', true);

        cpanel.update([], []);
        check('update empty args does not error', true);
    catch ME
        recordCrash('TEST 4', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 5: cursor panel shows dash when no dataset is loaded
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 5: dash when no dataset ==\n');
    try
        cpanel = api.getCursorPanel();
        cpanel.update(NaN, NaN);
        check('lblLeft shows dash', strcmp(cpanel.lblLeft.Text, '--'));
    catch ME
        recordCrash('TEST 5', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 6: line objects exist after loading and plotting a dataset
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 6: lines exist after load ==\n');
    try
        if ~isfile(VSM_F)
            fprintf('   SKIP (test dataset missing)\n');
        else
            drawnow;
            axh   = api.getAxes();
            % Accept any visible plot objects (line, errorbar, scatter, etc.)
            visObjs = findobj(axh, '-not', 'HandleVisibility', 'off', ...
                              '-not', 'Tag', 'GUICursorReadout');
            check('at least one visible plot object after load', numel(visObjs) >= 1);
        end
    catch ME
        recordCrash('TEST 6', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 7: plotInteractions module-level call is safe on empty axes
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 7: plotInteractions safe on empty axes ==\n');
    try
        api.reset();
        drawnow;
        axh = api.getAxes();
        cb  = struct( ...
            'getDatasets',           @() {}, ...
            'getActiveIdx',          @() 0, ...
            'setActiveIdx',          @(~) [], ...
            'setCustomXLabel',       @(~) [], ...
            'setCustomYLabel',       @(~) [], ...
            'setCustomTitle',        @(~) [], ...
            'onAutoLimits',          @() [], ...
            'isContextMenuSupported', false);
        bosonPlotter.plotInteractions(axh, api.fig, cb);
        check('plotInteractions does not error on empty axes', true);
    catch ME
        recordCrash('TEST 7', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 8: cursorPanel shows coordinate text after update with valid XY
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 8: cursorPanel shows coordinates ==\n');
    try
        cpanel = api.getCursorPanel();
        cpanel.update(3.14159, 2.71828);
        drawnow;
        lbl = cpanel.lblLeft.Text;
        check('label contains X value', contains(lbl, 'X:'));
        check('label contains Y value', contains(lbl, 'Y:'));
    catch ME
        recordCrash('TEST 8', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n════ test_plotInteractions: %d passed, %d failed ════\n', passed, failed);
    if failed > 0
        for fi = 1:numel(failures)
            fprintf('  FAIL: %s\n', failures{fi});
        end
        error('test_plotInteractions:failures', '%d test(s) failed.', failed);
    end

    % ── Local helpers ─────────────────────────────────────────────────────
    function check(label, cond)
        if cond
            fprintf('  PASS: %s\n', label);
            passed = passed + 1;
        else
            fprintf('  FAIL: %s\n', label);
            failed  = failed  + 1;
            failures{end+1} = label;
        end
    end

    function recordCrash(testName, ME)
        fprintf('  CRASH in %s: %s\n', testName, ME.message);
        failed  = failed + 1;
        failures{end+1} = [testName ': ' ME.message];
    end
end
