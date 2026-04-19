function result = resolveParser(filepath)
%RESOLVEPARSER  Centralized dispatcher: extension → parser name + metadata.
%
%   result = parser.resolveParser('scan.raw')
%   result = parser.resolveParser('sample.dat')
%   result = parser.resolveParser('image.tif')
%
%   Inspects file extension (and for .raw/.dat, the content) to determine
%   which parser should handle the file. Returns a struct with:
%
%       .name        - Parser function name (string): 'importXRDML', 'importTIFF', etc.
%       .fallback    - Fallback parser name ('' if none). For .dat: 'importPPMS'
%       .isBrukerRaw - Logical: true if .raw file has Bruker magic ('RAW1.01')
%
%   This function centralizes dispatch logic so importAuto.m and guiImport()
%   both use the same source of truth for extension→parser mapping.
%
%   INPUTS:
%       filepath - Path to the data file (string or char)
%
%   OUTPUT:
%       result   - Struct with fields:
%                    .name        (char) Parser function name to call, e.g.
%                                 'importXRDML', 'importQDVSM', 'importTIFF'.
%                                 Empty string if no parser is registered.
%                    .fallback    (char) Name of a secondary parser to try if
%                                 the primary fails. Non-empty only for .dat
%                                 files (primary: 'importQDVSM', fallback:
%                                 'importPPMS'). Empty string otherwise.
%                    .isBrukerRaw (logical) true only when the file is a .raw
%                                 file whose first 3 bytes are 'RAW' (Bruker
%                                 format). Used by importAuto to select the
%                                 correct Bruker code path.
%
%   EXAMPLES:
%       res = parser.resolveParser('scan.raw');
%       if res.isBrukerRaw
%           data = parser.(res.name)(filepath);  % Call Bruker
%       end
%
%       res = parser.resolveParser('sample.dat');
%       % res.name = 'importQDVSM', res.fallback = 'importPPMS'
%
%       res = parser.resolveParser('image.tif');
%       % res.name = 'importTIFF'
%
%   See also IMPORTAUTO, IMPORTTIFF, GUIIMPORT

    arguments
        filepath (1,1) string {mustBeFile}
    end

    [~, ~, ext] = fileparts(filepath);
    ext = lower(ext);

    % Default output
    result.name       = '';
    result.fallback   = '';
    result.isBrukerRaw = false;

    % ════════════════════════════════════════════════════════════════
    %  Dispatch by extension
    % ════════════════════════════════════════════════════════════════

    switch ext
        case '.xrdml'
            result.name = 'importXRDML';

        case '.brml'
            result.name = 'importBruker';

        case '.raw'
            % Magic-byte detection: first 7 bytes tell us the XRD format.
            % Bruker: magic 'RAW1.01' (first 3 bytes 'RAW')
            % Rigaku: magic 'FI'
            % Anything else is likely a headerless EM/instrument binary — not
            % auto-dispatchable because dimensions are unknown.
            magic = readFileMagic(filepath, 7);
            if strncmp(magic, 'RAW', 3)
                result.name        = 'importBruker';
                result.isBrukerRaw = true;
            elseif strncmp(magic, 'FI', 2)
                result.name        = 'importRigaku_raw';
                result.isBrukerRaw = false;
            else
                error('parser:resolveParser:unknownRaw', ...
                    ['Unrecognized .raw file: "%s".\n' ...
                     'This file does not match known XRD magic bytes ' ...
                     '(Bruker ''RAW1.01'' or Rigaku ''FI'').\n' ...
                     'If this is a headerless binary image, use:\n' ...
                     '  parser.importRawImage(filepath, Width=W, Height=H, BitDepth=B)'], ...
                    filepath);
            end

        case {'.tif', '.tiff'}
            result.name = 'importTIFF';

        case {'.jpg', '.jpeg', '.png', '.bmp', '.gif'}
            result.name = 'importImage';

        case '.bcf'
            result.name = 'importBCF';

        case '.dm3'
            result.name = 'importDM3';

        case '.dm4'
            result.name = 'importDM4';

        case '.ser'
            result.name = 'importSER';

        case {'.mrc', '.mrcs'}
            result.name = 'importMRC';

        case {'.spm', '.000', '.001', '.002', '.003'}
            result.name = 'importAFM';

        case {'.xlsx', '.xls', '.xlsm', '.xlsb', '.ods'}
            if looksLikeSIMSExcel(filepath)
                result.name = 'importSIMS';
            else
                result.name = 'importExcel';
            end

        case {'.csv', '.tsv', '.txt'}
            % Check for SIMS paired-column layout before falling back to CSV
            if looksLikeSIMS(filepath)
                result.name = 'importSIMS';
            else
                result.name = 'importCSV';
            end

        case '.refl'
            result.name = 'importNCNRRefl';

        case '.pnr'
            result.name = 'importNCNRPNR';

        case {'.data', '.datb', '.datc', '.datd'}
            result.name = 'importNCNRDat';

        case '.dat'
            % .dat is an overloaded extension. Quantum Design instruments
            % (VSM, PPMS, MPMS) emit files with a [Header]/[Data] block
            % marker; Lake Shore magnetometers emit a very different
            % layout with per-instrument model-number + "Lake Shore" in
            % the header. Content-sniff to pick the right parser.
            if looksLikeLakeShore(filepath)
                result.name = 'importLakeShore';
            elseif looksLikeMPMS(filepath)
                % MPMS SQUID header marker ("BYAPP,SQUID" in recent
                % software versions, or "SQUID" / "MPMS" vendor strings).
                % Route to importMPMS so the MPMS-specific defaults
                % (temperature x-axis, DC moment y-axis) apply; fall
                % back to PPMS legacy CSV if the QD block is malformed.
                result.name     = 'importMPMS';
                result.fallback = 'importPPMS';
            else
                % Default: QD VSM primary, fall back to legacy PPMS CSV.
                result.name     = 'importQDVSM';
                result.fallback = 'importPPMS';
            end

        otherwise
            error('parser:resolveParser:unknownExtension', ...
                ['No parser registered for extension "%s".\n' ...
                 'Supported: .xrdml, .brml, .raw, .tif/.tiff, ' ...
                 '.jpg/.jpeg/.png/.bmp/.gif, .bcf, .dm3/.dm4, ' ...
                 '.ser, .mrc/.mrcs, .spm/.000/.001 (AFM), ' ...
                 '.xlsx/.xls/.xlsm/.xlsb/.ods, .csv/.tsv/.txt, ' ...
                 '.refl, .pnr, .datA/B/C/D, .dat\n' ...
                 'For headerless binary images use parser.importRawImage directly.'], ext);
    end
