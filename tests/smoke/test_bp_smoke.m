function test_bp_smoke
%TEST_BP_SMOKE  Full interaction smoke test for BosonPlotter.
%
%   Loads real data, fires every reachable button callback, exercises
%   interaction sequences, and captures exportapp screenshots at major
%   steps. Uses SmokeRunner — any uncaught error in a callback registers
%   as a failure rather than aborting the suite.
%
%   Run:  runAllTests(Group="smoke")
%   Or:   run tests/smoke/test_bp_smoke

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    addpath(rootDir);
    addpath(fullfile(rootDir, 'tests', 'smoke'));

    ROOT  = rootDir;
    XRDML = fullfile(ROOT, '+test_datasets', 'XRDML', 'La2NiO4_1.xrdml');
    VSM   = fullfile(ROOT, '+test_datasets', 'QuantumDesign', 'EDP136_Perp_StrawNew.dat');
    assert(isfile(XRDML) && isfile(VSM), 'Test data files not found');

    isBatch = batchStartupOptionUsed;

    fprintf('\n=== test_bp_smoke ===\n');

    % ── Launch BosonPlotter headless ────────────────────────────────────
    api = BosonPlotter('Visible', 'off');
    cleanupApi = onCleanup(@() safeClose(api)); %#ok<NASGU>
    drawnow;

    sr = SmokeRunner(api.fig);

    % ── Load test data ──────────────────────────────────────────────────
    fprintf('\n── Loading test data ──\n');
    api.addFiles({XRDML, VSM});
    drawnow;
    nDS = numel(api.getDatasets());
    fprintf('  Loaded %d datasets\n', nDS);
    assert(nDS == 2, 'Failed to load both test files');

    sr.captureSnapshot('bp_01_after_load');

    % ════════════════════════════════════════════════════════════════════
    %  A. Toolbar buttons (icon-only — find by Tooltip)
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── A. Toolbar buttons ──\n');

    sr.fireButtonByTag('zoomIn');
    sr.fireButtonByTag('zoomOut');
    sr.fireButtonByTag('autoscale');

    % ════════════════════════════════════════════════════════════════════
    %  B. Dataset management
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── B. Dataset management ──\n');

    api.setActiveIdx(1); drawnow;
    api.setActiveIdx(2); drawnow;
    sr.captureSnapshot('bp_02_dataset_switch');

    % ════════════════════════════════════════════════════════════════════
    %  C. Plot controls — dropdowns
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── C. Plot controls ──\n');

    sr.setDropdown('Linear', 'Log');
    sr.captureSnapshot('bp_03_log_scale');
    sr.setDropdown('Log', 'Linear');

    % ════════════════════════════════════════════════════════════════════
    %  D. Corrections panel buttons
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── D. Corrections panel ──\n');

    api.setActiveIdx(2); drawnow;  % VSM data for corrections

    % "Apply" opens a uiconfirm in -batch mode — skip if in batch
    if ~isBatch
        sr.fireButton('Apply');
        sr.fireButton('Undo');
    else
        fprintf('  SKIP  Apply/Undo (uiconfirm not supported in -batch)\n');
    end
    sr.captureSnapshot('bp_04_corrections');

    % ════════════════════════════════════════════════════════════════════
    %  E. Keyboard shortcuts
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── E. Keyboard shortcuts ──\n');

    % WindowKeyPressFcn may be empty in -batch mode
    if ~isBatch
        sr.pressKey('z');
        sr.pressKey('r');
        sr.pressKey('l');
        sr.pressKey('g');
    else
        fprintf('  SKIP  keyboard shortcuts (WindowKeyPressFcn empty in -batch)\n');
    end

    sr.captureSnapshot('bp_05_after_keys');

    % ════════════════════════════════════════════════════════════════════
    %  F. Export operations (non-destructive)
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── F. Export (non-destructive) ──\n');

    sr.fireButton('Copy Plot');
    sr.captureSnapshot('bp_06_after_copy');

    % ════════════════════════════════════════════════════════════════════
    %  G. Theme toggle
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── G. Theme toggle ──\n');

    % Theme toggle may recreate widgets. Fire via Tag to avoid
    % stale handle issues — and catch the "deleted object" crash.
    sr.fireButtonByTag('themeToggle');
    drawnow;
    sr.captureSnapshot('bp_07_theme_toggled');

    % Toggle back — re-find since the button text changed
    sr.fireButtonByTag('themeToggle');
    drawnow;

    % ════════════════════════════════════════════════════════════════════
    %  H. File list panel buttons
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── H. File list panel ──\n');

    sr.fireButton('Select All');
    sr.fireButton('Remove Selected');
    sr.captureSnapshot('bp_08_after_remove');

    % Re-add files for remaining tests
    api.addFiles({XRDML}); drawnow;

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    sr.captureSnapshot('bp_09_final');
    sr.summary();
    sr.assertAllPassed();

    function safeClose(a)
        try
            if isfield(a, 'close')
                a.close();
            end
        catch
        end
    end
end
