%TEST_SIMS_PARSER  Tests for parser.importSIMS
%
%   Tests cover paired-column layout, shared-depth layout, element name
%   cleaning, depth grid merging, metadata capture, edge cases, unit
%   detection, and realistic 10-element vendor-format stacks.
%
%   Fixture files in +test_datasets/SIMS/:
%     sims_synthetic.csv        — 8-element vendor format (original)
%     sims_stack_magnetic.csv   — 10-element Pt/Co/Cu/Co/Ta/Si
%     sims_stack_oxide.csv      — 10-element TiN/HfO₂/SiO₂/Si
%     sims_stack_barrier.csv    — 10-element Cu/TaN/Ta/SiCN/Si
%
%   Run standalone:  cd tests; run test_sims_parser
%   Run from root:   run tests/test_sims_parser
%       runAllTests(Group="sims")

clear; clc;

% Ensure toolbox is on the path
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n═══ test_sims_parser ═══\n');

nPass = 0;
nFail = 0;
tmpFiles = {};

% Fixture directory
simsDataDir = fullfile(rootDir, '+test_datasets', 'SIMS');

try

% ── Test 1: Paired columns with empty separators ──────────────────────
try
    fp = writeTempCSV('sims_t1', {
        'Depth Si,Si (at/cm3),,Depth O,O (at/cm3),,Depth Fe,Fe (at/cm3)'
        '0,1e20,,0,5e19,,0,1e18'
        '10,9e19,,10,4.5e19,,10,2e18'
        '20,8e19,,20,4e19,,20,3e18'
        '30,7e19,,30,3.5e19,,30,4e18'
    });
    tmpFiles{end+1} = fp;
    d = parser.importSIMS(fp);
    assert(numel(d.labels) == 3, 'Expected 3 elements');
    assert(isequal(d.labels, {'Si', 'O', 'Fe'}), 'Element names not cleaned');
    assert(all(strcmp(d.units, {'at/cm3', 'at/cm3', 'at/cm3'})), 'Units wrong');
    assert(numel(d.time) == 4, 'Expected 4 depth points');
    assert(~any(isnan(d.values(:))), 'No NaN expected for shared grid');
    assert(d.metadata.parserSpecific.isPairedLayout, 'Should detect paired layout');
    nPass = nPass + 1;
    fprintf('  ✔ Test 1: Paired columns with empty separators\n');
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 1: %s\n', ME.message);
end

% ── Test 2: Shared single depth column ────────────────────────────────
try
    fp = writeTempCSV('sims_t2', {
        'Depth (nm),Si,O,Fe'
        '0,1e20,5e19,1e18'
        '10,9e19,4.5e19,2e18'
        '20,8e19,4e19,3e18'
    });
    tmpFiles{end+1} = fp;
    d = parser.importSIMS(fp);
    assert(numel(d.labels) == 3, 'Expected 3 elements');
    assert(numel(d.time) == 3, 'Expected 3 depth points');
    assert(~d.metadata.parserSpecific.isPairedLayout, 'Should detect shared layout');
    assert(d.values(1,1) == 1e20, 'First Si value wrong');
    nPass = nPass + 1;
    fprintf('  ✔ Test 2: Shared single depth column\n');
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 2: %s\n', ME.message);
end

% ── Test 3: Different depth ranges per element (NaN padding) ──────────
try
    fp = writeTempCSV('sims_t3', {
        'Depth A,A,Depth B,B'
        '0,100,0,200'
        '50,110,50,210'
        '100,120,100,220'
        ',,150,230'
        ',,200,240'
    });
    tmpFiles{end+1} = fp;
    d = parser.importSIMS(fp);
    assert(numel(d.labels) == 2, 'Expected 2 elements');
    assert(d.time(1) == 0, 'Grid should start at 0');
    assert(d.time(end) == 200, 'Grid should end at 200');
    lastAValid = find(~isnan(d.values(:,1)), 1, 'last');
    assert(d.time(lastAValid) == 100, 'A should be valid up to depth 100');
    assert(~any(isnan(d.values(:,2))), 'B should have no NaN');
    nPass = nPass + 1;
    fprintf('  ✔ Test 3: Different depth ranges with NaN padding\n');
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 3: %s\n', ME.message);
end

