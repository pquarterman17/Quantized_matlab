function corrData = applyCorrections(rawData, params, options)
%APPLYCORRECTIONS  Apply the DataPlotter corrections pipeline to a data struct.
%
%   corrData = dataplotter.applyCorrections(rawData, params)
%   corrData = dataplotter.applyCorrections(rawData, params, 'BgDataset', bgDs)
%
%   This is the core, GUI-independent corrections pipeline extracted from
%   DataPlotter.  It takes raw data + a params struct and returns corrected
%   data.  DataPlotter's onApplyCorrections reads UI widgets into `params`,
%   then delegates here.
%
%   Inputs:
%       rawData     Unified data struct (.time, .values, .labels, .units, .metadata)
%       params      Struct with correction parameters:
%                     .xOff        (double) X-axis offset
%                     .yOff        (double) Y-axis offset (multiplicative for neutron)
%                     .bgSlope     (double) Background slope
%                     .bgInt       (double) Background intercept
%                     .bgPoly      (double vector) Polynomial coefficients (optional)
%                     .xTrimMin    (double) X-axis crop minimum (NaN = no trim)
%                     .xTrimMax    (double) X-axis crop maximum (NaN = no trim)
%                     .smoothEnabled (logical) Enable smoothing
%                     .smoothWindow  (double) Smoothing window size
%                     .smoothMethod  (char) 'gaussian' | 'savitzky-golay' | 'moving'
%                     .normMethod  (char) 'None' | 'Range [0,1]' | 'Peak (max=1)' | 'Z-score' | 'Area (integral=1)'
%                     .derivativeMode (char) 'None' | 'dY/dX' | 'd²Y/dX²' | '∫Y dx' | 'dlog/dlog'
%                     .isNeutron   (logical) Whether this is neutron reflectometry data
%                     .isMag       (logical) Whether this is magnetometry data
%                     .fieldUnit   (char) Field unit for mag data (optional)
%                     .momentUnit  (char) Moment unit for mag data (optional)
%                     .sampleMass  (double) Sample mass in grams (optional)
%                     .sampleVolume (double) Sample volume in cm³ (optional)
%
%   Name-Value Options:
%       BgDataset   Struct with .time, .values for background subtraction
%       BgInterp    Interpolation method for background ('linear','pchip',...)
%
%   Output:
%       corrData    Corrected data struct (same fields as rawData)
%
%   Pipeline order:
%       1. Trim/crop → 2. X offset → 3. Y background/offset →
%       4. Background dataset subtraction → 5. Magnetometry unit conversion →
%       6. Smoothing → 7. Normalization → 8. Derivative
%
%   See also: DataPlotter, dataplotter.correctionParams

% ════════════════════════════════════════════════════════════════════════
%  Input validation
% ════════════════════════════════════════════════════════════════════════
arguments
    rawData    struct
    params     struct
    options.BgDataset  = []
    options.BgInterp   string = "linear"
end

corrData = rawData;

% ════════════════════════════════════════════════════════════════════════
%  1. Trim / crop (FIRST step)
% ════════════════════════════════════════════════════════════════════════
xTrimMin = params.xTrimMin;
xTrimMax = params.xTrimMax;
if ~isnan(xTrimMin) || ~isnan(xTrimMax)
    tVec = double(corrData.time);
    mask = true(size(tVec));
    if ~isnan(xTrimMin), mask = mask & tVec >= xTrimMin; end
    if ~isnan(xTrimMax), mask = mask & tVec <= xTrimMax; end
    corrData.time   = corrData.time(mask);
    corrData.values = corrData.values(mask, :);
end

% ════════════════════════════════════════════════════════════════════════
%  2. X-axis offset (skip for datetime)
% ════════════════════════════════════════════════════════════════════════
if ~isdatetime(corrData.time)
    corrData.time = corrData.time - params.xOff;
end

% ════════════════════════════════════════════════════════════════════════
%  3. Y-axis corrections (background + offset)
% ════════════════════════════════════════════════════════════════════════
isNeutron = isfield(params, 'isNeutron') && params.isNeutron;
if isNeutron
    % Neutron: yOff is multiplicative R scale factor; skip dQ columns
    for k = 1:size(corrData.values, 2)
        if ~strcmpi(corrData.labels{k}, 'dQ')
            corrData.values(:, k) = corrData.values(:, k) * params.yOff;
        end
    end
