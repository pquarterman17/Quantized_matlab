function test_convertMagUnits
%TEST_CONVERTMAGUNITS  Unit tests for utilities.convertMagUnits.
%
%   Covers:
%     - Field conversions: Oe ↔ T, mT, A/m (both directions via pivot)
%     - Moment conversions: emu ↔ A·m², emu/g, emu/cm³, kA/m
%     - Round-trip precision (convert forward then back recovers input)
%     - Missing mass / volume → warn but don't error, return unchanged
%     - Raw data preservation: input arrays never mutated
%     - Known reference values (50 kOe = 5 T, 1 emu = 1e-3 A·m², ...)
%
%   Run standalone:  run tests/utilities/test_convertMagUnits
%   Run via group :  runAllTests(Group="utilities")

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    if ~contains(path, rootDir), addpath(rootDir); end

    passed = 0;
    failed = 0;
    failures = {};

    TOL = 1e-10;

    % ════════════════════════════════════════════════════════════════════
    %  TEST 1: Oe → T reference values
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 1: Oe → T reference values ==\n');
    try
        x = [-5e4, -1e4, 0, 1e4, 5e4];
        y = zeros(size(x));
        [xo, ~, xu, ~] = utilities.convertMagUnits(x, y, ...
            'FromField', 'Oe', 'ToField', 'T');

        expected = [-5, -1, 0, 1, 5];
        check('Oe → T: 50 kOe = 5 T',    abs(xo(end) - 5)    < TOL);
        check('Oe → T: 10 kOe = 1 T',    abs(xo(4)   - 1)    < TOL);
        check('Oe → T: 0 stays 0',       abs(xo(3))          < TOL);
        check('Oe → T: -50 kOe = -5 T',  abs(xo(1)   - (-5)) < TOL);
        check('Oe → T: full array',      max(abs(xo - expected)) < TOL);
        check('xUnitOut is "T"',         strcmp(xu, 'T'));
    catch ME
        recordCrash('TEST 1', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 2: Oe ↔ mT and Oe ↔ A/m
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 2: other field conversions ==\n');
    try
        % Oe → mT: 10 Oe = 1 mT
        x = [10, 100, 1000];
        [xo, ~] = utilities.convertMagUnits(x, x, ...
            'FromField', 'Oe', 'ToField', 'mT');
        check('Oe → mT: 10 Oe = 1 mT',   abs(xo(1) - 1)   < TOL);
        check('Oe → mT: 100 Oe = 10 mT', abs(xo(2) - 10)  < TOL);

        % Oe → A/m: 1 Oe ≈ 79.577 A/m
        [xo, ~] = utilities.convertMagUnits([1, 1e4], [1, 1e4], ...
            'FromField', 'Oe', 'ToField', 'A/m');
        check('Oe → A/m: 1 Oe ≈ 79.5775 A/m',  abs(xo(1) - 1e3/(4*pi)) < TOL);
        check('Oe → A/m: 10 kOe ≈ 795775 A/m', abs(xo(2) - 1e7/(4*pi)) < 1e-6);

        % mT → T: 1000 mT = 1 T
        [xo, ~] = utilities.convertMagUnits([1000, 500], [0 0], ...
            'FromField', 'mT', 'ToField', 'T');
        check('mT → T: 1000 mT = 1 T',   abs(xo(1) - 1)   < TOL);
        check('mT → T: 500 mT = 0.5 T',  abs(xo(2) - 0.5) < TOL);
    catch ME
        recordCrash('TEST 2', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 3: emu → A·m² reference value
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 3: emu → A·m² ==\n');
    try
        y = [1, 0.5, 0.001, 0];
        [~, yo, ~, yu] = utilities.convertMagUnits(y, y, ...
            'FromMoment', 'emu', 'ToMoment', 'A·m²');

        check('emu → A·m²: 1 emu = 1e-3',  abs(yo(1) - 1e-3)   < TOL);
        check('emu → A·m²: 0.5 emu',       abs(yo(2) - 0.5e-3) < TOL);
        check('emu → A·m²: 0 stays 0',     abs(yo(4))          < TOL);
        check('yUnitOut is "A·m²"',        strcmp(yu, 'A·m²'));
    catch ME
        recordCrash('TEST 3', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 4: emu → emu/g with mass
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 4: emu → emu/g (with mass) ==\n');
    try
        y = [0.01, 0.02, 0.005];
        mass_g = 0.0125;   % 12.5 mg
        [~, yo, ~, ~, w] = utilities.convertMagUnits(y, y, ...
            'FromMoment', 'emu', 'ToMoment', 'emu/g', ...
            'SampleMass', mass_g);

        check('emu/g: 0.01 / 0.0125 = 0.8',    abs(yo(1) - 0.8)  < TOL);
        check('emu/g: 0.02 / 0.0125 = 1.6',    abs(yo(2) - 1.6)  < TOL);
        check('emu/g: 0.005 / 0.0125 = 0.4',   abs(yo(3) - 0.4)  < TOL);
        check('no warning on successful conversion', isempty(w));
    catch ME
        recordCrash('TEST 4', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 5: Missing sample mass → warn, no conversion, not error
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 5: missing mass → warn + no-op ==\n');
    try
        y = [0.01, 0.02];
        [xo, yo, xu, yu, w] = utilities.convertMagUnits(y, y, ...
            'ToMoment', 'emu/g', 'SampleMass', 0);

        check('yOut unchanged when mass missing', isequal(yo, y));
        check('yUnitOut stays "emu"', strcmp(yu, 'emu'));
        check('warning message is non-empty', ~isempty(w));
        check('warning mentions sample mass',  contains(lower(w), 'sample mass'));
    catch ME
        recordCrash('TEST 5', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 6: Missing sample volume → warn, no conversion
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 6: missing volume → warn + no-op ==\n');
    try
        y = [0.01, 0.02];
        [~, yo, ~, yu, w] = utilities.convertMagUnits(y, y, ...
            'ToMoment', 'emu/cm³', 'SampleVolume', 0);
        check('yOut unchanged when volume missing (emu/cm³)', isequal(yo, y));
        check('warning mentions volume (emu/cm³)',            contains(lower(w), 'volume'));

        [~, yo2, ~, yu2, w2] = utilities.convertMagUnits(y, y, ...
            'ToMoment', 'kA/m', 'SampleVolume', 0);
        check('yOut unchanged when volume missing (kA/m)', isequal(yo2, y));
        check('warning mentions volume (kA/m)',            contains(lower(w2), 'volume'));
    catch ME
        recordCrash('TEST 6', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 7: Round-trip precision (Oe → T → Oe recovers input)
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 7: round-trip precision ==\n');
    try
        x0 = linspace(-70000, 70000, 101);
        y0 = zeros(size(x0));

        [x1, ~] = utilities.convertMagUnits(x0, y0, ...
            'FromField', 'Oe', 'ToField', 'T');
        [x2, ~] = utilities.convertMagUnits(x1, y0, ...
            'FromField', 'T', 'ToField', 'Oe');

        check('Oe → T → Oe round-trip preserves values', ...
              max(abs(x2 - x0)) < 1e-6);

        % Moment round-trip: emu → A·m² → (no inverse supported yet)
        % So test emu → A·m² factor is exactly 1e-3
        [~, y1] = utilities.convertMagUnits([], [1.0], ...
            'FromMoment', 'emu', 'ToMoment', 'A·m²');
        check('emu → A·m² factor is exactly 1e-3', abs(y1 - 1e-3) < TOL);
    catch ME
        recordCrash('TEST 7', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 8: Raw data preservation (input not mutated)
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 8: input arrays not mutated ==\n');
    try
        x_original = [-5e4, 0, 5e4];
        y_original = [-0.01, 0, 0.01];
        x_copy = x_original;
        y_copy = y_original;

        [~, ~] = utilities.convertMagUnits(x_original, y_original, ...
            'FromField', 'Oe', 'ToField', 'T', ...
            'FromMoment', 'emu', 'ToMoment', 'A·m²');

        check('x input array unchanged after conversion', isequal(x_original, x_copy));
        check('y input array unchanged after conversion', isequal(y_original, y_copy));
    catch ME
        recordCrash('TEST 8', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 9: No-op when from == to
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 9: no-op when source == target ==\n');
    try
        x = [1 2 3];  y = [4 5 6];
        [xo, yo, xu, yu, w] = utilities.convertMagUnits(x, y, ...
            'FromField', 'Oe', 'ToField', 'Oe', ...
            'FromMoment', 'emu', 'ToMoment', 'emu');

        check('no-op x unchanged',       isequal(xo, x));
        check('no-op y unchanged',       isequal(yo, y));
        check('no-op xUnitOut is "Oe"',  strcmp(xu, 'Oe'));
        check('no-op yUnitOut is "emu"', strcmp(yu, 'emu'));
        check('no warning on no-op',     isempty(w));
    catch ME
        recordCrash('TEST 9', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 10: Empty arrays handled cleanly
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 10: empty array handling ==\n');
    try
        [xo, yo, xu, yu, w] = utilities.convertMagUnits([], [], ...
            'FromField', 'Oe', 'ToField', 'T', ...
            'FromMoment', 'emu', 'ToMoment', 'A·m²');

        check('empty x stays empty',   isempty(xo));
        check('empty y stays empty',   isempty(yo));
        check('label is "T"',          strcmp(xu, 'T'));
        check('label is "A·m²"',       strcmp(yu, 'A·m²'));
        check('no warning on empty',   isempty(w));
    catch ME
        recordCrash('TEST 10', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  TEST 11: Unknown unit → warn + no-op
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n== TEST 11: unknown unit → warn ==\n');
    try
        [xo, ~, xu, ~, w] = utilities.convertMagUnits([1 2 3], [0 0 0], ...
            'FromField', 'Oe', 'ToField', 'furlongs');
        check('unknown target → x unchanged', isequal(xo, [1 2 3]));
        check('unknown target → label stays at source "Oe"', strcmp(xu, 'Oe'));
        check('unknown target → warning present', ~isempty(w));
        check('unknown target → warning mentions unit name', contains(w, 'furlongs'));
    catch ME
        recordCrash('TEST 11', ME);
    end

    % ════════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════════
    fprintf('\n%s\n', repmat('=', 1, 68));
    fprintf('  test_convertMagUnits: %d passed, %d failed\n', passed, failed);
    if failed > 0
        fprintf('\n  Failures:\n');
        for i = 1:numel(failures)
            fprintf('    - %s\n', failures{i});
        end
        error('test_convertMagUnits:failed', '%d test(s) failed', failed);
    end
    fprintf('%s\n', repmat('=', 1, 68));

    % ── Nested helpers ─────────────────────────────────────────────
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
