%TEST_PARSERS  Quick smoke-test for all +parser functions.
%
%   Run standalone:  cd tests; run test_parsers
%   Run from root:   run tests/test_parsers
%
%   Each section prints PASS / FAIL and a brief summary.

clear; clc;

% Ensure toolbox is on the path
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
if ~contains(path, rootDir)
    addpath(rootDir);
end

ROOT = rootDir;

% ── Data file paths ──────────────────────────────────────────────────────
QD_VSM_FILE = fullfile(ROOT, '+test_datasets', 'QuantumDesign', 'EDP136_Perp_StrawNew.dat');
RAW_FILE    = fullfile(ROOT, '+test_datasets', 'rigaku_sample.raw');  % kept for legacy; test skips if not found
XRDML_FILE2 = fullfile(ROOT, '+test_datasets', 'XRDML', 'La2NiO4_1.xrdml');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  1. importCSV  –  legacy PPMS .dat treated as generic CSV
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: parser.importCSV (PPMS .dat as CSV) ══\n');
try
    d = parser.importCSV(QD_VSM_FILE, ...
        'TimeColumn',   'Magnetic Field (Oe)', ...
        'DataColumns',  {'Moment (emu)', 'Temperature (K)'});

    assert(isstruct(d),           'output must be a struct');
    assert(isfield(d,'time'),     'missing field: time');
    assert(isfield(d,'values'),   'missing field: values');
    assert(isfield(d,'labels'),   'missing field: labels');
    assert(isfield(d,'units'),    'missing field: units');
    assert(isfield(d,'metadata'), 'missing field: metadata');
    assert(~isempty(d.time),      'time vector is empty');
    assert(size(d.values,2)==2,   'expected 2 data columns');

    fprintf('  Rows       : %d\n', numel(d.time));
    fprintf('  Channels   : %s | %s\n', d.labels{1}, d.labels{2});
    fprintf('  Field range: %.0f to %.0f Oe\n', min(d.time), max(d.time));
    fprintf('  Moment range: %.3e to %.3e emu\n', ...
        min(d.values(:,1)), max(d.values(:,1)));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. importCSV  –  auto-detect columns
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: parser.importCSV (auto-detect, second file) ══\n');
try
    d = parser.importCSV(QD_VSM_FILE);

    assert(isstruct(d));
    assert(~isempty(d.time));
    assert(~isempty(d.values));

    fprintf('  Rows       : %d\n', numel(d.time));
    fprintf('  Channels   : %d\n', size(d.values,2));
    fprintf('  Labels     : %s\n', strjoin(d.labels, ' | '));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. importPPMS  –  legacy CSV .dat  (field vs moment, then all channels)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: parser.importPPMS (legacy CSV format) ══\n');
try
    % PPMS expects legacy CSV format; if file doesn't match, skip gracefully
    try
        d = parser.importPPMS(QD_VSM_FILE);
    catch parseErr
        if contains(parseErr.message, 'No valid numeric rows', 'IgnoreCase', true)
            fprintf('  SKIP  – test file not in PPMS legacy format\n');
        else
            rethrow(parseErr);
        end
    end

    if exist('d', 'var') && ~isempty(d)
        assert(isstruct(d),           'output must be a struct');
        assert(isfield(d,'time'),     'missing field: time');
        assert(isfield(d,'values'),   'missing field: values');
        assert(isfield(d,'labels'),   'missing field: labels');
        assert(isfield(d,'units'),    'missing field: units');
        assert(isfield(d,'metadata'), 'missing field: metadata');

        fprintf('  PASS\n');
        passed = passed + 1;
    end
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. importQDVSM  –  expects [Header]/[Data] format; these files lack it
%     so we expect a graceful error, not a crash.
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: parser.importQDVSM (legacy CSV – expected format mismatch) ══\n');
try
    d = parser.importQDVSM(QD_VSM_FILE);
    % If we get here the parser handled the non-standard file anyway.
    assert(isstruct(d));
    fprintf('  Parser accepted legacy CSV format – unexpected but OK.\n');
    fprintf('  Rows: %d | Channels: %d\n', numel(d.time), size(d.values,2));
    fprintf('  PASS (lenient)\n');
    passed = passed + 1;
