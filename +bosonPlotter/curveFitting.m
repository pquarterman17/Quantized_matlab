function curveFitting(datasets, activeIdx, mainAx, options)
%CURVEFITTING  Open a standalone curve fitting dialog.
%
%   Syntax:
%       bosonPlotter.curveFitting(datasets, activeIdx, mainAx)
%       bosonPlotter.curveFitting(datasets, activeIdx, mainAx, 'StatusFcn', fcn)
%       bosonPlotter.curveFitting(datasets, activeIdx, mainAx, 'ButtonColors', s)
%
%   Inputs:
%       datasets    cell array of dataset structs (each with .corrData / .data)
%       activeIdx   index into datasets of the currently active file
%       mainAx      axes handle of the main BosonPlotter plot (used by "Plot on Main"
%                   and by cfPickXRange to capture click coordinates)
%
%   Options:
%       StatusFcn       function_handle  Called with a status string message.
%                       Default: @(~) [] (no-op)
%       ButtonColors    struct with fields:
%                         .primary  — RGB triple for primary action buttons
%                         .tool     — RGB triple for secondary tool buttons
%                         .fg       — RGB triple for button text (foreground)
%                       Default: standard BosonPlotter colours
%
%   Description:
%       General-purpose curve fitting dialog with 24+ built-in models
%       (grouped by category), custom equation support, parameter bounds,
%       fixed parameters, weighting, auto-guess, and parameter error
%       estimation.  Uses the +fitting/ package for models, fitting engine,
%       and equation parsing.

arguments
    datasets   cell
    activeIdx  double
    mainAx                              % axes handle — no type constraint (handle)
    options.StatusFcn   function_handle = @(~) []
    options.ButtonColors struct = struct( ...
        'primary', [0.15 0.45 0.75], ...
        'tool',    [0.22 0.22 0.28], ...
        'fg',      [0.95 0.95 0.95])
    options.Appearance  struct = bosonPlotter.resolveStyle(styles.template('screen'))
end

% ════════════════════════════════════════════════════════════════════════
% Resolve active dataset
% ════════════════════════════════════════════════════════════════════════

if isempty(datasets) || activeIdx < 1 || activeIdx > numel(datasets)
    error('bosonPlotter:curveFitting:noDataset', ...
        'No valid dataset at activeIdx = %d.', activeIdx);
end

ds = datasets{activeIdx};
if ~isempty(ds.corrData) && ~isempty(ds.corrData.time)
    plotD = ds.corrData;
else
    plotD = ds.data;
end

if isempty(plotD) || isempty(plotD.time)
    error('bosonPlotter:curveFitting:emptyData', ...
        'Active dataset has no plottable data.');
end

xData  = plotD.time;
labels = plotD.labels;

BTN_PRIMARY = options.ButtonColors.primary;
BTN_TOOL    = options.ButtonColors.tool;
BTN_FG      = options.ButtonColors.fg;

% ════════════════════════════════════════════════════════════════════════
% Model library from +fitting/ package
% ════════════════════════════════════════════════════════════════════════

catalog = fitting.models();
categories = unique({catalog.category}, 'stable');
categories = ['All', categories, 'Custom'];

% Active model state (updated by dropdowns)
activeModel = catalog(1);
customFcn   = [];       % function handle from parseEquation
customNames = {};       % parameter names from parseEquation

