%TEST_FITBANDS  Tests for fitting.fitBands (confidence and prediction bands).
%
%   Run:
%     run tests/fitting/test_fitBands
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_fitBands ===\n');
% Globals are the simplest way to share pass/fail counters with the
% local helper functions — refactoring to a class would be heavier
% than the test warrants.
global TEST_FITBANDS_PASSED TEST_FITBANDS_FAILED %#ok<GVMIS>
TEST_FITBANDS_PASSED = 0;
TEST_FITBANDS_FAILED = 0;

rng(42);

% Helpers (`approxEq`, `logPass`, `logFail`) live at the end of the file.
% Pre-R2024a MATLAB requires script-local functions to be after all
% top-level executable code; keeping them there works in every release.

% ════════════════════════════════════════════════════════════════════════
% Shared linear-model fit (y = a*x + b)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Setup: linear model fit ---\n');

N = 30;
aTrue = 2.0; bTrue = 1.5;
xData = linspace(0, 5, N)';
noise = 0.3 * randn(N, 1);
yData = aTrue * xData + bTrue + noise;

linFcn = @(x, p) p(1) * x + p(2);

res = fitting.curveFit(xData, yData, linFcn, [1 0]);

xGrid = linspace(-0.5, 5.5, 200)';

% ════════════════════════════════════════════════════════════════════════
% Test 1: Basic output structure
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Test 1: output structure ---\n');

bands = fitting.fitBands(xGrid, linFcn, res.params, res.covar, ...
    res.nPoints, res.nFree);

requiredFields = {'yFit', 'ciLo', 'ciHi', 'piLo', 'piHi', 'level'};
allFields = true;
for fi = 1:numel(requiredFields)
    if ~isfield(bands, requiredFields{fi})
        allFields = false;
        fprintf('    missing field: %s\n', requiredFields{fi});
    end
end
if allFields
    logPass('bands struct has all required fields');
else
    logFail('bands struct missing fields');
end

% All outputs are column vectors of correct length
M = numel(xGrid);
sizeOk = isequal(size(bands.yFit), [M 1]) && ...
         isequal(size(bands.ciLo), [M 1]) && ...
         isequal(size(bands.ciHi), [M 1]) && ...
         isequal(size(bands.piLo), [M 1]) && ...
         isequal(size(bands.piHi), [M 1]);
if sizeOk
    logPass('all band arrays are [M×1]');
else
    logFail('band array sizes incorrect');
end

% Level stored correctly
if bands.level == 0.95
    logPass('level stored correctly (default 0.95)');
else
    logFail(sprintf('level incorrect: %.2f', bands.level));
end

% ════════════════════════════════════════════════════════════════════════
% Test 2: Band ordering (CI inside PI)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Test 2: band ordering (CI inside PI) ---\n');

ciInsidePI = all(bands.ciLo >= bands.piLo - 1e-12) && ...
             all(bands.ciHi <= bands.piHi + 1e-12);
if ciInsidePI
    logPass('CI is contained within PI at all grid points');
else
    logFail('CI extends outside PI');
end

ciNonNegWidth = all(bands.ciHi >= bands.ciLo);
piNonNegWidth = all(bands.piHi >= bands.piLo);
if ciNonNegWidth && piNonNegWidth
    logPass('CI and PI have non-negative width everywhere');
else
    logFail('CI or PI has negative width');
end

% ════════════════════════════════════════════════════════════════════════
% Test 3: Band symmetry around yFit
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Test 3: symmetry around yFit ---\n');

ciHalfUp   = bands.ciHi - bands.yFit;
ciHalfDown = bands.yFit - bands.ciLo;
piHalfUp   = bands.piHi - bands.yFit;
piHalfDown = bands.yFit - bands.piLo;

if approxEq(ciHalfUp, ciHalfDown, 1e-10)
    logPass('CI is symmetric about yFit');
else
    logFail(sprintf('CI asymmetry: max deviation = %.3g', max(abs(ciHalfUp - ciHalfDown))));
end

if approxEq(piHalfUp, piHalfDown, 1e-10)
    logPass('PI is symmetric about yFit');
else
    logFail(sprintf('PI asymmetry: max deviation = %.3g', max(abs(piHalfUp - piHalfDown))));
end

% ════════════════════════════════════════════════════════════════════════
% Test 4: Higher confidence level → wider bands
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Test 4: wider bands at higher confidence ---\n');

bands90 = fitting.fitBands(xGrid, linFcn, res.params, res.covar, ...
    res.nPoints, res.nFree, Level=0.90);
bands95 = bands;  % already computed above at 0.95
bands99 = fitting.fitBands(xGrid, linFcn, res.params, res.covar, ...
    res.nPoints, res.nFree, Level=0.99);

ciWidth90 = mean(bands90.ciHi - bands90.ciLo);
ciWidth95 = mean(bands95.ciHi - bands95.ciLo);
ciWidth99 = mean(bands99.ciHi - bands99.ciLo);

piWidth90 = mean(bands90.piHi - bands90.piLo);
piWidth95 = mean(bands95.piHi - bands95.piLo);
piWidth99 = mean(bands99.piHi - bands99.piLo);

if ciWidth90 < ciWidth95 && ciWidth95 < ciWidth99
    logPass(sprintf('CI width increases with level: 90%%=%.4g 95%%=%.4g 99%%=%.4g', ...
        ciWidth90, ciWidth95, ciWidth99));
