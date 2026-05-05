function test_bp_smoke
%TEST_BP_SMOKE  Full interaction smoke test for BosonPlotter.
%
%   Loads real data, fires every reachable button callback, exercises key
%   interaction sequences, and captures exportapp screenshots at major
%   steps. Uses SmokeRunner for all interactions — any uncaught error in
%   a callback registers as a failure rather than aborting the suite.
%
%   This test catches bugs that wiring tests miss: callbacks that crash
%   with real data, uninitialized variables, missing icon files, and
%   broken interaction flows.
%
%   Run:  runAllTests(Group="smoke")
%   Or:   run tests/smoke/test_bp_smoke

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end

    ROOT  = rootDir;
    XRDML = fullfile(ROOT, '+test_datasets', 'XRDML', 'La2NiO4_1.xrdml');
    VSM   = fullfile(ROOT, '+test_datasets', 'QuantumDesign', 'EDP136_Perp_StrawNew.dat');
    assert(isfile(XRDML) && isfile(VSM), 'Test data files not found');

    fprintf('\n=== test_bp_smoke ===\n');

    % ── Launch BosonPlotter headless ────────────────────────────────────
    api = BosonPlotter('Visible', 'off');
    cleanupApi = onCleanup(@() safeClose(api));
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
    %  A. Toolbar buttons
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── A. Toolbar buttons ──\n');

    sr.fireButton('Zoom In');
    sr.fireButton('Zoom Out');
    sr.fireButton('Reset View');

    % ════════════════════════════════════════════════════════════════════
    %  B. Dataset management
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── B. Dataset management ──\n');

    api.setActiveIdx(1); drawnow;
    api.setActiveIdx(2); drawnow;
    sr.captureSnapshot('bp_02_dataset_switch');

    % ════════════════════════════════════════════════════════════════════
    %  C. Plot controls — dropdowns and checkboxes
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
    sr.fireButton('Apply');
    sr.fireButton('Undo');
    sr.captureSnapshot('bp_04_corrections');

    % ════════════════════════════════════════════════════════════════════
    %  E. Keyboard shortcuts
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── E. Keyboard shortcuts ──\n');

    sr.pressKey('z');
    sr.pressKey('r');
    sr.pressKey('l');
    sr.pressKey('g');

    sr.captureSnapshot('bp_05_after_keys');

    % ════════════════════════════════════════════════════════════════════
    %  F. Export operations (non-destructive)
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── F. Export (non-destructive) ──\n');

    sr.fireButton('Copy Plot');
    sr.captureSnapshot('bp_06_after_copy');

    % ════════════════════════════════════════════════════════════════════
    %  G. Popup windows (open + auto-close)
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── G. Popup windows ──\n');

    % Settings dialog
    sr.startDialogAutoClose(Timeout=3);
    sr.fireButton('Settings');
    sr.stopDialogAutoClose();
    sr.closePopups();

    sr.captureSnapshot('bp_07_after_popups');

    % ════════════════════════════════════════════════════════════════════
    %  H. Theme toggle
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── H. Theme toggle ──\n');

    themeBtn = findall(api.fig, 'Type', 'uibutton', 'Tag', 'themeToggle');
    if ~isempty(themeBtn)
        sr.fireButton(themeBtn(1).Text);
        sr.captureSnapshot('bp_08_theme_toggled');
        sr.fireButton(themeBtn(1).Text);
    else
        fprintf('  SKIP  theme toggle button not found by Tag\n');
    end

    % ════════════════════════════════════════════════════════════════════
    %  I. Sequence: load → correct → plot → reset
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n── I. Full sequence ──\n');

    api.setActiveIdx(1); drawnow;
    sr.runSequence({
        {'key', 'r'}
        {'snap', 'bp_09_sequence_start'}
        {'key', 'z'}
        {'key', 'r'}
        {'snap', 'bp_10_sequence_end'}
    });

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
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
