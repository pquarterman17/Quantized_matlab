function graphDigitizer(options)
%GRAPHDIGITIZER  Standalone graph digitizer dialog.
%
%   Syntax:
%     bosonPlotter.graphDigitizer()
%     bosonPlotter.graphDigitizer('LoadCallback', @myFcn)
%     bosonPlotter.graphDigitizer('LoadCallback', @myFcn, 'StatusFcn', @setStatus, ...
%                                'ButtonColors', struct('primary', c1, 'tool', c2, 'fg', c3))
%
%   Inputs (name-value):
%     LoadCallback  - function_handle  Called with (data) when user clicks
%                                      "Load as Dataset". data is a unified
%                                      parser struct from parser.createDataStruct.
%                                      If empty, the button shows an alert.
%     StatusFcn     - function_handle  Called with (msg) to relay status text
%                                      to a parent GUI. Default: no-op.
%     ButtonColors  - struct           Fields: .primary, .tool, .fg — RGB row
%                                      vectors for button theming.
%                                      Default: green primary, dark-gray tool.
%
%   Workflow:
%     1. Load a graph image (PNG/JPG/TIFF screenshot of a figure)
%     2. Set axis calibration by clicking 4 reference points with known values
%        (order: X1-left, X2-right, Y1-bottom, Y2-top)
%     3. Click on data points — pixel coords are converted to data coords
%        via linear calibration
%     4. Export extracted points as CSV, or pass them to LoadCallback
%
%   Examples:
%     % Standalone use — no callback
%     bosonPlotter.graphDigitizer()
%
%     % Integrated with BosonPlotter
%     bosonPlotter.graphDigitizer('LoadCallback', @myLoadFcn, ...
%         'StatusFcn', @setStatus)

% ════════════════════════════════════════════════════════════════════════════
arguments
    options.LoadCallback function_handle = function_handle.empty
    options.StatusFcn    function_handle = @(~) []
    options.ButtonColors struct = struct( ...
        'primary', [0.18 0.52 0.18], ...
        'tool',    [0.28 0.28 0.28], ...
        'fg',      [1 1 1])
end

% ── Resolve colors ────────────────────────────────────────────────────────
BTN_PRIMARY = options.ButtonColors.primary;
BTN_FG      = options.ButtonColors.fg;

% ── Build dialog ──────────────────────────────────────────────────────────
digFig = uifigure('Name', 'Graph Digitizer', ...
    'Position', [150 80 820 620], 'Resize', 'on');

digRootGL = uigridlayout(digFig, [1 2], ...
    'ColumnWidth', {'1x', 250}, ...
    'Padding', [4 4 4 4], 'ColumnSpacing', 6);

% Left: image axes
digAxPanel = uipanel(digRootGL, 'Title', 'Graph Image');
digAxPanel.Layout.Column = 1;
digAxGL = uigridlayout(digAxPanel, [1 1], 'Padding', [2 2 2 2]);
digAx = uiaxes(digAxGL);
digAx.Box = 'on';
digAx.XTick = []; digAx.YTick = [];
title(digAx, 'Load a graph image to begin', 'Interpreter', 'none');

% Right: controls panel
ctrlPanel = uipanel(digRootGL, 'Title', 'Controls');
ctrlPanel.Layout.Column = 2;
ctrlGL = uigridlayout(ctrlPanel, [16 2], ...
    'RowHeight', {28, 6, 18, 24, 24, 24, 24, 6, 18, 28, 28, 6, '1x', 28, 28, 28}, ...
    'ColumnWidth', {'1x', '1x'}, ...
    'Padding', [6 4 6 4], 'RowSpacing', 3);

% Row 1: Load image
btnDigLoad = uibutton(ctrlGL, 'Text', 'Load Image', ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~,~) digLoadImage());
btnDigLoad.Layout.Row = 1; btnDigLoad.Layout.Column = [1 2];

% Row 3: Calibration header
uilabel(ctrlGL, 'Text', 'AXIS CALIBRATION', 'FontSize', 9, ...
    'FontWeight', 'bold', 'FontColor', [0.5 0.5 0.5]).Layout.Row = 3;

