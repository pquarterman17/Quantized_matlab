function outPath = exportRender(datasets, activeIdx, overlayMode, model, profileName, outFile)
%EXPORTRENDER  Render figure to file using FigDocModel + export profile.
%
%   outPath = bosonPlotter.figDoc.exportRender(datasets, activeIdx, overlayMode, model, profileName, outFile)
%
%   Creates a temporary invisible figure at the profile's target dimensions,
%   draws the traces, applies model state (style, legend, annotations), then
%   exports to file. The on-screen figure is never touched. WYSIWYG: what
%   the model describes is what gets exported.
%
%   Inputs:
%     datasets    - cell array of dataset structs
%     activeIdx   - active dataset index
%     overlayMode - logical
%     model       - FigDocModel handle
%     profileName - string: 'powerpoint', 'aps', 'nature', etc.
%     outFile     - output file path (extension overridden by profile format)
%
%   Output:
%     outPath - actual path of the exported file

    profile = bosonPlotter.figDoc.exportProfiles(profileName);

    % Ensure output file has correct extension
    [fdir, fname, ~] = fileparts(outFile);
    outPath = fullfile(fdir, [fname '.' profile.format]);

    % Create temporary figure at target size
    figW = profile.width;
    figH = profile.height;
    tmpFig = figure('Visible', 'off', ...
        'Units', 'inches', ...
        'Position', [1 1 figW figH], ...
        'PaperUnits', 'inches', ...
        'PaperSize', [figW figH], ...
        'PaperPosition', [0 0 figW figH], ...
        'Color', 'w', ...
        'Renderer', profile.renderer);

    cleanupFig = onCleanup(@() delete(tmpFig));

    ax = axes(tmpFig, 'Units', 'normalized');

    % Draw traces
    bosonPlotter.figDoc.updateTraces(ax, datasets, activeIdx, overlayMode);

    % Apply model state (limits, legend, annotations, etc.)
    bosonPlotter.figDoc.applyToAxes(ax, model);

    % Override fonts and line widths for export profile
    ax.FontSize = profile.tickFont;
    ax.FontName = profile.fontName;
    ax.LineWidth = profile.axesWidth;

    if ~isempty(ax.XLabel.String)
        ax.XLabel.FontSize = profile.fontSize;
        ax.XLabel.FontName = profile.fontName;
    end
    if ~isempty(ax.YLabel.String)
        ax.YLabel.FontSize = profile.fontSize;
        ax.YLabel.FontName = profile.fontName;
    end

    % Scale data line widths (respect user overrides from traceStyles)
    lines = findobj(ax.Children, 'Type', 'Line');
    for k = 1:numel(lines)
        trIdx = numel(lines) - k + 1;
        hasOverride = trIdx <= numel(model.traceStyles) ...
            && isfield(model.traceStyles{trIdx}, 'lineWidth') ...
            && ~isempty(model.traceStyles{trIdx}.lineWidth);
        if ~hasOverride
            lines(k).LineWidth = profile.lineWidth;
        end
    end

    % Scale legend font
    lgd = ax.Legend;
    if ~isempty(lgd) && isvalid(lgd)
        lgd.FontSize = profile.tickFont;
        lgd.FontName = profile.fontName;
    end

    % Export
    switch profile.format
        case 'pdf'
            exportgraphics(tmpFig, outPath, ...
                'ContentType', 'vector', ...
                'Resolution', profile.dpi);
        case 'eps'
            exportgraphics(tmpFig, outPath, ...
                'ContentType', 'vector', ...
                'Resolution', profile.dpi);
        case 'svg'
            exportgraphics(tmpFig, outPath, ...
                'ContentType', 'vector');
        otherwise % png, tiff, jpg
            exportgraphics(tmpFig, outPath, ...
                'Resolution', profile.dpi);
    end
end
