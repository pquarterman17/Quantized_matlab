function results = batchApplyTemplate(folder, templateName, options)
%BATCHAPPLYTEMPLATE  Import files from a folder and apply a named dataset template.
%
%   results = scripts.batchApplyTemplate('/path/to/data', 'QD VSM — M vs H')
%   results = scripts.batchApplyTemplate(folder, '')          % auto-match per file
%   results = scripts.batchApplyTemplate(folder, name, Recursive=true)
%   results = scripts.batchApplyTemplate(folder, name, ExportCSV=false)
%   results = scripts.batchApplyTemplate(folder, name, OutputDir='/out/')
%
%   Walks the folder (optionally recursively), imports every supported file
%   via parser.importAuto, matches or applies the named dataset template,
%   and optionally exports the corrected data to CSV.
%
%   If templateName is empty ('') the best-matching template is auto-selected
%   per file via templates.TemplateEngine.match().  Files with no template
%   match (confidence == 0) are still returned but have .templateApplied = false.
%
%   Inputs
%   ------
%   folder       — path to the root folder to process (char or string)
%   templateName — exact template name to apply, or '' for auto-match
%
%   Optional Name-Value Inputs
%   --------------------------
%   Recursive  — recurse into subdirectories (default: true)
%   OutputDir  — directory for exported CSV files; defaults to folder when
%                empty and ExportCSV is true
%   ExportCSV  — write corrected data to CSV (default: true)
%
%   Outputs
%   -------
%   results — struct array (one element per file) with fields:
%     .name            — filename (without path)
%     .filepath        — full source path
%     .templateName    — name of the template applied ('' if none)
%     .templateApplied — logical, true if a template was applied
%     .confidence      — match confidence (0 if templateName was specified exactly)
%     .data            — corrected data struct ([] if import failed)
%     .csvPath         — path of the exported CSV ('' if not exported)
%     .error           — error message ('' on success)
%
%   Examples
%   --------
%   % Apply a named template to all files in a folder
%   res = scripts.batchApplyTemplate('data/', 'QD VSM — M vs H');
%   ok  = res(~cellfun(@isempty, {res.data}));
%   fprintf('Applied template to %d / %d files.\n', ...
%       sum([ok.templateApplied]), numel(res));
%
%   % Auto-match templates and export to a separate output folder
%   res = scripts.batchApplyTemplate('data/', '', OutputDir='corrected/');
%
%   See also scripts.batchImport, templates.TemplateEngine, parser.importAuto

% ════════════════════════════════════════════════════════════════════

arguments
    folder       (1,:) char
    templateName (1,:) char
    options.Recursive  (1,1) logical = true
    options.OutputDir  (1,:) char    = ''
    options.ExportCSV  (1,1) logical = true
end

% ── Resolve template (for exact-name mode) ────────────────────────────

namedTmpl = [];
if ~isempty(templateName)
    all = templates.TemplateEngine.loadAll();
    for k = 1:numel(all)
        if strcmp(all{k}.name, templateName)
            namedTmpl = all{k};
            break;
        end
    end
    if isempty(namedTmpl)
        error('scripts:batchApplyTemplate:unknownTemplate', ...
            'No template named "%s" found. Use templates.TemplateEngine.loadAll() to see available names.', ...
            templateName);
    end
end

% ── Collect files ─────────────────────────────────────────────────────

supportedExts = {'.dat','.csv','.tsv','.txt','.xlsx','.xls','.raw', ...
                 '.xrdml','.brml','.refl','.pnr', ...
                 '.datA','.datB','.datC','.datD'};

if options.Recursive
    allFiles = findFilesRecursive(folder, supportedExts);
else
    allFiles = findFilesFlat(folder, supportedExts);
end

nFiles = numel(allFiles);
if nFiles == 0
    warning('scripts:batchApplyTemplate:noFiles', ...
        'No supported files found in: %s', folder);
    results = struct('name',{},'filepath',{},'templateName',{},'templateApplied',{}, ...
                     'confidence',{},'data',{},'csvPath',{},'error',{});
    return;
end

% ── Resolve output directory ──────────────────────────────────────────

outDir = options.OutputDir;
if options.ExportCSV && isempty(outDir)
    outDir = folder;
end
if options.ExportCSV && ~isfolder(outDir)
    mkdir(outDir);
end

% ── Process each file ─────────────────────────────────────────────────

emptyEntry = struct('name','','filepath','','templateName','','templateApplied',false, ...
                    'confidence',0,'data',[],'csvPath','','error','');
results = repmat(emptyEntry, nFiles, 1);

fprintf('batchApplyTemplate: processing %d file(s) in %s\n', nFiles, folder);

