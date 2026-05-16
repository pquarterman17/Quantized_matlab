function result = extractionInventory(filePath, startLine, endLine, opts)
% Analyze a line range for extraction: closure reads, writes, callbacks, widgets.
%
%   result = scripts.extractionInventory('BosonPlotter.m', 1808, 1969)
%   result = scripts.extractionInventory('FermiViewer.m', 500, 800, GenerateCode=true)
%
% Returns a struct with:
%   .closureReads   — variables read inside range but defined outside
%   .closureWrites  — variables assigned inside range and used outside
%   .callbackRefs   — @functionName handles referenced
%   .widgetCreates  — uibutton/uilabel/etc. creation calls
%   .widgetHandles  — variable names assigned from widget creation
%   .parentRefs     — layout/grid/panel references (likely function args)
%   .lineCount      — total lines in range
%   .codeLines      — non-blank, non-comment lines
%   .generatedCode  — (optional) skeleton build function + caller code

    arguments
        filePath   (1,1) string
        startLine  (1,1) double {mustBePositive, mustBeInteger}
        endLine    (1,1) double {mustBePositive, mustBeInteger}
        opts.GenerateCode (1,1) logical = false
        opts.FunctionName (1,1) string  = ""
        opts.Verbose      (1,1) logical = true
    end

    lines = readlines(filePath);
    totalLines = numel(lines);

    if endLine > totalLines
        error('extractionInventory:range', ...
            'endLine %d exceeds file length %d', endLine, totalLines);
    end

    block = lines(startLine:endLine);
    before = lines(1:startLine-1);
    after  = lines(endLine+1:end);
    outside = [before; after];

    blockText  = join(block, newline);
    outsideText = join(outside, newline);

    % ── Identify all assignments in the block ────────────────────────
    assignPat = '^\s*(\w+)\s*[=]';
    dotAssignPat = '^\s*(\w+)\.(\w+)\s*[=]';
    blockAssigns = extractTokens(block, assignPat);
    blockDotAssigns = extractDotTokens(block, dotAssignPat);

    % ── Identify all variable references in the block ────────────────
    blockVarRefs = extractAllIdentifiers(block);

    % ── Identify all assignments outside the block ───────────────────
    outsideAssigns = extractTokens(outside, assignPat);
    outsideVarRefs = extractAllIdentifiers(outside);

    % ── Closure reads: used in block, defined outside, not defined in block
    closureReads = setdiff(intersect(blockVarRefs, outsideAssigns), blockAssigns);
    closureReads = removeMatlabBuiltins(closureReads);

    % ── Closure writes: defined in block, used outside
    closureWrites = intersect(blockAssigns, outsideVarRefs);
    closureWrites = removeMatlabBuiltins(closureWrites);

    % ── Callback references (@functionName)
    cbPat = '@(\w+)';
    callbackRefs = unique(regexp(blockText, cbPat, 'tokens'));
    callbackRefs = cellfun(@(c) c{1}, callbackRefs, 'UniformOutput', false);
    callbackRefs = callbackRefs(~startsWith(callbackRefs, '('));

    % ── Widget creation calls
    widgetTypes = {'uifigure','uigridlayout','uipanel','uitab','uitabgroup', ...
        'uibutton','uilabel','uidropdown','uieditfield','uicheckbox', ...
        'uitextarea','uislider','uiknob','uiswitch','uilistbox', ...
        'uitable','uispreadsheet','uiimage','uitree','uitreenode', ...
        'uimenu','uicontextmenu','uihtml','uilamp','uigauge', ...
        'uispinner','uiprogressdlg','uihyperlink'};
    widgetPat = sprintf('(%s)\\s*\\(', strjoin(widgetTypes, '|'));
    widgetCreates = unique(regexp(blockText, widgetPat, 'tokens'));
    widgetCreates = cellfun(@(c) c{1}, widgetCreates, 'UniformOutput', false);

    % Widget handles — variables assigned from widget creation
    widgetHandles = {};
    for i = 1:numel(block)
        ln = block(i);
        for w = 1:numel(widgetTypes)
            wt = widgetTypes{w};
            pat = sprintf('^\\s*(\\w+)\\s*=\\s*%s\\(', wt);
            tok = regexp(ln, pat, 'tokens');
            if ~isempty(tok)
                widgetHandles{end+1} = tok{1}{1}; %#ok<AGROW>
            end
        end
    end
    widgetHandles = unique(widgetHandles);

    % ── Parent refs (grid/layout/panel vars used as first arg to widget creation)
    parentPat = sprintf('(?:%s)\\s*\\(\\s*(\\w+)', strjoin(widgetTypes, '|'));
    parentRefs = unique(regexp(blockText, parentPat, 'tokens'));
    parentRefs = cellfun(@(c) c{1}, parentRefs, 'UniformOutput', false);

    % ── Dot-property assignments (ui.xxx = ..., appData.xxx = ...)
    dotWrites = {};
    for i = 1:numel(blockDotAssigns)
        da = blockDotAssigns{i};
        dotWrites{end+1} = sprintf('%s.%s', da{1}, da{2}); %#ok<AGROW>
    end
    dotWrites = unique(dotWrites);

    % ── Code metrics
    codeLines = 0;
    for i = 1:numel(block)
        ln = strtrim(block(i));
        if strlength(ln) > 0 && ~startsWith(ln, '%')
            codeLines = codeLines + 1;
        end
    end

    % ── Build result ─────────────────────────────────────────────────
    result.closureReads   = sort(closureReads(:));
    result.closureWrites  = sort(closureWrites(:));
    result.callbackRefs   = sort(callbackRefs(:));
    result.widgetCreates  = sort(widgetCreates(:));
    result.widgetHandles  = sort(widgetHandles(:));
    result.parentRefs     = sort(parentRefs(:));
    result.dotWrites      = sort(dotWrites(:));
    result.lineCount      = endLine - startLine + 1;
    result.codeLines      = codeLines;

    % ── Code generation ──────────────────────────────────────────────
    if opts.GenerateCode
        if opts.FunctionName == ""
            opts.FunctionName = "buildExtracted";
        end
        result.generatedCode = generateSkeleton(result, opts.FunctionName, block);
    end

    % ── Display ──────────────────────────────────────────────────────
    if opts.Verbose
        printReport(result, filePath, startLine, endLine, opts);
    end
