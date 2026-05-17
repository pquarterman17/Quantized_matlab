function publishFigure(appData, fig, callbacks)
%PUBLISHFIGURE  One-click export with journal presets.
%
%   bosonPlotter.publishFigure(appData, fig, callbacks)
%
%   Opens a compact dialog with journal presets (APS, Nature, ACS, IEEE,
%   Custom).  Selecting a preset locks font, dimensions, and line widths.
%   "Publish" applies the preset and exports a vector PDF in one step.
%   Last-used settings are persisted for re-export.
%
%   Inputs
%     appData   - bosonPlotter.AppState handle
%     fig       - Main BosonPlotter figure handle
%     callbacks - Struct with:
%       .drawToAxes(targetAx) — renders the current plot into an axes
%       .setStatus(msg)       — status bar update
%       .logGUIError(t,m,ME)  — error sink

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig, 'Load a file first.', 'Publish'); return;
    end

    presets = getPresets();
    presetNames = {presets.name};

    % Load last-used settings
    lastUsed = loadLastUsed();

    % ── Build dialog ─────────────────────────────────────────────────────
    pubFig = uifigure('Name', 'Publish Figure', ...
        'Position', [400 250 380 340], 'Resize', 'off');
    gl = uigridlayout(pubFig, [9 2], ...
        'RowHeight', {26, 26, 26, 26, 26, 26, 10, 36, 22}, ...
        'ColumnWidth', {110, '1x'}, ...
        'Padding', [14 14 14 14], 'RowSpacing', 6);

    % Row 1: Preset dropdown
    uilabel(gl, 'Text', 'Journal Preset:', 'FontWeight', 'bold');
    ddPreset = uidropdown(gl, 'Items', presetNames, ...
        'Value', lastUsed.preset, ...
        'ValueChangedFcn', @(src,~) onPresetChanged(src.Value));

    % Row 2: Width
    uilabel(gl, 'Text', 'Width (in):');
    efWidth = uieditfield(gl, 'numeric', 'Value', lastUsed.width, ...
        'Limits', [0.5 20], 'ValueDisplayFormat', '%.3f');

    % Row 3: Height
    uilabel(gl, 'Text', 'Height (in):');
    efHeight = uieditfield(gl, 'numeric', 'Value', lastUsed.height, ...
        'Limits', [0.5 20], 'ValueDisplayFormat', '%.3f');

    % Row 4: Font
    uilabel(gl, 'Text', 'Font:');
    efFont = uieditfield(gl, 'text', 'Value', lastUsed.font);

    % Row 5: Font size
    uilabel(gl, 'Text', 'Font Size (pt):');
    efFontSize = uieditfield(gl, 'numeric', 'Value', lastUsed.fontSize, ...
        'Limits', [4 24]);

    % Row 6: Line width
    uilabel(gl, 'Text', 'Line Width (pt):');
    efLineWidth = uieditfield(gl, 'numeric', 'Value', lastUsed.lineWidth, ...
        'Limits', [0.25 5], 'ValueDisplayFormat', '%.2f');

    % Row 7: spacer
    uilabel(gl, 'Text', '');
    uilabel(gl, 'Text', '');

    % Row 8: Publish button
    btnPublish = uibutton(gl, 'Text', 'Publish PDF', ...
        'BackgroundColor', [0.15 0.55 0.25], 'FontColor', [1 1 1], ...
        'FontSize', 14, 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) doPublish());
    btnPublish.Layout.Column = [1 2];

    % Row 9: status
    lblStatus = uilabel(gl, 'Text', '', 'FontSize', 9, ...
        'FontColor', [0.4 0.4 0.4]);
    lblStatus.Layout.Row = 9; lblStatus.Layout.Column = [1 2];

    % Apply initial preset
    onPresetChanged(ddPreset.Value);

    % ── Nested functions ─────────────────────────────────────────────────

    function onPresetChanged(name)
        idx = find(strcmp(presetNames, name), 1);
        if isempty(idx), return; end
        p = presets(idx);
        if ~strcmp(name, 'Custom')
            efWidth.Value    = p.width;
            efHeight.Value   = p.height;
            efFont.Value     = p.font;
            efFontSize.Value = p.fontSize;
            efLineWidth.Value = p.lineWidth;
        end
    end

    function doPublish()
        w = efWidth.Value;
        h = efHeight.Value;
        fontName = efFont.Value;
        fontSize = efFontSize.Value;
        lineW    = efLineWidth.Value;

        % Suggest filename
        ds = appData.datasets{appData.activeIdx};
        [dPath, dName] = fileparts(ds.filepath);
        defPath = fullfile(dPath, [dName '_pub.pdf']);
        [fname, fpath] = uiputfile({'*.pdf','PDF vector (*.pdf)'}, ...
            'Publish as...', defPath);
        if isequal(fname, 0), return; end
        outPath = fullfile(fpath, fname);

        lblStatus.Text = 'Rendering...';
        pubFig.Pointer = 'watch'; drawnow;

        try
            tmpFig = figure('Visible', 'off', 'Name', 'Publish', ...
                'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
                'Color', 'none', ...
                'Units', 'inches', 'Position', [0 0 w h]);
            tmpAx = axes(tmpFig);
            set(tmpAx, 'Color', 'none');
            box(tmpAx, 'on');
            grid(tmpAx, 'on');
            callbacks.drawToAxes(tmpAx);

            % Apply journal formatting
            applyJournalStyle(tmpAx, fontName, fontSize, lineW);

            exportgraphics(tmpFig, outPath, 'ContentType', 'vector', ...
                'BackgroundColor', 'none');
            delete(tmpFig);

            % Persist settings
            saveLastUsed(ddPreset.Value, w, h, fontName, fontSize, lineW, outPath);
            appData.lastExportPath = outPath;

            lblStatus.Text = sprintf('Published: %s', fname);
            pubFig.Pointer = 'arrow';
            callbacks.setStatus(sprintf('Published: %s', outPath));
        catch ME
            if exist('tmpFig', 'var') && isvalid(tmpFig)
                delete(tmpFig);
            end
            pubFig.Pointer = 'arrow';
            lblStatus.Text = sprintf('Error: %s', ME.message);
            callbacks.logGUIError('Publish error', ME.message, ME);
        end
    end
