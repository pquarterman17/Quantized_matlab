function fig = quickPlot(files, options)
%QUICKPLOT  Import and plot one or more data files with smart type detection.
%
%   scripts.quickPlot('scan.xrdml')
%   scripts.quickPlot({'vsm1.dat', 'vsm2.dat'}, 'Normalize', true)
%   scripts.quickPlot({'a.dat','b.dat'}, 'Layout','subplots', 'LogY',true)
%   scripts.quickPlot('refl.refl', 'SaveAs', 'refl_plot.pdf')
%
%   Auto-imports each file via parser.importAuto, detects the data type from
%   parser metadata, and produces publication-ready figures using the
%   +plotting and +styles infrastructure.
%
%   INPUTS:
%       files — file path (char/string) or cell array of paths
%
%   OPTIONAL NAME-VALUE PAIRS:
%       LogY      — force log scale on Y axis (default: auto per type)
%       Normalize — peak-normalise all Y data to [0,1] (default: false)
%       SaveAs    — file path to save figure (.png/.pdf/.svg/.eps/.tif)
%       Title     — figure title string
%       XLabel    — override x-axis label (default: auto per type)
%       YLabel    — override y-axis label (default: auto per type)
%       Layout    — 'overlay' (default) or 'subplots'
%       Theme     — theme struct (default: styles.default())
%
%   OUTPUT:
%       fig — figure handle (returned only if requested)
%
%   EXAMPLES:
%       % XRD overlay of two scans
%       scripts.quickPlot({'scan1.xrdml', 'scan2.xrdml'}, 'LogY', true)
%
%       % Magnetometry comparison in subplots
%       scripts.quickPlot({'sample_a.dat', 'sample_b.dat'}, ...
%           'Layout', 'subplots', 'Normalize', true)
%
%       % SIMS depth profile with save
%       scripts.quickPlot('sims.csv', 'SaveAs', 'sims_plot.png')
%
%       % Reflectometry on log scale (auto-detected)
%       scripts.quickPlot('refl.refl')
%
%   See also parser.importAuto, plotting.formatAxes, plotting.saveFigure

    arguments
        files
        options.LogY      (1,1) logical = false
        options.Normalize (1,1) logical = false
        options.SaveAs    (1,1) string  = ""
        options.Title     (1,1) string  = ""
        options.XLabel    (1,1) string  = ""
        options.YLabel    (1,1) string  = ""
        options.Layout    (1,1) string  {mustBeMember(options.Layout, ...
                                         {'overlay','subplots'})} = 'overlay'
        options.Theme                   = []
    end

    % ════════════════════════════════════════════════════════════════
    %  Normalise input to cell array of file paths
    % ════════════════════════════════════════════════════════════════
    if ischar(files) || (isstring(files) && isscalar(files))
        files = {char(files)};
    elseif isstring(files)
        files = cellstr(files);
    elseif ~iscell(files)
        error('scripts:quickPlot:badInput', ...
            'files must be a file path (char/string) or cell array of paths.');
    end
    nFiles = numel(files);
    if nFiles == 0
        error('scripts:quickPlot:noFiles', 'No files specified.');
    end

    % ════════════════════════════════════════════════════════════════
    %  Import all files
    % ════════════════════════════════════════════════════════════════
    allData    = cell(1, nFiles);
    fileLabels = cell(1, nFiles);

    for k = 1:nFiles
        allData{k} = parser.importAuto(files{k});
        [~, fname, fext] = fileparts(files{k});
        fileLabels{k} = [fname, fext];
    end

    % ════════════════════════════════════════════════════════════════
    %  Detect data types and warn on image data
    % ════════════════════════════════════════════════════════════════
    dataTypes = cell(1, nFiles);
    keep = true(1, nFiles);
    for k = 1:nFiles
        dataTypes{k} = detectDataType(allData{k});
        if strcmp(dataTypes{k}, 'image')
            warning('scripts:quickPlot:skipImage', ...
                'Skipping image file: %s (use FermiViewer for images)', ...
                fileLabels{k});
            keep(k) = false;
        end
    end
    allData    = allData(keep);
    dataTypes  = dataTypes(keep);
    fileLabels = fileLabels(keep);
    nFiles     = numel(allData);
    if nFiles == 0
        error('scripts:quickPlot:noPlottable', ...
            'No plottable (non-image) files remain.');
    end

    % ════════════════════════════════════════════════════════════════
    %  Resolve theme
    % ════════════════════════════════════════════════════════════════
    th = options.Theme;
    if isempty(th)
        th = styles.default();
    end
    colors = plotting.lineColors(max(nFiles, 1), th);

    % ════════════════════════════════════════════════════════════════
    %  Create figure and plot
    % ════════════════════════════════════════════════════════════════
    fig = figure('Units', 'centimeters', ...
                 'Position', [2 2 th.figWidth th.figHeight]);

    if strcmp(options.Layout, 'overlay')
        ax = axes(fig);
        hold(ax, 'on');

        defaults = getPlotDefaults(dataTypes{1}, allData{1});

        for k = 1:nFiles
            plotOne(ax, allData{k}, dataTypes{k}, colors(k,:), th, ...
                    options.Normalize, fileLabels{k});
        end

        % Y scale: explicit LogY > type default
        yScale = defaults.yScale;
        if options.LogY
            yScale = 'log';
        end

        % Labels: user override > auto-detected
        xLbl = defaults.xLabel;
        yLbl = defaults.yLabel;
        if options.XLabel ~= "", xLbl = char(options.XLabel); end
        if options.YLabel ~= "", yLbl = char(options.YLabel); end
        if options.Normalize,    yLbl = 'Normalised'; end

        ttl = '';
        if options.Title ~= "", ttl = char(options.Title); end

        plotting.formatAxes(ax, th, ...
            'XLabel', xLbl, 'YLabel', yLbl, ...
            'Title', ttl, 'YScale', yScale);

        if nFiles > 1 || strcmp(dataTypes{1}, 'sims')
            legend(ax, 'Interpreter', 'none', ...
                   'FontSize', th.legendFontSize, 'Location', 'best');
        end

    else  % 'subplots'
        % Widen figure for vertical stack
        fig.Position(4) = th.figHeight * max(nFiles * 0.6, 1);

        for k = 1:nFiles
            ax = subplot(nFiles, 1, k, 'Parent', fig);
            hold(ax, 'on');

            defaults = getPlotDefaults(dataTypes{k}, allData{k});
            plotOne(ax, allData{k}, dataTypes{k}, colors(k,:), th, ...
                    options.Normalize, fileLabels{k});

            yScale = defaults.yScale;
            if options.LogY, yScale = 'log'; end

            xLbl = defaults.xLabel;
            yLbl = defaults.yLabel;
            if options.XLabel ~= "", xLbl = char(options.XLabel); end
            if options.YLabel ~= "", yLbl = char(options.YLabel); end
            if options.Normalize,    yLbl = 'Normalised'; end

            ttl = fileLabels{k};
            if options.Title ~= "" && k == 1
                ttl = char(options.Title);
            end

            plotting.formatAxes(ax, th, ...
                'XLabel', xLbl, 'YLabel', yLbl, ...
                'Title', ttl, 'YScale', yScale);

            if strcmp(dataTypes{k}, 'sims')
                legend(ax, 'Interpreter', 'none', ...
                       'FontSize', th.legendFontSize, 'Location', 'best');
            end
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  Save if requested
    % ════════════════════════════════════════════════════════════════
    if options.SaveAs ~= ""
        plotting.saveFigure(fig, options.SaveAs, 'Theme', th);
    end

    % Only return figure handle if requested
    if nargout == 0
        clear fig;
    end
