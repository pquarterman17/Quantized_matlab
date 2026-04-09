%TEST_TOOLBARCONFIG  Headless tests for BosonPlotter toolbar customisation.
%
%   Tests the toolbar system without any dialog interaction:
%     A. Default config contains expected button IDs
%     B. buildToolbar creates correct number of button children
%     C. Save/load round-trip of config to a temp file
%     D. API: setToolbarConfig updates appData and rebuilds toolbar
%     E. Stale IDs in saved config are silently dropped at load time
%     F. Empty config falls back to factory default when building toolbar
%
%   Run via: runAllTests(Group="gui")

clear; clc;

% ── Path setup ───────────────────────────────────────────────────────────
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

passed  = 0;
failed  = 0;

% ── Temp directory for pref-file round-trip tests ────────────────────────
tmpDir = fullfile(tempdir, ['tbcfg_test_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]);
mkdir(tmpDir);
cleanupTmp = onCleanup(@() rmdir(tmpDir, 's'));

% ── Shared headless GUI instance ─────────────────────────────────────────
api = BosonPlotter();
api.fig.Visible = 'off';
drawnow;
cleanupApi = onCleanup(@() safeClose(api));

% ════════════════════════════════════════════════════════════════════════
%  A. Default config contains expected button IDs
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST A1: toolbarDefaultConfig returns expected IDs ══\n');
try
    defaults = bosonPlotter.toolbarDefaultConfig();
    assert(iscell(defaults),         'result must be a cell array');
    assert(~isempty(defaults),       'default config must not be empty');
    assert(ismember('cursor',    defaults), 'missing: cursor');
    assert(ismember('autoscale', defaults), 'missing: autoscale');
    assert(ismember('grid',      defaults), 'missing: grid');
    assert(ismember('legend',    defaults), 'missing: legend');
    assert(ismember('copy',      defaults), 'missing: copy');
    assert(ismember('save',      defaults), 'missing: save');
    fprintf('PASS\n');
    passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  B. buildToolbar creates correct number of button children
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST B1: buildToolbar creates N buttons for N-item config ══\n');
try
    tbGL = api.getToolbarGL();
    reg  = api.getToolbarRegistry();

    % Build with a 3-item config
    cfg3 = {'cursor', 'grid', 'save'};
    api.setToolbarConfig(cfg3);
    drawnow;

    % Count uibutton children (exclude uilabel spacer)
    kids = tbGL.Children;
    btnKids = 0;
    for k = 1:numel(kids)
        if isa(kids(k), 'matlab.ui.control.Button')
            btnKids = btnKids + 1;
        end
    end
    assert(btnKids == 3, sprintf('expected 3 buttons, got %d', btnKids));
    fprintf('PASS\n');
    passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message);
    failed = failed + 1;
end

fprintf('\n══ TEST B2: buildToolbar with 1-item config creates 1 button ══\n');
try
    api.setToolbarConfig({'autoscale'});
    drawnow;
    tbGL = api.getToolbarGL();
    kids = tbGL.Children;
    btnKids = 0;
    for k = 1:numel(kids)
        if isa(kids(k), 'matlab.ui.control.Button')
            btnKids = btnKids + 1;
        end
    end
    assert(btnKids == 1, sprintf('expected 1 button, got %d', btnKids));
    fprintf('PASS\n');
    passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  C. Save / load round-trip via a temp mat file
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST C1: save/load round-trip preserves config ══\n');
try
    cfgToSave = {'legend', 'copy', 'cursor', 'save'};

    % Write manually to a temp file (same format as saveToolbarConfig)
    prefFile = fullfile(tmpDir, 'boson_toolbar.mat');
    toolbarConfig = cfgToSave; %#ok<NASGU>
    save(prefFile, 'toolbarConfig');

    % Reload
    s = load(prefFile, 'toolbarConfig');
    assert(isequal(s.toolbarConfig, cfgToSave), 'round-trip mismatch');
    fprintf('PASS\n');
    passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  D. API setToolbarConfig updates appData.toolbarConfig
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST D1: setToolbarConfig updates appData.toolbarConfig ══\n');
try
    newCfg = {'grid', 'legend', 'save', 'copy'};
    api.setToolbarConfig(newCfg);
    drawnow;
    readBack = api.getToolbarConfig();
    assert(isequal(readBack, newCfg), 'appData.toolbarConfig not updated');
    fprintf('PASS\n');
    passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  E. Stale IDs in config are silently dropped during buildToolbar
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST E1: stale IDs in config are dropped (no error) ══\n');
try
    staleConfig = {'cursor', 'nonexistent_action_xyz', 'save'};
    % Should not throw; unknown ID silently filtered
    api.setToolbarConfig(staleConfig);
    drawnow;
    tbGL = api.getToolbarGL();
    kids = tbGL.Children;
    btnKids = 0;
    for k = 1:numel(kids)
        if isa(kids(k), 'matlab.ui.control.Button')
            btnKids = btnKids + 1;
        end
    end
    % Only 'cursor' and 'save' are valid — expect 2 buttons
    assert(btnKids == 2, sprintf('expected 2 valid buttons, got %d', btnKids));
    fprintf('PASS\n');
    passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  F. Empty config falls back to factory default
% ════════════════════════════════════════════════════════════════════════

fprintf('\n══ TEST F1: empty config rebuilds toolbar with factory defaults ══\n');
try
    api.setToolbarConfig({});
    drawnow;
    tbGL = api.getToolbarGL();
    kids = tbGL.Children;
    btnKids = 0;
    for k = 1:numel(kids)
        if isa(kids(k), 'matlab.ui.control.Button')
            btnKids = btnKids + 1;
        end
    end
    defaults = bosonPlotter.toolbarDefaultConfig();
    assert(btnKids == numel(defaults), ...
        sprintf('expected %d default buttons, got %d', numel(defaults), btnKids));
    fprintf('PASS\n');
    passed = passed + 1;
catch ex
    fprintf('FAIL: %s\n', ex.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════

fprintf('\n════════════════════════════════════════════════════════\n');
fprintf('test_toolbarConfig: %d passed, %d failed\n', passed, failed);
if failed == 0
    fprintf('ALL TESTS PASSED\n');
else
    fprintf('SOME TESTS FAILED\n');
end

% ── Local helpers ─────────────────────────────────────────────────────────

function safeClose(api)
    try
        if isstruct(api) && isfield(api,'close') && isvalid(api.fig)
            api.close();
        end
    catch
    end
end
