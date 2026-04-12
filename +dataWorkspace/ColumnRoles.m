classdef ColumnRoles
%COLUMNROLES  Lightweight column metadata for display order and X/Y grouping.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   roles = dataWorkspace.ColumnRoles(numCols)
%
% ── Overview ──────────────────────────────────────────────────────────────
%
%   ColumnRoles is a VALUE class (copied on assignment).  One instance is
%   stored per dataset in WorkspaceModel.columnRoles.
%
%   Column index conventions:
%     0       — refers to the data struct's .time vector (the X column)
%     1..M    — refers to .values(:, idx) (the Y columns)
%
%   Default state (one X group, no reordering, nothing skipped) is fully
%   backward-compatible with existing code that treats .time as the only X.
%
% ── Inputs ────────────────────────────────────────────────────────────────
%
%   numCols — number of value columns (= size(data.values, 2))
%
% ── Properties ────────────────────────────────────────────────────────────
%
%   displayOrder — [1×N] index permutation for visual column order
%   xGroups      — struct array; each element has .xCol and .yCols
%   skipped      — [1×N] logical; true = column is not plotted
%
% ── Examples ──────────────────────────────────────────────────────────────
%
%   roles = dataWorkspace.ColumnRoles(3);
%   roles = roles.addXGroup(1, [2 3]);   % col 1 is X for cols 2 and 3
%   groups = roles.getPlotGroups(dataStruct);
%
% ════════════════════════════════════════════════════════════════════════

    % ════════════════════════════════════════════════════════════════════════
    %  Properties
    % ════════════════════════════════════════════════════════════════════════
    properties
        displayOrder  (1,:) double   % visual column permutation
        xGroups       (1,:) struct   % struct array with .xCol and .yCols
        skipped       (1,:) logical  % true = column excluded from plots
    end

    % ════════════════════════════════════════════════════════════════════════
    %  Constructor
    % ════════════════════════════════════════════════════════════════════════
    methods

        function obj = ColumnRoles(numCols)
        %COLUMNROLES  Create default roles for N value columns.
        %
        %   roles = dataWorkspace.ColumnRoles(numCols)
        %
        %   Inputs:
        %     numCols — number of .values columns (non-negative integer)
            arguments
                numCols (1,1) double {mustBeNonnegative, mustBeInteger}
            end

            obj.displayOrder = 1:numCols;
            obj.skipped      = false(1, numCols);

            % Default: one group with xCol=0 (.time) and all value columns
            defaultGroup.xCol  = 0;
            defaultGroup.yCols = 1:numCols;
            obj.xGroups = defaultGroup;
        end

        % ════════════════════════════════════════════════════════════════════════
        %  Public methods
        % ════════════════════════════════════════════════════════════════════════

        function obj = addXGroup(obj, xColIdx, yColIndices)
        %ADDXGROUP  Add a new X→Y grouping.
        %
        %   roles = roles.addXGroup(xColIdx, yColIndices)
        %
        %   Inputs:
        %     xColIdx     — column index for X axis (0 = .time, 1..M = .values)
        %     yColIndices — [1×K] column indices for Y axes
        %
        %   Returns a modified copy (value class semantics).
            arguments
                obj         (1,1) dataWorkspace.ColumnRoles
                xColIdx     (1,1) double {mustBeNonnegative, mustBeInteger}
                yColIndices (1,:) double {mustBePositive}
            end

            newGroup.xCol  = xColIdx;
            newGroup.yCols = yColIndices(:)';
            obj.xGroups(end+1) = newGroup;
        end

        function obj = removeXGroup(obj, groupIdx)
        %REMOVEXGROUP  Remove an X grouping by index.
        %
        %   roles = roles.removeXGroup(groupIdx)
        %
        %   Inputs:
        %     groupIdx — 1-based index into xGroups array
        %
        %   Returns a modified copy.
            arguments
                obj      (1,1) dataWorkspace.ColumnRoles
                groupIdx (1,1) double {mustBePositive, mustBeInteger}
            end

            n = numel(obj.xGroups);
            if groupIdx > n
                error('dataWorkspace:ColumnRoles:badGroupIndex', ...
                    'Group index %d out of range (1..%d).', groupIdx, n);
            end

            obj.xGroups(groupIdx) = [];
        end

        function obj = reorder(obj, newOrder)
        %REORDER  Set the visual display order of value columns.
        %
        %   roles = roles.reorder(newOrder)
        %
        %   Inputs:
        %     newOrder — [1×N] permutation of 1:numColumns(roles)
        %
        %   Validates that newOrder is a permutation of 1:N before storing.
        %   Returns a modified copy.
            arguments
                obj      (1,1) dataWorkspace.ColumnRoles
                newOrder (1,:) double {mustBePositive, mustBeInteger}
            end

            n = obj.numColumns();
            if numel(newOrder) ~= n
                error('dataWorkspace:ColumnRoles:badOrderLength', ...
                    'newOrder has %d elements but there are %d columns.', ...
                    numel(newOrder), n);
            end
            if ~isequal(sort(newOrder), 1:n)
                error('dataWorkspace:ColumnRoles:notAPermutation', ...
                    'newOrder must be a permutation of 1:%d.', n);
            end

            obj.displayOrder = newOrder;
        end

        function groups = getPlotGroups(obj, dataStruct)
        %GETPLOTGROUPS  Extract plot-ready data groups from a data struct.
        %
        %   groups = roles.getPlotGroups(dataStruct)
        %
        %   Inputs:
        %     dataStruct — unified data struct with .time, .values, .labels, .units
        %
        %   Outputs:
        %     groups — {1×G} cell array of structs, each with:
        %       .xData  — [N×1] vector (from .time or .values(:, xCol))
        %       .yData  — [N×K] matrix of the Y columns
        %       .labels — {1×K} label strings for Y columns
        %       .units  — {1×K} unit strings for Y columns
        %
        %   Skipped columns are excluded from their respective groups.
        %   Groups with no non-skipped Y columns are omitted from output.
            arguments
                obj        (1,1) dataWorkspace.ColumnRoles
                dataStruct (1,1) struct
            end

            groups = {};
            for g = 1:numel(obj.xGroups)
                grp = obj.xGroups(g);

                % Resolve X data
                if grp.xCol == 0
                    xData = dataStruct.time(:);
                else
                    xData = dataStruct.values(:, grp.xCol);
                end

                % Filter skipped columns from yCols
                activeCols = grp.yCols(~obj.skipped(grp.yCols));
                if isempty(activeCols)
                    continue;
                end

                yData  = dataStruct.values(:, activeCols);
                lbls   = dataStruct.labels(activeCols);
                units  = dataStruct.units(activeCols);

                outGroup.xData  = xData;
                outGroup.yData  = yData;
                outGroup.labels = lbls;
                outGroup.units  = units;

                groups{end+1} = outGroup; %#ok<AGROW>
            end
        end

        function obj = setSkipped(obj, colIndices, tf)
        %SETSKIPPED  Mark value columns as skipped (not plotted) or active.
        %
        %   roles = roles.setSkipped(colIndices, tf)
        %
        %   Inputs:
        %     colIndices — [1×K] 1-based column indices
        %     tf         — scalar logical (true = skip, false = include)
        %
        %   Returns a modified copy.
            arguments
                obj        (1,1) dataWorkspace.ColumnRoles
                colIndices (1,:) double {mustBePositive, mustBeInteger}
                tf         (1,1) logical
            end

            n = obj.numColumns();
            if any(colIndices > n)
                error('dataWorkspace:ColumnRoles:badColIndex', ...
                    'Column index exceeds total column count (%d).', n);
            end

            obj.skipped(colIndices) = tf;
        end

        function n = numColumns(obj)
        %NUMCOLUMNS  Return the number of value columns.
        %
        %   n = roles.numColumns()
            n = numel(obj.displayOrder);
        end

    end  % methods

end  % classdef ColumnRoles
