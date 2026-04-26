function outFig = generateBrokenAxis(datasets, cfg, globalOpts)
%GENERATEBROKENAXIS  Two-panel plot with a discontinuity in X or Y.
%
%   cfg fields:
%     .datasets    [1xN] dataset indices to overlay (single supported in
%                  practice; first is used)
%     .yChannel    Y channel name
%     .breakAxis   'X' (default) | 'Y' — which axis to split
%     .gapLow      lower bound of the gap (data values inside (lo, hi)
%                  are excluded from rendering)
%     .gapHigh     upper bound of the gap
%     .logY        logical (default false)
%     .ratio       'Proportional' (default) | '1:1' | '2:1' | '1:2'
%     .leftRange   [xMin xBreakLow]   (legacy — used if breakAxis='X' and
%                  gapLow/gapHigh both unset; auto-derived from data otherwise)
%     .rightRange  [xBreakHigh xMax]
    arguments
        datasets   cell
        cfg        struct
        globalOpts struct
    end
    if ~isfield(cfg,'datasets')   || isempty(cfg.datasets), cfg.datasets = 1:min(1, numel(datasets)); end
    if ~isfield(cfg,'yChannel')   || isempty(cfg.yChannel), cfg.yChannel = datasets{cfg.datasets(1)}.data.labels{1}; end
    if ~isfield(cfg,'breakAxis'), cfg.breakAxis = 'X'; end
    if ~isfield(cfg,'logY'),      cfg.logY      = false; end
    if ~isfield(cfg,'ratio'),     cfg.ratio     = 'Proportional'; end

    % Single-dataset path: we plot the first dataset
    di = cfg.datasets(1);
    [xv, yv, xLbl, yLbl] = bosonPlotter.figureBuilder.extractXY(datasets{di}, cfg.yChannel);
    if isempty(xv)
        outFig = bosonPlotter.figureBuilder.createOutFig('Broken Axis', globalOpts);
        return;
    end

    % Auto-derive gap if not set: use legacy {leftRange,rightRange} or
    % default to ±5% around the median for X-break.
    if ~isfield(cfg,'gapLow') || ~isfield(cfg,'gapHigh') || ...
            isempty(cfg.gapLow) || isempty(cfg.gapHigh)
        if isfield(cfg,'leftRange') && isfield(cfg,'rightRange') && ...
                ~isempty(cfg.leftRange) && ~isempty(cfg.rightRange)
            cfg.gapLow  = cfg.leftRange(2);
            cfg.gapHigh = cfg.rightRange(1);
        else
            xMid = median(xv);
            xSpan = max(xv) - min(xv);
            cfg.gapLow  = xMid - 0.025 * xSpan;
            cfg.gapHigh = xMid + 0.025 * xSpan;
        end
    end
    gapLo = cfg.gapLow; gapHi = cfg.gapHigh;
    if gapLo >= gapHi
        error('BrokenAxis:badGap','gapLow must be < gapHigh');
    end

    outFig = bosonPlotter.figureBuilder.createOutFig('Broken Axis', globalOpts);

    if strcmpi(cfg.breakAxis, 'Y')
        % ── Y-axis break ─────────────────────────────────────────
        bottomMask = yv < gapLo;
        topMask    = yv > gapHi;
        if ~any(bottomMask) || ~any(topMask)
            error('BrokenAxis:emptyGap','Gap range leaves no data on one side');
        end
        if strcmpi(cfg.ratio, 'Proportional')
            rangeB = gapLo - min(yv(bottomMask));
            rangeT = max(yv(topMask)) - gapHi;
            hRatio = [rangeB rangeT];
        else
            hRatio = parseRatio(cfg.ratio);
        end
        hFrac = hRatio / sum(hRatio);
        gap = 0.03;
        bot_h = (1 - gap) * hFrac(1) * 0.72;
        top_h = (1 - gap) * hFrac(2) * 0.72;
        bot_y = 0.14;  top_y = bot_y + bot_h + gap;
        ax1 = axes(outFig, 'Position', [0.14 bot_y 0.78 bot_h]);
        ax2 = axes(outFig, 'Position', [0.14 top_y 0.78 top_h]);
        for ax_ = [ax1 ax2]
            hold(ax_,'on'); ax_.Box = 'on'; grid(ax_,'on');
            ax_.FontSize = globalOpts.fontSize; ax_.FontName = globalOpts.fontName;
            plot(ax_, xv, yv, '-', 'Color', [0.12 0.47 0.71], 'LineWidth', 1.0);
        end
        ax1.YLim = [min(yv(bottomMask)) * 0.95, gapLo];
        ax2.YLim = [gapHi, max(yv(topMask)) * 1.05];
        ax2.XTickLabel = {};
        linkaxes([ax1 ax2], 'x');
        if cfg.logY, ax1.YScale = 'log'; ax2.YScale = 'log'; end
        xlabel(ax1, xLbl); ylabel(ax1, yLbl);
        drawBreakMarksHere(ax1, 'top');
        drawBreakMarksHere(ax2, 'bottom');
    else
        % ── X-axis break ──────────────────────────────────────────
        leftMask  = xv < gapLo;
        rightMask = xv > gapHi;
        if ~any(leftMask) || ~any(rightMask)
            error('BrokenAxis:emptyGap','Gap range leaves no data on one side');
        end
        xLeft = xv(leftMask);  yLeft = yv(leftMask);
        xRight = xv(rightMask); yRight = yv(rightMask);
        if strcmpi(cfg.ratio, 'Proportional')
            wRatio = [max(xLeft)-min(xLeft), max(xRight)-min(xRight)];
        else
            wRatio = parseRatio(cfg.ratio);
        end
        wFrac = wRatio / sum(wRatio);
        gap = 0.03;
        left_w  = (1 - gap) * wFrac(1) * 0.75;
        right_w = (1 - gap) * wFrac(2) * 0.75;
        left_x  = 0.12;  right_x = left_x + left_w + gap;
        ax1 = axes(outFig, 'Position', [left_x  0.15 left_w  0.75]);
        ax2 = axes(outFig, 'Position', [right_x 0.15 right_w 0.75]);
        hold(ax1,'on'); ax1.Box = 'on'; grid(ax1,'on');
        ax1.FontSize = globalOpts.fontSize; ax1.FontName = globalOpts.fontName;
        plot(ax1, xLeft, yLeft, '-', 'Color', [0.12 0.47 0.71], 'LineWidth', 1.0);
        ax1.XLim = [min(xLeft) max(xLeft)];
        hold(ax2,'on'); ax2.Box = 'on'; grid(ax2,'on');
        ax2.FontSize = globalOpts.fontSize; ax2.FontName = globalOpts.fontName;
        plot(ax2, xRight, yRight, '-', 'Color', [0.12 0.47 0.71], 'LineWidth', 1.0);
        ax2.XLim = [min(xRight) max(xRight)];
        ax2.YTickLabel = {};
        linkaxes([ax1 ax2], 'y');
        if cfg.logY, ax1.YScale = 'log'; ax2.YScale = 'log'; end
        xlabel(ax1, xLbl); ylabel(ax1, yLbl);
        drawBreakMarksHere(ax1, 'right');
        drawBreakMarksHere(ax2, 'left');
    end
