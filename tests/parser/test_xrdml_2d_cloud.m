%TEST_XRDML_2D_CLOUD  Generalized 2D XRDML layouts (snapshot / coupled).
%
%   Covers the two RSM layouts the classic mesh check rejects:
%     'snapshot' — PIXcel3D area snapshots (schema 2.x): omega fixed per
%                  frame while BOTH omega and the 2theta window step.
%     'coupled'  — schema-1.0 Omega-2Theta RSMs: omega sweeps within each
%                  scan at a stepped offset (sheared mesh).
%   Plus regressions: the classic mesh stays meshKind='mesh', a 2-range 1D
%   file stays 1D, and computeQSpace uses the per-point grids.
%
%   Mirrors the Python port's tests (quantized tests/test_io_xrdml.py).
%
%   Run standalone:  cd tests/parser; run test_xrdml_2d_cloud

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

passed = 0;
failed = 0;
tmpDir = tempname;
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

% ════════════════════════════════════════════════════════════════════════
%  Synthetic file builders
% ════════════════════════════════════════════════════════════════════════
header = ['<?xml version="1.0"?>' newline ...
    '<xrdMeasurements xmlns="http://www.xrdml.com/XRDMeasurement/2.0" status="Completed">' newline ...
    '<xrdMeasurement measurementType="Area measurement" status="Completed">' newline ...
    '<usedWavelength intended="K-Alpha 1"><kAlpha1 unit="Angstrom">1.5406</kAlpha1></usedWavelength>' newline];
footer = ['</xrdMeasurement>' newline '</xrdMeasurements>' newline];

snapScan = @(app, tt0, tt1, om, cts) sprintf([ ...
    '<scan appendNumber="%d" status="Completed" scanAxis="2Theta"><dataPoints>' ...
    '<positions axis="2Theta" unit="deg"><startPosition>%g</startPosition>' ...
    '<endPosition>%g</endPosition></positions>' ...
    '<positions axis="Omega" unit="deg"><commonPosition>%g</commonPosition></positions>' ...
    '<commonCountingTime unit="seconds">1.0</commonCountingTime>' ...
    '<counts unit="counts">%s</counts></dataPoints></scan>\n'], app, tt0, tt1, om, cts);

coupScan = @(app, om0, om1, cts) sprintf([ ...
    '<scan appendNumber="%d" status="Completed" scanAxis="Omega-2Theta"><dataPoints>' ...
    '<positions axis="2Theta" unit="deg"><startPosition>40.0</startPosition>' ...
    '<endPosition>42.0</endPosition></positions>' ...
    '<positions axis="Omega" unit="deg"><startPosition>%g</startPosition>' ...
    '<endPosition>%g</endPosition></positions>' ...
    '<commonCountingTime unit="seconds">1.0</commonCountingTime>' ...
    '<intensities unit="counts">%s</intensities></dataPoints></scan>\n'], app, om0, om1, cts);

% ════════════════════════════════════════════════════════════════════════
%  1. Snapshot cloud detection (omega fixed per frame, 2theta window steps)
% ════════════════════════════════════════════════════════════════════════
body = '';
for i = 0:3
    body = [body snapScan(i+1, 40.0 + 0.1*i, 41.0 + 0.1*i, 20.0 + 0.05*i, '1 2 3 4')]; %#ok<AGROW>
end
fSnap = fullfile(tmpDir, 'snapshot.xrdml');
fid = fopen(fSnap, 'w'); fwrite(fid, [header body footer]); fclose(fid);

