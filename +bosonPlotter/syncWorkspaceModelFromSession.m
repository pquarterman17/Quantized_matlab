function syncWorkspaceModelFromSession(appData, datasets, restored)
%SYNCWORKSPACEMODELFROMSESSION  Push restored datasets + modelState into appData.model.
%
% Syntax
%   bosonPlotter.syncWorkspaceModelFromSession(appData, datasets, restored)
%
% Behaviour
%   Assembles a WorkspaceModel snapshot from the session payload and
%   calls restoreFromSnapshot on appData.model.  Called by both the
%   interactive load path (+bosonPlotter/onLoadSession) and the
%   programmatic API path (loadSessionDirect inside BosonPlotter.m).
%
%   Legacy sessions (saved before model state was persisted) arrive
%   with empty mask/computedColumns/columnRoles in restored.modelState;
%   this function pads them to match the dataset count with safe
%   defaults (all-true mask, empty computed columns, default
%   ColumnRoles sized to the dataset's value-column count).
%
% Inputs
%   appData  - AppState handle; mutates appData.model
%   datasets - Cell array of BosonPlotter ds wrappers (each with
%              .data, .name, .axLims, ...).  This function extracts the
%              .data struct for the model snapshot.
%   restored - Struct returned by sessionManager.load with fields
%              activeIdx + modelState (.mask, .computedColumns,
%              .columnRoles, .version).
%
% Notes
%   No-op when appData.model is missing or invalid.  Fires DataChanged
%   and SelectionChanged through restoreFromSnapshot.

    if ~isprop(appData, 'model') || isempty(appData.model) || ~isvalid(appData.model)
        return;
    end

    nDs = numel(datasets);
    ms  = restored.modelState;

    % BosonPlotter's `datasets` is a cell of ds wrappers (.data, .name,
    % .axLims, ...).  The WorkspaceModel stores raw unified data structs
    % in its `datasets` cell, so extract `.data` from each wrapper
    % before building the snapshot.
    modelDatasets = cell(1, nDs);
    for k = 1:nDs
        ds = datasets{k};
        if isstruct(ds) && isfield(ds, 'data') && isstruct(ds.data)
            modelDatasets{k} = ds.data;
        else
            modelDatasets{k} = ds;
        end
    end

    if numel(ms.mask) ~= nDs
        ms.mask = cell(1, nDs);
        for k = 1:nDs
            rows = numel(modelDatasets{k}.time);
            ms.mask{k} = true(rows, 1);
        end
    end
    if numel(ms.computedColumns) ~= nDs
        ms.computedColumns = cell(1, nDs);
    end
    if numel(ms.columnRoles) ~= nDs
        ms.columnRoles = cell(1, nDs);
        for k = 1:nDs
            nCols = size(modelDatasets{k}.values, 2);
            ms.columnRoles{k} = dataWorkspace.ColumnRoles(nCols);
        end
    end

    snap = struct( ...
        'datasets',        {modelDatasets}, ...
        'mask',            {ms.mask}, ...
        'columnRoles',     {ms.columnRoles}, ...
        'computedColumns', {ms.computedColumns}, ...
        'activeIdx',       restored.activeIdx, ...
        'timestamp',       datetime('now'), ...
        'version',         '1.0');

    appData.model.restoreFromSnapshot(snap);
end
