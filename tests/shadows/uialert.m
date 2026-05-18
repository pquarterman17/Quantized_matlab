function uialert(fig, msg, varargin)
%UIALERT  Path-shadow that intercepts uialert in headless test mode.
%
%   When QUANTIZED_MATLAB_HEADLESS=1 this function suppresses the dialog and
%   logs to the Command Window so test diaries still record what would have
%   been shown. In normal interactive use it delegates to the real MATLAB
%   uialert by temporarily removing this shadow directory from the path.
%
%   This file lives in tests/shadows/ which is added to the MATLAB path ONLY
%   by tests/run_gui_hidden.ps1 and tests/run_gui_hidden.sh.  Production code
%   never sees this file.  Source files may use uialert() directly without any
%   project-specific wrapper — the shadow is transparent to callers.
%
%   Log format (matches bosonPlotter.quietAlert for diary compatibility):
%       [alert][Title] message
%       [alert] message   (when no title given)
%
%   See also UICONFIRM (tests/shadows), bosonPlotter.isHeadless

    if bosonPlotter.isHeadless()
        title = '';
        if ~isempty(varargin) && (ischar(varargin{1}) || isstring(varargin{1}))
            title = char(varargin{1});
        end
        if isempty(title)
            fprintf('[alert] %s\n', char(string(msg)));
        else
            fprintf('[alert][%s] %s\n', title, char(string(msg)));
        end
        return
    end

    % Normal mode: delegate to real MATLAB uialert.
    % Temporarily remove the shadow directory from the path so MATLAB
    % resolves the toolbox uialert instead of this file.
    shadowDir = fileparts(mfilename('fullpath'));
    onPath = contains(path, shadowDir);
    if onPath
        rmpath(shadowDir);
    end
    try
        uialert(fig, msg, varargin{:});
    catch ME
        if onPath
            addpath(shadowDir, '-begin');
        end
        rethrow(ME);
    end
    if onPath
        addpath(shadowDir, '-begin');
    end
end
