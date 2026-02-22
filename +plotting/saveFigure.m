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
%       Width   — figure width  in cm (default: from styles.default)
%       Height  — figure height in cm (default: from styles.default)
%       Theme   — theme struct for default Width/Height (default: [])
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
        options.DPI    (1,1) double  {mustBePositive} = 300
        options.Width  (1,1) double  {mustBePositive} = 0
        options.Height (1,1) double  {mustBePositive} = 0
        options.Theme                                  = []
    end

    % Resolve dimensions from theme defaults when not explicitly specified
    if options.Width == 0 || options.Height == 0
        th = options.Theme;
        if isempty(th)
            th = styles.default();
        end
        if options.Width  == 0, options.Width  = th.figWidth;  end
        if options.Height == 0, options.Height = th.figHeight; end
    end

    % ── Set figure paper size (cm → inch conversion for MATLAB's PaperSize) ─
    cmPerInch = 2.54;
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
            print(fig, char(filepath), '-dpdf', '-painters');
        case '.svg'
            print(fig, char(filepath), '-dsvg', '-painters');
        case '.eps'
            print(fig, char(filepath), '-depsc', '-painters');
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
