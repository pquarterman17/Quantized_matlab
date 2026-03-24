%TEST_PEAK_DETECTION  Tests for robust peak detection and background estimation.
%
%   Tests adaptive local noise, prominence filtering, iterative background,
%   and handling of high dynamic range / sloped data.
%
%   Run:
%     run tests/fitting/test_peak_detection
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_peak_detection ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  BACKGROUND ESTIMATION
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- estimateBackground ---\n');

% Basic SNIP on flat data with a peak
x = linspace(0, 100, 500)';
yFlat = 100 + 20 * exp(-0.5 * ((x - 50) / 2).^2);
bg = utilities.estimateBackground(x, yFlat);
if max(bg) < 110 && min(bg) > 90
    fprintf('  PASS: SNIP flat background\n'); passed = passed + 1;
else
    fprintf('  FAIL: SNIP flat background\n'); failed = failed + 1;
end

% Sloped background with peaks
ySloped = 50 + 2*x + 30 * exp(-0.5 * ((x-30)/1.5).^2) + ...
                       15 * exp(-0.5 * ((x-70)/2).^2);
bg = utilities.estimateBackground(x, ySloped, 'Iterative', true);
% Background should follow the slope, not the peaks
bgAtPeaks = interp1(x, bg, [30; 70]);
trueSlope = 50 + 2*[30; 70];
if all(abs(bgAtPeaks - trueSlope) < 15)
    fprintf('  PASS: iterative SNIP on sloped data\n'); passed = passed + 1;
else
    fprintf('  FAIL: iterative SNIP on sloped data (error=%.1f,%.1f)\n', ...
        abs(bgAtPeaks(1)-trueSlope(1)), abs(bgAtPeaks(2)-trueSlope(2)));
    failed = failed + 1;
end

% Polynomial background
bg = utilities.estimateBackground(x, ySloped, 'Method', 'polynomial', 'PolyDegree', 2);
if numel(bg) == numel(x) && all(isfinite(bg))
    fprintf('  PASS: polynomial background returns valid output\n'); passed = passed + 1;
else
    fprintf('  FAIL: polynomial background\n'); failed = failed + 1;
end

% Edge case: very few points
bgShort = utilities.estimateBackground([1;2], [5;6]);
if numel(bgShort) == 2
    fprintf('  PASS: short data edge case\n'); passed = passed + 1;
