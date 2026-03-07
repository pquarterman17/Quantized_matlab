function idx = resolveColumnShorthand(spec, colNames, shorthandMap, label)
%RESOLVECOLUMNSHORTHAND  Resolve a column spec (index, shorthand, or name) to a 1-based index.
%
%   Syntax
%     idx = parser.resolveColumnShorthand(spec, colNames)
%     idx = parser.resolveColumnShorthand(spec, colNames, shorthandMap)
%     idx = parser.resolveColumnShorthand(spec, colNames, shorthandMap, label)
%
%   Inputs
%     spec         — Column specification: numeric index, shorthand string, or column name.
%     colNames     — {1×N} cell array of column name strings.
%     shorthandMap — (optional) {K×2} cell of {'shorthand','target name'} pairs.
%                    Pass [] or omit to skip shorthand expansion.
%     label        — (optional) Role label for error messages (e.g. 'x-axis').
%                    Default: 'column'.
%
%   Output
%     idx  — 1-based column index.
%            Returns 0 when spec is a numeric 0 or an empty string (caller interprets
%            as "no column selected").
%
%   Resolution order
%     1. Numeric index  — validate bounds [1, N] and return (0 → pass-through).
%     2. Empty string   — return 0.
%     3. Shorthand map  — case-insensitive lookup; replace spec with the target name.
%     4. Exact match    — strcmpi against colNames.
%     5. Partial match  — contains() search; shortest matching column name wins.
%     6. Error          — throws parser:resolveColumnShorthand:notFound.
%
%   Examples
%     % With shorthand map (QDVSM / PPMS):
%     map = {'field','Magnetic Field'; 'moment','Moment'; 'temp','Temperature'};
%     idx = parser.resolveColumnShorthand('moment', colNames, map, 'y-axis');
%
%     % Without shorthand map (CSV / Excel plain name resolution):
%     idx = parser.resolveColumnShorthand('Temperature (K)', colNames);
%
%   See also parser.importQDVSM, parser.importPPMS, parser.importCSV, parser.importExcel
%
% ════════════════════════════════════════════════════════════════════════════

    arguments
        spec
        colNames  cell
        shorthandMap  = []
        label     (1,:) char = 'column'
    end

    N = numel(colNames);

    % ── 1. Numeric index ─────────────────────────────────────────────────
    if isnumeric(spec)
        idx = double(spec);
        if idx == 0
            return;   % 0 means "no column" for optional specs
        end
        if idx < 1 || idx > N
            error('parser:resolveColumnShorthand:indexOutOfRange', ...
                '%s index %d is out of range (1–%d).', label, idx, N);
        end
        return;
    end

    spec = char(spec);

    % ── 2. Empty string — treat as "no column" ───────────────────────────
    if isempty(spec)
        idx = 0;
        return;
    end

    % ── 3. Shorthand map ─────────────────────────────────────────────────
    if ~isempty(shorthandMap)
        for k = 1:size(shorthandMap, 1)
            if strcmpi(spec, shorthandMap{k, 1})
                spec = shorthandMap{k, 2};
                break;
            end
        end
    end

    % ── 4. Exact match ───────────────────────────────────────────────────
    idx = find(strcmpi(colNames, spec), 1);
    if ~isempty(idx), return; end

    % ── 5. Partial match (shortest wins when ambiguous) ───────────────────
    matches = find(contains(colNames, spec, 'IgnoreCase', true));
    if numel(matches) == 1
        idx = matches;
        return;
    elseif numel(matches) > 1
        [~, best] = min(cellfun(@numel, colNames(matches)));
        idx = matches(best);
        return;
    end

    % ── 6. Not found ─────────────────────────────────────────────────────
    error('parser:resolveColumnShorthand:notFound', ...
        'Cannot resolve %s "%s".\nAvailable columns:\n  %s', ...
        label, spec, strjoin(colNames, '\n  '));
end
