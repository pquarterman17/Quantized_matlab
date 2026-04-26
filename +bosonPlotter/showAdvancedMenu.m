function showAdvancedMenu(appData, fig, headless, callbacks)
%SHOWADVANCEDMENU  Open the Advanced Tools popup dialog.
%
% Syntax
%   bosonPlotter.showAdvancedMenu(appData, fig, headless, callbacks)
%
% Inputs
%   appData   - bosonPlotter.AppState handle (used as persistent store for
%               the popup figure handle via appData.advMenuFig)
%   fig       - Main BosonPlotter figure handle (for popup positioning)
%   headless  - Logical scalar; when true, skip the `figure()` raise
%   callbacks - Struct of function handles:
%                 .anaCb                — struct of analysis callbacks
%                                         (onOpenIntegrationDialog, onOpenCurveFitDialog,
%                                          onOpenHysteresisDialog, onROIAnalysis,
%                                          onConfidenceBand, onLinearRegression, onTTest,
%                                          onBatchFit, onGlobalFit, onTrackPeak, onFFTFilter,
%                                          onOpenAdvancedPeakAnalysis, onOpenReflFitDialog,
%                                          onOpenDigitizer)
%                 .tblCb                — struct of table callbacks (onDescriptiveStats)
%                 .onDatasetAlgebra     — dataset math dialog
%                 .onResampleDataset    — resample to uniform x-grid
%                 .onColumnCalculator   — column-calculator dialog
%                 .onAdvAsymmetry       — spin-asymmetry toggle
%                 .onFFTThickness       — Laue / Kiessig FFT thickness
%                 .onReflectivityFFT    — reflectivity FFT SLD
%                 .onArmFringeThickness — 2-click fringe thickness
%                 .onCreateInset        — inset graph builder
%
% Notes
%   The previously-nested helpers advBtn / advMenuAction / onAdvMenuKey /
%   onAdvFilterChanged are now nested inside this package function, which
%   frees ~5 slots (including closeAdvMenu) against the parent GUI's
%   nested-function parser cap.

    if ~isempty(appData.advMenuFig) && isvalid(appData.advMenuFig)
        if ~headless, figure(appData.advMenuFig); end
        return;
    end

    anaCb = callbacks.anaCb;
    tblCb = callbacks.tblCb;

    BTN_BG = [0.15 0.15 0.15];
    BTN_FC = [0.9 0.9 0.9];
    HDR_FC = [0.5 0.5 0.5];

    figPos = fig.Position;
    advMenuFig = uifigure('Name', 'Advanced Tools', ...
        'Position', [figPos(1) + figPos(3) - 400, figPos(2) + figPos(4) - 700, 380, 640], ...
        'Resize', 'on', ...
        'CloseRequestFcn', @(~,~) closeMenu(), ...
        'KeyPressFcn', @(~,evt) onKey(evt));
    appData.advMenuFig = advMenuFig;

    advRootGL = uigridlayout(advMenuFig, [2 1], ...
        'RowHeight', {30, '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 0);
    efAdvFilter = uieditfield(advRootGL, 'text', ...
        'Value', '', ...
        'Placeholder', 'Filter tools...', ...
        'FontSize', 10, ...
        'ValueChangedFcn', @(~,~) onFilterChanged());
    efAdvFilter.Layout.Row = 1;

    advScrollPanel = uipanel(advRootGL, 'BorderType', 'none', 'Scrollable', 'on');
    advScrollPanel.Layout.Row = 2;

    advMenuGL = uigridlayout(advScrollPanel, [26 2], ...
        'RowHeight', {16, 26,26,26,  5,  16, 26,26,26,  5,  16, 26,  5,  0,  0,  0,  16, 26,  5,  16, 26,26,26,  5,  16, 26}, ...
        'ColumnWidth', {'1x', '1x'}, ...
        'Padding', [8 6 8 6], 'RowSpacing', 2, 'ColumnSpacing', 4);

    allAdvBtns = {};

    % ── ANALYSIS ─────────────────────────────────────────────────────
    hdr = uilabel(advMenuGL, 'Text', 'ANALYSIS', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
    hdr.Layout.Row = 1; hdr.Layout.Column = [1 2];

    addBtn(advMenuGL, 2, 1, [char(8747) ' Integrate...'], anaCb.onOpenIntegrationDialog, ...
        'Compute definite integral between two x-range edge points');
    addBtn(advMenuGL, 2, 2, [char(8776) ' Curve Fit...'], anaCb.onOpenCurveFitDialog, ...
        'Fit data to built-in models (exponential, power law, polynomial, Gaussian, ...)');
    addBtn(advMenuGL, 3, 1, [char(916) ' Dataset Math...'], callbacks.onDatasetAlgebra, ...
        'Combine datasets: A+B, A-B, A/B, A*B, asymmetry');
    addBtn(advMenuGL, 3, 2, [char(8635) ' Hysteresis...'], anaCb.onOpenHysteresisDialog, ...
        'Analyze M(H) loops: Hc, Mr, Ms, squareness, SFD, background subtraction');
    addBtn(advMenuGL, 4, 1, 'ROI / Range Stats...', anaCb.onROIAnalysis, ...
        'Drag cursors on the plot to get live area / mean / std / FWHM over an x-range');
    addBtn(advMenuGL, 4, 2, 'Confidence Band...', anaCb.onConfidenceBand, ...
        ['Mean' char(177) 'std or median' char(177) 'IQR shaded bands from repeat measurements']);

    % ── STATISTICS & FITTING ─────────────────────────────────────────
    hdr2 = uilabel(advMenuGL, 'Text', 'STATISTICS & FITTING', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
    hdr2.Layout.Row = 6; hdr2.Layout.Column = [1 2];

    addBtn(advMenuGL, 7, 1, 'Descriptive Stats...', tblCb.onDescriptiveStats, ...
        'Mean, median, std, quartiles, skewness, kurtosis for selected channel');
    addBtn(advMenuGL, 7, 2, 'Linear Regression...', anaCb.onLinearRegression, ...
        'Polynomial regression with confidence bands and p-values');
    addBtn(advMenuGL, 8, 1, 't-Test...', anaCb.onTTest, ...
        'One-sample, paired, or two-sample t-test');
    addBtn(advMenuGL, 8, 2, 'Batch Fit...', anaCb.onBatchFit, ...
        'Fit the same model across all loaded datasets and collect trend results');
    addBtn(advMenuGL, 9, 1, 'Global Fit...', anaCb.onGlobalFit, ...
        'Fit multiple datasets simultaneously with shared parameters');
    addBtn(advMenuGL, 9, 2, 'Track Peak...', anaCb.onTrackPeak, ...
        'Track peak position/width drift across a dataset series');

    % ── SIGNAL PROCESSING ────────────────────────────────────────────
    hdr3 = uilabel(advMenuGL, 'Text', 'SIGNAL PROCESSING', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
    hdr3.Layout.Row = 11; hdr3.Layout.Column = [1 2];

    addBtn(advMenuGL, 12, 1, 'FFT Filter...', anaCb.onFFTFilter, ...
        'Frequency-domain lowpass / highpass / bandpass / notch filter');

    % ── CORRECTION ───────────────────────────────────────────────────
    hdr5 = uilabel(advMenuGL, 'Text', 'CORRECTION', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
    hdr5.Layout.Row = 17; hdr5.Layout.Column = [1 2];

    addBtn(advMenuGL, 18, 1, [char(8596) ' Resample...'], callbacks.onResampleDataset, ...
        'Resample data to a uniform x-grid');
    addBtn(advMenuGL, 18, 2, 'Column Calculator...', callbacks.onColumnCalculator, ...
        'Create new columns from expressions');

    % ── NEUTRON / REFLECTOMETRY ──────────────────────────────────────
    hdr6 = uilabel(advMenuGL, 'Text', 'NEUTRON / REFLECTOMETRY', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
    hdr6.Layout.Row = 20; hdr6.Layout.Column = [1 2];

    addBtn(advMenuGL, 21, 1, 'Spin Asymmetry...', callbacks.onAdvAsymmetry, ...
        ['Toggle spin asymmetry calculation (R++ ' char(8722) ' R--) / (R++ + R--) for polarized neutron data']);
    addBtn(advMenuGL, 21, 2, 'Reflectivity Fitting...', anaCb.onOpenReflFitDialog, ...
        'Fit specular reflectivity R(Q) via Parratt recursion with layer stack editor');
    addBtn(advMenuGL, 22, 1, 'FFT Thickness...', callbacks.onFFTThickness, ...
        'Compute film thickness from Laue / Kiessig fringe periodicity via FFT');
    addBtn(advMenuGL, 22, 2, 'Reflectivity FFT...', callbacks.onReflectivityFFT, ...
        ['Compute SLD profile from Kiessig fringes via FFT (Q-space). ' ...
         'Also estimates thickness from fringe spacing.']);
    addBtn(advMenuGL, 23, 1, ['Fringe ' char(916) 't (2-click)...'], callbacks.onArmFringeThickness, ...
        ['Pick two fringe peaks to estimate thickness via t = 2' char(960) ...
         '/' char(916) 'Q.  Draggable markers for refinement.']);

    % ── VISUALIZATION & DATA ─────────────────────────────────────────
    hdr7 = uilabel(advMenuGL, 'Text', 'VISUALIZATION & DATA', 'FontSize', 9, 'FontWeight', 'bold', 'FontColor', HDR_FC);
    hdr7.Layout.Row = 25; hdr7.Layout.Column = [1 2];

    addBtn(advMenuGL, 26, 1, 'Inset Plot...', callbacks.onCreateInset, ...
        'Create an inset zoom of a selected region');
    addBtn(advMenuGL, 26, 2, [char(9998) ' Graph Digitizer...'], anaCb.onOpenDigitizer, ...
        'Extract data points from a graph image (screenshot/PDF figure)');

    % ──────────────────────────────────────────────────────────────────
    % Nested helpers
    % ──────────────────────────────────────────────────────────────────

    function addBtn(gl, row, col, txt, cb, tip)
        b = uibutton(gl, 'Text', txt, ...
            'ButtonPushedFcn', @(~,~) menuAction(cb), ...
            'BackgroundColor', BTN_BG, 'FontColor', BTN_FC, ...
            'HorizontalAlignment', 'left', ...
            'Tooltip', tip);
        b.Layout.Row = row; b.Layout.Column = col;
        allAdvBtns{end+1} = b;
    end

    function menuAction(callbackFcn)
        closeMenu();
        callbackFcn([], []);
    end

    function onKey(evt)
        if strcmp(evt.Key, 'escape'), closeMenu(); end
    end

    function onFilterChanged()
        term = lower(strtrim(efAdvFilter.Value));
        for bi = 1:numel(allAdvBtns)
            b = allAdvBtns{bi};
            if ~isvalid(b), continue; end
            if isempty(term)
                b.Visible = 'on';
            else
                matches = contains(lower(b.Text), term) || ...
                          contains(lower(b.Tooltip), term);
                b.Visible = guiTernary(matches, 'on', 'off');
            end
        end
    end

    function closeMenu()
        if ~isempty(advMenuFig) && isvalid(advMenuFig)
            delete(advMenuFig);
        end
        appData.advMenuFig = [];
    end
end
