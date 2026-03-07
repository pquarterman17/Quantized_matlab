function data = importNCNRDat(filepath, options)
%IMPORTNCNRDAT Import NCNR reflectometry .dat files (refl1d fitting output).
%
%   data = importNCNRDat('fit_result.datA')
%   data = importNCNRDat('fit_result.datB')
%   data = importNCNRDat('fit_result.datC')
%   data = importNCNRDat('fit_result.datD')
%
%   Reads neutron reflectivity fitting results from refl1d in space-delimited
%   format. Extracts polarization state from file extension:
%
%   EXTENSION MAPPING:
%     .datA  → R++ (up-up, non-spin-flip)
%     .datB  → R+- (up-down, spin-flip)
%     .datC  → R-+ (down-up, spin-flip)
%     .datD  → R-- (down-down, non-spin-flip)
%
%   FILE FORMAT:
%     # intensity: <float>
%     # background: <float>
%     #           Q (1/A)             dQ (1/A)                    R                   dR               theory              fresnel
%     [space-delimited data rows]
%
%   OUTPUT:
%       data - Unified data struct with fields:
%           .time    - Q values [Nx1]
%           .values  - [NxM] array [dQ, R, dR, theory, fresnel]
%           .labels  - {'Q', 'dQ', 'R', 'dR', 'theory', 'fresnel'}
%           .units   - {'1/A', '1/A', '', '', '', ''}
%           .metadata - Contains polarization, intensity, background
%
%   See also IMPORTAUTO, CREATEDATASTRUCT, IMPORTNCNRREFL, IMPORTNCNRPNR

    arguments
        filepath (1,1) string {mustBeFile}
        options.Verbose (1,1) logical = false
    end

    % ════════════════════════════════════════════════════════════════
    %  Determine polarization from file extension (e.g., .datA, .datB, etc.)
    % ════════════════════════════════════════════════════════════════
    % Use lower-case filename to check extension (fileparts may not split correctly)
    filepathStr = string(filepath);

    polarization = '';
    if endsWith(filepathStr, '.datA', 'IgnoreCase', true)
        polarization = '++';
    elseif endsWith(filepathStr, '.datB', 'IgnoreCase', true)
        polarization = '+-';
    elseif endsWith(filepathStr, '.datC', 'IgnoreCase', true)
        polarization = '-+';
    elseif endsWith(filepathStr, '.datD', 'IgnoreCase', true)
        polarization = '--';
    else
        error('parser:importNCNRDat:badExtension', ...
            'File must have extension .datA, .datB, .datC, or .datD; got: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  Read file and parse header
    % ════════════════════════════════════════════════════════════════
    fid = fopen(filepath, 'r');
    try
        lines = {};
        while true
            line = fgetl(fid);
            if ~ischar(line)
                break;
            end
            lines{end+1} = line;
        end
    finally
        fclose(fid);
    end

    if isempty(lines)
        error('parser:importNCNRDat:emptyFile', ...
            'File is empty: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  Parse metadata from first few lines
    % ════════════════════════════════════════════════════════════════
    intensity = NaN;
    background = NaN;
    dataStartIdx = 1;

    for i = 1:min(5, numel(lines))
        line = lines{i};
        if startsWith(line, '# intensity:')
            intensityStr = extractAfter(line, '# intensity:');
            intensity = str2double(strtrim(intensityStr));
        elseif startsWith(line, '# background:')
            backgroundStr = extractAfter(line, '# background:');
            background = str2double(strtrim(backgroundStr));
        elseif startsWith(line, '#') && contains(line, 'Q (1/A)')
            % This is the header line — data starts next
            dataStartIdx = i + 1;
            break;
        elseif ~startsWith(line, '#')
            % Non-comment line means we're at data
            dataStartIdx = i;
            break;
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  Parse data rows
    % ════════════════════════════════════════════════════════════════
    dataLines = lines(dataStartIdx:end);
    dataArray = [];

    for i = 1:numel(dataLines)
        line = dataLines{i};
        if isempty(strtrim(line)) || startsWith(strtrim(line), '#')
            continue;
        end
        tokens = str2double(strsplit(strtrim(line)));
        % Filter out NaN tokens
        tokens(isnan(tokens)) = [];
        if isempty(tokens), continue; end
        % Guard: skip rows with inconsistent column count
        if ~isempty(dataArray) && numel(tokens) ~= size(dataArray, 2)
            continue;
        end
        dataArray = [dataArray; tokens];
    end

    if isempty(dataArray)
        error('parser:importNCNRDat:noData', ...
            'No numeric data found in file: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  Extract columns: Q is col 1, then [dQ, R, dR, theory, fresnel]
    % ════════════════════════════════════════════════════════════════
    Q = dataArray(:, 1);

    % Extract remaining columns in order
    nCols = size(dataArray, 2);
    if nCols < 6
        % Handle case with fewer columns (e.g., no theory/fresnel)
        valueData = dataArray(:, 2:end);
    else
        % Standard 6 columns: Q, dQ, R, dR, theory, fresnel
        valueData = dataArray(:, 2:nCols);
    end

    % ════════════════════════════════════════════════════════════════
    %  Build output
    % ════════════════════════════════════════════════════════════════
    nVal = size(valueData, 2);
    defaultLabels = {'dQ', 'R', 'dR', 'theory', 'fresnel'};
    defaultUnits  = {'1/A', '', '', '', ''};
    if nVal <= numel(defaultLabels)
        labels = defaultLabels(1:nVal);
        units  = defaultUnits(1:nVal);
    else
        % More columns than expected — extend with generic names
        labels = defaultLabels;
        units  = defaultUnits;
        for ei = numel(defaultLabels)+1:nVal
            labels{ei} = sprintf('col%d', ei);
            units{ei}  = '';
        end
    end

    metadata.source        = char(filepath);
    metadata.importDate    = datetime('now');
    metadata.parserName    = 'importNCNRDat';
    metadata.parserVersion = '1.0';
    metadata.xColumnName = 'Q';
    metadata.xColumnUnit = '1/Ang';
    metadata.parserSpecific.dataSource = 'refl1d fitting';
    metadata.parserSpecific.instrument = 'NCNR reflectometer';
    metadata.parserSpecific.polarization = polarization;

    if ~isnan(intensity)
        metadata.parserSpecific.intensity = intensity;
    end
    if ~isnan(background)
        metadata.parserSpecific.background = background;
    end

    % Call createDataStruct with Q (time), values, labels, units, metadata
    % Note: Q is stored in .time, not .values, so labels should not include Q
    data = parser.createDataStruct(Q, valueData, ...
        'labels', labels, ...
        'units', units, ...
        'metadata', metadata);
end
