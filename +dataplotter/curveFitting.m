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
%       Creates a uifigure with 15 built-in curve models (Linear, Polynomials,
%       Exponentials, Gaussian, Lorentzian, Voigt, Sigmoid, Arrhenius, Langmuir,
%       Logarithmic, Sqrt).  Uses fminsearch (Nelder-Mead simplex) with up to
%       10 000 evaluations.  Displays fit + residual axes, parameter table,
%       R² and RMSE.  "Plot on Main" overlays the fit curve on mainAx.
%
%   Examples:
%       api = DataPlotter();           % normal GUI launch
%       % -- or call standalone:
%       dataplotter.curveFitting(myDatasets, 1, gca);

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
% BTN_TOOL and BTN_FG reserved for future use
% BTN_TOOL    = options.ButtonColors.tool;
% BTN_FG      = options.ButtonColors.fg;

% ════════════════════════════════════════════════════════════════════════
% Model library
% ════════════════════════════════════════════════════════════════════════
% Columns: name | display equation | nParams | paramNames | defaultP0 | fitFcn
% fitFcn signature: @(p, x) -> y

models = { ...
    'Linear',           'y = a*x + b',               2, {'a','b'},         [1, 0], ...
        @(p,x) p(1)*x + p(2);
    'Polynomial 2',     'y = a*x^2 + b*x + c',       3, {'a','b','c'},     [0, 1, 0], ...
        @(p,x) p(1)*x.^2 + p(2)*x + p(3);
    'Polynomial 3',     'y = a*x^3 + b*x^2 + c*x + d', 4, {'a','b','c','d'}, [0, 0, 1, 0], ...
        @(p,x) p(1)*x.^3 + p(2)*x.^2 + p(3)*x + p(4);
    'Exponential Decay','y = a*exp(-x/b) + c',       3, {'a','b','c'},     [1, 1, 0], ...
        @(p,x) p(1)*exp(-x./p(2)) + p(3);
    'Exp. Growth',      'y = a*exp(x/b) + c',        3, {'a','b','c'},     [1, 1, 0], ...
        @(p,x) p(1)*exp(x./p(2)) + p(3);
    'Double Exp. Decay','y = a*exp(-x/b) + c*exp(-x/d) + e', 5, {'a','b','c','d','e'}, [1,1,0.5,5,0], ...
        @(p,x) p(1)*exp(-x./p(2)) + p(3)*exp(-x./p(4)) + p(5);
    'Power Law',        'y = a*x^b',                 2, {'a','b'},         [1, 1], ...
        @(p,x) p(1)*abs(x).^p(2);
    'Gaussian',         'y = a*exp(-(x-b)^2/(2*c^2))', 3, {'a','b','c'},  [1, 0, 1], ...
        @(p,x) p(1)*exp(-(x-p(2)).^2./(2*p(3)^2));
    'Lorentzian',       'y = a / (1 + ((x-b)/c)^2)', 3, {'a','b','c'},    [1, 0, 1], ...
        @(p,x) p(1) ./ (1 + ((x-p(2))./p(3)).^2);
    'Voigt (approx)',   'y = eta*L + (1-eta)*G',     4, {'amp','ctr','wid','eta'}, [1,0,1,0.5], ...
        @(p,x) p(4)*(p(1)./(1+((x-p(2))./p(3)).^2)) + (1-p(4))*(p(1)*exp(-(x-p(2)).^2./(2*p(3)^2)));
    'Sigmoid',          'y = a / (1 + exp(-(x-b)/c))',3, {'a','b','c'},    [1, 0, 1], ...
        @(p,x) p(1) ./ (1 + exp(-(x-p(2))./p(3)));
    'Arrhenius',        'y = a*exp(-b/x)',            2, {'a','Ea_over_kB'},[1, 1000], ...
        @(p,x) p(1)*exp(-p(2)./x);
    'Langmuir',         'y = a*x / (b + x)',          2, {'a','b'},         [1, 1], ...
        @(p,x) p(1)*x ./ (p(2) + x);
    'Logarithmic',      'y = a*ln(x) + b',           2, {'a','b'},         [1, 0], ...
        @(p,x) p(1)*log(abs(x)) + p(2);
    'Sqrt',             'y = a*sqrt(x) + b',         2, {'a','b'},         [1, 0], ...
        @(p,x) p(1)*sqrt(abs(x)) + p(2);
};

