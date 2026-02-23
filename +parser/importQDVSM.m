function data = importQDVSM(filepath, options)
%IMPORTQDVSM Import a Quantum Design VSM/PPMS .dat file.
%
%   data = importQDVSM('EDP124_Perp_StrawNew.dat')
%   data = importQDVSM(file, 'TimeColumn', 'Magnetic Field')
%   data = importQDVSM(file, 'DataColumns', {'Moment','Temperature'})
%   data = importQDVSM(file, 'XAxis', 'field', 'YAxis', 'moment')
%
%   Reads Quantum Design DynaCool / PPMS / MPMS VSM data files that use
%   the standard [Header] / [Data] format. Extracts all instrument
%   metadata, column names, units, and numeric data into a unified data
%   struct compatible with all toolbox plotting functions.
%
%   FILE FORMAT EXPECTED:
%     [Header]
%     ; comment lines
%     KEY,VALUE,...
%     INFO,value,tag
%     [Data]
%     ColName1,ColName2 (unit),...
%     datarow1
%     datarow2
%     ...
%
%   INPUTS:
%       filepath - Path to the .dat file.
%
%   OPTIONAL NAME-VALUE PAIRS:
%       TimeColumn  - Column for the x-axis / independent variable.
%                     Accepts column index, exact name, or shorthand:
%                       'field'  → 'Magnetic Field'
%                       'temp'   → 'Temperature'
%                       'time'   → 'Time Stamp'
%                     Default: 'field' (Magnetic Field).
%       DataColumns - Columns for the y-axis / dependent variable(s).
%                     Accepts indices, exact names, cell array, or
%                     shorthand:
%                       'moment'  → 'Moment'
%                       'stderr'  → 'M. Std. Err.'
%                       'all'     → all numeric columns except x-axis
%                     Default: 'moment'.
%       XAxis       - Alias for TimeColumn (for readability).
%       YAxis       - Alias for DataColumns (for readability).
%       IncludeRaw  - Also import raw moment columns (default: false).
%       Verbose     - Print import summary (default: true).
%
%   OUTPUT:
%       data - Unified data struct with fields:
%                time     - [Nx1] x-axis values (e.g. field in Oe)
%                values   - [NxM] data matrix
%                labels   - {1xM} channel names
%                units    - {1xM} unit strings
%                metadata - struct with all [Header] info plus:
%                             .source, .importDate
%                             .title, .fileOpenTime, .app
%                             .instrument (all INFO fields)
%                             .allColumnNames, .allColumnUnits
%                             .startupAxisX, .startupAxisY
%
%   EXAMPLES:
%       % M vs H hysteresis loop (default)
%       data = importQDVSM('EDP124_Perp_StrawNew.dat');
%       plotTimeSeries(data, 'xlabel', 'Magnetic Field (Oe)', ...
%                            'ylabel', 'Moment (emu)');
%
%       % Moment and temperature vs time
%       data = importQDVSM('myfile.dat', ...
%           'XAxis', 'time', ...
%           'YAxis', {'moment', 'temp'});
%
%       % All numeric channels vs field
%       data = importQDVSM('myfile.dat', 'YAxis', 'all');
%
%       % By exact column name
%       data = importQDVSM('myfile.dat', ...
%           'TimeColumn', 'Temperature', ...
%           'DataColumns', {'Moment', 'M. Std. Err.'});
%
%   See also CREATEDATASTRUCT, VALIDATEDATA, IMPORTCSV, PLOTTIMESERIES

    arguments
        filepath          (1,1) string {mustBeFile}
        options.TimeColumn       = ''
        options.DataColumns      = ''
        options.XAxis            = ''
        options.YAxis            = ''
        options.IncludeRaw (1,1) logical = false
        options.Verbose    (1,1) logical = true
    end

    % Handle XAxis/YAxis aliases
    xSpec = options.TimeColumn;
    ySpec = options.DataColumns;
    if ~isempty(char(options.XAxis))
        xSpec = options.XAxis;
    end
    if ~isempty(char(options.YAxis)) && ~(iscell(options.YAxis) && isempty(options.YAxis))
        ySpec = options.YAxis;
    end
    % Defaults
    if isempty(char(xSpec)),  xSpec = 'field';  end
    if ischar(ySpec) && isempty(ySpec), ySpec = 'moment'; end

    % ════════════════════════════════════════════════════════════════
    %  STEP 1: Read entire file
    % ════════════════════════════════════════════════════════════════
    fid = fopen(filepath, 'r');
    if fid == -1
        error('importQDVSM:cannotOpen', 'Cannot open file: %s', filepath);
    end
    cleanObj = onCleanup(@() fclose(fid));

    rawLines = {};
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line)
            rawLines{end+1} = line; %#ok<AGROW>
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 2: Parse [Header] and locate [Data]
    % ════════════════════════════════════════════════════════════════
    headerInfo = struct();
    headerInfo.instrument = struct();
    dataStartLine = 0;

    inHeader = false;
    for i = 1:numel(rawLines)
        line = strtrim(rawLines{i});

        % Section markers
        if strcmpi(line, '[Header]')
            inHeader = true;
            continue;
        elseif strcmpi(line, '[Data]')
            inHeader = false;
            dataStartLine = i + 1;   % next line is column headers
            break;
        end

        if ~inHeader, continue; end

        % Skip comment lines
        if startsWith(line, ';'), continue; end

        % Parse key-value lines
        parts = strsplit(line, ',', 'CollapseDelimiters', false);
        if numel(parts) < 2, continue; end

        key = strtrim(parts{1});
        switch upper(key)
            case 'TITLE'
                headerInfo.title = strtrim(strjoin(parts(2:end), ','));
            case 'FILEOPENTIME'
                headerInfo.fileOpenTime = strtrim(strjoin(parts(2:end), ','));
                if numel(parts) >= 4
                    headerInfo.fileOpenDate = strtrim(parts{3});
                    headerInfo.fileOpenTimeStr = strtrim(parts{4});
                end
            case 'BYAPP'
                headerInfo.app = strtrim(strjoin(parts(2:end), ','));
            case 'INFO'
                val = strtrim(parts{2});
                if numel(parts) >= 3
                    tag = strtrim(parts{3});
                    % Make valid field name
                    fieldName = matlab.lang.makeValidName(tag);
                    headerInfo.instrument.(fieldName) = val;
                end
            case 'DATATYPE'
                if ~isfield(headerInfo, 'dataTypes')
                    headerInfo.dataTypes = {};
                end
                headerInfo.dataTypes{end+1} = strtrim(strjoin(parts(2:end), ','));
            case 'STARTUPAXIS'
                if numel(parts) >= 3
                    axName = strtrim(parts{2});
                    axCol  = str2double(parts{3});
                    if strcmpi(axName, 'X')
                        headerInfo.startupAxisX = axCol;
                    else
                        headerInfo.startupAxisY = axCol;
                    end
                end
        end
    end

    if dataStartLine == 0
        error('importQDVSM:noData', ...
            '[Data] section not found in file: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 3: Parse column header row
    % ════════════════════════════════════════════════════════════════
    colHeaderLine = rawLines{dataStartLine};
    rawColNames = strsplit(colHeaderLine, ',', 'CollapseDelimiters', false);
    rawColNames = strtrim(rawColNames);
    numCols = numel(rawColNames);

    % Extract names and units from "Name (unit)" pattern
    colNames = cell(1, numCols);
    colUnits = cell(1, numCols);
    for c = 1:numCols
        [colNames{c}, colUnits{c}] = parseColumnHeader(rawColNames{c});
    end

    headerInfo.allColumnNames = colNames;
    headerInfo.allColumnUnits = colUnits;

    % ════════════════════════════════════════════════════════════════
    %  STEP 4: Parse data rows
    % ════════════════════════════════════════════════════════════════
    dataLines = rawLines(dataStartLine+1 : end);
    numRows = numel(dataLines);

    rawMatrix = NaN(numRows, numCols);
    validRows = true(numRows, 1);

    for r = 1:numRows
        line = dataLines{r};
        if isempty(strtrim(line))
            validRows(r) = false;
            continue;
        end
        parts = strsplit(line, ',', 'CollapseDelimiters', false);
        nCols = min(numel(parts), numCols);
        for c = 1:nCols
            val = strtrim(parts{c});
            if ~isempty(val)
                num = str2double(val);
                rawMatrix(r, c) = num;  % NaN if non-numeric
            end
        end
    end

    % Remove completely empty rows
    rawMatrix = rawMatrix(validRows, :);
    numRows = size(rawMatrix, 1);

    if numRows == 0
        error('importQDVSM:noRows', 'No valid data rows in file: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 5: Resolve x-axis column
    % ════════════════════════════════════════════════════════════════
    xColIdx = resolveQDColumn(xSpec, colNames, 'x-axis');

    % ════════════════════════════════════════════════════════════════
    %  STEP 6: Resolve y-axis / data columns
    % ════════════════════════════════════════════════════════════════
    if ischar(ySpec) || isstring(ySpec)
        ySpec = {char(ySpec)};
    end

    if numel(ySpec) == 1 && strcmpi(ySpec{1}, 'all')
        % All numeric columns except x and the Comment column
        yColIdx = [];
        for c = 1:numCols
            if c == xColIdx, continue; end
            if strcmpi(colNames{c}, 'Comment'), continue; end
            if any(startsWith(colNames{c}, 'Map')), continue; end
            frac = sum(~isnan(rawMatrix(:,c))) / numRows;
            if frac > 0.5
                yColIdx(end+1) = c; %#ok<AGROW>
            end
        end
        % Optionally exclude raw columns
        if ~options.IncludeRaw
            rawCols = contains(colNames, 'Raw') | contains(colNames, 'Quad');
            yColIdx = yColIdx(~rawCols(yColIdx));
        end
    else
        yColIdx = zeros(1, numel(ySpec));
        for k = 1:numel(ySpec)
            yColIdx(k) = resolveQDColumn(ySpec{k}, colNames, 'y-axis');
        end
    end

    if isempty(yColIdx)
        error('importQDVSM:noYCols', 'No valid data columns resolved.');
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 7: Extract vectors and build struct
    % ════════════════════════════════════════════════════════════════
    timeVec = rawMatrix(:, xColIdx);
    valuesMatrix = rawMatrix(:, yColIdx);

    labels = colNames(yColIdx);
    units  = colUnits(yColIdx);

    % Build metadata
    meta = headerInfo;
    meta.source     = char(filepath);
    meta.importDate = datetime('now');
    meta.xColumnName = colNames{xColIdx};
    meta.xColumnUnit = colUnits{xColIdx};
    meta.xColumnIndex = xColIdx;
    meta.yColumnIndices = yColIdx;

    data = parser.createDataStruct(timeVec, valuesMatrix, ...
        'labels', labels, 'units', units, 'metadata', meta);

    % ════════════════════════════════════════════════════════════════
    %  STEP 8: Print summary
    % ════════════════════════════════════════════════════════════════
    if options.Verbose
        fprintf('\n');
        fprintf('═══ Quantum Design VSM Import ═══════════════════════\n');
        fprintf('  File:       %s\n', filepath);
        if isfield(headerInfo, 'fileOpenDate')
            fprintf('  Date:       %s %s\n', ...
                headerInfo.fileOpenDate, headerInfo.fileOpenTimeStr);
        end
        if isfield(headerInfo, 'app')
            fprintf('  App:        %s\n', headerInfo.app);
        end
        if isfield(headerInfo.instrument, 'APPNAME')
            fprintf('  Instrument: %s\n', headerInfo.instrument.APPNAME);
        end
        fprintf('  Rows:       %d\n', numRows);
        fprintf('  X-axis:     %s', colNames{xColIdx});
        if ~isempty(colUnits{xColIdx})
            fprintf(' (%s)', colUnits{xColIdx});
        end
        fprintf('\n');
        fprintf('  Y-axis:     ');
        for k = 1:numel(yColIdx)
            if k > 1, fprintf('              '); end
            fprintf('%s', labels{k});
            if ~isempty(units{k})
                fprintf(' (%s)', units{k});
            end
            fprintf('\n');
        end
        fprintf('═════════════════════════════════════════════════════\n\n');
    end
end


% ════════════════════════════════════════════════════════════════════
%  LOCAL HELPER FUNCTIONS
% ════════════════════════════════════════════════════════════════════

function [name, unit] = parseColumnHeader(raw)
%PARSECOLUMNHEADER Split "Magnetic Field (Oe)" → name, unit
    unit = '';
    name = strtrim(raw);
    if isempty(name), return; end

    % Match "Name (unit)" pattern
    tok = regexp(name, '^(.+?)\s*\(([^)]+)\)\s*$', 'tokens', 'once');
    if ~isempty(tok)
        name = strtrim(tok{1});
        unit = strtrim(tok{2});
    end
end


function idx = resolveQDColumn(spec, colNames, label)
%RESOLVEQDCOLUMN Resolve a column spec to an index using shorthands.

    % Handle numeric index
    if isnumeric(spec)
        if spec < 1 || spec > numel(colNames)
            error('importQDVSM:badIndex', ...
                '%s column index %d is out of range (1-%d).', ...
                label, spec, numel(colNames));
        end
        idx = spec;
        return;
    end

    spec = char(spec);

    % ── Shorthands ───────────────────────────────────────────────
    shorthandMap = {
        'field',      'Magnetic Field'
        'moment',     'Moment'
        'temp',       'Temperature'
        'temperature','Temperature'
        'time',       'Time Stamp'
        'stderr',     'M. Std. Err.'
        'mass',       'Mass'
        'pressure',   'Pressure'
        'frequency',  'Frequency'
        'amplitude',  'Peak Amplitude'
        'range',      'Range'
        'motorcurrent','Motor Current'
        'coilsignal', 'Coil Signal'
    };

    resolvedName = spec;
    for k = 1:size(shorthandMap, 1)
        if strcmpi(spec, shorthandMap{k, 1})
            resolvedName = shorthandMap{k, 2};
            break;
        end
    end

    % ── Exact match ──────────────────────────────────────────────
    idx = find(strcmpi(colNames, resolvedName), 1);
    if ~isempty(idx), return; end

    % ── Partial match (contains) ─────────────────────────────────
    matches = find(contains(colNames, resolvedName, 'IgnoreCase', true));
    if numel(matches) == 1
        idx = matches;
        return;
    elseif numel(matches) > 1
        % Prefer shortest match (most specific)
        lens = cellfun(@numel, colNames(matches));
        [~, best] = min(lens);
        idx = matches(best);
        return;
    end

    % ── Failed ───────────────────────────────────────────────────
    % Build helpful error message
    validNames = colNames(~cellfun('isempty', colNames));
    error('importQDVSM:columnNotFound', ...
        'Cannot resolve %s column "%s".\nAvailable columns:\n  %s\n\nShorthands: field, moment, temp, time, stderr, mass, pressure', ...
        label, spec, strjoin(validNames, '\n  '));
end