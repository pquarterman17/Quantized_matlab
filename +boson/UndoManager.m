classdef UndoManager < handle
%UNDOMANAGER  Unlimited undo/redo stack for Boson operations.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   mgr = boson.UndoManager()
%   mgr = boson.UndoManager(MaxSize=50)
%
% ── Inputs ────────────────────────────────────────────────────────────────
%
%   MaxSize   (optional) Maximum stack depth; oldest entries are dropped
%             when the stack exceeds this limit.  Default: 50.
%
% ── Usage ─────────────────────────────────────────────────────────────────
%
%   Each entry is a struct with fields:
%     .type   — string tag for the operation ('correction', 'peak_edit', …)
%     .label  — human-readable description shown in tooltips
%     .undo   — function handle: restores state before the operation
%     .redo   — function handle: re-applies the operation
%
%   Callers capture the needed state in closures:
%
%     prevState = captureState();
%     % ... perform operation ...
%     newState = captureState();
%     mgr.push(struct( ...
%         'type',  'correction', ...
%         'label', 'Apply Corrections', ...
%         'undo',  @() restoreState(prevState), ...
%         'redo',  @() restoreState(newState)));
%
% ── Examples ──────────────────────────────────────────────────────────────
%
%   mgr = boson.UndoManager(MaxSize=10);
%   mgr.push(struct('type','test','label','Op 1','undo',@() disp('undo1'),'redo',@() disp('redo1')));
%   mgr.canUndo()   % true
%   mgr.undoLabel() % 'Undo: Op 1'
%   mgr.undo();
%   mgr.canRedo()   % true
%
% ════════════════════════════════════════════════════════════════════════

    properties (SetAccess = private)
        stack     cell    % cell array of undo entry structs (read-only externally)
        stackPos  double  % index of the last committed entry (0 = empty)
        maxSize   double  % maximum stack depth
    end

    methods

        function obj = UndoManager(options)
        %UNDOMANAGER  Construct a new UndoManager.
        %
        %   mgr = boson.UndoManager()
        %   mgr = boson.UndoManager(MaxSize=100)
            arguments
                options.MaxSize (1,1) double {mustBePositive, mustBeInteger} = 50
            end
            obj.stack    = {};
            obj.stackPos = 0;
            obj.maxSize  = options.MaxSize;
        end

        function push(obj, entry)
        %PUSH  Record a new undoable operation.
        %
        %   mgr.push(entry)
        %
        %   entry — struct with fields .type, .label, .undo, .redo
        %
        %   Any redo entries beyond the current position are discarded
        %   (standard branching undo behaviour).  When the stack exceeds
        %   MaxSize the oldest entry is dropped.

            % Discard redo branch
            obj.stack    = obj.stack(1:obj.stackPos);

            % Append new entry
            obj.stack{end+1} = entry;
            obj.stackPos     = numel(obj.stack);

            % Cap at maxSize — drop oldest entry
            if numel(obj.stack) > obj.maxSize
                obj.stack    = obj.stack(end - obj.maxSize + 1 : end);
                obj.stackPos = numel(obj.stack);
            end
        end

        function entry = undo(obj)
        %UNDO  Execute the current entry's .undo function and step back.
        %
        %   entry = mgr.undo()
        %
        %   Returns the entry that was undone, or [] if the stack is empty.

            if ~obj.canUndo()
                entry = [];
                return;
            end
            entry = obj.stack{obj.stackPos};
            entry.undo();
            obj.stackPos = obj.stackPos - 1;
        end

        function entry = redo(obj)
        %REDO  Execute the next entry's .redo function and step forward.
        %
        %   entry = mgr.redo()
        %
        %   Returns the entry that was redone, or [] if at the head.

            if ~obj.canRedo()
                entry = [];
                return;
            end
            obj.stackPos = obj.stackPos + 1;
            entry = obj.stack{obj.stackPos};
            entry.redo();
        end

        function tf = canUndo(obj)
        %CANUNDO  True when there is at least one entry to undo.
            tf = obj.stackPos > 0;
        end

        function tf = canRedo(obj)
        %CANREDO  True when there is at least one entry to redo.
            tf = obj.stackPos < numel(obj.stack);
        end

        function label = undoLabel(obj)
        %UNDOLABEL  Human-readable label for the next undo action.
        %
        %   Returns e.g. 'Undo: Apply Corrections', or 'Nothing to undo'.
            if obj.canUndo()
                label = ['Undo: ' obj.stack{obj.stackPos}.label];
            else
                label = 'Nothing to undo';
            end
        end

        function label = redoLabel(obj)
        %REDOLABEL  Human-readable label for the next redo action.
        %
        %   Returns e.g. 'Redo: Apply Corrections', or 'Nothing to redo'.
            if obj.canRedo()
                label = ['Redo: ' obj.stack{obj.stackPos + 1}.label];
            else
                label = 'Nothing to redo';
            end
        end

        function clear(obj)
        %CLEAR  Discard all undo and redo history.
            obj.stack    = {};
            obj.stackPos = 0;
        end

        function n = depth(obj)
        %DEPTH  Number of undo entries currently available (not counting redo).
            n = obj.stackPos;
        end

    end % methods

end % UndoManager
