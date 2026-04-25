function txt = formatHistory(ds, opts)
%FORMATHISTORY  Pretty-print a dataset's provenance log for display.
%
%   txt = bosonPlotter.formatHistory(ds)
%
%   Returns a multi-line char with one row per history entry, suitable
%   for command-window display, a uitextarea, or a tooltip. Distinct
%   from `getHistoryScript`, which returns runnable code — this function
%   formats for *reading*, not replay.
%
%   Format (one entry per line):
%     1. [HH:mm:ss] category: summary
%
%   Options:
%     opts.MaxRows — truncate to first N entries (default Inf, all rows)
%
%   Example:
%     disp(bosonPlotter.formatHistory(ds))
%     % 1. [09:14:02] import:     imported sample.dat via importQDVSM
%     % 2. [09:14:30] correction: smooth=5, polyBg deg 2
%     % 3. [09:15:11] fit:        Lorentzian peak @ x=42.3 (FWHM=0.18)

    arguments
        ds                  struct
        opts.MaxRows  (1,1) double = Inf
    end

    if ~isfield(ds, 'history') || isempty(ds.history)
        txt = '(no history entries)';
        return;
    end

    n = numel(ds.history);
    nShow = min(n, opts.MaxRows);

    lines = strings(nShow, 1);
    for k = 1:nShow
        e = ds.history(k);
        ts = char(e.timestamp, 'HH:mm:ss');
        lines(k) = sprintf('%2d. [%s] %-11s %s', ...
            k, ts, [e.category ':'], e.summary);
    end

    if nShow < n
        lines(end+1) = sprintf('... (%d more entries)', n - nShow);
    end

    txt = char(strjoin(lines, newline));
end
