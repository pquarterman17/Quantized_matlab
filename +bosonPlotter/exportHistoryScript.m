function exportHistoryScript(ds, filepath, opts)
%EXPORTHISTORYSCRIPT  Write a dataset's provenance log to a .m file.
%
%   bosonPlotter.exportHistoryScript(ds, 'replay.m')
%   bosonPlotter.exportHistoryScript(ds, 'replay.m', IncludeComments=false)
%
%   Convenience wrapper around `bosonPlotter.getHistoryScript` that
%   writes the formatted script to disk. Errors with a clear identifier
%   when the file can't be written or the dataset has no history.
%
%   Inputs:
%     ds       — dataset struct with `.history` (built via
%                `bosonPlotter.appendHistory`)
%     filepath — destination .m path (string or char)
%     opts     — forwarded to `getHistoryScript`:
%                  .IncludeComments (default true)
%                  .Header          (default true)
%
%   Errors:
%     bosonPlotter:exportHistoryScript:emptyHistory — dataset has no entries
%     bosonPlotter:exportHistoryScript:writeError   — cannot open destination

    arguments
        ds                       struct
        filepath                 (1,1) string
        opts.IncludeComments    (1,1) logical = true
        opts.Header             (1,1) logical = true
    end

    if ~isfield(ds, 'history') || isempty(ds.history)
        error('bosonPlotter:exportHistoryScript:emptyHistory', ...
            'Dataset has no history entries — nothing to export.');
    end

    txt = bosonPlotter.getHistoryScript(ds, ...
        IncludeComments=opts.IncludeComments, ...
        Header=opts.Header);

    fid = fopen(char(filepath), 'w');
    if fid == -1
        error('bosonPlotter:exportHistoryScript:writeError', ...
            'Cannot write to "%s".', filepath);
    end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', txt);
end
