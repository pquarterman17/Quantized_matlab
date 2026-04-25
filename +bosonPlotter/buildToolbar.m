function buildToolbar(parentGL, config, registry, btnColor)
%BUILDTOOLBAR  Clear and repopulate a toolbar grid with action buttons.
%
% Syntax
%   bosonPlotter.buildToolbar(parentGL, config, registry, btnColor)
%
% Inputs
%   parentGL  — uigridlayout (1 row) that hosts the toolbar buttons
%   config    — {1×N} cell of action IDs; empty → use factory default
%   registry  — struct array with .id / .label / .tooltip / .callback
%   btnColor  — [1×3] RGB background colour for each button
%
% Notes
%   Pure function — no closure or appData dependencies. Sets each button's
%   `Tag = act.id` so callbacks can locate buttons after creation. Filters
%   `config` to IDs that exist in `registry`; falls back to the factory
%   default config (intersected with the registry) when filtering empties
%   the list.

    if isempty(config)
        config = bosonPlotter.toolbarDefaultConfig();
    end

    % Keep only IDs present in the registry
    allRegIds = {registry.id};
    config    = config(ismember(config, allRegIds));
    if isempty(config)
        config = bosonPlotter.toolbarDefaultConfig();
        config = config(ismember(config, allRegIds));
    end

    nBtns = numel(config);

    % Remove all existing children (buttons + spacer)
    existingChildren = parentGL.Children;
    for ci = 1:numel(existingChildren)
        if isvalid(existingChildren(ci))
            delete(existingChildren(ci));
        end
    end

    % Set column widths: spacer | btn1 | btn2 | …
    BTN_W = 55;
    colWidths = [{'1x'}, repmat({BTN_W}, 1, nBtns)];
    parentGL.ColumnWidth = colWidths;

    % Spacer label
    spacer = uilabel(parentGL, 'Text', '');
    spacer.Layout.Column = 1;

    % Create a button for each action
    for bi = 1:nBtns
        actId = config{bi};
        idx   = find(strcmp(allRegIds, actId), 1);
        if isempty(idx), continue; end
        act = registry(idx);
        btn = uibutton(parentGL, 'Text', act.label, ...
            'BackgroundColor', btnColor, ...
            'FontColor',       [0.85 0.85 0.85], ...
            'FontSize',        9, ...
            'Tooltip',         act.tooltip, ...
            'ButtonPushedFcn', act.callback);
        btn.Tag           = act.id;
        btn.Layout.Column = bi + 1;
    end
end
