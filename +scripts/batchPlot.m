function results = batchPlot(filePaths, options)
%BATCHPLOT  Apply a plot template to multiple datasets and save publication figures.
%
%   Syntax:
%       results = scripts.batchPlot(filePaths)
%       results = scripts.batchPlot(filePaths, Template="aps", Format="pdf")
%       results = scripts.batchPlot('/path/to/dir', OutputDir='/out', Overwrite=true)
%
%   Inputs:
%       filePaths — {1xN} cell array of file paths, or a directory path string.
%                   When a directory string is given, all supported files in that
%                   directory are collected automatically.
%
%   Name-Value Options:
%       Template  — user template name (from plotting.plotTemplate) OR a journal
%                   preset string ('aps','nature','thesis', …). Default "" applies
%                   no template (uses styles.default figure sizing only).
%       OutputDir — directory for saved figures. Default "": figures are saved
%                   next to each input file.
%       Format    — "png"|"pdf"|"svg"|"eps"|"tiff"  (default "png")
%       DPI       — raster resolution in dpi (default 300)
%       PlotType  — "auto"|"line"|"scatter"  (default "auto")
%       XAxis     — column name to use as x-axis, or "auto"  (default "auto")
%       YAxis     — column name, "all", or "auto"  (default "auto")
%       FigSize   — [width height] in inches. Default [] uses template or [6 4].
%       Prefix    — prepend string for output filenames  (default "")
%       Suffix    — append string for output filenames   (default "")
%       Overwrite — overwrite existing output files  (default false)
%       Verbose   — print one line per file  (default true)
%
%   Outputs:
%       results — struct array with fields:
%                   .inputFile  — full input path
%                   .outputFile — full output path ('' if skipped/failed)
%                   .success    — logical
%                   .error      — error message string ('' if successful)
%
%   Examples:
%       % Batch-plot all files in a folder as APS-style PDFs
%       results = scripts.batchPlot('measurements/', Template="aps", Format="pdf");
%
%       % Plot specific files, save PNGs with a prefix, skip existing
%       results = scripts.batchPlot({'a.dat','b.dat'}, Prefix="fig_", Overwrite=false);
%
%       % Check for failures
%       failed = results(~[results.success]);
%
%   See also scripts.batchImport, scripts.quickPlot, parser.importAuto,
%            plotting.saveFigure, styles.template

arguments
    filePaths
    options.Template  (1,1) string  = ""
    options.OutputDir (1,1) string  = ""
    options.Format    (1,1) string  {mustBeMember(options.Format, ...
                                     ["png","pdf","svg","eps","tiff"])} = "png"
    options.DPI       (1,1) double  {mustBePositive} = 300
    options.PlotType  (1,1) string  {mustBeMember(options.PlotType, ...
                                     ["auto","line","scatter"])} = "auto"
    options.XAxis     (1,1) string  = "auto"
    options.YAxis     (1,1) string  = "auto"
    options.FigSize   (1,:) double  = []
    options.Prefix    (1,1) string  = ""
    options.Suffix    (1,1) string  = ""
    options.Overwrite (1,1) logical = false
    options.Verbose   (1,1) logical = true
end

% ════════════════════════════════════════════════════════════════════════
%  Normalise input to cell array of file paths
% ════════════════════════════════════════════════════════════════════════
if ischar(filePaths) || (isstring(filePaths) && isscalar(filePaths))
    % Directory path — collect all supported files
    dirPath = char(filePaths);
    if ~isfolder(dirPath)
        error('scripts:batchPlot:badInput', ...
            'filePaths is not a cell array and not an existing directory: %s', dirPath);
    end
    filePaths = collectFiles(dirPath);
elseif isstring(filePaths)
    filePaths = cellstr(filePaths);
elseif ~iscell(filePaths)
    error('scripts:batchPlot:badInput', ...
        'filePaths must be a file-path string, directory string, or cell array of paths.');
end

nFiles = numel(filePaths);
if nFiles == 0
    warning('scripts:batchPlot:noFiles', 'No files to process.');
    results = struct('inputFile',{},'outputFile',{},'success',{},'error',{});
    return;
end

% ════════════════════════════════════════════════════════════════════════
%  Resolve template / theme
% ════════════════════════════════════════════════════════════════════════
[tmpl, isJournalPreset] = resolveTemplate(options.Template);

