function installInteractions(ax, fig, appData, applyFcn, setStatusFcn)
%INSTALLINTERACTIONS  Wire direct-manipulation handlers onto figDoc axes.
%
%   bosonPlotter.figDoc.installInteractions(ax, fig, appData, applyFcn, setStatusFcn)
%
%   Installs:
%     - Right-click on axes background → axis quick-edit popup
%     - Right-click on a trace line → trace style popup
%     - Click on legend → cycle location
%     - Drag on annotation text → reposition

    if isempty(ax) || ~isvalid(ax), return; end

    % ── Axes context menu ────────────────────────────────────────────────
    axMenu = uicontextmenu(fig);
    uimenu(axMenu, 'Text', 'Set X Limits...', ...
        'MenuSelectedFcn', @(~,~) editLimits_(ax, appData, applyFcn, 'x'));
    uimenu(axMenu, 'Text', 'Set Y Limits...', ...
        'MenuSelectedFcn', @(~,~) editLimits_(ax, appData, applyFcn, 'y'));
    uimenu(axMenu, 'Text', 'Log X', 'Separator', 'on', ...
        'MenuSelectedFcn', @(~,~) toggleScale_(ax, appData, applyFcn, 'x'));
    uimenu(axMenu, 'Text', 'Log Y', ...
        'MenuSelectedFcn', @(~,~) toggleScale_(ax, appData, applyFcn, 'y'));
    uimenu(axMenu, 'Text', 'Toggle Grid', 'Separator', 'on', ...
        'MenuSelectedFcn', @(~,~) toggleGrid_(ax, appData, applyFcn));
    uimenu(axMenu, 'Text', 'Edit X Label...', 'Separator', 'on', ...
        'MenuSelectedFcn', @(~,~) editLabel_(ax, appData, applyFcn, 'x'));
    uimenu(axMenu, 'Text', 'Edit Y Label...', ...
        'MenuSelectedFcn', @(~,~) editLabel_(ax, appData, applyFcn, 'y'));
    uimenu(axMenu, 'Text', 'Reset to Auto', 'Separator', 'on', ...
        'MenuSelectedFcn', @(~,~) resetAuto_(ax, appData, applyFcn, setStatusFcn));
    ax.ContextMenu = axMenu;

    % ── Legend click → cycle location ────────────────────────────────────
    lgd = findobj(fig, 'Type', 'Legend');
    if ~isempty(lgd) && isvalid(lgd(1))
        lgd(1).ButtonDownFcn = @(~,~) cycleLegend_(ax, appData, applyFcn, setStatusFcn);
    end

    % ── Trace context menus ──────────────────────────────────────────────
    lines = findobj(ax.Children, 'Type', 'Line');
    traceMenu = uicontextmenu(fig);
    uimenu(traceMenu, 'Text', 'Color...', ...
        'MenuSelectedFcn', @(~,~) editTraceColor_(ax, fig, appData, applyFcn));
    uimenu(traceMenu, 'Text', 'Line Width...', ...
        'MenuSelectedFcn', @(~,~) editTraceWidth_(ax, fig, appData, applyFcn));
    uimenu(traceMenu, 'Text', 'Marker...', ...
        'MenuSelectedFcn', @(~,~) editTraceMarker_(ax, fig, appData, applyFcn));
    uimenu(traceMenu, 'Text', 'Move to Right Y-Axis', 'Separator', 'on', ...
        'MenuSelectedFcn', @(~,~) toggleTraceAxis_(ax, fig, appData, applyFcn, setStatusFcn));
    uimenu(traceMenu, 'Text', 'Edit All Styles...', ...
        'MenuSelectedFcn', @(~,~) bosonPlotter.figDoc.dispatchAction('traceStyles', fig, appData, false, ax, setStatusFcn));

    for k = 1:numel(lines)
        ln = lines(k);
        if ~startsWith(string(ln.Tag), 'figDoc')
            ln.ContextMenu = traceMenu;
        end
    end

    % ── Annotation drag ──────────────────────────────────────────────────
    installAnnotationDrag_(ax, appData, applyFcn);
end

