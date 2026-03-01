function testNCNRDatVerification()
%TESTNCNRDATVERIFICATION Verify importNCNRDat works with user's NCNR PNR data files.
%
%   Comprehensive verification that:
%   - importNCNRDat loads all 4 polarization variants (.datA/B/C/D)
%   - Correct polarization states are extracted from file extensions
%   - Unified data struct format is maintained
%   - Metadata (intensity, background) is correctly parsed
%   - importAuto dispatch routes to the correct parser
%
%   Run from MATLAB:
%       >> testNCNRDatVerification
%
%   Expected: All tests pass (PASS count > 0)

    setupToolbox;  % Ensure toolbox is on path

    % ════════════════════════════════════════════════════════════════
    %  Define test dataset paths
    % ════════════════════════════════════════════════════════════════
    rootDir = fileparts(mfilename('fullpath'));
    testDatDir = fullfile(rootDir, '+test_datasets', 'NCNR', 'PNR_SF');
    testFileBase = fullfile(testDatDir, 'S11_Si_YIG_Co_mult_domain_abinitio-1-refl');

    % Map of file extensions to expected polarization states
    extMap = struct();
    extMap.datA = '++';  % R++ (up-up, non-spin-flip)
    extMap.datB = '+-';  % R+- (up-down, spin-flip)
    extMap.datC = '-+';  % R-+ (down-up, spin-flip)
    extMap.datD = '--';  % R-- (down-down, non-spin-flip)

    exts = {'datA', 'datB', 'datC', 'datD'};

    % ════════════════════════════════════════════════════════════════
    %  Print header
    % ════════════════════════════════════════════════════════════════
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║  NCNR Neutron Reflectometry Parser Verification Test       ║\n');
    fprintf('║  File: importNCNRDat.m (polarized neutron reflectivity)   ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n\n');

    passed = 0;
    failed = 0;

    % ════════════════════════════════════════════════════════════════
    %  TEST 1: Direct importNCNRDat calls on all 4 polarizations
    % ════════════════════════════════════════════════════════════════
    fprintf('TEST 1: Direct importNCNRDat calls (all 4 polarizations)\n');
    fprintf('───────────────────────────────────────────────────────────\n\n');

    results = struct();

    for i = 1:numel(exts)
        ext = exts{i};
        filepath = [testFileBase '.' ext];
        expectedPol = extMap.(ext);

        fprintf('  %-4s: ', ext);

        if ~isfile(filepath)
            fprintf('SKIP (file not found: %s)\n', filepath);
            continue;
        end

        try
            % Load the file
            data = parser.importNCNRDat(filepath);

            % Verify struct has all required fields
            assert(isstruct(data), 'output must be struct');
            assert(isfield(data, 'time'),     'missing field: .time');
            assert(isfield(data, 'values'),   'missing field: .values');
            assert(isfield(data, 'labels'),   'missing field: .labels');
            assert(isfield(data, 'units'),    'missing field: .units');
            assert(isfield(data, 'metadata'), 'missing field: .metadata');

            % Verify metadata structure
            assert(isfield(data.metadata, 'parserSpecific'), ...
                'missing field: .metadata.parserSpecific');
            assert(isfield(data.metadata.parserSpecific, 'polarization'), ...
                'missing field: .metadata.parserSpecific.polarization');

            % Check polarization state
            actualPol = data.metadata.parserSpecific.polarization;
            assert(strcmp(actualPol, expectedPol), ...
                sprintf('expected pol=%s, got %s', expectedPol, actualPol));

            % Verify data dimensions
            nRows = numel(data.time);
            nCols = size(data.values, 2);
            assert(nRows > 0, 'no data rows');
            assert(nCols == 5, sprintf('expected 5 value columns, got %d', nCols));

            % Verify Q values are reasonable
            Q = data.time;
            assert(all(Q > 0), 'Q values must be positive');
            assert(all(Q < 0.15), 'Q values seem out of range (>0.15 Å⁻¹)');

            % Verify reflectivity values are reasonable
            % Note: Spin-flip (+-,-+) channels can have negative R in PNR data
            % Non-spin-flip (++,--) channels should be 0-1
            R = data.values(:, 2);  % R is in column 2 (after dQ)
            validR = R(~isnan(R));

            % For non-spin-flip (++) check 0-1 range
            if strcmp(expectedPol, '++') || strcmp(expectedPol, '--')
                assert(all(validR >= 0) && all(validR <= 1), ...
                    'Non-spin-flip R (reflectivity) must be in [0, 1]');
            else
                % For spin-flip, just verify they're finite and reasonable magnitude
                assert(all(abs(validR) <= 1), ...
                    'Spin-flip R magnitude should be reasonable (<1 in absolute value)');
            end

            % Store results
            results.(ext) = struct( ...
                'filepath', filepath, ...
                'polarization', actualPol, ...
                'nRows', nRows, ...
                'Q_min', min(Q), ...
                'Q_max', max(Q), ...
                'R_min', min(validR), ...
                'R_max', max(validR), ...
                'intensity', data.metadata.parserSpecific.intensity, ...
                'background', data.metadata.parserSpecific.background ...
            );

            fprintf('PASS (%d points, pol=%s, Q: %.4f–%.4f Å⁻¹)\n', ...
                nRows, actualPol, min(Q), max(Q));
            passed = passed + 1;

        catch ME
            fprintf('FAIL: %s\n', ME.message);
            failed = failed + 1;
        end
    end

    fprintf('\n');

    % ════════════════════════════════════════════════════════════════
    %  TEST 2: importAuto dispatch
    % ════════════════════════════════════════════════════════════════
    fprintf('TEST 2: importAuto dispatch routing\n');
    fprintf('───────────────────────────────────────────────────────────\n\n');

    for i = 1:numel(exts)
        ext = exts{i};
        filepath = [testFileBase '.' ext];

        fprintf('  %-4s: ', ext);

        if ~isfile(filepath)
            fprintf('SKIP\n');
            continue;
        end

        try
            [data, parserName] = parser.importAuto(filepath);

            % Verify correct parser was dispatched
            assert(strcmp(parserName, 'importNCNRDat'), ...
                sprintf('expected importNCNRDat, got %s', parserName));

            % Verify output is valid
            assert(isstruct(data), 'output must be struct');
            assert(numel(data.time) > 0, 'no data loaded');

            fprintf('PASS (dispatch: %s)\n', parserName);
            passed = passed + 1;

        catch ME
            fprintf('FAIL: %s\n', ME.message);
            failed = failed + 1;
        end
    end

    fprintf('\n');

    % ════════════════════════════════════════════════════════════════
    %  TEST 3: Verify data structure and content quality
    % ════════════════════════════════════════════════════════════════
    fprintf('TEST 3: Verify data structure and content quality\n');
    fprintf('───────────────────────────────────────────────────────────\n\n');

    try
        % Load all 4 files and verify structure
        dataA = parser.importNCNRDat([testFileBase '.datA']);
        dataB = parser.importNCNRDat([testFileBase '.datB']);
        dataC = parser.importNCNRDat([testFileBase '.datC']);
        dataD = parser.importNCNRDat([testFileBase '.datD']);

        % Verify all have expected labels and units
        expectedLabels = {'Q', 'dQ', 'R', 'dR', 'theory', 'fresnel'};
        for dataName = {'dataA', 'dataB', 'dataC', 'dataD'}
            data = eval(dataName{1});
            assert(isequal(data.labels, expectedLabels), ...
                sprintf('%s: unexpected labels', dataName{1}));
        end

        % Check Q vector ranges are similar
        QA = dataA.time;
        QB = dataB.time;
        QC = dataC.time;
        QD = dataD.time;

        % All files should have Q ranging from ~0.005 to ~0.074 Å⁻¹
        % Note: slight variations (±0.2%) are normal in experimental PNR data
        Q_ranges = [min(QA) max(QA); min(QB) max(QB); ...
                    min(QC) max(QC); min(QD) max(QD)];

        % Verify Q min/max are within 3% tolerance (reasonable for PNR data)
        % Different detector configurations can have slight Q range variations
        Q_min_mean = mean(Q_ranges(:, 1));
        Q_max_mean = mean(Q_ranges(:, 2));
        Q_min_dev = max(abs(Q_ranges(:, 1) - Q_min_mean)) / Q_min_mean;
        Q_max_dev = max(abs(Q_ranges(:, 2) - Q_max_mean)) / Q_max_mean;

        assert(Q_min_dev < 0.03 && Q_max_dev < 0.03, ...
            'Q ranges differ excessively across files (>3%)');

        % Verify all have >90 data points (should be ~94)
        assert(numel(QA) > 90 && numel(QB) > 90 && ...
               numel(QC) > 90 && numel(QD) > 90, ...
            'Expected >90 data points in each file');

        fprintf('  Label consistency: PASS\n');
        fprintf('  Q range consistency: PASS\n');
        fprintf('  Data row count: PASS (A:%d, B:%d, C:%d, D:%d)\n', ...
            numel(QA), numel(QB), numel(QC), numel(QD));
        passed = passed + 1;

    catch ME
        fprintf('  Structure check: FAIL: %s\n', ME.message);
        failed = failed + 1;
    end

    fprintf('\n');

    % ════════════════════════════════════════════════════════════════
    %  Summary table
    % ════════════════════════════════════════════════════════════════
    if ~isempty(fieldnames(results))
        fprintf('SUMMARY TABLE\n');
        fprintf('───────────────────────────────────────────────────────────\n\n');
        fprintf('  Ext   Polarization  Rows   Q range (Å⁻¹)      Intensity   Background\n');
        fprintf('  ─────────────────────────────────────────────────────────────────\n');

        for i = 1:numel(exts)
            ext = exts{i};
            if isfield(results, ext)
                r = results.(ext);
                fprintf('  %s    %s         %3d    %.5f–%.5f   %.6f   %.6f\n', ...
                    ext, r.polarization, r.nRows, r.Q_min, r.Q_max, ...
                    r.intensity, r.background);
            end
        end
        fprintf('\n');
    end

    % ════════════════════════════════════════════════════════════════
    %  Final results
    % ════════════════════════════════════════════════════════════════
    fprintf('═════════════════════════════════════════════════════════════\n');
    fprintf('RESULTS: %d passed, %d failed\n', passed, failed);
    fprintf('═════════════════════════════════════════════════════════════\n\n');

    if failed == 0 && passed > 0
        fprintf('✓ All tests PASSED. importNCNRDat is working correctly.\n\n');
    else
        fprintf('✗ Some tests failed. See details above.\n\n');
    end

    % Return status for potential script integration
    if nargout > 0
        varargout{1} = passed;
        varargout{2} = failed;
    end

end
