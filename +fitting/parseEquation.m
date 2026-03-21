function [fcn, paramNames] = parseEquation(eqnStr)
%PARSEEQUATION  Safely parse a user equation string into a function handle.
%
%   [fcn, paramNames] = fitting.parseEquation('A*exp(-x/tau) + C')
%
%   Parses a mathematical expression into a function handle f(x, p) and
%   a cell array of parameter names.  Does NOT use eval(), str2func(), or
%   feval() with dynamic strings.  Instead it tokenizes the expression,
%   converts to reverse-Polish notation (RPN), and builds a stack-machine
%   evaluator.
%
%   Supported syntax:
%       Variables:  x (independent variable), any letter/word = parameter
%       Operators:  + - * / ^  (standard precedence)
%       Grouping:   ( )
%       Functions:  exp log log10 sqrt abs sin cos tan asin acos atan
%                   sinh cosh tanh coth erf erfc sign floor ceil round
%       Constants:  pi, e (Euler's number), numbers (1.5, 3e-4, .7)
%       Unary minus: -x, -(A+B), -sin(x)
%
%   Output:
%       fcn        — function handle @(x, p) → y (element-wise, column vector)
%       paramNames — cell array of parameter name strings in order they appear
%
%   Example:
%       [f, names] = fitting.parseEquation('A*exp(-x/tau) + C');
%       % names = {'A', 'tau', 'C'}
%       % f(xdata, [1.5 200 0.1]) evaluates the expression

arguments
    eqnStr (1,1) string
end

eqnStr = char(strtrim(eqnStr));

% Strip leading "y =" or "y=" or "f(x) ="
eqnStr = regexprep(eqnStr, '^\s*(y|f\(x\))\s*=\s*', '');

if isempty(eqnStr)
    error('fitting:parseEquation:empty', 'Equation string is empty.');
end

% ════════════════════════════════════════════════════════════════════════
% Allowed functions and constants
% ════════════════════════════════════════════════════════════════════════

funcNames = {'exp','log','log10','sqrt','abs','sin','cos','tan', ...
    'asin','acos','atan','sinh','cosh','tanh','coth','erf','erfc', ...
    'sign','floor','ceil','round'};
funcHandles = containers.Map(funcNames, ...
    {@exp, @log, @log10, @sqrt, @abs, @sin, @cos, @tan, ...
     @asin, @acos, @atan, @sinh, @cosh, @tanh, @coth, @erf, @erfc, ...
     @sign, @floor, @ceil, @round});

constNames = {'pi', 'e'};
constValues = containers.Map(constNames, {pi, exp(1)});

% ════════════════════════════════════════════════════════════════════════
% Tokenize
% ════════════════════════════════════════════════════════════════════════

tokens = {};
paramSet = {};    % ordered unique parameter names
pos = 1;
len = length(eqnStr);
prevType = 'start';  % track for unary minus detection

while pos <= len
    ch = eqnStr(pos);

    % Skip whitespace
    if ch == ' ' || ch == char(9)
        pos = pos + 1;
        continue;
    end

    % Number literal: 123, 1.5, .7, 3e-4, 2.1E+3
    if isDigit(ch) || (ch == '.' && pos < len && isDigit(eqnStr(pos+1)))
        [numStr, pos] = readNumber(eqnStr, pos);
        tokens{end+1} = struct('type', 'number', 'value', str2double(numStr)); %#ok<AGROW>
        prevType = 'value';
        continue;
    end

    % Identifier: variable, function, or constant
    if isLetter(ch) || ch == '_'
        [name, pos] = readIdent(eqnStr, pos);

        if funcHandles.isKey(name)
            tokens{end+1} = struct('type', 'function', 'value', name); %#ok<AGROW>
            prevType = 'function';
        elseif constValues.isKey(name)
            tokens{end+1} = struct('type', 'number', 'value', constValues(name)); %#ok<AGROW>
            prevType = 'value';
        elseif strcmp(name, 'x')
            tokens{end+1} = struct('type', 'x', 'value', 'x'); %#ok<AGROW>
            prevType = 'value';
        else
            % It's a parameter
            pIdx = find(strcmp(paramSet, name), 1);
            if isempty(pIdx)
                paramSet{end+1} = name; %#ok<AGROW>
                pIdx = numel(paramSet);
            end
            tokens{end+1} = struct('type', 'param', 'value', pIdx); %#ok<AGROW>
            prevType = 'value';
        end
        continue;
    end

    % Operators and parentheses
    if any(ch == '+-*/^()')
        if ch == '('
            tokens{end+1} = struct('type', 'lparen', 'value', '('); %#ok<AGROW>
            prevType = 'lparen';
        elseif ch == ')'
            tokens{end+1} = struct('type', 'rparen', 'value', ')'); %#ok<AGROW>
            prevType = 'value';
        elseif ch == '-' && (strcmp(prevType, 'start') || strcmp(prevType, 'lparen') || strcmp(prevType, 'operator'))
            % Unary minus: insert 0 - ...
            tokens{end+1} = struct('type', 'number', 'value', 0); %#ok<AGROW>
            tokens{end+1} = struct('type', 'operator', 'value', '-'); %#ok<AGROW>
            prevType = 'operator';
        elseif ch == '+' && (strcmp(prevType, 'start') || strcmp(prevType, 'lparen') || strcmp(prevType, 'operator'))
            % Unary plus: skip
            % do nothing
            prevType = 'operator';
        else
            tokens{end+1} = struct('type', 'operator', 'value', ch); %#ok<AGROW>
            prevType = 'operator';
        end
        pos = pos + 1;
        continue;
    end

    error('fitting:parseEquation:badChar', ...
        'Unexpected character "%s" at position %d.', ch, pos);
end

paramNames = paramSet;

% ════════════════════════════════════════════════════════════════════════
% Shunting-yard → RPN
% ════════════════════════════════════════════════════════════════════════

rpn = {};
opStack = {};

for ti = 1:numel(tokens)
    tok = tokens{ti};
    switch tok.type
        case {'number', 'x', 'param'}
            rpn{end+1} = tok; %#ok<AGROW>

        case 'function'
            opStack{end+1} = tok; %#ok<AGROW>

        case 'operator'
            while ~isempty(opStack) && strcmp(opStack{end}.type, 'operator') && ...
                    shouldPop(opStack{end}.value, tok.value)
                rpn{end+1} = opStack{end}; %#ok<AGROW>
                opStack(end) = [];
            end
            opStack{end+1} = tok; %#ok<AGROW>

        case 'lparen'
            opStack{end+1} = tok; %#ok<AGROW>

        case 'rparen'
            while ~isempty(opStack) && ~strcmp(opStack{end}.type, 'lparen')
                rpn{end+1} = opStack{end}; %#ok<AGROW>
                opStack(end) = [];
            end
            if isempty(opStack)
                error('fitting:parseEquation:parenMismatch', 'Mismatched parentheses.');
            end
            opStack(end) = [];  % discard '('
            % If top of stack is a function, pop it
            if ~isempty(opStack) && strcmp(opStack{end}.type, 'function')
                rpn{end+1} = opStack{end}; %#ok<AGROW>
                opStack(end) = [];
            end
    end
end

while ~isempty(opStack)
    if strcmp(opStack{end}.type, 'lparen')
        error('fitting:parseEquation:parenMismatch', 'Mismatched parentheses.');
    end
    rpn{end+1} = opStack{end}; %#ok<AGROW>
    opStack(end) = [];
end

% ════════════════════════════════════════════════════════════════════════
% Build evaluator function handle (stack machine over the RPN list)
% ════════════════════════════════════════════════════════════════════════

% Capture rpn and funcHandles into the closure
rpnCopy = rpn;
fhMap = funcHandles;

fcn = @(x, p) evaluateRPN(rpnCopy, fhMap, x, p);

end

% ════════════════════════════════════════════════════════════════════════
% RPN stack-machine evaluator
% ════════════════════════════════════════════════════════════════════════

function y = evaluateRPN(rpn, fhMap, x, p)
    stack = cell(1, numel(rpn));
    top = 0;
    for k = 1:numel(rpn)
        tok = rpn{k};
        switch tok.type
            case 'number'
                top = top + 1;
                stack{top} = tok.value;    % scalar, will broadcast

            case 'x'
                top = top + 1;
                stack{top} = x;

            case 'param'
                top = top + 1;
                stack{top} = p(tok.value);

            case 'operator'
                b = stack{top}; top = top - 1;
                a = stack{top}; top = top - 1;
                switch tok.value
                    case '+', r = a + b;
                    case '-', r = a - b;
                    case '*', r = a .* b;
                    case '/', r = a ./ b;
                    case '^', r = a .^ b;
                end
                top = top + 1;
                stack{top} = r;

            case 'function'
                a = stack{top}; top = top - 1;
                fh = fhMap(tok.value);
                top = top + 1;
                stack{top} = fh(a);
        end
    end
    y = stack{1};
    % Ensure column vector output
    if isscalar(y)
        y = repmat(y, size(x));
    end
    y = y(:);
end

% ════════════════════════════════════════════════════════════════════════
% Tokenizer helpers
% ════════════════════════════════════════════════════════════════════════

function tf = isDigit(ch)
    tf = ch >= '0' && ch <= '9';
end

function tf = isLetter(ch)
    tf = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
end

function [s, pos] = readNumber(str, pos)
    start = pos;
    len = length(str);
    % Integer/decimal part
    while pos <= len && (isDigit(str(pos)) || str(pos) == '.')
        pos = pos + 1;
    end
    % Exponent part
    if pos <= len && (str(pos) == 'e' || str(pos) == 'E')
        pos = pos + 1;
        if pos <= len && (str(pos) == '+' || str(pos) == '-')
            pos = pos + 1;
        end
        while pos <= len && isDigit(str(pos))
            pos = pos + 1;
        end
    end
    s = str(start:pos-1);
end

function [s, pos] = readIdent(str, pos)
    start = pos;
    len = length(str);
    while pos <= len && (isLetter(str(pos)) || isDigit(str(pos)) || str(pos) == '_')
        pos = pos + 1;
    end
    s = str(start:pos-1);
end

% ════════════════════════════════════════════════════════════════════════
% Operator precedence for shunting-yard
% ════════════════════════════════════════════════════════════════════════

function tf = shouldPop(stackOp, newOp)
    prec = containers.Map({'+','-','*','/','^'}, {1,1,2,2,3});
    if ~prec.isKey(stackOp)
        tf = false;
        return;
    end
    sp = prec(stackOp);
    np = prec(newOp);
    if newOp == '^'
        tf = sp > np;       % right-associative: pop only if strictly higher
    else
        tf = sp >= np;      % left-associative: pop if equal or higher
    end
end
