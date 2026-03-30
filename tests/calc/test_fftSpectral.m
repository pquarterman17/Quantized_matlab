%TEST_FFTSPECTRAL  Tests for spectral analysis (+utilities/fftSpectral)
%   and cross-correlation (+utilities/crossCorrelation).
%
%   Run:
%     run tests/calc/test_fftSpectral
%     runAllTests(Group="spectral")

clear; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(fileparts(thisDir));
if ~contains(path, rootDir)
    addpath(rootDir);
end

fprintf('\n=== test_fftSpectral ===\n');
passed = 0;
failed = 0;

% ════════════════════════════════════════════════════════════════════
%  1. KNOWN SINE WAVE — peak at correct frequency
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Sine wave peak detection ---\n');

fs_test = 1000;              % 1 kHz sampling
T_test  = 1;                 % 1 second
N_test  = fs_test * T_test;
t = (0:N_test-1)' / fs_test;
f0 = 50;                     % 50 Hz test tone
A  = 3.0;                    % amplitude

y_sine = A * sin(2*pi*f0*t);

% PSD with Hanning window
r = utilities.fftSpectral(t, y_sine, Window="hanning", OutputType="psd", Detrend="none");
[~, iPeak] = max(r.psd);
fPeak = r.freq(iPeak);
if abs(fPeak - f0) <= r.df
    fprintf('  PASS: PSD peak at %.1f Hz (expected %d Hz, df=%.2f)\n', fPeak, f0, r.df);
    passed = passed + 1;
else
    fprintf('  FAIL: PSD peak at %.1f Hz (expected %d Hz)\n', fPeak, f0);
    failed = failed + 1;
end

% Magnitude spectrum — correct amplitude
r_mag = utilities.fftSpectral(t, y_sine, Window="none", OutputType="magnitude", ...
    Detrend="none", ZeroPad=N_test);
[magPeak, iPeak2] = max(r_mag.magnitude);
% For a pure sine with rectangular window and nfft=N, magnitude peak = A/2 * 2 = A (one-sided)
if abs(magPeak - A) < 0.1
    fprintf('  PASS: magnitude peak = %.3f (expected %.1f)\n', magPeak, A);
    passed = passed + 1;
else
    fprintf('  FAIL: magnitude peak = %.3f (expected %.1f)\n', magPeak, A);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  2. PARSEVAL'S THEOREM — sum(PSD)*df ≈ var(signal)
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Parseval''s theorem ---\n');

% Use a noisy signal so variance is well-defined
rng(42);
y_noisy = 2*sin(2*pi*100*t) + randn(N_test,1);
sigVar = var(y_noisy);

% Test with each window type
windowNames = {"none", "hanning", "hamming", "blackman", "flattop", "kaiser"};
parsAllOk = true;
for w = 1:numel(windowNames)
    wName = windowNames{w};
    rp = utilities.fftSpectral(t, y_noisy, Window=wName, OutputType="psd", ...
        Detrend="mean", ZeroPad=N_test);
    psdIntegral = sum(rp.psd) * rp.df;
    relErr = abs(psdIntegral - sigVar) / sigVar;
    if relErr > 0.15
        fprintf('  FAIL: Parseval (%s): integral=%.4f, var=%.4f, err=%.1f%%\n', ...
            wName, psdIntegral, sigVar, relErr*100);
        parsAllOk = false;
    end
end
if parsAllOk
    fprintf('  PASS: Parseval holds for all 6 windows (< 15%% error)\n');
    passed = passed + 1;
else
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  3. DETREND removes DC offset from spectrum
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Detrend removes DC ---\n');

dcOffset = 100;
y_dc = y_sine + dcOffset;

% Without detrend — DC bin should be large
r_noDt = utilities.fftSpectral(t, y_dc, Detrend="none", OutputType="magnitude");
dcBin_noDt = r_noDt.magnitude(1);

% With mean detrend — DC bin should be ~0
r_dt = utilities.fftSpectral(t, y_dc, Detrend="mean", OutputType="magnitude");
dcBin_dt = r_dt.magnitude(1);

