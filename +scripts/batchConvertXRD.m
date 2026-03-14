function results = batchConvertXRD(files, options)
% ════════════════════════════════════════════════════════════════════════
% Batch convert XRD files (XRDML, Rigaku .raw, Bruker .brml) to CSV/Origin.
% ════════════════════════════════════════════════════════════════════════
%
% Syntax:
%   results = scripts.batchConvertXRD(files)
%   results = scripts.batchConvertXRD(files, Name=Value)
%
% Inputs:
%   files      String array of file paths OR single string (folder path)
%              If folder: auto-discovers XRD files (.xrdml, .raw, .brml)
%              If file list: uses files as-is
%
% Name-Value Options:
%   Format          "standard" (default) | "origin" | "com"
%                   Output format: standard CSV, Origin ASCII, or COM (Origin workbook)
%   OutputDir       string = ""
%                   Output directory. Empty = same folder as source. Otherwise all files go here.
%   Recursive       logical = false
%                   When input is folder, recurse into subdirectories
%   Intensity       "both" (default) | "cps" | "counts"
%                   Which intensity columns to write
%   IncludeMetadata logical = true
%                   Write metadata header block in CSV
%   Verbose         logical = true
%                   Print progress to console
%   ProgressFcn     function_handle = []
%                   Callback function: @(k, n, filename) for GUI progress updates
%
% Outputs:
%   results         Struct array with fields:
%                   .name       filename (no path)
%                   .filepath   full source path
%                   .outputFile full output path (empty for COM format)
%                   .data       parsed data struct (empty [] if error)
%                   .error      error message ('' if OK)
%
% Examples:
%   % Convert all XRD files in a directory to standard CSV
%   results = scripts.batchConvertXRD('test_datasets/XRDML/');
%
%   % Convert explicit file list to Origin ASCII
%   files = ["sample1.xrdml", "sample2.xrdml"];
%   results = scripts.batchConvertXRD(files, Format="origin");
%
%   % Convert to custom output directory
%   results = scripts.batchConvertXRD('measurements/', OutputDir="output/", Recursive=true);
%
%   % Convert with GUI progress callback
%   results = scripts.batchConvertXRD('data/', ProgressFcn=@updateGUIProgress);
%
% ════════════════════════════════════════════════════════════════════════

arguments
    files string
    options.Format string = "standard"
    options.OutputDir string = ""
    options.Recursive logical = false
    options.Intensity string = "both"
    options.IncludeMetadata logical = true
    options.Verbose logical = true
    options.ProgressFcn = []
end

% Validate format option
validatestring(options.Format, ["standard", "origin", "com"]);

% Validate ProgressFcn if provided
if ~isempty(options.ProgressFcn) && ~isa(options.ProgressFcn, 'function_handle')
    error("scripts:batchConvertXRD:badProgressFcn", ...
        "ProgressFcn must be a function handle or empty");
end

% Resolve file list
fileList = resolveFileList(files, options.Recursive);

if isempty(fileList)
    if options.Verbose
        fprintf("batchConvertXRD: no XRD files found.\n");
    end
    results = struct.empty;
    return;
end

nFiles = numel(fileList);
if options.Verbose
    fprintf("batchConvertXRD: found %d XRD file(s)\n", nFiles);
end

% Initialize results array (pre-allocate if possible, otherwise start empty)
if nFiles > 0
    results = repmat(struct('name', '', 'filepath', '', 'outputFile', '', 'data', [], 'error', ''), nFiles, 1);
else
    results = struct.empty;
end

% For COM format, open one workbook to accumulate sheets
if strcmp(options.Format, "com")
    [comSuccess, originApp] = initComWorkbook('XRD_BatchExport');
    if ~comSuccess
        warning("batchConvertXRD: Origin COM server not available");
    end
end

% Loop over files
nOk = 0;
nErr = 0;

