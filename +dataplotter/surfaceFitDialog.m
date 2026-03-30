function surfaceFitDialog(mapData, options)
%SURFACEFITDIALOG  Interactive 2D surface fitting dialog for map datasets.
%
%   Syntax
%     dataplotter.surfaceFitDialog(mapData)
%     dataplotter.surfaceFitDialog(mapData, Title="My Title")
%
%   Inputs
%     mapData — struct with fields:
%       .intensity  [Ny×Nx] intensity matrix
%       .axis1      [Ny×1]  first-axis positions (rows, e.g. 2-theta or Qz)
%       .axis2      [Nx×1]  second-axis positions (cols, e.g. phi or Qx)
%
%   Options (name-value)
%     Title  — dialog window title (default: 'Surface Fit')
%
%   The dialog provides:
%     - Model dropdown (all models from fitting.surfaceModels)
%     - Editable initial-guess table (auto-populated via surfaceAutoGuess)
%     - Fit button (runs fminsearch via fitting.surfaceFit)
%     - Parameter results table with values and standard errors
%     - R², RMSE, chi²_red summary row
%     - Three visualisation panels: original | fitted | residual
%     - Save Fit (to workspace) and Export (to CSV) buttons

arguments
    mapData  struct
    options.Title  (1,1) string = "Surface Fit"
end

% ════════════════════════════════════════════════════════════════════════
% Validate input
% ════════════════════════════════════════════════════════════════════════
assert(isfield(mapData, 'intensity') && isfield(mapData, 'axis1') && ...
       isfield(mapData, 'axis2'), ...
    'dataplotter:surfaceFitDialog:invalidInput', ...
    'mapData must have fields .intensity, .axis1, .axis2');

Z = double(mapData.intensity);
a1 = mapData.axis1(:);   % [Ny×1]
a2 = mapData.axis2(:);   % [Nx×1]

[Ny, Nx] = size(Z);
assert(numel(a1) == Ny && numel(a2) == Nx, ...
    'dataplotter:surfaceFitDialog:sizeMismatch', ...
    'axis1 length (%d) must match intensity rows (%d), axis2 (%d) must match cols (%d).', ...
    numel(a1), Ny, numel(a2), Nx);

[X2, Y2] = meshgrid(a2, a1);   % X along axis2 (columns), Y along axis1 (rows)
xFlat = X2(:);
yFlat = Y2(:);
zFlat = Z(:);

% ════════════════════════════════════════════════════════════════════════
% Model catalog
% ════════════════════════════════════════════════════════════════════════
catalog    = fitting.surfaceModels();
modelNames = {catalog.name};

% Mutable state
fitResult = [];

% ════════════════════════════════════════════════════════════════════════
% Build figure
% ════════════════════════════════════════════════════════════════════════
hFig = uifigure('Name', char(options.Title), ...
    'Position', [100 60 1060 720], 'Resize', 'on');

rootGL = uigridlayout(hFig, [1 2], ...
    'ColumnWidth', {270, '1x'}, ...
    'Padding', [6 6 6 6], 'ColumnSpacing', 6);

% ── Left control panel ────────────────────────────────────────────────
ctrlPanel = uipanel(rootGL, 'Title', 'Fit Controls', 'FontSize', 11);
ctrlGL = uigridlayout(ctrlPanel, [14 2], ...
    'RowHeight', {22, 22, 20, '1x', 22, 'fit', 24, 24, 24, 24, 20, 'fit', 24, 24}, ...
    'ColumnWidth', {'1x', '1x'}, ...
    'Padding', [6 6 6 6], 'RowSpacing', 4);

% Row 1: Model label + dropdown
lblModelLbl = uilabel(ctrlGL, 'Text', 'Model:', ...
    'HorizontalAlignment', 'right', 'FontSize', 10);
lblModelLbl.Layout.Row = 1; lblModelLbl.Layout.Column = 1;
ddModel = uidropdown(ctrlGL, 'Items', modelNames, 'Value', modelNames{3}, ...
    'Tooltip', 'Select the 2D surface model to fit');
ddModel.Layout.Row = 1; ddModel.Layout.Column = 2;

% Row 2: Equation display
lblEq = uilabel(ctrlGL, 'Text', '', 'FontSize', 9, 'FontColor', [0.4 0.4 0.4], ...
    'WordWrap', 'on', 'HorizontalAlignment', 'left');
lblEq.Layout.Row = 2; lblEq.Layout.Column = [1 2];

% Row 3: "Initial guesses" header
lblGuessHdr = uilabel(ctrlGL, 'Text', 'Initial guesses (editable):', ...
    'FontSize', 10, 'FontColor', [0.25 0.25 0.25]);
lblGuessHdr.Layout.Row = 3; lblGuessHdr.Layout.Column = [1 2];

% Row 4: Guess table (stretchy)
tblGuess = uitable(ctrlGL, ...
    'ColumnName', {'Param', 'Value'}, ...
    'ColumnWidth', {70, 120}, ...
    'ColumnEditable', [false true], ...
    'RowName', {}, ...
    'Data', cell(0, 2));
