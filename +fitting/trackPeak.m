function result = trackPeak(datasets, seedPosition, options)
%TRACKPEAK  Track a peak across a series of datasets.
%
%   result = fitting.trackPeak(datasets, 45.2)
%   result = fitting.trackPeak(datasets, 45.2, Window=2, Shape='gaussian')
%
%   Starting from a seed peak position, finds and fits the nearest peak
%   in each dataset.  The search window follows the peak — if it drifts,
%   the search region moves with it.
%
%   Inputs:
%       datasets     — cell array of data structs or {x,y} pairs
%       seedPosition — x-position of the peak in the reference dataset
%
%   Options:
%       Channel   — column index for .values (default: 1)
%       Window    — half-width of the search window in x-units (default: auto)
%       Shape     — 'gaussian' | 'lorentzian' (for local peak fit, default: 'gaussian')
%       MinHeight — minimum peak height to accept (default: 0)
%       Follow    — if true, search window follows peak drift (default: true)
%
%   Output (struct):
%       .center   — [N×1] fitted peak center positions
%       .height   — [N×1] fitted peak heights
%       .fwhm     — [N×1] fitted full-width at half-maximum
%       .area     — [N×1] integrated peak area (from fit)
%       .R2       — [N×1] local fit R²
%       .found    — [N×1] logical — was a peak found?
%       .nDatasets— number of datasets
%
%   Example:
%       % Track Bragg peak at 2θ = 45.2° across temperature series
%       r = fitting.trackPeak(scans, 45.2, Window=1.5, Shape='lorentzian');
%       plot(temperatures, r.center, 'o-');  % peak shift vs T
%
%   Width-to-FWHM conventions
%   ─────────────────────────────
%   The local fit returns a width parameter that is converted to FWHM:
%
%     Gaussian:    sigma -> FWHM = 2*sqrt(2*ln 2) * sigma  ~ 2.355 * sigma
%     Lorentzian:  gamma -> FWHM = 2 * gamma
%
%   Integrated areas use the analytical forms
%
%     Gaussian:    A = amplitude * sigma * sqrt(2*pi)
%     Lorentzian:  A = amplitude * pi * gamma
%
%   The "Follow" mode is essential for steep peak migration (e.g. lattice
%   thermal expansion across a phase transition) — without it the search
%   window stays anchored at the seed and may lose the peak.
%
%   See also fitting.pawleyRefine (whole-pattern fit when peaks overlap),
%   fitting.curveFit (the underlying single-peak optimiser).

arguments
    datasets     cell
    seedPosition (1,1) double
    options.Channel   (1,1) double = 1
    options.Window    (1,1) double = 0
    options.Shape     (1,1) string {mustBeMember(options.Shape, ...
        ["gaussian","lorentzian"])} = "gaussian"
    options.MinHeight (1,1) double = 0
    options.Follow    (1,1) logical = true
end

N = numel(datasets);

center = NaN(N, 1);
height = NaN(N, 1);
fwhm   = NaN(N, 1);
area   = NaN(N, 1);
R2     = NaN(N, 1);
found  = false(N, 1);

currentPos = seedPosition;

for i = 1:N
    [xData, yData] = extractXY(datasets{i}, options.Channel);
    if isempty(xData) || numel(xData) < 5
        continue;
    end

    % Determine search window
    if options.Window > 0
        hw = options.Window;
    else
        % Auto: 5% of x-range
        hw = 0.05 * (max(xData) - min(xData));
    end

    % Extract data in search window around current position
    mask = xData >= (currentPos - hw) & xData <= (currentPos + hw);
    xSeg = xData(mask);
    ySeg = yData(mask);

    if numel(xSeg) < 5
        continue;
    end

    % Find local maximum
    [peakH, peakIdx] = max(ySeg);
    peakX = xSeg(peakIdx);

    if peakH < options.MinHeight
        continue;
    end

    % Local peak fit
    switch options.Shape
        case 'gaussian'
            % y = A * exp(-(x-mu)^2 / (2*sigma^2))
            fitFcn = @(x, p) p(1) * exp(-(x - p(2)).^2 ./ (2*p(3)^2));
            sigma0 = hw / 3;
            p0 = [peakH, peakX, sigma0];
            lb = [0, currentPos - hw, 0];
            ub = [Inf, currentPos + hw, hw];
        case 'lorentzian'
            % y = A / (1 + ((x-x0)/gamma)^2)
            fitFcn = @(x, p) p(1) ./ (1 + ((x - p(2)) ./ p(3)).^2);
            gamma0 = hw / 3;
            p0 = [peakH, peakX, gamma0];
            lb = [0, currentPos - hw, 0];
            ub = [Inf, currentPos + hw, hw];
    end

    try
        r = fitting.curveFit(xSeg, ySeg, fitFcn, p0, ...
            Lower=lb, Upper=ub, CalcErrors=false);

        if r.R2 > 0.5  % reasonable fit
            center(i) = r.params(2);
            height(i) = r.params(1);

            switch options.Shape
                case 'gaussian'
                    sigma = abs(r.params(3));
                    fwhm(i) = 2.355 * sigma;
                    area(i) = r.params(1) * sigma * sqrt(2*pi);
                case 'lorentzian'
                    gamma = abs(r.params(3));
                    fwhm(i) = 2 * gamma;
                    area(i) = r.params(1) * pi * gamma;
            end

            R2(i) = r.R2;
            found(i) = true;

            % Update search position for next dataset
            if options.Follow
                currentPos = center(i);
            end
        end
    catch
        % Fit failed — skip this dataset
    end
end

result.center    = center;
result.height    = height;
result.fwhm      = fwhm;
result.area      = area;
result.R2        = R2;
result.found     = found;
result.nDatasets = N;

end

% ════════════════════════════════════════════════════════════════════════

function [x, y] = extractXY(ds, channel)
    if isstruct(ds)
        if isfield(ds, 'corrData') && ~isempty(ds.corrData) && ...
                isfield(ds.corrData, 'time') && ~isempty(ds.corrData.time)
            plotD = ds.corrData;
        elseif isfield(ds, 'data')
            plotD = ds.data;
        elseif isfield(ds, 'time')
            plotD = ds;
        else
            x = []; y = []; return;
        end
        x = plotD.time(:);
        ch = min(channel, size(plotD.values, 2));
        y = plotD.values(:, ch);
    elseif iscell(ds) && numel(ds) >= 2
        x = ds{1}(:);
        y = ds{2}(:);
    else
        x = []; y = [];
    end
end
