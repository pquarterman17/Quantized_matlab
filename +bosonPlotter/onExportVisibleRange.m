function onExportVisibleRange(appData, fig, ax)
%ONEXPORTVISIBLERANGE  Export only the data within the current axis X limits to CSV.
%
% Syntax
%   bosonPlotter.onExportVisibleRange(appData, fig, ax)
%
% Behaviour
%   Reads the active dataset (using `corrData` when present, otherwise
%   `data`), applies display-unit scaling via
%   `bosonPlotter.applyDisplayUnits`, filters rows to the current X-axis
%   limits, and writes the filtered data to a user-chosen CSV file.
%   The Y-column order matches `primaryD.labels`; the header row is
%   `xHdr, label1 (unit1), label2 (unit2), ...`.  Empty selections and
%   file-open failures surface through `uialert`.
%
% Inputs
%   appData - bosonPlotter.AppState handle (reads datasets / activeIdx)
%   fig     - Main figure handle (uialert parent)
%   ax      - Main axes (reads XLim)
%
% Notes
%   Label formatting matches the +bosonPlotter/ convention (no greekify)
%   for CSV-friendly plain-text headers — differs slightly from the
%   interactive axis labels in the main plot.

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig, 'Load a file first.', 'No data'); return;
    end
    ds  = appData.datasets{appData.activeIdx};
    src = guiTernary(~isempty(ds.corrData), ds.corrData, ds.data);
    % Apply display-unit scaling so exported values match the preview
    src = bosonPlotter.applyDisplayUnits(src, ds, appData);
    xLims = ax.XLim;

    % Filter data to visible x range (use scaled x values)
    xVec = double(src.time);
    mask = xVec >= xLims(1) & xVec <= xLims(2);
    if ~any(mask)
        uialert(fig, 'No data points in the visible range.', 'Empty'); return;
    end

    % Build output table
    xVisible = xVec(mask);
    yVisible = src.values(mask, :);

    % File dialog
    [~, fn, ~] = fileparts(ds.filepath);
    defaultName = [fn '_visible.csv'];
    [outFile, outDir] = uiputfile({'*.csv','CSV (*.csv)'}, ...
        'Export Visible Range', defaultName);
    if isequal(outFile, 0), return; end
    outPath = fullfile(outDir, outFile);

    % Write CSV with headers (labels already updated by applyDisplayUnits)
    fid = fopen(outPath, 'w');
    if fid == -1
        uialert(fig, 'Cannot open file for writing.', 'Error'); return;
    end
    xHdr = guiLabel(guiXName(src.metadata), guiXUnit(src.metadata));
    headers = [{xHdr}, cellfun(@(l,u) guiLabel(l,u), ...
        src.labels(:)', src.units(:)', 'UniformOutput', false)];
    fprintf(fid, '%s', headers{1});
    for hi = 2:numel(headers)
        fprintf(fid, ',%s', headers{hi});
    end
    fprintf(fid, '\n');
    % Data rows
    for ri = 1:numel(xVisible)
        fprintf(fid, '%.10g', xVisible(ri));
        for ci = 1:size(yVisible, 2)
            fprintf(fid, ',%.10g', yVisible(ri, ci));
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
    uialert(fig, sprintf('Exported %d points to:\n%s', sum(mask), outPath), ...
        'Export Complete');
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function name = guiXName(meta)
    if isfield(meta,'xColumnName') && ~isempty(meta.xColumnName)
        name = meta.xColumnName;
    else
        name = 'X';
    end
end

function u = guiXUnit(meta)
    if isfield(meta,'xColumnUnit') && ~isempty(meta.xColumnUnit)
        u = meta.xColumnUnit;
    else
        u = '';
    end
end

function s = guiLabel(name, unit)
    if isempty(unit)
        s = name;
    else
        s = sprintf('%s (%s)', name, unit);
    end
end
