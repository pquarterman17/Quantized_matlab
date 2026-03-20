function data = importSIMS(filepath, options)
%IMPORTSIMS Import a SIMS depth profile CSV into a unified data struct.
%
%   data = parser.importSIMS('profile.csv')
%   data = parser.importSIMS('profile.csv', 'DepthUnit', 'nm')
%   data = parser.importSIMS('profile.csv', 'Verbose', true)
%
%   Reads SIMS (Secondary Ion Mass Spectrometry) depth profile data from
%   delimited text files. Handles the common paired-column layout where
%   each element has its own (depth, concentration) column pair, optionally
%   separated by empty columns.
%
%   AUTO-DETECTION:
%     - Delimiter: comma, tab, semicolon, or space
%     - Header row and data start row
%     - Paired vs shared depth column layout
%     - Element names cleaned from mass numbers, charge states, unit suffixes
%     - Depth unit (nm or µm) from headers or metadata
%     - Concentration units from headers
%
%   PAIRED-COLUMN LAYOUT (most common):
%     After removing all-empty separator columns, the parser checks whether
%     odd columns are monotonically increasing (depth) and even columns are
%     concentration values. If so, each (odd, even) pair is treated as one
%     element. Otherwise, column 1 is used as the shared depth axis.
%
%   DEPTH GRID MERGING:
%     When elements have different depth ranges, a union grid is built from
%     the finest step size spanning the full depth range. Each element is
%     interpolated onto this grid using linear interpolation; NaN marks
%     regions outside the element's measured range.
%
%   INPUTS:
%       filepath - Path to the SIMS data file.
%
%   OPTIONAL NAME-VALUE PAIRS:
%       Delimiter    - Delimiter character. Default: auto-detect.
%       HeaderRow    - Row number containing column headers (-1 = auto).
%       DataStartRow - Row where numeric data begins (-1 = auto).
%       DepthUnit    - 'nm', 'um', or 'auto' (detect from headers).
%       Verbose      - Print summary after import. Default: false.
%
%   OUTPUT:
%       data - Unified data struct with fields:
%           .time     - [Nx1] union depth grid
%           .values   - [NxM] concentration matrix (M elements)
%           .labels   - element names {'Si', 'O', 'Fe', ...}
%           .units    - concentration units {'atoms/cm3', ...}
%           .metadata - import metadata including:
%               .parserSpecific.originalDepths  - {1xM} cell of raw depth vectors
%               .parserSpecific.originalConcentrations - {1xM} cell of raw conc vectors
%               .parserSpecific.headerMetadata  - pre-data text lines
%               .parserSpecific.depthUnit       - resolved depth unit string
%
%   EXAMPLES:
%       % Basic import — auto-detect everything
%       data = parser.importSIMS('sims_profile.csv');
%
%       % Force nanometer depth units
%       data = parser.importSIMS('sims_profile.csv', 'DepthUnit', 'nm');
%
%       % Access original per-element depth vectors
%       origD = data.metadata.parserSpecific.originalDepths;
%       origC = data.metadata.parserSpecific.originalConcentrations;
%
%   See also CREATEDATASTRUCT, IMPORTCSV, IMPORTAUTO

    arguments
        filepath         (1,1) string {mustBeFile}
        options.Delimiter    (1,1) string  = ""      % auto-detect
        options.HeaderRow    (1,1) double  = -1       % auto-detect
        options.DataStartRow (1,1) double  = -1       % auto-detect
        options.DepthUnit    (1,1) string  = "auto"   % "nm", "um", "auto"
        options.Verbose      (1,1) logical = false
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 1: Read raw lines
    % ════════════════════════════════════════════════════════════════
    rawLines = readRawLines(filepath);
    if isempty(rawLines)
        error('parser:importSIMS:emptyFile', ...
            'File is empty or contains only comments: %s', filepath);
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
    nDataCols = max(cellfun(@numel, tokens(dataStartRow:end)));
    if headerRow > 0
        colHeaders = strtrim(tokens{headerRow});
    else
        colHeaders = {};
    end

    % Pad / trim to match data width
    if numel(colHeaders) < nDataCols
        for k = numel(colHeaders)+1 : nDataCols
            colHeaders{k} = sprintf('Col%d', k);
        end
    elseif numel(colHeaders) > nDataCols
        colHeaders = colHeaders(1:nDataCols);
    end

    % Replace blank headers
    for k = 1:numel(colHeaders)
        if isempty(strtrim(colHeaders{k}))
            colHeaders{k} = sprintf('Col%d', k);
        end
    end

    % Capture pre-header metadata
    headerMetadata = {};
    if headerRow > 1
        for mi = 1:headerRow-1
            headerMetadata{end+1} = strjoin(strtrim(tokens{mi}), char(delim)); %#ok<AGROW>
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 6: Parse numeric data matrix
    % ════════════════════════════════════════════════════════════════
    dataRows = tokens(dataStartRow:end);
    numRows  = numel(dataRows);
    numCols  = numel(colHeaders);

    allTokens = cell(numRows, numCols);
    for r = 1:numRows
        row = dataRows{r};
        nC  = min(numel(row), numCols);
        for c = 1:nC
            allTokens{r,c} = strtrim(row{c});
        end
    end
    rawMatrix = str2double(allTokens);

    % ════════════════════════════════════════════════════════════════
    %  STEP 7: Remove empty separator columns (all-NaN)
    % ════════════════════════════════════════════════════════════════
    emptyMask   = all(isnan(rawMatrix), 1);
    rawMatrix   = rawMatrix(:, ~emptyMask);
    colHeaders  = colHeaders(~emptyMask);
    numCols     = size(rawMatrix, 2);

    if numCols < 2
        error('parser:importSIMS:tooFewColumns', ...
            'Need at least 2 non-empty columns; found %d in: %s', numCols, filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 8: Detect paired vs shared-depth layout
    % ════════════════════════════════════════════════════════════════
    isPaired = detectPairedLayout(rawMatrix);

    if isPaired
        % Odd columns (1,3,5,...) = depth; even columns (2,4,6,...) = concentration
        nPairs = floor(numCols / 2);
        depths = cell(1, nPairs);
        concs  = cell(1, nPairs);
        elemHeaders = cell(1, nPairs);
        for p = 1:nPairs
            dCol = rawMatrix(:, 2*p - 1);
            cCol = rawMatrix(:, 2*p);
            % Remove rows where both depth and conc are NaN
            valid = ~isnan(dCol) & ~isnan(cCol);
            depths{p} = dCol(valid);
            concs{p}  = cCol(valid);
            elemHeaders{p} = colHeaders{2*p};  % concentration column header
        end
    else
        % Column 1 = shared depth; columns 2..N = concentration
        nElements = numCols - 1;
        sharedDepth = rawMatrix(:, 1);
        depths = cell(1, nElements);
        concs  = cell(1, nElements);
        elemHeaders = cell(1, nElements);
        for e = 1:nElements
            cCol = rawMatrix(:, e + 1);
            valid = ~isnan(sharedDepth) & ~isnan(cCol);
            depths{e} = sharedDepth(valid);
            concs{e}  = cCol(valid);
            elemHeaders{e} = colHeaders{e + 1};
        end
    end

    nElements = numel(depths);

    % ════════════════════════════════════════════════════════════════
    %  STEP 9: Clean element names from headers
    % ════════════════════════════════════════════════════════════════
    [elemNames, concUnits] = cleanElementNames(elemHeaders);

    % ════════════════════════════════════════════════════════════════
    %  STEP 9b: Recover element names from pre-header rows
    %
    %  Some SIMS vendors place element names in a dedicated row
    %  *above* the Depth / CONC. header row.  In the original CSV,
    %  element names appear at depth-column positions with separator
    %  and concentration columns blank:
    %
    %    H  |    |    | C  |    |    | O  |    |    | ...
    %    Depth | CONC. |    | Depth | CONC. |    | ...
    %    (nm) | (atoms/cc) |    | (nm) | ...
    %
    %  We apply the same emptyMask column removal to each pre-header
    %  row, then check if odd positions (1,3,5,...) contain text while
    %  even positions are blank — the paired-name pattern.
    % ════════════════════════════════════════════════════════════════
    if isPaired && any(cellfun(@isempty, elemNames)) && headerRow > 1
        nE = numel(elemNames);
        for mi = 1:headerRow-1
            rowToks = tokens{mi};
            % Pad to match original data width, then apply emptyMask
            if numel(rowToks) < numel(emptyMask)
                rowToks(end+1 : numel(emptyMask)) = {''};
            elseif numel(rowToks) > numel(emptyMask)
                rowToks = rowToks(1:numel(emptyMask));
            end
            parts = strtrim(rowToks(~emptyMask));  % same columns kept in data

            if numel(parts) < 2 * nE
                parts(end+1 : 2*nE) = {''};
            end
            parts = parts(1 : 2 * nE);

            oddParts  = parts(1:2:end);   % depth column positions → element names
            evenParts = parts(2:2:end);   % conc column positions  → expected blank

            nEvenBlank = sum(cellfun(@isempty, evenParts));
            nOddText   = sum(cellfun( ...
                @(s) ~isempty(s) && isnan(str2double(s)), oddParts));

            % Accept when ≥50% of even slots are blank AND ≥50% of odd
            % slots are non-numeric text (robust to partially missing names)
            if nEvenBlank >= floor(nE * 0.5) && nOddText >= floor(nE * 0.5)
                for p = 1:nE
                    if isempty(elemNames{p}) && ~isempty(oddParts{p})
                        elemNames{p} = cleanVendorElement(oddParts{p});
                    end
                end
                break;
            end
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 10: Build union depth grid and interpolate
    % ════════════════════════════════════════════════════════════════
    [unionDepth, interpConcs] = buildUnionGrid(depths, concs);

    % ════════════════════════════════════════════════════════════════
    %  STEP 11: Detect depth unit
    % ════════════════════════════════════════════════════════════════
    if options.DepthUnit ~= "auto"
        depthUnit = char(options.DepthUnit);
    else
        depthUnit = detectDepthUnit(colHeaders, headerMetadata);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 12: Assemble output struct
    % ════════════════════════════════════════════════════════════════
    meta.source        = char(filepath);
    meta.importDate    = datetime('now');
    meta.parserName    = 'importSIMS';
    meta.parserVersion = '1.0';
    meta.xColumnName   = 'Depth';
    meta.xColumnUnit   = depthUnit;

    meta.parserSpecific.headerMetadata         = headerMetadata;
    meta.parserSpecific.originalDepths          = depths;
    meta.parserSpecific.originalConcentrations  = concs;
    meta.parserSpecific.depthUnit               = depthUnit;
    meta.parserSpecific.isPairedLayout          = isPaired;

    data = parser.createDataStruct(unionDepth, interpConcs, ...
        'labels', elemNames, 'units', concUnits, 'metadata', meta);

    if options.Verbose
        fprintf('Imported %d depth points x %d elements from %s\n', ...
            numel(unionDepth), nElements, filepath);
    end
end


% ════════════════════════════════════════════════════════════════════
%  LOCAL HELPER FUNCTIONS
% ════════════════════════════════════════════════════════════════════

function rawLines = readRawLines(filepath)
%READRAWLINES Read file, strip blank and comment lines.
    allLines = readlines(filepath);
    allLines = strtrim(allLines);

    % Remove blank lines and comment lines (# or %)
    mask = allLines ~= "";
    for c = ["#", "%"]
        mask = mask & ~startsWith(allLines, c);
    end
    rawLines = cellstr(allLines(mask));
end


function delim = detectDelimiter(rawLines)
%DETECTDELIMITER Auto-detect the most likely delimiter.
    candidates = {',', sprintf('\t'), ';', ' '};
    scores = zeros(size(candidates));
    testLines = rawLines(1:min(10, numel(rawLines)));

    for d = 1:numel(candidates)
        ch = candidates{d};
        counts = zeros(numel(testLines), 1);
        for r = 1:numel(testLines)
            counts(r) = numel(strfind(testLines{r}, ch));
        end
        if all(counts > 0) && std(counts) < mean(counts) * 0.5
            scores(d) = mean(counts);
        end
    end

    [~, best] = max(scores);
    if scores(best) > 0
        delim = candidates{best};
    else
        delim = ',';
    end
end


function tokens = splitLines(rawLines, delim)
%SPLITLINES Split each raw line by the delimiter.
    tokens = cell(numel(rawLines), 1);
    pat = regexptranslate('escape', char(delim));
    for i = 1:numel(rawLines)
        tokens{i} = regexp(rawLines{i}, pat, 'split');
    end
end


function [headerRow, dataStartRow] = detectLayout(tokens, hdrOpt, dsOpt)
%DETECTLAYOUT Find header row and first data row.
    N = numel(tokens);

    if hdrOpt >= 0 && dsOpt >= 0
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
            if ~isnan(str2double(strtrim(row{j})))
                nNum = nNum + 1;
            end
        end
        numericScore(i) = nNum / max(nFields, 1);
    end

    % First row that is >50% numeric
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
    elseif firstDataIdx > 1
        % Walk backward past blank rows (all tokens empty) to find real header
        candidate = firstDataIdx - 1;
        while candidate >= 1
            row = tokens{candidate};
            hasContent = any(cellfun(@(s) ~isempty(strtrim(s)), row));
            if hasContent && numericScore(candidate) < 0.5
                break;
            end
            candidate = candidate - 1;
        end
        if candidate >= 1
            headerRow = candidate;
        else
            headerRow = 0;
        end
    else
        headerRow = 0;
    end
end


function isPaired = detectPairedLayout(rawMatrix)
%DETECTPAIREDLAYOUT Check if data uses paired (depth, conc) column layout.
%   Returns true if:
%     - There are an even number of columns (≥4)
%     - Odd columns (1,3,5,...) are mostly monotonically increasing (depth)
%     - The monotonic check uses the non-NaN portion of each odd column
    [~, nCols] = size(rawMatrix);

    if nCols < 4 || mod(nCols, 2) ~= 0
        isPaired = false;
        return;
    end

    nMonotonic = 0;
    nOdd = floor(nCols / 2);
    for k = 1:nOdd
        col = rawMatrix(:, 2*k - 1);
        col = col(~isnan(col));
        if numel(col) >= 2 && all(diff(col) > 0)
            nMonotonic = nMonotonic + 1;
        end
    end

    % Require at least 80% of odd columns to be monotonic
    isPaired = (nMonotonic / nOdd) >= 0.8;
end


function [elemNames, concUnits] = cleanElementNames(headers)
%CLEANELEMENTNAMES Extract element names and units from column headers.
%   Handles patterns like:
%     '28Si'         → 'Si'     (mass number prefix)
%     'O16+'         → 'O'      (mass number suffix + charge state)
%     'Si (at/cm3)'  → 'Si', unit='at/cm3'
%     'Fe56+'        → 'Fe'     (element + mass + charge)
%     'Ga'           → 'Ga'     (plain element symbol)
%     'Depth Si'     → 'Si'     (depth prefix from paired header)
    nE = numel(headers);
    elemNames = cell(1, nE);
    concUnits = cell(1, nE);

    for i = 1:nE
        h = strtrim(headers{i});

        % Step 0: bare unit string — entire header is wrapped in parentheses,
        % e.g. "(atoms/cc)" or "(arb. units)".  This happens when the parser
        % selects the units row as the column header row (vendor multi-row header layout).
        matchBare = regexp(h, '^\(([^)]+)\)$', 'tokens', 'once');
        if ~isempty(matchBare)
            elemNames{i} = '';
            concUnits{i} = strtrim(matchBare{1});
            continue;
        end

        % Step 1: extract unit in parentheses or brackets
        unit = '';
        matchP = regexp(h, '(.+?)\s*\(([^)]+)\)\s*$', 'tokens', 'once');
        if ~isempty(matchP)
            h = strtrim(matchP{1});
            unit = strtrim(matchP{2});
        else
            matchB = regexp(h, '(.+?)\s*\[([^\]]+)\]\s*$', 'tokens', 'once');
            if ~isempty(matchB)
                h = strtrim(matchB{1});
                unit = strtrim(matchB{2});
            end
        end

        % Step 2: strip 'Conc' or 'Concentration' prefix (case-insensitive)
        h = regexprep(h, '^\s*(?:Conc(?:entration)?)\s+', '', 'ignorecase');

        % Step 3: strip leading mass number: '28Si' → 'Si'
        matchMass = regexp(h, '^\d+([A-Z][a-z]?)', 'tokens', 'once');
        if ~isempty(matchMass)
            h = matchMass{1};
        end

        % Step 4: strip trailing mass + charge: 'Fe56+' or 'O16-' → element
        matchTrail = regexp(h, '^([A-Z][a-z]?)\d+[+\-]?$', 'tokens', 'once');
        if ~isempty(matchTrail)
            h = matchTrail{1};
        end

        % Step 5: strip trailing charge state only: 'O+' → 'O'
        h = regexprep(h, '[+\-]+$', '');

        elemNames{i} = h;
        concUnits{i} = unit;
    end
end


function [unionDepth, interpConcs] = buildUnionGrid(depths, concs)
%BUILDUNIONGRID Build a union depth grid and interpolate all elements onto it.
    nE = numel(depths);

    % Check if all depth vectors are identical (shared grid → no interpolation)
    allSame = true;
    if nE > 1
        for e = 2:nE
            if numel(depths{e}) ~= numel(depths{1}) || ...
                    any(abs(depths{e} - depths{1}) > eps(max(abs(depths{1}))) * 10)
                allSame = false;
                break;
            end
        end
    end

    if allSame && ~isempty(depths{1})
        % No interpolation needed — all share the same grid
        unionDepth = depths{1}(:);
        interpConcs = zeros(numel(unionDepth), nE);
        for e = 1:nE
            interpConcs(:, e) = concs{e}(:);
        end
        return;
    end

    % Find global min/max and finest step
    allMin   = inf;
    allMax   = -inf;
    minStep  = inf;
    for e = 1:nE
        d = depths{e};
        if isempty(d), continue; end
        allMin  = min(allMin, min(d));
        allMax  = max(allMax, max(d));
        steps   = diff(d);
        posStep = steps(steps > 0);
        if ~isempty(posStep)
            minStep = min(minStep, min(posStep));
        end
    end

    if isinf(minStep) || allMin >= allMax
        % Degenerate case: return first element's grid
        unionDepth = depths{1}(:);
        interpConcs = zeros(numel(unionDepth), nE);
        for e = 1:nE
            interpConcs(:, e) = concs{e}(:);
        end
        return;
    end

    % Build union grid
    unionDepth = (allMin : minStep : allMax)';
    % Ensure allMax is included
    if unionDepth(end) < allMax
        unionDepth(end+1) = allMax;
    end

    % Interpolate each element onto the union grid
    interpConcs = NaN(numel(unionDepth), nE);
    for e = 1:nE
        d = depths{e};
        c = concs{e};
        if numel(d) < 2
            % Single point: place it at the nearest grid location
            if ~isempty(d)
                [~, idx] = min(abs(unionDepth - d(1)));
                interpConcs(idx, e) = c(1);
            end
            continue;
        end
        % Interpolate, NaN outside the element's measured range
        interpConcs(:, e) = interp1(d, c, unionDepth, 'linear', NaN);
    end
end


function depthUnit = detectDepthUnit(colHeaders, headerMetadata)
%DETECTDEPTHUNIT Detect depth unit from headers and metadata.
    depthUnit = 'nm';  % default

    % Search all column headers
    allText = strjoin(colHeaders, ' ');
    % Also search metadata lines
    if ~isempty(headerMetadata)
        allText = [allText, ' ', strjoin(headerMetadata, ' ')];
    end

    allTextLower = lower(allText);
    if contains(allTextLower, 'um') || contains(allTextLower, char(181)) || ...  % µm
       contains(allTextLower, 'micron') || contains(allTextLower, 'micrometer')
        depthUnit = 'um';
    elseif contains(allTextLower, 'nm') || contains(allTextLower, 'nanometer')
        depthUnit = 'nm';
    elseif contains(allTextLower, 'angstrom') || contains(allText, char(197))  % Å
        depthUnit = 'A';
    end
end


function name = cleanVendorElement(raw)
%CLEANVENDORELEMENT  Normalize a raw element name from a vendor header row.
%   Strips trailing '->' or '-->' (Eurofins/EAG arb-units marker) and
%   normalizes capitalization to standard element symbols (first letter
%   uppercase, rest lowercase): 'AL->' → 'Al', 'SI' → 'Si', 'TA' → 'Ta'.
    name = regexprep(raw, '-+>$', '');   % strip -> or -->
    name = strtrim(name);
    if ~isempty(name) && all(isstrprop(name, 'alpha'))
        name = [upper(name(1)), lower(name(2:end))];
    end
end
