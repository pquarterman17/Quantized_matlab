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

% Material presets. Prepend a non-empty placeholder for "manual entry" —
% R2025b's uitable rejects empty strings in popupmenu ColumnFormat lists.
presets = fitting.reflSLDPresets();
MANUAL_ENTRY = '(manual)';
presetNames = [{MANUAL_ENTRY}, {presets.name}];

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
ctrlGL = uigridlayout(rfRoot, [1 9], ...
    'ColumnWidth', {44, 70, 75, 75, 80, 80, 80, 80, '1x'}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 4);
ctrlGL.Layout.Row = 1; ctrlGL.Layout.Column = [1 2];

uilabel(ctrlGL, 'Text', 'Mode:', 'HorizontalAlignment', 'right', 'FontSize', 9);
ddMode = uidropdown(ctrlGL, 'Items', {'Layers', 'Spline'}, ...
    'Value', 'Layers', 'FontSize', 9, ...
    'Tooltip', ['Layers: classic box-stack with explicit roughness. ' ...
                'Spline: free-form SLD(z) from knot points (PCHIP), ' ...
                'for graded interfaces and model-independent fits.'], ...
    'ValueChangedFcn', @(~,~) onModeChanged());

btnAdd = uibutton(ctrlGL, 'Text', 'Add Layer', 'FontSize', 9, ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'ButtonPushedFcn', @(~,~) addRow());
btnRemove = uibutton(ctrlGL, 'Text', 'Remove', 'FontSize', 9, ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'ButtonPushedFcn', @(~,~) removeRow()); %#ok<NASGU>
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

% ── Row 2 left: Layer table (Layers mode) ──────────────────────────
tblLayers = uitable(rfRoot, ...
    'ColumnName', {'Material', 'd (Å)', 'SLD (×10⁻⁶)', 'SLD_imag', 'σ (Å)', 'Fixed'}, ...
    'ColumnEditable', [true true true true true true], ...
    'ColumnFormat', {presetNames, 'numeric', 'numeric', 'numeric', 'numeric', 'logical'}, ...
    'ColumnWidth', {'auto', 60, 80, 65, 55, 45}, ...
    'CellEditCallback', @onLayerEdit, ...
    'FontSize', 9);
tblLayers.Layout.Row = 2; tblLayers.Layout.Column = 1;

% ── Row 2 left: Knot table (Spline mode, hidden initially) ─────────
% Knot data for the spline-SLD profile: each row is one (z, SLD) pair.
% Profile interpolates between adjacent knots (PCHIP); plateaus to first /
% last knot's SLD outside the knot range — those values become the
% ambient (z<min) and substrate (z>max) plateaus expected by parrattRefl.
tblKnots = uitable(rfRoot, ...
    'ColumnName', {'z (Å)', 'SLD (×10⁻⁶)', 'Fixed'}, ...
    'ColumnEditable', [true true true], ...
    'ColumnFormat', {'numeric', 'numeric', 'logical'}, ...
    'ColumnWidth', {'auto', 100, 60}, ...
    'CellEditCallback', @(~,~) updateSLDPlot(), ...
    'FontSize', 9, ...
    'Visible', 'off');
tblKnots.Layout.Row = 2; tblKnots.Layout.Column = 1;

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
bottomGL = uigridlayout(rfRoot, [1 9], ...
    'ColumnWidth', {50, 65, 40, 65, 50, 65, 100, '1x', 60}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 4);
bottomGL.Layout.Row = 4; bottomGL.Layout.Column = [1 2];

uilabel(bottomGL, 'Text', 'Scale:', 'HorizontalAlignment', 'right', 'FontSize', 9);
efScale = uieditfield(bottomGL, 'numeric', 'Value', 1.0, 'FontSize', 9);
uilabel(bottomGL, 'Text', 'BG:', 'HorizontalAlignment', 'right', 'FontSize', 9);
efBG = uieditfield(bottomGL, 'numeric', 'Value', 1e-8, 'FontSize', 9, ...
    'ValueDisplayFormat', '%.2e');
