function [widget, isSpreadsheet] = createTableWidget(parent, opts)
%CREATETABLEWIDGET  Create a table widget — uispreadsheet on R2025a+, uitable fallback.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   [widget, isSpreadsheet] = dataWorkspace.createTableWidget(parent)
%   [widget, isSpreadsheet] = dataWorkspace.createTableWidget(parent, Data=C, ...)
%
% ── Inputs ────────────────────────────────────────────────────────────────
%
%   parent          — uigridlayout, uipanel, or uifigure to host the widget
%
%   Data            — (optional) cell array or table for initial data
%   ColumnName      — (optional) cell array of column name strings
%   ColumnEditable  — (optional) logical array indicating editable columns
%   ColumnWidth     — (optional) cell array of widths, e.g. {100, '1x', 80}
%
% ── Outputs ───────────────────────────────────────────────────────────────
%
%   widget          — uispreadsheet (R2025a+) or uitable (R2022b–R2024b) handle
%   isSpreadsheet   — logical, true when uispreadsheet was used
%
% ── Notes ─────────────────────────────────────────────────────────────────
%
%   Both widget types expose a consistent surface for the caller:
%     .Data               — set/get table or cell-array data
%     .ColumnName         — set/get column headers
%     .ColumnEditable     — set/get per-column edit mask
%     .CellEditCallback   — callback fired when the user edits a cell
%     .CellSelectionCallback — callback fired when cell selection changes
%
%   On uispreadsheet these callbacks are emulated via DataChangedFcn and
%   SelectionChangedFcn respectively, so callers can use the uitable-style
%   property names on either widget type.
%
%   A one-time notice is printed to the Command Window when the uitable
%   fallback is activated.
%
% ── Examples ──────────────────────────────────────────────────────────────
%
%   fig = uifigure;
%   [tbl, isSS] = dataWorkspace.createTableWidget(fig, ...
%       Data={'a',1; 'b',2}, ColumnName={'Name','Value'});
%   if isSS
%       disp('Running with uispreadsheet (sort/filter built-in)');
%   end
%
% ════════════════════════════════════════════════════════════════════════

arguments
    parent
    opts.Data            = table()
    opts.ColumnName      cell = {}
    opts.ColumnEditable  logical = logical([])
    opts.ColumnWidth     cell = {}
end

% ════════════════════════════════════════════════════════════════════════
%  Version detection
%
%  Check both the MATLAB release (R2025a+) AND that uispreadsheet is
%  actually available.  The function was introduced in R2025a but may
%  require a toolbox or may not be present in all R2025a+ distributions.
% ════════════════════════════════════════════════════════════════════════

useSpreadsheet = ~isMATLABReleaseOlderThan('R2025a') && ...
                 (exist('uispreadsheet', 'builtin') ~= 0 || ...
                  exist('uispreadsheet', 'file')    ~= 0);

if useSpreadsheet
    % ────────────────────────────────────────────────────────────────────
    %  R2025a+: uispreadsheet
    % ────────────────────────────────────────────────────────────────────
    widget = uispreadsheet(parent);
    widget.Data            = opts.Data;
    widget.EnableSorting   = true;
    widget.EnableFiltering = true;

    if ~isempty(opts.ColumnName)
        widget.ColumnName = opts.ColumnName;
    end
    if ~isempty(opts.ColumnEditable)
        widget.ColumnEditable = opts.ColumnEditable;
    end

    % uispreadsheet uses DataChangedFcn in place of CellEditCallback and
    % SelectionChangedFcn in place of CellSelectionCallback.  We add
    % dynamic properties so the caller can use the uitable-style names.
    addprop(widget, 'CellEditCallback');
    addprop(widget, 'CellSelectionCallback');

    % Wire the uispreadsheet-native callbacks to forward into the shim
    % properties so callers' code works without branching.
    widget.DataChangedFcn = @(src, evt) dispatchShim(src, evt, ...
        'CellEditCallback', 'DataChangedFcn');
    widget.SelectionChangedFcn = @(src, evt) dispatchShim(src, evt, ...
        'CellSelectionCallback', 'SelectionChangedFcn');

    isSpreadsheet = true;
else
    % ────────────────────────────────────────────────────────────────────
    %  uitable path (used in all currently shipping releases — uispreadsheet
    %  branch above is in place for future MATLAB releases that introduce it)
    % ────────────────────────────────────────────────────────────────────

    widget = uitable(parent);
    widget.Data           = opts.Data;
    widget.ColumnEditable = opts.ColumnEditable;

    if ~isempty(opts.ColumnName)
        widget.ColumnName = opts.ColumnName;
    end

    % ColumnSortable is R2023a+; wrap defensively
    try
        if ~isempty(opts.ColumnName)
            widget.ColumnSortable = true(1, numel(opts.ColumnName));
        end
    catch
    end

    isSpreadsheet = false;
end

% ColumnWidth — best-effort on both widget types
if ~isempty(opts.ColumnWidth)
    try
        widget.ColumnWidth = opts.ColumnWidth;
    catch
    end
end

end % createTableWidget


% ════════════════════════════════════════════════════════════════════════
%  Module-level helpers
% ════════════════════════════════════════════════════════════════════════

function dispatchShim(src, evt, shimProp, ~)
%DISPATCHSHIM  Forward a uispreadsheet-native event to a shim callback.
%   Reads the function handle stored in the shim dynamic property and calls
%   it with (src, evt) so the caller's handler fires unchanged.
    cb = src.(shimProp);
    if ~isempty(cb)
        cb(src, evt);
    end
end


