function setupToolbox(options)
%SETUPTOOLBOX Add all toolbox subdirectories to the MATLAB path.
%
%   setupToolbox()              - Adds parsers, scripts, and utils to path
%   setupToolbox('save', true)  - Also saves the path for future sessions
%   setupToolbox('verbose', true) - Prints each directory added
%   setupToolbox('remove', true)  - Removes toolbox from path instead
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

    % Define subdirectories to add (edit this list to include your folders)
    subdirs = {
        'parsers'
        'plotting'
        'styles'
        'scripts'
        'utils'
    };

    % Gather all directories (including nested subdirectories)
    dirsToAdd = {toolboxRoot};
    for i = 1:numel(subdirs)
        folder = fullfile(toolboxRoot, subdirs{i});
        if isfolder(folder)
            dirsToAdd{end+1} = folder; %#ok<AGROW>
            % Recursively find all subdirectories
            subfolders = genpath(folder);
            if ~isempty(subfolders)
                parts = strsplit(subfolders, pathsep);
                parts = parts(~cellfun('isempty', parts));
                dirsToAdd = [dirsToAdd, parts]; %#ok<AGROW>
            end
        else
            if options.verbose
                warning('setupToolbox:missingDir', ...
                    'Directory not found: %s (skipping)', folder);
            end
        end
    end

    % Remove duplicates
    dirsToAdd = unique(dirsToAdd, 'stable');

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