else
    % Standard: y_corrected = y_raw - yBG(x) - yOff
    hasPoly = isfield(params, 'bgPoly') && numel(params.bgPoly) > 2;
    for k = 1:size(corrData.values, 2)
        yRaw = corrData.values(:, k);
        if isdatetime(corrData.time)
            xForBG = (1:numel(yRaw))';
        else
            xForBG = double(corrData.time);
        end
        if hasPoly
            yBG = polyval(params.bgPoly, xForBG);
        else
            yBG = params.bgSlope .* xForBG + params.bgInt;
        end
        corrData.values(:, k) = yRaw - yBG - params.yOff;
    end
end

% ════════════════════════════════════════════════════════════════════════
%  4. Background dataset subtraction
% ════════════════════════════════════════════════════════════════════════
bgDs = options.BgDataset;
if ~isempty(bgDs)
    if ~isdatetime(bgDs.time) && ~isdatetime(corrData.time)
        bgX = double(bgDs.time);
        bgY = bgDs.values(:, 1);
        bgInterp = interp1(bgX, bgY, double(corrData.time), ...
                           char(options.BgInterp), 0);
        for k = 1:size(corrData.values, 2)
            corrData.values(:, k) = corrData.values(:, k) - bgInterp;
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
%  5. Magnetometry unit conversion
% ════════════════════════════════════════════════════════════════════════
isMag = isfield(params, 'isMag') && params.isMag;
if isMag && ~isdatetime(corrData.time)
    % Field unit conversion (x-axis)
    fUnit = '';
    if isfield(params, 'fieldUnit'), fUnit = params.fieldUnit; end
    if ~isempty(fUnit) && ~strcmp(fUnit, 'Oe (raw)')
        targetField = regexprep(fUnit, ' \(raw\)', '');
        corrData.time = utilities.convertUnits(double(corrData.time), 'Oe', targetField);
    end

    % Moment normalization (y-axis)
    mUnit = '';
    if isfield(params, 'momentUnit'), mUnit = params.momentUnit; end
    switch mUnit
        case 'emu/g'
            mass_g = 0;
            if isfield(params, 'sampleMass'), mass_g = params.sampleMass; end
            if mass_g > 0
                corrData.values = corrData.values / mass_g;
            end
        case 'emu/cm³'
            vol = 0;
            if isfield(params, 'sampleVolume'), vol = params.sampleVolume; end
            if vol > 0
                corrData.values = corrData.values / vol;
            end
        case 'A·m²'
            corrData.values = corrData.values * 1e-3;
        case 'kA/m'
            vol = 0;
            if isfield(params, 'sampleVolume'), vol = params.sampleVolume; end
            if vol > 0
                corrData.values = corrData.values / vol;
            end
    end
end

% ════════════════════════════════════════════════════════════════════════
%  6. Smoothing
% ════════════════════════════════════════════════════════════════════════
if isfield(params, 'smoothEnabled') && params.smoothEnabled
    win = max(1, round(params.smoothWindow));
    corrData.values = utilities.smoothData(corrData.values, ...
        'Window', win, 'Method', lower(params.smoothMethod));
end

% ════════════════════════════════════════════════════════════════════════
%  7. Normalization
% ════════════════════════════════════════════════════════════════════════
normMethod = 'None';
if isfield(params, 'normMethod'), normMethod = params.normMethod; end
switch normMethod
    case 'Range [0,1]'
        corrData.values = utilities.normalize(corrData.values, 'Method', 'range');
    case 'Peak (max=1)'
        corrData.values = utilities.normalize(corrData.values, 'Method', 'peak');
    case 'Z-score'
        corrData.values = utilities.normalize(corrData.values, 'Method', 'zscore');
    case 'Area (integral=1)'
        for k = 1:size(corrData.values, 2)
            A = trapz(double(corrData.time), corrData.values(:, k));
            if A ~= 0, corrData.values(:, k) = corrData.values(:, k) / A; end
        end
end

% ════════════════════════════════════════════════════════════════════════
%  8. Derivative / integral (LAST step)
% ════════════════════════════════════════════════════════════════════════
derivMode = 'None';
if isfield(params, 'derivativeMode'), derivMode = params.derivativeMode; end
if ~strcmp(derivMode, 'None') && ~isdatetime(corrData.time)
    xVec = double(corrData.time);
    switch derivMode
        case 'dY/dX'
            corrData.values = utilities.derivative(xVec, corrData.values, 'Order', 1);
        case 'd²Y/dX²'
            corrData.values = utilities.derivative(xVec, corrData.values, 'Order', 2);
        case '∫Y dx'
            corrData.values = utilities.cumulativeIntegral(xVec, corrData.values);
        case 'dlog/dlog'
            corrData.values = utilities.logDerivative(xVec, corrData.values);
    end
end

end
