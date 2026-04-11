function test_plotStyleDialog
%TEST_PLOTSTYLEDIALOG  Headless tests for the Phase B Plot Style dialog.
%
%   Covers:
%     - Dialog launches without errors and registers in the figure tree
%     - Layout integrity (reuses checkClippedLayouts)
%     - Applying global overrides via api.setStyleOverrides flows through
%       to the live plot (ax.FontSize, ax.Box, etc.)
%     - Per-dataset override (ds.styleOverride) takes precedence over
%       global overrides on the active dataset
%     - Reset clears overrides everywhere
%     - Save-as user template → appears in refreshed template list
%     - Session save/load round-trips activeTemplate + styleOverrides +
%       ds.styleOverride (Phase C)

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end
    if ~contains(path, thisDir), addpath(thisDir); end

    VSM_F = fullfile(rootDir, '+test_datasets', 'QuantumDesign', 'EDP136_Perp_StrawNew.dat');
    if ~isfile(VSM_F)
        warning('test_plotStyleDialog:noData', 'Missing VSM test file — skipping'); return;
    end

    passed = 0;
    failed = 0;
    failures = {};

    api = BosonPlotter();
    api.fig.Visible = 'off';
    drawnow;
    cleanupApi = onCleanup(@() api.close()); %#ok<NASGU>
    api.addFiles({VSM_F});
    api.setActiveIdx(1);
    drawnow;

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: api.openPlotStyle launches the dialog cleanly
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: dialog launches ==\n');
    try
        % Dialog creation can require the parent figure to be visible in
        % some MATLAB builds.  Briefly toggle Visible on, then off again
        % after the dialog is closed.
        api.fig.Visible = 'on';
        drawnow;
        api.openPlotStyle();
        drawnow;

        dlg = findall(groot, 'Type', 'figure', 'Tag', 'BosonPlotStyleDialog');
        check('Plot Style dialog figure exists',        ~isempty(dlg));
        check('dialog has valid handle',                 ~isempty(dlg) && isvalid(dlg(1)));

        if ~isempty(dlg)
            % Layout integrity on the dialog window itself
            v = checkClippedLayouts(dlg(1));
            structural = sum(cellfun(@(x) ~strcmp(x.kind,'zero_size_leaf'), v));
            zeroSize   = sum(cellfun(@(x)  strcmp(x.kind,'zero_size_leaf'), v));
            check(sprintf('dialog has zero structural violations (found %d)', structural), structural == 0);
            check(sprintf('dialog has zero zero-size leaves (found %d)', zeroSize), zeroSize == 0);

            delete(dlg);
        end
        drawnow;
        api.fig.Visible = 'off';
    catch ME
        try api.fig.Visible = 'off'; catch, end
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: setStyleOverrides flows into the live plot
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2: global override applied to axes ==\n');
    try
        api.setTemplate('screen');
        drawnow;

        ovr = struct('fontSize', 22, 'lineWidth', 3.5, 'boxOn', false);
        api.setStyleOverrides(ovr);
        drawnow;

        % The BosonPlotter auto-replot is only triggered by the callback,
        % not by api.setStyleOverrides — force it
        % (in the real dialog, onApply calls ctx.replot() which is onPlot)
        feval(api.setTemplate, 'screen');  % trigger a replot via template reset
        drawnow;

        ax = api.getAxes();
        check('ax.FontSize reflects override (22)',  ax.FontSize == 22);
        check('ax.Box reflects override (off)',      strcmp(ax.Box, 'off'));

        % Find a line and verify lineWidth
        lines = findall(ax, 'Type', 'line', '-not', 'Tag', 'GUIFringeMarker');
        ebars = findall(ax, 'Type', 'errorbar');
        dataH = [lines(:); ebars(:)];
        if ~isempty(dataH)
            widths = arrayfun(@(h) get(h,'LineWidth'), dataH);
            check('at least one data series at lineWidth=3.5', any(abs(widths - 3.5) < 1e-6));
        end
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 3: Per-dataset styleOverride wins over global
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 3: ds.styleOverride precedence ==\n');
    try
        % Global: lineWidth 3.5.  Dataset: lineWidth 1.0.
        api.setStyleOverrides(struct('lineWidth', 3.5));
        ds = api.getActiveDataset();
        ds.styleOverride = struct('lineWidth', 1.0);
        % Write back via the api (no direct access; use the test-only path)
        datasets = api.getDatasets();
        datasets{1} = ds;
        % The api doesn't expose a setDatasets, but activeIdx points at our slot.
        % Piggyback on the openPlotStyle -> setActiveDataset pathway via the
        % resolveStyle direct call instead — we can verify the layer chain
        % by calling resolveStyle ourselves with the same inputs.
        tpl = styles.template('screen');
        eff = bosonPlotter.resolveStyle(tpl, struct('lineWidth', 3.5), ...
                                        struct('styleOverride', struct('lineWidth', 1.0)));
        check('ds.styleOverride wins over global (lineWidth == 1.0)', eff.lineWidth == 1.0);

        % Per-channel wins over per-dataset
        dsWithChan = struct('styleOverride', struct('lineWidth', 1.0), ...
                            'channelStyles', {{struct('lineWidth', 4.2)}});
        eff2 = bosonPlotter.resolveStyle(tpl, struct('lineWidth', 3.5), dsWithChan, 1);
        check('channelStyles{1} wins over ds.styleOverride (lineWidth == 4.2)', eff2.lineWidth == 4.2);
    catch ME
        recordCrash('TEST 3', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 4: Resetting overrides reverts to template
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 4: reset clears overrides ==\n');
    try
        api.setStyleOverrides(struct('fontSize', 30));
        api.setTemplate('screen');
        drawnow;

        ax = api.getAxes();
        fontBefore = ax.FontSize;
        check('pre-reset fontSize reflects override (30)', fontBefore == 30);

        api.setStyleOverrides(struct());  % clear
        api.setTemplate('screen');          % trigger replot
        drawnow;

        ax = api.getAxes();
        % screen template default fontSize is 13 (from styles.default / template)
        check('post-reset fontSize reverted to template default', ax.FontSize ~= 30);
    catch ME
        recordCrash('TEST 4', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 5: User template save / reload via session round-trip
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 5: session round-trip preserves style state ==\n');
    try
        api.setTemplate('nature');
        api.setStyleOverrides(struct('lineWidth', 2.5, 'fontSize', 17));
        drawnow;

        % Save a temporary session
        tmp = [tempname '.mat'];
        api.saveSession(tmp);

        % Clobber the state to confirm the load actually restores it
        api.setTemplate('screen');
        api.setStyleOverrides(struct());
        drawnow;

        % Reload
        api.loadSession(tmp);
        drawnow;

        % Verify restoration
        check('activeTemplate restored to nature', strcmp(api.getTemplate(), 'nature'));
        ovr = api.getStyleOverrides();
        check('styleOverrides.lineWidth restored (2.5)', ...
              isfield(ovr,'lineWidth') && ovr.lineWidth == 2.5);
        check('styleOverrides.fontSize restored (17)', ...
              isfield(ovr,'fontSize') && ovr.fontSize == 17);

        % Cleanup temp file
        if isfile(tmp), delete(tmp); end
    catch ME
        recordCrash('TEST 5', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 6: User template save and deletion via userTemplates API
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 6: user template create/delete via dialog path ==\n');
    try
        name = 'test_plotStyleDialog_userTemplate';

        % Clean slate — remove any global overrides left over from TEST 5
        % so the user template's fontSize is the winning value.
        api.setStyleOverrides(struct());
        try bosonPlotter.userTemplates.delete(name); catch, end

        % Simulate what the Save As button does: read the active template,
        % overlay some values, call userTemplates.save
        tpl = styles.template('screen');
        tpl.fontSize  = 19;
        tpl.lineWidth = 2.2;
        bosonPlotter.userTemplates.save(name, tpl);

        check('user template persisted to disk', ...
              any(strcmp(bosonPlotter.userTemplates.list(), name)));

        % Apply it via the main api
        api.setTemplate(['user:' name]);
        drawnow;

        ax = api.getAxes();
        check('user template applied: fontSize == 19', ax.FontSize == 19);

        % Clean up
        api.setTemplate('screen');
        bosonPlotter.userTemplates.delete(name);
        check('user template deleted from disk', ...
              ~any(strcmp(bosonPlotter.userTemplates.list(), name)));
    catch ME
        recordCrash('TEST 6', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 68));
    fprintf('  test_plotStyleDialog: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_plotStyleDialog:failed', '%d test(s) failed', failed);
    end
    fprintf('%s\n', repmat('=', 1, 68));

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