uilabel(bottomGL, 'Text', 'dQ/Q:', 'HorizontalAlignment', 'right', 'FontSize', 9);
efSmear = uieditfield(bottomGL, 'numeric', 'Value', 0, 'FontSize', 9, ...
    'Tooltip', ['Gaussian resolution smearing as fractional dQ/Q ' ...
                '(e.g. 0.03 for NCNR typical). 0 = sharp Q.']);
cbPointwise = uicheckbox(bottomGL, 'Text', 'Pointwise', 'FontSize', 9, ...
    'Value', false, ...
    'Tooltip', ['When checked, use per-point σ_Q from the dataset''s ' ...
                'dQ column (e.g. NCNR reductus exports). Overrides ' ...
                'the dQ/Q field. Falls back to dQ/Q if no dQ column ' ...
                'is found.']);
btnClose = uibutton(bottomGL, 'Text', 'Close', 'FontSize', 9, ...
    'ButtonPushedFcn', @(~,~) delete(rfFig));
btnClose.Layout.Column = 9;

% State
rfResult = struct('Q', [], 'R', [], 'layers', [], 'R2', NaN);

% Initialize with default 3-layer stack: air / 200Å SiO2 / Si
initLayers();
initKnots();
updateSLDPlot();

% ════════════════════════════════════════════════════════════════════════
% Nested functions
% ════════════════════════════════════════════════════════════════════════

    function initLayers()
        tblLayers.Data = { ...
            'Air / Vacuum', 0,   0,       0,    0,   true; ...
            MANUAL_ENTRY,   200, 3.47,    0,    5,   false; ...
            'Silicon',      0,   2.073,   0,    3,   false};
    end

    function initKnots()
        % Default: 5 knots forming a smoothed equivalent of the box stack
        % (air → 200 Å of SiO₂ → Si). The two endpoint knots set the
        % ambient (z<0) and substrate (z>200) plateaus respectively.
        tblKnots.Data = { ...
                0,    0.000,  true;  ...   % ambient endpoint (z=0, vacuum)
               40,    3.470,  false; ...   % entering film
              100,    3.470,  false; ...   % mid-film
              160,    3.470,  false; ...   % exiting film
              200,    2.073,  true};       % substrate endpoint (z=200, Si)
    end

    function isSpline = inSplineMode()
        isSpline = strcmp(ddMode.Value, 'Spline');
    end

    function onModeChanged()
        % Toggle table visibility and update the Add button label.
        if inSplineMode()
            tblLayers.Visible = 'off';
            tblKnots.Visible  = 'on';
            btnAdd.Text       = 'Add Knot';
        else
            tblKnots.Visible  = 'off';
            tblLayers.Visible = 'on';
            btnAdd.Text       = 'Add Layer';
        end
        updateSLDPlot();
    end

    function addRow()
        if inSplineMode()
            addKnot();
        else
            addLayer();
        end
    end

    function removeRow()
        if inSplineMode()
            removeKnot();
        else
            removeLayer();
        end
    end

    function addKnot()
        data = tblKnots.Data;
        nR   = size(data, 1);
        sel  = tblKnots.Selection;
        % Insert after selected row (or before last knot if no selection)
        if ~isempty(sel)
            insertAfter = sel(1, 1);
        else
            insertAfter = nR - 1;
        end
        insertAfter = max(1, min(insertAfter, nR - 1));
        zNew   = 0.5 * (toNum(data{insertAfter, 1}) + toNum(data{insertAfter+1, 1}));
        sldNew = 0.5 * (toNum(data{insertAfter, 2}) + toNum(data{insertAfter+1, 2}));
        newRow = {zNew, sldNew, false};
        data   = [data(1:insertAfter, :); newRow; data(insertAfter+1:end, :)];
        tblKnots.Data = data;
        updateSLDPlot();
    end

    function removeKnot()
        data = tblKnots.Data;
        nR   = size(data, 1);
        if nR <= 2, return; end
        sel = tblKnots.Selection;
        if ~isempty(sel)
            row = sel(1, 1);
            if row > 1 && row < nR
                data(row, :) = [];
                tblKnots.Data = data;
                updateSLDPlot();
            end
        else
            data(nR-1, :) = [];   % remove second-to-last by default
            tblKnots.Data = data;
            updateSLDPlot();
        end
    end

    function layers = getLayerMatrix()
    %GETLAYERMATRIX  Build [M×4] layer matrix for fitting.parrattRefl.
    %   In Layers mode, reads the box-stack table directly. In Spline
    %   mode, microslices the spline-interpolated SLD(z) profile.
        if inSplineMode()
            layers = bosonPlotter.reflBuildSplineLayers(tblKnots.Data);
            return;
        end
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

    function resArg = getResolutionArg()
    %GETRESOLUTIONARG  Build the Resolution kwarg for fitting.parrattRefl.
    %   Returns [] (no smearing), a scalar dQ/Q, or an [N×1] per-point σ_Q
    %   vector. Pointwise mode scans plotD.labels for a dQ-like column
    %   (dQ, resolution, sigma_q); if none is found, silently falls back
    %   to the scalar field (the tooltip warns the user this can happen).
        resArg = [];
        if cbPointwise.Value
            dQvec = findPointwiseDQ(plotD, numel(xData));
            if ~isempty(dQvec)
                resArg = dQvec(:);
                return;
            end
        end
        s = efSmear.Value;
        if isfinite(s) && s > 0
            resArg = s;
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
        newRow = {MANUAL_ENTRY, 100, 0, 0, 3, false};
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
        % If material column changed and the user picked a real preset
        % (not the (manual) placeholder), auto-fill SLD.
        if col == 1
            matName = evt.NewData;
            if ~isempty(matName) && ~strcmp(matName, MANUAL_ENTRY)
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
        cla(axSLD);
        if inSplineMode()
            % Re-run splineSLD directly so the plot can also overlay knot
            % markers — getLayerMatrix would only give us the microsliced
            % output and we'd lose the knot positions.
            data = tblKnots.Data;
            nR   = size(data, 1);
            if nR < 2, return; end
            zK   = cellfun(@toNum, data(:, 1));
            sldK = cellfun(@toNum, data(:, 2)) * 1e-6;
            [zK, sortIdx] = sort(zK);
            sldK = sldK(sortIdx);
            try
                [z, sldProf] = fitting.splineSLD(zK, sldK, ...
                    SldAmbient=sldK(1), SldSubstrate=sldK(end), ...
                    ZRange=[zK(1)-50, zK(end)+50], NPoints=400);
            catch
                return;   % e.g. duplicate z — silently bail until user fixes
            end
            plot(axSLD, z, sldProf * 1e6, 'b-', 'LineWidth', 1.5);
            hold(axSLD, 'on');
            plot(axSLD, zK, sldK * 1e6, 'ro', ...
                'MarkerFaceColor', [1 0.75 0.75], 'MarkerSize', 6);
            hold(axSLD, 'off');
        else
            layers = getLayerMatrix();
            if size(layers, 1) < 2, return; end
            [z, sldProf] = fitting.sldProfile(layers);
            plot(axSLD, z, sldProf * 1e6, 'b-', 'LineWidth', 1.5);
        end
        xlabel(axSLD, 'Depth (Å)');
        ylabel(axSLD, 'SLD (10^{-6} Å^{-2})');
        title(axSLD, 'SLD Profile');
        grid(axSLD, 'on'); axSLD.Box = 'on';
    end

    function doSimulate()
        layers = getLayerMatrix();
        resArg = getResolutionArg();
        R = fitting.parrattRefl(xData, layers, ...
            Scale=efScale.Value, Background=efBG.Value, ...
            Resolution=resArg);
        plotRQ(R, []);
        rfResult.Q = xData; rfResult.R = R; rfResult.layers = layers;
        options.StatusFcn(['Simulation plotted' resolutionStatusSuffix(resArg)]);
    end

    function doFit()
        if inSplineMode()
            doFitSpline();
            return;
        end
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

        % Snapshot the resolution arg at fit-start so every model call in
        % the curveFit loop uses the same kernel.
        resArg = getResolutionArg();

        % Model function: reshape p vector back to layers matrix
        modelFcn = @(Q, p) fitting.parrattRefl(Q, reshape(p, [], 4), ...
            Scale=efScale.Value, Background=efBG.Value, ...
            Resolution=resArg);

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
                Scale=efScale.Value, Background=efBG.Value, ...
                Resolution=resArg);

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

    function doFitSpline()
    %DOFITSPLINE  Fit knot z and SLD parameters in Spline mode.
    %   Parameter layout: p = [z1, z2, ..., zN, sld1*1e6, sld2*1e6, ..., sldN*1e6]
    %   Two blocks (z then SLD) so the param vector is easy to reshape.
    %   Each knot's "Fixed" checkbox locks BOTH its z and its SLD.
    %   Bounds: z within zRange-padding window; SLD within ±20×10⁻⁶
    %   (covers all common materials including D₂O at 6.36 and dense oxides).
        data = tblKnots.Data;
        nK   = size(data, 1);
        if nK < 2
            uialert(rfFig, 'Spline mode needs at least 2 knots.', 'Fit');
            return;
        end
        zK0   = cellfun(@toNum, data(:, 1));
        sldK0 = cellfun(@toNum, data(:, 2));               % already in ×10⁻⁶
        knotFixed = cellfun(@logical, data(:, 3));

        p0    = [zK0; sldK0]';                             % [N z, N sld] block layout
        nP    = numel(p0);
        fixed = false(1, nP);
        fixed(1:nK)         = knotFixed;                   % lock z when knot is fixed
        fixed(nK+1:2*nK)    = knotFixed;                   % lock SLD when knot is fixed

        zSpan = max(zK0(end) - zK0(1), 1);
        zPad  = max(50, 0.25 * zSpan);
        lb_z   = (zK0(1) - zPad) * ones(1, nK);
        ub_z   = (zK0(end) + zPad) * ones(1, nK);
        % First/last z are typically anchors — clamp them tighter
        lb_z(1)    = zK0(1)   - 1; ub_z(1)    = zK0(1)   + 1;
        lb_z(end)  = zK0(end) - 1; ub_z(end)  = zK0(end) + 1;
        lb_sld = -20 * ones(1, nK);   % ×10⁻⁶
        ub_sld =  20 * ones(1, nK);
        lb = [lb_z, lb_sld];
        ub = [ub_z, ub_sld];

        resArg = getResolutionArg();
        sc     = efScale.Value;
        bg     = efBG.Value;

        modelFcn    = @(Q, p) splineModel(Q, p, nK, sc, bg, resArg);
        logModelFcn = @(Q, p) log10(max(modelFcn(Q, p), 1e-15));
        logY        = log10(max(yData, 1e-15));

        rfFig.Pointer = 'watch'; drawnow;
        try
            res = fitting.curveFit(xData, logY, logModelFcn, p0, ...
                Lower=lb, Upper=ub, Fixed=fixed, CalcErrors=true);

            % Write fitted params back into the knot table
            zFit   = res.params(1:nK);
            sldFit = res.params(nK+1:2*nK);
            for ki = 1:nK
                tblKnots.Data{ki, 1} = zFit(ki);
                tblKnots.Data{ki, 2} = sldFit(ki);
            end

            % Final R(Q) and residuals
            Rfit = modelFcn(xData, res.params);
            ssRes = sum((yData - Rfit).^2);
            ssTot = sum((yData - mean(yData)).^2);
            R2lin = 1 - ssRes / max(ssTot, eps);

            plotRQ(Rfit, yData - Rfit);
            updateSLDPlot();

            fitLayers = bosonPlotter.reflBuildSplineLayers(tblKnots.Data);
            rfResult.Q = xData; rfResult.R = Rfit;
            rfResult.layers = fitLayers; rfResult.R2 = R2lin;

            lblFitStats.Text = sprintf('R%s=%.4f  %s%s=%.4g  Exit=%d  [Spline %d kn]', ...
                char(178), R2lin, char(967), char(178), res.chiSqRed, res.exitFlag, nK);

            rfFig.Pointer = 'arrow';
            options.StatusFcn(sprintf('Refl fit (spline): R%s=%.4f, %d knots', ...
                char(178), R2lin, nK));
        catch ME
            rfFig.Pointer = 'arrow';
            uialert(rfFig, sprintf('Spline fit failed:\n%s', ME.message), 'Error');
        end
    end

    function doMCMC()
    %DOMCMC  Sample the posterior around the current layer fit.
    %   Requires a successful fit first (uses fitted layers as seed and
    %   estimates σ from log-residuals). Only unfixed parameters are
    %   sampled; fixed params are held constant. Shows a corner plot on
    %   completion.
        if inSplineMode()
            uialert(rfFig, ['MCMC is only supported in Layers mode for now. ' ...
                'Spline-mode posterior sampling needs a knot-aware ' ...
                'parameter scaling and is on the W3 #11 follow-up list. ' ...
                'Switch to Layers mode and re-fit to use MCMC.'], 'MCMC');
            return;
        end
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

        resArgMCMC = getResolutionArg();
        logPost = @(q) logPosteriorRefl(q, pBest, scaleVec, lb, ub, ...
            fixedMask, sigma2, xData, yData, ...
            efScale.Value, efBG.Value, resArgMCMC);

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
        if inSplineMode()
            lines{end+1} = 'Reflectivity Fit Results (Spline mode)';
            lines{end+1} = sprintf('R² = %.6f', rfResult.R2);
            lines{end+1} = '';
            lines{end+1} = sprintf('%10s %14s %8s', 'z (Å)', 'SLD (×10⁻⁶)', 'Fixed');
            lines{end+1} = repmat('-', 1, 36);
            data = tblKnots.Data;
            for ri = 1:size(data, 1)
                lines{end+1} = sprintf('%10.2f %14.4f %8s', ...
                    toNum(data{ri, 1}), toNum(data{ri, 2}), ...
                    yesNo(logical(data{ri, 3}))); %#ok<AGROW>
            end
        else
            lines{end+1} = 'Reflectivity Fit Results';
            lines{end+1} = sprintf('R² = %.6f', rfResult.R2);
            lines{end+1} = '';
            lines{end+1} = sprintf('%-20s %10s %12s %10s %8s', ...
                'Material', 'd (Å)', 'SLD (×10⁻⁶)', 'SLD_imag', 'σ (Å)');
            lines{end+1} = repmat('-', 1, 62);
            data = tblLayers.Data;
            for ri = 1:size(data, 1)
                matName = data{ri, 1};
                if isempty(matName) || strcmp(matName, MANUAL_ENTRY)
                    matName = '—';
                end
                lines{end+1} = sprintf('%-20s %10.2f %12.4f %10.4f %8.2f', ...
                    matName, rfResult.layers(ri,1), rfResult.layers(ri,2)*1e6, ...
                    rfResult.layers(ri,3)*1e6, rfResult.layers(ri,4)); %#ok<AGROW>
            end
        end
        clipboard('copy', strjoin(lines, newline));
        options.StatusFcn('Reflectivity fit results copied to clipboard');
    end

    function s = yesNo(b)
        if b, s = 'yes'; else, s = 'no'; end
    end

