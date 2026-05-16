function buildQuickExportDialog(fig, datasets, activeIdx, overlayMode, model)
%BUILDQUICKEXPORTDIALOG  One-click export dialog with profile presets.
%
%   bosonPlotter.figDoc.buildQuickExportDialog(fig, datasets, activeIdx, overlayMode, model)
%
%   Opens a compact dialog with:
%   - Profile selector (PowerPoint, APS, Nature, Poster)
%   - Preview of target dimensions
%   - "Copy to Clipboard" button (for slides)
%   - "Save to File" button (for papers)

    if activeIdx < 1 || isempty(datasets), return; end

    profiles = {'powerpoint', 'aps', 'aps-double', 'nature', 'nature-double', 'poster'};
    profileNames = {'PowerPoint (16:9)', 'APS Single Column', 'APS Double Column', ...
                    'Nature Single', 'Nature Double', 'Poster'};

    dlg = uifigure('Name', 'Quick Export', 'Position', [300 300 360 260], ...
        'Resize', 'off');
    gl = uigridlayout(dlg, [7 2], ...
        'RowHeight', {26, 26, 26, 26, 26, 10, 36}, ...
        'ColumnWidth', {'1x', '1x'}, ...
        'Padding', [12 12 12 12], 'RowSpacing', 6);

    uilabel(gl, 'Text', 'Export Profile:', 'FontWeight', 'bold');
    ddProfile = uidropdown(gl, 'Items', profileNames, 'Value', profileNames{1});
    ddProfile.Layout.Row = 1; ddProfile.Layout.Column = 2;

    lblDims = uilabel(gl, 'Text', '');
    lblDims.Layout.Row = 2; lblDims.Layout.Column = [1 2];

    lblFonts = uilabel(gl, 'Text', '');
    lblFonts.Layout.Row = 3; lblFonts.Layout.Column = [1 2];

    lblLines = uilabel(gl, 'Text', '');
    lblLines.Layout.Row = 4; lblLines.Layout.Column = [1 2];

    lblFormat = uilabel(gl, 'Text', '');
    lblFormat.Layout.Row = 5; lblFormat.Layout.Column = [1 2];

    btnCopy = uibutton(gl, 'Text', 'Copy to Clipboard', ...
        'FontWeight', 'bold');
    btnCopy.Layout.Row = 7; btnCopy.Layout.Column = 1;

    btnSave = uibutton(gl, 'Text', 'Save to File');
    btnSave.Layout.Row = 7; btnSave.Layout.Column = 2;

    updatePreview(ddProfile.Value);

    ddProfile.ValueChangedFcn = @(~,~) updatePreview(ddProfile.Value);

    btnCopy.ButtonPushedFcn = @(~,~) doCopy();
    btnSave.ButtonPushedFcn = @(~,~) doSave();

    function updatePreview(profileName)
        idx = find(strcmp(profileNames, profileName), 1);
        if isempty(idx), idx = 1; end
        p = bosonPlotter.figDoc.exportProfiles(profiles{idx});
        lblDims.Text = sprintf('Size: %.2f" x %.2f" @ %d DPI', p.width, p.height, p.dpi);
        lblFonts.Text = sprintf('Fonts: %dpt labels, %dpt ticks (%s)', p.fontSize, p.tickFont, p.fontName);
        lblLines.Text = sprintf('Lines: %.1fpt data, %.2fpt axes', p.lineWidth, p.axesWidth);
        lblFormat.Text = sprintf('Format: %s (%s renderer)', upper(p.format), p.renderer);
    end

    function doCopy()
        idx = find(strcmp(profileNames, ddProfile.Value), 1);
        pName = profiles{idx};
        try
            dlg.Pointer = 'watch'; drawnow;
            bosonPlotter.figDoc.copyForSlides(datasets, activeIdx, overlayMode, model);
            dlg.Pointer = 'arrow';
            uialert(dlg, 'Plot copied to clipboard!', 'Success', 'Icon', 'success');
            model.lastExportProfile = pName;
        catch ME
            dlg.Pointer = 'arrow';
            uialert(dlg, sprintf('Copy failed:\n%s', ME.message), 'Error', 'Icon', 'error');
        end
    end

    function doSave()
        idx = find(strcmp(profileNames, ddProfile.Value), 1);
        pName = profiles{idx};
        p = bosonPlotter.figDoc.exportProfiles(pName);
        ext = p.format;
        [fname, fdir] = uiputfile(['*.' ext], 'Save Figure', ...
            fullfile(pwd, ['export.' ext]));
        if isequal(fname, 0), return; end
        outFile = fullfile(fdir, fname);
        try
            dlg.Pointer = 'watch'; drawnow;
            outPath = bosonPlotter.figDoc.exportRender(datasets, activeIdx, ...
                overlayMode, model, pName, outFile);
            dlg.Pointer = 'arrow';
            model.lastExportProfile = pName;
            uialert(dlg, sprintf('Saved: %s', outPath), 'Exported', 'Icon', 'success');
        catch ME
            dlg.Pointer = 'arrow';
            uialert(dlg, sprintf('Export failed:\n%s', ME.message), 'Error', 'Icon', 'error');
        end
    end
end
