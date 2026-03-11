%EXAMPLE_BATCH_IMPORT  Batch-import a directory of mixed instrument files.
%
%   Demonstrates:
%     - scripts.batchImport for scanning directories automatically
%     - Recursive import with mixed file types (.dat, .raw, .xrdml, .refl)
%     - Filtering by extension or parser type
%     - Aggregating results and reporting errors
%     - Waterfall plot from a series of datasets
%     - Saving a summary table to CSV
%
%   Run this script from any directory — it locates test data automatically.
%
%   See also scripts.batchImport, scripts.batchConvertXRD, parser.importAuto

clear; clc;

ROOT = fileparts(fileparts(mfilename('fullpath')));
addpath(ROOT);
setupToolbox;

TEST_DIR = fullfile(ROOT, '+test_datasets');

% ════════════════════════════════════════════════════════════════
%  1. Basic recursive batch import
% ════════════════════════════════════════════════════════════════
%   batchImport walks the directory tree, calls importAuto on each
%   supported file, and returns a struct array with results.
%
%   Fields per entry:
%     .file     — full file path
%     .data     — parsed data struct (empty if error)
%     .error    — error message string (empty if success)
%     .duration — import time (seconds)

fprintf('=== 1. Recursive batch import of +test_datasets ===\n');
results = scripts.batchImport(TEST_DIR, 'Recursive', true, 'Verbose', false);

nTotal  = numel(results);
nOK     = sum(cellfun(@isempty, {results.error}));
nFail   = nTotal - nOK;

fprintf('  Total files attempted : %d\n', nTotal);
fprintf('  Successful imports    : %d\n', nOK);
fprintf('  Failed / unsupported  : %d\n', nFail);

% ════════════════════════════════════════════════════════════════
%  2. Inspect results — what parser was used for each file?
% ════════════════════════════════════════════════════════════════
fprintf('\n=== 2. Parser breakdown ===\n');
parserNames = {};
for k = 1:nTotal
    if isempty(results(k).error) && ~isempty(results(k).data)
        pn = results(k).data.metadata.parserName;
        parserNames{end+1} = pn; %#ok<AGROW>
    end
end
[uParsers, ~, pidx] = unique(parserNames);
for k = 1:numel(uParsers)
    fprintf('  %-25s : %d files\n', uParsers{k}, sum(pidx == k));
end

% ════════════════════════════════════════════════════════════════
%  3. Show any failed files (with reason)
% ════════════════════════════════════════════════════════════════
failIdx = find(~cellfun(@isempty, {results.error}));
if ~isempty(failIdx)
    fprintf('\n=== 3. Failed imports ===\n');
    for k = failIdx
        [~,fname,ext] = fileparts(results(k).file);
        fprintf('  %s%s : %s\n', fname, ext, results(k).error);
    end
end

% ════════════════════════════════════════════════════════════════
%  4. Filter: keep only XRD datasets (Rigaku .raw and .xrdml)
% ════════════════════════════════════════════════════════════════
%   Strategy: check parserName for 'Rigaku' or 'XRDML'

xrdDatasets = {};
xrdLabels   = {};

for k = 1:nTotal
    if isempty(results(k).error) && ~isempty(results(k).data)
        pn = results(k).data.metadata.parserName;
        if contains(lower(pn), 'rigaku') || contains(lower(pn), 'xrdml')
            xrdDatasets{end+1} = results(k).data; %#ok<AGROW>
            [~,fn,~] = fileparts(results(k).file);
            xrdLabels{end+1} = fn; %#ok<AGROW>
        end
    end
end
fprintf('\n=== 4. XRD datasets found: %d ===\n', numel(xrdDatasets));

% ════════════════════════════════════════════════════════════════
%  5. Waterfall plot — stacked XRD patterns with vertical offset
% ════════════════════════════════════════════════════════════════
%   Each scan is shifted upward by a fixed offset so all are visible.
%   This is the standard way to compare a series of XRD scans (e.g.
%   annealing series, thickness series, temperature series).

if numel(xrdDatasets) >= 2
    th   = styles.default();
    nXRD = numel(xrdDatasets);
    cols = plotting.lineColors(nXRD, th);

    fig1 = figure('Name', 'XRD Waterfall');
    ax1  = axes(fig1);
    hold(ax1, 'on');

    % Determine a reasonable stack offset = 30% of the max intensity across all scans
    maxI = max(cellfun(@(d) max(d.values(:,1)), xrdDatasets));
    offset = 0.30 * maxI;

    for k = 1:nXRD
        d  = xrdDatasets{k};
        I  = d.values(:,1) / max(d.values(:,1));   % peak-normalise each scan
        vertOff = (k-1) * 1.2;                      % 1.2 × unit spacing between scans
        plot(ax1, d.time, I + vertOff, ...
            'Color', cols(k,:), 'LineWidth', 0.9, 'DisplayName', xrdLabels{k});
    end

    plotting.formatAxes(ax1, th, ...
        'XLabel', '2\theta (°)', ...
        'YLabel', 'Intensity (norm.) + offset');
    title(ax1, 'XRD Waterfall — all imported scans');
    legend(ax1, 'Location', 'northeast', 'FontSize', 7);
    grid(ax1, 'on');
end

% ════════════════════════════════════════════════════════════════
%  6. Save summary table to CSV
% ════════════════════════════════════════════════════════════════
%   Useful for keeping a lab notebook of what was imported.

summaryFile = fullfile(tempdir, 'batch_import_summary.csv');
fid = fopen(summaryFile, 'w');
fprintf(fid, 'File,Parser,NumPoints,XMin,XMax,Status\n');
for k = 1:nTotal
    [~,fn,ext] = fileparts(results(k).file);
    if isempty(results(k).error) && ~isempty(results(k).data)
        d  = results(k).data;
        pn = d.metadata.parserName;
        np = numel(d.time);
        xmn = min(d.time);
        xmx = max(d.time);
        fprintf(fid, '%s%s,%s,%d,%.4g,%.4g,OK\n', fn, ext, pn, np, xmn, xmx);
    else
        fprintf(fid, '%s%s,,,,,%s\n', fn, ext, strrep(results(k).error, ',', ';'));
    end
end
fclose(fid);
fprintf('\n=== 6. Summary saved ===\n');
fprintf('  %s\n', summaryFile);

% ════════════════════════════════════════════════════════════════
%  7. Import a single directory (non-recursive) — QuantumDesign
% ════════════════════════════════════════════════════════════════
%   Non-recursive mode is useful when different subfolders contain
%   different experiments that should be processed separately.

fprintf('\n=== 7. Non-recursive import — QuantumDesign ===\n');
qdResults = scripts.batchImport(fullfile(TEST_DIR, 'QuantumDesign'), ...
    'Recursive', false, 'Verbose', true);

nQD = sum(cellfun(@isempty, {qdResults.error}));
fprintf('  Imported %d / %d QD files successfully\n', nQD, numel(qdResults));

if nQD > 0
    % Quick overview of field ranges across all VSM files
    fprintf('  Field ranges:\n');
    for k = 1:numel(qdResults)
        if isempty(qdResults(k).error)
            d = qdResults(k).data;
            [~,fn,~] = fileparts(qdResults(k).file);
            fprintf('    %-35s  H: [%.0f, %.0f] Oe\n', fn, min(d.time), max(d.time));
        end
    end
end

fprintf('\nDone.\n');