end

% ════════════════════════════════════════════════════════════════════════════
% Local helpers
% ════════════════════════════════════════════════════════════════════════════

function presets = getPresets()
%GETPRESETS  Journal dimension/font presets.
    presets = struct( ...
        'name',      {'APS (PRL/PRB)', 'Nature', 'ACS', 'IEEE', 'Custom'}, ...
        'width',     {3.375,           3.503,    3.25,  3.5,    4.0}, ...
        'height',    {2.5,             2.5,      2.5,   2.5,    3.0}, ...
        'font',      {'Arial',         'Helvetica', 'Arial', 'Times New Roman', 'Arial'}, ...
        'fontSize',  {8,               7,        7,     8,      10}, ...
        'lineWidth', {1.0,             0.75,     0.75,  1.0,    1.0});
end

function applyJournalStyle(ax, fontName, fontSize, lineW)
%APPLYJOURNALSTYLE  Format axes for publication output.
    darkColor = [0.1 0.1 0.1];

    % Axes appearance
    ax.FontName  = fontName;
    ax.FontSize  = fontSize;
    ax.LineWidth = max(lineW * 0.6, 0.5);
    ax.XColor    = darkColor;
    ax.YColor    = darkColor;
    ax.TickDir   = 'in';
    ax.TickLength = [0.015 0.015];

    % Labels
    ax.XLabel.FontSize = fontSize;
    ax.XLabel.Color    = darkColor;
    ax.YLabel.FontSize = fontSize;
    ax.YLabel.Color    = darkColor;
    if ~isempty(ax.Title.String)
        ax.Title.FontSize = fontSize + 1;
        ax.Title.Color    = darkColor;
    end

    % Right Y-axis
    if isprop(ax, 'YAxis') && numel(ax.YAxis) > 1
        ax.YAxis(2).Color = darkColor;
    end

    % Data lines
    lines = findobj(ax, 'Type', 'Line');
    for i = 1:numel(lines)
        lines(i).LineWidth = lineW;
    end

    % Legend
    lgd = findobj(ancestor(ax, 'figure'), 'Type', 'Legend');
    if ~isempty(lgd)
        lgd(1).FontSize  = fontSize - 1;
        lgd(1).Color     = 'none';
        lgd(1).EdgeColor = darkColor;
        lgd(1).TextColor = darkColor;
    end
end

function s = loadLastUsed()
%LOADLASTUSED  Load persisted publish settings or return defaults.
    matPath = fullfile(prefdir, 'boson_publish_settings.mat');
    if isfile(matPath)
        tmp = load(matPath, 's');
        s = tmp.s;
    else
        s = struct('preset', 'APS (PRL/PRB)', 'width', 3.375, ...
            'height', 2.5, 'font', 'Arial', 'fontSize', 8, ...
            'lineWidth', 1.0, 'lastPath', '');
    end
end

function saveLastUsed(preset, w, h, font, fontSize, lineWidth, lastPath)
%SAVELASTUSED  Persist publish settings.
    s = struct('preset', preset, 'width', w, 'height', h, ...
        'font', font, 'fontSize', fontSize, 'lineWidth', lineWidth, ...
        'lastPath', lastPath); %#ok<NASGU>
    save(fullfile(prefdir, 'boson_publish_settings.mat'), 's');
end
