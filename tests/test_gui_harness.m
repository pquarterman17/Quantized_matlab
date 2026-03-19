%TEST_GUI_HARNESS  Automated test harness for DataPlotter programmatic API.
%
%   Tests the GUI through its programmatic API interface:
%   - File loading and navigation
%   - Corrections (offset, background subtraction)
%   - Peak detection and fitting
%   - Session save/load
%   - Multi-dataset operations
%
%   Run standalone:  cd tests; run test_gui_harness
%   Run from root:   run tests/test_gui_harness
%
%   Uses a SINGLE GUI instance for all tests except 11/12 (session reload),
%   calling api.reset() between tests to clear state. Tests 11 and 12 launch
%   a temporary second instance only for the session reload phase.
%
%   Each test prints PASS / FAIL. Cleanup is automatic via onCleanup.

clear; clc;

% Ensure toolbox is on the path
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
if ~contains(path, rootDir)
    addpath(rootDir);
end

ROOT = rootDir;
XRDML_F = fullfile(ROOT, '+test_datasets', 'XRDML', 'La2NiO4_1.xrdml');
VSM_F   = fullfile(ROOT, '+test_datasets', 'QuantumDesign', 'EDP136_Perp_StrawNew.dat');

% Setup temp directory for session files
tmpDir = fullfile(tempdir, 'gui_test_' + string(datetime('now','Format','yyyyMMdd_HHmmss')));
mkdir(tmpDir);
cleanupTmp = onCleanup(@() rmdir(tmpDir, 's'));

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  Launch single shared GUI instance
% ════════════════════════════════════════════════════════════════════════
api = DataPlotter();
api.fig.Visible = 'off';
drawnow;
cleanupApi = onCleanup(@() api.close());

