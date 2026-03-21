function out = smoothData(y, options)
%SMOOTHDATA  Smooth a data vector or matrix (no Signal Processing Toolbox).
%
%   out = utilities.smoothData(y)
%   out = utilities.smoothData(y, 'Window', 9)
%   out = utilities.smoothData(y, 'Method', 'gaussian', 'Window', 11)
%   out = utilities.smoothData(y, 'Method', 'savitzky-golay', 'PolyOrder', 3)
%
%   Smooths each COLUMN of y independently using a moving window.
%   Implemented with basic MATLAB operations — no toolboxes required.
%   Edge effects are handled by mirroring (reflecting) the data.
%
%   INPUTS:
%       y — [Nx1] or [NxM] numeric array (NaN values are propagated)
%
%   OPTIONAL NAME-VALUE PAIRS:
%       Method — 'moving'         (default) — uniform moving average
%                'gaussian'                 — Gaussian-weighted moving average
%                'savitzky-golay'           — Savitzky-Golay polynomial filter
%       Window — smoothing window half-width in samples (default: 5)
%                Total window = 2·Window + 1 points.
%       PolyOrder — polynomial order for Savitzky-Golay (default: 2)
%                   Must be less than total window width (2·Window + 1).
%                   Higher orders preserve sharper features but smooth less.
%                   Typical values: 2 (quadratic) for general use,
%                                   3-4 for preserving narrow peaks.
%
%   OUTPUT:
%       out — smoothed array, same size as y
%
%   EXAMPLES:
%       smoothI = utilities.smoothData(data.values);
%       smoothI = utilities.smoothData(data.values, 'Window', 15, 'Method', 'gaussian');
%
%       % Savitzky-Golay: preserves peak shapes better than moving average
%       sgSmooth = utilities.smoothData(data.values, 'Method', 'savitzky-golay');
%       sgSmooth = utilities.smoothData(data.values, 'Method', 'savitzky-golay', ...
%                                       'Window', 7, 'PolyOrder', 3);
%
%   WHEN TO USE WHICH METHOD:
%       Moving average  — fast, simple; broadens peaks; good for noisy baselines
%       Gaussian        — similar to moving avg but smoother roll-off
%       Savitzky-Golay  — preserves peak positions, heights, and widths;
%                         best for XRD, spectroscopy, or any data where
%                         peak shape integrity matters
%
%   See also utilities.normalize, utilities.convertUnits

    arguments
        y                   (:,:) double
        options.Method (1,1) string {mustBeMember(options.Method, ...
                            {'moving','gaussian','savitzky-golay'})} = 'moving'
        options.Window (1,1) double {mustBePositive, mustBeInteger} = 5
        options.PolyOrder (1,1) double {mustBeNonnegative, mustBeInteger} = 2
    end

    hw = options.Window;

    % Validate PolyOrder for Savitzky-Golay
    if strcmp(options.Method, 'savitzky-golay')
        wLen = 2 * hw + 1;
        if options.PolyOrder >= wLen
            error('utilities:smoothData:polyOrder', ...
                'PolyOrder (%d) must be less than window width (%d = 2*%d+1).', ...
                options.PolyOrder, wLen, hw);
        end
    end

    out = NaN(size(y));
    for c = 1:size(y, 2)
        col = y(:, c);
        n   = numel(col);

        % Clamp half-width so mirror-pad indices stay valid
        hwc = min(hw, n - 1);
        if hwc < 1
            out(:, c) = col;
            continue;
        end

        if strcmp(options.Method, 'savitzky-golay')
            % Savitzky-Golay: use local polynomial fitting with proper edge
            % handling. Interior points use the standard symmetric kernel.
            % Edge points use asymmetric windows that still preserve polynomials.
            polyOrd = min(options.PolyOrder, 2*hwc);

            % Precompute interior kernel (symmetric window)
            wLen = 2*hwc + 1;
            t = (-hwc:hwc)';
            V = zeros(wLen, polyOrd + 1);
            for p = 0:polyOrd
                V(:, p+1) = t .^ p;
            end
            C = (V' * V) \ V';
            intKernel = C(1, :);

            % Apply interior kernel via convolution (fast path)
            if n > 2*hwc
                smoothed = conv(col, intKernel(end:-1:1), 'same');
                out(:, c) = smoothed;
            else
                out(:, c) = col;
            end

            % Fix edge points with asymmetric SG coefficients
            for i = 1:hwc
                % Left edge: fit polynomial to first (hwc+i) points,
                % evaluate at position i (1-indexed)
                nPts = min(wLen, n);
                localY = col(1:nPts);
                t_local = (0:nPts-1)';
                evalPt = i - 1;  % 0-indexed position within the window
                Vl = zeros(nPts, polyOrd + 1);
                for p = 0:polyOrd
                    Vl(:, p+1) = t_local .^ p;
                end
                coeffs = Vl \ localY;
                val = 0;
                for p = 0:polyOrd
                    val = val + coeffs(p+1) * evalPt^p;
                end
                out(i, c) = val;

                % Right edge: mirror logic
                localY = col(n-nPts+1:n);
                t_local = (0:nPts-1)';
                evalPt = nPts - 1 - (i - 1);  % position from start of local window
                Vr = zeros(nPts, polyOrd + 1);
                for p = 0:polyOrd
                    Vr(:, p+1) = t_local .^ p;
                end
                coeffs = Vr \ localY;
                val = 0;
                for p = 0:polyOrd
                    val = val + coeffs(p+1) * evalPt^p;
                end
                out(n - i + 1, c) = val;
            end
        else
            % Moving average or Gaussian
            wLen = 2*hwc + 1;
            switch options.Method
                case 'moving'
                    kernel = ones(wLen, 1) / wLen;
                case 'gaussian'
                    sigma  = hwc / 2;
                    t      = (-hwc:hwc)';
                    kernel = exp(-t.^2 / (2*sigma^2));
                    kernel = kernel / sum(kernel);
            end

            % Mirror-pad to reduce edge effects
            padded = [col(hwc+1:-1:2); col; col(end-1:-1:end-hwc)];

            % Convolve
            smoothed = conv(padded, kernel, 'valid');

            % valid gives length n — trim if rounding gives n+1
            out(:, c) = smoothed(1:n);
        end
    end
end
