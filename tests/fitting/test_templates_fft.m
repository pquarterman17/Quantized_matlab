%TEST_TEMPLATES_FFT  Tests for publication templates (+styles/template,
%   +plotting/applyTemplate) and FFT filtering (+utilities/fftFilter).
%
%   Run:
%     run tests/fitting/test_templates_fft
%     runAllTests(Group="fitting")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_templates_fft ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  PUBLICATION TEMPLATES
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- styles.template ---\n');

% All template names load without error
templateNames = {'aps', 'aps_double', 'nature', 'nature_double', ...
    'thesis', 'presentation', 'poster', 'screen'};
allLoadOk = true;
for i = 1:numel(templateNames)
    try
        t = styles.template(templateNames{i});
        if ~isfield(t, 'name') || ~isfield(t, 'fontName') || ...
           ~isfield(t, 'figWidth_cm') || ~isfield(t, 'dpi')
            allLoadOk = false;
            fprintf('    missing fields in: %s\n', templateNames{i});
        end
    catch ME
        allLoadOk = false;
        fprintf('    error in %s: %s\n', templateNames{i}, ME.message);
    end
end
if allLoadOk
    fprintf('  PASS: all %d templates load with required fields\n', numel(templateNames));
    passed = passed + 1;
else
    fprintf('  FAIL: some templates failed\n'); failed = failed + 1;
end

% APS template has correct figure width
tAps = styles.template('aps');
if abs(tAps.figWidth_cm - 8.6) < 0.01
    fprintf('  PASS: APS width = 8.6 cm\n'); passed = passed + 1;
else
    fprintf('  FAIL: APS width = %.2f (exp 8.6)\n', tAps.figWidth_cm); failed = failed + 1;
end

% Nature template uses Arial 7pt
tNat = styles.template('nature');
if strcmp(tNat.fontName, 'Arial') && tNat.fontSize == 7
    fprintf('  PASS: Nature uses Arial 7pt\n'); passed = passed + 1;
else
    fprintf('  FAIL: Nature font: %s %dpt\n', tNat.fontName, tNat.fontSize); failed = failed + 1;
end

% Thesis template uses Times
tThesis = styles.template('thesis');
if contains(tThesis.fontName, 'Times')
    fprintf('  PASS: Thesis uses Times family\n'); passed = passed + 1;
else
    fprintf('  FAIL: Thesis font: %s\n', tThesis.fontName); failed = failed + 1;
end

% Presentation has larger fonts than APS
tPres = styles.template('presentation');
if tPres.fontSize > tAps.fontSize && tPres.lineWidth > tAps.lineWidth
    fprintf('  PASS: Presentation has larger fonts and thicker lines\n'); passed = passed + 1;
else
    fprintf('  FAIL: Presentation scaling incorrect\n'); failed = failed + 1;
end

% All templates have color palette
allColorsOk = true;
for i = 1:numel(templateNames)
    t = styles.template(templateNames{i});
    if ~isfield(t, 'colors') || size(t.colors, 2) ~= 3 || size(t.colors, 1) < 4
        allColorsOk = false;
    end
end
if allColorsOk
    fprintf('  PASS: all templates have valid color palette\n'); passed = passed + 1;
else
    fprintf('  FAIL: some templates missing color palette\n'); failed = failed + 1;
end

% Unknown template throws error
try
    styles.template('nonexistent');
    fprintf('  FAIL: unknown template should throw error\n'); failed = failed + 1;
catch
    fprintf('  PASS: unknown template throws error\n'); passed = passed + 1;
end

% Journal templates have no grid (gridAlpha = 0)
if tAps.gridAlpha == 0 && tNat.gridAlpha == 0
    fprintf('  PASS: journal templates have grid off\n'); passed = passed + 1;
else
    fprintf('  FAIL: journal templates should have gridAlpha=0\n'); failed = failed + 1;
end

% Journal templates have legend box off
if ~tAps.legendBox && ~tNat.legendBox
    fprintf('  PASS: journal templates have legend box off\n'); passed = passed + 1;
else
    fprintf('  FAIL: journal templates should have legendBox=false\n'); failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  FFT FILTER
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- utilities.fftFilter ---\n');

% Generate test signal: 10 Hz sine + 60 Hz noise + DC offset
fs = 1000;  % 1000 samples/sec
N = 1000;
t = (0:N-1)' / fs;
signal10  = 2.0 * sin(2*pi*10*t);    % desired signal
noise60   = 0.5 * sin(2*pi*60*t);    % line noise
noise200  = 0.3 * sin(2*pi*200*t);   % HF noise
y = signal10 + noise60 + noise200 + 1.0;  % DC = 1.0

% ── Lowpass at 50 Hz: should keep 10 Hz, remove 60 Hz and 200 Hz ──

r = utilities.fftFilter(t, y, Type='lowpass', Cutoff=30, Order=6);

% After filtering, the 60 Hz and 200 Hz components should be greatly reduced
% Measure amplitude at 60 Hz in filtered signal
Y_filt = fft(r.yFiltered - mean(r.yFiltered));
freqAxis = (0:N-1)' * fs / N;
amp60_orig = 2 * abs(fft(y - mean(y))) / N;
amp60_filt = 2 * abs(Y_filt) / N;

