function reportBug(options)
%REPORTBUG  Show an editable bug-report dialog with zero-infrastructure sending.
%
%   bugReport.reportBug()                               % no context
%   bugReport.reportBug(Source="BosonPlotter", Dataset=ds, Error=ME)
%
%   Collects environment, the most recent error, and optional dataset
%   metadata, then shows a dialog where the user describes the bug and
%   sends the report by one of three paths:
%
%       • Copy to Clipboard   — user pastes anywhere (email, Slack, issue)
%       • Save as .txt        — writes bugreport_<date>.txt to a chosen folder
%       • Open on GitHub      — opens a prefilled issue URL (GitHub account
%                                required; checkbox gates this option)
%
%   All arguments are optional and pass straight through to
%   `bugReport.buildReport`.  See that file for the full list.

    arguments
        options.Source      (1,1) string = "Unknown"
        options.Dataset     struct       = struct()
        options.Error                    = []
    end

    report = bugReport.buildReport( ...
        Source      = options.Source, ...
        Dataset     = options.Dataset, ...
        Error       = options.Error);

    showDialog(report);
end

% ═══════════════════════════════════════════════════════════════════════════
function showDialog(report)
    % Github repo for the "Open on GitHub" button
    REPO = "pquarterman17/Quantized_matlab";

    % ─── Figure ──────────────────────────────────────────────────────────
    dlg = uifigure('Name', 'Report a Bug', ...
                   'Position', centerOnScreen(560, 620), ...
                   'WindowStyle', 'modal', ...
                   'Resize', 'on');

    grid = uigridlayout(dlg, [7 4], ...
        'RowHeight',   {22, 100, 22, 28, 22, '1x', 32}, ...
        'ColumnWidth', {'1x', 100, 100, 100}, ...
        'Padding',     [12 12 12 12], ...
        'RowSpacing',  6, ...
        'ColumnSpacing', 6);

    % Row 1 — Description label
    lbl = uilabel(grid, 'Text', 'What happened? (required)', ...
                  'FontWeight', 'bold');
    lbl.Layout.Row = 1; lbl.Layout.Column = [1 4];

    % Row 2 — Description textarea
    descBox = uitextarea(grid, 'Placeholder', ...
        'Describe the bug: what you did, what you expected, what happened...');
    descBox.Layout.Row = 2; descBox.Layout.Column = [1 4];

    % Row 3 — Email label
    lbl = uilabel(grid, 'Text', 'Email (optional — for follow-up):');
    lbl.Layout.Row = 3; lbl.Layout.Column = [1 4];

    % Row 4 — Email field + GitHub checkbox
    emailBox = uieditfield(grid, 'text', 'Placeholder', 'you@example.com');
    emailBox.Layout.Row = 4; emailBox.Layout.Column = [1 2];

    ghCheck = uicheckbox(grid, 'Text', 'I have a GitHub account', ...
                         'Value', false, ...
                         'Tooltip', 'Enables the "Open on GitHub" button');
    ghCheck.Layout.Row = 4; ghCheck.Layout.Column = [3 4];

    % Row 5 — Context label
    lbl = uilabel(grid, ...
        'Text', 'Auto-captured context (you can edit or redact):', ...
        'FontWeight', 'bold');
    lbl.Layout.Row = 5; lbl.Layout.Column = [1 4];

    % Row 6 — Context textarea (pre-populated with markdown)
    contextMd = bugReport.formatReportMarkdown(report, ContextOnly=true);
    contextBox = uitextarea(grid, 'Value', splitLinesForTextarea(contextMd));
    contextBox.Layout.Row = 6; contextBox.Layout.Column = [1 4];
    try
        contextBox.FontName = 'Consolas';
    catch
        contextBox.FontName = 'Courier New';
    end

    % Row 7 — Action buttons
    btnCancel = uibutton(grid, 'Text', 'Cancel', ...
                         'ButtonPushedFcn', @(~,~) delete(dlg));
    btnCancel.Layout.Row = 7; btnCancel.Layout.Column = 1;

    btnCopy = uibutton(grid, 'Text', 'Copy', ...
                       'BackgroundColor', [0.18 0.52 0.18], ...
                       'FontColor', [1 1 1], ...
                       'ButtonPushedFcn', @(~,~) onCopy());
    btnCopy.Layout.Row = 7; btnCopy.Layout.Column = 2;

    btnSave = uibutton(grid, 'Text', 'Save .txt', ...
                       'ButtonPushedFcn', @(~,~) onSave());
    btnSave.Layout.Row = 7; btnSave.Layout.Column = 3;

    btnGitHub = uibutton(grid, 'Text', 'Open on GitHub', ...
                         'Enable', 'off', ...
                         'ButtonPushedFcn', @(~,~) onGitHub());
    btnGitHub.Layout.Row = 7; btnGitHub.Layout.Column = 4;

    ghCheck.ValueChangedFcn = @(src,~) set(btnGitHub, 'Enable', ...
                              ternary(src.Value, 'on', 'off'));

    % ─── Callbacks ───────────────────────────────────────────────────────
    function body = assembleBody()
        report.description = string(strtrim(strjoin(descBox.Value, newline)));
        report.email       = string(strtrim(emailBox.Value));
        editedContext      = strjoin(contextBox.Value, newline);

        if report.description == ""
            bosonPlotter.quietAlert(dlg, ...
                'Please describe what happened in the text area at the top.', ...
                'Description required');
            body = '';
            return;
        end

        header = strings(0, 1);
        header(end+1, 1) = "## Bug Report";
        header(end+1, 1) = "";
        header(end+1, 1) = "**What happened:**";
        header(end+1, 1) = "";
        header(end+1, 1) = report.description;
        header(end+1, 1) = "";
        if report.email ~= ""
            header(end+1, 1) = sprintf("**Reply to:** %s", report.email);
            header(end+1, 1) = "";
        end
        headerStr = char(strjoin(header, newline));
        footer = sprintf('\n_Generated %s by %s_', ...
                         char(report.generatedAt), char(report.source));
        body = sprintf('%s\n%s%s', headerStr, char(editedContext), footer);
    end

    function onCopy()
        body = assembleBody();
        if isempty(body); return; end
        clipboard('copy', body);
        bosonPlotter.quietAlert(dlg, ...
            'Bug report copied to clipboard. Paste it wherever you file bugs.', ...
            'Copied', 'Icon', 'success');
    end

    function onSave()
        body = assembleBody();
        if isempty(body); return; end
        defaultName = sprintf('bugreport_%s.txt', ...
                              char(datetime('now', 'Format', 'yyyy-MM-dd_HHmm')));
        [file, path] = uiputfile({'*.txt','Text file (*.txt)'}, ...
                                 'Save bug report', defaultName);
        if isequal(file, 0); return; end
        fid = fopen(fullfile(path, file), 'w', 'n', 'UTF-8');
        if fid == -1
            bosonPlotter.quietAlert(dlg, 'Could not open file for writing.', 'Save failed');
            return;
        end
        cleanup = onCleanup(@() fclose(fid));
        fwrite(fid, body, 'char');
        clear cleanup;
        bosonPlotter.quietAlert(dlg, sprintf('Saved to:\n%s', fullfile(path, file)), ...
                'Saved', 'Icon', 'success');
    end

    function onGitHub()
        body = assembleBody();
        if isempty(body); return; end

        titleStr = extractTitle(report.description);
        url = buildGitHubIssueURL(REPO, titleStr, body);

        % GitHub tolerates very long URLs (~8 KB) but clients vary.  Warn
        % if we're pushing past a safe limit and fall back to clipboard.
        if numel(url) > 7500
            clipboard('copy', body);
            bosonPlotter.quietAlert(dlg, ...
                ['Report is too long for a GitHub URL. ', ...
                 'It has been copied to your clipboard instead — open a ', ...
                 'new issue manually and paste.'], ...
                'Too long', 'Icon', 'warning');
            return;
        end
        web(url, '-browser');
        bosonPlotter.quietAlert(dlg, ...
            'Opened GitHub in your browser. Review and click "Submit new issue".', ...
            'Opened', 'Icon', 'success');
    end
