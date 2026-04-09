function w = buildMap2DPanel(parentGL, isMac)
%BUILDMAP2DPANEL  Construct the 2D Map View panel inside the analysis grid.
%
%   Syntax
%     w = bosonPlotter.buildMap2DPanel(parentGL, isMac)
%
%   Inputs
%     parentGL - uigridlayout that is the parent (analysisGL in BosonPlotter)
%     isMac    - logical scalar; true when running on macOS (used for hint text)
%
%   Outputs
%     w - struct of widget handles (all ValueChangedFcn / ButtonPushedFcn
%         callbacks left empty; caller wires them after receiving w)
%
%       w.map2DPanel        uipanel  (Visible='off'; caller shows when 2D data active)
%       w.ddMap2DType       uidropdown  {'Heatmap','Contour','Filled Contour'}
%       w.efMap2DContourN   uieditfield (numeric, contour level count)
%       w.cbMap2DQSpace     uicheckbox  (Q-space toggle; starts disabled)
%       w.ddMap2DCmap       uidropdown  (colormap selection)
%       w.ddMap2DScale      uidropdown  {'Linear','Log₁₀'}
%       w.efMap2DCMin       uieditfield (text, colorbar min; blank = auto)
%       w.efMap2DCMax       uieditfield (text, colorbar max; blank = auto)
%       w.btnPoleFigure     uibutton
%       w.btnBoxIntegrate   uibutton
%       w.efBoxIntW         uieditfield (text, box width; blank = free-draw)
%       w.efBoxIntH         uieditfield (text, box height; blank = free-draw)
%       w.btnArcIntegrate   uibutton   (starts disabled)
%       w.lblMap2DInfo      uilabel    (runtime status text)
%       w.cbMap2DSingle     uicheckbox  (single-precision toggle)
%       w.btnFitSurface     uibutton   (open 2D surface fitting dialog)
%       w.btnClear2DMatrix  uibutton
%
%   Examples
%     w = bosonPlotter.buildMap2DPanel(analysisGL, ismac);
%     w.map2DPanel.Layout.Row = [1 2];
%     w.map2DPanel.Layout.Column = 3;
%     w.ddMap2DType.ValueChangedFcn     = @(~,~) onPlot([],[]);
%     w.efMap2DContourN.ValueChangedFcn = @(~,~) onPlot([],[]);
%     % ... wire remaining callbacks ...

% ════════════════════════════════════════════════════════════════════
%  Platform-specific key hint
% ════════════════════════════════════════════════════════════════════
if isMac
    altKey = 'Opt';
    altFull = 'Option';
else
    altKey = 'Alt';
    altFull = 'Alt';
end

% ════════════════════════════════════════════════════════════════════
%  Panel (parent layout assignment left to caller)
% ════════════════════════════════════════════════════════════════════
map2DPanel = uipanel(parentGL,'Title','2D Map View','FontSize',11, ...
    'Scrollable','on');
map2DPanel.Visible = 'off';   % shown only when a 2D area-detector dataset is active

map2DGL = uigridlayout(map2DPanel,[19 2], ...
    'RowHeight',    {20, 20, 20, 20, 20, 20, 20, 22, 22, 16, 20, 20, 22, 22, 18, 20, 22, 22, '1x'}, ...
    'ColumnWidth',  {85, '1x'}, ...
    'Padding',      [4 4 4 4], ...
    'RowSpacing',   3, ...
    'ColumnSpacing', 4);

% ── Row 1: Plot type ─────────────────────────────────────────────
lblMap2DType = uilabel(map2DGL,'Text','Plot type:','FontSize',10,'HorizontalAlignment','right');
lblMap2DType.Layout.Row = 1; lblMap2DType.Layout.Column = 1;
ddMap2DType = uidropdown(map2DGL, ...
    'Items',   {'Heatmap','Contour','Filled Contour'}, ...
    'Value',   'Heatmap', ...
    'Tooltip', 'Rendering style for the 2D intensity map');
ddMap2DType.Layout.Row = 1; ddMap2DType.Layout.Column = 2;

% ── Row 2: Contour levels ────────────────────────────────────────
lblMap2DLevels = uilabel(map2DGL,'Text','Contour lvls:','FontSize',10,'HorizontalAlignment','right');
lblMap2DLevels.Layout.Row = 2; lblMap2DLevels.Layout.Column = 1;
efMap2DContourN = uieditfield(map2DGL,'numeric', ...
    'Value',   20, ...
    'Limits',  [2 200], ...
    'Tooltip', 'Number of contour levels (Contour and Filled Contour modes)');
efMap2DContourN.Layout.Row = 2; efMap2DContourN.Layout.Column = 2;

