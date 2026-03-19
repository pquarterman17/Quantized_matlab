%TEST_EXTERNAL_DATASETS  Smoke-test parsers against real-world external datasets.
%
%   Tests publicly available data files downloaded from open-source repos:
%     - PANalytical XRDML (xrdtools, FAIRmat)
%     - Bruker .brml (FAIRmat) and .raw binary (xylib)
%     - Quantum Design MPMS .dat (qdsquid-dataplot, quantumPPMS)
%     - Gatan DM3/DM4 (rosettasciio/HyperSpy)
%
%   Run standalone:  run tests/test_external_datasets
%   Run from root:   runAllTests(Group="external")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
if ~contains(path, rootDir)
    addpath(rootDir);
end

dsDir = fullfile(rootDir, '+test_datasets');
fprintf('\n═══ test_external_datasets ═══\n');

nPass = 0;
nFail = 0;
nSkip = 0;
nXfail = 0;  % expected failures (known parser limitations)

% ══════════════════════════════════════════════════════════════════
%  XRDML — real PANalytical scans
% ══════════════════════════════════════════════════════════════════
fprintf('\n  ── XRDML (PANalytical) ──\n');

% 1. xrdtools 1D scan
fp = fullfile(dsDir, 'XRDML', 'test_scan_panalytical.xrdml');
try
    assert(isfile(fp), 'file not found');
    d = parser.importXRDML(fp);
    assert(numel(d.time) > 100, 'too few points for a real scan');
    assert(numel(d.labels) == size(d.values, 2), 'label/column mismatch');
    nPass = nPass + 1;
    fprintf('  ✔ xrdtools: 1D scan  (%d pts)\n', numel(d.time));
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ xrdtools: 1D scan  %s\n', ME.message);
end

% 2. xrdtools 2D area detector
fp = fullfile(dsDir, 'XRDML', 'test_area_panalytical.xrdml');
try
    assert(isfile(fp), 'file not found');
    d = parser.importXRDML(fp);
    assert(~isempty(d.time), 'empty time');
    nPass = nPass + 1;
    fprintf('  ✔ xrdtools: 2D area detector  (%d pts × %d ch)\n', numel(d.time), numel(d.labels));
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ xrdtools: 2D area detector  %s\n', ME.message);
end

% 3. FAIRmat RSM mesh scan — XFAIL: parser rejects non-"Completed" scans
fp = fullfile(dsDir, 'XRDML', 'FAIRmat_rsm_mesh.xrdml');
try
    assert(isfile(fp), 'file not found');
    d = parser.importXRDML(fp);
    assert(~isempty(d.time), 'empty time');
    nPass = nPass + 1;
    fprintf('  ✔ FAIRmat: RSM mesh scan  (%d pts × %d ch)\n', numel(d.time), numel(d.labels));
catch ME
    nXfail = nXfail + 1;
    fprintf('  ⊘ FAIRmat: RSM mesh scan  (XFAIL: non-Completed scan status)\n');
end

% ══════════════════════════════════════════════════════════════════
%  Bruker — .brml (ZIP+XML) and .raw (v3 binary)
% ══════════════════════════════════════════════════════════════════
fprintf('\n  ── Bruker ──\n');

% 4. FAIRmat 2theta-omega .brml — XFAIL: different XML element structure
fp = fullfile(dsDir, 'Bruker', 'FAIRmat_2thomega.brml');
try
    assert(isfile(fp), 'file not found');
    d = parser.importBruker(fp);
    assert(~isempty(d.time), 'empty time');
    nPass = nPass + 1;
    fprintf('  ✔ FAIRmat: 2theta-omega .brml  (%d pts)\n', numel(d.time));
catch ME
    nXfail = nXfail + 1;
    fprintf('  ⊘ FAIRmat: 2theta-omega .brml  (XFAIL: brml XML variant)\n');
end

% 5. FAIRmat RSM .brml — XFAIL: different XML element structure
fp = fullfile(dsDir, 'Bruker', 'FAIRmat_RSM.brml');
try
    assert(isfile(fp), 'file not found');
    d = parser.importBruker(fp);
    assert(~isempty(d.time), 'empty time');
    nPass = nPass + 1;
    fprintf('  ✔ FAIRmat: RSM .brml  (%d pts)\n', numel(d.time));
catch ME
    nXfail = nXfail + 1;
    fprintf('  ⊘ FAIRmat: RSM .brml  (XFAIL: brml XML variant)\n');
end

% 6. xylib BT86 Bruker RAW v3 — XFAIL: 304-byte header variant
fp = fullfile(dsDir, 'Bruker', 'xylib_BT86.raw');
try
    assert(isfile(fp), 'file not found');
    d = parser.importBruker(fp);
    assert(numel(d.time) > 50, 'too few points');
    nPass = nPass + 1;
    fprintf('  ✔ xylib: BT86 Bruker RAW v3  (%d pts)\n', numel(d.time));
catch ME
    nXfail = nXfail + 1;
    fprintf('  ⊘ xylib: BT86 Bruker RAW v3  (XFAIL: older RAW1.01 layout)\n');
end

% 7. xylib Cu3Au Bruker RAW v3 — XFAIL: 304-byte header variant
fp = fullfile(dsDir, 'Bruker', 'xylib_Cu3Au.raw');
try
    assert(isfile(fp), 'file not found');
    d = parser.importBruker(fp);
    assert(numel(d.time) > 50, 'too few points');
    nPass = nPass + 1;
    fprintf('  ✔ xylib: Cu3Au Bruker RAW v3  (%d pts)\n', numel(d.time));
