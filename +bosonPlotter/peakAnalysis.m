function peakAnalysis(datasets, activeIdx, mainAx, options)
%PEAKANALYSIS  Advanced peak detection and fitting dialog.
%
%   bosonPlotter.peakAnalysis(datasets, activeIdx, mainAx)
%
%   Provides advanced peak detection controls beyond the basic peak panel:
%   - Background model selection (SNIP, polynomial, iterative)
%   - Detection sensitivity slider with preview
%   - Simultaneous multi-peak + background fitting
%   - Per-peak model selection
%   - Residual visualization
%   - Peak quality metrics (prominence, local SNR)
%
%   Results are communicated back to BosonPlotter via PeakUpdateCallback.

arguments
    datasets   cell
    activeIdx  double
    mainAx
    options.StatusFcn          function_handle = @(~) []
    options.PeakUpdateCallback function_handle = @(~,~) []
    options.ButtonColors       struct = struct( ...
        'primary', [0.15 0.45 0.75], ...
        'tool',    [0.22 0.22 0.28], ...
        'fg',      [0.95 0.95 0.95])
    options.Appearance         struct = bosonPlotter.resolveStyle(styles.template('screen'))
end

% ════════════════════════════════════════════════════════════════════════
% Resolve data
% ════════════════════════════════════════════════════════════════════════

if isempty(datasets) || activeIdx < 1 || activeIdx > numel(datasets)
    error('bosonPlotter:peakAnalysis:noDataset', 'No valid dataset.');
end
ds = datasets{activeIdx};
if ~isempty(ds.corrData) && ~isempty(ds.corrData.time)
    plotD = ds.corrData;
else
    plotD = ds.data;
end

BTN_PRIMARY = options.ButtonColors.primary;
BTN_TOOL    = options.ButtonColors.tool;
BTN_FG      = options.ButtonColors.fg;
BG_DARK     = [0.12 0.12 0.12];
BG_PANEL    = [0.16 0.16 0.18];

xv = double(plotD.time);
yv = plotD.values(:,1);
valid = ~isnan(xv) & ~isnan(yv);
xv = xv(valid);  yv = yv(valid);

if numel(xv) < 10
    error('bosonPlotter:peakAnalysis:tooFewPoints', 'Need at least 10 data points.');
end

% State
detectedPeaks = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
    'xRange',{},'status',{},'bg',{},'model',{},'eta',{}, ...
    'prominence',{},'localSNR',{});
bgEstimate    = [];
residualData  = [];

% ════════════════════════════════════════════════════════════════════════
% Build dialog
% ════════════════════════════════════════════════════════════════════════

hFig = uifigure('Name', 'Advanced Peak Analysis', ...
    'Position', [150 80 860 720], 'Resize', 'on', ...
    'Color', BG_DARK, ...
    'CloseRequestFcn', @(src,~) delete(src));

rootGL = uigridlayout(hFig, [2 1], ...
    'RowHeight', {'1x', 'fit'}, ...
    'Padding', [6 6 6 6], 'RowSpacing', 4, ...
    'BackgroundColor', BG_DARK);

% ── Top: split into controls (left) and preview (right) ────────────────
topGL = uigridlayout(rootGL, [1 2], ...
    'ColumnWidth', {280, '1x'}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 6, ...
    'BackgroundColor', BG_DARK);
topGL.Layout.Row = 1;

% ── Left panel: controls ───────────────────────────────────────────────
ctrlPanel = uipanel(topGL, 'Title', '', 'BorderType', 'none', ...
    'BackgroundColor', BG_PANEL);
ctrlPanel.Layout.Column = 1;

ctrlGL = uigridlayout(ctrlPanel, [24 2], ...
    'RowHeight', {18, 26, 26, 8, ...       % Background section
                  18, 26, 26, 26, 8, ...    % Detection section
                  18, 26, 26, 26, 8, ...    % Fitting section
                  18, 26, 26, 8, ...        % Quality section
                  34, 34, 8, ...            % Actions
                  34, 34, 'fit'}, ...
    'ColumnWidth', {100, '1x'}, ...
    'Padding', [8 6 8 6], 'RowSpacing', 2, ...
    'BackgroundColor', BG_PANEL);

% ── Section: Background ───────────────────────────────────────────────
lblBg = uilabel(ctrlGL, 'Text', 'BACKGROUND', ...
    'FontSize', 9, 'FontWeight', 'bold', 'FontColor', [0.5 0.5 0.5]);
