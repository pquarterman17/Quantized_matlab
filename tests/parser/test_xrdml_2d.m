%TEST_XRDML_2D  Parser tests for 2D area-detector XRDML support.
%
%   Tests the is2D heuristic, matrix assembly, axis values, 1D integrated
%   fallback, cps normalisation, and backward compatibility with the
%   existing La2NiO4 1D scan file.
%
%   Run standalone:  cd tests; run test_xrdml_2d
%   Run from root:   run tests/test_xrdml_2d

clear; clc;

% Ensure toolbox is on the path
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

ROOT = rootDir;
FILE_1D  = fullfile(ROOT, '+test_datasets', 'XRDML', 'La2NiO4_1.xrdml');
FILE_2D  = fullfile(ROOT, '+test_datasets', 'XRDML', 'synthetic_rsm.xrdml');
GEN_DIR  = fullfile(ROOT, '+test_datasets', 'XRDML');

passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  Generate synthetic 2D test file
% ════════════════════════════════════════════════════════════════════════
fprintf('Generating synthetic 2D XRDML file...\n');

N_OMEGA  = 5;
N_PIXELS = 10;
OM_START = 30.0;
OM_END   = 31.0;
TT_START = 60.0;
TT_END   = 62.0;
CT       = 0.5;    % counting time (s)
PEAK_SCL = 1000;
BG       = 50;

addpath(GEN_DIR);
try
    writeTestXRDML2D(FILE_2D, N_OMEGA, N_PIXELS, ...
        'OmegaStart',    OM_START, 'OmegaEnd',   OM_END, ...
        'TwoThetaStart', TT_START, 'TwoThetaEnd', TT_END, ...
        'CountingTime',  CT, ...
        'PeakScale',     PEAK_SCL, 'Background', BG);
    fprintf('  Written: %s\n\n', FILE_2D);
catch ME
    rmpath(GEN_DIR);
    fprintf('FATAL: could not generate test file: %s\n', ME.message);
    return;
end
rmpath(GEN_DIR);

% ════════════════════════════════════════════════════════════════════════
%  TEST 1 — is2D detection
% ════════════════════════════════════════════════════════════════════════
fprintf('══ TEST 1: 2D detection (is2D flag) ══\n');
try
    d  = parser.importXRDML(FILE_2D, Intensity='cps');
    ps = d.metadata.parserSpecific;

    assert(isfield(ps, 'is2D'),    'parserSpecific must have is2D field');
    assert(ps.is2D == true,        'is2D should be true for synthetic RSM file');
    assert(isfield(ps, 'map2D'),   'parserSpecific must have map2D struct when is2D=true');
    assert(isstruct(ps.map2D),     'map2D must be a struct');

    fprintf('  is2D       : %d (expected 1)\n', ps.is2D);
    fprintf('  axis1Name  : %s\n', ps.map2D.axis1Name);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 2 — matrix shape
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 2: intensity matrix shape [N_OMEGA x N_PIXELS] ══\n');
try
    d    = parser.importXRDML(FILE_2D, Intensity='cps');
    map  = d.metadata.parserSpecific.map2D;
    sz   = size(map.intensity);

    assert(sz(1) == N_OMEGA,  sprintf('map2D.intensity rows: expected %d, got %d', N_OMEGA,  sz(1)));
    assert(sz(2) == N_PIXELS, sprintf('map2D.intensity cols: expected %d, got %d', N_PIXELS, sz(2)));
    assert(all(isfinite(map.intensity(:))), 'map2D.intensity contains non-finite values');

    fprintf('  Shape      : [%d x %d] (expected [%d x %d])\n', sz(1), sz(2), N_OMEGA, N_PIXELS);
    fprintf('  Intensity range: %.2f to %.2f %s\n', ...
        min(map.intensity(:)), max(map.intensity(:)), map.intensityUnit);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 3 — axis1 values (Omega positions)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 3: axis1 (Omega) values and metadata ══\n');
try
    d    = parser.importXRDML(FILE_2D, Intensity='cps');
    map  = d.metadata.parserSpecific.map2D;

    expectedOmega = linspace(OM_START, OM_END, N_OMEGA)';

    assert(strcmp(map.axis1Name, 'Omega'),   'axis1Name should be ''Omega''');
    assert(strcmp(map.axis1Unit, 'deg'),     'axis1Unit should be ''deg''');
    assert(numel(map.axis1) == N_OMEGA,      'axis1 wrong length');
    assert(max(abs(map.axis1 - expectedOmega)) < 1e-5, ...
        sprintf('axis1 values differ from expected by up to %.2e', ...
                max(abs(map.axis1 - expectedOmega))));

    fprintf('  axis1Name  : %s\n', map.axis1Name);
    fprintf('  axis1      : %.4f to %.4f deg (%d steps)\n', ...
        map.axis1(1), map.axis1(end), numel(map.axis1));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 4 — axis2 values (2Theta detector strip)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 4: axis2 (2Theta) values and metadata ══\n');
