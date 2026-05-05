function cb = analysisCallbacks(ctx)
%ANALYSISCALLBACKS  Analysis, statistics, and dialog-launcher callbacks.
%
%   Syntax
%     cb = bosonPlotter.analysisCallbacks(ctx)
%
%   Inputs
%     ctx — struct bundling all closure state the callbacks need
%       .appData          shared AppState handle (mutations visible to caller)
%       .fig              uifigure handle
%       .ax               main plot axes
%       .lbY              Y-channel listbox
%       .lbDatasets       dataset listbox
%       .cbOverlayMode    overlay mode checkbox
%       .ui               UI handles struct (for plotTemplates)
%       .ptCb_            plot-templates callback struct
%       .BTN_PRIMARY      primary button background color
%       .BTN_TOOL         tool button background color
%       .BTN_FG           button foreground color
%       .headless         logical — suppress dialog focus when true
%       .setStatus        function handle — status bar
%       .recordAction     function handle — action log
%       .ensureCell       function handle — ensures cell array
%       .onPlot           function handle — triggers a replot
%       .resolveActiveAppearance  function handle — appearance struct
%       .updateFileList   function handle — refresh dataset list
%       .updateControlsForActiveDataset  function handle — refresh controls
%       .buildDs          function handle — build dataset struct
%       .getActiveXY      function handle — get x/y for active dataset
%       .getPlotData      function handle — corrected data for a dataset
%       .peakCb           peak-callbacks struct (for refreshPeakTable)
%       .showPeakWindow   function handle — show peak analysis window
%
%   Outputs
%     cb — struct of function handles:
%       .onOpenAdvancedPeakAnalysis, .onOpenIntegrationDialog,
%       .onOpenCurveFitDialog, .onOpenHysteresisDialog,
%       .onLinearRegression, .onTTest, .onConfidenceBand, .onROIAnalysis,
%       .onFFTFilter, .onBatchFit, .onGlobalFit, .onTrackPeak,
%       .onOpenReflFitDialog, .onOpenDigitizer,
%       .onOverlayModeChanged, .onPlotTemplates,
%       .onBatchFigureExport, .onAdvancedFigureBuilder

% ════════════════════════════════════════════════════════════════════════
% Unpack context — nested functions share this outer scope, so they use
% plain names instead of ctx.xxx throughout.
% NOTE: appData is an AppState handle class — mutations propagate to caller.
% ════════════════════════════════════════════════════════════════════════

appData     = ctx.appData;
fig         = ctx.fig;
ax          = ctx.ax;
lbY         = ctx.lbY;
lbDatasets  = ctx.lbDatasets;
cbOverlayMode = ctx.cbOverlayMode;
ui          = ctx.ui;
ptCb_       = ctx.ptCb_;
BTN_PRIMARY = ctx.BTN_PRIMARY;
BTN_TOOL    = ctx.BTN_TOOL;
BTN_FG      = ctx.BTN_FG;
headless    = ctx.headless;

% Function handles — already function handles, so no @ needed when passing
setStatus                    = ctx.setStatus;
recordAction                 = ctx.recordAction;
ensureCell                   = ctx.ensureCell;
onPlot                       = ctx.onPlot;
resolveActiveAppearance      = ctx.resolveActiveAppearance;
updateFileList               = ctx.updateFileList;
updateControlsForActiveDataset = ctx.updateControlsForActiveDataset;
buildDs                      = ctx.buildDs;
getActiveXY                  = ctx.getActiveXY;
getPlotData                  = ctx.getPlotData;
peakCb                       = ctx.peakCb;
showPeakWindow               = ctx.showPeakWindow;

% ════════════════════════════════════════════════════════════════════════
% Return struct of callback function handles
% ════════════════════════════════════════════════════════════════════════