modelNames = models(:,1);

% ════════════════════════════════════════════════════════════════════════
% Build dialog
% ════════════════════════════════════════════════════════════════════════

cfFig = uifigure('Name', 'Curve Fit', ...
    'Position', [250 120 560 560], 'Resize', 'on');

cfRootGL = uigridlayout(cfFig, [5 1], ...
    'RowHeight', {70, 30, '1x', 90, 36}, ...
    'Padding', [10 8 10 8], 'RowSpacing', 6);

% ── Row 1: Model selection + channel + X range ────────────────────────
cfTopGL = uigridlayout(cfRootGL, [3 6], ...
    'RowHeight', {22, 22, 22}, ...
    'ColumnWidth', {70, '1x', 70, '1x', 45, 45}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 4);
cfTopGL.Layout.Row = 1;

uilabel(cfTopGL, 'Text', 'Model:', 'HorizontalAlignment', 'right', ...
    'FontWeight', 'bold');
ddCFModel = uidropdown(cfTopGL, 'Items', modelNames, 'Value', modelNames{1}, ...
    'ValueChangedFcn', @(~,~) onCFModelChanged());
ddCFModel.Layout.Row = 1; ddCFModel.Layout.Column = 2;

uilabel(cfTopGL, 'Text', 'Channel:', 'HorizontalAlignment', 'right');
ddCFCh = uidropdown(cfTopGL, 'Items', labels, ...
    'ItemsData', 1:numel(labels), 'Value', 1);
ddCFCh.Layout.Row = 1; ddCFCh.Layout.Column = 4;

uilabel(cfTopGL, 'Text', 'X min:', 'HorizontalAlignment', 'right');
efCFXmin = uieditfield(cfTopGL, 'numeric', 'Value', min(xData));
efCFXmin.Layout.Row = 2; efCFXmin.Layout.Column = 2;
uilabel(cfTopGL, 'Text', 'X max:', 'HorizontalAlignment', 'right');
efCFXmax = uieditfield(cfTopGL, 'numeric', 'Value', max(xData));
efCFXmax.Layout.Row = 2; efCFXmax.Layout.Column = 4;

btnCFPickMin = uibutton(cfTopGL, 'Text', 'Pick', ...
    'FontSize', 9, ...
    'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [0.9 0.9 0.9], ...
    'Tooltip', 'Click on the plot to set X min', ...
    'ButtonPushedFcn', @(~,~) cfPickXRange('min'));
btnCFPickMin.Layout.Row = 2; btnCFPickMin.Layout.Column = 5;

btnCFPickMax = uibutton(cfTopGL, 'Text', 'Pick', ...
    'FontSize', 9, ...
    'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [0.9 0.9 0.9], ...
    'Tooltip', 'Click on the plot to set X max', ...
    'ButtonPushedFcn', @(~,~) cfPickXRange('max'));
btnCFPickMax.Layout.Row = 2; btnCFPickMax.Layout.Column = 6;

lblCFEqn = uilabel(cfTopGL, 'Text', models{1,2}, ...
    'FontSize', 11, 'FontColor', [0.4 0.7 0.4], ...
    'Interpreter', 'none');
lblCFEqn.Layout.Row = 3; lblCFEqn.Layout.Column = [1 6];

% ── Row 2: Fit button ─────────────────────────────────────────────────
btnCFFit = uibutton(cfRootGL, 'Text', 'Fit', ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
    'FontWeight', 'bold', 'FontSize', 12, ...
    'ButtonPushedFcn', @(~,~) doCurveFit());
btnCFFit.Layout.Row = 2;

% ── Row 3: Results axes (fit + residuals) ─────────────────────────────
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

% ── Row 4: Parameter table ────────────────────────────────────────────
tblCFParams = uitable(cfRootGL, ...
    'ColumnName', {'Parameter', 'Value', 'Initial Guess'}, ...
    'ColumnEditable', [false, false, true], ...
    'ColumnFormat', {'char', 'char', 'numeric'}, ...
    'Data', {});
tblCFParams.Layout.Row = 4;

% ── Row 5: Stats label + action buttons ───────────────────────────────
cfBtnGL = uigridlayout(cfRootGL, [1 4], ...
    'ColumnWidth', {'2x', 80, 80, 80}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 6);
