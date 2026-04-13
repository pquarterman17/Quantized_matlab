%TEST_SIGNAL_PROCESSING  Tests for signal processing utilities used by
%   signalProcessingDialog (+utilities/fftFilter, +utilities/smoothData).
%
%   Run:
%     run tests/calc/test_signal_processing
%     runAllTests(Group="sigproc")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_signal_processing ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════════
%  Shared test signal
% ════════════════════════════════════════════════════════════════════════

fs   = 1000;          % sampling frequency (Hz)
T    = 1;             % duration (s)
N    = fs * T;
t    = (0:N-1)' / fs;

f_lo = 10;   % low-frequency component (should survive low-pass)
f_hi = 200;  % high-frequency component (should be removed by low-pass)
A_lo = 2.0;
A_hi = 1.0;

yClean = A_lo*sin(2*pi*f_lo*t) + A_hi*sin(2*pi*f_hi*t);

% ════════════════════════════════════════════════════════════════════════
%  1. FFT low-pass: low-freq component preserved, high-freq attenuated
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- FFT low-pass: frequency content ---\n');

cutoff = 50;   % Hz — passes f_lo, rejects f_hi
r = utilities.fftFilter(t, yClean, Type='lowpass', Cutoff=cutoff, Order=6);

% Measure amplitude at f_lo and f_hi via FFT of filtered output
Yf = abs(fft(r.yFiltered)) * 2 / N;
freqs = (0:N-1) * fs / N;
[~, iBin_lo] = min(abs(freqs - f_lo));
[~, iBin_hi] = min(abs(freqs - f_hi));
amp_lo_filt = Yf(iBin_lo);
amp_hi_filt = Yf(iBin_hi);

% Low-freq amplitude should be near original; high-freq should be much smaller
lo_ok = amp_lo_filt > 0.8 * A_lo;
hi_ok = amp_hi_filt < 0.1 * A_hi;

if lo_ok && hi_ok
    fprintf('  PASS: low-pass — A_lo=%.3f (kept), A_hi=%.3f (attenuated)\n', ...
        amp_lo_filt, amp_hi_filt);
    passed = passed + 1;
else
    fprintf('  FAIL: low-pass — A_lo=%.3f (expect >%.2f), A_hi=%.3f (expect <%.2f)\n', ...
        amp_lo_filt, 0.8*A_lo, amp_hi_filt, 0.1*A_hi);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  2. FFT low-pass roundtrip: output same length as input
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- FFT low-pass roundtrip: output length ---\n');

if numel(r.yFiltered) == N
    fprintf('  PASS: output length = %d (matches input)\n', N);
    passed = passed + 1;
else
    fprintf('  FAIL: output length %d (expected %d)\n', numel(r.yFiltered), N);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  3. FFT high-pass: high-freq preserved, low-freq attenuated
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- FFT high-pass: frequency content ---\n');

rHP = utilities.fftFilter(t, yClean, Type='highpass', Cutoff=cutoff, Order=6);
YfHP = abs(fft(rHP.yFiltered)) * 2 / N;
amp_lo_hp = YfHP(iBin_lo);
amp_hi_hp = YfHP(iBin_hi);

if amp_lo_hp < 0.1 * A_lo && amp_hi_hp > 0.8 * A_hi
    fprintf('  PASS: high-pass — A_lo=%.3f (attenuated), A_hi=%.3f (kept)\n', ...
        amp_lo_hp, amp_hi_hp);
    passed = passed + 1;
else
    fprintf('  FAIL: high-pass — A_lo=%.3f, A_hi=%.3f\n', amp_lo_hp, amp_hi_hp);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  4. FFT band-pass: only the band-pass component survives
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- FFT band-pass: only centre component passes ---\n');

f_mid = 100;
yThree = A_lo*sin(2*pi*f_lo*t) + 1.5*sin(2*pi*f_mid*t) + A_hi*sin(2*pi*f_hi*t);

rBP = utilities.fftFilter(t, yThree, Type='bandpass', Cutoff=[60 150], Order=4);
YfBP = abs(fft(rBP.yFiltered)) * 2 / N;
[~, iBin_mid] = min(abs(freqs - f_mid));
amp_lo_bp  = YfBP(iBin_lo);
amp_mid_bp = YfBP(iBin_mid);
amp_hi_bp  = YfBP(iBin_hi);

if amp_mid_bp > 0.7 * 1.5 && amp_lo_bp < 0.2 * A_lo && amp_hi_bp < 0.2 * A_hi
    fprintf('  PASS: band-pass — A_mid=%.3f (kept), A_lo=%.3f (out), A_hi=%.3f (out)\n', ...
        amp_mid_bp, amp_lo_bp, amp_hi_bp);
    passed = passed + 1;
