function txt = getHistoryScript(ds, opts)
%GETHISTORYSCRIPT  Format a dataset's provenance log as a runnable .m script.
%
%   txt = bosonPlotter.getHistoryScript(ds)
%   txt = bosonPlotter.getHistoryScript(ds, IncludeComments=true, ...
%                                            Header=true)
%
%   Walks ds.history (built by `bosonPlotter.appendHistory`) and emits
%   a self-contained MATLAB script that, when run, replays the recorded
%   transformations. Entries with an empty .cmd are emitted as comment
%   lines so the human-readable summary still appears in the script.
%
%   Inputs:
%     ds  — dataset struct with a `.history` struct array
%     opts.IncludeComments — prepend a `% [HH:mm:ss] category: summary`
%                             line before each command (default true)
%     opts.Header          — include the standard `setupToolbox` header
%                             block (default true)
%
%   Output:
%     txt — newline-joined script text (char). Suitable for `fprintf` or
%           `writelines`. Replay with `run(filepath)`.
%
%   Examples:
%     fid = fopen('replay.m', 'w');
%     fprintf(fid, '%s', bosonPlotter.getHistoryScript(ds));
%     fclose(fid);
%     run('replay.m')
%
%   See also bosonPlotter.appendHistory, bosonPlotter.exportHistoryScript

    arguments
        ds                       struct
        opts.IncludeComments    (1,1) logical = true
        opts.Header             (1,1) logical = true
    end

    lines = strings(0, 1);

    if opts.Header
        lines(end+1, 1) = "%% Dataset provenance replay";
        if isfield(ds, 'filepath') && ~isempty(ds.filepath)
            lines(end+1, 1) = "% Source: " + string(ds.filepath);
        end
        if isfield(ds, 'history') && ~isempty(ds.history)
            lines(end+1, 1) = "% Entries: " + numel(ds.history);
        end
        lines(end+1, 1) = "% Generated: " + string(datetime('now'));
        lines(end+1, 1) = "";
        lines(end+1, 1) = "setupToolbox;";
        lines(end+1, 1) = "";
    end

    if ~isfield(ds, 'history') || isempty(ds.history)
        lines(end+1, 1) = "% (no history entries on this dataset)";
        txt = char(strjoin(lines, newline));
        return;
    end

    for k = 1:numel(ds.history)
        e = ds.history(k);
        if opts.IncludeComments
            ts = char(e.timestamp, 'HH:mm:ss');
            lines(end+1, 1) = string(sprintf('%% [%s] %s: %s', ts, e.category, e.summary)); %#ok<AGROW>
        end
        if isempty(e.cmd)
            % Informational-only entry; emit a comment so it's preserved.
            if ~opts.IncludeComments
                lines(end+1, 1) = string(sprintf('%% %s: %s', e.category, e.summary)); %#ok<AGROW>
            end
        else
            lines(end+1, 1) = string(e.cmd); %#ok<AGROW>
        end
    end

    if opts.Header
        lines(end+1, 1) = "";
        lines(end+1, 1) = "%% End of provenance replay";
    end

    txt = char(strjoin(lines, newline));
end
