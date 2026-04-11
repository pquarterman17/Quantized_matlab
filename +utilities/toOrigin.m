function success = toOrigin(data, options)
%TOORIGIN  Send a data struct to OriginPro via COM automation.
%
%   success = utilities.toOrigin(data)
%   success = utilities.toOrigin(data, 'SheetName', 'M vs H')
%   success = utilities.toOrigin(data, 'BookName', 'Sample1', ...
%       'AxisLabels', struct('x','Field (Oe)','y','Moment (emu)'), ...
%       'LogY', true)
%
%   Attempts to connect to a running OriginPro instance or start a new one
%   via actxserver('Origin.Application'). Returns true on success, false
%   if Origin is not installed or COM connection fails.
%
%   INPUTS:
%       data — unified data struct (.time, .values, .labels, .units, .metadata)
%
%   OPTIONAL NAME-VALUE PAIRS:
%       SheetName   — worksheet name (default: derived from metadata source)
%       BookName    — workbook name (default: 'MatlabExport')
%       AxisLabels  — struct with fields .x, .y for axis label strings
%       LogY        — logical; set Y axis to log scale (default false)
%       LogX        — logical; set X axis to log scale (default false)
%       Visible     — logical; make Origin visible (default true)
%
%   OUTPUTS:
%       success — true if data was sent; false if Origin not available
%
%   EXAMPLES:
%       data = parser.importAuto('sample.dat');
%       ok = utilities.toOrigin(data, 'SheetName', 'M_vs_H');
%       if ~ok
%           warning('Origin not available; use CSV export instead.');
%       end

    arguments
        data                  (1,1) struct
        options.SheetName     (1,1) string  = ""
        options.BookName      (1,1) string  = "MatlabExport"
        options.AxisLabels    (1,1) struct  = struct()
        options.LogY          (1,1) logical = false
        options.LogX          (1,1) logical = false
        options.Visible       (1,1) logical = true
        options.OriginObj                   = []   % DI hook: pre-built COM-like obj for tests
    end

    success = false;

    % ── Validate input struct ─────────────────────────────────────────
    if ~isfield(data, 'time') || ~isfield(data, 'values') || ...
       ~isfield(data, 'labels') || ~isfield(data, 'units')
        warning('toOrigin:badStruct', 'Input must be a unified data struct.');
        utilities.logError('toOrigin:badStruct', ...
            'Input is not a unified data struct (missing time/values/labels/units).', []);
        return;
    end

    % ── Obtain Origin handle (real COM or injected mock) ──────────────
    % The OriginObj name-value lets tests inject a record-and-replay mock so
    % the call sequence can be verified without OriginPro being installed.
    weOwnHandle = false;
    if isempty(options.OriginObj)
        try
            origin = actxserver('Origin.Application');
            weOwnHandle = true;
        catch ME
            % Origin not installed or COM registration missing — soft-fail
            % but record *why* so users with intermittent issues have a trail.
            utilities.logError('toOrigin:noCom', ...
                sprintf('actxserver(''Origin.Application'') failed: %s', ME.message), ME);
            return;
        end
    else
        origin = options.OriginObj;
    end

    % Only release the handle if we created it ourselves — never release a
    % caller-provided object, the caller owns its lifecycle.
    if weOwnHandle
        cleanupObj = onCleanup(@() safeRelease(origin)); %#ok<NASGU>
    end

    try
        if options.Visible
            origin.Visible = int32(1);
        end

        % ── Determine names ───────────────────────────────────────────
        bookName = char(options.BookName);
        sheetName = char(options.SheetName);
        if isempty(sheetName) && isfield(data, 'metadata') && ...
           isfield(data.metadata, 'source')
            [~, sheetName, ~] = fileparts(data.metadata.source);
        end
        if isempty(sheetName), sheetName = 'Sheet1'; end

        % Sanitise names for LabTalk (remove special chars)
        bookName  = regexprep(bookName,  '[^\w]', '_');
        sheetName = regexprep(sheetName, '[^\w]', '_');

        % ── Create workbook ───────────────────────────────────────────
        % Use `newbook bk:=...` (the canonical LabTalk command for creating
        % a workbook with an explicit short name).  Avoid `win -t data X` —
        % that form interprets X as a *template* name, not the new book's
        % name, so the resulting book ends up auto-named (Book1, Book2, …)
        % and PutWorksheet can no longer address it by name.
        origin.Execute(sprintf('newbook bk:="%s" name:="%s" sheet:=1 option:=lsname;', ...
            bookName, bookName));

        % Read back the *actual* short name Origin assigned (it may have
        % suffixed it on collision, e.g. ThinFilmToolkit2).  Fall back to
        % the requested name on any COM-introspection failure.
        actualBookName = bookName;
        try
            pages = origin.WorksheetPages;
            nPages = pages.Count;
            if nPages > 0
                lastPage = pages.Item(int32(nPages - 1));
                rb = char(lastPage.Name);
                if ~isempty(rb), actualBookName = rb; end
            end
        catch
            % Pages collection not available — keep the requested name
        end

        % Make sure our new book is the active window before any LabTalk
        % `wks.*` commands run (they target the *active* worksheet).
        origin.Execute(sprintf('win -a %s;', actualBookName));

        % ── Rename the default sheet *now* ────────────────────────────
        % This must happen BEFORE PutWorksheet — PutWorksheet addresses
        % the sheet by name via the [Book]Sheet! range syntax, so the
        % sheet must already have its final name when we write data.
        origin.Execute(sprintf('wks.name$ = "%s";', escapeLT(sheetName)));

        % ── Set up columns ────────────────────────────────────────────
        nYCols = size(data.values, 2);
        totalCols = 1 + nYCols;

        % Ensure enough columns exist (worksheet starts with 2).
        % `wks.nCols` sets the total column count directly — more reliable
        % than `wks.addcol(N)`, which is not valid LabTalk (the real form
        % is `wks.addCol()` and adds ONE column per call).
        if totalCols > 2
            origin.Execute(sprintf('wks.nCols = %d;', totalCols));
        end

        % Column 1 = X
        origin.Execute('wks.col1.type = 4;');
        xName = 'X';
        xUnit = '';
        if isfield(data, 'metadata')
            m = data.metadata;
            if isfield(m, 'xColumnName') && ~isempty(m.xColumnName)
                xName = char(m.xColumnName);
            end
            if isfield(m, 'xColumnUnit') && ~isempty(m.xColumnUnit)
                xUnit = char(m.xColumnUnit);
            elseif isfield(m, 'parserSpecific') && isfield(m.parserSpecific, 'xUnit')
                xUnit = char(m.parserSpecific.xUnit);
            end
        end
        origin.Execute(sprintf('wks.col1.lname$ = "%s";', escapeLT(xName)));
        origin.Execute(sprintf('wks.col1.unit$ = "%s";', escapeLT(xUnit)));

        % Y columns
        for k = 1:nYCols
            cn = k + 1;
            lbl = char(data.labels{k});
            unt = char(data.units{k});

            % Column designation: yErr for error-like columns
            if contains(lower(lbl), {'err', 'dr', 'std', 'sigma'})
                origin.Execute(sprintf('wks.col%d.type = 3;', cn));   % yErr
            else
                origin.Execute(sprintf('wks.col%d.type = 1;', cn));   % Y
            end
            origin.Execute(sprintf('wks.col%d.lname$ = "%s";', cn, escapeLT(lbl)));
            origin.Execute(sprintf('wks.col%d.unit$ = "%s";', cn, escapeLT(unt)));
        end

        % ── Write data ────────────────────────────────────────────────
        % PutWorksheet's first argument MUST be a fully-qualified range:
        % `[BookShortName]SheetShortName!`.  Passing only a sheet name is
        % undocumented and fails silently when Origin can't resolve it
        % (which is exactly the case the original code hit — it produced
        % "headers but no data").  We also check the boolean return value
        % so we can warn instead of pretending it worked.
        mat = [data.time(:), data.values];
        rangePath = sprintf('[%s]%s!', actualBookName, sheetName);
        wrote = origin.PutWorksheet(rangePath, mat, 0, 0);
        if (isnumeric(wrote) || islogical(wrote)) && ~wrote
            % Last-ditch fallback: some Origin builds resolve a bare
            % sheet name when there's only one open book.
            wrote = origin.PutWorksheet(sheetName, mat, 0, 0);
            if (isnumeric(wrote) || islogical(wrote)) && ~wrote
                msg = sprintf(['Origin.PutWorksheet failed for range %s ' ...
                    '(matrix %dx%d, %d Y columns) — workbook is likely empty.'], ...
                    rangePath, size(mat,1), size(mat,2), nYCols);
                warning('toOrigin:putWorksheetFailed', '%s', msg);
                utilities.logError('toOrigin:putWorksheetFailed', msg, []);
            end
        end

        % ── Optional: axis scales ─────────────────────────────────────
        if options.LogX
            origin.Execute('layer.x.type = 1;');
        end
        if options.LogY
            origin.Execute('layer.y.type = 1;');
        end

        % ── Optional: axis labels ─────────────────────────────────────
        if isfield(options.AxisLabels, 'x') && ~isempty(options.AxisLabels.x)
            origin.Execute(sprintf('xb.text$ = "%s";', escapeLT(char(options.AxisLabels.x))));
        end
        if isfield(options.AxisLabels, 'y') && ~isempty(options.AxisLabels.y)
            origin.Execute(sprintf('yl.text$ = "%s";', escapeLT(char(options.AxisLabels.y))));
        end

        success = true;
    catch ME
        warning('toOrigin:comError', 'Origin COM error: %s', ME.message);
        utilities.logError('toOrigin:comError', ...
            sprintf('Origin COM error during data export: %s', ME.message), ME);
        success = false;
    end
end


% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function safeRelease(origin)
%SAFERELEASE  Release COM object without throwing.
    try
        origin.release();
    catch
        % Ignore release errors
    end
end


function s = escapeLT(str)
%ESCAPELT  Escape double-quotes for LabTalk string literals.
    s = strrep(str, '"', '\"');
end
