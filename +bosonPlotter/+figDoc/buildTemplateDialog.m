function buildTemplateDialog(fig, model, applyCallback)
%BUILDTEMPLATEDIALOG  Save/load/apply FigDoc style templates.
%
%   bosonPlotter.figDoc.buildTemplateDialog(fig, model, applyCallback)

    dlg = uifigure('Name', 'FigDoc Templates', 'Position', [300 300 340 280], ...
        'Resize', 'off');
    gl = uigridlayout(dlg, [7 2], ...
        'RowHeight', {26, '1x', 10, 26, 36, 36, 36}, ...
        'ColumnWidth', {'1x', '1x'}, ...
        'Padding', [12 12 12 12], 'RowSpacing', 6);

    uilabel(gl, 'Text', 'Saved Templates:', 'FontWeight', 'bold');
    lbl2 = uilabel(gl, 'Text', '');
    lbl2.Layout.Row = 1; lbl2.Layout.Column = 2;

    lbTemplates = uilistbox(gl, 'Items', refreshList(), 'Value', {});
    lbTemplates.Layout.Row = 2; lbTemplates.Layout.Column = [1 2];

    uilabel(gl, 'Text', 'New name:', 'FontWeight', 'bold');
    efName = uieditfield(gl, 'text', 'Value', '', 'Placeholder', 'template name');
    efName.Layout.Row = 4; efName.Layout.Column = 2;

    btnSave = uibutton(gl, 'Text', 'Save Current Style', 'FontWeight', 'bold');
    btnSave.Layout.Row = 5; btnSave.Layout.Column = [1 2];

    btnApply = uibutton(gl, 'Text', 'Apply Selected');
    btnApply.Layout.Row = 6; btnApply.Layout.Column = [1 2];

    btnDelete = uibutton(gl, 'Text', 'Delete Selected');
    btnDelete.Layout.Row = 7; btnDelete.Layout.Column = [1 2];

    btnSave.ButtonPushedFcn = @(~,~) doSave();
    btnApply.ButtonPushedFcn = @(~,~) doApply();
    btnDelete.ButtonPushedFcn = @(~,~) doDelete();

    function doSave()
        name = strtrim(efName.Value);
        if isempty(name), return; end
        name = matlab.lang.makeValidName(name);
        bosonPlotter.figDoc.templateManager.save(name, model);
        lbTemplates.Items = refreshList();
        efName.Value = '';
    end

    function doApply()
        sel = lbTemplates.Value;
        if isempty(sel) || strcmp(sel, '(none)'), return; end
        try
            bosonPlotter.figDoc.templateManager.applyTo(sel, model);
            applyCallback();
        catch ME
            bosonPlotter.quietAlert(dlg, ME.message, 'Error', 'Icon', 'error');
        end
    end

    function doDelete()
        sel = lbTemplates.Value;
        if isempty(sel) || strcmp(sel, '(none)'), return; end
        bosonPlotter.figDoc.templateManager.delete(sel);
        lbTemplates.Items = refreshList();
    end

    function items = refreshList()
        names = bosonPlotter.figDoc.templateManager.list();
        if isempty(names)
            items = {'(none)'};
        else
            items = names;
        end
    end
end
