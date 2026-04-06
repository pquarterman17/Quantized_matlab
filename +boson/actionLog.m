classdef actionLog < handle
%ACTIONLOG  Record GUI actions as reproducible MATLAB commands.
%
%   log = boson.actionLog()
%   log.record("data = parser.importAuto('file.dat');")
%   log.record("data = utilities.smoothData(data.time, data.values, 5);")
%   log.exportScript('analysis.m')
%
%   Tracks a sequence of MATLAB command strings representing GUI actions.
%   Export as a standalone .m script for reproducibility.
%
%   Methods:
%       record(cmd)        — append a command string to the log
%       undo()             — remove the last recorded command
%       clear()            — clear all recorded commands
%       getLog()           — return cell array of all commands
%       getScript()        — return the log as a formatted script string
%       exportScript(path) — write the script to a .m file
%       nEntries()         — number of recorded commands
%
%   Example:
%       log = boson.actionLog();
%       log.record("setupToolbox;");
%       log.record("d = parser.importAuto('sample.dat');");
%       log.record("d.corrData = utilities.smoothData(d.data.time, d.data.values, 5);");
%       log.exportScript('my_analysis.m');

    properties (Access = private)
        commands  cell = {}
        timestamps datetime = datetime.empty
    end

    methods
        function obj = actionLog()
            %ACTIONLOG  Create a new empty action log.
            obj.commands = {};
            obj.timestamps = datetime.empty;
        end

        function record(obj, cmd)
            %RECORD  Append a command string to the log.
            arguments
                obj
                cmd (1,1) string
            end
            obj.commands{end+1} = char(cmd);
            obj.timestamps(end+1) = datetime('now');
        end

        function undo(obj)
            %UNDO  Remove the last recorded command.
            if ~isempty(obj.commands)
                obj.commands(end) = [];
                obj.timestamps(end) = [];
            end
        end

        function clear(obj)
            %CLEAR  Clear all recorded commands.
            obj.commands = {};
            obj.timestamps = datetime.empty;
        end

        function cmds = getLog(obj)
            %GETLOG  Return cell array of all recorded commands.
            cmds = obj.commands;
        end

        function n = nEntries(obj)
            %NENTRIES  Number of recorded commands.
            n = numel(obj.commands);
        end

        function txt = getScript(obj)
            %GETSCRIPT  Format the log as a standalone MATLAB script.
            lines = {};
            lines{end+1} = '%% Analysis Script';
            lines{end+1} = sprintf('%% Generated: %s', char(datetime('now')));
            lines{end+1} = sprintf('%% Commands:  %d', numel(obj.commands));
            lines{end+1} = '';
            lines{end+1} = '% Setup';
            lines{end+1} = 'setupToolbox;';
            lines{end+1} = '';

            % Group commands by section (detect file loads as section breaks)
            for i = 1:numel(obj.commands)
                cmd = obj.commands{i};
                % Add timestamp as comment
                if i <= numel(obj.timestamps)
                    lines{end+1} = sprintf('%% [%s]', ...
                        char(obj.timestamps(i), 'HH:mm:ss')); %#ok<AGROW>
                end
                lines{end+1} = cmd; %#ok<AGROW>
            end

            lines{end+1} = '';
            lines{end+1} = '%% End of script';
            txt = strjoin(lines, newline);
        end

        function exportScript(obj, filepath)
            %EXPORTSCRIPT  Write the script to a .m file.
            arguments
                obj
                filepath (1,1) string
            end
            txt = obj.getScript();
            fid = fopen(char(filepath), 'w');
            if fid == -1
                error('boson:actionLog:writeError', ...
                    'Cannot write to "%s".', filepath);
            end
            fprintf(fid, '%s', txt);
            fclose(fid);
        end
    end
end
