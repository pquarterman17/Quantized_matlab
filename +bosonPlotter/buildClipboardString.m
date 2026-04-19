function s = buildClipboardString(appData, dsIndices)
%BUILDCLIPBOARDSTRING  Build tab-delimited text with Origin-style headers.
%
% Syntax
%   s = bosonPlotter.buildClipboardString(appData, dsIndices)
%
% Behaviour
%   Returns a string ready for `clipboard('copy', s)` that pastes
%   cleanly into OriginPro.  The header is three rows (Long Name,
%   Units, Comments/Designation) followed by data rows.  Column
%   designations use Origin's abbreviations: `X` for x-axis, `yEr`
%   when the label contains err/dr/std/sigma, `Y` otherwise.  When
%   more than one dataset is selected, each column's long name is
%   prefixed with the source filename so Origin paste retains
%   provenance.  Corrected data is preferred over raw when available,
%   and display-unit conversions are applied before serialisation.
%
% Inputs
%   appData    - bosonPlotter.AppState handle (reads datasets)
%   dsIndices  - 1-based indices into appData.datasets to include
%
% Output
%   s          - Tab-delimited clipboard string (lines joined by
%                MATLAB `newline`)

    allLongNames = {};
    allUnits     = {};
    allDesig     = {};
    allCols      = {};
    multiDS      = numel(dsIndices) > 1;

    for ii = 1:numel(dsIndices)
        di = dsIndices(ii);
        dsi = appData.datasets{di};
        src = guiTernary(~isempty(dsi.corrData), dsi.corrData, dsi.data);
        src = bosonPlotter.applyDisplayUnits(src, dsi, appData);
        [~, fn, ~] = fileparts(dsi.filepath);
        prefix = guiTernary(multiDS, [fn, '_'], '');

        % X column
        allLongNames{end+1} = [prefix, 'X']; %#ok<AGROW>
        allUnits{end+1}     = extractXUnitFromStruct(src); %#ok<AGROW>
        allDesig{end+1}     = 'X'; %#ok<AGROW>
        allCols{end+1}      = src.time(:); %#ok<AGROW>

        % Y columns
        for k = 1:size(src.values, 2)
            allLongNames{end+1} = [prefix, src.labels{k}]; %#ok<AGROW>
            allUnits{end+1}     = src.units{k}; %#ok<AGROW>
            lbl = lower(src.labels{k});
            if contains(lbl, {'err', 'dr', 'std', 'sigma'})
                allDesig{end+1} = 'yEr'; %#ok<AGROW>
            else
                allDesig{end+1} = 'Y'; %#ok<AGROW>
            end
            allCols{end+1} = src.values(:, k); %#ok<AGROW>
        end
    end

    % Determine max rows across all datasets
    maxR = max(cellfun(@numel, allCols));
    nC   = numel(allCols);

    % Build string: Long Name / Units / Comments header rows, then data
    lines = cell(1, maxR + 3);
    lines{1} = strjoin(allLongNames, sprintf('\t'));
    lines{2} = strjoin(allUnits, sprintf('\t'));
    lines{3} = strjoin(allDesig, sprintf('\t'));

    for r = 1:maxR
        vals = cell(1, nC);
        for c = 1:nC
            if r <= numel(allCols{c})
                vals{c} = sprintf('%.10g', allCols{c}(r));
            else
                vals{c} = '';
            end
        end
        lines{r + 3} = strjoin(vals, sprintf('\t'));
    end

    s = strjoin(lines, newline);
end

% ════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m module-level scope)
% ════════════════════════════════════════════════════════════════════════

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function unit = extractXUnitFromStruct(d)
%EXTRACTXUNITFROMSTRUCT  Get X-axis unit string from a data struct's metadata.
    unit = '';
    if ~isfield(d, 'metadata'), return; end
    m = d.metadata;
    if isfield(m, 'xColumnUnit') && ~isempty(m.xColumnUnit)
        unit = char(m.xColumnUnit);
    elseif isfield(m, 'parserSpecific') && isfield(m.parserSpecific, 'xUnit')
        unit = char(m.parserSpecific.xUnit);
    end
end