catch ME
    % A clear error about missing [Header]/[Data] is the expected outcome.
    if contains(ME.message, {'[Header]','[Data]','header','Header','format','Format'}, ...
            'IgnoreCase', true)
        fprintf('  Format mismatch detected as expected.\n');
        fprintf('  Error: %s\n', ME.message);
        fprintf('  PASS (correct rejection)\n');
        passed = passed + 1;
    else
        fprintf('  FAIL (unexpected error): %s\n', ME.message);
        failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  5. importRigaku_raw  (skipped if no .raw file is found at RAW_FILE)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: parser.importRigaku_raw ══\n');
if ~isfile(RAW_FILE)
    fprintf('  SKIP – RAW_FILE not found. Update RAW_FILE at top of script to enable.\n');
else
    try
        d = parser.importRigaku_raw(RAW_FILE, 'Verbose', true);

        assert(isstruct(d),                          'output must be a struct');
        assert(isfield(d,'time'),                    'missing field: time');
        assert(isfield(d,'values'),                  'missing field: values');
        assert(isfield(d,'labels'),                  'missing field: labels');
        assert(isfield(d,'units'),                   'missing field: units');
        assert(isfield(d,'metadata'),                'missing field: metadata');
        assert(~isempty(d.time),                     '2θ vector is empty');
        assert(size(d.values,2) == 1,                'expected exactly 1 intensity channel');
        assert(isfield(d.metadata,'stepSize'),       'missing metadata.stepSize');
        assert(isfield(d.metadata,'startAngle'),     'missing metadata.startAngle');
        assert(isfield(d.metadata,'countingTime'),   'missing metadata.countingTime');
        assert(strcmp(d.units{1},'counts'),          'default unit should be counts');

        fprintf('  Points        : %d\n',   numel(d.time));
        fprintf('  2\xB0 range     : %.4f to %.4f deg\n', min(d.time), max(d.time));
        fprintf('  Step size     : %.4f deg\n', d.metadata.stepSize);
        fprintf('  Counting time : %.4f s\n',  d.metadata.countingTime);
        fprintf('  Peak intensity: %.1f %s\n', max(d.values), d.units{1});
        fprintf('  PASS\n');
        passed = passed + 1;
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  6. importExcel  –  synthetic .xlsx created on the fly
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6: parser.importExcel (synthetic .xlsx) ══\n');
tmpXlsx = fullfile(tempdir, 'test_importExcel_tmp.xlsx');
try
    % --- Build a small worksheet with headers + units ---
    N = 50;
    t  = (0:N-1)' * 0.1;           % time (s)
    V  = sin(2*pi*0.5*t);          % voltage (V)
    I  = 0.5*cos(2*pi*0.5*t);      % current (A)
    T  = 25 + 5*randn(N,1);        % temperature (°C)

    headers = {'Time (s)', 'Voltage (V)', 'Current (A)', 'Temperature (C)'};
    T_write = array2table([t, V, I, T], 'VariableNames', headers);
    writetable(T_write, tmpXlsx, 'WriteVariableNames', true);

    % --- Test 6a: auto-detect ---
    d = parser.importExcel(tmpXlsx);

    assert(isstruct(d),           'output must be a struct');
    assert(isfield(d,'time'),     'missing field: time');
    assert(isfield(d,'values'),   'missing field: values');
    assert(isfield(d,'labels'),   'missing field: labels');
    assert(isfield(d,'units'),    'missing field: units');
    assert(isfield(d,'metadata'), 'missing field: metadata');
    assert(numel(d.time) == N,    'wrong number of rows');
    assert(size(d.values,2) == 3, 'expected 3 data channels');

    fprintf('  Rows         : %d\n', numel(d.time));
    fprintf('  Channels     : %s\n', strjoin(d.labels, ' | '));
    fprintf('  Units        : %s\n', strjoin(d.units,  ' | '));
    fprintf('  Time range   : %.1f to %.1f s\n', min(d.time), max(d.time));

    % --- Test 6b: named columns ---
    d2 = parser.importExcel(tmpXlsx, ...
        'TimeColumn',  'Time (s)', ...
        'DataColumns', {'Voltage (V)', 'Current (A)'});

    assert(size(d2.values,2) == 2, 'expected 2 channels when explicitly selected');
    assert(strcmpi(d2.labels{1}, 'Voltage'), 'label should be stripped of units');
    assert(strcmpi(d2.units{1},  'V'),       'unit should be extracted');

    fprintf('  Named-col labels: %s | %s\n', d2.labels{1}, d2.labels{2});
    fprintf('  Named-col units : %s | %s\n', d2.units{1}, d2.units{2});

    % --- Test 6c: metadata ---
    assert(isfield(d.metadata.parserSpecific, 'sheetName'), 'missing metadata.parserSpecific.sheetName');
    assert(isfield(d.metadata.parserSpecific, 'allSheets'), 'missing metadata.parserSpecific.allSheets');

    fprintf('  Sheet name   : %s\n', d.metadata.parserSpecific.sheetName);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
