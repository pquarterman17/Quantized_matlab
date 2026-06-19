function out = themePref(action, value)
%THEMEPREF  Read or write the persisted theme preference (Dark/Light/Auto).
%
% Syntax
%   t = bosonPlotter.themePref('read')          % returns 'Dark' | 'Light' | 'Auto'
%   bosonPlotter.themePref('write', 'Auto')     % persists choice
%
% 'Auto' means "follow OS appearance"; resolve via bosonPlotter.resolveTheme
% to get a concrete 'Dark'/'Light' value at apply time.
%
% Behaviour
%   The preference is stored as a tiny .mat file in `prefdir` so it is
%   shared across BosonPlotter, DiraCulator, DataWorkspace, and any other GUI that
%   wants to honour the user's mode choice. On read failure (file
%   missing, corrupted, etc.) returns 'Dark' — the historical default.
%
%   Writes are best-effort: failures are silent so a read-only prefdir
%   never blocks the toggle.
%
% File location
%   fullfile(prefdir, 'boson_theme.mat') with variable `themeName`
%   containing the char vector 'Dark' or 'Light'.

    persistent CACHED_PATH
    if isempty(CACHED_PATH)
        CACHED_PATH = fullfile(prefdir, 'boson_theme.mat');
    end

    switch lower(string(action))
        case "read"
            out = 'Dark';
            try
                if isfile(CACHED_PATH)
                    s = load(CACHED_PATH, 'themeName');
                    if isfield(s, 'themeName') && ischar(s.themeName) ...
                            && any(strcmpi(s.themeName, {'Dark','Light','Auto'}))
                        % Normalise to canonical capitalisation.
                        if strcmpi(s.themeName, 'Dark')
                            out = 'Dark';
                        elseif strcmpi(s.themeName, 'Auto')
                            out = 'Auto';
                        else
                            out = 'Light';
                        end
                    end
                end
            catch
                % Silent fallback to the historical default.
            end
        case "write"
            if nargin < 2 || ~ischar(value) && ~isstring(value)
                return;
            end
            value = char(value);
            if ~any(strcmpi(value, {'Dark','Light','Auto'}))
                return;
            end
            % Normalise.
            if strcmpi(value, 'Dark')
                themeName = 'Dark';
            elseif strcmpi(value, 'Auto')
                themeName = 'Auto';
            else
                themeName = 'Light';
            end
            % Persist, then verify the file actually holds the new value.
            % A silent failure here is exactly what makes the theme "revert"
            % on the next launch (it applies in-session via appData.theme but
            % was never written), so surface the cause instead of swallowing.
            persisted = false;
            hadError  = false;
            try
                save(CACHED_PATH, 'themeName');
                v = load(CACHED_PATH, 'themeName');
                persisted = isfield(v, 'themeName') && strcmp(v.themeName, themeName);
            catch ME
                hadError = true;
                warning('bosonPlotter:themePref:writeFailed', ...
                    ['Could not save theme preference to\n  %s\n%s\n' ...
                     'The theme will apply now but may not persist to the next session.'], ...
                    CACHED_PATH, ME.message);
            end
            if ~persisted && ~hadError
                warning('bosonPlotter:themePref:notVerified', ...
                    ['Theme preference write to\n  %s\ndid not verify; it may not ' ...
                     'persist across sessions.'], CACHED_PATH);
            end
            if nargout > 0, out = value; end
        otherwise
            error('bosonPlotter:themePref:badAction', ...
                'Action must be ''read'' or ''write''.');
    end
end
