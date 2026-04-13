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
        %  Computed column management
        % ════════════════════════════════════════════════════════════════════════

        function addComputedColumn(obj, dsIdx, name, expression, unit)
        %ADDCOMPUTEDCOLUMN  Evaluate a formula and append a computed column.
        %
        %   model.addComputedColumn(dsIdx, name, expression, unit)
        %
        %   Inputs:
        %     dsIdx      — 1-based dataset index
        %     name       — display name for the new column (string)
        %     expression — formula string, e.g. 'col("Field") / 79.5775'
        %     unit       — unit string (optional, default '')
        %
        %   The formula is evaluated immediately; the result is stored in
        %   computedColumns{dsIdx}.  Fires DataChanged.
            arguments
                obj        (1,1) dataWorkspace.WorkspaceModel
                dsIdx      (1,1) double {mustBePositive, mustBeInteger}
                name       (1,:) char
                expression (1,:) char
                unit       (1,:) char = ''
            end

            obj.validateDatasetIndex(dsIdx);

            % Check for duplicate computed column name
            existing = obj.computedColumns{dsIdx};
            for k = 1:numel(existing)
                if strcmpi(existing{k}.name, name)
                    error('dataWorkspace:WorkspaceModel:duplicateComputedColumn', ...
                        'A computed column named "%s" already exists for dataset %d.', ...
                        name, dsIdx);
                end
            end

            % Guard: new column must not reference itself (it can't exist yet,
            % but names of existing computed columns in the chain could cycle)
            existingNames = cellfun(@(c) c.name, existing, 'UniformOutput', false);
            if dataWorkspace.FormulaEngine.hasCircularRef(string(expression), [{name}, existingNames])
                error('dataWorkspace:WorkspaceModel:circularRef', ...
                    'Formula for "%s" would create a circular reference.', name);
            end

            % Evaluate the formula now
            data   = obj.getData(dsIdx);
            values = dataWorkspace.FormulaEngine.evaluate(string(expression), data);

            entry.name       = name;
            entry.expression = expression;
            entry.values     = values(:);
            entry.unit       = unit;

            obj.computedColumns{dsIdx}{end+1} = entry;
            notify(obj, 'DataChanged');
        end

        function removeComputedColumn(obj, dsIdx, colName)
        %REMOVECOMPUTEDCOLUMN  Remove a computed column by name and fire DataChanged.
        %
        %   model.removeComputedColumn(dsIdx, colName)
        %
        %   Inputs:
        %     dsIdx   — 1-based dataset index
        %     colName — name of the computed column to remove
            arguments
                obj     (1,1) dataWorkspace.WorkspaceModel
                dsIdx   (1,1) double {mustBePositive, mustBeInteger}
                colName (1,:) char
            end

            obj.validateDatasetIndex(dsIdx);
            cols = obj.computedColumns{dsIdx};
            idx  = [];
            for k = 1:numel(cols)
                if strcmpi(cols{k}.name, colName)
                    idx = k;
                    break;
                end
            end
            if isempty(idx)
                error('dataWorkspace:WorkspaceModel:unknownComputedColumn', ...
                    'No computed column named "%s" in dataset %d.', colName, dsIdx);
            end
            obj.computedColumns{dsIdx}(idx) = [];
            notify(obj, 'DataChanged');
        end

        function recomputeColumns(obj, dsIdx)
        %RECOMPUTECOLUMNS  Re-evaluate all computed columns for a dataset.
        %
        %   model.recomputeColumns(dsIdx)
        %
        %   Call this after the underlying data changes.  Fires DataChanged
        %   once at the end.  Columns that fail re-evaluation are left with
        %   their previous values and a warning is issued.
            arguments
                obj   (1,1) dataWorkspace.WorkspaceModel
                dsIdx (1,1) double {mustBePositive, mustBeInteger}
            end

            obj.validateDatasetIndex(dsIdx);
            data = obj.getData(dsIdx);
            cols = obj.computedColumns{dsIdx};
            for k = 1:numel(cols)
                try
                    newVals = dataWorkspace.FormulaEngine.evaluate( ...
                        string(cols{k}.expression), data);
                    obj.computedColumns{dsIdx}{k}.values = newVals(:);
                catch ME
                    warning('dataWorkspace:WorkspaceModel:recomputeFailed', ...
                        'Failed to recompute column "%s": %s', cols{k}.name, ME.message);
                end
            end
            notify(obj, 'DataChanged');
        end

        function cols = getComputedColumns(obj, dsIdx)
        %GETCOMPUTEDCOLUMNS  Return the computed column cell array for a dataset.
        %
        %   cols = model.getComputedColumns(dsIdx)
        %
        %   Outputs:
        %     cols — cell array of structs with fields:
        %            .name, .expression, .values ([Nx1]), .unit
            arguments
                obj   (1,1) dataWorkspace.WorkspaceModel
                dsIdx (1,1) double {mustBePositive, mustBeInteger}
            end
            obj.validateDatasetIndex(dsIdx);
            cols = obj.computedColumns{dsIdx};
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

        % ════════════════════════════════════════════════════════════════════════
        %  Session persistence — snapshot save / restore
        % ════════════════════════════════════════════════════════════════════════

        function snap = createSnapshot(obj)
        %CREATESNAPSHOT  Return a struct capturing all serializable model state.
        %
        %   snap = model.createSnapshot()
        %
        %   Outputs:
        %     snap — struct with fields:
        %              .datasets        — cell array of unified data structs
        %              .mask            — cell array of logical row masks
        %              .columnRoles     — cell array of ColumnRoles objects
        %              .computedColumns — cell array of computed column arrays
        %              .activeIdx       — current active dataset index
        %              .timestamp       — datetime of snapshot creation
        %              .version         — format version string (for future compat)
        %
        %   The snapshot can be passed to save() then later to restoreFromSnapshot().
            snap.datasets        = obj.datasets;
            snap.mask            = obj.mask;
            snap.columnRoles     = obj.columnRoles;
            snap.computedColumns = obj.computedColumns;
            snap.activeIdx       = obj.activeIdx;
            snap.timestamp       = datetime('now');
            snap.version         = '1.0';
        end

        function restoreFromSnapshot(obj, snap)
        %RESTOREFROMSNAPSHOT  Replace all model state from a snapshot struct.
        %
        %   model.restoreFromSnapshot(snap)
        %
        %   Inputs:
        %     snap — struct previously produced by createSnapshot(), or a struct
        %            loaded from a .dwk file (which is a .mat with the same fields)
        %
        %   Fires DataChanged and SelectionChanged after restore.  Any outstanding
        %   listeners see the new state immediately.
            arguments
                obj  (1,1) dataWorkspace.WorkspaceModel
                snap (1,1) struct
            end

            % Required fields — error early with a clear message
            requiredFields = {'datasets', 'mask', 'columnRoles', ...
                              'computedColumns', 'activeIdx'};
            for k = 1:numel(requiredFields)
                if ~isfield(snap, requiredFields{k})
                    error('dataWorkspace:WorkspaceModel:badSnapshot', ...
                        'Snapshot is missing required field "%s".', requiredFields{k});
                end
            end

            obj.datasets        = snap.datasets;
            obj.mask            = snap.mask;
            obj.columnRoles     = snap.columnRoles;
            obj.computedColumns = snap.computedColumns;
            obj.activeIdx       = snap.activeIdx;
            obj.undoStack       = {};  % do not restore undo history

            notify(obj, 'DataChanged');
            notify(obj, 'SelectionChanged');
        end

        % ════════════════════════════════════════════════════════════════════════
        %  Multi-dataset operations
        % ════════════════════════════════════════════════════════════════════════

        function result = datasetMath(obj, idxA, op, idxB)
        %DATASETMATH  Apply element-wise arithmetic between two datasets.
        %
        %   result = model.datasetMath(idxA, op, idxB)
        %
        %   Inputs:
        %     idxA — 1-based index of the first (reference) dataset
        %     op   — operation string: '+', '-', '*', '/', 'ratio'
        %     idxB — 1-based index of the second dataset
        %
        %   Outputs:
        %     result — new unified data struct; NOT added to the model.
        %              Call model.addDataset(result, ...) to register it.
        %
        %   If row counts differ, dataset B is interpolated onto dataset A's
        %   time grid using interp1 (linear, extrap='extrap').
        %   Operation applies element-wise to all value columns.
        %   If the datasets have different numbers of value columns the
        %   operation is applied only to the minimum of the two column counts.
            arguments
                obj  (1,1) dataWorkspace.WorkspaceModel
                idxA (1,1) double {mustBePositive, mustBeInteger}
                op   (1,:) char
                idxB (1,1) double {mustBePositive, mustBeInteger}
            end

            obj.validateDatasetIndex(idxA);
            obj.validateDatasetIndex(idxB);

            validOps = {'+', '-', '*', '/', 'ratio'};
            if ~ismember(op, validOps)
                error('dataWorkspace:WorkspaceModel:badOp', ...
                    'op must be one of: %s', strjoin(validOps, ', '));
            end

            dsA = obj.getData(idxA);
            dsB = obj.getData(idxB);

            xA = dsA.time(:);
            xB = dsB.time(:);
            vA = dsA.values;
            vB = dsB.values;

            % Interpolate B onto A's X grid when row counts differ
            if numel(xA) ~= numel(xB) || ~isequal(xA, xB)
                nCols = size(vB, 2);
                vBi = zeros(numel(xA), nCols);
                for c = 1:nCols
                    vBi(:, c) = interp1(xB, vB(:, c), xA, 'linear', 'extrap');
                end
                vB = vBi;
            end

            % Operate on the common number of columns
            nCols = min(size(vA, 2), size(vB, 2));
            vA = vA(:, 1:nCols);
            vB = vB(:, 1:nCols);

            switch op
                case '+'
                    vResult = vA + vB;
                    opStr = 'plus';
                case '-'
                    vResult = vA - vB;
                    opStr = 'minus';
                case '*'
                    vResult = vA .* vB;
                    opStr = 'times';
                case '/'
                    vResult = vA ./ vB;
                    opStr = 'div';
                case 'ratio'
                    vResult = vA ./ vB;
                    opStr = 'ratio';
            end

            % Build labels: "LabelA op LabelB"
            labA = dsA.labels(1:nCols);
            labB = dsB.labels(1:nCols);
            newLabels = cell(1, nCols);
            for c = 1:nCols
                newLabels{c} = sprintf('%s %s %s', labA{c}, opStr, labB{c});
            end
            newUnits = dsA.units(1:nCols);

            % Name the result datasets
            nameA = obj.getDatasetName(idxA);
            nameB = obj.getDatasetName(idxB);
            srcStr = sprintf('%s %s %s', nameA, op, nameB);

            result = parser.createDataStruct(xA, vResult, ...
                'labels',   newLabels, ...
                'units',    newUnits, ...
                'metadata', struct('source', srcStr, 'parserName', 'datasetMath'));
        end

        function result = mergeDatasets(obj, idxA, idxB)
        %MERGEDATASETS  Horizontally concatenate Y columns from two datasets.
        %
        %   result = model.mergeDatasets(idxA, idxB)
        %
        %   Inputs:
        %     idxA — 1-based index of the first (reference) dataset
        %     idxB — 1-based index of the second dataset
        %
        %   Outputs:
        %     result — new unified data struct; NOT added to the model.
        %
        %   Dataset B's Y columns are interpolated onto dataset A's time grid.
        %   Result has all Y columns from A followed by all from B.
            arguments
                obj  (1,1) dataWorkspace.WorkspaceModel
                idxA (1,1) double {mustBePositive, mustBeInteger}
                idxB (1,1) double {mustBePositive, mustBeInteger}
            end

            obj.validateDatasetIndex(idxA);
            obj.validateDatasetIndex(idxB);

            dsA = obj.getData(idxA);
            dsB = obj.getData(idxB);

            xA = dsA.time(:);
            xB = dsB.time(:);
            vB = dsB.values;

            % Interpolate B onto A's X grid
            nColsB = size(vB, 2);
            vBi = zeros(numel(xA), nColsB);
            for c = 1:nColsB
                vBi(:, c) = interp1(xB, vB(:, c), xA, 'linear', 'extrap');
            end

            vMerged    = [dsA.values, vBi];
            labMerged  = [dsA.labels(:)', dsB.labels(:)'];
            unitMerged = [dsA.units(:)',  dsB.units(:)'];

            nameA = obj.getDatasetName(idxA);
            nameB = obj.getDatasetName(idxB);
            srcStr = sprintf('merge(%s, %s)', nameA, nameB);

            result = parser.createDataStruct(xA, vMerged, ...
                'labels',   labMerged, ...
                'units',    unitMerged, ...
                'metadata', struct('source', srcStr, 'parserName', 'mergeDatasets'));
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

        function name = getDatasetName(obj, idx)
        %GETDATASETNAME  Return a short display name for dataset idx.
            ds = obj.datasets{idx};
            if isfield(ds, 'metadata') && isfield(ds.metadata, 'source') ...
                    && ~isempty(ds.metadata.source)
                [~, nm, ext] = fileparts(ds.metadata.source);
                name = [nm ext];
            else
                name = sprintf('Dataset%d', idx);
            end
        end

    end  % private methods

end  % classdef WorkspaceModel
