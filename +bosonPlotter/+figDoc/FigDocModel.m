classdef FigDocModel < handle
%FIGDOCMODEL  Persistent figure document state for a BosonPlotter dataset.
%
%   Owns all visual decisions (axis limits, legend config, annotations,
%   per-trace styles, export prefs). Survives data re-renders. Export reads
%   from this model to guarantee WYSIWYG.
%
%   Usage:
%     m = bosonPlotter.figDoc.FigDocModel();
%     m.xLim = [0 100];
%     m.legendLocation = 'northeast';
%     s = m.snapshot();    % serialize for session save
%     m2 = bosonPlotter.figDoc.FigDocModel();
%     m2.restore(s);       % reload from session

    properties
        % ── Axes ─────────────────────────────────────────────────────────
        xLim     = 'auto'       % [min max] or 'auto'
        yLim     = 'auto'       % [min max] or 'auto'
        xScale   = 'linear'     % 'linear' | 'log'
        yScale   = 'linear'     % 'linear' | 'log'
        xLabel   = ""           % string
        yLabel   = ""           % string
        fontSize = 11           % base font size (pt)
        fontName = "Arial"      % font family
        gridOn   = false        % major grid lines
        minorTicks = false      % minor tick marks
        tickDir  = 'out'        % 'in' | 'out' | 'both'
        boxOn    = false        % axes box

        % ── Legend ───────────────────────────────────────────────────────
        legendVisible     = true
        legendLocation    = 'best'       % MATLAB location string or [x y w h]
        legendOrientation = 'vertical'   % 'vertical' | 'horizontal'
        legendFontSize    = 10
        legendColumns     = 1            % number of columns (R2024b+)

        % ── Layout ──────────────────────────────────────────────────────
        margins = [0.13 0.05 0.05 0.11]  % [left right top bottom] normalized

        % ── Annotations ─────────────────────────────────────────────────
        annotations = {}    % cell array of annotation structs:
                            %   .type = 'text' | 'arrow' | 'bracket'
                            %   .position = [x y] (data coords) or [x y dx dy] for arrow
                            %   .text = string
                            %   .style = struct (fontSize, color, lineWidth, ...)

        % ── Per-trace style overrides ───────────────────────────────────
        traceStyles = {}    % cell array (one per overlay dataset) of structs:
                            %   .color, .lineWidth, .lineStyle, .marker,
                            %   .markerSize, .displayName

        % ── Second Y-axis ───────────────────────────────────────────────
        traceYAxis = {}     % cell array of 'left'|'right' per trace (empty = all left)
        y2Lim    = 'auto'   % right-Y [min max] or 'auto'
        y2Scale  = 'linear' % right-Y 'linear' | 'log'
        y2Label  = ""       % right-Y axis label

        % ── Export ──────────────────────────────────────────────────────
        lastExportProfile = 'powerpoint'  % 'powerpoint' | 'aps' | 'nature' | 'custom'
    end

    properties (SetAccess = private)
        dirty = false   % true when model changed since last applyToAxes
        undoStack = {}  % cell array of snapshot structs (max 10)
    end

    properties (Constant, Hidden)
        UNDO_CAP = 10
    end

    methods
        function obj = FigDocModel()
        end

        function reset(obj)
        %RESET  Restore all properties to factory defaults.
            m = bosonPlotter.figDoc.FigDocModel();
            props = properties(m);
            for k = 1:numel(props)
                p = props{k};
                if strcmp(p, 'dirty'), continue; end
                obj.(p) = m.(p);
            end
            obj.dirty = true;
        end

        function s = snapshot(obj)
        %SNAPSHOT  Serialize model to a plain struct for session save.
            props = properties(obj);
            s = struct();
            skip = {'dirty', 'undoStack'};
            for k = 1:numel(props)
                p = props{k};
                if ismember(p, skip), continue; end
                s.(p) = obj.(p);
            end
        end

        function restore(obj, s)
        %RESTORE  Load model state from a snapshot struct.
            if ~isstruct(s), return; end
            props = properties(obj);
            skip = {'dirty', 'undoStack'};
            for k = 1:numel(props)
                p = props{k};
                if ismember(p, skip), continue; end
                if isfield(s, p)
                    obj.(p) = s.(p);
                end
            end
            obj.dirty = true;
        end

        function markDirty(obj)
            obj.dirty = true;
        end

        function markClean(obj)
            obj.dirty = false;
        end

        function tf = hasManualLimits(obj)
        %HASMANUALLIMITS  True if either axis has user-set limits.
            tf = ~isequal(obj.xLim, 'auto') || ~isequal(obj.yLim, 'auto');
        end

        function addAnnotation(obj, annot)
        %ADDANNOTATION  Append an annotation struct to the model.
            obj.annotations{end+1} = annot;
            obj.dirty = true;
        end

        function removeAnnotation(obj, idx)
        %REMOVEANNOTATION  Remove annotation by index.
            if idx >= 1 && idx <= numel(obj.annotations)
                obj.annotations(idx) = [];
                obj.dirty = true;
            end
        end

        function setTraceStyle(obj, idx, field, value)
        %SETTRACESTYLE  Set a style override for trace at index idx.
            while numel(obj.traceStyles) < idx
                obj.traceStyles{end+1} = struct();
            end
            obj.traceStyles{idx}.(field) = value;
            obj.dirty = true;
        end

        function setTraceYAxis(obj, idx, side)
        %SETTRACEYAXIS  Assign trace to 'left' or 'right' Y-axis.
            while numel(obj.traceYAxis) < idx
                obj.traceYAxis{end+1} = 'left';
            end
            obj.traceYAxis{idx} = side;
            obj.dirty = true;
        end

        function tf = hasRightAxis(obj)
            tf = any(strcmp(obj.traceYAxis, 'right'));
        end

        function pushUndo(obj)
        %PUSHUNDO  Save current state to the undo stack (before a change).
            s = obj.snapshot();
            obj.undoStack{end+1} = s;
            if numel(obj.undoStack) > obj.UNDO_CAP
                obj.undoStack(1) = [];
            end
        end

        function tf = canUndo(obj)
            tf = ~isempty(obj.undoStack);
        end

        function undo(obj)
        %UNDO  Restore the most recent undo snapshot.
            if isempty(obj.undoStack), return; end
            s = obj.undoStack{end};
            obj.undoStack(end) = [];
            obj.restore(s);
        end

        function clearUndo(obj)
            obj.undoStack = {};
        end
    end
end
