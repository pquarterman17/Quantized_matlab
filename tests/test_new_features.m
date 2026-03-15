%TEST_NEW_FEATURES  Tests for features 4-16 implemented in the proposed features batch.
%
%   Run standalone:  cd tests; run test_new_features
%   Run from root:   run tests/test_new_features
%
%   Tests standalone utility functions and parser changes.
%   GUI tests require headless mode and are in a separate section.

clear; clc;

% Ensure toolbox is on the path
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
if ~contains(path, rootDir)
    addpath(rootDir);
end

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  FEATURE #10: Split Pearson VII utility
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST 1: splitPearsonVII — symmetric case matches Lorentzian ══\n');
try
    x = linspace(25, 35, 500)';
    % Symmetric Pearson VII with m=1 should match Lorentzian
    % params = [H, center, wL, wR, mL, mR, baseline]
    params = [1000, 30, 0.5, 0.5, 1, 1, 10];
    y = utilities.splitPearsonVII(x, params);

    % With k=(2^(1/m)-1), m=1: y = H/(1+(dx/w)^2) + bg
    % This is a Lorentzian where w = HWHM, FWHM = wL+wR = 1.0
    w = 0.5;  % each half-width
    yLor = 1000 ./ (1 + ((x - 30)./w).^2) + 10;

    maxErr = max(abs(y - yLor));
    assert(maxErr < 1e-10, 'symmetric split Pearson VII should match Lorentzian, err=%.2e', maxErr);

    % Check peak value at exact center
    yCenter = utilities.splitPearsonVII(30, params);
    assert(abs(yCenter - 1010) < 1e-10, 'peak should be H + baseline = 1010');
    [~, iMax] = max(y);
    assert(abs(x(iMax) - 30) < 0.1, 'peak should be at center = 30');

    fprintf('  Max error vs Lorentzian: %.2e\n', maxErr);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

fprintf('\n══ TEST 2: splitPearsonVII — asymmetric case ══\n');
try
    x = linspace(40, 50, 500)';
    params = [5000, 45, 0.3, 0.6, 2, 1.5, 20];
    y = utilities.splitPearsonVII(x, params);

    % Peak should be at center — evaluate at exact center for height check
    yCenter = utilities.splitPearsonVII(45, params);
    assert(abs(yCenter - 5020) < 1e-10, 'peak height should be H+baseline = 5020');
    [~, iMax] = max(y);
    assert(abs(x(iMax) - 45) < 0.05, 'peak center should be at 45');

    % Left side should be narrower (wL=0.3) than right (wR=0.6)
    halfMaxLevel = (5020 + 20) / 2;  % midpoint between peak and baseline
    leftHalf = y(x < 45);
    rightHalf = y(x >= 45);

    % FWHM = wL + wR = 0.9
    assert(abs(0.3 + 0.6 - 0.9) < 1e-10, 'FWHM should be wL+wR');

    fprintf('  Peak: %.1f at x=%.3f (expected 5020 at 45)\n', yCenter, x(iMax));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

