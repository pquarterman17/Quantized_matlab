function buildPreviewPanel(fig, datasets, activeIdx, overlayOn, model)
%BUILDPREVIEWPANEL  WYSIWYG export preview showing figure at target size.
%
%   bosonPlotter.figDoc.buildPreviewPanel(fig, datasets, activeIdx, overlayOn, model)
%
%   Opens a dialog showing a rendered preview of the figure at the selected
%   export profile's dimensions. Highlights potential issues (text too small,
%   lines too thin). User can switch profiles to compare output.

    profiles = {'powerpoint', 'aps', 'aps-double', 'nature', 'nature-double', 'poster'};
    profileLabels = {'PowerPoint', 'APS Single', 'APS Double', 'Nature Single', 'Nature Double', 'Poster'};

    dlg = uifigure('Name', 'Export Preview', ...
        'Position', [100 100 700 550], 'Resize', 'on');
    movegui(dlg, 'center');

    grid = uigridlayout(dlg, [3 1], 'RowHeight', {30, '1x', 30});

    topGrid = uigridlayout(grid, [1 4], 'ColumnWidth', {80, 150, '1x', 100});
    topGrid.Layout.Row = 1;
    uilabel(topGrid, 'Text', 'Profile:');
    ddProfile = uidropdown(topGrid, 'Items', profileLabels, ...
        'ItemsData', profiles, 'Value', model.lastExportProfile);
    lblDims = uilabel(topGrid, 'Text', '');
    btnRefresh = uibutton(topGrid, 'Text', 'Refresh', ...
        'ButtonPushedFcn', @(~,~) refreshPreview_());

    imgPanel = uipanel(grid, 'BorderType', 'line');
    imgPanel.Layout.Row = 2;
    axPreview = uiaxes(imgPanel, 'Position', [10 10 660 440]);
    axPreview.XTick = [];
    axPreview.YTick = [];
    axPreview.Box = 'on';
    axPreview.XColor = [0.7 0.7 0.7];
    axPreview.YColor = [0.7 0.7 0.7];

    bottomGrid = uigridlayout(grid, [1 3], 'ColumnWidth', {'1x', 120, 120});
    bottomGrid.Layout.Row = 3;
    lblWarnings = uilabel(bottomGrid, 'Text', '', ...
        'FontColor', [0.8 0.4 0]);
    uibutton(bottomGrid, 'Text', 'Save As', ...
        'ButtonPushedFcn', @(~,~) saveFromPreview_());
    uibutton(bottomGrid, 'Text', 'Close', ...
        'ButtonPushedFcn', @(~,~) delete(dlg));

    ddProfile.ValueChangedFcn = @(~,~) refreshPreview_();

    refreshPreview_();

    function refreshPreview_()
        profName = ddProfile.Value;
        profile = bosonPlotter.figDoc.exportProfiles(profName);
        lblDims.Text = sprintf('%.2f" x %.2f" @ %d DPI (%s)', ...
            profile.width, profile.height, profile.dpi, profile.format);

        tmpFile = [tempname '.png'];
        try
            bosonPlotter.figDoc.exportRender(datasets, activeIdx, ...
                overlayOn, model, profName, tmpFile);
            img = imread(tmpFile);
            cla(axPreview);
            image(axPreview, img);
            axPreview.XTick = [];
            axPreview.YTick = [];
            axis(axPreview, 'image');
            delete(tmpFile);
        catch ME
            cla(axPreview);
            text(axPreview, 0.5, 0.5, ['Render failed: ' ME.message], ...
                'HorizontalAlignment', 'center', 'Units', 'normalized');
        end

        warnings = checkIssues_(profile);
        lblWarnings.Text = warnings;
    end

    function saveFromPreview_()
        profName = ddProfile.Value;
        profile = bosonPlotter.figDoc.exportProfiles(profName);
        [~, fn, ~] = fileparts(datasets{activeIdx}.filepath);
        defName = fullfile(fileparts(datasets{activeIdx}.filepath), ...
            [fn '_' profName '.' profile.format]);
        [fname, fpath] = uiputfile( ...
            {['*.' profile.format], [upper(profile.format) ' files']}, ...
            'Save Export As...', defName);
        if isequal(fname, 0), return; end
        outFile = fullfile(fpath, fname);
        bosonPlotter.figDoc.exportRender(datasets, activeIdx, ...
            overlayOn, model, profName, outFile);
        bosonPlotter.quietAlert(dlg, sprintf('Saved: %s', outFile), 'Exported');
    end

    function w = checkIssues_(profile)
        issues = {};
        if profile.fontSize < 8
            issues{end+1} = 'Font <8pt (may be hard to read)';
        end
        if profile.lineWidth < 0.5
            issues{end+1} = 'Lines <0.5pt (may not reproduce well)';
        end
        if profile.dpi < 150
            issues{end+1} = 'Low DPI (<150)';
        end
        if isempty(issues)
            w = '';
        else
            w = strjoin(issues, ' | ');
        end
    end
end
