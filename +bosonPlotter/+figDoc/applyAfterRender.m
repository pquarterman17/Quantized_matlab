function applyAfterRender(ax, datasets, activeIdx)
%APPLYAFTERRENDER  Re-apply figDoc overrides after renderPlot.
%
%   bosonPlotter.figDoc.applyAfterRender(ax, datasets, activeIdx)
%
%   Called after bosonPlotter.renderPlot to restore persistent manual
%   overrides (axis limits, legend config, annotations, trace styles)
%   that renderPlot would otherwise have wiped.

    if activeIdx < 1 || isempty(datasets), return; end
    if isempty(ax) || ~isvalid(ax), return; end
    ds = datasets{activeIdx};
    if ~isfield(ds, 'figDoc') || isempty(ds.figDoc), return; end
    fdm = ds.figDoc;
    if ~fdm.hasManualLimits() && isempty(fdm.annotations) ...
            && isempty(fdm.traceStyles) && ~fdm.dirty
        return;
    end
    bosonPlotter.figDoc.applyToAxes(ax, fdm);
end
