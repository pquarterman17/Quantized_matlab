function plan = extractionPlan(filePath, opts)
% Scan a MATLAB file for extractable UI-construction blocks and rank them.
%
%   plan = scripts.extractionPlan('BosonPlotter.m')
%   plan = scripts.extractionPlan('FermiViewer.m', MinLines=30)
%
% Finds contiguous regions of widget creation, groups them by parent
% layout container, and ranks by line count (biggest wins first).
% Each candidate includes an extractionInventory result.

    arguments
        filePath (1,1) string
        opts.MinLines (1,1) double = 20
        opts.MaxCandidates (1,1) double = 20
        opts.Verbose (1,1) logical = true
    end

    lines = readlines(filePath);
    n = numel(lines);

    widgetTypes = {'uifigure','uigridlayout','uipanel','uitab','uitabgroup', ...
        'uibutton','uilabel','uidropdown','uieditfield','uicheckbox', ...
        'uitextarea','uislider','uiknob','uiswitch','uilistbox', ...
        'uitable','uispreadsheet','uiimage','uitree','uitreenode', ...
        'uimenu','uicontextmenu','uihtml','uilamp','uigauge', ...
        'uispinner','uihyperlink'};
    widgetPat = sprintf('\\b(%s)\\s*\\(', strjoin(widgetTypes, '|'));

    % ── Find all widget creation lines ───────────────────────────────
    isWidget = false(n, 1);
    parentVar = strings(n, 1);
    parentArgPat = sprintf('(?:%s)\\s*\\(\\s*(\\w+)', strjoin(widgetTypes, '|'));

    for i = 1:n
        ln = lines(i);
        if startsWith(strtrim(ln), '%'), continue; end
        if ~isempty(regexp(ln, widgetPat, 'once'))
            isWidget(i) = true;
            tok = regexp(ln, parentArgPat, 'tokens', 'once');
            if ~isempty(tok)
                parentVar(i) = tok{1};
            end
        end
    end

    % ── Expand widget lines to include their property continuations ──
    isBlock = false(n, 1);
    for i = 1:n
        if isWidget(i)
            isBlock(i) = true;
            % Walk backward for assignment line
            if i > 1 && ~isWidget(i-1)
                prev = strtrim(lines(i-1));
                if endsWith(prev, '...')
                    isBlock(i-1) = true;
                end
            end
            % Walk forward for continuation lines
            j = i;
            while j <= n && endsWith(strtrim(lines(j)), '...')
                isBlock(j) = true;
                j = j + 1;
            end
            if j <= n
                isBlock(j) = true;
            end
        end
    end

    % Also include adjacent property-setting lines (set(handle,...) or
    % handle.Property = value) within 3 lines of a widget creation
    for i = 1:n
        if isWidget(i)
            for j = max(1,i-1):min(n,i+5)
                ln = strtrim(lines(j));
                if contains(ln, '.ButtonPushedFcn') || ...
                   contains(ln, '.ValueChangedFcn') || ...
                   contains(ln, '.MenuSelectedFcn') || ...
                   contains(ln, '.CellEditCallback') || ...
                   contains(ln, '.CellSelectionCallback') || ...
                   contains(ln, '.Layout.Row') || ...
                   contains(ln, '.Layout.Column') || ...
                   contains(ln, '.Tooltip') || ...
                   contains(ln, '.Tag')
                    isBlock(j) = true;
                end
            end
        end
    end

    % ── Group into contiguous runs (with small gaps) ─────────────────
    % Merge blocks separated by <= 3 non-block lines
    blockStarts = [];
    blockEnds   = [];
    inBlock = false;
    gapCount = 0;
    maxGap = 5;

    for i = 1:n
        if isBlock(i)
            if ~inBlock
                blockStarts(end+1) = i; %#ok<AGROW>
                inBlock = true;
            end
            gapCount = 0;
        else
            if inBlock
                gapCount = gapCount + 1;
                if gapCount > maxGap
                    blockEnds(end+1) = i - gapCount; %#ok<AGROW>
                    inBlock = false;
                    gapCount = 0;
                end
            end
        end
    end
    if inBlock
        blockEnds(end+1) = n; %#ok<AGROW>
    end

    % ── Filter by minimum size and rank ──────────────────────────────
    candidates = struct('startLine', {}, 'endLine', {}, 'lineCount', {}, ...
        'parentVar', {}, 'widgetCount', {}, 'inventory', {});

    for k = 1:numel(blockStarts)
        s = blockStarts(k);
        e = blockEnds(k);
        lc = e - s + 1;
        if lc < opts.MinLines, continue; end

        % Dominant parent in this block
        parents = parentVar(s:e);
        parents = parents(parents ~= "");
        if isempty(parents)
            dominant = "(unknown)";
        else
            [~, ~, ic] = unique(parents);
            counts = accumarray(ic, 1);
            [~, mi] = max(counts);
            uparents = unique(parents);
            dominant = uparents(mi);
        end

        wc = sum(isWidget(s:e));

        inv = scripts.extractionInventory(filePath, s, e, Verbose=false);

        cand.startLine   = s;
        cand.endLine     = e;
        cand.lineCount   = lc;
        cand.parentVar   = dominant;
        cand.widgetCount = wc;
        cand.inventory   = inv;
        candidates(end+1) = cand; %#ok<AGROW>
    end

    % Sort by line count descending
    [~, idx] = sort([candidates.lineCount], 'descend');
    candidates = candidates(idx);
    if numel(candidates) > opts.MaxCandidates
        candidates = candidates(1:opts.MaxCandidates);
    end

    plan = candidates;

    % ── Display ──────────────────────────────────────────────────────
    if opts.Verbose && ~isempty(plan)
        fprintf('\n');
        fprintf('═══════════════════════════════════════════════════════════\n');
        fprintf('  EXTRACTION PLAN: %s\n', filePath);
        fprintf('  Found %d extractable blocks (>= %d lines)\n', ...
            numel(plan), opts.MinLines);
        fprintf('═══════════════════════════════════════════════════════════\n');
        totalSavings = 0;
        for k = 1:numel(plan)
            c = plan(k);
            fprintf('  %2d. Lines %5d–%5d  (%3d lines, %2d widgets)  parent: %s\n', ...
                k, c.startLine, c.endLine, c.lineCount, c.widgetCount, c.parentVar);
            fprintf('      Closure: %d reads, %d writes, %d callbacks\n', ...
                numel(c.inventory.closureReads), numel(c.inventory.closureWrites), ...
                numel(c.inventory.callbackRefs));
            totalSavings = totalSavings + c.lineCount;
        end
        fprintf('───────────────────────────────────────────────────────────\n');
        fprintf('  Total extractable: ~%d lines\n', totalSavings);
        fprintf('═══════════════════════════════════════════════════════════\n\n');
    end
end
