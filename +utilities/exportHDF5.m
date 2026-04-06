function exportHDF5(data, filepath, options)
%EXPORTHDF5  Export a unified toolbox data struct to a self-describing HDF5 file.
%
%   utilities.exportHDF5(data, 'output.h5')
%   utilities.exportHDF5(data, 'output.h5', 'CorrData', corrData)
%   utilities.exportHDF5(data, 'output.h5', 'CorrData', corrData, ...
%       'Corrections', struct('xOff',0.1,'yOff',0,'bgSlope',0,'bgInt',0), ...
%       'IncludePeaks', true, 'Peaks', ds.peaks)
%
%   Writes a hierarchical HDF5 file with schema version 1.0.  All parsers
%   produce the same unified struct layout, so the schema is consistent
%   across data types (VSM, PPMS, XRD, generic CSV/Excel).
%
%   Schema overview:
%       /raw/           — raw data (always written)
%       /corrected/     — corrected data (optional)
%       /corrections/   — correction parameters (optional)
%       /peaks/         — peak fit results (optional)
%       /metadata/      — common metadata attributes
%       /metadata/parserSpecific/  — instrument-specific attributes
%
%   String datasets (labels, units, peak status/model) are written as
%   space-padded ASCII uint8 matrices.  The companion attribute
%   'encoding'='ASCII_padded_space' documents this for downstream readers.
%
%   INPUTS:
%       data     — unified data struct with fields .time, .values, .labels,
%                  .units, .metadata  (as returned by any parser.import* function)
%       filepath — output file path; must end in .h5 or .hdf5
%
%   OPTIONAL NAME-VALUE PAIRS:
%       CorrData     — corrected data struct (same layout as data); omit or
%                      pass struct() to skip the /corrected/ group
%       Corrections  — struct with fields xOff, yOff, bgSlope, bgInt
%       IncludePeaks — logical; write /peaks/ group (default false)
%       Peaks        — struct array from ds.peaks (required when IncludePeaks=true)
%       Overwrite    — delete existing file before writing (default true)
%
%   EXAMPLES:
%       % Minimal export
%       data = parser.importAuto('scan.xrdml');
%       utilities.exportHDF5(data, 'scan.h5');
%
%       % Full export from GUI dataset struct
%       utilities.exportHDF5(ds.data, 'output.h5', ...
%           'CorrData',    ds.corrData, ...
%           'Corrections', struct('xOff',ds.xOff,'yOff',ds.yOff, ...
%                                 'bgSlope',ds.bgSlope,'bgInt',ds.bgInt), ...
%           'IncludePeaks', ~isempty(ds.peaks), ...
%           'Peaks',        ds.peaks);
%
%       % Read back in MATLAB
%       t = h5read('output.h5', '/raw/time');
%       v = h5read('output.h5', '/raw/values');
%       parserName = h5readatt('output.h5', '/metadata', 'parserName');
%
%   See also utilities.normalize, utilities.smoothData, parser.importAuto

% ════════════════════════════════════════════════════════════════════════
%  Arguments
% ════════════════════════════════════════════════════════════════════════

    arguments
        data                  (1,1) struct
        filepath              (1,1) string
        options.CorrData      (1,1) struct  = struct()
        options.Corrections   (1,1) struct  = struct()
        options.IncludePeaks  (1,1) logical = false
        options.Peaks         (1,:) struct  = struct('center',{},'fwhm',{}, ...
                                                     'height',{},'xRange',{}, ...
                                                     'status',{},'bg',{},'model',{})
        options.Overwrite     (1,1) logical = true
    end

% ════════════════════════════════════════════════════════════════════════
%  Validate inputs
% ════════════════════════════════════════════════════════════════════════

    requiredFields = {'time','values','labels','units','metadata'};
    for fi = 1:numel(requiredFields)
        if ~isfield(data, requiredFields{fi})
            error('exportHDF5:badData', ...
                'data struct is missing required field: %s', requiredFields{fi});
        end
    end

    [~, ~, ext] = fileparts(filepath);
    if ~any(strcmpi(ext, {'.h5','.hdf5'}))
        error('exportHDF5:badExtension', ...
            'filepath must end in .h5 or .hdf5 (got: %s)', ext);
    end

    dirPart = fileparts(filepath);
    if ~isempty(dirPart) && ~isfolder(dirPart)
        error('exportHDF5:badDir', ...
            'Output directory does not exist:\n%s', dirPart);
    end

    if options.Overwrite && isfile(filepath)
        delete(filepath);
    elseif ~options.Overwrite && isfile(filepath)
        error('exportHDF5:fileExists', ...
            'File already exists and Overwrite=false:\n%s', filepath);
    end

    hasCorrData  = isfield(options.CorrData, 'time');
    hasPeaks     = options.IncludePeaks && numel(options.Peaks) > 0;
    corrFields   = fieldnames(options.Corrections);
    corrVals     = cellfun(@(f) options.Corrections.(f), corrFields);
    hasCorrections = ~isempty(corrFields) && any(isfinite(corrVals));
    correctionsApplied = hasCorrections && any(corrVals ~= 0);