try
    d = parser.importXRDML(fSnap, 'Intensity', 'counts');
    m = d.metadata.parserSpecific.map2D;
    assert(d.metadata.parserSpecific.is2D, 'snapshot: is2D');
    assert(strcmp(m.meshKind, 'snapshot'), 'snapshot: meshKind');
    assert(isequal(size(m.intensity), [4 4]), 'snapshot: map size');
    assert(isfield(m, 'axis2Grid'), 'snapshot: axis2Grid present');
    assert(~isfield(m, 'axis1Grid'), 'snapshot: no axis1Grid (omega fixed per row)');
    % each frame keeps its OWN 2theta window
    assert(max(abs(m.axis2Grid(1,:) - linspace(40.0, 41.0, 4))) < 1e-12, 'snapshot: row 1 2theta');
    assert(max(abs(m.axis2Grid(4,:) - linspace(40.3, 41.3, 4))) < 1e-12, 'snapshot: row 4 2theta');
    assert(max(abs(m.axis1' - (20.0:0.05:20.15))) < 1e-12, 'snapshot: omega steps');
    fprintf('PASS  snapshot cloud detection + grids\n'); passed = passed + 1;
catch ME
    fprintf('FAIL  snapshot cloud: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. Q-space uses the per-point grid (snapshot)
% ════════════════════════════════════════════════════════════════════════
try
    m = parser.computeQSpace(m);
    assert(isfield(m, 'Qx') && isequal(size(m.Qx), [4 4]), 'Qx grid size');
    % Row 1, pixel 1: 2theta=40.0, omega=20.0 — closed-form check
    k0 = 2*pi/1.5406; th = deg2rad(40.0)/2; om = deg2rad(20.0);
    assert(abs(m.Qx(1,1) - 2*k0*sin(th)*sin(om - th)) < 1e-12, 'Qx(1,1) closed form');
    assert(abs(m.Qz(1,1) - 2*k0*sin(th)*cos(om - th)) < 1e-12, 'Qz(1,1) closed form');
    % Row 4 must use ROW 4's 2theta window (not row 1's)
    th4 = deg2rad(40.3)/2; om4 = deg2rad(20.15);
    assert(abs(m.Qx(4,1) - 2*k0*sin(th4)*sin(om4 - th4)) < 1e-12, 'Qx(4,1) per-row grid');
    fprintf('PASS  computeQSpace per-point grids\n'); passed = passed + 1;
catch ME
    fprintf('FAIL  computeQSpace grids: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Coupled scan detection (omega sweeps within each scan)
% ════════════════════════════════════════════════════════════════════════
body = '';
for i = 0:2
    body = [body coupScan(i+1, 19.0 + 0.1*i, 21.0 + 0.1*i, '5 6 7 8 9')]; %#ok<AGROW>
end
fCoup = fullfile(tmpDir, 'coupled.xrdml');
fid = fopen(fCoup, 'w'); fwrite(fid, [header body footer]); fclose(fid);

try
    d = parser.importXRDML(fCoup, 'Intensity', 'counts');
    m = d.metadata.parserSpecific.map2D;
    assert(strcmp(m.meshKind, 'coupled'), 'coupled: meshKind');
    assert(isequal(size(m.intensity), [3 5]), 'coupled: map size');
    assert(isfield(m, 'axis1Grid'), 'coupled: axis1Grid present');
    assert(~isfield(m, 'axis2Grid'), 'coupled: no axis2Grid (shared window)');
    assert(max(abs(m.axis1Grid(1,:) - linspace(19.0, 21.0, 5))) < 1e-12, 'coupled: omega sweeps in scan');
    assert(max(abs(m.axis1Grid(:,1)' - [19.0 19.1 19.2])) < 1e-12, 'coupled: omega steps between scans');
    % Integrated 1D fallback (shared window -> aligned like the classic mesh)
    assert(max(abs(d.values' - sum(m.intensity, 1))) < 1e-12, 'coupled: integrated fallback');
    fprintf('PASS  coupled scan detection + grids\n'); passed = passed + 1;
catch ME
    fprintf('FAIL  coupled scan: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. Regression: 2-range 1D file must stay 1D (>= 3-scan guard)
% ════════════════════════════════════════════════════════════════════════
body = [snapScan(1, 40.0, 41.0, 20.0, '1 2 3') snapScan(2, 41.0, 42.0, 20.5, '4 5 6')];
fTwo = fullfile(tmpDir, 'two_range.xrdml');
fid = fopen(fTwo, 'w'); fwrite(fid, [header body footer]); fclose(fid);
try
    d = parser.importXRDML(fTwo, 'Intensity', 'counts');
    assert(~d.metadata.parserSpecific.is2D, 'two-range: stays 1D');
    fprintf('PASS  2-range 1D guard\n'); passed = passed + 1;
catch ME
    fprintf('FAIL  2-range 1D guard: %s\n', ME.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. Regression: classic mesh keeps meshKind='mesh' + no grids
% ════════════════════════════════════════════════════════════════════════
fMesh = fullfile(rootDir, '+test_datasets', 'XRDML', 'synthetic_rsm.xrdml');
if exist(fMesh, 'file')
    try
        d = parser.importXRDML(fMesh);
        m = d.metadata.parserSpecific.map2D;
        assert(strcmp(m.meshKind, 'mesh'), 'mesh: meshKind');
        assert(~isfield(m, 'axis1Grid') && ~isfield(m, 'axis2Grid'), 'mesh: no grids');
        fprintf('PASS  classic mesh regression\n'); passed = passed + 1;
    catch ME
        fprintf('FAIL  classic mesh regression: %s\n', ME.message); failed = failed + 1;
    end
else
    fprintf('SKIP  classic mesh regression (fixture missing)\n');
end

% ════════════════════════════════════════════════════════════════════════
%  6. Real corpus files (sibling test-data repo; skip when absent)
% ════════════════════════════════════════════════════════════════════════
corpus = fullfile(fileparts(rootDir), 'test-data', 'panalytical', 'xrd');
realCases = { ...
    'm3learning_rsm.xrdml',    'snapshot', [1827 255]; ...
    'xrdtools_rsm_point.xrdml', 'coupled',  [76 75]};
for c = 1:size(realCases, 1)
    fReal = fullfile(corpus, realCases{c, 1});
    if ~exist(fReal, 'file')
        fprintf('SKIP  corpus %s (not present)\n', realCases{c, 1});
        continue;
    end
    try
        d = parser.importXRDML(fReal);
        m = d.metadata.parserSpecific.map2D;
        assert(strcmp(m.meshKind, realCases{c, 2}), 'corpus meshKind');
        assert(isequal(size(m.intensity), realCases{c, 3}), 'corpus map size');
        fprintf('PASS  corpus %s -> %s %dx%d\n', realCases{c, 1}, m.meshKind, ...
            size(m.intensity, 1), size(m.intensity, 2));
        passed = passed + 1;
    catch ME
        fprintf('FAIL  corpus %s: %s\n', realCases{c, 1}, ME.message); failed = failed + 1;
    end
end

% ════════════════════════════════════════════════════════════════════════
fprintf('\n%d passed, %d failed\n', passed, failed);
if failed > 0
    error('test_xrdml_2d_cloud:failures', '%d test(s) failed', failed);
end