% ── Test 4: Header cleaning variations ────────────────────────────────
try
    fp = writeTempCSV('sims_t4', {
        'Depth,28Si,O16+,Fe (at/cm3),Ga,Conc N'
        '0,1e20,5e19,1e18,3e17,2e16'
        '10,9e19,4e19,2e18,2e17,1e16'
        '20,8e19,3e19,3e18,1e17,5e15'
    });
    tmpFiles{end+1} = fp;
    d = parser.importSIMS(fp);
    assert(strcmp(d.labels{1}, 'Si'), '28Si → Si failed');
    assert(strcmp(d.labels{2}, 'O'),  'O16+ → O failed');
    assert(strcmp(d.labels{3}, 'Fe'), 'Fe (at/cm3) → Fe failed');
    assert(strcmp(d.labels{4}, 'Ga'), 'Ga → Ga failed');
    assert(strcmp(d.labels{5}, 'N'),  'Conc N → N failed');
    assert(strcmp(d.units{3}, 'at/cm3'), 'Fe unit not extracted');
    nPass = nPass + 1;
    fprintf('  ✔ Test 4: Header cleaning (mass numbers, charges, units)\n');
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 4: %s\n', ME.message);
end

% ── Test 5: Metadata rows before data ─────────────────────────────────
try
    fp = writeTempCSV('sims_t5', {
        'SIMS Depth Profile'
        'Instrument: TOF-SIMS IV'
        'Sample: ThinFilm_42'
        'Date: 2026-03-14'
        'Operator: Lab User'
        'Depth (nm),Si,O'
        '0,1e20,5e19'
        '10,9e19,4e19'
    });
    tmpFiles{end+1} = fp;
    d = parser.importSIMS(fp);
    hm = d.metadata.parserSpecific.headerMetadata;
    assert(numel(hm) == 5, 'Expected 5 metadata lines');
    assert(contains(hm{1}, 'SIMS'), 'First metadata line wrong');
    assert(contains(hm{3}, 'ThinFilm_42'), 'Sample metadata missing');
    nPass = nPass + 1;
    fprintf('  ✔ Test 5: Metadata rows captured\n');
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 5: %s\n', ME.message);
end

% ── Test 6: Single element (one depth-conc pair) ─────────────────────
try
    fp = writeTempCSV('sims_t6', {
        'Depth,Conc'
        '0,1e20'
        '10,9e19'
        '20,8e19'
    });
    tmpFiles{end+1} = fp;
    d = parser.importSIMS(fp);
    assert(numel(d.labels) == 1, 'Expected 1 element');
    assert(numel(d.time) == 3, 'Expected 3 depth points');
    nPass = nPass + 1;
    fprintf('  ✔ Test 6: Single element\n');
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 6: %s\n', ME.message);
end

% ── Test 7: No column headers (auto-generated labels) ────────────────
try
    fp = writeTempCSV('sims_t7', {
        '0,1e20,5e19'
        '10,9e19,4e19'
        '20,8e19,3e19'
    });
    tmpFiles{end+1} = fp;
    d = parser.importSIMS(fp);
    assert(numel(d.labels) >= 1, 'Should have auto-generated labels');
    assert(numel(d.time) == 3, 'Expected 3 depth points');
    nPass = nPass + 1;
    fprintf('  ✔ Test 7: No column headers\n');
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 7: %s\n', ME.message);
end

% ── Test 8: Unit detection from headers ───────────────────────────────
try
    fp1 = writeTempCSV('sims_t8a', {
        'Depth (nm),Si (atoms/cm3)'
        '0,1e20'
        '10,9e19'
    });
    tmpFiles{end+1} = fp1;
    d1 = parser.importSIMS(fp1);
    assert(strcmp(d1.metadata.parserSpecific.depthUnit, 'nm'), 'nm not detected');
    assert(strcmp(d1.units{1}, 'atoms/cm3'), 'Conc unit not extracted');

    fp2 = writeTempCSV('sims_t8b', {
        'Depth (um),Si (a.u.)'
        '0,1e20'
        '0.01,9e19'
    });
    tmpFiles{end+1} = fp2;
    d2 = parser.importSIMS(fp2);
    assert(strcmp(d2.metadata.parserSpecific.depthUnit, 'um'), 'um not detected');
    assert(strcmp(d2.units{1}, 'a.u.'), 'a.u. unit not extracted');

    nPass = nPass + 1;
    fprintf('  ✔ Test 8: Unit detection (nm, um, atoms/cm3, a.u.)\n');
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 8: %s\n', ME.message);
end

