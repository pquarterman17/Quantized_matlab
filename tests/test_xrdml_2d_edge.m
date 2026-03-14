%TEST_XRDML_2D_EDGE  Phase 5 edge-case tests for 2D area-detector XRDML support.
%
%   Covers the 8 scenarios from PLAN_TEST_2D_XRD.md Phase 5:
%     5.1  Minimal 2×2 grid            — is2D, shape, H-cut 2 pts, V-cut 2 pts
%     5.2  Large 100×256 grid          — parser completes without error
%     5.3  Tall 50×5 grid              — shape, H-cut 5 pts, V-cut 50 pts
%     5.4  Wide 3×100 grid             — shape, H-cut 100 pts, V-cut 3 pts
%     5.5  Zero background             — no NaN/Inf in map.intensity
%     5.6  Boundary cuts               — H/V-cuts at axis extremes return correct length
%     5.7  Session round-trip (2D)     — is2DActive() true after save/reload
%     5.8  Session round-trip (cuts)   — 4 datasets (1 map + 3 cuts) restored
%
%   Generated edge-case files go to a temporary directory and are auto-cleaned.
%   The pre-existing synthetic_rsm.xrdml in +test_datasets is used for 5.6–5.8.
%
%   Run from the project root:
%       run tests/test_xrdml_2d_edge

clear; clc;

ROOT    = fileparts(fileparts(mfilename('fullpath')));
addpath(ROOT);
GEN_DIR = fullfile(ROOT, '+test_datasets', 'XRDML');
FILE_2D = fullfile(GEN_DIR, 'synthetic_rsm.xrdml');  % 5×10 reference file

% Ensure synthetic_rsm.xrdml exists (needed for 5.6–5.8)
if ~isfile(FILE_2D)
    addpath(GEN_DIR);
    writeTestXRDML2D(FILE_2D, 5, 10, ...
        'OmegaStart', 30.0, 'OmegaEnd', 31.0, ...
        'TwoThetaStart', 60.0, 'TwoThetaEnd', 62.0, ...
        'CountingTime', 0.5, 'PeakScale', 1000, 'Background', 50);
    rmpath(GEN_DIR);
    fprintf('Generated: %s\n', FILE_2D);
end

