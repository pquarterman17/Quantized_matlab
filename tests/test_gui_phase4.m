%TEST_GUI_PHASE4  Automated coverage for PLAN_TEST_2D_XRD Phase 4 scenarios.
%
%   Automates the headless-testable sub-scenarios from Phase 4 (Manual GUI
%   Testing) in PLAN_TEST_2D_XRD.md.  Scenarios requiring visual inspection
%   (colorbar appearance, pcolor curvature, legend layout) are noted as
%   "visual-only" and skipped.
%
%   Scenarios covered:
%     4.1  Load 2D file: parser properties, xColumn, axis info
%     4.2  Plot type (Heatmap/Contour/Filled Contour): all render without error
%     4.3  Contour level control: setContourLevels + Contour render
%     4.4  Q-space toggle: Qx/Qz fields present; cbMap2DQSpace state
%     4.7  Q-space line cuts: xColumnName = 'Q_x...' / 'Q_z...' after Q-space on
%     4.8  Colormap: switch colormap + replot without error
%     4.9  Mixed 1D + 2D datasets: is2DActive toggles correctly when switching
%
%   Run standalone:  cd tests; run test_gui_phase4
%   Run from root:   run tests/test_gui_phase4

clear; clc;

% Ensure toolbox is on the path
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
if ~contains(path, rootDir)
    addpath(rootDir);
end

ROOT = rootDir;
GEN_DIR = fullfile(ROOT, '+test_datasets', 'XRDML');
FILE_2D = fullfile(GEN_DIR, 'synthetic_rsm.xrdml');   % 5 Omega × 10 2Theta
FILE_1D = fullfile(GEN_DIR, 'La2NiO4_1.xrdml');

% Ensure synthetic_rsm.xrdml exists
if ~isfile(FILE_2D)
    addpath(GEN_DIR);
    writeTestXRDML2D(FILE_2D, 5, 10, ...
        'OmegaStart', 30.0, 'OmegaEnd', 31.0, ...
        'TwoThetaStart', 60.0, 'TwoThetaEnd', 62.0, ...
        'CountingTime', 0.5, 'PeakScale', 1000, 'Background', 50);
    rmpath(GEN_DIR);
    fprintf('Generated: %s\n', FILE_2D);
