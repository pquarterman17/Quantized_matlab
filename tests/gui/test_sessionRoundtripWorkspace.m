function test_sessionRoundtripWorkspace
%TEST_SESSIONROUNDTRIPWORKSPACE  WorkspaceModel state survives session save/load.
%
%   MASTERPLAN W3 #10. Previously, saving a BosonPlotter session and
%   reloading it silently lost:
%     - formula / computed columns  (model.computedColumns)
%     - row masks                  (model.mask)
%     - X/Y column roles           (model.columnRoles)
%   The sessionManager now round-trips all three, and onLoadSession
%   syncs them into appData.model via restoreFromSnapshot.
%
%   This test seeds one dataset with all three kinds of state, saves,
%   loads into a fresh GUI, and verifies each survives.
%
%   Also covers the legacy-session path: a .mat saved before these
%   fields existed should load without error and populate defaults
%   (empty computedColumns, all-true mask, default ColumnRoles).
%
%   Run standalone:  run tests/gui/test_sessionRoundtripWorkspace
%   Run via group :  runAllTests(Group="gui")

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end

    close('all','force'); drawnow;

    passed  = 0;
    failed  = 0;
    failures = {};

    XRDML_F = fullfile(rootDir, '+test_datasets', 'XRDML', 'La2NiO4_1.xrdml');
    tmpDir  = fullfile(tempdir, 'sessRT_' + string(datetime('now','Format','yyyyMMdd_HHmmss')));
    mkdir(tmpDir);
    cleanupTmp = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: Computed column + mask + column roles round-trip
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: WorkspaceModel state round-trip ==\n');
    try
        api1 = BosonPlotter('Visible','off');
        cleanupApi1 = onCleanup(@() safeClose(api1)); %#ok<NASGU>
        api1.addFiles({XRDML_F});
        drawnow;

        model1 = api1.getModel();
        check('baseline: model has exactly 1 dataset', model1.count() == 1);

        % Seed state: one formula column, a partial mask, and a custom
        % xGroup added to the default ColumnRoles.
        ds   = model1.getData(1);
        cols = ds.labels;
        assert(~isempty(cols), 'dataset needs >=1 column to seed state');
        yCol = cols{1};

        % Formula columns reference labels via col("Name")
        model1.addComputedColumn(1, 'doubled', ...
            sprintf('col("%s") * 2', yCol), 'a.u.');

        nRows = numel(ds.time);
        maskRows = 1:min(5, nRows);
        model1.maskPoints(1, maskRows);

        % Add a non-default X group so we can verify ColumnRoles
        % structure survives intact.  Default is a single group
        % (xCol=0, yCols=1:N); we add a second group pairing col 1 to
        % itself (harmless but distinguishable after round-trip).
        roles = model1.getColumnRoles(1);
        nGroupsBefore = numel(roles.xGroups);
        roles = roles.addXGroup(1, 1);
        model1.setColumnRoles(1, roles);

        % Save
        sessionFile = fullfile(tmpDir, 'rt1.mat');
        api1.saveSession(sessionFile);
        check('session file written', isfile(sessionFile));

        % Reload in a fresh GUI instance
        api1.close();
        clear cleanupApi1;
        drawnow;

        api2 = BosonPlotter('Visible','off');
        cleanupApi2 = onCleanup(@() safeClose(api2)); %#ok<NASGU>
        api2.loadSession(sessionFile);
        drawnow;

        model2 = api2.getModel();
        check('after load: model has 1 dataset', model2.count() == 1);

        % Computed column restored? (getComputedColumns returns a cell of structs)
        cc = model2.getComputedColumns(1);
        check('computed column count restored', numel(cc) == 1);
        if ~isempty(cc)
            check('computed column name restored', strcmp(cc{1}.name, 'doubled'));
            check('computed column expression restored', ...
                  contains(cc{1}.expression, yCol));
        end

        % Mask restored?
        m = model2.getMask(1);
        check('mask length matches dataset rows', numel(m) == nRows);
        if numel(m) == nRows
            check(sprintf('first %d rows are masked (false)', numel(maskRows)), ...
                  all(~m(maskRows)));
            if numel(m) > numel(maskRows)
                check('rows beyond mask region remain true', ...
                      all(m(numel(maskRows)+1:end)));
            end
        end

        % Column roles restored?
        r2 = model2.getColumnRoles(1);
        check('column roles object restored', ...
              isa(r2, 'dataWorkspace.ColumnRoles'));
        if isa(r2, 'dataWorkspace.ColumnRoles')
            check('custom xGroup survived round-trip', ...
                  numel(r2.xGroups) == nGroupsBefore + 1);
        end
    catch ME
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: Legacy session (missing new fields) loads with defaults
    % ════════════════════════════════════════════════════════════════════
    % Simulate a pre-2026-04 session by hand-crafting a .mat that has
    % only the old savedDatasets/savedActiveIdx fields.
    fprintf('\n== TEST 2: Legacy session loads with defaults ==\n');
    try
        api3 = BosonPlotter('Visible','off');
        cleanupApi3 = onCleanup(@() safeClose(api3)); %#ok<NASGU>
        api3.addFiles({XRDML_F});
        drawnow;

        % Save a full session, then strip the new fields to simulate legacy
        fullFile   = fullfile(tmpDir, 'rt2_full.mat');
        legacyFile = fullfile(tmpDir, 'rt2_legacy.mat');
        api3.saveSession(fullFile);

        S = load(fullFile, '-mat');
        legacyFields = setdiff(fieldnames(S), ...
            {'savedMask','savedComputedColumns','savedColumnRoles','savedModelVersion'});
        Sl = struct();
        for k = 1:numel(legacyFields)
            Sl.(legacyFields{k}) = S.(legacyFields{k});
        end
        save(legacyFile, '-struct', 'Sl', '-v7.3');

        api3.close();
        clear cleanupApi3;
        drawnow;

        api4 = BosonPlotter('Visible','off');
        cleanupApi4 = onCleanup(@() safeClose(api4)); %#ok<NASGU>
        api4.loadSession(legacyFile);
        drawnow;

        model4 = api4.getModel();
        check('legacy load: 1 dataset', model4.count() == 1);
        check('legacy load: computedColumns defaults to empty', ...
              isempty(model4.getComputedColumns(1)));

        ds4 = model4.getData(1);
        m4  = model4.getMask(1);
        check('legacy load: mask length matches dataset rows', ...
              numel(m4) == numel(ds4.time));
        check('legacy load: mask is all-true (no rows masked)', all(m4));

        r4 = model4.getColumnRoles(1);
        check('legacy load: default ColumnRoles populated', ...
              isa(r4, 'dataWorkspace.ColumnRoles'));
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 68));
    fprintf('  test_sessionRoundtripWorkspace: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_sessionRoundtripWorkspace:failed', '%d test(s) failed', failed);
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
        for f = 1:min(5, numel(ME.stack))
            fprintf('         at %s:%d\n', ME.stack(f).name, ME.stack(f).line);
        end
    end
end

function safeClose(api)
    try
        if isstruct(api) && isfield(api, 'close')
            api.close();
        end
    catch
        % ignore
    end
end
