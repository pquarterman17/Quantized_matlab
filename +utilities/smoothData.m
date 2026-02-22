function out = smoothData(y, options)
%SMOOTHDATA  Smooth a data vector or matrix (no Signal Processing Toolbox).
%
%   out = utilities.smoothData(y)
%   out = utilities.smoothData(y, 'Window', 9)
%   out = utilities.smoothData(y, 'Method', 'gaussian', 'Window', 11)
%
%   Smooths each COLUMN of y independently using a moving window.
%   Implemented with basic MATLAB operations — no toolboxes required.
%   Edge effects are handled by mirroring (reflecting) the data.
%
%   INPUTS:
%       y — [Nx1] or [NxM] numeric array (NaN values are propagated)
%
%   OPTIONAL NAME-VALUE PAIRS:
%       Method — 'moving'   (default) — uniform moving average
%                'gaussian'           — Gaussian-weighted moving average
%       Window — smoothing window half-width in samples (default: 5)
%                Total window = 2·Window + 1 points.
%
%   OUTPUT:
%       out — smoothed array, same size as y
%
%   EXAMPLES:
%       smoothI = utilities.smoothData(data.values);
%       smoothI = utilities.smoothData(data.values, 'Window', 15, 'Method', 'gaussian');
%
%   See also utilities.normalize, utilities.convertUnits

    arguments
        y                   (:,:) double
        options.Method (1,1) string {mustBeMember(options.Method, ...
                            {'moving','gaussian'})} = 'moving'
        options.Window (1,1) double {mustBePositive, mustBeInteger} = 5
    end

    hw   = options.Window;
    wLen = 2*hw + 1;

    % Build convolution kernel
    switch options.Method
        case 'moving'
            kernel = ones(wLen, 1) / wLen;
        case 'gaussian'
            sigma  = hw / 2;
            t      = (-hw:hw)';
            kernel = exp(-t.^2 / (2*sigma^2));
            kernel = kernel / sum(kernel);
    end

    out = NaN(size(y));
    for c = 1:size(y, 2)
        col = y(:, c);
        n   = numel(col);

        % Mirror-pad to reduce edge effects
        padded = [col(hw+1:-1:2); col; col(end-1:-1:end-hw)];

        % Convolve
        smoothed = conv(padded, kernel, 'valid');

        % valid gives length n — trim if rounding gives n+1
        out(:, c) = smoothed(1:n);
    end
end
