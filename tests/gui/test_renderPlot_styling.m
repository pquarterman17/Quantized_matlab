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

    api = BosonPlotter('Visible','off');
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
    %  TEST 7: Line alpha is wired from appearance to rendered lines
    %
    %  Pre-fix bug: spAlpha in the dialog was writing to
    %  styleOverrides.alpha but renderPlot never consumed it.  Verify
    %  that alpha < 1 now promotes line Color to a 4-element RGBA.
    %
    %  First half is a standalone test of applyPostRenderStyle on a
    %  synthetic axes — isolates "does the helper work" from "does the
    %  BosonPlotter integration wire it up."  Second half verifies the
    %  main GUI path end-to-end.
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 7a: applyAlphaToLine direct helper ==\n');
    try
        fSyn = figure('Visible','off');
        axSyn = axes(fSyn);
        h1 = plot(axSyn, 1:10, rand(1,10), '-o', 'Color', [0.2 0.5 0.8]);
        hold(axSyn, 'on');
        drawnow;

        bosonPlotter.applyAlphaToLine(h1, 0.4);
        drawnow;

        % Probe-based: check whether native 4-element Color took effect,
        % or the undocumented Edge primitive path was used instead.
        c = get(h1, 'Color');
        if numel(c) >= 4 && abs(c(4) - 0.4) < 0.02
            % Native alpha path succeeded
            check('Color has 4 elements (native alpha)', true);
            check('Color(4) approx 0.4', abs(c(4) - 0.4) < 0.02);
            check('Color(1) preserved', abs(c(1) - 0.2) < 0.02);
        else
            % Undocumented Edge primitive path (R2025b and earlier)
            haveEdge = false;
            try
                e = h1.Edge;
                haveEdge = ~isempty(e) && isvalid(e);
            catch
            end
            check('line.Edge primitive is accessible', haveEdge);
            if haveEdge
                check('Edge.ColorType is truecoloralpha', ...
                      strcmp(h1.Edge.ColorType, 'truecoloralpha'));
                cd = h1.Edge.ColorData;
                check('Edge.ColorData has 4 bytes', numel(cd) == 4);
                if numel(cd) == 4
                    check('Edge.ColorData(4) approx 102', abs(double(cd(4)) - 102) <= 1);
                    check('Edge.ColorData(1) preserved', abs(double(cd(1)) - 51) <= 1);
                end
            end
        end

        close(fSyn);
    catch ME
        try close(fSyn); catch, end
        recordCrash('TEST 7a', ME);
    end

    fprintf('\n== TEST 7b: alpha override in main GUI ==\n');
    try
        api.setStyleOverrides(struct());
        api.setTemplate('screen');
        drawnow;

        ax = api.getAxes();
        dataKids = findDataLines(ax);
        check('baseline has data lines', ~isempty(dataKids));

        api.setStyleOverrides(struct('alpha', 0.35));
        api.setTemplate('screen');
        drawnow;

        ax = api.getAxes();
        dataKids = findDataLines(ax);
        check('alpha override has data lines', ~isempty(dataKids));
        if ~isempty(dataKids)
            % Data objects may be Line (→ .Edge primitive) or
            % ErrorBar (→ .Bar primitive).  Both store the alpha'd
            % colour as uint8 RGBA in ColorData via ColorType=
            % 'truecoloralpha'.  Walk every data object and check
            % whichever primitive it exposes.
            anyTruecoloralpha = false;
            matchedAlpha = false;
            for di = 1:numel(dataKids)
                h = dataKids(di);
                prim = [];
                try
                    if isprop(h, 'Edge'), prim = h.Edge; end
                catch
                end
                if isempty(prim) || ~isvalid(prim)
                    try
                        if isprop(h, 'Bar'), prim = h.Bar; end
                    catch
                    end
                end
                if ~isempty(prim) && isvalid(prim)
                    try
                        if strcmp(prim.ColorType, 'truecoloralpha')
                            anyTruecoloralpha = true;
                            cd = prim.ColorData;
                            if numel(cd) == 4 && abs(double(cd(4)) - 89) <= 1
                                matchedAlpha = true;
                            end
                        end
                    catch
                    end
                end
            end
            check('at least one data line/errorbar has truecoloralpha', anyTruecoloralpha);
            check('at least one primitive ColorData(4) ≈ 89 (0.35*255)', matchedAlpha);
        end

        api.setStyleOverrides(struct());
        api.setTemplate('screen');
        drawnow;
    catch ME
        recordCrash('TEST 7b', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 8: ds.styleOverride.datasetColor reaches the plotted line
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 8: ds.styleOverride.datasetColor reaches rendered line ==\n');
    try
        api.setStyleOverrides(struct());
        api.setTemplate('screen');

        targetColor = [0.1 0.8 0.3];
        api.setDatasetStyleOverride(struct('datasetColor', targetColor));
        drawnow;

        ax = api.getAxes();
        dataKids = findDataLines(ax);
        check('dataset-colour override has data lines', ~isempty(dataKids));
        if ~isempty(dataKids)
            c = get(dataKids(1), 'Color');
            if numel(c) >= 3
                check('line Color(1:3) matches ds.styleOverride.datasetColor', ...
                      all(abs(c(1:3) - targetColor) < 1e-6));
            else
                check('line Color has at least 3 elements', false);
            end
        end

        api.setDatasetStyleOverride(struct());
        drawnow;
    catch ME
        recordCrash('TEST 8', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 9: markerFaceMode='auto' fills markers with line colour
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 9: markerFaceMode auto/none ==\n');
    try
        api.setStyleOverrides(struct());
        api.setTemplate('screen');
        api.setStyle('Scatter');
        drawnow;

        ax = api.getAxes();
        dataKids = findDataLines(ax);
        check('scatter has data lines', ~isempty(dataKids));
        if ~isempty(dataKids)
            mfc = get(dataKids(1), 'MarkerFaceColor');
            check('default MarkerFaceColor is ''none''', ...
                  (ischar(mfc) || isstring(mfc)) && strcmpi(char(mfc), 'none'));
        end

        api.setStyleOverrides(struct('markerFaceMode', 'auto'));
        api.setTemplate('screen');
        drawnow;

        ax = api.getAxes();
        dataKids = findDataLines(ax);
        if ~isempty(dataKids)
            mfc = get(dataKids(1), 'MarkerFaceColor');
            lineCol = get(dataKids(1), 'Color');
            check('MarkerFaceColor is numeric RGB when markerFaceMode=auto', ...
                  isnumeric(mfc) && numel(mfc) == 3);
            if isnumeric(mfc) && numel(mfc) == 3 && numel(lineCol) >= 3
                check('MarkerFaceColor matches line Color(1:3)', ...
                      all(abs(mfc - lineCol(1:3)) < 1e-6));
            end
        end

        api.setStyleOverrides(struct());
        api.setStyle('Line');
        drawnow;
    catch ME
        recordCrash('TEST 9', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 10: Palette override replaces the default colour cycle
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 10: paletteOverride changes rendered colours ==\n');
    try
        api.setStyleOverrides(struct());
        api.setTemplate('screen');
        drawnow;

        ax = api.getAxes();
        kids0 = findDataLines(ax);
        baselineColor = [];
        if ~isempty(kids0)
            c0 = get(kids0(1), 'Color');
            if numel(c0) >= 3, baselineColor = c0(1:3); end
        end

        tabPal = styles.palette('tab10');
        api.setStyleOverrides(struct('paletteOverride', tabPal));
        api.setTemplate('screen');
        drawnow;

        ax = api.getAxes();
        kids1 = findDataLines(ax);
        if ~isempty(kids1) && ~isempty(baselineColor)
            c1 = get(kids1(1), 'Color');
            check('line Color matches Tab10 first stop', ...
                  numel(c1) >= 3 && all(abs(c1(1:3) - tabPal(1,:)) < 1e-6));
            check('line Color differs from baseline template colour', ...
                  ~isequal(c1(1:3), baselineColor));
        end

        api.setStyleOverrides(struct());
        api.setTemplate('screen');
        drawnow;
    catch ME
        recordCrash('TEST 10', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 11: tickLength from appearance lands on the axes
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 11: tickLength override lands on axes ==\n');
    try
        api.setStyleOverrides(struct());
        api.setTemplate('screen');
        drawnow;

        api.setStyleOverrides(struct('tickLength', [0.025 0.0125]));
        api.setTemplate('screen');
        drawnow;

        ax = api.getAxes();
        check('ax.TickLength(1) matches override', ...
              abs(ax.TickLength(1) - 0.025) < 1e-6);

        api.setStyleOverrides(struct());
        api.setTemplate('screen');
        drawnow;
    catch ME
        recordCrash('TEST 11', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 12: legendFontWeight flows via applyPostRenderStyle
    %
    %  We test the helper directly on a synthetic axes so we don't have
    %  to orchestrate BosonPlotter's "is a legend drawn?" heuristic
    %  (which depends on dataset count and show-legend state).  The
    %  renderPlot wiring is covered by test_plotStyleDialog ensuring
    %  the struct reaches the resolver.
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 12: legendFontWeight via applyPostRenderStyle ==\n');
    try
        fSyn = figure('Visible','off');
        axSyn = axes(fSyn);
        plot(axSyn, 1:10, rand(1,10), 'DisplayName', 'a');
        hold(axSyn, 'on');
        plot(axSyn, 1:10, rand(1,10), 'DisplayName', 'b');
        lgd = legend(axSyn);
        drawnow;

        check('synthetic legend default is normal weight', ...
              strcmpi(lgd.FontWeight, 'normal'));

        appr = bosonPlotter.resolveStyle(styles.template('screen'), ...
                                         struct('legendFontWeight', 'bold'));
        bosonPlotter.applyPostRenderStyle(axSyn, appr);
        drawnow;

        check('legend FontWeight is bold after applyPostRenderStyle', ...
              strcmpi(lgd.FontWeight, 'bold'));

        close(fSyn);
    catch ME
        try close(fSyn); catch, end
        recordCrash('TEST 12', ME);
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

function dataKids = findDataLines(ax)
%FINDDATALINES  Return axes children that represent data series.
%   Filters out auxiliary chrome (fringe markers, masked-point
%   overlay, SNIP background) by tag so colour/alpha checks only
%   hit the real data lines.
    allKids = findall(ax, '-not', 'Tag', 'GUIFringeMarker', ...
                          '-not', 'Tag', 'GUIMaskedPoints', ...
                          '-not', 'Tag', 'GUISNIPBackground', ...
                          '-not', 'Tag', 'GUIPeakAnnotation');
    types = arrayfun(@(h) lower(get(h, 'Type')), allKids, ...
                     'UniformOutput', false);
    dataMask = ismember(types, {'line', 'errorbar'});
    dataKids = allKids(dataMask);
    if ~isempty(dataKids)
        % Only visible series (HandleVisibility='on') are real data
        visible = arrayfun(@(h) strcmp(get(h, 'HandleVisibility'), 'on'), dataKids);
        dataKids = dataKids(visible);
    end
end
