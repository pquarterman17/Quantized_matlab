classdef userTemplates
%USERTEMPLATES  Persistence for user-defined BosonPlotter style templates.
%
%   Saves and loads named style template structs to/from disk so the user
%   can build up a personal library of looks that survive across sessions.
%   Stored in prefdir/boson_user_templates.mat as a struct whose fields
%   are the template names (sanitised to valid MATLAB identifiers) and
%   whose values are the template structs.
%
%   Static API:
%       names   = bosonPlotter.userTemplates.list()
%       tpl     = bosonPlotter.userTemplates.load(name)
%       exists  = bosonPlotter.userTemplates.hasName(name)
%                 bosonPlotter.userTemplates.save(name, tpl)
%                 bosonPlotter.userTemplates.delete(name)
%       path    = bosonPlotter.userTemplates.storagePath()
%
%   All methods are static — call them directly on the class, never
%   instantiate.  Every method is safe to call even when the storage
%   file doesn't exist yet.
%
%   See also styles.template, bosonPlotter.resolveStyle

    methods (Static)

        function p = storagePath()
        %STORAGEPATH  Return the absolute path to the user templates .mat file.
        %   Uses MATLAB's prefdir so personal styles don't leak into the
        %   git-tracked toolbox directory.
            p = fullfile(prefdir, 'boson_user_templates.mat');
        end

        function names = list()
        %LIST  Return a cell array of saved template names (sanitised form).
            names = {};
            p = bosonPlotter.userTemplates.storagePath();
            if ~isfile(p), return; end
            try
                s = load(p, 'templates');
                if isfield(s, 'templates') && isstruct(s.templates)
                    names = fieldnames(s.templates);
                end
            catch
                % Corrupt file — return empty, caller can Save-as over it
            end
        end

        function tf = hasName(name)
        %HASNAME  Return true if a template with this name exists on disk.
            tf = any(strcmp(bosonPlotter.userTemplates.list(), ...
                            bosonPlotter.userTemplates.sanitise(name)));
        end

        function tpl = load(name)
        %LOAD  Load a named user template.  Throws if not found.
            key = bosonPlotter.userTemplates.sanitise(name);
            p = bosonPlotter.userTemplates.storagePath();
            if ~isfile(p)
                error('bosonPlotter:userTemplates:notFound', ...
                    'No user templates file exists at %s', p);
            end
            s = load(p, 'templates');
            if ~isfield(s, 'templates') || ~isfield(s.templates, key)
                error('bosonPlotter:userTemplates:notFound', ...
                    'No user template named "%s"', name);
            end
            tpl = s.templates.(key);
        end

        function save(name, tpl)
        %SAVE  Persist a template struct under the given name.  Overwrites
        %   any existing entry with the same (sanitised) name.
            arguments
                name (1,:) char
                tpl  (1,1) struct
            end
            key = bosonPlotter.userTemplates.sanitise(name);
            if isempty(key)
                error('bosonPlotter:userTemplates:badName', ...
                    'Template name "%s" sanitises to empty — pick another', name);
            end

            p = bosonPlotter.userTemplates.storagePath();
            templates = struct();
            if isfile(p)
                try
                    s = load(p, 'templates');
                    if isfield(s, 'templates') && isstruct(s.templates)
                        templates = s.templates;
                    end
                catch
                    % Corrupt file — start fresh
                end
            end

            % Always record the user-facing name alongside the sanitised
            % key so a future UI can display "My Paper Style" even if the
            % struct field is `my_paper_style`.
            tpl.name         = key;
            tpl.displayName  = name;
            tpl.savedAt      = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

            templates.(key) = tpl;

            % Ensure prefdir exists (it should, but don't assume)
            [dirPart, ~, ~] = fileparts(p);
            if ~isfolder(dirPart), mkdir(dirPart); end

            save(p, 'templates');
        end

        function delete(name)
        %DELETE  Remove a named user template.  No-op if not present.
            key = bosonPlotter.userTemplates.sanitise(name);
            p = bosonPlotter.userTemplates.storagePath();
            if ~isfile(p), return; end
            try
                s = load(p, 'templates');
            catch
                return;
            end
            if ~isfield(s, 'templates') || ~isstruct(s.templates), return; end
            if ~isfield(s.templates, key), return; end
            templates = rmfield(s.templates, key);
            save(p, 'templates');
        end

        function key = sanitise(name)
        %SANITISE  Convert a user-facing name into a valid MATLAB fieldname.
        %   Replaces any non-word character with underscore and ensures the
        %   first character is alphabetic (prepending 'u_' if needed).
            key = regexprep(char(name), '[^\w]', '_');
            if ~isempty(key) && ~isstrprop(key(1), 'alpha')
                key = ['u_' key];
            end
        end
    end
end
