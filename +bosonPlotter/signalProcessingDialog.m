function signalProcessingDialog(appData, fig, ax, callbacks)
%SIGNALPROCESSINGDIALOG  Interactive signal processing with live preview.
%
%   Syntax:
%       bosonPlotter.signalProcessingDialog(appData, fig, ax, callbacks)
%
%   Inputs:
%       appData   — BosonPlotter application data struct with at least:
%                     .datasets   — cell array of dataset structs
%                     .activeIdx  — index of active dataset
%       fig       — main BosonPlotter uifigure handle
%       ax        — main plot axes handle (used for live preview overlay)
%       callbacks — struct of function handles:
%                     .getPlotData  — @() returns struct with .time, .values, .labels
%                     .setStatus    — @(msg) updates the status bar
%                     .onPlot       — @() refreshes the main plot
%
%   Description:
%       Opens a modal-less dialog for FFT Filter, Smoothing, and Welch PSD
%       processing with live preview overlaid on the main axes. The Apply
%       button adds a processed copy as a new dataset; the original is
%       never modified.
%
%   Examples:
%       % Called from BosonPlotter advanced tools menu:
%       % bosonPlotter.signalProcessingDialog(appData, fig, ax, callbacks)
%
%   See also utilities.fftFilter, utilities.smoothData, utilities.fftSpectral

arguments
    appData   struct
    fig                   % uifigure — no type constraint (handle)
    ax                    % axes handle — no type constraint (handle)
    callbacks struct
end

% ════════════════════════════════════════════════════════════════════════
% Validate callbacks
% ════════════════════════════════════════════════════════════════════════

requiredCb = {'getPlotData', 'setStatus', 'onPlot'};
for k = 1:numel(requiredCb)
    if ~isfield(callbacks, requiredCb{k}) || ~isa(callbacks.(requiredCb{k}), 'function_handle')
        error('bosonPlotter:signalProcessingDialog:badCallbacks', ...
            'callbacks.%s must be a function handle.', requiredCb{k});
    end
end

% ════════════════════════════════════════════════════════════════════════
% Load current plot data
% ════════════════════════════════════════════════════════════════════════

plotD = callbacks.getPlotData();
if isempty(plotD) || isempty(plotD.time) || isempty(plotD.values)
    uialert(fig, 'No plottable data in the active dataset.', 'Signal Processing');
    return
end

xData  = plotD.time(:);
yAll   = plotD.values;
labels = plotD.labels;
nCols  = size(yAll, 2);

% Active channel (column index into yAll)
activeCh = 1;

% Handle for the live-preview line on the main axes (removed on close/cancel)
previewLine = gobjects(0);

% Result from last successful processing run (used by Apply)
lastResult = [];

% ════════════════════════════════════════════════════════════════════════
% Theme colours (match BosonPlotter defaults)
% ════════════════════════════════════════════════════════════════════════

BTN_PRIMARY = [0.15 0.45 0.75];
BTN_TOOL    = [0.22 0.22 0.28];
BTN_FG      = [0.95 0.95 0.95];

% ════════════════════════════════════════════════════════════════════════
% Build dialog window
% ════════════════════════════════════════════════════════════════════════

dlgFig = uifigure('Name', 'Signal Processing', ...
    'Position', [220 120 500 450], ...
    'Resize', 'on', ...
    'CloseRequestFcn', @(~,~) onCancel());

rootGL = uigridlayout(dlgFig, [5 1], ...
    'RowHeight', {52, 'fit', 'fit', 22, 30}, ...
    'Padding', [10 8 10 8], 'RowSpacing', 6);

% ── Row 1: Top controls ──────────────────────────────────────────────

topGL = uigridlayout(rootGL, [2 4], ...
    'RowHeight', {22, 22}, ...
    'ColumnWidth', {90, '1x', 80, '1x'}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 4);
topGL.Layout.Row = 1;

