function test_styleResolution
%TEST_STYLERESOLUTION  Pure-function tests for bosonPlotter.resolveStyle.
%
%   Covers the visual-style precedence chain:
%       template < globalOverrides < ds.styleOverride < ds.channelStyles{k}
%
%   Also covers the legacy ds.color migration shim, sparse-override
%   semantics (empty fields pass through), the marker auto-cycle, and
%   user-template persistence via bosonPlotter.userTemplates.
%
%   Run standalone:  run tests/gui/test_styleResolution
%   Run via group :  runAllTests(Group="gui")

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end

    passed = 0;
    failed = 0;
    failures = {};

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: Template only — every default field is populated
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: template only ==\n');
    try
        t = styles.template('screen');
        a = bosonPlotter.resolveStyle(t);

        check('appearance is a struct',      isstruct(a));
        check('has fontName',                isfield(a, 'fontName'));
        check('has fontSize',                isfield(a, 'fontSize'));
        check('has lineWidth',               isfield(a, 'lineWidth'));
        check('has markerSize',              isfield(a, 'markerSize'));
        check('has markerShape',             isfield(a, 'markerShape'));
        check('has lineStyle',               isfield(a, 'lineStyle'));
        check('has tickDir',                 isfield(a, 'tickDir'));
        check('has boxOn',                   isfield(a, 'boxOn'));
        check('has gridAlpha',               isfield(a, 'gridAlpha'));
        check('has legendLocation',          isfield(a, 'legendLocation'));
        check('screen template fontSize matches',  a.fontSize == t.fontSize);
        check('screen template markerSize matches', a.markerSize == t.markerSize);
    catch ME
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: Global overrides win over template
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2: global overrides ==\n');
    try
        t = styles.template('screen');
        overrides = struct('lineWidth', 3.5, 'fontSize', 20);
        a = bosonPlotter.resolveStyle(t, overrides);

        check('global lineWidth applied',   a.lineWidth == 3.5);
        check('global fontSize applied',    a.fontSize == 20);
        check('untouched fields pass through (markerSize)', ...
              a.markerSize == t.markerSize);
        check('untouched fields pass through (fontName)', ...
              strcmp(a.fontName, t.fontName));
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 3: Empty fields in override are sparse (do NOT clobber)
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 3: sparse empty fields ==\n');
    try
        t = styles.template('screen');
        overrides = struct('lineWidth', 2.0, 'fontSize', [], 'markerSize', []);
        a = bosonPlotter.resolveStyle(t, overrides);

        check('populated override applied',  a.lineWidth == 2.0);
        check('empty fontSize passes through template', ...
              a.fontSize == t.fontSize);
        check('empty markerSize passes through template', ...
              a.markerSize == t.markerSize);
    catch ME
        recordCrash('TEST 3', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 4: Per-dataset override wins over global
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 4: per-dataset override ==\n');
    try
        t = styles.template('screen');
        globalO = struct('lineWidth', 2.0, 'markerSize', 5.0);
        ds = struct('styleOverride', struct('lineWidth', 4.0));

        a = bosonPlotter.resolveStyle(t, globalO, ds);

        check('ds override wins over global',    a.lineWidth == 4.0);
        check('global still applies (markerSize)', a.markerSize == 5.0);
        check('template still applies (fontSize)', a.fontSize == t.fontSize);
    catch ME
        recordCrash('TEST 4', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 5: Per-channel override wins over per-dataset
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 5: per-channel override ==\n');
    try
        t = styles.template('screen');
        ds = struct( ...
            'styleOverride', struct('lineWidth', 2.0, 'markerSize', 6), ...
            'channelStyles', {{ ...
                struct('lineWidth', 5.0), ...   % channel 1
                struct(), ...                   % channel 2 (empty)
                struct('markerShape', 's') ...  % channel 3
            }});

        a1 = bosonPlotter.resolveStyle(t, struct(), ds, 1);
        a2 = bosonPlotter.resolveStyle(t, struct(), ds, 2);
        a3 = bosonPlotter.resolveStyle(t, struct(), ds, 3);

        check('channel 1 lineWidth from channel override', a1.lineWidth == 5.0);
        check('channel 1 markerSize from ds override',     a1.markerSize == 6);
        check('channel 2 lineWidth from ds override',      a2.lineWidth == 2.0);
        check('channel 2 markerSize from ds override',     a2.markerSize == 6);
        check('channel 3 markerShape from channel override', ...
              strcmp(a3.markerShape, 's'));
        check('channel 3 lineWidth still from ds override',  a3.lineWidth == 2.0);
    catch ME
        recordCrash('TEST 5', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 6: Legacy ds.color migration shim
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 6: ds.color migration ==\n');
    try
        t = styles.template('screen');
        ds = struct('color', [0.8 0.2 0.3]);    % legacy field, no styleOverride

        a = bosonPlotter.resolveStyle(t, struct(), ds);
        check('legacy ds.color surfaces as datasetColor', ...
              isfield(a, 'datasetColor') && isequal(a.datasetColor, [0.8 0.2 0.3]));

        % When styleOverride explicitly sets it, that wins
        ds2 = struct('color', [0.8 0.2 0.3], ...
                     'styleOverride', struct('datasetColor', [0.1 0.9 0.1]));
        a2 = bosonPlotter.resolveStyle(t, struct(), ds2);
        check('explicit styleOverride wins over legacy color', ...
              isequal(a2.datasetColor, [0.1 0.9 0.1]));
    catch ME
        recordCrash('TEST 6', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 7: Every built-in template resolves successfully
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 7: all built-in templates ==\n');
    try
        names = {'screen','aps','aps_double','nature','nature_double', ...
                 'thesis','presentation','poster'};
        for i = 1:numel(names)
            t = styles.template(names{i});
            a = bosonPlotter.resolveStyle(t);
            check(sprintf('%s resolves + has markerShape', names{i}), ...
                  isfield(a, 'markerShape') && ~isempty(a.markerShape));
            check(sprintf('%s resolves + has lineStyle', names{i}), ...
                  isfield(a, 'lineStyle') && ~isempty(a.lineStyle));
            check(sprintf('%s fontSize is positive', names{i}), ...
                  a.fontSize > 0);
            check(sprintf('%s lineWidth is positive', names{i}), ...
                  a.lineWidth > 0);
        end
    catch ME
        recordCrash('TEST 7', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 8: User templates — save / list / load / delete round-trip
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 8: user templates persistence ==\n');
    try
        testName = 'test_style_resolution_roundtrip';

        % Clean slate — ignore if not present
        try bosonPlotter.userTemplates.delete(testName); catch, end

        tpl = styles.template('aps');
        tpl.lineWidth = 42;   % a sentinel value we can recognise
        bosonPlotter.userTemplates.save(testName, tpl);

        check('saved template appears in list()', ...
              any(strcmp(bosonPlotter.userTemplates.list(), testName)));
        check('hasName returns true for saved template', ...
              bosonPlotter.userTemplates.hasName(testName));

        loaded = bosonPlotter.userTemplates.load(testName);
        check('loaded template round-trips lineWidth', loaded.lineWidth == 42);
        check('loaded template retains displayName',  isfield(loaded, 'displayName'));

        bosonPlotter.userTemplates.delete(testName);
        check('deleted template gone from list()', ...
              ~any(strcmp(bosonPlotter.userTemplates.list(), testName)));
        check('hasName returns false after delete', ...
              ~bosonPlotter.userTemplates.hasName(testName));
    catch ME
        recordCrash('TEST 8', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 9: User template sanitisation
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 9: name sanitisation ==\n');
    try
        key = bosonPlotter.userTemplates.sanitise('My Paper Style!');
        check('spaces and punctuation become underscores', ...
              strcmp(key, 'My_Paper_Style_'));

        key2 = bosonPlotter.userTemplates.sanitise('123invalid');
        check('leading digit gets u_ prefix', ...
              strcmp(key2, 'u_123invalid'));

        key3 = bosonPlotter.userTemplates.sanitise('already_valid');
        check('valid name passes through', ...
              strcmp(key3, 'already_valid'));
    catch ME
        recordCrash('TEST 9', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 68));
    fprintf('  test_styleResolution: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_styleResolution:failed', '%d test(s) failed', failed);
    end
    fprintf('%s\n', repmat('=', 1, 68));

    % ── Nested helpers (share parent workspace) ─────────────────────
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
