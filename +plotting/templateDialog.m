function result = templateDialog(ax, mode)
%TEMPLATEDIALOG  Modal GUI for saving or applying plot style templates.
%
%   Syntax:
%       result = plotting.templateDialog(ax, 'save')
%       result = plotting.templateDialog(ax, 'apply')
%
%   Inputs:
%       ax    — axes handle to capture styling from (save) or apply to (apply)
%       mode  — 'save' | 'apply'
%
%   Outputs:
%       result — name of the template saved or applied, or '' if cancelled
%
%   Examples:
%       fig = figure; plot(rand(5,1));
%       name = plotting.templateDialog(gca, 'save')
%       name = plotting.templateDialog(gca, 'apply')
%
%   See also plotting.plotTemplate

arguments
    ax   (1,1)          % axes handle
    mode (1,1) string {mustBeMember(mode, ["save","apply"])}
end

result = '';

switch mode
    case 'save'
        result = runSaveDialog(ax);
    case 'apply'
        result = runApplyDialog(ax);
end

end % templateDialog


% ════════════════════════════════════════════════════════════════════════
%  Save dialog
% ════════════════════════════════════════════════════════════════════════
function result = runSaveDialog(ax)

result = '';

dlg = uifigure('Name', 'Save Plot Template', ...
    'Position', [400 300 340 180], ...
    'Resize', 'off', 'WindowStyle', 'modal');

gl = uigridlayout(dlg, [4 2], ...
    'RowHeight', {24, 24, 24, 34}, ...
    'ColumnWidth', {90, '1x'}, ...
    'Padding', [14 14 14 10], 'RowSpacing', 8, 'ColumnSpacing', 8);

uilabel(gl, 'Text', 'Template name:', 'FontSize', 11, ...
    'HorizontalAlignment', 'right');
efName = uieditfield(gl, 'Value', '', 'Placeholder', 'e.g. PubStyle', ...
    'FontSize', 11);

uilabel(gl, 'Text', 'Description:', 'FontSize', 11, ...
    'HorizontalAlignment', 'right');
efDesc = uieditfield(gl, 'Value', '', 'Placeholder', 'optional', ...
    'FontSize', 11);  %#ok<NASGU>  — stored for future use

uilabel(gl, 'Text', '');   % spacer
uilabel(gl, 'Text', '');

% Buttons row
btnGL = uigridlayout(gl, [1 3], ...
    'ColumnWidth', {'1x', 90, 80}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 6);
btnGL.Layout.Row = 4; btnGL.Layout.Column = [1 2];

uilabel(btnGL, 'Text', '');
btnSave = uibutton(btnGL, 'Text', 'Save', ...
    'BackgroundColor', [0.15 0.45 0.75], 'FontColor', [1 1 1], ...
    'FontWeight', 'bold', 'ButtonPushedFcn', @onSave);
uibutton(btnGL, 'Text', 'Cancel', 'ButtonPushedFcn', @(~,~) uiresume(dlg));

% ── Wait for user ──────────────────────────────────────────────────────
uiwait(dlg);

    % ── Callback ──────────────────────────────────────────────────────
    function onSave(~,~)
        nm = strtrim(efName.Value);
        if isempty(nm)
            uialert(dlg, 'Please enter a template name.', 'Missing Name');
            return;
        end
        try
            plotting.plotTemplate('save', Name=nm, Axes=ax);
            result = nm;
        catch ME
            uialert(dlg, ME.message, 'Save Failed');
            return;
        end
        uiresume(dlg);
    end

if isvalid(dlg)
    delete(dlg);
end

end


% ════════════════════════════════════════════════════════════════════════
%  Apply dialog
% ════════════════════════════════════════════════════════════════════════
function result = runApplyDialog(ax)

result = '';

names = plotting.plotTemplate('list');
if isempty(names)
    uialert(ancestor(ax,'figure'), ...
        'No saved templates found. Use "Save as Template" first.', ...
        'No Templates');
    return;
end

dlg = uifigure('Name', 'Apply Plot Template', ...
    'Position', [380 250 400 340], ...
    'Resize', 'off', 'WindowStyle', 'modal');

gl = uigridlayout(dlg, [3 1], ...
    'RowHeight', {24, '1x', 38}, ...
    'Padding', [14 14 14 10], 'RowSpacing', 8);

