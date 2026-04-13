classdef TemplateAnalytics
%TEMPLATEANALYTICS  Log and summarise template application events.
%
%   templates.TemplateAnalytics.logApplication(name, conf, auto, edited)
%   report = templates.TemplateAnalytics.summary()
%   templates.TemplateAnalytics.clearLog()
%
%   Events are persisted to a JSON lines file in prefdir so usage data
%   survives across MATLAB sessions. Each log entry records the template
%   name, confidence score, whether the match was auto-applied, whether
%   the user subsequently edited the result, and a UTC timestamp.
%
%   Log file location:
%       fullfile(prefdir, 'boson_template_log.json')
%
%   See also templates.TemplateEngine

    methods (Static)

        function logApplication(templateName, confidence, wasAutoApplied, wasEdited)
        %LOGAPPLICATION  Append one event to the persistent log.
        %
        %   Inputs
        %   ------
        %   templateName  — char, name of the template that was applied
        %   confidence    — scalar in [0,1], match confidence
        %   wasAutoApplied — logical, true if applied without user confirmation
        %   wasEdited      — logical, true if user modified the result afterward
            arguments
                templateName  (1,:) char
                confidence    (1,1) double {mustBeInRange(confidence, 0, 1)}
                wasAutoApplied (1,1) logical
                wasEdited      (1,1) logical
            end

            entry = struct( ...
                'template',    templateName, ...
                'confidence',  confidence, ...
                'autoApplied', wasAutoApplied, ...
                'edited',      wasEdited, ...
                'timestamp',   char(datetime('now', 'TimeZone', 'UTC', ...
                                   'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')));

            logPath = templates.TemplateAnalytics.logPath();
            templates.TemplateAnalytics.appendEntry(logPath, entry);
        end

        function report = summary()
        %SUMMARY  Return per-template usage statistics.
        %
        %   Output
        %   ------
        %   report — struct array (one element per template seen in the log) with:
        %     .templateName  — char, template name
        %     .count         — number of times applied
        %     .avgConfidence — mean confidence across all applications
        %     .editRate      — fraction of applications that were subsequently edited
        %
        %   Returns empty struct array (with correct fields) if the log is empty.
            entries = templates.TemplateAnalytics.readAll();

            emptyReport = struct('templateName', {}, 'count', {}, ...
                                 'avgConfidence', {}, 'editRate', {});

            if isempty(entries)
                report = emptyReport;
                return;
            end

            names = cellfun(@(e) e.template, entries, 'UniformOutput', false);
            uniqueNames = unique(names);

            report = repmat(emptyReport, 1, numel(uniqueNames));
            for k = 1:numel(uniqueNames)
                n = uniqueNames{k};
                mask = strcmp(names, n);
                subset = entries(mask);

                confs    = cellfun(@(e) e.confidence, subset);
                editedVec = cellfun(@(e) e.edited,    subset);

                report(k).templateName  = n;
                report(k).count         = numel(subset);
                report(k).avgConfidence = mean(confs);
                report(k).editRate      = mean(double(editedVec));
            end
        end

        function clearLog()
        %CLEARLOG  Delete the persistent log file.
            p = templates.TemplateAnalytics.logPath();
            if isfile(p)
                builtin('delete', p);
            end
        end

    end % methods (Static)


    methods (Static, Access = private)

        function p = logPath()
        %LOGPATH  Full path to the JSON log file.
            p = fullfile(prefdir, 'boson_template_log.json');
        end

        function appendEntry(logPath, entry)
        %APPENDENTRY  Append one JSON-encoded entry as a new line.
            line = [jsonencode(entry), newline];
            fid = fopen(logPath, 'a', 'n', 'UTF-8');
            if fid < 0
                warning('templates:analytics:writeFailure', ...
                    'Could not open analytics log for writing: %s', logPath);
                return;
            end
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, line, 'char');
        end

        function entries = readAll()
        %READALL  Read the log file and return a cell array of decoded structs.
            entries = {};
            p = templates.TemplateAnalytics.logPath();
            if ~isfile(p)
                return;
            end
            txt = fileread(p);
            lines = strsplit(strtrim(txt), newline);
            lines(cellfun(@isempty, lines)) = [];
            for k = 1:numel(lines)
                try
                    entries{end+1} = jsondecode(lines{k}); %#ok<AGROW>
                catch
                    % Skip malformed lines
                end
            end
        end

    end % methods (Static, Access = private)

end % classdef
