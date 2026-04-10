function renderPlot(targetAx, ctx)
%RENDERPLOT  Render selected datasets into the given axes.
%
%   Syntax
%     bosonPlotter.renderPlot(targetAx, ctx)
%
%   Inputs
%     targetAx  — axes handle to render into
%     ctx       — struct containing all rendering state:
%
%   ctx fields
%     .appData          — application state struct
%     .plotIdx          — indices of datasets to plot
%     .xSel             — X-axis column selection string
%     .xName            — resolved X-axis name
%     .xUnit            — resolved X-axis unit
%     .xLabel           — resolved X-axis label string
%     .ySel             — cell array of Y-channel names
%     .y2Sel            — cell array of Y2-channel names (empty if no Y2)
%     .colormapName     — colormap name string
%     .useWfGradient    — logical, gradient waterfall mode
%     .waterfallOn      — logical, waterfall enabled
%     .effectiveSpacing — waterfall spacing value (already resolved)
%     .scaleX           — 'Log' or 'Linear'
%     .scaleY           — 'Log' or 'Linear'
%     .scaleY2          — 'Log' or 'Linear'
%     .showLegend       — logical
%     .showRaw          — logical, show raw overlay
%     .countsPerSec     — logical
%     .style            — line style string
%     .ddMap2DType      — 2D map type string
%     .calculateAsymmetry — logical
%     .asymFormula      — 'Linear' or 'Log'
%     .xMin, .xMax, .xStep — axis limit strings ('' = auto)
%     .yMin, .yMax, .yStep — axis limit strings
%     .y2Min, .y2Max, .y2Step — Y2 axis limit strings
%     .xFmt, .yFmt, .y2Fmt — tick format strings
%     .customXLabel, .customYLabel, .customY2Label, .customTitle — label strings
%     .isMainAx         — logical, true when targetAx is the main GUI axes
%     .efXMin, .efXMax, .efYMin, .efYMax, .efY2Min, .efY2Max — widget handles
%     .axLimGL          — grid layout handle (for Y2 row height)
%     .fig              — figure handle
%     % Function handles for callbacks that remain in BosonPlotter:
%     .draw2DMap               — @(targetAx, ds) draw2DMap(targetAx, ds)
%     .computeAutoWaterfallSpacing — @() computeAutoWaterfallSpacing()
%     .toggleY2Appearance      — @(active) toggleY2Appearance(active)
%     .applyAxisPrefix         — @(ax, which, info) applyAxisPrefix(ax, which, info)
%     .recreateFringeMarkers   — @() recreateFringeMarkers()
%     .resolvedCorrStyle       — @() resolvedCorrStyle()
%     .getColorsFromMap        — @(name, n) getColorsFromMap(name, n)
%     .findPolarizationPairs   — @(datasets) findPolarizationPairs(datasets)
%     .setStatus               — @(msg) setStatus(msg)
%     .logGUIError             — @(tag, msg, ME) logGUIError(tag, msg, ME)
%
%   Examples
%     bosonPlotter.renderPlot(ax, ctx)

