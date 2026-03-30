function result = fftSpectral(xData, yData, Options)
%FFTSPECTRAL  Comprehensive spectral analysis with windowing and Welch PSD.
%
%   result = utilities.fftSpectral(x, y)
%   result = utilities.fftSpectral(x, y, Window="blackman", OutputType="psd")
%   result = utilities.fftSpectral(x, y, OutputType="magnitude", Sided="two")
%   result = utilities.fftSpectral(x, y, SegmentLen=256, Overlap=0.5)
%
%   Computes the discrete Fourier transform of uniformly sampled data with
%   configurable windowing, detrending, zero-padding, and Welch averaging.
%   No Signal Processing Toolbox required — all window functions are
%   implemented from their mathematical definitions.
%
%   Inputs:
%       xData — [N×1] independent variable (assumed uniformly spaced)
%       yData — [N×1] dependent variable (real-valued)
%
%   Options (name-value):
%       Window      — Tapering window to reduce spectral leakage:
%                    "none" | "hanning" | "hamming" | "blackman" |
%                    "flattop" | "kaiser"
%                    (default: "hanning")
%       KaiserBeta  — Shape parameter for Kaiser window.  Higher values
%                    give narrower main lobe and lower sidelobes.
%                    (default: 5)
%       OutputType  — "psd" | "magnitude" | "phase" | "complex"
%                    (default: "psd")
%       Sided       — "one" (single-sided, positive frequencies only) or
%                    "two" (double-sided, full spectrum)
%                    (default: "one")
%       Detrend     — Pre-processing before windowing:
%                    "none" | "mean" | "linear"
%                    (default: "mean")
%       ZeroPad     — Zero-pad the signal to this length.  Must be >= N.
%                    (default: next power of 2 >= N)
%       Overlap     — Fractional overlap 0–1 for Welch PSD segments
%                    (default: 0.5)
%       SegmentLen  — Segment length for Welch averaging.  When set, the
%                    signal is split into overlapping segments, each
%                    windowed and FFT'd, and the PSDs averaged.  This
%                    reduces variance at the cost of frequency resolution.
%                    (default: [], meaning no segmentation — use full signal)
%
%   Output (struct):
%       .freq       — frequency axis [Hz or 1/(x-unit)]
%       .psd        — power spectral density (when OutputType="psd")
%       .magnitude  — |FFT| scaled by 1/N (when OutputType="magnitude")
%       .phase      — phase angle in degrees (when OutputType="phase")
%       .spectrum   — complex FFT coefficients (when OutputType="complex")
%       .window     — the window vector applied to each segment
%       .df         — frequency resolution (Hz)
%       .nfft       — FFT length used (after zero-padding)
%       .fs         — sampling frequency
%       .windowName — name of the window function
%
%   Window Functions (implemented from definitions):
%       hanning  :  w(n) = 0.5 [1 - cos(2*pi*n/(N-1))]
%       hamming  :  w(n) = 0.54 - 0.46 cos(2*pi*n/(N-1))
%       blackman :  w(n) = 0.42 - 0.5 cos(2*pi*n/(N-1)) + 0.08 cos(4*pi*n/(N-1))
%       flattop  :  5-term cosine series (a0..a4)
%       kaiser   :  w(n) = I0(beta*sqrt(1-(2n/(N-1)-1)^2)) / I0(beta)
%
%   Examples:
%       % PSD of a noisy 50-Hz sine wave sampled at 1 kHz
%       t = (0:999)'/1000;  y = sin(2*pi*50*t) + 0.5*randn(1000,1);
%       r = utilities.fftSpectral(t, y, Window="hanning");
%       semilogy(r.freq, r.psd);
%
%       % Magnitude spectrum with Blackman window
%       r = utilities.fftSpectral(t, y, Window="blackman", OutputType="magnitude");
%       plot(r.freq, r.magnitude);
%
%       % Welch PSD with 256-point segments
%       r = utilities.fftSpectral(t, y, SegmentLen=256, Overlap=0.5);
%       semilogy(r.freq, r.psd);
%
%   See also utilities.fftFilter, utilities.crossCorrelation

