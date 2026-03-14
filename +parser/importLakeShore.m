function data = importLakeShore(filepath, options)
%IMPORTLAKESHORE Import a Lake Shore VSM / magnetometer .csv or .dat file.
%
%   Syntax
%   ──────
%   data = parser.importLakeShore(filepath)
%   data = parser.importLakeShore(filepath, Name=Value)
%
%   Inputs
%   ──────
%   filepath   (1,1) string   Path to the Lake Shore CSV or DAT file.
%
%   Name-Value Options
%   ──────────────────
%   HeaderRows      Number of header lines to skip before column headers
%                   (default: 'auto' — scans for first line with headers).
%                   Positive integer to skip exactly N rows.
%   XAxis           Column for x-axis (default: 'temp'). Accepts:
%                     'temp' / 'temperature' → Temperature
%                     'field'                → Magnetic Field
%                     Column index or exact name
%   YAxis           Column(s) for y-axis (default: 'moment'). Accepts:
%                     'moment' / 'magnetization' → Moment
%                     'susceptibility' / 'chi'   → Magnetic Susceptibility
%                     'all'                      → All columns except x-axis
%                     Cell array of column names/indices
%   TimeColumn      Alias for XAxis.
%   DataColumns     Alias for YAxis.
%   Verbose         Print import summary (default: false).
%
%   Outputs
%   ───────
%   data   Struct with fields:
%            .time        [Nx1]  x-axis values (temperature or field)
%            .values      [NxM]  data matrix (moments or susceptibilities)
%            .labels      {1xM}  channel names
%            .units       {1xM}  unit strings
%            .metadata    Struct with import details and header info
%
%   FILE FORMAT
%   ───────────
%   Lake Shore exports typically have:
%     1. Optional header block with instrument info and metadata
%     2. Column header row (comma-separated)
%     3. Data rows (comma-separated values)
%
%   The parser auto-detects the header block and column row. Common columns:
%     - Temperature (K) or Temp
%     - Magnetic Field (Oe) or Field
%     - Moment (emu) or Magnetization
%     - Susceptibility (cgs/g or cgs/cm³)
%
%   Examples
%   ────────
%   % Temperature-dependent magnetization (auto-detect header)
%   d = parser.importLakeShore('sample.csv', Verbose=true);
%
%   % Field-dependent at fixed temperature
%   d = parser.importLakeShore('sample.csv', XAxis='field');
%
%   % Multiple channels
%   d = parser.importLakeShore('sample.csv', YAxis={'moment', 'susceptibility'});
%
%   % Skip known number of header lines
%   d = parser.importLakeShore('sample.csv', HeaderRows=15);
%
%   See also IMPORTCSV, IMPORTPPMS, CREATEDATASTRUCT

    arguments
        filepath              (1,1) string {mustBeFile}
        options.HeaderRows           = 'auto'   % 'auto' or positive integer
        options.XAxis                = 'temp'
        options.YAxis                = 'moment'
        options.TimeColumn           = ''       % alias for XAxis
        options.DataColumns          = ''       % alias for YAxis
        options.Verbose       (1,1) logical = false
    end

    % Resolve aliases
    xSpec = options.XAxis;
    ySpec = options.YAxis;
    if ~isempty(char(options.TimeColumn))
        xSpec = options.TimeColumn;
    end
    if ~isempty(char(options.DataColumns))
        ySpec = options.DataColumns;
    end

    % ════════════════════════════════════════════════════════════════════════
    %  1. Read file
    % ════════════════════════════════════════════════════════════════════════
    fid = fopen(filepath, 'r');
    if fid == -1
        error('parser:importLakeShore:cannotOpen', ...
            'Cannot open file: %s', filepath);
    end
    cleanObj = onCleanup(@() fclose(fid));

    rawLines = {};
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line)
            rawLines{end+1} = line; %#ok<AGROW>
        end
    end

    % ════════════════════════════════════════════════════════════════════════
    %  2. Locate column header row
    % ════════════════════════════════════════════════════════════════════════
    headerRowIdx = 0; %#ok<NASGU>
    if ischar(options.HeaderRows) && strcmpi(options.HeaderRows, 'auto')
        % Auto-detect: scan for first line with comma-separated text that looks
        % like column headers (no pure numbers, contains common keywords)
        headerRowIdx = detectHeaderRow(rawLines);
        if headerRowIdx == 0
            error('parser:importLakeShore:noHeader', ...
                'Could not auto-detect column header row in file: %s', filepath);
        end
    else
        % User-specified skip rows
        headerRowIdx = double(options.HeaderRows) + 1;  % convert 0-based to 1-based
        if headerRowIdx > numel(rawLines)
            error('parser:importLakeShore:headerRowOOB', ...
                'HeaderRows (%d) exceeds file length (%d)', ...
                headerRowIdx - 1, numel(rawLines));
        end
    end

    % ════════════════════════════════════════════════════════════════════════
    %  3. Parse column headers
    % ════════════════════════════════════════════════════════════════════════
    colHeaderLine = rawLines{headerRowIdx};
    rawColNames = strsplit(colHeaderLine, ',', 'CollapseDelimiters', false);
    rawColNames = strtrim(rawColNames);
    numCols = numel(rawColNames);

    % Extract names and units from "Name (unit)" pattern
    colNames = cell(1, numCols);
    colUnits = cell(1, numCols);
    for c = 1:numCols
        [colNames{c}, colUnits{c}] = parseColumnHeader(rawColNames{c});
    end

    % ════════════════════════════════════════════════════════════════════════
    %  4. Parse data rows
    % ════════════════════════════════════════════════════════════════════════
    dataLines = rawLines(headerRowIdx + 1 : end);
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

    % Remove empty rows
    rawMatrix = rawMatrix(validRows, :);
    numRows = size(rawMatrix, 1);

    if numRows == 0
        error('parser:importLakeShore:noData', ...
            'No valid data rows in file: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════════════
    %  5. Resolve x-axis and y-axis columns
    % ════════════════════════════════════════════════════════════════════════
    xColIdx = resolveLakeShoreColumn(xSpec, colNames, 'x-axis');
    yColIndices = resolveLakeShoreColumns(ySpec, colNames, xColIdx, 'y-axis');

    if isempty(yColIndices)
        error('parser:importLakeShore:noYColumns', ...
            'No valid y-axis columns found matching: %s', char(ySpec));
    end

    % ════════════════════════════════════════════════════════════════════════
    %  6. Extract data
    % ════════════════════════════════════════════════════════════════════════
    timeVec = rawMatrix(:, xColIdx);
    valuesMatrix = rawMatrix(:, yColIndices);
    yLabels = colNames(yColIndices);
    yUnits = colUnits(yColIndices);

    % ════════════════════════════════════════════════════════════════════════
    %  7. Assemble output struct
    % ════════════════════════════════════════════════════════════════════════
    meta.source        = char(filepath);
    meta.importDate    = datetime('now');
    meta.parserName    = 'importLakeShore';
    meta.parserVersion = '1.0';
    meta.xColumnName  = colNames{xColIdx};
    meta.xColumnUnit  = colUnits{xColIdx};
    meta.parserSpecific.instrumentType = 'Lake Shore VSM/Magnetometer';
    meta.parserSpecific.allColumnNames = colNames;
    meta.parserSpecific.allColumnUnits = colUnits;

    data = parser.createDataStruct(timeVec, valuesMatrix, ...
        'labels',   yLabels, ...
        'units',    yUnits, ...
        'metadata', meta);

    % ════════════════════════════════════════════════════════════════════════
    %  8. Verbose output
    % ════════════════════════════════════════════════════════════════════════
    if options.Verbose
        printSummary(data, filepath);
    end
end


% ════════════════════════════════════════════════════════════════════════════
%  Helper functions
% ════════════════════════════════════════════════════════════════════════════

function headerIdx = detectHeaderRow(rawLines)
%DETECTHEADERROW  Scan for the first line that looks like column headers.
%   Returns the 1-based index, or 0 if not found.
%   Heuristic: line with commas, non-empty text fields, no pure-number pattern.
    headerIdx = 0;
    for i = 1:min(numel(rawLines), 100)  % scan first 100 lines max
        line = strtrim(rawLines{i});
        if isempty(line), continue; end

        % Must contain comma
        if ~contains(line, ','), continue; end

        % Split and check for text-like content
        parts = strsplit(line, ',', 'CollapseDelimiters', false);
        if numel(parts) < 2, continue; end

        % Heuristic: if most parts are text (not pure numbers), likely header row
        textCount = 0;
        for p = 1:numel(parts)
            txt = strtrim(parts{p});
            num = str2double(txt);
            if isnan(num)
                textCount = textCount + 1;
            end
        end

        % If >50% of columns are text (non-numeric), call it a header row
        if textCount / numel(parts) > 0.5
            headerIdx = i;
            return;
        end
    end
end

function [name, unit] = parseColumnHeader(headerStr)
%PARSECOLUMNHEADER  Extract name and unit from "Name (unit)" format.
%   If no unit present, returns ('Name', '').
    headerStr = strtrim(headerStr);

    % Match pattern "Name (unit)"
    pattern = '(.+?)\s*\(([^)]+)\)\s*$';
    tokens = regexp(headerStr, pattern, 'tokens', 'once');

    if ~isempty(tokens) && numel(tokens) == 2
        name = strtrim(tokens{1});
        unit = strtrim(tokens{2});
    else
        name = headerStr;
        unit = '';
    end
end

function colIdx = resolveLakeShoreColumn(spec, colNames, role)
%RESOLVELAKESHORECOLUMN  Resolve a column spec (shorthand, name, or index).
%   Returns 1-based column index, or errors if not found.
    spec = char(spec);

    % If numeric index, validate and return
    if all(ismember(spec, '0123456789'))
        colIdx = str2double(spec);
        if colIdx < 1 || colIdx > numel(colNames)
            error('parser:importLakeShore:badColIndex', ...
                'Column index %d out of range [1, %d]', colIdx, numel(colNames));
        end
        return;
    end

    % Try shorthands
    shorthand = lower(spec);

    % Temperature shorthands
    if ismember(shorthand, {'temp', 'temperature', 't'})
        colIdx = findColumnByKeyword(colNames, {'Temperature', 'Temp', 'T'});
        if ~isnan(colIdx), return; end
    end

    % Field shorthands
    if ismember(shorthand, {'field', 'h', 'appliedfield'})
        colIdx = findColumnByKeyword(colNames, {'Magnetic Field', 'Field', 'H-Field', 'H Field'});
        if ~isnan(colIdx), return; end
    end

    % Moment shorthands
    if ismember(shorthand, {'moment', 'magnetization', 'm'})
        colIdx = findColumnByKeyword(colNames, {'Moment', 'Magnetization', 'M'});
        if ~isnan(colIdx), return; end
    end

    % Susceptibility shorthands
    if ismember(shorthand, {'susceptibility', 'chi', 'chi_m'})
        colIdx = findColumnByKeyword(colNames, {'Susceptibility', 'Chi', 'χ'});
        if ~isnan(colIdx), return; end
    end

    % Try exact match (case-insensitive)
    colIdx = findColumnByExactName(colNames, spec);
    if ~isnan(colIdx), return; end

    % Not found
    error('parser:importLakeShore:colNotFound', ...
        'Could not resolve %s column "%s". Available: %s', ...
        role, spec, strjoin(colNames, ', '));
end

function colIndices = resolveLakeShoreColumns(spec, colNames, xColIdx, role)
%RESOLVELAKESHORECOLUMNS  Resolve one or more y-axis columns.
%   Returns 1-based column indices. Special value 'all' returns all except xColIdx.
    if ischar(spec) && strcmpi(spec, 'all')
        % All columns except x-axis
        colIndices = setdiff(1:numel(colNames), xColIdx);
        if isempty(colIndices)
            colIndices = [];
        end
        return;
    end

    if ischar(spec) || isstring(spec)
        % Single column
        spec = {spec};
    end

    colIndices = [];
    if iscell(spec)
        for k = 1:numel(spec)
            idx = resolveLakeShoreColumn(spec{k}, colNames, role);
            if idx ~= xColIdx  % exclude x-axis
                colIndices = [colIndices, idx]; %#ok<AGROW>
            end
        end
    end
end

function idx = findColumnByKeyword(colNames, keywords)
%FINDCOLUMNBYKEYWORD  Find first column name containing any keyword.
%   Returns 1-based index or NaN.
    idx = NaN;
    for k = 1:numel(keywords)
        keyword = keywords{k};
        for c = 1:numel(colNames)
            if contains(colNames{c}, keyword, 'IgnoreCase', true)
                idx = c;
                return;
            end
        end
    end
end

function idx = findColumnByExactName(colNames, name)
%FINDCOLUMNBYEXACTNAME  Find column by exact case-insensitive name match.
%   Returns 1-based index or NaN.
    idx = NaN;
    for c = 1:numel(colNames)
        if strcmpi(colNames{c}, name)
            idx = c;
            return;
        end
    end
end

function printSummary(data, filepath)
%PRINTSUMMARY  Formatted console output for Verbose mode.
    [~, fname, ext] = fileparts(filepath);

    xLabel = '';
    if isfield(data.metadata, 'xColumnName') && ~isempty(data.metadata.xColumnName)
        xLabel = data.metadata.xColumnName;
    end

    SEP = repmat('─', 1, 58);
    fprintf('\n%s\n', repmat('═', 1, 58));
    fprintf('  importLakeShore  (Lake Shore magnetometer)\n');
    fprintf('  File       : %s%s\n', fname, ext);
    fprintf('%s\n', SEP);

    % X-axis summary
    if isdatetime(data.time)
        tMin = char(datetime(min(data.time), 'Format', 'yyyy-MM-dd HH:mm'));
        tMax = char(datetime(max(data.time), 'Format', 'yyyy-MM-dd HH:mm'));
        fprintf('  X : (datetime)  %s  to  %s\n', tMin, tMax);
    else
        xRange = [min(data.time), max(data.time)];
        fprintf('  X : %-20s  [%.4g, %.4g]\n', xLabel, xRange(1), xRange(2));
    end

    % Y-axis channels
    fprintf('  Channels   : %d\n', size(data.values, 2));
    for k = 1:size(data.values, 2)
        col = data.values(:, k);
        unitStr = '';
        if ~isempty(data.units{k})
            unitStr = sprintf(' (%s)', data.units{k});
        end
        tag = [data.labels{k}, unitStr];
        validVals = col(~isnan(col));
        if isempty(validVals)
            fprintf('    %-28s  (all NaN)\n', tag);
        else
            fprintf('    %-28s  [%.4g, %.4g]\n', tag, ...
                min(validVals), max(validVals));
        end
    end

    fprintf('%s\n\n', repmat('═', 1, 58));
end
