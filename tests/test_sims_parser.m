%TEST_SIMS_PARSER  Synthetic-data tests for parser.importSIMS
%
%   Tests cover paired-column layout, shared-depth layout, element name
%   cleaning, depth grid merging, metadata capture, edge cases, and unit
%   detection. All test data is generated via fprintf to temporary files.
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
    % Union grid should span 0-200 with step 50
    assert(d.time(1) == 0, 'Grid should start at 0');
    assert(d.time(end) == 200, 'Grid should end at 200');
    % Element A should have NaN beyond depth 100
    lastAValid = find(~isnan(d.values(:,1)), 1, 'last');
    assert(d.time(lastAValid) == 100, 'A should be valid up to depth 100');
    % Element B should be valid across the full range
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
    % Test nm detection
    fp1 = writeTempCSV('sims_t8a', {
        'Depth (nm),Si (atoms/cm3)'
        '0,1e20'
        '10,9e19'
    });
    tmpFiles{end+1} = fp1;
    d1 = parser.importSIMS(fp1);
    assert(strcmp(d1.metadata.parserSpecific.depthUnit, 'nm'), 'nm not detected');
    assert(strcmp(d1.units{1}, 'atoms/cm3'), 'Conc unit not extracted');

    % Test um detection
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

catch ME
    fprintf('  ✘ FATAL: %s\n', ME.message);
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
