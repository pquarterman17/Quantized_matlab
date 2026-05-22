function data = importAFM(filepath, options)
%IMPORTAFM  Import Bruker NanoScope AFM/SPM files (.spm, .000, .001, ...).
%
%   Bruker NanoScope files contain an ASCII header with backslash-delimited
%   sections followed by binary image data. Each image channel (Height,
%   Phase, Amplitude, etc.) is stored as a separate data block. This parser
%   extracts the first image channel (typically Height) and converts to
%   physical units using the Z scale calibration.
%
%   Syntax
%   ------
%   data = parser.importAFM(filepath)
%   data = parser.importAFM(filepath, Channel="Height")
%   data = parser.importAFM(filepath, Verbose=true)
%
%   Inputs
%   ------
%   filepath   (1,1) string   Path to a .spm / .000 / .001 file.
%
%   Name-Value Options
%   ------------------
%   Channel    string   Channel name to extract (default: first available).
%                       Common names: "Height", "Phase", "Amplitude",
%                       "Height Sensor", "Peak Force Error".
%   Verbose    logical  Print summary after import (default: false).
%
%   Outputs
%   -------
%   data   Struct produced by parser.createDataStruct with fields:
%
%     .time        [Hx1]  Row pixel indices 1..H
%     .values      [Hx1]  Mean height/signal per row
%     .labels      {'Mean <channel>'}
%     .units       {'<z_unit>'}
%     .metadata.parserSpecific
%       .isImage           true
%       .imageData         Standard imageData struct:
%         .pixels          [HxW] double — calibrated height map in physical units
%         .bitDepth        16 or 32
%         .height          H (pixels)
%         .width           W (pixels)
%         .numChannels     1
%         .numFrames       1
%         .frames          {}
%         .pixelSize       Physical size per pixel (nm or um)
%         .pixelUnit       'nm' or 'um'
%         .calibrated      logical
%         .acquiParams     struct with AFM acquisition parameters
%       .allChannels       Cell array of available channel names
%       .channelName       Name of the extracted channel
%       .scanSize          [width height] in scanUnit
%       .scanUnit          'nm' or 'um'
%       .zScale            Z sensitivity * Z scale factor
%       .zUnit             Physical unit of Z axis
%
%   Supported Formats
%   -----------------
%   Bruker NanoScope V5+ (.spm) and numbered exports (.000, .001, ...).
%   Files must begin with '\*Force file list' or '\*File list' header.
%
%   See also parser.createDataStruct

    arguments
        filepath              (1,1) string {mustBeFile}
        options.Channel       string = ""
        options.Verbose       (1,1) logical = false
    end

    fp = char(filepath);

    % ── Read header ──────────────────────────────────────────────────────
    fid = fopen(fp, 'r', 'ieee-le');
    if fid == -1
        error('parser:importAFM:fileOpen', 'Cannot open file: %s', fp);
    end
    cleanupObj = onCleanup(@() fclose(fid));

    % Read ASCII header (terminated by \*File list end or 0x1A byte)
    headerLines = {};
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line), break; end
        headerLines{end+1} = line; %#ok<AGROW>
        if contains(line, '\*File list end')
            break;
        end
    end
    headerEndPos = ftell(fid);
    headerText = strjoin(headerLines, newline);

    % Validate this is a NanoScope file
    if isempty(headerLines) || ...
            (~contains(headerLines{1}, '\*Force file list') && ...
             ~contains(headerLines{1}, '\*File list'))
        error('parser:importAFM:notNanoScope', ...
            'Not a Bruker NanoScope file: header does not start with \\*File list');
    end

    % ── Parse header sections ────────────────────────────────────────────
    sections = parseNanoScopeHeader(headerLines);

    % ── Find image channels ──────────────────────────────────────────────
    imageSections = sections(strcmp({sections.type}, 'Ciao image list'));
    if isempty(imageSections)
        error('parser:importAFM:noImages', 'No image channels found in header.');
    end

    % Get channel names
    allChannels = cell(1, numel(imageSections));
    for i = 1:numel(imageSections)
        allChannels{i} = getField(imageSections(i), '@2:Image Data', sprintf('Channel %d', i));
        % Clean up: extract just the channel name from the descriptor
        tok = regexp(allChannels{i}, '"([^"]+)"', 'tokens', 'once');
        if ~isempty(tok), allChannels{i} = tok{1}; end
    end

    % Select channel
    if options.Channel == ""
        chIdx = 1;  % default: first channel
    else
        chIdx = find(strcmpi(allChannels, options.Channel), 1);
        if isempty(chIdx)
            error('parser:importAFM:channelNotFound', ...
                'Channel "%s" not found. Available: %s', ...
                options.Channel, strjoin(allChannels, ', '));
        end
    end
    imgSection = imageSections(chIdx);
    channelName = allChannels{chIdx};

    % ── Extract image parameters ─────────────────────────────────────────
    dataOffset  = getNumericField(imgSection, 'Data offset', 0);
    dataLength  = getNumericField(imgSection, 'Data length', 0);
    bytesPerPx  = getNumericField(imgSection, 'Bytes/pixel', 2);
    nLines      = getNumericField(imgSection, 'Number of lines', 0);
    sampsPerLine = getNumericField(imgSection, 'Samps/line', 0);

    if nLines == 0 || sampsPerLine == 0
        error('parser:importAFM:badDimensions', ...
            'Image dimensions not found in header (lines=%d, samps=%d).', nLines, sampsPerLine);
    end

    % Z scale: extract the numeric factor from e.g. "V [Sens. Zsens] (xxx V/LSB) xxx"
    zScaleStr = getField(imgSection, '@2:Z scale', '');
    zScale = parseScaleValue(zScaleStr);

    zUnit = 'nm';  % default
    tok = regexp(zScaleStr, '\)\s*(\S+)', 'tokens', 'once');
    if ~isempty(tok), zUnit = tok{1}; end

    % Scan size from scanner section
    scanSections = sections(strcmp({sections.type}, 'Scanner list') | ...
                            strcmp({sections.type}, 'Ciao scan list'));
    scanSize = [NaN NaN];
    scanUnit = 'nm';
    if ~isempty(scanSections)
        scanSizeStr = getField(scanSections(1), 'Scan Size', '');
        tok = regexp(scanSizeStr, '([\d.eE+-]+)\s*(\w+)', 'tokens', 'once');
        if ~isempty(tok)
            scanSize = [str2double(tok{1}), str2double(tok{1})];  % square scan assumed
            scanUnit = tok{2};
        end
    end

    % Aspect ratio from image section
    aspectStr = getField(imgSection, 'Aspect Ratio', '');
    if ~isempty(aspectStr)
        tok = regexp(aspectStr, '(\d+):(\d+)', 'tokens', 'once');
        if ~isempty(tok) && scanSize(1) > 0
            ar1 = str2double(tok{1}); ar2 = str2double(tok{2});
            if ar1 > 0 && ar2 > 0
                scanSize(2) = scanSize(1) * ar2 / ar1;
            end
        end
    end

    % ── Read binary image data ───────────────────────────────────────────
    fseek(fid, dataOffset, 'bof');
    expectedPixels = nLines * sampsPerLine;

    switch bytesPerPx
        case 2
            rawData = fread(fid, expectedPixels, 'int16', 0, 'ieee-le');
            bitDepth = 16;
        case 4
            rawData = fread(fid, expectedPixels, 'int32', 0, 'ieee-le');
            bitDepth = 32;
        otherwise
            rawData = fread(fid, expectedPixels, 'int16', 0, 'ieee-le');
            bitDepth = 16;
    end

    if numel(rawData) < expectedPixels
        error('parser:importAFM:truncated', ...
            'Expected %d pixels, got %d. File may be truncated.', ...
            expectedPixels, numel(rawData));
    end

    % Reshape to image (row-major, top-to-bottom)
    pixels = reshape(rawData(1:expectedPixels), [sampsPerLine, nLines])';

    % Convert to physical units
    if zScale ~= 0
        pixels = double(pixels) * zScale;
    else
        pixels = double(pixels);
    end

    % ── Compute pixel size ───────────────────────────────────────────────
    if ~isnan(scanSize(1)) && sampsPerLine > 0
        pixelSize = scanSize(1) / sampsPerLine;
        pixelUnit = scanUnit;
        calibrated = true;
    else
        pixelSize = NaN;
        pixelUnit = '';
        calibrated = false;
    end

    % ── Acquisition parameters ───────────────────────────────────────────
    acquiParams = struct();
    if ~isempty(scanSections)
        acquiParams.scanRate_Hz  = getNumericField(scanSections(1), 'Scan rate', NaN);
        acquiParams.tipVoltage_V = getNumericField(scanSections(1), 'Tip voltage', NaN);
        acquiParams.setpoint     = getField(scanSections(1), 'Setpoint', '');
    end
    acquiParams.scanSize     = scanSize;
    acquiParams.scanUnit     = scanUnit;
    acquiParams.zScale       = zScale;
    acquiParams.zUnit        = zUnit;
    acquiParams.bytesPerPx   = bytesPerPx;
    acquiParams.allChannels  = allChannels;

    % ── Build imageData struct ───────────────────────────────────────────
    imgData = struct( ...
        'pixels',      pixels, ...
        'bitDepth',    bitDepth, ...
        'height',      nLines, ...
        'width',       sampsPerLine, ...
        'numChannels', 1, ...
        'numFrames',   1, ...
        'frames',      {{}}, ...
        'pixelSize',   pixelSize, ...
        'pixelUnit',   pixelUnit, ...
        'calibrated',  calibrated, ...
        'acquiParams', acquiParams);

    % ── Build metadata ───────────────────────────────────────────────────
    meta = struct();
    meta.source        = fp;
    meta.importDate    = datetime('now');
    meta.parserName    = 'importAFM';
    meta.parserVersion = '1.0';
    meta.xColumnName   = 'Row';
    meta.xColumnUnit   = 'px';
    meta.parserSpecific.isImage      = true;
    meta.parserSpecific.imageData    = imgData;
    meta.parserSpecific.allChannels  = allChannels;
    meta.parserSpecific.channelName  = channelName;
    meta.parserSpecific.scanSize     = scanSize;
    meta.parserSpecific.scanUnit     = scanUnit;
    meta.parserSpecific.zScale       = zScale;
    meta.parserSpecific.zUnit        = zUnit;

    % ── Build unified struct ─────────────────────────────────────────────
    timeVec = (1:nLines)';
    meanPerRow = mean(pixels, 2);

    data = parser.createDataStruct(timeVec, meanPerRow, ...
        'labels', {sprintf('Mean %s', channelName)}, ...
        'units',  {zUnit}, ...
        'metadata', meta);

    if options.Verbose
        fprintf('  importAFM: %s\n', fp);
        fprintf('    Channel:    %s\n', channelName);
        fprintf('    Image:      %d x %d px (%d-bit)\n', sampsPerLine, nLines, bitDepth);
        fprintf('    Scan size:  %.2f x %.2f %s\n', scanSize(1), scanSize(2), scanUnit);
        fprintf('    Pixel size: %.4f %s\n', pixelSize, pixelUnit);
        fprintf('    Z range:    %.4f to %.4f %s\n', min(pixels(:)), max(pixels(:)), zUnit);
        fprintf('    Channels:   %s\n', strjoin(allChannels, ', '));
    end
