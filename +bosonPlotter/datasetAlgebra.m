function datasetAlgebra(appData, fig, callbacks)
%DATASETALGEBRA  Open dialog to combine two datasets arithmetically.
%
%   Syntax:
%     bosonPlotter.datasetAlgebra(appData, fig, callbacks)
%
%   Inputs:
%     appData   - shared application state struct (handle)
%     fig       - parent uifigure (for uialert)
%     callbacks - struct with function handles:
%       .BTN_PRIMARY                - [r g b] color for primary buttons
%       .BTN_FG                     - [r g b] foreground color for buttons
%       .getPlotDataFn              - @(idx) → data struct
%       .buildDsFn                  - @(fp, data, parserName) → ds
%       .rebuildDatasetListFn       - @(keepActiveIdx)
%       .updateControlsForActiveFn  - @()
%       .onPlotFn                   - @() trigger re-plot
%       .setStatusFn                - @(msg) update status bar
%
%   Description:
%     Opens a uifigure dialog allowing the user to select two datasets and
%     an arithmetic operation (A-B, A+B, A/B, A*B, (A-B)/(A+B)).  Interpolates
%     dataset B onto dataset A's x-grid if needed, then adds the result as a
%     new virtual dataset.

% ════════════════════════════════════════════════════════════════════════

    if isempty(appData.datasets) || numel(appData.datasets) < 2
        uialert(fig, 'Load at least two files to use dataset math.', 'Need 2+ datasets');
        return;
    end

    BTN_PRIMARY = callbacks.BTN_PRIMARY;
    BTN_FG      = callbacks.BTN_FG;

    nDS = numel(appData.datasets);
    dsNames = cell(1, nDS);
    for ii = 1:nDS
        [~, fn, fx] = fileparts(appData.datasets{ii}.filepath);
        dsNames{ii} = [fn, fx];
    end

    % ── Build dialog ───────────────────────────────────────────────────────
    mathFig = uifigure('Name', 'Dataset Math', 'Position', [350 300 420 280], 'Resize', 'off');
    mGL = uigridlayout(mathFig, [7 2], ...
        'RowHeight', {22, 22, 22, 22, 22, 22, 30}, ...
        'ColumnWidth', {110, '1x'}, ...
        'Padding', [10 10 10 10], 'RowSpacing', 6);

    uilabel(mGL, 'Text', 'Dataset A:', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
    ddMathA = uidropdown(mGL, 'Items', dsNames, 'ItemsData', 1:nDS, ...
        'Value', min(1, nDS));

    uilabel(mGL, 'Text', 'Channel A:', 'HorizontalAlignment', 'right');
    ddMathChA = uidropdown(mGL, 'Items', appData.datasets{1}.data.labels, ...
        'ItemsData', 1:numel(appData.datasets{1}.data.labels), 'Value', 1);

    uilabel(mGL, 'Text', 'Dataset B:', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
    ddMathB = uidropdown(mGL, 'Items', dsNames, 'ItemsData', 1:nDS, ...
        'Value', min(2, nDS));

    uilabel(mGL, 'Text', 'Channel B:', 'HorizontalAlignment', 'right');
    ddMathChB = uidropdown(mGL, 'Items', appData.datasets{min(2,nDS)}.data.labels, ...
        'ItemsData', 1:numel(appData.datasets{min(2,nDS)}.data.labels), 'Value', 1);

    uilabel(mGL, 'Text', 'Operation:', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
    ddMathOp = uidropdown(mGL, 'Items', {'A-B', 'A+B', 'A/B', 'A*B', '(A-B)/(A+B)'}, ...
        'Value', 'A-B');

    uilabel(mGL, 'Text', 'Interpolation:', 'HorizontalAlignment', 'right');
    ddMathInterp = uidropdown(mGL, 'Items', {'pchip', 'linear', 'spline'}, 'Value', 'pchip');

    % Update channel lists when dataset selection changes
    ddMathA.ValueChangedFcn = @(~,~) set(ddMathChA, ...
        'Items', appData.datasets{ddMathA.Value}.data.labels, ...
        'ItemsData', 1:numel(appData.datasets{ddMathA.Value}.data.labels), 'Value', 1);
    ddMathB.ValueChangedFcn = @(~,~) set(ddMathChB, ...
        'Items', appData.datasets{ddMathB.Value}.data.labels, ...
        'ItemsData', 1:numel(appData.datasets{ddMathB.Value}.data.labels), 'Value', 1);

    btnGL = uigridlayout(mGL, [1 2], 'ColumnWidth', {'1x', '1x'}, ...
        'Padding', [0 0 0 0], 'ColumnSpacing', 8);
    btnGL.Layout.Row = 7; btnGL.Layout.Column = [1 2];

    uibutton(btnGL, 'Text', 'Compute', ...
        'BackgroundColor', BTN_PRIMARY, 'FontColor', BTN_FG, ...
        'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) doMathCompute());
    uibutton(btnGL, 'Text', 'Cancel', ...
        'ButtonPushedFcn', @(~,~) delete(mathFig));

    % ── Compute callback ───────────────────────────────────────────────────
    function doMathCompute()
        try
            idxA = ddMathA.Value;  idxB = ddMathB.Value;
            dsA = callbacks.getPlotDataFn(idxA);
            dsB = callbacks.getPlotDataFn(idxB);
            result = utilities.datasetAlgebra(dsA, dsB, ddMathOp.Value, ...
                'ChannelA', ddMathChA.Value, 'ChannelB', ddMathChB.Value, ...
                'InterpMethod', ddMathInterp.Value);

            % Add result as a new virtual dataset
            newDS = struct();
            newDS.data     = result;
            newDS.corrData = [];
            newDS.filepath = sprintf('[Math: %s %s %s]', dsNames{idxA}, ddMathOp.Value, dsNames{idxB});
            newDS.xOff = 0; newDS.yOff = 0;
            newDS.bgSlope = 0; newDS.bgInt = 0;
            newDS.smoothEnabled = false; newDS.smoothWindow = 5; newDS.smoothMethod = 'Moving';
            newDS.xTrimMin = NaN; newDS.xTrimMax = NaN;
            newDS.normMethod = 'None'; newDS.derivativeMode = 'None';
            newDS.peaks = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
                                 'fitCurve',{},'status',{},'dSpacing',{});
            newDS.axLims = struct('xMin','','xMax','','xStep','', ...
                                  'yMin','','yMax','','yStep','', ...
                                  'y2Min','','y2Max','','y2Step','');
            newDS.parserName = 'datasetAlgebra';

            appData.datasets{end+1} = newDS;
            appData.activeIdx = numel(appData.datasets);
            callbacks.rebuildDatasetListFn(true);
            callbacks.updateControlsForActiveFn();
            callbacks.onPlotFn();
            delete(mathFig);
            callbacks.setStatusFn(sprintf('Math result added: %s', ddMathOp.Value));
        catch ME
            uialert(mathFig, ME.message, 'Math Error');
        end
    end
end