% ════════════════════════════════════════════════════════════════════════════

    try
        appData = ctx.appData;

        if isempty(appData.datasets) || appData.activeIdx < 1, return; end

        activeDs = appData.datasets{appData.activeIdx};

        % ── Determine which datasets to plot ─────────────────────────────
        plotIdx = ctx.plotIdx;
        nDS = numel(plotIdx);

        % ── Channel selection ─────────────────────────────────────────────
        xSel   = ctx.xSel;
        xName  = ctx.xName;
        xUnit  = ctx.xUnit;
        xLabel = ctx.xLabel;

        % Override axis labels when magnetometry unit conversion is active
        magYLabel = '';
        isMagActive = ~isempty(activeDs.corrData) && ...
            ismember(guiTernary(isfield(activeDs,'parserName'), activeDs.parserName, ''), ...
                {'importQDVSM','importPPMS','importMPMS','importLakeShore'});
        if isMagActive
            fu = guiTernary(isfield(activeDs,'fieldUnit'),  activeDs.fieldUnit,  'Oe (raw)');
            mu = guiTernary(isfield(activeDs,'momentUnit'), activeDs.momentUnit, 'emu (raw)');
            if ~strcmp(fu, 'Oe (raw)')
                fuClean = regexprep(fu, ' \(raw\)', '');
                xLabel = sprintf('Magnetic Field (%s)', fuClean);
            end
            if ~strcmp(mu, 'emu (raw)')
                magYLabel = sprintf('Magnetization (%s)', mu);
            end
        end

        ySel = ctx.ySel;
        nY   = numel(ySel);

        y2Sel = ctx.y2Sel;
        nY2   = numel(y2Sel);
        hasY2 = nY2 > 0;

        % ── Colour allocation ─────────────────────────────────────────────
        colormapName = ctx.colormapName;
        nColors = max(nDS * (nY + nY2), 1);
        useWfGradient = ctx.waterfallOn && ctx.useWfGradient && nDS > 1;
        if useWfGradient
            gradCmap = interp1([0 0.5 1], ...
                [0.23 0.30 0.75; 0.87 0.87 0.87; 0.71 0.02 0.15], ...
                linspace(0, 1, nDS)', 'pchip');
            colors = zeros(nColors, 3);
            for gi = 1:nDS
                for gk = 1:nY
                    colors((gi-1)*nY + gk, :) = gradCmap(gi, :);
                end
                for gk = 1:nY2
                    colors(nDS*nY + (gi-1)*nY2 + gk, :) = gradCmap(gi, :);
                end
            end
        else
            colors = ctx.getColorsFromMap(colormapName, nColors);
        end

        % ── 2D fast-path ──────────────────────────────────────────────────
        is2D = is2DDataset(activeDs);
        h2D  = appData.map2DHandle;
        fast2D = is2D && ~isempty(h2D) && isvalid(h2D) ...
                 && strcmp(ctx.ddMap2DType, 'Heatmap') ...
                 && numel(targetAx.YAxis) <= 1;
        if fast2D
            ctx.draw2DMap(targetAx, activeDs);
            return;
        end

        % ── Draw ──────────────────────────────────────────────────────────
        delete(findall(targetAx, 'Tag', 'GUIPeakAnnotation'));
        delete(findall(targetAx, 'Tag', 'GUISNIPBackground'));
        delete(findall(targetAx, 'Tag', 'GUIZoomBox'));
        delete(findall(targetAx, 'Tag', 'GUIRefLine'));
        delete(findall(targetAx, 'Tag', 'GUIMaskedPoints'));
        delete(findall(targetAx, 'Tag', 'GUIMaskBox'));
        delete(findall(targetAx, 'Tag', 'GUIFringeMarker'));
        delete(findall(targetAx, 'Tag', 'GUIFringeAnnotation'));
        delete(findall(targetAx, 'Tag', 'GUIFringeSpan'));
        delete(findall(targetAx, 'Tag', 'GUIPhaseTickMark'));
        delete(findall(targetAx, 'Tag', 'GUIPhaseLabel'));
        delete(findall(targetAx, 'Tag', 'GUISmoothPreview'));
        appData.smoothPreviewLine = [];
        delete(targetAx.Children);
        cla(targetAx);
        appData.map2DHandle = [];
        targetAx.XLim = [0 1];  targetAx.YLim = [0 1];
        targetAx.XLimMode = 'auto';
        targetAx.YLimMode = 'auto';

        if numel(targetAx.YAxis) > 1
            yyaxis(targetAx, 'right');
            cla(targetAx);
            targetAx.YLim = [0 1];
            targetAx.YLimMode = 'auto';
            targetAx.YScale   = 'linear';
            ylabel(targetAx, '');
            yyaxis(targetAx, 'left');
        end

        % ── 2D area-detector map branch (full redraw) ─────────────────────
        if is2D
            ctx.draw2DMap(targetAx, activeDs);
            return;
        end

        hold(targetAx,'on');
        if hasY2
            yyaxis(targetAx,'right'); hold(targetAx,'on');
            yyaxis(targetAx,'left');
        end
        lsPrimary    = guiLineSpec(ctx.style);
        lsRight      = guiLineSpec_right(ctx.style);
        lsRaw        = guiLineSpec_raw(ctx.style);
        anyRawShown  = false;

        % ── Waterfall offset ──────────────────────────────────────────────
        waterfallOn      = ctx.waterfallOn;
        effectiveSpacing = ctx.effectiveSpacing;
        wfLogMode        = waterfallOn && strcmp(ctx.scaleY, 'Log');

        % For neutron data, group polarization cross-sections...
        wfGroupIdx = (1:nDS)';
        if waterfallOn && nDS > 1
            anyNeutron = false;
            baseNames = cell(nDS, 1);
            for gi = 1:nDS
                gds = appData.datasets{plotIdx(gi)};
                if isfield(gds, 'parserName') && isNeutronParser(gds.parserName)
                    anyNeutron = true;
                    baseNames{gi} = neutronBaseName(gds.filepath);
                else
                    baseNames{gi} = sprintf('__unique_%d__', gi);
                end
            end
            if anyNeutron
                [~, ~, wfGroupIdx] = unique(baseNames, 'stable');
            end
        end

        % SIMS waterfall
        wfSIMSByChannel = false;
        if waterfallOn
            anySIMS = false;
            for gi = 1:nDS
                gds = appData.datasets{plotIdx(gi)};
                if isfield(gds,'parserName') && strcmp(gds.parserName,'importSIMS')
                    anySIMS = true; break;
                end
            end
            if anySIMS && nDS == 1
                wfSIMSByChannel = true;
            end
        end

        for si = 1:nDS
            di          = plotIdx(si);
            ds          = appData.datasets{di};
            if isfield(ds, 'visible') && ~ds.visible, continue; end
            if isfield(ds, 'hiddenForAsymmetry') && ds.hiddenForAsymmetry, continue; end

            d           = ds.data;
            hasCorrData = ~isempty(ds.corrData);
            showRawOver = hasCorrData && ctx.showRaw;
            primaryD    = guiTernary(hasCorrData, ds.corrData, d);

            % ── Build display mask ───────────────────────────────────────
            if isfield(ds, 'mask') && ~isempty(ds.mask) && any(~ds.mask)
                if hasCorrData
                    nRaw    = numel(d.time);
                    rawMask = ds.mask;
                    keepM   = true(nRaw, 1);
                    if ~isdatetime(d.time)
                        tVM = double(d.time);
                        if isfield(ds,'xTrimMin') && ~isnan(ds.xTrimMin)
                            keepM = keepM & tVM >= ds.xTrimMin;
                        end
                        if isfield(ds,'xTrimMax') && ~isnan(ds.xTrimMax)
                            keepM = keepM & tVM <= ds.xTrimMax;
                        end
                    end
                    displayMask = rawMask(keepM);
                else
                    displayMask = ds.mask;
                end
            else
                displayMask = true(size(primaryD.time));
            end

            % ── X vector for this dataset ─────────────────────────────────
            if strcmp(xSel, xName)
                xVecRaw     = d.time;
                xVecPrimary = primaryD.time;
            else
                idx2 = find(strcmp(d.labels, xSel), 1);
                if isempty(idx2)
                    xVecRaw     = d.time;
                    xVecPrimary = primaryD.time;
                else
                    xVecRaw     = d.values(:, idx2);
                    xVecPrimary = primaryD.values(:, idx2);
                end
            end

            if nDS > 1
                [~, fn, fext] = fileparts(ds.filepath);
                fileSuffix = sprintf('  [%s%s]', fn, fext);
            else
                fileSuffix = '';
            end

            ctFactor = 0;
            if ctx.countsPerSec
                ctFactor = guiCountingTime(ds);
            end

            dsColorOverride  = [];
            if isfield(ds,'color')  && ~isempty(ds.color),  dsColorOverride  = ds.color;  end
            dsColorROverride = [];
            if isfield(ds,'colorR') && ~isempty(ds.colorR), dsColorROverride = ds.colorR; end

            isSIMSds = isfield(ds,'parserName') && strcmp(ds.parserName,'importSIMS');

            for k = 1:nY
                colorIdx  = (si-1)*nY + k;
                baseColor = guiTernary(~isempty(dsColorOverride), dsColorOverride, colors(colorIdx,:));

                idx = find(strcmp(d.labels, ySel{k}), 1);
                if isempty(idx), continue; end

                isNeutron  = isfield(ds,'parserName') && isNeutronParser(ds.parserName);
                isRChannel = strcmp(ySel{k}, 'R');

                if isNeutron && isRChannel && ctx.calculateAsymmetry
                    continue;
                end

                if isNeutron && isRChannel
                    % --- Neutron R channel: error bars + theory overlay ---
                    pol = '';
                    if isfield(d.metadata,'parserSpecific') && isfield(d.metadata.parserSpecific,'polarization')
                        pol = d.metadata.parserSpecific.polarization;
                    end
                    baseColor = neutronPolarizationColor(pol);
                    if isempty(pol), polLabel = 'R'; else, polLabel = ['R' pol]; end
                    if nDS > 1
                        [~, fn, ~] = fileparts(ds.filepath);
                        fn = regexprep(fn, '-refl$', '');
                        polLabel = [fn '  ' polLabel];
                    end
                    dispName = polLabel;

                    yR  = primaryD.values(:, idx);
                    idR = find(strcmp(primaryD.labels, 'dR'), 1);
                    if ~isempty(idR), dyR = primaryD.values(:, idR); else, dyR = zeros(size(yR)); end
                    if effectiveSpacing ~= 0
                        if wfLogMode, yR = yR * effectiveSpacing^(wfGroupIdx(si) - 1);
                        else, yR = yR + (wfGroupIdx(si) - 1) * effectiveSpacing; end
                    end
                    good = ~isnan(xVecPrimary) & ~isnan(yR) & displayMask;
                    xGood = xVecPrimary(good); yGood = yR(good); dyGood = dyR(good);

                    if any(good) && ~isempty(idR)
                        whiskerAlpha = 0.5;
                        whiskerColor = [baseColor(1)*whiskerAlpha+0.5, baseColor(2)*whiskerAlpha+0.5, baseColor(3)*whiskerAlpha+0.5];
                        nPts = length(xGood);
                        xWhiskers = zeros(1, nPts*3);
                        yWhiskers = zeros(1, nPts*3);
                        for ii = 1:nPts
                            wi = (ii-1)*3 + 1;
                            xWhiskers(wi:wi+1) = xGood(ii);
                            yWhiskers(wi) = yGood(ii) - dyGood(ii);
                            yWhiskers(wi+1) = yGood(ii) + dyGood(ii);
                            xWhiskers(wi+2) = NaN; yWhiskers(wi+2) = NaN;
                        end
                        plot(targetAx, xWhiskers, yWhiskers, '-', ...
                            'Color', whiskerColor, 'LineWidth', 1.2, 'HitTest', 'off', 'HandleVisibility', 'off');
                    end
                    plot(targetAx, xGood, yGood, 'o', ...
                        'Color', baseColor, 'MarkerSize', 4.5, 'LineWidth', 1.0, ...
                        'HitTest', 'off', 'DisplayName', dispName);

                    iTheory = find(strcmp(primaryD.labels, 'theory'), 1);
                    if isempty(iTheory), iTheory = find(strcmpi(primaryD.labels, 'Theory'), 1); end
                    if isempty(iTheory), iTheory = find(strcmpi(primaryD.labels, 'model'), 1); end
                    if ~isempty(iTheory)
                        yTheory = primaryD.values(:, iTheory);
                        if effectiveSpacing ~= 0
                            if wfLogMode, yTheory = yTheory * effectiveSpacing^(wfGroupIdx(si) - 1);
                            else, yTheory = yTheory + (wfGroupIdx(si) - 1) * effectiveSpacing; end
                        end
                        theoryColor = 0.55 * baseColor + 0.45 * [1 1 1];
                        goodT = ~isnan(xVecPrimary) & ~isnan(yTheory);
                        if any(goodT)
                            plot(targetAx, xVecPrimary(goodT), yTheory(goodT), '-', ...
                                'Color', theoryColor, 'LineWidth', 1.2, 'HitTest', 'off', ...
                                'DisplayName', [polLabel ' theory']);
                        end
                    end

                else
                    % --- Standard (non-neutron) path ---
                    if isSIMSds
                        baseLabel = [d.labels{idx}, fileSuffix];
                    else
                        baseLabel = [guiLabel(d.labels{idx}, d.units{idx}), fileSuffix];
                    end

                    if wfSIMSByChannel, wfOffset = k - 1;
                    else, wfOffset = wfGroupIdx(si) - 1; end

                    if showRawOver
                        anyRawShown = true;
                        yRaw     = d.values(:, idx);
                        if ctFactor > 0, yRaw = yRaw / ctFactor; end
                        if effectiveSpacing ~= 0
                            if wfLogMode, yRaw = yRaw * effectiveSpacing^wfOffset;
                            else, yRaw = yRaw + wfOffset * effectiveSpacing; end
                        end
                        rawColor = 0.5 * baseColor + 0.5 * [1 1 1];
                        rawMaskVec = guiTernary(isfield(ds,'mask') && ~isempty(ds.mask), ds.mask, true(size(xVecRaw)));
                        if isdatetime(xVecRaw), good = ~isnat(xVecRaw) & ~isnan(yRaw) & rawMaskVec;
                        else, good = ~isnan(xVecRaw) & ~isnan(yRaw) & rawMaskVec; end
                        plot(targetAx, xVecRaw(good), yRaw(good), lsRaw{:}, ...
                            'Color', rawColor, 'HitTest', 'off', 'DisplayName', [baseLabel, ' (raw)']);
                    end

                    yPrimary = primaryD.values(:, idx);
                    if ctFactor > 0, yPrimary = yPrimary / ctFactor; end
                    if effectiveSpacing ~= 0
                        if wfLogMode, yPrimary = yPrimary * effectiveSpacing^wfOffset;
                        else, yPrimary = yPrimary + wfOffset * effectiveSpacing; end
                    end
                    if isdatetime(xVecPrimary), good = ~isnan(double(xVecPrimary)) & ~isnan(yPrimary) & displayMask;
                    else, good = ~isnan(xVecPrimary) & ~isnan(yPrimary) & displayMask; end
                    dispName = guiTernary(hasCorrData, [baseLabel, ' (corr)'], baseLabel);
                    if isfield(ds,'legendName') && ~isempty(ds.legendName)
                        dispName = ds.legendName;
                    end

                    % Auto-detect error column
                    errIdx = findErrorColumn(primaryD.labels, ySel{k});
                    if ~isempty(errIdx)
                        yErr = primaryD.values(:, errIdx);
                        if ctFactor > 0, yErr = yErr / ctFactor; end
                        yErrGood = yErr(good);
                        if strcmp(ctx.style, 'ErrorBand')
                            xFill = [xVecPrimary(good); flipud(xVecPrimary(good))];
                            yFill = [yPrimary(good) + yErrGood; flipud(yPrimary(good) - yErrGood)];
                            fill(targetAx, xFill, yFill, baseColor, ...
                                'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
                                'HitTest', 'off', 'HandleVisibility', 'off');
                            plot(targetAx, xVecPrimary(good), yPrimary(good), lsPrimary{:}, ...
                                'Color', baseColor, 'HitTest', 'off', 'DisplayName', dispName);
                        else
                            errorbar(targetAx, xVecPrimary(good), yPrimary(good), yErrGood, ...
                                'Color', baseColor, 'LineWidth', 1.0, 'CapSize', 3, ...
                                'HitTest', 'off', 'DisplayName', dispName);
                        end
                    else
                        plot(targetAx, xVecPrimary(good), yPrimary(good), lsPrimary{:}, ...
                            'Color', baseColor, 'HitTest', 'off', 'DisplayName', dispName);
                    end
                end
            end

            % ── Show masked points ────────────────────────────────────────
            if any(~displayMask)
                for km = 1:nY
                    idxM = find(strcmp(primaryD.labels, ySel{km}), 1);
                    if isempty(idxM), continue; end
                    yM = primaryD.values(:, idxM);
                    if ctFactor > 0, yM = yM / ctFactor; end
                    masked = ~displayMask & ~isnan(double(xVecPrimary)) & ~isnan(yM);
                    if any(masked)
                        plot(targetAx, xVecPrimary(masked), yM(masked), '.', ...
                            'Color', [0.55 0.55 0.55], 'MarkerSize', 4, ...
                            'HitTest', 'off', 'HandleVisibility', 'off', 'Tag', 'GUIMaskedPoints');
                    end
                end
            end

            % ── Right-axis (Y2) channels ──────────────────────────────────
            if hasY2
                yyaxis(targetAx, 'right');
                for k2 = 1:nY2
                    colorIdx2  = nDS*nY + (si-1)*nY2 + k2;
                    baseColor2 = guiTernary(~isempty(dsColorROverride), dsColorROverride, colors(colorIdx2, :));
                    idx2 = find(strcmp(d.labels, y2Sel{k2}), 1);
                    if isempty(idx2), continue; end
                    if isSIMSds, baseLabel2 = [d.labels{idx2}, fileSuffix];
                    else, baseLabel2 = [guiLabel(d.labels{idx2}, d.units{idx2}), fileSuffix]; end
                    yY2 = primaryD.values(:, idx2);
                    if ctFactor > 0, yY2 = yY2 / ctFactor; end
                    if isdatetime(xVecPrimary), good2 = ~isnat(xVecPrimary) & ~isnan(yY2) & displayMask;
                    else, good2 = ~isnan(xVecPrimary) & ~isnan(yY2) & displayMask; end
                    dispName2 = [baseLabel2, '  [R]'];
                    if isfield(ds,'legendNameR') && ~isempty(ds.legendNameR)
                        dispName2 = ds.legendNameR;
                    end
                    plot(targetAx, xVecPrimary(good2), yY2(good2), lsRight{:}, ...
                        'Color', baseColor2, 'HitTest', 'off', 'DisplayName', dispName2);
                end
                yyaxis(targetAx, 'left');
            end
        end

        % ── Spin asymmetry calculation ────────────────────────────────────
        if ctx.calculateAsymmetry && isNeutronParser(ctx.resolvedCorrStyle())
            hold(targetAx, 'on');
            pairMap = ctx.findPolarizationPairs(appData.datasets);
            drawnPairs = [];
            for i = 1:numel(pairMap)
                if isempty(pairMap{i}), continue; end
                [idxPP, idxMM] = deal(pairMap{i}(1), pairMap{i}(2));
                pairKey = idxPP * 10000 + idxMM;
                if ismember(pairKey, drawnPairs), continue; end
                drawnPairs(end+1) = pairKey;
                dsPP = appData.datasets{idxPP};
                dsMM = appData.datasets{idxMM};
                dPP = dsPP.data; dMM = dsMM.data;
                primaryPP = guiTernary(~isempty(dsPP.corrData), dsPP.corrData, dPP);
                primaryMM = guiTernary(~isempty(dsMM.corrData), dsMM.corrData, dMM);
                idxRPP = find(strcmp(primaryPP.labels, 'R'), 1);
                idxRMM = find(strcmp(primaryMM.labels, 'R'), 1);
                if isempty(idxRPP) || isempty(idxRMM), continue; end
                idxdRPP = find(strcmp(primaryPP.labels, 'dR'), 1);
                idxdRMM = find(strcmp(primaryMM.labels, 'dR'), 1);
                RPP = primaryPP.values(:, idxRPP);
                RMM = primaryMM.values(:, idxRMM);
                dRPP = guiTernary(~isempty(idxdRPP), primaryPP.values(:, idxdRPP), zeros(size(RPP)));
                dRMM = guiTernary(~isempty(idxdRMM), primaryMM.values(:, idxdRMM), zeros(size(RMM)));
                formulaStr = ctx.asymFormula;
                if contains(formulaStr, 'Log'), formula = 'Log'; else, formula = 'Linear'; end
                xAsym = primaryPP.time;
                valid = ~isnan(RPP) & ~isnan(RMM) & RPP > 0 & RMM > 0;
                asymVal = NaN(size(RPP)); asymErr = NaN(size(RPP));
                if strcmp(formula, 'Linear')
                    sumR = RPP + RMM;
                    asymVal(valid) = (RPP(valid) - RMM(valid)) ./ sumR(valid);
                    dA_dRPP = 2 * RMM(valid) ./ (sumR(valid).^2);
                    dA_dRMM = -2 * RPP(valid) ./ (sumR(valid).^2);
                    asymErr(valid) = sqrt((dA_dRPP .* dRPP(valid)).^2 + (dA_dRMM .* dRMM(valid)).^2);
                else
                    asymVal(valid) = log(RPP(valid) ./ RMM(valid));
                    dA_dRPP = 1 ./ RPP(valid);
                    dA_dRMM = -1 ./ RMM(valid);
                    asymErr(valid) = sqrt((dA_dRPP .* dRPP(valid)).^2 + (dA_dRMM .* dRMM(valid)).^2);
                end
                good = ~isnan(xAsym) & ~isnan(asymVal);
                xGood = xAsym(good); yGood = asymVal(good); dyGood = asymErr(good);
                [~, fnPP, ~] = fileparts(dsPP.filepath);
                fnPP = regexprep(fnPP, '-refl$', '');
                asymLegend = sprintf('%s  Asymmetry', fnPP);
                asymColor = [0.4 0.4 0.4];
                whiskerColor = 0.5 * asymColor + 0.5 * [1 1 1];
                nPts = length(xGood);
                xWhiskers = zeros(1, nPts*3); yWhiskers = zeros(1, nPts*3);
                for ii = 1:nPts
                    wi = (ii-1)*3 + 1;
                    xWhiskers(wi:wi+1) = xGood(ii);
                    yWhiskers(wi) = yGood(ii) - dyGood(ii);
                    yWhiskers(wi+1) = yGood(ii) + dyGood(ii);
                    xWhiskers(wi+2) = NaN; yWhiskers(wi+2) = NaN;
                end
                plot(targetAx, xWhiskers, yWhiskers, '-', ...
                    'Color', whiskerColor, 'LineWidth', 1.0, 'HitTest', 'off', 'HandleVisibility', 'off');
                plot(targetAx, xGood, yGood, 'o', ...
                    'Color', asymColor, 'MarkerSize', 4.5, 'LineWidth', 1.0, ...
                    'HitTest', 'off', 'DisplayName', asymLegend);
                % Theoretical asymmetry overlay
                iThPP = find(strcmpi(primaryPP.labels, 'theory'), 1);
                if isempty(iThPP), iThPP = find(strcmpi(primaryPP.labels, 'model'), 1); end
                iThMM = find(strcmpi(primaryMM.labels, 'theory'), 1);
                if isempty(iThMM), iThMM = find(strcmpi(primaryMM.labels, 'model'), 1); end
                if ~isempty(iThPP) && ~isempty(iThMM)
                    thPP = primaryPP.values(:, iThPP); thMM = primaryMM.values(:, iThMM);
                    validTh = ~isnan(thPP) & ~isnan(thMM) & thPP > 0 & thMM > 0;
                    asymTheory = NaN(size(thPP));
                    if strcmp(formula, 'Linear')
                        sumTh = thPP + thMM;
                        asymTheory(validTh) = (thPP(validTh) - thMM(validTh)) ./ sumTh(validTh);
                    else
                        asymTheory(validTh) = log(thPP(validTh) ./ thMM(validTh));
                    end
                    goodTh = ~isnan(xAsym) & ~isnan(asymTheory);
                    if any(goodTh)
                        theoryColor = 0.55 * asymColor + 0.45 * [1 1 1];
                        plot(targetAx, xAsym(goodTh), asymTheory(goodTh), '-', ...
                            'Color', theoryColor, 'LineWidth', 1.2, 'HitTest', 'off', ...
                            'DisplayName', [asymLegend ' theory']);
                    end
                end
            end
        end

        hold(targetAx,'off');
        if hasY2
            yyaxis(targetAx, 'right');
            hold(targetAx, 'off');
            targetAx.YScale = guiTernary(strcmp(ctx.scaleY2, 'Log'), 'log', 'linear');
            if ~isempty(ctx.customY2Label)
                ylabel(targetAx, ctx.customY2Label);
            elseif nY2 == 1
                idx2r = find(strcmp(activeDs.data.labels, y2Sel{1}), 1);
                if ~isempty(idx2r)
                    ylabel(targetAx, guiLabel(activeDs.data.labels{idx2r}, activeDs.data.units{idx2r}));
                end
            end
            yyaxis(targetAx, 'left');
        end

        % Legend
        if ctx.showLegend && (nY > 1 || nDS > 1 || anyRawShown || hasY2)
            legend(targetAx,'Location','best','Interpreter','none');
        else
            legend(targetAx,'off');
        end

        % X label
        if ~isempty(ctx.customXLabel), xlabel(targetAx, ctx.customXLabel);
        else, xlabel(targetAx, xLabel); end

        % Y label
        isSIMSActive = isfield(activeDs,'parserName') && strcmp(activeDs.parserName,'importSIMS');
        if ~isempty(ctx.customYLabel)
            ylabel(targetAx, ctx.customYLabel);
        elseif ~isempty(magYLabel)
            ylabel(targetAx, magYLabel);
        elseif isSIMSActive
            simsUnit = '';
            for su = 1:numel(activeDs.data.units)
                if ~isempty(activeDs.data.units{su}), simsUnit = activeDs.data.units{su}; break; end
            end
            if isempty(simsUnit), ylabel(targetAx, 'Concentration');
            else, ylabel(targetAx, ['Concentration (' simsUnit ')']); end
        elseif waterfallOn
            ylabel(targetAx, 'Intensity (a.u.)');
        elseif nY == 1 && nDS == 1
            idx = find(strcmp(activeDs.data.labels, ySel{1}), 1);
            if ~isempty(idx)
                unitStr = activeDs.data.units{idx};
                if ctx.countsPerSec && guiCountingTime(activeDs) > 0
                    unitStr = 'counts/s';
                end
                ylabel(targetAx, guiLabel(activeDs.data.labels{idx}, unitStr));
            end
        else
            ylabel(targetAx,'');
        end

        if nDS == 1
            [~,fn,fext] = fileparts(activeDs.filepath);
            titleStr = [fn, fext];
            if ~isempty(activeDs.corrData), titleStr = [titleStr, '  [corrected]']; end
        else
            titleStr = sprintf('%d datasets selected  (active: [%d])', nDS, appData.activeIdx);
        end
        if ~isempty(ctx.customTitle)
            title(targetAx, ctx.customTitle, 'Interpreter','none');
        else
            title(targetAx, titleStr, 'Interpreter','none');
        end

        warnState = warning('off', 'MATLAB:Axes:NegativeDataInLogAxis');
        cleanupWarn = onCleanup(@() warning(warnState));
        targetAx.XScale = guiTernary(strcmp(ctx.scaleX, 'Log'),'log','linear');
        targetAx.YScale = guiTernary(strcmp(ctx.scaleY, 'Log'),'log','linear');
        grid(targetAx,'on');
        targetAx.FontSize       = 13;
        targetAx.Title.FontSize = 14;

        % ── Manual axis limits ────────────────────────────────────────────
        xMinV  = str2double(ctx.xMin);
        xMaxV  = str2double(ctx.xMax);
        xStepV = str2double(ctx.xStep);
        yMinV  = str2double(ctx.yMin);
        yMaxV  = str2double(ctx.yMax);
        yStepV = str2double(ctx.yStep);

        xLimsInvalid = ~isnan(xMinV) && ~isnan(xMaxV) && xMinV >= xMaxV;
        yLimsInvalid = ~isnan(yMinV) && ~isnan(yMaxV) && yMinV >= yMaxV;
        warnColor  = [0.45 0.10 0.10];
        clearColor = [0.17 0.17 0.17];
        ctx.efXMin.BackgroundColor = guiTernary(xLimsInvalid, warnColor, clearColor);
        ctx.efXMax.BackgroundColor = guiTernary(xLimsInvalid, warnColor, clearColor);
        ctx.efYMin.BackgroundColor = guiTernary(yLimsInvalid, warnColor, clearColor);
        ctx.efYMax.BackgroundColor = guiTernary(yLimsInvalid, warnColor, clearColor);

        if ~isnan(xMinV) && ~isnan(xMaxV) && xMinV < xMaxV
            targetAx.XLim = [xMinV, xMaxV];
        end
        if ~isnan(yMinV) && ~isnan(yMaxV) && yMinV < yMaxV
            targetAx.YLim = [yMinV, yMaxV];
        end
        if ~isnan(xStepV) && xStepV > 0
            xTk = targetAx.XLim(1) : xStepV : targetAx.XLim(2);
            if numel(xTk) >= 2 && numel(xTk) <= 500, targetAx.XTick = xTk; end
        end
        if ~isnan(yStepV) && yStepV > 0
            yTk = targetAx.YLim(1) : yStepV : targetAx.YLim(2);
            if numel(yTk) >= 2 && numel(yTk) <= 500, targetAx.YTick = yTk; end
        end

        % ── Right Y-axis (Y2) limits ──────────────────────────────────────
        if ctx.isMainAx
            ctx.axLimGL.RowHeight{3} = 22 * hasY2;
            ctx.toggleY2Appearance(hasY2);
        end
        if hasY2
            y2MinV  = str2double(ctx.y2Min);
            y2MaxV  = str2double(ctx.y2Max);
            y2StepV = str2double(ctx.y2Step);
            y2LimsInvalid = ~isnan(y2MinV) && ~isnan(y2MaxV) && y2MinV >= y2MaxV;
            ctx.efY2Min.BackgroundColor = guiTernary(y2LimsInvalid, warnColor, clearColor);
            ctx.efY2Max.BackgroundColor = guiTernary(y2LimsInvalid, warnColor, clearColor);
            yyaxis(targetAx, 'right');
            if ~isnan(y2MinV) && ~isnan(y2MaxV) && y2MinV < y2MaxV
                targetAx.YLim = [y2MinV, y2MaxV];
            end
            if ~isnan(y2StepV) && y2StepV > 0
                yTk2 = targetAx.YLim(1) : y2StepV : targetAx.YLim(2);
                if numel(yTk2) >= 2 && numel(yTk2) <= 500, targetAx.YTick = yTk2; end
            end
            yyaxis(targetAx, 'left');
        end

        % ── Tick-label notation ───────────────────────────────────────────
        xfmt = ctx.xFmt;
        if isempty(xfmt), xtickformat(targetAx, 'auto');
        else, xtickformat(targetAx, xfmt); end
        yfmt = ctx.yFmt;
        if strcmp(yfmt, '__exp0')
            ytickformat(targetAx, 'auto');
            try targetAx.YAxis(1).ExponentMode = 'manual'; targetAx.YAxis(1).Exponent = 0;
            catch, try targetAx.YRuler.Exponent = 0; catch, end; end
        elseif isempty(yfmt)
            ytickformat(targetAx, 'auto');
            try targetAx.YAxis(1).ExponentMode = 'auto'; catch, end
        else
            ytickformat(targetAx, yfmt);
            try targetAx.YAxis(1).ExponentMode = 'auto'; catch, end
        end
        if hasY2
            yyaxis(targetAx, 'right');
            y2fmt = ctx.y2Fmt;
            if strcmp(y2fmt, '__exp0')
                ytickformat(targetAx, 'auto');
                try targetAx.YAxis(2).ExponentMode = 'manual'; targetAx.YAxis(2).Exponent = 0; catch, end
            elseif isempty(y2fmt)
                ytickformat(targetAx, 'auto');
                try targetAx.YAxis(2).ExponentMode = 'auto'; catch, end
            else
                ytickformat(targetAx, y2fmt);
                try targetAx.YAxis(2).ExponentMode = 'auto'; catch, end
            end
            yyaxis(targetAx, 'left');
        end

        % ── Overlays ─────────────────────────────────────────────────────
        if waterfallOn && appData.activeIdx >= 1 && appData.activeIdx <= numel(wfGroupIdx)
            activeGroupIdx = wfGroupIdx(appData.activeIdx);
        else
            activeGroupIdx = 1;
        end
        if appData.activeIdx >= 1 && ~isempty(appData.datasets)
            bosonPlotter.drawOverlays(targetAx, appData.datasets{appData.activeIdx}, ...
                'ShowFitCurves',    appData.showFitCurves, ...
                'ShowSnipBg',       appData.showSnipBg, ...
                'FitCurveColor',    appData.fitCurveColor, ...
                'SelectedPeakIdx',  appData.selectedPeakIdx, ...
                'WaterfallOn',      waterfallOn, ...
                'WfLogMode',        wfLogMode, ...
                'EffectiveSpacing', effectiveSpacing, ...
                'ActiveGroupIdx',   activeGroupIdx);
        end

        % ── Cache line handles ────────────────────────────────────────────
        allLines = findobj(targetAx, 'Type', 'line');
        nDSTotal = numel(appData.datasets);
        appData.lineCache.left  = cell(nDSTotal, max(nY, 1));
        appData.lineCache.right = cell(nDSTotal, max(nY2, 1));
        appData.lineCache.valid = false;
        lineIdx = 1;
        for di = 1:nDSTotal
            ds = appData.datasets{di};
            if isfield(ds, 'visible') && ~ds.visible, continue; end
            if isfield(ds, 'hiddenForAsymmetry') && ds.hiddenForAsymmetry, continue; end
            for k = 1:nY
                if lineIdx <= numel(allLines)
                    appData.lineCache.left{di, k} = allLines(lineIdx);
                    lineIdx = lineIdx + 1;
                end
            end
        end
        if hasY2
            for di = 1:nDSTotal
                ds = appData.datasets{di};
                if isfield(ds, 'visible') && ~ds.visible, continue; end
                if isfield(ds, 'hiddenForAsymmetry') && ds.hiddenForAsymmetry, continue; end
                for k = 1:nY2
                    if lineIdx <= numel(allLines)
                        appData.lineCache.right{di, k} = allLines(lineIdx);
                        lineIdx = lineIdx + 1;
                    end
                end
            end
        end
        appData.lineCache.valid = true;

        % ── SI prefix scaling ─────────────────────────────────────────────
        ctx.applyAxisPrefix(targetAx, 'x', appData.axisPrefixX);
        ctx.applyAxisPrefix(targetAx, 'y', appData.axisPrefixY);

        % ── Fringe markers ────────────────────────────────────────────────
        if ctx.isMainAx && appData.fringeClickCount == 2 && all(~isnan(appData.fringeQ))
            ctx.recreateFringeMarkers();
        end

    catch ME
        fprintf(2, '\n[BosonPlotter] Plot error: %s\n', ME.message);
        for si = 1:numel(ME.stack)
            fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
        end
        ctx.logGUIError('Plot error', ME.message, ME);
        uialert(ctx.fig, ME.message, 'Plot error');
    end

end

% ════════════════════════════════════════════════════════════════════════════
% Local helper functions
% ════════════════════════════════════════════════════════════════════════════

function s = guiTernary(cond, a, b)
    if cond, s = a; else, s = b; end
end

function c = ensureCell(v)
    if ~iscell(v), c = {v}; else, c = v; end
end

function name = guiXName(meta)
    if isfield(meta, 'x_column_name') && ~isempty(meta.x_column_name)
        name = meta.x_column_name;
    else
        name = 'Time';
    end
end

function u = guiXUnit(meta)
    if isfield(meta, 'x_column_unit') && ~isempty(meta.x_column_unit)
        u = meta.x_column_unit;
    else
        u = '';
    end
end

function s = guiLabel(name, unit)
    if isempty(unit), s = name;
    else, s = sprintf('%s (%s)', name, unit); end
end

function ls = guiLineSpec(style)
    switch style
        case 'Scatter',   ls = {'o', 'MarkerSize', 4, 'LineWidth', 1};
        case 'ErrorBand', ls = {'-', 'LineWidth', 1.2};
        otherwise,        ls = {'-', 'LineWidth', 1.2};  % 'Line' default
    end
end

function ls = guiLineSpec_raw(style)
    switch style
        case 'Scatter', ls = {'x', 'MarkerSize', 3, 'LineWidth', 0.8};
        otherwise,      ls = {'--', 'LineWidth', 0.8};
    end
end

function ls = guiLineSpec_right(style)
    switch style
        case 'Scatter', ls = {'s', 'MarkerSize', 4, 'LineWidth', 1};
        otherwise,      ls = {'-.', 'LineWidth', 1.2};
    end
end

function tf = is2DDataset(ds)
    tf = isfield(ds, 'data') && isfield(ds.data, 'metadata') && ...
         isfield(ds.data.metadata, 'parserSpecific') && ...
         isfield(ds.data.metadata.parserSpecific, 'is2D') && ...
         ds.data.metadata.parserSpecific.is2D;
end

function tf = isNeutronParser(pName)
    tf = ismember(pName, {'importNCNRPNR', 'importNCNR', 'importRefl1D', 'importORSO'});
end

function baseName = neutronBaseName(filepath)
    [~, fn, ~] = fileparts(filepath);
    baseName = regexprep(fn, '[ABCD]$', '');
end

function col = neutronPolarizationColor(polarization)
    switch polarization
        case '++',    col = [0.12 0.47 0.71];
        case '--',    col = [0.89 0.10 0.11];
        case '+-',    col = [0.17 0.63 0.17];
        case '-+',    col = [1.00 0.50 0.05];
        otherwise,    col = [0.40 0.40 0.40];
    end
end

function ct = guiCountingTime(ds)
    ct = 0;
    d = ds.data;
    if ~isfield(d.metadata, 'parserSpecific'), return; end
    ps = d.metadata.parserSpecific;
    if isfield(ps, 'countingTime') && ps.countingTime > 0
        ct = ps.countingTime;
    elseif isfield(ps, 'measurementTime') && ps.measurementTime > 0
        ct = ps.measurementTime;
    end
end

function idx = findErrorColumn(labels, yLabel)
    idx = [];
    candidates = { ...
        ['d' yLabel], [yLabel ' err'], [yLabel ' Err'], ...
        'M. Std. Err.', [yLabel ' std'], [yLabel ' sigma'] };
    for ci = 1:numel(candidates)
        ii = find(strcmpi(labels, candidates{ci}), 1);
        if ~isempty(ii), idx = ii; return; end
    end
    for li = 1:numel(labels)
        lbl = lower(labels{li});
        if (contains(lbl, 'err') || contains(lbl, 'std')) && ~strcmpi(labels{li}, yLabel)
            idx = li; return;
        end
    end
end