end

function v = toNum(val)
    if isnumeric(val), v = val;
    elseif ischar(val) || isstring(val), v = str2double(val);
    else, v = 0;
    end
    if isnan(v), v = 0; end
end

function dQvec = findPointwiseDQ(pd, nExpected)
%FINDPOINTWISEDQ  Locate a per-point σ_Q column in a dataset's values.
%   Returns [] if no dQ-like column exists or the column length doesn't
%   match nExpected. Candidate labels (case-insensitive): 'dq',
%   'resolution', 'sigma_q', 'sigmaq'. Matches importNCNRRefl and
%   importNCNRDat conventions.
    dQvec = [];
    if ~isstruct(pd) || ~isfield(pd, 'labels') || isempty(pd.labels)
        return;
    end
    if ~isfield(pd, 'values') || isempty(pd.values), return; end
    candidates = {'dq', 'resolution', 'sigma_q', 'sigmaq'};
    lbls = lower(string(pd.labels));
    for ci = 1:numel(candidates)
        idx = find(lbls == candidates{ci}, 1);
        if ~isempty(idx) && idx <= size(pd.values, 2)
            col = pd.values(:, idx);
            if numel(col) == nExpected && all(isfinite(col)) && all(col >= 0)
                dQvec = col;
                return;
            end
        end
    end
