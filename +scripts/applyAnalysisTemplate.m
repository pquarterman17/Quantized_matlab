function results = applyAnalysisTemplate(templatePath, files, options)
%APPLYANALYSISTEMPLATE  Batch-apply a saved BosonPlotter template to multiple files.
%
%   results = scripts.applyAnalysisTemplate('template.mat', {'a.dat','b.dat'})
%   results = scripts.applyAnalysisTemplate('template.mat', 'data_folder/')
%   results = scripts.applyAnalysisTemplate(..., 'OutputDir', 'csv_out/')
%   results = scripts.applyAnalysisTemplate(..., 'ExportPeaks', true)
%
%   Loads a template saved from BosonPlotter (Templates > Save Template...) and
%   applies the same corrections pipeline to each file: import → select columns →
%   apply corrections (offsets, background, smoothing, normalization, derivative,
%   trim) → optionally detect peaks → export corrected CSV.
%
%   This enables reproducible analysis workflows — set up your processing once
%   on a reference file, save the template, then batch-apply to all your data.
%
%   INPUTS:
%       templatePath — path to a .mat template file saved from BosonPlotter
%       files        — cell array of file paths, OR a directory path (string)
%                      If a directory, all supported files in it are processed.
%
%   OPTIONAL NAME-VALUE PAIRS:
%       OutputDir    — directory for exported CSVs (default: same as input file)
%       Recursive    — recurse into subdirectories when files is a directory
%                      (default: false)
%       ExportCSV    — export corrected data as CSV (default: true)
%       ExportPeaks  — run peak detection and export peak summary (default: false)
%       Verbose      — print progress to console (default: true)
%
%   OUTPUT:
%       results — struct array with fields:
%                   .name      — filename
%                   .filepath  — full path to input file
%                   .data      — raw imported data struct
%                   .corrData  — corrected data struct
%                   .peaks     — peak struct array (empty if ExportPeaks=false)
%                   .csvPath   — path to exported CSV (empty if ExportCSV=false)
%                   .error     — error message ('' if successful)
%
%   EXAMPLES:
%       % Apply XRD corrections template to all .xrdml files
%       results = scripts.applyAnalysisTemplate('xrd_template.mat', ...
%           {'scan1.xrdml', 'scan2.xrdml', 'scan3.xrdml'}, ...
%           'OutputDir', 'corrected/', 'ExportPeaks', true);
%
%       % Apply to an entire folder
%       results = scripts.applyAnalysisTemplate('mag_template.mat', ...
%           'measurements/', 'Recursive', true);
%
%       % Check results
%       ok = results(cellfun(@isempty, {results.error}));
%       fprintf('Processed %d / %d files successfully.\n', numel(ok), numel(results));
%
%   See also scripts.batchImport, scripts.batchConvertXRD, BosonPlotter

    arguments
        templatePath       (1,1) string {mustBeFile}
        files
        options.OutputDir  (1,1) string  = ""
        options.Recursive  (1,1) logical = false
        options.ExportCSV  (1,1) logical = true
        options.ExportPeaks(1,1) logical = false
        options.Verbose    (1,1) logical = true
    end

    % ── Load template ────────────────────────────────────────────────────
    tpl = load(templatePath);
    if options.Verbose
        fprintf('applyAnalysisTemplate: loaded template from %s\n', templatePath);
    end

    % ── Resolve file list ────────────────────────────────────────────────
    if ischar(files) || (isstring(files) && isscalar(files))
        % Directory path — find all supported files
        dirPath = char(files);
        if isfolder(dirPath)
            imported = scripts.batchImport(dirPath, ...
                'Recursive', options.Recursive, 'Verbose', false);
            fileList = {imported.filepath};
        else
            fileList = {char(files)};
        end
    elseif iscell(files)
        fileList = files;
    else
        error('scripts:applyAnalysisTemplate:badInput', ...
            'files must be a cell array of paths or a directory path.');
    end

    nFiles = numel(fileList);
    if nFiles == 0
        warning('scripts:applyAnalysisTemplate:noFiles', 'No files to process.');
        results = struct('name',{},'filepath',{},'data',{},'corrData',{}, ...
                         'peaks',{},'csvPath',{},'error',{});
        return;
    end

    if options.Verbose
        fprintf('applyAnalysisTemplate: processing %d file(s)...\n', nFiles);
    end

    % ── Create output directory if needed ────────────────────────────────
    if options.ExportCSV && strlength(options.OutputDir) > 0
        if ~isfolder(options.OutputDir)
            mkdir(char(options.OutputDir));
        end
    end

    % ── Process each file ────────────────────────────────────────────────
    results(nFiles) = struct('name','','filepath','','data',[], ...
        'corrData',[],'peaks',[],'csvPath','','error','');

    for k = 1:nFiles
        fp = char(fileList{k});
        [fdir, fname, fext] = fileparts(fp);
        results(k).name     = [fname, fext];
        results(k).filepath = fp;

        try
            % Import
            data = parser.importAuto(fp);
            results(k).data = data;

            % Apply corrections pipeline
            corrData = applyPipeline(data, tpl);
            results(k).corrData = corrData;

            % Peak detection (optional)
            if options.ExportPeaks
                peaks = detectPeaks(corrData);
                results(k).peaks = peaks;
            end

            % Export corrected CSV
            if options.ExportCSV
                if strlength(options.OutputDir) > 0
                    outDir = char(options.OutputDir);
                else
                    outDir = fdir;
                end
                csvName = [fname, '_corrected.csv'];
                csvPath = fullfile(outDir, csvName);
                exportCorrectedCSV(corrData, csvPath);
                results(k).csvPath = csvPath;
            end

            % Export peak summary
            if options.ExportPeaks && ~isempty(results(k).peaks)
                if strlength(options.OutputDir) > 0
                    outDir = char(options.OutputDir);
                else
                    outDir = fdir;
                end
                peakPath = fullfile(outDir, [fname, '_peaks.csv']);
                exportPeakCSV(results(k).peaks, peakPath, [fname, fext]);
            end

            results(k).error = '';
            if options.Verbose
                fprintf('  [OK]  %s\n', [fname, fext]);
            end

        catch ME
            results(k).corrData = [];
            results(k).error = ME.message;
            if options.Verbose
                fprintf('  [ERR] %s — %s\n', [fname, fext], ME.message);
            end
        end
    end

    nOk  = sum(cellfun(@isempty, {results.error}));
    nErr = nFiles - nOk;
    if options.Verbose
        fprintf('applyAnalysisTemplate: done — %d ok, %d failed.\n', nOk, nErr);
    end