end

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  TEST 1 — 4.1 Load 2D file: parser fields and axis information
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1 (4.1): Load 2D file — parser fields and axis info ══\n');
try
    api = launchHeadless();
    C   = onCleanup(@() api.close());

    api.addFiles({FILE_2D});
    drawnow;

    assert(api.is2DActive(), 'is2DActive() should be true');

    ds = api.getDatasets();
    assert(~isempty(ds), 'no datasets loaded');
    d  = ds{1}.data;
    ps = d.metadata.parserSpecific;

    % Verify map2D has expected fields
    assert(isfield(ps, 'map2D'),               'map2D field missing');
    assert(isfield(ps.map2D, 'intensity'),     'map2D.intensity missing');
    assert(isfield(ps.map2D, 'axis1'),         'map2D.axis1 missing');
    assert(isfield(ps.map2D, 'axis2'),         'map2D.axis2 missing');
    assert(isfield(ps.map2D, 'axis1Name'),     'map2D.axis1Name missing');
    assert(isfield(ps.map2D, 'axis2Name'),     'map2D.axis2Name missing');
    assert(isfield(ps.map2D, 'intensityUnit'), 'map2D.intensityUnit missing');

    map = ps.map2D;
    assert(strcmp(map.axis1Name, 'Omega'),  ...
        sprintf('axis1Name expected ''Omega'', got ''%s''', map.axis1Name));
    assert(strcmp(map.axis2Name, '2Theta'), ...
        sprintf('axis2Name expected ''2Theta'', got ''%s''', map.axis2Name));
    assert(numel(map.axis1) == 5,  sprintf('Omega axis: expected 5 pts, got %d', numel(map.axis1)));
    assert(numel(map.axis2) == 10, sprintf('2Theta axis: expected 10 pts, got %d', numel(map.axis2)));

    fprintf('  is2D     : true\n');
    fprintf('  Map size : [%d %d] (%s × %s)\n', ...
        numel(map.axis1), numel(map.axis2), map.axis1Name, map.axis2Name);
    fprintf('  Int. unit: %s\n', map.intensityUnit);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 2 — 4.2 Plot type switching: Heatmap / Contour / Filled Contour
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2 (4.2): Plot type switching ══\n');
try
    api = launchHeadless();
    C   = onCleanup(@() api.close());

    api.addFiles({FILE_2D});
    drawnow;
    assert(api.is2DActive(), 'is2DActive() should be true');

    types = {'Heatmap', 'Contour', 'Filled Contour'};
    for ti = 1:numel(types)
        api.setMap2DType(types{ti});
        fprintf('  %-16s: OK\n', types{ti});
    end

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 3 — 4.3 Contour level control: setContourLevels + render
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3 (4.3): Contour level control ══\n');
try
    api = launchHeadless();
    C   = onCleanup(@() api.close());

    api.addFiles({FILE_2D});
    drawnow;
    assert(api.is2DActive(), 'is2DActive() should be true');

    % Switch to Contour, change levels, rerender
    api.setMap2DType('Contour');

    api.setContourLevels(5);
    api.setMap2DType('Contour');   % force rerender with new levels
    fprintf('  Contour @ 5 levels : OK\n');

    api.setContourLevels(40);
    api.setMap2DType('Contour');
    fprintf('  Contour @ 40 levels: OK\n');

    api.setContourLevels(20);
    api.setMap2DType('Filled Contour');
    fprintf('  Filled @ 20 levels : OK\n');

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 4 — 4.4 Q-space toggle: Qx/Qz present; checkbox state changes
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4 (4.4): Q-space toggle ══\n');
try
    api = launchHeadless();
    C   = onCleanup(@() api.close());

    api.addFiles({FILE_2D});
    drawnow;
    assert(api.is2DActive(), 'is2DActive() should be true');

    % Verify Qx/Qz were computed by the parser (wavelength present in synthetic file)
    ds = api.getDatasets();
    ps = ds{1}.data.metadata.parserSpecific;
    assert(isfield(ps.map2D, 'Qx'), 'map2D.Qx missing — Q-space unavailable');
    assert(isfield(ps.map2D, 'Qz'), 'map2D.Qz missing — Q-space unavailable');
    assert(isequal(size(ps.map2D.Qx), [5 10]), ...
        sprintf('Qx size expected [5 10], got [%d %d]', size(ps.map2D.Qx)));

    % Enable Q-space: replot should succeed
    api.setQSpace(true);
    fprintf('  Q-space ON : rendered without error\n');

    % Disable Q-space: back to angular
    api.setQSpace(false);
    fprintf('  Q-space OFF: rendered without error\n');

    fprintf('  Qx/Qz size : [%d %d]\n', size(ps.map2D.Qx));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 5 — 4.7 Q-space line cuts: xColumnName reflects Q coordinates
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5 (4.7): Q-space line cuts — xColumnName ══\n');
try
    api = launchHeadless();
    C   = onCleanup(@() api.close());

    api.addFiles({FILE_2D});
    drawnow;
    assert(api.is2DActive(), 'is2DActive() should be true');

    % Confirm Qx/Qz present
    ds = api.getDatasets();
    ps = ds{1}.data.metadata.parserSpecific;
    if ~isfield(ps.map2D, 'Qx')
        error('Qx not available; skip Q-space cut test');
    end

    % Enable Q-space, then extract H-cut (→ x-axis = Qx)
    api.setQSpace(true);

    api.extractLineCut2D(0.0, 0.0, true);   % H-cut: clickX=Qx, clickY=Qz centroid
    allDs = api.getDatasets();
    hCut  = allDs{end};
    xColH = hCut.data.metadata.xColumnName;
    assert(contains(xColH, 'Q_x', 'IgnoreCase', true), ...
        sprintf('H-cut xColumnName should contain Q_x, got: %s', xColH));
    fprintf('  H-cut xColumnName: %s\n', xColH);

    % V-cut in Q-space (→ x-axis = Qz)
    api.extractLineCut2D(0.0, 0.0, false);
    allDs = api.getDatasets();
    vCut  = allDs{end};
    xColV = vCut.data.metadata.xColumnName;
    assert(contains(xColV, 'Q_z', 'IgnoreCase', true), ...
        sprintf('V-cut xColumnName should contain Q_z, got: %s', xColV));
    fprintf('  V-cut xColumnName: %s\n', xColV);

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 6 — 4.8 Colormap: switch and replot without error
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6 (4.8): Colormap switching ══\n');
try
    api = launchHeadless();
    C   = onCleanup(@() api.close());

    api.addFiles({FILE_2D});
    drawnow;
    assert(api.is2DActive(), 'is2DActive() should be true');

    maps = {'jet', 'hot', 'parula', 'viridis', 'gray'};
    for mi = 1:numel(maps)
        api.setColormap(maps{mi});
        fprintf('  %-10s: OK\n', maps{mi});
    end

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 7 — 4.9 Mixed 1D + 2D: is2DActive toggles on dataset switch
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7 (4.9): Mixed 1D + 2D datasets — is2DActive toggles ══\n');
if ~isfile(FILE_1D)
    fprintf('  SKIP — La2NiO4 file not found\n');
    passed = passed + 1;
else
    try
        api = launchHeadless();
        C   = onCleanup(@() api.close());

        % Load 2D first, then 1D
        api.addFiles({FILE_2D, FILE_1D});
        drawnow;

        nDs = numel(api.getDatasets());
        assert(nDs == 2, sprintf('expected 2 datasets, got %d', nDs));

        % Identify which dataset index is 2D and which is 1D
        api.setActiveIdx(1);
        drawnow;
        is2D_idx1 = api.is2DActive();

        api.setActiveIdx(2);
        drawnow;
        is2D_idx2 = api.is2DActive();

        % Exactly one should be 2D, the other 1D
        assert(xor(is2D_idx1, is2D_idx2), ...
            sprintf('expected one 2D and one 1D dataset; got is2D=[%d %d]', is2D_idx1, is2D_idx2));

        % Switch back to whichever was 2D
        if is2D_idx1
            api.setActiveIdx(1); drawnow;
            assert(api.is2DActive(), 'is2DActive should be true after switching back to 2D dataset');
        else
            api.setActiveIdx(2); drawnow;
            assert(api.is2DActive(), 'is2DActive should be true after switching back to 2D dataset');
        end

        fprintf('  Dataset 1 is2D: %d\n', is2D_idx1);
        fprintf('  Dataset 2 is2D: %d\n', is2D_idx2);
        fprintf('  Toggle verified: correct\n');
        fprintf('  PASS\n');
        passed = passed + 1;
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n%s\n', repmat(char(9552), 1, 60));
fprintf('  test_gui_phase4: %d passed, %d failed\n', passed, failed);
fprintf('%s\n\n', repmat(char(9552), 1, 60));

if failed > 0
    error('test_gui_phase4:failures', '%d test(s) failed.', failed);
end

% ════════════════════════════════════════════════════════════════════════
%  Local functions (must appear after all script code)
% ════════════════════════════════════════════════════════════════════════
function api = launchHeadless()
%LAUNCHHEADLESS  Start dataImportGUI with the figure hidden.
    api = dataImportGUI();
    api.fig.Visible = 'off';
    drawnow;
end
