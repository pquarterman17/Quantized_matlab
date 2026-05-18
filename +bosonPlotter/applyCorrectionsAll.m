function applyCorrectionsAll(appData, fig, ui, callbacks)
%APPLYCORRECTIONSALL  Apply the current UI corrections to every dataset.
%
% Syntax
%   bosonPlotter.applyCorrectionsAll(appData, fig, ui, callbacks)
%
% Behaviour
%   Reads correction parameters from the UI widgets, then iterates every
%   dataset: saves the current correction state into the dataset's
%   `.undoState` field and writes the newly corrected trace back into
%   `.corrData`, `.xOff`, ... etc.  Uses the shared correctionParams /
%   applyCorrections pipeline from the +bosonPlotter package.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutated: datasets, model)
%   fig       - Main BosonPlotter figure handle (for uialert parent,
%               pointer changes, drawnow)
%   ui        - Struct with widget handles: efXOffset, efYOffset, efBGSlope,
%               efBGIntercept, cbSmooth, efSmoothWin, ddSmoothMethod,
%               efXTrimMin, efXTrimMax, ddNormalize, cbSubtractBG, ddBGInterp
%   callbacks - Struct of function handles:
%                 .setStatus(msg)
%                 .onPlot()

    if isempty(appData.datasets) || appData.activeIdx < 1
        bosonPlotter.quietAlert(fig,'Load a file first.','No data');
        return;
    end

    callbacks.setStatus('Applying corrections to all datasets...');
    fig.Pointer = 'watch';
    drawnow;

    % Get current correction parameters from UI
    xOff     = ui.efXOffset.Value;
    yOff     = ui.efYOffset.Value;
    bgSlope  = ui.efBGSlope.Value;
    bgIntcpt = ui.efBGIntercept.Value;
    smoothEnabled = ui.cbSmooth.Value;
    smoothWin = ui.efSmoothWin.Value;
    smoothMeth = ui.ddSmoothMethod.Value;
    xTrimMin = str2num_trim(ui.efXTrimMin.Value);
    xTrimMax = str2num_trim(ui.efXTrimMax.Value);
    normVal  = ui.ddNormalize.Value;

    % Apply to all datasets
    for di = 1:numel(appData.datasets)
        ds = appData.datasets{di};
        d = ds.data;

        % Save undo state (same logic as onApplyCorrections)
        undoState.corrData       = ds.corrData;
        undoState.mask           = guiTernary(isfield(ds,'mask'), ds.mask, true(size(ds.data.time)));
        undoState.xOff           = ds.xOff;
        undoState.yOff           = ds.yOff;
        undoState.bgSlope        = ds.bgSlope;
        undoState.bgInt          = ds.bgInt;
        undoState.bgPoly         = guiTernary(isfield(ds,'bgPoly'), ds.bgPoly, []);
        undoState.smoothEnabled  = ds.smoothEnabled;
        undoState.smoothWindow   = ds.smoothWindow;
        undoState.smoothMethod   = ds.smoothMethod;
        undoState.xTrimMin       = ds.xTrimMin;
        undoState.xTrimMax       = ds.xTrimMax;
        undoState.normMethod     = ds.normMethod;
        ds.undoState = undoState;

        % Apply corrections via extracted pipeline
        uiVals = struct('xOff', xOff, 'yOff', yOff, ...
            'bgSlope', bgSlope, 'bgInt', bgIntcpt, ...
            'xTrimMin', xTrimMin, 'xTrimMax', xTrimMax, ...
            'smoothEnabled', smoothEnabled, ...
            'smoothWindow', smoothWin, ...
            'smoothMethod', smoothMeth, ...
            'normMethod', normVal, ...
            'derivativeMode', 'None', ...
            'fieldUnit', 'Oe', 'momentUnit', 'emu');
        corrParams = bosonPlotter.correctionParams(ds, uiVals);
        bgArgs = {};
        if ui.cbSubtractBG.Value && ~isempty(appData.bgDataset)
            bgArgs = {'BgDataset', appData.bgDataset, ...
                      'BgInterp', ui.ddBGInterp.Value};
        end
        corrData = bosonPlotter.applyCorrections(d, corrParams, bgArgs{:});

        % Save corrected data
        ds.corrData      = corrData;
        ds.xOff          = xOff;
        ds.yOff          = yOff;
        ds.bgSlope       = bgSlope;
        ds.bgInt         = bgIntcpt;
        ds.smoothEnabled = smoothEnabled;
        ds.smoothWindow  = smoothWin;
        ds.smoothMethod  = smoothMeth;
        ds.xTrimMin      = xTrimMin;
        ds.xTrimMax      = xTrimMax;
        ds.normMethod    = normVal;

        appData.datasets{di} = ds;
        try
            appData.model.updateDataset(di, ds);
        catch
        end
    end

    % Refresh plot
    fig.Pointer = 'arrow';
    callbacks.setStatus(sprintf('Corrections applied to all %d datasets.', numel(appData.datasets)));
    callbacks.onPlot();
    bosonPlotter.quietAlert(fig, sprintf('Corrections applied to all %d datasets.', ...
        numel(appData.datasets)), 'Batch Apply Complete');
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m module-level scope)
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function x = str2num_trim(s)
    x = str2double(s);
    if isnan(x), x = NaN; end
end