% ── Workshop model (MASTERPLAN W5 #60) ─────────────────────────────────
% CurveFitWorkshopModel owns the algorithmic state. The dialog widgets
% remain canonical for input (uitable, dropdowns) but doCurveFit/the
% custom-equation parser write through the model so its `result` is
% always current. Allows scripted batch curve fits + isolation tests
% without a GUI.
cfModel = bosonPlotter.curveFit.CurveFitWorkshopModel();
cfModel.bindFromDataset(ds);

% ════════════════════════════════════════════════════════════════════════
% Build dialog
% ════════════════════════════════════════════════════════════════════════

cfFig = uifigure('Name', 'Curve Fit', ...
    'Position', [200 80 680 700], 'Resize', 'on');

cfRootGL = uigridlayout(cfFig, [7 1], ...
    'RowHeight', {94, 32, '1x', 'fit', 30, 30, 28}, ...
    'Padding', [10 8 10 8], 'RowSpacing', 6);

% ── Row 1: Model selection + channel + X range + weights ─────────────
cfTopGL = uigridlayout(cfRootGL, [4 6], ...
    'RowHeight', {22, 22, 22, 22}, ...
    'ColumnWidth', {75, '1x', 75, '1x', 50, 50}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 4);
cfTopGL.Layout.Row = 1;

% Category dropdown
uilabel(cfTopGL, 'Text', 'Category:', 'HorizontalAlignment', 'right', ...
    'FontWeight', 'bold');
ddCFCat = uidropdown(cfTopGL, 'Items', categories, 'Value', 'All', ...
    'ValueChangedFcn', @(~,~) onCFCategoryChanged());
ddCFCat.Layout.Row = 1; ddCFCat.Layout.Column = 2;

% Model dropdown
uilabel(cfTopGL, 'Text', 'Model:', 'HorizontalAlignment', 'right', ...
    'FontWeight', 'bold');
ddCFModel = uidropdown(cfTopGL, 'Items', {catalog.name}, ...
    'Value', catalog(1).name, ...
    'ValueChangedFcn', @(~,~) onCFModelChanged());
ddCFModel.Layout.Row = 1; ddCFModel.Layout.Column = 4;

% Weights dropdown
uilabel(cfTopGL, 'Text', 'Weights:', 'HorizontalAlignment', 'right', ...
    'FontSize', 10);
ddCFWeights = uidropdown(cfTopGL, 'Items', {'None','1/y','1/y²','1/σ²'}, ...
    'Value', 'None', 'FontSize', 10);
ddCFWeights.Layout.Row = 1; ddCFWeights.Layout.Column = 6;

% Channel dropdown
uilabel(cfTopGL, 'Text', 'Channel:', 'HorizontalAlignment', 'right');
ddCFCh = uidropdown(cfTopGL, 'Items', labels, ...
    'ItemsData', 1:numel(labels), 'Value', 1);
ddCFCh.Layout.Row = 2; ddCFCh.Layout.Column = 2;

% X range
uilabel(cfTopGL, 'Text', 'X min:', 'HorizontalAlignment', 'right');
efCFXmin = uieditfield(cfTopGL, 'numeric', 'Value', min(xData), ...
    'ValueChangedFcn', @(~,~) onXRangeEdited());
efCFXmin.Layout.Row = 2; efCFXmin.Layout.Column = 4;

btnCFPickMin = uibutton(cfTopGL, 'Text', 'Pick', ...
    'FontSize', 9, 'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'Tooltip', 'Click on the plot to set X min', ...
    'ButtonPushedFcn', @(~,~) cfPickXRange('min'));
btnCFPickMin.Layout.Row = 2; btnCFPickMin.Layout.Column = 5;

uilabel(cfTopGL, 'Text', 'X max:', 'HorizontalAlignment', 'right');
efCFXmax = uieditfield(cfTopGL, 'numeric', 'Value', max(xData), ...
    'ValueChangedFcn', @(~,~) onXRangeEdited());
efCFXmax.Layout.Row = 3; efCFXmax.Layout.Column = 2;

btnCFPickMax = uibutton(cfTopGL, 'Text', 'Pick', ...
    'FontSize', 9, 'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'Tooltip', 'Click on the plot to set X max', ...
    'ButtonPushedFcn', @(~,~) cfPickXRange('max'));
btnCFPickMax.Layout.Row = 3; btnCFPickMax.Layout.Column = 5;

% Custom equation field
uilabel(cfTopGL, 'Text', 'Custom:', 'HorizontalAlignment', 'right', ...
    'FontSize', 10);
efCFCustom = uieditfield(cfTopGL, 'text', 'Value', '', ...
    'Placeholder', 'e.g. A*exp(-x/tau) + C', 'FontSize', 10, ...
    'Tooltip', 'Type a custom equation (select "Custom" category to use)');
efCFCustom.Layout.Row = 3; efCFCustom.Layout.Column = 4;

btnCFParseCustom = uibutton(cfTopGL, 'Text', 'Parse', ...
    'FontSize', 9, 'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'Tooltip', 'Parse the custom equation', ...
    'ButtonPushedFcn', @(~,~) onParseCustom());
btnCFParseCustom.Layout.Row = 3; btnCFParseCustom.Layout.Column = 6;

% Equation display (columns 1-4; columns 5-6 hold the cursor toggle)
lblCFEqn = uilabel(cfTopGL, 'Text', catalog(1).equation, ...
    'FontSize', 11, 'FontColor', [0.4 0.7 0.4], ...
    'Interpreter', 'none');
lblCFEqn.Layout.Row = 4; lblCFEqn.Layout.Column = [1 4];

% Cursor toggle (columns 5-6, row 4)
cbCFCursors = uicheckbox(cfTopGL, 'Text', 'Cursors', ...
    'Value', true, ...
    'FontSize', 9, ...
    'Tooltip', 'Show draggable vertical cursors on the fit axes to set the X range', ...
    'ValueChangedFcn', @(~,~) onCFCursorsToggled());
cbCFCursors.Layout.Row = 4; cbCFCursors.Layout.Column = [5 6];

% ── Row 2: Action buttons ────────────────────────────────────────────
cfBtnRow = uigridlayout(cfRootGL, [1 4], ...
    'ColumnWidth', {'1x', '1x', '1x', '1x'}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 6);
cfBtnRow.Layout.Row = 2;

uibutton(cfBtnRow, 'Text', 'Auto-Guess', ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'FontSize', 10, ...
    'Tooltip', 'Estimate initial parameters from data shape', ...
    'ButtonPushedFcn', @(~,~) onAutoGuess());

uibutton(cfBtnRow, 'Text', 'Simulate', ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'FontSize', 10, ...
    'Tooltip', 'Preview model with current parameters (no fitting)', ...
    'ButtonPushedFcn', @(~,~) doSimulate());

btnCFFit = uibutton(cfBtnRow, 'Text', 'Fit', ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
    'FontWeight', 'bold', 'FontSize', 12, ...
    'ButtonPushedFcn', @(~,~) doCurveFit());

uibutton(cfBtnRow, 'Text', 'Reset', ...
    'FontSize', 10, ...
    'Tooltip', 'Reset parameters to defaults', ...
    'ButtonPushedFcn', @(~,~) onCFModelChanged());

% ── Row 3: Results axes (fit + residuals) ────────────────────────────
cfAxPanel = uigridlayout(cfRootGL, [2 1], ...
    'RowHeight', {'3x', '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 4);
cfAxPanel.Layout.Row = 3;

cfAxFit = uiaxes(cfAxPanel);
cfAxFit.Layout.Row = 1;
title(cfAxFit, 'Fit Result');
xlabel(cfAxFit, 'X'); ylabel(cfAxFit, 'Y');
cfAxFit.Box = 'on'; grid(cfAxFit, 'on');
bosonPlotter.applyAppearanceToAxes(cfAxFit, options.Appearance);

cfAxRes = uiaxes(cfAxPanel);
cfAxRes.Layout.Row = 2;
title(cfAxRes, 'Residuals');
xlabel(cfAxRes, 'X'); ylabel(cfAxRes, 'Residual');
cfAxRes.Box = 'on'; grid(cfAxRes, 'on');
bosonPlotter.applyAppearanceToAxes(cfAxRes, options.Appearance);

% ── Row 4: Parameter table ───────────────────────────────────────────
% Columns: Name | Value (fitted) | ±Error | Guess | Lower | Upper | Fixed | Constraint
% Constraint column: empty = free param, non-empty expression = constrained
%   e.g. "2*p1"  or  "p1 + p2"  (p1, p2 refer to position in parameter list)
tblCFParams = uitable(cfRootGL, ...
    'ColumnName', {'Name', 'Value', char(177)+' Error', 'Guess', 'Lower', 'Upper', 'Fixed', 'Constraint'}, ...
    'ColumnEditable', [false, false, false, true, true, true, true, true], ...
    'ColumnFormat', {'char', 'char', 'char', 'numeric', 'numeric', 'numeric', 'logical', 'char'}, ...
    'ColumnWidth', {'auto', 75, 65, 65, 60, 60, 42, 100}, ...
    'Tooltip', 'Constraint column: leave empty for a free parameter. Enter an expression like "2*p1" or "p1+p2" to constrain this parameter to the others.', ...
    'Data', {});
tblCFParams.Layout.Row = 4;

% ── Row 5: Stats label + action buttons ──────────────────────────────
cfBottomGL = uigridlayout(cfRootGL, [1 6], ...
    'ColumnWidth', {'2x', 75, 60, 85, 65, 85}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 6);
cfBottomGL.Layout.Row = 5;

lblCFStats = uilabel(cfBottomGL, 'Text', '', ...
    'FontSize', 10, 'FontColor', [0.6 0.6 0.6], ...
    'Interpreter', 'html');
lblCFStats.Layout.Column = 1;

% Confidence bands controls
cbShowBands = uicheckbox(cfBottomGL, 'Text', 'Show Bands', ...
    'FontSize', 9, ...
    'Tooltip', 'Overlay confidence and prediction bands on the fit curve', ...
    'Value', false, ...
    'ValueChangedFcn', @(~,~) onShowBandsChanged());
cbShowBands.Layout.Column = 2;

ddCFBandLevel = uidropdown(cfBottomGL, ...
    'Items', {'90%', '95%', '99%'}, ...
    'Value', '95%', 'FontSize', 9, ...
    'Tooltip', 'Confidence level for CI and PI bands', ...
    'ValueChangedFcn', @(~,~) onShowBandsChanged());
ddCFBandLevel.Layout.Column = 3;

uibutton(cfBottomGL, 'Text', 'Plot on Main', ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
    'FontSize', 9, ...
    'Tooltip', 'Overlay fit curve on the main BosonPlotter axes', ...
    'ButtonPushedFcn', @(~,~) onCFPlotOnMain());
uibutton(cfBottomGL, 'Text', 'Copy', ...
    'FontSize', 9, ...
    'Tooltip', 'Copy fit results to clipboard', ...
    'ButtonPushedFcn', @(~,~) onCFCopyResults());
uibutton(cfBottomGL, 'Text', 'Close', ...
    'FontSize', 9, ...
    'ButtonPushedFcn', @(~,~) onCFClose());

% ── Row 6: Secondary actions + extended stats ────────────────────────
cfBottom2GL = uigridlayout(cfRootGL, [1 5], ...
    'ColumnWidth', {'2x', 85, 100, 80, 95}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 6);
cfBottom2GL.Layout.Row = 6;

lblCFStats2 = uilabel(cfBottom2GL, 'Text', '', ...
    'FontSize', 9, 'FontColor', [0.5 0.5 0.5], ...
    'Interpreter', 'html');
lblCFStats2.Layout.Column = 1;

uibutton(cfBottom2GL, 'Text', 'Diagnostics', ...
    'FontSize', 9, ...
    'Tooltip', 'Open residual diagnostics window (Q-Q, runs, DW, summary)', ...
    'ButtonPushedFcn', @(~,~) onCFDiagnostics());
uibutton(cfBottom2GL, 'Text', 'Compare Models', ...
    'FontSize', 9, ...
    'Tooltip', 'Show table comparing up to 5 stored fit results (AIC, BIC, adj-R², F-test)', ...
    'ButtonPushedFcn', @(~,~) onCompareModels());
uibutton(cfBottom2GL, 'Text', 'Global Fit', ...
    'BackgroundColor', [0.10 0.35 0.55], 'FontColor', [1 1 1], ...
    'FontSize', 9, ...
    'Tooltip', 'Fit the same model to multiple datasets with shared parameter constraints', ...
    'ButtonPushedFcn', @(~,~) onGlobalFit());
uibutton(cfBottom2GL, 'Text', 'Sample Posterior', ...
    'BackgroundColor', [0.45 0.25 0.55], 'FontColor', [1 1 1], ...
    'FontSize', 9, ...
    'Tooltip', ['MCMC-sample the posterior around the current fit and ' ...
                'show a corner plot. Run Fit first.'], ...
    'ButtonPushedFcn', @(~,~) onCFMCMCSample());

% Cursor state (created after axes exist; [] when cursors are off or removed)
cfCursors = [];

% State for fit results
cfResult = struct('params', [], 'errors', [], 'model', '', ...
    'xFit', [], 'yFit', [], 'R2', NaN, 'RMSE', NaN, ...
    'chiSqRed', NaN, 'AIC', NaN, 'paramNames', {{}}, 'residuals', [], ...
    'covar', [], 'nPoints', 0, 'nFree', 0, 'modelFcn', [], ...
    'bands', []);  % bands struct from fitting.fitBands (empty until computed)

% History for model comparison (stores last 5 fit snapshots)
cfHistory = {};   % cell array of structs; newest at end

% Initialise parameter table for the default model
onCFModelChanged();

% Initialise draggable cursors on the fit axes
cfCursors = bosonPlotter.fitCursors(cfAxFit, ...
    efCFXmin.Value, efCFXmax.Value, @onCursorRangeChanged);

% Remove cursors when the dialog closes
cfFig.CloseRequestFcn = @(~,~) onCFClose();

% ════════════════════════════════════════════════════════════════════════
% Nested functions
% ════════════════════════════════════════════════════════════════════════

    function onCFCategoryChanged()
    %ONCFCATEGORYCHANGED  Filter model dropdown by selected category.
        cat = ddCFCat.Value;
        if strcmp(cat, 'All')
            filtered = {catalog.name};
        elseif strcmp(cat, 'Custom')
            filtered = {'Custom Equation'};
        else
            mask = strcmp({catalog.category}, cat);
            filtered = {catalog(mask).name};
        end
        ddCFModel.Items = filtered;
        if ~isempty(filtered)
            ddCFModel.Value = filtered{1};
        end
        onCFModelChanged();
    end

    function onCFModelChanged()
    %ONCFMODELCHANGED  Update equation display and parameter table for selected model.
        modelName = ddCFModel.Value;

        if strcmp(modelName, 'Custom Equation')
            % Custom mode: show whatever was last parsed
            if ~isempty(customFcn) && ~isempty(customNames)
                populateTable(customNames, zeros(1, numel(customNames)), ...
                    repmat(-Inf, 1, numel(customNames)), ...
                    repmat(Inf, 1, numel(customNames)));
                lblCFEqn.Text = efCFCustom.Value;
            else
                tblCFParams.Data = {};
                lblCFEqn.Text = 'Enter equation and click Parse';
            end
            return;
        end

        idx = find(strcmp({catalog.name}, modelName), 1);
        if isempty(idx), return; end
        activeModel = catalog(idx);
        lblCFEqn.Text = activeModel.equation;
        populateTable(activeModel.paramNames, activeModel.p0, ...
            activeModel.lb, activeModel.ub);
    end

    function populateTable(pNames, p0, lb, ub)
    %POPULATETABLE  Fill parameter table with names, defaults, bounds.
        nP = numel(pNames);
        tblData = cell(nP, 8);
        for pi = 1:nP
            tblData{pi, 1} = pNames{pi};       % Name
            tblData{pi, 2} = '';                % Value (fitted)
            tblData{pi, 3} = '';                % Error
            tblData{pi, 4} = p0(pi);            % Guess
            tblData{pi, 5} = lb(pi);            % Lower bound
            tblData{pi, 6} = ub(pi);            % Upper bound
            tblData{pi, 7} = false;             % Fixed
            tblData{pi, 8} = '';                % Constraint expression (empty = free)
        end
        tblCFParams.Data = tblData;
    end

    function [fcn, pNames, p0, lb, ub, fixedMask, constraintExprs] = resolveModel()
    %RESOLVEMODEL  Get current model function, params, bounds, constraints from UI state.
        modelName = ddCFModel.Value;

        if strcmp(modelName, 'Custom Equation')
            if isempty(customFcn)
                error('bosonPlotter:curveFitting:noCustom', ...
                    'No custom equation parsed. Click Parse first.');
            end
            fcn = customFcn;
            pNames = customNames;
        else
            idx = find(strcmp({catalog.name}, modelName), 1);
            m = catalog(idx);
            % Model library uses f(x,p), fitting.curveFit expects f(x,p)
            fcn = m.fcn;
            pNames = m.paramNames;
        end

        nP = numel(pNames);
        p0 = zeros(1, nP);
        lb = repmat(-Inf, 1, nP);
        ub = repmat(Inf, 1, nP);
        fixedMask = false(1, nP);
        constraintExprs = repmat({''}, 1, nP);

        nRows = size(tblCFParams.Data, 1);
        for pi = 1:nP
            if pi > nRows, break; end
            p0(pi)        = readNumericCell(tblCFParams.Data{pi, 4}, 0);
            lb(pi)        = readNumericCell(tblCFParams.Data{pi, 5}, -Inf);
            ub(pi)        = readNumericCell(tblCFParams.Data{pi, 6}, Inf);
            fixedMask(pi) = logical(tblCFParams.Data{pi, 7});
            if size(tblCFParams.Data, 2) >= 8
                raw = tblCFParams.Data{pi, 8};
                if ischar(raw) || isstring(raw)
                    constraintExprs{pi} = strtrim(char(raw));
                end
            end
        end
    end

    function v = readNumericCell(val, default)
    %READNUMERICCELL  Safely extract a numeric value from a table cell.
        if isnumeric(val) && ~isempty(val)
            v = val;
        elseif ischar(val) || isstring(val)
            v = str2double(val);
            if isnan(v), v = default; end
        else
            v = default;
        end
    end

    function [xSeg, ySeg] = getDataSegment()
    %GETDATASEGMENT  Get x/y data within the current X-range and channel.
        ch = ddCFCh.Value;
        xAll = plotD.time;
        yAll = plotD.values(:, ch);
        mask = xAll >= efCFXmin.Value & xAll <= efCFXmax.Value;
        xSeg = xAll(mask);
        ySeg = yAll(mask);
    end

    function w = getWeights(ySeg)
    %GETWEIGHTS  Compute weight vector from dropdown selection.
        switch ddCFWeights.Value
            case 'None'
                w = [];
            case '1/y'
                w = 1 ./ max(abs(ySeg), eps);
            case '1/y²'
                w = 1 ./ max(ySeg.^2, eps);
            case '1/σ²'
                % Use 1/y as a proxy (Poisson-like counting statistics)
                w = 1 ./ max(abs(ySeg), eps);
        end
    end

    function onAutoGuess()
    %ONAUTOGUESS  Fill initial guesses from data shape using fitting.autoGuess.
        modelName = ddCFModel.Value;
        if strcmp(modelName, 'Custom Equation'), return; end

        [xSeg, ySeg] = getDataSegment();
        if numel(xSeg) < 3, return; end

        try
            p0g = fitting.autoGuess(modelName, xSeg, ySeg);
            nP = size(tblCFParams.Data, 1);
            for pi = 1:min(numel(p0g), nP)
                tblCFParams.Data{pi, 4} = p0g(pi);
            end
            options.StatusFcn('Auto-guess applied');
        catch ME
            options.StatusFcn(sprintf('Auto-guess failed: %s', ME.message));
        end
    end

    function onParseCustom()
    %ONPARSECUSTOM  Parse the custom equation string.
        eqn = strtrim(efCFCustom.Value);
        if isempty(eqn)
            uialert(cfFig, 'Enter an equation first.', 'Parse Error');
            return;
        end
        try
            [customFcn, customNames] = fitting.parseEquation(eqn);
            ddCFCat.Value = 'Custom';
            ddCFModel.Items = {'Custom Equation'};
            ddCFModel.Value = 'Custom Equation';
            lblCFEqn.Text = eqn;
            populateTable(customNames, zeros(1, numel(customNames)), ...
                repmat(-Inf, 1, numel(customNames)), ...
                repmat(Inf, 1, numel(customNames)));
            options.StatusFcn(sprintf('Parsed: %d parameters (%s)', ...
                numel(customNames), strjoin(customNames, ', ')));
        catch ME
            uialert(cfFig, sprintf('Parse error:\n%s', ME.message), 'Parse Error');
        end
    end

    function doSimulate()
    %DOSIMULATE  Preview model curve with current parameter values (no fitting).
        [xSeg, ySeg] = getDataSegment();
        if numel(xSeg) < 2
            uialert(cfFig, 'Not enough data in range.', 'Simulate');
            return;
        end

        try
            [fcn, ~, p0, ~, ~, ~, ~] = resolveModel();
        catch ME
            uialert(cfFig, ME.message, 'Simulate Error');
            return;
        end

        xFit = linspace(min(xSeg), max(xSeg), 500)';
        yFit = fcn(xFit, p0);

        % Plot
        cla(cfAxFit);
        plot(cfAxFit, xSeg, ySeg, 'k.', 'MarkerSize', 4);
        hold(cfAxFit, 'on');
        plot(cfAxFit, xFit, yFit, 'b--', 'LineWidth', 1.2);
        hold(cfAxFit, 'off');
        legend(cfAxFit, {'Data', 'Simulation'}, 'Location', 'best');
        title(cfAxFit, 'Simulation (no fit)');
        cfAxFit.Box = 'on'; grid(cfAxFit, 'on');

        cla(cfAxRes);
        title(cfAxRes, 'Residuals (run Fit first)');
        options.StatusFcn('Simulation plotted');
    end

    function doCurveFit()
    %DOCURVEFIT  Execute the curve fit via fitting.curveFit.
        [xSeg, ySeg] = getDataSegment();
        if numel(xSeg) < 3
            uialert(cfFig, 'Not enough data in range.', 'Fit Error');
            return;
        end

        try
            [fcn, pNames, p0, lb, ub, fixedMask, constraintExprs] = resolveModel();
        catch ME
            uialert(cfFig, ME.message, 'Fit Error');
            return;
        end

        w = getWeights(ySeg);

        % Determine if any constraint expressions are non-empty
        hasConstraints = any(~cellfun(@isempty, constraintExprs));

        cfFig.Pointer = 'watch'; drawnow;
        try
            % Sync dialog state into the workshop model so model.fit is
            % the canonical entry point (testable + scriptable). The
            % model holds its own copy of params/result; dialog widgets
            % keep their existing data for now.
            cfModel.modelName = ddCFModel.Value;
            if strcmp(cfModel.modelName, 'Custom Equation')
                cfModel.customFcn   = customFcn;
                cfModel.customNames = customNames;
            end
            cfModel.params = bosonPlotter.curveFit.CurveFitWorkshopModel.makeParamArray(pNames);
            for pi = 1:numel(pNames)
                cfModel.params(pi).p0         = p0(pi);
                cfModel.params(pi).lb         = lb(pi);
                cfModel.params(pi).ub         = ub(pi);
                cfModel.params(pi).fixed      = fixedMask(pi);
                cfModel.params(pi).constraint = constraintExprs{pi};
            end
            res = cfModel.fit(xSeg, ySeg, w);

            % Dense x grid for smooth fit curve display
            xFit = linspace(min(xSeg), max(xSeg), 500)';
            yFit = fcn(xFit, res.params);

            % Store result
            cfResult.params     = res.params;
            cfResult.errors     = res.errors;
            cfResult.model      = ddCFModel.Value;
            cfResult.xFit       = xFit;
            cfResult.yFit       = yFit;
            cfResult.R2         = res.R2;
            cfResult.RMSE       = res.RMSE;
            cfResult.chiSqRed   = res.chiSqRed;
            cfResult.AIC        = res.AIC;
            cfResult.paramNames = pNames;
            cfResult.residuals  = res.residuals;
            cfResult.covar      = res.covar;
            cfResult.nPoints    = res.nPoints;
            cfResult.nFree      = res.nFree;
            cfResult.modelFcn   = fcn;
            cfResult.bands      = [];  % cleared; recomputed by onShowBandsChanged

            % Update parameter table with fitted values and errors
            for pi = 1:numel(pNames)
                tblCFParams.Data{pi, 2} = sprintf('%.6g', res.params(pi));
                if isfinite(res.errors(pi))
                    tblCFParams.Data{pi, 3} = sprintf('%.3g', res.errors(pi));
                else
                    tblCFParams.Data{pi, 3} = '—';
                end
            end

            % Plot fit (bands rendered separately via onShowBandsChanged)
            renderFitAxes(xSeg, ySeg, xFit, yFit, []);
            if cbShowBands.Value
                onShowBandsChanged();
            end

            % Plot residuals
            cla(cfAxRes);
            stem(cfAxRes, xSeg, res.residuals, 'b.', 'MarkerSize', 3);
            hold(cfAxRes, 'on');
            yline(cfAxRes, 0, 'k--');
            hold(cfAxRes, 'off');
            title(cfAxRes, sprintf('Residuals (RMSE = %.4g)', res.RMSE));
            cfAxRes.Box = 'on'; grid(cfAxRes, 'on');

            % Durbin-Watson for inline stats
            dwVal = sum(diff(res.residuals).^2) / max(sum(res.residuals.^2), eps);

            % Extended comparison metrics
            cmpM = fitting.fitCompare(ySeg, res.residuals, res.nFree);

            % Stats labels
            lblCFStats.Text = sprintf( ...
                'R%s = <b>%.6f</b> &nbsp; adj-R%s = %.6f &nbsp; RMSE = %.4g &nbsp; DW = %.3f &nbsp; N = %d', ...
                char(178), res.R2, char(178), cmpM.adjR2, res.RMSE, dwVal, res.nPoints);
            lblCFStats2.Text = sprintf( ...
                '%s%s = %.4g &nbsp; AIC = %.1f &nbsp; AICc = %.1f &nbsp; BIC = %.1f &nbsp; Free = %d/%d &nbsp; Exit = %d', ...
                char(967), char(178), res.chiSqRed, cmpM.aic, cmpM.aicc, cmpM.bic, ...
                res.nFree, numel(pNames), res.exitFlag);

            % Push snapshot to history (keep last 5)
            snap.model    = ddCFModel.Value;
            snap.R2       = res.R2;
            snap.adjR2    = cmpM.adjR2;
            snap.aic      = cmpM.aic;
            snap.aicc     = cmpM.aicc;
            snap.bic      = cmpM.bic;
            snap.rmse     = res.RMSE;
            snap.nParams  = res.nFree;
            snap.nPoints  = res.nPoints;
            snap.residuals = res.residuals;
            cfHistory{end+1} = snap;
            if numel(cfHistory) > 5
                cfHistory = cfHistory(end-4:end);  % keep newest 5
            end

            cfFig.Pointer = 'arrow';
            options.StatusFcn(sprintf('Fit: %s  R%s=%.6f', ...
                cfResult.model, char(178), res.R2));
        catch ME
            cfFig.Pointer = 'arrow';
            uialert(cfFig, sprintf('Fit failed:\n%s', ME.message), 'Error');
        end
    end

    function renderFitAxes(xSeg, ySeg, xFit, yFit, bands)
    %RENDERFITAXES  Draw data + fit curve (+ optional bands) on cfAxFit.
        cla(cfAxFit);
        hold(cfAxFit, 'on');

        % CI band (darker shade)
        if ~isempty(bands) && ~all(isnan(bands.ciLo))
            xPatch = [xFit; flipud(xFit)];
            yPatch = [bands.ciLo; flipud(bands.ciHi)];
            fill(cfAxFit, xPatch, yPatch, [0.2 0.5 0.9], ...
                'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
                'DisplayName', sprintf('%.0f%% CI', bands.level*100), ...
                'HandleVisibility', 'on');
        end

        % PI band (lighter shade)
        if ~isempty(bands) && ~all(isnan(bands.piLo))
            xPatch = [xFit; flipud(xFit)];
            yPatch = [bands.piLo; flipud(bands.piHi)];
            fill(cfAxFit, xPatch, yPatch, [0.6 0.8 1.0], ...
                'FaceAlpha', 0.18, 'EdgeColor', 'none', ...
                'DisplayName', sprintf('%.0f%% PI', bands.level*100), ...
                'HandleVisibility', 'on');
        end

        plot(cfAxFit, xSeg, ySeg, 'k.', 'MarkerSize', 4, ...
            'DisplayName', 'Data', 'HandleVisibility', 'on');
        plot(cfAxFit, xFit, yFit, 'r-', 'LineWidth', 1.5, ...
            'DisplayName', 'Fit', 'HandleVisibility', 'on');

        hold(cfAxFit, 'off');
        legend(cfAxFit, 'Location', 'best');
        title(cfAxFit, sprintf('%s  (R%s = %.6f)', ...
            cfResult.model, char(178), cfResult.R2));
        cfAxFit.Box = 'on'; grid(cfAxFit, 'on');
    end

    function onShowBandsChanged()
    %ONSHOWBANDSCHANGED  Recompute and render bands when checkbox or level changes.
        if isempty(cfResult.xFit), return; end

        [xSeg, ySeg] = getDataSegment();
        bands = [];

        if cbShowBands.Value && ~isempty(cfResult.covar) && cfResult.nFree > 0
            levelStr = ddCFBandLevel.Value;
            switch levelStr
                case '90%', level = 0.90;
                case '99%', level = 0.99;
                otherwise,  level = 0.95;
            end
            try
                bands = fitting.fitBands(cfResult.xFit, cfResult.modelFcn, ...
                    cfResult.params(:), cfResult.covar, ...
                    cfResult.nPoints, cfResult.nFree, Level=level);
                cfResult.bands = bands;
            catch ME
                options.StatusFcn(sprintf('Bands failed: %s', ME.message));
                cfResult.bands = [];
            end
        else
            cfResult.bands = [];
        end

        renderFitAxes(xSeg, ySeg, cfResult.xFit, cfResult.yFit, cfResult.bands);
    end

    function onCFPlotOnMain()
    %ONCFPLOTONMAIN  Overlay the fit curve (and optional bands) on the main axes.
        if isempty(cfResult.xFit), return; end
        hold(mainAx, 'on');

        % CI band on main axes
        if ~isempty(cfResult.bands) && ~all(isnan(cfResult.bands.ciLo))
            xPatch = [cfResult.xFit; flipud(cfResult.xFit)];
            fill(mainAx, xPatch, ...
                [cfResult.bands.ciLo; flipud(cfResult.bands.ciHi)], ...
                [0.2 0.5 0.9], 'FaceAlpha', 0.22, 'EdgeColor', 'none', ...
                'DisplayName', sprintf('%.0f%% CI', cfResult.bands.level*100), ...
                'HandleVisibility', 'on', 'Tag', 'curveFitBandCI');
        end

        % PI band on main axes
        if ~isempty(cfResult.bands) && ~all(isnan(cfResult.bands.piLo))
            xPatch = [cfResult.xFit; flipud(cfResult.xFit)];
            fill(mainAx, xPatch, ...
                [cfResult.bands.piLo; flipud(cfResult.bands.piHi)], ...
                [0.6 0.8 1.0], 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                'DisplayName', sprintf('%.0f%% PI', cfResult.bands.level*100), ...
                'HandleVisibility', 'on', 'Tag', 'curveFitBandPI');
        end

        plot(mainAx, cfResult.xFit, cfResult.yFit, 'r-', 'LineWidth', 1.5, ...
            'DisplayName', sprintf('%s fit (R%s=%.4f)', ...
                cfResult.model, char(178), cfResult.R2), ...
            'HandleVisibility', 'on', 'Tag', 'curveFitOverlay');
        hold(mainAx, 'off');
        % Add full fit results text box (parameters + errors + metrics)
        delete(findobj(mainAx, 'Tag', 'curveFitLabel'));
        resultsTxt = bosonPlotter.formatFitResultsText(cfResult);
        text(mainAx, 0.02, 0.95, resultsTxt, ...
            'Units', 'normalized', 'FontSize', 8, 'FontName', 'FixedWidth', ...
            'Color', [0.1 0.1 0.1], 'BackgroundColor', [1 1 1 0.85], ...
            'EdgeColor', [0.6 0.6 0.6], 'Margin', 4, ...
            'VerticalAlignment', 'top', ...
            'HandleVisibility', 'off', 'Tag', 'curveFitLabel');
        options.StatusFcn(sprintf('Fit overlaid: %s (R%s=%.6f)', ...
            cfResult.model, char(178), cfResult.R2));
    end

    function onCFDiagnostics()
    %ONCFDIAGNOSTICS  Open residual diagnostics window for the last fit.
        if isempty(cfResult.residuals)
            uialert(cfFig, 'Run a fit first.', 'Diagnostics');
            return
        end

        d = fitting.residualDiagnostics(cfResult.residuals);

        diagFig = figure('Name', sprintf('Residual Diagnostics — %s', cfResult.model), ...
            'NumberTitle', 'off', 'Color', [1 1 1], ...
            'Position', [250 120 820 600]);

        % ── Subplot 1: Q-Q plot ──────────────────────────────────────
        ax1 = subplot(2, 2, 1, 'Parent', diagFig);
        plot(ax1, d.qqX, d.qqY, 'b.', 'MarkerSize', 5);
        hold(ax1, 'on');
        qlim = [min(d.qqX) max(d.qqX)];
        plot(ax1, qlim, qlim, 'r--', 'LineWidth', 1.2);
        hold(ax1, 'off');
        xlabel(ax1, 'Theoretical Quantiles');
        ylabel(ax1, 'Sample Quantiles');
        title(ax1, 'Normal Q-Q Plot');
        grid(ax1, 'on'); box(ax1, 'on');

        % ── Subplot 2: Residuals vs X (data-point order) ────────────
        ax2 = subplot(2, 2, 2, 'Parent', diagFig);
        [xSeg, ~] = getDataSegment();
        plot(ax2, xSeg, cfResult.residuals, 'b.', 'MarkerSize', 5);
        hold(ax2, 'on');
        yline(ax2, 0, 'r--');
        hold(ax2, 'off');
        xlabel(ax2, 'X (data points)');
        ylabel(ax2, 'Residual');
        title(ax2, sprintf('Residuals vs X  (RMSE = %.4g)', cfResult.RMSE));
        grid(ax2, 'on'); box(ax2, 'on');

        % ── Subplot 3: Residuals vs order, runs colour-coded ─────────
        ax3 = subplot(2, 2, 3, 'Parent', diagFig);
        r = cfResult.residuals;
        nR = numel(r);
        hold(ax3, 'on');
        % Compute run membership
        signs = r >= 0;
        runId = cumsum([true; signs(1:end-1) ~= signs(2:end)]);
        isOdd = mod(runId, 2) == 1;
        % Plot positive/negative runs in alternating colours
        plot(ax3, find(isOdd),  r(isOdd),  'b.', 'MarkerSize', 6);
        plot(ax3, find(~isOdd), r(~isOdd), 'm.', 'MarkerSize', 6);
        yline(ax3, 0, 'k--');
        hold(ax3, 'off');
        xlabel(ax3, 'Observation Order');
        ylabel(ax3, 'Residual');
        if isnan(d.runsTestP)
            runTitle = sprintf('Residuals vs Order  (nRuns = %d)', d.nRuns);
        else
            runTitle = sprintf('Residuals vs Order  (nRuns = %d, p = %.3f)', ...
                d.nRuns, d.runsTestP);
        end
        title(ax3, runTitle);
        legend(ax3, {'Run (odd)', 'Run (even)'}, 'Location', 'best', 'FontSize', 7);
        grid(ax3, 'on'); box(ax3, 'on');

        % ── Subplot 4: Text summary ──────────────────────────────────
        ax4 = subplot(2, 2, 4, 'Parent', diagFig);
        axis(ax4, 'off');
        summaryLines = strsplit(d.summary, newline);
        nLines = numel(summaryLines);
        yStep  = 0.9 / max(nLines, 1);
        for li = 1:nLines
            text(ax4, 0.04, 0.95 - (li-1)*yStep, summaryLines{li}, ...
                'Units', 'normalized', 'FontSize', 9, ...
                'VerticalAlignment', 'top', 'Interpreter', 'none');
        end
        title(ax4, 'Diagnostic Summary');
    end

    function onCFCopyResults()
    %ONCFCOPYRESULTS  Copy fit parameters, errors, and statistics to clipboard.
        if isnan(cfResult.R2), return; end
        lines = {};
        lines{end+1} = sprintf('Model: %s', cfResult.model);
        lines{end+1} = sprintf('R² = %.8f', cfResult.R2);
        lines{end+1} = sprintf('RMSE = %.6g', cfResult.RMSE);
        lines{end+1} = sprintf('χ²_red = %.6g', cfResult.chiSqRed);
        lines{end+1} = sprintf('AIC = %.2f', cfResult.AIC);
        lines{end+1} = 'Parameters:';
        for pi = 1:numel(cfResult.paramNames)
            if isfinite(cfResult.errors(pi))
                lines{end+1} = sprintf('  %s = %.8g ± %.4g', ...
                    cfResult.paramNames{pi}, cfResult.params(pi), cfResult.errors(pi)); %#ok<AGROW>
            else
                lines{end+1} = sprintf('  %s = %.8g', ...
                    cfResult.paramNames{pi}, cfResult.params(pi)); %#ok<AGROW>
            end
        end
        clipboard('copy', strjoin(lines, newline));
        options.StatusFcn('Fit results copied to clipboard');
    end

    function onCFClose()
    %ONCFCLOSE  Clean up cursors then delete the dialog.
        if ~isempty(cfCursors) && isfield(cfCursors, 'remove')
            try
                cfCursors.remove();
            catch
            end
        end
        cfCursors = [];
        if isvalid(cfFig)
            delete(cfFig);
        end
    end

    function onCFCursorsToggled()
    %ONCFCURSORSTOGGLED  Show or hide the draggable cursors.
        if cbCFCursors.Value
            % Create cursors if not already present
            if isempty(cfCursors)
                cfCursors = bosonPlotter.fitCursors(cfAxFit, ...
                    efCFXmin.Value, efCFXmax.Value, @onCursorRangeChanged);
            end
        else
            % Remove cursors
            if ~isempty(cfCursors) && isfield(cfCursors, 'remove')
                cfCursors.remove();
                cfCursors = [];
            end
        end
    end

    function onCursorRangeChanged(xL, xR)
    %ONCURSORRANGECHANGED  Sync edit fields when a cursor is dragged.
        efCFXmin.Value = xL;
        efCFXmax.Value = xR;
        options.StatusFcn(sprintf('Fit range: [%.4g, %.4g]', xL, xR));
    end

    function onXRangeEdited()
    %ONXRANGEEDITED  Move cursors when the user edits the X min/max fields.
        if ~isempty(cfCursors) && isfield(cfCursors, 'setRange')
            xL = efCFXmin.Value;
            xR = efCFXmax.Value;
            if xL < xR
                cfCursors.setRange(xL, xR);
            end
        end
    end

    cfPickState = struct('which', '', 'savedWBDF', '');
    mainFig     = ancestor(mainAx, 'matlab.ui.Figure');

    function cfPickXRange(which)
    %CFPICKXRANGE  Click on the main axes to set X min or max.
    %   Temporarily hides cfFig so the main plot is accessible.
        cfFig.Visible = 'off';
        mainFig.Pointer = 'crosshair';
        options.StatusFcn(sprintf('Click on the plot to set X %s...', which));
        cfPickState.which     = which;
        cfPickState.savedWBDF = mainFig.WindowButtonDownFcn;
        mainFig.WindowButtonDownFcn = @(~,~) cfCaptureX();
    end

    function cfCaptureX()
        cp = mainAx.CurrentPoint;
        xClick = cp(1,1);  yClick = cp(1,2);
        xl = mainAx.XLim;  yl = mainAx.YLim;
        if xClick < xl(1) || xClick > xl(2) || yClick < yl(1) || yClick > yl(2)
            return;
        end
        switch cfPickState.which
            case 'min', efCFXmin.Value = xClick;
            case 'max', efCFXmax.Value = xClick;
        end
        mainFig.WindowButtonDownFcn = cfPickState.savedWBDF;
        mainFig.Pointer = 'arrow';
        cfFig.Visible = 'on';
        figure(cfFig);
        options.StatusFcn(sprintf('X %s set to %.4g', cfPickState.which, xClick));
    end

    function onCompareModels()
    %ONCOMPAREMODELS  Open a figure showing a comparison table of stored fits.
    %   Highlights the best model (lowest AIC).
    %   If exactly 2 models are in history, also shows F-test result.
        if isempty(cfHistory)
            uialert(cfFig, 'No fit history yet. Run at least one fit first.', ...
                'Compare Models');
            return;
        end

        nH = numel(cfHistory);

        % ── Build table data ──────────────────────────────────────────
        colNames = {'#', 'Model', 'R²', 'adj-R²', 'AIC', 'AICc', 'BIC', ...
            'RMSE', 'Params', 'N'};
        tData = cell(nH, numel(colNames));
        aicVals = zeros(1, nH);
        for hi = 1:nH
            s = cfHistory{hi};
            aicVals(hi) = s.aic;
            tData{hi,1}  = hi;
            tData{hi,2}  = s.model;
            tData{hi,3}  = sprintf('%.6f', s.R2);
            tData{hi,4}  = sprintf('%.6f', s.adjR2);
            tData{hi,5}  = sprintf('%.2f', s.aic);
            tData{hi,6}  = sprintf('%.2f', s.aicc);
            tData{hi,7}  = sprintf('%.2f', s.bic);
            tData{hi,8}  = sprintf('%.4g',  s.rmse);
            tData{hi,9}  = s.nParams;
            tData{hi,10} = s.nPoints;
        end

        % Find best model (lowest AIC, ignoring -Inf from perfect fits)
        finiteAIC = aicVals;
        finiteAIC(~isfinite(aicVals)) = Inf;
        [~, bestIdx] = min(finiteAIC);

        % ── F-test between 2 models (if exactly 2 in history) ─────────
        fLine = '';
        if nH == 2
            s1 = cfHistory{1};
            s2 = cfHistory{2};
            % Compare the model with more params against the simpler one
            if s1.nParams ~= s2.nParams && s1.nPoints == s2.nPoints
                if s1.nParams > s2.nParams
                    full = s1; ref = s2;
                else
                    full = s2; ref = s1;
                end
                try
                    mF = fitting.fitCompare(zeros(full.nPoints,1), full.residuals, ...
                        full.nParams, ResidRef=ref.residuals, NParamsRef=ref.nParams);
                    if ~isnan(mF.fStat)
                        fLine = sprintf('F(%d,%d) = %.3f   p = %.4f', ...
                            full.nParams - ref.nParams, ...
                            full.nPoints - full.nParams, ...
                            mF.fStat, mF.fPvalue);
                    end
                catch
                    fLine = 'F-test could not be computed';
                end
            else
                fLine = 'F-test requires 2 nested models with the same N';
            end
        end

        % ── Figure ────────────────────────────────────────────────────
        cmpFig = figure('Name', 'Model Comparison', ...
            'NumberTitle', 'off', 'Color', [1 1 1], ...
            'Position', [300 200 860 max(160, 80 + nH*22)]);

        % Table
        ax = axes(cmpFig, 'Visible', 'off', ...
            'Position', [0 0.2 1 0.75]);

        colWidths = [0.04, 0.20, 0.09, 0.09, 0.08, 0.08, 0.08, 0.08, 0.06, 0.06];
        xPos = cumsum([0.02, colWidths(1:end-1)]);

        % Header row
        for ci = 1:numel(colNames)
            text(ax, xPos(ci), 0.97, colNames{ci}, ...
                'Units', 'normalized', 'FontSize', 9, 'FontWeight', 'bold', ...
                'VerticalAlignment', 'top', 'Interpreter', 'none');
        end

        % Divider line
        annotation(cmpFig, 'line', [0.02 0.98], [0.92 0.92]);

        % Data rows
        rowH = 0.85 / max(nH, 1);
        for hi = 1:nH
            yRow = 0.90 - (hi-1) * rowH;
            isBest = (hi == bestIdx);
            if isBest
                annotation(cmpFig, 'rectangle', [0.01, yRow-0.01, 0.97, rowH], ...
                    'FaceColor', [0.85 1.0 0.85], 'EdgeColor', 'none');
            end
            for ci = 1:numel(colNames)
                val = tData{hi, ci};
                if isnumeric(val)
                    txt = num2str(val);
                else
                    txt = val;
                end
                textColor = [0 0 0];
                if isBest && (ci == 5 || ci == 6 || ci == 7)
                    textColor = [0 0.5 0];  % green for best AIC/AICc/BIC
                end
                text(ax, xPos(ci), yRow, txt, ...
                    'Units', 'normalized', 'FontSize', 9, ...
                    'VerticalAlignment', 'top', 'Interpreter', 'none', ...
                    'Color', textColor);
            end
        end

        % Legend
        annotation(cmpFig, 'rectangle', [0.01, 0.13, 0.15, 0.04], ...
            'FaceColor', [0.85 1.0 0.85], 'EdgeColor', [0 0.5 0]);
        annotation(cmpFig, 'textbox', [0.17, 0.12, 0.80, 0.05], ...
            'String', sprintf('Best model by AIC: #%d (%s)', bestIdx, ...
                cfHistory{bestIdx}.model), ...
            'EdgeColor', 'none', 'FontSize', 9, 'FitBoxToText', 'on');

        % F-test line (if available)
        if ~isempty(fLine)
            annotation(cmpFig, 'textbox', [0.02, 0.03, 0.96, 0.08], ...
                'String', ['F-test: ', fLine], ...
                'EdgeColor', [0.7 0.7 0.7], 'FontSize', 9, ...
                'FitBoxToText', 'off', 'BackgroundColor', [0.97 0.97 0.97]);
        end

        options.StatusFcn(sprintf('Model comparison: %d fits — best by AIC: %s', ...
            nH, cfHistory{bestIdx}.model));
    end

% ════════════════════════════════════════════════════════════════════════

    function onGlobalFit()
    %ONGLOBALFIT  Open the Global Fit configuration dialog.
    %
    %   Lets the user select multiple loaded datasets, choose a model,
    %   and mark which parameters should be shared across datasets.
    %   Calls fitting.globalCurveFit and displays results.

        if numel(datasets) < 2
            uialert(cfFig, ...
                sprintf('Global Fit requires at least 2 loaded datasets (have %d).', ...
                    numel(datasets)), 'Global Fit');
            return;
        end

        % ── Resolve current model ──────────────────────────────────────
        try
            [gfcn, gParamNames, gP0, gLb, gUb, ~] = resolveModel();
        catch ME
            uialert(cfFig, sprintf('Resolve model failed:\n%s', ME.message), ...
                'Global Fit');
            return;
        end
        nP = numel(gParamNames);

        % ── Build dialog ───────────────────────────────────────────────
        gfFig = uifigure('Name', 'Global Fit', ...
            'Position', [220 100 560 480], 'Resize', 'off');

        gfGL = uigridlayout(gfFig, [5 1], ...
            'RowHeight', {22, '1x', '1x', 28, 22}, ...
            'Padding', [10 8 10 8], 'RowSpacing', 6);

        % Info label
        uilabel(gfGL, ...
            'Text', sprintf('Model: %s  (%d params)', ddCFModel.Value, nP), ...
            'FontWeight', 'bold');

        % ── Dataset selection ──────────────────────────────────────────
        dsPanel = uipanel(gfGL, 'Title', 'Select Datasets', ...
            'FontSize', 10);

        dsGL = uigridlayout(dsPanel, [1 1], 'Padding', [4 4 4 4]);
        dsNames = cell(1, numel(datasets));
        for di = 1:numel(datasets)
            nm = '';
            if isfield(datasets{di}, 'label') && ~isempty(datasets{di}.label)
                nm = datasets{di}.label;
            elseif isfield(datasets{di}, 'filename') && ~isempty(datasets{di}.filename)
                [~, nm, ext] = fileparts(datasets{di}.filename);
                nm = [nm ext]; %#ok<AGROW>
            end
            if isempty(nm)
                nm = sprintf('Dataset %d', di);
            end
            dsNames{di} = sprintf('[%d] %s', di, nm);
        end

        lbDS = uilistbox(dsGL, 'Items', dsNames, ...
            'Multiselect', 'on', ...
            'Value', dsNames(max(1, activeIdx - 1) : min(end, activeIdx + 1)));

        % ── Shared parameter table ─────────────────────────────────────
        shPanel = uipanel(gfGL, 'Title', 'Shared Parameters', ...
            'FontSize', 10);

        shGL = uigridlayout(shPanel, [1 1], 'Padding', [4 4 4 4]);
        shTbl = uitable(shGL, ...
            'ColumnName', {'Parameter', 'Shared?', 'Guess', 'Lower', 'Upper'}, ...
            'ColumnEditable', [false true true true true], ...
            'ColumnFormat', {'char', 'logical', 'numeric', 'numeric', 'numeric'}, ...
            'ColumnWidth', {'auto', 60, 65, 65, 65});

        shData = cell(nP, 5);
        for pi = 1:nP
            shData{pi, 1} = gParamNames{pi};
            shData{pi, 2} = false;           % not shared by default
            shData{pi, 3} = gP0(pi);
            shData{pi, 4} = gLb(pi);
            shData{pi, 5} = gUb(pi);
        end
        shTbl.Data = shData;

        % ── Action buttons ─────────────────────────────────────────────
        gfBtnGL = uigridlayout(gfGL, [1 3], ...
            'ColumnWidth', {'1x', '1x', '1x'}, ...
            'Padding', [0 0 0 0], 'ColumnSpacing', 8);

        uibutton(gfBtnGL, 'Text', 'Run Global Fit', ...
            'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
            'FontWeight', 'bold', ...
            'ButtonPushedFcn', @(~,~) doRunGlobalFit());

        uibutton(gfBtnGL, 'Text', 'Share All', ...
            'Tooltip', 'Mark all parameters as shared', ...
            'ButtonPushedFcn', @(~,~) setAllShared(true));

        uibutton(gfBtnGL, 'Text', 'Share None', ...
            'Tooltip', 'Clear all shared flags', ...
            'ButtonPushedFcn', @(~,~) setAllShared(false));

        % Status label
        lblGFStatus = uilabel(gfGL, 'Text', 'Select datasets and shared parameters, then click Run.', ...
            'FontSize', 9, 'FontColor', [0.5 0.5 0.5]);

        % ── Nested helpers ─────────────────────────────────────────────
        function setAllShared(val)
            for pi2 = 1:nP
                shTbl.Data{pi2, 2} = val;
            end
        end

        function doRunGlobalFit()
            % Identify selected dataset indices
            selItems = lbDS.Value;
            selIdx = zeros(1, numel(selItems));
            for si = 1:numel(selItems)
                selIdx(si) = find(strcmp(dsNames, selItems{si}), 1);
            end

            if numel(selIdx) < 2
                uialert(gfFig, 'Select at least 2 datasets.', 'Global Fit');
                return;
            end

            % Extract per-dataset data structs
            selDS = cell(1, numel(selIdx));
            for si = 1:numel(selIdx)
                d = datasets{selIdx(si)};
                if ~isempty(d.corrData) && ~isempty(d.corrData.time)
                    pd = d.corrData;
                else
                    pd = d.data;
                end
                ch = min(ddCFCh.Value, size(pd.values, 2));
                selDS{si} = struct('x', pd.time, 'y', pd.values(:, ch));
            end

            % Build constraints from shared flags
            gfConstraints = struct('paramName', {}, 'datasets', {});
            nC = 0;
            for pi2 = 1:nP
                if logical(shTbl.Data{pi2, 2})
                    nC = nC + 1;
                    gfConstraints(nC).paramName = shData{pi2, 1};
                    gfConstraints(nC).datasets  = 1:numel(selIdx);
                end
            end

            % Build per-dataset init guesses and bounds from table
            p0Row = zeros(1, nP);
            lbRow = zeros(1, nP);
            ubRow = zeros(1, nP);
            for pi2 = 1:nP
                p0Row(pi2) = readNumericCell(shTbl.Data{pi2, 3}, gP0(pi2));
                lbRow(pi2) = readNumericCell(shTbl.Data{pi2, 4}, gLb(pi2));
                ubRow(pi2) = readNumericCell(shTbl.Data{pi2, 5}, gUb(pi2));
            end
            initG = repmat({p0Row}, 1, numel(selIdx));
            lbG   = repmat({lbRow}, 1, numel(selIdx));
            ubG   = repmat({ubRow}, 1, numel(selIdx));

            % Build a model struct (use active model's fcn/paramNames)
            gModel.name       = ddCFModel.Value;
            gModel.fcn        = gfcn;
            gModel.paramNames = gParamNames;
            gModel.p0         = p0Row;
            gModel.lb         = lbRow;
            gModel.ub         = ubRow;
            gModel.nParams    = nP;

            % Run fit
            gfFig.Pointer = 'watch'; drawnow;
            lblGFStatus.Text = 'Fitting...'; drawnow;
            try
                gfResult = fitting.globalCurveFit(selDS, gModel, gfConstraints, ...
                    InitGuess=initG, LowerBound=lbG, UpperBound=ubG);
                gfFig.Pointer = 'arrow';
                lblGFStatus.Text = sprintf( ...
                    'Done. Global chi²_red=%.4g  Exit=%d', ...
                    gfResult.chiSqRed, gfResult.exitFlag);
                showGlobalResults(gfResult, selIdx, selItems, gfConstraints);
            catch ME
                gfFig.Pointer = 'arrow';
                lblGFStatus.Text = 'Fit failed.';
                uialert(gfFig, sprintf('Global fit failed:\n%s', ME.message), 'Error');
            end
        end

        function showGlobalResults(gfr, selIdx2, selItems2, gfConst)
        %SHOWGLOBALRESULTS  Display global fit results in a separate figure.
            nSel = numel(selIdx2);

            resFig = figure('Name', sprintf('Global Fit Results — %s', ddCFModel.Value), ...
                'NumberTitle', 'off', 'Color', [1 1 1], ...
                'Position', [270 80 820 max(500, 180 + nSel * 140)]);

            % ── Shared parameter summary ───────────────────────────────
            nShared = numel(gfr.shared);
            yTop = 0.97;
            axHdr = axes(resFig, 'Visible', 'off', ...
                'Position', [0 0.88 1 0.10]);
            text(axHdr, 0.01, 0.9, ...
                sprintf('Model: %s    Global chi²_red = %.4g    Total N = %d    Free params = %d', ...
                    ddCFModel.Value, gfr.chiSqRed, gfr.nTotal, gfr.nFree), ...
                'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold', ...
                'Interpreter', 'none', 'VerticalAlignment', 'top');

            if nShared > 0
                shLines = cell(1, nShared);
                for g = 1:nShared
                    if isfinite(gfr.shared(g).error)
                        shLines{g} = sprintf('  %s = %.6g  ±  %.3g  (shared across datasets [%s])', ...
                            gfr.shared(g).name, gfr.shared(g).value, gfr.shared(g).error, ...
                            num2str(selIdx2(gfr.shared(g).datasets)));
                    else
                        shLines{g} = sprintf('  %s = %.6g  (shared)', ...
                            gfr.shared(g).name, gfr.shared(g).value);
                    end
                end
                text(axHdr, 0.01, 0.55, ['Shared:  ' strjoin(shLines, '   |   ')], ...
                    'Units', 'normalized', 'FontSize', 9, ...
                    'Color', [0.1 0.5 0.1], 'Interpreter', 'none', ...
                    'VerticalAlignment', 'top');
            end

            % ── Per-dataset fit overlays ───────────────────────────────
            COLORS = lines(nSel);
            axOverlay = axes(resFig, 'Position', [0.07 0.46 0.90 0.40]);
            hold(axOverlay, 'on');
            box(axOverlay, 'on'); grid(axOverlay, 'on');

            for si = 1:nSel
                d = datasets{selIdx2(si)};
                if ~isempty(d.corrData) && ~isempty(d.corrData.time)
                    pd = d.corrData;
                else
                    pd = d.data;
                end
                ch = min(ddCFCh.Value, size(pd.values, 2));
                xd = pd.time;
                yd = pd.values(:, ch);

                plot(axOverlay, xd, yd, '.', 'Color', COLORS(si,:), ...
                    'MarkerSize', 3, 'HandleVisibility', 'off');

                xFine = linspace(min(xd), max(xd), 400)';
                yFine = gfcn(xFine, gfr.params{si});
                plot(axOverlay, xFine, yFine, '-', 'Color', COLORS(si,:), ...
                    'LineWidth', 1.5, ...
                    'DisplayName', sprintf('%s (R²=%.4f)', selItems2{si}, gfr.R2(si)));
            end
            legend(axOverlay, 'Location', 'best', 'FontSize', 8);
            title(axOverlay, 'Data + Global Fit Curves');
            xlabel(axOverlay, 'X'); ylabel(axOverlay, 'Y');
            hold(axOverlay, 'off');

            % ── Per-dataset parameter table ────────────────────────────
            % Shared params are highlighted in green via annotation rectangles
            axTbl = axes(resFig, 'Visible', 'off', ...
                'Position', [0.02 0.02 0.96 0.42]);

            colHdr = [{'Dataset'}, gParamNames, {'R²', 'RMSE'}];
            nCols  = numel(colHdr);
            colW   = 1 / nCols;

            % Find which param indices are shared (for highlighting)
            sharedParamIdx = zeros(1, nShared);
            for g = 1:nShared
                sharedParamIdx(g) = gfr.shared(g).paramIdx;
            end

            % Header
            for ci = 1:nCols
                text(axTbl, (ci-0.5) * colW, 0.97, colHdr{ci}, ...
                    'Units', 'normalized', 'FontSize', 8.5, ...
                    'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                    'Interpreter', 'none', 'VerticalAlignment', 'top');
            end
            annotation(resFig, 'line', [0.02 0.98], [0.93*0.42+0.02 0.93*0.42+0.02]);

            rowH = 0.88 / max(nSel, 1);
            for si = 1:nSel
                yRow = 0.91 - (si-1) * rowH;

                % Dataset name
                text(axTbl, 0.5*colW, yRow, selItems2{si}, ...
                    'Units', 'normalized', 'FontSize', 8, ...
                    'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
                    'VerticalAlignment', 'top');

                % Parameters
                for pi2 = 1:nP
                    xCell = (pi2 + 0.5) * colW;
                    pVal  = gfr.params{si}(pi2);
                    pErr  = gfr.errors{si}(pi2);

                    if isfinite(pErr)
                        txt = sprintf('%.4g\n±%.2g', pVal, pErr);
                    else
                        txt = sprintf('%.4g', pVal);
                    end

                    isSharedParam = ismember(pi2, sharedParamIdx);
                    fc = [0 0 0];
                    if isSharedParam
                        fc = [0.05 0.45 0.05];  % green text for shared
                    end

                    text(axTbl, xCell, yRow, txt, ...
                        'Units', 'normalized', 'FontSize', 8, ...
                        'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
                        'VerticalAlignment', 'top', 'Color', fc);
                end

                % R² and RMSE
                text(axTbl, (nP + 1 + 0.5) * colW, yRow, ...
                    sprintf('%.5f', gfr.R2(si)), ...
                    'Units', 'normalized', 'FontSize', 8, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
                text(axTbl, (nP + 2 + 0.5) * colW, yRow, ...
                    sprintf('%.4g', gfr.RMSE(si)), ...
                    'Units', 'normalized', 'FontSize', 8, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
            end

            options.StatusFcn(sprintf( ...
                'Global fit complete: %d datasets, chi²_red=%.4g, exit=%d', ...
                nSel, gfr.chiSqRed, gfr.exitFlag));
        end

    end % onGlobalFit

% ════════════════════════════════════════════════════════════════════════

    function onCFMCMCSample()
    %ONCFMCMCSAMPLE  Sample the posterior around the current fit.
    %   Requires a successful fit first (cfResult must be populated).
    %   Uses a Gaussian likelihood with σ² = RMSE²  and a flat prior
    %   inside the table's [Lower, Upper] box. Samples in whitened
    %   coordinates so mcmcSample's scalar StepSize can handle
    %   heterogeneous parameter scales. Displays a corner plot of the
    %   free (unfixed) parameters.
        if isempty(cfResult.params) || isempty(cfResult.modelFcn)
            uialert(cfFig, 'Run Fit first — MCMC samples around the current best fit.', ...
                'Sample Posterior');
            return;
        end

        defAns = inputdlg({'Steps', 'Burn-in', 'Step size (σ/|p|)'}, ...
            'MCMC sampling', 1, {'4000', '800', '0.05'});
        if isempty(defAns), return; end
        nSteps = str2double(defAns{1});
        nBurn  = str2double(defAns{2});
        stepSz = str2double(defAns{3});
        if ~isfinite(nSteps) || nSteps < 100 || ~isfinite(nBurn) || ...
                ~isfinite(stepSz) || stepSz <= 0
            uialert(cfFig, 'Invalid MCMC settings.', 'Sample Posterior');
            return;
        end

        % Resolve current model / bounds / fixed mask
        try
            [fcn, pNames, ~, lb, ub, fixedMask, ~] = resolveModel();
        catch ME
            uialert(cfFig, ME.message, 'Sample Posterior');
            return;
        end
        [xSeg, ySeg] = getDataSegment();
        if numel(xSeg) < 3
            uialert(cfFig, 'Not enough data in range.', 'Sample Posterior');
            return;
        end

        pBest = cfResult.params(:)';
        nP    = numel(pBest);
        if numel(pNames) ~= nP || numel(lb) ~= nP || numel(ub) ~= nP
            uialert(cfFig, ...
                'Parameter table is out of sync with the fit — re-run Fit and try again.', ...
                'Sample Posterior');
            return;
        end

        freeIdx = find(~fixedMask);
        if isempty(freeIdx)
            uialert(cfFig, 'All parameters are fixed — nothing to sample.', ...
                'Sample Posterior');
            return;
        end

        % Noise level from fit residuals (profile-likelihood fixed-σ approx)
        sigma2 = max(var(cfResult.residuals), eps);
        if sigma2 == 0, sigma2 = eps; end

        scaleVec = zeros(1, nP);
        scaleVec(freeIdx) = max(abs(pBest(freeIdx)), 1e-6) * stepSz;

        logPost = @(q) logPosteriorCF(q, pBest, scaleVec, lb, ub, ...
            fixedMask, sigma2, xSeg, ySeg, fcn);

        cfFig.Pointer = 'watch'; drawnow;
        try
            qInit = zeros(1, nP);
            mcRes = fitting.mcmcSample(logPost, qInit, ...
                NumSteps=nSteps, BurnIn=nBurn, StepSize=1.0);

            pSamples    = pBest + mcRes.samples .* scaleVec;
            freeSamples = pSamples(:, freeIdx);
            freeLabels  = pNames(freeIdx);
            freeTruth   = pBest(freeIdx);

            plotting.cornerPlot(freeSamples, Labels=freeLabels, Truth=freeTruth);
            cfFig.Pointer = 'arrow';
            options.StatusFcn(sprintf( ...
                'MCMC: %d samples, accept=%.1f%% (scaffold sampler)', ...
                size(freeSamples,1), 100*mcRes.acceptRate));
        catch ME
            cfFig.Pointer = 'arrow';
            uialert(cfFig, sprintf('MCMC failed:\n%s', ME.message), 'Error');
        end
    end

end

function lp = logPosteriorCF(q, pBest, scaleVec, lb, ub, fixedMask, ...
        sigma2, xSeg, ySeg, fcn)
%LOGPOSTERIORCF  Log-posterior for Curve Fit MCMC (whitened q-space).
%   p = pBest + q.*scaleVec. Flat prior inside [lb, ub]; Gaussian
%   likelihood on residuals with variance sigma2. Fixed params are
%   hard-locked to pBest so nothing moves them regardless of q.
    p = pBest + q .* scaleVec;
    p(fixedMask) = pBest(fixedMask);
    if any(p < lb) || any(p > ub)
        lp = -Inf; return;
    end
    try
        yModel = fcn(xSeg, p);
        resid  = ySeg - yModel;
        lp = -0.5 * sum(resid.^2) / sigma2;
    catch
        lp = -Inf;
    end
end
