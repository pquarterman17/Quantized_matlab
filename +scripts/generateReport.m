function reportPath = generateReport(datasets, options)
%GENERATEREPORT  Generate a formatted analysis report from loaded datasets.
%
%   Syntax:
%       reportPath = scripts.generateReport(datasets)
%       reportPath = scripts.generateReport(datasets, OutputPath='report.html', Title='My Data')
%
%   Inputs:
%       datasets — {1xN} cell array of data structs from parser.importAuto.
%                  May be empty to produce a header-only report.
%
%   Name-Value Options:
%       OutputPath      — output file path  (default "report.html")
%       Format          — "html" | "txt"  (default "html")
%       Title           — report title  (default "Analysis Report")
%       Author          — author name  (default "")
%       Date            — date string  (default: today's date)
%       IncludePlots    — embed plots in the report  (default true)
%       IncludeStats    — include per-column statistics  (default true)
%       IncludeMetadata — include dataset metadata table  (default true)
%       PlotFormat      — "png" | "svg"  (default "png")
%       PlotDPI         — raster resolution for plots  (default 150)
%       CustomSections  — {1xM} cell of structs with .title and .content
%       TempDir         — temp directory for intermediate plot files
%                         (default: tempdir)
%
%   Outputs:
%       reportPath — full path of the written report file
%
%   Examples:
%       data1 = parser.importAuto('scan1.xrdml');
%       data2 = parser.importAuto('vsm.dat');
%       reportPath = scripts.generateReport({data1, data2}, ...
%           Title='Sample Batch', Author='J. Smith');
%
%       % Text-only report (no embedded images)
%       scripts.generateReport({data1}, Format='txt', IncludePlots=false);
%
%   See also parser.importAuto, scripts.batchPlot

arguments
    datasets    cell
    options.OutputPath       (1,1) string  = "report.html"
    options.Format           (1,1) string  {mustBeMember(options.Format, ...
                                             ["html","txt"])} = "html"
    options.Title            (1,1) string  = "Analysis Report"
    options.Author           (1,1) string  = ""
    options.Date             (1,1) string  = ""
    options.IncludePlots     (1,1) logical = true
    options.IncludeStats     (1,1) logical = true
    options.IncludeMetadata  (1,1) logical = true
    options.PlotFormat       (1,1) string  {mustBeMember(options.PlotFormat, ...
                                             ["png","svg"])} = "png"
    options.PlotDPI          (1,1) double  {mustBePositive} = 150
    options.CustomSections   cell   = {}
    options.TempDir          (1,1) string  = ""
    options.Verbose          (1,1) logical = true
end

% ════════════════════════════════════════════════════════════════════════
%  Setup
% ════════════════════════════════════════════════════════════════════════
if options.Date == ""
    dateStr = char(datetime('today', 'Format', 'yyyy-MM-dd'));
else
    dateStr = char(options.Date);
end

if options.TempDir == ""
    tmpDir = fullfile(tempdir, ['report_', char(datetime('now','Format','yyyyMMddHHmmss'))]);
else
    tmpDir = char(options.TempDir);
end
if options.IncludePlots
    if ~isfolder(tmpDir)
        mkdir(tmpDir);
    end
    cleanupTmp = onCleanup(@() safeRmdir(tmpDir));
end

nSets = numel(datasets);
outPath = char(options.OutputPath);

% Ensure output directory exists
outDir = fileparts(outPath);
if ~isempty(outDir) && ~isfolder(outDir)
    mkdir(outDir);
end

% ════════════════════════════════════════════════════════════════════════
%  Dispatch to format-specific builder
% ════════════════════════════════════════════════════════════════════════
if options.Format == "html"
    writeHtmlReport(outPath, datasets, nSets, options, dateStr, tmpDir);
else
    writeTxtReport(outPath, datasets, nSets, options, dateStr);
end

reportPath = outPath;
if options.Verbose
    fprintf('generateReport: saved → %s\n', outPath);
end

end % generateReport


% ════════════════════════════════════════════════════════════════════════
%  HTML report builder
% ════════════════════════════════════════════════════════════════════════
function writeHtmlReport(outPath, datasets, nSets, options, dateStr, tmpDir)

lines = {};
A = @(s) [lines, {s}];  % local appender — not used; we build directly

% ── HTML header and CSS ───────────────────────────────────────────────
css = htmlCss();
lines{end+1} = '<!DOCTYPE html>';
lines{end+1} = '<html lang="en"><head>';
lines{end+1} = '<meta charset="UTF-8">';
lines{end+1} = sprintf('<title>%s</title>', htmlEscape(char(options.Title)));
lines{end+1} = sprintf('<style>%s</style>', css);
lines{end+1} = '</head><body>';

% ── Report header ─────────────────────────────────────────────────────
lines{end+1} = '<div class="report-header">';
lines{end+1} = sprintf('<h1>%s</h1>', htmlEscape(char(options.Title)));
lines{end+1} = '<div class="meta-line">';
if char(options.Author) ~= ""
    lines{end+1} = sprintf('<span><strong>Author:</strong> %s</span>', ...
        htmlEscape(char(options.Author)));
end
lines{end+1} = sprintf('<span><strong>Date:</strong> %s</span>', dateStr);
lines{end+1} = sprintf('<span><strong>Generated:</strong> %s</span>', ...
    char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
lines{end+1} = '</div></div>';

% ── Summary section ───────────────────────────────────────────────────
lines{end+1} = '<section class="summary">';
lines{end+1} = '<h2>Summary</h2>';
lines{end+1} = sprintf('<p>Datasets: <strong>%d</strong></p>', nSets);

if nSets > 0
    lines{end+1} = '<table class="summary-table"><thead>';
    lines{end+1} = '<tr><th>#</th><th>Source File</th><th>Parser</th><th>Points</th><th>Channels</th></tr>';
    lines{end+1} = '</thead><tbody>';
    for k = 1:nSets
        ds = datasets{k};
        srcFile = metaField(ds, 'sourceFile', '');
        if isempty(srcFile)
            srcFile = metaField(ds, 'filename', '(unknown)');
        end
        parserName = metaField(ds, 'parserName', '(unknown)');
        nPts  = size(ds.values, 1);
        nChan = size(ds.values, 2);
        [~, fname, fext] = fileparts(char(srcFile));
        displayName = [fname, fext];
        if isempty(displayName), displayName = char(srcFile); end
        lines{end+1} = sprintf( ...
            '<tr><td>%d</td><td>%s</td><td>%s</td><td>%d</td><td>%d</td></tr>', ...
            k, htmlEscape(displayName), htmlEscape(char(parserName)), nPts, nChan);
    end
    lines{end+1} = '</tbody></table>';
end
lines{end+1} = '</section>';

% ── Per-dataset sections ──────────────────────────────────────────────
for k = 1:nSets
    ds = datasets{k};
    srcFile = metaField(ds, 'sourceFile', '');
    if isempty(srcFile)
        srcFile = metaField(ds, 'filename', sprintf('Dataset %d', k));
    end
    [~, fname, fext] = fileparts(char(srcFile));
    displayName = [fname, fext];
    if isempty(strtrim(displayName)), displayName = sprintf('Dataset %d', k); end

    lines{end+1} = sprintf('<section class="dataset" id="ds-%d">', k);
    lines{end+1} = sprintf('<h2>%d. %s</h2>', k, htmlEscape(displayName));

    % ── Metadata table ────────────────────────────────────────────────
    if options.IncludeMetadata
        lines{end+1} = '<h3>Metadata</h3>';
        lines{end+1} = '<table class="meta-table"><tbody>';
        lines{end+1} = metaRow('Source File', char(srcFile));
        lines{end+1} = metaRow('Parser', metaField(ds, 'parserName', '—'));
        lines{end+1} = metaRow('Import Date', metaField(ds, 'importDate', '—'));
        lines{end+1} = metaRow('Data Points', num2str(size(ds.values, 1)));
        lines{end+1} = metaRow('Channels', num2str(size(ds.values, 2)));
        lines{end+1} = metaRow('Column Labels', strjoin(ds.labels, ', '));
        lines{end+1} = metaRow('Units', strjoin(ds.units, ', '));
        lines{end+1} = '</tbody></table>';
    end

    % ── Data preview (first 10 rows) ──────────────────────────────────
    nPreview  = min(10, size(ds.values, 1));
    allLabels = [{'x'}, ds.labels];
    lines{end+1} = sprintf('<h3>Data Preview (first %d rows)</h3>', nPreview);
    lines{end+1} = '<div class="table-scroll">';
    lines{end+1} = '<table class="data-table"><thead><tr>';
    for col = 1:numel(allLabels)
        lines{end+1} = sprintf('<th>%s</th>', htmlEscape(allLabels{col}));
    end
    lines{end+1} = '</tr></thead><tbody>';
    for row = 1:nPreview
        lines{end+1} = '<tr>';
        lines{end+1} = sprintf('<td>%s</td>', formatNum(ds.time(row)));
        for col = 1:size(ds.values, 2)
            lines{end+1} = sprintf('<td>%s</td>', formatNum(ds.values(row, col)));
        end
        lines{end+1} = '</tr>';
    end
    lines{end+1} = '</tbody></table></div>';

    % ── Statistics ────────────────────────────────────────────────────
    if options.IncludeStats
        lines{end+1} = '<h3>Statistics</h3>';
        lines{end+1} = '<div class="table-scroll">';
        lines{end+1} = '<table class="stats-table"><thead><tr>';
        lines{end+1} = '<th>Column</th><th>Min</th><th>Max</th><th>Mean</th><th>Std</th><th>Median</th>';
        lines{end+1} = '</tr></thead><tbody>';
        for col = 1:size(ds.values, 2)
            v   = ds.values(:, col);
            lbl = '';
            if col <= numel(ds.labels), lbl = ds.labels{col}; end
            lines{end+1} = sprintf( ...
                '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>', ...
                htmlEscape(lbl), formatNum(min(v)), formatNum(max(v)), ...
                formatNum(mean(v)), formatNum(std(v)), formatNum(median(v)));
        end
        lines{end+1} = '</tbody></table></div>';
    end

    % ── Embedded plot ─────────────────────────────────────────────────
    if options.IncludePlots
        lines{end+1} = '<h3>Plot</h3>';
        imgTag = buildEmbeddedPlot(ds, k, tmpDir, options);
        if ~isempty(imgTag)
            lines{end+1} = imgTag;
        else
            lines{end+1} = '<p class="warn">Plot generation failed.</p>';
        end
    end

    lines{end+1} = '</section>';
end

% ── Custom sections ───────────────────────────────────────────────────
for k = 1:numel(options.CustomSections)
    sec = options.CustomSections{k};
    secTitle   = '';
    secContent = '';
    if isstruct(sec)
        if isfield(sec, 'title'),   secTitle   = sec.title;   end
        if isfield(sec, 'content'), secContent = sec.content; end
    end
    lines{end+1} = '<section class="custom-section">';
    if ~isempty(secTitle)
        lines{end+1} = sprintf('<h2>%s</h2>', htmlEscape(char(secTitle)));
    end
    lines{end+1} = char(secContent);
    lines{end+1} = '</section>';
end

% ── Footer ────────────────────────────────────────────────────────────
lines{end+1} = '<footer><p>Generated by quantized_matlab — scripts.generateReport</p></footer>';
lines{end+1} = '</body></html>';

% Write file
fid = fopen(outPath, 'w', 'n', 'UTF-8');
if fid == -1
    error('scripts:generateReport:cannotWrite', ...
        'Cannot open file for writing: %s', outPath);
end
fprintf(fid, '%s\n', lines{:});
fclose(fid);
end % writeHtmlReport


% ════════════════════════════════════════════════════════════════════════
%  Plain-text report builder
% ════════════════════════════════════════════════════════════════════════
function writeTxtReport(outPath, datasets, nSets, options, dateStr)

SEP  = repmat('=', 1, 72);
SEP2 = repmat('-', 1, 72);

lines = {};
lines{end+1} = SEP;
lines{end+1} = padCenter(char(options.Title), 72);
lines{end+1} = SEP;
if char(options.Author) ~= ""
    lines{end+1} = sprintf('Author  : %s', char(options.Author));
end
lines{end+1} = sprintf('Date    : %s', dateStr);
lines{end+1} = sprintf('Created : %s', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
lines{end+1} = '';

% ── Summary ───────────────────────────────────────────────────────────
lines{end+1} = SEP;
lines{end+1} = 'SUMMARY';
lines{end+1} = SEP;
lines{end+1} = sprintf('Datasets : %d', nSets);
lines{end+1} = '';
for k = 1:nSets
    ds = datasets{k};
    srcFile = metaField(ds, 'sourceFile', '');
    if isempty(srcFile)
        srcFile = metaField(ds, 'filename', sprintf('Dataset %d', k));
    end
    lines{end+1} = sprintf('  %d. %s  (%d pts, %d ch)', ...
        k, char(srcFile), size(ds.values,1), size(ds.values,2));
end
lines{end+1} = '';

% ── Per-dataset sections ──────────────────────────────────────────────
for k = 1:nSets
    ds = datasets{k};
    srcFile = metaField(ds, 'sourceFile', '');
    if isempty(srcFile)
        srcFile = metaField(ds, 'filename', sprintf('Dataset %d', k));
    end

    lines{end+1} = SEP;
    lines{end+1} = sprintf('DATASET %d: %s', k, char(srcFile));
    lines{end+1} = SEP;

    % Metadata
    if options.IncludeMetadata
        lines{end+1} = 'Metadata:';
        lines{end+1} = SEP2;
        lines{end+1} = sprintf('  Parser      : %s', metaField(ds,'parserName','—'));
        lines{end+1} = sprintf('  Import Date : %s', metaField(ds,'importDate','—'));
        lines{end+1} = sprintf('  Data Points : %d', size(ds.values,1));
        lines{end+1} = sprintf('  Channels    : %d', size(ds.values,2));
        lines{end+1} = sprintf('  Labels      : %s', strjoin(ds.labels,', '));
        lines{end+1} = sprintf('  Units       : %s', strjoin(ds.units,', '));
        lines{end+1} = '';
    end

    % Data preview
    nPreview = min(10, size(ds.values,1));
    lines{end+1} = sprintf('Data Preview (first %d rows):', nPreview);
    lines{end+1} = SEP2;
    allLabels = [{'x'}, ds.labels];
    hdr = sprintf('%-14s', allLabels{:});
    lines{end+1} = hdr;
    lines{end+1} = SEP2;
    for row = 1:nPreview
        rowStr = sprintf('%-14s', formatNum(ds.time(row)));
        for col = 1:size(ds.values,2)
            rowStr = [rowStr, sprintf('%-14s', formatNum(ds.values(row,col)))]; %#ok<AGROW>
        end
        lines{end+1} = rowStr;
    end
    lines{end+1} = '';

    % Statistics
    if options.IncludeStats
        lines{end+1} = 'Statistics:';
        lines{end+1} = SEP2;
        lines{end+1} = sprintf('%-16s %-12s %-12s %-12s %-12s %-12s', ...
            'Column','Min','Max','Mean','Std','Median');
        lines{end+1} = SEP2;
        for col = 1:size(ds.values,2)
            v   = ds.values(:,col);
            lbl = '';
            if col <= numel(ds.labels), lbl = ds.labels{col}; end
            lines{end+1} = sprintf('%-16s %-12s %-12s %-12s %-12s %-12s', ...
                lbl, formatNum(min(v)), formatNum(max(v)), ...
                formatNum(mean(v)), formatNum(std(v)), formatNum(median(v)));
        end
        lines{end+1} = '';
    end
end

% Custom sections
for k = 1:numel(options.CustomSections)
    sec = options.CustomSections{k};
    if isstruct(sec) && isfield(sec,'title')
        lines{end+1} = SEP;
        lines{end+1} = upper(char(sec.title));
        lines{end+1} = SEP;
        if isfield(sec,'content')
            lines{end+1} = char(sec.content);
        end
        lines{end+1} = '';
    end
end

% Footer
lines{end+1} = SEP;
lines{end+1} = 'Generated by quantized_matlab — scripts.generateReport';
lines{end+1} = SEP;

% Write file
fid = fopen(outPath, 'w', 'n', 'UTF-8');
if fid == -1
    error('scripts:generateReport:cannotWrite', ...
        'Cannot open file for writing: %s', outPath);
end
fprintf(fid, '%s\n', lines{:});
fclose(fid);
end % writeTxtReport


% ════════════════════════════════════════════════════════════════════════
%  Local: build an embedded plot image tag (HTML)
% ════════════════════════════════════════════════════════════════════════
function imgTag = buildEmbeddedPlot(ds, idx, tmpDir, options)
%BUILDEMBEDDEDPLOT  Render dataset to a figure, save to tmpDir, return <img> tag.
    imgTag = '';
    try
        fig = figure('Visible', 'off', 'Units', 'centimeters', ...
                     'Position', [0 0 15 10]);
        ax  = axes(fig);
        hold(ax, 'on');
        nCols = min(size(ds.values,2), 8);  % cap to 8 channels
        for c = 1:nCols
            lbl = '';
            if c <= numel(ds.labels), lbl = ds.labels{c}; end
            plot(ax, ds.time, ds.values(:,c), 'DisplayName', lbl);
        end
        hold(ax, 'off');
        if nCols > 1
            legend(ax, 'Interpreter', 'none', 'Location', 'best', 'FontSize', 8);
        end

        imgFile = fullfile(tmpDir, sprintf('ds_%d.%s', idx, char(options.PlotFormat)));
        if options.PlotFormat == "svg"
            print(fig, imgFile, '-dsvg', '-vector');
        else
            print(fig, imgFile, '-dpng', sprintf('-r%d', options.PlotDPI));
        end
        close(fig);

        if options.PlotFormat == "png"
            % Base64-encode for self-contained HTML
            b64 = base64encodeFile(imgFile);
            if ~isempty(b64)
                imgTag = sprintf('<img src="data:image/png;base64,%s" alt="Dataset %d plot" class="plot-img">', b64, idx);
            else
                % Fallback to file reference
                imgTag = sprintf('<img src="%s" alt="Dataset %d plot" class="plot-img">', imgFile, idx);
            end
        else
            % SVG: inline the file contents
            svgStr = readFileToString(imgFile);
            if ~isempty(svgStr)
                imgTag = sprintf('<div class="plot-img">%s</div>', svgStr);
            else
                imgTag = sprintf('<img src="%s" alt="Dataset %d plot" class="plot-img">', imgFile, idx);
            end
        end
    catch ME
        warning('scripts:generateReport:plotFailed', ...
            'Plot generation failed for dataset %d: %s', idx, ME.message);
        if exist('fig','var') && ishandle(fig)
            close(fig);
        end
    end
end


% ════════════════════════════════════════════════════════════════════════
%  Local: base64 encode a file (no external toolbox)
% ════════════════════════════════════════════════════════════════════════
function b64 = base64encodeFile(filepath)
%BASE64ENCODEFILE  Read binary file and return base64 string.
    b64 = '';
    try
        fid  = fopen(filepath, 'rb');
        if fid == -1, return; end
        data = fread(fid, '*uint8');
        fclose(fid);
        % Use MATLAB built-in base64 encoder (available R2016b+)
        b64 = matlab.net.base64encode(data);
    catch
        b64 = '';
    end
end


% ════════════════════════════════════════════════════════════════════════
%  Local: read a text file into a single string
% ════════════════════════════════════════════════════════════════════════
function str = readFileToString(filepath)
%READFILETOSTRING  Return contents of a text file as a char array.
    str = '';
    fid = fopen(filepath, 'r', 'n', 'UTF-8');
    if fid == -1, return; end
    lines = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
    fclose(fid);
    str = strjoin(lines{1}, newline);
end


% ════════════════════════════════════════════════════════════════════════
%  Local: HTML helper utilities
% ════════════════════════════════════════════════════════════════════════
function s = htmlEscape(s)
%HTMLESCAPE  Escape special HTML characters.
    s = strrep(s, '&',  '&amp;');
    s = strrep(s, '<',  '&lt;');
    s = strrep(s, '>',  '&gt;');
    s = strrep(s, '"',  '&quot;');
end

function row = metaRow(key, val)
%METAROW  Build an HTML table row for a metadata key-value pair.
    row = sprintf('<tr><th>%s</th><td>%s</td></tr>', ...
        htmlEscape(key), htmlEscape(char(val)));
end

function val = metaField(ds, fieldName, defaultVal)
%METAFIELD  Safely read a field from ds.metadata, returning defaultVal if absent.
    if isfield(ds.metadata, fieldName)
        val = ds.metadata.(fieldName);
        if isnumeric(val), val = num2str(val); end
        if isdatetime(val), val = char(val); end
    else
        val = defaultVal;
    end
end

function s = formatNum(v)
%FORMATNUM  Format a scalar number concisely for tables.
    if ~isfinite(v)
        s = num2str(v);
    elseif abs(v) == 0
        s = '0';
    elseif abs(v) >= 1e4 || (abs(v) < 1e-3 && abs(v) > 0)
        s = sprintf('%.4g', v);
    else
        s = sprintf('%.5g', v);
    end
end

function s = padCenter(str, width)
%PADCENTER  Centre a string within a field of given width.
    n   = numel(str);
    pad = max(0, floor((width - n) / 2));
    s   = [repmat(' ', 1, pad), str];
end

function safeRmdir(d)
%SAFERMDIR  Delete a directory tree; ignore errors (cleanup helper).
    try
        if isfolder(d)
            rmdir(d, 's');
        end
    catch
    end
end


% ════════════════════════════════════════════════════════════════════════
%  CSS
% ════════════════════════════════════════════════════════════════════════
function css = htmlCss()
%HTMLCSS  Return embedded CSS for the HTML report.
css = [ ...
'body{font-family:Arial,Helvetica,sans-serif;font-size:14px;', ...
    'line-height:1.5;margin:0;padding:0;background:#f8f9fa;color:#212529;}', ...
'.report-header{background:#1a3a5c;color:#fff;padding:24px 40px 16px;}', ...
'.report-header h1{margin:0 0 8px;font-size:24px;}', ...
'.meta-line{display:flex;gap:24px;font-size:12px;opacity:0.85;}', ...
'section{margin:24px 40px;background:#fff;border-radius:6px;', ...
    'padding:20px 28px;box-shadow:0 1px 4px rgba(0,0,0,.08);}', ...
'.summary{}', ...
'h2{color:#1a3a5c;margin-top:0;font-size:18px;border-bottom:2px solid #dee2e6;', ...
    'padding-bottom:6px;}', ...
'h3{color:#495057;font-size:15px;margin-top:16px;}', ...
'table{border-collapse:collapse;font-size:13px;}', ...
'.summary-table,.data-table,.stats-table{width:100%;}', ...
'.meta-table{width:auto;min-width:400px;}', ...
'th{background:#343a40;color:#fff;padding:6px 10px;text-align:left;}', ...
'td{padding:5px 10px;border-bottom:1px solid #dee2e6;}', ...
'tr:nth-child(even) td{background:#f2f4f6;}', ...
'.meta-table th{background:#495057;width:180px;}', ...
'.table-scroll{overflow-x:auto;}', ...
'.plot-img{max-width:100%;height:auto;margin-top:8px;border:1px solid #dee2e6;border-radius:4px;}', ...
'.plot-img img{max-width:100%;}', ...
'.warn{color:#856404;background:#fff3cd;padding:6px 10px;border-radius:4px;}', ...
'.custom-section{}', ...
'footer{text-align:center;padding:20px;color:#6c757d;font-size:12px;}', ...
];
end
