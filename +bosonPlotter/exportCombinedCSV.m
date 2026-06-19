function exportCombinedCSV(appData, selIdx, fp, fmt, wf)
%EXPORTCOMBINEDCSV  Write multiple datasets side-by-side into one CSV.
%
% Syntax
%   bosonPlotter.exportCombinedCSV(appData, selIdx, fp, fmt)
%   bosonPlotter.exportCombinedCSV(appData, selIdx, fp, fmt, wf)
%
% Each selected dataset contributes its own X column followed by its Y/value
% columns: 'X [tag], R [tag], dR [tag], X [tag2], ...'.  Datasets with
% differing row counts are blank-padded (shorter columns leave trailing cells
% empty rather than printing NaN) so the file imports cleanly into Origin /
% Excel — matching saveConsolidatedNeutronCSV's per-dataset-block writer.
%
% Optional waterfall offset (wf) bakes the on-screen waterfall stacking into
% the written Y values so the CSV matches the plot.  Applied to signal and
% theory columns only — X and error columns (designation 'X'/'yEr'/'xEr') are
% left raw, exactly like the on-screen waterfall (error bars ride along, the
% error magnitude is unchanged).
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
%
% Header format
%   'standard' — one row of '<Long Name> (<unit>) [<tag>]' (the [tag]
%       disambiguates datasets in the side-by-side layout).
%   'origin'   — three rows so nothing is stuffed into one line:
%       Row 1  Long Name [tag]   Row 2  Units   Row 3  Comments (X/Y/yEr/xEr)

    if nargin < 5 || isempty(wf) || ~isstruct(wf)
        wf = struct('apply', false, 'levels', [], 'spacing', 0, 'logMode', false);
    end
    applyWf = isfield(wf, 'apply') && wf.apply && isfield(wf, 'spacing') && wf.spacing ~= 0;

    % ── Build per-column descriptors (name / unit / tag / desig / data) ──────
    cols = newColumn();   % empty 0x0 struct array with the canonical fields
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

        % ── X column (own per dataset; never offset) ──
        cols(end+1) = newColumn(guiXName(d), guiXUnit(d), tag, 'X', d.time(:)); %#ok<AGROW>

        % ── Value columns ──
        for ci = 1:numel(d.labels)
            lbl  = d.labels{ci};
            role = columnRole(lbl);
            yCol = d.values(:, ci);
            % Bake in the waterfall offset for signal columns only (role 'Y').
            % X and error/resolution columns ('yEr'/'xEr') are left raw.
            if applyWf && lvl ~= 0 && strcmp(role, 'Y')
                if wf.logMode
                    yCol = yCol * (wf.spacing ^ lvl);
                else
                    yCol = yCol + lvl * wf.spacing;
                end
            end
            u = '';
            if ci <= numel(d.units), u = d.units{ci}; end
            cols(end+1) = newColumn(lbl, u, tag, role, yCol); %#ok<AGROW>
        end
    end

    writeCombinedCSV(fp, fmt, cols);
end

% ════════════════════════════════════════════════════════════════════════
%  CSV writer
% ════════════════════════════════════════════════════════════════════════