tblGuess.Layout.Row = 4; tblGuess.Layout.Column = [1 2];

% Row 5: Fit button
btnFit = uibutton(ctrlGL, 'Text', 'Fit Surface', ...
    'BackgroundColor', [0.15 0.45 0.75], 'FontColor', [1 1 1], ...
    'Tooltip', 'Run fminsearch optimisation with current initial guesses');
btnFit.Layout.Row = 5; btnFit.Layout.Column = [1 2];

% Row 6: Status label (fit)
lblStatus = uilabel(ctrlGL, 'Text', '', 'FontSize', 9, ...
    'FontColor', [0.4 0.4 0.4], 'WordWrap', 'on', 'HorizontalAlignment', 'center');
lblStatus.Layout.Row = 6; lblStatus.Layout.Column = [1 2];

% Rows 7–10: Goodness-of-fit stats
lblR2 = uilabel(ctrlGL, 'Text', 'R²:',       'HorizontalAlignment', 'right', 'FontSize', 10);
lblR2.Layout.Row = 7; lblR2.Layout.Column = 1;
valR2 = uilabel(ctrlGL, 'Text', '—', 'FontSize', 10);
valR2.Layout.Row = 7; valR2.Layout.Column = 2;

lblRMSE = uilabel(ctrlGL, 'Text', 'RMSE:',   'HorizontalAlignment', 'right', 'FontSize', 10);
lblRMSE.Layout.Row = 8; lblRMSE.Layout.Column = 1;
valRMSE = uilabel(ctrlGL, 'Text', '—', 'FontSize', 10);
valRMSE.Layout.Row = 8; valRMSE.Layout.Column = 2;

lblChi = uilabel(ctrlGL, 'Text', 'chi2_red:', 'HorizontalAlignment', 'right', 'FontSize', 10);
lblChi.Layout.Row = 9; lblChi.Layout.Column = 1;
valChi = uilabel(ctrlGL, 'Text', '—', 'FontSize', 10);
valChi.Layout.Row = 9; valChi.Layout.Column = 2;

lblExit = uilabel(ctrlGL, 'Text', 'Converged:', 'HorizontalAlignment', 'right', 'FontSize', 10);
lblExit.Layout.Row = 10; lblExit.Layout.Column = 1;
valExit = uilabel(ctrlGL, 'Text', '—', 'FontSize', 10);
valExit.Layout.Row = 10; valExit.Layout.Column = 2;

% Row 11: "Fitted parameters" header
lblParamsHdr = uilabel(ctrlGL, 'Text', 'Fitted parameters:', ...
    'FontSize', 10, 'FontColor', [0.25 0.25 0.25]);
lblParamsHdr.Layout.Row = 11; lblParamsHdr.Layout.Column = [1 2];

% Row 12: Param results table (stretchy)
tblParams = uitable(ctrlGL, ...
    'ColumnName', {'Param', 'Value', 'Std Err'}, ...
    'ColumnWidth', {60, 90, 90}, ...
    'RowName', {}, ...
    'Enable', 'off', ...
    'Data', cell(0, 3));
tblParams.Layout.Row = 12; tblParams.Layout.Column = [1 2];

% Rows 13–14: Save / Export buttons
btnSave = uibutton(ctrlGL, 'Text', 'Save to Workspace', ...
    'BackgroundColor', [0.20 0.50 0.35], 'FontColor', [1 1 1], ...
    'Enable', 'off', ...
    'Tooltip', 'Save fit result struct to base workspace as ''surfaceFitResult''');
btnSave.Layout.Row = 13; btnSave.Layout.Column = [1 2];

btnExport = uibutton(ctrlGL, 'Text', 'Export to CSV...', ...
    'BackgroundColor', [0.35 0.35 0.45], 'FontColor', [1 1 1], ...
    'Enable', 'off', ...
    'Tooltip', 'Write x, y, z_data, z_fit, residual columns to a CSV file');
btnExport.Layout.Row = 14; btnExport.Layout.Column = [1 2];

% ── Right visualisation panel ─────────────────────────────────────────
vizPanel = uipanel(rootGL, 'Title', 'Visualisation', 'FontSize', 11);
vizGL = uigridlayout(vizPanel, [1 3], ...
    'RowHeight', {'1x'}, ...
    'ColumnWidth', {'1x', '1x', '1x'}, ...
    'Padding', [4 4 4 4], 'ColumnSpacing', 4);

axOrig = uiaxes(vizGL);
axOrig.Layout.Row = 1; axOrig.Layout.Column = 1;

axFit = uiaxes(vizGL);
axFit.Layout.Row = 1; axFit.Layout.Column = 2;

axRes = uiaxes(vizGL);
axRes.Layout.Row = 1; axRes.Layout.Column = 3;

% ════════════════════════════════════════════════════════════════════════
% Initial render
% ════════════════════════════════════════════════════════════════════════
plotOriginal();
populateGuessTable();

