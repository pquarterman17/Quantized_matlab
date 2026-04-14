function report = buildReport(options)
%BUILDREPORT  Collect environment, error, and dataset context for a bug report.
%
%   report = bugReport.buildReport()
%   report = bugReport.buildReport(Source="BosonPlotter", Dataset=ds, ...
%                                Error=ME, Description=desc, Email=addr)
%
%   Pure function — no UI, no side effects beyond reading `version`, `computer`,
%   and shelling out to `git` for the toolbox SHA.  Returns a struct suitable
%   for `bugReport.formatReportMarkdown`.
%
%   Name-Value arguments:
%       Source      string  — GUI or script that initiated the report
%       Dataset     struct  — parser data struct (.labels/.units/.metadata/...)
%       Error       MException or [] — if empty, falls back to MException.last
%       Description string  — user-entered description (filled in by dialog)
%       Email       string  — optional reply-to email (filled in by dialog)
%
%   OUTPUT fields:
%       report.env         — .matlabRelease, .computer, .os, .gitSha,
%                            .gitBranch, .toolboxRoot
%       report.error       — .identifier, .message, .stack (or empty struct)
%       report.dataset     — .parser, .filename, .labels, .units, .nRows,
%                            .nCols, .metadata (or empty struct)
%       report.description — user text
%       report.email       — user email
%       report.source      — source label
%       report.generatedAt — ISO 8601 UTC timestamp

    arguments
        options.Source      (1,1) string = "Unknown"
        options.Dataset     struct       = struct()
        options.Error                    = []
        options.Description (1,1) string = ""
        options.Email       (1,1) string = ""
    end

    report = struct();
    report.source      = options.Source;
    report.description = options.Description;
    report.email       = options.Email;
    report.generatedAt = string(datetime('now', 'TimeZone', 'UTC', ...
                                'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

    report.env     = collectEnv();
    report.error   = collectError(options.Error);
    report.dataset = collectDataset(options.Dataset);
end

% ═══════════════════════════════════════════════════════════════════════════
function env = collectEnv()
    env = struct();
    env.matlabRelease = string(version('-release'));
    env.matlabVersion = string(version());
    env.computer      = string(computer());
    env.os            = detectOS();
    env.toolboxRoot   = string(toolboxRoot());
    [env.gitSha, env.gitBranch] = gitInfo(env.toolboxRoot);
end

function osStr = detectOS()
    try
        osStr = string(feature('GetOS'));
    catch
        osStr = string(computer());
    end
end

function root = toolboxRoot()
    % +support lives at <toolboxRoot>/+support/.  mfilename gives the full
    % path of buildReport.m; parent is +support, grandparent is the toolbox.
    supportDir = fileparts(mfilename('fullpath'));
    root       = fileparts(supportDir);
end

function [sha, branch] = gitInfo(root)
    sha    = "unknown";
    branch = "unknown";
    try
        cmd = sprintf('git -C "%s" rev-parse --short HEAD', char(root));
        [status, out] = system(cmd);
        if status == 0
            sha = string(strtrim(out));
        end
        cmd = sprintf('git -C "%s" rev-parse --abbrev-ref HEAD', char(root));
        [status, out] = system(cmd);
        if status == 0
            branch = string(strtrim(out));
        end
    catch
        % Git not available — stay "unknown"
    end
end

% ═══════════════════════════════════════════════════════════════════════════
function err = collectError(explicit)
    if isempty(explicit)
        try
            ME = MException.last;
        catch
            ME = MException.empty;
        end
    elseif isa(explicit, 'MException')
        ME = explicit;
    else
        ME = MException.empty;
    end

    err = struct();
    if isempty(ME)
        return;
    end

    err.identifier = string(ME.identifier);
    err.message    = string(ME.message);
    err.stack      = formatStack(ME.stack);
end

function lines = formatStack(stack)
    if isempty(stack)
        lines = string.empty(0, 1);
        return;
    end
    lines = strings(numel(stack), 1);
    for k = 1:numel(stack)
        frame = stack(k);
        lines(k) = sprintf("  %s (%s:%d)", ...
            frame.name, shortenPath(frame.file), frame.line);
    end
end

function short = shortenPath(p)
    % Strip the toolbox root so stack frames don't leak absolute paths
    % unnecessarily.  Keep basename + parent for context.
    try
        [parent, name, ext] = fileparts(p);
        [~, parentName]     = fileparts(parent);
        if isempty(parentName)
            short = [name, ext];
        else
            short = fullfile(parentName, [name, ext]);
        end
    catch
        short = p;
    end
end

% ═══════════════════════════════════════════════════════════════════════════
function info = collectDataset(ds)
    info = struct();
    if isempty(fieldnames(ds))
        return;
    end

    % Parser name — look in metadata.parser, then metadata.parserName
    if isfield(ds, 'metadata') && isstruct(ds.metadata)
        meta = ds.metadata;
        info.parser   = fieldOrDefault(meta, 'parser',   ...
                        fieldOrDefault(meta, 'parserName', "unknown"));
        info.filename = fieldOrDefault(meta, 'filename', ...
                        fieldOrDefault(meta, 'filepath',  "unknown"));
        % Strip full path — just keep the base name
        if ischar(info.filename) || isstring(info.filename)
            [~, name, ext] = fileparts(char(info.filename));
            info.filename  = string([name, ext]);
        end
    end

    if isfield(ds, 'labels');  info.labels = string(ds.labels(:)');  end
    if isfield(ds, 'units');   info.units  = string(ds.units(:)');   end
    if isfield(ds, 'values')
        info.nRows = size(ds.values, 1);
        info.nCols = size(ds.values, 2);
    end
end

function v = fieldOrDefault(s, name, default)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        v = string(s.(name));
    else
        v = string(default);
    end
end
