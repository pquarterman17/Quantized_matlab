function drawOverlays(targetAx, ds, options)
%DRAWOVERLAYS  Render peak markers, fit curves, annotations, and reference lines.
%   bosonPlotter.drawOverlays(targetAx, ds, Name=Value)
%
%   Renders overlay graphics on top of the plotted data: fitted peak curves,
%   vertical peak markers with FWHM bars, SNIP background, user annotations,
%   and reference lines.  All overlays use HandleVisibility='off' and carry
%   identifying Tags for easy deletion before the next redraw.
%
%   Inputs
%   ------
%   targetAx   Axes handle to render into
%   ds         Dataset struct (must have .peaks, .snipBackground, .annotations, .refLines)
%
%   Name-Value Options
%   ------------------
%   ShowFitCurves   logical   Render Lorentzian/Gaussian/PV fit curves (default: true)
%   ShowSnipBg      logical   Render SNIP background curve (default: false)
%   FitCurveColor   [R G B]  Color for fit curves (default: [0.9 0.2 0.2])
%   SelectedPeakIdx double    0-based index of selected peak for highlight (default: 0)
%   WaterfallOn     logical   Apply waterfall Y-offset to overlays (default: false)
%   WfLogMode       logical   Multiplicative waterfall (true) or additive (false)
%   EffectiveSpacing double   Waterfall spacing value
%   ActiveGroupIdx  double    Group index for the active dataset in waterfall mode

arguments
    targetAx
    ds          struct
    options.ShowFitCurves    logical = true
    options.ShowSnipBg       logical = false
    options.FitCurveColor    (1,3) double = [0.9 0.2 0.2]
    options.SelectedPeakIdx  double = 0
    options.WaterfallOn      logical = false
    options.WfLogMode        logical = false
    options.EffectiveSpacing double = 0
    options.ActiveGroupIdx   double = 1
end

wfOn    = options.WaterfallOn;
wfLog   = options.WfLogMode;
wfSpace = options.EffectiveSpacing;
grpIdx  = options.ActiveGroupIdx;

if wfLog
    pkYMult = wfSpace^(grpIdx - 1);
    pkYOff  = 0;
else
    pkYMult = 1;
    pkYOff  = (grpIdx - 1) * wfSpace;
end

% ════════════════════════════════════════════════════════════════════════
%  1. Peak annotations (fit curves + vertical markers + FWHM bars)
% ════════════════════════════════════════════════════════════════════════
if ~isempty(ds.peaks)
    hold(targetAx, 'on');
    yLo   = targetAx.YLim(1);
    yHi   = targetAx.YLim(2);
    ySpan = yHi - yLo;
    fitColor = options.FitCurveColor;

    % ── (1a) Fit curve overlays ────────────────────────────────────
    if options.ShowFitCurves
        for pki = 1:numel(ds.peaks)
            pk       = ds.peaks(pki);
            hasBg    = isfield(pk,'bg') && ~isempty(pk.bg) && ~isnan(pk.bg);
            isFitted = strcmp(pk.status,'fitted') && ~isnan(pk.fwhm) && pk.fwhm > 0;
            if ~isFitted || ~hasBg, continue; end

            if ~isempty(pk.xRange) && numel(pk.xRange) == 2
                gxLo = pk.xRange(1);  gxHi = pk.xRange(2);
            else
                gxLo = pk.center - 3*pk.fwhm;
                gxHi = pk.center + 3*pk.fwhm;
            end
            xFitPlot = linspace(gxLo, gxHi, 300);
            pkModel  = '';
            if isfield(pk,'model'), pkModel = pk.model; end
            u = (xFitPlot - pk.center) ./ pk.fwhm;
            if strcmp(pkModel, 'Gaussian')
                yFitPlot = pk.height .* exp(-4.*log(2).*u.^2) + pk.bg;
            elseif strcmp(pkModel, 'Pseudo-Voigt')
                eta = 0.5;
                if isfield(pk,'eta') && ~isempty(pk.eta) && ~isnan(pk.eta)
                    eta = pk.eta;
                end
                L = 1 ./ (1 + 4.*u.^2);
                G = exp(-4.*log(2).*u.^2);
                yFitPlot = pk.height .* (eta.*L + (1-eta).*G) + pk.bg;
            elseif strcmp(pkModel, 'Split Pearson VII') && isfield(pk,'fitParams') && numel(pk.fitParams) == 7
                yFitPlot = utilities.splitPearsonVII(xFitPlot(:), pk.fitParams)';
            else  % Lorentzian (default)
                yFitPlot = pk.height ./ (1 + 4.*u.^2) + pk.bg;
            end
            if wfLog
                yFitPlot = yFitPlot * pkYMult;
            else
                yFitPlot = yFitPlot + pkYOff;
            end

            isSel = (pki == options.SelectedPeakIdx);
            lw = 1.5;  if isSel, lw = 2.5; end
            plot(targetAx, xFitPlot, yFitPlot, '-', ...
                'Color',            fitColor, ...
                'LineWidth',        lw, ...
                'HitTest',          'off', ...
                'Tag',              'GUIPeakAnnotation', ...
                'HandleVisibility', 'off');
        end
    end

    % ── (1b) Vertical markers, labels and FWHM bars ────────────────
    for pki = 1:numel(ds.peaks)
        pk    = ds.peaks(pki);
        isSel = (pki == options.SelectedPeakIdx);
        if isSel
            lineColor = [1.0 0.50 0.00];
            lineWidth = 2.5;
        else
            lineColor = [0.55 0.15 0.75];
            lineWidth = 1.5;
        end

        % Vertical dashed line spanning full y-axis
        plot(targetAx, [pk.center, pk.center], [yLo, yHi], '--', ...
            'Color',            lineColor, ...
            'LineWidth',        lineWidth, ...
            'HitTest',          'off', ...
            'Tag',              'GUIPeakAnnotation', ...
            'HandleVisibility', 'off');

        % Peak label near the bottom
        if wfLog && yLo > 0 && yHi > 0
            pkLabelY = exp(log(yLo) + (log(yHi)-log(yLo))*0.03) * pkYMult;
        else
            pkLabelY = yLo + ySpan*0.03 + pkYOff;
        end
        text(targetAx, pk.center, pkLabelY, ...
            sprintf('#%d  %.3f\xb0', pki, pk.center), ...
            'FontSize',           7, ...
            'HorizontalAlignment','center', ...
            'Color',              lineColor, ...
            'Tag',                'GUIPeakAnnotation', ...
            'HandleVisibility',   'off', ...
            'Interpreter',        'none');

        % FWHM horizontal bar at half-maximum
        if ~isnan(pk.fwhm) && pk.fwhm > 0
            hasBg = isfield(pk,'bg') && ~isempty(pk.bg) && ~isnan(pk.bg);
            if hasBg
                halfHBase = pk.bg + pk.height*0.5;
            else
                halfHBase = pk.height*0.5;
            end
            if wfLog
                halfH = halfHBase * pkYMult;
            else
                halfH = halfHBase + pkYOff;
            end
            plot(targetAx, ...
                [pk.center - pk.fwhm/2, pk.center + pk.fwhm/2], ...
                [halfH, halfH], '-', ...
                'Color',            lineColor, ...
                'LineWidth',        2.0, ...
                'HitTest',          'off', ...
                'Tag',              'GUIPeakAnnotation', ...
                'HandleVisibility', 'off');
        end
    end
    hold(targetAx, 'off');