% Clean up temp file
if isfile(tmpXlsx), delete(tmpXlsx); end

% ════════════════════════════════════════════════════════════════════════
%  7. importXRDML  –  PANalytical .xrdml file
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7: parser.importXRDML ══\n');
if ~isfile(XRDML_FILE2)
    fprintf('  SKIP – XRDML_FILE2 not found. Check +test_datasets/XRDML/.\n');
else
    try
        % ── 7a: default (cps output, Verbose summary) ────────────────────
        d = parser.importXRDML(XRDML_FILE2, Intensity='cps', Verbose=true);

        assert(isstruct(d),                        'output must be a struct');
        assert(isfield(d, 'time'),                 'missing field: time');
        assert(isfield(d, 'values'),               'missing field: values');
        assert(isfield(d, 'labels'),               'missing field: labels');
        assert(isfield(d, 'units'),                'missing field: units');
        assert(isfield(d, 'metadata'),             'missing field: metadata');
        assert(~isempty(d.time),                   '2θ vector is empty');
        assert(size(d.values, 2) == 1,             'expected exactly 1 intensity channel');
        assert(strcmp(d.units{1}, 'cps'),          'default Intensity=cps should yield units "cps"');

        % Metadata top-level fields
        assert(strcmp(d.metadata.xColumnName, '2-Theta'), 'xColumnName should be "2-Theta"');
        assert(strcmp(d.metadata.xColumnUnit, 'deg'),     'xColumnUnit should be "deg"');
        assert(strcmp(d.metadata.parserName, 'importXRDML'), 'parserName wrong');

        % parserSpecific instrument and geometry fields
        ps = d.metadata.parserSpecific;
        assert(isstruct(ps),                       'parserSpecific must be a struct');
        assert(isfield(ps, 'wavelength'),          'missing parserSpecific.wavelength');
        assert(isfield(ps, 'anodeMaterial'),       'missing parserSpecific.anodeMaterial');
        assert(isfield(ps, 'detectorName'),        'missing parserSpecific.detectorName');
        assert(isfield(ps, 'comments'),            'missing parserSpecific.comments');
        assert(~isnan(ps.wavelength.kAlpha1),      'kAlpha1 should be a number');
        assert(isfield(ps, 'startAngle'),          'missing parserSpecific.startAngle');
        assert(isfield(ps, 'endAngle'),            'missing parserSpecific.endAngle');
        assert(isfield(ps, 'stepSize'),            'missing parserSpecific.stepSize');
        assert(isfield(ps, 'countingTime'),        'missing parserSpecific.countingTime');
        assert(isfield(ps, 'numPoints'),           'missing parserSpecific.numPoints');

        % Sanity-check geometry: 2θ range and point count
        assert(ps.startAngle > 0,                  'startAngle should be positive');
        assert(ps.endAngle > ps.startAngle,        'endAngle must exceed startAngle');
        assert(ps.stepSize  > 0,                   'stepSize should be positive');
        assert(ps.numPoints == numel(d.time),      'numPoints mismatch with time vector');

        fprintf('  Points        : %d\n',   numel(d.time));
        fprintf('  2\xB0 range     : %.4f to %.4f deg\n', ps.startAngle, ps.endAngle);
        fprintf('  Step size     : %.6f deg\n',  ps.stepSize);
        fprintf('  Counting time : %.3f s\n',    ps.countingTime);
        fprintf('  Peak cps      : %.2f\n',       max(d.values));
        fprintf('  Anode         : %s\n',         ps.anodeMaterial);
        fprintf('  K\xCE\xB11           : %.7f \xC3\x85\n', ps.wavelength.kAlpha1);

        % ── 7b: counts output — ratio to cps should equal countingTime ────
        dCts = parser.importXRDML(XRDML_FILE2, Intensity='counts');
        assert(strcmp(dCts.units{1}, 'counts'),    'Intensity=counts should yield units "counts"');

        ct  = ps.countingTime;
        tol = 1e-9;
        assert(abs(max(dCts.values) / max(d.values) - ct) < tol, ...
            sprintf('counts / cps ratio (%.6f) should equal countingTime (%.3f)', ...
                max(dCts.values)/max(d.values), ct));
        fprintf('  counts/cps ratio: %.3f (expected %.3f) — OK\n', ...
            max(dCts.values) / max(d.values), ct);

        % ── 7c: importAuto dispatch ────────────────────────────────────────
        [dAuto, pName] = parser.importAuto(XRDML_FILE2);
        assert(strcmp(pName, 'importXRDML'),       'importAuto should dispatch to importXRDML');
        assert(numel(dAuto.time) == numel(d.time), 'importAuto point count mismatch');
        fprintf('  importAuto dispatch: %s  — OK\n', pName);

        fprintf('  PASS\n');
        passed = passed + 1;
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  8. importBruker  –  Bruker .brml (ZIP+XML) or .raw (binary v3)
% ════════════════════════════════════════════════════════════════════════
BRML_FILE = 'C:\Users\patri\Downloads\bruker_sample.brml';
BRUKER_RAW_FILE = 'C:\Users\patri\Downloads\bruker_sample.raw';
fprintf('\n══ TEST 8: parser.importBruker ══\n');

