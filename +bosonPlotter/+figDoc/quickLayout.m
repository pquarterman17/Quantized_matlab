function quickLayout(ax, fig, appData, layout, setStatusFcn)
%QUICKLAYOUT  Create multi-panel axes layout for dataset comparison.
%
%   bosonPlotter.figDoc.quickLayout(ax, fig, appData, layout, setStatusFcn)
%
%   Inputs:
%     ax     - current main axes handle
%     fig    - uifigure handle
%     appData - AppState with datasets
%     layout  - string: '1x1', '1x2', '2x1', '2x2'
%     setStatusFcn - function handle for status messages
%
%   Creates a tiled layout within the axes parent and distributes datasets
%   across the panels. If fewer datasets than panels, extra panels stay empty.

    if isempty(appData.datasets)
        setStatusFcn('No datasets to arrange.');
        return;
    end

    parent = ax.Parent;
    nDs = numel(appData.datasets);

    switch layout
        case '1x1'
            nRows = 1; nCols = 1;
        case '1x2'
            nRows = 1; nCols = 2;
        case '2x1'
            nRows = 2; nCols = 1;
        case '2x2'
            nRows = 2; nCols = 2;
        otherwise
            setStatusFcn('Unknown layout.');
            return;
    end

    nPanels = nRows * nCols;
    if nPanels == 1
        setStatusFcn('Single panel — use normal plot mode.');
        return;
    end

    dlg = uifigure('Name', sprintf('Multi-Panel Layout (%s)', layout), ...
        'Position', [100 100 800 600], 'Resize', 'on');
    movegui(dlg, 'center');

    mainGL = uigridlayout(dlg, [2 1], 'RowHeight', {'1x', 28}, ...
        'Padding', [0 0 0 0], 'RowSpacing', 0);
    plotPanel = uipanel(mainGL, 'BorderType', 'none');
    plotPanel.Layout.Row = 1;

    tl = tiledlayout(plotPanel, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');

    axHandles = gobjects(nPanels, 1);
    for k = 1:nPanels
        axHandles(k) = nexttile(tl);
        hold(axHandles(k), 'on');
    end

    for k = 1:min(nDs, nPanels)
        ds = appData.datasets{k};
        d = ds.data;
        if ~isempty(ds.corrData)
            d = ds.corrData;
        end
        for col = 1:size(d.values, 2)
            plot(axHandles(k), d.time, d.values(:, col), ...
                'DisplayName', getLegendName_(ds, col));
        end
        if isfield(ds, 'legendName') && ~isempty(ds.legendName)
            title(axHandles(k), ds.legendName, 'Interpreter', 'none');
        end
        if ~isempty(d.labels) && numel(d.labels) >= 1
            xlabel(axHandles(k), d.labels{1});
        end
        legend(axHandles(k), 'Location', 'best', 'FontSize', 8);
    end

    if isfield(appData.datasets{1}, 'figDoc') && ~isempty(appData.datasets{1}.figDoc)
        model = appData.datasets{1}.figDoc;
        for k = 1:min(nDs, nPanels)
            if strcmp(model.xScale, 'log'), axHandles(k).XScale = 'log'; end
            if strcmp(model.yScale, 'log'), axHandles(k).YScale = 'log'; end
        end
    end

    % ── Linked axes controls (row 2 of mainGL) ─────────────────────────────
    linkGL = uigridlayout(mainGL, [1 4], 'RowHeight', {24}, ...
        'ColumnWidth', {'1x', 70, 70, 50}, 'Padding', [6 2 6 2]);
    linkGL.Layout.Row = 2;
    uilabel(linkGL, 'Text', 'Link axes:', 'FontWeight', 'bold');
    uibutton(linkGL, 'Text', 'X only', ...
        'ButtonPushedFcn', @(~,~) linkaxes(axHandles, 'x'));
    uibutton(linkGL, 'Text', 'X + Y', ...
        'ButtonPushedFcn', @(~,~) linkaxes(axHandles, 'xy'));
    uibutton(linkGL, 'Text', 'Off', ...
        'ButtonPushedFcn', @(~,~) linkaxes(axHandles, 'off'));

    setStatusFcn(sprintf('Multi-panel: %d datasets in %s layout.', min(nDs, nPanels), layout));
end

% ═══════════════════════════════════════════════════════════════════════════
function name = getLegendName_(ds, col)
    if isfield(ds, 'legendName') && ~isempty(ds.legendName)
        name = ds.legendName;
        if col > 1
            name = sprintf('%s [%d]', name, col);
        end
    else
        name = sprintf('Dataset [col %d]', col);
    end
end
