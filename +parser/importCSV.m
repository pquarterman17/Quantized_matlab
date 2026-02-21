function data = importCSV(filepath, options)
%IMPORTCSV Import a CSV/TSV file into a unified data struct.
%
%   data = importCSV('experiment.csv')
%   data = importCSV('data.tsv', 'Delimiter', '\t')
%   data = importCSV('data.csv', 'TimeColumn', 1, 'DataColumns', [2 3 4])
%   data = importCSV('data.csv', 'HeaderRow', 1, 'DataStartRow', 3)
%
%   Reads delimited text files and returns a standardized data struct
%   compatible with all toolbox plotting functions. Handles common lab
%   data issues: mixed headers, comment lines, inconsistent delimiters,
%   and missing values.
%
%   AUTO-DETECTION (when options are not specified):
%     - Delimiter: tries comma, tab, semicolon, space
%     - Header row: looks for the first row that is mostly non-numeric
%     - Time column: uses column 1 by default
%     - Data columns: all numeric columns except time
%
%   INPUTS:
%       filepath - Path to the CSV/TSV file.
%
%   OPTIONAL NAME-VALUE PAIRS:
%       Delimiter    - Delimiter character. Default: auto-detect.
%       HeaderRow    - Row number containing column headers (0 = none).
%                      Default: auto-detect.
%       DataStartRow - Row where numeric data begins. Default: auto-detect.
%       TimeColumn   - Column index or name for the time/x-axis variable.
%                      Default: 1. Use 0 to auto-generate a sample index.
%       DataColumns  - Vector of column indices or cell array of names for
%                      data channels. Default: all columns except time.
%       TimeFormat   - Datetime format string if time is text (e.g.
%                      'yyyy-MM-dd HH:mm:ss'). Default: '' (numeric).
%       CommentChar  - Character(s) that mark comment lines to skip.
%                      Default: '#%'.
%       TreatAs      - Force 'numeric' or 'datetime' interpretation of
%                      the time column. Default: 'auto'.
%       Labels       - Override channel labels {1xM} cell. Default: from
%                      header row or auto-generated.
%       Units        - Channel units {1xM} cell. Default: '' for all.
%
%   OUTPUT:
%       data - Unified data struct (see createDataStruct).
%
%   EXAMPLES:
%       % Basic usage — auto-detect everything
%       data = importCSV('experiment.csv');
%
%       % Tab-delimited with specific columns
%       data = importCSV('log.tsv', 'Delimiter', '\t', ...
%                         'TimeColumn', 1, 'DataColumns', [3 5 7]);
%
%       % Datetime time column
%       data = importCSV('sensor.csv', 'TimeFormat', 'yyyy-MM-dd HH:mm:ss');
%
%       % No time column — use sample index
%       data = importCSV('raw.csv', 'TimeColumn', 0);
%
%   See also CREATEDATASTRUCT, VALIDATEDATA, PREVIEWFILE, IMPORTAUTO

    arguments
        filepath        (1,1) string {mustBeFile}
        options.Delimiter    (1,1) string  = ""
        options.HeaderRow    (1,1) double  = -1   % -1 = auto
        options.DataStartRow (1,1) double  = -1   % -1 = auto
        options.TimeColumn                 = 1    % index, name, or 0
        options.DataColumns                = []   % indices, names, or []
        options.TimeFormat   (1,1) string  = ""
        options.CommentChar  (1,1) string  = "#%"
        options.TreatAs      (1,1) string  = "auto"
        options.Labels       (1,:) cell    = {}
        options.Units        (1,:) cell    = {}
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 1: Read raw lines and strip comments
    % ════════════════════════════════════════════════════════════════
    rawLines = readRawLines(filepath, options.CommentChar);
    if isempty(rawLines)
        error('importCSV:emptyFile', 'File is empty or contains only comments: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 2: Detect delimiter
    % ════════════════════════════════════════════════════════════════
    if options.Delimiter == ""
        delim = detectDelimiter(rawLines);
    else
        delim = options.Delimiter;
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 3: Split lines into tokens
    % ════════════════════════════════════════════════════════════════
    tokens = splitLines(rawLines, delim);

    % ════════════════════════════════════════════════════════════════
    %  STEP 4: Detect header row and data start
    % ════════════════════════════════════════════════════════════════
    [headerRow, dataStartRow] = detectLayout(tokens, ...
        options.HeaderRow, options.DataStartRow);

    % ════════════════════════════════════════════════════════════════
    %  STEP 5: Extract column headers
    % ════════════════════════════════════════════════════════════════
    if headerRow > 0
        colHeaders = strtrim(tokens{headerRow});
    else
        numCols = numel(tokens{dataStartRow});
        colHeaders = arrayfun(@(k) sprintf('Col%d',k), 1:numCols, ...
                              'UniformOutput', false);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 6: Parse numeric data
    % ════════════════════════════════════════════════════════════════
    numCols = numel(colHeaders);
    dataRows = tokens(dataStartRow:end);
    numRows = numel(dataRows);

    rawMatrix = NaN(numRows, numCols);
    rawText   = cell(numRows, numCols);   % keep text for datetime parsing
    for r = 1:numRows
        row = dataRows{r};
        nCols = min(numel(row), numCols);
        for c = 1:nCols
            val = strtrim(row{c});
            rawText{r,c} = val;
            num = str2double(val);
            if ~isnan(num)
                rawMatrix(r,c) = num;
            elseif isempty(val) || strcmpi(val, 'nan') || ...
                   strcmpi(val, 'na') || strcmpi(val, '-') || ...
                   strcmpi(val, 'n/a')
                rawMatrix(r,c) = NaN;
            end
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 7: Resolve time column
    % ════════════════════════════════════════════════════════════════
    timeColIdx = resolveColumnIndex(options.TimeColumn, colHeaders);

    if timeColIdx == 0
        % No time column — generate sample index
        timeVec = (1:numRows)';
    else
        timeVec = parseTimeColumn(rawMatrix(:, timeColIdx), ...
                                   rawText(:, timeColIdx), ...
                                   options.TimeFormat, options.TreatAs);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 8: Resolve data columns
    % ════════════════════════════════════════════════════════════════
    if isempty(options.DataColumns)
        % Default: all columns except time
        allCols = 1:numCols;
        if timeColIdx > 0
            dataColIdx = allCols(allCols ~= timeColIdx);
        else
            dataColIdx = allCols;
        end
        % Further filter: keep only columns that have at least some numeric data
        numericFrac = sum(~isnan(rawMatrix(:, dataColIdx)), 1) / numRows;
        dataColIdx = dataColIdx(numericFrac > 0.1);
    else
        dataColIdx = resolveColumnIndices(options.DataColumns, colHeaders);
    end

    if isempty(dataColIdx)
        error('importCSV:noDataColumns', ...
            'No valid numeric data columns found in: %s', filepath);
    end

    valuesMatrix = rawMatrix(:, dataColIdx);

    % ════════════════════════════════════════════════════════════════
    %  STEP 9: Build labels and units
    % ════════════════════════════════════════════════════════════════
    M = numel(dataColIdx);
    if ~isempty(options.Labels)
        labels = options.Labels;
    else
        labels = colHeaders(dataColIdx);
    end

    if ~isempty(options.Units)
        units = options.Units;
    else
        units = repmat({''}, 1, M);
        % Try to extract units from header strings like "Temp (°C)"
        for i = 1:M
            [unitStr, cleanLabel] = extractUnitsFromHeader(labels{i});
            if ~isempty(unitStr)
                units{i}  = unitStr;
                labels{i} = cleanLabel;
            end
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 10: Assemble unified struct
    % ════════════════════════════════════════════════════════════════
    meta.source     = char(filepath);
    meta.importDate = datetime('now');
    meta.delimiter  = char(delim);
    meta.headerRow  = headerRow;
    meta.numRawRows = numel(rawLines);

    % X-axis label (used by importAuto summary)
    if timeColIdx > 0
        rawXHeader = colHeaders{timeColIdx};
        [xUnit, xName] = extractUnitsFromHeader(rawXHeader);
        if isempty(xName), xName = rawXHeader; end
        meta.xColumnName = xName;
        meta.xColumnUnit = xUnit;
    else
        meta.xColumnName = 'Sample Index';
        meta.xColumnUnit = '';
    end

    data = parser.createDataStruct(timeVec, valuesMatrix, ...
        'labels', labels, 'units', units, 'metadata', meta);

    fprintf('Imported %d samples x %d channels from %s\n', ...
        size(valuesMatrix,1), M, filepath);
end


% ════════════════════════════════════════════════════════════════════
%  LOCAL HELPER FUNCTIONS
% ════════════════════════════════════════════════════════════════════

function rawLines = readRawLines(filepath, commentChars)
%READRAWLINES Read file, strip blank and comment lines.
    fid = fopen(filepath, 'r');
    cleanObj = onCleanup(@() fclose(fid));
    allLines = {};
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line), continue; end
        stripped = strtrim(line);
        if isempty(stripped), continue; end
        % Skip comment lines
        isComment = false;
        for c = 1:strlength(commentChars)
            if stripped(1) == extract(commentChars, c)
                isComment = true;
                break;
            end
        end
        if ~isComment
            allLines{end+1} = stripped; %#ok<AGROW>
        end
    end
    rawLines = allLines(:);