% ════════════════════════════════════════════════════════════════════════
%  Resolve figure size in cm (1 inch = 2.54 cm)
% ════════════════════════════════════════════════════════════════════════
if ~isempty(options.FigSize) && numel(options.FigSize) == 2
    figW_cm = options.FigSize(1) * 2.54;
    figH_cm = options.FigSize(2) * 2.54;
elseif isJournalPreset && isfield(tmpl, 'figWidth_cm')
    figW_cm = tmpl.figWidth_cm;
    figH_cm = tmpl.figHeight_cm;
else
    figW_cm = 6 * 2.54;   % 6 inches default
    figH_cm = 4 * 2.54;
end

% ════════════════════════════════════════════════════════════════════════
%  Preallocate results
% ════════════════════════════════════════════════════════════════════════
results(nFiles) = struct('inputFile','','outputFile','','success',false,'error','');

% ════════════════════════════════════════════════════════════════════════
%  Process each file
% ════════════════════════════════════════════════════════════════════════
for k = 1:nFiles
    fp = char(filePaths{k});
    results(k).inputFile  = fp;
    results(k).outputFile = '';
    results(k).success    = false;
    results(k).error      = '';

    [fdir, fname, ~] = fileparts(fp);

    % Resolve output directory
    if options.OutputDir == ""
        outDir = fdir;
    else
        outDir = char(options.OutputDir);
        if ~isfolder(outDir)
            mkdir(outDir);
        end
    end

    outName = options.Prefix + string(fname) + options.Suffix + "." + options.Format;
    outPath = fullfile(outDir, char(outName));
    results(k).outputFile = outPath;

    % Skip existing unless Overwrite
    if ~options.Overwrite && isfile(outPath)
        if options.Verbose
            fprintf('  [SKIP] %s (exists)\n', [fname, '.', char(options.Format)]);
        end
        results(k).success = true;
        results(k).error   = '';
        continue;
    end

    try
        % Import
        data = parser.importAuto(fp);

        % Build figure
        fig = figure('Visible', 'off', ...
                     'Units', 'centimeters', ...
                     'Position', [2 2 figW_cm figH_cm]);
        ax  = axes(fig);

        % Determine which columns to plot
        [xData, yData, xLabel, yLabel] = resolveAxes(data, options.XAxis, options.YAxis);

        % Plot
        plotData(ax, xData, yData, data, options.PlotType);

        % Axis labels
        if ~isempty(xLabel), xlabel(ax, xLabel, 'Interpreter', 'none'); end
        if ~isempty(yLabel), ylabel(ax, yLabel, 'Interpreter', 'none'); end
        title(ax, fname, 'Interpreter', 'none');

        % Apply template styling
        if isJournalPreset
            plotting.applyTemplate(fig, ax, tmpl);
        elseif options.Template ~= ""
            % User template from plotTemplate store
            try
                plotting.plotTemplate('apply', Name=options.Template, Axes=ax);
            catch ME2
                warning('scripts:batchPlot:templateNotFound', ...
                    'Template "%s" not found: %s', options.Template, ME2.message);
            end
        end

        % Save
        plotting.saveFigure(fig, outPath, 'DPI', options.DPI, ...
                            'Width', figW_cm, 'Height', figH_cm);
        close(fig);

        results(k).success = true;
        if options.Verbose
            fprintf('  [OK]   %s → %s\n', [fname, fileparts(fp)], outPath);
        end

    catch ME
        results(k).success = false;
        results(k).error   = ME.message;
        % Close figure if it was opened
        if exist('fig','var') && ishandle(fig)
            close(fig);
        end
        if options.Verbose
            fprintf('  [ERR]  %s — %s\n', fname, ME.message);
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Summary
% ════════════════════════════════════════════════════════════════════════
if options.Verbose
    nOk  = sum([results.success]);
    nErr = nFiles - nOk;
    fprintf('batchPlot: done — %d ok, %d failed.\n', nOk, nErr);
end

end % batchPlot


