function onApplyCorrections(appData, ui, callbacks)
%ONAPPLYCORRECTIONS  Apply user-configured corrections to the active dataset.
%
% Syntax
%   bosonPlotter.onApplyCorrections(appData, ui, callbacks)
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutated: datasets, activeIdx)
%   ui        - Widget handle struct built in BosonPlotter initialisation
%   callbacks - Struct of function handles:
%                 .onPlot()
%                 .setStatus(msg)
%                 .logGUIError(title, msg, ME)
%                 .markCorrectionsDirty()
%                 .updateApplyButtonStyle()
%                 .recordAction(cmd)
%                 .pushUndoCorrectionEntry(dsIdx, prev, next, label)
%                 .updateUndoButtons()
%                 .magSampleVolume_cm3()   — reads ui widget values
%                 .str2num_trim(s)
%                 .isNeutronParser(name)
%                 .neutronBaseName(filepath)
%                 .BTN_FG               — colour constant [r g b]
%                 .BTN_PRIMARY          — colour constant [r g b]
%                 .fig                  — figure handle (for uialert)
%
% Notes
%   Reads correction parameters from ui widgets, delegates computation to
%   bosonPlotter.correctionParams and bosonPlotter.applyCorrections, then
%   propagates corrections to polarization siblings for neutron datasets.

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(callbacks.fig, 'Load a file first.', 'No data');
        return;
    end
    ds       = appData.datasets{appData.activeIdx};
    % 2D datasets have corrections disabled in the UI — skip the full
    % struct copy (corrData = d) that would otherwise double memory.
    if is2DDataset_(ds), return; end
    d        = ds.data;
    xOff     = ui.efXOffset.Value;
    yOff     = ui.efYOffset.Value;
    bgSlope  = ui.efBGSlope.Value;
    bgIntcpt = ui.efBGIntercept.Value;

    % ════════════════════════════════════════════════════════════════════
    %  Save undo state before applying new corrections
    % ════════════════════════════════════════════════════════════════════
    undoState.corrData       = ds.corrData;
    undoState.mask           = guiTernary_(isfield(ds,'mask'), ds.mask, true(size(ds.data.time)));
    undoState.xOff           = ds.xOff;
    undoState.yOff           = ds.yOff;
    undoState.bgSlope        = ds.bgSlope;
    undoState.bgInt          = ds.bgInt;
    undoState.bgPoly         = guiTernary_(isfield(ds,'bgPoly'), ds.bgPoly, []);
    undoState.smoothEnabled  = ds.smoothEnabled;
    undoState.smoothWindow   = ds.smoothWindow;
    undoState.smoothMethod   = ds.smoothMethod;
    undoState.xTrimMin       = ds.xTrimMin;
    undoState.xTrimMax       = ds.xTrimMax;
    undoState.normMethod     = ds.normMethod;
    if isfield(ds, 'derivativeMode')
        undoState.derivativeMode = ds.derivativeMode;
    else
        undoState.derivativeMode = 'None';
    end
    % Magnetometry undo fields
    undoState.sampleMass  = guiTernary_(isfield(ds,'sampleMass'),  ds.sampleMass,  0);
    undoState.sampleWidth = guiTernary_(isfield(ds,'sampleWidth'), ds.sampleWidth, 0);
    undoState.sampleHeight= guiTernary_(isfield(ds,'sampleHeight'),ds.sampleHeight,0);
    undoState.dimUnit     = guiTernary_(isfield(ds,'dimUnit'),     ds.dimUnit,     'mm');
    undoState.sampleThick = guiTernary_(isfield(ds,'sampleThick'), ds.sampleThick, 0);
    undoState.thickUnit   = guiTernary_(isfield(ds,'thickUnit'),   ds.thickUnit,   'nm');
    undoState.momentUnit  = guiTernary_(isfield(ds,'momentUnit'),  ds.momentUnit,  'emu');
    undoState.fieldUnit   = guiTernary_(isfield(ds,'fieldUnit'),   ds.fieldUnit,   'Oe');
    undoState.unitSystem  = guiTernary_(isfield(ds,'unitSystem'),  ds.unitSystem,  'CGS');
    % Multi-level undo stack (#13): push onto stack, cap at 5
    if ~isfield(ds, 'undoStack') || ~iscell(ds.undoStack)
        ds.undoStack = {};
    end
    ds.undoStack{end+1} = undoState;
    if numel(ds.undoStack) > 5
        ds.undoStack = ds.undoStack(end-4:end);
    end
    ds.undoState = undoState;  % keep single-state for backward compat

    % ════════════════════════════════════════════════════════════════════
    %  Apply corrections via extracted pipeline
    % ════════════════════════════════════════════════════════════════════
    xTrimMin = callbacks.str2num_trim(ui.efXTrimMin.Value);
    xTrimMax = callbacks.str2num_trim(ui.efXTrimMax.Value);
    sampleVol = 0;
    isMag = ismember(guiTernary_(isfield(ds,'parserName'), ds.parserName, ''), ...
            {'importQDVSM','importPPMS','importMPMS','importLakeShore'});
    if isMag
        sampleVol = callbacks.magSampleVolume_cm3();
    end
    uiVals = struct('xOff', xOff, 'yOff', yOff, ...
        'bgSlope', bgSlope, 'bgInt', bgIntcpt, ...
        'xTrimMin', xTrimMin, 'xTrimMax', xTrimMax, ...
        'smoothEnabled', ui.cbSmooth.Value, ...
        'smoothWindow', ui.efSmoothWin.Value, ...
        'smoothMethod', ui.ddSmoothMethod.Value, ...
        'normMethod', ui.ddNormalize.Value, ...
        'derivativeMode', ui.ddDerivative.Value, ...
        'fieldUnit', ui.ddFieldUnit.Value, ...
        'momentUnit', ui.ddMomentUnit.Value, ...
        'sampleMass', ui.efSampleMass.Value, ...
        'sampleVolume', sampleVol);
    corrParams = bosonPlotter.correctionParams(ds, uiVals);
    bgArgs = {};
    if ui.cbSubtractBG.Value && ~isempty(appData.bgDataset)
        bgArgs = {'BgDataset', appData.bgDataset, ...
                  'BgInterp', ui.ddBGInterp.Value};
    end
    corrData = bosonPlotter.applyCorrections(d, corrParams, bgArgs{:});

    ds.corrData      = corrData;
    ds.xOff          = xOff;
    ds.yOff          = yOff;
    ds.bgSlope       = bgSlope;
    ds.bgInt         = bgIntcpt;
    % bgPoly already set on ds by onBGMouseUp; preserve it here (don't overwrite)
    ds.smoothEnabled = ui.cbSmooth.Value;
    ds.smoothWindow  = ui.efSmoothWin.Value;
    ds.smoothMethod  = ui.ddSmoothMethod.Value;
    ds.xTrimMin      = xTrimMin;
    ds.xTrimMax      = xTrimMax;
    ds.normMethod      = ui.ddNormalize.Value;
    ds.derivativeMode  = ui.ddDerivative.Value;
    % Magnetometry sample parameters
    ds.sampleMass    = ui.efSampleMass.Value;
    ds.sampleWidth   = ui.efSampleWidth.Value;
    ds.sampleHeight  = ui.efSampleHeight.Value;
    ds.dimUnit       = ui.ddDimUnit.Value;
    ds.sampleThick   = ui.efSampleThick.Value;
    ds.thickUnit     = ui.ddThickUnit.Value;
    ds.momentUnit    = ui.ddMomentUnit.Value;
    ds.fieldUnit     = ui.ddFieldUnit.Value;
    ds.unitSystem    = ui.ddUnitSystem.Value;
    appData.datasets{appData.activeIdx} = ds;

    % ════════════════════════════════════════════════════════════════════
    %  Cross-polarization propagation (neutron data only)
    %  Apply same corrections to all datasets sharing the same source
    %  file (matched by stripping polarization suffixes).
    % ════════════════════════════════════════════════════════════════════
    if isfield(ds, 'parserName') && callbacks.isNeutronParser(ds.parserName)
        activeBase = callbacks.neutronBaseName(ds.filepath);
        normVal    = ui.ddNormalize.Value;
        for pki = 1:numel(appData.datasets)
            if pki == appData.activeIdx, continue; end
            pds = appData.datasets{pki};
            if ~isfield(pds, 'parserName') || ~callbacks.isNeutronParser(pds.parserName)
                continue;
            end
            if ~strcmp(callbacks.neutronBaseName(pds.filepath), activeBase)
                continue;
            end
            % Save undo state for this sibling
            pUndo.corrData      = pds.corrData;
            pUndo.xOff          = pds.xOff;
            pUndo.yOff          = pds.yOff;
            pUndo.bgSlope       = pds.bgSlope;
            pUndo.bgInt         = pds.bgInt;
            pUndo.smoothEnabled = pds.smoothEnabled;
            pUndo.smoothWindow  = pds.smoothWindow;
            pUndo.smoothMethod  = pds.smoothMethod;
            pUndo.xTrimMin      = pds.xTrimMin;
            pUndo.xTrimMax      = pds.xTrimMax;
            pUndo.normMethod    = pds.normMethod;
            pds.undoState       = pUndo;
            % Apply same correction pipeline via extracted function
            pUiVals = struct('xOff', xOff, 'yOff', yOff, ...
                'bgSlope', 0, 'bgInt', 0, ...
                'xTrimMin', xTrimMin, 'xTrimMax', xTrimMax, ...
                'smoothEnabled', false, 'smoothWindow', 5, ...
                'smoothMethod', 'Moving', ...
                'normMethod', normVal, 'derivativeMode', 'None', ...
                'fieldUnit', 'Oe', 'momentUnit', 'emu');
            pParams = bosonPlotter.correctionParams(pds, pUiVals);
            pCorr = bosonPlotter.applyCorrections(pds.data, pParams);
            pds.corrData   = pCorr;
            pds.xOff       = xOff;
            pds.yOff       = yOff;
            pds.bgSlope    = 0;
            pds.bgInt      = 0;
            pds.xTrimMin   = xTrimMin;
            pds.xTrimMax   = xTrimMax;
            pds.normMethod = normVal;
            appData.datasets{pki} = pds;
        end
    end

    % Auto-set the save path for the active dataset
    [fpath, fname, ~] = fileparts(ds.filepath);
    ui.efSavePath.Value = fullfile(fpath, [fname, '_corrected.csv']);

    % Reset dirty-state indicator on Apply button
    ui.btnApply.Text      = 'Apply Corrections';
    ui.btnApply.FontColor = callbacks.BTN_FG;

    % Record correction parameters in macro
    callbacks.recordAction(sprintf("%% Apply corrections: XOff=%.6g YOff=%.6g BGSlope=%.6g BGInt=%.6g Smooth=%s Norm=%s Deriv=%s", ...
        xOff, yOff, bgSlope, bgIntcpt, ...
        string(ui.cbSmooth.Value), ui.ddNormalize.Value, ui.ddDerivative.Value));

    % ── Push UndoManager entry for unlimited undo/redo ───────────────
    % undoState (prevState) captured above; build newState from the
    % just-applied values so Redo can re-apply the same correction.
    newState.corrData       = ds.corrData;
    newState.mask           = guiTernary_(isfield(ds,'mask'), ds.mask, true(size(ds.data.time)));
    newState.xOff           = ds.xOff;
    newState.yOff           = ds.yOff;
    newState.bgSlope        = ds.bgSlope;
    newState.bgInt          = ds.bgInt;
    newState.bgPoly         = guiTernary_(isfield(ds,'bgPoly'), ds.bgPoly, []);
    newState.smoothEnabled  = ds.smoothEnabled;
    newState.smoothWindow   = ds.smoothWindow;
    newState.smoothMethod   = ds.smoothMethod;
    newState.xTrimMin       = ds.xTrimMin;
    newState.xTrimMax       = ds.xTrimMax;
    newState.normMethod     = ds.normMethod;
    newState.derivativeMode = ds.derivativeMode;
    newState.sampleMass     = guiTernary_(isfield(ds,'sampleMass'),  ds.sampleMass,  0);
    newState.sampleWidth    = guiTernary_(isfield(ds,'sampleWidth'), ds.sampleWidth, 0);
    newState.sampleHeight   = guiTernary_(isfield(ds,'sampleHeight'),ds.sampleHeight,0);
    newState.dimUnit        = guiTernary_(isfield(ds,'dimUnit'),     ds.dimUnit,     'mm');
    newState.sampleThick    = guiTernary_(isfield(ds,'sampleThick'), ds.sampleThick, 0);
    newState.thickUnit      = guiTernary_(isfield(ds,'thickUnit'),   ds.thickUnit,   'nm');
    newState.momentUnit     = guiTernary_(isfield(ds,'momentUnit'),  ds.momentUnit,  'emu');
    newState.fieldUnit      = guiTernary_(isfield(ds,'fieldUnit'),   ds.fieldUnit,   'Oe');
    newState.unitSystem     = guiTernary_(isfield(ds,'unitSystem'),  ds.unitSystem,  'CGS');
    activeIdxAtPush = appData.activeIdx;
    callbacks.pushUndoCorrectionEntry(activeIdxAtPush, undoState, newState, 'Apply Corrections');

    callbacks.onPlot();
end

% ════════════════════════════════════════════════════════════════════════
%  Module-level helpers (duplicated from BosonPlotter module-level helpers
%  to avoid closure dependency)
% ════════════════════════════════════════════════════════════════════════

function out = guiTernary_(cond, ifTrue, ifFalse)
%GUITERNARY_  Inline ternary: return ifTrue when cond is true, else ifFalse.
    if cond
        out = ifTrue;
    else
        out = ifFalse;
    end
end

function tf = is2DDataset_(ds)
%IS2DDATASET_  True when the dataset contains a 2D area-detector map.
    tf = isfield(ds, 'data') && ...
         isfield(ds.data, 'metadata') && ...
         isfield(ds.data.metadata, 'parserSpecific') && ...
         isfield(ds.data.metadata.parserSpecific, 'is2D') && ...
         ds.data.metadata.parserSpecific.is2D;
end