lblBg.Layout.Row = 1; lblBg.Layout.Column = [1 2];

uilabel(ctrlGL, 'Text', 'Method:', 'FontColor', [0.8 0.8 0.8], 'FontSize', 11);
ddBgMethod = uidropdown(ctrlGL, 'Items', {'SNIP', 'SNIP (iterative)', 'Polynomial'}, ...
    'Value', 'SNIP (iterative)', ...
    'BackgroundColor', [0.2 0.2 0.22], 'FontColor', [0.9 0.9 0.9]);
ddBgMethod.Layout.Row = 2; ddBgMethod.Layout.Column = 2;

uilabel(ctrlGL, 'Text', 'Window / Deg:', 'FontColor', [0.8 0.8 0.8], 'FontSize', 11);
efBgWindow = uieditfield(ctrlGL, 'numeric', 'Value', 2.0, ...
    'Limits', [0.1 20], 'ValueDisplayFormat', '%.1f', ...
    'BackgroundColor', [0.2 0.2 0.22], 'FontColor', [0.9 0.9 0.9]);
efBgWindow.Layout.Row = 3; efBgWindow.Layout.Column = 2;

% ── Section: Detection ─────────────────────────────────────────────────
row = 5;
lblDet = uilabel(ctrlGL, 'Text', 'DETECTION', ...
    'FontSize', 9, 'FontWeight', 'bold', 'FontColor', [0.5 0.5 0.5]);
lblDet.Layout.Row = row; lblDet.Layout.Column = [1 2];

row = row + 1;
uilabel(ctrlGL, 'Text', 'Sensitivity:', 'FontColor', [0.8 0.8 0.8], 'FontSize', 11);
ddSensitivity = uidropdown(ctrlGL, 'Items', {'Low', 'Medium', 'High'}, ...
    'Value', 'Medium', ...
    'BackgroundColor', [0.2 0.2 0.22], 'FontColor', [0.9 0.9 0.9]);
ddSensitivity.Layout.Row = row; ddSensitivity.Layout.Column = 2;

row = row + 1;
uilabel(ctrlGL, 'Text', 'SNR threshold:', 'FontColor', [0.8 0.8 0.8], 'FontSize', 11);
efSNR = uieditfield(ctrlGL, 'numeric', 'Value', 5.0, ...
    'Limits', [1 50], 'ValueDisplayFormat', '%.1f', ...
    'BackgroundColor', [0.2 0.2 0.22], 'FontColor', [0.9 0.9 0.9]);
efSNR.Layout.Row = row; efSNR.Layout.Column = 2;

row = row + 1;
uilabel(ctrlGL, 'Text', 'Min prom. (%):', 'FontColor', [0.8 0.8 0.8], 'FontSize', 11);
efMinProm = uieditfield(ctrlGL, 'numeric', 'Value', 2.0, ...
    'Limits', [0 50], 'ValueDisplayFormat', '%.1f', ...
    'BackgroundColor', [0.2 0.2 0.22], 'FontColor', [0.9 0.9 0.9]);
efMinProm.Layout.Row = row; efMinProm.Layout.Column = 2;

% ── Section: Fitting ───────────────────────────────────────────────────
row = 10;
lblFit = uilabel(ctrlGL, 'Text', 'FITTING', ...
    'FontSize', 9, 'FontWeight', 'bold', 'FontColor', [0.5 0.5 0.5]);
lblFit.Layout.Row = row; lblFit.Layout.Column = [1 2];

row = row + 1;
uilabel(ctrlGL, 'Text', 'Peak model:', 'FontColor', [0.8 0.8 0.8], 'FontSize', 11);
ddModel = uidropdown(ctrlGL, ...
    'Items', {'Pseudo-Voigt', 'Gaussian', 'Lorentzian', 'Split Pearson VII', 'TCH-pV'}, ...
    'Value', 'Pseudo-Voigt', ...
    'BackgroundColor', [0.2 0.2 0.22], 'FontColor', [0.9 0.9 0.9]);
ddModel.Layout.Row = row; ddModel.Layout.Column = 2;

row = row + 1;
uilabel(ctrlGL, 'Text', 'Background:', 'FontColor', [0.8 0.8 0.8], 'FontSize', 11);
ddFitBg = uidropdown(ctrlGL, ...
    'Items', {'Linear', 'Quadratic', 'Cubic'}, ...
    'Value', 'Linear', ...
    'BackgroundColor', [0.2 0.2 0.22], 'FontColor', [0.9 0.9 0.9]);