% Row 4-7: Reference point values
uilabel(ctrlGL, 'Text', 'X1 value:', 'HorizontalAlignment', 'right');
efDigX1 = uieditfield(ctrlGL, 'numeric', 'Value', 0);
efDigX1.Layout.Row = 4; efDigX1.Layout.Column = 2;

uilabel(ctrlGL, 'Text', 'X2 value:', 'HorizontalAlignment', 'right');
efDigX2 = uieditfield(ctrlGL, 'numeric', 'Value', 100);
efDigX2.Layout.Row = 5; efDigX2.Layout.Column = 2;

uilabel(ctrlGL, 'Text', 'Y1 value:', 'HorizontalAlignment', 'right');
efDigY1 = uieditfield(ctrlGL, 'numeric', 'Value', 0);
efDigY1.Layout.Row = 6; efDigY1.Layout.Column = 2;

uilabel(ctrlGL, 'Text', 'Y2 value:', 'HorizontalAlignment', 'right');
efDigY2 = uieditfield(ctrlGL, 'numeric', 'Value', 100);
efDigY2.Layout.Row = 7; efDigY2.Layout.Column = 2;

% Row 9: Mode header
uilabel(ctrlGL, 'Text', 'MODE', 'FontSize', 9, ...
    'FontWeight', 'bold', 'FontColor', [0.5 0.5 0.5]).Layout.Row = 9;

% Row 10-11: Mode buttons
btnDigCalibrate = uibutton(ctrlGL, 'Text', 'Set Axes (4 clicks)', ...
    'BackgroundColor', [0.6 0.4 0.1], 'FontColor', [1 1 1], ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~,~) digStartCalibration(), ...
    'Tooltip', 'Click 4 points: X1-left, X2-right, Y1-bottom, Y2-top');
btnDigCalibrate.Layout.Row = 10; btnDigCalibrate.Layout.Column = [1 2];

btnDigCollect = uibutton(ctrlGL, 'Text', 'Collect Points (click)', ...
    'BackgroundColor', [0.15 0.45 0.75], 'FontColor', [1 1 1], ...
    'FontWeight', 'bold', ...
    'Enable', 'off', ...
    'ButtonPushedFcn', @(~,~) digStartCollection(), ...
    'Tooltip', 'Click on data points in the graph — coordinates computed from calibration');
btnDigCollect.Layout.Row = 11; btnDigCollect.Layout.Column = [1 2];

% Row 13: Points table
tblDigPts = uitable(ctrlGL, ...
    'ColumnName', {'X', 'Y'}, ...
    'Data', {}, ...
    'ColumnEditable', [true true], ...
    'ColumnFormat', {'numeric', 'numeric'}, ...
    'FontSize', 9);
tblDigPts.Layout.Row = 13; tblDigPts.Layout.Column = [1 2];

% Row 14: Undo last / Clear all
btnDigUndo = uibutton(ctrlGL, 'Text', 'Undo Last', ...
    'ButtonPushedFcn', @(~,~) digUndoLast());
btnDigUndo.Layout.Row = 14; btnDigUndo.Layout.Column = 1;