uilabel(gl, 'Text', 'Select a template:', 'FontSize', 11, ...
    'FontWeight', 'bold');

% Listbox + preview panel side-by-side
midGL = uigridlayout(gl, [1 2], ...
    'ColumnWidth', {'1x', '1x'}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 8);
midGL.Layout.Row = 2;

lb = uilistbox(midGL, 'Items', names, 'Value', names{1}, ...
    'FontSize', 11, 'ValueChangedFcn', @onSelectionChanged);

previewPanel = uipanel(midGL, 'Title', 'Details', 'FontSize', 9);
previewGL    = uigridlayout(previewPanel, [1 1], 'Padding', [2 2 2 2]);
txtPreview   = uitextarea(previewGL, 'Value', '', 'Editable', 'off', 'FontSize', 9);

% Buttons row
btnGL = uigridlayout(gl, [1 4], ...
    'ColumnWidth', {'1x', 90, 80, 80}, ...
    'Padding', [0 0 0 0], 'ColumnSpacing', 6);
btnGL.Layout.Row = 3;

uilabel(btnGL, 'Text', '');
uibutton(btnGL, 'Text', 'Apply', ...
    'BackgroundColor', [0.15 0.45 0.75], 'FontColor', [1 1 1], ...
    'FontWeight', 'bold', 'ButtonPushedFcn', @onApply);
uibutton(btnGL, 'Text', 'Delete', ...
    'BackgroundColor', [0.6 0.2 0.2], 'FontColor', [1 1 1], ...
    'ButtonPushedFcn', @onDelete);
uibutton(btnGL, 'Text', 'Cancel', 'ButtonPushedFcn', @(~,~) uiresume(dlg));

% Populate preview for initial selection
updatePreview(names{1});

uiwait(dlg);

    % ── Callbacks ─────────────────────────────────────────────────────
    function onSelectionChanged(~,~)
        if ~isempty(lb.Value)
            updatePreview(lb.Value);
        end
    end

    function updatePreview(nm)
        try
            tmpl = plotting.plotTemplate('load', Name=nm);
            lines = { ...
                sprintf('Name:     %s', tmpl.name), ...
                sprintf('Created:  %s', datestr(tmpl.created, 'yyyy-mm-dd HH:MM')), ...
                sprintf('Font:     %s %dpt', tmpl.axesProps.FontName, tmpl.axesProps.FontSize), ...
                sprintf('Box:      %s', tmpl.axesProps.Box), ...
                sprintf('Grid X/Y: %s / %s', tmpl.axesProps.XGrid, tmpl.axesProps.YGrid), ...
                sprintf('Scale:    %s / %s', tmpl.axesProps.XScale, tmpl.axesProps.YScale), ...
                sprintf('TickDir:  %s', tmpl.axesProps.TickDir), ...
                sprintf('Lines:    %d captured', numel(tmpl.lineProps)), ...
            };
            txtPreview.Value = lines;
        catch
            txtPreview.Value = {'(could not load template)'};
        end
    end

    function onApply(~,~)
        nm = lb.Value;
        if isempty(nm)
            uialert(dlg, 'Select a template first.', 'No Selection');
            return;
        end
        try
            plotting.plotTemplate('apply', Name=nm, Axes=ax);
            result = nm;
        catch ME
            uialert(dlg, ME.message, 'Apply Failed');
            return;
        end
        uiresume(dlg);
    end

    function onDelete(~,~)
        nm = lb.Value;
        if isempty(nm)
            return;
        end
        answer = uiconfirm(dlg, ...
            sprintf('Delete template "%s"?', nm), 'Confirm Delete', ...
            'Options', {'Delete','Cancel'}, 'DefaultOption', 'Cancel', ...
            'Icon', 'warning');
        if strcmp(answer, 'Delete')
            try
                plotting.plotTemplate('delete', Name=nm);
            catch ME
                uialert(dlg, ME.message, 'Delete Failed');
                return;
            end
            % Refresh list
            names = plotting.plotTemplate('list');
            if isempty(names)
                uiresume(dlg);
                return;
            end
            lb.Items = names;
            lb.Value = names{1};
            updatePreview(names{1});
        end
    end

if isvalid(dlg)
    delete(dlg);
end

end
