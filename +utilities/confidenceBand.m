function result = confidenceBand(datasets, options)
%CONFIDENCEBAND  Compute mean ± spread from multiple datasets.
%
%   result = utilities.confidenceBand(datasets)
%   result = utilities.confidenceBand(datasets, 'Method', 'median')
%
%   Given N data structs of the same measurement, interpolates all onto a
%   common x-grid and computes the central tendency ± spread.
%
%   INPUTS:
%       datasets — cell array of data structs (each with .time, .values)
%
%   OPTIONAL NAME-VALUE PAIRS:
%       Method  — 'mean' (default): mean ± std
%                 'median': median ± IQR (25th–75th percentile)
%       Channel — column index to analyze (default 1)
%       NPoints — number of points on the common grid (default: max of all)
%
%   OUTPUT:
%       result — struct with fields:
%           .x      — common x-grid [Nx1]
%           .center — central tendency (mean or median) [Nx1]
%           .upper  — upper bound (mean+std or 75th pct) [Nx1]
%           .lower  — lower bound (mean-std or 25th pct) [Nx1]
%           .spread — std or IQR half-width [Nx1]
%           .method — 'mean' or 'median'
%           .nSets  — number of datasets used
%
%   EXAMPLES:
%       % Compute confidence band from 5 repeat measurements
%       result = utilities.confidenceBand({d1, d2, d3, d4, d5});
%       fill([result.x; flipud(result.x)], ...
%            [result.upper; flipud(result.lower)], 'b', 'FaceAlpha', 0.2);
%       hold on; plot(result.x, result.center, 'b-', 'LineWidth', 1.5);
%
%   See also utilities.normalize, utilities.datasetAlgebra

    arguments
        datasets  (1,:) cell
        options.Method  (1,1) string {mustBeMember(options.Method, {'mean','median'})} = 'mean'
        options.Channel (1,1) double {mustBePositive, mustBeInteger} = 1
        options.NPoints (1,1) double {mustBePositive, mustBeInteger} = 0
    end

    nSets = numel(datasets);
    if nSets < 2
        error('utilities:confidenceBand:tooFew', ...
            'Need at least 2 datasets, got %d.', nSets);
    end

    % Determine common x-range (intersection of all datasets)
    xMin = -inf;
    xMax = inf;
    maxLen = 0;
    for i = 1:nSets
        xi = double(datasets{i}.time);
        xMin = max(xMin, min(xi));
        xMax = min(xMax, max(xi));
        maxLen = max(maxLen, numel(xi));
    end

    if xMin >= xMax
        error('utilities:confidenceBand:noOverlap', ...
            'Datasets have no overlapping x-range.');
    end

    % Build common grid
    nPts = options.NPoints;
    if nPts == 0
        nPts = maxLen;
    end
    xCommon = linspace(xMin, xMax, nPts)';

    % Interpolate all datasets onto common grid
    yMatrix = NaN(nPts, nSets);
    for i = 1:nSets
        xi = double(datasets{i}.time);
        ch = min(options.Channel, size(datasets{i}.values, 2));
        yi = datasets{i}.values(:, ch);
        yMatrix(:, i) = interp1(xi, yi, xCommon, 'pchip', NaN);
    end

    % Compute statistics
    switch options.Method
        case 'mean'
            center = mean(yMatrix, 2, 'omitnan');
            spread = std(yMatrix, 0, 2, 'omitnan');
            upper  = center + spread;
            lower  = center - spread;
        case 'median'
            center = median(yMatrix, 2, 'omitnan');
            q25    = prctile(yMatrix, 25, 2);
            q75    = prctile(yMatrix, 75, 2);
            upper  = q75;
            lower  = q25;
            spread = (q75 - q25) / 2;
    end

    result.x       = xCommon;
    result.center  = center;
    result.upper   = upper;
    result.lower   = lower;
    result.spread  = spread;
    result.method  = char(options.Method);
    result.nSets   = nSets;
end
