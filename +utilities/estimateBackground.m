function bg = estimateBackground(x, y, options)
%ESTIMATEBACKGROUND  Estimate baseline via SNIP peak-clipping algorithm.
%
%   bg = utilities.estimateBackground(x, y)
%   bg = utilities.estimateBackground(x, y, 'MaxWindowDeg', 2.0)
%   bg = utilities.estimateBackground(x, y, 'Method', 'snip')
%   bg = utilities.estimateBackground(x, y, 'Method', 'polynomial', 'PolyDegree', 3)
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
%   Optionally supports iterative refinement: after initial background
%   estimation, points significantly above the background are masked as
%   peak regions and the background is re-estimated from non-peak data.
%
%   Inputs:
%       x — [N×1] numeric vector of x-axis values (e.g., 2-theta degrees)
%       y — [N×1] numeric vector of intensity values
%
%   Name-Value Options:
%       Method        — 'snip' (default) or 'polynomial'
%       MaxWindowDeg  — SNIP: max clipping window in x-axis units (default 2.0)
%       SmoothPasses  — SNIP: smoothing passes on final background (default 3)
%       PolyDegree    — polynomial: degree of fit (default 4)
%       Iterative     — logical, enable iterative peak-mask-refit (default false)
%       IterMaxPasses — maximum refinement iterations (default 3)
%       IterSigma     — sigma threshold for peak masking (default 3.0)
%
%   Output:
%       bg — [N×1] estimated background vector, same size as y
%
%   Examples:
%       % Basic SNIP background
%       bg = utilities.estimateBackground(x, y);
%
%       % Iterative SNIP (better for sloped data with peaks)
%       bg = utilities.estimateBackground(x, y, 'Iterative', true);
%
%       % Polynomial background (good for gentle slopes)
%       bg = utilities.estimateBackground(x, y, 'Method', 'polynomial', 'PolyDegree', 3);

% ════════════════════════════════════════════════════════════════════════
%  Input validation
% ════════════════════════════════════════════════════════════════════════
    arguments
        x    (:,1) double
        y    (:,1) double
        options.Method        (1,:) char {mustBeMember(options.Method, {'snip','polynomial'})} = 'snip'
        options.MaxWindowDeg  (1,1) double {mustBePositive} = 2.0
        options.SmoothPasses  (1,1) double {mustBeNonnegative, mustBeInteger} = 3
        options.PolyDegree    (1,1) double {mustBePositive, mustBeInteger} = 4
        options.Iterative     (1,1) logical = false
        options.IterMaxPasses (1,1) double {mustBePositive, mustBeInteger} = 3
        options.IterSigma     (1,1) double {mustBePositive} = 3.0
    end

    n = numel(y);
    if n < 3
        bg = y;
        return;
    end

% ════════════════════════════════════════════════════════════════════════
%  Dispatch to selected method
% ════════════════════════════════════════════════════════════════════════
    switch options.Method
        case 'snip'
            bg = snipBackground(x, y, n, options);
        case 'polynomial'
            bg = polyBackground(x, y, n, options);
    end

% ════════════════════════════════════════════════════════════════════════
%  Iterative refinement (optional, works with any method)
% ════════════════════════════════════════════════════════════════════════
    if options.Iterative
        bg = iterativeRefine(x, y, bg, n, options);
    end

    % Ensure background never exceeds original data
    bg = min(bg, y(:));
end

% ════════════════════════════════════════════════════════════════════════
%  SNIP background (original algorithm, unchanged)
% ════════════════════════════════════════════════════════════════════════
function bg = snipBackground(x, y, n, options)
    dx = median(diff(x));
    if dx <= 0
        bg = y;
        return;
    end
    wMax = round(options.MaxWindowDeg / dx);
    wMax = max(1, min(wMax, floor((n - 1) / 2)));

    % SNIP in square-root domain (stabilises Poisson noise)
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

    % Light smoothing to reduce staircase artifacts
    smoothWin = 5;
    for pass = 1:options.SmoothPasses
        bgPad = [bg(3:-1:2); bg; bg(end-1:-1:end-2)];
        kernel = ones(smoothWin, 1) / smoothWin;
        bgSmooth = conv(bgPad, kernel, 'valid');
        bg = bgSmooth(1:n);
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Polynomial background via iterative sigma-clip
% ════════════════════════════════════════════════════════════════════════
function bg = polyBackground(x, y, n, options)
    deg = min(options.PolyDegree, max(1, floor(n/3) - 1));
    mask = true(n, 1);

    % Iterative: fit, reject points above sigma threshold, refit
    for pass = 1:4
        xm = x(mask);
        ym = y(mask);
        if numel(xm) < deg + 1
            break;
        end
        % Centre and scale x for numerical stability
        xc = mean(xm);
        xs = max(std(xm), eps);
        p  = polyfit((xm - xc) / xs, ym, deg);
        bg = polyval(p, (x - xc) / xs);

        residual = y - bg;
        sigma = 1.4826 * median(abs(residual(mask) - median(residual(mask))));
        if sigma < eps, break; end

        % Mask points that are significantly above background (peaks)
        mask = residual < options.IterSigma * sigma;
        if sum(mask) < deg + 1
            mask = true(n, 1);
            break;
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Iterative peak-mask-refit refinement
% ════════════════════════════════════════════════════════════════════════
function bg = iterativeRefine(x, y, bg, n, options)
    for pass = 1:options.IterMaxPasses
        residual = y(:) - bg;

        % Estimate noise from below-background residual (non-peak regions)
        belowMed = residual(residual < median(residual));
        if numel(belowMed) > 5
            sigma = 1.4826 * median(abs(belowMed - median(belowMed)));
        else
            sigma = 1.4826 * median(abs(residual - median(residual)));
        end
        % Guard: if noise is negligible relative to data range, stop
        dataRange = max(y) - min(y);
        if sigma < max(eps, dataRange * 1e-10), break; end

        % Mask peak regions (above threshold)
        peakMask = residual > options.IterSigma * sigma;

        % Dilate peak mask by a few points to cover peak wings
        dilateW = max(3, round(0.005 * n));
        dilated = peakMask;
        for d = 1:dilateW
            prev = dilated;
            dilated(2:end)   = dilated(2:end)   | prev(1:end-1);
            dilated(1:end-1) = dilated(1:end-1) | prev(2:end);
        end

        nonPeak = ~dilated;
        if sum(nonPeak) < 10, break; end

        bgPrev = bg;

        % Re-estimate background from non-peak points only
        switch options.Method
            case 'snip'
                % Interpolate across masked regions, then re-run SNIP
                yClean = y(:);
                yClean(dilated) = interp1(x(nonPeak), y(nonPeak), ...
                    x(dilated), 'linear', 'extrap');
                bg = snipBackground(x, yClean, n, options);
            case 'polynomial'
                bg = polyBackground(x, y, n, options);
        end

        % Convergence check (background change < 1% of noise)
        if max(abs(bg - bgPrev)) < 0.01 * sigma
            break;
        end
    end
end
