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
        [allHdrs, allCols, desigs] = buildPolarizedColumns(collected, polOrder, polSuffix);
    else
        [allHdrs, allCols, desigs] = buildPerDatasetColumns(collected);
    end

    writeColumnsCSV(fp, fmt, allHdrs, allCols, desigs);
end

% ════════════════════════════════════════════════════════════════════════════
% Column builders
% ════════════════════════════════════════════════════════════════════════════

function [allHdrs, allCols, desigs] = buildPolarizedColumns(collected, polOrder, polSuffix)
%BUILDPOLARIZEDCOLUMNS  Shared-Q table with R/dR/theory per polarization plus
%   spin asymmetry.  Cross-sections are interpolated onto the first dataset's
%   Q grid (required so asymmetry can be computed point-by-point).

    % ── Build shared Q vector from first dataset ───────────────────────────
    src0 = guiTernary(~isempty(collected(1).ds.corrData), ...
                      collected(1).ds.corrData, collected(1).ds.data);
    Q = src0.time(:);
    nRows = numel(Q);

    % ── Determine Q unit ──────────────────────────────────────────────────
    qUnit = '';
    if isfield(src0.metadata, 'parserSpecific') && ...
       isfield(src0.metadata.parserSpecific, 'xUnit')
        qUnit = src0.metadata.parserSpecific.xUnit;
    end
    qHdr = guiTernary(~isempty(qUnit), sprintf('Q (%s)', qUnit), 'Q');

    % ── Collect columns per polarization ──────────────────────────────────
    allHdrs = {qHdr};
    allCols = {Q};
    hasPP = false; hasMM = false;
    RPP = []; RMM = []; dRPP = []; dRMM = []; thPP = []; thMM = [];

    for ci = 1:numel(collected)
        pol    = collected(ci).pol;
        dsi    = collected(ci).ds;
        src    = guiTernary(~isempty(dsi.corrData), dsi.corrData, dsi.data);
        pidx   = find(strcmp(polOrder, pol), 1);
        suffix = polSuffix{pidx};

        iR  = find(strcmp(src.labels, 'R'), 1);
        idR = find(strcmp(src.labels, 'dR'), 1);
        iTh = find(strcmp(src.labels, 'theory'), 1);

        % Interpolate onto shared Q grid if needed
        Qi = src.time(:);
        needInterp = numel(Qi) ~= nRows || any(abs(Qi - Q) > eps(Q)*10);

        if ~isempty(iR)
            Rcol = src.values(:, iR);
            if needInterp, Rcol = interp1(Qi, Rcol, Q, 'linear', NaN); end
            allHdrs{end+1} = sprintf('R_%s', suffix); %#ok<AGROW>
            allCols{end+1} = Rcol(:); %#ok<AGROW>
            if strcmp(pol, '++'), RPP = Rcol(:); hasPP = true; end
            if strcmp(pol, '--'), RMM = Rcol(:); hasMM = true; end
        end
        if ~isempty(idR)
            dRcol = src.values(:, idR);
            if needInterp, dRcol = interp1(Qi, dRcol, Q, 'linear', NaN); end
            allHdrs{end+1} = sprintf('dR_%s', suffix); %#ok<AGROW>
            allCols{end+1} = dRcol(:); %#ok<AGROW>
            if strcmp(pol, '++'), dRPP = dRcol(:); end
            if strcmp(pol, '--'), dRMM = dRcol(:); end
        end
        if ~isempty(iTh)
            thcol = src.values(:, iTh);
            if needInterp, thcol = interp1(Qi, thcol, Q, 'linear', NaN); end
            allHdrs{end+1} = sprintf('theory_%s', suffix); %#ok<AGROW>
            allCols{end+1} = thcol(:); %#ok<AGROW>
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
        allHdrs{end+1} = 'Asymmetry';
        allCols{end+1} = asymVal;

        % Propagated error: dA = 2/(R+++R--)^2 * sqrt((R--*dR++)^2 + (R++*dR--)^2)
        if ~isempty(dRPP) && ~isempty(dRMM)
            dAsym = NaN(nRows, 1);
            dAsym(valid) = 2 ./ sumR(valid).^2 .* ...
                sqrt((RMM(valid) .* dRPP(valid)).^2 + (RPP(valid) .* dRMM(valid)).^2);
            allHdrs{end+1} = 'dAsymmetry';
            allCols{end+1} = dAsym;
        end

        % Theory asymmetry
        if ~isempty(thPP) && ~isempty(thMM)
            validTh = thPP > 0 & thMM > 0 & ~isnan(thPP) & ~isnan(thMM);
            asymTh = NaN(nRows, 1);
            sumTh = thPP + thMM;
            asymTh(validTh) = (thPP(validTh) - thMM(validTh)) ./ sumTh(validTh);
            allHdrs{end+1} = 'Asymmetry_theory';
            allCols{end+1} = asymTh;
        end
    end

    desigs = buildColumnDesignations(allHdrs);
end

