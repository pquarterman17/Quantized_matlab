function test_2dMapStyling
%TEST_2DMAPSTYLING  Verify template changes propagate to 2D heatmap axes (Phase F).
%
%   Loads a 2D XRDML file, switches the active template, and asserts
%   that the axes FontName / FontSize / TickDir / Box reflect the new
%   template.  This is the equivalent of test_renderPlot_styling but
%   for the imagesc / contourf rendering path inside draw2DMap.

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end

    XRDML_2D = fullfile(rootDir, '+test_datasets', 'XRDML', 'FAIRmat_rsm_mesh.xrdml');
    if ~isfile(XRDML_2D)
        warning('test_2dMapStyling:noData', 'Missing 2D XRDML test file — skipping');
        return;
    end

    passed = 0;
    failed = 0;
    failures = {};

    api = BosonPlotter('Visible','off');
    drawnow;
    cleanupApi = onCleanup(@() api.close()); %#ok<NASGU>

    try
        api.addFiles({XRDML_2D});
        api.setActiveIdx(1);
        drawnow;
    catch ME
        error('test_2dMapStyling:setup', 'Failed to load 2D XRDML file: %s', ME.message);
    end

    % Confirm this is actually a 2D map
    if ~api.is2DActive()
        warning('test_2dMapStyling:not2D', 'Loaded file is not 2D — skipping');
        return;
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: Template switch propagates to 2D map axes
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: 2D map picks up template FontName ==\n');
    try
        api.setTemplate('aps');
        drawnow;

        aps = styles.template('aps');
        ax = api.getAxes();

        check('ax.FontName matches aps',     strcmp(ax.FontName, aps.fontName));
        check('ax.FontSize matches aps',     ax.FontSize == aps.fontSize);
        check('ax.TickDir matches aps',      strcmp(ax.TickDir, aps.tickDir));
        check('ax.Box matches aps',          strcmp(ax.Box, onOff(aps.boxOn)));
    catch ME
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: Presentation template scales font up on 2D map
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2: presentation template on 2D map ==\n');
    try
        api.setTemplate('screen');
        drawnow;
        sz1 = api.getAxes().FontSize;

        api.setTemplate('presentation');
        drawnow;
        sz2 = api.getAxes().FontSize;

        check('presentation FontSize > screen FontSize on 2D map', sz2 > sz1);
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 3: Colorbar inherits template font / tick direction (Phase G)
    %
    %  Pre-fix bug: Phase F applied template font/tick to the 2D axes,
    %  but the colorbar (a second axes) was created with only
    %  Label.String set — its FontName, FontSize, TickDirection,
    %  TickLength, and Label.FontName stayed at MATLAB defaults, so an
    %  APS-styled 2D map showed Helvetica axes but a default-font
    %  colorbar.  applyAppearanceToColorbar closes this gap.
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 3: colorbar inherits APS template (Phase G) ==\n');
    try
        api.setTemplate('aps');
        drawnow;

        aps = styles.template('aps');
        ax = api.getAxes();
        cbh = [];
        try
            cbh = ax.Colorbar;
        catch
        end
        if isempty(cbh) || ~isvalid(cbh)
            % Alternative lookup: walk the parent figure's children
            fg = ancestor(ax, 'figure');
            cList = findall(fg, 'Type', 'ColorBar');
            if ~isempty(cList), cbh = cList(1); end
        end

        check('colorbar handle exists after 2D render', ~isempty(cbh) && isvalid(cbh));
        if ~isempty(cbh) && isvalid(cbh)
            check('colorbar FontName matches aps', strcmp(cbh.FontName, aps.fontName));
            check('colorbar FontSize matches aps', cbh.FontSize == aps.fontSize);
            % TickDirection on colorbars uses the same string as TickDir
            % on axes ('in' / 'out' / 'both')
            if isprop(cbh, 'TickDirection')
                check('colorbar TickDirection matches aps.tickDir', ...
                      strcmp(cbh.TickDirection, aps.tickDir));
            end
            check('colorbar Label FontName matches aps', ...
                  strcmp(cbh.Label.FontName, aps.fontName));
        end
    catch ME
        recordCrash('TEST 3', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 4: Switching to Nature re-skins the colorbar too
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 4: colorbar re-skins on template switch ==\n');
    try
        api.setTemplate('nature');
        drawnow;

        nat = styles.template('nature');
        ax = api.getAxes();
        cbh = [];
        try cbh = ax.Colorbar; catch, end
        if isempty(cbh) || ~isvalid(cbh)
            fg = ancestor(ax, 'figure');
            cList = findall(fg, 'Type', 'ColorBar');
            if ~isempty(cList), cbh = cList(1); end
        end

        if ~isempty(cbh) && isvalid(cbh)
            check('colorbar FontName follows nature', strcmp(cbh.FontName, nat.fontName));
            check('colorbar FontSize follows nature', cbh.FontSize == nat.fontSize);
        end
    catch ME
        recordCrash('TEST 4', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 68));
    fprintf('  test_2dMapStyling: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_2dMapStyling:failed', '%d test(s) failed', failed);
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

function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end
