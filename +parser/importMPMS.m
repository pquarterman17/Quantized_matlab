function data = importMPMS(filepath, options)
%IMPORTMPMS Import a Quantum Design MPMS SQUID magnetometer .dat file.
%
%   Syntax
%   ──────
%   data = parser.importMPMS(filepath)
%   data = parser.importMPMS(filepath, Name=Value)
%
%   Inputs
%   ──────
%   filepath   (1,1) string   Path to the MPMS .dat file.
%
%   Name-Value Options
%   ──────────────────
%   XAxis           Column for x-axis (default: 'temp'). Accepts:
%                     'temp' / 'temperature' → Temperature (K)
%                     'field'                → Magnetic Field (Oe)
%                     'time'                 → Time Stamp
%                     Column index or exact name
%   YAxis           Column(s) for y-axis (default: 'dcmoment'). Accepts:
%                     'dcmoment' / 'dc'  → DC Moment (emu)
%                     'acmoment' / 'ac'  → AC Moment (emu)
%                     'ach'              → AC Susceptibility (emu/Oe)
%                     'acsusceptibility' → AC Susceptibility
%                     'stderr'           → M. Std. Err.
%                     'all'              → All numeric columns except x-axis
%                     Cell array of column names/indices
%   TimeColumn      Alias for XAxis.
%   DataColumns     Alias for YAxis.
%   Verbose         Print import summary (default: false).
%
%   Outputs
%   ───────
%   data   Struct with fields:
%            .time        [Nx1]  x-axis values (temperature or field)
%            .values      [NxM]  data matrix (moments/susceptibilities)
%            .labels      {1xM}  channel names
%            .units       {1xM}  unit strings
%            .metadata    Struct with header info and import details
%
%   FILE FORMAT
%   ───────────
%   MPMS files use the Quantum Design [Header] / [Data] format, similar to
%   VSM/PPMS, but with SQUID-specific columns:
%     - DC Moment (emu) — SQUID measured moment
%     - AC Moment (emu) — AC susceptibility moment response
%     - AC Susceptibility (emu/Oe) — AC χ normalized by field
%     - M. Std. Err. — Uncertainty on DC moment
%
%   Examples
%   ────────
%   % Temperature-dependent magnetization (default)
%   d = parser.importMPMS('sample_MT.dat', Verbose=true);
%
%   % Field-dependent at fixed temperature
%   d = parser.importMPMS('sample_MH.dat', XAxis='field');
%
%   % Multiple channels: DC moment and AC susceptibility vs temp
%   d = parser.importMPMS('sample.dat', YAxis={'dcmoment', 'acsusceptibility'});
%
%   See also IMPORTQDVSM, IMPORTPPMS, CREATEDATASTRUCT

    arguments
        filepath            (1,1) string {mustBeFile}
        options.XAxis              = 'temp'
        options.YAxis              = 'dcmoment'
        options.TimeColumn         = ''    % alias for XAxis
        options.DataColumns        = ''    % alias for YAxis
        options.Verbose     (1,1) logical = false
    end

    % Resolve aliases
    xSpec = options.XAxis;
    ySpec = options.YAxis;
    if ~isempty(char(options.TimeColumn))
        xSpec = options.TimeColumn;
    end
    if ~isempty(char(options.DataColumns))
        ySpec = options.DataColumns;
    end

    % ════════════════════════════════════════════════════════════════════════
    %  1. Delegate to importQDVSM with MPMS-specific column resolution
    % ════════════════════════════════════════════════════════════════════════
    try
        data = parser.importQDVSM(filepath, ...
            'XAxis', xSpec, 'YAxis', ySpec, 'Verbose', false);
    catch ME
        % If importQDVSM fails (no [Header]/[Data] structure), suggest alternative
        if contains(ME.message, '[Header]', 'IgnoreCase', true) || ...
           contains(ME.message, '[Data]', 'IgnoreCase', true)
            error('parser:importMPMS:formatError', ...
                ['File does not have the expected MPMS [Header]/[Data] format.\n' ...
                 'Is this a legacy MPMS CSV file? Try parser.importCSV instead.\n' ...
                 'Original error: %s'], ME.message);
        else
            rethrow(ME);
        end
    end

    % ════════════════════════════════════════════════════════════════════════
    %  2. Update metadata to indicate MPMS parser
    % ════════════════════════════════════════════════════════════════════════
    data.metadata.parserName = 'importMPMS';
    data.metadata.instrumentType = 'MPMS SQUID';

    % ════════════════════════════════════════════════════════════════════════
    %  3. Verbose output
    % ════════════════════════════════════════════════════════════════════════
    if options.Verbose
        printSummary(data, filepath);
    end
end


% ════════════════════════════════════════════════════════════════════════════
%  Helper function: Print summary
% ════════════════════════════════════════════════════════════════════════════

function printSummary(data, filepath)
%PRINTSUMMARY  Formatted console output for Verbose mode.
    [~, fname, ext] = fileparts(filepath);

    xLabel = '';
    if isfield(data.metadata, 'xColumnName') && ~isempty(data.metadata.xColumnName)
        xLabel = data.metadata.xColumnName;
    end

    SEP = repmat('─', 1, 58);
    fprintf('\n%s\n', repmat('═', 1, 58));
    fprintf('  importMPMS  (Quantum Design SQUID magnetometer)\n');
    fprintf('  File       : %s%s\n', fname, ext);
    fprintf('%s\n', SEP);

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
    fprintf('  Channels   : %d\n', size(data.values, 2));
    for k = 1:size(data.values, 2)
        col = data.values(:, k);
        unitStr = '';
        if ~isempty(data.units{k})
            unitStr = sprintf(' (%s)', data.units{k});
        end
        tag = [data.labels{k}, unitStr];
        validVals = col(~isnan(col));
        if isempty(validVals)
            fprintf('    %-28s  (all NaN)\n', tag);
        else
            fprintf('    %-28s  [%.4g, %.4g]\n', tag, ...
                min(validVals), max(validVals));
        end
    end

    fprintf('%s\n\n', repmat('═', 1, 58));
end
