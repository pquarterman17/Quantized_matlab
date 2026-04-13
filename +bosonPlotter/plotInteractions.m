function plotInteractions(ax, fig, callbacks)
%PLOTINTERACTIONS  Wire double-click-to-edit on axis labels and context
%   menus on data line objects after each renderPlot call.
%
%   Syntax
%     bosonPlotter.plotInteractions(ax, fig, callbacks)
%
%   Inputs
%     ax        — uiaxes handle (main plot axes)
%     fig       — uifigure handle
%     callbacks — struct of function handles from BosonPlotter:
%       .getDatasets     @() -> cell array of dataset structs
%       .getActiveIdx    @() -> scalar int (1-based, 0 = none)
%       .setActiveIdx    @(idx) -> navigate to dataset idx
%       .drawToAxes      @() -> rerender the main axes
%       .setCustomXLabel @(str) -> update the X label edit field
%       .setCustomYLabel @(str) -> update the Y label edit field
%       .setCustomTitle  @(str) -> update the title edit field
%       .onAutoLimits    @() -> reset axis limits to auto
%       .isContextMenuSupported  logical (R2023b+ feature guard)
%
%   Outputs
%     (none) — all effects are wired as ButtonDownFcn on text objects
%     and ContextMenu on line handles.
%
%   Notes
%     All handlers fire ONLY on double-click (SelectionType == 'open') or
%     right-click context menus.  They are no-ops during cursor, zoom, and
%     pan modes (guarded by appData.cursorActive and zoomStartPt checks
%     which are performed at the BosonPlotter level before reaching here).
%
%     This function is designed to be called from drawToAxes() after each
%     successful renderPlot.  It attaches to whatever text and line
%     objects currently exist in ax — a fresh call replaces any stale
%     handles from the previous render.
%
%   Examples
%     bosonPlotter.plotInteractions(ax, fig, cb)

% ════════════════════════════════════════════════════════════════════════════

    % ── Axis label double-click handlers ─────────────────────────────────
    tryWireLabelEdit(ax.XLabel, 'X-Axis Label', callbacks.setCustomXLabel, fig);
    tryWireLabelEdit(ax.YLabel, 'Y-Axis Label', callbacks.setCustomYLabel, fig);
    tryWireLabelEdit(ax.Title,  'Plot Title',   callbacks.setCustomTitle,  fig);

    % ── Context menus and double-click on data lines ──────────────────────
    if ~callbacks.isContextMenuSupported
        return;   % R2022b: ContextMenu on uiaxes children not supported
    end

    lineObjs = findobj(ax, 'Type', 'line', '-not', 'HandleVisibility', 'off');
    datasets = callbacks.getDatasets();
    nDS      = numel(datasets);
    nLines   = numel(lineObjs);

    for li = 1:nLines
        lh = lineObjs(li);

        % Try to map this line back to a dataset index by matching UserData
        % or position in the line list.  Fall back to nearest-dataset logic.
        dsIdx = resolveDatasetForLine(lh, li, nDS, nLines);

        % Build a context menu for this line
        cm = uicontextmenu(fig);

        if dsIdx > 0
            capturedIdx = dsIdx;
            uimenu(cm, 'Text', 'Go to this dataset', ...
                'MenuSelectedFcn', @(~,~) callbacks.setActiveIdx(capturedIdx));
        end

        uimenu(cm, 'Text', 'Hide this trace', ...
            'MenuSelectedFcn', @(~,~) hideTrace(lh));
        uimenu(cm, 'Text', 'Change color...', ...
            'MenuSelectedFcn', @(~,~) changeLineColor(lh));
        uimenu(cm, 'Text', 'Copy data to clipboard', ...
            'MenuSelectedFcn', @(~,~) copyTraceData(lh));

        lh.ContextMenu = cm;

        % Double-click on a line: open color/style editor
        lh.ButtonDownFcn = @(src,~) onLineDoubleClick(src, fig);
    end
end

% ════════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════════

