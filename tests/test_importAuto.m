%TEST_IMPORTAUTO  Quick manual test of parser.importAuto dispatch.
clear; clc;

ROOT = fileparts(fileparts(mfilename('fullpath')));  % go up from tests/ to project root
addpath(ROOT);   % ensure +parser packages are on path
DAT1 = fullfile(ROOT, '+test_datasets', 'QuantumDesign', 'EDP136_Perp_StrawNew.dat');
RAW1 = fullfile(ROOT, '+test_datasets', 'rigaku_sample.raw');

passed = 0; failed = 0;

% ── PPMS legacy .dat (default: field vs moment) ───────────────────
fprintf('=== 1. PPMS legacy .dat (field/moment) ===\n');
try
    d = parser.importAuto(DAT1);
    assert(strcmp(d.metadata.xColumnName, 'Magnetic Field'));
    assert(size(d.values,2) == 1);
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ── PPMS legacy .dat (all channels) ──────────────────────────────
fprintf('=== 2. PPMS legacy .dat (all channels) ===\n');
try
    d = parser.importAuto(DAT1, 'YAxis', 'all');
    assert(size(d.values,2) > 5);
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ── Synthetic .xlsx ───────────────────────────────────────────────
fprintf('=== 3. Synthetic .xlsx ===\n');
tmpXlsx = fullfile(tempdir, 'importAuto_test.xlsx');
try
    N = 30;
    headers = {'Time (s)', 'Voltage (V)', 'Current (A)'};
    T_write = array2table([(0:N-1)' * 0.05, sin((0:N-1)'*0.5), rand(N,1)], ...
        'VariableNames', headers);
    writetable(T_write, tmpXlsx);

    d = parser.importAuto(tmpXlsx);
    assert(numel(d.time) == N);
    assert(size(d.values,2) == 2);
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end
if isfile(tmpXlsx), delete(tmpXlsx); end

% ── Synthetic .csv ────────────────────────────────────────────────
fprintf('=== 4. Synthetic .csv ===\n');
tmpCsv = fullfile(tempdir, 'importAuto_test.csv');
try
    fid = fopen(tmpCsv, 'w');
    fprintf(fid, 'Time (s),Signal (V),Noise (V)\n');
    for i = 1:20
        fprintf(fid, '%.3f,%.5f,%.5f\n', (i-1)*0.1, sin(i*0.3), rand*0.01);
    end
    fclose(fid);

    d = parser.importAuto(tmpCsv);
    assert(numel(d.time) == 20);
    assert(size(d.values,2) == 2);
    passed = passed + 1;
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end
if isfile(tmpCsv), delete(tmpCsv); end

% ── Rigaku .raw ───────────────────────────────────────────────────
fprintf('=== 5. Rigaku .raw (XRD) ===\n');
try
    if isfile(RAW1)
        d = parser.importAuto(RAW1);
        assert(numel(d.time) > 0,                     'time vector is empty');
        assert(size(d.values,2) == 1,                 'expected 1 intensity channel');
        assert(isfield(d.metadata,'stepSize'),         'missing metadata.stepSize');
        assert(isfield(d.metadata,'startAngle'),       'missing metadata.startAngle');
        assert(isfield(d.metadata,'countingTime'),     'missing metadata.countingTime');
        fprintf('  Points: %d  |  2Th: %.4f to %.4f deg  |  step: %.4f deg\n', ...
            numel(d.time), min(d.time), max(d.time), d.metadata.stepSize);
        passed = passed + 1;
    else
        fprintf('  SKIP (RAW1 not found)\n');
    end
catch ME; fprintf('FAIL: %s\n', ME.message); failed = failed+1; end

% ── Unknown extension (expected rejection) ────────────────────────
fprintf('=== 6. Unknown extension (.md) ===\n');
try
    mdFile = fullfile(ROOT, 'CLAUDE.md');
    if isfile(mdFile)
        parser.importAuto(mdFile);
        fprintf('FAIL: should have errored\n'); failed = failed+1;
    else
        fprintf('  SKIP (CLAUDE.md not found)\n');
    end
catch ME
    if contains(ME.message, 'No parser registered')
        fprintf('  Correctly rejected .md\n');
        passed = passed + 1;
    else
        fprintf('FAIL (wrong error): %s\n', ME.message); failed = failed+1;
    end
end

fprintf('\n--- Results: %d passed, %d failed ---\n', passed, failed);
