function saveConsolidatedNeutronCSV(activeDs, fp, fmt, datasets)
%SAVECONSOLIDATEDNEUTRONCSV  Write all polarization channels to one CSV.
%   Gathers loaded neutron datasets from the same measurement and writes
%   a single file with Q, R/dR/theory per polarization, plus spin asymmetry.
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

    % ── Build shared Q vector from first dataset ───────────────────────────
    src0 = guiTernary(~isempty(collected(1).ds.corrData), ...
                      collected(1).ds.corrData, collected(1).ds.data);
    Q = src0.time(:);
    nRows = numel(Q);

    % ── Determine Q unit ──────────────────────────────────────────────────
    qUnit = '';
    if isfield(src0, 'units') && ~isempty(src0.units)
        % X-axis unit is in metadata for neutron data
    end
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

    % ── Write CSV ──────────────────────────────────────────────────────────
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
    closeGuard = onCleanup(@() fclose(fid));

    if strcmp(fmt, 'origin')
        longNames = cellfun(@(h) strtrim(regexprep(h, '\s*\([^)]+\)', '')), ...
                            allHdrs, 'UniformOutput', false);
        units = cellfun(@extractUnitFromHeader, allHdrs, 'UniformOutput', false);
        desigs = buildColumnDesignations(allHdrs);
        fprintf(fid, '%s\n', strjoin(longNames, ','));
        fprintf(fid, '%s\n', strjoin(units, ','));
        fprintf(fid, '%s\n', strjoin(desigs, ','));
    else
        fprintf(fid, '%s\n', strjoin(allHdrs, ','));
    end
    nCols = numel(allCols);
    for r = 1:nRows
        fprintf(fid, '%.10g', allCols{1}(r));
        for c = 2:nCols
            fprintf(fid, ',%.10g', allCols{c}(r));
        end
        fprintf(fid, '\n');
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
