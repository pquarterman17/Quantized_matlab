function onBatchExportCSV(appData, fig, callbacks)
%ONBATCHEXPORTCSV  Export every loaded dataset to its own CSV file.
%
% Syntax
%   bosonPlotter.onBatchExportCSV(appData, fig, callbacks)
%
% Behaviour
%   Prompts for an output folder (Cancel = save next to each source
%   file), then iterates every loaded dataset:
%     - Neutron datasets share a consolidated file named
%       `<base>_neutron.csv`; only the first dataset matching each
%       measurement base name triggers the write.  `neutronBaseName`
%       strips polarization suffixes so ++ / -- / NSF / SF
%       cross-sections collapse onto one file.
%     - Non-neutron corrected datasets are written as
%       `<name>_corrected.csv` with the raw data duplicated alongside.
%     - Non-neutron uncorrected datasets are written as
%       `<name>_export.csv` with no raw duplication (display-unit
%       scaling is still applied).
%   Individual failures are collected into a "Batch Export Partial"
%   alert so a single bad dataset doesn't abort the whole run.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (reads datasets /
%               lastDir)
%   fig       - Main figure handle (pointer cursor + uialert parent)
%   callbacks - Struct of function handles:
%                 .setStatus(msg)
%                 .resolvedExportFormat() -> 'origin' | 'standard'
%                 .guiSaveCSV(d, fp, dRaw, asymData, fmt)

    if isempty(appData.datasets)
        bosonPlotter.quietAlert(fig,'Load a file first.','No data');
        return;
    end

    % Output directory picker: choose folder or save source-adjacent
    outDir = uigetdir(resolveStartDir(appData.lastDir), ...
        'Choose output folder (Cancel = save next to source files)');
    if isequal(outDir, 0), outDir = ''; end  % empty = source-adjacent

    callbacks.setStatus('Exporting CSV files...');
    fig.Pointer = 'watch';
    drawnow;

    fmt = callbacks.resolvedExportFormat();
    nDS = numel(appData.datasets);
    nExported = 0;
    failedFiles = {};
    neutronDone = {};  % base names already exported

    for di = 1:nDS
        ds = appData.datasets{di};

        % ── Neutron: consolidated export (once per measurement) ────
        if isfield(ds, 'parserName') && isNeutronParser(ds.parserName)
            bn = neutronBaseName(ds.filepath);
            if any(strcmp(neutronDone, bn)), continue; end
            [fpath, ~, ~] = fileparts(ds.filepath);
            if ~isempty(outDir), fpath = outDir; end
            outFile = fullfile(fpath, [bn, '_neutron.csv']);
            try
                bosonPlotter.saveConsolidatedNeutronCSV(ds, outFile, fmt, appData.datasets);
                nExported = nExported + 1;
                neutronDone{end+1} = bn; %#ok<AGROW>
            catch ME
                failedFiles{end+1} = sprintf('%s: %s', bn, ME.message); %#ok<AGROW>
            end
            continue;
        end

        % ── Non-neutron: individual export ─────────────────────────
        hasCorrected = ~isempty(ds.corrData);
        exportData   = guiTernary(hasCorrected, ds.corrData, ds.data);
        exportData   = bosonPlotter.applyDisplayUnits(exportData, ds, appData);
        suffix       = guiTernary(hasCorrected, '_corrected.csv', '_export.csv');

        [fpath, fname, ~] = fileparts(ds.filepath);
        if ~isempty(outDir), fpath = outDir; end
        outFile = fullfile(fpath, [fname, suffix]);

        try
            % Include raw data alongside corrected; skip duplication if uncorrected
            rawRef = guiTernary(hasCorrected, ds.data, []);
            callbacks.guiSaveCSV(exportData, outFile, rawRef, [], fmt);
            nExported = nExported + 1;
        catch ME
            failedFiles{end+1} = sprintf('%s: %s', fname, ME.message); %#ok<AGROW>
        end
    end

    % Show result
    fig.Pointer = 'arrow';
    if nExported == 0
        callbacks.setStatus('Batch export: no datasets exported.');
        bosonPlotter.quietAlert(fig, 'No datasets to export.', 'Batch Export');
    elseif isempty(failedFiles)
        callbacks.setStatus(sprintf('Batch export complete: %d file(s) saved.', nExported));
        bosonPlotter.quietAlert(fig, sprintf('Successfully exported %d file(s) to CSV.', nExported), ...
            'Batch Export Complete');
    else
        callbacks.setStatus(sprintf('Batch export partial: %d exported, %d failed.', nExported, numel(failedFiles)));
        msg = sprintf('Exported: %d\nFailed: %d\n\n', nExported, numel(failedFiles));
        msg = [msg, strjoin(failedFiles, '\n')];
        bosonPlotter.quietAlert(fig, msg, 'Batch Export Partial');
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

function d = resolveStartDir(lastDir)
%RESOLVESTARTDIR  Pick a file-dialog starting folder.
%   Uses lastDir when it is a valid existing directory; otherwise falls back
%   to pwd so newly-launched sessions open in the MATLAB working directory.
    if ~isempty(lastDir) && (ischar(lastDir) || (isstring(lastDir) && isscalar(lastDir))) ...
            && isfolder(lastDir)
        d = char(lastDir);
    else
        d = pwd;
    end
end

function baseName = neutronBaseName(filepath)
%NEUTRONBASENAME  Strip polarization suffixes to get the measurement base name.
%   Removes [_-](refl|pnr), [_-](NSF|SF), and trailing [_-][a-z] so all
%   cross-sections from one measurement share the same base name.
    [~, fn, ~] = fileparts(filepath);
    fn = regexprep(fn, '[_-](refl|pnr)$', '', 'ignorecase');
    fn = regexprep(fn, '[_-](NSF|SF)$',   '', 'ignorecase');
    fn = regexprep(fn, '[_-][a-z]$',       '', 'ignorecase');
    baseName = fn;
end