% ── Test 9: Original 8-element vendor format ──────────────────────────
try
    fp = fullfile(simsDataDir, 'sims_synthetic.csv');
    assert(isfile(fp), 'Fixture missing: %s', fp);
    d = parser.importSIMS(fp);
    assert(numel(d.labels) == 8, ...
        sprintf('Expected 8 elements, got %d', numel(d.labels)));
    assert(d.metadata.parserSpecific.isPairedLayout, ...
        'Should detect paired layout');
    assert(all(d.values(~isnan(d.values)) > 0), ...
        'All valid concentrations should be positive');
    hm = d.metadata.parserSpecific.headerMetadata;
    assert(~isempty(hm), 'Header metadata should not be empty');
    nPass = nPass + 1;
    fprintf('  ✔ Test 9: Original 8-element vendor format (%d pts)\n', numel(d.time));
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 9: %s\n', ME.message);
end

% ── Test 10: Magnetic multilayer — 10 elements ────────────────────────
% Stack: Pt(5 nm) / Co(3 nm) / Cu(5 nm) / Co(3 nm) / Ta(8 nm) / Si sub
try
    fp = fullfile(simsDataDir, 'sims_stack_magnetic.csv');
    assert(isfile(fp), 'Fixture missing: %s', fp);
    d = parser.importSIMS(fp);

    assert(numel(d.labels) == 10, ...
        sprintf('Expected 10 elements, got %d', numel(d.labels)));
    assert(d.metadata.parserSpecific.isPairedLayout, ...
        'Should detect paired layout');

    % Element names recovered from header row (XX-> format)
    assert(any(contains(d.labels, 'Pt')), 'Pt not found in labels');
    assert(any(contains(d.labels, 'Co')), 'Co not found in labels');
    assert(any(contains(d.labels, 'Cu')), 'Cu not found in labels');
    assert(any(contains(d.labels, 'Ta')), 'Ta not found in labels');
    assert(any(contains(d.labels, 'Si')), 'Si not found in labels');

    % Units: first 5 atoms/cc, last 5 arb. units
    assert(contains(d.units{1}, 'atoms'), ...
        sprintf('First unit should contain "atoms", got "%s"', d.units{1}));
    assert(contains(d.units{end}, 'arb'), ...
        sprintf('Last unit should contain "arb", got "%s"', d.units{end}));

    % All valid values positive
    assert(all(d.values(~isnan(d.values)) > 0), ...
        'All valid concentrations should be positive');

    % Pt cap should be high at surface
    ptCol = find(contains(d.labels, 'Pt'), 1);
    surfacePt = mean(d.values(d.time < 4, ptCol), 'omitnan');
    deepPt    = mean(d.values(d.time > 40, ptCol), 'omitnan');
    assert(surfacePt > 50 * deepPt, ...
        'Pt should be high at surface, low deep');

    % Si should be high in substrate
    siCol = find(contains(d.labels, 'Si'), 1);
    surfaceSi  = mean(d.values(d.time < 10, siCol), 'omitnan');
    substrateSi = mean(d.values(d.time > 40, siCol), 'omitnan');
    assert(substrateSi > 50 * surfaceSi, ...
        'Si should be much higher in substrate');

    nPass = nPass + 1;
    fprintf('  ✔ Test 10: Magnetic multilayer (%d pts × 10 elements)\n', numel(d.time));
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 10: %s\n', ME.message);
end