try
    d    = parser.importXRDML(FILE_2D, Intensity='cps');
    map  = d.metadata.parserSpecific.map2D;

    expectedTT = linspace(TT_START, TT_END, N_PIXELS)';

    assert(strcmp(map.axis2Name, '2Theta'), 'axis2Name should be ''2Theta''');
    assert(strcmp(map.axis2Unit, 'deg'),    'axis2Unit should be ''deg''');
    assert(numel(map.axis2) == N_PIXELS,   'axis2 wrong length');
    assert(max(abs(map.axis2 - expectedTT)) < 1e-5, ...
        sprintf('axis2 values differ from expected by up to %.2e', ...
                max(abs(map.axis2 - expectedTT))));

    fprintf('  axis2Name  : %s\n', map.axis2Name);
    fprintf('  axis2      : %.4f to %.4f deg (%d pixels)\n', ...
        map.axis2(1), map.axis2(end), numel(map.axis2));
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 5 — 1D fallback (integrated profile)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 5: 1D integrated fallback ══\n');
try
    d   = parser.importXRDML(FILE_2D, Intensity='cps');
    map = d.metadata.parserSpecific.map2D;

    assert(numel(d.time)   == N_PIXELS,    '1D fallback time vector wrong length');
    assert(size(d.values,1) == N_PIXELS,   '1D fallback values wrong length');
    assert(size(d.values,2) == 1,          '1D fallback should have 1 channel');
    assert(strcmp(d.labels{1}, 'Intensity (integrated)'), ...
        'label should be ''Intensity (integrated)'' for 2D files');
    assert(strcmp(d.units{1}, 'cps'), '1D fallback units should match Intensity option');
    assert(all(isfinite(d.values)), '1D fallback values contain non-finite entries');

    % data.values should equal sum of map rows (col-wise integration)
    expected1D = sum(map.intensity, 1)';
    tol = 1e-10 * max(abs(expected1D));
    assert(max(abs(d.values - expected1D)) <= tol, ...
        'data.values differs from sum(map2D.intensity,1)'' beyond tolerance');

    fprintf('  1D length  : %d (expected %d)\n', numel(d.time), N_PIXELS);
    fprintf('  2\xB0 range   : %.4f to %.4f deg\n', d.time(1), d.time(end));
    fprintf('  Integ. max : %.2f %s\n', max(d.values), d.units{1});
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 6 — cps normalisation of map2D.intensity
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 6: cps normalisation ══\n');
try
    dCps = parser.importXRDML(FILE_2D, Intensity='cps');
    dCts = parser.importXRDML(FILE_2D, Intensity='counts');

    mapCps = dCps.metadata.parserSpecific.map2D;
    mapCts = dCts.metadata.parserSpecific.map2D;

    assert(strcmp(mapCps.intensityUnit, 'cps'),    'intensityUnit should be ''cps''');
    assert(strcmp(mapCts.intensityUnit, 'counts'), 'intensityUnit should be ''counts''');

    % cps * countingTime == counts (exact to floating-point rounding)
    ratio = mapCts.intensity ./ mapCps.intensity;
    assert(max(abs(ratio(:) - CT)) < 1e-9, ...
        sprintf('counts/cps ratio max deviation %.2e (expected CT=%.3f)', ...
                max(abs(ratio(:) - CT)), CT));

    % 1D integrated fallback obeys the same normalisation
    ratioFb = dCts.values ./ dCps.values;
    assert(max(abs(ratioFb - CT)) < 1e-9, ...
        '1D fallback counts/cps ratio deviates from countingTime');

    fprintf('  cps max    : %.2f  |  counts max : %.0f\n', ...
        max(mapCps.intensity(:)), max(mapCts.intensity(:)));
    fprintf('  counts/cps : %.4f (expected CT = %.4f)\n', ratio(1,1), CT);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 7 — 1D file unchanged (La2NiO4 backward compatibility)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 7: 1D file unchanged (La2NiO4 backward compatibility) ══\n');
if ~isfile(FILE_1D)
    fprintf('  SKIP – La2NiO4 file not found.\n');
