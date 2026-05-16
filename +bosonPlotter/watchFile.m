function watchFile(appData, fig, cb)
%WATCHFILE  Start or stop live file watching on the active dataset.
%
%   bosonPlotter.watchFile(appData, fig, cb)
%
%   Inputs:
%     appData - AppState handle
%     fig     - uifigure
%     cb      - struct with fields: setStatus, rebuildDatasetList, onPlot

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig, 'Load a file first.', 'Watch File');
        return;
    end

    idx = appData.activeIdx;
    ds  = appData.datasets{idx};

    while numel(appData.dataConnectors) < idx
        appData.dataConnectors{end+1} = [];
    end

    existing = appData.dataConnectors{idx};
    if ~isempty(existing) && isstruct(existing) && existing.isRunning()
        existing.stop();
        appData.dataConnectors{idx} = [];
        cb.setStatus(sprintf('File watch stopped for: %s', ds.filepath));
        return;
    end

    if ~isfile(ds.filepath)
        uialert(fig, sprintf('Cannot watch: file not found.\n%s', ds.filepath), 'Watch File');
        return;
    end

    connector = scripts.dataConnector(ds.filepath, ...
        Callback=@(newData) onFileChanged_(appData, idx, newData, cb));
    appData.dataConnectors{idx} = connector;
    cb.setStatus(sprintf('Watching: %s', ds.filepath));
end

function onFileChanged_(appData, dsIdx, newData, cb)
    if dsIdx < 1 || dsIdx > numel(appData.datasets), return; end
    ds = appData.datasets{dsIdx};
    ds.data     = newData;
    ds.corrData = [];
    appData.datasets{dsIdx} = ds;
    try
        appData.model.updateDataset(dsIdx, ds);
    catch
    end
    cb.rebuildDatasetList(false);
    if appData.activeIdx == dsIdx
        cb.onPlot();
    end
    cb.setStatus(sprintf('Reloaded: %s', ds.filepath));
end
