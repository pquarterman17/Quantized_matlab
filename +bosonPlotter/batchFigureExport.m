function batchFigureExport(datasets, parentFig, getPlotDataFn, setStatusFn, btnColors)
%BATCHFIGUREEXPORT  Export each loaded dataset as an individual figure.
%
%   bosonPlotter.batchFigureExport(datasets, fig, @getPlotData, @setStatus, btnColors)
%
%   Extracted from BosonPlotter to reduce main file complexity.
%
%   Inputs:
%       datasets      - cell array of dataset structs
%       parentFig     - parent uifigure (for alerts)
%       getPlotDataFn - function handle: d = fn(dsIdx) returning corrected data
%       setStatusFn   - function handle: fn(msg)
%       btnColors     - struct with .primary, .fg fields

    if isempty(datasets)
        bosonPlotter.quietAlert(parentFig, 'Load files first.', 'No data'); return;
    end

    BTN_PRIMARY = btnColors.primary;
    BTN_FG      = btnColors.fg;

    beFig = uifigure('Name', 'Batch Figure Export', 'Position', [350 300 400 250], 'Resize', 'off');
    beGL = uigridlayout(beFig, [6 2], ...
        'RowHeight', {22, 22, 22, 22, 22, 30}, ...
        'ColumnWidth', {110, '1x'}, ...
        'Padding', [10 10 10 10], 'RowSpacing', 6);

    uilabel(beGL, 'Text', 'Format:', 'HorizontalAlignment', 'right');
    ddBEFormat = uidropdown(beGL, 'Items', {'PNG','PDF','SVG','EPS'}, 'Value', 'PNG');

    uilabel(beGL, 'Text', 'DPI (raster):', 'HorizontalAlignment', 'right');
    spBEDpi = uispinner(beGL, 'Value', 300, 'Limits', [72 1200], 'Step', 50);

    uilabel(beGL, 'Text', 'Width (in):', 'HorizontalAlignment', 'right');
    spBEW = uispinner(beGL, 'Value', 7, 'Limits', [2 20], 'Step', 0.5);

    uilabel(beGL, 'Text', 'Height (in):', 'HorizontalAlignment', 'right');
    spBEH = uispinner(beGL, 'Value', 5, 'Limits', [2 20], 'Step', 0.5);

    uilabel(beGL, 'Text', 'Template:', 'HorizontalAlignment', 'right');
    ddBETpl = uidropdown(beGL, ...
        'Items', {'None','APS (Phys Rev)','Nature','ACS'}, ...
        'Value', 'None');

    btnBEGL = uigridlayout(beGL, [1 2], 'ColumnWidth', {'1x','1x'}, ...
        'Padding', [0 0 0 0], 'ColumnSpacing', 8);
    btnBEGL.Layout.Row = 6; btnBEGL.Layout.Column = [1 2];

    uibutton(btnBEGL, 'Text', 'Export All', ...
        'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
        'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) doBatchExport());
    uibutton(btnBEGL, 'Text', 'Cancel', ...
        'ButtonPushedFcn', @(~,~) delete(beFig));

    function doBatchExport()
        outDir = uigetdir('', 'Select output folder');
        if isequal(outDir, 0), return; end

        fmt = lower(ddBEFormat.Value);
        nDS = numel(datasets);
        pb = uiprogressdlg(beFig, 'Title', 'Exporting...', 'Indeterminate', 'off');

        for ii = 1:nDS
            pb.Value = (ii-1)/nDS;
            pb.Message = sprintf('Dataset %d of %d', ii, nDS);

            ds = datasets{ii};
            d  = getPlotDataFn(ii);
            [~, fn, ~] = fileparts(ds.filepath);

            % Create temporary figure
            tmpFig = figure('Visible', 'off', 'Units', 'inches', ...
                'Position', [0 0 spBEW.Value spBEH.Value]);
            tmpAx = axes(tmpFig);
            hold(tmpAx, 'on'); box(tmpAx, 'on'); grid(tmpAx, 'on');

            % Plot all Y channels
            nCh = size(d.values, 2);
            cols = plotting.lineColors(nCh);
            for ch = 1:nCh
                plot(tmpAx, d.time, d.values(:, ch), '-', ...
                    'Color', cols(ch,:), 'LineWidth', 1.5, ...
                    'DisplayName', d.labels{ch});
            end

            % Apply template formatting
            fontSize = 10;
            fontName = 'Helvetica';
            switch ddBETpl.Value
                case 'APS (Phys Rev)', fontSize = 8; fontName = 'Times New Roman';
                case 'Nature',         fontSize = 7; fontName = 'Helvetica';
                case 'ACS',            fontSize = 8; fontName = 'Helvetica';
            end

            tmpAx.FontSize = fontSize;
            tmpAx.FontName = fontName;
            tmpAx.TickDir = 'in';

            xlabel(tmpAx, guiLabel(guiXName(d.metadata), guiXUnit(d.metadata)), 'FontSize', fontSize);
            if nCh == 1
                ylabel(tmpAx, guiLabel(d.labels{1}, d.units{min(1,numel(d.units))}), 'FontSize', fontSize);
            else
                ylabel(tmpAx, 'Intensity', 'FontSize', fontSize);
                legend(tmpAx, 'Location', 'best', 'FontSize', max(6, fontSize-2));
            end
            title(tmpAx, fn, 'FontSize', fontSize+1, 'Interpreter', 'none');

            % Save
            outPath = fullfile(outDir, [fn '.' fmt]);
            switch fmt
                case 'png'
                    exportgraphics(tmpFig, outPath, 'Resolution', spBEDpi.Value);
                case {'pdf','eps','svg'}
                    exportgraphics(tmpFig, outPath, 'ContentType', 'vector');
            end
            close(tmpFig);
        end
        close(pb);
        setStatusFn(sprintf('Exported %d figures to %s', nDS, outDir));
        delete(beFig);
    end
end


% ════════════════════════════════════════════════════════════════════════
%  Local helpers (duplicated from BosonPlotter — keep in sync)
% ════════════════════════════════════════════════════════════════════════

function name = guiXName(meta)
    if isfield(meta, 'xColumnName'), name = meta.xColumnName;
    else, name = 'X';
    end
end

function u = guiXUnit(meta)
    if isfield(meta, 'xColumnUnit'), u = meta.xColumnUnit;
    else, u = '';
    end
end

function s = guiLabel(name, unit)
    s = bosonPlotter.smartLabel(name, unit);
end
