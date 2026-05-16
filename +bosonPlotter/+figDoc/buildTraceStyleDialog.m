function buildTraceStyleDialog(fig, ax, model, applyCallback)
%BUILDTRACESTYLEDIALOG  Edit per-trace visual styles (color, width, markers).
%
%   bosonPlotter.figDoc.buildTraceStyleDialog(fig, ax, model, applyCallback)

    lines = findobj(ax.Children, 'Type', 'Line');
    if isempty(lines), return; end
    lines = flipud(lines); % put in draw order

    names = cell(1, numel(lines));
    for k = 1:numel(lines)
        if strlength(string(lines(k).DisplayName)) > 0
            names{k} = sprintf('%d: %s', k, lines(k).DisplayName);
        else
            names{k} = sprintf('%d: Trace %d', k, k);
        end
    end

    dlg = uifigure('Name', 'Trace Styles', 'Position', [300 300 340 300], ...
        'Resize', 'off');
    gl = uigridlayout(dlg, [8 2], ...
        'RowHeight', {26, 26, 26, 26, 26, 26, 10, 36}, ...
        'ColumnWidth', {110, '1x'}, ...
        'Padding', [12 12 12 12], 'RowSpacing', 6);

    uilabel(gl, 'Text', 'Trace:', 'FontWeight', 'bold');
    ddTrace = uidropdown(gl, 'Items', names, 'Value', names{1});
    ddTrace.Layout.Row = 1; ddTrace.Layout.Column = 2;

    uilabel(gl, 'Text', 'Color:');
    ddColor = uidropdown(gl, 'Items', {'(unchanged)','Red','Blue','Green','Black','Orange','Purple','Cyan'}, ...
        'Value', '(unchanged)');
    ddColor.Layout.Row = 2; ddColor.Layout.Column = 2;

    uilabel(gl, 'Text', 'Line Width:');
    spnLW = uispinner(gl, 'Value', 1.5, 'Limits', [0.25 6], 'Step', 0.25);
    spnLW.Layout.Row = 3; spnLW.Layout.Column = 2;

    uilabel(gl, 'Text', 'Line Style:');
    ddStyle = uidropdown(gl, 'Items', {'-','--',':','-.','none'}, 'Value', '-');
    ddStyle.Layout.Row = 4; ddStyle.Layout.Column = 2;

    uilabel(gl, 'Text', 'Marker:');
    ddMarker = uidropdown(gl, 'Items', {'none','o','s','d','^','v','+','x','*'}, ...
        'Value', 'none');
    ddMarker.Layout.Row = 5; ddMarker.Layout.Column = 2;

    uilabel(gl, 'Text', 'Marker Size:');
    spnMS = uispinner(gl, 'Value', 6, 'Limits', [2 20], 'Step', 1);
    spnMS.Layout.Row = 6; spnMS.Layout.Column = 2;

    btnApply = uibutton(gl, 'Text', 'Apply', 'FontWeight', 'bold');
    btnApply.Layout.Row = 8; btnApply.Layout.Column = [1 2];

    ddTrace.ValueChangedFcn = @(~,~) loadCurrent();
    btnApply.ButtonPushedFcn = @(~,~) doApply();

    loadCurrent();

    function loadCurrent()
        idx = getSelectedIdx();
        if idx > numel(lines), return; end
        ln = lines(idx);
        spnLW.Value = ln.LineWidth;
        ddStyle.Value = ln.LineStyle;
        ddMarker.Value = ln.Marker;
        spnMS.Value = ln.MarkerSize;
        ddColor.Value = '(unchanged)';
    end

    function doApply()
        idx = getSelectedIdx();
        col = resolveColor_(ddColor.Value);
        if ~isempty(col)
            model.setTraceStyle(idx, 'color', col);
        end
        model.setTraceStyle(idx, 'lineWidth', spnLW.Value);
        model.setTraceStyle(idx, 'lineStyle', ddStyle.Value);
        model.setTraceStyle(idx, 'marker', ddMarker.Value);
        model.setTraceStyle(idx, 'markerSize', spnMS.Value);
        applyCallback();
    end

    function idx = getSelectedIdx()
        sel = ddTrace.Value;
        idx = find(strcmp(names, sel), 1);
        if isempty(idx), idx = 1; end
    end
end

function rgb = resolveColor_(name)
    switch name
        case 'Red',    rgb = [0.85 0.2 0.2];
        case 'Blue',   rgb = [0.2 0.2 0.85];
        case 'Green',  rgb = [0.2 0.7 0.2];
        case 'Black',  rgb = [0 0 0];
        case 'Orange', rgb = [0.9 0.5 0.1];
        case 'Purple', rgb = [0.6 0.2 0.8];
        case 'Cyan',   rgb = [0 0.7 0.8];
        otherwise,     rgb = [];
    end
end
