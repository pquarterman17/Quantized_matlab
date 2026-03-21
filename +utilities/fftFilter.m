function result = fftFilter(xData, yData, options)
%FFTFILTER  Apply frequency-domain filters to 1D data.
%
%   result = utilities.fftFilter(x, y, Type='lowpass', Cutoff=100)
%   result = utilities.fftFilter(x, y, Type='bandpass', Cutoff=[10 200])
%   result = utilities.fftFilter(x, y, Type='notch', Cutoff=60, Bandwidth=5)
%
%   Filters 1D data in the frequency domain using a Butterworth transfer
%   function.  No Signal Processing Toolbox required.
%
%   Inputs:
%       xData — [N×1] independent variable (assumed uniformly spaced)
%       yData — [N×1] dependent variable
%
%   Options (name-value):
%       Type       — 'lowpass' | 'highpass' | 'bandpass' | 'notch'
%                    (default: 'lowpass')
%       Cutoff     — Cutoff frequency in units of 1/(x-unit):
%                      scalar for lowpass/highpass
%                      [low high] for bandpass
%                      centre frequency for notch
%                    (default: Nyquist/4)
%       Bandwidth  — Width of the notch band, same units as Cutoff
%                    (only used for Type='notch', default: Cutoff/10)
%       Order      — Butterworth filter order; higher = sharper rolloff
%                    (default: 4)
%       Window     — Tapering window before FFT to reduce spectral leakage:
%                    'none' | 'hamming' | 'hanning' | 'blackman'
%                    (default: 'none')
%       Detrend    — Remove linear trend before filtering (default: true)
%
%   Output (struct):
%       .yFiltered  — [N×1] filtered data (time domain)
%       .freq       — [N×1] frequency axis (positive and negative)
%       .power      — [N×1] power spectral density of original data
%       .powerFilt  — [N×1] power spectral density of filtered data
%       .transfer   — [N×1] filter transfer function |H(f)|
%       .freqPos    — [N/2×1] positive frequencies only (for plotting)
%       .powerPos   — [N/2×1] one-sided PSD (for plotting)
%
%   Examples:
%       % Remove high-frequency noise above 100 Hz
%       r = utilities.fftFilter(t, signal, Type='lowpass', Cutoff=100);
%       plot(t, r.yFiltered);
%
%       % Remove 60 Hz line noise
%       r = utilities.fftFilter(t, signal, Type='notch', Cutoff=60, Bandwidth=2);
%
%       % Bandpass: keep only 10-200 Hz
%       r = utilities.fftFilter(t, signal, Type='bandpass', Cutoff=[10 200]);
%
%       % View power spectrum
%       semilogy(r.freqPos, r.powerPos);
%
%   See also imaging.butterworthFilter, utilities.smoothData

arguments
    xData    (:,1) double
    yData    (:,1) double
    options.Type      (1,1) string {mustBeMember(options.Type, ...
        ["lowpass","highpass","bandpass","notch"])} = "lowpass"
    options.Cutoff    double = []
    options.Bandwidth double = []
    options.Order     (1,1) double {mustBePositive, mustBeInteger} = 4
    options.Window    (1,1) string {mustBeMember(options.Window, ...
        ["none","hamming","hanning","blackman"])} = "none"
    options.Detrend   (1,1) logical = true
end

N = numel(xData);
if N < 4
    error('utilities:fftFilter:tooShort', 'Need at least 4 data points.');
end

% ════════════════════════════════════════════════════════════════════════
% Sampling parameters
% ════════════════════════════════════════════════════════════════════════

dx = mean(diff(xData));     % assume approximately uniform spacing
fs = 1 / abs(dx);           % sampling frequency
fNyq = fs / 2;              % Nyquist frequency

% Default cutoff
if isempty(options.Cutoff)
    options.Cutoff = fNyq / 4;
end

% Validate cutoff
filterType = char(options.Type);
switch filterType
    case 'bandpass'
        if numel(options.Cutoff) ~= 2
            error('utilities:fftFilter:cutoff', ...
                'Bandpass requires Cutoff = [low high].');
        end
        fLow  = options.Cutoff(1);
        fHigh = options.Cutoff(2);
    case 'notch'
        fCenter = options.Cutoff(1);
        if isempty(options.Bandwidth)
            bw = fCenter / 10;
        else
            bw = options.Bandwidth;
        end
        fLow  = fCenter - bw/2;
        fHigh = fCenter + bw/2;
    case 'lowpass'
        fHigh = options.Cutoff(1);
        fLow  = 0;
    case 'highpass'
        fLow  = options.Cutoff(1);
        fHigh = fNyq;