arguments
    xData    (:,1) double
    yData    (:,1) double
    Options.Window      (1,1) string {mustBeMember(Options.Window, ...
        ["none","hanning","hamming","blackman","flattop","kaiser"])} = "hanning"
    Options.KaiserBeta  (1,1) double {mustBeNonnegative} = 5
    Options.OutputType  (1,1) string {mustBeMember(Options.OutputType, ...
        ["psd","magnitude","phase","complex"])} = "psd"
    Options.Sided       (1,1) string {mustBeMember(Options.Sided, ...
        ["one","two"])} = "one"
    Options.Detrend     (1,1) string {mustBeMember(Options.Detrend, ...
        ["none","mean","linear"])} = "mean"
    Options.ZeroPad     (1,1) double {mustBeNonnegative, mustBeInteger} = 0
    Options.Overlap     (1,1) double {mustBeInRange(Options.Overlap,0,1)} = 0.5
    Options.SegmentLen  (1,1) double {mustBeNonnegative, mustBeInteger} = 0
end

N = numel(xData);
if N < 4
    error('utilities:fftSpectral:tooShort', 'Need at least 4 data points.');
end

% ════════════════════════════════════════════════════════════════════════
% Sampling parameters
% ════════════════════════════════════════════════════════════════════════

dx = mean(diff(xData));
fs = 1 / abs(dx);

% ════════════════════════════════════════════════════════════════════════
% Welch segmented PSD vs single-segment
% ════════════════════════════════════════════════════════════════════════

if Options.SegmentLen > 0
    result = welchPSD(yData, fs, Options);
    return
end

% ════════════════════════════════════════════════════════════════════════
% Detrend
% ════════════════════════════════════════════════════════════════════════

y = yData;
switch char(Options.Detrend)
    case 'mean'
        y = y - mean(y);
    case 'linear'
        p = polyfit(xData, y, 1);
        y = y - polyval(p, xData);
end

% ════════════════════════════════════════════════════════════════════════
% Window
% ════════════════════════════════════════════════════════════════════════

win = makeWindow(char(Options.Window), N, Options.KaiserBeta);

yWin = y .* win;

% ════════════════════════════════════════════════════════════════════════
% Zero-pad and FFT
% ════════════════════════════════════════════════════════════════════════

if Options.ZeroPad > 0
    nfft = max(Options.ZeroPad, N);
else
    nfft = 2^nextpow2(N);
end

Y = fft(yWin, nfft);

df = fs / nfft;

% ════════════════════════════════════════════════════════════════════════
% Build frequency axis and compute output
% ════════════════════════════════════════════════════════════════════════

% Window energy correction factors
S1 = sum(win);       % coherent gain
S2 = sum(win.^2);    % incoherent (power) gain

if strcmp(Options.Sided, "one")
    % Single-sided: 0 to fs/2
    nHalf = floor(nfft/2) + 1;
    freq = (0:nHalf-1)' * df;
    Yh = Y(1:nHalf);

    switch char(Options.OutputType)
        case 'psd'
            % PSD = |Y|^2 / (fs * S2), doubled for one-sided (except DC, Nyquist)
            psdVal = (abs(Yh).^2) / (fs * S2);
            psdVal(2:end-1) = 2 * psdVal(2:end-1);
            result.psd = psdVal;

        case 'magnitude'
            mag = abs(Yh) / S1;
            mag(2:end-1) = 2 * mag(2:end-1);
            result.magnitude = mag;

        case 'phase'
            result.phase = rad2deg(angle(Yh));

        case 'complex'
            result.spectrum = Yh;
    end
    result.freq = freq;

else
    % Two-sided: use fftshift convention
    freq = (-floor(nfft/2):ceil(nfft/2)-1)' * df;
    Yshift = fftshift(Y);

    switch char(Options.OutputType)
        case 'psd'
            result.psd = (abs(Yshift).^2) / (fs * S2);

        case 'magnitude'
            result.magnitude = abs(Yshift) / S1;

        case 'phase'
            result.phase = rad2deg(angle(Yshift));

        case 'complex'
            result.spectrum = Yshift;
    end
    result.freq = freq;
end

% ════════════════════════════════════════════════════════════════════════
% Metadata
% ════════════════════════════════════════════════════════════════════════

result.window     = win;
result.df         = df;
result.nfft       = nfft;
result.fs         = fs;
result.windowName = char(Options.Window);

end % fftSpectral


% ========================================================================
%  LOCAL FUNCTIONS
% ========================================================================

