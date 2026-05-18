function hysteresisDialog(datasets, activeIdx, mainAx, options)
%HYSTERESISDIALOG  Interactive hysteresis loop analysis dialog.
%
%   bosonPlotter.hysteresisDialog(datasets, activeIdx, mainAx)
%
%   Analyzes M(H) loops: auto-detects branches, extracts Hc, Mr, Ms,
%   squareness, SFD, loop area. Displays branch-colored plot with
%   analysis markers and dM/dH subplot.
%
%   Workshop pattern (MASTERPLAN W5 #61): the algorithmic state +
%   helpers live in `+bosonPlotter/+hysteresis/HysteresisWorkshopModel`.
%   This dialog is now a thin view: builds widgets, wires Analyze /
%   Plot / Copy / Export to model methods. Algorithm itself stays in
%   `utilities.hysteresisAnalysis`.

arguments
    datasets   cell
    activeIdx  double
    mainAx
    options.StatusFcn      function_handle = @(~) []
    options.ButtonColors   struct = struct( ...
        'primary', [0.15 0.45 0.75], ...
        'tool',    [0.22 0.22 0.28], ...
        'fg',      [0.95 0.95 0.95])
end

% ════════════════════════════════════════════════════════════════════════
% Resolve data + construct model
% ════════════════════════════════════════════════════════════════════════

if isempty(datasets) || activeIdx < 1 || activeIdx > numel(datasets)
    error('bosonPlotter:hysteresisDialog:noDataset', 'No valid dataset.');
end
ds = datasets{activeIdx};
if ~isempty(ds.corrData) && ~isempty(ds.corrData.time)
    plotD = ds.corrData;
else
    plotD = ds.data;
end
labels = plotD.labels;

model = bosonPlotter.hysteresis.HysteresisWorkshopModel();
model.bindFromDataset(ds);

BTN_PRIMARY = options.ButtonColors.primary;
BTN_TOOL    = options.ButtonColors.tool;
BTN_FG      = options.ButtonColors.fg;

% ════════════════════════════════════════════════════════════════════════
% Build dialog
% ════════════════════════════════════════════════════════════════════════

hFig = uifigure('Name', 'Hysteresis Loop Analysis', ...
    'Position', [180 60 780 700], 'Resize', 'on');

rootGL = uigridlayout(hFig, [6 1], ...
    'RowHeight', {52, 30, '2x', '1x', 'fit', 28}, ...
    'Padding', [8 6 8 6], 'RowSpacing', 5);

% ── Row 1: Channel selection ─────────────────────────────────────────
chGL = uigridlayout(rootGL, [2 4], ...
    'RowHeight', {22, 22}, ...
    'ColumnWidth', {65, '1x', 65, '1x'}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 3);
chGL.Layout.Row = 1;

uilabel(chGL, 'Text', 'H channel:', 'HorizontalAlignment', 'right');
allCols     = [{'X (time axis)'}, labels];
allColData  = 0:numel(labels);
ddHCh = uidropdown(chGL, 'Items', allCols, 'ItemsData', allColData, ...
    'Value', model.hChannelIdx, ...
    'ValueChangedFcn', @(s,~) setfield_(model, 'hChannelIdx', s.Value)); %#ok<SFLD>
ddHCh.Layout.Row = 1; ddHCh.Layout.Column = 2;

uilabel(chGL, 'Text', 'M channel:', 'HorizontalAlignment', 'right');
ddMCh = uidropdown(chGL, 'Items', allCols, 'ItemsData', allColData, ...
    'Value', model.mChannelIdx, ...
    'ValueChangedFcn', @(s,~) setfield_(model, 'mChannelIdx', s.Value)); %#ok<SFLD>
ddMCh.Layout.Row = 1; ddMCh.Layout.Column = 4;

uilabel(chGL, 'Text', 'Smooth:', 'HorizontalAlignment', 'right');
efSmooth = uieditfield(chGL, 'numeric', 'Value', model.preSmooth, ...
    'Tooltip', 'Pre-smoothing window (0 = none)', ...
    'ValueChangedFcn', @(s,~) setfield_(model, 'preSmooth', s.Value)); %#ok<SFLD>
efSmooth.Layout.Row = 2; efSmooth.Layout.Column = 2;

cbBgSub = uicheckbox(chGL, 'Text', 'Subtract linear BG', 'Value', model.subtractBg, ...
    'Tooltip', 'Fit and subtract high-field linear slope before analysis', ...
    'ValueChangedFcn', @(s,~) setfield_(model, 'subtractBg', s.Value)); %#ok<SFLD>
cbBgSub.Layout.Row = 2; cbBgSub.Layout.Column = [3 4];

% ── Row 2: Action buttons ────────────────────────────────────────────
btnGL = uigridlayout(rootGL, [1 5], ...
    'ColumnWidth', {'1x','1x','1x','1x','1x'}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 4);
btnGL.Layout.Row = 2;

uibutton(btnGL, 'Text', 'Analyze', 'FontWeight', 'bold', ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @(~,~) onAnalyze());
uibutton(btnGL, 'Text', 'Plot on Main', ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'ButtonPushedFcn', @(~,~) onPlotOnMain());
uibutton(btnGL, 'Text', 'Copy Results', ...
    'ButtonPushedFcn', @(~,~) onCopy());
uibutton(btnGL, 'Text', 'Export CSV', ...
    'ButtonPushedFcn', @(~,~) onExport());
uibutton(btnGL, 'Text', 'Close', ...
    'ButtonPushedFcn', @(~,~) delete(hFig));

% ── Row 3-4: Plots ───────────────────────────────────────────────────
axMH = uiaxes(rootGL); axMH.Layout.Row = 3;
title(axMH, 'M(H) Loop'); xlabel(axMH, 'H'); ylabel(axMH, 'M');
axMH.Box = 'on'; grid(axMH, 'on');

axSFD = uiaxes(rootGL); axSFD.Layout.Row = 4;
title(axSFD, 'dM/dH (Switching Field Distribution)');
xlabel(axSFD, 'H'); ylabel(axSFD, 'dM/dH');
axSFD.Box = 'on'; grid(axSFD, 'on');

% ── Row 5: Results table ────────────────────────────────────────────
tblResults = uitable(rootGL, ...
    'ColumnName', {'Parameter', 'Value', 'Unit'}, ...
    'ColumnEditable', false, ...
    'ColumnWidth', {140, 120, 80}, ...
    'Data', {}, 'FontSize', 9);
tblResults.Layout.Row = 5;

% ── Row 6: Warnings ─────────────────────────────────────────────────
lblWarnings = uilabel(rootGL, 'Text', '', ...
    'FontSize', 9, 'FontColor', [0.8 0.5 0.2]);
lblWarnings.Layout.Row = 6;

% ════════════════════════════════════════════════════════════════════════
% Nested view callbacks (drive the model + repaint)
% ════════════════════════════════════════════════════════════════════════

    function onAnalyze()
        [H, M] = model.extractHM(ds);
        hFig.Pointer = 'watch'; drawnow;
        try
            model.analyze(H, M);
            renderResultPlots();
            tblResults.Data = model.buildResultsTable();
            if ~isempty(model.warnings)
                lblWarnings.Text = strjoin(model.warnings, ' | ');
            else
                lblWarnings.Text = '';
            end
            hFig.Pointer = 'arrow';
            r = model.result;
            options.StatusFcn(sprintf('Hysteresis: Hc=%.1f Ms=%.3e Mr/Ms=%.3f', ...
                r.HcMean, r.MsMean, r.squareness));
        catch ME
            hFig.Pointer = 'arrow';
            bosonPlotter.quietAlert(hFig, sprintf('Analysis failed:\n%s', ME.message), 'Error');
        end
    end

    function renderResultPlots()
        if ~model.hasResult(), return; end
        r = model.result;

        % ── M(H) ──
        cla(axMH); hold(axMH, 'on');
        if ~isempty(r.virgin.H)
            plot(axMH, r.virgin.H, r.virgin.M, 'g-', 'LineWidth', 1, ...
                'DisplayName', 'Virgin');
        end
        if ~isempty(r.ascending.H)
            plot(axMH, r.ascending.H, r.ascending.M, 'b-', 'LineWidth', 1.2, ...
                'DisplayName', 'Ascending');
        end
        if ~isempty(r.descending.H)
            plot(axMH, r.descending.H, r.descending.M, 'r-', 'LineWidth', 1.2, ...
                'DisplayName', 'Descending');
        end
        if isfinite(r.Hc(1))
            xline(axMH, r.Hc(1), '--b', 'LineWidth', 0.8, 'HandleVisibility', 'off');
        end
        if isfinite(r.Hc(2))
            xline(axMH, r.Hc(2), '--r', 'LineWidth', 0.8, 'HandleVisibility', 'off');
        end
        if isfinite(r.Mr(1))
            yline(axMH, r.Mr(1), ':b', 'LineWidth', 0.8, 'HandleVisibility', 'off');
        end
        if isfinite(r.Mr(2))
            yline(axMH, r.Mr(2), ':r', 'LineWidth', 0.8, 'HandleVisibility', 'off');
        end
        if isfinite(r.Ms(1))
            yline(axMH, r.Ms(1), '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, ...
                'HandleVisibility', 'off');
        end
        if isfinite(r.Ms(2))
            yline(axMH, r.Ms(2), '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, ...
                'HandleVisibility', 'off');
        end
        hold(axMH, 'off');
        legend(axMH, 'Location', 'best');
        title(axMH, sprintf('M(H) — Hc = %.1f, Ms = %.3e', r.HcMean, r.MsMean));
        axMH.Box = 'on'; grid(axMH, 'on');

        % ── dM/dH ──
        cla(axSFD); hold(axSFD, 'on');
        if ~isempty(r.dMdH_asc)
            plot(axSFD, r.ascending.H, r.dMdH_asc, 'b-', 'LineWidth', 1);
        end
        if ~isempty(r.dMdH_desc)
            plot(axSFD, r.descending.H, r.dMdH_desc, 'r-', 'LineWidth', 1);
        end
        if isfinite(r.SFD.peakH)
            xline(axSFD, r.SFD.peakH, '--k', 'HandleVisibility', 'off');
        end
        hold(axSFD, 'off');
        title(axSFD, sprintf('dM/dH — SFD FWHM = %.1f', r.SFD.fwhm));
        axSFD.Box = 'on'; grid(axSFD, 'on');
    end

    function onPlotOnMain()
        if ~model.hasResult(), return; end
        r = model.result;
        hold(mainAx, 'on');
        if isfinite(r.Hc(1))
            xline(mainAx, r.Hc(1), '--b', 'LineWidth', 1, ...
                'HandleVisibility', 'off', 'Tag', 'hystMarker');
        end
        if isfinite(r.Hc(2))
            xline(mainAx, r.Hc(2), '--r', 'LineWidth', 1, ...
                'HandleVisibility', 'off', 'Tag', 'hystMarker');
        end
        if isfinite(r.Ms(1))
            yline(mainAx, r.Ms(1), '-', 'Color', [0.4 0.4 0.4], ...
                'HandleVisibility', 'off', 'Tag', 'hystMarker');
        end
        hold(mainAx, 'off');
        options.StatusFcn('Hysteresis markers overlaid on main axes');
    end

    function onCopy()
        if ~model.hasResult(), return; end
        clipboard('copy', model.buildClipboardText());
        options.StatusFcn('Hysteresis results copied to clipboard');
    end

    function onExport()
        if ~model.hasResult(), return; end
        [fn, fp] = uiputfile({'*.csv','CSV'}, 'Export Hysteresis Results');
        if isequal(fn, 0), return; end
        model.exportCSV(fullfile(fp, fn));
        options.StatusFcn(sprintf('Results exported: %s', fn));
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helper — set a property on the model from a widget callback
% (workaround: an anonymous function can't do `obj.field = val;` directly)
% ════════════════════════════════════════════════════════════════════════
function setfield_(obj, fld, val)
    obj.(fld) = val;
end
