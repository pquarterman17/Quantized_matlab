function resetCorrections(appData, fig, ui, callbacks)
%RESETCORRECTIONS  Discard all corrections on the active dataset.
%
% Syntax
%   bosonPlotter.resetCorrections(appData, fig, ui, callbacks)
%
% Behaviour
%   Prompts the user to confirm if corrections have been applied, then
%   resets all correction, trim, normalise, and magnetometry widgets on
%   the UI, restores the dataset's correction state to neutral, and
%   refreshes the plot.  For neutron parsers the neutral Y offset is
%   1.0 (multiplicative); otherwise 0.0 (additive).
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutated: datasets, selectedPeakIdx)
%   fig       - Main BosonPlotter figure handle (for uiconfirm parent)
%   ui        - Struct with widget handles: efXOffset, efYOffset, efBGSlope,
%               efBGIntercept, ddBGOrder, cbSmooth, efSmoothWin, ddSmoothMethod,
%               efXTrimMin, efXTrimMax, ddNormalize, efSavePath, efSampleMass,
%               efSampleWidth, efSampleHeight, ddDimUnit, efSampleThick,
%               ddThickUnit, ddMomentUnit, ddFieldUnit, ddUnitSystem
%   callbacks - Struct of function handles:
%                 .cancelInteractions()
%                 .refreshPeakTable()
%                 .onPlot()

    % Guard: confirm if corrections have been applied
    if appData.activeIdx >= 1 && ~isempty(appData.datasets)
        dsReset = appData.datasets{appData.activeIdx};
        if ~isempty(dsReset.corrData)
            sel = bosonPlotter.quietConfirm(fig, ...
                'Discard all corrections for the active dataset?', ...
                'Reset Corrections', 'Options', {'Reset', 'Cancel'}, ...
                'DefaultOption', 2, 'CancelOption', 2);
            if ~strcmp(sel, 'Reset'), return; end
        end
    end
    % Determine neutral yOff: 1.0 for neutron (multiplicative), 0 for others (additive)
    isNeutronReset = false;
    if appData.activeIdx >= 1 && ~isempty(appData.datasets)
        dsCheck = appData.datasets{appData.activeIdx};
        isNeutronReset = isfield(dsCheck, 'parserName') && isNeutronParser(dsCheck.parserName);
    end
    yOffDefault = guiTernary(isNeutronReset, 1, 0);

    ui.efXOffset.Value     = 0;
    ui.efYOffset.Value     = yOffDefault;
    ui.efBGSlope.Value     = 0;
    ui.efBGIntercept.Value = 0;
    ui.ddBGOrder.Value     = 'Linear';
    ui.cbSmooth.Value      = false;
    ui.efSmoothWin.Value   = 5;
    ui.ddSmoothMethod.Value = 'Moving';
    ui.efXTrimMin.Value    = '';
    ui.efXTrimMax.Value    = '';
    ui.ddNormalize.Value   = 'None';
    ui.efSavePath.Value    = '';
    % Reset magnetometry fields
    ui.efSampleMass.Value   = 0;
    ui.efSampleWidth.Value  = 0;
    ui.efSampleHeight.Value = 0;
    ui.ddDimUnit.Value      = 'mm';
    ui.efSampleThick.Value  = 0;
    ui.ddThickUnit.Value    = 'nm';
    ui.ddMomentUnit.Value   = 'emu';
    ui.ddFieldUnit.Value    = 'Oe';
    ui.ddUnitSystem.Value   = 'CGS';

    if appData.activeIdx >= 1 && ~isempty(appData.datasets)
        ds               = appData.datasets{appData.activeIdx};
        ds.corrData      = [];
        ds.mask          = true(size(ds.data.time));
        ds.xOff          = 0;
        ds.yOff          = yOffDefault;
        ds.bgSlope       = 0;
        ds.bgInt         = 0;
        ds.bgPoly        = [];
        ds.smoothEnabled = false;
        ds.smoothWindow  = 5;
        ds.smoothMethod  = 'Moving';
        ds.xTrimMin      = NaN;
        ds.xTrimMax      = NaN;
        ds.normMethod    = 'None';
        ds.sampleMass    = 0;
        ds.sampleWidth   = 0;
        ds.sampleHeight  = 0;
        ds.dimUnit       = 'mm';
        ds.sampleThick   = 0;
        ds.thickUnit     = 'nm';
        ds.momentUnit    = 'emu';
        ds.fieldUnit     = 'Oe';
        ds.unitSystem    = 'CGS';
        ds.peaks         = struct('center',{},'fwhm',{},'height',{},'area',{}, ...
                                  'xRange',{},'status',{},'bg',{},'model',{},'eta',{});
        appData.datasets{appData.activeIdx} = ds;
        appData.selectedPeakIdx = 0;
    end

    callbacks.cancelInteractions();
    callbacks.refreshPeakTable();
    callbacks.onPlot();
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m module-level scope)
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function tf = isNeutronParser(pName)
    tf = ismember(pName, {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'});
end
