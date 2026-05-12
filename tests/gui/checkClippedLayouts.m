function violations = checkClippedLayouts(rootHandle, options)
%CHECKCLIPPEDLAYOUTS  Walk a figure tree and report clipped/undersized widgets.
%
%   v = checkClippedLayouts(fig)
%   v = checkClippedLayouts(fig, 'IgnoreTags', {'foo','bar'})
%   v = checkClippedLayouts(fig, 'MinLeafHeight', 10)
%
%   Returns a cell array of violation structs.  Each violation has:
%       .kind      — 'nested_grid_too_tall' | 'nested_grid_too_wide' | 'zero_size_leaf'
%       .handle    — the offending widget handle
%       .parent    — the parent uigridlayout (for structural cases)
%       .allocated — parent's allocated pixels for this child
%       .required  — child's minimum required pixels
%       .location  — human-readable path through the widget tree
%       .reason    — free-text explanation
%
%   Empty cell on success.  Non-empty cell means the test should fail
%   and the caller should print each .reason so the exact widget can
%   be found and fixed.
%
%   DETECTION PASSES:
%
%   1. STRUCTURAL — for every uigridlayout whose child is itself a
%      uigridlayout with fixed-pixel RowHeight / ColumnWidth entries,
%      verify that the sum of those fixed sizes + RowSpacing +
%      top+bottom Padding fits inside the parent's allocated row /
%      column.  If the parent also uses a fixed pixel size for the
%      slot that holds the child, and it's smaller than the child
%      needs, flag it.  (This catches the bug class where you stack
%      two 18-px rows into a parent row that only allocates 22 px.)
%
%   2. RUNTIME — after a drawnow, walk every descendant and check that
%      its Position(3) > 0 and Position(4) > 0.  Zero-sized widgets
%      are effectively invisible regardless of the reason (could be
%      '1x' collapse, Visible='off' but no — Visible='off' keeps
%      Position intact, only layout engine zero sizes are caught).
%
%   LIMITATIONS:
%     - Only catches fixed-pixel clipping.  A parent row set to '1x'
%       (flex) with a child that overflows will NOT be flagged because
%       we can't tell at static-check time how much space the flex
%       will receive.
%     - Column widths are checked analogously to row heights.
%     - Padding arrays are assumed to be [left bottom right top] as
%       per MATLAB's uigridlayout convention.

    arguments
        rootHandle
        options.IgnoreTags    cell    = {}
        options.MinLeafHeight double  = 1
        options.MinLeafWidth  double  = 1
    end

    violations = {};
    if isempty(rootHandle) || ~isvalid(rootHandle), return; end

    % Recurse, passing down a breadcrumb path for readable diagnostics
    walk(rootHandle, '');

    function walk(node, path)
        if ~isvalid(node), return; end

        % Build a location string for this node
        here = describe(node);
        if isempty(path), fullPath = here; else, fullPath = [path ' > ' here]; end

        % ── PASS 2 RUNTIME CHECK: zero-sized leaf ────────────────
        % Apply only to "leaf" widgets (no Children OR known leaf types).
        % Skip uigridlayout containers themselves — their size is
        % handled by the structural pass.
        % Also skip widgets in collapsed sections: any ancestor grid with
        % a 0-height row is an intentional hide (same exemption as PASS 1).
        if isLeafWidget(node) && shouldCheck(node, options.IgnoreTags) && ...
                ~isInCollapsedSection(node)
            pos = getPositionSafe(node);
            if ~isempty(pos)
                if pos(4) < options.MinLeafHeight
                    violations{end+1} = makeViolation('zero_size_leaf', node, [], ...
                        pos(4), options.MinLeafHeight, fullPath, ...
                        sprintf('Widget height %g < minimum %g', pos(4), options.MinLeafHeight)); %#ok<*AGROW>
                end
                if pos(3) < options.MinLeafWidth
                    violations{end+1} = makeViolation('zero_size_leaf', node, [], ...
                        pos(3), options.MinLeafWidth, fullPath, ...
                        sprintf('Widget width %g < minimum %g', pos(3), options.MinLeafWidth));
                end
            end
        end

        % ── PASS 1 STRUCTURAL CHECK: nested grid fits parent row/col ──
        if isa(node, 'matlab.ui.container.GridLayout')
            % Look at every child grid and compare its minimum required
            % size to the slot this parent gives it.
            for ci = 1:numel(node.Children)
                child = node.Children(ci);
                if ~isvalid(child), continue; end
                if ~isa(child, 'matlab.ui.container.GridLayout'), continue; end

                % What does THIS node allocate for the child?
                [allocH, allocW] = parentAllocation(node, child);

                % What does the CHILD need at minimum?
                [reqH, reqW] = minRequiredSize(child);

                % IMPORTANT: allocated == 0 is a legitimate "collapsed
                % section" pattern in BosonPlotter — rows are set to 0
                % height when the section is hidden.  Treat that as
                % intentionally invisible, NOT as clipping.  Only flag
                % partial clipping (0 < allocated < required).
                if isfinite(allocH) && isfinite(reqH) && ...
                   allocH > 0 && reqH > allocH + 0.5
                    violations{end+1} = makeViolation('nested_grid_too_tall', ...
                        child, node, allocH, reqH, fullPath, ...
                        sprintf(['Nested grid needs %g px high but parent row allocates %g px. ' ...
                                 'Bump the parent uigridlayout RowHeight for the slot holding this child.'], ...
                                reqH, allocH));
                end
                if isfinite(allocW) && isfinite(reqW) && ...
                   allocW > 0 && reqW > allocW + 0.5
                    violations{end+1} = makeViolation('nested_grid_too_wide', ...
                        child, node, allocW, reqW, fullPath, ...
                        sprintf(['Nested grid needs %g px wide but parent column allocates %g px. ' ...
                                 'Bump the parent uigridlayout ColumnWidth for the slot holding this child.'], ...
                                reqW, allocW));
                end
            end
        end

        % Recurse
        if isprop(node, 'Children') && ~isempty(node.Children)
            for ci = 1:numel(node.Children)
                walk(node.Children(ci), fullPath);
            end
        end
    end
