classdef TemplateEngine
%TEMPLATEENGINE  Load, save, match, and apply dataset templates.
%
%   templates.TemplateEngine.loadAll()
%   templates.TemplateEngine.match(data)
%   templates.TemplateEngine.apply(data, tmpl)
%   templates.TemplateEngine.save(tmpl)
%   templates.TemplateEngine.delete(name)
%   templates.TemplateEngine.fingerprint(data)
%
%   Templates are JSON files that capture column role overrides (tabular
%   data) or metadata overrides (images).  Shipped defaults live in
%   +templates/defaults/; user-created templates in prefdir/boson_templates/.
%
%   See also templates.ColumnMapper, templates.MetadataEditor

    methods (Static)

        function all = loadAll(opts)
        %LOADALL  Scan defaults + user dirs, return cell array of template structs.
            arguments
                opts.ForceReload (1,1) logical = false
            end
            persistent cache
            if ~isempty(cache) && ~opts.ForceReload
                all = cache;
                return;
            end

            all = {};
            % Shipped defaults
            defaultDir = fullfile(fileparts(mfilename('fullpath')), 'defaults');
            if isfolder(defaultDir)
                all = [all; loadJsonDir(defaultDir, 'shipped')];
            end
            % User templates (searched first during match — appended last,
            % but match() iterates in reverse so user templates win)
            userDir = templates.TemplateEngine.userDir();
            if isfolder(userDir)
                all = [all; loadJsonDir(userDir, 'user')];
            end
            cache = all;
        end

        function clearCache()
        %CLEARCACHE  Force next loadAll to re-read from disk.
            templates.TemplateEngine.loadAll(ForceReload=true);
        end

        function tmpl = save(tmpl)
        %SAVE  Write a template struct to the user template directory as JSON.
        %   tmpl must have at least .name and .type fields.
            arguments
                tmpl (1,1) struct
            end
            assert(isfield(tmpl, 'name') && ~isempty(tmpl.name), ...
                'templates:save:noName', 'Template must have a .name field.');
            assert(isfield(tmpl, 'type') && ~isempty(tmpl.type), ...
                'templates:save:noType', 'Template must have a .type field.');

            tmpl.version = 1;
            tmpl.source  = 'user';
            if ~isfield(tmpl, 'created') || isempty(tmpl.created)
                tmpl.created = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
            end

            ud = templates.TemplateEngine.userDir();
            if ~isfolder(ud), mkdir(ud); end

            safeName = regexprep(tmpl.name, '[^\w\-]', '_');
            outPath  = fullfile(ud, [safeName '.json']);
            fid = fopen(outPath, 'w', 'n', 'UTF-8');
            assert(fid > 0, 'templates:save:fileOpen', ...
                'Could not open %s for writing.', outPath);
            cleanupFid = onCleanup(@() fclose(fid));
            txt = jsonencode(tmpl, PrettyPrint=true);
            fwrite(fid, txt, 'char');

            % Bust cache so next loadAll picks up the new file
            templates.TemplateEngine.clearCache();
        end

        function delete(name)
        %DELETE  Remove a user template by name.
            arguments
                name (1,:) char
            end
            ud = templates.TemplateEngine.userDir();
            safeName = regexprep(name, '[^\w\-]', '_');
            target = fullfile(ud, [safeName '.json']);
            if isfile(target)
                builtin('delete', target);
                templates.TemplateEngine.clearCache();
            end
        end

        function result = apply(data, tmpl)
        %APPLY  Return a new data struct with template overrides applied.
        %   Never mutates the input. Works for both 'tabular' and
        %   'image_metadata' template types.
            arguments
                data  (1,1) struct
                tmpl  (1,1) struct
            end
            result = data;

            if ~isfield(tmpl, 'overrides') || isempty(tmpl.overrides)
                return;
            end
            ov = tmpl.overrides;

            if strcmp(tmpl.type, 'tabular')
                result = applyTabular(result, ov);
            elseif strcmp(tmpl.type, 'image_metadata')
                result = applyImageMetadata(result, ov);
            end
        end

        function fp = fingerprint(data)
        %FINGERPRINT  Hash column names + count + parserName into a hex string.
        %   Deterministic: same column layout always produces the same hash.
            arguments
                data (1,1) struct
            end
            parts = {};
            if isfield(data, 'labels')
                sortedLabels = sort(data.labels);
                parts = [parts, sortedLabels];
            end
            if isfield(data, 'metadata') && isfield(data.metadata, 'parserName')
                parts = [parts, {data.metadata.parserName}];
            end
            nCols = 0;
            if isfield(data, 'values')
                nCols = size(data.values, 2);
            end
            parts = [parts, {sprintf('ncols=%d', nCols)}];

            raw = strjoin(parts, '|');
            fp = fnv1a(raw);
        end

        function [bestTmpl, bestConf] = match(data, opts)
        %MATCH  Run the 5-step confidence cascade, return best template + score.
        %   Returns empty + 0 if no templates are loaded.
            arguments
                data (1,1) struct
                opts.Type (1,:) char = ''  % 'tabular' or 'image_metadata'; '' = auto-detect
            end

            allTemplates = templates.TemplateEngine.loadAll();
            bestTmpl = [];
            bestConf = 0;

            if isempty(allTemplates)
                return;
            end

            % Auto-detect type
            tmplType = opts.Type;
            if isempty(tmplType)
                if isfield(data, 'values') && ~isempty(data.values)
                    tmplType = 'tabular';
                else
                    tmplType = 'image_metadata';
                end
            end

            dataFP = templates.TemplateEngine.fingerprint(data);
            dataParser = '';
            dataInstrument = '';
            dataFile = '';
            dataColNames = {};
            if isfield(data, 'metadata')
                m = data.metadata;
                if isfield(m, 'parserName'),    dataParser = m.parserName; end
                if isfield(m, 'source'),        dataFile = m.source; end
                if isfield(m, 'parserSpecific')
                    ps = m.parserSpecific;
                    if isfield(ps, 'instrument'),   dataInstrument = ps.instrument; end
                    if isfield(ps, 'instrumentType'), dataInstrument = ps.instrumentType; end
                end
            end
            if isfield(data, 'labels')
                dataColNames = data.labels;
            end

            % Iterate all templates (user templates are last → checked last →
            % win ties because we use > not >=)
            for k = 1:numel(allTemplates)
                t = allTemplates{k};
                if ~strcmp(t.type, tmplType), continue; end

                conf = scoreTemplate(t, dataFP, dataParser, dataInstrument, ...
                                     dataFile, dataColNames);
                if conf > bestConf
                    bestConf = conf;
                    bestTmpl = t;
                end
            end
        end

        function d = userDir()
        %USERDIR  Path to the user template directory under prefdir.
            d = fullfile(prefdir, 'boson_templates');
        end

    end % methods (Static)
