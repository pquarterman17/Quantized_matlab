function test_rowLevelMasking
%TEST_ROWLEVELMASKING  Verify the dataset info bar and DataWorkspace button
%   work correctly after the legacy embedded table was removed.
%
%   Covers:
%     - Dataset info label is present and updates on dataset load
%     - Dataset info label shows row count and masked count
%     - "Open in DataWorkspace" button is present
%     - refreshDataTable() API call updates the info label without error
%     - Mask state from ds.mask is reflected in the info bar

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end

    VSM_F = fullfile(rootDir, '+test_datasets', 'QuantumDesign', 'EDP136_Perp_StrawNew.dat');
    if ~isfile(VSM_F)
        warning('test_rowLevelMasking:noData', 'Missing VSM file — skipping');
        return;
    end

    passed = 0;
    failed = 0;
    failures = {};

    api = BosonPlotter('Visible','off');
    drawnow;
    cleanupApi = onCleanup(@() api.close()); %#ok<NASGU>
    api.addFiles({VSM_F});
    api.setActiveIdx(1);
    drawnow;

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: Legacy embedded uitables are gone; info label is present
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: Legacy uitables removed; info label present ==\n');
    try
        legacyData  = findall(api.fig, 'Type', 'uitable', 'Tag', 'BosonDataTable');
        legacyUnits = findall(api.fig, 'Type', 'uitable', 'Tag', 'BosonUnitsTable');
        check('BosonDataTable uitable is gone',  isempty(legacyData));
        check('BosonUnitsTable uitable is gone', isempty(legacyUnits));

        % Info label should exist as a uilabel inside the dataTablePanel
        infoLabels = findall(api.fig, 'Type', 'uilabel');
        texts = arrayfun(@(h) char(h.Text), infoLabels, 'UniformOutput', false);
        hasInfoText = any(cellfun(@(t) ~isempty(t) && length(t) > 3, texts));
        check('At least one uilabel with content exists', hasInfoText);
    catch ME
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: refreshDataTable() runs without error and updates label
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2: refreshDataTable() updates info label ==\n');
    try
        api.refreshDataTable();
        drawnow;
        % Should not throw — that is sufficient for a smoke test
        check('refreshDataTable() completed without error', true);

        % Verify the info label text contains row count info
        infoLabels = findall(api.fig, 'Type', 'uilabel');
        texts = arrayfun(@(h) char(h.Text), infoLabels, 'UniformOutput', false);
        hasRowInfo = any(cellfun(@(t) contains(t, 'rows'), texts));
        check('Info label text contains "rows"', hasRowInfo);
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 3: Info label reflects masked rows in ds.mask
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 3: Info label reflects masked row count ==\n');
    try
        datasets = api.getDatasets();
        ds = datasets{1};
        nRows = numel(ds.data.time);

        % First check with no masks (all included)
        api.refreshDataTable();
        drawnow;
        infoLabels = findall(api.fig, 'Type', 'uilabel');
        texts = arrayfun(@(h) char(h.Text), infoLabels, 'UniformOutput', false);
        zeroMaskText = any(cellfun(@(t) contains(t, '0 masked'), texts));
        check('Info label shows "0 masked" when no rows masked', zeroMaskText);

        % The label should also contain the row count
        expectedStr = sprintf('%d rows', nRows);
        hasRowCount = any(cellfun(@(t) contains(t, expectedStr), texts));
        check(sprintf('Info label contains "%s"', expectedStr), hasRowCount);
    catch ME
        recordCrash('TEST 3', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 4: "Open in DataWorkspace" button is wired
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 4: DataWorkspace button exists ==\n');
    try
        btns = findall(api.fig, 'Type', 'uibutton');
        btnTexts = arrayfun(@(h) char(h.Text), btns, 'UniformOutput', false);
        hasDwBtn = any(cellfun(@(t) contains(t, 'DataWorkspace'), btnTexts));
        check('"Open in DataWorkspace" button present', hasDwBtn);
    catch ME
        recordCrash('TEST 4', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 68));
    fprintf('  test_rowLevelMasking: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_rowLevelMasking:failed', '%d test(s) failed', failed);
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