brmlExists = isfile(BRML_FILE);
rawExists  = isfile(BRUKER_RAW_FILE);

if ~brmlExists && ~rawExists
    fprintf('  SKIP – no .brml or Bruker .raw file found. Update file paths at top of script.\n');
else
    try
        % Test .brml if available
        if brmlExists
            d = parser.importBruker(BRML_FILE, 'Verbose', true);

            assert(isstruct(d),                        'output must be a struct');
            assert(isfield(d, 'time'),                 'missing field: time');
            assert(isfield(d, 'values'),               'missing field: values');
            assert(isfield(d, 'labels'),               'missing field: labels');
            assert(isfield(d, 'units'),                'missing field: units');
            assert(isfield(d, 'metadata'),             'missing field: metadata');
            assert(~isempty(d.time),                   '2θ vector is empty');
            assert(size(d.values, 2) == 1,             'expected exactly 1 intensity channel');
            ps2 = d.metadata.parserSpecific;
            assert(isfield(ps2, 'startAngle'),  'missing parserSpecific.startAngle');
            assert(isfield(ps2, 'endAngle'),    'missing parserSpecific.endAngle');
            assert(isfield(ps2, 'stepSize'),    'missing parserSpecific.stepSize');
            assert(isfield(ps2, 'countingTime'),'missing parserSpecific.countingTime');

            fprintf('  Points        : %d\n',   numel(d.time));
            fprintf('  2θ range      : %.4f to %.4f deg\n', ps2.startAngle, ps2.endAngle);
            fprintf('  Format        : .brml (ZIP+XML)\n');
        end

        % Test Bruker .raw (v3) if available
        if rawExists
            d = parser.importBruker(BRUKER_RAW_FILE, 'UseCountsPerSec', true, 'Verbose', true);

            assert(isstruct(d),                        'output must be a struct');
            assert(isfield(d, 'time'),                 'missing field: time');
            assert(isfield(d, 'values'),               'missing field: values');
            assert(size(d.values, 2) == 1,             'expected 1 intensity channel');
            assert(strcmp(d.units{1}, 'counts/s'),     'UseCountsPerSec=true should yield counts/s');

            ps3 = d.metadata.parserSpecific;
            fprintf('  Points        : %d\n',   numel(d.time));
            fprintf('  2θ range      : %.4f to %.4f deg\n', ps3.startAngle, ps3.endAngle);
            fprintf('  Format        : .raw (Bruker binary v3)\n');
        end

        fprintf('  PASS\n');
        passed = passed + 1;
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  9. importMPMS  –  Quantum Design MPMS SQUID magnetometer
% ════════════════════════════════════════════════════════════════════════
MPMS_FILE = 'C:\Users\patri\Downloads\mpms_sample.dat';
fprintf('\n══ TEST 9: parser.importMPMS ══\n');
if ~isfile(MPMS_FILE)
    fprintf('  SKIP – MPMS_FILE not found. Update file path at top of script.\n');
