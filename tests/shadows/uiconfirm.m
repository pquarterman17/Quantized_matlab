function sel = uiconfirm(fig, msg, varargin)
%UICONFIRM  Path-shadow that intercepts uiconfirm in headless test mode.
%
%   When QUANTIZED_MATLAB_HEADLESS=1 this function suppresses the blocking
%   confirmation dialog and auto-selects a response.  The auto-selected
%   response is chosen by:
%     1. The 'DefaultOption' name-value pair (if given as a string).
%     2. The first entry of the 'Options' list.
%     3. 'OK' as a hard fallback.
%
%   The choice and message are printed to the Command Window so test diaries
%   record what was auto-confirmed.
%
%   In normal interactive use this delegates to the real MATLAB uiconfirm by
%   temporarily removing this shadow directory from the path.
%
%   Log format (matches bosonPlotter.quietConfirm for diary compatibility):
%       [confirm:Title auto=Choice] message
%       [confirm auto=Choice] message   (when no title given)
%
%   See also UIALERT (tests/shadows), bosonPlotter.isHeadless

    if bosonPlotter.isHeadless()
        title      = '';
        opts       = {'OK'};
        defaultOpt = '';

        if ~isempty(varargin) && (ischar(varargin{1}) || isstring(varargin{1}))
            title = char(varargin{1});
            nv    = varargin(2:end);
        else
            nv = varargin;
        end

        for k = 1:2:numel(nv)-1
            key = lower(string(nv{k}));
            switch key
                case "options"
                    opts = cellstr(nv{k+1});
                case "defaultoption"
                    v = nv{k+1};
                    if isnumeric(v)
                        if v >= 1 && v <= numel(opts)
                            defaultOpt = opts{v};
                        end
                    else
                        defaultOpt = char(string(v));
                    end
            end
        end

        if isempty(defaultOpt)
            defaultOpt = opts{1};
        end
        sel = defaultOpt;

        if isempty(title)
            fprintf('[confirm auto=%s] %s\n', sel, char(string(msg)));
        else
            fprintf('[confirm:%s auto=%s] %s\n', title, sel, char(string(msg)));
        end
        return
    end

    % Normal mode: delegate to real MATLAB uiconfirm.
    % Temporarily remove the shadow directory from the path so MATLAB
    % resolves the toolbox uiconfirm instead of this file.
    shadowDir = fileparts(mfilename('fullpath'));
    onPath = contains(path, shadowDir);
    if onPath
        rmpath(shadowDir);
    end
    try
        sel = uiconfirm(fig, msg, varargin{:});
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