ddFitBg.Layout.Row = row; ddFitBg.Layout.Column = 2;

row = row + 1;
cbConstrain = uicheckbox(ctrlGL, 'Text', 'Constrain centers', ...
    'Value', true, 'FontColor', [0.8 0.8 0.8], 'FontSize', 11);
cbConstrain.Layout.Row = row; cbConstrain.Layout.Column = [1 2];

% ── Section: Quality ───────────────────────────────────────────────────
row = 15;
lblQ = uilabel(ctrlGL, 'Text', 'FIT QUALITY', ...
    'FontSize', 9, 'FontWeight', 'bold', 'FontColor', [0.5 0.5 0.5]);
lblQ.Layout.Row = row; lblQ.Layout.Column = [1 2];

row = row + 1;
lblR2 = uilabel(ctrlGL, 'Text', 'R² = —', ...
    'FontColor', [0.7 0.85 1.0], 'FontSize', 11);
lblR2.Layout.Row = row; lblR2.Layout.Column = [1 2];

row = row + 1;
lblRMSE = uilabel(ctrlGL, 'Text', 'RMSE = —', ...
    'FontColor', [0.7 0.85 1.0], 'FontSize', 11);
lblRMSE.Layout.Row = row; lblRMSE.Layout.Column = [1 2];

% ── Action buttons ─────────────────────────────────────────────────────
row = 19;
btnDetect = uibutton(ctrlGL, 'Text', 'Detect Peaks', ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~,~) onDetect());
btnDetect.Layout.Row = row; btnDetect.Layout.Column = [1 2];

row = row + 1;
btnFitAll = uibutton(ctrlGL, 'Text', 'Fit All (simultaneous)', ...
    'BackgroundColor', [0.15 0.55 0.35], 'FontColor', BTN_FG, ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~,~) onFitSimultaneous());
btnFitAll.Layout.Row = row; btnFitAll.Layout.Column = [1 2];

% Spacer row 21

row = 22;
btnApply = uibutton(ctrlGL, 'Text', 'Apply to BosonPlotter', ...
    'BackgroundColor', [0.65 0.45 0.15], 'FontColor', BTN_FG, ...
    'ButtonPushedFcn', @(~,~) onApply());
btnApply.Layout.Row = row; btnApply.Layout.Column = [1 2];

row = row + 1;
btnExport = uibutton(ctrlGL, 'Text', 'Export CSV...', ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'ButtonPushedFcn', @(~,~) onExportCSV());
btnExport.Layout.Row = row; btnExport.Layout.Column = [1 2];

% ── Right panel: preview axes ──────────────────────────────────────────
previewPanel = uipanel(topGL, 'Title', '', 'BorderType', 'none', ...
    'BackgroundColor', BG_DARK);
previewPanel.Layout.Column = 2;

previewGL = uigridlayout(previewPanel, [3 1], ...
    'RowHeight', {'3x', '1x', 'fit'}, ...
    'Padding', [4 4 4 4], 'RowSpacing', 4, ...
    'BackgroundColor', BG_DARK);

axMain = uiaxes(previewGL);
axMain.Layout.Row = 1;
axMain.Color = [0.06 0.06 0.08];
axMain.XColor = [0.7 0.7 0.7];
axMain.YColor = [0.7 0.7 0.7];
title(axMain, 'Peak Detection Preview', 'Color', [0.8 0.8 0.8]);
xlabel(axMain, plotD.labels{1}, 'Color', [0.7 0.7 0.7]);
ylabel(axMain, 'Intensity', 'Color', [0.7 0.7 0.7]);
bosonPlotter.applyAppearanceToAxes(axMain, options.Appearance);

axResidual = uiaxes(previewGL);
axResidual.Layout.Row = 2;
axResidual.Color = [0.06 0.06 0.08];
axResidual.XColor = [0.7 0.7 0.7];
axResidual.YColor = [0.7 0.7 0.7];
title(axResidual, 'Residual (data − background)', 'Color', [0.8 0.8 0.8]);
ylabel(axResidual, 'Residual', 'Color', [0.7 0.7 0.7]);
bosonPlotter.applyAppearanceToAxes(axResidual, options.Appearance);

