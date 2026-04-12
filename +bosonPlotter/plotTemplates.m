function plotTemplates(appData, fig, ui, callbacks)
%PLOTTEMPLATES  Save or load plot formatting presets.
%
% Syntax
%   bosonPlotter.plotTemplates(appData, fig, ui, callbacks)
%
% Inputs
%   appData   - bosonPlotter.AppState handle (read: datasets, activeIdx)
%   fig       - Main BosonPlotter figure handle (for uialert parent)
%   ui        - Widget handle struct built in BosonPlotter initialisation
%   callbacks - Struct of function handles:
%                 .onApplyCorrections()
%                 .setStatus(msg)
%                 .logGUIError(title, msg, ME)
%                 .getLastDir()               — returns appData.lastDir string
%                 .BTN_PRIMARY                — colour [r g b]
%                 .BTN_TOOL                   — colour [r g b]
%                 .BTN_FG                     — colour [r g b]
%
% Notes
%   Template format: .mat file with struct fields matching the widget values
%   saved from the active dataset.  doSaveTemplate / doLoadTemplate are
%   implemented as nested-to-this-file sub-functions sharing the tplFig handle.

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig, 'Load a file first.', 'No data'); return;
    end

    tplFig = uifigure('Name', 'Plot Templates', 'Position', [350 300 360 260], 'Resize', 'off');
    tplGL = uigridlayout(tplFig, [4 2], ...
        'RowHeight', {30, 30, 30, '1x'}, 'ColumnWidth', {'1x', '1x'}, ...
        'Padding', [15 15 15 15], 'RowSpacing', 10);

    uibutton(tplGL, 'Text', 'Save Template...', ...
        'BackgroundColor', callbacks.BTN_PRIMARY, 'FontColor', callbacks.BTN_FG, ...
        'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) doSaveTemplate());
    uibutton(tplGL, 'Text', 'Load Template...', ...
        'BackgroundColor', callbacks.BTN_TOOL, 'FontColor', callbacks.BTN_FG, ...
        'FontWeight', 'bold', ...
        'ButtonPushedFcn', @(~,~) doLoadTemplate());

    uibutton(tplGL, 'Text', 'Delete Template...', ...
        'ButtonPushedFcn', @(~,~) doDeleteTemplate());
    uibutton(tplGL, 'Text', 'Cancel', ...
        'ButtonPushedFcn', @(~,~) delete(tplFig));

    btnBatchApply = uibutton(tplGL, 'Text', 'Batch Apply...', ...
        'BackgroundColor', [0.18 0.55 0.34], 'FontColor', callbacks.BTN_FG, ...
        'FontWeight', 'bold', ...
        'Tooltip', 'Apply a saved template to a folder of files (import + correct + export CSV)', ...
        'ButtonPushedFcn', @(~,~) doBatchApplyTemplate());
    btnBatchApply.Layout.Row = 3; btnBatchApply.Layout.Column = [1 2];

    lblInfo = uilabel(tplGL, 'Text', ...
        ['Templates save corrections, normalization, labels, and scale settings. ' ...
         'Use "Batch Apply" to process a folder of files with the same pipeline.'], ...
        'WordWrap', 'on', 'FontSize', 9, 'FontColor', [0.4 0.4 0.4]);
    lblInfo.Layout.Row = 4; lblInfo.Layout.Column = [1 2];

    % ── Sub-function: Save Template ────────────────────────────────────────

    function doSaveTemplate()
        [fname, fpath] = uiputfile('*.mat', 'Save Plot Template');
        if isequal(fname, 0), return; end

        ds = appData.datasets{appData.activeIdx};
        tpl = struct();
        % Axis limits
        tpl.xMin = ui.efXMin.Value; tpl.xMax = ui.efXMax.Value; tpl.xStep = ui.efXStep.Value;
        tpl.yMin = ui.efYMin.Value; tpl.yMax = ui.efYMax.Value; tpl.yStep = ui.efYStep.Value;
        % Corrections
        tpl.xOff = ds.xOff; tpl.yOff = ds.yOff;
        tpl.bgSlope = ds.bgSlope; tpl.bgInt = ds.bgInt;
        tpl.smoothEnabled = ds.smoothEnabled;
        tpl.smoothWindow = ds.smoothWindow;
        tpl.smoothMethod = ds.smoothMethod;
        tpl.normMethod = ds.normMethod;
        tpl.derivativeMode = ds.derivativeMode;
        tpl.xTrimMin = ds.xTrimMin; tpl.xTrimMax = ds.xTrimMax;
        % Labels (axis appearance overrides)
        tpl.plotTitle = ui.efCustomTitle.Value;
        tpl.xLabel = ui.efCustomXLabel.Value;
        tpl.yLabel = ui.efCustomYLabel.Value;
        % Scale
        tpl.xScale = 'linear';  % resolved from ddScaleX at save time is not stored;
                                 % use axes X/Y scale from the format selector if available
        tpl.yScale = 'linear';
        % Tick format
        tpl.xTickFormat = ui.ddXFmt.Value;
        tpl.yTickFormat = ui.ddYFmt.Value;

        save(fullfile(fpath, fname), '-struct', 'tpl');
        callbacks.setStatus(sprintf('Template saved: %s', fname));
    end

    % ── Sub-function: Load Template ────────────────────────────────────────

    function doLoadTemplate()
        [fname, fpath] = uigetfile('*.mat', 'Load Plot Template');
        if isequal(fname, 0), return; end

        tpl = load(fullfile(fpath, fname));
        ds = appData.datasets{appData.activeIdx};

        % Apply corrections
        if isfield(tpl, 'xOff'), ui.efXOffset.Value = tpl.xOff; ds.xOff = tpl.xOff; end
        if isfield(tpl, 'yOff'), ui.efYOffset.Value = tpl.yOff; ds.yOff = tpl.yOff; end
        if isfield(tpl, 'bgSlope'), ui.efBGSlope.Value = tpl.bgSlope; ds.bgSlope = tpl.bgSlope; end
        if isfield(tpl, 'bgInt'), ui.efBGIntercept.Value = tpl.bgInt; ds.bgInt = tpl.bgInt; end
        if isfield(tpl, 'smoothEnabled'), ui.cbSmooth.Value = tpl.smoothEnabled; ds.smoothEnabled = tpl.smoothEnabled; end
        if isfield(tpl, 'smoothWindow'), ui.efSmoothWin.Value = tpl.smoothWindow; ds.smoothWindow = tpl.smoothWindow; end
        if isfield(tpl, 'smoothMethod'), ui.ddSmoothMethod.Value = tpl.smoothMethod; ds.smoothMethod = tpl.smoothMethod; end
        if isfield(tpl, 'normMethod'), ui.ddNormalize.Value = tpl.normMethod; ds.normMethod = tpl.normMethod; end
        if isfield(tpl, 'derivativeMode'), ui.ddDerivative.Value = tpl.derivativeMode; ds.derivativeMode = tpl.derivativeMode; end
        if isfield(tpl, 'xTrimMin') && ~isnan(tpl.xTrimMin), ui.efXTrimMin.Value = num2str(tpl.xTrimMin); end
        if isfield(tpl, 'xTrimMax') && ~isnan(tpl.xTrimMax), ui.efXTrimMax.Value = num2str(tpl.xTrimMax); end

        % Apply axis limits
        if isfield(tpl, 'xMin'), ui.efXMin.Value = tpl.xMin; end
        if isfield(tpl, 'xMax'), ui.efXMax.Value = tpl.xMax; end
        if isfield(tpl, 'xStep'), ui.efXStep.Value = tpl.xStep; end
        if isfield(tpl, 'yMin'), ui.efYMin.Value = tpl.yMin; end
        if isfield(tpl, 'yMax'), ui.efYMax.Value = tpl.yMax; end
        if isfield(tpl, 'yStep'), ui.efYStep.Value = tpl.yStep; end

        % Apply labels (axis appearance overrides)
        if isfield(tpl, 'plotTitle'), ui.efCustomTitle.Value = tpl.plotTitle; end
        if isfield(tpl, 'xLabel'), ui.efCustomXLabel.Value = tpl.xLabel; end
        if isfield(tpl, 'yLabel'), ui.efCustomYLabel.Value = tpl.yLabel; end

        % Apply tick formats
        if isfield(tpl, 'xTickFormat'), ui.ddXFmt.Value = tpl.xTickFormat; end
        if isfield(tpl, 'yTickFormat'), ui.ddYFmt.Value = tpl.yTickFormat; end

        appData.datasets{appData.activeIdx} = ds;

        % Re-apply corrections and replot
        callbacks.onApplyCorrections();
        callbacks.setStatus(sprintf('Template loaded: %s', fname));
        delete(tplFig);
    end

    % ── Sub-function: Delete Template ─────────────────────────────────────

    function doDeleteTemplate()
        [fname, fpath] = uigetfile('*.mat', 'Delete Plot Template');
        if isequal(fname, 0), return; end
        delete(fullfile(fpath, fname));
        callbacks.setStatus(sprintf('Template deleted: %s', fname));
    end

    % ── Sub-function: Batch Apply Template ────────────────────────────────

    function doBatchApplyTemplate()
    %DOBATCHAPPLYTEMPLATE  Pick a template + folder, run analysis pipeline.
        % Select template
        [tplName, tplPath] = uigetfile('*.mat', 'Select Template to Apply');
        if isequal(tplName, 0), return; end
        tplFile = fullfile(tplPath, tplName);

        % Select input folder
        startDir = callbacks.getLastDir();
        inputDir = uigetdir(startDir, 'Select folder of data files');
        if isequal(inputDir, 0), return; end

        % Select output folder
        outputDir = uigetdir(inputDir, 'Select output folder for corrected CSVs');
        if isequal(outputDir, 0), return; end

        callbacks.setStatus('Batch applying template...');
        delete(tplFig);
        drawnow;

        try
            res = scripts.applyAnalysisTemplate(tplFile, inputDir, ...
                'OutputDir', outputDir, 'Recursive', true, ...
                'ExportCSV', true, 'ExportPeaks', false);
            nOk  = sum(cellfun(@isempty, {res.error}));
            nErr = numel(res) - nOk;
            msg = sprintf('Batch complete: %d processed, %d failed.\nOutput: %s', ...
                nOk, nErr, outputDir);
            callbacks.setStatus(sprintf('Batch template: %d ok, %d failed', nOk, nErr));
            uialert(fig, msg, 'Batch Apply Complete');
        catch ME
            callbacks.setStatus('Batch apply failed.');
            callbacks.logGUIError('Batch Apply Error', ME.message, ME);
            uialert(fig, sprintf('Batch apply failed:\n%s', ME.message), ...
                'Batch Apply Error');
        end
    end

end