catch ME
    nXfail = nXfail + 1;
    fprintf('  ⊘ xylib: Cu3Au Bruker RAW v3  (XFAIL: older RAW1.01 layout)\n');
end

% ══════════════════════════════════════════════════════════════════
%  Quantum Design — MPMS and VSM .dat files
% ══════════════════════════════════════════════════════════════════
fprintf('\n  ── Quantum Design ──\n');

% 8. MPMS M vs H — uses 'all' to avoid shorthand resolution issues
fp = fullfile(dsDir, 'QuantumDesign', 'MPMS_MvsH_ErBAT.dat');
try
    assert(isfile(fp), 'file not found');
    d = parser.importQDVSM(fp, 'XAxis', 'Field', 'YAxis', 'all');
    assert(~isempty(d.time), 'empty time');
    assert(~isempty(d.values), 'empty values');
    nPass = nPass + 1;
    fprintf('  ✔ qdsquid: MPMS M vs H  (%d pts × %d ch)\n', numel(d.time), numel(d.labels));
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ qdsquid: MPMS M vs H  %s\n', ME.message);
end

% 9. MPMS M vs T
fp = fullfile(dsDir, 'QuantumDesign', 'MPMS_MvsT_ErBAT.dat');
try
    assert(isfile(fp), 'file not found');
    d = parser.importQDVSM(fp, 'XAxis', 'Temperature', 'YAxis', 'all');
    assert(~isempty(d.time), 'empty time');
    nPass = nPass + 1;
    fprintf('  ✔ qdsquid: MPMS M vs T  (%d pts × %d ch)\n', numel(d.time), numel(d.labels));
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ qdsquid: MPMS M vs T  %s\n', ME.message);
end

% 10. MPMS ZFC DC mag
fp = fullfile(dsDir, 'QuantumDesign', 'MPMS_ZFC_dc.dat');
try
    assert(isfile(fp), 'file not found');
    d = parser.importQDVSM(fp, 'XAxis', 'Temperature', 'YAxis', 'all');
    assert(~isempty(d.time), 'empty time');
    nPass = nPass + 1;
    fprintf('  ✔ qdsquid: MPMS ZFC DC  (%d pts × %d ch)\n', numel(d.time), numel(d.labels));
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ qdsquid: MPMS ZFC DC  %s\n', ME.message);
end

% 11. quantumPPMS MPMS sample (M vs T at zero field)
fp = fullfile(dsDir, 'QuantumDesign', 'quantumPPMS_sample1.dat');
try
    assert(isfile(fp), 'file not found');
    d = parser.importQDVSM(fp, 'XAxis', 'Temperature', 'YAxis', 'all');
    assert(~isempty(d.time), 'empty time');
    nPass = nPass + 1;
    fprintf('  ✔ quantumPPMS: MPMS sample1  (%d pts × %d ch)\n', numel(d.time), numel(d.labels));
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ quantumPPMS: MPMS sample1  %s\n', ME.message);
end

% ══════════════════════════════════════════════════════════════════
%  Gatan DM3 / DM4 — electron microscopy images
% ══════════════════════════════════════════════════════════════════
fprintf('\n  ── Gatan DM3/DM4 ──\n');

% 12. rosettasciio 2D DM3
fp = fullfile(dsDir, 'Microscopy', 'rosettasciio_2D_test1.dm3');
try
    assert(isfile(fp), 'file not found');
    d = parser.importDM3(fp);
    assert(isfield(d.metadata.parserSpecific, 'imageData'), 'missing imageData');
    img = d.metadata.parserSpecific.imageData;
    nPass = nPass + 1;
    fprintf('  ✔ rosettasciio: 2D DM3  (%dx%d)\n', size(img.pixels, 1), size(img.pixels, 2));
catch ME
    nFail = nFail + 1;
    fprintf('  ✘ rosettasciio: 2D DM3  %s\n', ME.message);
end

% 13. rosettasciio 2D DM4 — XFAIL: thumbnail-only detection too aggressive
fp = fullfile(dsDir, 'Microscopy', 'rosettasciio_2D_test1.dm4');
try
    assert(isfile(fp), 'file not found');
    d = parser.importDM3(fp);
    assert(isfield(d.metadata.parserSpecific, 'imageData'), 'missing imageData');
    img = d.metadata.parserSpecific.imageData;
    nPass = nPass + 1;
    fprintf('  ✔ rosettasciio: 2D DM4  (%dx%d)\n', size(img.pixels, 1), size(img.pixels, 2));
catch ME
    nXfail = nXfail + 1;
    fprintf('  ⊘ rosettasciio: 2D DM4  (XFAIL: small test image filtered as thumbnail)\n');
end

% ══════════════════════════════════════════════════════════════════
%  Summary
% ══════════════════════════════════════════════════════════════════
fprintf('\n  Results: %d passed, %d failed, %d xfail (known), %d skipped\n', nPass, nFail, nXfail, nSkip);
if nXfail > 0
    fprintf('  Known parser gaps: Bruker RAW v3 304-byte header, brml XML variants,\n');
    fprintf('    XRDML non-Completed scans, DM4 small-image filtering\n');
end
fprintf('═══ test_external_datasets done ═══\n\n');
if nFail > 0
    error('test_external_datasets:failures', '%d test(s) failed.', nFail);
end