end


% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function corrData = applyPipeline(data, tpl)
%APPLYPIPELINE  Apply template corrections to imported data struct.
    corrData = data;

    % X offset
    xOff = getField(tpl, 'xOff', 0);
    if xOff ~= 0
        corrData.time = corrData.time + xOff;
    end

    % Y offset
    yOff = getField(tpl, 'yOff', 0);
    if yOff ~= 0
        corrData.values = corrData.values + yOff;
    end

    % Background subtraction (linear)
    bgSlope = getField(tpl, 'bgSlope', 0);
    bgInt   = getField(tpl, 'bgInt', 0);
    if bgSlope ~= 0 || bgInt ~= 0
        x = double(corrData.time);
        bg = bgSlope * x + bgInt;
        corrData.values = corrData.values - bg;
    end

    % X trim
    xTrimMin = getField(tpl, 'xTrimMin', NaN);
    xTrimMax = getField(tpl, 'xTrimMax', NaN);
    if ~isnan(xTrimMin) || ~isnan(xTrimMax)
        x = double(corrData.time);
        mask = true(size(x));
        if ~isnan(xTrimMin), mask = mask & (x >= xTrimMin); end
        if ~isnan(xTrimMax), mask = mask & (x <= xTrimMax); end
        corrData.time   = corrData.time(mask);
        corrData.values = corrData.values(mask, :);
    end

    % Smoothing
    smoothEnabled = getField(tpl, 'smoothEnabled', false);
    if smoothEnabled
        win  = max(1, round(getField(tpl, 'smoothWindow', 5)));
        meth = lower(getField(tpl, 'smoothMethod', 'Moving'));
        corrData.values = utilities.smoothData(corrData.values, ...
            'Window', win, 'Method', meth);
    end

    % Normalization
    normMethod = getField(tpl, 'normMethod', 'None');
    switch normMethod
        case 'Range [0,1]'
            corrData.values = utilities.normalize(corrData.values, 'Method', 'range');
        case 'Peak (max=1)'
            corrData.values = utilities.normalize(corrData.values, 'Method', 'peak');
        case 'Z-score'
            corrData.values = utilities.normalize(corrData.values, 'Method', 'zscore');
        case 'Area (integral=1)'
            x = double(corrData.time);
            for j = 1:size(corrData.values, 2)
                A = trapz(x, abs(corrData.values(:, j)));
                if A > 0
                    corrData.values(:, j) = corrData.values(:, j) / A;
                end
            end
    end

    % Derivative
    derivMode = getField(tpl, 'derivativeMode', 'None');
    x = double(corrData.time);
    switch derivMode
        case 'dY/dX'
            corrData.values = utilities.derivative(x, corrData.values);
        case 'd²Y/dX²'
            corrData.values = utilities.derivative(x, corrData.values, 'Order', 2);
        case '∫Y dx'
            corrData.values = utilities.cumulativeIntegral(x, corrData.values);
        case 'dlog/dlog'
            for j = 1:size(corrData.values, 2)
                corrData.values(:, j) = utilities.logDerivative(x, corrData.values(:, j));
            end
    end
