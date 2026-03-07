function writeXRDcsv(data, outputPath, options)
% ════════════════════════════════════════════════════════════════════════
% Write parsed XRD data struct to CSV file with optional metadata header.
% ════════════════════════════════════════════════════════════════════════
%
% Syntax:
%   utilities.writeXRDcsv(data, outputPath)
%   utilities.writeXRDcsv(data, outputPath, Name=Value)
%
% Inputs:
%   data         Unified data struct from any XRD parser
%                Fields: .time, .values, .labels, .units, .metadata
%   outputPath   Full path for output .csv file
%
% Name-Value Options:
%   Format             "standard" (default) | "origin"
%                      CSV format: standard (comma-delimited) or Origin ASCII (tab-delimited)
%   Intensity          "both" (default) | "cps" | "counts"
%                      Which intensity column(s) to write
%   IncludeMetadata    true (default) | false
%                      Write metadata header block prefixed with '#'
%
% Outputs:
%   (none — writes file to disk)
%
% Examples:
%   % Write standard CSV with metadata and both intensity columns
%   data = parser.importXRDML('sample.xrdml');
%   utilities.writeXRDcsv(data, 'sample.csv');
%
%   % Write Origin ASCII format without metadata
%   utilities.writeXRDcsv(data, 'sample.csv', Format="origin", IncludeMetadata=false);
%
%   % Write CPS-only CSV
%   utilities.writeXRDcsv(data, 'sample.csv', Intensity="cps");
%
% ════════════════════════════════════════════════════════════════════════

arguments
    data struct
    outputPath string
    options.Format string = "standard"
    options.Intensity string = "both"
    options.IncludeMetadata logical = true
end

% Validate format and intensity options
validatestring(options.Format, ["standard", "origin"]);
validatestring(options.Intensity, ["both", "cps", "counts"]);

% Check output directory exists (if a directory is specified)
[outDir, ~, ~] = fileparts(outputPath);
if ~isempty(outDir)
    % A directory was specified — verify it exists
    if ~isfolder(outDir)
        error("utilities:writeXRDcsv:badOutputDir", ...
            "Output directory does not exist: " + outDir);
    end
end
% If outDir is empty, file will be written to current directory (pwd)

% Determine intensity columns to write
[intensityVals, intensityLabels, intensityUnits] = ...
    resolveIntensityColumns(data, options.Intensity);

