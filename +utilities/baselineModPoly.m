function [baseline, params] = baselineModPoly(y, options)
%BASELINEMODPOLY  Modified polynomial baseline estimation.
%
%   [baseline, params] = utilities.baselineModPoly(y)
%   [baseline, params] = utilities.baselineModPoly(y, 'Order', 3, 'MaxIter', 50)
%
%   Estimates a baseline using iterative polynomial fitting (Lieber &
%   Mahadevan-Jansen, 2003).  At each iteration a polynomial of the
%   specified order is fitted to the data.  Points lying above the
%   polynomial are then replaced by the polynomial value, effectively
%   "pulling" the fit downward.  The process repeats until the polynomial
%   converges, yielding a smooth baseline beneath the peaks.
%
%   This method is particularly useful for removing broad fluorescence
%   backgrounds from Raman spectra, where the background varies smoothly
%   but can be much stronger than the Raman signal.
%
%   Inputs:
%       y — [N×1] numeric signal vector
%
%   Name-Value Options:
%       Order   — polynomial order (default 5). Higher orders can capture
%                 more complex curvature but risk overfitting.
%       MaxIter — maximum number of iterations (default 100)
%       Tol     — convergence tolerance on baseline RMS change (default 1e-6)
%
%   Outputs:
%       baseline — [N×1] estimated baseline
%       params   — struct with fields:
%                   .order     — polynomial order used
%                   .nIter     — number of iterations performed
%                   .converged — true if converged before MaxIter
%
%   Examples:
%       % Remove fluorescence from Raman spectrum
%       bl = utilities.baselineModPoly(ramanSpectrum, 'Order', 4);
%       corrected = ramanSpectrum - bl;
%
%   References:
%       C.A. Lieber & A. Mahadevan-Jansen, "Automated Method for
%       Subtraction of Fluorescence from Biological Raman Spectra",
%       Applied Spectroscopy 57(11), 1363-1367 (2003).
%
%   See also utilities.baselineALS, utilities.baselineRollingBall

% ════════════════════════════════════════════════════════════════════════
%  Input validation
% ════════════════════════════════════════════════════════════════════════
    arguments
        y        (:,1) double
        options.Order   (1,1) double {mustBePositive, mustBeInteger} = 5
        options.MaxIter (1,1) double {mustBePositive, mustBeInteger} = 100
        options.Tol     (1,1) double {mustBePositive}                = 1e-6
    end

    N = numel(y);

% ════════════════════════════════════════════════════════════════════════
%  Trivial cases
% ════════════════════════════════════════════════════════════════════════
    if N < 3
        baseline = y;
        params = struct('order', options.Order, 'nIter', 0, 'converged', true);
        return;
    end

    % Clamp polynomial order to what the data can support
    polyOrd = min(options.Order, N - 1);

% ════════════════════════════════════════════════════════════════════════
%  Normalise x-axis for numerical stability
% ════════════════════════════════════════════════════════════════════════
    x = (1:N)';
    xc = mean(x);
    xs = max(std(x), eps);
    xn = (x - xc) / xs;

% ════════════════════════════════════════════════════════════════════════
%  Iterative modified polynomial fitting
% ════════════════════════════════════════════════════════════════════════
    yMod = y;       % working copy — points above fit get replaced
    converged = false;

    for iter = 1:options.MaxIter
        % Fit polynomial to (possibly modified) data
        p = polyfit(xn, yMod, polyOrd);
        baseline = polyval(p, xn);

        % Replace points above the fit with the fit values
        yNew = min(yMod, baseline);

        % Convergence check: RMS change in modified signal, normalised by
        % signal range so Tol is dimensionless and works across scales.
        rmsChange = sqrt(mean((yNew - yMod).^2));
        yRange    = max(max(y) - min(y), eps);
        relChange = rmsChange / yRange;
        yMod = yNew;

        if relChange < options.Tol
            converged = true;
            break;
        end
    end

    % Final polynomial evaluated at all points
    baseline = polyval(p, xn);

    % Ensure baseline does not exceed original data
    baseline = min(baseline, y);

    params = struct('order', polyOrd, 'nIter', iter, 'converged', converged);
end
