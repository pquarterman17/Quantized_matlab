function data = importNCNRPNR(filepath, options)
%IMPORTNCNRPNR Import NCNR PNR (Polarized Neutron Reflectometry) .pnr files.
%
%   data = importNCNRPNR('sample_NSF.pnr')
%   data = importNCNRPNR('sample_SF.pnr')
%
%   Reads polarized neutron reflectivity data in tab-delimited format with
%   two header rows. Supports NSF (non-spin-flip), SF (spin-flip), and
%   combined variants.
%
%   FILE FORMAT:
%     Row 1: Q  dQ  R++  dR++  R--  dR--  T++  T--   (column names, tab-delimited)
%     Row 2: A-1 A-1 arb. units ... (units, tab-delimited)
%     Rows 3+: [numeric tab-delimited data]
%
%   NSF variant: R++/dR++, R--/dR--, T++/T--
%   SF variant:  R+-/dR+-, R-+/dR-+, T+-/T-+
%
%   OUTPUT:
%       data - Unified data struct with fields:
%           .time    - Q values [Nx1]
%           .values  - [NxM] array of remaining columns
%           .labels  - Column names (special chars cleaned: +- -> pm, ++ -> pp, etc.)
%           .units   - From row 2
%           .metadata - Contains variant ('NSF', 'SF', or 'combined')
%
%   See also IMPORTAUTO, CREATEDATASTRUCT, IMPORTNCNRREFL, IMPORTNCNRDAT

    arguments
        filepath (1,1) string {mustBeFile}
        options.Verbose (1,1) logical = false
    end

    % ════════════════════════════════════════════════════════════════
    %  Read file: header rows + data
    % ════════════════════════════════════════════════════════════════
    fid = fopen(filepath, 'r');
    try
        % Read header lines (first two)
        headerLine1 = fgetl(fid);  % Column names
        headerLine2 = fgetl(fid);  % Units

        % Split headers by tab
        colNames = strsplit(strtrim(headerLine1), char(9));  % char(9) = tab
        units = strsplit(strtrim(headerLine2), char(9));

        % Read remaining data as numeric
        % Build a format string for textscan
        nCols = numel(colNames);
        formatStr = repmat('%f', 1, nCols);
        dataArray = textscan(fid, formatStr, 'Delimiter', '\t');

        % Convert cell array to matrix
        dataMatrix = [dataArray{:}];
    finally
        fclose(fid);
    end

    if isempty(dataMatrix)
        error('parser:importNCNRPNR:noData', ...
            'No numeric data found in file: %s', filepath);
    end

    % ════════════════════════════════════════════════════════════════
    %  Extract Q (time) and values
    % ════════════════════════════════════════════════════════════════
    Q = dataMatrix(:, 1);
    valueData = dataMatrix(:, 2:end);

    % Clean up column names (replace polarization markers)
    cleanLabels = cleanPolarizationLabels(colNames);

    % ════════════════════════════════════════════════════════════════
    %  Detect variant (NSF vs SF)
    % ════════════════════════════════════════════════════════════════
    colNamesLower = lower(string(colNames));
    isNSF = any(contains(colNamesLower, {'r++', 'r--'}, 'IgnoreCase', true));
    isSF = any(contains(colNamesLower, {'r+-', 'r-+', 'r+/-'}, 'IgnoreCase', true));

    if isNSF && isSF
        variant = 'combined';
    elseif isNSF
        variant = 'NSF';
    elseif isSF
        variant = 'SF';
    else
        variant = 'unknown';
    end

    % ════════════════════════════════════════════════════════════════
    %  Build output
    % ════════════════════════════════════════════════════════════════
    % Build labels and units: Q is the first column (already extracted as time)
    % outLabels should be the remaining column names (already cleaned)
    outLabels = cleanLabels(2:end);  % skip Q (already extracted as time)

    % Build units: skip the first unit (Q) and keep the rest
    outUnits = units(2:end);

    metadata.source        = char(filepath);
    metadata.importDate    = datetime('now');
    metadata.parserName    = 'importNCNRPNR';
    metadata.parserVersion = '1.0';
    metadata.xColumnName = 'Q';
    metadata.xColumnUnit = '1/Ang';
    metadata.parserSpecific.dataSource = 'NCNR reductus';
    metadata.parserSpecific.instrument = 'NCNR polarized reflectometer';
    metadata.parserSpecific.variant = variant;

    % Call createDataStruct
    data = parser.createDataStruct(Q, valueData, ...
        'labels', outLabels, ...
        'units', outUnits, ...
        'metadata', metadata);
end


% ────────────────────────────────────────────────────────────────────
% HELPER FUNCTIONS
% ────────────────────────────────────────────────────────────────────

function cleanLabels = cleanPolarizationLabels(labels)
%CLEANPOLARIZATIONLABELS  Replace polarization notation: +- -> pm, ++ -> pp, etc.
    cleanLabels = {};
    for i = 1:numel(labels)
        label = labels{i};
        % Replace common polarization notations
        label = strrep(label, '++', 'pp');
        label = strrep(label, '+-', 'pm');
        label = strrep(label, '-+', 'mp');
        label = strrep(label, '--', 'mm');
        label = strrep(label, '+/-', 'pm');  % Alternative notation
        label = strrep(label, '-/+', 'mp');
        cleanLabels{i} = label;
    end
end
