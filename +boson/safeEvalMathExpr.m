function result = safeEvalMathExpr(expr, vars)
%SAFEEVALMATHEXPR  Evaluate a dataset-math expression without eval().
%
%   result = boson.safeEvalMathExpr('D1 - D2', vars)
%
%   Inputs:
%     expr — char expression such as 'D1 - D2', 'log10(D1)', 'abs(D1-D2)/D3'
%     vars — struct whose fields are dataset vectors, e.g. vars.D1, vars.D2
%
%   Supported constructs:
%     Unary functions : log10 log abs diff sqrt exp sin cos tan
%                       real imag cumsum cumtrapz gradient
%     Binary operators: + - * / .^  (standard precedence)
%     Grouping        : parentheses (arbitrary nesting)
%     Operands        : dataset refs (D1, D2, …) and numeric literals

% ── dispatch table ──────────────────────────────────────────────────
funcMap = containers.Map( ...
    {'log10','log','abs','diff','sqrt','exp', ...
     'sin','cos','tan','real','imag','cumsum','cumtrapz','gradient'}, ...
    {@log10, @log, @abs, @diff, @sqrt, @exp, ...
     @sin, @cos, @tan, @real, @imag, @cumsum, @cumtrapz, @gradient});

tokens = tokenise(expr);
pos = 1;
result = parseExpr();
if pos <= numel(tokens)
    error('Unexpected token ''%s'' in expression.', tokens{pos});
end

% ─────────────────────────────────────────────────────────────────────
%  Nested parsing functions (share pos, tokens, vars, funcMap via closure)
% ─────────────────────────────────────────────────────────────────────

    function toks = tokenise(s)
        s = strtrim(s);
        toks = {};
        i = 1;
        while i <= numel(s)
            c = s(i);
            if c == ' ' || c == 9
                i = i + 1;
            elseif any(c == '()+-*/')
                toks{end+1} = c; i = i + 1; %#ok<AGROW>
            elseif c == '.' && i < numel(s) && s(i+1) == '^'
                toks{end+1} = '.^'; i = i + 2; %#ok<AGROW>
            elseif c == '^'
                toks{end+1} = '.^'; i = i + 1; %#ok<AGROW>
            elseif c == 'D' && i < numel(s) && s(i+1) >= '0' && s(i+1) <= '9'
                j = i + 1;
                while j <= numel(s) && s(j) >= '0' && s(j) <= '9', j = j+1; end
                toks{end+1} = s(i:j-1); i = j; %#ok<AGROW>
            elseif (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
                j = i;
                while j <= numel(s) && ((s(j)>='a'&&s(j)<='z')||(s(j)>='A'&&s(j)<='Z')||(s(j)>='0'&&s(j)<='9'))
                    j = j+1;
                end
                toks{end+1} = s(i:j-1); i = j; %#ok<AGROW>
            elseif (c >= '0' && c <= '9') || c == '.'
                j = i;
                while j <= numel(s) && (s(j)>='0'&&s(j)<='9'||s(j)=='.'), j=j+1; end
                if j <= numel(s) && (s(j)=='e'||s(j)=='E')
                    j = j+1;
                    if j <= numel(s) && (s(j)=='+'||s(j)=='-'), j=j+1; end
                    while j <= numel(s) && s(j)>='0'&&s(j)<='9', j=j+1; end
                end
                toks{end+1} = s(i:j-1); i = j; %#ok<AGROW>
            else
                error('Unrecognised character ''%s'' in expression.', c);
            end
        end
    end

    function val = parseExpr()
        val = parseTerm();
        while pos <= numel(tokens) && (strcmp(tokens{pos},'+')||strcmp(tokens{pos},'-'))
            op = tokens{pos}; pos = pos+1;
            rhs = parseTerm();
            if op=='+', val=val+rhs; else, val=val-rhs; end
        end
    end

    function val = parseTerm()
        val = parsePower();
        while pos <= numel(tokens) && (strcmp(tokens{pos},'*')||strcmp(tokens{pos},'/'))
            op = tokens{pos}; pos = pos+1;
            rhs = parsePower();
            if op=='*', val=val.*rhs; else, val=val./rhs; end
        end
    end

    function val = parsePower()
        val = parseUnary();
        if pos <= numel(tokens) && strcmp(tokens{pos},'.^')
            pos = pos+1; val = val .^ parseUnary();
        end
    end

    function val = parseUnary()
        if pos <= numel(tokens) && strcmp(tokens{pos},'-')
            pos = pos+1; val = -parsePrimary();
        else
            val = parsePrimary();
        end
    end

    function val = parsePrimary()
        if pos > numel(tokens), error('Unexpected end of expression.'); end
        tok = tokens{pos};
        if strcmp(tok,'(')
            pos = pos+1; val = parseExpr();
            if pos > numel(tokens)||~strcmp(tokens{pos},')'), error('Missing closing parenthesis.'); end
            pos = pos+1; return
        end
        if isKey(funcMap, tok)
            pos = pos+1;
            if pos > numel(tokens)||~strcmp(tokens{pos},'('), error('Expected ''('' after ''%s''.', tok); end
            pos = pos+1; arg = parseExpr();
            if pos > numel(tokens)||~strcmp(tokens{pos},')'), error('Missing '')'' after ''%s(...''.', tok); end
            pos = pos+1; val = funcMap(tok); val = val(arg); return
        end
        if ~isempty(regexp(tok, '^D\d+$', 'once'))
            if ~isfield(vars, tok), error('Dataset ''%s'' not found.', tok); end
            val = vars.(tok); pos = pos+1; return
        end
        numVal = str2double(tok);
        if ~isnan(numVal), val = numVal; pos = pos+1; return; end
        error('Unrecognised token ''%s''.', tok);
    end

end