function writeCombinedCSV(fp, fmt, cols)
%WRITECOMBINEDCSV  Header(s) + columns to fp.  Columns may differ in length;
%   shorter columns leave trailing cells blank rather than printing NaN.
    dirPart = fileparts(fp);
    if ~isempty(dirPart) && ~isfolder(dirPart)
        error('exportCombinedCSV:badDir', 'Output directory does not exist:\n%s', dirPart);
    end
    fid = fopen(fp, 'w');
    if fid < 0
        error('exportCombinedCSV:cannotOpen', 'Cannot open file for writing:\n%s', fp);
    end
    closeGuard = onCleanup(@() fclose(fid)); %#ok<NASGU>

    nCols = numel(cols);
    if nCols == 0, return; end

    if strcmp(fmt, 'origin')
        longRow  = cell(1, nCols);
        unitRow  = cell(1, nCols);
        desigRow = cell(1, nCols);
        for c = 1:nCols
            longRow{c}  = sprintf('%s [%s]', cols(c).name, cols(c).tag);
            unitRow{c}  = cols(c).unit;
            desigRow{c} = cols(c).desig;
        end
        writeHeaderRow(fid, longRow);    % Long Name [tag]
        writeHeaderRow(fid, unitRow);    % Units
        writeHeaderRow(fid, desigRow);   % Comments (Origin column designation)
    else
        hdr = cell(1, nCols);
        for c = 1:nCols
            if ~isempty(cols(c).unit)
                hdr{c} = sprintf('%s (%s) [%s]', cols(c).name, cols(c).unit, cols(c).tag);
            else
                hdr{c} = sprintf('%s [%s]', cols(c).name, cols(c).tag);
            end
        end
        writeHeaderRow(fid, hdr);
    end

    maxRows = 0;
    for c = 1:nCols
        maxRows = max(maxRows, numel(cols(c).data));
    end
    for r = 1:maxRows
        parts = cell(1, nCols);
        for c = 1:nCols
            col = cols(c).data;
            if r <= numel(col)
                if isdatetime(col)
                    parts{c} = datestr(col(r), 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST>
                else
                    parts{c} = sprintf('%.10g', col(r));
                end
            else
                parts{c} = '';   % shorter column — leave blank, not NaN
            end
        end
        fprintf(fid, '%s\n', strjoin(parts, ','));
    end
end

function writeHeaderRow(fid, cells)
%WRITEHEADERROW  Join header cells with commas (CSV-escaping each) and write.
    fprintf(fid, '%s\n', strjoin(cellfun(@csvField, cells, 'UniformOutput', false), ','));
end

% ════════════════════════════════════════════════════════════════════════
%  Local helpers
% ════════════════════════════════════════════════════════════════════════

function col = newColumn(name, unit, tag, desig, data)
%NEWCOLUMN  Construct a column descriptor.  No arguments → empty 0x0 struct
%   array carrying the canonical field set (for accumulation).
    if nargin == 0
        col = struct('name', {}, 'unit', {}, 'tag', {}, 'desig', {}, 'data', {});
        return;
    end
    col = struct('name', name, 'unit', unit, 'tag', tag, 'desig', desig, 'data', data);
end

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function name = guiXName(d)
%GUIXNAME  X-axis long name from a data struct's metadata (mirrors the
%   guiXName helpers used across BosonPlotter).  Falls back to 'X'.
    name = 'X';
    if isfield(d, 'metadata') && isfield(d.metadata, 'xColumnName') && ...
       ~isempty(d.metadata.xColumnName)
        name = char(d.metadata.xColumnName);
    end
end

function u = guiXUnit(d)
%GUIXUNIT  X-axis unit from a data struct's metadata.  Falls back to ''.
    u = '';
    if isfield(d, 'metadata') && isfield(d.metadata, 'xColumnUnit') && ...
       ~isempty(d.metadata.xColumnUnit)
        u = char(d.metadata.xColumnUnit);
    end
end

function role = columnRole(lbl)
%COLUMNROLE  Origin column designation for a value column label.
%   uncertainty / error-like → 'yEr';  resolution / dQ → 'xEr' (X error);
%   everything else → 'Y'.  Matches saveConsolidatedNeutronCSV.columnRole so
%   the two reflectivity export paths agree on roles.
    l = lower(char(lbl));
    if any(strcmp(l, {'dr', 'di'})) || contains(l, {'uncert', 'err', 'std', 'sigma'})
        role = 'yEr';
    elseif contains(l, {'resolution', 'dq'})
        role = 'xEr';
    else
        role = 'Y';
    end
end

function s = csvField(s)
%CSVFIELD  Coerce a header cell to a single char row and quote it when it
%   contains a comma, quote, or newline (tags from legendName may contain
%   commas, which would otherwise shift every downstream column).
    if isstring(s) || iscell(s)
        s = char(join(string(s), ''));
    else
        s = char(s);
    end
    s = reshape(s, 1, []);
    if any(ismember(s, sprintf(',"\n\r')))
        s = ['"', strrep(s, '"', '""'), '"'];
    end
end