end % classdef


% ════════════════════════════════════════════════════════════════════════
%  Local helper functions
% ════════════════════════════════════════════════════════════════════════

function templates = loadJsonDir(dirPath, source)
%LOADJSONDIR  Load all .json files from a directory into template structs.
    templates = {};
    listing = dir(fullfile(dirPath, '*.json'));
    for k = 1:numel(listing)
        fp = fullfile(listing(k).folder, listing(k).name);
        try
            txt = fileread(fp);
            t = jsondecode(txt);
            t.source_ = source;      % track origin
            t.filePath_ = fp;        % track file location
            templates{end+1, 1} = t; %#ok<AGROW>
        catch
            % Skip malformed JSON
        end
    end
end


function conf = scoreTemplate(t, dataFP, dataParser, dataInstrument, ...
                              dataFile, dataColNames)
%SCORETEMPLATE  5-step cascade returning max confidence for one template.
    conf = 0;
    if ~isfield(t, 'match'), return; end
    m = t.match;

    % Step 1: Header fingerprint (exact match → 1.0)
    if isfield(m, 'headerFingerprint') && ~isempty(m.headerFingerprint)
        if strcmp(m.headerFingerprint, dataFP)
            conf = max(conf, 1.0);
            return;  % can't beat 1.0
        end
    end

    % Step 2: Fuzzy header match (Jaccard on column names)
    if isfield(m, 'columnNames') && ~isempty(m.columnNames) && ~isempty(dataColNames)
        tmplTokens = normalizeNames(m.columnNames);
        dataTokens = normalizeNames(dataColNames);
        j = jaccardIndex(tmplTokens, dataTokens);
        conf = max(conf, j);
    end

    % Step 3: Parser type + instrument (→ 0.6)
    if isfield(m, 'parserName') && ~isempty(m.parserName) && ~isempty(dataParser)
        if strcmp(m.parserName, dataParser)
            if isfield(m, 'instrument') && ~isempty(m.instrument) && ~isempty(dataInstrument)
                if contains(lower(dataInstrument), lower(m.instrument))
                    conf = max(conf, 0.6);
                end
            else
                % Parser match only (no instrument check) → 0.3
                conf = max(conf, 0.3);
            end
        end
    end

    % Step 4: File name pattern (→ 0.4)
    if isfield(m, 'filePattern') && ~isempty(m.filePattern) && ~isempty(dataFile)
        [~, fname, fext] = fileparts(dataFile);
        basename = [fname fext];
        % Convert glob to regex: * → .*, ? → .
        pat = ['^' regexptranslate('wildcard', m.filePattern) '$'];
        if ~isempty(regexp(basename, pat, 'once', 'ignorecase'))
            conf = max(conf, 0.4);
        end
    end
