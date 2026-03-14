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
    end

    success = false;

    % ── Validate input struct ─────────────────────────────────────────
    if ~isfield(data, 'time') || ~isfield(data, 'values') || ...
       ~isfield(data, 'labels') || ~isfield(data, 'units')
        warning('toOrigin:badStruct', 'Input must be a unified data struct.');
        return;
    end

    % ── Attempt COM connection ────────────────────────────────────────
    try
        origin = actxserver('Origin.Application');
    catch
        % Origin not installed or COM registration missing
        return;
    end

    cleanupObj = onCleanup(@() safeRelease(origin));

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
        origin.Execute(sprintf('win -t data %s;', bookName));
        origin.Execute(sprintf('page.longname$ = "%s";', bookName));

        % ── Set up columns ────────────────────────────────────────────
        nYCols = size(data.values, 2);
        totalCols = 1 + nYCols;

        % Ensure enough columns exist (worksheet starts with 2)
        if totalCols > 2
            origin.Execute(sprintf('wks.addcol(%d);', totalCols - 2));
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
        mat = [data.time(:), data.values];
        origin.PutWorksheet(sheetName, mat, 0, 0);

        % ── Rename sheet ──────────────────────────────────────────────
        origin.Execute(sprintf('wks.name$ = "%s";', escapeLT(sheetName)));

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