end


% ════════════════════════════════════════════════════════════════════
%  LOCAL FUNCTIONS
% ════════════════════════════════════════════════════════════════════

function dtype = detectDataType(data)
%DETECTDATATYPE  Classify a data struct by its source parser.
    meta = data.metadata;
    pName = '';
    if isfield(meta, 'parserName')
        pName = meta.parserName;
    end

    % XRD parsers
    if any(strcmpi(pName, {'importXRDML','importBruker','importRigaku_raw'}))
        dtype = 'xrd'; return;
    end

    % Magnetometry parsers
    if any(strcmpi(pName, {'importQDVSM','importPPMS','importMPMS','importLakeShore'}))
        dtype = 'magnetometry'; return;
    end

    % Reflectometry parsers
    if any(strcmpi(pName, {'importNCNRRefl','importNCNRPNR','importNCNRDat'}))
        dtype = 'reflectometry'; return;
    end

    % SIMS
    if strcmpi(pName, 'importSIMS')
        dtype = 'sims'; return;
    end

    % EM image parsers
    if any(strcmpi(pName, {'importTIFF','importDM3','importRawImage','importMRC'}))
        dtype = 'image'; return;
    end

    % Fallback: heuristic from xColumnName
    xCol = '';
    if isfield(meta, 'xColumnName')
        xCol = lower(meta.xColumnName);
    end
    if contains(xCol, '2theta') || contains(xCol, '2-theta')
        dtype = 'xrd';
    elseif contains(xCol, 'depth')
        dtype = 'sims';
    elseif contains(xCol, 'field') || contains(xCol, 'oe')
        dtype = 'magnetometry';
    elseif startsWith(xCol, 'q') && ~contains(xCol, 'quantity')
        dtype = 'reflectometry';
    else
        dtype = 'generic';
    end
