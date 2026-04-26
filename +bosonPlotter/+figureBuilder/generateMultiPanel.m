function outFig = generateMultiPanel(datasets, cfg, globalOpts)
%GENERATEMULTIPANEL  Build a multi-panel figure from a config struct.
%
%   outFig = bosonPlotter.figureBuilder.generateMultiPanel( ...
%       datasets, cfg, globalOpts)
%
%   Produces a multi-panel publication figure programmatically — the
%   scriptable equivalent of the Figure Builder dialog's "Multi-Panel"
%   path. The dialog's nested generateMultiPanel reads from widget
%   structs; this version takes config + globalOpts directly so the
%   path is testable and reusable from batch / notebook contexts.
%
%   Inputs
%     datasets   {1×N} cell of dataset structs (each with .data.time,
%                .data.values, .data.labels, .filepath)
%     cfg        struct from FigureBuilderModel.multiPanelConfig:
%                  .rows, .cols (panel grid)
%                  .shareX, .shareY (logical)
%                  .panels (struct array — one per tile, see
%                           FigureBuilderModel.defaultPanelSpec)
%     globalOpts struct from FigureBuilderModel.globalOpts:
%                  .figureWidth, .figureHeight (inches)
%                  .fontSize, .fontName
%                  .lineStyle ('Line' | 'Scatter' | 'Line+Pts')
%                  .grayscale (logical)
%
%   Output
%     outFig     figure handle (the produced multi-panel figure)
%
%   Note
%     Today this is a focused implementation: simple line/scatter
%     traces, no error bars/bands, no shared-axis linking beyond what
%     tiledlayout natively supports. The dialog's nested
%     generateMultiPanel includes broader features (reference-line
%     tools, linked cursors, error styling). Migrating those into
%     this package fn is follow-up work — flagged in
%     plans/workshop-conversion-plan.md.

    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end

    cfg = bosonPlotter.figureBuilder.FigureBuilderModel.normalizeMultiPanelConfig(cfg);
    nR = cfg.rows;
    nC = cfg.cols;
    nPanels = nR * nC;
    if numel(cfg.panels) < nPanels
        % Pad to required panel count
        defaults = bosonPlotter.figureBuilder.FigureBuilderModel.defaultPanelArray( ...
            nPanels - numel(cfg.panels));
        cfg.panels = [cfg.panels, defaults];
    end

    % ── Output figure ────────────────────────────────────────────────
    outFig = figure( ...
        'Units', 'inches', ...
        'Position', [1, 1, globalOpts.figureWidth, globalOpts.figureHeight], ...
        'Color', 'white', ...
        'PaperPositionMode', 'auto');

    if cfg.shareX
        tlo = tiledlayout(outFig, nR, nC, ...
            'TileSpacing','compact', 'Padding','compact');
    else
        tlo = tiledlayout(outFig, nR, nC, ...
            'TileSpacing','normal', 'Padding','normal');
    end

    % Plot style spec from globalOpts.lineStyle
    [lineSpec, useMarkers] = resolveLineStyle(globalOpts.lineStyle);

    % ── Iterate panels ───────────────────────────────────────────────
    occupied = false(nR, nC);
    axList = gobjects(0);
    for pi = 1:nPanels
        [r, c] = ind2sub([nR, nC], pi);
        if occupied(r, c), continue; end

        pSpec = cfg.panels(pi);
        rSpan = min(pSpec.rowSpan, nR - r + 1);
        cSpan = min(pSpec.colSpan, nC - c + 1);
        occupied(r:r+rSpan-1, c:c+cSpan-1) = true;

        tAx = nexttile(tlo, pi, [rSpan cSpan]);
        hold(tAx, 'on');
        tAx.Box = 'on';
        tAx.FontSize = globalOpts.fontSize;
        tAx.FontName = globalOpts.fontName;
        axList(end+1) = tAx; %#ok<AGROW>

        xLbl = '';  yLbl = '';
        ci = 0;
        for di = 1:numel(pSpec.datasets)
            dsIdx = pSpec.datasets(di);
            if dsIdx < 1 || dsIdx > numel(datasets), continue; end
            ds = datasets{dsIdx};
            xv = double(ds.data.time);
            for yi = 1:numel(pSpec.yChannels)
                yLabel = pSpec.yChannels{yi};
                yIdx = find(strcmp(ds.data.labels, yLabel), 1);
                if isempty(yIdx), continue; end
                yv = ds.data.values(:, yIdx);
                ci = ci + 1;
                col = pickColor(ci, globalOpts.grayscale);
                plot(tAx, xv, yv, lineSpec, ...
                    'Color', col, 'LineWidth', 1.0, ...
                    'MarkerSize', 4, ...
                    'DisplayName', sprintf('%d: %s', dsIdx, yLabel));
                if useMarkers && ~contains(lineSpec, 'o')
                    plot(tAx, xv, yv, 'o', 'Color', col, ...
                        'MarkerSize', 3, 'HandleVisibility', 'off');
                end
                if isempty(yLbl), yLbl = yLabel; end
            end
        end

        if isempty(xLbl)
            % Try to get an X label from the first dataset's metadata
            if ~isempty(pSpec.datasets) && pSpec.datasets(1) <= numel(datasets)
                d0 = datasets{pSpec.datasets(1)}.data;
                if isfield(d0.metadata, 'x_column_name')
                    xLbl = d0.metadata.x_column_name;
                end
            end
        end

        % ── Right Y axis (Y2) — channels listed in pSpec.y2Channels ─
        hasY2 = isfield(pSpec, 'y2Channels') && ~isempty(pSpec.y2Channels);
        if hasY2
            yyaxis(tAx, 'right'); hold(tAx, 'on');
            y2Lbl = '';
            for di = 1:numel(pSpec.datasets)
                dsIdx = pSpec.datasets(di);
                if dsIdx < 1 || dsIdx > numel(datasets), continue; end
                ds = datasets{dsIdx};
                xv = double(ds.data.time);
                for yi = 1:numel(pSpec.y2Channels)
                    yLabel = pSpec.y2Channels{yi};
                    yIdx = find(strcmp(ds.data.labels, yLabel), 1);
                    if isempty(yIdx), continue; end
                    yv = ds.data.values(:, yIdx);
                    ci = ci + 1;
                    col = pickColor(ci, globalOpts.grayscale);
                    plot(tAx, xv, yv, lineSpec, ...
                        'Color', col, 'LineWidth', 1.0, 'MarkerSize', 4, ...
                        'DisplayName', sprintf('%d: %s (y2)', dsIdx, yLabel));
                    if isempty(y2Lbl), y2Lbl = yLabel; end
                end
            end
            ylabel(tAx, y2Lbl, 'FontSize', globalOpts.fontSize);
            yyaxis(tAx, 'left');
        end

        if pSpec.logY
            tAx.YScale = 'log';
        end

        % Suppress X label on non-bottom rows when shareX is true
        if cfg.shareX && (r + rSpan - 1) < nR
            xlabel(tAx, '');
        else
            xlabel(tAx, xLbl, 'FontSize', globalOpts.fontSize);
        end
        ylabel(tAx, yLbl, 'FontSize', globalOpts.fontSize);

        if ~isempty(pSpec.title)
            title(tAx, pSpec.title, ...
                'FontSize', globalOpts.fontSize+1, 'Interpreter', 'none');
        end
        if ci > 1 || hasY2
            legend(tAx, 'Interpreter','none', ...
                'FontSize', max(globalOpts.fontSize-2, 6), 'Location','best');
        end
        hold(tAx, 'off');
    end

    % Axis linking
    if numel(axList) >= 2
        if cfg.shareX && cfg.shareY
            linkaxes(axList, 'xy');
        elseif cfg.shareX
            linkaxes(axList, 'x');
        elseif cfg.shareY
            linkaxes(axList, 'y');
        end
    end
end

% ────────────────────────────────────────────────────────────────────
%  Local helpers
% ────────────────────────────────────────────────────────────────────

function [spec, useMarkers] = resolveLineStyle(styleName)
    switch styleName
        case 'Scatter'
            spec       = '.';
            useMarkers = true;
        case 'Line+Pts'
            spec       = '-o';
            useMarkers = false;
        otherwise % 'Line'
            spec       = '-';
            useMarkers = false;
    end
end

function col = pickColor(idx, grayscale)
    if grayscale
        % Gray ramp: distinguishable shades
        levels = linspace(0.15, 0.7, 8);
        v = levels(mod(idx-1, numel(levels)) + 1);
        col = [v v v];
    else
        % MATLAB default colour order (lines)
        c = lines(8);
        col = c(mod(idx-1, 8) + 1, :);
    end
end