end


% ────────────────────────────────────────────────────────────────────
function tf = looksLikeSIMS(filepath)
%LOOKSSLIMSIMS  Quick content scan: does a CSV look like SIMS paired-column data?
%   Checks the first 20 lines for either:
%     (a) A vendor signature: "Eurofins", "EAG", "SIMS" in the first few rows
%     (b) A header row with repeated "Depth"+"CONC" column pairs (≥3 pairs)
    tf = false;
    try
        fid = fopen(filepath, 'r');
        if fid == -1, return; end
        cleanObj = onCleanup(@() fclose(fid));
        lines = cell(1, 20);
        for i = 1:20
            ln = fgetl(fid);
            if ~ischar(ln), break; end
            lines{i} = ln;
        end
    catch
        return;
    end

    allText = strjoin(lines(~cellfun(@isempty, lines)), ' ');
    allLower = lower(allText);

    % (a) Vendor signature check
    if contains(allLower, 'sims') || ...
       (contains(allLower, 'eurofins') && contains(allLower, 'eag'))
        tf = true;
        return;
    end

    % (b) Repeated Depth + CONC column pairs in any single line
    for i = 1:numel(lines)
        if isempty(lines{i}), continue; end
        ln = lower(lines{i});
        nDepth = numel(regexp(ln, '\bdepth\b'));
        nConc  = numel(regexp(ln, '\bconc'));
        if nDepth >= 3 && nConc >= 3
            tf = true;
            return;
        end
    end
end


% ────────────────────────────────────────────────────────────────────
function tf = looksLikeLakeShore(filepath)
%LOOKSSLIKELAKESHORE  Quick content scan for a Lake Shore magnetometer file.
%   Reads the first ~20 lines and looks for Lake Shore vendor signatures
%   (brand string, classic instrument model numbers 7400-series or
%   8600-series VSMs). Returns true when any of those appear.
    tf = false;
    try
        fid = fopen(filepath, 'r');
        if fid == -1, return; end
        cleanObj = onCleanup(@() fclose(fid));
        lines = cell(1, 20);
        for i = 1:20
            ln = fgetl(fid);
            if ~ischar(ln), break; end
            lines{i} = ln;
        end
    catch
        return;
    end

    % Bail early if the first non-empty line is '[Header]' — that's the
    % Quantum Design QD-format marker and takes priority regardless of
    % any later content.
    for i = 1:numel(lines)
        ln = strtrim(lines{i});
        if isempty(ln), continue; end
        if strcmpi(ln, '[Header]')
            return;   % QD format; not Lake Shore
        end
        break;
    end

    allLower = lower(strjoin(lines(~cellfun(@isempty, lines)), ' '));
    if contains(allLower, 'lake shore') || contains(allLower, 'lakeshore') ...
            || ~isempty(regexp(allLower, 'model\s*7[34]\d\d\b', 'once')) ...
            || ~isempty(regexp(allLower, 'model\s*86\d\d\b', 'once'))
        tf = true;
    end