% Prepare header row and data
if strcmp(options.Format, "origin")
    % Origin ASCII format: tab-delimited, 3 header rows (Name, Units, Designation)
    xLabel = getXAxisLabel(data);
    xUnit = getXAxisUnit(data);

    names = [xLabel, intensityLabels];
    units = [xUnit, intensityUnits];
    designations = ['X', repmat('Y', 1, numel(intensityLabels))];

    % Open file and write Origin ASCII format
    fid = fopen(outputPath, 'w');
    if fid < 0
        error("utilities:writeXRDcsv:fileOpenError", ...
            "Cannot open file for writing: " + outputPath);
    end
    cleanup = onCleanup(@() fclose(fid));

    % Metadata header
    if options.IncludeMetadata
        writeMetadataBlock(fid, data, true); % true = Origin format (tab after #)
    end

    % Three header rows
    fprintf(fid, "%s", names(1));
    for i = 2:numel(names)
        fprintf(fid, "\t%s", names(i));
    end
    fprintf(fid, "\n");

    fprintf(fid, "%s", units(1));
    for i = 2:numel(units)
        fprintf(fid, "\t%s", units(i));
    end
    fprintf(fid, "\n");

    fprintf(fid, "%s", designations(1));
    for i = 2:numel(designations)
        fprintf(fid, "\t%s", designations(i));
    end
    fprintf(fid, "\n");

    % Data rows (tab-delimited)
    for row = 1:size(data.values, 1)
        fprintf(fid, "%.6f", data.time(row));
        for col = 1:size(intensityVals, 2)
            fprintf(fid, "\t%.6g", intensityVals(row, col));
        end
        fprintf(fid, "\n");
    end
else
    % Standard CSV format: comma-delimited, metadata block, data with headers
    xLabel = getXAxisLabel(data);
    headers = [xLabel, intensityLabels];

    fid = fopen(outputPath, 'w');
    if fid < 0
        error("utilities:writeXRDcsv:fileOpenError", ...
            "Cannot open file for writing: " + outputPath);
    end
    cleanup = onCleanup(@() fclose(fid));

    % Metadata header
    if options.IncludeMetadata
        writeMetadataBlock(fid, data, false); % false = standard format (space after #)
    end

    % CSV header row
    fprintf(fid, "%s", headers(1));
    for i = 2:numel(headers)
        fprintf(fid, ",%s", headers(i));
    end
    fprintf(fid, "\n");

    % Data rows (comma-delimited)
    for row = 1:size(data.values, 1)
        fprintf(fid, "%.6f", data.time(row));
        for col = 1:size(intensityVals, 2)
            fprintf(fid, ",%.6g", intensityVals(row, col));
        end
        fprintf(fid, "\n");
    end
end

end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Resolve intensity columns
% ════════════════════════════════════════════════════════════════════════

function [intensityVals, labels, units] = resolveIntensityColumns(data, intensityOpt)

    originalUnit = data.units{1};
    originalVals = data.values(:, 1);
    countingTime = getNested(data.metadata, 'countingTime', nan);

    if strcmp(intensityOpt, "both")
        % Try to provide both cps and counts columns
        if contains(originalUnit, 'cps', 'IgnoreCase', true)
            % Original is cps — convert to counts if countingTime available
            if isnan(countingTime)
                % Can't convert; write only cps with note
                intensityVals = originalVals;
                labels = ["Intensity (cps)"];
                units = ["cps"];
            else
                counts = originalVals * countingTime;
                intensityVals = [originalVals, counts];
                labels = ["Intensity (cps)", "Intensity (counts)"];
                units = ["cps", "counts"];
            end
        else
            % Original is counts — convert to cps if countingTime available
            if isnan(countingTime)
                % Can't convert; write only counts with note
                intensityVals = originalVals;
                labels = ["Intensity (counts)"];
                units = ["counts"];
            else
                cps = originalVals / countingTime;
                intensityVals = [cps, originalVals];
                labels = ["Intensity (cps)", "Intensity (counts)"];
                units = ["cps", "counts"];
            end
        end
    elseif strcmp(intensityOpt, "cps")
        if contains(originalUnit, 'cps', 'IgnoreCase', true)
            intensityVals = originalVals;
        else
            % Original is counts — convert if possible
            if isnan(countingTime)
                warning("utilities:writeXRDcsv:noConversion", ...
                    "Cannot convert counts to cps (countingTime not available). Writing counts.");
                intensityVals = originalVals;
            else
                intensityVals = originalVals / countingTime;
            end
        end
        labels = ["Intensity (cps)"];
        units = ["cps"];
    else
        % intensityOpt == "counts"
        if contains(originalUnit, 'counts', 'IgnoreCase', true)
            intensityVals = originalVals;
        else
            % Original is cps — convert if possible
            if isnan(countingTime)
                warning("utilities:writeXRDcsv:noConversion", ...
                    "Cannot convert cps to counts (countingTime not available). Writing cps.");
                intensityVals = originalVals;
            else
                intensityVals = originalVals * countingTime;
            end
        end
        labels = ["Intensity (counts)"];
        units = ["counts"];
    end
end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Write metadata block
% ════════════════════════════════════════════════════════════════════════

function writeMetadataBlock(fid, data, isOriginFormat)
    if isOriginFormat
        prefix = "# ";
    else
        prefix = "# ";
    end

    fprintf(fid, "%sXRD Batch Export\n", prefix);

    % Source file
    if isfield(data.metadata, 'sourceFile')
        fprintf(fid, "%sSource: %s\n", prefix, data.metadata.sourceFile);
    end

    % Parser type
    if isfield(data.metadata, 'parser')
        fprintf(fid, "%sParser: %s\n", prefix, data.metadata.parser);
    end

    % Sample info
    if isfield(data.metadata, 'parserSpecific') && isfield(data.metadata.parserSpecific, 'sampleName')
        fprintf(fid, "%sSample: %s\n", prefix, data.metadata.parserSpecific.sampleName);
    elseif isfield(data.metadata, 'parserSpecific') && isfield(data.metadata.parserSpecific, 'sampleID')
        fprintf(fid, "%sSample: %s\n", prefix, data.metadata.parserSpecific.sampleID);
    end

    % Anode info (from parserSpecific if available)
    if isfield(data.metadata, 'parserSpecific') && isfield(data.metadata.parserSpecific, 'anodeMaterial')
        anode = data.metadata.parserSpecific.anodeMaterial;
        kv = getNested(data.metadata.parserSpecific, 'tension_kV', []);
        mA = getNested(data.metadata.parserSpecific, 'current_mA', []);
        if ~isempty(kv) && ~isempty(mA)
            fprintf(fid, "%sAnode: %s (%.1f kV / %.1f mA)\n", prefix, anode, kv, mA);
        else
            fprintf(fid, "%sAnode: %s\n", prefix, anode);
        end
    end

    % Wavelength
    if isfield(data.metadata, 'parserSpecific') && isfield(data.metadata.parserSpecific, 'kAlpha1')
        ka1 = data.metadata.parserSpecific.kAlpha1;
        fprintf(fid, "%sWavelength: Ka1 = %.5g A\n", prefix, ka1);
    end

    % 2-theta range
    if isfield(data.metadata, 'parserSpecific')
        startAngle = getNested(data.metadata.parserSpecific, 'startAngle', []);
        endAngle = getNested(data.metadata.parserSpecific, 'endAngle', []);
        if ~isempty(startAngle) && ~isempty(endAngle)
            fprintf(fid, "%s2-theta range: %.4f - %.4f deg\n", prefix, startAngle, endAngle);
        end
    end

    % Step size and point count
    if isfield(data.metadata, 'parserSpecific')
        stepSize = getNested(data.metadata.parserSpecific, 'stepSize', []);
        nPoints = getNested(data.metadata.parserSpecific, 'nPoints', []);
        if ~isempty(stepSize) && ~isempty(nPoints)
            fprintf(fid, "%sStep size: %.6f deg (%d points)\n", prefix, stepSize, nPoints);
        end
    end

    % Counting time
    countingTime = getNested(data.metadata, 'countingTime', []);
    if ~isempty(countingTime) && ~isnan(countingTime)
        fprintf(fid, "%sCounting time: %.3f s/point\n", prefix, countingTime);
    end

    % Export date
    fprintf(fid, "%sExport date: %s\n", prefix, datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    fprintf(fid, "%s\n", prefix);
end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Get x-axis label from metadata or default
% ════════════════════════════════════════════════════════════════════════

function label = getXAxisLabel(data)
    % Return x-axis label from metadata; default to "X Axis"
    if isfield(data.metadata, 'xColumnName')
        unit = '';
        if isfield(data.metadata, 'xColumnUnit')
            unit = data.metadata.xColumnUnit;
        end
        if ~isempty(unit)
            label = sprintf('%s (%s)', data.metadata.xColumnName, unit);
        else
            label = data.metadata.xColumnName;
        end
    else
        label = 'X Axis';
    end
end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Get x-axis unit from metadata or default
% ════════════════════════════════════════════════════════════════════════

function unit = getXAxisUnit(data)
    % Return x-axis unit from metadata; default to empty
    if isfield(data.metadata, 'xColumnUnit')
        unit = data.metadata.xColumnUnit;
    else
        unit = '';
    end
end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Extract axis label (legacy, not used)
% ════════════════════════════════════════════════════════════════════════

function label = extractLabel(fullLabel)
    % Input: e.g., "2-Theta (deg)" or "Temperature (K)"
    % Output: e.g., "2-Theta (deg)"
    label = fullLabel;
end

% ════════════════════════════════════════════════════════════════════════
% HELPER: Nested get with default
% ════════════════════════════════════════════════════════════════════════

function val = getNested(struct, field, default)
    if nargin < 3
        default = [];
    end
    if isfield(struct, field)
        val = struct.(field);
    else
        val = default;
    end
end
