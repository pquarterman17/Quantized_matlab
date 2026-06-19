function saveConsolidatedNeutronCSV(activeDs, fp, fmt, datasets)
%SAVECONSOLIDATEDNEUTRONCSV  Write neutron reflectometry datasets to one CSV.
%   Gathers loaded neutron datasets from the same measurement and writes one
%   file.  The layout depends on whether the data is genuinely polarized:
%
%     * Polarized (>=2 distinct polarizations of one measurement): a single
%       shared-Q table with R/dR/theory per polarization plus spin asymmetry.
%       Cross-sections are interpolated onto a common Q grid so the asymmetry
%       can be computed point-by-point.
%
%     * Unpolarized / independent scans (0 or 1 distinct polarization — e.g.
%       XRR .refl): per-dataset blocks, each scan keeping its OWN Q column
%       followed by its R/dR/theory.  No interpolation, so the raw sampling
%       of every scan is preserved (no shared-grid resampling).
%
%   Header format
%     'standard' (default) — one header row of '<Long Name> (<unit>)'.  The
%        source file is NOT crammed into the header (it lives in the file name
%        and, for multi-scan files, in the Origin header below).
%     'origin' — four header rows so nothing is stuffed into one line:
%        Row 1  Long Name  (clean column name, no units / no file tag)
%        Row 2  Units
%        Row 3  File Name  (source file for that column; blank for derived
%               columns such as Asymmetry)
%        Row 4  Comments   (Origin column designation: X / Y / yEr / xEr)
%
% Syntax
%   bosonPlotter.saveConsolidatedNeutronCSV(activeDs, fp, fmt, datasets)
%
% Inputs
%   activeDs  - active dataset struct (provides the measurement base name)
%   fp        - output file path (char)
%   fmt       - 'standard' (default) or 'origin' (multi-row Origin headers)
%   datasets  - cell array of all loaded dataset structs (appData.datasets)

    if nargin < 3 || isempty(fmt), fmt = 'standard'; end

    % ── Polarization suffix map ────────────────────────────────────────────
    polOrder   = {'++', '+-', '-+', '--', ''};
    polSuffix  = {'pp', 'pm', 'mp', 'mm', 'unpol'};

    % ── Gather datasets from the same measurement ──────────────────────────
    baseName = neutronBaseName(activeDs.filepath);
    nDS = numel(datasets);
    collected = struct('ds', {}, 'pol', {}, 'sortKey', {});

    for di = 1:nDS
        dsi = datasets{di};
        if ~isfield(dsi, 'parserName') || ~isNeutronParser(dsi.parserName)
            continue;
        end
        if ~strcmp(neutronBaseName(dsi.filepath), baseName)
            continue;
        end
        pol = '';
        if isfield(dsi.data.metadata, 'parserSpecific') && ...
           isfield(dsi.data.metadata.parserSpecific, 'polarization')
            pol = dsi.data.metadata.parserSpecific.polarization;
        end
        idx = find(strcmp(polOrder, pol), 1);
        if isempty(idx), idx = numel(polOrder); end
        entry.ds      = dsi;
        entry.pol     = pol;
        entry.sortKey = idx;
        collected(end+1) = entry; %#ok<AGROW>
    end

    if isempty(collected)
        error('saveConsolidatedNeutronCSV:noData', ...
            'No neutron datasets found for measurement "%s".', baseName);
    end

    % Sort by canonical polarization order
    [~, si] = sort([collected.sortKey]);
    collected = collected(si);

    % ── Choose layout ──────────────────────────────────────────────────────
    % Genuine polarized measurement = at least two distinct, non-empty
    % polarization states.  Everything else (single channel, or several
    % unpolarized/independent scans) uses per-dataset blocks.
    pols = {collected.pol};
    distinctPols = unique(pols(~cellfun(@isempty, pols)));
    if numel(distinctPols) >= 2
        cols = buildPolarizedColumns(collected, polOrder, polSuffix);
    else
        cols = buildPerDatasetColumns(collected);
    end

    writeColumnsCSV(fp, fmt, cols);
end

% ════════════════════════════════════════════════════════════════════════════
% Column builders
% ════════════════════════════════════════════════════════════════════════════
%
% Both builders return a struct array of columns with fields:
%   .name   long name (clean, no units, no file tag)
%   .unit   unit string ('' if none)
%   .file   source file name ('' for derived columns)
%   .desig  Origin column designation ('X' / 'Y' / 'yEr' / 'xEr')
%   .data   numeric column vector

