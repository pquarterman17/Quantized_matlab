function restoreCorrectionState(appData, ui, dsIdx, s)
%RESTORECORRECTIONSTATE  Apply a saved correction snapshot to a dataset.
%
% Syntax
%   bosonPlotter.restoreCorrectionState(appData, ui, dsIdx, s)
%
% Behaviour
%   Copies every correction-related field (offsets, background model,
%   smoothing, trim range, normalisation, derivative mode, sample
%   geometry, units) from the snapshot struct `s` back onto
%   `appData.datasets{dsIdx}`.  Every field is `isfield`-guarded so
%   older snapshots (pre-R2022 sessions) load without error.  The
%   dataset is written back through `appData.model.updateDataset` so
%   any DataWorkspace observing the model sees the change.  When the
%   target index is the active dataset, the matching control widgets
%   are synced so the correction panel reflects the restored state.
%
%   Used by the undo/redo machinery — each correction mutation pushes
%   a before/after snapshot and this function replays one of them.
%
%   Legacy unit migration: session files written before 2026-04 used
%   "Oe (raw)" / "emu (raw)" to mean the un-converted state; those
%   tags are rewritten to plain "Oe" / "emu" here so the dropdowns
%   can resolve them.
%
% Inputs
%   appData - bosonPlotter.AppState handle (mutates datasets)
%   ui      - Struct with widget handles (20 correction controls).
%             See the widget sync block at the end of this function
%             for the exact list.
%   dsIdx   - 1-based index into appData.datasets to restore
%   s       - Snapshot struct captured by a prior correction action

    if dsIdx < 1 || dsIdx > numel(appData.datasets)
        return;
    end
    ds = appData.datasets{dsIdx};
    ds.corrData      = s.corrData;
    if isfield(s,'mask'),          ds.mask          = s.mask;          end
    ds.xOff          = s.xOff;
    ds.yOff          = s.yOff;
    ds.bgSlope       = s.bgSlope;
    ds.bgInt         = s.bgInt;
    if isfield(s,'bgPoly'),        ds.bgPoly        = s.bgPoly;        end
    ds.smoothEnabled = s.smoothEnabled;
    ds.smoothWindow  = s.smoothWindow;
    ds.smoothMethod  = s.smoothMethod;
    if isfield(s,'xTrimMin'),      ds.xTrimMin      = s.xTrimMin;      end
    if isfield(s,'xTrimMax'),      ds.xTrimMax      = s.xTrimMax;      end
    if isfield(s,'normMethod'),    ds.normMethod    = s.normMethod;    end
    if isfield(s,'derivativeMode'),ds.derivativeMode= s.derivativeMode;end
    if isfield(s,'sampleMass'),    ds.sampleMass    = s.sampleMass;    end
    if isfield(s,'sampleWidth'),   ds.sampleWidth   = s.sampleWidth;   end
    if isfield(s,'sampleHeight'),  ds.sampleHeight  = s.sampleHeight;  end
    if isfield(s,'dimUnit'),       ds.dimUnit       = s.dimUnit;       end
    if isfield(s,'sampleThick'),   ds.sampleThick   = s.sampleThick;   end
    if isfield(s,'thickUnit'),     ds.thickUnit     = s.thickUnit;     end
    if isfield(s,'momentUnit'),    ds.momentUnit    = s.momentUnit;    end
    if isfield(s,'fieldUnit'),     ds.fieldUnit     = s.fieldUnit;     end
    if isfield(s,'unitSystem'),    ds.unitSystem    = s.unitSystem;    end
    % Migration: old sessions used 'Oe (raw)' / 'emu (raw)' as the
    % un-converted state; the "(raw)" suffix was dropped in 2026-04.
    if isfield(ds,'fieldUnit')  && strcmp(ds.fieldUnit,  'Oe (raw)'),  ds.fieldUnit  = 'Oe';  end
    if isfield(ds,'momentUnit') && strcmp(ds.momentUnit, 'emu (raw)'), ds.momentUnit = 'emu'; end
    appData.datasets{dsIdx} = ds;
    try
        appData.model.updateDataset(dsIdx, ds);
    catch
    end

    % Sync UI widgets only when this is the active dataset
    if dsIdx == appData.activeIdx
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
        if isfield(ds,'derivativeMode')
            ui.ddDerivative.Value = ds.derivativeMode;
        end
        ui.efSampleMass.Value   = guiTernary(isfield(ds,'sampleMass'),   ds.sampleMass,   0);
        ui.efSampleWidth.Value  = guiTernary(isfield(ds,'sampleWidth'),  ds.sampleWidth,  0);
        ui.efSampleHeight.Value = guiTernary(isfield(ds,'sampleHeight'), ds.sampleHeight, 0);
        ui.ddDimUnit.Value      = guiTernary(isfield(ds,'dimUnit'),      ds.dimUnit,      'mm');
        ui.efSampleThick.Value  = guiTernary(isfield(ds,'sampleThick'),  ds.sampleThick,  0);
        ui.ddThickUnit.Value    = guiTernary(isfield(ds,'thickUnit'),    ds.thickUnit,    'nm');
        ui.ddMomentUnit.Value   = guiTernary(isfield(ds,'momentUnit'),   ds.momentUnit,   'emu');
        ui.ddFieldUnit.Value    = guiTernary(isfield(ds,'fieldUnit'),    ds.fieldUnit,    'Oe');
        ui.ddUnitSystem.Value   = guiTernary(isfield(ds,'unitSystem'),   ds.unitSystem,   'CGS');
    end
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m module-level scope)
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function s = nan2str(x)
%NAN2STR  Render NaN as empty string; otherwise delegate to num2str.
    if isnan(x), s = ''; else, s = num2str(x); end
end