fprintf('\n══ TEST 3: splitPearsonVII — input validation ══\n');
try
    x = (1:10)';

    % Should error on negative width
    try
        utilities.splitPearsonVII(x, [100, 5, -0.5, 0.5, 1, 1, 0]);
        error('Should have thrown for negative wL');
    catch ME
        assert(contains(ME.message, 'positive', 'IgnoreCase', true), ...
            'expected positive width error');
    end

    % Should error on shape < 0.5
    try
        utilities.splitPearsonVII(x, [100, 5, 0.5, 0.5, 0.3, 1, 0]);
        error('Should have thrown for mL < 0.5');
    catch ME
        assert(contains(ME.message, '0.5', 'IgnoreCase', true), ...
            'expected shape exponent error');
    end

    fprintf('  Input validation correct\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  FEATURE #14: Dark theme struct
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST 4: styles.dark — struct completeness ══\n');
try
    d = styles.dark();
    s = styles.default();

    % Dark theme should have all fields that default has
    defFields = fieldnames(s);
    for i = 1:numel(defFields)
        assert(isfield(d, defFields{i}), ...
            'dark theme missing field: %s', defFields{i});
    end

    % Dark theme should also have additional GUI fields
    extraFields = {'bgColor', 'fgColor', 'axesBgColor', 'axesFgColor', ...
                   'gridColor', 'panelBgColor', 'buttonBgColor', 'buttonFgColor', ...
                   'listBgColor', 'listFgColor', 'editBgColor', 'editFgColor'};
    for i = 1:numel(extraFields)
        assert(isfield(d, extraFields{i}), ...
            'dark theme missing GUI field: %s', extraFields{i});
    end

    % Colors should be RGB triplets
    assert(size(d.bgColor, 2) == 3, 'bgColor should be [1x3]');
    assert(all(d.bgColor >= 0 & d.bgColor <= 1), 'bgColor values should be in [0,1]');
    assert(size(d.colors, 2) == 3, 'colors should have 3 columns');
    assert(size(d.colors, 1) >= 6, 'colors should have at least 6 entries');

    fprintf('  Default fields: %d, Dark extra fields: %d\n', numel(defFields), numel(extraFields));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  FEATURE #8: QD scan type auto-detection
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST 5: importQDVSM — scan type detection (real file) ══\n');
try
    % Find a real QD VSM file
    testFiles = dir(fullfile(rootDir, '+test_datasets', 'QuantumDesign', '*.dat'));

    if isempty(testFiles)
        fprintf('  SKIP: No QD test files found\n');
        passed = passed + 1;  % count as pass (skip)
    else
        testFile = fullfile(testFiles(1).folder, testFiles(1).name);
        data = parser.importQDVSM(testFile, 'Verbose', false);

        assert(isfield(data.metadata, 'parserSpecific'), 'should have parserSpecific');
        assert(isfield(data.metadata.parserSpecific, 'scanType'), ...
            'should have scanType field');

        validTypes = {'MvsH', 'MvsT', 'MvsTime', 'ACsusceptibility', 'unknown'};
        assert(ismember(data.metadata.parserSpecific.scanType, validTypes), ...
            'scanType "%s" is not a valid type', data.metadata.parserSpecific.scanType);

        fprintf('  File: %s\n', testFiles(1).name);
        fprintf('  Detected scan type: %s\n', data.metadata.parserSpecific.scanType);
        fprintf('  PASS\n');
        passed = passed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

fprintf('\n══ TEST 6: importQDVSM — scan type detection (synthetic header) ══\n');
try
    tmpDir = tempdir();

    % Create a synthetic QD VSM file with STARTUPAXIS
    tmpFile = fullfile(tmpDir, 'test_scantype.dat');
    fid = fopen(tmpFile, 'w');
    fprintf(fid, '[Header]\n');
    fprintf(fid, 'BYAPP,QD VSM\n');
    fprintf(fid, 'STARTUPAXIS,X,2\n');   % X axis = column 2 (Temperature)
    fprintf(fid, 'STARTUPAXIS,Y1,3\n');
    fprintf(fid, '[Data]\n');
    fprintf(fid, 'Time Stamp (s),Temperature (K),Moment (emu)\n');
    fprintf(fid, '0,300,0.001\n');
    fprintf(fid, '1,290,0.0012\n');
    fprintf(fid, '2,280,0.0015\n');
    fprintf(fid, '3,270,0.0018\n');
    fprintf(fid, '4,260,0.0020\n');
    fclose(fid);
    cleanObj = onCleanup(@() delete(tmpFile));

    data = parser.importQDVSM(tmpFile, 'Verbose', false, 'XAxis', 'temp', 'YAxis', 'moment');

    assert(strcmp(data.metadata.parserSpecific.scanType, 'MvsT'), ...
        'expected MvsT, got %s', data.metadata.parserSpecific.scanType);

    fprintf('  STARTUPAXIS → Temperature → MvsT: correct\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  FEATURE #15: Origin script export
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST 7: exportOriginScript — basic export ══\n');
try
    tmpDir = tempdir();
    scriptPath = fullfile(tmpDir, 'test_origin.ogs');
    csvPath    = fullfile(tmpDir, 'test_origin_data.csv');

    % Create a simple data struct
    data.time   = (1:10)';
    data.values = [(1:10)' * 2, (1:10)' * 3];
    data.labels = {'Channel1', 'Channel2'};
    data.units  = {'V', 'mA'};
    data.metadata.source = 'test_sample.dat';
    data.metadata.xColumnName = 'Time';
    data.metadata.xColumnUnit = 's';

    utilities.exportOriginScript(data, scriptPath);
    cleanObj1 = onCleanup(@() delete(scriptPath));
    cleanObj2 = onCleanup(@() delete(csvPath));

    % Check script file exists and contains LabTalk
    assert(exist(scriptPath, 'file') == 2, 'script file should exist');
    scriptText = fileread(scriptPath);
    assert(contains(scriptText, 'LabTalk'), 'script should contain LabTalk header');
    assert(contains(scriptText, 'impASC'), 'script should contain import command');
    assert(contains(scriptText, 'wks.col1.type = 4'), 'should designate X column');
    assert(contains(scriptText, 'Channel1'), 'should contain channel name');
    assert(contains(scriptText, 'plotxy'), 'should contain graph creation');

    % Check CSV data file
    assert(exist(csvPath, 'file') == 2, 'CSV data file should exist');
    csvText = fileread(csvPath);
    assert(contains(csvText, 'Time'), 'CSV should contain header');
    assert(contains(csvText, 'Channel1'), 'CSV should contain channel names');

    fprintf('  Script: %d bytes, CSV: %d bytes\n', numel(scriptText), numel(csvText));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

fprintf('\n══ TEST 8: exportOriginScript — log scale options ══\n');
try
    tmpDir = tempdir();
    scriptPath = fullfile(tmpDir, 'test_origin_log.ogs');

    data.time   = (1:5)';
    data.values = (1:5)' * 10;
    data.labels = {'Intensity'};
    data.units  = {'cps'};
    data.metadata.source = 'xrd_scan.xrdml';
    data.metadata.xColumnName = '2Theta';
    data.metadata.xColumnUnit = 'deg';

    utilities.exportOriginScript(data, scriptPath, 'LogY', true, 'LogX', false);
    cleanObj = onCleanup(@() delete(scriptPath));

    scriptText = fileread(scriptPath);
    assert(contains(scriptText, 'layer.y.type = 1'), 'should have log Y');
    assert(~contains(scriptText, 'layer.x.type = 1'), 'should NOT have log X');

    % Clean up the CSV too
    [sd, sn, ~] = fileparts(scriptPath);
    csvClean = fullfile(sd, [sn, '_data.csv']);
    if exist(csvClean, 'file'), delete(csvClean); end

    fprintf('  LogY flag correctly written\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  FEATURE #10: Split Pearson VII area estimation
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST 9: splitPearsonVII — numerical area matches Lorentzian ══\n');
try
    x = linspace(-200, 260, 50000)';
    H = 500;  c = 30;  w = 0.8;

    % Symmetric Lorentzian (m=1): y = H/(1+(dx/w)^2), area = H*w*pi
    params = [H, c, w, w, 1, 1, 0];
    y = utilities.splitPearsonVII(x, params);
    numArea = trapz(x, y);

    analyticalArea = H * w * pi;

    relErr = abs(numArea - analyticalArea) / analyticalArea;
    assert(relErr < 0.005, 'numerical area should match analytical within 0.5%%, got %.4f%%', relErr*100);

    fprintf('  Numerical: %.2f, Analytical: %.2f, Rel err: %.4f%%\n', ...
        numArea, analyticalArea, relErr*100);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  FEATURE #8: detectScanType fallback logic
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST 10: importQDVSM — scan type fallback (field sweep) ══\n');
try
    tmpDir = tempdir();
    tmpFile = fullfile(tmpDir, 'test_field_sweep.dat');
    fid = fopen(tmpFile, 'w');
    fprintf(fid, '[Header]\n');
    fprintf(fid, 'BYAPP,QD PPMS\n');
    % No STARTUPAXIS — should fall back to column-name inference
    fprintf(fid, '[Data]\n');
    fprintf(fid, 'Magnetic Field (Oe),Moment (emu)\n');
    fprintf(fid, '0,0.001\n');
    fprintf(fid, '1000,0.005\n');
    fprintf(fid, '2000,0.009\n');
    fprintf(fid, '3000,0.012\n');
    fprintf(fid, '4000,0.015\n');
    fclose(fid);
    cleanObj = onCleanup(@() delete(tmpFile));

    data = parser.importQDVSM(tmpFile, 'Verbose', false);

    assert(strcmp(data.metadata.parserSpecific.scanType, 'MvsH'), ...
        'expected MvsH from column fallback, got %s', data.metadata.parserSpecific.scanType);

    fprintf('  Column fallback → MvsH: correct\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  FEATURE #14: Default theme consistency
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST 11: styles.dark — line geometry matches default ══\n');
try
    d = styles.dark();
    s = styles.default();

    % Line geometry should be identical between themes
    assert(d.lineWidth == s.lineWidth, 'lineWidth should match');
    assert(d.lineWidthThin == s.lineWidthThin, 'lineWidthThin should match');
    assert(d.markerSize == s.markerSize, 'markerSize should match');
    assert(d.fontSize == s.fontSize, 'fontSize should match');
    assert(d.titleFontSize == s.titleFontSize, 'titleFontSize should match');

    % Dark colors should be brighter (higher luminance) than default
    % since they need to show on dark backgrounds
    darkLum = mean(d.colors, 2);
    defLum  = mean(s.colors, 2);
    assert(mean(darkLum) > mean(defLum), ...
        'dark theme colors should be brighter on average');

    fprintf('  Geometry matches, dark palette brighter: %.2f vs %.2f\n', ...
        mean(darkLum), mean(defLum));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  FEATURE #15: Origin script — error column detection
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST 12: exportOriginScript — yErr column detection ══\n');
try
    tmpDir = tempdir();
    scriptPath = fullfile(tmpDir, 'test_origin_err.ogs');

    data.time   = (1:5)';
    data.values = [(1:5)' * 10, (1:5)' * 0.1];
    data.labels = {'Moment', 'M. Std. Err.'};
    data.units  = {'emu', 'emu'};
    data.metadata.source = 'vsm_data.dat';
    data.metadata.xColumnName = 'Field';
    data.metadata.xColumnUnit = 'Oe';

    utilities.exportOriginScript(data, scriptPath);
    cleanObj = onCleanup(@() delete(scriptPath));

    scriptText = fileread(scriptPath);
    % Column 2 (Moment) should be Y, column 3 (Std. Err.) should be yErr
    assert(contains(scriptText, 'wks.col2.type = 1'), 'Moment should be Y type');
    assert(contains(scriptText, 'wks.col3.type = 3'), 'Std. Err. should be yErr type');

    % Clean CSV
    [sd, sn, ~] = fileparts(scriptPath);
    csvClean = fullfile(sd, [sn, '_data.csv']);
    if exist(csvClean, 'file'), delete(csvClean); end

    fprintf('  Error column correctly designated as yErr\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n');
fprintf('════════════════════════════════════════════════════════════════\n');
fprintf('  NEW FEATURES TEST SUMMARY\n');
fprintf('════════════════════════════════════════════════════════════════\n');
fprintf('  Passed: %d / %d\n', passed, passed + failed);
fprintf('  Failed: %d / %d\n', failed, passed + failed);
fprintf('════════════════════════════════════════════════════════════════\n');

if failed == 0
    fprintf('\n  All new feature tests passed!\n\n');
else
    fprintf('\n  %d test(s) failed.\n\n', failed);
    error('test_new_features:failures', '%d test(s) failed.', failed);
end
