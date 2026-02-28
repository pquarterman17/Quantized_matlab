function data = importBruker(filepath, options)
%IMPORTBRUKER  Import Bruker XRD files (.brml ZIP+XML or .raw binary v3).
%
%   Syntax
%   ──────
%   data = parser.importBruker(filepath)
%   data = parser.importBruker(filepath, Name=Value)
%
%   Inputs
%   ──────
%   filepath   (1,1) string   Path to the .brml or .raw file.
%
%   Name-Value Options
%   ──────────────────
%   RangeIndex      (1,1) double   Which range to import from multi-range
%                                   .raw files (default: 1). Ignored for .brml.
%   UseCountsPerSec (1,1) logical  Output intensity unit. false (default)
%                                   returns raw detector counts; true
%                                   divides by the per-point counting time.
%   Verbose         (1,1) logical  Print a formatted summary to the console
%                                   (default: false).
%
%   Outputs
%   ───────
%   data   Struct produced by parser.createDataStruct with fields:
%            .time        [Nx1]  2θ angles (degrees)
%            .values      [Nx1]  Intensity (counts or counts/s)
%            .labels      {'Intensity'}
%            .units       {'counts'} or {'counts/s'}
%            .metadata    Struct with parser-specific fields
%
%   Metadata fields (data.metadata)
%   ────────────────────────────────
%   .source              Full file path
%   .importDate          datetime of import
%   .parserName          'importBruker'
%   .xColumnName         '2-Theta'
%   .xColumnUnit         'deg'
%   .numPoints           Total number of data points imported
%   .startAngle          First 2θ position (deg)
%   .endAngle            Last 2θ position (deg)
%   .stepSize            Mean angular step size (deg)
%   .countingTime        Per-point counting time (seconds)
%   .parserSpecific      Struct with instrument-level detail
%
%   Supported Formats
%   ─────────────────
%   .brml  — ZIP archive containing RawData0.xml (Bruker XML format)
%   .raw   — Binary file with magic bytes "RAW1.01" (v3 format); v2.00 and
%            v4.00 are not supported (please provide an example file).
%
%   Examples
%   ────────
%   % Bruker ZIP+XML
%   d = parser.importBruker('scan.brml');
%
%   % Bruker binary v3
%   d = parser.importBruker('scan.raw', 'UseCountsPerSec', true);
%
%   % Verbose output
%   d = parser.importBruker('scan.raw', 'Verbose', true);
%
%   See also IMPORTXRDML, IMPORTRIGAKU_RAW, IMPORTAUTO

    arguments
        filepath                (1,1) string {mustBeFile}
        options.RangeIndex      (1,1) double  = 1
        options.UseCountsPerSec (1,1) logical = false
        options.Verbose         (1,1) logical = false
    end

    [~, ~, ext] = fileparts(filepath);
    ext = lower(ext);

    % ════════════════════════════════════════════════════════════════════════
    %  Dispatch by extension
    % ════════════════════════════════════════════════════════════════════════
    if strcmpi(ext, '.brml')
        data = parseBRML(filepath, options);
    else   % .raw
        data = parseRawBinary(filepath, options);
    end
end


% ════════════════════════════════════════════════════════════════════════════
%  .brml parser: ZIP + XML
% ════════════════════════════════════════════════════════════════════════════

