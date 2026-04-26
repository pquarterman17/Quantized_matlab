function changedIdx = syncMasksFromModel(appData)
%SYNCMASKSFROMMODEL  Pull row masks from the shared WorkspaceModel into the
%   per-dataset working copies in appData.datasets{:}.mask.
%
%   changedIdx = bosonPlotter.syncMasksFromModel(appData)
%
%   The shared WorkspaceModel (edited by DataWorkspace) stores masks in
%   model.mask{idx}; BosonPlotter's plotting and corrections paths read
%   appData.datasets{idx}.mask. This helper copies model → appData,
%   matching by dataset index. Datasets present in appData but absent
%   from the model (or with mismatched length) are left untouched.
%
%   Returns the indices of datasets whose masks actually changed, so the
%   caller can decide whether to redraw. Empty if nothing changed.
%
%   Convention (both sides agree): true = row included, false = masked.

    arguments
        appData
    end

    changedIdx = [];
    if isempty(appData.model) || ~isa(appData.model, 'dataWorkspace.WorkspaceModel')
        return;
    end
    nModel = appData.model.count();
    nLocal = numel(appData.datasets);
    nSync  = min(nModel, nLocal);

    for k = 1:nSync
        modelMask = appData.model.mask{k};
        if isempty(modelMask), continue; end
        ds = appData.datasets{k};
        nRows = numel(ds.data.time);
        if numel(modelMask) ~= nRows, continue; end

        if ~isfield(ds, 'mask') || isempty(ds.mask) ...
                || numel(ds.mask) ~= nRows ...
                || ~isequal(logical(ds.mask(:)), logical(modelMask(:)))
            ds.mask = logical(modelMask(:));
            appData.datasets{k} = ds;
            changedIdx(end+1) = k; %#ok<AGROW>
        end
    end
end
