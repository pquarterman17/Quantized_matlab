function data = importXRDML(filepath, options)
%IMPORTXRDML  Parse a PANalytical .xrdml file into the toolkit data struct.
%
%   Syntax
%   ──────
%   data = parser.importXRDML(filepath)
%   data = parser.importXRDML(filepath, Name=Value)
%
%   Inputs
%   ──────
%   filepath   (1,1) string   Path to the .xrdml file.
%
%   Name-Value Options
%   ──────────────────
%   Intensity   "cps" | "counts"   Output intensity unit.  "cps" (default)
%               divides raw detector counts by the per-point counting time.
%               "counts" returns the raw integer counts as recorded.
%   Verbose     logical             Print a formatted summary to the console
%               (default: false).
%
%   Outputs
%   ───────
%   data   Struct produced by parser.createDataStruct with fields:
%            .time        [Nx1]  2θ angles (degrees); reconstructed by
%                                linear interpolation between the scan's
%                                startPosition and endPosition values
%            .values      [Nx1]  Intensity (cps or raw counts per option)
%            .labels      {'Intensity'}
%            .units       {'cps'} or {'counts'}
%            .metadata    Struct — see below
%
%   Metadata fields (data.metadata)
%   ────────────────────────────────
%   .source              Full file path
%   .importDate          datetime of import
%   .parserName          'importXRDML'
%   .xColumnName         '2-Theta'
%   .xColumnUnit         'deg'
%   .numPoints           Total number of data points imported
%   .startAngle          First 2θ position (deg)
%   .endAngle            Last 2θ position (deg)
%   .stepSize            Mean angular step size (deg)
%   .countingTime        Per-point counting time (seconds)
%   .parserSpecific      Struct with instrument-level detail:
%     .wavelength        Struct: kAlpha1, kAlpha2, kBeta (Å), ratio, intended
%     .sampleMode        e.g. 'Reflection'
%     .measurementType   e.g. 'Scan'
%     .scanMode          e.g. 'Continuous'
%     .scanAxis          e.g. 'Gonio'
%     .anodeMaterial     e.g. 'Cu'
%     .tubeName          X-ray tube name string
%     .tension_kV        Tube voltage (kV)
%     .current_mA        Tube current (mA)
%     .detectorName      Detector name string
%     .sampleName        Sample <name> field (may be empty in schema 1.x)
%     .sampleID          Sample <id> field (used as label when name is blank)
%     .instrumentID      Instrument serial number
%     .softwareName      Acquisition software (applicationSoftware node)
%     .softwareVersion   Acquisition software version string
%     .controlSoftware   Instrument control software name (e.g. 'EMPYREAN')
%     .controlSoftwareVersion   Instrument control software version string
%     .schemaVersion     XRDML schema version string, e.g. '1.5' or '2.1'
%     .intensityTag      XML tag used for counts data: 'counts' or 'intensities'
%     .spinnerPeriod_s   Sample spinner revolution time in seconds (NaN if absent)
%     .startTime         Scan start timestamp (datetime)
%     .endTime           Scan end timestamp (datetime)
%     .comments          Cell array of instrument comment strings
%
%   Multi-scan files
%   ────────────────
%   XRDML files may contain multiple <scan appendNumber="N"> elements
%   (e.g. when a measurement spans multiple angular ranges, each with
%   different divergence slit settings).  All Completed scans are
%   concatenated in ascending appendNumber order.  The countingTime from
%   the first valid scan is used for the cps normalisation.
%
%   Example
%   ───────
%   d = parser.importXRDML('La2NiO4.xrdml', Intensity='cps', Verbose=true);
%   semilogy(d.time, d.values);
%   xlabel('2\theta (deg)');  ylabel('Intensity (cps)');
%
%   Limitations
%   ───────────
%   File size: tested up to ~20 MB.  Uses fileread + regexp (text-based
%   parsing) for speed; avoids the much slower xmlread DOM parser.
%
%   See also IMPORTRIGAKU_RAW, IMPORTAUTO

    arguments
        filepath           (1,1) string {mustBeFile}
        options.Intensity  (1,1) string = "cps"
        options.Verbose    (1,1) logical = false
    end

    validIntensity = ["cps", "counts"];
    if ~any(options.Intensity == validIntensity)
        error('parser:importXRDML:badIntensityOption', ...
            'Intensity must be "cps" or "counts"; got "%s".', options.Intensity);
    end

    % ════════════════════════════════════════════════════════════════════════
    %  1. Read file as text (much faster than xmlread DOM parser)
    % ════════════════════════════════════════════════════════════════════════
    try
        xml = fileread(filepath);
    catch ME
        error('parser:importXRDML:readFailed', ...
            'Failed to read "%s": %s', filepath, ME.message);
    end

    % ════════════════════════════════════════════════════════════════════════
    %  2. Wavelength
    % ════════════════════════════════════════════════════════════════════════
    wl = struct('kAlpha1', NaN, 'kAlpha2', NaN, 'kBeta', NaN, ...
                'ratioKAlpha2KAlpha1', NaN, 'intended', '');
    wlBlock = rxBlock(xml, 'usedWavelength');
    if ~isempty(wlBlock)
        wl.kAlpha1             = rxDouble(wlBlock, 'kAlpha1');
        wl.kAlpha2             = rxDouble(wlBlock, 'kAlpha2');
        wl.kBeta               = rxDouble(wlBlock, 'kBeta');
        wl.ratioKAlpha2KAlpha1 = rxDouble(wlBlock, 'ratioKAlpha2KAlpha1');
        wl.intended            = rxAttr(wlBlock, 'usedWavelength', 'intended');
    end

    % ════════════════════════════════════════════════════════════════════════
    %  3. Instrument metadata
    % ════════════════════════════════════════════════════════════════════════

    % Schema version from xmlns URI (e.g. ".../XRDMeasurement/2.1")
    schemaVersion = rxMatch(xml, '(?:xmlns[^=]*=\s*"[^"]*/)(\d[\d.]+)"');

    % Sample
    smpBlock   = rxBlock(xml, 'sample');
    sampleName = rxText(smpBlock, 'name');
    sampleID   = rxText(smpBlock, 'id');

    % X-ray tube
    tubeBlock     = rxBlock(xml, 'xRayTube');
    tubeName      = rxAttr(xml, 'xRayTube', 'name');
    anodeMaterial = rxText(tubeBlock, 'anodeMaterial');
    tension_kV    = rxDouble(tubeBlock, 'tension');
    current_mA    = rxDouble(tubeBlock, 'current');

    % Detector
    detectorName = rxAttr(xml, 'detector', 'name');

    % Software
    appSoftware     = rxText(xml, 'applicationSoftware');
    appSoftwareVer  = rxAttr(xml, 'applicationSoftware', 'version');
    ctrlSoftware    = rxText(xml, 'instrumentControlSoftware');
    ctrlSoftwareVer = rxAttr(xml, 'instrumentControlSoftware', 'version');

    % Instrument ID
    instrumentID = rxText(xml, 'instrumentID');

    % Spinner revolution time
    spinnerPeriod_s = rxDouble(xml, 'spinnerRevolutionTime');

    % Comments — all <entry> elements
    comments = regexp(xml, '<entry[^>]*>\s*(.*?)\s*</entry>', 'tokens', 'dotall');
    comments = cellfun(@(c) c{1}, comments, 'UniformOutput', false);
    comments = comments(~cellfun(@isempty, comments));

    % Measurement attributes
    measType   = rxAttr(xml, 'xrdMeasurement', 'measurementType');
    sampleMode = rxAttr(xml, 'xrdMeasurement', 'sampleMode');

    % ════════════════════════════════════════════════════════════════════════
    %  4. Collect scan data (handles multi-scan / appended ranges)
    % ════════════════════════════════════════════════════════════════════════

    % Extract all <scan ...>...</scan> blocks using strfind (robust for large
    % blocks that can overwhelm MATLAB's regex backtracking engine).
    scanBlocks = extractBlocks(xml, 'scan');
    nScans     = numel(scanBlocks);
    if nScans == 0
        error('parser:importXRDML:noScans', ...
            'No <scan> elements found in "%s".', filepath);
    end

    % Sort by appendNumber attribute
    appendNums = zeros(1, nScans);
    for s = 1:nScans
        anStr = rxAttr(scanBlocks{s}, 'scan', 'appendNumber');
        val   = str2double(anStr);
        if ~isnan(val)
            appendNums(s) = val;
        end
    end
    [~, sortIdx] = sort(appendNums);

    twoTheta_all      = [];
    counts_all        = [];
    countingTime      = NaN;
    countingTimes_all = [];
    scanMode          = '';
    scanAxis          = '';
    startTimeStamp    = NaT;
    endTimeStamp      = NaT;
    intensityTag      = '';

    for si = 1:nScans
        sb = scanBlocks{sortIdx(si)};

        % Skip non-Completed scans
        statusAttr = rxAttr(sb, 'scan', 'status');
        if ~isempty(statusAttr) && ~strcmpi(statusAttr, 'Completed')
            if options.Verbose
                fprintf('  [importXRDML] Skipping scan (appendNumber=%d, status=%s)\n', ...
                    appendNums(sortIdx(si)), statusAttr);
            end
            continue;
        end

        % Capture scan mode/axis from first valid scan
        if isempty(scanMode)
            scanMode = rxAttr(sb, 'scan', 'mode');
            scanAxis = rxAttr(sb, 'scan', 'scanAxis');
        end

        % Timestamps
        if isnat(startTimeStamp)
            t0 = rxText(sb, 'startTimeStamp');
            if ~isempty(t0)
                try
                    startTimeStamp = datetime(t0, 'InputFormat', ...
                        "yyyy-MM-dd'T'HH:mm:ssXXX", 'TimeZone', 'local');
                catch
                end
            end
        end
        t1 = rxText(sb, 'endTimeStamp');
        if ~isempty(t1)
            try
                endTimeStamp = datetime(t1, 'InputFormat', ...
                    "yyyy-MM-dd'T'HH:mm:ssXXX", 'TimeZone', 'local');
            catch
            end
        end

        % ── Data points ────────────────────────────────────────────────────
        dpBlock = rxBlock(sb, 'dataPoints');
        if isempty(dpBlock); continue; end

        % Counting time
        ct = rxDouble(dpBlock, 'commonCountingTime');
        if ~isnan(ct)
            countingTimes_all(end+1) = ct; %#ok<AGROW>
            if isnan(countingTime)
                countingTime = ct;
            end
        end

        % 2θ positions: find the <positions axis="2Theta"> block
        ttRange = rxPositions(dpBlock, '2Theta');
        if isempty(ttRange); continue; end

        % Intensity data — schema 2.x: <counts>, schema 1.x: <intensities>
        cntStr  = rxText(dpBlock, 'counts');
        thisTag = 'counts';
        if isempty(cntStr)
            cntStr  = rxText(dpBlock, 'intensities');
            thisTag = 'intensities';
        end
        if isempty(cntStr); continue; end
        if isempty(intensityTag); intensityTag = thisTag; end

        cntVals = sscanf(cntStr, '%f')';    % sscanf is faster than str2double(strsplit())
        nPts    = numel(cntVals);
        if nPts < 1; continue; end

        % Build 2θ vector; trim overlap at range boundaries
        ttVec = linspace(ttRange(1), ttRange(2), nPts);
        if ~isempty(twoTheta_all) && ttVec(1) == twoTheta_all(end)
            ttVec   = ttVec(2:end);
            cntVals = cntVals(2:end);
        end
        if isempty(ttVec); continue; end

        twoTheta_all = [twoTheta_all, ttVec];    %#ok<AGROW>
        counts_all   = [counts_all,   cntVals];   %#ok<AGROW>
    end

    % Warn on mixed counting times
    if numel(countingTimes_all) > 1
        uniqueCT = unique(countingTimes_all);
        if numel(uniqueCT) > 1
            warning('parser:importXRDML:mixedCountingTimes', ...
                ['Multi-range file has inconsistent counting times across scans ' ...
                 '(%s s).  cps normalisation uses the first value (%.3g s); ' ...
                 'intensities from other ranges will be incorrectly scaled.'], ...
                strjoin(arrayfun(@(x) sprintf('%.3g',x), uniqueCT, ...
                    'UniformOutput', false), ', '), ...
                countingTime);
        end
    end

    % ════════════════════════════════════════════════════════════════════════
    %  5. Validate extracted data
    % ════════════════════════════════════════════════════════════════════════
    if isempty(twoTheta_all)
        error('parser:importXRDML:noData', ...
            ['No data points could be extracted from "%s". ' ...
             'All scans may have a non-Completed status.'], filepath);
    end

    twoTheta_col = twoTheta_all(:);
    counts_col   = counts_all(:);

    % ════════════════════════════════════════════════════════════════════════
    %  6. Intensity output
    % ════════════════════════════════════════════════════════════════════════
    if options.Intensity == "cps"
        if isnan(countingTime) || countingTime <= 0
            warning('parser:importXRDML:noCountingTime', ...
                ['Counting time not found or invalid (%.3g s); ' ...
                 'returning raw counts instead of cps.'], countingTime);
            intensity  = counts_col;
            intensUnit = 'counts';
        else
            intensity  = counts_col / countingTime;
            intensUnit = 'cps';
        end
    else
        intensity  = counts_col;
        intensUnit = 'counts';
    end

    % ════════════════════════════════════════════════════════════════════════
    %  7. Assemble metadata
    % ════════════════════════════════════════════════════════════════════════
    ps = struct();
    ps.wavelength              = wl;
    ps.sampleMode              = sampleMode;
    ps.measurementType         = measType;
    ps.scanMode                = scanMode;
    ps.scanAxis                = scanAxis;
    ps.anodeMaterial           = anodeMaterial;
    ps.tubeName                = tubeName;
    ps.tension_kV              = tension_kV;
    ps.current_mA              = current_mA;
    ps.detectorName            = detectorName;
    ps.sampleName              = sampleName;
    ps.sampleID                = sampleID;
    ps.instrumentID            = instrumentID;
    ps.softwareName            = appSoftware;
    ps.softwareVersion         = appSoftwareVer;
    ps.controlSoftware         = ctrlSoftware;
    ps.controlSoftwareVersion  = ctrlSoftwareVer;
    ps.schemaVersion           = schemaVersion;
    ps.intensityTag            = intensityTag;
    ps.spinnerPeriod_s         = spinnerPeriod_s;
    ps.startTime               = startTimeStamp;
    ps.endTime                 = endTimeStamp;
    ps.comments                = comments;
    ps.countingTime            = countingTime;
    ps.numPoints               = numel(twoTheta_col);
    ps.startAngle              = twoTheta_col(1);
    ps.endAngle                = twoTheta_col(end);
    ps.stepSize                = mean(diff(twoTheta_col), 'omitnan');

    meta = struct();
    meta.source        = char(filepath);
    meta.importDate    = datetime('now');
    meta.parserName    = 'importXRDML';
    meta.parserVersion = '1.0';
    meta.xColumnName   = '2-Theta';
    meta.xColumnUnit   = 'deg';
    meta.parserSpecific = ps;

    % ════════════════════════════════════════════════════════════════════════
    %  8. Build unified output struct
    % ════════════════════════════════════════════════════════════════════════
    data = parser.createDataStruct(twoTheta_col, intensity, ...
        'labels',   {'Intensity'}, ...
        'units',    {intensUnit},  ...
        'metadata', meta);

    % ════════════════════════════════════════════════════════════════════════
    %  9. Optional verbose summary
    % ════════════════════════════════════════════════════════════════════════
    if options.Verbose
        printSummary(data, filepath);
    end
end


% ════════════════════════════════════════════════════════════════════════════
%  Regex-based XML helpers (replace DOM-based nodeDouble/nodeText/etc.)
% ════════════════════════════════════════════════════════════════════════════

function blocks = extractBlocks(xml, tag)
%EXTRACTBLOCKS  Extract all <tag ...>...</tag> blocks using strfind.
%   Returns a cell array of strings, each containing a complete block
%   including the outer tags.  Handles nested same-name tags by tracking
%   nesting depth.  Uses strfind instead of regex to avoid backtracking
%   issues with very large content (e.g. 30 KB count data lines).
    openPat  = ['<' tag];        % matches <tag  or <tag> or <tag ...>
    closePat = ['</' tag '>'];
    openLen  = numel(openPat);
    closeLen = numel(closePat);

    openStarts  = strfind(xml, openPat);
    closeStarts = strfind(xml, closePat);

    % Filter openStarts: next char after '<tag' must be whitespace, '>', or '/'
    % to avoid matching e.g. <scanner> when looking for <scan>
    validOpen = false(size(openStarts));
    for k = 1:numel(openStarts)
        nextIdx = openStarts(k) + openLen;
        if nextIdx <= numel(xml)
            ch = xml(nextIdx);
            validOpen(k) = (ch == ' ' || ch == '>' || ch == '/' || ...
                            ch == char(9) || ch == newline || ch == char(13));
        end
    end
    openStarts = openStarts(validOpen);

    blocks = {};
    oi = 1;  % open index cursor
    ci = 1;  % close index cursor
    while oi <= numel(openStarts) && ci <= numel(closeStarts)
        blockStart = openStarts(oi);
        depth = 1;
        oi = oi + 1;
        % Walk through remaining opens/closes to find matching close
        while depth > 0 && ci <= numel(closeStarts)
            % Check if another open comes before the next close
            if oi <= numel(openStarts) && openStarts(oi) < closeStarts(ci)
                depth = depth + 1;
                oi = oi + 1;
            else
                depth = depth - 1;
                if depth == 0
                    blockEnd = closeStarts(ci) + closeLen - 1;
                    blocks{end+1} = xml(blockStart:blockEnd); %#ok<AGROW>
                end
                ci = ci + 1;
            end
        end
    end
end

function blk = rxBlock(xml, tag)
%RXBLOCK  Extract the content of the first <tag ...>...</tag> block.
%   Returns the full match including outer tags, or '' if not found.
%   Uses strfind for robustness against large content that can overwhelm
%   MATLAB's regex backtracking engine.
    blocks = extractBlocks(xml, tag);
    if ~isempty(blocks)
        blk = blocks{1};
    else
        blk = '';
    end
end

function val = rxDouble(xml, tag)
%RXDOUBLE  Numeric value inside the first <tag>...</tag>, or NaN.
    tok = regexp(xml, ['<' tag '(?=[\s>/])[^>]*>\s*([\d.eE+\-]+)\s*</' tag '>'], 'tokens', 'once', 'dotall');
    if ~isempty(tok)
        val = str2double(tok{1});
    else
        val = NaN;
    end
end

function txt = rxText(xml, tag)
%RXTEXT  Trimmed text content of the first <tag>...</tag>, or ''.
%   Uses strfind-based extraction to handle large content (e.g. counts data
%   with thousands of values) that can overwhelm regex backtracking.
    blk = rxBlock(xml, tag);
    if isempty(blk)
        txt = '';
        return;
    end
    % Strip the opening tag: find end of first '>'
    gt = strfind(blk, '>');
    if isempty(gt); txt = ''; return; end
    % Strip the closing tag: find last '<'
    lt = strfind(blk, '<');
    if numel(lt) < 2; txt = ''; return; end
    txt = strtrim(blk(gt(1)+1 : lt(end)-1));
end

function val = rxAttr(xml, tag, attr)
%RXATTR  Value of a named attribute on the first <tag> element, or ''.
    tok = regexp(xml, ['<' tag '(?=[\s>/])[^>]*\s' attr '="([^"]*)"'], 'tokens', 'once');
    if ~isempty(tok)
        val = tok{1};
    else
        val = '';
    end
end

function val = rxMatch(xml, pat)
%RXMATCH  First capture group from a general regex, or ''.
    tok = regexp(xml, pat, 'tokens', 'once');
    if ~isempty(tok)
        val = tok{1};
    else
        val = '';
    end
end

function range = rxPositions(dpBlock, axisName)
%RXPOSITIONS  Extract [startPos, endPos] for the named axis from a dataPoints block.
%   Handles both scanned axes (startPosition/endPosition) and fixed axes
%   (commonPosition).
    range = [];
    % Find all <positions ...>...</positions> blocks
    posBlocks = extractBlocks(dpBlock, 'positions');
    for k = 1:numel(posBlocks)
        pb = posBlocks{k};
        axVal = rxAttr(pb, 'positions', 'axis');
        if ~strcmpi(axVal, axisName); continue; end

        s = rxDouble(pb, 'startPosition');
        e = rxDouble(pb, 'endPosition');
        if ~isnan(s) && ~isnan(e)
            range = [s, e];
            return;
        end
        c = rxDouble(pb, 'commonPosition');
        if ~isnan(c)
            range = [c, c];
            return;
        end
    end
end


% ── printSummary ────────────────────────────────────────────────────────────
function printSummary(data, filepath)
%PRINTSUMMARY  Formatted console output for Verbose mode.
    m  = data.metadata;
    ps = m.parserSpecific;
    wl = ps.wavelength;

    SEP = repmat(char(9552), 1, 62);
    fprintf('\n%s\n', SEP);
    fprintf('  importXRDML  (schema %s)\n', ps.schemaVersion);
    fprintf('  File       : %s\n', filepath);
    fprintf('%s\n', SEP);

    sampleLabel = ps.sampleName;
    if isempty(sampleLabel); sampleLabel = ps.sampleID; end
    if ~isempty(sampleLabel)
        fprintf('  Sample     : %s\n', sampleLabel);
    end

    fprintf('  Anode      : %s  (%.1f kV / %.1f mA)\n', ...
        ps.anodeMaterial, ps.tension_kV, ps.current_mA);
    fprintf('  Wavelength : K%s1 = %.7f %s\n', char(945), wl.kAlpha1, char(197));
    if ~isnan(wl.kAlpha2)
        fprintf('             : K%s2 = %.7f %s  (ratio %.4f)\n', ...
            char(945), wl.kAlpha2, char(197), wl.ratioKAlpha2KAlpha1);
    end
    fprintf('  2%s range  : %.4f %s %.4f deg\n', char(952), ps.startAngle, char(8594), ps.endAngle);
    fprintf('  Step size  : %.6f deg  (%d points)\n', ps.stepSize, ps.numPoints);
    fprintf('  Count time : %.3f s/point\n', ps.countingTime);
    if ~isnan(ps.spinnerPeriod_s)
        fprintf('  Spinner    : %.1f s/rev\n', ps.spinnerPeriod_s);
    end
    fprintf('  Detector   : %s\n', ps.detectorName);
    fprintf('  Scan       : %s, %s\n', ps.scanMode, ps.scanAxis);
    if ~isempty(ps.controlSoftware)
        fprintf('  Software   : %s v%s\n', ps.controlSoftware, ps.controlSoftwareVersion);
    elseif ~isempty(ps.softwareName)
        fprintf('  Software   : %s v%s\n', ps.softwareName, ps.softwareVersion);
    end
    if ~isnat(ps.startTime)
        fprintf('  Start time : %s\n', char(datetime(ps.startTime, 'Format', 'yyyy-MM-dd HH:mm:ss')));
        fprintf('  End time   : %s\n', char(datetime(ps.endTime,   'Format', 'yyyy-MM-dd HH:mm:ss')));
    end
    fprintf('  Data tag   : <%s>\n', ps.intensityTag);
    fprintf('%s\n\n', SEP);
end