cb.onOpenAdvancedPeakAnalysis = @onOpenAdvancedPeakAnalysis;
cb.onOpenIntegrationDialog    = @onOpenIntegrationDialog;
cb.onOpenCurveFitDialog       = @onOpenCurveFitDialog;
cb.onOpenHysteresisDialog     = @onOpenHysteresisDialog;
cb.onLinearRegression         = @onLinearRegression;
cb.onTTest                    = @onTTest;
cb.onConfidenceBand           = @onConfidenceBand;
cb.onROIAnalysis              = @onROIAnalysis;
cb.onFFTFilter                = @onFFTFilter;
cb.onBatchFit                 = @onBatchFit;
cb.onGlobalFit                = @onGlobalFit;
cb.onTrackPeak                = @onTrackPeak;
cb.onOpenReflFitDialog        = @onOpenReflFitDialog;
cb.onOpenDigitizer            = @onOpenDigitizer;
cb.onOverlayModeChanged       = @onOverlayModeChanged;
cb.onPlotTemplates            = @onPlotTemplates;
cb.onBatchFigureExport        = @onBatchFigureExport;
cb.onAdvancedFigureBuilder    = @onAdvancedFigureBuilder;

% ════════════════════════════════════════════════════════════════════════
% Dialog launchers — validate data present, then delegate to +bosonPlotter/
% ════════════════════════════════════════════════════════════════════════

    function onOpenAdvancedPeakAnalysis(~, ~)
    %ONOPENADVANCEDPEAKANALYSIS  Launch the Peak Workshop.
    %   Legacy entry point — previously opened a separate modal config
    %   dialog (bosonPlotter.peakAnalysis). The Peak Workshop now folds
    %   the modal's noise + prominence params into the sidebar, so this
    %   redirects to the workshop. Modal source kept in
    %   +bosonPlotter/peakAnalysis.m for reference; not called here.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Peak Workshop');
            return;
        end
        showPeakWindow();
    end

    function onOpenIntegrationDialog(~, ~)
    %ONOPENINTEGRATIONDIALOG  Open dialog for manual bounded integration.
    %   User sets two x-range edge points (type or click-to-set),
    %   selects a channel, and computes the definite integral.
    %   The integrated region is shaded on the main axes.

        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Integrate');
            return;
        end

        plotD = getPlotData(appData.activeIdx);
        if isempty(plotD)
            uialert(fig, 'Apply corrections or plot data first.', 'Integrate');
            return;
        end

        xData  = plotD.time;
        labels = plotD.labels;
        nCh    = numel(labels);

        xMin = min(xData);
        xMax = max(xData);

        intFig = uifigure('Name', 'Integrate — Bounded Area', ...
            'Position', [350 280 440 340], 'Resize', 'off');
        iGL = uigridlayout(intFig, [9 3], ...
            'RowHeight', {22, 28, 28, 28, 12, 28, 50, 12, 34}, ...
            'ColumnWidth', {100, '1x', 80}, ...
            'Padding', [12 10 12 10], 'RowSpacing', 5);

        lblInstr = uilabel(iGL, 'Text', ...
            'Set two x-range edge points, then compute the area.', ...
            'FontSize', 10, 'FontColor', [0.5 0.5 0.5]);
        lblInstr.Layout.Row = 1; lblInstr.Layout.Column = [1 3];

        uilabel(iGL, 'Text', 'X₁ (left edge):', ...
            'HorizontalAlignment', 'right', 'FontWeight', 'bold');
        efIntX1 = uieditfield(iGL, 'numeric', 'Value', xMin);
        efIntX1.Layout.Row = 2; efIntX1.Layout.Column = 2;
        btnPickX1 = uibutton(iGL, 'Text', 'Pick', ...
            'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [1 1 1], ...
            'Tooltip', 'Click on the plot to set X₁', ...
            'ButtonPushedFcn', @(~,~) pickEdgePoint('x1'));
        btnPickX1.Layout.Row = 2; btnPickX1.Layout.Column = 3;

        uilabel(iGL, 'Text', 'X₂ (right edge):', ...
            'HorizontalAlignment', 'right', 'FontWeight', 'bold');
        efIntX2 = uieditfield(iGL, 'numeric', 'Value', xMax);
        efIntX2.Layout.Row = 3; efIntX2.Layout.Column = 2;
        btnPickX2 = uibutton(iGL, 'Text', 'Pick', ...
            'BackgroundColor', [0.28 0.28 0.28], 'FontColor', [1 1 1], ...
            'Tooltip', 'Click on the plot to set X₂', ...
            'ButtonPushedFcn', @(~,~) pickEdgePoint('x2'));
        btnPickX2.Layout.Row = 3; btnPickX2.Layout.Column = 3;

        uilabel(iGL, 'Text', 'Channel:', 'HorizontalAlignment', 'right');
        ddIntCh = uidropdown(iGL, 'Items', labels, 'ItemsData', 1:nCh, 'Value', 1);
        ddIntCh.Layout.Row = 4; ddIntCh.Layout.Column = [2 3];

        btnCompute = uibutton(iGL, 'Text', 'Compute Integral', ...
            'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
            'FontWeight', 'bold', ...
            'ButtonPushedFcn', @(~,~) doComputeIntegral());
        btnCompute.Layout.Row = 6; btnCompute.Layout.Column = [1 3];

        lblIntResult = uilabel(iGL, 'Text', '', ...
            'FontSize', 13, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'Interpreter', 'html', 'WordWrap', 'on');
        lblIntResult.Layout.Row = 7; lblIntResult.Layout.Column = [1 3];

        btnRowGL = uigridlayout(iGL, [1 2], ...
            'ColumnWidth', {'1x', '1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 8);
        btnRowGL.Layout.Row = 9; btnRowGL.Layout.Column = [1 3];

        uibutton(btnRowGL, 'Text', 'Copy Result', ...
            'BackgroundColor', [0.15 0.45 0.75], 'FontColor', [1 1 1], ...
            'ButtonPushedFcn', @(~,~) copyIntResult());
        uibutton(btnRowGL, 'Text', 'Close', ...
            'ButtonPushedFcn', @(~,~) closeIntDialog());

        intResult   = struct('area', NaN, 'x1', NaN, 'x2', NaN, 'channel', '');
        hShadePatch = [];

        bosonPlotter.applyDialogTheme(intFig, appData.theme);

        function pickEdgePoint(which)
        %PICKEDGEPOINT  Click on the main axes to set an edge point.
            intFig.Visible = 'off';
            setStatus(sprintf('Click on the plot to set %s...', upper(which)));
            fig.Pointer = 'crosshair';
            oldBDF = ax.ButtonDownFcn;
            ax.ButtonDownFcn = @(~, ~) captureClick(which, oldBDF);

            function captureClick(wh, restoreFcn)
                cp     = ax.CurrentPoint;
                xClick = cp(1, 1);
                switch wh
                    case 'x1', efIntX1.Value = xClick;
                    case 'x2', efIntX2.Value = xClick;
                end
                ax.ButtonDownFcn = restoreFcn;
                fig.Pointer = 'arrow';
                if ~headless
                    intFig.Visible = 'on';
                    figure(intFig);
                end
                setStatus(sprintf('%s set to %.4g', upper(wh), xClick));
            end
        end

        function doComputeIntegral()
        %DOCOMPUTEINTEGRAL  Compute the definite integral between X1 and X2.
            x1v = efIntX1.Value;
            x2v = efIntX2.Value;
            ch  = ddIntCh.Value;

            if x1v >= x2v
                uialert(intFig, 'X₁ must be less than X₂.', 'Range Error');
                return;
            end

            d    = getPlotData(appData.activeIdx);
            xAll = d.time;
            yAll = d.values(:, ch);

            mask = xAll >= x1v & xAll <= x2v;
            xSeg = xAll(mask);
            ySeg = yAll(mask);

            if numel(xSeg) < 2
                uialert(intFig, 'Not enough data points in the selected range.', 'Error');
                return;
            end

            area = trapz(xSeg, ySeg);

            intResult.area    = area;
            intResult.x1      = x1v;
            intResult.x2      = x2v;
            intResult.channel = labels{ch};

            lblIntResult.Text = sprintf( ...
                ['<b>%s</b> %s Y dx = <b>%.6g</b><br>' ...
                 'Range: [%.4g, %.4g] &nbsp; (%d points)'], ...
                char(8747), char(160), area, x1v, x2v, numel(xSeg));

            clearIntShading();
            hold(ax, 'on');
            yBase = zeros(size(ySeg));
            xPoly = [xSeg; flipud(xSeg)];
            yPoly = [ySeg; yBase];
            hShadePatch = fill(ax, xPoly, yPoly, [0.3 0.6 1.0], ...
                'FaceAlpha', 0.3, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off', 'Tag', 'integrationShade');
            yLimCurr = ax.YLim;
            line(ax, [x1v x1v], yLimCurr, 'Color', [0.8 0.2 0.2], ...
                'LineStyle', '--', 'LineWidth', 1.5, ...
                'HandleVisibility', 'off', 'Tag', 'integrationEdge');
            line(ax, [x2v x2v], yLimCurr, 'Color', [0.8 0.2 0.2], ...
                'LineStyle', '--', 'LineWidth', 1.5, ...
                'HandleVisibility', 'off', 'Tag', 'integrationEdge');
            hold(ax, 'off');

            setStatus(sprintf('Integral = %.6g over [%.4g, %.4g]', area, x1v, x2v));
        end

        function copyIntResult()
            if isnan(intResult.area)
                uialert(intFig, 'Compute an integral first.', 'Copy');
                return;
            end
            txt = sprintf('Integral of %s from %.6g to %.6g = %.6g', ...
                intResult.channel, intResult.x1, intResult.x2, intResult.area);
            clipboard('copy', txt);
            setStatus('Integration result copied to clipboard');
        end

        function closeIntDialog()
            clearIntShading();
            delete(intFig);
        end

        function clearIntShading()
        %CLEARINTSHADING  Remove shading and edge lines from main axes.
            if ~isempty(hShadePatch) && isvalid(hShadePatch)
                delete(hShadePatch);
                hShadePatch = [];
            end
            if ~isempty(ax) && isvalid(ax)
                delete(findobj(ax, 'Tag', 'integrationEdge'));
                delete(findobj(ax, 'Tag', 'integrationShade'));
            end
        end
    end

    function onOpenCurveFitDialog(~, ~)
    %ONOPENCURVEFITDIALOG  Open general-purpose curve fitting dialog.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Curve Fit');
            return;
        end
        bosonPlotter.curveFitting(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn',    setStatus, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG), ...
            'Appearance',   resolveActiveAppearance());
    end

    function onOpenHysteresisDialog(~, ~)
    %ONOPENHYSTERESISDIALOG  Open hysteresis loop analysis dialog.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Hysteresis');
            return;
        end
        bosonPlotter.hysteresisDialog(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn',    setStatus, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG));
    end

% ════════════════════════════════════════════════════════════════════════
% Statistics callbacks
% ════════════════════════════════════════════════════════════════════════

    function onLinearRegression(~, ~)
    %ONLINEARREGRESSION  Polynomial regression with confidence bands.
        [xV, yV, ~] = getActiveXY();
        if isempty(yV), return; end
        answer = inputdlg('Polynomial degree (1 = linear):', 'Regression', 1, {'1'});
        if isempty(answer), return; end
        deg = round(str2double(answer{1}));
        if isnan(deg) || deg < 1 || deg > 10
            uialert(fig, 'Degree must be 1-10.', 'Regression'); return;
        end
        result = utilities.linRegress(xV, yV, 'Degree', deg);
        hold(ax, 'on');
        xFit = linspace(min(xV), max(xV), 500)';
        yFit = polyval(result.coefficients, xFit);
        plot(ax, xFit, yFit, 'r-', 'LineWidth', 1.5, ...
            'DisplayName', sprintf('Poly(%d) R%s=%.4f', deg, char(178), result.R2), ...
            'Tag', 'GUIFitOverlay');
        if isfield(result, 'ciUpper') && ~isempty(result.ciUpper)
            ciUp = polyval(result.ciUpper, xFit);
            ciLo = polyval(result.ciLower, xFit);
            fill(ax, [xFit; flipud(xFit)], [ciUp; flipud(ciLo)], ...
                'r', 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off', 'Tag', 'GUIFitOverlay');
        end
        hold(ax, 'off');
        legend(ax, 'show');
        msg = sprintf('R%s = %.6f,  p = %.4g', char(178), result.R2, result.pValue);
        setStatus(sprintf('Regression: degree=%d  %s', deg, msg));
        uialert(fig, sprintf('Degree %d regression:\n%s\nCoeffs: %s', ...
            deg, msg, mat2str(result.coefficients, 4)), 'Regression', 'Icon', 'info');
        recordAction(sprintf('%% Regression: degree=%d R2=%.4f', deg, result.R2));
    end

    function onTTest(~, ~)
    %ONTTEST  Perform a t-test on the active channel.
        [~, yV, yLbl] = getActiveXY();
        if isempty(yV), return; end
        choice = uiconfirm(fig, ...
            'Select t-test type:', 't-Test', ...
            'Options', {'One-sample (vs 0)', 'One-sample (vs value)', 'Cancel'}, ...
            'DefaultOption', 1, 'CancelOption', 3);
        if strcmp(choice, 'Cancel'), return; end
        if strcmp(choice, 'One-sample (vs value)')
            answer = inputdlg('Test value:', 't-Test', 1, {'0'});
            if isempty(answer), return; end
            mu0 = str2double(answer{1});
        else
            mu0 = 0;
        end
        result = utilities.tTest(yV, [], 'TestType', 'one', 'Mu', mu0);
        msg = sprintf(['t-Test: %s vs %.4g\n' ...
            't-statistic: %.4f\n' ...
            'p-value:     %.6g\n' ...
            'df:          %d\n' ...
            'CI (95%%):    [%.4g, %.4g]\n' ...
            'Significant: %s'], ...
            yLbl, mu0, result.tStat, result.pValue, result.df, ...
            result.ci(1), result.ci(2), ...
            mat2str(result.pValue < 0.05));
        uialert(fig, msg, 't-Test Result', 'Icon', 'info');
        setStatus(sprintf('t-Test: t=%.3f  p=%.4g', result.tStat, result.pValue));
        recordAction(sprintf('%% t-Test: %s vs %.4g, p=%.4g', yLbl, mu0, result.pValue));
    end

    function onConfidenceBand(~, ~)
    %ONCONFIDENCEBAND  Overlay mean+/-std band from multiple datasets.
        if numel(appData.datasets) < 2
            uialert(fig, 'Need at least 2 datasets for confidence bands.', 'Confidence Band');
            return;
        end
        choice = uiconfirm(fig, ...
            'Band type:', 'Confidence Band', ...
            'Options', {'Mean +/- Std', 'Median +/- IQR', 'Cancel'}, ...
            'DefaultOption', 1, 'CancelOption', 3);
        if strcmp(choice, 'Cancel'), return; end
        bandType = 'meanstd';
        if contains(choice, 'Median'), bandType = 'medianiqr'; end
        result = utilities.confidenceBand(appData.datasets, 'Type', bandType);
        hold(ax, 'on');
        fill(ax, [result.x; flipud(result.x)], ...
            [result.upper; flipud(result.lower)], ...
            'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
            'DisplayName', choice, 'Tag', 'GUIFitOverlay');
        plot(ax, result.x, result.center, 'b-', 'LineWidth', 1.5, ...
            'DisplayName', 'Center', 'Tag', 'GUIFitOverlay');
        hold(ax, 'off');
        legend(ax, 'show');
        setStatus(sprintf('Confidence band: %s (%d datasets)', bandType, numel(appData.datasets)));
        recordAction(sprintf('%% Confidence band: %s', bandType));
    end

    function onROIAnalysis(~, ~)
    %ONROIANALYSIS  Open ROI selection and statistics dialog.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'ROI Analysis');
            return;
        end
        bosonPlotter.roiAnalysis(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn', setStatus);
    end

    function onFFTFilter(~, ~)
    %ONFFTFILTER  Apply FFT filter to active dataset.
        [xV, yV, yLbl] = getActiveXY();
        if isempty(yV), return; end
        answer = inputdlg({ ...
            'Filter type (lowpass / highpass / bandpass / notch):', ...
            'Cutoff frequency (Hz, or [low high] for bandpass/notch):'}, ...
            'FFT Filter', [1 50; 1 50], {'lowpass', '0.1'});
        if isempty(answer), return; end
        filterType = strtrim(answer{1});
        cutoffStr  = strtrim(answer{2});
        cutoff = str2double(strsplit(strtrim(cutoffStr)));
        cutoff = cutoff(~isnan(cutoff));
        if isempty(cutoff)
            uialert(fig, 'Invalid cutoff value.', 'FFT Filter'); return;
        end
        result = utilities.fftFilter(xV, yV, 'Type', filterType, 'Cutoff', cutoff);
        ds   = appData.datasets{appData.activeIdx};
        ySel = ensureCell(lbY.Value);
        idx  = find(strcmp(ds.data.labels, ySel{1}), 1);
        if ~isempty(idx)
            ds.data.values(:, idx) = result.filtered;
            appData.datasets{appData.activeIdx} = ds;
            try
                appData.model.updateDataset(appData.activeIdx, ds);
            catch
            end
            onPlot();
            setStatus(sprintf('FFT filter: %s (cutoff=%s) applied to %s', filterType, cutoffStr, yLbl));
        end
        recordAction(sprintf('%% FFT filter: %s cutoff=%s on %s', filterType, cutoffStr, yLbl));
    end

% ════════════════════════════════════════════════════════════════════════
% Batch / global fitting and peak tracking
% ════════════════════════════════════════════════════════════════════════

    function onBatchFit(~, ~)
    %ONBATCHFIT  Fit the same model across all loaded datasets.
        if numel(appData.datasets) < 2
            uialert(fig, 'Need at least 2 datasets for batch fitting.', 'Batch Fit');
            return;
        end
        setStatus('Batch Fit: first configure a fit on the active dataset using Curve Fit dialog...');
        onOpenCurveFitDialog([], []);
    end

    function onGlobalFit(~, ~)
    %ONGLOBALFIT  Fit multiple datasets simultaneously with shared parameters.
        if numel(appData.datasets) < 2
            uialert(fig, 'Need at least 2 datasets for global fitting.', 'Global Fit');
            return;
        end
        setStatus('Global Fit: first configure a model via Curve Fit, then apply globally...');
        onOpenCurveFitDialog([], []);
    end

    function onTrackPeak(~, ~)
    %ONTRACKPEAK  Track peak position across a dataset series.
        if numel(appData.datasets) < 2
            uialert(fig, 'Need at least 2 datasets for peak tracking.', 'Track Peak');
            return;
        end
        answer = inputdlg('Seed peak position (x value):', 'Track Peak', 1, {'0'});
        if isempty(answer), return; end
        seedPos = str2double(answer{1});
        if isnan(seedPos)
            uialert(fig, 'Invalid position.', 'Track Peak'); return;
        end
        try
            result = fitting.trackPeak(appData.datasets, seedPos);
            hold(ax, 'on');
            plot(ax, 1:numel(result.positions), result.positions, 'ro-', ...
                'LineWidth', 1.5, 'DisplayName', 'Peak Track', ...
                'Tag', 'GUIFitOverlay');
            hold(ax, 'off');
            setStatus(sprintf('Peak tracked across %d datasets: %.4g to %.4g', ...
                numel(result.positions), result.positions(1), result.positions(end)));
        catch ME
            uialert(fig, sprintf('Track Peak failed:\n%s', ME.message), 'Error');
        end
        recordAction(sprintf('%% Track peak: seed=%.4g', seedPos));
    end

% ════════════════════════════════════════════════════════════════════════
% Additional dialog launchers
% ════════════════════════════════════════════════════════════════════════

    function onOpenReflFitDialog(~, ~)
    %ONOPENREFLFITDIALOG  Open reflectivity fitting dialog (Parratt recursion).
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load a dataset first.', 'Reflectivity Fit');
            return;
        end
        bosonPlotter.reflFitting(appData.datasets, appData.activeIdx, ax, ...
            'StatusFcn',    setStatus, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG), ...
            'Appearance',   resolveActiveAppearance());
    end

    function onOpenDigitizer(~, ~)
    %ONOPENDIGITIZER  Delegates to bosonPlotter.graphDigitizer.
        bosonPlotter.graphDigitizer( ...
            'LoadCallback', @digLoadDataset, ...
            'StatusFcn',    setStatus, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG));

        function digLoadDataset(data)
            newDS = buildDs('[Digitized]', data, 'digitizer');
            appData.datasets{end+1} = newDS;
            appData.activeIdx = numel(appData.datasets);
            try
                appData.model.addDataset(newDS.data, newDS.filepath, newDS.parserName);
            catch
            end
            updateFileList();
            updateControlsForActiveDataset();
            onPlot();
        end
    end

% ════════════════════════════════════════════════════════════════════════
% View / template callbacks (early-created toolbar stubs delegate here)
% ════════════════════════════════════════════════════════════════════════

    function onOverlayModeChanged(~, ~)
    %ONOVERLAYCHANGED  Toggle multi-dataset overlay mode.
        if ~isprop(appData, 'overlayMode'), appData.overlayMode = false; end
        appData.overlayMode = cbOverlayMode.Value;
        if appData.overlayMode && numel(appData.datasets) > 1
            allIdx = num2cell(1:numel(appData.datasets));
            lbDatasets.Value = allIdx;
            setStatus(sprintf('Overlay ON — all %d datasets overlaid.', numel(appData.datasets)));
        else
            lbDatasets.Value = {appData.activeIdx};
            setStatus('Overlay off.');
        end
        onPlot();
    end

    function onPlotTemplates(~, ~)
    %ONPLOTTEMPLATES  Delegate to extracted +bosonPlotter module.
        bosonPlotter.plotTemplates(appData, fig, ui, ptCb_);
    end

    function onBatchFigureExport(~, ~)
    %ONBATCHFIGUREEXPORT  Delegates to bosonPlotter.batchFigureExport.
        bosonPlotter.batchFigureExport(appData.datasets, fig, ...
            getPlotData, setStatus, ...
            struct('primary', BTN_PRIMARY, 'fg', BTN_FG));
    end

    function onAdvancedFigureBuilder(~, ~)
    %ONADVANCEDFIGUREBUILDER  Delegates to bosonPlotter.figureBuilder.
        if isempty(appData.datasets) || appData.activeIdx < 1
            uialert(fig, 'Load at least one file first.', 'No data'); return;
        end
        bosonPlotter.figureBuilder(appData.datasets, appData.activeIdx, ...
            'ButtonColors', struct('primary', BTN_PRIMARY, 'tool', BTN_TOOL, 'fg', BTN_FG), ...
            'Appearance',   resolveActiveAppearance());
    end

end