% ── Row 3: Q-space toggle ────────────────────────────────────────
cbMap2DQSpace = uicheckbox(map2DGL, ...
    'Text',    'Q-space (Qx / Qz)', ...
    'Value',   false, ...
    'Enable',  'off', ...
    'Tooltip', ['Show reciprocal-space map in Qx/Qz coordinates.' newline ...
                'Enabled when the file contains wavelength metadata.' newline ...
                'Shift+click / Ctrl+click line-cuts use Q-space coordinates.']);
cbMap2DQSpace.Layout.Row = 3; cbMap2DQSpace.Layout.Column = [1 2];

% ── Row 4: Colormap ─────────────────────────────────────────────
lblMap2DCmap = uilabel(map2DGL,'Text','Color scale:','FontSize',10,'HorizontalAlignment','right');
lblMap2DCmap.Layout.Row = 4; lblMap2DCmap.Layout.Column = 1;
MAP2D_CMAPS = {'parula','viridis','plasma','inferno','hot','jet','turbo','gray','bone','copper'};
ddMap2DCmap = uidropdown(map2DGL, ...
    'Items',   MAP2D_CMAPS, ...
    'Value',   'parula', ...
    'Tooltip', 'Colormap for 2D heatmap / contour display');
ddMap2DCmap.Layout.Row = 4; ddMap2DCmap.Layout.Column = 2;

% ── Row 5: Intensity scale ───────────────────────────────────────
lblMap2DScale = uilabel(map2DGL,'Text','Intensity:','FontSize',10,'HorizontalAlignment','right');
lblMap2DScale.Layout.Row = 5; lblMap2DScale.Layout.Column = 1;
ddMap2DScale = uidropdown(map2DGL, ...
    'Items',   {'Linear','Log₁₀'}, ...
    'Value',   'Log₁₀', ...
    'Tooltip', 'Linear or log₁₀ intensity scaling for the 2D map');
ddMap2DScale.Layout.Row = 5; ddMap2DScale.Layout.Column = 2;

% ── Row 6: Colorbar min ──────────────────────────────────────────
lblMap2DCMin = uilabel(map2DGL,'Text','CBar min:','FontSize',10,'HorizontalAlignment','right');
lblMap2DCMin.Layout.Row = 6; lblMap2DCMin.Layout.Column = 1;
efMap2DCMin = uieditfield(map2DGL,'Value','','Placeholder','auto', ...
    'FontSize',10, ...
    'Tooltip','Minimum colorbar value (blank = auto)');
efMap2DCMin.Layout.Row = 6; efMap2DCMin.Layout.Column = 2;

% ── Row 7: Colorbar max ──────────────────────────────────────────
lblMap2DCMax = uilabel(map2DGL,'Text','CBar max:','FontSize',10,'HorizontalAlignment','right');
lblMap2DCMax.Layout.Row = 7; lblMap2DCMax.Layout.Column = 1;
efMap2DCMax = uieditfield(map2DGL,'Value','','Placeholder','auto', ...
    'FontSize',10, ...
    'Tooltip','Maximum colorbar value (blank = auto)');
efMap2DCMax.Layout.Row = 7; efMap2DCMax.Layout.Column = 2;

% ── Row 8: Pole Figure ───────────────────────────────────────────
btnPoleFigure = uibutton(map2DGL,'Text','Pole Figure...', ...
    'BackgroundColor',[0.30 0.45 0.55], ...
    'FontColor',[1 1 1], ...
    'Tooltip','Open a polar plot of integrated intensity at a chosen 2θ position');
btnPoleFigure.Layout.Row = 8; btnPoleFigure.Layout.Column = [1 2];

% ── Row 9: Box Integrate ─────────────────────────────────────────
btnBoxIntegrate = uibutton(map2DGL,'Text','Box Integrate...', ...
    'BackgroundColor',[0.20 0.50 0.35], ...
    'FontColor',[1 1 1], ...
    'Tooltip',['Draw a box on the 2D map to integrate intensity within a region.' newline ...
               'Or use ' altFull '+drag directly on the map.']);
btnBoxIntegrate.Layout.Row = 9; btnBoxIntegrate.Layout.Column = [1 2];

% ── Row 10: Box size label ───────────────────────────────────────
lblBoxSize = uilabel(map2DGL,'Text','Box size (fixed):', ...
    'FontSize', 9, 'FontColor', [0.5 0.5 0.5], ...
    'HorizontalAlignment', 'left');
lblBoxSize.Layout.Row = 10; lblBoxSize.Layout.Column = [1 2];

% ── Row 11: Box width ────────────────────────────────────────────
lblBoxW = uilabel(map2DGL,'Text','Width:','FontSize',10,'HorizontalAlignment','right');
lblBoxW.Layout.Row = 11; lblBoxW.Layout.Column = 1;
efBoxIntW = uieditfield(map2DGL,'Value','','Placeholder','free-draw', ...
    'FontSize',10, ...
    'Tooltip',['Box width in axis units (X-axis extent).' newline ...
               'Leave blank for free-draw mode.']);
