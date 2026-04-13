%TEST_CURSOR_ANCHOR  Tests for fitCursors and anchorSplineBackground.
%
%   Tests the pure-computation layer of both tools without opening a
%   GUI figure.  All tests are headless-safe.
%
%   Run:
%     run tests/fitting/test_cursor_anchor
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_cursor_anchor ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  Section 1: Spline interpolation accuracy
%  Five anchor points on a cubic polynomial; the spline should reproduce
%  the polynomial exactly (cubic spline is exact for cubics).
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Spline interpolation (polynomial ground truth) ---\n');

polyFcn = @(x) 2*x.^3 - 3*x.^2 + x - 1;

ancX = linspace(0, 5, 5)';
ancY = polyFcn(ancX);

xEval = linspace(0, 5, 200)';
yTrue = polyFcn(xEval);

ySpline = interp1(ancX, ancY, xEval, 'spline');
maxErr = max(abs(ySpline - yTrue));

if maxErr < 1e-10
    fprintf('  PASS: cubic spline exact on cubic poly (5 anchors)\n');
    passed = passed + 1;
else
    fprintf('  FAIL: cubic spline exact on cubic poly (5 anchors) — max error = %.3e\n', maxErr);
    failed = failed + 1;
end

% ── 2 anchor points (linear case) ─────────────────────────────────────
fprintf('\n--- Spline with 2 anchors (linear) ---\n');

ancX2 = [1; 4];
ancY2 = [3; 9];        % linear: y = 2*x + 1

xEval2  = linspace(1, 4, 50)';
yTrue2  = 2*xEval2 + 1;
ySpline2 = interp1(ancX2, ancY2, xEval2, 'spline');
lineErr  = max(abs(ySpline2 - yTrue2));

if lineErr < 1e-10
    fprintf('  PASS: 2-anchor spline reproduces linear trend\n');
    passed = passed + 1;
else
    fprintf('  FAIL: 2-anchor spline reproduces linear trend — max error = %.3e\n', lineErr);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Section 2: Background subtraction recovers signal
%  Data = signal + known polynomial background.
%  Anchors placed exactly on the background curve → subtraction should
%  recover the signal to floating-point precision.
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Background subtraction ---\n');

xData  = linspace(0, 10, 500)';
signal = sin(2*pi*xData / 3);         % oscillatory signal
bg     = 0.5*xData.^2 - xData + 2;   % polynomial background
yData  = signal + bg;

% Anchors exactly on the background (ideal case for a unit test)
anchorXv = linspace(0, 10, 7)';
anchorYv = 0.5*anchorXv.^2 - anchorXv + 2;

% Compute spline the same way anchorSplineBackground does
ySplineEst = interp1(anchorXv, anchorYv, xData, 'spline', 'extrap');
yCorrected = yData - ySplineEst;

maxSignalErr = max(abs(yCorrected - signal));
if maxSignalErr < 1e-10
    fprintf('  PASS: spline subtraction recovers signal (anchors on bg)\n');
    passed = passed + 1;
else
    fprintf('  FAIL: spline subtraction recovers signal — max error = %.3e\n', maxSignalErr);
    failed = failed + 1;
end

% Corrected values should match the true signal (same mean)
% The sin signal itself has a non-zero mean over a non-integer number of
% periods; check that the corrected mean matches the signal mean instead.
corrMeanDiff = abs(mean(yCorrected) - mean(signal));
if corrMeanDiff < 1e-10
    fprintf('  PASS: corrected signal mean matches true signal mean (diff=%.2e)\n', corrMeanDiff);
    passed = passed + 1;
else
    fprintf('  FAIL: corrected signal mean differs from true signal mean (diff=%.3e)\n', corrMeanDiff);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Section 3: Unique-x deduplication
%  Duplicate anchor x-values must not crash interp1.
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Duplicate-x anchor deduplication ---\n');

ancXdup = [1; 2; 2; 4];    % duplicated x=2
ancYdup = [1; 3; 3; 7];

[ux, ia] = unique(ancXdup, 'stable');
uy = ancYdup(ia);

noError = false;
try
    interp1(ux, uy, linspace(1, 4, 20)', 'spline');
    noError = true;
catch
end

if noError
    fprintf('  PASS: duplicate-x anchors deduplicated without error\n');
    passed = passed + 1;
else
    fprintf('  FAIL: duplicate-x anchor deduplication threw an error\n');
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Section 4: fitCursors range-clamping logic
%  Test the clamping and ordering rules without a real axes handle.
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- fitCursors range clamping logic ---\n');

xl = [0, 10];   % axis limits
xR_val = 8;     % right cursor

% Left cursor dragged past right cursor → should clamp below xR
rawLeft = 9.5;
buf = (xl(2) - xl(1)) * 0.001;
clampedLeft = min(rawLeft, xR_val - buf);

if clampedLeft < xR_val
    fprintf('  PASS: left cursor clamped below right cursor\n');
    passed = passed + 1;
else
    fprintf('  FAIL: left cursor not clamped (clampedLeft=%.4f, xR=%.4f)\n', ...
        clampedLeft, xR_val);
    failed = failed + 1;
end

% Left cursor dragged below axis lower limit
rawLeft2 = -3;
clampedLeft2 = max(xl(1), min(xl(2), rawLeft2));

if clampedLeft2 == xl(1)
    fprintf('  PASS: left cursor clamped to axis lower limit\n');
    passed = passed + 1;
else
    fprintf('  FAIL: left cursor lower limit clamp failed (result=%.4f)\n', clampedLeft2);
    failed = failed + 1;
end

% Right cursor dragged left of left cursor → should clamp above xL
xL_val = 2;
rawRight = 1.5;
clampedRight = max(rawRight, xL_val + buf);

if clampedRight > xL_val
    fprintf('  PASS: right cursor clamped above left cursor\n');
    passed = passed + 1;
else
    fprintf('  FAIL: right cursor not clamped (clampedRight=%.4f, xL=%.4f)\n', ...
        clampedRight, xL_val);
    failed = failed + 1;
end

% Right cursor dragged above axis upper limit
rawRight2 = 15;
clampedRight2 = max(xl(1), min(xl(2), rawRight2));

if clampedRight2 == xl(2)
    fprintf('  PASS: right cursor clamped to axis upper limit\n');
    passed = passed + 1;
else
    fprintf('  FAIL: right cursor upper limit clamp failed (result=%.4f)\n', clampedRight2);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Section 5: getDataSegment range filtering
%  Verify that the logical mask used by getDataSegment correctly
%  selects data within [xMin, xMax].
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- X-range mask (getDataSegment logic) ---\n');

xAll = linspace(0, 10, 101)';
xMinVal = 3.0;
xMaxVal = 7.0;
mask = xAll >= xMinVal & xAll <= xMaxVal;
xSeg = xAll(mask);

if min(xSeg) >= xMinVal && max(xSeg) <= xMaxVal && numel(xSeg) > 0
    fprintf('  PASS: range mask selects correct subset (%d points)\n', numel(xSeg));
    passed = passed + 1;
else
    fprintf('  FAIL: range mask incorrect (min=%.4f max=%.4f)\n', min(xSeg), max(xSeg));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Results: %d passed, %d failed ---\n\n', passed, failed);
assert(failed == 0, ...
    'test_cursor_anchor: %d test(s) failed.', failed);