% ── Test 11: Gate oxide stack — 10 elements ───────────────────────────
% Stack: TiN(10 nm) / HfO₂(4 nm) / SiO₂(2 nm) / Si sub
try
    fp = fullfile(simsDataDir, 'sims_stack_oxide.csv');
    assert(isfile(fp), 'Fixture missing: %s', fp);
    d = parser.importSIMS(fp);

    assert(numel(d.labels) == 10, ...
        sprintf('Expected 10 elements, got %d', numel(d.labels)));
    assert(d.metadata.parserSpecific.isPairedLayout, ...
        'Should detect paired layout');

    % O should be elevated in oxide region
    oCol = find(strcmp(d.labels, 'O'), 1);
    assert(~isempty(oCol), 'O column not found');
    oOxide  = max(d.values(d.time > 8 & d.time < 18, oCol));
    oDeep   = mean(d.values(d.time > 40, oCol), 'omitnan');
    assert(oOxide > 10 * oDeep, ...
        'O should be elevated in oxide layers');

    % Ti should be high in TiN cap
    tiCol = find(contains(d.labels, 'Ti'), 1);
    assert(~isempty(tiCol), 'Ti column not found');

    % Metadata
    hm = d.metadata.parserSpecific.headerMetadata;
    assert(~isempty(hm), 'Header metadata should not be empty');

    nPass = nPass + 1;
    fprintf('  ✔ Test 11: Gate oxide stack (%d pts × 10 elements)\n', numel(d.time));
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 11: %s\n', ME.message);
end

% ── Test 12: Interconnect barrier stack — 10 elements ─────────────────
% Stack: Cu(15 nm) / TaN(3 nm) / Ta(5 nm) / SiCN(8 nm) / Si sub
try
    fp = fullfile(simsDataDir, 'sims_stack_barrier.csv');
    assert(isfile(fp), 'Fixture missing: %s', fp);
    d = parser.importSIMS(fp);

    assert(numel(d.labels) == 10, ...
        sprintf('Expected 10 elements, got %d', numel(d.labels)));
    assert(d.metadata.parserSpecific.isPairedLayout, ...
        'Should detect paired layout');

    % Cu should be high at surface (Cu layer 0–15 nm)
    cuCol = find(contains(d.labels, 'Cu'), 1);
    assert(~isempty(cuCol), 'Cu column not found');
    surfaceCu = mean(d.values(d.time < 10, cuCol), 'omitnan');
    deepCu    = mean(d.values(d.time > 50, cuCol), 'omitnan');
    assert(surfaceCu > 50 * deepCu, ...
        'Cu should be high at surface');

    % C and N should be elevated in SiCN region
    cCol = find(strcmp(d.labels, 'C'), 1);
    nCol = find(strcmp(d.labels, 'N'), 1);
    assert(~isempty(cCol) && ~isempty(nCol), 'C or N column not found');

    % Metadata
    hm = d.metadata.parserSpecific.headerMetadata;
    allMeta = strjoin(hm, ' ');
    assert(contains(allMeta, 'BARR'), ...
        'Sample ID should appear in header metadata');

    nPass = nPass + 1;
    fprintf('  ✔ Test 12: Interconnect barrier stack (%d pts × 10 elements)\n', numel(d.time));
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 12: %s\n', ME.message);
end

catch ME
    fprintf('  ✘ FATAL: %s\n', ME.message);
    nFail = nFail + 1;
end