end


function tokens = normalizeNames(names)
%NORMALIZENAMES  Tokenize and lowercase column names for fuzzy matching.
%   "Temperature (K)" → {"temperature", "k"}
    if ischar(names), names = {names}; end
    if isstruct(names) || (~iscell(names) && isstring(names))
        names = cellstr(names);
    end
    tokens = {};
    for k = 1:numel(names)
        raw = lower(char(names{k}));
        raw = regexprep(raw, '[^a-z0-9]', ' ');
        parts = strsplit(strtrim(raw));
        parts(cellfun(@isempty, parts)) = [];
        tokens = [tokens, parts]; %#ok<AGROW>
    end
    tokens = unique(tokens);
end


function j = jaccardIndex(setA, setB)
%JACCARDINDEX  |intersection| / |union| of two cell arrays of strings.
    if isempty(setA) && isempty(setB)
        j = 0;
        return;
    end
    inter = numel(intersect(setA, setB));
    uni   = numel(union(setA, setB));
    j = inter / uni;
end


function hex = fnv1a(str)
%FNV1A  FNV-1a 32-bit hash of a char vector, returned as 8-char hex string.
%   Pure MATLAB, no toolbox dependency.
    hash = uint32(2166136261);  % FNV offset basis
    prime = uint32(16777619);   % FNV prime
    bytes = uint8(str);
    for k = 1:numel(bytes)
        hash = bitxor(hash, uint32(bytes(k)));
        hash = mod(uint64(hash) * uint64(prime), uint64(2^32));
        hash = uint32(hash);
    end
    hex = lower(dec2hex(hash, 8));
end


function result = applyTabular(data, ov)
%APPLYTABULAR  Apply tabular overrides (column reassignment, labels, units).
    result = data;

    % Reconstruct from full column set if parser stored them
    allCols = [];
    if isfield(data, 'metadata') && isfield(data.metadata, 'parserSpecific')
        ps = data.metadata.parserSpecific;
        if isfield(ps, 'allColumns')
            allCols = ps.allColumns;
        end
    end

    % X column override
    if isfield(ov, 'xColumn') && ~isempty(allCols)
        xIdx = ov.xColumn + 1;  % JSON uses 0-based
        if xIdx >= 1 && xIdx <= size(allCols, 2)
            result.time = allCols(:, xIdx);
            if isfield(data.metadata, 'xColumnName')
                result.metadata.xColumnName = sprintf('Column %d', xIdx);
            end
        end
    end

    % Y columns override
    if isfield(ov, 'yColumns') && ~isempty(allCols)
        yIdx = ov.yColumns + 1;  % JSON 0-based → MATLAB 1-based
        valid = yIdx >= 1 & yIdx <= size(allCols, 2);
        yIdx = yIdx(valid);
        if ~isempty(yIdx)
            result.values = allCols(:, yIdx);
        end
    end

    % Label overrides (keyed by column index as string)
    if isfield(ov, 'labels') && isstruct(ov.labels)
        flds = fieldnames(ov.labels);
        for k = 1:numel(flds)
            idx = str2double(flds{k}) + 1;  % 0-based → 1-based
            if idx >= 1 && idx <= numel(result.labels)
                result.labels{idx} = ov.labels.(flds{k});
            end
        end
    end

    % Unit overrides (same keying)
    if isfield(ov, 'units') && isstruct(ov.units)
        flds = fieldnames(ov.units);
        for k = 1:numel(flds)
            idx = str2double(flds{k}) + 1;
            if idx >= 1 && idx <= numel(result.units)
                result.units{idx} = ov.units.(flds{k});
            end
        end
    end
end


function result = applyImageMetadata(data, ov)
%APPLYIMAGEMETADATA  Apply image metadata overrides (sample name, pixel size, etc.).
    result = data;
    if ~isfield(result, 'metadata')
        result.metadata = struct();
    end
    if ~isfield(result.metadata, 'parserSpecific')
        result.metadata.parserSpecific = struct();
    end

    overrideFields = fieldnames(ov);
    for k = 1:numel(overrideFields)
        fn = overrideFields{k};
        val = ov.(fn);
        % Known top-level metadata fields
        if ismember(fn, {'sampleName', 'pixelSize', 'pixelUnit', 'voltage', ...
                         'operator', 'magnification', 'detector'})
            result.metadata.parserSpecific.(fn) = val;

            % Also update imageData sub-struct if it exists
            if isfield(result.metadata.parserSpecific, 'imageData')
                img = result.metadata.parserSpecific.imageData;
                if isfield(img, fn)
                    result.metadata.parserSpecific.imageData.(fn) = val;
                end
            end
        end
    end
end