for k = 1:nFiles
    fp = allFiles{k};
    [~, fname, fext] = fileparts(fp);
    results(k).name     = [fname, fext];
    results(k).filepath = fp;

    % Import
    try
        rawData = parser.importAuto(fp);
    catch ME
        results(k).error = ['Import failed: ' ME.message];
        fprintf('  [ERR] %s — %s\n', results(k).name, ME.message);
        continue;
    end

    % Match / apply template
    try
        if ~isempty(namedTmpl)
            % Exact-name mode: apply without confidence scoring
            tmpl = namedTmpl;
            conf = 0;
        else
            % Auto-match mode
            [tmpl, conf] = templates.TemplateEngine.match(rawData);
        end

        if ~isempty(tmpl)
            corrected = templates.TemplateEngine.apply(rawData, tmpl);
            results(k).templateName    = tmpl.name;
            results(k).templateApplied = true;
            results(k).confidence      = conf;
            results(k).data            = corrected;
        else
            results(k).data = rawData;
        end
    catch ME
        results(k).data  = rawData;
        results(k).error = ['Template apply failed: ' ME.message];
        fprintf('  [WARN] %s — template apply error: %s\n', results(k).name, ME.message);
    end

    % Export CSV
    if options.ExportCSV && ~isempty(results(k).data)
        try
            csvName = [fname, '.csv'];
            csvPath = fullfile(outDir, csvName);
            exportToCSV(results(k).data, csvPath);
            results(k).csvPath = csvPath;
        catch ME
            results(k).error = [results(k).error ' CSV export failed: ' ME.message];
            fprintf('  [WARN] %s — CSV export error: %s\n', results(k).name, ME.message);
        end
    end

    if results(k).templateApplied
        fprintf('  [OK]  %s → "%s" (conf=%.2f)\n', results(k).name, ...
            results(k).templateName, results(k).confidence);
    else
        fprintf('  [OK]  %s — no template applied\n', results(k).name);
    end
end

nApplied = sum([results.templateApplied]);
nErr     = sum(~cellfun(@isempty, {results.error}));
fprintf('batchApplyTemplate: done — %d template(s) applied, %d error(s).\n', nApplied, nErr);

end


% ════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════

function files = findFilesFlat(dir_, exts)
%FINDFILESFLAT  Return full paths of matching files in a single directory.
    files = {};
    listing = dir(dir_);
    for k = 1:numel(listing)
        if listing(k).isdir, continue; end
        [~, ~, ext] = fileparts(listing(k).name);
        if any(strcmpi(ext, exts))
            files{end+1} = fullfile(dir_, listing(k).name); %#ok<AGROW>
        end
    end
end

function files = findFilesRecursive(dir_, exts)
%FINDFILESRECURSIVE  Return full paths of matching files in dir_ and subdirs.
    files   = findFilesFlat(dir_, exts);
    listing = dir(dir_);
    for k = 1:numel(listing)
        if ~listing(k).isdir || listing(k).name(1) == '.', continue; end
        sub = fullfile(dir_, listing(k).name);
        files = [files, findFilesRecursive(sub, exts)]; %#ok<AGROW>
    end
end

function exportToCSV(data, csvPath)
%EXPORTTOCSV  Write a data struct to a CSV file.
%   First column is data.time; remaining columns are data.values.
%   Row 1 = labels, Row 2 = units, remaining rows = numeric data.
    if ~isfield(data, 'time') || ~isfield(data, 'values')
        error('scripts:batchApplyTemplate:exportToCSV:missingFields', ...
            'data struct must have .time and .values fields.');
    end

    mat = [data.time, data.values];
    nCols = size(mat, 2);

    % Build header
    labels = {};
    units  = {};
    if isfield(data, 'labels') && numel(data.labels) == size(data.values, 2)
        % Prepend x-axis label
        xLabel = 'X';
        if isfield(data.metadata, 'xColumnName') && ~isempty(data.metadata.xColumnName)
            xLabel = data.metadata.xColumnName;
        end
        labels = [{xLabel}, data.labels];
    else
        labels = arrayfun(@(i) sprintf('Col%d', i), 1:nCols, 'UniformOutput', false);
    end
    if isfield(data, 'units') && numel(data.units) == size(data.values, 2)
        xUnit = '';
        if isfield(data.metadata, 'xColumnUnit')
            xUnit = data.metadata.xColumnUnit;
        end
        units = [{xUnit}, data.units];
    else
        units = repmat({''}, 1, nCols);
    end

    fid = fopen(csvPath, 'w', 'n', 'UTF-8');
    assert(fid > 0, 'scripts:batchApplyTemplate:exportToCSV:openFailed', ...
        'Could not open %s for writing.', csvPath);
    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, '%s\n', strjoin(labels, ','));
    fprintf(fid, '%s\n', strjoin(units,  ','));

    fmtStr = [repmat('%.8g,', 1, nCols-1), '%.8g\n'];
    for row = 1:size(mat, 1)
        fprintf(fid, fmtStr, mat(row, :));
    end
end