end

% ═══════════════════════════════════════════════════════════════════════════
function titleStr = extractTitle(desc)
    desc = strtrim(char(desc));
    if isempty(desc)
        titleStr = 'Bug report';
        return;
    end
    % First line, clipped to 80 chars
    nl = find(desc == newline | desc == char(13), 1);
    if ~isempty(nl)
        desc = desc(1:nl-1);
    end
    if numel(desc) > 80
        desc = [desc(1:77), '...'];
    end
    titleStr = desc;
end

function url = buildGitHubIssueURL(repo, title, body)
    base = sprintf('https://github.com/%s/issues/new', char(repo));
    url  = sprintf('%s?title=%s&body=%s', base, ...
                   urlencode(char(title)), urlencode(char(body)));
end

function pos = centerOnScreen(w, h)
    try
        r = groot;
        s = r.ScreenSize;
        pos = [s(1) + (s(3)-w)/2, s(2) + (s(4)-h)/2, w, h];
    catch
        pos = [100 100 w h];
    end
end

function out = ternary(cond, a, b)
    if cond; out = a; else; out = b; end
end

function cellLines = splitLinesForTextarea(str)
    % uitextarea Value wants a cell array of char rows (one per line).
    str = char(str);
    cellLines = strsplit(str, newline);
end
