classdef autosave
%AUTOSAVE  Crash-recovery autosave for BosonPlotter.
%
%   bosonPlotter.autosave.start(appData)   — start periodic autosave timer
%   bosonPlotter.autosave.stop()           — stop timer (called on clean close)
%   bosonPlotter.autosave.save(appData)    — write snapshot to prefdir
%   bosonPlotter.autosave.check()          — true if a recovery file exists
%   bosonPlotter.autosave.restore()        — load recovery data, delete file
%   bosonPlotter.autosave.cleanup()        — delete recovery file (clean exit)
%
%   The autosave file lives at prefdir/boson_autosave.mat.  On clean exit
%   (figure close), cleanup() deletes it.  On crash, the file persists and
%   check() returns true on the next startup.

    properties (Constant, Access = private)
        INTERVAL_SEC = 120    % 2 minutes
        FILENAME     = 'boson_autosave.mat'
    end

    properties (Access = private)
    end

    methods (Static)

        function start(appData)
        %START  Begin periodic autosave (every 2 min).
            bosonPlotter.autosave.stop();  % clear any existing timer
            if isempty(appData.datasets), return; end
            t = timer( ...
                'Name',          'BosonAutosave', ...
                'ExecutionMode', 'fixedRate', ...
                'Period',        bosonPlotter.autosave.INTERVAL_SEC, ...
                'StartDelay',    bosonPlotter.autosave.INTERVAL_SEC, ...
                'TimerFcn',      @(~,~) bosonPlotter.autosave.save(appData));
            start(t);
        end

        function stop()
        %STOP  Stop and delete the autosave timer.
            t = timerfind('Name', 'BosonAutosave');
            if ~isempty(t)
                stop(t);
                delete(t);
            end
        end

        function save(appData)
        %SAVE  Write a minimal recovery snapshot to prefdir.
            try
                fp = fullfile(prefdir, bosonPlotter.autosave.FILENAME);
                datasets  = appData.datasets;  %#ok<NASGU>
                activeIdx = appData.activeIdx;  %#ok<NASGU>
                lastDir   = appData.lastDir;    %#ok<NASGU>
                timestamp = datetime('now');     %#ok<NASGU>
                save(fp, 'datasets', 'activeIdx', 'lastDir', 'timestamp', '-v7.3');
            catch
                % Silent — autosave is best-effort
            end
        end

        function tf = check()
        %CHECK  True if a recovery file exists (indicates prior crash).
            fp = fullfile(prefdir, bosonPlotter.autosave.FILENAME);
            tf = isfile(fp);
        end

        function [datasets, restored] = restore()
        %RESTORE  Load recovery data and delete the file.
        %   [datasets, restored] = bosonPlotter.autosave.restore()
        %   restored has fields: .activeIdx, .lastDir, .timestamp
            fp = fullfile(prefdir, bosonPlotter.autosave.FILENAME);
            tmp = load(fp);
            datasets = tmp.datasets;
            restored = struct( ...
                'activeIdx', tmp.activeIdx, ...
                'lastDir',   tmp.lastDir, ...
                'timestamp', tmp.timestamp);
            delete(fp);
        end

        function cleanup()
        %CLEANUP  Stop timer and delete recovery file (clean exit).
            bosonPlotter.autosave.stop();
            fp = fullfile(prefdir, bosonPlotter.autosave.FILENAME);
            if isfile(fp)
                try; delete(fp); catch; end
            end
        end

    end
end
