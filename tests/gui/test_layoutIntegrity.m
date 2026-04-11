function test_layoutIntegrity
%TEST_LAYOUTINTEGRITY  Verify no clipped / undersized widgets in BosonPlotter.
%
%   Uses tests/gui/checkClippedLayouts.m to walk the BosonPlotter widget
%   tree and flag any nested uigridlayout whose fixed row/column spec
%   doesn't fit inside the slot its parent allocates.  This catches the
%   whole bug class where Controls panel row N only gets 22 px but the
%   child grid needs 44.  (Phase A shipped with exactly this bug; the
%   Template dropdown was there but clipped out of sight.)
%
%   Tests in this file:
%     1. Main BosonPlotter figure: zero structural violations + zero
%        runtime zero-size leaves (ignoring legitimately hidden widgets)
%     2. Synthetic broken grid: the detector actually catches a known-
%        bad layout (proves the detector works, not just that the GUI
%        happens to be clean right now)
%     3. Synthetic zero-size leaf: detector flags a leaf with 0 height
%
%   Run standalone:  run tests/gui/test_layoutIntegrity
%   Run via group :  runAllTests(Group="gui")

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end
    if ~contains(path, thisDir), addpath(thisDir); end

    passed = 0;
    failed = 0;
    failures = {};

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: The live BosonPlotter GUI has no clipped layouts
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: BosonPlotter layout integrity ==\n');
    try
        api = BosonPlotter();
        api.fig.Visible = 'off';
        drawnow;
        cleanupApi = onCleanup(@() api.close()); %#ok<NASGU>

        violations = checkClippedLayouts(api.fig);

        if ~isempty(violations)
            fprintf('\n  !! %d layout violation(s) found:\n', numel(violations));
            for vi = 1:numel(violations)
                v = violations{vi};
                fprintf('     [%s] %s\n', v.kind, v.location);
                fprintf('       %s\n', v.reason);
            end
        end

        check('BosonPlotter has zero structural violations', ...
              sum(cellfun(@(v) ~strcmp(v.kind,'zero_size_leaf'), violations)) == 0);

        % Runtime zero-size leaves: many widgets are Visible='off' on
        % initial launch (Y2 controls, conditional panels, etc.) which
        % getPositionSafe already ignores.  But we still expect zero
        % tripped assertions here for any VISIBLE leaf.
        zeroSizeCount = sum(cellfun(@(v) strcmp(v.kind,'zero_size_leaf'), violations));
        check(sprintf('BosonPlotter has zero zero-size visible leaves (found %d)', zeroSizeCount), ...
              zeroSizeCount == 0);
    catch ME
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: Detector catches a synthetic broken layout
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2: synthetic broken layout (nested grid too tall) ==\n');
    try
        badFig = uifigure('Visible','off','Position',[100 100 300 200]);
        cleanup2 = onCleanup(@() delete(badFig)); %#ok<NASGU>

        % Outer grid: row 1 is only 22 px tall
        outerGrid = uigridlayout(badFig, [1 1], ...
            'RowHeight', {22}, 'ColumnWidth', {'1x'}, ...
            'Padding', [0 0 0 0]);

        % Inner grid stuffed into that 22-px slot: needs 2×18 + spacing = 38 px
        innerGrid = uigridlayout(outerGrid, [2 1], ...
            'RowHeight', {18, 18}, 'ColumnWidth', {'1x'}, ...
            'Padding', [0 0 0 0], 'RowSpacing', 2); %#ok<NASGU>
        innerGrid.Layout.Row = 1;
        innerGrid.Layout.Column = 1;

        drawnow;
        v = checkClippedLayouts(badFig);

        % Filter to the structural violation type
        structural = v(cellfun(@(x) strcmp(x.kind, 'nested_grid_too_tall'), v));
        check('detector caught the too-tall nested grid', ~isempty(structural));

        if ~isempty(structural)
            s = structural{1};
            check('violation reports the correct allocated size (22)', s.allocated == 22);
            check('violation reports required size >= 38', s.required >= 38);
            check('violation .reason mentions parent RowHeight', ...
                  contains(s.reason, 'RowHeight'));
        end
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 3: Detector catches a synthetic too-wide nested grid
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 3: synthetic broken layout (nested grid too wide) ==\n');
    try
        badFig = uifigure('Visible','off','Position',[100 100 300 200]);
        cleanup3 = onCleanup(@() delete(badFig)); %#ok<NASGU>

        outerGrid = uigridlayout(badFig, [1 1], ...
            'ColumnWidth', {50}, 'RowHeight', {'1x'}, ...
            'Padding', [0 0 0 0]);

        innerGrid = uigridlayout(outerGrid, [1 3], ...
            'ColumnWidth', {40, 40, 40}, 'RowHeight', {'1x'}, ...
            'Padding', [0 0 0 0], 'ColumnSpacing', 5); %#ok<NASGU>
        innerGrid.Layout.Row = 1;
        innerGrid.Layout.Column = 1;

        drawnow;
        v = checkClippedLayouts(badFig);

        widthViol = v(cellfun(@(x) strcmp(x.kind, 'nested_grid_too_wide'), v));
        check('detector caught the too-wide nested grid', ~isempty(widthViol));

        if ~isempty(widthViol)
            s = widthViol{1};
            check('violation reports the correct allocated width (50)', s.allocated == 50);
            check('violation reports required width >= 130', s.required >= 130);
        end
    catch ME
        recordCrash('TEST 3', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 4: Flex rows ('1x') are NOT flagged (can't statically resolve)
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 4: flex rows are ignored (no false positives) ==\n');
    try
        flexFig = uifigure('Visible','off','Position',[100 100 300 200]);
        cleanup4 = onCleanup(@() delete(flexFig)); %#ok<NASGU>

        outerGrid = uigridlayout(flexFig, [1 1], ...
            'RowHeight', {'1x'}, 'ColumnWidth', {'1x'}, ...
            'Padding', [0 0 0 0]);

        innerGrid = uigridlayout(outerGrid, [5 1], ...
            'RowHeight', {100, 100, 100, 100, 100}, ...
            'ColumnWidth', {'1x'}, 'Padding', [0 0 0 0]); %#ok<NASGU>
        innerGrid.Layout.Row = 1;
        innerGrid.Layout.Column = 1;

        drawnow;
        v = checkClippedLayouts(flexFig);
        nStruct = sum(cellfun(@(x) contains(x.kind, 'nested_grid'), v));
        check('flex parent row produces zero structural violations', nStruct == 0);
    catch ME
        recordCrash('TEST 4', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 5: Detector regression — ensure the old Phase A bug would fail
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 5: Phase A regression simulation ==\n');
    try
        % Reproduce the exact structure that bit Phase A:
        %   ctrlGL row 4 = 22 px (fixed), containing styleGL (2×4 grid
        %   with RowHeight {18,18}).  The Template row was clipped.
        badFig = uifigure('Visible','off','Position',[100 100 400 300]);
        cleanup5 = onCleanup(@() delete(badFig)); %#ok<NASGU>

        ctrlGL = uigridlayout(badFig, [8 1], ...
            'RowHeight', {24,'2x','1x',22,66,22,22,20}, ...  % the buggy spec
            'Padding', [4 4 4 4], 'RowSpacing', 2);

        styleGL = uigridlayout(ctrlGL, [2 4], ...
            'RowHeight', {18, 18}, 'ColumnWidth', {'1x','1x','1x','1x'}, ...
            'Padding', [0 0 0 0], 'RowSpacing', 2); %#ok<NASGU>
        styleGL.Layout.Row = 4;

        drawnow;
        v = checkClippedLayouts(badFig);
        nTall = sum(cellfun(@(x) strcmp(x.kind,'nested_grid_too_tall'), v));
        check('Phase A bug structure is caught by detector', nTall >= 1);

        % And the fixed version (row height 44) should pass
        goodFig = uifigure('Visible','off','Position',[100 100 400 300]);
        cleanup5b = onCleanup(@() delete(goodFig)); %#ok<NASGU>

        ctrlGL2 = uigridlayout(goodFig, [8 1], ...
            'RowHeight', {24,'2x','1x',44,66,22,22,20}, ...  % the fix
            'Padding', [4 4 4 4], 'RowSpacing', 2);

        styleGL2 = uigridlayout(ctrlGL2, [2 4], ...
            'RowHeight', {18, 18}, 'ColumnWidth', {'1x','1x','1x','1x'}, ...
            'Padding', [0 0 0 0], 'RowSpacing', 2); %#ok<NASGU>
        styleGL2.Layout.Row = 4;

        drawnow;
        v2 = checkClippedLayouts(goodFig);
        nTall2 = sum(cellfun(@(x) strcmp(x.kind,'nested_grid_too_tall'), v2));
        check('Phase A fix (row height 44) passes detector', nTall2 == 0);
    catch ME
        recordCrash('TEST 5', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 68));
    fprintf('  test_layoutIntegrity: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_layoutIntegrity:failed', '%d test(s) failed', failed);
    end
    fprintf('%s\n', repmat('=', 1, 68));

    % ── Nested helpers ─────────────────────────────────────────────
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
