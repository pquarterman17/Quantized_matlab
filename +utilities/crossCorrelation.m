function result = crossCorrelation(x, y, Options)
%CROSSCORRELATION  Normalized cross-correlation between two signals via FFT.
%
%   result = utilities.crossCorrelation(x, y)
%   result = utilities.crossCorrelation(x, y, Normalize="none")
%
%   Computes the cross-correlation of two equal-length real signals using
%   the FFT (via the correlation theorem: Rxy = IFFT(conj(X) .* Y)).
%   The result is returned with lag indices and the peak lag identified.
%
%   Inputs:
%       x — [N×1] first signal
%       y — [N×1] second signal (same length as x)
%
%   Options (name-value):
%       Normalize — "coeff" (default) normalises to [-1, 1] by dividing
%                   by sqrt(Rxx(0) * Ryy(0));  "none" returns raw
%                   cross-correlation values.
%
%   Output (struct):
%       .lags      — [2N-1 × 1] lag indices  (-(N-1) : N-1)
%       .xcorr     — [2N-1 × 1] cross-correlation values
%       .peakLag   — lag at which |xcorr| is maximum
%       .peakValue — value of xcorr at peakLag
%
%   The lag convention is: positive peakLag means y is delayed relative
%   to x (i.e., y looks like x shifted right by peakLag samples).
%
%   Examples:
%       % Cross-correlate a signal with a delayed copy
%       N = 256;  delay = 10;
%       x = randn(N,1);
%       y = [zeros(delay,1); x(1:end-delay)];
%       r = utilities.crossCorrelation(x, y);
%       fprintf('Peak lag = %d (expected %d)\n', r.peakLag, delay);
%
%       % Raw (unnormalised) cross-correlation
%       r = utilities.crossCorrelation(x, y, Normalize="none");
%
%   See also utilities.fftSpectral, utilities.fftFilter

arguments
    x       (:,1) double
    y       (:,1) double
    Options.Normalize (1,1) string {mustBeMember(Options.Normalize, ...
        ["coeff","none"])} = "coeff"
end

Nx = numel(x);
Ny = numel(y);
if Nx ~= Ny
    error('utilities:crossCorrelation:lengthMismatch', ...
        'Signals must have equal length (got %d and %d).', Nx, Ny);
end
N = Nx;
if N < 2
    error('utilities:crossCorrelation:tooShort', ...
        'Need at least 2 data points.');
end

% ════════════════════════════════════════════════════════════════════════
% FFT-based cross-correlation
% ════════════════════════════════════════════════════════════════════════

% Zero-pad to length 2N-1 (next power of 2 for efficiency) to avoid
% circular correlation artifacts.
nfft = 2^nextpow2(2*N - 1);

X = fft(x, nfft);
Y = fft(y, nfft);

% Correlation theorem: Rxy(tau) = IFFT( conj(X) .* Y )
Rxy = real(ifft(conj(X) .* Y));

% Re-arrange: IFFT gives lags [0, 1, ..., nfft-1].
% We need lags [-(N-1), ..., -1, 0, 1, ..., N-1].
% Negative lags correspond to indices nfft-N+1 : nfft.
xcorrFull = [Rxy(nfft-N+2:nfft); Rxy(1:N)];
lags = (-(N-1):(N-1))';

% ════════════════════════════════════════════════════════════════════════
% Normalisation
% ════════════════════════════════════════════════════════════════════════

if strcmp(Options.Normalize, "coeff")
    % Normalise by sqrt( autocorrelation at zero lag for each signal )
    Rxx0 = sum(x.^2);
    Ryy0 = sum(y.^2);
    denom = sqrt(Rxx0 * Ryy0);
    if denom > 0
        xcorrFull = xcorrFull / denom;
    end
end

% ════════════════════════════════════════════════════════════════════════
% Identify peak
% ════════════════════════════════════════════════════════════════════════

[~, iPeak] = max(abs(xcorrFull));
peakLag   = lags(iPeak);
peakValue = xcorrFull(iPeak);

% ════════════════════════════════════════════════════════════════════════
% Output
% ════════════════════════════════════════════════════════════════════════

result.lags      = lags;
result.xcorr     = xcorrFull;
result.peakLag   = peakLag;
result.peakValue = peakValue;

end
