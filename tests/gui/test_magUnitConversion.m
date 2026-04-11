function test_magUnitConversion
%TEST_MAGUNITCONVERSION  End-to-end test: changing the field unit dropdown
%   actually converts the x-axis data on the live preview.
%
%   This is the integration regression net for the Oe→T fix.  It loads
%   a real VSM dataset, drives the api.setFieldUnit entry point to
%   change field unit, and reads back the actual line XData to verify
%   the values were scaled by the expected factor.
%
%   Also verifies the "raw data preservation" rule: after the dropdown
%   changes, the underlying ds.data.time array is UNCHANGED — the
%   conversion only applies to what's displayed.

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end

    VSM_F = fullfile(rootDir, '+test_datasets', 'QuantumDesign', 'EDP136_Perp_StrawNew.dat');
    if ~isfile(VSM_F)
        warning('test_magUnitConversion:noData', ...
            'Missing VSM test file %s — skipping', VSM_F);
        return;
    end

    passed = 0;
    failed = 0;
    failures = {};

    api = BosonPlotter();
    api.fig.Visible = 'off';
    drawnow;
    cleanupApi = onCleanup(@() api.close()); %#ok<NASGU>

    try
        api.addFiles({VSM_F});
        api.setActiveIdx(1);
        drawnow;
    catch ME
        error('test_magUnitConversion:setup', ...
              'Failed to load VSM file: %s', ME.message);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: Baseline — x-axis is in Oersted
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: baseline Oe ==\n');
    try
        ax = api.getAxes();
        drawnow;

        lines = findall(ax, 'Type', 'line', '-not', 'Tag', 'GUIFringeMarker', ...
                            '-not', 'Tag', 'GUIMaskedPoints');
        ebars = findall(ax, 'Type', 'errorbar', '-not', 'Tag', 'GUIFringeMarker');
        dataH = [lines(:); ebars(:)];

        check('at least one data series on axes', ~isempty(dataH));

        if ~isempty(dataH)
            xOe = dataH(1).XData;
            xMaxOe = max(abs(xOe));
            check('baseline x range is in Oersted order of magnitude (>= 1000)', xMaxOe >= 1000);
        end
    catch ME
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: Switch to Tesla — x-axis values divided by 1e4
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2: Oe → T conversion on live plot ==\n');
    try
        % Capture baseline x data from current line objects
        ax = api.getAxes();
        dataH0 = [
            findall(ax, 'Type', 'line', '-not', 'Tag', 'GUIFringeMarker', ...
                       '-not', 'Tag', 'GUIMaskedPoints');
            findall(ax, 'Type', 'errorbar')
        ];
        xBefore = dataH0(1).XData(:);

        % Drive the conversion via the clean programmatic API
        api.setFieldUnit('T');
        drawnow;

        % Read the converted line data back
        dataH1 = [
            findall(ax, 'Type', 'line', '-not', 'Tag', 'GUIFringeMarker', ...
                       '-not', 'Tag', 'GUIMaskedPoints');
            findall(ax, 'Type', 'errorbar')
        ];
        xAfter = dataH1(1).XData(:);

        % Conversion factor is 1e-4 (Oe → T)
        expected = xBefore * 1e-4;

        check('x array length unchanged',     numel(xAfter) == numel(xBefore));
        check('Oe→T conversion applied (max error < 1e-10)', ...
              max(abs(xAfter - expected)) < 1e-10);
        check('max |xAfter| is in Tesla range (<= 10)', max(abs(xAfter)) <= 10);
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 3: Raw data preservation — ds.data.time unchanged
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 3: ds.data not mutated by conversion ==\n');
    try
        datasets = api.getDatasets();
        ds = datasets{1};

        % After setting unit to T, ds.data.time should STILL be in Oe
        check('ds.data.time is still in Oe-scale (>= 1000)', ...
              max(abs(ds.data.time(:))) >= 1000);
        check('ds.fieldUnit is "T" (requested)', strcmp(ds.fieldUnit, 'T'));
        check('ds.data.metadata.xColumnUnit is still "Oe" (raw)', ...
              strcmpi(ds.data.metadata.xColumnUnit, 'Oe'));
    catch ME
        recordCrash('TEST 3', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 4: Switch back to Oe — values restored
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 4: switch back to Oe restores values ==\n');
    try
        api.setFieldUnit('Oe');
        drawnow;

        ax = api.getAxes();
        dataH = [
            findall(ax, 'Type', 'line', '-not', 'Tag', 'GUIFringeMarker', ...
                       '-not', 'Tag', 'GUIMaskedPoints');
            findall(ax, 'Type', 'errorbar')
        ];
        xBack = dataH(1).XData(:);

        check('max |xBack| back in Oe range (>= 1000)', max(abs(xBack)) >= 1000);
    catch ME
        recordCrash('TEST 4', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 5: emu/g with sampleMass=0 → warn, no conversion, no crash
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 5: emu/g with missing mass → warn, no crash ==\n');
    try
        api.setMomentUnit('emu/g');
        drawnow;   % should NOT crash — warning is accumulated, not thrown

        check('plot did not crash with emu/g + zero mass', isvalid(api.fig));

        % With missing mass, conversion should NOT have been applied —
        % the line YData should still be in the original emu range.
        % (We can't easily assert an exact factor here because the
        % moment values depend on the dataset; we just verify the plot
        % still exists and the values are finite.)
        ax = api.getAxes();
        dataH = [
            findall(ax, 'Type', 'line', '-not', 'Tag', 'GUIFringeMarker', ...
                       '-not', 'Tag', 'GUIMaskedPoints');
            findall(ax, 'Type', 'errorbar')
        ];
        if ~isempty(dataH)
            y = dataH(1).YData(:);
            check('YData is finite after failed emu/g conversion', all(isfinite(y(:))));
        end

        % Reset
        api.setMomentUnit('emu');
        drawnow;
    catch ME
        recordCrash('TEST 5', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 6: API is reachable and exposes the new entry points
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 6: api exposes setFieldUnit / setMomentUnit ==\n');
    try
        check('api.setFieldUnit exists',  isfield(api, 'setFieldUnit')  && isa(api.setFieldUnit,  'function_handle'));
        check('api.setMomentUnit exists', isfield(api, 'setMomentUnit') && isa(api.setMomentUnit, 'function_handle'));
    catch ME
        recordCrash('TEST 6', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 68));
    fprintf('  test_magUnitConversion: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_magUnitConversion:failed', '%d test(s) failed', failed);
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
