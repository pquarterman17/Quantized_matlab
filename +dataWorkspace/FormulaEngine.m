classdef FormulaEngine
%FORMULAENGINE  Parse and evaluate column formulas for computed columns.
%
% ── Syntax ────────────────────────────────────────────────────────────────
%
%   result = dataWorkspace.FormulaEngine.evaluate(expression, dataStruct)
%   tokens = dataWorkspace.FormulaEngine.tokenize(expression)
%   rpn    = dataWorkspace.FormulaEngine.toRPN(tokens)
%   result = dataWorkspace.FormulaEngine.evalRPN(rpn, dataStruct)
%   tf     = dataWorkspace.FormulaEngine.hasCircularRef(expression, dependsOn)
%
% ── Overview ──────────────────────────────────────────────────────────────
%
%   FormulaEngine provides a safe tokenizer → RPN converter → evaluator
%   pipeline for column formulas.  It does NOT use eval(), feval() with
%   dynamic strings, or str2func() on user input.
%
%   Column references:
%     col("Temperature") or $Temperature — resolved to data.values column
%     col(0) or $X                       — resolved to data.time
%
%   Supported operators:  + - * / ^  (element-wise)
%   Supported functions:  sin cos tan exp log log10 sqrt abs round floor
%                         ceil diff cumsum cumtrapz
%   Constants:            pi, e
%
% ── Examples ──────────────────────────────────────────────────────────────
%
%   data = parser.createDataStruct((1:10)', rand(10,2), ...
%       'labels', {'Field','Moment'}, 'units', {'Oe','emu'});
%   result = dataWorkspace.FormulaEngine.evaluate('$Field / 79.5775', data);
%   result = dataWorkspace.FormulaEngine.evaluate('col("Field") * 2', data);
%   result = dataWorkspace.FormulaEngine.evaluate('sqrt($X^2 + $Field^2)', data);
%
% ════════════════════════════════════════════════════════════════════════

    methods (Static)

        % ════════════════════════════════════════════════════════════════════
        %  Public API
        % ════════════════════════════════════════════════════════════════════

        function result = evaluate(expression, dataStruct)
        %EVALUATE  Parse and evaluate a formula against a data struct.
        %
        %   result = dataWorkspace.FormulaEngine.evaluate(expression, dataStruct)
        %
        %   Inputs:
        %     expression  — formula string, e.g. 'col("Field") / 79.5775'
        %     dataStruct  — unified data struct (.time, .values, .labels, .units)
        %
        %   Outputs:
        %     result — [Nx1] double vector, same length as dataStruct.time
        %
        %   Errors (with descriptive messages):
        %     Unknown column name, syntax error, dimension mismatch.
            arguments
                expression  (1,1) string
                dataStruct  (1,1) struct
            end

            tokens = dataWorkspace.FormulaEngine.tokenize(expression);
            rpn    = dataWorkspace.FormulaEngine.toRPN(tokens);
            result = dataWorkspace.FormulaEngine.evalRPN(rpn, dataStruct);
        end

        function tokens = tokenize(expression)
        %TOKENIZE  Break a formula string into a cell array of token structs.
        %
        %   tokens = dataWorkspace.FormulaEngine.tokenize(expression)
        %
        %   Each token is a struct with fields:
        %     .type  — 'number' | 'column' | 'function' | 'operator' |
        %              'lparen' | 'rparen' | 'constant'
        %     .value — numeric value (numbers/constants), string name
        %              (functions), or column-name string (columns)
        %
        %   Column references are recognised as single tokens:
        %     col("name")  or  col('name')
        %     col(0)                          → X axis
        %     $name                           → col("name")
        %     $X                              → col(0) / time axis
            arguments
                expression (1,1) string
            end

            expr = char(strtrim(expression));
            if isempty(expr)
                error('dataWorkspace:FormulaEngine:emptyExpression', ...
                    'Formula expression is empty.');
            end

            % ── Dispatch tables (no eval / str2func) ─────────────────────
            funcNames = dataWorkspace.FormulaEngine.supportedFunctions();
            funcSet   = containers.Map(funcNames, true(1, numel(funcNames)));

            constMap  = containers.Map({'pi','e'}, [pi, exp(1)]);

            tokens   = {};
            pos      = 1;
            len      = length(expr);
            prevType = 'start';

            while pos <= len
                ch = expr(pos);

                % Skip whitespace
                if ch == ' ' || ch == char(9)
                    pos = pos + 1;
                    continue;
                end

                % ── col("name") or col(0) reference ──────────────────────
                if pos + 2 <= len && strncmp(expr(pos:end), 'col', 3) ...
                        && (pos + 3 > len || ~dataWorkspace.FormulaEngine.isIdentChar(expr(pos+3)))
                    [tok, pos] = dataWorkspace.FormulaEngine.readColRef(expr, pos + 3);
                    tokens{end+1} = tok;     %#ok<AGROW>
                    prevType = 'value';
                    continue;
                end

                % ── $name shorthand ───────────────────────────────────────
                if ch == '$'
                    [tok, pos] = dataWorkspace.FormulaEngine.readDollarRef(expr, pos + 1);
                    tokens{end+1} = tok;     %#ok<AGROW>
                    prevType = 'value';
                    continue;
                end

                % ── Number literal ────────────────────────────────────────
                if dataWorkspace.FormulaEngine.isDigit(ch) || ...
                   (ch == '.' && pos < len && dataWorkspace.FormulaEngine.isDigit(expr(pos+1)))
                    [numStr, pos] = dataWorkspace.FormulaEngine.readNumber(expr, pos);
                    tokens{end+1} = struct('type', 'number', 'value', str2double(numStr)); %#ok<AGROW>
                    prevType = 'value';
                    continue;
                end

                % ── Identifier: function, constant, or bare word ──────────
                if dataWorkspace.FormulaEngine.isLetter(ch) || ch == '_'
                    [name, pos] = dataWorkspace.FormulaEngine.readIdent(expr, pos);

                    if funcSet.isKey(name)
                        tokens{end+1} = struct('type', 'function', 'value', name); %#ok<AGROW>
                        prevType = 'function';
                    elseif constMap.isKey(name)
                        tokens{end+1} = struct('type', 'number', 'value', constMap(name)); %#ok<AGROW>
                        prevType = 'value';
                    else
                        % Treat bare identifier as column reference by name
                        tokens{end+1} = struct('type', 'column', 'value', name); %#ok<AGROW>
                        prevType = 'value';
                    end
                    continue;
                end

                % ── Operators and parentheses ─────────────────────────────
                if any(ch == '+-*/^()')
                    if ch == '('
                        tokens{end+1} = struct('type', 'lparen', 'value', '('); %#ok<AGROW>
                        prevType = 'lparen';
                    elseif ch == ')'
                        tokens{end+1} = struct('type', 'rparen', 'value', ')'); %#ok<AGROW>
                        prevType = 'value';
                    elseif ch == '-' && any(strcmp(prevType, {'start','lparen','operator'}))
                        % Unary minus → insert 0 -
                        tokens{end+1} = struct('type', 'number', 'value', 0); %#ok<AGROW>
                        tokens{end+1} = struct('type', 'operator', 'value', '-'); %#ok<AGROW>
                        prevType = 'operator';
                    elseif ch == '+' && any(strcmp(prevType, {'start','lparen','operator'}))
                        % Unary plus → skip
                        prevType = 'operator';
                    else
                        tokens{end+1} = struct('type', 'operator', 'value', ch); %#ok<AGROW>
                        prevType = 'operator';
                    end
                    pos = pos + 1;
                    continue;
                end

                error('dataWorkspace:FormulaEngine:badChar', ...
                    'Unexpected character "%s" at position %d in formula: %s', ...
                    ch, pos, expression);
            end

            if isempty(tokens)
                error('dataWorkspace:FormulaEngine:emptyFormula', ...
                    'Formula produces no tokens: %s', expression);
            end
        end

        function rpn = toRPN(tokens)
        %TORPHM  Convert infix token list to reverse Polish notation (RPN).
        %
        %   rpn = dataWorkspace.FormulaEngine.toRPN(tokens)
        %
        %   Uses the shunting-yard algorithm.
        %   Operator precedence: ^ (3) > */ (2) > +- (1)
        %   ^ is right-associative; all others are left-associative.
            rpn     = {};
            opStack = {};

            for ti = 1:numel(tokens)
                tok = tokens{ti};
                switch tok.type
                    case {'number', 'column'}
                        rpn{end+1} = tok;           %#ok<AGROW>

                    case 'function'
                        opStack{end+1} = tok;        %#ok<AGROW>

                    case 'operator'
                        while ~isempty(opStack) && ...
                              strcmp(opStack{end}.type, 'operator') && ...
                              dataWorkspace.FormulaEngine.shouldPop(opStack{end}.value, tok.value)
                            rpn{end+1} = opStack{end}; %#ok<AGROW>
                            opStack(end) = [];
                        end
                        opStack{end+1} = tok;        %#ok<AGROW>

                    case 'lparen'
                        opStack{end+1} = tok;        %#ok<AGROW>

                    case 'rparen'
                        while ~isempty(opStack) && ...
                              ~strcmp(opStack{end}.type, 'lparen')
                            rpn{end+1} = opStack{end}; %#ok<AGROW>
                            opStack(end) = [];
                        end
                        if isempty(opStack)
                            error('dataWorkspace:FormulaEngine:parenMismatch', ...
                                'Mismatched parentheses in formula.');
                        end
                        opStack(end) = [];  % discard '('
                        % Pop function if sitting below the paren
                        if ~isempty(opStack) && strcmp(opStack{end}.type, 'function')
                            rpn{end+1} = opStack{end}; %#ok<AGROW>
                            opStack(end) = [];
                        end
                end
            end

            % Drain remaining operators
            while ~isempty(opStack)
                if strcmp(opStack{end}.type, 'lparen')
                    error('dataWorkspace:FormulaEngine:parenMismatch', ...
                        'Mismatched parentheses in formula.');
                end
                rpn{end+1} = opStack{end}; %#ok<AGROW>
                opStack(end) = [];
            end
        end

        function result = evalRPN(rpn, dataStruct)
        %EVALRPN  Evaluate an RPN token list against a data struct.
        %
        %   result = dataWorkspace.FormulaEngine.evalRPN(rpn, dataStruct)
        %
        %   Column tokens are resolved to vectors from dataStruct.
        %   All arithmetic is element-wise.  Result is [Nx1] double.
            arguments
                rpn        (1,:) cell
                dataStruct (1,1) struct
            end

            if isempty(rpn)
                error('dataWorkspace:FormulaEngine:emptyRPN', ...
                    'RPN token list is empty — formula may be blank.');
            end

            fhMap = dataWorkspace.FormulaEngine.functionHandles();
            N     = numel(dataStruct.time);  % expected output length

            stack = cell(1, numel(rpn));
            top   = 0;

            for k = 1:numel(rpn)
                tok = rpn{k};
                switch tok.type
                    case 'number'
                        top = top + 1;
                        stack{top} = tok.value;   % scalar; broadcasts in ops

                    case 'column'
                        top = top + 1;
                        stack{top} = dataWorkspace.FormulaEngine.resolveColumn( ...
                            tok.value, dataStruct);

                    case 'operator'
                        if top < 2
                            error('dataWorkspace:FormulaEngine:stackUnderflow', ...
                                'Stack underflow evaluating operator "%s".', tok.value);
                        end
                        b = stack{top}; top = top - 1;
                        a = stack{top}; top = top - 1;
                        switch tok.value
                            case '+', r = a + b;
                            case '-', r = a - b;
                            case '*', r = a .* b;
                            case '/', r = a ./ b;
                            case '^', r = a .^ b;
                            otherwise
                                error('dataWorkspace:FormulaEngine:unknownOp', ...
                                    'Unknown operator "%s".', tok.value);
                        end
                        top = top + 1;
                        stack{top} = r;

                    case 'function'
                        if top < 1
                            error('dataWorkspace:FormulaEngine:stackUnderflow', ...
                                'Stack underflow calling function "%s".', tok.value);
                        end
                        a  = stack{top}; top = top - 1;
                        fh = fhMap(tok.value);
                        r  = fh(a);
                        % diff prepends NaN to maintain length
                        if numel(r) == N - 1
                            r = [NaN; r(:)];
                        end
                        top = top + 1;
                        stack{top} = r;

                    otherwise
                        error('dataWorkspace:FormulaEngine:unknownTokenType', ...
                            'Unknown token type "%s" in RPN.', tok.type);
                end
            end

            if top ~= 1
                error('dataWorkspace:FormulaEngine:unusedOperands', ...
                    'Formula has %d unconsumed operands — check for missing operators.', top);
            end

            result = stack{1};

            % Broadcast scalar to column vector
            if isscalar(result)
                result = repmat(result, N, 1);
            end

            result = result(:);   % ensure column vector

            if numel(result) ~= N
                error('dataWorkspace:FormulaEngine:dimensionMismatch', ...
                    'Formula result has %d rows but dataset has %d rows.', ...
                    numel(result), N);
            end
        end

        function tf = hasCircularRef(expression, dependsOn)
        %HASCIRCULARREF  Return true if expression references any column in dependsOn.
        %
        %   tf = dataWorkspace.FormulaEngine.hasCircularRef(expression, dependsOn)
        %
        %   Inputs:
        %     expression — formula string
        %     dependsOn  — cell array of column name strings to check against
        %
        %   Outputs:
        %     tf — logical scalar
            arguments
                expression (1,1) string
                dependsOn  (1,:) cell
            end

            if isempty(dependsOn)
                tf = false;
                return;
            end

            try
                tokens = dataWorkspace.FormulaEngine.tokenize(expression);
            catch
                tf = false;
                return;
            end

            for k = 1:numel(tokens)
                tok = tokens{k};
                if strcmp(tok.type, 'column') && ischar(tok.value)
                    if any(strcmp(tok.value, dependsOn))
                        tf = true;
                        return;
                    end
                end
            end
            tf = false;
        end

    end  % Static methods

    % ════════════════════════════════════════════════════════════════════════
    %  Private static helpers
    % ════════════════════════════════════════════════════════════════════════
    methods (Static, Access = private)

        function v = resolveColumn(nameOrIdx, dataStruct)
        %RESOLVECOLUMN  Resolve a column token value to a data vector.
        %
        %   nameOrIdx is either:
        %     0          → data.time (X axis)
        %     'X'        → data.time (X axis)
        %     <string>   → matched against data.labels (case-insensitive)
            if isnumeric(nameOrIdx)
                % Numeric 0 → time axis; other indices into values columns
                if nameOrIdx == 0
                    v = dataStruct.time(:);
                else
                    nCols = size(dataStruct.values, 2);
                    if nameOrIdx < 1 || nameOrIdx > nCols
                        error('dataWorkspace:FormulaEngine:columnIndex', ...
                            'Column index %d out of range (1..%d).', ...
                            nameOrIdx, nCols);
                    end
                    v = dataStruct.values(:, nameOrIdx);
                end
                return;
            end

            % String reference
            name = char(nameOrIdx);

            % '$X' or 'X' → time axis sentinel
            if strcmpi(name, 'X')
                v = dataStruct.time(:);
                return;
            end

            % Search labels (case-insensitive)
            labels = {};
            if isfield(dataStruct, 'labels') && ~isempty(dataStruct.labels)
                labels = dataStruct.labels;
            end

            idx = find(strcmpi(labels, name), 1);
            if isempty(idx)
                % Build a helpful list of available columns
                if isempty(labels)
                    avail = '(no columns)';
                else
                    avail = strjoin(labels, ', ');
                end
                error('dataWorkspace:FormulaEngine:unknownColumn', ...
                    'Unknown column "%s". Available columns: %s.', ...
                    name, avail);
            end
            v = dataStruct.values(:, idx);
        end

        function [tok, pos] = readColRef(expr, pos)
        %READCOLREF  Parse col("name") or col(0) starting just after 'col'.
        %   pos points at the '(' character.
            len = length(expr);
            % Expect '('
            if pos > len || expr(pos) ~= '('
                error('dataWorkspace:FormulaEngine:colRefSyntax', ...
                    'Expected "(" after "col" in formula.');
            end
            pos = pos + 1;  % skip '('

            % Skip whitespace
            while pos <= len && (expr(pos) == ' ' || expr(pos) == char(9))
                pos = pos + 1;
            end
            if pos > len
                error('dataWorkspace:FormulaEngine:colRefSyntax', ...
                    'Unterminated col() reference.');
            end

            ch = expr(pos);

            if ch == '"' || ch == ''''
                % String argument: col("name") or col('name')
                quote = ch;
                pos = pos + 1;
                nameStart = pos;
                while pos <= len && expr(pos) ~= quote
                    pos = pos + 1;
                end
                if pos > len
                    error('dataWorkspace:FormulaEngine:colRefSyntax', ...
                        'Unterminated string in col() reference.');
                end
                colName = expr(nameStart:pos-1);
                pos = pos + 1;  % skip closing quote
            elseif dataWorkspace.FormulaEngine.isDigit(ch)
                % Numeric argument: col(0), col(1), ...
                numStart = pos;
                while pos <= len && dataWorkspace.FormulaEngine.isDigit(expr(pos))
                    pos = pos + 1;
                end
                colName = str2double(expr(numStart:pos-1));
            else
                error('dataWorkspace:FormulaEngine:colRefSyntax', ...
                    'col() argument must be a quoted string or number.');
            end

            % Skip whitespace before ')'
            while pos <= len && (expr(pos) == ' ' || expr(pos) == char(9))
                pos = pos + 1;
            end
            if pos > len || expr(pos) ~= ')'
                error('dataWorkspace:FormulaEngine:colRefSyntax', ...
                    'Expected ")" to close col() reference.');
            end
            pos = pos + 1;  % skip ')'

            tok = struct('type', 'column', 'value', colName);
        end

        function [tok, pos] = readDollarRef(expr, pos)
        %READDOLLARREF  Parse $name shorthand starting after the '$'.
        %   $X → col(0), $name → col("name").
            len = length(expr);
            if pos > len || (~dataWorkspace.FormulaEngine.isLetter(expr(pos)) && expr(pos) ~= '_')
                error('dataWorkspace:FormulaEngine:dollarRefSyntax', ...
                    '"$" must be followed by an identifier.');
            end
            [name, pos] = dataWorkspace.FormulaEngine.readIdent(expr, pos);
            if strcmpi(name, 'X')
                tok = struct('type', 'column', 'value', 0);   % time axis
            else
                tok = struct('type', 'column', 'value', name);
            end
        end

        function [s, pos] = readNumber(str, pos)
        %READNUMBER  Read a numeric literal from str starting at pos.
            start = pos;
            len   = length(str);
            while pos <= len && (dataWorkspace.FormulaEngine.isDigit(str(pos)) || str(pos) == '.')
                pos = pos + 1;
            end
            % Optional exponent
            if pos <= len && (str(pos) == 'e' || str(pos) == 'E')
                pos = pos + 1;
                if pos <= len && (str(pos) == '+' || str(pos) == '-')
                    pos = pos + 1;
                end
                while pos <= len && dataWorkspace.FormulaEngine.isDigit(str(pos))
                    pos = pos + 1;
                end
            end
            s = str(start:pos-1);
        end

        function [s, pos] = readIdent(str, pos)
        %READIDENT  Read an identifier (letters, digits, underscore) from str.
            start = pos;
            len   = length(str);
            while pos <= len && dataWorkspace.FormulaEngine.isIdentChar(str(pos))
                pos = pos + 1;
            end
            s = str(start:pos-1);
        end

        function tf = isDigit(ch)
            tf = ch >= '0' && ch <= '9';
        end

        function tf = isLetter(ch)
            tf = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
        end

        function tf = isIdentChar(ch)
            tf = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ...
                 (ch >= '0' && ch <= '9') || ch == '_';
        end

        function tf = shouldPop(stackOp, newOp)
        %SHOULDPOP  True if stackOp should be popped before newOp is pushed.
            prec = containers.Map({'+','-','*','/','.'}, [1,1,2,2,2]);
            % Override: '^' has higher precedence than all, right-associative
            stackPrec = 0;
            newPrec   = 0;
            if prec.isKey(stackOp), stackPrec = prec(stackOp); end
            if prec.isKey(newOp),   newPrec   = prec(newOp);   end
            % Give '^' precedence 3
            if strcmp(stackOp, '^'), stackPrec = 3; end
            if strcmp(newOp,   '^'), newPrec   = 3; end

            if strcmp(newOp, '^')
                tf = stackPrec > newPrec;   % right-associative
            else
                tf = stackPrec >= newPrec;  % left-associative
            end
        end

        function names = supportedFunctions()
        %SUPPORTEDFUNCTIONS  Return the list of supported function name strings.
            names = {'sin','cos','tan','exp','log','log10','sqrt','abs', ...
                     'round','floor','ceil','diff','cumsum','cumtrapz'};
        end

        function fhMap = functionHandles()
        %FUNCTIONHANDLES  Return a containers.Map of name → function handle.
        %   All function handles are built-ins or anonymous wrappers — no
        %   eval, feval with dynamic strings, or str2func on user input.
            names = dataWorkspace.FormulaEngine.supportedFunctions();
            fhs = { ...
                @sin, @cos, @tan, @exp, @log, @log10, @sqrt, @abs, ...
                @round, @floor, @ceil, ...
                @(x) diff(x(:)),    ...  % diff: returns N-1 vector; evalRPN prepends NaN
                @(x) cumsum(x(:)),  ...
                @(x) cumtrapz(x(:)) ...
            };
            fhMap = containers.Map(names, fhs);
        end

    end  % private static methods

end  % classdef FormulaEngine