% Peak table
peakTable = uitable(previewGL, ...
    'ColumnName', {'Center', 'FWHM', 'Height', 'Area', 'Prom', 'SNR', 'Model'}, ...
    'ColumnFormat', {'numeric','numeric','numeric','numeric','numeric','numeric','char'}, ...
    'ColumnWidth', {70, 60, 70, 70, 55, 45, 80}, ...
    'ColumnEditable', false(1,7), ...
    'BackgroundColor', [0.14 0.14 0.16; 0.17 0.17 0.19], ...
    'ForegroundColor', [0.9 0.9 0.9], ...
    'FontSize', 10);
peakTable.Layout.Row = 3;

% ── Bottom: status bar ─────────────────────────────────────────────────
lblStatus = uilabel(rootGL, 'Text', 'Ready — click Detect Peaks to begin', ...
    'FontSize', 10, 'FontColor', [0.5 0.6 0.7]);
lblStatus.Layout.Row = 2;

% ── Initial plot ───────────────────────────────────────────────────────
plotData();

% ════════════════════════════════════════════════════════════════════════
% Callbacks
% ════════════════════════════════════════════════════════════════════════

    function onDetect()
        setStatusLocal('Detecting peaks...');
        drawnow;

        % Parse background options
        bgMethod = ddBgMethod.Value;
        bgWindow = efBgWindow.Value;

        % Run detection
        switch bgMethod
            case 'SNIP'
                bgOpts = {'MaxWindowDeg', bgWindow, 'Iterative', false};
            case 'SNIP (iterative)'
                bgOpts = {'MaxWindowDeg', bgWindow, 'Iterative', true};
            case 'Polynomial'
                bgOpts = {'Method', 'polynomial', 'PolyDegree', 4, 'Iterative', false};
        end

        % Compute background first
        bgEstimate = utilities.estimateBackground(xv, yv, bgOpts{:});
        residualData = yv - bgEstimate;

        % Detect peaks
        sens = lower(ddSensitivity.Value);
        [detectedPeaks, ~] = utilities.findPeaksRobust(xv, yv, ...
            'SNRThreshold',  efSNR.Value, ...
            'MinProminence', efMinProm.Value / 100, ...
            'Sensitivity',   sens, ...
            'MaxWindowDeg',  bgWindow);

        plotDetection();
        updatePeakTable();
        setStatusLocal(sprintf('Detected %d peaks', numel(detectedPeaks)));
    end

    function onFitSimultaneous()
        if isempty(detectedPeaks)
            setStatusLocal('No peaks to fit — run detection first.');
            return;
        end
        nP = numel(detectedPeaks);
        if nP < 1
            setStatusLocal('Need at least 1 peak.');
            return;
        end

        setStatusLocal(sprintf('Fitting %d peaks simultaneously...', nP));
        drawnow;

        modelName = ddModel.Value;
        bgDeg     = getBgDegree();
        constrain = cbConstrain.Value;
        xSpan     = max(xv) - min(xv);

        % Build composite model function and parameter vector
        [modelFun, p0, nPPerPeak, centerIndices, seedCenters] = ...
            buildCompositeModel(xv, yv, detectedPeaks, modelName, bgDeg);

        % Objective with optional center constraints
        if constrain && nP > 1
            centerBnd = zeros(1, nP);
            for k = 1:nP
                fwInit = abs(p0((k-1)*nPPerPeak + 3));
                centerBnd(k) = max(3 * fwInit, xSpan * 0.02);
            end
            penaltyWt = sum((yv - mean(yv)).^2) * 10;
            objFun = @(p) sum((modelFun(p, xv) - yv).^2) + ...
                penaltyWt * sum(max(0, ((p(centerIndices) - seedCenters) ./ centerBnd).^2 - 1));
        else
            objFun = @(p) sum((modelFun(p, xv) - yv).^2);
        end

        opts = optimset('Display', 'off', 'MaxIter', 30000, ...
            'TolX', 1e-10, 'TolFun', 1e-14);
        try
            pFit = fminsearch(objFun, p0, opts);
        catch me
            setStatusLocal(['Fit failed: ' me.message]);
            return;
        end

        % Extract fitted parameters
        nBgParams = bgDeg + 1;
        bgParams  = pFit(end-nBgParams+1:end);

        for k = 1:nP
            base = (k-1) * nPPerPeak;
            Hk   = pFit(base + 1);
            x0k  = pFit(base + 2);
            fwk  = abs(pFit(base + 3));

            detectedPeaks(k).center = x0k;
            detectedPeaks(k).fwhm   = fwk;
            detectedPeaks(k).height = Hk;
            detectedPeaks(k).model  = modelName;
            detectedPeaks(k).status = 'fitted(global)';

            % Background at peak center
            bgAtPeak = polyval(flip(bgParams), x0k);
            detectedPeaks(k).bg = bgAtPeak;

            % Eta for Pseudo-Voigt
            if nPPerPeak == 4
                detectedPeaks(k).eta = max(0, min(1, pFit(base + 4)));
            else
                detectedPeaks(k).eta = NaN;
            end

            % Area calculation
            detectedPeaks(k).area = computeArea(modelName, detectedPeaks(k));
        end

        % Compute fit quality
        yFitted = modelFun(pFit, xv);
        ssRes   = sum((yv - yFitted).^2);
        ssTot   = sum((yv - mean(yv)).^2);
        R2      = 1 - ssRes / max(ssTot, eps);
        rmse    = sqrt(ssRes / numel(yv));

        lblR2.Text   = sprintf('R%c = %.6f', 178, R2);
        lblRMSE.Text = sprintf('RMSE = %.2e', rmse);

        plotFit(pFit, modelFun, nP, nPPerPeak, bgParams, bgDeg);
        updatePeakTable();
        setStatusLocal(sprintf('Fit complete — R%c = %.4f, %d peaks', 178, R2, nP));
    end

    function onApply()
        if isempty(detectedPeaks)
            setStatusLocal('No peaks to apply.');
            return;
        end
        % Strip extra fields that the main peak struct doesn't expect
        peaksOut = detectedPeaks;
        % Call the update callback
        options.PeakUpdateCallback(peaksOut, bgEstimate);
        setStatusLocal(sprintf('Applied %d peaks to BosonPlotter.', numel(peaksOut)));
        options.StatusFcn(sprintf('Advanced peak analysis: %d peaks applied', numel(peaksOut)));
    end

    function onExportCSV()
        if isempty(detectedPeaks)
            setStatusLocal('No peaks to export.');
            return;
        end
        [file, path] = uiputfile('*.csv', 'Export Peak List');
        if isequal(file, 0), return; end

        fid = fopen(fullfile(path, file), 'w');
        fprintf(fid, 'Center,FWHM,Height,Area,Prominence,LocalSNR,Model,Status\n');
        for k = 1:numel(detectedPeaks)
            pk = detectedPeaks(k);
            fprintf(fid, '%.6f,%.6f,%.4e,%.4e,%.4e,%.1f,%s,%s\n', ...
                pk.center, pk.fwhm, pk.height, pk.area, ...
                pk.prominence, pk.localSNR, pk.model, pk.status);
        end
        fclose(fid);
        setStatusLocal(sprintf('Exported %d peaks to %s', numel(detectedPeaks), file));
    end

