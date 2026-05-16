function buildPropertiesPanel(fig, model, applyCallback)
%BUILDPROPERTIESPANEL  Figure Properties dialog — legend, axes, fonts, margins.
%
%   bosonPlotter.figDoc.buildPropertiesPanel(fig, model, applyCallback)
%
%   Opens a non-modal dialog for editing the FigDocModel. Changes are
%   applied live via applyCallback() which should call applyToAxes.
%
%   Inputs:
%     fig           - parent figure (for positioning)
%     model         - FigDocModel handle (mutated in place)
%     applyCallback - function handle called after each change: applyCallback()

    dlg = uifigure('Name', 'Figure Properties', ...
        'Position', [200 200 380 480], 'Resize', 'off');

    tabs = uitabgroup(dlg, 'Units', 'normalized', 'Position', [0 0 1 1]);

    buildAxesTab(tabs, model, applyCallback);
    buildLegendTab(tabs, model, applyCallback);
    buildLayoutTab(tabs, model, applyCallback);
end

% ═════════════════════════════════════════════════════════════════════════
function buildAxesTab(tabs, model, cb)
    tab = uitab(tabs, 'Title', 'Axes');
    gl = uigridlayout(tab, [9 3], ...
        'RowHeight', {26,26,26,26,26,26,26,26,'1x'}, ...
        'ColumnWidth', {100, '1x', '1x'}, ...
        'Padding', [10 10 10 10], 'RowSpacing', 6);

    % X Limits
    uilabel(gl, 'Text', 'X Limits:');
    efXMin = uieditfield(gl, 'text', 'Value', limStr(model.xLim, 1), 'Placeholder', 'auto');
    efXMax = uieditfield(gl, 'text', 'Value', limStr(model.xLim, 2), 'Placeholder', 'auto');
    efXMin.Layout.Row = 1; efXMin.Layout.Column = 2;
    efXMax.Layout.Row = 1; efXMax.Layout.Column = 3;

    % Y Limits
    uilabel(gl, 'Text', 'Y Limits:');
    efYMin = uieditfield(gl, 'text', 'Value', limStr(model.yLim, 1), 'Placeholder', 'auto');
    efYMax = uieditfield(gl, 'text', 'Value', limStr(model.yLim, 2), 'Placeholder', 'auto');
    lbl = findobj(gl.Children, 'flat', 'Type', 'uilabel'); %#ok — row auto
    efYMin.Layout.Row = 2; efYMin.Layout.Column = 2;
    efYMax.Layout.Row = 2; efYMax.Layout.Column = 3;

    % X Scale
    uilabel(gl, 'Text', 'X Scale:');
    ddXScale = uidropdown(gl, 'Items', {'linear','log'}, 'Value', model.xScale);
    ddXScale.Layout.Row = 3; ddXScale.Layout.Column = [2 3];

    % Y Scale
    uilabel(gl, 'Text', 'Y Scale:');
    ddYScale = uidropdown(gl, 'Items', {'linear','log'}, 'Value', model.yScale);
    ddYScale.Layout.Row = 4; ddYScale.Layout.Column = [2 3];

    % X Label
    uilabel(gl, 'Text', 'X Label:');
    efXLabel = uieditfield(gl, 'text', 'Value', char(model.xLabel));
    efXLabel.Layout.Row = 5; efXLabel.Layout.Column = [2 3];

    % Y Label
    uilabel(gl, 'Text', 'Y Label:');
    efYLabel = uieditfield(gl, 'text', 'Value', char(model.yLabel));
    efYLabel.Layout.Row = 6; efYLabel.Layout.Column = [2 3];

    % Font size
    uilabel(gl, 'Text', 'Font Size:');
    spnFont = uispinner(gl, 'Value', model.fontSize, 'Limits', [6 36], 'Step', 1);
    spnFont.Layout.Row = 7; spnFont.Layout.Column = 2;

    % Grid + ticks
    cbGrid = uicheckbox(gl, 'Text', 'Grid', 'Value', model.gridOn);
    cbGrid.Layout.Row = 8; cbGrid.Layout.Column = 2;
    cbMinor = uicheckbox(gl, 'Text', 'Minor ticks', 'Value', model.minorTicks);
    cbMinor.Layout.Row = 8; cbMinor.Layout.Column = 3;

    % Callbacks
    efXMin.ValueChangedFcn = @(~,~) applyLims();
    efXMax.ValueChangedFcn = @(~,~) applyLims();
    efYMin.ValueChangedFcn = @(~,~) applyLims();
    efYMax.ValueChangedFcn = @(~,~) applyLims();
    ddXScale.ValueChangedFcn = @(~,~) applyScale();
    ddYScale.ValueChangedFcn = @(~,~) applyScale();
    efXLabel.ValueChangedFcn = @(~,~) applyLabels();
    efYLabel.ValueChangedFcn = @(~,~) applyLabels();
    spnFont.ValueChangedFcn = @(~,~) applyFont();
    cbGrid.ValueChangedFcn = @(~,~) applyGrid();
    cbMinor.ValueChangedFcn = @(~,~) applyGrid();

    function applyLims()
        model.xLim = parseLim(efXMin.Value, efXMax.Value);
        model.yLim = parseLim(efYMin.Value, efYMax.Value);
        model.markDirty(); cb();
    end
    function applyScale()
        model.xScale = ddXScale.Value;
        model.yScale = ddYScale.Value;
        model.markDirty(); cb();
    end
    function applyLabels()
        model.xLabel = string(efXLabel.Value);
        model.yLabel = string(efYLabel.Value);
        model.markDirty(); cb();
    end
    function applyFont()
        model.fontSize = spnFont.Value;
        model.markDirty(); cb();
    end
    function applyGrid()
        model.gridOn = cbGrid.Value;
        model.minorTicks = cbMinor.Value;
        model.markDirty(); cb();
    end