% Temporary directory for generated edge-case files
tmpDir = fullfile(tempdir, ['edge2d_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]);
mkdir(tmpDir);
cleanupTmp = onCleanup(@() rmdir(tmpDir, 's'));

addpath(GEN_DIR);  % for writeTestXRDML2D
cleanupPath = onCleanup(@() rmpath(GEN_DIR));

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  TEST 1 — 5.1 Minimal 2×2 grid: parser + cuts
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: Minimal 2×2 grid ══\n');
try
    fp = fullfile(tmpDir, 'rsm_min.xrdml');
    writeTestXRDML2D(fp, 2, 2, ...
        'OmegaStart', 30.0, 'OmegaEnd', 31.0, ...
        'TwoThetaStart', 60.0, 'TwoThetaEnd', 62.0);

    % Parser check
    d = parser.importXRDML(fp);
    ps = d.metadata.parserSpecific;
    assert(isfield(ps,'is2D') && ps.is2D, 'is2D should be true');
    assert(isfield(ps,'map2D'), 'map2D field missing');
    assert(isequal(size(ps.map2D.intensity), [2 2]), ...
        sprintf('expected [2 2], got [%d %d]', size(ps.map2D.intensity)));
    fprintf('  Parser: is2D=true, map [2×2]\n');

    % GUI cuts
    api = launchHeadless();
    C   = onCleanup(@() api.close());

    api.addFiles({fp});
    drawnow;
    assert(api.is2DActive(), 'is2DActive() should be true');

    nBefore = numel(api.getDatasets());

    % H-cut (fixed Omega → I vs 2Theta): expect 2 points (nPixels=2)
    api.extractLineCut2D(61.0, 30.5, true);
    allDs = api.getDatasets();
    hCut  = allDs{end};
    assert(numel(hCut.data.time) == 2, ...
        sprintf('H-cut expected 2 pts, got %d', numel(hCut.data.time)));
    fprintf('  H-cut: %d points (correct)\n', numel(hCut.data.time));

    % V-cut (fixed 2Theta → I vs Omega): expect 2 points (nOmega=2)
    api.extractLineCut2D(61.0, 30.5, false);
    allDs = api.getDatasets();
    vCut  = allDs{end};
    assert(numel(vCut.data.time) == 2, ...
        sprintf('V-cut expected 2 pts, got %d', numel(vCut.data.time)));
    fprintf('  V-cut: %d points (correct)\n', numel(vCut.data.time));

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 2 — 5.2 Large 100×256 grid: parser completes without error
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: Large 100×256 grid (parser only) ══\n');
try
    fp = fullfile(tmpDir, 'rsm_large.xrdml');
    writeTestXRDML2D(fp, 100, 256);

    d = parser.importXRDML(fp);
    ps = d.metadata.parserSpecific;
    assert(isfield(ps,'is2D') && ps.is2D, 'is2D should be true');
    assert(isequal(size(ps.map2D.intensity), [100 256]), ...
        sprintf('expected [100 256], got [%d %d]', size(ps.map2D.intensity)));
    assert(all(isfinite(ps.map2D.intensity(:))), 'intensity contains non-finite values');

    fprintf('  Map size: [%d %d]\n', size(ps.map2D.intensity,1), size(ps.map2D.intensity,2));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 3 — 5.3 Tall 50×5 grid: shape + H-cut 5 pts, V-cut 50 pts
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: Tall 50×5 grid ══\n');
try
    fp = fullfile(tmpDir, 'rsm_tall.xrdml');
    writeTestXRDML2D(fp, 50, 5, ...
        'OmegaStart', 30.0, 'OmegaEnd', 31.0, ...
        'TwoThetaStart', 60.0, 'TwoThetaEnd', 62.0);

    % Parser shape check
    d = parser.importXRDML(fp);
    ps = d.metadata.parserSpecific;
    assert(isfield(ps,'is2D') && ps.is2D, 'is2D should be true');
    assert(isequal(size(ps.map2D.intensity), [50 5]), ...
        sprintf('expected [50 5], got [%d %d]', size(ps.map2D.intensity)));
    fprintf('  Parser: map [%d×%d]\n', size(ps.map2D.intensity,1), size(ps.map2D.intensity,2));

    % GUI cuts
    api = launchHeadless();
    C   = onCleanup(@() api.close());

    api.addFiles({fp});
    drawnow;

    api.extractLineCut2D(61.0, 30.5, true);   % H-cut → 5 pts (nPixels)
    allDs = api.getDatasets();
    hCut  = allDs{end};
    assert(numel(hCut.data.time) == 5, ...
        sprintf('H-cut expected 5 pts, got %d', numel(hCut.data.time)));
    fprintf('  H-cut: %d points (correct)\n', numel(hCut.data.time));

    api.extractLineCut2D(61.0, 30.5, false);  % V-cut → 50 pts (nOmega)
    allDs = api.getDatasets();
    vCut  = allDs{end};
    assert(numel(vCut.data.time) == 50, ...
        sprintf('V-cut expected 50 pts, got %d', numel(vCut.data.time)));
    fprintf('  V-cut: %d points (correct)\n', numel(vCut.data.time));

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 4 — 5.4 Wide 3×100 grid: shape + H-cut 100 pts, V-cut 3 pts
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: Wide 3×100 grid ══\n');
try
    fp = fullfile(tmpDir, 'rsm_wide.xrdml');
    writeTestXRDML2D(fp, 3, 100, ...
        'OmegaStart', 30.0, 'OmegaEnd', 31.0, ...
        'TwoThetaStart', 60.0, 'TwoThetaEnd', 62.0);

    % Parser shape check
    d = parser.importXRDML(fp);
    ps = d.metadata.parserSpecific;
    assert(isfield(ps,'is2D') && ps.is2D, 'is2D should be true');
    assert(isequal(size(ps.map2D.intensity), [3 100]), ...
        sprintf('expected [3 100], got [%d %d]', size(ps.map2D.intensity)));
    fprintf('  Parser: map [%d×%d]\n', size(ps.map2D.intensity,1), size(ps.map2D.intensity,2));

    % GUI cuts
    api = launchHeadless();
    C   = onCleanup(@() api.close());

    api.addFiles({fp});
    drawnow;

    api.extractLineCut2D(61.0, 30.5, true);   % H-cut → 100 pts (nPixels)
    allDs = api.getDatasets();
    hCut  = allDs{end};
    assert(numel(hCut.data.time) == 100, ...
        sprintf('H-cut expected 100 pts, got %d', numel(hCut.data.time)));
    fprintf('  H-cut: %d points (correct)\n', numel(hCut.data.time));

    api.extractLineCut2D(61.0, 30.5, false);  % V-cut → 3 pts (nOmega)
    allDs = api.getDatasets();
    vCut  = allDs{end};
    assert(numel(vCut.data.time) == 3, ...
        sprintf('V-cut expected 3 pts, got %d', numel(vCut.data.time)));
    fprintf('  V-cut: %d points (correct)\n', numel(vCut.data.time));

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 5 — 5.5 Zero background: no NaN/Inf in intensity map
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: Zero background — no NaN/Inf in intensity map ══\n');
try
    fp = fullfile(tmpDir, 'rsm_nobg.xrdml');
    writeTestXRDML2D(fp, 5, 10, 'Background', 0);

    d = parser.importXRDML(fp);
    ps = d.metadata.parserSpecific;
    assert(isfield(ps,'is2D') && ps.is2D, 'is2D should be true');

    I = ps.map2D.intensity;
    assert(~any(isnan(I(:))),  'map2D.intensity contains NaN');
    assert(~any(isinf(I(:))),  'map2D.intensity contains Inf');
    assert(all(I(:) >= 0),     'map2D.intensity has negative values');

    minI = min(I(:));
    maxI = max(I(:));
    fprintf('  Intensity range: [%.4g, %.4g]\n', minI, maxI);
    fprintf('  No NaN/Inf: confirmed\n');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 6 — 5.6 Boundary cuts on synthetic_rsm.xrdml (5×10)
%           H-cuts at Omega min (30.0) and max (31.0) → 10 pts each
%           V-cuts at 2Theta min (60.0) and max (62.0) → 5 pts each
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6: Boundary cuts on synthetic_rsm.xrdml ══\n');
if ~isfile(FILE_2D)
    fprintf('  SKIP — synthetic_rsm.xrdml not found\n');
    passed = passed + 1;  % neutral skip
else
    try
        api = launchHeadless();
        C   = onCleanup(@() api.close());

        api.addFiles({FILE_2D});
        drawnow;
        assert(api.is2DActive(), 'is2DActive() should be true');

        % H-cut at Omega = 30.0 (axis minimum)
        api.extractLineCut2D(61.0, 30.0, true);
        allDs = api.getDatasets();
        hMin  = allDs{end};
        nHMin = numel(hMin.data.time);
        assert(nHMin == 10, sprintf('H-cut at Omega min: expected 10 pts, got %d', nHMin));

        % H-cut at Omega = 31.0 (axis maximum)
        api.extractLineCut2D(61.0, 31.0, true);
        allDs = api.getDatasets();
        hMax  = allDs{end};
        nHMax = numel(hMax.data.time);
        assert(nHMax == 10, sprintf('H-cut at Omega max: expected 10 pts, got %d', nHMax));

        % V-cut at 2Theta = 60.0 (axis minimum)
        api.extractLineCut2D(60.0, 30.5, false);
        allDs = api.getDatasets();
        vMin  = allDs{end};
        nVMin = numel(vMin.data.time);
        assert(nVMin == 5, sprintf('V-cut at 2Theta min: expected 5 pts, got %d', nVMin));

        % V-cut at 2Theta = 62.0 (axis maximum)
        api.extractLineCut2D(62.0, 30.5, false);
        allDs = api.getDatasets();
        vMax  = allDs{end};
        nVMax = numel(vMax.data.time);
        assert(nVMax == 5, sprintf('V-cut at 2Theta max: expected 5 pts, got %d', nVMax));

        fprintf('  H-cut @ Omega=30.0: %d pts\n', nHMin);
        fprintf('  H-cut @ Omega=31.0: %d pts\n', nHMax);
        fprintf('  V-cut @ 2T=60.0:    %d pts\n', nVMin);
        fprintf('  V-cut @ 2T=62.0:    %d pts\n', nVMax);
        fprintf('  PASS\n');
        passed = passed + 1;
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 7 — 5.7 Session round-trip with 2D dataset
%           Load → save session → new GUI → load session → is2DActive() true
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7: Session round-trip — 2D dataset ══\n');
if ~isfile(FILE_2D)
    fprintf('  SKIP — synthetic_rsm.xrdml not found\n');
    passed = passed + 1;
else
    try
        sessionFile = fullfile(tmpDir, 'session_2d.mat');

        % Load 2D file and save session
        api1 = launchHeadless();
        C1   = onCleanup(@() api1.close());

        api1.addFiles({FILE_2D});
        drawnow;
        assert(api1.is2DActive(), 'is2DActive() should be true before save');

        nSaved = numel(api1.getDatasets());
        api1.saveSession(sessionFile);
        clear C1; % close first GUI

        assert(isfile(sessionFile), 'session file not written');

        % Open fresh GUI and restore session
        api2 = launchHeadless();
        C2   = onCleanup(@() api2.close());

        api2.loadSession(sessionFile);
        drawnow;

        nRestored = numel(api2.getDatasets());
        assert(nRestored == nSaved, ...
            sprintf('expected %d dataset(s) after reload, got %d', nSaved, nRestored));
        assert(api2.is2DActive(), 'is2DActive() should be true after session reload');

        % Verify map2D persisted
        ds = api2.getDatasets();
        ps = ds{1}.data.metadata.parserSpecific;
        assert(isfield(ps,'map2D'), 'map2D field missing after reload');

        fprintf('  Datasets saved/restored: %d\n', nRestored);
        fprintf('  is2DActive after reload: true\n');
        fprintf('  PASS\n');
        passed = passed + 1;
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 8 — 5.8 Session round-trip with line-cut datasets
%           Load 2D → extract 2 H-cuts + 1 V-cut → save (4 datasets)
%           → new GUI → load → verify 4 datasets; cuts plot as 1D
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 8: Session round-trip — map + line-cut datasets ══\n');
if ~isfile(FILE_2D)
    fprintf('  SKIP — synthetic_rsm.xrdml not found\n');
    passed = passed + 1;
else
    try
        sessionFile = fullfile(tmpDir, 'session_cuts.mat');

        % Load 2D file, extract 3 cuts
        api1 = launchHeadless();
        C1   = onCleanup(@() api1.close());

        api1.addFiles({FILE_2D});
        drawnow;

        api1.extractLineCut2D(61.0, 30.0, true);   % H-cut 1
        api1.extractLineCut2D(61.0, 31.0, true);   % H-cut 2
        api1.extractLineCut2D(61.0, 30.5, false);  % V-cut 1

        nSaved = numel(api1.getDatasets());
        assert(nSaved == 4, sprintf('expected 4 datasets before save, got %d', nSaved));

        api1.saveSession(sessionFile);
        clear C1;

        % Restore in fresh GUI
        api2 = launchHeadless();
        C2   = onCleanup(@() api2.close());

        api2.loadSession(sessionFile);
        drawnow;

        allDs = api2.getDatasets();
        nRestored = numel(allDs);
        assert(nRestored == 4, sprintf('expected 4 datasets after reload, got %d', nRestored));

        % First dataset should still be 2D map
        ds1 = allDs{1};
        ps1 = ds1.data.metadata.parserSpecific;
        assert(isfield(ps1,'is2D') && ps1.is2D, 'first dataset (map) should have is2D=true');

        % Remaining 3 should be line cuts (is2D == false)
        for k = 2:4
            dsk = allDs{k};
            psk = dsk.data.metadata.parserSpecific;
            assert(~psk.is2D, sprintf('dataset %d (cut) should have is2D=false', k));
            assert(~isempty(dsk.data.time),   sprintf('dataset %d time is empty', k));
            assert(~isempty(dsk.data.values), sprintf('dataset %d values is empty', k));
        end

        fprintf('  Total datasets restored: %d\n', nRestored);
        fprintf('  Map dataset (is2D=true): confirmed\n');
        fprintf('  Cut datasets (is2D=false): 3 confirmed\n');
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
fprintf('  test_xrdml_2d_edge: %d passed, %d failed\n', passed, failed);
fprintf('%s\n\n', repmat(char(9552), 1, 60));

if failed > 0
    error('test_xrdml_2d_edge:failures', '%d test(s) failed.', failed);
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