function cols = buildPolarizedColumns(collected, polOrder, polSuffix)
%BUILDPOLARIZEDCOLUMNS  Shared-Q table with R/dR/theory per polarization plus
%   spin asymmetry.  Cross-sections are interpolated onto the first dataset's
%   Q grid (required so asymmetry can be computed point-by-point).

    % ── Build shared Q vector from first dataset ───────────────────────────
    src0 = guiTernary(~isempty(collected(1).ds.corrData), ...
                      collected(1).ds.corrData, collected(1).ds.data);
    Q = src0.time(:);
    nRows = numel(Q);
    qUnit = resolveXUnit(src0);
    qFile = datasetFileName(collected(1).ds);

    cols = newColumn('Q', qUnit, qFile, 'X', Q);

    hasPP = false; hasMM = false;
    RPP = []; RMM = []; dRPP = []; dRMM = []; thPP = []; thMM = [];

    for ci = 1:numel(collected)
        pol    = collected(ci).pol;
        dsi    = collected(ci).ds;
        src    = guiTernary(~isempty(dsi.corrData), dsi.corrData, dsi.data);
        pidx   = find(strcmp(polOrder, pol), 1);
        suffix = polSuffix{pidx};
        file   = datasetFileName(dsi);

        iR  = find(strcmp(src.labels, 'R'), 1);
        idR = find(strcmp(src.labels, 'dR'), 1);
        iTh = find(strcmp(src.labels, 'theory'), 1);

        % Interpolate onto shared Q grid if needed
        Qi = src.time(:);
        needInterp = numel(Qi) ~= nRows || any(abs(Qi - Q) > eps(Q)*10);

        if ~isempty(iR)
            Rcol = src.values(:, iR);
            if needInterp, Rcol = interp1(Qi, Rcol, Q, 'linear', NaN); end
            cols(end+1) = newColumn(sprintf('R_%s', suffix), '', file, 'Y', Rcol(:)); %#ok<AGROW>
            if strcmp(pol, '++'), RPP = Rcol(:); hasPP = true; end
            if strcmp(pol, '--'), RMM = Rcol(:); hasMM = true; end
        end
        if ~isempty(idR)
            dRcol = src.values(:, idR);
            if needInterp, dRcol = interp1(Qi, dRcol, Q, 'linear', NaN); end
            cols(end+1) = newColumn(sprintf('dR_%s', suffix), '', file, 'yEr', dRcol(:)); %#ok<AGROW>
            if strcmp(pol, '++'), dRPP = dRcol(:); end
            if strcmp(pol, '--'), dRMM = dRcol(:); end
        end
        if ~isempty(iTh)
            thcol = src.values(:, iTh);
            if needInterp, thcol = interp1(Qi, thcol, Q, 'linear', NaN); end
            cols(end+1) = newColumn(sprintf('theory_%s', suffix), '', file, 'Y', thcol(:)); %#ok<AGROW>
            if strcmp(pol, '++'), thPP = thcol(:); end
            if strcmp(pol, '--'), thMM = thcol(:); end
        end
    end

    % ── Spin asymmetry (++ and -- present) ────────────────────────────────
    if hasPP && hasMM
        valid = RPP > 0 & RMM > 0 & ~isnan(RPP) & ~isnan(RMM);
        asymVal = NaN(nRows, 1);
        sumR = RPP + RMM;
        asymVal(valid) = (RPP(valid) - RMM(valid)) ./ sumR(valid);
        cols(end+1) = newColumn('Asymmetry', '', '', 'Y', asymVal);

        % Propagated error: dA = 2/(R+++R--)^2 * sqrt((R--*dR++)^2 + (R++*dR--)^2)
        if ~isempty(dRPP) && ~isempty(dRMM)
            dAsym = NaN(nRows, 1);
            dAsym(valid) = 2 ./ sumR(valid).^2 .* ...
                sqrt((RMM(valid) .* dRPP(valid)).^2 + (RPP(valid) .* dRMM(valid)).^2);
            cols(end+1) = newColumn('dAsymmetry', '', '', 'yEr', dAsym);
        end

        % Theory asymmetry
        if ~isempty(thPP) && ~isempty(thMM)
            validTh = thPP > 0 & thMM > 0 & ~isnan(thPP) & ~isnan(thMM);
            asymTh = NaN(nRows, 1);
            sumTh = thPP + thMM;
            asymTh(validTh) = (thPP(validTh) - thMM(validTh)) ./ sumTh(validTh);
            cols(end+1) = newColumn('Asymmetry_theory', '', '', 'Y', asymTh);
        end
    end
end

function cols = buildPerDatasetColumns(collected)
%BUILDPERDATASETCOLUMNS  One Q + values block per dataset, each keeping its own
%   Q column.  No interpolation onto a shared grid — every scan's native
%   sampling is preserved.
    cols = newColumn();   % empty 0x0 struct array with the right fields
    for ci = 1:numel(collected)
        dsi  = collected(ci).ds;
        src  = guiTernary(~isempty(dsi.corrData), dsi.corrData, dsi.data);
        file = datasetFileName(dsi);

        cols(end+1) = newColumn('Q', resolveXUnit(src), file, 'X', src.time(:)); %#ok<AGROW>

        for li = 1:numel(src.labels)
            lbl = src.labels{li};
            u = '';
            if li <= numel(src.units), u = src.units{li}; end
            cols(end+1) = newColumn(lbl, u, file, columnRole(lbl), src.values(:, li)); %#ok<AGROW>
        end
    end
end

% ════════════════════════════════════════════════════════════════════════════
% CSV writer
% ════════════════════════════════════════════════════════════════════════════

