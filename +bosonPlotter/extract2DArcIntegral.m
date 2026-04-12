function [newDs, cutLabel] = extract2DArcIntegral(ds, params, fig, buildDsFcn)
%EXTRACT2DARCINTEGRAL  Integrate a 2D RSM along arcs of constant |Q|.
%
%   Syntax:
%     [newDs, cutLabel] = bosonPlotter.extract2DArcIntegral(ds, params, fig, buildDsFcn)
%
%   Inputs:
%     ds          - active 2D dataset struct (must have Q-space: map2D.Qx/Qz)
%     params      - struct with fields:
%                     .qMin, .qMax   — Q-radius range (Ang^-1)
%                     .nBins         — number of radial bins
%                     .sectorMin     — azimuthal start angle in degrees (0 = +Qx, CCW)
%                     .sectorMax     — azimuthal end angle in degrees
%                     .mode          — 'Sum' or 'Mean'
%     fig         - figure handle (for uialert dialogs)
%     buildDsFcn  - @buildDs function handle from BosonPlotter (builds dataset struct)
%
%   Outputs:
%     newDs     - new dataset struct ([] if the operation failed)
%     cutLabel  - label string for the extracted profile ('' if failed)
%
%   Examples:
%     [newDs, lbl] = bosonPlotter.extract2DArcIntegral(ds, params, fig, @buildDs);
%     if ~isempty(newDs)
%         appData.datasets{end+1} = newDs;
%     end

    newDs    = [];
    cutLabel = '';

    map = ds.data.metadata.parserSpecific.map2D;
    if ~isfield(map, 'Qx'), return; end

    [~, fn, fext] = fileparts(ds.filepath);

    % Flatten Q-space grids and intensity
    Qx_v  = map.Qx(:);
    Qz_v  = map.Qz(:);
    I_v   = double(map.intensity(:));
    Qrad  = hypot(Qx_v, Qz_v);
    phi   = atan2d(Qz_v, Qx_v);  % [-180, 180]

    % Apply azimuthal sector mask
    sMin = params.sectorMin;
    sMax = params.sectorMax;
    fullCircle = (sMin == 0 && sMax == 360) || (sMin == -180 && sMax == 180);
    if ~fullCircle
        if sMin < sMax
            sectorMask = (phi >= sMin) & (phi < sMax);
        else
            % Wrapping sector (e.g. 170 → -170)
            sectorMask = (phi >= sMin) | (phi < sMax);
        end
    else
        sectorMask = true(size(Qrad));
    end

    % Apply Q-range and sector masks, exclude NaN
    mask = sectorMask & ~isnan(I_v) & (Qrad >= params.qMin) & (Qrad <= params.qMax);
    if ~any(mask)
        uialert(fig, 'No data points fall within the specified Q-range and sector.', ...
            'Empty Selection');
        return;
    end

    Qrad_m = Qrad(mask);
    I_m    = I_v(mask);

    % Radial binning
    nBins    = params.nBins;
    edges    = linspace(params.qMin, params.qMax, nBins + 1);
    binWidth = edges(2) - edges(1);
    binCentres = (edges(1:nBins) + edges(2:nBins+1))' / 2;

    binIdx = floor((Qrad_m - params.qMin) / binWidth) + 1;
    binIdx = max(1, min(binIdx, nBins));

    binSum   = accumarray(binIdx, I_m,   [nBins 1], @sum, 0);
    binCount = accumarray(binIdx, ones(size(I_m)), [nBins 1], @sum, 0);

    if strcmp(params.mode, 'Mean')
        yVec = binSum ./ binCount;
        yVec(binCount == 0) = NaN;
        modeStr = 'mean';
    else
        yVec = binSum;
        modeStr = 'sum';
    end

    % Build label
    if fullCircle
        sectorStr = '';
    else
        sectorStr = sprintf(' sector [%.0f%s%.0f%s]', ...
            sMin, char(176), sMax, char(176));
    end
    cutLabel = sprintf('Arc %s |Q|=[%.4g–%.4g] %s%s%s (%s)', ...
        char(8747), params.qMin, params.qMax, char(197), ...
        char(8315), char(185), modeStr);
    if ~isempty(sectorStr)
        cutLabel = [cutLabel sectorStr];
    end

    meta.source      = ds.filepath;
    meta.importDate  = datetime('now');
    meta.parserName  = 'arcIntegral';
    meta.xColumnName = '|Q| (Ang^-1)';
    meta.xColumnUnit = '';
    meta.parserSpecific = struct('is2D', false, ...
        'originFile', ds.filepath, 'cutLabel', cutLabel, ...
        'qRange', [params.qMin params.qMax], ...
        'sector', [sMin sMax], 'mode', params.mode);
    arcData = parser.createDataStruct(binCentres, yVec, ...
        'labels',   {['I (' map.intensityUnit ')']}, ...
        'units',    {map.intensityUnit}, ...
        'metadata', meta);

    newDs             = buildDsFcn('[arcIntegral]', arcData, 'arcIntegral');
    newDs.displayName = cutLabel;
    newDs.legendName  = cutLabel;

    fprintf('[BosonPlotter] Arc integral added: %s — %s\n', [fn fext], cutLabel);
end
