function hysteresisDialog(datasets, activeIdx, mainAx, options)
%HYSTERESISDIALOG  Interactive hysteresis loop analysis dialog.
%
%   bosonPlotter.hysteresisDialog(datasets, activeIdx, mainAx)
%
%   Analyzes M(H) loops: auto-detects branches, extracts Hc, Mr, Ms,
%   squareness, SFD, loop area. Displays branch-colored plot with
%   analysis markers and dM/dH subplot.

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
% Resolve data
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
BTN_PRIMARY = options.ButtonColors.primary;
BTN_TOOL    = options.ButtonColors.tool;
BTN_FG      = options.ButtonColors.fg;

% Auto-detect field and moment channels
[hIdx, mIdx] = autoDetectChannels(labels);

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
% Use time column (index 0) or value columns
allCols = [{'X (time axis)'}, labels];
allColData = 0:numel(labels);
ddHCh = uidropdown(chGL, 'Items', allCols, 'ItemsData', allColData, ...
    'Value', hIdx);
ddHCh.Layout.Row = 1; ddHCh.Layout.Column = 2;

uilabel(chGL, 'Text', 'M channel:', 'HorizontalAlignment', 'right');
ddMCh = uidropdown(chGL, 'Items', allCols, 'ItemsData', allColData, ...
    'Value', mIdx);
ddMCh.Layout.Row = 1; ddMCh.Layout.Column = 4;

uilabel(chGL, 'Text', 'Smooth:', 'HorizontalAlignment', 'right');
efSmooth = uieditfield(chGL, 'numeric', 'Value', 0, ...
    'Tooltip', 'Pre-smoothing window (0 = none)');
efSmooth.Layout.Row = 2; efSmooth.Layout.Column = 2;

cbBgSub = uicheckbox(chGL, 'Text', 'Subtract linear BG', 'Value', false, ...
    'Tooltip', 'Fit and subtract high-field linear slope before analysis');
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

% ── Row 3: M(H) plot ────────────────────────────────────────────────
axMH = uiaxes(rootGL);
axMH.Layout.Row = 3;
title(axMH, 'M(H) Loop'); xlabel(axMH, 'H'); ylabel(axMH, 'M');
axMH.Box = 'on'; grid(axMH, 'on');

% ── Row 4: dM/dH plot ───────────────────────────────────────────────
axSFD = uiaxes(rootGL);
axSFD.Layout.Row = 4;
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

% State
hResult = [];