if dcBin_noDt > 50 && dcBin_dt < 1
    fprintf('  PASS: DC bin without detrend=%.1f, with detrend=%.4f\n', dcBin_noDt, dcBin_dt);
    passed = passed + 1;
else
    fprintf('  FAIL: DC bin without detrend=%.1f, with detrend=%.4f\n', dcBin_noDt, dcBin_dt);
    failed = failed + 1;
end

% Linear detrend removes a ramp
y_ramp = y_sine + linspace(0, 50, N_test)';
r_linDt = utilities.fftSpectral(t, y_ramp, Detrend="linear", OutputType="magnitude");
dcBin_lin = r_linDt.magnitude(1);
if dcBin_lin < 1
    fprintf('  PASS: linear detrend removes ramp, DC=%.4f\n', dcBin_lin);
    passed = passed + 1;
else
    fprintf('  FAIL: linear detrend DC=%.4f (expected ~0)\n', dcBin_lin);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  4. ZERO-PADDING increases frequency resolution
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Zero-padding ---\n');

% Default: next power of 2
r_def = utilities.fftSpectral(t, y_sine);
df_def = r_def.df;

% Explicit zero-pad to 4x
r_zp = utilities.fftSpectral(t, y_sine, ZeroPad=4*N_test);
df_zp = r_zp.df;

if df_zp < df_def && abs(df_zp - fs_test/(4*N_test)) < 1e-6
    fprintf('  PASS: df default=%.4f Hz, 4x pad=%.4f Hz\n', df_def, df_zp);
    passed = passed + 1;
else
    fprintf('  FAIL: df default=%.4f Hz, 4x pad=%.4f Hz\n', df_def, df_zp);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  5. TWO-SIDED spectrum
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Two-sided spectrum ---\n');

r2 = utilities.fftSpectral(t, y_sine, Sided="two", OutputType="psd", Detrend="none");
% Frequency axis should span negative to positive
if min(r2.freq) < 0 && max(r2.freq) > 0
    fprintf('  PASS: two-sided freq range [%.1f, %.1f] Hz\n', min(r2.freq), max(r2.freq));
    passed = passed + 1;
else
    fprintf('  FAIL: two-sided freq range [%.1f, %.1f] Hz\n', min(r2.freq), max(r2.freq));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  6. PHASE spectrum
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Phase spectrum ---\n');

% Cosine at f0 should have ~0 degree phase at peak; sine should have ~-90
y_cos = A * cos(2*pi*f0*t);
r_ph = utilities.fftSpectral(t, y_cos, OutputType="phase", Detrend="none", ...
    Window="none", ZeroPad=N_test);
[~, iP] = max(abs(r_ph.phase));  % find dominant peak by largest |phase| -- not ideal
% Instead, find the bin closest to f0
[~, iBin] = min(abs(r_ph.freq - f0));
phaseDeg = r_ph.phase(iBin);
if abs(phaseDeg) < 5
    fprintf('  PASS: cosine phase at %d Hz = %.1f deg (expected ~0)\n', f0, phaseDeg);
    passed = passed + 1;
else
    fprintf('  FAIL: cosine phase at %d Hz = %.1f deg (expected ~0)\n', f0, phaseDeg);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  7. WINDOW FUNCTIONS — basic shape checks
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Window function shapes ---\n');

winAllOk = true;
Nw = 64;
tw = (0:Nw-1)'/fs_test;
yw = ones(Nw, 1);

for w = 1:numel(windowNames)
    wName = windowNames{w};
    rw = utilities.fftSpectral(tw, yw, Window=wName, Detrend="none");
    win = rw.window;
    % Windows should have length Nw, values in [0, 1] (or close), peak near centre
    if numel(win) ~= Nw
        fprintf('  FAIL: %s window length %d (expected %d)\n', wName, numel(win), Nw);
        winAllOk = false;
        continue
    end
    % Flat-top windows can go slightly negative by design (~-0.07)
    minAllowed = -0.001;
    if strcmp(wName, 'flattop'), minAllowed = -0.08; end
    if min(win) < minAllowed
        fprintf('  FAIL: %s window has unexpected negative values (min=%.4f)\n', wName, min(win));
        winAllOk = false;
    end
    % Symmetry check (except for very short windows)
    if Nw > 8
        winFlip = flipud(win);
        symErr = max(abs(win - winFlip));
        if symErr > 1e-10
            fprintf('  FAIL: %s window not symmetric (max diff=%.2e)\n', wName, symErr);
            winAllOk = false;
        end
    end
