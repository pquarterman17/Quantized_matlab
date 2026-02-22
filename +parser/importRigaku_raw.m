function data = importRigaku_raw(filepath, options)
%IMPORTRIGAKU_RAW  Import a Rigaku SmartLab .raw binary file (magic "FI").
%
%   data = parser.importRigaku_raw('scan.raw')
%   data = parser.importRigaku_raw('scan.raw', 'UseCountsPerSec', true)
%   data = parser.importRigaku_raw('scan.raw', 'Verbose', true)
%
%   Reads a Rigaku SmartLab binary .raw file and returns a standardised
%   data struct compatible with the toolbox plotting functions.
%
%   BINARY FORMAT (Rigaku SmartLab, magic bytes "FI"):
%     Bytes    1-2   : Magic identifier "FI"
%     Bytes 2959-2962: Counting time per step (float32, seconds)
%     Bytes 2963-2966: Starting 2θ angle      (float32, degrees)
%     Bytes 2967-2970: Ending 2θ angle        (float32, degrees)
%     Bytes 2971-2974: Angular step size      (float32, degrees)
%     Bytes 3155-3158: Number of data points  (uint32)
%     Bytes 3159+    : Intensity data         (float32, 4 bytes/point)
%
%   INPUTS:
%       filepath - Path to the .raw file (string or char).
%
%   OPTIONAL NAME-VALUE PAIRS:
%       UseCountsPerSec - false (default) → intensity in raw counts
%                         true            → intensity / counting_time (counts/s)
%       Verbose         - Print a one-line import summary (default: false).
%
%   OUTPUT:
%       data - Unified data struct:
%                .time     [Nx1] 2θ angles (degrees)
%                .values   [Nx1] intensity (counts or counts/s)
%                .labels   {'Intensity'}
%                .units    {'counts'} or {'counts/s'}
%                .metadata struct with fields:
%                            .numPoints    - number of data points
%                            .startAngle   - starting 2θ (degrees)
%                            .endAngle     - ending 2θ (degrees)
%                            .stepSize     - angular step (degrees)
%                            .countingTime - counting time per step (seconds)
%                            .source       - source file path
%                            .importDate   - datetime of import
%
%   EXAMPLES:
%       data = parser.importRigaku_raw('YIG_Py_S7.raw');
%       plot(data.time, data.values);
%       xlabel('2\theta (°)');  ylabel(data.units{1});
%
%       % counts/s instead of raw counts
%       data = parser.importRigaku_raw('scan.raw', 'UseCountsPerSec', true);
%
%   See also parser.importAuto, parser.importCSV, parser.importQDVSM

    arguments
        filepath                (1,1) string {mustBeFile}
        options.UseCountsPerSec (1,1) logical = false
        options.Verbose         (1,1) logical = false
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 1: Read binary file
    % ════════════════════════════════════════════════════════════════
    fid = fopen(filepath, 'r');
    if fid == -1
        error('importRigaku_raw:cannotOpen', 'Cannot open file: %s', filepath);
    end
    raw = fread(fid, '*uint8');
    fclose(fid);

    nBytes = numel(raw);

    % ════════════════════════════════════════════════════════════════
    %  STEP 2: Validate format
    % ════════════════════════════════════════════════════════════════
    if nBytes < 3162   % 3158-byte header + at least one float32 (4 bytes)
        error('importRigaku_raw:fileTooSmall', ...
            'File too small to be a valid Rigaku SmartLab .raw (%d bytes): %s', ...
            nBytes, filepath);
    end

    magic = char(raw(1:2)');
    if ~strcmp(magic, 'FI')
        error('importRigaku_raw:badMagic', ...
            ['Unrecognised magic bytes "%s" (expected "FI").\n' ...
             'This file may not be a Rigaku SmartLab .raw: %s'], magic, filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 3: Extract header parameters  (all offsets are 1-indexed)
    % ════════════════════════════════════════════════════════════════
    countingTime = double(typecast(raw(2959:2962), 'single'));
    startAngle   = double(typecast(raw(2963:2966), 'single'));
    endAngle     = double(typecast(raw(2967:2970), 'single'));
    stepSize     = double(typecast(raw(2971:2974), 'single'));
    numPoints    = double(typecast(raw(3155:3158), 'uint32'));

    % Guard against nonsensical header values
    if stepSize <= 0 || stepSize > 10
        error('importRigaku_raw:badHeader', ...
            'Implausible step size (%.6g °) — file may not be a Rigaku SmartLab .raw.', ...
            stepSize);
    end

    % ── Validate numPoints against bytes actually present ─────────────
    nAvail = floor((nBytes - 3158) / 4);   % complete float32 words after header
    if numPoints == 0 || numPoints > nAvail
        if nAvail == 0
            error('importRigaku_raw:noData', ...
                'No data bytes found after the header block in: %s', filepath);
        end
        warning('importRigaku_raw:pointsMismatch', ...
            'Header numPoints (%d) exceeds available float32 words (%d); using file size.', ...
            numPoints, nAvail);
        numPoints = nAvail;
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 4: Read intensity data (float32, contiguous from byte 3159)
    % ════════════════════════════════════════════════════════════════
    dataBytes   = raw(3159 : 3158 + numPoints*4);
    intensities = double(typecast(dataBytes, 'single'));

    % ════════════════════════════════════════════════════════════════
    %  STEP 5: Build 2θ axis
    % ════════════════════════════════════════════════════════════════
    twoTheta = startAngle + (0 : numPoints-1)' * stepSize;

    % ════════════════════════════════════════════════════════════════
    %  STEP 6: Choose y-axis units
    % ════════════════════════════════════════════════════════════════
    if options.UseCountsPerSec && countingTime > 0
        yValues = intensities / countingTime;
        yUnit   = 'counts/s';
    else
        yValues = intensities;
        yUnit   = 'counts';
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 7: Assemble output struct
    % ════════════════════════════════════════════════════════════════
    meta.source       = char(filepath);
    meta.importDate   = datetime('now');
    meta.numPoints    = numPoints;
    meta.startAngle   = startAngle;
    meta.endAngle     = endAngle;
    meta.stepSize     = stepSize;
    meta.countingTime = countingTime;

    data = parser.createDataStruct(twoTheta, yValues, ...
        'labels',   {'Intensity'}, ...
        'units',    {yUnit}, ...
        'metadata', meta);

    if options.Verbose
        fprintf(['importRigaku_raw: %d pts  |  2\xB0 %.4f\xB0\x2013%.4f\xB0' ...
                 '  |  step %.4f\xB0  |  ct %.4g s  |  %s\n'], ...
            numPoints, startAngle, endAngle, stepSize, countingTime, filepath);
    end
end