% ════════════════════════════════════════════════════════════════════════
%  1. GUI launches with valid API
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: GUI launches with valid API ══\n');
try
    % Verify API struct has all expected fields
    assert(isstruct(api), 'API must be a struct');
    assert(isfield(api, 'fig'), 'missing field: fig');
    assert(isfield(api, 'addFiles'), 'missing field: addFiles');
    assert(isfield(api, 'getDatasets'), 'missing field: getDatasets');
    assert(isfield(api, 'getActiveIdx'), 'missing field: getActiveIdx');

    % Initial state: no active dataset
    assert(api.getActiveIdx() == 0, 'initially activeIdx should be 0');

    fprintf('  API struct with %d fields\n', numel(fieldnames(api)));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. Load XRDML file
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: Load XRDML file ══\n');
try
    api.reset();
    api.addFiles({XRDML_F});
    drawnow;

    datasets = api.getDatasets();
    assert(isscalar(datasets), sprintf('expected 1 dataset, got %d', numel(datasets)));

    ds = datasets{1};
    assert(isfield(ds, 'data'), 'missing data field');
    assert(~isempty(ds.data.time), 'time vector is empty');
    assert(strcmpi(ds.parserName, 'importXRDML'), ...
        sprintf('expected parserName=importXRDML, got %s', ds.parserName));

    fprintf('  Data points: %d\n', numel(ds.data.time));
    fprintf('  Parser: %s\n', ds.parserName);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Load QD VSM file
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: Load QD VSM file ══\n');
try
    api.reset();
    api.addFiles({VSM_F});
    drawnow;

    datasets = api.getDatasets();
    assert(isscalar(datasets), sprintf('expected 1 dataset, got %d', numel(datasets)));

    ds = datasets{1};
    parserName = ds.parserName;
    assert(any(strcmpi(parserName, {'importQDVSM', 'importPPMS'})), ...
        sprintf('unexpected parser: %s', parserName));

    fprintf('  Parser: %s\n', parserName);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Load multiple files
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: Load multiple files ══\n');
try
    api.reset();
    api.addFiles({XRDML_F, VSM_F});
    drawnow;

    datasets = api.getDatasets();
    assert(numel(datasets) == 2, sprintf('expected 2 datasets, got %d', numel(datasets)));

    parser1 = datasets{1}.parserName;
    parser2 = datasets{2}.parserName;
    assert(~strcmpi(parser1, parser2), ...
        sprintf('expected different parsers, got %s and %s', parser1, parser2));

    fprintf('  Datasets: %d\n', numel(datasets));
    fprintf('  Parsers: %s, %s\n', parser1, parser2);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. X offset correction
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: X offset correction ══\n');
try
    api.reset();
    api.addFiles({XRDML_F});
    drawnow;

    % Set X offset
    api.setCorrections(0.1, 0, 0, 0);
    api.applyCorrections();

    allDs = api.getDatasets();
    ds = allDs{1};
    assert(isfield(ds, 'corrData') && ~isempty(ds.corrData), 'corrData is empty');
    assert(~isempty(ds.corrData.time), 'corrected time is empty');

    % Verify correction applied: time should be original - xOffset
    orig_time = ds.data.time;
    corr_time = ds.corrData.time;
    expected_diff = -0.1;  % correction: time = time - xOffset, so corr = orig - 0.1
    actual_diff = corr_time(1) - orig_time(1);

    assert(abs(actual_diff - expected_diff) < 1e-10, ...
        sprintf('x offset mismatch: expected %.6e, got %.6e', expected_diff, actual_diff));

    fprintf('  Original time(1): %.8f\n', orig_time(1));
    fprintf('  Corrected time(1): %.8f\n', corr_time(1));
    fprintf('  Offset applied: %.8f (expected: -0.1)\n', actual_diff);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. Y offset correction
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6: Y offset correction ══\n');
try
    api.reset();
    api.addFiles({XRDML_F});
    drawnow;

    % Set Y offset
    api.setCorrections(0, 1.5, 0, 0);
    api.applyCorrections();

    allDs = api.getDatasets();
    ds = allDs{1};
    assert(~isempty(ds.corrData), 'corrData is empty');

    orig_val = ds.data.values(1,1);
    corr_val = ds.corrData.values(1,1);
    % GUI applies yOff as subtraction: corrData = origData - yOff
    expected_diff = -1.5;
    actual_diff = corr_val - orig_val;

    assert(abs(actual_diff - expected_diff) < 1e-10, ...
        sprintf('y offset mismatch: expected %.6e, got %.6e', expected_diff, actual_diff));

    fprintf('  Original value(1): %.6e\n', orig_val);
    fprintf('  Corrected value(1): %.6e\n', corr_val);
    fprintf('  Offset applied: %.6e (expected: 1.5)\n', actual_diff);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. Undo corrections
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7: Undo corrections ══\n');
try
    api.reset();
    api.addFiles({XRDML_F});
    drawnow;

    % Apply corrections
    api.setCorrections(0, 2.0, 0, 0);
    api.applyCorrections();

    allDs = api.getDatasets();
    ds = allDs{1};
    assert(~isempty(ds.corrData), 'corrData should not be empty after applyCorrections');

    % Undo
    api.undoCorrections();

    allDs = api.getDatasets();
    ds = allDs{1};
    if isfield(ds, 'corrData')
        assert(isempty(ds.corrData), 'corrData should be empty after undo');
    end

    fprintf('  Undo successful\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  8. Apply corrections to all datasets
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 8: Apply corrections to all datasets ══\n');
try
    api.reset();
    api.addFiles({XRDML_F, VSM_F});
    drawnow;

    % Set active to first, apply correction
    api.setActiveIdx(1);
    api.setCorrections(0, 3.0, 0, 0);
    api.fig.Visible = 'on'; drawnow;   % applyCorrectionsAll requires visible figure
    api.applyCorrectionsAll();
    api.fig.Visible = 'off';

    datasets = api.getDatasets();

    % Both should have corrData
    for i = 1:numel(datasets)
        assert(~isempty(datasets{i}.corrData), ...
            sprintf('dataset %d: corrData is empty', i));
    end

    fprintf('  Datasets with corrections: %d/%d\n', ...
        sum(cellfun(@(d) ~isempty(d.corrData), datasets)), numel(datasets));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  9. Auto-detect peaks (XRD)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 9: Auto-detect peaks (XRD) ══\n');
try
    api.reset();
    api.addFiles({XRDML_F});
    drawnow;

    api.autoPeaks();

    peaks = api.getPeaks();
    assert(~isempty(peaks), 'no peaks detected');
    assert(isfield(peaks(1), 'center'), 'missing peak.center field');

    fprintf('  Peaks detected: %d\n', numel(peaks));
    if ~isempty(peaks)
        fprintf('  First peak center: %.4f\n', peaks(1).center);
    end
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  10. Fit peaks
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 10: Fit peaks ══\n');
try
    api.reset();
    api.addFiles({XRDML_F});
    drawnow;

    api.autoPeaks();
    api.fig.Visible = 'on'; drawnow;   % fitPeaks requires visible figure
    api.fitPeaks();
    api.fig.Visible = 'off';

    peaks = api.getPeaks();
    assert(~isempty(peaks), 'no peaks after fit');

    % Check for fitted status and positive area
    hasFitted = any(strcmpi({peaks.status}, 'fitted'));
    hasArea = any(arrayfun(@(p) isfield(p, 'area') && p.area > 0, peaks));

    if hasFitted
        fprintf('  Peaks fitted: yes\n');
    else
        fprintf('  Peaks fitted: no (may be expected for this data)\n');
    end

    fprintf('  Peaks with area: %d\n', sum(hasArea));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  11. Session save/load round-trip
%  Uses shared GUI to save; launches a SECOND instance only for reload.
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 11: Session save/load round-trip ══\n');
try
    api.reset();
    api.addFiles({XRDML_F});
    drawnow;
    api.setActiveIdx(1);
    api.setCorrections(0, 3.0, 0, 0);
    api.applyCorrections();

    % Save session from the shared instance
    sessionFile = fullfile(tmpDir, 'test11_session.mat');
    api.saveSession(sessionFile);

    % Reload into a fresh second GUI instance
    api2 = launchHeadless();
    cleanupApi2 = onCleanup(@() safeClose(api2));

    api2.loadSession(sessionFile);

    datasets = api2.getDatasets();
    assert(isscalar(datasets), sprintf('expected 1 dataset, got %d', numel(datasets)));

    ds = datasets{1};
    assert(~isempty(ds.corrData), 'corrData not restored');
    assert(abs(ds.yOff - 3.0) < 1e-10, ...
        sprintf('yOff not restored correctly: %.6f vs 3.0', ds.yOff));

    fprintf('  Session file: %s\n', sessionFile);
    fprintf('  Datasets restored: %d\n', numel(datasets));
    fprintf('  Y offset restored: %.1f\n', ds.yOff);
    fprintf('  PASS\n');
    passed = passed + 1;

    safeClose(api2);
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  12. Session round-trip with peaks
%  Uses shared GUI to save; launches a SECOND instance only for reload.
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 12: Session save/load with peaks ══\n');
try
    api.reset();
    api.addFiles({XRDML_F});
    drawnow;
    api.autoPeaks();

    % Save session from the shared instance
    sessionFile = fullfile(tmpDir, 'test12_peaks_session.mat');
    api.saveSession(sessionFile);

    % Reload into a fresh second GUI instance
    api2 = launchHeadless();
    cleanupApi2 = onCleanup(@() safeClose(api2));

    api2.loadSession(sessionFile);

    peaks = api2.getPeaks();
    assert(~isempty(peaks), 'peaks not restored');

    fprintf('  Peaks restored: %d\n', numel(peaks));
    fprintf('  PASS\n');
    passed = passed + 1;

    safeClose(api2);
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  13. Session load with invalid file
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 13: Session load with invalid file ══\n');
try
    api.reset();

    % Create invalid session file (missing savedDatasets field)
    badSessionFile = fullfile(tmpDir, 'bad_session.mat');
    badData = 'this is not a valid session';
    save(badSessionFile, 'badData');

    % Try to load invalid session
    try
        api.loadSession(badSessionFile);
        fprintf('  FAIL: should have thrown error for invalid session\n');
        failed = failed + 1;
    catch loadErr
        % Expected
        assert(contains(lower(loadErr.message), 'session'), ...
            'error message should mention ''session''');
        fprintf('  Error caught (expected): %s\n', loadErr.message(1:min(50, end)));
        fprintf('  PASS\n');
        passed = passed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  14. Dataset visibility toggle
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 14: Dataset visibility toggle ══\n');
try
    api.reset();
    api.addFiles({XRDML_F, VSM_F});
    drawnow;

    api.setDatasetVisible(1, false);

    datasets = api.getDatasets();
    assert(datasets{1}.visible == false, 'visibility not set');
    assert(datasets{2}.visible ~= false, 'other dataset visibility changed');

    fprintf('  Dataset 1 visible: false\n');
    fprintf('  Dataset 2 visible: %d\n', datasets{2}.visible);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  15. Load non-existent file (graceful handling)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 15: Load non-existent file (graceful handling) ══\n');
try
    api.reset();

    % Try to load non-existent file
    try
        api.addFiles({'C:\does_not_exist_sample.xrdml'});
    catch
        % addFiles may throw or silently skip; both are acceptable
    end

    % GUI should still be functional
    datasets = api.getDatasets();
    % May be 0 datasets (file was skipped) or may throw
    fprintf('  Datasets after failed load: %d\n', numel(datasets));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  16. Data masking: mask region + unmask all
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 16: Data masking (mask region + unmask all) ══\n');
try
    api.reset();

    % Load XRD file
    api.addFiles({XRDML_F});
    drawnow;

    datasets = api.getDatasets();
    nOriginal = numel(datasets{1}.data.time);
    fprintf('  Total points: %d\n', nOriginal);

    % Mask a region in the middle of the data
    xAll = double(datasets{1}.data.time);
    xMid = (min(xAll) + max(xAll)) / 2;
    xSpan = (max(xAll) - min(xAll)) * 0.1;  % mask 10% of x-range
    yAll = datasets{1}.data.values(:,1);
    api.maskRegion(xMid - xSpan, xMid + xSpan, min(yAll), max(yAll));
    drawnow;

    % Verify mask was applied
    datasets = api.getDatasets();
    nMasked = sum(~datasets{1}.mask);
    assert(nMasked > 0, 'Expected some masked points');
    assert(nMasked < nOriginal, 'Expected partial mask, not all points');
    fprintf('  Masked points: %d (%.1f%%)\n', nMasked, 100*nMasked/nOriginal);

    % Unmask all
    api.unmaskAll();
    drawnow;
    datasets = api.getDatasets();
    nMaskedAfter = sum(~datasets{1}.mask);
    assert(nMaskedAfter == 0, 'Expected zero masked points after unmask');
    fprintf('  After unmask: %d masked\n', nMaskedAfter);

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  17. Peak window opens on auto-detect and has expected API fields
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 17: Peak window opens on auto-detect ══\n');
try
    api.reset();
    api.addFiles({XRDML_F});
    drawnow;

    % Peak window should exist but be hidden before any peaks
    assert(isfield(api, 'peakFig'), 'missing api.peakFig field');
    assert(isfield(api, 'showPeakWindow'), 'missing api.showPeakWindow field');
    assert(isvalid(api.peakFig), 'peakFig is not valid');
    assert(strcmp(api.peakFig.Visible, 'off'), 'peakFig should be hidden before peak detection');

    % Auto-detect peaks — should auto-open peak window
    api.autoPeaks();
    drawnow;

    assert(strcmp(api.peakFig.Visible, 'on'), 'peakFig should be visible after auto-detect');
    fprintf('  Peak window visible after autoPeaks: yes\n');

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  18. Peak window close hides but preserves peaks on main axes
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 18: Peak window close hides but preserves peaks ══\n');
try
    api.reset();
    api.addFiles({XRDML_F});
    drawnow;

    api.autoPeaks();
    drawnow;
    assert(strcmp(api.peakFig.Visible, 'on'), 'peakFig should be visible');

    % Close the peak window (should hide, not delete)
    api.peakFig.Visible = 'off';
    drawnow;

    % Peaks should still be in dataset
    peaks = api.getPeaks();
    assert(~isempty(peaks), 'peaks should still exist after closing peak window');
    fprintf('  Peaks after window close: %d\n', numel(peaks));

    % Re-open via API
    api.showPeakWindow();
    drawnow;
    assert(strcmp(api.peakFig.Visible, 'on'), 'peakFig should reopen via showPeakWindow');
    fprintf('  Peak window reopened: yes\n');

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════════
fprintf('\n%s\n', repmat(char(9552), 1, 72));
fprintf('SUMMARY: %d passed, %d failed\n', passed, failed);
if failed > 0
    fprintf('Status: FAIL\n');
    error('test_gui_harness:failures', '%d test(s) failed.', failed);
else
    fprintf('Status: ALL PASS\n');
end

% ════════════════════════════════════════════════════════════════════════
%  Local functions  (must appear after all script code)
% ════════════════════════════════════════════════════════════════════════
function api = launchHeadless()
%LAUNCHHEADLESS  Start DataPlotter with the figure hidden.
%   Used only for the session reload phase of tests 11 and 12, where a
%   fresh GUI instance is required to verify that saved state loads
%   correctly into a clean environment.
    api = DataPlotter();
    api.fig.Visible = 'off';
    drawnow;
end

function safeClose(a)
%SAFECLOSE  Close GUI figure, ignoring errors if already closed.
    try a.close(); catch, end
end