for k = 1:nFiles
    filepath = fileList{k};
    [~, filename, ext] = fileparts(filepath);
    fullFilename = string(filename) + string(ext);  % Convert to string for concatenation

    try
        % Parse the file
        data = parser.importAuto(filepath);

        % Determine output path
        if strcmp(options.Format, "com")
            % COM format doesn't write files; workbook accumulates sheets
            outFile = "";
        else
            if strlength(options.OutputDir) == 0
                % Same folder as source
                [srcDir, ~, ~] = fileparts(filepath);
                outFile = fullfile(srcDir, filename + ".csv");
            else
                % Custom output directory
                outFile = fullfile(options.OutputDir, filename + ".csv");
            end
        end

        % Write output
        if strcmp(options.Format, "com")
            % Send to Origin workbook via COM
            if exist('originApp', 'var') && ~isempty(originApp)
                % Truncate sheet name to 30 chars (Origin limit)
                sheetName = filename;
                if strlength(sheetName) > 30
                    sheetName = extractBefore(sheetName, 31);
                end
                try
                    utilities.toOrigin(data, SheetName=sheetName, BookName='XRD_BatchExport');
                catch ME
                    error("COM:sendFailed", ME.message);
                end
            end
        else
            % Write CSV file
            utilities.writeXRDcsv(data, outFile, ...
                Format=options.Format, ...
                Intensity=options.Intensity, ...
                IncludeMetadata=options.IncludeMetadata);
        end

        % Success
        results(k).name = fullFilename;
        results(k).filepath = filepath;
        results(k).outputFile = outFile;
        results(k).data = data;
        results(k).error = '';

        nOk = nOk + 1;

        if options.Verbose
            if strcmp(options.Format, "com")
                fprintf("  [OK]  %s -> Origin workbook\n", fullFilename);
            else
                fprintf("  [OK]  %s -> %s\n", fullFilename, filename + ".csv");
            end
        end

    catch ME
        % Error
        results(k).name = fullFilename;
        results(k).filepath = filepath;
        results(k).outputFile = "";
        results(k).data = [];
        results(k).error = ME.message;

        nErr = nErr + 1;

        if options.Verbose
            fprintf("  [ERR] %s -- %s\n", fullFilename, ME.message);
        end
    end

    % Call progress callback if provided
    if ~isempty(options.ProgressFcn)
        try
            options.ProgressFcn(k, nFiles, fullFilename);
        catch
            % Silently ignore callback errors
        end
    end
end

% Close COM workbook if open
if strcmp(options.Format, "com") && exist('originApp', 'var') && ~isempty(originApp)
    try
        closeComWorkbook();
    catch
        % Silently ignore
    end
end

% Summary
if options.Verbose
    if nErr == 0
        fprintf("batchConvertXRD: done -- %d ok.\n", nOk);
    else
        fprintf("batchConvertXRD: done -- %d ok, %d failed.\n", nOk, nErr);
    end
end

end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Resolve file list
% ════════════════════════════════════════════════════════════════════════

function fileList = resolveFileList(filesInput, recursive)
    fileList = {};

    if isscalar(filesInput) && isfolder(filesInput)
        % Input is a folder — auto-discover XRD files
        folderPath = filesInput;

        if recursive
            % Recursive scan
            allFiles = dir(fullfile(folderPath, '**', '*'));
        else
            % Non-recursive scan
            allFiles = dir(folderPath);
        end

        for i = 1:numel(allFiles)
            f = allFiles(i);
            if f.isdir
                continue;
            end

            [~, ~, ext] = fileparts(f.name);
            ext = lower(ext);

            isXRD = false;

            % Check file extension
            if strcmp(ext, '.xrdml') || strcmp(ext, '.brml')
                isXRD = true;
            elseif strcmp(ext, '.raw')
                % For .raw files, check magic bytes to filter XRD files
                fullPath = fullfile(f.folder, f.name);
                if isXRDRawFile(fullPath)
                    isXRD = true;
                end
            end

            if isXRD
                fullPath = fullfile(f.folder, f.name);
                fileList{end+1} = fullPath; %#ok<AGROW>
            end
        end
    else
        % Input is explicit file list — use as-is
        if isstring(filesInput)
            fileList = cellstr(filesInput);
        else
            fileList = filesInput;
        end
    end

    % Sort for consistent order
    fileList = sort(fileList);
end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Magic-byte check for XRD .raw files
% ════════════════════════════════════════════════════════════════════════

function isXRD = isXRDRawFile(filepath)
    try
        fid = fopen(filepath, 'r');
        if fid < 0
            isXRD = false;
            return;
        end
        cleanup = onCleanup(@() fclose(fid));

        header = fread(fid, 7, '*char')';

        % Check for Rigaku magic ("FI") or Bruker magic ("RAW1.01")
        isXRD = startsWith(header, 'FI') || startsWith(header, 'RAW1.01');
    catch
        isXRD = false;
    end
end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Initialize COM workbook
% ════════════════════════════════════════════════════════════════════════

function [success, originApp] = initComWorkbook(bookName)
    try
        originApp = actxGetRunningObject('Origin.ApplicationSI');
        if isempty(originApp)
            originApp = actxserver('Origin.ApplicationSI');
        end

        % Create new workbook
        originApp.CreatePage(3, bookName, [], 2); % 3 = worksheet, blank template
        success = true;
    catch
        success = false;
        originApp = [];
    end
end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Close COM workbook (placeholder)
% ════════════════════════════════════════════════════════════════════════

function closeComWorkbook()
    % Workbook stays open in Origin
    % User closes it manually
end