% ════════════════════════════════════════════════════════════════════════
% Plotting
% ════════════════════════════════════════════════════════════════════════

    function plotData()
        cla(axMain);
        plot(axMain, xv, yv, '-', 'Color', [0.5 0.7 1.0], 'LineWidth', 0.8);
        axMain.XLim = [min(xv) max(xv)];

        cla(axResidual);
    end

    function plotDetection()
        cla(axMain);
        hold(axMain, 'on');
        plot(axMain, xv, yv, '-', 'Color', [0.5 0.7 1.0], 'LineWidth', 0.8);
        if ~isempty(bgEstimate)
            plot(axMain, xv, bgEstimate, '--', 'Color', [0.3 0.8 0.3], 'LineWidth', 1.2);
        end

        % Mark peaks
        for k = 1:numel(detectedPeaks)
            pk = detectedPeaks(k);
            plot(axMain, pk.center, pk.height + pk.bg, 'v', ...
                'MarkerSize', 8, 'MarkerFaceColor', [1.0 0.3 0.3], ...
                'MarkerEdgeColor', 'none');
        end
        hold(axMain, 'off');
        legend(axMain, {'Data', 'Background'}, 'TextColor', [0.8 0.8 0.8], ...
            'Color', [0.15 0.15 0.17], 'EdgeColor', [0.3 0.3 0.3], ...
            'Location', 'best');

        % Residual plot
        if ~isempty(residualData)
            cla(axResidual);
            hold(axResidual, 'on');
            plot(axResidual, xv, residualData, '-', 'Color', [0.8 0.6 0.3], 'LineWidth', 0.7);
            yline(axResidual, 0, ':', 'Color', [0.4 0.4 0.4]);
            for k = 1:numel(detectedPeaks)
                xline(axResidual, detectedPeaks(k).center, ':', ...
                    'Color', [1 0.3 0.3 0.5]);
            end
            hold(axResidual, 'off');
            axResidual.XLim = [min(xv) max(xv)];
        end
    end

    function plotFit(pFit, modelFun, nP, nPPerPeak, bgParams, bgDeg)
        cla(axMain);
        hold(axMain, 'on');

        % Data
        plot(axMain, xv, yv, '.', 'Color', [0.4 0.6 0.9], 'MarkerSize', 3);

        % Composite fit
        xDense = linspace(min(xv), max(xv), 1000)';
        yComp  = modelFun(pFit, xDense);
        plot(axMain, xDense, yComp, '-', 'Color', [0.9 0.15 0.15], 'LineWidth', 1.5);

        % Background
        bgLine = polyval(flip(bgParams), xDense);
        plot(axMain, xDense, bgLine, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.0);

        % Individual peaks
        peakColors = lines(max(nP, 1));
        for k = 1:nP
            pk = detectedPeaks(k);
            yPk = evaluateSinglePeak(xDense, pk, ddModel.Value) + bgLine;
            plot(axMain, xDense, yPk, '--', 'Color', [peakColors(k,:) 0.6], 'LineWidth', 1.0);
        end
        hold(axMain, 'off');

        % Residual
        yFitted = modelFun(pFit, xv);
        resid   = yv - yFitted;
        cla(axResidual);
        hold(axResidual, 'on');
        plot(axResidual, xv, resid, '-', 'Color', [0.8 0.6 0.3], 'LineWidth', 0.7);
        yline(axResidual, 0, ':', 'Color', [0.4 0.4 0.4]);
        hold(axResidual, 'off');
        axResidual.XLim = [min(xv) max(xv)];
        title(axResidual, 'Residual (data − fit)', 'Color', [0.8 0.8 0.8]);
    end

    function updatePeakTable()
        if isempty(detectedPeaks)
            peakTable.Data = {};
            return;
        end
        nP = numel(detectedPeaks);
        tData = cell(nP, 7);
        for k = 1:nP
            pk = detectedPeaks(k);
            tData{k,1} = round(pk.center, 4);
            tData{k,2} = round(pk.fwhm, 4);
            tData{k,3} = pk.height;
            tData{k,4} = pk.area;
            tData{k,5} = pk.prominence;
            tData{k,6} = round(pk.localSNR, 1);
            tData{k,7} = pk.model;
        end
        peakTable.Data = tData;
    end

    function setStatusLocal(msg)
        lblStatus.Text = msg;
    end

