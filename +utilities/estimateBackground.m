function bg = estimateBackground(x, y, options)
%ESTIMATEBACKGROUND  Estimate baseline via SNIP peak-clipping algorithm.
%
%   bg = utilities.estimateBackground(x, y)
%   bg = utilities.estimateBackground(x, y, 'MaxWindowDeg', 2.0)
%   bg = utilities.estimateBackground(x, y, 'MaxWindowDeg', 1.5, 'SmoothPasses', 5)
%
%   Implements the SNIP (Statistics-sensitive Non-linear Iterative
%   Peak-clipping) algorithm, standard in X-ray spectroscopy for
%   separating diffraction peaks from a slowly varying background.
%
%   The algorithm works by iteratively replacing each point with the
%   minimum of itself and the average of its neighbours at increasing
%   distances.  In the square-root domain this clips peaks while
%   preserving the smooth background shape.
%
%   Inputs:
%       x — [N×1] numeric vector of x-axis values (e.g., 2-theta degrees)
%       y — [N×1] numeric vector of intensity values
%
%   Name-Value Options:
%       MaxWindowDeg  — maximum clipping window in x-axis units (default 2.0).
%                       Should be wider than the widest expected peak.
%                       For XRD data, 1–3 degrees typically covers Bragg peaks.
%       SmoothPasses  — number of light smoothing passes on the final
%                       background to reduce staircase artifacts (default 3).
%                       Set to 0 to skip smoothing.
%
%   Output:
%       bg — [N×1] estimated background vector, same size as y
%
%   Examples:
%       % Basic usage with default 2-degree window
%       data = parser.importRigaku_raw('scan.raw');
%       bg = utilities.estimateBackground(data.time, data.values(:,1));
%       plot(data.time, data.values(:,1)); hold on; plot(data.time, bg, '--');
%
%       % Narrower window for data with sharp features
%       bg = utilities.estimateBackground(x, y, 'MaxWindowDeg', 1.0);

% ════════════════════════════════════════════════════════════════════════
%  Input validation
% ════════════════════════════════════════════════════════════════════════
    arguments
        x    (:,1) double
        y    (:,1) double
        options.MaxWindowDeg  (1,1) double {mustBePositive} = 2.0
        options.SmoothPasses  (1,1) double {mustBeNonnegative, mustBeInteger} = 3
    end

    n = numel(y);
    if n < 3
        bg = y;
        return;
    end

% ════════════════════════════════════════════════════════════════════════
%  Convert window from x-units to data points
% ════════════════════════════════════════════════════════════════════════
    dx = median(diff(x));
    if dx <= 0
        bg = y;
        return;
    end
    wMax = round(options.MaxWindowDeg / dx);
    wMax = max(1, min(wMax, floor((n - 1) / 2)));

% ════════════════════════════════════════════════════════════════════════
%  SNIP algorithm in square-root domain
% ════════════════════════════════════════════════════════════════════════
    %  The sqrt transform stabilises Poisson-distributed counting noise,
    %  making the clipping threshold uniform across the dynamic range.
    v = sqrt(max(y(:), 0));

    for w = wMax:-1:1
        vNew = v;
        for i = (w + 1):(n - w)
            avg = (v(i - w) + v(i + w)) / 2;
            if avg < vNew(i)
                vNew(i) = avg;
            end
        end
        v = vNew;
    end

    bg = v .^ 2;

% ════════════════════════════════════════════════════════════════════════
%  Light smoothing to reduce staircase artifacts
% ════════════════════════════════════════════════════════════════════════
    smoothWin = 5;
    for pass = 1:options.SmoothPasses
        bgPad = [bg(3:-1:2); bg; bg(end-1:-1:end-2)];  % mirror-pad edges
        kernel = ones(smoothWin, 1) / smoothWin;
        bgSmooth = conv(bgPad, kernel, 'valid');
        % conv 'valid' trims (smoothWin-1) samples; our padding matches
        bg = bgSmooth(1:n);
    end

    % Ensure background never exceeds original data
    bg = min(bg, y(:));
end