cfBtnGL.Layout.Row = 5;

lblCFStats = uilabel(cfBtnGL, 'Text', '', ...
    'FontSize', 10, 'FontColor', [0.6 0.6 0.6], ...
    'Interpreter', 'html');
lblCFStats.Layout.Column = 1;

uibutton(cfBtnGL, 'Text', 'Plot on Main', ...
    'BackgroundColor', [0.15 0.45 0.75], 'FontColor', [1 1 1], ...
    'FontSize', 9, ...
    'Tooltip', 'Overlay fit curve on the main DataPlotter axes', ...
    'ButtonPushedFcn', @(~,~) onCFPlotOnMain());
uibutton(cfBtnGL, 'Text', 'Copy', ...
    'FontSize', 9, ...
    'Tooltip', 'Copy fit results to clipboard', ...
    'ButtonPushedFcn', @(~,~) onCFCopyResults());
uibutton(cfBtnGL, 'Text', 'Close', ...
    'FontSize', 9, ...
    'ButtonPushedFcn', @(~,~) delete(cfFig));

% State for fit results
cfResult = struct('params', [], 'model', '', 'xFit', [], 'yFit', [], ...
    'R2', NaN, 'RMSE', NaN, 'paramNames', {{}});

% Initialise parameter table for the default model
onCFModelChanged();

