classdef correctionPresets
%CORRECTIONPRESETS  Named correction presets persisted to prefdir.
%
%   bosonPlotter.correctionPresets.list()        — cell array of preset names
%   bosonPlotter.correctionPresets.save(name, p) — save a preset struct
%   bosonPlotter.correctionPresets.load(name)    — load a preset struct
%   bosonPlotter.correctionPresets.delete(name)  — delete a preset
%
%   Presets are stored in prefdir/boson_corr_presets.mat as a containers.Map
%   keyed by name. Each value is a struct with correction parameters.

    properties (Constant, Access = private)
        FILENAME = 'boson_corr_presets.mat'
    end

    methods (Static)

        function names = list()
        %LIST  Return cell array of saved preset names.
            m = bosonPlotter.correctionPresets.loadMap();
            names = keys(m);
        end

        function save(name, params)
        %SAVE  Save a correction preset by name.
        %   params is a struct with fields: xOff, yOff, bgSlope, bgInt,
        %   smoothEnabled, smoothWindow, smoothMethod, normMethod,
        %   derivativeMode, xTrimMin, xTrimMax.
            m = bosonPlotter.correctionPresets.loadMap();
            m(name) = params; %#ok<NASGU>
            fp = fullfile(prefdir, bosonPlotter.correctionPresets.FILENAME);
            presetMap = m; %#ok<NASGU>
            builtin('save', fp, 'presetMap');
        end

        function p = load(name)
        %LOAD  Load a correction preset by name.
            m = bosonPlotter.correctionPresets.loadMap();
            if ~isKey(m, name)
                error('correctionPresets:notFound', 'Preset "%s" not found.', name);
            end
            p = m(name);
        end

        function delete(name)
        %DELETE  Remove a preset by name.
            m = bosonPlotter.correctionPresets.loadMap();
            if isKey(m, name)
                remove(m, name);
            end
            fp = fullfile(prefdir, bosonPlotter.correctionPresets.FILENAME);
            presetMap = m; %#ok<NASGU>
            builtin('save', fp, 'presetMap');
        end

    end

    methods (Static, Access = private)

        function m = loadMap()
        %LOADMAP  Load the presets map from prefdir, or create empty.
            fp = fullfile(prefdir, bosonPlotter.correctionPresets.FILENAME);
            if isfile(fp)
                try
                    tmp = builtin('load', fp, 'presetMap');
                    m = tmp.presetMap;
                catch
                    m = containers.Map();
                end
            else
                m = containers.Map();
            end
        end

    end
end
