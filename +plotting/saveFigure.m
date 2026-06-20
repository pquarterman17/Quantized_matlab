function saveFigure(fig, filepath, options)
%SAVEFIGURE  Export a figure to disk at publication-ready resolution.
%
%   plotting.saveFigure(fig, 'output/scan.png')
%   plotting.saveFigure(fig, 'output/scan.pdf', 'DPI', 600)
%   plotting.saveFigure(fig, 'output/scan.png', 'Width', 14, 'Height', 10)
%
%   Saves the figure fig to filepath.  The file format is inferred from the
%   extension (.png, .pdf, .svg, .eps, .tif).  Width and Height set the
%   figure's PaperSize in centimetres before export so the output matches
%   the physical dimensions used in the theme.
%
%   INPUTS:
%       fig      — figure handle
%       filepath — output path including extension (string or char)
%
%   OPTIONAL NAME-VALUE PAIRS:
%       DPI     — raster resolution in dots per inch (default: 300)
%       Width   — figure width  in cm.  Default 0 = resolve in priority order:
%                 (1) Theme's size if a Theme is given, (2) the cm size stamped
%                 by plotting.applyTemplate, (3) styles.default (14x10).
%       Height  — figure height in cm (same default-resolution logic as Width)
%       Theme   — theme struct for default Width/Height (default: [])
%
%   When Width/Height are omitted, a figure styled with plotting.applyTemplate
%   exports at its preset size (applyTemplate stamps the cm size in the figure's
%   'qmExportSizeCm' appdata).  Untemplated figures use the deterministic
%   styles.default size so basic-recipe output is reproducible across machines.
%
%   EXAMPLE:
%       fig = figure;
%       plot(data.time, data.values);
%       plotting.formatAxes(gca, [], 'XLabel', '2\theta (°)');
%       plotting.saveFigure(fig, 'xrd_scan.pdf');
%
%   See also plotting.formatAxes, styles.default

    arguments
        fig      (1,1)
        filepath (1,1) string
        options.DPI    (1,1) double  {mustBePositive}    = 300
        options.Width  (1,1) double  {mustBeNonnegative} = 0   % 0 = resolve from theme/default
        options.Height (1,1) double  {mustBeNonnegative} = 0   % 0 = resolve from theme/default
        options.Theme                                    = []
    end

    % Resolve omitted dimensions (the 0 sentinel) from most- to least-specific
    % source. Precedence:
    %   1. An explicit Theme's figWidth/figHeight, when a Theme was passed.
    %   2. The cm size stamped by plotting.applyTemplate — so a templated figure
    %      exports at its preset size instead of being reset to styles.default.
    %   3. styles.default (14x10) — deterministic, machine-independent fallback
    %      for untemplated figures (keeps the basic recipe reproducible).
    if options.Width == 0 || options.Height == 0
        if ~isempty(options.Theme)
            th = options.Theme;
            if options.Width  == 0, options.Width  = th.figWidth;  end
            if options.Height == 0, options.Height = th.figHeight; end
        else
            stampCm = getappdata(fig, 'qmExportSizeCm');  % set by plotting.applyTemplate
            if numel(stampCm) == 2
                if options.Width  == 0 && stampCm(1) > 0, options.Width  = stampCm(1); end
                if options.Height == 0 && stampCm(2) > 0, options.Height = stampCm(2); end
            end
        end
    end

    % Deterministic fallback for any dimension still unresolved (untemplated
    % figure, or a Theme missing the field) — never export at 0 cm.
    if options.Width == 0 || options.Height == 0
        d = styles.default();
        if options.Width  == 0, options.Width  = d.figWidth;  end
        if options.Height == 0, options.Height = d.figHeight; end
    end

    % ── Set figure paper size (cm → inch conversion for MATLAB's PaperSize) ─
    cmPerInch = 2.54; %#ok<NASGU>
    fig.Units         = 'centimeters';
    fig.Position(3:4) = [options.Width, options.Height];
    fig.PaperUnits    = 'centimeters';
    fig.PaperSize     = [options.Width, options.Height];
    fig.PaperPosition = [0, 0, options.Width, options.Height];

    % ── Determine format and export ───────────────────────────────────────
    [~, ~, ext] = fileparts(filepath);
    ext = lower(ext);

    switch ext
        case '.pdf'
            print(fig, char(filepath), '-dpdf', '-vector');
        case '.svg'
            print(fig, char(filepath), '-dsvg', '-vector');
        case '.eps'
            print(fig, char(filepath), '-depsc', '-vector');
        case {'.tif', '.tiff'}
            print(fig, char(filepath), '-dtiff', sprintf('-r%d', options.DPI));
        case '.png'
            print(fig, char(filepath), '-dpng', sprintf('-r%d', options.DPI));
        otherwise
            error('plotting:saveFigure:unknownFormat', ...
                'Unsupported file extension "%s". Use .png .pdf .svg .eps .tif', ext);
    end

    % Unit reset so the figure stays usable after export
    fig.Units = 'pixels';

    if nargout == 0
        fprintf('Saved: %s  (%.0fx%.0f cm, %d dpi)\n', ...
            filepath, options.Width, options.Height, options.DPI);
    end
end