% ════════════════════════════════════════════════════════════════════════
% Nested functions
% ════════════════════════════════════════════════════════════════════════

    function onCFModelChanged()
    %ONCFMODELCHANGED  Update equation display and parameter table for selected model.
        idx = find(strcmp(ddCFModel.Value, modelNames), 1);
        if isempty(idx), return; end
        lblCFEqn.Text = models{idx, 2};
        pNames = models{idx, 4};
        p0 = models{idx, 5};
        tblData = cell(numel(pNames), 3);
        for pi = 1:numel(pNames)
            tblData{pi, 1} = pNames{pi};
            tblData{pi, 2} = '';
            tblData{pi, 3} = p0(pi);
        end
        tblCFParams.Data = tblData;
    end

    function doCurveFit()
    %DOCURVEFIT  Execute the curve fit using fminsearch (Nelder-Mead simplex).
        idx = find(strcmp(ddCFModel.Value, modelNames), 1);
        if isempty(idx), return; end

        ch = ddCFCh.Value;
        xAll = plotD.time;
        yAll = plotD.values(:, ch);

        % Apply X-range mask
        mask = xAll >= efCFXmin.Value & xAll <= efCFXmax.Value;
        xSeg = xAll(mask);
        ySeg = yAll(mask);

        if numel(xSeg) < 3
            uialert(cfFig, 'Not enough data in range.', 'Fit Error');
            return;
        end

        fitFcn = models{idx, 6};
        pNames = models{idx, 4};

        % Read initial guesses from table (user may have edited them)
        p0 = zeros(1, numel(pNames));
        for pi = 1:numel(pNames)
            val = tblCFParams.Data{pi, 3};
            if isnumeric(val)
                p0(pi) = val;
            else
                p0(pi) = str2double(val);
            end
        end

        % Improve initial guesses from data characteristics
        p0 = autoGuess(idx, p0, xSeg, ySeg);

        % Cost function: sum of squared residuals
        costFcn = @(p) sum((ySeg - fitFcn(p, xSeg)).^2);

        cfFig.Pointer = 'watch'; drawnow;
        try
            opts = optimset('MaxFunEvals', 10000, 'MaxIter', 5000, ...
                'TolFun', 1e-12, 'TolX', 1e-10);
            [pOpt, fval] = fminsearch(costFcn, p0, opts);

            % Dense x grid for smooth fit curve display
            xFit = linspace(min(xSeg), max(xSeg), 500)';
            yFit = fitFcn(pOpt, xFit);
            yPred = fitFcn(pOpt, xSeg);
            residuals = ySeg - yPred;

            % Goodness-of-fit statistics
            ssTot = sum((ySeg - mean(ySeg)).^2);
            ssRes = fval;
            R2   = 1 - ssRes / max(ssTot, eps);
            RMSE = sqrt(ssRes / numel(ySeg));

            % Store result for use by onCFPlotOnMain / onCFCopyResults
            cfResult.params     = pOpt;
            cfResult.model      = ddCFModel.Value;
            cfResult.xFit       = xFit;
            cfResult.yFit       = yFit;
            cfResult.R2         = R2;
            cfResult.RMSE       = RMSE;
            cfResult.paramNames = pNames;

            % Update parameter table with fitted values
            for pi = 1:numel(pNames)
                tblCFParams.Data{pi, 2} = sprintf('%.6g', pOpt(pi));
            end

            % Plot fit
            cla(cfAxFit);
            plot(cfAxFit, xSeg, ySeg, 'k.', 'MarkerSize', 4);
            hold(cfAxFit, 'on');
            plot(cfAxFit, xFit, yFit, 'r-', 'LineWidth', 1.5);
            hold(cfAxFit, 'off');
            legend(cfAxFit, {'Data', 'Fit'}, 'Location', 'best');
            title(cfAxFit, sprintf('%s  (R%s = %.6f)', ddCFModel.Value, char(178), R2));
            cfAxFit.Box = 'on'; grid(cfAxFit, 'on');

            % Plot residuals
            cla(cfAxRes);
            stem(cfAxRes, xSeg, residuals, 'b.', 'MarkerSize', 3);
            hold(cfAxRes, 'on');
            yline(cfAxRes, 0, 'k--');
            hold(cfAxRes, 'off');
            title(cfAxRes, sprintf('Residuals (RMSE = %.4g)', RMSE));
            cfAxRes.Box = 'on'; grid(cfAxRes, 'on');

            % Stats label (HTML)
            lblCFStats.Text = sprintf('R%s = <b>%.6f</b> &nbsp; RMSE = %.4g &nbsp; N = %d', ...
                char(178), R2, RMSE, numel(xSeg));

            cfFig.Pointer = 'arrow';
        catch ME
            cfFig.Pointer = 'arrow';
            uialert(cfFig, sprintf('Fit failed:\n%s', ME.message), 'Error');
        end
    end

    function p0 = autoGuess(modelIdx, p0, xS, yS)
    %AUTOGUESS  Improve initial parameter guesses from data statistics.
        switch modelIdx
            case 1  % Linear
                p0(1) = (yS(end)-yS(1)) / max(eps, xS(end)-xS(1));
                p0(2) = yS(1);
            case {2,3}  % Polynomial
                p0(end) = mean(yS);
            case 4  % Exponential Decay
                p0(1) = max(yS) - min(yS);
                p0(2) = (max(xS) - min(xS)) / 3;
                p0(3) = min(yS);
            case 5  % Exp. Growth
                p0(1) = min(yS);
                p0(2) = (max(xS) - min(xS)) / 3;
                p0(3) = min(yS);
            case 7  % Power Law
                p0(1) = yS(1) / max(eps, abs(xS(1)));
                p0(2) = 1;
            case {8,9,10}  % Gaussian / Lorentzian / Voigt
                [~, pkIdx] = max(yS);
                p0(1) = yS(pkIdx);
                p0(2) = xS(pkIdx);
                hm = find(yS >= yS(pkIdx)/2);
                if numel(hm) >= 2
                    p0(3) = (xS(hm(end)) - xS(hm(1))) / 2.355;
                else
                    p0(3) = (max(xS)-min(xS)) / 10;
                end
            case 11  % Sigmoid
                p0(1) = max(yS) - min(yS);
                p0(2) = mean(xS);
                p0(3) = (max(xS) - min(xS)) / 10;
            case 13  % Langmuir
                p0(1) = max(yS);
                p0(2) = median(xS);
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
    %ONCFCOPYRESULTS  Copy fit parameters and statistics to clipboard.
        if isnan(cfResult.R2), return; end
        lines = {};
        lines{end+1} = sprintf('Model: %s', cfResult.model);
        lines{end+1} = sprintf('R² = %.8f', cfResult.R2);
        lines{end+1} = sprintf('RMSE = %.6g', cfResult.RMSE);
        lines{end+1} = 'Parameters:';
        for pi = 1:numel(cfResult.paramNames)
            lines{end+1} = sprintf('  %s = %.8g', cfResult.paramNames{pi}, cfResult.params(pi)); %#ok<AGROW>
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
