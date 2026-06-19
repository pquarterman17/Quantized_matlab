function out = legendBulkOps(op, labels, varargin)
%LEGENDBULKOPS  Pure bulk transforms for legend labels (no GUI — testable).
%
% Syntax
%   out = bosonPlotter.legendBulkOps('stripCommon', labels)
%   out = bosonPlotter.legendBulkOps('findReplace', labels, findStr, replStr)
%
% Inputs
%   op     - 'stripCommon' | 'findReplace'
%   labels - cellstr of legend labels
%   varargin - for 'findReplace': findStr, replStr
%
% Output
%   out - cellstr, same size as labels, transformed.  Rows that would become
%         empty (stripCommon) or are unchanged (findReplace no-op) are left
%         as the original label.

    labels = cellfun(@char, labels(:).', 'UniformOutput', false);
    switch lower(op)
        case 'stripcommon'
            out = stripCommon(labels);
        case 'findreplace'
            findStr = char(varargin{1});
            replStr = char(varargin{2});
            out = labels;
            if ~isempty(findStr)
                for i = 1:numel(labels)
                    out{i} = strrep(labels{i}, findStr, replStr);
                end
            end
        otherwise
            error('legendBulkOps:badOp', 'Unknown op: %s', op);
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function out = stripCommon(labels)
%STRIPCOMMON  Remove the shared prefix and suffix from every label.
    out = labels;
    [pfx, sfx] = commonAffix(labels);
    if isempty(pfx) && isempty(sfx), return; end
    for i = 1:numel(labels)
        s = labels{i};
        if isempty(s), continue; end
        mid = strtrim(s(numel(pfx)+1 : end-numel(sfx)));
        if ~isempty(mid)
            out{i} = mid;   % skip rows that would otherwise become empty
        end
    end
end

function [pfx, sfx] = commonAffix(strs)
%COMMONAFFIX  Longest common prefix and (non-overlapping) suffix of a cellstr.
    pfx = ''; sfx = '';
    strs = strs(~cellfun(@isempty, strs));
    if numel(strs) < 2, return; end

    % Longest common prefix
    p = strs{1};
    for i = 2:numel(strs)
        s = strs{i};
        m = min(numel(p), numel(s));
        j = find(p(1:m) ~= s(1:m), 1) - 1;
        if isempty(j), j = m; end
        p = p(1:j);
        if isempty(p), break; end
    end
    pfx = p;

    % Longest common suffix of the remainder after removing the prefix
    rem = cellfun(@(s) s(numel(pfx)+1:end), strs, 'UniformOutput', false);
    rem = rem(~cellfun(@isempty, rem));
    if numel(rem) < 2, return; end
    q = fliplr(rem{1});
    for i = 2:numel(rem)
        s = fliplr(rem{i});
        m = min(numel(q), numel(s));
        j = find(q(1:m) ~= s(1:m), 1) - 1;
        if isempty(j), j = m; end
        q = q(1:j);
        if isempty(q), break; end
    end
    sfx = fliplr(q);
end