function [allHdrs, allCols, desigs] = buildPerDatasetColumns(collected)
%BUILDPERDATASETCOLUMNS  One Q + values block per dataset, each keeping its own
%   Q column.  No interpolation onto a shared grid — every scan's native
%   sampling is preserved.  Columns: Q [tag], <label> [tag], ... per dataset.
    allHdrs = {};
    allCols = {};
    desigs  = {};
    for ci = 1:numel(collected)
        dsi = collected(ci).ds;
        src = guiTernary(~isempty(dsi.corrData), dsi.corrData, dsi.data);
        tag = datasetTag(dsi);

        qUnit = '';
        if isfield(src, 'metadata') && isfield(src.metadata, 'parserSpecific') && ...
           isfield(src.metadata.parserSpecific, 'xUnit')
            qUnit = src.metadata.parserSpecific.xUnit;
        end
        allHdrs{end+1} = headerWithUnit('Q', tag, qUnit); %#ok<AGROW>
        allCols{end+1} = src.time(:);                      %#ok<AGROW>
        desigs{end+1}  = 'X';                              %#ok<AGROW>

        for li = 1:numel(src.labels)
            lbl = src.labels{li};
            u = '';
            if li <= numel(src.units), u = src.units{li}; end
            allHdrs{end+1} = headerWithUnit(lbl, tag, u); %#ok<AGROW>
            allCols{end+1} = src.values(:, li);            %#ok<AGROW>
            desigs{end+1}  = columnRole(lbl);              %#ok<AGROW>
        end
    end
end

% ════════════════════════════════════════════════════════════════════════════
% CSV writer
% ════════════════════════════════════════════════════════════════════════════

function writeColumnsCSV(fp, fmt, hdrs, cols, desigs)
%WRITECOLUMNSCSV  Write header(s) + numeric columns to fp.  Columns may have
%   different lengths (per-dataset blocks); shorter columns leave trailing
%   cells blank rather than printing NaN.  Origin format adds long-name / unit
%   / designation header rows.
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
    closeGuard = onCleanup(@() fclose(fid)); %#ok<NASGU>

    if strcmp(fmt, 'origin')
        longNames = cellfun(@(h) strtrim(regexprep(h, '\s*\([^)]+\)', '')), ...
                            hdrs, 'UniformOutput', false);
        units = cellfun(@extractUnitFromHeader, hdrs, 'UniformOutput', false);
        fprintf(fid, '%s\n', strjoin(longNames, ','));
        fprintf(fid, '%s\n', strjoin(units, ','));
        fprintf(fid, '%s\n', strjoin(desigs, ','));
    else
        fprintf(fid, '%s\n', strjoin(hdrs, ','));
    end

    nCols = numel(cols);
    maxRows = 0;
    for c = 1:nCols
        maxRows = max(maxRows, numel(cols{c}));
    end
    for r = 1:maxRows
        parts = cell(1, nCols);
        for c = 1:nCols
            col = cols{c};
            if r <= numel(col)
                parts{c} = sprintf('%.10g', col(r));
            else
                parts{c} = '';   % shorter column — leave blank, not NaN
            end
        end
        fprintf(fid, '%s\n', strjoin(parts, ','));
    end
end

% ════════════════════════════════════════════════════════════════════════════
% Local helpers (duplicated from BosonPlotter.m local function scope)
% ════════════════════════════════════════════════════════════════════════════

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

function tag = datasetTag(dsi)
%DATASETTAG  Short provenance label for a dataset: legend name or file name.
    if isfield(dsi, 'legendName') && ~isempty(dsi.legendName)
        tag = dsi.legendName;
    else
        [~, fn, fext] = fileparts(dsi.filepath);
        tag = [fn fext];
    end
end

function h = headerWithUnit(name, tag, unit)
%HEADERWITHUNIT  '<name> [<tag>]' with an optional ' (<unit>)' suffix.
    h = sprintf('%s [%s]', name, tag);
    if ~isempty(unit)
        h = sprintf('%s (%s)', h, unit);
    end
end

function role = columnRole(lbl)
%COLUMNROLE  Origin column designation for a value column label.
%   dR / error-like → 'yEr'; everything else → 'Y'.
    l = lower(lbl);
    if strcmp(l, 'dr') || contains(l, {'err', 'std', 'sigma'})
        role = 'yEr';
    else
        role = 'Y';
    end
end

function unit = extractUnitFromHeader(hdr)
%EXTRACTUNITFROMHEADER  Extract text inside parentheses from a header string.
%   'Moment (emu) [corr]' → 'emu';  'X [raw]' → ''
    tok = regexp(hdr, '\(([^)]+)\)', 'tokens', 'once');
    if ~isempty(tok)
        unit = tok{1};
    else
        unit = '';
    end
end

function desigs = buildColumnDesignations(hdrs)
%BUILDCOLUMNDESIGNATIONS  Map header names to Origin column designations.
%   First column → 'X'.  Headers containing error-like keywords → 'yEr'.
%   Any column named 'X [raw]' → 'X'.  All others → 'Y'.
    desigs = cell(size(hdrs));
    for k = 1:numel(hdrs)
        lbl = lower(hdrs{k});
        if k == 1 || startsWith(lbl, 'x ')
            desigs{k} = 'X';
        elseif contains(lbl, {'err', 'dr_', 'dr ', 'dasym', 'std', 'sigma'})
            desigs{k} = 'yEr';
        else
            desigs{k} = 'Y';
        end
    end
end
