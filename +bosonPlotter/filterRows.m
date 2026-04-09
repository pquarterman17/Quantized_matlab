function mask = filterRows(dataStruct, expression)
%FILTERROWS  Evaluate a filter expression against a data struct.
%
%   Syntax:
%     mask = bosonPlotter.filterRows(dataStruct, expression)
%
%   Inputs:
%     dataStruct  — unified data struct with fields .time, .values, .labels,
%                   .units (as returned by parser.createDataStruct)
%     expression  — filter string, e.g. "Temp > 300" or
%                   "Field > 0 & Moment < 1e-3" or "between(x, 100, 200)"
%                   Token 'x' (case-insensitive) maps to .time.
%                   Column tokens match .labels by case-insensitive partial
%                   match (first match wins; shortest label preferred).
%                   Supported operators : > < >= <= == ~= & | ~
%                   Supported functions : abs(col), between(col, lo, hi)
%
%   Outputs:
%     mask  — [N×1] logical, true = row passes the filter
%
%   Examples:
%     mask = bosonPlotter.filterRows(d, 'Temp > 300')
%     mask = bosonPlotter.filterRows(d, 'Field >= -500 & Field <= 500')
%     mask = bosonPlotter.filterRows(d, 'between(x, 0, 1e-3)')
%     mask = bosonPlotter.filterRows(d, '')   % all-true mask

arguments
    dataStruct (1,1) struct
    expression (1,:) char
end

% ════════════════════════════════════════════════════════════════════════
%  Fast return for empty expression
% ════════════════════════════════════════════════════════════════════════
nRows = numel(dataStruct.time);
if isempty(strtrim(expression))
    mask = true(nRows, 1);
    return;
end

% ════════════════════════════════════════════════════════════════════════
%  Column resolver — builds a struct mapping lower-case label → column vec
% ════════════════════════════════════════════════════════════════════════
colData = buildColumnMap(dataStruct);

% ════════════════════════════════════════════════════════════════════════
%  Tokenise → recursive-descent parse → logical mask
% ════════════════════════════════════════════════════════════════════════
tokens = tokenise(expression);
pos    = 1;
mask   = parseOr();

if pos <= numel(tokens)
    error('bosonPlotter:filterRows:unexpectedToken', ...
        'Unexpected token ''%s'' near end of expression.', tokens{pos});
end

% Ensure column-vector output
mask = logical(mask(:));