end

function suffix = resolutionStatusSuffix(resArg)
%RESOLUTIONSTATUSSUFFIX  Short " (dQ/Q=X)" or " (pointwise σ_Q)" tag for
%   the status bar, so the user can tell at a glance whether smearing
%   was applied.
    if isempty(resArg)
        suffix = '';
    elseif isscalar(resArg)
        suffix = sprintf(' (dQ/Q=%.3g)', resArg);
    else
        suffix = sprintf(' (pointwise σ_Q, n=%d)', numel(resArg));
    end
end

function lp = logPosteriorRefl(q, pBest, scaleVec, lb, ub, fixedMask, ...
        sigma2, xData, yData, sc, bg, resArg)
%LOGPOSTERIORREFL  Log-posterior for MCMC sampling around a refl fit.
%   q is in whitened coordinates; p = pBest + q.*scaleVec. Fixed params
%   have scaleVec=0 so q never moves them. Prior is flat inside the
%   [lb, ub] box and -Inf outside; likelihood is Gaussian on
%   log10(reflectivity) residuals with variance sigma2. resArg threads
%   the instrument Q-resolution kernel (see fitting.parrattRefl) so the
%   sampler sees the same smeared model the fit converged on.
    p = pBest + q .* scaleVec;
    p(fixedMask) = pBest(fixedMask);        % hard-lock fixed params
    if any(p < lb) || any(p > ub)
        lp = -Inf; return;
    end
    try
        layers = reshape(p, [], 4);
        R = fitting.parrattRefl(xData, layers, ...
            Scale=sc, Background=bg, Resolution=resArg);
        logModel = log10(max(R,      1e-15));
        logY     = log10(max(yData,  1e-15));
        resid    = logY - logModel;
        lp = -0.5 * sum(resid.^2) / sigma2;
    catch
        lp = -Inf;
    end
end

function R = splineModel(Q, p, nK, sc, bg, resArg)
%SPLINEMODEL  Reflectivity model for spline-mode fitting.
%   Reconstructs the (z, SLD) knot table from parameter vector
%   p = [z1..zN, sld1..sldN] (SLD in ×10⁻⁶ units), builds the
%   spline-microsliced layer matrix via reflBuildSplineLayers, and
%   evaluates parrattRefl with the dialog's scale / background /
%   resolution kwargs. Out-of-order z values from the fitter are
%   handled inside reflBuildSplineLayers (sort + de-duplicate), so
%   the model is well-defined even mid-iteration.
    knotData = cell(nK, 3);
    for ki = 1:nK
        knotData{ki, 1} = p(ki);
        knotData{ki, 2} = p(nK + ki);
        knotData{ki, 3} = false;
    end
    layers = bosonPlotter.reflBuildSplineLayers(knotData);
    R = fitting.parrattRefl(Q, layers, ...
        Scale=sc, Background=bg, Resolution=resArg);
end
