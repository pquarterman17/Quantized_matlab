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
%     - Units row: a second non-numeric row immediately before data (e.g.
%       a row of "(°C)","(Oe)","emu") is detected and its values are used
%       as channel units, overriding any inline "Label (unit)" extraction
%     - Pre-header metadata (instrument info, date, etc.) is captured and
%       stored in data.metadata.parserSpecific.headerMetadata
%     - Time column: uses column 1 by default
%     - Data columns: all numeric columns except time; fully-empty columns
%       (e.g. blank separator columns in Excel exports) are automatically
%       removed; blank column headers are replaced with 'Col{N}'
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
%   Limitations
%     File size: tested up to ~200 MB. Larger files will load but may be slow due to
%     in-memory string processing. Files above ~1 GB may exhaust available RAM.
%     For very large files, consider pre-filtering with external tools before import.
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
        options.Verbose      (1,1) logical = false
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 1: Read raw lines and strip comments
    % ════════════════════════════════════════════════════════════════
    rawLines = readRawLines(filepath, options.CommentChar);
    if isempty(rawLines)
        error('parser:importCSV:emptyFile', 'File is empty or contains only comments: %s', filepath);
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
    %  STEP 4: Detect header row, units row, and data start
    % ════════════════════════════════════════════════════════════════
    [headerRow, dataStartRow, unitsRow] = detectLayout(tokens, ...
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

    % Pad / trim colHeaders to match the actual data row width
    nDataCols = numel(tokens{dataStartRow});
    if numel(colHeaders) < nDataCols
        for k = numel(colHeaders)+1 : nDataCols
            colHeaders{k} = sprintf('Col%d', k);
        end
    elseif numel(colHeaders) > nDataCols
        colHeaders = colHeaders(1:nDataCols);
    end

    % Replace blank column headers with 'Col{N}' so output labels are never empty
    for k = 1:numel(colHeaders)
        if isempty(strtrim(colHeaders{k}))
            colHeaders{k} = sprintf('Col%d', k);
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 5b: Extract row-level units from a dedicated units row
    %  (e.g. a row of "(s)","(°C)","emu" between the header and data)
    % ════════════════════════════════════════════════════════════════
    rowUnits = {};   % populated only when a units row was detected
    if unitsRow > 0
        uTok = strtrim(tokens{unitsRow});
        rowUnits = cell(1, numel(colHeaders));
        for k = 1:numel(colHeaders)
            if k <= numel(uTok)
                u = strtrim(uTok{k});
                % Strip surrounding ( ) or [ ]
                u = regexprep(u, '^\s*[\(\[](.*?)[\)\]]\s*$', '$1');
                rowUnits{k} = u;
            else
                rowUnits{k} = '';
            end
        end
    end

    % Capture pre-header metadata lines (instrument name, date, operator, etc.)
    % These are all non-comment rows before the column header row.
    headerMetadata = {};
    if headerRow > 1
        for mi = 1:headerRow-1
            headerMetadata{end+1} = strjoin(strtrim(tokens{mi}), char(delim)); %#ok<AGROW>
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 6: Parse numeric data
    % ════════════════════════════════════════════════════════════════
    numCols = numel(colHeaders);
    dataRows = tokens(dataStartRow:end);
    numRows = numel(dataRows);

    % Build a padded 2D cell array of all tokens; trim whitespace
    allTokens = cell(numRows, numCols);
    rawText   = cell(numRows, numCols);   % keep text for datetime parsing
    for r = 1:numRows
        row = dataRows{r};
        nCols = min(numel(row), numCols);
        for c = 1:nCols
            val = strtrim(row{c});
            allTokens{r,c} = val;
            rawText{r,c}   = val;
        end
    end

    % Vectorized str2double call on the entire matrix
    rawMatrix = str2double(allTokens);

    % Post-process NaN patterns: treat empties, 'nan', 'na', '-', 'n/a' as NaN
    for r = 1:numRows
        for c = 1:numCols
            val = rawText{r,c};
            if isempty(val) || strcmpi(val, 'nan') || ...
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
        % Filter 1: keep only columns that have at least some numeric data.
        % This removes empty separator columns (all-NaN) common in Excel exports.
        numericFrac = sum(~isnan(rawMatrix(:, dataColIdx)), 1) / numRows;
        dataColIdx = dataColIdx(numericFrac > 0.1);
    else
        dataColIdx = resolveColumnIndices(options.DataColumns, colHeaders);
    end

    if isempty(dataColIdx)
        error('parser:importCSV:noDataColumns', ...
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
        % Dedicated units row overrides inline units from header strings
        if ~isempty(rowUnits)
            for i = 1:M
                u = rowUnits{dataColIdx(i)};
                if ~isempty(u)
                    units{i} = u;
                end
            end
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 10: Assemble unified struct
    % ════════════════════════════════════════════════════════════════
    % X-axis label (core metadata field)
    if timeColIdx > 0
        rawXHeader = colHeaders{timeColIdx};
        [xUnit, xName] = extractUnitsFromHeader(rawXHeader);
        if isempty(xName), xName = rawXHeader; end
        % Prefer dedicated units row over inline unit in header
        if ~isempty(rowUnits) && timeColIdx <= numel(rowUnits) && ~isempty(rowUnits{timeColIdx})
            xUnit = rowUnits{timeColIdx};
        end
    else
        xName = 'Sample Index';
        xUnit = '';
    end

    % Build allColumnNames / allColumnUnits across ALL columns for parserSpecific
    allColNames = cell(1, numel(colHeaders));
    allColUnits = cell(1, numel(colHeaders));
    for ci = 1:numel(colHeaders)
        [allColUnits{ci}, allColNames{ci}] = extractUnitsFromHeader(colHeaders{ci});
        if isempty(allColNames{ci}), allColNames{ci} = colHeaders{ci}; end
    end

    meta.source        = char(filepath);
    meta.importDate    = datetime('now');
    meta.parserName    = 'importCSV';
    meta.parserVersion = '1.0';
    meta.xColumnName   = xName;
    meta.xColumnUnit   = xUnit;

    meta.parserSpecific.delimiter      = char(delim);
    meta.parserSpecific.headerRow      = headerRow;
    meta.parserSpecific.unitsRow       = unitsRow;
    meta.parserSpecific.numRawRows     = numel(rawLines);
    meta.parserSpecific.allColumnNames = allColNames;
    meta.parserSpecific.allColumnUnits = allColUnits;
    meta.parserSpecific.headerMetadata = headerMetadata;  % pre-header text lines

    data = parser.createDataStruct(timeVec, valuesMatrix, ...
        'labels', labels, 'units', units, 'metadata', meta);

    if options.Verbose
        fprintf('Imported %d samples x %d channels from %s\n', ...
            size(valuesMatrix,1), M, filepath);
    end
end


% ════════════════════════════════════════════════════════════════════
%  LOCAL HELPER FUNCTIONS
% ════════════════════════════════════════════════════════════════════

function rawLines = readRawLines(filepath, commentChars)
%READRAWLINES Read file, strip blank and comment lines.
    % Use readlines() for vectorized I/O (R2020b+) — much faster than fgetl loop
    allLines = readlines(filepath);
    allLines = strtrim(allLines);                    % vectorized trim

    % Build mask for non-blank, non-comment lines
    mask = allLines ~= "";
    for c = 1:strlength(commentChars)
        cc = extract(commentChars, c);
        mask = mask & ~startsWith(allLines, cc);
    end

    rawLines = cellstr(allLines(mask));             % convert to cell for compatibility
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
%   Uses regexp 'split' so that consecutive delimiters (e.g. ",," in CSV)
%   produce an empty-string token rather than being silently collapsed.
%   strsplit collapses consecutive delimiters by default in some MATLAB
%   versions, which would drop empty columns — so regexp is safer here.
    tokens = cell(numel(rawLines), 1);
    pat = regexptranslate('escape', char(delim));
    for i = 1:numel(rawLines)
        tokens{i} = regexp(rawLines{i}, pat, 'split');
    end
end


function [headerRow, dataStartRow, unitsRow] = detectLayout(tokens, hdrOpt, dsOpt)
%DETECTLAYOUT Find header row, optional units row, and first data row.
%
%   unitsRow is non-zero when a dedicated units row is detected between the
%   column-header row and the data (e.g. a row of "(s)","(°C)","emu").
%   Detection requires at least two consecutive non-numeric rows before the
%   first data row so that a single header like "Field (Oe)" is never
%   mis-identified as a units row.
    N = numel(tokens);
    unitsRow = 0;

    if hdrOpt >= 0 && dsOpt >= 0
        % Both explicitly specified — trust the caller
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
        return;
    end

    % ── Auto-detect header (and optional units) row ──────────────────
    % Only attempt units-row detection when there are ≥2 consecutive
    % non-numeric rows immediately before the first data row, to avoid
    % misidentifying a header like "Field (Oe)" as a units row.
    if firstDataIdx >= 3 && ...
       numericScore(firstDataIdx - 1) < 0.5 && ...
       numericScore(firstDataIdx - 2) < 0.5 && ...
       looksLikeUnitsRow(tokens{firstDataIdx - 1}, numel(tokens{firstDataIdx}))
        % Pattern: ... | header row | units row | data row
        unitsRow  = firstDataIdx - 1;
        headerRow = firstDataIdx - 2;
    elseif firstDataIdx > 1 && numericScore(firstDataIdx - 1) < 0.5
        % Standard: single non-numeric row immediately before data
        headerRow = firstDataIdx - 1;
    else
        headerRow = 0;  % no header detected
    end
end


function tf = looksLikeUnitsRow(rowTokens, nDataCols)
%LOOKSLIKEUNITSROW  Return true if rowTokens looks like a units row.
%   Heuristic: the row must have a similar column count to the data row,
%   and ≥60% of entries must either be empty or look like physical unit
%   strings (short, no spaces, wrapped in brackets, or a recognised unit
%   abbreviation pattern).
    n = numel(rowTokens);
    if n < max(nDataCols * 0.5, 2)
        tf = false; return;
    end
    nUnitLike = 0;
    nNonEmpty = 0;
    for i = 1:n
        t = strtrim(rowTokens{i});
        if isempty(t)
            nUnitLike = nUnitLike + 1;  % empty separators are fine in units rows
            continue;
        end
        nNonEmpty = nNonEmpty + 1;
        % Wrapped in ( ) or [ ] → classic unit annotation
        if ~isempty(regexp(t, '^[\(\[{].*[\)\]}]$', 'once'))
            nUnitLike = nUnitLike + 1;
        % Short unit abbreviation: has non-alpha chars (/, °, digits) + short,
        % OR is a very short all-alpha token (≤4 chars, e.g. "Oe", "emu", "K").
        % The ≤4 cap prevents column-name words like "Field" (5) or "Temp" (4+)
        % from being mistaken for unit abbreviations.
        elseif isempty(strfind(t, ' ')) && isnan(str2double(t)) && ...
               (~isempty(regexp(t, '[^a-zA-Z]', 'once')) && numel(t) <= 10 || ...
                isempty(regexp(t, '[^a-zA-Z]', 'once'))  && numel(t) <= 4)
            nUnitLike = nUnitLike + 1;
        end
    end
    % Require at least one non-empty entry and ≥60% unit-like entries overall
    tf = nNonEmpty > 0 && (nUnitLike / max(n, 1)) >= 0.6;
end


function idx = resolveColumnIndex(spec, colHeaders)
%RESOLVECOLUMNINDEX Convert a column spec (index or name) to index.
%   Delegates to parser.resolveColumnShorthand (no shorthand map — plain name/index).
    idx = parser.resolveColumnShorthand(spec, colHeaders);
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
        nFail = 0;
        for i = 1:N
            try
                if timeFmt ~= ""
                    timeVec(i) = datetime(textCol{i}, 'InputFormat', char(timeFmt));
                else
                    timeVec(i) = datetime(textCol{i});
                end
            catch
                nFail = nFail + 1;
            end
        end
        if nFail > 0
            warning('parser:importCSV:timestampParseFailed', ...
                '%d of %d timestamps could not be parsed and were set to NaT.', nFail, N);
        end
    else
        % Try auto-parsing datetime, fall back to numeric index
        try
            test = datetime(textCol{1}); %#ok<NASGU>
            timeVec = NaT(N, 1);
            nFail = 0;
            for i = 1:N
                try
                    timeVec(i) = datetime(textCol{i});
                catch
                    nFail = nFail + 1;
                end
            end
            if nFail > 0
                warning('parser:importCSV:timestampAutoParseFailed', ...
                    '%d of %d timestamps could not be auto-parsed and were set to NaT.', nFail, N);
            end
        catch
            timeVec = (1:N)';  % fallback: sample index
            warning('parser:importCSV:noDatetimeDetected', ...
                'Time column could not be parsed as datetime; using sample index [1..N] instead.');
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