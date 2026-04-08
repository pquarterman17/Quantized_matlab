function connector = dataConnector(filePath, options)
%DATACONNECTOR  Live file watcher — auto-reloads data when the source file changes.
%
%   Syntax:
%       connector = scripts.dataConnector(filePath, Callback=@myFcn)
%       connector = scripts.dataConnector(filePath, Interval=5, AutoStart=false)
%
%   Inputs:
%       filePath — path to the file to watch (string or char)
%
%   Name-Value Options:
%       Interval  — polling interval in seconds  (default 2)
%       Callback  — function handle called as Callback(data) when the file
%                   changes and re-imports successfully  (default [])
%       AutoStart — start the watcher immediately  (default true)
%
%   Outputs:
%       connector — struct with function-handle fields:
%           .start()       — begin watching (no-op if already running)
%           .stop()        — stop and delete the internal timer
%           .isRunning()   — returns logical true if timer is active
%           .filePath      — char path of the watched file
%           .lastModified  — datetime of the last detected change ([] until first change)
%
%   Notes:
%       Uses a MATLAB timer with ExecutionMode 'fixedSpacing' to poll the
%       file's modification timestamp via dir().  When a change is detected
%       the file is re-imported via parser.importAuto and the Callback is
%       invoked with the new data struct.  Errors during import are printed
%       as warnings and do not stop the timer.
%
%       Call connector.stop() before clearing the connector to prevent a
%       leaked timer object.
%
%   Examples:
%       % Print a message whenever 'live_data.csv' changes
%       c = scripts.dataConnector('live_data.csv', ...
%               Callback=@(d) fprintf('Reloaded: %d rows\n', size(d.values,1)));
%       % … work with data …
%       c.stop();
%
%       % Manual start/stop cycle
%       c = scripts.dataConnector('log.dat', AutoStart=false);
%       c.start();
%       pause(10);
%       c.stop();
%
%   See also parser.importAuto, timer

arguments
    filePath    (1,1) string
    options.Interval  (1,1) double  {mustBePositive} = 2
    options.Callback                                  = []
    options.AutoStart (1,1) logical                   = true
end

% ════════════════════════════════════════════════════════════════════════
%  Validate file path (warn but do not error for non-existent files so the
%  caller can start a watcher before the file appears)
% ════════════════════════════════════════════════════════════════════════
fpChar = char(filePath);
if ~isfile(fpChar)
    warning('scripts:dataConnector:fileNotFound', ...
        'File does not exist (yet): %s', fpChar);
end

% ════════════════════════════════════════════════════════════════════════
%  Mutable state shared across closure functions
% ════════════════════════════════════════════════════════════════════════
[state.lastDatenum, state.lastBytes] = getFileStat(fpChar);  % 0,0 if absent
state.tmr         = [];
state.lastModified = [];

% ════════════════════════════════════════════════════════════════════════
%  Timer tick callback
% ════════════════════════════════════════════════════════════════════════
    function onTick(~, ~)
        [dn, sz] = getFileStat(fpChar);
        if dn == 0, return; end  % file not present yet
        % Detect change via mtime OR size (filesystem mtime resolution can be
        % coarse — bytes flip catches rapid back-to-back writes).
        if dn == state.lastDatenum && sz == state.lastBytes, return; end

        % File has changed
        state.lastDatenum  = dn;
        state.lastBytes    = sz;
        state.lastModified = datetime('now');

        try
            newData = parser.importAuto(fpChar);
        catch ME
            warning('scripts:dataConnector:importFailed', ...
                'Re-import failed for %s: %s', fpChar, ME.message);
            return;
        end

        if ~isempty(options.Callback)
            try
                options.Callback(newData);
            catch ME
                warning('scripts:dataConnector:callbackError', ...
                    'Callback error: %s', ME.message);
            end
        end
    end

% ════════════════════════════════════════════════════════════════════════
%  start / stop / isRunning functions
% ════════════════════════════════════════════════════════════════════════
    function startWatcher()
        if ~isempty(state.tmr) && isvalid(state.tmr)
            % Already running
            return;
        end
        state.tmr = timer( ...
            'ExecutionMode', 'fixedSpacing', ...
            'Period',        options.Interval, ...
            'TimerFcn',      @onTick, ...
            'ErrorFcn',      @onTimerError, ...
            'Name',          'dataConnector');
        start(state.tmr);
    end

    function stopWatcher()
        if ~isempty(state.tmr) && isvalid(state.tmr)
            stop(state.tmr);
            delete(state.tmr);
        end
        state.tmr = [];
    end

    function running = isRunning()
        running = ~isempty(state.tmr) && isvalid(state.tmr) && ...
                  strcmp(state.tmr.Running, 'on');
    end

    function onTimerError(~, eventdata)
        warning('scripts:dataConnector:timerError', ...
            'Timer error: %s', eventdata.Data.message);
    end

    function lm = getLastModified()
        % Nested function — sees live `state` in enclosing workspace.
        % (Anonymous function would capture state.lastModified by value.)
        lm = state.lastModified;
    end

% ════════════════════════════════════════════════════════════════════════
%  Build and return connector struct
% ════════════════════════════════════════════════════════════════════════
connector.start        = @startWatcher;
connector.stop         = @stopWatcher;
connector.isRunning    = @isRunning;
connector.filePath     = fpChar;
connector.lastModified = @getLastModified;

if options.AutoStart
    startWatcher();
end

end % dataConnector


% ════════════════════════════════════════════════════════════════════════
%  Local helper
% ════════════════════════════════════════════════════════════════════════
function [dn, sz] = getFileStat(fp)
%GETFILESTAT  Return [datenum, bytes] of a file, or [0,0] if absent.
    info = dir(fp);
    if isempty(info)
        dn = 0;
        sz = 0;
    else
        dn = info(1).datenum;
        sz = info(1).bytes;
    end
end
