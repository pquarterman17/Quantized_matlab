function capture(ax, datasets, activeIdx)
%CAPTURE  Read current axes state back into the active dataset's figDoc.
%
%   bosonPlotter.figDoc.capture(ax, datasets, activeIdx)
%
%   Convenience wrapper around captureFromAxes that extracts the model
%   from the dataset and validates inputs.

    if activeIdx < 1 || isempty(datasets), return; end
    if isempty(ax) || ~isvalid(ax), return; end
    ds = datasets{activeIdx};
    if ~isfield(ds, 'figDoc') || isempty(ds.figDoc), return; end
    bosonPlotter.figDoc.captureFromAxes(ax, ds.figDoc);
end
