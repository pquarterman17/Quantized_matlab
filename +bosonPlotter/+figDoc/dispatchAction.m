function dispatchAction(action, fig, appData, overlayOn, ax, setStatusFcn)
%DISPATCHACTION  Route figDoc menu actions (properties, export, copy).

    if appData.activeIdx < 1, return; end
    ds = appData.datasets{appData.activeIdx};
    if ~isfield(ds, 'figDoc') || isempty(ds.figDoc), return; end
    model = ds.figDoc;

    applyFcn = @() bosonPlotter.figDoc.applyAfterRender(ax, appData.datasets, appData.activeIdx);

    switch action
        case 'properties'
            bosonPlotter.figDoc.buildPropertiesPanel(fig, model, applyFcn);
        case 'export'
            bosonPlotter.figDoc.buildQuickExportDialog(fig, appData.datasets, ...
                appData.activeIdx, overlayOn, model);
        case 'copy'
            try
                bosonPlotter.figDoc.copyForSlides(appData.datasets, ...
                    appData.activeIdx, overlayOn, model);
                setStatusFcn('Plot copied to clipboard (slide format).');
            catch ME
                setStatusFcn(['Copy failed: ' ME.message]);
            end
        case 'annotations'
            bosonPlotter.figDoc.buildAnnotationDialog(fig, ax, model, applyFcn);
        case 'traceStyles'
            bosonPlotter.figDoc.buildTraceStyleDialog(fig, ax, model, applyFcn);
        case 'templates'
            bosonPlotter.figDoc.buildTemplateDialog(fig, model, applyFcn);
    end
end
