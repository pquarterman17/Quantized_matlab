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

    arguments
        data                  (1,1) struct
        options.SheetName     (1,1) string  = ""
        options.BookName      (1,1) string  = "MatlabExport"
        options.AxisLabels    (1,1) struct  = struct()
        options.LogY          (1,1) logical = false
        options.LogX          (1,1) logical = false
        options.Visible       (1,1) logical = true
        options.OriginObj                   = []
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
        try
            origin = actxserver('Origin.Application');
            weOwnHandle = true;
        catch ME
            utilities.logError('toOrigin:noCom', ...
                sprintf('actxserver(''Origin.Application'') failed: %s', ME.message), ME);
            return;
        end
    else
        origin = options.OriginObj;
    end

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

        bookName  = sanitiseLTName(bookName);
        sheetName = sanitiseLTName(sheetName);

        if isempty(bookName),  bookName  = 'MatlabExport'; end
        if isempty(sheetName), sheetName = 'Sheet1'; end

        % Origin worksheet names are limited to 32 characters
        if numel(sheetName) > 32
            sheetName = sheetName(1:32);
        end

        % ── Create workbook ───────────────────────────────────────────
        % `name:=` without `option:=lsname` sets the short name directly,
        % which is what range references like [BookName]Sheet! require.
        origin.Execute(sprintf('newbook name:="%s" sheet:=1;', bookName));

        origin.Execute(sprintf('win -a %s;', bookName));

        % ── Rename the default sheet ──────────────────────────────────
        origin.Execute(sprintf('wks.name$ = "%s";', escapeLT(sheetName)));

        % ── Set up columns ────────────────────────────────────────────
        nYCols = size(data.values, 2);
        totalCols = 1 + nYCols;

        if totalCols > 2
            origin.Execute(sprintf('wks.nCols = %d;', totalCols));
        end

        % Column 1 = X  (Origin type code: 3 = X)
        origin.Execute('wks.col1.type = 3;');
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

        % Y columns (Origin type codes: 0 = Y, 2 = yErr)
        for k = 1:nYCols
            cn = k + 1;
            lbl = char(data.labels{k});
            unt = char(data.units{k});

            if contains(lower(lbl), {'err', 'dr', 'std', 'sigma'})
                origin.Execute(sprintf('wks.col%d.type = 2;', cn));
            else
                origin.Execute(sprintf('wks.col%d.type = 0;', cn));
            end
            origin.Execute(sprintf('wks.col%d.lname$ = "%s";', cn, escapeLT(lbl)));
            origin.Execute(sprintf('wks.col%d.unit$ = "%s";', cn, escapeLT(unt)));
        end

        % ── Write data ────────────────────────────────────────────────
        mat = [timeVec, data.values];
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

function tf = wroteOk(wrote)
    if isempty(wrote)
        tf = true;
    elseif (isnumeric(wrote) || islogical(wrote))
        tf = logical(wrote);
    else
        tf = true;
    end
end
