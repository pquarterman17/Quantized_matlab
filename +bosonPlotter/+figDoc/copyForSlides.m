function copyForSlides(datasets, activeIdx, overlayMode, model)
%COPYFORSLIDES  Render with PowerPoint profile and copy to clipboard.
%
%   bosonPlotter.figDoc.copyForSlides(datasets, activeIdx, overlayMode, model)
%
%   Creates a temporary figure at slide dimensions (10"x5.625" @150dpi)
%   with thick lines and large fonts, then copies it to the system clipboard.
%   No file dialog — one-click paste into PowerPoint/Keynote.

    profile = bosonPlotter.figDoc.exportProfiles('powerpoint');

    figW = profile.width;
    figH = profile.height;
    tmpFig = figure('Visible', 'off', ...
        'Units', 'inches', ...
        'Position', [1 1 figW figH], ...
        'Color', 'w', ...
        'Renderer', profile.renderer);

    cleanupFig = onCleanup(@() delete(tmpFig));

    ax = axes(tmpFig, 'Units', 'normalized');

    bosonPlotter.figDoc.updateTraces(ax, datasets, activeIdx, overlayMode);
    bosonPlotter.figDoc.applyToAxes(ax, model);

    % Override for slide readability
    ax.FontSize = profile.tickFont;
    ax.FontName = profile.fontName;
    ax.LineWidth = profile.axesWidth;
    if ~isempty(ax.XLabel.String)
        ax.XLabel.FontSize = profile.fontSize;
    end
    if ~isempty(ax.YLabel.String)
        ax.YLabel.FontSize = profile.fontSize;
    end
    lines = findobj(ax.Children, 'Type', 'Line');
    for k = 1:numel(lines)
        lines(k).LineWidth = profile.lineWidth;
    end
    lgd = ax.Legend;
    if ~isempty(lgd) && isvalid(lgd)
        lgd.FontSize = profile.tickFont;
    end

    % Copy to clipboard
    copygraphics(tmpFig, 'Resolution', profile.dpi);
end
