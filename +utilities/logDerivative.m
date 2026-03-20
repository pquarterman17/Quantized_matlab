function [dlogy, xOut] = logDerivative(x, y, options)
%LOGDERIVATIVE  Logarithmic derivative d(log Y)/d(log X).
%
%   dlogy = utilities.logDerivative(x, y)
%   dlogy = utilities.logDerivative(x, y, 'PreSmooth', 5)
%
%   Computes the power-law exponent: d(ln Y)/d(ln X) = (x/y) · (dY/dX).
%   Points where x ≤ 0 or y ≤ 0 are set to NaN (log undefined).
%   Operates column-wise on [NxM] matrices.
%
%   INPUTS:
%       x — [Nx1] positive numeric vector
%       y — [Nx1] or [NxM] numeric array (positive values expected)
%
%   OPTIONAL NAME-VALUE PAIRS:
%       PreSmooth — smoothing half-window before differentiation (default 0)
%
%   OUTPUTS:
%       dlogy — logarithmic derivative, same size as y
%       xOut  — x vector (same as input)
%
%   EXAMPLES:
%       % Identify power-law regimes in reflectivity
%       dlogy = utilities.logDerivative(Q, R, 'PreSmooth', 3);
%       plot(Q, dlogy);  % constant regions = power-law exponent
%
%   See also utilities.derivative, utilities.cumulativeIntegral

    arguments
        x       (:,1) double
        y       (:,:) double
        options.PreSmooth (1,1) double {mustBeNonnegative, mustBeInteger} = 0
    end

    if numel(x) ~= size(y, 1)
        error('utilities:logDerivative:sizeMismatch', ...
            'x length (%d) must match y row count (%d).', numel(x), size(y, 1));
    end

    xOut = x;

    % Optional pre-smoothing
    if options.PreSmooth > 0
        y = utilities.smoothData(y, 'Window', options.PreSmooth, 'Method', 'gaussian');
    end

    dlogy = NaN(size(y));
    for c = 1:size(y, 2)
        col = y(:, c);
        % dY/dX via central differences
        dydx = gradient(col, x);
        % d(log Y)/d(log X) = (x / y) * (dY/dX)
        valid = (x > 0) & (col > 0);
        dlogy(valid, c) = (x(valid) ./ col(valid)) .* dydx(valid);
    end
end
