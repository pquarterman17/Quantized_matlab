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

    % ────────────────────────────────────────────────────────────────
    %  Test 11: Default template column names match parser output
    %  Verifies that shipped templates use post-parsing label format
    %  (units stripped) so Jaccard matching is effective.
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 11: Shipped template column names match parser output ==\n');
    try
        % QD VSM M vs H — parsers strip "(Oe)" from "Magnetic Field (Oe)"
        data = makeTabularData({'Magnetic Field', 'Moment', 'M. Std. Err.'}, ...
            {'Oe', 'emu', 'emu'}, 'importQDVSM');
        data.metadata.parserSpecific.instrument = 'VSM';
        [tmpl, conf] = templates.TemplateEngine.match(data, Type='tabular');
        check('QD VSM M vs H: confidence >= 0.5', conf >= 0.5);
        check('QD VSM M vs H: matched correct template', ...
            ~isempty(tmpl) && contains(tmpl.name, 'M vs H'));
        fprintf('  QD VSM M vs H matched: "%s" at %.2f\n', tmpl.name, conf);

        % QD VSM M vs T
        data = makeTabularData({'Temperature', 'Moment', 'M. Std. Err.'}, ...
            {'K', 'emu', 'emu'}, 'importQDVSM');
        data.metadata.parserSpecific.instrument = 'VSM';
        [tmpl, conf] = templates.TemplateEngine.match(data, Type='tabular');
        check('QD VSM M vs T: confidence >= 0.5', conf >= 0.5);
        check('QD VSM M vs T: matched correct template', ...
            ~isempty(tmpl) && contains(tmpl.name, 'M vs T'));
        fprintf('  QD VSM M vs T matched: "%s" at %.2f\n', tmpl.name, conf);

        % PPMS Resistivity
        data = makeTabularData({'Temperature', 'Resistance Ch1', 'Resistance Ch2'}, ...
            {'K', 'Ohms', 'Ohms'}, 'importPPMS');
        [tmpl, conf] = templates.TemplateEngine.match(data, Type='tabular');
        check('PPMS Resistivity: confidence >= 0.5', conf >= 0.5);
        check('PPMS Resistivity: matched correct template', ...
            ~isempty(tmpl) && contains(tmpl.name, 'Resistivity'));
        fprintf('  PPMS Resistivity matched: "%s" at %.2f\n', tmpl.name, conf);

        % PPMS ACMS — uses importQDVSM parser
        data = makeTabularData({'Temperature', 'AC Moment', 'AC Susceptibility'}, ...
            {'K', 'emu', 'emu/Oe'}, 'importQDVSM');
        data.metadata.parserSpecific.instrument = 'PPMS';
        [tmpl, conf] = templates.TemplateEngine.match(data, Type='tabular');
        check('PPMS ACMS: confidence >= 0.5', conf >= 0.5);
        check('PPMS ACMS: matched correct template', ...
            ~isempty(tmpl) && contains(tmpl.name, 'AC Susceptibility'));
        fprintf('  PPMS ACMS matched: "%s" at %.2f\n', tmpl.name, conf);

        % XRD Bragg — matches on filePattern + parserName (no columnNames to
        % avoid ambiguity with other Intensity-producing parsers)
        data = makeTabularData({'Intensity'}, {'cps'}, 'importXRDML');
        data.metadata.source = 'scan.xrdml';
        [tmpl, conf] = templates.TemplateEngine.match(data, Type='tabular');
        check('XRD Bragg: confidence >= 0.4', conf >= 0.4);
        check('XRD Bragg: matched correct template', ...
            ~isempty(tmpl) && contains(tmpl.name, 'Bragg'));
        fprintf('  XRD Bragg matched: "%s" at %.2f\n', tmpl.name, conf);

        % Lake Shore M vs T
        data = makeTabularData({'Temperature', 'Moment'}, {'K', 'emu'}, 'importLakeShore');
        data.metadata.parserSpecific.instrumentType = 'Lake Shore VSM/Magnetometer';
        [tmpl, conf] = templates.TemplateEngine.match(data, Type='tabular');
        check('LakeShore M vs T: confidence >= 0.5', conf >= 0.5);
        check('LakeShore M vs T: matched correct template', ...
            ~isempty(tmpl) && contains(tmpl.name, 'Lake Shore'));
        fprintf('  Lake Shore matched: "%s" at %.2f\n', tmpl.name, conf);

        % NCNR Reflectometry — matches on filePattern + parserName
        data = makeTabularData({'Intensity'}, {'counts'}, 'importNCNRRefl');
        data.metadata.source = 'sample_CANDOR.refl';
        [tmpl, conf] = templates.TemplateEngine.match(data, Type='tabular');
        check('NCNR Reflectometry: confidence >= 0.4', conf >= 0.4);
        check('NCNR Reflectometry: matched correct template', ...
            ~isempty(tmpl) && contains(tmpl.name, 'NCNR'));
        fprintf('  NCNR matched: "%s" at %.2f\n', tmpl.name, conf);
    catch ME
        recordError('TEST 11', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 12: Apply does not mutate input data
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 12: Apply does not mutate input ==\n');
    try
        data = makeTabularData({'Magnetic Field', 'Moment'}, {'Oe', 'emu'}, 'importQDVSM');
        data.metadata.parserSpecific.instrument = 'VSM';
        [tmpl, ~] = templates.TemplateEngine.match(data, Type='tabular');
        if isempty(tmpl)
            check('skipped (no template to apply)', true);
        else
            origLabel1 = data.labels{1};
            result = templates.TemplateEngine.apply(data, tmpl);
            check('apply returns struct', isstruct(result));
            check('original data.labels{1} unchanged after apply', ...
                strcmp(data.labels{1}, origLabel1));
        end
    catch ME
        recordError('TEST 12', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 13: All shipped JSON files are valid and have required fields
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 13: All shipped JSON files valid ==\n');
    try
        defaultDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
            '..', '+templates', 'defaults');
        listing = dir(fullfile(defaultDir, '*.json'));
        check('at least 6 shipped templates', numel(listing) >= 6);
        for k = 1:numel(listing)
            fp = fullfile(listing(k).folder, listing(k).name);
            txt = fileread(fp);
            t = jsondecode(txt);
            fname = listing(k).name;
            check(sprintf('%s: has .name', fname), isfield(t, 'name') && ~isempty(t.name));
            check(sprintf('%s: has .type', fname), isfield(t, 'type') && ~isempty(t.type));
            check(sprintf('%s: has .match', fname), isfield(t, 'match'));
            check(sprintf('%s: has .overrides', fname), isfield(t, 'overrides'));
            check(sprintf('%s: has .source=shipped', fname), ...
                isfield(t, 'source') && strcmp(t.source, 'shipped'));
            if isfield(t, 'match') && isfield(t.match, 'parserName')
                pname = t.match.parserName;
                parserDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                    '..', '+parser');
                parserFile = fullfile(parserDir, [pname '.m']);
                check(sprintf('%s: parserName %s exists in +parser/', fname, pname), ...
                    isfile(parserFile));
            end
        end
    catch ME
        recordError('TEST 13', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 14: Synonym matching — "Temp" + "Mag" map to canonical forms
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 14: Synonym matching (Temp/Mag → temperature/moment) ==\n');
    try
        % Use highly unusual column names that won't match shipped templates
        tmpl = struct();
        tmpl.name = 'test_synonym_uniqueparser';
        tmpl.type = 'tabular';
        tmpl.match.columnNames = {'Temperature', 'Susceptibility', 'Frequency'};
        tmpl.match.parserName  = 'importCSV';
        tmpl.overrides = struct('labels', struct(), 'units', struct());
        templates.TemplateEngine.save(tmpl);

        % Data uses abbreviated / synonym forms of all three columns
        data = makeTabularData({'Temp', 'Chi', 'Freq'}, {'K', 'emu/Oe', 'Hz'}, 'importCSV');
        [matched, conf] = templates.TemplateEngine.match(data, Type='tabular');

        check('synonym match: confidence >= 0.9', conf >= 0.9);
        check('synonym match: correct template found', ...
            ~isempty(matched) && strcmp(matched.name, 'test_synonym_uniqueparser'));
        fprintf('  Synonym match confidence: %.3f\n', conf);

        % Also verify normalizeNames works by calling scoreTemplate indirectly:
        % If synonyms are working, 'Temp' normalises to 'temperature' which
        % matches 'Temperature' in the template's columnNames.
        data2 = makeTabularData({'Temperature', 'Susceptibility', 'Frequency'}, ...
            {'K', 'emu/Oe', 'Hz'}, 'importCSV');
        [~, conf2] = templates.TemplateEngine.match(data2, Type='tabular');
        check('synonym: abbreviated confidence equals verbose confidence', ...
            abs(conf - conf2) < 0.05);
        fprintf('  Verbose match confidence: %.3f\n', conf2);

        % Cleanup
        templates.TemplateEngine.delete('test_synonym_uniqueparser');
    catch ME
        recordError('TEST 14', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 15: Unit stripping in fingerprint / matching
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 15: Unit stripping in column name normalization ==\n');
    try
        % Labels with units in parens vs without should match the same template
        tmpl = struct();
        tmpl.name = 'test_unit_strip';
        tmpl.type = 'tabular';
        tmpl.match.columnNames = {'Temperature', 'Moment'};
        tmpl.match.parserName  = 'importCSV';
        tmpl.overrides = struct('labels', struct(), 'units', struct());
        templates.TemplateEngine.save(tmpl);

        % Data with unit suffixes embedded in label strings
        dataWithUnits = makeTabularData( ...
            {'Temperature (K)', 'Moment (emu)'}, {'', ''}, 'importCSV');
        dataPlain = makeTabularData( ...
            {'Temperature', 'Moment'}, {'K', 'emu'}, 'importCSV');

        [~, confWithUnits] = templates.TemplateEngine.match(dataWithUnits, Type='tabular');
        [~, confPlain]     = templates.TemplateEngine.match(dataPlain,     Type='tabular');

        check('unit-stripped labels match template', confWithUnits > 0.5);
        check('plain labels still match template', confPlain > 0.5);
        check('unit-stripped confidence close to plain', ...
            abs(confWithUnits - confPlain) < 0.15);
        fprintf('  Confidence with units in labels: %.3f, plain: %.3f\n', ...
            confWithUnits, confPlain);

        templates.TemplateEngine.delete('test_unit_strip');
    catch ME
        recordError('TEST 15', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 16: TemplateManager launches and lists templates
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 16: TemplateManager launch and list ==\n');
    try
        templates.TemplateManager();          % no parent — standalone
        drawnow;

        % Find the figure by name
        allFigs = findall(groot, 'Type', 'figure');
        mgr = [];
        for k = 1:numel(allFigs)
            if strcmp(allFigs(k).Name, 'Template Manager')
                mgr = allFigs(k);
                break;
            end
        end

        check('TemplateManager figure opened', ~isempty(mgr) && isvalid(mgr));

        if ~isempty(mgr) && isvalid(mgr)
            % Verify list box is populated
            lb = findall(mgr, 'Type', 'uilistbox');
            check('list box present', ~isempty(lb));
            if ~isempty(lb)
                check('list box has items', numel(lb(1).Items) >= 1);
            end

            % Close gracefully
            close(mgr);
            check('TemplateManager closed without error', true);
        end
    catch ME
        recordError('TEST 16', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 17: TemplateAnalytics — log, summary, clear
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 17: TemplateAnalytics log / summary / clear ==\n');
    try
        % Start from a clean slate so prior runs don't pollute counts
        templates.TemplateAnalytics.clearLog();

        templates.TemplateAnalytics.logApplication('QD VSM — M vs H', 0.9, true,  false);
        templates.TemplateAnalytics.logApplication('QD VSM — M vs H', 0.85, true, true);
        templates.TemplateAnalytics.logApplication('PPMS — Resistivity', 0.7, false, false);

        rpt = templates.TemplateAnalytics.summary();

        check('summary returns struct array', isstruct(rpt));
        check('summary has 2 unique templates', numel(rpt) == 2);

        % Find the VSM entry
        vsmIdx = [];
        for ri = 1:numel(rpt)
            if strcmp(rpt(ri).templateName, 'QD VSM — M vs H')
                vsmIdx = ri;
            end
        end
        check('QD VSM entry present', ~isempty(vsmIdx));
        if ~isempty(vsmIdx)
            check('QD VSM count = 2',            rpt(vsmIdx).count == 2);
            check('QD VSM avgConfidence ~= 0.875', abs(rpt(vsmIdx).avgConfidence - 0.875) < 1e-9);
            check('QD VSM editRate = 0.5',        abs(rpt(vsmIdx).editRate - 0.5) < 1e-9);
        end

        % After clear, summary should be empty
        templates.TemplateAnalytics.clearLog();
        rpt2 = templates.TemplateAnalytics.summary();
        check('summary empty after clearLog', isempty(rpt2));
    catch ME
        recordError('TEST 17', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 18: Template inheritance — ppms_hall extends ppms_base
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 18: Template inheritance (extends field) ==\n');
    try
        templates.TemplateEngine.clearCache();
        all = templates.TemplateEngine.loadAll(ForceReload=true);

        names = cellfun(@(t) t.name, all, 'UniformOutput', false);

        % Find the Hall template
        hallIdx = find(strcmp(names, 'PPMS — Hall Effect'), 1);
        check('ppms_hall.json loaded', ~isempty(hallIdx));

        if ~isempty(hallIdx)
            hall = all{hallIdx};

            % Child field should be present (from ppms_hall.json)
            check('Hall: has overrides.labels', isfield(hall, 'overrides') && isfield(hall.overrides, 'labels'));

            % Base field should be merged in (from ppms_base.json)
            check('Hall: has match.parserName (from base)', ...
                isfield(hall, 'match') && isfield(hall.match, 'parserName'));

            % "extends" marker should be stripped from resolved template
            check('Hall: extends field removed after resolution', ~isfield(hall, 'extends'));

            % Verify the child label overrides survived
            if isfield(hall.overrides, 'labels') && isstruct(hall.overrides.labels)
                hasLongR = isfield(hall.overrides.labels, 'x0') && ...
                           strcmp(hall.overrides.labels.x0, 'Longitudinal Resistance');
                check('Hall: child label override x0 present', hasLongR);
            else
                check('Hall: child label override x0 present', false);
            end
        end
    catch ME
        recordError('TEST 18', ME);
    end

    % ────────────────────────────────────────────────────────────────
    %  Test 19: Circular inheritance detection
    % ────────────────────────────────────────────────────────────────
    fprintf('\n== TEST 19: Circular inheritance error ==\n');
    try
        % Build two fake templates that form a cycle: A extends B, B extends A
        tA.name    = 'test_circular_A';
        tA.type    = 'tabular';
        tA.extends = 'test_circular_B';
        tA.match   = struct('parserName', 'importCSV');
        tA.overrides = struct();

        tB.name    = 'test_circular_B';
        tB.type    = 'tabular';
        tB.extends = 'test_circular_A';
        tB.match   = struct('parserName', 'importCSV');
        tB.overrides = struct();

        raw = {tA; tB};
        errThrown = false;
        try
            % resolveInheritance is a local function in TemplateEngine; we
            % trigger it via loadAll by saving the templates to user dir
            templates.TemplateEngine.save(tA);
            templates.TemplateEngine.save(tB);
            templates.TemplateEngine.loadAll(ForceReload=true);
        catch ME2
            if contains(ME2.identifier, 'circularInheritance') || ...
               contains(lower(ME2.message), 'circular')
                errThrown = true;
            end
        end
        check('circular inheritance throws an error', errThrown);

        % Cleanup
        templates.TemplateEngine.delete('test_circular_A');
        templates.TemplateEngine.delete('test_circular_B');
        templates.TemplateEngine.clearCache();
    catch ME
        recordError('TEST 19', ME);
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
