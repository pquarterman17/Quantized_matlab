function d = applyDisplayUnits(d, ds, appData)
%APPLYDISPLAYUNITS  Scale exported data to match the units shown on the preview plot.
%
% Syntax
%   d = bosonPlotter.applyDisplayUnits(d, ds, appData)
%
% Applies two transformations:
%   1. Magnetometry unit conversion: multiplies .time / .values by the
%      appropriate factor to convert Oe/emu into the user's requested
%      field/moment unit, AND updates the corresponding labels.
%   2. SI axis prefix scaling: multiplies .time and .values by the
%      prefix factors currently active on the preview axes (e.g. kilo = 1e-3).
%
% NEVER mutates the input dataset (ds.data / ds.corrData).  The argument
% `d` is a COPY created by the caller before calling this function — we
% scale that copy and hand it back to the exporter.
%
% Inputs
%   d       - Data struct (.time, .values, .units, .metadata) to scale
%   ds      - Full dataset struct (for parserName, fieldUnit, momentUnit,
%             sample dimensions)
%   appData - bosonPlotter.AppState handle (reads .axisPrefixX / .axisPrefixY)
%
% Output
%   d       - Scaled copy of the input data struct

    % ── 1. Magnetometry unit conversion (values + labels) ─────────
    % Same helper as renderPlot so the exported file matches the
    % preview byte-for-byte.  Removed the old ~isempty(corrData)
    % gate so raw data exports correctly too.
    isMag = ismember(guiTernary(isfield(ds,'parserName'), ds.parserName, ''), ...
                {'importQDVSM','importPPMS','importMPMS','importLakeShore'});
    if isMag
        fu = guiTernary(isfield(ds,'fieldUnit'),  ds.fieldUnit,  'Oe');
        mu = guiTernary(isfield(ds,'momentUnit'), ds.momentUnit, 'emu');
        if ~strcmp(fu, 'Oe') || ~strcmp(mu, 'emu')
            sampleMass = guiTernary(isfield(ds,'sampleMass'), ds.sampleMass, 0);
            sampleVol  = computeSampleVolumeForExport(ds);

            % ── Field / x-axis ──
            xU = '';
            if isfield(d,'metadata') && isfield(d.metadata,'xColumnUnit')
                xU = char(d.metadata.xColumnUnit);
            end
            if strcmpi(xU, 'Oe') && ~strcmp(fu, 'Oe') && isnumeric(d.time)
                [xNew, ~, xuNew, ~, wX] = utilities.convertMagUnits( ...
                    d.time(:), zeros(numel(d.time),1), ...
                    'FromField', 'Oe', 'ToField', fu);
                if isempty(wX)
                    d.time = reshape(xNew, size(d.time));
                    d.metadata.xColumnUnit = xuNew;
                end
            end

            % ── Moment / y-columns (per column) ──
            if ~strcmp(mu, 'emu') && isfield(d,'units') && iscell(d.units)
                for k = 1:numel(d.units)
                    if k > size(d.values, 2), break; end
                    if strcmpi(char(d.units{k}), 'emu')
                        [~, yNew, ~, yuNew, wY] = utilities.convertMagUnits( ...
                            zeros(size(d.values,1),1), d.values(:,k), ...
                            'FromMoment', 'emu', 'ToMoment', mu, ...
                            'SampleMass', sampleMass, 'SampleVolume', sampleVol);
                        if isempty(wY)
                            d.values(:,k) = yNew;
                            d.units{k} = yuNew;
                        else
                            % Stop trying the rest — same warning
                            break;
                        end
                    end
                end
            end
        end
    end

    % ── 2. SI prefix scaling (matches preview axes) ────────────────
    pfX = appData.axisPrefixX;
    pfY = appData.axisPrefixY;
    if pfX.factor ~= 1 && ~isdatetime(d.time)
        d.time = d.time * pfX.factor;
        % Prepend prefix symbol to x-axis unit
        if isfield(d, 'metadata') && isfield(d.metadata, 'xColumnUnit')
            d.metadata.xColumnUnit = [pfX.symbol, d.metadata.xColumnUnit];
        end
    end
    if pfY.factor ~= 1
        d.values = d.values * pfY.factor;
        % Prepend prefix symbol to all y-channel units
        for k = 1:numel(d.units)
            d.units{k} = [pfY.symbol, d.units{k}];
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers
% ════════════════════════════════════════════════════════════════════════

function v = computeSampleVolumeForExport(ds)
%COMPUTESAMPLEVOLUMEFOREXPORT  Sample volume in cm³ from stored dimensions.
%   Mirror of the helper inside +bosonPlotter/renderPlot.m so the export
%   path and the live preview path agree on volume calculation.  Returns
%   0 when any dimension is missing — caller treats this as "volume
%   unavailable" and skips the conversion with a warning.
    v = 0;
    w = guiTernary(isfield(ds,'sampleWidth')  && isnumeric(ds.sampleWidth),  double(ds.sampleWidth),  0);
    h = guiTernary(isfield(ds,'sampleHeight') && isnumeric(ds.sampleHeight), double(ds.sampleHeight), 0);
    t = guiTernary(isfield(ds,'sampleThick')  && isnumeric(ds.sampleThick),  double(ds.sampleThick),  0);
    if w <= 0 || h <= 0 || t <= 0, return; end

    dimU = '';
    if isfield(ds,'dimUnit'), dimU = char(ds.dimUnit); end
    switch lower(dimU)
        case 'mm', dimToCm = 0.1;
        case 'cm', dimToCm = 1.0;
        otherwise, dimToCm = 0.1;
    end

    thkU = '';
    if isfield(ds,'thickUnit'), thkU = char(ds.thickUnit); end
    switch lower(thkU)
        case 'nm',                   thkToCm = 1e-7;
        case {char(197), 'a', 'ang'}, thkToCm = 1e-8;   % Å
        otherwise,                   thkToCm = 1e-7;
    end

    v = (w * dimToCm) * (h * dimToCm) * (t * thkToCm);
end

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end