function data = parseBRML(filepath, options)
%PARSEBRML  Parse a Bruker .brml (ZIP archive with XML) file.

    % ════════════════════════════════════════════════════════════════════════
    %  1. Extract ZIP contents
    % ════════════════════════════════════════════════════════════════════════
    tmpDir = tempname();
    mkdir(tmpDir);
    cleanObj = onCleanup(@() rmdir(tmpDir, 's'));

    try
        unzip(filepath, tmpDir);
    catch ME
        error('parser:importBruker:unzipFailed', ...
            'Failed to extract .brml ZIP archive "%s": %s', filepath, ME.message);
    end

    % ════════════════════════════════════════════════════════════════════════
    %  2. Locate RawData0.xml
    % ════════════════════════════════════════════════════════════════════════
    xmlFiles = dir(fullfile(tmpDir, '**', 'RawData0.xml'));
    if isempty(xmlFiles)
        error('parser:importBruker:noRawData', ...
            'Could not find RawData0.xml in .brml archive. The file structure may differ.');
    end
    rawDataXml = fullfile(xmlFiles(1).folder, xmlFiles(1).name);

    % ════════════════════════════════════════════════════════════════════════
    %  3. Parse XML document
    % ════════════════════════════════════════════════════════════════════════
    try
        dom = xmlread(rawDataXml);
    catch ME
        error('parser:importBruker:xmlParseFailed', ...
            'Failed to parse RawData0.xml: %s', ME.message);
    end

    % ════════════════════════════════════════════════════════════════════════
    %  4. Find and validate DataRoute element
    % ════════════════════════════════════════════════════════════════════════
    dataRoutes = dom.getElementsByTagName('DataRoute');
    nRanges = dataRoutes.getLength;

    if nRanges == 0
        error('parser:importBruker:noDataRoute', ...
            'No <DataRoute> elements found in RawData0.xml.');
    end

    rangeIdx = min(options.RangeIndex, nRanges);   % clamp to available range
    if options.RangeIndex > nRanges && options.Verbose
        fprintf('RangeIndex %d exceeds available ranges (%d); using %d\n', ...
            options.RangeIndex, nRanges, rangeIdx);
    end

    dataRoute = dataRoutes.item(rangeIdx - 1);

    % ════════════════════════════════════════════════════════════════════════
    %  5. Extract scan parameters
    % ════════════════════════════════════════════════════════════════════════
    scanInfoNodes = dataRoute.getElementsByTagName('ScanInformation');
    if scanInfoNodes.getLength == 0
        error('parser:importBruker:noScanInfo', ...
            'No <ScanInformation> found in selected <DataRoute>.');
    end
    scanInfo = scanInfoNodes.item(0);

    startPosition       = nodeDouble(scanInfo, 'StartPosition');
    stepSize            = nodeDouble(scanInfo, 'StepSize');
    measuredTimePerStep = nodeDouble(scanInfo, 'MeasuredTimePerStep');
    numberOfSteps       = nodeDouble(scanInfo, 'NumberOfSteps');
    sweepScanAxis       = nodeText(scanInfo, 'SweepScanAxis');

    if isnan(startPosition) || isnan(stepSize) || isnan(numberOfSteps)
        error('parser:importBruker:incompleteScanInfo', ...
            'StartPosition, StepSize, or NumberOfSteps missing or invalid.');
    end

    % ════════════════════════════════════════════════════════════════════════
    %  6. Extract data points (Datum elements)
    % ════════════════════════════════════════════════════════════════════════
    datumNodes = dataRoute.getElementsByTagName('Datum');
    nData = datumNodes.getLength;

    if nData == 0
        error('parser:importBruker:noData', ...
            'No <Datum> elements found in <DataRoute>.');
    end

    % Collect all datum text and parse into a numeric matrix
    allCounts = [];
    for d = 0 : nData - 1
        datumNode = datumNodes.item(d);
        txt = strtrim(char(datumNode.getTextContent()));
        if ~isempty(txt)
            % Each datum may contain comma-separated values
            vals = str2double(strsplit(txt, ','));
            allCounts = [allCounts; vals(:)];  %#ok<AGROW>
        end
    end

    if isempty(allCounts)
        error('parser:importBruker:emptyData', ...
            'No numeric data extracted from <Datum> elements.');
    end

    % ════════════════════════════════════════════════════════════════════════
    %  7. Determine column structure and extract counts
    % ════════════════════════════════════════════════════════════════════════
    nCols = size(allCounts, 2);
    nRows = size(allCounts, 1);

    if nCols == 1
        % Only counts — reconstruct 2theta from StartPosition/StepSize
        counts = allCounts(:, 1);
        twoTheta = startPosition + (0 : nRows-1)' * stepSize;
    else
        % Multiple columns: assume first is 2theta, last is counts
        twoTheta = allCounts(:, 1);
        counts   = allCounts(:, nCols);
    end

    % ════════════════════════════════════════════════════════════════════════
    %  8. Extract wavelength
    % ════════════════════════════════════════════════════════════════════════
    wavelength_A = NaN;
    fixedInfoNodes = dom.getElementsByTagName('FixedInformation');
    if fixedInfoNodes.getLength > 0
        fixedInfo = fixedInfoNodes.item(0);
        wlNodes = fixedInfo.getElementsByTagName('Wavelength');
        if wlNodes.getLength > 0
            wl = wlNodes.item(0);
            wavelength_A = nodeDouble(wl, 'Alpha1');
        end
    end

    % ════════════════════════════════════════════════════════════════════════
    %  9. Choose intensity output
    % ════════════════════════════════════════════════════════════════════════
    if options.UseCountsPerSec && ~isnan(measuredTimePerStep) && measuredTimePerStep > 0
        yValues = counts / measuredTimePerStep;
        yUnit   = 'counts/s';
    else
        yValues = counts;
        yUnit   = 'counts';
    end

    % ════════════════════════════════════════════════════════════════════════
    %  10. Assemble output struct
    % ════════════════════════════════════════════════════════════════════════
    meta.source       = char(filepath);
    meta.importDate   = datetime('now');
    meta.parserName   = 'importBruker';
    meta.xColumnName  = '2-Theta';
    meta.xColumnUnit  = 'deg';
    meta.numPoints    = numel(twoTheta);
    meta.startAngle   = twoTheta(1);
    meta.endAngle     = twoTheta(end);
    meta.stepSize     = mean(diff(twoTheta), 'omitnan');
    meta.countingTime = measuredTimePerStep;

    meta.parserSpecific.formatType     = 'brml';
    meta.parserSpecific.wavelength_A   = wavelength_A;
    meta.parserSpecific.scanAxis       = sweepScanAxis;
    meta.parserSpecific.rangeIndex     = rangeIdx;
    meta.parserSpecific.totalRanges    = nRanges;

    data = parser.createDataStruct(twoTheta(:), yValues(:), ...
        'labels',   {'Intensity'}, ...
        'units',    {yUnit}, ...
        'metadata', meta);

    if options.Verbose
        fprintf(['importBruker (.brml): %d pts  |  2θ %.4f°–%.4f°  |  step %.6f°  |' ...
                 '  ct %.3g s  |  %s\n'], ...
            numel(twoTheta), twoTheta(1), twoTheta(end), ...
            meta.stepSize, measuredTimePerStep, filepath);
    end
