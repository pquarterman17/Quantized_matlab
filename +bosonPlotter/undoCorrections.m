function undoCorrections(appData, fig, ui, callbacks)
%UNDOCORRECTIONS  Restore the previous correction state from the undo stack.
%
% Syntax
%   bosonPlotter.undoCorrections(appData, fig, ui, callbacks)
%
% Behaviour
%   Pops the last state from the active dataset's multi-level undoStack
%   (up to 5 levels), or falls back to the legacy single undoState field.
%   Restores all correction, trim, normalisation, derivative, and
%   magnetometry parameters both on the dataset struct and on the UI
%   controls, then triggers a plot refresh.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutated: datasets)
%   fig       - Main BosonPlotter figure handle (for uialert parent)
%   ui        - Struct with widget handles: efXOffset, efYOffset, efBGSlope,
%               efBGIntercept, cbSmooth, efSmoothWin, ddSmoothMethod,
%               efXTrimMin, efXTrimMax, ddNormalize, ddDerivative,
%               efSampleMass, efSampleWidth, efSampleHeight, ddDimUnit,
%               efSampleThick, ddThickUnit, ddMomentUnit, ddFieldUnit,
%               ddUnitSystem
%   callbacks - Struct of function handles:
%                 .onPlot()

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig,'Load a file first.','No data');
        return;
    end

    ds = appData.datasets{appData.activeIdx};

    % Pop from multi-level stack if available, else fall back to single undoState
    hasStack = isfield(ds, 'undoStack') && iscell(ds.undoStack) && ~isempty(ds.undoStack);
    hasSingle = isfield(ds, 'undoState') && isstruct(ds.undoState) && ~isempty(fieldnames(ds.undoState));
    if ~hasStack && ~hasSingle
        uialert(fig, 'No previous correction state to restore.', 'Undo unavailable');
        return;
    end

    if hasStack
        undoState = ds.undoStack{end};
        ds.undoStack(end) = [];  % pop
    else
        undoState = ds.undoState;
        ds.undoState = struct();
    end

    % Restore all correction state from the saved undo state
    ds.corrData      = undoState.corrData;
    if isfield(undoState, 'mask'), ds.mask = undoState.mask; end
    ds.xOff          = undoState.xOff;
    ds.yOff          = undoState.yOff;
    ds.bgSlope       = undoState.bgSlope;
    ds.bgInt         = undoState.bgInt;
    ds.smoothEnabled = undoState.smoothEnabled;
    ds.smoothWindow  = undoState.smoothWindow;
    ds.smoothMethod  = undoState.smoothMethod;
    if isfield(undoState, 'xTrimMin'), ds.xTrimMin = undoState.xTrimMin; end
    if isfield(undoState, 'xTrimMax'), ds.xTrimMax = undoState.xTrimMax; end
    if isfield(undoState, 'normMethod'), ds.normMethod = undoState.normMethod; end
    if isfield(undoState, 'bgPoly'), ds.bgPoly = undoState.bgPoly; end
    if isfield(undoState, 'derivativeMode'), ds.derivativeMode = undoState.derivativeMode; end
    % Magnetometry undo restore
    if isfield(undoState, 'sampleMass'),  ds.sampleMass  = undoState.sampleMass;  end
    if isfield(undoState, 'sampleWidth'), ds.sampleWidth = undoState.sampleWidth; end
    if isfield(undoState, 'sampleHeight'),ds.sampleHeight= undoState.sampleHeight;end
    if isfield(undoState, 'dimUnit'),     ds.dimUnit     = undoState.dimUnit;     end
    if isfield(undoState, 'sampleThick'), ds.sampleThick = undoState.sampleThick; end
    if isfield(undoState, 'thickUnit'),   ds.thickUnit   = undoState.thickUnit;   end
    if isfield(undoState, 'momentUnit'),  ds.momentUnit  = undoState.momentUnit;  end
    if isfield(undoState, 'fieldUnit'),   ds.fieldUnit   = undoState.fieldUnit;   end
    if isfield(undoState, 'unitSystem'),  ds.unitSystem  = undoState.unitSystem;  end

    % Update appData
    appData.datasets{appData.activeIdx} = ds;

    % Sync UI fields to the restored state
    ui.efXOffset.Value      = ds.xOff;
    ui.efYOffset.Value      = ds.yOff;
    ui.efBGSlope.Value      = ds.bgSlope;
    ui.efBGIntercept.Value  = ds.bgInt;
    ui.cbSmooth.Value       = ds.smoothEnabled;
    ui.efSmoothWin.Value    = ds.smoothWindow;
    ui.ddSmoothMethod.Value = ds.smoothMethod;
    ui.efXTrimMin.Value     = nan2str(ds.xTrimMin);
    ui.efXTrimMax.Value     = nan2str(ds.xTrimMax);
    ui.ddNormalize.Value    = ds.normMethod;
    if isfield(ds, 'derivativeMode')
        ui.ddDerivative.Value = ds.derivativeMode;
    end
    % Magnetometry UI sync
    ui.efSampleMass.Value   = guiTernary(isfield(ds,'sampleMass'),   ds.sampleMass,   0);
    ui.efSampleWidth.Value  = guiTernary(isfield(ds,'sampleWidth'),  ds.sampleWidth,  0);
    ui.efSampleHeight.Value = guiTernary(isfield(ds,'sampleHeight'), ds.sampleHeight, 0);
    ui.ddDimUnit.Value      = guiTernary(isfield(ds,'dimUnit'),      ds.dimUnit,      'mm');
    ui.efSampleThick.Value  = guiTernary(isfield(ds,'sampleThick'),  ds.sampleThick,  0);
    ui.ddThickUnit.Value    = guiTernary(isfield(ds,'thickUnit'),    ds.thickUnit,    'nm');
    ui.ddMomentUnit.Value   = guiTernary(isfield(ds,'momentUnit'),   ds.momentUnit,   'emu');
    ui.ddFieldUnit.Value    = guiTernary(isfield(ds,'fieldUnit'),    ds.fieldUnit,    'Oe');
    ui.ddUnitSystem.Value   = guiTernary(isfield(ds,'unitSystem'),   ds.unitSystem,   'CGS');

    % Refresh the plot
    callbacks.onPlot();
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m module-level scope)
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function s = nan2str(x)
    if isnan(x), s = ''; else, s = num2str(x); end
end