% ════════════════════════════════════════════════════════════════════════
% Model building helpers
% ════════════════════════════════════════════════════════════════════════

    function bgDeg = getBgDegree()
        switch ddFitBg.Value
            case 'Linear',    bgDeg = 1;
            case 'Quadratic', bgDeg = 2;
            case 'Cubic',     bgDeg = 3;
            otherwise,        bgDeg = 1;
        end
    end

end

% ════════════════════════════════════════════════════════════════════════
%  Composite model builder (peaks + polynomial background)
% ════════════════════════════════════════════════════════════════════════
function [modelFun, p0, nPPerPeak, centerIndices, seedCenters] = ...
        buildCompositeModel(xv, yv, peaks, modelName, bgDeg)
    nP = numel(peaks);
    xSpan = max(xv) - min(xv);

    isPV = strcmp(modelName, 'Pseudo-Voigt');
    if isPV
        nPPerPeak = 4;  % H, x0, fwhm, eta
    else
        nPPerPeak = 3;  % H, x0, fwhm
    end

    nBgParams   = bgDeg + 1;  % polynomial coefficients [c0, c1, ..., cn]
    nTotalParams = nP * nPPerPeak + nBgParams;

    p0 = zeros(1, nTotalParams);
    centerIndices = zeros(1, nP);
    seedCenters   = zeros(1, nP);

    bgEst = min(yv);
    for k = 1:nP
        pk    = peaks(k);
        base  = (k-1) * nPPerPeak;
        H0    = max(pk.height, max(yv) * 0.01);
        fwhm0 = max(pk.fwhm, xSpan * 0.005);

        p0(base + 1) = H0;
        p0(base + 2) = pk.center;
        p0(base + 3) = fwhm0;
        if isPV
            eta0 = 0.5;
            if isfield(pk, 'eta') && ~isnan(pk.eta)
                eta0 = pk.eta;
            end
            p0(base + 4) = eta0;
        end

        centerIndices(k) = base + 2;
        seedCenters(k)   = pk.center;
    end

    % Initial background: linear fit to data
    p0(end-nBgParams+1) = bgEst;  % c0 (intercept)
    if nBgParams >= 2
        p0(end-nBgParams+2) = 0;  % c1 (slope)
    end

    % Build model function: sum of peaks + polynomial background
    modelFun = @(p, x) compositeEval(p, x, nP, nPPerPeak, nBgParams, modelName);
