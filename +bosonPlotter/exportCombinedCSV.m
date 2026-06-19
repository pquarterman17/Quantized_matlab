function exportCombinedCSV(appData, selIdx, fp, fmt, wf)
%EXPORTCOMBINEDCSV  Write multiple datasets side-by-side into one CSV.
%
% Syntax
%   bosonPlotter.exportCombinedCSV(appData, selIdx, fp, fmt)
%   bosonPlotter.exportCombinedCSV(appData, selIdx, fp, fmt, wf)
%
% Each selected dataset contributes its own X column followed by its Y/value
% columns: 'X [tag], R [tag], dR [tag], X [tag2], ...'.
%
% Optional waterfall offset (wf) bakes the on-screen waterfall stacking into
% the written Y values so the CSV matches the plot.  Applied to signal and
% theory columns only — X and error columns (dR/err/std/sigma) are left raw,
% exactly like the on-screen waterfall (error bars ride along, the error
% magnitude is unchanged).
%
% Inputs
%   appData - AppState handle
%   selIdx  - vector of selected dataset indices (plot/export order)
%   fp      - output file path
%   fmt     - 'standard' | 'origin'
%   wf      - (optional) struct with fields:
%               .apply   logical — apply the offset (default false)
%               .levels  0-based level per selIdx element (waterfallOffsets)
%               .spacing waterfall spacing value
%               .logMode logical — multiplicative stacking (log Y)

    if nargin < 5 || isempty(wf) || ~isstruct(wf)
        wf = struct('apply', false, 'levels', [], 'spacing', 0, 'logMode', false);
    end
    applyWf = isfield(wf, 'apply') && wf.apply && isfield(wf, 'spacing') && wf.spacing ~= 0;

    allHdrs = {};
    allCols = {};
    maxRows = 0;
    for k = 1:numel(selIdx)
        di = selIdx(k);
        ds = appData.datasets{di};
        hasCorrected = ~isempty(ds.corrData);
        d = guiTernary(hasCorrected, ds.corrData, ds.data);
        d = bosonPlotter.applyDisplayUnits(d, ds, appData);
        [~, fn, fext] = fileparts(ds.filepath);
        tag = [fn fext];
        if isfield(ds, 'legendName') && ~isempty(ds.legendName)
            tag = ds.legendName;   % isfield-guarded: guiTernary would eval both args
        end

        % Waterfall level for this dataset (0-based)
        lvl = 0;
        if applyWf && k <= numel(wf.levels), lvl = wf.levels(k); end

        xName = 'X';
        if isfield(d, 'metadata') && isfield(d.metadata, 'xName')
            xName = d.metadata.xName;
        end
        allHdrs{end+1} = sprintf('%s [%s]', xName, tag); %#ok<AGROW>
        allCols{end+1} = d.time(:); %#ok<AGROW>

        for ci = 1:numel(d.labels)
            lbl  = d.labels{ci};
            yCol = d.values(:, ci);
            % Bake in the waterfall offset for signal/theory columns only.
            if applyWf && lvl ~= 0 && ~isErrorLabel(lbl)
                if wf.logMode
                    yCol = yCol * (wf.spacing ^ lvl);
                else
                    yCol = yCol + lvl * wf.spacing;
                end
            end
            if ~isempty(d.units{ci})
                lbl = sprintf('%s (%s)', lbl, d.units{ci});
            end
            allHdrs{end+1} = sprintf('%s [%s]', lbl, tag); %#ok<AGROW>
            allCols{end+1} = yCol; %#ok<AGROW>
        end
        maxRows = max(maxRows, numel(d.time));
    end

    dirPart = fileparts(fp);
    if ~isempty(dirPart) && ~isfolder(dirPart)
        error('exportCombinedCSV:badDir', 'Output directory does not exist:\n%s', dirPart);
    end
    fid = fopen(fp, 'w');
    if fid < 0
        error('exportCombinedCSV:cannotOpen', 'Cannot open file for writing:\n%s', fp);
    end
    closeGuard = onCleanup(@() fclose(fid)); %#ok<NASGU>

    if strcmp(fmt, 'origin')
        longNames = cellfun(@(h) strtrim(regexprep(h, '\s*\([^)]+\)', '')), ...
                            allHdrs, 'UniformOutput', false);
        units = cellfun(@(h) extractUnit(h), allHdrs, 'UniformOutput', false);
        desigs = cell(size(allHdrs));
        isX = true;
        for ci = 1:numel(allHdrs)
            if isX, desigs{ci} = 'X'; isX = false;
            elseif contains(lower(allHdrs{ci}), {'err','std','sigma'}), desigs{ci} = 'yEr';
            else, desigs{ci} = 'Y';
            end
            if ci < numel(allHdrs) && ~isempty(regexp(allHdrs{ci+1}, '^\s*X\b', 'once'))
                isX = true;
            end
        end
        fprintf(fid, '%s\n', strjoin(longNames, ','));
        fprintf(fid, '%s\n', strjoin(units, ','));
        fprintf(fid, '%s\n', strjoin(desigs, ','));
    else
        fprintf(fid, '%s\n', strjoin(allHdrs, ','));
    end

    hasDatetime = any(cellfun(@isdatetime, allCols));
    if hasDatetime
        for r = 1:maxRows
            parts = cell(1, numel(allCols));
            for ci = 1:numel(allCols)
                col = allCols{ci};
                if r <= numel(col)
                    if isdatetime(col)
                        parts{ci} = datestr(col(r), 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST>
                    else
                        parts{ci} = sprintf('%.10g', col(r));
                    end
                else
                    parts{ci} = '';
                end
            end
            fprintf(fid, '%s\n', strjoin(parts, ','));
        end
    else
        mat = NaN(maxRows, numel(allCols));
        for ci = 1:numel(allCols)
            col = allCols{ci};
            mat(1:numel(col), ci) = col;
        end
        rowFmt = ['%.10g', repmat(',%.10g', 1, size(mat, 2) - 1), '\n'];
        fprintf(fid, rowFmt, mat.');
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function tf = isErrorLabel(lbl)
%ISERRORLABEL  True for error/uncertainty columns (left un-offset).
%   Matches 'dR' exactly plus any label containing err/std/sigma — avoids
%   false positives like 'Drift' that merely contain 'dr'.
    l = lower(char(lbl));
    tf = strcmp(l, 'dr') || ~isempty(regexp(l, 'err|std|sigma', 'once'));
end

function u = extractUnit(hdr)
    tok = regexp(hdr, '\(([^)]+)\)', 'tokens', 'once');
    if ~isempty(tok), u = tok{1}; else, u = ''; end
end