end


function delim = detectDelimiter(rawLines)
%DETECTDELIMITER Auto-detect the most likely delimiter.
    candidates = {',', '\t', ';', ' '};
    scores = zeros(size(candidates));
    testLines = rawLines(1:min(10, numel(rawLines)));

    for d = 1:numel(candidates)
        if strcmp(candidates{d}, '\t')
            ch = sprintf('\t');
        else
            ch = candidates{d};
        end
        counts = zeros(numel(testLines), 1);
        for r = 1:numel(testLines)
            counts(r) = numel(strfind(testLines{r}, ch));
        end
        % Best delimiter: consistent non-zero count across lines
        if all(counts > 0) && std(counts) < mean(counts) * 0.5
            scores(d) = mean(counts);
        end
    end

    [~, best] = max(scores);
    if scores(best) > 0
        if strcmp(candidates{best}, '\t')
            delim = sprintf('\t');
        else
            delim = candidates{best};
        end
    else
        delim = ',';  % fallback
    end
end


function tokens = splitLines(rawLines, delim)
%SPLITLINES Split each raw line by the delimiter.
    tokens = cell(numel(rawLines), 1);
    for i = 1:numel(rawLines)
        tokens{i} = strsplit(rawLines{i}, delim);
    end
end


function [headerRow, dataStartRow] = detectLayout(tokens, hdrOpt, dsOpt)
%DETECTLAYOUT Find header row and first data row.
    N = numel(tokens);

    if hdrOpt >= 0 && dsOpt >= 0
        % Both specified
        headerRow = hdrOpt;
        dataStartRow = dsOpt;
        return;
    end

    % Score each row: fraction of fields that parse as numeric
    numericScore = zeros(N, 1);
    for i = 1:N
        row = tokens{i};
        nFields = numel(row);
        nNum = 0;
        for j = 1:nFields
            val = strtrim(row{j});
            if ~isnan(str2double(val))
                nNum = nNum + 1;
            end
        end
        numericScore(i) = nNum / max(nFields, 1);
    end

    % Find first row that is mostly numeric (>50%)
    firstDataIdx = find(numericScore > 0.5, 1, 'first');
    if isempty(firstDataIdx)
        firstDataIdx = 1;  % all rows look non-numeric — try anyway
    end

    if dsOpt >= 0
        dataStartRow = dsOpt;
    else
        dataStartRow = firstDataIdx;
    end

    if hdrOpt >= 0
        headerRow = hdrOpt;
    else
        % If the row above the first data row is non-numeric, it's the header
        if firstDataIdx > 1 && numericScore(firstDataIdx - 1) < 0.5
            headerRow = firstDataIdx - 1;
        else
            headerRow = 0;  % no header detected
        end
    end
