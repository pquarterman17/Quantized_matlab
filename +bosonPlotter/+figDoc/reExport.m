function reExport(datasets, activeIdx, overlayOn, model, setStatusFcn)
%REEXPORT  Repeat last export with stored profile and path.
%
%   bosonPlotter.figDoc.reExport(datasets, activeIdx, overlayOn, model, setStatusFcn)
%
%   If lastExportPath is set, overwrites that file with the current figure
%   state using lastExportProfile. If no previous export exists, opens the
%   Quick Export dialog instead.

    if isempty(model.lastExportPath) || strlength(model.lastExportPath) == 0
        fig = ancestor(findobj('Type','uifigure'), 'figure');
        if isempty(fig)
            setStatusFcn('No previous export — use Quick Export first.');
            return;
        end
        bosonPlotter.figDoc.buildQuickExportDialog(fig, datasets, activeIdx, overlayOn, model);
        return;
    end

    try
        outPath = bosonPlotter.figDoc.exportRender(datasets, activeIdx, ...
            overlayOn, model, model.lastExportProfile, char(model.lastExportPath));
        model.lastExportPath = string(outPath);
        setStatusFcn(sprintf('Re-exported: %s', outPath));
    catch ME
        setStatusFcn(sprintf('Export failed: %s', ME.message));
    end
end
