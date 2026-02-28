%TEST_PARSERS  Quick smoke-test for all +parser functions.
%
%   Run from the project root:
%       cd G:\Onedrive\Coding\git\thin_film_toolkit_matlab
%       test_parsers
%
%   Each section prints PASS / FAIL and a brief summary.

clear; clc;

ROOT = fileparts(mfilename('fullpath'));

% ── Data file paths ──────────────────────────────────────────────────────
DAT_FILE   = 'G:\Onedrive\Coding\Python\DataPlotting\2449_1B_IP.dat';
DAT_FILE2  = 'G:\Onedrive\Coding\Python\DataPlotting\EDP140_PerpStraw.dat';
RAW_FILE   = 'G:\Onedrive\Work and School Research\NCNR Research\YIG_AF-Coupling-YabinFan\XRD\YIG_Py_S7.raw';
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  1. importCSV  –  legacy PPMS .dat treated as generic CSV
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 1: parser.importCSV (PPMS .dat as CSV) ══\n');
try
    d = parser.importCSV(DAT_FILE, ...
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
    d = parser.importCSV(DAT_FILE2);

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
fprintf('\n══ TEST 3: parser.importPPMS ══\n');
try
    % 3a: default (field vs moment)
    d = parser.importPPMS(DAT_FILE);

    assert(isstruct(d),           'output must be a struct');
    assert(isfield(d,'time'),     'missing field: time');
    assert(isfield(d,'values'),   'missing field: values');
    assert(isfield(d,'labels'),   'missing field: labels');
    assert(isfield(d,'units'),    'missing field: units');
    assert(isfield(d,'metadata'), 'missing field: metadata');
    assert(~isempty(d.time),      'time vector is empty');
    assert(size(d.values,2) == 1, 'expected 1 channel (moment)');

    fprintf('  Rows       : %d\n', numel(d.time));
    fprintf('  X          : %s (%s)\n', d.metadata.xColumnName, d.metadata.xColumnUnit);
    fprintf('  Y          : %s (%s)\n', d.labels{1}, d.units{1});
    fprintf('  Field range: %.0f to %.0f Oe\n', min(d.time), max(d.time));
    fprintf('  Moment range: %.3e to %.3e emu\n', min(d.values), max(d.values));

    % 3b: explicit multi-channel
    d2 = parser.importPPMS(DAT_FILE, 'XAxis', 'time', ...
        'YAxis', {'moment', 'temp', 'field'});

    assert(size(d2.values,2) == 3, 'expected 3 channels');
    assert(strcmpi(d2.labels{1}, 'Moment'),      'label 1 wrong');
    assert(strcmpi(d2.labels{2}, 'Temperature'), 'label 2 wrong');
    assert(strcmpi(d2.labels{3}, 'Magnetic Field'), 'label 3 wrong');

    fprintf('  Multi-channel: %s\n', strjoin(d2.labels, ' | '));

    % 3c: 'all' channels
    d3 = parser.importPPMS(DAT_FILE, 'YAxis', 'all');
    assert(size(d3.values,2) > 3, 'expected >3 channels with YAxis=all');
    fprintf('  ''all'' channels: %d\n', size(d3.values,2));

    fprintf('  PASS\n');
    passed = passed + 1;
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
    d = parser.importQDVSM(DAT_FILE);
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
    assert(isfield(d.metadata, 'sheetName'), 'missing metadata.sheetName');
    assert(isfield(d.metadata, 'allSheets'), 'missing metadata.allSheets');

    fprintf('  Sheet name   : %s\n', d.metadata.sheetName);
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
XRDML_FILE = 'C:\Users\patri\Downloads\La2NiO4_1.xrdml';
fprintf('\n══ TEST 7: parser.importXRDML ══\n');
if ~isfile(XRDML_FILE)
    fprintf('  SKIP – XRDML_FILE not found. Update XRDML_FILE at top of script to enable.\n');
else
    try
        % ── 7a: default (cps output, Verbose summary) ────────────────────
        d = parser.importXRDML(XRDML_FILE, Intensity='cps', Verbose=true);

        assert(isstruct(d),                        'output must be a struct');
        assert(isfield(d, 'time'),                 'missing field: time');
        assert(isfield(d, 'values'),               'missing field: values');
        assert(isfield(d, 'labels'),               'missing field: labels');
        assert(isfield(d, 'units'),                'missing field: units');
        assert(isfield(d, 'metadata'),             'missing field: metadata');
        assert(~isempty(d.time),                   '2θ vector is empty');
        assert(size(d.values, 2) == 1,             'expected exactly 1 intensity channel');
        assert(strcmp(d.units{1}, 'cps'),          'default Intensity=cps should yield units "cps"');

        % Metadata scalar fields (should be directly on metadata, not nested)
        assert(isfield(d.metadata, 'startAngle'),  'missing metadata.startAngle');
        assert(isfield(d.metadata, 'endAngle'),    'missing metadata.endAngle');
        assert(isfield(d.metadata, 'stepSize'),    'missing metadata.stepSize');
        assert(isfield(d.metadata, 'countingTime'),'missing metadata.countingTime');
        assert(isfield(d.metadata, 'numPoints'),   'missing metadata.numPoints');
        assert(strcmp(d.metadata.xColumnName, '2-Theta'), 'xColumnName should be "2-Theta"');
        assert(strcmp(d.metadata.xColumnUnit, 'deg'),     'xColumnUnit should be "deg"');
        assert(strcmp(d.metadata.parserName, 'importXRDML'), 'parserName wrong');

        % Sanity-check geometry: 2θ range and point count
        assert(d.metadata.startAngle > 0,          'startAngle should be positive');
        assert(d.metadata.endAngle > d.metadata.startAngle, 'endAngle must exceed startAngle');
        assert(d.metadata.stepSize  > 0,           'stepSize should be positive');
        assert(d.metadata.numPoints == numel(d.time), 'numPoints mismatch with time vector');

        % parserSpecific instrument fields
        ps = d.metadata.parserSpecific;
        assert(isstruct(ps),                       'parserSpecific must be a struct');
        assert(isfield(ps, 'wavelength'),          'missing parserSpecific.wavelength');
        assert(isfield(ps, 'anodeMaterial'),       'missing parserSpecific.anodeMaterial');
        assert(isfield(ps, 'detectorName'),        'missing parserSpecific.detectorName');
        assert(isfield(ps, 'comments'),            'missing parserSpecific.comments');
        assert(~isnan(ps.wavelength.kAlpha1),      'kAlpha1 should be a number');

        fprintf('  Points        : %d\n',   numel(d.time));
        fprintf('  2\xB0 range     : %.4f to %.4f deg\n', d.metadata.startAngle, d.metadata.endAngle);
        fprintf('  Step size     : %.6f deg\n',  d.metadata.stepSize);
        fprintf('  Counting time : %.3f s\n',    d.metadata.countingTime);
        fprintf('  Peak cps      : %.2f\n',       max(d.values));
        fprintf('  Anode         : %s\n',         ps.anodeMaterial);
        fprintf('  K\xCE\xB11           : %.7f \xC3\x85\n', ps.wavelength.kAlpha1);

        % ── 7b: counts output — ratio to cps should equal countingTime ────
        dCts = parser.importXRDML(XRDML_FILE, Intensity='counts');
        assert(strcmp(dCts.units{1}, 'counts'),    'Intensity=counts should yield units "counts"');

        ct  = d.metadata.countingTime;
        tol = 1e-9;
        assert(abs(max(dCts.values) / max(d.values) - ct) < tol, ...
            sprintf('counts / cps ratio (%.6f) should equal countingTime (%.3f)', ...
                max(dCts.values)/max(d.values), ct));
        fprintf('  counts/cps ratio: %.3f (expected %.3f) — OK\n', ...
            max(dCts.values) / max(d.values), ct);

        % ── 7c: importAuto dispatch ────────────────────────────────────────
        [dAuto, pName] = parser.importAuto(XRDML_FILE);
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
            assert(isfield(d.metadata, 'startAngle'),  'missing metadata.startAngle');
            assert(isfield(d.metadata, 'endAngle'),    'missing metadata.endAngle');
            assert(isfield(d.metadata, 'stepSize'),    'missing metadata.stepSize');
            assert(isfield(d.metadata, 'countingTime'),'missing metadata.countingTime');

            fprintf('  Points        : %d\n',   numel(d.time));
            fprintf('  2θ range      : %.4f to %.4f deg\n', d.metadata.startAngle, d.metadata.endAngle);
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

            fprintf('  Points        : %d\n',   numel(d.time));
            fprintf('  2θ range      : %.4f to %.4f deg\n', d.metadata.startAngle, d.metadata.endAngle);
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
%  Summary
% ════════════════════════════════════════════════════════════════════════
total = passed + failed;
fprintf('\n════════════════════════════════════════════════════════════════\n');
fprintf('  Results: %d / %d passed', passed, total);
if failed > 0
    fprintf('  (%d FAILED)', failed);
end
fprintf('\n════════════════════════════════════════════════════════════════\n');
