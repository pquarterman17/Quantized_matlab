function setupToolbox(options)
%SETUPTOOLBOX Add the toolbox root to the MATLAB path.
%
%   setupToolbox()              - Adds toolbox root to path (all packages accessible)
%   setupToolbox('save', true)  - Also saves the path for future sessions
%   setupToolbox('verbose', true) - Prints each directory added
%   setupToolbox('remove', true)  - Removes toolbox from path instead
%
%   Packages available after running setupToolbox:
%       parser.*    - Data importers (importAuto, importQDVSM, importCSV, ...)
%       plotting.*  - Plot helpers (formatAxes, lineColors, saveFigure)
%       styles.*    - Visual themes (default)
%       utilities.* - Data helpers (normalize, smoothData, convertUnits)
%       scripts.*   - Batch scripts (batchImport)
%
%   MATLAB package directories (+parser, +plotting, ...) are resolved
%   automatically once the toolbox root is on the path — there is no need
%   to add the package subdirectories themselves.
%
%   Example:
%       setupToolbox()
%       setupToolbox('save', true, 'verbose', true)

    arguments
        options.save    (1,1) logical = false
        options.verbose (1,1) logical = true
        options.remove  (1,1) logical = false
    end

    % Resolve the root directory of this toolbox
    toolboxRoot = fileparts(mfilename('fullpath'));

    % Only the root directory needs to be on the path.
    % MATLAB resolves +package directories automatically from the parent.
    dirsToAdd = {toolboxRoot};

    % Add or remove from path
    if options.remove
        for i = 1:numel(dirsToAdd)
            rmpath(dirsToAdd{i});
            if options.verbose
                fprintf('  Removed: %s\n', dirsToAdd{i});
            end
        end
        fprintf('Toolbox removed from path (%d directories).\n', numel(dirsToAdd));
    else
        for i = 1:numel(dirsToAdd)
            addpath(dirsToAdd{i});
            if options.verbose
                fprintf('  Added: %s\n', dirsToAdd{i});
            end
        end
        fprintf('Toolbox added to path (%d directories).\n', numel(dirsToAdd));
    end

    % Optionally save the path permanently
    if options.save
        status = savepath;
        if status == 0
            fprintf('Path saved successfully.\n');
        else
            warning('setupToolbox:saveFailed', ...
                'Could not save path. Try running MATLAB as administrator.');
        end
    end
end