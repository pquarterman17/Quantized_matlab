function sendToOrigin(appData, fig, guiState)
%SENDTOORIGIN  Send selected dataset(s) to OriginPro via COM.
%
%   bosonPlotter.sendToOrigin(appData, fig, guiState)
%
%   One selected dataset  → sent as a single worksheet.
%   Multiple selected     → a popup offers:
%       • Active dataset only
%       • Separate workbook per dataset (each dataset → its OWN workbook)
%       • One workbook, one worksheet tab per dataset (all in "ThinFilmToolkit")
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
%                  .mode             (optional) 'active'|'books'|'sheets'|'combined'
%                                    — skips the popup (tests / scripting).
%                                    'books'  = separate workbook per dataset;
%                                    'sheets' = one workbook, a tab per dataset.
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
            mode = askSendMode(fig, numel(selIdx), appData.theme);
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

    % ── Per-dataset layout: separate workbooks ('books') OR one workbook
    %    with a worksheet tab per dataset ('sheets') ─────────────────────
    %    'books' routes every dataset through the single-dataset newbook
    %    path (AddSheet=false, unique BookName), which avoids the shared-book
    %    AddSheet sequence that could drop datasets when several were sent.
    perBook   = strcmp(mode, 'books');
    nOk       = 0;
    usedNames = {};
    usedBooks = {};
    for k = 1:numel(selIdx)
        di  = selIdx(k);
        ds  = appData.datasets{di};
        src = guiTernary_(~isempty(ds.corrData), ds.corrData, ds.data);
        src = bosonPlotter.applyDisplayUnits(src, ds, appData);

        if perBook
            book     = uniqueName(ds, usedBooks, 'Book');
            usedBooks{end+1} = book; %#ok<AGROW>
            sheet    = 'Sheet1';
            addSheet = false;        % each dataset → its OWN new workbook
        else
            book     = 'ThinFilmToolkit';
            sheet    = uniqueName(ds, usedNames, 'Sheet');
            usedNames{end+1} = sheet; %#ok<AGROW>
            addSheet = k > 1;        % first creates the book; rest add tabs
        end

        ok = utilities.toOrigin(src, ...
            'SheetName',  sheet, ...
            'BookName',   book, ...
            'AddSheet',   addSheet, ...
            'AxisLabels', axLabels, ...
            'LogY', logY, 'LogX', logX, ...
            'OriginObj', origin);
        if ok, nOk = nOk + 1; end
    end

    where = guiTernary_(perBook, ...
        sprintf('%d separate workbook(s)', nOk), ...
        'workbook "ThinFilmToolkit"');
    if nOk == numel(selIdx)
        bosonPlotter.quietAlert(fig, ...
            sprintf('Sent %d dataset(s) to OriginPro\n(%s).', nOk, where), ...
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

function mode = askSendMode(fig, nSel, theme)
%ASKSENDMODE  Modal dialog: how to lay out multiple datasets in Origin.
%   Returns 'active' | 'books' | 'sheets' | 'combined', or '' if cancelled.
%   Uses radio buttons (not uiconfirm) so all four distinct layouts read
%   clearly — separate workbooks vs. tabs in one workbook were previously
%   conflated under a single "one worksheet per dataset" wording.
    mode = '';
    if nargin < 3 || isempty(theme), theme = 'Dark'; end
    if bosonPlotter.isHeadless()
        mode = 'books';   % scripted/headless multi-select default
        return;
    end

    pos = [300 300 440 250];
    try
        fp = fig.Position;
        pos(1:2) = [fp(1) + (fp(3)-pos(3))/2, fp(2) + (fp(4)-pos(4))/2];
    catch
    end
    dlg = uifigure('Name', 'Send to Origin', 'WindowStyle', 'modal', ...
        'Resize', 'off', 'Position', pos);
    gl = uigridlayout(dlg, [3 1], 'RowHeight', {30, 120, 36}, ...
        'Padding', [14 12 14 12], 'RowSpacing', 8);

    uilabel(gl, 'Text', sprintf('%d datasets selected. How should they be sent to Origin?', nSel), ...
        'WordWrap', 'on');

    bg = uibuttongroup(gl, 'BorderType', 'none');
    rbActive = uiradiobutton(bg, 'Text', 'Active dataset only', ...
        'Position', [6 96 410 20]); %#ok<NASGU>
    rbBooks  = uiradiobutton(bg, 'Text', sprintf('Separate workbook per dataset (%d workbooks)', nSel), ...
        'Position', [6 66 410 20]);
    rbSheets = uiradiobutton(bg, 'Text', sprintf('One workbook, a worksheet tab per dataset (%d tabs)', nSel), ...
        'Position', [6 36 410 20]); %#ok<NASGU>
    rbComb   = uiradiobutton(bg, 'Text', sprintf('Combined into one worksheet (%d datasets)', nSel), ...
        'Position', [6 6 410 20]); %#ok<NASGU>
    bg.SelectedObject = rbBooks;   % "own workbook" is the natural multi-select choice

    btnGL = uigridlayout(gl, [1 3], 'ColumnWidth', {'1x', 90, 90}, 'Padding', [0 0 0 0]);
    uilabel(btnGL);
    uibutton(btnGL, 'Text', 'Cancel', 'ButtonPushedFcn', @(~,~) finish(false));
    uibutton(btnGL, 'Text', 'Send', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) finish(true));

    try, bosonPlotter.applyDialogTheme(dlg, theme); catch, end
    uiwait(dlg);

    function finish(ok)
        if ok
            switch bg.SelectedObject.Text
                case rbBooks.Text,  mode = 'books';
                case rbSheets.Text, mode = 'sheets';
                case rbComb.Text,   mode = 'combined';
                otherwise,          mode = 'active';
            end
        else
            mode = '';
        end
        if isvalid(dlg), uiresume(dlg); delete(dlg); end
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

function name = uniqueName(ds, usedNames, fallback)
%UNIQUENAME  Sanitised, <=32-char, collision-free workbook/worksheet name.
%   Used for both worksheet tabs ('sheets' mode) and workbooks ('books'
%   mode); Origin imposes the same 32-char / word-char constraints on each.
    if nargin < 3 || isempty(fallback), fallback = 'Sheet'; end
    if isfield(ds, 'legendName') && ~isempty(ds.legendName)
        base = ds.legendName;
    else
        [~, fn, ~] = fileparts(ds.filepath);
        base = fn;
    end
    base = regexprep(base, '[^\w]', '_');   % mirror toOrigin's sanitisation
    if isempty(base), base = fallback; end
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
