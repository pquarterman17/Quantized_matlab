function results = batchImport(directory, options)
%BATCHIMPORT  Import all supported data files from a directory tree.
%
%   results = scripts.batchImport('data/')
%   results = scripts.batchImport('data/', 'Recursive', true)
%   results = scripts.batchImport('data/', 'Extensions', {'.dat','.raw'})
%
%   Walks directory (and optionally all subdirectories), calls
%   parser.importAuto on every supported file, and returns a struct array
%   with the filename, path, imported data struct and any import errors.
%
%   Successfully imported files have results(i).data populated and
%   results(i).error empty.  Failed files have data = [] and error set to
%   the error message string so the rest of the batch continues.
%
%   INPUTS:
%       directory — path to the root folder to search (string or char)
%
%   OPTIONAL NAME-VALUE PAIRS:
%       Recursive  — true (default: false) to recurse into subdirectories
%       Extensions — cell array of file extensions to process
%                    (default: {'.dat','.csv','.tsv','.txt','.xlsx','.raw'})
%       Verbose    — print one line per file (default: true)
%
%   OUTPUT:
%       results — struct array with fields:
%                   .name      — filename (without path)
%                   .filepath  — full path
%                   .data      — output of parser.importAuto (or [])
%                   .error     — error message string ('' if successful)
%
%   EXAMPLE:
%       res = scripts.batchImport('measurements/', 'Recursive', true);
%
%       % Show only failed files
%       failed = res(~cellfun(@isempty, {res.error}));
%       fprintf('Failed: %d / %d\n', numel(failed), numel(res));
%
%       % Collect all successfully imported data structs
%       good = res(cellfun(@isempty, {res.error}));
%       allData = {good.data};
%
%   See also parser.importAuto, parser.importCSV, parser.importQDVSM

    arguments
        directory              (1,1) string {mustBeFolder}
        options.Recursive      (1,1) logical = false
        options.Extensions           cell    = {'.dat','.csv','.tsv','.txt', ...
                                                '.xlsx','.xls','.raw'}
        options.Verbose        (1,1) logical = true
    end

    % ── Find files ────────────────────────────────────────────────────────
    if options.Recursive
        allFiles = findFilesRecursive(char(directory), options.Extensions);
    else
        allFiles = findFilesFlat(char(directory), options.Extensions);
    end

    nFiles = numel(allFiles);

    if nFiles == 0
        warning('scripts:batchImport:noFiles', ...
            'No supported files found in: %s', directory);
        results = struct('name',{},'filepath',{},'data',{},'error',{});
        return;
    end

    if options.Verbose
        fprintf('batchImport: found %d file(s) in %s\n', nFiles, directory);
    end

    % ── Import each file ──────────────────────────────────────────────────
    results(nFiles) = struct('name','','filepath','','data',[],'error','');

    for k = 1:nFiles
        fp = allFiles{k};
        [~, fname, fext] = fileparts(fp);
        results(k).name     = [fname, fext];
        results(k).filepath = fp;

        try
            results(k).data  = parser.importAuto(fp);
            results(k).error = '';
            if options.Verbose
                fprintf('  [OK]  %s\n', [fname, fext]);
            end
        catch ME
            results(k).data  = [];
            results(k).error = ME.message;
            if options.Verbose
                fprintf('  [ERR] %s — %s\n', [fname, fext], ME.message);
            end
        end
    end

    nOk  = sum(cellfun(@isempty, {results.error}));
    nErr = nFiles - nOk;
    if options.Verbose
        fprintf('batchImport: done — %d ok, %d failed.\n', nOk, nErr);
    end
end


% ── Local helpers ──────────────────────────────────────────────────────────

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
%FINDFILESRECURSIVE  Return full paths of matching files in dir_ and all subdirs.
    files   = findFilesFlat(dir_, exts);
    listing = dir(dir_);
    for k = 1:numel(listing)
        if ~listing(k).isdir || listing(k).name(1) == '.', continue; end
        sub = fullfile(dir_, listing(k).name);
        files = [files, findFilesRecursive(sub, exts)]; %#ok<AGROW>
    end
end