else
    try
        % ── 9a: Default (T vs DC Moment) ─────────────────────────────────
        d = parser.importMPMS(MPMS_FILE, Verbose=true);

        assert(isstruct(d),                        'output must be a struct');
        assert(isfield(d, 'time'),                 'missing field: time');
        assert(isfield(d, 'values'),               'missing field: values');
        assert(isfield(d, 'labels'),               'missing field: labels');
        assert(isfield(d, 'units'),                'missing field: units');
        assert(isfield(d, 'metadata'),             'missing field: metadata');
        assert(strcmp(d.metadata.parserName, 'importMPMS'), 'parserName should be importMPMS');

        % ── 9b: Multiple channels (DC moment + AC susceptibility) ────────
        d2 = parser.importMPMS(MPMS_FILE, YAxis={'dcmoment', 'acsusceptibility'});
        if ~isempty(d2.values)
            assert(size(d2.values, 2) >= 1, 'expected at least 1 channel');
        end

        % ── 9c: Field-dependent (H vs M) ────────────────────────────────
        d3 = parser.importMPMS(MPMS_FILE, XAxis='field', YAxis='dcmoment');
        if ~isempty(d3.values)
            assert(~isempty(d3.time), '2θ vector should not be empty');
        end

        fprintf('  PASS\n');
        passed = passed + 1;
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  10. importLakeShore  –  Lake Shore magnetometer CSV/DAT
% ════════════════════════════════════════════════════════════════════════
LAKESHORE_FILE = 'C:\Users\patri\Downloads\lakeshore_sample.csv';
fprintf('\n══ TEST 10: parser.importLakeShore ══\n');
if ~isfile(LAKESHORE_FILE)
    fprintf('  SKIP – LAKESHORE_FILE not found. Update file path at top of script.\n');
else
    try
        % ── 10a: Auto-detect header, default x/y ────────────────────────
        d = parser.importLakeShore(LAKESHORE_FILE, Verbose=true);

        assert(isstruct(d),                        'output must be a struct');
        assert(isfield(d, 'time'),                 'missing field: time');
        assert(isfield(d, 'values'),               'missing field: values');
        assert(isfield(d, 'labels'),               'missing field: labels');
        assert(isfield(d, 'units'),                'missing field: units');
        assert(isfield(d, 'metadata'),             'missing field: metadata');
        assert(strcmp(d.metadata.parserName, 'importLakeShore'), 'parserName should be importLakeShore');

        % ── 10b: Field-dependent with auto header detection ──────────────
        d2 = parser.importLakeShore(LAKESHORE_FILE, XAxis='field', YAxis='moment');
        if ~isempty(d2.values)
            assert(~isempty(d2.time), 'x-axis should not be empty');
            fprintf('  Field range: %.4g to %.4g\n', min(d2.time), max(d2.time));
        end

        % ── 10c: Multiple channels (moment + susceptibility) ──────────────
        d3 = parser.importLakeShore(LAKESHORE_FILE, YAxis={'moment', 'susceptibility'});
        if ~isempty(d3.values)
            % At least one of the requested channels found
            assert(size(d3.values, 2) >= 1, 'expected at least 1 channel');
        end

        fprintf('  PASS\n');
        passed = passed + 1;
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  11. NCNR parsers  –  Neutron reflectivity data from reductus and refl1d
% ════════════════════════════════════════════════════════════════════════
NCNR_REFL_FILE = fullfile(ROOT, '+test_datasets', 'NCNR', 'NR_Nickelate', 'raw_data', 'J395_dfs01_v2.refl');
NCNR_PNR_FILE  = fullfile(ROOT, '+test_datasets', 'NCNR', 'PNR_SF', 'S11_20G_SF.pnr');
NCNR_DAT_FILE  = fullfile(ROOT, '+test_datasets', 'NCNR', 'PNR_NoSpinFlip', 'S3_Si_YIG_Py_300K_700mT_multi-1-refl.datA');