end

% ════════════════════════════════════════════════════════════════════════
%  2. SNIP background overlay
% ════════════════════════════════════════════════════════════════════════
if options.ShowSnipBg && isfield(ds, 'snipBackground') && ...
   ~isempty(ds.snipBackground) && ~isempty(ds.snipBackground.x)
    if wfLog
        snipBgY = ds.snipBackground.bg * wfSpace^(grpIdx - 1);
    else
        snipBgY = ds.snipBackground.bg + (grpIdx - 1) * wfSpace;
    end
    hold(targetAx, 'on');
    plot(targetAx, ds.snipBackground.x, snipBgY, '--', ...
        'Color',            [0.2 0.8 0.2], ...
        'LineWidth',        1.5, ...
        'HitTest',          'off', ...
        'Tag',              'GUISNIPBackground', ...
        'HandleVisibility', 'off');
    hold(targetAx, 'off');
end

% ════════════════════════════════════════════════════════════════════════
%  3. User annotations
% ════════════════════════════════════════════════════════════════════════
if isfield(ds, 'annotations') && ~isempty(ds.annotations)
    hold(targetAx, 'on');
    for ai = 1:numel(ds.annotations)
        annot = ds.annotations{ai};
        if wfLog
            yPos = annot.y * wfSpace^(grpIdx - 1);
        else
            yPos = annot.y + (grpIdx - 1) * wfSpace;
        end
        text(targetAx, annot.x, yPos, annot.text, ...
            'FontSize',         10, ...
            'FontWeight',       'normal', ...
            'Color',            [0.2 0.2 0.2], ...
            'BackgroundColor',  [1.0 0.95 0.85], ...
            'EdgeColor',        [0.7 0.7 0.7], ...
            'LineWidth',        0.5, ...
            'HitTest',          'off', ...
            'Tag',              'GUIUserAnnotation', ...
            'HandleVisibility', 'off');
    end
    hold(targetAx, 'off');
end

% ════════════════════════════════════════════════════════════════════════
%  4. Reference lines
% ════════════════════════════════════════════════════════════════════════
if isfield(ds, 'refLines') && ~isempty(ds.refLines)
    hold(targetAx, 'on');
    for ri = 1:numel(ds.refLines)
        rl = ds.refLines{ri};
        if strcmp(rl.orientation, 'horizontal')
            yline(targetAx, rl.value, rl.style, ...
                'Color', rl.color, 'LineWidth', 1.2, ...
                'HitTest', 'off', 'HandleVisibility', 'off', ...
                'Tag', 'GUIRefLine');
        else
            xline(targetAx, rl.value, rl.style, ...
                'Color', rl.color, 'LineWidth', 1.2, ...
                'HitTest', 'off', 'HandleVisibility', 'off', ...
                'Tag', 'GUIRefLine');
        end
    end
    hold(targetAx, 'off');
end

end
