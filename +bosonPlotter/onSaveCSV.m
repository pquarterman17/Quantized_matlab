function onSaveCSV(appData, fig, ui, callbacks)
%ONSAVECSV  Save the active dataset to the path in efSavePath.
%
% Syntax
%   bosonPlotter.onSaveCSV(appData, fig, ui, callbacks)
%
% Behaviour
%   Writes the active dataset to the file path entered in the
%   efSavePath edit field.  Three cases:
%     1. Neutron data (importNCNRDat/Refl/PNR): delegates to the
%        consolidated NCNR writer that bundles ±± polarization
%        states into a single file.
%     2. Corrected non-neutron data: applies mask + display-unit
%        scaling to the corrected copy, computes linear asymmetry
%        if a ± partner exists, and saves the display-scaled
%        corrected view alongside the untouched raw columns for
%        reproducibility.
%     3. Uncorrected non-neutron data: display-unit-scales a copy
%        and writes it with no raw duplication.
%   Successful saves are recorded in the action history; errors are
%   logged via the standard GUI error sink and surfaced to the user
%   through a modal alert.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads datasets /
%               activeIdx)
%   fig       - Main figure handle (for uialert parent)
%   ui        - Struct with widget handles: efSavePath
%   callbacks - Struct of function handles:
%                 .resolvedExportFormat() -> 'origin' | 'standard'
%                 .findPolarizationPairs(datasets) -> pairMap
%                 .recordAction(cmdLine)
%                 .logGUIError(title, msg, ME)
%                 .guiSaveCSV(d, fp, dRaw, asymData, fmt)

    if isempty(appData.datasets) || appData.activeIdx < 1
        uialert(fig,'Load a file first.','No data');
        return;
    end
    ds = appData.datasets{appData.activeIdx};
    fp = strtrim(ui.efSavePath.Value);
    if isempty(fp)
        uialert(fig,'Set an output file path first.','No output path');
        return;
    end
    fmt = callbacks.resolvedExportFormat();
    try
        if isfield(ds, 'parserName') && isNeutronParser(ds.parserName)
            bosonPlotter.saveConsolidatedNeutronCSV(ds, fp, fmt, appData.datasets);
        else
            hasCorrected = ~isempty(ds.corrData);
            exportData   = guiTernary(hasCorrected, ds.corrData, ds.data);
            % Apply mask (exclude masked points from export)
            if isfield(ds, 'mask') && ~isempty(ds.mask) && any(~ds.mask)
                if hasCorrected
                    % Map raw mask through trim to match exportData rows
                    nRawE = numel(ds.data.time);
                    keepE = true(nRawE, 1);
                    if ~isdatetime(ds.data.time)
                        tVE = double(ds.data.time);
                        if ~isnan(ds.xTrimMin), keepE = keepE & tVE >= ds.xTrimMin; end
                        if ~isnan(ds.xTrimMax), keepE = keepE & tVE <= ds.xTrimMax; end
                    end
                    exportMask = ds.mask(keepE);
                else
                    exportMask = ds.mask;
                end
                exportData.time   = exportData.time(exportMask);
                exportData.values = exportData.values(exportMask, :);
            end
            % Apply display-unit scaling (SI prefix + mag unit labels)
            exportData = bosonPlotter.applyDisplayUnits(exportData, ds, appData);
            if hasCorrected
                cafeCb_ = struct('findPolarizationPairs', callbacks.findPolarizationPairs);
                asymData = bosonPlotter.computeAsymmetryForExport(ds, appData, cafeCb_);
                % Include original raw data alongside display-scaled corrected
                callbacks.guiSaveCSV(exportData, fp, ds.data, asymData, fmt);
            else
                % No corrections — export in display units, no duplication
                callbacks.guiSaveCSV(exportData, fp, [], [], fmt);
            end
        end
        callbacks.recordAction(sprintf("%% Exported CSV: %s", fp));
        uialert(fig, sprintf('Saved:\n%s', fp), 'Saved');
    catch ME
        fprintf(2, '\n[BosonPlotter] Save error: %s\n', ME.message);
        for si = 1:numel(ME.stack)
            fprintf(2, '  at %s  (line %d)\n', ME.stack(si).name, ME.stack(si).line);
        end
        callbacks.logGUIError('Save error', ME.message, ME);
        uialert(fig, ME.message, 'Save error');
    end
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
