function onDropFiles(fig, e, callbacks)
%ONDROPFILES  Handle files dragged from the OS file explorer onto the figure.
%
% Syntax
%   bosonPlotter.onDropFiles(fig, e, callbacks)
%
% Behaviour
%   Normalises `e.Data` (string scalar / string array / char vector /
%   cell array) into a cell array of path strings, filters to existing
%   files with supported extensions, and hands the list to
%   `callbacks.loadFilePaths`.  Shows a user-friendly `uialert` when
%   none of the dropped items are loadable and prints stack traces to
%   stderr on unexpected errors.
%
% Requires MATLAB R2023a+ (DropFcn / drop-target support).
%
% Inputs
%   fig       - Main figure handle (uialert parent)
%   e         - DropFcn event object (reads `.Data`)
%   callbacks - Struct of function handles:
%                 .loadFilePaths(fpaths)  - load one or more paths
%                                           into the GUI
%
% Supported extensions
%   .dat .csv .tsv .txt .xlsx .xls .xlsm .xlsb .ods
%   .raw .brml .xrdml .refl .pnr
%   .datA-D / .data-d (NCNR)
%   .jpg .jpeg .png .bmp .gif .tif .tiff  (bitmap images)
%   .bcf .dm3 .dm4 .mrc .mrcs .ser .spm   (EM / microscopy)
%   .000 .001                             (sequence fragments)

    try
        d = e.Data;
        if isstring(d)
            % String scalar: may be newline-separated list; string array: one path per element.
            if isscalar(d)
                fpaths = cellstr(strsplit(strtrim(d), newline));
            else
                fpaths = cellstr(d);   % multi-element string array → cell of chars
            end
        elseif ischar(d)
            % Char vector — may be newline-separated (legacy format)
            fpaths = cellstr(strsplit(strtrim(d), newline));
        elseif iscell(d)
            fpaths = d;
        else
            return;   % unrecognised format; nothing to do
        end
        fpaths = fpaths(~cellfun(@isempty, fpaths));
        if isempty(fpaths), return; end

        supported = {'.dat','.csv','.tsv','.txt', ...
                     '.xlsx','.xls','.xlsm','.xlsb','.ods', ...
                     '.raw','.brml','.xrdml', ...
                     '.refl','.pnr', ...
                     '.datA','.datB','.datC','.datD', ...
                     '.data','.datb','.datc','.datd', ...
                     '.jpg','.jpeg','.png','.bmp','.gif', ...
                     '.tif','.tiff','.bcf','.dm3','.dm4', ...
                     '.mrc','.mrcs','.ser','.spm', ...
                     '.000','.001'};
        valid = {};
        for k = 1:numel(fpaths)
            p = strtrim(char(fpaths{k}));
            [~, ~, ext] = fileparts(p);
            if isfile(p) && any(strcmpi(ext, supported))
                valid{end+1} = p; %#ok<AGROW>
            end
        end

        if isempty(valid)
            bosonPlotter.quietAlert(fig, ...
                'None of the dropped items are supported data files.', ...
                'Unsupported file type');
            return;
        end
        callbacks.loadFilePaths(valid);

    catch ME
        fprintf(2, '[BosonPlotter] DropFcn error: %s\n', ME.message);
        for si = 1:numel(ME.stack)
            fprintf(2, '  at %s (line %d)\n', ME.stack(si).name, ME.stack(si).line);
        end
    end
end
