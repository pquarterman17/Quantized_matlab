function [data, parserName] = importAuto(filepath, varargin)
%IMPORTAUTO Auto-detect file type and import with the appropriate parser.
%
%   data = parser.importAuto('results.xlsx')
%   data = parser.importAuto('magnetometry.dat')
%   data = parser.importAuto('log.csv', 'TimeColumn', 1)
%
%   Inspects the file extension (and for .dat files, the content) to
%   choose the right parser automatically. Prints a formatted summary of
%   what was imported. Extra name-value pairs are forwarded to the
%   underlying parser unchanged.
%
%   DISPATCH RULES:
%     .xrdml            → parser.importXRDML
%     .brml             → parser.importBruker
%     .raw              → parser.importBruker (Bruker magic "RAW1.01")
%                         parser.importRigaku_raw (Rigaku magic "FI")
%     .xlsx .xls .xlsm
%       .ods .xlsb      → parser.importExcel
%     .csv .tsv .txt    → parser.importCSV
%     .refl             → parser.importNCNRRefl (NCNR reflectivity from reductus)
%     .pnr              → parser.importNCNRPNR (PNR polychromatic variants)
%     .data/.datb/
%       .datc/.datd     → parser.importNCNRDat (refl1d fit output, polarization-encoded)
%     .dat              → tries parser.importQDVSM ([Header]/[Data] format)
%                         falls back to parser.importPPMS (legacy CSV)
%
%   INPUTS:
%       filepath  - Path to the data file (string or char).
%       varargin  - Any name-value pairs accepted by the chosen parser.
%
%   OUTPUTS:
%       data       - Unified data struct (.time, .values, .labels, .units,
%                    .metadata) as returned by the underlying parser.
%       parserName - (optional) Name of the parser that was used, e.g.
%                    'importQDVSM', 'importNCNRRefl', 'importCSV'.
%
%   EXAMPLES:
%       % Let importAuto pick the parser
%       d = parser.importAuto('reflectivity.refl');
%       d = parser.importAuto('polarization.pnr');
%       d = parser.importAuto('results.xlsx', 'Sheet', 2);
%
%       % Inspect the result with verbose summary
%       parser.importAuto('log.csv', 'Verbose', true)
%
%   See also IMPORTNCNRREFL, IMPORTNCNRPNR, IMPORTNCNRDAT, IMPORTXRDML, IMPORTBRUKER, IMPORTRIGAKU_RAW, IMPORTCSV, IMPORTEXCEL, IMPORTPPMS, IMPORTQDVSM

    arguments
        filepath (1,1) string {mustBeFile}
    end
    arguments (Repeating)
        varargin
    end

    [~, ~, ext] = fileparts(filepath);
    ext = lower(ext);

    % Extract Verbose flag from varargin (default false — callers opt in)
    verbIdx = find(strcmpi(varargin(1:2:end), 'Verbose'), 1);
    if ~isempty(verbIdx)
        verboseFlag = varargin{verbIdx * 2};
    else
        verboseFlag = false;
    end

    % ════════════════════════════════════════════════════════════════
    %  Dispatch by extension (via centralized resolveParser)
    % ════════════════════════════════════════════════════════════════

    resolveResult = parser.resolveParser(filepath);
    parserName = resolveResult.name;

    % Dispatch to the primary parser
    parserFunc = str2func(['parser.' parserName]);
    try
        data = parserFunc(filepath, varargin{:});
    catch ME
        % For .dat files, try fallback parser if primary failed
        if ~isempty(resolveResult.fallback) && contains(ME.message, '[Data]', 'IgnoreCase', true)
            parserName = resolveResult.fallback;
            fallbackFunc = str2func(['parser.' parserName]);
            data = fallbackFunc(filepath, varargin{:});
        else
            rethrow(ME);
        end
    end

    % ════════════════════════════════════════════════════════════════
    %  Summary (opt-in via 'Verbose', true)
    % ════════════════════════════════════════════════════════════════
    if verboseFlag
        printSummary(data, parserName, filepath);
    end
end


% ────────────────────────────────────────────────────────────────────
function printSummary(data, parserName, filepath)
    SEP = repmat('-', 1, 55);
    [~, fname, ext] = fileparts(filepath);
    fprintf('\n%s\n', SEP);
    fprintf('  importAuto -> %s\n', parserName);
    fprintf('  File : %s%s\n', fname, ext);
    fprintf('%s\n', SEP);
    fprintf('  Rows     : %d\n', numel(data.time));
    fprintf('  Channels : %d\n', size(data.values, 2));
    fprintf('%s\n', SEP);

    % X-axis label — check several metadata field names
    xLabel = resolveXLabel(data.metadata);

    % X-axis summary
    if isdatetime(data.time)
        tMin = datestr(min(data.time), 'yyyy-mm-dd HH:MM');
        tMax = datestr(max(data.time), 'yyyy-mm-dd HH:MM');
        fprintf('  X : (datetime)  %s  to  %s\n', tMin, tMax);
    else
        xRange = [min(data.time), max(data.time)];
        fprintf('  X : %-20s  [%.4g, %.4g]\n', xLabel, xRange(1), xRange(2));
    end

    % Y-axis channels
    for k = 1:size(data.values, 2)
        col = data.values(:, k);
        unitStr = '';
        if ~isempty(data.units{k})
            unitStr = sprintf(' (%s)', data.units{k});
        end
        tag = [data.labels{k}, unitStr];
        validVals = col(~isnan(col));
        if isempty(validVals)
            fprintf('  Y%-2d: %-26s  (all NaN)\n', k, tag);
        else
            fprintf('  Y%-2d: %-26s  [%.4g, %.4g]\n', k, tag, ...
                min(validVals), max(validVals));
        end
    end

    fprintf('%s\n\n', SEP);
end


function label = resolveXLabel(meta)
%RESOLVEXLABEL Extract a human-readable x-axis name from unified metadata.
%   All parsers now set meta.xColumnName directly.
    if isfield(meta, 'xColumnName') && ~isempty(meta.xColumnName)
        label = meta.xColumnName;
    else
        label = '';
    end
end


function magic = readFileMagic(filepath, nBytes)
%READFILEMAGIC  Read the first nBytes from filepath as characters.
%   Returns a char array of length nBytes (padded with nulls if file is shorter).
    try
        fid = fopen(filepath, 'r');
        if fid == -1
            magic = char(zeros(1, nBytes));
            return;
        end
        cleanObj = onCleanup(@() fclose(fid));
        raw = fread(fid, nBytes, '*uint8');
        magic = char(raw(:)');
    catch
        magic = char(zeros(1, nBytes));
    end
end