% ═══════════════════════════════════════════════════════════════════════════
function editLimits_(ax, appData, applyFcn, which)
    model = getModel_(appData);
    if isempty(model), return; end
    if which == 'x'
        cur = ax.XLim;
        prompt = {'X min:', 'X max:'};
    else
        cur = ax.YLim;
        prompt = {'Y min:', 'Y max:'};
    end
    answer = inputdlg(prompt, 'Set Limits', [1 30], ...
        {num2str(cur(1)), num2str(cur(2))});
    if isempty(answer), return; end
    lo = str2double(answer{1}); hi = str2double(answer{2});
    if isnan(lo) || isnan(hi) || lo >= hi, return; end
    model.pushUndo();
    if which == 'x'
        model.xLim = [lo hi];
    else
        model.yLim = [lo hi];
    end
    applyFcn();
end

% ═══════════════════════════════════════════════════════════════════════════
function toggleScale_(~, appData, applyFcn, which)
    model = getModel_(appData);
    if isempty(model), return; end
    model.pushUndo();
    if which == 'x'
        if strcmp(model.xScale, 'linear')
            model.xScale = 'log';
        else
            model.xScale = 'linear';
        end
    else
        if strcmp(model.yScale, 'linear')
            model.yScale = 'log';
        else
            model.yScale = 'linear';
        end
    end
    applyFcn();
end

% ═══════════════════════════════════════════════════════════════════════════
function toggleGrid_(~, appData, applyFcn)
    model = getModel_(appData);
    if isempty(model), return; end
    model.pushUndo();
    model.gridOn = ~model.gridOn;
    applyFcn();
end

% ═══════════════════════════════════════════════════════════════════════════
function editLabel_(~, appData, applyFcn, which)
    model = getModel_(appData);
    if isempty(model), return; end
    if which == 'x'
        cur = char(model.xLabel);
        title = 'X Label';
    else
        cur = char(model.yLabel);
        title = 'Y Label';
    end
    answer = inputdlg({'Label:'}, title, [1 50], {cur});
    if isempty(answer), return; end
    model.pushUndo();
    if which == 'x'
        model.xLabel = string(answer{1});
    else
        model.yLabel = string(answer{1});
    end
    applyFcn();
end

% ═══════════════════════════════════════════════════════════════════════════
function resetAuto_(~, appData, applyFcn, setStatusFcn)
    model = getModel_(appData);
    if isempty(model), return; end
    model.pushUndo();
    model.xLim = 'auto';
    model.yLim = 'auto';
    model.xScale = 'linear';
    model.yScale = 'linear';
    applyFcn();
    setStatusFcn('Axes reset to auto limits and linear scale.');
end

% ═══════════════════════════════════════════════════════════════════════════
function cycleLegend_(~, appData, applyFcn, setStatusFcn)
    model = getModel_(appData);
    if isempty(model), return; end
    model.pushUndo();
    locations = {'northeast', 'southeast', 'southwest', 'northwest', ...
                 'northoutside', 'eastoutside', 'best'};
    cur = model.legendLocation;
    if isnumeric(cur), cur = 'best'; end
    idx = find(strcmp(locations, cur), 1);
    if isempty(idx), idx = 0; end
    nextIdx = mod(idx, numel(locations)) + 1;
    model.legendLocation = locations{nextIdx};
    applyFcn();
    setStatusFcn(sprintf('Legend → %s', locations{nextIdx}));
end

% ═══════════════════════════════════════════════════════════════════════════
function toggleTraceAxis_(ax, fig, appData, applyFcn, setStatusFcn)
    model = getModel_(appData);
    if isempty(model), return; end
    [idx, ~] = pickTrace_(ax, fig);
    if isempty(idx), return; end
    model.pushUndo();
    while numel(model.traceYAxis) < idx
        model.traceYAxis{end+1} = 'left';
    end
    if strcmp(model.traceYAxis{idx}, 'right')
        model.traceYAxis{idx} = 'left';
        setStatusFcn(sprintf('Trace %d → left Y-axis', idx));
    else
        model.traceYAxis{idx} = 'right';
        setStatusFcn(sprintf('Trace %d → right Y-axis', idx));
    end
    applyFcn();
end

% ═══════════════════════════════════════════════════════════════════════════
function editTraceColor_(ax, fig, appData, applyFcn)
    model = getModel_(appData);
    if isempty(model), return; end
    [idx, ln] = pickTrace_(ax, fig);
    if isempty(idx), return; end
    c = uisetcolor(ln.Color, 'Trace Color');
    if isequal(c, 0), return; end
    model.pushUndo();
    model.setTraceStyle(idx, 'color', c);
    applyFcn();
end