else
    logFail(sprintf('CI widths not monotone: 90%%=%.4g 95%%=%.4g 99%%=%.4g', ...
        ciWidth90, ciWidth95, ciWidth99));
end

if piWidth90 < piWidth95 && piWidth95 < piWidth99
    logPass(sprintf('PI width increases with level: 90%%=%.4g 95%%=%.4g 99%%=%.4g', ...
        piWidth90, piWidth95, piWidth99));
else
    logFail(sprintf('PI widths not monotone: 90%%=%.4g 95%%=%.4g 99%%=%.4g', ...
        piWidth90, piWidth95, piWidth99));
end

% Level stored on each struct
if bands90.level == 0.90 && bands99.level == 0.99
    logPass('level field matches requested level on all structs');
else
    logFail('level field mismatch');
end

% ════════════════════════════════════════════════════════════════════════
% Test 5: Singular / empty covariance → NaN bands (no crash)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Test 5: singular covariance → NaN bands ---\n');

singCovar = zeros(2, 2);
try
    bNaN = fitting.fitBands(xGrid, linFcn, res.params, singCovar, ...
        res.nPoints, res.nFree);
    if all(isnan(bNaN.ciLo)) && all(isnan(bNaN.ciHi)) && ...
       all(isnan(bNaN.piLo)) && all(isnan(bNaN.piHi))
        logPass('singular covariance returns NaN bands without crash');
    else
        logFail('singular covariance did not return all-NaN bands');
    end
catch ME
    logFail(sprintf('singular covariance threw error: %s', ME.message));
end

% Empty covariance
try
    bEmpty = fitting.fitBands(xGrid, linFcn, res.params, [], ...
        res.nPoints, res.nFree);
    if all(isnan(bEmpty.ciLo))
        logPass('empty covariance returns NaN bands without crash');
    else
        logFail('empty covariance did not return NaN bands');
    end
catch ME
    logFail(sprintf('empty covariance threw error: %s', ME.message));
end

% ════════════════════════════════════════════════════════════════════════
% Test 6: Single-parameter model
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Test 6: single-parameter model ---\n');

xD1 = linspace(0.1, 5, 20)';
yD1 = 3.0 * xD1 + 0.2 * randn(20, 1);
slopeFcn = @(x, p) p(1) * x;

res1 = fitting.curveFit(xD1, yD1, slopeFcn, 1);

try
    b1 = fitting.fitBands(xGrid, slopeFcn, res1.params, res1.covar, ...
        res1.nPoints, res1.nFree);
    if isequal(size(b1.yFit), [M 1]) && ~all(isnan(b1.ciLo))
        logPass('single-parameter model returns valid bands');
    else
        logFail('single-parameter model bands are unexpected');
    end
catch ME
    logFail(sprintf('single-parameter model threw error: %s', ME.message));
end

% ════════════════════════════════════════════════════════════════════════
% Test 7: yFit matches model evaluated at xGrid
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Test 7: yFit consistency ---\n');

yRef = linFcn(xGrid, res.params);
if approxEq(bands.yFit, yRef, 1e-12)
    logPass('bands.yFit matches direct model evaluation');
else
    logFail(sprintf('yFit deviation: %.3g', max(abs(bands.yFit - yRef))));
end

% ════════════════════════════════════════════════════════════════════════
% Test 8: Linear model analytic check (CI at data centroid is narrowest)
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Test 8: CI narrowest at x-bar ---\n');

xBar = mean(xData);
% Find grid point closest to xBar
[~, iBar] = min(abs(xGrid - xBar));
ciHalfBar = bands.ciHi(iBar) - bands.yFit(iBar);

% CI should be narrower at xBar than at the extremes
ciHalfMin = bands.ciHi(1) - bands.yFit(1);
ciHalfMax = bands.ciHi(end) - bands.yFit(end);

if ciHalfBar < ciHalfMin && ciHalfBar < ciHalfMax
    logPass('CI is narrowest near the data centroid (x-bar)');
else
    logFail(sprintf('CI not narrowest at centroid: bar=%.4g vs ends=%.4g/%.4g', ...
        ciHalfBar, ciHalfMin, ciHalfMax));
end

% ════════════════════════════════════════════════════════════════════════
% Summary
% ════════════════════════════════════════════════════════════════════════

fprintf('\n=== test_fitBands: %d passed, %d failed ===\n\n', ...
    TEST_FITBANDS_PASSED, TEST_FITBANDS_FAILED);
if TEST_FITBANDS_FAILED > 0
    error('test_fitBands: %d test(s) FAILED', TEST_FITBANDS_FAILED);
end

% ════════════════════════════════════════════════════════════════════════
% Helpers (must be at end of script for R2022b–R2023b compatibility;
% R2024a relaxed this to allow function defs anywhere in scripts)
% ════════════════════════════════════════════════════════════════════════

function tf = approxEq(a, b, tol)
    tf = all(abs(a - b) <= tol);
end

function logPass(msg)
    global TEST_FITBANDS_PASSED %#ok<GVMIS>
    fprintf('  PASS: %s\n', msg);
    TEST_FITBANDS_PASSED = TEST_FITBANDS_PASSED + 1;
end

function logFail(msg)
    global TEST_FITBANDS_FAILED %#ok<GVMIS>
    fprintf('  FAIL: %s\n', msg);
    TEST_FITBANDS_FAILED = TEST_FITBANDS_FAILED + 1;
end