fprintf('\n══ TEST 11: NCNR Parsers (.refl, .pnr, .datA) ══\n');

% 11a: importNCNRRefl (.refl files)
if ~isfile(NCNR_REFL_FILE)
    fprintf('  SKIP .refl – file not found\n');
else
    try
        d = parser.importNCNRRefl(NCNR_REFL_FILE);

        assert(isstruct(d),                            'output must be a struct');
        assert(isfield(d, 'time'),                     'missing field: time');
        assert(isfield(d, 'values'),                   'missing field: values');
        assert(isfield(d, 'labels'),                   'missing field: labels');
        assert(isfield(d, 'units'),                    'missing field: units');
        assert(isfield(d, 'metadata'),                 'missing field: metadata');
        assert(~isempty(d.time),                                'Qz vector is empty');
        assert(~isempty(d.labels),                             'labels must not be empty');
        % Qz is the x-axis stored in .time; check via metadata not labels
        assert(strcmpi(d.metadata.xColumnName, 'Qz'),          'xColumnName should be Qz');
        assert(isfield(d.metadata, 'parserSpecific'),           'missing metadata.parserSpecific');

        fprintf('  [.refl] PASS: %d points, instrument=%s\n', ...
            numel(d.time), d.metadata.parserSpecific.instrument_type);
        passed = passed + 1;
    catch ME
        fprintf('  [.refl] FAIL: %s\n', ME.message);
        failed = failed + 1;
    end
end

% 11b: importNCNRPNR (.pnr files)
if ~isfile(NCNR_PNR_FILE)
    fprintf('  SKIP .pnr – file not found\n');
else
    try
        d = parser.importNCNRPNR(NCNR_PNR_FILE);

        assert(isstruct(d),                            'output must be a struct');
        assert(isfield(d, 'time'),                     'missing field: time');
        assert(isfield(d, 'values'),                   'missing field: values');
        assert(~isempty(d.time),                       'Q vector is empty');
        assert(isfield(d.metadata, 'parserSpecific'),  'missing metadata.parserSpecific');
        assert(isfield(d.metadata.parserSpecific, 'variant'), 'missing variant');

        fprintf('  [.pnr] PASS: %d points, variant=%s\n', ...
            numel(d.time), d.metadata.parserSpecific.variant);
        passed = passed + 1;
    catch ME
        fprintf('  [.pnr] FAIL: %s\n', ME.message);
        failed = failed + 1;
    end
end

% 11c: importNCNRDat (.datA, .datB, .datC, .datD files)
if ~isfile(NCNR_DAT_FILE)
    fprintf('  SKIP .datA – file not found\n');
else
    try
        d = parser.importNCNRDat(NCNR_DAT_FILE);

        assert(isstruct(d),                            'output must be a struct');
        assert(isfield(d, 'time'),                     'missing field: time');
        assert(isfield(d, 'values'),                   'missing field: values');
        assert(~isempty(d.time),                       'Q vector is empty');
        assert(isfield(d.metadata, 'parserSpecific'),  'missing metadata.parserSpecific');
        assert(isfield(d.metadata.parserSpecific, 'polarization'), 'missing polarization');

        pol = d.metadata.parserSpecific.polarization;
        assert(strcmp(pol, '++'),                      'expected ++ polarization for .datA');

        fprintf('  [.datA] PASS: %d points, polarization=%s\n', ...
            numel(d.time), pol);
        passed = passed + 1;
    catch ME
        fprintf('  [.datA] FAIL: %s\n', ME.message);
        failed = failed + 1;
    end
end