function win = makeWindow(name, N, kaiserBeta)
%MAKEWINDOW  Generate a window function of length N using only built-ins.
    n = (0:N-1)';
    switch name
        case 'none'
            win = ones(N, 1);
        case 'hanning'
            win = 0.5 * (1 - cos(2*pi*n/(N-1)));
        case 'hamming'
            win = 0.54 - 0.46 * cos(2*pi*n/(N-1));
        case 'blackman'
            win = 0.42 - 0.5*cos(2*pi*n/(N-1)) + 0.08*cos(4*pi*n/(N-1));
        case 'flattop'
            % 5-term flat-top window (D'Antona & Ferrero coefficients)
            a0 = 0.21557895;
            a1 = 0.41663158;
            a2 = 0.277263158;
            a3 = 0.083578947;
            a4 = 0.006947368;
            win = a0 - a1*cos(2*pi*n/(N-1)) + a2*cos(4*pi*n/(N-1)) ...
                     - a3*cos(6*pi*n/(N-1)) + a4*cos(8*pi*n/(N-1));
        case 'kaiser'
            win = kaiserWindow(N, kaiserBeta);
    end
end


function win = kaiserWindow(N, beta)
%KAISERWINDOW  Kaiser window using polynomial approximation of I0(x).
%   I0(x) is the zeroth-order modified Bessel function of the first kind.
%   Uses the series expansion: I0(x) = sum_{k=0}^{inf} [(x/2)^k / k!]^2
%   which converges rapidly for typical beta values (< 40).
    n = (0:N-1)';
    alpha = (N-1) / 2;
    arg = beta * sqrt(1 - ((n - alpha) / alpha).^2);
    win = besselI0(arg) / besselI0(beta);
end


function y = besselI0(x)
%BESSELI0  Modified Bessel function I0(x) via series expansion.
%   I0(x) = sum_{k=0}^{K} [(x/2)^k / k!]^2
%   25 terms gives machine precision for x < 40.
    y = ones(size(x));
    term = ones(size(x));
    for k = 1:25
        term = term .* (x / (2*k)).^2;
        y = y + term;
    end
end


function result = welchPSD(yData, fs, Options)
%WELCHPSD  Welch's method: segment, window, FFT, average periodograms.
    N = numel(yData);
    segLen = Options.SegmentLen;
    if segLen > N
        segLen = N;
    end
    if segLen < 4
        error('utilities:fftSpectral:segTooShort', ...
            'SegmentLen must be >= 4.');
    end

    overlap = round(segLen * Options.Overlap);
    step = segLen - overlap;

    % Determine zero-pad length for each segment
    if Options.ZeroPad > 0
        nfft = max(Options.ZeroPad, segLen);
    else
        nfft = 2^nextpow2(segLen);
    end

    df = fs / nfft;

    % Build window for each segment
    win = makeWindow(char(Options.Window), segLen, Options.KaiserBeta);
    S2 = sum(win.^2);

    % Determine number of segments
    nSegs = 0;
    idx = 1;
    while idx + segLen - 1 <= N
        nSegs = nSegs + 1;
        idx = idx + step;
    end
    if nSegs < 1
        nSegs = 1;
    end

    % Accumulate periodograms
    if strcmp(Options.Sided, "one")
        nHalf = floor(nfft/2) + 1;
        psdAccum = zeros(nHalf, 1);
    else
        psdAccum = zeros(nfft, 1);
    end

    idx = 1;
    nActual = 0;
    for s = 1:nSegs
        iEnd = idx + segLen - 1;
        if iEnd > N, break; end

        seg = yData(idx:iEnd);

        % Detrend each segment
        switch char(Options.Detrend)
            case 'mean'
                seg = seg - mean(seg);
            case 'linear'
                xSeg = (0:segLen-1)';
                p = polyfit(xSeg, seg, 1);
                seg = seg - polyval(p, xSeg);
        end

        segWin = seg .* win;
        Y = fft(segWin, nfft);

        if strcmp(Options.Sided, "one")
            Yh = Y(1:nHalf);
            pSeg = (abs(Yh).^2) / (fs * S2);
            pSeg(2:end-1) = 2 * pSeg(2:end-1);
            psdAccum = psdAccum + pSeg;
        else
            psdAccum = psdAccum + (abs(Y).^2) / (fs * S2);
        end

        nActual = nActual + 1;
        idx = idx + step;
    end

    psdAccum = psdAccum / max(nActual, 1);

    % Build frequency axis
    if strcmp(Options.Sided, "one")
        nHalf = floor(nfft/2) + 1;
        freq = (0:nHalf-1)' * df;
    else
        freq = (-floor(nfft/2):ceil(nfft/2)-1)' * df;
        psdAccum = fftshift(psdAccum);
    end

    result.freq       = freq;
    result.psd        = psdAccum;
    result.window     = win;
    result.df         = df;
    result.nfft       = nfft;
    result.fs         = fs;
    result.windowName = char(Options.Window);
end
