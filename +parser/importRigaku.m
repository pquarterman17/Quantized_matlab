function data = importRigaku(filepath, options)
%IMPORTRIGAKU Import a Rigaku SmartLab XRD binary .raw file.
%
%   data = importRigaku('scan.raw')
%   data = importRigaku('scan.raw', 'UseCountsPerSec', true)
%   data = importRigaku('scan.raw', 'Verbose', false)
%
%   Reads a Rigaku SmartLab binary .raw file and returns a standardized
%   data struct compatible with all toolbox plotting functions.
%
%   BINARY FORMAT (Rigaku SmartLab .raw):
%     Bytes   5-8    : Number of data points (uint32)
%     Bytes 1217-1220: Counting time per step (float32, seconds)
%     Bytes 1257-1260: Angular step size (float32, degrees)
%     Bytes 3137-3140: Starting 2θ angle (float32, degrees)
%     Bytes 3141+    : Intensity data (uint32, 4 bytes per point)
%
%   INPUTS:
%       filepath - Path to the .raw file.
%
%   OPTIONAL NAME-VALUE PAIRS:
%       UseCountsPerSec - true  → y-axis is intensity / counting_time (default)
%                         false → y-axis is raw counts
%       Verbose         - Print import summary. Default: false.
%
%   OUTPUT:
%       data - Unified data struct with fields:
%                time     - [Nx1] 2θ angles (degrees)
%                values   - [Nx1] intensity (counts/s or counts)
%                labels   - {'Intensity'}
%                units    - {'counts/s'} or {'counts'}
%                metadata - struct with measurement parameters:
%                             .numPoints    - number of data points
%                             .startAngle   - starting 2θ (degrees)
%                             .stepSize     - angular step (degrees)
%                             .countingTime - time per step (seconds)
%                             .source, .importDate
%
%   EXAMPLES:
%       data = parser.importRigaku('YIG_001.raw');
%       plot(data.time, data.values);
%       xlabel(['2\theta (' char(176) ')']);
%       ylabel(data.labels{1});
%
%       % Raw counts instead of counts/s
%       data = parser.importRigaku('scan.raw', 'UseCountsPerSec', false);
%
%   See also IMPORTCSV, IMPORTEXCEL, CREATEDATASTRUCT

    arguments
        filepath              (1,1) string {mustBeFile}
        options.UseCountsPerSec (1,1) logical = true
        options.Verbose         (1,1) logical = false
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 1: Read binary file
    % ════════════════════════════════════════════════════════════════
    fid = fopen(filepath, 'r');
    if fid == -1
        error('importRigaku:cannotOpen', 'Cannot open file: %s', filepath);
    end
    raw = fread(fid, '*uint8');
    fclose(fid);

    nBytes = numel(raw);
    if nBytes < 3144
        error('importRigaku:fileTooSmall', ...
            'File is too small to be a valid Rigaku .raw (%d bytes): %s', ...
            nBytes, filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 2: Extract header parameters
    % ════════════════════════════════════════════════════════════════
    numPoints    = double(typecast(raw(5:8),       'uint32'));
    countingTime = double(typecast(raw(1217:1220),  'single'));
    stepSize     = double(typecast(raw(1257:1260),  'single'));
    startAngle   = double(typecast(raw(3137:3140),  'single'));

    if numPoints == 0 || numPoints > 1e6
        error('importRigaku:badHeader', ...
            'Unexpected number of points (%d) — file may not be a Rigaku .raw.', ...
            numPoints);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 3: Extract intensity data — row count from actual file bytes
    %  Data begins at byte 3141 (1-indexed). Each point is uint32 (4 bytes).
    %  numPoints from the header is used as a maximum / validation value;
    %  the number of rows actually returned is determined by what is present
    %  in the file, so truncated or oversized files are handled gracefully.
    % ════════════════════════════════════════════════════════════════
    dataOffset = 3141;
    dataBytes  = raw(dataOffset : end);          % everything after the header
    nAvail     = floor(numel(dataBytes) / 4);    % complete uint32 words present

    if nAvail == 0
        error('importRigaku:noData', ...
            'No data bytes found after the header block in: %s', filepath);
    end

    % Read all available uint32 values in one vectorised call
    rawInts = double(typecast(dataBytes(1 : nAvail*4), 'uint32'));

    % Skip leading header-remnant words (values > 100 000 are not scan data)
    startIdx = 1;
    for i = 2:numel(rawInts)
        if rawInts(i) < 1e5
            window = rawInts(i : min(i+9, numel(rawInts)));
            if all(window < 1e5)
                startIdx = i;
                break;
            end
        end
    end

    % Reconcile header-specified numPoints with bytes actually present.
    % If the file is truncated, use the smaller actual count and warn.
    % If the file has extra trailing bytes, trust the header value.
    availableFromStart = numel(rawInts) - startIdx + 1;
    if availableFromStart < numPoints
        warning('importRigaku:truncated', ...
            'File contains %d data points but header says %d; using available count.', ...
            availableFromStart, numPoints);
        numPoints = availableFromStart;
    end

    intensities = rawInts(startIdx : startIdx + numPoints - 1);

    % ════════════════════════════════════════════════════════════════
    %  STEP 4: Compute angular axis
    % ════════════════════════════════════════════════════════════════
    twoTheta = startAngle + (0:numPoints-1)' * stepSize;

    % ════════════════════════════════════════════════════════════════
    %  STEP 5: Choose y-axis
    % ════════════════════════════════════════════════════════════════
    if options.UseCountsPerSec && countingTime > 0
        yValues = intensities / countingTime;
        yUnit   = 'counts/s';
    else
        yValues = intensities;
        yUnit   = 'counts';
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 6: Assemble output struct
    % ════════════════════════════════════════════════════════════════
    meta.source       = char(filepath);
    meta.importDate   = datetime('now');
    meta.numPoints    = numPoints;
    meta.startAngle   = startAngle;
    meta.stepSize     = stepSize;
    meta.countingTime = countingTime;

    data = parser.createDataStruct(twoTheta, yValues, ...
        'labels',   {'Intensity'}, ...
        'units',    {yUnit}, ...
        'metadata', meta);

    if options.Verbose
        fprintf('importRigaku: %d points, 2\xB0 %.4f\xB0 to %.4f\xB0, step %.4f\xB0, %s\n', ...
            numPoints, min(twoTheta), max(twoTheta), stepSize, filepath);
    end
end
