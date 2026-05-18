function rsmDecomposeDialog(mapData, options)
%RSMDECOMPOSEDIALOG  Interactive reciprocal-space-map peak decomposition.
%
% Syntax
%   bosonPlotter.rsmDecomposeDialog(mapData)
%   bosonPlotter.rsmDecomposeDialog(mapData, Title="RSM Decompose", ...
%                                   OverlayAxes=ax)
%
% Inputs
%   mapData — struct with fields:
%     .intensity  [N×M] intensity matrix
%     .axis1      [N×1] row axis (ω, degrees)
%     .axis2      [M×1] col axis (2θ, degrees)
%     .Qx, .Qz    (optional) reciprocal-space grids
%     .intensityUnit (optional)
%
% Options
%   Title        — dialog title (default 'RSM Decompose')
%   OverlayAxes  — handle to a uiaxes already displaying the map; when
%                  provided, fitted peak centres are drawn as markers on
%                  that axes. The dialog removes them on close.
%
% The dialog wraps fitting.rsmAnalyze + fitting.rsmStrain. It shows:
%   - NPeaks, FitModel, Threshold, FitWindow, SmoothSigma controls
%   - Results table: rank / class / ω / 2θ / Qx / Qz / FWHM(ω,2θ) / amp
%   - Strain summary (ε∥, ε⊥, relaxation from first two peaks when
%     Q-space data is available)
%   - Markers overlaid on the parent map axes (if OverlayAxes given)

    arguments
        mapData (1,1) struct
        options.Title       (1,1) string = "RSM Decompose"
        options.OverlayAxes              = []
    end

    % ── Validate input ──────────────────────────────────────────────
    required = {'intensity','axis1','axis2'};
    for k = 1:numel(required)
        assert(isfield(mapData, required{k}), ...
            'bosonPlotter:rsmDecomposeDialog:missingField', ...
            'mapData must have field "%s"', required{k});
    end

    hasQ = isfield(mapData, 'Qx') && isfield(mapData, 'Qz') ...
           && ~isempty(mapData.Qx) && ~isempty(mapData.Qz);

    % ── Figure ──────────────────────────────────────────────────────
    hFig = uifigure('Name', char(options.Title), ...
                    'Position', [120 120 720 520], 'Resize','on');

    rootGL = uigridlayout(hFig, [1 1], 'Padding', [8 8 8 8]);
    mainPanel = uipanel(rootGL, 'BorderType','none');
    mainGL = uigridlayout(mainPanel, [6 4], ...
        'RowHeight',   {24, 24, 24, '1x', 60, 28}, ...
        'ColumnWidth', {130, '1x', 130, '1x'}, ...
        'Padding',     [6 6 6 6], 'RowSpacing', 4, 'ColumnSpacing', 8);

    % Row 1: NPeaks + FitModel
    lblN = uilabel(mainGL, 'Text','# peaks:','HorizontalAlignment','right');
    lblN.Layout.Row = 1; lblN.Layout.Column = 1;
    efN = uieditfield(mainGL, 'numeric', 'Value',2, 'Limits',[1 10], ...
                      'RoundFractionalValues','on');
    efN.Layout.Row = 1;  efN.Layout.Column = 2;
    lblModel = uilabel(mainGL, 'Text','Fit model:','HorizontalAlignment','right');
    lblModel.Layout.Row = 1; lblModel.Layout.Column = 3;
    ddModel = uidropdown(mainGL, ...
        'Items',{'2D Gaussian','2D Lorentzian','2D Pseudo-Voigt'}, ...
        'Value','2D Gaussian');
    ddModel.Layout.Row = 1;  ddModel.Layout.Column = 4;

    % Row 2: Threshold + Smooth σ
    lblT = uilabel(mainGL, 'Text','Threshold (·max):','HorizontalAlignment','right');
    lblT.Layout.Row = 2; lblT.Layout.Column = 1;
    efThresh = uieditfield(mainGL, 'numeric', 'Value',0.01, 'Limits',[0 1]);
    efThresh.Layout.Row = 2; efThresh.Layout.Column = 2;
    lblS = uilabel(mainGL, 'Text','Smooth σ (px):','HorizontalAlignment','right');
    lblS.Layout.Row = 2; lblS.Layout.Column = 3;
    efSigma = uieditfield(mainGL, 'numeric', 'Value',1.5, 'Limits',[0.1 20]);
    efSigma.Layout.Row = 2; efSigma.Layout.Column = 4;

    % Row 3: Fit window + Decompose button
    lblW = uilabel(mainGL, 'Text','Fit window (px):','HorizontalAlignment','right');
    lblW.Layout.Row = 3; lblW.Layout.Column = 1;
    efWin = uieditfield(mainGL, 'numeric', 'Value',6, 'Limits',[2 50], ...
                        'RoundFractionalValues','on');
    efWin.Layout.Row = 3; efWin.Layout.Column = 2;
    btnRun = uibutton(mainGL, 'Text','Decompose', ...
        'BackgroundColor',[0.25 0.40 0.60], 'FontColor',[1 1 1], ...
        'ButtonPushedFcn', @(~,~) onDecompose());
    btnRun.Layout.Row = 3; btnRun.Layout.Column = [3 4];

    % Row 4: results table
    tbl = uitable(mainGL, ...
        'ColumnName', {'Rank','Class','ω (°)','2θ (°)', ...
                       'Qx (Å⁻¹)','Qz (Å⁻¹)', ...
                       'FWHM ω (°)','FWHM 2θ (°)','Amplitude'}, ...
        'ColumnWidth', {40, 75, 70, 70, 80, 80, 80, 80, 90}, ...
        'ColumnEditable', false(1,9), ...
        'Data', {});
    tbl.Layout.Row = 4;  tbl.Layout.Column = [1 4];

    % Row 5: strain summary label
    lblStrain = uilabel(mainGL, ...
        'Text','Run Decompose to compute ε∥, ε⊥ (needs ≥ 2 peaks with Q-space data).', ...
        'FontSize', 11, 'WordWrap','on', ...
        'FontColor', [0.3 0.3 0.3]);
    lblStrain.Layout.Row = 5;  lblStrain.Layout.Column = [1 4];

    % Row 6: close button
    btnClose = uibutton(mainGL, 'Text','Close', ...
        'ButtonPushedFcn', @(~,~) onClose());
    btnClose.Layout.Row = 6;  btnClose.Layout.Column = 4;

    % Overlay handles (cleared on re-run and on close)
    overlayHandles = gobjects(0);

    hFig.CloseRequestFcn = @(~,~) onClose();

    % ── Callbacks ───────────────────────────────────────────────────
    function onDecompose()
        clearOverlay();
        lblStrain.Text = 'Running rsmAnalyze…';
        drawnow;
        try
            result = fitting.rsmAnalyze(mapData, ...
                NPeaks        = efN.Value, ...
                Threshold     = efThresh.Value, ...
                SmoothSigma   = efSigma.Value, ...
                FitWindow     = efWin.Value, ...
                FitModel      = ddModel.Value);
        catch ME
            bosonPlotter.quietAlert(hFig, sprintf('rsmAnalyze failed: %s', ME.message), ...
                    'RSM Decompose', 'Icon','error');
            lblStrain.Text = 'Fit failed. See error dialog.';
            return;
        end

        if result.nPeaksFound == 0
            tbl.Data = {};
            lblStrain.Text = 'No peaks above threshold. Try lowering Threshold or Smooth σ.';
            return;
        end

        % Populate results table
        rows = cell(result.nPeaksFound, 9);
        for k = 1:result.nPeaksFound
            pk = result.peaks(k);
            rows(k,:) = { pk.rank, pk.classification, ...
                          pk.centre_angle(1), pk.centre_angle(2), ...
                          pk.centre_Q(1), pk.centre_Q(2), ...
                          pk.fwhm_angle(1), pk.fwhm_angle(2), ...
                          pk.amplitude };
        end
        tbl.Data = rows;

        % Strain summary (rank 1 = substrate, rank 2 = film)
        if result.nPeaksFound >= 2 && result.usedQSpace
            s = fitting.rsmStrain(result.peaks(1).centre_Q, ...
                                  result.peaks(2).centre_Q);
            lblStrain.Text = sprintf( ...
                'ε∥ = %+0.3f %%   ε⊥ = %+0.3f %%   (substrate: rank 1, film: rank 2)', ...
                100*s.eps_parallel, 100*s.eps_perp);
        elseif result.nPeaksFound >= 2
            lblStrain.Text = ...
                'Peaks found, but map has no Q-space data — strain not computed.';
        else
            lblStrain.Text = 'Only one peak found — strain requires ≥ 2.';
        end

        % Overlay markers on parent map axes (if any)
        drawOverlay(result);
    end

    function drawOverlay(result)
        ax = options.OverlayAxes;
        if isempty(ax) || ~isvalid(ax)
            return;
        end
        useQ = hasQ && isQSpaceAxes(ax);
        holdBefore = ishold(ax);
        hold(ax, 'on');
        for k = 1:result.nPeaksFound
            pk = result.peaks(k);
            if useQ
                px = pk.centre_Q(1);
                py = pk.centre_Q(2);
            else
                px = pk.centre_angle(2);   % 2θ (x-axis of map)
                py = pk.centre_angle(1);   % ω (y-axis of map)
            end
            if strcmp(pk.classification, 'substrate')
                mkr = 's'; mcol = [0.95 0.30 0.30];
            elseif strcmp(pk.classification, 'film')
                mkr = 'o'; mcol = [0.30 0.80 0.30];
            else
                mkr = 'x'; mcol = [0.95 0.95 0.10];
            end
            h = plot(ax, px, py, mkr, ...
                'MarkerSize', 12, 'LineWidth', 2, ...
                'MarkerEdgeColor', mcol, ...
                'Tag', 'rsmDecomposeMarker');
            overlayHandles(end+1) = h; %#ok<AGROW>
            ht = text(ax, px, py, sprintf(' %d', pk.rank), ...
                'Color', mcol, 'FontWeight','bold', 'FontSize', 11, ...
                'VerticalAlignment','bottom', 'Tag','rsmDecomposeMarker');
            overlayHandles(end+1) = ht; %#ok<AGROW>
        end
        if ~holdBefore
            hold(ax, 'off');
        end
    end

    function clearOverlay()
        for h = overlayHandles(:)'
            if isgraphics(h), delete(h); end
        end
        overlayHandles = gobjects(0);
    end

    function tf = isQSpaceAxes(ax)
        % Heuristic: the parent plotter labels Q-space axes with "Q" text.
        tf = contains(string(ax.XLabel.String), "Q", 'IgnoreCase', true) || ...
             contains(string(ax.YLabel.String), "Q", 'IgnoreCase', true);
    end

    function onClose()
        clearOverlay();
        if isvalid(hFig)
            delete(hFig);
        end
    end
end
