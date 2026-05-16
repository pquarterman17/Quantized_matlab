function overlayActions(action, appData, lbDatasets, onSelectDataset, setStatus)
%OVERLAYACTIONS  Quick overlay commands for the dataset context menu.

    if isempty(appData.datasets) || appData.activeIdx < 1, return; end

    switch action
        case 'add'
            nDs = numel(appData.datasets);
            if nDs < 2
                setStatus('Need at least 2 datasets for overlay.');
                return;
            end
            lbDatasets.Value = num2cell(1:nDs);
            onSelectDataset([], []);
            setStatus(sprintf('Overlay: all %d datasets shown.', nDs));

        case 'y2'
            idx = appData.activeIdx;
            ds = appData.datasets{idx};
            if ~isfield(ds, 'figDoc') || isempty(ds.figDoc)
                ds.figDoc = bosonPlotter.figDoc.FigDocModel();
            end
            nTraces = size(ds.data.values, 2);
            for t = 1:nTraces
                ds.figDoc.setTraceYAxis(t, 'right');
            end
            appData.datasets{idx} = ds;
            bosonPlotter.overlayActions('add', appData, lbDatasets, onSelectDataset, setStatus);
            setStatus('Dataset assigned to right Y-axis + overlay.');
    end
end
