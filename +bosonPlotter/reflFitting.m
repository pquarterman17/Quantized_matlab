function reflFitting(datasets, activeIdx, mainAx, options)
%REFLFITTING  Reflectivity fitting dialog with layer stack editor.
%
%   bosonPlotter.reflFitting(datasets, activeIdx, mainAx)
%
%   Opens a dialog for fitting specular reflectivity data using Parratt
%   recursion.  Features an editable layer table with material presets,
%   SLD profile visualization, simulate/fit buttons, and overlay on
%   the main BosonPlotter axes.
%
%   Inputs:
%       datasets  — cell array of dataset structs
%       activeIdx — index of active dataset
%       mainAx    — handle to main BosonPlotter axes

arguments
    datasets   cell
    activeIdx  double
    mainAx
    options.StatusFcn   function_handle = @(~) []
    options.ButtonColors struct = struct( ...
        'primary', [0.15 0.45 0.75], ...
        'tool',    [0.22 0.22 0.28], ...
        'fg',      [0.95 0.95 0.95])
    options.Appearance  struct = bosonPlotter.resolveStyle(styles.template('screen'))
end

% ════════════════════════════════════════════════════════════════════════
% Resolve data
% ════════════════════════════════════════════════════════════════════════

if isempty(datasets) || activeIdx < 1 || activeIdx > numel(datasets)
    error('bosonPlotter:reflFitting:noDataset', 'No valid dataset.');
end
ds = datasets{activeIdx};
if ~isempty(ds.corrData) && ~isempty(ds.corrData.time)
    plotD = ds.corrData;
else
    plotD = ds.data;
end
xData = plotD.time(:);
yData = plotD.values(:, 1);

BTN_PRIMARY = options.ButtonColors.primary;
BTN_TOOL    = options.ButtonColors.tool;
BTN_FG      = options.ButtonColors.fg;

% Material presets
presets = fitting.reflSLDPresets();
presetNames = [{''}, {presets.name}];  % empty = manual entry

% ════════════════════════════════════════════════════════════════════════
% Build dialog (800 × 650)
% ════════════════════════════════════════════════════════════════════════

rfFig = uifigure('Name', 'Reflectivity Fitting', ...
    'Position', [180 80 800 650], 'Resize', 'on');

rfRoot = uigridlayout(rfFig, [4 2], ...
    'RowHeight', {'fit', '1x', '1x', 32}, ...
    'ColumnWidth', {'1x', '1x'}, ...
    'Padding', [8 6 8 6], 'RowSpacing', 6, 'ColumnSpacing', 6);

% ── Row 1: Controls ──────────────────────────────────────────────────
ctrlGL = uigridlayout(rfRoot, [1 8], ...
    'ColumnWidth', {80, 80, 80, 80, 80, 80, 80, '1x'}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 4);
ctrlGL.Layout.Row = 1; ctrlGL.Layout.Column = [1 2];

