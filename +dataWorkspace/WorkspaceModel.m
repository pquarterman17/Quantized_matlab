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

    end  % private methods

end  % classdef WorkspaceModel
