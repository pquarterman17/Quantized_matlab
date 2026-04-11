function applyPostRenderStyle(targetAx, appearance)
%APPLYPOSTRENDERSTYLE  Post-draw style pass for BosonPlotter axes.
%
%   bosonPlotter.applyPostRenderStyle(ax, appearance)
%
%   Applied AFTER all plot/errorbar/line calls have finished drawing the
%   data series.  Handles style fields that are cheaper to fix up in a
%   single pass over the rendered children than to plumb through every
%   plot() call site in renderPlot.m:
%
%       • alpha            — line/marker transparency via RGBA Color(4)
%       • markerFaceMode   — 'none' (outline) or 'auto' (match line colour)
%       • legendFontWeight — 'normal' or 'bold' on the Legend object
%
%   Only data series are touched — auxiliary lines with HandleVisibility
%   'off' (mask overlay, whiskers, theory ticks) keep whatever properties
%   they were created with.  That rule is what makes this helper safe to
%   call from the main render path without second-guessing every call
%   site's intent.
%
%   INPUTS:
%       targetAx    — axes handle
%       appearance  — resolved style struct (from bosonPlotter.resolveStyle)

    arguments
        targetAx     matlab.graphics.axis.Axes
        appearance   struct
    end

    if ~isvalid(targetAx), return; end

    % ── Flush pending graphics updates so the Line.Edge and
    %    Line.MarkerHandle primitives exist before we reach for them.
    %    Plain `drawnow` would re-enter user callbacks; `limitrate`
    %    flushes the render pipeline without re-dispatching
    %    callbacks, which is exactly what we need from inside the
    %    render path itself.  Without this, the line objects are
    %    still pending construction when we run and Edge is empty.
    try drawnow limitrate; catch, end

    % ── Pull the fields we care about (backfillDefaults guarantees
    %    they exist, but stay defensive against hand-built structs) ──
    alphaVal = 1.0;
    if isfield(appearance, 'alpha') && isnumeric(appearance.alpha) && ~isempty(appearance.alpha)
        alphaVal = max(0, min(1, double(appearance.alpha)));
    end

    faceMode = 'none';
    if isfield(appearance, 'markerFaceMode') && ~isempty(appearance.markerFaceMode)
        faceMode = char(appearance.markerFaceMode);
    end

    legendWeight = '';
    if isfield(appearance, 'legendFontWeight') && ~isempty(appearance.legendFontWeight)
        legendWeight = char(appearance.legendFontWeight);
    end

    % ── Walk the axes children once.  Lines/errorbars that are
    %    HandleVisibility='on' are data series; everything else is
    %    treated as chrome and left alone.  Using findall instead of
    %    findobj so we can see through suppressed visibility and make
    %    our own decision. ──
    children = findall(targetAx, '-depth', 1);
    for k = 1:numel(children)
        h = children(k);
        if ~isvalid(h), continue; end

        hv = get(h, 'HandleVisibility');
        if ~strcmp(hv, 'on')
            continue;   % chrome/auxiliary — skip
        end

        t = lower(get(h, 'Type'));
        switch t
            case {'line', 'errorbar'}
                applyAlphaToLine(h, alphaVal);
                applyFaceModeToLine(h, faceMode);
        end
    end

    % ── Legend font weight (separate object — not a child of axes
    %    for find purposes, but reachable via the Legend property) ──
    if ~isempty(legendWeight)
        try
            lgd = targetAx.Legend;
            if ~isempty(lgd) && isvalid(lgd)
                lgd.FontWeight = legendWeight;
            end
        catch
        end
    end
end


% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function applyAlphaToLine(h, alphaVal)
%APPLYALPHATOLINE  Apply alpha to a Line / ErrorBar object.
%
%   MATLAB's documented Line.Color property silently truncates the
%   4th element — it only stores RGB.  To actually get transparent
%   lines we have to reach for the undocumented `Edge` primitive
%   (stable since R2018b) and set ColorType='truecoloralpha' with a
%   uint8 [R;G;B;A] ColorData vector.  The MarkerHandle primitive
%   has the same escape hatch for filled/edge marker colours.
%
%   On older MATLAB releases where Edge/MarkerHandle don't exist, we
%   silently degrade by blending the colour with white — the line
%   isn't actually translucent, but the colour pops less, which is
%   close enough to the intent for a no-op fallback.
%
%   When alphaVal >= 1 we leave the Color alone entirely so exports
%   (EMF, clipboard) don't inherit any RGBA baggage.
    if alphaVal >= 1.0, return; end

    try
        c = get(h, 'Color');
    catch
        return;
    end
    if ~isnumeric(c) || numel(c) < 3, return; end
    c3 = double(c(1:3));
    aVal = max(0, min(1, double(alphaVal)));
    rgba = uint8(round([c3(:); aVal] * 255));

    % ── Primary path: object-type-specific primitives ─────────────
    % Line:     h.Edge                 (LineStrip primitive)
    % ErrorBar: h.Bar + h.Cap          (LineStrip + Marker primitives)
    % Both:     h.MarkerHandle         (Marker primitive for the plot
    %                                   symbols, distinct from the line)
    applied = false;

    % Line.Edge — Line objects only
    try
        if isprop(h, 'Edge')
            e = h.Edge;
            if ~isempty(e) && isvalid(e)
                e.ColorType = 'truecoloralpha';
                e.ColorData = rgba;
                applied = true;
            end
        end
    catch
    end

    % ErrorBar.Bar — the whisker line primitive
    try
        if isprop(h, 'Bar')
            b = h.Bar;
            if ~isempty(b) && isvalid(b)
                b.ColorType = 'truecoloralpha';
                b.ColorData = rgba;
                applied = true;
            end
        end
    catch
    end

    % ErrorBar.Cap — the whisker cap primitive (Marker world object)
    try
        if isprop(h, 'Cap')
            cp = h.Cap;
            if ~isempty(cp) && isvalid(cp)
                cp.EdgeColorType = 'truecoloralpha';
                cp.EdgeColorData = rgba;
                applied = true;
            end
        end
    catch
    end

    % MarkerHandle — the data-symbol markers (both Line and ErrorBar)
    try
        if isprop(h, 'MarkerHandle')
            mh = h.MarkerHandle;
            if ~isempty(mh) && isvalid(mh)
                mh.EdgeColorType = 'truecoloralpha';
                mh.EdgeColorData = rgba;
                % If the marker is filled, carry alpha to the face too
                try
                    faceCt = mh.FaceColorType;
                    if ~isempty(faceCt) && ~strcmp(faceCt, 'none')
                        mh.FaceColorType = 'truecoloralpha';
                        mh.FaceColorData = rgba;
                    end
                catch
                end
                applied = true;
            end
        end
    catch
    end

    % ── Fallback path: colour blending with white ─────────────────
    % Only fires when the primary path never applied — older MATLAB
    % releases without the Edge primitive get a visual approximation
    % (line turns closer to white, mimicking the look of alpha).
    if ~applied
        try
            blended = (1 - aVal) * [1 1 1] + aVal * c3(:).';
            set(h, 'Color', blended);
        catch
        end
    end
end

function applyFaceModeToLine(h, faceMode)
%APPLYFACEMODETOLINE  Set MarkerFaceColor based on faceMode.
%   'none' leaves markers as outlines (MATLAB default).
%   'auto' fills the marker with the same colour as the line edge —
%   useful for publication plots where filled markers read better
%   against busy backgrounds.
    try
        if ~isprop(h, 'MarkerFaceColor'), return; end
    catch
        return;
    end

    switch lower(faceMode)
        case 'none'
            try set(h, 'MarkerFaceColor', 'none'); catch, end
        case 'auto'
            % 'auto' mirrors the line colour.  We strip any alpha
            % channel — face colour uses RGB only, and MATLAB
            % rejects [R G B A] on MarkerFaceColor.
            try
                c = get(h, 'Color');
                if isnumeric(c) && numel(c) >= 3
                    set(h, 'MarkerFaceColor', c(1:3));
                end
            catch
            end
        otherwise
            % Unknown — leave alone
    end
end
