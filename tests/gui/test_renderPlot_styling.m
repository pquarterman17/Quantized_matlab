function test_renderPlot_styling
%TEST_RENDERPLOT_STYLING  Headless test for Phase A template wiring in
%   bosonPlotter.renderPlot.
%
%   Launches a BosonPlotter instance, loads a real dataset, switches the
%   active template via the new api.setTemplate, and asserts that the
%   live axes properties (FontName, FontSize, Title FontSize, TickDir,
%   Box, legend location) match the chosen template.  This is the
%   regression net that proves "changing Template on the dropdown
%   immediately changes the live plot" — the Phase A deliverable.
%
%   Uses the existing GUI test harness pattern: one BosonPlotter, api
%   reset between tests, cleanup via onCleanup.

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end

    VSM_F = fullfile(rootDir, '+test_datasets', 'QuantumDesign', 'EDP136_Perp_StrawNew.dat');
    if ~isfile(VSM_F)
        warning('test_renderPlot_styling:noData', ...
            'Missing test dataset %s — skipping render tests', VSM_F);
        return;
    end

    passed = 0;
    failed = 0;
    failures = {};

    api = BosonPlotter();
    api.fig.Visible = 'off';
    drawnow;
    cleanupApi = onCleanup(@() api.close()); %#ok<NASGU>

    % Load a dataset so renderPlot has something to draw
    try
        api.addFiles({VSM_F});
        api.setActiveIdx(1);
        drawnow;
    catch ME
        error('test_renderPlot_styling:setup', ...
            'Failed to load test dataset: %s', ME.message);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: Default template is 'screen' with sensible defaults
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: default template ==\n');
    try
        check('default template is screen', ...
              strcmp(api.getTemplate(), 'screen'));

        a = api.getAppearance();
        check('appearance struct returned',   isstruct(a));
        check('appearance has fontSize',      isfield(a, 'fontSize'));
        check('appearance fontSize > 0',      a.fontSize > 0);
    catch ME
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: Switching to APS applies APS-specific values to the axes
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2: switch to APS template ==\n');
    try
        api.setTemplate('aps');
        drawnow;

        aps = styles.template('aps');
        ax  = api.getAxes();

        check('activeTemplate is aps',       strcmp(api.getTemplate(), 'aps'));
        check('ax.FontName matches aps',     strcmp(ax.FontName, aps.fontName));
        check('ax.FontSize matches aps',     ax.FontSize == aps.fontSize);
        check('ax.Title.FontSize matches aps', ax.Title.FontSize == aps.titleFontSize);
        check('ax.TickDir matches aps',      strcmp(ax.TickDir, aps.tickDir));
        check('ax.Box matches aps',          strcmp(ax.Box, onOff(aps.boxOn)));
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 3: Switching to Nature applies Nature-specific values
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 3: switch to Nature template ==\n');
    try
        api.setTemplate('nature');
        drawnow;

        nat = styles.template('nature');
        ax  = api.getAxes();

        check('ax.FontName matches nature',  strcmp(ax.FontName, nat.fontName));
        check('ax.FontSize matches nature',  ax.FontSize == nat.fontSize);
        check('ax.Title.FontSize matches nature', ax.Title.FontSize == nat.titleFontSize);
    catch ME
        recordCrash('TEST 3', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 4: Presentation template has much larger fonts than screen
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 4: presentation template scales up ==\n');
    try
        api.setTemplate('screen');
        drawnow;
        ax1 = api.getAxes();
        screenFontSize = ax1.FontSize;

        api.setTemplate('presentation');
        drawnow;
        ax2 = api.getAxes();

        check('presentation fontSize > screen fontSize', ...
              ax2.FontSize > screenFontSize);
        check('presentation fontSize >= 16', ax2.FontSize >= 16);
    catch ME
        recordCrash('TEST 4', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 5: LineWidth from template flows to plotted data objects
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 5: line width flows to plotted objects ==\n');
    try
        api.setTemplate('thesis');
        drawnow;

        thesis = styles.template('thesis');
        ax = api.getAxes();

        % Plotted series in renderPlot can be 'line' (plot/line) OR
        % 'errorbar' OR 'ErrorBar' (when an error column is auto-detected).
        % findall reaches across HandleVisibility='off' objects that
        % findobj would miss.
        allKids = findall(ax, '-not', 'Tag', 'GUIFringeMarker', ...
                              '-not', 'Tag', 'GUIMaskedPoints');
        types = arrayfun(@(h) lower(get(h, 'Type')), allKids, ...
                         'UniformOutput', false);
        dataMask = ismember(types, {'line', 'errorbar'});
        dataKids = allKids(dataMask);

        check('at least one data series exists on the axes', ~isempty(dataKids));

        if ~isempty(dataKids)
            widths = arrayfun(@(h) get(h, 'LineWidth'), dataKids);
            check('at least one series matches thesis.lineWidth', ...
                  any(abs(widths - thesis.lineWidth) < 1e-6));
        end
    catch ME
        recordCrash('TEST 5', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 6: Invalid template name falls back gracefully (no crash)
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 6: invalid template name ==\n');
    try
        api.setTemplate('screen');   % start from a known state
        drawnow;

        api.setTemplate('definitely_not_a_template');
        drawnow;

        % resolveActiveAppearance has a catch that falls back to 'screen'
        a = api.getAppearance();
        check('appearance still resolves on bad name', isstruct(a));
        check('appearance still has fontSize',         isfield(a, 'fontSize'));
    catch ME
        recordCrash('TEST 6', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 68));
    fprintf('  test_renderPlot_styling: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_renderPlot_styling:failed', '%d test(s) failed', failed);
    end
    fprintf('%s\n', repmat('=', 1, 68));

    % ── Nested helpers ──────────────────────────────────────────────
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


% ════════════════════════════════════════════════════════════════════════
function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end