end
if winAllOk
    fprintf('  PASS: all 6 windows have correct length, non-negative, symmetric\n');
    passed = passed + 1;
else
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  8. WELCH PSD — reduced variance
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Welch PSD ---\n');

rng(123);
y_welch = sin(2*pi*f0*t) + 0.5*randn(N_test, 1);

rw = utilities.fftSpectral(t, y_welch, SegmentLen=256, Overlap=0.5, ...
    Window="hanning", OutputType="psd");

% Welch PSD should still show the 50 Hz peak
[~, iWp] = max(rw.psd);
fWpeak = rw.freq(iWp);
if abs(fWpeak - f0) <= 2*rw.df
    fprintf('  PASS: Welch PSD peak at %.1f Hz (expected %d Hz)\n', fWpeak, f0);
    passed = passed + 1;
else
    fprintf('  FAIL: Welch PSD peak at %.1f Hz (expected %d Hz)\n', fWpeak, f0);
    failed = failed + 1;
end

% Welch integral should approximate signal variance
welchInt = sum(rw.psd) * rw.df;
sigVarW  = var(y_welch - mean(y_welch));
relErrW  = abs(welchInt - sigVarW) / sigVarW;
if relErrW < 0.25
    fprintf('  PASS: Welch Parseval — integral=%.3f, var=%.3f, err=%.1f%%\n', ...
        welchInt, sigVarW, relErrW*100);
    passed = passed + 1;
else
    fprintf('  FAIL: Welch Parseval — integral=%.3f, var=%.3f, err=%.1f%%\n', ...
        welchInt, sigVarW, relErrW*100);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  9. COMPLEX output
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Complex output ---\n');

rc = utilities.fftSpectral(t, y_sine, OutputType="complex", Detrend="none");
if isfield(rc, 'spectrum') && ~isreal(rc.spectrum)
    fprintf('  PASS: complex output has imaginary components\n');
    passed = passed + 1;
else
    fprintf('  FAIL: complex output missing or real-only\n');
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  10. CROSS-CORRELATION — peak lag matches known shift
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Cross-correlation: known shift ---\n');

rng(99);
Ncc = 512;
delay = 15;
xSig = randn(Ncc, 1);
% Shift y by 'delay' samples to the right
ySig = [zeros(delay, 1); xSig(1:end-delay)];

rc = utilities.crossCorrelation(xSig, ySig);
if rc.peakLag == delay
    fprintf('  PASS: peak lag = %d (expected %d)\n', rc.peakLag, delay);
    passed = passed + 1;
else
    fprintf('  FAIL: peak lag = %d (expected %d)\n', rc.peakLag, delay);
    failed = failed + 1;
end

% Normalised peak should be close to 1 for identical shapes
if rc.peakValue > 0.8
    fprintf('  PASS: normalised peak = %.3f (expected ~1)\n', rc.peakValue);
    passed = passed + 1;
else
    fprintf('  FAIL: normalised peak = %.3f (expected ~1)\n', rc.peakValue);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  11. CROSS-CORRELATION — auto-correlation peak at lag 0
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Cross-correlation: auto-correlation ---\n');

ra = utilities.crossCorrelation(xSig, xSig);
if ra.peakLag == 0 && abs(ra.peakValue - 1.0) < 1e-10
    fprintf('  PASS: auto-correlation peak at lag 0, value = %.6f\n', ra.peakValue);
    passed = passed + 1;
else
    fprintf('  FAIL: auto-correlation peak lag=%d, value=%.6f\n', ra.peakLag, ra.peakValue);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  12. CROSS-CORRELATION — unnormalised mode
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Cross-correlation: unnormalised ---\n');