function writeColumnsCSV(fp, fmt, cols)
%WRITECOLUMNSCSV  Write header(s) + numeric columns to fp.  Columns may have
%   different lengths (per-dataset blocks); shorter columns leave trailing
%   cells blank rather than printing NaN.
%
%   'origin' writes four header rows (Long Name / Units / File Name /
%   Comments); 'standard' writes a single '<name> (<unit>)' row.
    dirPart = fileparts(fp);
    if ~isempty(dirPart) && ~isfolder(dirPart)
        error('saveConsolidatedNeutronCSV:badDir', ...
            'Output directory does not exist:\n%s', dirPart);
    end
    fid = fopen(fp, 'w');
    if fid < 0
        error('saveConsolidatedNeutronCSV:cannotOpen', ...
            'Cannot open file for writing:\n%s', fp);
    end
    closeGuard = onCleanup(@() fclose(fid));   % closes fid on any exit path

    names = {cols.name};
    units = {cols.unit};
    files = {cols.file};
    desig = {cols.desig};

    if strcmp(fmt, 'origin')
        writeHeaderRow(fid, names);   % Long Name
        writeHeaderRow(fid, units);   % Units
        writeHeaderRow(fid, files);   % File Name
        writeHeaderRow(fid, desig);   % Comments (Origin column designation)
    else
        hdr = cell(1, numel(names));
        for k = 1:numel(names)
            if ~isempty(units{k})
                hdr{k} = sprintf('%s (%s)', names{k}, units{k});
            else
                hdr{k} = names{k};
            end
        end
        writeHeaderRow(fid, hdr);
    end

    nCols = numel(cols);
    maxRows = 0;
    for c = 1:nCols
        maxRows = max(maxRows, numel(cols(c).data));
    end
    for r = 1:maxRows
        parts = cell(1, nCols);
        for c = 1:nCols
            col = cols(c).data;
            if r <= numel(col)
                parts{c} = sprintf('%.10g', col(r));
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

% ════════════════════════════════════════════════════════════════════════════
% Local helpers
% ════════════════════════════════════════════════════════════════════════════

function col = newColumn(name, unit, file, desig, data)
%NEWCOLUMN  Construct a column descriptor struct.  With no arguments returns an
%   empty 0x0 struct array carrying the canonical field set (for accumulation).
    if nargin == 0
        col = struct('name', {}, 'unit', {}, 'file', {}, 'desig', {}, 'data', {});
        return;
    end
    col = struct('name', name, 'unit', unit, 'file', file, 'desig', desig, 'data', data);
end

function v = guiTernary(cond, a, b)
    if cond, v = a; else, v = b; end
end

function tf = isNeutronParser(pName)
%ISNEUTRONPARSER  True when pName is an NCNR neutron reflectometry parser.
    tf = ismember(pName, {'importNCNRDat', 'importNCNRRefl', 'importNCNRPNR'});
end

function baseName = neutronBaseName(filepath)
%NEUTRONBASENAME  Strip polarization suffixes to get the measurement base name.
%   Removes [_-](refl|pnr), [_-](NSF|SF), and trailing [_-][a-z] so that
%   all cross-sections from one measurement share the same base name.
%   Handles both dash and underscore separators.
    [~, fn, ~] = fileparts(filepath);
    fn = regexprep(fn, '[_-](refl|pnr)$', '', 'ignorecase');
    fn = regexprep(fn, '[_-](NSF|SF)$',   '', 'ignorecase');
    fn = regexprep(fn, '[_-][a-z]$',       '', 'ignorecase');
    baseName = fn;
end

function nm = datasetFileName(dsi)
%DATASETFILENAME  Source file name (with extension) for a dataset.  Falls back
%   to the legend name, then a generic label, when no file path is present.
    nm = '';
    if isfield(dsi, 'filepath') && ~isempty(dsi.filepath)
        [~, fn, fext] = fileparts(char(dsi.filepath));   % char(): tolerate string paths
        nm = [fn, fext];
    end
    if isempty(nm) && isfield(dsi, 'legendName') && ~isempty(dsi.legendName)
        nm = char(dsi.legendName);
    end
    if isempty(nm)
        nm = 'dataset';
    end
end

function u = resolveXUnit(src)
%RESOLVEXUNIT  X-axis unit from a data struct's metadata.  Prefers the
%   parser-specific xUnit, then the canonical xColumnUnit field.
    u = '';
    if ~isfield(src, 'metadata'), return; end
    m = src.metadata;
    if isfield(m, 'parserSpecific') && isfield(m.parserSpecific, 'xUnit') && ...
       ~isempty(m.parserSpecific.xUnit)
        u = char(m.parserSpecific.xUnit);
    elseif isfield(m, 'xColumnUnit') && ~isempty(m.xColumnUnit)
        u = char(m.xColumnUnit);
    end
end

function role = columnRole(lbl)
%COLUMNROLE  Origin column designation for a value column label.
%   uncertainty / error-like → 'yEr';  resolution / dQ → 'xEr' (X error);
%   everything else → 'Y'.
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
%   contains a comma, quote, or newline.  Flattens string arrays (e.g. a
%   stray ["a" "b"]) to one row so strjoin never sees a multi-row char block.
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