% ════════════════════════════════════════════════════════════════════════
% Nested functions
% ════════════════════════════════════════════════════════════════════════

    function [H, M] = getHM()
    %GETHM  Extract field and moment vectors from selected channels.
        hCh = ddHCh.Value;
        mCh = ddMCh.Value;
        if hCh == 0
            H = plotD.time(:);
        else
            H = plotD.values(:, hCh);
        end
        if mCh == 0
            M = plotD.time(:);
        else
            M = plotD.values(:, mCh);
        end
    end

    function onAnalyze()
        [H, M] = getHM();

        % Optional background subtraction
        if cbBgSub.Value
            [H, M] = subtractLinearBG(H, M);
        end

        hFig.Pointer = 'watch'; drawnow;
        try
            r = utilities.hysteresisAnalysis(H, M, ...
                PreSmooth=efSmooth.Value);
            hResult = r;

            % ── Plot M(H) with colored branches ──
            cla(axMH);
            hold(axMH, 'on');
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

            % Markers
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

            % ── Plot dM/dH ──
            cla(axSFD);
            hold(axSFD, 'on');
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

            % ── Populate results table ──
            tblResults.Data = buildResultsTable(r);

            % ── Warnings ──
            if ~isempty(r.warnings)
                lblWarnings.Text = strjoin(r.warnings, ' | ');
            else
                lblWarnings.Text = '';
            end

            hFig.Pointer = 'arrow';
            options.StatusFcn(sprintf('Hysteresis: Hc=%.1f Ms=%.3e Mr/Ms=%.3f', ...
                r.HcMean, r.MsMean, r.squareness));
        catch ME
            hFig.Pointer = 'arrow';
            uialert(hFig, sprintf('Analysis failed:\n%s', ME.message), 'Error');
        end
    end

    function onPlotOnMain()
        if isempty(hResult), return; end
        hold(mainAx, 'on');
        if isfinite(hResult.Hc(1))
            xline(mainAx, hResult.Hc(1), '--b', 'LineWidth', 1, ...
                'HandleVisibility', 'off', 'Tag', 'hystMarker');
        end
        if isfinite(hResult.Hc(2))
            xline(mainAx, hResult.Hc(2), '--r', 'LineWidth', 1, ...
                'HandleVisibility', 'off', 'Tag', 'hystMarker');
        end
        if isfinite(hResult.Ms(1))
            yline(mainAx, hResult.Ms(1), '-', 'Color', [0.4 0.4 0.4], ...
                'HandleVisibility', 'off', 'Tag', 'hystMarker');
        end
        hold(mainAx, 'off');
        options.StatusFcn('Hysteresis markers overlaid on main axes');
    end

    function onCopy()
        if isempty(hResult), return; end
        lines = {};
        lines{end+1} = 'Hysteresis Loop Analysis';
        data = buildResultsTable(hResult);
        for ri = 1:size(data, 1)
            lines{end+1} = sprintf('%s\t%s\t%s', data{ri,1}, data{ri,2}, data{ri,3}); %#ok<AGROW>
        end
        if ~isempty(hResult.warnings)
            lines{end+1} = '';
            lines{end+1} = sprintf('Warnings: %s', strjoin(hResult.warnings, '; '));
        end
        clipboard('copy', strjoin(lines, newline));
        options.StatusFcn('Hysteresis results copied to clipboard');
    end

    function onExport()
        if isempty(hResult), return; end
        [fn, fp] = uiputfile({'*.csv','CSV'}, 'Export Hysteresis Results');
        if isequal(fn, 0), return; end
        data = buildResultsTable(hResult);
        fid = fopen(fullfile(fp, fn), 'w');
        fprintf(fid, 'Parameter,Value,Unit\n');
        for ri = 1:size(data, 1)
            fprintf(fid, '%s,%s,%s\n', data{ri,1}, data{ri,2}, data{ri,3});
        end
        fclose(fid);
        options.StatusFcn(sprintf('Results exported: %s', fn));
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers
% ════════════════════════════════════════════════════════════════════════

function [hIdx, mIdx] = autoDetectChannels(labels)
    lower_labels = lower(labels);
    hIdx = find(contains(lower_labels, 'field') | contains(lower_labels, 'magnetic'), 1);
    mIdx = find(contains(lower_labels, 'moment') | contains(lower_labels, 'emu'), 1);
    if isempty(hIdx), hIdx = 0; end  % 0 = use time axis
    if isempty(mIdx), mIdx = min(1, numel(labels)); end
end

function [H, M] = subtractLinearBG(H, M)
%SUBTRACTLINEARBG  Fit and subtract linear paramagnetic/diamagnetic slope.
    Hmax = max(abs(H));
    hiMask = abs(H) > 0.7 * Hmax;
    if sum(hiMask) < 4, return; end
    p = polyfit(H(hiMask), M(hiMask), 1);
    M = M - p(1) * H;  % subtract slope only, keep offset
end

function data = buildResultsTable(r)
    data = { ...
        'Hc (ascending)',    sprintf('%.2f', r.Hc(1)),    'Oe'; ...
        'Hc (descending)',   sprintf('%.2f', r.Hc(2)),    'Oe'; ...
        'Hc (average)',      sprintf('%.2f', r.HcMean),   'Oe'; ...
        'Mr (ascending)',    sprintf('%.4e', r.Mr(1)),     'emu'; ...
        'Mr (descending)',   sprintf('%.4e', r.Mr(2)),     'emu'; ...
        'Mr (average)',      sprintf('%.4e', r.MrMean),    'emu'; ...
        'Ms (+)',            sprintf('%.4e', r.Ms(1)),     'emu'; ...
        'Ms (-)',            sprintf('%.4e', r.Ms(2)),     'emu'; ...
        'Ms (average)',      sprintf('%.4e', r.MsMean),    'emu'; ...
        'Squareness (Mr/Ms)',sprintf('%.4f', r.squareness),''; ...
        'SFD FWHM',         sprintf('%.2f', r.SFD.fwhm),  'Oe'; ...
        'Loop Area',         sprintf('%.4e', r.loopArea),  'emu·Oe'};
end
