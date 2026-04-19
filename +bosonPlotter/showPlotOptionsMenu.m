function showPlotOptionsMenu(appData, fig, headless, callbacks)
%SHOWPLOTOPTIONSMENU  Open (or raise) the Plot Options popup figure.
%
% Syntax
%   bosonPlotter.showPlotOptionsMenu(appData, fig, headless, callbacks)
%
% Behaviour
%   Invoked by the "Plot Options..." toolbar button (two entry points in
%   BosonPlotter: the top toolbar and the 2D/image-mode toolbar).  If
%   the popup is already open (`appData.plotOptFig` valid), brings it to
%   the front and returns.  Otherwise builds a two-section popup — PLOT
%   TYPES (Compose Figure / 3D Surface / Polar Plot) and CONVERT
%   (Unit Converter / XRD CSV Export) — plus a Close button.  Each
%   action button calls `bosonPlotter.closePlotOptMenu` to dismiss the
%   popup, then dispatches to the supplied callback.
%
% Inputs
%   appData    - bosonPlotter.AppState handle (mutates plotOptFig)
%   fig        - Main figure handle (only used for anchoring the popup
%                   position near the main window)
%   headless   - logical; when true, omits the `figure(plotOptFig)`
%                   raise-to-front call (avoids figure focus changes in
%                   headless test runs)
%   callbacks  - Struct of function handles:
%                   .onComposeFigure(src, evt)
%                   .on3DSurface(src, evt)
%                   .onPolarPlot(src, evt)
%                   .onConvertUnits(src, evt)
%                   .onWriteXRDcsv(src, evt)

    if ~isempty(appData.plotOptFig) && isvalid(appData.plotOptFig)
        if ~headless, figure(appData.plotOptFig); end
        return;
    end

    BTN_BG = [0.15 0.15 0.15];
    BTN_FC = [0.9 0.9 0.9];
    HDR_FC = [0.5 0.5 0.5];

    figPos = fig.Position;
    appData.plotOptFig = uifigure('Name', 'Plot Options', ...
        'Position', [figPos(1) + 200, figPos(2) + figPos(4) - 300, 220, 260], ...
        'Resize', 'off', ...
        'CloseRequestFcn', @(~,~) bosonPlotter.closePlotOptMenu(appData), ...
        'KeyPressFcn', @(~,evt) localKey(appData, evt));

    poGL = uigridlayout(appData.plotOptFig, [10 1], ...
        'RowHeight', {16, 26, 26, 26, 5, 16, 26, 26, 5, 26}, ...
        'ColumnWidth', {'1x'}, ...
        'Padding', [8 6 8 6], 'RowSpacing', 2);

    lblPT = uilabel(poGL, 'Text', 'PLOT TYPES', 'FontSize', 9, ...
        'FontWeight', 'bold', 'FontColor', HDR_FC);
    lblPT.Layout.Row = 1;

    localBtn(poGL, 2, 'Compose Figure...', callbacks.onComposeFigure, ...
        'Multi-panel composite figure with subplot labels and annotations', ...
        appData, BTN_BG, BTN_FC);
    localBtn(poGL, 3, '3D Surface / Mesh...', callbacks.on3DSurface, ...
        'Surface, mesh, or contour plot from gridded 2D data (e.g. area detector XRDML)', ...
        appData, BTN_BG, BTN_FC);
    localBtn(poGL, 4, 'Polar Plot...', callbacks.onPolarPlot, ...
        'Polar plot for phi scans, pole figures, and angular measurements', ...
        appData, BTN_BG, BTN_FC);

    lblCv = uilabel(poGL, 'Text', 'CONVERT', 'FontSize', 9, ...
        'FontWeight', 'bold', 'FontColor', HDR_FC);
    lblCv.Layout.Row = 6;

    localBtn(poGL, 7, ['Convert Units (' char(8596) ')...'], callbacks.onConvertUnits, ...
        ['Convert axis units: Oe' char(8596) 'T, emu' char(8596) ...
         'A' char(183) 'm' char(178) ', K' char(8596) char(176) 'C, etc.'], ...
        appData, BTN_BG, BTN_FC);
    localBtn(poGL, 8, 'XRD CSV Export...', callbacks.onWriteXRDcsv, ...
        'Export XRD data as CSV with metadata header (standard or Origin ASCII format)', ...
        appData, BTN_BG, BTN_FC);

    btnCloseP = uibutton(poGL, 'Text', 'Close', ...
        'ButtonPushedFcn', @(~,~) bosonPlotter.closePlotOptMenu(appData), ...
        'BackgroundColor', [0.25 0.25 0.25], 'FontColor', [0.7 0.7 0.7]);
    btnCloseP.Layout.Row = 10;
end

function localBtn(gl, row, txt, cb, tip, appData, bgCol, fcCol)
    b = uibutton(gl, 'Text', txt, ...
        'ButtonPushedFcn', @(~,~) localAction(appData, cb), ...
        'BackgroundColor', bgCol, 'FontColor', fcCol, ...
        'HorizontalAlignment', 'left', ...
        'Tooltip', tip);
    b.Layout.Row = row;
end

function localAction(appData, callbackFcn)
    bosonPlotter.closePlotOptMenu(appData);
    callbackFcn([], []);
end

function localKey(appData, evt)
    if strcmp(evt.Key, 'escape'), bosonPlotter.closePlotOptMenu(appData); end
end
