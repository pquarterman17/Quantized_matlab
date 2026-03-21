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
%       result   - Struct with .name, .fallback, .isBrukerRaw fields
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
            % QD VSM/PPMS: try primary (.qd format with [Header]/[Data] markers)
            % and fallback to legacy PPMS CSV format
            result.name     = 'importQDVSM';
            result.fallback = 'importPPMS';

        otherwise
            error('parser:resolveParser:unknownExtension', ...
                ['No parser registered for extension "%s".\n' ...
                 'Supported: .xrdml, .brml, .raw, .tif/.tiff, ' ...
                 '.jpg/.jpeg/.png/.bmp/.gif, .bcf, .dm3/.dm4, ' ...
                 '.ser, .mrc/.mrcs, ' ...
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
function tf = looksLikeSIMSExcel(filepath)
%LOOKSSLIMSIMEXCEL  Quick content scan: does an Excel file look like SIMS data?
%   Reads the first 15 rows of the first sheet and checks for:
%     (a) Vendor signature: "Evans Analytical", "EAG", "SIMS" in early rows
%     (b) Repeated "Depth" + "CONC" column pairs (≥3 pairs) in any row
    tf = false;
    try
        raw = readcell(filepath, 'Range', '1:15');
    catch
        return;
    end
    if isempty(raw), return; end

    % Flatten all text content from the first 15 rows
    allText = '';
    [nR, nC] = size(raw);
    for r = 1:nR
        for c = 1:nC
            v = raw{r, c};
            if ischar(v)
                allText = [allText, ' ', v]; %#ok<AGROW>
            elseif isstring(v)
                allText = [allText, ' ', char(v)]; %#ok<AGROW>
            end
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
            v = raw{r, c};
            if ischar(v)
                rowText = [rowText, ' ', v]; %#ok<AGROW>
            elseif isstring(v)
                rowText = [rowText, ' ', char(v)]; %#ok<AGROW>
            end
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