end


function idx = resolveColumnIndex(spec, colHeaders)
%RESOLVECOLUMNINDEX Convert a column spec (index or name) to index.
    if isnumeric(spec)
        idx = spec;
    elseif ischar(spec) || isstring(spec)
        idx = find(strcmpi(colHeaders, spec), 1);
        if isempty(idx)
            error('importCSV:columnNotFound', ...
                'Column "%s" not found. Available: %s', ...
                spec, strjoin(colHeaders, ', '));
        end
    else
        idx = 1;
    end
end


function idxVec = resolveColumnIndices(spec, colHeaders)
%RESOLVECOLUMNINDICES Convert multiple column specs to indices.
    if isnumeric(spec)
        idxVec = spec;
    elseif iscell(spec)
        idxVec = zeros(1, numel(spec));
        for i = 1:numel(spec)
            idxVec(i) = resolveColumnIndex(spec{i}, colHeaders);
        end
    else
        idxVec = resolveColumnIndex(spec, colHeaders);
    end
end


function timeVec = parseTimeColumn(numCol, textCol, timeFmt, treatAs)
%PARSETIMECOLUMN Parse time column as numeric or datetime.
    N = numel(numCol);

    % Decide strategy
    if treatAs == "numeric" || (treatAs == "auto" && sum(~isnan(numCol))/N > 0.8)
        % Numeric time
        timeVec = numCol;
    elseif treatAs == "datetime" || timeFmt ~= ""
        % Parse as datetime
        timeVec = NaT(N, 1);
        for i = 1:N
            try
                if timeFmt ~= ""
                    timeVec(i) = datetime(textCol{i}, 'InputFormat', char(timeFmt));
                else
                    timeVec(i) = datetime(textCol{i});
                end
            catch
                % leave as NaT
            end
        end
    else
        % Try auto-parsing datetime, fall back to numeric index
        try
            test = datetime(textCol{1});
            timeVec = NaT(N, 1);
            for i = 1:N
                try
                    timeVec(i) = datetime(textCol{i});
                catch
                end
            end
        catch
            timeVec = (1:N)';  % fallback: sample index
        end
    end
end


function [unitStr, cleanLabel] = extractUnitsFromHeader(header)
%EXTRACTUNITSFROMHEADER Parse "Temp (°C)" → unitStr='°C', cleanLabel='Temp'
    unitStr = '';
    cleanLabel = header;

    % Pattern: "Label (unit)" or "Label [unit]"
    matchParen = regexp(header, '(.+?)\s*\(([^)]+)\)\s*$', 'tokens', 'once');
    if ~isempty(matchParen)
        cleanLabel = strtrim(matchParen{1});
        unitStr = strtrim(matchParen{2});
        return;
    end
    matchBrack = regexp(header, '(.+?)\s*\[([^\]]+)\]\s*$', 'tokens', 'once');
    if ~isempty(matchBrack)
        cleanLabel = strtrim(matchBrack{1});
        unitStr = strtrim(matchBrack{2});
    end
end