function applyAlphaToLine(h, alphaVal)
%APPLYALPHATOLINE  Apply alpha transparency to a Line / ErrorBar handle.
%
%   bosonPlotter.applyAlphaToLine(h, alphaVal)
%
%   On R2024b+ MATLAB's documented Line.Color property accepts a 4-element
%   [R G B A] vector for native transparency.  On older releases, this
%   function falls back to the undocumented `Edge`/`Bar`/`MarkerHandle`
%   primitives with ColorType='truecoloralpha', and as a last resort blends
%   with white.
%
%   When alphaVal >= 1 this is a no-op so exports (EMF, clipboard) don't
%   inherit any RGBA baggage.
%
%   INPUTS:
%       h        — line/errorbar handle (or anything with .Edge/.Bar)
%       alphaVal — scalar in [0, 1].  Values >= 1 are a no-op; 0 hides.

    if alphaVal >= 1.0, return; end
    if ~isvalid(h), return; end

    try
        c = get(h, 'Color');
    catch
        return;
    end
    if ~isnumeric(c) || numel(c) < 3, return; end
    c3 = double(c(1:3));
    aVal = max(0, min(1, double(alphaVal)));

    % ── R2024b+ native alpha ─────────────────────────────────────────
    % Line.Color accepts [R G B A] as a documented feature.
    if ~isMATLABReleaseOlderThan('R2024b')
        try
            set(h, 'Color', [c3(:).', aVal]);
            % Markers too
            if isprop(h, 'MarkerEdgeColor') && ~strcmp(get(h,'MarkerEdgeColor'), 'none')
                set(h, 'MarkerEdgeColor', [c3(:).', aVal]);
            end
            if isprop(h, 'MarkerFaceColor') && isnumeric(get(h,'MarkerFaceColor'))
                set(h, 'MarkerFaceColor', [c3(:).', aVal]);
            end
            return;
        catch
            % Fall through to undocumented path
        end
    end

    % ── Pre-R2024b: undocumented primitive approach ──────────────────
    persistent warnedAlphaFallback
    if isempty(warnedAlphaFallback)
        warnedAlphaFallback = true;
        fprintf('Note: Line transparency using fallback mode. Upgrade to R2024b+ for native alpha support.\n');
    end
    rgba = uint8(round([c3(:); aVal] * 255));
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

    % ErrorBar.Cap — the whisker cap primitive
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

    % Fallback: colour blending with white (visual approximation —
    % undocumented primitives not available on this graphics object)
    if ~applied
        try
            blended = (1 - aVal) * [1 1 1] + aVal * c3(:).';
            set(h, 'Color', blended);
        catch
        end
    end
end