end

function y = compositeEval(p, x, nP, nPPerPeak, nBgParams, modelName)
    % Polynomial background: c0 + c1*x + c2*x^2 + ...
    bgCoeffs = p(end-nBgParams+1:end);
    y = polyval(flip(bgCoeffs), x);

    % Add peaks
    for k = 1:nP
        base = (k-1) * nPPerPeak;
        H    = p(base + 1);
        x0   = p(base + 2);
        fw   = p(base + 3);
        if fw == 0, fw = eps; end

        switch modelName
            case 'Gaussian'
                y = y + H .* exp(-4 .* log(2) .* ((x - x0) ./ fw).^2);
            case 'Pseudo-Voigt'
                eta = max(0, min(1, p(base + 4)));
                L = H ./ (1 + 4 .* ((x - x0) ./ fw).^2);
                G = H .* exp(-4 .* log(2) .* ((x - x0) ./ fw).^2);
                y = y + eta .* L + (1 - eta) .* G;
            case 'Split Pearson VII'
                % For global fit, use symmetric Pearson VII approximation
                m = 1.5;
                y = y + H .* (1 + 4 .* (2^(1/m) - 1) .* ((x - x0) ./ fw).^2).^(-m);
            case 'TCH-pV'
                % Global fit uses pseudo-Voigt with eta=0.5 as an
                % approximation; per-peak fit in peakCallbacks uses the
                % full TCH formula with separate fG/fL.
                etaT = 0.5;
                L = H ./ (1 + 4 .* ((x - x0) ./ fw).^2);
                G = H .* exp(-4 .* log(2) .* ((x - x0) ./ fw).^2);
                y = y + etaT .* L + (1 - etaT) .* G;
            otherwise  % Lorentzian
                y = y + H ./ (1 + 4 .* ((x - x0) ./ fw).^2);
        end
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Evaluate a single peak shape (for decomposition overlay)
% ════════════════════════════════════════════════════════════════════════
function yPk = evaluateSinglePeak(x, pk, modelName)
    H  = pk.height;
    x0 = pk.center;
    fw = pk.fwhm;
    if fw == 0, fw = eps; end

    switch modelName
        case 'Gaussian'
            yPk = H .* exp(-4 .* log(2) .* ((x - x0) ./ fw).^2);
        case 'Pseudo-Voigt'
            eta = 0.5;
            if isfield(pk, 'eta') && ~isnan(pk.eta), eta = pk.eta; end
            L = H ./ (1 + 4 .* ((x - x0) ./ fw).^2);
            G = H .* exp(-4 .* log(2) .* ((x - x0) ./ fw).^2);
            yPk = eta .* L + (1 - eta) .* G;
        otherwise
            yPk = H ./ (1 + 4 .* ((x - x0) ./ fw).^2);
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Compute peak area from fitted parameters
% ════════════════════════════════════════════════════════════════════════
function area = computeArea(modelName, pk)
    H  = pk.height;
    fw = pk.fwhm;
    switch modelName
        case 'Gaussian'
            area = H * fw * sqrt(pi / log(2)) / 2;
        case 'Pseudo-Voigt'
            eta = 0.5;
            if isfield(pk, 'eta') && ~isnan(pk.eta), eta = pk.eta; end
            A_L = pi / 2;
            A_G = sqrt(pi) / (2 * sqrt(log(2)));
            area = H * fw * (eta * A_L + (1 - eta) * A_G);
        otherwise  % Lorentzian
            area = H * fw * pi / 2;
    end
end