end


function tokens = extractTokens(lines, pat)
    tokens = {};
    for i = 1:numel(lines)
        ln = lines(i);
        if startsWith(strtrim(ln), '%'), continue; end
        tok = regexp(ln, pat, 'tokens');
        for j = 1:numel(tok)
            tokens{end+1} = tok{j}{1}; %#ok<AGROW>
        end
    end
    tokens = unique(tokens);
end


function tokens = extractDotTokens(lines, pat)
    tokens = {};
    for i = 1:numel(lines)
        ln = lines(i);
        if startsWith(strtrim(ln), '%'), continue; end
        tok = regexp(ln, pat, 'tokens');
        for j = 1:numel(tok)
            tokens{end+1} = tok{j}; %#ok<AGROW>
        end
    end
end


function ids = extractAllIdentifiers(lines)
    text = join(lines, newline);
    % Remove comments
    text = regexprep(text, '%[^\n]*', '');
    % Remove string literals
    text = regexprep(text, '''[^'']*''', '');
    text = regexprep(text, '"[^"]*"', '');
    % Extract identifiers
    raw = unique(regexp(text, '\b([a-zA-Z]\w*)\b', 'tokens'));
    ids = cellfun(@(c) c{1}, raw, 'UniformOutput', false);
end


function ids = removeMatlabBuiltins(ids)
    builtins = {'true','false','end','if','else','elseif','for','while', ...
        'switch','case','otherwise','try','catch','function','return', ...
        'break','continue','struct','cell','zeros','ones','nan','inf', ...
        'numel','length','size','isempty','strcmp','strcmpi','contains', ...
        'startsWith','endsWith','sprintf','fprintf','warning','error', ...
        'disp','get','set','findobj','delete','close','figure','axes', ...
        'plot','hold','title','xlabel','ylabel','legend','grid', ...
        'cellfun','arrayfun','fieldnames','isfield','rmfield', ...
        'fullfile','exist','char','string','double','single','int32', ...
        'uint8','logical','isa','class','isnumeric','ischar','isstring', ...
        'islogical','isstruct','iscell','reshape','repmat','cat','horzcat', ...
        'vertcat','sort','unique','intersect','setdiff','union','find', ...
        'min','max','sum','mean','median','std','abs','round','floor', ...
        'ceil','mod','rem','sqrt','log','log10','exp','pi','eps', ...
        'strtrim','strip','split','join','replace','strrep','regexprep', ...
        'regexp','regexpi','num2str','str2double','str2num', ...
        'varargin','nargin','nargout','mfilename','persistent'};
    ids = setdiff(ids, builtins);
end


