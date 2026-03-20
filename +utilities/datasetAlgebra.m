function result = datasetAlgebra(dsA, dsB, operation, options)
%DATASETALGEBRA  Combine two data structs via arithmetic operations.
%
%   result = utilities.datasetAlgebra(dsA, dsB, 'A-B')
%   result = utilities.datasetAlgebra(dsA, dsB, '(A-B)/(A+B)')
%
%   Interpolates dataset B onto dataset A's x-grid (or a common grid),
%   then applies the requested operation channel-wise.  Returns a new
%   unified data struct via parser.createDataStruct.
%
%   INPUTS:
%       dsA       — data struct with .time, .values, .labels, .units, .metadata
%       dsB       — data struct (same field layout)
%       operation — one of: 'A+B', 'A-B', 'A*B', 'A/B', '(A-B)/(A+B)'
%
%   OPTIONAL NAME-VALUE PAIRS:
%       InterpMethod — interpolation method for grid alignment
%                      ('pchip' default, 'linear', 'spline')
%       ChannelA     — column index in dsA (default 1)
%       ChannelB     — column index in dsB (default 1)
%
%   OUTPUT:
%       result — unified data struct with the computed result
%
%   EXAMPLES:
%       % Subtract background from measurement
%       result = utilities.datasetAlgebra(signal, background, 'A-B');
%
%       % Spin asymmetry from up/down channels
%       result = utilities.datasetAlgebra(Rup, Rdown, '(A-B)/(A+B)');
%
%   See also parser.createDataStruct, utilities.derivative

    arguments
        dsA       (1,1) struct
        dsB       (1,1) struct
        operation (1,1) string {mustBeMember(operation, ...
                    {'A+B','A-B','A*B','A/B','(A-B)/(A+B)'})}
        options.InterpMethod (1,1) string {mustBeMember(options.InterpMethod, ...
                    {'pchip','linear','spline'})} = 'pchip'
        options.ChannelA (1,1) double {mustBePositive, mustBeInteger} = 1
        options.ChannelB (1,1) double {mustBePositive, mustBeInteger} = 1
    end

    xA = double(dsA.time);
    xB = double(dsB.time);

    chA = min(options.ChannelA, size(dsA.values, 2));
    chB = min(options.ChannelB, size(dsB.values, 2));

    yA = dsA.values(:, chA);
    yB_raw = dsB.values(:, chB);

    % Interpolate B onto A's x-grid
    yB = interp1(xB, yB_raw, xA, char(options.InterpMethod), NaN);

    % Apply operation
    switch operation
        case 'A+B'
            yResult = yA + yB;
            opLabel = sprintf('%s + %s', safeLabel(dsA, chA), safeLabel(dsB, chB));
        case 'A-B'
            yResult = yA - yB;
            opLabel = sprintf('%s - %s', safeLabel(dsA, chA), safeLabel(dsB, chB));
        case 'A*B'
            yResult = yA .* yB;
            opLabel = sprintf('%s × %s', safeLabel(dsA, chA), safeLabel(dsB, chB));
        case 'A/B'
            yResult = yA ./ yB;
            yResult(yB == 0) = NaN;
            opLabel = sprintf('%s / %s', safeLabel(dsA, chA), safeLabel(dsB, chB));
        case '(A-B)/(A+B)'
            denom = yA + yB;
            yResult = (yA - yB) ./ denom;
            yResult(denom == 0) = NaN;
            opLabel = sprintf('(%s - %s) / (%s + %s)', ...
                safeLabel(dsA, chA), safeLabel(dsB, chB), ...
                safeLabel(dsA, chA), safeLabel(dsB, chB));
    end

    % Determine units for result
    unitA = safeUnit(dsA, chA);
    switch operation
        case {'A+B','A-B'},     resultUnit = unitA;
        case 'A*B',             resultUnit = [unitA '²'];
        case 'A/B',             resultUnit = 'ratio';
        case '(A-B)/(A+B)',     resultUnit = 'asymmetry';
    end

    % Build metadata
    meta = struct();
    if isfield(dsA.metadata, 'source'), meta.source = dsA.metadata.source; end
    meta.operation = char(operation);

    result = parser.createDataStruct( ...
        'Time',     xA, ...
        'Values',   yResult, ...
        'Labels',   {{opLabel}}, ...
        'Units',    {{resultUnit}}, ...
        'Metadata', meta);
end

function lbl = safeLabel(ds, ch)
    if ch <= numel(ds.labels)
        lbl = ds.labels{ch};
    else
        lbl = sprintf('ch%d', ch);
    end
end

function u = safeUnit(ds, ch)
    if ch <= numel(ds.units)
        u = ds.units{ch};
    else
        u = '';
    end
end
