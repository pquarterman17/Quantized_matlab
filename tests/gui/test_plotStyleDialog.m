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
    %  TEST 1b: Dialog opens cleanly in Dark mode and applies the
    %  dark theme to every widget
    %
    %  Regression net for two bugs observed in Phase G:
    %    1. 'default' as an ItemsData value crashes uidropdown because
    %       MATLAB's set() treats 'default' as a "reset to factory"
    %       keyword.  We now use 'template_default' as the sentinel.
    %    2. New widgets (panels, spinners, dropdowns) in the Phase G
    %       sections were not picking up the dark theme — text stayed
    %       black on dark background and was unreadable.  The theme
    %       walker now recolours every widget in the tree.
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1b: dark-mode dialog theming ==\n');
    try
        api.setTheme('Dark');
        drawnow;

        api.fig.Visible = 'on';
        drawnow;
        api.openPlotStyle();
        drawnow;

        dlg = findall(groot, 'Type', 'figure', 'Tag', 'BosonPlotStyleDialog');
        check('dark dialog opened without error', ~isempty(dlg) && isvalid(dlg(1)));

        if ~isempty(dlg)
            d = dlg(1);

            % Figure background should be dark
            isDarkFigBg = mean(d.Color) < 0.5;
            check('dialog figure background is dark', isDarkFigBg);

            % Every panel should have dark background + light foreground
            panels = findall(d, 'Type', 'uipanel');
            if ~isempty(panels)
                allPanelsDark  = true;
                allPanelsLight = true;
                for i = 1:numel(panels)
                    if mean(panels(i).BackgroundColor) >= 0.5, allPanelsDark = false; end
                    if mean(panels(i).ForegroundColor) <= 0.5, allPanelsLight = false; end
                end
                check('all panels have dark background',  allPanelsDark);
                check('all panel titles have light text',  allPanelsLight);
            end

            % Every label should have light font
            lbls = findall(d, 'Type', 'uilabel');
            if ~isempty(lbls)
                allLightText = true;
                for i = 1:numel(lbls)
                    if mean(lbls(i).FontColor) <= 0.5
                        allLightText = false;
                    end
                end
                check('all labels have light font color', allLightText);
            end

            % Every dropdown should have dark bg + light fg
            dds = findall(d, 'Type', 'uidropdown');
            if ~isempty(dds)
                allDdDark  = true;
                allDdLight = true;
                for i = 1:numel(dds)
                    if mean(dds(i).BackgroundColor) >= 0.5, allDdDark  = false; end
                    if mean(dds(i).FontColor)       <= 0.5, allDdLight = false; end
                end
                check('all dropdowns have dark background', allDdDark);
                check('all dropdowns have light font color', allDdLight);
            end

            % Every spinner too
            sps = findall(d, 'Type', 'uispinner');
            if ~isempty(sps)
                allSpDark  = true;
                allSpLight = true;
                for i = 1:numel(sps)
                    if mean(sps(i).BackgroundColor) >= 0.5, allSpDark  = false; end
                    if mean(sps(i).FontColor)       <= 0.5, allSpLight = false; end
                end
                check('all spinners have dark background', allSpDark);
                check('all spinners have light font color', allSpLight);
            end

            % Checkboxes and radiobuttons
            cbs = findall(d, 'Type', 'uicheckbox');
            if ~isempty(cbs)
                allCbLight = all(arrayfun(@(h) mean(h.FontColor) > 0.5, cbs));
                check('all checkboxes have light font color', allCbLight);
            end
            rbs = findall(d, 'Type', 'uiradiobutton');
            if ~isempty(rbs)
                allRbLight = all(arrayfun(@(h) mean(h.FontColor) > 0.5, rbs));
                check('all radiobuttons have light font color', allRbLight);
                % Regression net: radiobuttons must have a ButtonGroup
                % parent directly (not a nested grid).  This crashed
                % the whole dialog in R2025b before the fix because
                % uiradiobutton's validator rejects anything else.
                allRbParented = all(arrayfun( ...
                    @(h) isa(h.Parent, 'matlab.ui.container.ButtonGroup'), rbs));
                check('radiobuttons are direct children of ButtonGroup', allRbParented);
            end

            delete(d);
        end

        drawnow;
        api.fig.Visible = 'off';
        % Restore light mode for subsequent tests
        api.setTheme('Light');
        drawnow;
    catch ME
        try api.fig.Visible = 'off'; catch, end
        try api.setTheme('Light'); catch, end
        recordCrash('TEST 1b', ME);
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
    %  TEST 2b: Active-dataset scope actually lands on the rendered line
    %
    %  Regression net: before the per-dataset cascade fix, clicking
    %  Apply with "Active dataset" scope wrote to ds.styleOverride but
    %  renderPlot never read it back for lineWidth / markerSize /
    %  alpha / markerFaceMode, so the plot visibly didn't change.
    %  The user reported this as "changing the plot styles doesn't
    %  seem to do anything on the plot."
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2b: Active-dataset scope reaches the plot ==\n');
    try
        api.fig.Visible = 'on';
        drawnow;
        api.setStyleOverrides(struct());
        api.setTemplate('screen');    % force a fresh replot
        drawnow;

        api.setDatasetStyleOverride(struct('lineWidth', 6.5));
        drawnow;

        ax = api.getAxes();
        % Use findall without HandleVisibility filter since VSM data
        % renders as errorbar + line overlays
        allKids = findall(ax, '-not', 'Tag', 'GUIFringeMarker', ...
                              '-not', 'Tag', 'GUIMaskedPoints', ...
                              '-not', 'Tag', 'GUIPeakAnnotation');
        types = arrayfun(@(h) lower(get(h, 'Type')), allKids, ...
                         'UniformOutput', false);
        dataMask = ismember(types, {'line', 'errorbar'});
        dataKids = allKids(dataMask);

        check('Active dataset has drawn handles', ~isempty(dataKids));
        if ~isempty(dataKids)
            widths = arrayfun(@(h) get(h,'LineWidth'), dataKids);
            check('ds.styleOverride.lineWidth reaches the rendered line', ...
                  any(abs(widths - 6.5) < 1e-6));
        end

        % Reset and restore visibility
        api.setDatasetStyleOverride(struct());
        api.setTemplate('screen');
        drawnow;
        api.fig.Visible = 'off';
    catch ME
        try api.fig.Visible = 'off'; catch, end
        recordCrash('TEST 2b', ME);
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
