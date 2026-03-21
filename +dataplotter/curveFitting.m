function curveFitting(datasets, activeIdx, mainAx, options)
%CURVEFITTING  Open a standalone curve fitting dialog.
%
%   Syntax:
%       dataplotter.curveFitting(datasets, activeIdx, mainAx)
%       dataplotter.curveFitting(datasets, activeIdx, mainAx, 'StatusFcn', fcn)
%       dataplotter.curveFitting(datasets, activeIdx, mainAx, 'ButtonColors', s)
%
%   Inputs:
%       datasets    cell array of dataset structs (each with .corrData / .data)
%       activeIdx   index into datasets of the currently active file
%       mainAx      axes handle of the main DataPlotter plot (used by "Plot on Main"
%                   and by cfPickXRange to capture click coordinates)
%
%   Options:
%       StatusFcn       function_handle  Called with a status string message.
%                       Default: @(~) [] (no-op)
%       ButtonColors    struct with fields:
%                         .primary  — RGB triple for primary action buttons
%                         .tool     — RGB triple for secondary tool buttons
%                         .fg       — RGB triple for button text (foreground)
%                       Default: standard DataPlotter colours
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
end

% ════════════════════════════════════════════════════════════════════════
% Resolve active dataset
% ════════════════════════════════════════════════════════════════════════

if isempty(datasets) || activeIdx < 1 || activeIdx > numel(datasets)
    error('dataplotter:curveFitting:noDataset', ...
        'No valid dataset at activeIdx = %d.', activeIdx);
end

ds = datasets{activeIdx};
if ~isempty(ds.corrData) && ~isempty(ds.corrData.time)
    plotD = ds.corrData;
else
    plotD = ds.data;
end

