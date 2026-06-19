function sendToOrigin(appData, fig, guiState)
%SENDTOORIGIN  Send selected dataset(s) to OriginPro via COM.
%
%   bosonPlotter.sendToOrigin(appData, fig, guiState)
%
%   One selected dataset  → sent as a single worksheet.
%   Multiple selected     → a popup offers:
%       • Active dataset only
%       • One worksheet per dataset   (all in workbook "ThinFilmToolkit")
%       • Combined into one worksheet (X1 Y1 | X2 Y2 | ... side by side)
%   Falls back to copying the active dataset to the clipboard when
%   OriginPro is not available.
%
%   Inputs:
%     appData  - AppState handle
%     fig      - uifigure (alert/confirm parent)
%     guiState - struct with fields:
%                  .xLabel, .yLabel  axis label strings ('' = derive)
%                  .logX, .logY      logical axis-scale flags
%                  .selIdx           (optional) selected dataset indices
%                  .mode             (optional) 'active'|'sheets'|'combined'
%                                    — skips the popup (tests / scripting)
%                  .originObj        (optional) injected COM handle (tests)

    if isempty(appData.datasets) || appData.activeIdx < 1
        bosonPlotter.quietAlert(fig, 'Load a file first.', 'No data');
        return;
    end

    logX = isfield(guiState, 'logX') && guiState.logX;
    logY = isfield(guiState, 'logY') && guiState.logY;

    % ── Resolve the selection ──────────────────────────────────────────
    selIdx = appData.activeIdx;
    if isfield(guiState, 'selIdx') && ~isempty(guiState.selIdx)
        selIdx = guiState.selIdx(:)';
    end
    selIdx = selIdx(selIdx >= 1 & selIdx <= numel(appData.datasets));
    selIdx = unique(selIdx, 'stable');
    if isempty(selIdx), selIdx = appData.activeIdx; end

    % ── Choose how to lay the datasets out ─────────────────────────────
    if numel(selIdx) > 1
        if isfield(guiState, 'mode') && ~isempty(guiState.mode)
            mode = guiState.mode;
        else
            mode = askSendMode(fig, numel(selIdx));
            if isempty(mode), return; end
        end
    else
        mode = 'sheets';   % single dataset → one worksheet
    end
    if strcmp(mode, 'active')
        selIdx = appData.activeIdx;
        mode   = 'sheets';
    end

    % ── Connect to Origin (injected handle wins, for tests) ────────────
    weOwn = false;
    if isfield(guiState, 'originObj') && ~isempty(guiState.originObj)
        origin = guiState.originObj;
    else
        try
            origin = actxserver('Origin.Application');
            weOwn  = true;
        catch
            origin = [];
        end
    end

    if isempty(origin)
        clipStr = bosonPlotter.buildClipboardString(appData, appData.activeIdx);
        clipboard('copy', clipStr);
        bosonPlotter.quietAlert(fig, ...
            ['Origin not available — active dataset copied to clipboard instead.' newline ...
             'Paste into Origin with Edit > Paste.'], ...
            'Origin not found');
        return;
    end
    if weOwn
        cleanupObj = onCleanup(@() safeRelease(origin)); %#ok<NASGU>
    end

    axLabels = struct();
    if isfield(guiState, 'xLabel') && ~isempty(guiState.xLabel)
        axLabels.x = guiState.xLabel;
    end
    if isfield(guiState, 'yLabel') && ~isempty(guiState.yLabel)
        axLabels.y = guiState.yLabel;
    end

    % ── Combined: all datasets side by side in one worksheet ───────────
    if strcmp(mode, 'combined')
        [cData, colTypes] = buildCombined(appData, selIdx);
        ok = utilities.toOrigin(cData, ...
            'SheetName',  'Combined', ...
            'BookName',   'ThinFilmToolkit', ...
            'ColTypes',   colTypes, ...
            'AxisLabels', axLabels, ...
            'LogY', logY, 'LogX', logX, ...
            'OriginObj', origin);
        if ok
            bosonPlotter.quietAlert(fig, ...
                sprintf('Sent %d datasets to one OriginPro worksheet.', numel(selIdx)), ...
                'Origin Export');
        else
            originFailedAlert(fig);
        end
        return;
    end

    % ── One worksheet per dataset ──────────────────────────────────────
    nOk = 0;
    usedNames = {};
    for k = 1:numel(selIdx)
        di  = selIdx(k);
        ds  = appData.datasets{di};
        src = guiTernary_(~isempty(ds.corrData), ds.corrData, ds.data);
        src = bosonPlotter.applyDisplayUnits(src, ds, appData);
        sheet = uniqueSheetName(ds, usedNames);
        usedNames{end+1} = sheet; %#ok<AGROW>
        ok = utilities.toOrigin(src, ...
            'SheetName',  sheet, ...
            'BookName',   'ThinFilmToolkit', ...
            'AddSheet',   k > 1, ...   % first creates the book; rest add sheets
            'AxisLabels', axLabels, ...
            'LogY', logY, 'LogX', logX, ...
            'OriginObj', origin);
        if ok, nOk = nOk + 1; end
    end

    if nOk == numel(selIdx)
        bosonPlotter.quietAlert(fig, ...
            sprintf('Sent %d dataset(s) to OriginPro\n(workbook: ThinFilmToolkit).', nOk), ...
            'Origin Export');
    elseif nOk > 0
        bosonPlotter.quietAlert(fig, ...
            sprintf('Sent %d of %d datasets; %d failed (see error log).', ...
                nOk, numel(selIdx), numel(selIdx) - nOk), ...
            'Origin Export');
    else
        originFailedAlert(fig);
    end
