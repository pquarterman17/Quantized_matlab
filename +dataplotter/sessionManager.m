classdef sessionManager
%SESSIONMANAGER  Save and load DataPlotter session .mat files.
%
%   Static methods for session persistence.  The data portion (datasets)
%   uses the AppState handle class for pass-by-reference.  GUI widget
%   state is passed as a plain struct.
%
%   Examples:
%       dataplotter.sessionManager.save('session.mat', appData, guiState);
%       [guiState] = dataplotter.sessionManager.load('session.mat', appData);

    methods (Static)

        function save(outPath, appData, guiState)
        %SAVE  Save datasets and GUI state to a .mat session file.
        %
        %   dataplotter.sessionManager.save(outPath, appData, guiState)
        %
        %   Inputs:
        %       outPath  — path to output .mat file
        %       appData  — dataplotter.AppState handle (datasets read from here)
        %       guiState — struct with GUI dropdown/checkbox values

            if isfile(outPath)
                warning('DataPlotter:sessionOverwrite', ...
                    'Overwriting existing session file: %s', outPath);
            end

            savedDatasets = appData.datasets; %#ok<NASGU>
            savedState    = guiState;         %#ok<NASGU>
            save(outPath, 'savedDatasets', 'savedState');
        end

        function guiState = load(matPath, appData)
        %LOAD  Restore datasets from a .mat session file.
        %
        %   guiState = dataplotter.sessionManager.load(matPath, appData)
        %
        %   Inputs:
        %       matPath — path to session .mat file
        %       appData — dataplotter.AppState handle (datasets written here)
        %
        %   Output:
        %       guiState — struct of saved GUI state (may be empty struct)

            if ~isfile(matPath)
                error('Session file not found: %s', matPath);
            end

            s = load(matPath);
            if ~isfield(s, 'savedDatasets')
                error('Invalid session file: missing savedDatasets field');
            end

            % Restore datasets into appData (handle — mutations propagate)
            appData.datasets  = s.savedDatasets;
            appData.activeIdx = 0;

            % parserVersion compatibility check
            nLegacy = sum(cellfun(@(ds) ...
                ~isfield(ds.data.metadata, 'parserVersion'), appData.datasets));
            if nLegacy > 0
                warning('DataPlotter:legacySession', ...
                    '%d dataset(s) lack parserVersion; re-import files to attach version metadata.', ...
                    nLegacy);
            end

            % Return GUI state for the caller to apply to widgets
            if isfield(s, 'savedState')
                guiState = s.savedState;
            else
                guiState = struct();
            end
        end

    end
end