end


function d = getPlotDefaults(dtype, data)
%GETPLOTDEFAULTS  Return default axis labels and scale for a data type.
    d.xLabel = '';
    d.yLabel = '';
    d.yScale = 'linear';

    switch dtype
        case 'xrd'
            d.xLabel = '2\theta (\circ)';
            d.yLabel = 'Intensity (counts)';

        case 'magnetometry'
            d.xLabel = 'Field (Oe)';
            d.yLabel = 'Moment (emu)';
            if isfield(data.metadata, 'xColumnName')
                xCol = lower(data.metadata.xColumnName);
                if contains(xCol, 'temp')
                    d.xLabel = 'Temperature (K)';
                end
            end

        case 'reflectometry'
            d.xLabel = 'Q (\AA^{-1})';
            d.yLabel = 'Reflectivity';
            d.yScale = 'log';

        case 'sims'
            d.xLabel = 'Depth (nm)';
            d.yLabel = 'Concentration';

        otherwise
            if isfield(data.metadata, 'xColumnName') && ...
                    ~isempty(data.metadata.xColumnName)
                d.xLabel = data.metadata.xColumnName;
            end
    end
end


function plotOne(ax, data, dtype, color, th, doNormalize, label)
%PLOTONE  Draw one dataset onto an axes.
    x = data.time;
    y = data.values;

    if doNormalize
        y = utilities.normalize(y, 'Method', 'peak');
    end

    switch dtype
        case 'sims'
            % Each element gets its own colour
            nElem = size(y, 2);
            elemColors = plotting.lineColors(nElem, th);
            for c = 1:nElem
                plot(ax, x, y(:,c), ...
                    'Color', elemColors(c,:), ...
                    'LineWidth', th.lineWidth, ...
                    'DisplayName', data.labels{c});
            end

        case 'reflectometry'
            % Plot R columns, skip error columns (3+)
            nR = min(size(y, 2), 2);
            for c = 1:nR
                dName = label;
                if nR > 1
                    dName = sprintf('%s [%s]', label, data.labels{c});
                end
                plot(ax, x, y(:,c), ...
                    'Color', color, ...
                    'LineWidth', th.lineWidth, ...
                    'DisplayName', dName);
            end

        otherwise  % xrd, magnetometry, generic
            for c = 1:size(y, 2)
                dName = label;
                if size(y, 2) > 1
                    dName = sprintf('%s [%s]', label, data.labels{c});
                end
                plot(ax, x, y(:,c), ...
                    'Color', color, ...
                    'LineWidth', th.lineWidth, ...
                    'DisplayName', dName);
            end
    end
end