end

ord = options.Order;

% ════════════════════════════════════════════════════════════════════════
% Preprocessing
% ════════════════════════════════════════════════════════════════════════

y = yData;

% Remove linear trend (restored after filtering)
if options.Detrend
    p = polyfit(xData, y, 1);
    trend = polyval(p, xData);
    y = y - trend;
else
    trend = zeros(N, 1);
end

% Apply window function
win = ones(N, 1);
switch char(options.Window)
    case 'hamming'
        win = 0.54 - 0.46 * cos(2*pi*(0:N-1)'/(N-1));
    case 'hanning'
        win = 0.5 * (1 - cos(2*pi*(0:N-1)'/(N-1)));
    case 'blackman'
        win = 0.42 - 0.5*cos(2*pi*(0:N-1)'/(N-1)) + ...
              0.08*cos(4*pi*(0:N-1)'/(N-1));
end
yWin = y .* win;

% ════════════════════════════════════════════════════════════════════════
% FFT and frequency axis
% ════════════════════════════════════════════════════════════════════════

Y = fft(yWin);
freq = (0:N-1)' * fs / N;
% Shift frequencies > Nyquist to negative
freq(freq > fNyq) = freq(freq > fNyq) - fs;

absFreq = abs(freq);

% ════════════════════════════════════════════════════════════════════════
% Build Butterworth transfer function
% ════════════════════════════════════════════════════════════════════════

H = ones(N, 1);

switch filterType
    case 'lowpass'
        % H = 1 / (1 + (f/fc)^(2n))
        H = 1 ./ (1 + (absFreq / max(fHigh, eps)).^(2*ord));

    case 'highpass'
        % H = 1 / (1 + (fc/f)^(2n)), handle f=0
        H = 1 ./ (1 + (max(fLow, eps) ./ max(absFreq, eps)).^(2*ord));
        H(absFreq == 0) = 0;  % DC blocked

    case 'bandpass'
        % Product of high-pass and low-pass
        Hlp = 1 ./ (1 + (absFreq / max(fHigh, eps)).^(2*ord));
        Hhp = 1 ./ (1 + (max(fLow, eps) ./ max(absFreq, eps)).^(2*ord));
        Hhp(absFreq == 0) = 0;
        H = Hlp .* Hhp;

    case 'notch'
        % Band-reject: 1 - bandpass
        Hlp = 1 ./ (1 + (absFreq / max(fHigh, eps)).^(2*ord));
        Hhp = 1 ./ (1 + (max(fLow, eps) ./ max(absFreq, eps)).^(2*ord));
        Hhp(absFreq == 0) = 0;
        Hbp = Hlp .* Hhp;
        H = 1 - Hbp;
end

% ════════════════════════════════════════════════════════════════════════
% Apply filter and inverse FFT
% ════════════════════════════════════════════════════════════════════════

Yfilt = Y .* H;
yFilt = real(ifft(Yfilt));

% Undo window (approximate: divide by window, avoiding division by ~0)
if ~strcmp(options.Window, 'none')
    safeWin = max(win, 0.01);
    yFilt = yFilt ./ safeWin;
end

% Restore trend
yFilt = yFilt + trend;

% ════════════════════════════════════════════════════════════════════════
% Power spectra (for diagnostics / plotting)
% ════════════════════════════════════════════════════════════════════════

powerOrig = abs(Y).^2 / N;
powerFilt = abs(Yfilt).^2 / N;

% One-sided spectrum (positive frequencies only)
nHalf = floor(N/2) + 1;
freqPos  = (0:nHalf-1)' * fs / N;
powerPos = 2 * powerOrig(1:nHalf) / N;
powerPos(1) = powerPos(1) / 2;  % DC not doubled

% ════════════════════════════════════════════════════════════════════════
% Output
% ════════════════════════════════════════════════════════════════════════

result.yFiltered = yFilt;
result.freq      = freq;
result.power     = powerOrig;
result.powerFilt = powerFilt;
result.transfer  = H;
result.freqPos   = freqPos;
result.powerPos  = powerPos;

end