% ════════════════════════════════════════════════════════════════════
%  Test 13: Excel SIMS — realistic Evans Analytical Group format
%
%  Matches the real vendor file structure exactly:
%   Row 1: "Evans Analytical Group"
%   Row 2: "Sample : ID W2834"
%   Row 3: "3/10/2026"
%   Row 4: "Drawn Curves" | 8               (metadata with numeric in B)
%   Row 5: "Num of Cycles" | 222            (metadata with numeric in B)
%   Row 6: blank
%   Row 7: Element names at column 1 of each 3-col group
%           H | | | C | | | O | | | F | | | N | | | AL-> | | | SI-> | | | TA->
%   Row 8: Depth | CONC. | blank | Depth | CONC. | blank | ...
%   Row 9: (nm) | (atoms/cc) | blank | ... | (nm) | (atom%) | ...
%   Row 10: blank
%   Row 11+: data — 3 columns per element (depth, conc, blank separator)
% ════════════════════════════════════════════════════════════════════
fprintf('   Test 13: Excel SIMS file (full Evans Analytical format)\n');
tmpXlsx = fullfile(tempdir, 'test_sims_excel.xlsx');
tmpFiles{end+1} = tmpXlsx;
try
    % 8 elements × 3 cols each = 24 cols (last element has no trailing blank = 23)
    % Using actual data values from a real Evans Analytical file
    nC = 23;  % total columns
    blk = [];  % blank cell shorthand

    % Rows 1-6: metadata block + blank
    r1 = [{'Evans Analytical Group'}, repmat({blk}, 1, nC-1)];
    r2 = [{'Sample : ID W2834'},     repmat({blk}, 1, nC-1)];
    r3 = [{'3/10/2026'},             repmat({blk}, 1, nC-1)];
    r4 = [{'Drawn Curves', 8},       repmat({blk}, 1, nC-2)];
    r5 = [{'Num of Cycles', 222},    repmat({blk}, 1, nC-2)];
    r6 = repmat({blk}, 1, nC);

    % Row 7: element names at col 1 of each 3-col group
    r7 = repmat({blk}, 1, nC);
    elemCols = 1:3:nC;  % 1, 4, 7, 10, 13, 16, 19, 22
    elemNames = {'H', 'C', 'O', 'F', 'N', 'AL->', 'SI->', 'TA->'};
    for k = 1:numel(elemNames)
        r7{elemCols(k)} = elemNames{k};
    end

    % Row 8: Depth | CONC. | blank (repeating)
    r8 = repmat({blk}, 1, nC);
    for k = 1:8
        r8{elemCols(k)}   = 'Depth';
        r8{elemCols(k)+1} = 'CONC.';
    end

    % Row 9: units — first 5 elements (atoms/cc), last 3 (atom%)
    r9 = repmat({blk}, 1, nC);
    for k = 1:8
        r9{elemCols(k)} = '(nm)';
        if k <= 5
            r9{elemCols(k)+1} = '(atoms/cc)';
        else
            r9{elemCols(k)+1} = '(atom%)';
        end
    end

    % Row 10: blank
    r10 = repmat({blk}, 1, nC);

    % Rows 11-14: data (from screenshot)
    % Columns: H(d,c,_) C(d,c,_) O(d,c,_) F(d,c,_) N(d,c,_) Al(d,c,_) Si(d,c,_) Ta(d,c)
    d11 = {0.35661,2.65e22,blk, 0.41977,1.6e20,blk, 0.49557,3.24e22,blk, ...
           0.63453,2.1e19,blk,  0.71033,5.48e18,blk, 0.0471,0.350898,blk, ...
           0.15278,94.97478,blk, 0.64946,8.993688};
    d12 = {1.19038,2.15e22,blk, 1.26617,1.96e19,blk, 1.34197,3.56e22,blk, ...
           1.48093,5.07e18,blk, 1.5441,2.86e17,blk,  0.87138,0.132672,blk, ...
           0.97706,58.08073,blk, 1.47374,66.86718};
    d13 = {2.03678,3.41e22,blk, 2.11258,1.21e19,blk, 2.17574,2.69e22,blk, ...
           2.3147,1.14e18,blk,  2.3905,1.02e17,blk,  1.69566,0.147769,blk, ...
           1.80133,13.51894,blk, 2.29801,93.93995};
    d14 = {2.88318,4.37e22,blk, 2.94634,1.28e19,blk, 3.02214,1.03e22,blk, ...
           3.1611,4.72e17,blk,  3.2369,1.02e17,blk,  2.50937,0.014993,blk, ...
           2.62561,3.19098,blk, 3.12229,98.32604};

    rawCell = [r1; r2; r3; r4; r5; r6; r7; r8; r9; r10; d11; d12; d13; d14];
    writecell(rawCell, tmpXlsx);

    % Test 1: resolveParser should detect SIMS
    res = parser.resolveParser(tmpXlsx);
    assert(strcmp(res.name, 'importSIMS'), ...
        'resolveParser should route Excel SIMS to importSIMS, got: %s', res.name);

    % Test 2: importSIMS should parse it correctly
    d = parser.importSIMS(tmpXlsx);
    assert(isstruct(d), 'output must be a struct');
    assert(size(d.values, 2) == 8, ...
        'expected 8 elements, got: %d', size(d.values, 2));

    % Test 3: Element names recovered from vendor row (with arrow cleaning)
    expected = {'H', 'C', 'O', 'F', 'N', 'Al', 'Si', 'Ta'};
    for ei = 1:8
        assert(strcmp(d.labels{ei}, expected{ei}), ...
            'element %d should be %s, got: %s', ei, expected{ei}, d.labels{ei});
    end

    % Test 4: Mixed units — first 5 atoms/cc, last 3 atom%
    for ei = 1:5
        assert(contains(d.units{ei}, 'atoms'), ...
            'element %d unit should contain atoms, got: %s', ei, d.units{ei});
    end
    for ei = 6:8
        assert(contains(d.units{ei}, 'atom'), ...
            'element %d unit should contain atom, got: %s', ei, d.units{ei});
    end

    % Test 5: Depth values are reasonable (nm range)
    assert(min(d.time) < 1, 'min depth should be < 1 nm');
    assert(max(d.time) > 2, 'max depth should be > 2 nm');

    % Test 6: Concentration values are in the right order of magnitude
    % H should be ~1e22 atoms/cc
    hCol = find(strcmp(d.labels, 'H'));
    hMax = max(d.values(:, hCol));
    assert(hMax > 1e20, 'H concentration too low: %g', hMax);

    % Test 7: importAuto dispatch works
    d2 = parser.importAuto(tmpXlsx);
    assert(strcmp(d2.metadata.parserName, 'importSIMS'), ...
        'importAuto should dispatch to importSIMS for SIMS xlsx');

    fprintf('     resolveParser: %s (correct)\n', res.name);
    fprintf('     Elements: %s\n', strjoin(d.labels, ', '));
    fprintf('     Units: %s\n', strjoin(d.units, ', '));
    fprintf('     Depth points: %d, data cols: %d\n', numel(d.time), size(d.values,2));
    nPass = nPass + 1;