end


function peaks = detectPeaks(corrData)
%DETECTPEAKS  Run peak detection on corrected data.
    x = double(corrData.time);
    y = corrData.values(:, 1);  % Use first Y column
    valid = ~isnan(x) & ~isnan(y);
    x = x(valid); y = y(valid);

    try
        peakInfo = utilities.findPeaksRobust(x, y);
        peaks = peakInfo;
    catch
        peaks = [];
    end
end


function exportCorrectedCSV(corrData, csvPath)
%EXPORTCORRECTEDCSV  Write corrected data struct to CSV.
    x = double(corrData.time);
    vals = corrData.values;

    % Build header
    xLabel = 'X';
    if isfield(corrData, 'metadata') && isfield(corrData.metadata, 'xColumn')
        xLabel = corrData.metadata.xColumn;
    end

    labels = corrData.labels;
    if ischar(labels), labels = {labels}; end
    if isstring(labels), labels = cellstr(labels); end

    header = [xLabel, labels(:)'];

    % Write
    fid = fopen(csvPath, 'w');
    if fid == -1
        error('Cannot write to: %s', csvPath);
    end
    fprintf(fid, '%s', header{1});
    for j = 2:numel(header)
        fprintf(fid, ',%s', header{j});
    end
    fprintf(fid, '\n');

    mat = [x, vals];
    for r = 1:size(mat, 1)
        fprintf(fid, '%.10g', mat(r, 1));
        for j = 2:size(mat, 2)
            fprintf(fid, ',%.10g', mat(r, j));
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
end


function exportPeakCSV(peaks, csvPath, sourceName)
%EXPORTPEAKCSV  Write peak summary to CSV.
    fid = fopen(csvPath, 'w');
    if fid == -1
        error('Cannot write to: %s', csvPath);
    end
    fprintf(fid, 'Source,Center,Height,FWHM,Area\n');
    for p = 1:numel(peaks)
        pk = peaks(p);
        center = getField(pk, 'center', NaN);
        height = getField(pk, 'height', NaN);
        fwhm   = getField(pk, 'fwhm',   NaN);
        area   = getField(pk, 'area',   NaN);
        fprintf(fid, '%s,%.6g,%.6g,%.6g,%.6g\n', ...
            sourceName, center, height, fwhm, area);
    end
    fclose(fid);
end


function val = getField(s, fieldName, default)
%GETFIELD  Safely get a struct field with a default value.
    if isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = default;
    end
end
