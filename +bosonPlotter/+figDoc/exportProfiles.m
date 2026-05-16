function profile = exportProfiles(name)
%EXPORTPROFILES  Return export profile struct by name.
%
%   profile = bosonPlotter.figDoc.exportProfiles('powerpoint')
%   profile = bosonPlotter.figDoc.exportProfiles('aps')
%   profile = bosonPlotter.figDoc.exportProfiles('nature')
%   profile = bosonPlotter.figDoc.exportProfiles('aps-double')
%   profile = bosonPlotter.figDoc.exportProfiles('poster')
%
%   Each profile specifies target dimensions, DPI, font sizes, and line
%   widths optimized for that output medium.
%
%   Output struct fields:
%     .name       - display name
%     .width      - figure width (inches)
%     .height     - figure height (inches)
%     .dpi        - resolution (dots per inch)
%     .fontSize   - base font size (pt)
%     .tickFont   - tick label font size (pt)
%     .lineWidth  - data line width (pt)
%     .axesWidth  - axes line width (pt)
%     .fontName   - font family
%     .format     - 'png' | 'pdf' | 'eps' | 'svg'
%     .renderer   - 'opengl' | 'painters'

    switch lower(name)
        case 'powerpoint'
            profile.name      = 'PowerPoint (16:9)';
            profile.width     = 10;
            profile.height    = 5.625;
            profile.dpi       = 150;
            profile.fontSize  = 16;
            profile.tickFont  = 14;
            profile.lineWidth = 2.0;
            profile.axesWidth = 1.0;
            profile.fontName  = 'Arial';
            profile.format    = 'png';
            profile.renderer  = 'opengl';

        case 'aps'
            profile.name      = 'APS Single Column';
            profile.width     = 3.375;
            profile.height    = 2.5;
            profile.dpi       = 600;
            profile.fontSize  = 10;
            profile.tickFont  = 9;
            profile.lineWidth = 0.75;
            profile.axesWidth = 0.5;
            profile.fontName  = 'Arial';
            profile.format    = 'pdf';
            profile.renderer  = 'painters';

        case 'aps-double'
            profile.name      = 'APS Double Column';
            profile.width     = 7.0;
            profile.height    = 4.5;
            profile.dpi       = 600;
            profile.fontSize  = 10;
            profile.tickFont  = 9;
            profile.lineWidth = 0.75;
            profile.axesWidth = 0.5;
            profile.fontName  = 'Arial';
            profile.format    = 'pdf';
            profile.renderer  = 'painters';

        case 'nature'
            profile.name      = 'Nature Single Column';
            profile.width     = 3.503;   % 89 mm
            profile.height    = 2.75;
            profile.dpi       = 600;
            profile.fontSize  = 8;
            profile.tickFont  = 7;
            profile.lineWidth = 0.5;
            profile.axesWidth = 0.25;
            profile.fontName  = 'Arial';
            profile.format    = 'pdf';
            profile.renderer  = 'painters';

        case 'nature-double'
            profile.name      = 'Nature Double Column';
            profile.width     = 7.204;   % 183 mm
            profile.height    = 4.5;
            profile.dpi       = 600;
            profile.fontSize  = 8;
            profile.tickFont  = 7;
            profile.lineWidth = 0.5;
            profile.axesWidth = 0.25;
            profile.fontName  = 'Arial';
            profile.format    = 'pdf';
            profile.renderer  = 'painters';

        case 'poster'
            profile.name      = 'Poster / Large Display';
            profile.width     = 12;
            profile.height    = 8;
            profile.dpi       = 300;
            profile.fontSize  = 24;
            profile.tickFont  = 20;
            profile.lineWidth = 3.0;
            profile.axesWidth = 1.5;
            profile.fontName  = 'Arial';
            profile.format    = 'png';
            profile.renderer  = 'opengl';

        otherwise
            error('figDoc:unknownProfile', 'Unknown export profile "%s".', name);
    end
end
