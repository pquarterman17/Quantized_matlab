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
    %  1. Parse XML document
    % ════════════════════════════════════════════════════════════════════════
    try
        dom = xmlread(filepath);
    catch ME
        error('parser:importXRDML:xmlParseFailed', ...
            'Failed to parse "%s" as XML: %s', filepath, ME.message);
    end

    % ════════════════════════════════════════════════════════════════════════
    %  2. Wavelength
    % ════════════════════════════════════════════════════════════════════════
    wl = struct('kAlpha1', NaN, 'kAlpha2', NaN, 'kBeta', NaN, ...
                'ratioKAlpha2KAlpha1', NaN, 'intended', '');
    wlNodes = dom.getElementsByTagName('usedWavelength');
    if wlNodes.getLength > 0
        wlNode                 = wlNodes.item(0);
        wl.kAlpha1             = nodeDouble(wlNode, 'kAlpha1');
        wl.kAlpha2             = nodeDouble(wlNode, 'kAlpha2');
        wl.kBeta               = nodeDouble(wlNode, 'kBeta');
        wl.ratioKAlpha2KAlpha1 = nodeDouble(wlNode, 'ratioKAlpha2KAlpha1');
        wl.intended            = char(wlNode.getAttribute('intended'));
    end

    % ════════════════════════════════════════════════════════════════════════
    %  3. Instrument metadata
    % ════════════════════════════════════════════════════════════════════════

    % Schema version — encoded in the xmlns URI on the root element,
    % e.g. "http://www.xrdml.com/XRDMeasurement/1.5"
    schemaVersion = '';
    try
        nsURI         = char(dom.getDocumentElement().getNamespaceURI());
        schemaVersion = regexp(nsURI, '[\d.]+$', 'match', 'once');
    catch; end

    % Sample identification.  Schema 1.x stores the label in <id>; schema 2.x
    % uses <name>.  Target the <sample> element directly to avoid picking up
    % the author <name> node that lives elsewhere in the document.
    sampleName = '';
    sampleID   = '';
    smpNodes = dom.getElementsByTagName('sample');
    if smpNodes.getLength > 0
        sn         = smpNodes.item(0);
        sampleName = nodeText(sn, 'name');
        sampleID   = nodeText(sn, 'id');
    end

    % X-ray tube
    tubeName      = '';
    anodeMaterial = '';
    tension_kV    = NaN;
    current_mA    = NaN;
    tubeNodes = dom.getElementsByTagName('xRayTube');
    if tubeNodes.getLength > 0
        tn            = tubeNodes.item(0);
        tubeName      = char(tn.getAttribute('name'));
        anodeMaterial = nodeText(tn, 'anodeMaterial');
        tension_kV    = nodeDouble(tn, 'tension');
        current_mA    = nodeDouble(tn, 'current');
    end

    % Detector
    detectorName = '';
    detNodes = dom.getElementsByTagName('detector');
    if detNodes.getLength > 0
        detectorName = char(detNodes.item(0).getAttribute('name'));
    end

    % Acquisition software (<applicationSoftware>) and instrument control
    % software (<instrumentControlSoftware>) — both may be present
    appSoftware         = '';
    appSoftwareVer      = '';
    ctrlSoftware        = '';
    ctrlSoftwareVer     = '';
    appNodes = dom.getElementsByTagName('applicationSoftware');
    if appNodes.getLength > 0
        an             = appNodes.item(0);
        appSoftware    = strtrim(char(an.getTextContent()));
        appSoftwareVer = char(an.getAttribute('version'));
    end
    ctrlNodes = dom.getElementsByTagName('instrumentControlSoftware');
    if ctrlNodes.getLength > 0
        cn              = ctrlNodes.item(0);
        ctrlSoftware    = strtrim(char(cn.getTextContent()));
        ctrlSoftwareVer = char(cn.getAttribute('version'));
    end

    % Instrument ID
    instrumentID = nodeText(dom, 'instrumentID');

    % Sample spinner (present when sampleMovement xsi:type="spinningSampleMovementType")
    spinnerPeriod_s = NaN;
    spinNodes = dom.getElementsByTagName('spinnerRevolutionTime');
    if spinNodes.getLength > 0
        spinnerPeriod_s = str2double(char(spinNodes.item(0).getTextContent()));
    end

    % Comment entries (all <comment><entry> elements in the document)
    comments = extractComments(dom);

    % Measurement-level attributes
    measType   = '';
    sampleMode = '';
    measNodes  = dom.getElementsByTagName('xrdMeasurement');
    if measNodes.getLength > 0
        mn         = measNodes.item(0);
        measType   = char(mn.getAttribute('measurementType'));
        sampleMode = char(mn.getAttribute('sampleMode'));
    end

    % ════════════════════════════════════════════════════════════════════════
    %  4. Collect scan data (handles multi-scan / appended ranges)
    % ════════════════════════════════════════════════════════════════════════
    scanNodes = dom.getElementsByTagName('scan');
    nScans    = scanNodes.getLength;
    if nScans == 0
        error('parser:importXRDML:noScans', ...
            'No <scan> elements found in "%s".', filepath);
    end

    % Sort by appendNumber attribute so ranges concatenate in angular order
    appendNums = zeros(1, nScans);
    for s = 0 : nScans - 1
        anStr = char(scanNodes.item(s).getAttribute('appendNumber'));
        val   = str2double(anStr);
        if ~isempty(anStr) && ~isnan(val)
            appendNums(s + 1) = val;
        end
    end
    [~, sortIdx] = sort(appendNums);   % ascending appendNumber order

    twoTheta_all      = [];
    counts_all        = [];
    countingTime      = NaN;    % seconds per point (from first valid scan)
    countingTimes_all = [];     % all per-scan counting times (for consistency check)
    scanMode          = '';
    scanAxis          = '';
    startTimeStamp    = NaT;
    endTimeStamp      = NaT;
    intensityTag      = '';     % 'counts' (schema 2.x) or 'intensities' (schema 1.x)

    for si = 1 : nScans
        scanNode = scanNodes.item(sortIdx(si) - 1);

        % Skip scans that did not reach Completed status
        statusAttr = char(scanNode.getAttribute('status'));
        if ~isempty(statusAttr) && ~strcmpi(statusAttr, 'Completed')
            if options.Verbose
                fprintf('  [importXRDML] Skipping scan (appendNumber=%d, status=%s)\n', ...
                    appendNums(sortIdx(si)), statusAttr);
            end
            continue;
        end

        % Capture scan mode/axis strings from first valid scan
        if isempty(scanMode)
            scanMode = char(scanNode.getAttribute('mode'));
            scanAxis = char(scanNode.getAttribute('scanAxis'));
        end

        % Timestamps from <scan><header>
        hdrNodes = scanNode.getElementsByTagName('header');
        if hdrNodes.getLength > 0
            hdr = hdrNodes.item(0);
            if isnat(startTimeStamp)
                t0 = nodeText(hdr, 'startTimeStamp');
                if ~isempty(t0)
                    try
                        startTimeStamp = datetime(t0, 'InputFormat', ...
                            "yyyy-MM-dd'T'HH:mm:ssXXX", 'TimeZone', 'local');
                    catch; end
                end
            end
            t1 = nodeText(hdr, 'endTimeStamp');
            if ~isempty(t1)
                try
                    endTimeStamp = datetime(t1, 'InputFormat', ...
                        "yyyy-MM-dd'T'HH:mm:ssXXX", 'TimeZone', 'local');
                catch; end
            end
        end

        % ── Data points ────────────────────────────────────────────────────
        dpNodes = scanNode.getElementsByTagName('dataPoints');
        if dpNodes.getLength == 0; continue; end
        dp = dpNodes.item(0);

        % Counting time — collect from every scan for consistency check.
        % The first valid value is used for cps normalisation of all data.
        ct = nodeDouble(dp, 'commonCountingTime');
        if ~isnan(ct)
            countingTimes_all(end+1) = ct; %#ok<AGROW>
            if isnan(countingTime)
                countingTime = ct;
            end
        end

        % 2θ axis: XRDML stores only startPosition / endPosition; angles are
        % NOT written per-point.  Reconstruct via linspace over nPts steps.
        ttRange = extractPositions(dp, '2Theta');
        if isempty(ttRange); continue; end

        % Raw counts — tag name differs by schema version:
        %   schema 2.x: <counts unit="counts"> ...integers... </counts>
        %   schema 1.x: <intensities unit="counts"> ...integers... </intensities>
        cntNodes = dp.getElementsByTagName('counts');
        thisTag  = 'counts';
        if cntNodes.getLength == 0
            cntNodes = dp.getElementsByTagName('intensities');
            thisTag  = 'intensities';
        end
        if cntNodes.getLength == 0; continue; end
        if isempty(intensityTag); intensityTag = thisTag; end   % record first found
        cntStr  = strtrim(char(cntNodes.item(0).getTextContent()));

        % Guard: strsplit('') returns {''} → str2double gives [NaN] → nPts=1.
        % An empty text node means this scan has no data — skip it.
        if isempty(cntStr); continue; end

        cntVals = str2double(strsplit(cntStr));
        nPts    = numel(cntVals);
        if nPts < 1; continue; end

        % Build this scan's 2θ vector then trim its first point if it exactly
        % overlaps the last already-accumulated angle (common at range boundaries
        % in multi-range measurements, e.g. two scans both including 40.000°).
        ttVec = linspace(ttRange(1), ttRange(2), nPts);
        if ~isempty(twoTheta_all) && ttVec(1) == twoTheta_all(end)
            ttVec   = ttVec(2:end);
            cntVals = cntVals(2:end);
        end
        if isempty(ttVec); continue; end

        twoTheta_all = [twoTheta_all, ttVec];    %#ok<AGROW>
        counts_all   = [counts_all,   cntVals];  %#ok<AGROW>
    end

    % Warn if different scan ranges were measured with different counting times —
    % cps normalisation uses only the first value, so the result is incorrect for
    % any range whose counting time differs.
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

    twoTheta_col = twoTheta_all(:);   % Nx1 column
    counts_col   = counts_all(:);     % Nx1 column

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
    else   % "counts"
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
    % Scan summary — mirrored into parserSpecific so guiMetaLines can display
    % them (it only iterates parserSpecific fields, not top-level meta).
    ps.countingTime            = countingTime;
    ps.numPoints               = numel(twoTheta_col);
    ps.startAngle              = twoTheta_col(1);
    ps.endAngle                = twoTheta_col(end);
    ps.stepSize                = mean(diff(twoTheta_col), 'omitnan');

    meta = struct();
    meta.source       = char(filepath);
    meta.importDate   = datetime('now');
    meta.parserName   = 'importXRDML';
    meta.xColumnName  = '2-Theta';
    meta.xColumnUnit  = 'deg';
    meta.numPoints    = ps.numPoints;
    meta.startAngle   = ps.startAngle;
    meta.endAngle     = ps.endAngle;
    meta.stepSize     = ps.stepSize;
    meta.countingTime = countingTime;
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
%  Local helpers
% ════════════════════════════════════════════════════════════════════════════

