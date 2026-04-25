%TEST_REFLSPLINEMODE  Tests for the spline-mode wiring in
%   bosonPlotter.reflFitting and the reflBuildSplineLayers helper
%   (MASTERPLAN W3 #11 GUI integration).
%
%   Run:
%     run tests/gui/test_reflSplineMode
%     runAllTests(Group="gui")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_reflSplineMode ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  bosonPlotter.reflBuildSplineLayers (pure-logic helper)
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- bosonPlotter.reflBuildSplineLayers ---\n');

% Test 1: cell-array (knot table) input
knotData = { ...
        0,    0.000,  true; ...
       40,    3.470,  false; ...
      100,    3.470,  false; ...
      160,    3.470,  false; ...
      200,    2.073,  true};
[layers, z, sldProf] = bosonPlotter.reflBuildSplineLayers(knotData);

if size(layers, 2) == 4 && size(layers, 1) > 100
    fprintf('  PASS: layer matrix is [%d×4] from 5-knot cell input\n', size(layers, 1));
    passed = passed + 1;
else
    fprintf('  FAIL: layer matrix shape [%d×%d]\n', size(layers,1), size(layers,2));
    failed = failed + 1;
end

% Endpoint rows have correct ambient/substrate SLD (×10⁻⁶ → Å⁻²)
if abs(layers(1, 2) - 0.0e-6) < 1e-12 && abs(layers(end, 2) - 2.073e-6) < 1e-12
    fprintf('  PASS: endpoint SLDs match first/last knot values\n');
    passed = passed + 1;
else
    fprintf('  FAIL: endpoint SLDs %.3e / %.3e\n', layers(1,2), layers(end,2));
    failed = failed + 1;
end

% Microslab roughness is identically zero (profile already smooth)
if all(layers(2:end-1, 4) == 0)
    fprintf('  PASS: microslab roughness = 0\n'); passed = passed + 1;
else
    fprintf('  FAIL: nonzero microslab roughness\n'); failed = failed + 1;
end

% Profile passes through knot values within tolerance
sldAt40 = interp1(z, sldProf, 40);
if abs(sldAt40 - 3.47e-6) < 1e-9
    fprintf('  PASS: profile passes through knot z=40 within 1e-9\n');
    passed = passed + 1;
else
    fprintf('  FAIL: profile at z=40 is %.4e (expected 3.47e-6)\n', sldAt40);
    failed = failed + 1;
end

% Test 2: numeric matrix input (alternative form)
numKnots = [0, 0; 40, 3.47; 100, 3.47; 200, 2.073];
layers2 = bosonPlotter.reflBuildSplineLayers(numKnots);
if size(layers2, 2) == 4 && size(layers2, 1) > 100
    fprintf('  PASS: accepts numeric matrix input\n'); passed = passed + 1;
else
    fprintf('  FAIL: numeric matrix input rejected\n'); failed = failed + 1;
end

% Test 3: out-of-order knots are sorted internally
shuffled = { ...
      200,    2.073,  true; ...
       40,    3.470,  false; ...
        0,    0.000,  true; ...
      100,    3.470,  false};
layersSh = bosonPlotter.reflBuildSplineLayers(shuffled);
if abs(layersSh(1, 2) - 0.0e-6) < 1e-12 && abs(layersSh(end, 2) - 2.073e-6) < 1e-12
    fprintf('  PASS: out-of-order knots sorted before splining\n');
    passed = passed + 1;
else
    fprintf('  FAIL: shuffled knots not sorted (endpoints %.3e / %.3e)\n', ...
        layersSh(1,2), layersSh(end,2));
    failed = failed + 1;
end

% Test 4: parrattRefl on the spline-built layers produces physical R(Q)
Q = linspace(0.005, 0.25, 100)';
R = fitting.parrattRefl(Q, layers, Roughness=false);
if all(isreal(R)) && all(R >= 0) && all(R <= 1.001) ...
        && R(1) > 0.99 && R(end) < 1e-3
    fprintf('  PASS: spline → parrattRefl gives physical R (R_low=%.3f, R_high=%.2e)\n', ...
        R(1), R(end));
    passed = passed + 1;
else
    fprintf('  FAIL: R out of expected range (R(1)=%.3f, max=%.3f, R(end)=%.2e)\n', ...
        R(1), max(R), R(end));
    failed = failed + 1;
end

% Test 5: error path on too-few-knots
try
    bosonPlotter.reflBuildSplineLayers({0, 0, false});
    fprintf('  FAIL: did not error on 1-knot input\n'); failed = failed + 1;
catch ME
    if contains(ME.identifier, 'tooFewKnots')
        fprintf('  PASS: rejects 1-knot input\n'); passed = passed + 1;
    else
        fprintf('  FAIL: wrong error id %s\n', ME.identifier); failed = failed + 1;
    end
end

% Test 6: NProfile option propagates. profileToLayers maps N profile points
% → (N-1) microslabs + 2 endpoint rows = N+1 layer rows.
[layersA, ~, ~] = bosonPlotter.reflBuildSplineLayers(knotData, NProfile=100);
[layersB, ~, ~] = bosonPlotter.reflBuildSplineLayers(knotData, NProfile=400);
if size(layersA, 1) == 101 && size(layersB, 1) == 401
    fprintf('  PASS: NProfile option propagates (100 → 101 rows, 400 → 401 rows)\n');
    passed = passed + 1;
else
    fprintf('  FAIL: NProfile not honoured (%d vs %d, expected 101 / 401)\n', ...
        size(layersA,1), size(layersB,1));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  Smoke test: launch reflFitting headlessly and toggle modes
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- reflFitting headless smoke test ---\n');

% Build a minimal synthetic dataset (reflectometry of bare Si)
Q   = linspace(0.005, 0.25, 60)';
boxL = [0 0 0 0; 0 2.073e-6 0 0];
Rsi  = fitting.parrattRefl(Q, boxL, Roughness=false);

ds.data    = struct('time', Q, 'values', Rsi, ...
                    'labels', {{'Reflectivity'}}, 'units', {{''}}, ...
                    'metadata', struct());
ds.corrData = ds.data;

% Launch (uifigure becomes visible by default; we tear down immediately
% after exercising it so the dialog flicker is brief). We don't pass a
% mainAx because plotOnMain isn't invoked.
try
    bosonPlotter.reflFitting({ds}, 1, gca);
    fprintf('  PASS: reflFitting launches without error\n');
    passed = passed + 1;

    % Locate the dialog and inspect its widgets
    figs = findall(groot, 'Type', 'figure', 'Name', 'Reflectivity Fitting');
    if numel(figs) >= 1
        rfFig = figs(1);
        ddMode = findall(rfFig, 'Type', 'uidropdown', '-and', '-property', 'Items');
        if ~isempty(ddMode) && any(strcmp(ddMode(1).Items, 'Spline'))
            fprintf('  PASS: Mode dropdown present with Spline option\n');
            passed = passed + 1;

            % Toggle to Spline mode programmatically
            ddMode(1).Value = 'Spline';
            % Trigger the ValueChangedFcn
            evt = struct('Value', 'Spline');
            try
                ddMode(1).ValueChangedFcn(ddMode(1), evt);
                fprintf('  PASS: Mode toggle to Spline executes without error\n');
                passed = passed + 1;
            catch ME
                fprintf('  FAIL: Mode toggle errored: %s\n', ME.message);
                failed = failed + 1;
            end

            % Inspect knot table visibility after toggle
            tables = findall(rfFig, 'Type', 'uitable');
            if numel(tables) >= 2
                fprintf('  PASS: Both layer + knot tables exist (%d tables)\n', ...
                    numel(tables));
                passed = passed + 1;
            else
                fprintf('  FAIL: Expected 2 tables, found %d\n', numel(tables));
                failed = failed + 1;
            end
        else
            fprintf('  FAIL: Mode dropdown missing or lacks Spline option\n');
            failed = failed + 1;
        end
        delete(rfFig);
    else
        fprintf('  FAIL: reflFitting figure not found after launch\n');
        failed = failed + 1;
    end
catch ME
    fprintf('  FAIL: reflFitting launch failed: %s\n', ME.message);
    failed = failed + 1;
end

close all force

% ════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_reflSplineMode: %d passed, %d failed ===\n\n', passed, failed);

if failed > 0
    error('test_reflSplineMode:failures', '%d test(s) failed', failed);
end