end

% ═════════════════════════════════════════════════════════════════════════
function buildLegendTab(tabs, model, cb)
    tab = uitab(tabs, 'Title', 'Legend');
    gl = uigridlayout(tab, [6 2], ...
        'RowHeight', {26,26,26,26,26,'1x'}, ...
        'ColumnWidth', {120, '1x'}, ...
        'Padding', [10 10 10 10], 'RowSpacing', 6);

    % Visible
    uilabel(gl, 'Text', 'Legend Visible:');
    cbVis = uicheckbox(gl, 'Text', '', 'Value', model.legendVisible);
    cbVis.Layout.Row = 1; cbVis.Layout.Column = 2;

    % Location
    uilabel(gl, 'Text', 'Location:');
    locs = {'best','northeast','northwest','southeast','southwest', ...
            'north','south','east','west','bestoutside'};
    curLoc = 'best';
    if ischar(model.legendLocation) || isstring(model.legendLocation)
        curLoc = char(model.legendLocation);
        if ~ismember(curLoc, locs), curLoc = 'best'; end
    end
    ddLoc = uidropdown(gl, 'Items', locs, 'Value', curLoc);
    ddLoc.Layout.Row = 2; ddLoc.Layout.Column = 2;

    % Orientation
    uilabel(gl, 'Text', 'Orientation:');
    ddOrient = uidropdown(gl, 'Items', {'vertical','horizontal'}, ...
        'Value', model.legendOrientation);
    ddOrient.Layout.Row = 3; ddOrient.Layout.Column = 2;

    % Font size
    uilabel(gl, 'Text', 'Font Size:');
    spnLF = uispinner(gl, 'Value', model.legendFontSize, 'Limits', [6 24], 'Step', 1);
    spnLF.Layout.Row = 4; spnLF.Layout.Column = 2;

    % Columns
    uilabel(gl, 'Text', 'Columns:');
    spnCol = uispinner(gl, 'Value', model.legendColumns, 'Limits', [1 6], 'Step', 1);
    spnCol.Layout.Row = 5; spnCol.Layout.Column = 2;

    cbVis.ValueChangedFcn = @(~,~) apply();
    ddLoc.ValueChangedFcn = @(~,~) apply();
    ddOrient.ValueChangedFcn = @(~,~) apply();
    spnLF.ValueChangedFcn = @(~,~) apply();
    spnCol.ValueChangedFcn = @(~,~) apply();

    function apply()
        model.legendVisible = cbVis.Value;
        model.legendLocation = ddLoc.Value;
        model.legendOrientation = ddOrient.Value;
        model.legendFontSize = spnLF.Value;
        model.legendColumns = spnCol.Value;
        model.markDirty(); cb();
    end
end

% ═════════════════════════════════════════════════════════════════════════
function buildLayoutTab(tabs, model, cb)
    tab = uitab(tabs, 'Title', 'Layout');
    gl = uigridlayout(tab, [5 2], ...
        'RowHeight', {26,26,26,26,'1x'}, ...
        'ColumnWidth', {120, '1x'}, ...
        'Padding', [10 10 10 10], 'RowSpacing', 6);

    m = model.margins; % [left right top bottom]

    uilabel(gl, 'Text', 'Left margin:');
    sldL = uislider(gl, 'Value', m(1)*100, 'Limits', [2 40]);
    sldL.Layout.Row = 1; sldL.Layout.Column = 2;

    uilabel(gl, 'Text', 'Right margin:');
    sldR = uislider(gl, 'Value', m(2)*100, 'Limits', [2 40]);
    sldR.Layout.Row = 2; sldR.Layout.Column = 2;

    uilabel(gl, 'Text', 'Top margin:');
    sldT = uislider(gl, 'Value', m(3)*100, 'Limits', [2 40]);
    sldT.Layout.Row = 3; sldT.Layout.Column = 2;

    uilabel(gl, 'Text', 'Bottom margin:');
    sldB = uislider(gl, 'Value', m(4)*100, 'Limits', [2 40]);
    sldB.Layout.Row = 4; sldB.Layout.Column = 2;

    sldL.ValueChangedFcn = @(~,~) apply();
    sldR.ValueChangedFcn = @(~,~) apply();
    sldT.ValueChangedFcn = @(~,~) apply();
    sldB.ValueChangedFcn = @(~,~) apply();

    function apply()
        model.margins = [sldL.Value/100, sldR.Value/100, sldT.Value/100, sldB.Value/100];
        model.markDirty(); cb();
    end
end

% ═════════════════════════════════════════════════════════════════════════
function s = limStr(lim, idx)
    if isequal(lim, 'auto')
        s = '';
    else
        s = num2str(lim(idx));
    end
end

function lim = parseLim(sMin, sMax)
    vMin = str2double(sMin);
    vMax = str2double(sMax);
    if isnan(vMin) || isnan(vMax) || vMin >= vMax
        lim = 'auto';
    else
        lim = [vMin vMax];
    end
end
