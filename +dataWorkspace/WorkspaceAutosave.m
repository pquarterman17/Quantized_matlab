classdef WorkspaceAutosave
%WORKSPACEAUTOSAVE  Crash-recovery autosave for DataWorkspace.
%
%   dataWorkspace.WorkspaceAutosave.start(model)   — start 2-min autosave timer
%   dataWorkspace.WorkspaceAutosave.stop()          — stop timer (clean close)
%   dataWorkspace.WorkspaceAutosave.save(model)     — write snapshot to prefdir
%   dataWorkspace.WorkspaceAutosave.check()         — true if recovery file exists
%   dataWorkspace.WorkspaceAutosave.restore(model)  — load recovery, delete file
%   dataWorkspace.WorkspaceAutosave.cleanup()       — delete recovery file (clean exit)
%
%   The autosave file lives at prefdir/dataworkspace_autosave.dwk.  On clean
%   exit (figure close), cleanup() deletes it.  On crash, the file persists
%   and check() returns true on the next startup.
%
% ════════════════════════════════════════════════════════════════════════

    properties (Constant, Access = private)
        INTERVAL_SEC = 120                        % 2 minutes
        FILENAME     = 'dataworkspace_autosave.dwk'
        TIMER_NAME   = 'DataWorkspaceAutosave'
    end

    methods (Static)

        function start(model)
        %START  Begin periodic autosave (every 2 min).
        %
        %   dataWorkspace.WorkspaceAutosave.start(model)
        %
        %   Inputs:
        %     model — dataWorkspace.WorkspaceModel handle
            dataWorkspace.WorkspaceAutosave.stop();  % clear any existing timer
            if model.count() == 0, return; end
            t = timer( ...
                'Name',          dataWorkspace.WorkspaceAutosave.TIMER_NAME, ...
                'ExecutionMode', 'fixedRate', ...
                'Period',        dataWorkspace.WorkspaceAutosave.INTERVAL_SEC, ...
                'StartDelay',    dataWorkspace.WorkspaceAutosave.INTERVAL_SEC, ...
                'TimerFcn',      @(~,~) dataWorkspace.WorkspaceAutosave.save(model));
            start(t);
        end

        function stop()
        %STOP  Stop and delete the autosave timer.
            t = timerfind('Name', dataWorkspace.WorkspaceAutosave.TIMER_NAME);
            if ~isempty(t)
                stop(t);
                delete(t);
            end
        end

        function save(model)
        %SAVE  Write a recovery snapshot to prefdir.
        %
        %   dataWorkspace.WorkspaceAutosave.save(model)
        %
        %   Inputs:
        %     model — dataWorkspace.WorkspaceModel handle
            try
                fp   = dataWorkspace.WorkspaceAutosave.filepath();
                snap = model.createSnapshot();  %#ok<NASGU>
                save(fp, 'snap', '-v7.3');
            catch
                % Silent — autosave is best-effort
            end
        end

        function tf = check()
        %CHECK  True if a recovery file exists (indicates prior crash).
            tf = isfile(dataWorkspace.WorkspaceAutosave.filepath());
        end

        function restore(model)
        %RESTORE  Load recovery data into model and delete the file.
        %
        %   dataWorkspace.WorkspaceAutosave.restore(model)
        %
        %   Inputs:
        %     model — dataWorkspace.WorkspaceModel handle (state will be replaced)
            fp  = dataWorkspace.WorkspaceAutosave.filepath();
            tmp = load(fp);
            model.restoreFromSnapshot(tmp.snap);
            delete(fp);
        end

        function cleanup()
        %CLEANUP  Stop timer and delete recovery file (clean exit).
            dataWorkspace.WorkspaceAutosave.stop();
            fp = dataWorkspace.WorkspaceAutosave.filepath();
            if isfile(fp)
                try; delete(fp); catch; end
            end
        end

    end  % static methods

    methods (Static, Access = private)

        function fp = filepath()
        %FILEPATH  Return the full path to the autosave file.
            fp = fullfile(prefdir, dataWorkspace.WorkspaceAutosave.FILENAME);
        end

    end  % private static methods

end  % classdef WorkspaceAutosave
