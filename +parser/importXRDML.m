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
%   2D area-detector data
%   ─────────────────────
%   PANalytical Empyrean systems with PIXcel3D / GaliPIX3D detectors produce
%   multi-scan XRDML files where each <scan> records a strip of M detector
%   pixels at a different motor position (Omega, Chi, or Phi).  importXRDML
%   automatically detects this pattern when all scans share the same 2Theta
%   range and a secondary axis (Omega / Chi / Phi) varies across scans.
%
%   When 2D data is detected, these extra fields appear in
%   data.metadata.parserSpecific:
%     .is2D    true
%     .map2D   struct with fields:
%       .intensity     [N×M]  Intensity matrix (N frames × M detector pixels)
%       .axis1         [N×1]  Scanned motor positions (e.g. Omega, degrees)
%       .axis1Name     string 'Omega', 'Chi', or 'Phi'
%       .axis1Unit     'deg'
%       .axis2         [M×1]  Detector strip axis (2Theta, degrees)
%       .axis2Name     '2Theta'
%       .axis2Unit     'deg'
%       .intensityUnit 'cps' or 'counts' (matches the Intensity option)
%       .Qx            [N×M]  Reciprocal-space coordinate (Å⁻¹), present only
%                             when wavelength metadata is available.
%                             Qx = (4π/λ)·sin(θ)·sin(ω−θ),  θ = 2θ/2
%       .Qz            [N×M]  Reciprocal-space coordinate (Å⁻¹), present only
%                             when wavelength metadata is available.
%                             Qz = (4π/λ)·sin(θ)·cos(ω−θ)
%       .QxUnit        'Ang^-1'  (only when Qx is present)
%       .QzUnit        'Ang^-1'  (only when Qz is present)
%
%   The 1D output (data.time, data.values) contains the integrated profile
%   (row-sum of the intensity matrix) for backward compatibility with
%   existing code that expects 1D data.
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

    % Beam attenuator metadata (from incidentBeamPath)
    attBlock         = rxBlock(xml, 'beamAttenuator');
    attFactor        = rxDouble(attBlock, 'factor');
    attMaterial      = rxText(attBlock, 'material');
    attActivateLevel = rxDouble(attBlock, 'activateLevel');
    nScansAttCorrected = 0;  % count of scans where factors ~= 1

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

    % Per-scan data storage for 2D area-detector detection (pre-allocated)
    scanTTRanges = cell(1, nScans);    % {[start, end]} per completed scan
    scanTTLists  = cell(1, nScans);    % {[1×M] double} explicit position lists
    scanCounts   = cell(1, nScans);    % {[1×M] double} raw count vector per scan
    scanSecVals  = NaN(1, nScans);     % fixed secondary-axis position per scan
    scanSecName  = '';                  % secondary axis name from first valid scan
    nValid2D     = 0;                   % count of valid scans (for trimming)

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
        [ttRange, ttPosList] = rxPositions(dpBlock, '2Theta');
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

        % Apply beam attenuation correction (per-pixel factors from the instrument)
        % When an attenuator is active, factors > 1 restore true intensity.
        bafStr = rxText(dpBlock, 'beamAttenuationFactors');
        if ~isempty(bafStr)
            bafVals = sscanf(bafStr, '%f')';
            if numel(bafVals) == nPts
                if any(abs(bafVals - 1) > 1e-6)
                    nScansAttCorrected = nScansAttCorrected + 1;
                end
                cntVals = cntVals .* bafVals;
            elseif isscalar(bafVals) && abs(bafVals - 1) > 1e-6
                nScansAttCorrected = nScansAttCorrected + 1;
                cntVals = cntVals * bafVals;
            end
        end

        % ── Collect per-scan data for 2D area-detector classification ──────
        nValid2D = nValid2D + 1;
        if isempty(scanSecName)
            % First valid scan: discover which secondary axis is fixed
            for axN = ["Omega", "Chi", "Phi"]
                [pos2, ~] = rxPositions(dpBlock, char(axN));
                if ~isempty(pos2) && pos2(1) == pos2(2)
                    scanSecName = char(axN);
                    scanSecVals(nValid2D) = pos2(1);
                    break;
                end
            end
            if isempty(scanSecName)
                scanSecVals(nValid2D) = NaN;
            end
        else
            % Subsequent scans: read the established secondary axis
            [pos2, ~] = rxPositions(dpBlock, scanSecName);
            if ~isempty(pos2) && pos2(1) == pos2(2)
                scanSecVals(nValid2D) = pos2(1);
            else
                scanSecVals(nValid2D) = NaN;
            end
        end
        scanTTRanges{nValid2D} = ttRange;
        scanTTLists{nValid2D}  = ttPosList;
        scanCounts{nValid2D}   = cntVals;

        % Build 2θ vector; use explicit listPositions if available,
        % otherwise generate evenly spaced from range endpoints
        if ~isempty(ttPosList) && numel(ttPosList) == nPts
            ttVec = ttPosList;
        elseif ~isempty(ttPosList) && numel(ttPosList) ~= nPts
            % listPositions length mismatch: fall back to linspace
            ttVec = linspace(ttRange(1), ttRange(2), nPts);
        else
            ttVec = linspace(ttRange(1), ttRange(2), nPts);
        end
        % Trim overlap at range boundaries
        if ~isempty(twoTheta_all) && ttVec(1) == twoTheta_all(end)
            ttVec   = ttVec(2:end);
            cntVals = cntVals(2:end);
        end
        if isempty(ttVec); continue; end

        twoTheta_all = [twoTheta_all, ttVec];    %#ok<AGROW>
        counts_all   = [counts_all,   cntVals];   %#ok<AGROW>
    end

    % ════════════════════════════════════════════════════════════════════════
    %  4b. 2D area-detector detection and matrix assembly
    % ════════════════════════════════════════════════════════════════════════
    % Trim pre-allocated arrays to actual valid count
    scanTTRanges = scanTTRanges(1:nValid2D);
    scanTTLists  = scanTTLists(1:nValid2D);
    scanCounts   = scanCounts(1:nValid2D);
    scanSecVals  = scanSecVals(1:nValid2D);
    nValid       = nValid2D;
    is2D         = false;
    intensityMap = [];
    twoThetaVec  = [];
    secSorted    = [];

    if nValid > 1 && ~isempty(scanSecName)
        ttStarts    = cellfun(@(r) r(1), scanTTRanges);
        ttEnds      = cellfun(@(r) r(2), scanTTRanges);
        ttSame      = all(abs(ttStarts - ttStarts(1)) < 1e-4) && ...
                      all(abs(ttEnds   - ttEnds(1))   < 1e-4);
        allSecKnown = all(~isnan(scanSecVals));
        if allSecKnown
            secVaries = (max(scanSecVals) - min(scanSecVals)) > 1e-6;
        else
            secVaries = false;
        end
        is2D = ttSame && secVaries;
    end

    if is2D
        [secSorted, secOrder] = sort(scanSecVals);
        nPtsPerScan  = numel(scanCounts{1});
        % Use explicit listPositions if available; otherwise linspace
        if ~isempty(scanTTLists{1}) && numel(scanTTLists{1}) == nPtsPerScan
            twoThetaVec = scanTTLists{1}(:);
        else
            twoThetaVec = linspace(scanTTRanges{1}(1), scanTTRanges{1}(2), nPtsPerScan)';
        end
        intensityMap = zeros(nValid, nPtsPerScan);
        for i = 1:nValid
            vals = scanCounts{secOrder(i)};
            n    = min(numel(vals), nPtsPerScan);
            intensityMap(i, 1:n) = vals(1:n);
        end
        if options.Verbose
            fprintf('  [importXRDML] 2D area-detector: %d %s frames x %d detector pixels\n', ...
                nValid, scanSecName, nPtsPerScan);
            if nScansAttCorrected > 0
                fprintf('  [importXRDML] Beam attenuation corrected in %d/%d scans (factor: %.1f, %s)\n', ...
                    nScansAttCorrected, nValid, attFactor, attMaterial);
            end
        end
        % 1D fallback: override concatenated vectors with integrated profile
        twoTheta_all = twoThetaVec';
        counts_all   = sum(intensityMap, 1);
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
    ps.attenuatorFactor        = attFactor;
    ps.attenuatorMaterial      = attMaterial;
    ps.attenuatorActivateLevel = attActivateLevel;
    ps.nScansAttCorrected      = nScansAttCorrected;

    % 2D area-detector fields
    ps.is2D = is2D;
    if is2D
        if options.Intensity == "cps" && ~isnan(countingTime) && countingTime > 0
            mapIntensity = intensityMap / countingTime;
            mapIntUnit   = 'cps';
        else
            mapIntensity = intensityMap;
            mapIntUnit   = 'counts';
        end
        map2D.intensity     = mapIntensity;
        map2D.axis1         = secSorted(:);
        map2D.axis1Name     = scanSecName;
        map2D.axis1Unit     = 'deg';
        map2D.axis2         = twoThetaVec;
        map2D.axis2Name     = '2Theta';
        map2D.axis2Unit     = 'deg';
        map2D.intensityUnit = mapIntUnit;

        % ── Reciprocal-space conversion (requires wavelength) ─────────────
        % Standard coplanar geometry:
        %   Qx = (4π/λ) · sin(θ) · sin(ω − θ)
        %   Qz = (4π/λ) · sin(θ) · cos(ω − θ)
        % where θ = 2θ/2 (half detector angle), ω = motor position.
        % At the symmetric Bragg condition ω = θ: Qx = 0, Qz = (4π/λ)·sin(θ).
        if ~isnan(wl.kAlpha1) && wl.kAlpha1 > 0
            lambda = wl.kAlpha1;   % Å
            [TT_rad, OM_rad] = meshgrid(deg2rad(twoThetaVec), deg2rad(secSorted(:)));
            theta_rad = TT_rad / 2;
            k0        = 2 * pi / lambda;
            map2D.Qx     = 2 * k0 .* sin(theta_rad) .* sin(OM_rad - theta_rad);
            map2D.Qz     = 2 * k0 .* sin(theta_rad) .* cos(OM_rad - theta_rad);
            map2D.QxUnit = 'Ang^-1';
            map2D.QzUnit = 'Ang^-1';
        end

        ps.map2D = map2D;
    end

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
    labelStr = 'Intensity';
    if is2D; labelStr = 'Intensity (integrated)'; end
    data = parser.createDataStruct(twoTheta_col, intensity, ...
        'labels',   {labelStr}, ...
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

function [range, posList] = rxPositions(dpBlock, axisName)
%RXPOSITIONS  Extract [startPos, endPos] for the named axis from a dataPoints block.
%   Handles scanned axes (startPosition/endPosition), fixed axes
%   (commonPosition), and explicit per-pixel position lists (listPositions).
%   Returns:
%     range   — [start, end] two-element vector (empty if not found)
%     posList — full position vector from listPositions (empty if not available)
    range = [];
    posList = [];
    % Find all <positions ...>...</positions> blocks
    posBlocks = extractBlocks(dpBlock, 'positions');
    for k = 1:numel(posBlocks)
        pb = posBlocks{k};
        axVal = rxAttr(pb, 'positions', 'axis');
        if ~strcmpi(axVal, axisName); continue; end

        % Try startPosition/endPosition first (standard scans)
        s = rxDouble(pb, 'startPosition');
        e = rxDouble(pb, 'endPosition');
        if ~isnan(s) && ~isnan(e)
            range = [s, e];
            return;
        end

        % Try listPositions (mesh/RSM scans with explicit pixel positions)
        lpStr = rxText(pb, 'listPositions');
        if ~isempty(lpStr)
            posList = sscanf(lpStr, '%f')';
            if numel(posList) >= 1
                range = [posList(1), posList(end)];
                return;
            end
        end

        % Try commonPosition (fixed axis)
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
    if isfield(ps, 'is2D') && ps.is2D
        fprintf('  Map size   : %d %s frames x %d detector pixels (2D)\n', ...
            numel(ps.map2D.axis1), ps.map2D.axis1Name, numel(ps.map2D.axis2));
    end
    fprintf('%s\n\n', SEP);
end
