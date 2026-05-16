function buildAnnotationDialog(fig, ax, model, applyCallback)
%BUILDANNOTATIONDIALOG  Add/edit/remove text annotations on the plot.
%
%   bosonPlotter.figDoc.buildAnnotationDialog(fig, ax, model, applyCallback)
%
%   Opens a dialog for managing persistent annotations. Users can:
%   - Add text at a clicked position (interactive placement)
%   - Add text at specified coordinates
%   - Remove existing annotations
%   - Edit annotation text/style

    dlg = uifigure('Name', 'Annotations', 'Position', [300 300 360 340], ...
        'Resize', 'off');
    gl = uigridlayout(dlg, [9 2], ...
        'RowHeight', {26, 26, 26, 26, 26, 26, '1x', 10, 36}, ...
        'ColumnWidth', {'1x', '1x'}, ...
        'Padding', [12 12 12 12], 'RowSpacing', 6);

    % ── Text input ─────────────────────────────────────────────────────
    uilabel(gl, 'Text', 'Annotation Text:', 'FontWeight', 'bold');
    efText = uieditfield(gl, 'text', 'Value', '', 'Placeholder', 'Enter text...');
    efText.Layout.Row = 1; efText.Layout.Column = 2;

    % ── Position ──────────────────────────────────��─────────────────────
    uilabel(gl, 'Text', 'X Position:');
    efX = uieditfield(gl, 'numeric', 'Value', 0);
    efX.Layout.Row = 2; efX.Layout.Column = 2;

    uilabel(gl, 'Text', 'Y Position:');
    efY = uieditfield(gl, 'numeric', 'Value', 0);
    efY.Layout.Row = 3; efY.Layout.Column = 2;

    % ── Style ───────────────────────────────────────────────────────────
    uilabel(gl, 'Text', 'Font Size:');
    spnFS = uispinner(gl, 'Value', 11, 'Limits', [6 36], 'Step', 1);
    spnFS.Layout.Row = 4; spnFS.Layout.Column = 2;

    uilabel(gl, 'Text', 'Color:');
    ddColor = uidropdown(gl, 'Items', {'Black','Red','Blue','Green','Orange'}, ...
        'Value', 'Black');
    ddColor.Layout.Row = 5; ddColor.Layout.Column = 2;

    % ── Existing annotations list ──────────────────────────────────────
    uilabel(gl, 'Text', 'Existing:', 'FontWeight', 'bold');
    lbAnnot = uilistbox(gl, 'Items', buildListItems(model), 'Value', {});
    lbAnnot.Layout.Row = [6 7]; lbAnnot.Layout.Column = [1 2];

    % ── Buttons ─────────────────────────────────────────────────────────
    btnAdd = uibutton(gl, 'Text', 'Add', 'FontWeight', 'bold');
    btnAdd.Layout.Row = 9; btnAdd.Layout.Column = 1;

    btnRemove = uibutton(gl, 'Text', 'Remove Selected');
    btnRemove.Layout.Row = 9; btnRemove.Layout.Column = 2;

    btnAdd.ButtonPushedFcn = @(~,~) doAdd();
    btnRemove.ButtonPushedFcn = @(~,~) doRemove();

    function doAdd()
        txt = strtrim(efText.Value);
        if isempty(txt), return; end
        annot.type = 'text';
        annot.position = [efX.Value, efY.Value];
        annot.text = txt;
        annot.style.fontSize = spnFS.Value;
        annot.style.color = resolveColor(ddColor.Value);
        model.addAnnotation(annot);
        applyCallback();
        lbAnnot.Items = buildListItems(model);
        efText.Value = '';
    end

    function doRemove()
        sel = lbAnnot.Value;
        if isempty(sel), return; end
        idx = find(strcmp(lbAnnot.Items, sel), 1);
        if ~isempty(idx)
            model.removeAnnotation(idx);
            applyCallback();
            lbAnnot.Items = buildListItems(model);
        end
    end
end

function items = buildListItems(model)
    n = numel(model.annotations);
    if n == 0
        items = {'(none)'};
        return;
    end
    items = cell(1, n);
    for k = 1:n
        a = model.annotations{k};
        items{k} = sprintf('[%d] "%s" at (%.1f, %.1f)', k, a.text, a.position(1), a.position(2));
    end
end

function rgb = resolveColor(name)
    switch name
        case 'Black',  rgb = [0 0 0];
        case 'Red',    rgb = [0.85 0.2 0.2];
        case 'Blue',   rgb = [0.2 0.2 0.85];
        case 'Green',  rgb = [0.2 0.7 0.2];
        case 'Orange', rgb = [0.9 0.5 0.1];
        otherwise,     rgb = [0 0 0];
    end
end
