function data = importAuto(filepath, varargin)
%IMPORTAUTO Auto-detect file type and import with the appropriate parser.
%
%   data = parser.importAuto('scan.raw')
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
%     .raw              → parser.importRigaku
%     .xlsx .xls .xlsm
%       .ods .xlsb      → parser.importExcel
%     .csv .tsv .txt    → parser.importCSV
%     .dat              → tries parser.importQDVSM ([Header]/[Data] format)
%                         falls back to parser.importPPMS (legacy CSV)
%
%   INPUTS:
%       filepath  - Path to the data file (string or char).
%       varargin  - Any name-value pairs accepted by the chosen parser.
%
%   OUTPUT:
%       data - Unified data struct (.time, .values, .labels, .units,
%              .metadata) as returned by the underlying parser.
%
%   EXAMPLES:
%       % Let importAuto pick the parser
%       d = parser.importAuto('EDP140_PerpStraw.dat');
%       d = parser.importAuto('scan.raw', 'UseCountsPerSec', false);
%       d = parser.importAuto('results.xlsx', 'Sheet', 2);
%
%       % Inspect the result
%       parser.importAuto('log.csv')
%
%   See also IMPORTCSV, IMPORTEXCEL, IMPORTPPMS, IMPORTQDVSM, IMPORTRIGAKU

    arguments
        filepath (1,1) string {mustBeFile}
    end
    arguments (Repeating)
        varargin
    end

    [~, ~, ext] = fileparts(filepath);
    ext = lower(ext);

    % ════════════════════════════════════════════════════════════════
    %  Dispatch by extension
    % ════════════════════════════════════════════════════════════════
    switch ext
        case '.raw'
            parserName = 'importRigaku';
            data = parser.importRigaku(filepath, varargin{:});

        case {'.xlsx', '.xls', '.xlsm', '.xlsb', '.ods'}
            parserName = 'importExcel';
            data = parser.importExcel(filepath, varargin{:});

        case {'.csv', '.tsv', '.txt'}
            parserName = 'importCSV';
            data = parser.importCSV(filepath, varargin{:});

        case '.dat'
            % Try QD VSM format first (has [Header]/[Data] markers)
            try
                data = parser.importQDVSM(filepath, 'Verbose', false, varargin{:});
                parserName = 'importQDVSM';
            catch ME
                if contains(ME.message, '[Data]', 'IgnoreCase', true)
                    % Not a QD file — fall back to legacy PPMS CSV
                    data = parser.importPPMS(filepath, varargin{:});
                    parserName = 'importPPMS';
                else
                    rethrow(ME);
                end
            end

        otherwise
            error('importAuto:unknownExtension', ...
                ['No parser registered for extension "%s".\n' ...
                 'Supported: .raw, .xlsx/.xls/.xlsm, .csv/.tsv/.txt, .dat'], ext);
    end

    % ════════════════════════════════════════════════════════════════
    %  Summary
    % ════════════════════════════════════════════════════════════════
    printSummary(data, parserName, filepath);
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
%RESOLVEXLABEL Extract a human-readable x-axis name from any parser's metadata.
    candidates = {'xColumnName', 'delimiter'};   % delimiter = importCSV marker
    for f = {'xColumnName'}
        if isfield(meta, f{1}) && ~isempty(meta.(f{1}))
            label = meta.(f{1});
            return;
        end
    end
    if isfield(meta, 'startAngle')   % importRigaku
        label = '2-Theta (deg)';
        return;
    end
    if isfield(meta, 'delimiter')    % importCSV — no explicit x label stored
        label = 'col 1';
        return;
    end
    if isfield(meta, 'sheetName')    % importExcel — no explicit x label
        label = 'col 1';
        return;
    end
    label = '';
end
