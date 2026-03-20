function [dydx, xOut] = derivative(x, y, options)
%DERIVATIVE  Numerical derivative of y with respect to x.
%
%   dydx = utilities.derivative(x, y)
%   dydx = utilities.derivative(x, y, 'Order', 2)
%   [dydx, xOut] = utilities.derivative(x, y, 'PreSmooth', 5)
%
%   Computes dY/dX or d²Y/dX² using central differences (gradient).
%   Optionally pre-smooths Y before differentiation to suppress noise
%   amplification.  Operates column-wise on [NxM] matrices.
%
%   INPUTS:
%       x — [Nx1] numeric vector (must be monotonic)
%       y — [Nx1] or [NxM] numeric array
%
%   OPTIONAL NAME-VALUE PAIRS:
%       Order     — derivative order: 1 (default) or 2
%       PreSmooth — smoothing half-window applied before differentiation
%                   (0 = no smoothing, default).  Uses Gaussian method.
%
%   OUTPUTS:
%       dydx — derivative array, same size as y
%       xOut — x vector (same as input; useful for pipeline chaining)
%
%   EXAMPLES:
%       dydx = utilities.derivative(data.time, data.values);
%       d2ydx2 = utilities.derivative(data.time, data.values, 'Order', 2);
%       dydx = utilities.derivative(x, y, 'PreSmooth', 5);
%
%   See also utilities.logDerivative, utilities.cumulativeIntegral

    arguments
        x       (:,1) double
        y       (:,:) double
        options.Order     (1,1) double {mustBeMember(options.Order, [1 2])} = 1
        options.PreSmooth (1,1) double {mustBeNonnegative, mustBeInteger} = 0
    end

    if numel(x) ~= size(y, 1)
        error('utilities:derivative:sizeMismatch', ...
            'x length (%d) must match y row count (%d).', numel(x), size(y, 1));
    end

    xOut = x;

    % Optional pre-smoothing to reduce noise amplification
    if options.PreSmooth > 0
        y = utilities.smoothData(y, 'Window', options.PreSmooth, 'Method', 'gaussian');
    end

    % Compute derivative column-wise using central differences
    dydx = zeros(size(y));
    for c = 1:size(y, 2)
        dydx(:, c) = gradient(y(:, c), x);
        if options.Order == 2
            dydx(:, c) = gradient(dydx(:, c), x);
        end
    end
end