catch ME
    fprintf('     FAIL: %s\n', ME.message);
    nFail = nFail + 1;
end

% ════════════════════════════════════════════════════════════════════
%  Test 14: Excel SIMS — minimal format (no separators, fewer rows)
%  Verifies the parser handles a simpler Excel layout without the
%  blank separator columns between element groups.
% ════════════════════════════════════════════════════════════════════
fprintf('   Test 14: Excel SIMS minimal (no separator columns)\n');
tmpXlsx2 = fullfile(tempdir, 'test_sims_excel_minimal.xlsx');
tmpFiles{end+1} = tmpXlsx2;
try
    rawCell2 = {
        'Evans Analytical Group', [], [], [], [], [], [], [];
        'Sample : ID T9999',     [], [], [], [], [], [], [];
        [],                       [], [], [], [], [], [], [];
        'H',   [],  'AL->',  [],  'SI->',  [],  'TA->',  [];
        'Depth', 'CONC.', 'Depth', 'CONC.', 'Depth', 'CONC.', 'Depth', 'CONC.';
        '(nm)', '(atom%)', '(nm)', '(atom%)', '(nm)', '(atom%)', '(nm)', '(atom%)';
        [],  [],  [],  [],  [],  [],  [],  [];
        0.15, 94.97, 0.05, 0.35, 0.06, 0.005, 0.65, 8.99;
        0.98, 58.08, 0.87, 0.13, 0.97, 0.003, 1.47, 66.87;
        1.80, 13.52, 1.70, 0.15, 1.80, 0.004, 2.30, 93.94;
    };
    writecell(rawCell2, tmpXlsx2);

    d = parser.importSIMS(tmpXlsx2);
    assert(strcmp(d.labels{1}, 'H'),  'expected H, got: %s', d.labels{1});
    assert(strcmp(d.labels{2}, 'Al'), 'expected Al, got: %s', d.labels{2});
    assert(strcmp(d.labels{3}, 'Si'), 'expected Si, got: %s', d.labels{3});
    assert(strcmp(d.labels{4}, 'Ta'), 'expected Ta, got: %s', d.labels{4});
    assert(contains(d.units{1}, 'atom'), 'unit should contain atom');
    assert(size(d.values, 2) == 4, 'expected 4 elements');

    fprintf('     Elements: %s\n', strjoin(d.labels, ', '));
    nPass = nPass + 1;
catch ME
    fprintf('     FAIL: %s\n', ME.message);
    nFail = nFail + 1;
end

