function formatAxes(ax, theme, options)
%FORMATAXES  Apply a visual theme to an axes object.
%
%   plotting.formatAxes(ax)
%   plotting.formatAxes(ax, theme)
%   plotting.formatAxes(ax, theme, 'XLabel', 'Field (Oe)', 'YLabel', 'M (emu)')
%
%   Applies font sizes, tick direction, grid alpha, box state and other
%   cosmetic properties defined in a theme struct to the axes ax.
%   Falls back to styles.default() when no theme is supplied.
%
%   INPUTS:
%       ax    — axes handle (e.g. gca)
%       theme — (optional) struct from styles.default() or a custom theme.
%               Omit or pass [] to use styles.default().
%
%   OPTIONAL NAME-VALUE PAIRS:
%       XLabel      — x-axis label string (default: keep existing)
%       YLabel      — y-axis label string (default: keep existing)
%       Title       — axes title string   (default: keep existing)
%       XScale      — 'linear' | 'log'   (default: keep existing)
%       YScale      — 'linear' | 'log'   (default: keep existing)
%
%   EXAMPLE:
%       th = styles.default();
%       fig = figure;
%       plot(data.time, data.values, 'Color', th.colors(1,:));
%       plotting.formatAxes(gca, th, 'XLabel', '2\theta (°)', 'YLabel', 'Counts');
%
%   See also styles.default, plotting.saveFigure, plotting.lineColors

    arguments
        ax                    (1,1)          % axes handle
        theme                               = []
        options.XLabel        (1,1) string  = ""
        options.YLabel        (1,1) string  = ""
        options.Title         (1,1) string  = ""
        options.XScale        (1,1) string  = ""
        options.YScale        (1,1) string  = ""
    end

    if isempty(theme)
        theme = styles.default();
    end

    % ── Typography ────────────────────────────────────────────────────────
    ax.FontSize       = theme.fontSize;
    ax.Title.FontSize = theme.titleFontSize;
    if ~isempty(ax.Legend)
        ax.Legend.FontSize = theme.legendFontSize;
    end

    % ── Axes appearance ───────────────────────────────────────────────────
    ax.TickDir   = theme.tickDir;
    ax.Box       = guiOnOff(theme.boxOn);
    ax.GridAlpha = theme.gridAlpha;
    grid(ax, 'on');

    % ── Axis scale ────────────────────────────────────────────────────────
    if options.XScale ~= ""
        ax.XScale = char(options.XScale);
    end
    if options.YScale ~= ""
        ax.YScale = char(options.YScale);
    end

    % ── Labels ────────────────────────────────────────────────────────────
    if options.XLabel ~= ""
        xlabel(ax, char(options.XLabel), 'FontSize', theme.fontSize);
    end
    if options.YLabel ~= ""
        ylabel(ax, char(options.YLabel), 'FontSize', theme.fontSize);
    end
    if options.Title ~= ""
        title(ax, char(options.Title), 'FontSize', theme.titleFontSize, ...
            'Interpreter', 'none');
    end
end


function s = guiOnOff(tf)
%GUIONOFF  Convert logical to 'on'/'off' string.
    if tf, s = 'on'; else, s = 'off'; end
end
