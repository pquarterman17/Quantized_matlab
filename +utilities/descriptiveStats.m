function s = descriptiveStats(x)
%DESCRIPTIVESTATS  Compute descriptive statistics for a numeric vector.
%
%   s = utilities.descriptiveStats(x)
%
%   Returns a struct with standard summary statistics.  No Statistics
%   Toolbox required — all computed from MATLAB built-ins.
%
%   Input:
%       x — numeric vector (NaN values are excluded)
%
%   Output (struct):
%       .N        — number of non-NaN observations
%       .mean     — arithmetic mean
%       .median   — median
%       .std      — sample standard deviation (N-1 denominator)
%       .sem      — standard error of the mean (std/sqrt(N))
%       .var      — sample variance
%       .min      — minimum value
%       .max      — maximum value
%       .range    — max - min
%       .q1       — 25th percentile (first quartile)
%       .q3       — 75th percentile (third quartile)
%       .iqr      — interquartile range (q3 - q1)
%       .skewness — sample skewness (Fisher's definition)
%       .kurtosis — sample excess kurtosis (Fisher's; normal = 0)
%
%   Example:
%       s = utilities.descriptiveStats(randn(1000,1));
%       fprintf('Mean=%.3f ± %.3f, Skew=%.3f\n', s.mean, s.sem, s.skewness);

arguments
    x (:,1) double
end

% Remove NaN
x = x(~isnan(x));
n = numel(x);

s.N      = n;
s.mean   = mean(x);
s.median = median(x);
s.std    = std(x);
s.sem    = s.std / sqrt(max(n, 1));
s.var    = var(x);
s.min    = min(x);
s.max    = max(x);
s.range  = s.max - s.min;

% Quartiles via sorted data
if n >= 4
    xSorted = sort(x);
    s.q1 = interp1((1:n)', xSorted, 0.25*(n+1), 'linear', xSorted(1));
    s.q3 = interp1((1:n)', xSorted, 0.75*(n+1), 'linear', xSorted(end));
    s.iqr = s.q3 - s.q1;
else
    s.q1  = NaN;
    s.q3  = NaN;
    s.iqr = NaN;
end

% Skewness (Fisher's definition): E[(x-μ)³] / σ³
if n >= 3 && s.std > 0
    m3 = mean((x - s.mean).^3);
    s.skewness = m3 / s.std^3 * (n^2 / ((n-1)*(n-2)));
else
    s.skewness = NaN;
end

% Excess kurtosis (Fisher's): E[(x-μ)⁴]/σ⁴ - 3, with bias correction
if n >= 4 && s.std > 0
    m4 = mean((x - s.mean).^4);
    rawKurt = m4 / s.std^4;
    % Bias-corrected excess kurtosis
    s.kurtosis = ((n+1)*rawKurt - 3*(n-1)) * (n-1) / ((n-2)*(n-3));
else
    s.kurtosis = NaN;
end

end