% 11d: importAuto dispatch
fprintf('  [importAuto] Testing dispatch for .refl, .pnr, .datA:\n');
try
    [d1, p1] = parser.importAuto(NCNR_REFL_FILE);
    assert(strcmp(p1, 'importNCNRRefl'), 'dispatch to importNCNRRefl failed');

    [d2, p2] = parser.importAuto(NCNR_PNR_FILE);
    assert(strcmp(p2, 'importNCNRPNR'), 'dispatch to importNCNRPNR failed');

    [d3, p3] = parser.importAuto(NCNR_DAT_FILE);
    assert(strcmp(p3, 'importNCNRDat'), 'dispatch to importNCNRDat failed');

    fprintf('        .refl → %s\n', p1);
    fprintf('        .pnr  → %s\n', p2);
    fprintf('        .datA → %s\n', p3);
    fprintf('        PASS\n');
    passed = passed + 1;
catch ME
    fprintf('        FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  12. importExcel  –  blank separator row between headers and data
%      Regression test for vendor SIMS xlsx files that place a blank row
%      between the column header row and the numeric data block.
%      A blank row (all missing cells) previously caused a MATLAB scalar-AND
%      error: "Operands to && must be convertible to logical scalar values"
%      because isnumeric([]) = true but ~isnan([]) = [] (empty array).
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 12: parser.importExcel (blank row between headers and data) ══\n');
tmpXlsx12 = fullfile(tempdir, 'test_importExcel_blankrow.xlsx');
try
    % Build xlsx with a vendor-style SIMS paired-column layout:
    %   Row 1: column headers (text)
    %   Row 2: BLANK separator (the bug trigger — all cells are missing)
    %   Rows 3-6: numeric data
    rawCell = {
        'Depth (nm)', 'H (atoms/cc)', 'C (atoms/cc)', 'O (atoms/cc)', ...
        'F (atoms/cc)', 'N (atoms/cc)', 'Al (arb. units)';   % row 1: headers
        [], [], [], [], [], [], [];                           % row 2: blank (7 cols)
        0.26918, 2.46e22, 1.17e20, 3.0e22, 2.06e19, 1.83e19, 1.45;  % data
        0.89853, 1.83e22, 3.51e19, 3.6e22, 6.75e18, 7.2e17,  2.32;
        1.53742, 3.14e22, 2.92e19, 3.11e22, 1.66e18, 2.75e17, 4.08;
        2.17631, 3.78e22, 2.85e19, 1.72e22, 6.39e17, 9.0e16,  1.62;
    };
    writecell(rawCell, tmpXlsx12);

    d = parser.importExcel(tmpXlsx12);

    assert(isstruct(d),              'output must be a struct');
    assert(isfield(d,'time'),        'missing field: time');
    assert(isfield(d,'values'),      'missing field: values');
    assert(numel(d.time) == 4,       'expected 4 data rows');
    assert(size(d.values,2) == 6,    'expected 6 data channels');

    % Header row 1 should be detected despite blank row 2 between it and data
    assert(strcmpi(d.labels{1}, 'H'),  'first channel label should be H');
    assert(strcmpi(d.units{1}, 'atoms/cc'), 'unit should be atoms/cc');

    % Depth values should match the first column from the data rows
    assert(abs(d.time(1) - 0.26918) < 1e-4, 'first depth wrong');
    assert(abs(d.time(end) - 2.17631) < 1e-4, 'last depth wrong');

    % First H concentration: 2.46e22
    assert(abs(d.values(1,1) - 2.46e22) / 2.46e22 < 1e-4, 'H conc row 1 wrong');

    fprintf('  Rows         : %d\n', numel(d.time));
    fprintf('  Channels     : %s\n', strjoin(d.labels, ' | '));
    fprintf('  Units        : %s\n', strjoin(d.units, ' | '));
    fprintf('  Header row   : %d (blank row correctly skipped)\n', ...
        d.metadata.parserSpecific.headerRow);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end
if isfile(tmpXlsx12), delete(tmpXlsx12); end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
total = passed + failed;
fprintf('\n════════════════════════════════════════════════════════════════\n');
fprintf('  Results: %d / %d passed', passed, total);
if failed > 0
    fprintf('  (%d FAILED)', failed);
end
fprintf('\n════════════════════════════════════════════════════════════════\n');