end


% ═════════════════════════════════════════════════════════════════════════
%  LOCAL HELPERS
% ═════════════════════════════════════════════════════════════════════════

function sections = parseNanoScopeHeader(headerLines)
%PARSENANOSCPOPEHEADER  Split header into typed sections with key=value pairs.
    sections = struct('type', {}, 'fields', {});
    currentSection = [];
    for i = 1:numel(headerLines)
        line = strtrim(headerLines{i});
        if startsWith(line, '\*')
            % New section header
            if ~isempty(currentSection)
                sections(end+1) = currentSection; %#ok<AGROW>
            end
            sectionName = regexprep(line, '^\\+\*\s*', '');
            currentSection = struct('type', sectionName, 'fields', {{}});
        elseif startsWith(line, '\') && ~isempty(currentSection)
            % Key-value pair: \Key: Value  or  \@N:Key: Value
            cleaned = regexprep(line, '^\\', '');
            colonIdx = strfind(cleaned, ':');
            if ~isempty(colonIdx)
                % For @N: prefixed keys, skip the prefix colon
                % e.g. "@2:Image Data: S [Height] ..." → key="@2:Image Data"
                sepIdx = colonIdx(1);
                if startsWith(cleaned, '@') && numel(colonIdx) >= 2
                    sepIdx = colonIdx(2);
                end
                key = strtrim(cleaned(1:sepIdx-1));
                val = strtrim(cleaned(sepIdx+1:end));
                currentSection.fields{end+1} = {key, val}; %#ok<AGROW>
            end
        end
    end
    if ~isempty(currentSection)
        sections(end+1) = currentSection;
    end
end

function val = getField(section, key, default)
%GETFIELD  Get a field value from a parsed section by key name.
    val = default;
    for i = 1:numel(section.fields)
        if strcmp(section.fields{i}{1}, key)
            val = section.fields{i}{2};
            return;
        end
    end
end

function val = getNumericField(section, key, default)
%GETNUMERICFIELD  Get a numeric field value, parsing the first number found.
    str = getField(section, key, '');
    if isempty(str)
        val = default;
        return;
    end
    tok = regexp(str, '[-+]?[\d.]+(?:[eE][-+]?\d+)?', 'match', 'once');
    if isempty(tok)
        val = default;
    else
        val = str2double(tok);
    end
end

function val = parseScaleValue(scaleStr)
%PARSESCALEVALUE  Extract the numeric scale factor from a NanoScope Z scale string.
%   Format examples:
%     "V [Sens. Zsens] (0.002000 V/LSB) 100.000 nm"
%     "0.002000 V/LSB"
%     "100.0000 nm"
    val = 0;
    if isempty(scaleStr), return; end
    % Try to extract the value after the parenthetical
    tok = regexp(scaleStr, '\)\s*([\d.eE+-]+)', 'tokens', 'once');
    if ~isempty(tok)
        val = str2double(tok{1});
        if ~isnan(val), return; end
    end
    % Fallback: extract value from inside parentheses (V/LSB factor)
    tok = regexp(scaleStr, '\(([\d.eE+-]+)', 'tokens', 'once');
    if ~isempty(tok)
        val = str2double(tok{1});
        if ~isnan(val), return; end
    end
    % Last resort: first number in the string
    tok = regexp(scaleStr, '([\d.eE+-]+)', 'tokens', 'once');
    if ~isempty(tok)
        val = str2double(tok{1});
    end
end