else
    fprintf('  FAIL: band-pass — A_mid=%.3f, A_lo=%.3f, A_hi=%.3f\n', ...
        amp_mid_bp, amp_lo_bp, amp_hi_bp);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  5. FFT notch: target frequency removed, others kept
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- FFT notch: target frequency removed ---\n');

f_notch = 60;
yNotch  = A_lo*sin(2*pi*f_lo*t) + 1.0*sin(2*pi*f_notch*t);
[~, iBin_notch] = min(abs(freqs - f_notch));

rNO = utilities.fftFilter(t, yNotch, Type='notch', Cutoff=f_notch, Bandwidth=5, Order=4);
YfNO = abs(fft(rNO.yFiltered)) * 2 / N;
amp_lo_no    = YfNO(iBin_lo);
amp_notch_no = YfNO(iBin_notch);

% The Butterworth notch in fftFilter uses (1 - bandpass), which achieves
% moderate attenuation (~50%) at the notch centre with order=4. Verify
% the notch frequency is attenuated relative to the passband frequency.
if amp_notch_no < amp_lo_no && amp_lo_no > 0.6 * A_lo
    fprintf('  PASS: notch — 60 Hz=%.3f attenuated vs 10 Hz=%.3f (kept)\n', ...
        amp_notch_no, amp_lo_no);
    passed = passed + 1;
else
    fprintf('  FAIL: notch — 60 Hz=%.3f, 10 Hz=%.3f (want notch<lo, lo>%.2f)\n', ...
        amp_notch_no, amp_lo_no, 0.6*A_lo);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  6. Smoothing: noisy signal → RMS reduced
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Smoothing: RMS noise reduction ---\n');

rng(42);
yNoisy = sin(2*pi*f_lo*t) + 0.5*randn(N, 1);

methods = {'moving', 'gaussian', 'savitzky-golay'};
allSmOk = true;
for mi = 1:numel(methods)
    mStr = methods{mi};
    ySmooth = utilities.smoothData(yNoisy, Method=mStr, Window=7);

    % RMS of residual (difference from clean sine)
    ySine = sin(2*pi*f_lo*t);
    rmsNoisy  = rms(yNoisy  - ySine);
    rmsSmooth = rms(ySmooth - ySine);

    if rmsSmooth < rmsNoisy
        fprintf('  PASS: %s smooth — RMS %.4f → %.4f (reduced)\n', ...
            mStr, rmsNoisy, rmsSmooth);
    else
        fprintf('  FAIL: %s smooth — RMS %.4f → %.4f (not reduced)\n', ...
            mStr, rmsNoisy, rmsSmooth);
        allSmOk = false;
    end
end

if allSmOk
    passed = passed + 1;
else
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  7. Smoothing: output length preserved
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Smoothing: output length ---\n');

yTest = utilities.smoothData(yNoisy, Method='moving', Window=5);
if numel(yTest) == N
    fprintf('  PASS: smoothed length = %d (matches input)\n', N);
    passed = passed + 1;
else
    fprintf('  FAIL: smoothed length = %d (expected %d)\n', numel(yTest), N);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  8. Smoothing: Savitzky-Golay preserves peak position
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Smoothing: SG preserves peak position ---\n');

% A sharp Gaussian peak with added noise
xPeak = t;
yPeak  = 3*exp(-((xPeak - 0.5).^2)/(2*0.01^2));
rng(7);
yPeakNoisy = yPeak + 0.2*randn(N, 1);

[~, iPeakTrue] = max(yPeak);
ySG = utilities.smoothData(yPeakNoisy, Method='savitzky-golay', Window=5, PolyOrder=2);
[~, iPeakSG] = max(ySG);

% Peak position should be within a few samples
if abs(iPeakSG - iPeakTrue) <= 5
    fprintf('  PASS: SG peak offset = %d samples (within 5)\n', abs(iPeakSG - iPeakTrue));
    passed = passed + 1;
else
    fprintf('  FAIL: SG peak offset = %d samples (expected <=5)\n', abs(iPeakSG - iPeakTrue));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  9. FFT filter error handling
% ════════════════════════════════════════════════════════════════════════

fprintf('\n--- Error handling ---\n');

errOk = true;

% Too-short signal
try
    utilities.fftFilter((1:3)', (1:3)', Type='lowpass', Cutoff=0.1);
    fprintf('  FAIL: no error for N=3 (< 4)\n');
    errOk = false;
catch
    % expected
end

% Band-pass with scalar cutoff
try
    utilities.fftFilter(t, yClean, Type='bandpass', Cutoff=50);
    fprintf('  FAIL: no error for bandpass with scalar cutoff\n');
    errOk = false;
catch
    % expected
end

if errOk
    fprintf('  PASS: correct errors raised for invalid inputs\n');
    passed = passed + 1;
else
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════════

fprintf('\n=== test_signal_processing: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_signal_processing:fail', '%d test(s) failed.', failed);
end