% ════════════════════════════════════════════════════════════════════════
%  Root-level attributes
% ════════════════════════════════════════════════════════════════════════

    % Bootstrap the file by writing a sentinel dataset at root level.
    % h5create implicitly creates the file; root '/' always exists for attrs.
    h5create(filepath, '/file_schema_version', [1 1], 'Datatype', 'uint8');
    h5write( filepath, '/file_schema_version', uint8(1));

    h5writeatt(filepath, '/', 'toolboxName',         'quantized_matlab');
    h5writeatt(filepath, '/', 'hdf5Schema',           '1.0');
    h5writeatt(filepath, '/', 'createdAt',            datestr(now, 'yyyy-mm-ddTHH:MM:SS')); %#ok<TNOW1,DATST>
    h5writeatt(filepath, '/', 'hasCorrected',         uint8(hasCorrData));
    h5writeatt(filepath, '/', 'hasPeaks',             uint8(hasPeaks));
    h5writeatt(filepath, '/', 'correctionsApplied',   uint8(correctionsApplied));

% ════════════════════════════════════════════════════════════════════════
%  /raw/   (always written)
% ════════════════════════════════════════════════════════════════════════

    writeDataGroup(filepath, '/raw', data);

% ════════════════════════════════════════════════════════════════════════
%  /corrected/   (optional)
% ════════════════════════════════════════════════════════════════════════

    if hasCorrData
        writeDataGroup(filepath, '/corrected', options.CorrData);
    end

% ════════════════════════════════════════════════════════════════════════
%  /corrections/   (optional)
% ════════════════════════════════════════════════════════════════════════

    if hasCorrections
        corrFieldNames = {'xOff','yOff','bgSlope','bgInt'};
        for fi = 1:numel(corrFieldNames)
            fn  = corrFieldNames{fi};
            val = 0.0;
            if isfield(options.Corrections, fn)
                val = double(options.Corrections.(fn));
            end
            dsPath = ['/corrections/', fn];
            h5create(filepath, dsPath, [1 1], 'Datatype', 'double');
            h5write( filepath, dsPath, val);
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  /peaks/   (optional)
% ════════════════════════════════════════════════════════════════════════

    if hasPeaks
        writePeaksGroup(filepath, options.Peaks);
    end

% ════════════════════════════════════════════════════════════════════════
%  /metadata/   — common fields as attributes; parserSpecific sub-group
% ════════════════════════════════════════════════════════════════════════

    % Sentinel dataset so the group exists before writing attributes.
    h5create(filepath, '/metadata/schema_version', [1 1], 'Datatype', 'uint8');
    h5write( filepath, '/metadata/schema_version', uint8(1));

    meta = data.metadata;

    h5writeatt(filepath, '/metadata', 'parserName',      safeCharAtt(meta, 'parserName'));
    h5writeatt(filepath, '/metadata', 'xColumnName',     safeCharAtt(meta, 'xColumnName'));
    h5writeatt(filepath, '/metadata', 'xColumnUnit',     safeCharAtt(meta, 'xColumnUnit'));
    h5writeatt(filepath, '/metadata', 'source',          safeCharAtt(meta, 'source'));
    h5writeatt(filepath, '/metadata', 'timeIsDatetime',  uint8(isdatetime(data.time)));

    if isfield(meta, 'importDate') && ~isempty(meta.importDate)
        try
            h5writeatt(filepath, '/metadata', 'importDate', ...
                datestr(meta.importDate, 'yyyy-mm-ddTHH:MM:SS')); %#ok<DATST>
        catch
            h5writeatt(filepath, '/metadata', 'importDate', char(meta.importDate));
        end
    end

    if isfield(meta, 'parserSpecific') && isstruct(meta.parserSpecific)
        h5create(filepath, '/metadata/parserSpecific/schema_version', [1 1], 'Datatype','uint8');
        h5write( filepath, '/metadata/parserSpecific/schema_version', uint8(1));
        writeStructAttrs(filepath, '/metadata/parserSpecific', meta.parserSpecific, '');
    end

% ════════════════════════════════════════════════════════════════════════
%  Verify (warning-only — does not mask a successfully written file)
% ════════════════════════════════════════════════════════════════════════

    try
        verifyHDF5(filepath);
    catch verifyErr
        warning('exportHDF5:verifyFailed', ...
            'Post-write verification failed: %s', verifyErr.message);
    end

end  % exportHDF5


% ════════════════════════════════════════════════════════════════════════
%  Private helpers
% ════════════════════════════════════════════════════════════════════════