uibutton(ctrlGL, 'Text', 'Add Layer', 'FontSize', 9, ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'ButtonPushedFcn', @(~,~) addLayer());
uibutton(ctrlGL, 'Text', 'Remove', 'FontSize', 9, ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'ButtonPushedFcn', @(~,~) removeLayer());
uibutton(ctrlGL, 'Text', 'Simulate', 'FontSize', 9, ...
    'BackgroundColor', [0.22 0.44 0.22], 'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @(~,~) doSimulate());
uibutton(ctrlGL, 'Text', 'Fit', 'FontSize', 10, 'FontWeight', 'bold', ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @(~,~) doFit());
uibutton(ctrlGL, 'Text', 'MCMC...', 'FontSize', 9, ...
    'BackgroundColor', [0.45 0.25 0.55], 'FontColor', [1 1 1], ...
    'Tooltip', ['Sample the posterior around the current fit with ' ...
                'random-walk Metropolis and show a corner plot. ' ...
                'Run Fit first.'], ...
    'ButtonPushedFcn', @(~,~) doMCMC());
uibutton(ctrlGL, 'Text', 'Plot on Main', 'FontSize', 9, ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @(~,~) plotOnMain());
uibutton(ctrlGL, 'Text', 'Copy', 'FontSize', 9, ...
    'ButtonPushedFcn', @(~,~) copyResults());

lblFitStats = uilabel(ctrlGL, 'Text', '', ...
    'FontSize', 9, 'FontColor', [0.5 0.5 0.5], ...
    'HorizontalAlignment', 'right');
lblFitStats.Layout.Column = 8;

% ── Row 2 left: Layer table ──────────────────────────────────────────
tblLayers = uitable(rfRoot, ...
    'ColumnName', {'Material', 'd (Å)', 'SLD (×10⁻⁶)', 'SLD_imag', 'σ (Å)', 'Fixed'}, ...
    'ColumnEditable', [true true true true true true], ...
    'ColumnFormat', {presetNames, 'numeric', 'numeric', 'numeric', 'numeric', 'logical'}, ...
    'ColumnWidth', {'auto', 60, 80, 65, 55, 45}, ...
    'CellEditCallback', @onLayerEdit, ...
    'FontSize', 9);
tblLayers.Layout.Row = 2; tblLayers.Layout.Column = 1;

% ── Row 2 right: SLD profile ────────────────────────────────────────
axSLD = uiaxes(rfRoot);
axSLD.Layout.Row = 2; axSLD.Layout.Column = 2;
title(axSLD, 'SLD Profile');
xlabel(axSLD, 'Depth (Å)'); ylabel(axSLD, 'SLD (10^{-6} Å^{-2})');
axSLD.Box = 'on'; grid(axSLD, 'on');
bosonPlotter.applyAppearanceToAxes(axSLD, options.Appearance);

% ── Row 3: R(Q) plot (full width) ───────────────────────────────────
rfAxPanel = uigridlayout(rfRoot, [2 1], ...
    'RowHeight', {'3x', '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 2);
rfAxPanel.Layout.Row = 3; rfAxPanel.Layout.Column = [1 2];

axRQ = uiaxes(rfAxPanel);
axRQ.Layout.Row = 1;
title(axRQ, 'R(Q)');
xlabel(axRQ, 'Q (Å^{-1})'); ylabel(axRQ, 'Reflectivity');
axRQ.YScale = 'log'; axRQ.Box = 'on'; grid(axRQ, 'on');
bosonPlotter.applyAppearanceToAxes(axRQ, options.Appearance);

axRes = uiaxes(rfAxPanel);
axRes.Layout.Row = 2;
title(axRes, 'Residuals');
xlabel(axRes, 'Q (Å^{-1})'); ylabel(axRes, 'log(R) residual');
axRes.Box = 'on'; grid(axRes, 'on');
bosonPlotter.applyAppearanceToAxes(axRes, options.Appearance);

% ── Row 4: Scale/BG controls + close ────────────────────────────────
bottomGL = uigridlayout(rfRoot, [1 7], ...
    'ColumnWidth', {50, 65, 50, 65, 50, '1x', 60}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 4);
bottomGL.Layout.Row = 4; bottomGL.Layout.Column = [1 2];

uilabel(bottomGL, 'Text', 'Scale:', 'HorizontalAlignment', 'right', 'FontSize', 9);
efScale = uieditfield(bottomGL, 'numeric', 'Value', 1.0, 'FontSize', 9);
uilabel(bottomGL, 'Text', 'BG:', 'HorizontalAlignment', 'right', 'FontSize', 9);
efBG = uieditfield(bottomGL, 'numeric', 'Value', 1e-8, 'FontSize', 9, ...
    'ValueDisplayFormat', '%.2e');
uilabel(bottomGL, 'Text', 'Smear:', 'HorizontalAlignment', 'right', 'FontSize', 9);
efSmear = uieditfield(bottomGL, 'numeric', 'Value', 0, 'FontSize', 9, ...
    'Tooltip', 'Gaussian dQ/Q resolution smearing (0 = none)');
uibutton(bottomGL, 'Text', 'Close', 'FontSize', 9, ...
    'ButtonPushedFcn', @(~,~) delete(rfFig));

% State
rfResult = struct('Q', [], 'R', [], 'layers', [], 'R2', NaN);

% Initialize with default 3-layer stack: air / 200Å SiO2 / Si
initLayers();
updateSLDPlot();

% ════════════════════════════════════════════════════════════════════════
% Nested functions
% ════════════════════════════════════════════════════════════════════════

    function initLayers()
        tblLayers.Data = { ...
            'Air / Vacuum', 0,   0,       0,    0,   true; ...
            '',             200, 3.47,    0,    5,   false; ...
            'Silicon',      0,   2.073,   0,    3,   false};
    end

    function layers = getLayerMatrix()
    %GETLAYERMATRIX  Build [M×4] layer matrix from table data.
        data = tblLayers.Data;
        nR = size(data, 1);
        layers = zeros(nR, 4);
        for ri = 1:nR
            layers(ri, 1) = toNum(data{ri, 2});          % d
            layers(ri, 2) = toNum(data{ri, 3}) * 1e-6;   % SLD (table is ×10⁻⁶)
            layers(ri, 3) = toNum(data{ri, 4}) * 1e-6;   % SLD imag
            layers(ri, 4) = toNum(data{ri, 5});           % sigma
        end
    end

    function fixed = getFixedMask()
    %GETFIXEDMASK  Build fixed parameter mask from table checkboxes.
        data = tblLayers.Data;
        nR = size(data, 1);
        % 4 params per layer, but d for layers 1 and M are always fixed
        fixed = false(1, nR * 4);
        for ri = 1:nR
            baseIdx = (ri-1)*4;
            isFixed = logical(data{ri, 6});
            if isFixed
                fixed(baseIdx + (1:4)) = true;
            end
            % Always fix thickness of incident medium and substrate
            if ri == 1 || ri == nR
                fixed(baseIdx + 1) = true;
            end
        end
    end

    function addLayer()
        data = tblLayers.Data;
        nR = size(data, 1);
        % Insert before substrate (last row)
        newRow = {'', 100, 0, 0, 3, false};
        if nR >= 2
            data = [data(1:nR-1, :); newRow; data(nR, :)];
        else
            data = [data; newRow];
        end
        tblLayers.Data = data;
        updateSLDPlot();
    end

    function removeLayer()
        data = tblLayers.Data;
        nR = size(data, 1);
        if nR <= 2, return; end  % can't remove incident medium or substrate
        sel = tblLayers.Selection;
        if ~isempty(sel)
            row = sel(1, 1);
            if row > 1 && row < nR
                data(row, :) = [];
                tblLayers.Data = data;
                updateSLDPlot();
            end
        else
            % Remove last film layer (row before substrate)
            data(nR-1, :) = [];
            tblLayers.Data = data;
            updateSLDPlot();
        end
    end

    function onLayerEdit(~, evt)
        row = evt.Indices(1);
        col = evt.Indices(2);
        % If material column changed, auto-fill SLD
        if col == 1
            matName = evt.NewData;
            if ~isempty(matName)
                idx = find(strcmp({presets.name}, matName), 1);
                if ~isempty(idx)
                    tblLayers.Data{row, 3} = presets(idx).sldN * 1e6;  % display in ×10⁻⁶
                    tblLayers.Data{row, 4} = presets(idx).sldImag * 1e6;
                end
            end
        end
        updateSLDPlot();
    end

    function updateSLDPlot()
        layers = getLayerMatrix();
        if size(layers, 1) < 2, return; end
        [z, sldProf] = fitting.sldProfile(layers);
        cla(axSLD);
        plot(axSLD, z, sldProf * 1e6, 'b-', 'LineWidth', 1.5);
        xlabel(axSLD, 'Depth (Å)');
        ylabel(axSLD, 'SLD (10^{-6} Å^{-2})');
        title(axSLD, 'SLD Profile');
        grid(axSLD, 'on'); axSLD.Box = 'on';
    end

    function doSimulate()
        layers = getLayerMatrix();
        R = fitting.parrattRefl(xData, layers, ...
            Scale=efScale.Value, Background=efBG.Value);
        plotRQ(R, []);
        rfResult.Q = xData; rfResult.R = R; rfResult.layers = layers;
        options.StatusFcn('Simulation plotted');
    end

    function doFit()
        layers = getLayerMatrix();
        nR = size(layers, 1);

        % Flatten layer params into vector: [d1,sld1,sldi1,sig1, d2,sld2,...]
        p0 = layers(:)';
        fixedMask = getFixedMask();

        % Bounds: thickness >= 0, roughness >= 0, SLD free
        lb = repmat([-Inf -Inf -Inf 0], 1, nR);
        ub = repmat([Inf Inf Inf Inf], 1, nR);
        for ri = 1:nR
            lb((ri-1)*4 + 1) = 0;  % thickness >= 0
        end

        % Model function: reshape p vector back to layers matrix
        modelFcn = @(Q, p) fitting.parrattRefl(Q, reshape(p, [], 4), ...
            Scale=efScale.Value, Background=efBG.Value);

        % Fit in log space (reflectivity spans orders of magnitude)
        logY = log10(max(yData, 1e-15));
        logModel = @(Q, p) log10(max(modelFcn(Q, p), 1e-15));

        rfFig.Pointer = 'watch'; drawnow;
        try
            res = fitting.curveFit(xData, logY, logModel, p0, ...
                Lower=lb, Upper=ub, Fixed=fixedMask, CalcErrors=true);

            % Reshape fitted params back to layers
            fitLayers = reshape(res.params, [], 4);

            % Update table with fitted values
            for ri = 1:nR
                tblLayers.Data{ri, 2} = fitLayers(ri, 1);           % d
                tblLayers.Data{ri, 3} = fitLayers(ri, 2) * 1e6;     % SLD ×10⁻⁶
                tblLayers.Data{ri, 4} = fitLayers(ri, 3) * 1e6;     % SLD_imag
                tblLayers.Data{ri, 5} = fitLayers(ri, 4);           % sigma
            end

            % Compute R(Q) with fitted params (linear space)
            Rfit = fitting.parrattRefl(xData, fitLayers, ...
                Scale=efScale.Value, Background=efBG.Value);

            % R² in linear space
            ssRes = sum((yData - Rfit).^2);
            ssTot = sum((yData - mean(yData)).^2);
            R2lin = 1 - ssRes / max(ssTot, eps);

            plotRQ(Rfit, yData - Rfit);
            updateSLDPlot();

            rfResult.Q = xData; rfResult.R = Rfit;
            rfResult.layers = fitLayers; rfResult.R2 = R2lin;

            lblFitStats.Text = sprintf('R%s=%.4f  %s%s=%.4g  Exit=%d', ...
                char(178), R2lin, char(967), char(178), res.chiSqRed, res.exitFlag);

            rfFig.Pointer = 'arrow';
            options.StatusFcn(sprintf('Refl fit: R%s=%.4f', char(178), R2lin));
        catch ME
            rfFig.Pointer = 'arrow';
            uialert(rfFig, sprintf('Fit failed:\n%s', ME.message), 'Error');
        end
    end

    function doMCMC()
    %DOMCMC  Sample the posterior around the current layer fit.
    %   Requires a successful fit first (uses fitted layers as seed and
    %   estimates σ from log-residuals). Only unfixed parameters are
    %   sampled; fixed params are held constant. Shows a corner plot on
    %   completion.
        if isempty(rfResult.layers) || isempty(rfResult.R)
            uialert(rfFig, 'Run Fit first — MCMC samples around the current best fit.', ...
                'MCMC');
            return;
        end

        % Ask for sampler settings
        defAns = inputdlg({'Steps', 'Burn-in', 'Step size (σ/|p|)'}, ...
            'MCMC sampling', 1, {'2000', '500', '0.05'});
        if isempty(defAns), return; end
        nSteps  = str2double(defAns{1});
        nBurn   = str2double(defAns{2});
        stepSz  = str2double(defAns{3});
        if ~isfinite(nSteps) || nSteps < 100 || ~isfinite(nBurn) || ...
                ~isfinite(stepSz) || stepSz <= 0
            uialert(rfFig, 'Invalid MCMC settings.', 'MCMC');
            return;
        end

        fitLayers = rfResult.layers;
        nR        = size(fitLayers, 1);
        pBest     = fitLayers(:)';       % [d1 sldR1 sldI1 sig1 d2 ...]
        fixedMask = getFixedMask();

        % Bounds (same as doFit)
        lb = repmat([-Inf -Inf -Inf 0], 1, nR);
        ub = repmat([Inf Inf Inf Inf], 1, nR);
        for ri = 1:nR
            lb((ri-1)*4 + 1) = 0;
        end

        % Free-parameter indices and human labels
        freeIdx = find(~fixedMask);
        if isempty(freeIdx)
            uialert(rfFig, 'All parameters are fixed — nothing to sample.', 'MCMC');
            return;
        end
        paramNames = repmat({''}, 1, numel(pBest));
        for ri = 1:nR
            base = (ri-1)*4;
            paramNames{base+1} = sprintf('d_{%d}', ri);
            paramNames{base+2} = sprintf('SLD_{%d}', ri);
            paramNames{base+3} = sprintf('SLDi_{%d}', ri);
            paramNames{base+4} = sprintf('\\sigma_{%d}', ri);
        end

        % Noise-level estimate: σ² from log-residuals at best fit
        logY   = log10(max(yData, 1e-15));
        logR   = log10(max(rfResult.R, 1e-15));
        sigma2 = max(var(logY - logR), eps);

        % Per-dim proposal scale; fixed params get 0 so they stay at pBest.
        % mcmcSample uses a single scalar StepSize, so we sample in
        % whitened coordinates  q = (p - pBest) ./ scaleVec  with step=1
        % and transform back to p-space for the model call.
        scaleVec = zeros(1, numel(pBest));
        scaleVec(freeIdx) = max(abs(pBest(freeIdx)), 1e-6) * stepSz;

        logPost = @(q) logPosteriorRefl(q, pBest, scaleVec, lb, ub, ...
            fixedMask, sigma2, xData, yData, ...
            efScale.Value, efBG.Value);

        rfFig.Pointer = 'watch'; drawnow;
        try
            qInit = zeros(1, numel(pBest));
            mcRes = fitting.mcmcSample(logPost, qInit, ...
                NumSteps=nSteps, BurnIn=nBurn, StepSize=1.0);

            % Transform q-samples back to physical parameters
            pSamples = pBest + mcRes.samples .* scaleVec;

            freeSamples = pSamples(:, freeIdx);
            freeLabels  = paramNames(freeIdx);
            freeTruth   = pBest(freeIdx);

            plotting.cornerPlot(freeSamples, Labels=freeLabels, Truth=freeTruth);

            rfFig.Pointer = 'arrow';
            options.StatusFcn(sprintf(...
                'MCMC: %d samples, accept=%.1f%% (scaffold sampler — see docs/theory/fitting.md)', ...
                size(freeSamples,1), 100*mcRes.acceptRate));
        catch ME
            rfFig.Pointer = 'arrow';
            uialert(rfFig, sprintf('MCMC failed:\n%s', ME.message), 'Error');
        end
    end

    function plotRQ(Rmodel, residuals)
        cla(axRQ);
        semilogy(axRQ, xData, yData, 'k.', 'MarkerSize', 3);
        hold(axRQ, 'on');
        semilogy(axRQ, xData, max(Rmodel, 1e-15), 'r-', 'LineWidth', 1.5);
        hold(axRQ, 'off');
        legend(axRQ, {'Data', 'Model'}, 'Location', 'southwest');
        title(axRQ, 'R(Q)');
        axRQ.YScale = 'log'; grid(axRQ, 'on'); axRQ.Box = 'on';

        if ~isempty(residuals)
            cla(axRes);
            stem(axRes, xData, log10(max(yData,1e-15)) - log10(max(Rmodel,1e-15)), ...
                'b.', 'MarkerSize', 3);
            hold(axRes, 'on');
            yline(axRes, 0, 'k--');
            hold(axRes, 'off');
            title(axRes, 'log(R) Residuals');
            grid(axRes, 'on'); axRes.Box = 'on';
        end
    end

    function plotOnMain()
        if isempty(rfResult.R), return; end
        hold(mainAx, 'on');
        plot(mainAx, rfResult.Q, rfResult.R, 'r-', 'LineWidth', 1.5, ...
            'DisplayName', 'Refl Fit', 'Tag', 'reflFitOverlay');
        hold(mainAx, 'off');
        options.StatusFcn('Reflectivity fit overlaid on main axes');
    end

    function copyResults()
        if isempty(rfResult.layers), return; end
        lines = {};
        lines{end+1} = 'Reflectivity Fit Results';
        lines{end+1} = sprintf('R² = %.6f', rfResult.R2);
        lines{end+1} = '';
        lines{end+1} = sprintf('%-20s %10s %12s %10s %8s', ...
            'Material', 'd (Å)', 'SLD (×10⁻⁶)', 'SLD_imag', 'σ (Å)');
        lines{end+1} = repmat('-', 1, 62);
        data = tblLayers.Data;
        for ri = 1:size(data, 1)
            matName = data{ri, 1};
            if isempty(matName), matName = '—'; end
            lines{end+1} = sprintf('%-20s %10.2f %12.4f %10.4f %8.2f', ...
                matName, rfResult.layers(ri,1), rfResult.layers(ri,2)*1e6, ...
                rfResult.layers(ri,3)*1e6, rfResult.layers(ri,4)); %#ok<AGROW>
        end
        clipboard('copy', strjoin(lines, newline));
        options.StatusFcn('Reflectivity fit results copied to clipboard');
    end

end

function v = toNum(val)
    if isnumeric(val), v = val;
    elseif ischar(val) || isstring(val), v = str2double(val);
    else, v = 0;
    end
    if isnan(v), v = 0; end
end

function lp = logPosteriorRefl(q, pBest, scaleVec, lb, ub, fixedMask, ...
        sigma2, xData, yData, sc, bg)
%LOGPOSTERIORREFL  Log-posterior for MCMC sampling around a refl fit.
%   q is in whitened coordinates; p = pBest + q.*scaleVec. Fixed params
%   have scaleVec=0 so q never moves them. Prior is flat inside the
%   [lb, ub] box and -Inf outside; likelihood is Gaussian on
%   log10(reflectivity) residuals with variance sigma2.
    p = pBest + q .* scaleVec;
    p(fixedMask) = pBest(fixedMask);        % hard-lock fixed params
    if any(p < lb) || any(p > ub)
        lp = -Inf; return;
    end
    try
        layers = reshape(p, [], 4);
        R = fitting.parrattRefl(xData, layers, Scale=sc, Background=bg);
        logModel = log10(max(R,      1e-15));
        logY     = log10(max(yData,  1e-15));
        resid    = logY - logModel;
        lp = -0.5 * sum(resid.^2) / sigma2;
    catch
        lp = -Inf;
    end
end