% ── nodeDouble ──────────────────────────────────────────────────────────────
function val = nodeDouble(parent, tagName)
%NODEDOUBLE  Numeric value of the first matching child element, or NaN.
    val   = NaN;
    nodes = parent.getElementsByTagName(tagName);
    if nodes.getLength > 0
        val = str2double(strtrim(char(nodes.item(0).getTextContent())));
    end
end

% ── nodeText ────────────────────────────────────────────────────────────────
function txt = nodeText(parent, tagName)
%NODETEXT  Trimmed text of the first matching child element, or ''.
    txt   = '';
    nodes = parent.getElementsByTagName(tagName);
    if nodes.getLength > 0
        txt = strtrim(char(nodes.item(0).getTextContent()));
    end
end

% ── extractPositions ────────────────────────────────────────────────────────
function range = extractPositions(dpNode, axisName)
%EXTRACTPOSITIONS  [startPos, endPos] for the named axis, or [].
%   Handles startPosition/endPosition pairs (scanned axes) and
%   commonPosition (fixed axes such as Phi and Chi in a standard
%   coupled Theta/2Theta scan).
    range    = [];
    posNodes = dpNode.getElementsByTagName('positions');
    for p = 0 : posNodes.getLength - 1
        pn   = posNodes.item(p);
        attr = char(pn.getAttribute('axis'));
        if ~strcmpi(attr, axisName); continue; end

        startN = pn.getElementsByTagName('startPosition');
        endN   = pn.getElementsByTagName('endPosition');
        commN  = pn.getElementsByTagName('commonPosition');

        if startN.getLength > 0 && endN.getLength > 0
            s     = str2double(char(startN.item(0).getTextContent()));
            e     = str2double(char(endN.item(0).getTextContent()));
            range = [s, e];
        elseif commN.getLength > 0
            v     = str2double(char(commN.item(0).getTextContent()));
            range = [v, v];   % fixed axis — return as a degenerate pair
        end
        return;   % stop after the first matching axis node
    end
