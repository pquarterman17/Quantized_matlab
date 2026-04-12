function results = test_templateEngine()
%TEST_TEMPLATEENGINE  Tests for the +templates/ package.
%
%   results = test_templateEngine()
%
%   Covers: TemplateEngine (fingerprint, match, apply, save/load, delete),
%   shipped default templates, and the JSON round-trip contract.
%
%   Run via:  runAllTests(Group="templates")

    results = struct('passed', 0, 'failed', 0, 'errors', {{}});
    fprintf('\n=== test_templateEngine ===\n');

    % ────────────────────────────────────────────────────────────────
    %  Test 1: Fingerprint is deterministic
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 1: Fingerprint determinism ==\n');
    try
        data1 = makeTabularData({'Field', 'Moment'}, {'Oe', 'emu'}, 'importQDVSM');
        fp1 = templates.TemplateEngine.fingerprint(data1);
        fp2 = templates.TemplateEngine.fingerprint(data1);
        check('fingerprint is deterministic', strcmp(fp1, fp2));
        check('fingerprint is 8-char hex', numel(fp1) == 8 && ~isempty(regexp(fp1, '^[0-9A-Fa-f]{8}$', 'once')));

        % Different data → different fingerprint
        data2 = makeTabularData({'Temp', 'Moment'}, {'K', 'emu'}, 'importQDVSM');
        fp3 = templates.TemplateEngine.fingerprint(data2);
        check('different labels → different fingerprint', ~strcmp(fp1, fp3));
    catch ME
        recordError('TEST 1', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 2: Fingerprint is sort-invariant
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 2: Fingerprint sort invariance ==\n');
    try
        dataA = makeTabularData({'Alpha', 'Beta'}, {'', ''}, 'importCSV');
        dataB = makeTabularData({'Beta', 'Alpha'}, {'', ''}, 'importCSV');
        fpA = templates.TemplateEngine.fingerprint(dataA);
        fpB = templates.TemplateEngine.fingerprint(dataB);
        check('fingerprint is order-invariant', strcmp(fpA, fpB));
    catch ME
        recordError('TEST 2', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 3: loadAll returns shipped defaults
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 3: loadAll returns shipped defaults ==\n');
    try
        all = templates.TemplateEngine.loadAll(ForceReload=true);
        check('loadAll returns cell array', iscell(all));
        check('loadAll finds shipped templates', numel(all) >= 4);

        % Check a known template exists
        names = cellfun(@(t) t.name, all, 'UniformOutput', false);
        check('QD VSM — M vs H shipped', any(contains(names, 'M vs H')));
        check('SEM — FEI shipped', any(contains(names, 'FEI')));
    catch ME
        recordError('TEST 3', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 4: Match cascade — parser type match
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 4: Match cascade — parser type ==\n');
    try
        data = makeTabularData({'Field', 'Moment', 'Std Err'}, ...
            {'Oe', 'emu', 'emu'}, 'importQDVSM');
        data.metadata.parserSpecific.instrument = 'VSM';

        [tmpl, conf] = templates.TemplateEngine.match(data, Type='tabular');
        check('match returns a template', ~isempty(tmpl));
        check('confidence > 0', conf > 0);
        check('matched template has a name', isfield(tmpl, 'name') && ~isempty(tmpl.name));
        fprintf('  Matched: "%s" at confidence %.2f\n', tmpl.name, conf);
    catch ME
        recordError('TEST 4', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 5: Apply tabular overrides — labels and units
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 5: Apply tabular overrides ==\n');
    try
        data = makeTabularData({'Ch1', 'Ch2'}, {'V', 'A'}, 'importCSV');
        tmpl = struct();
        tmpl.type = 'tabular';
        tmpl.overrides = struct();
        tmpl.overrides.labels = struct('x0', 'Resistance', 'x1', 'Current');
        tmpl.overrides.units  = struct('x0', 'Ohm', 'x1', 'mA');

        result = templates.TemplateEngine.apply(data, tmpl);
        check('label override applied (col 1)', strcmp(result.labels{1}, 'Resistance'));
        check('label override applied (col 2)', strcmp(result.labels{2}, 'Current'));
        check('unit override applied (col 1)',  strcmp(result.units{1}, 'Ohm'));
        check('unit override applied (col 2)',  strcmp(result.units{2}, 'mA'));
        check('original data unchanged', strcmp(data.labels{1}, 'Ch1'));
    catch ME
        recordError('TEST 5', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 6: Apply image metadata overrides
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 6: Apply image metadata overrides ==\n');
    try
        data = struct();
        data.time = [];
        data.values = [];
        data.labels = {};
        data.units = {};
        data.metadata.parserName = 'importTIFF';
        data.metadata.parserSpecific.sampleName = 'OldSample';
        data.metadata.parserSpecific.pixelSize = 10.0;

        tmpl = struct();
        tmpl.type = 'image_metadata';
        tmpl.overrides.sampleName = 'CorrectSample';
        tmpl.overrides.pixelSize = 4.93;
        tmpl.overrides.operator = 'Patrick';

        result = templates.TemplateEngine.apply(data, tmpl);
        check('sampleName overridden', strcmp(result.metadata.parserSpecific.sampleName, 'CorrectSample'));
        check('pixelSize overridden', result.metadata.parserSpecific.pixelSize == 4.93);
        check('operator added', strcmp(result.metadata.parserSpecific.operator, 'Patrick'));
        check('original unchanged', strcmp(data.metadata.parserSpecific.sampleName, 'OldSample'));
    catch ME
        recordError('TEST 6', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 7: Save / load / delete round-trip
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 7: Save / load / delete round-trip ==\n');
    try
        tmpl = struct();
        tmpl.name = 'test_roundtrip_template';
        tmpl.type = 'tabular';
        tmpl.match = struct('parserName', 'importCSV', 'headerFingerprint', 'DEADBEEF');
        tmpl.overrides = struct('labels', struct('x0', 'TestLabel'));

        templates.TemplateEngine.save(tmpl);

        % Verify it shows up in loadAll
        all = templates.TemplateEngine.loadAll(ForceReload=true);
        names = cellfun(@(t) t.name, all, 'UniformOutput', false);
        check('saved template found in loadAll', any(strcmp(names, 'test_roundtrip_template')));

        % Verify JSON file exists
        ud = templates.TemplateEngine.userDir();
        jsonPath = fullfile(ud, 'test_roundtrip_template.json');
        check('JSON file exists on disk', isfile(jsonPath));

        % Load and verify content
        txt = fileread(jsonPath);
        loaded = jsondecode(txt);
        check('loaded name matches', strcmp(loaded.name, 'test_roundtrip_template'));
        check('loaded type matches', strcmp(loaded.type, 'tabular'));
        check('loaded has source=user', strcmp(loaded.source, 'user'));

        % Delete
        templates.TemplateEngine.delete('test_roundtrip_template');
        check('JSON file deleted', ~isfile(jsonPath));

        all2 = templates.TemplateEngine.loadAll(ForceReload=true);
        names2 = cellfun(@(t) t.name, all2, 'UniformOutput', false);
        check('deleted template gone from loadAll', ~any(strcmp(names2, 'test_roundtrip_template')));
    catch ME
        recordError('TEST 7', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 8: Exact fingerprint match → confidence 1.0
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 8: Exact fingerprint match ==\n');
    try
        data = makeTabularData({'Xdata', 'Ydata'}, {'m', 's'}, 'importCSV');
        fp = templates.TemplateEngine.fingerprint(data);

        tmpl = struct();
        tmpl.name = 'test_exact_fp_match';
        tmpl.type = 'tabular';
        tmpl.match = struct('headerFingerprint', fp, 'parserName', 'importCSV');
        tmpl.overrides = struct('labels', struct('x0', 'Matched'));

        templates.TemplateEngine.save(tmpl);

        [matched, conf] = templates.TemplateEngine.match(data, Type='tabular');
        check('exact fingerprint → confidence 1.0', conf == 1.0);
        check('matched template is correct', strcmp(matched.name, 'test_exact_fp_match'));

        % Cleanup
        templates.TemplateEngine.delete('test_exact_fp_match');
    catch ME
        recordError('TEST 8', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 9: No match for unknown data → confidence 0
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 9: No match for unknown data ==\n');
    try
        data = makeTabularData({'CompletelyUnknown1', 'CompletelyUnknown2'}, ...
            {'??', '??'}, 'importNonExistent');
        [tmpl, conf] = templates.TemplateEngine.match(data, Type='tabular');
        check('unknown data → low confidence', conf < 0.4);
    catch ME
        recordError('TEST 9', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 10: Apply with no overrides is identity
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 10: Apply with empty overrides ==\n');
    try
        data = makeTabularData({'A', 'B'}, {'x', 'y'}, 'importCSV');
        tmpl = struct('type', 'tabular', 'overrides', struct());
        result = templates.TemplateEngine.apply(data, tmpl);
        check('labels unchanged', isequal(result.labels, data.labels));
        check('units unchanged', isequal(result.units, data.units));
        check('values unchanged', isequal(result.values, data.values));
    catch ME
        recordError('TEST 10', ME);
    end

    % ════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════
    fprintf('\n--- test_templateEngine summary ---\n');
    fprintf('  Passed: %d    Failed: %d\n', results.passed, results.failed);
    if results.failed > 0
        fprintf(2, '  ERRORS:\n');
        for k = 1:numel(results.errors)
            fprintf(2, '    %s\n', results.errors{k});
        end
    end
    fprintf('==============================\n\n');

    % ════════════════════════════════════════════════════════════════
    %  Helpers
    % ════════════════════════════════════════════════════════════════
    function check(msg, cond)
        if cond
            results.passed = results.passed + 1;
            fprintf('  [PASS] %s\n', msg);
        else
            results.failed = results.failed + 1;
            results.errors{end+1} = msg;
            fprintf(2, '  [FAIL] %s\n', msg);
        end
    end

    function recordError(testName, ME)
        results.failed = results.failed + 1;
        errMsg = sprintf('%s CRASHED: %s', testName, ME.message);
        results.errors{end+1} = errMsg;
        fprintf(2, '  [CRASH] %s\n', errMsg);
        for si = 1:min(3, numel(ME.stack))
            fprintf(2, '    at %s (line %d)\n', ME.stack(si).name, ME.stack(si).line);
        end
    end
end


function data = makeTabularData(labels, units, parserName)
%MAKETABULARDATA  Create a minimal data struct for testing.
    N = 20;
    M = numel(labels);
    data = parser.createDataStruct( ...
        (1:N)', rand(N, M), ...
        'labels', labels, 'units', units, ...
        'metadata', struct('parserName', parserName, 'source', 'test.dat', ...
                           'xColumnName', 'X', 'xColumnUnit', '', ...
                           'parserSpecific', struct()));
end
