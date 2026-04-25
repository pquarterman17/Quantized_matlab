function ds = appendHistory(ds, category, summary, cmd)
%APPENDHISTORY  Append an operation entry to a dataset's provenance log.
%
%   ds = bosonPlotter.appendHistory(ds, category, summary, cmd)
%
%   Each dataset carries a `.history` struct array recording every
%   transformation applied to it (Mantid-style operation history).
%   Entries are append-only and persist across session save/load.
%
%   Inputs:
%     ds       — dataset struct (mutated; result returned)
%     category — short tag, e.g. 'import', 'correction', 'fit', 'mask',
%                'transform', 'manual'. Lowercase by convention.
%     summary  — one-line human-readable description (e.g. 'smooth=5,
%                yOff=0.1, polyBg deg 2')
%     cmd      — MATLAB command string that, when run, reproduces the
%                operation. Empty string if the operation isn't trivially
%                replayable (the entry is then informational only).
%
%   Output:
%     ds — updated dataset with a new entry appended to ds.history. If
%          the input ds has no `.history` field, one is created.
%
%   Schema of each history entry:
%     .timestamp  datetime
%     .category   char
%     .summary    char
%     .cmd        char  (may be empty)
%
%   Example:
%     ds = bosonPlotter.appendHistory(ds, 'import', ...
%             'imported sample.dat via importQDVSM', ...
%             "data = parser.importQDVSM('sample.dat');");

    arguments
        ds        struct
        category  (1,1) string
        summary   (1,1) string
        cmd       (1,1) string = ""
    end

    entry = struct( ...
        'timestamp', datetime('now'), ...
        'category',  char(category), ...
        'summary',   char(summary), ...
        'cmd',       char(cmd));

    if ~isfield(ds, 'history') || isempty(ds.history)
        ds.history = entry;
    else
        ds.history(end+1) = entry;
    end
end