function writeDataGroup(filepath, groupPath, d)
%WRITEDATAGROUP  Write time, values, labels, units into a /groupPath/ group.
    N = numel(d.time);
    M = size(d.values, 2);

    % ── time ──────────────────────────────────────────────────────────
    timePath = [groupPath, '/time'];
    if isdatetime(d.time)
        % Convert to [N×19] char matrix of ISO-8601 strings.
        strs    = cellstr(datestr(d.time, 'yyyy-mm-ddTHH:MM:SS')); %#ok<DATST>
        maxLen  = max(max(cellfun(@numel, strs)), 1);
        charMat = repmat(uint8(' '), N, maxLen);
        for r = 1:N
            s = uint8(strs{r});
            charMat(r, 1:numel(s)) = s;
        end
        h5create(filepath, timePath, size(charMat), 'Datatype', 'uint8');
        h5write( filepath, timePath, charMat);
        h5writeatt(filepath, timePath, 'encoding',      'ISO8601_padded_space');
        h5writeatt(filepath, timePath, 'timeIsDatetime', uint8(1));
    else
        tVec = double(d.time(:));
        h5create(filepath, timePath, [N 1], 'Datatype', 'double');
        h5write( filepath, timePath, tVec);
        h5writeatt(filepath, timePath, 'timeIsDatetime', uint8(0));
    end

    % ── values ────────────────────────────────────────────────────────
    valPath = [groupPath, '/values'];
    h5create(filepath, valPath, [N M], 'Datatype', 'double');
    h5write( filepath, valPath, double(d.values));

    % ── labels & units ────────────────────────────────────────────────
    writeCellStrDataset(filepath, [groupPath, '/labels'], d.labels);
    writeCellStrDataset(filepath, [groupPath, '/units'],  d.units);

    % ── group-level attributes ────────────────────────────────────────
    % Write a sentinel so the group path accepts attributes.
    sentinelPath = [groupPath, '/nRows'];
    h5create(filepath, sentinelPath, [1 1], 'Datatype', 'int32');
    h5write( filepath, sentinelPath, int32(N));
    h5writeatt(filepath, groupPath, 'nChannels',      int32(M));
    h5writeatt(filepath, groupPath, 'timeIsDatetime', uint8(isdatetime(d.time)));
end