else
    fprintf('  FAIL: short data edge case\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  PEAK DETECTION — BASIC
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- findPeaksRobust (basic) ---\n');

% Single clear peak (narrow, XRD-like)
x1 = linspace(20, 80, 1000)';
y1 = 10 + 50 * exp(-0.5 * ((x1-50)/0.5).^2);
pks = utilities.findPeaksRobust(x1, y1);
if numel(pks) >= 1 && any(abs([pks.center] - 50) < 1)
    fprintf('  PASS: single peak detected at correct position\n'); passed = passed + 1;
else
    fprintf('  FAIL: single peak detection (found %d peaks)\n', numel(pks)); failed = failed + 1;
end

% Two well-separated peaks
y2 = 10 + 40 * exp(-0.5 * ((x1-35)/0.5).^2) + ...
          30 * exp(-0.5 * ((x1-65)/0.5).^2);
pks = utilities.findPeaksRobust(x1, y2);
if numel(pks) == 2
    fprintf('  PASS: two separated peaks\n'); passed = passed + 1;
else
    fprintf('  FAIL: two separated peaks (found %d)\n', numel(pks)); failed = failed + 1;
end

% No peaks (flat data with noise) — allow a few false detections
rng(42);
yFlat2 = 100 + 0.5 * randn(numel(x1), 1);
pks = utilities.findPeaksRobust(x1, yFlat2);
if numel(pks) <= 10
    fprintf('  PASS: few false peaks on flat noise (%d)\n', numel(pks)); passed = passed + 1;
else
    fprintf('  FAIL: too many false peaks on flat noise (found %d)\n', numel(pks)); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  PEAK DETECTION — HIGH DYNAMIC RANGE
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- findPeaksRobust (dynamic range) ---\n');

% Strong peak at x=30 (height=10000) and weak peak at x=60 (height=50)
x3 = linspace(20, 80, 2000)';
rng(42);
y3 = 20 + 0.5*randn(2000,1) + ...
     10000 * exp(-0.5*((x3-35)/0.3).^2) + ...
     50    * exp(-0.5*((x3-60)/0.4).^2);
y3 = max(y3, 0);  % no negative counts

pks = utilities.findPeaksRobust(x3, y3, 'Sensitivity', 'high');
centers = [pks.center];
foundStrong = any(abs(centers - 35) < 2);
foundWeak   = any(abs(centers - 60) < 3);

if foundStrong && foundWeak
    fprintf('  PASS: found both strong and weak peaks (200:1 ratio)\n'); passed = passed + 1;
else
    fprintf('  FAIL: dynamic range (strong=%d, weak=%d, total=%d)\n', ...
        foundStrong, foundWeak, numel(pks)); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  PEAK DETECTION — SLOPED BACKGROUND (FALSE POSITIVE REJECTION)
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- findPeaksRobust (slope rejection) ---\n');

% Steep slope with one real peak — should not detect bumps on slope
x4 = linspace(10, 80, 1000)';
rng(42);
ySlope = 500 * exp(-0.05*(x4-10)) + 1*randn(1000,1);  % exponential decay
ySlope = ySlope + 60 * exp(-0.5*((x4-45)/0.5).^2);     % one real narrow peak
ySlope = max(ySlope, 0);

pks = utilities.findPeaksRobust(x4, ySlope);
% Should find exactly 1 peak near x=45, not noise on the slope
realPeaks = pks(abs([pks.center] - 45) < 5);
if numel(realPeaks) >= 1
    fprintf('  PASS: found real peak on sloped background\n'); passed = passed + 1;
else
    fprintf('  FAIL: missed real peak on slope (found %d total)\n', numel(pks)); failed = failed + 1;
end

% Check that there aren't many false positives on the slope
if numel(pks) <= 3
    fprintf('  PASS: few false positives on slope (%d total)\n', numel(pks)); passed = passed + 1;
else
    fprintf('  FAIL: too many false positives on slope (%d peaks)\n', numel(pks)); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  PEAK DETECTION — PROMINENCE
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- findPeaksRobust (prominence) ---\n');

% Create data with one prominent peak and a shoulder (low prominence)
x5 = linspace(20, 80, 1000)';
y5 = 10 + 100 * exp(-0.5*((x5-50)/0.5).^2) + ...   % main peak (FWHM~1.18)
     12 * exp(-0.5*((x5-52)/0.3).^2);                % shoulder

pks = utilities.findPeaksRobust(x5, y5, 'MinProminence', 0.10);
foundMain = any(abs([pks.center] - 50) < 3);
if foundMain && numel(pks) <= 2
    fprintf('  PASS: prominence filtering keeps main peak (found %d)\n', numel(pks)); passed = passed + 1;
else
    fprintf('  FAIL: prominence filtering (found %d peaks, main=%d)\n', numel(pks), foundMain); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  PEAK DETECTION — SENSITIVITY PRESETS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- findPeaksRobust (sensitivity) ---\n');

x6 = linspace(20, 80, 1000)';
rng(42);
y6 = 20 + 2*randn(1000,1) + ...
     80 * exp(-0.5*((x6-30)/0.4).^2) + ...
     12 * exp(-0.5*((x6-50)/0.5).^2) + ...     % borderline peak
     60 * exp(-0.5*((x6-65)/0.4).^2);

pksLow  = utilities.findPeaksRobust(x6, y6, 'Sensitivity', 'low');
pksMed  = utilities.findPeaksRobust(x6, y6, 'Sensitivity', 'medium');
pksHigh = utilities.findPeaksRobust(x6, y6, 'Sensitivity', 'high');

if numel(pksLow) <= numel(pksMed) && numel(pksMed) <= numel(pksHigh)
    fprintf('  PASS: sensitivity monotonicity (low=%d, med=%d, high=%d)\n', ...
        numel(pksLow), numel(pksMed), numel(pksHigh)); passed = passed + 1;
else
    fprintf('  FAIL: sensitivity monotonicity (low=%d, med=%d, high=%d)\n', ...
        numel(pksLow), numel(pksMed), numel(pksHigh)); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  OUTPUT STRUCT FIELDS
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- output struct ---\n');

pks = utilities.findPeaksRobust(x1, y1);
if ~isempty(pks)
    reqFields = {'center','fwhm','height','area','xRange','status','bg','model','eta','prominence','localSNR'};
    allOk = true;
    for fi = 1:numel(reqFields)
        if ~isfield(pks, reqFields{fi})
            allOk = false;
            fprintf('  FAIL: missing field %s\n', reqFields{fi});
        end
    end
    if allOk
        fprintf('  PASS: all output fields present (including prominence, localSNR)\n'); passed = passed + 1;
    else
        failed = failed + 1;
    end
else
    fprintf('  FAIL: no peaks returned for struct test\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  FWHM ACCURACY
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- FWHM accuracy ---\n');

% Gaussian peak with known FWHM = 2*sqrt(2*ln(2))*sigma ~ 0.59 for sigma=0.25
sigma = 0.25;
trueFWHM = 2 * sqrt(2 * log(2)) * sigma;  % ~0.589
xf = linspace(20, 80, 2000)';
yf = 10 + 100 * exp(-0.5 * ((xf - 50)/sigma).^2);
pks = utilities.findPeaksRobust(xf, yf);
if ~isempty(pks) && abs(pks(1).fwhm - trueFWHM) < 0.15
    fprintf('  PASS: FWHM = %.3f (true = %.3f)\n', pks(1).fwhm, trueFWHM); passed = passed + 1;
else
    fwEst = 0;
    if ~isempty(pks), fwEst = pks(1).fwhm; end
    fprintf('  FAIL: FWHM = %.3f (true = %.3f)\n', fwEst, trueFWHM); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_peak_detection: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_peak_detection:fail', '%d test(s) failed', failed);
end
