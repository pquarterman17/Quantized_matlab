function [baseline, params] = baselineRollingBall(y, options)
%BASELINEROLLINGBALL  Rolling ball baseline estimation.
%
%   [baseline, params] = utilities.baselineRollingBall(y)
%   [baseline, params] = utilities.baselineRollingBall(y, 'Radius', 200)
%
%   Estimates a baseline by conceptually rolling a ball (parabola in 1D)
%   underneath the spectrum.  The ball cannot penetrate the data, so it
%   traces a smooth lower envelope.  This is a morphological approach:
%   erosion with a parabolic structuring element followed by dilation.
%
%   The algorithm is fast (O(N * Radius)) and parameter-intuitive: the
%   Radius controls the scale of features the ball can "fit into".  Peaks
%   narrower than the ball diameter are effectively removed from the
%   baseline; broader undulations are preserved.
%
%   Inputs:
%       y — [N×1] numeric signal vector
%
%   Name-Value Options:
%       Radius — ball radius in points (default 100).
%                Larger radius = smoother baseline that ignores wider peaks.
%       Smooth — smoothing half-width applied to the final baseline
%                (default: Radius/10, minimum 0). Set to 0 to disable.
%
%   Outputs:
%       baseline — [N×1] estimated baseline
%       params   — struct with fields:
%                   .radius — ball radius used
%                   .smooth — smoothing half-width used
%
%   Examples:
%       bl = utilities.baselineRollingBall(spectrum, 'Radius', 150);
%       corrected = spectrum - bl;
%
%   References:
%       M.A. Kneen & H.J. Annegarn, "Algorithm for fitting XRF, SEM and
%       PIXE X-ray spectra backgrounds", Nucl. Instr. Meth. B 109/110
%       (1996) 209-213.
%
%   See also utilities.baselineALS, utilities.estimateBackground

% ════════════════════════════════════════════════════════════════════════
%  Input validation
% ════════════════════════════════════════════════════════════════════════
    arguments
        y        (:,1) double
        options.Radius (1,1) double {mustBePositive, mustBeInteger} = 100
        options.Smooth (1,1) double {mustBeNonnegative}            = -1
    end

    R = options.Radius;
    N = numel(y);

    % Default smoothing: Radius/10
    if options.Smooth < 0
        smoothHW = max(1, round(R / 10));
    else
        smoothHW = round(options.Smooth);
    end

% ════════════════════════════════════════════════════════════════════════
%  Trivial cases
% ════════════════════════════════════════════════════════════════════════
    if N < 3
        baseline = y;
        params = struct('radius', R, 'smooth', smoothHW);
        return;
    end

% ════════════════════════════════════════════════════════════════════════
%  Precompute parabolic structuring element
%  A ball of radius R touching at offset j rises by: R - sqrt(R^2 - j^2)
%  We precompute this "rise" for j = -halfW .. +halfW
% ════════════════════════════════════════════════════════════════════════
    halfW = min(R, N - 1);
    j = (-halfW:halfW)';
    % Clamp to avoid complex sqrt when |j| > R (shouldn't happen since halfW <= R)
    rise = R - sqrt(max(R*R - j.*j, 0));

% ════════════════════════════════════════════════════════════════════════
%  Erosion: sliding minimum of (y_j + rise_j)
%  For each point i, eroded(i) = min over j of [y(i+j) + rise(|j|)]
%  This is the lowest the ball's centre can sit at position i.
% ════════════════════════════════════════════════════════════════════════
    eroded = inf(N, 1);

    for k = 1:numel(j)
        offset = j(k);
        riseVal = rise(k);

        % Determine valid index range
        iStart = max(1, 1 - offset);
        iEnd   = min(N, N - offset);

        % y(i + offset) + rise
        eroded(iStart:iEnd) = min(eroded(iStart:iEnd), ...
                                   y(iStart+offset:iEnd+offset) + riseVal);
    end

% ════════════════════════════════════════════════════════════════════════
%  Dilation: sliding maximum of (eroded_j - rise_j)
%  For each point i, dilated(i) = max over j of [eroded(i+j) - rise(|j|)]
%  This reconstructs the baseline from the eroded signal.
% ════════════════════════════════════════════════════════════════════════
    dilated = -inf(N, 1);

    for k = 1:numel(j)
        offset = j(k);
        riseVal = rise(k);

        iStart = max(1, 1 - offset);
        iEnd   = min(N, N - offset);

        dilated(iStart:iEnd) = max(dilated(iStart:iEnd), ...
                                    eroded(iStart+offset:iEnd+offset) - riseVal);
    end

    baseline = dilated;

% ════════════════════════════════════════════════════════════════════════
%  Optional smoothing pass
% ════════════════════════════════════════════════════════════════════════
    if smoothHW > 0 && N > 2*smoothHW
        wLen = 2 * smoothHW + 1;
        kernel = ones(wLen, 1) / wLen;

        % Mirror-pad to reduce edge effects
        padLen = min(smoothHW, N - 1);
        padded = [baseline(padLen+1:-1:2); baseline; baseline(end-1:-1:end-padLen)];
        smoothed = conv(padded, kernel, 'valid');
        baseline = smoothed(1:N);
    end

    % Ensure baseline does not exceed data
    baseline = min(baseline, y);

    params = struct('radius', R, 'smooth', smoothHW);
end