function writeCellStrDataset(filepath, dsPath, cellArr)
%WRITECELLSTRDATASET  Write a cell array of strings as a padded uint8 matrix.
%   Each row is one string, space-padded to a uniform column count.
%   Attribute 'encoding'='ASCII_padded_space' and 'count' document the format.
    if isempty(cellArr)
        cellArr = {''};
    end
    strs   = cellfun(@(x) char(x), cellArr(:)', 'UniformOutput', false);
    M      = numel(strs);
    maxLen = max(max(cellfun(@numel, strs)), 1);

    charMat = repmat(uint8(' '), M, maxLen);
    for k = 1:M
        s = uint8(strs{k});
        if ~isempty(s)
            charMat(k, 1:numel(s)) = s;
        end
    end

    h5create(filepath, dsPath, size(charMat), 'Datatype', 'uint8');
    h5write( filepath, dsPath, charMat);
    h5writeatt(filepath, dsPath, 'encoding', 'ASCII_padded_space');
    h5writeatt(filepath, dsPath, 'count',    int32(M));
end


function writeStructAttrs(filepath, groupPath, s, prefix)
%WRITESTRUCTATTRS  Write every field of struct s as an HDF5 attribute on groupPath.
%   Nested structs are flattened one level with '<fieldname>_' prefix.
%   Skipped types are recorded as a '<name>__type' string attribute.
    fns = fieldnames(s);
    for fi = 1:numel(fns)
        fn       = fns{fi};
        val      = s.(fn);
        attrName = [prefix, fn];

        if isnumeric(val) && isscalar(val) && ~isnan(val)
            h5writeatt(filepath, groupPath, attrName, double(val));

        elseif isnumeric(val) && isscalar(val) && isnan(val)
            h5writeatt(filepath, groupPath, attrName, 'NaN');

        elseif isnumeric(val) && isvector(val) && numel(val) > 1 && numel(val) <= 64
            h5writeatt(filepath, groupPath, attrName, double(val(:))');

        elseif ischar(val)
            h5writeatt(filepath, groupPath, attrName, val);

        elseif isstring(val) && isscalar(val)
            h5writeatt(filepath, groupPath, attrName, char(val));

        elseif islogical(val) && isscalar(val)
            h5writeatt(filepath, groupPath, attrName, uint8(val));

        elseif isdatetime(val) && isscalar(val)
            try
                h5writeatt(filepath, groupPath, attrName, ...
                    datestr(val, 'yyyy-mm-ddTHH:MM:SS')); %#ok<DATST>
            catch
                % Non-finite or NaT datetime
                h5writeatt(filepath, groupPath, attrName, 'NaT');
            end

        elseif iscell(val) && ~isempty(val) && numel(val) <= 128 && ...
               all(cellfun(@(x) ischar(x) || (isstring(x) && isscalar(x)), val))
            joined = strjoin(cellfun(@char, val(:)', 'UniformOutput', false), '|');
            h5writeatt(filepath, groupPath, attrName,            joined);
            h5writeatt(filepath, groupPath, [attrName,'__delim'], '|');

        elseif isstruct(val) && isscalar(val) && isempty(prefix)
            % One level of recursion — flatten nested struct with underscore prefix.
            writeStructAttrs(filepath, groupPath, val, [fn, '_']);

        else
            % Unserialisable or oversized — record type so readers are not confused.
            h5writeatt(filepath, groupPath, [attrName,'__type'], class(val));
        end
    end
end


function writePeaksGroup(filepath, peaks)
%WRITEPEAKSGROUP  Write parallel peak datasets into /peaks/.
    P = numel(peaks);

    % Extract parallel vectors with NaN fallback for missing fields.
    center   = cellfun(@(pk) safeField(pk,'center'),  num2cell(peaks))';
    fwhm     = cellfun(@(pk) safeField(pk,'fwhm'),    num2cell(peaks))';
    height   = cellfun(@(pk) safeField(pk,'height'),  num2cell(peaks))';
    bg       = cellfun(@(pk) safeField(pk,'bg'),      num2cell(peaks))';

    xRlo = NaN(P,1);  xRhi = NaN(P,1);
    for pi = 1:P
        if isfield(peaks(pi),'xRange') && numel(peaks(pi).xRange) == 2
            xRlo(pi) = peaks(pi).xRange(1);
            xRhi(pi) = peaks(pi).xRange(2);
        end
    end

    status = cell(1,P);
    model  = cell(1,P);
    for pi = 1:P
        status{pi} = safeStrField(peaks(pi),'status','unknown');
        model{pi}  = safeStrField(peaks(pi),'model','');
    end

    % Sentinel that also stores count.
    h5create(filepath, '/peaks/count', [1 1], 'Datatype', 'uint32');
    h5write( filepath, '/peaks/count', uint32(P));

    writeScalarVec(filepath, '/peaks/center',    center);
    writeScalarVec(filepath, '/peaks/fwhm',      fwhm);
    writeScalarVec(filepath, '/peaks/height',    height);
    writeScalarVec(filepath, '/peaks/bg',        bg);
    writeScalarVec(filepath, '/peaks/xRange_lo', xRlo);
    writeScalarVec(filepath, '/peaks/xRange_hi', xRhi);

    writeCellStrDataset(filepath, '/peaks/status', status);
    writeCellStrDataset(filepath, '/peaks/model',  model);
end


function writeScalarVec(filepath, dsPath, vec)
%WRITESCALARVEC  h5create + h5write for a [P×1] double vector.
    P = numel(vec);
    h5create(filepath, dsPath, [P 1], 'Datatype', 'double');
    h5write( filepath, dsPath, double(vec(:)));
end


function v = safeField(pk, fn)
%SAFEFIELD  Extract a numeric scalar from struct field; return NaN if absent/empty.
    if isfield(pk, fn) && ~isempty(pk.(fn)) && isnumeric(pk.(fn))
        v = double(pk.(fn)(1));
    else
        v = NaN;
    end
end


function s = safeStrField(pk, fn, defaultVal)
%SAFESTRFIELD  Extract a string field from struct; return defaultVal if absent/empty.
    if isfield(pk, fn) && ~isempty(pk.(fn))
        s = char(pk.(fn));
    else
        s = defaultVal;
    end
end


function s = safeCharAtt(meta, fn)
%SAFECHARATT  Return char value of meta.fn, or '' if absent.
    if isfield(meta, fn) && ~isempty(meta.(fn))
        s = char(meta.(fn));
    else
        s = '';
    end
end


function verifyHDF5(filepath)
%VERIFYHDF5  Lightweight post-write sanity check.
    info = h5info(filepath);  % throws if file unreadable or corrupt

    groupNames = {};
    if ~isempty(info.Groups)
        groupNames = {info.Groups.Name};
    end
    assert(any(strcmp('/raw', groupNames)), ...
        'exportHDF5:verify:missingRawGroup', '/raw group not found in %s', filepath);

    t = h5read(filepath, '/raw/time');
    v = h5read(filepath, '/raw/values');
    assert(size(t,1) == size(v,1), ...
        'exportHDF5:verify:sizeMismatch', ...
        'time (%d rows) and values (%d rows) row count mismatch', ...
        size(t,1), size(v,1));
end