% ═══════════════════════════════════════════════════════════════════════════
function editTraceWidth_(ax, fig, appData, applyFcn)
    model = getModel_(appData);
    if isempty(model), return; end
    [idx, ln] = pickTrace_(ax, fig);
    if isempty(idx), return; end
    answer = inputdlg({'Line width:'}, 'Trace Width', [1 20], ...
        {num2str(ln.LineWidth)});
    if isempty(answer), return; end
    w = str2double(answer{1});
    if isnan(w) || w <= 0, return; end
    model.pushUndo();
    model.setTraceStyle(idx, 'lineWidth', w);
    applyFcn();
end

% ═══════════════════════════════════════════════════════════════════════════
function editTraceMarker_(ax, fig, appData, applyFcn)
    model = getModel_(appData);
    if isempty(model), return; end
    [idx, ~] = pickTrace_(ax, fig);
    if isempty(idx), return; end
    markers = {'none', 'o', '+', '*', '.', 'x', 's', 'd', '^', 'v', '<', '>', 'p', 'h'};
    [sel, ok] = listdlg('ListString', markers, 'SelectionMode', 'single', ...
        'PromptString', 'Select marker:', 'ListSize', [120 200]);
    if ~ok, return; end
    model.pushUndo();
    model.setTraceStyle(idx, 'marker', markers{sel});
    applyFcn();
end

% ═══════════════════════════════════════════════════════════════════════════
function [idx, ln] = pickTrace_(ax, fig)
%PICKTRACE_  If multiple traces, ask user which one; if only one, return it.
    lines = findobj(ax.Children, 'Type', 'Line');
    lines = lines(~startsWith(string({lines.Tag}'), 'figDoc'));
    idx = []; ln = [];
    if isempty(lines), return; end
    if numel(lines) == 1
        idx = 1;
        ln = lines(1);
        return;
    end
    names = cell(numel(lines), 1);
    for k = 1:numel(lines)
        dn = lines(k).DisplayName;
        if isempty(dn), dn = sprintf('Trace %d', k); end
        names{k} = dn;
    end
    [sel, ok] = listdlg('ListString', names, 'SelectionMode', 'single', ...
        'PromptString', 'Select trace:', 'ListSize', [200 150]);
    if ~ok, return; end
    idx = numel(lines) - sel + 1;
    ln = lines(sel);
end

% ═══════════════════════════════════════════════════════════════════════════
function installAnnotationDrag_(ax, appData, applyFcn)
%INSTALLANNOTATIONDRAG_  Make figDoc text annotations draggable.
    annots = findobj(ax, 'Tag', 'figDocAnnotation', 'Type', 'text');
    for k = 1:numel(annots)
        annots(k).ButtonDownFcn = @(src, evt) startDrag_(src, evt, ax, appData, applyFcn, k);
    end
end

% ═══════════════════════════════════════════════════════════════════════════
function startDrag_(src, ~, ax, appData, applyFcn, annotIdx)
    model = getModel_(appData);
    if ~isempty(model), model.pushUndo(); end
    fig = ancestor(ax, 'figure');
    fig.UserData.dragAnnot = struct('src', src, 'ax', ax, ...
        'appData', appData, 'applyFcn', applyFcn, 'annotIdx', annotIdx);
    fig.WindowButtonMotionFcn = @(~,~) dragMotion_(fig);
    fig.WindowButtonUpFcn     = @(~,~) dragRelease_(fig);
end

% ═══════════════════════════════════════════════════════════════════════════
function dragMotion_(fig)
    d = fig.UserData.dragAnnot;
    cp = d.ax.CurrentPoint;
    d.src.Position = [cp(1,1) cp(1,2) 0];
end

% ═══════════════════════════════════════════════════════════════════════════
function dragRelease_(fig)
    d = fig.UserData.dragAnnot;
    fig.WindowButtonMotionFcn = '';
    fig.WindowButtonUpFcn     = '';
    cp = d.ax.CurrentPoint;
    newPos = [cp(1,1) cp(1,2)];

    model = getModel_(d.appData);
    if ~isempty(model) && d.annotIdx <= numel(model.annotations)
        model.annotations{d.annotIdx}.position = newPos;
        model.markDirty();
    end
    fig.UserData = rmfield(fig.UserData, 'dragAnnot');
end

% ═══════════════════════════════════════════════════════════════════════════
function model = getModel_(appData)
    model = [];
    if appData.activeIdx < 1 || appData.activeIdx > numel(appData.datasets)
        return;
    end
    ds = appData.datasets{appData.activeIdx};
    if isfield(ds, 'figDoc') && ~isempty(ds.figDoc)
        model = ds.figDoc;
    end
end
