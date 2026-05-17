function saveFigure(appData, fig, ui, callbacks)
%SAVEFIGURE  Export the current plot to a file using exportgraphics.
%
% Syntax
%   bosonPlotter.saveFigure(appData, fig, ui, callbacks)
%
% Behaviour
%   Format and resolution are read from the ddFigFormat dropdown.  Width
%   and height come from efFigWidth / efFigHeight (inches).  Renders
%   into a hidden temporary figure with a transparent canvas (like
%   onCopyToClipboard) so the live GUI axes is not disturbed, then
%   writes via savefig (for .fig) or exportgraphics (all other
%   formats).  Uses bosonPlotter.styleAxesForExport to darken axes for
%   white-background output.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads datasets / activeIdx)
%   fig       - Main BosonPlotter figure handle (for uialert parent)
%   ui        - Struct with widget handles: ddFigFormat, efFigWidth,
%               efFigHeight
%   callbacks - Struct of function handles:
%                 .drawToAxes(targetAx)    — renders the preview into the
%                                            given temporary axes
%                 .logGUIError(title, msg, ME) — error sink

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig,'Load a file first.','No data'); return;
    end

    % Map dropdown choice to file extension and exportgraphics options.
    % BackgroundColor='none' gives transparent output for PNG/TIFF,
    % which paste cleanly into both light and dark documents. PDF/SVG
    % also honour it. JPEG (not offered here) would ignore it since
    % JPEG has no alpha channel.
    fmtStr = ui.ddFigFormat.Value;
    isFigFormat = strcmp(fmtStr, 'MATLAB .fig');
    switch fmtStr
        case 'PNG (300 dpi)'
            ext      = '.png';
            fmtFilter = {'*.png','PNG image (*.png)'};
            egOpts   = {'ContentType','image','Resolution',300, 'BackgroundColor','none'};
        case 'PDF (vector)'
            ext      = '.pdf';
            fmtFilter = {'*.pdf','PDF vector (*.pdf)'};
            egOpts   = {'ContentType','vector', 'BackgroundColor','none'};
        case 'SVG (vector)'
            ext      = '.svg';
            fmtFilter = {'*.svg','SVG vector (*.svg)'};
            egOpts   = {'ContentType','vector', 'BackgroundColor','none'};
        case 'TIFF (300 dpi)'
            ext      = '.tif';
            fmtFilter = {'*.tif','TIFF image (*.tif)'};
            egOpts   = {'ContentType','image','Resolution',300, 'BackgroundColor','none'};
        case 'MATLAB .fig'
            ext      = '.fig';
            fmtFilter = {'*.fig','MATLAB figure (*.fig)'};
            egOpts   = {};
        otherwise
            ext      = '.pdf';
            fmtFilter = {'*.pdf','PDF vector (*.pdf)'};
            egOpts   = {'ContentType','vector', 'BackgroundColor','none'};
    end

    % Suggest a filename based on the active dataset
    ds = appData.datasets{appData.activeIdx};
    [dPath, dName, ~] = fileparts(ds.filepath);
    defPath = fullfile(dPath, [dName, ext]);

    [fname, fpath] = uiputfile(fmtFilter, 'Save figure as...', defPath);
    if isequal(fname, 0), return; end
    outPath = fullfile(fpath, fname);

    % Use custom figure dimensions from efFigWidth/efFigHeight (#7)
    figW = ui.efFigWidth.Value;
    figH = ui.efFigHeight.Value;

    % Render into a hidden figure with a transparent canvas so the
    % saved image doesn't carry the GUI's dark-theme background.
    tmpFig = figure('Visible','off','Name','SaveFig','NumberTitle','off', ...
                    'MenuBar','none','ToolBar','none', ...
                    'Renderer','painters','Color','none', ...
                    'Units','inches','Position',[0 0 figW figH]);
    tmpAx = axes(tmpFig);
    set(tmpAx, 'Color','none');
    box(tmpAx,'on');
    grid(tmpAx,'on');
    callbacks.drawToAxes(tmpAx);
    bosonPlotter.styleAxesForExport(tmpAx);
    try
        if isFigFormat
            savefig(tmpFig, outPath);  % #20: MATLAB .fig format
        else
            exportgraphics(tmpFig, outPath, egOpts{:});
        end
        delete(tmpFig);
        uialert(fig, sprintf('Saved:\n%s', outPath), 'Figure Saved');
    catch ME
        delete(tmpFig);
        callbacks.logGUIError('Save error (exportgraphics)', ME.message, ME);
        uialert(fig, sprintf('Export failed:\n%s', ME.message), 'Save error');
    end
end