efBoxIntW.Layout.Row = 11; efBoxIntW.Layout.Column = 2;

% ── Row 12: Box height ───────────────────────────────────────────
lblBoxH = uilabel(map2DGL,'Text','Height:','FontSize',10,'HorizontalAlignment','right');
lblBoxH.Layout.Row = 12; lblBoxH.Layout.Column = 1;
efBoxIntH = uieditfield(map2DGL,'Value','','Placeholder','free-draw', ...
    'FontSize',10, ...
    'Tooltip',['Box height in axis units (Y-axis extent).' newline ...
               'Leave blank for free-draw mode.']);
efBoxIntH.Layout.Row = 12; efBoxIntH.Layout.Column = 2;

% ── Row 13: Arc Integrate ────────────────────────────────────────
btnArcIntegrate = uibutton(map2DGL,'Text','Arc Integrate...', ...
    'BackgroundColor',[0.40 0.25 0.55], ...
    'FontColor',[1 1 1], ...
    'Enable', 'off', ...
    'Tooltip',['Integrate along arcs of constant |Q| in reciprocal space.' newline ...
               'Requires Q-space coordinates (wavelength in file metadata).']);
btnArcIntegrate.Layout.Row = 13; btnArcIntegrate.Layout.Column = [1 2];

% ── Row 14: Info label (populated at runtime) ────────────────────
lblMap2DInfo = uilabel(map2DGL,'Text','', ...
    'FontSize', 9, ...
    'FontColor', [0.4 0.4 0.4], ...
    'HorizontalAlignment', 'center', ...
    'WordWrap', 'on');
lblMap2DInfo.Layout.Row = 14; lblMap2DInfo.Layout.Column = [1 2];

% ── Row 15: Interaction hint ─────────────────────────────────────
lblMap2DHint = uilabel(map2DGL,'Text', ...
    ['Shift+click: H-cut | Ctrl+click: V-cut | ' altKey '+drag: Box integrate'], ...
    'FontSize', 8, ...
    'FontColor', [0.55 0.55 0.55], ...
    'HorizontalAlignment', 'center', ...
    'WordWrap', 'on');
lblMap2DHint.Layout.Row = 15; lblMap2DHint.Layout.Column = [1 2];

% ── Row 16: Single-precision toggle ─────────────────────────────
cbMap2DSingle = uicheckbox(map2DGL, ...
    'Text',    'Single precision (½ RAM)', ...
    'Value',   false, ...
    'Tooltip', ['Store intensity matrix as single (32-bit) instead of double (64-bit).' newline ...
                'Halves memory usage with negligible precision loss for intensity data.']);
cbMap2DSingle.Layout.Row = 16; cbMap2DSingle.Layout.Column = [1 2];

% ── Row 17: Fit Surface ──────────────────────────────────────────
btnFitSurface = uibutton(map2DGL,'Text','Fit Surface...', ...
    'BackgroundColor', [0.25 0.40 0.60], ...
    'FontColor', [1 1 1], ...
    'Tooltip', ['Open the 2D surface fitting dialog.' newline ...
                'Fit a parametric model z = f(x,y) to the active map.']);
btnFitSurface.Layout.Row = 17; btnFitSurface.Layout.Column = [1 2];

% ── Row 18: Clear 2D matrix ──────────────────────────────────────
btnClear2DMatrix = uibutton(map2DGL,'Text','Clear 2D Matrix', ...
    'BackgroundColor', [0.55 0.20 0.20], ...
    'FontColor', [1 1 1], ...
    'Tooltip', ['Discard the 2D intensity matrix from memory.' newline ...
                'Reclaims RAM after viewing. The 1D scan data is preserved.']);
btnClear2DMatrix.Layout.Row = 18; btnClear2DMatrix.Layout.Column = [1 2];

% ════════════════════════════════════════════════════════════════════
%  Pack output struct
% ════════════════════════════════════════════════════════════════════
w.map2DPanel       = map2DPanel;
w.ddMap2DType      = ddMap2DType;
w.efMap2DContourN  = efMap2DContourN;
w.cbMap2DQSpace    = cbMap2DQSpace;
w.ddMap2DCmap      = ddMap2DCmap;
w.ddMap2DScale     = ddMap2DScale;
w.efMap2DCMin      = efMap2DCMin;
w.efMap2DCMax      = efMap2DCMax;
w.btnPoleFigure    = btnPoleFigure;
w.btnBoxIntegrate  = btnBoxIntegrate;
w.efBoxIntW        = efBoxIntW;
w.efBoxIntH        = efBoxIntH;
w.btnArcIntegrate  = btnArcIntegrate;
w.lblMap2DInfo     = lblMap2DInfo;
w.cbMap2DSingle    = cbMap2DSingle;
w.btnFitSurface    = btnFitSurface;
w.btnClear2DMatrix = btnClear2DMatrix;

end
