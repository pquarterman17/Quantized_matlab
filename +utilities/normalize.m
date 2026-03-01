function out = normalize(y, options)
%NORMALIZE  Normalise a data vector or matrix to a target range or peak.
%
%   out = utilities.normalize(y)
%   out = utilities.normalize(y, 'Method', 'peak')
%   out = utilities.normalize(y, 'Method', 'range', 'Range', [0 1])
%
%   Normalises each COLUMN of y independently.  NaN values are ignored
%   when computing statistics but preserved in the output.
%
%   INPUTS:
%       y — [Nx1] or [NxM] numeric array
%
%   OPTIONAL NAME-VALUE PAIRS:
%       Method — normalisation method:
%                  'range' (default) — linearly maps [min,max] → Range
%                  'peak'            — divides by the maximum absolute value
%                  'zscore'          — subtracts mean, divides by std dev
%       Range  — [lo, hi] target output range for 'range' method (default [0,1])
%
%   OUTPUT:
%       out — same size as y, normalised
%
%   EXAMPLES:
%       % Scale XRD intensity to [0,1]
%       normI = utilities.normalize(data.values);
%
%       % Normalise to peak height
%       normI = utilities.normalize(data.values, 'Method', 'peak');
%
%       % Z-score each channel
%       zs = utilities.normalize(data.values, 'Method', 'zscore');
%
%   See also utilities.smoothData, utilities.convertUnits

    arguments
        y                   (:,:) double
        options.Method (1,1) string {mustBeMember(options.Method, ...
                            {'range','peak','zscore'})} = 'range'
        options.Range  (1,2) double = [0, 1]
    end

    out = NaN(size(y));

    for c = 1:size(y, 2)
        col = y(:, c);
        switch options.Method
            case 'range'
                lo = min(col, [], 'omitnan');
                hi = max(col, [], 'omitnan');
                span = hi - lo;
                if span == 0
                    out(:, c) = options.Range(1);   % constant column
                else
                    out(:, c) = options.Range(1) + ...
                        (col - lo) ./ span .* diff(options.Range);
                end

            case 'peak'
                pk = max(abs(col), [], 'omitnan');
                if pk == 0
                    out(:, c) = col;
                else
                    out(:, c) = col ./ pk;
                end

            case 'zscore'
                mu = mean(col, 'omitnan');
                sg = std(col,  'omitnan');
                if sg == 0
                    out(:, c) = col - mu;
                else
                    out(:, c) = (col - mu) ./ sg;
                end
        end
    end
end