btnDigClear = uibutton(ctrlGL, 'Text', 'Clear All', ...
    'BackgroundColor', [0.55 0.15 0.15], 'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @(~,~) digClearPoints());
btnDigClear.Layout.Row = 14; btnDigClear.Layout.Column = 2;

% Row 15: Export CSV
btnDigExport = uibutton(ctrlGL, 'Text', 'Export CSV', ...
    'BackgroundColor', [0.15 0.45 0.75], 'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @(~,~) digExportCSV());
btnDigExport.Layout.Row = 15; btnDigExport.Layout.Column = 1;

% Row 16: Load into BosonPlotter (via callback)
btnDigToDP = uibutton(ctrlGL, 'Text', 'Load as Dataset', ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
    'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~,~) digLoadAsDataset());
btnDigToDP.Layout.Row = 16; btnDigToDP.Layout.Column = [1 2];

% ── Digitizer state ───────────────────────────────────────────────────────
digState = struct();
digState.imgLoaded  = false;
digState.imgData    = [];       % [H x W x 3] uint8
digState.calibrated = false;
% Calibration: pixel coords of 4 reference points
digState.refPx      = zeros(4, 2);  % [x1px y1px; x2px y2px; ...]
digState.refClicks  = 0;        % 0–4 during calibration
digState.mode       = 'idle';   % 'idle' | 'calibrate' | 'collect'
% Extracted data points
digState.pts        = [];       % [N x 2] data coordinates
digState.ptsPx      = [];       % [N x 2] pixel coordinates
digState.markers    = {};       % graphics handles for point markers

% ════════════════════════════════════════════════════════════════════════════
% Nested helper functions
% ════════════════════════════════════════════════════════════════════════════

    function digLoadImage()
        [fn2, fp2] = uigetfile( ...
            {'*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp', 'Image Files'}, ...
            'Load Graph Image');
        if isequal(fn2, 0), return; end
        imgPath = fullfile(fp2, fn2);
        try
            digState.imgData    = imread(imgPath);
            digState.imgLoaded  = true;
            digState.calibrated = false;
            digState.refClicks  = 0;
            digState.pts        = [];
            digState.ptsPx      = [];
            digState.markers    = {};

            cla(digAx);
            image(digAx, digState.imgData);
            axis(digAx, 'image');
            digAx.XTick = []; digAx.YTick = [];
            title(digAx, fn2, 'Interpreter', 'none');
            digAx.YDir = 'reverse';  % image convention
        catch ME
            uialert(digFig, sprintf('Failed to load image:\n%s', ME.message), 'Error');
        end
    end

    function digStartCalibration()
        if ~digState.imgLoaded
            uialert(digFig, 'Load an image first.', 'Calibrate');
            return;
        end
        digState.mode      = 'calibrate';
        digState.refClicks = 0;
        digState.calibrated = false;
        btnDigCollect.Enable = 'off';
        title(digAx, 'Click X1 (left axis reference point)', 'Color', [0.8 0.4 0]);

        digAx.ButtonDownFcn = @digOnAxesClick;
        % Make image click-through so axes gets the click
        imgs = findobj(digAx, 'Type', 'image');
        for ii = 1:numel(imgs)
            imgs(ii).HitTest = 'off';
        end
    end

    function digStartCollection()
        if ~digState.calibrated
            uialert(digFig, 'Calibrate axes first.', 'Collect');
            return;
        end
        digState.mode = 'collect';
        title(digAx, 'Click on data points (Esc to stop)', 'Color', [0.2 0.5 0.8]);

        digAx.ButtonDownFcn = @digOnAxesClick;
        imgs = findobj(digAx, 'Type', 'image');
        for ii = 1:numel(imgs)
            imgs(ii).HitTest = 'off';
        end
    end

    function digOnAxesClick(~, ~)
        cp = digAx.CurrentPoint;
        px = cp(1, 1);   % pixel x
        py = cp(1, 2);   % pixel y

        switch digState.mode
            case 'calibrate'
                digState.refClicks = digState.refClicks + 1;
                digState.refPx(digState.refClicks, :) = [px, py];

                % Mark calibration point
                hold(digAx, 'on');
                plot(digAx, px, py, 's', 'MarkerSize', 10, 'LineWidth', 2, ...
                    'Color', [0.9 0.5 0], 'MarkerFaceColor', [1 0.8 0.2], ...
                    'HandleVisibility', 'off', 'Tag', 'digCalibMark');
                hold(digAx, 'off');

                prompts = {'Click X2 (right axis reference point)', ...
                           'Click Y1 (bottom axis reference point)', ...
                           'Click Y2 (top axis reference point)', ...
                           'Calibration complete!'};
                if digState.refClicks < 4
                    title(digAx, prompts{digState.refClicks}, 'Color', [0.8 0.4 0]);
                else
                    % Calibration done
                    digState.calibrated = true;
                    digState.mode       = 'idle';
                    digAx.ButtonDownFcn = [];
                    btnDigCollect.Enable = 'on';
                    title(digAx, 'Calibrated — click "Collect Points" to begin', ...
                        'Color', [0.2 0.7 0.2]);
                end

            case 'collect'
                % Convert pixel coords to data coords
                [dx, dy] = digPixelToData(px, py);
                if isnan(dx) || isnan(dy), return; end

                digState.pts(end+1, :)   = [dx, dy];
                digState.ptsPx(end+1, :) = [px, py];

                % Draw marker
                hold(digAx, 'on');
                hM = plot(digAx, px, py, 'r+', 'MarkerSize', 10, 'LineWidth', 1.5, ...
                    'HandleVisibility', 'off', 'Tag', 'digDataMark');
                hold(digAx, 'off');
                digState.markers{end+1} = hM;

                % Update table
                tblDigPts.Data = num2cell(digState.pts);
                title(digAx, sprintf('%d points collected', size(digState.pts, 1)), ...
                    'Color', [0.2 0.5 0.8]);
        end
    end

    function [dx, dy] = digPixelToData(px, py)
    %DIGPIXELTODATA  Convert pixel coordinates to data coordinates.
    %   Uses linear mapping derived from the 4 calibration reference points.
        if ~digState.calibrated
            dx = NaN; dy = NaN; return;
        end

        % Reference pixel positions
        x1px = digState.refPx(1, 1);  % X1 left
        x2px = digState.refPx(2, 1);  % X2 right
        y1px = digState.refPx(3, 2);  % Y1 bottom
        y2px = digState.refPx(4, 2);  % Y2 top

        % Reference data values
        x1val = efDigX1.Value;
        x2val = efDigX2.Value;
        y1val = efDigY1.Value;
        y2val = efDigY2.Value;

        % Linear interpolation
        if abs(x2px - x1px) < 1, dx = NaN; return; end
        if abs(y2px - y1px) < 1, dy = NaN; return; end

        dx = x1val + (px - x1px) / (x2px - x1px) * (x2val - x1val);
        dy = y1val + (py - y1px) / (y2px - y1px) * (y2val - y1val);
    end

    function digUndoLast()
        if isempty(digState.pts), return; end
        digState.pts(end, :)   = [];
        digState.ptsPx(end, :) = [];
        if ~isempty(digState.markers)
            hM = digState.markers{end};
            if isvalid(hM), delete(hM); end
            digState.markers(end) = [];
        end
        tblDigPts.Data = num2cell(digState.pts);
        title(digAx, sprintf('%d points collected', size(digState.pts, 1)), ...
            'Color', [0.2 0.5 0.8]);
    end

    function digClearPoints()
        digState.pts   = [];
        digState.ptsPx = [];
        for mi = 1:numel(digState.markers)
            if isvalid(digState.markers{mi})
                delete(digState.markers{mi});
            end
        end
        digState.markers = {};
        tblDigPts.Data   = {};
        title(digAx, 'Points cleared', 'Color', [0.5 0.5 0.5]);
    end

    function digExportCSV()
        if isempty(digState.pts)
            uialert(digFig, 'No points to export.', 'Export');
            return;
        end
        [fn2, fp2] = uiputfile({'*.csv', 'CSV (*.csv)'}, 'Export Digitized Points');
        if isequal(fn2, 0), return; end
        outPath = fullfile(fp2, fn2);
        T2 = array2table(digState.pts, 'VariableNames', {'X', 'Y'});
        writetable(T2, outPath);
        options.StatusFcn(sprintf('Digitized %d points exported to %s', ...
            size(digState.pts, 1), fn2));
    end

    function digLoadAsDataset()
        if isempty(digState.pts)
            uialert(digFig, 'No points to load.', 'Load');
            return;
        end
        if isempty(options.LoadCallback)
            uialert(digFig, ...
                'No LoadCallback was provided. Use graphDigitizer(''LoadCallback'', @yourFcn) to enable this button.', ...
                'Load as Dataset');
            return;
        end

        % Sort by X
        sorted = sortrows(digState.pts, 1);

        % Build unified data struct via parser.createDataStruct
        data = parser.createDataStruct( ...
            sorted(:, 1), ...
            sorted(:, 2), ...
            {'Digitized Y'}, ...
            {'a.u.'}, ...
            struct('source', 'Graph Digitizer', 'parserName', 'digitizer'));

        % Delegate to caller — caller adds the dataset to its own state
        options.LoadCallback(data);
        options.StatusFcn(sprintf('Loaded %d digitized points as new dataset', size(sorted, 1)));
        delete(digFig);
    end

end
