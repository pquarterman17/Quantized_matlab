%TEST_CIF_PARSER  Tests for calc.importCIF and calc.crystalCache.
%
%   Run:
%       run tests/test_cif_parser
%       runAllTests(Group="cif")

clear; clc;
fprintf('\n=== CIF Parser & Crystal Cache Tests ===\n\n');

ROOT = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(ROOT);

tmpDir = fullfile(tempdir, sprintf('cif_test_%s', datestr(now, 'yyyymmdd_HHMMSS')));
mkdir(tmpDir);
cleanupDir = onCleanup(@() rmdir(tmpDir, 's'));

passed = 0;
failed = 0;

% ── Create synthetic CIF file ────────────────────────────────────────
cifText = [ ...
    'data_SrTiO3\n' ...
    '#\n' ...
    '_cell_length_a    3.9050(1)\n' ...
    '_cell_length_b    3.9050(1)\n' ...
    '_cell_length_c    3.9050(1)\n' ...
    '_cell_angle_alpha 90.000\n' ...
    '_cell_angle_beta  90.000\n' ...
    '_cell_angle_gamma 90.000\n' ...
    '_symmetry_space_group_name_H-M ''Pm-3m''\n' ...
    '_chemical_formula_sum ''O3 Sr Ti''\n' ...
    '#\n' ...
    'loop_\n' ...
    '_atom_site_label\n' ...
    '_atom_site_type_symbol\n' ...
    '_atom_site_fract_x\n' ...
    '_atom_site_fract_y\n' ...
    '_atom_site_fract_z\n' ...
    '_atom_site_occupancy\n' ...
    'Sr1 Sr 0.5 0.5 0.5 1.0\n' ...
    'Ti1 Ti 0.0 0.0 0.0 1.0\n' ...
    'O1  O  0.5 0.0 0.0 1.0\n' ...
    'O2  O  0.0 0.5 0.0 1.0\n' ...
    'O3  O  0.0 0.0 0.5 1.0\n' ...
];

cifPath = fullfile(tmpDir, 'SrTiO3.cif');
fid = fopen(cifPath, 'w');
fprintf(fid, cifText);
fclose(fid);

% ── TEST 1: Parse CIF file ──────────────────────────────────────────
fprintf('== TEST 1: Parse CIF file ==\n');
try
    r = calc.importCIF(cifPath);
    assert(strcmp(r.blockName, 'SrTiO3'), 'Block name should be SrTiO3');
    assert(abs(r.cellParams.a - 3.905) < 0.001, 'a should be 3.905');
    assert(abs(r.cellParams.b - 3.905) < 0.001, 'b should be 3.905');
    assert(abs(r.cellParams.c - 3.905) < 0.001, 'c should be 3.905');
    assert(abs(r.cellParams.alpha - 90) < 0.01, 'alpha should be 90');
    fprintf('  Cell params: a=%.4f b=%.4f c=%.4f\n', r.cellParams.a, r.cellParams.b, r.cellParams.c);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ── TEST 2: Space group ──────────────────────────────────────────────
fprintf('== TEST 2: Space group ==\n');
try
    r = calc.importCIF(cifPath);
    assert(contains(r.spaceGroup, 'Pm-3m') || contains(r.spaceGroup, 'Pm3m'), ...
        'Space group should contain Pm-3m');
    fprintf('  Space group: %s\n', r.spaceGroup);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ── TEST 3: Atom sites ──────────────────────────────────────────────
fprintf('== TEST 3: Atom sites ==\n');
try
    r = calc.importCIF(cifPath);
    assert(numel(r.atomSites) == 5, 'Should have 5 atom sites');
    % Check first site
    assert(strcmp(r.atomSites(1).symbol, 'Sr'), 'First site should be Sr');
    assert(abs(r.atomSites(1).x - 0.5) < 1e-6, 'Sr x should be 0.5');
    assert(abs(r.atomSites(1).occupancy - 1.0) < 1e-6, 'Occupancy should be 1.0');
    fprintf('  Found %d atom sites\n', numel(r.atomSites));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ── TEST 4: Uncertainty stripping ────────────────────────────────────
fprintf('== TEST 4: Uncertainty stripping ==\n');
try
    r = calc.importCIF(cifPath);
    % 3.9050(1) should become exactly 3.9050
    assert(abs(r.cellParams.a - 3.905) < 1e-4, 'Uncertainty should be stripped');
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ── TEST 5: Tags map ────────────────────────────────────────────────
fprintf('== TEST 5: Tags map ==\n');
try
    r = calc.importCIF(cifPath);
    assert(isa(r.tags, 'containers.Map'), 'tags should be a containers.Map');
    assert(r.tags.isKey('_cell_length_a'), 'Should have _cell_length_a tag');
    fprintf('  Tags map has %d entries\n', r.tags.Count);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ── TEST 6: Formula field ───────────────────────────────────────────
fprintf('== TEST 6: Formula field ==\n');
try
    r = calc.importCIF(cifPath);
    assert(~isempty(r.formula), 'Formula should not be empty');
    assert(contains(r.formula, 'Sr') && contains(r.formula, 'Ti'), ...
        'Formula should contain Sr and Ti');
    fprintf('  Formula: %s\n', r.formula);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ── TEST 7: Crystal cache add/list/search/remove ────────────────────
fprintf('== TEST 7: Crystal cache operations ==\n');
try
    % Use a temporary cache by temporarily working in tmpDir
    entry.name = 'SrTiO3_test';
    entry.formula = 'SrTiO3';
    entry.a = 3.905; entry.b = 3.905; entry.c = 3.905;
    entry.alpha = 90; entry.beta = 90; entry.gamma = 90;
    entry.spaceGroup = 'Pm-3m';

    calc.crystalCache('add', Entry=entry);

    % List
    allEntries = calc.crystalCache('list');
    found = false;
    for ei = 1:numel(allEntries)
        if strcmp(allEntries(ei).name, 'SrTiO3_test')
            found = true;
            break;
        end
    end
    assert(found, 'Added entry should appear in list');

    % Search
    results = calc.crystalCache('search', Query='SrTiO3');
    assert(~isempty(results), 'Search should find SrTiO3_test');

    % Get
    got = calc.crystalCache('get', Name='SrTiO3_test');
    assert(abs(got.a - 3.905) < 0.001, 'Got entry should have correct a');

    % Remove
    calc.crystalCache('remove', Name='SrTiO3_test');
    allEntries2 = calc.crystalCache('list');
    found2 = false;
    for ei = 1:numel(allEntries2)
        if strcmp(allEntries2(ei).name, 'SrTiO3_test')
            found2 = true;
            break;
        end
    end
    assert(~found2, 'Removed entry should not appear in list');

    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ── TEST 8: CIF import to cache ─────────────────────────────────────
fprintf('== TEST 8: CIF import to cache ==\n');
try
    calc.crystalCache('import', FilePath=cifPath);
    allEntries = calc.crystalCache('list');
    found = false;
    for ei = 1:numel(allEntries)
        if contains(allEntries(ei).name, 'SrTiO3')
            found = true;
            break;
        end
    end
    assert(found, 'Imported CIF should appear in cache');
    % Clean up
    calc.crystalCache('remove', Name=allEntries(ei).name);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ── SUMMARY ──────────────────────────────────────────────────────────
fprintf('\n=== Results: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_cif_parser:failures', '%d test(s) FAILED', failed);
end