end


% ════════════════════════════════════════════════════════════════════════════
%  .raw parser: Binary v3 format (RAW1.01)
% ════════════════════════════════════════════════════════════════════════════

function data = parseRawBinary(filepath, options)
%PARSERAWBINARY  Parse a Bruker .raw binary file (v3, magic "RAW1.01").

    % ════════════════════════════════════════════════════════════════════════
    %  1. Read binary file
    % ════════════════════════════════════════════════════════════════════════
    fid = fopen(filepath, 'r');
    if fid == -1
        error('parser:importBruker:cannotOpen', ...
            'Cannot open file: %s', filepath);
    end
    cleanObj = onCleanup(@() fclose(fid));
    raw = fread(fid, '*uint8');
    nBytes = numel(raw);

    % ════════════════════════════════════════════════════════════════════════
    %  2. Validate file size and magic bytes
    % ════════════════════════════════════════════════════════════════════════
    if nBytes < 800
        error('parser:importBruker:fileTooSmall', ...
            'File too small to contain header: %d bytes', nBytes);
    end

    magic = char(raw(1:7)');
    if strcmp(magic, 'RAW2.00') || strcmp(magic, 'RAW4.00')
        error('parser:importBruker:unsupportedVersion', ...
            ['Bruker .raw format "%s" is not currently supported.\n' ...
             'Currently only RAW1.01 (v3) is implemented.\n' ...
             'Please provide an example file to add support for this version.'], magic);
    elseif ~strcmp(magic, 'RAW1.01')
        error('parser:importBruker:badMagic', ...
            ['Unrecognised magic bytes "%s" (expected "RAW1.01").\n' ...
             'This file may not be a Bruker .raw v3.'], magic);
    end

    % ════════════════════════════════════════════════════════════════════════
    %  3. Count number of ranges (at offset 13-16, 1-indexed)
    % ════════════════════════════════════════════════════════════════════════
    nRangesBytes = raw(13:16);
    nRanges = double(typecast(uint8(nRangesBytes), 'uint32'));

    rangeIdx = min(options.RangeIndex, nRanges);
    if options.RangeIndex > nRanges && options.Verbose
        fprintf('RangeIndex %d exceeds available ranges (%d); using %d\n', ...
            options.RangeIndex, nRanges, rangeIdx);
    end

    % ════════════════════════════════════════════════════════════════════════
    %  4. Read range headers and find the selected range
    % ════════════════════════════════════════════════════════════════════════
    % File preamble is 712 bytes; then each range has a 332-byte header
    % followed by (headerSize[+5:+8] / 4) float32 intensity values
    fileHeaderSize = 712;
    rangeHeaderSize = 332;
    currentOffset = fileHeaderSize;

    for r = 1 : rangeIdx
        if currentOffset + rangeHeaderSize > nBytes
            error('parser:importBruker:truncatedFile', ...
                'Range %d header extends beyond file size.', r);
        end

        % Extract this range's header
        rangeStart = currentOffset + 1;   % 1-indexed
        rangeEnd   = currentOffset + rangeHeaderSize;

        headerSizeBytes = raw(rangeStart : rangeStart + 3);
        headerSize = double(typecast(uint8(headerSizeBytes), 'uint32'));

        % Sanity check
        if headerSize ~= 332
            warning('parser:importBruker:unexpectedHeaderSize', ...
                ['Range %d has headerSize=%d (expected 332). ' ...
                 'File format may differ from documentation.'], r, headerSize);
        end

        % If this is the range we want, extract parameters
        if r == rangeIdx
            % Read parameters at documented offsets (relative to range start)
            nStepsBytes     = raw(rangeStart + 12 : rangeStart + 15);
            nSteps          = double(typecast(uint8(nStepsBytes), 'uint32'));

            startAngleBytes = raw(rangeStart + 44 : rangeStart + 47);
            startAngle      = double(typecast(uint8(startAngleBytes), 'single'));

            stepSizeBytes   = raw(rangeStart + 48 : rangeStart + 51);
            stepSize        = double(typecast(uint8(stepSizeBytes), 'single'));

            timePerStepBytes = raw(rangeStart + 56 : rangeStart + 59);
            timePerStep      = double(typecast(uint8(timePerStepBytes), 'single'));

            wavelengthBytes = raw(rangeStart + 88 : rangeStart + 91);
            wavelength_A    = double(typecast(uint8(wavelengthBytes), 'single'));

            % Sanity checks
            if startAngle < -10 || startAngle > 180
                warning('parser:importBruker:suspiciousAngle', ...
                    'Start angle %.2f° is outside normal XRD range [-10°, 180°].', startAngle);
            end
            if stepSize < 0.0001 || stepSize > 5
                warning('parser:importBruker:suspiciousStepSize', ...
                    'Step size %.6f° is outside normal range [0.0001°, 5°].', stepSize);
            end
            if nSteps < 1 || nSteps > 1e6
                warning('parser:importBruker:suspiciousNSteps', ...
                    'Number of steps %d is implausible.', nSteps);
            end

            % Data starts after the range header (offset 333 relative to range start)
            dataStart = rangeStart + 332;
            nDataBytes = nSteps * 4;
            if dataStart + nDataBytes - 1 > nBytes
                error('parser:importBruker:truncatedData', ...
                    'Data block for range %d extends beyond file size.', rangeIdx);
            end

            dataBytes  = raw(dataStart : dataStart + nDataBytes - 1);
            intensities = double(typecast(uint8(dataBytes), 'single'));

            % Build 2theta axis
            twoTheta = startAngle + (0 : nSteps-1)' * stepSize;

            % Choose output unit
            if options.UseCountsPerSec && timePerStep > 0
                yValues = intensities / timePerStep;
                yUnit   = 'counts/s';
            else
                yValues = intensities;
                yUnit   = 'counts';
            end

            % Assemble output
            meta.source       = char(filepath);
            meta.importDate   = datetime('now');
            meta.parserName   = 'importBruker';
            meta.xColumnName  = '2-Theta';
            meta.xColumnUnit  = 'deg';
            meta.numPoints    = nSteps;
            meta.startAngle   = startAngle;
            meta.endAngle     = twoTheta(end);
            meta.stepSize     = stepSize;
            meta.countingTime = timePerStep;

            meta.parserSpecific.formatType  = 'raw_binary_v3';
            meta.parserSpecific.wavelength_A = wavelength_A;
            meta.parserSpecific.rangeIndex  = rangeIdx;
            meta.parserSpecific.totalRanges = nRanges;

            data = parser.createDataStruct(twoTheta, yValues, ...
                'labels',   {'Intensity'}, ...
                'units',    {yUnit}, ...
                'metadata', meta);

            if options.Verbose
                fprintf(['importBruker (.raw v3): %d pts  |  2θ %.4f°–%.4f°  |  step %.6f°  |' ...
                         '  ct %.3g s  |  %s\n'], ...
                    nSteps, startAngle, twoTheta(end), stepSize, timePerStep, filepath);
            end
            return;   % Done — exit after processing selected range
        end

        % Move to next range's header
        dataSizeBytes = raw(rangeStart + 4 : rangeStart + 7);
        dataSize = double(typecast(uint8(dataSizeBytes), 'uint32'));
        currentOffset = currentOffset + rangeHeaderSize + dataSize;
    end
end


% ════════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════════

function val = nodeDouble(parent, tagName)
%NODEDOUBLE  Numeric value of the first matching child element, or NaN.
    val   = NaN;
    nodes = parent.getElementsByTagName(tagName);
    if nodes.getLength > 0
        val = str2double(strtrim(char(nodes.item(0).getTextContent())));
    end
end

function txt = nodeText(parent, tagName)
%NODETEXT  Trimmed text of the first matching child element, or ''.
    txt   = '';
    nodes = parent.getElementsByTagName(tagName);
    if nodes.getLength > 0
        txt = strtrim(char(nodes.item(0).getTextContent()));
    end
end