idx60 = find(abs(freqAxis - 60) < 1, 1);
if ~isempty(idx60) && amp60_filt(idx60) < amp60_orig(idx60) * 0.15
    fprintf('  PASS: lowpass removes 60 Hz (%.4f → %.4f)\n', ...
        amp60_orig(idx60), amp60_filt(idx60));
    passed = passed + 1;
else
    fprintf('  FAIL: lowpass did not sufficiently attenuate 60 Hz\n');
    failed = failed + 1;
end

% 10 Hz component should be preserved (within 20%)
idx10 = find(abs(freqAxis - 10) < 1, 1);
if ~isempty(idx10) && amp60_filt(idx10) > amp60_orig(idx10) * 0.8
    fprintf('  PASS: lowpass preserves 10 Hz signal\n'); passed = passed + 1;
else
    fprintf('  FAIL: lowpass attenuated 10 Hz too much\n'); failed = failed + 1;
end

% ── Highpass at 50 Hz: should remove 10 Hz, keep 60 Hz ────────────

r2 = utilities.fftFilter(t, y, Type='highpass', Cutoff=50, Order=6);
Y_hp = fft(r2.yFiltered - mean(r2.yFiltered));
amp_hp = 2 * abs(Y_hp) / N;

if ~isempty(idx10) && amp_hp(idx10) < 0.1  % 10 Hz should be gone
    fprintf('  PASS: highpass removes 10 Hz\n'); passed = passed + 1;
else
    fprintf('  FAIL: highpass did not remove 10 Hz\n'); failed = failed + 1;
end

% ── Bandpass 40-80 Hz: should isolate 60 Hz ──────────────────────

r3 = utilities.fftFilter(t, y, Type='bandpass', Cutoff=[40 80], Order=6);
Y_bp = fft(r3.yFiltered - mean(r3.yFiltered));
amp_bp = 2 * abs(Y_bp) / N;

if ~isempty(idx60) && amp_bp(idx60) > 0.3 && amp_bp(idx10) < 0.1
    fprintf('  PASS: bandpass isolates 60 Hz\n'); passed = passed + 1;
else
    fprintf('  FAIL: bandpass did not isolate 60 Hz correctly\n'); failed = failed + 1;
end

% ── Notch at 60 Hz: should remove only 60 Hz ─────────────────────

r4 = utilities.fftFilter(t, y, Type='notch', Cutoff=60, Bandwidth=20, Order=6);
Y_notch = fft(r4.yFiltered - mean(r4.yFiltered));
amp_notch = 2 * abs(Y_notch) / N;

if ~isempty(idx60) && amp_notch(idx60) < 0.15 && amp_notch(idx10) > 0.5 * amp60_orig(idx10)
    fprintf('  PASS: notch removes 60 Hz while preserving 10 Hz\n'); passed = passed + 1;
else
    fprintf('  FAIL: notch filter performance\n'); failed = failed + 1;
end

% ── Output struct has all expected fields ─────────────────────────

expectedFields = {'yFiltered','freq','power','powerFilt','transfer','freqPos','powerPos'};
allFieldsOk = true;
for i = 1:numel(expectedFields)
    if ~isfield(r, expectedFields{i})
        allFieldsOk = false;
    end
end
if allFieldsOk
    fprintf('  PASS: output struct has all expected fields\n'); passed = passed + 1;
else
    fprintf('  FAIL: output struct missing fields\n'); failed = failed + 1;
end

% ── yFiltered is same length as input ─────────────────────────────

if numel(r.yFiltered) == N
    fprintf('  PASS: output length matches input\n'); passed = passed + 1;
else
    fprintf('  FAIL: output length %d (exp %d)\n', numel(r.yFiltered), N); failed = failed + 1;
end

% ── Window functions don't crash ──────────────────────────────────

windowsOk = true;
for wn = ["hamming", "hanning", "blackman"]
    try
        rw = utilities.fftFilter(t, y, Type='lowpass', Cutoff=50, Window=wn);
        if numel(rw.yFiltered) ~= N, windowsOk = false; end
    catch
        windowsOk = false;
    end
end
if windowsOk
    fprintf('  PASS: all window functions work\n'); passed = passed + 1;
else
    fprintf('  FAIL: some window functions failed\n'); failed = failed + 1;
end

% ── Detrend option ────────────────────────────────────────────────

yTrend = y + 5*t;  % add a linear trend
r5 = utilities.fftFilter(t, yTrend, Type='lowpass', Cutoff=50, Detrend=true);
% After detrend+filter, the trend should be restored
trendSlope = (r5.yFiltered(end) - r5.yFiltered(1)) / (t(end) - t(1));
if abs(trendSlope - 5) < 1  % should preserve ~5 units/s trend
    fprintf('  PASS: detrend preserves linear trend\n'); passed = passed + 1;
else
    fprintf('  FAIL: detrend slope = %.2f (exp ~5)\n', trendSlope); failed = failed + 1;
end

% ── Too-short data throws error ───────────────────────────────────

try
    utilities.fftFilter([1;2;3], [1;2;3], Type='lowpass', Cutoff=1);
    fprintf('  FAIL: short data should throw error\n'); failed = failed + 1;
catch
    fprintf('  PASS: short data throws error\n'); passed = passed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_templates_fft: %d passed, %d failed ===\n\n', passed, failed);
if failed > 0
    error('test_templates_fft:failures', '%d test(s) failed.', failed);
end
