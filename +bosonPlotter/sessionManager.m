classdef sessionManager
%SESSIONMANAGER  Save and load BosonPlotter session .mat files.
%
%   Static methods for session persistence.  The data portion (datasets)
%   is passed by value; GUI widget state is passed as a plain struct built
%   by collectGuiState() and applied by applyGuiState().
%
%   Typical call sequence — save:
%       guiState = bosonPlotter.sessionManager.collectGuiState(widgets);
%       bosonPlotter.sessionManager.save(outPath, appData, guiState);
%
%   Typical call sequence — load:
%       [datasets, restored] = bosonPlotter.sessionManager.load(matPath);
%       bosonPlotter.sessionManager.applyGuiState(restored.guiState, widgets);
%
%   The format written by save() uses individual named variables so that
%   older session files created before this refactor remain loadable.

    methods (Static)

        % ── Widget-state helpers ─────────────────────────────────────────

        function gs = collectGuiState(widgets)
        %COLLECTGUISTATE  Snapshot current widget values into a plain struct.
        %
        %   gs = bosonPlotter.sessionManager.collectGuiState(widgets)
        %
        %   Input:
        %       widgets — struct with fields:
        %           .ddColormap   uidropdown
        %           .ddMap2DCmap  uidropdown
        %           .ddX          uidropdown
        %           .lbY          uilistbox
        %           .lbY2         uilistbox
        %           .ddScaleX     uidropdown
        %           .ddScaleY     uidropdown
        %           .ddBGInterp   uidropdown
        %
        %   Output:
        %       gs — struct with savedColormap, savedMap2DCmap, savedXSel,
        %            savedYSel, savedY2Sel, savedLogX, savedLogY, savedBGInterp

            gs.savedColormap  = widgets.ddColormap.Value;
            gs.savedMap2DCmap = widgets.ddMap2DCmap.Value;
            gs.savedXSel      = widgets.ddX.Value;
            gs.savedYSel      = bosonPlotter.sessionManager.ensureCell_(widgets.lbY.Value);
            gs.savedY2Sel     = bosonPlotter.sessionManager.ensureCell_(widgets.lbY2.Value);
            gs.savedLogX      = strcmp(widgets.ddScaleX.Value, 'Log');
            gs.savedLogY      = strcmp(widgets.ddScaleY.Value, 'Log');
            gs.savedBGInterp  = widgets.ddBGInterp.Value;
        end

        function applyGuiState(gs, widgets)
        %APPLYGUISTATE  Restore widget values from a saved GUI-state struct.
        %
        %   bosonPlotter.sessionManager.applyGuiState(gs, widgets)
        %
        %   Inputs:
        %       gs      — struct returned by collectGuiState (or loaded from file)
        %       widgets — same field layout as collectGuiState
        %
        %   Missing or invalid fields are silently skipped so that old
        %   session files degrade gracefully.

            if isfield(gs,'savedColormap') && ismember(gs.savedColormap, widgets.ddColormap.Items)
                widgets.ddColormap.Value = gs.savedColormap;
            end
            if isfield(gs,'savedMap2DCmap') && ismember(gs.savedMap2DCmap, widgets.ddMap2DCmap.Items)
                widgets.ddMap2DCmap.Value = gs.savedMap2DCmap;
            end
            if isfield(gs,'savedLogX')
                if gs.savedLogX
                    widgets.ddScaleX.Value = 'Log';
                else
                    widgets.ddScaleX.Value = 'Linear';
                end
            end
            if isfield(gs,'savedLogY')
                if gs.savedLogY
                    widgets.ddScaleY.Value = 'Log';
                else
                    widgets.ddScaleY.Value = 'Linear';
                end
            end
            if isfield(gs,'savedBGInterp') && ismember(gs.savedBGInterp, widgets.ddBGInterp.Items)
                widgets.ddBGInterp.Value = gs.savedBGInterp;
            end
            % X/Y axis selections applied after rebuildDatasetList populates items
            % — caller must call applyAxisSelections() separately if needed.
        end

        function applyAxisSelections(gs, widgets)
        %APPLYAXISSELECTIONS  Restore ddX / lbY / lbY2 after dataset list is rebuilt.
        %
        %   bosonPlotter.sessionManager.applyAxisSelections(gs, widgets)
        %
        %   Called after rebuildDatasetList() so that listbox .Items are
        %   populated before we attempt to set .Value.

            if isfield(gs,'savedXSel') && ismember(gs.savedXSel, widgets.ddX.Items)
                widgets.ddX.Value = gs.savedXSel;
            end
            if isfield(gs,'savedYSel')
                validY = gs.savedYSel(ismember(gs.savedYSel, widgets.lbY.Items));
                if ~isempty(validY)
                    widgets.lbY.Value = validY;
                end
            end
            if isfield(gs,'savedY2Sel')
                validY2 = gs.savedY2Sel(ismember(gs.savedY2Sel, widgets.lbY2.Items));
                if ~isempty(validY2)
                    widgets.lbY2.Value = validY2;
                end
            end
        end

        % ── File I/O ─────────────────────────────────────────────────────

        function save(outPath, appData, guiState)
        %SAVE  Save datasets and GUI state to a .mat session file.
        %
        %   bosonPlotter.sessionManager.save(outPath, appData, guiState)
        %
        %   Inputs:
        %       outPath  — full path to output .mat file
        %       appData  — bosonPlotter.AppState handle (datasets read from here)
        %       guiState — struct produced by collectGuiState()

            savedDatasets  = appData.datasets;  %#ok<NASGU>
            savedActiveIdx = appData.activeIdx; %#ok<NASGU>
            savedBgFile    = appData.bgFile;    %#ok<NASGU>
            savedBgDataset = appData.bgDataset; %#ok<NASGU>
            savedStyle     = appData.style;     %#ok<NASGU>
            savedLastDir   = appData.lastDir;   %#ok<NASGU>

            % Phase A/B visual style state (per-session persistence)
            savedActiveTemplate = ''; %#ok<NASGU>
            if isprop(appData, 'activeTemplate') || isfield(appData, 'activeTemplate')
                savedActiveTemplate = appData.activeTemplate; %#ok<NASGU>
            end
            savedStyleOverrides = struct(); %#ok<NASGU>
            if isprop(appData, 'styleOverrides') || isfield(appData, 'styleOverrides')
                savedStyleOverrides = appData.styleOverrides; %#ok<NASGU>
            end

            % Unpack guiState fields as individual variables for backward
            % compatibility with session files written before this refactor.
            savedColormap  = guiState.savedColormap;  %#ok<NASGU>
            savedMap2DCmap = guiState.savedMap2DCmap; %#ok<NASGU>
            savedXSel      = guiState.savedXSel;      %#ok<NASGU>
            savedYSel      = guiState.savedYSel;      %#ok<NASGU>
            savedY2Sel     = guiState.savedY2Sel;     %#ok<NASGU>
            savedLogX      = guiState.savedLogX;      %#ok<NASGU>
            savedLogY      = guiState.savedLogY;      %#ok<NASGU>
            savedBGInterp  = guiState.savedBGInterp;  %#ok<NASGU>

            save(outPath, ...
                'savedDatasets',  'savedActiveIdx',      ...
                'savedBgFile',    'savedBgDataset',      ...
                'savedStyle',     'savedLastDir',        ...
                'savedActiveTemplate', 'savedStyleOverrides', ...
                'savedColormap',  'savedMap2DCmap',      ...
                'savedXSel',                             ...
                'savedYSel',      'savedY2Sel',          ...
                'savedLogX',      'savedLogY',           ...
                'savedBGInterp',                         ...
                '-v7.3');
        end

        function [datasets, restored] = load(matPath)
        %LOAD  Restore datasets and GUI state from a .mat session file.
        %
        %   [datasets, restored] = bosonPlotter.sessionManager.load(matPath)
        %
        %   Input:
        %       matPath — full path to session .mat file
        %
        %   Outputs:
        %       datasets — cell array of dataset structs (field-patched for compat)
        %       restored — struct with fields:
        %           .activeIdx  double
        %           .bgFile     char
        %           .bgDataset  ([] or struct)
        %           .style      char
        %           .lastDir    char
        %           .guiState   struct (pass to applyGuiState / applyAxisSelections)

            if ~isfile(matPath)
                error('BosonPlotter:sessionNotFound', ...
                    'Session file not found: %s', matPath);
            end

            S = load(matPath, '-mat');

            if ~isfield(S, 'savedDatasets')
                error('BosonPlotter:invalidSession', ...
                    'File does not appear to be a valid session file (missing savedDatasets).');
            end

            % ── parserVersion compatibility check ────────────────────────
            nLegacy = sum(cellfun(@(ds) ...
                ~isfield(ds.data.metadata, 'parserVersion'), S.savedDatasets));
            if nLegacy > 0
                warning('BosonPlotter:legacySession', ...
                    ['%d dataset(s) in this session were imported before parser ' ...
                     'versioning was introduced.\n' ...
                     'Data should load correctly; re-import files to attach version metadata.'], ...
                    nLegacy);
            end

            % ── Backward-compat: patch missing per-dataset fields ────────
            defs  = bosonPlotter.sessionManager.datasetDefaults_();
            fnames = fieldnames(defs);
            patchedDatasets = S.savedDatasets;
            for di = 1:numel(patchedDatasets)
                for fi = 1:numel(fnames)
                    if ~isfield(patchedDatasets{di}, fnames{fi})
                        patchedDatasets{di}.(fnames{fi}) = defs.(fnames{fi});
                    end
                end
            end
            datasets = patchedDatasets;

            % ── Build restored struct ─────────────────────────────────────
            nDS = numel(datasets);

            function v = pick_(fieldName, default)
                if isfield(S, fieldName)
                    v = S.(fieldName);
                else
                    v = default;
                end
            end

            rawIdx = pick_('savedActiveIdx', 1);
            if rawIdx < 1 || rawIdx > nDS
                rawIdx = 1;
            end

            restored.activeIdx      = rawIdx;
            restored.bgFile         = pick_('savedBgFile',         '');
            restored.bgDataset      = pick_('savedBgDataset',      []);
            restored.style          = pick_('savedStyle',          'Line');
            restored.lastDir        = pick_('savedLastDir',        '');
            restored.activeTemplate = pick_('savedActiveTemplate', 'screen');
            restored.styleOverrides = pick_('savedStyleOverrides', struct());
            if ~isstruct(restored.styleOverrides)
                restored.styleOverrides = struct();
            end
            if isempty(char(restored.activeTemplate))
                restored.activeTemplate = 'screen';
            end

            % Pack GUI fields back into a guiState struct
            gs.savedColormap  = pick_('savedColormap',  '');
            gs.savedMap2DCmap = pick_('savedMap2DCmap', '');
            gs.savedXSel      = pick_('savedXSel',      '');
            gs.savedYSel      = pick_('savedYSel',      {});
            gs.savedY2Sel     = pick_('savedY2Sel',     {});
            gs.savedLogX      = pick_('savedLogX',      false);
            gs.savedLogY      = pick_('savedLogY',      false);
            gs.savedBGInterp  = pick_('savedBGInterp',  '');
            restored.guiState = gs;
        end

    end % methods (Static)

    % ── Private helpers ───────────────────────────────────────────────────

    methods (Static, Access = private)

        function defs = datasetDefaults_()
        %DATASETDEFAULTS_  Default values for per-dataset fields added after
        %  initial release.  Used to patch old session files on load.
            defs = struct( ...
                'snipBackground', struct('x', [], 'bg', []), ...
                'derivativeMode', 'None', ...
                'refLines',       {{}},   ...
                'undoStack',      {{}},   ...
                'normMethod',     'None', ...
                'xTrimMin',       NaN,    ...
                'xTrimMax',       NaN,    ...
                'legendName',     '',     ...
                'legendNameR',    '',     ...
                'color',          [],     ...
                'colorR',         [],     ...
                'styleOverride',  struct(), ...
                'channelStyles',  {{}},   ...
                'annotations',    {{}},   ...
                'visible',        true);
        end

        function c = ensureCell_(v)
        %ENSURECELL_  Wrap non-cell value in a cell; leave cell as-is.
            if iscell(v)
                c = v;
            else
                c = {v};
            end
        end

    end % methods (Static, Access = private)

end