end


% ────────────────────────────────────────────────────────────────────
function tf = looksLikeMPMS(filepath)
%LOOKSSLIKEMPMS  Quick content scan for a Quantum Design MPMS SQUID file.
%   MPMS .dat files share the QD [Header]/[Data] layout with VSM/PPMS
%   but are disambiguated by vendor strings naming the SQUID software
%   in the header block. The marker observed on recent MPMS firmware is
%   "BYAPP,SQUID" (e.g. "BYAPP,SQUID AC,0.9.1.0"); we also match bare
%   "SQUID" or "MPMS" anywhere in the first ~40 header lines. QDVSM and
%   PPMS files do not contain these markers.
    tf = false;
    try
        fid = fopen(filepath, 'r');
        if fid == -1, return; end
        cleanObj = onCleanup(@() fclose(fid));
        lines = cell(1, 40);
        for i = 1:40
            ln = fgetl(fid);
            if ~ischar(ln), break; end
            lines{i} = ln;
            % Stop scanning once we reach the data block — MPMS markers
            % only appear in the header, and comma-separated data rows
            % can legitimately contain the substring "MPMS" as part of
            % a user-chosen sample ID.
            if ~isempty(strtrim(ln)) && strcmpi(strtrim(ln), '[Data]')
                break;
            end
        end
    catch
        return;
    end

    headerText = lower(strjoin(lines(~cellfun(@isempty, lines)), ' '));
    if contains(headerText, 'byapp,squid') ...
            || ~isempty(regexp(headerText, '\bsquid\b', 'once')) ...
            || ~isempty(regexp(headerText, '\bmpms\b', 'once'))
        tf = true;
    end
end


% ────────────────────────────────────────────────────────────────────
function tf = looksLikeSIMSExcel(filepath)
%LOOKSSLIMSIMEXCEL  Quick content scan: does an Excel file look like SIMS data?
%   Reads the first 15 rows of the first sheet and checks for:
%     (a) Vendor signature: "Evans Analytical", "EAG", "SIMS" in early rows
%     (b) Repeated "Depth" + "CONC" column pairs (≥3 pairs) in any row
    tf = false;

    % Try readcell with explicit range first; fall back to full read if
    % the row-range syntax fails (MATLAB version-dependent).
    raw = {};
    try
        raw = readcell(filepath, 'Range', '1:15');
    catch
        try
            rawFull = readcell(filepath);
            nRows = min(15, size(rawFull, 1));
            raw = rawFull(1:nRows, :);
        catch
            return;
        end
    end
    if isempty(raw), return; end

    tf = checkSIMSContent(raw);
end


function tf = checkSIMSContent(raw)
%CHECKSIMSCONTENT  Check cell array rows for SIMS vendor signatures or
%   repeated Depth/CONC column pairs.
    tf = false;
    [nR, nC] = size(raw);

    % Flatten all text content
    allText = '';
    for r = 1:nR
        for c = 1:nC
            allText = [allText, ' ', cellToText(raw{r, c})]; %#ok<AGROW>
        end
    end
    allLower = lower(allText);

    % (a) Vendor signature check
    if contains(allLower, 'sims') || ...
       contains(allLower, 'evans analytical') || ...
       (contains(allLower, 'eurofins') && contains(allLower, 'eag'))
        tf = true;
        return;
    end

    % (b) Repeated Depth + CONC pairs in any single row
    for r = 1:nR
        rowText = '';
        for c = 1:nC
            rowText = [rowText, ' ', cellToText(raw{r, c})]; %#ok<AGROW>
        end
        rowLower = lower(rowText);
        nDepth = numel(regexp(rowLower, '\bdepth\b'));
        nConc  = numel(regexp(rowLower, '\bconc'));
        if nDepth >= 3 && nConc >= 3
            tf = true;
            return;
        end
    end
end


function s = cellToText(v)
%CELLTOTEXT  Convert a readcell value to char for text scanning.
    if ischar(v)
        s = v;
    elseif isstring(v)
        if ismissing(v)
            s = '';
        else
            s = char(v);
        end
    else
        s = '';
    end
end


% ────────────────────────────────────────────────────────────────────
function magic = readFileMagic(filepath, nBytes)
%READFILEMAGIC  Read first N bytes of file and return as char array.
    try
        fid = fopen(filepath, 'r');
        if fid == -1
            magic = '';
            return
        end
        cleanObj = onCleanup(@() fclose(fid));
        raw = fread(fid, nBytes, '*uint8');
        magic = char(raw');
    catch
        magic = '';
    end
end