% ════════════════════════════════════════════════════════════════════════
%  Local: collect supported files from a directory
% ════════════════════════════════════════════════════════════════════════
function files = collectFiles(dirPath)
%COLLECTFILES  Return cell array of full paths for supported extensions.
    SUPPORTED_EXTS = {'.dat','.csv','.tsv','.txt','.xlsx','.xls','.raw', ...
                      '.xrdml','.brml','.refl','.pnr', ...
                      '.datA','.datB','.datC','.datD'};
    files   = {};
    listing = dir(dirPath);
    for k = 1:numel(listing)
        if listing(k).isdir, continue; end
        [~, ~, ext] = fileparts(listing(k).name);
        if any(strcmpi(ext, SUPPORTED_EXTS))
            files{end+1} = fullfile(dirPath, listing(k).name); %#ok<AGROW>
        end
    end
end


% ════════════════════════════════════════════════════════════════════════
%  Local: resolve template string to struct
% ════════════════════════════════════════════════════════════════════════
function [tmpl, isJournalPreset] = resolveTemplate(templateStr)
%RESOLVETEMPLATE  Return a template struct and flag if it is a journal preset.
    JOURNAL_PRESETS = {'aps','aps_double','nature','nature_double', ...
                       'thesis','presentation','poster','screen'};

    if templateStr == ""
        tmpl           = styles.default();
        isJournalPreset = false;
        return;
    end

    if any(strcmpi(templateStr, JOURNAL_PRESETS))
        tmpl            = styles.template(lower(char(templateStr)));
        isJournalPreset = true;
    else
        % Treat as a user plotTemplate name — return default theme here;
        % the actual apply happens later when the axes exist.
        tmpl            = styles.default();
        isJournalPreset = false;
    end
end


% ════════════════════════════════════════════════════════════════════════
%  Local: resolve x/y data and axis labels from options
% ════════════════════════════════════════════════════════════════════════
function [xData, yData, xLabel, yLabel] = resolveAxes(data, xAxisOpt, yAxisOpt)
%RESOLVEAXES  Extract x/y arrays and labels from a data struct.

    % ── X axis ───────────────────────────────────────────────────────────
    if xAxisOpt == "auto" || xAxisOpt == ""
        xData  = data.time;
        xLabel = '';
        if isfield(data.metadata, 'xColumnName') && ~isempty(data.metadata.xColumnName)
            xLabel = data.metadata.xColumnName;
        end
    else
        % User specified a column name; look for it in labels
        idx = find(strcmpi(data.labels, char(xAxisOpt)), 1);
        if ~isempty(idx)
            xData  = data.values(:, idx);
            xLabel = data.labels{idx};
        else
            warning('scripts:batchPlot:xColumnNotFound', ...
                'XAxis column "%s" not found; using .time.', xAxisOpt);
            xData  = data.time;
            xLabel = '';
        end
    end

    % ── Y axis ───────────────────────────────────────────────────────────
    if yAxisOpt == "auto" || yAxisOpt == ""
        yData  = data.values;
        yLabel = '';
    elseif yAxisOpt == "all"
        yData  = data.values;
        yLabel = '';
    else
        idx = find(strcmpi(data.labels, char(yAxisOpt)), 1);
        if ~isempty(idx)
            yData  = data.values(:, idx);
            yLabel = data.labels{idx};
        else
            warning('scripts:batchPlot:yColumnNotFound', ...
                'YAxis column "%s" not found; plotting all columns.', yAxisOpt);
            yData  = data.values;
            yLabel = '';
        end
    end
end


% ════════════════════════════════════════════════════════════════════════
%  Local: draw data onto axes
% ════════════════════════════════════════════════════════════════════════
function plotData(ax, xData, yData, data, plotType)
%PLOTDATA  Plot y columns against x with the requested plot type.
    hold(ax, 'on');
    nCols = size(yData, 2);
    for c = 1:nCols
        lbl = '';
        if nCols > 1 && c <= numel(data.labels)
            lbl = data.labels{c};
        end

        switch plotType
            case 'scatter'
                scatter(ax, xData, yData(:,c), 10, 'filled', ...
                        'DisplayName', lbl);
            otherwise  % 'auto' and 'line'
                plot(ax, xData, yData(:,c), ...
                     'DisplayName', lbl);
        end
    end
    hold(ax, 'off');
    if nCols > 1
        legend(ax, 'Interpreter', 'none', 'Location', 'best');
    end
end
