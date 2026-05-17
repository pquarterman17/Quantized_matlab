function [ok, warnings] = validateForPublish(ax, preset)
%VALIDATEFORPUBLISH  Check axes against journal requirements before export.
%
%   [ok, warnings] = bosonPlotter.validateForPublish(ax, preset)
%
%   Scans the axes for common rejection reasons: font too small, lines too
%   thin, missing labels, dimensions outside journal spec. Returns a cell
%   array of warning strings. ok is true only when warnings is empty.
%
%   Inputs
%     ax     - axes handle (the temporary export axes, already styled)
%     preset - struct with fields: .name, .fontSize, .lineWidth, .width, .height

    warnings = {};

    minFont  = preset.fontSize;
    minLine  = preset.lineWidth * 0.5;

    % ── Font size checks ─────────────────────────────────────────────────
    if ax.FontSize < minFont
        warnings{end+1} = sprintf('Axis font size (%.0fpt) below %s minimum (%.0fpt)', ...
            ax.FontSize, preset.name, minFont);
    end

    % Check text objects (annotations, fit results boxes)
    texts = findobj(ax, 'Type', 'Text');
    for i = 1:numel(texts)
        if texts(i).FontSize < minFont - 1
            warnings{end+1} = sprintf('Text annotation "%.20s..." at %.0fpt (min %.0fpt)', ...
                texts(i).String, texts(i).FontSize, minFont - 1);
            break;
        end
    end

    % ── Line width checks ────────────────────────────────────────────────
    lines = findobj(ax, 'Type', 'Line');
    thinCount = 0;
    for i = 1:numel(lines)
        if lines(i).LineWidth < minLine
            thinCount = thinCount + 1;
        end
    end
    if thinCount > 0
        warnings{end+1} = sprintf('%d line(s) below %.2fpt (may not reproduce in print)', ...
            thinCount, minLine);
    end

    % ── Axis label checks ────────────────────────────────────────────────
    if isempty(ax.XLabel.String) || strcmp(ax.XLabel.String, '')
        warnings{end+1} = 'X-axis label is empty';
    end
    if isempty(ax.YLabel.String) || strcmp(ax.YLabel.String, '')
        warnings{end+1} = 'Y-axis label is empty';
    end

    % ── Dimension checks ─────────────────────────────────────────────────
    figW = preset.width;
    figH = preset.height;

    % Common journal constraints
    switch preset.name
        case 'APS (PRL/PRB)'
            if figW > 3.375
                warnings{end+1} = sprintf('Width %.3f" exceeds APS single-column max (3.375")', figW);
            end
        case 'Nature'
            if figW > 7.087
                warnings{end+1} = sprintf('Width %.3f" exceeds Nature double-column max (7.087")', figW);
            end
            if figW > 3.503 && figW < 4.724
                warnings{end+1} = 'Width between 89mm and 120mm — not a standard Nature column width';
            end
        case 'ACS'
            if figW > 3.25 && figW < 7.0
                warnings{end+1} = 'Width between single-col (3.25") and double-col (7") — non-standard for ACS';
            end
    end

    % Aspect ratio sanity
    aspect = figH / figW;
    if aspect > 2.5
        warnings{end+1} = sprintf('Aspect ratio %.1f:1 (very tall) — may waste journal space', aspect);
    end
    if aspect < 0.3
        warnings{end+1} = sprintf('Aspect ratio 1:%.1f (very wide) — may not fit column', 1/aspect);
    end

    % ── Legend checks ────────────────────────────────────────────────────
    lgd = findobj(ancestor(ax, 'figure'), 'Type', 'Legend');
    if ~isempty(lgd) && lgd(1).FontSize < minFont - 2
        warnings{end+1} = sprintf('Legend font (%.0fpt) too small for readability', lgd(1).FontSize);
    end

    % ── Tick direction ───────────────────────────────────────────────────
    if strcmp(ax.TickDir, 'out')
        warnings{end+1} = 'Tick direction is "out" — most journals prefer "in"';
    end

    ok = isempty(warnings);
end
