function [corrected, bgSlope, bgIntercept] = subtractMagBackground(temperature, moment, options)
%SUBTRACTMAGBACKGROUND  Remove linear diamagnetic/paramagnetic background from M(T).
%
%   Syntax:
%     [corrected, bgSlope, bgIntercept] = ...
%         utilities.subtractMagBackground(temperature, moment)
%     [corrected, bgSlope, bgIntercept] = ...
%         utilities.subtractMagBackground(temperature, moment, ...
%             'FitRange', [200 350])
%     [corrected, bgSlope, bgIntercept] = ...
%         utilities.subtractMagBackground(temperature, moment, ...
%             'AutoFraction', 0.2)
%
%   At high temperature the ferromagnetic contribution saturates or
%   vanishes, leaving a linear background from diamagnetic or
%   paramagnetic contributions: M_bg = χ_bg·T + M0.  This function
%   fits a line to the high-T region and subtracts it from the full
%   data, isolating the ferromagnetic signal.
%
%   Inputs:
%     temperature — [N×1] temperature vector (K)
%     moment      — [N×1] moment vector (emu or any consistent units)
%
%   Name-Value Options:
%     FitRange     — [Tmin Tmax] temperature window for the linear fit
%                    (K).  Empty (default) triggers auto-selection.
%     AutoFraction — fraction of the full T range to use from the top
%                    when FitRange is empty (default: 0.1 = top 10%).
%
%   Outputs:
%     corrected    — [N×1] background-subtracted moment
%     bgSlope      — slope of the fitted background line (emu/K)
%     bgIntercept  — intercept of the fitted background line (emu)
%
%   Examples:
%     [Mcorr, slope, intercept] = ...
%         utilities.subtractMagBackground(T, M);
%
%     % Specify the high-T fit region explicitly
%     [Mcorr, ~, ~] = utilities.subtractMagBackground(T, M, ...
%         'FitRange', [250 350]);

% ════════════════════════════════════════════════════════════════════════
%  Input validation
% ════════════════════════════════════════════════════════════════════════
arguments
    temperature (:,1) double
    moment      (:,1) double
    options.FitRange     (1,2) double = [NaN NaN]
    options.AutoFraction (1,1) double {mustBePositive} = 0.1
end

n = numel(temperature);
if n < 3
    error('utilities:subtractMagBackground:tooFewPoints', ...
        'Need at least 3 data points.');
end
if numel(moment) ~= n
    error('utilities:subtractMagBackground:sizeMismatch', ...
        'temperature and moment must be the same length.');
end

% ════════════════════════════════════════════════════════════════════════
%  Determine fitting region
% ════════════════════════════════════════════════════════════════════════
Tmin = min(temperature);
Tmax = max(temperature);

if all(isnan(options.FitRange))
    % Auto: use top AutoFraction of the temperature range
    Tthresh = Tmax - options.AutoFraction * (Tmax - Tmin);
    fitMask = temperature >= Tthresh;
else
    fitMask = temperature >= options.FitRange(1) & ...
              temperature <= options.FitRange(2);
end

if sum(fitMask) < 2
    warning('utilities:subtractMagBackground:tooFewFitPoints', ...
        'Fit region contains fewer than 2 points; using full range.');
    fitMask = true(n, 1);
end

% ════════════════════════════════════════════════════════════════════════
%  Linear fit in high-T region
% ════════════════════════════════════════════════════════════════════════
Tfit = temperature(fitMask);
Mfit = moment(fitMask);

% Least-squares linear fit: [intercept, slope] via normal equations
X = [ones(numel(Tfit), 1), Tfit];
b = X \ Mfit;
bgIntercept = b(1);
bgSlope     = b(2);

% ════════════════════════════════════════════════════════════════════════
%  Subtract background over the full temperature range
% ════════════════════════════════════════════════════════════════════════
bg        = bgSlope .* temperature + bgIntercept;
corrected = moment - bg;

end
