function [success, bookUsed] = toOrigin(data, options)
%TOORIGIN  Send a data struct to OriginPro via COM automation.
%
%   success = utilities.toOrigin(data)
%   success = utilities.toOrigin(data, 'SheetName', 'M vs H')
%   success = utilities.toOrigin(data, 'BookName', 'Sample1', ...
%       'AxisLabels', struct('x','Field (Oe)','y','Moment (emu)'), ...
%       'LogY', true)
%
%   Attempts to connect to a running OriginPro instance (or start one) via
%   utilities.connectOrigin — which prefers 'Origin.ApplicationSI' (Single
%   Instance) over 'Origin.Application'. Returns true on success, false if
%   Origin is not installed or COM connection fails.
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
%       MakePlot    — logical; after writing data, create a line graph of the
%                     first Y column vs X for the sheet (default false).  Axis
%                     scales (LogX/LogY) and AxisLabels apply to that graph —
%                     on a bare worksheet they are no-ops, so they only take
%                     visible effect when MakePlot is true.
%
%   OUTPUTS:
%       success  — true if data was sent; false if Origin not available
%       bookUsed — the ACTUAL workbook short name the data landed in ('' on
%                  failure).  May differ from BookName when the requested name
%                  was taken; callers adding sibling sheets (AddSheet=true)
%                  must pass this back as BookName so they target the same book.

    arguments
        data                  (1,1) struct
        options.SheetName     (1,1) string  = ""
        options.BookName      (1,1) string  = "MatlabExport"
        options.AxisLabels    (1,1) struct  = struct()
        options.LogY          (1,1) logical = false
        options.LogX          (1,1) logical = false
        options.Visible       (1,1) logical = true
        options.OriginObj                   = []
        options.AddSheet      (1,1) logical = false   % add a worksheet to the active book instead of creating a new book
        options.ColTypes                    = {}      % optional cellstr of per-column designations ('X'/'Y'/'yErr'); overrides auto-typing
        options.MakePlot      (1,1) logical = false   % create a line graph of the data after writing it
    end

    success  = false;
    bookUsed = '';

    % ── Validate input struct ─────────────────────────────────────────
    if ~isfield(data, 'time') || ~isfield(data, 'values') || ...
       ~isfield(data, 'labels') || ~isfield(data, 'units')
        warning('toOrigin:badStruct', 'Input must be a unified data struct.');
        utilities.logError('toOrigin:badStruct', ...
            'Input is not a unified data struct (missing time/values/labels/units).', []);
        return;
    end

    % ── Validate data is non-empty ────────────────────────────────────
    if isempty(data.time) || isempty(data.values)
        warning('toOrigin:emptyData', 'Data struct has empty time or values.');
        utilities.logError('toOrigin:emptyData', ...
            'Data struct has empty time or values — nothing to export.', []);
        return;
    end

    % ── Convert datetime to datenum for matrix concatenation ──────────
    timeVec = data.time(:);
    if isdatetime(timeVec)
        timeVec = datenum(timeVec); %#ok<DATNM>
    end

    % ── Obtain Origin handle (real COM or injected mock) ──────────────
    weOwnHandle = false;
    if isempty(options.OriginObj)
        origin = utilities.connectOrigin();   % prefers the running instance
        if isempty(origin)
            utilities.logError('toOrigin:noCom', ...
                'Could not connect to OriginPro (Origin.ApplicationSI / Origin.Application).', []);
            return;
        end
        weOwnHandle = true;
    else
        origin = options.OriginObj;
    end

    if weOwnHandle
        cleanupObj = onCleanup(@() safeRelease(origin));
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

        bookName  = sanitiseLTName(bookName);
        sheetName = sanitiseLTName(sheetName);

        if isempty(bookName),  bookName  = 'MatlabExport'; end
        if isempty(sheetName), sheetName = 'Sheet1'; end

        % Origin worksheet names are limited to 32 characters
        if numel(sheetName) > 32
            sheetName = sheetName(1:32);
        end

        % ── Column count up front (newsheet needs cols:= at creation) ──
        nYCols    = size(data.values, 2);
        totalCols = 1 + nYCols;
        ct        = options.ColTypes;
        haveCT    = iscell(ct) && numel(ct) == totalCols;

        % ── Create the destination worksheet ──────────────────────────
        if options.AddSheet
            % Add a new worksheet to the (already-existing) active book so
            % multiple datasets land in one workbook as separate sheets.
            origin.Execute(sprintf('win -a %s;', bookName));
            origin.Execute(sprintf('newsheet name:="%s" cols:=%d;', ...
                escapeLT(sheetName), totalCols));
        else
            % Create the workbook and resolve its ACTUAL short name.
            %
            % Preferred: Application.CreatePage(2=Worksheet, name, template)
            % RETURNS the short name Origin actually assigned — so we never
            % guess it.  If `name` is already taken (e.g. a prior send) Origin
            % hands back a unique variant (Book2…); we then reference THAT for
            % win -a / [book]sheet! and there is no scatter/overwrite.
            %
            % Fallback (older Origin, or injected mocks without CreatePage):
            % `newbook name:=name` + page.name$ to pin the short name.  `name:=`
            % sets the short name for a fresh name, but diverges when taken or
            % treated as a long name; page.name$ pins it (non-fatal if rejected).
            realBook = '';
            try
                realBook = char(origin.CreatePage(2, bookName, 'Origin'));
            catch
                realBook = '';
            end
            if isempty(realBook)
                origin.Execute(sprintf('newbook name:="%s" sheet:=1;', bookName));
                try
                    origin.Execute(sprintf('page.name$ = "%s";', bookName));
                catch
                end
                realBook = bookName;
            end
            bookName = realBook;   % every reference below uses the ACTUAL name
            origin.Execute(sprintf('win -a %s;', bookName));
            origin.Execute(sprintf('wks.name$ = "%s";', escapeLT(sheetName)));
            if totalCols > 2
                origin.Execute(sprintf('wks.nCols = %d;', totalCols));
            end
        end

        % ── Column 1 (X by default; overridable via ColTypes) ─────────
        if haveCT
            origin.Execute(sprintf('wks.col1.type = %d;', originTypeCode(ct{1})));
        else
            origin.Execute('wks.col1.type = 3;');   % 3 = X
        end
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

        % ── Y columns (type codes: 0 = Y, 2 = yErr, 3 = X) ────────────
        for k = 1:nYCols
            cn  = k + 1;
            lbl = char(data.labels{k});
            unt = char(data.units{k});

            if haveCT
                tc = originTypeCode(ct{cn});
            elseif contains(lower(lbl), {'err', 'dr', 'std', 'sigma'})
                tc = 2;
            else
                tc = 0;
            end
            origin.Execute(sprintf('wks.col%d.type = %d;', cn, tc));
            origin.Execute(sprintf('wks.col%d.lname$ = "%s";', cn, escapeLT(lbl)));
            origin.Execute(sprintf('wks.col%d.unit$ = "%s";', cn, escapeLT(unt)));
        end

        % ── Write data ────────────────────────────────────────────────
        mat = [timeVec, data.values];

        % Preferred: write through the worksheet OBJECT.  FindWorksheet('')
        % returns the ACTIVE worksheet — which is exactly the sheet we just
        % created / renamed / added — so there is no name-string resolution at
        % write time (Worksheet.SetData == Application.PutWorksheet).
        wroteObj = false;
        try
            wksObj = origin.FindWorksheet('');
            if ~isempty(wksObj)
                res = wksObj.SetData(mat, 0, 0);
                wroteObj = wroteOk(res);
            end
        catch
            wroteObj = false;
        end

        % Fallback: PutWorksheet by range name (older Origin / object call
        % unavailable).  Tries qualified [book]sheet!, bare sheet, then Sheet1.
        if ~wroteObj
            rangePath = sprintf('[%s]%s!', bookName, sheetName);
            wrote = origin.PutWorksheet(rangePath, mat, 0, 0);
            if ~wroteOk(wrote)
                wrote = origin.PutWorksheet(sheetName, mat, 0, 0);
            end
            if ~wroteOk(wrote)
                wrote = origin.PutWorksheet(sprintf('[%s]Sheet1!', bookName), mat, 0, 0);
            end
            if ~wroteOk(wrote)
                msg = sprintf(['Origin.PutWorksheet failed for range %s ' ...
                    '(matrix %dx%d, %d Y columns) — workbook is likely empty.'], ...
                    rangePath, size(mat,1), size(mat,2), nYCols);
                warning('toOrigin:putWorksheetFailed', '%s', msg);
                utilities.logError('toOrigin:putWorksheetFailed', msg, []);
            end
        end

        % ── Optional: line graph of the first Y vs X for this sheet ────
        % A worksheet has no axis scale or axis labels, so LogX/LogY and
        % AxisLabels are applied to the GRAPH layer plotxy creates.  Without a
        % plot they would target a worksheet and do nothing, so they are only
        % emitted here, gated on MakePlot.
        if options.MakePlot
            % plot:=200 → line plot; iy:=(1,2) → col1 (X) vs col2 (first Y).
            origin.Execute(sprintf('plotxy iy:=[%s]%s!(1,2) plot:=200;', ...
                bookName, sheetName));
            % Axis scale type code: 0 = Linear, 2 = Log10 (NOT 1).
            if options.LogX
                origin.Execute('layer.x.type = 2;');
            end
            if options.LogY
                origin.Execute('layer.y.type = 2;');
            end
            % Axis titles via the `label` command (the X-bottom / Y-left title);
            % escapeLT guards ; and % so they don't terminate or substitute.
            if isfield(options.AxisLabels, 'x') && ~isempty(options.AxisLabels.x)
                origin.Execute(sprintf('label -xb %s;', escapeLT(char(options.AxisLabels.x))));
            end
            if isfield(options.AxisLabels, 'y') && ~isempty(options.AxisLabels.y)
                origin.Execute(sprintf('label -yl %s;', escapeLT(char(options.AxisLabels.y))));
            end
        end

        bookUsed = bookName;   % the actual workbook name the data landed in
        success  = true;
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
    try
        origin.release();
    catch
    end
end

function s = escapeLT(str)
    s = strrep(str, '"', '\"');
    s = strrep(s, '%', '\%');
    s = strrep(s, ';', '\;');
    s = regexprep(s, '[\r\n]', ' ');
end

function name = sanitiseLTName(name)
    name = regexprep(name, '[^\w]', '_');
end

function code = originTypeCode(desig)
%ORIGINTYPECODE  Map a designation string to an Origin column type code.
%   'X' → 3, 'yErr'/'err' → 2, anything else → 0 (Y).
    d = lower(strtrim(char(desig)));
    switch d
        case 'x',                   code = 3;
        case {'yerr', 'yer', 'err'}, code = 2;
        otherwise,                  code = 0;
    end
end

function tf = wroteOk(wrote)
    if isempty(wrote)
        tf = true;
    elseif (isnumeric(wrote) || islogical(wrote))
        tf = logical(wrote);
    else
        tf = true;
    end
end