% ════════════════════════════════════════════════════════════════════════
%  Nested parsing functions  (share pos, tokens, colData via closure)
% ════════════════════════════════════════════════════════════════════════

    % ── OR level  (|) ────────────────────────────────────────────────────
    function val = parseOr()
        val = parseAnd();
        while pos <= numel(tokens) && strcmp(tokens{pos}, '|')
            pos = pos + 1;
            val = val | parseAnd();
        end
    end

    % ── AND level  (&) ───────────────────────────────────────────────────
    function val = parseAnd()
        val = parseNot();
        while pos <= numel(tokens) && strcmp(tokens{pos}, '&')
            pos = pos + 1;
            val = val & parseNot();
        end
    end

    % ── NOT level  (~) ───────────────────────────────────────────────────
    function val = parseNot()
        if pos <= numel(tokens) && strcmp(tokens{pos}, '~')
            % Only treat as NOT when NOT followed by '=' (inequality handled
            % at comparison level)
            if pos + 1 <= numel(tokens) && strcmp(tokens{pos + 1}, '=')
                % ~= is a comparison token, handled in parseComparison
                val = parseComparison();
            else
                pos = pos + 1;
                val = ~parseNot();
            end
        else
            val = parseComparison();
        end
    end

    % ── Comparison level  (> < >= <= == ~=) ──────────────────────────────
    function val = parseComparison()
        lhs = parseAddSub();
        if pos > numel(tokens)
            val = lhs;
            return;
        end
        op = tokens{pos};
        if ~any(strcmp(op, {'>', '<', '>=', '<=', '==', '~='}))
            val = lhs;
            return;
        end
        pos = pos + 1;
        rhs = parseAddSub();

        % Dispatch table instead of eval
        switch op
            case '>'
                val = lhs > rhs;
            case '<'
                val = lhs < rhs;
            case '>='
                val = lhs >= rhs;
            case '<='
                val = lhs <= rhs;
            case '=='
                val = lhs == rhs;
            case '~='
                val = lhs ~= rhs;
            otherwise
                error('bosonPlotter:filterRows:unknownOp', ...
                    'Unknown comparison operator ''%s''.', op);
        end
    end

    % ── Additive level  (+ -) ────────────────────────────────────────────
    function val = parseAddSub()
        val = parseMulDiv();
        while pos <= numel(tokens) && any(strcmp(tokens{pos}, {'+', '-'}))
            op = tokens{pos}; pos = pos + 1;
            rhs = parseMulDiv();
            if op == '+'
                val = val + rhs;
            else
                val = val - rhs;
            end
        end
    end

    % ── Multiplicative level  (* /) ───────────────────────────────────────
    function val = parseMulDiv()
        val = parseUnary();
        while pos <= numel(tokens) && any(strcmp(tokens{pos}, {'*', '/'}))
            op = tokens{pos}; pos = pos + 1;
            rhs = parseUnary();
            if op == '*'
                val = val .* rhs;
            else
                val = val ./ rhs;
            end
        end
    end

    % ── Unary minus ───────────────────────────────────────────────────────
    function val = parseUnary()
        if pos <= numel(tokens) && strcmp(tokens{pos}, '-')
            pos = pos + 1;
            val = -parsePrimary();
        else
            val = parsePrimary();
        end
    end

    % ── Primary: literals, columns, functions, parentheses ───────────────
    function val = parsePrimary()
        if pos > numel(tokens)
            error('bosonPlotter:filterRows:unexpectedEnd', ...
                'Unexpected end of filter expression.');
        end
        tok = tokens{pos};

        % ── parenthesised sub-expression ──────────────────────────────
        if strcmp(tok, '(')
            pos = pos + 1;
            val = parseOr();
            if pos > numel(tokens) || ~strcmp(tokens{pos}, ')')
                error('bosonPlotter:filterRows:missingParen', ...
                    'Missing closing parenthesis in filter expression.');
            end
            pos = pos + 1;
            return;
        end

        % ── supported functions ────────────────────────────────────────
        tokLow = lower(tok);
        if strcmp(tokLow, 'abs')
            pos = pos + 1;
            expectOpen();
            arg = parseAddSub();
            expectClose();
            val = abs(arg);
            return;
        end

        if strcmp(tokLow, 'between')
            pos = pos + 1;
            expectOpen();
            col = parseAddSub();
            expectComma();
            lo  = parseAddSub();
            expectComma();
            hi  = parseAddSub();
            expectClose();
            val = (col >= lo) & (col <= hi);
            return;
        end

        % ── numeric literal ────────────────────────────────────────────
        numVal = str2double(tok);
        if ~isnan(numVal)
            val = numVal;
            pos = pos + 1;
            return;
        end

        % ── column token (label or 'x' for time) ──────────────────────
        if isKey(colData, tokLow)
            val = colData(tokLow);
            pos = pos + 1;
            return;
        end

        error('bosonPlotter:filterRows:unknownToken', ...
            'Unknown token ''%s''. Not a number, column name, or supported function.', ...
            tok);
    end

    % ── Helper: expect '(' / ')' / ',' ────────────────────────────────────
    function expectOpen()
        if pos > numel(tokens) || ~strcmp(tokens{pos}, '(')
            error('bosonPlotter:filterRows:missingOpenParen', ...
                'Expected ''('' after function name.');
        end
        pos = pos + 1;
    end

    function expectClose()
        if pos > numel(tokens) || ~strcmp(tokens{pos}, ')')
            error('bosonPlotter:filterRows:missingCloseParen', ...
                'Expected '')'' after function argument(s).');
        end
        pos = pos + 1;
    end

    function expectComma()
        if pos > numel(tokens) || ~strcmp(tokens{pos}, ',')
            error('bosonPlotter:filterRows:missingComma', ...
                'Expected '','' between function arguments.');
        end
        pos = pos + 1;
    end