uilabel(topGL, 'Text', 'Operation:', 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
ddOperation = uidropdown(topGL, ...
    'Items', {'FFT Filter', 'Smoothing', 'Welch PSD'}, ...
    'Value', 'FFT Filter', ...
    'ValueChangedFcn', @(~,~) onOperationChanged());
ddOperation.Layout.Row = 1; ddOperation.Layout.Column = 2;

uilabel(topGL, 'Text', 'Channel:', 'HorizontalAlignment', 'right');
ddChannel = uidropdown(topGL, ...
    'Items', labels, ...
    'ItemsData', 1:nCols, ...
    'Value', activeCh, ...
    'ValueChangedFcn', @(~,~) onChannelChanged());
ddChannel.Layout.Row = 1; ddChannel.Layout.Column = 4;

lblNyq = uilabel(topGL, 'Text', buildNyquistLabel(), ...
    'HorizontalAlignment', 'left', 'FontSize', 9, ...
    'FontColor', [0.5 0.5 0.5]);
lblNyq.Layout.Row = 2; lblNyq.Layout.Column = [1 4];

% ── Row 2: FFT Filter panel ──────────────────────────────────────────

pnlFFT = uipanel(rootGL, 'Title', 'FFT Filter Settings', 'FontSize', 10);
pnlFFT.Layout.Row = 2;

fftGL = uigridlayout(pnlFFT, [4 4], ...
    'RowHeight', {22, 22, 22, 22}, ...
    'ColumnWidth', {100, '1x', 80, 65}, ...
    'Padding', [6 4 6 4], 'RowSpacing', 4);

uilabel(fftGL, 'Text', 'Filter type:', 'HorizontalAlignment', 'right');
ddFilterType = uidropdown(fftGL, ...
    'Items', {'Low-pass', 'High-pass', 'Band-pass', 'Notch'}, ...
    'Value', 'Low-pass', ...
    'ValueChangedFcn', @(~,~) onFilterTypeChanged());
ddFilterType.Layout.Row = 1; ddFilterType.Layout.Column = [2 4];

uilabel(fftGL, 'Text', 'Cutoff f (Hz):', 'HorizontalAlignment', 'right');
efCutoff = uieditfield(fftGL, 'numeric', 'Value', defaultCutoff(), ...
    'Tooltip', 'Cutoff frequency in same units as 1/(x spacing)', ...
    'ValueChangedFcn', @(~,~) onParamChanged());
efCutoff.Layout.Row = 2; efCutoff.Layout.Column = 2;
slCutoff = uislider(fftGL, 'Limits', [0.001 nyquist()], 'Value', defaultCutoff(), ...
    'ValueChangedFcn', @(src,~) onSliderChanged(src, efCutoff), ...
    'ValueChangingFcn', @(src,e) onSliderChanging(src, e, efCutoff));
slCutoff.Layout.Row = 2; slCutoff.Layout.Column = [3 4];

% Second cutoff (band-pass high edge / notch bandwidth)
lblCutoff2 = uilabel(fftGL, 'Text', 'Cutoff f2 (Hz):', 'HorizontalAlignment', 'right');
efCutoff2 = uieditfield(fftGL, 'numeric', 'Value', defaultCutoff() * 2, ...
    'Tooltip', 'Upper cutoff (band-pass) or bandwidth (notch)', ...
    'ValueChangedFcn', @(~,~) onParamChanged());
efCutoff2.Layout.Row = 3; efCutoff2.Layout.Column = 2;
slCutoff2 = uislider(fftGL, 'Limits', [0.001 nyquist()], 'Value', defaultCutoff() * 2, ...
    'ValueChangedFcn', @(src,~) onSliderChanged(src, efCutoff2), ...
    'ValueChangingFcn', @(src,e) onSliderChanging(src, e, efCutoff2));
slCutoff2.Layout.Row = 3; slCutoff2.Layout.Column = [3 4];

uilabel(fftGL, 'Text', 'Order:', 'HorizontalAlignment', 'right');
spOrder = uispinner(fftGL, 'Limits', [1 12], 'Value', 4, 'Step', 1, ...
    'Tooltip', 'Butterworth filter order — higher = sharper rolloff', ...
    'ValueChangedFcn', @(~,~) onParamChanged());
spOrder.Layout.Row = 4; spOrder.Layout.Column = 2;

uilabel(fftGL, 'Text', 'Window:', 'HorizontalAlignment', 'right');
ddFFTWin = uidropdown(fftGL, ...
    'Items', {'None', 'Hamming', 'Hanning', 'Blackman'}, ...
    'Value', 'None', ...
    'Tooltip', 'Taper window to reduce spectral leakage', ...
    'ValueChangedFcn', @(~,~) onParamChanged());
ddFFTWin.Layout.Row = 4; ddFFTWin.Layout.Column = [3 4];

% Assign layout positions for label/second slider (set visibility below)
lblCutoff2.Layout.Row = 3; lblCutoff2.Layout.Column = 1;

% ── Row 3: Smoothing panel ──────────────────────────────────────────

pnlSmooth = uipanel(rootGL, 'Title', 'Smoothing Settings', 'FontSize', 10);
pnlSmooth.Layout.Row = 3;

smGL = uigridlayout(pnlSmooth, [2 4], ...
    'RowHeight', {22, 22}, ...
    'ColumnWidth', {100, '1x', 80, 65}, ...
    'Padding', [6 4 6 4], 'RowSpacing', 4);

uilabel(smGL, 'Text', 'Method:', 'HorizontalAlignment', 'right');
ddSmMethod = uidropdown(smGL, ...
    'Items', {'Moving', 'Gaussian', 'Savitzky-Golay'}, ...
    'Value', 'Moving', ...
    'ValueChangedFcn', @(~,~) onParamChanged());
ddSmMethod.Layout.Row = 1; ddSmMethod.Layout.Column = [2 4];

uilabel(smGL, 'Text', 'Window half-w:', 'HorizontalAlignment', 'right', ...
    'Tooltip', 'Half-width in samples; total window = 2*W+1');
spSmWindow = uispinner(smGL, 'Limits', [1 500], 'Value', 5, 'Step', 1, ...
    'Tooltip', 'Smoothing half-width (samples)', ...
    'ValueChangedFcn', @(~,~) onParamChanged());
spSmWindow.Layout.Row = 2; spSmWindow.Layout.Column = 2;

slSmWindow = uislider(smGL, 'Limits', [1 min(100, floor(numel(xData)/4))], 'Value', 5, ...
    'ValueChangedFcn', @(src,~) onSliderChanged(src, spSmWindow), ...
    'ValueChangingFcn', @(src,e) onSliderChanging(src, e, spSmWindow));
slSmWindow.Layout.Row = 2; slSmWindow.Layout.Column = [3 4];

% ── Row 4: Status label ──────────────────────────────────────────────

lblStatus = uilabel(rootGL, 'Text', '', ...
    'FontSize', 9, 'FontColor', [0.5 0.5 0.5], ...
    'HorizontalAlignment', 'left');
lblStatus.Layout.Row = 4;

% ── Row 5: Action buttons ────────────────────────────────────────────

btnGL = uigridlayout(rootGL, [1 4], ...
    'ColumnWidth', {'1x', '1x', '1x', '1x'}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 6);
btnGL.Layout.Row = 5;

btnPreview = uibutton(btnGL, 'Text', 'Preview', ...
    'BackgroundColor', BTN_TOOL, 'FontColor', BTN_FG, ...
    'Tooltip', 'Overlay processed result on main axes', ...
    'ButtonPushedFcn', @(~,~) onPreview());

btnApply = uibutton(btnGL, 'Text', 'Apply', ...
    'BackgroundColor', BTN_PRIMARY, 'FontColor', [1 1 1], ...
    'FontWeight', 'bold', ...
    'Tooltip', 'Add processed result as a new dataset', ...
    'ButtonPushedFcn', @(~,~) onApply());

uibutton(btnGL, 'Text', 'Clear Preview', ...
    'Tooltip', 'Remove the preview overlay from main axes', ...
    'ButtonPushedFcn', @(~,~) clearPreview());

uibutton(btnGL, 'Text', 'Cancel', ...
    'ButtonPushedFcn', @(~,~) onCancel());

% ════════════════════════════════════════════════════════════════════════
% Initialise panel visibility
% ════════════════════════════════════════════════════════════════════════

onOperationChanged();   % hides/shows FFT vs Smooth panel
onFilterTypeChanged();  % hides/shows second cutoff row

% ════════════════════════════════════════════════════════════════════════
% Nested callbacks
% ════════════════════════════════════════════════════════════════════════

    function onOperationChanged()
        op = ddOperation.Value;
        pnlFFT.Visible    = strcmp(op, 'FFT Filter');
        pnlSmooth.Visible = strcmp(op, 'Smoothing');
        % Welch PSD has no additional settings; preview shows spectral plot
        clearPreview();
        setStatus('');
    end

    function onFilterTypeChanged()
        ft = ddFilterType.Value;
        needTwo = ismember(ft, {'Band-pass', 'Notch'});
        lblCutoff2.Visible = needTwo;
        efCutoff2.Visible  = needTwo;
        slCutoff2.Visible  = needTwo;
        if strcmp(ft, 'Notch')
            lblCutoff2.Text = 'Bandwidth:';
            efCutoff2.Tooltip = 'Width of the notch band in the same units as Cutoff f';
        else
            lblCutoff2.Text = 'Cutoff f2 (Hz):';
            efCutoff2.Tooltip = 'Upper cutoff frequency for band-pass';
        end
    end

    function onChannelChanged()
        activeCh = ddChannel.Value;
        % Update slider ranges based on new channel's Nyquist
        fNyq = nyquist();
        slCutoff.Limits  = [0.001 fNyq];
        slCutoff2.Limits = [0.001 fNyq];
        lblNyq.Text = buildNyquistLabel();
        clearPreview();
        setStatus('');
    end

    function onParamChanged()
        % Sync slider value from edit field (if field was typed directly)
        syncEditToSlider(efCutoff,  slCutoff);
        syncEditToSlider(efCutoff2, slCutoff2);
        syncSpinnerToSlider(spSmWindow, slSmWindow);
        clearPreview();
        setStatus('Parameters changed — press Preview to update.');
    end

    function onSliderChanged(src, ef)
        ef.Value = round(src.Value * 1000) / 1000;
        clearPreview();
        setStatus('Parameters changed — press Preview to update.');
    end

    function onSliderChanging(src, event, ef)
        % Live drag: update edit field continuously
        ef.Value = round(event.Value * 1000) / 1000;
        % Trigger a non-blocking preview on drag
        doProcess();
    end

    function onPreview()
        try
            doProcess();
        catch ME
            setStatus(['Preview failed: ' ME.message]);
        end
    end

    function doProcess()
        op = ddOperation.Value;
        y  = yAll(:, activeCh);

        switch op
            case 'FFT Filter'
                r = runFFTFilter(xData, y);
                if isempty(r), return; end
                lastResult = struct('x', xData, 'y', r.yFiltered, 'op', op);
                overlayOnMain(xData, r.yFiltered, ...
                    sprintf('FFT Filter (%s)', ddFilterType.Value));
                setStatus(sprintf('FFT filter applied — peak attenuation at cutoff: %s', ...
                    ddFilterType.Value));

            case 'Smoothing'
                ySmooth = runSmoothing(y);
                if isempty(ySmooth), return; end
                lastResult = struct('x', xData, 'y', ySmooth, 'op', op);
                overlayOnMain(xData, ySmooth, ...
                    sprintf('Smoothed (%s, W=%d)', ddSmMethod.Value, spSmWindow.Value));
                setStatus(sprintf('Smoothing applied — method: %s, window: %d', ...
                    ddSmMethod.Value, spSmWindow.Value));

            case 'Welch PSD'
                r = utilities.fftSpectral(xData, y, Window='hanning', ...
                    SegmentLen=min(256, floor(numel(xData)/4)), ...
                    Overlap=0.5, OutputType='psd');
                lastResult = struct('x', r.freq, 'y', r.psd, 'op', op);
                overlaySpectrum(r.freq, r.psd, labels{activeCh});
                setStatus(sprintf('Welch PSD — df=%.4f Hz', r.df));
        end
    end

    function r = runFFTFilter(x, y)
        r = [];
        ft = lower(strrep(ddFilterType.Value, '-', ''));
        % Map GUI string to fftFilter Type option
        typeMap = struct('lowpass','lowpass','highpass','highpass', ...
            'bandpass','bandpass','notch','notch');
        if ~isfield(typeMap, ft)
            setStatus('Unknown filter type.'); return;
        end
        ftype = typeMap.(ft);

        cutoff1 = efCutoff.Value;
        fNyq    = nyquist();
        if cutoff1 <= 0 || cutoff1 >= fNyq
            setStatus(sprintf('Cutoff must be between 0 and Nyquist (%.3f).', fNyq));
            return
        end

        winStr = lower(ddFFTWin.Value);  % 'none','hamming','hanning','blackman'
        ord    = round(spOrder.Value);

        switch ftype
            case {'bandpass'}
                cutoff2 = efCutoff2.Value;
                if cutoff2 <= cutoff1 || cutoff2 >= fNyq
                    setStatus('Cutoff f2 must be > Cutoff f and < Nyquist.'); return;
                end
                r = utilities.fftFilter(x, y, Type=ftype, Cutoff=[cutoff1 cutoff2], ...
                    Order=ord, Window=winStr);
            case {'notch'}
                bw = efCutoff2.Value;
                if bw <= 0
                    setStatus('Bandwidth must be positive.'); return;
                end
                r = utilities.fftFilter(x, y, Type=ftype, Cutoff=cutoff1, ...
                    Bandwidth=bw, Order=ord, Window=winStr);
            otherwise
                r = utilities.fftFilter(x, y, Type=ftype, Cutoff=cutoff1, ...
                    Order=ord, Window=winStr);
        end
    end

    function ySmooth = runSmoothing(y)
        ySmooth = [];
        method = lower(strrep(ddSmMethod.Value, '-', ''));
        switch method
            case 'moving'
                mStr = 'moving';
            case 'gaussian'
                mStr = 'gaussian';
            case {'savitzkygolay'}
                mStr = 'savitzky-golay';
            otherwise
                setStatus('Unknown smoothing method.'); return
        end
        hw = round(spSmWindow.Value);
        if hw < 1
            setStatus('Window half-width must be at least 1.'); return
        end
        ySmooth = utilities.smoothData(y, Method=mStr, Window=hw);
    end

    function overlayOnMain(x, yProc, labelStr)
        clearPreview();
        if ~isvalid(ax), return; end
        hold(ax, 'on');
        previewLine = plot(ax, x, yProc, '-', ...
            'Color', [0.9 0.4 0.1], 'LineWidth', 1.5, ...
            'DisplayName', labelStr, ...
            'Tag', 'signalProcessingPreview', ...
            'HandleVisibility', 'on');
        hold(ax, 'off');
        legend(ax, 'Location', 'best');
    end

    function overlaySpectrum(freq, psd, chanLabel)
        % For Welch PSD, open a small figure rather than overlaying on main axes
        % (frequency domain is a different plot space from the original signal)
        clearPreview();
        psdFig = figure('Name', sprintf('Welch PSD — %s', chanLabel), ...
            'NumberTitle', 'off', 'Position', [300 200 500 300]);
        semilogy(freq, psd, 'b-', 'LineWidth', 1.2);
        xlabel('Frequency'); ylabel('PSD');
        title(sprintf('Welch PSD — %s', chanLabel));
        grid on; box on;
        % Store figure handle so we can track it (not removed by clearPreview)
        previewLine = gobjects(0);  % no overlay on main axes for PSD
    end

    function onApply()
        if isempty(lastResult)
            try
                doProcess();
            catch ME
                uialert(dlgFig, ME.message, 'Processing Error');
                return
            end
            if isempty(lastResult), return; end
        end

        % Build new dataset name
        ds = appData.datasets{appData.activeIdx};
        origName = ds.data.metadata.filename;
        if isempty(origName)
            origName = sprintf('Dataset %d', appData.activeIdx);
        end
        op = lastResult.op;
        switch op
            case 'FFT Filter'
                suffix = sprintf(' (%s filtered)', lower(ddFilterType.Value));
            case 'Smoothing'
                suffix = sprintf(' (%s smoothed)', lower(ddSmMethod.Value));
            case 'Welch PSD'
                suffix = ' (Welch PSD)';
            otherwise
                suffix = ' (processed)';
        end
        newName = [origName suffix];

        % Build new data struct using original as template
        if ~isempty(ds.corrData) && ~isempty(ds.corrData.time)
            baseD = ds.corrData;
        else
            baseD = ds.data;
        end

        newValues = baseD.values;
        if strcmp(op, 'Welch PSD')
            % PSD has a different x-axis — build a standalone data struct
            newData = parser.createDataStruct( ...
                lastResult.x, lastResult.y, ...
                {'PSD'}, {''}, ...
                struct('filename', newName, 'source', 'signalProcessingDialog', ...
                       'parserName', 'SignalProcessing', 'parserSpecific', struct()));
        else
            % Replace the active channel, keep others
            newValues(:, activeCh) = lastResult.y;
            newData = parser.createDataStruct( ...
                baseD.time, newValues, ...
                baseD.labels, baseD.units, ...
                struct('filename', newName, 'source', 'signalProcessingDialog', ...
                       'parserName', 'SignalProcessing', 'parserSpecific', struct()));
        end

        % Add to workspace via model if available, otherwise via callbacks
        if isfield(appData, 'model') && isfield(appData.model, 'addDataset') && ...
                isa(appData.model.addDataset, 'function_handle')
            appData.model.addDataset(newData);
        else
            % Fallback: trigger onPlot so the caller can handle it
            callbacks.setStatus(sprintf('Processed dataset ready: %s', newName));
        end

        clearPreview();
        callbacks.setStatus(sprintf('Applied: %s added as new dataset.', newName));
        callbacks.onPlot();
        setStatus(sprintf('Done — "%s" added.', newName));
    end

    function onCancel()
        clearPreview();
        delete(dlgFig);
    end

    function clearPreview()
        if ~isempty(previewLine) && all(isvalid(previewLine))
            delete(previewLine);
        end
        previewLine = gobjects(0);
    end

    function setStatus(msg)
        if isvalid(lblStatus)
            lblStatus.Text = msg;
        end
    end

% ════════════════════════════════════════════════════════════════════════
% Helper utilities (nested, access captured variables)
% ════════════════════════════════════════════════════════════════════════

    function fNyq = nyquist()
        dx   = mean(diff(xData));
        fNyq = 1 / (2 * abs(dx));
    end

    function fc = defaultCutoff()
        fc = nyquist() / 4;
    end

    function txt = buildNyquistLabel()
        fNyq = nyquist();
        dx   = mean(diff(xData));
        txt  = sprintf('Sampling: dx=%.4g, Nyquist=%.4g Hz  |  N=%d points', ...
            dx, fNyq, numel(xData));
    end

    function syncEditToSlider(ef, sl)
        v = ef.Value;
        v = max(sl.Limits(1), min(sl.Limits(2), v));
        if abs(sl.Value - v) > 1e-9
            sl.Value = v;
        end
    end

    function syncSpinnerToSlider(sp, sl)
        v = round(sp.Value);
        v = max(sl.Limits(1), min(sl.Limits(2), v));
        if abs(sl.Value - v) > 1e-9
            sl.Value = v;
        end
    end

end
