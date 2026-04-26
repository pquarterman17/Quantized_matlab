function applyParserAnalysisConfig(pName, appData, ui, CROW, peakFig, callbacks)
%APPLYPARSERANALYSISCONFIG  Relabel Analysis panel controls for data type.
%
% Syntax
%   bosonPlotter.applyParserAnalysisConfig(pName, appData, ui, CROW, peakFig, callbacks)
%
% Inputs
%   pName     - Parser name string, e.g. 'importRigaku_raw', 'importQDVSM'
%   appData   - bosonPlotter.AppState handle (mutated: peakMode, corrPanelWidth)
%   ui        - Widget handle struct built in BosonPlotter initialisation
%   CROW      - Struct of corrGL row-index constants (BGFILE, BGSUBTR, ASYM1, ASYM2)
%   peakFig   - Peak analysis figure handle (may be closed/invalid)
%   callbacks - Struct of function handles:
%                 .configurePeakWindowForMode(mode)
%                 .showMagSection(tf)
%                 .is2DDataset(ds)
%                 .updateUndoButtons()
%
% Notes
%   Uses CROW row-index constants defined at corrGL creation in BosonPlotter.
%   Called by the nested updateControlsForActiveDataset and resolvedCorrStyle.

    % ── Common row-height setup for non-neutron modes ──
    % Show BG file rows only if section not collapsed; hide asymmetry
    showBGFileRows = ~appData.sectionCollapsed.bgFile;
    bgFileH = 22 * showBGFileRows;

    switch pName
        case {'importRigaku_raw', 'importXRDML', 'importBruker'}
            % Re-enable controls for non-neutron case
            for hh = {ui.efXOffset, ui.efYOffset, ui.efBGSlope, ui.efBGIntercept, ...
                      ui.btnApply, ui.btnReset, ui.btnApplyAll, ui.btnUndo, ...
                      ui.cbSmooth, ui.efSmoothWin, ui.ddSmoothMethod, ui.cbSmoothPreview, ...
                      ui.efXTrimMin, ui.efXTrimMax, ui.ddNormalize}
                hh{1}.Enable = 'on'; %#ok<FXSET>
            end
            ui.analysisPanel.Title   = 'Analysis & Corrections  —  XRD';
            ui.lblXOff.Text          = '2θ Offset (°):';
            ui.efXOffset.Tooltip     = '2θ-offset: 2θ_corrected = 2θ − this value  (0 = no shift)';
            ui.lblYOff.Text          = 'Intens. Floor:';
            ui.efYOffset.Tooltip     = ['Intensity floor subtracted from all counts ' ...
                                     'after BG removal  (0 = no shift)'];
            ui.lblBGSlope.Text       = 'BG Slope:';
            ui.efBGSlope.Tooltip     = 'Linear BG slope m: I_BG = m·2θ + b  (0 = no BG subtraction)';
            ui.lblBGInt.Text         = 'BG Intercept:';
            ui.efBGIntercept.Tooltip = 'Linear BG intercept b: I_BG = m·2θ + b  (0 = no BG subtraction)';
            % Show XRD interactive tools, hide generic ones
            ui.btnFitBG.Visible           = 'off';
            ui.btnPickY.Visible           = 'off';
            ui.btnYTranslate.Visible      = 'on';
            ui.btnAutoPeak.Visible        = 'on';
            ui.btnManualPeak.Visible      = 'on';
            ui.btnRemovePeakClick.Visible = 'on';
            ui.btnPeakWindow.Visible      = 'on';
            % Peak window mode — XRD
            appData.peakMode = 'xrd';
            callbacks.configurePeakWindowForMode('xrd');
            ui.analysisGL.ColumnWidth     = {appData.corrPanelWidth, '1x', 0, 210};
            % Hide asymmetry; respect BG file collapse state
            ui.corrGL.RowHeight{CROW.BGFILE}  = bgFileH;
            ui.corrGL.RowHeight{CROW.BGSUBTR} = bgFileH;
            ui.corrGL.RowHeight{CROW.ASYM1}   = 0;
            ui.corrGL.RowHeight{CROW.ASYM2}   = 0;
            % Hide magnetometry section (not applicable to XRD)
            callbacks.showMagSection(false);

        case {'importQDVSM', 'importMPMS', 'importLakeShore', 'importPPMS'}
            % Re-enable controls for magnetometry data
            for hh = {ui.efXOffset, ui.efYOffset, ui.efBGSlope, ui.efBGIntercept, ...
                      ui.btnApply, ui.btnReset, ui.btnApplyAll, ui.btnUndo, ...
                      ui.cbSmooth, ui.efSmoothWin, ui.ddSmoothMethod, ui.cbSmoothPreview, ...
                      ui.efXTrimMin, ui.efXTrimMax, ui.ddNormalize}
                hh{1}.Enable = 'on'; %#ok<FXSET>
            end
            switch pName
                case 'importPPMS',     magTitle = 'PPMS';
                case 'importMPMS',     magTitle = 'MPMS';
                case 'importLakeShore',magTitle = 'Lake Shore';
                otherwise,             magTitle = 'VSM';
            end
            ui.analysisPanel.Title   = ['Analysis & Corrections  —  ' magTitle];
            % Magnetometry-specific labels and tooltips
            ui.lblXOff.Text          = 'Field Offset:';
            ui.efXOffset.Tooltip     = 'Field offset: H_corrected = H − this value  (0 = no shift)';
            ui.lblYOff.Text          = 'Moment Offset:';
            ui.efYOffset.Tooltip     = ['Moment baseline shift applied after diamagnetic BG ' ...
                                     'subtraction  (0 = no shift)'];
            ui.lblBGSlope.Text       = 'Diamag. Slope:';
            ui.efBGSlope.Tooltip     = ['Diamagnetic susceptibility slope ' char(967) ': ' ...
                                     'M_BG = ' char(967) char(183) 'H + b  (0 = no subtraction).  ' ...
                                     'Use "Fit BG from Box" or "Auto BG" to estimate automatically.'];
            ui.lblBGInt.Text         = 'Diamag. Intcpt:';
            ui.efBGIntercept.Tooltip = ['Diamagnetic intercept b: M_BG = ' char(967) char(183) 'H + b  ' ...
                                     '(0 = no subtraction)'];
            % Magnetometry interactive tools: Fit BG + Est. Y Offset
            ui.btnFitBG.Visible           = 'on';
            ui.btnPickY.Visible           = 'on';
            ui.btnYTranslate.Visible      = 'off';
            ui.btnAutoPeak.Visible        = 'off';
            ui.btnManualPeak.Visible      = 'off';
            ui.btnRemovePeakClick.Visible = 'off';
            ui.btnPeakWindow.Visible      = 'off';
            appData.peakMode = 'none';
            ui.analysisGL.ColumnWidth     = {appData.corrPanelWidth, '1x', 0, 210};
            % Hide asymmetry; respect BG file collapse state; show mag section
            ui.corrGL.RowHeight{CROW.BGFILE}  = bgFileH;
            ui.corrGL.RowHeight{CROW.BGSUBTR} = bgFileH;
            ui.corrGL.RowHeight{CROW.ASYM1}   = 0;
            ui.corrGL.RowHeight{CROW.ASYM2}   = 0;
            callbacks.showMagSection(true);

        case {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'}
            ui.analysisPanel.Title = 'Analysis & Corrections  —  Neutron Reflectometry';
            ui.lblXOff.Text  = 'Q Offset:';
            ui.efXOffset.Tooltip = 'Q-offset: Q_corrected = Q − this value  (0 = no shift)';
            ui.lblYOff.Text  = 'R Scale:';
            ui.efYOffset.Tooltip = 'R scale factor: R_corrected = R × this value  (1.0 = no change)';
            for hh = {ui.efXOffset, ui.efYOffset, ui.btnApply, ui.btnReset, ui.btnApplyAll, ui.btnUndo, ...
                      ui.efXTrimMin, ui.efXTrimMax, ui.ddNormalize}
                hh{1}.Enable = 'on'; %#ok<FXSET>
            end
            for hh = {ui.efBGSlope, ui.efBGIntercept, ui.cbSmooth, ui.efSmoothWin, ui.ddSmoothMethod, ui.cbSmoothPreview}
                hh{1}.Enable = 'off'; %#ok<FXSET>
            end
            ui.lblBGSlope.Text = 'BG Slope:';
            ui.lblBGInt.Text   = 'BG Intercept:';
            ui.btnFitBG.Visible           = 'off';
            ui.btnPickY.Visible           = 'off';
            ui.btnYTranslate.Visible      = 'off';
            ui.btnAutoPeak.Visible        = 'off';
            ui.btnManualPeak.Visible      = 'off';
            ui.btnRemovePeakClick.Visible = 'off';
            ui.btnPeakWindow.Visible      = 'off';
            ui.btnApply.Tooltip = 'Apply Q offset / R scale, trim, and normalization to all polarizations from the same measurement';
            % Peak window mode — reflectometry
            appData.peakMode = 'reflectometry';
            callbacks.configurePeakWindowForMode('reflectometry');
            ui.analysisGL.ColumnWidth     = {appData.corrPanelWidth, '1x', 0, 210};
            % Hide BG file rows; asymmetry is now in Advanced Analysis popup
            ui.corrGL.RowHeight{CROW.BGFILE}  = 0;
            ui.corrGL.RowHeight{CROW.BGSUBTR} = 0;
            ui.corrGL.RowHeight{CROW.ASYM1}   = 0;
            ui.corrGL.RowHeight{CROW.ASYM2}   = 0;
            % Hide magnetometry section (not applicable to neutron)
            callbacks.showMagSection(false);

        case 'importSIMS'
            ui.analysisPanel.Title   = 'Analysis & Corrections  —  SIMS Depth Profile';
            ui.lblXOff.Text          = 'Depth Offset (nm):';
            ui.efXOffset.Tooltip     = 'Depth offset: depth_corrected = depth − this value  (0 = no shift)';
            ui.lblYOff.Text          = 'Conc. Floor:';
            ui.efYOffset.Tooltip     = 'Concentration floor subtracted from all values  (0 = no shift)';
            ui.lblBGSlope.Text       = 'BG Slope:';
            ui.lblBGInt.Text         = 'BG Intercept:';
            for hh = {ui.efXOffset, ui.efYOffset, ui.btnApply, ui.btnReset, ui.btnApplyAll, ui.btnUndo, ...
                      ui.cbSmooth, ui.efSmoothWin, ui.ddSmoothMethod, ui.cbSmoothPreview, ...
                      ui.efXTrimMin, ui.efXTrimMax, ui.ddNormalize}
                hh{1}.Enable = 'on'; %#ok<FXSET>
            end
            for hh = {ui.efBGSlope, ui.efBGIntercept}
                hh{1}.Enable = 'off'; %#ok<FXSET>
            end
            ui.btnFitBG.Visible           = 'off';
            ui.btnPickY.Visible           = 'off';
            ui.btnYTranslate.Visible      = 'off';
            ui.btnAutoPeak.Visible        = 'off';
            ui.btnManualPeak.Visible      = 'off';
            ui.btnRemovePeakClick.Visible = 'off';
            ui.btnPeakWindow.Visible      = 'off';
            appData.peakMode = 'none';
            ui.analysisGL.ColumnWidth     = {appData.corrPanelWidth, '1x', 0, 210};
            % Hide asymmetry; respect BG file collapse state
            ui.corrGL.RowHeight{CROW.BGFILE}  = bgFileH;
            ui.corrGL.RowHeight{CROW.BGSUBTR} = bgFileH;
            ui.corrGL.RowHeight{CROW.ASYM1}   = 0;
            ui.corrGL.RowHeight{CROW.ASYM2}   = 0;
            % Hide magnetometry section (not applicable to SIMS)
            callbacks.showMagSection(false);

        otherwise  % importCSV, importExcel, unknown — generic labels
            % Re-enable controls for non-neutron case
            for hh = {ui.efXOffset, ui.efYOffset, ui.efBGSlope, ui.efBGIntercept, ...
                      ui.btnApply, ui.btnReset, ui.btnApplyAll, ui.btnUndo, ...
                      ui.cbSmooth, ui.efSmoothWin, ui.ddSmoothMethod, ui.cbSmoothPreview, ...
                      ui.efXTrimMin, ui.efXTrimMax, ui.ddNormalize}
                hh{1}.Enable = 'on'; %#ok<FXSET>
            end
            ui.analysisPanel.Title   = 'Analysis & Corrections';
            ui.lblXOff.Text          = 'X Offset:';
            ui.efXOffset.Tooltip     = 'X-offset: x_corrected = x − this value  (0 = no shift)';
            ui.lblYOff.Text          = 'Y Offset:';
            ui.efYOffset.Tooltip     = 'Y-offset: applied after BG subtraction  (0 = no shift)';
            ui.lblBGSlope.Text       = 'BG Slope:';
            ui.efBGSlope.Tooltip     = 'Linear BG slope m: y_BG = m·x + b  (0 = no BG subtraction)';
            ui.lblBGInt.Text         = 'BG Intercept:';
            ui.efBGIntercept.Tooltip = 'Linear BG intercept b: y_BG = m·x + b  (0 = no BG subtraction)';
            ui.btnFitBG.Visible           = 'on';
            ui.btnPickY.Visible           = 'on';
            ui.btnYTranslate.Visible      = 'off';
            ui.btnAutoPeak.Visible        = 'off';
            ui.btnManualPeak.Visible      = 'off';
            ui.btnRemovePeakClick.Visible = 'off';
            ui.btnPeakWindow.Visible      = 'off';
            appData.peakMode = 'none';
            ui.analysisGL.ColumnWidth     = {appData.corrPanelWidth, '1x', 0, 210};
            % Hide asymmetry; respect BG file collapse state
            ui.corrGL.RowHeight{CROW.BGFILE}  = bgFileH;
            ui.corrGL.RowHeight{CROW.BGSUBTR} = bgFileH;
            ui.corrGL.RowHeight{CROW.ASYM1}   = 0;
            ui.corrGL.RowHeight{CROW.ASYM2}   = 0;
            % Hide magnetometry section for generic data
            callbacks.showMagSection(false);
    end

    % ── Hide peak window when switching to a non-peak mode ───────────
    if strcmp(appData.peakMode, 'none') && isvalid(peakFig)
        peakFig.Visible = 'off';
    end

    % ── 2D area-detector override (applied after the switch) ─────────
    % When the active dataset contains a 2D map, hide the peak/map and
    % corrections (not meaningful for raw intensity maps) and show the
    % map2D controls instead.
    is2D_active = appData.activeIdx >= 1 && ~isempty(appData.datasets) && ...
                  callbacks.is2DDataset(appData.datasets{appData.activeIdx});
    if is2D_active
        ui.map2DPanel.Visible = 'on';
        % Col 2 collapses to 0 so the heatmap (col 3) can take the freed
        % horizontal space in 2D mode — there's no axes/data-table panel
        % to keep visible there now.
        ui.analysisGL.ColumnWidth = {appData.corrPanelWidth, 0, '1x', 180};
        ui.dataTablePanel.Visible   = 'off';
        % Disable all corrections — not meaningful for raw 2D maps
        for hh = {ui.efXOffset, ui.efYOffset, ui.efBGSlope, ui.efBGIntercept, ...
                  ui.btnApply, ui.btnReset, ui.btnApplyAll, ui.btnUndo, ...
                  ui.cbSmooth, ui.efSmoothWin, ui.ddSmoothMethod, ui.cbSmoothPreview, ...
                  ui.efXTrimMin, ui.efXTrimMax, ui.ddNormalize}
            hh{1}.Enable = 'off'; %#ok<FXSET>
        end
        ui.btnFitBG.Visible           = 'off';
        ui.btnPickY.Visible           = 'off';
        ui.btnYTranslate.Visible      = 'off';
        ui.btnAutoPeak.Visible        = 'off';
        ui.btnManualPeak.Visible      = 'off';
        ui.btnRemovePeakClick.Visible = 'off';
        ui.btnPeakWindow.Visible      = 'off';
        if isvalid(peakFig), peakFig.Visible = 'off'; end
        ui.analysisPanel.Title = 'Analysis  —  XRD 2D Map';
    else
        ui.map2DPanel.Visible = 'off';
        ui.dataTablePanel.Visible   = 'on';
    end

    % Sync undo/redo button state after layout changes (enable flags above
    % may have overridden the UndoManager-managed state for btnUndo).
    callbacks.updateUndoButtons();
end