end  % filterRows

% ════════════════════════════════════════════════════════════════════════
%  Local helper: buildColumnMap
%   Returns a containers.Map: lowercaseName → [N×1] double vector
% ════════════════════════════════════════════════════════════════════════
function colData = buildColumnMap(dataStruct)
%BUILDCOLUMNMAP  Build name→vector map from dataStruct fields.
%   'x' maps to .time.  Label tokens are matched case-insensitively;
%   for partial matches the shortest matching label wins.

colData = containers.Map('KeyType', 'char', 'ValueType', 'any');

% Always add 'x' → time
colData('x') = dataStruct.time(:);

if ~isfield(dataStruct, 'labels') || isempty(dataStruct.labels)
    return;
end

labels  = dataStruct.labels;   % cell array of strings
nLabels = numel(labels);
nCols   = size(dataStruct.values, 2);

% Exact lower-case mappings first
for ci = 1:min(nLabels, nCols)
    key = lower(strtrim(labels{ci}));
    if ~isempty(key) && ~isKey(colData, key)
        colData(key) = dataStruct.values(:, ci);
    end
end

% Also register every unique lower-case token within each label
% (handles labels like "Temperature (K)" → also accessible as "temperature")
for ci = 1:min(nLabels, nCols)
    parts = strsplit(strtrim(labels{ci}), {' ', '_', '(', ')', '[', ']', '/', '-'});
    for pi = 1:numel(parts)
        key = lower(strtrim(parts{pi}));
        if ~isempty(key) && isvarname(key) && ~isKey(colData, key)
            colData(key) = dataStruct.values(:, ci);
        end
    end
end

end  % buildColumnMap

% ════════════════════════════════════════════════════════════════════════
%  Local helper: tokenise
%   Converts expression string into cell array of string tokens.
% ════════════════════════════════════════════════════════════════════════
function toks = tokenise(expr)
%TOKENISE  Split a filter expression string into tokens.
%   Recognised token classes:
%     Identifiers   — [A-Za-z][A-Za-z0-9_]*
%     Numbers       — decimal / scientific-notation literals
%     Two-char ops  — >= <= == ~=
%     One-char ops  — > < & | ~ + - * / ( ) ,

s    = strtrim(expr);
toks = {};
i    = 1;
n    = numel(s);

while i <= n
    c = s(i);

    % Skip whitespace
    if c == ' ' || c == 9
        i = i + 1;
        continue;
    end

    % Two-character operators
    if i < n
        two = s(i:i+1);
        if any(strcmp(two, {'>=', '<=', '==', '~='}))
            toks{end+1} = two; %#ok<AGROW>
            i = i + 2;
            continue;
        end
    end

    % Single-character operators / punctuation
    if any(c == '><&|~+-*/(),')
        toks{end+1} = c; %#ok<AGROW>
        i = i + 1;
        continue;
    end

    % Identifier
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
        j = i;
        while j <= n && ((s(j) >= 'a' && s(j) <= 'z') || ...
                         (s(j) >= 'A' && s(j) <= 'Z') || ...
                         (s(j) >= '0' && s(j) <= '9') || s(j) == '_')
            j = j + 1;
        end
        toks{end+1} = s(i:j-1); %#ok<AGROW>
        i = j;
        continue;
    end

    % Number (decimal and scientific notation, including leading dot)
    if (c >= '0' && c <= '9') || c == '.'
        j = i;
        % Integer / fractional part
        while j <= n && ((s(j) >= '0' && s(j) <= '9') || s(j) == '.')
            j = j + 1;
        end
        % Optional exponent
        if j <= n && (s(j) == 'e' || s(j) == 'E')
            j = j + 1;
            if j <= n && (s(j) == '+' || s(j) == '-')
                j = j + 1;
            end
            while j <= n && s(j) >= '0' && s(j) <= '9'
                j = j + 1;
            end
        end
        toks{end+1} = s(i:j-1); %#ok<AGROW>
        i = j;
        continue;
    end

    error('bosonPlotter:filterRows:badChar', ...
        'Unrecognised character ''%s'' in filter expression.', c);
end
end  % tokenise
