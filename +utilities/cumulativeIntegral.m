function [intY, xOut] = cumulativeIntegral(x, y)
%CUMULATIVEINTEGRAL  Cumulative trapezoidal integral of y with respect to x.
%
%   intY = utilities.cumulativeIntegral(x, y)
%
%   Computes the running integral ∫₀ˣ y(t) dt using the trapezoidal rule.
%   Operates column-wise on [NxM] matrices.  NaN values are treated as 0
%   for integration but preserved as NaN in the output at those positions.
%
%   INPUTS:
%       x — [Nx1] numeric vector (must be monotonic)
%       y — [Nx1] or [NxM] numeric array
%
%   OUTPUTS:
%       intY — cumulative integral, same size as y.  intY(1,:) = 0.
%       xOut — x vector (same as input; useful for pipeline chaining)
%
%   EXAMPLES:
%       intY = utilities.cumulativeIntegral(data.time, data.values);
%
%   See also utilities.derivative, utilities.logDerivative

    arguments
        x (:,1) double
        y (:,:) double
    end

    if numel(x) ~= size(y, 1)
        error('utilities:cumulativeIntegral:sizeMismatch', ...
            'x length (%d) must match y row count (%d).', numel(x), size(y, 1));
    end

    xOut = x;
    intY = zeros(size(y));

    for c = 1:size(y, 2)
        col = y(:, c);
        nanMask = isnan(col);
        col(nanMask) = 0;
        intY(:, c) = cumtrapz(x, col);
        intY(nanMask, c) = NaN;
    end
end
