function logError(title, msg, ME, options)
%LOGERROR  Append a structured error entry to gui_bug_log.txt at the toolbox root.
%
%   utilities.logError(title, msg)
%   utilities.logError(title, msg, ME)
%   utilities.logError(title, msg, ME, 'LogFile', '/path/to/custom.log')
%
%   Mirrors the format used by BosonPlotter's internal logGUIError so any
%   tooling that scans gui_bug_log.txt continues to work.  Safe to call from
%   any package code (parsers, GUI callbacks, COM bridges).  Never throws —
%   logging failures are swallowed so a broken disk never crashes the caller.
%
%   INPUTS:
%       title    — short tag identifying the failure site (e.g. 'toOrigin:com')
%       msg      — human-readable message string (will be passed through char())
%
%   OPTIONAL:
%       ME       — MException object; identifier and stack are recorded if present
%
%   NAME-VALUE:
%       LogFile  — override the destination path; defaults to gui_bug_log.txt
%                  located alongside the +utilities package (i.e. toolbox root)

    arguments
        title              (1,:) char
        msg                (1,:) char
        ME                 = []          % MException or empty
        options.LogFile    (1,:) char = ''
    end

    % Resolve default log file: <toolbox_root>/gui_bug_log.txt.
    % +utilities/logError.m  →  +utilities/  →  <toolbox_root>
    if isempty(options.LogFile)
        thisFile     = mfilename('fullpath');
        utilitiesDir = fileparts(thisFile);
        toolboxRoot  = fileparts(utilitiesDir);
        logFile      = fullfile(toolboxRoot, 'gui_bug_log.txt');
    else
        logFile = options.LogFile;
    end

    try
        fid = fopen(logFile, 'a');
        if fid == -1, return; end
        cleanup = onCleanup(@() fclose(fid));

        stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
        fprintf(fid, '\n%s\n', repmat('=', 1, 68));
        fprintf(fid, '[%s]  %s\n', stamp, title);
        fprintf(fid, 'Message: %s\n', msg);

        if ~isempty(ME) && isa(ME, 'MException')
            if ~isempty(ME.identifier)
                fprintf(fid, 'Identifier: %s\n', ME.identifier);
            end
            if ~isempty(ME.stack)
                fprintf(fid, 'Stack:\n');
                for si = 1:numel(ME.stack)
                    fprintf(fid, '  %s  (line %d)\n', ...
                        ME.stack(si).name, ME.stack(si).line);
                end
            end
        end
    catch
        % Logging must never crash the caller — swallow any I/O failure.
    end
end