ru = utilities.crossCorrelation(xSig, xSig, Normalize="none");
% Unnormalised auto-correlation at lag 0 = sum(x.^2)
expectedRxx0 = sum(xSig.^2);
if abs(ru.peakValue - expectedRxx0) < 1e-6
    fprintf('  PASS: unnorm Rxx(0) = %.3f (expected %.3f)\n', ru.peakValue, expectedRxx0);
    passed = passed + 1;
else
    fprintf('  FAIL: unnorm Rxx(0) = %.3f (expected %.3f)\n', ru.peakValue, expectedRxx0);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  13. CROSS-CORRELATION — lag vector properties
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Cross-correlation: lag vector ---\n');

expectedLags = 2*Ncc - 1;
if numel(rc.lags) == expectedLags && rc.lags(1) == -(Ncc-1) && rc.lags(end) == Ncc-1
    fprintf('  PASS: lags vector length=%d, range [%d, %d]\n', ...
        expectedLags, rc.lags(1), rc.lags(end));
    passed = passed + 1;
else
    fprintf('  FAIL: lags vector length=%d, range [%d, %d]\n', ...
        numel(rc.lags), rc.lags(1), rc.lags(end));
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  14. ERROR HANDLING
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Error handling ---\n');

errOk = true;

% Too short signal
try
    utilities.fftSpectral((1:2)', (1:2)');
    fprintf('  FAIL: no error for N=2\n'); errOk = false;
catch
    % expected
end

% Cross-correlation length mismatch
try
    utilities.crossCorrelation(ones(10,1), ones(5,1));
    fprintf('  FAIL: no error for length mismatch\n'); errOk = false;
catch
    % expected
end

if errOk
    fprintf('  PASS: correct errors raised for invalid inputs\n');
    passed = passed + 1;
else
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  15. KAISER WINDOW — Bessel I0 accuracy
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Kaiser window ---\n');

rk = utilities.fftSpectral(t, y_sine, Window="kaiser", KaiserBeta=8, ...
    OutputType="psd", Detrend="none");
[~, iKp] = max(rk.psd);
fKpeak = rk.freq(iKp);
if abs(fKpeak - f0) <= rk.df
    fprintf('  PASS: Kaiser PSD peak at %.1f Hz (beta=8)\n', fKpeak);
    passed = passed + 1;
else
    fprintf('  FAIL: Kaiser PSD peak at %.1f Hz (expected %d)\n', fKpeak, f0);
    failed = failed + 1;
end

% Kaiser window values should be positive and peak in the centre
kWin = rk.window;
midIdx = round(numel(kWin)/2);
if all(kWin > 0) && kWin(midIdx) > kWin(1)
    fprintf('  PASS: Kaiser window all positive, peaks at centre\n');
    passed = passed + 1;
else
    fprintf('  FAIL: Kaiser window shape incorrect\n');
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  16. FLAT-TOP WINDOW — amplitude accuracy
% ════════════════════════════════════════════════════════════════════

fprintf('\n--- Flat-top window amplitude accuracy ---\n');

% Flat-top windows are designed for accurate amplitude measurement
r_ft = utilities.fftSpectral(t, y_sine, Window="flattop", OutputType="magnitude", ...
    Detrend="none", ZeroPad=N_test);
[ftPeak, ~] = max(r_ft.magnitude);
% Flat-top should give very accurate amplitude even for non-bin-centered frequencies
% For bin-centered f0 with N=fs, rectangular is exact; flat-top is close
if abs(ftPeak - A) < 0.3
    fprintf('  PASS: flat-top magnitude = %.3f (expected %.1f)\n', ftPeak, A);
    passed = passed + 1;
else
    fprintf('  FAIL: flat-top magnitude = %.3f (expected %.1f)\n', ftPeak, A);
    failed = failed + 1;
end

% ════════════════════════════════════════════════════════════════════
%  SUMMARY
% ════════════════════════════════════════════════════════════════════

fprintf('\n=== test_fftSpectral: %d passed, %d failed ===\n', passed, failed);
if failed > 0
    error('test_fftSpectral:fail', '%d test(s) failed.', failed);
end