else
    try
        d  = parser.importXRDML(FILE_1D, Intensity='cps');
        ps = d.metadata.parserSpecific;

        assert(isfield(ps, 'is2D'),         'parserSpecific.is2D field missing');
        assert(ps.is2D == false,            'La2NiO4 should NOT be detected as 2D');
        assert(~isfield(ps, 'map2D'),       'map2D should not exist for 1D files');
        assert(~isempty(d.time),            '2θ vector is empty');
        assert(size(d.values,2) == 1,       'expected exactly 1 channel');
        assert(strcmp(d.labels{1}, 'Intensity'), ...
            'label should be ''Intensity'' (not integrated) for 1D files');
        assert(strcmp(d.units{1}, 'cps'),   'units should be cps');
        assert(ps.numPoints == numel(d.time), 'numPoints mismatch');
        assert(ps.startAngle > 0,           'startAngle should be positive');
        assert(ps.endAngle > ps.startAngle, 'endAngle must exceed startAngle');
        assert(all(isfinite(d.values)),     '1D values contain non-finite entries');

        fprintf('  is2D       : %d (expected 0)\n', ps.is2D);
        fprintf('  Points     : %d\n', ps.numPoints);
        fprintf('  2\xB0 range   : %.4f to %.4f deg\n', ps.startAngle, ps.endAngle);
        fprintf('  PASS\n');
        passed = passed + 1;
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  TEST 8 — Q-space conversion (Qx / Qz fields in map2D)
% ════════════════════════════════════════════════════════════════════════
fprintf('\n══ TEST 8: Q-space conversion (Qx / Qz) ══\n');
try
    d   = parser.importXRDML(FILE_2D, Intensity='cps');
    map = d.metadata.parserSpecific.map2D;

    % Lazy Q-space: wavelength stored at parse, Qx/Qz computed on demand
    assert(isfield(map, 'wavelength_A'), 'map2D.wavelength_A missing (lazy Q-space)');
    map = parser.computeQSpace(map);
    assert(isfield(map, 'Qx'),      'map2D.Qx field missing after computeQSpace');
    assert(isfield(map, 'Qz'),      'map2D.Qz field missing');
    assert(isfield(map, 'QxUnit'),  'map2D.QxUnit field missing');
    assert(isfield(map, 'QzUnit'),  'map2D.QzUnit field missing');
    assert(strcmp(map.QxUnit, 'Ang^-1'), 'QxUnit should be ''Ang^-1''');
    assert(strcmp(map.QzUnit, 'Ang^-1'), 'QzUnit should be ''Ang^-1''');

    % Shape must match intensity matrix
    sz = size(map.intensity);
    assert(isequal(size(map.Qx), sz), ...
        sprintf('Qx shape [%d %d] must match intensity [%d %d]', ...
                size(map.Qx,1), size(map.Qx,2), sz(1), sz(2)));
    assert(isequal(size(map.Qz), sz), ...
        sprintf('Qz shape [%d %d] must match intensity [%d %d]', ...
                size(map.Qz,1), size(map.Qz,2), sz(1), sz(2)));
    assert(all(isfinite(map.Qx(:))), 'Qx contains non-finite values');
    assert(all(isfinite(map.Qz(:))), 'Qz contains non-finite values');

    % Physical checks:
    %   Qz must be positive for our 2Theta range [60,62] (well above zero).
    assert(all(map.Qz(:) > 0), 'Qz should be positive for 2Theta > 0');

    %   At the symmetric Bragg condition (Omega = Theta = 2Theta/2), Qx = 0.
    %   Find the scan frame closest to Omega = mean(TT)/2.
    ttMid  = (TT_START + TT_END) / 2;
    omSym  = ttMid / 2;
    [~, symRow] = min(abs(map.axis1 - omSym));
    qxSym = map.Qx(symRow, :);
    assert(max(abs(qxSym)) < 0.15, ...
        sprintf('Qx at symmetric row max abs = %.4f (expected ~0)', max(abs(qxSym))));

    %   Qz at symmetric point ~ (4π/λ)·sin(θ)  (within small angular range)
    lambda = 1.5405980;
    thetaMid = deg2rad(ttMid / 2);
    qzExpected = 4 * pi / lambda * sin(thetaMid);
    qzSym = mean(map.Qz(symRow, :));
    assert(abs(qzSym - qzExpected) / qzExpected < 0.05, ...
        sprintf('Qz at symmetric row = %.4f, expected ~%.4f (>5%% error)', ...
                qzSym, qzExpected));

    fprintf('  Qx range   : %.4f to %.4f Ang^-1\n', min(map.Qx(:)), max(map.Qx(:)));
    fprintf('  Qz range   : %.4f to %.4f Ang^-1\n', min(map.Qz(:)), max(map.Qz(:)));
    fprintf('  Qz(sym)    : %.4f (expected ~%.4f)\n', qzSym, qzExpected);
    fprintf('  PASS\n');
    passed = passed + 1;
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
fprintf('\n%s\n', repmat(char(9552), 1, 52));
fprintf('  test_xrdml_2d: %d passed, %d failed\n', passed, failed);
fprintf('%s\n\n', repmat(char(9552), 1, 52));

if failed > 0
    error('test_xrdml_2d:failures', '%d test(s) failed.', failed);
end
