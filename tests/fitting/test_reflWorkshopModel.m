%TEST_REFLWORKSHOPMODEL  Isolation tests for the Reflectivity Workshop model.
%
%   Exercises ReflWorkshopModel against synthetic R(Q) data with no GUI.
%
%   Run:
%     run tests/fitting/test_reflWorkshopModel
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_reflWorkshopModel ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  CONSTRUCTION
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- Construction seeds default 3-layer + 5-knot defaults ---\n');
try
    m = bosonPlotter.reflectivity.ReflWorkshopModel();
    assert(strcmp(m.mode, 'Layers'), 'default mode = Layers');
    assert(numel(m.layers) == 3, sprintf('default 3 layers; got %d', numel(m.layers)));
    assert(numel(m.knots) == 5, sprintf('default 5 knots; got %d', numel(m.knots)));
    assert(strcmp(m.layers(1).name, 'Air / Vacuum'), 'first layer is ambient');
    assert(strcmp(m.layers(end).name, 'Silicon'), 'last layer is substrate');
    fprintf('  PASS: 3 layers (%s), 5 knots\n', ...
        strjoin({m.layers.name}, ' | '));
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SIMULATE — produces sensible R(Q) curve
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- simulate() yields physical R(Q) ---\n');
try
    m = bosonPlotter.reflectivity.ReflWorkshopModel();
    Q = linspace(0.005, 0.2, 200)';     % typical Q range in Å⁻¹
    R = m.simulate(Q);
    assert(numel(R) == numel(Q), 'output length matches Q');
    assert(all(R >= 0), 'R must be non-negative');
    assert(all(R <= 1.001), 'R must not exceed unity (within float tol)');
    % Expect monotone-ish decline at high Q
    assert(R(end) < R(1), 'R must decay at high Q');
    fprintf('  PASS: R(Q) length=%d, R(min Q)=%.3f, R(max Q)=%.2e\n', ...
        numel(R), R(1), R(end));
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  ADDLAYER / REMOVELAYER — preserve ambient + substrate boundaries
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- addLayer / removeLayer preserve endpoints ---\n');
try
    m = bosonPlotter.reflectivity.ReflWorkshopModel();
    n0 = numel(m.layers);

    m.addLayer('Foo', 50, 4.5);
    assert(numel(m.layers) == n0 + 1, 'addLayer grows by 1');
    assert(strcmp(m.layers(end).name, 'Silicon'), 'substrate stays last');
    assert(strcmp(m.layers(end-1).name, 'Foo'), 'new layer inserted before substrate');

    % Try to delete substrate — should be refused
    nBefore = numel(m.layers);
    m.removeLayer(numel(m.layers));
    assert(numel(m.layers) == nBefore, 'cannot delete substrate');

    % Try to delete ambient — should be refused
    m.removeLayer(1);
    assert(numel(m.layers) == nBefore, 'cannot delete ambient');

    % Delete the new Foo layer
    fooIdx = find(strcmp({m.layers.name}, 'Foo'), 1);
    m.removeLayer(fooIdx);
    assert(numel(m.layers) == n0, 'Foo removed');
    fprintf('  PASS: addLayer + removeLayer preserve endpoints (final n=%d)\n', n0);
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  ADDKNOT — sorts by z
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- addKnot sorts by z ---\n');
try
    m = bosonPlotter.reflectivity.ReflWorkshopModel();
    n0 = numel(m.knots);
    m.addKnot(75, 3.0);                 % between knots at z=40 and z=100
    assert(numel(m.knots) == n0 + 1, 'addKnot grows by 1');
    zs = [m.knots.z];
    assert(issorted(zs), sprintf('knots not sorted: %s', num2str(zs)));
    fprintf('  PASS: knots sorted by z (%s)\n', num2str(zs));
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  LAYERMATRIX — round-trip with parrattRefl
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- layerMatrix → parrattRefl round-trip ---\n');
try
    m = bosonPlotter.reflectivity.ReflWorkshopModel();
    L = m.layerMatrix();
    assert(size(L, 2) == 4, 'matrix has 4 columns');
    assert(size(L, 1) == numel(m.layers), 'rows match layer count');

    % Independently call parrattRefl with the same matrix and verify
    % m.simulate gives the same answer.
    Q = linspace(0.01, 0.1, 50)';
    R_direct = fitting.parrattRefl(Q, L);
    R_model  = m.simulate(Q);
    err = max(abs(R_direct - R_model));
    assert(err < 1e-12, sprintf('simulate diverges from direct call: max err %.2e', err));
    fprintf('  PASS: simulate matches direct parrattRefl (max err %.2e)\n', err);
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  REGRESSION — normalizeLayers upgrades legacy 5-field input
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- normalizeLayers on legacy 5-field input ---\n');
try
    legacy = struct('name',{'Air','Si'}, 'thick',{0,0}, ...
        'sld',{0,2.073}, 'abs',{0,0}, 'rough',{0,3});  % no 'fixed' field
    upgraded = bosonPlotter.reflectivity.ReflWorkshopModel.normalizeLayers(legacy);
    assert(isfield(upgraded, 'fixed'), 'normalizeLayers adds fixed');
    assert(numel(upgraded) == 2, 'preserves count');
    assert(upgraded(1).fixed == false, 'default fixed=false');
    fprintf('  PASS: legacy 5-field → canonical 6-field\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  BINDFROMDATASET — normalizes legacy 5-field layers (contract rule #1)
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- bindFromDataset normalizes pre-set legacy layers ---\n');
try
    m = bosonPlotter.reflectivity.ReflWorkshopModel();
    % Simulate a session loader feeding 5-field layers (no 'fixed'):
    m.layers = struct('name', {'Air', 'SiO2', 'Si'}, ...
        'thick', {0, 200, 0}, 'sld', {0, 3.47, 2.073}, ...
        'abs', {0, 0, 0}, 'rough', {0, 5, 3});
    ds = struct('corrData', [], 'data', ...
        struct('time', (1:10)', 'values', (1:10)', 'labels', {{'R'}}));
    m.bindFromDataset(ds);
    assert(isfield(m.layers, 'fixed'), 'bindFromDataset must add fixed field');
    assert(numel(m.layers) == 3, 'preserves count');
    assert(strcmp(m.layers(2).name, 'SiO2'), 'preserves names');
    assert(m.layers(2).fixed == false, 'default fixed=false');
    fprintf('  PASS: legacy 5-field layers upgraded by bindFromDataset\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  EMPTYRESULT — result shape exposes Q/R/layerMatrix/R2/mode
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- bindFromDataset seeds canonical empty result ---\n');
try
    m = bosonPlotter.reflectivity.ReflWorkshopModel();
    ds = struct('corrData', [], 'data', ...
        struct('time', (1:5)', 'values', (1:5)', 'labels', {{'R'}}));
    m.bindFromDataset(ds);
    needed = {'Q', 'R', 'layerMatrix', 'R2', 'mode', 'params', 'errors'};
    missing = needed(~ismember(needed, fieldnames(m.result)));
    assert(isempty(missing), sprintf('result missing fields: %s', strjoin(missing, ', ')));
    assert(~m.hasResult(), 'hasResult false until simulate/fit runs');
    assert(strcmp(m.result.mode, 'Layers'), 'default mode is Layers');
    fprintf('  PASS: %d expected result fields present\n', numel(needed));
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SETSIMULATEOUTCOME / SETFITOUTCOME — dialog-side state on the model
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- setSimulateOutcome / setFitOutcome round-trip ---\n');
try
    m = bosonPlotter.reflectivity.ReflWorkshopModel();
    Q = linspace(0.01, 0.1, 30)';
    R = m.simulate(Q);
    L = m.layerMatrix();
    m.setSimulateOutcome(Q, R, L);
    assert(m.hasResult(), 'hasResult true after setSimulateOutcome');
    assert(numel(m.result.Q) == 30 && numel(m.result.R) == 30, 'Q/R stored');
    assert(isnan(m.result.R2), 'R2 NaN for simulate (no observed curve)');
    assert(isequal(m.result.layerMatrix, L), 'layerMatrix stored');

    m.setFitOutcome(Q, R, L, 0.987, struct('chiSqRed', 1.2, 'exitFlag', 1));
    assert(abs(m.result.R2 - 0.987) < 1e-12, 'R2 stored from fit outcome');
    assert(m.result.chiSqRed == 1.2, 'extras merged in');
    assert(m.result.exitFlag == 1, 'extras merged in');
    fprintf('  PASS: simulate + fit outcome round-trip + extras merge\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SETMODE — validates membership, syncs result mode after outcome
% ════════════════════════════════════════════════════════════════════
fprintf('\n--- setMode + outcome reflects current mode ---\n');
try
    m = bosonPlotter.reflectivity.ReflWorkshopModel();
    m.setMode('Spline');
    assert(strcmp(m.mode, 'Spline'), 'setMode applied');
    Q = linspace(0.01, 0.1, 20)';
    R = ones(size(Q)) * 0.5;
    L = m.layerMatrix();
    m.setSimulateOutcome(Q, R, L);
    assert(strcmp(m.result.mode, 'Spline'), 'result.mode reflects current mode');

    err = '';
    try
        m.setMode('Garbage');
    catch ex
        err = ex.message;
    end
    assert(~isempty(err), 'setMode must reject invalid values');
    fprintf('  PASS: setMode validates + propagates to result.mode\n');
    passed = passed + 1;
catch ex
    fprintf('  FAIL: %s\n', ex.message); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════
fprintf('\n=== test_reflWorkshopModel: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_reflWorkshopModel:failed', '%d test(s) failed', failed);
end