end

% ── extractComments ─────────────────────────────────────────────────────────
function comments = extractComments(dom)
%EXTRACTCOMMENTS  Cell array of non-empty <entry> text strings from all
%   <comment> blocks in the document.
    comments = {};
    entries  = dom.getElementsByTagName('entry');
    for k = 0 : entries.getLength - 1
        txt = strtrim(char(entries.item(k).getTextContent()));
        if ~isempty(txt)
            comments{end+1} = txt; %#ok<AGROW>
        end
    end
end

% ── printSummary ────────────────────────────────────────────────────────────
function printSummary(data, filepath)
%PRINTSUMMARY  Formatted console output for Verbose mode.
    m  = data.metadata;
    ps = m.parserSpecific;
    wl = ps.wavelength;

    SEP = repmat('═', 1, 62);
    fprintf('\n%s\n', SEP);
    fprintf('  importXRDML  (schema %s)\n', ps.schemaVersion);
    fprintf('  File       : %s\n', filepath);
    fprintf('%s\n', SEP);

    % Sample label: prefer <name>, fall back to <id>
    sampleLabel = ps.sampleName;
    if isempty(sampleLabel); sampleLabel = ps.sampleID; end
    if ~isempty(sampleLabel)
        fprintf('  Sample     : %s\n', sampleLabel);
    end

    fprintf('  Anode      : %s  (%.1f kV / %.1f mA)\n', ...
        ps.anodeMaterial, ps.tension_kV, ps.current_mA);
    fprintf('  Wavelength : K\u03b11 = %.7f \u00c5\n', wl.kAlpha1);
    if ~isnan(wl.kAlpha2)
        fprintf('             : K\u03b12 = %.7f \u00c5  (ratio %.4f)\n', ...
            wl.kAlpha2, wl.ratioKAlpha2KAlpha1);
    end
    fprintf('  2\u03b8 range  : %.4f \u2192 %.4f deg\n', m.startAngle, m.endAngle);
    fprintf('  Step size  : %.6f deg  (%d points)\n', m.stepSize, m.numPoints);
    fprintf('  Count time : %.3f s/point\n', m.countingTime);
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
        fprintf('  Start time : %s\n', datestr(ps.startTime, 'yyyy-mm-dd HH:MM:SS'));
        fprintf('  End time   : %s\n', datestr(ps.endTime,   'yyyy-mm-dd HH:MM:SS'));
    end
    fprintf('  Data tag   : <%s>\n', ps.intensityTag);
    fprintf('%s\n\n', SEP);
end