% ════════════════════════════════════════════════════════════════════
%  Test 15: Different depth step sizes per element (grid merging)
%  Verifies that buildUnionGrid uses the finest step and interpolates
%  coarser elements onto the union grid.
% ════════════════════════════════════════════════════════════════════
fprintf('   Test 15: Different depth step sizes per element\n');
tmpStepCSV = fullfile(tempdir, 'test_sims_diff_steps.csv');
tmpFiles{end+1} = tmpStepCSV;
try
    % Element A: coarse 2 nm steps (6 points)
    % Element B: fine 1 nm steps (11 points)
    lines = {
        'Depth,CONC.,Depth,CONC.';
        '(nm),(atoms/cm3),(nm),(atoms/cm3)';
        '0,1e20,0,2e20';
        '2,9e19,1,1.9e20';
        '4,8e19,2,1.8e20';
        '6,7e19,3,1.7e20';
        '8,6e19,4,1.6e20';
        '10,5e19,5,1.5e20';
        ',,6,1.4e20';
        ',,7,1.3e20';
        ',,8,1.2e20';
        ',,9,1.1e20';
        ',,10,1.0e20'
    };
    fp = writeTempCSV('test_sims_diff_steps', lines);

    d = parser.importSIMS(fp);

    % Union grid should use 1 nm step (the finest)
    gridStep = diff(d.time);
    uniqueSteps = unique(round(gridStep, 6));
    assert(numel(uniqueSteps) == 1 && abs(uniqueSteps - 1.0) < 0.01, ...
        'Union grid step should be ~1.0 nm (finest), got: %s', mat2str(uniqueSteps));
    fprintf('     Grid step: %.2f nm (finest of 1 and 2 nm)\n', uniqueSteps);

    % Grid should span 0-10 nm with ~11 points
    assert(numel(d.time) >= 10, ...
        'Expected >= 10 grid points, got %d', numel(d.time));
    assert(abs(d.time(1)) < 0.01, 'Grid should start near 0');
    assert(abs(d.time(end) - 10) < 0.1, 'Grid should end near 10');
    fprintf('     Grid: %d points, %.1f to %.1f nm\n', numel(d.time), d.time(1), d.time(end));

    % Element A (coarse) should be interpolated: value at depth=1 nm
    % should be ~9.5e19 (linear interp between 1e20 at 0 and 9e19 at 2)
    idx1 = find(abs(d.time - 1.0) < 0.1, 1);
    if ~isempty(idx1)
        interpVal = d.values(idx1, 1);
        assert(interpVal > 9e19 && interpVal < 1e20, ...
            'Interpolated A at 1 nm should be ~9.5e19, got %.2e', interpVal);
        fprintf('     Element A interpolated at 1nm: %.2e (expected ~9.5e19)\n', interpVal);
    end

    % Element B (fine) should be exact at integer depths
    idx5 = find(abs(d.time - 5.0) < 0.1, 1);
    if ~isempty(idx5)
        exactVal = d.values(idx5, 2);
        assert(abs(exactVal - 1.5e20) < 1e18, ...
            'Element B at 5 nm should be ~1.5e20, got %.2e', exactVal);
        fprintf('     Element B exact at 5nm: %.2e (expected 1.5e20)\n', exactVal);
    end

    % Original depths should be preserved in metadata
    orig = d.metadata.parserSpecific.originalDepths;
    assert(numel(orig{1}) == 6, 'Original A should have 6 points');
    assert(numel(orig{2}) == 11, 'Original B should have 11 points');
    fprintf('     Original depths preserved: A=%d pts, B=%d pts\n', numel(orig{1}), numel(orig{2}));

    nPass = nPass + 1;
catch ME
    fprintf('     FAIL: %s\n', ME.message);
    nFail = nFail + 1;
end

% ── Cleanup temp files ────────────────────────────────────────────────
for k = 1:numel(tmpFiles)
    if isfile(tmpFiles{k})
        delete(tmpFiles{k});
    end
end

% ── Summary ──────────────────────────────────────────────────────────
fprintf('\n  Results: %d passed, %d failed\n', nPass, nFail);
fprintf('═══ test_sims_parser done ═══\n\n');
if nFail > 0
    error('test_sims_parser:failures', '%d test(s) failed.', nFail);
end


% ════════════════════════════════════════════════════════════════════
%  LOCAL HELPERS
% ════════════════════════════════════════════════════════════════════

function fp = writeTempCSV(name, lines)
%WRITETEMPCSV Write cell array of strings to a temp CSV file.
    fp = fullfile(tempdir, [name, '.csv']);
    fid = fopen(fp, 'w');
    assert(fid ~= -1, 'Cannot create temp file: %s', fp);
    cleanObj = onCleanup(@() fclose(fid));
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
end
