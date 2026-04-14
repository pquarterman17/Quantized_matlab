function md = formatReportMarkdown(report, options)
%FORMATREPORTMARKDOWN  Render a bug-report struct as GitHub-flavored markdown.
%
%   md = bugReport.formatReportMarkdown(report)
%   md = bugReport.formatReportMarkdown(report, ContextOnly=true)
%
%   Pure function.  Produces a UTF-8 char array suitable for clipboard,
%   file write, mailto body, or GitHub issue URL.
%
%   Options:
%       ContextOnly  (false) — when true, emits only the auto-captured
%                               sections (env + error + dataset).  Used by
%                               the dialog to populate its editable preview.

    arguments
        report               struct
        options.ContextOnly  (1,1) logical = false
    end

    lines = strings(0, 1);

    if ~options.ContextOnly
        lines(end+1, 1) = "## Bug Report";
        lines(end+1, 1) = "";
        if report.description ~= ""
            lines(end+1, 1) = "**What happened:**";
            lines(end+1, 1) = "";
            lines(end+1, 1) = report.description;
            lines(end+1, 1) = "";
        end
        if report.email ~= ""
            lines(end+1, 1) = sprintf("**Reply to:** %s", report.email);
            lines(end+1, 1) = "";
        end
    end

    lines = [lines; envBlock(report)];
    lines = [lines; errorBlock(report)];
    lines = [lines; datasetBlock(report)];

    if ~options.ContextOnly
        lines(end+1, 1) = "";
        lines(end+1, 1) = sprintf("_Generated %s by %s_", ...
                                  report.generatedAt, report.source);
    end

    md = char(strjoin(lines, newline));
end

% ═══════════════════════════════════════════════════════════════════════════
function lines = envBlock(report)
    env = report.env;
    lines = strings(0, 1);
    lines(end+1, 1) = "### Environment";
    lines(end+1, 1) = sprintf("- MATLAB release: %s", env.matlabRelease);
    lines(end+1, 1) = sprintf("- Platform: %s", env.computer);
    lines(end+1, 1) = sprintf("- OS: %s", env.os);
    lines(end+1, 1) = sprintf("- Toolbox SHA: %s (%s)", env.gitSha, env.gitBranch);
    lines(end+1, 1) = sprintf("- Source: %s", report.source);
    lines(end+1, 1) = "";
end

% ═══════════════════════════════════════════════════════════════════════════
function lines = errorBlock(report)
    lines = strings(0, 1);
    err = report.error;
    if isempty(fieldnames(err))
        return;
    end
    lines(end+1, 1) = "### Last Error";
    if isfield(err, 'identifier')
        lines(end+1, 1) = sprintf("- Identifier: `%s`", err.identifier);
    end
    if isfield(err, 'message')
        lines(end+1, 1) = sprintf("- Message: %s", err.message);
    end
    if isfield(err, 'stack') && ~isempty(err.stack)
        lines(end+1, 1) = "";
        lines(end+1, 1) = "```";
        lines = [lines; err.stack(:)];
        lines(end+1, 1) = "```";
    end
    lines(end+1, 1) = "";
end

% ═══════════════════════════════════════════════════════════════════════════
function lines = datasetBlock(report)
    lines = strings(0, 1);
    ds = report.dataset;
    if isempty(fieldnames(ds))
        return;
    end
    lines(end+1, 1) = "### Active Dataset";
    if isfield(ds, 'parser')
        lines(end+1, 1) = sprintf("- Parser: `%s`", ds.parser);
    end
    if isfield(ds, 'filename')
        lines(end+1, 1) = sprintf("- File: `%s`", ds.filename);
    end
    if isfield(ds, 'nRows') && isfield(ds, 'nCols')
        lines(end+1, 1) = sprintf("- Size: %d rows × %d columns", ...
                                  ds.nRows, ds.nCols);
    end
    if isfield(ds, 'labels') && ~isempty(ds.labels)
        lines(end+1, 1) = sprintf("- Columns: %s", strjoin(ds.labels, ", "));
    end
    if isfield(ds, 'units') && ~isempty(ds.units)
        units = ds.units;
        units(units == "") = "—";
        lines(end+1, 1) = sprintf("- Units: %s", strjoin(units, ", "));
    end
    lines(end+1, 1) = "";
end
