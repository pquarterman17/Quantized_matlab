function data = importExcel(filepath, options)
%IMPORTEXCEL Import an Excel (.xlsx / .xls / .xlsm) file into a unified data struct.
%
%   data = importExcel('experiment.xlsx')
%   data = importExcel('data.xlsx', 'Sheet', 2)
%   data = importExcel('data.xlsx', 'Sheet', 'Results', 'TimeColumn', 1)
%   data = importExcel('data.xlsx', 'DataColumns', {'Voltage','Current'})
%
%   Reads a spreadsheet and returns a standardized data struct compatible
%   with all toolbox plotting functions. Handles merged cells, mixed
%   header rows, unit extraction from headers, and missing values.
%
%   AUTO-DETECTION (when options are not specified):
%     - Sheet:       first sheet
%     - Header row:  first row whose columns are mostly non-numeric
%     - Time column: column 1 by default
%     - Data cols:   all numeric columns except time
%
%   INPUTS:
%       filepath - Path to the Excel file (.xlsx, .xls, .xlsm, .ods).
%
%   OPTIONAL NAME-VALUE PAIRS:
%       Sheet        - Sheet name (string) or 1-based index (integer).
%                      Default: 1 (first sheet).
%       Range        - Excel range string like 'A1:D200'. Default: entire sheet.
%       HeaderRow    - Row number (within the loaded range) that contains
%                      column labels. 0 = no header. Default: auto-detect.
%       DataStartRow - Row where numeric data begins (within range).
%                      Default: auto-detect.
%       TimeColumn   - Column index or exact header name for x-axis.
%                      Default: 1. Use 0 for sample index.
%       DataColumns  - Column indices or cell of header names for y channels.
%                      Default: all numeric columns except time.
%       Labels       - Override channel labels {1xM} cell.
%       Units        - Override channel units {1xM} cell.
%       Verbose      - Print import summary. Default: false.
%
%   OUTPUT:
%       data - Unified data struct with fields:
%                time     - [Nx1] x-axis (numeric or datetime)
%                values   - [NxM] data matrix
%                labels   - {1xM} channel name strings
%                units    - {1xM} unit strings
%                metadata - struct with .source, .importDate, .sheet,
%                           .sheetName, .allSheets, .headerRow
%
%   EXAMPLES:
%       % Auto-detect everything on first sheet
%       data = importExcel('results.xlsx');
%
%       % Specific sheet and columns
%       data = importExcel('lab.xlsx', 'Sheet', 'Run3', ...
%                          'TimeColumn', 'Time (s)', ...
%                          'DataColumns', {'Temp (°C)', 'Pressure (Pa)'});
%
%       % No time column — use sample index
%       data = importExcel('spectra.xlsx', 'TimeColumn', 0);
%
%       % List available sheets before importing
%       [~, sheets] = xlsfinfo('data.xlsx');
%       disp(sheets);
%
%   Limitations
%     File size: tested up to ~50 MB. MATLAB's readcell loads the entire sheet into
%     memory; very large workbooks (>100 MB) may be slow or exhaust RAM.
%     Excel formula errors (#DIV/0!, #VALUE!, #REF!, etc.) become NaN on import;
%     a warning is emitted when more than 10% of values are NaN.
%
%   See also IMPORTCSV, CREATEDATASTRUCT, XLSFINFO, READTABLE

    arguments
        filepath          (1,1) string {mustBeFile}
        options.Sheet                  = 1
        options.Range      (1,1) string = ""
        options.HeaderRow  (1,1) double = -1   % -1 = auto
        options.DataStartRow (1,1) double = -1 % -1 = auto
        options.TimeColumn             = 1     % index, name, or 0
        options.DataColumns            = []    % indices, names, or []
        options.Labels     (1,:) cell  = {}
        options.Units      (1,:) cell  = {}
        options.Verbose    (1,1) logical = false
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 1: Inspect file — get sheet list
    % ════════════════════════════════════════════════════════════════
    allSheets = sheetnames(filepath);
    allSheets = cellstr(allSheets);   % ensure cell array of char

    % Resolve sheet spec to name + index
    if ischar(options.Sheet) || isstring(options.Sheet)
        sheetName = char(options.Sheet);
        sheetIdx  = find(strcmpi(allSheets, sheetName), 1);
        if isempty(sheetIdx)
            error('parser:importExcel:sheetNotFound', ...
                'Sheet "%s" not found. Available sheets: %s', ...
                sheetName, strjoin(allSheets, ', '));
        end
    else
        sheetIdx  = options.Sheet;
        if sheetIdx < 1 || sheetIdx > numel(allSheets)
            error('parser:importExcel:sheetOutOfRange', ...
                'Sheet index %d is out of range (1-%d).', ...
                sheetIdx, numel(allSheets));
        end
        sheetName = allSheets{sheetIdx};
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 2: Read raw cell data (preserves text + numbers)
    % ════════════════════════════════════════════════════════════════
    readArgs = {'Sheet', sheetName};
    if options.Range ~= ""
        readArgs = [readArgs, {'Range', char(options.Range)}];
    end

    % readcell returns cell array; each entry is numeric, char, or missing
    raw = readcell(filepath, readArgs{:});

    % Normalise: replace <missing> with []
    isMiss = cellfun(@(v) isa(v,'missing'), raw);
    raw(isMiss) = {[]};

    % Trim trailing rows/cols that are all NaN or empty
    raw = trimRaw(raw);

    if isempty(raw)
        error('parser:importExcel:emptySheet', ...
            'Sheet "%s" contains no data in file: %s', sheetName, filepath);
    end

    [nRows, nCols] = size(raw);

    % ════════════════════════════════════════════════════════════════
    %  STEP 3: Build numeric shadow matrix for layout detection
    % ════════════════════════════════════════════════════════════════
    numMat = NaN(nRows, nCols);
    for r = 1:nRows
        for c = 1:nCols
            v = raw{r,c};
            if isnumeric(v) && isscalar(v) && ~isnan(v)
                numMat(r,c) = v;
            end
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 4: Detect header row and data start row
    % ════════════════════════════════════════════════════════════════
    [headerRow, dataStartRow] = detectLayout(numMat, nRows, nCols, ...
        options.HeaderRow, options.DataStartRow);

    % ════════════════════════════════════════════════════════════════
    %  STEP 5: Extract column headers
    % ════════════════════════════════════════════════════════════════
    if headerRow > 0
        colHeaders = cell(1, nCols);
        for c = 1:nCols
            v = raw{headerRow, c};
            if ischar(v) || isstring(v)
                colHeaders{c} = strtrim(char(v));
            elseif isnumeric(v) && ~isnan(v)
                colHeaders{c} = num2str(v);
            else
                colHeaders{c} = sprintf('Col%d', c);
            end
        end
    else
        colHeaders = arrayfun(@(k) sprintf('Col%d',k), 1:nCols, ...
            'UniformOutput', false);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 6: Extract data rows as numeric matrix
    % ════════════════════════════════════════════════════════════════
    dataNumMat = numMat(dataStartRow:end, :);
    dataRaw    = raw(dataStartRow:end, :);
    numDataRows = size(dataNumMat, 1);

    % Remove completely empty rows
    nonEmpty = any(~isnan(dataNumMat), 2);
    dataNumMat = dataNumMat(nonEmpty, :);
    dataRaw    = dataRaw(nonEmpty, :);
    numDataRows = size(dataNumMat, 1);

    if numDataRows == 0
        error('parser:importExcel:noDataRows', ...
            'No numeric data rows found on sheet "%s".', sheetName);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 7: Resolve time column
    % ════════════════════════════════════════════════════════════════
    timeColIdx = resolveColumnIndex(options.TimeColumn, colHeaders);

    if timeColIdx == 0
        timeVec = (1:numDataRows)';
    else
        timeVec = buildTimeVector(dataNumMat(:, timeColIdx), ...
                                  dataRaw(:, timeColIdx));
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 8: Resolve data columns
    % ════════════════════════════════════════════════════════════════
    if isempty(options.DataColumns)
        allCols = 1:nCols;
        if timeColIdx > 0
            dataColIdx = allCols(allCols ~= timeColIdx);
        else
            dataColIdx = allCols;
        end
        % Keep only columns with at least 10% numeric content
        numFrac = sum(~isnan(dataNumMat(:, dataColIdx)), 1) / numDataRows;
        dataColIdx = dataColIdx(numFrac > 0.1);
    else
        dataColIdx = resolveColumnIndices(options.DataColumns, colHeaders);
    end

    if isempty(dataColIdx)
        error('parser:importExcel:noDataColumns', ...
            'No valid numeric data columns found on sheet "%s".', sheetName);
    end

    valuesMatrix = dataNumMat(:, dataColIdx);

    % ── NaN fraction check — likely formula errors (#DIV/0!, #VALUE!, etc.) ──
    if numDataRows > 0
        nanFrac = sum(isnan(valuesMatrix(:))) / numel(valuesMatrix);
        if nanFrac > 0.10
            warning('parser:importExcel:highNaNFraction', ...
                ['%.0f%% of data values are NaN in "%s".\n' ...
                 'Excel formula errors (#DIV/0!, #VALUE!, #REF!, etc.) become NaN on import.\n' ...
                 'Check the source spreadsheet for formula errors.'], ...
                nanFrac * 100, sheetName);
        end
    end

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
        for i = 1:M
            [unitStr, cleanLabel] = extractUnitsFromHeader(labels{i});
            if ~isempty(unitStr)
                units{i}  = unitStr;
                labels{i} = cleanLabel;
            end
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 10: Assemble metadata and output struct
    % ════════════════════════════════════════════════════════════════
    % X-axis label (core metadata field)
    if timeColIdx > 0
        rawXHeader = colHeaders{timeColIdx};
        [xUnit, xName] = extractUnitsFromHeader(rawXHeader);
        if isempty(xName), xName = rawXHeader; end
    else
        xName = 'Sample Index';
        xUnit = '';
    end

    % Build allColumnNames / allColumnUnits across ALL columns for parserSpecific
    allColNames = cell(1, nCols);
    allColUnits = cell(1, nCols);
    for ci = 1:nCols
        [allColUnits{ci}, allColNames{ci}] = extractUnitsFromHeader(colHeaders{ci});
        if isempty(allColNames{ci}), allColNames{ci} = colHeaders{ci}; end
    end

    meta.source        = char(filepath);
    meta.importDate    = datetime('now');
    meta.parserName    = 'importExcel';
    meta.parserVersion = '1.0';
    meta.xColumnName   = xName;
    meta.xColumnUnit   = xUnit;

    meta.parserSpecific.sheet          = sheetIdx;
    meta.parserSpecific.sheetName      = sheetName;
    meta.parserSpecific.allSheets      = allSheets;
    meta.parserSpecific.headerRow      = headerRow;
    meta.parserSpecific.numRawRows     = numDataRows;
    meta.parserSpecific.allColumnNames = allColNames;
    meta.parserSpecific.allColumnUnits = allColUnits;

    data = parser.createDataStruct(timeVec, valuesMatrix, ...
        'labels', labels, 'units', units, 'metadata', meta);

    if options.Verbose
        fprintf('Imported %d samples x %d channels from sheet "%s" in %s\n', ...
            numDataRows, M, sheetName, filepath);
    end
end


% ════════════════════════════════════════════════════════════════════
%  LOCAL HELPER FUNCTIONS
% ════════════════════════════════════════════════════════════════════

function raw = trimRaw(raw)
%TRIMRAW Remove trailing all-empty rows and columns.
    if isempty(raw), return; end
    isEmpty = cellfun(@(v) isempty(v) || (isnumeric(v) && isscalar(v) && isnan(v)), raw);
    % Trim trailing empty rows
    lastRow = find(~all(isEmpty, 2), 1, 'last');
    if isempty(lastRow), raw = {}; return; end
    % Trim trailing empty cols
    lastCol = find(~all(isEmpty, 1), 1, 'last');
    raw = raw(1:lastRow, 1:lastCol);
end


function [headerRow, dataStartRow] = detectLayout(numMat, nRows, nCols, hdrOpt, dsOpt)
%DETECTLAYOUT Infer header row and first data row from numeric density.
    if hdrOpt >= 0 && dsOpt >= 0
        headerRow    = hdrOpt;
        dataStartRow = dsOpt;
        return;
    end

    % Score each row: fraction of non-NaN numeric entries
    numericScore = sum(~isnan(numMat), 2) / nCols;

    firstDataIdx = find(numericScore > 0.5, 1, 'first');
    if isempty(firstDataIdx)
        firstDataIdx = 1;
    end

    if dsOpt >= 0
        dataStartRow = dsOpt;
    else
        dataStartRow = firstDataIdx;
    end

    if hdrOpt >= 0
        headerRow = hdrOpt;
    else
        if firstDataIdx > 1 && numericScore(firstDataIdx - 1) < 0.5
            headerRow = firstDataIdx - 1;
        else
            headerRow = 0;
        end
    end
end


function idx = resolveColumnIndex(spec, colHeaders)
%RESOLVECOLUMNINDEX Resolve a single column spec (index or name) to index.
%   Delegates to parser.resolveColumnShorthand (no shorthand map — plain name/index).
    idx = parser.resolveColumnShorthand(spec, colHeaders);
end


function idxVec = resolveColumnIndices(spec, colHeaders)
%RESOLVECOLUMNINDICES Resolve multiple column specs to index vector.
    if isnumeric(spec)
        idxVec = spec(:)';
    elseif iscell(spec)
        idxVec = zeros(1, numel(spec));
        for i = 1:numel(spec)
            idxVec(i) = resolveColumnIndex(spec{i}, colHeaders);
        end
    else
        idxVec = resolveColumnIndex(spec, colHeaders);
    end
end


function timeVec = buildTimeVector(numCol, rawCol)
%BUILDTIMEVECTOR Return numeric column, or try to parse cell entries as datetime.
    if sum(~isnan(numCol)) / numel(numCol) > 0.8
        timeVec = numCol;
        return;
    end
    % Try datetime parsing from text cells
    N = numel(rawCol);
    timeVec = NaT(N, 1);
    anyParsed = false;
    nFail = 0;
    for i = 1:N
        v = rawCol{i};
        if isdatetime(v)
            timeVec(i) = v;
            anyParsed = true;
        elseif ischar(v) && ~isempty(strtrim(v))
            try
                timeVec(i) = datetime(strtrim(v));
                anyParsed = true;
            catch
                nFail = nFail + 1;
            end
        end
    end
    if nFail > 0
        warning('parser:importExcel:timestampParseFailed', ...
            '%d cells could not be parsed as datetime and were set to NaT.', nFail);
    end
    if ~anyParsed
        timeVec = (1:N)';  % fallback: sample index
        warning('parser:importExcel:noDatetimeDetected', ...
            'Time column could not be parsed as datetime; using sample index [1..N] instead.');
    end
end


function [unitStr, cleanLabel] = extractUnitsFromHeader(header)
%EXTRACTUNITSFROMHEADER Parse "Temp (°C)" → unitStr='°C', cleanLabel='Temp'
    unitStr    = '';
    cleanLabel = header;
    tok = regexp(header, '(.+?)\s*\(([^)]+)\)\s*$', 'tokens', 'once');
    if ~isempty(tok)
        cleanLabel = strtrim(tok{1});
        unitStr    = strtrim(tok{2});
        return;
    end
    tok = regexp(header, '(.+?)\s*\[([^\]]+)\]\s*$', 'tokens', 'once');
    if ~isempty(tok)
        cleanLabel = strtrim(tok{1});
        unitStr    = strtrim(tok{2});
    end
end