end

% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function mode = askSendMode(fig, nSel)
%ASKSENDMODE  Prompt how to lay out multiple datasets in Origin.
    choices = { ...
        'Active dataset only', ...
        sprintf('One worksheet per dataset (%d sheets)', nSel), ...
        sprintf('Combined into one worksheet (%d datasets)', nSel), ...
        'Cancel'};
    answer = bosonPlotter.quietConfirm(fig, ...
        sprintf('%d datasets selected. How should they be sent to Origin?', nSel), ...
        'Send to Origin', ...
        'Options', choices, 'DefaultOption', 2, 'CancelOption', 4);
    switch answer
        case choices{1}, mode = 'active';
        case choices{2}, mode = 'sheets';
        case choices{3}, mode = 'combined';
        otherwise,       mode = '';
    end
end

function [cData, colTypes] = buildCombined(appData, selIdx)
%BUILDCOMBINED  Pack selected datasets side by side into one data struct.
%   Returns a unified data struct (time = first X column, values = the rest)
%   plus colTypes — a per-column designation cellstr so toOrigin can mark
%   each dataset's X / Y / yErr columns correctly in the single worksheet.
    cols = {}; names = {}; units = {}; types = {};
    for k = 1:numel(selIdx)
        ds  = appData.datasets{selIdx(k)};
        src = guiTernary_(~isempty(ds.corrData), ds.corrData, ds.data);
        src = bosonPlotter.applyDisplayUnits(src, ds, appData);
        tag = datasetTag(ds);

        cols{end+1}  = src.time(:);                   %#ok<AGROW>
        names{end+1} = sprintf('X [%s]', tag);        %#ok<AGROW>
        units{end+1} = xUnitOf(src);                  %#ok<AGROW>
        types{end+1} = 'X';                           %#ok<AGROW>

        for li = 1:numel(src.labels)
            cols{end+1}  = src.values(:, li);                          %#ok<AGROW>
            names{end+1} = sprintf('%s [%s]', src.labels{li}, tag);    %#ok<AGROW>
            u = ''; if li <= numel(src.units), u = src.units{li}; end
            units{end+1} = u;                                          %#ok<AGROW>
            lbl = lower(src.labels{li});
            if strcmp(lbl, 'dr') || contains(lbl, {'err', 'std', 'sigma'})
                types{end+1} = 'yErr';                                 %#ok<AGROW>
            else
                types{end+1} = 'Y';                                    %#ok<AGROW>
            end
        end
    end

    maxRows = max(cellfun(@numel, cols));
    M = NaN(maxRows, numel(cols));
    for c = 1:numel(cols)
        v = cols{c}(:);
        M(1:numel(v), c) = v;
    end

    cData = struct();
    cData.time     = M(:, 1);
    cData.values   = M(:, 2:end);
    cData.labels   = names(2:end);
    cData.units    = units(2:end);
    cData.metadata = struct('xColumnName', names{1}, 'xColumnUnit', units{1});
    colTypes = types;   % length == 1 + size(cData.values,2)
end

function name = uniqueSheetName(ds, usedNames)
%UNIQUESHEETNAME  Sanitised, <=32-char, collision-free worksheet name.
    if isfield(ds, 'legendName') && ~isempty(ds.legendName)
        base = ds.legendName;
    else
        [~, fn, ~] = fileparts(ds.filepath);
        base = fn;
    end
    base = regexprep(base, '[^\w]', '_');   % mirror toOrigin's sanitisation
    if isempty(base), base = 'Sheet'; end
    if numel(base) > 28, base = base(1:28); end
    name = base;
    n = 1;
    while any(strcmp(name, usedNames))
        n   = n + 1;
        suf = sprintf('_%d', n);
        keep = max(1, min(numel(base), 32 - numel(suf)));
        name = [base(1:keep), suf];
    end
    if numel(name) > 32, name = name(1:32); end
end

function tag = datasetTag(ds)
%DATASETTAG  Provenance label for a dataset: legend name or file name.
    if isfield(ds, 'legendName') && ~isempty(ds.legendName)
        tag = ds.legendName;
    else
        [~, fn, fext] = fileparts(ds.filepath);
        tag = [fn fext];
    end
end

function u = xUnitOf(src)
%XUNITOF  Best-effort X-axis unit string for a data struct.
    u = '';
    if isfield(src, 'metadata')
        m = src.metadata;
        if isfield(m, 'xColumnUnit') && ~isempty(m.xColumnUnit)
            u = m.xColumnUnit;
        elseif isfield(m, 'parserSpecific') && isfield(m.parserSpecific, 'xUnit')
            u = m.parserSpecific.xUnit;
        end
    end
end

function originFailedAlert(fig)
    bosonPlotter.quietAlert(fig, ...
        ['Origin export failed (see error log). Origin may be busy or the ' ...
         'COM call was rejected.'], 'Origin Export');
end

function safeRelease(origin)
    try
        origin.release();
    catch
    end
end

function out = guiTernary_(cond, ifTrue, ifFalse)
    if cond, out = ifTrue; else, out = ifFalse; end
end