end


% ════════════════════════════════════════════════════════════════════════
%  Helpers
% ════════════════════════════════════════════════════════════════════════

function [h, w] = parentAllocation(parentGrid, child)
%PARENTALLOCATION  How many pixels parentGrid gives to child in each axis.
%   Returns Inf for any dimension that uses flex ('1x', '2x') or 'fit'
%   — we can't statically resolve those, so we don't report them.
    h = Inf;  w = Inf;

    lay = child.Layout;
    if isempty(lay), return; end

    % Row range (scalar or [start end])
    rowRng = lay.Row;
    if isempty(rowRng), return; end
    rowIdx = rowRng(1):rowRng(end);

    h = sumFixedSlots(parentGrid.RowHeight, rowIdx);
    if isfinite(h) && numel(rowIdx) > 1
        h = h + parentGrid.RowSpacing * (numel(rowIdx) - 1);
    end

    % Column range
    colRng = lay.Column;
    if isempty(colRng), return; end
    colIdx = colRng(1):colRng(end);

    w = sumFixedSlots(parentGrid.ColumnWidth, colIdx);
    if isfinite(w) && numel(colIdx) > 1
        w = w + parentGrid.ColumnSpacing * (numel(colIdx) - 1);
    end
end


function total = sumFixedSlots(specCell, idx)
%SUMFIXEDSLOTS  Sum the fixed-pixel entries at specCell{idx}.
%   Returns Inf if any entry is flex or 'fit' (can't statically resolve).
    total = 0;
    for k = 1:numel(idx)
        i = idx(k);
        if i < 1 || i > numel(specCell), total = Inf; return; end
        v = specCell{i};
        if isnumeric(v)
            total = total + double(v);
        else
            total = Inf; return;    % '1x', '2x', 'fit', etc.
        end
    end
end


function [h, w] = minRequiredSize(grid)
%MINREQUIREDSIZE  Minimum pixels needed by a uigridlayout using its spec.
%   If any row / column spec is flex, the corresponding dimension is Inf
%   (meaning "can grow / shrink", so we can't prove it needs a minimum).
    h = sumFixedSlots(grid.RowHeight, 1:numel(grid.RowHeight));
    if isfinite(h) && numel(grid.RowHeight) > 1
        h = h + grid.RowSpacing * (numel(grid.RowHeight) - 1);
    end
    w = sumFixedSlots(grid.ColumnWidth, 1:numel(grid.ColumnWidth));
    if isfinite(w) && numel(grid.ColumnWidth) > 1
        w = w + grid.ColumnSpacing * (numel(grid.ColumnWidth) - 1);
    end

    % Padding is [left bottom right top] in uigridlayout
    if isprop(grid, 'Padding')
        pad = grid.Padding;
        if numel(pad) >= 4
            if isfinite(h), h = h + pad(2) + pad(4); end
            if isfinite(w), w = w + pad(1) + pad(3); end
        end
    end
end


function tf = isLeafWidget(node)
%ISLEAFWIDGET  True if node is a widget we should size-check.
%   We skip containers (figure, panel, gridlayout) — their sizes are
%   driven by their children, not the other way around.
    leafTypes = {
        'matlab.ui.control.Label'
        'matlab.ui.control.Button'
        'matlab.ui.control.DropDown'
        'matlab.ui.control.EditField'
        'matlab.ui.control.NumericEditField'
        'matlab.ui.control.CheckBox'
        'matlab.ui.control.Slider'
        'matlab.ui.control.Spinner'
        'matlab.ui.control.ListBox'
        'matlab.ui.control.Table'
        'matlab.ui.control.TextArea'
        'matlab.ui.control.RadioButton'
        'matlab.ui.control.StateButton'
        'matlab.ui.control.Image'
    };
    tf = false;
    for k = 1:numel(leafTypes)
        if isa(node, leafTypes{k}), tf = true; return; end
    end
end


function tf = shouldCheck(node, ignoreTags)
%SHOULDCHECK  Honor the IgnoreTags option.
    tf = true;
    if isempty(ignoreTags), return; end
    if isprop(node, 'Tag')
        t = char(node.Tag);
        if any(strcmp(ignoreTags, t)), tf = false; end
    end
end


function tf = isInCollapsedSection(node)
%ISINCOLLAPEDSECTION  True if any ancestor uigridlayout allocates 0 px to node's section.
%   Mirrors the PASS 1 exemption: RowHeight/ColumnWidth = 0 is an intentional hide.
    tf = false;
    cur = node;
    while ~isempty(cur) && isvalid(cur)
        parent = cur.Parent;
        if isempty(parent) || ~isvalid(parent), break; end
        if isa(parent, 'matlab.ui.container.GridLayout') && isprop(cur, 'Layout')
            lay = cur.Layout;
            if ~isempty(lay)
                if ~isempty(lay.Row)
                    rowRng = lay.Row;
                    rowIdx = rowRng(1):rowRng(end);
                    allocated = sumFixedSlots(parent.RowHeight, rowIdx);
                    if isfinite(allocated) && allocated <= 0
                        tf = true; return;
                    end
                end
                if ~isempty(lay.Column)
                    colRng = lay.Column;
                    colIdx = colRng(1):colRng(end);
                    allocated = sumFixedSlots(parent.ColumnWidth, colIdx);
                    if isfinite(allocated) && allocated <= 0
                        tf = true; return;
                    end
                end
            end
        end
        cur = parent;
    end
end


function pos = getPositionSafe(node)
%GETPOSITIONSAFE  Return node.Position or empty if unavailable / Visible='off'.
    pos = [];
    if ~isprop(node, 'Position'), return; end
    try
        pos = node.Position;
    catch
        pos = [];
    end
    % Invisible widgets are intentional — don't flag them
    if isprop(node, 'Visible') && strcmpi(node.Visible, 'off')
        pos = [];
    end
end


function d = describe(node)
%DESCRIBE  One-line description of a handle for breadcrumb paths.
    try
        cls = class(node);
        cls = regexprep(cls, 'matlab\.ui\.(control|container)\.', '');
        tagStr = '';
        if isprop(node, 'Tag') && ~isempty(char(node.Tag))
            tagStr = sprintf('#%s', char(node.Tag));
        end
        textStr = '';
        if isprop(node, 'Text')
            txt = char(node.Text);
            if ~isempty(txt)
                if numel(txt) > 24, txt = [txt(1:21) '...']; end
                textStr = sprintf('"%s"', txt);
            end
        end
        d = sprintf('%s%s%s', cls, tagStr, textStr);
    catch
        d = '<?>';
    end
end


function v = makeViolation(kind, handle, parent, allocated, required, path, reason)
%MAKEVIOLATION  Build a violation struct.
    v = struct( ...
        'kind',      kind, ...
        'handle',    handle, ...
        'parent',    parent, ...
        'allocated', allocated, ...
        'required',  required, ...
        'location',  path, ...
        'reason',    reason);
end