if isempty(plotD) || isempty(plotD.time)
    error('dataplotter:curveFitting:emptyData', ...
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

% ════════════════════════════════════════════════════════════════════════
% Build dialog
% ════════════════════════════════════════════════════════════════════════

cfFig = uifigure('Name', 'Curve Fit', ...
    'Position', [200 80 680 700], 'Resize', 'on');

cfRootGL = uigridlayout(cfFig, [6 1], ...
    'RowHeight', {94, 32, '1x', 'fit', 36, 28}, ...
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
efCFXmin = uieditfield(cfTopGL, 'numeric', 'Value', min(xData));
efCFXmin.Layout.Row = 2; efCFXmin.Layout.Column = 4;

btnCFPickMin = uibutton(cfTopGL, 'Text', 'Pick', ...
    'FontSize', 9, 'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'Tooltip', 'Click on the plot to set X min', ...
    'ButtonPushedFcn', @(~,~) cfPickXRange('min'));
btnCFPickMin.Layout.Row = 2; btnCFPickMin.Layout.Column = 5;

uilabel(cfTopGL, 'Text', 'X max:', 'HorizontalAlignment', 'right');
efCFXmax = uieditfield(cfTopGL, 'numeric', 'Value', max(xData));
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

% Equation display
lblCFEqn = uilabel(cfTopGL, 'Text', catalog(1).equation, ...
    'FontSize', 11, 'FontColor', [0.4 0.7 0.4], ...
    'Interpreter', 'none');
lblCFEqn.Layout.Row = 4; lblCFEqn.Layout.Column = [1 6];

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

cfAxRes = uiaxes(cfAxPanel);
cfAxRes.Layout.Row = 2;
title(cfAxRes, 'Residuals');
xlabel(cfAxRes, 'X'); ylabel(cfAxRes, 'Residual');
cfAxRes.Box = 'on'; grid(cfAxRes, 'on');

% ── Row 4: Parameter table ───────────────────────────────────────────
tblCFParams = uitable(cfRootGL, ...
    'ColumnName', {'Name', 'Value', char(177)+' Error', 'Guess', 'Lower', 'Upper', 'Fixed'}, ...
    'ColumnEditable', [false, false, false, true, true, true, true], ...
    'ColumnFormat', {'char', 'char', 'char', 'numeric', 'numeric', 'numeric', 'logical'}, ...
    'ColumnWidth', {'auto', 80, 70, 70, 65, 65, 45}, ...
    'Data', {});
tblCFParams.Layout.Row = 4;

% ── Row 5: Stats label + action buttons ──────────────────────────────
cfBottomGL = uigridlayout(cfRootGL, [1 4], ...
    'ColumnWidth', {'2x', 85, 65, 65}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 6);
cfBottomGL.Layout.Row = 5;

lblCFStats = uilabel(cfBottomGL, 'Text', '', ...
    'FontSize', 10, 'FontColor', [0.6 0.6 0.6], ...
    'Interpreter', 'html');
lblCFStats.Layout.Column = 1;

uibutton(cfBottomGL, 'Text', 'Plot on Main', ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
    'FontSize', 9, ...
    'Tooltip', 'Overlay fit curve on the main DataPlotter axes', ...
    'ButtonPushedFcn', @(~,~) onCFPlotOnMain());
uibutton(cfBottomGL, 'Text', 'Copy', ...
    'FontSize', 9, ...
    'Tooltip', 'Copy fit results to clipboard', ...
    'ButtonPushedFcn', @(~,~) onCFCopyResults());
uibutton(cfBottomGL, 'Text', 'Close', ...
    'FontSize', 9, ...
    'ButtonPushedFcn', @(~,~) delete(cfFig));

% ── Row 6: Extended stats ────────────────────────────────────────────
lblCFStats2 = uilabel(cfRootGL, 'Text', '', ...
    'FontSize', 9, 'FontColor', [0.5 0.5 0.5], ...
    'Interpreter', 'html');
lblCFStats2.Layout.Row = 6;

% State for fit results
cfResult = struct('params', [], 'errors', [], 'model', '', ...
    'xFit', [], 'yFit', [], 'R2', NaN, 'RMSE', NaN, ...
    'chiSqRed', NaN, 'AIC', NaN, 'paramNames', {{}});

% Initialise parameter table for the default model
onCFModelChanged();

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
        tblData = cell(nP, 7);
        for pi = 1:nP
            tblData{pi, 1} = pNames{pi};       % Name
            tblData{pi, 2} = '';                % Value (fitted)
            tblData{pi, 3} = '';                % Error
            tblData{pi, 4} = p0(pi);            % Guess
            tblData{pi, 5} = lb(pi);            % Lower bound
            tblData{pi, 6} = ub(pi);            % Upper bound
            tblData{pi, 7} = false;             % Fixed
        end
        tblCFParams.Data = tblData;
    end

    function [fcn, pNames, p0, lb, ub, fixedMask] = resolveModel()
    %RESOLVEMODEL  Get current model function, params, bounds from UI state.
        modelName = ddCFModel.Value;

        if strcmp(modelName, 'Custom Equation')
            if isempty(customFcn)
                error('dataplotter:curveFitting:noCustom', ...
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

        for pi = 1:nP
            p0(pi) = readNumericCell(tblCFParams.Data{pi, 4}, 0);
            lb(pi) = readNumericCell(tblCFParams.Data{pi, 5}, -Inf);
            ub(pi) = readNumericCell(tblCFParams.Data{pi, 6}, Inf);
            fixedMask(pi) = logical(tblCFParams.Data{pi, 7});
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
            [fcn, ~, p0, ~, ~, ~] = resolveModel();
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
            [fcn, pNames, p0, lb, ub, fixedMask] = resolveModel();
        catch ME
            uialert(cfFig, ME.message, 'Fit Error');
            return;
        end

        w = getWeights(ySeg);

        cfFig.Pointer = 'watch'; drawnow;
        try
            res = fitting.curveFit(xSeg, ySeg, fcn, p0, ...
                Lower=lb, Upper=ub, Fixed=fixedMask, Weights=w);

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

            % Update parameter table with fitted values and errors
            for pi = 1:numel(pNames)
                tblCFParams.Data{pi, 2} = sprintf('%.6g', res.params(pi));
                if isfinite(res.errors(pi))
                    tblCFParams.Data{pi, 3} = sprintf('%.3g', res.errors(pi));
                else
                    tblCFParams.Data{pi, 3} = '—';
                end
            end

            % Plot fit
            cla(cfAxFit);
            plot(cfAxFit, xSeg, ySeg, 'k.', 'MarkerSize', 4);
            hold(cfAxFit, 'on');
            plot(cfAxFit, xFit, yFit, 'r-', 'LineWidth', 1.5);
            hold(cfAxFit, 'off');
            legend(cfAxFit, {'Data', 'Fit'}, 'Location', 'best');
            title(cfAxFit, sprintf('%s  (R%s = %.6f)', ...
                cfResult.model, char(178), res.R2));
            cfAxFit.Box = 'on'; grid(cfAxFit, 'on');

            % Plot residuals
            cla(cfAxRes);
            stem(cfAxRes, xSeg, res.residuals, 'b.', 'MarkerSize', 3);
            hold(cfAxRes, 'on');
            yline(cfAxRes, 0, 'k--');
            hold(cfAxRes, 'off');
            title(cfAxRes, sprintf('Residuals (RMSE = %.4g)', res.RMSE));
            cfAxRes.Box = 'on'; grid(cfAxRes, 'on');

            % Stats labels
            lblCFStats.Text = sprintf( ...
                'R%s = <b>%.6f</b> &nbsp; RMSE = %.4g &nbsp; N = %d', ...
                char(178), res.R2, res.RMSE, res.nPoints);
            lblCFStats2.Text = sprintf( ...
                '%s%s = %.4g &nbsp; AIC = %.1f &nbsp; Free = %d/%d &nbsp; Exit = %d', ...
                char(967), char(178), res.chiSqRed, res.AIC, ...
                res.nFree, numel(pNames), res.exitFlag);

            cfFig.Pointer = 'arrow';
            options.StatusFcn(sprintf('Fit: %s  R%s=%.6f', ...
                cfResult.model, char(178), res.R2));
        catch ME
            cfFig.Pointer = 'arrow';
            uialert(cfFig, sprintf('Fit failed:\n%s', ME.message), 'Error');
        end
    end

    function onCFPlotOnMain()
    %ONCFPLOTONMAIN  Overlay the fit curve on the main DataPlotter axes.
        if isempty(cfResult.xFit), return; end
        hold(mainAx, 'on');
        plot(mainAx, cfResult.xFit, cfResult.yFit, 'r-', 'LineWidth', 1.5, ...
            'DisplayName', sprintf('%s fit (R%s=%.4f)', ...
                cfResult.model, char(178), cfResult.R2), ...
            'HandleVisibility', 'on', 'Tag', 'curveFitOverlay');
        hold(mainAx, 'off');
        % Add equation text annotation
        eqnStr = sprintf('%s  R%s = %.4f', cfResult.model, char(178), cfResult.R2);
        text(mainAx, 0.02, 0.95, eqnStr, ...
            'Units', 'normalized', 'FontSize', 9, ...
            'Color', [0.9 0.2 0.2], 'BackgroundColor', [1 1 1 0.7], ...
            'VerticalAlignment', 'top', ...
            'HandleVisibility', 'off', 'Tag', 'curveFitLabel');
        options.StatusFcn(sprintf('Fit overlaid: %s (R%s=%.6f)', ...
            cfResult.model, char(178), cfResult.R2));
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

    function cfPickXRange(which)
    %CFPICKXRANGE  Click on the main axes to set X min or max.
    %   Temporarily hides cfFig so the main plot is accessible.
        cfFig.Visible = 'off';
        mainAx.Parent.Pointer = 'crosshair';
        options.StatusFcn(sprintf('Click on the plot to set X %s...', which));
        oldBDF = mainAx.ButtonDownFcn;
        mainAx.ButtonDownFcn = @(~,~) cfCaptureX(which, oldBDF);

        function cfCaptureX(wh, restoreFcn)
            cp = mainAx.CurrentPoint;
            xClick = cp(1,1);
            switch wh
                case 'min', efCFXmin.Value = xClick;
                case 'max', efCFXmax.Value = xClick;
            end
            mainAx.ButtonDownFcn = restoreFcn;
            mainAx.Parent.Pointer = 'arrow';
            cfFig.Visible = 'on';
            figure(cfFig);
            options.StatusFcn(sprintf('X %s set to %.4g', wh, xClick));
        end
    end

end
