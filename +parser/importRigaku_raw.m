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
%       UseCountsPerSec     - false (default) → intensity in raw counts
%                             true            → intensity / counting_time (counts/s)
%       AllowPartialImport  - false (default) → error if multi-range file detected
%                             true            → warn and import first range only
%       Verbose             - Print a one-line import summary (default: false).
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
%   LIMITATIONS:
%       • Multi-range files: only the first scan range is imported (see AllowPartialImport).
%       • Variable-step scans: not supported (errors on stepSize = 0).
%       • Rigaku magic bytes "FI" are required; Bruker files (magic "RAW") are rejected.
%
%   EXAMPLES:
%       data = parser.importRigaku_raw('YIG_Py_S7.raw');
%       plot(data.time, data.values);
%       xlabel('2\theta (°)');  ylabel(data.units{1});
%
%       % counts/s instead of raw counts
%       data = parser.importRigaku_raw('scan.raw', 'UseCountsPerSec', true);
%
%       % Import multi-range file (warning only, no error)
%       data = parser.importRigaku_raw('multirange.raw', 'AllowPartialImport', true);
%
%   See also parser.importAuto, parser.importCSV, parser.importQDVSM

    arguments
        filepath                    (1,1) string {mustBeFile}
        options.UseCountsPerSec     (1,1) logical = false
        options.Verbose             (1,1) logical = false
        options.AllowPartialImport  (1,1) logical = false
    end

    % ─ Rigaku SmartLab binary format constants (1-indexed byte offsets) ─
    RGK_MAGIC          = 1:2;           % magic identifier "FI"
    RGK_COUNTING_TIME  = 2959:2962;     % float32: counting time per step (s)
    RGK_START_ANGLE    = 2963:2966;     % float32: starting 2θ (degrees)
    RGK_END_ANGLE      = 2967:2970;     % float32: ending 2θ (degrees)
    RGK_STEP_SIZE      = 2971:2974;     % float32: angular step size (degrees)
    RGK_NUM_POINTS     = 3155:3158;     % uint32:  number of data points
    RGK_HEADER_SIZE    = 3158;          % total header bytes before data
    RGK_DATA_START     = 3159;          % first byte of intensity float32 array
    RGK_MIN_FILE_SIZE  = 3162;          % minimum valid file: header + 1 float32

    % ════════════════════════════════════════════════════════════════
    %  STEP 1: Read binary file
    % ════════════════════════════════════════════════════════════════
    fid = fopen(filepath, 'r');
    if fid == -1
        error('parser:importRigaku_raw:cannotOpen', 'Cannot open file: %s', filepath);
    end
    cleanObj = onCleanup(@() fclose(fid));   %#ok<NASGU> — closes on error or normal exit
    raw = fread(fid, '*uint8');

    nBytes = numel(raw);

    % ════════════════════════════════════════════════════════════════
    %  STEP 2: Validate format
    % ════════════════════════════════════════════════════════════════
    if nBytes < RGK_MIN_FILE_SIZE   % 3158-byte header + at least one float32 (4 bytes)
        error('parser:importRigaku_raw:fileTooSmall', ...
            'File too small to be a valid Rigaku SmartLab .raw (%d bytes): %s', ...
            nBytes, filepath);
    end

    magic = char(raw(RGK_MAGIC)');
    if ~strcmp(magic, 'FI')
        error('parser:importRigaku_raw:badMagic', ...
            ['Unrecognised magic bytes "%s" (expected "FI").\n' ...
             'This file may not be a Rigaku SmartLab .raw: %s'], magic, filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 3: Extract header parameters  (all offsets are 1-indexed)
    % ════════════════════════════════════════════════════════════════
    countingTime = double(typecast(raw(RGK_COUNTING_TIME), 'single'));
    startAngle   = double(typecast(raw(RGK_START_ANGLE), 'single'));
    endAngle     = double(typecast(raw(RGK_END_ANGLE), 'single'));
    stepSize     = double(typecast(raw(RGK_STEP_SIZE), 'single'));
    numPoints    = double(typecast(raw(RGK_NUM_POINTS), 'uint32'));

    % Guard against nonsensical header values
    if stepSize == 0
        error('parser:importRigaku_raw:variableStep', ...
            ['Step size is zero — this may be a variable-step scan, which is not ' ...
             'supported by this parser. Export the file as fixed-step or use the ' ...
             'Rigaku software to convert it first.']);
    end
    if stepSize < 0 || stepSize > 10
        error('parser:importRigaku_raw:badHeader', ...
            'Implausible step size (%.6g °) — file may not be a Rigaku SmartLab .raw.', ...
            stepSize);
    end

    % ── Validate numPoints against bytes actually present ─────────────
    nAvail = floor((nBytes - RGK_HEADER_SIZE) / 4);   % complete float32 words after header
    if numPoints == 0 || numPoints > nAvail
        if nAvail == 0
            error('parser:importRigaku_raw:noData', ...
                'No data bytes found after the header block in: %s', filepath);
        end
        warning('parser:importRigaku_raw:pointsMismatch', ...
            'Header numPoints (%d) exceeds available float32 words (%d); using file size.', ...
            numPoints, nAvail);
        numPoints = nAvail;
    end

    % ── Detect multi-range files ──────────────────────────────────────
    % After the first range's data block, any remaining bytes indicate
    % additional scan ranges. By default, error on multi-range detection.
    firstRangeEnd = RGK_HEADER_SIZE + numPoints * 4;
    if nBytes > firstRangeEnd + 3
        if options.AllowPartialImport
            % User opted in: warn and continue with first range only
            warning('parser:importRigaku_raw:multiRange', ...
                ['Multi-range .raw file detected (%d bytes remain after first range). ' ...
                 'Only the first scan range (%.4f\xB0\x2013%.4f\xB0) is imported. ' ...
                 'Use Rigaku software to split ranges if full data is required.'], ...
                nBytes - firstRangeEnd, startAngle, endAngle);
        else
            % Default: prevent silent data loss
            error('parser:importRigaku_raw:multiRangeNotSupported', ...
                ['Multi-range .raw file detected (%d bytes remain after first range). ' ...
                 'This parser only imports the first range, which would result in silent data loss. ' ...
                 'Use AllowPartialImport=true to proceed with the first range only, ' ...
                 'or use Rigaku software to split ranges into separate files. ' ...
                 'File: %s'], ...
                nBytes - firstRangeEnd, filepath);
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  STEP 4: Read intensity data (float32, contiguous from byte RGK_DATA_START)
    % ════════════════════════════════════════════════════════════════
    dataBytes   = raw(RGK_DATA_START : RGK_HEADER_SIZE + numPoints*4);
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
    meta.source      = char(filepath);
    meta.importDate  = datetime('now');
    meta.parserName  = 'importRigaku_raw';
    meta.xColumnName = '2-Theta';
    meta.xColumnUnit = 'deg';

    meta.parserSpecific.numPoints    = numPoints;
    meta.parserSpecific.startAngle   = startAngle;
    meta.parserSpecific.endAngle     = endAngle;
    meta.parserSpecific.stepSize     = stepSize;
    meta.parserSpecific.countingTime = countingTime;

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
