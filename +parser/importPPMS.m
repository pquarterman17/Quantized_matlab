function data = importPPMS(filepath, options)
%IMPORTPPMS Import a Quantum Design PPMS/VSM legacy magnetometry .dat file.
%
%   data = importPPMS('sample.dat')
%   data = importPPMS('sample.dat', 'XAxis', 'field', 'YAxis', 'moment')
%   data = importPPMS('sample.dat', 'YAxis', {'moment','temp'})
%   data = importPPMS('sample.dat', 'YAxis', 'all')
%
%   Reads PPMS/VSM .dat files that use a plain CSV layout (no [Header] or
%   [Data] markers). The first column ("Comment") is automatically ignored.
%   Column resolution uses the same shorthands as importQDVSM so the two
%   parsers are interchangeable when the file format is known.
%
%   FILE FORMAT EXPECTED:
%     Comment,Time Stamp (sec),Temperature (K),Magnetic Field (Oe),Moment (emu),...
%     ,3745741634.97,9.99,6999.72,6.87e-6,...
%     ,3745741651.38,9.99,6904.04,6.77e-6,...
%     ...
%
%   INPUTS:
%       filepath - Path to the .dat file.
%
%   OPTIONAL NAME-VALUE PAIRS:
%       XAxis       - Column for the x-axis. Accepts column index, exact
%                     column name, or shorthand:
%                       'field'   → 'Magnetic Field'
%                       'temp'    → 'Temperature'
%                       'time'    → 'Time Stamp'
%                     Default: 'field'.
%       YAxis       - Column(s) for y-axis. Accepts index, name, cell array,
%                     or shorthand. Special value 'all' selects every numeric
%                     column except the x-axis. Default: 'moment'.
%       TimeColumn  - Alias for XAxis.
%       DataColumns - Alias for YAxis.
%       Verbose     - Print import summary. Default: false.
%
%   OUTPUT:
%       data - Unified data struct with fields:
%                time     - [Nx1] x-axis values
%                values   - [NxM] data matrix
%                labels   - {1xM} channel names
%                units    - {1xM} unit strings
%                metadata - struct with .source, .importDate,
%                           .allColumnNames, .allColumnUnits
%
%   EXAMPLES:
%       % Default: M vs H
%       data = parser.importPPMS('2449_1B_IP.dat');
%       plot(data.time, data.values);
%       xlabel('Magnetic Field (Oe)');  ylabel('Moment (emu)');
%
%       % Moment and temperature vs time
%       data = parser.importPPMS('run.dat', ...
%           'XAxis', 'time', 'YAxis', {'moment', 'temp'});
%
%       % All numeric channels vs field
%       data = parser.importPPMS('run.dat', 'YAxis', 'all');
%
%   Limitations
%     File size: tested up to ~50 MB. The entire file is read into memory.
%     Files above ~500 MB may exhaust available RAM.
%
%   See also IMPORTQDVSM, IMPORTCSV, CREATEDATASTRUCT

    arguments
        filepath            (1,1) string {mustBeFile}
        options.XAxis              = 'field'
        options.YAxis              = 'moment'
        options.TimeColumn         = ''    % alias for XAxis
        options.DataColumns        = ''    % alias for YAxis
        options.HeaderRow    (1,1) double = 1   % 1-based line number; -1 = auto-detect
        options.DataStartRow (1,1) double = -1  % 1-based line number; -1 = HeaderRow+1
        options.Verbose     (1,1) logical = false
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

    % ════════════════════════════════════════════════════════════════
    %  STEP 1: Read all lines, then locate header and data start
    %  HeaderRow  = 1 (default) or -1 (auto-detect first non-comment line)
    %  DataStartRow = -1 (auto = HeaderRow+1) or an explicit 1-based index
    %  Comment lines are those whose first non-space character is ; # or %
    % ════════════════════════════════════════════════════════════════
    % Use readlines() for vectorized I/O (R2020b+) — much faster than fgetl loop
    allLines = cellstr(readlines(filepath));

    if isempty(allLines)
        error('parser:importPPMS:emptyFile', 'File is empty: %s', filepath);
    end

    % Resolve header row
    if options.HeaderRow == -1
        trimmed = strtrim(allLines);
        nonEmpty = ~cellfun('isempty', trimmed);
        firstChars = repmat(' ', 1, numel(trimmed));
        firstChars(nonEmpty) = cellfun(@(s) s(1), trimmed(nonEmpty));
        isHeader = nonEmpty & ~ismember(firstChars, ';#%');
        headerRowIdx = find(isHeader, 1);
        if isempty(headerRowIdx)
            error('parser:importPPMS:noHeader', ...
                'No non-comment header line found in: %s', filepath);
        end
    else
        headerRowIdx = options.HeaderRow;
    end

    % Resolve data start row
    if options.DataStartRow == -1
        dataStartIdx = headerRowIdx + 1;
    else
        dataStartIdx = options.DataStartRow;
    end

    % Collect non-empty lines from data start onward (vectorized)
    headerLine = allLines{headerRowIdx};
    tailLines  = strtrim(allLines(dataStartIdx:end));
    rawLines   = tailLines(~cellfun('isempty', tailLines));

    if isempty(rawLines)
        error('parser:importPPMS:noData', 'No data rows found in: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 2: Parse column headers (skip first "Comment" column)
    %  Auto-detect delimiter: prefer tab if the header contains a tab,
    %  otherwise fall back to comma (handles newer PPMS TSV exports).
    % ════════════════════════════════════════════════════════════════
    if contains(headerLine, sprintf('\t'))
        delim = sprintf('\t');
    else
        delim = ',';
    end
    allHeaders = strtrim(strsplit(headerLine, delim, 'CollapseDelimiters', false));

    % Drop leading empty / "Comment" column
    if strcmpi(strtrim(allHeaders{1}), 'comment') || isempty(strtrim(allHeaders{1}))
        allHeaders = allHeaders(2:end);
        firstDataCol = 2;   % 1-indexed in raw CSV
    else
        firstDataCol = 1;
    end

    numCols = numel(allHeaders);

    % Split "Name (unit)" → name + unit
    colNames = cell(1, numCols);
    colUnits = cell(1, numCols);
    for c = 1:numCols
        [colNames{c}, colUnits{c}] = parser.parseColHeader(allHeaders{c});
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 3: Parse numeric data
    % ════════════════════════════════════════════════════════════════
    numRows = numel(rawLines);
    rawMatrix = NaN(numRows, numCols);

    for r = 1:numRows
        parts = strsplit(rawLines{r}, delim, 'CollapseDelimiters', false);
        % Offset to skip the Comment column if present
        for c = 1:numCols
            srcIdx = c + firstDataCol - 1;
            if srcIdx <= numel(parts)
                rawMatrix(r, c) = str2double(strtrim(parts{srcIdx}));
            end
        end
    end

    % Drop rows that are entirely NaN
    validRows = any(~isnan(rawMatrix), 2);
    rawMatrix = rawMatrix(validRows, :);
    numRows   = size(rawMatrix, 1);

    if numRows == 0
        error('parser:importPPMS:noValidRows', 'No valid numeric rows in: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 4: Resolve x-axis
    % ════════════════════════════════════════════════════════════════
    xColIdx = resolvePPMSColumn(xSpec, colNames, 'x-axis');

    % ════════════════════════════════════════════════════════════════
    %  STEP 5: Resolve y-axis
    % ════════════════════════════════════════════════════════════════
    if ischar(ySpec) || isstring(ySpec)
        ySpec = {char(ySpec)};
    end

    if isscalar(ySpec) && strcmpi(ySpec{1}, 'all')
        yColIdx = [];
        for c = 1:numCols
            if c == xColIdx, continue; end
            frac = sum(~isnan(rawMatrix(:,c))) / numRows;
            if frac > 0.5
                yColIdx(end+1) = c; %#ok<AGROW>
            end
        end
    else
        yColIdx = zeros(1, numel(ySpec));
        for k = 1:numel(ySpec)
            yColIdx(k) = resolvePPMSColumn(ySpec{k}, colNames, 'y-axis');
        end
    end

    if isempty(yColIdx)
        error('parser:importPPMS:noYColumns', 'No valid y-axis columns found.');
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 6: Assemble output struct
    % ════════════════════════════════════════════════════════════════
    timeVec      = rawMatrix(:, xColIdx);
    valuesMatrix = rawMatrix(:, yColIdx);
    labels       = colNames(yColIdx);
    units        = colUnits(yColIdx);

    meta.source        = char(filepath);
    meta.importDate    = datetime('now');
    meta.parserName    = 'importPPMS';
    meta.parserVersion = '1.0';
    meta.xColumnName   = colNames{xColIdx};
    meta.xColumnUnit = colUnits{xColIdx};

    meta.parserSpecific.allColumnNames  = colNames;
    meta.parserSpecific.allColumnUnits  = colUnits;
    meta.parserSpecific.headerRow       = headerRowIdx;
    meta.parserSpecific.delimiter       = delim;
    meta.parserSpecific.numRawRows      = numel(allLines);
    meta.parserSpecific.xColumnIndex    = xColIdx;
    meta.parserSpecific.yColumnIndices  = yColIdx;

    data = parser.createDataStruct(timeVec, valuesMatrix, ...
        'labels', labels, 'units', units, 'metadata', meta);

    if options.Verbose
        fprintf('importPPMS: %d rows, x=%s, y=%s — %s\n', ...
            numRows, colNames{xColIdx}, strjoin(labels, '/'), filepath);
    end
end


% ════════════════════════════════════════════════════════════════════
%  LOCAL HELPERS
% ════════════════════════════════════════════════════════════════════

function idx = resolvePPMSColumn(spec, colNames, role)
%RESOLVEPPMSCOLUMN Map a shorthand or name/index to a column index.
%   Delegates to parser.resolveColumnShorthand with the PPMS-specific shorthand map.
    persistent PPMS_SHORTHAND_MAP
    if isempty(PPMS_SHORTHAND_MAP)
        PPMS_SHORTHAND_MAP = {
            'field',       'Magnetic Field'
            'moment',      'Moment'
            'temp',        'Temperature'
            'temperature', 'Temperature'
            'time',        'Time Stamp'
            'stderr',      'M. Std. Err.'
            'mass',        'Mass'
            'pressure',    'Pressure'
            'frequency',   'Frequency'
            'amplitude',   'Peak Amplitude'
            'range',       'Range'
            'motorcurrent','Motor Current'
        };
    end
    try
        idx = parser.resolveColumnShorthand(spec, colNames, PPMS_SHORTHAND_MAP, role);
    catch ME
        if contains(ME.identifier, 'notFound')
            error('parser:importPPMS:columnNotFound', ...
                'Cannot find %s column "%s".\nAvailable: %s\nShorthands: field, moment, temp, time, stderr', ...
                role, char(spec), strjoin(colNames, ', '));
        end
        rethrow(ME);
    end
end