function tryWireLabelEdit(labelObj, dlgTitle, setCb, fig)
%TRYWIRELABELEDIT  Attach a double-click edit handler to a text/label object.
    if isempty(labelObj) || ~isgraphics(labelObj), return; end
    try
        labelObj.ButtonDownFcn = @(~,~) onLabelDoubleClick(labelObj, dlgTitle, setCb, fig);
    catch
        % Silently skip — some MATLAB versions disallow ButtonDownFcn on axes labels
    end
end

function onLabelDoubleClick(labelObj, dlgTitle, setCb, fig)
%ONLABELDOUBLECLICK  Open an edit dialog when the user double-clicks a label.
    if ~strcmp(fig.SelectionType, 'open'), return; end   % only double-click

    currentStr = '';
    try
        currentStr = labelObj.String;
        if iscell(currentStr), currentStr = strjoin(currentStr, ' '); end
    catch
    end

    answer = inputdlg(dlgTitle, 'Edit Label', [1 52], {currentStr});
    if isempty(answer), return; end   % user cancelled

    newStr = strtrim(answer{1});
    try
        setCb(newStr);
    catch ME
        warning('bosonPlotter:plotInteractions:labelEdit', ...
            'Could not update label: %s', ME.message);
    end
end

function onLineDoubleClick(lh, fig)
%ONLINEDOUBLECLICK  Open a quick color/style editor on double-click of a data line.
    if ~strcmp(fig.SelectionType, 'open'), return; end
    changeLineColor(lh);
end

function changeLineColor(lh)
%CHANGELINECOLOR  Open a color picker and apply the chosen color to a line.
    if ~isgraphics(lh), return; end
    try
        currentColor = lh.Color;
        newColor = uisetcolor(currentColor, 'Line Color');
        if isempty(newColor) || isequal(newColor, 0)
            return;  % user cancelled
        end
        lh.Color = newColor;
        if isprop(lh, 'MarkerEdgeColor') && ...
                ~strcmpi(char(lh.MarkerEdgeColor), 'auto') && ...
                ~strcmpi(char(lh.MarkerEdgeColor), 'none')
            lh.MarkerEdgeColor = newColor;
        end
    catch ME
        warning('bosonPlotter:plotInteractions:changeColor', ...
            'Color change failed: %s', ME.message);
    end
end

function hideTrace(lh)
%HIDETRACE  Toggle a single line's visibility.
    if ~isgraphics(lh), return; end
    try
        if strcmp(lh.Visible, 'on')
            lh.Visible = 'off';
        else
            lh.Visible = 'on';
        end
    catch ME
        warning('bosonPlotter:plotInteractions:hideTrace', ...
            'Hide trace failed: %s', ME.message);
    end
end

function copyTraceData(lh)
%COPYTRACEDATA  Copy (X, Y) columns of a line to the system clipboard.
    if ~isgraphics(lh), return; end
    try
        xData = lh.XData(:);
        yData = lh.YData(:);
        if isempty(xData), return; end
        n   = numel(xData);
        txt = cell(n, 1);
        for i = 1:n
            txt{i} = sprintf('%.10g\t%.10g', xData(i), yData(i));
        end
        clipboard('copy', strjoin(txt, newline));
    catch ME
        warning('bosonPlotter:plotInteractions:copyData', ...
            'Copy data failed: %s', ME.message);
    end
end

function dsIdx = resolveDatasetForLine(lh, lineRank, nDS, nLines)
%RESOLVEDATASETFORLINE  Best-effort mapping from a line handle to a 1-based
%   dataset index.  Uses UserData.dsIdx when set by renderPlot; otherwise
%   scales lineRank proportionally.
    dsIdx = 0;
    try
        ud = lh.UserData;
        if isstruct(ud) && isfield(ud, 'dsIdx') && isnumeric(ud.dsIdx)
            dsIdx = ud.dsIdx;
            return;
        end
    catch
    end
    if nDS > 0 && nLines > 0
        % Proportional fallback: distribute lines evenly across datasets
        dsIdx = min(ceil(lineRank / max(nLines/nDS, 1)), nDS);
    end
end
