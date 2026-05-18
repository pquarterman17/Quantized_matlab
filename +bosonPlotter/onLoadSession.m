function onLoadSession(appData, fig, widgets, callbacks)
%ONLOADSESSION  Restore a previously saved session from a .mat file.
%
% Syntax
%   bosonPlotter.onLoadSession(appData, fig, widgets, callbacks)
%
% Behaviour
%   Prompts the user for a `.mat` file, delegates deserialisation to
%   `bosonPlotter.sessionManager.load`, and restores:
%     - All datasets and the active index
%     - Background file / dataset references
%     - Plot style and last directory
%     - Phase A/B template state and style overrides
%     - WorkspaceModel state: row masks, computed/formula columns,
%       and X/Y/err column-role assignments (legacy sessions default
%       to empty, matching pre-2026-04 behaviour)
%     - Widget values (colormap, scale, BG interpolation, axis
%       channel selections) through
%       `bosonPlotter.sessionManager.applyGuiState`
%   Shows a watch cursor during the load, fires the active template
%   and plot-style UI sync, and finishes with a status line + modal
%   alert confirming the number of datasets restored.  Errors surface
%   through `logGUIError` and a user-facing `uialert`.
%
% Inputs
%   appData   - bosonPlotter.AppState handle (mutates datasets / style
%               / activeIdx / lastDir / activeTemplate / styleOverrides
%               / searchFilter / bgFile / bgDataset)
%   fig       - Main figure handle (watch cursor + uialert parent)
%   widgets   - Struct with handles used by applyGuiState /
%               applyAxisSelections.  At minimum:
%                 .ddTemplate, .efBGFile, .efDatasetSearch
%               plus whatever sessionManager requires.
%   callbacks - Struct of function handles:
%                 .cancelInteractions()
%                 .refreshTemplateDropdown()
%                 .onStylePick(styleName)
%                 .rebuildDatasetList(tf)
%                 .updateControlsForActiveDataset()
%                 .onPlot()
%                 .setStatus(msg)
%                 .logGUIError(title, msg, ME)
%                 .buildSessionWidgets()  -> struct for sessionManager

    startDir = resolveStartDir(appData.lastDir);
    [fname, fpath] = uigetfile({'*.mat','MATLAB session (*.mat)'}, ...
        'Load session file...', startDir);
    if isequal(fname, 0), return; end
    matPath = fullfile(fpath, fname);

    callbacks.setStatus('Loading session...');
    fig.Pointer = 'watch';
    drawnow;

    try
        [datasets, restored] = bosonPlotter.sessionManager.load(matPath);
    catch ME
        fig.Pointer = 'arrow';
        callbacks.setStatus('Session load failed.');
        callbacks.logGUIError('Load Error', ME.message, ME);
        bosonPlotter.quietAlert(fig, sprintf('Could not load session:\n%s', ME.message), 'Load Error');
        return;
    end

    callbacks.cancelInteractions();

    % Restore core data into appData
    appData.datasets  = datasets;
    appData.activeIdx = restored.activeIdx;
    appData.bgFile    = restored.bgFile;
    appData.bgDataset = restored.bgDataset;
    appData.style     = restored.style;
    appData.lastDir   = restored.lastDir;
    % Phase A/B visual state
    if isfield(restored, 'activeTemplate') && ~isempty(restored.activeTemplate)
        appData.activeTemplate = restored.activeTemplate;
    end
    if isfield(restored, 'styleOverrides') && isstruct(restored.styleOverrides)
        appData.styleOverrides = restored.styleOverrides;
    end

    % Sync the WorkspaceModel.  Required so formula/computed columns,
    % row masks, and column-role assignments survive the round-trip —
    % previously the model was untouched on load and its state was
    % effectively wiped whenever a session reopened.
    bosonPlotter.syncWorkspaceModelFromSession(appData, datasets, restored);
    % Sync the Template dropdown so the UI reflects the restored state
    callbacks.refreshTemplateDropdown();
    if ~isempty(widgets.ddTemplate) && isvalid(widgets.ddTemplate)
        if any(strcmp(widgets.ddTemplate.Items, appData.activeTemplate))
            widgets.ddTemplate.Value = appData.activeTemplate;
        end
    end

    if isempty(appData.datasets)
        callbacks.rebuildDatasetList(false);
        fig.Pointer = 'arrow';
        return;
    end

    % Restore dropdown/scale widget values (colormap, scale, BG interp)
    sessionWidgets = callbacks.buildSessionWidgets();
    bosonPlotter.sessionManager.applyGuiState(restored.guiState, sessionWidgets);

    % Restore plot style button appearance
    callbacks.onStylePick(appData.style);

    % Restore BG file display
    if ~isempty(appData.bgFile)
        widgets.efBGFile.Value = appData.bgFile;
    end

    % Clear search filter so all datasets are visible on load
    appData.searchFilter = '';
    widgets.efDatasetSearch.Value = '';

    callbacks.rebuildDatasetList(true);
    callbacks.updateControlsForActiveDataset();

    % Restore axis channel selections after listbox items are populated
    bosonPlotter.sessionManager.applyAxisSelections(restored.guiState, sessionWidgets);

    callbacks.onPlot();
    fig.Pointer = 'arrow';
    callbacks.setStatus(sprintf('Session loaded: %d dataset(s)', numel(appData.datasets)));
    bosonPlotter.quietAlert(fig, sprintf('Session loaded: %d dataset(s)', numel(appData.datasets)), ...
        'Session Loaded');
end

% ════════════════════════════════════════════════════════════════════════
% Local helper (duplicated from BosonPlotter.m module-level scope)
% ════════════════════════════════════════════════════════════════════════

function d = resolveStartDir(lastDir)
%RESOLVESTARTDIR  Pick a file-dialog starting folder.
    if ~isempty(lastDir) && (ischar(lastDir) || (isstring(lastDir) && isscalar(lastDir))) ...
            && isfolder(lastDir)
        d = char(lastDir);
    else
        d = pwd;
    end
end