end

% ── Local helpers ────────────────────────────────────────────────────

function r = parseRatio(s)
    switch s
        case '1:1', r = [1 1];
        case '2:1', r = [2 1];
        case '1:2', r = [1 2];
        otherwise,  r = [1 1];
    end
end

function drawBreakMarksHere(ax, edge)
%DRAWBREAKMARKSHERE  Draw zigzag break marks on the named edge of ax.
%   edge: 'top' | 'bottom' | 'left' | 'right'
    yL = ax.YLim;  xL = ax.XLim;
    sz = 0.02;
    switch edge
        case 'top'
            yPos = yL(2);
            zigX = [xL(1)+0.05*(xL(2)-xL(1)), xL(1)+0.10*(xL(2)-xL(1)), ...
                    xL(1)+0.15*(xL(2)-xL(1)), xL(1)+0.20*(xL(2)-xL(1))];
            zigY = [yPos, yPos + sz*(yL(2)-yL(1)), yPos - sz*(yL(2)-yL(1)), yPos];
            line(ax, zigX, zigY, 'Color','k', 'LineWidth', 1, 'Clipping','off');
        case 'bottom'
            yPos = yL(1);
            zigX = [xL(1)+0.05*(xL(2)-xL(1)), xL(1)+0.10*(xL(2)-xL(1)), ...
                    xL(1)+0.15*(xL(2)-xL(1)), xL(1)+0.20*(xL(2)-xL(1))];
            zigY = [yPos, yPos + sz*(yL(2)-yL(1)), yPos - sz*(yL(2)-yL(1)), yPos];
            line(ax, zigX, zigY, 'Color','k', 'LineWidth', 1, 'Clipping','off');
        case 'right'
            xPos = xL(2);
            zigY = [yL(1)+0.05*(yL(2)-yL(1)), yL(1)+0.10*(yL(2)-yL(1)), ...
                    yL(1)+0.15*(yL(2)-yL(1)), yL(1)+0.20*(yL(2)-yL(1))];
            zigX = [xPos, xPos + sz*(xL(2)-xL(1)), xPos - sz*(xL(2)-xL(1)), xPos];
            line(ax, zigX, zigY, 'Color','k', 'LineWidth', 1, 'Clipping','off');
        case 'left'
            xPos = xL(1);
            zigY = [yL(1)+0.05*(yL(2)-yL(1)), yL(1)+0.10*(yL(2)-yL(1)), ...
                    yL(1)+0.15*(yL(2)-yL(1)), yL(1)+0.20*(yL(2)-yL(1))];
            zigX = [xPos, xPos + sz*(xL(2)-xL(1)), xPos - sz*(xL(2)-xL(1)), xPos];
            line(ax, zigX, zigY, 'Color','k', 'LineWidth', 1, 'Clipping','off');
    end
end
