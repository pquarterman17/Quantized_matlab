function data = importRefl1dDat(filepath, options)
%IMPORTREFL1DDAT Import refl1d fitting output .dat files.
%
%   data = importRefl1dDat('sample-refl.dat')
%   data = importRefl1dDat('sample-profile.dat')
%
%   Reads refl1d output files (reflectivity, SLD profile, slabs, steps).
%   These are space-delimited with #-prefixed comment headers containing
%   column names and optional key-value metadata.
%
%   SUPPORTED VARIANTS:
%     -refl.dat    : Q, dQ, R, dR, theory, fresnel
%     -profile.dat : z, rho, irho [, rhoM, theta]
%     -slabs.dat   : thickness, interface, rho, irho [, rhoM, theta]
%     -steps.dat   : z, rho, irho [, rhoM, theta]
%
%   See also IMPORTAUTO, CREATEDATASTRUCT, IMPORTNCNRREFL

    arguments
        filepath (1,1) string {mustBeFile}
        options.Verbose (1,1) logical = false
    end

    % ════════════════════════════════════════════════════════════════
    %  Read file
    % ════════════════════════════════════════════════════════════════
    fid = fopen(filepath, 'r');
    if fid == -1
        error('parser:importRefl1dDat:openFail', ...
            'Cannot open file: %s', filepath);
    end
    cleanObj = onCleanup(@() fclose(fid));

    lines = {};
    while true
        ln = fgetl(fid);
        if ~ischar(ln), break; end
        lines{end+1} = ln; %#ok<AGROW>
    end

    if isempty(lines)
        error('parser:importRefl1dDat:emptyFile', ...
            'File is empty: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  Parse headers: extract column names and key-value metadata
    % ════════════════════════════════════════════════════════════════
    headerMeta = struct();
    columnLine = '';
    dataStartIdx = 1;

    for i = 1:numel(lines)
        ln = lines{i};
        stripped = strtrim(ln);
        if ~startsWith(stripped, '#')
            dataStartIdx = i;
            break;
        end
        content = strtrim(stripped(2:end));
        if isempty(content), continue; end

        kvMatch = regexp(content, '^(\w[\w\s]*\w|\w+):\s*(.+)$', 'tokens');
        if ~isempty(kvMatch)
            key = matlab.lang.makeValidName(kvMatch{1}{1});
            val = str2double(kvMatch{1}{2});
            if ~isnan(val)
                headerMeta.(key) = val;
            else
                headerMeta.(key) = kvMatch{1}{2};
            end
        else
            columnLine = content;
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  Parse column names and units from the column header line
    % ════════════════════════════════════════════════════════════════
    colLabels = {};
    colUnits  = {};
    if ~isempty(columnLine)
        colTokens = regexp(columnLine, '(\S+(?:\s*\([^)]*\))?)', 'match');
        for k = 1:numel(colTokens)
            tok = strtrim(colTokens{k});
            unitMatch = regexp(tok, '^(.+?)\s*\(([^)]+)\)$', 'tokens');
            if ~isempty(unitMatch)
                colLabels{end+1} = unitMatch{1}{1}; %#ok<AGROW>
                colUnits{end+1}  = unitMatch{1}{2}; %#ok<AGROW>
            else
                colLabels{end+1} = tok; %#ok<AGROW>
                colUnits{end+1}  = ''; %#ok<AGROW>
            end
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  Parse numeric data
    % ════════════════════════════════════════════════════════════════
    dataRows = [];
    for i = dataStartIdx:numel(lines)
        ln = strtrim(lines{i});
        if isempty(ln) || startsWith(ln, '#')
            continue;
        end
        vals = str2double(strsplit(ln));
        if ~any(isnan(vals))
            dataRows = [dataRows; vals]; %#ok<AGROW>
        end
    end

    if isempty(dataRows)
        error('parser:importRefl1dDat:noData', ...
            'No numeric data found in file: %s', filepath);
    end

    nCols = size(dataRows, 2);
    if isempty(colLabels)
        colLabels = arrayfun(@(j) sprintf('Col%d', j), 1:nCols, ...
            'UniformOutput', false);
        colUnits = repmat({''}, 1, nCols);
    end

    % ════════════════════════════════════════════════════════════════
    %  Detect variant and assign x-axis
    % ════════════════════════════════════════════════════════════════
    variant = detectVariant(filepath, colLabels);

    xCol = dataRows(:, 1);
    xLabel = colLabels{1};
    xUnit  = colUnits{1};

    yLabels = colLabels(2:min(nCols, numel(colLabels)));
    yUnits  = colUnits(2:min(nCols, numel(colUnits)));
    yValues = dataRows(:, 2:end);

    % ════════════════════════════════════════════════════════════════
    %  Build output
    % ════════════════════════════════════════════════════════════════
    metadata.source        = char(filepath);
    metadata.importDate    = datetime('now');
    metadata.parserName    = 'importRefl1dDat';
    metadata.parserVersion = '1.0';
    metadata.xColumnName   = xLabel;
    metadata.xColumnUnit   = xUnit;
    metadata.parserSpecific.dataSource = 'refl1d';
    metadata.parserSpecific.variant    = variant;
    flds = fieldnames(headerMeta);
    for k = 1:numel(flds)
        metadata.parserSpecific.(flds{k}) = headerMeta.(flds{k});
    end

    data = parser.createDataStruct(xCol, yValues, ...
        'labels', yLabels, ...
        'units', yUnits, ...
        'metadata', metadata);

    if options.Verbose
        fprintf('importRefl1dDat: %d rows, variant=%s\n', ...
            size(yValues, 1), variant);
    end
end


% ────────────────────────────────────────────────────────────────────
function variant = detectVariant(filepath, colLabels)
    [~, fname] = fileparts(filepath);
    fname = lower(fname);
    if endsWith(fname, '-refl') || endsWith(fname, '-refl-fix')
        variant = 'reflectivity';
    elseif endsWith(fname, '-profile') || endsWith(fname, '-profile-edit')
        variant = 'profile';
    elseif endsWith(fname, '-slabs')
        variant = 'slabs';
    elseif endsWith(fname, '-steps')
        variant = 'steps';
    elseif any(strcmpi(colLabels, 'R')) || any(strcmpi(colLabels, 'theory'))
        variant = 'reflectivity';
    elseif any(strcmpi(colLabels, 'rho')) || any(strcmpi(colLabels, 'z'))
        variant = 'profile';
    else
        variant = 'unknown';
    end
end
