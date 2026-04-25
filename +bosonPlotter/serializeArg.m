function s = serializeArg(value)
%SERIALIZEARG  Serialize a MATLAB value to its source-code literal form.
%   s = bosonPlotter.serializeArg(value)
%
%   Converts a value to a string that, when eval'd, reproduces it.
%   Used by `actionLog.recordCall` to build replayable command lines
%   without manual sprintf'ing.
%
%   Type handling:
%     char/string scalar  → 'value' (quoted; embedded ' doubled)
%     string array        → ["a", "b", ...]
%     numeric scalar      → num2str (full precision)
%     numeric vector/mat  → mat2str
%     logical scalar      → 'true' / 'false'
%     logical array       → bracketed
%     cell                → {<recursed>, <recursed>, ...}
%     function_handle     → @(...)... source via func2str
%     struct (scalar)     → struct('f1',v1,'f2',v2,...)
%     []                  → '[]'
%     {}                  → '{}'
%
%   Anything else falls back to `<unsupported:CLASS>` rather than erroring,
%   so a single weird arg won't break the whole replay.
%
%   Examples:
%     bosonPlotter.serializeArg(5)              % '5'
%     bosonPlotter.serializeArg('hi')           % '''hi'''
%     bosonPlotter.serializeArg([1 2 3])        % '[1 2 3]'
%     bosonPlotter.serializeArg({1, 'two'})     % '{1, ''two''}'

    if isempty(value) && ~ischar(value) && ~isstring(value)
        if iscell(value)
            s = '{}';
        elseif isstruct(value)
            s = 'struct()';
        else
            s = '[]';
        end
        return;
    end

    if ischar(value)
        s = ['''' strrep(value, '''', '''''') ''''];
        return;
    end

    if isstring(value)
        if isscalar(value)
            s = ['"' strrep(char(value), '"', '""') '"'];
        else
            parts = arrayfun(@(v) ['"' strrep(char(v), '"', '""') '"'], ...
                value(:).', 'UniformOutput', false);
            s = ['[' strjoin(parts, ', ') ']'];
        end
        return;
    end

    if islogical(value)
        if isscalar(value)
            if value, s = 'true'; else, s = 'false'; end
        else
            words = arrayfun(@(b) ternary(b,'true','false'), value(:).', ...
                'UniformOutput', false);
            s = ['[' strjoin(words, ' ') ']'];
        end
        return;
    end

    if isnumeric(value)
        if isscalar(value)
            s = num2str(value, '%.15g');
        else
            s = mat2str(value, 15);
        end
        return;
    end

    if iscell(value)
        parts = cellfun(@bosonPlotter.serializeArg, value(:).', ...
            'UniformOutput', false);
        s = ['{' strjoin(parts, ', ') '}'];
        return;
    end

    if isstruct(value) && isscalar(value)
        fns = fieldnames(value);
        parts = cell(1, 2*numel(fns));
        for k = 1:numel(fns)
            parts{2*k-1} = ['''' fns{k} ''''];
            parts{2*k}   = bosonPlotter.serializeArg(value.(fns{k}));
        end
        s = ['struct(' strjoin(parts, ', ') ')'];
        return;
    end

    if isa(value, 'function_handle')
        s = func2str(value);
        return;
    end

    s = sprintf('<unsupported:%s>', class(value));
end

function out = ternary(cond, ifTrue, ifFalse)
    if cond, out = ifTrue; else, out = ifFalse; end
end
