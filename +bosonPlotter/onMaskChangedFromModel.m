function onMaskChangedFromModel(appData, callbacks)
%ONMASKCHANGEDFROMMODEL  Handle MaskChanged event from the shared
%   WorkspaceModel. Pulls fresh masks into appData.datasets and triggers
%   a table + plot refresh if the active dataset is among those changed.
%
%   bosonPlotter.onMaskChangedFromModel(appData, callbacks)
%
%   callbacks fields:
%     .refreshTable — handle to BosonPlotter's refreshDataTable
%     .redraw       — handle to BosonPlotter's onPlot

    arguments
        appData
        callbacks struct
    end
    changed = bosonPlotter.syncMasksFromModel(appData);
    if any(changed == appData.activeIdx)
        callbacks.refreshTable();
        callbacks.redraw();
    end
end
