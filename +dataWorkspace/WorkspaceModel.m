classdef WorkspaceModel < handle
%WORKSPACEMODEL  Shared data model for the DataWorkspace GUI.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   model = dataWorkspace.WorkspaceModel()
%
% ── Overview ──────────────────────────────────────────────────────────────
%
%   WorkspaceModel is a handle class that owns all datasets, masks, and
%   computed column definitions.  The DataWorkspace GUI (and any future
%   plotter integration) observes the model via event listeners; all data
%   mutations flow through model methods rather than being applied directly
%   by the view.
%
%   Dataset format is the toolbox-standard unified struct:
%       .time     — [Nx1] independent-variable vector
%       .values   — [NxM] data matrix
%       .labels   — {1xM} channel name strings
%       .units    — {1xM} unit strings
%       .metadata — struct (includes .source filepath, .parserName, etc.)
%
% ── Events ────────────────────────────────────────────────────────────────
%
%   DataChanged      — fired when datasets are added, removed, or modified
%   SelectionChanged — fired when activeIdx changes
%   MaskChanged      — fired when a row mask is set
%
% ── Examples ──────────────────────────────────────────────────────────────
%
%   model = dataWorkspace.WorkspaceModel();
%   d = parser.importAuto('data.dat');
%   model.addDataset(d, 'data.dat', 'importAuto');
%   model.setActive(1);
%   ds = model.getData(1);
%
% ════════════════════════════════════════════════════════════════════════

    % ════════════════════════════════════════════════════════════════════════
    %  Events
    % ════════════════════════════════════════════════════════════════════════
    events
        DataChanged       % dataset added / removed / modified
        SelectionChanged  % activeIdx changed
        MaskChanged       % row mask changed for a dataset
    end

    % ════════════════════════════════════════════════════════════════════════
    %  Public properties
    % ════════════════════════════════════════════════════════════════════════
    properties (SetAccess = private)
        datasets         cell    % {1 x N} cell of unified data structs
        activeIdx        double  % index of currently active dataset (0 = none)
        mask             cell    % {1 x N} cell of logical vectors (true = included)
        computedColumns  cell    % {1 x N} cell of computed column definition arrays
        columnRoles      cell    % {1 x N} cell of ColumnRoles value objects
        undoStack        cell    % cell of saved model snapshots for undo
        listeners        cell    % cell of addlistener handles (managed externally)
    end

    % ════════════════════════════════════════════════════════════════════════
    %  Constructor
    % ════════════════════════════════════════════════════════════════════════
    methods

        function obj = WorkspaceModel()
        %WORKSPACEMODEL  Construct an empty WorkspaceModel.
            obj.datasets        = {};
            obj.activeIdx       = 0;
            obj.mask            = {};
            obj.computedColumns = {};
            obj.columnRoles     = {};
            obj.undoStack       = {};
            obj.listeners       = {};
        end

        % ════════════════════════════════════════════════════════════════════════
        %  Dataset management
        % ════════════════════════════════════════════════════════════════════════

        function addDataset(obj, data, filepath, parserName)
        %ADDDATASET  Append a dataset to the workspace and fire DataChanged.
        %
        %   model.addDataset(data, filepath, parserName)
        %
        %   Inputs:
        %     data       — unified data struct (must have .time, .values, etc.)
        %     filepath   — full file path string (stored in metadata.source)
        %     parserName — parser name string (stored in metadata.parserName)
            arguments
                obj        (1,1) dataWorkspace.WorkspaceModel
                data       (1,1) struct
                filepath   (1,:) char = ''
                parserName (1,:) char = ''
            end

            % Stamp source / parser into metadata if not already set
            if ~isfield(data, 'metadata') || ~isstruct(data.metadata)
                data.metadata = struct();
            end
            if ~isfield(data.metadata, 'source') || isempty(data.metadata.source)
                data.metadata.source = filepath;
            end
            if ~isfield(data.metadata, 'parserName') || isempty(data.metadata.parserName)
                data.metadata.parserName = parserName;
            end

            % Ensure required fields exist (defensive — importAuto always
            % returns these, but callers may pass hand-crafted structs)
            data = obj.ensureFields(data);

            n = numel(obj.datasets) + 1;
            obj.datasets{n}        = data;
            obj.mask{n}            = true(numel(data.time), 1);
            obj.computedColumns{n} = {};
            obj.columnRoles{n}     = dataWorkspace.ColumnRoles(size(data.values, 2));

            % Auto-activate the first dataset
            if obj.activeIdx == 0
                obj.activeIdx = 1;
            end

            notify(obj, 'DataChanged');
        end

        function removeDataset(obj, idx)
        %REMOVEDATASET  Remove a dataset by index and fire DataChanged.
        %
        %   model.removeDataset(idx)
            arguments
                obj (1,1) dataWorkspace.WorkspaceModel
                idx (1,1) double {mustBePositive, mustBeInteger}
            end

            n = numel(obj.datasets);
            if idx < 1 || idx > n
                error('dataWorkspace:WorkspaceModel:badIndex', ...
                    'Index %d out of range (1..%d).', idx, n);
            end

            obj.datasets(idx)        = [];
            obj.mask(idx)            = [];
            obj.computedColumns(idx) = [];
            obj.columnRoles(idx)     = [];

            % Clamp activeIdx
            remaining = numel(obj.datasets);
            if remaining == 0
                obj.activeIdx = 0;
            elseif obj.activeIdx > remaining
                obj.activeIdx = remaining;
            elseif obj.activeIdx >= idx
                obj.activeIdx = max(1, obj.activeIdx - 1);
            end

            notify(obj, 'DataChanged');
        end

        function setActive(obj, idx)
        %SETACTIVE  Set the active dataset index and fire SelectionChanged.
        %
        %   model.setActive(idx)
            arguments
                obj (1,1) dataWorkspace.WorkspaceModel
                idx (1,1) double {mustBeNonnegative, mustBeInteger}
            end

            n = numel(obj.datasets);
            if idx ~= 0 && (idx < 1 || idx > n)
                error('dataWorkspace:WorkspaceModel:badIndex', ...
                    'Index %d out of range (1..%d). Use 0 for "none".', idx, n);
            end

            obj.activeIdx = idx;
            notify(obj, 'SelectionChanged');
        end

        function data = getData(obj, idx)
        %GETDATA  Return dataset at index (corrData if available, else raw data).
        %
        %   data = model.getData(idx)
            arguments
                obj (1,1) dataWorkspace.WorkspaceModel
                idx (1,1) double {mustBePositive, mustBeInteger}
            end

            if idx < 1 || idx > numel(obj.datasets)
                error('dataWorkspace:WorkspaceModel:badIndex', ...
                    'Index %d out of range (1..%d).', idx, numel(obj.datasets));
            end

            ds = obj.datasets{idx};
            % Prefer corrected data when available (same convention as BosonPlotter)
            if isfield(ds, 'corrData') && ~isempty(ds.corrData) && isstruct(ds.corrData)
                data = ds.corrData;
            else
                data = ds;
            end
        end

        function updateDataset(obj, idx, ds)
        %UPDATEDATASET  Replace a dataset struct in-place and fire DataChanged.
        %
        %   model.updateDataset(idx, ds)
        %
        %   Use this instead of `model.datasets{idx} = ds` (which would fail
        %   because datasets has SetAccess=private).
            arguments
                obj (1,1) dataWorkspace.WorkspaceModel
                idx (1,1) double {mustBePositive, mustBeInteger}
                ds  (1,1) struct
            end
            obj.validateDatasetIndex(idx);
            obj.datasets{idx} = ds;
            notify(obj, 'DataChanged');
        end

        function setMask(obj, idx, maskVec)
        %SETMASK  Set the row mask for dataset idx and fire MaskChanged.
        %
        %   model.setMask(idx, maskVec)
        %
        %   maskVec is a logical vector with length == numel(data.time).
        %   true = row included, false = row masked (excluded).
            arguments
                obj     (1,1) dataWorkspace.WorkspaceModel
                idx     (1,1) double {mustBePositive, mustBeInteger}
                maskVec (:,1) logical
            end

            if idx < 1 || idx > numel(obj.datasets)
                error('dataWorkspace:WorkspaceModel:badIndex', ...
                    'Index %d out of range (1..%d).', idx, numel(obj.datasets));
            end

            nRows = numel(obj.datasets{idx}.time);
            if numel(maskVec) ~= nRows
                error('dataWorkspace:WorkspaceModel:maskSizeMismatch', ...
                    'Mask length %d does not match dataset row count %d.', ...
                    numel(maskVec), nRows);
            end

            obj.mask{idx} = maskVec(:);
            notify(obj, 'MaskChanged');
        end

        function setColumnRoles(obj, dsIdx, roles)
        %SETCOLUMNROLES  Replace the ColumnRoles for a dataset and fire DataChanged.
        %
        %   model.setColumnRoles(dsIdx, roles)
        %
        %   Inputs:
        %     dsIdx — 1-based dataset index
        %     roles — dataWorkspace.ColumnRoles value object
            arguments
                obj    (1,1) dataWorkspace.WorkspaceModel
                dsIdx  (1,1) double {mustBePositive, mustBeInteger}
                roles  (1,1) dataWorkspace.ColumnRoles
            end

            if dsIdx > numel(obj.datasets)
                error('dataWorkspace:WorkspaceModel:badIndex', ...
                    'Index %d out of range (1..%d).', dsIdx, numel(obj.datasets));
            end

            obj.columnRoles{dsIdx} = roles;
            notify(obj, 'DataChanged');
        end

        function roles = getColumnRoles(obj, dsIdx)
        %GETCOLUMNROLES  Return the ColumnRoles for a dataset.
        %
        %   roles = model.getColumnRoles(dsIdx)
        %
        %   Inputs:
        %     dsIdx — 1-based dataset index
        %
        %   Outputs:
        %     roles — dataWorkspace.ColumnRoles value object
            arguments
                obj   (1,1) dataWorkspace.WorkspaceModel
                dsIdx (1,1) double {mustBePositive, mustBeInteger}
            end

            if dsIdx > numel(obj.datasets)
                error('dataWorkspace:WorkspaceModel:badIndex', ...
                    'Index %d out of range (1..%d).', dsIdx, numel(obj.datasets));
            end

            roles = obj.columnRoles{dsIdx};
        end

        % ════════════════════════════════════════════════════════════════════════
        %  Mask operations
        % ════════════════════════════════════════════════════════════════════════

        function maskPoints(obj, dsIdx, rowIndices)
        %MASKPOINTS  Exclude specific rows from a dataset and fire MaskChanged.
        %
        %   model.maskPoints(dsIdx, rowIndices)
        %
        %   Inputs:
        %     dsIdx      — 1-based dataset index
        %     rowIndices — [1×K] row indices to mask (set to false)
            arguments
                obj        (1,1) dataWorkspace.WorkspaceModel
                dsIdx      (1,1) double {mustBePositive, mustBeInteger}
                rowIndices (1,:) double {mustBePositive, mustBeInteger}
            end

            obj.validateDatasetIndex(dsIdx);
            obj.mask{dsIdx}(rowIndices) = false;
            notify(obj, 'MaskChanged');
        end

        function unmaskPoints(obj, dsIdx, rowIndices)
        %UNMASKPOINTS  Re-include specific rows of a dataset and fire MaskChanged.
        %
        %   model.unmaskPoints(dsIdx, rowIndices)
        %
        %   Inputs:
        %     dsIdx      — 1-based dataset index
        %     rowIndices — [1×K] row indices to unmask (set to true)
            arguments
                obj        (1,1) dataWorkspace.WorkspaceModel
                dsIdx      (1,1) double {mustBePositive, mustBeInteger}
                rowIndices (1,:) double {mustBePositive, mustBeInteger}
            end

            obj.validateDatasetIndex(dsIdx);
            obj.mask{dsIdx}(rowIndices) = true;
            notify(obj, 'MaskChanged');
        end

        function maskRegion(obj, dsIdx, xMin, xMax, yMin, yMax, colIdx)
        %MASKREGION  Mask rows where X∈[xMin,xMax] AND Y colIdx∈[yMin,yMax].
        %
        %   model.maskRegion(dsIdx, xMin, xMax, yMin, yMax, colIdx)
        %
        %   Inputs:
        %     dsIdx  — 1-based dataset index
        %     xMin   — lower bound for X (inclusive)
        %     xMax   — upper bound for X (inclusive)
        %     yMin   — lower bound for Y column colIdx (inclusive)
        %     yMax   — upper bound for Y column colIdx (inclusive)
        %     colIdx — which .values column to test for Y bounds
        %
        %   Fires MaskChanged.
            arguments
                obj    (1,1) dataWorkspace.WorkspaceModel
                dsIdx  (1,1) double {mustBePositive, mustBeInteger}
                xMin   (1,1) double
                xMax   (1,1) double
                yMin   (1,1) double
                yMax   (1,1) double
                colIdx (1,1) double {mustBePositive, mustBeInteger}
            end

            obj.validateDatasetIndex(dsIdx);
            ds = obj.datasets{dsIdx};

            xVec = ds.time(:);
            yVec = ds.values(:, colIdx);

            inRegion = xVec >= xMin & xVec <= xMax & yVec >= yMin & yVec <= yMax;
            obj.mask{dsIdx}(inRegion) = false;
            notify(obj, 'MaskChanged');
        end

        function unmaskAll(obj, dsIdx)
        %UNMASKALL  Set the full row mask to true (all rows included).
        %
        %   model.unmaskAll(dsIdx)
        %
        %   Inputs:
        %     dsIdx — 1-based dataset index
        %
        %   Fires MaskChanged.
            arguments
                obj   (1,1) dataWorkspace.WorkspaceModel
                dsIdx (1,1) double {mustBePositive, mustBeInteger}
            end

            obj.validateDatasetIndex(dsIdx);
            nRows = numel(obj.datasets{dsIdx}.time);
            obj.mask{dsIdx} = true(nRows, 1);
            notify(obj, 'MaskChanged');
        end

        function m = getMask(obj, dsIdx)
        %GETMASK  Return the row mask for a dataset.
        %
        %   m = model.getMask(dsIdx)
        %
        %   Inputs:
        %     dsIdx — 1-based dataset index
        %
        %   Outputs:
        %     m — [N×1] logical vector (true = included, false = masked)
            arguments
                obj   (1,1) dataWorkspace.WorkspaceModel
                dsIdx (1,1) double {mustBePositive, mustBeInteger}
            end

            obj.validateDatasetIndex(dsIdx);
            m = obj.mask{dsIdx};
        end

        function n = count(obj)
        %COUNT  Return the number of datasets in the workspace.
        %
        %   n = model.count()
            n = numel(obj.datasets);
        end

        % ════════════════════════════════════════════════════════════════════════
        %  Undo / redo
        % ════════════════════════════════════════════════════════════════════════

        function pushUndo(obj, label)
        %PUSHUNDO  Save a snapshot of the current model state for undo.
        %
        %   model.pushUndo(label)
        %
        %   label — human-readable description of the operation being saved
            arguments
                obj   (1,1) dataWorkspace.WorkspaceModel
                label (1,:) char = ''
            end

            snap.datasets        = obj.datasets;
            snap.activeIdx       = obj.activeIdx;
            snap.mask            = obj.mask;
            snap.computedColumns = obj.computedColumns;
            snap.columnRoles     = obj.columnRoles;
            snap.label           = label;
            snap.timestamp       = now();  %#ok<TNOW1>

            obj.undoStack{end+1} = snap;
        end

        function snap = popUndo(obj)
        %POPUNDO  Restore the most recent undo snapshot and return it.
        %
        %   snap = model.popUndo()
        %
        %   Returns the snapshot struct (fields: datasets, activeIdx, mask,
        %   computedColumns, label, timestamp).  Fires DataChanged and
        %   SelectionChanged after restore.
            if isempty(obj.undoStack)
                error('dataWorkspace:WorkspaceModel:undoEmpty', ...
                    'Undo stack is empty.');
            end

            snap = obj.undoStack{end};
            obj.undoStack(end) = [];

            obj.datasets        = snap.datasets;
            obj.activeIdx       = snap.activeIdx;
            obj.mask            = snap.mask;
            obj.computedColumns = snap.computedColumns;
            if isfield(snap, 'columnRoles')
                obj.columnRoles = snap.columnRoles;
            end

            notify(obj, 'DataChanged');
            notify(obj, 'SelectionChanged');
        end

    end  % public methods

    % ════════════════════════════════════════════════════════════════════════
    %  Private helpers
    % ════════════════════════════════════════════════════════════════════════
    methods (Access = private)

        function data = ensureFields(~, data)
        %ENSUREFIELDS  Guarantee that all required unified-struct fields exist.
            if ~isfield(data, 'time'),     data.time     = [];  end
            if ~isfield(data, 'values'),   data.values   = [];  end
            if ~isfield(data, 'labels'),   data.labels   = {};  end
            if ~isfield(data, 'units'),    data.units    = {};  end
            if ~isfield(data, 'metadata'), data.metadata = struct(); end
        end

        function validateDatasetIndex(obj, idx)
        %VALIDATEDATASETINDEX  Error if idx is out of range.
            if idx < 1 || idx > numel(obj.datasets)
                error('dataWorkspace:WorkspaceModel:badIndex', ...
                    'Index %d out of range (1..%d).', idx, numel(obj.datasets));
            end
        end

    end  % private methods

end  % classdef WorkspaceModel
