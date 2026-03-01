function data = importNCNRRefl(filepath, options)
%IMPORTNCNRREFL Import NCNR reflectometry .refl files (reductus output).
%
%   data = importNCNRRefl('sample_CANDOR.refl')
%   data = importNCNRRefl('sample_PBR.refl')
%
%   Reads neutron reflectivity data in NCNR reductus format: space-delimited
%   with JSON headers. Supports both monochromatic PBR and polychromatic
%   CANDOR variants.
%
%   FILE FORMAT:
%     # "name": "Sample Name"
%     # "polarization": ""
%     # "wavelength": [5.9, 5.8, ...]  or  5.9
%     # "wavelength_resolution": [0.05, ...]
%     # "columns": ["Qz", "Intensity", "uncertainty", "resolution"]
%     # "units": ["1/Ang", "counts", "counts", "1/Ang"]
%     [space-delimited data rows]
%
%   OUTPUT:
%       data - Unified data struct with fields:
%           .time    - Qz values [Nx1]
%           .values  - [NxM] array [I, dI, dQ] or subset
%           .labels  - {'Qz', 'Intensity', 'dI', 'dQ'}
%           .units   - {'1/Ang', 'counts', 'counts', '1/Ang'}
%           .metadata - struct with parserSpecific.polarization, etc.
%
%   See also IMPORTAUTO, CREATEDATASTRUCT, IMPORTNCNRPNR, IMPORTNCNRDAT

    arguments
        filepath (1,1) string {mustBeFile}
        options.Verbose (1,1) logical = false
    end

    % ════════════════════════════════════════════════════════════════
    %  Read file and parse header
    % ════════════════════════════════════════════════════════════════
    fid = fopen(filepath, 'r');
    try
        % Read all lines
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
        error('parser:importNCNRRefl:emptyFile', ...
            'File is empty: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  Parse headers (lines starting with #)
    % ════════════════════════════════════════════════════════════════
    name = '';
    polarization = '';
    wavelength = [];
    wavelength_resolution = [];
    columns = {};
    units = {};
    dataStartIdx = 1;

    for i = 1:numel(lines)
        line = lines{i};
        if startsWith(line, '#')
            % Extract key and value from # "key": value format
            % First, check if it's the JSON-style format or simple format
            if contains(line, '"') && contains(line, ':')
                % Try to parse as JSON-style header
                match = regexp(line, '# "([^"]+)": (.+)$', 'tokens');
                if ~isempty(match)
                    key = match{1}{1};
                    valStr = match{1}{2};

                    % Parse value based on key
                    switch key
                        case 'name'
                            name = extractJsonString(valStr);
                        case 'polarization'
                            polarization = extractJsonString(valStr);
                        case 'wavelength'
                            wavelength = parseJsonArray(valStr);
                        case 'wavelength_resolution'
                            wavelength_resolution = parseJsonArray(valStr);
                        case 'columns'
                            columns = parseJsonStringArray(valStr);
                        case 'units'
                            units = parseJsonStringArray(valStr);
                    end
                end
            end
        else
            % First non-comment line is start of data
            dataStartIdx = i;
            break;
        end
    end

    if isempty(columns)
        error('parser:importNCNRRefl:noColumns', ...
            'Could not find columns header in file: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  Parse data
    % ════════════════════════════════════════════════════════════════
    dataLines = lines(dataStartIdx:end);
    dataArray = [];

    for i = 1:numel(dataLines)
        line = dataLines{i};
        if isempty(strtrim(line))
            continue;
        end
        tokens = str2double(strsplit(strtrim(line)));
        if ~any(isnan(tokens))
            dataArray = [dataArray; tokens];
        end
    end

    if isempty(dataArray)
        error('parser:importNCNRRefl:noData', ...
            'No numeric data found in file: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  Extract columns: Qz is always first, then [I, dI, dQ]
    % ════════════════════════════════════════════════════════════════
    Qz = dataArray(:, 1);

    % Build values matrix: [I, dI, dQ] in order from columns
    % Supported column names: Intensity, uncertainty (=dI), resolution (=dQ)
    valueLabels = {};
    valueUnits = {};
    values = [];

    for j = 2:numel(columns)
        colName = columns{j};
        colUnit = '';
        if j <= numel(units)
            colUnit = units{j};
        end

        valueLabels{end+1} = colName;
        valueUnits{end+1} = colUnit;
        values = [values, dataArray(:, j)];
    end

    % ════════════════════════════════════════════════════════════════
    %  Build output
    % ════════════════════════════════════════════════════════════════
    % Note: Qz is stored in .time, not .values, so labels should not include it
    outLabels = valueLabels;
    outUnits = valueUnits;

    % Store metadata
    metadata.filename = filepath;
    metadata.source = 'NCNR reductus';
    metadata.xColumnName = 'Qz';
    metadata.importDate = datetime('now');
    metadata.parserName = 'importNCNRRefl';
    metadata.parserSpecific.instrument = 'NCNR reflectometer';
    metadata.parserSpecific.name = name;

    % Detect CANDOR vs PBR by checking if wavelength is an array
    if ~isempty(wavelength) && isscalar(wavelength)
        metadata.parserSpecific.instrument_type = 'PBR (monochromatic)';
        metadata.parserSpecific.wavelength = wavelength;
    else
        metadata.parserSpecific.instrument_type = 'CANDOR (polychromatic)';
        metadata.parserSpecific.wavelengths = wavelength;
    end

    if ~isempty(polarization)
        metadata.parserSpecific.polarization = polarization;
    end

    % Call createDataStruct with time (Qz), values, labels, units, metadata
    data = parser.createDataStruct(Qz, values, ...
        'labels', outLabels, ...
        'units', outUnits, ...
        'metadata', metadata);
end


% ────────────────────────────────────────────────────────────────────
% HELPER FUNCTIONS
% ────────────────────────────────────────────────────────────────────

function str = extractJsonString(jsonStr)
%EXTRACTJSONSTRING  Extract a JSON string value (remove quotes).
    jsonStr = strtrim(jsonStr);
    if startsWith(jsonStr, '"') && endsWith(jsonStr, '"')
        str = jsonStr(2:end-1);
    else
        str = jsonStr;
    end
end


function arr = parseJsonArray(jsonStr)
%PARSEJSONARRAY  Parse a JSON array [1.0, 2.0, ...] to double vector.
    jsonStr = strtrim(jsonStr);
    if startsWith(jsonStr, '[') && endsWith(jsonStr, ']')
        jsonStr = jsonStr(2:end-1);
    end
    % Split by comma and convert to double
    parts = strsplit(jsonStr, ',');
    arr = [];
    for i = 1:numel(parts)
        val = str2double(strtrim(parts{i}));
        if ~isnan(val)
            arr = [arr, val];
        end
    end
    arr = arr(:);  % Column vector
end


function strArr = parseJsonStringArray(jsonStr)
%PARSEJSONSTRINGARRAY  Parse JSON string array ["a", "b", ...].
    jsonStr = strtrim(jsonStr);
    if startsWith(jsonStr, '[') && endsWith(jsonStr, ']')
        jsonStr = jsonStr(2:end-1);
    end
    % Split by comma and clean up quotes
    parts = strsplit(jsonStr, ',');
    strArr = {};
    for i = 1:numel(parts)
        s = strtrim(parts{i});
        % Remove quotes if present
        if startsWith(s, '"') && endsWith(s, '"')
            s = s(2:end-1);
        end
        strArr{i} = s;
    end
end