% ════════════════════════════════════════════════════════════════════════
% Callbacks
% ════════════════════════════════════════════════════════════════════════
ddModel.ValueChangedFcn   = @(~,~) populateGuessTable();
btnFit.ButtonPushedFcn    = @(~,~) onFit();
btnSave.ButtonPushedFcn   = @(~,~) onSave();
btnExport.ButtonPushedFcn = @(~,~) onExport();

% ════════════════════════════════════════════════════════════════════════
% Nested helper functions
% ════════════════════════════════════════════════════════════════════════

    function plotOriginal()
        cla(axOrig);
        imagesc(axOrig, a2, a1, Z);
        axis(axOrig, 'xy');
        colorbar(axOrig);
        xlabel(axOrig, 'Axis 2');
        ylabel(axOrig, 'Axis 1');
        title(axOrig, 'Original Data');
        cla(axFit); title(axFit, 'Fitted Surface (pending)');
        cla(axRes); title(axRes, 'Residuals (pending)');
    end

    function populateGuessTable()
        mName = ddModel.Value;
        ci = find(strcmp(modelNames, mName), 1);
        if isempty(ci); return; end

        lblEq.Text = catalog(ci).description;

        try
            p0 = fitting.surfaceAutoGuess(string(mName), xFlat, yFlat, zFlat);
        catch
            p0 = ones(1, catalog(ci).nParams);
        end
        pNames = catalog(ci).paramNames;
        nP     = catalog(ci).nParams;

        td = cell(nP, 2);
        for k = 1:nP
            td{k,1} = pNames{k};
            td{k,2} = p0(k);
        end
        tblGuess.Data = td;
    end

    function onFit()
        mName = ddModel.Value;
        lblStatus.Text = 'Fitting...';
        drawnow;

        % Read initial guesses
        td = tblGuess.Data;
        nP = size(td, 1);
        p0 = zeros(1, nP);
        for k = 1:nP
            val = td{k,2};
            if isnumeric(val)
                p0(k) = val;
            else
                p0(k) = str2double(val);
            end
        end
        if any(isnan(p0))
            lblStatus.Text = 'Error: non-numeric initial guess value.';
            return;
        end

        try
            fitResult = fitting.surfaceFit(xFlat, yFlat, zFlat, mName, ...
                'InitGuess', p0, 'MaxIter', 10000);
        catch ME
            lblStatus.Text = ['Error: ' ME.message];
            return;
        end

        % Update statistics
        valR2.Text   = sprintf('%.5f', fitResult.R2);
        valRMSE.Text = sprintf('%.4g', fitResult.RMSE);
        valChi.Text  = sprintf('%.4g', fitResult.chiSqRed);
        valExit.Text = sprintf('%d', fitResult.exitFlag);

        if fitResult.exitFlag == 1
            lblStatus.Text = sprintf('Converged. R2=%.4f, RMSE=%.4g', ...
                fitResult.R2, fitResult.RMSE);
        else
            lblStatus.Text = sprintf('Warning: did not converge (exitFlag=%d). R2=%.4f', ...
                fitResult.exitFlag, fitResult.R2);
        end

        % Param results table
        nP = fitResult.nFree;
        td2 = cell(nP, 3);
        for k = 1:nP
            td2{k,1} = fitResult.paramNames{k};
            td2{k,2} = fitResult.params(k);
            td2{k,3} = fitResult.errors(k);
        end
        tblParams.Data   = td2;
        tblParams.Enable = 'on';

        % Enable action buttons
        btnSave.Enable   = 'on';
        btnExport.Enable = 'on';

        % Visualise
        zFitMat = reshape(fitResult.zFit,       Ny, Nx);
        zResMat = reshape(fitResult.residuals,   Ny, Nx);

        cla(axFit);
        imagesc(axFit, a2, a1, zFitMat);
        axis(axFit, 'xy'); colorbar(axFit);
        xlabel(axFit, 'Axis 2'); ylabel(axFit, 'Axis 1');
        title(axFit, sprintf('Fitted — %s', fitResult.modelName));

        cla(axRes);
        imagesc(axRes, a2, a1, zResMat);
        axis(axRes, 'xy'); colorbar(axRes);
        xlabel(axRes, 'Axis 2'); ylabel(axRes, 'Axis 1');
        title(axRes, 'Residuals');
    end

    function onSave()
        if isempty(fitResult); return; end
        assignin('base', 'surfaceFitResult', fitResult);
        lblStatus.Text = 'Saved to workspace variable ''surfaceFitResult''.';
    end

    function onExport()
        if isempty(fitResult); return; end
        [fname, fpath] = uiputfile('*.csv', 'Export fitted surface', 'surface_fit.csv');
        if isequal(fname, 0); return; end
        fullPath = fullfile(fpath, fname);
        try
            T = table(xFlat, yFlat, zFlat, fitResult.zFit, fitResult.residuals, ...
                'VariableNames', {'x', 'y', 'z_data', 'z_fit', 'residual'});
            writetable(T, fullPath);
            lblStatus.Text = ['Exported to ' fname];
        catch ME
            lblStatus.Text = ['Export error: ' ME.message];
        end
    end

end
