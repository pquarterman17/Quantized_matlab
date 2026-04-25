classdef actionLog < handle
%ACTIONLOG  Record GUI actions as reproducible MATLAB commands.
%
%   log = bosonPlotter.actionLog()
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
%       log = bosonPlotter.actionLog();
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

        function recordCall(obj, fn, args, opts)
            %RECORDCALL  Record a structured function call.
            %
            %   log.recordCall(fn, {arg1, arg2, ...})
            %   log.recordCall(fn, args, Lhs="d")
            %   log.recordCall(fn, args, Lhs="d", Raw=[true false ...])
            %
            %   Builds a single MATLAB statement and appends it to the log.
            %   Each entry of `args` is converted to a literal via
            %   `bosonPlotter.serializeArg`. To pass an expression instead
            %   of a value-to-be-serialized (e.g. an existing variable
            %   `data.values`), set the corresponding `Raw` flag to true
            %   and pass the expression as a string in `args`.
            %
            %   Inputs:
            %     fn   — function name (string), e.g. "parser.importAuto"
            %     args — cell array of argument values (or expressions if Raw)
            %     Lhs  — optional left-hand-side variable name (default "")
            %     Raw  — logical vector matching numel(args); true entries
            %            are inserted verbatim. Default = false(1, numel(args)).
            %
            %   Examples:
            %     log.recordCall("parser.importAuto", {'sample.dat'}, Lhs="d")
            %       % d = parser.importAuto('sample.dat');
            %     log.recordCall("utilities.smoothData", ...
            %                    {"d.time", "d.values", 5}, ...
            %                    Lhs="d.values", Raw=[true true false])
            %       % d.values = utilities.smoothData(d.time, d.values, 5);
            arguments
                obj
                fn   (1,1) string
                args      cell
                opts.Lhs  (1,1) string  = ""
                opts.Raw  (1,:) logical = false(1,0)
            end
            n = numel(args);
            if isempty(opts.Raw)
                rawMask = false(1, n);
            elseif numel(opts.Raw) == n
                rawMask = opts.Raw;
            else
                error('bosonPlotter:actionLog:rawMaskSize', ...
                    'Raw mask must have %d entries, got %d.', n, numel(opts.Raw));
            end

            argStrs = cell(1, n);
            for k = 1:n
                if rawMask(k)
                    argStrs{k} = char(args{k});
                else
                    argStrs{k} = bosonPlotter.serializeArg(args{k});
                end
            end
            argList = strjoin(argStrs, ', ');

            if strlength(opts.Lhs) > 0
                cmd = sprintf('%s = %s(%s);', char(opts.Lhs), char(fn), argList);
            else
                cmd = sprintf('%s(%s);', char(fn), argList);
            end
            obj.record(string(cmd));
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
                error('bosonPlotter:actionLog:writeError', ...
                    'Cannot write to "%s".', filepath);
            end
            fprintf(fid, '%s', txt);
            fclose(fid);
        end
    end
end
