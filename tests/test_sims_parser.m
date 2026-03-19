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

% ── Test 9: vendor multi-row header — realistic thin-film stack ────────
% Generates a synthetic SIMS depth profile for a 4-layer stack on Si:
%
%   Surface → 0 nm
%   Layer 4 (TaN cap)       :   0 –  40 nm   (high Ta, N; surface H/C/F)
%   Layer 3 (HfO₂ high-k)  :  40 –  80 nm   (high Hf, O)
%   Layer 2 (Al₂O₃)        :  80 – 120 nm   (high Al, O)
%   Layer 1 (Ta barrier)    : 120 – 160 nm   (high Ta)
%   Si substrate            : 160+ nm        (high Si)
%
% Each element has its own slightly-offset depth vector (vendor quirk)
% with Poisson-like noise (seeded RNG for reproducibility).
% 8 elements: H, C, O, F, N, Al->, Si->, Ta->
try
    rng(42);  % reproducible noise
    nPts = 273;

    % Per-element depth vectors (vendor instruments have small offsets)
    depthOffsets = [0.27, 0.32, 0.37, 0.48, 0.53, 0.03, 0.11, 0.46];
    depths = cell(1, 8);
    for ei = 1:8
        depths{ei} = linspace(depthOffsets(ei), 200 + depthOffsets(ei), nPts)';
    end

    % erfc-based layer builder:  erfc((z - edge) / width) transitions
    % from ~1 (above edge) to ~0 (below edge).
    layer = @(z, top, bot, w) 0.5 * (erfc((z - bot) ./ w) - erfc((z - top) ./ w));

    % --- H: surface contamination peak, then background ---
    zH = depths{1};
    H = 5e22 * exp(-zH / 5) + 2e19 * ones(size(zH));  % surface spike + BG

    % --- C: surface contamination, slight enrichment in TaN cap ---
    zC = depths{2};
    C = 1e20 * exp(-zC / 3) ...                         % surface spike
      + 3e19 * layer(zC, 0, 40, 4) ...                  % TaN cap
      + 5e17 * ones(size(zC));                           % background

    % --- O: high in HfO₂ (40-80) and Al₂O₃ (80-120), low elsewhere ---
    zO = depths{3};
    O = 4.5e22 * layer(zO, 40, 80, 3) ...               % HfO₂
      + 3.8e22 * layer(zO, 80, 120, 3) ...              % Al₂O₃
      + 1e19  * ones(size(zO));                          % background

    % --- F: surface contaminant, minor incorporation in HfO₂ ---
    zF = depths{4};
    F = 2e19 * exp(-zF / 6) ...                          % surface
      + 8e18 * layer(zF, 40, 80, 4) ...                  % HfO₂ trace
      + 5e16 * ones(size(zF));                           % background

    % --- N: high in TaN cap (0-40), otherwise low ---
    zN = depths{5};
    N = 2.5e22 * layer(zN, 0, 40, 3) ...                 % TaN cap
      + 3e17  * ones(size(zN));                          % background

    % --- Al: high in Al₂O₃ layer (80-120) ---
    zAl = depths{6};
    Al = 3.2e22 * layer(zAl, 80, 120, 3) ...             % Al₂O₃
       + 1e17  * ones(size(zAl));                        % background

    % --- Si: substrate (160+), traces elsewhere ---
    zSi = depths{7};
    Si = 5e22  * 0.5 .* erfc(-(zSi - 160) ./ 4) ...     % substrate rises
       + 2e18  * ones(size(zSi));                        % background

    % --- Ta: TaN cap (0-40) + Ta barrier (120-160) ---
    zTa = depths{8};
    Ta = 3.5e22 * layer(zTa, 0, 40, 3) ...               % TaN cap
       + 3.0e22 * layer(zTa, 120, 160, 3) ...            % Ta barrier
       + 5e17  * ones(size(zTa));                        % background

    % Add multiplicative Poisson-like noise (~5% relative)
    concs = {H, C, O, F, N, Al, Si, Ta};
    for ei = 1:8
        noise = 1 + 0.05 * randn(nPts, 1);
        noise(noise < 0.5) = 0.5;  % clamp to avoid negative
        concs{ei} = concs{ei} .* noise;
    end

    % Build CSV lines
    elemRow = 'H,,C,,O,,F,,N,,AL->,,Si->,,Ta->';
    labelRow = 'Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.,Depth,CONC.';
    unitRow  = '(nm),(atoms/cc),(nm),(atoms/cc),(nm),(atoms/cc),(nm),(atoms/cc),(nm),(atoms/cc),(nm),(arb. units),(nm),(arb. units),(nm),(arb. units)';

    dataLines = cell(nPts, 1);
    for ri = 1:nPts
        parts = cell(1, 8);
        for ei = 1:8
            parts{ei} = sprintf('%.5g,%.4E', depths{ei}(ri), concs{ei}(ri));
        end
        dataLines{ri} = strjoin(parts, ',');
    end

    allLines = [
        {'Eurofins EAG Materials Science, LLC'}
        {':Sample 2829'}
        {'2/17/2026'}
        {'Drawn Curves,8'}
        {sprintf('Num of Cycles,%d', nPts)}
        {''}
        {elemRow}
        {labelRow}
        {unitRow}
        {''}
        dataLines
    ];
    fp = writeTempCSV('sims_t9_vendor_multirow', allLines);
    tmpFiles{end+1} = fp;
    d = parser.importSIMS(fp);

    % 8 element pairs (H, C, O, F, N, Al, Si, Ta)
    assert(numel(d.labels) == 8, ...
        sprintf('Expected 8 elements, got %d', numel(d.labels)));
    assert(d.metadata.parserSpecific.isPairedLayout, ...
        'Should detect paired layout');

    % Depth grid covers the full 0-200 nm range
    assert(numel(d.time) >= nPts, ...
        sprintf('Expected >= %d depth points, got %d', nPts, numel(d.time)));
    assert(d.time(1) > 0,        'Depth should be positive');
    assert(d.time(end) > 190,    'Depth should extend beyond 190 nm');

    % Concentration units extracted from the units header row
    hasUnits = any(~cellfun(@isempty, d.units));
    assert(hasUnits, 'At least one concentration unit should be non-empty');

    % All valid concentrations should be positive
    assert(all(d.values(~isnan(d.values)) > 0), ...
        'All valid concentrations should be positive');

    % Verify layer structure: Si concentration rises in the substrate
    siCol = find(contains(d.labels, 'Si'), 1);
    assert(~isempty(siCol), 'Si column not found');
    surfaceSi  = mean(d.values(d.time < 20, siCol), 'omitnan');
    substrateSi = mean(d.values(d.time > 170, siCol), 'omitnan');
    assert(substrateSi > 100 * surfaceSi, ...
        'Si should be >100× higher in substrate than at surface');

    % Verify Ta has two peaks (cap + barrier)
    taCol = find(contains(d.labels, 'Ta'), 1);
    assert(~isempty(taCol), 'Ta column not found');
    taCap     = max(d.values(d.time < 40, taCol));
    taMid     = min(d.values(d.time > 60 & d.time < 100, taCol));
    taBarrier = max(d.values(d.time > 120 & d.time < 160, taCol));
    assert(taCap > 10 * taMid && taBarrier > 10 * taMid, ...
        'Ta should show two distinct peaks (cap + barrier)');

    % Metadata captured
    hm = d.metadata.parserSpecific.headerMetadata;
    assert(~isempty(hm), 'Header metadata should not be empty');
    allMeta = strjoin(hm, ' ');
    assert(contains(allMeta, 'Sample 2829'), ...
        'Sample ID should appear in header metadata');
    assert(contains(allMeta, 'Eurofins'), ...
        'Company name should appear in header metadata');

    rng('default');  % restore RNG state
    nPass = nPass + 1;
    fprintf('  ✔ Test 9: vendor multi-row header (thin-film stack, %d pts × 8 elements)\n', nPts);
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ Test 9: %s\n', ME.message);
    rng('default');
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