function code = generateSkeleton(result, fnName, block)
    % Generate the build function file content + caller-side replacement

    % Determine args: parent + tk + callbacks
    parentArg = 'parent';
    if ~isempty(result.parentRefs)
        parentArg = result.parentRefs{1};
    end

    % Separate closure reads into: layout parents, tokens/colors, callbacks
    reads = result.closureReads;
    cbs = result.callbackRefs;

    % Build function signature
    returnFields = [result.widgetHandles(:); result.closureWrites(:)];
    returnFields = unique(returnFields);

    lines = {};
    lines{end+1} = sprintf('function s = %s(parent, tk, palette, callbacks)', fnName);
    lines{end+1} = sprintf('%% %s  Build extracted UI block.', upper(fnName));
    lines{end+1} = '';
    lines{end+1} = '    % ── Unpack callbacks ──';
    for i = 1:numel(cbs)
        lines{end+1} = sprintf('    %% cb: @%s', cbs{i});
    end
    lines{end+1} = '';
    lines{end+1} = '    % ── Closure reads (need as args or in callbacks struct) ──';
    for i = 1:numel(reads)
        lines{end+1} = sprintf('    %% read: %s', reads{i});
    end
    lines{end+1} = '';
    lines{end+1} = '    % ══════ EXTRACTED CODE — paste and adapt ══════';
    for i = 1:numel(block)
        lines{end+1} = sprintf('    %s', block(i));
    end
    lines{end+1} = '';
    lines{end+1} = '    % ── Return struct ──';
    lines{end+1} = '    s = struct( ...';
    for i = 1:numel(returnFields)
        sep = ', ...';
        if i == numel(returnFields), sep = ''; end
        lines{end+1} = sprintf('        ''%s'', %s%s', ...
            returnFields{i}, returnFields{i}, sep);
    end
    lines{end+1} = '    );';
    lines{end+1} = 'end';

    skeleton = strjoin(lines, newline);

    % Generate caller-side replacement
    callerLines = {};
    callerLines{end+1} = '';
    callerLines{end+1} = '    % ── Caller-side replacement ──';
    callerLines{end+1} = sprintf('    %sCb_ = struct( ...', lower(extractAfter(fnName, 'build')));
    for i = 1:numel(cbs)
        sep = ', ...';
        if i == numel(cbs), sep = ''; end
        callerLines{end+1} = sprintf('        ''%s'', @%s%s', cbs{i}, cbs{i}, sep);
    end
    callerLines{end+1} = '    );';
    callerLines{end+1} = sprintf('    %sUI_ = bosonPlotter.%s(parent, tk, palette, %sCb_);', ...
        lower(extractAfter(fnName, 'build')), fnName, lower(extractAfter(fnName, 'build')));
    for i = 1:numel(returnFields)
        callerLines{end+1} = sprintf('    %s = %sUI_.%s;', ...
            returnFields{i}, lower(extractAfter(fnName, 'build')), returnFields{i});
    end
    caller = strjoin(callerLines, newline);

    code.skeleton = skeleton;
    code.caller = caller;
    code.returnFields = returnFields;
end


function printReport(result, filePath, startLine, endLine, opts)
    fprintf('\n');
    fprintf('═══════════════════════════════════════════════════════\n');
    fprintf('  EXTRACTION INVENTORY: %s [%d–%d]\n', filePath, startLine, endLine);
    fprintf('═══════════════════════════════════════════════════════\n');
    fprintf('  Lines: %d total, %d code (non-blank/non-comment)\n', ...
        result.lineCount, result.codeLines);
    fprintf('\n');

    printSection('CLOSURE READS (defined outside, used inside)', result.closureReads);
    printSection('CLOSURE WRITES (defined inside, used outside)', result.closureWrites);
    printSection('CALLBACK REFS (@handles)', result.callbackRefs);
    printSection('WIDGET CREATIONS', result.widgetCreates);
    printSection('WIDGET HANDLES (assigned)', result.widgetHandles);
    printSection('PARENT REFS (layout containers)', result.parentRefs);
    printSection('DOT-PROPERTY WRITES (obj.field = ...)', result.dotWrites);

    fprintf('───────────────────────────────────────────────────────\n');
    fprintf('  Summary: %d closure reads, %d closure writes,\n', ...
        numel(result.closureReads), numel(result.closureWrites));
    fprintf('           %d callbacks, %d widgets created\n', ...
        numel(result.callbackRefs), numel(result.widgetCreates));
    fprintf('───────────────────────────────────────────────────────\n');

    if opts.GenerateCode
        fprintf('\n  ★ Generated code written to result.generatedCode\n');
        fprintf('    .skeleton — paste into +bosonPlotter/%s.m\n', opts.FunctionName);
        fprintf('    .caller   — paste into BosonPlotter.m (replacing lines %d–%d)\n', ...
            startLine, endLine);
    end
    fprintf('\n');
end


function printSection(title, items)
    fprintf('  ┌─ %s (%d)\n', title, numel(items));
    if isempty(items)
        fprintf('  │  (none)\n');
    else
        for i = 1:numel(items)
            fprintf('  │  %s\n', items{i});
        end
    end
    fprintf('  └\n');
end
